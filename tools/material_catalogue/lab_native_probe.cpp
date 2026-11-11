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

struct PairDifference {
    unsigned source = 0;
    unsigned target = 0;
    unsigned example_roll = 0;
    unsigned different_rolls = 0;
};

struct Comparison {
    std::size_t candidate_selected = 0;
    std::size_t baseline_selected = 0;
    std::size_t different = 0;
    std::size_t introduced = 0;
    std::size_t removed = 0;
    std::size_t probability_changed = 0;
    std::size_t products_changed = 0;
    std::size_t queried_pairs = 0;
    std::array<PairDifference, shadow::kPairInteractionRules.size() * 4U> changes{};
    std::size_t changed_pairs = 0;
};

Comparison compare(std::span<const cybersand::PairInteractionRule> candidate_rules) {
    // Unique directed queries in either sparse set include removed domains,
    // self-pairs and separately authored opposite Ordered rules exactly once.
    std::array<bool, 65536> queries{};
    const auto include = [&queries](std::span<const cybersand::PairInteractionRule> rows) {
        for (const auto& rule : rows) {
            const auto first = static_cast<unsigned>(rule.first);
            const auto second = static_cast<unsigned>(rule.second);
            queries[first * 256U + second] = true;
            if (rule.match != cybersand::InteractionMatchKind::Ordered)
                queries[second * 256U + first] = true;
        }
    };
    include(candidate_rules);
    include(InteractionRules::pair_rules());
    Comparison result{};
    for (unsigned pair = 0; pair < queries.size(); ++pair) {
        if (!queries[pair]) continue;
        ++result.queried_pairs;
        PairDifference change{pair / 256U, pair % 256U, 0U, 0U};
        for (unsigned roll = 0; roll < 256U; ++roll) {
            const auto source = static_cast<Material>(change.source);
            const auto target = static_cast<Material>(change.target);
            const auto actual = InteractionRules::resolve_pair_from(candidate_rules, source, target, static_cast<std::uint8_t>(roll));
            const auto original = InteractionRules::resolve_pair(source, target, static_cast<std::uint8_t>(roll));
            result.candidate_selected += actual.selected ? 1U : 0U;
            result.baseline_selected += original.selected ? 1U : 0U;
            const bool introduced = actual.matched && !original.matched;
            const bool removed = !actual.matched && original.matched;
            const bool probability = actual.matched && original.matched && actual.selected != original.selected;
            const bool products = actual.selected && original.selected &&
                (actual.source_product != original.source_product || actual.target_product != original.target_product);
            if (introduced || removed || probability || products) {
                if (change.different_rolls == 0U) change.example_roll = roll;
                ++change.different_rolls;
                ++result.different;
            }
            result.introduced += introduced ? 1U : 0U;
            result.removed += removed ? 1U : 0U;
            result.probability_changed += probability ? 1U : 0U;
            result.products_changed += products ? 1U : 0U;
        }
        if (change.different_rolls != 0U) {
            require(result.changed_pairs < result.changes.size(), "Sparse comparison capacity exceeded");
            result.changes[result.changed_pairs++] = change;
        }
    }
    return result;
}

void print_pair_outcome(std::span<const cybersand::PairInteractionRule> rows,
                       const PairDifference& pair, bool candidate) {
    const auto resolved = InteractionRules::resolve_pair_from(rows, static_cast<Material>(pair.source),
        static_cast<Material>(pair.target), static_cast<std::uint8_t>(pair.example_roll));
    std::cout << "{\"matched\":" << (resolved.matched ? "true" : "false")
        << ",\"selected_at_example_roll\":" << (resolved.selected ? "true" : "false");
    if (resolved.matched) {
        const auto& rule = rows[resolved.rule_index];
        const auto source_defaults = candidate ? descriptor(static_cast<unsigned>(resolved.source_product)) :
            cybersand::material_definition(resolved.source_product);
        const auto target_defaults = candidate ? descriptor(static_cast<unsigned>(resolved.target_product)) :
            cybersand::material_definition(resolved.target_product);
        std::cout << ",\"rule_slot\":" << resolved.rule_index << ",\"rule_id\":\"" << rule.id << "\""
            << ",\"probability_threshold\":" << static_cast<unsigned>(rule.probability)
            << ",\"successful_rolls_of_256\":" << static_cast<unsigned>(rule.probability) + 1U
            << ",\"source_product\":" << static_cast<unsigned>(resolved.source_product)
            << ",\"target_product\":" << static_cast<unsigned>(resolved.target_product)
            << ",\"source_product_descriptor_defaults\":{\"state_a\":" << static_cast<unsigned>(source_defaults.initial_state_a)
            << ",\"state_b\":" << static_cast<unsigned>(source_defaults.initial_state_b) << "}"
            << ",\"target_product_descriptor_defaults\":{\"state_a\":" << static_cast<unsigned>(target_defaults.initial_state_a)
            << ",\"state_b\":" << static_cast<unsigned>(target_defaults.initial_state_b) << "}";
    }
    std::cout << '}';
}

void print_comparison(const Comparison& result, std::span<const cybersand::PairInteractionRule> candidate_rules) {
    std::cout << "{\"candidate_selected\":" << result.candidate_selected << ",\"baseline_selected\":" << result.baseline_selected
        << ",\"different_outcomes\":" << result.different << ",\"introduced_rule_queries\":" << result.introduced
        << ",\"removed_rule_queries\":" << result.removed << ",\"probability_changed_outcomes\":" << result.probability_changed
        << ",\"products_changed_outcomes\":" << result.products_changed << ",\"queried_directed_pairs\":" << result.queried_pairs
        << ",\"domain\":\"all 256 rolls for each unique directed pair in the union of baseline and candidate sparse rules\""
        << ",\"changed_pairs\":[";
    for (std::size_t index = 0; index < result.changed_pairs; ++index) {
        const auto& pair = result.changes[index];
        if (index != 0U) std::cout << ',';
        std::cout << "{\"source\":" << pair.source << ",\"target\":" << pair.target
            << ",\"different_rolls\":" << pair.different_rolls << ",\"example_roll\":" << pair.example_roll << ",\"baseline\":";
        print_pair_outcome(InteractionRules::pair_rules(), pair, false);
        std::cout << ",\"candidate\":";
        print_pair_outcome(candidate_rules, pair, true);
        std::cout << '}';
    }
    std::cout << "]}";
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
            }
            const bool matches = orientation == 0U || rule.first == rule.second || rule.match != cybersand::InteractionMatchKind::Ordered;
            // The reverse of an Ordered rule can legitimately be owned by a
            // different Ordered slot. It is validated when that slot is visited.
            if (matches) require(successes == static_cast<unsigned>(rule.probability) + 1U, "Probability enumeration failed");
        }
    }
    const auto comparison = compare(candidate_rules);
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
        << ",\"comparison\":";
    print_comparison(comparison, candidate_rules);
    std::cout << ",\"diagnostic\":{\"source\":" << source_id << ",\"target\":" << target_id << ",\"roll\":" << roll
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
