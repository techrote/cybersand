// Included by world.cpp after complete World/Chunk definitions, inside cybersand.
ConservativeDisplacementResult World::conservative_displace_cells(
    const ConservativeDisplacementRequest& request) {
    using Outcome = ConservativeDisplacementOutcome;
    const auto refuse = [](Outcome reason) { return ConservativeDisplacementResult{reason, 0}; };
    if (tick_failed_) return refuse(Outcome::WorldFailed);
    if (tick_in_progress_) return refuse(Outcome::TickInProgress);
    if (solid_detachment_fenced()) return refuse(Outcome::TransitionFenced);
    if (request.count > request.path.size()) return refuse(Outcome::Capacity);
    if (request.count < 2 || request.source_body_id > kMaximumTransientBodies)
        return refuse(Outcome::InvalidPath);
    if (request.expected_tick != tick_index_) return refuse(Outcome::StaleTick);
    if (pressure_ != nullptr || inertial_enabled_ || water_cellular_yield_)
        return refuse(Outcome::UnsupportedPolicy);
    if (selected_core_region_ != applied_core_region_) return refuse(Outcome::Excluded);
    const bool aggregate_lease = request.aggregate_token.incarnation != 0 ||
        request.aggregate_token.sequence != 0 || request.body_generation != 0;
    if (aggregate_lease) {
        if (!solid_detachment_) return refuse(Outcome::StaleAggregate);
        const auto& aggregate = solid_detachment_->snapshot;
        if (aggregate.phase != soliding::SolidPhase::Active ||
            request.aggregate_token != aggregate.token ||
            request.body_generation != aggregate.body_generation ||
            aggregate.body_id == 0 || aggregate.shape_count == 0 ||
            aggregate.body_id > kMaximumTransientBodies ||
            aggregate.shape_count > static_cast<std::size_t>(kMaximumTransientBodies - aggregate.body_id + 1U) ||
            request.source_body_id < aggregate.body_id ||
            static_cast<std::size_t>(request.source_body_id - aggregate.body_id) >= aggregate.shape_count)
            return refuse(Outcome::StaleAggregate);
    }

    // This contact API admits the same finite coordinate envelope as the
    // external player material field, avoiding extreme signed-domain ambiguity.
    constexpr std::int64_t coordinate_limit = 1'000'000'000;
    std::array<Chunk*, kConservativeDisplacementCells> chunks{};
    for (std::size_t i = 0; i < request.count; ++i) {
        const auto& cell = request.path[i];
        if (cell.x < -coordinate_limit || cell.x > coordinate_limit ||
            cell.y < -coordinate_limit || cell.y > coordinate_limit)
            return refuse(Outcome::InvalidPath);
        for (std::size_t j = 0; j < i; ++j)
            if (request.path[j].x == cell.x && request.path[j].y == cell.y)
                return refuse(Outcome::InvalidPath);
        if (i != 0) {
            const auto& previous = request.path[i - 1];
            const auto dx = cell.x - previous.x, dy = cell.y - previous.y;
            if (!((dx == 0 && (dy == -1 || dy == 1)) ||
                  (dy == 0 && (dx == -1 || dx == 1)))) return refuse(Outcome::InvalidPath);
        }
        const auto target = address(cell.x, cell.y);
        auto* chunk = find_chunk(target.chunk);
        if (chunk == nullptr) return refuse(Outcome::Nonresident);
        chunks[i] = chunk;
        if (selected_core_region_) {
            const auto core = scheduler_geometry_.core_for_cell(cell.x, cell.y);
            const auto& region = *selected_core_region_;
            if (core.x < region.min_x || core.x > region.max_x ||
                core.y < region.min_y || core.y > region.max_y) return refuse(Outcome::Excluded);
        }
        const auto mask = transient_obstacle_at(cell.x, cell.y);
        if (i == 0) {
            if (mask != request.source_body_id) return refuse(Outcome::SourceMask);
        } else if (mask != 0) return refuse(Outcome::DestinationMask);
        const auto& actual = chunk->cells[target.index];
        const auto temperature = chunk->temperatures == nullptr ? config_.ambient_temperature
            : (*chunk->temperatures)[target.index];
        if (actual.material_value() != cell.expected_material ||
            actual.state_a_value() != cell.expected_state_a ||
            actual.state_b_value() != cell.expected_state_b || temperature != cell.expected_temperature)
            return refuse(Outcome::StalePayload);
        if (i + 1 == request.count) {
            // No hidden Empty state or nonambient thermal value is discarded.
            if (cell.expected_material != Material::Empty || cell.expected_state_a != 0 ||
                cell.expected_state_b != 0 || temperature != config_.ambient_temperature)
                return refuse(Outcome::InvalidTerminal);
        } else if (cell.expected_material != Material::Sand && cell.expected_material != Material::Water) {
            return refuse(Outcome::UnsupportedMaterial);
        }
    }
    // move_cell writes material before its lazy thermal allocation. Therefore
    // every needed field must already exist before the FIRST parcel moves.
    // Chunks are resident and no allowed material is a hard-surface revision.
    for (std::size_t i = 0; i + 1 < request.count; ++i)
        if (request.path[i].expected_temperature != config_.ambient_temperature &&
            chunks[i + 1]->temperatures == nullptr) return refuse(Outcome::ThermalCapacity);

    ConservativeDisplacementResult result{Outcome::Applied, 0};
    try {
        // Shift the vacancy backwards; every parcel travels one cardinal cell.
        // One serialized owner prevents cancellation or other mutation between
        // preflight and these bounded allocation-free ordinary move operations.
        for (std::size_t i = request.count - 1; i > 0; --i) {
            const auto& from = request.path[i - 1];
            const auto& to = request.path[i];
            move_cell(from.x, from.y, to.x, to.y, false, nullptr);
            ++result.moved_cells;
        }
    } catch (...) {
        // An unexpected invariant failure is not a retryable refusal. Retain
        // material at its actual locations and quarantine the World rather
        // than admitting a second owner or replaying a partial transaction.
        tick_failed_ = true;
        if (settled_discovery_) settled_discovery_->fail();
        result.outcome = Outcome::Quarantined;
    }
    return result;
}
