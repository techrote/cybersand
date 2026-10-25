#pragma once

#include "cyber_native_cell_world.hpp"
#include "cyber_observation_values.hpp"
#include "cybersand/demo_snapshot.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/material_rules.hpp"
#include <bit>
#include <algorithm>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

namespace godot {

// This adapter is not a simulation backend. It constructs/reconstructs the
// existing World and transfers owned packed values at an exclusive boundary.
class CyberDemoBridge final : public RefCounted {
    GDCLASS(CyberDemoBridge, RefCounted)
    String error_;
    Dictionary last_liquid_policy_refusal_;

    static PackedInt32Array policy_request_values(const cybersand::LiquidSolverPolicy& policy,
        std::span<const cybersand::LiquidSolverAssignment> assignments,
        std::span<const cybersand::LiquidParameterBlock> family_blocks,
        std::span<const cybersand::LiquidParameterBlock> material_blocks) {
        auto words = policy.envelope();
        words.resize(cybersand::LiquidSolverPolicy::kHeaderWords);
        words.push_back(static_cast<std::int32_t>(assignments.size()));
        for (const auto& item : assignments) {
            words.push_back(item.material); words.push_back(static_cast<std::int32_t>(item.family));
            words.push_back(static_cast<std::int32_t>(item.variant));
        }
        for (const auto blocks : {family_blocks,material_blocks}) {
            words.push_back(static_cast<std::int32_t>(blocks.size()));
            for (const auto& block : blocks) {
                words.push_back(block.owner); words.push_back(block.version);
                words.push_back(static_cast<std::int32_t>(block.values.size()));
                words.insert(words.end(),block.values.begin(),block.values.end());
            }
        }
        PackedInt32Array result;
        for (const auto word : words) result.push_back(word);
        return result;
    }

    static String interaction_string(std::string_view value) {
        if (value.empty()) return String();
        return String(value.data());
    }

    static Array interaction_channels(std::uint32_t mask) {
        Array result;
        for (const auto& channel : cybersand::InteractionRules::channels()) {
            if ((mask & cybersand::interaction_channel_bit(channel.channel)) != 0U) {
                result.push_back(interaction_string(channel.id));
            }
        }
        return result;
    }

    static Array interaction_revalidation_tags(std::uint32_t mask) {
        Array result;
        for (std::uint8_t raw = 0U;
             raw <= static_cast<std::uint8_t>(cybersand::InteractionRevalidationTag::BallisticContact);
             ++raw) {
            const auto tag = static_cast<cybersand::InteractionRevalidationTag>(raw);
            if ((mask & cybersand::interaction_revalidation_bit(tag)) != 0U) {
                result.push_back(interaction_string(cybersand::interaction_revalidation_tag_id(tag)));
            }
        }
        return result;
    }

    static Array interaction_families(cybersand::Material material) {
        Array result;
        for (const auto& membership : cybersand::InteractionRules::semantic_family_memberships()) {
            if (membership.material == material) result.push_back(interaction_string(membership.family_id));
        }
        return result;
    }

    static Array specialized_interactions(cybersand::Material material) {
        Array result;
        const auto kernel = cybersand::MaterialRules::descriptor(material).kernel;
        for (const auto& rule : cybersand::InteractionRules::specialized_rules()) {
            if (rule.material != material &&
                (rule.kernel == cybersand::RuleKernel::None || rule.kernel != kernel)) {
                continue;
            }
            Dictionary item;
            item["rule_id"] = interaction_string(rule.id);
            item["channels"] = interaction_channels(rule.channels);
            item["trigger"] = interaction_string(cybersand::interaction_trigger_id(rule.trigger));
            item["authority"] = interaction_string(rule.authority_path);
            item["represented_semantics"] = interaction_string(rule.represented_semantics);
            item["version"] = static_cast<std::int64_t>(rule.version);
            item["supersedes"] = interaction_string(rule.supersedes);
            item["tuning_pass_id"] = interaction_string(rule.tuning_pass_id);
            item["revalidation_tags"] = interaction_revalidation_tags(rule.revalidation_tags);
            item["authority_state"] = "current-world-kernel";
            item["evaluated"] = false;
            result.push_back(item);
        }
        return result;
    }

    static void install(CyberNativeCellWorld& adapter, std::unique_ptr<cybersand::World> candidate) {
        auto exchange = std::make_unique<cybersand::RenderSnapshotExchange>(
            3, 64, std::size_t{cybersand::demo::kWidth} * cybersand::demo::kHeight * 2);
        candidate->set_liquid_surface_adhesion_enabled(adapter.liquid_surface_adhesion_enabled_);
        candidate->set_simulation_region(adapter.world_->simulation_region());
        // All fallible allocation and validation precede these no-throw swaps.
        adapter.world_.swap(candidate);
        adapter.render_exchange_.swap(exchange);
        adapter.retire_liquid_construction_identity();
        ++adapter.liquid_policy_session_generation_;
        adapter.current_bodies_ = {};
        adapter.previous_bodies_ = {};
        adapter.clear_observations();
        adapter.raster_indices_.clear();
        adapter.last_stats_ = {};
        adapter.simulation_time_ms_ = 0;
        adapter.tick_failure_count_ = 0;
        adapter.last_tick_error_ = String();
        adapter.render_cells_revision_ = UINT64_MAX;
        adapter.hard_surface_rectangles_revision_ = UINT64_MAX;
        adapter.hard_surface_chunk_rectangles_revision_ = UINT64_MAX;
        adapter.render_snapshot_full_refresh_required_ = true;
        ++adapter.revision_;
        ++adapter.hard_surface_revision_;
    }

public:
    // The API reports the loader's library path, which can differ from an
    // editor shadow copy. Observe current bytes at that path; this alone does
    // not identify mapped bytes. The caller supplies no path/digest. Hash only
    // at evidence boundaries, never from a native pool job or simulation tick.
    [[nodiscard]] Dictionary loaded_native_runtime_values() const {
        String path;
        gdextension_interface::get_library_path(gdextension_interface::library,path._native_ptr());
        Dictionary out;
        out["schema_version"] = 1;
        out["observation_source"] = "godot_library_path_current_file_v1";
        out["api_reported_library_path"] = path;
        out["mapped_module_binding"] = "unverified";
        out["status"] = "unavailable";
        out["current_file_sha256"] = Variant();
        out["current_file_size"] = Variant();
        if (path.is_empty() || !FileAccess::file_exists(path)) {
            out["detail"] = "The API-reported path bytes are unavailable to FileAccess";
            return out;
        }
        const auto file = FileAccess::open(path,FileAccess::READ);
        const auto digest = FileAccess::get_sha256(path);
        if (file.is_null() || digest.length() != 64) {
            out["detail"] = "The API-reported path bytes could not be read completely";
            return out;
        }
        out["current_file_size"] = static_cast<std::int64_t>(file->get_length());
        out["current_file_sha256"] = digest;
        out["status"] = "path_file_observed";
        out["detail"] = "API-reported library path and current file hash; mapped-module and source/publication binding require separate evidence";
        return out;
    }

    [[nodiscard]] Dictionary inspect_interaction_profile() const {
        Dictionary out;
        out["schema_id"] = interaction_string(cybersand::kInteractionSchemaId);
        out["schema_version"] = static_cast<std::int64_t>(cybersand::kInteractionSchemaVersion);
        out["profile_id"] = interaction_string(cybersand::kInteractionProfileId);
        out["profile_version"] = static_cast<std::int64_t>(cybersand::kInteractionProfileVersion);

        Array channels;
        for (const auto& channel : cybersand::InteractionRules::channels()) {
            Dictionary item;
            item["id"] = interaction_string(channel.id);
            channels.push_back(item);
        }
        out["channels"] = channels;

        Array layer_kinds;
        for (const auto& kind : cybersand::InteractionRules::layer_kinds()) {
            Dictionary item;
            item["id"] = interaction_string(kind.id);
            item["precedence"] = static_cast<std::int64_t>(kind.precedence);
            layer_kinds.push_back(item);
        }
        out["layer_kinds"] = layer_kinds;

        Array authored_layers;
        for (const auto& layer : cybersand::InteractionRules::authored_layers()) {
            Dictionary item;
            item["id"] = interaction_string(layer.id);
            item["version"] = static_cast<std::int64_t>(layer.version);
            item["supersedes"] = interaction_string(layer.supersedes);
            item["channel"] = interaction_string(cybersand::interaction_channel_id(layer.channel));
            item["kind"] = interaction_string(cybersand::interaction_layer_kind_id(layer.kind));
            item["precedence"] =
                static_cast<std::int64_t>(cybersand::InteractionRules::layer_precedence(layer.kind));
            item["participant_role"] =
                interaction_string(cybersand::interaction_participant_role_id(layer.selector.role));
            item["family_id"] = interaction_string(layer.selector.family_id);
            item["has_material"] = layer.selector.has_material;
            if (layer.selector.has_material) {
                item["material"] = static_cast<std::int64_t>(layer.selector.material);
            }
            item["context_id"] = interaction_string(layer.selector.context_id);
            item["effect_ref"] = interaction_string(layer.effect_ref);
            item["tuning_pass_id"] = interaction_string(layer.tuning_pass_id);
            authored_layers.push_back(item);
        }
        out["authored_layers"] = authored_layers;

        const auto validation = cybersand::InteractionRules::validate_catalogue();
        Dictionary validation_result;
        validation_result["ok"] = validation.ok;
        validation_result["duplicate_rule_ids"] =
            static_cast<std::int64_t>(validation.duplicate_rule_ids);
        validation_result["conflicting_pair_overrides"] =
            static_cast<std::int64_t>(validation.conflicting_pair_overrides);
        validation_result["invalid_family_memberships"] =
            static_cast<std::int64_t>(validation.invalid_family_memberships);
        validation_result["unresolved_layer_conflicts"] =
            static_cast<std::int64_t>(validation.unresolved_layer_conflicts);
        validation_result["invalid_supersession_links"] =
            static_cast<std::int64_t>(validation.invalid_supersession_links);
        out["catalogue_validation"] = validation_result;

        Array families;
        for (const auto& family : cybersand::InteractionRules::semantic_families()) {
            Dictionary item;
            item["id"] = interaction_string(family.id);
            item["version"] = static_cast<std::int64_t>(family.version);
            item["purpose"] = interaction_string(family.purpose);
            families.push_back(item);
        }
        out["families"] = families;

        Array pair_rules;
        for (const auto& rule : cybersand::InteractionRules::pair_rules()) {
            Dictionary item;
            item["rule_id"] = interaction_string(rule.id);
            item["channels"] = interaction_channels(rule.channels);
            item["trigger"] = interaction_string(cybersand::interaction_trigger_id(rule.trigger));
            item["match"] = interaction_string(cybersand::interaction_match_id(rule.match));
            item["first"] = static_cast<std::int64_t>(rule.first);
            item["second"] = static_cast<std::int64_t>(rule.second);
            item["first_product"] = static_cast<std::int64_t>(rule.first_product);
            item["second_product"] = static_cast<std::int64_t>(rule.second_product);
            item["probability_threshold"] = static_cast<std::int64_t>(rule.probability);
            item["accounting"] = interaction_string(rule.accounting);
            item["version"] = static_cast<std::int64_t>(rule.version);
            item["supersedes"] = interaction_string(rule.supersedes);
            item["tuning_pass_id"] = interaction_string(rule.tuning_pass_id);
            item["revalidation_tags"] = interaction_revalidation_tags(rule.revalidation_tags);
            pair_rules.push_back(item);
        }
        out["pair_rules"] = pair_rules;

        Array coverage;
        for (const auto& entry : cybersand::InteractionRules::coverage()) {
            Dictionary item;
            item["subject_id"] = interaction_string(entry.subject_id);
            item["channel_id"] = interaction_string(entry.channel_id);
            item["authored_status"] =
                interaction_string(cybersand::interaction_authored_status_id(entry.authored_status));
            item["evidence_status"] =
                interaction_string(cybersand::interaction_evidence_status_id(entry.evidence_status));
            item["effective_rule_id"] = interaction_string(entry.effective_rule_id);
            item["limitation"] = interaction_string(entry.limitation);
            coverage.push_back(item);
        }
        out["coverage"] = coverage;

        Array passes;
        for (const auto& pass : cybersand::InteractionRules::tuning_passes()) {
            Dictionary item;
            item["id"] = interaction_string(pass.id);
            item["version"] = static_cast<std::int64_t>(pass.version);
            item["parent"] = interaction_string(pass.parent);
            item["disposition"] = interaction_string(pass.disposition);
            item["changed_rules"] = interaction_string(pass.changed_rules);
            passes.push_back(item);
        }
        out["tuning_passes"] = passes;
        Array specialized_rules;
        for (const auto& rule : cybersand::InteractionRules::specialized_rules()) {
            Dictionary item;
            item["rule_id"] = interaction_string(rule.id);
            item["version"] = static_cast<std::int64_t>(rule.version);
            item["supersedes"] = interaction_string(rule.supersedes);
            item["channels"] = interaction_channels(rule.channels);
            item["trigger"] = interaction_string(cybersand::interaction_trigger_id(rule.trigger));
            item["material"] = static_cast<std::int64_t>(rule.material);
            item["authority"] = interaction_string(rule.authority_path);
            item["represented_semantics"] = interaction_string(rule.represented_semantics);
            item["tuning_pass_id"] = interaction_string(rule.tuning_pass_id);
            item["revalidation_tags"] = interaction_revalidation_tags(rule.revalidation_tags);
            specialized_rules.push_back(item);
        }
        out["specialized_rules"] = specialized_rules;
        out["specialized_rule_count"] =
            static_cast<std::int64_t>(cybersand::InteractionRules::specialized_rules().size());
        out["specialized_authority"] = "native/src/world.cpp";
        out["specialized_migration_state"] =
            "represented-provenance-visible; current world kernels remain authoritative";
        return out;
    }

    [[nodiscard]] Dictionary inspect_interaction(std::int64_t source_id,
                                                 std::int64_t target_id,
                                                 std::int64_t probability_roll) const {
        if (source_id < 0 || target_id < 0 || probability_roll < 0 ||
            source_id >= static_cast<std::int64_t>(cybersand::kMaterialDefinitions.size()) ||
            target_id >= static_cast<std::int64_t>(cybersand::kMaterialDefinitions.size()) ||
            probability_roll > 255 ||
            !cybersand::valid_material(static_cast<std::uint16_t>(source_id)) ||
            !cybersand::valid_material(static_cast<std::uint16_t>(target_id))) {
            return cyber_observation::rejected("Invalid interaction inspection input");
        }

        const auto source = static_cast<cybersand::Material>(source_id);
        const auto target = static_cast<cybersand::Material>(target_id);
        const auto resolved = cybersand::InteractionRules::resolve_pair(
            source, target, static_cast<std::uint8_t>(probability_roll));

        Dictionary out;
        out["ok"] = true;
        out["schema_id"] = interaction_string(cybersand::kInteractionSchemaId);
        out["schema_version"] = static_cast<std::int64_t>(cybersand::kInteractionSchemaVersion);
        out["profile_id"] = interaction_string(cybersand::kInteractionProfileId);
        out["profile_version"] = static_cast<std::int64_t>(cybersand::kInteractionProfileVersion);
        out["source"] = source_id;
        out["target"] = target_id;
        out["probability_roll"] = probability_roll;
        out["source_families"] = interaction_families(source);
        out["target_families"] = interaction_families(target);
        out["source_specialized"] = specialized_interactions(source);
        out["target_specialized"] = specialized_interactions(target);
        out["matched"] = resolved.matched;
        out["selected"] = resolved.selected;

        const cybersand::PairInteractionRule* compact_rule =
            resolved.matched ? &cybersand::InteractionRules::pair_rules()[resolved.rule_index] : nullptr;
        Array channel_resolution;
        for (const auto& channel : cybersand::InteractionRules::channels()) {
            Dictionary item;
            item["channel"] = interaction_string(channel.id);
            const bool pair_applies =
                compact_rule != nullptr &&
                (compact_rule->channels &
                 cybersand::interaction_channel_bit(channel.channel)) != 0U;
            item["pair_rule_applies"] = pair_applies;
            item["pair_rule_selected"] = pair_applies && resolved.selected;
            if (pair_applies) {
                item["pair_rule_id"] = interaction_string(compact_rule->id);
                item["pair_match"] =
                    interaction_string(cybersand::interaction_match_id(compact_rule->match));
            }

            const auto layer = cybersand::InteractionRules::compile_layer(
                channel.channel, source, target);
            item["authored_layer_matched"] = layer.matched;
            bool conflict = layer.conflict;
            if (layer.matched) {
                const auto& authored =
                    cybersand::InteractionRules::authored_layers()[layer.layer_index];
                item["authored_layer_id"] = interaction_string(authored.id);
                item["authored_layer_kind"] =
                    interaction_string(cybersand::interaction_layer_kind_id(authored.kind));
                item["authored_layer_effect_ref"] = interaction_string(authored.effect_ref);
                item["authored_layer_precedence"] =
                    static_cast<std::int64_t>(layer.precedence);
                if (pair_applies &&
                    layer.precedence ==
                        cybersand::InteractionRules::layer_precedence(
                            cybersand::InteractionLayerKind::PairOverride)) {
                    conflict = true;
                }
            }
            item["conflict"] = conflict;

            String effective_origin = "none";
            if (conflict) {
                effective_origin = "conflict";
            } else if (layer.matched &&
                       (!pair_applies ||
                        layer.precedence >
                            cybersand::InteractionRules::layer_precedence(
                                cybersand::InteractionLayerKind::PairOverride))) {
                effective_origin = interaction_string(
                    cybersand::InteractionRules::authored_layers()[layer.layer_index].id);
            } else if (pair_applies) {
                effective_origin = interaction_string(compact_rule->id);
            } else if (layer.matched) {
                effective_origin = interaction_string(
                    cybersand::InteractionRules::authored_layers()[layer.layer_index].id);
            }
            item["effective_origin"] = effective_origin;
            channel_resolution.push_back(item);
        }
        out["channel_resolution"] = channel_resolution;

        if (!resolved.matched) {
            out["authored_status"] = "no-compact-pair-rule";
            out["note"] =
                "No compact INT pair rule; specialized or kinetic mechanisms may still apply.";
            return out;
        }

        const auto& rule = cybersand::InteractionRules::pair_rules()[resolved.rule_index];
        out["rule_id"] = interaction_string(rule.id);
        out["channels"] = interaction_channels(rule.channels);
        out["trigger"] = interaction_string(cybersand::interaction_trigger_id(rule.trigger));
        out["match"] = interaction_string(cybersand::interaction_match_id(rule.match));
        out["reversed"] = resolved.reversed;
        out["probability_threshold"] = static_cast<std::int64_t>(rule.probability);
        out["source_product"] = static_cast<std::int64_t>(resolved.source_product);
        out["target_product"] = static_cast<std::int64_t>(resolved.target_product);
        out["accounting"] = interaction_string(rule.accounting);
        out["version"] = static_cast<std::int64_t>(rule.version);
        out["supersedes"] = interaction_string(rule.supersedes);
        out["tuning_pass_id"] = interaction_string(rule.tuning_pass_id);
        for (const auto& pass : cybersand::InteractionRules::tuning_passes()) {
            if (pass.id != rule.tuning_pass_id) continue;
            out["tuning_pass_parent"] = interaction_string(pass.parent);
            out["tuning_pass_disposition"] = interaction_string(pass.disposition);
            out["tuning_pass_changed_rules"] = interaction_string(pass.changed_rules);
            break;
        }
        out["revalidation_tags"] = interaction_revalidation_tags(rule.revalidation_tags);
        out["authority"] = "InteractionRules via MaterialRules::pair_reaction";
        Array provenance_chain;
        provenance_chain.push_back(interaction_string(cybersand::kInteractionProfileId));
        provenance_chain.push_back(interaction_string(rule.tuning_pass_id));
        provenance_chain.push_back(interaction_string(rule.id));
        out["provenance_chain"] = provenance_chain;
        out["provenance"] = "explicit sparse pair override / current-behaviour profile";
        return out;
    }

    [[nodiscard]] Dictionary inspect_cell(const Ref<CyberNativeCellWorld>& adapter, Vector2i point) const {
        if (adapter.is_null() || !adapter->world_) return cyber_observation::rejected("Native world unavailable");
        return cyber_observation::cell(*adapter->world_, point);
    }

    [[nodiscard]] Dictionary inspect_statistics(const Ref<CyberNativeCellWorld>& adapter) const {
        if (adapter.is_null() || !adapter->world_) return cyber_observation::rejected("Native world unavailable");
        return cyber_observation::statistics(*adapter->world_, adapter->last_stats_);
    }

    [[nodiscard]] String get_last_error() const { return error_; }

    [[nodiscard]] bool build_tuned_world(const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles, const PackedInt32Array& profile) {
        error_ = String();
        if(adapter.is_null() || !adapter->world_) { error_="Native world unavailable"; return false; }
        try {
            auto config = adapter->world_->config();
            config.transport_policy = cybersand::TransportPolicy::unpack(
                {profile.ptr(),static_cast<std::size_t>(profile.size())});
            config.physics_diagnostics = {}; config.physics_diagnostics.enabled = true;
            config.interaction_policy = {};
            config.water_experiment_policy = cybersand::WaterExperimentPolicy{};
            config.liquid_solver_policy = {};
            config.maximum_rule_radius = CyberNativeCellWorld::kProtectedCurrentRuleRadius;
            auto candidate=cybersand::demo::construct(config,
                {rectangles.ptr(),static_cast<std::size_t>(rectangles.size())});
            install(*adapter.ptr(),std::move(candidate));
            return true;
        } catch(const std::exception& error) { error_=error.what(); return false; }
    }

    [[nodiscard]] bool build_water_feel_world(
        const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles,
        const PackedInt32Array& profile,
        const PackedInt32Array& policy,
        const PackedInt32Array& water_fills) {
        error_ = String();
        last_liquid_policy_refusal_ = Dictionary();
        return build_water_world(adapter, rectangles, profile, policy, water_fills, {},
                                 CyberNativeCellWorld::kProtectedCurrentRuleRadius);
    }

    // The same validated candidate-and-swap construction with an explicit
    // LCB-001 liquid solver policy request (the flat int32 envelope). The
    // request is decoded and admitted before any World is built; a refusal
    // returns false, records a typed refusal and keeps the live session.
    [[nodiscard]] bool build_liquid_policy_world(
        const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles,
        const PackedInt32Array& profile,
        const PackedInt32Array& policy,
        const PackedInt32Array& water_fills,
        const PackedInt32Array& liquid_policy,
        std::int64_t maximum_rule_radius = CyberNativeCellWorld::kProtectedCurrentRuleRadius) {
        error_ = String();
        last_liquid_policy_refusal_ = Dictionary();
        auto decoded = cybersand::LiquidSolverPolicy::decode(
            std::span<const std::int32_t>(liquid_policy.ptr(), static_cast<std::size_t>(liquid_policy.size())));
        if (!decoded.accepted()) {
            refuse_liquid_policy(decoded.refusal);
            return false;
        }
        return build_water_world(adapter, rectangles, profile, policy, water_fills, *decoded.policy,
                                 maximum_rule_radius);
    }

    [[nodiscard]] PackedInt32Array default_liquid_policy() const {
        PackedInt32Array words;
        for (const auto word : cybersand::LiquidSolverPolicy::default_request()) words.push_back(word);
        return words;
    }

    // Side-effect-free validation: the would-be applied receipt or the refusal.
    [[nodiscard]] Dictionary validate_liquid_policy(const PackedInt32Array& liquid_policy) const {
        auto decoded = cybersand::LiquidSolverPolicy::decode(
            std::span<const std::int32_t>(liquid_policy.ptr(), static_cast<std::size_t>(liquid_policy.size())));
        if (decoded.accepted()) {
            if (auto refusal = decoded.policy->admission_refusal()) {
                decoded.refusal = *refusal;
                decoded.policy.reset();
            }
        }
        Dictionary result;
        result["accepted"] = decoded.accepted();
        result["refusal"] = decoded.accepted() ? Variant() : Variant(refusal_dictionary(decoded.refusal));
        result["receipt"] = decoded.accepted()
            ? Variant(CyberNativeCellWorld::liquid_policy_receipt(*decoded.policy, -1)) : Variant();
        return result;
    }

    [[nodiscard]] Dictionary get_last_liquid_policy_refusal() const { return last_liquid_policy_refusal_; }

    // The UI receives native-generated request values and actual admission
    // outcomes. GDScript never reconstructs the policy wire layout or infers
    // availability from a design-only matrix cell.
    [[nodiscard]] Array liquid_policy_assignment_choices(const PackedInt32Array& request, std::int64_t material) {
        error_ = String();
        Array choices;
        const auto decoded = cybersand::LiquidSolverPolicy::decode(std::span<const std::int32_t>(
            request.ptr(), static_cast<std::size_t>(request.size())));
        if (!decoded.accepted()) { error_ = String(decoded.refusal.message().c_str()); return choices; }
        std::size_t index = 0;
        for (const auto& row : cybersand::liquid_policy_catalogue::kLiquidRows) {
            if (material != row.material_id) { ++index; continue; }
            for (std::uint8_t family = 1; family <= cybersand::LiquidSolverPolicy::kFamilyCount; ++family) {
                const auto mask = row.variant_mask[family-1];
                for (std::uint8_t variant = 0; variant < cybersand::LiquidSolverPolicy::kVariantCount; ++variant) {
                    if (variant != 0 && (mask & (1U << variant)) == 0U) continue;
                    auto assignments = std::vector<cybersand::LiquidSolverAssignment>(
                        decoded.policy->assignments().begin(),decoded.policy->assignments().end());
                    const auto former = assignments[index].family;
                    assignments[index].family = static_cast<cybersand::LiquidSolverFamily>(family);
                    assignments[index].variant = static_cast<cybersand::LiquidSolverVariant>(variant);
                    std::vector<cybersand::LiquidParameterBlock> families,materials;
                    for (const auto& block : decoded.policy->family_blocks())
                        if (std::any_of(assignments.begin(),assignments.end(),[&](const auto& item) {
                            return static_cast<std::uint16_t>(item.family) == block.owner;
                        })) families.push_back(block);
                    for (const auto& block : decoded.policy->material_blocks())
                        if (block.owner != material || former == assignments[index].family) materials.push_back(block);
                    auto edited = policy_request_values(*decoded.policy,assignments,families,materials);
                    auto choice = validate_liquid_policy(edited);
                    choice["request"] = edited;
                    choice["material"] = material;
                    choice["family"] = String(std::string(cybersand::liquid_solver_family_id(
                        static_cast<cybersand::LiquidSolverFamily>(family))).c_str());
                    choice["variant"] = String(std::string(cybersand::liquid_solver_variant_id(
                        static_cast<cybersand::LiquidSolverVariant>(variant))).c_str());
                    choice["current_default"] = family == row.default_family && variant == 0;
                    choices.push_back(choice);
                }
            }
            return choices;
        }
        error_ = "Material has no liquid solver assignment";
        return choices;
    }

    [[nodiscard]] Dictionary liquid_policy_with_inertial_damping(const PackedInt32Array& request, std::int64_t numerator) const {
        auto decoded = cybersand::LiquidSolverPolicy::decode(std::span<const std::int32_t>(
            request.ptr(),static_cast<std::size_t>(request.size())));
        if (!decoded.accepted()) return validate_liquid_policy(request);
        const bool used = std::any_of(decoded.policy->assignments().begin(),decoded.policy->assignments().end(),
            [](const auto& item) { return item.family == cybersand::LiquidSolverFamily::InertialCellularV1; });
        if (!used || numerator < 0 || numerator > cybersand::InertialParameters::kDampingDenominator) {
            Dictionary result; result["accepted"] = false; result["receipt"] = Variant();
            result["refusal"] = refusal_dictionary({cybersand::LiquidPolicyRefusalCode::UnknownParameter, std::nullopt,
                "IN damping requires an active IN family and an integer numerator from 0 through 16"});
            return result;
        }
        std::vector<cybersand::LiquidParameterBlock> blocks;
        for (const auto& block : decoded.policy->family_blocks()) if (block.owner != 4U) blocks.push_back(block);
        blocks.push_back({4U,cybersand::InertialParameters::kFamilyBlockVersion,{static_cast<std::int32_t>(numerator)}});
        auto edited = policy_request_values(*decoded.policy,decoded.policy->assignments(),blocks,decoded.policy->material_blocks());
        auto result = validate_liquid_policy(edited);
        result["request"] = edited;
        return result;
    }

    // Construction is deliberately split: the simulation owner may prepare
    // without holding its queue mutex, then fence the one-use commit under it.
    [[nodiscard]] std::int64_t prepare_liquid_world(const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles, const PackedInt32Array& profile,
        const PackedInt32Array& policy, const PackedInt32Array& water_fills,
        const PackedInt32Array& liquid_policy, const Dictionary& options);
    [[nodiscard]] std::int64_t prepare_liquid_level(const Ref<CyberNativeCellWorld>& adapter,
        const PackedByteArray& payload, const PackedInt32Array& profile,
        const PackedInt32Array& policy, const PackedInt32Array& liquid_policy, const Dictionary& options);
    [[nodiscard]] std::int64_t prepare_liquid_default_demo(const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& liquid_policy, const Dictionary& options);
private:
    [[nodiscard]] std::int64_t prepare_liquid_candidate(const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles, const PackedInt32Array& profile,
        const PackedInt32Array& policy, const PackedInt32Array& water_fills,
        const PackedInt32Array& liquid_policy, const Dictionary& options, const PackedByteArray* level_payload, bool default_demo = false);
public:
    [[nodiscard]] bool prepared_liquid_character_box_collides(const Ref<CyberNativeCellWorld>& adapter,
        std::int64_t token, Vector2 origin, Vector2 size, std::int64_t mode) const {
        // A stale view fails closed; no World reference, mutable storage or
        // tick/edit capability crosses the exclusive preparation boundary.
        if (adapter.is_null() || token <= 0 || !adapter->pending_liquid_world_ ||
            adapter->pending_liquid_world_->token != static_cast<std::uint64_t>(token)) return true;
        return CyberNativeCellWorld::character_box_collides_in(
            adapter->pending_liquid_world_->world.get(), origin, size, mode);
    }
    [[nodiscard]] Dictionary prepared_liquid_world_values(const Ref<CyberNativeCellWorld>& adapter, std::int64_t token) {
        error_ = String();
        if (adapter.is_null() || token <= 0 || !adapter->pending_liquid_world_ ||
            adapter->pending_liquid_world_->token != static_cast<std::uint64_t>(token)) {
            error_ = "Preparation token is absent or retired";
            return {};
        }
        try {
            const auto& pending = *adapter->pending_liquid_world_;
            PackedByteArray cells;
            const auto size = static_cast<std::int64_t>(CyberNativeCellWorld::kWorldWidth) * CyberNativeCellWorld::kWorldHeight;
            if (cells.resize(size) != OK) throw std::bad_alloc();
            pending.world->copy_material_cells({0,0,CyberNativeCellWorld::kWorldWidth,CyberNativeCellWorld::kWorldHeight},
                std::span<std::uint8_t>{cells.ptrw(),static_cast<std::size_t>(size)},CyberNativeCellWorld::kWorldWidth);
            Dictionary out;
            out["token"] = token;
            out["terrain"] = CyberNativeCellWorld::hard_surface_chunks_from_cells(cells);
            out["initial_bodies"] = pending.initial_body_input.duplicate();
            out["initial_body_state_sha256"] = pending.initial_body_digest;
            out["candidate_physical_state_hash"] = String::num_uint64(pending.world->physical_state_hash(),16).lpad(16,"0");
            // Candidate facts are explicitly pending values. No applied receipt
            // or mutable native storage is exposed before the final owner swap.
            return out;
        } catch (const std::exception& error) {
            error_ = String(error.what());
            return {};
        }
    }
    [[nodiscard]] Dictionary prepared_liquid_run_capture(const Ref<CyberNativeCellWorld>& adapter, std::int64_t token) {
        error_ = String();
        if (adapter.is_null() || token <= 0 || !adapter->pending_liquid_world_ ||
            adapter->pending_liquid_world_->token != static_cast<std::uint64_t>(token)) {
            error_ = "Preparation token is absent or retired";
            return {};
        }
        // The encoding was captured during preparation. This copied wrapper
        // explicitly remains pending; it does not install or expose a World.
        Dictionary out;
        out["schema_version"] = 1;
        out["lifecycle"] = "prepared";
        out["token"] = token;
        out["native_run_encoding"] = adapter->pending_liquid_world_->receipt.duplicate(true);
        return out;
    }
    [[nodiscard]] bool commit_liquid_world(const Ref<CyberNativeCellWorld>& adapter, std::int64_t token);
    void discard_liquid_world(const Ref<CyberNativeCellWorld>& adapter, std::int64_t token) {
        if (adapter.is_valid() && adapter->pending_liquid_world_ &&
            adapter->pending_liquid_world_->token == static_cast<std::uint64_t>(token))
            adapter->pending_liquid_world_.reset();
    }

private:
    [[nodiscard]] static Dictionary refusal_dictionary(const cybersand::LiquidPolicyRefusal& refusal) {
        Dictionary out;
        out["code"] = String(std::string(cybersand::liquid_policy_refusal_id(refusal.code)).c_str());
        out["material"] = refusal.material ? Variant(static_cast<std::int64_t>(*refusal.material)) : Variant();
        out["detail"] = String(refusal.detail.c_str());
        return out;
    }

    void refuse_liquid_policy(const cybersand::LiquidPolicyRefusal& refusal) {
        last_liquid_policy_refusal_ = refusal_dictionary(refusal);
        error_ = String(cybersand::liquid_policy_detail::concat(
            "Liquid solver policy refused; running world preserved: ", refusal.message()).c_str());
    }

    [[nodiscard]] bool build_water_world(
        const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles,
        const PackedInt32Array& profile,
        const PackedInt32Array& policy,
        const PackedInt32Array& water_fills,
        const cybersand::LiquidSolverPolicy& liquid_policy,
        std::int64_t maximum_rule_radius) {
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            if (maximum_rule_radius != 2 && maximum_rule_radius != 3)
                throw std::invalid_argument("Maximum rule radius must be explicitly two or three");
            if (policy.size() != 4 || policy[0] != 1 || policy[1] < 3 || policy[1] > 8 ||
                policy[2] < 0 || policy[2] > 12 || policy[3] != 0) {
                throw std::invalid_argument("Invalid Water experiment policy");
            }
            if (water_fills.size() % 6 != 0 ||
                water_fills.size() / 6 >
                    static_cast<std::int64_t>(cybersand::demo::kMaximumRectangles)) {
                throw std::invalid_argument("Invalid Water fill count");
            }
            std::uint64_t fill_area = 0;
            for (std::int64_t i = 0; i < water_fills.size(); i += 6) {
                const auto x = water_fills[i], y = water_fills[i + 1];
                const auto width = water_fills[i + 2], height = water_fills[i + 3];
                const auto normalized_mass = water_fills[i + 4];
                const auto coherence = water_fills[i + 5];
                if (x < 0 || y < 0 || width <= 0 || height <= 0 ||
                    width > cybersand::demo::kWidth || height > cybersand::demo::kHeight ||
                    x > cybersand::demo::kWidth - width ||
                    y > cybersand::demo::kHeight - height ||
                    normalized_mass < 0 || normalized_mass > 255 ||
                    coherence < 0 || coherence > 12) {
                    throw std::invalid_argument("Invalid Water fill");
                }
                fill_area += static_cast<std::uint64_t>(width) *
                             static_cast<std::uint64_t>(height);
                if (fill_area > static_cast<std::uint64_t>(cybersand::demo::kWidth) *
                                    cybersand::demo::kHeight) {
                    throw std::invalid_argument("Water fill budget exceeded");
                }
            }

            auto config = adapter->world_->config();
            config.transport_policy = cybersand::TransportPolicy::unpack(
                {profile.ptr(), static_cast<std::size_t>(profile.size())});
            config.physics_diagnostics = {};
            config.physics_diagnostics.enabled = true;
            config.interaction_policy = {};
            config.water_experiment_policy = cybersand::WaterExperimentPolicy(
                static_cast<std::uint8_t>(policy[1]),
                static_cast<std::uint8_t>(policy[2]),
                cybersand::WaterRestPolicy::CurrentNormalizedV1);
            config.liquid_solver_policy = liquid_policy;
            config.maximum_rule_radius = static_cast<std::int32_t>(maximum_rule_radius);
            auto candidate = cybersand::demo::construct(
                config, {rectangles.ptr(), static_cast<std::size_t>(rectangles.size())});
            const auto& water_policy = candidate->config().water_experiment_policy;
            const auto fill_mass = [&](std::int64_t offset) {
                return static_cast<std::uint16_t>(
                    (2U * static_cast<std::uint32_t>(water_fills[offset + 4]) *
                         water_policy.maximum() + 255U) /
                    (2U * 255U));
            };
            // Whole-cell admission examines the resolved setup, not an
            // intermediate overlay. Zero-mass fills keep their existing no-op
            // meaning. This bounded construction-only map records the last
            // nonzero fill at each cell; no live World is converted or rounded.
            const bool whole_cell = candidate->whole_cell_water_enabled();
            std::vector<std::uint16_t> final_fill;
            if (whole_cell) {
                final_fill.resize(std::size_t{cybersand::demo::kWidth} * cybersand::demo::kHeight);
                for (std::int64_t i = 0; i < water_fills.size(); i += 6) {
                    if (fill_mass(i) == 0U) continue;
                    const auto owner = static_cast<std::uint16_t>(i / 6 + 1);
                    for (auto y = water_fills[i + 1]; y < water_fills[i + 1] + water_fills[i + 3]; ++y)
                        for (auto x = water_fills[i]; x < water_fills[i] + water_fills[i + 2]; ++x)
                            final_fill[std::size_t{static_cast<std::uint32_t>(y)} * cybersand::demo::kWidth +
                                       static_cast<std::uint32_t>(x)] = owner;
                }
            }
            for (std::int64_t i = 0; i < water_fills.size(); i += 6) {
                const auto mass = fill_mass(i);
                const auto coherence = static_cast<std::uint8_t>(
                    (2U * static_cast<std::uint32_t>(water_fills[i + 5]) *
                         water_policy.coherence_ticks() + 12U) /
                    (2U * 12U));
                if (mass == 0U) continue;
                for (auto y = water_fills[i + 1];
                     y < water_fills[i + 1] + water_fills[i + 3]; ++y) {
                    for (auto x = water_fills[i];
                         x < water_fills[i] + water_fills[i + 2]; ++x) {
                        if (whole_cell) {
                            if (final_fill[std::size_t{static_cast<std::uint32_t>(y)} * cybersand::demo::kWidth +
                                           static_cast<std::uint32_t>(x)] != static_cast<std::uint16_t>(i / 6 + 1))
                                continue;
                            if (mass != water_policy.maximum())
                                throw cybersand::LiquidPolicyRefused({
                                    cybersand::LiquidPolicyRefusalCode::NormalizationRequired,
                                    static_cast<std::uint16_t>(cybersand::Material::Water),
                                    "whole-cell Water setup requires explicit water-normalize-v1; "
                                    "the Godot constructor does not opt in"});
                        }
                        if (!candidate->set_cell_state(
                                x, y, cybersand::Material::Water, mass, coherence) &&
                            (candidate->stored_material(x, y) != cybersand::Material::Water ||
                             candidate->stored_state_a(x, y) != mass ||
                             candidate->stored_state_b(x, y) != coherence)) {
                            throw std::invalid_argument("Water fill could not be applied");
                        }
                    }
                }
            }
            install(*adapter.ptr(), std::move(candidate));
            return true;
        } catch (const cybersand::LiquidPolicyRefused& refused) {
            refuse_liquid_policy(refused.refusal());
            return false;
        } catch (const std::exception& error) {
            error_ = error.what();
            return false;
        }
    }

public:
    [[nodiscard]] PackedByteArray export_level(const Ref<CyberNativeCellWorld>& adapter) {
        error_ = String();
        PackedByteArray bytes;
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return bytes;
        }
        try {
            bytes.resize(static_cast<std::int64_t>(cybersand::demo::kPayloadBytes));
            cybersand::demo::copy_level(*adapter->world_,
                {bytes.ptrw(), static_cast<std::size_t>(bytes.size())});
        } catch (const std::exception& error) {
            error_ = error.what();
            bytes = PackedByteArray();
        }
        return bytes;
    }

    // LCB-001 candidate-capable persistence (CYPS v1): exact tick-boundary
    // continuation including pressure sidecars and the gas table. Import is
    // transactional: validation and construction precede the install swap.
    [[nodiscard]] PackedByteArray export_physical_state(const Ref<CyberNativeCellWorld>& adapter) {
        error_ = String();
        PackedByteArray bytes;
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return bytes;
        }
        try {
            const auto saved = adapter->world_->save_physical_state();
            bytes.resize(static_cast<std::int64_t>(saved.size()));
            std::copy(saved.begin(), saved.end(), bytes.ptrw());
        } catch (const std::exception& error) {
            error_ = error.what();
            bytes = PackedByteArray();
        }
        return bytes;
    }

    [[nodiscard]] bool import_physical_state(const Ref<CyberNativeCellWorld>& adapter, const PackedByteArray& bytes) {
        error_ = String();
        last_liquid_policy_refusal_ = Dictionary();
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            auto execution = adapter->world_->config();
            auto candidate = cybersand::World::restore_physical_state(
                execution, {bytes.ptr(), static_cast<std::size_t>(bytes.size())});
            const auto region = candidate->simulation_region();
            const auto adhesion = candidate->liquid_surface_adhesion_enabled();
            install(*adapter.ptr(), std::move(candidate));
            // install() applies the adapter's interest/adhesion; a saved state
            // carries its own, so restore them for exact continuation.
            adapter->world_->set_simulation_region(region);
            adapter->world_->set_liquid_surface_adhesion_enabled(adhesion);
            adapter->liquid_surface_adhesion_enabled_ = adhesion;
            return true;
        } catch (const cybersand::LiquidPolicyRefused& refused) {
            refuse_liquid_policy(refused.refusal());
            return false;
        } catch (const std::exception& error) {
            error_ = String(cybersand::liquid_policy_detail::concat(
                "Physical state import refused; running world preserved: ", error.what()).c_str());
            return false;
        }
    }

    [[nodiscard]] bool import_level(const Ref<CyberNativeCellWorld>& adapter, const PackedByteArray& bytes) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            // A CYSD1 level is a finite-level reconstruction on default families.
            auto config = adapter->world_->config();
            config.liquid_solver_policy = {};
            config.maximum_rule_radius = CyberNativeCellWorld::kProtectedCurrentRuleRadius;
            auto candidate = cybersand::demo::reconstruct(config,
                {bytes.ptr(), static_cast<std::size_t>(bytes.size())});
            install(*adapter.ptr(), std::move(candidate));
            return true;
        } catch (const std::exception& error) {
            error_ = error.what();
            return false;
        }
    }

    [[nodiscard]] bool build_world(const Ref<CyberNativeCellWorld>& adapter, const PackedInt32Array& rectangles) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            auto config = adapter->world_->config();
            config.transport_policy = {}; // Ordinary demos retain production Baseline.
            config.water_experiment_policy = cybersand::WaterExperimentPolicy{};
            config.liquid_solver_policy = {};
            config.maximum_rule_radius = CyberNativeCellWorld::kProtectedCurrentRuleRadius;
            auto candidate = cybersand::demo::construct(config,
                {rectangles.ptr(), static_cast<std::size_t>(rectangles.size())});
            install(*adapter.ptr(), std::move(candidate));
            return true;
        } catch (const std::exception& error) {
            error_ = error.what();
            return false;
        }
    }

    [[nodiscard]] bool queue_explosion(const Ref<CyberNativeCellWorld>& adapter,
        std::int64_t x, std::int64_t y, std::int64_t radius) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_ || x < 0 || y < 0 ||
            x >= cybersand::demo::kWidth || y >= cybersand::demo::kHeight || radius < 1 || radius > 64) {
            error_ = "Explosion outside supported bounds";
            return false;
        }
        if (adapter->world_->has_failed()) {
            error_ = "World failed; reset or replace it before accepting explosions";
            return false;
        }
        if (!adapter->world_->queue_explosion(x, y, static_cast<std::int32_t>(radius))) {
            error_ = "Explosion queue capacity exhausted";
            return false;
        }
        return true;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("loaded_native_runtime_values"), &CyberDemoBridge::loaded_native_runtime_values);
        ClassDB::bind_method(D_METHOD("inspect_cell", "world", "point"), &CyberDemoBridge::inspect_cell);
        ClassDB::bind_method(D_METHOD("inspect_statistics", "world"), &CyberDemoBridge::inspect_statistics);
        ClassDB::bind_method(D_METHOD("inspect_interaction_profile"), &CyberDemoBridge::inspect_interaction_profile);
        ClassDB::bind_method(D_METHOD("inspect_interaction", "source_id", "target_id", "probability_roll"),
                             &CyberDemoBridge::inspect_interaction);
        ClassDB::bind_method(D_METHOD("export_level", "world"), &CyberDemoBridge::export_level);
        ClassDB::bind_method(D_METHOD("import_level", "world", "bytes"), &CyberDemoBridge::import_level);
        ClassDB::bind_method(D_METHOD("export_physical_state", "world"), &CyberDemoBridge::export_physical_state);
        ClassDB::bind_method(D_METHOD("import_physical_state", "world", "bytes"),
                             &CyberDemoBridge::import_physical_state);
        ClassDB::bind_method(D_METHOD("build_world", "world", "rectangles"), &CyberDemoBridge::build_world);
        ClassDB::bind_method(D_METHOD("build_tuned_world", "world", "rectangles", "profile"), &CyberDemoBridge::build_tuned_world);
        ClassDB::bind_method(D_METHOD("build_water_feel_world", "world", "rectangles",
                                     "profile", "policy", "water_fills"),
                             &CyberDemoBridge::build_water_feel_world);
        ClassDB::bind_method(D_METHOD("build_liquid_policy_world", "world", "rectangles", "profile",
                                     "policy", "water_fills", "liquid_policy", "maximum_rule_radius"),
                             &CyberDemoBridge::build_liquid_policy_world,
                             DEFVAL(CyberNativeCellWorld::kProtectedCurrentRuleRadius));
        ClassDB::bind_method(D_METHOD("default_liquid_policy"), &CyberDemoBridge::default_liquid_policy);
        ClassDB::bind_method(D_METHOD("liquid_policy_assignment_choices", "request", "material"),
                             &CyberDemoBridge::liquid_policy_assignment_choices);
        ClassDB::bind_method(D_METHOD("liquid_policy_with_inertial_damping", "request", "numerator"),
                             &CyberDemoBridge::liquid_policy_with_inertial_damping);
        ClassDB::bind_method(D_METHOD("prepare_liquid_world", "world", "rectangles", "profile", "policy",
            "water_fills", "liquid_policy", "options"), &CyberDemoBridge::prepare_liquid_world);
        ClassDB::bind_method(D_METHOD("prepare_liquid_level", "world", "payload", "profile", "policy",
            "liquid_policy", "options"), &CyberDemoBridge::prepare_liquid_level);
        ClassDB::bind_method(D_METHOD("prepared_liquid_character_box_collides", "world", "token", "origin", "size", "mode"),
            &CyberDemoBridge::prepared_liquid_character_box_collides);
        ClassDB::bind_method(D_METHOD("prepare_liquid_default_demo", "world", "liquid_policy", "options"),
            &CyberDemoBridge::prepare_liquid_default_demo);
        ClassDB::bind_method(D_METHOD("prepared_liquid_world_values", "world", "token"), &CyberDemoBridge::prepared_liquid_world_values);
        ClassDB::bind_method(D_METHOD("prepared_liquid_run_capture", "world", "token"), &CyberDemoBridge::prepared_liquid_run_capture);
        ClassDB::bind_method(D_METHOD("commit_liquid_world", "world", "token"), &CyberDemoBridge::commit_liquid_world);
        ClassDB::bind_method(D_METHOD("discard_liquid_world", "world", "token"), &CyberDemoBridge::discard_liquid_world);
        ClassDB::bind_method(D_METHOD("validate_liquid_policy", "liquid_policy"),
                             &CyberDemoBridge::validate_liquid_policy);
        ClassDB::bind_method(D_METHOD("get_last_liquid_policy_refusal"),
                             &CyberDemoBridge::get_last_liquid_policy_refusal);
        ClassDB::bind_method(D_METHOD("queue_explosion", "world", "x", "y", "radius"), &CyberDemoBridge::queue_explosion);
        ClassDB::bind_method(D_METHOD("get_last_error"), &CyberDemoBridge::get_last_error);
    }
};

}  // namespace godot

#include "cyber_prepared_liquid_world.hpp"
