// WAVE-MT-001 wave_flow_v1: bulk strip-parallel Water law (included by world.cpp).
//
// One round is three barriers over disjoint column strips:
//   column  settle each column (gravity, refill, overfill) and derive the
//           weight-above head of every cell; writes only its own columns;
//   flux    update the retained flux on each cell's right face from the head
//           difference; writes only its own faces, reads settled neighbours;
//   apply   move the whole-unit part of every flux; both sides of a face
//           evaluate the same pure function, so mass is conserved exactly.
// No pass depends on task order, so the result is identical for every worker
// count. A chunk stops being solved once it is at exact rest (no cell changed
// and every retained flux is zero) and is solved again when woken.

// Per-strip result of one tick for half of a chunk; reduced by the owner.
struct World::WaveHalf {
    std::int32_t min_x = 0, min_y = 0, max_x = -1, max_y = -1;
    std::int32_t peak = 0;
    std::int32_t non_empty_delta = 0;
    std::uint64_t moved = 0;
    std::uint64_t changed = 0;
    std::uint32_t invalid = 0;
    std::uint32_t transitions = 0; // cells that became or stopped being Water
    // Spill diagnostics; written only by the strip that owns this half.
    std::uint64_t spill_units = 0, relief_units = 0, spill_faces = 0;
    std::uint64_t falling_units = 0, falling_cells = 0;
    bool pending_flux = false;
    // Candidate rows for floating Oil to spread or follow a rising/falling Water surface.
    std::int32_t oil_first = std::numeric_limits<std::int32_t>::max(), oil_last = -1;
    // Separate neighbouring writers without over-aligning WaveChunk. C++17
    // aligned allocation imports CXXABI_1.3.11, above the Linux runtime floor.
    // A full cache line between counter sets works with ordinary allocation.
    std::array<std::uint8_t, 64> separation{};
    void touch(std::int32_t x, std::int32_t y) noexcept {
        if (max_x < min_x) { min_x = max_x = x; min_y = max_y = y; return; }
        min_x = std::min(min_x, x); max_x = std::max(max_x, x);
        min_y = std::min(min_y, y); max_y = std::max(max_y, y);
    }
};

struct World::WaveChunk {
    static constexpr std::uint8_t kGainMask = 3, kGainNormal = 1, kGainConfined = 2;
    static constexpr std::uint8_t kFull = 4, kSolid = 8, kWet = 16;
    // Gain bits are unused on solid faces. Keep a floating Oil lid distinct
    // from a rigid ceiling when a column continues from a sleeping chunk.
    static constexpr std::uint8_t kOilLid = kSolid | kGainNormal;
    // Bits 5-7: ceil(log2) of the responding rows of the cell's stack (0..5).
    static constexpr std::uint8_t kDepthShift = 5;
    static constexpr std::uint8_t kSaturated = 7; // depth code of a stack at the carrier ceiling
    // Spill only: depth code of a wet cell that nothing supports (it is falling).
    // Such a cell carries no hydrostatic head and never reports kFull.
    static constexpr std::uint8_t kFalling = 6;
    explicit WaveChunk(std::size_t count, std::size_t columns, bool smooth)
        : flux(count, 0), prior_flux(smooth ? count : 0U), weight(count, 0), meta(count, 0), dry(columns, 0) {}
    std::vector<std::int32_t> flux;   // authoritative: retained flux through the right face
    std::vector<std::int32_t> prior_flux; // derived snapshot, refilled by the column pass before every flux pass
    std::vector<std::int32_t> weight; // derived: head above the cell floor, in mass units
    std::vector<std::uint8_t> meta;   // derived: gain code, full, solid, wet
    Chunk* left = nullptr;            // solved neighbours this tick, else null
    Chunk* right = nullptr;
    Chunk* above = nullptr;           // resident neighbour, solved or not
    Chunk* below = nullptr;
    bool right_paused = false;
    std::uint32_t quiet = 0;
    bool woken = true;
    bool active = false;
    bool solve = false;
    // Derived tick-local selected-core intersection, exclusive maxima.
    std::int32_t min_x = 0, min_y = 0, max_x = 0, max_y = 0;
    [[nodiscard]] bool included(std::int32_t x, std::int32_t y) const noexcept {
        return x >= min_x && x < max_x && y >= min_y && y < max_y;
    }
    [[nodiscard]] bool right_face_paused(std::int32_t x, std::int32_t columns) const noexcept {
        return x + 1 >= max_x && (max_x < columns || right_paused);
    }
    // A half that is entirely Empty with zeroed interior flux and derived
    // state. A face at the selected-region boundary can retain paused flux.
    // Its interior needs no work until something writes into it.
    std::array<bool, 2> clean{};
    // Derived cache only: actual cells are all Empty and weight/meta are zero.
    // Unlike clean, this makes no promise about retained or paused flux. The
    // allocated body-mask region may prevent clean/dry retirement even when
    // this half contains no occupied body cells. Never hash/serialize this
    // redundant certificate or use it to skip flux, apply or column physics.
    std::array<bool, 2> empty_derived{};
    // Per column: 0 unknown, 1 holds no Water (derived state is current),
    // 2 additionally holds nothing but Empty. A strip skips columns that are
    // dry in every chunk of its group. Each half owns its own columns.
    std::vector<std::uint8_t> dry;
    std::array<bool, 2> dry_reset{true, true};
    std::array<WaveHalf, 2> half{};
};

struct World::WaveState {
    struct Entry {
        ChunkCoord coord;
        Chunk* chunk = nullptr;
    };
    struct Task {
        std::uint32_t first = 0, count = 0;
        std::uint8_t half = 0;
    };
    // An exposed face nominated for a ballistic launch by its strip.
    struct Launch {
        std::int64_t x = 0, y = 0;   // donor cell
        std::int32_t head = 0;       // donor head in mass units
        std::int32_t quantity = 0;   // share to hand over
        std::int32_t side = 0;       // +1 right, -1 left
        std::int32_t crest_speed_q = -1; // horizontal carried speed, or -1 for ordinary spray
    };
    struct Scratch {
        std::vector<std::int32_t> mass, weight;
        std::vector<std::uint8_t> flags;
        std::vector<Launch> launch;      // fixed capacity; filled only in the last round
        std::uint64_t launch_overflow = 0;

        // The strip visits faces in vertical order. A full list must not
        // permanently exclude the bottom of a tall wall. For full-face mode
        // keep a deterministic reservoir sample; no worker allocates here.
        void nominate(const Launch& face, bool full_face, std::uint32_t round) noexcept {
            constexpr auto limit = WaveSpillConfig::kLaunchCandidatesPerTask;
            if (launch.size() < limit) {
                launch.push_back(face);
                return;
            }
            ++launch_overflow;
            if (full_face) {
                const auto seen = limit + launch_overflow;
                const auto slot = mix64((static_cast<std::uint64_t>(round) << 32U) ^ seen) % seen;
                if (slot < limit) launch[static_cast<std::size_t>(slot)] = face;
            }
        }
    };
    std::vector<Entry> sorted;
    std::vector<ChunkCoord> grow;
    std::vector<Task> tasks;
    std::vector<Scratch> scratch;
    std::int32_t maximum = 0, film = 0;
    // Hysteresis for the visible Oil/Water interface, in Water mass units.
    [[nodiscard]] std::int32_t oil_lift_threshold() const noexcept { return maximum + maximum / 2; }
    [[nodiscard]] std::int32_t oil_drop_threshold() const noexcept { return maximum / 4; }
    std::uint32_t round = 0;
    bool mask_present = false;
    // Exact occupied bounds, rebuilt by the exclusive owner before dispatch.
    // The configured mask region is storage capacity, often the whole canvas;
    // probing every cell of that allocation for one small body is redundant.
    // Keep the original region for dry/clean classification so this elides
    // only lookups known to return zero, without changing derived state.
    RectI64 occupied_mask_bounds{};
    // Hybrid release. `launch` and `final_round` are tick-local; `launch_backoff`
    // is carried state: the tick after a refused or deferred launch spills natively.
    bool launch = false, final_round = false, launch_backoff = false;
    WaveFlowDiagnostics diagnostics{};
};

namespace {

[[nodiscard]] bool wave_chunk_coordinate_fits(ChunkCoord coord, std::int32_t size) noexcept {
    // Keep a whole chunk of arithmetic headroom for neighbour/core halos.
    // Explicitly refuse the extreme int64 fringe instead of wrapping it into
    // a distant resident chunk when the moving front requests a neighbour.
    const auto minimum = std::numeric_limits<std::int64_t>::min() / size + 1;
    const auto maximum = (std::numeric_limits<std::int64_t>::max() - (size - 1)) / size - 1;
    return coord.x >= minimum && coord.x <= maximum && coord.y >= minimum && coord.y <= maximum;
}

// Clip one positive-length mask axis to a strip's bounded local indices. The
// signed ordering makes each unsigned subtraction the exact nonnegative
// distance, even when the origins are more than INT64_MAX apart. Never form a
// global endpoint: an accepted mask may extend beyond the signed coordinate
// range, while only its representable occupied cells can be accessed.
[[nodiscard]] std::array<std::int32_t, 2> wave_clip_mask_axis(
    std::int64_t origin, std::int32_t count, std::int64_t start, std::int64_t extent) noexcept {
    const auto span = static_cast<std::uint64_t>(count);
    const auto length = static_cast<std::uint64_t>(extent);
    if (start >= origin) {
        const auto distance = static_cast<std::uint64_t>(start) - static_cast<std::uint64_t>(origin);
        const auto first = std::min(distance, span);
        const auto last = first + std::min(length, span - first);
        return {static_cast<std::int32_t>(first), static_cast<std::int32_t>(last)};
    }
    const auto distance = static_cast<std::uint64_t>(origin) - static_cast<std::uint64_t>(start);
    const auto last = distance >= length ? std::uint64_t{0} : std::min(length - distance, span);
    return {0, static_cast<std::int32_t>(last)};
}

// Whole mass units moved through a face in one round. The sub-unit part of the
// flux is resolved by a stateless additive threshold sequence over rows and
// rounds, with a per-column offset. For a constant flux, the average transfer
// over all 4096 round phases equals that flux. A single column's aggregate can
// still differ from its rounded total in a given round. Spreading the thresholds
// reduces the observed sampling noise without moving identical rows in lockstep;
// independent random rounding had kept disturbed pools sloshing indefinitely.
[[nodiscard]] inline std::int32_t wave_transfer(std::int32_t flux, std::int64_t x, std::int64_t y,
                                                std::uint32_t round) noexcept {
    if (flux == 0) return 0;
    std::uint32_t k = static_cast<std::uint32_t>(x) * 73856093U;
    k ^= k >> 15;
    k *= 0x2C1B3C6DU;
    k ^= k >> 12;
    k += static_cast<std::uint32_t>(y) * 3093U + round * 2333U;
    return (flux + static_cast<std::int32_t>(k & 4095U)) >> WaveFlowParameters::kFluxShift;
}

// Wave Worlds already refuse physical serialization. Bind the new law and its
// live flight countdowns in both Wave hashes, without changing historical streams.
void hash_wave_discharge(std::uint64_t& hash, const WaveSpillConfig& spill,
                         std::span<const BallisticParcel> parcels) {
    if (spill.deep_draw != 0) {
        for (const char c : std::string_view{"wave-deep-draw"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, spill.deep_draw);
    }
    if (spill.full_face != 0) {
        for (const char c : std::string_view{"wave-full-face-v1"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, spill.full_face);
    }
    if (spill.sheet_rate != 0) {
        for (const char c : std::string_view{"wave-sheet-rate"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, spill.sheet_rate);
    }
    if (spill.coyote_ticks != 0) {
        for (const char c : std::string_view{"wave-crest-flight"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, spill.coyote_ticks);
        hash_integer(hash, static_cast<std::uint64_t>(parcels.size()));
        for (const auto& parcel : parcels) hash_integer(hash, parcel.coyote_left);
    }
}

}  // namespace

void World::validate_wave_flow_config() const {
    if (!config_.wave_flow.enabled) return;
    using P = WaveFlowParameters;
    const auto& tune = config_.wave_flow;
    if (tune.substeps < 1 || tune.substeps > P::kMaximumSubsteps)
        throw std::invalid_argument("wave_flow substeps must be between 1 and 8");
    if (tune.active_rows < 1 || tune.active_rows > P::kMaximumActiveRows)
        throw std::invalid_argument("wave_flow active_rows must be between 1 and 32");
    if (tune.gain < 0 || tune.gain > P::kMaximumGain || tune.gain_confined < 0 || tune.gain_confined > P::kMaximumGain)
        throw std::invalid_argument("wave_flow gains outside 0..512");
    if (tune.floor_gain < 0 || tune.floor_gain > P::kMaximumFloorGain)
        throw std::invalid_argument("wave_flow floor_gain outside 0..4096");
    if (tune.deep_gain < 0 || tune.deep_gain > P::kMaximumGain)
        throw std::invalid_argument("wave_flow deep_gain outside 0..512");
    if (tune.flux_smoothing < 0 || tune.flux_smoothing > 64)
        throw std::invalid_argument("wave_flow flux_smoothing outside 0..64");
    if (tune.stiffness < tune.active_rows || tune.stiffness > P::kMaximumStiffness)
        throw std::invalid_argument("wave_flow stiffness must be at least active_rows and at most 4096");
    if (tune.damp_shift < 0 || tune.damp_shift > P::kMaximumDampingShift ||
        tune.calm_damp_shift < 0 || tune.calm_damp_shift > P::kMaximumDampingShift)
        throw std::invalid_argument("wave_flow damping shifts outside 0..16");
    if (tune.coast < 0 || tune.coast > P::kMaximumCoast || tune.level_shift < 0 || tune.level_shift > P::kMaximumLevelShift)
        throw std::invalid_argument("wave_flow coast/level tuning outside native bounds");
    if (tune.sleep_after < 1 || tune.sleep_after > P::kMaximumSleepAfter || tune.wake_peak < 0 || tune.wake_peak > P::kMaximumWakePeak)
        throw std::invalid_argument("wave_flow sleep/wake tuning outside native bounds");
    if (tune.rest_head < 0 || tune.rest_head > P::kMaximumRestHead || tune.stick < 0 || tune.stick > P::kMaximumStick ||
        tune.calm < 0 || tune.calm > P::kMaximumCalm)
        throw std::invalid_argument("wave_flow rest/calm tuning outside native bounds");
    if (tune.maximum_mass < config_.water_experiment_policy.maximum() || tune.maximum_mass > P::kMaximumTunedMass)
        throw std::invalid_argument("wave_flow maximum_mass outside the Water carrier range");
    if (tune.empty_pour_shift < 1 || tune.empty_pour_shift > P::kMaximumPourShift ||
        tune.flow_share_shift < 1 || tune.flow_share_shift > P::kMaximumPourShift ||
        tune.adhesion_shift < 0 || tune.adhesion_shift > P::kMaximumAdhesionShift)
        throw std::invalid_argument("wave_flow pour/share/adhesion shifts outside native bounds");
    if (tune.body_push < 0 || tune.body_push > 1024 || tune.body_push_by_mass < 0 || tune.body_push_by_mass > 1)
        throw std::invalid_argument("wave_flow body push outside 0..1024 or by-mass outside 0..1");
    if (tune.spill.enabled) {
        using S = WaveSpillConfig;
        if (tune.spill.fall < 1 || tune.spill.fall > S::kMaximumFall ||
            tune.spill.share_shift < 1 || tune.spill.share_shift > S::kMaximumShareShift ||
            tune.spill.draw < 0 || tune.spill.draw > S::kMaximumDraw ||
            tune.spill.deep_draw < 0 || tune.spill.deep_draw > S::kMaximumDraw ||
            tune.spill.draw_head < 0 || tune.spill.draw_head > S::kMaximumDrawHead ||
            tune.spill.stream < 0 || tune.spill.stream > S::kMaximumStream ||
            tune.spill.launch_min < 1 || tune.spill.launch_min > 255 ||
            tune.spill.launch_budget < 0 || tune.spill.launch_budget > S::kMaximumLaunchBudget ||
            tune.spill.launch_speed < 0 || tune.spill.launch_speed > S::kMaximumLaunchSpeed ||
            tune.spill.stream_share < 0 || tune.spill.stream_share > 255 ||
            tune.spill.catch_falling < 0 || tune.spill.catch_falling > 1 ||
            tune.spill.stream_draw < 0 || tune.spill.stream_draw > 255 ||
            tune.spill.sheet_rate < 0 || tune.spill.sheet_rate > 127 ||
            tune.spill.coyote_ticks < 0 || tune.spill.coyote_ticks > 8 ||
            tune.spill.full_face < 0 || tune.spill.full_face > 1)
            throw std::invalid_argument("wave_flow spill tuning outside native bounds");
    }
    if (config_.backend != SimulationBackend::PhasedInPlace)
        throw std::invalid_argument("wave_flow requires the phased in-place backend");
    if (config_.water_experiment_policy.mass_bits() != 8U)
        throw std::invalid_argument("wave_flow requires 8-bit fractional Water mass");
    const auto water = config_.liquid_solver_policy.assignment(static_cast<std::uint16_t>(Material::Water));
    if (!water || water->family != LiquidSolverFamily::FreeMassV1)
        throw std::invalid_argument("wave_flow requires Water assigned to freemass_v1 (the fractional carrier)");
    if (config_.chunk_size < 2 || config_.chunk_size % 2 != 0)
        throw std::invalid_argument("wave_flow requires an even chunk size");
    if (config_.settled_discovery_enabled)
        throw std::invalid_argument("wave_flow does not support settled discovery");
    // Generic ballistic_water_v1 (splashes, sprays, injected and body-launched
    // parcels) is admitted with or without spill: every parcel path respects
    // Wave overfill, paused cores and one-cell walls. Spill's hybrid release owns
    // exposed faces, so the WCX-FR per-cell face scan is refused only beside it.
    if (config_.ballistic_water.enabled && config_.ballistic_water.face_release && tune.spill.enabled)
        throw std::invalid_argument("wave_flow does not support ballistic face_release with spill; spill owns the release");
    if (config_.transport_policy.configured)
        throw std::invalid_argument("wave_flow does not support custom cellular transport policies");
}

bool World::wave_flow_enabled() const noexcept { return wave_ != nullptr; }

std::int32_t World::wave_flow_flux(std::int64_t x, std::int64_t y) const noexcept {
    if (wave_ == nullptr) return 0;
    const auto at = address(x, y);
    const auto* chunk = find_chunk(at.chunk);
    return chunk == nullptr ? 0 : chunk->wave->flux[at.index];
}

WaveFlowDiagnostics World::wave_flow_diagnostics() const noexcept {
    if (wave_ == nullptr) return {};
    auto result = wave_->diagnostics;
    for (const auto& [coord, chunk] : chunks_) {
        (void)coord;
        if (chunk->wave == nullptr) continue;
        result.storage_bytes += chunk->wave->flux.capacity() * sizeof(std::int32_t) +
                                (chunk->wave->weight.capacity() + chunk->wave->prior_flux.capacity()) * sizeof(std::int32_t) +
                                chunk->wave->meta.capacity() + chunk->wave->dry.capacity() + sizeof(WaveChunk);
    }
    for (const auto& scratch : wave_->scratch)
        result.storage_bytes += (scratch.mass.capacity() + scratch.weight.capacity()) * sizeof(std::int32_t) +
                                scratch.flags.capacity() + scratch.launch.capacity() * sizeof(WaveState::Launch);
    result.storage_bytes += wave_->sorted.capacity() * sizeof(WaveState::Entry) +
                            wave_->grow.capacity() * sizeof(ChunkCoord) +
                            wave_->tasks.capacity() * sizeof(WaveState::Task) +
                            wave_->scratch.capacity() * sizeof(WaveState::Scratch) + sizeof(WaveState);
    return result;
}

// The legacy state_hash() contribution of a Wave World: everything that can
// change a later tick beyond the cells themselves. Two Worlds with equal cells
// and different retained momentum are different states. Mirrors the fields the
// versioned physical identity binds; absent for every other World.
void World::hash_wave_state(std::uint64_t& hash) const {
    if (wave_ == nullptr) return;
    for (const char c : std::string_view{"wave_flow_v1"}) hash_byte(hash, static_cast<std::uint8_t>(c));
    hash_integer(hash, WaveFlowParameters::kVersion);
    hash_integer(hash, config_.wave_flow.substeps);
    const auto& tune = config_.wave_flow;
    const bool tuned = tune.active_rows != WaveFlowParameters::kActiveRows ||
        tune.gain != WaveFlowParameters::kGain || tune.gain_confined != WaveFlowParameters::kGainConfined ||
        tune.stiffness != WaveFlowParameters::kStiffness || tune.damp_shift != WaveFlowParameters::kDampShift ||
        tune.coast != WaveFlowParameters::kCoast || tune.level_shift != WaveFlowParameters::kLevelShift ||
        tune.sleep_after != WaveFlowParameters::kSleepAfter || tune.wake_peak != WaveFlowParameters::kWakePeak ||
        tune.rest_head != WaveFlowParameters::kRestHead || tune.stick != WaveFlowParameters::kStick ||
        tune.calm != WaveFlowParameters::kCalm || tune.calm_damp_shift != WaveFlowParameters::kCalmDampShift ||
        tune.maximum_mass != WaveFlowParameters::kMaximumMass || tune.empty_pour_shift != WaveFlowParameters::kEmptyPourShift ||
        tune.flow_share_shift != WaveFlowParameters::kFlowShareShift || tune.adhesion_shift != WaveFlowParameters::kAdhesionShift;
    if (tuned) {
        for (const char c : std::string_view{"wave-authoring-tuning-v1"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, tune.active_rows); hash_integer(hash, tune.gain); hash_integer(hash, tune.gain_confined);
        hash_integer(hash, tune.stiffness); hash_integer(hash, tune.damp_shift); hash_integer(hash, tune.coast);
        hash_integer(hash, tune.level_shift); hash_integer(hash, tune.sleep_after); hash_integer(hash, tune.wake_peak);
        hash_integer(hash, tune.rest_head); hash_integer(hash, tune.stick); hash_integer(hash, tune.calm);
        hash_integer(hash, tune.calm_damp_shift); hash_integer(hash, tune.maximum_mass);
        hash_integer(hash, tune.empty_pour_shift); hash_integer(hash, tune.flow_share_shift); hash_integer(hash, tune.adhesion_shift);
    }
    if (tune.flux_smoothing != 0) {
        for (const char c : std::string_view{"wave-flux-smoothing"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, tune.flux_smoothing);
    }
    if (tune.floor_gain != 0) {
        for (const char c : std::string_view{"wave-floor-gain"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, tune.floor_gain);
    }
    if (tune.deep_gain != 0) {
        for (const char c : std::string_view{"wave-deep-gain"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, tune.deep_gain);
    }
    if (tune.spill.enabled) {
        // Absent while disabled, so every existing Wave World keeps its hash.
        for (const char c : std::string_view{"wave-spill-v1"}) hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_integer(hash, tune.spill.fall); hash_integer(hash, tune.spill.share_shift);
        hash_integer(hash, tune.spill.draw); hash_integer(hash, tune.spill.draw_head);
        hash_integer(hash, tune.spill.stream);
        hash_integer(hash, tune.spill.launch_min); hash_integer(hash, tune.spill.launch_budget);
        hash_integer(hash, tune.spill.launch_speed);
        hash_integer(hash, tune.spill.stream_share); hash_integer(hash, tune.spill.catch_falling);
        hash_integer(hash, static_cast<std::uint8_t>(wave_->launch_backoff));
        // Bound only when used, so every earlier spill World keeps its hash.
        if (tune.spill.stream_draw != 0) {
            for (const char c : std::string_view{"stream-draw"}) hash_byte(hash, static_cast<std::uint8_t>(c));
            hash_integer(hash, tune.spill.stream_draw);
        }
        hash_wave_discharge(hash, tune.spill, ballistic_parcels_);
    }
    hash_integer(hash, wave_->round);
    std::vector<ChunkCoord> coordinates;
    coordinates.reserve(chunks_.size());
    for (const auto& [coord, chunk] : chunks_) {
        (void)chunk;
        coordinates.push_back(coord);
    }
    std::sort(coordinates.begin(), coordinates.end());
    for (const auto coord : coordinates) {
        const auto* chunk = find_chunk(coord);
        if (chunk == nullptr || chunk->wave == nullptr) continue;
        const auto& wave = *chunk->wave;
        hash_integer(hash, coord.x);
        hash_integer(hash, coord.y);
        hash_integer(hash, wave.quiet);
        hash_integer(hash, static_cast<std::uint8_t>(wave.woken));
        for (const auto value : wave.clean) hash_integer(hash, static_cast<std::uint8_t>(value));
        for (const auto value : wave.dry_reset) hash_integer(hash, static_cast<std::uint8_t>(value));
        for (const auto value : wave.dry) hash_integer(hash, value);
        for (std::size_t i = 0; i < wave.flux.size(); ++i) {
            hash_integer(hash, wave.flux[i]);
            hash_integer(hash, wave.weight[i]);
            hash_integer(hash, wave.meta[i]);
        }
    }
}

void World::reset_wave_cell(std::int64_t x, std::int64_t y) noexcept {
    if (wave_ == nullptr) return;
    const auto at = address(x, y);
    if (auto* chunk = find_chunk(at.chunk); chunk != nullptr) {
        chunk->wave->flux[at.index] = 0;
        chunk->wave->weight[at.index] = 0;
        chunk->wave->meta[at.index] = 0;
        wake_wave_chunk(*chunk);
    }
    if (x == std::numeric_limits<std::int64_t>::min()) return;
    const auto left = address(x - 1, y);
    if (auto* chunk = find_chunk(left.chunk); chunk != nullptr) {
        chunk->wave->flux[left.index] = 0;
        wake_wave_chunk(*chunk);
    }
}

void World::wake_wave_chunk(Chunk& chunk) noexcept {
    if (chunk.wave == nullptr) return;
    chunk.wave->woken = true;
    chunk.wave->clean = {};
    chunk.wave->empty_derived = {};
    chunk.wave->dry_reset = {true, true};
}

void World::wave_column_task(std::size_t task_index) noexcept {
    // The extra certificate addresses allocated mask coverage suppressing the
    // original dry/clean shortcuts. It adds no skip when no configured mask
    // column crosses this strip. Choose once per task; compile all redundant
    // per-column certificate bookkeeping out of the ordinary unmasked path.
    bool mask_covered = false;
    if (wave_->mask_present) {
        const auto& task = wave_->tasks[task_index];
        const auto size = config_.chunk_size;
        const auto& origin = wave_->sorted[task.first].coord;
        const auto& mask = transient_obstacles_->region;
        const auto ys = wave_clip_mask_axis(origin.y * size, static_cast<std::int32_t>(task.count) * size,
                                            mask.y, mask.height);
        const auto xs = wave_clip_mask_axis(origin.x * size, size, mask.x, mask.width);
        const auto first_x = task.half == 0U ? 0 : size / 2;
        const auto last_x = task.half == 0U ? size / 2 : size;
        mask_covered = ys[0] < ys[1] && xs[0] < last_x && xs[1] > first_x;
    }
    if (mask_covered) {
        wave_column_task_impl<true>(task_index);
    } else {
        // Retire older mask-era certificates once per owned half, including
        // partial selections and long groups. The original column path need
        // not maintain them, and a returning mask must recertify actual data.
        const auto& task = wave_->tasks[task_index];
        for (std::uint32_t c = 0; c < task.count; ++c) {
            auto& certificate = wave_->sorted[task.first + c].chunk->wave->empty_derived[task.half];
            if (certificate) certificate = false;
        }
        wave_column_task_impl<false>(task_index);
    }
}

template <bool WithEmptyDerived>
void World::wave_column_task_impl(std::size_t task_index) noexcept {
    using P = WaveFlowParameters;
    auto& state = *wave_;
    const auto& task = state.tasks[task_index];
    auto& scratch = state.scratch[task_index];
    const auto size = config_.chunk_size;
    const auto rows = static_cast<std::int32_t>(task.count) * size;
    const auto maximum = state.maximum;
    const auto first_x = task.half == 0U ? 0 : size / 2;
    const auto last_x = task.half == 0U ? size / 2 : size;
    const auto* entries = state.sorted.data() + task.first;
    const auto origin_x = entries[0].coord.x * size;
    const auto origin_y = entries[0].coord.y * size;
    auto* mass = scratch.mass.data();
    auto* weight = scratch.weight.data();
    auto* flags = scratch.flags.data();
    auto* const above = entries[0].chunk->wave->above;
    const auto press_body = [&](std::uint16_t body, int dx, int dy, std::int64_t x, std::int64_t y, std::int32_t cell) {
        wave_press_body(body, dx, dy, x, y, cell);
    };
    const bool spill = config_.wave_flow.spill.enabled;
    const auto fall = spill ? config_.wave_flow.spill.fall : 1;
    std::uint64_t falling_units = 0, falling_cells = 0;
    // Body masks: only the rows of this strip inside the mask region are probed.
    const auto& mask = transient_obstacles_->region;
    std::int32_t mask_first = 0, mask_last = 0;
    std::int32_t mask_first_x = 0, mask_last_x = 0;
    std::int32_t occupied_first = 0, occupied_last = 0;
    std::int32_t occupied_first_x = 0, occupied_last_x = 0;
    if (state.mask_present) {
        const auto clipped_y = wave_clip_mask_axis(origin_y, rows, mask.y, mask.height);
        mask_first = clipped_y[0];
        mask_last = clipped_y[1];
        const auto clipped_x = wave_clip_mask_axis(origin_x, size, mask.x, mask.width);
        mask_first_x = clipped_x[0];
        mask_last_x = clipped_x[1];
        const auto& occupied = state.occupied_mask_bounds;
        const auto occupied_y = wave_clip_mask_axis(origin_y, rows, occupied.y, occupied.height);
        occupied_first = occupied_y[0];
        occupied_last = occupied_y[1];
        const auto occupied_x = wave_clip_mask_axis(origin_x, size, occupied.x, occupied.width);
        occupied_first_x = occupied_x[0];
        occupied_last_x = occupied_x[1];
    }
    constexpr std::uint32_t kMaximumGroup = 64;
    bool skip[kMaximumGroup] = {}, empty[kMaximumGroup] = {};
    [[maybe_unused]] bool reuse_empty[kMaximumGroup] = {};
#if defined(CYBERSAND_WAVE_VERIFY_EMPTY_DERIVED)
    // Retained safety apparatus, deliberately absent from ordinary timing.
    // Check the actual storage, not another derived mark; remain effective
    // even if a diagnostic build also defines NDEBUG. Flux is not certified.
    [[maybe_unused]] const auto verify_empty_derived = [&](const Chunk& chunk) {
        for (std::int32_t ly = 0; ly < size; ++ly)
            for (auto lx = first_x; lx < last_x; ++lx) {
                const auto at = static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) +
                                static_cast<std::size_t>(lx);
                if (chunk.cells[at].material_value() != Material::Empty ||
                    chunk.wave->weight[at] != 0 || chunk.wave->meta[at] != 0U)
                    std::terminate();
            }
    };
#endif
    for (std::uint32_t c = 0; c < task.count && (WithEmptyDerived || c < kMaximumGroup); ++c) {
        const auto base = static_cast<std::int32_t>(c) * size;
        auto& wave = *entries[c].chunk->wave;
        const bool full = wave.min_y == 0 && wave.max_y == size &&
                          wave.min_x <= first_x && wave.max_x >= last_x;
        if constexpr (WithEmptyDerived) {
            // A partial pass cannot certify untouched cells, even if old dry
            // marks skip all selected columns. Tall groups retain fallback.
            if (!full || c >= kMaximumGroup) wave.empty_derived[task.half] = false;
            if (c >= kMaximumGroup) continue;
        }
        skip[c] = wave.clean[task.half] && full &&
                  !(base < mask_last && base + size > mask_first);
        if constexpr (WithEmptyDerived) {
            const bool occupied = base < occupied_last && base + size > occupied_first &&
                                  first_x < occupied_last_x && last_x > occupied_first_x;
            reuse_empty[c] = wave.empty_derived[task.half] && full && !occupied;
#if defined(CYBERSAND_WAVE_VERIFY_EMPTY_DERIVED)
            if (reuse_empty[c]) verify_empty_derived(*entries[c].chunk);
#endif
        }
        empty[c] = true;
    }

    for (std::uint32_t c = 0; c < task.count; ++c) {
        auto& wave = *entries[c].chunk->wave;
        if (!wave.dry_reset[task.half]) continue;
        std::fill_n(wave.dry.data() + first_x, last_x - first_x, std::uint8_t{0});
        wave.dry_reset[task.half] = false;
    }

    for (auto lx = first_x; lx < last_x; ++lx) {
        if (lx < entries[0].chunk->wave->min_x || lx >= entries[0].chunk->wave->max_x) continue;
        const bool masked_column = mask_last > mask_first && lx >= mask_first_x && lx < mask_last_x;
        if (!masked_column) {
            // A column that is dry in every chunk of the group cannot change:
            // liquid enters it only through the apply pass or an owner edit,
            // and both clear the mark.
            bool dry = true;
            for (std::uint32_t c = 0; c < task.count && dry; ++c)
                dry = entries[c].chunk->wave->min_y == 0 && entries[c].chunk->wave->max_y == size &&
                      entries[c].chunk->wave->dry[static_cast<std::size_t>(lx)] != 0U;
            if (dry) {
                for (std::uint32_t c = 0; c < task.count && c < kMaximumGroup; ++c)
                    if (entries[c].chunk->wave->dry[static_cast<std::size_t>(lx)] != 2U) empty[c] = false;
                continue;
            }
        }
        // Both negative codes block Water transport. Oil can float, so it
        // does not supply the rigid-ceiling pressure response below it.
        constexpr std::int32_t oil_lid = -2;
        for (std::uint32_t c = 0; c < task.count; ++c) {
            const auto& chunk = *entries[c].chunk;
            if (c < kMaximumGroup && (skip[c] || (WithEmptyDerived && reuse_empty[c]))) {
                // Both certificates prove Empty cells and zero derived flags.
                // All column physics still runs, so inflow from above may
                // invalidate the certificate before scatter.
                const auto base = static_cast<std::size_t>(c) * static_cast<std::size_t>(size);
                std::fill_n(mass + base, size, 0);
                std::fill_n(flags + base, size, std::uint8_t{0});
                continue;
            }
            const auto* cells = chunk.cells.data() + lx;
            const auto* meta = chunk.wave->meta.data() + lx;
            const auto base = static_cast<std::int32_t>(c) * size;
            for (std::int32_t ly = 0; ly < size; ++ly) {
                const auto& cell = cells[static_cast<std::size_t>(ly) * static_cast<std::size_t>(size)];
                const auto material = cell.material_value();
                if (!chunk.wave->included(lx, ly)) {
                    mass[base + ly] = -1;
                    flags[base + ly] = 0;
                    continue;
                }
                mass[base + ly] = material == Material::Water ? static_cast<std::int32_t>(cell.state_a_value())
                                  : material == Material::Empty ? 0 : material == Material::Oil ? oil_lid : -1;
                flags[base + ly] = meta[static_cast<std::size_t>(ly) * static_cast<std::size_t>(size)] & WaveChunk::kFull;
            }
        }
        if (masked_column && lx >= occupied_first_x && lx < occupied_last_x) {
            for (auto r = occupied_first; r < occupied_last; ++r) {
                const auto body = transient_obstacle_at(origin_x + lx, origin_y + r);
                if (body == 0U) continue;
                // Water resting on a body presses it down (the existing contract).
                if (r > 0 && mass[r - 1] > 0)
                    press_body(body, 0, 1, origin_x + lx, origin_y + r - 1, mass[r - 1]);
                mass[r] = -1;
            }
        }

        // Settle, bottom-up. `dst` is the lowest cell that may still receive.
        // Cells that were full after the previous settle transmit support:
        // deficits left by lateral outflow are refilled from above without a
        // distance limit, so a hydrostatic stack never splits. Loose liquid
        // above anything else falls one cell per round. Excess is carried up
        // to the surface, or stays as overfill under a solid ceiling.
        std::int32_t dst = -1, segment_bottom = rows - 1;
        std::int64_t carry = 0;
        bool chain = false;
        // Usually overfill fits in the top cell. At extreme legal volumes it
        // is spread down the same sealed segment, never wrapped or discarded.
        // The segment originally held this quantity in uint16 cells, so it
        // necessarily has room when every lateral receiver is bounded too.
        const auto retain_overfill = [&](std::int32_t first, std::int32_t last) {
            for (auto row = first; row <= last && carry != 0; ++row) {
                const auto added = std::min(carry, std::int64_t{65535} - mass[row]);
                mass[row] += static_cast<std::int32_t>(added);
                carry -= added;
            }
            if (carry != 0) {
                ++entries[0].chunk->wave->half[task.half].invalid;
                carry = 0;
            }
        };
        for (auto r = rows - 1; r >= 0; --r) {
            if (mass[r] < 0) {
                retain_overfill(r + 1, segment_bottom);
                segment_bottom = r - 1;
                dst = -1;
                chain = false;
                continue;
            }
            auto amount = static_cast<std::int64_t>(mass[r]) + carry;
            carry = 0;
            // Spill lets loose liquid fall `fall` cells per round: `dst` then
            // stays the lowest free cell of the open run instead of the nearest.
            if (amount == 0) { if (fall == 1 || dst <= r) dst = r; chain = false; continue; }
            if (dst > r && !chain) dst = std::min(dst, r + fall);
            while (dst > r && amount > 0) {
                const auto room = maximum - mass[dst];
                if (room <= 0) { --dst; continue; }
                const auto moved = static_cast<std::int32_t>(std::min(amount, static_cast<std::int64_t>(room)));
                mass[dst] += moved;
                amount -= moved;
            }
            // What follows lands on top of what just landed, not beside its source.
            while (fall != 1 && dst > r && mass[dst] >= maximum) --dst;
            mass[r] = static_cast<std::int32_t>(std::min(amount, static_cast<std::int64_t>(maximum)));
            carry = amount - mass[r];
            chain = flags[r] != 0U;
            if (dst <= r || mass[dst] >= maximum) dst = mass[r] < maximum ? r : -1;
        }
        retain_overfill(0, segment_bottom);

        // Heads, top-down. The head of a wet cell is the weight of the liquid
        // resting on its floor: its own mass, plus what the cell above carries
        // if this cell is full. A unit moved sideways at a row then changes
        // potential energy by exactly the head difference for any stack of
        // full, thin or falling cells, so retained flux cannot gain energy.
        // Accumulate in a wider temporary even though stored heads are bounded:
        // long legal uint16 stacks must never overflow before saturation.
        if (spill) {
            // Unsupported Water, bottom-up: a cell rests on a solid, on the
            // bottom of what is solved, or on a full resting cell. Anything
            // else is falling. `weight` holds the mark until heads replace it.
            bool support = true;
            for (auto r = rows - 1; r >= 0; --r) {
                weight[r] = 0;
                if (mass[r] < 0) { support = true; continue; }
                if (mass[r] == 0) { support = false; continue; }
                if (!support) {
                    weight[r] = 1;
                    falling_units += static_cast<std::uint64_t>(mass[r]);
                    ++falling_cells;
                }
                support = support && mass[r] >= maximum;
            }
        }
        std::int64_t carried = 0;
        std::int32_t index = 0;
        bool confined = false;
        bool oil_above_group = false;
        if (above != nullptr && above->wave->included(lx, size - 1)) {
            const auto bottom = static_cast<std::size_t>(size - 1) * static_cast<std::size_t>(size) +
                                static_cast<std::size_t>(lx);
            const auto meta = above->wave->meta[bottom];
            if ((meta & WaveChunk::kFull) != 0U) {
                carried = above->wave->weight[bottom];
                index = config_.wave_flow.active_rows;
            } else if ((meta & WaveChunk::kSolid) != 0U) {
                oil_above_group = meta == WaveChunk::kOilLid;
                if (!oil_above_group) index = -1;
            }
        } else {
            index = -1; // nothing resident above: treated as a ceiling
        }
        bool ceiling = index < 0;
        if (ceiling) index = 0;
        for (std::int32_t r = 0; r < rows; ++r) {
            const auto value = mass[r];
            if (value < 0) {
                // Propagate a rigid cap through Oil trapped immediately under
                // it. A body mask or paused cell is always a rigid cap.
                if (value == oil_lid && state.final_round && r + 1 < rows && mass[r + 1] > 0 &&
                    ((r >= 2 && mass[r - 1] == oil_lid && mass[r - 2] == oil_lid) ||
                     mass[r + 1] > state.oil_lift_threshold() ||
                     (mass[r + 1] < state.oil_drop_threshold() && r + 2 < rows && mass[r + 2] >= maximum))) {
                    auto& half = entries[r / size].chunk->wave->half[task.half];
                    half.oil_first = std::min(half.oil_first, r % size);
                    half.oil_last = std::max(half.oil_last, r % size);
                }
                ceiling = value != oil_lid || ceiling;
                weight[r] = 0;
                flags[r] = ceiling ? WaveChunk::kSolid : WaveChunk::kOilLid;
                carried = 0;
                index = 0;
                continue;
            }
            if (value == 0) { weight[r] = 0; flags[r] = 0; carried = 0; index = 0; ceiling = false; continue; }
            if (spill && weight[r] != 0) {
                // Falling Water presses on nothing and starts no stack.
                weight[r] = value;
                flags[r] = static_cast<std::uint8_t>(WaveChunk::kWet | WaveChunk::kGainNormal |
                                                     (WaveChunk::kFalling << WaveChunk::kDepthShift));
                carried = 0; index = 0; confined = false; ceiling = false;
                continue;
            }
            if (index == 0) {
                const bool under_oil = r == 0 ? oil_above_group : flags[r - 1] == WaveChunk::kOilLid;
                confined = !under_oil && (value > maximum || (value == maximum && ceiling));
                if (value > maximum && !under_oil) {
                    // Sealed overfill is stiff: scale by the rows that can respond.
                    std::int32_t responding = 1;
                    while (responding < config_.wave_flow.active_rows && r + responding < rows && mass[r + responding] > 0) ++responding;
                    carried = static_cast<std::int64_t>(value - maximum) *
                              (config_.wave_flow.stiffness / responding - 1);
                }
            }
            carried = std::min<std::int64_t>(P::kMaximumHead,
                static_cast<std::int64_t>(value) + (value >= maximum ? carried : 0));
            weight[r] = static_cast<std::int32_t>(carried);
            flags[r] = static_cast<std::uint8_t>(
                WaveChunk::kWet | (value >= maximum ? WaveChunk::kFull : 0U) |
                (index >= config_.wave_flow.active_rows ? 0U : confined ? WaveChunk::kGainConfined : WaveChunk::kGainNormal));
            // A thin cell starts a new stack below it.
            if (value < maximum) { index = 0; confined = false; ceiling = false; continue; }
            index = std::min(index + 1, config_.wave_flow.active_rows);
            ceiling = false;
        }

        // Depth class of every stack: how many rows respond together. A shallow
        // layer may level a larger share of its head difference per round than
        // a deep one without overshooting.
        for (std::int32_t r = 0; r < rows;) {
            if ((flags[r] & WaveChunk::kWet) == 0U || (flags[r] >> WaveChunk::kDepthShift) == WaveChunk::kFalling) { ++r; continue; }
            auto end = r;
            while (end + 1 < rows && (flags[end] & WaveChunk::kFull) != 0U && (flags[end + 1] & WaveChunk::kWet) != 0U) ++end;
            const auto length = std::min(end - r + 1, config_.wave_flow.active_rows);
            std::uint8_t depth = 0;
            while ((1 << depth) < length) ++depth;
            // Overfill collects in the top cell of a sealed stack while inflow
            // arrives at any row, so a stack at the carrier ceiling is marked
            // whole and refuses further inflow.
            const bool saturated = mass[r] >= config_.wave_flow.maximum_mass;
            if (saturated) depth = WaveChunk::kSaturated;
            for (auto k = r; k <= end && (saturated || k < r + config_.wave_flow.active_rows); ++k)
                flags[k] = static_cast<std::uint8_t>(flags[k] | (depth << WaveChunk::kDepthShift));
            r = end + 1;
        }

        // Scatter: write changed cells, derived weight and meta.
        for (std::uint32_t c = 0; c < task.count; ++c) {
            auto& chunk = *entries[c].chunk;
            auto& wave = *chunk.wave;
            auto& half = wave.half[task.half];
            const auto base = static_cast<std::int32_t>(c) * size;
            bool any = false, wet = false;
            for (std::int32_t ly = 0; ly < size; ++ly) {
                any = any || mass[base + ly] != 0;
                wet = wet || mass[base + ly] > 0;
            }
            const auto mark = masked_column || wet || wave.min_y != 0 || wave.max_y != size
                ? std::uint8_t{0} : any ? std::uint8_t{1} : std::uint8_t{2};
            if (mark != 0U && wave.dry[static_cast<std::size_t>(lx)] == 0U &&
                !wave.right_face_paused(lx, size)) {
                // Faces of a newly dry column are skipped from now on, so the
                // flux a just-emptied cell still carries must not survive.
                for (std::int32_t ly = 0; ly < size; ++ly)
                    wave.flux[static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) + static_cast<std::size_t>(lx)] = 0;
            }
            wave.dry[static_cast<std::size_t>(lx)] = mark;
            if (c < kMaximumGroup) {
                // A clean half stays untouched unless liquid settled into it.
                if ((skip[c] || (WithEmptyDerived && reuse_empty[c])) && !any) continue;
                if (any) {
                    empty[c] = false;
                    wave.clean[task.half] = false;
                    skip[c] = false;
                    if constexpr (WithEmptyDerived) {
                        if (wave.empty_derived[task.half]) wave.empty_derived[task.half] = false;
                        reuse_empty[c] = false;
                    }
                }
            }
            for (std::int32_t ly = 0; ly < size; ++ly) {
                const auto at = static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) + static_cast<std::size_t>(lx);
                const auto r = base + ly;
                if (!wave.included(lx, ly)) continue;
                wave.weight[at] = weight[r];
                wave.meta[at] = flags[r];
                if (mass[r] < 0) continue;
                auto& cell = chunk.cells[at];
                const auto before = cell.material_value() == Material::Water
                                        ? static_cast<std::int32_t>(cell.state_a_value()) : 0;
                if (before == mass[r]) continue;
                wave_write_mass(chunk, at, before, mass[r], half);
                // The other side of a paused face retains this exact flux
                // even when the selected source column drains vertically.
                if (mass[r] == 0 && !wave.right_face_paused(lx, size)) wave.flux[at] = 0;
                half.touch(lx, ly);
                half.peak = std::max(half.peak, std::abs(mass[r] - before));
            }
        }
    }
    if (spill) {
        auto& half = entries[0].chunk->wave->half[task.half];
        half.falling_units = falling_units;
        half.falling_cells = falling_cells;
    }
    // A half found entirely Empty becomes clean: zero its retained flux once.
    for (std::uint32_t c = 0; c < task.count && c < kMaximumGroup; ++c) {
        auto& wave = *entries[c].chunk->wave;
        if (wave.min_y != 0 || wave.max_y != size || wave.min_x > first_x || wave.max_x < last_x) continue;
        if constexpr (WithEmptyDerived) {
            // Zero post-column mass unconditionally clears scratch weight/meta
            // in the head pass. Every visited column scattered those zeros or
            // already had a valid certificate; old dry==2 retains its zeros.
            wave.empty_derived[task.half] = empty[c];
#if defined(CYBERSAND_WAVE_VERIFY_EMPTY_DERIVED)
            if (wave.empty_derived[task.half]) verify_empty_derived(*entries[c].chunk);
#endif
        }
        if (!empty[c] || wave.clean[task.half]) continue;
        const auto base = static_cast<std::int32_t>(c) * size;
        if (base < mask_last && base + size > mask_first) continue;
        const auto clear_end = wave.right_face_paused(last_x - 1, size) ? last_x - 1 : last_x;
        for (std::int32_t ly = 0; ly < size; ++ly)
            std::fill_n(wave.flux.data() + static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) +
                            static_cast<std::size_t>(first_x), clear_end - first_x, 0);
        wave.clean[task.half] = true;
    }
    // Flux workers overwrite their own faces in parallel. Sample all faces
    // in this strip after local dry/empty resets, within the column barrier.
    if (config_.wave_flow.flux_smoothing != 0) {
        for (std::uint32_t c = 0; c < task.count; ++c) {
            auto& wave = *entries[c].chunk->wave;
            for (auto ly = wave.min_y; ly < wave.max_y; ++ly) {
                const auto i = static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) + static_cast<std::size_t>(first_x);
                std::copy_n(wave.flux.data() + i, last_x - first_x, wave.prior_flux.data() + i);
            }
        }
    }
}

// Offer Wave Water's push on a transient body. With the defaults this is
// exactly record_transient_contact. Otherwise the same accumulators receive a
// scaled impulse; the contact count is unchanged. Pool workers call this; the
// accumulators are relaxed atomics, so the order of additions does not matter.
void World::wave_press_body(std::uint16_t body, int dx, int dy, std::int64_t x, std::int64_t y,
                            std::int32_t cell_mass) noexcept {
    const auto& tune = config_.wave_flow;
    if ((tune.body_push == 256 && tune.body_push_by_mass == 0) || MaterialRules::supports_granular_load(Material::Water)) {
        record_transient_contact(body, Material::Water, dx, dy, x, y);
        return;
    }
    if (body == 0U || body > kMaximumTransientBodies) return;
    const auto density = std::clamp<std::int64_t>(
        static_cast<std::int64_t>(MaterialRules::descriptor(Material::Water).density), 50, 1'600);
    const auto maximum = static_cast<std::int64_t>(config_.water_experiment_policy.maximum());
    const auto share = tune.body_push_by_mass != 0 ? std::clamp<std::int64_t>(cell_mass, 0, maximum) : maximum;
    const auto push = density * tune.body_push * share / (256 * maximum);
    transient_obstacles_->contacts[body].fetch_add(1U, std::memory_order_relaxed);
    transient_obstacles_->impulse_x[body].fetch_add(dx * push, std::memory_order_relaxed);
    transient_obstacles_->impulse_y[body].fetch_add(dy * push, std::memory_order_relaxed);
}

void World::wave_write_mass(Chunk& chunk, std::size_t at, std::int32_t before, std::int32_t after,
                            WaveHalf& half) noexcept {
    auto& cell = chunk.cells[at];
    ++half.changed;
    // The limiters make this unreachable. If a defect ever produces a mass the
    // carrier cannot hold, the tick fails the World instead of wrapping it.
    if (after < 0 || after > 65535) {
        ++half.invalid;
        after = std::clamp(after, 0, 65535);
    }
    if (after == 0) {
        cell = Chunk::Cell::for_material(Material::Empty);
        cell.set_epoch(update_epoch_);
        // The retained flux of this face is left alone here: the apply pass of
        // the neighbouring strip may still be reading it.
        --half.non_empty_delta;
        ++half.transitions;
        return;
    }
    const auto column = at % static_cast<std::size_t>(config_.chunk_size);
    const auto half_index = column < static_cast<std::size_t>(config_.chunk_size / 2) ? 0U : 1U;
    chunk.wave->clean[half_index] = false;
    // Wet halves normally already have no certificate. Avoid another shared
    // header store for every positive cell update, but invalidate a retained
    // certificate even while this tick is using the no-mask specialization.
    if (chunk.wave->empty_derived[half_index]) chunk.wave->empty_derived[half_index] = false;
    chunk.wave->dry[column] = 0;
    if (before == 0) {
        cell = Chunk::Cell::for_material(Material::Water);
        cell.set_state_b(0);
        cell.set_epoch(update_epoch_);
        ++half.non_empty_delta;
        ++half.transitions;
    }
    cell.set_state_a(static_cast<std::uint16_t>(after));
}

void World::wave_flux_task(std::size_t task_index) noexcept {
    using P = WaveFlowParameters;
    auto& state = *wave_;
    const auto& task = state.tasks[task_index];
    const auto size = config_.chunk_size;
    const auto stride = static_cast<std::size_t>(size);
    const auto first_x = task.half == 0U ? 0 : size / 2;
    const auto last_x = task.half == 0U ? size / 2 : size;
    const auto film = state.film;
    const auto& spill = config_.wave_flow.spill;
    const bool full_face_hybrid = spill.enabled && spill.full_face != 0 &&
        config_.ballistic_water.enabled && spill.launch_budget > 0;
    const auto maximum = state.maximum;
    for (std::uint32_t c = 0; c < task.count; ++c) {
        auto& chunk = *state.sorted[task.first + c].chunk;
        auto& wave = *chunk.wave;
        const auto* right = wave.right;
        // Interior faces of a clean half are Empty|Empty with zero flux.
        const auto start_x = wave.clean[task.half] ? last_x - 1 : first_x;
        // Faces whose two columns are both dry (and not reset since) are skipped.
        bool dry_face[1024] = {};
        if (!state.mask_present && size <= 1024 && !wave.dry_reset[0] && !wave.dry_reset[1]) {
            for (auto lx = start_x; lx < last_x; ++lx) {
                const auto mine = wave.dry[static_cast<std::size_t>(lx)] != 0U;
                const auto theirs = lx + 1 < size ? wave.dry[static_cast<std::size_t>(lx) + 1U] != 0U
                    : right != nullptr && !right->wave->dry_reset[0] && right->wave->dry[0] != 0U;
                dry_face[lx] = mine && theirs;
            }
        }
        const auto origin_x = state.sorted[task.first + c].coord.x * size;
        const auto origin_y = state.sorted[task.first + c].coord.y * size;
        for (std::int32_t ly = 0; ly < size; ++ly) {
            if (ly < wave.min_y || ly >= wave.max_y) continue;
            const auto row = static_cast<std::size_t>(ly) * stride;
            for (auto lx = start_x; lx < last_x; ++lx) {
                if (lx < wave.min_x || lx >= wave.max_x) continue;
                const auto i = row + static_cast<std::size_t>(lx);
                // Exclusion freezes the face too. Its retained flux must not
                // leak mass across the boundary or vanish while paused.
                if (lx + 1 < size) {
                    if (!wave.included(lx + 1, ly)) continue;
                } else if (wave.right_paused || (right != nullptr && !right->wave->included(0, ly))) continue;
                // No Water on either side. The face may still hold flux written
                // while one side was wet, so it is cleared rather than assumed zero.
                if (dry_face[lx]) { wave.flux[i] = 0; continue; }
                const Chunk* other = &chunk;
                auto j = i + 1U;
                if (lx + 1 == size) {
                    // A face is solved only when both of its chunks are.
                    if (right == nullptr) { wave.flux[i] = 0; continue; }
                    other = right;
                    j = row;
                }
                const auto meta_a = wave.meta[i], meta_b = other->wave->meta[j];
                if (((meta_a | meta_b) & WaveChunk::kSolid) != 0U || ((meta_a | meta_b) & WaveChunk::kWet) == 0U) {
                    wave.flux[i] = 0;
                    // Water leaning on a body pushes it sideways (the existing contract).
                    if (state.mask_present && ((meta_a | meta_b) & WaveChunk::kWet) != 0U) {
                        const bool wet_left = (meta_a & WaveChunk::kWet) != 0U;
                        const auto body = transient_obstacle_at(origin_x + lx + (wet_left ? 1 : 0), origin_y + ly);
                        if (body != 0U)
                            wave_press_body(body, wet_left ? 1 : -1, 0, origin_x + lx + (wet_left ? 0 : 1), origin_y + ly,
                                wet_left ? static_cast<std::int32_t>(chunk.cells[i].state_a_value())
                                         : static_cast<std::int32_t>(other->cells[j].state_a_value()));
                    }
                    continue;
                }
                const auto a = (meta_a & WaveChunk::kWet) != 0U ? static_cast<std::int32_t>(chunk.cells[i].state_a_value()) : 0;
                const auto b = (meta_b & WaveChunk::kWet) != 0U ? static_cast<std::int32_t>(other->cells[j].state_a_value()) : 0;
                auto gain_a = meta_a & WaveChunk::kGainMask, gain_b = meta_b & WaveChunk::kGainMask;
                // Liquid beside an empty cell always pours.
                if (a == 0) gain_a = gain_b == WaveChunk::kGainConfined ? gain_b : WaveChunk::kGainNormal;
                if (b == 0) gain_b = gain_a == WaveChunk::kGainConfined ? gain_a : WaveChunk::kGainNormal;
                const auto code = (gain_a == WaveChunk::kGainConfined || gain_b == WaveChunk::kGainConfined)
                                      ? WaveChunk::kGainConfined : std::max(gain_a, gain_b);
                // A face outside every active band keeps no momentum: coasting
                // flux with no restoring force would pump energy into the surface.
                if (code == 0U) { wave.flux[i] = 0; continue; }
                auto head = wave.weight[i] - other->wave->weight[j];
                if (full_face_hybrid && a != 0 && b != 0) {
                    // A passing curtain exerts no hydrostatic counter-head.
                    // Otherwise one full falling cell can hide the entire crest.
                    const bool left_falling = (meta_a >> WaveChunk::kDepthShift) == WaveChunk::kFalling;
                    const bool right_falling = (meta_b >> WaveChunk::kDepthShift) == WaveChunk::kFalling;
                    if (left_falling != right_falling) head = left_falling ? -other->wave->weight[j] : wave.weight[i];
                }
                // Whether the cell rests on something solid (or on the edge of
                // what is solved, which is treated as a floor).
                const auto supported = [&](const Chunk* owner, std::size_t at) noexcept {
                    if (ly + 1 < size)
                        // Spill: a paused cell keeps stale meta but is solid to the column pass.
                        return (owner->wave->meta[at + stride] & WaveChunk::kSolid) != 0U ||
                               (spill.enabled && !owner->wave->included(static_cast<std::int32_t>(at - row), ly + 1));
                    const auto* under = owner->wave->below;
                    const auto column = static_cast<std::int32_t>(at - row);
                    return under == nullptr || !under->wave->included(column, 0) ||
                           (under->wave->meta[static_cast<std::size_t>(column)] & WaveChunk::kSolid) != 0U;
                };
                // The leading film may retain momentum only along an actual,
                // level floor. A solved-region edge, a body, Water underneath,
                // or a step up/down cannot supply this extra acceleration.
                const auto floor_depth = [&](const Chunk* owner, std::size_t at) noexcept {
                    const auto x = static_cast<std::int32_t>(at - row);
                    auto y = ly;
                    for (int depth = 1; depth <= 3; ++depth) {
                        if (++y == size) {
                            owner = owner->wave->below;
                            y = 0;
                        }
                        if (!owner || !owner->wave->solve || !owner->wave->included(x, y)) return 0;
                        const auto below = static_cast<std::size_t>(y) * stride + static_cast<std::size_t>(x);
                        const auto& cell = owner->cells[below];
                        if (material_definition(cell.material_value()).state == MaterialState::Solid) return depth;
                        if ((owner->wave->meta[below] & WaveChunk::kFull) == 0U) return 0;
                    }
                    return 0;
                };
                bool floor_front = false;
                if (config_.wave_flow.floor_gain != 0 && code == WaveChunk::kGainNormal &&
                    std::min(wave.weight[i], other->wave->weight[j]) < maximum && std::max(a, b) > film) {
                    // The lowest three Water rows can travel as a sheet. Both
                    // faces need full supporting Water down to the same floor.
                    const auto depth = floor_depth(&chunk, i);
                    floor_front = depth != 0 && floor_depth(other, j) == depth;
                }
                if (!floor_front && a != 0 && b != 0 && ((meta_a | meta_b) & WaveChunk::kFull) == 0U) {
                    // A film: two partly filled cells that both rest on a solid
                    // floor. Less than a cell of Water carries no wave worth
                    // keeping, and momentum would let it creep for thousands
                    // of ticks. It levels directly instead: about a quarter of
                    // the difference while the donor is above the adhesion
                    // threshold and the cells differ by more than one unit.
                    // Each face budgets from the pre-apply donor mass. Two faces
                    // can leave it below the threshold, which stops later outflow
                    // rather than guaranteeing a minimum residue. Nothing is remembered.
                    if (supported(&chunk, i) && supported(other, j)) {
                        const auto difference = a - b;
                        const auto spare = std::max(0, std::max(a, b) - film);
                        const auto units = std::abs(difference) <= config_.wave_flow.rest_head
                            ? 0 : std::min((std::abs(difference) + 2) >> 2, spare);
                        const auto direct = (difference > 0 ? units : -units) * (1 << P::kFluxShift);
                        wave.flux[i] = direct;
                        wave.half[task.half].pending_flux = wave.half[task.half].pending_flux || direct != 0;
                        continue;
                    }
                }
                const auto& tuning = config_.wave_flow;
                const bool pool_face = a != 0 && b != 0 && code == WaveChunk::kGainNormal &&
                    (meta_a >> WaveChunk::kDepthShift) < WaveChunk::kFalling &&
                    (meta_b >> WaveChunk::kDepthShift) < WaveChunk::kFalling;
                auto previous = wave.flux[i];
                if (tuning.flux_smoothing != 0 && pool_face) {
                    // A missing, solid, dry, or paused outside cell ends the
                    // stencil (zero gradient). Only connected Water contributes.
                    const auto neighbour = [&](const Chunk* owner, std::int32_t x, bool left) noexcept {
                        if (x < 0) { owner = owner->wave->left; x = size - 1; }
                        else if (x == size) { owner = owner->wave->right; x = 0; }
                        if (owner == nullptr || !owner->wave->included(x, ly)) return previous;
                        const auto k = row + static_cast<std::size_t>(x);
                        const auto m = owner->wave->meta[k];
                        if ((m & WaveChunk::kWet) == 0 || (m & WaveChunk::kGainMask) != WaveChunk::kGainNormal ||
                            (m >> WaveChunk::kDepthShift) >= WaveChunk::kFalling) return previous;
                        return left ? owner->wave->prior_flux[k] : other->wave->prior_flux[j];
                    };
                    const auto left_flux = neighbour(&chunk, lx - 1, true);
                    const auto right_flux = neighbour(other, static_cast<std::int32_t>(j - row) + 1, false);
                    const auto curvature = static_cast<std::int64_t>(left_flux) + right_flux - 2LL * previous;
                    previous += static_cast<std::int32_t>(curvature * tuning.flux_smoothing / 256);
                }
                // Flux below kCalm is damped hard. A real wave only passes
                // through that range near its turning points, where its energy
                // is in the heads, so it loses almost nothing; the residue that
                // rounding whole units leaves behind stays in that range and is
                // absorbed instead of ringing at the solver's low damping.
                const auto speed = std::abs(previous);
                const auto damping = previous == 0 ? 0
                    : (previous > 0 ? 1 : -1) * std::max(1, speed >> (speed < config_.wave_flow.calm ? config_.wave_flow.calm_damp_shift : config_.wave_flow.damp_shift));
                auto gain = code == WaveChunk::kGainConfined ? tuning.gain_confined : tuning.gain;
                // Depth class two starts at three responding rows in each
                // stack. A dry or thin advancing front always uses ordinary gain.
                if (tuning.deep_gain != 0 && code == WaveChunk::kGainNormal) {
                    // A partial top cell is its own one-row stack in Wave.
                    // It belongs to the pool wave if a deep stack lies directly
                    // beneath it. This also covers an Empty cell just above
                    // the pool, without slowing a wave spreading onto dry land.
                    const auto deep_stack = [](std::uint8_t meta) noexcept {
                        const auto depth = meta >> WaveChunk::kDepthShift;
                        return (meta & WaveChunk::kGainMask) == WaveChunk::kGainNormal &&
                               depth >= 2 && depth < WaveChunk::kFalling;
                    };
                    const auto deep_column = [&](const Chunk* owner, std::size_t at, std::uint8_t meta) noexcept {
                        if (deep_stack(meta)) return true;
                        if ((meta >> WaveChunk::kDepthShift) >= WaveChunk::kFalling) return false;
                        const auto column = static_cast<std::int32_t>(at - row);
                        if (ly + 1 < size)
                            return owner->wave->included(column, ly + 1) && deep_stack(owner->wave->meta[at + stride]);
                        const auto* below = owner->wave->below;
                        return below != nullptr && below->wave->solve && below->wave->included(column, 0) &&
                               deep_stack(below->wave->meta[static_cast<std::size_t>(column)]);
                    };
                    if (deep_column(&chunk, i, meta_a) && deep_column(other, j, meta_b)) gain = tuning.deep_gain;
                }
                auto flux = static_cast<std::int64_t>(previous) - damping + static_cast<std::int64_t>(head) * gain;
                if (floor_front) {
                    // Accelerate at most one cell of head. Deeper head keeps
                    // ordinary gain. The usual two-face donor and room bounds
                    // below cap the resulting total flux, including inertia.
                    const auto toe_head = std::clamp(head, -maximum, maximum);
                    flux += static_cast<std::int64_t>(toe_head) * (tuning.floor_gain - gain);
                }
                // Rest rule: one unit cannot level a one-unit step (it only
                // flips it), so a small flux across such a step is discarded.
                // Larger flux retains its wave inertia until damping calms it.
                if (a != 0 && b != 0 && std::abs(head) <= config_.wave_flow.rest_head && std::abs(flux) < config_.wave_flow.stick) flux = 0;
                // A resting exposed stack can discharge under its own head even
                // when the ordinary restoring gain is zero. Dry and blocked
                // receivers still go through the open-face test below.
                const bool sheet_start = flux == 0 && spill.enabled && spill.sheet_rate != 0 &&
                    static_cast<std::int64_t>(std::abs(head)) * spill.sheet_rate >= maximum &&
                    ((head > 0 ? meta_a : meta_b) >> WaveChunk::kDepthShift) != WaveChunk::kFalling;
                const bool rightward = flux > 0 || (sheet_start && head > 0);
                auto available = rightward ? a : b;
                const auto destination_mass = rightward ? b : a;
                // Spill: the receiver is open when it is falling Water, or an
                // Empty cell with nothing under it that could hold Water up.
                bool open = false;
                int spill_kind = 0;
                if (spill.enabled && (flux != 0 || sheet_start)) {
                    if (destination_mass != 0) {
                        open = ((rightward ? meta_b : meta_a) >> WaveChunk::kDepthShift) == WaveChunk::kFalling;
                    } else {
                        const auto* owner = rightward ? other : &chunk;
                        const auto at = rightward ? j : i;
                        std::uint8_t under = WaveChunk::kSolid;
                        if (ly + 1 < size) {
                            // Paused cells keep stale meta; the column pass treats them as solid.
                            if (owner->wave->included(static_cast<std::int32_t>(at - row), ly + 1))
                                under = owner->wave->meta[at + stride];
                        }
                        else if (const auto* below = owner->wave->below;
                                 below != nullptr && below->wave->solve && below->wave->included(static_cast<std::int32_t>(at - row), 0))
                            under = below->wave->meta[at - row];
                        open = (under & WaveChunk::kSolid) == 0U &&
                               ((under & WaveChunk::kWet) == 0U || (under >> WaveChunk::kDepthShift) == WaveChunk::kFalling);
                    }
                }
                if (open) {
                    const bool donor_falling = ((rightward ? meta_a : meta_b) >> WaveChunk::kDepthShift) == WaveChunk::kFalling;
                    if (donor_falling) {
                        // A falling stream stays together; only its dense part
                        // (above `stream`) spreads, so a saturated curtain widens.
                        available = std::max(0, available - spill.stream) >> 1;
                    } else {
                        // An exposed face of resting Water discharges a share of
                        // its cell per round, whatever the depth of its stack.
                        if (rightward ? supported(&chunk, i) : supported(other, j)) available -= film;
                        available = std::max(0, available) >> spill.share_shift;
                    }
                    // A parcel flies out of the cell without occupying grid room.
                    // A full falling curtain may still pass spray from the wall behind it.
                    const auto face_share = std::min(available, maximum >> 1);
                    // Falling Water is never overfilled: two faces share the room.
                    available = std::min(available, std::max(0, maximum - destination_mass) >> 1);
                    const auto donor_head = rightward ? wave.weight[i] : other->wave->weight[j];
                    const auto donor_mass = rightward ? a : b;
                    if (spill.sheet_rate != 0 && !donor_falling && ((head > 0) == rightward)) {
                        // Each wet row owns one slice of the vertical sheet. Supply
                        // it immediately from head while retaining faster outward
                        // momentum. The ordinary donor and room caps still apply.
                        const auto sheet = std::min<std::int64_t>(available,
                            static_cast<std::int64_t>(std::abs(head)) * spill.sheet_rate / maximum);
                        const auto rate = sheet * (std::int64_t{1} << P::kFluxShift);
                        flux = rightward ? std::max(flux, rate) : std::min(flux, -rate);
                    }
                    const bool full_face = spill.full_face != 0;
                    const bool throwing_row = full_face || spill.sheet_rate == 0 || donor_head <= 2 * maximum;
                    const auto release = full_face ? face_share : available;
                    if (state.launch && throwing_row && !donor_falling && (destination_mass == 0 || full_face) &&
                        release >= spill.launch_min) {
                        // Reserve the thrown share before the grid transfer.
                        // A successful launch debits its own donor after apply.
                        auto& list = state.scratch[task_index];
                        // stream_share keeps part of the face pouring as the
                        // vertical stream; the rest is thrown. stream_draw pours
                        // an extra share from the face cell itself, so the throw
                        // keeps its size and the pool feed refills the face.
                        // In full-face mode the sheet fraction keeps a coherent grid
                        // stream alongside spray. Either stream control can add to it.
                        const auto fraction = full_face ? std::max(spill.sheet_rate, spill.stream_share) : spill.stream_share;
                        const auto keep = (release * fraction) >> 8;
                        const auto thrown = release - keep;
                        const auto drawn = (release * spill.stream_draw) >> 8;
                        if (thrown < spill.launch_min) {
                            // Too little left to throw: the whole share pours.
                        } else if (full_face || list.launch.size() < WaveSpillConfig::kLaunchCandidatesPerTask) {
                            if (state.final_round) {
                                // Carry the outward Wave velocity (mass flux / donor
                                // mass, converted from rounds to ticks) into crest flight.
                                std::int32_t crest_speed_q = -1;
                                if (spill.coyote_ticks != 0 && donor_head <= maximum) {
                                    const auto outward = std::min<std::int64_t>(std::abs(flux),
                                        static_cast<std::int64_t>(release) << P::kFluxShift);
                                    crest_speed_q = static_cast<std::int32_t>(outward * config_.wave_flow.substeps *
                                        BallisticWaterConfig::kQ / (static_cast<std::int64_t>(donor_mass) << P::kFluxShift));
                                }
                                list.nominate({origin_x + lx + (rightward ? 0 : 1), origin_y + ly,
                                               full_face ? donor_head : std::abs(head), thrown, rightward ? 1 : -1,
                                               crest_speed_q}, full_face, state.round);
                            }
                            // The receiver is Empty: two faces share its room.
                            // The launch takes what the cell still holds after
                            // the apply pass, so ownership stays exact.
                            // Never more than this face's own share: the two-face
                            // donor budget (share_shift >= 1) must still hold.
                            const auto grid_budget = (full_face || spill.sheet_rate != 0 || spill.coyote_ticks != 0)
                                ? (donor_mass >> 1) - thrown : available;
                            available = std::min({keep + drawn, grid_budget, available, maximum >> 1});
                        } else if (state.final_round) {
                            ++list.launch_overflow;
                        }
                    }
                    spill_kind = available == 0 ? 0 : donor_falling ? 2 : 1;
                } else if (destination_mass == 0) {
                    // A supported donor uses the adhesion threshold wherever
                    // it pours, as the per-cell Water law does. This is a
                    // start-of-round threshold, not a minimum final mass.
                    // Keyed on the destination's floor instead, a ledge drained
                    // to its last units for a very long time.
                    if (rightward ? supported(&chunk, i) : supported(other, j)) available -= film;
                    // Pouring into an empty cell is one-directional; a quarter of
                    // the cell per round cannot invert a pair of columns.
                    available >>= config_.wave_flow.empty_pour_shift;
                } else {
                    // Inertia is bounded: a face may coast at most kCoast units
                    // against or beyond its head difference. Larger transfers are
                    // limited to a share of that difference, so bulk flow relaxes
                    // without overshoot while small flow keeps its momentum.
                    const auto depth_of = [&](std::uint8_t meta) noexcept {
                        const auto stack = meta >> WaveChunk::kDepthShift;
                        return spill.enabled && stack == WaveChunk::kFalling ? 0 : stack;
                    };
                    const auto depth = std::max(depth_of(meta_a), depth_of(meta_b));
                    const auto downhill = (head > 0) == rightward ? std::abs(head) >> (config_.wave_flow.level_shift + depth) : 0;
                    // Spill: bulk flow may exceed the wave coast limit unless it
                    // runs against more than `draw_head` of head, so a pool can
                    // feed its draining edge while a reversing surge still relaxes.
                    auto coast = config_.wave_flow.coast;
                    if (spill.enabled && ((head > 0) == rightward || std::abs(head) <= spill.draw_head)) {
                        auto draw = spill.draw;
                        if (spill.deep_draw != 0) {
                            // Opposing draw faces can drain most of a tall column together.
                            // Depth codes 3..5 denote 5..32 responding rows in one wet stack.
                            const auto deep = [](std::uint8_t meta) noexcept {
                                const auto d = meta >> WaveChunk::kDepthShift;
                                return d >= 3 && d < WaveChunk::kFalling;
                            };
                            if (deep(meta_a) || deep(meta_b)) draw = std::min(draw, spill.deep_draw);
                        }
                        coast = std::max(coast, draw);
                    }
                    available = std::min(available >> config_.wave_flow.flow_share_shift, std::max(coast, downhill));
                    if (((rightward ? meta_b : meta_a) >> WaveChunk::kDepthShift) == WaveChunk::kSaturated) available = 0;
                }
                // Two neighbours can send into a receiver concurrently. Each
                // gets at most half of its remaining uint16 capacity; both
                // strips evaluate this same pre-apply bound.
                available = std::min(available, (65535 - destination_mass) / 2);
                const auto cap = available <= 0 ? std::int64_t{0} : static_cast<std::int64_t>(available) << P::kFluxShift;
                flux = rightward ? std::min(flux, cap) : std::max(flux, -cap);
                wave.flux[i] = static_cast<std::int32_t>(flux);
                wave.half[task.half].pending_flux = wave.half[task.half].pending_flux || flux != 0;
                if (spill_kind != 0) {
                    // The apply pass moves exactly this many units through the face.
                    const auto units = static_cast<std::uint64_t>(std::abs(
                        wave_transfer(static_cast<std::int32_t>(flux), origin_x + lx, origin_y + ly, state.round)));
                    auto& counters = wave.half[task.half];
                    if (spill_kind == 2) counters.relief_units += units;
                    else { counters.spill_units += units; counters.spill_faces += units != 0U ? 1U : 0U; }
                }
            }
        }
    }
}

void World::wave_apply_task(std::size_t task_index) noexcept {
    auto& state = *wave_;
    const auto& task = state.tasks[task_index];
    const auto size = config_.chunk_size;
    const auto stride = static_cast<std::size_t>(size);
    const auto first_x = task.half == 0U ? 0 : size / 2;
    const auto last_x = task.half == 0U ? size / 2 : size;
    const auto round = state.round;
    for (std::uint32_t c = 0; c < task.count; ++c) {
        const auto& entry = state.sorted[task.first + c];
        auto& chunk = *entry.chunk;
        auto& wave = *chunk.wave;
        auto& half = wave.half[task.half];
        const auto* left = wave.left;
        const auto origin_x = entry.coord.x * size;
        const auto origin_y = entry.coord.y * size;
        for (std::int32_t ly = 0; ly < size; ++ly) {
            if (ly < wave.min_y || ly >= wave.max_y) continue;
            const auto row = static_cast<std::size_t>(ly) * stride;
            const auto y = origin_y + ly;
            const auto begin_x = std::max(first_x, wave.min_x);
            const auto end_x = std::min(last_x, wave.max_x);
            auto incoming = begin_x > wave.min_x
                ? wave_transfer(wave.flux[row + static_cast<std::size_t>(begin_x) - 1U], origin_x + begin_x - 1, y, round)
                : begin_x == 0 && left != nullptr && left->wave->included(size - 1, ly)
                    ? wave_transfer(left->wave->flux[row + stride - 1U], origin_x - 1, y, round) : 0;
            const bool clean = wave.clean[task.half];
            for (auto lx = begin_x; lx < end_x; ++lx) {
                // Interior faces of a clean half carry nothing.
                if (clean && lx == begin_x + 1 && end_x - begin_x > 2) { lx = end_x - 1; incoming = 0; }
                const auto i = row + static_cast<std::size_t>(lx);
                const bool face_open = lx + 1 < wave.max_x ||
                    (lx + 1 == size && wave.right != nullptr && wave.right->wave->included(0, ly));
                const auto outgoing = face_open ? wave_transfer(wave.flux[i], origin_x + lx, y, round) : 0;
                const auto delta = incoming - outgoing;
                const auto magnitude = std::max(std::abs(incoming), std::abs(outgoing));
                incoming = outgoing;
                if (delta == 0) continue;
                auto& cell = chunk.cells[i];
                const auto before = cell.material_value() == Material::Water
                                        ? static_cast<std::int32_t>(cell.state_a_value()) : 0;
                wave_write_mass(chunk, i, before, before + delta, half);
                half.touch(lx, ly);
                half.peak = std::max(half.peak, magnitude);
                half.moved += static_cast<std::uint64_t>(std::abs(delta));
            }
        }
    }
}

void World::advance_wave_flow(TickStats& stats) {
    using Clock = std::chrono::steady_clock;
    const auto elapsed = [](Clock::time_point from) {
        return static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now() - from).count());
    };
    auto& state = *wave_;
    auto& diagnostics = state.diagnostics;
    ++diagnostics.ticks;
    auto started = Clock::now();
    const auto size = config_.chunk_size;
    const auto stride = static_cast<std::size_t>(size);

    state.film = liquid_surface_adhesion_enabled_ ? config_.water_experiment_policy.film() >> config_.wave_flow.adhesion_shift : 0;
    const auto included_chunk = [&](ChunkCoord coord, WaveChunk& wave) {
        wave.min_x = wave.min_y = 0;
        wave.max_x = wave.max_y = size;
        if (!selected_core_region_) return true;
        const auto ox = coord.x * size, oy = coord.y * size;
        const auto first = scheduler_geometry_.core_for_cell(ox, oy);
        const auto last = scheduler_geometry_.core_for_cell(ox + size - 1, oy + size - 1);
        const auto& region = *selected_core_region_;
        if (last.x < region.min_x || first.x > region.max_x ||
            last.y < region.min_y || first.y > region.max_y) {
            wave.max_x = wave.max_y = 0;
            return false;
        }
        const auto core = config_.scheduling_core_size;
        if (first.x < region.min_x)
            wave.min_x = static_cast<std::int32_t>((region.min_x - first.x) * core - positive_mod(ox, core));
        if (first.y < region.min_y)
            wave.min_y = static_cast<std::int32_t>((region.min_y - first.y) * core - positive_mod(oy, core));
        if (last.x > region.max_x)
            wave.max_x = static_cast<std::int32_t>((region.max_x - first.x + 1) * core - positive_mod(ox, core));
        if (last.y > region.max_y)
            wave.max_y = static_cast<std::int32_t>((region.max_y - first.y + 1) * core - positive_mod(oy, core));
        return true;
    };

    // A chunk is active while its Water moved recently or an owner edit, kernel
    // write or body mask touched it. Active chunks and their eight neighbours
    // are solved, so motion can always enter a neighbour in the same tick.
    state.grow.clear();
    for (const auto& [coord, chunk] : chunks_) {
        auto& wave = *chunk->wave;
        wave.active = included_chunk(coord, wave) &&
            (wave.woken || wave.quiet < static_cast<std::uint32_t>(config_.wave_flow.sleep_after));
        wave.solve = false;
        if (!wave.active || chunk->non_empty_cell_count == 0U) continue;
        // Liquid on an edge row or column needs a resident destination. Workers
        // never allocate, so the owner admits the neighbour here.
        const auto* cells = chunk->cells.data();
        bool edge[4] = {false, false, false, false}; // left, right, up, down
        for (std::int32_t k = 0; k < size; ++k) {
            const auto step = static_cast<std::size_t>(k);
            edge[0] = edge[0] || (wave.included(0, k) && cells[step * stride].material_value() == Material::Water);
            edge[1] = edge[1] || (wave.included(size - 1, k) && cells[step * stride + stride - 1U].material_value() == Material::Water);
            edge[2] = edge[2] || (wave.included(k, 0) && cells[step].material_value() == Material::Water);
            edge[3] = edge[3] || (wave.included(k, size - 1) && cells[(stride - 1U) * stride + step].material_value() == Material::Water);
        }
        const ChunkCoord wanted[4] = {{coord.x - 1, coord.y}, {coord.x + 1, coord.y}, {coord.x, coord.y - 1}, {coord.x, coord.y + 1}};
        for (std::size_t k = 0; k < 4U; ++k) {
            if (!edge[k] || find_chunk(wanted[k]) != nullptr) continue;
            if (!wave_chunk_coordinate_fits(wanted[k], size)) { ++diagnostics.boundary_refusals; continue; }
            // Do not allocate offscreen recipients for paused work.
            if (selected_core_region_) {
                const auto x = coord.x * size + (k == 0U ? -1 : k == 1U ? size : wave.min_x);
                const auto y = coord.y * size + (k == 2U ? -1 : k == 3U ? size : wave.min_y);
                const auto at = scheduler_geometry_.core_for_cell(x, y);
                const auto& region = *selected_core_region_;
                if (at.x < region.min_x || at.x > region.max_x || at.y < region.min_y || at.y > region.max_y) continue;
            }
            state.grow.push_back(wanted[k]);
        }
    }
    std::sort(state.grow.begin(), state.grow.end());
    state.grow.erase(std::unique(state.grow.begin(), state.grow.end()), state.grow.end());
    for (const auto coord : state.grow) {
        // Capacity is an explicit outcome: an unadmitted neighbour stays a wall.
        if (chunks_.size() >= config_.maximum_chunk_count) { ++diagnostics.capacity_refusals; continue; }
        auto& created = ensure_chunk(coord);
        created.wave->active = included_chunk(coord, *created.wave);
    }

    state.sorted.clear();
    for (const auto& [coord, chunk] : chunks_) {
        auto& wave = *chunk->wave;
        if (!included_chunk(coord, wave)) { wave.solve = false; continue; }
        bool solve = wave.active;
        for (std::int64_t dy = -1; dy <= 1 && !solve; ++dy)
            for (std::int64_t dx = -1; dx <= 1 && !solve; ++dx) {
                const auto* other = find_chunk({coord.x + dx, coord.y + dy});
                solve = other != nullptr && other->wave->active;
            }
        wave.solve = solve;
        if (solve) state.sorted.push_back({coord, chunk.get()});
    }
    std::sort(state.sorted.begin(), state.sorted.end(), [](const WaveState::Entry& a, const WaveState::Entry& b) {
        return a.coord.x != b.coord.x ? a.coord.x < b.coord.x : a.coord.y < b.coord.y;
    });
    state.tasks.clear();
    std::size_t tallest = 0;
    for (std::size_t first = 0; first < state.sorted.size();) {
        auto count = std::size_t{1};
        while (first + count < state.sorted.size() &&
               state.sorted[first + count].coord.x == state.sorted[first].coord.x &&
               state.sorted[first + count].coord.y == state.sorted[first + count - 1U].coord.y + 1)
            ++count;
        if (count > static_cast<std::size_t>(std::numeric_limits<std::int32_t>::max() / size))
            throw std::length_error("wave_flow column exceeds its bounded scratch index range");
        state.tasks.push_back({static_cast<std::uint32_t>(first), static_cast<std::uint32_t>(count), 0U});
        state.tasks.push_back({static_cast<std::uint32_t>(first), static_cast<std::uint32_t>(count), 1U});
        tallest = std::max(tallest, count);
        first += count;
    }
    for (const auto& entry : state.sorted) {
        auto& wave = *entry.chunk->wave;
        const auto solved = [this](ChunkCoord coord) -> Chunk* {
            auto* chunk = find_chunk(coord);
            return chunk != nullptr && chunk->wave->solve ? chunk : nullptr;
        };
        wave.left = solved({entry.coord.x - 1, entry.coord.y});
        wave.right = solved({entry.coord.x + 1, entry.coord.y});
        wave.above = find_chunk({entry.coord.x, entry.coord.y - 1});
        wave.below = find_chunk({entry.coord.x, entry.coord.y + 1});
        wave.right_paused = false;
        if (selected_core_region_) {
            const auto right_core = scheduler_geometry_.core_for_cell((entry.coord.x + 1) * size, entry.coord.y * size);
            wave.right_paused = right_core.x > selected_core_region_->max_x;
        }
        wave.half = {};
    }
    // Scratch grows only when the tallest solved column grows.
    if (state.scratch.size() < state.tasks.size()) state.scratch.resize(state.tasks.size());
    const auto rows = tallest * stride;
    for (std::size_t index = 0; index < state.tasks.size(); ++index) {
        auto& scratch = state.scratch[index];
        if (scratch.mass.size() < rows) {
            scratch.mass.resize(rows);
            scratch.weight.resize(rows);
            scratch.flags.resize(rows);
        }
    }
    // Hybrid release: decided once per tick by the owner, never by a worker.
    const auto& spill = config_.wave_flow.spill;
    const bool hybrid = spill.enabled && config_.ballistic_water.enabled && spill.launch_budget > 0;
    // At least one free parcel slot opens the release; the per-tick budget is
    // clamped to the free slots when the launches run. A full pool is counted.
    const bool room = ballistic_parcels_.size() < config_.ballistic_water.capacity;
    if (hybrid && !state.launch_backoff && !room) ++diagnostics.launch_capacity_skips;
    state.launch = hybrid && !state.launch_backoff && room;
    state.launch_backoff = false;
    if (hybrid)
        for (std::size_t index = 0; index < state.tasks.size(); ++index) {
            auto& scratch = state.scratch[index];
            if (scratch.launch.capacity() < WaveSpillConfig::kLaunchCandidatesPerTask)
                scratch.launch.reserve(WaveSpillConfig::kLaunchCandidatesPerTask);
            scratch.launch.clear();
            scratch.launch_overflow = 0;
        }
    state.mask_present = !transient_obstacles_->occupied_indices.empty();
    state.occupied_mask_bounds = {};
    if (state.mask_present) {
        const auto& mask = transient_obstacles_->region;
        const auto mask_width = static_cast<std::size_t>(mask.width);
        auto min_x = mask_width, min_y = static_cast<std::size_t>(mask.height);
        std::size_t max_x = 0, max_y = 0;
        for (const auto index : transient_obstacles_->occupied_indices) {
            const auto x = index % mask_width, y = index / mask_width;
            min_x = std::min(min_x, x); max_x = std::max(max_x, x);
            min_y = std::min(min_y, y); max_y = std::max(max_y, y);
        }
        // Entries were admitted by set_transient_obstacle from representable
        // global coordinates, even if the allocated region extends beyond an
        // int64 endpoint. Do not form the allocated region's endpoint here.
        state.occupied_mask_bounds = {
            mask.x + static_cast<std::int64_t>(min_x),
            mask.y + static_cast<std::int64_t>(min_y),
            static_cast<std::int64_t>(max_x - min_x + 1U),
            static_cast<std::int64_t>(max_y - min_y + 1U)};
    }
    diagnostics.prepare_nanoseconds += elapsed(started);
    diagnostics.last_falling_units = diagnostics.last_falling_cells = 0;
    diagnostics.last_tasks = static_cast<std::uint32_t>(state.tasks.size());
    diagnostics.last_solved_chunks = static_cast<std::uint32_t>(state.sorted.size());
    diagnostics.solved_chunks += state.sorted.size();
    if (state.tasks.empty()) return;

    using Pass = void (World::*)(std::size_t) noexcept;
    struct Dispatch {
        World* world;
        Pass pass;
    };
    const auto run = [&](Pass pass, std::uint64_t& nanoseconds) {
        const auto from = Clock::now();
        Dispatch dispatch{this, pass};
        const auto execute = +[](void* raw, std::size_t index) noexcept {
            auto& context = *static_cast<Dispatch*>(raw);
            (context.world->*context.pass)(index);
        };
        std::uint32_t participants = 1;
        if (parallel_ != nullptr && parallel_->pool != nullptr && state.tasks.size() >= 2U) {
            parallel_->pool->dispatch(state.tasks.size(), &dispatch, execute);
            participants = parallel_->pool->participating_workers();
        } else {
            for (std::size_t index = 0; index < state.tasks.size(); ++index) execute(&dispatch, index);
        }
        diagnostics.maximum_participants = std::max(diagnostics.maximum_participants, participants);
        stats.worker_threads_observed = std::max(stats.worker_threads_observed, participants);
        diagnostics.tasks += state.tasks.size();
        nanoseconds += elapsed(from);
    };
    for (std::uint8_t substep = 0; substep < config_.wave_flow.substeps; ++substep) {
        ++state.round;
        ++diagnostics.rounds;
        state.final_round = substep + 1 == config_.wave_flow.substeps;
        run(&World::wave_column_task, diagnostics.column_nanoseconds);
        run(&World::wave_flux_task, diagnostics.flux_nanoseconds);
        run(&World::wave_apply_task, diagnostics.apply_nanoseconds);
    }

    // Owner-side reduction: activity, render dirtiness and occupancy.
    started = Clock::now();
    bool loaded_oil = false;
    std::uint64_t invalid = 0;
    std::int64_t population = 0;
    diagnostics.last_falling_units = diagnostics.last_falling_cells = 0;
    for (const auto& entry : state.sorted) {
        auto& chunk = *entry.chunk;
        auto& wave = *chunk.wave;
        std::int32_t peak = 0, delta = 0;
        std::uint32_t transitions = 0;
        bool pending_flux = false;
        WaveHalf bounds;
        for (const auto& half : wave.half) {
            peak = std::max(peak, half.peak);
            delta += half.non_empty_delta;
            diagnostics.moved_units += half.moved;
            diagnostics.spill_units += half.spill_units;
            diagnostics.relief_units += half.relief_units;
            diagnostics.spill_faces += half.spill_faces;
            diagnostics.last_falling_units += half.falling_units;
            diagnostics.last_falling_cells += half.falling_cells;
            loaded_oil = loaded_oil || half.oil_last >= 0;
            invalid += half.invalid;
            transitions += half.transitions;
            pending_flux = pending_flux || half.pending_flux;
            stats.moved_cells += half.changed;
            if (half.max_x >= half.min_x) { bounds.touch(half.min_x, half.min_y); bounds.touch(half.max_x, half.max_y); }
        }
        wave.woken = false;
        if (peak >= config_.wave_flow.wake_peak || pending_flux) wave.quiet = 0;
        else if (wave.quiet < static_cast<std::uint32_t>(config_.wave_flow.sleep_after)) ++wave.quiet;
        chunk.non_empty_cell_count = static_cast<std::size_t>(static_cast<std::int64_t>(chunk.non_empty_cell_count) + delta);
        population += delta;
        if (bounds.max_x < bounds.min_x) continue;
        chunk.changed_this_tick = true;
        if (!chunk.dirty) {
            chunk.dirty = true;
            chunk.dirty_min_x = bounds.min_x; chunk.dirty_max_x = bounds.max_x;
            chunk.dirty_min_y = bounds.min_y; chunk.dirty_max_y = bounds.max_y;
        } else {
            chunk.dirty_min_x = std::min(chunk.dirty_min_x, bounds.min_x);
            chunk.dirty_max_x = std::max(chunk.dirty_max_x, bounds.max_x);
            chunk.dirty_min_y = std::min(chunk.dirty_min_y, bounds.min_y);
            chunk.dirty_max_y = std::max(chunk.dirty_max_y, bounds.max_y);
        }
        // Other materials react to Water that arrived or left: keep the
        // touched activity blocks (and their border neighbours) scheduled.
        if (peak < config_.wave_flow.wake_peak && transitions == 0U) continue;
        const auto block = config_.activity_block_size;
        // One cell of margin: a neighbour of a changed cell may sit in the next block.
        const auto wake_min_x = std::max(bounds.min_x - 1, 0), wake_max_x = std::min(bounds.max_x + 1, size - 1);
        const auto wake_min_y = std::max(bounds.min_y - 1, 0), wake_max_y = std::min(bounds.max_y + 1, size - 1);
        for (auto by = wake_min_y / block; by <= wake_max_y / block; ++by)
            for (auto bx = wake_min_x / block; bx <= wake_max_x / block; ++bx) {
                auto& activity = chunk.activity_blocks[static_cast<std::size_t>(by) *
                    static_cast<std::size_t>(chunk.activity_blocks_per_axis) + static_cast<std::size_t>(bx)];
                activity.active = true;
                activity.changed_this_tick = true;
                activity.quiet_ticks = 0;
            }
        chunk.active = true;
        const auto origin_x = entry.coord.x * size, origin_y = entry.coord.y * size;
        // Walk the perimeter one activity block at a time so blocks in
        // neighbouring chunks along a touched edge are woken, not only corners.
        for (auto x = bounds.min_x;; x = std::min(x + block, bounds.max_x)) {
            wake_cell_neighborhood(origin_x + x, origin_y + bounds.min_y, false);
            wake_cell_neighborhood(origin_x + x, origin_y + bounds.max_y, false);
            if (x == bounds.max_x) break;
        }
        for (auto y = bounds.min_y;; y = std::min(y + block, bounds.max_y)) {
            wake_cell_neighborhood(origin_x + bounds.min_x, origin_y + y, false);
            wake_cell_neighborhood(origin_x + bounds.max_x, origin_y + y, false);
            if (y == bounds.max_y) break;
        }
    }
    // Spreading changes how many cells hold Water without changing its
    // quantity: keep the native ledger's cell population exact.
    apply_wave_population(population);
    diagnostics.merge_nanoseconds += elapsed(started);
    if (invalid != 0) throw std::runtime_error("wave_flow produced a Water mass outside its carrier");
    if (state.launch) {
        // Serial, in strip order: the same launches for every worker count.
        // Each one is an exact transfer from its cell to one parcel.
        started = Clock::now();
        const auto& law = config_.ballistic_water;
        auto budget = static_cast<std::int32_t>(std::min<std::size_t>(static_cast<std::size_t>(spill.launch_budget),
            config_.ballistic_water.capacity - ballistic_parcels_.size()));
        // Thin an over-budget full face evenly through the entire nomination
        // sequence, instead of always spending the pool slots on the top rows.
        std::uint64_t nominees = 0;
        if (spill.full_face != 0)
            for (std::size_t index = 0; index < state.tasks.size(); ++index) nominees += state.scratch[index].launch.size();
        const auto quota = static_cast<std::uint64_t>(budget);
        const bool thinning = nominees > quota;
        auto phase = thinning ? mix64(state.round) % nominees : 0;
        bool held = false;
        for (std::size_t index = 0; index < state.tasks.size(); ++index) {
            auto& scratch = state.scratch[index];
            if (scratch.launch_overflow != 0U) { diagnostics.launch_deferrals += scratch.launch_overflow; held = true; }
            for (const auto& face : scratch.launch) {
                if (thinning) {
                    phase += quota;
                    if (phase < nominees) { ++diagnostics.launch_deferrals; held = true; continue; }
                    phase -= nominees;
                }
                if (budget == 0) { ++diagnostics.launch_deferrals; held = true; continue; }
                std::int64_t spawn_x = 0, spawn_y = 0;
                if (!BallisticWaterConfig::spawn_cell_center_q(face.x, face.side, spawn_x) ||
                    !BallisticWaterConfig::spawn_cell_center_q(face.y, 0, spawn_y)) {
                    ++diagnostics.launch_refusals;
                    held = true;
                    continue;
                }
                // Integer sqrt(2 g h) in q per tick; h is the head in cells.
                const auto energy = static_cast<std::uint64_t>(2 * law.gravity_q) * static_cast<std::uint64_t>(face.head) *
                                    static_cast<std::uint64_t>(BallisticWaterConfig::kQ) / static_cast<std::uint64_t>(state.maximum);
                std::uint64_t root = 0;
                for (std::uint64_t bit = std::uint64_t{1} << 20; bit != 0; bit >>= 1)
                    if ((root + bit) * (root + bit) <= energy) root += bit;
                // A fixed, position-keyed spread keeps a sheet from flying as one line.
                const auto key = mix64(static_cast<std::uint64_t>(face.x) * 0x9e3779b97f4a7c15ULL ^
                                       static_cast<std::uint64_t>(face.y) * 0xc2b2ae3d27d4eb4fULL ^ state.round);
                auto speed = static_cast<std::int64_t>(root) * spill.launch_speed / 256;
                speed += speed * static_cast<std::int64_t>(key & 63U) / 256;
                if (face.crest_speed_q >= 0) speed += face.crest_speed_q;
                speed = std::min<std::int64_t>(speed, law.max_speed_q);
                const auto drop = face.crest_speed_q >= 0 ? 0 : static_cast<std::int32_t>((key >> 8) & 15U);
                const auto result = launch_ballistic_water_internal(face.x, face.y, spawn_x, spawn_y,
                    static_cast<std::int32_t>(face.side * speed), drop, 0, static_cast<std::uint32_t>(face.quantity), true);
                if (result.outcome != BallisticLaunchOutcome::Launched) { ++diagnostics.launch_refusals; held = true; continue; }
                if (face.crest_speed_q >= 0) ballistic_parcels_.back().coyote_left = static_cast<std::uint8_t>(spill.coyote_ticks);
                ++diagnostics.launched_parcels;
                diagnostics.launched_units += result.quantity;
                --budget;
            }
        }
        state.launch_backoff = held;
        diagnostics.launch_nanoseconds += elapsed(started);
    }
    if (loaded_oil) advance_floating_oil();
}

// Only the owner calls this, after the three Wave passes and ballistic launches.
void World::advance_floating_oil() {
    const auto& state = *wave_;
    const auto size = config_.chunk_size;
    const auto stride = static_cast<std::size_t>(size);
    // Vertical motion needs an open top. Lateral spreading also needs a
    // connected Water-backed surface and at least three Oil cells on the donor.
    constexpr int reach = 16, max_depth = 64;
    const auto surface_cell = [&](std::int64_t x, std::int64_t y) {
        const auto a = address(x, y);
        const auto* chunk = find_chunk(a.chunk);
        if (!chunk || !chunk->wave->solve || !chunk->wave->included(a.local_x, a.local_y) ||
            (state.mask_present && transient_obstacle_at(x, y) != 0)) return Material::Wall;
        return chunk->cells[a.index].material_value();
    };
    // Retiring an endpoint clears both incident horizontal faces. Hold an
    // endpoint at a selected-region edge until its neighbouring core resumes.
    const auto faces_selected = [&](std::int64_t x, std::int64_t y) {
        return !selected_core_region_ ||
            (scheduler_geometry_.core_for_cell(x - 1, y).x >= selected_core_region_->min_x &&
             scheduler_geometry_.core_for_cell(x + 1, y).x <= selected_core_region_->max_x);
    };
    const auto oil_available = [&](std::int64_t x, std::int64_t y) {
        const auto a = address(x, y);
        return find_chunk(a.chunk)->cells[a.index].epoch_value() != update_epoch_ && faces_selected(x, y);
    };
    // Pre-admit thermal storage before changing a tuple outside the material-job halo.
    const auto move_oil = [&](std::int64_t x, std::int64_t y, std::int64_t tx, std::int64_t ty) {
        if (stored_temperature(x, y) != config_.ambient_temperature)
            ensure_temperature_field(*find_chunk(address(tx, ty).chunk));
        move_cell(x, y, tx, ty, false, nullptr);
    };
    // Wave keeps excess volume underneath an impermeable cap. Let an exposed
    // slick follow it by one grid row. Moving just the end Oil cell preserves
    // the whole slick's occupancy and transports its complete stored tuple.
    // The gap between the rise and fall thresholds keeps a level interface quiet.
    const auto follow_water = [&](std::int64_t x, std::int64_t top, std::int64_t bottom) {
        const auto water_y = bottom + 1;
        const auto water = stored_state_a(x, water_y);
        const auto maximum = state.maximum;
        if (water > state.oil_lift_threshold() && oil_available(x, bottom) && faces_selected(x, top - 1)) {
            const auto rise = static_cast<std::uint16_t>(std::min<int>(water - maximum, maximum));
            const auto temperature = stored_temperature(x, water_y);
            if (temperature != config_.ambient_temperature)
                ensure_temperature_field(*find_chunk(address(x, bottom).chunk));
            move_oil(x, bottom, x, top - 1);
            write_transferred_water(x, water_y, static_cast<std::uint16_t>(water - rise));
            write_transferred_water(x, bottom, rise);
            set_temperature(x, bottom, temperature);
            return true;
        }
        if (water >= state.oil_drop_threshold() || !oil_available(x, top) || !faces_selected(x, water_y) ||
            surface_cell(x, water_y + 1) != Material::Water) return false;
        const auto below = stored_state_a(x, water_y + 1);
        if (below < maximum || below + water > std::min(65535, state.oil_lift_threshold())) return false;
        // Only consolidate Water of equal temperature. Otherwise ordinary
        // withdrawal can empty the cell without mixing unlike thermal states.
        if (stored_temperature(x, water_y) != stored_temperature(x, water_y + 1)) return false;
        if (stored_temperature(x, top) != config_.ambient_temperature)
            ensure_temperature_field(*find_chunk(address(x, water_y).chunk));
        write_transferred_water(x, water_y, 0);
        write_transferred_water(x, water_y + 1, static_cast<std::uint16_t>(below + water));
        move_cell(x, top, x, water_y, false, nullptr);
        return true;
    };
    for (const auto& entry : state.sorted) {
        const auto& wave = *entry.chunk->wave;
        for (std::int32_t h = 0; h < 2; ++h) {
            const auto& half = wave.half[static_cast<std::size_t>(h)];
            for (auto ly = half.oil_first; ly <= half.oil_last; ++ly) {
                const auto bottom = entry.coord.y * size + ly;
                // Keep every bounded search and its one-cell air clearance representable.
                constexpr int margin = max_depth + reach + 3;
                if (bottom < std::numeric_limits<std::int64_t>::min() + margin ||
                    bottom > std::numeric_limits<std::int64_t>::max() - margin) continue;
                for (auto lx = h == 0 ? 0 : size / 2; lx < (h == 0 ? size / 2 : size); ++lx) {
                    const auto x = entry.coord.x * size + lx;
                    if (x < std::numeric_limits<std::int64_t>::min() + reach + 1 ||
                        x > std::numeric_limits<std::int64_t>::max() - reach - 1) continue;
                    const auto idx = static_cast<std::size_t>(ly) * stride + static_cast<std::size_t>(lx);
                    if (entry.chunk->cells[idx].material_value() != Material::Oil ||
                        surface_cell(x, bottom + 1) != Material::Water) continue;
                    int depth = 0;
                    while (depth < max_depth && surface_cell(x, bottom - depth) == Material::Oil) ++depth;
                    const auto top = bottom - depth + 1;
                    if (surface_cell(x, top - 1) != Material::Empty || follow_water(x, top, bottom)) continue;
                    if (depth < 3 || !oil_available(x, top)) continue;
                    auto target_x = x, target_y = top;
                    auto best = depth - 1;
                    const auto direction = deterministic_direction(x, bottom);
                    for (const auto dx : {direction, -direction}) {
                        auto surface = top;
                        for (int d = 1; d <= reach; ++d) {
                            const auto nx = x + d * dx;
                            // Follow a connected surface by at most one row per column.
                            // On a rise both columns need open air at the higher level.
                            auto next = surface;
                            const auto air = surface_cell(nx, next - 1);
                            if (air == Material::Water || air == Material::Oil) {
                                if (surface_cell(nx - dx, next - 2) != Material::Empty ||
                                    surface_cell(nx, next - 2) != Material::Empty) break;
                                --next;
                            } else if (air != Material::Empty) {
                                break;
                            } else if (surface_cell(nx, next) == Material::Empty) {
                                ++next;
                            }
                            auto value = surface_cell(nx, next);
                            int thickness = 0;
                            while (thickness < max_depth && value == Material::Oil)
                                value = surface_cell(nx, next + ++thickness);
                            if (value != Material::Water) break;
                            if (thickness < best && faces_selected(nx, next - 1)) {
                                best = thickness;
                                target_x = nx;
                                target_y = next - 1;
                            }
                            surface = next;
                            if (best == 0) break;
                        }
                        if (best == 0) break;
                    }
                    if (target_x == x) continue;
                    move_oil(x, top, target_x, target_y);
                }
            }
        }
    }
}
