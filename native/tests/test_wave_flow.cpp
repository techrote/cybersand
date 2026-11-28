// WAVE-MT-001 wave_flow_v1: standalone native regressions for the opt-in bulk
// strip-parallel Water law. Build targets: make wave-flow-test /
// wave-flow-sanitize / wave-flow-thread-sanitize.
#include "cybersand/world.hpp"
#include "cybersand/c_api.h"
#include "cybersand/prepared_world.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <exception>
#include <functional>
#include <limits>
#include <memory>
#include <random>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

void prepared_uint16_payload_and_quantity_are_lossless() {
    using namespace normalization;
    FinalSetupInput input;
    input.mass_bits = 8;
    input.setup.seed = 631;
    input.setup.domain = {0, 0, 64, 64};
    input.cells = {{10, 20, Material::Water, 1, 0, 200},
                   {11, 20, Material::Water, 255, 0, 200},
                   {12, 20, Material::Water, 256, 0, 200},
                   {13, 20, Material::Water, 65535, 0, 200}};
    // Keep the subsequent tick's inventory inside the declared finite domain.
    // Without a floor, Wave's gravity pass legitimately falls into the halo.
    for (std::int64_t x = 0; x < 64; ++x) {
        input.cells.push_back({x, 0, Material::Wall, 0, 0, 200});
        input.cells.push_back({x, 63, Material::Wall, 0, 0, 200});
    }
    for (std::int64_t y = 1; y < 63; ++y) {
        input.cells.push_back({0, y, Material::Wall, 0, 0, 200});
        input.cells.push_back({63, y, Material::Wall, 0, 0, 200});
    }
    const auto original = input.cells;
    WorldConfig cfg;
    cfg.wave_flow.enabled = true;
    cfg.worker_threads = 4;
    auto result = PreparedWorldBuilder::prepare(cfg, input, NormalizationOptIn::None);
    require(std::holds_alternative<PreparedWorld>(result), "prepared Wave World refused legal uint16 stored Water");
    auto prepared = std::get<PreparedWorld>(std::move(result));
    const auto& candidate = prepared.world();
    require(input.cells == original, "prepared Wave World mutated caller tuples");
    for (const auto& cell : input.cells)
        require(candidate.stored_material(cell.x, cell.y) == cell.material &&
                    candidate.stored_state_a(cell.x, cell.y) == cell.state_a &&
                    candidate.stored_state_b(cell.x, cell.y) == cell.state_b,
                "prepared Wave World truncated or altered a boundary tuple");
    require(candidate.water_quantity({0, 0, 64, 64}) == 66047, "prepared Wave World changed exact fullmass quantity");
    require(!prepared.setup().normalization_receipt(), "prepared Wave World silently normalized its input");
    const auto facts = receipt::capture_native_facts(candidate, prepared.setup().setup_descriptor());
    require(facts.values().prepared_native_payload == prepared.setup().native_payload_hash(),
            "prepared Wave payload hash does not bind actual native cells");
    const auto ledger = candidate.quantity_ledger();
    require(ledger.baseline_water == 66047 && ledger.water_visible + ledger.water_overfill == 66047 &&
                ledger.construction && ledger.construction->expected_final_water == 66047 &&
                ledger.construction->prepared_payload_digest == prepared.setup().native_payload_hash() &&
                ledger.construction->prepared_setup_identity == prepared.setup().setup_hash() &&
                ledger.construction->normalization_produced == 0 && ledger.construction->normalization_consumed == 0 &&
                !ledger.construction->normalization_receipt_digest,
            "prepared Wave ledger lost quantity or fabricated setup conversion");
    const auto before = candidate.physical_state_hash();
    const auto refused_setup = [&](const WorldConfig& settings, const FinalSetupInput& invalid, NormalizationOptIn opt_in) {
        const auto rejected = PreparedWorldBuilder::prepare(settings, invalid, opt_in);
        const auto* refusal = std::get_if<ConstructionRefusal>(&rejected);
        require(refusal != nullptr && refusal->policy_refusal() &&
                    refusal->policy_refusal()->code == LiquidPolicyRefusalCode::MalformedPolicy,
                "invalid prepared uint16 domain was not explicitly refused");
        require(candidate.physical_state_hash() == before && candidate.quantity_ledger() == ledger,
                "refused candidate mutated existing prepared World");
    };
    auto ordinary = cfg;
    ordinary.wave_flow.enabled = false;
    refused_setup(ordinary, input, NormalizationOptIn::None);
    refused_setup(ordinary, input, NormalizationOptIn::WaterNormalizeV1);
    refused_setup(cfg, input, NormalizationOptIn::WaterNormalizeV1);
    auto invalid = input; invalid.cells[0].state_a = 0;
    refused_setup(cfg, invalid, NormalizationOptIn::None);
    invalid = input; invalid.cells[0].state_b = 1;
    refused_setup(cfg, invalid, NormalizationOptIn::None);
    invalid = input; invalid.mass_bits = 7;
    refused_setup(cfg, invalid, NormalizationOptIn::None);
    invalid = input; invalid.cells[2].material = Material::Oil;
    refused_setup(cfg, invalid, NormalizationOptIn::None);
    invalid = input;
    for (auto& cell : invalid.cells) if (cell.material == Material::Water) cell.state_a = 255;
    require(std::holds_alternative<PreparedWorld>(PreparedWorldBuilder::prepare(ordinary, invalid, NormalizationOptIn::None)),
            "ordinary nominal Water construction regressed");
    auto world = prepared.take_world();
    (void)world->tick();
    require(!world->has_failed() && world->wave_flow_diagnostics().ticks == 1 &&
                world->water_quantity({0, 0, 64, 64}) == 66047,
            "prepared uint16 Wave World cannot execute a conserving native tick");
}

WorldConfig config(std::uint32_t workers = 4, std::uint8_t substeps = 1) {
    WorldConfig result;
    result.worker_threads = workers;
    result.parallel_job_threshold = 2;
    result.maximum_chunk_count = 128;
    result.active_chunk_capacity = 128;
    result.wave_flow.enabled = true;
    result.wave_flow.substeps = substeps;
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

double level(const World& world, int x, int height) {
    return static_cast<double>(world.water_quantity({x, 0, 1, height})) / 255.0;
}

std::uint64_t count(const World& world, int width, int height, Material material) {
    std::uint64_t total = 0;
    for (int y = 0; y < height; ++y)
        for (int x = 0; x < width; ++x) total += world.stored_material(x, y) == material;
    return total;
}

// Every Water cell holds a positive mass; nothing is stored in a wall.
void check_well_formed(const World& world, int width, int height, const char* where) {
    for (int y = 0; y < height; ++y)
        for (int x = 0; x < width; ++x)
            if (world.stored_material(x, y) == Material::Water)
                require(world.stored_state_a(x, y) > 0U, std::string(where) + ": Water cell with zero mass");
}

template <typename Function>
void expect_refusal(Function&& mutate, const char* what) {
    auto cfg = config();
    mutate(cfg);
    bool refused = false;
    try {
        World world(cfg);
    } catch (const std::invalid_argument&) {
        refused = true;
    }
    require(refused, std::string("wave_flow admitted an unsupported configuration: ") + what);
}

void disabled_is_default_and_unsupported_is_refused() {
    World ordinary{WorldConfig{}};
    require(!ordinary.wave_flow_enabled(), "wave_flow enabled by default");
    const auto idle = ordinary.wave_flow_diagnostics();
    require(idle.ticks == 0 && idle.storage_bytes == 0, "disabled wave_flow reported work or storage");
    (void)ordinary.tick();
    require(ordinary.wave_flow_diagnostics().ticks == 0, "disabled wave_flow advanced");

    expect_refusal([](WorldConfig& c) { c.wave_flow.substeps = 0; }, "zero substeps");
    expect_refusal([](WorldConfig& c) { c.wave_flow.substeps = 9; }, "nine substeps");
    expect_refusal([](WorldConfig& c) { c.wave_flow.active_rows = 0; }, "zero active rows");
    expect_refusal([](WorldConfig& c) { c.wave_flow.active_rows = 33; }, "thirty-three active rows");
    expect_refusal([](WorldConfig& c) { c.wave_flow.stiffness = 1; }, "stiffness below active rows");
    expect_refusal([](WorldConfig& c) { c.wave_flow.empty_pour_shift = 0; }, "unsafe empty-pour share");
    expect_refusal([](WorldConfig& c) { c.wave_flow.flow_share_shift = 0; }, "unsafe two-face share");
    expect_refusal([](WorldConfig& c) { c.wave_flow.maximum_mass = 254; }, "carrier saturation below full Water");
    expect_refusal([](WorldConfig& c) { c.backend = SimulationBackend::SerialInPlace; }, "serial backend");
    expect_refusal([](WorldConfig& c) { c.backend = SimulationBackend::Buffered; }, "buffered backend");
    expect_refusal([](WorldConfig& c) { c.water_experiment_policy = WaterExperimentPolicy(6, 0); }, "6-bit mass");
    expect_refusal([](WorldConfig& c) { c.settled_discovery_enabled = true; }, "settled discovery");
    // Generic ballistic_water_v1 is admitted under Wave (WAVE-WATERWALL-001, test_wave_spill.cpp).
    expect_refusal([](WorldConfig& c) { c.transport_policy.configured = true; }, "custom cellular transport");
    expect_refusal([](WorldConfig& c) {
        auto words = LiquidSolverPolicy::default_request();
        words[21] = 2; // Water on whole-cell cellular_yield_v1
        c.liquid_solver_policy = *LiquidSolverPolicy::decode(std::span<const std::int32_t>(words)).policy;
    }, "whole-cell Water family");

    World wave(config());
    require(wave.wave_flow_enabled(), "wave_flow not applied");
    bool refused = false;
    try {
        (void)wave.save_physical_state();
    } catch (const std::logic_error&) {
        refused = true;
    }
    require(refused, "wave_flow physical-state save was not refused");

    // Refusal must also cover loading a legacy image with a Wave execution
    // request. Otherwise the loader can silently discard the requested law.
    const auto legacy_image = ordinary.save_physical_state();
    refused = false;
    try {
        (void)World::restore_physical_state(config(), legacy_image);
    } catch (const std::invalid_argument&) {
        refused = true;
    }
    require(refused, "legacy physical-state load silently accepted Wave execution");
    refused = false;
    try {
        (void)wave.set_cell_state(4, 4, Material::Water, 255, 1);
    } catch (const std::invalid_argument&) {
        refused = true;
    }
    require(refused && wave.stored_material(4, 4) == Material::Empty,
            "unsupported coherence state was not rejected before mutation");
}

void coherent_water_edits_refuse_before_zero_mass_normalization() {
    for (const auto workers : {1U, 4U}) {
        World world(config(workers));
        box(world, 32, 32);
        rect(world, 8, 20, 8, 11, Material::Water);
        (void)world.tick(); // Refusal must preserve an active solver, including its flux.
        const auto physical = world.physical_state_hash();
        const auto state = world.state_hash();
        const auto ledger = world.quantity_ledger();
        const auto chunks = world.chunk_count();
        const auto surface = world.hard_surface_revision();
        // Occupied Water, hard terrain, resident Empty and an absent chunk.
        for (const auto target : std::array<std::array<int, 2>, 4>{{
                 {10, 30}, {0, 0}, {20, 10}, {2048, 2048}}}) {
            for (const auto mass : {0U, 1U, 255U, 65535U}) {
                bool refused = false;
                try {
                    (void)world.set_cell_state(target[0], target[1], Material::Water,
                                               static_cast<std::uint16_t>(mass), 1);
                } catch (const std::invalid_argument&) {
                    refused = true;
                }
                require(refused, "coherent Water write bypassed admission through zero-mass normalization");
                require(world.physical_state_hash() == physical && world.state_hash() == state &&
                            world.quantity_ledger() == ledger && world.chunk_count() == chunks &&
                            world.hard_surface_revision() == surface && !world.has_failed(),
                        "refused coherent Water write changed state, quantity, allocation or health");
            }
        }
        require(world.set_cell_state(10, 30, Material::Water, 0, 0) &&
                    world.stored_material(10, 30) == Material::Empty,
                "valid zero-mass Wave erasure was refused");
    }
    World ordinary{WorldConfig{}};
    ordinary.set(10, 10, Material::Water);
    require(ordinary.set_cell_state(10, 10, Material::Water, 0, 1) &&
                ordinary.stored_material(10, 10) == Material::Empty,
            "Wave refusal changed legacy zero-mass normalization");
}

void dam_break_conserves_and_spreads() {
    const int n = 256;
    World world(config(4, 3));
    box(world, n, n);
    rect(world, 1, n / 4, n / 3, n - 1 - n / 4, Material::Water);
    const auto before = world.water_quantity({0, 0, n, n});
    const auto walls = count(world, n, n, Material::Wall);
    for (int tick = 0; tick < 1500; ++tick) {
        (void)world.tick();
        if (tick % 100 == 0)
            require(world.water_quantity({0, 0, n, n}) == before, "dam break changed the Water quantity");
    }
    require(world.water_quantity({0, 0, n, n}) == before, "dam break changed the Water quantity at the end");
    require(count(world, n, n, Material::Wall) == walls, "dam break changed terrain");
    check_well_formed(world, n, n, "dam break");
    require(level(world, 8, n) < 0.75 * (n - 1 - n / 4), "reservoir did not drain");
    require(level(world, n - 9, n) > 2.0, "flow front did not reach the far wall");
}

void worker_counts_are_cell_identical() {
    const int width = 384, height = 256;
    const auto run = [&](std::uint32_t workers) {
        auto world = std::make_unique<World>(config(workers, 2));
        box(*world, width, height);
        rect(*world, 1, 60, 120, height - 61, Material::Water);
        rect(*world, 200, 150, 2, height - 151, Material::Wall); // a weir across two chunk seams
        rect(*world, 260, 40, 40, 30, Material::Water);
        for (int tick = 0; tick < 300; ++tick) {
            if (tick == 120) rect(*world, 150, 20, 20, 20, Material::Water);
            (void)world->tick();
        }
        return world;
    };
    const auto reference = run(1);
    const auto participants = reference->wave_flow_diagnostics().maximum_participants;
    require(participants == 1, "single-worker World reported pool participants");
    for (const std::uint32_t workers : {2U, 4U, 6U}) {
        const auto other = run(workers);
        require(other->wave_flow_diagnostics().maximum_participants > 1U,
                "multi-worker wave_flow dispatch had one participant");
        for (int y = 0; y < height; ++y)
            for (int x = 0; x < width; ++x)
                require(reference->stored_material(x, y) == other->stored_material(x, y) &&
                            reference->stored_state_a(x, y) == other->stored_state_a(x, y),
                        "wave_flow result depends on the worker count (" + std::to_string(workers) + ")");
        require(reference->state_hash() == other->state_hash(), "state hash depends on the worker count");
        require(reference->physical_state_hash() == other->physical_state_hash(),
                "complete Wave state depends on the worker count");
    }
}

// Two disturbances in one pool, probed at the midpoint. Separate runs with A,
// B, A+B, a trough and A-with-trough test linear superposition directly.
std::vector<double> probe(int sign_a, int sign_b, int ticks) {
    const int width = 512, height = 128, depth = 48, bump = 5, half = 10;
    World world(config());
    box(world, width, height);
    const int surface = height - 1 - depth;
    rect(world, 1, surface, width - 2, depth, Material::Water);
    for (int tick = 0; tick < 60; ++tick) (void)world.tick();
    const auto disturb = [&](int cx, int sign) {
        if (sign > 0) rect(world, cx - half, surface - bump, half * 2, bump, Material::Water);
        if (sign < 0) rect(world, cx - half, surface, half * 2, bump, Material::Empty);
    };
    disturb(width / 4, sign_a);
    disturb(width * 3 / 4, sign_b);
    const double mean = static_cast<double>((sign_a + sign_b) * bump * 2 * half) / (width - 2);
    std::vector<double> series;
    for (int tick = 0; tick < ticks; ++tick) {
        (void)world.tick();
        series.push_back((level(world, width / 2 - 1, height) + level(world, width / 2, height) +
                          level(world, width / 2 + 1, height)) / 3.0 - depth - mean);
    }
    return series;
}

void waves_propagate_and_interfere() {
    const int ticks = 700;
    const auto a = probe(+1, 0, ticks), b = probe(0, +1, ticks), both = probe(+1, +1, ticks);
    const auto trough = probe(0, -1, ticks), cancel = probe(+1, -1, ticks);
    int arrival = 0;
    double peak_a = 0;
    for (int t = 0; t < ticks; ++t)
        if (std::fabs(a[static_cast<std::size_t>(t)]) > std::fabs(peak_a)) { peak_a = a[static_cast<std::size_t>(t)]; arrival = t; }
    const auto window_peak = [&](const std::vector<double>& s) {
        double best = 0;
        for (int t = std::max(0, arrival - 100); t < std::min(ticks, arrival + 100); ++t)
            if (std::fabs(s[static_cast<std::size_t>(t)]) > std::fabs(best)) best = s[static_cast<std::size_t>(t)];
        return best;
    };
    // The wave is real state propagation: it arrives late, at a bounded speed.
    const double speed = 128.0 / std::max(1, arrival);
    require(peak_a > 0.2, "single disturbance never reached the probe");
    require(arrival > 150 && speed > 0.2 && speed < 0.8, "wave speed outside the declared band");
    const double constructive = window_peak(both) / peak_a;
    const double destructive = std::fabs(window_peak(cancel)) / std::fabs(peak_a);
    require(std::fabs(window_peak(b) / peak_a - 1.0) < 0.35, "mirror sources arrived unequal");
    require(window_peak(trough) < -0.2, "trough did not arrive inverted");
    require(constructive > 1.5 && constructive < 2.5, "no constructive interference: ratio " + std::to_string(constructive));
    require(destructive < 0.6, "no destructive interference: ratio " + std::to_string(destructive));
    double residual = 0, signal = 0;
    for (int t = 0; t < ticks; ++t) {
        const auto k = static_cast<std::size_t>(t);
        residual += std::pow(both[k] - (a[k] + b[k]), 2);
        signal += std::pow(a[k] + b[k], 2);
    }
    require(std::sqrt(residual / signal) < 0.35, "superposition error too large");
}

void quiet_water_sleeps_and_wakes() {
    const int n = 256;
    World world(config());
    box(world, n, n);
    rect(world, 1, n - 61, n - 2, 60, Material::Water);
    TickStats stats{};
    for (int tick = 0; tick < 200; ++tick) stats = world.tick();
    require(world.wave_flow_diagnostics().last_solved_chunks == 0, "a level pool is still being solved");
    require(stats.active_blocks_after == 0, "a level pool kept generic activity blocks awake");
    const auto rounds = world.wave_flow_diagnostics().tasks;
    for (int tick = 0; tick < 20; ++tick) (void)world.tick();
    require(world.wave_flow_diagnostics().tasks == rounds, "a sleeping pool dispatched strip tasks");
    // Level within one cell across both chunk seams.
    for (int x = 2; x < n - 2; ++x)
        require(std::fabs(level(world, x, n) - 60.0) < 1.0, "pool surface is not level");
    rect(world, 100, 100, 8, 8, Material::Water);
    (void)world.tick();
    require(world.wave_flow_diagnostics().last_solved_chunks > 0, "an owner edit did not wake the solver");
}

void sealed_passage_equalises() {
    const int width = 160, height = 160;
    World world(config());
    box(world, width, height);
    rect(world, 50, 1, 60, height - 5, Material::Wall);   // block; a 3-row passage runs under it
    rect(world, 1, 40, 49, height - 41, Material::Water);  // tall left arm
    rect(world, 50, height - 4, 60, 3, Material::Water);
    rect(world, 110, 120, width - 111, height - 121, Material::Water); // short right arm
    const auto before = world.water_quantity({0, 0, width, height});
    const auto left0 = level(world, 20, height), right0 = level(world, 130, height);
    for (int tick = 0; tick < 4000; ++tick) (void)world.tick();
    require(world.water_quantity({0, 0, width, height}) == before, "sealed passage changed the Water quantity");
    require(level(world, 20, height) < left0 - 4.0 && level(world, 130, height) > right0 + 4.0,
            "no flow through the sealed passage");
    require(level(world, 20, height) > level(world, 130, height) - 1.0, "passage overshot past level");
}

void bodies_block_water_and_receive_contacts() {
    const int width = 192, height = 160;
    World world(config());
    box(world, width, height);
    rect(world, 1, height - 61, width - 2, 60, Material::Water);
    world.configure_transient_obstacles({0, 0, width, height});
    const auto before = world.water_quantity({0, 0, width, height});
    std::uint64_t pressed = 0, pushed = 0;
    for (int tick = 0; tick < 300; ++tick) {
        const int top = 40 + tick / 3; // a slab sinking into the pool
        world.clear_transient_obstacles();
        world.clear_transient_contact_observations();
        for (int y = top; y < top + 10; ++y)
            for (int x = 80; x < 112; ++x) (void)world.set_transient_obstacle(x, y, 1);
        if (tick == 30) rect(world, 86, 20, 20, 6, Material::Water); // rain onto the slab
        (void)world.tick();
        if (world.transient_contact_impulse_y(1) > 0) ++pressed;
        if (world.transient_contact_count(1) > 0U) ++pushed;
    }
    require(pressed > 0, "Water resting on a body recorded no downward contact");
    require(pushed > 100, "submerged body recorded no Water contacts");
    require(world.water_quantity({0, 0, width, height}) == before + 20U * 6U * 255U,
            "moving body mask changed the Water quantity");
    check_well_formed(world, width, height, "body");
}

void other_materials_still_interact() {
    const int n = 128;
    World world(config());
    box(world, n, n);
    rect(world, 1, n - 41, n - 2, 40, Material::Water);
    rect(world, 60, 40, 6, 6, Material::Sand);
    const auto sand = count(world, n, n, Material::Sand);
    for (int tick = 0; tick < 600; ++tick) (void)world.tick();
    require(count(world, n, n, Material::Sand) == sand, "Sand was created or destroyed");
    // The Sand sank through the pool and rests on the floor.
    std::uint64_t floor_rows = 0;
    for (int y = n - 5; y < n - 1; ++y)
        for (int x = 1; x < n - 1; ++x) floor_rows += world.stored_material(x, y) == Material::Sand;
    require(floor_rows >= sand / 2U, "Sand did not sink through wave_flow Water");
    check_well_formed(world, n, n, "sand");
}

void documented_water_owned_chemistry_is_disabled() {
    // BareIron's contact rule is owned by the Water per-cell kernel. Wave's
    // experimental limitation is explicit: it must not intermittently run that
    // kernel (and therefore depend on activity scheduling or worker count).
    for (const auto workers : {1U, 4U}) {
        World world(config(workers));
        rect(world, 0, 0, 8, 8, Material::Wall);
        world.set(3, 4, Material::Water);
        world.set(4, 4, Material::BareIron);
        for (int t = 0; t < 300; ++t) (void)world.tick();
        require(world.stored_material(4, 4) == Material::BareIron,
                "Wave unexpectedly executed unsupported Water-owned corrosion");
        require(world.water_quantity({0, 0, 8, 8}) == 255U,
                "disabled Water-owned chemistry consumed Water");
    }
}

// Spreading changes how many cells hold Water; the native quantity ledger must
// follow, or a later erase or reaction underflows it.
void ledger_population_follows_spreading() {
    const int n = 128;
    World world(config());
    box(world, n, n);
    rect(world, 40, 100, 10, 26, Material::Water);
    const auto painted = world.quantity_ledger().material_cells[static_cast<std::size_t>(Material::Water)];
    require(painted == 260U, "ledger did not count painted Water cells");
    for (int tick = 0; tick < 400; ++tick) (void)world.tick();
    const auto cells = count(world, n, n, Material::Water);
    require(cells != 260U, "Water did not spread");
    require(world.quantity_ledger().material_cells[static_cast<std::size_t>(Material::Water)] == cells,
            "ledger Water cell population differs from stored cells");
    // Erasing every spread cell must not underflow the ledger.
    for (int y = 0; y < n; ++y)
        for (int x = 0; x < n; ++x)
            if (world.stored_material(x, y) == Material::Water) world.set(x, y, Material::Empty);
    require(world.quantity_ledger().material_cells[static_cast<std::size_t>(Material::Water)] == 0U,
            "ledger kept Water cells after erasing all Water");
    require(world.water_quantity({0, 0, n, n}) == 0U, "Water remained after erase");
}

void chunk_capacity_is_an_explicit_outcome() {
    auto cfg = config();
    cfg.maximum_chunk_count = 2;
    cfg.initial_chunk_reserve = 2;
    World world(cfg);
    // Unwalled Water at a chunk edge: its neighbours cannot all be admitted.
    rect(world, 0, 100, 128, 2, Material::Wall);
    rect(world, 0, 90, 128, 10, Material::Water);
    const auto before = world.water_quantity({-256, -256, 768, 768});
    for (int tick = 0; tick < 300; ++tick) (void)world.tick();
    require(!world.has_failed(), "chunk capacity failed the World");
    require(world.chunk_count() <= 2U, "wave_flow exceeded the chunk capacity");
    require(world.wave_flow_diagnostics().capacity_refusals > 0U,
            "chunk capacity exhaustion had no explicit diagnostic outcome");
    require(world.water_quantity({-256, -256, 768, 768}) == before, "capacity limit changed the Water quantity");
}

void tiny_drops_cross_sleep_and_chunk_boundaries() {
    // One, two and three mass units must fall farther than kSleepAfter, through
    // previously dormant chunks. This catches the original peak>=2 sleep bug.
    for (const auto workers : {1U, 4U}) {
        World world(config(workers));
        const int width = 132, height = 520;
        box(world, width, height);
        for (const int x : {63, 127}) {
            rect(world, x - 1, 1, 1, height - 2, Material::Wall);
            rect(world, x + 1, 1, 1, height - 2, Material::Wall);
        }
        for (int t = 0; t < 60; ++t) (void)world.tick();
        require(world.wave_flow_diagnostics().last_solved_chunks == 0,
                "empty shafts did not become dormant");
        require(world.set_cell_state(63, 4, Material::Water, 1, 0), "one-unit drop refused");
        require(world.set_cell_state(127, 9, Material::Water, 2, 0), "two-unit drop refused");
        require(world.set_cell_state(63, 20, Material::Water, 3, 0), "three-unit drop refused");
        for (int t = 0; t < 600; ++t) {
            (void)world.tick();
            require(world.water_quantity({0, 0, width, height}) == 6U,
                    "tiny drops lost mass while crossing a dormant boundary");
        }
        require(world.stored_state_a(63, height - 2) == 4U &&
                    world.stored_state_a(127, height - 2) == 2U,
                "tiny drop stopped before reaching the bottom of its shaft");
        require(world.wave_flow_diagnostics().last_solved_chunks == 0,
                "settled tiny drops did not return to sleep");
    }
}

void erasing_support_reactivates_a_dormant_film() {
    World world(config());
    const int width = 132, height = 270;
    box(world, width, height);
    rect(world, 126, 1, 1, height - 2, Material::Wall);
    rect(world, 128, 1, 1, height - 2, Material::Wall);
    world.set(127, 128, Material::Wall);
    require(world.set_cell_state(127, 127, Material::Water, 1, 0), "film seed refused");
    for (int t = 0; t < 80; ++t) (void)world.tick();
    require(world.stored_state_a(127, 127) == 1U, "supported film moved");
    require(world.wave_flow_diagnostics().last_solved_chunks == 0, "supported film did not sleep");
    world.set(127, 128, Material::Empty);
    for (int t = 0; t < height; ++t) (void)world.tick();
    require(world.stored_state_a(127, height - 2) == 1U,
            "removing support across a chunk seam did not wake the film");
    require(world.water_quantity({0, 0, width, height}) == 1U,
            "reactivated film changed quantity");
}

void region_pause_freezes_cells_and_reentry_resumes() {
    for (const auto workers : {1U, 4U}) {
        World world(config(workers, 2));
        const int width = 256, height = 192;
        box(world, width, height);
        rect(world, 30, 20, 30, 30, Material::Water);
        rect(world, 120, 20, 30, 30, Material::Water); // straddles selection edge
        rect(world, 190, 20, 30, 30, Material::Water);
        world.set_simulation_region(RectI64{0, 0, 128, height});
        const auto before = world.water_quantity({0, 0, width, height});
        const auto paused_quantity = world.water_quantity({128, 0, 128, height});
        std::vector<std::uint16_t> paused;
        for (int y = 0; y < height; ++y)
            for (int x = 128; x < width; ++x) paused.push_back(world.stored_state_a(x, y));
        for (int t = 0; t < 100; ++t) (void)world.tick();
        require(world.water_quantity({0, 0, width, height}) == before, "region boundary lost quantity");
        require(world.water_quantity({128, 0, 128, height}) == paused_quantity,
                "Water crossed the paused-region boundary");
        std::size_t at = 0;
        for (int y = 0; y < height; ++y)
            for (int x = 128; x < width; ++x)
                require(world.stored_state_a(x, y) == paused[at++], "paused cell changed");
        require(world.water_quantity({1, 100, 126, 90}) > 0U, "selected region did not advance");
        world.set_simulation_region(std::nullopt);
        for (int t = 0; t < 150; ++t) (void)world.tick();
        require(world.water_quantity({0, 0, width, height}) == before, "region reentry lost quantity");
        require(world.water_quantity({190, 20, 30, 30}) == 0U, "re-entered Water stayed frozen");
    }
}

void fixed_seed_edits_masks_and_seams_conserve() {
    // Reproduction seed is fixed and printed in the failure prefix. All edits
    // are independently booked from stored cells, not from the quantity ledger.
    constexpr std::uint32_t seed = 0x6185A17U;
    const int left = -128, top = -64, width = 384, height = 256;
    const RectI64 all{left, top, width, height};
    const auto run = [&](std::uint32_t workers) {
        auto world = std::make_unique<World>(config(workers, 3));
        rect(*world, left, top, width, 1, Material::Wall);
        rect(*world, left, top + height - 1, width, 1, Material::Wall);
        rect(*world, left, top, 1, height, Material::Wall);
        rect(*world, left + width - 1, top, 1, height, Material::Wall);
        world->configure_transient_obstacles(all);
        std::mt19937 random(seed);
        std::uint64_t expected = 0;
        constexpr std::array<int, 12> seams{-65, -64, -1, 0, 63, 64, 127, 128, 191, 192, 62, 129};
        for (int t = 0; t < 240; ++t) {
            world->clear_transient_obstacles();
            if (t % 7 != 0) {
                const int mx = 54 + (t % 82), my = 74 + (t % 29);
                for (int y = my; y < my + 8; ++y)
                    for (int x = mx; x < mx + 12; ++x) (void)world->set_transient_obstacle(x, y, 1);
            }
            for (int edit = 0; edit < 6; ++edit) {
                const int x = seams[random() % seams.size()];
                const int y = top + 1 + static_cast<int>(random() % static_cast<unsigned>(height - 2));
                const auto before = world->water_quantity({x, y, 1, 1});
                const auto choice = random() % 5U;
                if (choice < 3U) {
                    const auto units = static_cast<std::uint16_t>(1U + random() % 255U);
                    (void)world->set_cell_state(x, y, Material::Water, units, 0);
                } else {
                    world->set(x, y, choice == 3U ? Material::Empty : Material::Wall);
                }
                const auto after = world->water_quantity({x, y, 1, 1});
                require(expected >= before, "seed 0x6185A17 external edit book underflow");
                expected = expected - before + after;
            }
            (void)world->tick();
            require(!world->has_failed(), "seed 0x6185A17 World quarantined");
            require(world->water_quantity(all) == expected,
                    "seed 0x6185A17 seam/mask/edit quantity mismatch at tick " + std::to_string(t));
            const auto ledger = world->quantity_ledger();
            require(ledger.water_visible + ledger.water_overfill == expected,
                    "seed 0x6185A17 ledger total mismatch");
            if (t % 20 == 0) {
                std::uint64_t population = 0;
                for (int y = top; y < top + height; ++y)
                    for (int x = left; x < left + width; ++x)
                        if (world->stored_material(x, y) == Material::Water) {
                            require(world->stored_state_a(x, y) > 0U, "seed 0x6185A17 zero-mass Water");
                            ++population;
                        }
                require(ledger.material_cells[static_cast<std::size_t>(Material::Water)] == population,
                        "seed 0x6185A17 Water population mismatch");
            }
        }
        world->clear_transient_obstacles();
        return world;
    };
    const auto reference = run(1);
    for (const auto workers : {2U, 4U, 6U}) {
        const auto concurrent = run(workers);
        require(reference->physical_state_hash() == concurrent->physical_state_hash(),
                "seed 0x6185A17 complete state depends on worker count " + std::to_string(workers));
        require(reference->quantity_ledger() == concurrent->quantity_ledger(),
                "seed 0x6185A17 ledger depends on worker count");
    }
}

void physical_identity_names_wave_and_substeps() {
    World ordinary{WorldConfig{}};
    World one(config(1, 1)), three(config(1, 3));
    require(ordinary.physical_state_hash_version() != one.physical_state_hash_version(),
            "Wave reused the legacy complete-state identity version");
    require(one.physical_state_hash() != ordinary.physical_state_hash(),
            "complete-state identity omitted Wave selection");
    require(one.physical_state_hash() != three.physical_state_hash(),
            "complete-state identity omitted Wave substeps");
    require(one.physical_state_format_version() == 0U,
            "unsupported Wave save advertised a legacy wire format");
}

void paused_flux_is_retained_and_edits_retire_faces() {
    World world(config(4));
    const int width = 256, height = 128;
    box(world, width, height);
    rect(world, 1, 80, width - 2, 47, Material::Water);
    rect(world, 48, 64, 32, 16, Material::Water);
    for (int t = 0; t < 5; ++t) (void)world.tick();
    struct Sample { Material material; std::uint16_t mass; std::int32_t flux; };
    std::vector<Sample> before;
    int witness_x = -1, witness_y = -1;
    for (int y = 0; y < height; ++y)
        for (int x = 0; x < width; ++x) {
            const auto flux = world.wave_flow_flux(x, y);
            before.push_back({world.stored_material(x, y), world.stored_state_a(x, y), flux});
            if (flux != 0 && witness_x < 0) { witness_x = x; witness_y = y; }
        }
    require(witness_x >= 0, "paused-flux fixture generated no moving face");
    const auto quantity = world.water_quantity({0, 0, width, height});
    world.set_simulation_region(RectI64{1024, 1024, 64, 64});
    for (int t = 0; t < 70; ++t) (void)world.tick();
    std::size_t at = 0;
    for (int y = 0; y < height; ++y)
        for (int x = 0; x < width; ++x) {
            const auto& sample = before[at++];
            require(world.stored_material(x, y) == sample.material && world.stored_state_a(x, y) == sample.mass &&
                        world.wave_flow_flux(x, y) == sample.flux,
                    "paused Wave state decayed or moved");
        }
    const auto retired = world.water_quantity({witness_x, witness_y, 1, 1});
    world.set(witness_x, witness_y, Material::Wall);
    require(world.wave_flow_flux(witness_x, witness_y) == 0 &&
                world.wave_flow_flux(witness_x - 1, witness_y) == 0,
            "material edit retained flux through an invalid face");
    world.set_simulation_region(std::nullopt);
    for (int t = 0; t < 60; ++t) (void)world.tick();
    require(world.water_quantity({0, 0, width, height}) == quantity - retired,
            "resuming after a paused material edit changed unbooked Water");
}

void region_boundary_flux_freezes_while_source_falls() {
    for (const int seam : {63, 127}) {
        World world(config(4));
        const int width = 192, height = 192;
        box(world, width, height);
        require(world.set_cell_state(seam, 20, Material::Water, 192, 0), "boundary source refused");
        require(world.set_cell_state(seam + 1, 20, Material::Water, 64, 0), "boundary receiver refused");
        (void)world.tick();
        const auto flux = world.wave_flow_flux(seam, 21);
        const auto receiver = world.stored_state_a(seam + 1, 21);
        const auto quantity = world.water_quantity({0, 0, width, height});
        require(flux != 0 && receiver != 0U, "partial-region fixture generated no boundary flux");
        world.set_simulation_region(RectI64{0, 0, seam + 1, height});
        for (int t = 0; t < 60; ++t) {
            (void)world.tick();
            require(world.wave_flow_flux(seam, 21) == flux,
                    "falling included source erased a paused boundary face");
            require(world.stored_state_a(seam + 1, 21) == receiver,
                    "included source changed a paused receiver");
            require(world.water_quantity({0, 0, width, height}) == quantity,
                    "partially paused falling pair lost Water");
        }
        require(world.stored_state_a(seam, 21) == 0U,
                "included source did not drain while its receiver was paused");
        world.set_simulation_region(std::nullopt);
        (void)world.tick();
        require(world.stored_state_a(seam + 1, 21) == 0U,
                "paused boundary receiver did not resume falling");
        require(world.water_quantity({0, 0, width, height}) == quantity,
                "boundary-face reentry lost Water");
    }
}

void c_api_construction_and_overfill_are_lossless() {
    auto cfg = cybersand_default_config_v2();
    cfg.worker_threads = 4;
    cfg.parallel_job_threshold = 2;
    cybersand_wave_flow_config_v1 request{
        sizeof(cybersand_wave_flow_config_v1), CYBERSAND_WAVE_FLOW_CONFIG_V1_ABI_VERSION, 1, 3};
    cybersand_liquid_policy_refusal_v1 refusal{};
    refusal.struct_size = sizeof(refusal);
    const auto create = [&](const cybersand_wave_flow_config_v1& value) {
        return std::unique_ptr<cybersand_world, decltype(&cybersand_world_destroy)>(
            cybersand_world_create_with_wave_flow_v1(&cfg, &value, &refusal), &cybersand_world_destroy);
    };
    for (const int bad : {0, 1, 2, 3}) {
        auto invalid = request;
        if (bad == 0) invalid.struct_size = 1;
        if (bad == 1) invalid.abi_version = 99;
        if (bad == 2) invalid.enabled = 2;
        if (bad == 3) invalid.substeps = 0;
        const auto rejected = create(invalid);
        require(rejected == nullptr && refusal.code != CYBERSAND_LIQUID_POLICY_ACCEPTED,
                "C API accepted malformed Wave construction");
    }
    auto world = create(request);
    require(world != nullptr && refusal.code == CYBERSAND_LIQUID_POLICY_ACCEPTED,
            "C API rejected supported Wave construction");
    const auto paint = [&](int x, int y, int width, int height, Material material) {
        for (int yy = y; yy < y + height; ++yy)
            for (int xx = x; xx < x + width; ++xx)
                require(cybersand_world_set_v2(world.get(), xx, yy, static_cast<std::uint16_t>(material)) != 0,
                        "C API fixture paint failed");
    };
    const int width = 160, height = 160;
    paint(0, 0, width, 1, Material::Wall);
    paint(0, height - 1, width, 1, Material::Wall);
    paint(0, 0, 1, height, Material::Wall);
    paint(width - 1, 0, 1, height, Material::Wall);
    paint(50, 1, 60, height - 5, Material::Wall);
    paint(1, 40, 49, height - 41, Material::Water);
    paint(50, height - 4, 60, 3, Material::Water);
    paint(110, 120, width - 111, height - 121, Material::Water);
    const auto expected = (49U * 119U + 60U * 3U + 49U * 39U) * 255U;
    bool overfilled = false;
    for (int t = 0; t < 300; ++t) {
        cybersand_tick_stats_v2 stats{};
        require(cybersand_world_tick_v2(world.get(), &stats) != 0, "C API Wave tick failed");
        if (t % 20 != 0 && t != 299) continue;
        std::uint64_t total = 0;
        for (int y = 0; y < height; ++y)
            for (int x = 0; x < width; ++x) {
                const auto wide = cybersand_world_liquid_mass_v2(world.get(), x, y);
                const auto legacy = cybersand_world_liquid_mass(world.get(), x, y);
                total += wide;
                require(legacy == std::min<std::uint16_t>(wide, 255U),
                        "legacy C API wrapped instead of saturating Water mass");
                overfilled = overfilled || wide > 255U;
            }
        require(total == expected, "wide C API did not retain all sealed-passage Water");
    }
    require(overfilled, "C API overfill regression never produced overfill");
    require(cybersand_world_liquid_mass_v2(nullptr, 0, 0) == 0U,
            "wide C API null-world contract changed");
}

void extreme_legal_overfill_conserves_and_remains_editable() {
    for (const auto workers : {1U, 4U}) {
        World world(config(workers, 8));
        // A sealed three-cell stack starts with far more than one uint16 top
        // cell can retain. The column pass must distribute the retained excess
        // without wrapping, clamping it away, or quarantining a legal state.
        rect(world, 59, 59, 12, 8, Material::Wall);
        require(world.set_cell_state(60, 60, Material::Water, 65535, 0), "upper overfill seed refused");
        require(world.set_cell_state(60, 61, Material::Water, 65535, 0), "middle overfill seed refused");
        require(world.set_cell_state(60, 62, Material::Water, 32000, 0), "lower overfill seed refused");
        // Opposing high heads feed receivers across the x=64 worker strip.
        for (int x = 61; x <= 69; ++x)
            require(world.set_cell_state(x, 62, Material::Water,
                        static_cast<std::uint16_t>(x % 2 == 0 ? 65535 : 1), 0), "lateral overfill seed refused");
        const auto expected = world.water_quantity({59, 59, 12, 8});
        for (int t = 0; t < 1100; ++t) {
            (void)world.tick();
            require(!world.has_failed(), "legal extreme overfill quarantined the World");
            require(world.water_quantity({59, 59, 12, 8}) == expected,
                    "extreme sealed overfill lost or created Water");
        }
        const auto ledger = world.quantity_ledger();
        require(ledger.water_visible + ledger.water_overfill == expected,
                "extreme overfill ledger mismatch");
        std::int64_t edit_x = -1, edit_y = -1;
        for (int y = 60; y <= 62; ++y)
            for (int x = 60; x <= 69; ++x)
                if (world.stored_material(x, y) == Material::Water && world.stored_state_a(x, y) > 256U) {
                    edit_x = x; edit_y = y;
                }
        require(edit_x >= 0, "extreme overfill fixture stopped holding overfilled cells");
        const auto mass = world.stored_state_a(edit_x, edit_y);
        require(world.set_cell_state(edit_x, edit_y, Material::Water, static_cast<std::uint16_t>(mass - 1U), 0),
                "metered removal from overfilled Water was refused");
        require(world.water_quantity({59, 59, 12, 8}) == expected - 1U,
                "metered overfill removal did not remove exactly one unit");
        (void)world.tick();
        require(world.water_quantity({59, 59, 12, 8}) == expected - 1U,
                "overfill edit damaged subsequent continuation");
    }
    World legacy{WorldConfig{}};
    bool refused = false;
    try { (void)legacy.set_cell_state(0, 0, Material::Water, 256, 0); }
    catch (const std::invalid_argument&) { refused = true; }
    require(refused && legacy.chunk_count() == 0U, "Wave overfill admission changed default Water edits");
}

void coordinate_extrema_refuse_before_mutation() {
    World world(config());
    const auto hash = world.physical_state_hash();
    for (const auto coordinate : {std::numeric_limits<std::int64_t>::min(),
                                  std::numeric_limits<std::int64_t>::max()}) {
        for (const bool vertical : {false, true}) {
            bool refused = false;
            try { world.set(vertical ? 0 : coordinate, vertical ? coordinate : 0, Material::Water); }
            catch (const std::overflow_error&) { refused = true; }
            require(refused, "Wave accepted a coordinate without arithmetic halo headroom");
            require(world.chunk_count() == 0U && world.physical_state_hash() == hash,
                    "coordinate-fringe refusal mutated the World");
        }
    }
    // A very distant but valid sparse coordinate remains usable in both signs.
    for (const std::int64_t offset : {-1'000'000'000'000LL, 1'000'000'000'000LL}) {
        World far(config(1));
        require(far.set_cell_state(offset, offset, Material::Water, 1, 0), "valid distant drop refused");
        for (int t = 0; t < 70; ++t) (void)far.tick();
        require(far.water_quantity({offset - 2, offset, 5, 80}) == 1U,
                "distant sparse drop changed quantity");
        require(far.stored_state_a(offset, offset + 70) == 1U,
                "distant sparse drop did not descend at one cell per round");
    }
}

// A mask and resident Water may each be legal while the distance between
// their origins exceeds INT64_MAX. A remote body must behave exactly like
// the unmasked control; exercise both row clipping and column membership.
void check_distant_mask_transport(std::int64_t water_origin, std::int64_t mask_origin) {
    constexpr int drops = 32, spacing = 16, ticks = 16;
    for (const bool vertical : {true, false}) {
        const auto run = [&](std::uint32_t workers) {
            World reference(config(1)), masked(config(workers));
            const std::int64_t x = vertical ? 0 : water_origin;
            const std::int64_t y = vertical ? water_origin : 0;
            for (int drop = 0; drop < drops; ++drop) {
                const auto at_x = x + drop * spacing;
                require(reference.set_cell_state(at_x, y, Material::Water, 1, 0) &&
                            masked.set_cell_state(at_x, y, Material::Water, 1, 0),
                        "distant-mask fixture rejected legal Water");
            }
            const RectI64 mask{vertical ? 0 : mask_origin, vertical ? mask_origin : 0, 2, 2};
            masked.configure_transient_obstacles(mask);
            require(masked.set_transient_obstacle(mask.x, mask.y, 1), "distant mask body refused");
            const RectI64 observed{x - 2, y - 1, (drops - 1) * spacing + 5, ticks + 4};
            for (int tick = 0; tick < ticks; ++tick) {
                (void)reference.tick();
                (void)masked.tick();
                require(!reference.has_failed() && !masked.has_failed(), "distant mask quarantined a World");
                require(masked.water_quantity(observed) == drops && reference.water_quantity(observed) == drops,
                        "distant mask changed the Water quantity");
                const auto ledger = masked.quantity_ledger();
                require(ledger.water_visible + ledger.water_overfill + ledger.water_ballistic == drops,
                        "distant mask damaged the quantity ledger");
                for (std::int64_t dy = 0; dy < observed.height; ++dy)
                    for (std::int64_t dx = 0; dx < observed.width; ++dx) {
                        const auto px = observed.x + dx, py = observed.y + dy;
                        require(reference.stored_material(px, py) == masked.stored_material(px, py) &&
                                    reference.stored_state_a(px, py) == masked.stored_state_a(px, py) &&
                                    reference.wave_flow_flux(px, py) == masked.wave_flow_flux(px, py),
                                "remote body changed local Wave transport");
                    }
            }
            require(reference.stored_material(x, y) == Material::Empty,
                    "distant-mask control never transported Water");
            require(masked.transient_contact_count(1) == 0U, "remote body received a local Water contact");
            require(workers == 1U || masked.wave_flow_diagnostics().maximum_participants > 1U,
                    "distant-mask parallel fixture had only one participant");
            return masked.physical_state_hash();
        };
        require(run(1) == run(4), "distant-mask continuation depends on the worker count");
    }
}

void distant_positive_masks_preserve_wave_transport() {
    check_distant_mask_transport(-5'000'000'000'000'000'000LL, 5'000'000'000'000'000'000LL);
}

void distant_negative_masks_preserve_wave_transport() {
    check_distant_mask_transport(5'000'000'000'000'000'000LL, -5'000'000'000'000'000'000LL);
}

// Four separated, one-cell-wide shafts distinguish real body support from
// mere non-crashing clipping. First/last mask columns must block; immediately
// outside columns must remain open. Only representable cells with normal
// Wave halo headroom are occupied, even when a mask's mathematical exclusive
// endpoint lies beyond INT64_MAX.
void mask_overlap_at_signed_bounds_preserves_bodies() {
    const auto check = [&](RectI64 mask, bool overflowing_x) {
        const std::array<std::int64_t, 4> xs = overflowing_x
            ? std::array<std::int64_t, 4>{mask.x - 1, mask.x, mask.x + 128, mask.x + 256}
            : std::array<std::int64_t, 4>{mask.x - 1, mask.x, mask.x + 63, mask.x + 64};
        const std::array<bool, 4> occupied{false, true, true, overflowing_x};
        const auto run = [&](std::uint32_t workers) {
            World world(config(workers));
            world.configure_transient_obstacles(mask);
            for (std::size_t shaft = 0; shaft < xs.size(); ++shaft) {
                const auto x = xs[shaft];
                const auto receiver_y = mask.y + 4 + static_cast<std::int64_t>(shaft) * 20;
                for (int dy = -2; dy <= 6; ++dy) {
                    world.set(x - 1, receiver_y + dy, Material::Wall);
                    world.set(x + 1, receiver_y + dy, Material::Wall);
                }
                world.set(x, receiver_y - 2, Material::Wall);
                world.set(x, receiver_y + 6, Material::Wall);
                require(world.set_cell_state(x, receiver_y - 1, Material::Water, 255, 0),
                        "signed-bound mask fixture rejected legal Water");
                const auto body = static_cast<std::uint16_t>(shaft + 1U);
                require(world.set_transient_obstacle(x, receiver_y, body) == occupied[shaft],
                        "mask first/last/outside column membership differs");
            }
            for (int tick = 0; tick < 12; ++tick) {
                (void)world.tick();
                require(!world.has_failed(), "overlapping signed-bound mask quarantined the World");
                const auto ledger = world.quantity_ledger();
                require(ledger.water_visible + ledger.water_overfill + ledger.water_ballistic == 4U * 255U,
                        "overlapping signed-bound mask lost or created Water");
                for (std::size_t shaft = 0; shaft < xs.size(); ++shaft) {
                    if (!occupied[shaft]) continue;
                    const auto y = mask.y + 4 + static_cast<std::int64_t>(shaft) * 20;
                    require(world.stored_state_a(xs[shaft], y - 1) == 255U &&
                                world.stored_material(xs[shaft], y) == Material::Empty,
                            "signed-bound body failed to hold Water outside its occupied cell");
                }
            }
            for (std::size_t shaft = 0; shaft < xs.size(); ++shaft) {
                const auto y = mask.y + 4 + static_cast<std::int64_t>(shaft) * 20;
                const auto body = static_cast<std::uint16_t>(shaft + 1U);
                if (occupied[shaft]) {
                    require(world.transient_contact_count(body) > 0U && world.transient_contact_impulse_y(body) > 0,
                            "signed-bound body received no downward Water contact");
                } else {
                    require(world.stored_material(xs[shaft], y - 1) == Material::Empty &&
                                world.stored_state_a(xs[shaft], y + 5) == 255U &&
                                world.transient_contact_count(body) == 0U,
                            "Water outside the signed-bound mask did not descend freely");
                }
            }
            return world.physical_state_hash();
        };
        require(run(1) == run(4), "signed-bound mask continuation depends on the worker count");
    };
    constexpr auto minimum = std::numeric_limits<std::int64_t>::min();
    constexpr auto maximum = std::numeric_limits<std::int64_t>::max();
    check({minimum + 256, minimum + 256, 64, 96}, false);
    check({maximum - 384, maximum - 384, 64, 96}, false);
    // Exercise the x and y endpoint hazards independently, then together.
    check({maximum - 512, maximum - 512, 1024, 96}, true);
    check({maximum - 512, maximum - 512, 64, 1024}, false);
    check({maximum - 512, maximum - 512, 1024, 1024}, true);
}

void sparse_mask_bounds_follow_clear_move_and_reconfigure() {
    const auto run = [](std::uint32_t workers) {
        World world(config(workers));
        const std::array<std::int64_t, 3> xs{-100, 127, 220};
        const std::array<std::int64_t, 3> ys{-20, 64, 160};
        // Full canvas storage is deliberately much larger than the sparse
        // occupancy. The middle shaft straddles a chunk boundary.
        world.configure_transient_obstacles({-128, -128, 512, 512});
        for (std::size_t shaft = 0; shaft < xs.size(); ++shaft) {
            rect(world, static_cast<int>(xs[shaft] - 1), static_cast<int>(ys[shaft] - 2), 1, 10, Material::Wall);
            rect(world, static_cast<int>(xs[shaft] + 1), static_cast<int>(ys[shaft] - 2), 1, 10, Material::Wall);
            world.set(xs[shaft], ys[shaft] + 7, Material::Wall);
        }
        std::vector<std::uint64_t> hashes;
        // Shrink, expand, remove, then reconfigure the actual mask. No retained
        // bounds may hide the newly selected far-away body or preserve a ghost.
        const std::array<unsigned, 7> patterns{1U, 4U, 5U, 2U, 0U, 7U, 1U};
        for (std::size_t stage = 0; stage < patterns.size(); ++stage) {
            world.clear_transient_obstacles();
            if (stage == 5U) world.configure_transient_obstacles({-120, -64, 400, 300});
            for (std::size_t shaft = 0; shaft < xs.size(); ++shaft) {
                for (int dy = -1; dy < 7; ++dy) world.set(xs[shaft], ys[shaft] + dy, Material::Empty);
                require(world.set_cell_state(xs[shaft], ys[shaft] - 1, Material::Water, 255, 0),
                        "sparse moving mask Water preparation refused");
                const auto body = static_cast<std::uint16_t>(shaft + 1U);
                if ((patterns[stage] & (1U << shaft)) != 0U) {
                    require(world.set_transient_obstacle(xs[shaft], ys[shaft], body), "new sparse body refused");
                    require(!world.set_transient_obstacle(xs[shaft], ys[shaft], body), "duplicate body was admitted");
                }
            }
            require(!world.set_transient_obstacle(-1000, -1000, 1) &&
                        !world.set_transient_obstacle(xs[0], ys[0], 0),
                    "invalid/outside body changed the occupancy field");
            (void)world.tick();
            require(!world.has_failed(), "sparse moving mask failed native World");
            for (std::size_t shaft = 0; shaft < xs.size(); ++shaft) {
                const auto body = static_cast<std::uint16_t>(shaft + 1U);
                const bool occupied = (patterns[stage] & (1U << shaft)) != 0U;
                require(world.transient_obstacle_at(xs[shaft], ys[shaft]) == (occupied ? body : 0),
                        "clear/move retained an old body or lost a new one");
                require(world.stored_material(xs[shaft], ys[shaft]) == (occupied ? Material::Empty : Material::Water),
                        "sparse bound omitted a real blocker or invented a ghost blocker");
                require((world.transient_contact_count(body) > 0U) == occupied &&
                            (world.transient_contact_impulse_y(body) > 0) == occupied,
                        "sparse bound changed real downward body contact");
            }
            hashes.push_back(world.physical_state_hash());
            hashes.push_back(world.state_hash());
        }
        return hashes;
    };
    require(run(1) == run(4), "sparse mask bounds depend on worker count");
}

void tall_extreme_column_preserves_head_sign() {
    auto cfg = config(1);
    cfg.chunk_size = 8;
    cfg.activity_block_size = 8;
    cfg.scheduling_core_size = 8;
    cfg.maximum_chunk_count = 4300;
    cfg.active_chunk_capacity = 4300;
    cfg.active_core_capacity = 5000;
    World world(cfg);
    constexpr int height = 33024;
    rect(world, 1, 0, 1, height, Material::Wall);
    rect(world, 3, 0, 1, height, Material::Wall);
    world.set(2, 0, Material::Wall);
    world.set(2, height - 1, Material::Wall);
    for (int y = 1; y < height - 1; ++y)
        require(world.set_cell_state(2, y, Material::Water, 65535, 0), "tall overfill seed refused");
    // Its positive physical head exceeds a signed 32-bit accumulator. An
    // overflow would reverse the head and prevent discharge into this Empty
    // receiver. The solver must bound the head without changing mass.
    world.set(3, height - 2, Material::Empty);
    world.set(4, height - 2, Material::Wall);
    world.set(3, height - 1, Material::Wall);
    const auto expected = static_cast<std::uint64_t>(height - 2) * 65535U;
    (void)world.tick();
    require(world.water_quantity({0, 0, 8, height}) == expected,
            "tall extreme column lost Water");
    require(world.stored_state_a(3, height - 2) > 0U,
            "tall positive head overflowed or failed to discharge");
    require(!world.has_failed(), "tall legal column quarantined the World");
}


struct WaveSnapshot {
    std::vector<std::uint16_t> mass;
    std::vector<std::int32_t> flux;
    [[nodiscard]] bool operator==(const WaveSnapshot&) const = default;
};

WaveSnapshot snapshot(const World& world, int width, int height) {
    WaveSnapshot result;
    for (int y = 0; y < height; ++y)
        for (int x = 0; x < width; ++x) {
            result.mass.push_back(world.stored_material(x, y) == Material::Water ? world.stored_state_a(x, y) : 0);
            result.flux.push_back(world.wave_flow_flux(x, y));
        }
    return result;
}

// Ticks until no Wave chunk is solved, or -1 if the budget runs out first.
int ticks_until_rest(World& world, int budget) {
    for (int tick = 1; tick <= budget; ++tick) {
        (void)world.tick();
        if (world.wave_flow_diagnostics().last_solved_chunks == 0U) return tick;
    }
    return -1;
}

// Law version 1 never rested once disturbed: rounding every face to whole
// units at random fed a permanent slosh, so only a never-touched level pool
// stopped being solved. Rest must be reached from a real disturbance, at every
// depth, and must be a fixed point: solving the rested Water again changes
// neither a cell nor a retained flux.
void disturbed_water_reaches_exact_rest() {
    struct Case { int depth, budget; };
    for (const auto item : {Case{1, 9000}, Case{3, 7000}, Case{12, 5000}, Case{48, 4000}}) {
        const int width = 192, height = 128;
        const auto name = "depth " + std::to_string(item.depth);
        World world(config(4));
        box(world, width, height);
        const int surface = height - 1 - item.depth;
        rect(world, 1, surface, width - 2, item.depth, Material::Water);
        rect(world, 90, surface - 30, 12, 12, Material::Water); // a splash
        rect(world, 30, surface - 3, 4, 3, Material::Water);    // and a ripple
        const auto quantity = world.water_quantity({0, 0, width, height});
        const auto rested = ticks_until_rest(world, item.budget);
        require(rested > 0, name + ": disturbed Water was still being solved after " + std::to_string(item.budget) + " ticks");
        require(world.water_quantity({0, 0, width, height}) == quantity, name + ": coming to rest changed the Water quantity");
        check_well_formed(world, width, height, name.c_str());
        // Level to the unit: whole units cannot do better than a one-unit step.
        for (int x = 1; x + 1 < width - 1; ++x) {
            const auto here = static_cast<std::int64_t>(world.water_quantity({x, 0, 1, height}));
            const auto next = static_cast<std::int64_t>(world.water_quantity({x + 1, 0, 1, height}));
            require(std::llabs(here - next) <= 1, name + ": rested columns differ by more than one unit at x=" + std::to_string(x));
        }
        for (int y = 0; y < height; ++y)
            for (int x = 0; x < width; ++x)
                require(world.wave_flow_flux(x, y) == 0, name + ": rested Water retains flux");
        // Leaving and re-entering the simulation region wakes every chunk.
        // Solving the rested Water again must change nothing, and it must
        // fall asleep again.
        const auto before = snapshot(world, width, height);
        world.set_simulation_region(RectI64{8192, 8192, 64, 64});
        (void)world.tick();
        world.set_simulation_region(std::nullopt);
        (void)world.tick();
        require(world.wave_flow_diagnostics().last_solved_chunks > 0U, name + ": re-entry did not wake the rested Water");
        for (int tick = 0; tick < 2 * WaveFlowParameters::kSleepAfter; ++tick) (void)world.tick();
        require(snapshot(world, width, height) == before, name + ": solving rested Water again changed it");
        require(world.wave_flow_diagnostics().last_solved_chunks == 0U, name + ": rested Water did not fall asleep again");
    }
}

// A supported film above the adhesion threshold levels directly and stops:
// no momentum, at least one unit a round while the cells differ by more than one.
void films_level_and_rest() {
    const int width = 160, height = 48;
    {
        // A film across the whole floor with a hump in the middle.
        World world(config(2));
        box(world, width, height);
        for (int x = 1; x < width - 1; ++x)
            require(world.set_cell_state(x, height - 2, Material::Water, x >= 70 && x < 90 ? 200 : 60, 0), "film seed refused");
        const auto quantity = world.water_quantity({0, 0, width, height});
        const auto rested = ticks_until_rest(world, 4000);
        require(rested > 0, "a film with a hump never came to rest");
        require(world.water_quantity({0, 0, width, height}) == quantity, "levelling a film changed its quantity");
        for (int x = 1; x + 1 < width - 1; ++x)
            require(std::abs(static_cast<int>(world.stored_state_a(x, height - 2)) -
                             static_cast<int>(world.stored_state_a(x + 1, height - 2))) <= 1,
                    "rested film cells differ by more than one unit");
        for (int x = 0; x < width; ++x) require(world.wave_flow_flux(x, height - 2) == 0, "rested film retains flux");
    }
    {
        // A puddle on a dry floor spreads, keeps its residual film and stops.
        World world(config(2));
        box(world, width, height);
        for (int x = 70; x < 90; ++x)
            require(world.set_cell_state(x, height - 2, Material::Water, 230, 0), "puddle seed refused");
        const auto quantity = world.water_quantity({0, 0, width, height});
        const auto rested = ticks_until_rest(world, 4000);
        require(rested > 0, "a puddle on a dry floor never came to rest");
        require(world.water_quantity({0, 0, width, height}) == quantity, "a spreading puddle changed its quantity");
        require(count(world, width, height, Material::Water) > 20U, "the puddle did not spread");
        check_well_formed(world, width, height, "puddle");
    }
}

// Adhesion is a threshold for starting supported flow, not a minimum final
// mass. Both owned faces use the same pre-apply donor, so two-sided outflow can
// leave it below that threshold. The residue must conserve quantity, sleep at
// a real fixed point, and level further when adhesion is disabled.
void supported_film_uses_an_adhesion_threshold() {
    for (const int center : {63, 127}) { // half-strip and chunk seams
        for (const auto middle : {std::uint16_t{25}, std::uint16_t{32}}) {
            const auto run = [&](std::uint32_t workers) {
                World world(config(workers));
                rect(world, center - 2, 0, 5, 1, Material::Wall);
                rect(world, center - 2, 4, 5, 1, Material::Wall);
                rect(world, center - 2, 1, 1, 3, Material::Wall);
                rect(world, center + 2, 1, 1, 3, Material::Wall);
                require(world.set_cell_state(center - 1, 3, Material::Water, 1, 0) &&
                            world.set_cell_state(center, 3, Material::Water, middle, 0) &&
                            world.set_cell_state(center + 1, 3, Material::Water, 1, 0),
                        "adhesion threshold fixture seed refused");
                const RectI64 region{center - 2, 0, 5, 5};
                const auto quantity = world.water_quantity(region);
                const auto masses = [&] {
                    return std::array<std::uint16_t, 3>{world.stored_state_a(center - 1, 3),
                        world.stored_state_a(center, 3), world.stored_state_a(center + 1, 3)};
                };
                const auto expected = middle == 25U ? std::array<std::uint16_t, 3>{2, 23, 2}
                                                   : std::array<std::uint16_t, 3>{9, 16, 9};
                (void)world.tick();
                require(masses() == expected, "two-sided supported outflow lost its threshold semantics");
                require(world.water_quantity(region) == quantity, "two-sided film outflow changed quantity");
                const auto assert_stable_rest = [&] {
                    for (int tick = 0; tick < 2 * WaveFlowParameters::kSleepAfter; ++tick) {
                        (void)world.tick();
                        require(masses() == expected, "adhesion residue changed while coming to rest");
                        require(world.water_quantity(region) == quantity, "adhesion residue changed quantity");
                    }
                    require(world.wave_flow_diagnostics().last_solved_chunks == 0U,
                            "adhesion residue never stopped being solved");
                    require(world.wave_flow_flux(center - 1, 3) == 0 && world.wave_flow_flux(center, 3) == 0,
                            "rested adhesion residue retains momentum");
                };
                assert_stable_rest();
                const auto resting_content = world.content_hash();
                world.set_simulation_region(RectI64{8192, 8192, 64, 64});
                (void)world.tick();
                world.set_simulation_region(std::nullopt);
                (void)world.tick();
                require(world.wave_flow_diagnostics().last_solved_chunks > 0U,
                        "region re-entry did not wake adhesion residue");
                assert_stable_rest();
                require(world.content_hash() == resting_content, "re-solving adhesion residue changed its content");

                world.set_liquid_surface_adhesion_enabled(false);
                for (int tick = 0; tick < 2 * WaveFlowParameters::kSleepAfter; ++tick) {
                    (void)world.tick();
                    require(world.water_quantity(region) == quantity, "disabling adhesion changed film quantity");
                }
                const auto levelled = masses();
                require(std::abs(static_cast<int>(levelled[0]) - levelled[1]) <= 1 &&
                            std::abs(static_cast<int>(levelled[1]) - levelled[2]) <= 1,
                        "disabling adhesion did not let the residue level");
                require(world.wave_flow_diagnostics().last_solved_chunks == 0U,
                        "film did not return to rest with adhesion disabled");
                return world.physical_state_hash();
            };
            require(run(1) == run(4), "adhesion threshold continuation depends on the worker count");
        }
    }
}

// state_hash() is the hash hosts compare for "same state". Two Worlds with the
// same cells and different retained flux continue differently, so they must not
// share it. The Worlds differ only in where a one-cell body sat for one tick:
// on the right-hand column (freezing the face between the columns) or in the
// air above it. Afterwards every cell is equal and only the momentum differs.
void state_hash_binds_retained_momentum() {
    const int width = 64, height = 64;
    const int left = 31, right = 32, top = height - 3, bottom = height - 2;
    const auto build = [&](bool freeze_face) {
        auto world = std::make_unique<World>(config(1));
        box(*world, width, height);
        rect(*world, left - 1, top, 1, 2, Material::Wall);
        rect(*world, right + 1, top, 1, 2, Material::Wall);
        world->set(left, bottom, Material::Water);
        world->set(right, bottom, Material::Water);
        require(world->set_cell_state(left, top, Material::Water, 22, 0) &&
                    world->set_cell_state(right, top, Material::Water, 20, 0), "momentum fixture seed refused");
        world->configure_transient_obstacles({0, 0, width, height});
        require(world->set_transient_obstacle(right, freeze_face ? top : top - 1, 1), "momentum fixture body refused");
        (void)world->tick();
        world->clear_transient_obstacles();
        world->clear_transient_contact_observations();
        (void)world->tick();
        (void)world->tick();
        return world;
    };
    const auto moving = build(false), delayed = build(true);
    for (int y = 0; y < height; ++y)
        for (int x = 0; x < width; ++x)
            require(moving->stored_material(x, y) == delayed->stored_material(x, y) &&
                        moving->stored_state_a(x, y) == delayed->stored_state_a(x, y) &&
                        moving->stored_state_b(x, y) == delayed->stored_state_b(x, y),
                    "momentum fixture: the two Worlds' cells differ");
    require(moving->content_hash() == delayed->content_hash(), "momentum fixture: content differs");
    require(moving->stored_state_a(left, top) == 22U && moving->stored_state_a(right, top) == 20U,
            "momentum fixture: Water already moved, so the cells no longer isolate momentum");
    require(moving->wave_flow_flux(left, top) != delayed->wave_flow_flux(left, top) ||
                moving->wave_flow_flux(left, bottom) != delayed->wave_flow_flux(left, bottom),
            "momentum fixture: both Worlds retain the same flux");
    require(moving->state_hash() != delayed->state_hash(),
            "equal cells with different retained flux share one state hash");
    require(moving->physical_state_hash() != delayed->physical_state_hash(),
            "equal cells with different retained flux share one physical identity");
    // Different rounds per tick is a different law even before the first tick.
    World one(config(1, 1)), three(config(1, 3));
    require(one.state_hash() != three.state_hash(), "state hash ignores the Wave substep count");
    auto tuned_config = config(1, 1);
    tuned_config.wave_flow.gain += 1;
    World tuned(tuned_config);
    require(one.state_hash() != tuned.state_hash(), "state hash ignores Wave authoring tuning");
    require(one.physical_state_hash() != tuned.physical_state_hash(), "physical identity ignores Wave authoring tuning");
    // Worlds without Wave Flow keep their historical hash definition.
    WorldConfig plain;
    World first(plain), second(plain);
    first.set(3, 3, Material::Sand);
    second.set(3, 3, Material::Sand);
    require(first.state_hash() == second.state_hash(), "plain Worlds lost their state hash");
}

void slosh_short_ripples_and_shallow_front() {
    const auto sample = [](int smooth, int deep, bool film) {
        auto cfg = config(1);
        cfg.wave_flow.deep_gain = deep;
        cfg.wave_flow.flux_smoothing = smooth;
        World world(cfg);
        box(world, 64, 32);
        if (film) {
            rect(world, 24, 30, 16, 1, Material::Water);
        } else {
            rect(world, 1, 21, 62, 10, Material::Water);
            for (int x = 2; x < 62; x += 2) world.set(x, 20, Material::Water);
        }
        double ripple_energy = 0;
        for (int t = 0; t < 50; ++t) {
            (void)world.tick();
            if (film || t < 5) continue;
            // Nyquist component in the tank interior; alternate sign each
            // column, so a broad surface tilt contributes very little.
            double amplitude = 0;
            for (int x = 8; x < 56; ++x) amplitude += level(world, x, 32) * (x % 2 ? -1 : 1);
            ripple_energy += amplitude * amplitude;
        }
        return std::pair{ripple_energy, world.content_hash()};
    };
    const auto unfiltered = sample(0, 16, false), filtered = sample(48, 16, false);
    require(unfiltered.first > 0 && filtered.first < unfiltered.first / 2,
            "flux smoothing did not damp short-wavelength surface energy");
    require(sample(0, 512, false).second != unfiltered.second, "deep gain did not affect a pool");
    require(sample(0, 16, true).second == sample(0, 512, true).second, "deep gain changed a shallow front");
}

void slosh_admission_identity_and_worker_parity() {
    expect_refusal([](WorldConfig& c) { c.wave_flow.deep_gain = -1; }, "negative deep gain");
    expect_refusal([](WorldConfig& c) { c.wave_flow.deep_gain = 513; }, "excessive deep gain");
    expect_refusal([](WorldConfig& c) { c.wave_flow.flux_smoothing = -1; }, "negative smoothing");
    expect_refusal([](WorldConfig& c) { c.wave_flow.flux_smoothing = 65; }, "unstable smoothing");
    World original(config(1));
    for (const auto pair : std::array<std::array<int, 2>, 3>{{{512, 0}, {0, 64}, {512, 64}}}) {
        const auto run = [&](std::uint32_t workers) {
            auto cfg = config(workers, 1);
            cfg.wave_flow.deep_gain = pair[0];
            cfg.wave_flow.flux_smoothing = pair[1];
            World world(cfg);
            require(world.state_hash() != original.state_hash() &&
                    world.physical_state_hash() != original.physical_state_hash(), "slosh identity omitted a control");
            box(world, 194, 48);
            rect(world, 1, 36, 170, 11, Material::Water);
            rect(world, 48, 30, 16, 6, Material::Water);
            // Alternating top cells straddle both the half-strip and chunk seams.
            for (int x = 62; x < 150; x += 2) world.set(x, 35, Material::Water);
            rect(world, 172, 1, 1, 46, Material::Wall);
            for (int k = 0; k < 16; ++k) world.set(17 + k, 31 + k, Material::Wall);
            require(world.set_cell_state(170, 46, Material::Water, 65535, 0), "slosh overfill seed refused");
            const auto initial = world.water_quantity({0, 0, 194, 48});
            for (int tick = 0; tick < 34; ++tick) {
                if (tick == 5) world.set_simulation_region(RectI64{0, 0, 128, 128});
                if (tick == 20) world.set_simulation_region(std::nullopt);
                const auto paused_flux = world.wave_flow_flux(127, 42);
                const auto paused_quantity = world.water_quantity({128, 0, 66, 48});
                (void)world.tick();
                require(world.water_quantity({0, 0, 194, 48}) == initial, "slosh changed total mass");
                const auto ledger = world.quantity_ledger();
                require(ledger.water_visible + ledger.water_overfill == initial, "slosh ledger mismatch");
                require(world.water_quantity({173, 0, 20, 48}) == 0, "slosh crossed one-cell wall");
                if (tick >= 5 && tick < 20) {
                    require(world.wave_flow_flux(127, 42) == paused_flux &&
                            world.water_quantity({128, 0, 66, 48}) == paused_quantity, "slosh crossed paused face");
                }
            }
            return std::array<std::uint64_t, 2>{world.content_hash(), world.physical_state_hash()};
        };
        require(run(1) == run(6), "slosh cell content or complete identity depends on workers");
    }
}

}  // namespace

int main(int argc, char** argv) {
    std::string filter;
    if (argc == 3 && std::string(argv[1]) == "--filter") filter = argv[2];
    else if (argc != 1) {
        std::fprintf(stderr, "usage: test_wave_flow [--filter name-substring]\n");
        return 2;
    }
    struct Test {
        const char* name;
        void (*function)();
    };
    const Test tests[] = {
        {"disabled default and typed refusal", disabled_is_default_and_unsupported_is_refused},
        {"coherent Water edits refuse before zero-mass normalization", coherent_water_edits_refuse_before_zero_mass_normalization},
        {"dam break conserves and spreads", dam_break_conserves_and_spreads},
        {"worker counts are cell identical", worker_counts_are_cell_identical},
        {"waves propagate and interfere", waves_propagate_and_interfere},
        {"quiet water sleeps and wakes", quiet_water_sleeps_and_wakes},
        {"sealed passage equalises", sealed_passage_equalises},
        {"bodies block water and receive contacts", bodies_block_water_and_receive_contacts},
        {"other materials still interact", other_materials_still_interact},
        {"documented Water-owned chemistry is disabled", documented_water_owned_chemistry_is_disabled},
        {"ledger population follows spreading", ledger_population_follows_spreading},
        {"chunk capacity is an explicit outcome", chunk_capacity_is_an_explicit_outcome},
        {"tiny drops cross sleep and chunk boundaries", tiny_drops_cross_sleep_and_chunk_boundaries},
        {"erasing support reactivates a dormant film", erasing_support_reactivates_a_dormant_film},
        {"region pause freezes cells and reentry resumes", region_pause_freezes_cells_and_reentry_resumes},
        {"fixed-seed edits masks and seams conserve", fixed_seed_edits_masks_and_seams_conserve},
        {"physical identity names Wave and substeps", physical_identity_names_wave_and_substeps},
        {"paused flux is retained and edits retire faces", paused_flux_is_retained_and_edits_retire_faces},
        {"region boundary flux freezes while source falls", region_boundary_flux_freezes_while_source_falls},
        {"C API construction and overfill are lossless", c_api_construction_and_overfill_are_lossless},
        {"extreme legal overfill conserves and remains editable", extreme_legal_overfill_conserves_and_remains_editable},
        {"coordinate extrema refuse before mutation", coordinate_extrema_refuse_before_mutation},
        {"distant positive masks preserve Wave transport", distant_positive_masks_preserve_wave_transport},
        {"distant negative masks preserve Wave transport", distant_negative_masks_preserve_wave_transport},
        {"mask overlap at signed bounds preserves bodies", mask_overlap_at_signed_bounds_preserves_bodies},
        {"sparse mask bounds follow clear move and reconfigure", sparse_mask_bounds_follow_clear_move_and_reconfigure},
        {"tall extreme column preserves head sign", tall_extreme_column_preserves_head_sign},
        {"disturbed water reaches exact rest", disturbed_water_reaches_exact_rest},
        {"films level and rest", films_level_and_rest},
        {"supported film uses an adhesion threshold", supported_film_uses_an_adhesion_threshold},
        {"state hash binds retained momentum", state_hash_binds_retained_momentum},
        {"prepared uint16 payload and quantity are lossless", prepared_uint16_payload_and_quantity_are_lossless},
        {"slosh short ripples and shallow front", slosh_short_ripples_and_shallow_front},
        {"slosh admission identity and worker parity", slosh_admission_identity_and_worker_parity},
    };
    int failures = 0, executed = 0;
    for (const auto& test : tests) {
        if (!filter.empty() && std::string(test.name).find(filter) == std::string::npos) continue;
        ++executed;
        try {
            test.function();
            std::printf("PASS %s\n", test.name);
            std::fflush(stdout);
        } catch (const std::exception& error) {
            ++failures;
            std::printf("FAIL %s: %s\n", test.name, error.what());
            std::fflush(stdout);
        }
    }
    if (executed == 0) {
        std::fprintf(stderr, "No Wave Flow tests matched the filter.\n");
        return 2;
    }
    std::printf("WAVE_FLOW: %d tests; %d failures (%zu registered)\n", executed, failures, std::size(tests));
    return failures == 0 ? 0 : 1;
}
