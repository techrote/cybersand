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
    // 2: low-discrepancy transfer rounding, the rest rule and direct film
    // levelling. Version 1 Water never came to rest once disturbed.
    static constexpr std::uint16_t kVersion = 2;
    static constexpr std::int32_t kFluxShift = 12;      // flux sub-units per mass unit
    static constexpr std::int32_t kActiveRows = 32;     // rows below a surface that respond to head
    static constexpr std::int32_t kGain = 32;           // sub-units per unit of head per tick
    static constexpr std::int32_t kGainConfined = 4;    // sealed stacks accelerate 8x slower...
    static constexpr std::int32_t kStiffness = 256;     // ...so their overfill can be 8x stiffer
    static constexpr std::int32_t kDampShift = 7;       // flux loses 1/128 per tick
    static constexpr std::int32_t kCoast = 16;          // units a face may carry on inertia alone
    // A face may level 1/2^(kLevelShift + d) of its head difference per round,
    // d = ceil(log2(responding rows)) <= 5: 1/8 for one row, 1/256 for 32.
    static constexpr std::int32_t kLevelShift = 3;
    // A chunk stops being solved after this many consecutive ticks in which no
    // cell changed and every retained flux was zero. That is a fixed point of
    // the law: solving the chunk again would change nothing.
    static constexpr std::int32_t kSleepAfter = 30;
    static constexpr std::int32_t kWakePeak = 1;        // even one conserved unit must finish travelling
    // Rest. Whole units cannot level a one-unit step between two cells (moving
    // one only flips it), so a face whose heads differ by at most kRestHead
    // discards a flux below kStick. Flux below kCalm (an eighth of a unit per
    // round) loses 1/8 per round instead of 1/128: the residue of rounding to
    // whole units is absorbed, while a real wave is in that range only near
    // its turning points, where its energy is in the heads.
    static constexpr std::int32_t kRestHead = 1;
    static constexpr std::int32_t kStick = 512;
    static constexpr std::int32_t kCalm = 512;
    static constexpr std::int32_t kCalmDampShift = 3;
    static constexpr std::int32_t kMaximumMass = 32'000; // stop inflow to a sealed stack at this threshold
    static constexpr std::int32_t kEmptyPourShift = 2;
    static constexpr std::int32_t kFlowShareShift = 1;
    static constexpr std::int32_t kAdhesionShift = 1;
    static constexpr std::int32_t kMaximumHead = 1 << 26; // bounded derived head for extreme sealed columns
    static constexpr std::uint8_t kMaximumSubsteps = 8;

    // Workbench authoring bounds. These bound kinetic tuning without exposing
    // fixed-point representation or allowing one donor to overdraw through
    // two opposing faces in a single apply pass.
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

// WAVE-WATERWALL-001 exposed-face spill (experimental, off by default). An
// approximation, not physics: Water resting beside open air discharges through
// that face at a share of the cell per round, unsupported Water falls several
// cells per round and stays a coherent stream unless it is dense, and bulk
// flow running down a real surface slope may exceed the wave coast limit.
// No storage is added; every transfer uses the existing conserved faces.
struct WaveSpillConfig {
    static constexpr std::int32_t kMaximumFall = 8;
    static constexpr std::int32_t kMaximumShareShift = 8;
    static constexpr std::int32_t kMaximumDraw = 127;
    static constexpr std::int32_t kMaximumDrawHead = 65535;
    static constexpr std::int32_t kMaximumStream = 255;
    static constexpr std::int32_t kMaximumLaunchBudget = 4096;
    static constexpr std::int32_t kMaximumLaunchSpeed = 512;
    static constexpr std::uint32_t kLaunchCandidatesPerTask = 512;
    bool enabled = false;
    std::int32_t fall = 3;         // cells unsupported Water falls per round, 1..8
    std::int32_t share_shift = 1;  // an exposed face sheds 1/2^n of its cell per round, 1..8
    std::int32_t draw = 64;        // units per round a bulk face may carry, 0..127 (0: coast only)
    std::int32_t draw_head = 255;  // adverse head (mass units) above which the coast limit applies again
    std::int32_t stream = 128;     // falling Water denser than this (mass units) spreads sideways, 0..255
    // Hybrid release, used only when ballistic_water_v1 is enabled on the same
    // World: an exposed face beside Empty air hands its share to one ballistic
    // parcel thrown outward at launch_speed / 256 of sqrt(2 g h), instead of
    // moving it through the face. Bounded per tick; a refused or deferred
    // launch leaves the Water in its cell and the next tick spills natively.
    std::int32_t launch_min = 16;      // smallest share (mass units) worth a parcel, 1..255
    std::int32_t launch_budget = 256;  // parcels launched per tick, 0..4096 (0: never launch)
    std::int32_t launch_speed = 256;   // / 256 of sqrt(2 g h), 0..512
    // Look controls for the release:
    std::int32_t stream_share = 0;     // n/256 of each thrown face share keeps pouring as a vertical grid stream, 0..255
    std::int32_t catch_falling = 1;    // 1: parcels older than the self-contact grace merge into falling Water (blobs); 0: they pass through
    [[nodiscard]] bool operator==(const WaveSpillConfig&) const = default;
};

struct WaveFlowConfig {
    bool enabled = false;
    // Keep the historical byte width: the physical hash binds integer width.
    std::uint8_t substeps = 1;
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
    WaveSpillConfig spill{};
    [[nodiscard]] bool operator==(const WaveFlowConfig&) const = default;
};

// Cumulative, diagnostic only. Times are wall-clock inside World::tick.
// Preserve the qualified-v2 member order; Workbench tuning does not alter this
// diagnostic structure's existing layout.
struct WaveFlowDiagnostics {
    std::uint64_t ticks = 0;
    std::uint64_t rounds = 0;
    std::uint64_t tasks = 0;            // strip tasks dispatched (all passes)
    std::uint64_t solved_chunks = 0;    // chunk visits (one per chunk per tick)
    std::uint64_t moved_units = 0;      // lateral mass units transferred
    std::uint64_t capacity_refusals = 0; // missing neighbour admissions refused; quantity stays resident
    std::uint64_t boundary_refusals = 0; // coordinate-fringe neighbours treated as walls
    std::uint64_t prepare_nanoseconds = 0;
    std::uint64_t column_nanoseconds = 0;
    std::uint64_t flux_nanoseconds = 0;
    std::uint64_t apply_nanoseconds = 0;
    std::uint64_t merge_nanoseconds = 0;
    std::uint32_t last_tasks = 0;        // strip tasks per pass in the last tick
    std::uint32_t last_solved_chunks = 0;
    std::uint32_t maximum_participants = 0; // distinct pool workers in one dispatch
    std::uint64_t storage_bytes = 0;     // solver-owned side storage currently allocated
    // WAVE-WATERWALL-001 spill, appended; all zero while spill is disabled.
    std::uint64_t spill_units = 0;       // mass units moved through exposed faces (resting donor, open receiver)
    std::uint64_t relief_units = 0;      // mass units dense falling Water shed sideways
    std::uint64_t spill_faces = 0;       // exposed-face transfers (face-rounds that moved at least one unit)
    std::uint64_t last_falling_units = 0; // Water mass that was unsupported in the last round
    std::uint64_t last_falling_cells = 0;
    std::uint64_t launched_parcels = 0;  // hybrid: exposed-face shares handed to ballistic parcels
    std::uint64_t launched_units = 0;
    std::uint64_t launch_refusals = 0;   // launches the parcel owner refused (capacity, spawn cell); Water stayed
    std::uint64_t launch_deferrals = 0;  // nominated faces beyond the per-tick budget or the per-strip list
    std::uint64_t launch_nanoseconds = 0;
    std::uint64_t launch_capacity_skips = 0; // ticks with no free parcel slot; exposed faces spilled through the grid
};

}  // namespace cybersand
