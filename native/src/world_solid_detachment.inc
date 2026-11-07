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
        phase == soliding::SolidPhase::DebrisCommitted ||
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
    if (workbench_solid_count()) return SolidOutcome::Busy;
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
    if (s.granular_piece) return SolidOutcome::Invalid;
    if (body.body_id == 0 || body.body_id > kMaximumTransientBodies || body.body_generation == 0 ||
        body.shape_count > static_cast<std::size_t>(kMaximumTransientBodies - body.body_id + 1U) ||
        body.shape_count != s.shape_count || body.payload_digest != s.payload_digest ||
        body.shape_digest != s.shape_digest) return SolidOutcome::Invalid;
    if (workbench_solids_) {
        if (workbench_solids_->count==kWorkbenchSolids) return SolidOutcome::MemberCapacity;
        std::size_t total_shapes=s.shape_count;
        for (std::size_t i=0;i<workbench_solids_->count;++i) {
            const auto& previous=workbench_solids_->owned[i].snapshot;
            total_shapes+=previous.shape_count;
            if (body.body_id<previous.body_id+previous.shape_count && previous.body_id<body.body_id+body.shape_count)
                return SolidOutcome::Occupied;
        }
        if (total_shapes>kWorkbenchSolidShapes) return SolidOutcome::ShapeCapacity;
    }
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
    return (solid_detachment_ ? sizeof(soliding::SolidStore) : 0) +
        (workbench_solids_ ? sizeof(soliding::SolidWorkbenchStore) : 0);
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

soliding::SolidOutcome World::configure_workbench_solids(soliding::SolidBounds canvas) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (tick_in_progress_ || solid_detachment_fenced()) return SolidOutcome::Busy;
    if (canvas.x != 0 || canvas.y != 0 || canvas.width < 512 || canvas.height < 512 ||
        canvas.width > 2048 || canvas.height > 2048) return SolidOutcome::Invalid;
    if (workbench_solids_) return workbench_solids_->canvas == canvas ? SolidOutcome::Accepted : SolidOutcome::Busy;
    if (solid_detachment_) return SolidOutcome::Busy;
    auto candidate = std::make_unique<SolidWorkbenchStore>();
    candidate->canvas = canvas;
    const auto result = configure_solid_detachment({kSolidMembers, kWorkbenchSolidShapes});
    if (result == SolidOutcome::Accepted) workbench_solids_ = std::move(candidate);
    return result;
}

soliding::SolidOutcome World::prepare_workbench_solid(std::int64_t x, std::int64_t y,
    std::size_t small_debris_limit) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!workbench_solids_) return SolidOutcome::Disabled;
    if (tick_in_progress_ || solid_detachment_->snapshot.phase != SolidPhase::Idle) return SolidOutcome::Busy;
    if (selected_core_region_ != applied_core_region_) return SolidOutcome::Excluded;
    auto& work = *workbench_solids_;
    work.inspected=work.probes=0;
    if (small_debris_limit!=0 && small_debris_limit!=kWorkbenchSmallDebrisCells) return SolidOutcome::Invalid;
    if (!small_debris_limit && work.count==kWorkbenchSolids) return SolidOutcome::MemberCapacity;
    if (!solid_detail::contains(work.canvas,x,y)) return SolidOutcome::Invalid;
    if (!contact_cell_available(x,y)) return SolidOutcome::NotResident;
    if (stored_material(x,y) != Material::RedBrick) return SolidOutcome::Ineligible;
    work.lookup.fill(-1);
    std::size_t head=0, tail=0;
    const auto add = [&](std::int64_t px,std::int64_t py) {
        const auto key = (static_cast<std::uint64_t>(px)*0x9e3779b185ebca87ULL ^
            static_cast<std::uint64_t>(py)*0xc2b2ae3d27d4eb4fULL) % kSolidDomainCells;
        auto bucket=static_cast<std::size_t>(key);
        while (work.lookup[bucket] >= 0) {
            if (work.queue[static_cast<std::size_t>(work.lookup[bucket])] == std::array<std::int64_t,2>{px,py}) return true;
            bucket=(bucket+1)%kSolidDomainCells;
        }
        if (tail == kSolidMembers) return false;
        work.lookup[bucket]=static_cast<std::int16_t>(tail);
        work.queue[tail++]={px,py}; return true;
    };
    (void)add(x,y);
    auto min_x=x,max_x=x,min_y=y,max_y=y;
    constexpr std::array<std::array<int,2>,4> offsets{{{{0,-1}},{{-1,0}},{{1,0}},{{0,1}}}};
    while (head < tail) {
        const auto point=work.queue[head++];
        ++work.inspected;
        const auto px=point[0],py=point[1];
        if (px==0 || py==0 || px+1==work.canvas.width || py+1==work.canvas.height) return SolidOutcome::Anchored;
        if (!contact_cell_available(px,py)) return SolidOutcome::NotResident;
        if (transient_obstacle_at(px,py)) return SolidOutcome::Occupied;
        if (stored_temperature(px,py)!=config_.ambient_temperature) return SolidOutcome::Thermal;
        if (stored_state_a(px,py) || stored_state_b(px,py)) return SolidOutcome::Ineligible;
        min_x=std::min(min_x,px);max_x=std::max(max_x,px);
        min_y=std::min(min_y,py);max_y=std::max(max_y,py);
        if (max_x-min_x+3>64 || max_y-min_y+3>64) return SolidOutcome::MemberCapacity;
        for (const auto& offset:offsets) {
            ++work.probes;
            const auto nx=px+offset[0],ny=py+offset[1];
            if (!contact_cell_available(nx,ny)) return SolidOutcome::NotResident;
            if (transient_obstacle_at(nx,ny)) return SolidOutcome::Occupied;
            const auto material=stored_material(nx,ny);
            if (material==Material::Wall || material==Material::ReinforcedConcrete) return SolidOutcome::Anchored;
            if (material==Material::RedBrick) {
                if (!add(nx,ny)) return SolidOutcome::MemberCapacity;
            } else if (material==Material::Sand || (material==Material::Water && !water_cellular_yield_)) {
                if (stored_temperature(nx,ny)!=config_.ambient_temperature) return SolidOutcome::Thermal;
            } else if (material!=Material::Empty) return SolidOutcome::Ineligible;
        }
    }
    const auto prepared=prepare_solid_detachment({{min_x-1,min_y-1,static_cast<std::uint16_t>(max_x-min_x+3),
        static_cast<std::uint16_t>(max_y-min_y+3)}, {0,work.canvas.height-1,work.canvas.width,1},x,y});
    if (prepared!=SolidOutcome::Accepted) return prepared;
    auto& pending=solid_detachment_->snapshot;
    pending.granular_piece=small_debris_limit && pending.member_count<=small_debris_limit;
    if (pending.granular_piece) return SolidOutcome::Accepted;
    if (work.count==kWorkbenchSolids) {
        (void)cancel_solid_detachment(pending.token);
        return SolidOutcome::MemberCapacity;
    }
    std::size_t total_shapes=solid_detachment_->snapshot.shape_count;
    for (std::size_t i=0;i<work.count;++i) total_shapes+=work.owned[i].snapshot.shape_count;
    if (total_shapes>kWorkbenchSolidShapes) {
        (void)cancel_solid_detachment(solid_detachment_->snapshot.token);
        return SolidOutcome::ShapeCapacity;
    }
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::crumble_workbench_solid(soliding::SolidToken token) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!workbench_solids_ || !solid_detachment_) return SolidOutcome::Disabled;
    auto& store=*solid_detachment_;auto& s=store.snapshot;auto& ledger=workbench_solids_->debris;
    if (s.phase!=SolidPhase::Prepared || s.token!=token) return SolidOutcome::Stale;
    if (!s.granular_piece || !s.member_count || s.member_count>kWorkbenchSmallDebrisCells) return SolidOutcome::Invalid;
    if (tick_in_progress_ || s.source_tick!=tick_index_ || s.source_terrain_revision!=hard_surface_revision_ ||
        selected_core_region_!=applied_core_region_ || !pending_explosions_.empty()) return SolidOutcome::Stale;
    for (std::size_t i=0;i<s.member_count;++i) {
        const auto& m=store.members[i];
        if (!contact_cell_available(m.x,m.y) || transient_obstacle_at(m.x,m.y) || m.material!=Material::RedBrick ||
            m.state_a || m.state_b || m.temperature!=config_.ambient_temperature ||
            stored_material(m.x,m.y)!=m.material || stored_state_a(m.x,m.y)!=m.state_a ||
            stored_state_b(m.x,m.y)!=m.state_b || stored_temperature(m.x,m.y)!=m.temperature)
            return SolidOutcome::Stale;
    }
    for (std::size_t i=0;i<ledger.size();++i)
        if (ledger[i]>std::numeric_limits<std::uint64_t>::max()-kWorkbenchSmallDebrisCells)
            return SolidOutcome::GenerationExhausted;
    try {
        // Explicit owner-authorized material conversion. No body reservation,
        // source erase/restoration, transport event, kick or new motion law.
        for (std::size_t i=0;i<s.member_count;++i) {
            const auto& m=store.members[i];const auto output=i%2 ? Material::Rust : Material::Sand;
            if (!write_cell(m.x,m.y,output,0,0,nullptr,true))
                throw std::logic_error("small debris source refused conversion");
            ++s.granular_converted_count;++ledger[1];++ledger[i%2 ? 3 : 2];
        }
        ++ledger[0];
    } catch (...) {
        s.phase=SolidPhase::Quarantined;tick_failed_=true;
        if (settled_discovery_) settled_discovery_->fail();
        return SolidOutcome::Quarantined;
    }
    s.committed_terrain_revision=hard_surface_revision_;
    s.phase=SolidPhase::DebrisCommitted; // Hold clocks until terrain installation.
    return SolidOutcome::Accepted;
}

soliding::SolidOutcome World::finalize_workbench_crumble(soliding::SolidToken token,
    std::uint64_t terrain_revision) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!workbench_solids_ || !solid_detachment_) return SolidOutcome::Disabled;
    auto& s=solid_detachment_->snapshot;
    if (s.phase!=SolidPhase::DebrisCommitted || s.token!=token || s.source_tick!=tick_index_ ||
        terrain_revision!=s.committed_terrain_revision || terrain_revision!=hard_surface_revision_)
        return SolidOutcome::Stale;
    const auto incarnation=s.token.incarnation;
    s={};s.phase=SolidPhase::Idle;s.token.incarnation=incarnation;
    return SolidOutcome::Accepted;
}

std::array<std::uint64_t,4> World::workbench_debris_ledger() const noexcept {
    return workbench_solids_ ? workbench_solids_->debris : std::array<std::uint64_t,4>{};
}

soliding::SolidOutcome World::archive_workbench_solid(soliding::SolidToken token) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!workbench_solids_ || !solid_detachment_) return SolidOutcome::Disabled;
    auto& s=solid_detachment_->snapshot;
    if (s.phase!=SolidPhase::Active || token!=s.token) return SolidOutcome::Stale;
    auto& work=*workbench_solids_;
    if (work.count==kWorkbenchSolids || s.shape_count>kWorkbenchSolidShapes) return SolidOutcome::MemberCapacity;
    std::size_t total_shapes=s.shape_count;
    for (std::size_t i=0;i<work.count;++i) total_shapes+=work.owned[i].snapshot.shape_count;
    if (total_shapes>kWorkbenchSolidShapes) return SolidOutcome::ShapeCapacity;
    for (std::size_t i=0;i<work.count;++i) {
        const auto& previous=work.owned[i].snapshot;
        if (previous.physics_epoch!=s.physics_epoch ||
            (s.body_id<previous.body_id+previous.shape_count && previous.body_id<s.body_id+s.shape_count))
            return SolidOutcome::Stale;
    }
    auto& record=work.owned[work.count++];record.snapshot=s;
    std::copy_n(solid_detachment_->members.begin(),s.member_count,record.members.begin());
    std::copy_n(solid_detachment_->shapes.begin(),s.shape_count,record.shapes.begin());
    const auto incarnation=s.token.incarnation;
    s={};s.phase=SolidPhase::Idle;s.token.incarnation=incarnation;
    return SolidOutcome::Accepted;
}
std::size_t World::workbench_solid_count() const noexcept {
    return workbench_solids_ ? workbench_solids_->count : 0;
}
std::array<std::uint64_t,2> World::workbench_solid_discovery_work() const noexcept {
    return workbench_solids_ ? std::array<std::uint64_t,2>{workbench_solids_->inspected,workbench_solids_->probes} : std::array<std::uint64_t,2>{};
}
soliding::SolidSnapshot World::workbench_solid_record(std::size_t index) const noexcept {
    return index<workbench_solid_count() ? workbench_solids_->owned[index].snapshot : soliding::SolidSnapshot{};
}
soliding::SolidOutcome World::rebind_workbench_solids(std::uint64_t old_epoch,std::uint64_t new_epoch) {
    using namespace soliding;
    if (tick_failed_) return SolidOutcome::WorldFailed;
    if (!workbench_solids_ || !new_epoch || old_epoch==new_epoch) return SolidOutcome::Invalid;
    for (std::size_t i=0;i<workbench_solid_count();++i)
        if (workbench_solids_->owned[i].snapshot.physics_epoch!=old_epoch) return SolidOutcome::Stale;
    for (std::size_t i=0;i<workbench_solid_count();++i)
        workbench_solids_->owned[i].snapshot.physics_epoch=new_epoch;
    return SolidOutcome::Accepted;
}
