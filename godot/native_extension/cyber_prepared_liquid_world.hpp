#pragma once

#include "cyber_prepared_level_payload.hpp"

#include <string_view>
#include <cmath>
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

// Workbench's schema-1 Baseline is a fully resolved transport table, so
// unpack() marks it configured even though its behavior is the native default.
// Wave deliberately refuses custom transport. Admit only this exact Baseline
// representation and canonicalize it at the adapter boundary; never relax the
// numerical law's custom-transport refusal or drop a caller's actual tuning.
inline bool is_workbench_baseline_transport(const cybersand::TransportPolicy& policy) {
    constexpr std::array<std::uint8_t, 9> powders{2, 13, 14, 19, 23, 25, 26, 27, 29};
    constexpr auto mercury = static_cast<std::uint8_t>(cybersand::Material::Mercury);
    const cybersand::TransportPair defaults;
    const auto mercury_period = cybersand::InteractionPolicy{}.mercury_exchange_period;
    for (std::size_t source = 0; source < cybersand::TransportPolicy::materials; ++source) {
        if (policy.horizontal[source] != 2 || policy.cadence[source] != 1) return false;
        const bool powder = std::find(powders.begin(), powders.end(), source) != powders.end();
        for (std::size_t target = 0; target < cybersand::TransportPolicy::materials; ++target) {
            const auto& pair = policy.pairs[source * cybersand::TransportPolicy::materials + target];
            const auto permeability = source == mercury || (powder && target == mercury)
                ? mercury_period : 1U;
            if (pair.mixing != defaults.mixing || pair.carrying != defaults.carrying ||
                pair.pickup != defaults.pickup || pair.packing != defaults.packing ||
                pair.erosion != defaults.erosion || pair.permeability != permeability) return false;
        }
    }
    return true;
}
} // namespace prepared_liquid_detail

inline std::int64_t CyberDemoBridge::prepare_liquid_world(
    const Ref<CyberNativeCellWorld>& adapter, const PackedInt32Array& rectangles,
    const PackedInt32Array& profile, const PackedInt32Array& policy,
    const PackedInt32Array& water_fills, const PackedInt32Array& liquid_policy,
    const Dictionary& options) {
    if (options.has("workbench_continuation") || options.has("workbench_continuation_identity"))
        return prepare_workbench_continuation(adapter, rectangles, profile, policy, water_fills, liquid_policy, options);
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
        } else if (options.has("workbench_extent") || options.has("workbench_sample") || options.has("workbench_retain_cells") ||
                   options.has("workbench_convert_liquid_inventory")) {
            throw std::invalid_argument("Incomplete workbench configuration");
        }
        if (options.has("workbench_convert_liquid_inventory") &&
            options["workbench_convert_liquid_inventory"].get_type() != Variant::BOOL)
            throw std::invalid_argument("Workbench inventory conversion intent must be boolean");
        const bool convert = options.get("workbench_convert_liquid_inventory",false);
        const bool retain = options.get("workbench_retain_cells",false);
        const bool authoring_patch = options.has("workbench_authoring_patch");
        Dictionary authoring_patch_receipt;
        if (authoring_patch && (!workbench || !retain || convert || !adapter->workbench_ ||
            options["workbench_authoring_patch"].get_type() != Variant::DICTIONARY ||
            extent != adapter->extent_ || !rectangles.is_empty() || !water_fills.is_empty() ||
            decoded.policy->policy_hash() != adapter->world_->liquid_solver_policy().policy_hash()))
            throw std::invalid_argument("Authoring patch requires unchanged retained Workbench settings and no alternate terrain");
        // EXPLORE-001: copied GEN-007 play-plane bytes are construction-only.
        // Nothing in this input exposes a mutable World, or admits post-commit
        // chunk mutation. Edits are ordered starting-map marks, not live state.
        const bool generated = options.has("workbench_generated");
        const bool material_baseline = options.has("workbench_material_baseline");
        Dictionary generated_claim;
        Dictionary baseline_claim;
        PackedByteArray generated_cells;
        PackedByteArray baseline_cells;
        Array generated_edits;
        String generated_expected_material_sha;
        if (generated) {
            if (!workbench || retain || default_demo || level_payload != nullptr ||
                options["workbench_generated"].get_type() != Variant::DICTIONARY ||
                !rectangles.is_empty() || !water_fills.is_empty())
                throw std::invalid_argument("Generated-grid construction requires a fresh exclusive workbench");
            generated_claim = options["workbench_generated"];
            if (generated_claim.size() != 12 ||
                !generated_claim.has("schema") || !generated_claim.has("extent") ||
                !generated_claim.has("origin") || !generated_claim.has("cells") ||
                !generated_claim.has("sha256") || !generated_claim.has("recipe_sha256") ||
                !generated_claim.has("generator_fingerprint") ||
                !generated_claim.has("plane_revision") ||
                !generated_claim.has("generator_revision") ||
                !generated_claim.has("generator_seed") ||
                !generated_claim.has("receipt_hashes") || !generated_claim.has("edits") ||
                generated_claim["schema"].get_type() != Variant::INT ||
                generated_claim["extent"].get_type() != Variant::VECTOR2I ||
                generated_claim["origin"].get_type() != Variant::VECTOR2I ||
                generated_claim["cells"].get_type() != Variant::PACKED_BYTE_ARRAY ||
                generated_claim["sha256"].get_type() != Variant::STRING ||
                generated_claim["recipe_sha256"].get_type() != Variant::STRING ||
                generated_claim["generator_fingerprint"].get_type() != Variant::STRING ||
                generated_claim["plane_revision"].get_type() != Variant::STRING ||
                generated_claim["generator_revision"].get_type() != Variant::INT ||
                generated_claim["generator_seed"].get_type() != Variant::INT ||
                generated_claim["receipt_hashes"].get_type() != Variant::ARRAY ||
                generated_claim["edits"].get_type() != Variant::ARRAY ||
                static_cast<std::int64_t>(generated_claim["schema"]) != 1 ||
                static_cast<std::int64_t>(generated_claim["generator_revision"]) < 1 ||
                static_cast<std::int64_t>(generated_claim["generator_seed"]) < 0 ||
                static_cast<Vector2i>(generated_claim["extent"]) != extent)
                throw std::invalid_argument("Malformed generated-grid schema or dimensions");
            const auto origin = static_cast<Vector2i>(generated_claim["origin"]);
            const auto valid_origin = [](std::int64_t start, std::int64_t side) {
                return start >= -1'000'000 && side >= 1 &&
                    start <= 1'000'000 - side;
            };
            if (!valid_origin(origin.x, extent.x) || !valid_origin(origin.y, extent.y))
                throw std::invalid_argument("Generated-grid world region is outside bounded coordinates");
            generated_cells = generated_claim["cells"];
            generated_edits = generated_claim["edits"];
            if (generated_cells.size() != static_cast<std::int64_t>(extent.x) * extent.y ||
                generated_edits.size() > 32768)
                throw std::invalid_argument("Generated-grid length or starting edit capacity invalid");
            const auto is_hex = [](const String& value, std::int64_t length) {
                if (value.length() != length) return false;
                for (std::int64_t i = 0; i < value.length(); ++i) {
                    const auto c = value[i];
                    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
                }
                return true;
            };
            if (!is_hex(generated_claim["sha256"], 64) ||
                !is_hex(generated_claim["recipe_sha256"], 64) ||
                !is_hex(generated_claim["generator_fingerprint"], 16) ||
                (!String(generated_claim["plane_revision"]).is_empty() &&
                 !is_hex(generated_claim["plane_revision"], 16)))
                throw std::invalid_argument("Generated-grid source identity is malformed");
            const Array receipt_hashes = generated_claim["receipt_hashes"];
            if (receipt_hashes.size() > 1024)
                throw std::invalid_argument("Generated-grid receipt count exceeds capacity");
            for (std::int64_t i = 0; i < receipt_hashes.size(); ++i)
                if (receipt_hashes[i].get_type() != Variant::STRING ||
                    !is_hex(receipt_hashes[i], 16))
                    throw std::invalid_argument("Invalid generated-grid receipt hash");
            const String actual = prepared_liquid_detail::digest(cybersand::Sha256::of(
                {generated_cells.ptr(), static_cast<std::size_t>(generated_cells.size())}));
            if (actual != static_cast<String>(generated_claim["sha256"]))
                throw std::invalid_argument("Generated-grid SHA256 mismatch; existing World preserved");
            for (std::int64_t i = 0; i < generated_cells.size(); ++i)
                if (!cybersand::valid_material(static_cast<std::uint16_t>(generated_cells[i])))
                    throw std::invalid_argument("Generated-grid contains an invalid material ID");
        }
        if (material_baseline) {
            if (!workbench || generated || retain || default_demo || level_payload != nullptr ||
                options["workbench_material_baseline"].get_type() != Variant::DICTIONARY ||
                !rectangles.is_empty() || !water_fills.is_empty())
                throw std::invalid_argument("Material baseline requires a fresh exclusive workbench constructor");
            baseline_claim = options["workbench_material_baseline"];
            if (baseline_claim.size() != 5 ||
                baseline_claim.get("schema",Variant()).get_type() != Variant::INT ||
                baseline_claim.get("extent",Variant()).get_type() != Variant::VECTOR2I ||
                baseline_claim.get("cells",Variant()).get_type() != Variant::PACKED_BYTE_ARRAY ||
                baseline_claim.get("sha256",Variant()).get_type() != Variant::STRING ||
                baseline_claim.get("edits",Variant()).get_type() != Variant::ARRAY ||
                static_cast<std::int64_t>(baseline_claim["schema"]) != cybersand::material_baseline::kSchema ||
                static_cast<Vector2i>(baseline_claim["extent"]) != extent)
                throw std::invalid_argument("Malformed or unsupported material baseline schema or extent");
            baseline_cells = baseline_claim["cells"];
            generated_edits = baseline_claim["edits"];
            if (generated_edits.size() > 32768)
                throw std::length_error("Material baseline subsequent edit capacity exceeded");
            const auto bytes = std::span<const std::uint8_t>{baseline_cells.ptr(),
                static_cast<std::size_t>(baseline_cells.size())};
            cybersand::material_baseline::validate(bytes, extent.x, extent.y);
            const auto actual = prepared_liquid_detail::digest(cybersand::Sha256::of(bytes));
            if (actual != static_cast<String>(baseline_claim["sha256"]))
                throw std::invalid_argument("Material baseline integrity mismatch");
        }
        if (retain && (!adapter->workbench_ || adapter->extent_ != extent))
            throw std::invalid_argument("Live content requires the retained workbench extent");
        // Retaining terrain constructs a new World and retires its predecessor's
        // audition identity. Require an explicit reset before losing live laws.
        if (retain && adapter->world_->material_audition_changes_behavior())
            throw std::invalid_argument("Reset live material overrides in Materials Lab before rebuilding the retained scene");
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
        const bool changed_policy = retain &&
            adapter->world_->liquid_solver_policy().policy_hash() != decoded.policy->policy_hash();
        if (changed_policy && !convert)
            throw std::invalid_argument("Changing a retained workbench liquid policy requires explicit inventory conversion");
        if (convert && (!changed_policy || intent != "exploratory"))
            throw std::invalid_argument("Explicit inventory conversion requires a retained workbench and changed liquid policy");
        const String rule = options.get("normalization", String());
        if (authoring_patch && !rule.is_empty())
            throw std::invalid_argument("Authoring patch may not normalize retained native quantities");
        if (!rule.is_empty() && rule != "water-normalize-v1")
            throw std::invalid_argument("Unknown normalization rule");
        const auto seed = static_cast<std::int64_t>(options.get("seed", std::int64_t{0}));
        if (seed < 0) throw std::invalid_argument("Negative setup seed");
        const String definition_hash = options.get("definition_hash", String());
        const auto definition_bytes = definition_hash.hex_decode();
        if (level_payload == nullptr && !default_demo && !retain && (definition_hash.length() != 64 || definition_bytes.size() != 32))
            throw std::invalid_argument("Controlled preparation requires a definition SHA256 claim");
        if ((level_payload != nullptr || default_demo) && options.has("definition_hash"))
            throw std::invalid_argument("Native prepared input does not accept a caller definition hash claim");
        if (default_demo && seed != 0)
            throw std::invalid_argument("The native default demo recipe has fixed seed zero");
        auto config = std::make_unique<cybersand::WorldConfig>(adapter->world_->config());
        if (options.has("workbench_worker_threads")) {
            if (!workbench || options["workbench_worker_threads"].get_type() != Variant::INT)
                throw std::invalid_argument("Workbench worker threads require a workbench integer");
            const auto workers = static_cast<std::int64_t>(options["workbench_worker_threads"]);
            if (workers < 1 || workers > 32)
                throw std::invalid_argument("Workbench worker threads outside 1..32");
#if defined(__EMSCRIPTEN__) && !defined(__EMSCRIPTEN_PTHREADS__)
            if (workers != 1) throw std::invalid_argument("This Web runtime supports one native worker");
#endif
            config->worker_threads = static_cast<std::uint32_t>(workers);
        }
        // Explicit capacity belongs to the prepared World, never the mutable v1
        // liquid policy envelope. Invalid types and bounds refuse before staging.
        if (options.has("pressure_gas_compartment_capacity") &&
            options["pressure_gas_compartment_capacity"].get_type() != Variant::INT)
            throw std::invalid_argument("Pressure gas capacity must be a signed integer");
        const auto gas_capacity = static_cast<std::int64_t>(
            options.get("pressure_gas_compartment_capacity", std::int64_t{1024}));
        if (gas_capacity != 1024 && gas_capacity != 2048)
            throw std::invalid_argument("Unsupported pressure gas capacity (1024 or 2048)");
        const auto destination_water = decoded.policy->assignment(static_cast<std::uint16_t>(cybersand::Material::Water));
        const bool destination_pressure = destination_water &&
            destination_water->family == cybersand::LiquidSolverFamily::PressureFlowV1;
        // An explicit family conversion already retires/constructs the PF owner
        // and reports its gas/overfill inventory. A capacity-only change while
        // retaining that owner still requires a fresh World.
        const bool pressure_owner_changes = convert && changed_policy &&
            adapter->world_->pressure_flow_enabled() != destination_pressure;
        if (retain && adapter->world_->config().pressure_gas_compartment_capacity != gas_capacity &&
            !pressure_owner_changes)
            throw std::invalid_argument("Retained gas capacity change requires a fresh World");
        config->pressure_gas_compartment_capacity = static_cast<std::uint16_t>(gas_capacity);
        config->workbench_parallel_pressure_heads = workbench;
        // Bound the finite reservation, halo, eligible chunks and active task list.
        // Ordinary controlled/demo replacements keep their established limits.
        if (options.has("workbench_fine_cores") && (!workbench || options["workbench_fine_cores"].get_type() != Variant::BOOL))
            throw std::invalid_argument("Fine scheduling cores require the workbench and a boolean value");
        if (workbench) {
            const auto halo_columns = (extent.x + config->chunk_size - 1) / config->chunk_size + 2;
            const auto halo_rows = (extent.y + config->chunk_size - 1) / config->chunk_size + 2;
            config->maximum_chunk_count = std::max<std::size_t>(128, halo_columns * halo_rows);
            config->active_chunk_capacity = config->maximum_chunk_count;
            // Workbench performance option: 32-cell scheduling cores split the
            // phased scan's critical path (the slowest core of each phase).
            // A different, equally deterministic update geometry; never exact
            // to the 64-cell default. Capacity covers every halo core.
            if (static_cast<bool>(options.get("workbench_fine_cores", false))) {
                constexpr std::int32_t kFineCore = 32;
                if (config->chunk_size % kFineCore != 0 || kFineCore % config->activity_block_size != 0 ||
                    config->maximum_rule_radius > kFineCore / 2)
                    throw std::invalid_argument("Fine scheduling cores do not fit this chunk geometry");
                config->scheduling_core_size = kFineCore;
                const auto per_chunk = static_cast<std::size_t>(config->chunk_size / kFineCore);
                config->active_core_capacity = std::max(config->active_core_capacity,
                    static_cast<std::size_t>(halo_columns) * per_chunk * static_cast<std::size_t>(halo_rows) * per_chunk);
            } else {
                // Never inherit a previous build's fine geometry.
                config->scheduling_core_size = cybersand::WorldConfig{}.scheduling_core_size;
            }
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
        // WCX/BW-001 experimental construction options: workbench only, explicit,
        // never inherited from the replaced World. Absent keeps every default.
        config->ballistic_water = {};
        config->inertial_signed_vertical = false;
        config->wave_flow = {};
        for (const char* key : {"workbench_ballistic", "workbench_inertial_signed", "workbench_face_release",
                                "workbench_wave_flow"}) {
            if (!options.has(key)) continue;
            if (!workbench || options[key].get_type() != Variant::BOOL)
                throw std::invalid_argument("Experimental Water options require the workbench and a boolean value");
        }
        config->ballistic_water.enabled = options.get("workbench_ballistic", false);
        config->inertial_signed_vertical = options.get("workbench_inertial_signed", false);
        config->ballistic_water.face_release = config->ballistic_water.enabled &&
            static_cast<bool>(options.get("workbench_face_release", false));
        config->wave_flow.enabled = options.get("workbench_wave_flow", false);
        if (config->wave_flow.enabled && config->transport_policy.configured) {
            if (!prepared_liquid_detail::is_workbench_baseline_transport(config->transport_policy))
                throw std::invalid_argument("Workbench Wave Flow requires the exact Baseline transport profile; custom transport is not supported");
            config->transport_policy = {};
        }
        if (options.has("workbench_wave_substeps")) {
            if (!workbench || !config->wave_flow.enabled ||
                options["workbench_wave_substeps"].get_type() != Variant::INT)
                throw std::invalid_argument("Wave Flow substeps require an enabled workbench Wave Flow and an integer");
            const auto value = static_cast<std::int64_t>(options["workbench_wave_substeps"]);
            if (value < 1 || value > cybersand::WaveFlowParameters::kMaximumSubsteps)
                throw std::invalid_argument("Wave Flow substeps outside 1..8");
            config->wave_flow.substeps = static_cast<std::uint8_t>(value);
        }
        struct WaveKnob {
            const char* key;
            std::int32_t cybersand::WaveFlowConfig::*member;
        };
        for (const WaveKnob knob : {
                WaveKnob{"workbench_wave_active_rows", &cybersand::WaveFlowConfig::active_rows},
                WaveKnob{"workbench_wave_gain", &cybersand::WaveFlowConfig::gain},
                WaveKnob{"workbench_wave_deep_gain", &cybersand::WaveFlowConfig::deep_gain},
                WaveKnob{"workbench_wave_floor_gain", &cybersand::WaveFlowConfig::floor_gain},
                WaveKnob{"workbench_wave_flux_smoothing", &cybersand::WaveFlowConfig::flux_smoothing},
                WaveKnob{"workbench_wave_gain_confined", &cybersand::WaveFlowConfig::gain_confined},
                WaveKnob{"workbench_wave_stiffness", &cybersand::WaveFlowConfig::stiffness},
                WaveKnob{"workbench_wave_damp_shift", &cybersand::WaveFlowConfig::damp_shift},
                WaveKnob{"workbench_wave_coast", &cybersand::WaveFlowConfig::coast},
                WaveKnob{"workbench_wave_level_shift", &cybersand::WaveFlowConfig::level_shift},
                WaveKnob{"workbench_wave_sleep_after", &cybersand::WaveFlowConfig::sleep_after},
                WaveKnob{"workbench_wave_wake_peak", &cybersand::WaveFlowConfig::wake_peak},
                WaveKnob{"workbench_wave_rest_head", &cybersand::WaveFlowConfig::rest_head},
                WaveKnob{"workbench_wave_stick", &cybersand::WaveFlowConfig::stick},
                WaveKnob{"workbench_wave_calm", &cybersand::WaveFlowConfig::calm},
                WaveKnob{"workbench_wave_calm_damp_shift", &cybersand::WaveFlowConfig::calm_damp_shift},
                WaveKnob{"workbench_wave_maximum_mass", &cybersand::WaveFlowConfig::maximum_mass},
                WaveKnob{"workbench_wave_empty_pour_shift", &cybersand::WaveFlowConfig::empty_pour_shift},
                WaveKnob{"workbench_wave_flow_share_shift", &cybersand::WaveFlowConfig::flow_share_shift},
                WaveKnob{"workbench_wave_adhesion_shift", &cybersand::WaveFlowConfig::adhesion_shift},
                WaveKnob{"workbench_wave_body_push", &cybersand::WaveFlowConfig::body_push},
                WaveKnob{"workbench_wave_body_push_by_mass", &cybersand::WaveFlowConfig::body_push_by_mass}}) {
            if (!options.has(knob.key)) continue;
            if (!workbench || !config->wave_flow.enabled || options[knob.key].get_type() != Variant::INT)
                throw std::invalid_argument("Wave Flow tuning requires an enabled workbench Wave Flow and integer values");
            const auto value = static_cast<std::int64_t>(options[knob.key]);
            if (value < std::numeric_limits<std::int32_t>::min() ||
                value > std::numeric_limits<std::int32_t>::max())
                throw std::invalid_argument("Wave Flow tuning does not fit the native integer range");
            config->wave_flow.*(knob.member) = static_cast<std::int32_t>(value);
        }
        // WAVE-WATERWALL-001 exposed-face spill: Wave-only, explicit, never
        // inherited. Generic Ballistic Water (splashes, sprays, nozzles, body
        // launches) runs under Wave with or without spill. "parcels" asks for
        // spill's hybrid release, which throws exposed faces through the same
        // parcel pool, so it turns Ballistic Water on. Without it a spill World's
        // release budget is zero: parcels fly, but faces spill through the grid.
        for (const char* key : {"workbench_wave_spill", "workbench_wave_spill_parcels", "workbench_wave_spill_full_face"}) {
            if (!options.has(key)) continue;
            if (!workbench || !config->wave_flow.enabled || options[key].get_type() != Variant::BOOL)
                throw std::invalid_argument("Wave spill options require an enabled workbench Wave Flow and a boolean value");
        }
        config->wave_flow.spill.enabled = options.get("workbench_wave_spill", false);
        const bool full_face = options.get("workbench_wave_spill_full_face", false);
        if (full_face && !config->wave_flow.spill.enabled)
            throw std::invalid_argument("Full-face release requires Waterwall spill");
        config->wave_flow.spill.full_face = full_face ? 1 : 0;
        const bool spill_parcels = options.get("workbench_wave_spill_parcels", false);
        if (spill_parcels && !config->wave_flow.spill.enabled)
            throw std::invalid_argument("Wave spill ballistic release requires Waterwall spill");
        if (config->wave_flow.spill.enabled && config->ballistic_water.face_release)
            throw std::invalid_argument("Face release cannot run beside Waterwall spill; spill owns exposed Water faces");
        if (spill_parcels) config->ballistic_water.enabled = true;
        struct SpillKnob {
            const char* key;
            std::int32_t cybersand::WaveSpillConfig::*member;
        };
        for (const SpillKnob knob : {
                SpillKnob{"workbench_wave_spill_fall", &cybersand::WaveSpillConfig::fall},
                SpillKnob{"workbench_wave_spill_share_shift", &cybersand::WaveSpillConfig::share_shift},
                SpillKnob{"workbench_wave_spill_draw", &cybersand::WaveSpillConfig::draw},
                SpillKnob{"workbench_wave_spill_deep_draw", &cybersand::WaveSpillConfig::deep_draw},
                SpillKnob{"workbench_wave_spill_draw_head", &cybersand::WaveSpillConfig::draw_head},
                SpillKnob{"workbench_wave_spill_stream", &cybersand::WaveSpillConfig::stream},
                SpillKnob{"workbench_wave_spill_launch_min", &cybersand::WaveSpillConfig::launch_min},
                SpillKnob{"workbench_wave_spill_launch_budget", &cybersand::WaveSpillConfig::launch_budget},
                SpillKnob{"workbench_wave_spill_launch_speed", &cybersand::WaveSpillConfig::launch_speed},
                SpillKnob{"workbench_wave_spill_stream_share", &cybersand::WaveSpillConfig::stream_share},
                SpillKnob{"workbench_wave_spill_blobs", &cybersand::WaveSpillConfig::catch_falling},
                SpillKnob{"workbench_wave_spill_sheet_rate", &cybersand::WaveSpillConfig::sheet_rate},
                SpillKnob{"workbench_wave_spill_coyote_ticks", &cybersand::WaveSpillConfig::coyote_ticks},
                SpillKnob{"workbench_wave_spill_stream_draw", &cybersand::WaveSpillConfig::stream_draw}}) {
            if (!options.has(knob.key)) continue;
            if (!workbench || !config->wave_flow.spill.enabled || options[knob.key].get_type() != Variant::INT)
                throw std::invalid_argument("Wave spill tuning requires an enabled Waterwall spill and integer values");
            const auto value = static_cast<std::int64_t>(options[knob.key]);
            if (value < std::numeric_limits<std::int32_t>::min() ||
                value > std::numeric_limits<std::int32_t>::max())
                throw std::invalid_argument("Wave spill tuning does not fit the native integer range");
            config->wave_flow.spill.*(knob.member) = static_cast<std::int32_t>(value);
        }
        if (config->wave_flow.spill.enabled && !spill_parcels) config->wave_flow.spill.launch_budget = 0;
        // WCX-FR workbench tuning: explicit integers inside the native admission
        // bounds; absent keys keep the ballistic_water_v1 defaults.
        struct FaceKnob { const char* key; std::int64_t low, high; };
        for (const FaceKnob knob : {FaceKnob{"workbench_face_budget", 1, 1024}, FaceKnob{"workbench_face_speed", 0, 512},
                                    FaceKnob{"workbench_face_period", 1, 64}, FaceKnob{"workbench_face_min_height", 2, 64}}) {
            if (!options.has(knob.key)) continue;
            if (!workbench || !config->ballistic_water.face_release || options[knob.key].get_type() != Variant::INT)
                throw std::invalid_argument("Face release tuning requires the workbench, face release and an integer value");
            const std::int64_t value = options[knob.key];
            if (value < knob.low || value > knob.high)
                throw std::invalid_argument("Face release tuning outside its native bounds");
            auto& c = config->ballistic_water;
            const std::string_view key = knob.key;
            if (key == "workbench_face_budget") c.face_budget = static_cast<std::uint32_t>(value);
            else if (key == "workbench_face_speed") c.face_speed = static_cast<std::int32_t>(value);
            else if (key == "workbench_face_period") c.face_period = static_cast<std::uint32_t>(value);
            else c.face_min_height = static_cast<std::int32_t>(value);
        }

        if (authoring_patch) {
            const auto retained_region = adapter->world_->simulation_region();
            if (!retained_region || retained_region->x != region[0] || retained_region->y != region[1] ||
                retained_region->width != region[2] || retained_region->height != region[3])
                throw std::invalid_argument("Authoring patch may not change the retained simulation region");
        }
        if (authoring_patch &&
            (!prepared_liquid_detail::workbench_same_authoring_physics(adapter->world_->config(), *config) ||
             response != adapter->workbench_->response || window != adapter->simulation_window_enabled_ ||
             static_cast<bool>(options.get("cadence_lod_enabled", false)) != adapter->cadence_lod_enabled_ ||
             static_cast<bool>(options.get("liquid_surface_adhesion_enabled", true)) != adapter->liquid_surface_adhesion_enabled_))
            throw std::invalid_argument("Authoring patch may not change the retained physical configuration");

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
        } else if (retain) {
            // A live edit reconstructs the actual paused cells. It does not
            // compile a dense starting recipe only to discard its contents.
            input.mass_bits=config->water_experiment_policy.mass_bits();
            input.ambient_temperature=config->ambient_temperature;
            input.setup.domain={0,0,static_cast<std::uint32_t>(extent.x),static_cast<std::uint32_t>(extent.y)};
            input.setup.seed=static_cast<std::uint64_t>(seed);
            prepared_liquid_detail::workbench_copy_retained_cells(*adapter->world_,input);
            if (authoring_patch)
                authoring_patch_receipt = prepared_liquid_detail::workbench_stage_authoring_patch(
                    *adapter->world_, input, options["workbench_authoring_patch"], extent,
                    adapter->liquid_policy_session_generation_, adapter->revision_);
        } else {
            // Resolve rectangle and nonzero-fill overwrite order once, before the
            // native normalization law sees any tuple. The dense four-lane staging
            // map exists only during construction, never in tick execution.
            struct Tuple { cybersand::Material material = cybersand::Material::Empty;
                std::uint16_t a = 0; std::uint8_t b = 0; };
            std::vector<Tuple> map(static_cast<std::size_t>(extent.x) * extent.y);
            if (generated || material_baseline) {
                const auto baseline_bytes = std::span<const std::uint8_t>{baseline_cells.ptr(),
                    static_cast<std::size_t>(baseline_cells.size())};
                for (std::int32_t y = 0; y < extent.y; ++y) for (std::int32_t x = 0; x < extent.x; ++x) {
                    const auto index = static_cast<std::size_t>(y) * extent.x + x;
                    const auto id = material_baseline ? cybersand::material_baseline::decode(baseline_bytes, index)
                        : static_cast<std::uint16_t>(generated_cells[static_cast<std::int64_t>(index)]);
                    const auto material = static_cast<cybersand::Material>(id);
                    const auto& initial = cybersand::MaterialRules::descriptor(material);
                    map[static_cast<std::size_t>(y) * extent.x + x] = {
                        material, material == cybersand::Material::Water
                            ? config->water_experiment_policy.maximum() : initial.initial_state_a,
                        initial.initial_state_b};
                }
            }
            if ((!workbench && rectangles.is_empty()) || rectangles.size() % 5 ||
                rectangles.size() / 5 > (workbench ? std::int64_t{32768} :
                    static_cast<std::int64_t>(cybersand::demo::kMaximumRectangles)))
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
            if (generated || material_baseline) {
                // Bound total generated-start replay work independently of
                // rectangle count and file size. These are construction writes,
                // not arbitrary tick-time native World ownership.
                const auto generated_limit = std::min<std::uint64_t>(
                    64ULL * static_cast<std::uint64_t>(extent.x) * extent.y, 32'000'000ULL);
                std::uint64_t generated_work = 0;
                const auto reserve_generated_work = [&](std::uint64_t cells) {
                    if (cells > generated_limit - generated_work)
                        throw std::invalid_argument("Generated-grid edit replay budget exceeded");
                    generated_work += cells;
                };
                // The same integer-disc geometry as starting paint, with
                // ordered overwrite and Erase (material zero) preserved.
                for (std::int64_t i = 0; i < generated_edits.size(); ++i) {
                    if (generated_edits[i].get_type() != Variant::ARRAY)
                        throw std::invalid_argument("Generated-grid edit must be an array");
                    const Array stamp = generated_edits[i];
                    if (stamp.size() != 4 && stamp.size() != 5)
                        throw std::invalid_argument("Generated-grid edit has invalid arity");
                    std::int64_t v[5]{};
                    for (std::int64_t j = 0; j < stamp.size(); ++j) {
                        if (stamp[j].get_type() != Variant::INT)
                            throw std::invalid_argument("Generated-grid edit requires integer values");
                        v[j] = static_cast<std::int64_t>(stamp[j]);
                    }
                    const auto material_id = static_cast<std::uint16_t>(v[stamp.size()-1]);
                    if (v[stamp.size()-1] < 0 || v[stamp.size()-1] > 255 ||
                        !cybersand::valid_material(material_id) ||
                        v[0] < 0 || v[1] < 0 || v[0] >= extent.x || v[1] >= extent.y)
                        throw std::invalid_argument("Invalid generated-grid edit coordinates/material");
                    const auto material = static_cast<cybersand::Material>(material_id);
                    const auto& initial = cybersand::MaterialRules::descriptor(material);
                    const Tuple cell{material, material == cybersand::Material::Water
                        ? config->water_experiment_policy.maximum() : initial.initial_state_a,
                        initial.initial_state_b};
                    if (stamp.size() == 5) {
                        if (v[2] < 1 || v[3] < 1 || v[2] > extent.x - v[0] ||
                            v[3] > extent.y - v[1])
                            throw std::invalid_argument("Generated-grid box edit outside extent");
                        reserve_generated_work(static_cast<std::uint64_t>(v[2]) * v[3]);
                        for (auto y = v[1]; y < v[1]+v[3]; ++y)
                            for (auto x = v[0]; x < v[0]+v[2]; ++x)
                                map[static_cast<std::size_t>(y)*extent.x + x] = cell;
                    } else {
                        const auto radius = v[2];
                        if (radius < 2 || radius > 24)
                            throw std::invalid_argument("Invalid generated-grid brush radius");
                        const auto left = std::max<std::int64_t>(0,v[0]-radius);
                        const auto top = std::max<std::int64_t>(0,v[1]-radius);
                        const auto right = std::min<std::int64_t>(extent.x,v[0]+radius+1);
                        const auto bottom = std::min<std::int64_t>(extent.y,v[1]+radius+1);
                        reserve_generated_work(static_cast<std::uint64_t>(right-left) * (bottom-top));
                        for (auto dy = std::max<std::int64_t>(-radius,-v[1]);
                             dy <= std::min<std::int64_t>(radius, extent.y-1-v[1]); ++dy) {
                            const auto half = static_cast<std::int64_t>(
                                std::floor(std::sqrt(static_cast<double>(radius*radius-dy*dy))));
                            for (auto x = std::max<std::int64_t>(0,v[0]-half);
                                 x < std::min<std::int64_t>(extent.x,v[0]+half+1); ++x)
                                map[static_cast<std::size_t>(v[1]+dy)*extent.x + x] = cell;
                        }
                    }
                }
                const std::size_t stride = material_baseline ? 2U : 1U;
                std::vector<std::uint8_t> expected(map.size() * stride, 0);
                for (std::size_t i = 0; i < map.size(); ++i)
                    expected[i * stride] = static_cast<std::uint8_t>(map[i].material);
                generated_expected_material_sha = prepared_liquid_detail::digest(cybersand::Sha256::of(
                    {expected.data(), expected.size()}));
            }
            input.mass_bits = config->water_experiment_policy.mass_bits();
            input.ambient_temperature = config->ambient_temperature;
            input.setup.kind = cybersand::setup::SetupKind::MicroScenario;
            input.setup.definition_schema = 2;
            input.setup.definition_digest.emplace();
            // Retain the existing host-validated Workbench definition identity.
            // Generator recipe and exact copied play-plane identities remain
            // additional, independent receipt fields (not a false host digest).
            std::copy(definition_bytes.ptr(), definition_bytes.ptr()+32, input.setup.definition_digest->begin());
            input.setup.seed = static_cast<std::uint64_t>(seed);
            input.setup.domain = {0, 0, static_cast<std::uint32_t>(extent.x), static_cast<std::uint32_t>(extent.y)};
            // Binding a host digest does not establish a native definition compiler.
            input.setup.coverage = cybersand::setup::SetupCoverage::RegisteredDefinitionAndPayload;
            input.setup.gaps = cybersand::setup::kKnownSetupGaps;
            if (material_baseline) {
                // Exact reserve prevents geometric reallocation of a dense
                // 2048-square baseline's temporary prepared tuples.
                input.cells.reserve(static_cast<std::size_t>(std::count_if(map.begin(),map.end(),
                    [](const Tuple& cell) { return cell.material != cybersand::Material::Empty; })));
            }
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
        }
        const auto water_assignment = config->liquid_solver_policy.assignment(static_cast<std::uint16_t>(cybersand::Material::Water));
        const bool whole_water = water_assignment &&
            (water_assignment->family == cybersand::LiquidSolverFamily::CellularYieldV1 ||
             water_assignment->family == cybersand::LiquidSolverFamily::InertialCellularV1);
        const bool normalize_water = !rule.is_empty() || (convert && whole_water);
        // Wave's conserved stored mass can legitimately exceed the nominal
        // 255-unit cell after real ticks. Retuning a Wave owner preserves that
        // uint16 payload exactly. Other laws have no corresponding carrier;
        // refuse a retained conversion before normalization could truncate it.
        if (retain && adapter->world_->wave_flow_enabled() && !config->wave_flow.enabled) {
            const auto nominal_mass = config->water_experiment_policy.maximum();
            for (const auto& cell : input.cells)
                if (cell.material == cybersand::Material::Water && cell.state_a > nominal_mass)
                    throw std::invalid_argument(
                        "Retained Wave Water overfill exceeds the target law's cell capacity; load a comparison scene with the requested solver");
        }
        auto result = std::make_unique<cybersand::PreparedWorldBuilder::Result>(cybersand::PreparedWorldBuilder::prepare(
            *config, input, normalize_water ? cybersand::normalization::NormalizationOptIn::WaterNormalizeV1 :
                cybersand::normalization::NormalizationOptIn::None, limits));
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
        pending->world->configure_transient_obstacles({0, 0, extent.x, extent.y}, workbench);
        if (generated || material_baseline) {
            // Authoritative material-ID equality is not render-copy equality:
            // copy_material_cells() intentionally dithers fractional Water and
            // overlays in-flight ballistic parcels. Only stored_material()
            // reflects the constructed World that native physics will tick.
            // This is one bounded native construction-time scan, never a
            // per-cell GDScript call or a tick-path traversal.
            const std::size_t stride = material_baseline ? 2U : 1U;
            std::vector<std::uint8_t> readback(static_cast<std::size_t>(extent.x) * extent.y * stride);
            if (material_baseline) {
                cybersand::material_baseline::copy(*pending->world, readback, extent.x, extent.y);
            } else {
                for (std::int32_t y = 0; y < extent.y; ++y) {
                    for (std::int32_t x = 0; x < extent.x; ++x)
                        readback[static_cast<std::size_t>(y) * extent.x + x] =
                            static_cast<std::uint8_t>(pending->world->stored_material(x, y));
                }
            }
            const auto installed_digest = prepared_liquid_detail::digest(cybersand::Sha256::of(
                {readback.data(), readback.size()}));
            if (installed_digest != generated_expected_material_sha)
                throw std::invalid_argument("Generated-grid authoritative prepared-World material readback differs from accepted input");
        }
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
            auto& initial = pending->workbench->pending;
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
        CyberNativeCellWorld::parse_body_state_values(pending->initial_bodies, pending->initial_body_input, true);
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

        if (authoring_patch) {
            // Main may stage a fresh physical sample while native preparation
            // waits. The source-mask check alone cannot certify that new sample.
            const Dictionary patch = options["workbench_authoring_patch"];
            const PackedInt32Array cells = patch["cells"];
            for (std::int64_t i = 0; i < cells.size(); i += 3)
                if (pending->world->transient_obstacle_at(cells[i], cells[i + 1]) != 0)
                    throw std::invalid_argument("Authoring patch intersects the prepared physical owner");
        }

        Dictionary conversion_receipt;
        if (retain) {
            const auto transfer = pending->world->inherit_workbench_liquid_state(*adapter->world_,
                {0,0,extent.x,extent.y},convert,normalize_water);
            const auto before = adapter->world_->quantity_ledger();
            const auto after = pending->world->quantity_ledger();
            const auto& norm = prepared.setup().normalization_receipt();
            const auto produced = (norm ? norm->totals().positive_delta : 0U) + transfer.halo_normalization_produced;
            const auto consumed = (norm ? norm->totals().negative_delta : 0U) + transfer.halo_normalization_consumed;
            // In-flight parcel Water is part of both owners' inventory (BW-001).
            const auto water_before = before.water_visible + before.water_overfill + before.water_ballistic;
            const auto water_after = after.water_visible + after.water_overfill + after.water_ballistic;
            if (water_before + produced != water_after + consumed + transfer.discarded_overfill + transfer.clipped_visible_water +
                    transfer.discarded_in_flight_water)
                throw std::logic_error("Workbench conversion Water balance did not close");
            conversion_receipt["requested"] = convert;
            conversion_receipt["source_policy_sha256"] = prepared_liquid_detail::digest(adapter->world_->liquid_solver_policy().policy_hash());
            conversion_receipt["target_policy_sha256"] = prepared_liquid_detail::digest(pending->world->liquid_solver_policy().policy_hash());
            conversion_receipt["discarded_water_overfill"] = transfer.discarded_overfill;
            conversion_receipt["preserved_in_flight_water"] = static_cast<std::int64_t>(transfer.preserved_in_flight_water);
            conversion_receipt["discarded_in_flight_water"] = static_cast<std::int64_t>(transfer.discarded_in_flight_water);
            conversion_receipt["discarded_gas_amount"] = transfer.discarded_gas;
            conversion_receipt["preserved_water_overfill"] = transfer.preserved_overfill;
            conversion_receipt["preserved_gas_amount"] = transfer.preserved_gas;
            conversion_receipt["preserved_inertial_cells"] = transfer.preserved_inertial_cells;
            conversion_receipt["discarded_inertial_cells"] = transfer.discarded_inertial_cells;
            conversion_receipt["discarded_pressure_flow_cells"] = transfer.discarded_pressure_flow_cells;
            Dictionary kept_materials, clipped_materials;
            std::int64_t kept_cells=0,clipped_cells=0;
            for (std::size_t i=0;i<transfer.clipped_materials.size();++i) {
                if (transfer.preserved_halo_materials[i]) {
                    kept_materials[static_cast<std::int64_t>(i)]=transfer.preserved_halo_materials[i];
                    kept_cells+=static_cast<std::int64_t>(transfer.preserved_halo_materials[i]);
                }
                if (transfer.clipped_materials[i]) {
                    clipped_materials[static_cast<std::int64_t>(i)]=transfer.clipped_materials[i];
                    clipped_cells+=static_cast<std::int64_t>(transfer.clipped_materials[i]);
                }
            }
            conversion_receipt["preserved_halo_materials"]=kept_materials;
            conversion_receipt["clipped_materials"]=clipped_materials;
            conversion_receipt["preserved_halo_cells"]=kept_cells;
            conversion_receipt["clipped_material_cells"]=clipped_cells;
            conversion_receipt["preserved_halo_visible_water"]=transfer.preserved_halo_visible_water;
            conversion_receipt["clipped_visible_water"]=transfer.clipped_visible_water;
            conversion_receipt["clipped_water_overfill"]=transfer.clipped_water_overfill;
            conversion_receipt["clipped_gas_amount"]=transfer.clipped_gas_amount;
            conversion_receipt["clipped_gas_labels"]=transfer.clipped_gas_labels;
            conversion_receipt["clipped_thermal_cells"]=transfer.clipped_thermal_cells;
            conversion_receipt["clipped_pressure_flow_cells"]=transfer.clipped_pressure_flow_cells;
            conversion_receipt["clipped_inertial_cells"]=transfer.clipped_inertial_cells;
            conversion_receipt["halo_normalization_produced"]=transfer.halo_normalization_produced;
            conversion_receipt["halo_normalization_consumed"]=transfer.halo_normalization_consumed;
            conversion_receipt["water_before"] = water_before;
            conversion_receipt["water_after"] = water_after;
            conversion_receipt["normalization_produced"] = produced;
            conversion_receipt["normalization_consumed"] = consumed;
        }
        // Census the actual staged topology, including inherited halo cells
        // and gas labels, before any token or authority replacement escapes.
        if (default_demo || workbench) {
            if (const auto refused = cybersand::PreparedWorldBuilder::validate_initial_pressure_capacity(
                    *pending->world, prepared.setup().domain(), limits.maximum_side, retain)) {
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
            if (generated) {
                pending->receipt["generated_grid_schema"] = 1;
                pending->receipt["generated_source_origin"] = generated_claim["origin"];
                pending->receipt["generated_source_sha256"] = generated_claim["sha256"];
                pending->receipt["generated_prepared_material_sha256"] = generated_expected_material_sha;
                pending->receipt["generated_recipe_sha256"] = generated_claim["recipe_sha256"];
                pending->receipt["generated_generator_fingerprint"] = generated_claim["generator_fingerprint"];
                pending->receipt["generated_plane_revision"] = generated_claim["plane_revision"];
                pending->receipt["generated_generator_revision"] = generated_claim["generator_revision"];
                pending->receipt["generated_generator_seed"] = generated_claim["generator_seed"];
                pending->receipt["generated_receipt_hashes"] = generated_claim["receipt_hashes"];
                pending->receipt["generated_edit_count"] = generated_edits.size();
            }
            if (material_baseline) {
                pending->receipt["material_baseline_schema"] = cybersand::material_baseline::kSchema;
                pending->receipt["material_baseline_source_sha256"] = baseline_claim["sha256"];
                pending->receipt["material_baseline_prepared_material_sha256"] = generated_expected_material_sha;
                pending->receipt["material_baseline_edit_count"] = generated_edits.size();
            }
            if (retain) pending->receipt["workbench_conversion"] = conversion_receipt;
            if (authoring_patch) pending->receipt["workbench_authoring_patch"] = authoring_patch_receipt;
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
        Dictionary wave_flow;
        const auto& wave = pending->world->config().wave_flow;
        wave_flow["enabled"] = wave.enabled;
        wave_flow["substeps"] = wave.substeps;
        wave_flow["active_rows"] = wave.active_rows;
        wave_flow["gain"] = wave.gain;
        wave_flow["deep_gain"] = wave.deep_gain;
        wave_flow["floor_gain"] = wave.floor_gain;
        wave_flow["flux_smoothing"] = wave.flux_smoothing;
        wave_flow["gain_confined"] = wave.gain_confined;
        wave_flow["stiffness"] = wave.stiffness;
        wave_flow["damp_shift"] = wave.damp_shift;
        wave_flow["coast"] = wave.coast;
        wave_flow["level_shift"] = wave.level_shift;
        wave_flow["sleep_after"] = wave.sleep_after;
        wave_flow["wake_peak"] = wave.wake_peak;
        wave_flow["rest_head"] = wave.rest_head;
        wave_flow["stick"] = wave.stick;
        wave_flow["calm"] = wave.calm;
        wave_flow["calm_damp_shift"] = wave.calm_damp_shift;
        wave_flow["maximum_mass"] = wave.maximum_mass;
        wave_flow["empty_pour_shift"] = wave.empty_pour_shift;
        wave_flow["flow_share_shift"] = wave.flow_share_shift;
        wave_flow["adhesion_shift"] = wave.adhesion_shift;
        pending->receipt["wave_flow"] = wave_flow;
        if (wave.enabled) pending->receipt["wave_transport_admission"] = "workbench_baseline_to_native_defaults_v1";
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
        ++adapter->resident_source_constructions_;
        return static_cast<std::int64_t>(token);
    } catch (const cybersand::LiquidPolicyRefused& error) {
        refuse_liquid_policy(error.refusal());
        return 0;
    } catch (const std::invalid_argument& error) {
        refuse_liquid_policy({cybersand::LiquidPolicyRefusalCode::MalformedPolicy, std::nullopt, error.what()});
        return 0;
    } catch (const std::length_error& error) {
        refuse_liquid_policy({cybersand::LiquidPolicyRefusalCode::CapacityRefused, std::nullopt, error.what()});
        return 0;
    } catch (const std::bad_alloc&) {
        refuse_liquid_policy({cybersand::LiquidPolicyRefusalCode::CapacityRefused, std::nullopt,
                             "Workbench preparation allocation refused"});
        return 0;
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
    if (adapter->pending_liquid_world_->continuation) {
        // Body masks are intentionally absent from physical_state_hash(). A
        // new host dependency can therefore appear without a physical-hash
        // change; refuse it before any swap even for a direct native caller.
        try { validate_continuation_dependencies(*adapter.ptr()); }
        catch (const std::exception& error) {
            adapter->pending_liquid_world_.reset();
            error_ = String(error.what());
            return false;
        }
    }
    if (adapter->pending_liquid_world_->continuation_dirty) {
        try { refresh_continuation_receipt(*adapter.ptr()); }
        catch (const std::exception& error) {
            adapter->pending_liquid_world_.reset();
            error_ = String(error.what());
            return false;
        }
    }
    auto pending = std::move(adapter->pending_liquid_world_); // One use, also on refusal.
    if (pending->receipt.has("workbench_authoring_patch")) {
        // The physical hash binds scheduling-core coverage, which can remain
        // unchanged when the exact simulation rectangle moves within a core.
        // An authoring patch was admitted against this exact retained region.
        const auto region = adapter->world_->simulation_region();
        if (!region || region->x != pending->origin.x || region->y != pending->origin.y ||
            region->width != pending->size.x || region->height != pending->size.y) {
            error_ = "Retained authoring simulation region changed after preparation";
            return false;
        }
    }
    if (adapter->world_->has_failed() || pending->world->has_failed() || pending->retained_generation != adapter->liquid_policy_session_generation_ ||
        pending->retained_revision != adapter->revision_ || pending->retained_hash != adapter->world_->physical_state_hash() ||
        pending->retained_cadence != adapter->cadence_lod_enabled_ || pending->retained_window != adapter->simulation_window_enabled_) {
        error_ = "Retained World changed after preparation";
        return false;
    }
    std::unique_ptr<CyberNativeCellWorld::PendingLiquidWorld> resident_departure;
    try {
        if (adapter->active_resident_handle_!=0) {
            if (!pending->workbench || pending->extent!=Vector2i(512,512) || pending->cadence)
                throw std::invalid_argument("Resident replacement must remain an admitted actor-free persistent area");
            for (const auto& owner:pending->workbench->sample.owners)
                if (owner.instance!=0) throw std::invalid_argument("Resident replacement is pinned by target actors");
            cybersand::persistent_areas::validate_domain(*pending->world);
        }
        resident_departure=resident_stage_departure(*adapter.ptr());
    }
    catch (const std::exception& error) { error_=String(error.what()); return false; }
    // No allocations, capture, configuration changes or host callbacks after
    // this fence. All final native facts and copied receipts were prepared.
    resident_take_active(*adapter.ptr(),std::move(resident_departure));
    adapter->world_.swap(pending->world);
    adapter->worker_threads_ = adapter->world_->config().worker_threads;
    adapter->workbench_.swap(pending->workbench);
    adapter->extent_ = pending->extent;
    adapter->default_demo_recipe_active_ = pending->reset_demo_coupling;
    if (pending->reset_demo_coupling) adapter->reset_demo_coupling_parameters();
    adapter->render_exchange_.swap(pending->exchange);
    adapter->applied_liquid_setup_ = pending->setup;
    std::swap(adapter->applied_liquid_construction_receipt_, pending->receipt);
    adapter->liquid_construction_attempt_.clear();
    ++adapter->liquid_policy_session_generation_;
    // WCX/BW-001: counters describe one World; requested settings persist and are
    // ignored by a World without ballistic Water.
    adapter->spray_tick_ = {};
    adapter->spray_total_ = {};
    adapter->spray_budget_used_.fill(0);
    adapter->spray_jet_phase_ = 0;
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
