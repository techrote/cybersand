#pragma once

#include "cyber_prepared_level_payload.hpp"
#include "workbench_retained_setup.hpp"
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
        Vector2i extent{cybersand::demo::kWidth, cybersand::demo::kHeight};
        const bool workbench = options.has("workbench_response");
        String response;
        if (workbench) {
            if (level_payload || default_demo || options["workbench_response"].get_type() != Variant::STRING ||
                options.get("workbench_extent", Variant()).get_type() != Variant::VECTOR2I)
                throw std::invalid_argument("Workbench preparation requires an authored extent and response");
            response = options["workbench_response"];
            if (response != "RFT" && response != "LA" && response != "LA-SELECTIVE" && response != "LA-EVENT-OFF")
                throw std::invalid_argument("Unknown workbench response");
            extent = options["workbench_extent"];
            if (extent.x < 256 || extent.y < 256 || extent.x > 2048 || extent.y > 2048 || extent.x % 64 || extent.y % 64)
                throw std::invalid_argument("Workbench extent must be a multiple of 64 in 256..2048");
        } else if (options.has("workbench_extent") || options.has("workbench_sample") || options.has("workbench_retain_cells")) {
            throw std::invalid_argument("Incomplete workbench configuration");
        }
        const bool retain = options.get("workbench_retain_cells",false);
        if (retain && (!adapter->workbench_ || adapter->extent_ != extent))
            throw std::invalid_argument("Live content requires the retained workbench extent");
        const PackedInt32Array region = options.get("region", PackedInt32Array());
        if (region.size() != 4 || region[0] < 0 || region[1] < 0 || region[2] < 1 || region[3] < 1 ||
            region[2] > extent.x || region[3] > extent.y ||
            region[0] > extent.x - region[2] || region[1] > extent.y - region[3])
            throw std::invalid_argument("Controlled preparation requires a finite final simulation region");
        const String intent = options.get("intent", String("controlled"));
        const String pacing = options.get("pacing", String("fixed_steps"));
        if ((intent != "controlled" && intent != "exploratory") ||
            (pacing != "fixed_steps" && pacing != "host_paced"))
            throw std::invalid_argument("Unknown prepared host intent or pacing");
        const bool window = options.get("simulation_window_enabled", true);
        if (!window && (region[0] != 0 || region[1] != 0 ||
            region[2] != extent.x || region[3] != extent.y))
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
        // Bound the finite reservation, halo, eligible chunks and active task list.
        // Ordinary controlled/demo replacements keep their established limits.
        if (workbench) {
            const auto halo_columns = (extent.x + config->chunk_size - 1) / config->chunk_size + 2;
            const auto halo_rows = (extent.y + config->chunk_size - 1) / config->chunk_size + 2;
            config->maximum_chunk_count = std::max<std::size_t>(128, halo_columns * halo_rows);
            config->active_chunk_capacity = config->maximum_chunk_count;
        } else if (adapter->workbench_) {
            config->maximum_chunk_count = 128;
            config->active_chunk_capacity = 128;
        }
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
            std::vector<Tuple> map(static_cast<std::size_t>(extent.x) * extent.y);
            if ((!workbench && rectangles.is_empty()) || rectangles.size() % 5 ||
                rectangles.size() / 5 > static_cast<std::int64_t>(cybersand::demo::kMaximumRectangles))
                throw std::invalid_argument("Invalid demo rectangle count");
            std::uint64_t area = 0;
            const auto check_rect = [&](std::int32_t x, std::int32_t y, std::int32_t w, std::int32_t h) {
                if (x < 0 || y < 0 || w < 1 || h < 1 || w > extent.x || h > extent.y ||
                    x > extent.x - w || y > extent.y - h)
                    throw std::invalid_argument("Invalid construction rectangle");
            };
            for (std::int64_t i = 0; i < rectangles.size(); i += 5) {
                const auto x = rectangles[i], y = rectangles[i+1], w = rectangles[i+2], h = rectangles[i+3], id = rectangles[i+4];
                check_rect(x, y, w, h);
                if (!cybersand::demo::valid_material(id)) throw std::invalid_argument("Invalid material ID");
                area += static_cast<std::uint64_t>(w) * h;
                if (area > 8ULL * extent.x * extent.y)
                    throw std::invalid_argument("Demo construction budget exceeded");
                const auto material = static_cast<cybersand::Material>(id);
                const auto& initial = cybersand::MaterialRules::descriptor(material);
                const auto a = material == cybersand::Material::Water ? config->water_experiment_policy.maximum() : initial.initial_state_a;
                for (auto dy = y; dy < y+h; ++dy) for (auto dx = x; dx < x+w; ++dx)
                    map[static_cast<std::size_t>(dy) * extent.x + dx] = {material, a, initial.initial_state_b};
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
                if (area > static_cast<std::uint64_t>(extent.x) * extent.y)
                    throw std::invalid_argument("Water fill budget exceeded");
                const auto mass = static_cast<std::uint16_t>((2U * water_fills[i+4] * config->water_experiment_policy.maximum() + 255U) / 510U);
                const auto coherence = static_cast<std::uint8_t>((2U * water_fills[i+5] * config->water_experiment_policy.coherence_ticks() + 12U) / 24U);
                if (mass == 0) continue; // Registered zero source is a no-op.
                for (auto dy = y; dy < y+h; ++dy) for (auto dx = x; dx < x+w; ++dx)
                    map[static_cast<std::size_t>(dy) * extent.x + dx] = {cybersand::Material::Water, mass, coherence};
            }
            input.mass_bits = config->water_experiment_policy.mass_bits();
            input.ambient_temperature = config->ambient_temperature;
            input.setup.kind = cybersand::setup::SetupKind::MicroScenario;
            input.setup.definition_schema = 2;
            input.setup.definition_digest.emplace();
            std::copy(definition_bytes.ptr(), definition_bytes.ptr()+32, input.setup.definition_digest->begin());
            input.setup.seed = static_cast<std::uint64_t>(seed);
            input.setup.domain = {0, 0, static_cast<std::uint32_t>(extent.x), static_cast<std::uint32_t>(extent.y)};
            // Binding a host digest does not establish a native definition compiler.
            input.setup.coverage = cybersand::setup::SetupCoverage::RegisteredDefinitionAndPayload;
            input.setup.gaps = cybersand::setup::kKnownSetupGaps;
            for (std::int32_t y = 0; y < extent.y; ++y) for (std::int32_t x = 0; x < extent.x; ++x) {
                const auto& cell = map[static_cast<std::size_t>(y) * extent.x+x];
                if (cell.material != cybersand::Material::Empty)
                    input.cells.push_back({x, y, cell.material, cell.a, cell.b, config->ambient_temperature});
            }
        }
        cybersand::normalization::PreparationLimits limits;
        if (workbench) {
            limits.maximum_side = static_cast<std::uint32_t>(std::max(extent.x,extent.y));
            limits.maximum_cells = static_cast<std::size_t>(extent.x) * extent.y;
            if (retain) prepared_liquid_detail::workbench_copy_retained_cells(*adapter->world_, input);
        }
        auto result = std::make_unique<cybersand::PreparedWorldBuilder::Result>(cybersand::PreparedWorldBuilder::prepare(
            *config, input, rule.is_empty() ? cybersand::normalization::NormalizationOptIn::None :
                cybersand::normalization::NormalizationOptIn::WaterNormalizeV1, limits));
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
        pending->extent = extent;
        pending->world->configure_transient_obstacles({0, 0, extent.x, extent.y});
        if (workbench) {
            if (options.get("workbench_sample",Variant()).get_type() != Variant::DICTIONARY)
                throw std::invalid_argument("Missing workbench initial body sample");
            const Dictionary packet = options["workbench_sample"];
            if (packet.get("states",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                packet.get("geometry",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                packet.get("bodies",Variant()).get_type()!=Variant::ARRAY ||
                packet.get("session",Variant()).get_type()!=Variant::INT ||
                packet.get("epoch",Variant()).get_type()!=Variant::INT)
                throw std::invalid_argument("Workbench sample requires complete typed values");
            pending->workbench = std::make_unique<CyberNativeCellWorld::Workbench>();
            pending->workbench->response = response;
            CyberNativeCellWorld::WorkbenchSample initial;
            if (!CyberNativeCellWorld::parse_workbench_sample(initial, *pending->workbench,
                    packet.get("states",PackedFloat64Array()), packet.get("geometry",PackedFloat64Array()),
                    packet.get("bodies",Array()), packet.get("session",0), packet.get("epoch",0)))
                throw std::invalid_argument("Invalid workbench initial body sample or capacity");
            // Bind the actual tick-zero geometry, per-body context and routing,
            // independently of the legacy 11-field physical pose receipt.
            cybersand::setup::encoding::Writer identity;
            identity.text("cybersand-workbench-physical-input-v1");
            identity.integer(initial.session); identity.integer(initial.epoch);
            const PackedFloat64Array wire = packet["states"], geometry = packet["geometry"];
            for (const auto& array : {wire,geometry}) {
                identity.integer(static_cast<std::uint32_t>(array.size()));
                for (std::int64_t i=0; i<array.size(); ++i)
                    identity.integer(std::bit_cast<std::uint64_t>(array[i]));
            }
            for (std::size_t slot=1; slot<initial.owners.size(); ++slot) {
                const auto& owner=initial.owners[slot];
                if (!owner.instance) continue;
                identity.integer(static_cast<std::uint16_t>(slot));
                identity.integer(owner.instance); identity.integer(owner.generation);
                identity.integer(owner.first); identity.integer(owner.count);
                identity.integer(std::bit_cast<std::uint64_t>(owner.budget));
                identity.integer(std::bit_cast<std::uint64_t>(owner.gravity));
                identity.integer(static_cast<std::uint8_t>(owner.external_drive));
            }
            pending->workbench_initial_digest=prepared_liquid_detail::digest(cybersand::Sha256::of(identity.bytes));
            pending->workbench->sample = initial;
            pending->world->enable_transient_granular_wrenches(true);
            pending->world->enable_granular_arrival_witness(response == "LA-SELECTIVE");
            // Unique endpoint/sweep cells are bounded by the finite canvas.
            adapter->raster_indices_.reserve(static_cast<std::size_t>(extent.x)*extent.y);
        }
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
        if (workbench) {
            const auto& sample=pending->workbench->sample;
            for (std::size_t slot=1; slot<pending->initial_bodies.size(); ++slot) {
                const auto& physical=pending->initial_bodies[slot];
                const bool present=slot<sample.owners.size() && sample.owners[slot].instance!=0;
                if (physical.valid!=present)
                    throw std::invalid_argument("Workbench physical input and hull roster differ");
                if (!present) continue;
                const auto& b=sample.proxies[sample.owners[slot].first];
                // The legacy physical bridge samples float32. Its centre is the
                // actual rigid origin, also COM for all admitted workbench rigs.
                const auto near=[](double left,double right) {
                    const auto scale=std::max({1.,std::abs(left),std::abs(right)});
                    return std::abs(left-right)<=4.*std::numeric_limits<float>::epsilon()*scale;
                };
                if (!near(physical.center.x,b.com.x) || !near(physical.center.y,b.com.y) ||
                    !near(physical.rotation,b.rotation) || !near(physical.mass,b.mass) ||
                    !near(physical.angular_velocity,b.angular_velocity) ||
                    !near(physical.velocity.x,b.velocity.x) || !near(physical.velocity.y,b.velocity.y))
                    throw std::invalid_argument("Workbench physical pose and hull sample disagree");
            }
        }
        const auto& initial_proxies = workbench ? pending->workbench->sample.proxies : pending->initial_bodies;
        for (const auto& body : initial_proxies) if (body.valid)
            CyberNativeCellWorld::rasterize_transform_in(*pending->world, extent, nullptr,
                body.id, body.center, body.rotation, body.half_size);

        // The authored default contains many isolated Water-adjacent voids.
        // Admit its actual initial topology after body masks, before any token,
        // applied receipt or authority replacement can escape preparation.
        if (default_demo || workbench) {
            if (const auto refused = cybersand::PreparedWorldBuilder::validate_initial_pressure_capacity(
                    *pending->world, prepared.setup().domain(), limits.maximum_side)) {
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
            static_cast<std::size_t>(extent.x) * extent.y * 2);
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
        if (workbench) {
            pending->receipt["workbench_response"] = response;
            pending->receipt["workbench_extent"] = extent;
            pending->receipt["workbench_initial_sample_sha256"] = pending->workbench_initial_digest;
        }
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
    adapter->workbench_.swap(pending->workbench);
    adapter->extent_ = pending->extent;
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
    adapter->current_bodies_ = adapter->workbench_ ? adapter->workbench_->sample.proxies : pending->initial_bodies;
    adapter->previous_bodies_ = adapter->current_bodies_; adapter->clear_observations();
    adapter->raster_indices_.clear(); adapter->last_stats_ = {};
    adapter->simulation_time_ms_ = 0; adapter->tick_failure_count_ = 0; adapter->last_tick_error_ = String();
    adapter->render_cells_revision_ = adapter->hard_surface_rectangles_revision_ = adapter->hard_surface_chunk_rectangles_revision_ = UINT64_MAX;
    adapter->render_snapshot_full_refresh_required_ = true;
    ++adapter->revision_; ++adapter->hard_surface_revision_;
    return true;
}
} // namespace godot
