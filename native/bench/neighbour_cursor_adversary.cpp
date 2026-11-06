// Source-neutral adversarial fixture for PR #471 neighbour-read qualification.
// Compile this same file against the exact parent and candidate engine sources.
#include "cybersand/world.hpp"
#include <algorithm>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

using namespace cybersand;

static std::string hex64(std::uint64_t value) {
    std::ostringstream out;
    out << std::hex << std::setfill('0') << std::setw(16) << value;
    return out.str();
}

static void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}

static void seed(World& w) {
    // Reactive pairs deliberately straddle signed chunk seams and corners.
    for (const int y : {-17, -1, 15, 31}) {
        for (const int x : {-17, -1, 15, 31}) {
            w.set(x, y, Material::Wood);
            w.set(x + 1, y, Material::Fire);
            w.set(x, y + 2, Material::Glass);
            w.set(x + 1, y + 2, Material::Lava);
            w.set(x, y + 4, Material::Metal);
            w.set(x + 1, y + 4, Material::Acid);
            w.set(x + 2, y + 6, Material::Sand);
            w.set(x + 3, y + 6, Material::Dust);
        }
    }
    // Sources at resident edges read across intentionally absent neighbour chunks.
    w.set(-32, -32, Material::Wood);
    w.set(-31, -32, Material::Fire);
    w.set(47, 47, Material::Glass);
    w.set(46, 47, Material::Lava);
}

int main(int argc, char** argv) {
    try {
        if (argc != 2) throw std::invalid_argument("usage: neighbour_cursor_adversary WORKERS");
        const auto workers = static_cast<std::uint32_t>(std::stoul(argv[1]));
        if (workers != 1U && workers != 6U) throw std::invalid_argument("workers must be 1 or 6");

        WorldConfig cfg;
        cfg.worker_threads = workers;
        cfg.chunk_size = 16;
        cfg.activity_block_size = 8;
        cfg.scheduling_core_size = 16;
        cfg.parallel_job_threshold = 2;
        cfg.initial_chunk_reserve = 8;
        cfg.maximum_chunk_count = 64;
        cfg.active_chunk_capacity = 64;
        cfg.active_core_capacity = 64;
        cfg.sleep_after_quiet_ticks = 2;
        World world(cfg);
        world.configure_transient_obstacles({-48, -48, 112, 112});
        seed(world);

        std::uint64_t visited = 0, moved = 0, cores = 0;
        std::uint32_t max_workers = 0;
        std::ostringstream checkpoints;
        checkpoints << '[';
        bool first = true;

        for (int tick = 1; tick <= 96; ++tick) {
            // Repeated add/clear masks over same-chunk, seam and negative cells.
            if (tick % 12 == 1) {
                world.clear_transient_obstacles();
                require(world.set_transient_obstacle(-1, -1, 1), "negative seam mask");
                require(world.set_transient_obstacle(15, -1, 2), "positive seam mask");
                require(world.set_transient_obstacle(-16, 15, 3), "chunk corner mask");
            } else if (tick % 12 == 7) {
                world.clear_transient_obstacles();
            }

            // Deterministic edits force sleeping/wake re-entry and both in-chunk
            // and cross-chunk rule reads without changing the apparatus by source.
            if (tick % 9 == 0) {
                const int x = (tick % 18 == 0) ? -2 : 14;
                const int y = (tick % 27 == 0) ? -2 : 14;
                world.set(x, y, Material::Wood);
                world.set(x + 1, y, Material::Fire);
            }
            if (tick == 40) world.set(-33, 16, Material::Glass);
            if (tick == 41) world.set(-32, 16, Material::Lava);

            const auto stats = world.tick();
            visited += stats.visited_cells;
            moved += stats.moved_cells;
            cores += stats.scheduled_cores;
            max_workers = std::max(max_workers, stats.worker_threads_observed);
            if (tick % 24 == 0) {
                if (!first) checkpoints << ',';
                first = false;
                checkpoints << "{\"tick\":" << tick
                    << ",\"state\":\"" << hex64(world.state_hash())
                    << "\",\"physical\":\"" << hex64(world.physical_state_hash()) << "\"}";
            }
        }
        checkpoints << ']';
        std::cout << "{\"workers\":" << workers
                  << ",\"state_hash\":\"" << hex64(world.state_hash())
                  << "\",\"physical_state_hash\":\"" << hex64(world.physical_state_hash())
                  << "\",\"visited\":" << visited
                  << ",\"moved\":" << moved
                  << ",\"cores\":" << cores
                  << ",\"max_workers_observed\":" << max_workers
                  << ",\"checkpoints\":" << checkpoints.str() << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "neighbour_cursor_adversary: " << error.what() << '\n';
        return 1;
    }
}
