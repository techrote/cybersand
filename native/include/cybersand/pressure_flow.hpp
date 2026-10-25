#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

// LCB-001 (#200) pressure_flow_v1/reference: value types for the opt-in Water
// pressure family. The World owns all authoritative state (per-cell sidecar and
// the gas-compartment table); these types are immutable snapshots for owners,
// tests and adapters. The C64-E8 Cell layout is unchanged (Gate B handoff).
namespace cybersand {

// Declared, versioned family constants. Anything a request may change lives in
// PressureFlowParameters and is recorded in the receipt; the rest is fixed by v1.
struct PressureFlowParameters {
    static constexpr std::uint16_t kVersion = 1;
    // Velocity fixed point: |flow| == kFlowScale moves the whole cell quantity per tick.
    static constexpr std::int32_t kFlowScale = 1024;
    // Gas regions larger than this many Empty cells are the vented atmosphere.
    static constexpr std::uint32_t kCompartmentVolumeLimit = 16384;
    static constexpr std::size_t kCompartmentCapacity = 1024;
    static constexpr std::size_t kHistoryCapacity = 64;
    static constexpr std::size_t kMaximumParents = 8;
    // Gas gauge pressure saturates at this many mass units (declared bound).
    static constexpr std::int64_t kHeadLimit = std::int64_t{1} << 30;
    // Lateral acceleration: flow += head_difference * kAccelNumerator / (maximum * kAccelDenominator).
    static constexpr std::int32_t kAccelNumerator = 3;
    static constexpr std::int32_t kAccelDenominator = 1;
    // Overfill compressibility: one overfill unit raises the head by this many
    // maximum()-mass units (one row of saturated Water per unit).
    static constexpr std::int32_t kOverfillStiffnessRows = 0;
    // Constant velocity loss per tick (deterministic Coulomb friction).
    static constexpr std::int32_t kFriction = 0;
    // Retained velocity per tick, out of 256.
    static constexpr std::int32_t kRetain = 256;
    // Head dead bands (in 1/255 of a full cell, scaled by maximum()). The start
    // band is static friction: it must exceed the gauge noise of integer gas
    // amounts (one unit in a V-cell pocket is atmospheric_head_rows / V rows).
    static constexpr std::int32_t kStartDeadBand255 = 128;
    static constexpr std::int32_t kMovingDeadBand255 = 10;

    bool gas_enabled = true;
    std::int32_t atmospheric_head_rows = 32;

    [[nodiscard]] friend bool operator==(const PressureFlowParameters&, const PressureFlowParameters&) = default;
};

// Authoritative per-cell candidate state. Overfill only exists on a saturated
// Water cell; flow only on Water; gas labels only on Empty cells.
struct PressureCellState {
    bool available = false;      // false when the World has no pressure family
    std::uint16_t overfill = 0;  // quantity above maximum(), never rendered
    std::int16_t flow = 0;       // signed horizontal velocity, kFlowScale fixed point
    std::uint32_t gas = 0;       // 0 unresolved, kVacuumLabel, kAtmosphereLabel or a compartment id
};

// Read-only derived head-slot diagnostic, copied by the serialized World owner.
// This is the last pre-kernel prepared field, not current cell authority: later
// transport, host writes or restore can leave it stale/unprepared. NoHead is
// distinct from a valid zero head. Unresolved exposes the encoded temporary
// interpolation sentinel rather than treating it as a physical numeric head.
enum class PressureHeadStatus : std::uint8_t {
    FamilyUnavailable = 0,
    NonResident = 1,
    NoHead = 2,
    Unresolved = 3,
    Prepared = 4,
};

struct PressureHeadSnapshot {
    PressureHeadStatus status = PressureHeadStatus::FamilyUnavailable;
    std::int32_t head = 0;  // Water mass units only when status == Prepared
    friend bool operator==(const PressureHeadSnapshot&, const PressureHeadSnapshot&) = default;
};

// Label of an Empty cell vented to the atmosphere at the last resolution.
inline constexpr std::uint32_t kAtmosphereLabel = 0xFFFFFFFFU;
// Label of an Empty cell a kernel vacated since the last resolution (Water or
// another material left it): it adds volume but no gas amount. Label 0 is an
// unresolved cell (host-built or host-erased), atmospheric when first sealed.
inline constexpr std::uint32_t kVacuumLabel = 0xFFFFFFFEU;

enum class GasRetireReason : std::uint8_t {
    Merged = 1,
    Split = 2,
    Vented = 3,
    Collapsed = 4,
};

struct GasCompartmentSnapshot {
    std::uint32_t id = 0;
    std::uint32_t generation = 0;
    std::array<std::uint32_t, PressureFlowParameters::kMaximumParents> parents{};
    std::uint8_t parent_count = 0;
    std::uint64_t amount = 0;   // atmospheric cell-equivalents; identity is never derived from it
    std::uint64_t volume = 0;   // Empty cells (only Empty cells count)
    std::int64_t anchor_x = 0;  // lowest (y, x) cell of the compartment
    std::int64_t anchor_y = 0;
    std::uint64_t created_tick = 0;
    std::uint64_t revision = 0;  // topology revision of the last change to this compartment
    std::int64_t gauge = 0;      // derived gauge pressure in Water mass units
};

struct GasHistoryRecord {
    GasCompartmentSnapshot compartment;
    GasRetireReason reason = GasRetireReason::Merged;
    std::array<std::uint32_t, PressureFlowParameters::kMaximumParents> successors{};
    std::uint8_t successor_count = 0;
    std::uint64_t tick = 0;
};

// Exact signed gas accounting. amount_live == created + absorbed - vented - collapsed.
struct GasLedger {
    std::uint64_t created = 0;    // new compartments at atmospheric amount
    std::uint64_t absorbed = 0;   // atmosphere cells sealed into an existing compartment
    std::uint64_t vented = 0;     // amount returned to the atmosphere on venting
    std::uint64_t collapsed = 0;  // amount booked to the collapse sink (volume reached zero)
    std::uint64_t merges = 0;
    std::uint64_t splits = 0;
    std::uint64_t creations = 0;
    std::uint64_t vents = 0;
    std::uint64_t collapses = 0;
    std::uint64_t amount_live = 0;
};

// Exact Water and momentum accounting for the pressure family.
struct PressureFlowLedger {
    std::uint64_t overfill_converted = 0;  // overfill retired when its Water cell changed material in a kernel
    std::uint64_t overfill_external = 0;   // overfill removed by an external write (paint, erase, event)
    std::int64_t flow_remainder = 0;       // signed velocity-merge truncation remainder (numerator sum)
    std::uint64_t contact_loss = 0;        // |flow| removed at closed faces
    std::uint64_t relief_cells = 0;        // Water cells created by overfill relief
};

struct PressureFlowDiagnostics {
    std::uint64_t head_cells = 0;       // Water cells given a head this tick
    std::uint64_t unknown_heads = 0;    // lidded cells resolved by row interpolation/continuation
    std::uint64_t gas_visited = 0;      // Empty cells visited by topology resolution
    std::uint64_t gas_regions = 0;
    std::uint64_t atmosphere_regions = 0;
    std::uint64_t chunk_allocations = 0;  // non-resident chunks made resident for a sealed region
    std::uint64_t woken_blocks = 0;     // sleeping blocks woken by an actionable head gradient
};

}  // namespace cybersand
