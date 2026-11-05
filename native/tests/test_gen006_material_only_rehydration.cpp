// GEN-006 #194: experiment-only native material-only rehydration discrimination.
// No production serializer, streaming manager, owner transaction or eviction API.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using cybersand::ChunkCoord;
using cybersand::ChunkInstallOutcome;
using cybersand::Material;
using cybersand::SimulationBackend;
using cybersand::World;
using cybersand::WorldConfig;

constexpr std::int32_t kSide = 128;
constexpr std::int64_t kOriginX = -128;
constexpr std::int64_t kWaterX = -98;
constexpr std::int64_t kWaterY = 30;
constexpr std::int64_t kEraseX = -102;
constexpr std::int64_t kEraseY = 26;
std::uint64_t assertions = 0;

void require(bool yes, const char* text) {
    ++assertions;
    if (!yes) throw std::runtime_error(text);
}

std::size_t index(int local_x, int y) {
    return static_cast<std::size_t>(y * kSide + local_x);
}

std::vector<Material> baseline() {
    std::vector<Material> cells(static_cast<std::size_t>(kSide * kSide), Material::Empty);
    for (const int cx : {30, 94}) {
        for (const int cy : {30, 94}) {
            // Four independently active 64-cell scheduling cores, all on one
            // real native chunk at signed coordinate {-1,0}.
            for (int x = cx - 4; x <= cx + 4; ++x) {
                cells[index(x, cy - 4)] = Material::Wall;
                cells[index(x, cy + 4)] = Material::Wall;
            }
            for (int y = cy - 4; y <= cy + 4; ++y) {
                cells[index(cx - 4, y)] = Material::Wall;
                cells[index(cx + 4, y)] = Material::Wall;
            }
            for (int x = cx - 2; x <= cx + 2; ++x) {
                cells[index(x, cy - 2)] = Material::Water;
                cells[index(x, cy - 1)] = Material::Sand;
            }
        }
    }
    return cells;
}

WorldConfig config_for(std::uint32_t workers) {
    WorldConfig config{};
    config.chunk_size = kSide;
    config.backend = SimulationBackend::PhasedInPlace;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    config.sleep_after_quiet_ticks = 3;
    config.initial_chunk_reserve = 4;
    config.maximum_chunk_count = 16;
    config.active_chunk_capacity = 32;
    config.active_core_capacity = 64;
    config.deferred_event_capacity = 64;
    return config;
}

std::vector<Material> materials_of(const World& world) {
    std::vector<Material> content;
    content.reserve(static_cast<std::size_t>(kSide * kSide));
    for (std::int64_t y = 0; y < kSide; ++y) {
        for (std::int64_t local_x = 0; local_x < kSide; ++local_x)
            content.push_back(world.stored_material(kOriginX + local_x, y));
    }
    return content;
}

bool invalid_restore(const WorldConfig& cfg, const std::vector<std::uint8_t>& bytes) {
    try {
        (void)World::restore_physical_state(cfg, bytes);
    } catch (const std::invalid_argument&) {
        return true;
    }
    return false;
}

void probe(std::uint32_t workers) {
    const auto cfg = config_for(workers);
    const auto old_baseline = baseline();
    auto uninterrupted = std::make_unique<World>(cfg);

    // Keep identical bounded 1/4-worker workloads: eight separated, real
    // generated native chunks across both sides of the signed origin. They
    // cannot coalesce into a single scheduling core or share rule halos.
    for (const int chunk_x : {-1, 1, 3, 5, 7, 9, 11, 13}) {
        require(uninterrupted->install_generated_chunk({chunk_x, 0}, old_baseline) ==
                    ChunkInstallOutcome::Installed,
                "actual native absent-chunk admission rejected");
    }
    require(uninterrupted->chunk_count() == 8,
            "multichunk workload was not actually resident");
    require(uninterrupted->install_generated_chunk({-1, 0}, old_baseline) ==
                ChunkInstallOutcome::AlreadyResident,
            "strict installer did not refuse occupied resident");

    for (int t = 0; t < 3; ++t) (void)uninterrupted->tick();
    require(uninterrupted->set_cell_state(kWaterX, kWaterY, Material::Water, 17, 0),
            "partial Water admission");
    uninterrupted->set_temperature(kWaterX, kWaterY, 417);

    // A real mutation from baseline Wall to explicit Empty. The material-only
    // view cannot distinguish intentional erasure from generated empty.
    require(old_baseline[index(static_cast<int>(kEraseX - kOriginX), static_cast<int>(kEraseY))] ==
                Material::Wall, "erasure control baseline is Wall");
    require(uninterrupted->set_cell_state(kEraseX, kEraseY, Material::Empty, 0, 0),
            "erasure mutation not admitted");
    require(uninterrupted->stored_material(kEraseX, kEraseY) == Material::Empty,
            "erasure mutation not observable");

    require(uninterrupted->stored_state_a(kWaterX, kWaterY) == 17 &&
                uninterrupted->stored_temperature(kWaterX, kWaterY) == 417,
            "native partial Water and temperature are authoritative");
    // Keep a pending native event in the saved continuation domain.
    require(uninterrupted->queue_explosion(kOriginX + 94, 94, 1, 11),
            "native pending explosion not admitted");

    const auto checkpoint = uninterrupted->save_physical_state();
    require(!checkpoint.empty(), "CYPS whole-World checkpoint empty");
    const auto hash = uninterrupted->physical_state_hash();
    auto exact = World::restore_physical_state(cfg, checkpoint);
    require(exact != nullptr && exact->physical_state_hash() == hash,
            "real CYPS continuation restore not identical at checkpoint");
    require(exact->save_physical_state() == checkpoint,
            "real CYPS continuation bytes not canonical");

    // Construct an actual new native World, using only the material identities
    // obtainable from a generated-chunk installer. This is not an eviction API.
    auto naive = std::make_unique<World>(cfg);
    const auto current_materials = materials_of(*uninterrupted);
    require(naive->install_generated_chunk({-1, 0}, current_materials) ==
                ChunkInstallOutcome::Installed,
            "material-only native rehydration did not install");
    require(materials_of(*naive) == current_materials,
            "material-only material identities were not preserved");
    require(naive->stored_material(kEraseX, kEraseY) == Material::Empty,
            "material-only rehydration lost current Empty material");
    require(naive->stored_material(kWaterX, kWaterY) == Material::Water,
            "material-only rehydration lost Water material");
    require(naive->stored_state_a(kWaterX, kWaterY) !=
                uninterrupted->stored_state_a(kWaterX, kWaterY),
            "negative control did not lose partial Water state");
    require(naive->stored_temperature(kWaterX, kWaterY) !=
                uninterrupted->stored_temperature(kWaterX, kWaterY),
            "negative control did not lose authoritative temperature");
    require(naive->physical_state_hash() != uninterrupted->physical_state_hash(),
            "material-only rehydration falsely appears equivalent to continuation");

    std::uint32_t max_observed_live = 0;
    std::uint32_t max_observed_restored = 0;
    for (int t = 0; t < 10; ++t) {
        const auto a = uninterrupted->tick();
        const auto b = exact->tick();
        require(!uninterrupted->has_failed() && !exact->has_failed(),
                "native World quarantined during continuation");
        require(a.tick == b.tick &&
                    uninterrupted->completed_tick_index() == exact->completed_tick_index(),
                "attempted/completed tick clocks diverged");
        require(uninterrupted->physical_state_hash() == exact->physical_state_hash(),
                "native tick-continuation physical-state hash mismatch");
        require(uninterrupted->quantity_ledger() == exact->quantity_ledger(),
                "native tick-continuation quantity ledger mismatch");
        require(uninterrupted->stored_state_a(kWaterX, kWaterY) ==
                    exact->stored_state_a(kWaterX, kWaterY),
                "native tick-continuation Water state mismatch");
        max_observed_live = std::max(max_observed_live, a.worker_threads_observed);
        max_observed_restored = std::max(max_observed_restored, b.worker_threads_observed);
    }

    // Refuse invalid bytes without mutating either owner. This exercise never
    // edits production source or assumes cross-source CYPS compatibility.
    auto corrupt = checkpoint;
    corrupt[corrupt.size() / 2] ^= 0x80U;
    require(invalid_restore(cfg, corrupt), "corrupted CYPS payload accepted");
    require(invalid_restore(cfg, std::vector<std::uint8_t>(
                checkpoint.begin(), checkpoint.begin() +
                static_cast<std::ptrdiff_t>(checkpoint.size() / 2))),
            "truncated CYPS payload accepted");

    std::cout << "GEN006_NATIVE_MATERIAL_ONLY_NEGATIVE"
              << " configured_workers=" << workers
              << " max_observed_live=" << max_observed_live
              << " max_observed_restored=" << max_observed_restored
              << " chunk_x=-1 chunk_y=0"
              << " saved_bytes=" << checkpoint.size()
              << " continuation_ticks=10"
              << " assertions_so_far=" << assertions
              << " result=PASS\n";
}
}  // namespace

int main() {
    try {
        probe(1);
        probe(4);
        std::cout << "GEN006_NATIVE_FIXTURE_PASS assertions=" << assertions << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_NATIVE_FIXTURE_FAIL assertions=" << assertions
                  << " error=" << error.what() << '\n';
        return 1;
    }
}
