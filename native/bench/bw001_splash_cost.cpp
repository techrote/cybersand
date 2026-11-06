// BW-001 ballistic Water cost attribution (native only; advisory timings).
//
// A 512x256 basin (chunk 128) with a 60-row pool runs per family:
//   control  - ballistic enabled, nothing launched (pure bulk cost)
//   burst    - a 600-parcel crown splash launched from the surface at t=0
//   jet      - 3 injected 128-unit parcels per tick for the whole run
// Only World::tick is timed; the parcel pass is timed separately by the World.
// Usage: bw001_splash_cost [ticks] [workers] > out.jsonl
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
constexpr std::int64_t Q = BallisticWaterConfig::kQ;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

LiquidSolverPolicy water_policy(int family) {
    auto words = LiquidSolverPolicy::default_request();
    if (family != 1) words[21] = family;
    if (family == 4) {
        words[words.size() - 2U] = 1;
        words.insert(words.end() - 1, {4, 2, 1, 1});
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "policy refused");
    return *decoded.policy;
}

void rect(World& w, std::int64_t x, std::int64_t y, std::int64_t width, std::int64_t height, Material m) {
    for (auto yy = y; yy < y + height; ++yy)
        for (auto xx = x; xx < x + width; ++xx) w.set(xx, yy, m);
}

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
        for (const int family : {1, 2, 3, 4}) {
            for (const std::string mode : {"control", "burst", "jet"}) {
                WorldConfig config;
                config.liquid_solver_policy = water_policy(family);
                config.maximum_rule_radius = family == 4 ? 3 : 2;
                config.worker_threads = workers;
                config.parallel_job_threshold = 2;
                config.ballistic_water.enabled = true;
                World world(config);
                world.reserve_region({0, 0, 512, 256});
                rect(world, 0, 248, 512, 8, Material::Wall);
                rect(world, 0, 0, 8, 248, Material::Wall);
                rect(world, 504, 0, 8, 248, Material::Wall);
                rect(world, 8, 188, 496, 60, Material::Water);
                for (int t = 0; t < 60; ++t) (void)world.tick();  // settle
                if (mode == "burst") {
                    std::uint32_t launched = 0;
                    for (std::int64_t i = 0; i < 600; ++i) {
                        const auto x = 200 + (i % 112);
                        const auto side = x < 256 ? -1 : 1;
                        std::int64_t y = 150;
                        while (y < 248 && world.stored_material(x, y) != Material::Water) ++y;
                        if (y >= 248 || world.stored_material(x, y - 1) != Material::Empty) continue;
                        const auto vx = static_cast<std::int32_t>(side * (160 + (i * 37) % 300));
                        const auto vy = static_cast<std::int32_t>(-(500 + (i * 53) % 400));
                        if (world.launch_ballistic_water(x, y, x * Q + 128, (y - 1) * Q + 128, vx, vy).outcome ==
                            BallisticLaunchOutcome::Launched) ++launched;
                    }
                    require(launched > 100, "burst launches refused");
                }
                std::vector<double> tick_ms, pass_ms;
                std::uint64_t peak_live = 0;
                for (int t = 0; t < ticks; ++t) {
                    if (mode == "jet")
                        for (int j = 0; j < 3; ++j) {
                            const double angle = (-62.0 + ((t * 7 + j * 13) % 11 - 5)) * 3.14159265358979 / 180.0;
                            const auto maximum = world.config().water_experiment_policy.maximum();
                            const auto q = world.whole_cell_water_enabled() ? maximum : std::uint16_t{128};
                            (void)world.inject_ballistic_water(100 * Q + 128, 186 * Q + 128,
                                static_cast<std::int32_t>(std::cos(angle) * 3.4 * Q),
                                static_cast<std::int32_t>(std::sin(angle) * 3.4 * Q), q);
                        }
                    const auto start = std::chrono::steady_clock::now();
                    const auto stats = world.tick();
                    tick_ms.push_back(std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count());
                    if (std::getenv("BW001_TIMELINE") && t % 20 == 0)
                        std::fprintf(stderr, "family %d %s t=%d tick_ms=%.3f visited=%llu moved=%llu active_blocks=%llu live=%u\n",
                                     family, mode.c_str(), t, tick_ms.back(),
                                     static_cast<unsigned long long>(stats.visited_cells),
                                     static_cast<unsigned long long>(stats.moved_cells),
                                     static_cast<unsigned long long>(stats.active_blocks_after),
                                     world.ballistic_water_snapshot().live);
                    const auto s = world.ballistic_water_snapshot();
                    pass_ms.push_back(static_cast<double>(s.last_advance_nanoseconds) / 1e6);
                    peak_live = std::max<std::uint64_t>(peak_live, s.live);
                }
                const auto s = world.ballistic_water_snapshot();
                const double parcel_ticks = static_cast<double>(s.ledger.parcel_ticks);
                double pass_total = 0;
                for (const auto v : pass_ms) pass_total += v;
                std::printf("{\"family\":%d,\"mode\":\"%s\",\"workers\":%u,\"ticks\":%d,\"tick_p50_ms\":%.4f,"
                            "\"tick_p95_ms\":%.4f,\"pass_p50_ms\":%.4f,\"pass_p95_ms\":%.4f,\"peak_live\":%llu,"
                            "\"parcel_ticks\":%.0f,\"ns_per_parcel_tick\":%.1f,\"cell_steps\":%llu,"
                            "\"deposit_writes\":%llu,\"column_deposits\":%llu}\n",
                            family, mode.c_str(), workers, ticks, percentile(tick_ms, 0.5), percentile(tick_ms, 0.95),
                            percentile(pass_ms, 0.5), percentile(pass_ms, 0.95),
                            static_cast<unsigned long long>(peak_live), parcel_ticks,
                            parcel_ticks > 0 ? pass_total * 1e6 / parcel_ticks : 0.0,
                            static_cast<unsigned long long>(s.ledger.cell_steps),
                            static_cast<unsigned long long>(s.ledger.deposit_writes),
                            static_cast<unsigned long long>(s.ledger.column_deposits));
                std::fflush(stdout);
            }
        }
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "bw001_splash_cost: %s\n", error.what());
        return 1;
    }
}
