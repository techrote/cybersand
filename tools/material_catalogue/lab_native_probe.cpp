// Candidate-only consumer. Compiled by lab.py outside the source repository.
// Reuses the actual native sparse resolver; it is not a second World simulator.
#include "catalogue.shadow.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/material_rules.hpp"

#include <array>
#include <cstdlib>
#include <iostream>
#include <string_view>

namespace shadow = cybersand::material_catalogue_shadow;
using cybersand::Material;
using cybersand::InteractionRules;

namespace {
std::size_t checks = 0;
void require(bool condition, std::string_view message) {
    ++checks;
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(2);
    }
}

std::array<cybersand::PairInteractionRule, shadow::kPairInteractionRules.size()> rules() {
    std::array<cybersand::PairInteractionRule, shadow::kPairInteractionRules.size()> out{};
    for (std::size_t index = 0; index < out.size(); ++index) {
        const auto& row = shadow::kPairInteractionRules[index];
        out[index] = {row.id, row.channels,
            static_cast<cybersand::InteractionTriggerKind>(row.trigger),
            static_cast<cybersand::InteractionMatchKind>(row.match),
            static_cast<Material>(row.first), static_cast<Material>(row.second),
            static_cast<Material>(row.first_product), static_cast<Material>(row.second_product),
            row.probability, row.accounting, row.revalidation_tags, row.version,
            row.supersedes, row.tuning_pass_id};
    }
    return out;
}

cybersand::MaterialDefinition descriptor(std::size_t id) {
    const auto& row = shadow::kMaterialDefinitions[id];
    return {row.name, static_cast<cybersand::MaterialState>(row.state), row.density,
        row.rgba, row.movable, row.valid, row.current_rule_available,
        static_cast<cybersand::RuleKernel>(row.kernel), row.initial_state_a,
        row.initial_state_b, row.maximum_write_radius,
        static_cast<cybersand::DensityMotion>(row.density_motion),
        row.accepts_density_exchange, static_cast<cybersand::LateralFlowMode>(row.lateral_flow),
        row.viscosity_index};
}

unsigned number(const char* value) {
    char* end = nullptr;
    const auto result = std::strtoul(value, &end, 10);
    if (end == value || *end != '\0' || result > 255U) std::exit(3);
    return static_cast<unsigned>(result);
}
}  // namespace

int main(int argc, char** argv) {
    if (argc != 5) return 3;
    const auto candidate_id = number(argv[1]);
    const auto source_id = number(argv[2]);
    const auto target_id = number(argv[3]);
    const auto roll = number(argv[4]);
    require(candidate_id < shadow::kMaterialDefinitions.size(), "Candidate descriptor is absent");
    require(cybersand::kMaterialDefinitions.size() == 132U, "Production registry changed");
    require(!cybersand::valid_material(10U) && !cybersand::valid_material(132U), "Reserved/new production identities changed");
    const auto compiled = descriptor(candidate_id);
    const auto& cap = shadow::kCapabilities[candidate_id];
    require(compiled.valid && cap.valid, "Candidate validity was not compiled");
    require(compiled.density == shadow::kMaterialDefinitions[candidate_id].density, "Native descriptor conversion lost density");
    require(compiled.rgba == shadow::kMaterialDefinitions[candidate_id].rgba, "Native descriptor conversion lost appearance bytes");
    require(shadow::kVisualStateSources[candidate_id] <= 2U, "Unsupported visual projection");
    if (candidate_id == 132U) {
        require(!cap.hard_surface, "Synthetic powder inherited a hard-surface identity");
        require(compiled.kernel == cybersand::RuleKernel::Sand && compiled.state == cybersand::MaterialState::Powder,
                "Synthetic fixture changed its qualified mechanism");
    }
    const auto candidate_rules = rules();
    std::size_t differing = 0;
    std::size_t selected_count = 0;
    std::size_t baseline_selected_count = 0;
    for (std::size_t index = 0; index < candidate_rules.size(); ++index) {
        const auto& rule = candidate_rules[index];
        for (unsigned orientation = 0; orientation < 2U; ++orientation) {
            const auto first = orientation == 0U ? rule.first : rule.second;
            const auto second = orientation == 0U ? rule.second : rule.first;
            unsigned successes = 0;
            for (unsigned value = 0; value < 256U; ++value) {
                const auto actual = InteractionRules::resolve_pair_from(candidate_rules, first, second, static_cast<std::uint8_t>(value));
                const bool matches = orientation == 0U || rule.first == rule.second ||
                    rule.match != cybersand::InteractionMatchKind::Ordered;
                if (matches) {
                    require(actual.matched, "Candidate pair matching/orientation changed");
                    require(actual.rule_index == index, "Candidate legacy priority/slot changed");
                    require(actual.selected == (value <= rule.probability), "Threshold T must select T+1 of 256 rolls");
                    const bool reversed = orientation != 0U && rule.first != rule.second &&
                        rule.match != cybersand::InteractionMatchKind::Symmetric;
                    require(actual.source_product == (reversed ? rule.second_product : rule.first_product) &&
                            actual.target_product == (reversed ? rule.first_product : rule.second_product),
                            "Endpoint positional identity changed");
                }
                successes += actual.selected ? 1U : 0U;
                selected_count += actual.selected ? 1U : 0U;
                const auto original = InteractionRules::resolve_pair(first, second, static_cast<std::uint8_t>(value));
                baseline_selected_count += original.selected ? 1U : 0U;
                if (actual.matched != original.matched || actual.selected != original.selected ||
                    (actual.selected && (actual.source_product != original.source_product || actual.target_product != original.target_product))) ++differing;
            }
            const bool matches = orientation == 0U || rule.first == rule.second || rule.match != cybersand::InteractionMatchKind::Ordered;
            // The reverse of an Ordered rule can legitimately be owned by a
            // different Ordered slot. It is validated when that slot is visited.
            if (matches) require(successes == static_cast<unsigned>(rule.probability) + 1U, "Probability enumeration failed");
        }
    }
    const auto diagnostic = InteractionRules::resolve_pair_from(candidate_rules,
        static_cast<Material>(source_id), static_cast<Material>(target_id), static_cast<std::uint8_t>(roll));
    const auto native_diagnostic = InteractionRules::resolve_pair(
        static_cast<Material>(source_id), static_cast<Material>(target_id), static_cast<std::uint8_t>(roll));
    std::cout << "{\"ok\":true,\"backend\":\"native_sparse_resolver_and_descriptor_fixture_v1\","
        "\"runtime_active\":false,\"world_simulation\":false,\"production_registry_unchanged\":true,\"checks\":" << checks
        << ",\"candidate_material\":{\"id\":" << candidate_id
        << ",\"name\":\"" << compiled.name << "\",\"density\":" << compiled.density
        << ",\"kernel\":" << static_cast<unsigned>(compiled.kernel)
        << ",\"viscosity_index\":" << static_cast<unsigned>(compiled.viscosity_index)
        << ",\"hard_surface\":" << (cap.hard_surface ? "true" : "false")
        << ",\"granular_support\":" << (cap.granular_support ? "true" : "false")
        << ",\"visual_state_source\":" << static_cast<unsigned>(shadow::kVisualStateSources[candidate_id])
        << ",\"rgba\":[" << static_cast<unsigned>(compiled.rgba[0]) << ',' << static_cast<unsigned>(compiled.rgba[1]) << ','
        << static_cast<unsigned>(compiled.rgba[2]) << ',' << static_cast<unsigned>(compiled.rgba[3]) << "]}"
        << ",\"comparison\":{\"candidate_selected\":" << selected_count << ",\"baseline_selected\":" << baseline_selected_count
        << ",\"different_outcomes\":" << differing << ",\"domain\":\"all 256 rolls, both orientations of every candidate sparse rule\"}"
        << ",\"diagnostic\":{\"source\":" << source_id << ",\"target\":" << target_id << ",\"roll\":" << roll
        << ",\"status\":\"" << (!diagnostic.matched ? "no_matching_rule" : diagnostic.selected ? "selected" : "failed_probability_roll") << "\""
        << ",\"matched\":" << (diagnostic.matched ? "true" : "false")
        << ",\"selected\":" << (diagnostic.selected ? "true" : "false")
        << ",\"production_selected\":" << (native_diagnostic.selected ? "true" : "false");
    if (diagnostic.matched) {
        const auto& rule = candidate_rules[diagnostic.rule_index];
        const auto source_defaults = descriptor(static_cast<unsigned>(diagnostic.source_product));
        const auto target_defaults = descriptor(static_cast<unsigned>(diagnostic.target_product));
        std::cout << ",\"rule_slot\":" << diagnostic.rule_index << ",\"rule_id\":\"" << rule.id << "\""
            << ",\"probability_threshold\":" << static_cast<unsigned>(rule.probability)
            << ",\"successful_rolls_of_256\":" << static_cast<unsigned>(rule.probability) + 1U
            << ",\"source_product\":" << static_cast<unsigned>(diagnostic.source_product)
            << ",\"target_product\":" << static_cast<unsigned>(diagnostic.target_product)
            << ",\"effects_version\":1,\"endpoint_effect\":\"replace_with_defaults\""
            << ",\"source_product_descriptor_defaults\":{\"state_a\":" << static_cast<unsigned>(source_defaults.initial_state_a)
            << ",\"state_b\":" << static_cast<unsigned>(source_defaults.initial_state_b) << "}"
            << ",\"target_product_descriptor_defaults\":{\"state_a\":" << static_cast<unsigned>(target_defaults.initial_state_a)
            << ",\"state_b\":" << static_cast<unsigned>(target_defaults.initial_state_b) << "}"
            << ",\"world_writes_executed\":false,\"water_policy_required_for_product_quantity\":"
            << ((diagnostic.source_product == Material::Water || diagnostic.target_product == Material::Water) ? "true" : "false");
    }
    std::cout << "},\"limits\":[\"Resolver selection does not observe World cadence, masks, sleeping or competing mechanisms.\","
        "\"No candidate movement, state mutation, quantity ledger or production install was executed.\","
        "\"Legacy endpoint replacement uses World product initialisation, target then source, including applied Water maximum and same-ID reinitialisation.\"]}\n";
}
