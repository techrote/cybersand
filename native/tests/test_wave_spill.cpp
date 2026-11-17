// WAVE-WATERWALL-001: standalone native regressions for the opt-in wave_flow_v1
// exposed-face spill and its hybrid ballistic release. Build targets:
// make wave-spill-test / wave-spill-sanitize / wave-spill-thread-sanitize.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <exception>
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

enum class Mode { Original, Spill, Hybrid };

WorldConfig config(Mode mode, std::uint32_t workers = 4, std::uint8_t substeps = 1) {
    WorldConfig result;
    result.worker_threads = workers;
    result.parallel_job_threshold = 2;
    result.maximum_chunk_count = 128;
    result.active_chunk_capacity = 128;
    result.wave_flow.enabled = true;
    result.wave_flow.substeps = substeps;
    result.wave_flow.spill.enabled = mode != Mode::Original;
    result.ballistic_water.enabled = mode == Mode::Hybrid;
    return result;
}

void rect(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx, yy, material);
}

void box(World& world, int width, int height) {
    rect(world, 0, 0, width, 1, Material::Wall);
    rect(world, 0, height - 1, width, 1, Material::Wall);
    rect(world, 0, 0, 1, height, Material::Wall);
    rect(world, width - 1, 0, 1, height, Material::Wall);
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
    // Ballistic parcels are admitted only through the spill release contract.
    expect_refusal([](WorldConfig& c) { c.wave_flow.spill.enabled = false; c.ballistic_water.enabled = true; },
                   "ballistic Water without spill");
    expect_refusal([](WorldConfig& c) { c.ballistic_water.enabled = true; c.ballistic_water.face_release = true; },
                   "per-cell face release under Wave");
    // Out-of-range values are ignored while spill is disabled: nothing reads them.
    auto ignored = config(Mode::Original);
    ignored.wave_flow.spill.fall = 99;
    World accepted(ignored);
    require(accepted.wave_flow_enabled(), "disabled spill tuning refused a valid Wave World");
    World hybrid(config(Mode::Hybrid));
    require(hybrid.wave_flow_enabled() && hybrid.ballistic_water_enabled(), "hybrid release was not admitted");
    bool refused = false;
    try { (void)hybrid.save_physical_state(); } catch (const std::logic_error&) { refused = true; }
    require(refused && hybrid.physical_state_format_version() == 0U, "hybrid Wave World claimed exact persistence");
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
    // Parcel capacity too small for the per-tick budget: the hint stays off
    // and every face spills natively. Nothing is launched, nothing is lost.
    auto cfg = config(Mode::Hybrid, 4);
    cfg.ballistic_water.capacity = 8;
    cfg.wave_flow.spill.launch_budget = 16;
    auto starved = build(cfg);
    const auto before = owned(*starved, all);
    for (int t = 0; t < 200; ++t) (void)starved->tick();
    require(starved->wave_flow_diagnostics().launched_parcels == 0 && starved->wave_flow_diagnostics().spill_units > 0,
            "capacity below the launch budget did not fall back to native spill");
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
    // A parcel dropped onto the sealed, overfilled pocket cannot enter it.
    rect(world, 11, 9, 3, 1, Material::Empty);
    const auto injected = world.inject_ballistic_water(12 * 256 + 128, 5 * 256 + 128, 0, 64, 200);
    require(injected.outcome == BallisticLaunchOutcome::Launched, "test parcel refused");
    for (int t = 0; t < 400; ++t) (void)world.tick();
    require(!world.has_failed(), "overfilled deposit failed the World");
    require(world.liquid_mass(12, 11) <= 60000U, "landing wrapped or grew a sealed overfilled cell");
    require(owned(world, all) == before + 200U, "overfilled deposit lost or duplicated Water");
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
        {"spill is off by default and admission is typed", spill_is_off_by_default_and_admission_is_typed},
        {"disabled spill preserves Wave identity", disabled_spill_preserves_wave_identity},
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
