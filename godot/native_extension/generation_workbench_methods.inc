Dictionary CyberWorldGenerator::adopt_configuration(const Ref<CyberWorldGenerator>& prepared, std::int64_t expected_revision) {
    try {
        if (prepared.is_null() || prepared.ptr() == this || !prepared->generator_)
            return failure("prepared configuration is null, self or unconfigured");
        if (expected_revision < 0 || static_cast<std::uint64_t>(expected_revision) != revision_)
            return failure("stale receiving adapter revision");
        if (revision_ == static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max()))
            return failure("generator revision exhausted");
        if ((prepared->job_ && prepared->job_->state() == gen::ResultState::Pending) ||
            (prepared->plane_job_ && prepared->plane_job_->state() == gen::ResultState::Pending) ||
            (prepared->stage_job_ && prepared->stage_job_->state == gen::ResultState::Pending))
            return failure("prepared adapter still has pending work");
        // Prepare every potentially allocating copy and reply before touching
        // the receiving owner. Its native recipe revision/receipt stays intact.
        auto configuration = prepared->configuration_.duplicate(true);
        auto candidate = prepared->generator_; auto planes = prepared->plane_plan_;
        Dictionary result;
        result["ok"] = true; result["error"] = "";
        result["revision"] = static_cast<std::int64_t>(revision_ + 1);
        result["fingerprint"] = hexadecimal(candidate->fingerprint());
        result["native_revision"] = hexadecimal(candidate->recipe().revision);
        if (candidate->semantic_plan()) result["route_validation"] = grammar_route_validation(candidate->validate_routes());
        if (planes) result["plane_fingerprint"] = hexadecimal(planes->fingerprint());
        if (job_) job_->cancel();
        job_.reset();
        if (plane_job_) plane_job_->cancel();
        plane_job_.reset();
        stage_job_.reset(); generator_ = std::move(candidate); plane_plan_ = std::move(planes);
        configuration_ = std::move(configuration); ++revision_;
        return result;
    } catch (const std::exception& error) { return failure(error.what()); }
    catch (...) { return failure("unknown immutable configuration adoption failure"); }
}

// One bounded diagnostic job per adapter. New edits retire it only after a
// complete successful configure. Diagnostic payloads cannot enter World.
Dictionary CyberWorldGenerator::begin_stage_region(Rect2i bounds, const String& plane, const String& stage) {
    try {
        if (!generator_) return failure("no generator configured");
        const auto width = static_cast<std::int64_t>(bounds.size.x), height = static_cast<std::int64_t>(bounds.size.y);
        if (width < 1 || height < 1 || width > 256 || height > 256 || width * height > 65536)
            return failure("stage region must have axes 1..256 and at most 65536 cells");
        const auto name = string_value(stage, "stage");
        const auto base_stage = gen::parse_generation_stage(name);
        std::optional<gen::Plane> kind;
        if (!plane.is_empty() && plane_plan_) kind = plane_value(plane, "plane");
        else if (!plane.is_empty() && plane != "play") return failure("plane not configured");
        if (kind) {
            const auto domain = plane_plan_->bounds();
            if (bounds.position.x < domain.x || bounds.position.y < domain.y ||
                static_cast<std::int64_t>(bounds.position.x) + width > domain.x + domain.width ||
                static_cast<std::int64_t>(bounds.position.y) + height > domain.y + domain.height)
                return failure("stage region outside semantic window");
            if (!plane_stage_names(*plane_plan_, *kind).has(stage)) return failure("stage unavailable for this plane; choose policy/base/projections/final");
        } else if (!base_stage) return failure("unknown base generation stage");
        const auto count = static_cast<std::size_t>(width * height);
        const auto cost = (kind ? plane_plan_->operations_per_cell() : generator_->operations_per_cell()) + 16;
        const auto maximum = kind ? plane_plan_->definition().limits.max_operations : generator_->recipe().limits.max_operations_per_chunk;
        if (cost > maximum / count) return failure("stage region logical work budget exhausted");
        auto candidate = std::make_unique<StageRegionJob>();
        candidate->bounds = bounds; candidate->plane = kind; candidate->stage = name;
        candidate->revision = revision_; candidate->fingerprint = generator_->fingerprint(); candidate->cost = cost;
        candidate->cells.resize(count); candidate->final_cells.resize(count); candidate->checks.resize(count);
        stage_job_ = std::move(candidate);
        return advance_stage_region(0);
    } catch (const std::exception& error) { return failure(error.what()); }
}
Dictionary CyberWorldGenerator::advance_stage_region(std::int64_t budget) {
    try {
        if (!stage_job_) return failure("no stage job pending");
        if (budget < 0) return failure("stage cell budget must be non-negative");
        auto& job = *stage_job_;
        if (job.revision != revision_ || !generator_ || job.fingerprint != generator_->fingerprint()) {
            stage_job_.reset(); return failure("stale stage job identity");
        }
        if (job.state == gen::ResultState::Pending) {
            const auto count = std::min<std::size_t>(static_cast<std::size_t>(std::min<std::int64_t>(budget, 4096)), job.cells.size() - job.cursor);
            const auto end = job.cursor + count;
            const auto stage = gen::parse_generation_stage(job.stage);
            while (job.cursor < end) {
                const auto x = static_cast<std::int64_t>(job.bounds.position.x) + static_cast<std::int64_t>(job.cursor % static_cast<std::size_t>(job.bounds.size.x));
                const auto y = static_cast<std::int64_t>(job.bounds.position.y) + static_cast<std::int64_t>(job.cursor / static_cast<std::size_t>(job.bounds.size.x));
                if (job.plane) {
                    const auto sampled = plane_plan_->stages(*job.plane, x, y);
                    job.final_cells[job.cursor] = sampled.final;
                    job.checks[job.cursor] = static_cast<std::int32_t>(sampled.projection_checks);
                    if (job.stage == "policy") job.cells[job.cursor] = sampled.policy;
                    else if (job.stage == "base") job.cells[job.cursor] = sampled.base;
                    else if (job.stage == "projections") job.cells[job.cursor] = sampled.projections;
                    else if (job.stage == "final") job.cells[job.cursor] = sampled.final;
                    else if (stage && sampled.has_source) job.cells[job.cursor] = sampled.source.at(*stage);
                    else throw std::logic_error("unavailable plane stage reached execution");
                } else {
                    const auto sampled = generator_->stages(x, y);
                    job.cells[job.cursor] = sampled.at(*stage); job.final_cells[job.cursor] = sampled.at(gen::GenerationStage::Final);
                    job.checks[job.cursor] = 0;
                }
                ++job.cursor; job.operations += job.cost;
            }
            if (job.cursor == job.cells.size()) job.state = gen::ResultState::Ready;
        }
        Dictionary result;
        result["ok"] = true; result["state"] = state_name(job.state); result["bounds"] = job.bounds;
        result["revision"] = static_cast<std::int64_t>(job.revision); result["adapter_serial"] = static_cast<std::int64_t>(job.revision);
        result["fingerprint"] = hexadecimal(job.fingerprint);
        if (job.plane) result["plane_fingerprint"] = hexadecimal(plane_plan_->fingerprint());
        result["plane"] = job.plane ? gen::plane_name(*job.plane) : "play"; result["stage"] = String(job.stage.c_str());
        result["completed_cells"] = static_cast<std::int64_t>(job.cursor); result["operations"] = static_cast<std::int64_t>(job.operations);
        result["cost_kind"] = "conservative logical work; not elapsed time";
        result["origin"] = "actual intermediate of accepted native pipeline";
        result["projection_checks_kind"] = job.plane ? "measured candidate index entries examined" : "unavailable without semantic planes";
        if (job.state == gen::ResultState::Ready) {
            PackedByteArray cells, final_cells;
            PackedInt32Array checks;
            if (cells.resize(static_cast<std::int64_t>(job.cells.size())) != OK ||
                final_cells.resize(static_cast<std::int64_t>(job.final_cells.size())) != OK ||
                checks.resize(static_cast<std::int64_t>(job.checks.size())) != OK) throw std::runtime_error("cannot allocate copied stage region");
            std::memcpy(cells.ptrw(), job.cells.data(), job.cells.size());
            std::memcpy(final_cells.ptrw(), job.final_cells.data(), job.final_cells.size());
            std::memcpy(checks.ptrw(), job.checks.data(), job.checks.size()*sizeof(std::int32_t));
            result["cells"] = cells; result["stage_cells"] = cells; result["final_cells"] = final_cells; result["projection_checks"] = checks;
            // Material checksum is separate from revision/session admission.
            std::uint64_t h = UINT64_C(14695981039346656037);
            for (const auto value : job.cells) h = (h ^ static_cast<unsigned>(value)) * UINT64_C(1099511628211);
            result["hash"] = hexadecimal(h);
        }
        return result;
    } catch (const std::exception& error) { stage_job_.reset(); return failure(error.what()); }
    catch (...) { stage_job_.reset(); return failure("unknown stage generation failure"); }
}
Dictionary CyberWorldGenerator::cancel_stage_region() {
    stage_job_.reset();
    Dictionary result; result["ok"] = true; result["state"] = "cancelled";
    return result;
}
