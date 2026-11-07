// Source-matched, deterministic native PressureFlow gas fastpath A/B.
// Build the same harness against accepted baseline and candidate world sources.
// No Rapier, render pacing or altered material inventory enters the timing.
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <stdexcept>
#include <span>
#include <vector>

namespace {
using namespace cybersand;
void require(bool ok, const char* why) {
    if (!ok) throw std::runtime_error(why);
}
void fill(World& world, std::int64_t x, std::int64_t y, std::int64_t w, std::int64_t h,
          Material material) {
    for (auto yy = y; yy < y + h; ++yy)
        for (auto xx = x; xx < x + w; ++xx) {
            if (material == Material::Water)
                require(world.set_cell_state(xx, yy, Material::Water,
                    world.config().water_experiment_policy.maximum(), 0), "water fill");
            else world.set(xx, yy, material);
        }
}
void build(World& world, bool mask) {
    // 360 small sealed gas pockets over one fixed 1024 x 512 canvas.
    // Most water neighbours are interior, while boundary probes, unallocated
    // air and resident chunk seams stay represented in every configuration.
    world.reserve_region({0, 0, 1024, 512});
    for (int row = 0; row < 12; ++row) {
        for (int column = 0; column < 30; ++column) {
            const auto x = static_cast<std::int64_t>(24 + column * 32);
            const auto y = static_cast<std::int64_t>(8 + row * 40);
            fill(world, x, y, 12, 1, Material::Wall);
            fill(world, x, y + 12, 12, 1, Material::Wall);
            fill(world, x, y, 1, 13, Material::Wall);
            fill(world, x + 11, y, 1, 13, Material::Wall);
            fill(world, x + 1, y + 11, 10, 1, Material::Water);
        }
    }
    world.configure_transient_obstacles({0, 0, 1024, 512});
    if (mask) {
        for (int i = 0; i < 8; ++i) {
            const auto x = static_cast<std::int64_t>(24 + (i * 3) * 32 + 5);
            const auto y = static_cast<std::int64_t>(8 + i * 40 + 5);
            require(world.set_transient_obstacle(x, y, static_cast<std::uint16_t>(i + 1)),
                    "mask installation");
        }
    }
}
WorldConfig config_for(bool gas, int variant, int workers) {
    WorldConfig config;
    config.maximum_chunk_count = 128;
    config.active_chunk_capacity = 128;
    config.active_core_capacity = 4096;
    config.worker_threads = static_cast<std::uint32_t>(workers);
    config.parallel_job_threshold = 2;
    config.workbench_parallel_pressure_heads = true;
    auto request = LiquidSolverPolicy::default_request();
    request[21] = 3;
    request[22] = variant;
    const auto family_count_at = request.size() - 2U;
    request[family_count_at] = 1;
    request.insert(request.begin() + static_cast<std::ptrdiff_t>(family_count_at) + 1,
                   {3, 1, 2, gas ? 1 : 0, 32});
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    require(decoded.accepted(), "pressure policy rejected");
    config.liquid_solver_policy = *decoded.policy;
    return config;
}
void one_mutation(World& world, int tick) {
    // Reopen/reseal a small rotating selection while all other compartments
    // remain stable; do not assume the whole stress canvas is dormant.
    for (int k = 0; k < 3; ++k) {
        const int choice = ((tick / 4) * 7 + k * 67) % 360;
        const auto x = static_cast<std::int64_t>(24 + (choice % 30) * 32 + 5);
        const auto y = static_cast<std::int64_t>(8 + (choice / 30) * 40);
        if (tick % 4 == 0) world.set(x, y, Material::Empty);
        else if (tick % 4 == 2) world.set(x, y, Material::Wall);
    }
}
} // namespace

int main(int argc, char** argv) {
    try {
        if (argc != 6) {
            std::fprintf(stderr, "usage: %s gas(0|1) variant(0|1|2) workers(1|4) mask(0|1) repetition\n", argv[0]);
            return 2;
        }
        const bool gas = std::atoi(argv[1]) != 0;
        const int variant = std::atoi(argv[2]);
        const int workers = std::atoi(argv[3]);
        const bool mask = std::atoi(argv[4]) != 0;
        const int repetition = std::atoi(argv[5]);
        require(variant >= 0 && variant < 3 && (workers == 1 || workers == 4) &&
                (repetition >= 0 && repetition < 4), "invalid args");
        World world(config_for(gas, variant, workers));
        build(world, mask);
        constexpr int warmup = 8;
        constexpr int measured = 32;
        std::vector<std::uint64_t> hashes;
        hashes.reserve(warmup + measured);
        std::vector<double> durations;
        durations.reserve(measured);
        for (int i = 0; i < warmup + measured; ++i) {
            one_mutation(world, i);
            const auto start = std::chrono::steady_clock::now();
            (void)world.tick();
            const auto stop = std::chrono::steady_clock::now();
            require(!world.has_failed(), "World tick failed");
            if (i >= warmup) {
                durations.push_back(std::chrono::duration<double, std::milli>(stop - start).count());
            }
            hashes.push_back(world.physical_state_hash());
        }
        const auto counters = world.pressure_optimization_snapshot().counters;
        std::sort(durations.begin(), durations.end());
        const auto median = (durations[durations.size()/2-1] + durations[durations.size()/2])/2;
        const auto p95 = durations[static_cast<std::size_t>(0.95 * (durations.size()-1))];
        std::printf("{\"gas\":%d,\"variant\":%d,\"workers\":%d,\"mask\":%d,\"repetition\":%d,"
                    "\"median_ms\":%.6f,\"p95_ms\":%.6f,\"gas_ns\":%llu,\"gas_seed_cells\":%llu,"
                    "\"gas_bfs_cells\":%llu,\"gas_relabel_cells\":%llu,\"hashes\":[",
                    gas, variant, workers, mask, repetition, median, p95,
                    static_cast<unsigned long long>(counters.gas_nanoseconds),
                    static_cast<unsigned long long>(counters.gas_seed_cells),
                    static_cast<unsigned long long>(counters.gas_bfs_cells),
                    static_cast<unsigned long long>(counters.gas_relabel_cells));
        for (std::size_t i = 0; i < hashes.size(); ++i) {
            std::printf("%s%llu", i ? "," : "", static_cast<unsigned long long>(hashes[i]));
        }
        std::puts("]}");
    } catch (const std::exception& e) {
        std::fprintf(stderr, "pf_gas_exact_pairs: %s\n", e.what());
        return 1;
    }
}
