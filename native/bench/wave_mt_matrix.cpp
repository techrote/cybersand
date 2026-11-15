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
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstdint>
#include <iostream>
#include <memory>
#include <new>
#include <span>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#include <malloc.h>
#else
#include <sys/resource.h>
#endif

// Apparatus-only allocation probe. It is enabled exactly around the complete
// synchronous World::tick(), including work done by persistent pool threads.
// All compared laws carry the same instrumentation. This measures allocations
// and requested bytes, not allocator metadata or peak resident memory.
namespace allocations {
std::atomic<bool> enabled{false};
std::atomic<std::uint64_t> count{0}, bytes{0};
void record(std::size_t size) noexcept {
    if (!enabled.load(std::memory_order_relaxed)) return;
    count.fetch_add(1, std::memory_order_relaxed);
    bytes.fetch_add(size, std::memory_order_relaxed);
}
void* allocate(std::size_t size) {
    void* pointer = std::malloc(size == 0 ? 1 : size);
    if (pointer == nullptr) throw std::bad_alloc();
    record(size);
    return pointer;
}
void* aligned_allocate(std::size_t size, std::size_t alignment) {
    void* pointer = nullptr;
#ifdef _WIN32
    pointer = _aligned_malloc(size == 0 ? 1 : size, alignment);
#else
    if (posix_memalign(&pointer, alignment, size == 0 ? 1 : size) != 0) pointer = nullptr;
#endif
    if (pointer == nullptr) throw std::bad_alloc();
    record(size);
    return pointer;
}
void aligned_free(void* pointer) noexcept {
#ifdef _WIN32
    _aligned_free(pointer);
#else
    std::free(pointer);
#endif
}
} // namespace allocations

void* operator new(std::size_t size) { return allocations::allocate(size); }
void* operator new[](std::size_t size) { return allocations::allocate(size); }
void operator delete(void* pointer) noexcept { std::free(pointer); }
void operator delete[](void* pointer) noexcept { std::free(pointer); }
void operator delete(void* pointer, std::size_t) noexcept { std::free(pointer); }
void operator delete[](void* pointer, std::size_t) noexcept { std::free(pointer); }
void* operator new(std::size_t size, std::align_val_t alignment) {
    return allocations::aligned_allocate(size, static_cast<std::size_t>(alignment));
}
void* operator new[](std::size_t size, std::align_val_t alignment) {
    return allocations::aligned_allocate(size, static_cast<std::size_t>(alignment));
}
void operator delete(void* pointer, std::align_val_t) noexcept { allocations::aligned_free(pointer); }
void operator delete[](void* pointer, std::align_val_t) noexcept { allocations::aligned_free(pointer); }
void operator delete(void* pointer, std::size_t, std::align_val_t) noexcept { allocations::aligned_free(pointer); }
void operator delete[](void* pointer, std::size_t, std::align_val_t) noexcept { allocations::aligned_free(pointer); }

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
    if (argc < 8 || argc > 9) {
        std::cerr << "usage: SIZE SCENE FAMILY VARIANT WORKERS WARM TICKS [SUBSTEPS]\n";
        return 2;
    }
    const int n = std::stoi(argv[1]);
    const std::string scene = argv[2];
    const int family = std::stoi(argv[3]), variant = std::stoi(argv[4]);
    int workers = std::stoi(argv[5]);
    const int warm = std::stoi(argv[6]), ticks = std::stoi(argv[7]);
    const int substeps = argc > 8 ? std::stoi(argv[8]) : 1;
    if (n < 128 || n > 2048 || workers < 0 || workers > 256 || warm < 0 || ticks < 1 ||
        warm > 100000 || ticks > 100000 || family < 1 || family > 5 ||
        variant < 0 || variant > 2 || (family != 3 && variant != 0) ||
        substeps < 1 || substeps > WaveFlowParameters::kMaximumSubsteps ||
        (family != 5 && substeps != 1))
        throw std::invalid_argument("invalid size, solver, worker count or measurement window");
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
        cfg.wave_flow.substeps = static_cast<std::uint8_t>(substeps);
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
    std::uint64_t tick_allocations = 0, tick_allocated_bytes = 0;
    std::uint64_t tick_allocations_max = 0, tick_allocated_bytes_max = 0;
    std::uint64_t solved_chunks = 0, wave_tasks = 0;
    WaveFlowDiagnostics warm_diagnostics{};
    std::uint64_t warm_storage_bytes = 0;
    // "idle" lets the pool settle through the warm-up and then measures the
    // dormant cost; every other scene measures from the scripted state.
    for (int tick = 1; tick <= warm + ticks; ++tick) {
        disturb(*w, scene, n, tick);
        allocations::count.store(0, std::memory_order_relaxed);
        allocations::bytes.store(0, std::memory_order_relaxed);
        allocations::enabled.store(true, std::memory_order_relaxed);
        const auto start = std::chrono::steady_clock::now();
        const auto stats = w->tick();
        const auto ns = static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now() - start).count());
        allocations::enabled.store(false, std::memory_order_relaxed);
        const auto count_allocated = allocations::count.load(std::memory_order_relaxed);
        const auto bytes_allocated = allocations::bytes.load(std::memory_order_relaxed);
        if (tick <= warm) {
            if (tick == warm) {
                warm_diagnostics = w->wave_flow_diagnostics();
                warm_storage_bytes = warm_diagnostics.storage_bytes;
            }
            continue;
        }
        samples.push_back(ns);
        total_ns += ns;
        visited += stats.visited_cells;
        moved += stats.moved_cells;
        cores += stats.scheduled_cores;
        blocks += stats.active_blocks_after;
        observed = std::max(observed, stats.worker_threads_observed);
        tick_allocations += count_allocated;
        tick_allocated_bytes += bytes_allocated;
        tick_allocations_max = std::max(tick_allocations_max, count_allocated);
        tick_allocated_bytes_max = std::max(tick_allocated_bytes_max, bytes_allocated);
    }
    const auto water_final = w->water_quantity(all);
    // Cross-check the independently scanned authority with booked sources and
    // sinks. Repeated splashes are external edits, so initial==final alone is
    // deliberately not the conservation criterion for that scene.
    const auto ledger = w->quantity_ledger();
    std::uint64_t produced = 0, consumed = 0;
    for (const auto& kind : ledger.kinds) { produced += kind.produced; consumed += kind.consumed; }
    const auto accounted = ledger.baseline_water + produced;
    if (accounted < consumed || accounted - consumed != water_final ||
        ledger.water_visible + ledger.water_overfill + ledger.water_ballistic != water_final)
        throw std::runtime_error("Water conservation/quantity ledger mismatch");
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
    solved_chunks = d.solved_chunks - warm_diagnostics.solved_chunks;
    wave_tasks = d.tasks - warm_diagnostics.tasks;
    const auto per_tick = [&](std::uint64_t ns, std::uint64_t before) {
        return static_cast<double>(ns - before) / 1.0e6 / static_cast<double>(count);
    };
    std::cout << ',' << static_cast<int>(cfg.wave_flow.substeps) << ',' << d.last_tasks << ','
              << d.last_solved_chunks << ',' << d.maximum_participants << ','
              << per_tick(d.prepare_nanoseconds, warm_diagnostics.prepare_nanoseconds) << ','
              << per_tick(d.column_nanoseconds, warm_diagnostics.column_nanoseconds) << ','
              << per_tick(d.flux_nanoseconds, warm_diagnostics.flux_nanoseconds) << ','
              << per_tick(d.apply_nanoseconds, warm_diagnostics.apply_nanoseconds) << ','
              << per_tick(d.merge_nanoseconds, warm_diagnostics.merge_nanoseconds) << ',' << d.storage_bytes << ','
              << ms(percentile(samples, 99)) << ',' << tick_allocations << ',' << tick_allocated_bytes << ','
              << tick_allocations_max << ',' << tick_allocated_bytes_max << ',' << warm_storage_bytes << ','
              << static_cast<double>(solved_chunks) / static_cast<double>(count) << ','
              << static_cast<double>(wave_tasks) / static_cast<double>(count) << ','
              << produced << ',' << consumed << ',' << ledger.water_visible << ',' << ledger.water_overfill << '\n';
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
                     "wave_storage_bytes,tick_p99_ms,tick_allocations_total,tick_allocated_bytes_total,"
                     "tick_allocations_max,tick_allocated_bytes_max,wave_storage_after_warmup,"
                     "wave_solved_chunks_per_tick,wave_tasks_per_tick,water_produced,water_consumed,"
                     "ledger_water_visible,ledger_water_overfill\n";
        return 0;
    }
    try {
        return run(argc, argv);
    } catch (const std::exception& e) {
        std::cerr << "apparatus_error=" << e.what() << "\n";
        return 1;
    }
}
