// Build this same probe against accepted main and the candidate's native sources.
// No workbench/contact feature is enabled. Compare stdout and the complete CYPS
// stream byte-for-byte; this bounded fixture is not a universal equivalence proof.
#include "cybersand/world.hpp"
#include <fstream>
#include <iostream>
#include <span>
#include <stdexcept>
using namespace cybersand;

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::ofstream out(argv[1], std::ios::binary);
    for (unsigned family : {1U, 3U}) for (unsigned workers : {1U, 6U}) {
        auto words = LiquidSolverPolicy::default_request();
        words[21] = static_cast<int>(family); // Water FreeMass / PressureFlow reference.
        auto policy = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        if (!policy.accepted()) throw std::runtime_error("policy");
        WorldConfig config;
        config.liquid_solver_policy = *policy.policy;
        config.worker_threads = workers;
        config.chunk_size = config.scheduling_core_size = 16;
        config.activity_block_size = 8;
        config.maximum_chunk_count = config.active_chunk_capacity = config.active_core_capacity = 256;
        config.parallel_job_threshold = 2;
        World world(config);
        world.configure_transient_obstacles({-96, -64, 256, 128});
        const Material powders[] = {Material::Sand, Material::Dust, Material::Rust, Material::Coal};
        const Material liquids[] = {Material::Water, Material::Oil, Material::Brine, Material::Mercury};
        for (int index = 0; index < 4; ++index) {
            const int x = -80 + 48 * index;
            for (int dx = 0; dx < 30; ++dx) world.set(x + dx, 26, Material::Wall);
            for (int y = -28; y < 26; ++y) {
                world.set(x, y, Material::Wall);
                world.set(x + 29, y, Material::Wall);
            }
            for (int y = -24; y < -12; ++y) for (int dx = 3; dx < 15; ++dx)
                world.set(x + dx, y, powders[index]);
            for (int y = 9; y < 25; ++y) for (int dx = 1; dx < 28; ++dx)
                world.set(x + dx, y, liquids[index]);
        }
        for (int tick = 0; tick < 48; ++tick) {
            if (tick == 8 || tick == 18) {
                world.clear_transient_obstacles();
                for (int x = -72; x < -63; ++x)
                    if (!world.set_transient_obstacle(x + (tick == 18 ? 4 : 0), 3, 1))
                        throw std::runtime_error("mask admission");
            }
            if (tick == 26) world.clear_transient_obstacles();
            if (tick == 32) for (int x = 68; x < 75; ++x) world.set(x, 26, Material::Empty);
            const auto stats = world.tick();
            const auto bytes = world.save_physical_state();
            const auto size = static_cast<std::uint64_t>(bytes.size());
            out.write(reinterpret_cast<const char*>(&size), sizeof(size));
            out.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
            std::cout << family << ' ' << workers << ' ' << tick << ' ' << world.physical_state_hash()
                      << ' ' << size << ' ' << stats.visited_cells << ' ' << stats.active_blocks_after
                      << ' ' << world.transient_contact_count(1) << ' ' << world.transient_contact_impulse_x(1)
                      << ' ' << world.transient_contact_impulse_y(1) << '\n';
        }
    }
    return out ? 0 : 3;
}
