#pragma once

#include <cstdint>

namespace cybersand {

// WAVE-MT-001 fixed-point representation and the qualified v2 tuning point.
// Workbench authoring may vary the corresponding WaveFlowConfig fields inside
// the explicit bounds below. Representation/safety constants stay fixed.
struct WaveFlowParameters {
    static constexpr std::uint16_t kVersion = 2;
    static constexpr std::int32_t kFluxShift = 12;
    static constexpr std::int32_t kActiveRows = 32;
    static constexpr std::int32_t kGain = 32;
    static constexpr std::int32_t kGainConfined = 4;
    static constexpr std::int32_t kStiffness = 256;
    static constexpr std::int32_t kDampShift = 7;
    static constexpr std::int32_t kCoast = 16;
    static constexpr std::int32_t kLevelShift = 3;
    static constexpr std::int32_t kSleepAfter = 30;
    static constexpr std::int32_t kWakePeak = 1;
    static constexpr std::int32_t kRestHead = 1;
    static constexpr std::int32_t kStick = 512;
    static constexpr std::int32_t kCalm = 512;
    static constexpr std::int32_t kCalmDampShift = 3;
    static constexpr std::int32_t kMaximumMass = 32'000;
    static constexpr std::int32_t kEmptyPourShift = 2;
    static constexpr std::int32_t kFlowShareShift = 1;
    static constexpr std::int32_t kAdhesionShift = 1;
    static constexpr std::int32_t kMaximumHead = 1 << 26;
    static constexpr std::int32_t kMaximumSubsteps = 8;
    static constexpr std::int32_t kMaximumActiveRows = 32;
    static constexpr std::int32_t kMaximumGain = 512;
    static constexpr std::int32_t kMaximumStiffness = 4096;
    static constexpr std::int32_t kMaximumDampingShift = 16;
    static constexpr std::int32_t kMaximumCoast = 65535;
    static constexpr std::int32_t kMaximumLevelShift = 16;
    static constexpr std::int32_t kMaximumSleepAfter = 3600;
    static constexpr std::int32_t kMaximumWakePeak = 65535;
    static constexpr std::int32_t kMaximumRestHead = 65535;
    static constexpr std::int32_t kMaximumStick = 65535;
    static constexpr std::int32_t kMaximumCalm = 65535;
    static constexpr std::int32_t kMaximumTunedMass = 65535;
    static constexpr std::int32_t kMaximumPourShift = 8;
    static constexpr std::int32_t kMaximumAdhesionShift = 8;
};

struct WaveFlowConfig {
    bool enabled = false;
    std::int32_t substeps = 1;
    std::int32_t active_rows = WaveFlowParameters::kActiveRows;
    std::int32_t gain = WaveFlowParameters::kGain;
    std::int32_t gain_confined = WaveFlowParameters::kGainConfined;
    std::int32_t stiffness = WaveFlowParameters::kStiffness;
    std::int32_t damp_shift = WaveFlowParameters::kDampShift;
    std::int32_t coast = WaveFlowParameters::kCoast;
    std::int32_t level_shift = WaveFlowParameters::kLevelShift;
    std::int32_t sleep_after = WaveFlowParameters::kSleepAfter;
    std::int32_t wake_peak = WaveFlowParameters::kWakePeak;
    std::int32_t rest_head = WaveFlowParameters::kRestHead;
    std::int32_t stick = WaveFlowParameters::kStick;
    std::int32_t calm = WaveFlowParameters::kCalm;
    std::int32_t calm_damp_shift = WaveFlowParameters::kCalmDampShift;
    std::int32_t maximum_mass = WaveFlowParameters::kMaximumMass;
    std::int32_t empty_pour_shift = WaveFlowParameters::kEmptyPourShift;
    std::int32_t flow_share_shift = WaveFlowParameters::kFlowShareShift;
    std::int32_t adhesion_shift = WaveFlowParameters::kAdhesionShift;
    [[nodiscard]] bool operator==(const WaveFlowConfig&) const = default;
};

struct WaveFlowDiagnostics {
    std::uint64_t ticks = 0, rounds = 0, tasks = 0, solved_chunks = 0, moved_units = 0;
    std::uint64_t prepare_nanoseconds = 0, column_nanoseconds = 0, flux_nanoseconds = 0;
    std::uint64_t apply_nanoseconds = 0, merge_nanoseconds = 0, storage_bytes = 0, capacity_refusals = 0;
    std::uint32_t maximum_participants = 0, last_tasks = 0, last_solved_chunks = 0;
    [[nodiscard]] bool operator==(const WaveFlowDiagnostics&) const = default;
};

}  // namespace cybersand
