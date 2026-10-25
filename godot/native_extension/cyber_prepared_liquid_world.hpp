#pragma once

#include "cyber_prepared_level_payload.hpp"
#include "cybersand/default_demo_recipe.hpp"

// Implementation of the adapter-owned preparation slot. No native World
// pointer crosses the Godot boundary; only a token and copied value receipts do.
namespace godot {
namespace prepared_liquid_detail {
inline Dictionary encoding(const cybersand::receipt::ReceiptEncoding& value, const char* kind) {
    Dictionary out;
    PackedByteArray bytes;
    const auto source = value.canonical_bytes();
    bytes.resize(static_cast<std::int64_t>(source.size()));
    std::copy(source.begin(), source.end(), bytes.ptrw());
    out["kind"] = kind;
    out["schema_version"] = 1;
    out["canonical_bytes"] = bytes;
    out["receipt_hash"] = String(cybersand::Sha256::hex(value.receipt_hash()).c_str());
    out["qualifications"] = static_cast<std::int64_t>(value.qualifications());
    out["eligible_for_full_matched_evidence"] = value.eligible_for_full_matched_evidence();
    return out;
}
inline String digest(const cybersand::Sha256::Digest& value) {
    return String(cybersand::Sha256::hex(value).c_str());
}
} // namespace prepared_liquid_detail

inline std::int64_t CyberDemoBridge::prepare_liquid_world(
    const Ref<CyberNativeCellWorld>& adapter, const PackedInt32Array& rectangles,
    const PackedInt32Array& profile, const PackedInt32Array& policy,
    const PackedInt32Array& water_fills, const PackedInt32Array& liquid_policy,
    const Dictionary& options) {
    return prepare_liquid_candidate(adapter, rectangles, profile, policy, water_fills, liquid_policy, options, nullptr);
}

inline std::int64_t CyberDemoBridge::prepare_liquid_level(
    const Ref<CyberNativeCellWorld>& adapter, const PackedByteArray& payload,
    const PackedInt32Array& profile, const PackedInt32Array& policy,
    const PackedInt32Array& liquid_policy, const Dictionary& options) {
    return prepare_liquid_candidate(adapter, {}, profile, policy, {}, liquid_policy, options, &payload);
}

inline std::int64_t CyberDemoBridge::prepare_liquid_default_demo(
    const Ref<CyberNativeCellWorld>& adapter, const PackedInt32Array& liquid_policy,
    const Dictionary& options) {
    // Water precision and independent transport tuning are inherited exactly as
    // in reset_demo_world(), rather than replaced by an implicit Baseline.
    return prepare_liquid_candidate(adapter, {}, {}, {}, {}, liquid_policy, options, nullptr, true);
}

inline std::int64_t CyberDemoBridge::prepare_liquid_candidate(
    const Ref<CyberNativeCellWorld>& adapter, const PackedInt32Array& rectangles,
    const PackedInt32Array& profile, const PackedInt32Array& policy,
    const PackedInt32Array& water_fills, const PackedInt32Array& liquid_policy,
    const Dictionary& options, const PackedByteArray* level_payload, bool default_demo) {
    error_ = String();
    last_liquid_policy_refusal_.clear();
    if (adapter.is_null() || !adapter->world_ || adapter->world_->has_failed()) {
        error_ = "Healthy native World required for prepared replacement";
        return 0;
    }
    // A newer preparation always retires the preceding token, including when
    // the new request refuses. There is exactly one construction candidate.
    adapter->pending_liquid_world_.reset();
    adapter->liquid_construction_attempt_.clear();
    try {
        const auto retained_before = adapter->liquid_policy_session_generation_ != 0
            ? std::make_unique<cybersand::receipt::NativeFacts>(cybersand::receipt::capture_native_facts(
                *adapter->world_, adapter->applied_liquid_setup_)) : nullptr;
        const auto request = std::span<const std::int32_t>(liquid_policy.ptr(),
            static_cast<std::size_t>(liquid_policy.size()));
        const auto record_refusal = [&](const cybersand::ConstructionRefusal& refusal) {
            if (refusal.policy_refusal()) refuse_liquid_policy(*refusal.policy_refusal());
            else error_ = String(std::string(refusal.failure_detail()).c_str());
            // Initial legacy Worlds have no committed construction generation.
            // Never fabricate a native attempt receipt for that state.
            if (adapter->liquid_policy_session_generation_ != 0) {
                const auto after = std::make_unique<cybersand::receipt::NativeFacts>(
                    cybersand::receipt::capture_native_facts(*adapter->world_, adapter->applied_liquid_setup_));
                const auto attempt = cybersand::receipt::build_construction_attempt_receipt(*retained_before, *after,
                    refusal, adapter->liquid_policy_session_generation_, adapter->liquid_policy_session_generation_);
                adapter->liquid_construction_attempt_ = prepared_liquid_detail::encoding(attempt, "construction_attempt");
            }
        };
        if (const auto refused = cybersand::validate_liquid_policy_request(request)) {
            record_refusal(*refused);
            return 0;
        }
        const auto decoded = cybersand::LiquidSolverPolicy::decode(request);
        if (!default_demo && (policy.size() != 4 || policy[0] != 1 || policy[1] < 3 || policy[1] > 8 ||
            policy[2] < 0 || policy[2] > 12 || policy[3] != 0))
            throw std::invalid_argument("Invalid Water experiment policy");
        const PackedInt32Array region = options.get("region", PackedInt32Array());
        if (region.size() != 4 || region[0] < 0 || region[1] < 0 || region[2] < 1 || region[3] < 1 ||
            region[2] > cybersand::demo::kWidth || region[3] > cybersand::demo::kHeight ||
            region[0] > cybersand::demo::kWidth - region[2] || region[1] > cybersand::demo::kHeight - region[3])
            throw std::invalid_argument("Controlled preparation requires a finite final simulation region");
        const String intent = options.get("intent", String("controlled"));
        const String pacing = options.get("pacing", String("fixed_steps"));
        if ((intent != "controlled" && intent != "exploratory") ||
            (pacing != "fixed_steps" && pacing != "host_paced"))
            throw std::invalid_argument("Unknown prepared host intent or pacing");
        const bool window = options.get("simulation_window_enabled", true);
        if (!window && (region[0] != 0 || region[1] != 0 ||
            region[2] != cybersand::demo::kWidth || region[3] != cybersand::demo::kHeight))
            throw std::invalid_argument("Disabled simulation window requires the full finite World region");
        const String rule = options.get("normalization", String());
        if (!rule.is_empty() && rule != "water-normalize-v1")
            throw std::invalid_argument("Unknown normalization rule");
        const auto seed = static_cast<std::int64_t>(options.get("seed", std::int64_t{0}));
        if (seed < 0) throw std::invalid_argument("Negative setup seed");
        const String definition_hash = options.get("definition_hash", String());
        const auto definition_bytes = definition_hash.hex_decode();
        if (level_payload == nullptr && !default_demo && (definition_hash.length() != 64 || definition_bytes.size() != 32))
            throw std::invalid_argument("Controlled preparation requires a definition SHA256 claim");
        if ((level_payload != nullptr || default_demo) && options.has("definition_hash"))
            throw std::invalid_argument("Native prepared input does not accept a caller definition hash claim");
        if (default_demo && seed != 0)
            throw std::invalid_argument("The native default demo recipe has fixed seed zero");
        auto config = std::make_unique<cybersand::WorldConfig>(adapter->world_->config());
        if (!default_demo) {
            config->transport_policy = cybersand::TransportPolicy::unpack(
                {profile.ptr(), static_cast<std::size_t>(profile.size())});
            config->water_experiment_policy = cybersand::WaterExperimentPolicy(
                static_cast<std::uint8_t>(policy[1]), static_cast<std::uint8_t>(policy[2]));
        }
        config->liquid_solver_policy = *decoded.policy;
        const auto radius = static_cast<std::int64_t>(options.get("maximum_rule_radius",
            std::int64_t{CyberNativeCellWorld::kProtectedCurrentRuleRadius}));
        if (radius != CyberNativeCellWorld::kProtectedCurrentRuleRadius && radius != cybersand::InertialParameters::kExecutionRadius)
            throw std::invalid_argument("Prepared application geometry requires explicit rule radius two or three");
        config->maximum_rule_radius = static_cast<std::int32_t>(radius);
        config->interaction_policy = {};
        config->physics_diagnostics = {};
        config->physics_diagnostics.enabled = true;

        cybersand::normalization::FinalSetupInput input;
        if (default_demo) {
            // Resolve the same ordered native recipe before normalization. The
            // finite dense material map is construction-only; no tick allocates it.
            std::vector<cybersand::Material> materials(
                std::size_t{cybersand::demo::kWidth} * cybersand::demo::kHeight, cybersand::Material::Empty);
            cybersand::demo::visit_default_demo_recipe([&](std::int32_t x, std::int32_t y, cybersand::Material material) {
                materials[static_cast<std::size_t>(y) * cybersand::demo::kWidth + x] = material;
            });
            input.mass_bits = config->water_experiment_policy.mass_bits();
            input.ambient_temperature = config->ambient_temperature;
            input.setup.kind = cybersand::setup::SetupKind::NativeCellFixture;
            input.setup.definition_schema = 1;
            const auto recipe = cybersand::demo::kDefaultRecipeIdentity;
            input.setup.definition_digest = cybersand::Sha256::of({
                reinterpret_cast<const std::uint8_t*>(recipe.data()), recipe.size()});
            input.setup.seed = 0;
            input.setup.domain = {0, 0, cybersand::demo::kWidth, cybersand::demo::kHeight};
            input.setup.coverage = cybersand::setup::SetupCoverage::NativePayloadOnly;
            input.setup.gaps = cybersand::setup::kKnownSetupGaps;
            for (std::int32_t y = 0; y < cybersand::demo::kHeight; ++y) {
                for (std::int32_t x = 0; x < cybersand::demo::kWidth; ++x) {
                    const auto material = materials[static_cast<std::size_t>(y) * cybersand::demo::kWidth + x];
                    if (material == cybersand::Material::Empty) continue;
                    const auto& initial = cybersand::MaterialRules::descriptor(material);
                    const auto a = material == cybersand::Material::Water
                        ? config->water_experiment_policy.maximum() : initial.initial_state_a;
                    input.cells.push_back({x, y, material, a, initial.initial_state_b, config->ambient_temperature});
                }
            }
        } else if (level_payload != nullptr) {
            input = prepared_liquid_detail::level_setup(
                {level_payload->ptr(), static_cast<std::size_t>(level_payload->size())}, *config,
                static_cast<std::uint64_t>(seed));
        } else {
            // Resolve rectangle and nonzero-fill overwrite order once, before the
            // native normalization law sees any tuple. The dense four-lane staging
            // map exists only during construction, never in tick execution.
            struct Tuple { cybersand::Material material = cybersand::Material::Empty;
                std::uint16_t a = 0; std::uint8_t b = 0; };
            std::vector<Tuple> map(std::size_t{cybersand::demo::kWidth} * cybersand::demo::kHeight);
            if (rectangles.is_empty() || rectangles.size() % 5 ||
                rectangles.size() / 5 > static_cast<std::int64_t>(cybersand::demo::kMaximumRectangles))
                throw std::invalid_argument("Invalid demo rectangle count");
            std::uint64_t area = 0;
            const auto check_rect = [&](std::int32_t x, std::int32_t y, std::int32_t w, std::int32_t h) {
                if (x < 0 || y < 0 || w < 1 || h < 1 || w > cybersand::demo::kWidth || h > cybersand::demo::kHeight ||
                    x > cybersand::demo::kWidth - w || y > cybersand::demo::kHeight - h)
                    throw std::invalid_argument("Invalid construction rectangle");
            };
            for (std::int64_t i = 0; i < rectangles.size(); i += 5) {
                const auto x = rectangles[i], y = rectangles[i+1], w = rectangles[i+2], h = rectangles[i+3], id = rectangles[i+4];
                check_rect(x, y, w, h);
                if (!cybersand::demo::valid_material(id)) throw std::invalid_argument("Invalid material ID");
                area += static_cast<std::uint64_t>(w) * h;
                if (area > 8ULL * cybersand::demo::kWidth * cybersand::demo::kHeight)
                    throw std::invalid_argument("Demo construction budget exceeded");
                const auto material = static_cast<cybersand::Material>(id);
                const auto& initial = cybersand::MaterialRules::descriptor(material);
                const auto a = material == cybersand::Material::Water ? config->water_experiment_policy.maximum() : initial.initial_state_a;
                for (auto dy = y; dy < y+h; ++dy) for (auto dx = x; dx < x+w; ++dx)
                    map[static_cast<std::size_t>(dy) * cybersand::demo::kWidth + dx] = {material, a, initial.initial_state_b};
            }
            if (water_fills.size() % 6 || water_fills.size() / 6 > static_cast<std::int64_t>(cybersand::demo::kMaximumRectangles))
                throw std::invalid_argument("Invalid Water fill count");
            area = 0;
            for (std::int64_t i = 0; i < water_fills.size(); i += 6) {
                const auto x = water_fills[i], y = water_fills[i+1], w = water_fills[i+2], h = water_fills[i+3];
                check_rect(x, y, w, h);
                if (water_fills[i+4] < 0 || water_fills[i+4] > 255 || water_fills[i+5] < 0 || water_fills[i+5] > 12)
                    throw std::invalid_argument("Invalid Water fill value");
                area += static_cast<std::uint64_t>(w) * h;
                if (area > static_cast<std::uint64_t>(cybersand::demo::kWidth) * cybersand::demo::kHeight)
                    throw std::invalid_argument("Water fill budget exceeded");
                const auto mass = static_cast<std::uint16_t>((2U * water_fills[i+4] * config->water_experiment_policy.maximum() + 255U) / 510U);
                const auto coherence = static_cast<std::uint8_t>((2U * water_fills[i+5] * config->water_experiment_policy.coherence_ticks() + 12U) / 24U);
                if (mass == 0) continue; // Registered zero source is a no-op.
                for (auto dy = y; dy < y+h; ++dy) for (auto dx = x; dx < x+w; ++dx)
                    map[static_cast<std::size_t>(dy) * cybersand::demo::kWidth + dx] = {cybersand::Material::Water, mass, coherence};
            }
            input.mass_bits = config->water_experiment_policy.mass_bits();
            input.ambient_temperature = config->ambient_temperature;
            input.setup.kind = cybersand::setup::SetupKind::MicroScenario;
            input.setup.definition_schema = 2;
            input.setup.definition_digest.emplace();
            std::copy(definition_bytes.ptr(), definition_bytes.ptr()+32, input.setup.definition_digest->begin());
            input.setup.seed = static_cast<std::uint64_t>(seed);
            input.setup.domain = {0, 0, cybersand::demo::kWidth, cybersand::demo::kHeight};
            // Binding a host digest does not establish a native definition compiler.
            input.setup.coverage = cybersand::setup::SetupCoverage::RegisteredDefinitionAndPayload;
            input.setup.gaps = cybersand::setup::kKnownSetupGaps;
            for (std::int32_t y = 0; y < cybersand::demo::kHeight; ++y) for (std::int32_t x = 0; x < cybersand::demo::kWidth; ++x) {
                const auto& cell = map[static_cast<std::size_t>(y) * cybersand::demo::kWidth+x];
                if (cell.material != cybersand::Material::Empty)
                    input.cells.push_back({x, y, cell.material, cell.a, cell.b, config->ambient_temperature});
            }
        }
        auto result = std::make_unique<cybersand::PreparedWorldBuilder::Result>(cybersand::PreparedWorldBuilder::prepare(
            *config, input, rule.is_empty() ? cybersand::normalization::NormalizationOptIn::None :
                cybersand::normalization::NormalizationOptIn::WaterNormalizeV1));
        if (const auto* refused = std::get_if<cybersand::ConstructionRefusal>(result.get())) {
            record_refusal(*refused);
            return 0;
        }
        auto& prepared = std::get<cybersand::PreparedWorld>(*result);
        if (adapter->liquid_policy_session_generation_ == static_cast<std::uint64_t>(INT64_MAX))
            throw std::length_error("Construction generation space exhausted");
        auto pending = std::make_unique<CyberNativeCellWorld::PendingLiquidWorld>();
        pending->world = prepared.take_world();
        pending->reset_demo_coupling = default_demo;
        pending->world->configure_transient_obstacles({0, 0, cybersand::demo::kWidth, cybersand::demo::kHeight});
        if (options.has("initial_bodies") && options["initial_bodies"].get_type() != Variant::PACKED_FLOAT32_ARRAY)
            throw std::invalid_argument("Initial body input must be a PackedFloat32Array");
        pending->initial_body_input = options.get("initial_bodies", PackedFloat32Array());
        pending->initial_bodies = CyberNativeCellWorld::parse_body_state_values(pending->initial_body_input, true);
        cybersand::setup::encoding::Writer body_identity;
        body_identity.text("cybersand-prepared-physical-input-v1");
        body_identity.integer(static_cast<std::uint32_t>(pending->initial_body_input.size()));
        for (std::int64_t index = 0; index < pending->initial_body_input.size(); ++index)
            body_identity.integer(std::bit_cast<std::uint32_t>(pending->initial_body_input[index]));
        pending->initial_body_digest = prepared_liquid_detail::digest(cybersand::Sha256::of(body_identity.bytes));
        for (const auto& body : pending->initial_bodies) if (body.valid)
            CyberNativeCellWorld::rasterize_transform_in(*pending->world, nullptr,
                body.id, body.center, body.rotation, body.half_size);

        // The authored default contains many isolated Water-adjacent voids.
        // Admit its actual initial topology after body masks, before any token,
        // applied receipt or authority replacement can escape preparation.
        if (default_demo) {
            if (const auto refused = cybersand::PreparedWorldBuilder::validate_initial_pressure_capacity(
                    *pending->world, prepared.setup().domain())) {
                record_refusal(*refused);
                return 0;
            }
        }

        pending->origin = Vector2i(region[0], region[1]); pending->size = Vector2i(region[2], region[3]);
        pending->window = window;
        pending->cadence = options.get("cadence_lod_enabled", false);
        pending->adhesion = options.get("liquid_surface_adhesion_enabled", true);
        pending->world->set_simulation_region(cybersand::RectI64{region[0], region[1], region[2], region[3]});
        pending->world->set_liquid_surface_adhesion_enabled(pending->adhesion);
        pending->exchange = std::make_unique<cybersand::RenderSnapshotExchange>(3, 64,
            std::size_t{cybersand::demo::kWidth} * cybersand::demo::kHeight * 2);
        pending->setup = prepared.setup().setup_descriptor();
        const auto facts = std::make_unique<cybersand::receipt::NativeFacts>(
            cybersand::receipt::capture_native_facts(*pending->world, pending->setup));
        cybersand::receipt::HostExecution execution;
        execution.simulation_window_enabled = pending->window; execution.cadence_lod_enabled = pending->cadence;
        execution.pacing = pacing == "host_paced" ? cybersand::receipt::Pacing::HostPaced : cybersand::receipt::Pacing::FixedSteps;
        const auto receipt = cybersand::receipt::build_applied_run_receipt(*facts, pending->setup, request,
            intent == "exploratory" ? cybersand::receipt::RunIntent::Exploratory : cybersand::receipt::RunIntent::Controlled,
            cybersand::receipt::PlaneActivity::Active, execution, {},
            adapter->liquid_policy_session_generation_+1, prepared.setup().normalization_receipt());
        pending->receipt = prepared_liquid_detail::encoding(receipt, "applied_run");
        pending->receipt["session_generation"] = static_cast<std::int64_t>(adapter->liquid_policy_session_generation_+1);
        pending->receipt["prepared_setup_hash"] = prepared_liquid_detail::digest(prepared.setup().setup_hash());
        pending->receipt["prepared_payload_hash"] = prepared_liquid_detail::digest(prepared.setup().native_payload_hash());
        if (level_payload != nullptr) {
            pending->receipt["setup_kind"] = "native_cell_fixture";
            pending->receipt["source_payload_sha256"] = prepared_liquid_detail::digest(*input.setup.definition_digest);
        }
        if (default_demo) {
            pending->receipt["setup_kind"] = "native_cell_fixture";
            pending->receipt["native_recipe_id"] = String(cybersand::demo::kDefaultRecipeIdentity.data());
            pending->receipt["native_recipe_identity_sha256"] = prepared_liquid_detail::digest(*input.setup.definition_digest);
        }
        pending->receipt["policy_hash"] = String(pending->world->liquid_solver_policy().policy_hash_hex().c_str());
        pending->receipt["physical_state_hash"] = String::num_uint64(facts->values().physical_hash, 16).lpad(16,"0");
        pending->receipt["physical_state_hash_version"] = static_cast<std::int64_t>(facts->values().physical_hash_version);
        Array extensions;
        for (const auto& extension : facts->values().solver_state_extensions) {
            Dictionary value;
            value["family"] = static_cast<std::int64_t>(extension.family);
            value["state_contract_version"] = static_cast<std::int64_t>(extension.state_contract_version);
            value["extension_identity_version"] = static_cast<std::int64_t>(extension.extension_identity_version);
            value["extension_digest"] = extension.extension_digest
                ? Variant(prepared_liquid_detail::digest(*extension.extension_digest)) : Variant();
            extensions.push_back(value);
        }
        pending->receipt["solver_state_extensions"] = extensions;
        pending->receipt["worker_threads"] = static_cast<std::int64_t>(config->worker_threads);
        pending->receipt["maximum_rule_radius"] = static_cast<std::int64_t>(pending->world->config().maximum_rule_radius);
        pending->receipt["completed_tick"] = static_cast<std::int64_t>(facts->values().completed_tick);
        pending->receipt["region"] = region;
        pending->receipt["run_intent"] = intent; pending->receipt["pacing"] = pacing;
        pending->receipt["simulation_window_enabled"] = pending->window;
        pending->receipt["cadence_lod_enabled"] = pending->cadence;
        pending->receipt["liquid_surface_adhesion_enabled"] = pending->adhesion;
        pending->receipt["initial_body_count"] = pending->initial_body_input.size() / CyberNativeCellWorld::kInputStride;
        pending->receipt["initial_body_state_sha256"] = pending->initial_body_digest;
        pending->receipt["normalization"] = Dictionary();
        if (const auto& norm = prepared.setup().normalization_receipt()) {
            Dictionary normalized;
            normalized["rule"] = "water-normalize-v1";
            normalized["receipt_hash"] = prepared_liquid_detail::digest(norm->receipt_hash());
            normalized["payload_before_hash"] = prepared_liquid_detail::digest(norm->payload_before_hash());
            normalized["payload_after_hash"] = prepared_liquid_detail::digest(norm->payload_after_hash());
            normalized["setup_before_hash"] = prepared_liquid_detail::digest(norm->setup_before_hash());
            normalized["setup_after_hash"] = prepared_liquid_detail::digest(norm->setup_after_hash());
            const auto& totals = norm->totals();
            normalized["water_before"] = totals.water_before; normalized["water_after"] = totals.water_after;
            normalized["positive_delta"] = totals.positive_delta; normalized["negative_delta"] = totals.negative_delta;
            normalized["net_delta"] = totals.net_delta;
            normalized["cells_up"] = totals.cells_up; normalized["cells_down"] = totals.cells_down;
            normalized["cells_unchanged"] = totals.cells_unchanged;
            pending->receipt["normalization"] = normalized;
        }
        if (adapter->next_liquid_preparation_token_ == static_cast<std::uint64_t>(INT64_MAX))
            throw std::length_error("Preparation token space exhausted");
        pending->token = ++adapter->next_liquid_preparation_token_;
        pending->retained_generation = adapter->liquid_policy_session_generation_;
        pending->retained_revision = adapter->revision_;
        pending->retained_hash = adapter->world_->physical_state_hash();
        pending->retained_cadence = adapter->cadence_lod_enabled_;
        pending->retained_window = adapter->simulation_window_enabled_;
        const auto token = pending->token;
        adapter->pending_liquid_world_ = std::move(pending);
        return static_cast<std::int64_t>(token);
    } catch (const std::exception& error) {
        error_ = String(error.what());
        return 0;
    }
}

inline bool CyberDemoBridge::commit_liquid_world(const Ref<CyberNativeCellWorld>& adapter, std::int64_t token) {
    error_ = String();
    if (adapter.is_null() || !adapter->pending_liquid_world_ || token <= 0 ||
        adapter->pending_liquid_world_->token != static_cast<std::uint64_t>(token)) {
        error_ = "Preparation token is absent or retired";
        return false;
    }
    auto pending = std::move(adapter->pending_liquid_world_); // One use, also on refusal.
    if (adapter->world_->has_failed() || pending->retained_generation != adapter->liquid_policy_session_generation_ ||
        pending->retained_revision != adapter->revision_ || pending->retained_hash != adapter->world_->physical_state_hash() ||
        pending->retained_cadence != adapter->cadence_lod_enabled_ || pending->retained_window != adapter->simulation_window_enabled_) {
        error_ = "Retained World changed after preparation";
        return false;
    }
    // No allocations, capture, configuration changes or host callbacks after
    // this fence. All final native facts and copied receipts were prepared.
    adapter->world_.swap(pending->world);
    adapter->default_demo_recipe_active_ = pending->reset_demo_coupling;
    if (pending->reset_demo_coupling) adapter->reset_demo_coupling_parameters();
    adapter->render_exchange_.swap(pending->exchange);
    adapter->applied_liquid_setup_ = pending->setup;
    std::swap(adapter->applied_liquid_construction_receipt_, pending->receipt);
    adapter->liquid_construction_attempt_.clear();
    ++adapter->liquid_policy_session_generation_;
    adapter->simulation_window_enabled_ = pending->window;
    adapter->last_view_origin_ = pending->origin; adapter->last_view_size_ = pending->size;
    adapter->last_horizontal_buffer_ = adapter->last_vertical_buffer_ = 0;
    adapter->cadence_lod_enabled_ = pending->cadence;
    adapter->liquid_surface_adhesion_enabled_ = pending->adhesion;
    adapter->current_bodies_ = pending->initial_bodies; adapter->previous_bodies_ = pending->initial_bodies; adapter->clear_observations();
    adapter->raster_indices_.clear(); adapter->last_stats_ = {};
    adapter->simulation_time_ms_ = 0; adapter->tick_failure_count_ = 0; adapter->last_tick_error_ = String();
    adapter->render_cells_revision_ = adapter->hard_surface_rectangles_revision_ = adapter->hard_surface_chunk_rectangles_revision_ = UINT64_MAX;
    adapter->render_snapshot_full_refresh_required_ = true;
    ++adapter->revision_; ++adapter->hard_surface_revision_;
    return true;
}
} // namespace godot
