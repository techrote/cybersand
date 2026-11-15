// WAVE-MT-001 source-matched complete-native-tick matrix.
// Usage: wave_mt_matrix SIZE SCENE FAMILY VARIANT WORKERS WARM TICKS [SUBSTEPS]
//   SIZE    512 | 1024 | 2048 (square finite World, walled)
//   SCENE   dam | pool | sparse | wave | idle
//   FAMILY  1 FreeMass, 2 CellularYield, 3 PressureFlow, 4 Inertial,
//           5 wave_flow_v1 (FreeMass carrier with WorldConfig::wave_flow)
//   VARIANT 0 reference, 1 cached, 2 cached_dormant (PressureFlow only)
//   WORKERS 0 = Auto (hardware threads), else exact
// Times the complete World::tick() only. One CSV row per process on stdout.
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#else
#include <sys/resource.h>
#endif

using namespace cybersand;

namespace {

std::uint64_t peak_rss_bytes() {
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS counters{};
    if (GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters)))
        return static_cast<std::uint64_t>(counters.PeakWorkingSetSize);
    return 0;
#else
    rusage usage{};
    getrusage(RUSAGE_SELF, &usage);
    return static_cast<std::uint64_t>(usage.ru_maxrss) * 1024ULL;
#endif
}

void rect(World& w, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) w.set(xx, yy, material);
}

void walls(World& w, int n) {
    rect(w, 0, 0, n, 1, Material::Wall);
    rect(w, 0, n - 1, n, 1, Material::Wall);
    rect(w, 0, 0, 1, n, Material::Wall);
    rect(w, n - 1, 0, 1, n, Material::Wall);
}

// Deterministic scripted disturbance: a block of Water dropped above the pool.
void drop(World& w, int cx, int top, int half_width, int height) {
    rect(w, cx - half_width, top, half_width * 2, height, Material::Water);
}

void build_scene(World& w, const std::string& scene, int n) {
    walls(w, n);
    if (scene == "dam") {
        // Tall reservoir on the left third, released at tick zero.
        rect(w, 1, n / 4, n / 3, n - 1 - n / 4, Material::Water);
    } else if (scene == "pool" || scene == "idle" || scene == "wave") {
        // Large interconnected body: bottom 40% of the World.
        rect(w, 1, n - 1 - (n * 2) / 5, n - 2, (n * 2) / 5, Material::Water);
    } else if (scene == "sparse") {
        // Small disconnected basins on a 128-cell lattice, each with a column
        // of Water falling into it.
        for (int by = 96; by + 40 < n; by += 128) {
            for (int bx = 32; bx + 72 < n; bx += 128) {
                rect(w, bx, by + 32, 64, 1, Material::Wall);
                rect(w, bx, by, 1, 32, Material::Wall);
                rect(w, bx + 63, by, 1, 32, Material::Wall);
                rect(w, bx + 8, by - 24, 12, 40, Material::Water);
            }
        }
    } else {
        throw std::runtime_error("unknown scene: " + scene);
    }
}

void disturb(World& w, const std::string& scene, int n, int tick) {
    if (scene != "wave") return;
    const int surface = n - 1 - (n * 2) / 5;
    // Two independent sources every 90 ticks.
    if (tick % 90 == 1) {
        drop(w, n / 4, surface - 48, 16, 24);
        drop(w, (n * 3) / 4, surface - 48, 16, 24);
    }
}

std::uint64_t percentile(const std::vector<std::uint64_t>& sorted, int p) {
    if (sorted.empty()) return 0;
    return sorted[std::min(sorted.size() - 1U,
                           (sorted.size() * static_cast<std::size_t>(p) + 99U) / 100U - 1U)];
}

int run(int argc, char** argv) {
    if (argc < 8) {
        std::cerr << "usage: SIZE SCENE FAMILY VARIANT WORKERS WARM TICKS\n";
        return 2;
    }
    const int n = std::stoi(argv[1]);
    const std::string scene = argv[2];
    const int family = std::stoi(argv[3]), variant = std::stoi(argv[4]);
    int workers = std::stoi(argv[5]);
    const int warm = std::stoi(argv[6]), ticks = std::stoi(argv[7]);
    const bool automatic = workers == 0;
    if (automatic) workers = static_cast<int>(std::max(1U, std::thread::hardware_concurrency()));

    WorldConfig cfg;
    cfg.initial_chunk_reserve = 320;
    cfg.maximum_chunk_count = 512;
    cfg.active_chunk_capacity = 512;
    cfg.active_core_capacity = 4096;
    cfg.worker_threads = static_cast<std::uint32_t>(workers);
    cfg.parallel_job_threshold = 2;
    cfg.backend = SimulationBackend::PhasedInPlace;
    if (family == 3) cfg.pressure_gas_compartment_capacity = 2048;
    if (family == 4) cfg.maximum_rule_radius = 3;
    auto request = LiquidSolverPolicy::default_request();
    // wave_flow_v1 is an execution opt-in on the fractional FreeMass carrier.
    const bool wave = family == 5;
    if (wave) {
        cfg.wave_flow.enabled = true;
        cfg.wave_flow.substeps = static_cast<std::uint8_t>(argc > 8 ? std::stoi(argv[8]) : 1);
    }
    request[21] = wave ? 1 : family;
    request[22] = variant;
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    if (!decoded.accepted()) throw std::runtime_error("policy refused: " + decoded.refusal.message());
    cfg.liquid_solver_policy = *decoded.policy;

    auto w = std::make_unique<World>(cfg);
    build_scene(*w, scene, n);
    const RectI64 all{0, 0, n, n};
    const auto water_initial = w->water_quantity(all);

    std::vector<std::uint64_t> samples;
    samples.reserve(static_cast<std::size_t>(ticks));
    std::uint64_t visited = 0, moved = 0, cores = 0, blocks = 0, total_ns = 0;
    std::uint32_t observed = 0;
    // "idle" lets the pool settle through the warm-up and then measures the
    // dormant cost; every other scene measures from the scripted state.
    for (int tick = 1; tick <= warm + ticks; ++tick) {
        disturb(*w, scene, n, tick);
        const auto start = std::chrono::steady_clock::now();
        const auto stats = w->tick();
        const auto ns = static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now() - start).count());
        if (tick <= warm) continue;
        samples.push_back(ns);
        total_ns += ns;
        visited += stats.visited_cells;
        moved += stats.moved_cells;
        cores += stats.scheduled_cores;
        blocks += stats.active_blocks_after;
        observed = std::max(observed, stats.worker_threads_observed);
    }
    const auto water_final = w->water_quantity(all);
    std::sort(samples.begin(), samples.end());
    const auto count = static_cast<std::uint64_t>(samples.size());
    const auto ms = [](std::uint64_t ns) { return static_cast<double>(ns) / 1.0e6; };
    std::cout << n << ',' << scene << ',' << family << ',' << variant << ','
              << (automatic ? "auto" : std::to_string(workers)) << ',' << workers << ',' << observed << ','
              << warm << ',' << ticks << ',' << ms(percentile(samples, 50)) << ','
              << ms(percentile(samples, 95)) << ',' << ms(samples.back()) << ','
              << (total_ns == 0 ? 0.0 : static_cast<double>(count) * 1.0e9 / static_cast<double>(total_ns)) << ','
              << visited / count << ',' << moved / count << ',' << cores / count << ',' << blocks / count << ','
              << water_initial << ',' << water_final << ',' << w->chunk_count() << ','
              << w->resident_cell_bytes() << ',' << peak_rss_bytes();
    const auto d = w->wave_flow_diagnostics();
    const auto per_tick = [&](std::uint64_t ns) {
        return d.ticks == 0 ? 0.0 : static_cast<double>(ns) / 1.0e6 / static_cast<double>(d.ticks);
    };
    std::cout << ',' << static_cast<int>(cfg.wave_flow.substeps) << ',' << d.last_tasks << ','
              << d.last_solved_chunks << ',' << d.maximum_participants << ','
              << per_tick(d.prepare_nanoseconds) << ',' << per_tick(d.column_nanoseconds) << ','
              << per_tick(d.flux_nanoseconds) << ',' << per_tick(d.apply_nanoseconds) << ','
              << per_tick(d.merge_nanoseconds) << ',' << d.storage_bytes << '\n';
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc == 2 && std::string(argv[1]) == "--header") {
        std::cout << "size,scene,family,variant,workers_requested,workers_configured,workers_observed,"
                     "warm_ticks,measured_ticks,tick_p50_ms,tick_p95_ms,tick_max_ms,native_ticks_per_s,"
                     "visited_per_tick,moved_per_tick,scheduled_cores_per_tick,active_blocks_after,"
                     "water_initial,water_final,chunks,resident_cell_bytes,peak_rss_bytes,"
                     "wave_substeps,wave_tasks_last,wave_solved_chunks_last,wave_max_participants,"
                     "wave_prepare_ms,wave_column_ms,wave_flux_ms,wave_apply_ms,wave_merge_ms,"
                     "wave_storage_bytes\n";
        return 0;
    }
    try {
        return run(argc, argv);
    } catch (const std::exception& e) {
        std::cerr << "apparatus_error=" << e.what() << "\n";
        return 1;
    }
}
