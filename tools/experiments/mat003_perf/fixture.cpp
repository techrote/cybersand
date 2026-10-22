// MAT-003PREPASS S2F: source-control workload qualification only.
// This file is not part of production or of the S1 correctness collector.
// --mode measure is deliberately not a qualification pathway until separately admitted.
#include "cybersand/world.hpp"
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <exception>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <sys/resource.h>
#include <vector>

namespace {
using cybersand::Material;
using cybersand::RectI64;
using cybersand::SimulationBackend;
using cybersand::TickStats;
using cybersand::World;
using cybersand::WorldConfig;
using Clock = std::chrono::steady_clock;

struct Params {
    int side = 0;
    int workers = 0;
    int warmup = 0;
    int ticks = 0;
    unsigned seed = 0;
    std::string scenario;
    std::string mode;
};

std::uint64_t parse_number(std::string_view s) {
    if (s.empty()) throw std::invalid_argument("empty numeric argument");
    std::uint64_t v = 0;
    for (char ch : s) {
        if (ch < '0' || ch > '9') throw std::invalid_argument("nondecimal numeric argument");
        if (v > (UINT64_MAX - static_cast<unsigned>(ch - '0')) / 10)
            throw std::invalid_argument("numeric argument overflow");
        v = v * 10 + static_cast<unsigned>(ch - '0');
    }
    return v;
}

Params arguments(int argc, char** argv) {
    Params p;
    if (argc != 15) throw std::invalid_argument("expected seven named --key value options");
    for (int i = 1; i < argc; i += 2) {
        const std::string key(argv[i]), value(argv[i + 1]);
        if (key == "--side") p.side = static_cast<int>(parse_number(value));
        else if (key == "--workers") p.workers = static_cast<int>(parse_number(value));
        else if (key == "--warmup") p.warmup = static_cast<int>(parse_number(value));
        else if (key == "--ticks") p.ticks = static_cast<int>(parse_number(value));
        else if (key == "--seed") p.seed = static_cast<unsigned>(parse_number(value));
        else if (key == "--scenario") p.scenario = value;
        else if (key == "--mode") p.mode = value;
        else throw std::invalid_argument("unknown option: " + key);
    }
    if ((p.side != 512 && p.side != 1024 && p.side != 2048) ||
        (p.workers != 1 && p.workers != 4) || p.warmup != 120 ||
        p.ticks != 256 || p.seed != 204 ||
        (p.scenario != "quiet" && p.scenario != "small" &&
         p.scenario != "active" && p.scenario != "reactive") ||
        (p.mode != "qualify" && p.mode != "measure"))
        throw std::invalid_argument("fixture arguments not in S2F registration");
    return p;
}

void wall_box(World& world, int x, int y, int width, int height) {
    for (int yy = 0; yy < height; ++yy)
        for (int xx = 0; xx < width; ++xx)
            if (xx == 0 || yy == 0 || xx == width - 1 || yy == height - 1)
                world.set(x + xx, y + yy, Material::Wall);
}

World make_world(const Params& p) {
    WorldConfig c;
    c.backend = SimulationBackend::PhasedInPlace;
    c.worker_threads = static_cast<std::uint32_t>(p.workers);
    c.parallel_job_threshold = 1;
    c.initial_chunk_reserve = static_cast<std::size_t>(p.side / 128) * (p.side / 128);
    World world(c);
    world.reserve_region({0, 0, p.side, p.side});
    const auto expected = static_cast<std::size_t>(p.side / 128) * (p.side / 128);
    if (world.chunk_count() != expected) throw std::runtime_error("unexpected resident chunks");
    if (p.scenario == "quiet") {
        world.set_simulation_region(RectI64{p.side + 128, p.side + 128, 64, 64});
    } else if (p.scenario == "small") {
        world.set_simulation_region(RectI64{0, 0, 128, 128});
        wall_box(world, 16, 16, 64, 64);
        for (int x = 20; x < 76; x += 2) world.set(x, 33, Material::Sand);
        for (int x = 20; x < 76; x += 3) world.set(x, 27, Material::Water);
    } else if (p.scenario == "active") {
        world.set_simulation_region(RectI64{0, 0, 512, 512});
        for (int j = 0; j < 8; ++j)
            for (int i = 0; i < 8; ++i) {
                const int x = 20 + i * 56, y = 20 + j * 56;
                wall_box(world, x, y, 14, 18);
                for (int dx = 1; dx < 13; ++dx) {
                    world.set(x + dx, y + 3, Material::Water);
                    world.set(x + dx, y + 5, Material::Sand);
                }
            }
    } else {
        world.set_simulation_region(RectI64{0, 0, 512, 512});
        for (int j = 0; j < 4; ++j)
            for (int i = 0; i < 4; ++i) {
                int x = 20 + i * 112, y = 20 + j * 112;
                wall_box(world, x, y, 4, 3);
                world.set(x + 1, y + 1, Material::Brine);
                world.set(x + 2, y + 1, Material::BareIron);
            }
    }
    return world;
}

// Deterministic workload maintenance. It runs before the tick and its cost is
// never included in any eventual measured tick interval.
unsigned maintain(World& world, const Params& p, int step) {
    const int phase = static_cast<int>((p.seed + static_cast<unsigned>(step)) % 13U);
    if (p.scenario == "quiet") return 0;
    if (p.scenario == "small") {
        world.set(20 + phase, 19, Material::Sand);
        world.set(40 + phase, 19, Material::Water);
        return 2;
    }
    if (p.scenario == "active") {
        for (int j = 0; j < 8; ++j) for (int i = 0; i < 8; ++i) {
            const int x = 21 + i * 56, y = 21 + j * 56;
            world.set(x + phase % 11, y + 1, Material::Water);
            world.set(x + phase % 11, y + 2, Material::Sand);
        }
        return 128;
    }
    for (int j = 0; j < 4; ++j) for (int i = 0; i < 4; ++i) {
        const int x = 20 + i * 112, y = 20 + j * 112;
        world.set(x + 1, y + 1, Material::Brine);
        world.set(x + 2, y + 1, Material::BareIron);
    }
    return 32;
}

std::uint64_t count_reactive_products(const World& world) {
    std::uint64_t found = 0;
    for (int j = 0; j < 4; ++j) for (int i = 0; i < 4; ++i) {
        const int x = 20 + i * 112, y = 20 + j * 112;
        if (world.get(x + 2, y + 1) == Material::RustedSteel) ++found;
    }
    return found;
}

template <typename T>
void json_array(const std::vector<T>& values) {
    std::cout << '[';
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i) std::cout << ',';
        std::cout << values[i];
    }
    std::cout << ']';
}

int execute(const Params& p) {
    auto world = make_world(p);
    std::vector<std::uint64_t> tick_ns, input_ns, visits, phase_tasks;
    std::uint64_t positive_visits = 0, input_calls = 0, products = 0;
    const bool measured = p.mode == "measure";
    for (int step = 0; step < p.warmup + p.ticks; ++step) {
        const auto before_input = measured ? Clock::now() : Clock::time_point{};
        const unsigned written = maintain(world, p, step);
        const auto after_input = measured ? Clock::now() : Clock::time_point{};
        const auto before_tick = measured ? Clock::now() : Clock::time_point{};
        const TickStats stats = world.tick();
        const auto after_tick = measured ? Clock::now() : Clock::time_point{};
        if (world.has_failed() || stats.tick != static_cast<std::uint64_t>(step + 1) ||
            world.completed_tick_index() != stats.tick)
            throw std::runtime_error("tick failed, skipped or double completed");
        if (step >= p.warmup) {
            visits.push_back(stats.visited_cells);
            std::uint64_t tasks = 0;
            for (auto count : stats.phase_jobs) tasks += count;
            phase_tasks.push_back(tasks);
            positive_visits += (stats.visited_cells != 0);
            input_calls += written;
            if (p.scenario == "reactive") products += count_reactive_products(world);
            if (measured) {
                input_ns.push_back(static_cast<std::uint64_t>(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        after_input - before_input).count()));
                tick_ns.push_back(static_cast<std::uint64_t>(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        after_tick - before_tick).count()));
            }
        }
    }
    // A silent fixture that died before S2 warmup cannot qualify candidate work.
    if (p.scenario == "quiet" && positive_visits != 0)
        throw std::runtime_error("quiet fixture did not reach zero-visit condition");
    if (p.scenario != "quiet" && positive_visits < 231)
        throw std::runtime_error("maintained workload became inactive after warmup");
    if (p.scenario == "reactive" && products == 0)
        throw std::runtime_error("reactive source fixture never produced RustedSteel");
    struct rusage r{};
    if (getrusage(RUSAGE_SELF, &r) != 0)
        throw std::runtime_error("getrusage(RUSAGE_SELF) failed");
    std::cout << "{\"status\":\"passed\",\"stage\":\"S2F-source-feasibility\","
              << "\"performance_qualification\":false,\"mode\":\"" << p.mode
              << "\",\"scenario\":\"" << p.scenario << "\",\"side\":" << p.side
              << ",\"workers_configured\":" << p.workers
              << ",\"workers_observed\":false,\"seed\":" << p.seed
              << ",\"warmup_ticks\":" << p.warmup << ",\"sample_ticks\":" << p.ticks
              << ",\"completed_ticks\":" << world.completed_tick_index()
              << ",\"resident_cells\":" << static_cast<std::uint64_t>(p.side) * p.side
              << ",\"chunk_count\":" << world.chunk_count()
              << ",\"input_calls_after_warmup\":" << input_calls
              << ",\"reactive_products_observed\":" << products
              << ",\"positive_visit_ticks\":" << positive_visits
              << ",\"source_world_content_hash\":" << world.content_hash()
              << ",\"source_world_state_hash\":" << world.state_hash()
              << ",\"resident_aggregate_bytes_nonadditive\":" << world.resident_cell_bytes()
              << ",\"peak_process_rss_bytes\":" << static_cast<std::uint64_t>(r.ru_maxrss) * 1024ULL
              << ",\"input_tick_ns_separate\":true,\"visits\":";
    json_array(visits);
    std::cout << ",\"phase_jobs\":";
    json_array(phase_tasks);
    std::cout << ",\"input_ns\":";
    json_array(input_ns);
    std::cout << ",\"tick_ns\":";
    json_array(tick_ns);
    std::cout << "}\n";
    return 0;
}
} // namespace

int main(int argc, char** argv) {
    try { return execute(arguments(argc, argv)); }
    catch (const std::exception& e) {
        std::cerr << "MAT003 S2F fixture failure: " << e.what() << '\n';
        return 1;
    }
}
