#pragma once

#include "cybersand/material.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <string_view>

namespace cybersand {

// INT-000 is deliberately a sparse authored model. The arrays in this header
// describe only meaningful current rules/families and retained coverage
// decisions; they are not an N x N matrix.
inline constexpr std::string_view kInteractionSchemaId = "cybersand.interactions";
inline constexpr std::uint32_t kInteractionSchemaVersion = 1U;
inline constexpr std::string_view kInteractionProfileId = "int.current-behaviour";
inline constexpr std::uint32_t kInteractionProfileVersion = 1U;

enum class InteractionChannel : std::uint8_t {
    ThermalPhase,
    DissolutionCorrosion,
    ChemicalConversionProducts,
    Combustion,
    Electrical,
    CuringGrowthSpecialState,
    AuthoritativeEmissionsByproducts,
};

struct InteractionChannelDefinition {
    InteractionChannel channel;
    std::string_view id;
};

inline constexpr std::array<InteractionChannelDefinition, 7> kInteractionChannels{{
    {InteractionChannel::ThermalPhase, "thermal_phase"},
    {InteractionChannel::DissolutionCorrosion, "dissolution_corrosion"},
    {InteractionChannel::ChemicalConversionProducts, "chemical_conversion_products"},
    {InteractionChannel::Combustion, "combustion"},
    {InteractionChannel::Electrical, "electrical"},
    {InteractionChannel::CuringGrowthSpecialState, "curing_growth_special_state"},
    {InteractionChannel::AuthoritativeEmissionsByproducts, "authoritative_emissions_byproducts"},
}};

[[nodiscard]] constexpr std::uint32_t interaction_channel_bit(
    InteractionChannel channel) noexcept {
    return std::uint32_t{1} << static_cast<std::uint8_t>(channel);
}

enum class InteractionTriggerKind : std::uint8_t {
    PairContact,
    NeighbourhoodContext,
    IntrinsicState,
};

enum class InteractionMatchKind : std::uint8_t {
    Ordered,
    UnorderedRolePreserving,
    Symmetric,
};

enum class InteractionAuthority : std::uint8_t {
    NativePairResolver,
    CurrentWorldKernel,
};

enum class InteractionAuthoredStatus : std::uint8_t {
    InheritedDefault,
    ExplicitNonInteracting,
    CharacterizedAccepted,
    AcceptedWithLimitation,
    RejectedCandidate,
    Superseded,
    ExplicitOverride,
    Untested,
};

enum class InteractionEvidenceStatus : std::uint8_t {
    None,
    CurrentRegression,
    GeneratedFixture,
    GeneratedFixtureAndRegression,
    DeferredRevalidation,
};

enum class InteractionRevalidationTag : std::uint8_t {
    WaterContact = 0,
    GranularContact = 1,
    SchedulerContact = 2,
    ThermalCadence = 3,
    BiologicalContact = 4,
    BallisticContact = 5,
};

[[nodiscard]] constexpr std::uint32_t interaction_revalidation_bit(
    InteractionRevalidationTag tag) noexcept {
    return std::uint32_t{1} << static_cast<std::uint8_t>(tag);
}

struct PairInteractionRule {
    std::string_view id;
    std::uint32_t channels;
    InteractionTriggerKind trigger;
    InteractionMatchKind match;
    Material first;
    Material second;
    Material first_product;
    Material second_product;
    std::uint8_t probability;
    std::string_view accounting;
    std::uint32_t revalidation_tags;
};

inline constexpr std::array<PairInteractionRule, 14> kPairInteractionRules{{
    {"int.pair.lava-water.quench.v1",
     interaction_channel_bit(InteractionChannel::ThermalPhase) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Lava, Material::Water, Material::Stone, Material::Steam, 255,
     "replace both participants; preserve role-specific products",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.pair.fire-water.extinguish.v1",
     interaction_channel_bit(InteractionChannel::ThermalPhase) |
         interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Fire, Material::Water, Material::Smoke, Material::Steam, 255,
     "replace both participants; preserve role-specific products",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.pair.water-salt.dissolve.v1",
     interaction_channel_bit(InteractionChannel::DissolutionCorrosion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Water, Material::Salt, Material::Brine, Material::Brine, 255,
     "replace both participants with brine",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::GranularContact)},
    {"int.pair.water-sodium.react.v1",
     interaction_channel_bit(InteractionChannel::ChemicalConversionProducts) |
         interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Water, Material::Sodium, Material::Steam, Material::Fire, 255,
     "replace both participants; preserve role-specific products",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::GranularContact)},
    {"int.pair.brine-sodium.react.v1",
     interaction_channel_bit(InteractionChannel::ChemicalConversionProducts) |
         interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Brine, Material::Sodium, Material::Steam, Material::Fire, 255,
     "replace both participants; preserve role-specific products",
     interaction_revalidation_bit(InteractionRevalidationTag::GranularContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.pair.water-toxic-sludge.purify.v1",
     interaction_channel_bit(InteractionChannel::DissolutionCorrosion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Water, Material::ToxicSludge, Material::Water, Material::Water, 255,
     "replace both participants with water",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact)},
    {"int.pair.steam-ice.condense.v1",
     interaction_channel_bit(InteractionChannel::ThermalPhase),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Steam, Material::Ice, Material::Water, Material::Ice, 32,
     "convert steam role to water; preserve ice role",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
    {"int.pair.water-molten-glass.quench.v1",
     interaction_channel_bit(InteractionChannel::ThermalPhase) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Water, Material::MoltenGlass, Material::Steam, Material::Glass, 255,
     "replace both participants; preserve role-specific products",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
    {"int.pair.lava-glass.melt.v1",
     interaction_channel_bit(InteractionChannel::ThermalPhase) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Lava, Material::Glass, Material::Lava, Material::MoltenGlass, 255,
     "preserve lava role; convert glass role to molten glass",
     interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
    {"int.pair.acid-metal.corrosion.v1",
     interaction_channel_bit(InteractionChannel::DissolutionCorrosion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Acid, Material::Metal, Material::Smoke, Material::Rust, 96,
     "replace both participants; preserve role-specific products",
     interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.pair.fire-gunpowder.ignite.v1",
     interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Fire, Material::Gunpowder, Material::Fire, Material::Fire, 255,
     "replace both participants with fire",
     interaction_revalidation_bit(InteractionRevalidationTag::GranularContact)},
    {"int.pair.spark-gunpowder.ignite.v1",
     interaction_channel_bit(InteractionChannel::Electrical) |
         interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Spark, Material::Gunpowder, Material::Empty, Material::Fire, 255,
     "consume spark role; convert gunpowder role to fire",
     interaction_revalidation_bit(InteractionRevalidationTag::GranularContact)},
    {"int.pair.spark-oil.ignite.v1",
     interaction_channel_bit(InteractionChannel::Electrical) |
         interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Spark, Material::Oil, Material::Empty, Material::Fire, 255,
     "consume spark role; convert oil role to fire",
     interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.pair.fire-brine.evaporate.v1",
     interaction_channel_bit(InteractionChannel::ThermalPhase) |
         interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::PairContact, InteractionMatchKind::UnorderedRolePreserving,
     Material::Fire, Material::Brine, Material::Steam, Material::Salt, 64,
     "replace both participants; preserve role-specific products",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
}};

struct PairInteractionMatch {
    bool matched = false;
    std::size_t rule_index = 0U;
    bool reversed = false;
};

struct ResolvedPairInteraction {
    bool matched = false;
    bool selected = false;
    std::size_t rule_index = 0U;
    bool reversed = false;
    Material source_product = Material::Empty;
    Material target_product = Material::Empty;
};

struct SemanticFamilyDefinition {
    std::string_view id;
    std::uint32_t version;
    std::string_view purpose;
};

inline constexpr std::array<SemanticFamilyDefinition, 7> kSemanticFamilies{{
    {"int.family.combustible-kernel", 1U, "materials explicitly using the bounded combustible kernel"},
    {"int.family.conductive-base-metal", 1U, "base Metal only; themed metals do not inherit"},
    {"int.family.reactive-base-glass", 1U, "base Glass only; themed glasses do not inherit"},
    {"int.family.hot-source", 1U, "current materials treated as hot by neighbourhood kernels"},
    {"int.family.aqueous-contact", 1U, "Water and Brine contact participants"},
    {"int.family.biological-growth", 1U, "current Plant/Fungus/Seed growth-state participants"},
    {"int.family.special-agent", 1U, "Cloner/Mite/Rocket special-state participants"},
}};

struct SemanticFamilyMembership {
    std::string_view family_id;
    Material material;
};

inline constexpr std::array<SemanticFamilyMembership, 16> kSemanticFamilyMemberships{{
    {"int.family.combustible-kernel", Material::Wood},
    {"int.family.combustible-kernel", Material::OakTimber},
    {"int.family.combustible-kernel", Material::Thatch},
    {"int.family.conductive-base-metal", Material::Metal},
    {"int.family.reactive-base-glass", Material::Glass},
    {"int.family.hot-source", Material::Fire},
    {"int.family.hot-source", Material::Lava},
    {"int.family.hot-source", Material::MoltenGlass},
    {"int.family.aqueous-contact", Material::Water},
    {"int.family.aqueous-contact", Material::Brine},
    {"int.family.biological-growth", Material::Plant},
    {"int.family.biological-growth", Material::Fungus},
    {"int.family.biological-growth", Material::Seed},
    {"int.family.special-agent", Material::Cloner},
    {"int.family.special-agent", Material::Mite},
    {"int.family.special-agent", Material::Rocket},
}};

struct SpecializedInteractionRule {
    std::string_view id;
    std::uint32_t channels;
    InteractionTriggerKind trigger;
    Material material;
    RuleKernel kernel;
    std::string_view authority_path;
    std::string_view represented_semantics;
    std::uint32_t revalidation_tags;
};

inline constexpr std::array<SpecializedInteractionRule, 19> kSpecializedInteractionRules{{
    {"int.kernel.steam.condense.v1", interaction_channel_bit(InteractionChannel::ThermalPhase),
     InteractionTriggerKind::IntrinsicState, Material::Steam, RuleKernel::Steam,
     "native/src/world.cpp::RuleKernel::Steam", "lifetime expiry converts Steam to Water",
     interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
    {"int.kernel.fire.ignite-smoke.v1",
     interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::NeighbourhoodContext, Material::Fire, RuleKernel::Fire,
     "native/src/world.cpp::RuleKernel::Fire", "sampled ignition and Fire lifetime ending as Smoke",
     interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.kernel.combustible.burn.v1",
     interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::NeighbourhoodContext, Material::Wood, RuleKernel::Combustible,
     "native/src/world.cpp::RuleKernel::Combustible",
     "active burn, Water extinguishing, consumption and Fire emission",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact)},
    {"int.kernel.gunpowder.hot-ignite.v1", interaction_channel_bit(InteractionChannel::Combustion),
     InteractionTriggerKind::NeighbourhoodContext, Material::Gunpowder, RuleKernel::Gunpowder,
     "native/src/world.cpp::RuleKernel::Gunpowder", "hot-neighbour ignition",
     interaction_revalidation_bit(InteractionRevalidationTag::GranularContact)},
    {"int.kernel.coal.burn.v1",
     interaction_channel_bit(InteractionChannel::Combustion) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::NeighbourhoodContext, Material::Coal, RuleKernel::Coal,
     "native/src/world.cpp::RuleKernel::Coal",
     "hot ignition, Water/Brine extinguishing, Dust/Fire/Smoke products",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::GranularContact)},
    {"int.kernel.spark.charge-ignite.v1",
     interaction_channel_bit(InteractionChannel::Electrical) |
         interaction_channel_bit(InteractionChannel::Combustion),
     InteractionTriggerKind::NeighbourhoodContext, Material::Spark, RuleKernel::Spark,
     "native/src/world.cpp::RuleKernel::Spark",
     "adjacent base-Metal charging or sampled combustible ignition; Spark locomotion excluded",
     interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.kernel.metal.charge.v1",
     interaction_channel_bit(InteractionChannel::Electrical) |
         interaction_channel_bit(InteractionChannel::ThermalPhase),
     InteractionTriggerKind::NeighbourhoodContext, Material::Metal, RuleKernel::Metal,
     "native/src/world.cpp::RuleKernel::Metal",
     "base-Metal charge propagation and charged-Metal Water-to-Steam consequence",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact)},
    {"int.kernel.cement.cure.v1", interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState),
     InteractionTriggerKind::NeighbourhoodContext, Material::Cement, RuleKernel::Cement,
     "native/src/world.cpp::RuleKernel::Cement",
     "air/Water/Brine/Concrete-context cure ending as Concrete",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact)},
    {"int.kernel.molten-glass.cool.v1", interaction_channel_bit(InteractionChannel::ThermalPhase),
     InteractionTriggerKind::NeighbourhoodContext, Material::MoltenGlass, RuleKernel::MoltenGlass,
     "native/src/world.cpp::RuleKernel::MoltenGlass",
     "hot-neighbour cooling reset and eventual conversion to Glass",
     interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
    {"int.kernel.lava.contact.v1",
     interaction_channel_bit(InteractionChannel::ThermalPhase) |
         interaction_channel_bit(InteractionChannel::Combustion),
     InteractionTriggerKind::NeighbourhoodContext, Material::Lava, RuleKernel::Lava,
     "native/src/world.cpp::RuleKernel::Lava",
     "sampled Ice-to-Water conversion or neighbour ignition; movement excluded",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
    {"int.kernel.ice.phase.v1", interaction_channel_bit(InteractionChannel::ThermalPhase),
     InteractionTriggerKind::NeighbourhoodContext, Material::Ice, RuleKernel::Ice,
     "native/src/world.cpp::RuleKernel::Ice", "hot-neighbour melt and sampled Water freeze",
     interaction_revalidation_bit(InteractionRevalidationTag::WaterContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::ThermalCadence)},
    {"int.kernel.acid.corrosion.v1",
     interaction_channel_bit(InteractionChannel::DissolutionCorrosion) |
         interaction_channel_bit(InteractionChannel::ChemicalConversionProducts),
     InteractionTriggerKind::NeighbourhoodContext, Material::Acid, RuleKernel::Acid,
     "native/src/world.cpp::RuleKernel::Acid",
     "sampled broad corrosion of non-Empty/non-Wall/non-Acid targets; movement excluded",
     interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.kernel.cloner.capture-emit.v1",
     interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState) |
         interaction_channel_bit(InteractionChannel::AuthoritativeEmissionsByproducts),
     InteractionTriggerKind::NeighbourhoodContext, Material::Cloner, RuleKernel::Cloner,
     "native/src/world.cpp::RuleKernel::Cloner", "capture neighbour identity and emit initialized copies",
     interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
    {"int.kernel.plant.growth.v1",
     interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState) |
         interaction_channel_bit(InteractionChannel::Combustion),
     InteractionTriggerKind::NeighbourhoodContext, Material::Plant, RuleKernel::Plant,
     "native/src/world.cpp::RuleKernel::Plant", "growth plus hot-neighbour ignition",
     interaction_revalidation_bit(InteractionRevalidationTag::BiologicalContact)},
    {"int.kernel.fungus.growth.v1",
     interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState) |
         interaction_channel_bit(InteractionChannel::Combustion),
     InteractionTriggerKind::NeighbourhoodContext, Material::Fungus, RuleKernel::Fungus,
     "native/src/world.cpp::RuleKernel::Fungus", "growth plus hot-neighbour ignition",
     interaction_revalidation_bit(InteractionRevalidationTag::BiologicalContact)},
    {"int.kernel.seed.germinate.v1",
     interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState) |
         interaction_channel_bit(InteractionChannel::Combustion),
     InteractionTriggerKind::NeighbourhoodContext, Material::Seed, RuleKernel::Seed,
     "native/src/world.cpp::RuleKernel::Seed", "substrate/context germination plus hot-neighbour ignition",
     interaction_revalidation_bit(InteractionRevalidationTag::BiologicalContact) |
         interaction_revalidation_bit(InteractionRevalidationTag::GranularContact)},
    {"int.kernel.mite.environment.v1", interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState),
     InteractionTriggerKind::NeighbourhoodContext, Material::Mite, RuleKernel::Mite,
     "native/src/world.cpp::RuleKernel::Mite",
     "environmental death/consumption semantics; locomotion excluded",
     interaction_revalidation_bit(InteractionRevalidationTag::BiologicalContact)},
    {"int.kernel.rocket.trigger.v1", interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState),
     InteractionTriggerKind::NeighbourhoodContext, Material::Rocket, RuleKernel::Rocket,
     "native/src/world.cpp::RuleKernel::Rocket",
     "payload validation/capture and hot trigger state; ballistic motion excluded",
     interaction_revalidation_bit(InteractionRevalidationTag::BallisticContact)},
    {"int.kernel.foam.lifecycle.v1", interaction_channel_bit(InteractionChannel::CuringGrowthSpecialState),
     InteractionTriggerKind::IntrinsicState, Material::Foam, RuleKernel::Foam,
     "native/src/world.cpp::RuleKernel::Foam", "bounded intrinsic lifetime/disappearance",
     interaction_revalidation_bit(InteractionRevalidationTag::SchedulerContact)},
}};

struct InteractionCoverageEntry {
    std::string_view subject_id;
    std::string_view channel_id;
    InteractionAuthoredStatus authored_status;
    InteractionEvidenceStatus evidence_status;
    std::string_view effective_rule_id;
    std::string_view limitation;
};

inline constexpr std::array<InteractionCoverageEntry, 7> kInteractionCoverage{{
    {"compact-pair-current", "multiple", InteractionAuthoredStatus::ExplicitOverride,
     InteractionEvidenceStatus::CurrentRegression, "int.pair.*.v1",
     "all 14 compact pair rules are characterized against the frozen Current oracle"},
    {"specialized-current-kernels", "multiple", InteractionAuthoredStatus::AcceptedWithLimitation,
     InteractionEvidenceStatus::CurrentRegression, "int.kernel.*.v1",
     "represented/provenance-visible; authoritative execution remains in world.cpp"},
    {"control.water-sand", "chemical_conversion_products", InteractionAuthoredStatus::ExplicitNonInteracting,
     InteractionEvidenceStatus::GeneratedFixture, "",
     "no INT conversion rule; kinetic Water/Sand transport remains owned elsewhere"},
    {"family.conductive-themed-metals", "electrical", InteractionAuthoredStatus::ExplicitNonInteracting,
     InteractionEvidenceStatus::CurrentRegression, "",
     "themed metals do not inherit base Metal electrical semantics"},
    {"family.corrosive-themed-metals", "dissolution_corrosion", InteractionAuthoredStatus::ExplicitNonInteracting,
     InteractionEvidenceStatus::CurrentRegression, "",
     "themed metal names/appearance do not imply Acid+Metal pair semantics"},
    {"family.reactive-themed-glass", "thermal_phase", InteractionAuthoredStatus::ExplicitNonInteracting,
     InteractionEvidenceStatus::CurrentRegression, "",
     "themed glass names/appearance do not inherit base Glass pair semantics"},
    {"future-mechanism-tuning", "multiple", InteractionAuthoredStatus::Untested,
     InteractionEvidenceStatus::None, "",
     "later bounded versioned passes own new behavior; INT-000 does not fabricate it"},
}};

struct InteractionTuningPassDefinition {
    std::string_view id;
    std::uint32_t version;
    std::string_view parent;
    std::string_view disposition;
    std::string_view changed_rules;
};

inline constexpr std::array<InteractionTuningPassDefinition, 1> kInteractionTuningPasses{{
    {"int.pass.current-oracle", 1U, "", "characterized-baseline", "none"},
}};

class InteractionRules final {
public:
    InteractionRules() = delete;

    [[nodiscard]] static constexpr std::span<const InteractionChannelDefinition> channels() noexcept {
        return kInteractionChannels;
    }

    [[nodiscard]] static constexpr std::span<const PairInteractionRule> pair_rules() noexcept {
        return kPairInteractionRules;
    }

    [[nodiscard]] static constexpr std::span<const SpecializedInteractionRule>
    specialized_rules() noexcept {
        return kSpecializedInteractionRules;
    }

    [[nodiscard]] static constexpr std::span<const SemanticFamilyDefinition>
    semantic_families() noexcept {
        return kSemanticFamilies;
    }

    [[nodiscard]] static constexpr std::span<const SemanticFamilyMembership>
    semantic_family_memberships() noexcept {
        return kSemanticFamilyMemberships;
    }

    [[nodiscard]] static constexpr std::span<const InteractionCoverageEntry> coverage() noexcept {
        return kInteractionCoverage;
    }

    [[nodiscard]] static constexpr std::span<const InteractionTuningPassDefinition>
    tuning_passes() noexcept {
        return kInteractionTuningPasses;
    }

    [[nodiscard]] static constexpr bool in_family(
        std::string_view family_id, Material material) noexcept {
        for (const auto& membership : kSemanticFamilyMemberships) {
            if (membership.family_id == family_id && membership.material == material) return true;
        }
        return false;
    }

    [[nodiscard]] static constexpr PairInteractionMatch match_pair(
        Material source, Material target) noexcept {
        for (std::size_t index = 0; index < kPairInteractionRules.size(); ++index) {
            const auto& rule = kPairInteractionRules[index];
            if (source == rule.first && target == rule.second) {
                return {true, index, false};
            }
            if (rule.match == InteractionMatchKind::UnorderedRolePreserving &&
                source == rule.second && target == rule.first) {
                return {true, index, true};
            }
            if (rule.match == InteractionMatchKind::Symmetric &&
                source == rule.second && target == rule.first) {
                return {true, index, true};
            }
        }
        return {};
    }

    [[nodiscard]] static constexpr ResolvedPairInteraction resolve_pair(
        Material source, Material target, std::uint8_t probability_roll) noexcept {
        const auto match = match_pair(source, target);
        if (!match.matched) return {};
        const auto& rule = kPairInteractionRules[match.rule_index];
        const bool selected = probability_roll <= rule.probability;
        return {
            true,
            selected,
            match.rule_index,
            match.reversed,
            match.reversed ? rule.second_product : rule.first_product,
            match.reversed ? rule.first_product : rule.second_product,
        };
    }

    [[nodiscard]] static constexpr bool has_pair_rule(Material material) noexcept {
        for (const auto& rule : kPairInteractionRules) {
            if (rule.first == material || rule.second == material) return true;
        }
        return false;
    }
};

[[nodiscard]] constexpr std::string_view interaction_channel_id(
    InteractionChannel channel) noexcept {
    for (const auto& definition : kInteractionChannels) {
        if (definition.channel == channel) return definition.id;
    }
    return "unknown";
}

[[nodiscard]] constexpr std::string_view interaction_trigger_id(
    InteractionTriggerKind trigger) noexcept {
    switch (trigger) {
        case InteractionTriggerKind::PairContact: return "pair_contact";
        case InteractionTriggerKind::NeighbourhoodContext: return "neighbourhood_context";
        case InteractionTriggerKind::IntrinsicState: return "intrinsic_state";
    }
    return "unknown";
}

[[nodiscard]] constexpr std::string_view interaction_match_id(
    InteractionMatchKind match) noexcept {
    switch (match) {
        case InteractionMatchKind::Ordered: return "ordered";
        case InteractionMatchKind::UnorderedRolePreserving: return "unordered_role_preserving";
        case InteractionMatchKind::Symmetric: return "symmetric";
    }
    return "unknown";
}

[[nodiscard]] constexpr std::string_view interaction_authored_status_id(
    InteractionAuthoredStatus status) noexcept {
    switch (status) {
        case InteractionAuthoredStatus::InheritedDefault: return "inherited_default";
        case InteractionAuthoredStatus::ExplicitNonInteracting: return "explicitly_non_interacting";
        case InteractionAuthoredStatus::CharacterizedAccepted: return "characterized_accepted";
        case InteractionAuthoredStatus::AcceptedWithLimitation: return "accepted_with_limitation";
        case InteractionAuthoredStatus::RejectedCandidate: return "rejected_candidate";
        case InteractionAuthoredStatus::Superseded: return "superseded";
        case InteractionAuthoredStatus::ExplicitOverride: return "explicit_override";
        case InteractionAuthoredStatus::Untested: return "untested";
    }
    return "unknown";
}

[[nodiscard]] constexpr std::string_view interaction_evidence_status_id(
    InteractionEvidenceStatus status) noexcept {
    switch (status) {
        case InteractionEvidenceStatus::None: return "none";
        case InteractionEvidenceStatus::CurrentRegression: return "current_regression";
        case InteractionEvidenceStatus::GeneratedFixture: return "generated_fixture";
        case InteractionEvidenceStatus::GeneratedFixtureAndRegression:
            return "generated_fixture_and_regression";
        case InteractionEvidenceStatus::DeferredRevalidation: return "deferred_revalidation";
    }
    return "unknown";
}

static_assert(kPairInteractionRules.size() == 14U);
static_assert(InteractionRules::in_family("int.family.conductive-base-metal", Material::Metal));
static_assert(!InteractionRules::in_family("int.family.conductive-base-metal", Material::WroughtIron));
static_assert(!InteractionRules::in_family("int.family.conductive-base-metal", Material::Copper));
static_assert(InteractionRules::in_family("int.family.reactive-base-glass", Material::Glass));
static_assert(!InteractionRules::in_family("int.family.reactive-base-glass", Material::StainedGlass));
static_assert(!InteractionRules::in_family("int.family.reactive-base-glass", Material::ChemicalGlass));

}  // namespace cybersand
