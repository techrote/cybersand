// GEN-006 #194: independent native CYPS process restart / prepublication crash.
// EXPERIMENT ONLY: whole World, no selective eviction or admitted durable codec.
#include "cybersand/world.hpp"
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
namespace {
using namespace cybersand;
constexpr std::int32_t side = 128;
void must(bool yes, const char* msg) { if (!yes) throw std::runtime_error(msg); }
WorldConfig cfg(std::uint32_t workers) {
    WorldConfig c{};
    c.chunk_size = side;
    c.backend = SimulationBackend::PhasedInPlace;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.initial_chunk_reserve = 16;
    c.maximum_chunk_count = 16;
    c.active_chunk_capacity = 128;
    c.active_core_capacity = 2048;
    c.deferred_event_capacity = 128;
    return c;
}
std::vector<Material> payload() {
    std::vector<Material> cells(static_cast<std::size_t>(side * side), Material::Empty);
    for (int cy : {30, 94}) for (int cx : {30, 94}) {
        for (int x = cx - 4; x <= cx + 4; ++x) {
            cells[static_cast<std::size_t>((cy + 4) * side + x)] = Material::Wall;
            cells[static_cast<std::size_t>((cy - 4) * side + x)] = Material::Wall;
        }
        for (int y = cy - 4; y <= cy + 4; ++y) {
            cells[static_cast<std::size_t>(y * side + cx - 4)] = Material::Wall;
            cells[static_cast<std::size_t>(y * side + cx + 4)] = Material::Wall;
        }
        cells[static_cast<std::size_t>(cy * side + cx)] = Material::Water;
        cells[static_cast<std::size_t>((cy - 1) * side + cx)] = Material::Sand;
    }
    return cells;
}
void write(const std::string& name, const std::vector<std::uint8_t>& data) {
    std::ofstream f(name, std::ios::binary | std::ios::trunc);
    must(static_cast<bool>(f), "open-write refused");
    f.write(reinterpret_cast<const char*>(data.data()),
            static_cast<std::streamsize>(data.size()));
    f.flush();
    must(static_cast<bool>(f), "write/flush refused");
    f.close();
    must(!f.fail(), "close refused");
}
std::vector<std::uint8_t> read(const std::string& name) {
    std::ifstream f(name, std::ios::binary | std::ios::ate);
    must(static_cast<bool>(f), "open-read refused");
    const auto end = f.tellg();
    must(end > 0 && end <= 16 * 1024 * 1024, "invalid native payload length");
    f.seekg(0);
    std::vector<std::uint8_t> out(static_cast<std::size_t>(end));
    f.read(reinterpret_cast<char*>(out.data()), static_cast<std::streamsize>(end));
    must(f.gcount() == end, "short read");
    return out;
}
int run(const std::string& mode, const std::string& snapshot,
        const std::string& receipt, std::uint32_t workers, int water) {
    must((workers == 1 || workers == 4) && (water == 17 || water == 19),
         "invalid bounded cohort");
    const auto config = cfg(workers);
    if (mode == "emit" || mode == "emit-crash") {
        World world(config);
        const auto cells = payload();
        for (int i = 0; i < 8; ++i) {
            const ChunkCoord coord{static_cast<std::int64_t>(i * 2 - 2), 0};
            must(world.install_generated_chunk(coord, cells) ==
                 ChunkInstallOutcome::Installed, "fresh installation failed");
        }
        must(world.chunk_count() == 8, "resident count mismatch");
        std::uint32_t observed = 0;
        for (int i = 0; i < 2; ++i) {
            const auto stat = world.tick();
            must(!world.has_failed(), "producer native tick failed");
            observed = std::max(observed, stat.worker_threads_observed);
        }
        must(observed >= 1, "no participating native worker");
        must(world.stored_material(-230, 30) == Material::Wall &&
             world.stored_material(26, 30) == Material::Wall,
             "signed native baseline mismatch");
        must(world.set_cell_state(-230, 30, Material::Empty, 0, 0),
             "native tombstone mutation refused");
        must(world.set_cell_state(26, 30, Material::Water,
                                  static_cast<std::uint16_t>(water), 0),
             "native Water mutation refused");
        must(world.stored_state_a(26, 30) == water &&
             world.liquid_mass(26, 30) == static_cast<std::uint64_t>(water),
             "native Water state/quantity mismatch");
        const auto before = world.physical_state_hash();
        auto bytes = world.save_physical_state();
        must(!bytes.empty() && bytes.size() < 16 * 1024 * 1024,
             "unbounded/absent native checkpoint");
        write(snapshot, bytes);
        for (int i = 0; i < 3; ++i) {
            (void)world.tick();
            must(!world.has_failed(), "producer continuation quarantined");
        }
        const auto after = world.physical_state_hash();
        std::ofstream r(receipt, std::ios::trunc);
        must(static_cast<bool>(r), "receipt open failed");
        r << workers << " " << water << " " << before << " " << after << " "
          << bytes.size() << " " << observed << "\n";
        r.flush();
        must(static_cast<bool>(r), "receipt write failed");
        r.close();
        must(!r.fail(), "receipt close failed");
        std::cout << "GEN006_NATIVE_RESTART_JSON {\"phase\":\"emit\",\"workers\":"
                  << workers << ",\"observed\":" << observed
                  << ",\"quantity\":" << water
                  << ",\"bytes\":" << bytes.size() << "}\n" << std::flush;
        if (mode == "emit-crash") std::_Exit(17);
        return 0;
    }
    must(mode == "check", "unknown mode");
    std::ifstream r(receipt);
    std::uint32_t expected_workers = 0, observed = 0;
    int expected_water = 0;
    std::uint64_t before = 0, after = 0;
    std::size_t expected_size = 0;
    must(static_cast<bool>(r >> expected_workers >> expected_water >>
            before >> after >> expected_size >> observed),
         "malformed receipt");
    must(expected_workers == workers && expected_water == water &&
         expected_size > 0 && observed >= 1, "receipt identity mismatch");
    auto bytes = read(snapshot);
    must(bytes.size() == expected_size, "native length/receipt mismatch");
    auto restored = World::restore_physical_state(config, bytes);
    must(restored && restored->chunk_count() == 8 &&
         restored->physical_state_hash() == before, "native restore identity mismatch");
    must(restored->stored_material(-230, 30) == Material::Empty &&
         restored->stored_material(26, 30) == Material::Water &&
         restored->stored_state_a(26, 30) == water &&
         restored->liquid_mass(26, 30) == static_cast<std::uint64_t>(water),
         "restored native tombstone/Water tuple mismatch");
    for (int i = 0; i < 3; ++i) {
        (void)restored->tick();
        must(!restored->has_failed(), "restored World quarantined");
    }
    must(restored->physical_state_hash() == after,
         "independent process fixed-tick continuation diverged");
    std::cout << "GEN006_NATIVE_RESTART_JSON {\"phase\":\"check\",\"workers\":"
              << workers << ",\"quantity\":" << water
              << ",\"continuation_ticks\":3,\"result\":\"PASS\"}\n";
    return 0;
}
}  // namespace
int main(int argc, char** argv) {
    try {
        must(argc == 6, "usage: probe emit|emit-crash|check SNAPSHOT RECEIPT WORKERS WATER");
        return run(argv[1], argv[2], argv[3],
                   static_cast<std::uint32_t>(std::stoul(argv[4])),
                   std::stoi(argv[5]));
    } catch (const std::exception& e) {
        std::cerr << "GEN006_NATIVE_RESTART_REFUSED: " << e.what() << "\n";
        return 13;
    }
}
