// Source-identical paired Valgrind Callgrind input for #471.
// The complete 129-rectangle stress fixture is installed before enabling
// instrumentation. This is instruction-level attribution, NOT native tick timing.
// No changes to World or to original/candidate source trees.
#include "cybersand/world.hpp"
#include <valgrind/callgrind.h>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

using namespace cybersand;

static std::string hex_hash(std::uint64_t v) {
    std::ostringstream output;
    output << std::hex << std::setfill('0') << std::setw(16) << v;
    return output.str();
}

int main(int argc, char** argv) {
    try {
        if (argc != 3)
            throw std::invalid_argument("usage: callgrind_neighbour_cursor RECTANGLES TICKS");
        const int ticks = std::stoi(argv[2]);
        if (ticks < 1 || ticks > 40)
            throw std::invalid_argument("profiling ticks must be 1..40");
        std::ifstream fixture(argv[1]);
        if (!fixture)
            throw std::runtime_error("missing stress-canvas fixture");

        WorldConfig cfg{};
        cfg.worker_threads = 1;
        cfg.maximum_chunk_count = 512;
        cfg.active_chunk_capacity = 512;
        cfg.active_core_capacity = 4096;
        World world(cfg);
        world.reserve_region({0, 0, 2048, 1024});
        std::int64_t x=0, y=0, w=0, h=0;
        unsigned material=0, rectangles=0;
        while (fixture >> x >> y >> w >> h >> material) {
            if (x < 0 || y < 0 || w <= 0 || h <= 0 || x+w > 2048 ||
                y+h > 1024 || material == 0 || material > 131)
                throw std::runtime_error("invalid fixture rectangle");
            for (auto yy=y; yy<y+h; ++yy)
                for (auto xx=x; xx<x+w; ++xx)
                    world.set(xx, yy, static_cast<Material>(material));
            ++rectangles;
        }
        if (!fixture.eof() || rectangles != 129)
            throw std::runtime_error("stress fixture is not 129 valid rectangles");

        std::uint64_t visited=0, moved=0, cores=0;
        // Avoid attributing setup/rasterization to the World::tick read path.
        CALLGRIND_START_INSTRUMENTATION;
        CALLGRIND_ZERO_STATS;
        for (int i=0; i<ticks; ++i) {
            const auto stats=world.tick();
            visited+=stats.visited_cells;
            moved+=stats.moved_cells;
            cores+=stats.scheduled_cores;
        }
        CALLGRIND_STOP_INSTRUMENTATION;
        if (world.has_failed())
            throw std::runtime_error("world failed during profile");
        std::cout << "{\"ticks\":" << ticks
                  << ",\"rectangles\":" << rectangles
                  << ",\"state_hash\":\"" << hex_hash(world.state_hash())
                  << "\",\"physical_state_hash\":\"" << hex_hash(world.physical_state_hash())
                  << "\",\"visited\":" << visited
                  << ",\"moved\":" << moved
                  << ",\"scheduled_cores\":" << cores
                  << "}\n";
        return 0;
    } catch (std::exception const& e) {
        std::cerr << "callgrind-neighbour: " << e.what() << "\n";
        return 1;
    }
}
