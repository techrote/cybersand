// GEN-007: copied, bounded native replay. No World or preview cache is sampled.
Dictionary generation_stage_dictionary(const gen::GenerationStages& stages) {
    Dictionary result;
    for (std::size_t i = 0; i < gen::kGenerationStageCount; ++i)
        result[gen::generation_stage_name(static_cast<gen::GenerationStage>(i))] = static_cast<int>(stages.materials[i]);
    return result;
}
Array generation_stage_names() {
    Array result;
    for (std::size_t i = 0; i < gen::kGenerationStageCount; ++i)
        result.push_back(gen::generation_stage_name(static_cast<gen::GenerationStage>(i)));
    return result;
}
Array plane_stage_names(const gen::PlanePlan& plan, gen::Plane plane) {
    Array result;
    if (plan.definition().policies[static_cast<std::size_t>(plane)].base_generator) result = generation_stage_names();
    for (const char* name : {"policy", "base", "projections", "final"}) if (!result.has(name)) result.push_back(name);
    return result;
}
Dictionary generation_parameters(const gen::Parameters& p) {
    Dictionary result;
#define GEN_TRACE_PARAMETER(key) result[#key] = p.key
    GEN_TRACE_PARAMETER(surface_y); GEN_TRACE_PARAMETER(relief); GEN_TRACE_PARAMETER(feature_scale);
    GEN_TRACE_PARAMETER(cave_threshold); GEN_TRACE_PARAMETER(strata_period); GEN_TRACE_PARAMETER(warp);
    GEN_TRACE_PARAMETER(corridor_width); GEN_TRACE_PARAMETER(district_size); GEN_TRACE_PARAMETER(room_size);
    GEN_TRACE_PARAMETER(wall_thickness); GEN_TRACE_PARAMETER(detail); GEN_TRACE_PARAMETER(fluid_level);
#undef GEN_TRACE_PARAMETER
    return result;
}
Array generation_decisions(const std::vector<gen::EvaluationDecision>& decisions) {
    Array result;
    for (const auto& d : decisions) {
        Dictionary item;
        item["stage"] = String(d.stage.c_str()); item["id"] = String(d.id.c_str());
        item["application"] = String(d.application.c_str()); item["exclusion"] = String(d.exclusion.c_str());
        item["application_value"] = d.application_value; item["exclusion_value"] = d.exclusion_value;
        item["strength"] = d.strength; item["shape"] = d.shape; item["influence"] = d.influence;
        item["predicate"] = String(d.predicate.c_str()); item["context_passed"] = d.context_passed;
        item["draw"] = d.draw; item["draw_used"] = d.draw_used; item["accepted"] = d.accepted;
        item["detail"] = String(d.detail.c_str()); item["origin"] = "deterministic_replay";
        result.push_back(item);
    }
    return result;
}
Array generation_contributions(const std::vector<gen::MaterialContribution>& contributions) {
    Array result;
    for (const auto& c : contributions) {
        Dictionary item;
        item["stage"] = String(c.stage.c_str()); item["id"] = String(c.id.c_str());
        item["before"] = static_cast<int>(c.before); item["after"] = static_cast<int>(c.after);
        item["influence"] = c.influence; result.push_back(item);
    }
    return result;
}
Dictionary generation_trace_dictionary(const gen::CellProvenance& trace) {
    Dictionary result;
    result["ok"] = true; result["x"] = trace.x; result["y"] = trace.y;
    result["material"] = static_cast<int>(trace.material); result["initial_material"] = static_cast<int>(trace.initial_material);
    result["initial_candidate"] = gen::candidate_name(trace.initial_candidate);
    result["effective_candidate"] = gen::candidate_name(trace.effective_candidate);
    result["initial_parameters"] = generation_parameters(trace.initial_parameters);
    result["effective_parameters"] = generation_parameters(trace.effective_parameters);
    result["native_revision"] = hexadecimal(trace.revision); result["fingerprint"] = hexadecimal(trace.fingerprint);
    result["proposal_hash"] = hexadecimal(trace.proposal_hash); result["mode"] = "deterministic_replay";
    result["accepted_feature_id"] = String(trace.accepted_feature_id.c_str());
    result["logical_cost"] = static_cast<std::int64_t>(trace.logical_cost);
    result["cost_kind"] = "conservative logical work; not elapsed time";
    result["truncated"] = trace.truncated; result["omitted_entries"] = static_cast<std::int64_t>(trace.omitted_entries);
    result["max_entries_per_collection"] = static_cast<std::int64_t>(gen::kMaxTraceEntries);
    result["context_evaluated"] = trace.context_evaluated;
    Dictionary context;
    if (trace.context_evaluated) {
        context["occupied"] = trace.context.occupied; context["solid"] = trace.context.solid;
        context["fluid"] = trace.context.fluid; context["depth"] = trace.context.depth;
        context["slope"] = trace.context.slope; context["route"] = trace.context.route;
        context["material"] = trace.context.material;
    }
    result["initial_context"] = context;
    result["ancestry"] = grammar_strings(trace.ancestry);
    Array receipts, aggregates;
    for (const auto& receipt : trace.constraints) {
        auto item = grammar_receipt(receipt); item["origin"] = "recorded_semantic_plan";
        item["scope"] = "accepted ancestry or containing canonical region";
        receipts.push_back(item);
    }
    for (const auto& a : trace.aggregates) {
        Dictionary item;
        item["id"] = String(a.id.c_str()); item["source"] = String(a.source.c_str());
        item["selector"] = a.selector; item["material"] = static_cast<int>(a.material);
        Array components;
        for (const auto& c : a.components) {
            Dictionary component; component["material"] = static_cast<int>(c.material); component["weight"] = c.weight;
            components.push_back(component);
        }
        item["components"] = components; aggregates.push_back(item);
    }
    Dictionary scalar, typed;
    for (const auto& [name, value] : trace.scalar_fields) scalar[String(name.c_str())] = value;
    for (const auto& [name, value] : trace.typed_fields) typed[String(name.c_str())] = grammar_value(value);
    result["constraints"] = receipts; result["contributions"] = generation_contributions(trace.contributions);
    result["decisions"] = generation_decisions(trace.decisions); result["aggregates"] = aggregates;
    result["scalar_fields"] = scalar; result["typed_fields"] = typed;
    result["stages"] = generation_stage_dictionary(trace.stages); result["available_stages"] = generation_stage_names();
    result["unavailable"] = grammar_strings({"live simulation state", "historical per-cell execution trace", "native module internal branches beyond returned material"});
    return result;
}
void generation_semantic_details(Dictionary& result, const gen::GrammarPlan* plan, const std::vector<std::string>& feature_ids) {
    Array features, sockets, routes;
    bool truncated = static_cast<bool>(result.get("truncated", false));
    std::set<std::string> selected;
    if (plan) for (const auto& id : feature_ids) {
        for (const auto& ancestor : plan->ancestry(id)) selected.insert(ancestor);
    }
    if (plan) for (const auto& id : selected) {
        const auto* f = plan->feature(id); if (!f) continue;
        if (features.size() >= static_cast<std::int64_t>(gen::kMaxTraceEntries)) { truncated = true; break; }
        Dictionary item;
        item["id"] = String(f->id.c_str()); item["parent"] = String(f->parent.c_str());
        item["rule_id"] = String(f->rule_id.c_str()); item["candidate_id"] = String(f->candidate_id.c_str());
        item["kind"] = gen::semantic_kind_name(f->kind); item["bounds"] = grammar_bounds(f->bounds);
        item["revision"] = hexadecimal(f->revision); item["seed"] = hexadecimal(f->seed);
        item["ancestry"] = grammar_strings(plan->ancestry(f->id)); item["sockets"] = grammar_strings(f->sockets);
        item["tags"] = grammar_strings(f->tags); features.push_back(item);
    }
    std::set<std::string> socket_ids;
    if (plan) for (const auto& s : plan->sockets()) if (selected.contains(s.feature_id)) {
        if (sockets.size() >= static_cast<std::int64_t>(gen::kMaxTraceEntries)) { truncated = true; break; }
        Dictionary item;
        item["id"] = String(s.id.c_str()); item["feature_id"] = String(s.feature_id.c_str());
        item["type"] = String(s.type.c_str()); item["matched"] = String(s.matched.c_str());
        item["direction"] = gen::socket_direction_name(s.direction); item["width"] = s.width;
        item["x"] = s.x; item["y"] = s.y; item["required"] = s.required; item["shared"] = s.shared;
        sockets.push_back(item); socket_ids.insert(s.id);
    }
    std::set<std::string> contributing_routes;
    const Array contributions = result.get("contributions", Array());
    for (std::int64_t i = 0; i < contributions.size(); ++i) {
        const Dictionary c = contributions[i];
        if (c.has("id")) contributing_routes.insert(std::string(String(c["id"]).utf8().get_data()));
    }
    if (plan) for (const auto& r : plan->routes()) if (socket_ids.contains(r.from_socket) || socket_ids.contains(r.to_socket) || contributing_routes.contains(r.id)) {
        if (routes.size() >= static_cast<std::int64_t>(gen::kMaxTraceEntries)) { truncated = true; break; }
        Dictionary item;
        item["id"] = String(r.id.c_str()); item["type"] = String(r.type.c_str());
        item["from_socket"] = String(r.from_socket.c_str()); item["to_socket"] = String(r.to_socket.c_str());
        item["width"] = r.width; item["required"] = r.required; item["material"] = static_cast<int>(r.material);
        Array points; for (const auto& point : r.points) { Array p; p.push_back(point.x); p.push_back(point.y); points.push_back(p); }
        item["points"] = points; routes.push_back(item);
    }
    result["semantic_features"] = features; result["sockets"] = sockets; result["routes"] = routes;
    result["truncated"] = truncated;
}
