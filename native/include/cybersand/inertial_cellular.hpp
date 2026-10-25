#pragma once

#include "cybersand/sha256.hpp"
#include "cybersand/liquid_solver_policy.hpp"
#include <cstddef>
#include <cstdint>
#include <initializer_list>

// LCB-005 (#212) inertial_cellular_v1/reference: declared parameters and value
// types for the opt-in inertial liquid family (`inertial-update-v1`, executable
// contract tools/lcb/inertial_contract.py). Velocity and accumulators are signed
// integers in q units per cell, stored in optional solver-owned per-cell state;
// the C64-E8 Cell is unchanged.
namespace cybersand {

struct InertialParameters {
    static constexpr std::uint16_t kVersion = 1;
    static constexpr std::int32_t kQ = 16;      // velocity/accumulator units per cell
    static constexpr std::int32_t kGravity = 4; // +vy per tick, exactly once
    // Travel writes reach two cells; final support/contact reads reach three.
    // Every IN World explicitly admits the complete radius-three domain.
    static constexpr std::int32_t kVmax = 32;
    static constexpr std::int32_t kTurnNumerator = 1, kTurnDenominator = 8;
    static constexpr std::int32_t kDeflectNumerator = 3, kDeflectDenominator = 4;
    static constexpr std::int32_t kDampingNumerator = 1, kDampingDenominator = 16;
    static constexpr std::int32_t kDragNumerator = 1, kDragDenominator = 4;
    static constexpr std::int32_t kExecutionRadius = 3;
    static constexpr std::int32_t kRest = 1;
    static constexpr std::uint16_t kFamilyBlockVersion = LiquidPolicyBuild::kInertialBlockVersion;
    std::int32_t damping_numerator = kDampingNumerator;
    [[nodiscard]] bool operator==(const InertialParameters&) const = default;
};

// The policy decoder checks this optional native v2 schema before installation.
// Keep its interpretation shared by construction and pre-install CYPS identity.
[[nodiscard]] inline InertialParameters inertial_parameters_for_policy(const LiquidSolverPolicy& policy) {
    InertialParameters result;
    for (const auto& block : policy.family_blocks()) {
        if (block.owner != static_cast<std::uint16_t>(LiquidSolverFamily::InertialCellularV1)) continue;
        if (block.version != InertialParameters::kFamilyBlockVersion || block.values.size() != 1U ||
            block.values[0] < 0 || block.values[0] > InertialParameters::kDampingDenominator)
            throw std::invalid_argument("unsupported IN damping parameter block");
        result.damping_numerator = block.values[0];
    }
    return result;
}

// Authoritative per-cell state (only on a cell whose material runs inertial).
struct InertialCellState {
    bool available = false;
    std::int16_t vx = 0;
    std::int16_t vy = 0;
    std::int8_t ax = 0;
    std::int8_t ay = 0;
};

// Exact per-component momentum and separate L1 speed-loss accounting:
//   sum(v_after - v_before) == gravity + sum(impulses)  (per component)
//   sum(|v_after| - |v_before|) == gravity_y - sum(loss)
struct InertialLedger {
    std::int64_t gravity_y = 0;
    std::int64_t impulse_x = 0; // every non-gravity signed impulse
    std::int64_t impulse_y = 0;
    std::int64_t loss = 0;      // non-negative L1 speed loss (support constraint included)
    std::int64_t support = 0;   // the support-constraint part of loss
    std::int64_t remainder = 0; // audited truncation numerators (never state)
    std::uint64_t updates = 0;
    std::uint64_t unit_moves = 0;
    std::uint64_t density_swaps = 0;
    std::uint64_t contacts = 0;
    std::uint64_t rests = 0;
    std::uint64_t velocity_retired = 0; // |v| removed when an inertial cell changed material
    std::int64_t retired_x = 0;         // signed velocity removed by material changes/paint
    std::int64_t retired_y = 0;
    std::int64_t external_x = 0; // signed velocity set by the diagnostic owner API
    std::int64_t external_y = 0;
    std::uint64_t maximum_read_reach = 0, maximum_write_reach = 0;
    std::int64_t external_speed = 0; // signed change of L1 speed, before aggregation
    [[nodiscard]] bool operator==(const InertialLedger &) const = default;
};

struct InertialStorageUsage {
    std::size_t slot_size = 0, slot_alignment = 0;
    std::size_t resident_chunks = 0, slot_capacity = 0, nonzero_slots = 0;
    std::size_t slot_bytes = 0, owner_bytes = 0, job_ledger_bytes = 0, world_state_bytes = 0;
    // Sum of declared components; excludes allocator metadata, shared World
    // resources, padding between members and process RSS.
    std::size_t total_component_bytes = 0;
};

// Binds fields, units, actual damping, fixed law, execution reach and update order.
// Canonical LE int32 values follow the domain; independent of C++ padding.
[[nodiscard]] inline Sha256::Digest inertial_extension_identity(InertialParameters parameters = {}) noexcept {
    Sha256 hash;
    constexpr char domain[] = "cybersand-inertial-update-v1-state-v1-identity-v1";
    hash.update({reinterpret_cast<const std::uint8_t *>(domain), sizeof(domain) - 1U});
    using P = InertialParameters;
    for (const std::int32_t value :
         {16, 16, 8, 8, P::kQ, P::kGravity, P::kVmax, P::kTurnNumerator, P::kTurnDenominator,
          P::kDeflectNumerator, P::kDeflectDenominator, parameters.damping_numerator, P::kDampingDenominator,
          P::kDragNumerator, P::kDragDenominator, P::kRest, P::kExecutionRadius}) {
        std::array<std::uint8_t, 4> bytes{};
        for (unsigned i = 0; i < 4; ++i)
            bytes[i] = static_cast<std::uint8_t>(static_cast<std::uint32_t>(value) >> (8U * i));
        hash.update(bytes);
    }
    return hash.finish();
}

} // namespace cybersand
