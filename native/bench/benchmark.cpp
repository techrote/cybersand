#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>

namespace {

[[nodiscard]] int parse_positive(const char* text, std::string_view name) {
    const auto value = std::strtol(text, nullptr, 10);
    if (value <= 0 || value > 1'000'000) throw std::invalid_argument(std::string(name) + " is invalid");
    return static_cast<int>(value);
}

[[nodiscard]] cybersand::SimulationBackend parse_backend(std::string_view text) {
    if (text == "serial") return cybersand::SimulationBackend::SerialInPlace;
    if (text == "phased") return cybersand::SimulationBackend::PhasedInPlace;
    if (text == "buffered") return cybersand::SimulationBackend::Buffered;
    throw std::invalid_argument("backend must be serial, phased, or buffered");
}

[[nodiscard]] std::string_view backend_name(cybersand::SimulationBackend backend) {
    switch (backend) {
        case cybersand::SimulationBackend::SerialInPlace: return "serial";
        case cybersand::SimulationBackend::PhasedInPlace: return "phased";
        case cybersand::SimulationBackend::Buffered: return "buffered";
    }
    return "invalid";
}

}  // namespace

int main(int argc, char** argv) {
    try {
        const int width = argc > 1 ? parse_positive(argv[1], "width") : 512;
        const int height = argc > 2 ? parse_positive(argv[2], "height") : 512;
        const int ticks = argc > 3 ? parse_positive(argv[3], "ticks") : 120;
        const int chunk_size = argc > 4 ? parse_positive(argv[4], "chunk size") : 128;
        const std::string_view scenario = argc > 5 ? argv[5] : "dense";
        const auto backend = parse_backend(argc > 6 ? std::string_view(argv[6]) : "phased");
        const int worker_threads = argc > 7 ? parse_positive(argv[7], "worker threads") : 1;
        const std::string_view allocation_mode = argc > 8 ? argv[8] : "preallocated";
        if (scenario != "dense" && scenario != "sparse") {
            throw std::invalid_argument("scenario must be dense or sparse");
        }
        if (allocation_mode != "preallocated" && allocation_mode != "lazy") {
            throw std::invalid_argument("allocation mode must be preallocated or lazy");
        }

        cybersand::WorldConfig config{};
        config.chunk_size = chunk_size;
        config.backend = backend;
        config.worker_threads = static_cast<std::uint32_t>(worker_threads);
        cybersand::World world(config);
        if (allocation_mode == "preallocated") {
            world.reserve_region({-chunk_size, -chunk_size,
                                  static_cast<std::int64_t>(width) + chunk_size * 2LL,
                                  static_cast<std::int64_t>(height) + chunk_size * 2LL});
        }
        if (scenario == "dense") {
            for (int x = 0; x < width; ++x) world.set(x, height - 1, cybersand::Material::Wall);
            for (int y = 0; y < height / 2; ++y) {
                for (int x = 0; x < width; ++x) {
                    const auto selector = (x * 17 + y * 31) % 13;
                    if (selector < 7) world.set(x, y, cybersand::Material::Sand);
                    else if (selector < 10) world.set(x, y, cybersand::Material::Water);
                    else if (selector == 10) world.set(x, y, cybersand::Material::Smoke);
                }
            }
        } else {
            for (int y = 0; y < height; y += chunk_size) {
                for (int x = 0; x < width; x += chunk_size) {
                    world.set(x, y, cybersand::Material::Wall);
                }
            }
            for (int warmup = 0; warmup < 4; ++warmup) (void)world.tick();

            const int centre_x = width / 2;
            const int centre_y = height / 2;
            for (int x = centre_x - 64; x <= centre_x + 64; ++x) {
                world.set(x, centre_y + 80, cybersand::Material::Wall);
            }
            for (int y = centre_y - 64; y < centre_y; ++y) {
                for (int x = centre_x - 64; x < centre_x + 64; ++x) {
                    const auto selector = (x * 17 + y * 31) % 13;
                    if (selector < 7) world.set(x, y, cybersand::Material::Sand);
                    else if (selector < 10) world.set(x, y, cybersand::Material::Water);
                    else if (selector == 10) world.set(x, y, cybersand::Material::Smoke);
                }
            }
        }
        (void)world.take_dirty_chunks();

        std::uint64_t visited = 0;
        std::uint64_t moved = 0;
        std::uint64_t scheduled_cores = 0;
        std::uint64_t chunk_allocations = 0;
        std::uint64_t temperature_field_allocations = 0;
        std::uint64_t deferred_events = 0;
        std::array<std::uint64_t, cybersand::SchedulerGeometry::kPhaseCount> phase_jobs{};
        const auto start = std::chrono::steady_clock::now();
        for (int tick = 0; tick < ticks; ++tick) {
            const auto stats = world.tick();
            visited += stats.visited_cells;
            moved += stats.moved_cells;
            scheduled_cores += stats.scheduled_cores;
            chunk_allocations += stats.chunk_allocations;
            temperature_field_allocations += stats.temperature_field_allocations;
            deferred_events += stats.deferred_events;
            for (std::size_t phase = 0; phase < phase_jobs.size(); ++phase) {
                phase_jobs[phase] += stats.phase_jobs[phase];
            }
        }
        const auto finish = std::chrono::steady_clock::now();
        const auto milliseconds = std::chrono::duration<double, std::milli>(finish - start).count();

        std::cout << "Cyber Sand native benchmark\n"
                  << "scenario: " << scenario << '\n'
                  << "backend: " << backend_name(backend) << '\n'
                  << "workers: " << worker_threads << '\n'
                  << "allocation mode: " << allocation_mode << '\n'
                  << "region: " << width << 'x' << height << " cells\n"
                  << "chunk: " << chunk_size << 'x' << chunk_size << " cells\n"
                  << "ticks: " << ticks << '\n'
                  << "allocated chunks: " << world.chunk_count() << '\n'
                  << "resident cell payload: " << world.resident_cell_bytes() << " bytes\n"
                  << "elapsed: " << std::fixed << std::setprecision(2) << milliseconds << " ms\n"
                  << "mean tick: " << milliseconds / ticks << " ms\n"
                  << "visited cells/tick: " << visited / static_cast<std::uint64_t>(ticks) << '\n'
                  << "moves/tick: " << moved / static_cast<std::uint64_t>(ticks) << '\n'
                  << "scheduling cores/tick: "
                  << scheduled_cores / static_cast<std::uint64_t>(ticks) << '\n'
                  << "phase jobs/tick: ";
        for (std::size_t phase = 0; phase < phase_jobs.size(); ++phase) {
            if (phase != 0) std::cout << ',';
            std::cout << phase_jobs[phase] / static_cast<std::uint64_t>(ticks);
        }
        std::cout << '\n'
                  << "tick-time chunk allocations: " << chunk_allocations << '\n'
                  << "tick-time temperature allocations: "
                  << temperature_field_allocations << '\n'
                  << "committed deferred events: " << deferred_events << '\n'
                  << "final active chunks: " << world.active_chunk_count() << '\n'
                  << "state hash: 0x" << std::hex << world.state_hash() << '\n'
                  << "content hash: 0x" << world.content_hash() << std::dec << '\n';
    } catch (const std::exception& error) {
        std::cerr << "benchmark error: " << error.what() << '\n';
        return 1;
    }
    return 0;
}
