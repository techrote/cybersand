// Included by world.cpp only, after world_ballistic.inc. BS-001
// ballistic_solids_v1: a bounded, serialized owner for whole solid/powder cells
// in flight (see cybersand/ballistic_solids.hpp). Solids advance once per tick
// at tick entry, after ballistic Water, in slot order, independent of worker
// count. Launch and landing are exact cell transfers; injection creates a cell
// from an external stock (counted as `injected`).

void World::validate_ballistic_solids_config() const {
    const auto& c = config_.ballistic_solids;
    if (!c.enabled) return;
    if (!config_.ballistic_water.enabled)
        throw std::invalid_argument("ballistic_solids_v1 requires ballistic_water_v1 in the same World");
    if (c.capacity == 0U || c.capacity > BallisticSolidsConfig::kMaximumCapacity ||
        c.gravity_q < 0 || c.gravity_q > 256 || c.max_speed_q < 64 || c.max_speed_q > 8 * kBallisticQ ||
        c.air_drag < 0 || c.air_drag > 64 || c.restitution < 0 || c.restitution > 256 ||
        c.friction < 0 || c.friction > 256 || c.settle_speed_q < 0 || c.settle_speed_q > c.max_speed_q ||
        c.maximum_age_ticks == 0U || c.maximum_age_ticks > 1'000'000U || c.maximum_contacts > 32U)
        throw std::invalid_argument("ballistic_solids_v1 configuration outside its admitted envelope");
}

BallisticSolidsSnapshot World::ballistic_solids_snapshot() const noexcept {
    BallisticSolidsSnapshot out;
    out.enabled = config_.ballistic_solids.enabled;
    out.capacity = out.enabled ? config_.ballistic_solids.capacity : 0U;
    out.live = static_cast<std::uint32_t>(ballistic_solids_.size());
    out.ledger = ballistic_solids_ledger_;
    out.last_advance_nanoseconds = ballistic_solids_advance_nanoseconds_;
    return out;
}

std::size_t World::copy_ballistic_solids(std::span<BallisticSolid> output) const noexcept {
    const auto count = std::min(output.size(), ballistic_solids_.size());
    std::copy_n(ballistic_solids_.begin(), count, output.begin());
    return ballistic_solids_.size();
}

void World::reset_ballistic_solids() noexcept {
    ballistic_solids_.clear();
    ballistic_solids_ledger_ = {};
}

// One exact cell transfer between Empty and an admitted material. Population
// accounting, pressure topology, IN storage, activity and discovery follow the
// same rules as every other serialized external write; no quantity flows.
void World::ballistic_write_solid(std::int64_t x, std::int64_t y, Material material,
                                  std::uint16_t state_a, std::uint8_t state_b) {
    const auto target = address(x, y);
    auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr) throw std::logic_error("ballistic solid transfer reached a non-resident chunk");
    auto& cell = chunk->cells[target.index];
    const auto before = cell.material_value();
    if ((material == Material::Empty) == (before == Material::Empty) ||
        (before != Material::Empty && !ballistic_solid_admitted(before)) ||
        (material != Material::Empty && !ballistic_solid_admitted(material)))
        throw std::logic_error("ballistic solid transfer outside Empty <-> admitted solid");
    if (chunk->granular_arrivals) (*chunk->granular_arrivals)[target.index] = 0;
    record_quantity_transition(before, 0, 0, material, 0, 0, nullptr, {}, false);
    if (chunk->pressure != nullptr) reset_pressure_cell(*chunk, target.index, before, material, true, nullptr);
    if (chunk->inertial != nullptr) retire_inertial_cell(*chunk, target.index, nullptr);
    const bool hard_surface_changed =
        MaterialRules::is_hard_surface(before) != MaterialRules::is_hard_surface(material);
    cell = Chunk::Cell::for_material(material);
    if (material != Material::Empty) {
        cell.set_state_a(state_a);
        cell.set_state_b(state_b);
    }
    cell.set_epoch(update_epoch_);
    chunk->non_empty_cell_count = static_cast<std::size_t>(
        static_cast<std::int64_t>(chunk->non_empty_cell_count) + (material == Material::Empty ? -1 : 1));
    invalidate_pressure_input(target.chunk, target.local_x, target.local_y, target.local_x, target.local_y, true);
    chunk->changed_this_tick = true;
    mark_cell_dirty(*chunk, target.local_x, target.local_y);
    wake_cell_neighborhood(x, y);
    if (hard_surface_changed) {
        mark_hard_surface_dirty(target);
        ++hard_surface_revision_;
    }
    dirty_discovery_cell(x, y, soliding::ProducerReason::DirectMutation);
}

World::BallisticCell World::classify_ballistic_solid_cell(std::int64_t x, std::int64_t y,
        const BallisticSolid& solid, std::uint16_t& body) const noexcept {
    body = 0;
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr) return BallisticCell::Outside;
    if (const auto id = transient_obstacle_at(x, y); id != 0U) {
        if (id == solid.source_body && solid.age <= BallisticWaterConfig::kSelfContactGraceTicks)
            return BallisticCell::Free;
        body = id;
        return BallisticCell::Body;
    }
    const auto material = chunk->cells[target.index].material_value();
    if (material == Material::Empty) return BallisticCell::Free;
    const auto state = MaterialRules::descriptor(material).state;
    if (state == MaterialState::Gas) return BallisticCell::Free;
    if (state == MaterialState::Liquid) return BallisticCell::Water;
    return BallisticCell::Solid;
}

BallisticLaunchResult World::admit_ballistic_solid_spawn(std::int64_t spawn_x, std::int64_t spawn_y,
        std::int32_t vx, std::int32_t vy, const std::pair<std::int64_t, std::int64_t>* source) const noexcept {
    BallisticLaunchResult result;
    const auto& c = config_.ballistic_solids;
    if (!c.enabled) { result.outcome = BallisticLaunchOutcome::Disabled; return result; }
    if (tick_failed_) { result.outcome = BallisticLaunchOutcome::WorldFailed; return result; }
    if (tick_in_progress_) { result.outcome = BallisticLaunchOutcome::TickInProgress; return result; }
    constexpr std::int64_t limit = std::int64_t{1} << 52;
    if (std::abs(vx) > c.max_speed_q || std::abs(vy) > c.max_speed_q || spawn_x < -limit || spawn_x > limit ||
        spawn_y < -limit || spawn_y > limit) {
        result.outcome = BallisticLaunchOutcome::InvalidRequest;
        return result;
    }
    if (ballistic_solids_.size() >= c.capacity) { result.outcome = BallisticLaunchOutcome::CapacityFull; return result; }
    const auto cx = ballistic_cell(spawn_x), cy = ballistic_cell(spawn_y);
    const auto* chunk = find_chunk(address(cx, cy).chunk);
    if (chunk == nullptr) { result.outcome = BallisticLaunchOutcome::NonResident; return result; }
    if (transient_obstacle_at(cx, cy) != 0U) { result.outcome = BallisticLaunchOutcome::Masked; return result; }
    const auto material = chunk->cells[address(cx, cy).index].material_value();
    const bool own_source = source != nullptr && source->first == cx && source->second == cy;
    if (!own_source && material != Material::Empty && MaterialRules::descriptor(material).state != MaterialState::Gas) {
        result.outcome = BallisticLaunchOutcome::InvalidRequest;
        return result;
    }
    result.outcome = BallisticLaunchOutcome::Launched;
    return result;
}

BallisticLaunchResult World::launch_ballistic_solid(std::int64_t source_x, std::int64_t source_y,
        std::int64_t spawn_x, std::int64_t spawn_y, std::int32_t vx, std::int32_t vy, std::uint16_t source_body) {
    const std::pair<std::int64_t, std::int64_t> source_cell{source_x, source_y};
    auto result = admit_ballistic_solid_spawn(spawn_x, spawn_y, vx, vy, &source_cell);
    result.live = static_cast<std::uint32_t>(ballistic_solids_.size());
    if (result.outcome == BallisticLaunchOutcome::CapacityFull) ++ballistic_solids_ledger_.refused_launches;
    if (result.outcome != BallisticLaunchOutcome::Launched) return result;
    if (source_body > kMaximumTransientBodies) { result.outcome = BallisticLaunchOutcome::InvalidRequest; return result; }
    const auto source = address(source_x, source_y);
    const auto* chunk = find_chunk(source.chunk);
    if (chunk == nullptr) { result.outcome = BallisticLaunchOutcome::NonResident; return result; }
    const auto& cell = chunk->cells[source.index];
    const auto material = cell.material_value();
    if (!ballistic_solid_admitted(material)) { result.outcome = BallisticLaunchOutcome::NotAdmitted; return result; }
    BallisticSolid solid;
    solid.x = spawn_x;
    solid.y = spawn_y;
    solid.vx = vx;
    solid.vy = vy;
    solid.material = static_cast<std::uint16_t>(material);
    solid.state_a = cell.state_a_value();
    solid.state_b = cell.state_b_value();
    solid.source_body = source_body;
    ballistic_write_solid(source_x, source_y, Material::Empty, 0, 0);
    ballistic_solids_.push_back(solid);
    mark_ballistic_render_dirty(ballistic_cell(spawn_x), ballistic_cell(spawn_y));
    auto& l = ballistic_solids_ledger_;
    ++l.launched;
    l.maximum_live = std::max<std::uint64_t>(l.maximum_live, ballistic_solids_.size());
    result.quantity = 1U;
    result.live = static_cast<std::uint32_t>(ballistic_solids_.size());
    return result;
}

BallisticLaunchResult World::inject_ballistic_solid(std::int64_t spawn_x, std::int64_t spawn_y,
        std::int32_t vx, std::int32_t vy, Material material) {
    auto result = admit_ballistic_solid_spawn(spawn_x, spawn_y, vx, vy);
    result.live = static_cast<std::uint32_t>(ballistic_solids_.size());
    if (result.outcome == BallisticLaunchOutcome::CapacityFull) ++ballistic_solids_ledger_.refused_launches;
    if (result.outcome != BallisticLaunchOutcome::Launched) return result;
    if (!ballistic_solid_admitted(material)) { result.outcome = BallisticLaunchOutcome::NotAdmitted; return result; }
    const auto& definition = MaterialRules::descriptor(material);
    BallisticSolid solid;
    solid.x = spawn_x;
    solid.y = spawn_y;
    solid.vx = vx;
    solid.vy = vy;
    solid.material = static_cast<std::uint16_t>(material);
    solid.state_a = definition.initial_state_a;
    solid.state_b = definition.initial_state_b;
    ballistic_solids_.push_back(solid);
    mark_ballistic_render_dirty(ballistic_cell(spawn_x), ballistic_cell(spawn_y));
    auto& l = ballistic_solids_ledger_;
    ++l.injected;
    l.maximum_live = std::max<std::uint64_t>(l.maximum_live, ballistic_solids_.size());
    result.quantity = 1U;
    result.live = static_cast<std::uint32_t>(ballistic_solids_.size());
    return result;
}

// Land near (cx, cy): the free cell itself first, then the BW-001 ring order.
// A solid that entered a liquid at (cx, cy) instead climbs that liquid column
// (<= 64 rows) to its free surface; native density exchange then sinks it.
bool World::land_ballistic_solid(BallisticSolid& solid, std::int64_t cx, std::int64_t cy, bool liquid) {
    auto& l = ballistic_solids_ledger_;
    const auto material = static_cast<Material>(solid.material);
    const auto free_at = [&](std::int64_t x, std::int64_t y) {
        if (transient_obstacle_at(x, y) != 0U) return false;
        const auto target = address(x, y);
        const auto* chunk = find_chunk(target.chunk);
        if (chunk == nullptr) return false;
        const auto m = chunk->cells[target.index].material_value();
        return m == Material::Empty;
    };
    const auto land = [&](std::int64_t x, std::int64_t y) {
        ballistic_write_solid(x, y, material, solid.state_a, solid.state_b);
        ++l.landed;
        return true;
    };
    if (liquid) {
        for (std::int64_t rise = 1; rise <= kBallisticColumnReach; ++rise) {
            const auto ty = cy - rise;
            if (transient_obstacle_at(cx, ty) != 0U) break;
            const auto target = address(cx, ty);
            const auto* chunk = find_chunk(target.chunk);
            if (chunk == nullptr) break;
            const auto m = chunk->cells[target.index].material_value();
            if (m == Material::Empty) { ++l.surface_landings; return land(cx, ty); }
            if (MaterialRules::descriptor(m).state != MaterialState::Liquid) break;
        }
    }
    for (const auto& offset : kBallisticDepositOrder) {
        const auto x = cx + offset[0], y = cy + offset[1];
        if (free_at(x, y)) return land(x, y);
    }
    // Moving powder can bury a resting solid (solids never occupy cells). A
    // buried solid climbs its own column through powders and liquids to the
    // first free cell (<= 64 rows); walls, structural solids and bodies stop it.
    for (std::int64_t rise = 1; rise <= kBallisticColumnReach; ++rise) {
        const auto ty = cy - rise;
        if (transient_obstacle_at(cx, ty) != 0U) break;
        const auto target = address(cx, ty);
        const auto* chunk = find_chunk(target.chunk);
        if (chunk == nullptr) break;
        const auto m = chunk->cells[target.index].material_value();
        if (m == Material::Empty) return land(cx, ty);
        const auto state = MaterialRules::descriptor(m).state;
        if (state != MaterialState::Powder && state != MaterialState::Liquid && state != MaterialState::Gas) break;
    }
    ++l.deferred_landings;
    if (solid.deferrals < 255U) ++solid.deferrals;
    return false;
}

void World::advance_ballistic_solids() {
    ballistic_solids_advance_nanoseconds_ = 0;
    if (!config_.ballistic_solids.enabled || ballistic_solids_.empty()) return;
    const auto started = std::chrono::steady_clock::now();
    std::size_t index = 0;
    while (index < ballistic_solids_.size()) {
        auto& solid = ballistic_solids_[index];
        mark_ballistic_render_dirty(ballistic_cell(solid.x), ballistic_cell(solid.y));
        if (step_ballistic_solid(solid)) {
            ballistic_solids_[index] = ballistic_solids_.back();
            ballistic_solids_.pop_back();
        } else {
            mark_ballistic_render_dirty(ballistic_cell(solid.x), ballistic_cell(solid.y));
            ++index;
        }
    }
    ballistic_solids_advance_nanoseconds_ = static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now() - started).count());
}

bool World::step_ballistic_solid(BallisticSolid& p) {
    const auto& c = config_.ballistic_solids;
    auto& l = ballistic_solids_ledger_;
    ++p.age;
    ++l.solid_ticks;
    p.vy += c.gravity_q;
    p.vx -= ballistic_scale(p.vx, c.air_drag);
    p.vy -= ballistic_scale(p.vy, c.air_drag);
    p.vx = std::clamp(p.vx, -c.max_speed_q, c.max_speed_q);
    p.vy = std::clamp(p.vy, -c.max_speed_q, c.max_speed_q);
    const auto x0 = p.x, y0 = p.y;
    const auto xe = x0 + p.vx, ye = y0 + p.vy;
    auto cx = ballistic_cell(x0), cy = ballistic_cell(y0);
    const auto steps = std::max(std::abs(ballistic_cell(xe) - cx), std::abs(ballistic_cell(ye) - cy));
    bool contact = false;
    if (steps == 0) {
        p.x = xe;
        p.y = ye;
    }
    for (std::int64_t k = 1; k <= steps && !contact; ++k) {
        const auto tx = x0 + (xe - x0) * k / steps;
        const auto ty = y0 + (ye - y0) * k / steps;
        const auto ncx = ballistic_cell(tx), ncy = ballistic_cell(ty);
        if (ncx == cx && ncy == cy) { p.x = tx; p.y = ty; continue; }
        std::uint16_t body = 0;
        const auto kind = classify_ballistic_solid_cell(ncx, ncy, p, body);
        if (kind == BallisticCell::Free) {
            p.x = tx;
            p.y = ty;
            cx = ncx;
            cy = ncy;
            ++l.cell_steps;
            continue;
        }
        if (kind == BallisticCell::Water) {
            // A solid reaching any liquid settles on its free surface.
            ++l.liquid_contacts;
            return land_ballistic_solid(p, ncx, ncy, true);
        }
        const auto dcx = ncx - cx, dcy = ncy - cy;
        bool hit_x = dcx != 0 && dcy == 0;
        bool hit_y = dcy != 0 && dcx == 0;
        if (dcx != 0 && dcy != 0) {
            std::uint16_t ignored = 0;
            hit_x = classify_ballistic_solid_cell(cx + dcx, cy, p, ignored) != BallisticCell::Free;
            hit_y = classify_ballistic_solid_cell(cx, cy + dcy, p, ignored) != BallisticCell::Free;
            if (!hit_x && !hit_y) hit_x = hit_y = true;
        }
        const auto before_x = p.vx, before_y = p.vy;
        const auto coulomb = [&](std::int32_t tangent, std::int32_t normal_impulse) {
            const auto loss = static_cast<std::int32_t>(static_cast<std::int64_t>(normal_impulse) * c.friction / 256);
            const auto magnitude = std::max(0, std::abs(tangent) - loss);
            return tangent < 0 ? -magnitude : magnitude;
        };
        std::int32_t normal_impulse = 0;
        if (hit_y) {
            p.vy = -ballistic_scale(p.vy, c.restitution);
            normal_impulse = std::abs(p.vy - before_y);
            if (!hit_x) p.vx = coulomb(p.vx, normal_impulse);
        }
        if (hit_x) {
            p.vx = -ballistic_scale(p.vx, c.restitution);
            normal_impulse = std::max(normal_impulse, std::abs(p.vx - before_x));
            if (!hit_y) p.vy = coulomb(p.vy, std::abs(p.vx - before_x));
        }
        if (kind == BallisticCell::Body) {
            const auto mass = ballistic_solid_mass(static_cast<Material>(p.material));
            const auto dpx = ballistic_checked_product(mass, p.vx - before_x);
            const auto dpy = ballistic_checked_product(mass, p.vy - before_y);
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
        p.x = std::clamp(tx, cx * kBallisticQ, cx * kBallisticQ + kBallisticQ - 1);
        p.y = std::clamp(ty, cy * kBallisticQ, cy * kBallisticQ + kBallisticQ - 1);
        if (normal_impulse > 3 * c.gravity_q && p.contacts < 255U) ++p.contacts;
        contact = true;
    }
    const auto speed = std::abs(p.vx) + std::abs(p.vy);
    if (contact && (speed <= c.settle_speed_q || p.contacts > c.maximum_contacts))
        return land_ballistic_solid(p, cx, cy, false);
    if (p.age >= c.maximum_age_ticks) {
        ++l.forced_landings;
        return land_ballistic_solid(p, cx, cy, false);
    }
    return false;
}

void World::validate_ballistic_solids_ledger() const {
    if (!config_.ballistic_solids.enabled) {
        if (!ballistic_solids_.empty()) throw std::invalid_argument("ballistic solids present in a disabled World");
        return;
    }
    const auto& l = ballistic_solids_ledger_;
    for (const auto& p : ballistic_solids_) {
        if (!ballistic_solid_admitted(static_cast<Material>(p.material)) ||
            std::abs(p.vx) > config_.ballistic_solids.max_speed_q || std::abs(p.vy) > config_.ballistic_solids.max_speed_q ||
            p.source_body > kMaximumTransientBodies)
            throw std::invalid_argument("ballistic solid outside its state domain");
    }
    if (ballistic_solids_.size() > config_.ballistic_solids.capacity)
        throw std::invalid_argument("ballistic solid capacity exceeded");
    if (l.launched + l.injected != l.landed + ballistic_solids_.size())
        throw std::invalid_argument("ballistic solids cell ledger does not close");
}

void World::overlay_ballistic_solids_render(RectI64 region, std::span<std::uint8_t> destination,
                                            std::size_t stride_bytes, std::size_t bytes_per_cell) const noexcept {
    // Presentation derives from owned solid state only; authority is untouched.
    for (const auto& p : ballistic_solids_) {
        const auto x = ballistic_cell(p.x), y = ballistic_cell(p.y);
        if (x < region.x || y < region.y || x >= region.x + region.width || y >= region.y + region.height) continue;
        const auto offset = static_cast<std::size_t>(y - region.y) * stride_bytes +
                            static_cast<std::size_t>(x - region.x) * bytes_per_cell;
        if (offset + bytes_per_cell > destination.size()) continue;
        if (destination[offset] != static_cast<std::uint8_t>(Material::Empty)) continue;
        const auto material = static_cast<Material>(p.material);
        destination[offset] = static_cast<std::uint8_t>(p.material);
        if (bytes_per_cell > 1U)
            destination[offset + 1U] = project_visual_state(material, p.state_a, p.state_b, config_.water_experiment_policy);
    }
}
