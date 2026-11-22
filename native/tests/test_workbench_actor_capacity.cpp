#include "cybersand/world.hpp"
#include <chrono>
#include <iostream>
#include <stdexcept>

namespace {
void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}

void exercise(std::uint16_t count, std::uint32_t workers) {
    cybersand::WorldConfig config;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    cybersand::World world(config);
    world.reserve_region({0, 0, 512, 512});
    world.configure_transient_obstacles({0, 0, 512, 512}, true);
    for (std::uint16_t id = 1; id <= count; ++id) {
        const auto x = 2 + ((id - 1) % 64) * 8;
        const auto y = 2 + ((id - 1) / 64) * 8;
        world.set(x, y, cybersand::Material::Sand);
        world.set(x - 1, y, cybersand::Material::Wall);
        world.set(x + 1, y, cybersand::Material::Wall);
        for (int dx = -1; dx <= 1; ++dx)
            require(world.set_transient_obstacle(x + dx, y + 1, id), "admitted high-count mask refused");
        require(world.transient_obstacle_at(x, y + 1) == id, "body identity truncated");
    }
    const auto before = world.content_hash();
    const auto start = std::chrono::steady_clock::now();
    for (int tick = 0; tick < 3; ++tick) (void)world.tick();
    const auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now() - start).count();
    require(world.completed_tick_index() == 3, "native progression stalled");
    for (std::uint16_t id = 1; id <= count; ++id) {
        require(world.transient_contact_count(id) > 0, "actor lost independent native contact routing");
        require(world.transient_contact_impulse_y(id) > 0, "actor lost native contact impulse");
    }
    require(world.content_hash() == before, "mask mutated authoritative material");
    require(!world.set_transient_obstacle(0, 0, 0), "zero owner admitted");
    require(!world.set_transient_obstacle(0, 0, cybersand::World::kMaximumTransientBodies + 1U),
            "out-of-allocation owner admitted");
    world.clear_transient_obstacles();
    for (std::uint16_t id = 1; id <= count; ++id)
        require(world.transient_contact_count(id) == 0, "retired actor retained contacts");
    require(world.set_transient_obstacle(0, 0, cybersand::World::kMaximumTransientBodies), "highest slot refused");
    require(world.transient_obstacle_at(0, 0) == cybersand::World::kMaximumTransientBodies, "highest slot truncated");
    world.clear_transient_obstacles();
    require(world.transient_obstacle_at(0, 0) == 0, "highest slot leaked on teardown");
    std::cout << "{\"registered_identities\":" << count << ",\"native_proxies\":" << count
              << ",\"workers\":" << workers << ",\"native_ticks\":3,\"elapsed_usec\":" << elapsed
              << ",\"status\":\"pass\"}\n";
}
}

int main() {
    try {
        for (const auto count : {16, 32, 64, 128, 256, 512, 4096})
            for (const auto workers : {1U, 4U}) exercise(static_cast<std::uint16_t>(count), workers);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
    return 0;
}
