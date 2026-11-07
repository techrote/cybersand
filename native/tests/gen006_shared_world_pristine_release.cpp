// GEN-006 first in-place (one shared World) selective release acceptance.
// This proves real native storage reclamation ONLY for freshly generated,
// never-edited, wholly Empty, isolated chunks. No dynamic save/restore claim.
#include "cybersand/world.hpp"

#include <cstdint>
#include <exception>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cybersand;

namespace {
void require(bool condition, const char* why) {
    if (!condition) throw std::runtime_error(why);
}
WorldConfig config(std::uint32_t workers) {
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
void test(std::uint32_t workers) {
    const ChunkCoord vacant{-16, -8}, wall_coord{16, 8}, third{40, 8};
    std::vector<Material> empty(64 * 64, Material::Empty);
    auto wall = empty;
    wall[30 * 64 + 30] = Material::Wall;

    World w(config(workers));
    require(w.install_generated_chunk(vacant, empty) == ChunkInstallOutcome::Installed,
            "GEN006_EMPTY_ADMISSION_REFUSED");
    require(w.install_generated_chunk(wall_coord, wall) == ChunkInstallOutcome::Installed,
            "GEN006_WALL_ADMISSION_REFUSED");
    const auto before_bytes = w.resident_cell_bytes();
    const auto before_count = w.chunk_count();
    const auto before_tick = w.completed_tick_index();
    require(before_count == 2 && before_bytes > 0,
            "GEN006_SHARED_WORLD_NOT_FULL");
    require(w.install_generated_chunk(third, empty) == ChunkInstallOutcome::CapacityFull,
            "GEN006_CAPACITY_NEGATIVE_CONTROL");

    // Actual populated native chunk may NEVER be classified as disposable.
    require(w.release_pristine_empty_chunk(wall_coord) == ChunkReleaseOutcome::NotPristine,
            "GEN006_MODIFIED_WALL_RELEASED");
    require(w.chunk_count() == before_count &&
            w.resident_cell_bytes() == before_bytes,
            "GEN006_REFUSAL_MUTATED_WORLD");

    require(w.release_pristine_empty_chunk(vacant) == ChunkReleaseOutcome::Released,
            "GEN006_SHARED_WORLD_EMPTY_RELEASE_REFUSED");
    require(w.chunk_count() == 1 && w.resident_cell_bytes() < before_bytes &&
            w.completed_tick_index() == before_tick &&
            w.stored_material(vacant.x * 64 + 1, vacant.y * 64 + 1) == Material::Empty &&
            w.stored_material(wall_coord.x * 64 + 30, wall_coord.y * 64 + 30) == Material::Wall,
            "GEN006_NATIVE_RELEASE_DAMAGED_NEIGHBOUR_OR_CLOCK");
    require(w.release_pristine_empty_chunk(vacant) == ChunkReleaseOutcome::NotResident,
            "GEN006_RELEASED_CHUNK_STILL_RESIDENT");
    require(w.install_generated_chunk(third, empty) == ChunkInstallOutcome::Installed &&
            w.chunk_count() == 2,
            "GEN006_RELEASED_NATIVE_CAPACITY_NOT_REUSABLE");
    require(w.release_pristine_empty_chunk(third) == ChunkReleaseOutcome::Released,
            "GEN006_SECOND_EMPTY_RELEASE_REFUSED");
    const auto stats = w.tick();
    require(!w.has_failed() && stats.tick == w.completed_tick_index() &&
            w.stored_material(wall_coord.x * 64 + 30, wall_coord.y * 64 + 30) == Material::Wall,
            "GEN006_NATIVE_CONTINUATION_AFTER_RELEASE");
    const auto observed = stats.worker_threads_observed;

    // An explicit same-value player Empty tombstone cannot be erased on
    // the basis of identical physical bytes. Test native no-op edit intent.
    World edited(config(workers));
    require(edited.install_generated_chunk(vacant, empty) == ChunkInstallOutcome::Installed,
            "GEN006_EDIT_INTENT_SETUP");
    edited.set(vacant.x * 64 + 8, vacant.y * 64 + 8, Material::Empty);
    const auto edited_hash = edited.physical_state_hash();
    const auto edited_bytes = edited.resident_cell_bytes();
    require(edited.release_pristine_empty_chunk(vacant) == ChunkReleaseOutcome::NotPristine &&
            edited.chunk_count() == 1 &&
            edited.physical_state_hash() == edited_hash &&
            edited.resident_cell_bytes() == edited_bytes,
            "GEN006_EMPTY_TOMBSTONE_WAS_DROPPED");

    World state_edit(config(workers));
    require(state_edit.install_generated_chunk(vacant, empty) == ChunkInstallOutcome::Installed,
            "GEN006_STATE_INTENT_SETUP");
    require(state_edit.set_cell_state(vacant.x * 64 + 8, vacant.y * 64 + 8,
                                      Material::Empty, 0, 0),
            "GEN006_STATE_INTENT_REFUSED");
    require(state_edit.release_pristine_empty_chunk(vacant) == ChunkReleaseOutcome::NotPristine,
            "GEN006_STATE_EMPTY_INTENT_DROPPED");

    // The full-World native serializer lacks the newly introduced
    // untouched-origin evidence. Restored empty chunks are pinned, never
    // optimistically reclassified.
    World restored_origin(config(workers));
    require(restored_origin.install_generated_chunk(vacant, empty) == ChunkInstallOutcome::Installed,
            "GEN006_RESTORE_ORIGIN_SETUP");
    const auto bytes = restored_origin.save_physical_state();
    auto restored = World::restore_physical_state(config(workers), bytes);
    require(restored && !restored->has_failed() && restored->chunk_count() == 1 &&
            restored->release_pristine_empty_chunk(vacant) == ChunkReleaseOutcome::NotPristine,
            "GEN006_RESTORED_EMPTY_NOT_PINNED");

    World neighbours(config(workers));
    require(neighbours.install_generated_chunk({-1,3}, empty) == ChunkInstallOutcome::Installed &&
            neighbours.install_generated_chunk({0,3}, empty) == ChunkInstallOutcome::Installed,
            "GEN006_NEIGHBOUR_SETUP");
    const auto neighbour_bytes = neighbours.resident_cell_bytes();
    require(neighbours.release_pristine_empty_chunk({-1,3}) == ChunkReleaseOutcome::NeighbourPinned &&
            neighbours.chunk_count() == 2 &&
            neighbours.resident_cell_bytes() == neighbour_bytes,
            "GEN006_NEIGHBOUR_HALO_DROPPED");

    auto pinned_cfg = config(workers);
    pinned_cfg.settled_discovery_enabled = true;
    World pinned(pinned_cfg);
    require(pinned.install_generated_chunk(vacant, empty) == ChunkInstallOutcome::Installed,
            "GEN006_DISCOVERY_PIN_SETUP");
    require(pinned.release_pristine_empty_chunk(vacant) == ChunkReleaseOutcome::SidecarOrOwnerPinned,
            "GEN006_DISCOVERY_SIDECAR_DROPPED");

    std::cout << "GEN006_SHARED_WORLD_PRISTINE_RELEASE_PASS"
              << " configured_workers=" << workers
              << " actual_workers=" << observed
              << " actual_native_reclamation=1"
              << " same_World_reusable_capacity=1"
              << " populated=PINNED"
              << " no_op_Empty_intent=PINNED"
              << " restored_checkpoint=PINNED"
              << " neighbour=PINNED"
              << " optional_domain=PINNED"
              << " following_tick=PASS\n";
}
}

int main(int argc, char** argv) {
    try {
        require(argc == 2, "usage: gen006-native-release 1|4");
        const auto workers = static_cast<std::uint32_t>(std::stoul(argv[1]));
        require(workers == 1 || workers == 4, "GEN006_WORKERS");
        test(workers);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_SHARED_WORLD_PRISTINE_RELEASE_FAIL " << e.what() << '\n';
        return 1;
    }
}
