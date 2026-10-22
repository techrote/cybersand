// MAT-003PREPASS S2 candidate-twin qualification only.
// Built twice from the same immutable per-arm overlay:
// MAT003_TWIN_OBSERVERS=1 (observed) and =0 (timing-twin).
// Both modes are explicitly untimed; no S2A/S2B timing is admitted here.
#include "cybersand/world.hpp"
#include "world_adapter.hpp"

#include <cstdint>
#include <exception>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <sys/resource.h>
#include <vector>

#ifndef MAT003_TWIN_OBSERVERS
#error "MAT003_TWIN_OBSERVERS must be registered by the twin collector"
#endif
#ifndef MAT003_ARM_ID
#error "MAT003_ARM_ID must be registered by the World overlay"
#endif

namespace {
using cybersand::Material;
using cybersand::RectI64;
using cybersand::SimulationBackend;
using cybersand::TickStats;
using cybersand::World;
using cybersand::WorldConfig;

struct Params {
    int side = 0;
    int workers = 0;
    int warmup = 0;
    int ticks = 0;
    unsigned seed = 0;
    std::string scenario;
    std::string observer_mode;
};

struct InputLedger {
    std::uint64_t calls = 0;
    std::uint64_t water_added = 0;
    std::uint64_t water_removed = 0;
};

struct SemanticSummary {
    std::uint64_t empty_cells = 0;
    std::uint64_t water_cells = 0;
    std::uint64_t sand_cells = 0;
    std::uint64_t wall_cells = 0;
    std::uint64_t other_cells = 0;
    std::uint64_t water_mass = 0;
};

std::uint64_t parse_number(std::string_view s) {
    if (s.empty()) throw std::invalid_argument("empty numeric argument");
    std::uint64_t value = 0;
    for (char ch : s) {
        if (ch < '0' || ch > '9') throw std::invalid_argument("nondecimal numeric argument");
        if (value > (UINT64_MAX - static_cast<unsigned>(ch - '0')) / 10)
            throw std::invalid_argument("numeric argument overflow");
        value = value * 10 + static_cast<unsigned>(ch - '0');
    }
    return value;
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
        else if (key == "--observer") p.observer_mode = value;
        else throw std::invalid_argument("unknown option: " + key);
    }
    const bool active_anchor =
        p.side == 512 && p.workers == 4 && p.scenario == "active";
    const bool quiet_anchor =
        p.side == 2048 && p.workers == 1 && p.scenario == "quiet";
    if ((!active_anchor && !quiet_anchor) || p.warmup != 120 || p.ticks != 256 ||
        p.seed != 204 ||
        (p.observer_mode != "observed" && p.observer_mode != "timing-twin"))
        throw std::invalid_argument("fixture arguments not in candidate-twin registration");
#if MAT003_TWIN_OBSERVERS
    if (p.observer_mode != "observed")
        throw std::invalid_argument("observed binary invoked as timing twin");
#else
    if (p.observer_mode != "timing-twin")
        throw std::invalid_argument("timing-twin binary invoked as observed");
#endif
    return p;
}

void wall_box(World& world, int x, int y, int width, int height) {
    for (int yy = 0; yy < height; ++yy)
        for (int xx = 0; xx < width; ++xx)
            if (xx == 0 || yy == 0 || xx == width - 1 || yy == height - 1)
                world.set(x + xx, y + yy, Material::Wall);
}

World make_world(const Params& p) {
    WorldConfig config;
    config.backend = SimulationBackend::PhasedInPlace;
    config.worker_threads = static_cast<std::uint32_t>(p.workers);
    config.parallel_job_threshold = 1;
    config.initial_chunk_reserve =
        static_cast<std::size_t>(p.side / 128) * static_cast<std::size_t>(p.side / 128);
    World world(config);
    world.reserve_region({0, 0, p.side, p.side});
    const auto expected =
        static_cast<std::size_t>(p.side / 128) * static_cast<std::size_t>(p.side / 128);
    if (world.chunk_count() != expected) throw std::runtime_error("unexpected resident chunks");

    if (p.scenario == "quiet") {
        world.set_simulation_region(RectI64{p.side + 128, p.side + 128, 64, 64});
    } else {
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
    }
    return world;
}

std::uint64_t water_at(const World& world, int x, int y) {
    return world.get(x, y) == Material::Water ? world.liquid_mass(x, y) : 0U;
}

void set_with_ledger(World& world, int x, int y, Material material, InputLedger* ledger) {
    const std::uint64_t before = ledger ? water_at(world, x, y) : 0U;
    world.set(x, y, material);
    if (!ledger) return;
    const std::uint64_t after = water_at(world, x, y);
    ++ledger->calls;
    if (after >= before) ledger->water_added += after - before;
    else ledger->water_removed += before - after;
}

unsigned maintain(World& world, const Params& p, int step, InputLedger* ledger) {
    if (p.scenario == "quiet") return 0;
    const bool pulse = (step & 1) == 0;
    for (int j = 0; j < 8; ++j)
        for (int i = 0; i < 8; ++i) {
            const int x = 21 + i * 56, y = 21 + j * 56;
            set_with_ledger(world, x + 1, y + 1,
                            pulse ? Material::Water : Material::Sand, ledger);
            set_with_ledger(world, x + 2, y + 1,
                            pulse ? Material::Sand : Material::Water, ledger);
        }
    return 128;
}

SemanticSummary summarize(const World& world, int side) {
    SemanticSummary out;
    for (int y = 0; y < side; ++y)
        for (int x = 0; x < side; ++x) {
            const auto material = world.get(x, y);
            if (material == Material::Empty) ++out.empty_cells;
            else if (material == Material::Water) {
                ++out.water_cells;
                out.water_mass += world.liquid_mass(x, y);
            } else if (material == Material::Sand) ++out.sand_cells;
            else if (material == Material::Wall) ++out.wall_cells;
            else ++out.other_cells;
        }
    return out;
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

    for (int step = 0; step < p.warmup; ++step) {
        (void)maintain(world, p, step, nullptr);
        const TickStats stats = world.tick();
        if (world.has_failed() || stats.tick != static_cast<std::uint64_t>(step + 1) ||
            world.completed_tick_index() != stats.tick)
            throw std::runtime_error("warmup tick failed, skipped or double completed");
    }

    const auto before = summarize(world, p.side);
    InputLedger ledger;
    std::vector<std::uint64_t> visits, phase_tasks;
    visits.reserve(static_cast<std::size_t>(p.ticks));
    phase_tasks.reserve(static_cast<std::size_t>(p.ticks));
    std::uint64_t positive_visits = 0;
    std::uint64_t input_calls = 0;

    mat003_world::reset_dispatch_observations();
    for (int sample = 0; sample < p.ticks; ++sample) {
        const int step = p.warmup + sample;
        input_calls += maintain(world, p, step, &ledger);
        const TickStats stats = world.tick();
        if (world.has_failed() ||
            stats.tick != static_cast<std::uint64_t>(step + 1) ||
            world.completed_tick_index() != stats.tick)
            throw std::runtime_error("sample tick failed, skipped or double completed");
        visits.push_back(stats.visited_cells);
        std::uint64_t tasks = 0;
        for (auto count : stats.phase_jobs) tasks += count;
        phase_tasks.push_back(tasks);
        positive_visits += stats.visited_cells != 0;
    }
    const auto dispatch = mat003_world::dispatch_observations();
    const auto after = summarize(world, p.side);

    if (ledger.calls != input_calls)
        throw std::runtime_error("input call ledger disagrees with fixture schedule");
    if (p.scenario == "quiet") {
        if (positive_visits != 0 || input_calls != 0)
            throw std::runtime_error("quiet anchor was not quiescent");
    } else {
        if (positive_visits < 231 || input_calls != 128ULL * static_cast<std::uint64_t>(p.ticks))
            throw std::runtime_error("active anchor became vacuous");
    }

    const std::int64_t projected_water =
        static_cast<std::int64_t>(before.water_mass) +
        static_cast<std::int64_t>(ledger.water_added) -
        static_cast<std::int64_t>(ledger.water_removed);
    if (projected_water < 0 ||
        static_cast<std::uint64_t>(projected_water) != after.water_mass)
        throw std::runtime_error("closed Water ledger does not reconcile");

#if MAT003_TWIN_OBSERVERS
    if (!mat003_world::source_control && p.workers == 4 &&
        (dispatch.calls == 0 || dispatch.dispatched_tasks == 0 || dispatch.worker_tasks == 0))
        throw std::runtime_error("candidate observer did not witness real worker dispatch/execution");
#else
    if (dispatch.calls != 0 || dispatch.dispatched_tasks != 0 || dispatch.worker_tasks != 0)
        throw std::runtime_error("timing twin retained correctness observer activity");
#endif

    struct rusage usage{};
    if (getrusage(RUSAGE_SELF, &usage) != 0)
        throw std::runtime_error("getrusage(RUSAGE_SELF) failed");

    std::cout
        << "{\"status\":\"passed\",\"stage\":\"S2-candidate-twins\","
        << "\"performance_qualification\":false,\"formal_timing_admitted\":false,"
        << "\"arm_id\":\"" << MAT003_ARM_ID << "\","
        << "\"observer_mode\":\"" << p.observer_mode << "\","
        << "\"observer_compiled\":" << (MAT003_TWIN_OBSERVERS ? "true" : "false") << ','
        << "\"scenario\":\"" << p.scenario << "\",\"side\":" << p.side
        << ",\"workers_configured\":" << p.workers
        << ",\"seed\":" << p.seed
        << ",\"warmup_ticks\":" << p.warmup
        << ",\"sample_ticks\":" << p.ticks
        << ",\"completed_ticks\":" << world.completed_tick_index()
        << ",\"resident_cells\":" << static_cast<std::uint64_t>(p.side) * p.side
        << ",\"chunk_count\":" << world.chunk_count()
        << ",\"positive_visit_ticks\":" << positive_visits
        << ",\"input_calls_after_warmup\":" << input_calls
        << ",\"input_water_added\":" << ledger.water_added
        << ",\"input_water_removed\":" << ledger.water_removed
        << ",\"water_mass_before_sample\":" << before.water_mass
        << ",\"water_mass_after_sample\":" << after.water_mass
        << ",\"content_hash\":" << world.content_hash()
        << ",\"state_hash\":" << world.state_hash()
        << ",\"cell_stride\":" << sizeof(mat003_world::Cell)
        << ",\"cell_alignment\":" << alignof(mat003_world::Cell)
        << ",\"dispatch_calls\":" << dispatch.calls
        << ",\"dispatched_tasks\":" << dispatch.dispatched_tasks
        << ",\"worker_tasks\":" << dispatch.worker_tasks
        << ",\"peak_process_rss_bytes\":"
        << static_cast<std::uint64_t>(usage.ru_maxrss) * 1024ULL
        << ",\"summary\":{"
        << "\"empty\":" << after.empty_cells
        << ",\"water\":" << after.water_cells
        << ",\"sand\":" << after.sand_cells
        << ",\"wall\":" << after.wall_cells
        << ",\"other\":" << after.other_cells
        << ",\"water_mass\":" << after.water_mass << "},"
        << "\"visits\":";
    json_array(visits);
    std::cout << ",\"phase_jobs\":";
    json_array(phase_tasks);
    std::cout << ",\"input_ns\":[],\"tick_ns\":[]}\n";
    return 0;
}
} // namespace

int main(int argc, char** argv) {
    try {
        return execute(arguments(argc, argv));
    } catch (const std::exception& error) {
        std::cerr << "MAT003 candidate twin fixture failed: " << error.what() << '\n';
        return 1;
    }
}
