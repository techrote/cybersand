#pragma once

#include "cyber_native_cell_world.hpp"
#include "cyber_observation_values.hpp"
#include "cybersand/demo_snapshot.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/material_rules.hpp"
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

// This adapter is not a simulation backend. It constructs/reconstructs the
// existing World and transfers owned packed values at an exclusive boundary.
class CyberDemoBridge final : public RefCounted {
    GDCLASS(CyberDemoBridge, RefCounted)
    String error_;

    static String interaction_string(std::string_view value) {
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
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
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
            auto candidate = cybersand::demo::construct(
                config, {rectangles.ptr(), static_cast<std::size_t>(rectangles.size())});
            const auto& water_policy = candidate->config().water_experiment_policy;
            for (std::int64_t i = 0; i < water_fills.size(); i += 6) {
                const auto mass = static_cast<std::uint16_t>(
                    (2U * static_cast<std::uint32_t>(water_fills[i + 4]) *
                         water_policy.maximum() + 255U) /
                    (2U * 255U));
                const auto coherence = static_cast<std::uint8_t>(
                    (2U * static_cast<std::uint32_t>(water_fills[i + 5]) *
                         water_policy.coherence_ticks() + 12U) /
                    (2U * 12U));
                if (mass == 0U) continue;
                for (auto y = water_fills[i + 1];
                     y < water_fills[i + 1] + water_fills[i + 3]; ++y) {
                    for (auto x = water_fills[i];
                         x < water_fills[i] + water_fills[i + 2]; ++x) {
                        if (!candidate->set_cell_state(
                                x, y, cybersand::Material::Water, mass, coherence)) {
                            throw std::invalid_argument("Water fill could not be applied");
                        }
                    }
                }
            }
            install(*adapter.ptr(), std::move(candidate));
            return true;
        } catch (const std::exception& error) {
            error_ = error.what();
            return false;
        }
    }

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

    [[nodiscard]] bool import_level(const Ref<CyberNativeCellWorld>& adapter, const PackedByteArray& bytes) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            auto candidate = cybersand::demo::reconstruct(adapter->world_->config(),
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
        ClassDB::bind_method(D_METHOD("inspect_cell", "world", "point"), &CyberDemoBridge::inspect_cell);
        ClassDB::bind_method(D_METHOD("inspect_statistics", "world"), &CyberDemoBridge::inspect_statistics);
        ClassDB::bind_method(D_METHOD("inspect_interaction_profile"), &CyberDemoBridge::inspect_interaction_profile);
        ClassDB::bind_method(D_METHOD("inspect_interaction", "source_id", "target_id", "probability_roll"),
                             &CyberDemoBridge::inspect_interaction);
        ClassDB::bind_method(D_METHOD("export_level", "world"), &CyberDemoBridge::export_level);
        ClassDB::bind_method(D_METHOD("import_level", "world", "bytes"), &CyberDemoBridge::import_level);
        ClassDB::bind_method(D_METHOD("build_world", "world", "rectangles"), &CyberDemoBridge::build_world);
        ClassDB::bind_method(D_METHOD("build_tuned_world", "world", "rectangles", "profile"), &CyberDemoBridge::build_tuned_world);
        ClassDB::bind_method(D_METHOD("build_water_feel_world", "world", "rectangles",
                                     "profile", "policy", "water_fills"),
                             &CyberDemoBridge::build_water_feel_world);
        ClassDB::bind_method(D_METHOD("queue_explosion", "world", "x", "y", "radius"), &CyberDemoBridge::queue_explosion);
        ClassDB::bind_method(D_METHOD("get_last_error"), &CyberDemoBridge::get_last_error);
    }
};

}  // namespace godot
