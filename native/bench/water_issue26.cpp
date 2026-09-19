#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <numeric>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using cybersand::Material;
using cybersand::PhysicsEvent;
using cybersand::PhysicsTotals;
using cybersand::World;
using cybersand::WorldConfig;
using cybersand::WaterLevelingExperiment;

constexpr int kWidth = 96;
constexpr int kFloorY = 62;
constexpr int kSurfaceScale = 1000;
constexpr int kHillWindowRadius = 2;
constexpr int kHillThresholdMilli = 500;
constexpr int kTerraceThresholdMilli = 750;
constexpr int kSamplePeriod = 60;

struct Spec {
    std::string name;
    int horizon = 1800;
    int surface_x0 = 1;
    int surface_x1 = kWidth - 1;
    int left_x0 = -1;
    int left_x1 = -1;
    int right_x0 = -1;
    int right_x1 = -1;
    int receive_x0 = -1;
    bool release_gate = false;
    bool wall_gap_probe = false;
    bool primary_level_difference = false;
    bool primary_surface_spread = false;
};

struct SurfaceStats {
    std::int64_t slope_milli = 0;
    std::int64_t spread_milli = 0;
    std::int64_t mean_milli = -1;
    std::int64_t hill_amplitude_milli = 0;
    int hill_width = 0;
    int terrace_count = 0;
    std::int64_t max_terrace_step_milli = 0;
    std::uint64_t classification_signature = 1469598103934665603ULL;
};

struct Sample {
    int tick = 0;
    std::uint64_t mass = 0;
    std::uint64_t receive_mass = 0;
    std::int64_t com_x_milli = 0;
    int range_x = 0;
    SurfaceStats surface{};
    std::int64_t level_difference_milli = -1;
    int wall_gap_cells = 0;
    std::uint64_t content_hash = 0;
};

std::string hex64(std::uint64_t value) {
    std::ostringstream out;
    out << std::hex << value;
    return out.str();
}

std::uint64_t sum_event(const PhysicsTotals* totals, PhysicsEvent event) {
    if (totals == nullptr) return 0;
    std::uint64_t count = 0;
    const auto wanted = static_cast<std::uint32_t>(event);
    for (const auto& entry : totals->entries) {
        if (entry.key != 0U && ((entry.key >> 24U) & 0xffU) == wanted) count += entry.count;
    }
    return count;
}

double percentile(std::vector<double> values, double fraction) {
    if (values.empty()) return 0.0;
    std::sort(values.begin(), values.end());
    const auto index = static_cast<std::size_t>(
        std::min<double>(static_cast<double>(values.size() - 1),
                         std::floor(fraction * static_cast<double>(values.size() - 1))));
    return values[index];
}

Spec make_spec(const std::string& name) {
    Spec spec;
    spec.name = name;
    if (name == "head-shallow" || name == "head-medium" || name == "head-deep") {
        spec.surface_x0 = 1;
        spec.surface_x1 = 33;
        spec.receive_x0 = 35;
    } else if (name == "communicating-pools") {
        spec.horizon = 4800;
        spec.surface_x0 = 1;
        spec.surface_x1 = 95;
        spec.left_x0 = 3;
        spec.left_x1 = 44;
        spec.right_x0 = 52;
        spec.right_x1 = 93;
        spec.receive_x0 = 49;
        spec.primary_level_difference = true;
    } else if (name == "unequal-head-u-tube") {
        spec.horizon = 4800;
        spec.surface_x0 = 9;
        spec.surface_x1 = 87;
        spec.left_x0 = 10;
        spec.left_x1 = 27;
        spec.right_x0 = 69;
        spec.right_x1 = 86;
        spec.receive_x0 = 69;
        spec.primary_level_difference = true;
    } else if (name == "constriction") {
        spec.surface_x0 = 1;
        spec.surface_x1 = 39;
        spec.receive_x0 = 41;
    } else if (name == "fast-dump") {
        spec.surface_x0 = 1;
        spec.surface_x1 = 95;
        spec.receive_x0 = 35;
        spec.release_gate = true;
        spec.wall_gap_probe = true;
    } else if (name == "calm-settling") {
        spec.horizon = 3600;
        spec.surface_x0 = 1;
        spec.surface_x1 = 95;
        spec.primary_surface_spread = true;
    } else if (name == "ledge-sheet") {
        spec.surface_x0 = 1;
        spec.surface_x1 = 95;
        spec.receive_x0 = 57;
    } else {
        throw std::invalid_argument("unknown issue #26 fixture");
    }
    return spec;
}

void build_fixture(World& world, const Spec& spec, int shift, bool mirror) {
    const auto wx = [shift, mirror](int canonical_x) {
        return shift + (mirror ? kWidth - canonical_x : canonical_x);
    };
    const auto wy = [shift](int canonical_y) { return shift + canonical_y; };
    const auto put = [&](int x, int y, Material material) {
        world.set(wx(x), wy(y), material);
    };
    const auto box = [&]() {
        for (int x = 0; x <= kWidth; ++x) put(x, kFloorY, Material::Wall);
        for (int y = 0; y <= kFloorY; ++y) {
            put(0, y, Material::Wall);
            put(kWidth, y, Material::Wall);
        }
    };
    const auto fill = [&](int x0, int x1, int depth) {
        for (int x = x0; x <= x1; ++x)
            for (int y = kFloorY - depth; y < kFloorY; ++y) put(x, y, Material::Water);
    };

    if (spec.name.rfind("head-", 0) == 0) {
        box();
        for (int y = 0; y <= 56; ++y) put(34, y, Material::Wall);
        int depth = 8;
        if (spec.name == "head-medium") depth = 20;
        if (spec.name == "head-deep") depth = 36;
        fill(1, 33, depth);
        return;
    }
    if (spec.name == "communicating-pools") {
        box();
        for (int y = 0; y <= 55; ++y) put(48, y, Material::Wall);
        fill(1, 47, 28);
        fill(49, 95, 12);
        return;
    }
    if (spec.name == "unequal-head-u-tube") {
        for (int y = 0; y <= kFloorY; ++y) {
            put(8, y, Material::Wall);
            put(88, y, Material::Wall);
        }
        for (int x = 8; x <= 88; ++x) put(x, kFloorY, Material::Wall);
        for (int y = 0; y <= 54; ++y) {
            put(28, y, Material::Wall);
            put(68, y, Material::Wall);
        }
        fill(9, 27, 40);
        fill(69, 87, 16);
        for (int x = 29; x <= 67; ++x)
            for (int y = 55; y < kFloorY; ++y) put(x, y, Material::Water);
        return;
    }
    if (spec.name == "constriction") {
        box();
        for (int y = 0; y <= 58; ++y) put(40, y, Material::Wall);
        fill(1, 39, 40);
        return;
    }
    if (spec.name == "fast-dump") {
        box();
        for (int y = 0; y < kFloorY; ++y) put(34, y, Material::Wall);
        fill(1, 33, 40);
        return;
    }
    if (spec.name == "calm-settling") {
        box();
        fill(1, 24, 32);
        fill(25, 48, 22);
        fill(49, 72, 12);
        fill(73, 95, 4);
        return;
    }
    if (spec.name == "ledge-sheet") {
        box();
        for (int x = 1; x <= 56; ++x) put(x, 34, Material::Wall);
        for (int x = 3; x <= 52; ++x)
            for (int y = 30; y <= 33; ++y) put(x, y, Material::Water);
        return;
    }
}

template <typename MassAt>
SurfaceStats surface_stats(MassAt&& mass_at, int x0, int x1, std::uint16_t maximum) {
    const int count = x1 - x0 + 1;
    std::vector<std::int64_t> surface(static_cast<std::size_t>(count), -1);
    for (int x = x0; x <= x1; ++x) {
        for (int y = 0; y < kFloorY; ++y) {
            const auto mass = mass_at(x, y);
            if (mass == 0U) continue;
            const auto fractional = static_cast<std::int64_t>(
                (static_cast<std::uint64_t>(maximum - mass) * kSurfaceScale) / maximum);
            surface[static_cast<std::size_t>(x - x0)] =
                static_cast<std::int64_t>(y) * kSurfaceScale + fractional;
            break;
        }
    }

    SurfaceStats out;
    std::vector<std::pair<std::int64_t, std::int64_t>> points;
    for (int i = 0; i < count; ++i) {
        if (surface[static_cast<std::size_t>(i)] >= 0)
            points.emplace_back(x0 + i, surface[static_cast<std::size_t>(i)]);
    }
    if (points.empty()) return out;

    auto [min_it, max_it] = std::minmax_element(
        points.begin(), points.end(),
        [](const auto& a, const auto& b) { return a.second < b.second; });
    out.spread_milli = max_it->second - min_it->second;
    out.mean_milli = std::accumulate(
        points.begin(), points.end(), std::int64_t{0},
        [](std::int64_t total, const auto& point) { return total + point.second; }) /
        static_cast<std::int64_t>(points.size());

    const double mean_x = std::accumulate(
        points.begin(), points.end(), 0.0,
        [](double total, const auto& point) { return total + static_cast<double>(point.first); }) /
        static_cast<double>(points.size());
    const double mean_y = static_cast<double>(out.mean_milli);
    double numerator = 0.0;
    double denominator = 0.0;
    for (const auto& [x, y] : points) {
        numerator += (static_cast<double>(x) - mean_x) * (static_cast<double>(y) - mean_y);
        denominator += (static_cast<double>(x) - mean_x) * (static_cast<double>(x) - mean_x);
    }
    if (denominator > 0.0) out.slope_milli = static_cast<std::int64_t>(std::llround(numerator / denominator));

    int current_hill_width = 0;
    for (int i = 0; i < count; ++i) {
        const auto value = surface[static_cast<std::size_t>(i)];
        if (value < 0) {
            current_hill_width = 0;
            continue;
        }
        std::int64_t local_sum = 0;
        int local_count = 0;
        for (int j = std::max(0, i - kHillWindowRadius);
             j <= std::min(count - 1, i + kHillWindowRadius); ++j) {
            const auto neighbour = surface[static_cast<std::size_t>(j)];
            if (neighbour < 0) continue;
            local_sum += neighbour;
            ++local_count;
        }
        const auto local_mean = local_count ? local_sum / local_count : value;
        const auto amplitude = std::max<std::int64_t>(0, local_mean - value);
        out.hill_amplitude_milli = std::max(out.hill_amplitude_milli, amplitude);
        const bool hill = amplitude >= kHillThresholdMilli;
        if (hill) {
            ++current_hill_width;
            out.hill_width = std::max(out.hill_width, current_hill_width);
        } else {
            current_hill_width = 0;
        }
        out.classification_signature ^=
            static_cast<std::uint64_t>((hill ? 0x9e37U : 0x85ebU) + i * 131U);
        out.classification_signature *= 1099511628211ULL;
    }

    for (int i = 1; i < count; ++i) {
        const auto a = surface[static_cast<std::size_t>(i - 1)];
        const auto b = surface[static_cast<std::size_t>(i)];
        if (a < 0 || b < 0) continue;
        const auto step = static_cast<std::int64_t>(std::llabs(a - b));
        if (step >= kTerraceThresholdMilli) {
            ++out.terrace_count;
            out.max_terrace_step_milli = std::max(out.max_terrace_step_milli, step);
            out.classification_signature ^= static_cast<std::uint64_t>(0xc2b2U + i * 257U);
            out.classification_signature *= 1099511628211ULL;
        }
    }
    return out;
}

template <typename MassAt>
std::int64_t mean_surface(MassAt&& mass_at, int x0, int x1, std::uint16_t maximum) {
    const auto stats = surface_stats(mass_at, x0, x1, maximum);
    return stats.mean_milli;
}

int run_case(const Spec& spec, int shift, int workers, bool mirror,
             WaterLevelingExperiment experiment) {
    WorldConfig config;
    config.worker_threads = static_cast<std::uint32_t>(workers);
    config.parallel_job_threshold = 1;
    config.maximum_chunk_count = 64;
    config.active_chunk_capacity = 64;
    config.active_core_capacity = 512;
    config.physics_diagnostics.enabled = true;
    config.physics_diagnostics.water_leveling_experiment = experiment;
    World world(config);
    world.reserve_region({shift - 128, shift - 128, 512, 512});
    build_fixture(world, spec, shift, mirror);

    const auto wx = [shift, mirror](int canonical_x) {
        return shift + (mirror ? kWidth - canonical_x : canonical_x);
    };
    const auto wy = [shift](int canonical_y) { return shift + canonical_y; };
    const auto mass_at = [&](int x, int y) -> std::uint16_t {
        return world.liquid_mass(wx(x), wy(y));
    };
    const auto maximum = config.water_experiment_policy.maximum();

    const auto take_sample = [&](int tick) {
        Sample sample;
        sample.tick = tick;
        std::uint64_t weighted_x = 0;
        int min_x = kWidth + 1;
        int max_x = -1;
        for (int x = 1; x < kWidth; ++x) {
            for (int y = 0; y < kFloorY; ++y) {
                const auto mass = mass_at(x, y);
                if (mass == 0U) continue;
                sample.mass += mass;
                weighted_x += static_cast<std::uint64_t>(x) * mass;
                min_x = std::min(min_x, x);
                max_x = std::max(max_x, x);
                if (spec.receive_x0 >= 0 && x >= spec.receive_x0) sample.receive_mass += mass;
            }
        }
        sample.com_x_milli = sample.mass == 0U ? 0 :
            static_cast<std::int64_t>((weighted_x * kSurfaceScale) / sample.mass);
        sample.range_x = max_x >= min_x ? max_x - min_x : 0;
        sample.surface = surface_stats(mass_at, spec.surface_x0, spec.surface_x1, maximum);
        if (spec.left_x0 >= 0 && spec.right_x0 >= 0) {
            const auto left = mean_surface(mass_at, spec.left_x0, spec.left_x1, maximum);
            const auto right = mean_surface(mass_at, spec.right_x0, spec.right_x1, maximum);
            if (left >= 0 && right >= 0) sample.level_difference_milli = std::llabs(left - right);
        }
        if (spec.wall_gap_probe) {
            for (int y = 38; y < kFloorY; ++y) {
                if (mass_at(kWidth - 1, y) != 0U) continue;
                bool nearby = false;
                for (int x = kWidth - 8; x < kWidth - 1; ++x)
                    nearby = nearby || mass_at(x, y) != 0U;
                if (nearby) ++sample.wall_gap_cells;
            }
        }
        sample.content_hash = world.content_hash();
        return sample;
    };

    std::vector<Sample> samples;
    samples.push_back(take_sample(0));
    const auto initial_mass = samples.front().mass;
    std::vector<double> tick_times;
    tick_times.reserve(static_cast<std::size_t>(spec.horizon));
    std::uint64_t visited = 0;
    std::uint64_t blocks = 0;
    std::uint64_t allocations = 0;
    std::uint64_t moved = 0;

    for (int tick = 1; tick <= spec.horizon; ++tick) {
        if (spec.release_gate && tick == 1) {
            for (int y = 20; y < kFloorY; ++y) world.set(wx(34), wy(y), Material::Empty);
        }
        const auto start = std::chrono::steady_clock::now();
        const auto stats = world.tick();
        tick_times.push_back(std::chrono::duration<double, std::micro>(
            std::chrono::steady_clock::now() - start).count());
        visited += stats.visited_cells;
        blocks += stats.active_blocks_after;
        allocations += stats.chunk_allocations + stats.temperature_field_allocations;
        moved += stats.moved_cells;
        if (tick % kSamplePeriod == 0 || tick == spec.horizon) samples.push_back(take_sample(tick));
    }

    bool conserved = true;
    for (const auto& sample : samples) conserved = conserved && sample.mass == initial_mass;

    const auto primary = [&](const Sample& sample) -> std::int64_t {
        if (spec.primary_level_difference) return sample.level_difference_milli;
        if (spec.primary_surface_spread) return sample.surface.spread_milli;
        return -1;
    };
    const auto initial_primary = primary(samples.front());
    int first_half_life = 0;
    int sustained_half_life = 0;
    int half_streak = 0;
    int first_one_cell = 0;
    int flat_streak = 0;
    int sustained_one_cell = 0;
    if (initial_primary > 0) {
        for (const auto& sample : samples) {
            const auto value = primary(sample);
            if (value >= 0 && value * 2 <= initial_primary) {
                if (first_half_life == 0 && sample.tick != 0) first_half_life = sample.tick;
                ++half_streak;
                if (half_streak >= 5 && sustained_half_life == 0)
                    sustained_half_life = sample.tick - (5 - 1) * kSamplePeriod;
            } else {
                half_streak = 0;
            }
            if (value >= 0 && value <= kSurfaceScale) {
                if (first_one_cell == 0 && sample.tick != 0) first_one_cell = sample.tick;
                ++flat_streak;
                if (flat_streak >= 5 && sustained_one_cell == 0)
                    sustained_one_cell = sample.tick - (5 - 1) * kSamplePeriod;
            } else {
                flat_streak = 0;
            }
        }
    }

    std::int64_t max_hill = 0;
    int max_hill_width = 0;
    int max_terraces = 0;
    std::int64_t max_terrace_step = 0;
    int max_wall_gap = 0;
    int surface_turnover = 0;
    std::uint64_t previous_signature = samples.front().surface.classification_signature;
    for (std::size_t i = 0; i < samples.size(); ++i) {
        const auto& sample = samples[i];
        max_hill = std::max(max_hill, sample.surface.hill_amplitude_milli);
        max_hill_width = std::max(max_hill_width, sample.surface.hill_width);
        max_terraces = std::max(max_terraces, sample.surface.terrace_count);
        max_terrace_step = std::max(max_terrace_step, sample.surface.max_terrace_step_milli);
        max_wall_gap = std::max(max_wall_gap, sample.wall_gap_cells);
        if (i != 0 && sample.surface.classification_signature != previous_signature) ++surface_turnover;
        previous_signature = sample.surface.classification_signature;
    }

    auto receive_at = [&](int tick) -> std::uint64_t {
        for (const auto& sample : samples) if (sample.tick == tick) return sample.receive_mass;
        return 0;
    };

    const auto total_us = std::accumulate(tick_times.begin(), tick_times.end(), 0.0);
    const auto* diagnostics = world.physics_diagnostics();

    std::cout << "{";
    std::cout << "\"scenario\":\"" << spec.name << "\",";
    std::cout << "\"mode\":\"" << (experiment == WaterLevelingExperiment::HeadScaledLocal ? "head" : "baseline") << "\",";
    std::cout << "\"shift\":" << shift << ",";
    std::cout << "\"mirror\":" << (mirror ? 1 : 0) << ",";
    std::cout << "\"workers\":" << workers << ",";
    std::cout << "\"horizon\":" << spec.horizon << ",";
    std::cout << "\"maximum_mass\":" << maximum << ",";
    std::cout << "\"initial_mass\":" << initial_mass << ",";
    std::cout << "\"final_mass\":" << samples.back().mass << ",";
    std::cout << "\"mass_conserved\":" << (conserved ? "true" : "false") << ",";
    std::cout << "\"first_half_life_tick\":" << first_half_life << ",";
    std::cout << "\"sustained_half_life_tick\":" << sustained_half_life << ",";
    std::cout << "\"first_one_cell_tick\":" << first_one_cell << ",";
    std::cout << "\"sustained_one_cell_tick\":" << sustained_one_cell << ",";
    std::cout << "\"receive_mass_tick120\":" << receive_at(120) << ",";
    std::cout << "\"receive_mass_tick300\":" << receive_at(300) << ",";
    std::cout << "\"max_hill_milli\":" << max_hill << ",";
    std::cout << "\"max_hill_width\":" << max_hill_width << ",";
    std::cout << "\"max_terraces\":" << max_terraces << ",";
    std::cout << "\"max_terrace_step_milli\":" << max_terrace_step << ",";
    std::cout << "\"max_wall_gap_cells\":" << max_wall_gap << ",";
    std::cout << "\"surface_turnover_samples\":" << surface_turnover << ",";
    std::cout << "\"visited\":" << visited << ",";
    std::cout << "\"active_block_sum\":" << blocks << ",";
    std::cout << "\"moved\":" << moved << ",";
    std::cout << "\"allocations\":" << allocations << ",";
    std::cout << "\"water_transfers\":" << sum_event(diagnostics, PhysicsEvent::WaterTransfer) << ",";
    std::cout << "\"lateral_probes\":" << sum_event(diagnostics, PhysicsEvent::LateralProbe) << ",";
    std::cout << "\"lateral_requests\":" << sum_event(diagnostics, PhysicsEvent::LateralRequest) << ",";
    std::cout << "\"block_wakes\":" << sum_event(diagnostics, PhysicsEvent::BlockWake) << ",";
    std::cout << "\"block_sleeps\":" << sum_event(diagnostics, PhysicsEvent::BlockSleep) << ",";
    std::cout << "\"total_us\":" << std::fixed << std::setprecision(3) << total_us << ",";
    std::cout << "\"p50_us\":" << percentile(tick_times, 0.50) << ",";
    std::cout << "\"p95_us\":" << percentile(tick_times, 0.95) << ",";
    std::cout << "\"p99_us\":" << percentile(tick_times, 0.99) << ",";
    std::cout << "\"max_us\":" << (tick_times.empty() ? 0.0 : *std::max_element(tick_times.begin(), tick_times.end())) << ",";
    std::cout << "\"samples\":[";
    for (std::size_t i = 0; i < samples.size(); ++i) {
        if (i) std::cout << ",";
        const auto& sample = samples[i];
        std::cout << "{";
        std::cout << "\"tick\":" << sample.tick << ",";
        std::cout << "\"mass\":" << sample.mass << ",";
        std::cout << "\"receive_mass\":" << sample.receive_mass << ",";
        std::cout << "\"com_x_milli\":" << sample.com_x_milli << ",";
        std::cout << "\"range_x\":" << sample.range_x << ",";
        std::cout << "\"slope_milli\":" << sample.surface.slope_milli << ",";
        std::cout << "\"surface_spread_milli\":" << sample.surface.spread_milli << ",";
        std::cout << "\"surface_mean_milli\":" << sample.surface.mean_milli << ",";
        std::cout << "\"level_difference_milli\":" << sample.level_difference_milli << ",";
        std::cout << "\"hill_milli\":" << sample.surface.hill_amplitude_milli << ",";
        std::cout << "\"hill_width\":" << sample.surface.hill_width << ",";
        std::cout << "\"terraces\":" << sample.surface.terrace_count << ",";
        std::cout << "\"terrace_step_milli\":" << sample.surface.max_terrace_step_milli << ",";
        std::cout << "\"wall_gap_cells\":" << sample.wall_gap_cells << ",";
        std::cout << "\"surface_signature\":\"" << hex64(sample.surface.classification_signature) << "\",";
        std::cout << "\"content\":\"" << hex64(sample.content_hash) << "\"";
        std::cout << "}";
    }
    std::cout << "]}" << std::endl;
    return conserved && allocations == 0U ? 0 : 3;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 6) {
        std::cerr << "usage: water_issue26 <scenario> <shift> <workers> <mirror> <baseline|head>\n";
        return 2;
    }
    try {
        const auto spec = make_spec(argv[1]);
        const int shift = std::stoi(argv[2]);
        const int workers = std::stoi(argv[3]);
        const bool mirror = std::stoi(argv[4]) != 0;
        const std::string mode = argv[5];
        WaterLevelingExperiment experiment = WaterLevelingExperiment::Baseline;
        if (mode == "head") experiment = WaterLevelingExperiment::HeadScaledLocal;
        else if (mode != "baseline") return 2;
        if (workers != 1 && workers != 4) return 2;
        return run_case(spec, shift, workers, mirror, experiment);
    } catch (const std::exception& error) {
        std::cerr << error.what() << "\n";
        return 4;
    }
}
