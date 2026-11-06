#include "cybersand/material_rules.hpp"
#include "cybersand/interaction_rules.hpp"

#include <algorithm>
#include <array>

namespace cybersand {

namespace {
// The same derived tables InteractionRules::may_pair/has_pair_rule build, held
// at namespace scope. Their function-local constexpr copies are materialized
// per call by some compilers (an 8 KiB stack copy for every neighbour pair
// query). Results are identical; interaction_rules.hpp (a catalogue-digest
// input) is unchanged.
constexpr auto kPartnerSets = InteractionRules::build_partner_sets();
constexpr auto kParticipants = InteractionRules::build_participants();

[[nodiscard]] bool may_pair_fast(Material source, Material target) noexcept {
    const auto s = static_cast<std::uint8_t>(source);
    const auto t = static_cast<std::uint8_t>(target);
    return ((kPartnerSets[s][t >> 6U] >> (t & 63U)) & 1U) != 0U;
}

// The authored first match of every ordered pair, built once at load from
// InteractionRules::match_pair_from itself: (rule index + 1), 0 = none.
// Replaces a linear scan of the rule list for every partner-pair query.
struct FirstMatchTable {
    std::array<std::uint8_t, 65536> rule{};
    FirstMatchTable() noexcept {
        static_assert(InteractionRules::pair_rules().size() < 255U, "first-match table index width");
        for (unsigned s = 0; s < 256U; ++s)
            for (unsigned t = 0; t < 256U; ++t) {
                const auto match = InteractionRules::match_pair_from(
                    InteractionRules::pair_rules(), static_cast<Material>(s), static_cast<Material>(t));
                if (match.matched) rule[s * 256U + t] = static_cast<std::uint8_t>(match.rule_index + 1U);
            }
    }
};
const FirstMatchTable kFirstMatch{};
}  // namespace

std::span<const MaterialDefinition> MaterialRules::descriptors() noexcept {
    return kMaterialDefinitions;
}

const MaterialDefinition& MaterialRules::descriptor(Material material) noexcept {
    return material_definition(material);
}

bool MaterialRules::is_valid(std::uint16_t value) noexcept {
    return valid_material(value);
}

bool MaterialRules::has_current_rule(Material material) noexcept {
    const auto& definition = descriptor(material);
    return definition.valid && definition.current_rule_available;
}

bool MaterialRules::can_density_exchange(Material source, Material target,
                                         std::int64_t vertical_delta) noexcept {
    if (vertical_delta == 0) return false;
    const auto& source_definition = descriptor(source);
    const auto& target_definition = descriptor(target);
    // Grains rearrange by moving into real voids, never by swapping two
    // powders solely because their descriptor densities differ.
    if (source_definition.state == MaterialState::Powder &&
        target_definition.state == MaterialState::Powder) return false;
    // Preserve Oil's specialized no-powder-penetration path as explicit policy.
    // Heavier powders may still settle through Oil in the opposite layer order.
    if (source == Material::Oil && target_definition.state == MaterialState::Powder) return false;
    if (!source_definition.valid || !target_definition.valid ||
        !target_definition.current_rule_available ||
        !target_definition.accepts_density_exchange) {
        return false;
    }
    if (vertical_delta > 0) {
        return source_definition.density_motion == DensityMotion::Down &&
               source_definition.density > target_definition.density;
    }
    return source_definition.density_motion == DensityMotion::Up &&
           source_definition.density < target_definition.density;
}

bool MaterialRules::is_free_leveling_liquid(Material material) noexcept {
    return descriptor(material).lateral_flow == LateralFlowMode::FreeMass;
}

bool MaterialRules::is_hard_surface(Material material) noexcept {
    const auto material_id = static_cast<std::uint8_t>(material);
    if (material_id >= static_cast<std::uint8_t>(Material::LimestoneBlock) &&
        material_id <= static_cast<std::uint8_t>(kLastMaterial)) {
        return true;
    }
    switch (material) {
        case Material::Wall:
        case Material::Cloner:
        case Material::Wood:
        case Material::Ice:
        case Material::Metal:
        case Material::Concrete:
        case Material::Glass:
            return true;
        default:
            return false;
    }
}

bool MaterialRules::supports_granular_load(Material material) noexcept {
    // Explicit capability shared by player sampling and the pair policy. Seed
    // is included while it remains a grain; germinated Plant is not a powder.
    switch (material) {
        case Material::Sand: case Material::Stone: case Material::Dust:
        case Material::Seed: case Material::Salt: case Material::Sodium:
        case Material::Gunpowder: case Material::Coal: case Material::Rust:
            return true;
        default: return false;
    }
}

bool MaterialRules::has_pair_reactions(Material material) noexcept {
    return kParticipants[static_cast<std::uint8_t>(material)];
}

std::optional<PairReactionResult> MaterialRules::pair_reaction(
    Material source, Material target, std::uint8_t probability_roll) noexcept {
    // Equivalent to InteractionRules::resolve_pair: the partner-set rejection,
    // then the authored first-match scan.
    if (!may_pair_fast(source, target)) return std::nullopt;
    const auto entry = kFirstMatch.rule[static_cast<std::size_t>(static_cast<std::uint8_t>(source)) * 256U +
                                        static_cast<std::uint8_t>(target)];
    if (entry == 0U) return std::nullopt;
    // resolve_pair_from's selection and product orientation for that rule.
    const auto index = static_cast<std::size_t>(entry - 1U);
    const auto& rule = InteractionRules::pair_rules()[index];
    if (probability_roll > rule.probability) return std::nullopt;
    const bool reversed = !(source == rule.first && target == rule.second);
    const bool symmetric = rule.match == InteractionMatchKind::Symmetric;
    return PairReactionResult{
        symmetric ? rule.first_product : (reversed ? rule.second_product : rule.first_product),
        symmetric ? rule.second_product : (reversed ? rule.first_product : rule.second_product),
        static_cast<std::uint16_t>(index)};
}

std::uint8_t MaterialRules::discrete_lateral_flow_rate(
    Material material, std::uint8_t maximum_rate) noexcept {
    const auto& definition = descriptor(material);
    if (maximum_rate == 0U || definition.lateral_flow == LateralFlowMode::None) return 0U;
    const auto mobility = static_cast<std::uint16_t>(255U - definition.viscosity_index);
    const auto span = static_cast<std::uint16_t>(maximum_rate - 1U);
    const auto additional = static_cast<std::uint16_t>(
        (mobility * span + 127U) / 255U);
    return static_cast<std::uint8_t>(1U + additional);
}

std::uint16_t MaterialRules::apply_lateral_viscosity(
    Material material, std::uint16_t requested_transfer) noexcept {
    const auto& definition = descriptor(material);
    if (requested_transfer == 0U || definition.lateral_flow == LateralFlowMode::None) return 0U;
    const auto mobility = static_cast<std::uint32_t>(256U - definition.viscosity_index);
    const auto scaled = static_cast<std::uint16_t>(
        (static_cast<std::uint32_t>(requested_transfer) * mobility + 255U) / 256U);
    return std::max<std::uint16_t>(1U, scaled);
}

}  // namespace cybersand
