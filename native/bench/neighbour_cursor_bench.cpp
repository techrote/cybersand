// Standalone native World::tick benchmark; this file is not part of engine builds.
// Build: see run_neighbour_cursor.py; link Makefile SIMULATION_SOURCES only.
// Run: build/neighbour_cursor_bench native/bench/data/neighbour_stress_rectangles.txt 6 600 /tmp/ticks.csv
#include "cybersand/world.hpp"
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <vector>

using namespace cybersand;
using Clock = std::chrono::steady_clock;
struct Rect { std::int64_t x,y,w,h; unsigned material; };

static std::string hex(std::uint64_t n) {
    std::ostringstream s; s << std::hex << std::setfill('0') << std::setw(16) << n;
    return s.str();
}

int main(int argc, char** argv) {
    try {
        if (argc < 4 || argc > 5) {
            std::cerr << "usage: neighbour_cursor_bench RECTANGLES WORKERS TICKS [TICK_CSV]\n";
            return 2;
        }
        const auto workers = std::stoul(argv[2]), ticks = std::stoul(argv[3]);
        if ((workers != 1 && workers != 6) || (ticks != 600 && ticks != 1800))
            throw std::invalid_argument("workers=1/6, ticks=600/1800");
        std::ifstream input(argv[1]); if (!input) throw std::runtime_error("scene file missing");
        Rect rect{}; std::vector<Rect> rects;
        while (input >> rect.x >> rect.y >> rect.w >> rect.h >> rect.material) {
            if (rect.x < 0 || rect.y < 0 || rect.w < 1 || rect.h < 1 ||
                rect.x+rect.w > 2048 || rect.y+rect.h > 1024 ||
                rect.material < 1 || rect.material > 131)
                throw std::runtime_error("invalid rectangle");
            rects.push_back(rect);
        }
        if (!input.eof() || rects.size() != 129)
            throw std::runtime_error("expected 129 merged stress-canvas rectangles");
        WorldConfig cfg{};
        cfg.worker_threads = static_cast<std::uint32_t>(workers);
        cfg.maximum_chunk_count = 512;
        cfg.active_chunk_capacity = 512;
        cfg.active_core_capacity = 4096;
        World world(cfg);
        world.reserve_region({0,0,2048,1024});
        for (auto const& r: rects)
            for (std::int64_t y = r.y; y < r.y+r.h; ++y)
                for (std::int64_t x = r.x; x < r.x+r.w; ++x)
                    world.set(x,y,static_cast<Material>(r.material));
        std::ofstream csv;
        if (argc == 5) {
            csv.open(argv[4]); if (!csv) throw std::runtime_error("could not open csv");
            csv << "tick,ms,visited,moved,cores,active_blocks,workers_observed,"
                "chunk_allocations,temperature_field_allocations,deferred_events,dirty_chunks,"
                "active_chunks_before,active_chunks_after";
            for (std::size_t phase = 0; phase < SchedulerGeometry::kPhaseCount; ++phase)
                csv << ",phase_jobs_" << phase;
            csv << "\n";
            csv << std::fixed << std::setprecision(9);
        }
        double total=0,max_ms=0; std::uint64_t visited=0,moved=0,cores=0,allocations=0;
        std::ostringstream checkpoints; checkpoints << "[";
        bool first=true;
        for (unsigned i=1; i<=ticks; ++i) {
            auto start=Clock::now();
            const auto stats=world.tick();
            const double ms=std::chrono::duration<double,std::milli>(Clock::now()-start).count();
            total+=ms; max_ms=std::max(max_ms,ms);
            visited+=stats.visited_cells; moved+=stats.moved_cells;
            cores+=stats.scheduled_cores; allocations+=stats.chunk_allocations;
            if (csv) {
                csv << i << "," << ms << "," << stats.visited_cells
                    << "," << stats.moved_cells << "," << stats.scheduled_cores << ","
                    << stats.active_blocks_after << "," << stats.worker_threads_observed << ","
                    << stats.chunk_allocations << "," << stats.temperature_field_allocations << ","
                    << stats.deferred_events << "," << stats.dirty_chunks << ","
                    << stats.active_chunks_before << "," << stats.active_chunks_after;
                for (const auto count : stats.phase_jobs) csv << "," << count;
                csv << "\n";
            }
            if (i%150==0) {
                if (!first) checkpoints << ","; first=false;
                checkpoints << "{\"tick\":" << i << ",\"state_hash\":\""
                    << hex(world.state_hash()) << "\",\"physical_state_hash\":\""
                    << hex(world.physical_state_hash()) << "\"}";
            }
        }
        checkpoints << "]";
        std::cout << std::fixed << std::setprecision(9)
            << "{\"workers\":" << workers << ",\"ticks\":" << ticks
            << ",\"rectangles\":" << rects.size()
            << ",\"mean_ms\":" << total/ticks << ",\"max_ms\":" << max_ms
            << ",\"visited_total\":" << visited << ",\"moved_total\":" << moved
            << ",\"scheduled_cores_total\":" << cores
            << ",\"chunk_allocations_total\":" << allocations
            << ",\"state_hash\":\"" << hex(world.state_hash())
            << "\",\"physical_state_hash\":\"" << hex(world.physical_state_hash())
            << "\",\"checkpoints\":" << checkpoints.str() << "}\n";
        return 0;
    } catch (std::exception const& e) {
        std::cerr << "neighbour_cursor_bench: " << e.what() << "\n"; return 1;
    }
}
