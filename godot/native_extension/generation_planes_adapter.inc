// GEN-005 value-only JSON adapter; native compiler owns relational validation.
bool plane_boolean(const Variant& value, const std::string& context) {
    if (value.get_type() != Variant::BOOL) invalid(context, "expected a boolean");
    return static_cast<bool>(value);
}
gen::Plane plane_value(const Variant& value, const std::string& context) {
    const auto parsed = gen::parse_plane(string_value(value, context));
    if (!parsed) invalid(context, "unknown plane");
    return *parsed;
}
gen::PlaneDefinition plane_definition(const Variant& value) {
    const auto input = dictionary_value(value, "semantic_planes");
    fields(input, {"schema", "id", "revision", "policies", "projections", "fixtures", "links", "actors", "limits"}, "semantic_planes");
    gen::PlaneDefinition result;
    if (input.has("schema")) result.schema = static_cast<std::uint32_t>(bounded_integer(input["schema"], 1, 1, "semantic_planes.schema"));
    if (input.has("id")) result.id = string_value(input["id"], "semantic_planes.id");
    if (input.has("revision")) result.revision = static_cast<std::uint64_t>(bounded_integer(input["revision"], 1, 9007199254740991LL, "semantic_planes.revision"));
    if (input.has("policies")) {
        const auto list = array_value(input["policies"], 4, "semantic_planes.policies");
        if (list.size() != 4) invalid("semantic_planes.policies", "all four planes must be declared");
        std::array<bool,4> seen{};
        for (std::int64_t i = 0; i < list.size(); ++i) {
            const auto item = dictionary_value(list[i], "plane policy");
            fields(item, {"plane", "material", "base_generator", "rate", "omission"}, "plane policy");
            const auto plane = plane_value(required(item, "plane", "plane policy"), "plane policy.plane");
            const auto index = static_cast<std::size_t>(plane);
            if (seen[index]) invalid("plane policy", "duplicate plane");
            seen[index] = true;
            auto& policy = result.policies[index];
            policy.plane = plane;
            if (item.has("material")) policy.material = material_value(item["material"], "plane policy.material");
            if (item.has("base_generator")) policy.base_generator = plane_boolean(item["base_generator"], "plane policy.base_generator");
            if (item.has("rate")) policy.rate = static_cast<std::uint32_t>(bounded_integer(item["rate"], 0, 60, "plane policy.rate"));
            if (item.has("omission")) policy.omission = string_value(item["omission"], "plane policy.omission");
        }
    }
    if (input.has("projections")) {
        const auto list = array_value(input["projections"], 128, "semantic_planes.projections");
        for (std::int64_t i = 0; i < list.size(); ++i) {
            const auto item = dictionary_value(list[i], "projection");
            fields(item, {"id", "rule", "plane", "geometry", "route_type", "bounds", "shape", "material", "interior", "wall_thickness", "route_width", "density", "priority", "omission", "application", "exclusion"}, "projection");
            gen::PlaneProjectionTemplate projection;
            projection.id = string_value(required(item, "id", "projection"), "projection.id");
            projection.rule = string_value(required(item, "rule", "projection"), "projection.rule");
            projection.plane = plane_value(required(item, "plane", "projection"), "projection.plane");
            if (item.has("geometry")) projection.geometry = string_value(item["geometry"], "projection.geometry");
            if (item.has("route_type")) projection.route_type = string_value(item["route_type"], "projection.route_type");
            if (item.has("bounds")) projection.bounds = bounds_value(item["bounds"], "projection.bounds");
            if (item.has("shape")) {
                const auto shape = gen::parse_projection_shape(string_value(item["shape"], "projection.shape"));
                if (!shape || *shape == gen::ProjectionShape::Native) invalid("projection.shape", "unsupported authored shape");
                projection.shape = *shape;
            }
            if (item.has("material") && item["material"].get_type() != Variant::NIL) projection.material = material_value(item["material"], "projection.material");
            if (item.has("interior") && item["interior"].get_type() != Variant::NIL) projection.interior = material_value(item["interior"], "projection.interior");
            if (item.has("wall_thickness")) projection.wall_thickness = static_cast<std::uint32_t>(bounded_integer(item["wall_thickness"], 0, 1024, "projection.wall_thickness"));
            if (item.has("route_width")) projection.route_width = static_cast<std::uint32_t>(bounded_integer(item["route_width"], 0, 1024, "projection.route_width"));
            if (item.has("density")) projection.density = number_value(item["density"], "projection.density");
            if (item.has("priority")) projection.priority = static_cast<int>(bounded_integer(item["priority"], -100000, 100000, "projection.priority"));
            if (item.has("omission")) projection.omission = string_value(item["omission"], "projection.omission");
            if (item.has("application")) projection.application = string_value(item["application"], "projection.application");
            if (item.has("exclusion")) projection.exclusion = string_value(item["exclusion"], "projection.exclusion");
            result.projections.push_back(std::move(projection));
        }
    }
    if (input.has("fixtures")) {
        const auto list = array_value(input["fixtures"], 128, "semantic_planes.fixtures");
        for (std::int64_t i = 0; i < list.size(); ++i) {
            const auto item = dictionary_value(list[i], "fixture");
            fields(item, {"id", "rule", "plane", "bounds", "material", "mode", "first_tick", "period", "repeat", "cleanup_tick", "expected_products"}, "fixture");
            gen::PlaneFixtureTemplate fixture;
            fixture.id = string_value(required(item, "id", "fixture"), "fixture.id");
            fixture.rule = string_value(required(item, "rule", "fixture"), "fixture.rule");
            fixture.plane = plane_value(required(item, "plane", "fixture"), "fixture.plane");
            fixture.bounds = bounds_value(required(item, "bounds", "fixture"), "fixture.bounds");
            fixture.material = material_value(required(item, "material", "fixture"), "fixture.material");
            if (item.has("mode")) {
                const auto mode = gen::parse_fixture_mode(string_value(item["mode"], "fixture.mode"));
                if (!mode) invalid("fixture.mode", "unknown fixture mode");
                fixture.mode = *mode;
            }
            if (item.has("first_tick")) fixture.first_tick = static_cast<std::uint64_t>(bounded_integer(item["first_tick"], 0, 360000, "fixture.first_tick"));
            if (item.has("period")) fixture.period = static_cast<std::uint64_t>(bounded_integer(item["period"], 1, 360000, "fixture.period"));
            if (item.has("repeat")) fixture.repeat = static_cast<std::uint64_t>(bounded_integer(item["repeat"], 1, 10000, "fixture.repeat"));
            if (item.has("cleanup_tick")) fixture.cleanup_tick = static_cast<std::uint64_t>(bounded_integer(item["cleanup_tick"], 0, 360000, "fixture.cleanup_tick"));
            if (item.has("expected_products")) {
                const auto products = array_value(item["expected_products"], 32, "fixture.expected_products");
                for (std::int64_t p = 0; p < products.size(); ++p) fixture.expected_products.push_back(material_value(products[p], "fixture.expected_products"));
            }
            result.fixtures.push_back(std::move(fixture));
        }
    }
    if (input.has("links")) {
        const auto list = array_value(input["links"], 128, "semantic_planes.links");
        for (std::int64_t i = 0; i < list.size(); ++i) {
            const auto item = dictionary_value(list[i], "link");
            fields(item, {"id", "rule", "target_rule", "target_slot", "family", "classification", "source_plane", "target_plane", "effect", "bounds", "material", "radius", "max_events_per_tick", "fixture"}, "link");
            gen::PlaneLinkTemplate link;
            link.id = string_value(required(item, "id", "link"), "link.id");
            link.rule = string_value(required(item, "rule", "link"), "link.rule");
            if (item.has("target_rule")) link.target_rule = string_value(item["target_rule"], "link.target_rule");
            if (item.has("target_slot")) link.target_slot = static_cast<std::uint32_t>(bounded_integer(item["target_slot"], 0, 4096, "link.target_slot"));
            const auto family = gen::parse_link_family(string_value(required(item, "family", "link"), "link.family"));
            const auto classification = gen::parse_link_class(string_value(required(item, "classification", "link"), "link.classification"));
            if (!family || !classification) invalid("link", "unknown family or classification");
            link.family = *family; link.classification = *classification;
            link.source_plane = plane_value(required(item, "source_plane", "link"), "link.source_plane");
            link.target_plane = plane_value(required(item, "target_plane", "link"), "link.target_plane");
            link.bounds = bounds_value(required(item, "bounds", "link"), "link.bounds");
            if (item.has("effect")) link.effect = string_value(item["effect"], "link.effect");
            if (item.has("material")) link.material = material_value(item["material"], "link.material");
            if (item.has("radius")) link.radius = static_cast<std::uint32_t>(bounded_integer(item["radius"], 0, 32, "link.radius"));
            if (item.has("max_events_per_tick")) link.max_events_per_tick = static_cast<std::uint32_t>(bounded_integer(item["max_events_per_tick"], 1, 256, "link.max_events_per_tick"));
            if (item.has("fixture")) link.fixture = string_value(item["fixture"], "link.fixture");
            result.links.push_back(std::move(link));
        }
    }
    if (input.has("actors")) {
        const auto list = array_value(input["actors"], 8, "semantic_planes.actors");
        for (std::int64_t i = 0; i < list.size(); ++i) {
            const auto item = dictionary_value(list[i], "actor");
            fields(item, {"id", "rule", "model", "producer", "plane", "x", "y"}, "actor");
            gen::PlaneActorTemplate actor;
            actor.id = string_value(required(item, "id", "actor"), "actor.id");
            actor.rule = string_value(required(item, "rule", "actor"), "actor.rule");
            actor.model = string_value(required(item, "model", "actor"), "actor.model");
            if (item.has("producer")) actor.producer = string_value(item["producer"], "actor.producer");
            if (item.has("plane")) actor.plane = plane_value(item["plane"], "actor.plane");
            actor.x = integer_value(required(item, "x", "actor"), "actor.x");
            actor.y = integer_value(required(item, "y", "actor"), "actor.y");
            result.actors.push_back(std::move(actor));
        }
    }
    if (input.has("limits")) {
        const auto limits = dictionary_value(input["limits"], "semantic_planes.limits");
        fields(limits, {"max_templates", "max_projections", "max_fixtures", "max_links", "max_actors", "max_cells_per_plane", "max_operations", "max_prepared_bytes", "max_publication_bytes", "max_diagnostic_bytes", "max_events_per_tick", "max_fixture_cell_writes"}, "semantic_planes.limits");
#define PLANE_LIMIT(member, maximum) if (limits.has(#member)) result.limits.member = static_cast<decltype(result.limits.member)>(bounded_integer(limits[#member], 1, maximum, "semantic_planes.limits." #member))
        PLANE_LIMIT(max_templates, 128);
        PLANE_LIMIT(max_projections, 8192);
        PLANE_LIMIT(max_fixtures, 1024);
        PLANE_LIMIT(max_links, 2048);
        PLANE_LIMIT(max_actors, 8);
        PLANE_LIMIT(max_cells_per_plane, 1048576);
        PLANE_LIMIT(max_operations, 4000000000LL);
        PLANE_LIMIT(max_prepared_bytes, 67108864);
        PLANE_LIMIT(max_publication_bytes, 268435456);
        PLANE_LIMIT(max_diagnostic_bytes, 16777216);
        PLANE_LIMIT(max_events_per_tick, 256);
        PLANE_LIMIT(max_fixture_cell_writes, 4194304);
#undef PLANE_LIMIT
    }
    return result;
}
