// Standalone Stage-C differential oracle; compile all sources with
// -DCYBERSAND_RENDER_COPY_EXPERIMENT. Does not select a production copy path.
#include "cybersand/material_appearance.hpp"
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>
#include <tuple>
#include <vector>

#ifndef CYBERSAND_RENDER_COPY_EXPERIMENT
#error Stage-C tests require CYBERSAND_RENDER_COPY_EXPERIMENT
#endif

namespace {
using namespace cybersand;
std::uint64_t assertions = 0;
std::uint64_t regions_checked = 0;
void require(bool condition, const char* message) {
    ++assertions;
    if (!condition) throw std::runtime_error(message);
}

void set_and_verify(World& world, std::int64_t x, std::int64_t y, Material material,
                    std::uint16_t state_a, std::uint8_t state_b) {
    // The setter's false result also means an exact no-op. Check the stored
    // tuple instead, so a refused nontrivial setup cannot weaken the oracle.
    (void)world.set_cell_state(x, y, material, state_a, state_b);
    const bool zero_water = material == Material::Water && state_a == 0U;
    require(world.stored_material(x, y) == (zero_water ? Material::Empty : material),
            "fixture setter did not install the expected material");
    require(world.stored_state_a(x, y) == (zero_water ? 0U : state_a),
            "fixture setter did not install the expected state_a");
    require(world.stored_state_b(x, y) == (zero_water ? 0U : state_b),
            "fixture setter did not install the expected state_b");
}

struct StateReceipt {
    std::uint64_t physical, content, state, revision, tick, completed;
    std::size_t dirty, active, chunks;
    explicit StateReceipt(const World& world)
        : physical(world.physical_state_hash()), content(world.content_hash()),
          state(world.state_hash()), revision(world.hard_surface_revision()),
          tick(world.tick_index()), completed(world.completed_tick_index()),
          dirty(world.dirty_chunk_count()), active(world.active_chunk_count()),
          chunks(world.chunk_count()) {}
    void verify(const World& world) const {
        require(physical == world.physical_state_hash(), "copy changed physical state/quantities");
        require(content == world.content_hash(), "copy changed material/state/temperature tuples");
        require(state == world.state_hash(), "copy changed historical state hash");
        require(revision == world.hard_surface_revision(), "copy changed revision");
        require(tick == world.tick_index() && completed == world.completed_tick_index(),
                "copy advanced simulation");
        require(dirty == world.dirty_chunk_count() && active == world.active_chunk_count(),
                "copy changed dirty/activity state");
        require(chunks == world.chunk_count(), "copy allocated absent chunks");
    }
};

void compare(const World& world, RectI64 region, std::size_t padding = 0) {
    const auto row_bytes = static_cast<std::size_t>(region.width) * 2U;
    const auto stride = row_bytes + padding;
    const auto size = static_cast<std::size_t>(region.height) * stride + 19U;
    std::vector<std::uint8_t> original(size, 0xa5U), run(size, 0xa5U), counted(size, 0xa5U);
    world.copy_render_cells(region, original, stride);
    world.copy_render_cells_by_run(region, run, stride);
    RenderCopyExperimentMetrics original_metrics, run_metrics;
    world.profile_render_cells_original(region, counted, stride, original_metrics);
    require(original == run, "original/run output or padding differs");
    require(original == counted, "counted original does not match ordinary original");
    world.copy_render_cells_by_run(region, run, stride, &run_metrics);
    require(original == run, "counted run differs");
    const auto cells = static_cast<std::uint64_t>(region.width) *
                       static_cast<std::uint64_t>(region.height);
    require(original_metrics.cells == cells && run_metrics.cells == cells,
            "cell counters are incomplete");
    require(original_metrics.chunk_lookups == cells * 3U &&
            original_metrics.address_calculations == cells * 3U,
            "original must perform three lookups/addresses per cell");
    require(run_metrics.chunk_lookups <= cells &&
            run_metrics.address_calculations == run_metrics.chunk_lookups,
            "run must resolve exactly once per chunk run");
    require(original_metrics.absent_cells == run_metrics.absent_cells,
            "absent-cell accounting differs");
    require(original_metrics.material_reads == run_metrics.material_reads &&
            original_metrics.state_reads == run_metrics.state_reads,
            "material/state read accounting differs");
    // Independent per-cell projection checks output beyond comparing two loops.
    for (std::int64_t y = 0; y < region.height; ++y) {
        for (std::int64_t x = 0; x < region.width; ++x) {
            const auto material = world.stored_material(region.x + x, region.y + y);
            const auto index = static_cast<std::size_t>(y) * stride + static_cast<std::size_t>(x) * 2U;
            require(run[index] == static_cast<std::uint8_t>(material), "material oracle differs");
            require(run[index + 1U] == project_visual_state(material,
                world.stored_state_a(region.x + x, region.y + y),
                world.stored_state_b(region.x + x, region.y + y),
                world.config().water_experiment_policy), "visual projection oracle differs");
        }
    }
    ++regions_checked;
}

void populate(World& world, bool dense) {
    std::vector<Material> chunk(128U * 128U);
    for (std::int64_t cy = 0; cy < 8; ++cy) {
        for (std::int64_t cx = 0; cx < 8; ++cx) {
            if (!dense && (cx + cy * 3) % 7 != 0) continue;
            for (std::size_t index = 0; index < chunk.size(); ++index) {
                const auto id = static_cast<std::uint16_t>((index * 17U +
                    static_cast<std::size_t>(cx + cy * 8)) % kMaterialDefinitions.size());
                chunk[index] = valid_material(id) ? static_cast<Material>(id) : Material::Wall;
            }
            require(world.install_generated_chunk({cx, cy}, chunk) == ChunkInstallOutcome::Installed,
                    "fixture chunk installation refused");
        }
    }
}

void frame_and_regions() {
    for (const bool dense : {false, true}) {
        World world;
        populate(world, dense);
        const StateReceipt before(world);
        compare(world, {0, 0, 1024, 1024});
        for (const auto region : std::array<RectI64, 10>{{
            {0, 0, 1, 1}, {127, 127, 3, 3}, {119, 127, 27, 129},
            {-129, -129, 385, 385}, {-7, 5, 1024, 31}, {700, 700, 512, 300},
            {2048, -4096, 256, 129}, {1, 2, 0, 0}, {7, 11, 0, 4},
            {7, 11, 4, 0}}}) compare(world, region, 7);
        std::mt19937_64 random(0x535441474543ULL);
        for (int index = 0; index < 64; ++index) {
            compare(world, {static_cast<std::int64_t>(random() % 1800U) - 400,
                static_cast<std::int64_t>(random() % 1800U) - 400,
                static_cast<std::int64_t>(random() % 257U),
                static_cast<std::int64_t>(random() % 129U)}, static_cast<std::size_t>(random() % 13U));
        }
        before.verify(world);
        RenderCopyExperimentMetrics original_metrics, run_metrics;
        std::vector<std::uint8_t> bytes(1024U * 1024U * 2U);
        world.profile_render_cells_original({0, 0, 1024, 1024}, bytes, 2048, original_metrics);
        world.copy_render_cells_by_run({0, 0, 1024, 1024}, bytes, 2048, &run_metrics);
        require(original_metrics.chunk_lookups == 3U * 1024U * 1024U,
                "full-frame original lookup count wrong");
        require(run_metrics.chunk_lookups == 8U * 1024U, "full-frame run lookup count wrong");
    }
}

void material_states_and_water() {
    constexpr std::array<std::uint8_t, 6> edges{0, 1, 127, 128, 254, 255};
    World world;
    std::int64_t position = 0;
    for (std::uint16_t id = 0; id < kMaterialDefinitions.size(); ++id) {
        if (!valid_material(id) || id == static_cast<std::uint16_t>(Material::Water)) continue;
        for (const auto a : edges) for (const auto b : edges) {
            set_and_verify(world, position % 256 - 128, position / 256 - 128,
                           static_cast<Material>(id), a, b);
            ++position;
        }
        // Exercise every value in each byte lane, with a nontrivial other lane.
        for (unsigned value = 0; value < 256U; ++value) {
            set_and_verify(world, position % 256 - 128, position / 256 - 128,
                static_cast<Material>(id), static_cast<std::uint16_t>(value),
                static_cast<std::uint8_t>(255U - value));
            ++position;
        }
    }
    const StateReceipt before(world);
    compare(world, {-128, -128, 256, (position + 255) / 256}, 5);
    before.verify(world);
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        WorldConfig config;
        config.water_experiment_policy = WaterExperimentPolicy{bits, 12};
        World water(config);
        const auto maximum = config.water_experiment_policy.maximum();
        for (std::uint16_t mass = 0; mass <= maximum; ++mass) {
            for (std::uint8_t coherence = 0; coherence <= 12; ++coherence)
                set_and_verify(water, static_cast<std::int64_t>(mass) - 128,
                    static_cast<std::int64_t>(coherence) - 6, Material::Water, mass, coherence);
        }
        const StateReceipt water_before(water);
        compare(water, {-129, -7, static_cast<std::int64_t>(maximum) + 3, 15}, 3);
        water_before.verify(water);
    }
}

void randomized_state_pairs() {
    // Randomize both state lanes independently, in addition to the fixed edge
    // and complete individual-lane cases above. Water stays in its configured
    // mass/coherence domain; a zero mass must normalize to Empty.
    for (const std::uint8_t bits : std::array<std::uint8_t, 3>{3, 5, 8}) {
        WorldConfig config;
        config.water_experiment_policy = WaterExperimentPolicy{bits, 12};
        World world(config);
        std::mt19937_64 random(0x5354415445504149ULL + bits);
        for (int index = 0; index < 4096; ++index) {
            const auto x = static_cast<std::int64_t>(random() % 512U) - 256;
            const auto y = static_cast<std::int64_t>(random() % 256U) - 128;
            const auto id = static_cast<std::uint16_t>(random() % kMaterialDefinitions.size());
            const auto material = valid_material(id) ? static_cast<Material>(id) : Material::Wall;
            const auto state_a = static_cast<std::uint16_t>(material == Material::Water
                ? random() % (static_cast<std::uint64_t>(config.water_experiment_policy.maximum()) + 1U)
                : random() % 256U);
            const auto state_b = static_cast<std::uint8_t>(material == Material::Water
                ? random() % (static_cast<std::uint64_t>(config.water_experiment_policy.coherence_ticks()) + 1U)
                : random() % 256U);
            set_and_verify(world, x, y, material, state_a, state_b);
        }
        const StateReceipt before(world);
        compare(world, {-257, -129, 514, 258}, 5);
        for (int index = 0; index < 32; ++index) {
            compare(world, {static_cast<std::int64_t>(random() % 640U) - 320,
                static_cast<std::int64_t>(random() % 384U) - 192,
                static_cast<std::int64_t>(random() % 161U) + 1,
                static_cast<std::int64_t>(random() % 97U) + 1},
                static_cast<std::size_t>(random() % 11U));
        }
        before.verify(world);
    }
}

void signed_boundaries_and_nonmutation() {
    World empty;
    constexpr auto high = std::numeric_limits<std::int64_t>::max();
    constexpr auto low = std::numeric_limits<std::int64_t>::min();
    // No setters at INT64 endpoints: their wake neighbourhood has a wider
    // contract. Copy itself supports these valid inclusive endpoint regions.
    for (const auto region : std::array<RectI64, 6>{{
        {high, high, 1, 1}, {high - 128, high - 1, 129, 2},
        {low, low, 129, 2}, {-129, -129, 259, 259},
        {high - 1, low, 2, 3}, {low, high - 2, 3, 3}}}) compare(empty, region, 11);
    for (const auto chunk_size : {16, 64, 128}) {
        WorldConfig config;
        config.chunk_size = chunk_size;
        config.activity_block_size = std::min(chunk_size, 32);
        config.scheduling_core_size = chunk_size;
        World original(config), copied(config);
        std::mt19937_64 random(0x4e4f4e4d55544154ULL);
        for (int index = 0; index < 1600; ++index) {
            const auto x = static_cast<std::int64_t>(random() % 96U) - 48;
            const auto y = static_cast<std::int64_t>(random() % 96U) - 48;
            const auto material = std::array{Material::Wall, Material::Water, Material::Sand,
                Material::Wood, Material::Smoke, Material::Fire}[random() % 6U];
            original.set(x, y, material);
            copied.set(x, y, material);
        }
        const StateReceipt before(copied);
        compare(copied, {-65, -65, 130, 130}, 9);
        before.verify(copied);
        const auto expected_dirty = original.take_dirty_chunks();
        const auto actual_dirty = copied.take_dirty_chunks();
        require(expected_dirty.size() == actual_dirty.size(), "copy changed dirty chunk roster");
        for (std::size_t index = 0; index < expected_dirty.size(); ++index) {
            const auto& a = expected_dirty[index]; const auto& b = actual_dirty[index];
            require(a.chunk == b.chunk && a.local_rect.x == b.local_rect.x &&
                a.local_rect.y == b.local_rect.y && a.local_rect.width == b.local_rect.width &&
                a.local_rect.height == b.local_rect.height, "copy changed exact dirty bounds");
        }
        for (int tick = 0; tick < 4; ++tick) {
            (void)original.tick(); (void)copied.tick();
            require(original.physical_state_hash() == copied.physical_state_hash(),
                    "render extraction changed subsequent deterministic simulation output");
        }
    }
}

void layout_refusals() {
    World world;
    std::vector<std::uint8_t> bytes(24, 0x5a);
    for (const auto region : std::array<RectI64, 4>{{
        {0, 0, -1, 1}, {0, 0, 1, -1}, {0, 0, 20, 2},
        // Eight-byte stride is valid, but four rows require 32 bytes.
        {0, 0, 4, 4}}}) {
        bool original_refused = false, run_refused = false;
        try { world.copy_render_cells(region, bytes, 8); }
        catch (const std::exception&) { original_refused = true; }
        try { world.copy_render_cells_by_run(region, bytes, 8); }
        catch (const std::exception&) { run_refused = true; }
        require(original_refused && run_refused, "layout refusal parity failed");
        require(std::all_of(bytes.begin(), bytes.end(), [](auto byte) { return byte == 0x5a; }),
                "invalid layout partially wrote destination");
    }
}
}

int main() {
    try {
        frame_and_regions(); material_states_and_water(); randomized_state_pairs();
        signed_boundaries_and_nonmutation();
        layout_refusals();
        std::cout << "RENDER_COPY_ISOLATION: assertions=" << assertions << " regions="
                  << regions_checked << " failures=0\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "RENDER_COPY_ISOLATION: assertions=" << assertions << " regions="
                  << regions_checked << " failure=" << error.what() << '\n';
        return 1;
    }
}
