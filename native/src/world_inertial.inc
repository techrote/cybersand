// Included by world.cpp only. LCB-005 (#212) inertial_cellular_v1/reference: one
// ordered `inertial-update-v1` per inertial cell per tick (executable contract
// tools/lcb/inertial_contract.py). Exact integers, truncation toward zero,
// directional eligibility, one contact rule, bounded travel (2 cells per axis).
// Material hooks (pair chemistry before dispatch, density exchange, body-mask
// contact, transport coupling) are the Current ones.

namespace {

struct InertialDelta {
    std::int64_t gravity_y = 0;
    std::int64_t impulse_x = 0;
    std::int64_t impulse_y = 0;
    std::int64_t loss = 0;
    std::int64_t support = 0;
    std::int64_t remainder = 0;
    std::uint64_t unit_moves = 0;
    std::uint64_t density_swaps = 0;
    std::uint64_t contacts = 0;
    std::uint64_t rests = 0;
    std::uint64_t maximum_read_reach = 0, maximum_write_reach = 0;
};

struct Truncated {
    std::int32_t applied;
    std::int32_t remainder;
};

[[nodiscard]] constexpr Truncated trunc_mul(std::int32_t value, std::int32_t numerator,
                                            std::int32_t denominator) noexcept {
    const auto magnitude = (value < 0 ? -value : value) * numerator / denominator;
    const auto applied = value < 0 ? -magnitude : magnitude;
    return {applied, value * numerator - applied * denominator};
}

} // namespace

bool World::inertial_family(Material material) const noexcept {
    const auto index = static_cast<std::size_t>(material);
    return index < inertial_materials_.size() && inertial_materials_[index];
}

InertialCellState World::inertial_cell(std::int64_t x, std::int64_t y) const noexcept {
    InertialCellState out;
    if (!inertial_enabled_)
        return out;
    out.available = true;
    const auto target = address(x, y);
    const auto *chunk = find_chunk(target.chunk);
    if (chunk == nullptr || chunk->inertial == nullptr)
        return out;
    const auto &state = (*chunk->inertial)[target.index];
    out.vx = state.vx;
    out.vy = state.vy;
    out.ax = state.ax;
    out.ay = state.ay;
    return out;
}

InertialLedger World::inertial_ledger() const noexcept { return inertial_ledger_; }

void World::retire_inertial_cell(Chunk &chunk, std::size_t index, JobEffects *effects) noexcept {
    auto &state = (*chunk.inertial)[index];
    const auto magnitude = static_cast<std::uint64_t>(std::abs(state.vx) + std::abs(state.vy));
    if (magnitude != 0U) {
        if (effects != nullptr) {
            effects->inertial.velocity_retired += magnitude;
            effects->inertial.retired_x += state.vx;
            effects->inertial.retired_y += state.vy;
        } else {
            inertial_ledger_.velocity_retired += magnitude;
            inertial_ledger_.retired_x += state.vx;
            inertial_ledger_.retired_y += state.vy;
        }
    }
    state = {};
}

bool World::diagnostic_set_inertial_cell(std::int64_t x, std::int64_t y, std::int16_t vx, std::int16_t vy,
                                         std::int8_t ax, std::int8_t ay) {
    if (tick_failed_ || tick_in_progress_ || !inertial_enabled_)
        return false;
    using P = InertialParameters;
    if (vy < 0 || vy > P::kVmax || vx < -P::kVmax || vx > P::kVmax || ax <= -P::kQ || ax >= P::kQ ||
        ay <= -P::kQ || ay >= P::kQ)
        return false;
    const auto target = address(x, y);
    auto *chunk = find_chunk(target.chunk);
    if (chunk == nullptr || chunk->inertial == nullptr ||
        !inertial_family(chunk->cells[target.index].material_value()))
        return false;
    auto &state = (*chunk->inertial)[target.index];
    if (state.vx == vx && state.vy == vy && state.ax == ax && state.ay == ay)
        return true;
    inertial_ledger_.external_speed += std::abs(vx) + std::abs(vy) - std::abs(state.vx) - std::abs(state.vy);
    inertial_ledger_.external_x += vx - state.vx;
    inertial_ledger_.external_y += vy - state.vy;
    state = {vx, vy, ax, ay};
    chunk->changed_this_tick = true;
    mark_cell_dirty(*chunk, target.local_x, target.local_y);
    wake_cell_neighborhood(x, y);
    keep_cell_active(x, y, nullptr);
    dirty_discovery_cell(x, y, soliding::ProducerReason::DirectMutation);
    return true;
}

bool World::update_inertial(Material material, std::int64_t x, std::int64_t y, JobEffects *effects) {
    using P = InertialParameters;
    auto *start_chunk = find_chunk(address(x, y).chunk);
    if (start_chunk == nullptr || start_chunk->inertial == nullptr)
        return false;
    const auto start_index = address(x, y).index;
    const auto initial = (*start_chunk->inertial)[start_index];
    MotionFootprint footprint{x,y};
    const bool water = material == Material::Water;
    const auto coherence = water ? state_b(x,y) : std::uint8_t{0};
    bool water_changed = false;
    if (water) {
        record_physics(PhysicsEvent::WaterUpdate, material, Material::Empty, 0, 0, effects);
        if (coherence != 0U)
            water_changed = write_cell(x,y,material,config_.water_experiment_policy.maximum(),
                static_cast<std::uint8_t>(coherence-1U),effects);
    }
    std::int32_t vx = initial.vx;
    std::int32_t vy = initial.vy;
    std::int32_t ax = initial.ax;
    std::int32_t ay = initial.ay;
    if (vy < 0)
        throw std::logic_error("inertial_cellular_v1 holds a negative vy");
    InertialDelta book;
    const auto speed = [&]() { return static_cast<std::int64_t>(std::abs(vx) + std::abs(vy)); };
    struct Snapshot {
        std::int32_t vx, vy;
    };
    const auto booked = [&](Snapshot before) {
        book.impulse_x += vx - before.vx;
        book.impulse_y += vy - before.vy;
        book.loss += static_cast<std::int64_t>(std::abs(before.vx) + std::abs(before.vy)) - speed();
    };
    std::int64_t cx = x;
    std::int64_t cy = y;
    const auto direction = deterministic_direction(x, y);
    // Support/re-aim/rest probes owe the same material/body feedback as travel,
    // including at zero velocity. A repeated target and normal in this update
    // is one contact (U1/U7 and travel rechecks); after travel a different normal
    // at that target remains a distinct signed impulse. The complete radius-3
    // domain has 49 targets, so this scratch is fixed and never enters authority.
    std::array<std::uint64_t, 9> body_contact_targets{};
    // One directional eligibility rule for support, re-aim, side selection and
    // every travel move: Empty for any move; a lighter foreign material only
    // downward under Current density/exchange controls; never Wall, mask or
    // same material. A foreign lighter material retains density exchange even
    // when both materials select IN. Reads do not allocate serial sparse chunks.
    const auto eligible = [&](std::int64_t dx, std::int64_t dy) {
        const auto tx = cx + dx;
        const auto ty = cy + dy;
        if (tx < x - P::kExecutionRadius || tx > x + P::kExecutionRadius || ty < y - P::kExecutionRadius ||
            ty > y + P::kExecutionRadius)
            throw std::logic_error("IN read/write outside complete execution radius");
        footprint.read(tx,ty);
        if (const auto body = transient_obstacle_at(tx, ty); body != 0U) {
            constexpr auto width = 2 * P::kExecutionRadius + 1;
            const auto target_bit = std::uint64_t{1} <<
                ((ty - y + P::kExecutionRadius) * width + tx - x + P::kExecutionRadius);
            const auto normal = static_cast<std::size_t>((dy + 1) * 3 + dx + 1);
            if ((body_contact_targets[normal] & target_bit) == 0U) {
                body_contact_targets[normal] |= target_bit;
                record_physics(PhysicsEvent::BodyContact, material, Material::Empty, dx, dy, effects);
                record_transient_contact(body, material, dx, dy);
            }
            return false;
        }
        const auto target_address = address(tx, ty);
        const auto *chunk = find_chunk(target_address.chunk);
        if (chunk == nullptr)
            return effects == nullptr && config_.backend == SimulationBackend::SerialInPlace;
        const auto &cell = chunk->cells[target_address.index];
        const auto target = cell.material_value();
        if (target == Material::Empty)
            return true;
        if (config_.physics_diagnostics.disable_powder_exchange_targets &&
            MaterialRules::descriptor(target).state == MaterialState::Powder)
            return false;
        return dy == 1 && MaterialRules::can_density_exchange(material, target, 1) &&
               cell.epoch_value() != update_epoch_;
    };
    const auto side = [&](std::int64_t dy) -> std::int32_t {
        const std::int32_t first = vx != 0 ? (vx > 0 ? 1 : -1) : direction;
        for (const auto s : {first, -first})
            if (eligible(s, dy))
                return s;
        return 0;
    };
    const auto land = [&](std::int32_t carried) {
        const Snapshot before{vx, vy};
        const auto s = side(0);
        if (s != 0 && carried > 0) {
            const auto deflected = trunc_mul(carried, P::kDeflectNumerator, P::kDeflectDenominator);
            vy -= carried;
            vx += s * deflected.applied;
            book.remainder += deflected.remainder;
        } else {
            vy -= carried;
            if (carried != 0)
                ++book.contacts;
        }
        booked(before);
        ay = 0;
    };
    const auto saturate = [&]() {
        const Snapshot before{vx, vy};
        vx = std::clamp(vx, -P::kVmax, P::kVmax);
        vy = std::clamp(vy, -P::kVmax, P::kVmax);
        booked(before);
    };

    const auto carried = vy;
    // U1 support, before any velocity change.
    const bool supported = !eligible(0, 1);
    // U2 exactly one gravity application.
    vy += P::kGravity;
    book.gravity_y += P::kGravity;
    // U3 vertical resolution of a supported cell.
    if (supported) {
        if (const auto diagonal = side(1); diagonal != 0) {
            const Snapshot before{vx, vy};
            const auto in = std::abs(vx) + std::abs(vy);
            const auto turn = trunc_mul(in, P::kTurnNumerator, P::kTurnDenominator);
            const auto out = in - turn.applied;
            vx = diagonal * (out / 2);
            vy = out - out / 2;
            book.remainder += turn.remainder;
            booked(before);
        } else {
            const Snapshot before{vx, vy};
            vy -= P::kGravity;
            booked(before);
            book.support += P::kGravity;
            land(carried);
        }
    }
    // U4 saturation, U5 damping.
    saturate();
    {
        const Snapshot before{vx, vy};
        const auto damp_x = trunc_mul(vx, inertial_parameters_.damping_numerator, P::kDampingDenominator);
        const auto damp_y = trunc_mul(vy, inertial_parameters_.damping_numerator, P::kDampingDenominator);
        vx -= damp_x.applied;
        vy -= damp_y.applied;
        book.remainder += damp_x.remainder + damp_y.remainder;
        booked(before);
    }
    // U6 accumulator travel with a target recheck before every unit move.
    ax += vx;
    ay += vy;
    const auto nx = ax / P::kQ; // C++ integer division truncates toward zero
    const auto ny = ay / P::kQ;
    ax -= nx * P::kQ;
    ay -= ny * P::kQ;
    const auto steps = std::max(std::abs(nx), std::abs(ny));
    const std::int32_t sx = nx > 0 ? 1 : -1;
    const std::int32_t sy = ny > 0 ? 1 : -1;
    std::int32_t done_x = 0;
    std::int32_t done_y = 0;
    bool moved = false;
    std::optional<bool> lateral_allowed;
    for (std::int32_t i = 1; i <= steps; ++i) {
        const auto want_y = std::abs(ny) * i / steps - done_y;
        const auto want_x = std::abs(nx) * i / steps - done_x;
        std::array<std::pair<std::int32_t, std::int32_t>, 2> plan{};
        std::size_t count = 0;
        if (want_x != 0 && want_y != 0 && eligible(sx, sy)) {
            plan[count++] = {sx, sy};
        } else {
            if (want_y != 0)
                plan[count++] = {0, sy};
            if (want_x != 0)
                plan[count++] = {sx, 0};
        }
        bool stop = false;
        for (std::size_t p = 0; p < count && !stop; ++p) {
            const auto [dx, dy] = plan[p];
            if (water && dy == 0) {
                if (!lateral_allowed)
                    lateral_allowed = coherence == 0U && lateral_due(material,x,y,effects);
                if (!*lateral_allowed) {
                    // Coherence/cadence is a scheduling gate, not a collision.
                    // Velocity and bounded fractional phase remain under U1-U7;
                    // consumed opportunities never become catch-up travel.
                    done_x += std::abs(dx);
                    continue;
                }
            }
            const auto tx = cx + dx;
            const auto ty = cy + dy;
            if (tx < x - P::kExecutionRadius || tx > x + P::kExecutionRadius ||
                ty < y - P::kExecutionRadius || ty > y + P::kExecutionRadius)
                throw std::logic_error("IN read/write outside complete execution radius");
            bool permitted = eligible(dx, dy);
            footprint.read(tx,ty);
            const auto target = stored_material(tx, ty);
            if (permitted && target != Material::Empty &&
                !exchange_permitted(material, target, cx, cy, tx, ty, effects, &footprint))
                permitted = false;
            if (!permitted) {
                if (dy != 0) {
                    land(vy);
                    saturate();
                } else {
                    const Snapshot before{vx, vy};
                    vx = 0;
                    ax = 0;
                    booked(before);
                    ++book.contacts;
                }
                stop = true;
                break;
            }
            footprint.read(cx,cy);
            footprint.write(cx,cy);
            footprint.write(tx,ty);
            auto carrier = std::pair{tx,ty};
            if (target != Material::Empty) {
                const Snapshot before{vx, vy};
                const auto drag_x = trunc_mul(vx, P::kDragNumerator, P::kDragDenominator);
                const auto drag_y = trunc_mul(vy, P::kDragNumerator, P::kDragDenominator);
                vx -= drag_x.applied;
                vy -= drag_y.applied;
                book.remainder += drag_x.remainder + drag_y.remainder;
                booked(before);
                ++book.density_swaps;
                move_cell(cx, cy, tx, ty, true, effects);
            } else {
                move_cell(cx, cy, tx, ty, false, effects);
                if (stored_material(tx, ty) == material && stored_material(cx, cy) == Material::Empty)
                    carrier = mix_after_motion(material, cx, cy, tx, ty, state_a(tx, ty), effects, &footprint);
            }
            cx = carrier.first;
            cy = carrier.second;
            moved = true;
            ++book.unit_moves;
            done_x += std::abs(dx);
            done_y += std::abs(dy);
        }
        if (stop)
            break;
    }
    // U7 rest and sleep eligibility.
    const bool rested = !eligible(0, 1);
    if (rested && vy == 0 && std::abs(vx) <= P::kRest) {
        const Snapshot before{vx, vy};
        vx = 0;
        booked(before);
        if (before.vx != 0)
            ++book.rests;
        ax = 0;
        ay = 0;
    }
    const bool sleep_eligible = rested && vx == 0 && vy == 0 && ax == 0 && ay == 0 && coherence <= 1U;
    // Store at the cell's final position (move_cell carried the old values).
    footprint.read(cx,cy);
    footprint.write(cx,cy);
    if (stored_material(cx,cy) != material)
        throw std::logic_error("IN final state lost actual material carrier");
    book.maximum_read_reach = footprint.reads;
    book.maximum_write_reach = footprint.writes;
    const auto final_address = address(cx, cy);
    auto *final_chunk = find_chunk(final_address.chunk);
    auto &state = (*final_chunk->inertial)[final_address.index];
    const bool state_changed = state.vx != vx || state.vy != vy || state.ax != ax || state.ay != ay;
    state.vx = static_cast<std::int16_t>(vx);
    state.vy = static_cast<std::int16_t>(vy);
    state.ax = static_cast<std::int8_t>(ax);
    state.ay = static_cast<std::int8_t>(ay);
    if (state_changed && !moved) {
        if (effects != nullptr) {
            effects->record(final_address, 0);
            if (settled_discovery_ != nullptr)
                effects->record_discovery_mutation(final_address, config_.activity_block_size);
        } else {
            final_chunk->changed_this_tick = true;
            mark_cell_dirty(*final_chunk, final_address.local_x, final_address.local_y);
            wake_cell_neighborhood(cx, cy);
            dirty_discovery_cell(cx, cy, soliding::ProducerReason::DirectMutation);
        }
    }
    if (!sleep_eligible)
        keep_cell_active(cx, cy, effects);
    if (effects != nullptr) {
        effects->inertial.gravity_y += book.gravity_y;
        effects->inertial.impulse_x += book.impulse_x;
        effects->inertial.impulse_y += book.impulse_y;
        effects->inertial.loss += book.loss;
        effects->inertial.support += book.support;
        effects->inertial.remainder += book.remainder;
        effects->inertial.unit_moves += book.unit_moves;
        effects->inertial.density_swaps += book.density_swaps;
        effects->inertial.contacts += book.contacts;
        effects->inertial.rests += book.rests;
        effects->inertial.maximum_read_reach =
            std::max(effects->inertial.maximum_read_reach, book.maximum_read_reach);
        effects->inertial.maximum_write_reach =
            std::max(effects->inertial.maximum_write_reach, book.maximum_write_reach);
        ++effects->inertial.updates;
    } else {
        auto &ledger = inertial_ledger_;
        ledger.gravity_y += book.gravity_y;
        ledger.impulse_x += book.impulse_x;
        ledger.impulse_y += book.impulse_y;
        ledger.loss += book.loss;
        ledger.support += book.support;
        ledger.remainder += book.remainder;
        ledger.unit_moves += book.unit_moves;
        ledger.density_swaps += book.density_swaps;
        ledger.contacts += book.contacts;
        ledger.rests += book.rests;
        ledger.maximum_read_reach = std::max(ledger.maximum_read_reach, book.maximum_read_reach);
        ledger.maximum_write_reach = std::max(ledger.maximum_write_reach, book.maximum_write_reach);
        ++ledger.updates;
    }
    return moved || state_changed || water_changed;
}

InertialStorageUsage World::inertial_storage_usage() const noexcept {
    InertialStorageUsage out;
    out.slot_size = sizeof(InertialSlot);
    out.slot_alignment = alignof(InertialSlot);
    out.world_state_bytes =
        sizeof(inertial_enabled_) + sizeof(inertial_materials_) + sizeof(inertial_ledger_) + sizeof(inertial_parameters_);
    out.job_ledger_bytes = parallel_ == nullptr ? 0U : parallel_->results.capacity() * sizeof(InertialLedger);
    for (const auto &[coord, p] : chunks_) {
        (void)coord;
        out.owner_bytes += sizeof(p->inertial);
        if (p->inertial == nullptr)
            continue;
        ++out.resident_chunks;
        out.slot_capacity += p->inertial->capacity();
        out.owner_bytes += sizeof(*p->inertial);
        for (const auto &s : *p->inertial)
            if (s.vx || s.vy || s.ax || s.ay)
                ++out.nonzero_slots;
    }
    out.slot_bytes = out.slot_capacity * sizeof(InertialSlot);
    out.total_component_bytes =
        out.slot_bytes + out.owner_bytes + out.job_ledger_bytes + out.world_state_bytes;
    return out;
}

void World::validate_inertial_ledger() const {
    if (!inertial_enabled_)
        return;
    const auto add = [](std::int64_t a, std::int64_t b) {
        if ((b > 0 && a > std::numeric_limits<std::int64_t>::max() - b) ||
            (b < 0 && a < std::numeric_limits<std::int64_t>::min() - b))
            throw std::invalid_argument("IN ledger arithmetic capacity");
        return a + b;
    };
    const auto sub = [](std::int64_t a, std::int64_t b) {
        if ((b > 0 && a < std::numeric_limits<std::int64_t>::min() + b) ||
            (b < 0 && a > std::numeric_limits<std::int64_t>::max() + b))
            throw std::invalid_argument("IN ledger arithmetic capacity");
        return a - b;
    };
    std::int64_t x = 0, y = 0, speed = 0;
    for (const auto &[coord, chunk] : chunks_) {
        (void)coord;
        for (const auto &state : *chunk->inertial) {
            x = add(x, state.vx);
            y = add(y, state.vy);
            speed = add(speed, std::abs(state.vx) + std::abs(state.vy));
        }
    }
    const auto &l = inertial_ledger_;
    if (l.velocity_retired > static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max()) ||
        x != sub(add(l.impulse_x, l.external_x), l.retired_x) ||
        y != sub(add(add(l.gravity_y, l.impulse_y), l.external_y), l.retired_y) ||
        speed != sub(add(sub(l.gravity_y, l.loss), l.external_speed),
                     static_cast<std::int64_t>(l.velocity_retired)))
        throw std::invalid_argument("IN ledger does not close");
}
