// WCX-SURGE: which Water family (or PressureFlow gas variant) gives energetic
// surging at reasonable cost? One dam-break fixture per arm: a 1024x192 basin,
// a 40-row reservoir on the left third released into a 12-row pool. Only
// World::tick is timed. "Energy" is the time-averaged absolute change of the
// surface-height profile per tick (how much the surface moves), plus the front
// arrival tick at the far wall and the late-time slosh amplitude.
// Usage: wcx_surge_assessment [ticks] [workers] > out.jsonl
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

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

struct Arm {
    const char* name;
    int family;        // 1 FreeMass, 2 CellularYield, 3 PressureFlow, 4 IN
    int variant;       // PressureFlow implementation variant
    int gas;           // PressureFlow gas topology (-1: default block absent)
};

LiquidSolverPolicy policy_for(const Arm& arm) {
    auto words = LiquidSolverPolicy::default_request();
    if (arm.family != 1) words[21] = arm.family;
    if (arm.family == 3) {
        words[22] = arm.variant;
        if (arm.gas >= 0) {
            const auto at = words.size() - 2U;
            words[at] = 1;
            words.insert(words.begin() + static_cast<std::ptrdiff_t>(at) + 1, {3, 1, 2, arm.gas, 32});
        }
    }
    if (arm.family == 4) {
        words[words.size() - 2U] = 1;
        words.insert(words.end() - 1, {4, 2, 1, 1});
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), std::string("policy refused for ") + arm.name + ": " + decoded.refusal.message());
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
        const int ticks = argc > 1 ? std::atoi(argv[1]) : 400;
        const auto workers = static_cast<std::uint32_t>(argc > 2 ? std::atoi(argv[2]) : 1);
        const Arm arms[] = {
            {"freemass", 1, 0, -1}, {"cellular_yield", 2, 0, -1}, {"inertial", 4, 0, -1},
            {"pressure_ref_gas", 3, 0, 1}, {"pressure_ref_nogas", 3, 0, 0},
            {"pressure_dormant_gas", 3, 2, 1}, {"pressure_dormant_nogas", 3, 2, 0},
        };
        constexpr std::int64_t W = 1024, H = 192, floor_y = 184;
        const char* only = std::getenv("WCX_SURGE_ARM");
        for (const auto& arm : arms) {
            if (only != nullptr && std::string(only) != arm.name) continue;
            WorldConfig config;
            config.liquid_solver_policy = policy_for(arm);
            config.maximum_rule_radius = arm.family == 4 ? 3 : 2;
            config.worker_threads = workers;
            config.parallel_job_threshold = 2;
            config.maximum_chunk_count = 256;
            config.active_chunk_capacity = 256;
            config.active_core_capacity = 1024;
            World world(config);
            world.reserve_region({0, 0, W, H});
            rect(world, 0, floor_y, W, H - floor_y, Material::Wall);
            rect(world, 0, 0, 8, floor_y, Material::Wall);
            rect(world, W - 8, 0, 8, floor_y, Material::Wall);
            rect(world, 8, floor_y - 12, W - 16, 12, Material::Water);        // 12-row pool
            rect(world, 8, floor_y - 52, 330, 40, Material::Water);           // reservoir on top
            const auto surface = [&](std::vector<std::int32_t>& out) {
                out.assign(static_cast<std::size_t>(W), 0);
                for (std::int64_t x = 8; x < W - 8; ++x) {
                    std::int64_t top = floor_y;
                    for (std::int64_t y = 0; y < floor_y; ++y)
                        if (world.stored_material(x, y) == Material::Water) { top = y; break; }
                    out[static_cast<std::size_t>(x)] = static_cast<std::int32_t>(floor_y - top);
                }
            };
            std::vector<std::int32_t> previous, current;
            surface(previous);
            std::vector<double> tick_ms;
            double motion = 0, late_motion = 0;
            int arrival = -1;
            std::int32_t late_max = 0, late_min = 1 << 30;
            for (int t = 0; t < ticks; ++t) {
                const auto start = std::chrono::steady_clock::now();
                (void)world.tick();
                tick_ms.push_back(std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count());
                surface(current);
                double change = 0;
                for (std::size_t x = 8; x < current.size() - 8; ++x) change += std::abs(current[x] - previous[x]);
                motion += change;
                if (t >= ticks / 2) {
                    late_motion += change;
                    late_max = std::max(late_max, current[static_cast<std::size_t>(W - 40)]);
                    late_min = std::min(late_min, current[static_cast<std::size_t>(W - 40)]);
                }
                if (arrival < 0 && current[static_cast<std::size_t>(W - 40)] > 14) arrival = t;
                previous.swap(current);
            }
            if (arm.family == 3) {
                const auto c = world.pressure_optimization_snapshot().counters;
                const double n = static_cast<double>(ticks) + 1e-9;
                std::fprintf(stderr, "PROFILE %s prep_ms=%.3f gas_ms=%.3f head_ms=%.3f water_calls=%.0f motion_calls=%.0f "
                             "cert_attempts=%.0f cert_reuses=%.0f cert_saved=%.0f cert_declines=%.0f columns=%.0f rows=%.0f "
                             "fallbacks=%llu final_cells=%.0f base_cells=%.0f\n",
                             arm.name, c.preparation_nanoseconds / n / 1e6, c.gas_nanoseconds / n / 1e6,
                             c.head_nanoseconds / n / 1e6, c.water_material_calls / n, c.water_motion_calls / n,
                             c.certificate_attempts / n, c.certificate_reuses / n, c.certificate_saved_calls / n,
                             c.certificate_declines / n, c.columns_recomputed / n, c.rows_recomputed / n,
                             static_cast<unsigned long long>(c.reference_fallbacks), c.final_cells_written / n,
                             c.base_cells_written / n);
            }
            std::printf("{\"arm\":\"%s\",\"workers\":%u,\"ticks\":%d,\"tick_p50_ms\":%.4f,\"tick_p95_ms\":%.4f,"
                        "\"tick_mean_ms\":%.4f,\"surface_motion_per_tick\":%.2f,\"late_motion_per_tick\":%.2f,"
                        "\"far_wall_arrival_tick\":%d,\"late_far_wall_slosh_rows\":%d}\n",
                        arm.name, workers, ticks, percentile(tick_ms, 0.5), percentile(tick_ms, 0.95),
                        [&] { double s = 0; for (auto v : tick_ms) s += v; return s / static_cast<double>(tick_ms.size()); }(),
                        motion / ticks, late_motion / (ticks - ticks / 2), arrival, late_max - late_min);
            std::fflush(stdout);
        }
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "wcx_surge_assessment: %s\n", error.what());
        return 1;
    }
}
