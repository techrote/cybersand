#pragma once

#include "cybersand/material.hpp"
#include "cybersand/solid_detachment.hpp"
#include <array>
#include <cstddef>
#include <cstdint>

namespace cybersand {
// Bounded contact-specific vacancy propagation. This API supplies no search,
// force, torque or body motion policy. Call only from the serialized World owner
// between ticks, after the adapter validates full cell-square body clearance.
inline constexpr std::size_t kConservativeDisplacementCells = 5;
struct ConservativeDisplacementCell {
    std::int64_t x{}, y{};
    Material expected_material{Material::Empty};
    std::uint16_t expected_state_a{};
    std::uint8_t expected_state_b{};
    std::int16_t expected_temperature{};
};
struct ConservativeDisplacementRequest {
    std::array<ConservativeDisplacementCell, kConservativeDisplacementCells> path{};
    std::size_t count{}; // 2..5 positions, at most four one-cell parcel moves.
    std::uint16_t source_body_id{}; // Zero permits only an unmasked source.
    std::uint64_t expected_tick{};
    // Optional additional active aggregate lease. If any field is supplied,
    // all must bind the current active detachment and its exact reserved body.
    soliding::SolidToken aggregate_token{};
    std::uint64_t body_generation{};
};
enum class ConservativeDisplacementOutcome : std::uint8_t {
    Applied, InvalidPath, Capacity, WorldFailed, TickInProgress, TransitionFenced,
    StaleTick, StaleAggregate, StalePayload, UnsupportedPolicy, UnsupportedMaterial,
    Nonresident, Excluded, SourceMask, DestinationMask, InvalidTerminal,
    ThermalCapacity, Quarantined
};
struct ConservativeDisplacementResult {
    ConservativeDisplacementOutcome outcome{ConservativeDisplacementOutcome::InvalidPath};
    std::size_t moved_cells{};
};
} // namespace cybersand
