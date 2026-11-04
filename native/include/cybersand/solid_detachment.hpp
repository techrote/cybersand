#pragma once

#include "cybersand/material.hpp"
#include <array>
#include <cstddef>
#include <cstdint>

// SOL-DETACH-001/A1. Native ownership, not a Rapier implementation. The owner
// must suspend physics stepping until the contact-switch receipt is finalized.
// No default World enables this bounded one-aggregate experimental facility.
namespace cybersand::soliding {
inline constexpr std::size_t kSolidDomainSide = 64;
inline constexpr std::size_t kSolidDomainCells = kSolidDomainSide * kSolidDomainSide;
inline constexpr std::size_t kSolidMembers = 1024;
inline constexpr std::size_t kSolidShapes = 256;

enum class SolidPhase : std::uint8_t {
    Disabled, Idle, Prepared, Acknowledged, Committed, Restored, Active, Quarantined
};
enum class SolidOutcome : std::uint8_t {
    Accepted, Disabled, Busy, Invalid, Anchored, UnknownBoundary, NotResident,
    Excluded, Ineligible, Thermal, Occupied, PendingEvent, MemberCapacity,
    ShapeCapacity, Stale, GenerationExhausted, WorldFailed, Quarantined
};
struct SolidToken {
    std::uint64_t incarnation{}, sequence{};
    bool operator==(const SolidToken&) const = default;
};
struct SolidBounds {
    std::int64_t x{}, y{};
    std::uint16_t width{}, height{};
    bool operator==(const SolidBounds&) const = default;
};
struct SolidLimits {
    std::size_t members{kSolidMembers}, shapes{128};
};
struct SolidRequest {
    SolidBounds domain{}, anchors{};
    std::int64_t seed_x{}, seed_y{};
};
struct SolidMember {
    std::int64_t x{}, y{};
    Material material{Material::Empty};
    std::uint16_t state_a{};
    std::uint8_t state_b{};
    std::int16_t temperature{};
    bool operator==(const SolidMember&) const = default;
};
// Exact non-overlapping union of cell-aligned rectangles, NOT a bounding box.
struct SolidShape {
    std::int64_t x{}, y{};
    std::uint16_t width{}, height{};
    bool operator==(const SolidShape&) const = default;
};
struct SolidSnapshot {
    SolidPhase phase{SolidPhase::Disabled};
    SolidToken token{};
    SolidBounds domain{};
    std::size_t member_count{}, shape_count{}, aggregate_owned_count{};
    std::uint64_t payload_digest{}, shape_digest{}, source_tick{};
    std::uint64_t source_terrain_revision{}, committed_terrain_revision{};
    std::uint16_t body_id{};
    std::uint64_t body_generation{}, physics_epoch{};
    // Homogeneous unit-cell masses. COM offsets are relative to domain.x/y.
    double mass{}, com_x{}, com_y{}, inertia{};
    std::uint64_t inspected_cells{}, neighbour_probes{};
};
// Trusted main-thread bridge receipt for RESERVED INACTIVE objects. These values
// are bindings, not native proof that a live Rapier RID has been constructed.
struct SolidBodyReservation {
    SolidToken token{};
    std::uint16_t body_id{};
    std::uint64_t body_generation{}, payload_digest{}, shape_digest{};
    std::size_t shape_count{};
};
// Issued only while physics stepping is fenced, after the exact post-commit
// static-terrain revision is installed and the staged body is activated.
struct SolidCollisionReceipt {
    SolidToken token{};
    std::uint16_t body_id{};
    std::uint64_t body_generation{}, terrain_revision{}, physics_epoch{};
};

// World-private storage, allocated by explicit configuration outside a tick.
// Copies in Prepared/Acknowledged are borrowed evidence, NOT material owners.
struct SolidStore {
    SolidLimits limits{};
    SolidSnapshot snapshot{};
    std::uint64_t serial{};
    std::array<SolidMember, kSolidMembers> members{};
    std::array<SolidShape, kSolidShapes> shapes{};
    std::array<std::uint16_t, kSolidDomainCells> queue{};
    std::array<bool, kSolidDomainCells> seen{};
};
} // namespace cybersand::soliding
