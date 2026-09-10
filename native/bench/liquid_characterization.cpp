#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <string>

// Observation-only CLI. Behavior mode never reads a clock. The Python runner
// gates timing separately and preserves every tick, command and executable hash.
namespace {
using namespace cybersand;
using Clock = std::chrono::steady_clock;

int run(int argc, char** argv) {
    if (argc != 9) throw std::invalid_argument(
        "fixture material shift mirror workers quiet observer behavior|timing");
    const std::string fixture = argv[1], mode = argv[8];
    const int id = std::stoi(argv[2]), shift = std::stoi(argv[3]);
    const int mirror = std::stoi(argv[4]), workers = std::stoi(argv[5]);
    const int quiet = std::stoi(argv[6]), observer = std::stoi(argv[7]);
    const bool timing = mode == "timing";
    if (mode != "behavior" && !timing) throw std::invalid_argument("mode");
    if (id != 3 && id != 20 && id != 21 && id != 24 && id != 33)
        throw std::invalid_argument("registered materials only");
    if ((workers != 1 && workers != 4) || (quiet != 3 && quiet != 4096) ||
        (observer != 0 && observer != 1) || (mirror != 0 && mirror != 1))
        throw std::invalid_argument("registered configuration only");
    if (fixture != "support" && fixture != "film" && fixture != "basin48" && fixture != "basin96")
        throw std::invalid_argument("fixture");
    if (fixture != "support" && id != 3) throw std::invalid_argument("Water-only fixture");
    const auto material = static_cast<Material>(id);
    const int width = fixture == "basin96" ? 96 : 48;
    const int horizon = timing ? 2048 : 1800;
    Clock::time_point startup;
    if (timing) startup = Clock::now();
    WorldConfig config;
    config.worker_threads = static_cast<std::uint32_t>(workers);
    config.parallel_job_threshold = 1;
    config.sleep_after_quiet_ticks = static_cast<std::uint32_t>(quiet);
    config.maximum_chunk_count = 64;
    config.active_chunk_capacity = 64;
    config.active_core_capacity = 512;
    config.physics_diagnostics.enabled = observer != 0;
    World world(config);
    const RectI64 included{shift - 128, shift - 128, 512, 512};
    world.reserve_region(included);
    world.set_simulation_region(included);
    const auto px = [&](int x) { return shift + (mirror ? width + 1 - x : x); };
    const auto put = [&](int x, int y, Material m) { world.set(px(x), shift + y, m); };
    for (int x = 0; x <= width + 1; ++x) { put(x, 0, Material::Wall); put(x, 47, Material::Wall); }
    for (int y = 0; y < 48; ++y) { put(0, y, Material::Wall); put(width + 1, y, Material::Wall); }
    std::uint64_t expected = material == Material::Water ? 255 : 1;
    if (fixture == "support") {
        for (int x = 1; x <= width; ++x) put(x, 23, Material::Wall);
        put(12, 22, material);
    } else if (fixture == "film") {
        if (!world.set_cell_state(px(12), shift + 46, material, 48, 0))
            throw std::runtime_error("film construction");
        expected = 48;
    } else {
        for (int x = 1; x <= 12; ++x) for (int y = 15; y <= 46; ++y) put(x, y, material);
        expected = 12U * 32U * 255U;
    }
    const double startup_us = timing
        ? std::chrono::duration<double, std::micro>(Clock::now() - startup).count() : 0;
    std::cout << "{\"metadata\":true,\"fixture\":\"" << fixture << "\",\"material\":" << id
              << ",\"shift\":" << shift << ",\"mirror\":" << mirror << ",\"workers\":" << workers
              << ",\"quiet\":" << quiet << ",\"observer\":" << observer
              << ",\"cell_bytes\":" << world.resident_cell_bytes() << ",\"chunks\":" << world.chunk_count();
    if (timing) std::cout << ",\"startup_us\":" << startup_us;
    std::cout << "}\n";
    auto previous = world.content_hash();
    int last_change = 0, first_release_descent = 0, arrival = 0, level = 0;
    for (int tick = 1; tick <= horizon; ++tick) {
        if (fixture == "support") {
            if (tick == 601) {
                for (int x = 1; x <= width; ++x) put(x, 23, Material::Empty);
                previous = world.content_hash(); // External shelf deletion is not liquid motion.
            }
            if (tick == 901) world.set_simulation_region(RectI64{shift + 2048, shift + 2048, 64, 64});
            if (tick == 961) world.set_simulation_region(included);
        }
        Clock::time_point start;
        if (timing) start = Clock::now();
        const auto stats = world.tick();
        double elapsed = 0;
        if (timing) elapsed = std::chrono::duration<double, std::micro>(Clock::now() - start).count();
        // Closed impermeable bounds make this complete species accounting, not
        // a finite open ROI estimate. Hash additionally observes the resident world.
        std::array<std::uint64_t, 96> columns{};
        std::uint64_t quantity = 0, occupied = 0, below = 0;
        for (int x = 1; x <= width; ++x) for (int y = 1; y < 47; ++y) {
            const auto m = world.stored_material(px(x), shift + y);
            if (m == Material::Empty || m == Material::Wall) continue;
            if (m != material) throw std::runtime_error("unexpected conversion");
            const auto q = material == Material::Water ? world.liquid_mass(px(x), shift + y) : 1U;
            quantity += q; columns[static_cast<std::size_t>(x - 1)] += q; ++occupied;
            if (y > 23) below += q;
        }
        if (quantity != expected) throw std::runtime_error("quantity mismatch at tick " + std::to_string(tick));
        if (stats.chunk_allocations || stats.temperature_field_allocations)
            throw std::runtime_error("unprepared tick allocation");
        const auto content = world.content_hash();
        const bool changed = content != previous;
        if (changed) last_change = tick;
        if (fixture == "film" && changed) throw std::runtime_error("supported film changed");
        if (fixture == "support" && tick >= 901 && tick <= 960 && changed)
            throw std::runtime_error("excluded content changed");
        previous = content;
        if (fixture == "support" && tick >= 601 && below && !first_release_descent) first_release_descent = tick;
        const auto span = std::minmax_element(columns.begin(), columns.begin() + width);
        const auto spread = *span.second - *span.first;
        int front = 0;
        for (int x = 1; x <= width; ++x) if (columns[static_cast<std::size_t>(x - 1)] >= 128U) front = x;
        if (!arrival && front >= width * 3 / 4) arrival = tick;
        if (!level && spread <= 255U) level = tick;
        std::array<std::uint64_t, 15> events{};
        if (const auto* totals = world.physics_diagnostics()) {
            if (totals->overflow) throw std::runtime_error("observation overflow");
            for (const auto& entry : totals->entries) {
                const auto kind = entry.key >> 24U;
                if (kind < events.size()) events[kind] += entry.count;
            }
        }
        std::cout << "{\"tick\":" << tick << ",\"quantity\":" << quantity << ",\"occupied\":" << occupied
                  << ",\"content\":\"" << std::hex << content << std::dec << "\",\"changed\":" << changed
                  << ",\"visited\":" << stats.visited_cells << ",\"moved\":" << stats.moved_cells
                  << ",\"active\":" << stats.active_blocks_after << ",\"cores\":" << stats.scheduled_cores
                  << ",\"below\":" << below << ",\"front\":" << front << ",\"spread\":" << spread
                  << ",\"events\":[";
        for (std::size_t i = 1; i < events.size(); ++i) std::cout << (i == 1 ? "" : ",") << events[i];
        std::cout << "]";
        if (tick % 60 == 0 || tick == horizon)
            std::cout << ",\"state\":\"" << std::hex << world.state_hash() << std::dec << "\"";
        if (timing) std::cout << ",\"tick_us\":" << elapsed;
        std::cout << "}\n";
    }
    if (fixture == "support" && !first_release_descent) throw std::runtime_error("support removal did not release liquid");
    std::cout << "{\"result\":true,\"last_change\":" << last_change
              << ",\"release_descent\":" << first_release_descent << ",\"arrival\":" << arrival
              << ",\"level\":" << level << "}\n";
    return 0;
}
}
int main(int argc, char** argv) {
    try { return run(argc, argv); }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
