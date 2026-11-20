// WAVE-WATERWALL-001: standalone native regressions for the opt-in wave_flow_v1
// exposed-face spill and its hybrid ballistic release. Build targets:
// make wave-spill-test / wave-spill-sanitize / wave-spill-thread-sanitize.
#include "cybersand/world.hpp"
#include "cybersand/prepared_world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <exception>
#include <limits>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

// Ballistic: generic ballistic_water_v1 under Wave with spill off.
enum class Mode { Original, Spill, Hybrid, Ballistic };

WorldConfig config(Mode mode, std::uint32_t workers = 4, std::uint8_t substeps = 1) {
    WorldConfig result;
    result.worker_threads = workers;
    result.parallel_job_threshold = 2;
    result.maximum_chunk_count = 128;
    result.active_chunk_capacity = 128;
    result.wave_flow.enabled = true;
    result.wave_flow.substeps = substeps;
    result.wave_flow.spill.enabled = mode == Mode::Spill || mode == Mode::Hybrid;
    result.ballistic_water.enabled = mode == Mode::Hybrid || mode == Mode::Ballistic;
    return result;
}

void rect(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx, yy, material);
}

void box(World& world, int width, int height, int x = 0, int y = 0) {
    rect(world, x, y, width, 1, Material::Wall);
    rect(world, x, y + height - 1, width, 1, Material::Wall);
    rect(world, x, y, 1, height, Material::Wall);
    rect(world, x + width - 1, y, 1, height, Material::Wall);
}

// Every unit has exactly one owner: stored cells or a live parcel. The stored
// side is counted from cells, independently of the quantity ledger.
std::uint64_t owned(const World& world, RectI64 all) {
    return world.water_quantity(all) + world.ballistic_water_snapshot().in_flight_quantity;
}

void require_ledger_closes(const World& world, RectI64 all, std::uint64_t expected, const std::string& where) {
    const auto ledger = world.quantity_ledger();
    const auto flight = world.ballistic_water_snapshot();
    require(owned(world, all) == expected, where + ": stored plus in-flight Water changed");
    require(ledger.water_visible + ledger.water_overfill == world.water_quantity(all), where + ": ledger grid quantity disagrees with cells");
    require(ledger.water_ballistic == flight.in_flight_quantity, where + ": ledger in-flight quantity disagrees with parcels");
    require(flight.ledger.launched_quantity + flight.ledger.injected_quantity ==
                flight.ledger.deposited_quantity + flight.in_flight_quantity,
            where + ": ballistic launch/deposit ledger does not close");
    std::uint64_t cells = 0;
    for (auto y = all.y; y < all.y + all.height; ++y)
        for (auto x = all.x; x < all.x + all.width; ++x)
            if (world.stored_material(x, y) == Material::Water) ++cells;
    require(ledger.material_cells[static_cast<std::size_t>(Material::Water)] == cells, where + ": Water cell population drifted");
}

template <typename Mutate>
void expect_refusal(Mutate mutate, const char* what) {
    auto cfg = config(Mode::Spill);
    mutate(cfg);
    bool refused = false;
    try {
        World world(cfg);
    } catch (const std::invalid_argument&) {
        refused = true;
    }
    require(refused, std::string("spill admitted an unsupported configuration: ") + what);
}

void spill_is_off_by_default_and_admission_is_typed() {
    require(!WorldConfig{}.wave_flow.spill.enabled && !WaveFlowConfig{}.spill.enabled, "spill enabled by default");
    World original(config(Mode::Original));
    const auto idle = original.wave_flow_diagnostics();
    require(idle.spill_units == 0 && idle.relief_units == 0 && idle.launched_parcels == 0, "disabled spill reported work");

    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.fall = 0; }, "zero fall");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.fall = 9; }, "fall above eight");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.share_shift = 0; }, "whole-cell share (two faces could overdraw)");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.share_shift = 9; }, "share shift above eight");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.draw = -1; }, "negative draw");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.draw = 128; }, "draw above half a cell");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.draw_head = -1; }, "negative draw head");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.stream = 256; }, "stream above a cell");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.launch_min = 0; }, "empty parcels");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.launch_budget = 4097; }, "launch budget above bound");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.launch_speed = 513; }, "launch speed above bound");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.sheet_rate = -1; }, "negative sheet rate");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.sheet_rate = 128; }, "sheet rate above bound");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.coyote_ticks = -1; }, "negative crest flight duration");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.coyote_ticks = 9; }, "crest flight duration above bound");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.full_face = -1; }, "negative full face");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.full_face = 2; }, "full face above one");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.deep_draw = -1; }, "negative deep draw");
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.deep_draw = 128; }, "deep draw above 127");
    // Spill's hybrid release owns exposed faces: the per-cell face scan is
    // refused beside it, and admitted (generic Ballistic Water) without spill.
    expect_refusal([](WorldConfig& c) { c.ballistic_water.enabled = true; c.ballistic_water.face_release = true; },
                   "per-cell face release beside spill");
    // Out-of-range values are ignored while spill is disabled: nothing reads them.
    auto ignored = config(Mode::Original);
    ignored.wave_flow.spill.fall = 99;
    World accepted(ignored);
    require(accepted.wave_flow_enabled(), "disabled spill tuning refused a valid Wave World");
    World generic(config(Mode::Ballistic));
    require(generic.wave_flow_enabled() && generic.ballistic_water_enabled(), "generic Ballistic Water refused under Wave");
    auto faces = config(Mode::Ballistic);
    faces.ballistic_water.face_release = true;
    World face_release(faces);
    require(face_release.wave_flow_enabled(), "face release without spill refused under Wave");
    World hybrid(config(Mode::Hybrid));
    require(hybrid.wave_flow_enabled() && hybrid.ballistic_water_enabled(), "hybrid release was not admitted");
    bool refused = false;
    try { (void)hybrid.save_physical_state(); } catch (const std::logic_error&) { refused = true; }
    require(refused && hybrid.physical_state_format_version() == 0U, "hybrid Wave World claimed exact persistence");
}

// Pinned from the unmodified base law (origin/experiment/waterlab-631-consolidated-ui,
// c7386cfb) with the same scenes. A spill-disabled World must reproduce them.
struct Golden { int scene; unsigned substeps, workers; std::uint64_t physical, state, content; };
constexpr Golden kBaseLaw[] = {
    {0, 1, 1, 0x844fd61f59021a8aULL, 0x25901bdfd968b993ULL, 0xfa45619fc83ac4cdULL},
    {0, 1, 4, 0x844fd61f59021a8aULL, 0x25901bdfd968b993ULL, 0xfa45619fc83ac4cdULL},
    {0, 3, 1, 0xa9660fab732c5bbcULL, 0xbd2b22d4a5f6e80aULL, 0x118ec4257a1028e8ULL},
    {0, 3, 4, 0xa9660fab732c5bbcULL, 0xbd2b22d4a5f6e80aULL, 0x118ec4257a1028e8ULL},
    {1, 1, 1, 0xe411c9c748147d80ULL, 0xb1348ae054c63cbdULL, 0x43999505777f49f3ULL},
    {1, 1, 4, 0xe411c9c748147d80ULL, 0xb1348ae054c63cbdULL, 0x43999505777f49f3ULL},
    {1, 3, 1, 0xad40bf19f78ae119ULL, 0x37e3ba858b0b0eeeULL, 0xb64234684900bc53ULL},
    {1, 3, 4, 0xad40bf19f78ae119ULL, 0x37e3ba858b0b0eeeULL, 0xb64234684900bc53ULL},
    {2, 1, 1, 0x9d9ec4def35afb59ULL, 0xb0dbf26da7078a1fULL, 0x47e48c201bf2b286ULL},
    {2, 1, 4, 0x9d9ec4def35afb59ULL, 0xb0dbf26da7078a1fULL, 0x47e48c201bf2b286ULL},
    {2, 3, 1, 0x1b1d302b9af3c235ULL, 0x8b462a09edafdf3cULL, 0x10d5344ac7d6afd8ULL},
    {2, 3, 4, 0x1b1d302b9af3c235ULL, 0x8b462a09edafdf3cULL, 0x10d5344ac7d6afd8ULL},
};

void disabled_spill_reproduces_the_base_law() {
    for (const auto& golden : kBaseLaw) {
        auto cfg = config(Mode::Original, golden.workers, static_cast<std::uint8_t>(golden.substeps));
        if (golden.workers == 4U) {
            cfg.wave_flow.spill.fall = 7;
            cfg.wave_flow.spill.launch_budget = 9;
            cfg.wave_flow.spill.sheet_rate = 127;
            cfg.wave_flow.spill.full_face = 1;
            cfg.wave_flow.spill.deep_draw = 64;
            cfg.wave_flow.spill.coyote_ticks = 8;
        }
        World w(cfg);
        const int n = 300;
        box(w, n, n);
        if (golden.scene == 0) {
            rect(w, 1, 120, 90, 179, Material::Water);
            for (int x = 150; x < 260; x += 7)
                (void)w.set_cell_state(x, 40 + x % 23, Material::Water, static_cast<std::uint16_t>(30 + x % 200), 0);
        } else if (golden.scene == 1) {
            rect(w, 1, 140, 150, 3, Material::Wall);
            rect(w, 1, 90, 150, 50, Material::Water);
            rect(w, 1, 260, 298, 39, Material::Water);
        } else {
            rect(w, 1, 200, 298, 99, Material::Water);
            rect(w, 20, 180, 40, 20, Material::Water);
            w.set_simulation_region(RectI64{0, 0, 192, n});
        }
        for (int t = 0; t < 400; ++t) (void)w.tick();
        require(w.physical_state_hash() == golden.physical && w.state_hash() == golden.state && w.content_hash() == golden.content,
                "spill-disabled Wave diverged from the pinned base law (scene " + std::to_string(golden.scene) + ", substeps " +
                    std::to_string(golden.substeps) + ", workers " + std::to_string(golden.workers) + ")");
    }
}

void disabled_spill_preserves_wave_identity() {
    // The qualified Wave stream must not move: a World with spill disabled
    // (whatever its unused tuning says) is the original law, bit for bit.
    const int n = 256;
    const auto run = [&](bool touched) {
        auto cfg = config(Mode::Original, 4);
        if (touched) { cfg.wave_flow.spill.fall = 7; cfg.wave_flow.spill.draw = 100; cfg.wave_flow.spill.launch_budget = 9; }
        auto world = std::make_unique<World>(cfg);
        box(*world, n, n);
        rect(*world, 1, n / 4, n / 3, n - 1 - n / 4, Material::Water);
        for (int t = 0; t < 200; ++t) (void)world->tick();
        return std::array<std::uint64_t, 3>{world->physical_state_hash(), world->state_hash(), world->content_hash()};
    };
    require(run(false) == run(true), "unused spill tuning changed a spill-disabled Wave World");
    auto enabled = config(Mode::Spill, 4);
    World spill(enabled), plain(config(Mode::Original, 4));
    require(spill.physical_state_hash() != plain.physical_state_hash() && spill.state_hash() != plain.state_hash(),
            "enabled spill is not part of physical identity");
    auto tuned = enabled;
    tuned.wave_flow.spill.fall = 2;
    World other(tuned);
    require(other.physical_state_hash() != spill.physical_state_hash() && other.state_hash() != spill.state_hash(),
            "spill tuning is not part of physical identity");
}

// A tall block of Water standing in the open: the exposed face must discharge.
struct Collapse { std::uint64_t outside = 0, moved = 0, launched = 0, deposited = 0; std::uint64_t hash = 0; };
Collapse collapse(Mode mode, std::uint32_t workers, int ticks, std::uint8_t substeps = 1) {
    const int width = 384, height = 256;
    World world(config(mode, workers, substeps));
    box(world, width, height);
    rect(world, 1, height - 1 - 150, 120, 150, Material::Water);
    const RectI64 all{0, 0, width, height};
    const auto before = owned(world, all);
    for (int t = 0; t < ticks; ++t) {
        (void)world.tick();
        if (t % 50 == 49) require_ledger_closes(world, all, before, "open reservoir");
    }
    require(!world.has_failed(), "open reservoir failed the World");
    const auto flight = world.ballistic_water_snapshot();
    return {world.water_quantity({121, 0, width - 121, height}) + flight.in_flight_quantity,
            world.wave_flow_diagnostics().spill_units, world.wave_flow_diagnostics().launched_units,
            flight.ledger.deposited_quantity, world.physical_state_hash()};
}

void exposed_reservoir_collapses_and_conserves() {
    const auto original = collapse(Mode::Original, 4, 400);
    const auto spill = collapse(Mode::Spill, 4, 400);
    const auto hybrid = collapse(Mode::Hybrid, 4, 400);
    require(original.moved == 0 && original.launched == 0, "original Wave reported spill work");
    require(spill.moved > 0 && spill.launched == 0, "spill-only moved nothing through exposed faces or launched parcels");
    require(hybrid.launched > 0 && hybrid.deposited > 0, "hybrid release launched or landed nothing");
    // The defect is that the block stays where it is. Both mitigations must
    // put clearly more Water outside the original footprint in the same time.
    require(spill.outside * 4 > original.outside * 5, "spill did not discharge the exposed face faster than original Wave");
    require(hybrid.outside * 4 > original.outside * 5, "hybrid release did not discharge the exposed face faster than original Wave");
}

void worker_counts_and_repeats_are_identical() {
    for (const auto mode : {Mode::Spill, Mode::Hybrid})
        for (const std::uint8_t substeps : {std::uint8_t{1}, std::uint8_t{3}}) {
            const auto reference = collapse(mode, 1, 160, substeps);
            require(collapse(mode, 1, 160, substeps).hash == reference.hash, "spill repeat run diverged");
            for (const auto workers : {2U, 4U, 6U}) {
                const auto other = collapse(mode, workers, 160, substeps);
                require(other.hash == reference.hash && other.outside == reference.outside && other.launched == reference.launched,
                        "spill result depends on worker count");
            }
        }
}

void waterfall_lands_fills_and_rejoins() {
    // A platform lip over open air with a receiving basin under it, across
    // chunk seams (128-cell chunks): Water must leave, land and accumulate.
    const int width = 384, height = 320;
    for (const auto mode : {Mode::Spill, Mode::Hybrid}) {
        World world(config(mode, 4));
        box(world, width, height);
        rect(world, 1, 120, 139, 4, Material::Wall);      // platform, lip at x = 140 (past the 128 seam)
        rect(world, 1, 80, 139, 40, Material::Water);
        const RectI64 all{0, 0, width, height};
        const auto before = owned(world, all);
        for (int t = 0; t < 900; ++t) {
            (void)world.tick();
            if (t % 100 == 99) require_ledger_closes(world, all, before, "waterfall");
        }
        const auto platform = world.water_quantity({1, 0, 139, 120});
        const auto basin = world.water_quantity({1, 200, width - 2, height - 201});
        require(platform * 2 < before, "waterfall left more than half of the Water on the platform");
        require(basin * 2 > before - platform, "discharged Water did not accumulate in the receiving basin");
        const auto flight = world.ballistic_water_snapshot();
        if (mode == Mode::Hybrid) {
            require(flight.ledger.launched_parcels > 0 && flight.ledger.deposited_quantity > 0, "waterfall launched or landed nothing");
            require(flight.ledger.maximum_live <= world.config().ballistic_water.capacity, "parcel capacity exceeded");
        }
        // With the source removed by an owner edit, every parcel must land.
        const auto removed = world.water_quantity({1, 0, 139, 120});
        rect(world, 1, 60, 139, 60, Material::Empty);
        for (int t = 0; t < 2000 && world.ballistic_parcel_count() != 0; ++t) (void)world.tick();
        require(world.ballistic_parcel_count() == 0, "parcels never landed");
        require(owned(world, all) == before - removed, "landing lost or duplicated Water");
    }
}

void sealed_reservoir_is_untouched() {
    // Negative control: Water with no open face must not move, launch or wake.
    for (const auto mode : {Mode::Spill, Mode::Hybrid}) {
        World world(config(mode, 4));
        rect(world, 20, 20, 200, 4, Material::Wall);
        rect(world, 20, 120, 200, 4, Material::Wall);
        rect(world, 20, 20, 4, 104, Material::Wall);
        rect(world, 216, 20, 4, 104, Material::Wall);
        rect(world, 24, 24, 192, 96, Material::Water);
        const auto content = world.content_hash();
        for (int t = 0; t < 200; ++t) (void)world.tick();
        const auto diagnostics = world.wave_flow_diagnostics();
        require(world.content_hash() == content, "sealed reservoir changed");
        require(diagnostics.moved_units == 0 && diagnostics.spill_units == 0 && diagnostics.launched_parcels == 0 &&
                    diagnostics.last_solved_chunks == 0 && world.ballistic_parcel_count() == 0,
                "sealed reservoir did spill work or stayed awake");
    }
}

void contained_pool_still_waves_and_rests() {
    // A bump on a contained pool must still travel as a wave, then stop exactly.
    const int width = 384, height = 128, depth = 48;
    for (const auto mode : {Mode::Spill, Mode::Hybrid}) {
        World world(config(mode, 4));
        box(world, width, height);
        const int surface = height - 1 - depth;
        rect(world, 1, surface, width - 2, depth, Material::Water);
        for (int t = 0; t < 120; ++t) (void)world.tick();
        rect(world, 60, surface - 5, 20, 5, Material::Water);
        const RectI64 all{0, 0, width, height};
        const auto before = owned(world, all);
        const auto level = [&](int x) { return static_cast<double>(world.water_quantity({x, 0, 3, height})) / (3.0 * 255.0); };
        double peak = 0;
        for (int t = 0; t < 700; ++t) {
            (void)world.tick();
            peak = std::max(peak, level(width - 80) - depth);
        }
        require(peak > 0.05, "no wave reached the far side of the contained pool");
        int rested = -1;
        for (int t = 0; t < 12000 && rested < 0; ++t) {
            (void)world.tick();
            if (world.wave_flow_diagnostics().last_solved_chunks == 0 && world.ballistic_parcel_count() == 0) rested = t;
        }
        require(rested >= 0, "contained pool never reached exact rest with spill enabled");
        require_ledger_closes(world, all, before, "contained pool");
        const auto hash = world.physical_state_hash();
        const auto content = world.content_hash();
        for (int t = 0; t < 60; ++t) (void)world.tick();
        require(world.content_hash() == content, "rested pool changed");
        (void)hash;
    }
}

void capacity_and_budget_are_explicit_outcomes() {
    const int width = 384, height = 256;
    const RectI64 all{0, 0, width, height};
    const auto build = [&](WorldConfig cfg) {
        auto world = std::make_unique<World>(cfg);
        box(*world, width, height);
        rect(*world, 1, height - 1 - 150, 120, 150, Material::Water);
        return world;
    };
    // Parcel capacity smaller than the per-tick budget: launches are clamped
    // to the free slots, a full pool is counted, and the faces that cannot
    // launch spill through the grid. Nothing is lost.
    auto cfg = config(Mode::Hybrid, 4);
    cfg.ballistic_water.capacity = 8;
    cfg.wave_flow.spill.launch_budget = 16;
    auto starved = build(cfg);
    const auto before = owned(*starved, all);
    for (int t = 0; t < 200; ++t) {
        (void)starved->tick();
        require(starved->ballistic_parcel_count() <= 8U, "tiny parcel pool exceeded");
    }
    const auto clamped = starved->wave_flow_diagnostics();
    require(clamped.launched_parcels > 0 && clamped.spill_units > 0 && clamped.launch_capacity_skips > 0,
            "capacity below the launch budget was not clamped, counted and backed by native spill");
    require_ledger_closes(*starved, all, before, "starved capacity");

    // Capacity that fills: launches stop at the limit, are counted, and the
    // face keeps discharging natively on the ticks that cannot launch.
    cfg.ballistic_water.capacity = 64;
    cfg.wave_flow.spill.launch_budget = 32;
    auto tight = build(cfg);
    for (int t = 0; t < 300; ++t) {
        (void)tight->tick();
        require(tight->ballistic_parcel_count() <= 64U, "parcel capacity exceeded");
    }
    const auto diagnostics = tight->wave_flow_diagnostics();
    require(diagnostics.launched_parcels > 0 && diagnostics.spill_units > 0, "tight capacity neither launched nor spilled natively");
    require(tight->ballistic_water_snapshot().ledger.maximum_live <= 64U, "parcel ledger exceeded capacity");
    require_ledger_closes(*tight, all, before, "tight capacity");

    // A budget smaller than the face: the excess is deferred, counted, and
    // spills natively on the following tick.
    cfg = config(Mode::Hybrid, 4);
    cfg.wave_flow.spill.launch_budget = 4;
    auto slow = build(cfg);
    for (int t = 0; t < 200; ++t) (void)slow->tick();
    const auto deferred = slow->wave_flow_diagnostics();
    require(deferred.launch_deferrals > 0 && deferred.launched_parcels > 0 && deferred.launched_parcels <= 4U * 200U &&
                deferred.spill_units > 0,
            "launch budget was not an explicit deferral with a native fallback");
    require_ledger_closes(*slow, all, before, "small budget");

    // Budget zero never launches: cells evolve exactly as spill without parcels.
    cfg = config(Mode::Hybrid, 4);
    cfg.wave_flow.spill.launch_budget = 0;
    auto none = build(cfg);
    auto native = build(config(Mode::Spill, 4));
    for (int t = 0; t < 150; ++t) { (void)none->tick(); (void)native->tick(); }
    require(none->wave_flow_diagnostics().launched_parcels == 0 && none->content_hash() == native->content_hash(),
            "zero launch budget differs from native spill");
}

void overfilled_cells_never_wrap_or_overfill_parcels() {
    // Wave may store more than one cell of Water in a sealed cell. A parcel
    // never carries more than a cell, and landing never wraps a full one.
    World world(config(Mode::Hybrid, 1));
    box(world, 64, 64);
    rect(world, 10, 10, 5, 1, Material::Wall);
    rect(world, 10, 12, 5, 1, Material::Wall);
    rect(world, 10, 11, 1, 1, Material::Wall);
    rect(world, 14, 11, 1, 1, Material::Wall);
    rect(world, 11, 11, 3, 1, Material::Water);
    require(world.set_cell_state(12, 11, Material::Water, 60000, 0), "Wave refused a legal overfilled cell");
    const RectI64 all{0, 0, 64, 64};
    const auto before = owned(world, all);
    const auto launched = world.launch_ballistic_water(12, 11, 30 * 256 + 128, 30 * 256 + 128, 0, 0, 0,
                                                       std::numeric_limits<std::uint32_t>::max());
    require(launched.outcome == BallisticLaunchOutcome::Launched && launched.quantity == 255U &&
                world.liquid_mass(12, 11) == 60000U - 255U,
            "launch from an overfilled Wave cell did not hand over exactly one cell");
    require(owned(world, all) == before, "launch from an overfilled cell changed quantity");
    // A parcel that enters an almost-full uint16 cell must land elsewhere:
    // 65500 + 200 would wrap. Parcels advance before the Wave passes, so the
    // first tick's deposit meets the cell exactly as seeded.
    World cup(config(Mode::Hybrid, 1));
    box(cup, 64, 64);
    rect(cup, 19, 20, 1, 12, Material::Wall);
    rect(cup, 21, 20, 1, 12, Material::Wall);
    rect(cup, 19, 32, 3, 1, Material::Wall);
    rect(cup, 20, 22, 1, 10, Material::Water);
    require(cup.set_cell_state(20, 21, Material::Water, 65500, 0), "Wave refused a near-ceiling overfilled cell");
    const RectI64 room{0, 0, 64, 64};
    const auto seeded = owned(cup, room);
    const auto drop = cup.inject_ballistic_water(20 * 256 + 128, 20 * 256 + 128, 0, 600, 200);
    require(drop.outcome == BallisticLaunchOutcome::Launched, "test parcel refused");
    const auto deposited = cup.ballistic_water_snapshot().ledger.deposited_quantity;
    (void)cup.tick();
    require(!cup.has_failed(), "deposit onto a near-ceiling cell failed the World");
    require(cup.ballistic_water_snapshot().ledger.deposited_quantity == deposited + 200U, "the parcel did not land on the first tick");
    require(owned(cup, room) == seeded + 200U, "deposit onto an overfilled cell wrapped, lost or duplicated Water");
    for (int t = 0; t < 200; ++t) (void)cup.tick();
    require(owned(cup, room) == seeded + 200U, "overfilled cup lost Water afterwards");
}

void thin_walls_and_masks_stop_spill() {
    // Water thrown at a wall one cell thick must stay on its own side.
    const int width = 256, height = 192;
    for (const auto mode : {Mode::Spill, Mode::Hybrid}) {
        World world(config(mode, 4));
        box(world, width, height);
        rect(world, 1, 120, 80, 3, Material::Wall);           // platform, lip at x = 81
        rect(world, 100, 1, 1, height - 2, Material::Wall);   // one-cell wall across the room
        rect(world, 1, 70, 80, 50, Material::Water);
        const RectI64 all{0, 0, width, height};
        const auto before = owned(world, all);
        for (int t = 0; t < 700; ++t) (void)world.tick();
        require(world.water_quantity({101, 0, width - 101, height}) == 0U, "Water crossed a one-cell wall");
        require(world.water_quantity({1, 0, 80, 120}) * 2 < before, "walled waterfall did not discharge");
        require_ledger_closes(world, all, before, "thin wall");
    }
    // A transient body mask beside the face is solid: no launch into it, and
    // the Water it holds back stays put.
    World masked(config(Mode::Hybrid, 4));
    box(masked, width, height);
    rect(masked, 1, 120, 80, 3, Material::Wall);
    rect(masked, 1, 70, 80, 50, Material::Water);
    masked.configure_transient_obstacles({0, 0, width, height});
    const RectI64 all{0, 0, width, height};
    const auto before = owned(masked, all);
    for (int t = 0; t < 200; ++t) {
        masked.clear_transient_obstacles();
        for (int y = 40; y < 123; ++y) (void)masked.set_transient_obstacle(81, y, 1);
        (void)masked.tick();
    }
    require(masked.water_quantity({1, 0, 80, 120}) == before && masked.wave_flow_diagnostics().launched_parcels == 0,
            "Water passed or launched through a body mask");
    require_ledger_closes(masked, all, before, "masked face");
}

void paused_region_does_not_spill() {
    // An exposed reservoir outside the selected region is frozen: no spill,
    // no launch, no parcel born from excluded cells.
    const int width = 384, height = 192;
    for (const auto mode : {Mode::Spill, Mode::Hybrid}) {
        World world(config(mode, 4));
        box(world, width, height);
        rect(world, 200, 100, 100, 3, Material::Wall);
        rect(world, 200, 60, 100, 40, Material::Water);        // exposed on both sides, x >= 192
        rect(world, 20, 100, 60, 3, Material::Wall);
        rect(world, 20, 60, 60, 40, Material::Water);          // active control
        world.set_simulation_region(RectI64{0, 0, 192, height});
        const RectI64 all{0, 0, width, height};
        const auto before = owned(world, all);
        std::vector<std::uint16_t> paused;
        for (int y = 0; y < height; ++y)
            for (int x = 192; x < width; ++x) paused.push_back(world.stored_state_a(x, y));
        for (int t = 0; t < 250; ++t) (void)world.tick();
        std::size_t at = 0;
        for (int y = 0; y < height; ++y)
            for (int x = 192; x < width; ++x)
                require(world.stored_state_a(x, y) == paused[at++],
                        std::string(mode == Mode::Hybrid ? "hybrid" : "spill") + ": paused exposed Water changed");
        require(world.water_quantity({20, 0, 60, 100}) * 2 < 60U * 40U * 255U, "selected exposed reservoir did not discharge");
        require_ledger_closes(world, all, before, "paused region");
        world.set_simulation_region(std::nullopt);
        for (int t = 0; t < 400; ++t) (void)world.tick();
        require(world.water_quantity({200, 0, 100, 100}) * 2 < 100U * 40U * 255U, "re-entered exposed reservoir stayed a wall");
        require_ledger_closes(world, all, before, "region re-entry");
    }
}

void thin_film_is_not_thrown() {
    // Negative control: a sheet thinner than the adhesion threshold on a ledge
    // keeps the original film behaviour; spill must not strip or launch it.
    for (const auto mode : {Mode::Spill, Mode::Hybrid}) {
        World world(config(mode, 4));
        box(world, 256, 128);
        rect(world, 40, 80, 120, 3, Material::Wall);
        for (int x = 60; x < 140; ++x) require(world.set_cell_state(x, 79, Material::Water, 10, 0), "film setup refused");
        const RectI64 all{0, 0, 256, 128};
        const auto before = owned(world, all);
        for (int t = 0; t < 400; ++t) (void)world.tick();
        require(world.water_quantity({40, 0, 120, 80}) == before, "a sub-threshold film left its ledge");
        require(world.wave_flow_diagnostics().launched_parcels == 0, "a sub-threshold film was launched");
    }
}

void cleared_world_matches_a_fresh_world() {
    // clear() must drop carried spill state: a deferral right before clear()
    // may not change the cleared World's identity or its next launch.
    auto cfg = config(Mode::Hybrid, 1);
    cfg.wave_flow.spill.launch_budget = 1;
    cfg.wave_flow.spill.launch_min = 1;
    const auto seed = [](World& world) {
        box(world, 256, 200);
        rect(world, 1, 60, 40, 139, Material::Water);
    };
    World used(cfg);
    seed(used);
    for (int t = 0; t < 20 && used.wave_flow_diagnostics().launch_deferrals == 0; ++t) (void)used.tick();
    require(used.wave_flow_diagnostics().launch_deferrals > 0, "setup did not defer a launch");
    used.clear();
    World fresh(cfg);
    require(used.state_hash() == fresh.state_hash() && used.physical_state_hash() == fresh.physical_state_hash(),
            "a cleared hybrid World differs from a fresh one");
    seed(used);
    seed(fresh);
    for (int t = 0; t < 30; ++t) { (void)used.tick(); (void)fresh.tick(); }
    require(used.physical_state_hash() == fresh.physical_state_hash(), "a cleared hybrid World evolves differently");
}

void paused_floor_is_solid_to_spill() {
    // Water resting on a paused row must behave exactly as on a wall: the
    // column pass and the spill receiver test agree that paused cells are solid.
    for (const auto mode : {Mode::Spill, Mode::Hybrid}) {
        World walled(config(mode, 4)), paused(config(mode, 4));
        for (auto* world : {&walled, &paused}) {
            rect(*world, 0, 0, 128, 1, Material::Wall);
            rect(*world, 0, 0, 1, 64, Material::Wall);
            rect(*world, 127, 0, 1, 64, Material::Wall);
            rect(*world, 1, 10, 20, 54, Material::Water);
        }
        rect(walled, 0, 64, 128, 1, Material::Wall);
        paused.set_simulation_region(RectI64{0, 0, 128, 64});
        for (int t = 0; t < 40; ++t) { (void)walled.tick(); (void)paused.tick(); }
        for (int y = 0; y < 64; ++y)
            for (int x = 0; x < 128; ++x)
                require(walled.stored_material(x, y) == paused.stored_material(x, y) &&
                            walled.stored_state_a(x, y) == paused.stored_state_a(x, y),
                        "Water on a paused floor evolved differently from Water on a wall");
        require(walled.wave_flow_diagnostics().spill_units == paused.wave_flow_diagnostics().spill_units,
                "a paused floor was treated as open air");
        // Original Wave (spill disabled) keeps its qualified law, including its
        // known stale-support read of a paused floor; spill does not inherit it.
    }
}

void parcels_are_not_born_in_paused_cores() {
    World world(config(Mode::Hybrid, 1));
    box(world, 256, 256);
    rect(world, 150, 150, 1, 1, Material::Water);
    world.set_simulation_region(RectI64{0, 0, 64, 64});
    const auto injected = world.inject_ballistic_water(150 * 256 + 128, 140 * 256 + 128, 0, 0, 100);
    require(injected.outcome == BallisticLaunchOutcome::Paused && world.ballistic_parcel_count() == 0,
            "a parcel was injected inside a paused Wave core");
    const auto launched = world.launch_ballistic_water(150, 150, 30 * 256 + 128, 30 * 256 + 128, 0, 0, 0, 255);
    require(launched.outcome == BallisticLaunchOutcome::Paused && world.liquid_mass(150, 150) == 255U,
            "Water was launched from a paused Wave core");
    const auto inside = world.inject_ballistic_water(30 * 256 + 128, 30 * 256 + 128, 0, 0, 100);
    require(inside.outcome == BallisticLaunchOutcome::Launched, "selected-core injection regressed");
}

void full_parcel_pool_is_counted_and_clamped() {
    // A per-tick budget larger than the free slots still launches into the
    // free slots; a full pool is an explicit, counted outcome.
    auto cfg = config(Mode::Hybrid, 4);
    cfg.ballistic_water.capacity = 300;
    cfg.wave_flow.spill.launch_budget = 256;
    World world(cfg);
    box(world, 384, 256);
    rect(world, 1, 105, 120, 150, Material::Water);
    for (int k = 0; k < 120; ++k)
        require(world.inject_ballistic_water((200 + k) * 256 + 128, 20 * 256 + 128, 0, 0, 10).outcome ==
                    BallisticLaunchOutcome::Launched, "filler parcel refused");
    const RectI64 all{0, 0, 384, 256};
    const auto before = owned(world, all);
    std::uint64_t peak = 0;
    for (int t = 0; t < 60; ++t) {
        (void)world.tick();
        peak = std::max<std::uint64_t>(peak, world.ballistic_parcel_count());
        require(world.ballistic_parcel_count() <= 300U, "parcel capacity exceeded");
    }
    const auto diagnostics = world.wave_flow_diagnostics();
    require(diagnostics.launched_parcels > 0, "a budget above the free slots disabled the release");
    require(peak == 300U && diagnostics.launch_capacity_skips > 0, "a full parcel pool was not reached or not counted");
    require_ledger_closes(world, all, before, "clamped budget");
}

void check_diagonal_wall(WorldConfig cfg) {
    // A 45-degree wall one cell thick: Water may neither land beyond it from
    // the deposit ring nor step through it diagonally in flight.
    const int n = 128;
    World world(cfg);
    box(world, n, n);
    for (int x = 1; x < n - 1; ++x) {
        const int y = 103 - x;
        if (y > 0 && y < n - 1) world.set(x, y, Material::Wall);
    }
    for (int y = 1; y < n - 1; ++y)
        for (int x = 1; x < n - 1; ++x)
            if (x + y < 103) world.set(x, y, Material::Water);
    const auto far_side = [&] {
        std::uint64_t total = 0;
        for (int y = 1; y < n - 1; ++y)
            for (int x = 1; x < n - 1; ++x)
                if (x + y > 103 && world.stored_material(x, y) == Material::Water) total += world.liquid_mass(x, y);
        return total;
    };
    // Carve actual launch cells: these positions were Water in the old test,
    // so all 40 injections refused and no parcel ever exercised the wall.
    for (int k = 0; k < 40; ++k) world.set(20 + k, 82 - k, Material::Empty);
    const RectI64 all{0, 0, n, n};
    const auto initial = owned(world, all);
    for (int k = 0; k < 40; ++k) {
        const auto injected = world.inject_ballistic_water((20 + k) * 256 + 128, (82 - k) * 256 + 128, 300, 300, 100);
        require(injected.outcome == BallisticLaunchOutcome::Launched, "diagonal wall test parcel was refused");
    }
    require(world.ballistic_parcel_count() == 40U, "diagonal wall test did not create its in-flight parcels");
    for (int t = 0; t < 200; ++t) {
        (void)world.tick();
        require(far_side() == 0U, "Water crossed a one-cell diagonal wall");
        if (t == 0) require(world.ballistic_water_snapshot().ledger.terrain_contacts > 0U,
                            "diagonal wall test did not exercise a parcel/terrain collision");
        std::vector<BallisticParcel> parcels(world.ballistic_parcel_count());
        (void)world.copy_ballistic_parcels(parcels);
        for (const auto& p : parcels)
            require((p.x >> 8) + (p.y >> 8) < 103, "a parcel flew through a one-cell diagonal wall");
    }
    require_ledger_closes(world, all, initial + 4000U, "diagonal wall parcels");
}

void diagonal_one_cell_wall_holds() {
    auto cfg = config(Mode::Hybrid, 1);
    check_diagonal_wall(cfg);
    cfg.wave_flow.spill.sheet_rate = 127;
    cfg.wave_flow.spill.coyote_ticks = 8;
    check_diagonal_wall(cfg);
    cfg.wave_flow.spill.full_face = 1;
    check_diagonal_wall(cfg);
}

void wet_and_dry_corners_stop_ballistic_water() {
    // The destination is sealed by four axis neighbours. Its existing Water
    // must not turn the diagonal crossing into an unchecked preferred merge.
    for (const auto mode : {Mode::Ballistic, Mode::Hybrid})
        for (const bool wet : {false, true})
            for (const int dx : {-1, 1})
                for (const int dy : {-1, 1}) {
                    std::uint64_t reference = 0;
                    for (const auto workers : {1U, 4U}) {
                        auto cfg = config(mode, workers);
                        cfg.wave_flow.spill.launch_budget = 0;
                        World world(cfg);
                        box(world, 64, 64);
                        const int x = 20 + dx, y = 20 + dy;
                        world.set(x - 1, y, Material::Wall);
                        world.set(x + 1, y, Material::Wall);
                        world.set(x, y - 1, Material::Wall);
                        world.set(x, y + 1, Material::Wall);
                        if (wet) require(world.set_cell_state(x, y, Material::Water, 100, 0), "wet corner setup refused");
                        const auto parcel = world.inject_ballistic_water(20 * 256 + 128, 20 * 256 + 128,
                                                                        dx * 256, dy * 256, 100);
                        require(parcel.outcome == BallisticLaunchOutcome::Launched, "corner test parcel refused");
                        for (int tick = 0; tick < 32; ++tick) {
                            (void)world.tick();
                            require(world.liquid_mass(x, y) == (wet ? 100U : 0U),
                                    "ballistic Water entered a sealed diagonal destination");
                            if (tick == 0) require(world.ballistic_water_snapshot().ledger.terrain_contacts > 0U,
                                                  "corner did not stop the incoming parcel");
                        }
                        require_ledger_closes(world, {0, 0, 64, 64}, wet ? 200U : 100U, "sealed ballistic corner");
                        const auto hash = world.physical_state_hash();
                        if (workers == 1U) reference = hash;
                        else require(hash == reference, "corner collision depends on worker count");
                    }
                }
}

void automatic_spill_bounds_parcel_coordinates() {
    // The native cell domain is wider than the +/-2^52 q256 spawn domain.
    // A ten-cell column has one exposed, supported face at its bottom row,
    // making each result an actual automatic launch rather than a helper test.
    constexpr std::int64_t edge = std::int64_t{1} << 44;
    constexpr std::int64_t far = std::int64_t{1} << 56;
    struct Case { std::int64_t x, y; int side; bool admitted; const char* name; };
    const Case cases[] = {
        {edge - 2, 20, 1, true, "positive X last centre"},
        {edge - 1, 20, 1, false, "positive X first excluded centre"},
        {-edge + 1, 20, -1, true, "negative X first centre"},
        {-edge, 20, -1, false, "negative X first excluded centre"},
        {20, edge - 10, 1, true, "positive Y last centre"},
        {20, edge - 9, 1, false, "positive Y first excluded centre"},
        {20, -edge - 9, -1, true, "negative Y first centre"},
        {20, -edge - 10, -1, false, "negative Y first excluded centre"},
        {far, 20, 1, false, "positive X multiplication limit"},
        {-far, 20, -1, false, "negative X multiplication limit"},
        {20, far, 1, false, "positive Y multiplication limit"},
        {20, -far, -1, false, "negative Y multiplication limit"},
    };
    for (const bool face_release : {false, true}) for (const auto& test : cases) {
        std::uint64_t reference = 0;
        for (const auto workers : {1U, 4U}) {
            auto cfg = config(face_release ? Mode::Ballistic : Mode::Hybrid, workers);
            cfg.ballistic_water.face_release = face_release;
            cfg.ballistic_water.face_period = 1;
            World world(cfg);
            for (int row = 0; row < 10; ++row) {
                world.set(test.x, test.y + row, Material::Water);
                world.set(test.x - test.side, test.y + row, Material::Wall);
                // Legacy face release needs two adjacent open cells; spill
                // needs only the bottom face. Both nominate exactly one donor.
                if (row < (face_release ? 8 : 9)) world.set(test.x + test.side, test.y + row, Material::Wall);
            }
            world.set(test.x, test.y + 10, Material::Wall);
            const RectI64 all{test.x - 32, test.y - 16, 65, 64};
            (void)world.tick();
            const auto first = world.wave_flow_diagnostics();
            const auto flight = world.ballistic_water_snapshot();
            require(flight.ledger.launched_parcels == (test.admitted ? 1U : 0U), std::string(test.name) + ": wrong launch admission");
            if (face_release) require(flight.ledger.face_releases == (test.admitted ? 1U : 0U),
                                      std::string(test.name) + ": wrong face-release admission");
            else require(first.launch_refusals == (test.admitted ? 0U : 1U), std::string(test.name) + ": missing explicit refusal");
            if (!test.admitted) {
                if (!face_release) require(world.liquid_mass(test.x, test.y + 9) == 255U,
                                           std::string(test.name) + ": refused launch removed source Water");
                require(world.ballistic_parcel_count() == 0U, std::string(test.name) + ": refusal created a parcel");
            }
            require_ledger_closes(world, all, 2550U, test.name);
            (void)world.tick();
            if (!test.admitted && !face_release) require(world.wave_flow_diagnostics().spill_units > 0U,
                                                        std::string(test.name) + ": refused launch prevented grid spill fallback");
            require(!world.has_failed(), std::string(test.name) + ": coordinate refusal failed the World");
            require_ledger_closes(world, all, 2550U, test.name);
            const auto hash = world.physical_state_hash();
            if (workers == 1U) reference = hash;
            else require(hash == reference, std::string(test.name) + ": coordinate admission depends on workers");
        }
    }
}

void blobs_and_stream_share_conserve_and_are_deterministic() {
    // Every look combination keeps exact ownership and worker independence.
    for (const int share : {0, 64}) {
        for (const int blobs : {0, 1}) {
            std::uint64_t reference = 0;
            for (const auto workers : {1U, 4U}) {
                auto cfg = config(Mode::Hybrid, workers);
                cfg.wave_flow.spill.stream_share = share;
                cfg.wave_flow.spill.catch_falling = blobs;
                World world(cfg);
                const int width = 384, height = 320;
                box(world, width, height);
                rect(world, 1, 120, 139, 4, Material::Wall);
                rect(world, 1, 60, 139, 60, Material::Water);
                const RectI64 all{0, 0, width, height};
                const auto before = owned(world, all);
                for (int t = 0; t < 300; ++t) {
                    (void)world.tick();
                    if (t % 100 == 99) require_ledger_closes(world, all, before, "blobs/stream share");
                }
                require(world.wave_flow_diagnostics().launched_parcels > 0, "release threw nothing");
                if (workers == 1U) reference = world.physical_state_hash();
                else require(world.physical_state_hash() == reference, "blobs/stream share depend on worker count");
            }
        }
    }
    auto bad = config(Mode::Hybrid);
    bad.wave_flow.spill.catch_falling = 2;
    bool refused = false;
    try { World w(bad); } catch (const std::invalid_argument&) { refused = true; }
    require(refused, "invalid blobs value admitted");
}

void body_push_scales_with_water_amount() {
    // A body under a faint trickle and under a full sheet. By-mass push follows
    // the Water present; the default keeps the original per-cell push exactly.
    const auto push = [](std::int32_t body_push, std::int32_t by_mass, std::uint16_t cell_mass) {
        auto cfg = config(Mode::Original, 1);
        cfg.wave_flow.body_push = body_push;
        cfg.wave_flow.body_push_by_mass = by_mass;
        World w(cfg);
        box(w, 128, 64);
        w.configure_transient_obstacles({0, 0, 128, 64});
        for (int x = 20; x < 60; ++x) require(w.set_cell_state(x, 39, Material::Water, cell_mass, 0), "setup refused");
        const auto quantity = w.water_quantity({0, 0, 128, 64});
        w.clear_transient_contact_observations();
        for (int y = 40; y < 46; ++y) for (int x = 10; x < 70; ++x) (void)w.set_transient_obstacle(x, y, 1);
        (void)w.tick();
        require(w.water_quantity({0, 0, 128, 64}) == quantity, "body push changed Water");
        return std::pair<std::int64_t, std::uint64_t>{w.transient_contact_impulse_y(1), w.transient_contact_count(1)};
    };
    const auto original_full = push(256, 0, 255), original_trickle = push(256, 0, 4);
    require(original_full.first > 0 && original_full.first == original_trickle.first,
            "original Wave push should be per wet cell");
    const auto mass_full = push(256, 1, 255), mass_trickle = push(256, 1, 4);
    require(mass_full.first == original_full.first, "a full cell must push as before with by-mass push");
    require(mass_trickle.first * 20 < mass_full.first && mass_trickle.second == mass_full.second,
            "a trickle still pushed like a sheet with by-mass push");
    require(push(0, 1, 255).first == 0 && push(512, 0, 255).first == 2 * original_full.first, "body push scale not applied");
    auto bad = config(Mode::Original);
    bad.wave_flow.body_push = 1025;
    bool refused = false;
    try { World w(bad); } catch (const std::invalid_argument&) { refused = true; }
    require(refused, "invalid body push admitted");
}

// Generic Ballistic Water (splashes, sprays, body launches) under Wave with
// spill off: injected and launched parcels fly, land and rejoin the grid with
// exact ownership, for any worker count.
void generic_ballistic_water_runs_under_wave() {
    std::uint64_t reference = 0;
    for (const auto workers : {1U, 4U}) {
        World world(config(Mode::Ballistic, workers));
        const int width = 256, height = 192;
        box(world, width, height);
        rect(world, 1, 140, width - 2, height - 141, Material::Water);
        rect(world, 120, 60, 3, 80, Material::Wall);
        const RectI64 all{0, 0, width, height};
        auto expected = owned(world, all);
        for (int k = 0; k < 120; ++k) {
            const auto r = world.inject_ballistic_water((10 + 2 * k) * 256 + 128, (20 + k % 30) * 256 + 128,
                                                        (k % 7 - 3) * 160, -(k % 5) * 90, static_cast<std::uint32_t>(40 + k % 200));
            require(r.outcome == BallisticLaunchOutcome::Launched, "injection refused under Wave");
            expected += r.quantity;
        }
        for (int x = 20; x < 100; x += 4) {
            const auto r = world.launch_ballistic_water(x, 140, x * 256 + 128, 130 * 256 + 128, 200, -700, 0, 255);
            require(r.outcome == BallisticLaunchOutcome::Launched && r.quantity == 255U, "launch from Wave Water refused");
        }
        require_ledger_closes(world, all, expected, "generic ballistic setup");
        for (int t = 0; t < 600; ++t) {
            (void)world.tick();
            require(!world.has_failed(), "generic Ballistic Water failed a Wave World");
            if (t % 100 == 99) require_ledger_closes(world, all, expected, "generic ballistic under Wave");
        }
        const auto flight = world.ballistic_water_snapshot();
        require(flight.ledger.deposited_parcels > 100U && flight.ledger.surface_entries > 0U,
                "generic parcels did not land and rejoin Wave Water");
        require(world.wave_flow_diagnostics().launched_parcels == 0U && world.wave_flow_diagnostics().spill_units == 0U,
                "spill acted while disabled");
        if (workers == 1U) reference = world.physical_state_hash();
        else require(world.physical_state_hash() == reference, "generic Ballistic Water under Wave depends on worker count");
    }
    // Paused cores and overfilled cells keep the same contracts without spill.
    World paused(config(Mode::Ballistic, 1));
    box(paused, 256, 256);
    paused.set_simulation_region(RectI64{0, 0, 64, 64});
    require(paused.inject_ballistic_water(150 * 256 + 128, 140 * 256 + 128, 0, 0, 100).outcome == BallisticLaunchOutcome::Paused,
            "a parcel was injected inside a paused Wave core");
    World full(config(Mode::Ballistic, 1));
    box(full, 64, 64);
    rect(full, 10, 10, 5, 1, Material::Wall);
    rect(full, 10, 12, 5, 1, Material::Wall);
    rect(full, 10, 11, 1, 1, Material::Wall);
    rect(full, 14, 11, 1, 1, Material::Wall);
    rect(full, 11, 11, 3, 1, Material::Water);
    require(full.set_cell_state(12, 11, Material::Water, 60000, 0), "Wave refused a legal overfilled cell");
    const auto launched = full.launch_ballistic_water(12, 11, 30 * 256 + 128, 30 * 256 + 128, 0, 0, 0, 1000);
    require(launched.outcome == BallisticLaunchOutcome::Launched && launched.quantity == 255U &&
                full.liquid_mass(12, 11) == 60000U - 255U, "generic launch from an overfilled Wave cell was not one cell");
}

// WCX-FR face release is admitted under Wave without spill and conserves.
void face_release_without_spill_conserves() {
    std::uint64_t reference = 0;
    for (const auto workers : {1U, 4U}) {
        auto cfg = config(Mode::Ballistic, workers);
        cfg.ballistic_water.face_release = true;
        World world(cfg);
        const int width = 384, height = 256;
        box(world, width, height);
        rect(world, 1, height - 1 - 150, 120, 150, Material::Water);
        const RectI64 all{0, 0, width, height};
        const auto before = owned(world, all);
        for (int t = 0; t < 300; ++t) {
            (void)world.tick();
            require(!world.has_failed(), "face release failed a Wave World");
            if (t % 100 == 99) require_ledger_closes(world, all, before, "face release under Wave");
        }
        require(world.ballistic_water_snapshot().ledger.face_releases > 0U, "face release threw nothing under Wave");
        if (workers == 1U) reference = world.physical_state_hash();
        else require(world.physical_state_hash() == reference, "face release under Wave depends on worker count");
    }
}

// Stream draw pours an extra share from the face without thinning the throw;
// stream share splits the throw. Both conserve and are worker independent.
void stream_draw_keeps_the_throw_and_conserves() {
    struct Run { std::uint64_t launched = 0, grid = 0, hash = 0; };
    const auto run = [](int share, int draw, std::uint32_t workers, int ticks) {
        auto cfg = config(Mode::Hybrid, workers);
        cfg.wave_flow.spill.stream_share = share;
        cfg.wave_flow.spill.stream_draw = draw;
        World world(cfg);
        const int width = 384, height = 320;
        box(world, width, height);
        rect(world, 1, 120, 139, 4, Material::Wall);
        rect(world, 1, 60, 139, 60, Material::Water);
        const RectI64 all{0, 0, width, height};
        const auto before = owned(world, all);
        for (int t = 0; t < ticks; ++t) {
            (void)world.tick();
            require(!world.has_failed(), "stream draw failed the World");
            if (t % 50 == 49) require_ledger_closes(world, all, before, "stream draw");
        }
        const auto d = world.wave_flow_diagnostics();
        return Run{d.launched_units, d.spill_units, world.physical_state_hash()};
    };
    const auto plain = run(0, 0, 4, 40), drawn = run(0, 128, 4, 40), split = run(128, 0, 4, 40);
    require(drawn.grid > plain.grid, "stream draw poured no extra grid stream");
    require(drawn.launched > split.launched, "stream draw thinned the throw like stream share");
    require(drawn.hash != plain.hash, "stream draw is not part of physical identity");
    for (const int draw : {64, 255})
        require(run(0, draw, 1, 150).hash == run(0, draw, 4, 150).hash, "stream draw depends on worker count");
    require(run(64, 64, 1, 150).hash == run(64, 64, 4, 150).hash, "stream draw with stream share depends on worker count");
    auto bad = config(Mode::Hybrid);
    bad.wave_flow.spill.stream_draw = 256;
    bool refused = false;
    try { World w(bad); } catch (const std::invalid_argument&) { refused = true; }
    require(refused, "stream draw above 255 admitted");
    // Every face pours at most its own share, whatever stream share plus stream
    // draw ask for: a one-cell ridge with drops on both sides must not overdraw.
    for (const auto& [share, draw] : {std::pair{128, 255}, std::pair{255, 255}, std::pair{200, 200}}) {
        for (const auto workers : {1U, 4U}) {
            auto cfg = config(Mode::Hybrid, workers);
            cfg.wave_flow.spill.stream_share = share;
            cfg.wave_flow.spill.stream_draw = draw;
            World world(cfg);
            box(world, 256, 200);
            for (int x = 20; x < 236; x += 12) {
                rect(world, x, 120, 1, 79, Material::Wall);   // one-cell pillars
                // A one-cell column whose cells are part-full: a full cell is
                // already protected by the half-cell receiver cap, a part-full
                // one under a tall head is not.
                for (int y = 60; y < 120; ++y)
                    require(world.set_cell_state(x, y, Material::Water, static_cast<std::uint16_t>(120 + (x * 7 + y * 3) % 90), 0),
                            "column Water refused");
            }
            const RectI64 all{0, 0, 256, 200};
            const auto before = owned(world, all);
            for (int t = 0; t < 120; ++t) {
                (void)world.tick();
                require(!world.has_failed(), "stream share plus stream draw overdrew a two-sided face");
            }
            require_ledger_closes(world, all, before, "two-sided stream draw");
        }
    }
}

// Spill-on identity is pinned from the source before stream draw existed
// (8fc24b82 lineage, HEAD 68e0db19): stream_draw = 0 must reproduce it exactly,
// and a non-zero stream_draw must enter both hashes from tick 0.
void stream_draw_zero_is_the_earlier_spill_world() {
    struct Pin { int ballistic, share; std::uint64_t physical, state; };
    constexpr Pin kPins[] = {
        {0, 0, 0x52e829f3cb1be141ULL, 0xf005b77dbc1b9234ULL},
        {0, 64, 0x53e78f8bcb64f901ULL, 0x3607e6cf5512cff4ULL},
        {1, 0, 0x52796ca29d7a2ec9ULL, 0xd23bc389f5766534ULL},
        {1, 64, 0x8739a49c8ea34e20ULL, 0xc897f8bd4d68bdf8ULL},
    };
    const auto build = [](int ballistic, int share, int draw) {
        auto cfg = config(ballistic != 0 ? Mode::Hybrid : Mode::Spill, 4);
        cfg.wave_flow.spill.stream_share = share;
        cfg.wave_flow.spill.stream_draw = draw;
        auto world = std::make_unique<World>(cfg);
        box(*world, 384, 320);
        rect(*world, 1, 120, 139, 4, Material::Wall);
        rect(*world, 1, 60, 139, 60, Material::Water);
        return world;
    };
    for (const auto& pin : kPins) {
        auto world = build(pin.ballistic, pin.share, 0);
        for (int t = 0; t < 120; ++t) (void)world->tick();
        require(world->physical_state_hash() == pin.physical && world->state_hash() == pin.state,
                "stream_draw = 0 diverged from the pinned spill World (ballistic " + std::to_string(pin.ballistic) +
                    ", share " + std::to_string(pin.share) + ")");
        auto zero = build(pin.ballistic, pin.share, 0), one = build(pin.ballistic, pin.share, 1);
        require(zero->physical_state_hash() != one->physical_state_hash() && zero->state_hash() != one->state_hash(),
                "stream_draw is missing from a hash before any tick");
    }
}

void sheet_releases_deep_rows_and_keeps_crest_spray() {
    auto cfg = config(Mode::Hybrid, 4);
    std::uint64_t original_grid = 0, original_spray = 0;
    for (int sheet : {0, 64}) {
        cfg.wave_flow.spill.sheet_rate = sheet;
        World world(cfg);
        box(world, 256, 128);
        rect(world, 1, 64, 127, 1, Material::Wall);
        rect(world, 1, 40, 127, 24, Material::Water);
        const RectI64 all{0, 0, 256, 128};
        const auto before = owned(world, all);
        (void)world.tick();
        const auto grid = world.water_quantity({128, 40, 1, 24});
        const auto spray = world.wave_flow_diagnostics().launched_parcels;
        require_ledger_closes(world, all, before, "tall sheet");
        if (sheet == 0) {
            original_grid = grid;
            original_spray = spray;
        } else {
            require(grid > original_grid + 16 * 100, "sheet failed to discharge the deep rows");
            require(spray == 2 && spray < original_spray, "sheet failed to reserve spray for the top two rows");
        }
    }
}

void full_face_covers_dry_and_falling_receivers() {
    // A full-height face crossing two 32-row active bands and a chunk edge.
    // The second fixture has a full falling sheet in the spawn column.
    constexpr int top = 32, height = 96, lip = 64;
    for (const bool curtain : {false, true}) {
        std::uint64_t reference = 0;
        for (const unsigned workers : {1U, 6U}) {
            auto cfg = config(Mode::Hybrid, workers);
            cfg.wave_flow.spill.sheet_rate = 64;
            cfg.wave_flow.spill.coyote_ticks = 4;
            cfg.wave_flow.spill.stream = 255;
            World original(cfg);
            cfg.wave_flow.spill.full_face = 1;
            World world(cfg);
            require(original.physical_state_hash() != world.physical_state_hash() && original.state_hash() != world.state_hash(),
                    "enabled full-face release is absent from identity");
            for (auto* w : {&world, &original}) {
                box(*w, 128, 192);
                rect(*w, 1, top + height, lip - 1, 1, Material::Wall);
                rect(*w, 1, top, lip - 1, height, Material::Water);
                if (curtain) rect(*w, lip, top - 3, 1, height, Material::Water);
                const auto initial = owned(*w, {0, 0, 128, 192});
                (void)w->tick();
                require_ledger_closes(*w, {0, 0, 128, 192}, initial, "96-row wall");
            }
            require(original.wave_flow_diagnostics().launched_parcels <= 2, "historical sheet exceeded its two-row spray");
            std::vector<BallisticParcel> parcels(world.ballistic_parcel_count());
            (void)world.copy_ballistic_parcels(parcels);
            std::array<bool, height> seen{};
            for (const auto& p : parcels) {
                const auto y = static_cast<int>(p.y / BallisticWaterConfig::kQ);
                require(p.x / BallisticWaterConfig::kQ == lip && p.vx > 0 && y >= top && y < top + height,
                        "wall threw outside the exposed face");
                require(p.quantity <= 127 && p.quantity != 0, "one row exceeded its parcel share");
                require(p.coyote_left == (y == top ? 4 : 0), "submerged spray received crest grace");
                seen[static_cast<std::size_t>(y - top)] = true;
            }
            require(std::all_of(seen.begin(), seen.end(), [](bool wet) { return wet; }),
                    "a deep row of the full-height face failed to throw");
            for (int y = top; y < top + height; ++y)
                require(world.liquid_mass(lip, y) != 0, "full-face spray left a hole in the falling grid sheet");
            const auto identity = world.physical_state_hash();
            if (workers == 1) reference = identity;
            else require(reference == identity, "full-face coverage changed with worker count");
            std::printf("FULL_FACE curtain=%d workers=%u rows=%zu previous=%llu units=%llu grid=%llu\n",
                        curtain, workers, parcels.size(), static_cast<unsigned long long>(original.wave_flow_diagnostics().launched_parcels),
                        static_cast<unsigned long long>(world.wave_flow_diagnostics().launched_units),
                        static_cast<unsigned long long>(world.water_quantity({lip, top, 1, height})));
        }
    }
}

void full_face_curtain_head_is_independent_of_parcel_slots() {
    // No parcel can reach the launch threshold. Filling the pool with a
    // distant jet must not reverse flow between a 64-unit lip and a passing
    // 128-unit curtain. Both have exactly the same Water near the face.
    auto cfg = config(Mode::Hybrid, 1);
    cfg.ballistic_water.capacity = 1;
    cfg.wave_flow.spill.full_face = 1;
    cfg.wave_flow.spill.sheet_rate = 127;
    cfg.wave_flow.spill.launch_min = 255;
    std::uint64_t outward = 0;
    for (const bool full : {false, true}) {
        World w(cfg);
        box(w, 128, 192);
        w.set(62, 99, Material::Wall);
        w.set(63, 100, Material::Wall);
        require(w.set_cell_state(63, 99, Material::Water, 64, 0) &&
                w.set_cell_state(64, 96, Material::Water, 128, 0), "small lip setup");
        if (full) {
            const auto jet = w.inject_ballistic_water(108 * 256, 20 * 256, 0, 0, 20);
            require(jet.outcome == BallisticLaunchOutcome::Launched, "distant jet setup");
        }
        const auto initial = owned(w, {0, 0, 128, 192});
        (void)w.tick();
        const auto remaining = w.liquid_mass(63, 99);
        require(remaining < 64, "falling curtain pushed into the resting lip");
        if (full) require(remaining == outward && w.wave_flow_diagnostics().launch_capacity_skips == 1,
                          "parcel capacity changed the curtain pressure");
        else outward = remaining;
        require_ledger_closes(w, {0, 0, 128, 192}, initial, "full-face curtain pressure");
    }
}

void full_face_freezes_paused_receivers_and_bounds_max_overfill() {
    auto cfg = config(Mode::Hybrid, 6);
    auto& spill = cfg.wave_flow.spill;
    spill.full_face = 1;
    spill.sheet_rate = 64;
    spill.stream_draw = 255;
    World edge(cfg);
    const RectI64 all{0, 0, 256, 192};
    box(edge, 256, 192);
    rect(edge, 1, 96, 127, 1, Material::Wall);
    rect(edge, 1, 72, 127, 24, Material::Water);
    const auto initial = owned(edge, all);
    edge.set_simulation_region(RectI64{0, 0, 128, 192});
    for (int tick = 0; tick < 8; ++tick) (void)edge.tick();
    require(edge.ballistic_parcel_count() == 0 && edge.water_quantity({128, 0, 128, 192}) == 0,
            "full-face discharge crossed an unselected core");
    edge.set_simulation_region(std::nullopt);
    (void)edge.tick();
    require(edge.ballistic_parcel_count() == 24, "whole wall did not wake after re-entry");
    require_ledger_closes(edge, all, initial, "full-face region re-entry");

    World over(cfg);
    box(over, 256, 192);
    over.set(128, 63, Material::Wall);
    rect(over, 128, 65, 1, 124, Material::Wall);
    constexpr std::uint16_t mass = 65535;
    require(over.set_cell_state(128, 64, Material::Water, mass, 0), "maximal ridge setup");
    (void)over.tick();
    std::array<BallisticParcel, 2> parcels{};
    require(over.copy_ballistic_parcels(parcels) == 2, "maximal ridge did not throw on both sides");
    for (const auto& p : parcels)
        require(p.quantity <= 255 && over.liquid_mass(p.x / 256, p.y / 256) <= 127, "maximal ridge overflowed a receiver");
    require_ledger_closes(over, all, mass, "maximal full-face ridge");
}

void full_face_shares_slots_across_tall_walls() {
    constexpr int top = 24, height = 640, lip = 32;
    std::uint64_t reference = 0;
    for (const unsigned workers : {1U, 6U}) {
        auto cfg = config(Mode::Hybrid, workers);
        auto& spill = cfg.wave_flow.spill;
        spill.full_face = 1;
        spill.sheet_rate = 64;
        spill.launch_budget = 128;
        cfg.ballistic_water.capacity = 24;
        World w(cfg);
        const RectI64 all{0, 0, 64, 704};
        box(w, 64, 704);
        rect(w, 1, top + height, lip - 1, 1, Material::Wall);
        rect(w, 1, top, lip - 1, height, Material::Water);
        const auto initial = owned(w, all);
        (void)w.tick();
        const auto stats = w.wave_flow_diagnostics();
        require(stats.launched_parcels == 24 && stats.launch_deferrals == height - 24,
                "full face did not account for bounded candidates, pool slots and deferrals");
        std::array<BallisticParcel, 24> parcels{};
        (void)w.copy_ballistic_parcels(parcels);
        std::array<bool, 4> quarter{};
        for (const auto& p : parcels) quarter.at(static_cast<std::size_t>((p.y / 256 - top) * 4 / height)) = true;
        require(std::all_of(quarter.begin(), quarter.end(), [](bool hit) { return hit; }),
                "an entire quarter of the wall was starved by limited pool slots");
        (void)w.tick(); (void)w.tick();
        require(w.wave_flow_diagnostics().launch_capacity_skips > 0, "full pool did not remain explicit");
        require_ledger_closes(w, all, initial, "oversubscribed wall");
        if (workers == 1) reference = w.physical_state_hash();
        else require(w.physical_state_hash() == reference, "oversubscribed wall differs by worker count");
    }
}

void sheet_and_coyote_budget_each_side_of_a_ridge() {
    const RectI64 all{0, 0, 256, 128};
    for (const auto& mode : {std::array{127, 0, 0}, std::array{0, 8, 0}, std::array{127, 8, 0},
                             std::array{0, 0, 1}, std::array{127, 8, 1}}) {
        for (const int share : {0, 128, 255}) {
            std::uint64_t reference = 0;
            for (const unsigned workers : {1U, 2U, 4U, 6U}) {
                auto cfg = config(Mode::Hybrid, workers);
                auto& spill = cfg.wave_flow.spill;
                spill.sheet_rate = mode[0];
                spill.coyote_ticks = mode[1];
                spill.full_face = mode[2];
                spill.stream_share = share;
                spill.stream_draw = 255;
                spill.launch_min = 1;
                spill.launch_budget = 4096;
                cfg.ballistic_water.capacity = 2;
                World world(cfg);
                auto identity = cfg;
                identity.wave_flow.spill.sheet_rate = identity.wave_flow.spill.coyote_ticks = identity.wave_flow.spill.full_face = 0;
                World before(identity);
                require(world.physical_state_hash() != before.physical_state_hash() && world.state_hash() != before.state_hash(),
                        "an opt-in discharge control is missing from identity");
                box(world, 256, 128);
                rect(world, 128, 52, 1, 75, Material::Wall);
                rect(world, 134, 1, 1, 126, Material::Wall);
                constexpr std::uint16_t mass = 237;
                require(world.set_cell_state(128, 51, Material::Water, mass, 0), "odd ridge setup refused");
                (void)world.tick();
                std::array<BallisticParcel, 2> parcels{};
                require(world.copy_ballistic_parcels(parcels) == 2, "one face of the ridge failed to launch");
                std::array<unsigned, 2> spent{world.liquid_mass(127, 51), world.liquid_mass(129, 51)};
                for (const auto& p : parcels) spent[p.vx > 0 ? 1 : 0] += p.quantity;
                for (auto side : spent) require(side > 0 && side <= mass / 2, "one ridge face exceeded its donor half");
                require(spent[0] + spent[1] + world.liquid_mass(128, 51) == mass, "first round ridge ledger disagrees");
                for (int t = 0; t < 160; ++t) (void)world.tick();
                require(world.wave_flow_diagnostics().launch_capacity_skips > 0, "tiny pool never fell back to grid flow");
                require(world.water_quantity({135, 0, 121, 128}) == 0, "sheet leaked through the straight wall");
                require_ledger_closes(world, all, mass, "ridge and straight wall");
                if (workers == 1) reference = world.physical_state_hash();
                else require(world.physical_state_hash() == reference, "sheet/crest flight differs by worker count");
            }
        }
    }
}

void retained_crest_adopts_replacement_flight_law() {
    auto source_cfg = config(Mode::Hybrid);
    source_cfg.ballistic_water.air_drag = 0;
    source_cfg.wave_flow.spill.coyote_ticks = 4;
    World source(source_cfg);
    source.set(32, 32, Material::Wall);
    source.set(32, 31, Material::Water);
    (void)source.tick();
    std::array<BallisticParcel, 2> born{}, copied{};
    require(source.copy_ballistic_parcels(born) == 2 && born.front().coyote_left == 4, "need two live crests");
    normalization::FinalSetupInput input;
    input.setup.domain = {0, 0, 64, 64};
    for (int grace : {-1, 0, 2}) {
        auto cfg = source_cfg;
        cfg.wave_flow.enabled = grace >= 0;
        cfg.wave_flow.spill.enabled = grace > 0;
        cfg.wave_flow.spill.coyote_ticks = std::max(0, grace);
        auto prepared = PreparedWorldBuilder::prepare(cfg, input, normalization::NormalizationOptIn::None);
        require(std::holds_alternative<PreparedWorld>(prepared), "replacement refused");
        auto target = std::get<PreparedWorld>(prepared).take_world();
        const auto receipt = target->inherit_workbench_liquid_state(source, {0, 0, 64, 64}, false, false);
        require(receipt.discarded_in_flight_water == 0 && receipt.preserved_in_flight_water ==
            born[0].quantity + born[1].quantity, "replacement lost crest mass");
        require(target->copy_ballistic_parcels(copied) == born.size(), "missing inherited crests");
        for (std::size_t i = 0; i < copied.size(); ++i) {
            require(copied[i].coyote_left == std::max(grace, 0) && copied[i].vx == born[i].vx &&
                copied[i].vy == born[i].vy, "inherited flight did not adopt new grace or preserve velocity");
        }
        // Generic Ballistic saves do not serialize Wave state. Its restored
        // owner must follow exactly the same flight after conversion.
        std::unique_ptr<World> restored;
        if (grace < 0) restored = World::restore_physical_state(cfg, target->save_physical_state());
        (void)target->tick();
        require(target->copy_ballistic_parcels(copied) == born.size() &&
            copied[0].vy == (grace > 0 ? 0 : cfg.ballistic_water.gravity_q), "wrong gravity after Apply");
        if (restored) {
            (void)restored->tick();
            require(restored->physical_state_hash() == target->physical_state_hash(), "converted ballistic save diverged");
        }
    }
}

void sheet_starts_from_rest_without_wave_gain() {
    auto cfg = config(Mode::Spill);
    cfg.wave_flow.gain = 0;
    cfg.wave_flow.spill.sheet_rate = 127;
    World world(cfg);
    rect(world, 30, 40, 8, 1, Material::Wall);
    rect(world, 30, 20, 8, 20, Material::Water);
    rect(world, 29, 19, 1, 22, Material::Wall);
    (void)world.tick();
    require(world.water_quantity({38, 20, 1, 20}) > 0, "positive sheet head failed to discharge from rest");
    require(world.water_quantity({28, 19, 1, 22}) == 0, "sheet started through a wall");
    require_ledger_closes(world, {0, 0, 64, 64}, 8 * 20 * 255, "zero-gain sheet");
}

void deep_draw_limits_opposing_pool_faces() {
    const auto run = [](int height, int limit, int coast, unsigned workers, int draw = 127) {
        auto cfg = config(Mode::Spill, workers);
        cfg.wave_flow.gain = 512;
        cfg.wave_flow.coast = coast;
        cfg.wave_flow.spill.draw = draw;
        cfg.wave_flow.spill.deep_draw = limit;
        World w(cfg);
        box(w, 256, 160);
        rect(w, 126, 130, 5, 1, Material::Wall);
        rect(w, 127, 129, 3, 1, Material::Water);
        rect(w, 128, 130 - height, 1, height, Material::Water);
        const RectI64 region{0, 0, 256, 160};
        const auto before = owned(w, region);
        (void)w.tick();
        require(owned(w, region) == before, "two-sided deep draw lost Water");
        const int left = -w.wave_flow_flux(127, 129), right = w.wave_flow_flux(128, 129);
        require(left == right && right > 0, "opposing faces did not draw symmetrically");
        return std::pair{right, w.state_hash()};
    };
    const auto unlimited = run(5, 0, 32, 1);
    const auto limited = run(5, 64, 32, 1);
    require(limited == run(5, 64, 32, 6), "deep draw worker parity");
    require(unlimited.first > limited.first && limited.first == 64 * 4096, "five-row stack ignored deep draw");
    require(run(4, 64, 32, 1).first == run(4, 0, 32, 1).first, "deep draw slowed a four-row front");
    require(run(5, 64, 96, 1).first == 96 * 4096, "deep draw suppressed ordinary coast");
    require(run(5, 64, 32, 1, 40).first == run(5, 0, 32, 1, 40).first, "deep draw raised ordinary draw");
    auto a = config(Mode::Spill), b = a;
    b.wave_flow.spill.deep_draw = 64;
    World off(a), on(b);
    require(off.state_hash() != on.state_hash() && off.physical_state_hash() != on.physical_state_hash(),
            "active deep draw missing from identity");
}

void floor_gain_requires_a_level_solved_floor() {
    constexpr int x = 127, y = 127;
    const RectI64 all{0, -256, 256, 512};
    auto run = [&](int gain, std::uint32_t workers, bool drop, bool paused, std::uint16_t mass) {
        auto cfg = config(Mode::Hybrid, workers);
        cfg.wave_flow.floor_gain = gain;
        cfg.wave_flow.gain = 0;
        cfg.wave_flow.empty_pour_shift = 1;
        cfg.wave_flow.spill.launch_budget = 0;
        World world(cfg);
        rect(world, x-4, y+1, drop ? 5 : 9, 1, Material::Wall);
        require(world.set_cell_state(x, y, Material::Water, mass, 0), "floor donor setup failed");
        if (paused) world.set_simulation_region(RectI64{0, 0, 256, 128});
        const auto before_state = world.state_hash(), before_physical = world.physical_state_hash();
        (void)world.tick();
        require_ledger_closes(world, all, mass, "floor donor " + std::to_string(mass) + " at four-chunk corner");
        const auto left = world.water_quantity({x-4,y-6,4,8});
        const auto right = world.water_quantity({x+1,y-6,4,8});
        require(left + right <= mass, "two outgoing floor faces overdrew donor");
        return std::array<std::uint64_t,6>{left, right, before_state, before_physical,
                                            world.content_hash(), world.physical_state_hash()};
    };
    const auto plain = run(0, 1, false, false, 177);
    const auto driven = run(4096, 1, false, false, 177);
    require(plain[0] + plain[1] == 0 && driven[0] > 0 && driven[1] > 0,
            "floor gain failed to drive both sides of a resting partial donor");
    require(driven[2] != plain[2] && driven[3] != plain[3], "floor gain absent from identity");
    require(driven == run(4096, 6, false, false, 177), "floor flow depends on worker count");
    require(run(4096, 4, true, false, 177)[1] == 0, "floor acceleration crossed a descending step");
    const auto paused = run(4096, 4, false, true, 177);
    require(paused[0] + paused[1] == 0, "paused terrain supplied floor acceleration");
    (void)run(4096, 6, false, false, 65535);
    // Read the face shared by a three-cell column and its shallower neighbour.
    // The whole supporting path must lead to the same floor elevation.
    const auto top_flux = [](int donor_depth, int receiver_step) {
        constexpr int left = 127, top = 127;
        auto cfg = config(Mode::Hybrid, 4);
        cfg.wave_flow.gain = 0;
        cfg.wave_flow.floor_gain = 4096;
        cfg.wave_flow.spill.launch_budget = 0;
        World world(cfg);
        rect(world, left-2, top+donor_depth, 3, 1, Material::Wall);
        rect(world, left+1, top+donor_depth-receiver_step, 3, 1, Material::Wall);
        for (int k = 0; k < donor_depth; ++k) world.set(left, top+k, Material::Water);
        for (int k = 1; k < donor_depth-receiver_step; ++k) world.set(left+1, top+k, Material::Water);
        (void)world.tick();
        return world.wave_flow_flux(left, top);
    };
    require(top_flux(3, 0) > 0, "third supported row did not carry the surge");
    require(top_flux(4, 0) == 0, "floor acceleration escaped the shallow band");
    require(top_flux(3, 1) == 0, "floor acceleration climbed a riser");
    for (int bad : {-1, 4097}) {
        auto cfg = config(Mode::Hybrid);
        cfg.wave_flow.floor_gain = bad;
        bool refused = false;
        try { World invalid(cfg); } catch (const std::invalid_argument&) { refused = true; }
        require(refused, "invalid floor gain admitted");
    }
}

void coyote_flight_pauses_expires_and_leaves_jets_alone() {
    auto cfg = config(Mode::Hybrid, 4);
    cfg.wave_flow.spill.coyote_ticks = 4;
    cfg.wave_flow.spill.sheet_rate = 64;
    cfg.wave_flow.spill.launch_speed = 512;
    cfg.ballistic_water.capacity = 3;
    cfg.ballistic_water.air_drag = 0;
    World world(cfg);
    const RectI64 all{0, 0, 256, 128};
    box(world, 256, 128);
    world.set(95, 40, Material::Wall);
    world.set(95, 39, Material::Water);
    require(world.inject_ballistic_water(40*256 + 128, 12*256 + 128, 0, 0, 17).outcome ==
            BallisticLaunchOutcome::Launched, "generic jet refused");
    const auto before = owned(world, all);
    (void)world.tick();
    std::array<BallisticParcel, 3> born{}, now{};
    require(world.copy_ballistic_parcels(born) == 3, "expected a generic jet and two crest parcels");
    require(born[0].coyote_left == 0 && born[0].vy == cfg.ballistic_water.gravity_q, "generic jet received crest grace");
    require(born[1].vx * born[2].vx < 0 && born[1].vy == 0 && born[2].vy == 0, "lip did not launch horizontally");
    require(born[1].coyote_left == 4 && born[2].coyote_left == 4, "crest received an incorrect initial duration");
    world.set_simulation_region(RectI64{192, 0, 64, 128});
    for (int t = 0; t < 6; ++t) (void)world.tick();
    require(world.copy_ballistic_parcels(now) == 3 && now == born, "paused crest aged or moved");
    world.set_simulation_region(std::nullopt);
    for (int t = 1; t <= 5; ++t) {
        (void)world.tick();
        require(world.copy_ballistic_parcels(now) == 3, "flight fixture hit an unintended obstacle");
        for (int i : {1, 2}) {
            require(now[i].x == born[i].x + t * born[i].vx, "crest failed to carry horizontal momentum");
            require(now[i].coyote_left == std::max(0, 4 - t), "crest grace expired early or late");
            const auto expected_drop = t > 4 ? cfg.ballistic_water.gravity_q : 0;
            require(now[i].vy == expected_drop && now[i].y == born[i].y + expected_drop, "wrong crest trajectory on expiry");
        }
    }
    const auto flight = world.ballistic_water_snapshot();
    require(flight.momentum_y == flight.ledger.launch_py + flight.ledger.gravity_py, "crest momentum ledger disagrees");
    require_ledger_closes(world, all, before, "coyote flight");
}

// Match the Wave settings in the #678 Windows playtest where the owner
// reported trapped Oil, including full-face spill and ballistic blobs.
WorldConfig oil_tank_config(std::uint32_t workers) {
    auto cfg = config(Mode::Hybrid, workers, 2);
    auto& wave = cfg.wave_flow;
    wave.gain = wave.deep_gain = 32;
    wave.floor_gain = 1024;
    wave.flux_smoothing = 16;
    wave.coast = 32;
    wave.empty_pour_shift = 2;
    wave.damp_shift = 16;
    wave.calm_damp_shift = 8;
    wave.calm = wave.stick = 128;
    wave.sleep_after = 90;
    wave.body_push_by_mass = 1;
    wave.spill.sheet_rate = 64;
    wave.spill.coyote_ticks = 4;
    wave.spill.full_face = 1;
    wave.spill.fall = 3;
    wave.spill.draw = 127;
    wave.spill.draw_head = 255;
    wave.spill.deep_draw = 64;
    wave.spill.launch_budget = 128;
    return cfg;
}

void buried_oil_surfaces_and_disturbed_tank_settles() {
    constexpr std::uint64_t water = 48U * 31U * 255U;
    // The final row uses the physical coordinates of the packaged tank. A
    // different location samples different deterministic Oil/Sand motions.
    struct Tank { bool sand; int x, y, gate_tick; };
    const Tank tanks[] = {{false, 0, 0, 600}, {true, 0, 0, 600}, {true, 128, 192, 3600}};
    for (const auto [sand, offset_x, offset_y, gate_tick] : tanks) {
        const int left = offset_x + 104, right = left + 48;
        const RectI64 all{offset_x, offset_y, 256, 128};
        std::array<std::uint64_t, 3> reference{};
        for (const auto workers : {1U, 6U}) {
            if (gate_tick == 3600 && workers != 1) continue;
            World world(oil_tank_config(workers));
            world.configure_transient_obstacles(all, true);
            world.enable_transient_granular_wrenches(true);
            world.enable_granular_arrival_witness(true);
            box(world, 256, 128, offset_x, offset_y);
            rect(world, left - 1, offset_y + 1, 1, 95, Material::Wall);
            rect(world, right, offset_y + 1, 1, 96, Material::Wall);
            rect(world, left - 1, offset_y + 96, 49, 1, Material::Wall);
            rect(world, left, offset_y + 64, 48, 32, Material::Water);
            rect(world, left, offset_y + 74, 48, 1, Material::Oil);
            if (sand) rect(world, left + 17, offset_y + 46, 14, 8, Material::Sand);
            const auto deposited_sand = [&] {
                std::vector<int> cells;
                for (int y = offset_y + 65; y < offset_y + 96; ++y)
                    for (int x = left; x < right; ++x)
                        if (world.stored_material(x, y) == Material::Sand)
                            cells.push_back(y * 48 + (x - left));
                return cells;
            };

            std::array<std::uint64_t, 3> hashes{};
            std::uint64_t before_quiet = 0;
            std::vector<int> previous_deposit;
            for (int tick = 1; tick <= gate_tick; ++tick) {
                (void)world.tick();
                if (tick == 30) hashes[0] = world.physical_state_hash();
                if (tick == 540) {
                    before_quiet = world.wave_flow_diagnostics().launched_units;
                    if (sand) previous_deposit = deposited_sand();
                }
            }
            int surfaced = 0, supported = 0, slick_columns = 0, run = 0, longest_run = 0;
            for (int x = left; x < right; ++x) {
                bool water_above = false, floating_oil = false;
                for (int y = offset_y + 1; y < offset_y + 96; ++y) {
                    const auto material = world.stored_material(x, y);
                    if (material == Material::Water) water_above = true;
                    if (material == Material::Oil && !water_above) {
                        ++surfaced;
                        floating_oil = true;
                        const auto below = world.stored_material(x, y + 1);
                        if (below == Material::Water || below == Material::Oil) ++supported;
                    }
                }
                if (floating_oil) ++slick_columns;
                run = floating_oil ? run + 1 : 0;
                longest_run = std::max(longest_run, run);
            }
            const auto quiet = world.wave_flow_diagnostics().launched_units;
            const auto ledger = world.quantity_ledger();
            std::printf("Oil tank t=%d workers=%u sand=%d surfaced=%d supported=%d columns=%d longest_run=%d "
                        "late_throw=%llu live=%u\n", gate_tick, workers, sand ? 112 : 0, surfaced, supported, slick_columns,
                        longest_run, static_cast<unsigned long long>(quiet - before_quiet),
                        world.ballistic_water_snapshot().live);
            if (sand) require(previous_deposit.size() == 112 && previous_deposit == deposited_sand(),
                              "Sand had not formed a stationary submerged deposit");
            // The undisturbed strip should remain a single, tank-wide slick.
            // Sand may stack Oil, but all of it should remain afloat and
            // collectively cover at least three quarters of the tank surface.
            require(surfaced == 48 && supported == 48 && slick_columns >= (sand ? 36 : 48),
                    "Oil failed to form a broad floating slick");
            require(ledger.material_cells[static_cast<std::size_t>(Material::Oil)] == 48 &&
                    ledger.material_cells[static_cast<std::size_t>(Material::Sand)] == (sand ? 112U : 0U),
                    "Oil or Sand inventory changed");
            require(quiet == before_quiet && world.ballistic_water_snapshot().live == 0,
                    "settled tank still sprayed after tick 540: " + std::to_string(quiet - before_quiet));
            require_ledger_closes(world, all, water, "resting Oil tank");
            hashes[1] = world.physical_state_hash();

            // Opening the side gate starts a fresh dam-break wave into the
            // catch basin. The only possible spray source is the tank Water.
            rect(world, right, offset_y + 55, 1, 41, Material::Empty);
            for (int tick = 0; tick < 24; ++tick) (void)world.tick();
            const auto fresh = world.wave_flow_diagnostics().launched_units - quiet;
            require(fresh > 0 && world.water_quantity({right + 1, offset_y, 103, 128}) > 0,
                    "released wave did not travel into the basin and throw spray");
            require_ledger_closes(world, all, water, "released Oil tank");
            const auto released = world.quantity_ledger();
            require(released.material_cells[static_cast<std::size_t>(Material::Oil)] == 48 &&
                    released.material_cells[static_cast<std::size_t>(Material::Sand)] == (sand ? 112U : 0U),
                    "gate release changed the Oil or Sand inventory");
            hashes[2] = world.physical_state_hash();
            if (workers == 1) reference = hashes;
            else require(reference == hashes, "Oil tank physical states differed across worker counts");
            std::printf("Oil tank gate t=%d workers=%u sand=%d fresh_throw=%llu\n",
                        gate_tick, workers, sand ? 112 : 0, static_cast<unsigned long long>(fresh));
        }
    }
}

// The Workbench round Oil brush at radius 24 contains 1,793 cells. Paint
// through the surface, so roughly half the disk initially sits under water.
void thick_oil_brush_spreads_on_water() {
    constexpr int width = 384, height = 160, surface = 64, radius = 24;
    constexpr RectI64 bounds{0, 0, width + 2, height};
    std::array<std::uint64_t, 3> reference{};
    for (auto workers : {1U, 6U}) {
        World world(oil_tank_config(workers));
        box(world, width + 2, height);
        rect(world, 1, surface, width, height - surface - 1, Material::Water);
        for (int dy = -radius; dy <= radius; ++dy)
            for (int dx = -radius; dx <= radius; ++dx)
                if (dx * dx + dy * dy <= radius * radius)
                    world.set(width / 2 + dx, surface + dy, Material::Oil);
        const auto initial = owned(world, bounds);
        std::array<std::uint64_t, 3> hashes{};
        std::uint64_t initial_spray = 0;
        for (int tick = 1; tick <= 900; ++tick) {
            (void)world.tick();
            if (tick != 300 && tick != 540 && tick != 900) continue;
            int total = 0, columns = 0, deepest = 0, surfaced = 0;
            for (int x = 1; x <= width; ++x) {
                int depth = 0;
                bool seen_water = false;
                for (int y = 1; y < height - 1; ++y) {
                    const auto material = world.stored_material(x, y);
                    if (material == Material::Water) seen_water = true;
                    if (material == Material::Oil) {
                        ++depth;
                        if (!seen_water) ++surfaced;
                    }
                }
                total += depth;
                if (depth > 0) ++columns;
                deepest = std::max(deepest, depth);
            }
            require(total == 1793 && world.quantity_ledger().material_cells[
                        static_cast<std::size_t>(Material::Oil)] == 1793, "brush Oil inventory drifted");
            require_ledger_closes(world, bounds, initial, "thick Oil brush");
            const auto launched = world.wave_flow_diagnostics().launched_units;
            std::printf("thick Oil t=%d workers=%u columns=%d deepest=%d surfaced=%d spray=%llu live=%u\n",
                        tick, workers, columns, deepest, surfaced,
                        static_cast<unsigned long long>(launched), world.ballistic_water_snapshot().live);
            if (tick == 300) require(columns >= 160 && deepest <= 23, "painted Oil still sits in a thick blob");
            if (tick == 540) initial_spray = launched;
            if (tick == 900) {
                require(columns >= 270 && deepest <= 16 && surfaced == 1793, "thick brush failed to form a broad floating slick");
                require(initial_spray == launched && world.ballistic_water_snapshot().live == 0,
                        "thick slick kept spraying after settling");
            }
            hashes[tick == 300 ? 0U : tick == 540 ? 1U : 2U] = world.physical_state_hash();
        }
        if (workers == 1) reference = hashes;
        else require(hashes == reference, "thick Oil brush changed with worker count");
    }
}

void wave_crosses_a_floating_oil_blanket() {
    // The step starts well to the left of the probe. Read Water connected
    // to the floor so an isolated drop or parcel cannot count as a crest.
    constexpr int width = 48, left = 100, floor = 84, probe = left + width - 3;
    constexpr RectI64 bounds{left - 1, floor - 79, width + 2, 80};
    for (const int coat : {1, 4}) {
        std::array<std::uint64_t, 3> reference{};
        for (const auto workers : {1U, 6U}) {
            World world(oil_tank_config(workers));
            box(world, width + 2, 80, left - 1, floor - 79);
            for (int dx = 0; dx < width; ++dx) {
                const int depth = dx < width / 2 ? 32 : 16;
                rect(world, left + dx, floor - depth, 1, depth, Material::Water);
                rect(world, left + dx, floor - depth - coat, 1, coat, Material::Oil);
            }
            const auto water = owned(world, bounds);
            const auto surface = [&](int x) {
                int y = floor;
                while (world.stored_material(x, y - 1) == Material::Water) --y;
                return y;
            };
            const int initial = surface(probe);
            int crest = initial, return_level = initial;
            std::array<std::uint64_t, 3> hashes{};
            for (int tick = 1; tick <= 600; ++tick) {
                (void)world.tick();
                if (tick <= 60) crest = std::min(crest, surface(probe));
                if (tick == 60) return_level = surface(probe);
                if (tick > 60 && tick <= 150) return_level = std::max(return_level, surface(probe));
                if (tick != 60 && tick != 150 && tick != 600) continue;
                require_ledger_closes(world, bounds, water, "wave under floating Oil");
                require(world.quantity_ledger().material_cells[static_cast<std::size_t>(Material::Oil)] ==
                        static_cast<std::uint64_t>(width * coat), "wave changed the Oil inventory");
                hashes[tick == 60 ? 0U : tick == 150 ? 1U : 2U] = world.physical_state_hash();
            }
            // Visible displacement on arrival and reversal distinguish a
            // travelling wave from slow draining or levelling the Water once.
            require(initial - crest >= 6 && return_level - crest >= 4,
                    "Oil pinned the arriving or receding Water wave");
            int excess = 0;
            for (int x = left; x < left + width; ++x)
                excess += std::max(0, static_cast<int>(world.liquid_mass(x, surface(x))) - 255);
            require(excess <= width * 255, "more than a full row of Water still trapped under the slick");
            if (workers == 1) reference = hashes;
            else require(hashes == reference, "Oil-covered wave differed by worker count");
        }
    }
}

void mobile_oil_only_rises_into_accessible_headroom() {
    // One-cell-wide shaft: two full cells of Water compressed beneath
    // four Oil cells. The bottom Oil and upper Water straddle a chunk seam.
    constexpr int x = 69, y = 128, coat = 4;
    constexpr RectI64 bounds{64, 116, 12, 16};
    enum class Block { Wall, MaskInOil, MaskHeadroom, PausedUpper };
    for (const auto block : {Block::Wall, Block::MaskInOil, Block::MaskHeadroom, Block::PausedUpper}) {
        World world(oil_tank_config(6));
        rect(world, x - 1, y - coat - 2, 1, coat + 4, Material::Wall);
        rect(world, x + 1, y - coat - 2, 1, coat + 4, Material::Wall);
        world.set(x, y + 1, Material::Wall);
        require(world.set_cell_state(x, y, Material::Water, 510, 0), "compressed Water setup");
        for (int row = 1; row <= coat; ++row)
            require(world.set_cell_state(x, y - row, Material::Oil, static_cast<std::uint16_t>(170 + row), 0), "Oil payload setup");
        world.set_temperature(x, y - 1, 315);
        if (block == Block::Wall) world.set(x, y - coat - 1, Material::Wall);
        if (block == Block::MaskInOil || block == Block::MaskHeadroom) {
            world.configure_transient_obstacles(bounds);
            const int mask_y = block == Block::MaskInOil ? y - 2 : y - coat - 1;
            require(world.set_transient_obstacle(x, mask_y, 1), "Oil roof mask setup");
        }
        if (block == Block::PausedUpper) world.set_simulation_region(RectI64{64, y, 64, 64});
        for (int tick = 0; tick < 4; ++tick) (void)world.tick();
        require(world.liquid_mass(x, y) == 510 && world.stored_material(x, y - 1) == Material::Oil,
                "Oil rose through a blocked or paused interface");
        if (block == Block::Wall) world.set(x, y - coat - 1, Material::Empty);
        if (block == Block::MaskInOil || block == Block::MaskHeadroom) world.clear_transient_obstacles();
        if (block == Block::PausedUpper) world.set_simulation_region(std::nullopt);
        for (int tick = 0; tick < 8; ++tick) (void)world.tick();
        require(world.liquid_mass(x, y) == 255 && world.liquid_mass(x, y - 1) == 255,
                "released Oil cap kept a full Water cell compressed");
        require_ledger_closes(world, bounds, 510, "Oil cap released");
        std::array<bool, coat> seen{};
        for (int row = 2; row <= coat + 1; ++row) {
            const auto tag = world.stored_state_a(x, y - row);
            require(world.stored_material(x, y - row) == Material::Oil && tag >= 171 && tag <= 174,
                    "Oil lift lost a material or its payload");
            require(!seen[tag - 171], "Oil lift duplicated a payload");
            seen[tag - 171] = true;
            require(world.stored_temperature(x, y - row) == (tag == 171 ? 315 : 200),
                    "Oil lift separated the payload from its temperature");
        }
    }
}

void warm_oil_surface_move_carries_tuple_across_chunk() {
    World world(oil_tank_config(6));
    box(world, 256, 80);
    rect(world, 1, 42, 254, 37, Material::Water);
    rect(world, 100, 38, 28, 4, Material::Oil);
    rect(world, 128, 38, 17, 4, Material::Water);
    // Warm and identify only the last four columns of Oil in the left chunk.
    for (int x = 124; x < 128; ++x) {
        for (int y = 38; y < 42; ++y) {
            require(world.set_cell_state(x, y, Material::Oil, 173, 0), "tagging warm Oil failed");
            world.set_temperature(x, y, 315);
        }
    }
    (void)world.tick();
    int tagged = 0, across = 0;
    for (int x = 1; x < 255; ++x) {
        for (int y = 1; y < 79; ++y) {
            if (world.stored_material(x, y) != Material::Oil || world.stored_state_a(x, y) != 173) continue;
            require(world.stored_temperature(x, y) == 315, "Oil tuple lost its temperature");
            ++tagged;
            if (x >= 138) ++across;
        }
    }
    require(tagged == 16 && across > 0, "warm Oil did not carry its state beyond the cell-job halo");
}
void oil_exchange_preserves_partial_overfull_and_paused_cells() {
    // A pair straddling a scheduling core boundary, enclosed by a solid
    // one-cell jacket. Saturated Water has nowhere to redistribute after
    // the exchange; checking the exact tuple catches uint8 truncation.
    for (const std::uint16_t mass : std::array<std::uint16_t, 2>{1, 65535}) {
        for (const int active_y : {0, 64}) {
            World world(config(Mode::Original));
            rect(world, 68, 62, 3, 4, Material::Wall);
            require(world.set_cell_state(69, 63, Material::Water, mass, 0) &&
                    world.set_cell_state(69, 64, Material::Oil, 173, 0), "seam setup refused");
            world.set_simulation_region(RectI64{64, active_y, 64, 64});
            for (int n = 0; n < 100; ++n) (void)world.tick();
            require(world.stored_material(69, 64) == Material::Oil && world.stored_state_a(69, 64) == 173 &&
                    world.liquid_mass(69, 63) == mass, "Oil exchanged through a paused boundary");
            world.set_simulation_region(std::nullopt);
            for (int n = 0; n < 8; ++n) (void)world.tick();
            require(world.stored_material(69, 63) == Material::Oil && world.stored_state_a(69, 63) == 173 &&
                    world.liquid_mass(69, 64) == mass, "resumed Oil exchange lost a cell or its payload");
        }
    }
    for (const int masked_y : {127, 128}) {
        World world(config(Mode::Original, 6));
        rect(world, 68, 126, 3, 4, Material::Wall);
        world.set(69, 127, Material::Water);
        world.set(69, 128, Material::Oil);
        world.set_temperature(69, 128, 315);
        world.configure_transient_obstacles({64, 120, 16, 16});
        require(world.set_transient_obstacle(69, masked_y, 1), "Oil test mask refused");
        for (int n = 0; n < 10; ++n) (void)world.tick();
        require(world.stored_material(69, 127) == Material::Water &&
                world.stored_material(69, 128) == Material::Oil, "Oil exchanged through a body");
        world.clear_transient_obstacles();
        for (int n = 0; n < 8; ++n) (void)world.tick();
        require(world.stored_material(69, 127) == Material::Oil && world.stored_temperature(69, 127) == 315 &&
                world.liquid_mass(69, 128) == 255 && world.stored_temperature(69, 128) == 200,
                "unmasked Oil exchange across chunks lost Water or moved heat to the wrong cell");
    }
}

void oil_exchange_moves_water_only_once_per_tick() {
    // Upper and lower Oil belong to different scheduling cores. On a tick
    // where the upper core runs first, the lower Oil sees newly displaced
    // Water and must leave it alone until the next tick.
    for (int phase_offset = 0; phase_offset < 4; ++phase_offset) {
        World world(config(Mode::Original));
        for (int tick = 0; tick < phase_offset; ++tick) (void)world.tick();
        rect(world, 68, 61, 3, 5, Material::Wall);
        world.set(69, 62, Material::Water);
        rect(world, 69, 63, 1, 2, Material::Oil);
        for (int tick = 1; tick <= 2; ++tick) {
            (void)world.tick();
            require(world.liquid_mass(69, 62 + tick) == 255 &&
                    world.stored_material(69, 62) == Material::Oil,
                    "same Water must displace one Oil each tick, phase offset " + std::to_string(phase_offset));
        }
    }
    // The hot Water's chunk owns the only thermal field at setup. An Oil
    // update in the next, cold chunk has to carry both temperatures safely.
    World hot(config(Mode::Original));
    rect(hot, 68, 126, 3, 4, Material::Wall);
    hot.set(69, 127, Material::Water);
    hot.set_temperature(69, 127, 300);
    hot.set(69, 128, Material::Oil);
    (void)hot.tick();
    require(hot.liquid_mass(69, 128) == 255 && hot.stored_temperature(69, 128) == 300 &&
            hot.stored_material(69, 127) == Material::Oil && hot.stored_temperature(69, 127) == 200,
            "Oil exchange lost heat when only the adjacent Water chunk had thermal storage");
}

void oil_lid_pressure_respects_walls_and_masks() {
    enum class Cover { Free, Mask, Wall, Paused };
    const auto flux_under = [](Material roof, Cover cover) {
        World world(config(Mode::Original, 6));
        // Two communicating Water cells. Their roofs sit in the upper
        // chunk; only the left cell has excess mass. Surrounding walls
        // prevent sideways Oil movement and seal the sample from below.
        rect(world, 67, 127, 4, 3, Material::Wall);
        world.set(68, 127, roof);
        if (cover == Cover::Wall) world.set(68, 126, Material::Wall);
        world.set(68, 128, Material::Water);
        world.set(69, 128, Material::Water);
        // Prepare lid metadata while the upper core is visible before
        // masking or pausing it; the stale mobile tag must not leak through.
        (void)world.tick();
        if (cover == Cover::Mask) {
            world.configure_transient_obstacles({64, 120, 16, 16});
            require(world.set_transient_obstacle(68, 127, 1), "Oil roof mask refused");
        }
        if (cover == Cover::Paused) world.set_simulation_region(RectI64{64, 128, 64, 64});
        require(world.set_cell_state(68, 128, Material::Water, 287, 0), "excess Water refused");
        (void)world.tick();
        require_ledger_closes(world, {64, 120, 16, 16}, 542, "Oil roof");
        require(world.stored_material(68, 127) == roof, "pressure replaced the roof");
        return world.wave_flow_flux(68, 128);
    };
    const auto rigid = flux_under(Material::Wall, Cover::Free);
    const auto mobile = flux_under(Material::Oil, Cover::Free);
    require(rigid > mobile && mobile >= 0, "free Oil roof acted like a rigid ceiling on overfilled Water");
    require(flux_under(Material::Oil, Cover::Mask) == rigid, "body-masked Oil weakened rigid pressure");
    require(flux_under(Material::Oil, Cover::Wall) == rigid, "Oil trapped under Wall weakened rigid pressure");
    require(flux_under(Material::Oil, Cover::Paused) == rigid, "paused Oil weakened rigid pressure");
}

void dry_oil_keeps_its_cellular_spread() {
    const auto path = [](bool wave) {
        auto cfg = config(Mode::Original);
        cfg.wave_flow.enabled = wave;
        World world(cfg);
        // One Oil cell can shuffle along a flat bed of pure Oil. The
        // underlying row fills its trough and has nowhere to drain.
        rect(world, 47, 79, 18, 2, Material::Wall);
        rect(world, 47, 78, 1, 1, Material::Wall);
        rect(world, 64, 78, 1, 1, Material::Wall);
        rect(world, 48, 79, 16, 1, Material::Oil);
        world.set(56, 78, Material::Oil);
        std::array<int, 32> trace{};
        for (auto& position : trace) {
            (void)world.tick();
            for (int x = 48; x < 64; ++x)
                if (world.stored_material(x, 78) == Material::Oil) position = x;
            require(position != 0, "Oil left a closed dry trough");
        }
        return trace;
    };
    const auto dry = path(false);
    require(std::any_of(dry.begin(), dry.end(), [](int x) { return x != 56; }), "dry control was motionless");
    require(dry == path(true), "Wave changed a pure Oil cell's path on dry ground");
}

void floating_oil_preserves_paused_face_momentum() {
    for (const auto workers : {1U, 6U}) {
        for (const bool active_left : {true, false}) {
            auto cfg = config(Mode::Hybrid, workers);
            cfg.chunk_size = 64;
            cfg.scheduling_core_size = 32;
            cfg.activity_block_size = 16;
            cfg.wave_flow.spill.fall = 3;
            World world(cfg);
            const auto x = [active_left](int column) { return active_left ? column : 127 - column; };
            const auto put = [&](int column, int y, Material mat) { world.set(x(column), y, mat); };
            rect(world, x(60), 42, 1, 15, Material::Wall);
            rect(world, x(66), 42, 1, 15, Material::Wall);
            for (int column = 61; column <= 65; ++column) {
                put(column, 56, Material::Wall);
                rect(world, x(column), 49, 1, 7, Material::Water);
            }
            require(world.set_cell_state(x(63), 48, Material::Water, 200, 0) &&
                    world.set_cell_state(x(64), 48, Material::Water, 50, 0), "Oil seam setup");
            (void)world.tick();
            const auto held = world.wave_flow_flux(63, 48);
            require(held != 0, "uneven Water failed to establish boundary momentum");
            world.set_simulation_region(RectI64{active_left ? 0 : 64, 0, 64, 128});

            // Drain the active endpoint vertically. Its now-empty cell still
            // shares a retained face with the paused Water across the seam.
            for (int column = 61; column <= 63; ++column)
                rect(world, x(column), 49, 1, 7, Material::Empty);
            for (int i = 0; i < 16; ++i) (void)world.tick();
            require(world.stored_material(x(63), 48) == Material::Empty &&
                    world.wave_flow_flux(63, 48) == held, "draining lost the held seam");
            rect(world, x(61), 47, 1, 9, Material::Wall);
            rect(world, x(63), 49, 1, 7, Material::Water);
            rect(world, x(62), 52, 1, 4, Material::Water);
            rect(world, x(62), 49, 1, 3, Material::Oil);
            for (int i = 0; i < 8; ++i) {
                (void)world.tick();
                require(world.wave_flow_flux(63, 48) == held,
                        "floating Oil retired the shared face across a paused boundary");
            }
        }
    }
}

}  // namespace

int main(int argc, char** argv) {
    std::string filter;
    if (argc == 3 && std::string(argv[1]) == "--filter") filter = argv[2];
    else if (argc != 1) {
        std::fprintf(stderr, "usage: test_wave_spill [--filter name-substring]\n");
        return 2;
    }
    struct Test {
        const char* name;
        void (*function)();
    };
    const Test tests[] = {
        {"wave crosses a floating Oil blanket", wave_crosses_a_floating_oil_blanket},
        {"mobile Oil only rises into accessible headroom", mobile_oil_only_rises_into_accessible_headroom},
        {"warm Oil surface move carries its tuple across chunks", warm_oil_surface_move_carries_tuple_across_chunk},
        {"thick Oil brush spreads on Water", thick_oil_brush_spreads_on_water},
        {"floating Oil preserves paused face momentum", floating_oil_preserves_paused_face_momentum},
        {"buried Oil surfaces and disturbed tank settles", buried_oil_surfaces_and_disturbed_tank_settles},
        {"Oil exchange preserves partial overfull and paused cells", oil_exchange_preserves_partial_overfull_and_paused_cells},
        {"Oil exchange moves Water only once per tick", oil_exchange_moves_water_only_once_per_tick},
        {"Oil lid pressure respects walls and masks", oil_lid_pressure_respects_walls_and_masks},
        {"dry Oil keeps its cellular spread", dry_oil_keeps_its_cellular_spread},
        {"deep draw limits opposing pool faces", deep_draw_limits_opposing_pool_faces},
        {"floor gain requires real level terrain and conserves both shares", floor_gain_requires_a_level_solved_floor},
        {"crest Apply adopts the replacement flight law", retained_crest_adopts_replacement_flight_law},
        {"sheet starts with zero ordinary gain", sheet_starts_from_rest_without_wave_gain},
        {"sheet releases deep rows and keeps crest spray", sheet_releases_deep_rows_and_keeps_crest_spray},
        {"full face covers dry and falling receivers", full_face_covers_dry_and_falling_receivers},
        {"full face curtain head is independent of slots", full_face_curtain_head_is_independent_of_parcel_slots},
        {"full face respects paused receivers and maximal overfill", full_face_freezes_paused_receivers_and_bounds_max_overfill},
        {"full face shares slots across tall walls", full_face_shares_slots_across_tall_walls},
        {"sheet and coyote budget each side of a ridge", sheet_and_coyote_budget_each_side_of_a_ridge},
        {"coyote flight pauses expires and leaves jets alone", coyote_flight_pauses_expires_and_leaves_jets_alone},
        {"spill is off by default and admission is typed", spill_is_off_by_default_and_admission_is_typed},
        {"disabled spill reproduces the base law", disabled_spill_reproduces_the_base_law},
        {"disabled spill preserves Wave identity", disabled_spill_preserves_wave_identity},
        {"cleared World matches a fresh World", cleared_world_matches_a_fresh_world},
        {"paused floor is solid to spill", paused_floor_is_solid_to_spill},
        {"parcels are not born in paused cores", parcels_are_not_born_in_paused_cores},
        {"full parcel pool is counted and clamped", full_parcel_pool_is_counted_and_clamped},
        {"diagonal one-cell wall holds", diagonal_one_cell_wall_holds},
        {"wet and dry corners stop ballistic Water", wet_and_dry_corners_stop_ballistic_water},
        {"automatic spill bounds parcel coordinates", automatic_spill_bounds_parcel_coordinates},
        {"blobs and stream share conserve and are deterministic", blobs_and_stream_share_conserve_and_are_deterministic},
        {"body push scales with water amount", body_push_scales_with_water_amount},
        {"generic Ballistic Water runs under Wave", generic_ballistic_water_runs_under_wave},
        {"face release without spill conserves", face_release_without_spill_conserves},
        {"stream draw keeps the throw and conserves", stream_draw_keeps_the_throw_and_conserves},
        {"stream draw zero is the earlier spill World", stream_draw_zero_is_the_earlier_spill_world},
        {"exposed reservoir collapses and conserves", exposed_reservoir_collapses_and_conserves},
        {"worker counts and repeats are identical", worker_counts_and_repeats_are_identical},
        {"waterfall lands fills and rejoins", waterfall_lands_fills_and_rejoins},
        {"sealed reservoir is untouched", sealed_reservoir_is_untouched},
        {"contained pool still waves and rests", contained_pool_still_waves_and_rests},
        {"capacity and budget are explicit outcomes", capacity_and_budget_are_explicit_outcomes},
        {"overfilled cells never wrap or overfill parcels", overfilled_cells_never_wrap_or_overfill_parcels},
        {"thin walls and masks stop spill", thin_walls_and_masks_stop_spill},
        {"paused region does not spill", paused_region_does_not_spill},
        {"thin film is not thrown", thin_film_is_not_thrown},
    };
    int failures = 0, executed = 0;
    for (const auto& test : tests) {
        if (!filter.empty() && std::string(test.name).find(filter) == std::string::npos) continue;
        ++executed;
        try {
            test.function();
            std::printf("PASS %s\n", test.name);
        } catch (const std::exception& error) {
            ++failures;
            std::printf("FAIL %s: %s\n", test.name, error.what());
        }
        std::fflush(stdout);
    }
    if (executed == 0) {
        std::fprintf(stderr, "No Wave spill tests matched the filter.\n");
        return 2;
    }
    std::printf("WAVE_SPILL: %d tests; %d failures (%zu registered)\n", executed, failures, std::size(tests));
    return failures == 0 ? 0 : 1;
}
