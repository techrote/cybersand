#include "cybersand/world.hpp"
#include "cybersand/precision_storage.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {
using Clock = std::chrono::steady_clock;
using Counts = std::array<std::int64_t, 256>;
struct Sample {
    cybersand::TickStats stats;
    double tick_ms = 0;
    double edit_ms = 0;
    std::uint64_t edit_cells = 0;
};
int integer(const char* text, std::string_view name, int low, int high) {
    char* end = nullptr;
    const auto value = std::strtol(text, &end, 10);
    if (end == text || *end != '\0' || value < low || value > high) {
        throw std::invalid_argument(std::string(name) + " outside registered bounds");
    }
    return static_cast<int>(value);
}
double elapsed(Clock::time_point start) {
    return std::chrono::duration<double, std::milli>(Clock::now() - start).count();
}
bool epoch_clear(std::uint64_t tick) { return tick > 1 && (tick - 1) % 255 == 0; }
void summary(std::vector<double> values) {
    if (values.empty()) { std::cout << "null"; return; }
    double total = 0;
    for (const auto value : values) total += value;
    std::sort(values.begin(), values.end());
    auto percentile = [&](double p) {
        return values[static_cast<std::size_t>(std::ceil(p * static_cast<double>(values.size()))) - 1];
    };
    std::cout << "{\"count\":" << values.size() << ",\"total_ms\":" << total
              << ",\"p50_ms\":" << percentile(0.50) << ",\"p95_ms\":" << percentile(0.95)
              << ",\"p99_ms\":" << percentile(0.99) << ",\"max_ms\":" << values.back() << '}';
}
Counts census(const cybersand::World& world, int ox, int oy, int size) {
    Counts result{};
    // Deliberately outside timed ticks. Include the complete reserved halo.
    for (int y = oy - 128; y < oy + size + 128; ++y) {
        for (int x = ox - 128; x < ox + size + 128; ++x) {
            ++result[static_cast<std::size_t>(world.stored_material(x, y))];
        }
    }
    return result;
}
void counts_json(const Counts& counts) {
    std::cout << '[';
    for (std::size_t i = 0; i < counts.size(); ++i) {
        if (i) std::cout << ',';
        std::cout << counts[i];
    }
    std::cout << ']';
}
void samples_json(const std::vector<Sample>& samples) {
    std::cout << '[';
    for (std::size_t i = 0; i < samples.size(); ++i) {
        if (i) std::cout << ',';
        const auto& sample = samples[i];
        const auto& s = sample.stats;
        std::cout << "{\"tick\":" << s.tick << ",\"tick_ms\":" << sample.tick_ms
                  << ",\"epoch_clear\":" << (epoch_clear(s.tick) ? "true" : "false")
                  << ",\"edit_ms\":" << sample.edit_ms << ",\"edit_cells\":" << sample.edit_cells
                  << ",\"visited_cells\":" << s.visited_cells << ",\"moved_cells\":" << s.moved_cells
                  << ",\"scheduled_cores\":" << s.scheduled_cores
                  << ",\"active_chunks_before\":" << s.active_chunks_before
                  << ",\"active_chunks_after\":" << s.active_chunks_after
                  << ",\"active_blocks_after\":" << s.active_blocks_after
                  << ",\"dirty_chunks\":" << s.dirty_chunks
                  << ",\"chunk_allocations\":" << s.chunk_allocations
                  << ",\"temperature_field_allocations\":" << s.temperature_field_allocations
                  << ",\"deferred_events\":" << s.deferred_events << ",\"phase_jobs\":[";
        for (std::size_t phase = 0; phase < s.phase_jobs.size(); ++phase) {
            if (phase) std::cout << ',';
            std::cout << s.phase_jobs[phase];
        }
        std::cout << "]}";
    }
    std::cout << ']';
}
}

int main(int argc, char** argv) {
    try {
        if (argc != 9) throw std::invalid_argument(
            "usage: soliding_baseline fixture size workers settle warmup ticks offset_x offset_y");
        const std::string fixture = argv[1];
        const bool granular = fixture == "granular-rest" || fixture == "granular-release";
        if (!granular && fixture != "wall" && fixture != "redbrick" && fixture != "local-edit") {
            throw std::invalid_argument("unknown fixture");
        }
        const int size = integer(argv[2], "size", 128, 4096);
        const int workers = integer(argv[3], "workers", 1, 16);
        const int settle = integer(argv[4], "settle", 3, 10000);
        const int warmup = integer(argv[5], "warmup", 0, 10000);
        const int ticks = integer(argv[6], "ticks", 1, 1000000);
        const int ox = integer(argv[7], "offset_x", -8192, 8192);
        const int oy = integer(argv[8], "offset_y", -8192, 8192);
        cybersand::WorldConfig config{};
        config.worker_threads = static_cast<std::uint32_t>(workers);
        // Explicit construction capacities cover the largest admitted fixture,
        // including translated domains. They are fixed across all experiment sizes.
        config.maximum_chunk_count = 1600;
        config.active_chunk_capacity = 1600;
        config.active_core_capacity = 9216;
        const auto setup_start = Clock::now();
        cybersand::World world(config);
        world.reserve_region({ox - 128, oy - 128, size + 256, size + 256});
        const auto solid = fixture == "redbrick" ? cybersand::Material::RedBrick : cybersand::Material::Wall;
        if (!granular) {
            for (int y = 0; y < size; ++y) {
                for (int x = 0; x < size; ++x) world.set(ox + x, oy + y, solid);
            }
        } else {
            for (int x = 0; x < size; ++x) {
                world.set(ox + x, oy + size - 1, cybersand::Material::Wall);
                world.set(ox + x, oy + size - 33, cybersand::Material::Wall);
            }
            for (int y = 0; y < size; ++y) {
                world.set(ox, oy + y, cybersand::Material::Wall);
                world.set(ox + size - 1, oy + y, cybersand::Material::Wall);
            }
            for (int y = size / 2; y < size - 33; ++y) {
                for (int x = 1; x < size - 1; ++x) world.set(ox + x, oy + y, cybersand::Material::Sand);
            }
        }
        // Rendering is absent. Clear initial dirtiness once, then preserve it;
        // dirty_chunks measures pending dirty chunks, never per-tick mutations.
        (void)world.take_dirty_chunks();
        const auto setup_ms = elapsed(setup_start);
        std::vector<Sample> startup;
        std::vector<Sample> measured;
        startup.reserve(static_cast<std::size_t>(settle + warmup));
        measured.reserve(static_cast<std::size_t>(ticks));
        for (int i = 0; i < settle; ++i) {
            const auto start = Clock::now();
            const auto stats = world.tick();
            startup.push_back({stats, elapsed(start), 0, 0});
        }
        const auto initial_counts = census(world, ox, oy, size);
        const auto initial_hash = world.content_hash();
        // Protocol 2: full census/hash precedes warmup, so measured ticks follow
        // steady ticks without a global observer scan perturbing the caches.
        std::uint64_t warmup_moved_cells = 0;
        bool warmup_clean = true;
        for (int i = 0; i < warmup; ++i) {
            const auto start = Clock::now();
            const auto stats = world.tick();
            startup.push_back({stats, elapsed(start), 0, 0});
            warmup_moved_cells += stats.moved_cells;
            // All registered nonreactive fixtures must be quiet before their
            // first measured edit. Dirty state was cleared before settling.
            warmup_clean = warmup_clean && stats.dirty_chunks == 0;
        }
        Counts edit_delta{};
        std::uint64_t moved = 0;
        for (int i = 0; i < ticks; ++i) {
            const auto edit_start = Clock::now();
            std::uint64_t edits = 0;
            const auto replace = [&](int x, int y, cybersand::Material material) {
                const auto before = world.stored_material(x, y);
                if (before == material) return;
                --edit_delta[static_cast<std::size_t>(before)];
                ++edit_delta[static_cast<std::size_t>(material)];
                world.set(x, y, material);
                ++edits;
            };
            if (fixture == "local-edit" && i % 32 == 0) {
                const auto material = (i / 32) % 2 == 0 ? cybersand::Material::Empty : solid;
                for (int y = -4; y < 4; ++y) {
                    for (int x = -4; x < 4; ++x) replace(ox + size / 2 + x, oy + size / 2 + y, material);
                }
            }
            if (fixture == "granular-release" && i == 0) {
                for (int x = -16; x < 16; ++x) replace(ox + size / 2 + x, oy + size - 33, cybersand::Material::Empty);
            }
            const auto edit_ms = edits == 0 ? 0.0 : elapsed(edit_start);
            const auto start = Clock::now();
            const auto stats = world.tick();
            const auto tick_ms = elapsed(start);
            moved += stats.moved_cells;
            measured.push_back({stats, tick_ms, edit_ms, edits});
        }
        const auto final_counts = census(world, ox, oy, size);
        const auto final_hash = world.content_hash();
        bool conserved = true;
        for (std::size_t i = 0; i < initial_counts.size(); ++i) {
            if (initial_counts[i] + edit_delta[i] != final_counts[i]) conserved = false;
        }
        const bool stationary_control = fixture == "wall" || fixture == "redbrick" || fixture == "granular-rest";
        const bool valid = conserved && !world.has_failed() && warmup_clean && warmup_moved_cells == 0
            && (!stationary_control || (moved == 0 && initial_hash == final_hash))
            && (fixture != "granular-release" || moved > 0);
        std::vector<double> tick_times, complete_times, epoch_times, ordinary_times;
        for (const auto& sample : measured) {
            tick_times.push_back(sample.tick_ms);
            complete_times.push_back(sample.tick_ms + sample.edit_ms);
            (epoch_clear(sample.stats.tick) ? epoch_times : ordinary_times).push_back(sample.tick_ms);
        }
        std::cout << std::setprecision(10)
                  << "{\"schema\":\"soliding-baseline-v2\",\"arm\":\"current-ordinary-sleep\",\"fixture\":\"" << fixture
                  << "\",\"size\":" << size << ",\"workers\":" << workers
                  << ",\"offset\":[" << ox << ',' << oy << "],\"settle_ticks\":" << settle
                  << ",\"warmup_ticks\":" << warmup << ",\"warmup_moved_cells\":" << warmup_moved_cells
                  << ",\"warmup_clean\":" << (warmup_clean ? "true" : "false")
                  << ",\"measured_ticks\":" << ticks
                  << ",\"setup_ms\":" << setup_ms << ",\"tick_timing\":";
        summary(tick_times);
        std::cout << ",\"tick_plus_edit_timing\":"; summary(complete_times);
        std::cout << ",\"epoch_clear_timing\":"; summary(epoch_times);
        std::cout << ",\"ordinary_tick_timing\":"; summary(ordinary_times);
        std::cout << ",\"config\":{\"backend\":\"phased\",\"sleep_after_quiet_ticks\":3,\"chunk_size\":128,"
                  << "\"activity_block_size\":32,\"scheduling_core_size\":64,\"maximum_rule_radius\":2,"
                  << "\"ambient_temperature\":200,\"parallel_job_threshold\":8,\"maximum_chunk_count\":1600,"
                  << "\"active_chunk_capacity\":1600,\"active_core_capacity\":9216,\"deferred_event_capacity\":1024,"
                  << "\"physics_diagnostics\":false,\"simulation_region\":null,\"render_publication\":false},"
                  << "\"cell_storage_bytes\":" << sizeof(cybersand::detail::PrecisionStorage)
                  << ",\"cell_storage_alignment\":" << alignof(cybersand::detail::PrecisionStorage)
                  << ",\"resident_chunks\":" << world.chunk_count()
                  << ",\"resident_cell_bytes\":" << world.resident_cell_bytes()
                  << ",\"final_active_chunks\":" << world.active_chunk_count()
                  << ",\"initial_content_hash\":\"" << initial_hash << "\",\"final_content_hash\":\"" << final_hash
                  << "\",\"final_state_hash\":\"" << world.state_hash() << "\",\"initial_material_counts\":";
        counts_json(initial_counts);
        std::cout << ",\"external_edit_delta\":"; counts_json(edit_delta);
        std::cout << ",\"final_material_counts\":"; counts_json(final_counts);
        std::cout << ",\"conserved\":" << (conserved ? "true" : "false")
                  << ",\"valid\":" << (valid ? "true" : "false") << ",\"startup_samples\":";
        samples_json(startup);
        std::cout << ",\"samples\":"; samples_json(measured);
        std::cout << "}\n";
        return valid ? 0 : 2;
    } catch (const std::exception& error) {
        std::cerr << "soliding baseline failed: " << error.what() << '\n';
        return 1;
    }
}
