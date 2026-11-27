#pragma once

// GEN-006's opt-in, bounded whole-area continuation domain. This owner-side
// helper does not change World, its limits, any material law, or the CYPS codec.
#include "cybersand/world.hpp"
#include "cybersand/sha256.hpp"

#include <algorithm>
#include <chrono>
#include <limits>
#include <stdexcept>
#include <string>

namespace cybersand::persistent_areas {

inline constexpr std::int32_t kSide = 512;
inline constexpr std::size_t kMaximumChunks = 128;
inline constexpr std::size_t kMaximumCheckpointBytes = 32U * 1024U * 1024U;
inline constexpr std::uint32_t kMaximumSliceTicks = 32;
inline constexpr std::uint64_t kMaximumSliceMicroseconds = 100'000;

inline void validate_domain(const World& world) {
    const auto& config = world.config();
    const auto region = world.simulation_region();
    if (world.has_failed() || world.tick_index() != world.completed_tick_index())
        throw std::invalid_argument("Persistent area requires a healthy completed native tick boundary");
    if (world.material_audition_changes_behavior())
        throw std::invalid_argument("Persistent areas require the default material laws; an audition profile is active");
    if (world.physical_state_format_version() != 2 || world.physical_state_hash_version() != 2 ||
        config.liquid_solver_policy != LiquidSolverPolicy{} || config.wave_flow.enabled ||
        config.ballistic_water.enabled || config.inertial_signed_vertical ||
        config.pressure_gas_compartment_capacity != PressureFlowParameters::kCompartmentCapacity)
        throw std::invalid_argument("Persistent area v1 admits only Current/FreeMass CYPS2; Wave/PF/IN/ballistic are unsupported");
    if (config.backend != SimulationBackend::PhasedInPlace || config.chunk_size != 128 ||
        config.activity_block_size != 32 || config.scheduling_core_size != 64 ||
        config.maximum_rule_radius != 2 || config.settled_discovery_enabled ||
        config.settled_region_connectivity_enabled || config.worker_threads < 1 || config.worker_threads > 32)
        throw std::invalid_argument("Persistent area execution geometry or discovery domain is unsupported");
    if (config.maximum_chunk_count > kMaximumChunks || world.chunk_count() > kMaximumChunks ||
        config.active_chunk_capacity > kMaximumChunks)
        throw std::invalid_argument("Persistent area native residency exceeds the bounded prototype profile");
    if (!region || region->x != 0 || region->y != 0 || region->width != kSide || region->height != kSide)
        throw std::invalid_argument("Persistent area requires the complete 512x512 simulation region");
    // The finite Workbench owns this mask domain. Body/controller state is not
    // in CYPS, including an otherwise invisible stale occupancy mask.
    for (std::int32_t y = 0; y < kSide; ++y)
        for (std::int32_t x = 0; x < kSide; ++x)
            if (world.transient_obstacle_at(x,y) != 0)
                throw std::invalid_argument("Persistent area transition is pinned by a live transient body mask");
}

struct Capture {
    std::vector<std::uint8_t> bytes;
    Sha256::Digest sha256{};
    std::uint64_t physical_hash = 0, completed_tick = 0;
    std::size_t chunks = 0, resident_cell_bytes = 0;
};

inline Capture capture(const World& world) {
    validate_domain(world);
    Capture result;
    result.completed_tick = world.completed_tick_index();
    result.physical_hash = world.physical_state_hash();
    result.chunks = world.chunk_count();
    result.resident_cell_bytes = world.resident_cell_bytes();
    result.bytes = world.save_physical_state();
    // Residency and geometry are checked before serialization. This length
    // check bounds the retained payload, not the serializer's transient peak.
    if (result.bytes.empty() || result.bytes.size() > kMaximumCheckpointBytes)
        throw std::length_error("Persistent area checkpoint exceeds its 32 MiB payload budget");
    result.sha256 = Sha256::of(result.bytes);
    return result;
}

inline std::unique_ptr<World> restore(const WorldConfig& execution,
    std::span<const std::uint8_t> bytes, const Sha256::Digest& expected_sha,
    std::uint64_t expected_tick, std::uint64_t expected_physical_hash) {
    if (bytes.empty() || bytes.size() > kMaximumCheckpointBytes || Sha256::of(bytes) != expected_sha)
        throw std::invalid_argument("Persistent area checkpoint size or SHA256 mismatch");
    auto candidate = World::restore_physical_state(execution, bytes);
    validate_domain(*candidate);
    if (candidate->completed_tick_index() != expected_tick ||
        candidate->physical_state_hash() != expected_physical_hash)
        throw std::invalid_argument("Persistent area checkpoint native tick or physical identity mismatch");
    return candidate;
}

struct StepSlice {
    std::uint32_t completed_ticks = 0, observed_workers = 0;
    std::uint64_t elapsed_microseconds = 0, completed_tick = 0;
    std::uint64_t visited_cells = 0, moved_cells = 0;
};

inline StepSlice advance(World& candidate, std::uint32_t maximum_ticks, std::uint64_t maximum_microseconds) {
    if (maximum_ticks < 1 || maximum_ticks > kMaximumSliceTicks || maximum_microseconds < 1 ||
        maximum_microseconds > kMaximumSliceMicroseconds || candidate.has_failed())
        throw std::invalid_argument("Persistent area catch-up slice exceeds the native work budget");
    if (candidate.completed_tick_index() > static_cast<std::uint64_t>(INT64_MAX) - maximum_ticks)
        throw std::length_error("Persistent area native tick space exhausted");
    StepSlice result;
    const auto started = std::chrono::steady_clock::now();
    const auto elapsed = [&] {
        return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - started).count());
    };
    do {
        const auto stats = candidate.tick();
        ++result.completed_ticks;
        result.observed_workers = std::max(result.observed_workers, stats.worker_threads_observed);
        result.visited_cells += stats.visited_cells;
        result.moved_cells += stats.moved_cells;
    } while (result.completed_ticks < maximum_ticks && elapsed() < maximum_microseconds);
    result.elapsed_microseconds = elapsed();
    result.completed_tick = candidate.completed_tick_index();
    return result;
}

// No native future-rest certificate exists in this domain. Active counts and
// quiescent hashes omit epoch wraps and can hide scheduled interaction work.
// A rejected shortcut must grant ZERO accounted ticks; callers retain debt.
struct CoarseAdmission {
    bool admitted = false;
    std::uint64_t credited_ticks = 0;
    const char* reason = "No native certificate permits skipping epochs, interaction deadlines or reactions";
};
inline CoarseAdmission assess_coarse_advance(const World&, std::uint64_t) noexcept { return {}; }

} // namespace cybersand::persistent_areas
