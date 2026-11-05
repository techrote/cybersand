// Included by world.cpp only, after the Chunk/Address definitions and the IN
// helpers. BW-001 ballistic_water_v1: a bounded, serialized parcel owner for
// Water in flight (see cybersand/ballistic_water.hpp). Parcels advance once per
// tick at tick entry, in slot order, independent of worker count. Every grid
// write is an exact quantity transfer (never a source/sink) except injection,
// which is booked as an ExternalEdit source.

namespace {

constexpr std::int64_t kBallisticQ = BallisticWaterConfig::kQ;

[[nodiscard]] std::int64_t ballistic_cell(std::int64_t q) noexcept {
    return q >= 0 ? q / kBallisticQ : -((-q + kBallisticQ - 1) / kBallisticQ);
}

[[nodiscard]] std::int32_t ballistic_scale(std::int32_t value, std::int32_t numerator) noexcept {
    const auto magnitude = (static_cast<std::int64_t>(value < 0 ? -value : value) * numerator) / 256;
    return static_cast<std::int32_t>(value < 0 ? -magnitude : magnitude);
}

[[nodiscard]] std::int64_t ballistic_checked_product(std::int64_t quantity, std::int64_t velocity) {
    if (velocity != 0 && (quantity > std::numeric_limits<std::int64_t>::max() / std::abs(velocity)))
        throw std::overflow_error("ballistic momentum arithmetic capacity");
    return quantity * velocity;
}

// Deterministic deposition probe order: the cell itself, then rings preferring
// upward and lateral cells before downward ones (a landed parcel sits on top).
constexpr std::array<std::array<std::int8_t, 2>, 25> kBallisticDepositOrder{{
    {0, 0},
    {0, -1}, {-1, 0}, {1, 0}, {-1, -1}, {1, -1}, {0, 1}, {-1, 1}, {1, 1},
    {0, -2}, {-1, -2}, {1, -2}, {-2, 0}, {2, 0}, {-2, -1}, {2, -1}, {-2, -2}, {2, -2},
    {-2, 1}, {2, 1}, {0, 2}, {-1, 2}, {1, 2}, {-2, 2}, {2, 2},
}};

} // namespace

void World::validate_ballistic_config() const {
    const auto& c = config_.ballistic_water;
    if (!c.enabled) return;
    if (c.capacity == 0U || c.capacity > BallisticWaterConfig::kMaximumCapacity ||
        c.gravity_q < 0 || c.gravity_q > 256 || c.max_speed_q < 64 || c.max_speed_q > 8 * kBallisticQ ||
        c.air_drag < 0 || c.air_drag > 64 || c.restitution < 0 || c.restitution > 256 ||
        c.friction < 0 || c.friction > 256 || c.settle_speed_q < 0 || c.settle_speed_q > c.max_speed_q ||
        c.maximum_age_ticks == 0U || c.maximum_age_ticks > 1'000'000U || c.deposit_radius < 0 ||
        c.deposit_radius > 2 || c.maximum_contacts > 32U)
        throw std::invalid_argument("ballistic_water_v1 configuration outside its admitted envelope");
}

BallisticWaterSnapshot World::ballistic_water_snapshot() const noexcept {
    BallisticWaterSnapshot out;
    out.enabled = config_.ballistic_water.enabled;
    out.capacity = out.enabled ? config_.ballistic_water.capacity : 0U;
    out.live = static_cast<std::uint32_t>(ballistic_parcels_.size());
    for (const auto& p : ballistic_parcels_) {
        out.in_flight_quantity += p.quantity;
        out.momentum_x += static_cast<std::int64_t>(p.quantity) * p.vx;
        out.momentum_y += static_cast<std::int64_t>(p.quantity) * p.vy;
    }
    out.ledger = ballistic_ledger_;
    return out;
}

std::size_t World::copy_ballistic_parcels(std::span<BallisticParcel> output) const noexcept {
    const auto count = std::min(output.size(), ballistic_parcels_.size());
    std::copy_n(ballistic_parcels_.begin(), count, output.begin());
    return ballistic_parcels_.size();
}

std::int64_t World::transient_ballistic_impulse_x(std::uint16_t body) const noexcept {
    return body <= kMaximumTransientBodies ? ballistic_body_px_[body] : 0;
}
std::int64_t World::transient_ballistic_impulse_y(std::uint16_t body) const noexcept {
    return body <= kMaximumTransientBodies ? ballistic_body_py_[body] : 0;
}

void World::reset_ballistic_body_impulses() noexcept {
    ballistic_body_px_.fill(0);
    ballistic_body_py_.fill(0);
}

void World::reset_ballistic_water() noexcept {
    ballistic_parcels_.clear();
    ballistic_ledger_ = {};
    reset_ballistic_body_impulses();
}

// One exact transfer write: the stored Water quantity at (x, y) becomes
// `visible` (Empty when zero). Never a source or sink, never under a foreign
// family default: overfill and IN state follow write_cell's material-change rules.
void World::ballistic_write_water(std::int64_t x, std::int64_t y, std::uint16_t visible) {
    const auto target = address(x, y);
    auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr) throw std::logic_error("ballistic transfer reached a non-resident chunk");
    auto& cell = chunk->cells[target.index];
    const auto before = cell.material_value();
    if (before != Material::Empty && before != Material::Water)
        throw std::logic_error("ballistic transfer reached a foreign material");
    const auto after = visible == 0U ? Material::Empty : Material::Water;
    if (chunk->granular_arrivals) (*chunk->granular_arrivals)[target.index] = 0;
    const auto old_overfill = chunk->pressure == nullptr ? std::uint16_t{0} : chunk->pressure->cells[target.index].overfill;
    if (before != after && old_overfill != 0U)
        throw std::logic_error("ballistic transfer would discard pressurized overfill");
    record_quantity_transition(before, before == Material::Water ? cell.state_a_value() : std::uint16_t{0},
                               old_overfill, after, visible, before == after ? old_overfill : std::uint16_t{0},
                               nullptr, {}, false);
    if (before != after) {
        if (chunk->pressure != nullptr) reset_pressure_cell(*chunk, target.index, before, after, true, nullptr);
        if (chunk->inertial != nullptr) retire_inertial_cell(*chunk, target.index, nullptr);
    }
    const auto coherence = before == Material::Water ? cell.state_b_value() : std::uint8_t{0};
    if (before != after) {
        cell = Chunk::Cell::for_material(after);
        chunk->non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(chunk->non_empty_cell_count) + (after == Material::Empty ? -1 : 1));
    }
    if (after == Material::Water) {
        cell.set_state_a(visible);
        cell.set_state_b(coherence);
    }
    cell.set_epoch(update_epoch_);
    invalidate_pressure_input(target.chunk, target.local_x, target.local_y, target.local_x, target.local_y,
                              before != after);
    chunk->changed_this_tick = true;
    mark_cell_dirty(*chunk, target.local_x, target.local_y);
    wake_cell_neighborhood(x, y);
    dirty_discovery_cell(x, y, soliding::ProducerReason::DirectMutation);
}

World::BallisticCell World::classify_ballistic_cell(std::int64_t x, std::int64_t y, const BallisticParcel& parcel,
                                                    std::uint16_t& body) const noexcept {
    body = 0;
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr) return BallisticCell::Outside;
    if (const auto id = transient_obstacle_at(x, y); id != 0U) {
        if (id == parcel.source_body && parcel.age <= BallisticWaterConfig::kSelfContactGraceTicks)
            return BallisticCell::Free;
        body = id;
        return BallisticCell::Body;
    }
    const auto material = chunk->cells[target.index].material_value();
    if (material == Material::Empty) return BallisticCell::Free;
    if (material == Material::Water) return BallisticCell::Water;
    if (MaterialRules::descriptor(material).state == MaterialState::Gas) return BallisticCell::Free;
    return BallisticCell::Solid;
}

BallisticLaunchResult World::admit_ballistic_spawn(std::int64_t spawn_x, std::int64_t spawn_y,
                                                   std::int32_t vx, std::int32_t vy) const noexcept {
    BallisticLaunchResult result;
    const auto& c = config_.ballistic_water;
    if (!c.enabled) { result.outcome = BallisticLaunchOutcome::Disabled; return result; }
    if (tick_failed_) { result.outcome = BallisticLaunchOutcome::WorldFailed; return result; }
    if (tick_in_progress_) { result.outcome = BallisticLaunchOutcome::TickInProgress; return result; }
    constexpr std::int64_t limit = std::int64_t{1} << 52;
    if (std::abs(vx) > c.max_speed_q || std::abs(vy) > c.max_speed_q || spawn_x < -limit || spawn_x > limit ||
        spawn_y < -limit || spawn_y > limit) {
        result.outcome = BallisticLaunchOutcome::InvalidRequest;
        return result;
    }
    if (ballistic_parcels_.size() >= c.capacity) { result.outcome = BallisticLaunchOutcome::CapacityFull; return result; }
    const auto cx = ballistic_cell(spawn_x), cy = ballistic_cell(spawn_y);
    const auto* chunk = find_chunk(address(cx, cy).chunk);
    if (chunk == nullptr) { result.outcome = BallisticLaunchOutcome::NonResident; return result; }
    if (transient_obstacle_at(cx, cy) != 0U) { result.outcome = BallisticLaunchOutcome::Masked; return result; }
    const auto material = chunk->cells[address(cx, cy).index].material_value();
    if (material != Material::Empty && MaterialRules::descriptor(material).state != MaterialState::Gas) {
        result.outcome = BallisticLaunchOutcome::InvalidRequest;
        return result;
    }
    result.outcome = BallisticLaunchOutcome::Launched;
    return result;
}

BallisticLaunchResult World::launch_ballistic_water(std::int64_t source_x, std::int64_t source_y,
        std::int64_t spawn_x, std::int64_t spawn_y, std::int32_t vx, std::int32_t vy,
        std::uint16_t source_body, std::uint32_t maximum_quantity) {
    auto result = admit_ballistic_spawn(spawn_x, spawn_y, vx, vy);
    result.live = static_cast<std::uint32_t>(ballistic_parcels_.size());
    if (result.outcome == BallisticLaunchOutcome::CapacityFull) ++ballistic_ledger_.refused_launches;
    if (result.outcome != BallisticLaunchOutcome::Launched) return result;
    if (source_body > kMaximumTransientBodies) { result.outcome = BallisticLaunchOutcome::InvalidRequest; return result; }
    const auto source = address(source_x, source_y);
    auto* chunk = find_chunk(source.chunk);
    if (chunk == nullptr) { result.outcome = BallisticLaunchOutcome::NonResident; return result; }
    const auto& cell = chunk->cells[source.index];
    if (cell.material_value() != Material::Water) { result.outcome = BallisticLaunchOutcome::NotWater; return result; }
    if (chunk->pressure != nullptr && chunk->pressure->cells[source.index].overfill != 0U) {
        result.outcome = BallisticLaunchOutcome::Pressurized;
        return result;
    }
    const auto mass = static_cast<std::uint32_t>(cell.state_a_value());
    const auto maximum = static_cast<std::uint32_t>(config_.water_experiment_policy.maximum());
    std::uint32_t quantity = std::min(mass, maximum_quantity);
    if (whole_cell_water_enabled()) quantity = maximum_quantity >= maximum ? mass : 0U;
    if (quantity == 0U) { result.outcome = BallisticLaunchOutcome::InsufficientQuantity; return result; }
    ballistic_write_water(source_x, source_y, static_cast<std::uint16_t>(mass - quantity));
    BallisticParcel parcel;
    parcel.x = spawn_x;
    parcel.y = spawn_y;
    parcel.vx = vx;
    parcel.vy = vy;
    parcel.quantity = quantity;
    parcel.source_body = source_body;
    ballistic_parcels_.push_back(parcel);
    quantity_.water_ballistic += quantity;
    auto& l = ballistic_ledger_;
    ++l.launched_parcels;
    l.launched_quantity += quantity;
    l.launch_px += ballistic_checked_product(quantity, vx);
    l.launch_py += ballistic_checked_product(quantity, vy);
    l.maximum_live = std::max<std::uint64_t>(l.maximum_live, ballistic_parcels_.size());
    result.quantity = quantity;
    result.live = static_cast<std::uint32_t>(ballistic_parcels_.size());
    return result;
}

BallisticLaunchResult World::inject_ballistic_water(std::int64_t spawn_x, std::int64_t spawn_y,
        std::int32_t vx, std::int32_t vy, std::uint32_t quantity) {
    auto result = admit_ballistic_spawn(spawn_x, spawn_y, vx, vy);
    result.live = static_cast<std::uint32_t>(ballistic_parcels_.size());
    if (result.outcome == BallisticLaunchOutcome::CapacityFull) ++ballistic_ledger_.refused_launches;
    if (result.outcome != BallisticLaunchOutcome::Launched) return result;
    const auto maximum = static_cast<std::uint32_t>(config_.water_experiment_policy.maximum());
    if (quantity == 0U || quantity > maximum || (whole_cell_water_enabled() && quantity != maximum)) {
        result.outcome = BallisticLaunchOutcome::InvalidRequest;
        return result;
    }
    auto& source = quantity_.kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)];
    source.produced += quantity;
    quantity_.water_ballistic += quantity;
    BallisticParcel parcel;
    parcel.x = spawn_x;
    parcel.y = spawn_y;
    parcel.vx = vx;
    parcel.vy = vy;
    parcel.quantity = quantity;
    ballistic_parcels_.push_back(parcel);
    auto& l = ballistic_ledger_;
    ++l.injected_parcels;
    l.injected_quantity += quantity;
    l.launch_px += ballistic_checked_product(quantity, vx);
    l.launch_py += ballistic_checked_product(quantity, vy);
    l.maximum_live = std::max<std::uint64_t>(l.maximum_live, ballistic_parcels_.size());
    result.quantity = quantity;
    result.live = static_cast<std::uint32_t>(ballistic_parcels_.size());
    return result;
}

// Deposit as much of `parcel` as fits near (cx, cy); `merge` is a preferred
// Water cell (a liquid-surface entry). Returns true when nothing remains.
bool World::deposit_ballistic_parcel(BallisticParcel& parcel, std::int64_t cx, std::int64_t cy,
                                     const std::pair<std::int64_t, std::int64_t>* merge) {
    auto& l = ballistic_ledger_;
    const auto maximum = config_.water_experiment_policy.maximum();
    const bool whole = whole_cell_water_enabled();
    const bool inertial_water = inertial_family(Material::Water);
    std::uint32_t remaining = parcel.quantity;
    const auto try_cell = [&](std::int64_t tx, std::int64_t ty) {
        if (remaining == 0U || transient_obstacle_at(tx, ty) != 0U) return;
        const auto target = address(tx, ty);
        const auto* chunk = find_chunk(target.chunk);
        if (chunk == nullptr) return;
        const auto& cell = chunk->cells[target.index];
        const auto material = cell.material_value();
        std::uint32_t amount = 0;
        std::uint16_t after = 0;
        if (material == Material::Empty) {
            if (whole) amount = remaining == maximum ? remaining : 0U;
            else amount = std::min<std::uint32_t>(remaining, maximum);
            after = static_cast<std::uint16_t>(amount);
        } else if (material == Material::Water && !whole) {
            const auto mass = cell.state_a_value();
            amount = std::min<std::uint32_t>(remaining, static_cast<std::uint32_t>(maximum - mass));
            after = static_cast<std::uint16_t>(mass + amount);
        }
        if (amount == 0U) return;
        ballistic_write_water(tx, ty, after);
        if (material == Material::Empty && inertial_water) {
            // Hybrid handoff: the new IN carrier retains the parcel's momentum
            // (q256 -> q16 per cell); v1 may not hold upward velocity.
            auto* target_chunk = find_chunk(target.chunk);
            auto& slot = (*target_chunk->inertial)[target.index];
            const auto vmax = InertialParameters::kVmax;
            const auto ivx = std::clamp<std::int32_t>(parcel.vx / 16, -vmax, vmax);
            const auto ivy = std::clamp<std::int32_t>(parcel.vy / 16, inertial_parameters_.signed_vertical ? -vmax : 0, vmax);
            if (ivx != 0 || ivy != 0) {
                inertial_ledger_.external_speed += std::abs(ivx) + std::abs(ivy);
                inertial_ledger_.external_x += ivx;
                inertial_ledger_.external_y += ivy;
                slot.vx = static_cast<std::int16_t>(ivx);
                slot.vy = static_cast<std::int16_t>(ivy);
            }
        }
        remaining -= amount;
        ++l.deposit_writes;
        quantity_.water_ballistic -= amount;
        l.deposited_quantity += amount;
        l.deposit_px += ballistic_checked_product(amount, parcel.vx);
        l.deposit_py += ballistic_checked_product(amount, parcel.vy);
    };
    if (merge != nullptr) try_cell(merge->first, merge->second);
    const auto radius = config_.ballistic_water.deposit_radius;
    for (const auto& offset : kBallisticDepositOrder) {
        if (remaining == 0U) break;
        if (std::abs(offset[0]) > radius || std::abs(offset[1]) > radius) continue;
        try_cell(cx + offset[0], cy + offset[1]);
    }
    parcel.quantity = remaining;
    if (remaining == 0U) {
        ++l.deposited_parcels;
        return true;
    }
    ++l.deferred_deposits;
    if (parcel.deferrals < 255U) ++parcel.deferrals;
    return false;
}

void World::advance_ballistic_water() {
    if (!config_.ballistic_water.enabled || ballistic_parcels_.empty()) return;
    std::size_t index = 0;
    while (index < ballistic_parcels_.size()) {
        if (step_ballistic_parcel(ballistic_parcels_[index])) {
            ballistic_parcels_[index] = ballistic_parcels_.back();
            ballistic_parcels_.pop_back();
        } else {
            ++index;
        }
    }
}

bool World::step_ballistic_parcel(BallisticParcel& p) {
    const auto& c = config_.ballistic_water;
    auto& l = ballistic_ledger_;
    ++p.age;
    ++l.parcel_ticks;
    const auto q = static_cast<std::int64_t>(p.quantity);
    // Gravity, drag and saturation; each term is booked separately and exactly.
    p.vy += c.gravity_q;
    l.gravity_py += ballistic_checked_product(q, c.gravity_q);
    {
        const auto dx = -ballistic_scale(p.vx, c.air_drag), dy = -ballistic_scale(p.vy, c.air_drag);
        p.vx += dx;
        p.vy += dy;
        l.drag_px += ballistic_checked_product(q, dx);
        l.drag_py += ballistic_checked_product(q, dy);
    }
    {
        const auto cx = std::clamp(p.vx, -c.max_speed_q, c.max_speed_q);
        const auto cy = std::clamp(p.vy, -c.max_speed_q, c.max_speed_q);
        l.clamp_px += ballistic_checked_product(q, cx - p.vx);
        l.clamp_py += ballistic_checked_product(q, cy - p.vy);
        p.vx = cx;
        p.vy = cy;
    }
    // Swept travel, at most one cell per axis per substep. A blocked step
    // resolves its contact normal from the axis-separated neighbours.
    const auto x0 = p.x, y0 = p.y;
    const auto xe = x0 + p.vx, ye = y0 + p.vy;
    auto cx = ballistic_cell(x0), cy = ballistic_cell(y0);
    const auto steps = std::max(std::abs(ballistic_cell(xe) - cx), std::abs(ballistic_cell(ye) - cy));
    bool contact = false;
    bool surface = false;
    std::pair<std::int64_t, std::int64_t> surface_cell{};
    if (steps == 0) {
        p.x = xe;
        p.y = ye;
    }
    for (std::int64_t k = 1; k <= steps && !contact && !surface; ++k) {
        const auto tx = x0 + (xe - x0) * k / steps;
        const auto ty = y0 + (ye - y0) * k / steps;
        const auto ncx = ballistic_cell(tx), ncy = ballistic_cell(ty);
        if (ncx == cx && ncy == cy) { p.x = tx; p.y = ty; continue; }
        std::uint16_t body = 0;
        const auto kind = classify_ballistic_cell(ncx, ncy, p, body);
        if (kind == BallisticCell::Free) {
            p.x = tx;
            p.y = ty;
            cx = ncx;
            cy = ncy;
            ++l.cell_steps;
            continue;
        }
        if (kind == BallisticCell::Water) {
            surface = true;
            surface_cell = {ncx, ncy};
            ++l.surface_entries;
            break;
        }
        const auto dcx = ncx - cx, dcy = ncy - cy;
        bool hit_x = dcx != 0 && dcy == 0;
        bool hit_y = dcy != 0 && dcx == 0;
        if (dcx != 0 && dcy != 0) {
            std::uint16_t ignored = 0;
            hit_x = classify_ballistic_cell(cx + dcx, cy, p, ignored) != BallisticCell::Free;
            hit_y = classify_ballistic_cell(cx, cy + dcy, p, ignored) != BallisticCell::Free;
            if (!hit_x && !hit_y) hit_x = hit_y = true;
        }
        const auto before_x = p.vx, before_y = p.vy;
        if (hit_y) {
            p.vy = -ballistic_scale(p.vy, c.restitution);
            if (!hit_x) p.vx = ballistic_scale(p.vx, c.friction);
            if (dcy < 0) ++l.ceiling_contacts;
        }
        if (hit_x) {
            p.vx = -ballistic_scale(p.vx, c.restitution);
            if (!hit_y) p.vy = ballistic_scale(p.vy, c.friction);
        }
        const auto dpx = ballistic_checked_product(q, p.vx - before_x);
        const auto dpy = ballistic_checked_product(q, p.vy - before_y);
        l.contact_px += dpx;
        l.contact_py += dpy;
        if (kind == BallisticCell::Body) {
            ++l.body_contacts;
            l.body_px += dpx;
            l.body_py += dpy;
            ballistic_body_px_[body] -= dpx;
            ballistic_body_py_[body] -= dpy;
        } else if (kind == BallisticCell::Outside) {
            ++l.boundary_contacts;
        } else {
            ++l.terrain_contacts;
        }
        // Stay inside the last free cell, at the sub-cell point nearest the contact.
        p.x = std::clamp(tx, cx * kBallisticQ, cx * kBallisticQ + kBallisticQ - 1);
        p.y = std::clamp(ty, cy * kBallisticQ, cy * kBallisticQ + kBallisticQ - 1);
        if (p.contacts < 255U) ++p.contacts;
        contact = true;
    }
    if (surface) return deposit_ballistic_parcel(p, cx, cy, &surface_cell);
    const auto speed = std::abs(p.vx) + std::abs(p.vy);
    if (contact && (speed <= c.settle_speed_q || p.contacts > c.maximum_contacts))
        return deposit_ballistic_parcel(p, cx, cy, nullptr);
    if (p.age >= c.maximum_age_ticks) {
        ++l.forced_deposits;
        return deposit_ballistic_parcel(p, cx, cy, nullptr);
    }
    return false;
}

void World::validate_ballistic_ledger() const {
    if (!config_.ballistic_water.enabled) {
        if (!ballistic_parcels_.empty() || quantity_.water_ballistic != 0U)
            throw std::invalid_argument("ballistic Water present in a disabled World");
        return;
    }
    const auto& l = ballistic_ledger_;
    std::uint64_t quantity = 0;
    std::int64_t px = 0, py = 0;
    for (const auto& p : ballistic_parcels_) {
        if (p.quantity == 0U || p.quantity > config_.water_experiment_policy.maximum() ||
            std::abs(p.vx) > config_.ballistic_water.max_speed_q || std::abs(p.vy) > config_.ballistic_water.max_speed_q)
            throw std::invalid_argument("ballistic parcel outside its state domain");
        quantity += p.quantity;
        px += static_cast<std::int64_t>(p.quantity) * p.vx;
        py += static_cast<std::int64_t>(p.quantity) * p.vy;
    }
    if (ballistic_parcels_.size() > config_.ballistic_water.capacity)
        throw std::invalid_argument("ballistic parcel capacity exceeded");
    if (quantity != quantity_.water_ballistic ||
        l.launched_quantity + l.injected_quantity != l.deposited_quantity + quantity)
        throw std::invalid_argument("ballistic Water quantity ledger does not close");
    if (px != l.launch_px + l.drag_px + l.contact_px + l.clamp_px - l.deposit_px ||
        py != l.launch_py + l.gravity_py + l.drag_py + l.contact_py + l.clamp_py - l.deposit_py)
        throw std::invalid_argument("ballistic Water momentum ledger does not close");
}

void World::overlay_ballistic_render(RectI64 region, std::span<std::uint8_t> destination,
                                     std::size_t stride_bytes, std::size_t bytes_per_cell) const noexcept {
    // Presentation derives from owned parcel state only; authority is untouched.
    for (const auto& p : ballistic_parcels_) {
        const auto x = ballistic_cell(p.x), y = ballistic_cell(p.y);
        if (x < region.x || y < region.y || x >= region.x + region.width || y >= region.y + region.height) continue;
        const auto offset = static_cast<std::size_t>(y - region.y) * stride_bytes +
                            static_cast<std::size_t>(x - region.x) * bytes_per_cell;
        if (offset + bytes_per_cell > destination.size()) continue;
        if (destination[offset] != static_cast<std::uint8_t>(Material::Empty)) continue;
        destination[offset] = static_cast<std::uint8_t>(Material::Water);
        if (bytes_per_cell > 1U) destination[offset + 1U] = 255U;
    }
}
