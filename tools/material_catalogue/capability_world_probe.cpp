// Exact-source #353-B capability cutover: independent executable save exchange.
// Uses the unchanged native World, policies and quantity ledger; no fixture law.
#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/sha256.hpp"

#include <algorithm>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
WorldConfig configuration(int family, std::uint32_t workers) {
    WorldConfig config;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    config.maximum_chunk_count = 128;
    config.active_chunk_capacity = 128;
    config.active_core_capacity = 512;
    auto request = LiquidSolverPolicy::default_request();
    request[21] = family;
    if (family == 4) {
        request[request.size() - 2U] = 1;
        request.insert(request.end() - 1, {4, 2, 1, 1});
        config.maximum_rule_radius = 3;
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    require(decoded.accepted(), "source-bound liquid policy was refused");
    config.liquid_solver_policy = *decoded.policy;
    return config;
}
void rectangle(World& world, int x, int y, int width, int height, Material material) {
    for (int dy = 0; dy < height; ++dy)
        for (int dx = 0; dx < width; ++dx) world.set(x + dx, y + dy, material);
}
void populate(World& world) {
    // All allocated valid materials occupy independent small closed chambers.
    // Several scheduling cores have work in each phase, exposing real workers.
    for (unsigned id = 1; id < 132; ++id) {
        if (id == 10) continue;
        const int x = 2 + static_cast<int>(id % 16U) * 32;
        const int y = 2 + static_cast<int>(id / 16U) * 24;
        rectangle(world, x, y, 24, 1, Material::Wall);
        rectangle(world, x, y + 19, 24, 1, Material::Wall);
        rectangle(world, x, y, 1, 20, Material::Wall);
        rectangle(world, x + 23, y, 1, 20, Material::Wall);
        rectangle(world, x + 7, y + 4, 4, 3, static_cast<Material>(id));
        rectangle(world, x + 2, y + 14, 20, 5,
                  id % 2 == 0 ? Material::Water : Material::Sand);
    }
    world.set_simulation_region(RectI64{0, 0, 512, 256});
}
void balanced(const World& world) {
    const auto ledger = world.quantity_ledger();
    std::uint64_t produced = ledger.baseline_water, consumed = 0;
    for (const auto flow : ledger.kinds) {
        produced += flow.produced;
        consumed += flow.consumed;
    }
    require(produced >= consumed, "quantity ledger underflow");
    require(produced - consumed == ledger.water_visible + ledger.water_overfill + ledger.water_ballistic,
            "global Water quantity balance failed");
}
void advance(World& world, std::uint64_t end, std::uint32_t& observed) {
    while (world.completed_tick_index() < end) {
        const auto stats = world.tick();
        observed = std::max(observed, stats.worker_threads_observed);
        balanced(world);
    }
    require(world.completed_tick_index() == end && !world.has_failed(), "native tick window incomplete");
}
std::string stored_cells(const World& world) {
    Sha256 hash;
    for (std::int64_t y = 0; y < 256; ++y) {
        for (std::int64_t x = 0; x < 512; ++x) {
            const auto material = world.stored_material(x, y);
            const auto id = static_cast<std::uint8_t>(material);
            require(id < 132 && id != 10, "unallocated identity stored by native World");
            for (const std::uint64_t value : {
                     static_cast<std::uint64_t>(id),
                     static_cast<std::uint64_t>(world.stored_state_a(x, y)),
                     static_cast<std::uint64_t>(world.stored_state_b(x, y)),
                     static_cast<std::uint64_t>(world.stored_temperature(x, y))}) {
                std::array<std::uint8_t, 8> bytes{};
                for (unsigned index = 0; index < 8; ++index)
                    bytes[index] = static_cast<std::uint8_t>(value >> (8U * index));
                hash.update(bytes);
            }
        }
    }
    return Sha256::hex(hash.finish());
}
void write_file(const std::string& path, const std::vector<std::uint8_t>& bytes) {
    std::ofstream stream(path, std::ios::binary);
    stream.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    stream.close();
    require(static_cast<bool>(stream), "checkpoint write failed");
}
std::vector<std::uint8_t> read_file(const std::string& path) {
    std::ifstream stream(path, std::ios::binary);
    require(static_cast<bool>(stream), "checkpoint read failed");
    return {std::istreambuf_iterator<char>(stream), {}};
}
}  // namespace

int main(int argc, char** argv) {
    try {
        require(argc == 5, "expected create|restore family workers checkpoint");
        const std::string mode(argv[1]);
        const int family = std::stoi(argv[2]);
        const auto workers = static_cast<std::uint32_t>(std::stoul(argv[3]));
        require(family >= 1 && family <= 4 && (workers == 1 || workers == 4), "unsupported execution arguments");
        const auto config = configuration(family, workers);
        std::unique_ptr<World> world;
        std::uint32_t observed = 0;
        if (mode == "create") {
            world = std::make_unique<World>(config);
            populate(*world);
            advance(*world, 24, observed);
            write_file(argv[4], world->save_physical_state());
        } else if (mode == "restore") {
            world = World::restore_physical_state(config, read_file(argv[4]));
        } else {
            throw std::runtime_error("unsupported mode");
        }
        require(world->completed_tick_index() == 24, "checkpoint tick mismatch");
        const auto checkpoint_physical = world->physical_state_hash();
        const auto checkpoint_cells = stored_cells(*world);
        advance(*world, 48, observed);
        require(workers == 1 || observed > 1, "four-worker request did not execute multiple native workers");
        const auto saved = world->save_physical_state();
        std::cout << "{\"family\":" << family << ",\"workers\":" << workers
                  << ",\"observed_workers\":" << observed
                  << ",\"checkpoint_tick\":24,\"final_tick\":48,\"checkpoint_physical_hash\":\""
                  << checkpoint_physical << "\",\"checkpoint_cells_sha256\":\"" << checkpoint_cells
                  << "\",\"final_physical_hash\":\"" << world->physical_state_hash()
                  << "\",\"final_cells_sha256\":\"" << stored_cells(*world)
                  << "\",\"final_save_sha256\":\"" << Sha256::hex(Sha256::of(saved))
                  << "\",\"policy_hash\":\"" << world->liquid_solver_policy().policy_hash_hex()
                  << "\",\"water_visible\":" << world->quantity_ledger().water_visible
                  << ",\"water_overfill\":" << world->quantity_ledger().water_overfill
                  << ",\"quantity_balanced\":true,\"status\":\"PASS\"}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
