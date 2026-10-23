// MAT-003PREPASS S2P timing-capable apparatus.
// The same sealed observer-off binary supports --mode qualify and --mode measure.
// Qualification invokes no timing clocks and must precede any formal timing admission.
#include "cybersand/world.hpp"
#include "world_adapter.hpp"

#include <chrono>
#include <array>
#include <cstdint>
#include <exception>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <sys/resource.h>
#include <vector>

#ifndef MAT003_TWIN_OBSERVERS
#error "MAT003_TWIN_OBSERVERS must be supplied"
#endif
#if MAT003_TWIN_OBSERVERS != 0 && MAT003_TWIN_OBSERVERS != 1
#error "S2P performance candidates must compile correctness observers out"
#endif
#ifndef MAT003_ARM_ID
#error "MAT003_ARM_ID must be supplied by the registered overlay"
#endif

namespace cybersand { class PrecisionProbe { public: static std::uint64_t epoch(const World& w) { return w.update_epoch_; } }; }

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

struct InputLedger {
    std::uint64_t calls = 0;
    std::uint64_t water_added = 0;
    std::uint64_t water_removed = 0;
};

struct Summary {
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
        else if (key == "--mode") p.mode = value;
        else throw std::invalid_argument("unknown option: " + key);
    }
    const bool active = p.side == 512 && p.workers == 4 && p.scenario == "active";
    const bool quiet = p.side == 2048 && p.workers == 1 && p.scenario == "quiet";
    if ((!active && !quiet) || p.warmup != 120 || p.ticks != 256 || p.seed != 204 ||
        (p.mode != "qualify" && p.mode != "measure"))
        throw std::invalid_argument("fixture arguments not in S2P registration");
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

void set_with_ledger(World& world, int x, int y, Material material, InputLedger& ledger) {
    const std::uint64_t before = water_at(world, x, y);
    world.set(x, y, material);
    const std::uint64_t after = water_at(world, x, y);
    ++ledger.calls;
    if (after >= before) ledger.water_added += after - before;
    else ledger.water_removed += before - after;
}

unsigned maintain(World& world, const Params& p, int step, InputLedger& ledger) {
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

Summary summarize(const World& world, int side) {
    Summary out;
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

bool clear_tick(std::uint64_t completed_tick) {
    constexpr std::uint64_t maximum =
        MAT003_EPOCH_BITS == 8 ? 255ULL : 65535ULL;
    return completed_tick >= maximum + 1ULL &&
           ((completed_tick - 1ULL) % maximum) == 0ULL;
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
    const bool measured = p.mode == "measure";
    if (measured && MAT003_TWIN_OBSERVERS) throw std::runtime_error("observed twin cannot measure");
    const auto startup_begin = measured ? Clock::now() : Clock::time_point{};
    auto world = make_world(p);
    const auto startup_end = measured ? Clock::now() : Clock::time_point{};
    const auto initial = summarize(world, p.side);

    InputLedger warmup_ledger;
    for (int step = 0; step < p.warmup; ++step) {
        (void)maintain(world, p, step, warmup_ledger);
        const TickStats stats = world.tick();
        if (world.has_failed() || stats.tick != static_cast<std::uint64_t>(step + 1) ||
            world.completed_tick_index() != stats.tick)
            throw std::runtime_error("warmup tick failed, skipped or double completed");
    }

    InputLedger sample_ledger;
    std::vector<std::uint64_t> visits, phase_jobs, tick_ns, input_ns, clear_ticks;
    visits.reserve(static_cast<std::size_t>(p.ticks));
    phase_jobs.reserve(static_cast<std::size_t>(p.ticks));
    if (measured) {
        tick_ns.reserve(static_cast<std::size_t>(p.ticks));
        input_ns.reserve(static_cast<std::size_t>(p.ticks));
    }
    std::uint64_t positive_visits = 0;
    std::vector<std::array<std::uint64_t,3>> clear_observations;

    for (int sample = 0; sample < p.ticks; ++sample) {
        const int step = p.warmup + sample;
        const auto input_begin = measured ? Clock::now() : Clock::time_point{};
        const unsigned calls = maintain(world, p, step, sample_ledger);
        const auto input_end = measured ? Clock::now() : Clock::time_point{};
        const auto epoch_before = cybersand::PrecisionProbe::epoch(world);
        const auto tick_begin = measured ? Clock::now() : Clock::time_point{};
        const TickStats stats = world.tick();
        const auto tick_end = measured ? Clock::now() : Clock::time_point{};
        if (world.has_failed() || stats.tick != static_cast<std::uint64_t>(step + 1) ||
            world.completed_tick_index() != stats.tick)
            throw std::runtime_error("sample tick failed, skipped or double completed");
        if (calls != (p.scenario == "active" ? 128U : 0U))
            throw std::runtime_error("input schedule changed");
        visits.push_back(stats.visited_cells);
        std::uint64_t tasks = 0;
        for (auto count : stats.phase_jobs) tasks += count;
        phase_jobs.push_back(tasks);
        positive_visits += stats.visited_cells != 0;
        const bool observed_clear = epoch_before == 255 && cybersand::PrecisionProbe::epoch(world) == 1;
        if (observed_clear != clear_tick(stats.tick)) throw std::runtime_error("natural epoch transition mismatch");
        if (observed_clear) { clear_ticks.push_back(stats.tick); clear_observations.push_back({stats.tick,epoch_before,cybersand::PrecisionProbe::epoch(world)}); }
        if (measured) {
            input_ns.push_back(static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(input_end - input_begin).count()));
            tick_ns.push_back(static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(tick_end - tick_begin).count()));
        }
    }

    const auto final = summarize(world, p.side);
    const std::uint64_t all_added = warmup_ledger.water_added + sample_ledger.water_added;
    const std::uint64_t all_removed = warmup_ledger.water_removed + sample_ledger.water_removed;
    const std::int64_t projected =
        static_cast<std::int64_t>(initial.water_mass) +
        static_cast<std::int64_t>(all_added) -
        static_cast<std::int64_t>(all_removed);
    if (projected < 0 || static_cast<std::uint64_t>(projected) != final.water_mass)
        throw std::runtime_error("closed Water ledger does not reconcile");

    if (p.scenario == "quiet") {
        if (positive_visits != 0 || sample_ledger.calls != 0)
            throw std::runtime_error("quiet anchor was not quiescent");
    } else {
        if (positive_visits < 231 || sample_ledger.calls != 128ULL * static_cast<std::uint64_t>(p.ticks))
            throw std::runtime_error("active anchor became vacuous");
    }
    const auto dispatch = mat003_world::dispatch_observations();
    if (!MAT003_TWIN_OBSERVERS && (dispatch.calls != 0 || dispatch.dispatched_tasks != 0 || dispatch.worker_tasks != 0))
        throw std::runtime_error("S2P observer-off binary retained correctness observer activity");

    if (!measured && (!tick_ns.empty() || !input_ns.empty()))
        throw std::runtime_error("qualification path emitted timing arrays");
    if (measured && (tick_ns.size() != static_cast<std::size_t>(p.ticks) ||
                     input_ns.size() != static_cast<std::size_t>(p.ticks)))
        throw std::runtime_error("measurement path lost timing samples");

    struct rusage usage{};
    if (getrusage(RUSAGE_SELF, &usage) != 0)
        throw std::runtime_error("getrusage failed");

    const auto startup_ns = measured
        ? static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(startup_end - startup_begin).count())
        : 0ULL;

    std::cout
        << "{\"status\":\"passed\",\"stage\":\"S2P-paired-performance\","
        << "\"observer\":" << MAT003_TWIN_OBSERVERS << ",\"dispatch_calls\":" << dispatch.calls << ",\"worker_tasks\":" << dispatch.worker_tasks << ",\"dispatched_tasks\":" << dispatch.dispatched_tasks << ","
        << "\"performance_qualification\":" << (measured ? "true" : "false") << ','
        << "\"formal_timing_admitted\":false,"
        << "\"mode\":\"" << p.mode << "\","
        << "\"arm_id\":\"" << MAT003_ARM_ID << "\","
        << "\"scenario\":\"" << p.scenario << "\","
        << "\"side\":" << p.side << ",\"workers_configured\":" << p.workers
        << ",\"seed\":" << p.seed << ",\"warmup_ticks\":" << p.warmup
        << ",\"sample_ticks\":" << p.ticks
        << ",\"completed_ticks\":" << world.completed_tick_index()
        << ",\"resident_cells\":" << static_cast<std::uint64_t>(p.side) * p.side
        << ",\"chunk_count\":" << world.chunk_count()
        << ",\"positive_visit_ticks\":" << positive_visits
        << ",\"warmup_input_calls\":" << warmup_ledger.calls
        << ",\"sample_input_calls\":" << sample_ledger.calls
        << ",\"warmup_water_added\":" << warmup_ledger.water_added
        << ",\"warmup_water_removed\":" << warmup_ledger.water_removed
        << ",\"sample_water_added\":" << sample_ledger.water_added
        << ",\"sample_water_removed\":" << sample_ledger.water_removed
        << ",\"initial_water_mass\":" << initial.water_mass
        << ",\"final_water_mass\":" << final.water_mass
        << ",\"content_hash\":" << world.content_hash()
        << ",\"state_hash\":" << world.state_hash()
        << ",\"cell_stride\":" << sizeof(mat003_world::Cell)
        << ",\"cell_alignment\":" << alignof(mat003_world::Cell)
        << ",\"epoch_bits\":" << MAT003_EPOCH_BITS
        << ",\"startup_ns\":" << startup_ns
        << ",\"peak_process_rss_bytes\":" << static_cast<std::uint64_t>(usage.ru_maxrss) * 1024ULL
        << ",\"summary\":{\"empty\":" << final.empty_cells
        << ",\"water\":" << final.water_cells
        << ",\"sand\":" << final.sand_cells
        << ",\"wall\":" << final.wall_cells
        << ",\"other\":" << final.other_cells
        << ",\"water_mass\":" << final.water_mass << "},"
        << "\"clear_ticks\":";
    json_array(clear_ticks);
    std::cout << ",\"clear_observations\":[";
    for (std::size_t i=0;i<clear_observations.size();++i) { if(i) std::cout << ","; const auto& v=clear_observations[i]; std::cout << "{\"tick\":" << v[0] << ",\"before\":" << v[1] << ",\"after\":" << v[2] << "}"; }
    std::cout << "]";
    std::cout << ",\"visits\":";
    json_array(visits);
    std::cout << ",\"phase_jobs\":";
    json_array(phase_jobs);
    std::cout << ",\"input_ns\":";
    json_array(input_ns);
    std::cout << ",\"tick_ns\":";
    json_array(tick_ns);
    std::cout << "}\n";
    return 0;
}
} // namespace

int main(int argc, char** argv) {
    try {
        return execute(arguments(argc, argv));
    } catch (const std::exception& error) {
        std::cerr << "MAT003 S2P fixture failed: " << error.what() << '\n';
        return 1;
    }
}
