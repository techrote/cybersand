// LCB-002 #201 moving-camera PressureFlow cost and exactness discrimination.
//
// A prepared-host-sized World (1024x1024, chunk 128, the native host's
// capacities) holds a quiet vented pool, a sealed gas room and an optional
// active waterfall. After settling with a fixed interest, the simulation
// region is moved like a desktop camera window (480x270, ping-pong) at a fixed
// cell speed. Only World::tick is timed. Every tick the cached/cached_dormant
// arms are compared with reference by the pressure-variant equivalence hash;
// any difference is a hard failure. Cache cold transitions are observed
// through the public optimization counters.
//
// Usage: lcb201_moving_camera [ticks] [workers] [profile: quiet|flow] > out.jsonl
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

LiquidSolverPolicy policy_for(int arm) {
    auto words = LiquidSolverPolicy::default_request();
    const auto count = static_cast<std::size_t>(words[LiquidSolverPolicy::kHeaderWords]);
    for (std::size_t i = 0; i < count; ++i) {
        const auto at = LiquidSolverPolicy::kHeaderWords + 1U + 3U * i;
        if (words[at] != static_cast<std::int32_t>(Material::Water)) continue;
        words[at + 1U] = static_cast<std::int32_t>(LiquidSolverFamily::PressureFlowV1);
        words[at + 2U] = arm;
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "PressureFlow policy refused");
    return *decoded.policy;
}

WorldConfig host_config(int arm, std::uint32_t workers) {
    WorldConfig config;
    config.worker_threads = workers;
    config.initial_chunk_reserve = 64;
    config.maximum_chunk_count = 128;
    config.active_core_capacity = 1024;
    config.active_chunk_capacity = 128;
    config.parallel_job_threshold = 2;
    config.water_experiment_policy = WaterExperimentPolicy(8, 12);
    config.liquid_solver_policy = policy_for(arm);
    config.maximum_rule_radius = 2;
    return config;
}

void rect(World& w, std::int64_t x, std::int64_t y, std::int64_t width, std::int64_t height, Material m) {
    for (auto yy = y; yy < y + height; ++yy)
        for (auto xx = x; xx < x + width; ++xx) w.set(xx, yy, m);
}

void build(World& w, bool flow) {
    w.reserve_region({0, 0, 1024, 1024});
    rect(w, 16, 700, 992, 16, Material::Wall);          // floor
    rect(w, 16, 400, 16, 300, Material::Wall);          // left wall
    rect(w, 992, 400, 16, 300, Material::Wall);         // right wall
    rect(w, 32, 560, 960, 140, Material::Water);        // vented quiet pool
    // Sealed gas room with a lidded Water column (gas topology + heads).
    rect(w, 600, 200, 200, 8, Material::Wall);
    rect(w, 600, 200, 8, 160, Material::Wall);
    rect(w, 792, 200, 8, 160, Material::Wall);
    rect(w, 600, 352, 200, 8, Material::Wall);
    rect(w, 608, 300, 184, 52, Material::Water);
    if (flow) {
        // A reservoir spilling over a lip keeps real Water motion alive.
        rect(w, 100, 300, 160, 8, Material::Wall);
        rect(w, 100, 220, 8, 80, Material::Wall);
        rect(w, 252, 260, 8, 40, Material::Wall);
        rect(w, 108, 230, 144, 70, Material::Water);
    }
}

struct Arm {
    std::unique_ptr<World> world;
    std::vector<double> ms;
};

double percentile(std::vector<double> v, double q) {
    if (v.empty()) return 0;
    std::sort(v.begin(), v.end());
    return v[std::min(v.size() - 1, static_cast<std::size_t>(q * static_cast<double>(v.size())))];
}

} // namespace

int main(int argc, char** argv) {
    try {
        const int ticks = argc > 1 ? std::atoi(argv[1]) : 240;
        const auto workers = static_cast<std::uint32_t>(argc > 2 ? std::atoi(argv[2]) : 1);
        const std::string profile = argc > 3 ? argv[3] : "quiet";
        const bool flow = profile == "flow";
        for (const int speed : {0, 1, 4, 16, 64}) {
            std::array<Arm, 3> arms;
            for (int arm = 0; arm < 3; ++arm) {
                arms[static_cast<std::size_t>(arm)].world = std::make_unique<World>(host_config(arm, workers));
                build(*arms[static_cast<std::size_t>(arm)].world, flow);
                arms[static_cast<std::size_t>(arm)].world->set_simulation_region(RectI64{32, 400, 480, 270});
            }
            // Settle with a fixed interest: the cached arm warms up.
            for (int t = 0; t < 120; ++t)
                for (auto& a : arms) (void)a.world->tick();
            std::array<PressureOptimizationCounters, 3> before{};
            for (int arm = 0; arm < 3; ++arm)
                before[static_cast<std::size_t>(arm)] =
                    arms[static_cast<std::size_t>(arm)].world->pressure_optimization_snapshot().counters;
            std::int64_t x = 32;
            int direction = 1;
            std::uint64_t region_changes = 0;
            for (int t = 0; t < ticks; ++t) {
                x += direction * speed;
                if (x > 512) { x = 512; direction = -1; }
                if (x < 32) { x = 32; direction = 1; }
                for (auto& a : arms) {
                    const auto selected = a.world->selected_simulation_cores();
                    a.world->set_simulation_region(RectI64{x, 400, 480, 270});
                    if (&a == &arms[0] && selected != a.world->selected_simulation_cores()) ++region_changes;
                    const auto start = std::chrono::steady_clock::now();
                    (void)a.world->tick();
                    a.ms.push_back(std::chrono::duration<double, std::milli>(
                        std::chrono::steady_clock::now() - start).count());
                }
                const auto reference =
                    arms[0].world->liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1);
                for (int arm = 1; arm < 3; ++arm)
                    require(arms[static_cast<std::size_t>(arm)].world->liquid_comparison_hash(
                                LiquidStateProjection::PressureVariantEquivalenceV1) == reference,
                            "variant diverged from reference at speed " + std::to_string(speed) +
                                " tick " + std::to_string(t));
            }
            for (int arm = 0; arm < 3; ++arm) {
                const auto& a = arms[static_cast<std::size_t>(arm)];
                const auto after = a.world->pressure_optimization_snapshot().counters;
                const auto& b = before[static_cast<std::size_t>(arm)];
                std::printf("{\"profile\":\"%s\",\"workers\":%u,\"speed\":%d,\"arm\":%d,\"ticks\":%d,"
                            "\"region_core_changes\":%llu,\"p50_ms\":%.4f,\"p95_ms\":%.4f,\"p99_ms\":%.4f,"
                            "\"max_ms\":%.4f,\"reference_fallbacks\":%llu,\"gas_reference_passes\":%llu,"
                            "\"index_rebuilds\":%llu,\"columns_recomputed\":%llu,\"certificate_cold_resets\":%llu,"
                            "\"fallback_resident_cells\":%llu}\n",
                            profile.c_str(), workers, speed, arm, ticks,
                            static_cast<unsigned long long>(region_changes), percentile(a.ms, 0.5),
                            percentile(a.ms, 0.95), percentile(a.ms, 0.99), percentile(a.ms, 1.0),
                            static_cast<unsigned long long>(after.reference_fallbacks - b.reference_fallbacks),
                            static_cast<unsigned long long>(after.gas_reference_passes - b.gas_reference_passes),
                            static_cast<unsigned long long>(after.index_rebuilds - b.index_rebuilds),
                            static_cast<unsigned long long>(after.columns_recomputed - b.columns_recomputed),
                            static_cast<unsigned long long>(after.certificate_cold_resets - b.certificate_cold_resets),
                            static_cast<unsigned long long>(after.fallback_resident_cells - b.fallback_resident_cells));
                std::fflush(stdout);
            }
        }
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "lcb201_moving_camera: %s\n", error.what());
        return 1;
    }
}
