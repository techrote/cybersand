#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>
#elif defined(__unix__)
#include <sys/resource.h>
#endif

namespace {
using Clock = std::chrono::steady_clock;
using cybersand::Material;
using cybersand::World;

enum class Arm { Current, Producer, Journal, Connectivity };

int integer(const char* text, std::string_view name, int low, int high) {
    char* end = nullptr;
    const auto value = std::strtol(text, &end, 10);
    if (end == text || *end != '\0' || value < low || value > high)
        throw std::invalid_argument(std::string(name) + " outside registered bounds");
    return static_cast<int>(value);
}

double elapsed(Clock::time_point start) {
    return std::chrono::duration<double, std::milli>(Clock::now() - start).count();
}

bool epoch_clear(std::uint64_t tick) { return tick > 1 && (tick - 1) % 255 == 0; }

Arm arm_from(std::string_view text) {
    if (text == "current") return Arm::Current;
    if (text == "producer") return Arm::Producer;
    if (text == "journal") return Arm::Journal;
    if (text == "connectivity") return Arm::Connectivity;
    throw std::invalid_argument("unknown arm");
}

const char* arm_name(Arm arm) {
    switch (arm) {
    case Arm::Current: return "current";
    case Arm::Producer: return "producer";
    case Arm::Journal: return "journal";
    case Arm::Connectivity: return "connectivity";
    }
    return "invalid";
}

std::uint64_t peak_rss_bytes() {
#if defined(_WIN32)
    PROCESS_MEMORY_COUNTERS info{};
    info.cb = sizeof(info);
    return GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info))
        ? static_cast<std::uint64_t>(info.PeakWorkingSetSize) : 0;
#elif defined(__unix__)
    rusage usage{};
    if (getrusage(RUSAGE_SELF, &usage) != 0) return 0;
#if defined(__APPLE__)
    return static_cast<std::uint64_t>(usage.ru_maxrss);
#else
    return static_cast<std::uint64_t>(usage.ru_maxrss) * 1024U;
#endif
#else
    return 0;
#endif
}

void timing_json(std::vector<double> values) {
    if (values.empty()) { std::cout << "null"; return; }
    std::sort(values.begin(), values.end());
    double total = 0;
    for (const auto value : values) total += value;
    const auto percentile = [&](double p) {
        const auto index = static_cast<std::size_t>(
            std::ceil(p * static_cast<double>(values.size()))) - 1U;
        return values[index];
    };
    std::cout << "{\"count\":" << values.size() << ",\"total_ms\":" << total
              << ",\"p50_ms\":" << percentile(0.50) << ",\"p95_ms\":" << percentile(0.95)
              << ",\"p99_ms\":" << percentile(0.99) << ",\"max_ms\":" << values.back() << '}';
}

double drain_journal(World& world, std::uint64_t& work, std::size_t limit = 100'000'000) {
    const auto start = Clock::now();
    std::size_t total = 0;
    while (world.settled_discovery_pending() != 0 && total < limit) {
        const auto used = world.advance_settled_discovery(8192);
        if (used == 0) throw std::runtime_error("pending journal made no progress");
        total += used;
    }
    if (total >= limit) throw std::runtime_error("journal drain limit exceeded");
    work += total;
    return elapsed(start);
}

double drain_regions(World& world, std::uint64_t& work, std::size_t limit = 100'000'000) {
    const auto start = Clock::now();
    std::size_t total = 0;
    while (total < limit) {
        const auto used = world.advance_settled_regions(8192);
        total += used;
        if (used == 0) break;
    }
    if (total >= limit) throw std::runtime_error("region drain limit exceeded");
    work += total;
    return elapsed(start);
}

void fill_fixture(World& world, const std::string& fixture, int side, int ox, int oy) {
    world.reserve_region({ox, oy, side, side});
    const auto solid = fixture == "redbrick" ? Material::RedBrick : Material::Wall;
    if (fixture == "ring") {
        for (int y = 0; y < side; ++y)
            for (int x = 0; x < side; ++x)
                if (x == 0 || y == 0 || x + 1 == side || y + 1 == side ||
                    x == side / 2 || y == side / 2) world.set(ox + x, oy + y, solid);
        return;
    }
    if (fixture == "granular-rest" || fixture == "granular-release") {
        for (int x = 0; x < side; ++x) {
            world.set(ox + x, oy + side - 1, Material::Wall);
            world.set(ox + x, oy + side / 2, Material::Wall);
        }
        for (int y = 0; y < side; ++y) {
            world.set(ox, oy + y, Material::Wall);
            world.set(ox + side - 1, oy + y, Material::Wall);
        }
        for (int y = side / 4; y < side / 2; ++y)
            for (int x = 1; x + 1 < side; ++x) world.set(ox + x, oy + y, Material::Sand);
        return;
    }
    for (int y = 0; y < side; ++y)
        for (int x = 0; x < side; ++x) world.set(ox + x, oy + y, solid);
}

std::uint64_t apply_edit(World& world, const std::string& fixture, int iteration,
                         int side, int ox, int oy) {
    const auto cx = ox + side / 2;
    const auto cy = oy + side / 2;
    std::uint64_t edits = 0;
    const auto set = [&](int x, int y, Material material) {
        if (world.stored_material(x, y) != material) { world.set(x, y, material); ++edits; }
    };
    if (fixture == "local-edit" && iteration % 16 == 0) {
        const auto material = (iteration / 16) % 2 == 0 ? Material::Empty : Material::Wall;
        for (int y = -4; y < 4; ++y) for (int x = -4; x < 4; ++x) set(cx + x, cy + y, material);
    } else if (fixture == "churn") {
        const auto material = iteration % 2 == 0 ? Material::Empty : Material::Wall;
        for (int y = -16; y < 16; ++y) for (int x = -16; x < 16; ++x) set(cx + x, cy + y, material);
    } else if (fixture == "bridge") {
        const auto material = iteration % 2 == 0 ? Material::Empty : Material::Wall;
        for (int y = 0; y < side; ++y) set(cx, oy + y, material);
    } else if (fixture == "mask") {
        if (iteration % 2 == 0) {
            world.configure_transient_obstacles({cx - 4, cy - 4, 8, 8});
            for (int y = 0; y < 8; ++y) for (int x = 0; x < 8; ++x)
                if (world.set_transient_obstacle(cx - 4 + x, cy - 4 + y, 1)) ++edits;
        } else {
            world.clear_transient_obstacles();
            edits = 64;
        }
    } else if (fixture == "pending-event" && iteration % 8 == 0) {
        if (world.queue_explosion(cx, cy, 2, 0)) ++edits;
    } else if (fixture == "exclusion") {
        if (iteration % 2 == 0) world.set_simulation_region(cybersand::RectI64{ox + side * 2, oy, side, side});
        else world.set_simulation_region(std::nullopt);
        ++edits;
    } else if (fixture == "granular-release" && iteration == 0) {
        for (int x = -16; x < 16; ++x) set(cx + x, oy + side / 2, Material::Empty);
    }
    return edits;
}

bool known_fixture(const std::string& fixture) {
    static const std::vector<std::string> names{
        "wall", "redbrick", "local-edit", "granular-rest", "granular-release",
        "ring", "bridge", "mask", "pending-event", "exclusion", "churn"};
    return std::find(names.begin(), names.end(), fixture) != names.end();
}
} // namespace

int main(int argc, char** argv) {
    try {
        if (argc != 9) throw std::invalid_argument(
            "usage: stage3_cost arm fixture side workers settle ticks offset_x offset_y");
        const auto arm = arm_from(argv[1]);
        const std::string fixture = argv[2];
        if (!known_fixture(fixture)) throw std::invalid_argument("unknown fixture");
        const auto side = integer(argv[3], "side", 64, 2048);
        const auto workers = integer(argv[4], "workers", 1, 4);
        const auto settle = integer(argv[5], "settle", 1, 4096);
        const auto ticks = integer(argv[6], "ticks", 1, 100000);
        const auto ox = integer(argv[7], "offset_x", -8192, 8192);
        const auto oy = integer(argv[8], "offset_y", -8192, 8192);
        if (side % 32 != 0) throw std::invalid_argument("side must be divisible by 32");

        cybersand::WorldConfig config{};
        config.chunk_size = 32;
        config.activity_block_size = 32;
        config.scheduling_core_size = 32;
        config.sleep_after_quiet_ticks = 1;
        config.worker_threads = static_cast<std::uint32_t>(workers);
        config.parallel_job_threshold = 1;
        config.initial_chunk_reserve = 4096;
        config.maximum_chunk_count = 4096;
        config.active_chunk_capacity = 4096;
        config.active_core_capacity = 4096;
        config.settled_discovery_enabled = arm != Arm::Current;
        config.settled_discovery_tile_capacity = 4096;
        config.settled_region_connectivity_enabled = arm == Arm::Connectivity;

        const auto setup_start = Clock::now();
        World world(config);
        fill_fixture(world, fixture, side, ox, oy);
        (void)world.take_dirty_chunks();
        const auto setup_ms = elapsed(setup_start);

        std::vector<double> settle_ticks;
        for (int i = 0; i < settle; ++i) {
            const auto start = Clock::now();
            (void)world.tick();
            settle_ticks.push_back(elapsed(start));
        }

        std::uint64_t journal_work = 0, region_work = 0;
        double initial_journal_ms = 0, initial_region_ms = 0;
        if (arm == Arm::Journal || arm == Arm::Connectivity)
            initial_journal_ms = drain_journal(world, journal_work);
        if (arm == Arm::Connectivity)
            initial_region_ms = drain_regions(world, region_work);
        const auto initial_content_hash = world.content_hash();

        std::vector<double> tick_times, ordinary_tick_times, epoch_tick_times,
                            complete_times, edit_times, journal_times, region_times;
        std::uint64_t external_edits = 0, measured_moved_cells = 0;
        for (int i = 0; i < ticks; ++i) {
            const auto edit_start = Clock::now();
            const auto edits = apply_edit(world, fixture, i, side, ox, oy);
            external_edits += edits;
            const auto edit_ms = edits == 0 ? 0.0 : elapsed(edit_start);
            edit_times.push_back(edit_ms);
            const auto tick_start = Clock::now();
            const auto stats = world.tick();
            const auto tick_ms = elapsed(tick_start);
            tick_times.push_back(tick_ms);
            (epoch_clear(stats.tick) ? epoch_tick_times : ordinary_tick_times).push_back(tick_ms);
            measured_moved_cells += stats.moved_cells;
            double journal_ms = 0, region_ms = 0;
            if (arm == Arm::Journal || arm == Arm::Connectivity) {
                journal_ms = drain_journal(world, journal_work);
                journal_times.push_back(journal_ms);
            }
            if (arm == Arm::Connectivity) {
                region_ms = drain_regions(world, region_work);
                region_times.push_back(region_ms);
            }
            complete_times.push_back(edit_ms + tick_ms + journal_ms + region_ms);
        }

        const auto producer = world.settled_discovery_producer_metrics();
        const auto journal = world.settled_discovery_journal_metrics();
        const auto regions = world.settled_region_metrics();
        std::uint64_t region_area = 0, region_area_max = 0;
        for (std::size_t slot = 0; slot < 4096; ++slot) if (const auto region = world.settled_region(slot)) {
            region_area += region->area;
            region_area_max = std::max(region_area_max, region->area);
        }
        const auto final_content_hash = world.content_hash();
        const auto stationary = fixture == "wall" || fixture == "redbrick" ||
                                fixture == "ring" || fixture == "granular-rest";
        const auto valid = !world.has_failed() && !world.settled_discovery_capacity_blocked() &&
            (arm != Arm::Connectivity ||
             world.settled_region_refusal() != cybersand::soliding::RegionRefusal::SourceFailure) &&
            (!stationary || (measured_moved_cells == 0 && initial_content_hash == final_content_hash)) &&
            (fixture != "granular-release" || measured_moved_cells != 0);

        std::cout << std::setprecision(10)
                  << "{\"schema\":\"soliding-stage3-cost-v1\",\"arm\":\"" << arm_name(arm)
                  << "\",\"fixture\":\"" << fixture << "\",\"side\":" << side
                  << ",\"workers\":" << workers << ",\"settle\":" << settle
                  << ",\"ticks\":" << ticks << ",\"offset\":[" << ox << ',' << oy << ']'
                  << ",\"setup_ms\":" << setup_ms << ",\"initial_journal_ms\":" << initial_journal_ms
                  << ",\"initial_region_ms\":" << initial_region_ms << ",\"settle_timing\":";
        timing_json(settle_ticks);
        std::cout << ",\"tick_timing\":"; timing_json(tick_times);
        std::cout << ",\"ordinary_tick_timing\":"; timing_json(ordinary_tick_times);
        std::cout << ",\"epoch_clear_timing\":"; timing_json(epoch_tick_times);
        std::cout << ",\"complete_timing\":"; timing_json(complete_times);
        std::cout << ",\"edit_timing\":"; timing_json(edit_times);
        std::cout << ",\"journal_timing\":"; timing_json(journal_times);
        std::cout << ",\"region_timing\":"; timing_json(region_times);
        std::cout << ",\"external_edits\":" << external_edits
                  << ",\"measured_moved_cells\":" << measured_moved_cells
                  << ",\"resident_chunks\":" << world.chunk_count()
                  << ",\"resident_cell_bytes\":" << world.resident_cell_bytes()
                  << ",\"discovery_storage_bytes\":" << world.settled_discovery_storage_bytes()
                  << ",\"region_storage_bytes\":" << world.settled_region_storage_bytes()
                  << ",\"peak_rss_bytes\":" << peak_rss_bytes() << ",\"producer\":";
        if (arm == Arm::Current) {
            std::cout << "null";
        } else {
            std::cout << "{\"notifications\":[";
            for (std::size_t i = 0; i < producer.notifications.size(); ++i) {
                if (i) std::cout << ',';
                std::cout << producer.notifications[i];
            }
            std::cout << "],\"invalidated_tiles\":[";
            for (std::size_t i = 0; i < producer.invalidated_tiles.size(); ++i) {
                if (i) std::cout << ',';
                std::cout << producer.invalidated_tiles[i];
            }
            std::cout << "],\"registration_work\":" << producer.registration_work
                      << ",\"registration_refusals\":" << producer.registration_refusals
                      << ",\"index_probes\":" << producer.index_probes
                      << ",\"signal_observations\":" << producer.signal_observations
                      << ",\"global_fences\":" << producer.global_fences
                      << ",\"mapped_tiles\":" << producer.mapped_tiles << '}';
        }
        std::cout << ",\"journal\":";
        if (arm == Arm::Current) {
            std::cout << "null";
        } else {
            std::cout << "{\"cells_inspected\":" << journal.cells_inspected
                      << ",\"blocks_started\":" << journal.blocks_started
                      << ",\"work_units\":" << journal.work_units
                      << ",\"invalidations\":" << journal.invalidations
                      << ",\"restarts\":" << journal.restarts
                      << ",\"publications\":" << journal.publications
                      << ",\"queue_high_water\":" << journal.queue_high_water
                      << ",\"drained_work\":" << journal_work << '}';
        }
        std::cout << ",\"connectivity\":";
        if (arm != Arm::Connectivity) {
            std::cout << "null";
        } else {
            std::cout << "{\"tile_scans\":" << regions.tile_scans
                  << ",\"cells_inspected\":" << regions.cells_inspected
                  << ",\"components\":" << regions.components
                  << ",\"component_high_water\":" << regions.component_high_water
                  << ",\"boundary_comparisons\":" << regions.boundary_comparisons
                  << ",\"adjacency_edges\":" << regions.adjacency_edges
                  << ",\"seed_probes\":" << regions.seed_probes
                  << ",\"builds_started\":" << regions.builds_started
                  << ",\"builds_completed\":" << regions.builds_completed
                  << ",\"builds_restarted\":" << regions.builds_restarted
                  << ",\"builds_refused\":" << regions.builds_refused
                  << ",\"invalidated_regions\":" << regions.invalidated_regions
                  << ",\"facing_invalidation_fanout\":" << regions.facing_invalidation_fanout
                  << ",\"tile_lookup_probes\":" << regions.tile_lookup_probes
                  << ",\"publications\":" << regions.publications
                  << ",\"work_units\":" << regions.work_units
                  << ",\"drained_work\":" << region_work
                  << ",\"region_count\":" << world.settled_region_count()
                  << ",\"region_area\":" << region_area << ",\"region_area_max\":" << region_area_max
                  << ",\"last_refusal\":" << static_cast<int>(world.settled_region_refusal()) << '}';
        }
        std::cout << ",\"initial_content_hash\":\"" << initial_content_hash
                  << "\",\"final_content_hash\":\"" << final_content_hash
                  << "\",\"final_state_hash\":\"" << world.state_hash()
                  << "\",\"valid\":" << (valid ? "true" : "false") << "}\n";
        return valid ? 0 : 2;
    } catch (const std::exception& error) {
        std::cerr << "Stage-3 cost benchmark failed: " << error.what() << '\n';
        return 1;
    }
}
