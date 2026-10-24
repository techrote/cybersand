// LCB-001 (#200) pressure_flow_v1 characterization harness (native, headless).
// Rebuilds the registered LCB geometries (dam depth ladder, vented / narrow /
// sealed two-limb heads) from their scenario definitions and prints the frozen
// screen metrics for Current (freemass_v1) and pressure_flow_v1/reference.
// Characterization screens are NOT admission criteria; this tool only reports.
//
//   build: g++ -std=c++20 -O2 -I native/include <simulation sources> native/bench/lcb_pressure_characterisation.cpp
//   run:   lcb_pressure_characterisation [dam|heads|all] [workers]
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/world.hpp"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <span>
#include <string>
#include <vector>

namespace {

using cybersand::LiquidSolverPolicy;
using cybersand::Material;
using cybersand::RectI64;
using cybersand::World;
using cybersand::WorldConfig;

WorldConfig config_for(bool pressure, std::uint32_t workers) {
    WorldConfig config;
    config.worker_threads = workers;
    config.maximum_chunk_count = 128;
    config.active_chunk_capacity = 128;
    config.active_core_capacity = 1024;
    config.parallel_job_threshold = 2;
    if (pressure) {
        auto words = LiquidSolverPolicy::default_request();
        words[21] = 3;
        auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        if (!decoded.accepted()) {
            std::fprintf(stderr, "pressure refused: %s\n", decoded.refusal.message().c_str());
            std::exit(2);
        }
        config.liquid_solver_policy = *decoded.policy;
    }
    return config;
}

void fill(World& world, std::int64_t x, std::int64_t y, std::int64_t w, std::int64_t h, Material material) {
    for (auto yy = y; yy < y + h; ++yy)
        for (auto xx = x; xx < x + w; ++xx) {
            if (material == Material::Water)
                (void)world.set_cell_state(xx, yy, Material::Water, world.config().water_experiment_policy.maximum(), 0);
            else if (material == Material::Empty)
                (void)world.set_cell_state(xx, yy, Material::Empty, 0, 0);
            else
                world.set(xx, yy, material);
        }
}

std::unique_ptr<World> frame(bool pressure, std::uint32_t workers) {
    auto world = std::make_unique<World>(config_for(pressure, workers));
    world->reserve_region({0, 0, 1024, 1024});
    fill(*world, 0, 0, 1024, 1, Material::Wall);
    fill(*world, 0, 1023, 1024, 1, Material::Wall);
    fill(*world, 0, 0, 1, 1024, Material::Wall);
    fill(*world, 1023, 0, 1, 1024, Material::Wall);
    return world;
}

double seconds_since(std::chrono::steady_clock::time_point start) {
    return std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
}

struct DamResult {
    std::int64_t front240 = 0;
    std::int64_t front1800 = 0;
    double retained1800 = 0.0;
    bool exact = true;
    double seconds = 0.0;
};

DamResult run_dam(bool pressure, std::int64_t depth, std::uint32_t workers, int horizon) {
    auto world = frame(pressure, workers);
    fill(*world, 32, 256, 960, 8, Material::Wall);
    fill(*world, 32, 64, 8, 192, Material::Wall);
    fill(*world, 984, 64, 8, 192, Material::Wall);
    fill(*world, 232, 64, 8, 192, Material::Wall);
    fill(*world, 40, 256 - depth, 192, depth, Material::Water);
    world->set_simulation_region(RectI64{16, 16, 992, 272});
    const RectI64 all{0, 0, 1024, 1024};
    const auto initial = world->water_quantity(all);
    const auto reservoir = world->water_quantity({40, 64, 192, 192});
    fill(*world, 232, 64, 8, 192, Material::Empty);  // gate erase indexed t0
    const auto front = [&]() {
        for (std::int64_t x = 983; x >= 240; --x)
            if (world->stored_material(x, 255) == Material::Water) return x - 240;
        return std::int64_t{0};
    };
    DamResult result;
    const auto start = std::chrono::steady_clock::now();
    for (int t = 1; t <= horizon; ++t) {
        (void)world->tick();
        if (t % 50 == 0 && world->water_quantity(all) != initial) result.exact = false;
        if (t == 240) result.front240 = front();
        if (t == horizon) {
            result.front1800 = front();
            result.retained1800 = static_cast<double>(world->water_quantity({40, 64, 192, 192})) /
                                  static_cast<double>(reservoir);
        }
    }
    result.seconds = seconds_since(start);
    return result;
}

std::int64_t surface(const World& world, std::int64_t x0, std::int64_t width) {
    // Level of a limb: the topmost row whose cells hold Water at the limb centre
    // band, refined by the partial mass of that row (fraction of a full row).
    const auto maximum = static_cast<double>(world.config().water_experiment_policy.maximum());
    double total = 0.0;
    for (std::int64_t y = 64; y < 256; ++y)
        for (std::int64_t x = x0; x < x0 + width; ++x)
            if (world.stored_material(x, y) == Material::Water)
                total += static_cast<double>(world.stored_state_a(x, y)) / maximum;
    // Limb water rows above the passage floor (y=255 is the bottom row).
    return static_cast<std::int64_t>(256.0 - total / static_cast<double>(width));
}

void run_heads(bool pressure, const char* name, bool narrow, bool sealed, std::uint32_t workers, int horizon) {
    auto world = frame(pressure, workers);
    const std::int64_t inner = narrow ? 190 : 184;
    fill(*world, 92, 256, 264, 8, Material::Wall);
    fill(*world, 92, 64, 8, 192, Material::Wall);
    fill(*world, 348, 64, 8, 192, Material::Wall);
    fill(*world, 148, 64, 8, inner, Material::Wall);
    fill(*world, 292, 64, 8, inner, Material::Wall);
    fill(*world, 156, 64, 136, inner, Material::Wall);
    if (sealed) {
        fill(*world, 100, 64, 48, 8, Material::Wall);
        fill(*world, 300, 64, 48, 8, Material::Wall);
    }
    fill(*world, 100, 96, 48, 160, Material::Water);
    fill(*world, 300, 216, 48, 40, Material::Water);
    fill(*world, 148, 64 + inner, 152, 256 - 64 - inner, Material::Water);
    world->set_simulation_region(RectI64{80, 48, 296, 224});
    const RectI64 all{0, 0, 1024, 1024};
    const auto initial = world->water_quantity(all);
    bool exact = true;
    const auto start = std::chrono::steady_clock::now();
    std::printf("%-26s %-9s", name, pressure ? "pressure" : "current");
    double first_bound = -1;
    double worst_after = 0;
    for (int t = 1; t <= horizon; ++t) {
        (void)world->tick();
        if (t % 50 == 0 && world->water_quantity(all) != initial) exact = false;
        const auto difference = static_cast<double>(surface(*world, 300, 48) - surface(*world, 100, 48));
        if (first_bound < 0 && difference <= 12.0 && difference >= -12.0) first_bound = t;
        if (first_bound >= 0) worst_after = std::max(worst_after, difference < 0 ? -difference : difference);
        if (t == 300 || t == 600 || t == 1200 || t == horizon)
            std::printf(" t%-4d L=%3lld R=%3lld diff=%6.1f |", t, static_cast<long long>(surface(*world, 100, 48)),
                        static_cast<long long>(surface(*world, 300, 48)), difference);
    }
    const auto gas = world->gas_compartments();
    std::printf(" exact=%d first<=12@%g worst-after=%.1f compartments=%zu %.1fs\n", exact ? 1 : 0, first_bound,
                worst_after, gas.size(), seconds_since(start));
    for (const auto& c : gas)
        std::printf("    gas id=%u amount=%llu volume=%llu gauge=%lld anchor=(%lld,%lld)\n", c.id,
                    static_cast<unsigned long long>(c.amount), static_cast<unsigned long long>(c.volume),
                    static_cast<long long>(c.gauge), static_cast<long long>(c.anchor_x),
                    static_cast<long long>(c.anchor_y));
}

}  // namespace

int main(int argc, char** argv) {
    const std::string mode = argc > 1 ? argv[1] : "all";
    const auto workers = static_cast<std::uint32_t>(argc > 2 ? std::atoi(argv[2]) : 1);
    const int dam_horizon = argc > 3 ? std::atoi(argv[3]) : 1800;
    const int head_horizon = argc > 4 ? std::atoi(argv[4]) : 2400;
    if (mode == "dam" || mode == "all") {
        for (const bool pressure : {false, true}) {
            DamResult results[3];
            const std::int64_t depths[3] = {48, 96, 160};
            for (int i = 0; i < 3; ++i) results[i] = run_dam(pressure, depths[i], workers, dam_horizon);
            for (int i = 0; i < 3; ++i)
                std::printf("dam depth-%-3lld %-9s front240=%4lld front%d=%4lld retained=%.3f exact=%d %.1fs\n",
                            static_cast<long long>(depths[i]), pressure ? "pressure" : "current",
                            static_cast<long long>(results[i].front240), dam_horizon,
                            static_cast<long long>(results[i].front1800), results[i].retained1800,
                            results[i].exact ? 1 : 0, results[i].seconds);
            std::printf("dam %-9s depth_response_t240=%.2f\n", pressure ? "pressure" : "current",
                        results[0].front240 > 0 ? static_cast<double>(results[2].front240) /
                                                      static_cast<double>(results[0].front240)
                                                : 0.0);
        }
    }
    if (mode == "vented") {
        run_heads(true, "head.vented-two-limb", false, false, workers, head_horizon);
        return 0;
    }
    if (mode == "heads" || mode == "all") {
        for (const bool pressure : {false, true}) {
            run_heads(pressure, "head.vented-two-limb", false, false, workers, head_horizon);
            run_heads(pressure, "head.narrow-passage", true, false, workers, head_horizon);
            run_heads(pressure, "head.sealed-two-limb", false, true, workers, head_horizon);
        }
    }
    return 0;
}
