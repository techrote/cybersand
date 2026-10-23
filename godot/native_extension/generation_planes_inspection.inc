// All returned values are copies. Absolute semantic coordinates never depend on camera state.
Rect2i plane_rect(const cybersand::RectI64& value) {
    constexpr auto low = std::numeric_limits<std::int32_t>::min();
    constexpr auto high = std::numeric_limits<std::int32_t>::max();
    if (value.x < low || value.y < low || value.x > high || value.y > high ||
        value.width < 1 || value.height < 1 || value.width > 1024 || value.height > 1024 ||
        value.x > high - value.width || value.y > high - value.height)
        invalid("semantic plane bounds", "Godot host requires representable coordinates and each axis within 1..1024");
    return {static_cast<std::int32_t>(value.x), static_cast<std::int32_t>(value.y),
            static_cast<std::int32_t>(value.width), static_cast<std::int32_t>(value.height)};
}
Dictionary plane_limits_dictionary(const gen::PlaneLimits& value) {
    Dictionary result;
#define PLANE_EXPORT(member) result[#member] = static_cast<std::int64_t>(value.member)
    PLANE_EXPORT(max_templates); PLANE_EXPORT(max_projections); PLANE_EXPORT(max_fixtures);
    PLANE_EXPORT(max_links); PLANE_EXPORT(max_actors); PLANE_EXPORT(max_cells_per_plane); PLANE_EXPORT(max_operations);
    PLANE_EXPORT(max_prepared_bytes); PLANE_EXPORT(max_publication_bytes); PLANE_EXPORT(max_diagnostic_bytes);
    PLANE_EXPORT(max_events_per_tick); PLANE_EXPORT(max_fixture_cell_writes);
#undef PLANE_EXPORT
    return result;
}
Dictionary plane_plan_dictionary(const gen::PlanePlan& plan) {
    Dictionary result;
    result["ok"] = true; result["schema"] = gen::kPlaneSchemaVersion; result["algorithm"] = gen::kPlaneAlgorithmVersion;
    result["id"] = String(plan.definition().id.c_str()); result["revision"] = hexadecimal(plan.fingerprint());
    result["definition_revision"] = hexadecimal(plan.definition().revision);
    result["bounds"] = plane_rect(plan.bounds()); result["plan_bounds"] = plane_rect(plan.bounds());
    result["fingerprint"] = hexadecimal(plan.fingerprint());
    result["preparation_work"] = static_cast<std::int64_t>(plan.preparation_work());
    result["operations_per_cell"] = static_cast<std::int64_t>(plan.operations_per_cell());
    result["storage_bytes"] = static_cast<std::int64_t>(plan.storage_bytes());
    result["spatial_index"] = generation_index_dictionary(plan.index_info());
    result["budgets"] = plane_limits_dictionary(plan.definition().limits);
    Dictionary rates; Array policies, features, projections, fixtures, links, actors;
    for (const auto& policy : plan.definition().policies) {
        Dictionary item;
        item["plane"] = gen::plane_name(policy.plane); item["material"] = static_cast<int>(policy.material);
        item["base_generator"] = policy.base_generator; item["rate"] = policy.rate;
        item["omission"] = String(policy.omission.c_str()); policies.push_back(item);
        rates[gen::plane_name(policy.plane)] = policy.rate;
    }
    for (const auto& feature : plan.generator().semantic_plan()->features()) {
        Dictionary item;
        item["id"] = String(feature.id.c_str()); item["revision"] = hexadecimal(feature.revision);
        item["parent"] = String(feature.parent.c_str()); item["rule_id"] = String(feature.rule_id.c_str());
        item["kind"] = gen::semantic_kind_name(feature.kind); item["bounds"] = plane_rect(feature.bounds);
        item["owner_x"] = feature.owner.x; item["owner_y"] = feature.owner.y;
        item["seed"] = hexadecimal(feature.seed); item["tags"] = grammar_strings(feature.tags);
        features.push_back(item);
    }
    for (const auto& projection : plan.projections()) {
        Dictionary item;
        item["id"] = String(projection.id.c_str()); item["revision"] = hexadecimal(projection.revision);
        item["adapter"] = String(projection.adapter.c_str()); item["feature_id"] = String(projection.feature_id.c_str());
        item["geometry_ref"] = String(projection.geometry_ref.c_str()); item["plane"] = gen::plane_name(projection.plane);
        item["shape"] = gen::projection_shape_name(projection.shape); item["bounds"] = plane_rect(projection.bounds);
        item["owner_x"] = projection.owner.x; item["owner_y"] = projection.owner.y;
        item["material"] = static_cast<int>(projection.material); item["interior"] = static_cast<int>(projection.interior);
        item["wall_thickness"] = projection.wall_thickness; item["route_width"] = projection.route_width;
        item["density"] = projection.density; item["priority"] = projection.priority;
        item["seed"] = hexadecimal(projection.seed); item["omission"] = String(projection.omission.c_str());
        item["application"] = String(projection.application.c_str()); item["exclusion"] = String(projection.exclusion.c_str());
        item["fields_fingerprint"] = hexadecimal(projection.fields_fingerprint);
        Array points;
        for (const auto& point : projection.points) { Array p; p.push_back(point.x); p.push_back(point.y); points.push_back(p); }
        item["points"] = points; projections.push_back(item);
    }
    for (const auto& fixture : plan.fixtures()) {
        Dictionary item;
        item["id"] = String(fixture.id.c_str()); item["revision"] = hexadecimal(fixture.revision);
        item["adapter"] = String(fixture.adapter.c_str()); item["feature_id"] = String(fixture.feature_id.c_str());
        item["clock"] = String(fixture.clock.c_str()); item["lifecycle"] = String(fixture.lifecycle.c_str());
        item["plane"] = gen::plane_name(fixture.plane); item["bounds"] = plane_rect(fixture.bounds);
        item["owner_x"] = fixture.owner.x; item["owner_y"] = fixture.owner.y;
        item["mode"] = gen::fixture_mode_name(fixture.mode); item["material"] = static_cast<int>(fixture.material);
        item["first_tick"] = static_cast<std::int64_t>(fixture.first_tick); item["period"] = static_cast<std::int64_t>(fixture.period);
        item["repeat"] = static_cast<std::int64_t>(fixture.repeat); item["cleanup_tick"] = static_cast<std::int64_t>(fixture.cleanup_tick);
        Array products; for (auto material : fixture.expected_products) products.push_back(static_cast<int>(material));
        item["expected_products"] = products; fixtures.push_back(item);
    }
    for (const auto& link : plan.links()) {
        Dictionary item;
        item["id"] = String(link.id.c_str()); item["revision"] = hexadecimal(link.revision);
        item["adapter"] = String(link.adapter.c_str()); item["source_feature"] = String(link.source_feature.c_str());
        item["target_feature"] = String(link.target_feature.c_str()); item["effect"] = String(link.effect.c_str());
        item["fixture_id"] = String(link.fixture_id.c_str()); item["lifecycle"] = String(link.lifecycle.c_str());
        item["family"] = gen::link_family_name(link.family); item["classification"] = gen::link_class_name(link.classification);
        item["source_plane"] = gen::plane_name(link.source_plane); item["target_plane"] = gen::plane_name(link.target_plane);
        item["bounds"] = plane_rect(link.bounds); item["owner_x"] = link.owner.x; item["owner_y"] = link.owner.y;
        item["material"] = static_cast<int>(link.material); item["radius"] = link.radius;
        item["max_events_per_tick"] = link.max_events_per_tick; links.push_back(item);
    }
    for (const auto& actor : plan.actors()) {
        Dictionary item;
        item["id"] = String(actor.id.c_str()); item["revision"] = hexadecimal(actor.revision);
        item["adapter"] = String(actor.adapter.c_str()); item["feature_id"] = String(actor.feature_id.c_str());
        item["model"] = String(actor.model.c_str()); item["producer"] = String(actor.producer.c_str());
        item["lifecycle"] = String(actor.lifecycle.c_str()); item["plane"] = gen::plane_name(actor.plane);
        item["position"] = Vector2i(static_cast<std::int32_t>(actor.x), static_cast<std::int32_t>(actor.y));
        item["owner_x"] = actor.owner.x; item["owner_y"] = actor.owner.y;
        actors.push_back(item);
    }
    result["actors"] = actors;
    result["rates"] = rates; result["policies"] = policies; result["features"] = features;
    result["projections"] = projections; result["fixtures"] = fixtures; result["links"] = links;
    return result;
}
PackedInt32Array plane_rectangles(const std::vector<cybersand::Material>& cells, std::int32_t width, std::int32_t height) {
    // Merge identical row runs vertically. Empty cells need no write to a fresh World.
    // All output is staged before the host can see or register any of it.
    struct Run { std::int32_t x, y, width, height, material; };
    std::vector<Run> rectangles;
    std::map<std::tuple<std::int32_t,std::int32_t,std::int32_t>, std::size_t> previous;
    for (std::int32_t y = 0; y < height; ++y) {
        decltype(previous) current;
        for (std::int32_t x = 0; x < width;) {
            const auto material = static_cast<std::int32_t>(cells[static_cast<std::size_t>(y) * static_cast<std::size_t>(width) + static_cast<std::size_t>(x)]);
            const auto start = x;
            while (x < width && static_cast<std::int32_t>(cells[static_cast<std::size_t>(y) * static_cast<std::size_t>(width) + static_cast<std::size_t>(x)]) == material) ++x;
            if (material == 0) continue;
            const auto key = std::make_tuple(start, x - start, material);
            const auto existing = previous.find(key);
            if (existing != previous.end()) {
                ++rectangles[existing->second].height; current.emplace(key, existing->second);
            } else {
                if (rectangles.size() >= 4096) invalid("plane publication", "depth owner rectangle budget exceeded");
                current.emplace(key, rectangles.size()); rectangles.push_back({start, y, x-start, 1, material});
            }
        }
        previous = std::move(current);
    }
    PackedInt32Array result;
    if (result.resize(static_cast<std::int64_t>(rectangles.size() * 5)) != OK)
        invalid("semantic plane publication", "cannot allocate copied run rectangles");
    auto* out = result.ptrw();
    for (const auto& rect : rectangles) { *out++=rect.x; *out++=rect.y; *out++=rect.width; *out++=rect.height; *out++=rect.material; }
    return result;
}
