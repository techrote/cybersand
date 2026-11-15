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
// count. Chunks whose Water has been quiet stop being solved until woken.

// Per-strip result of one tick for half of a chunk; reduced by the owner.
struct alignas(64) World::WaveHalf {
    std::int32_t min_x = 0, min_y = 0, max_x = -1, max_y = -1;
    std::int32_t peak = 0;
    std::int32_t non_empty_delta = 0;
    std::uint64_t moved = 0;
    std::uint32_t invalid = 0;
    std::uint32_t transitions = 0; // cells that became or stopped being Water
    void touch(std::int32_t x, std::int32_t y) noexcept {
        if (max_x < min_x) { min_x = max_x = x; min_y = max_y = y; return; }
        min_x = std::min(min_x, x); max_x = std::max(max_x, x);
        min_y = std::min(min_y, y); max_y = std::max(max_y, y);
    }
};

struct World::WaveChunk {
    static constexpr std::uint8_t kGainMask = 3, kGainNormal = 1, kGainConfined = 2;
    static constexpr std::uint8_t kFull = 4, kSolid = 8, kWet = 16;
    // Bits 5-7: ceil(log2) of the responding rows of the cell's stack (0..5).
    static constexpr std::uint8_t kDepthShift = 5;
    static constexpr std::uint8_t kSaturated = 7; // depth code of a stack at the carrier ceiling
    explicit WaveChunk(std::size_t count, std::size_t columns)
        : flux(count, 0), weight(count, 0), meta(count, 0), dry(columns, 0) {}
    std::vector<std::int32_t> flux;   // authoritative: retained flux through the right face
    std::vector<std::int32_t> weight; // derived: head above the cell floor, in mass units
    std::vector<std::uint8_t> meta;   // derived: gain code, full, solid, wet
    Chunk* left = nullptr;            // solved neighbours this tick, else null
    Chunk* right = nullptr;
    Chunk* above = nullptr;           // resident neighbour, solved or not
    Chunk* below = nullptr;
    std::uint32_t quiet = 0;
    bool woken = true;
    bool active = false;
    bool solve = false;
    // A half that is entirely Empty with zeroed flux and derived state: its
    // interior needs no work until something writes into it.
    std::array<bool, 2> clean{};
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
    struct Scratch {
        std::vector<std::int32_t> mass, weight;
        std::vector<std::uint8_t> flags;
    };
    std::vector<Entry> sorted;
    std::vector<ChunkCoord> grow;
    std::vector<Task> tasks;
    std::vector<Scratch> scratch;
    std::int32_t maximum = 0, film = 0;
    std::uint32_t round = 0;
    bool mask_present = false;
    WaveFlowDiagnostics diagnostics{};
};

namespace {

// Whole mass units moved through a face in one round. The sub-unit part of the
// flux is resolved by a stateless per-face, per-round dither: the expected
// transfer equals the flux, and identical rows do not move in lockstep.
[[nodiscard]] inline std::int32_t wave_transfer(std::int32_t flux, std::int64_t x, std::int64_t y,
                                                std::uint32_t round) noexcept {
    if (flux == 0) return 0;
    std::uint32_t k = static_cast<std::uint32_t>(x) * 73856093U ^
                      static_cast<std::uint32_t>(y) * 19349663U ^ round * 83492791U;
    k ^= k >> 15;
    k *= 0x2C1B3C6DU;
    k ^= k >> 12;
    return (flux + static_cast<std::int32_t>(k & 4095U)) >> WaveFlowParameters::kFluxShift;
}

}  // namespace

void World::validate_wave_flow_config() const {
    if (!config_.wave_flow.enabled) return;
    using P = WaveFlowParameters;
    if (config_.wave_flow.substeps == 0U || config_.wave_flow.substeps > P::kMaximumSubsteps)
        throw std::invalid_argument("wave_flow substeps must be between 1 and 8");
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
    if (config_.ballistic_water.enabled)
        throw std::invalid_argument("wave_flow does not support ballistic_water_v1");
}

bool World::wave_flow_enabled() const noexcept { return wave_ != nullptr; }

WaveFlowDiagnostics World::wave_flow_diagnostics() const noexcept {
    if (wave_ == nullptr) return {};
    auto result = wave_->diagnostics;
    for (const auto& [coord, chunk] : chunks_) {
        (void)coord;
        if (chunk->wave == nullptr) continue;
        result.storage_bytes += chunk->wave->flux.capacity() * sizeof(std::int32_t) +
                                chunk->wave->weight.capacity() * sizeof(std::int32_t) +
                                chunk->wave->meta.capacity() + sizeof(WaveChunk);
    }
    for (const auto& scratch : wave_->scratch)
        result.storage_bytes += (scratch.mass.capacity() + scratch.weight.capacity()) * sizeof(std::int32_t) +
                                scratch.flags.capacity();
    return result;
}

void World::wake_wave_chunk(Chunk& chunk) noexcept {
    if (chunk.wave == nullptr) return;
    chunk.wave->woken = true;
    chunk.wave->clean = {};
    chunk.wave->dry_reset = {true, true};
}

void World::wave_column_task(std::size_t task_index) noexcept {
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
    // Body masks: only the rows of this strip inside the mask region are probed.
    const auto& mask = transient_obstacles_->region;
    std::int32_t mask_first = 0, mask_last = 0;
    if (state.mask_present) {
        mask_first = static_cast<std::int32_t>(std::clamp<std::int64_t>(mask.y - origin_y, 0, rows));
        mask_last = static_cast<std::int32_t>(std::clamp<std::int64_t>(mask.y + mask.height - origin_y, 0, rows));
    }
    constexpr std::uint32_t kMaximumGroup = 64;
    bool skip[kMaximumGroup] = {}, empty[kMaximumGroup] = {};
    for (std::uint32_t c = 0; c < task.count && c < kMaximumGroup; ++c) {
        const auto base = static_cast<std::int32_t>(c) * size;
        skip[c] = entries[c].chunk->wave->clean[task.half] && !(base < mask_last && base + size > mask_first);
        empty[c] = true;
    }

    for (std::uint32_t c = 0; c < task.count; ++c) {
        auto& wave = *entries[c].chunk->wave;
        if (!wave.dry_reset[task.half]) continue;
        std::fill_n(wave.dry.data() + first_x, last_x - first_x, std::uint8_t{0});
        wave.dry_reset[task.half] = false;
    }

    for (auto lx = first_x; lx < last_x; ++lx) {
        const bool masked_column = mask_last > mask_first && origin_x + lx >= mask.x && origin_x + lx < mask.x + mask.width;
        if (!masked_column) {
            // A column that is dry in every chunk of the group cannot change:
            // liquid enters it only through the apply pass or an owner edit,
            // and both clear the mark.
            bool dry = true;
            for (std::uint32_t c = 0; c < task.count && dry; ++c)
                dry = entries[c].chunk->wave->dry[static_cast<std::size_t>(lx)] != 0U;
            if (dry) {
                for (std::uint32_t c = 0; c < task.count && c < kMaximumGroup; ++c)
                    if (entries[c].chunk->wave->dry[static_cast<std::size_t>(lx)] != 2U) empty[c] = false;
                continue;
            }
        }
        // Gather the column: -1 solid, 0 empty, otherwise Water mass.
        for (std::uint32_t c = 0; c < task.count; ++c) {
            const auto& chunk = *entries[c].chunk;
            if (c < kMaximumGroup && skip[c]) {
                // A clean half is all Empty by definition: no cell is read.
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
                mass[base + ly] = material == Material::Water ? static_cast<std::int32_t>(cell.state_a_value())
                                  : material == Material::Empty ? 0 : -1;
                flags[base + ly] = meta[static_cast<std::size_t>(ly) * static_cast<std::size_t>(size)] & WaveChunk::kFull;
            }
        }
        if (masked_column) {
            for (auto r = mask_first; r < mask_last; ++r) {
                const auto body = transient_obstacle_at(origin_x + lx, origin_y + r);
                if (body == 0U) continue;
                // Water resting on a body presses it down (the existing contract).
                if (r > 0 && mass[r - 1] > 0)
                    record_transient_contact(body, Material::Water, 0, 1, origin_x + lx, origin_y + r - 1);
                mass[r] = -1;
            }
        }

        // Settle, bottom-up. `dst` is the lowest cell that may still receive.
        // Cells that were full after the previous settle transmit support:
        // deficits left by lateral outflow are refilled from above without a
        // distance limit, so a hydrostatic stack never splits. Loose liquid
        // above anything else falls one cell per round. Excess is carried up
        // to the surface, or stays as overfill under a solid ceiling.
        std::int32_t dst = -1, carry = 0;
        bool chain = false;
        for (auto r = rows - 1; r >= 0; --r) {
            if (mass[r] < 0) {
                if (carry != 0) { mass[r + 1] += carry; carry = 0; }
                dst = -1;
                chain = false;
                continue;
            }
            mass[r] += carry;
            carry = 0;
            if (mass[r] == 0) { dst = r; chain = false; continue; }
            if (dst > r && !chain) dst = r + 1;
            while (dst > r && mass[r] > 0) {
                const auto room = maximum - mass[dst];
                if (room <= 0) { --dst; continue; }
                const auto moved = std::min(mass[r], room);
                mass[dst] += moved;
                mass[r] -= moved;
            }
            if (mass[r] > maximum) { carry = mass[r] - maximum; mass[r] = maximum; }
            chain = flags[r] != 0U;
            if (dst <= r || mass[dst] >= maximum) dst = mass[r] < maximum ? r : -1;
        }
        if (carry != 0) mass[0] += carry; // the group's top row: nothing solved above it

        // Heads, top-down. The head of a wet cell is the weight of the liquid
        // resting on its floor: its own mass, plus what the cell above carries
        // if this cell is full. A unit moved sideways at a row then changes
        // potential energy by exactly the head difference for any stack of
        // full, thin or falling cells, so retained flux cannot gain energy.
        std::int32_t carried = 0, index = 0;
        bool confined = false;
        if (above != nullptr) {
            const auto bottom = static_cast<std::size_t>(size - 1) * static_cast<std::size_t>(size) +
                                static_cast<std::size_t>(lx);
            const auto meta = above->wave->meta[bottom];
            if ((meta & WaveChunk::kFull) != 0U) {
                carried = above->wave->weight[bottom];
                index = P::kActiveRows;
            } else if ((meta & WaveChunk::kSolid) != 0U) {
                index = -1; // a solid ceiling
            }
        } else {
            index = -1; // nothing resident above: treated as a ceiling
        }
        bool ceiling = index < 0;
        if (ceiling) index = 0;
        for (std::int32_t r = 0; r < rows; ++r) {
            const auto value = mass[r];
            if (value < 0) { weight[r] = 0; flags[r] = WaveChunk::kSolid; carried = 0; index = 0; ceiling = true; continue; }
            if (value == 0) { weight[r] = 0; flags[r] = 0; carried = 0; index = 0; ceiling = false; continue; }
            if (index == 0) {
                confined = value > maximum || (value == maximum && ceiling);
                if (value > maximum) {
                    // Sealed overfill is stiff: scale by the rows that can respond.
                    std::int32_t responding = 1;
                    while (responding < P::kActiveRows && r + responding < rows && mass[r + responding] > 0) ++responding;
                    carried = (value - maximum) * (P::kStiffness / responding - 1);
                }
            }
            carried = value + (value >= maximum ? carried : 0);
            weight[r] = carried;
            flags[r] = static_cast<std::uint8_t>(
                WaveChunk::kWet | (value >= maximum ? WaveChunk::kFull : 0U) |
                (index >= P::kActiveRows ? 0U : confined ? WaveChunk::kGainConfined : WaveChunk::kGainNormal));
            // A thin cell starts a new stack below it.
            if (value < maximum) { index = 0; confined = false; ceiling = false; continue; }
            ++index;
            ceiling = false;
        }

        // Depth class of every stack: how many rows respond together. A shallow
        // layer may level a larger share of its head difference per round than
        // a deep one without overshooting.
        for (std::int32_t r = 0; r < rows;) {
            if ((flags[r] & WaveChunk::kWet) == 0U) { ++r; continue; }
            auto end = r;
            while (end + 1 < rows && (flags[end] & WaveChunk::kFull) != 0U && (flags[end + 1] & WaveChunk::kWet) != 0U) ++end;
            const auto length = std::min(end - r + 1, P::kActiveRows);
            std::uint8_t depth = 0;
            while ((1 << depth) < length) ++depth;
            // Overfill collects in the top cell of a sealed stack while inflow
            // arrives at any row, so a stack at the carrier ceiling is marked
            // whole and refuses further inflow.
            const bool saturated = mass[r] >= P::kMaximumMass;
            if (saturated) depth = WaveChunk::kSaturated;
            for (auto k = r; k <= end && (saturated || k < r + P::kActiveRows); ++k)
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
            const auto mark = masked_column || wet ? std::uint8_t{0} : any ? std::uint8_t{1} : std::uint8_t{2};
            if (mark != 0U && wave.dry[static_cast<std::size_t>(lx)] == 0U) {
                // Faces of a newly dry column are skipped from now on, so the
                // flux a just-emptied cell still carries must not survive.
                for (std::int32_t ly = 0; ly < size; ++ly)
                    wave.flux[static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) + static_cast<std::size_t>(lx)] = 0;
            }
            wave.dry[static_cast<std::size_t>(lx)] = mark;
            if (c < kMaximumGroup) {
                // A clean half stays untouched unless liquid settled into it.
                if (skip[c] && !any) continue;
                if (any) { empty[c] = false; wave.clean[task.half] = false; skip[c] = false; }
            }
            for (std::int32_t ly = 0; ly < size; ++ly) {
                const auto at = static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) + static_cast<std::size_t>(lx);
                const auto r = base + ly;
                wave.weight[at] = weight[r];
                wave.meta[at] = flags[r];
                if (mass[r] < 0) continue;
                auto& cell = chunk.cells[at];
                const auto before = cell.material_value() == Material::Water
                                        ? static_cast<std::int32_t>(cell.state_a_value()) : 0;
                if (before == mass[r]) continue;
                wave_write_mass(chunk, at, before, mass[r], half);
                if (mass[r] == 0) wave.flux[at] = 0; // no strip reads flux during this pass
                half.touch(lx, ly);
                half.peak = std::max(half.peak, std::abs(mass[r] - before));
            }
        }
    }
    // A half found entirely Empty becomes clean: zero its retained flux once.
    for (std::uint32_t c = 0; c < task.count && c < kMaximumGroup; ++c) {
        auto& wave = *entries[c].chunk->wave;
        if (!empty[c] || wave.clean[task.half]) continue;
        const auto base = static_cast<std::int32_t>(c) * size;
        if (base < mask_last && base + size > mask_first) continue;
        for (std::int32_t ly = 0; ly < size; ++ly)
            std::fill_n(wave.flux.data() + static_cast<std::size_t>(ly) * static_cast<std::size_t>(size) +
                            static_cast<std::size_t>(first_x), last_x - first_x, 0);
        wave.clean[task.half] = true;
    }
}

void World::wave_write_mass(Chunk& chunk, std::size_t at, std::int32_t before, std::int32_t after,
                            WaveHalf& half) noexcept {
    auto& cell = chunk.cells[at];
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
    chunk.wave->clean[column < static_cast<std::size_t>(config_.chunk_size / 2) ? 0U : 1U] = false;
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
            const auto row = static_cast<std::size_t>(ly) * stride;
            for (auto lx = start_x; lx < last_x; ++lx) {
                const auto i = row + static_cast<std::size_t>(lx);
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
                            record_transient_contact(body, Material::Water, wet_left ? 1 : -1, 0,
                                                     origin_x + lx + (wet_left ? 0 : 1), origin_y + ly);
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
                const auto head = wave.weight[i] - other->wave->weight[j];
                const auto previous = wave.flux[i];
                auto flux = static_cast<std::int64_t>(previous) - previous / (1 << P::kDampShift) +
                            static_cast<std::int64_t>(head) * (code == WaveChunk::kGainConfined ? P::kGainConfined : P::kGain);
                const bool rightward = flux > 0;
                auto available = rightward ? a : b;
                const auto destination_mass = rightward ? b : a;
                if (destination_mass == 0) {
                    // Keep a residual film on a dry floor.
                    const auto* target = rightward ? other : &chunk;
                    const auto at = rightward ? j : i;
                    bool floor = true;
                    if (ly + 1 < size) floor = (target->wave->meta[at + stride] & WaveChunk::kSolid) != 0U;
                    else if (const auto* under = target->wave->below; under != nullptr)
                        floor = (under->wave->meta[at - row] & WaveChunk::kSolid) != 0U;
                    if (floor) available -= film;
                    // Pouring into an empty cell is one-directional; a quarter of
                    // the cell per round cannot invert a pair of columns.
                    available >>= 2;
                } else {
                    // Inertia is bounded: a face may coast at most kCoast units
                    // against or beyond its head difference. Larger transfers are
                    // limited to a share of that difference, so bulk flow relaxes
                    // without overshoot while small flow keeps its momentum.
                    const auto depth = std::max(meta_a >> WaveChunk::kDepthShift, meta_b >> WaveChunk::kDepthShift);
                    const auto downhill = (head > 0) == rightward ? std::abs(head) >> (P::kLevelShift + depth) : 0;
                    available = std::min(available >> 1, std::max(P::kCoast, downhill));
                    if (((rightward ? meta_b : meta_a) >> WaveChunk::kDepthShift) == WaveChunk::kSaturated) available = 0;
                }
                const auto cap = available <= 0 ? std::int64_t{0} : static_cast<std::int64_t>(available) << P::kFluxShift;
                flux = rightward ? std::min(flux, cap) : std::max(flux, -cap);
                wave.flux[i] = static_cast<std::int32_t>(flux);
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
            const auto row = static_cast<std::size_t>(ly) * stride;
            const auto y = origin_y + ly;
            auto incoming = first_x > 0
                ? wave_transfer(wave.flux[row + static_cast<std::size_t>(first_x) - 1U], origin_x + first_x - 1, y, round)
                : left != nullptr ? wave_transfer(left->wave->flux[row + stride - 1U], origin_x - 1, y, round) : 0;
            const bool clean = wave.clean[task.half];
            for (auto lx = first_x; lx < last_x; ++lx) {
                // Interior faces of a clean half carry nothing.
                if (clean && lx == first_x + 1 && last_x - first_x > 2) { lx = last_x - 1; incoming = 0; }
                const auto i = row + static_cast<std::size_t>(lx);
                const auto outgoing = wave_transfer(wave.flux[i], origin_x + lx, y, round);
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
    using P = WaveFlowParameters;
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

    // A chunk is active while its Water moved recently or an owner edit, kernel
    // write or body mask touched it. Active chunks and their eight neighbours
    // are solved, so motion can always enter a neighbour in the same tick.
    state.grow.clear();
    for (const auto& [coord, chunk] : chunks_) {
        auto& wave = *chunk->wave;
        wave.active = wave.woken || wave.quiet < static_cast<std::uint32_t>(P::kSleepAfter);
        wave.solve = false;
        if (!wave.active || chunk->non_empty_cell_count == 0U) continue;
        // Liquid on an edge row or column needs a resident destination. Workers
        // never allocate, so the owner admits the neighbour here.
        const auto* cells = chunk->cells.data();
        bool edge[4] = {false, false, false, false}; // left, right, up, down
        for (std::int32_t k = 0; k < size; ++k) {
            const auto step = static_cast<std::size_t>(k);
            edge[0] = edge[0] || cells[step * stride].material_value() == Material::Water;
            edge[1] = edge[1] || cells[step * stride + stride - 1U].material_value() == Material::Water;
            edge[2] = edge[2] || cells[step].material_value() == Material::Water;
            edge[3] = edge[3] || cells[(stride - 1U) * stride + step].material_value() == Material::Water;
        }
        const ChunkCoord wanted[4] = {{coord.x - 1, coord.y}, {coord.x + 1, coord.y}, {coord.x, coord.y - 1}, {coord.x, coord.y + 1}};
        for (std::size_t k = 0; k < 4U; ++k)
            if (edge[k] && find_chunk(wanted[k]) == nullptr) state.grow.push_back(wanted[k]);
    }
    for (const auto coord : state.grow) {
        // Capacity is an explicit outcome: an unadmitted neighbour stays a wall.
        if (chunks_.size() >= config_.maximum_chunk_count) break;
        (void)ensure_chunk(coord);
    }

    state.sorted.clear();
    for (const auto& [coord, chunk] : chunks_) {
        auto& wave = *chunk->wave;
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
    state.mask_present = !transient_obstacles_->occupied_indices.empty();
    diagnostics.prepare_nanoseconds += elapsed(started);
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
        run(&World::wave_column_task, diagnostics.column_nanoseconds);
        run(&World::wave_flux_task, diagnostics.flux_nanoseconds);
        run(&World::wave_apply_task, diagnostics.apply_nanoseconds);
    }

    // Owner-side reduction: activity, render dirtiness and occupancy.
    started = Clock::now();
    std::uint64_t invalid = 0;
    std::int64_t population = 0;
    for (const auto& entry : state.sorted) {
        auto& chunk = *entry.chunk;
        auto& wave = *chunk.wave;
        std::int32_t peak = 0, delta = 0;
        std::uint32_t transitions = 0;
        WaveHalf bounds;
        for (const auto& half : wave.half) {
            peak = std::max(peak, half.peak);
            delta += half.non_empty_delta;
            diagnostics.moved_units += half.moved;
            invalid += half.invalid;
            transitions += half.transitions;
            if (half.max_x >= half.min_x) { bounds.touch(half.min_x, half.min_y); bounds.touch(half.max_x, half.max_y); }
        }
        wave.woken = false;
        if (peak >= P::kWakePeak) wave.quiet = 0;
        else if (wave.quiet < static_cast<std::uint32_t>(P::kSleepAfter)) ++wave.quiet;
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
        if (peak < P::kWakePeak && transitions == 0U) continue;
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
}
