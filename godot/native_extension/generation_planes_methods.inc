Dictionary CyberWorldGenerator::get_plane_plan() const {
    try {
        if (!plane_plan_) return failure("no semantic planes configured");
        auto result = plane_plan_dictionary(*plane_plan_);
        Dictionary stages;
        for (unsigned p = 0; p < 4; ++p) stages[gen::plane_name(static_cast<gen::Plane>(p))] = plane_stage_names(*plane_plan_, static_cast<gen::Plane>(p));
        result["available_stages"] = stages;
        return result;
    } catch (const std::exception& error) { return failure(error.what()); }
}
Dictionary CyberWorldGenerator::copy_plane_result(const gen::PlaneResult& generated, bool complete) const {
    if (!plane_plan_ || generated.state != gen::ResultState::Ready || !plane_plan_->accepts(generated))
        return failure(generated.error.empty() ? "not a complete current semantic-plane proposal" : generated.error.c_str());
    auto result = complete ? plane_plan_dictionary(*plane_plan_) : Dictionary();
    result["ok"] = true; result["state"] = "ready"; result["complete"] = complete;
    result["bounds"] = plane_rect(generated.bounds);
    result["revision"] = hexadecimal(plane_plan_->fingerprint()); result["fingerprint"] = hexadecimal(generated.fingerprint);
    result["receipt_hash"] = hexadecimal(generated.receipt_hash);
    result["adapter_serial"] = static_cast<std::int64_t>(revision_);
    result["operations"] = static_cast<std::int64_t>(generated.operations);
    result["completed_cells"] = generated.bounds.width * generated.bounds.height;
    Dictionary materials, hashes, layers;
    for (std::size_t index = 0; index < 4; ++index) {
        const auto name = gen::plane_name(static_cast<gen::Plane>(index));
        PackedByteArray cells;
        if (cells.resize(static_cast<std::int64_t>(generated.cells[index].size())) != OK)
            return failure("cannot allocate copied semantic-plane cells");
        if (!generated.cells[index].empty()) std::memcpy(cells.ptrw(), generated.cells[index].data(), generated.cells[index].size());
        materials[name] = cells; hashes[name] = hexadecimal(generated.content_hashes[index]);
        if (complete) layers[name] = plane_rectangles(generated.cells[index], static_cast<std::int32_t>(generated.bounds.width), static_cast<std::int32_t>(generated.bounds.height));
    }
    result["materials"] = materials; result["hashes"] = hashes;
    result["actor_ids"] = grammar_strings(generated.actor_ids);
    result["fixture_ids"] = grammar_strings(generated.fixture_ids); result["link_ids"] = grammar_strings(generated.link_ids);
    if (complete) result["layers"] = layers;
    return result;
}
Dictionary CyberWorldGenerator::generate_plane_bundle() const {
    try {
        if (!plane_plan_) return failure("no semantic planes configured");
        return copy_plane_result(plane_plan_->generate(plane_plan_->bounds()), true);
    } catch (const std::exception& error) { return failure(error.what()); }
}
Dictionary CyberWorldGenerator::generate_plane_region(Rect2i bounds) const {
    try {
        if (!plane_plan_) return failure("no semantic planes configured");
        const cybersand::RectI64 area{bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y};
        return copy_plane_result(plane_plan_->generate(area), false);
    } catch (const std::exception& error) { return failure(error.what()); }
}
Dictionary CyberWorldGenerator::begin_plane_region(Rect2i bounds) {
    try {
        if (!plane_plan_) return failure("no semantic planes configured");
        auto candidate = plane_plan_->begin({bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y});
        if (plane_job_) plane_job_->cancel();
        plane_job_ = std::move(candidate);
        return advance_plane_region(0);
    } catch (const std::exception& error) { return failure(error.what()); }
}
Dictionary CyberWorldGenerator::advance_plane_region(std::int64_t budget) {
    try {
        if (!plane_job_) return failure("no semantic-plane job pending");
        if (budget < 0) return failure("cell budget must be non-negative");
        (void)plane_job_->advance(static_cast<std::size_t>(std::min<std::int64_t>(budget,1048576)));
        if (plane_job_->state() != gen::ResultState::Pending) return copy_plane_result(plane_job_->result(), false);
        Dictionary result;
        result["ok"] = true; result["state"] = "running";
        result["revision"] = hexadecimal(plane_plan_->fingerprint());
        result["adapter_serial"] = static_cast<std::int64_t>(revision_);
        result["completed_cells"] = static_cast<std::int64_t>(plane_job_->completed_cells());
        return result;
    } catch (const std::exception& error) { return failure(error.what()); }
}
Dictionary CyberWorldGenerator::cancel_plane_region() {
    if (plane_job_) plane_job_->cancel();
    plane_job_.reset();
    Dictionary result; result["ok"] = true; result["state"] = "cancelled";
    return result;
}
Dictionary CyberWorldGenerator::inspect_plane_cell(const String& plane, Vector2i position) const {
    try {
        if (!plane_plan_) return failure("no semantic planes configured");
        const auto kind = plane_value(plane, "plane");
        const auto trace = plane_plan_->explain(kind, position.x, position.y);
        Dictionary result;
        result["ok"] = true; result["plane"] = plane; result["position"] = position;
        result["x"] = position.x; result["y"] = position.y;
        result["material"] = static_cast<int>(trace.material);
        result["features"] = grammar_strings(trace.features); result["projections"] = grammar_strings(trace.projections);
        result["actors"] = grammar_strings(trace.actors);
        result["fixtures"] = grammar_strings(trace.fixtures); result["links"] = grammar_strings(trace.links);
        result["revision"] = hexadecimal(plane_plan_->fingerprint());
        result["plane_fingerprint"] = hexadecimal(plane_plan_->fingerprint());
        result["adapter_serial"] = static_cast<std::int64_t>(revision_);
        result["mode"] = "deterministic_replay"; result["proposal_hash"] = hexadecimal(trace.proposal_hash);
        result["truncated"] = trace.truncated || (trace.source && trace.source->truncated);
        result["omitted_entries"] = static_cast<std::int64_t>(trace.omitted_entries + (trace.source ? trace.source->omitted_entries : 0));
        result["max_entries_per_collection"] = static_cast<std::int64_t>(gen::kMaxTraceEntries);
        result["decisions"] = generation_decisions(trace.decisions);
        result["contributions"] = generation_contributions(trace.contributions);
        result["logical_cost"] = static_cast<std::int64_t>(plane_plan_->operations_per_cell());
        result["cost_kind"] = "conservative all-plane logical work; not elapsed time";
        result["projection_checks"] = static_cast<std::int64_t>(trace.stages.projection_checks);
        result["projection_checks_kind"] = "measured candidate index entries examined on this plane";
        Dictionary stages;
        if (trace.source) {
            result["source"] = generation_trace_dictionary(*trace.source);
            stages = generation_stage_dictionary(trace.source->stages);
        }
        stages["policy"] = static_cast<int>(trace.stages.policy); stages["base"] = static_cast<int>(trace.stages.base);
        stages["projections"] = static_cast<int>(trace.stages.projections); stages["final"] = static_cast<int>(trace.stages.final);
        result["stages"] = stages; result["available_stages"] = plane_stage_names(*plane_plan_, kind);
        Dictionary typed;
        gen::SpatialValues values;
        generator_->spatial_graph().evaluate(position.x, position.y, values);
        for (std::size_t i = 0; i < generator_->spatial_graph().nodes().size(); ++i)
            typed[String(generator_->spatial_graph().nodes()[i].id.c_str())] = grammar_value(values.values[i]);
        result["typed_fields"] = typed;
        result["unavailable"] = grammar_strings({"live simulation state", "historical per-cell execution trace", "fixture products before native simulation"});
        generation_semantic_details(result, generator_->semantic_plan(), trace.features);
        Array fixtures, links;
        for (const auto& f : plane_plan_->fixtures()) if (std::find(trace.fixtures.begin(), trace.fixtures.end(), f.id) != trace.fixtures.end()) {
            Dictionary item; item["id"] = String(f.id.c_str()); item["feature_id"] = String(f.feature_id.c_str());
            item["adapter"] = String(f.adapter.c_str()); item["bounds"] = grammar_bounds(f.bounds);
            item["mode"] = gen::fixture_mode_name(f.mode); item["material"] = static_cast<int>(f.material);
            item["clock"] = String(f.clock.c_str()); item["first_tick"] = static_cast<std::int64_t>(f.first_tick);
            item["period"] = static_cast<std::int64_t>(f.period); item["repeat"] = static_cast<std::int64_t>(f.repeat);
            item["revision"] = hexadecimal(f.revision); item["lifecycle"] = String(f.lifecycle.c_str());
            Array products; for (auto m : f.expected_products) products.push_back(static_cast<int>(m)); item["expected_products"] = products;
            fixtures.push_back(item);
        }
        for (const auto& k : plane_plan_->links()) if (std::find(trace.links.begin(), trace.links.end(), k.id) != trace.links.end()) {
            Dictionary item; item["id"] = String(k.id.c_str()); item["source_feature"] = String(k.source_feature.c_str());
            item["target_feature"] = String(k.target_feature.c_str()); item["source_plane"] = gen::plane_name(k.source_plane);
            item["target_plane"] = gen::plane_name(k.target_plane); item["family"] = gen::link_family_name(k.family);
            item["classification"] = gen::link_class_name(k.classification); item["effect"] = String(k.effect.c_str());
            item["bounds"] = grammar_bounds(k.bounds); item["revision"] = hexadecimal(k.revision); links.push_back(item);
        }
        result["fixture_details"] = fixtures; result["link_details"] = links;
        return result;
    } catch (const std::exception& error) { return failure(error.what()); }
}
