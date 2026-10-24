#pragma once

#include <cstdint>

// LCB-005 (#212) inertial_cellular_v1/reference: declared parameters and value
// types for the opt-in inertial liquid family (`inertial-update-v1`, executable
// contract tools/lcb/inertial_contract.py). Velocity and accumulators are signed
// integers in q units per cell, stored in optional solver-owned per-cell state;
// the C64-E8 Cell is unchanged.
namespace cybersand {

struct InertialParameters {
    static constexpr std::uint16_t kVersion = 1;
    static constexpr std::int32_t kQ = 16;            // velocity/accumulator units per cell
    static constexpr std::int32_t kGravity = 4;       // +vy per tick, exactly once
    // Per-component saturation. vmax / q = 2 cells per axis per tick keeps every
    // travel write inside the World's rule radius 2 (the contract's illustrative
    // 64 would travel 4 cells and exceed it).
    static constexpr std::int32_t kVmax = 32;
    static constexpr std::int32_t kTurnNumerator = 1, kTurnDenominator = 8;
    static constexpr std::int32_t kDeflectNumerator = 3, kDeflectDenominator = 4;
    static constexpr std::int32_t kDampingNumerator = 1, kDampingDenominator = 16;
    static constexpr std::int32_t kDragNumerator = 1, kDragDenominator = 4;
    static constexpr std::int32_t kRest = 1;
};

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
    std::int64_t impulse_x = 0;  // every non-gravity signed impulse
    std::int64_t impulse_y = 0;
    std::int64_t loss = 0;       // non-negative L1 speed loss (support constraint included)
    std::int64_t support = 0;    // the support-constraint part of loss
    std::int64_t remainder = 0;  // audited truncation numerators (never state)
    std::uint64_t updates = 0;
    std::uint64_t unit_moves = 0;
    std::uint64_t density_swaps = 0;
    std::uint64_t contacts = 0;
    std::uint64_t rests = 0;
    std::uint64_t velocity_retired = 0;  // |v| removed when an inertial cell changed material
    std::int64_t retired_x = 0;          // signed velocity removed by material changes/paint
    std::int64_t retired_y = 0;
    std::int64_t external_x = 0;         // signed velocity set by the diagnostic owner API
    std::int64_t external_y = 0;
};

}  // namespace cybersand
