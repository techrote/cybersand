Dictionary generation_index_dictionary(const gen::GenerationIndexInfo& index) {
    Dictionary result;
    result["bin_size"] = index.bin_size; result["bins"] = static_cast<std::int64_t>(index.bins);
    result["entries"] = static_cast<std::int64_t>(index.entries);
    result["maximum_candidates"] = static_cast<std::int64_t>(index.maximum_candidates);
    result["kind"] = "measured prepared index counts; 64-cell bins preserve canonical candidate order";
    result["cost_kind"] = "operations_per_sample/cell are conservative logical bounds, not elapsed time";
    return result;
}
Array grammar_strings(const std::vector<std::string>& values) {
    Array result;
    for (const auto& value : values) result.push_back(String(value.c_str()));
    return result;
}
Array grammar_bounds(const cybersand::RectI64& value) {
    Array result;
    result.push_back(value.x); result.push_back(value.y);
    result.push_back(value.width); result.push_back(value.height);
    return result;
}
Dictionary grammar_value(const gen::SpatialValue& value) {
    Dictionary result;
    result["type"] = gen::spatial_type_name(value.type);
    if (value.type == gen::SpatialType::Category) {
        Dictionary category;
        category["x"] = String(std::to_string(value.category.x).c_str());
        category["y"] = String(std::to_string(value.category.y).c_str());
        category["domain"] = hexadecimal(value.category.domain);
        result["category"] = category;
    } else {
        result["x"] = value.x;
        if (value.type == gen::SpatialType::Vector2) result["y"] = value.y;
    }
    return result;
}
Dictionary grammar_receipt(const gen::ConstraintReceipt& receipt) {
    Dictionary result;
    result["feature_id"] = String(receipt.feature_id.c_str());
    result["rule_id"] = String(receipt.rule_id.c_str());
    result["constraint"] = String(receipt.constraint.c_str());
    result["detail"] = String(receipt.detail.c_str());
    result["passed"] = receipt.passed; result["fallback"] = receipt.fallback;
    return result;
}
Dictionary grammar_route_validation(const gen::RouteValidation& report) {
    Dictionary result;
    result["ok"] = true; result["passed"] = report.passed;
    result["profile"] = String(report.profile.c_str()); result["clearance"] = report.clearance;
    result["cells"] = static_cast<std::int64_t>(report.cells);
    result["operations"] = static_cast<std::int64_t>(report.operations);
    result["boundary_apertures"] = report.boundary_apertures;
    Array routes;
    for (const auto& route : report.routes) {
        Dictionary item;
        item["id"] = String(route.id.c_str()); item["passed"] = route.passed;
        item["detail"] = String(route.detail.c_str());
        item["checked_centres"] = static_cast<std::int64_t>(route.checked_centres);
        item["blocked_centres"] = static_cast<std::int64_t>(route.blocked_centres);
        item["first_block_x"] = route.first_block_x; item["first_block_y"] = route.first_block_y;
        routes.push_back(item);
    }
    result["routes"] = routes;
    result["supports_passed"] = report.supports_passed;
    result["support_profile"] = String(report.support_profile.c_str());
    Array supports;
    for (const auto& support : report.supports) {
        Dictionary item;
        item["feature_id"] = String(support.feature_id.c_str());
        item["constraint"] = String(support.constraint.c_str()); item["passed"] = support.passed;
        item["detail"] = String(support.detail.c_str());
        item["checked_cells"] = static_cast<std::int64_t>(support.checked_cells);
        item["missing_cells"] = static_cast<std::int64_t>(support.missing_cells);
        item["first_missing_x"] = support.first_missing_x; item["first_missing_y"] = support.first_missing_y;
        supports.push_back(item);
    }
    result["supports"] = supports;
    return result;
}
Dictionary grammar_plan_dictionary(const gen::GrammarPlan& plan) {
    Dictionary result;
    result["ok"] = true; result["schema"] = gen::kGrammarSchemaVersion;
    result["algorithm"] = gen::kGrammarAlgorithmVersion;
    result["id"] = String(plan.definition().id.c_str());
    result["fingerprint"] = hexadecimal(plan.fingerprint());
    result["bounds"] = grammar_bounds(plan.bounds());
    result["region_window"] = grammar_bounds(plan.definition().region_window);
    result["region_size"] = plan.definition().region_size;
    result["preparation_work"] = static_cast<std::int64_t>(plan.preparation_work());
    result["operations_per_sample"] = static_cast<std::int64_t>(plan.operations_per_sample());
    result["storage_bytes"] = static_cast<std::int64_t>(plan.storage_bytes());
    result["spatial_index"] = generation_index_dictionary(plan.index_info());
    Array features, sockets, routes, receipts, geometries;
    for (const auto& feature : plan.features()) {
        Dictionary item;
        item["id"] = String(feature.id.c_str()); item["parent"] = String(feature.parent.c_str());
        item["rule_id"] = String(feature.rule_id.c_str()); item["candidate_id"] = String(feature.candidate_id.c_str());
        item["kind"] = gen::semantic_kind_name(feature.kind); item["bounds"] = grammar_bounds(feature.bounds);
        item["owner_x"] = feature.owner.x; item["owner_y"] = feature.owner.y;
        item["seed"] = hexadecimal(feature.seed); item["revision"] = hexadecimal(feature.revision);
        item["order"] = static_cast<std::int64_t>(feature.order); item["priority"] = feature.priority;
        item["children"] = grammar_strings(feature.children); item["tags"] = grammar_strings(feature.tags);
        item["sockets"] = grammar_strings(feature.sockets);
        item["ancestry"] = grammar_strings(plan.ancestry(feature.id));
        item["wall_thickness"] = feature.wall_thickness;
        item["material"] = feature.material ? Variant(static_cast<std::int64_t>(*feature.material)) : Variant();
        item["interior"] = feature.interior ? Variant(static_cast<std::int64_t>(*feature.interior)) : Variant();
        item["aggregate"] = String(feature.aggregate.c_str()); item["application"] = String(feature.application.c_str());
        item["exclusion"] = String(feature.exclusion.c_str());
        Array themes, materials;
        for (const auto& theme : feature.themes) {
            Dictionary t; t["id"] = String(theme.id.c_str()); t["weight"] = theme.weight; themes.push_back(t);
        }
        for (const auto material : feature.allowed_materials) materials.push_back(static_cast<std::int64_t>(material));
        item["themes"] = themes; item["allowed_materials"] = materials;
        Dictionary parameters;
        for (const auto& [name, value] : feature.parameters) parameters[String(name.c_str())] = grammar_value(value);
        item["parameters"] = parameters;
        features.push_back(item);
    }
    for (const auto& socket : plan.sockets()) {
        Dictionary item;
        item["id"] = String(socket.id.c_str()); item["feature_id"] = String(socket.feature_id.c_str());
        item["type"] = String(socket.type.c_str()); item["matched"] = String(socket.matched.c_str());
        item["direction"] = gen::socket_direction_name(socket.direction);
        item["owner_x"] = socket.owner.x; item["owner_y"] = socket.owner.y;
        item["x"] = socket.x; item["y"] = socket.y; item["width"] = socket.width;
        item["required"] = socket.required; item["shared"] = socket.shared;
        sockets.push_back(item);
    }
    for (const auto& route : plan.routes()) {
        Dictionary item;
        item["id"] = String(route.id.c_str()); item["type"] = String(route.type.c_str());
        item["from_socket"] = String(route.from_socket.c_str()); item["to_socket"] = String(route.to_socket.c_str());
        item["owner_x"] = route.owner.x; item["owner_y"] = route.owner.y;
        item["width"] = route.width; item["required"] = route.required;
        item["material"] = static_cast<std::int64_t>(route.material);
        Array points;
        for (const auto& point : route.points) { Array p; p.push_back(point.x); p.push_back(point.y); points.push_back(p); }
        item["points"] = points; routes.push_back(item);
    }
    for (const auto& receipt : plan.receipts()) receipts.push_back(grammar_receipt(receipt));
    for (const auto& geometry : plan.geometry_inputs()) {
        Dictionary item; item["id"] = String(geometry.id.c_str()); item["closed"] = geometry.closed;
        Array points;
        for (const auto& point : geometry.points) { Array p; p.push_back(point.x); p.push_back(point.y); points.push_back(p); }
        item["points"] = points; geometries.push_back(item);
    }
    result["features"] = features; result["sockets"] = sockets; result["routes"] = routes;
    result["receipts"] = receipts; result["geometries"] = geometries;
    return result;
}
