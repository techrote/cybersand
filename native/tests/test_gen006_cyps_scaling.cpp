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

} // namespace
int main() {
    try {
        for (auto workers : {1U, 4U}) {
            std::size_t last = 0;
            for (auto count : {1, 8, 32})
                cohort(workers, count, last);
        }
        std::cout << "GEN006_NATIVE_CYPS_SCALING_PASS assertions="
                  << assertions << "\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_NATIVE_CYPS_SCALING_FAIL assertions="
                  << assertions << " error=" << e.what() << "\n";
        return 1;
    }
}
