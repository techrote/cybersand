// Actual Current native World. No epoch/storage replacement and no restore implementation.
#include "cybersand/world.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>

unsigned checks = 0;
void require(bool value, const char* text) {
    ++checks;
    if (!value) throw std::runtime_error(text);
}

int main(int argc, char** argv) {
    try {
        if (argc != 2) throw std::runtime_error("registered configuration required");
        const std::string mode = argv[1];
        require(mode == "serial-1" || mode == "phased-1" || mode == "phased-4", "registered mode");
        cybersand::WorldConfig config;
        config.backend = mode == "serial-1" ? cybersand::SimulationBackend::SerialInPlace : cybersand::SimulationBackend::PhasedInPlace;
        config.worker_threads = mode == "phased-4" ? 4 : 1;
        config.parallel_job_threshold = 1;
        config.maximum_chunk_count = config.active_chunk_capacity = 64;
        config.initial_chunk_reserve = 8;
        config.active_core_capacity = 256;
        cybersand::World world(config);
        for (int x = 48; x < 80; ++x) {
            world.set(x, 104, cybersand::Material::Wall);
            for (int y = 100; y < 104; ++y) world.set(x, y, cybersand::Material::Sand);
        }
        constexpr std::array<unsigned, 9> checkpoints{1,2,254,255,256,257,510,511,512};
        bool recovery_pending = false;
        unsigned observations = 0, recoveries = 0;
        std::uint64_t scheduled = 0;
        std::cout << "{\"status\":\"passed\",\"timing\":false,\"mode\":\"" << mode << "\",\"observations\":[";
        for (unsigned tick = 1; tick <= 513; ++tick) {
            const auto stats = world.tick(); scheduled += stats.scheduled_cores;
            require(!world.has_failed() && world.tick_index() == tick && world.completed_tick_index() == tick, "healthy completed native clock");
            if (recovery_pending) {
                require(world.granular_support_at(64,100), "following tick restores stable support");
                ++recoveries; recovery_pending = false;
            }
            if (std::find(checkpoints.begin(), checkpoints.end(), tick) == checkpoints.end()) continue;
            require(world.granular_support_at(64,100), "pre-edit stable support");
            const auto a = world.stored_state_a(64,100);
            const auto b = world.stored_state_b(64,100);
            const auto hash = world.state_hash();
            const auto content = world.content_hash();
            require(!world.set_cell_state(64,100,cybersand::Material::Sand,a,b), "same value is a true noop");
            require(world.state_hash() == hash && world.granular_support_at(64,100), "noop preserves hash and support");
            require(world.set_cell_state(64,100,cybersand::Material::Sand,a == 0 ? 1 : 0,b), "external state edit accepted");
            require(!world.granular_support_at(64,100), "external edit suppresses immediate support");
            require(world.set_cell_state(64,100,cybersand::Material::Sand,a,b), "content restoration accepted");
            require(world.content_hash() == content, "roundtrip restores exact logical content");
            require(!world.granular_support_at(64,100), "content roundtrip does not erase touch predicate");
            require(world.tick_index() == tick && world.completed_tick_index() == tick, "no native tick during owner edits");
            if (observations++) std::cout << ',';
            std::cout << "{\"completed_tick\":" << tick << ",\"before_support\":true,\"noop_hash_unchanged\":true,\"after_edit_support\":false,\"restored_content_equal\":true,\"restored_support\":false,\"native_clock_unchanged\":true}";
            recovery_pending = true;
        }
        require(observations == 9 && recoveries == 9 && !recovery_pending, "complete checkpoint/recovery matrix");
        std::cout << "],\"native_ticks\":513,\"recoveries\":" << recoveries << ",\"checks\":" << checks
                  << ",\"scheduled_cores\":" << scheduled << ",\"configured_workers\":" << config.worker_threads << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n'; return 1;
    }
}
