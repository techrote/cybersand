// Included at file scope by test_world.cpp. Also supports an isolated executable
// with -x c++ -DCYBERSAND_RENDER_COPY_STANDALONE for source-matched host receipts.
// Fixture coverage is adapted from #335's isolation oracle; production R is the
// corrected #290 implementation, and this file adds no runtime copy selector.
#include "render_copy_reference.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <vector>

namespace render_copy_qualification {
using cybersand::Material;
using cybersand::RectI64;
using cybersand::World;
using cybersand::WorldConfig;

struct Counts {
    std::uint64_t assertions = 0;
    std::uint64_t regions = 0;
    std::uint64_t compared_bytes = 0;
    std::uint64_t nonmutation_checks = 0;
    std::uint64_t refusal_checks = 0;
    void check(bool condition, const char* message) {
        ++assertions;
        if (!condition) throw std::runtime_error(message);
    }
};

struct StateReceipt {
    std::uint64_t physical, content, state, revision, tick, completed;
    std::size_t dirty, active, chunks, resident_bytes;
    std::vector<std::uint8_t> persistent;
    explicit StateReceipt(const World& world)
        : physical(world.physical_state_hash()), content(world.content_hash()),
          state(world.state_hash()), revision(world.hard_surface_revision()),
          tick(world.tick_index()), completed(world.completed_tick_index()),
          dirty(world.dirty_chunk_count()), active(world.active_chunk_count()),
          chunks(world.chunk_count()), resident_bytes(world.resident_cell_bytes()),
          persistent(world.save_physical_state()) {}
    void verify(const World& world, Counts& count) const {
        count.check(physical == world.physical_state_hash(), "render copy changed physical state/quantities");
        count.check(content == world.content_hash(), "render copy changed cell/state/temperature tuples");
        count.check(state == world.state_hash(), "render copy changed historical state hash");
        count.check(revision == world.hard_surface_revision(), "render copy changed revision");
        count.check(tick == world.tick_index() && completed == world.completed_tick_index(),
                    "render copy advanced simulation");
        count.check(dirty == world.dirty_chunk_count(), "render copy changed dirty count");
        count.check(active == world.active_chunk_count(), "render copy changed active count");
        count.check(chunks == world.chunk_count() && resident_bytes == world.resident_cell_bytes(),
                    "render copy allocated or resized World storage");
        count.check(persistent == world.save_physical_state(),
                    "render copy changed exact persistent bytes/temperature/quantity ledger");
        ++count.nonmutation_checks;
    }
};

struct Case { RectI64 region; std::size_t padding = 0; };
struct GuardedBuffer {
    static constexpr std::size_t prefix = 17, suffix = 19;
    static constexpr std::uint8_t sentinel = 0xa5;
    std::size_t row_bytes, stride, payload_size;
    std::vector<std::uint8_t> bytes;
    explicit GuardedBuffer(Case fixture)
        : row_bytes(static_cast<std::size_t>(fixture.region.width) * 2U),
          stride(row_bytes + fixture.padding),
          payload_size(stride * static_cast<std::size_t>(fixture.region.height)),
          bytes(prefix + payload_size + suffix, sentinel) {}
    std::span<std::uint8_t> payload() {
        return {bytes.data() + prefix, payload_size};
    }
    void verify_guards(Case fixture, Counts& count) const {
        bool intact = std::all_of(bytes.begin(), bytes.begin() + prefix,
            [](auto value) { return value == sentinel; });
        intact = intact && std::all_of(bytes.begin() + static_cast<std::ptrdiff_t>(prefix + payload_size),
            bytes.end(), [](auto value) { return value == sentinel; });
        for (std::int64_t row = 0; row < fixture.region.height; ++row) {
            for (std::size_t pad = row_bytes; pad < stride; ++pad)
                intact = intact && bytes[prefix + static_cast<std::size_t>(row) * stride + pad] == sentinel;
        }
        count.check(intact, "render copy overwrote prefix, stride padding or trailing guard");
    }
};

void compare_batch(const World& world, const std::vector<Case>& cases, Counts& count) {
    // Verify after each implementation separately. Batching rectangles avoids
    // rescanning/serializing a million-cell World for every tiny rectangle.
    const StateReceipt before(world);
    std::vector<GuardedBuffer> reference;
    reference.reserve(cases.size());
    for (const auto& fixture : cases) {
        reference.emplace_back(fixture);
        auto& buffer = reference.back();
        render_copy_reference::copy(world, fixture.region, buffer.payload(), buffer.stride);
        buffer.verify_guards(fixture, count);
    }
    before.verify(world, count);
    for (std::size_t index = 0; index < cases.size(); ++index) {
        const auto& fixture = cases[index];
        GuardedBuffer actual(fixture);
        world.copy_render_cells(fixture.region, actual.payload(), actual.stride);
        count.check(actual.bytes == reference[index].bytes,
                    "production render copy differs byte-for-byte from literal reference");
        actual.verify_guards(fixture, count);
        ++count.regions;
        count.compared_bytes += static_cast<std::uint64_t>(fixture.region.width) *
            static_cast<std::uint64_t>(fixture.region.height) * 2U;
    }
    before.verify(world, count);
}

void set_and_verify(World& world, std::int64_t x, std::int64_t y, Material material,
                    std::uint16_t state_a, std::uint8_t state_b, Counts& count) {
    // False also means an exact no-op. Verify stored values instead of falling
    // back to defaults and accidentally weakening the fixture.
    (void)world.set_cell_state(x, y, material, state_a, state_b);
    const bool zero_water = material == Material::Water && state_a == 0U;
    count.check(world.stored_material(x, y) == (zero_water ? Material::Empty : material),
                "render fixture material installation failed");
    count.check(world.stored_state_a(x, y) == (zero_water ? 0U : state_a),
                "render fixture state_a installation failed");
    count.check(world.stored_state_b(x, y) == (zero_water ? 0U : state_b),
                "render fixture state_b installation failed");
}

void frame_and_regions(Counts& count) {
    for (const bool dense : {false, true}) {
        World world;
        std::vector<Material> chunk(128U * 128U);
        for (std::int64_t cy = 0; cy < 8; ++cy) for (std::int64_t cx = 0; cx < 8; ++cx) {
            if (!dense && (cx + cy * 3) % 7 != 0) continue;
            for (std::size_t index = 0; index < chunk.size(); ++index) {
                const auto id = static_cast<std::uint16_t>((index * 17U +
                    static_cast<std::size_t>(cx + cy * 8)) % cybersand::kMaterialDefinitions.size());
                chunk[index] = cybersand::valid_material(id) ? static_cast<Material>(id) : Material::Wall;
            }
            count.check(world.install_generated_chunk({cx, cy}, chunk) ==
                        cybersand::ChunkInstallOutcome::Installed, "render frame chunk refused");
            world.set_temperature(cx * 128 + 1, cy * 128 + 1,
                                  static_cast<std::int16_t>(-400 + cx * 100 + cy));
        }
        std::vector<Case> cases{{{0, 0, 1024, 1024}, 0}, {{0, 0, 1, 1}, 3},
            {{127, 127, 3, 3}, 6}, {{119, 127, 27, 129}, 7},
            {{-129, -129, 385, 385}, 7}, {{-7, 5, 1024, 31}, 7},
            {{700, 700, 512, 300}, 7}, {{2048, -4096, 256, 129}, 7},
            {{1, 2, 0, 0}, 7}, {{7, 11, 0, 4}, 7}, {{7, 11, 4, 0}, 7}};
        std::mt19937_64 random(0x535441474543ULL);
        for (int index = 0; index < 32; ++index) cases.push_back({{
            static_cast<std::int64_t>(random() % 1800U) - 400,
            static_cast<std::int64_t>(random() % 1800U) - 400,
            static_cast<std::int64_t>(random() % 257U),
            static_cast<std::int64_t>(random() % 129U)},
            static_cast<std::size_t>(random() % 13U)});
        compare_batch(world, cases, count);
        count.check(render_copy_reference::row_runs({0, 0, 1024, 1024}, 128) == 8192U,
                    "derived full-frame run count differs");
    }
}

void material_states_and_water(Counts& count) {
    constexpr std::array<std::uint8_t, 6> edges{0, 1, 127, 128, 254, 255};
    World world;
    std::int64_t position = 0;
    for (std::uint16_t id = 0; id < cybersand::kMaterialDefinitions.size(); ++id) {
        if (!cybersand::valid_material(id) || id == static_cast<std::uint16_t>(Material::Water)) continue;
        for (const auto a : edges) for (const auto b : edges) {
            set_and_verify(world, position % 256 - 128, position / 256 - 128,
                           static_cast<Material>(id), a, b, count);
            ++position;
        }
        for (unsigned value = 0; value < 256U; ++value) {
            set_and_verify(world, position % 256 - 128, position / 256 - 128,
                static_cast<Material>(id), static_cast<std::uint16_t>(value),
                static_cast<std::uint8_t>(255U - value), count);
            ++position;
        }
    }
    world.set_temperature(-127, -127, -900);
    world.set_temperature(127, -1, 2500);
    compare_batch(world, {{{-128, -128, 256, (position + 255) / 256}, 5}}, count);
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        WorldConfig config;
        config.water_experiment_policy = cybersand::WaterExperimentPolicy{bits, 12};
        World water(config);
        const auto maximum = config.water_experiment_policy.maximum();
        for (std::uint16_t mass = 0; mass <= maximum; ++mass)
            for (std::uint8_t coherence = 0; coherence <= 12; ++coherence)
                set_and_verify(water, static_cast<std::int64_t>(mass) - 128,
                    static_cast<std::int64_t>(coherence) - 6, Material::Water, mass, coherence, count);
        water.set_temperature(0, 0, 850);
        compare_batch(water, {{{-129, -7, static_cast<std::int64_t>(maximum) + 3, 15}, 3}}, count);
    }
}

void randomized_worlds(Counts& count) {
    for (const std::uint8_t bits : std::array<std::uint8_t, 3>{3, 5, 8}) {
        WorldConfig config;
        config.water_experiment_policy = cybersand::WaterExperimentPolicy{bits, 12};
        World world(config);
        std::mt19937_64 random(0x5354415445504149ULL + bits);
        for (int index = 0; index < 2048; ++index) {
            const auto x = static_cast<std::int64_t>(random() % 512U) - 256;
            const auto y = static_cast<std::int64_t>(random() % 256U) - 128;
            const auto id = static_cast<std::uint16_t>(random() % cybersand::kMaterialDefinitions.size());
            const auto material = cybersand::valid_material(id) ? static_cast<Material>(id) : Material::Wall;
            const auto a = static_cast<std::uint16_t>(material == Material::Water
                ? random() % (static_cast<std::uint64_t>(config.water_experiment_policy.maximum()) + 1U)
                : random() % 256U);
            const auto b = static_cast<std::uint8_t>(material == Material::Water
                ? random() % (static_cast<std::uint64_t>(config.water_experiment_policy.coherence_ticks()) + 1U)
                : random() % 256U);
            set_and_verify(world, x, y, material, a, b, count);
            if (index % 17 == 0)
                world.set_temperature(x, y, static_cast<std::int16_t>(static_cast<int>(random() % 4000U) - 1000));
        }
        std::vector<Case> cases{{{-257, -129, 514, 258}, 5}};
        for (int index = 0; index < 24; ++index) cases.push_back({{
            static_cast<std::int64_t>(random() % 640U) - 320,
            static_cast<std::int64_t>(random() % 384U) - 192,
            static_cast<std::int64_t>(random() % 161U) + 1,
            static_cast<std::int64_t>(random() % 97U) + 1},
            static_cast<std::size_t>(random() % 11U)});
        compare_batch(world, cases, count);
    }
}

void endpoints_and_refusals(Counts& count) {
    constexpr auto high = std::numeric_limits<std::int64_t>::max();
    constexpr auto low = std::numeric_limits<std::int64_t>::min();
    for (const auto chunk_size : {32, 128}) {
        WorldConfig config;
        config.chunk_size = chunk_size;
        config.scheduling_core_size = chunk_size;
        World empty(config);
        // No setters at INT64 endpoints: wake neighbourhoods have a wider
        // contract. Copy supports these valid inclusive-endpoint rectangles.
        const std::array<RectI64, 15> regions{{
            {high - 1, 0, 1, 1}, {high, 0, 1, 1}, {high - 127, 0, 128, 1},
            {high - 128, 0, 129, 1}, {low, 0, 1, 1}, {low, 0, 129, 1},
            {high, high, 1, 1}, {0, high - 1, 1, 2}, {0, low, 1, 2},
            {high - 128, high - 1, 129, 2}, {low, low, 129, 2},
            {high, 0, 1, 0}, {high, high, 0, 1}, {high, high, 0, 4},
            {high, high, 0, 0}}};
        std::vector<Case> cases;
        for (const auto region : regions) for (const std::size_t padding : {0U, 6U})
            cases.push_back({region, padding});
        compare_batch(empty, cases, count);
    }
    World world;
    world.set(-1, -1, Material::Water);
    world.set_temperature(-1, -1, 800);
    const StateReceipt before(world);
    struct Invalid { RectI64 region; std::size_t stride, size; bool overflow; };
    constexpr auto size_max = std::numeric_limits<std::size_t>::max();
    const std::array<Invalid, 9> cases{{
        {{0, 0, -1, 1}, 8, 24, false}, {{0, 0, 1, -1}, 8, 24, false},
        {{0, 0, 5, 1}, 8, 24, false}, {{0, 0, 4, 4}, 8, 24, false},
        {{high, 0, 2, 1}, 4, 24, true}, {{0, high, 1, 2}, 2, 24, true},
        {{high - 1, high - 1, 3, 3}, 6, 24, true},
        {{0, 0, 2, 2}, size_max, 24, true},
        {{0, 0, 1, high}, 4, 24, true}}};
    for (const bool reference : {true, false}) {
        for (const auto& fixture : cases) {
            std::vector<std::uint8_t> bytes(fixture.size, 0xab);
            bool refused = false;
            try {
                if (reference) render_copy_reference::copy(world, fixture.region, bytes, fixture.stride);
                else world.copy_render_cells(fixture.region, bytes, fixture.stride);
            } catch (const std::overflow_error&) { refused = fixture.overflow; }
              catch (const std::invalid_argument&) { refused = !fixture.overflow; }
            count.check(refused, "render copy did not refuse invalid coordinates/layout with expected exception");
            count.check(std::all_of(bytes.begin(), bytes.end(), [](auto value) { return value == 0xab; }),
                        "refused render copy partially wrote destination");
            ++count.refusal_checks;
        }
        before.verify(world, count);
    }
}

void equal_dirty(const std::vector<cybersand::DirtyChunk>& expected,
                 const std::vector<cybersand::DirtyChunk>& actual, Counts& count) {
    count.check(expected.size() == actual.size(), "render copy changed exact dirty chunk roster");
    for (std::size_t index = 0; index < expected.size(); ++index) {
        const auto& a = expected[index]; const auto& b = actual[index];
        count.check(a.chunk == b.chunk && a.local_rect.x == b.local_rect.x &&
            a.local_rect.y == b.local_rect.y && a.local_rect.width == b.local_rect.width &&
            a.local_rect.height == b.local_rect.height, "render copy changed exact dirty bounds");
    }
}

void subsequent_simulation(Counts& count) {
    for (const auto chunk_size : {16, 64, 128}) {
        WorldConfig config;
        config.chunk_size = chunk_size;
        config.activity_block_size = std::min(chunk_size, 32);
        config.scheduling_core_size = chunk_size;
        World untouched(config), reference(config), run(config);
        std::mt19937_64 random(0x4e4f4e4d55544154ULL);
        for (int index = 0; index < 800; ++index) {
            const auto x = static_cast<std::int64_t>(random() % 96U) - 48;
            const auto y = static_cast<std::int64_t>(random() % 96U) - 48;
            const auto material = std::array{Material::Wall, Material::Water, Material::Sand,
                Material::Wood, Material::Smoke, Material::Fire}[random() % 6U];
            for (auto* world : {&untouched, &reference, &run}) {
                world->set(x, y, material);
                if (index % 13 == 0) world->set_temperature(x, y, static_cast<std::int16_t>(index - 200));
            }
        }
        const StateReceipt reference_before(reference), run_before(run);
        const Case fixture{{-65, -65, 130, 130}, 9};
        GuardedBuffer expected(fixture), actual(fixture);
        render_copy_reference::copy(reference, fixture.region, expected.payload(), expected.stride);
        reference_before.verify(reference, count);
        run.copy_render_cells(fixture.region, actual.payload(), actual.stride);
        run_before.verify(run, count);
        count.check(expected.bytes == actual.bytes, "paired continuation render bytes differ");
        expected.verify_guards(fixture, count); actual.verify_guards(fixture, count);
        ++count.regions;
        count.compared_bytes += 130U * 130U * 2U;
        const auto dirty = untouched.take_dirty_chunks();
        equal_dirty(dirty, reference.take_dirty_chunks(), count);
        equal_dirty(dirty, run.take_dirty_chunks(), count);
        // Repeat with all dirty flags clear: extraction must not dirty cells.
        const StateReceipt clean_reference(reference), clean_run(run);
        render_copy_reference::copy(reference, fixture.region, expected.payload(), expected.stride);
        clean_reference.verify(reference, count);
        run.copy_render_cells(fixture.region, actual.payload(), actual.stride);
        clean_run.verify(run, count);
        count.check(reference.take_dirty_chunks().empty() && run.take_dirty_chunks().empty(),
                    "render copy dirtied a clean World");
        for (int tick = 0; tick < 4; ++tick) {
            (void)untouched.tick(); (void)reference.tick(); (void)run.tick();
            const auto physical = untouched.physical_state_hash();
            count.check(physical == reference.physical_state_hash(),
                        "literal reference changed subsequent deterministic simulation");
            count.check(physical == run.physical_state_hash(),
                        "production render copy changed subsequent deterministic simulation");
            const auto saved = untouched.save_physical_state();
            count.check(saved == reference.save_physical_state() && saved == run.save_physical_state(),
                        "render copy changed subsequent exact persistent simulation state");
        }
    }
}
}  // namespace render_copy_qualification

void test_render_copy_production_qualification() {
    using namespace render_copy_qualification;
    Counts count;
    try {
        frame_and_regions(count);
        material_states_and_water(count);
        randomized_worlds(count);
        endpoints_and_refusals(count);
        subsequent_simulation(count);
    } catch (...) {
        std::cerr << "RENDER_COPY_QUALIFICATION {\"assertions\":" << count.assertions
                  << ",\"regions\":" << count.regions << ",\"failures\":1}\n";
        throw;
    }
    std::cout << "RENDER_COPY_QUALIFICATION {\"assertions\":" << count.assertions
              << ",\"regions\":" << count.regions << ",\"compared_bytes\":" << count.compared_bytes
              << ",\"nonmutation_checks\":" << count.nonmutation_checks
              << ",\"refusal_checks\":" << count.refusal_checks << ",\"failures\":0}\n";
}

#ifdef CYBERSAND_RENDER_COPY_STANDALONE
int main() {
    try { test_render_copy_production_qualification(); return 0; }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
#endif
