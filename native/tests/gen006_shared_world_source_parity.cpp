// GEN-006 independent implementation-support native acceptance.
// Compiles WITHOUT GEN006_TEST_RELEASE against the pinned accepted-main
// World, and WITH it against the #512 in-place chunk release candidate.
// This is NOT a production streaming adapter or a synthetic World oracle.
#include "cybersand/world.hpp"
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <vector>

using namespace cybersand;
namespace {
void require(bool yes, const char* why) {
    if (!yes) throw std::runtime_error(why);
}
WorldConfig make_config(std::uint32_t workers) {
    WorldConfig cfg;
    cfg.chunk_size = 64;
    cfg.activity_block_size = 16;
    cfg.scheduling_core_size = 64;
    cfg.initial_chunk_reserve = 2;
    cfg.maximum_chunk_count = 2;
    cfg.active_chunk_capacity = 16;
    cfg.active_core_capacity = 16;
    cfg.worker_threads = workers;
    cfg.parallel_job_threshold = 1;
    return cfg;
}
void accepted_main_parity(std::uint32_t workers) {
    // No streaming or release API on this path: production defaults must not
    // change simply because #512 adds an opt-in chunk-release operation.
    const auto cfg = make_config(workers);
    World w(cfg);
    const ChunkCoord a{-1,-3}, b{24,8};
    std::vector<Material> empty(64 * 64, Material::Empty);
    require(w.install_generated_chunk(a, empty) == ChunkInstallOutcome::Installed,
            "GEN006_PARITY_A_ADMISSION");
    require(w.install_generated_chunk(b, empty) == ChunkInstallOutcome::Installed,
            "GEN006_PARITY_B_ADMISSION");
    const auto px = a.x * 64, py = a.y * 64;
    for (int x = 12; x <= 24; ++x) w.set(px + x, py + 36, Material::Wall);
    for (int y = 29; y <= 36; ++y) {
        w.set(px + 12, py + y, Material::Wall);
        w.set(px + 24, py + y, Material::Wall);
    }
    require(w.set_cell_state(px + 18, py + 30, Material::Water, 17, 0),
            "GEN006_PARITY_WATER");
    w.set_temperature(px + 18, py + 30, 417);
    w.set(px + 5, py + 5, Material::Empty); // explicit no-op player intent
    require(w.liquid_mass(px + 18, py + 30) == 17 &&
            w.stored_temperature(px + 18, py + 30) == 417,
            "GEN006_PARITY_WATER_STATE");
    const RectI64 basin{px + 12, py + 28, 13, 10};
    for (int step = 0; step <= 5; ++step) {
        require(w.chunk_count() == 2 && !w.has_failed(), "GEN006_PARITY_WORLD_FAILED");
        std::cout << "PARITY workers=" << workers
                  << " step=" << step
                  << " completed=" << w.completed_tick_index()
                  << " physical=" << w.physical_state_hash()
                  << " content=" << w.content_hash()
                  << " quantity=" << w.water_quantity(basin)
                  << " temp=" << w.stored_temperature(px + 18, py + 30)
                  << " empty=" << static_cast<unsigned>(w.stored_material(px + 5, py + 5))
                  << " distant=" << static_cast<unsigned>(w.stored_material(b.x * 64 + 10, b.y * 64 + 10))
                  << '\n';
        if (step < 5) {
            const auto stats = w.tick();
            require(stats.tick == w.completed_tick_index(), "GEN006_PARITY_TICK");
            std::cerr << "OBSERVED workers=" << workers
                      << " step=" << step << " active="
                      << stats.worker_threads_observed << '\n';
        }
    }
}
#ifdef GEN006_TEST_RELEASE
void same_world_readmission(std::uint32_t workers) {
    const auto cfg = make_config(workers);
    const ChunkCoord vacant{-16, -8}, live{16, 8};
    std::vector<Material> empty(64 * 64, Material::Empty), wall = empty;
    wall[30 * 64 + 30] = Material::Wall;
    World uninterrupted(cfg), streamed(cfg);
    for (World* w : {&uninterrupted, &streamed}) {
        require(w->install_generated_chunk(vacant, empty) == ChunkInstallOutcome::Installed,
                "GEN006_REJOIN_VACANT_ADMISSION");
        require(w->install_generated_chunk(live, wall) == ChunkInstallOutcome::Installed,
                "GEN006_REJOIN_LIVE_ADMISSION");
    }
    const auto originally_resident = streamed.resident_cell_bytes();
    require(streamed.chunk_count() == 2 &&
            streamed.content_hash() == uninterrupted.content_hash(),
            "GEN006_REJOIN_INITIAL");
    require(streamed.release_pristine_empty_chunk(vacant) == ChunkReleaseOutcome::Released,
            "GEN006_REJOIN_RELEASE");
    require(streamed.chunk_count() == 1 &&
            streamed.resident_cell_bytes() < originally_resident,
            "GEN006_REJOIN_NO_REAL_RECLAIM");
    require(streamed.install_generated_chunk(vacant, empty) == ChunkInstallOutcome::Installed,
            "GEN006_REJOIN_RE_ADMISSION");
    require(streamed.chunk_count() == 2 &&
            streamed.resident_cell_bytes() <= originally_resident &&
            streamed.content_hash() == uninterrupted.content_hash(),
            "GEN006_REJOIN_CONTENT_CHANGED");
    for (int t = 0; t < 4; ++t) {
        const auto a = uninterrupted.tick();
        const auto b = streamed.tick();
        require(!streamed.has_failed() && !uninterrupted.has_failed() &&
                a.tick == b.tick && streamed.completed_tick_index() == uninterrupted.completed_tick_index() &&
                streamed.content_hash() == uninterrupted.content_hash() &&
                streamed.stored_material(live.x * 64 + 30, live.y * 64 + 30) == Material::Wall,
                "GEN006_REJOIN_CONTINUATION_DIVERGED");
    }
    std::cout << "GEN006_SHARED_WORLD_RELEASE_READMIT_PASS workers=" << workers
              << " real_native_reclaim=1 pristine_regeneration=1"
              << " continuing_ticks=4"
              << " content=" << streamed.content_hash() << '\n';
}
#endif
}  // namespace

int main(int argc, char** argv) {
    try {
        require(argc == 2, "usage: gen006-parity 1|4");
        const auto workers = static_cast<std::uint32_t>(std::stoul(argv[1]));
        require(workers == 1 || workers == 4, "workers must be 1 or 4");
        accepted_main_parity(workers);
#ifdef GEN006_TEST_RELEASE
        same_world_readmission(workers);
#endif
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_SHARED_WORLD_SOURCE_PARITY_FAIL " << e.what() << '\n';
        return 1;
    }
}
