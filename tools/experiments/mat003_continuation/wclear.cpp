// Untimed qualifier only. probe.hpp is a receipted prefix of the accepted S1
// independent semantic observer plus the continuation's checked stamp rebase.
#include "probe.hpp"
#include <chrono>
#include <cstdlib>
#ifdef __linux__
#include <sys/resource.h>
#endif

int main(int argc, char** argv) {
    try {
        fixture::require(argc >= 6 && argc <= 8, "usage: wclear side workers scene event|ordinary output [setup-ticks] [--measure]");
        const bool measure = argc == 8 && std::string(argv[7]) == "--measure";
        fixture::require(argc != 8 || measure, "unknown mode");
        if (measure) {
            fixture::require(MAT003_TWIN_OBSERVERS == 0, "observed twins cannot be timed");
            const char* authority=std::getenv("MAT003_WCLEAR_EXECUTION_AUTHORITY");
            fixture::require(authority != nullptr && std::string(authority).size()==64,
                             "HELD: admitted collector execution authority is required");
        }
        using Clock=std::chrono::steady_clock;
        using Time=Clock::time_point;
        const auto now=[&]() { return measure ? Clock::now() : Time{}; };
        const auto ns=[](Time a,Time b) { return std::chrono::duration_cast<std::chrono::nanoseconds>(b-a).count(); };
        const auto startup_begin=now();
        const unsigned setup_ticks = argc >= 7 ? static_cast<unsigned>(std::stoul(argv[6])) : 255;
        const unsigned side = static_cast<unsigned>(std::stoul(argv[1]));
        const unsigned workers = static_cast<unsigned>(std::stoul(argv[2]));
        const bool active = std::string(argv[3]) == "active-window-excluded";
        const bool event = std::string(argv[4]) == "event";
        const std::filesystem::path out(argv[5]);
        fixture::require(!std::filesystem::exists(out), "append-only evidence output exists");
        std::filesystem::create_directories(out);
        using namespace cybersand;
        WorldConfig config;
        config.worker_threads = workers; config.parallel_job_threshold = 1;
        config.physics_diagnostics.enabled = true;
        World world(config);
        world.reserve_region({0, 0, side, side});
        world.reserve_temperature_region({0, 0, 128, 128});
        world.set_simulation_region(RectI64{0, 0, side / 2, side});
        // One wall per storage chunk retains a nonempty sleeping population;
        // half the resident chunks are outside the interest region.
        for (unsigned y = 0; y < side; y += 128)
            for (unsigned x = 0; x < side; x += 128) world.set(x + 3, y + 3, Material::Wall);
        world.set(side - 8, 8, Material::Sand); // excluded granular sentinel
        const std::vector<fixture::Point> support{{side - 8, 8}, {20, 20}};
        const auto startup_ns=ns(startup_begin,now());
        std::int64_t input_ns=0;
        const auto setup_begin=now();
        TickStats setup_stats;
        for (unsigned t = 1; t <= setup_ticks; ++t) {
            const auto input_begin=now();
            if (active && t >= setup_ticks - 119) {
                // Multiple disjoint phased cores; controlled external input is
                // finished before either matched event/ordinary tick.
                for (unsigned x = 16; x < side / 2; x += 64) {
                    world.set(x, 8, Material::Water); world.set(x + 8, 8, Material::Sand);
                }
            }
            input_ns+=ns(input_begin,now());
            const auto stats = world.tick();
            setup_stats = stats;
            fixture::require(stats.tick == t && world.completed_tick_index() == t, "setup tick failed");
        }
        const auto setup_ns=ns(setup_begin,now());
        const auto before = PrecisionProbe::snapshot(world, setup_stats, support);
        const auto limit = (std::uint64_t{1} << MAT003_EPOCH_BITS) - 1;
        const bool naturally_reached = PrecisionProbe::epoch(world) == limit;
        const auto stamps = PrecisionProbe::prepare_clear(world, event ? limit : 128);
        const auto epoch_before = PrecisionProbe::epoch(world);
        const auto prepared = PrecisionProbe::snapshot(world, setup_stats, support);
        fixture::require(before.bytes == prepared.bytes, "stamp preparation changed semantic/support/scheduling state");
        const auto write = [&](const char* name, const fixture::Bytes& bytes) {
            std::ofstream f(out / name, std::ios::binary);
            f.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
            fixture::require(bool(f), "semantic record write failed");
        };
        write("pre.bin", prepared.bytes);
        mat003_world::reset_dispatch_observations();
        mat003_world::observed_clears=0;
        mat003_world::observed_clear_cells=0;
        const auto event_begin=now();
        const auto stats = world.tick(); // Real production clear path; clocks only in admitted measure mode.
        const auto tick_ns=ns(event_begin,now());
        const auto epoch_after=PrecisionProbe::epoch(world);
        const auto event_dispatch = mat003_world::dispatch_observations();
        fixture::require(world.completed_tick_index() == setup_ticks + 1 && stats.tick == setup_ticks + 1, "event tick not completed");
        fixture::require(PrecisionProbe::epoch(world) == (event ? 1U : 129U), "event counter mismatch");
        const auto after = PrecisionProbe::snapshot(world, stats, support);
        fixture::require(before.water == after.water, "closed event changed Water mass");
        fixture::require(before.sand == after.sand, "closed event changed Sand count");
#if MAT003_TWIN_OBSERVERS
        fixture::require(mat003_world::observed_clears == (event ? 1U : 0U), "actual clear count mismatch");
        fixture::require(mat003_world::observed_clear_cells == (event ? stamps : 0U), "actual clear traversal count mismatch");
#endif
        write("post.bin", after.bytes);
        // Re-enter excluded residents and compare four further ticks. This
        // exercises support and stamp consumers after the event, not only an
        // inert stamp array. Keep clock/RNG schedules equal across widths.
        world.set_simulation_region(RectI64{0, 0, side, side});
        for (unsigned i = 0; i < 4; ++i) {
            const auto step = world.tick();
            const auto record = PrecisionProbe::snapshot(world, step, support);
            write(("reentry-" + std::to_string(i) + ".bin").c_str(), record.bytes);
        }
        const auto dispatch = mat003_world::dispatch_observations();
        std::cout << "{\"epoch_bits\":" << MAT003_EPOCH_BITS
                  << ",\"side\":" << side << ",\"workers\":" << workers
                  << ",\"event\":" << (event ? "true" : "false")
                  << ",\"natural_event\":" << (event && naturally_reached ? "true" : "false")
                  << ",\"prepared_event\":" << (event && !naturally_reached ? "true" : "false")
                  << ",\"resident_cells\":" << stamps << ",\"stride\":" << PrecisionProbe::stride()
                  << ",\"alignment\":" << PrecisionProbe::alignment()
                  << ",\"epoch_before\":" << static_cast<std::uint64_t>(epoch_before)
                  << ",\"epoch_after\":" << static_cast<std::uint64_t>(epoch_after)
                  << ",\"clear_count\":" << (epoch_after < epoch_before ? 1 : 0)
                  << ",\"completed_event_tick\":" << setup_ticks + 1 << ",\"visited\":" << stats.visited_cells
                  << ",\"phase_jobs\":[" << stats.phase_jobs[0] << ',' << stats.phase_jobs[1] << ',' << stats.phase_jobs[2] << ',' << stats.phase_jobs[3]
                  << "],\"worker_tasks\":" << dispatch.worker_tasks
                  << ",\"event_worker_tasks\":" << event_dispatch.worker_tasks
                  << ",\"observed_clear_count\":" << mat003_world::observed_clears
                  << ",\"observed_clear_cells\":" << mat003_world::observed_clear_cells
                  << ",\"qualification_only\":" << (measure ? "false" : "true")
                  << ",\"assertions\":" << fixture::assertions << "}\n";
        if (measure) {
            // Separate line prevents untimed output from containing timing
            // observations. The admitted collector retains both complete lines.
            std::int64_t peak_rss=0;
#ifdef __linux__
            rusage usage{};
            fixture::require(getrusage(RUSAGE_SELF,&usage)==0,"RSS query failed");
            peak_rss=usage.ru_maxrss;
#endif
            std::cout << "{\"measurement\":true,\"tick_ns\":" << tick_ns
                      << ",\"startup_ns\":" << startup_ns << ",\"setup_ns\":" << setup_ns
                      << ",\"input_ns\":" << input_ns << ",\"peak_rss_kib\":" << peak_rss << "}\n";
        }
        return 0;
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
