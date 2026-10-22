// Scratch-only Water flow prototype, tier B: tick-start hydrostatic pressure
// snapshot (serial pre-pass over active scheduling cores), 8-bit lateral
// velocity and 8-bit transient overfill with same-tick upward relief.
// Included inside namespace cybersand in world.cpp.
namespace proto_tls {
inline std::uint64_t stat[8] = {};
constexpr std::int32_t kNone = -1;
constexpr std::int32_t kUnknown = -2;
constexpr std::int32_t kFree = -3;
constexpr std::int32_t kDeferred = -4;
}  // namespace proto_tls

void World::proto_select_core(std::size_t) const noexcept {}

std::int32_t World::proto_pressure(std::int64_t x, std::int64_t y) const noexcept {
    const auto lx = x - proto_ox_, ly = y - proto_oy_;
    if (lx < 0 || ly < 0 || lx >= proto_w_ || ly >= proto_rows_) return proto_tls::kNone;
    return proto_p_[static_cast<std::size_t>(ly * proto_w_ + lx)];
}

bool World::proto_enclosed_air(std::int64_t x, std::int64_t y) const noexcept {
    const auto lx = x - proto_ox_, ly = y - proto_oy_;
    if (lx < 0 || ly < 0 || lx >= proto_w_ || ly >= proto_rows_) return false;
    return proto_k_[static_cast<std::size_t>(ly * proto_w_ + lx)] == 3;
}

std::int32_t World::proto_air_offset(std::int64_t x, std::int64_t y) const noexcept {
    const auto lx = x - proto_ox_, ly = y - proto_oy_;
    if (lx < 0 || ly < 0 || lx >= proto_w_ || ly >= proto_rows_) return 0;
    const auto pocket = proto_pocket_[static_cast<std::size_t>(ly * proto_w_ + lx)];
    return pocket >= 0 ? proto_offset_[static_cast<std::size_t>(pocket)] : 0;
}

std::int32_t World::proto_gradient(std::int64_t x, std::int64_t y) const noexcept {
    const auto lx = x - proto_ox_, ly = y - proto_oy_;
    if (lx < 0 || ly < 0 || lx >= proto_w_ || ly >= proto_rows_) return INT32_MIN;
    return proto_g_[static_cast<std::size_t>(ly * proto_w_ + lx)];
}

std::int32_t World::proto_run(std::int64_t x, std::int64_t y) const noexcept {
    const auto lx = x - proto_ox_, ly = y - proto_oy_;
    if (lx < 0 || ly < 0 || lx >= proto_w_ || ly >= proto_rows_) return 1;
    return proto_h_[static_cast<std::size_t>(ly * proto_w_ + lx)];
}

// One serial, read-only pass over the tick-start cells of the active cores
// bounding box (plus the radius-2 halo). Every core of every phase reads the
// same snapshot, so heads are identical on both sides of a core seam and
// independent of worker count.
//
// Stored value per Water cell: the settled head at the cell's bottom, i.e.
// the free-surface elevation of its vertical run above that row, in mass
// units: max(0, run_total - (bottom - y) * maximum). It depends only on the
// run's total mass and floor, never on where holes or overfill in transit
// currently sit inside the run. Runs under a ceiling (solid or body) take
// their row's interpolated head from neighbouring open runs; unsupported
// runs are in free fall and carry no pressure.
void World::proto_prepass() {
    const auto& params = proto::params();
    proto_w_ = proto_rows_ = 0;
    if (active_core_scratch_.empty()) return;
    std::int64_t x0 = INT64_MAX, y0 = INT64_MAX, x1 = INT64_MIN, y1 = INT64_MIN;
    for (const auto core : active_core_scratch_) {
        const auto rect = scheduler_geometry_.core_rect(core);
        x0 = std::min(x0, rect.x); y0 = std::min(y0, rect.y);
        x1 = std::max(x1, rect.x + rect.width); y1 = std::max(y1, rect.y + rect.height);
    }
    // Full-height box: heads and trapped-air pockets need whole water
    // columns. A box cut to the active cores truncates columns once part of a
    // pool sleeps, giving the awake part false heads; the sleeping part then
    // discharges in a burst when woken. Extend the box vertically over the
    // occupied chunks in the active columns. (PROTO: O(resident chunks); a
    // production version would keep a per-column-band occupied extent.)
    if (params.box_full_height) {
        const auto cs = static_cast<std::int64_t>(config_.chunk_size);
        for (const auto& [coord, chunk] : chunks_) {
            if (chunk == nullptr || chunk->non_empty_cell_count == 0) continue;
            const auto cx0 = static_cast<std::int64_t>(coord.x) * cs, cy0 = static_cast<std::int64_t>(coord.y) * cs;
            if (cx0 + cs <= x0 || cx0 >= x1) continue;
            y0 = std::min(y0, cy0); y1 = std::max(y1, cy0 + cs);
        }
    }
    proto_ox_ = x0 - 2; proto_oy_ = y0 - 2;
    const auto stride = x1 - x0 + 4, rows = y1 - y0 + 4;
    // PROTO: grows to the high-water bounding box (a production version would
    // bound and preallocate this with the scheduler capacity).
    const auto cells = static_cast<std::size_t>(stride * rows);
    if (proto_p_.size() < cells) { proto_p_.resize(cells); proto_h_.resize(cells); proto_g_.resize(cells); }
    proto_w_ = stride; proto_rows_ = rows;
    const auto ox = proto_ox_, oy = proto_oy_;
    const auto maximum = static_cast<std::int64_t>(config_.water_experiment_policy.maximum());
    auto* P = proto_p_.data();
    auto* H = proto_h_.data();
    const auto kind = [this](std::int64_t x, std::int64_t y) {
        if (transient_obstacle_at(x, y) != 0U) return 2;
        const auto m = stored_material(x, y);
        return m == Material::Empty ? 0 : m == Material::Water ? 1 : 2;
    };
    const auto mass = [this](std::int64_t x, std::int64_t y) -> std::int64_t {
        const auto a = address(x, y);
        const auto* c = find_chunk(a.chunk);
        if (c == nullptr) return 0;
        const auto& cell = c->cells[a.index];
        return static_cast<std::int64_t>(cell.state_a_value()) + cell.over_value();
    };
    // Snapshot the box once through per-row chunk spans (one map lookup per
    // span instead of per cell).
    if (proto_k_.size() < cells) { proto_k_.resize(cells); proto_m_.resize(cells); }
    auto* K = proto_k_.data();
    auto* M = proto_m_.data();
    for (std::int64_t r = 0; r < rows; ++r) {
        const auto y = oy + r;
        for (std::int64_t c = 0; c < stride;) {
            const auto a = address(ox + c, y);
            const auto* chunk = find_chunk(a.chunk);
            const auto span = std::min<std::int64_t>(stride - c, config_.chunk_size - a.local_x);
            for (std::int64_t i = 0; i < span; ++i) {
                const auto idx = static_cast<std::size_t>(r * stride + c + i);
                if (transient_obstacle_at(ox + c + i, y) != 0U) { K[idx] = 2; M[idx] = 0; continue; }
                if (chunk == nullptr) { K[idx] = 0; M[idx] = 0; continue; }
                const auto& cell = chunk->cells[a.index + static_cast<std::size_t>(i)];
                const auto m = cell.material_value();
                K[idx] = m == Material::Empty ? 0 : m == Material::Water ? 1 : 2;
                M[idx] = m == Material::Water ? static_cast<std::int32_t>(cell.state_a_value()) + cell.over_value() : 0;
            }
            c += span;
        }
    }

    // Trapped air (no persistent air state, no flood fill): an Empty row
    // segment is "enclosed" when both its ends are non-Empty inside the box
    // and every column of it is capped by solid/body above (within cap rows).
    // Such air is treated as incompressible (instant sound speed): it acts as
    // a ceiling for pressure and refuses pressure-driven inflow, leaking only
    // slowly. Anything touching open sky, the box edge or a long open column
    // counts as vented. Misclassification errs toward venting.
    if (params.air) {
        if (proto_cover_.size() < cells) proto_cover_.resize(cells);
        auto* C = proto_cover_.data();
        for (std::int64_t c = 0; c < stride; ++c) {
            for (std::int64_t r = 0; r < rows;) {
                if (K[r * stride + c] != 0) { ++r; continue; }
                const auto top = r;
                while (r < rows && K[r * stride + c] == 0) ++r;
                bool covered;
                // Water above also covers (splash droplets inside a pocket must
                // not vent it); the pocket checks below reject open-sky gaps.
                if (top > 0) covered = K[(top - 1) * stride + c] != 0;
                else {
                    std::int64_t yy = oy - 1, steps = 0;
                    while (steps < params.cap && kind(ox + c, yy) == 0) { --yy; ++steps; }
                    covered = steps < params.cap && kind(ox + c, yy) != 0;
                }
                for (auto k = top; k < r; ++k) C[k * stride + c] = covered ? 1 : 0;
            }
        }
        for (std::int64_t r = 0; r < rows; ++r) {
            for (std::int64_t c = 0; c < stride;) {
                if (K[r * stride + c] != 0) { ++c; continue; }
                const auto c0 = c;
                bool enclosed = c0 > 0;
                while (c < stride && K[r * stride + c] == 0) {
                    // Vented air directly above vents this segment too (rows are
                    // final top-down), so trough air under open sky never counts.
                    const bool vented_above = r > 0 ? K[(r - 1) * stride + c] == 0 : kind(ox + c, oy - 1) != 2;
                    enclosed = enclosed && C[r * stride + c] && !vented_above;
                    ++c;
                }
                enclosed = enclosed && c < stride && (c - c0) <= params.air_span;
                if (enclosed) for (auto k = c0; k < c; ++k) K[r * stride + k] = 3;
            }
        }
    }
    // Pockets: enclosed segments joined vertically (union-find over segments,
    // linear in the box). Each pocket is one uniform-pressure air volume.
    if (proto_pocket_.size() < cells) {
        proto_pocket_.resize(cells); proto_runpocket_.resize(cells); proto_pc_.resize(cells);
    }
    auto* PK = proto_pocket_.data();
    auto* RP = proto_runpocket_.data();
    std::fill(PK, PK + cells, -1);
    std::fill(RP, RP + cells, -1);
    std::vector<std::int32_t> parent;
    const auto find = [&parent](std::int32_t a) {
        while (parent[static_cast<std::size_t>(a)] != a) {
            parent[static_cast<std::size_t>(a)] = parent[static_cast<std::size_t>(parent[static_cast<std::size_t>(a)])];
            a = parent[static_cast<std::size_t>(a)];
        }
        return a;
    };
    for (std::int64_t r = 0; r < rows; ++r)
        for (std::int64_t c = 0; c < stride; ++c) {
            const auto i = r * stride + c;
            if (K[i] != 3) continue;
            if (c > 0 && K[i - 1] == 3) PK[i] = PK[i - 1];
            else { PK[i] = static_cast<std::int32_t>(parent.size()); parent.push_back(PK[i]); }
            if (r > 0 && K[i - stride] == 3) {
                const auto a = find(PK[i]), b = find(PK[i - stride]);
                if (a != b) parent[static_cast<std::size_t>(std::max(a, b))] = std::min(a, b);
            }
        }
    for (std::size_t i = 0; i < cells; ++i) if (PK[i] >= 0) PK[i] = find(PK[i]);
    // A pocket is real only if it is sealed in every direction we can see:
    // no vented air above or below any of its cells (venting spreads up and
    // down, e.g. air under an arch whose legs stop above the water), it holds
    // at least one wall-to-wall air segment (an overhang sliver bounded by a
    // wave crest is not a pocket) and it is not a tiny gap.
    {
        std::vector<std::uint8_t> vented(parent.size(), 0), walled(parent.size(), 0);
        std::vector<std::int32_t> size(parent.size(), 0);
        for (std::int64_t r = 0; r < rows; ++r)
            for (std::int64_t c = 0; c < stride; ++c) {
                const auto i = r * stride + c;
                if (K[i] != 3) continue;
                const auto q = static_cast<std::size_t>(PK[i]);
                ++size[q];
                if (r + 1 >= rows || K[i + stride] == 0 || (r > 0 && K[i - stride] == 0)) vented[q] = 1;
                if ((c == 0 || K[i - 1] != 3) && c > 0) {
                    auto e = c;
                    while (e < stride && K[r * stride + e] == 3) ++e;
                    if (e < stride && K[i - 1] == 2 && K[r * stride + e] == 2) walled[q] = 1;
                }
            }
        for (std::size_t i = 0; i < cells; ++i) {
            if (PK[i] < 0) continue;
            const auto q = static_cast<std::size_t>(PK[i]);
            if (vented[q] || !walled[q] || size[q] < params.air_min) { K[i] = 0; PK[i] = -1; }
        }
        static const long long flag_tick = std::getenv("WPOCKT") ? std::atoll(std::getenv("WPOCKT")) : -100;
        if (static_cast<long long>(tick_index_) >= flag_tick && static_cast<long long>(tick_index_) < flag_tick + 12)
            for (std::size_t q = 0; q < parent.size(); ++q)
                if (size[q] >= 16) std::fprintf(stderr, "t%llu root=%zu size=%d vented=%d walled=%d\n",
                    (unsigned long long)tick_index_, q, size[q], vented[q], walled[q]);
        static const bool pocket_debug = std::getenv("WPOCKDBG") != nullptr;
        if (pocket_debug && tick_index_ % 300 == 0) {
            for (std::size_t q = 0; q < parent.size(); ++q) {
                if (size[q] == 0 || parent[q] != static_cast<std::int32_t>(q) || vented[q] || !walled[q] || size[q] < params.air_min) continue;
                std::int64_t x0 = INT64_MAX, x1 = INT64_MIN, y0 = INT64_MAX, y1 = INT64_MIN;
                for (std::int64_t r = 0; r < rows; ++r) for (std::int64_t c = 0; c < stride; ++c)
                    if (PK[r * stride + c] == static_cast<std::int32_t>(q)) {
                        x0 = std::min(x0, ox + c); x1 = std::max(x1, ox + c); y0 = std::min(y0, oy + r); y1 = std::max(y1, oy + r); }
                std::fprintf(stderr, "t%llu pocket size=%d x=%lld..%lld y=%lld..%lld\n", (unsigned long long)tick_index_, size[q],
                             (long long)x0, (long long)x1, (long long)y0, (long long)y1);
            }
        }
    }
    const auto kind_at = [&](std::int64_t c, std::int64_t r) { const int k = K[r * stride + c]; return k == 3 ? 0 : k; };
    const auto mass_at = [&](std::int64_t c, std::int64_t r) { return static_cast<std::int64_t>(M[r * stride + c]); };
    // Column pass: vertical runs, extended (capped) beyond the box.
    for (std::int64_t c = 0; c < stride; ++c) {
        const auto x = ox + c;
        for (std::int64_t r = 0; r < rows;) {
            if (kind_at(c, r) != 1) { P[r * stride + c] = proto_tls::kNone; H[r * stride + c] = 0; ++r; continue; }
            const auto top = r;
            std::int64_t total = 0;
            while (r < rows && kind_at(c, r) == 1) { total += mass_at(c, r); ++r; }
            const auto bottom = r - 1;
            std::int64_t up = 0, down = 0;
            std::int64_t yy = oy + top - 1;
            if (top == 0) while (up < params.cap && kind(x, yy) == 1) { total += mass(x, yy); --yy; ++up; }
            const auto above_kind = up >= params.cap ? 0
                : top > 0 ? (K[(top - 1) * stride + c] == 3 ? 0 : static_cast<int>(K[(top - 1) * stride + c]))
                          : kind(x, yy);
            const auto run_pocket = top > 0 && K[(top - 1) * stride + c] == 3 ? PK[(top - 1) * stride + c] : -1;
            yy = oy + bottom + 1;
            if (bottom == rows - 1) while (down < params.cap && kind(x, yy) == 1) { total += mass(x, yy); ++yy; ++down; }
            const bool supported = down >= params.cap || kind(x, yy) != 0;
            const auto length = (bottom - top + 1) + up + down;
            const auto floor_y = bottom + down;  // in box rows
            for (auto k = top; k <= bottom; ++k) {
                H[k * stride + c] = static_cast<std::uint16_t>(std::min<std::int64_t>(length, 65535));
                std::int32_t value;
                if (params.freefall && !supported) value = proto_tls::kFree;
                else if (above_kind == 2) value = proto_tls::kUnknown;
                else value = static_cast<std::int32_t>(std::max<std::int64_t>(0, total - (floor_y - k) * maximum));
                P[k * stride + c] = value;
                if (value >= 0) RP[k * stride + c] = run_pocket;
            }
        }
    }
    // Ceiling resolution runs on a copy in which runs under trapped air are
    // also unknown: that gives the head the surrounding connected water would
    // impose on them ("as if capped"). The pocket's uniform pressure offset is
    // the mean difference between that and the run tops' own free-surface
    // heads, so waves under the air keep their slopes while the pocket as a
    // whole resists net inflow (no air state, recomputed every tick).
    auto* Pc = proto_pc_.data();
    // Taint marks heads that came only from the no-information fallback; a
    // pocket whose capped runs are all tainted has no connection to open
    // water, so its air is simply the local atmosphere (offset 0).
    if (proto_cover_.size() < cells) proto_cover_.resize(cells);
    auto* T = proto_cover_.data();
    std::fill(T, T + cells, std::uint8_t{0});
    const auto resolve = [&](std::int32_t* B) {
        // Row pass: ceiling runs take the interpolated head of their row's
        // connected open water; with none in reach, the settled column below
        // the resolved cell above (+maximum per row).
        for (std::int64_t r = 0; r < rows; ++r) {
            auto* row = B + r * stride;
            for (std::int64_t c = 0; c < stride;) {
                if (row[c] == proto_tls::kNone) { ++c; continue; }
                const auto c0 = c;
                while (c < stride && row[c] != proto_tls::kNone) ++c;
                const auto c1 = c;
                std::int64_t left = -1;
                for (auto i = c0; i < c1; ++i) {
                    if (row[i] >= 0) { left = i; continue; }
                    if (row[i] != proto_tls::kUnknown) continue;
                    std::int64_t right = -1;
                    for (auto j = i + 1; j < c1; ++j) if (row[j] >= 0) { right = j; break; }
                    for (auto k = i; k < (right >= 0 ? right : c1); ++k) {
                        if (row[k] != proto_tls::kUnknown) continue;
                        if (left >= 0 && right >= 0)
                            row[k] = row[left] + static_cast<std::int32_t>(
                                static_cast<std::int64_t>(row[right] - row[left]) * (k - left) / (right - left));
                        else if (left >= 0 || right >= 0) row[k] = row[left >= 0 ? left : right];
                        else row[k] = proto_tls::kDeferred;
                    }
                    if (right >= 0) { left = right; i = right; } else i = c1;
                }
            }
        }
        // Ceiling runs with no open water in their row (e.g. under trapped air in
        // a bell): continue the hydrostatic column upward from the resolved cell
        // below, so the pocket holds the pressure of the water it sits on.
        for (std::int64_t r = rows - 1; r >= 0; --r) {
            auto* row = B + r * stride;
            for (std::int64_t c = 0; c < stride; ++c) {
                if (row[c] != proto_tls::kDeferred && row[c] != proto_tls::kUnknown) continue;
                if (r + 1 < rows && row[c + stride] >= 0) {
                    T[r * stride + c] = T[(r + 1) * stride + c];
                    // Full cells below lower the head by one cell each; a cell's own
                    // held excess (compressed water) raises its pressure.
                    row[c] = static_cast<std::int32_t>(std::max<std::int64_t>(
                        0, row[c + stride] - std::min<std::int64_t>(M[(r + 1) * stride + c], maximum) +
                               std::max<std::int64_t>(0, M[r * stride + c] - maximum)));
                } else {
                    row[c] = static_cast<std::int32_t>(maximum);
                    T[r * stride + c] = 1;
                }
            }
        }
    };
    // 1) Real lids (solid, body) resolve against their neighbours' actual
    //    heads, including the free-surface heads of water under trapped air.
    // 2) "As if capped": an independent resolution from the unresolved heads
    //    with trapped-air runs unknown too, used only to price each pocket.
    // In a fully sealed system (e.g. a closed box whose whole sky is trapped
    // air) no pocket has an open-water reference. Then the largest unpriced
    // pocket becomes the zero-pressure reference (gauge) and the others are
    // priced against it; repeat for independent sealed systems (bounded).
    std::vector<std::uint8_t> reference(parent.size(), 0);
    std::vector<std::int64_t> sum(parent.size(), 0), count(parent.size(), 0), tops(parent.size(), 0);
    for (int pass = 0; pass < params.air_reference_passes; ++pass) {
        for (std::size_t i = 0; i < cells; ++i)
            Pc[i] = RP[i] >= 0 && !reference[static_cast<std::size_t>(RP[i])] ? proto_tls::kUnknown : P[i];
        std::fill(T, T + cells, std::uint8_t{0});
        resolve(Pc);
        std::fill(sum.begin(), sum.end(), 0);
        std::fill(count.begin(), count.end(), 0);
        std::fill(tops.begin(), tops.end(), 0);
        for (std::int64_t r = 1; r < rows; ++r)
            for (std::int64_t c = 0; c < stride; ++c) {
                const auto i = r * stride + c;
                if (RP[i] < 0 || K[i - stride] != 3) continue;
                const auto q = static_cast<std::size_t>(RP[i]);
                ++tops[q];
                if (T[i] || reference[q]) continue;
                sum[q] += static_cast<std::int64_t>(Pc[i]) - P[i];
                ++count[q];
            }
        std::int64_t best = -1, best_tops = 0;
        for (std::size_t q = 0; q < parent.size(); ++q)
            if (!reference[q] && tops[q] > 0 && count[q] == 0 && tops[q] > best_tops) { best = static_cast<std::int64_t>(q); best_tops = tops[q]; }
        if (best < 0) break;
        reference[static_cast<std::size_t>(best)] = 1;
    }
    {
        static const bool ref_debug = std::getenv("WREFDBG") != nullptr;
        if (ref_debug && tick_index_ % 100 == 0)
            for (std::size_t q = 0; q < parent.size(); ++q)
                if (tops[q] > 20) std::fprintf(stderr, "t%llu pocket %zu tops=%lld priced=%lld ref=%d offset=%lld\n",
                    (unsigned long long)tick_index_, q, (long long)tops[q], (long long)count[q], reference[q],
                    (long long)(count[q] ? sum[q] / count[q] : 0));
        proto_offset_.assign(parent.size(), 0);
        for (std::size_t q = 0; q < parent.size(); ++q)
            if (!reference[q] && count[q] > 0) proto_offset_[q] = static_cast<std::int32_t>(std::max<std::int64_t>(0, sum[q] / count[q]));
        // Air state (Boyle): every Empty cell of a pocket stores the pocket's
        // air amount A (equivalent atmospheric volume, cells) in its spare
        // bits. Gauge pressure = P_atm * (A - V) / V for the current volume V,
        // so water that intrudes compresses the air and is pushed back. A new
        // pocket (no stored air) seals at atmospheric pressure (A = V). Merged
        // pockets sum their distinct stored amounts; a split shares an amount
        // by volume. Pockets too large to store vent (act as atmosphere).
        if (params.air_state) {
            const std::vector<std::int32_t> priced = proto_offset_;  // balance price (v4)
            std::vector<std::int64_t> volume(parent.size(), 0);
            // Each pocket takes the amount held by most of its cells (stale or
            // fresh cells cannot create air; a merge keeps the larger pocket's
            // air). An amount claimed by several pockets is a split and is
            // shared by volume, so splitting never duplicates air.
            std::vector<std::pair<std::int32_t, std::uint32_t>> votes;  // (pocket, amount)
            const auto cell_ref = [this](std::int64_t cx, std::int64_t cy) -> Chunk::Cell* {
                const auto a2 = address(cx, cy);
                auto* ch = find_chunk(a2.chunk);
                return ch ? &ch->cells[a2.index] : nullptr;
            };
            for (std::int64_t r = 0; r < rows; ++r)
                for (std::int64_t c = 0; c < stride; ++c) {
                    const auto i = r * stride + c;
                    if (K[i] != 3) continue;
                    ++volume[static_cast<std::size_t>(PK[i])];
                    const auto* cell = cell_ref(ox + c, oy + r);
                    votes.push_back({PK[i], cell ? static_cast<std::uint32_t>((cell->bits >> 40) & 0xFFFFU) : 0U});
                }
            std::sort(votes.begin(), votes.end());
            std::vector<std::uint32_t> chosen(parent.size(), 0);
            std::vector<std::int64_t> chosen_votes(parent.size(), -1);
            // Smooth volume (x255): pocket cells plus the unfilled part of each
            // surface cell beneath them, so a thin film flicking between Empty
            // and Water does not jolt the pocket pressure.
            std::vector<std::int64_t> volume255(parent.size(), 0);
            for (std::int64_t r = 0; r < rows; ++r)
                for (std::int64_t c = 0; c < stride; ++c) {
                    const auto i = r * stride + c;
                    if (K[i] != 3) continue;
                    const auto q = static_cast<std::size_t>(PK[i]);
                    volume255[q] += static_cast<std::int64_t>(maximum);
                    if (r + 1 < rows && K[i + stride] == 1)
                        volume255[q] += std::max<std::int64_t>(0, static_cast<std::int64_t>(maximum) - std::min<std::int64_t>(M[i + stride], maximum));
                }
            for (std::size_t k = 0; k < votes.size();) {
                auto e = k;
                while (e < votes.size() && votes[e] == votes[k]) ++e;
                const auto q = static_cast<std::size_t>(votes[k].first);
                const auto n = static_cast<std::int64_t>(e - k);
                if (n > chosen_votes[q] || (n == chosen_votes[q] && votes[k].second > chosen[q])) {
                    chosen_votes[q] = n;
                    chosen[q] = votes[k].second;
                }
                k = e;
            }
            std::vector<std::int64_t> claim_volume(65536, 0);
            for (std::size_t q = 0; q < parent.size(); ++q)
                if (volume[q] > 0 && chosen[q] != 0) claim_volume[chosen[q]] += volume[q];
            std::vector<std::int64_t> air(parent.size(), 0);
            std::vector<std::uint8_t> has_air(parent.size(), 0);
            for (std::size_t q = 0; q < parent.size(); ++q)
                if (volume[q] > 0 && chosen[q] != 0) {
                    air[q] = static_cast<std::int64_t>(chosen[q]) * volume[q] / std::max<std::int64_t>(claim_volume[chosen[q]], 1);
                    has_air[q] = 1;
                }
            const auto p_atm = static_cast<std::int64_t>(params.air_atm_rows) * static_cast<std::int64_t>(maximum);
            for (std::size_t q = 0; q < parent.size(); ++q) {
                if (volume[q] == 0) continue;
                if (!has_air[q] || air[q] <= 0) air[q] = volume[q];
                // Very large enclosures (a sealed sky, big halls) act as the
                // local atmosphere: no stored air, no pressure.
                if (air[q] > params.air_max_cells || volume[q] > params.air_max_cells) { proto_offset_[q] = 0; air[q] = 0; continue; }
                const auto v255 = std::max<std::int64_t>(volume255[q], 1);
                const auto gauge = p_atm * (air[q] * static_cast<std::int64_t>(maximum) - v255) / v255;
                const auto quantum = std::max(1, params.air_quantum);
                proto_offset_[q] = static_cast<std::int32_t>(std::clamp<std::int64_t>(gauge / quantum * quantum, 0, p_atm));
            }
            // Air damping: a pocket whose volume is shrinking pushes back
            // harder (and one expanding, softer) in proportion to the gauge
            // change since last tick, so the air spring does not ring forever.
            // Last tick's smooth volume is kept per pocket, keyed by its air.
            {
                std::vector<std::pair<std::uint32_t, std::int32_t>> next;
                const auto quantum = std::max(1, params.air_quantum);
                for (std::size_t q = 0; q < parent.size(); ++q) {
                    if (volume[q] == 0 || air[q] <= 0 || !has_air[q]) continue;
                    const auto key = static_cast<std::uint32_t>(air[q]);
                    const auto v255 = std::max<std::int64_t>(volume255[q], 1);
                    const auto it = std::lower_bound(proto_air_last_.begin(), proto_air_last_.end(), std::make_pair(key, INT32_MIN));
                    if (params.air_damping > 0 && it != proto_air_last_.end() && it->first == key) {
                        const auto a255 = air[q] * static_cast<std::int64_t>(maximum);
                        const auto prev = std::max<std::int64_t>(it->second, 1);
                        const auto delta = p_atm * a255 / v255 - p_atm * a255 / prev;
                        const auto damped = static_cast<std::int64_t>(proto_offset_[q]) + delta * params.air_damping / 16;
                        proto_offset_[q] = static_cast<std::int32_t>(std::clamp<std::int64_t>(damped / quantum * quantum, 0, p_atm));
                    }
                    next.push_back({key, static_cast<std::int32_t>(std::min<std::int64_t>(v255, INT32_MAX))});
                }
                std::sort(next.begin(), next.end());
                proto_air_last_ = std::move(next);
            }
            // Equilibrium band: when the air's own (Boyle) pressure is within
            // the band of the pressure that exactly balances the surrounding
            // water, use the balancing pressure, so a pocket near equilibrium
            // leaves no residual push for sub-threshold flow to creep on.
            if (params.air_band > 0)
                for (std::size_t q = 0; q < parent.size(); ++q)
                    if (volume[q] > 0 && has_air[q] && air[q] > 0 && !reference[q] && count[q] > 0 &&
                        std::abs(proto_offset_[q] - priced[q]) <= params.air_band)
                        proto_offset_[q] = priced[q];
            // Wake on pressure change: when a pocket's pressure changes, every
            // water block in the box is woken, so no region falls asleep with a
            // stale view of the pocket and later discharges all at once.
            if (params.air_wake) {
                std::vector<std::pair<std::uint32_t, std::int32_t>> next;
                bool changed = false;
                for (std::size_t q = 0; q < parent.size(); ++q) {
                    if (volume[q] == 0 || air[q] <= 0) continue;
                    const auto key = static_cast<std::uint32_t>(air[q]);
                    const auto it = std::lower_bound(proto_air_offset_last_.begin(), proto_air_offset_last_.end(), std::make_pair(key, INT32_MIN));
                    if (it == proto_air_offset_last_.end() || it->first != key || it->second != proto_offset_[q]) changed = true;
                    next.push_back({key, proto_offset_[q]});
                }
                std::sort(next.begin(), next.end());
                proto_air_offset_last_ = std::move(next);
                if (changed) {
                    const auto bs = static_cast<std::int64_t>(config_.activity_block_size);
                    std::int64_t last_bx = INT64_MIN, last_by = INT64_MIN;
                    for (std::int64_t r = 2; r + 2 < rows; ++r)
                        for (std::int64_t c = 2; c + 2 < stride; ++c) {
                            if (K[r * stride + c] != 1) continue;
                            const auto wx = ox + c, wy = oy + r;
                            const auto bx = (wx >= 0 ? wx : wx - bs + 1) / bs, by = (wy >= 0 ? wy : wy - bs + 1) / bs;
                            if (bx == last_bx && by == last_by) { c = (bx + 1) * bs - ox - 1; continue; }
                            last_bx = bx; last_by = by;
                            const auto a2 = address(wx, wy);
                            if (auto* ch = find_chunk(a2.chunk)) mark_cell_dirty(*ch, a2.local_x, a2.local_y);
                            c = (bx + 1) * bs - ox - 1;  // skip to the next block in this row
                        }
                }
            }
            static const int air_trace = std::getenv("WAIRTRACE") ? std::atoi(std::getenv("WAIRTRACE")) : -1;
            if (air_trace >= 0 && static_cast<int>(tick_index_) >= air_trace)
                for (std::size_t q = 0; q < parent.size(); ++q)
                    if (volume[q] > 200) std::fprintf(stderr, "T%llu q%zu vol=%lld v255=%lld air=%lld off=%d\n",
                        (unsigned long long)tick_index_, q, (long long)volume[q], (long long)volume255[q], (long long)air[q], proto_offset_[q]);
            for (std::int64_t r = 0; r < rows; ++r)
                for (std::int64_t c = 0; c < stride; ++c) {
                    const auto i = r * stride + c;
                    if (K[i] != 3) continue;
                    auto* cell = cell_ref(ox + c, oy + r);
                    if (cell == nullptr) continue;
                    const auto amount = static_cast<std::uint64_t>(air[static_cast<std::size_t>(PK[i])]);
                    cell->bits = (cell->bits & ~Chunk::Cell::spare_mask) | (amount << 40);
                }
        }
        // Mean free-surface head of each pocket's capped tops (relief gate).
        std::vector<std::int64_t> top_sum(parent.size(), 0), top_count(parent.size(), 0);
        for (std::int64_t r = 1; r < rows; ++r)
            for (std::int64_t c = 0; c < stride; ++c) {
                const auto i = r * stride + c;
                if (RP[i] < 0 || K[i - stride] != 3 || P[i] < 0) continue;
                top_sum[static_cast<std::size_t>(RP[i])] += P[i];
                ++top_count[static_cast<std::size_t>(RP[i])];
            }
        proto_pocket_mean_.assign(parent.size(), INT32_MAX);
        for (std::size_t q = 0; q < parent.size(); ++q)
            if (top_count[q] > 0) proto_pocket_mean_[q] = static_cast<std::int32_t>(top_sum[q] / top_count[q]);
        for (std::size_t i = 0; i < cells; ++i)
            if (RP[i] >= 0 && P[i] >= 0) P[i] += proto_offset_[static_cast<std::size_t>(RP[i])];
        // 3) Real lids resolve last, against offset-corrected neighbours.
        resolve(P);
        static const bool air_debug = std::getenv("WAIRDBG") != nullptr;
        if (air_debug && tick_index_ % 200 == 0) {
            std::int64_t pockets = 0, max_off = 0, capped = 0, cells_air = 0;
            for (std::size_t q = 0; q < parent.size(); ++q) if (parent[q] == static_cast<std::int32_t>(q)) {
                ++pockets; max_off = std::max<std::int64_t>(max_off, proto_offset_[q]); capped += count[q]; }
            for (std::size_t i = 0; i < cells; ++i) cells_air += K[i] == 3;
            std::fprintf(stderr, "t%llu pockets=%lld air_cells=%lld capped_tops=%lld max_offset=%lld box=%lldx%lld\n",
                (unsigned long long)tick_index_, (long long)pockets, (long long)cells_air, (long long)capped, (long long)max_off,
                (long long)stride, (long long)rows);
        }
    }
    // Snapshot gradient: radius-2 smoothed head difference per Water cell, so
    // the kernel (and its inert fast path) reads one value instead of four.
    constexpr std::int32_t kSolid = INT32_MIN;
    std::vector<std::int32_t> heads(static_cast<std::size_t>(stride));
    auto* G = proto_g_.data();
    for (std::int64_t r = 0; r < rows; ++r) {
        const auto y = oy + r;
        const auto* row = P + r * stride;
        for (std::int64_t c = 0; c < stride; ++c) {
            const auto v = row[c];
            if (v >= 0) heads[static_cast<std::size_t>(c)] = v;
            else if (v == proto_tls::kFree) heads[static_cast<std::size_t>(c)] = static_cast<std::int32_t>(mass_at(c, r));
            else heads[static_cast<std::size_t>(c)] = K[r * stride + c] == 3
                ? proto_offset_[static_cast<std::size_t>(PK[r * stride + c])] : kind_at(c, r) == 0 ? 0 : kSolid;
        }
        for (std::int64_t c = 0; c < stride; ++c) {
            auto* g = G + r * stride + c;
            if (row[c] < 0 || c < 2 || c >= stride - 2) { *g = INT32_MIN; continue; }
            const auto own = row[c];
            const auto h = [&](std::int64_t k) {
                const auto v = heads[static_cast<std::size_t>(k)];
                return v == kSolid ? own : v;
            };
            *g = params.wide ? (h(c - 2) + h(c - 1) - h(c + 1) - h(c + 2)) / 2 : h(c - 1) - h(c + 1);
        }
    }

}

std::uint32_t World::proto_move(std::int64_t from_x, std::int64_t from_y, std::int64_t to_x,
                                std::int64_t to_y, std::uint32_t requested, bool allow_over,
                                bool destination_epoch, JobEffects* effects) {
    if (requested == 0 || transient_obstacle_at(to_x, to_y) != 0U) return 0;
    const auto source_address = address(from_x, from_y);
    const auto destination_address = address(to_x, to_y);
    auto* source = find_chunk(source_address.chunk);
    if (source == nullptr || source->cells[source_address.index].material_value() != Material::Water) return 0;
    auto* destination = find_chunk(destination_address.chunk);
    if (destination == nullptr) {
        if (effects != nullptr) { effects->overflow = true; return 0; }
        destination = &ensure_chunk(destination_address.chunk);
    }
    auto& sc = source->cells[source_address.index];
    auto& dc = destination->cells[destination_address.index];
    const auto dm = dc.material_value();
    if (dm != Material::Empty && dm != Material::Water) return 0;
    const auto maximum = static_cast<std::uint32_t>(config_.water_experiment_policy.maximum());
    const std::uint32_t s_m = sc.state_a_value(), s_o = sc.over_value();
    const std::uint32_t d_m = dm == Material::Water ? dc.state_a_value() : 0;
    const std::uint32_t d_o = dm == Material::Water ? dc.over_value() : 0;
    const auto capacity = (maximum - d_m) + (allow_over ? 255U - d_o : 0U);
    const auto amount = std::min({requested, s_m + s_o, capacity});
    if (amount == 0) return 0;
    record_physics(PhysicsEvent::WaterTransfer, Material::Water, dm, to_x - from_x, to_y - from_y, effects,
                   static_cast<std::uint16_t>(std::min<std::uint32_t>(amount, 65535)));
    const auto take_o = std::min(s_o, amount);
    const auto take_m = amount - take_o;
    const bool destination_was_empty = dm == Material::Empty;
    const auto source_flow = static_cast<std::int32_t>(sc.flow_value());
    const auto source_coherence = sc.state_b_value();
    if (destination_was_empty) {
        dc = Chunk::Cell::for_material(Material::Water);
        dc.set_flow(0);
    }
    {
        const auto d_total = static_cast<std::int32_t>(d_m + d_o);
        const auto blended = proto::blend(dc.flow_value(), d_total, source_flow, static_cast<std::int32_t>(amount));
        dc.set_flow(static_cast<std::int8_t>(blended));
    }
    const auto into_m = std::min(amount, maximum - d_m);
    dc.set_state_a(static_cast<std::uint16_t>(d_m + into_m));
    dc.set_over(static_cast<std::uint8_t>(d_o + amount - into_m));
    dc.set_state_b(std::max(dc.state_b_value(), source_coherence));
    if (destination_epoch) dc.set_epoch(update_epoch_);
    const bool source_becomes_empty = s_m - take_m == 0 && s_o - take_o == 0;
    if (source_becomes_empty) {
        sc = Chunk::Cell::for_material(Material::Empty);
    } else {
        sc.set_over(static_cast<std::uint8_t>(s_o - take_o));
        sc.set_state_a(static_cast<std::uint16_t>(s_m - take_m));
    }
    sc.set_epoch(update_epoch_);
    const auto source_delta = source_becomes_empty ? std::int64_t{-1} : std::int64_t{0};
    const auto destination_delta = destination_was_empty ? std::int64_t{1} : std::int64_t{0};
    if (effects != nullptr) {
        effects->record(source_address, source_delta);
        effects->record(destination_address, destination_delta);
        if (settled_discovery_ != nullptr) {
            effects->record_discovery_mutation(source_address, config_.activity_block_size);
            effects->record_discovery_mutation(destination_address, config_.activity_block_size);
        }
    } else {
        source->non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(source->non_empty_cell_count) + source_delta);
        destination->non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(destination->non_empty_cell_count) + destination_delta);
        source->changed_this_tick = true;
        destination->changed_this_tick = true;
        mark_cell_dirty(*source, source_address.local_x, source_address.local_y);
        mark_cell_dirty(*destination, destination_address.local_x, destination_address.local_y);
        wake_cell_neighborhood(from_x, from_y);
        wake_cell_neighborhood(to_x, to_y);
    }
    if (to_y == from_y)
        mix_after_motion(Material::Water, from_x, from_y, to_x, to_y,
                         static_cast<std::uint16_t>(std::min<std::uint32_t>(amount, maximum)), effects);
    return amount;
}

bool World::update_water_proto(std::int64_t x, std::int64_t y, JobEffects* effects) {
    const auto& params = proto::params();
    record_physics(PhysicsEvent::WaterUpdate, Material::Water, Material::Empty, 0, 0, effects);
    const auto maximum = config_.water_experiment_policy.maximum();
    const auto tolerance = config_.water_experiment_policy.tolerance();
    const auto cell_at = [this](std::int64_t cx, std::int64_t cy) -> Chunk::Cell* {
        const auto a = address(cx, cy);
        auto* c = find_chunk(a.chunk);
        return c ? &c->cells[a.index] : nullptr;
    };
    auto* self = cell_at(x, y);
    if (self == nullptr) return false;
    // Same-chunk neighbour access without map lookups (falls back to the
    // generic lookup only at chunk edges); obstacle checks only when a body
    // mask is configured at all.
    const auto self_address = address(x, y);
    auto* const self_chunk = find_chunk(self_address.chunk);
    const auto chunk_cells = config_.chunk_size;
    const bool any_mask = transient_obstacles_->region.width > 0;
    const auto near_cell = [&](std::int64_t tx, std::int64_t ty) -> Chunk::Cell* {
        const auto lx = self_address.local_x + (tx - x), ly = self_address.local_y + (ty - y);
        if (lx >= 0 && ly >= 0 && lx < chunk_cells && ly < chunk_cells)
            return &self_chunk->cells[static_cast<std::size_t>(ly) * static_cast<std::size_t>(chunk_cells) +
                                      static_cast<std::size_t>(lx)];
        return cell_at(tx, ty);
    };
    const auto fast_stored = [&](std::int64_t tx, std::int64_t ty) {
        const auto* c = near_cell(tx, ty);
        return c ? c->material_value() : Material::Empty;
    };
    const auto fast_get = [&](std::int64_t tx, std::int64_t ty) {
        if (any_mask && transient_obstacle_at(tx, ty) != 0U) return Material::Wall;
        return fast_stored(tx, ty);
    };
    const auto fast_state_a = [&](std::int64_t tx, std::int64_t ty) -> std::uint16_t {
        const auto* c = near_cell(tx, ty);
        return c ? c->state_a_value() : std::uint16_t{0};
    };
    const auto fast_mass = [&](std::int64_t tx, std::int64_t ty) -> std::uint16_t {
        if (any_mask && transient_obstacle_at(tx, ty) != 0U) return 0;
        const auto* c = near_cell(tx, ty);
        return c && c->material_value() == Material::Water ? c->state_a_value() : std::uint16_t{0};
    };
    const auto normalize = [maximum](Chunk::Cell& c) {
        if (c.material_value() != Material::Water || c.over_value() == 0 || c.state_a_value() >= maximum) return;
        const auto move = std::min<std::uint32_t>(c.over_value(), maximum - c.state_a_value());
        c.set_state_a(static_cast<std::uint16_t>(c.state_a_value() + move));
        c.set_over(static_cast<std::uint8_t>(c.over_value() - move));
    };
    normalize(*self);
    std::int32_t flow = self->flow_value();
    bool changed = false;
    bool keep = false;
    const auto raw_head = proto_pressure(x, y);
    const bool free_fall = raw_head == proto_tls::kFree;
    // Heads come from the tick-start snapshot; a cell without one (created
    // this tick, or in free fall) uses its own mass.
    const auto head_of = [&](std::int64_t tx, std::int64_t ty, std::int32_t own) -> std::int32_t {
        if (any_mask && transient_obstacle_at(tx, ty) != 0U) return own;
        const auto* c = near_cell(tx, ty);
        if (c == nullptr) return own;
        const auto& cell = *c;
        const auto m = cell.material_value();
        if (m == Material::Empty) return proto_air_offset(tx, ty);
        if (m != Material::Water) return own;
        const auto h = proto_pressure(tx, ty);
        return h >= 0 ? h : static_cast<std::int32_t>(cell.state_a_value()) + cell.over_value();
    };
    const auto coherence_delay = state_b(x, y);
    static const bool debug = std::getenv("WDEBUG") != nullptr;
    if (debug && y == 240 && x >= 176 && x <= 202 && tick_index_ < 4)
        std::fprintf(stderr, "t%llu x%lld P=%d H=%d m=%u o=%u f=%d hL=%d hR=%d\n", (unsigned long long)tick_index_, (long long)x,
                     raw_head, proto_run(x, y), self->state_a_value(), self->over_value(), flow,
                     head_of(x - 1, y, 0), head_of(x + 1, y, 0));
    if (coherence_delay == 0U && flow == 0 && self->over_value() == 0 && physics_totals_ == nullptr &&
        !config_.transport_policy.configured && self->state_a_value() == maximum) {
        const auto inert_below = [&](std::int64_t tx, std::int64_t ty) {
            if (transient_obstacle_at(tx, ty) != 0U) return false;
            const auto m = fast_stored(tx, ty);
            if (m == Material::Water) return fast_state_a(tx, ty) == maximum;
            return m != Material::Empty && !MaterialRules::can_density_exchange(Material::Water, m, 1);
        };
        const auto inert_side = [&](std::int64_t tx, std::int64_t ty) {
            const auto m = fast_get(tx, ty);
            if (m == Material::Water) return maximum <= fast_state_a(tx, ty) + tolerance;
            return m != Material::Empty;
        };
        if (inert_below(x, y + 1) && inert_below(x - 1, y + 1) && inert_below(x + 1, y + 1) &&
            inert_side(x - 1, y) && inert_side(x + 1, y)) {
            const auto own = raw_head >= 0 ? raw_head : static_cast<std::int32_t>(maximum);
            const auto g = params.snapshot_gradient ? proto_gradient(x, y) : INT32_MIN;
            if (free_fall || (g != INT32_MIN ? std::abs(g)
                                             : std::abs(head_of(x - 1, y, own) - head_of(x + 1, y, own))) <= std::max(params.head_db, params.head_db_start))
                return false;
        }
    }
    const auto direction = deterministic_direction(x, y);
    if (coherence_delay != 0U) {
        const auto over = self->over_value();
        changed = write_cell(x, y, Material::Water, state_a(x, y),
                             static_cast<std::uint8_t>(coherence_delay - 1U), effects);
        // write_cell rebuilds the cell; restore the prototype registers.
        self->set_over(over);
        self->set_flow(static_cast<std::int8_t>(flow));
    }

    const auto fall_or_exchange = [&](std::int64_t tx, std::int64_t ty) {
        if (fast_mass(x, y) == 0U) return false;
        if (fast_get(tx, ty) == Material::Water) {
            ++proto_tls::stat[0];
            const auto moved = transfer_water(x, y, tx, ty, config_.water_experiment_policy.maximum(), effects);
            changed = changed || moved != 0;
            normalize(*self);
            return moved != 0;
        }
        const auto moved = try_move(Material::Water, x, y, tx, ty, true, effects);
        changed = changed || moved;
        return moved;
    };
    (void)fall_or_exchange(x, y + 1);
    if (fast_mass(x, y) == 0) return changed;
    (void)fall_or_exchange(x + direction, y + 1);
    if (fast_mass(x, y) == 0) return changed;
    (void)fall_or_exchange(x - direction, y + 1);
    if (fast_mass(x, y) == 0) return changed;
    if (self->material_value() != Material::Water) return changed;

    // Overfill is transient pressure excess: relay it upward now. The cell
    // above keeps its epoch, so it relays further when scanned this tick.
    if (params.relief && self->over_value() != 0 && transient_obstacle_at(x, y - 1) == 0U) {
        const auto above = fast_get(x, y - 1);
        // Small excess under open air is held (it still counts as mass and
        // pressure) instead of spawning a sliver cell that skitters about.
        // Pressurized trapped air (positive offset) admits rising water only
        // where the surface is below the pocket's mean level: troughs refill,
        // the mean cannot ratchet up. Unpressurized pockets act as open air.
        bool pocket_full = false;
        if (!params.air_state && above == Material::Empty) {
            const auto lx = x - proto_ox_, ly = y - 1 - proto_oy_;
            if (lx >= 0 && ly >= 0 && lx < proto_w_ && ly < proto_rows_) {
                const auto q = proto_pocket_[static_cast<std::size_t>(ly * proto_w_ + lx)];
                if (q >= 0 && proto_offset_[static_cast<std::size_t>(q)] > params.air_pressurized) {
                    const auto own = proto_pressure(x, y) - proto_offset_[static_cast<std::size_t>(q)];
                    pocket_full = own >= proto_pocket_mean_[static_cast<std::size_t>(q)];
                }
            }
        }
        const bool hold = above == Material::Empty && (self->over_value() < params.relief_min || pocket_full);
        if (!hold && (above == Material::Water || above == Material::Empty)) {
            ++proto_tls::stat[1];
            changed = proto_move(x, y, x, y - 1, self->over_value(), true, above == Material::Empty, effects) != 0 ||
                      changed;
        }
    }
    // Excess under a ceiling (solid, body) cannot rise: spread it sideways
    // to the less-loaded water neighbour until it reaches an open column.
    bool over_stuck = false;
    if (params.relief && self->over_value() > 1) {
        const auto above = fast_get(x, y - 1);
        if (above != Material::Water && above != Material::Empty) {
            std::int32_t best = 0, best_over = self->over_value();
            for (const std::int32_t s : {direction, -direction}) {
                if (fast_get(x + s, y) != Material::Water) continue;
                const auto a = address(x + s, y);
                const auto* c = find_chunk(a.chunk);
                if (c == nullptr) continue;
                const auto& n = c->cells[a.index];
                const std::int32_t n_over = n.state_a_value() < config_.water_experiment_policy.maximum() ? -1 : n.over_value();
                if (n_over < best_over - 1) { best = s; best_over = n_over; }
            }
            if (best != 0) {
                const auto amount = static_cast<std::uint32_t>((self->over_value() - std::max(0, best_over)) / 2);
                changed = proto_move(x, y, x + best, y, std::max<std::uint32_t>(amount, 1U), true, false, effects) != 0 || changed;
            } else {
                over_stuck = true;
            }
        }
    }

    if (coherence_delay != 0U) {
        if (flow != 0 || self->over_value() != 0) keep_cell_active(x, y, effects);
        return changed;
    }
    const auto support = fast_get(x, y + 1);
    if (liquid_surface_adhesion_enabled_ && self->over_value() == 0 &&
        fast_mass(x, y) <= config_.water_experiment_policy.film() &&
        support != Material::Empty && support != Material::Water) {
        if (flow != 0) self->set_flow(0);
        return changed;
    }
    if (!lateral_due(Material::Water, x, y, effects)) {
        if (flow != 0 || self->over_value() != 0) keep_cell_active(x, y, effects);
        return changed;
    }

    // Pressure-driven velocity: central head difference, depth-adaptive gain
    // so long waves travel near one cell per tick at any depth.
    const auto total = static_cast<std::int32_t>(self->state_a_value()) + self->over_value();
    const auto own_head = raw_head >= 0 ? raw_head : total;
    const auto dither_of = [&](std::uint64_t stream, std::int64_t range) {
        const auto key_x = params.dither_cell ? static_cast<std::uint64_t>(x) : static_cast<std::uint64_t>(x >> params.dither_shift);
        return static_cast<std::int64_t>(
            mix64(key_x * 0x9e3779b97f4a7c15ULL ^
                  std::rotl(static_cast<std::uint64_t>(y), 29) ^ (tick_index_ << 2U) ^ stream) %
            static_cast<std::uint64_t>(range));
    };
    bool forced = false;
    if (!free_fall) {
        // Radius-2 smoothed gradient: long slopes add up, cell noise averages.
        const auto snapshot_gradient = params.snapshot_gradient ? proto_gradient(x, y) : INT32_MIN;
        const auto dh = snapshot_gradient != INT32_MIN ? snapshot_gradient : params.wide
            ? (head_of(x - 2, y, own_head) + head_of(x - 1, y, own_head) - head_of(x + 1, y, own_head) -
               head_of(x + 2, y, own_head)) / 2
            : head_of(x - 1, y, own_head) - head_of(x + 1, y, own_head);
        // Start/stop hysteresis: a resting cell needs a clearly larger head
        // difference to start moving than a moving one needs to keep going,
        // so sub-cell noise cannot restart motion in a settled bulk.
        const auto start_db = flow == 0 ? std::max(params.head_db, params.head_db_start) : params.head_db;
        if (std::abs(dh) > start_db + proto_run(x, y) * params.head_db_depth / 64) {
            const auto denom = static_cast<std::int64_t>(64) * std::max<std::int32_t>(proto_run(x, y), params.hmin);
            const auto num = static_cast<std::int64_t>(dh) * params.g;
            auto acc = num / denom;
            const auto rem = std::abs(num % denom);
            if (dither_of(1, denom) < rem) acc += num > 0 ? 1 : -1;
            flow += static_cast<std::int32_t>(acc);
            if (acc != 0) ++proto_tls::stat[2];
            static const long long trace_tick = std::getenv("WTRACE") ? std::atoll(std::getenv("WTRACE")) : -1;
            if (acc != 0 && static_cast<long long>(tick_index_) == trace_tick)
                std::fprintf(stderr, "acc x=%lld y=%lld dh=%d H=%d flow=%d m=%u o=%u h[-2..2]=%d %d %d %d %d\n",
                             static_cast<long long>(x), static_cast<long long>(y), static_cast<int>(dh),
                             proto_run(x, y), flow, self->state_a_value(), self->over_value(),
                             head_of(x - 2, y, own_head), head_of(x - 1, y, own_head), own_head,
                             head_of(x + 1, y, own_head), head_of(x + 2, y, own_head));
            forced = acc != 0;
        } else if (std::abs(flow) <= params.settle_speed) {
            // Near equilibrium (no significant gradient here) a crawl is
            // overdamped: micro-sloshing stops instead of random-walking.
            flow = 0;
        }
    }
    // Low-speed friction: an unforced crawl stops at once, so residual
    // sub-resolution velocities cannot random-walk a settled volume.
    if (!forced && std::abs(flow) <= params.low_speed) flow = 0;
    {
        // Dithered decay: unbiased for small velocities instead of a
        // one-unit-per-tick truncation floor.
        // Bed friction: thin runs are strongly damped (shallow sheets and
        // films settle like HEAD), deep runs keep their momentum.
        const auto run_length = std::max<std::int32_t>(proto_run(x, y), 1);
        // Low-speed drag: a crawl (|u| <= 2) decays faster, so micro-sloshing
        // dies out while real flows (larger |u|) keep their inertia.
        const auto retained = std::max<std::int32_t>(
            params.decay - params.bed / run_length - (std::abs(flow) <= 2 ? params.slow_drag : 0), 128);
        const auto loss = static_cast<std::int64_t>(std::abs(flow)) * (256 - retained);
        auto drop = loss / 256;
        if (dither_of(2, 256) < loss % 256) ++drop;
        flow = flow > 0 ? flow - static_cast<std::int32_t>(drop) : flow + static_cast<std::int32_t>(drop);
    }
    if (std::abs(flow) < params.dead) flow = 0;
    flow = std::clamp(flow, -127, 127);
    if (flow != 0) {
        const std::int32_t s = flow > 0 ? 1 : -1;
        const auto target = fast_get(x + s, y);
        if (target != Material::Empty && target != Material::Water) {
            flow = -flow * params.reflect / 8;
        } else {
            const auto scaled = static_cast<std::int64_t>(std::abs(flow)) * total;
            auto amount = static_cast<std::uint32_t>(scaled / 127);
            if (dither_of(3, 127) < scaled % 127) ++amount;
            // Lumpy bulk transport: a small move into Water becomes one move
            // of `lump` with the same expected mass, so each refill chain it
            // triggers carries more mass (fewer transfers, same mean flux).
            if (target == Material::Water && params.lump > 1 && amount < static_cast<std::uint32_t>(params.lump))
                amount = dither_of(6, params.lump) < static_cast<std::int64_t>(amount) ? static_cast<std::uint32_t>(params.lump) : 0U;
            if (amount) ++proto_tls::stat[3];
            changed = proto_move(x, y, x + s, y, amount, target == Material::Water,
                                 target == Material::Empty || params.lateral_epoch, effects) != 0 || changed;
        }
    }
    if (self->material_value() != Material::Water) return changed;

    // Edge diffusion: a small first-order flux down each edge's own head
    // difference. Stable (k*H <= 1/2) and strongest on odd-even noise that a
    // collocated central gradient cannot see.
    if (params.diffusion != 0 && !free_fall && raw_head >= 0) {
        const auto run_length = std::max<std::int32_t>(proto_run(x, y), params.hmin);
        for (const std::int32_t s : {direction, -direction}) {
            if (self->material_value() != Material::Water) break;
            const auto target = fast_get(x + s, y);
            if (target != Material::Water) continue;
            const auto drop = raw_head - head_of(x + s, y, raw_head);
            if (drop <= params.edge_db) continue;
            const auto num = static_cast<std::int64_t>(drop) * params.diffusion;
            const auto denom = static_cast<std::int64_t>(64) * run_length;
            auto amount = num / denom;
            if (dither_of(4 + static_cast<std::uint64_t>(s + 1), denom) < num % denom) ++amount;
            if (amount > 0)
                changed = proto_move(x, y, x + s, y, static_cast<std::uint32_t>(amount), true,
                                     params.lateral_epoch != 0, effects) != 0 || changed;
        }
        if (self->material_value() != Material::Water) return changed;
    }

    if (self->over_value() == 0 && (params.skin == 2 || (params.skin == 1 && fast_get(x, y - 1) != Material::Water))) {
        const auto level_with = [&](std::int64_t tx, std::int64_t ty) {
            const auto source_mass = static_cast<std::uint16_t>(fast_mass(x, y));
            if (source_mass == 0) return;
            const auto tm = fast_get(tx, ty);
            if (tm != Material::Empty && tm != Material::Water) return;
            const auto target_mass = static_cast<std::uint16_t>(fast_mass(tx, ty));
            if (source_mass <= target_mass + std::max<int>(tolerance, params.skin_tolerance)) return;
            const auto requested = MaterialRules::apply_lateral_viscosity(
                Material::Water, static_cast<std::uint16_t>((source_mass - target_mass) * static_cast<unsigned>(proto::params().skin_frac) / 4U));
            if (requested) ++proto_tls::stat[4];
            changed = transfer_water(x, y, tx, ty, requested, effects) != 0 || changed;
        };
        level_with(x + direction, y);
        if (!config_.transport_policy.configured || config_.transport_policy.horizontal[3] == 2)
            level_with(x - direction, y);
        if (self->material_value() != Material::Water) return changed;
    }
    if (self->flow_value() != flow) self->set_flow(static_cast<std::int8_t>(flow));
    const bool held = over_stuck ||
        (self->over_value() != 0 && self->over_value() < params.relief_min && fast_get(x, y - 1) == Material::Empty) ||
        // A few units of compressed water under a lid stay put (stored mass)
        // instead of shuffling sideways forever and keeping the block awake.
        (self->over_value() != 0 && self->over_value() <= params.over_hold &&
         fast_get(x, y - 1) != Material::Empty && fast_get(x, y - 1) != Material::Water);
    if (flow != 0 || (self->over_value() != 0 && !held)) keep = true;
    if (keep) keep_cell_active(x, y, effects);
    return changed;
}
