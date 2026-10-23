// Included inside the generator adapter's private namespace. Shared strict
// scalar/array/typed-value decoders are defined by cyber_world_generator.cpp.
bool grammar_boolean(const Variant& value, const std::string& context) {
    if (value.get_type() != Variant::BOOL) invalid(context, "expected a boolean");
    return static_cast<bool>(value);
}

std::vector<gen::GrammarTheme> grammar_themes(const Variant& value, const std::string& context) {
    std::vector<gen::GrammarTheme> result;
    const auto array = array_value(value, 16, context);
    for (std::int64_t i = 0; i < array.size(); ++i) {
        const auto item = dictionary_value(array[i], context);
        fields(item, {"id", "weight"}, context);
        result.push_back({string_value(required(item, "id", context), context),
            item.has("weight") ? number_value(item["weight"], context) : 1});
    }
    return result;
}

gen::GrammarConstraints grammar_constraints(const Variant& value) {
    const auto item = dictionary_value(value, "grammar.constraints");
    fields(item, {"intersects_route", "minimum_separation", "floor", "ceiling", "wall", "open_volume",
        "service", "required_neighbors", "forbidden_neighbors", "neighbor_distance", "exclusive_family",
        "minimum_sockets", "maximum_sockets", "connected", "occupancy_min", "occupancy_max"}, "grammar.constraints");
    gen::GrammarConstraints result;
    const auto boolean = [&](const char* name, bool& target) {
        if (item.has(name)) target = grammar_boolean(item[name], std::string("grammar.constraints.") + name);
    };
    boolean("intersects_route", result.intersects_route); boolean("floor", result.floor);
    boolean("ceiling", result.ceiling); boolean("wall", result.wall); boolean("open_volume", result.open_volume);
    boolean("connected", result.connected);
    if (item.has("minimum_separation")) result.minimum_separation = number_value(item["minimum_separation"], "minimum_separation");
    if (item.has("neighbor_distance")) result.neighbor_distance = number_value(item["neighbor_distance"], "neighbor_distance");
    if (item.has("occupancy_min")) result.occupancy_min = number_value(item["occupancy_min"], "occupancy_min");
    if (item.has("occupancy_max")) result.occupancy_max = number_value(item["occupancy_max"], "occupancy_max");
    if (item.has("service")) result.service = string_value(item["service"], "service");
    if (item.has("exclusive_family")) result.exclusive_family = string_value(item["exclusive_family"], "exclusive_family");
    if (item.has("required_neighbors")) result.required_neighbors = strings(item["required_neighbors"], 32, "required_neighbors");
    if (item.has("forbidden_neighbors")) result.forbidden_neighbors = strings(item["forbidden_neighbors"], 32, "forbidden_neighbors");
    if (item.has("minimum_sockets")) result.minimum_sockets = static_cast<std::uint32_t>(bounded_integer(item["minimum_sockets"], 0, 16, "minimum_sockets"));
    if (item.has("maximum_sockets")) result.maximum_sockets = static_cast<std::uint32_t>(bounded_integer(item["maximum_sockets"], 0, 16, "maximum_sockets"));
    return result;
}

gen::GrammarDefinition grammar_definition(const Variant& value) {
    const auto item = dictionary_value(value, "grammar");
    fields(item, {"schema", "id", "region_window", "region_size", "roots", "rules", "curve", "curve_order",
        "route_width", "clearance", "secondary_loop", "service_trunk", "liquid_trunk", "curve_services", "service_material",
        "liquid_material", "district_assignment", "district_themes", "geometry_exports", "limits"}, "grammar");
    gen::GrammarDefinition result;
    if (item.has("schema")) result.schema = static_cast<std::uint32_t>(bounded_integer(item["schema"], 1, 1, "grammar.schema"));
    if (item.has("id")) result.id = string_value(item["id"], "grammar.id");
    if (item.has("region_window")) result.region_window = bounds_value(item["region_window"], "grammar.region_window");
    if (item.has("region_size")) result.region_size = static_cast<std::int32_t>(bounded_integer(item["region_size"], 32, 4096, "grammar.region_size"));
    if (item.has("roots")) result.roots = strings(item["roots"], 32, "grammar.roots");
    if (item.has("curve")) {
        const auto parsed = gen::parse_grammar_curve(string_value(item["curve"], "grammar.curve"));
        if (!parsed) invalid("grammar.curve", "unknown finite curve");
        result.curve = *parsed;
    }
    if (item.has("curve_order")) result.curve_order = static_cast<std::uint32_t>(bounded_integer(item["curve_order"], 1, 12, "grammar.curve_order"));
    if (item.has("route_width")) result.route_width = static_cast<std::uint32_t>(bounded_integer(item["route_width"], 1, 63, "grammar.route_width"));
    if (item.has("clearance")) result.clearance = static_cast<std::uint32_t>(bounded_integer(item["clearance"], 1, 63, "grammar.clearance"));
    for (const auto& [name, destination] : std::initializer_list<std::pair<const char*, bool*>>{
        {"secondary_loop", &result.secondary_loop}, {"service_trunk", &result.service_trunk}, {"liquid_trunk", &result.liquid_trunk}, {"curve_services", &result.curve_services}})
        if (item.has(name)) *destination = grammar_boolean(item[name], name);
    if (item.has("service_material")) result.service_material = material_value(item["service_material"], "grammar.service_material");
    if (item.has("liquid_material")) result.liquid_material = material_value(item["liquid_material"], "grammar.liquid_material");
    if (item.has("geometry_exports")) result.geometry_exports = string_bindings(item["geometry_exports"], "grammar.geometry_exports");
    if (item.has("district_assignment")) {
        auto assignment = dictionary_value(item["district_assignment"], "grammar.district_assignment").duplicate(true);
        fields(assignment, {"specification", "limits"}, "grammar.district_assignment");
        assignment["id"] = "grammar-districts";
        Array assignments; assignments.push_back(assignment);
        Dictionary definition; definition["assignments"] = assignments;
        const auto parsed = spatial_definition(definition);
        result.district_assignment = parsed.assignments.front().specification;
        result.assignment_limits = parsed.assignments.front().limits;
    }
    if (item.has("district_themes")) {
        const auto themes = dictionary_value(item["district_themes"], "grammar.district_themes");
        if (themes.size() > 16) invalid("grammar.district_themes", "at most 16 categories");
        const auto keys = themes.keys();
        for (std::int64_t i = 0; i < keys.size(); ++i)
            result.district_themes.emplace(exact_unsigned_value(keys[i], "grammar.district_themes key"), grammar_themes(themes[keys[i]], "grammar.district_themes"));
    }
    if (item.has("limits")) {
        const auto limits = dictionary_value(item["limits"], "grammar.limits");
        fields(limits, {"max_regions", "max_rules", "max_depth", "max_children", "max_candidates", "max_features",
            "max_sockets", "max_routes", "max_work", "max_prepared_bytes", "max_raster_cells", "max_raster_operations"}, "grammar.limits");
        const auto bound = [&](const char* name, std::uint64_t maximum) {
            return limits.has(name) ? static_cast<std::uint64_t>(bounded_integer(limits[name], 1,
                static_cast<std::int64_t>(maximum), std::string("grammar.limits.") + name)) : maximum;
        };
        auto& out = result.limits;
        out.max_regions = bound("max_regions", out.max_regions); out.max_rules = bound("max_rules", out.max_rules);
        out.max_depth = bound("max_depth", out.max_depth); out.max_children = bound("max_children", out.max_children);
        out.max_candidates = bound("max_candidates", out.max_candidates); out.max_features = bound("max_features", out.max_features);
        out.max_sockets = bound("max_sockets", out.max_sockets); out.max_routes = bound("max_routes", out.max_routes);
        out.max_work = bound("max_work", out.max_work); out.max_prepared_bytes = bound("max_prepared_bytes", out.max_prepared_bytes);
        out.max_raster_cells = bound("max_raster_cells", out.max_raster_cells);
        if (limits.has("max_raster_operations")) out.max_raster_operations = static_cast<std::uint64_t>(
            bounded_integer(limits["max_raster_operations"], 1, INT64_C(16'000'000'000), "grammar.limits.max_raster_operations"));
    }
    if (item.has("rules")) {
        const auto rules = array_value(item["rules"], 64, "grammar.rules");
        for (std::int64_t i = 0; i < rules.size(); ++i) {
            const auto rule = dictionary_value(rules[i], "grammar.rule");
            fields(rule, {"id", "kind", "count", "priority", "tags", "themes", "parameters", "allowed_materials", "candidates",
                "children", "sockets", "constraints", "preferences", "fallback", "material", "interior", "wall_thickness",
                "aggregate", "application", "exclusion"}, "grammar.rule");
            gen::GrammarRule out;
            out.id = string_value(required(rule, "id", "grammar.rule"), "grammar.rule.id");
            if (rule.has("kind")) {
                const auto parsed = gen::parse_semantic_kind(string_value(rule["kind"], "grammar.rule.kind"));
                if (!parsed) invalid("grammar.rule.kind", "unknown semantic kind");
                out.kind = *parsed;
            }
            out.priority = priority_value(rule, "grammar.rule");
            if (rule.has("count")) out.count = static_cast<std::uint32_t>(bounded_integer(rule["count"], 0, 32, "grammar.rule.count"));
            if (rule.has("tags")) out.tags = strings(rule["tags"], 32, "grammar.rule.tags");
            if (rule.has("themes")) out.themes = grammar_themes(rule["themes"], "grammar.rule.themes");
            if (rule.has("children")) out.children = strings(rule["children"], 32, "grammar.rule.children");
            if (rule.has("parameters")) {
                const auto parameters = dictionary_value(rule["parameters"], "grammar.rule.parameters");
                if (parameters.size() > 32) invalid("grammar.rule.parameters", "too many typed parameters");
                const auto keys = parameters.keys();
                for (std::int64_t j = 0; j < keys.size(); ++j)
                    out.parameters.emplace(string_value(keys[j], "grammar.parameter.id"), spatial_value(parameters[keys[j]], "grammar.parameter.value"));
            }
            if (rule.has("allowed_materials")) {
                const auto materials = array_value(rule["allowed_materials"], 256, "grammar.allowed_materials");
                for (std::int64_t j = 0; j < materials.size(); ++j) out.allowed_materials.push_back(material_value(materials[j], "grammar.allowed_materials"));
            }
            if (rule.has("candidates")) {
                const auto candidates = array_value(rule["candidates"], 64, "grammar.candidates");
                for (std::int64_t j = 0; j < candidates.size(); ++j) {
                    const auto candidate = dictionary_value(candidates[j], "grammar.candidate");
                    fields(candidate, {"id", "bounds", "order_x", "order_y"}, "grammar.candidate");
                    gen::GrammarCandidate c;
                    c.id = string_value(required(candidate, "id", "grammar.candidate"), "grammar.candidate.id");
                    c.bounds = bounds_value(required(candidate, "bounds", "grammar.candidate"), "grammar.candidate.bounds");
                    if (candidate.has("order_x")) c.order_x = static_cast<std::uint32_t>(bounded_integer(candidate["order_x"], 0, 1'000'000, "grammar.candidate.order_x"));
                    if (candidate.has("order_y")) c.order_y = static_cast<std::uint32_t>(bounded_integer(candidate["order_y"], 0, 1'000'000, "grammar.candidate.order_y"));
                    out.candidates.push_back(std::move(c));
                }
            }
            if (rule.has("sockets")) {
                const auto sockets = array_value(rule["sockets"], 16, "grammar.sockets");
                for (std::int64_t j = 0; j < sockets.size(); ++j) {
                    const auto socket = dictionary_value(sockets[j], "grammar.socket");
                    fields(socket, {"id", "type", "direction", "offset", "width", "required", "attach_to_route"}, "grammar.socket");
                    gen::GrammarSocket s;
                    s.id = string_value(required(socket, "id", "grammar.socket"), "grammar.socket.id");
                    if (socket.has("type")) s.type = string_value(socket["type"], "grammar.socket.type");
                    if (socket.has("direction")) {
                        const auto parsed = gen::parse_socket_direction(string_value(socket["direction"], "grammar.socket.direction"));
                        if (!parsed) invalid("grammar.socket.direction", "expected west/east/north/south");
                        s.direction = *parsed;
                    }
                    if (socket.has("offset")) s.offset = integer_value(socket["offset"], "grammar.socket.offset");
                    if (socket.has("width")) s.width = static_cast<std::uint32_t>(bounded_integer(socket["width"], 1, 63, "grammar.socket.width"));
                    if (socket.has("required")) s.required = grammar_boolean(socket["required"], "grammar.socket.required");
                    if (socket.has("attach_to_route")) s.attach_to_route = grammar_boolean(socket["attach_to_route"], "grammar.socket.attach_to_route");
                    out.sockets.push_back(std::move(s));
                }
            }
            if (rule.has("constraints")) out.constraints = grammar_constraints(rule["constraints"]);
            if (rule.has("preferences")) {
                const auto preferences = array_value(rule["preferences"], 16, "grammar.preferences");
                for (std::int64_t j = 0; j < preferences.size(); ++j) {
                    const auto preference = dictionary_value(preferences[j], "grammar.preference");
                    fields(preference, {"id", "kind", "weight", "themes"}, "grammar.preference");
                    gen::GrammarPreference p;
                    p.id = string_value(required(preference, "id", "grammar.preference"), "grammar.preference.id");
                    if (preference.has("kind")) p.kind = string_value(preference["kind"], "grammar.preference.kind");
                    if (preference.has("weight")) p.weight = number_value(preference["weight"], "grammar.preference.weight");
                    if (preference.has("themes")) p.themes = strings(preference["themes"], 16, "grammar.preference.themes");
                    out.preferences.push_back(std::move(p));
                }
            }
            if (rule.has("fallback")) {
                const auto fallback = string_value(rule["fallback"], "grammar.fallback");
                if (fallback != "reject" && fallback != "omit") invalid("grammar.fallback", "expected reject or omit");
                out.fallback = fallback == "omit" ? gen::GrammarFallback::Omit : gen::GrammarFallback::Reject;
            }
            if (rule.has("material")) out.material = rule["material"].get_type() == Variant::NIL ? std::nullopt : std::optional(material_value(rule["material"], "grammar.material"));
            if (rule.has("interior")) out.interior = rule["interior"].get_type() == Variant::NIL ? std::nullopt : std::optional(material_value(rule["interior"], "grammar.interior"));
            if (rule.has("wall_thickness")) out.wall_thickness = static_cast<std::uint32_t>(bounded_integer(rule["wall_thickness"], 0, 64, "grammar.wall_thickness"));
            if (rule.has("aggregate")) out.aggregate = string_value(rule["aggregate"], "grammar.aggregate");
            if (rule.has("application")) out.application = string_value(rule["application"], "grammar.application");
            if (rule.has("exclusion")) out.exclusion = string_value(rule["exclusion"], "grammar.exclusion");
            result.rules.push_back(std::move(out));
        }
    }
    return result;
}
