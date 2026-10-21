Dictionary CyberWorldGenerator::get_plane_plan() const {
    try {
        if (!plane_plan_) return failure("no semantic planes configured");
        return plane_plan_dictionary(*plane_plan_);
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
        result["material"] = static_cast<int>(trace.material);
        result["features"] = grammar_strings(trace.features); result["projections"] = grammar_strings(trace.projections);
        result["actors"] = grammar_strings(trace.actors);
        result["fixtures"] = grammar_strings(trace.fixtures); result["links"] = grammar_strings(trace.links);
        result["revision"] = hexadecimal(plane_plan_->fingerprint());
        return result;
    } catch (const std::exception& error) { return failure(error.what()); }
}
