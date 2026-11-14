// GEN-006 #194 — owner save ACK identity ABA after a real native World clear/reinit.
// TEST ONLY. No production serializer, durable journal, actor state or eviction API.
#include "cybersand/world.hpp"
#include <algorithm>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace {
using namespace cybersand;
constexpr std::int32_t kSide = 128;
std::uint64_t checks = 0;

void require(bool condition, const char* what) {
    ++checks;
    if (!condition) throw std::runtime_error(what);
}

WorldConfig config(std::uint32_t workers) {
    WorldConfig c{};
    c.chunk_size = kSide;
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

std::int64_t coordinate(int n) { return static_cast<std::int64_t>(n * 2 - 2); }

std::vector<Material> active_payload() {
    std::vector<Material> cells(static_cast<std::size_t>(kSide * kSide), Material::Empty);
    // Four separated scheduled cores. The wall at (26,30) is an explicit tombstone target.
    for (int cy : {30, 94}) for (int cx : {30, 94}) {
        for (int x = cx - 4; x <= cx + 4; ++x) {
            cells[static_cast<std::size_t>((cy + 4) * kSide + x)] = Material::Wall;
            cells[static_cast<std::size_t>((cy - 4) * kSide + x)] = Material::Wall;
        }
        for (int y = cy - 4; y <= cy + 4; ++y) {
            cells[static_cast<std::size_t>(y * kSide + cx - 4)] = Material::Wall;
            cells[static_cast<std::size_t>(y * kSide + cx + 4)] = Material::Wall;
        }
        cells[static_cast<std::size_t>(cy * kSide + cx)] = Material::Water;
        cells[static_cast<std::size_t>((cy - 1) * kSide + cx)] = Material::Sand;
    }
    return cells;
}

void install_eight(World& w, const std::vector<Material>& payload) {
    for (int i = 0; i < 8; ++i) {
        require(w.install_generated_chunk({coordinate(i), 0}, payload) ==
                ChunkInstallOutcome::Installed, "native fresh admission failed");
    }
    require(w.chunk_count() == 8, "native resident count incorrect");
}

std::uint32_t tick_twice(World& w) {
    std::uint32_t observed = 0;
    for (int n = 0; n < 2; ++n) {
        const auto stats = w.tick();
        require(!w.has_failed(), "native tick quarantined");
        observed = std::max(observed, stats.worker_threads_observed);
    }
    require(observed >= 1, "no native worker participated");
    return observed;
}

// The next structures deliberately model the MISSING external owner contract.
// They are neither a native World persistence API nor evidence of a real disk ACK.
struct Receipt {
    std::uint64_t world_session = 0;
    std::uint64_t chunk_incarnation = 0;
    std::uint64_t mutation_generation = 0;
};
struct GenerationOnlyAck {
    std::uint64_t current_generation = 1;
    std::uint64_t acknowledged_generation = 0;
    bool acknowledge(const Receipt& r) {
        if (r.mutation_generation != current_generation ||
            acknowledged_generation >= r.mutation_generation) return false;
        acknowledged_generation = r.mutation_generation;
        return true;
    }
};
struct CompositeOwnerAck {
    std::uint64_t current_session = 0;
    std::uint64_t current_incarnation = 0;
    std::uint64_t current_generation = 1;
    std::uint64_t acknowledged_generation = 0;
    bool acknowledge(const Receipt& r) {
        if (r.world_session != current_session ||
            r.chunk_incarnation != current_incarnation ||
            r.mutation_generation != current_generation ||
            acknowledged_generation >= r.mutation_generation) return false;
        acknowledged_generation = r.mutation_generation;
        return true;
    }
};

void cohort(std::uint32_t workers) {
    const auto cfg = config(workers);
    World world(cfg);
    const auto payload = active_payload();
    install_eight(world, payload);
    const auto old_observed = tick_twice(world);
    const std::int64_t edit_x = coordinate(0) * kSide + 26; // -230, signed region
    constexpr std::int64_t edit_y = 30;
    require(world.stored_material(edit_x, edit_y) == Material::Wall,
            "old-session native Wall control missing");
    require(world.set_cell_state(edit_x, edit_y, Material::Empty, 0, 0),
            "old-session native Empty tombstone refused");
    const auto old_hash = world.physical_state_hash();
    const auto old_bytes = world.save_physical_state();
    require(!old_bytes.empty(), "old native snapshot absent");
    const Receipt late_old_save{71, 11, 1};

    // Actual native reset and re-admission at identical coordinates. A new
    // session/incarnation may legitimately reuse local mutation generation 1.
    world.clear();
    require(!world.has_failed() && world.chunk_count() == 0,
            "native clear failed to release old resident chunks");
    install_eight(world, payload);
    const auto new_observed = tick_twice(world);
    require(world.stored_material(edit_x, edit_y) == Material::Wall,
            "new-session baseline failed to reinitialize original coordinate");
    require(world.set_cell_state(edit_x, edit_y, Material::Water, 17, 0),
            "new-session native Water state edit refused");
    require(world.stored_state_a(edit_x, edit_y) == 17 &&
            world.liquid_mass(edit_x, edit_y) == 17,
            "new-session native Water quantity/state mismatch");
    const auto new_hash = world.physical_state_hash();
    const auto new_bytes = world.save_physical_state();
    require(!new_bytes.empty() && new_bytes != old_bytes && new_hash != old_hash,
            "old and new native World content unexpectedly identical");

    auto old_restored = World::restore_physical_state(cfg, old_bytes);
    auto new_restored = World::restore_physical_state(cfg, new_bytes);
    require(old_restored && new_restored, "native snapshot restore refused");
    require(old_restored->physical_state_hash() == old_hash &&
            old_restored->stored_material(edit_x, edit_y) == Material::Empty,
            "old native tombstone state failed restoration");
    require(new_restored->physical_state_hash() == new_hash &&
            new_restored->stored_material(edit_x, edit_y) == Material::Water &&
            new_restored->stored_state_a(edit_x, edit_y) == 17 &&
            new_restored->liquid_mass(edit_x, edit_y) == 17,
            "new native Water state failed restoration");

    // Negative: a generation-only ACK model accepts the *old* completed save
    // at generation 1, which coincides with the restarted owner's generation 1.
    GenerationOnlyAck inadequate{};
    require(inadequate.acknowledge(late_old_save),
            "generation-only negative control did not reproduce ACK ABA");

    CompositeOwnerAck guarded{72, 12, 1, 0};
    require(!guarded.acknowledge(late_old_save),
            "new owner accepted obsolete session+incarnation receipt");
    require(!guarded.acknowledge({72, 11, 1}),
            "new owner accepted old incarnation with matching session/gen");
    require(!guarded.acknowledge({71, 12, 1}),
            "new owner accepted old session with matching incarnation/gen");
    require(!guarded.acknowledge({72, 12, 2}),
            "new owner accepted future generation");
    require(guarded.acknowledged_generation == 0,
            "a refused old ACK cleared pending new mutation");
    require(guarded.acknowledge({72, 12, 1}),
            "current owner save ACK refused");
    require(!guarded.acknowledge({72, 12, 1}),
            "repeated current owner ACK was not rejected idempotently");

    // Source-identical whole-World fixed-tick comparison ONLY. This is not
    // actual selective eviction/reload and does not establish sidecar coverage.
    for (int n = 0; n < 3; ++n) {
        const auto a = world.tick();
        const auto b = new_restored->tick();
        require(!world.has_failed() && !new_restored->has_failed(),
                "native continuation tick failed");
        require(a.tick == b.tick &&
                world.physical_state_hash() == new_restored->physical_state_hash(),
                "new-session native whole-World fixed-tick comparison diverged");
    }
    std::cout << "GEN006_NATIVE_RESET_ABA_JSON {\"probe\":\"gen006_native_reset_aba\","
              << "\"configured_workers\":" << workers << ","
              << "\"old_observed_workers\":" << old_observed << ","
              << "\"new_observed_workers\":" << new_observed << ","
              << "\"resident_chunks\":8,"
              << "\"old_edit\":\"Empty\","
              << "\"new_edit\":\"Water17\","
              << "\"old_checkpoint_bytes\":" << old_bytes.size() << ","
              << "\"new_checkpoint_bytes\":" << new_bytes.size() << ","
              << "\"generation_only_stale_ack_accepted\":true,"
              << "\"identity_fence_stale_ack_refused\":true,"
              << "\"same_source_fixed_tick_control\":3,"
              << "\"result\":\"PASS\"}\n";
}
} // namespace

int main() {
    try {
        cohort(1);
        cohort(4);
        std::cout << "GEN006_NATIVE_RESET_ABA_PASS assertions=" << checks << "\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_NATIVE_RESET_ABA_FAIL assertions=" << checks
                  << " error=" << e.what() << "\n";
        return 1;
    }
}
