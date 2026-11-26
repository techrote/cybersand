// GEN-006 #194 — native whole-World CYPS scope/latency cost discriminator.
// TEST-ONLY. No selective serializer, eviction implementation, or gameplay claim.
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
using Clock = std::chrono::steady_clock;
std::size_t assertions = 0;
constexpr std::int32_t side = 128;

void check(bool ok, const char* message) {
    ++assertions;
    if (!ok) throw std::runtime_error(message);
}

WorldConfig config(std::uint32_t workers) {
    WorldConfig c{};
    c.chunk_size = side;
    c.backend = SimulationBackend::PhasedInPlace;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.initial_chunk_reserve = 40;
    c.maximum_chunk_count = 48;
    c.active_chunk_capacity = 256;
    c.active_core_capacity = 4096;
    c.deferred_event_capacity = 128;
    return c;
}

std::vector<Material> material_payload() {
    std::vector<Material> cells(static_cast<std::size_t>(side * side), Material::Empty);
    // Four distinct active 64-cell scheduling cores in each loaded chunk.
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

std::int64_t chunk_x(int n) {
    // Includes a negative chunk and, by n=32, coordinates well beyond 1024.
    return static_cast<std::int64_t>(n * 2 - 2);
}

std::vector<std::uint64_t> timed_saves_ns(const World& w, std::size_t& byte_size) {
    // Warmup is deliberately not in the timed cohort.
    const auto warmup = w.save_physical_state();
    byte_size = warmup.size();
    check(byte_size != 0, "empty native checkpoint");
    std::vector<std::uint64_t> ns;
    for (int i = 0; i < 5; ++i) {
        const auto start = Clock::now();
        const auto save = w.save_physical_state();
        const auto end = Clock::now();
        check(save == warmup, "unchanged native World exported noncanonical bytes");
        ns.push_back(static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count()));
    }
    return ns;
}

void cohort(std::uint32_t workers, int count, std::size_t& last_bytes) {
    const auto cfg = config(workers);
    World world(cfg);
    const auto payload = material_payload();
    for (int i = 0; i < count; ++i) {
        check(world.install_generated_chunk({chunk_x(i), 0}, payload) ==
                  ChunkInstallOutcome::Installed,
              "native generated-chunk installation refused");
    }
    check(world.chunk_count() == static_cast<std::size_t>(count),
          "actual native resident chunk count wrong");
    std::uint32_t observed = 0;
    for (int i = 0; i < 2; ++i) {
        const auto s = world.tick();
        observed = std::max(observed, s.worker_threads_observed);
        check(!world.has_failed(), "actual World failed during normal ticks");
    }

    std::size_t bytes = 0;
    const auto ns = timed_saves_ns(world, bytes);
    check(bytes > last_bytes, "whole-World CYPS size did not grow with resident chunks");
    last_bytes = bytes;
    const auto untouched = world.save_physical_state();
    const auto before = world.physical_state_hash();
    auto restored = World::restore_physical_state(cfg, untouched);
    check(restored != nullptr && restored->physical_state_hash() == before,
          "unchanged whole-World restore not identical");

    // Edit ONE remote stored cell, not a simulation skip or fast-path.
    const auto far_x = chunk_x(count - 1) * side + 4;
    check(world.stored_material(far_x, 1) == Material::Empty,
          "single-cell edit would overwrite nonempty authority");
    check(world.set_cell_state(far_x, 1, Material::Wall, 0, 0),
          "single stored-cell edit refused");
    const auto after_edit = world.save_physical_state();
    check(after_edit != untouched, "single-cell mutation did not alter checkpoint");
    auto edited_restore = World::restore_physical_state(cfg, after_edit);
    check(edited_restore != nullptr &&
              edited_restore->physical_state_hash() == world.physical_state_hash() &&
              edited_restore->stored_material(far_x, 1) == Material::Wall,
          "single-cell edit did not restore actual native authority");
    // The whole-World codec is not a dirty-chunk delta serializer.
    check(after_edit.size() >= bytes / 2,
          "unexpectedly small output: revisit format classification");

    std::cout << "{\"probe\":\"gen006_native_cyps_scaling\","
              << "\"configured_workers\":" << workers << ","
              << "\"observed_workers_max\":" << observed << ","
              << "\"resident_chunks\":" << count << ","
              << "\"resident_cell_bytes\":" << world.resident_cell_bytes() << ","
              << "\"checkpoint_bytes\":" << bytes << ","
              << "\"post_one_cell_edit_checkpoint_bytes\":" << after_edit.size() << ","
              << "\"last_world_cell_x\":" << far_x << ","
              << "\"timed_save_ns\":[";
    for (std::size_t i = 0; i < ns.size(); ++i) {
        if (i) std::cout << ",";
        std::cout << ns[i];
    }
    std::cout << "],\"result\":\"PASS\"}\n";
}


// Follow-on negative/control: render dirtiness and cell equality are not a
// durable mutation journal. The local generation receipt below is TEST-ONLY.
struct DurableIntentControl {
    std::uint64_t mutation_generation = 0;
    std::uint64_t acknowledged_generation = 0;
    void observe_owner_intent() { ++mutation_generation; }
    [[nodiscard]] bool pending() const {
        return mutation_generation != acknowledged_generation;
    }
    [[nodiscard]] bool acknowledge_if_current(std::uint64_t captured_generation) {
        if (captured_generation != mutation_generation ||
            captured_generation <= acknowledged_generation) return false;
        acknowledged_generation = captured_generation;
        return true;
    }
};

void dirty_ack_cohort(std::uint32_t workers) {
    const auto cfg = config(workers);
    World actual(cfg);
    const auto baseline = material_payload();
    // Distinct native active cores, one signed negative chunk, and chunks beyond
    // the finite viewer. This is a real World; it is NOT selective eviction.
    for (int i = 0; i < 8; ++i) {
        check(actual.install_generated_chunk({chunk_x(i), 0}, baseline) ==
                  ChunkInstallOutcome::Installed, "dirty-probe native admission refused");
    }
    std::uint32_t observed = 0;
    for (int i = 0; i < 2; ++i) {
        const auto stats = actual.tick();
        observed = std::max(observed, stats.worker_threads_observed);
        check(!actual.has_failed(), "dirty-probe native tick failed");
    }
    (void)actual.take_dirty_chunks(); // rendering consumer clears initialization dirtiness
    check(actual.dirty_chunk_count() == 0, "dirty-probe initial display flags remain");

    const auto tombstone_x = chunk_x(0) * side + 26; // Wall at signed (-2,0)
    const auto water_x = chunk_x(0) * side + 30;
    const std::int64_t y = 30;
    check(actual.stored_material(tombstone_x, y) == Material::Wall,
          "dirty-probe expected original Wall");
    DurableIntentControl owner;
    owner.observe_owner_intent(); // same-value player edit intent, not a World claim
    const bool same_value_changed =
        actual.set_cell_state(tombstone_x, y, Material::Wall, 0, 0);
    check(!same_value_changed, "same-value tuple unexpectedly changed physical World");
    check(actual.dirty_chunk_count() == 0, "same-value action unexpectedly raised display dirtiness");
    check(owner.pending(), "same-value user intent was not retained by owner control");
    // A failed durable save has no ACK. Native render dirtiness cannot replace
    // this owner journal. The following is a synthetic failure decision.
    check(actual.take_dirty_chunks().empty(), "render channel invented an edit receipt");
    check(owner.pending(), "render consumption incorrectly acknowledged durable intent");

    owner.observe_owner_intent(); // explicit Wall -> Empty tombstone
    check(actual.set_cell_state(tombstone_x, y, Material::Empty, 0, 0),
          "native Wall->Empty edit refused");
    check(actual.stored_material(tombstone_x, y) == Material::Empty,
          "native explicit Empty edit failed");
    check(actual.dirty_chunk_count() > 0, "true edit was not render-dirty");
    const auto display_acks = actual.take_dirty_chunks();
    check(!display_acks.empty() && actual.dirty_chunk_count() == 0,
          "display consumption must not be a durable save acknowledgment");
    check(owner.pending(), "unacknowledged tombstone lost from owner control");
    check(!owner.acknowledge_if_current(1), "old same-value save ACK accepted over tombstone");

    // The current native installer has strict fresh-only semantics, and
    // baseline-only regeneration would resurrect a deleted Wall if the dirty
    // tombstone had never been published. This is not actual eviction/reload.
    World regenerated(cfg);
    check(regenerated.install_generated_chunk({chunk_x(0), 0}, baseline) ==
              ChunkInstallOutcome::Installed, "baseline-only reproduction refused");
    check(regenerated.stored_material(tombstone_x, y) == Material::Wall,
          "regeneration negative control failed to expose absent tombstone");
    check(actual.install_generated_chunk({chunk_x(0), 0}, baseline) ==
              ChunkInstallOutcome::AlreadyResident,
          "existing resident chunk was improperly overwritten");

    // A real complete native CYPS capture remains safe *when* it is committed.
    // This copy is intentionally treated as still in-flight/unacknowledged.
    const auto first_capture_generation = owner.mutation_generation;
    const auto old_capture = actual.save_physical_state();
    check(!old_capture.empty(), "in-flight native snapshot empty");
    owner.observe_owner_intent(); // post-capture Water state/quantity mutation
    check(actual.set_cell_state(water_x, y, Material::Water, 17, 0),
          "native Water state_a=17 edit refused");
    check(actual.stored_material(water_x, y) == Material::Water &&
              actual.stored_state_a(water_x, y) == 17 &&
              actual.liquid_mass(water_x, y) == 17,
          "native partial Water amount/state mismatch");
    (void)actual.take_dirty_chunks(); // another render consumption
    check(actual.dirty_chunk_count() == 0 && owner.pending(),
          "render drain incorrectly completed durable Water mutation");
    check(!owner.acknowledge_if_current(first_capture_generation),
          "stale asynchronous snapshot ACK overwrote a later mutation");
    const auto newest_capture = actual.save_physical_state();
    check(newest_capture != old_capture, "new native Water state not captured");
    auto exact = World::restore_physical_state(cfg, newest_capture);
    check(exact != nullptr && exact->physical_state_hash() == actual.physical_state_hash() &&
              exact->stored_material(tombstone_x, y) == Material::Empty &&
              exact->liquid_mass(water_x, y) == 17,
          "complete native same-source restore lost tombstone/Water state");
    check(owner.acknowledge_if_current(owner.mutation_generation) && !owner.pending(),
          "test-only current-generation ACK could not complete");
    check(!owner.acknowledge_if_current(owner.mutation_generation),
          "duplicate durable ACK was not idempotently refused");

    std::cout << "GEN006_NATIVE_DIRTY_ACK_JSON {\"probe\":\"gen006_native_dirty_ack\","
              << "\"configured_workers\":" << workers << ","
              << "\"observed_workers_max\":" << observed << ","
              << "\"resident_chunks\":" << actual.chunk_count() << ","
              << "\"same_value_world_changed\":" << (same_value_changed ? "true" : "false") << ","
              << "\"render_dirty_after_drain\":" << actual.dirty_chunk_count() << ","
              << "\"owner_intent_generation\":" << owner.mutation_generation << ","
              << "\"owner_ack_generation\":" << owner.acknowledged_generation << ","
              << "\"baseline_only_regenerated_wall\":true,"
              << "\"native_restored_empty\":true,"
              << "\"native_restored_water_mass\":17,"
              << "\"result\":\"PASS\"}\n";
}

} // namespace
int main() {
    try {
        for (auto workers : {1U, 4U}) {
            std::size_t last = 0;
            for (auto count : {1, 8, 32})
                cohort(workers, count, last);
        }
        for (auto workers : {1U, 4U}) dirty_ack_cohort(workers);
        std::cout << "GEN006_NATIVE_CYPS_SCALING_PASS assertions="
                  << assertions << "\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_NATIVE_CYPS_SCALING_FAIL assertions="
                  << assertions << " error=" << e.what() << "\n";
        return 1;
    }
}
