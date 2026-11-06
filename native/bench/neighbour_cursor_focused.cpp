// Independently replayable native World exactness fixture for PR #471.
// The SAME file is linked into baseline and cursor engines (no tracked edits to
// either detached source worktree).  Output is deterministic JSON, not a speed test.
#include "cybersand/world.hpp"
#include <array>
#include <cstdint>
#include <exception>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

using namespace cybersand;

static std::string hex_hash(std::uint64_t number) {
    std::ostringstream out;
    out << std::hex << std::setfill('0') << std::setw(16) << number;
    return out.str();
}

static bool is_checkpoint(int tick) {
    switch (tick) {
        case 1: case 2: case 16: case 31: case 32: case 33:
        case 63: case 64: case 65: case 127: case 128: case 129:
        case 150: case 255: case 256: case 257: case 300:
        case 383: case 384: case 385: case 450:
        case 511: case 512: case 513: case 520: return true;
        default: return false;
    }
}

static void load_scene(World& w, std::string_view scenario, std::int64_t c) {
    static constexpr std::array<Material, 16> mats{
        Material::Sand, Material::Dust, Material::Stone, Material::Smoke,
        Material::Fire, Material::Ice, Material::Water, Material::Oil,
        Material::Metal, Material::Wood, Material::Plant, Material::Mite,
        Material::Seed, Material::Acid, Material::Lava, Material::Brine
    };
    // Sparse source-boundary placements cross positive/negative seams and
    // corners; non-resident neighbouring chunks remain genuinely absent.
    const std::array<std::pair<std::int64_t,std::int64_t>, 13> anchors{{
        {-2*c-1, -2*c-1}, {-c-1, -c-1}, {-c, -c},
        {-1, -1}, {0, 0}, {c-1, c-1}, {c, c},
        {2*c-1, -c}, {-2*c, c}, {-c, 2*c-1},
        {c-1, -1}, {-1, c-1}, {c, -c}
    }};
    for (std::size_t p = 0; p < anchors.size(); ++p) {
        auto [a, b] = anchors[p];
        for (int dx = -3; dx <= 3; ++dx)
            w.set(a+dx, b+4, Material::Wall);
        for (int dy = -2; dy <= 2; ++dy)
            for (int dx = -2; dx <= 2; ++dx)
                w.set(a+dx, b+dy, mats[(p*7 + std::size_t((dy+2)*5+dx+2)) % mats.size()]);
        // Explicit same-kernel reaction contact, asleep/wake and moving-water
        // opportunities in addition to randomized neighbour material reads.
        w.set(a, b-1, Material::Ice);
        w.set(a+1, b-1, Material::Water);
        w.set(a, b+1, Material::Seed);
        w.set(a+1, b+1, Material::Fire);
    }
    // A non-resident lookup stays empty even when other chunks are populated.
    if (w.get(-4*c-2, 4*c+2) != Material::Empty)
        throw std::runtime_error("non-resident chunk did not read Empty");

    if (scenario == "masked128") {
        w.configure_transient_obstacles({-3*c, -3*c, 6*c, 6*c});
        if (!w.set_transient_obstacle(0, 0, 1) ||
            !w.set_transient_obstacle(1, 0, 1) ||
            !w.set_transient_obstacle(-1, -1, 2))
            throw std::runtime_error("initial transient-mask setup refused");
        if (w.get(0, 0) != Material::Wall)
            throw std::runtime_error("transient source visibility was not Wall");
    }
}

static void external_event(World& w, std::string_view scenario,
                           std::int64_t c, int next_tick) {
    // Introduce previously missing chunks after earlier jobs have executed.
    if (next_tick == 30)
        w.set(3*c+1, -3*c-1, Material::Smoke);
    if (next_tick == 65)
        w.set(-3*c-1, 3*c+1, Material::Water);
    if (next_tick == 250)
        w.set(3*c+2, 3*c+2, Material::Fire);

    if (scenario != "masked128") return;
    if (next_tick == 33 || next_tick == 65 || next_tick == 161 || next_tick == 257)
        w.clear_transient_obstacles();
    if (next_tick == 129 || next_tick == 256) {
        w.configure_transient_obstacles({-3*c, -3*c, 6*c, 6*c});
        if (!w.set_transient_obstacle(0, 0, 1) ||
            !w.set_transient_obstacle(1, 0, 1))
            throw std::runtime_error("dynamic transient-mask setup refused");
    }
}

int main(int argc, char** argv) {
    try {
        if (argc != 4) {
            std::cerr << "usage: neighbour_cursor_focused CASE WORKERS TICKS\n";
            return 2;
        }
        const std::string_view scenario(argv[1]);
        const int workers = std::stoi(argv[2]);
        const int ticks = std::stoi(argv[3]);
        if (!(scenario == "seams128" || scenario == "seams192" ||
              scenario == "masked128" || scenario == "epochs192") ||
            (workers != 1 && workers != 6) ||
            (ticks != 300 && ticks != 520))
            throw std::invalid_argument("unsupported case/workers/ticks");
        const std::int64_t c = scenario == "seams192" || scenario == "epochs192" ? 192 : 128;
        WorldConfig cfg{};
        cfg.chunk_size = static_cast<std::int32_t>(c);
        cfg.worker_threads = static_cast<std::uint32_t>(workers);
        cfg.maximum_chunk_count = 256;
        cfg.active_chunk_capacity = 256;
        cfg.active_core_capacity = 4096;
        World w(cfg);
        if (scenario == "epochs192")
            w.reserve_region({-2*c, -2*c, 4*c, 4*c});
        load_scene(w, scenario, c);
        std::ostringstream checkpoints, work;
        checkpoints << '[';
        work << '[';
        bool first = true;
        std::uint64_t visited = 0, moved = 0, cores = 0;
        for (int tick = 1; tick <= ticks; ++tick) {
            external_event(w, scenario, c, tick);
            auto stats = w.tick();
            if (w.has_failed() || stats.tick != static_cast<std::uint64_t>(tick))
                throw std::runtime_error("tick failed or index mismatch");
            if (tick != 1) work << ',';
            work << '[' << stats.visited_cells << ',' << stats.moved_cells
                 << ',' << stats.scheduled_cores << ',' << stats.active_blocks_after
                 << ',' << stats.chunk_allocations << ','
                 << stats.temperature_field_allocations << ','
                 << stats.deferred_events << ','
                 << stats.dirty_chunks << ','
                 << stats.active_chunks_before << ','
                 << stats.active_chunks_after << ']';
            visited += stats.visited_cells;
            moved += stats.moved_cells;
            cores += stats.scheduled_cores;
            if (!is_checkpoint(tick)) continue;
            if (!first) checkpoints << ',';
            first = false;
            checkpoints << "{\"tick\":" << tick
                        << ",\"state_hash\":\"" << hex_hash(w.state_hash())
                        << "\",\"physical_state_hash\":\"" << hex_hash(w.physical_state_hash())
                        << "\",\"content_hash\":\"" << hex_hash(w.content_hash())
                        << "\",\"chunks\":" << w.chunk_count()
                        << '}';
        }
        checkpoints << ']';
        work << ']';
        std::cout << "{\"scenario\":\"" << scenario << "\",\"workers\":" << workers
                  << ",\"ticks\":" << ticks
                  << ",\"visited_total\":" << visited
                  << ",\"moved_total\":" << moved
                  << ",\"cores_total\":" << cores
                  << ",\"checkpoints\":" << checkpoints.str()
                  << ",\"work_per_tick\":" << work.str() << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "focused neighbour replay: " << error.what() << '\n';
        return 1;
    }
}
