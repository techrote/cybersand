// PUBPRES-PLAYABILITY-FINAL-001: complete native tick diagnostic with the
// current gameplay Wave law and the Workbench's full-canvas obstacle storage.
// This is a native causal screen, not a Rapier or graphical acceptance result.
// Usage: pubpres_mask_bounds SIZE BODIES WORKERS TICKS [PROFILE]
// PROFILE 0 is current gameplay (two rounds/spill/ballistics); 1 is historical
// one-round Wave. BODIES 0/1/8 selects none, one small aerial body, or separated
// bodies. All trajectories are deterministic and masks are rebuilt every tick.
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;

void rect(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx, yy, material);
}

WorldConfig configuration(int n, unsigned workers, bool historical) {
    WorldConfig cfg;
    const auto chunks = static_cast<std::size_t>(n / cfg.chunk_size + 2);
    cfg.maximum_chunk_count = chunks * chunks;
    cfg.initial_chunk_reserve = cfg.maximum_chunk_count;
    cfg.active_chunk_capacity = cfg.maximum_chunk_count;
    cfg.active_core_capacity = 4096;
    cfg.worker_threads = workers;
    cfg.parallel_job_threshold = 2;
    auto& wave = cfg.wave_flow;
    wave.enabled = true;
    if (historical) return cfg;
    wave.substeps = 2;
    wave.deep_gain = 32; wave.floor_gain = 1024; wave.flux_smoothing = 16;
    wave.coast = 32; wave.damp_shift = 16; wave.calm_damp_shift = 8;
    wave.calm = 128; wave.stick = 128; wave.sleep_after = 90;
    wave.body_push_by_mass = 1;
    wave.spill.enabled = true;
    wave.spill.sheet_rate = 64; wave.spill.coyote_ticks = 4;
    wave.spill.full_face = 1; wave.spill.fall = 3;
    wave.spill.draw = 127; wave.spill.draw_head = 255;
    wave.spill.deep_draw = 64; wave.spill.launch_budget = 128;
    cfg.ballistic_water.enabled = true;
    return cfg;
}

int run(int argc, char** argv) {
    if (argc < 5 || argc > 6) throw std::invalid_argument("SIZE BODIES WORKERS TICKS [PROFILE] required");
    const int n = std::stoi(argv[1]), bodies = std::stoi(argv[2]);
    const int workers = std::stoi(argv[3]), ticks = std::stoi(argv[4]);
    const int profile = argc == 6 ? std::stoi(argv[5]) : 0;
    if ((n != 512 && n != 1024 && n != 2048) || (bodies != 0 && bodies != 1 && bodies != 8) ||
        workers < 1 || workers > 8 || ticks < 1 || ticks > 4096 || profile < 0 || profile > 1)
        throw std::invalid_argument("invalid diagnostic parameters");
    World world(configuration(n, static_cast<unsigned>(workers), profile == 1));
    world.reserve_region({0, 0, n, n});
    world.configure_transient_obstacles({0, 0, n, n}, true);
    rect(world, 0, 0, n, 1, Material::Wall);
    rect(world, 0, n - 1, n, 1, Material::Wall);
    rect(world, 0, 0, 1, n, Material::Wall);
    rect(world, n - 1, 0, 1, n, Material::Wall);
    rect(world, 1, n / 2, n / 3, n / 2 - 1, Material::Water);
    rect(world, n / 3 + 1, n * 7 / 8, n - n / 3 - 2, n / 8 - 1, Material::Water);
    rect(world, n / 2, n * 3 / 4, 8, n / 4 - 1, Material::Wall);
    const auto initial = world.quantity_ledger();
    const auto initial_water = initial.water_visible + initial.water_overfill + initial.water_ballistic;
    std::vector<std::uint64_t> elapsed;
    std::vector<std::uint64_t> checkpoints;
    elapsed.reserve(static_cast<std::size_t>(ticks));
    std::uint32_t observed = 0;
    std::uint64_t total_ns = 0;
    for (int tick = 0; tick < ticks; ++tick) {
        world.clear_transient_obstacles();
        for (int actor = 0; actor < bodies; ++actor) {
            const int x = n / 8 + actor * n / 12 + (tick / 4) % 13;
            const int y = n / 5 + (actor % 2) * n / 10 + (tick / 7) % 11;
            for (int dy = 0; dy < 5; ++dy)
                for (int dx = 0; dx < 9; ++dx)
                    if (!world.set_transient_obstacle(x + dx, y + dy, static_cast<std::uint16_t>(actor + 1)))
                        throw std::runtime_error("actual body mask refused");
        }
        const auto start = std::chrono::steady_clock::now();
        const auto stats = world.tick();
        const auto duration = static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::steady_clock::now() - start).count());
        elapsed.push_back(duration); total_ns += duration;
        observed = std::max(observed, stats.worker_threads_observed);
        if (world.has_failed()) throw std::runtime_error("World failed");
        const auto ledger = world.quantity_ledger();
        if (ledger.water_visible + ledger.water_overfill + ledger.water_ballistic != initial_water ||
            ledger.water_ballistic != world.ballistic_water_snapshot().in_flight_quantity)
            throw std::runtime_error("Water/parcel conservation failed");
        if (tick % 12 == 11 || tick == ticks - 1) {
            checkpoints.push_back(world.physical_state_hash());
            checkpoints.push_back(world.state_hash());
            checkpoints.push_back(world.content_hash());
            for (int body = 1; body <= bodies; ++body) {
                checkpoints.push_back(world.transient_contact_count(static_cast<std::uint16_t>(body)));
                checkpoints.push_back(static_cast<std::uint64_t>(world.transient_contact_impulse_x(static_cast<std::uint16_t>(body))));
                checkpoints.push_back(static_cast<std::uint64_t>(world.transient_contact_impulse_y(static_cast<std::uint16_t>(body))));
            }
        }
    }
    std::sort(elapsed.begin(), elapsed.end());
    const auto at = [&](int percentage) {
        return static_cast<double>(elapsed[std::min(elapsed.size() - 1U,
            (elapsed.size() * static_cast<std::size_t>(percentage) + 99U) / 100U - 1U)]) / 1e6;
    };
    const auto diag = world.wave_flow_diagnostics();
    const auto mean = [ticks](std::uint64_t ns) { return static_cast<double>(ns) / ticks / 1e6; };
    std::cout << "{\"schema\":\"pubpres-mask-bounds-native-v1\",\"scope\":\"native-only\",\"size\":" << n
              << ",\"bodies\":" << bodies << ",\"workers\":" << workers << ",\"workers_observed\":" << observed
              << ",\"ticks\":" << ticks << ",\"profile\":" << profile << ",\"water_units\":" << initial_water
              << ",\"tick_mean_ms\":" << mean(total_ns) << ",\"tick_p50_ms\":" << at(50)
              << ",\"tick_p95_ms\":" << at(95) << ",\"tick_p99_ms\":" << at(99)
              << ",\"tick_max_ms\":" << static_cast<double>(elapsed.back()) / 1e6
              << ",\"column_mean_ms\":" << mean(diag.column_nanoseconds)
              << ",\"flux_mean_ms\":" << mean(diag.flux_nanoseconds)
              << ",\"apply_mean_ms\":" << mean(diag.apply_nanoseconds)
              << ",\"prepare_mean_ms\":" << mean(diag.prepare_nanoseconds)
              << ",\"wave_storage_bytes\":" << diag.storage_bytes
              << ",\"launched_parcels\":" << diag.launched_parcels << ",\"checkpoints\":[";
    for (std::size_t i = 0; i < checkpoints.size(); ++i) std::cout << (i == 0 ? "" : ",") << checkpoints[i];
    std::cout << "]}\n";
    return 0;
}
} // namespace

int main(int argc, char** argv) {
    try { return run(argc, argv); }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
