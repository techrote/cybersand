// Included by world.cpp after World/Chunk definitions, inside cybersand.
// All entry points require the SAME exclusive external native owner as tick().
namespace solid_detail {
bool valid_bounds(soliding::SolidBounds b) noexcept {
    return b.width != 0 && b.height != 0 &&
        b.x <= std::numeric_limits<std::int64_t>::max() - (b.width - 1) &&
        b.y <= std::numeric_limits<std::int64_t>::max() - (b.height - 1);
}
bool contains(soliding::SolidBounds b, std::int64_t x, std::int64_t y) noexcept {
    // Checked endpoints avoid signed subtraction overflow at far coordinates.
    return valid_bounds(b) && x >= b.x && y >= b.y &&
        x <= b.x + b.width - 1 && y <= b.y + b.height - 1;
}
bool cohesive(Material m) noexcept {
    // Deliberately narrow inert slice. Wood/bark and reactive states need their
    // own continuing material-work policy while aggregate-owned.
    return m == Material::Wall || m == Material::RedBrick;
}
bool fenced(soliding::SolidPhase phase) noexcept {
    return phase == soliding::SolidPhase::Prepared ||
        phase == soliding::SolidPhase::Acknowledged ||
        phase == soliding::SolidPhase::Committed ||
        phase == soliding::SolidPhase::Restored ||
        phase == soliding::SolidPhase::Quarantined;
}
} // namespace solid_detail

bool World::solid_detachment_fenced() const noexcept {
    return solid_detachment_ != nullptr &&
        solid_detail::fenced(solid_detachment_->snapshot.phase);
}

void World::require_solid_mutation_allowed() const {
    if (solid_detachment_fenced())
        throw std::logic_error("native mutation/tick fenced by solid detachment; finish or cancel its owner transaction");
}

soliding::SolidOutcome World::configure_solid_detachment(soliding::SolidLimits limits) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (tick_in_progress_ || (solid_detachment_ &&
        solid_detachment_->snapshot.phase != SolidPhase::Idle)) return SolidOutcome::Busy;
    if (limits.members == 0 || limits.members > kSolidMembers ||
        limits.shapes == 0 || limits.shapes > kSolidShapes) return SolidOutcome::Invalid;
    if (pressure_ != nullptr || inertial_enabled_) return SolidOutcome::Ineligible;
    // Failure before swap leaves any prior idle configuration untouched.
    auto candidate = std::make_unique<SolidStore>();
    candidate->limits = limits;
    candidate->snapshot.token.incarnation = allocate_discovery_incarnation();
    candidate->snapshot.phase = SolidPhase::Idle;
    solid_detachment_ = std::move(candidate);
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::prepare_solid_detachment(const soliding::SolidRequest& request) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!solid_detachment_) return SolidOutcome::Disabled;
    auto& store = *solid_detachment_;
    auto& out = store.snapshot;
    if (tick_in_progress_ || out.phase != SolidPhase::Idle) return SolidOutcome::Busy;
    if (store.serial == std::numeric_limits<std::uint64_t>::max())
        return SolidOutcome::GenerationExhausted;
    const auto domain = request.domain;
    if (!solid_detail::valid_bounds(domain) || !solid_detail::valid_bounds(request.anchors) ||
        domain.width > kSolidDomainSide || domain.height > kSolidDomainSide ||
        !solid_detail::contains(domain, request.seed_x, request.seed_y)) return SolidOutcome::Invalid;
    if (pressure_ != nullptr || inertial_enabled_) return SolidOutcome::Ineligible;
    if (!pending_explosions_.empty()) return SolidOutcome::PendingEvent;
    if (selected_core_region_ != applied_core_region_) return SolidOutcome::Excluded;
    const auto incarnation = out.token.incarnation;
    out = {};
    out.phase = SolidPhase::Idle;
    out.token.incarnation = incarnation;
    out.domain = domain;
    store.seen.fill(false);
    // No new residency is manufactured by observation. A not-resident cell is
    // unknown, never a proof of air or a disconnected support boundary.
    for (std::int64_t dy = 0; dy < domain.height; ++dy) {
        for (std::int64_t dx = 0; dx < domain.width; ++dx) {
            const auto x = domain.x + dx, y = domain.y + dy;
            if (find_chunk(address(x, y).chunk) == nullptr) return SolidOutcome::NotResident;
            if (selected_core_region_) {
                const auto core = scheduler_geometry_.core_for_cell(x, y);
                const auto& included = *selected_core_region_;
                if (core.x < included.min_x || core.x > included.max_x ||
                    core.y < included.min_y || core.y > included.max_y) return SolidOutcome::Excluded;
            }
        }
    }
    const auto material = stored_material(request.seed_x, request.seed_y);
    if (!solid_detail::cohesive(material)) return SolidOutcome::Ineligible;
    const auto local_index = [domain](std::int64_t x, std::int64_t y) {
        return static_cast<std::size_t>(y - domain.y) * domain.width +
            static_cast<std::size_t>(x - domain.x);
    };
    std::size_t head = 0, tail = 1;
    const auto seed = local_index(request.seed_x, request.seed_y);
    store.queue[0] = static_cast<std::uint16_t>(seed);
    store.seen[seed] = true;
    const auto refuse = [&out](SolidOutcome reason) {
        out.member_count = 0;
        out.shape_count = 0;
        return reason;
    };
    constexpr std::array<std::array<std::int64_t, 2>, 4> offsets{{
        {{0, -1}}, {{-1, 0}}, {{1, 0}}, {{0, 1}}
    }};
    while (head < tail) {
        const auto index = static_cast<std::size_t>(store.queue[head++]);
        const auto lx = index % domain.width, ly = index / domain.width;
        const auto x = domain.x + static_cast<std::int64_t>(lx);
        const auto y = domain.y + static_cast<std::int64_t>(ly);
        ++out.inspected_cells;
        if (solid_detail::contains(request.anchors, x, y)) return refuse(SolidOutcome::Anchored);
        if (transient_obstacle_at(x, y) != 0) return refuse(SolidOutcome::Occupied);
        if (stored_temperature(x, y) != config_.ambient_temperature)
            return refuse(SolidOutcome::Thermal);
        // Reaching the scope boundary cannot establish loss of attachment.
        if (lx == 0 || ly == 0 || lx + 1 == domain.width || ly + 1 == domain.height)
            return refuse(SolidOutcome::UnknownBoundary);
        if (out.member_count == store.limits.members) return refuse(SolidOutcome::MemberCapacity);
        store.members[out.member_count++] = {
            x, y, material, stored_state_a(x, y), stored_state_b(x, y), stored_temperature(x, y)
        };
        for (const auto& offset : offsets) {
            ++out.neighbour_probes;
            const auto nx = x + offset[0], ny = y + offset[1];
            if (transient_obstacle_at(nx, ny) != 0) return refuse(SolidOutcome::Occupied);
            const auto neighbour = stored_material(nx, ny);
            if (neighbour == Material::Empty) continue;
            if (solid_detail::contains(request.anchors, nx, ny) &&
                MaterialRules::is_hard_surface(neighbour)) return refuse(SolidOutcome::Anchored);
            // Explicit noncohesive boundary policy: ambient Sand and ordinary
            // FreeMass Water stay native contact material. They neither join
            // the component nor prove a structural anchor. Dynamic contact
            // resistance/displacement remains owned by the existing coupling.
            // Unsupported/reactive/thermal contacts remain uncertain and refuse.
            if (neighbour == Material::Sand ||
                (neighbour == Material::Water && !water_cellular_yield_)) {
                if (stored_temperature(nx, ny) != config_.ambient_temperature)
                    return refuse(SolidOutcome::Thermal);
                continue;
            }
            if (neighbour != material) return refuse(SolidOutcome::Ineligible);
            const auto ni = local_index(nx, ny);
            if (!store.seen[ni]) {
                if (tail == store.queue.size()) return refuse(SolidOutcome::MemberCapacity);
                store.seen[ni] = true;
                store.queue[tail++] = static_cast<std::uint16_t>(ni);
            }
        }
    }
    std::sort(store.members.begin(), store.members.begin() + static_cast<std::ptrdiff_t>(out.member_count),
        [](const SolidMember& a, const SolidMember& b) { return a.y < b.y || (a.y == b.y && a.x < b.x); });
    // Exact horizontal runs, vertically merged only for identical spans.
    for (std::size_t i = 0; i < out.member_count;) {
        const auto first = store.members[i];
        std::size_t end = i + 1;
        while (end < out.member_count && store.members[end].y == first.y &&
            store.members[end].x == store.members[end - 1].x + 1) ++end;
        const auto width = static_cast<std::uint16_t>(end - i);
        std::size_t match = out.shape_count;
        for (std::size_t j = 0; j < out.shape_count; ++j) {
            const auto& shape = store.shapes[j];
            if (shape.x == first.x && shape.width == width &&
                shape.y + shape.height == first.y) { match = j; break; }
        }
        if (match < out.shape_count) ++store.shapes[match].height;
        else {
            if (out.shape_count == store.limits.shapes) return refuse(SolidOutcome::ShapeCapacity);
            store.shapes[out.shape_count++] = {first.x, first.y, width, 1};
        }
        i = end;
    }
    out.mass = static_cast<double>(out.member_count);
    out.payload_digest = 1469598103934665603ULL;
    out.shape_digest = 1469598103934665603ULL;
    for (std::size_t i = 0; i < out.member_count; ++i) {
        const auto& m = store.members[i];
        out.com_x += static_cast<double>(m.x - domain.x) + 0.5;
        out.com_y += static_cast<double>(m.y - domain.y) + 0.5;
        hash_integer(out.payload_digest, m.x); hash_integer(out.payload_digest, m.y);
        hash_integer(out.payload_digest, static_cast<std::uint8_t>(m.material));
        hash_integer(out.payload_digest, m.state_a); hash_integer(out.payload_digest, m.state_b);
        hash_integer(out.payload_digest, m.temperature);
    }
    out.com_x /= out.mass; out.com_y /= out.mass;
    for (std::size_t i = 0; i < out.member_count; ++i) {
        const auto& m = store.members[i];
        const double dx = static_cast<double>(m.x - domain.x) + 0.5 - out.com_x;
        const double dy = static_cast<double>(m.y - domain.y) + 0.5 - out.com_y;
        out.inertia += dx * dx + dy * dy + 1.0 / 6.0;
    }
    for (std::size_t i = 0; i < out.shape_count; ++i) {
        const auto& shape = store.shapes[i];
        hash_integer(out.shape_digest, shape.x); hash_integer(out.shape_digest, shape.y);
        hash_integer(out.shape_digest, shape.width); hash_integer(out.shape_digest, shape.height);
    }
    // Reserve revision room for BOTH commit and a failed-body rollback.
    if (hard_surface_revision_ > std::numeric_limits<std::uint64_t>::max() - 2U * out.member_count)
        return refuse(SolidOutcome::GenerationExhausted);
    out.source_tick = tick_index_;
    out.source_terrain_revision = hard_surface_revision_;
    out.token.sequence = ++store.serial;
    out.phase = SolidPhase::Prepared; // Native mutation/ticks now refuse.
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::acknowledge_solid_detachment(const soliding::SolidBodyReservation& body) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!solid_detachment_) return SolidOutcome::Disabled;
    auto& s = solid_detachment_->snapshot;
    if (s.phase != SolidPhase::Prepared || body.token != s.token) return SolidOutcome::Stale;
    if (body.body_id == 0 || body.body_id > kMaximumTransientBodies || body.body_generation == 0 ||
        body.shape_count > static_cast<std::size_t>(kMaximumTransientBodies - body.body_id + 1U) ||
        body.shape_count != s.shape_count || body.payload_digest != s.payload_digest ||
        body.shape_digest != s.shape_digest) return SolidOutcome::Invalid;
    s.body_id = body.body_id;
    s.body_generation = body.body_generation;
    s.phase = SolidPhase::Acknowledged;
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::commit_solid_detachment(soliding::SolidToken token) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!solid_detachment_) return SolidOutcome::Disabled;
    auto& store = *solid_detachment_;
    auto& s = store.snapshot;
    if (s.phase != SolidPhase::Acknowledged || token != s.token) return SolidOutcome::Stale;
    if (tick_in_progress_ || s.source_tick != tick_index_ ||
        s.source_terrain_revision != hard_surface_revision_ || !pending_explosions_.empty())
        return SolidOutcome::Stale;
    for (std::size_t i = 0; i < s.member_count; ++i) {
        const auto& m = store.members[i];
        if (transient_obstacle_at(m.x, m.y) != 0 || stored_material(m.x, m.y) != m.material ||
            stored_state_a(m.x, m.y) != m.state_a || stored_state_b(m.x, m.y) != m.state_b ||
            stored_temperature(m.x, m.y) != m.temperature) return SolidOutcome::Stale;
    }
    // Existing resident inert cells, ambient thermal state, fixed metadata.
    // No material authority is moved before every source/resource check passes.
    try {
        for (std::size_t i = 0; i < s.member_count; ++i) {
            const auto& m = store.members[i];
            if (!write_cell(m.x, m.y, Material::Empty, 0, 0, nullptr, true))
                throw std::logic_error("solid source unexpectedly refused retirement");
            ++s.aggregate_owned_count;
        }
    } catch (...) {
        // Preserve diagnostic exact prefix ownership; never silently retry a
        // partial handoff or activate a body after an unexpected native failure.
        s.aggregate_owned_count = 0;
        for (std::size_t i = 0; i < s.member_count; ++i)
            if (stored_material(store.members[i].x, store.members[i].y) == Material::Empty)
                ++s.aggregate_owned_count;
        s.phase = SolidPhase::Quarantined;
        tick_failed_ = true;
        if (settled_discovery_) settled_discovery_->fail();
        return SolidOutcome::Quarantined;
    }
    s.committed_terrain_revision = hard_surface_revision_;
    s.phase = SolidPhase::Committed; // Native AND main-thread physics stay fenced.
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::finalize_solid_detachment(const soliding::SolidCollisionReceipt& receipt) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!solid_detachment_) return SolidOutcome::Disabled;
    auto& s = solid_detachment_->snapshot;
    if (s.phase != SolidPhase::Committed || receipt.token != s.token ||
        receipt.body_id != s.body_id || receipt.body_generation != s.body_generation ||
        receipt.terrain_revision != s.committed_terrain_revision ||
        receipt.terrain_revision != hard_surface_revision_ || s.source_tick != tick_index_ ||
        receipt.physics_epoch == 0)
        return SolidOutcome::Stale;
    s.physics_epoch = receipt.physics_epoch;
    s.phase = SolidPhase::Active;
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::cancel_solid_detachment(soliding::SolidToken token) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!solid_detachment_) return SolidOutcome::Disabled;
    auto& s = solid_detachment_->snapshot;
    if (token != s.token || (s.phase != SolidPhase::Prepared && s.phase != SolidPhase::Acknowledged))
        return SolidOutcome::Stale;
    const auto incarnation = s.token.incarnation;
    s = {}; s.phase = SolidPhase::Idle; s.token.incarnation = incarnation;
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::rollback_solid_detachment(soliding::SolidToken token) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!solid_detachment_) return SolidOutcome::Disabled;
    auto& store = *solid_detachment_;
    auto& s = store.snapshot;
    // This is cancellation of an INACTIVE staged body, not arbitrary dynamic
    // desoliding. The main-thread gate must remain held through terrain repair.
    if (token != s.token || s.phase != SolidPhase::Committed) return SolidOutcome::Stale;
    if (hard_surface_revision_ > std::numeric_limits<std::uint64_t>::max() - s.member_count)
        return SolidOutcome::GenerationExhausted;
    for (std::size_t i = 0; i < s.member_count; ++i) {
        const auto& m = store.members[i];
        if (stored_material(m.x, m.y) != Material::Empty || stored_state_a(m.x, m.y) != 0 ||
            stored_state_b(m.x, m.y) != 0 || stored_temperature(m.x, m.y) != m.temperature ||
            transient_obstacle_at(m.x, m.y) != 0) return SolidOutcome::Stale;
    }
    try {
        for (std::size_t i = 0; i < s.member_count; ++i) {
            const auto& m = store.members[i];
            if (!write_cell(m.x, m.y, m.material, m.state_a, m.state_b, nullptr, true))
                throw std::logic_error("solid source unexpectedly refused restoration");
            --s.aggregate_owned_count;
        }
    } catch (...) {
        s.aggregate_owned_count = 0;
        for (std::size_t i = 0; i < s.member_count; ++i)
            if (stored_material(store.members[i].x, store.members[i].y) == Material::Empty)
                ++s.aggregate_owned_count;
        s.phase = SolidPhase::Quarantined; tick_failed_ = true;
        if (settled_discovery_) settled_discovery_->fail();
        return SolidOutcome::Quarantined;
    }
    s.committed_terrain_revision = hard_surface_revision_;
    s.phase = SolidPhase::Restored; // Keep native fence until old terrain is repaired.
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::complete_solid_rollback(const soliding::SolidCollisionReceipt& receipt) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!solid_detachment_) return SolidOutcome::Disabled;
    auto& s = solid_detachment_->snapshot;
    if (s.phase != SolidPhase::Restored || receipt.token != s.token ||
        receipt.body_id != s.body_id || receipt.body_generation != s.body_generation ||
        receipt.terrain_revision != s.committed_terrain_revision ||
        receipt.terrain_revision != hard_surface_revision_ || receipt.physics_epoch == 0)
        return SolidOutcome::Stale;
    const auto incarnation = s.token.incarnation;
    s = {}; s.phase = SolidPhase::Idle; s.token.incarnation = incarnation;
    return SolidOutcome::Accepted;
}

std::size_t World::solid_detachment_storage_bytes() const noexcept {
    return solid_detachment_ ? sizeof(soliding::SolidStore) : 0;
}

soliding::SolidSnapshot World::inspect_solid_detachment() const noexcept {
    return solid_detachment_ ? solid_detachment_->snapshot : soliding::SolidSnapshot{};
}
std::size_t World::copy_solid_detachment_members(std::span<soliding::SolidMember> output) const noexcept {
    if (!solid_detachment_) return 0;
    const auto count = solid_detachment_->snapshot.member_count;
    if (output.size() >= count) std::copy_n(solid_detachment_->members.begin(), count, output.begin());
    return count;
}
std::size_t World::copy_solid_detachment_shapes(std::span<soliding::SolidShape> output) const noexcept {
    if (!solid_detachment_) return 0;
    const auto count = solid_detachment_->snapshot.shape_count;
    if (output.size() >= count) std::copy_n(solid_detachment_->shapes.begin(), count, output.begin());
    return count;
}
