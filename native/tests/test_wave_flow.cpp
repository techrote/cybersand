// WAVE-MT-001 wave_flow_v1: standalone native regressions for the opt-in bulk
// strip-parallel Water law. Build targets: make wave-flow-test /
// wave-flow-sanitize / wave-flow-thread-sanitize.
#include "cybersand/world.hpp"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <exception>
#include <functional>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
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
    expect_refusal([](WorldConfig& c) { c.backend = SimulationBackend::SerialInPlace; }, "serial backend");
    expect_refusal([](WorldConfig& c) { c.water_experiment_policy = WaterExperimentPolicy(6, 0); }, "6-bit mass");
    expect_refusal([](WorldConfig& c) { c.settled_discovery_enabled = true; }, "settled discovery");
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
    require(world.water_quantity({-256, -256, 768, 768}) == before, "capacity limit changed the Water quantity");
}

}  // namespace

int main() {
    struct Test {
        const char* name;
        void (*function)();
    };
    const Test tests[] = {
        {"disabled default and typed refusal", disabled_is_default_and_unsupported_is_refused},
        {"dam break conserves and spreads", dam_break_conserves_and_spreads},
        {"worker counts are cell identical", worker_counts_are_cell_identical},
        {"waves propagate and interfere", waves_propagate_and_interfere},
        {"quiet water sleeps and wakes", quiet_water_sleeps_and_wakes},
        {"sealed passage equalises", sealed_passage_equalises},
        {"bodies block water and receive contacts", bodies_block_water_and_receive_contacts},
        {"other materials still interact", other_materials_still_interact},
        {"chunk capacity is an explicit outcome", chunk_capacity_is_an_explicit_outcome},
    };
    int failures = 0;
    for (const auto& test : tests) {
        try {
            test.function();
            std::printf("PASS %s\n", test.name);
        } catch (const std::exception& error) {
            ++failures;
            std::printf("FAIL %s: %s\n", test.name, error.what());
        }
    }
    std::printf("WAVE_FLOW: %d tests; %d failures\n", static_cast<int>(std::size(tests)), failures);
    return failures == 0 ? 0 : 1;
}
