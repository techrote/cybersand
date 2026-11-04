// Included in namespace godot, after the adapter methods. Strict, opt-in
// SOL-DETACH contact admission. Rapier still owns motion and the ordinary
// cellular coupling still owns the single reaction applied to each contact.
const char* CyberNativeCellWorld::displacement_outcome_name(DisplacementOutcome outcome) {
    static constexpr std::array names{
        "Applied", "InvalidNormal", "UnsupportedMaterial", "SourceEmpty", "SourceOwnership",
        "GeometryBlocked", "ForeignOccupancy", "NoVacancy", "Capacity", "AlreadyTouched",
        "TransactionRefused", "StaleSample", "ThermalPolicy", "Quarantined"
    };
    return names[static_cast<std::size_t>(outcome)];
}

void CyberNativeCellWorld::prepare_conservative_sample() {
    displacement_sample_valid_ = false;
    const auto solid = world_->inspect_solid_detachment();
    if (solid.phase != cybersand::soliding::SolidPhase::Active || solid.shape_count == 0 ||
        solid.body_id == 0 || solid.body_id + solid.shape_count > current_bodies_.size()) return;
    const auto serial = current_bodies_[solid.body_id].sample_serial;
    for (std::size_t id = solid.body_id; id < solid.body_id + solid.shape_count; ++id) {
        if (!current_bodies_[id].valid || current_bodies_[id].sample_serial != serial) return;
    }
    if (solid.token != displacement_token_ || serial != displacement_sample_) {
        // A complete older snapshot cannot acquire another displacement budget.
        // The ordinary producer wraps at 1,000,000, matching its age contract.
        if (solid.token == displacement_token_ && displacement_sample_ >= 0) {
            const auto delta = (serial - displacement_sample_ + 1'000'000) % 1'000'000;
            if (delta <= 0 || delta > 500'000) return;
        }
        displacement_token_ = solid.token;
        displacement_sample_ = serial;
        displacement_touched_count_ = displacement_attempts_this_sample_ = 0;
    }
    displacement_sample_valid_ = true;
}

double CyberNativeCellWorld::displacement_square_gap(const BodyState& body, std::int32_t x, std::int32_t y) {
    // Four-axis SAT of a CLOSED unit cell square and each oriented rectangle.
    // Center-only obstacle rasterization is insufficient near a rotated edge.
    // Require a positive 1e-6 cell gap; exact touch/uncertainty refuses.
    const double c = std::cos(body.rotation), s = std::sin(body.rotation);
        const double dx = static_cast<double>(x) + 0.5 - body.center.x;
        const double dy = static_cast<double>(y) + 0.5 - body.center.y;
        const double ac = std::abs(c), as = std::abs(s);
        const double gap_x = std::abs(dx) - (0.5 + ac * body.half_size.x + as * body.half_size.y);
        const double gap_y = std::abs(dy) - (0.5 + as * body.half_size.x + ac * body.half_size.y);
        const double gap_u = std::abs(c * dx + s * dy) - (body.half_size.x + 0.5 * (ac + as));
        const double gap_v = std::abs(-s * dx + c * dy) - (body.half_size.y + 0.5 * (ac + as));
    return std::max({gap_x, gap_y, gap_u, gap_v});
}

bool CyberNativeCellWorld::displacement_square_clear(std::int32_t x, std::int32_t y) const {
    for (const auto& body : current_bodies_) {
        if (!body.valid) continue;
        const auto gap = displacement_square_gap(body, x, y);
        if (!std::isfinite(gap) || gap <= 1.0e-6) return false;
    }
    return true;
}

CyberNativeCellWorld::DisplacementAttempt CyberNativeCellWorld::conservative_displace(
    std::int32_t source_x, std::int32_t source_y, std::uint16_t body_id, Vector2 outward) {
    using NativeOutcome = cybersand::ConservativeDisplacementOutcome;
    DisplacementAttempt result;
    auto& totals = displacement_accounting_;
    ++totals.attempts;
    const auto finish = [&](DisplacementOutcome outcome) {
        result.outcome = outcome;
        ++totals.outcomes[static_cast<std::size_t>(outcome)];
        return result;
    };
    if (!displacement_sample_valid_) return finish(DisplacementOutcome::StaleSample);
    if (!std::isfinite(outward.x) || !std::isfinite(outward.y) ||
        outward.length_squared() < 0.999 || outward.length_squared() > 1.001)
        return finish(DisplacementOutcome::InvalidNormal);
    if (!in_bounds(source_x, source_y) || body_id == 0 || body_id >= current_bodies_.size() ||
        !current_bodies_[body_id].valid || world_->transient_obstacle_at(source_x, source_y) != body_id)
        return finish(DisplacementOutcome::SourceOwnership);
    const auto aggregate = world_->inspect_solid_detachment();
    for (const auto& other : current_bodies_) {
        if (!other.valid || other.id == body_id) continue;
        const bool same_aggregate = aggregate.phase == cybersand::soliding::SolidPhase::Active &&
            body_id >= aggregate.body_id && body_id < aggregate.body_id + aggregate.shape_count &&
            other.id >= aggregate.body_id && other.id < aggregate.body_id + aggregate.shape_count;
        if (!same_aggregate) {
            const auto gap = displacement_square_gap(other, source_x, source_y);
            if (!std::isfinite(gap) || gap <= 1.0e-6) return finish(DisplacementOutcome::SourceOwnership);
        }
    }
    const auto source_material = world_->stored_material(source_x, source_y);
    if (source_material == cybersand::Material::Empty) return finish(DisplacementOutcome::SourceEmpty);
    const auto eligible = [](cybersand::Material material) {
        return material == cybersand::Material::Sand || material == cybersand::Material::Water;
    };
    if (!eligible(source_material)) return finish(DisplacementOutcome::UnsupportedMaterial);
    if (world_->stored_temperature(source_x, source_y) != world_->config().ambient_temperature)
        return finish(DisplacementOutcome::ThermalPolicy);
    const auto touched = [&](std::int32_t x, std::int32_t y) {
        const auto index = y * kWorldWidth + x;
        return std::find(displacement_touched_.begin(),
            displacement_touched_.begin() + static_cast<std::ptrdiff_t>(displacement_touched_count_), index) !=
            displacement_touched_.begin() + static_cast<std::ptrdiff_t>(displacement_touched_count_);
    };
    if (touched(source_x, source_y)) return finish(DisplacementOutcome::AlreadyTouched);
    if (displacement_attempts_this_sample_ >= kDisplacementAttemptsPerSample)
        return finish(DisplacementOutcome::Capacity);
    ++displacement_attempts_this_sample_;

    // Deterministic breadth-first vacancy search: radius/depth four, not the
    // rejected wider ejection scan. Each occupied vertex represents a DIFFERENT
    // real parcel which will move one cardinal cell into the following vacancy.
    constexpr std::int32_t radius = 4, side = 9;
    struct Node { Vector2i point; std::int16_t parent; std::uint8_t depth; };
    std::array<Node, side * side> nodes{};
    std::array<bool, side * side> visited{};
    std::array<Vector2i, 4> directions{{{0, 1}, {1, 0}, {-1, 0}, {0, -1}}};
    const auto before = [outward](Vector2i a, Vector2i b) {
        return static_cast<double>(a.x) * outward.x + static_cast<double>(a.y) * outward.y >
               static_cast<double>(b.x) * outward.x + static_cast<double>(b.y) * outward.y;
    };
    // Four-element stable insertion sort uses no temporary heap storage.
    for (std::size_t i = 1; i < directions.size(); ++i) {
        const auto value = directions[i];
        auto j = i;
        while (j > 0 && before(value, directions[j - 1])) {
            directions[j] = directions[j - 1]; --j;
        }
        directions[j] = value;
    }
    nodes[0] = {{source_x, source_y}, -1, 0};
    visited[static_cast<std::size_t>(radius * side + radius)] = true;
    std::size_t head = 0, tail = 1;
    bool geometry_blocked = false, foreign_blocked = false, material_blocked = false;
    while (head < tail) {
        const auto current_index = head++;
        const auto node = nodes[current_index];
        if (node.depth >= radius) continue;
        for (const auto direction : directions) {
            if (direction.x * outward.x + direction.y * outward.y < 0.0) continue;
            const Vector2i point = node.point + direction;
            const auto dx = point.x - source_x, dy = point.y - source_y;
            if (std::abs(dx) > radius || std::abs(dy) > radius || !in_bounds(point.x, point.y)) continue;
            const auto slot = static_cast<std::size_t>((dy + radius) * side + dx + radius);
            if (visited[slot]) continue;
            visited[slot] = true;
            ++totals.node_probes;
            if (touched(point.x, point.y)) continue;
            if (world_->transient_obstacle_at(point.x, point.y) != 0U) {
                foreign_blocked = true; ++totals.foreign_blockers; continue;
            }
            if (!displacement_square_clear(point.x, point.y)) {
                geometry_blocked = true; ++totals.geometry_blockers; continue;
            }
            const auto material = world_->stored_material(point.x, point.y);
            if (material != cybersand::Material::Empty && !eligible(material)) {
                material_blocked = true; ++totals.material_blockers; continue;
            }
            if (world_->stored_temperature(point.x, point.y) != world_->config().ambient_temperature) {
                material_blocked = true; ++totals.material_blockers; continue;
            }
            if (material == cybersand::Material::Empty && dx * outward.x + dy * outward.y <= 0.0) continue;
            if (tail == nodes.size()) return finish(DisplacementOutcome::Capacity);
            const auto next = tail++;
            nodes[next] = {point, static_cast<std::int16_t>(current_index), static_cast<std::uint8_t>(node.depth + 1)};
            if (material != cybersand::Material::Empty) continue;

            cybersand::ConservativeDisplacementRequest request;
            request.count = static_cast<std::size_t>(nodes[next].depth) + 1;
            request.source_body_id = body_id;
            request.expected_tick = world_->completed_tick_index();
            const auto solid = world_->inspect_solid_detachment();
            if (solid.phase == cybersand::soliding::SolidPhase::Active) {
                request.aggregate_token = solid.token;
                request.body_generation = solid.body_generation;
            }
            auto reverse = static_cast<std::int16_t>(next);
            for (std::size_t index = request.count; index-- > 0;) {
                const auto p = nodes[static_cast<std::size_t>(reverse)].point;
                auto& cell = request.path[index];
                cell = {p.x, p.y, world_->stored_material(p.x, p.y),
                    world_->stored_state_a(p.x, p.y), world_->stored_state_b(p.x, p.y),
                    world_->stored_temperature(p.x, p.y)};
                reverse = nodes[static_cast<std::size_t>(reverse)].parent;
            }
            if (displacement_touched_count_ + request.count > displacement_touched_.size())
                return finish(DisplacementOutcome::Capacity);
            const auto receipt = world_->conservative_displace_cells(request);
            result.native_outcome = static_cast<std::int32_t>(receipt.outcome);
            ++totals.transaction_outcomes[static_cast<std::size_t>(receipt.outcome)];
            if (receipt.outcome == NativeOutcome::Quarantined) {
                result.moved_cells = receipt.moved_cells;
                return finish(DisplacementOutcome::Quarantined);
            }
            if (receipt.outcome != NativeOutcome::Applied)
                return finish(DisplacementOutcome::TransactionRefused);
            result.count = request.count;
            result.moved_cells = receipt.moved_cells;
            for (std::size_t index = 0; index < request.count; ++index) {
                const auto& p = request.path[index];
                result.path[index] = {static_cast<std::int32_t>(p.x), static_cast<std::int32_t>(p.y)};
                displacement_touched_[displacement_touched_count_++] = static_cast<std::int32_t>(p.y * kWorldWidth + p.x);
            }
            ++totals.accepted;
            totals.moved_cells += receipt.moved_cells;
            return finish(DisplacementOutcome::Applied);
        }
    }
    // These are exclusive refusal summaries. Probe blockers above retain their
    // separate counts; no summary claims that every possible route was tried.
    if (geometry_blocked) return finish(DisplacementOutcome::GeometryBlocked);
    if (foreign_blocked) return finish(DisplacementOutcome::ForeignOccupancy);
    if (material_blocked) return finish(DisplacementOutcome::UnsupportedMaterial);
    return finish(DisplacementOutcome::NoVacancy);
}

Dictionary CyberNativeCellWorld::conservative_displacement_metrics() const {
    Dictionary result, outcomes;
    result["policy"] = conservative_displacement_ ? "bounded-cardinal-chain-v1" : "current-main-ejection";
    result["attempts"] = static_cast<std::int64_t>(displacement_accounting_.attempts);
    result["accepted"] = static_cast<std::int64_t>(displacement_accounting_.accepted);
    result["moved_cells"] = static_cast<std::int64_t>(displacement_accounting_.moved_cells);
    result["node_probes"] = static_cast<std::int64_t>(displacement_accounting_.node_probes);
    result["geometry_blockers"] = static_cast<std::int64_t>(displacement_accounting_.geometry_blockers);
    result["foreign_blockers"] = static_cast<std::int64_t>(displacement_accounting_.foreign_blockers);
    result["material_blockers"] = static_cast<std::int64_t>(displacement_accounting_.material_blockers);
    result["maximum_attempts_per_sample"] = static_cast<std::int64_t>(kDisplacementAttemptsPerSample);
    result["maximum_parcel_moves"] = 4;
    result["touched_coordinates"] = static_cast<std::int64_t>(displacement_touched_count_);
    for (std::size_t i = 0; i < displacement_accounting_.outcomes.size(); ++i)
        outcomes[displacement_outcome_name(static_cast<DisplacementOutcome>(i))] =
            static_cast<std::int64_t>(displacement_accounting_.outcomes[i]);
    result["outcomes"] = outcomes;
    Array native_outcomes;
    for (const auto count : displacement_accounting_.transaction_outcomes)
        native_outcomes.append(static_cast<std::int64_t>(count));
    result["native_transaction_outcomes"] = native_outcomes;
    return result;
}

Dictionary CyberNativeCellWorld::diagnostic_replay_conservative_contact(const Dictionary& capsule) {
    // Rebuild a bounded, source-pinned contact in a real native World, then run
    // the production policy. This is deterministic geometry/transaction replay,
    // not evidence of asynchronous or actual Rapier-host motion.
    Dictionary result;
    result["ok"] = false;
    result["outcome"] = "MalformedCapsule";
    if (world_ && world_->inspect_solid_detachment().phase != cybersand::soliding::SolidPhase::Disabled &&
        world_->inspect_solid_detachment().phase != cybersand::soliding::SolidPhase::Idle) {
        result["outcome"] = "LiveAggregate"; return result;
    }
    const auto numbers = [](const Variant& value, std::size_t count, std::array<double, 12>& output) {
        if (value.get_type() != Variant::ARRAY) return false;
        const Array a = value;
        if (a.size() < static_cast<std::int64_t>(count) || count > output.size()) return false;
        for (std::size_t i = 0; i < count; ++i) {
            const Variant v = a[static_cast<std::int64_t>(i)];
            if (v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT) return false;
            output[i] = static_cast<double>(v);
            if (!std::isfinite(output[i])) return false;
        }
        return true;
    };
    const auto integer = [](double v, double low, double high) {
        return v >= low && v <= high && std::trunc(v) == v;
    };
    std::array<double, 12> bounds{}, source{}, normal{};
    if (!numbers(capsule.get("bounds", Variant()), 4, bounds) ||
        !numbers(capsule.get("source", Variant()), 2, source) ||
        !numbers(capsule.get("normal", Variant()), 2, normal) ||
        !integer(bounds[0], 0, 1023) || !integer(bounds[1], 0, 1023) ||
        !integer(bounds[2], 1, 17) || !integer(bounds[3], 1, 17) ||
        bounds[0] + bounds[2] > 1024 || bounds[1] + bounds[3] > 1024 ||
        !integer(source[0], bounds[0], bounds[0] + bounds[2] - 1) ||
        !integer(source[1], bounds[1], bounds[1] + bounds[3] - 1) ||
        capsule.get("cells", Variant()).get_type() != Variant::ARRAY) return result;
    const Array cells = capsule["cells"];
    const auto count = static_cast<std::size_t>(bounds[2] * bounds[3]);
    if (cells.size() != static_cast<std::int64_t>(count)) return result;
    struct CellValue { cybersand::Material material; std::uint16_t a; std::uint8_t b;
        std::int16_t temperature; std::uint16_t mask; };
    std::array<CellValue, 17 * 17> values{};
    for (std::size_t i = 0; i < count; ++i) {
        std::array<double, 12> v{};
        if (!numbers(cells[static_cast<std::int64_t>(i)], 5, v) ||
            !integer(v[0], 0, static_cast<std::uint16_t>(cybersand::kLastMaterial)) ||
            !cybersand::valid_material(static_cast<std::uint16_t>(v[0])) ||
            !integer(v[1], 0, 65535) || !integer(v[2], 0, 255) ||
            !integer(v[3], -32768, 32767) || !integer(v[4], 0, cybersand::World::kMaximumTransientBodies)) return result;
        values[i] = {static_cast<cybersand::Material>(static_cast<std::uint16_t>(v[0])),
            static_cast<std::uint16_t>(v[1]), static_cast<std::uint8_t>(v[2]),
            static_cast<std::int16_t>(v[3]), static_cast<std::uint16_t>(v[4])};
        const cybersand::WorldConfig default_policy;
        if ((values[i].material != cybersand::Material::Water && values[i].a > 255) ||
            (values[i].material == cybersand::Material::Water &&
             (values[i].a == 0 || values[i].a > default_policy.water_experiment_policy.maximum() ||
              values[i].b > default_policy.water_experiment_policy.coherence_ticks()))) return result;
    }
    Array body_inputs;
    if (capsule.has("all_current_bodies")) {
        if (capsule["all_current_bodies"].get_type() != Variant::ARRAY) return result;
        body_inputs = capsule["all_current_bodies"];
    } else body_inputs.append(capsule.get("current_body", Variant()));
    if (body_inputs.is_empty() || body_inputs.size() > 64) return result;
    BodyStates replay_bodies{};
    for (std::int64_t i = 0; i < body_inputs.size(); ++i) {
        std::array<double, 12> b{};
        if (!numbers(body_inputs[i], 11, b) || !integer(b[0], 1, 64) ||
            b[4] <= 0 || b[5] <= 0 || b[9] <= 0 || !integer(b[10], 0, 999999)) return result;
        auto& body = replay_bodies[static_cast<std::size_t>(b[0])];
        if (body.valid) return result;
        body.id = static_cast<std::uint16_t>(b[0]);
        body.center = {b[1], b[2]}; body.rotation = b[3]; body.half_size = {b[4], b[5]};
        body.velocity = {b[6], b[7]}; body.angular_velocity = b[8]; body.mass = b[9];
        body.sample_serial = static_cast<std::int32_t>(b[10]); body.valid = true;
        if (!std::isfinite(body.center.x) || !std::isfinite(body.center.y) ||
            !std::isfinite(body.half_size.x) || !std::isfinite(body.half_size.y) ||
            !std::isfinite(body.velocity.x) || !std::isfinite(body.velocity.y) ||
            body.half_size.x <= 0 || body.half_size.y <= 0) return result;
    }
    const auto body_id_value = static_cast<double>(capsule.get("body_id", 0));
    if (!integer(body_id_value, 1, 64) || !replay_bodies[static_cast<std::size_t>(body_id_value)].valid) return result;
    const auto body_id = static_cast<std::uint16_t>(body_id_value);
    const auto sx = static_cast<std::int32_t>(source[0]), sy = static_cast<std::int32_t>(source[1]);
    const auto& source_body = replay_bodies[body_id];
    Vector2 expected_normal{};
    double penetration = 0.5;
    if (cell_inside_body(source_body, sx, sy)) expected_normal = overlap_normal(source_body, sx, sy, penetration);
    else {
        std::array<double, 12> previous{};
        if (!numbers(capsule.get("previous_body", Variant()), 11, previous)) return result;
        expected_normal = normalized_or_zero(source_body.center - Vector2(previous[1], previous[2]));
        if (expected_normal.length_squared() <= 0.000001)
            expected_normal = overlap_normal(source_body, sx, sy, penetration);
    }
    // JSON stores captured float values; the small tolerance is arithmetic
    // roundoff, not an alternative contact-normal selection policy.
    const Vector2 supplied_normal{normal[0], normal[1]};
    const bool normal_valid = supplied_normal.distance_to(expected_normal) <= 1.0e-5;
    if (String(capsule.get("storage_policy", "")) != "default_cellular_no_pressure_or_inertial_sidecar") return result;
    Dictionary setup;
    setup["workers"] = worker_threads_; setup["telemetry"] = false; setup["conservative_displacement"] = true;
    try {
    if (!diagnostic_reset(setup)) { result["outcome"] = "SetupRefused"; return result; }
    set_simulation_window_enabled(false);
    // Apply the inclusion boundary while the World is entirely Empty. Frozen
    // material and masks are imported only after this setup tick, never stepped.
    if (!simulation_tick()) { result["outcome"] = "SetupTickFailed"; return result; }
    current_bodies_ = replay_bodies;
    previous_bodies_ = replay_bodies;
    // Unknown outside the captured window is an immovable boundary, never an
    // invented route to newly manufactured air. A halo one cell wide suffices
    // because no admitted chain can cross it.
    const auto bx = static_cast<std::int32_t>(bounds[0]), by = static_cast<std::int32_t>(bounds[1]);
    const auto width = static_cast<std::int32_t>(bounds[2]), height = static_cast<std::int32_t>(bounds[3]);
    for (auto y = by - 1; y <= by + height; ++y)
        for (auto x = bx - 1; x <= bx + width; ++x)
            if (in_bounds(x, y) && (x < bx || x >= bx + width || y < by || y >= by + height))
                (void)world_->set(x, y, cybersand::Material::Wall);
    for (std::size_t i = 0; i < count; ++i) {
        const auto x = bx + static_cast<std::int32_t>(i % static_cast<std::size_t>(width));
        const auto y = by + static_cast<std::int32_t>(i / static_cast<std::size_t>(width));
        const auto& v = values[i];
        (void)world_->set_cell_state(x, y, v.material, v.a, v.b);
        world_->set_temperature(x, y, v.temperature);
        if (world_->stored_material(x, y) != v.material || world_->stored_state_a(x, y) != v.a ||
            world_->stored_state_b(x, y) != v.b || world_->stored_temperature(x, y) != v.temperature) {
            result["outcome"] = "PayloadRefused"; return result;
        }
        if (v.mask != 0) (void)world_->set_transient_obstacle(x, y, v.mask);
        if (world_->transient_obstacle_at(x, y) != v.mask) { result["outcome"] = "MaskRefused"; return result; }
    }
    displacement_sample_valid_ = true;
    displacement_sample_ = source_body.sample_serial;
    const auto snapshot = [&]() {
        Array output;
        for (std::size_t i = 0; i < count; ++i) {
            const auto x = bx + static_cast<std::int32_t>(i % static_cast<std::size_t>(width));
            const auto y = by + static_cast<std::int32_t>(i / static_cast<std::size_t>(width));
            Array row;
            row.append(static_cast<std::int64_t>(world_->stored_material(x, y)));
            row.append(world_->stored_state_a(x, y)); row.append(world_->stored_state_b(x, y));
            row.append(world_->stored_temperature(x, y)); row.append(world_->transient_obstacle_at(x, y));
            output.append(row);
        }
        return output;
    };
    result["before"] = snapshot();
    DisplacementAttempt attempt;
    if (normal_valid) attempt = conservative_displace(sx, sy, body_id, supplied_normal);
    else attempt.outcome = DisplacementOutcome::InvalidNormal;
    result["ok"] = true;
    result["outcome"] = displacement_outcome_name(attempt.outcome);
    result["moved_cells"] = static_cast<std::int64_t>(attempt.moved_cells);
    result["after"] = snapshot();
    Array path;
    bool clear = true;
    for (std::size_t i = 0; i < attempt.count; ++i) {
        Array p; p.append(attempt.path[i].x); p.append(attempt.path[i].y); path.append(p);
        if (i > 0) clear = clear && displacement_square_clear(attempt.path[i].x, attempt.path[i].y);
    }
    result["path"] = path;
    result["geometry_clear"] = attempt.count > 1 && clear;
    result["fatal"] = attempt.outcome == DisplacementOutcome::Quarantined;
    result["native_outcome"] = attempt.native_outcome;
    result["normal"] = capsule["normal"];
    result["bounds"] = capsule["bounds"];
    result["counters"] = conservative_displacement_metrics();
    result["workers"] = static_cast<std::int64_t>(world_->config().worker_threads);
    result["empty_setup_ticks"] = static_cast<std::int64_t>(world_->completed_tick_index());
    } catch (const std::exception& error) {
        result["ok"] = false;
        result["outcome"] = "ReplaySetupException";
        result["error"] = String(error.what());
    }
    return result;
}
