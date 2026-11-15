#pragma once

#include <cstdint>

// WAVE-MT-001 wave_flow_v1 (experimental, opt-in): a bulk, strip-parallel Water
// law with retained face flux. It replaces the per-cell Water kernel for the
// World that enables it; no pressure head field, flood fill, gas topology or
// compartment state exists. Disabled is the default and allocates nothing.
//
// The law and its evidence are described in docs/architecture/wave-flow-v1.md.
namespace cybersand {

struct WaveFlowParameters {
    static constexpr std::uint16_t kVersion = 1;
    static constexpr std::int32_t kFluxShift = 12;      // flux sub-units per mass unit
    static constexpr std::int32_t kActiveRows = 32;     // rows below a surface that respond to head
    static constexpr std::int32_t kGain = 32;           // sub-units per unit of head per tick
    static constexpr std::int32_t kGainConfined = 4;    // sealed stacks accelerate 8x slower...
    static constexpr std::int32_t kStiffness = 256;     // ...so their overfill can be 8x stiffer
    static constexpr std::int32_t kDampShift = 7;       // flux loses 1/128 per tick
    static constexpr std::int32_t kCoast = 16;          // units a face may carry on inertia alone
    static constexpr std::int32_t kLevelShift = 9;      // share of a head difference moved per row
    static constexpr std::int32_t kSleepAfter = 30;     // quiet ticks before a chunk stops being solved
    static constexpr std::int32_t kWakePeak = 2;        // smallest per-cell change that counts as motion
    static constexpr std::int32_t kMaximumMass = 32'000; // overfill ceiling of the uint16 carrier
    static constexpr std::uint8_t kMaximumSubsteps = 8;
};

struct WaveFlowConfig {
    bool enabled = false;
    // Complete column/flux/apply rounds per World tick. Each round is one
    // stable explicit step, so N rounds make every transport speed N times
    // larger at N times the Water cost.
    std::uint8_t substeps = 1;
    [[nodiscard]] bool operator==(const WaveFlowConfig&) const = default;
};

// Cumulative, diagnostic only. Times are wall-clock inside World::tick.
struct WaveFlowDiagnostics {
    std::uint64_t ticks = 0;
    std::uint64_t rounds = 0;
    std::uint64_t tasks = 0;            // strip tasks dispatched (all passes)
    std::uint64_t solved_chunks = 0;    // chunk visits (one per chunk per tick)
    std::uint64_t moved_units = 0;      // lateral mass units transferred
    std::uint64_t prepare_nanoseconds = 0;
    std::uint64_t column_nanoseconds = 0;
    std::uint64_t flux_nanoseconds = 0;
    std::uint64_t apply_nanoseconds = 0;
    std::uint64_t merge_nanoseconds = 0;
    std::uint32_t last_tasks = 0;        // strip tasks per pass in the last tick
    std::uint32_t last_solved_chunks = 0;
    std::uint32_t maximum_participants = 0; // distinct pool workers in one dispatch
    std::uint64_t storage_bytes = 0;     // solver-owned side storage currently allocated
};

}  // namespace cybersand
