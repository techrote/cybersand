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

// Cross-process bridge between the same-process event/interest fixture and
// independent native restart. Test-only whole-World CYPS; no selective save.
std::uint64_t continue_queued_event(World& world, std::uint32_t workers,
                                    std::uint32_t& observed) {
    const auto first = world.tick();
    observed = std::max(observed, first.worker_threads_observed);
    must(!world.has_failed() && first.deferred_events == 1,
         "pending cross-seam event was lost or replayed on first tick");
    must(world.stored_material(-1, 40) == Material::Fire &&
         world.stored_material(0, 40) == Material::Empty,
         "cross-seam native event outcome changed");
    for (int step = 0; step < 5; ++step) {
        if (step == 0 || step == 3) {
            world.set_simulation_region(step == 0
                ? RectI64{-64, 0, 128, 128}
                : RectI64{256, 0, 64, 64});
        }
        const auto tick = world.tick();
        observed = std::max(observed, tick.worker_threads_observed);
        must(!world.has_failed() && tick.deferred_events == 0,
             "cross-seam event replay or native quarantine after re-entry");
    }
    must(observed >= 1 && observed <= workers, "invalid native event worker count");
    return world.physical_state_hash();
}
int event_run(const std::string& mode, const std::string& snapshot,
              const std::string& receipt, std::uint32_t workers, int water) {
    must((workers == 1 || workers == 4) && (water == 17 || water == 19),
         "invalid event process cohort");
    const auto config = cfg(workers);
    if (mode == "emit-event" || mode == "emit-event-crash") {
        World world(config);
        const auto cells = payload();
        for (int i = 0; i < 8; ++i) {
            must(world.install_generated_chunk({static_cast<std::int64_t>(i-2), 0}, cells)
                 == ChunkInstallOutcome::Installed, "event native admission refused");
        }
        for (std::int64_t y = 36; y <= 44; ++y) {
            for (std::int64_t x = -4; x <= 3; ++x) {
                world.set(x, y, Material::Wall);
            }
        }
        must(world.stored_material(-1, 40) == Material::Wall &&
             world.stored_material(0, 40) == Material::Wall,
             "event seam setup lacks authoritative wall");
        // Distinct native CYPS revision 17/19, with the same pending event.
        // The physical Water tuple is outside the excluded event seam.
        must(world.set_cell_state(26, 30, Material::Water,
                                  static_cast<std::uint16_t>(water), 0),
             "event revision Water mutation refused");
        must(world.stored_state_a(26, 30) == water &&
             world.liquid_mass(26, 30) == static_cast<std::uint64_t>(water),
             "event revision Water tuple invalid");
        world.set_simulation_region(RectI64{256, 0, 64, 64});
        const auto before_queue = world.physical_state_hash();
        must(world.queue_explosion(-1, 40, 2, 255),
             "pending signed-seam explosion refused");
        const auto before = world.physical_state_hash();
        must(before != before_queue, "queued event not in physical identity");
        const auto bytes = world.save_physical_state();
        must(!bytes.empty() && bytes.size() < 16 * 1024 * 1024,
             "event native CYPS missing or oversized");
        write(snapshot, bytes);
        std::uint32_t observed = 0;
        const auto after = continue_queued_event(world, workers, observed);
        std::ofstream out(receipt, std::ios::trunc);
        must(static_cast<bool>(out), "event receipt open refused");
        out << "GEN006_EVENT_V1 " << workers << " " << water << " "
            << before << " " << after << " " << bytes.size()
            << " " << observed << "\n";
        out.flush();
        must(static_cast<bool>(out), "event receipt flush refused");
        out.close();
        must(!out.fail(), "event receipt close refused");
        std::cout << "GEN006_NATIVE_EVENT_JSON {\"phase\":\"emit\",\"workers\":"
                  << workers << ",\"water\":" << water
                  << ",\"observed\":" << observed
                  << ",\"pending_events\":1,\"executed_once\":true,\"bytes\":"
                  << bytes.size() << "}\n" << std::flush;
        if (mode == "emit-event-crash") std::_Exit(17);
        return 0;
    }
    must(mode == "check-event", "unknown native event mode");
    std::ifstream in(receipt);
    std::string marker;
    std::uint32_t expected_workers = 0, producer_observed = 0;
    int expected_water = 0;
    std::uint64_t before = 0, after = 0;
    std::size_t expected_size = 0;
    must(static_cast<bool>(in >> marker >> expected_workers >> expected_water >>
            before >> after >> expected_size >> producer_observed),
         "malformed event receipt");
    must(marker == "GEN006_EVENT_V1" && expected_workers == workers &&
         expected_water == water && expected_size > 0 &&
         producer_observed >= 1 && producer_observed <= workers,
         "cross-session event receipt identity refused");
    const auto bytes = read(snapshot);
    must(bytes.size() == expected_size, "event native length/receipt mismatch");
    auto restored = World::restore_physical_state(config, bytes);
    must(restored && restored->chunk_count() == 8 &&
         restored->physical_state_hash() == before,
         "independent process pending event restore diverged");
    must(restored->save_physical_state() == bytes,
         "independent process event CYPS canonical roundtrip changed bytes");
    must(restored->stored_state_a(26, 30) == water &&
         restored->liquid_mass(26, 30) == static_cast<std::uint64_t>(water),
         "independent process event Water state/quantity lost");
    std::uint32_t observed = 0;
    const auto continued = continue_queued_event(*restored, workers, observed);
    must(continued == after, "independent process event continuation diverged");
    std::cout << "GEN006_NATIVE_EVENT_JSON {\"phase\":\"check\",\"workers\":"
              << workers << ",\"water\":" << water
              << ",\"observed\":" << observed
              << ",\"pending_events\":1,\"executed_once\":true"
              << ",\"continuation_ticks\":6,\"interest_reentries\":1"
              << ",\"result\":\"PASS\"}\n";
    return 0;
}

}  // namespace
int main(int argc, char** argv) {
    try {
        must(argc == 6, "usage: probe emit|emit-crash|check SNAPSHOT RECEIPT WORKERS WATER");
        const std::string mode = argv[1];
        if (mode == "emit-event" || mode == "emit-event-crash" ||
            mode == "check-event") {
            return event_run(mode, argv[2], argv[3],
                             static_cast<std::uint32_t>(std::stoul(argv[4])),
                             std::stoi(argv[5]));
        }
        return run(argv[1], argv[2], argv[3],
                   static_cast<std::uint32_t>(std::stoul(argv[4])),
                   std::stoi(argv[5]));
    } catch (const std::exception& e) {
        std::cerr << "GEN006_NATIVE_RESTART_REFUSED: " << e.what() << "\n";
        return 13;
    }
}
