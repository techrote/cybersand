// #353-A read-only native metadata oracle and independent shadow interpreter.
// Link only material_rules.cpp. No World, engine tick, Godot, or third party build.
#include "cybersand/interaction_rules.hpp"
#include "cybersand/material_appearance.hpp"
#include "cybersand/material_rules.hpp"

#ifdef CYBERSAND_MATERIAL_CANDIDATE_HEADER
#include CYBERSAND_MATERIAL_CANDIDATE_HEADER
#endif

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>

namespace {
namespace n = cybersand;

void value(std::ostream& out, std::string_view text) {
    out << '"';
    constexpr char hex[] = "0123456789abcdef";
    for (unsigned char c : text) {
        switch (c) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default:
                if (c < 32U) out << "\\u00" << hex[c >> 4U] << hex[c & 15U];
                else out << static_cast<char>(c);
        }
    }
    out << '"';
}
void value(std::ostream& out, bool x) { out << (x ? "true" : "false"); }
template <typename T> requires (std::is_integral_v<T> && !std::is_same_v<T, bool>)
void value(std::ostream& out, T x) { out << +x; }
template <typename T> requires std::is_enum_v<T>
void value(std::ostream& out, T x) { value(out, static_cast<std::underlying_type_t<T>>(x)); }
template <typename T, std::size_t N>
void value(std::ostream& out, const std::array<T, N>& xs) {
    out << '[';
    for (std::size_t i = 0; i < N; ++i) { if (i) out << ','; value(out, xs[i]); }
    out << ']';
}
struct Object {
    std::ostream& out;
    bool first = true;
    explicit Object(std::ostream& stream) : out(stream) { out << '{'; }
    ~Object() { out << '}'; }
    void key(std::string_view name) { if (!first) out << ','; first = false; value(out, name); out << ':'; }
    template <typename T> void field(std::string_view name, const T& x) { key(name); value(out, x); }
    template <typename Rows, typename Write>
    void table(std::string_view name, const Rows& rows, Write write) {
        key(name); out << '[';
        std::size_t index = 0;
        for (const auto& row : rows) { if (index) out << ','; write(row, index++); }
        out << ']';
    }
};
#define FIELD(name) obj.field(#name, row.name)

template <bool Candidate, typename Row>
void material(std::ostream& out, const Row& row, std::size_t index) {
    Object obj(out);
    if constexpr (Candidate) obj.field("id", row.id); else obj.field("id", index);
    FIELD(name); FIELD(state); FIELD(density); FIELD(rgba); FIELD(movable);
    FIELD(valid); FIELD(current_rule_available); FIELD(kernel);
    FIELD(initial_state_a); FIELD(initial_state_b); FIELD(maximum_write_radius);
    FIELD(density_motion); FIELD(accepts_density_exchange); FIELD(lateral_flow); FIELD(viscosity_index);
}
template <bool Candidate, typename Row>
void pair(std::ostream& out, const Row& row, std::size_t index) {
    Object obj(out);
    if constexpr (Candidate) obj.field("legacy_slot", row.legacy_slot); else obj.field("legacy_slot", index);
    FIELD(id); FIELD(channels); FIELD(trigger); FIELD(match); FIELD(first); FIELD(second);
    FIELD(first_product); FIELD(second_product); FIELD(probability); FIELD(accounting);
    FIELD(revalidation_tags); FIELD(version); FIELD(supersedes); FIELD(tuning_pass_id);
}
template <bool Candidate, typename Row>
void specialized(std::ostream& out, const Row& row, std::size_t index) {
    Object obj(out);
    if constexpr (Candidate) obj.field("legacy_slot", row.legacy_slot); else obj.field("legacy_slot", index);
    FIELD(id); FIELD(channels); FIELD(trigger); FIELD(material); FIELD(kernel);
    FIELD(authority_path); FIELD(represented_semantics); FIELD(revalidation_tags);
    FIELD(version); FIELD(supersedes); FIELD(tuning_pass_id);
}
template <typename Row> void channel(std::ostream& out, const Row& row, std::size_t) {
    Object obj(out); FIELD(channel); FIELD(id);
}
template <typename Row> void layer_kind(std::ostream& out, const Row& row, std::size_t) {
    Object obj(out); FIELD(kind); FIELD(id); FIELD(precedence);
}
template <typename Row> void family(std::ostream& out, const Row& row, std::size_t) {
    Object obj(out); FIELD(id); FIELD(version); FIELD(purpose);
}
template <typename Row> void membership(std::ostream& out, const Row& row, std::size_t) {
    Object obj(out); FIELD(family_id); FIELD(material);
}
template <typename Row> void coverage(std::ostream& out, const Row& row, std::size_t) {
    Object obj(out); FIELD(subject_id); FIELD(channel_id); FIELD(authored_status);
    FIELD(evidence_status); FIELD(effective_rule_id); FIELD(limitation);
}
template <typename Row> void tuning_pass(std::ostream& out, const Row& row, std::size_t) {
    Object obj(out); FIELD(id); FIELD(version); FIELD(parent); FIELD(disposition); FIELD(changed_rules);
}
#undef FIELD

void native_snapshot(std::ostream& out) {
    Object obj(out);
    obj.key("identity");
    {
        Object identity(out);
        identity.field("allocated_slots", n::MaterialRules::descriptors().size());
        identity.field("reserved_ids", std::array<unsigned, 1>{10U});
        identity.key("aliases"); out << '[';
        { Object alias(out); alias.field("namespace", std::string_view("native_enum"));
          alias.field("name", std::string_view("Gas")); alias.field("target", n::Material::Gas); }
        out << ']';
    }
    obj.table("materials", n::MaterialRules::descriptors(), [&](const auto& r, auto i) { material<false>(out, r, i); });
    obj.key("capabilities"); out << '[';
    for (unsigned id = 0; id < 256; ++id) {
        if (id) out << ',';
        const auto mat = static_cast<n::Material>(id);
        Object cap(out); cap.field("id", id);
        cap.field("valid", n::MaterialRules::is_valid(id));
        cap.field("current_rule", n::MaterialRules::has_current_rule(mat));
        cap.field("hard_surface", n::MaterialRules::is_hard_surface(mat));
        cap.field("granular_support", n::MaterialRules::supports_granular_load(mat));
        cap.field("free_leveling_liquid", n::MaterialRules::is_free_leveling_liquid(mat));
        cap.field("pair_participant", n::MaterialRules::has_pair_reactions(mat));
    }
    out << ']';
    obj.key("appearance"); out << '[';
    for (unsigned id = 0; id < 256; ++id) {
        if (id) out << ',';
        Object appearance(out); appearance.field("id", id);
        appearance.field("visual_state_source", id < n::kVisualStateSources.size()
            ? static_cast<unsigned>(n::kVisualStateSources[id]) : 0U);
    }
    out << ']';
    obj.key("interactions");
    {
        Object interaction(out);
        interaction.field("schema_id", n::kInteractionSchemaId);
        interaction.field("schema_version", n::kInteractionSchemaVersion);
        interaction.field("profile_id", n::kInteractionProfileId);
        interaction.field("profile_version", n::kInteractionProfileVersion);
        interaction.field("current_oracle_pair_rule_count", n::kCurrentOraclePairRuleCount);
        interaction.field("building_material_pass_id", n::kBuildingMaterialPassId);
#define TABLE(key, source, writer) interaction.table(key, source, [&](const auto& r, auto i) { writer(out, r, i); })
        TABLE("channels", n::InteractionRules::channels(), channel);
        TABLE("layer_kinds", n::InteractionRules::layer_kinds(), layer_kind);
        TABLE("pairs", n::InteractionRules::pair_rules(), pair<false>);
        TABLE("specialized", n::InteractionRules::specialized_rules(), specialized<false>);
        TABLE("families", n::InteractionRules::semantic_families(), family);
        TABLE("memberships", n::InteractionRules::semantic_family_memberships(), membership);
        TABLE("coverage", n::InteractionRules::coverage(), coverage);
        TABLE("tuning_passes", n::InteractionRules::tuning_passes(), tuning_pass);
#undef TABLE
        if (!n::InteractionRules::authored_layers().empty()) throw std::runtime_error("oracle: retained layers must be empty");
        interaction.key("layers"); out << "[]";
    }
}

#ifdef CYBERSAND_MATERIAL_CANDIDATE_HEADER
namespace c = cybersand::material_catalogue_shadow;

void candidate_snapshot(std::ostream& out) {
    Object obj(out);
    obj.key("identity");
    {
        Object identity(out);
        identity.field("allocated_slots", c::kMaterialDefinitions.size());
        identity.field("reserved_ids", c::kReservedIds);
        identity.table("aliases", c::kAliases, [&](const auto& row, auto) {
            Object alias(out); alias.field("namespace", row.namespace_id);
            alias.field("name", row.name); alias.field("target", row.target);
        });
    }
    obj.table("materials", c::kMaterialDefinitions, [&](const auto& r, auto i) { material<true>(out, r, i); });
    obj.table("capabilities", c::kCapabilities, [&](const auto& r, auto) {
        Object cap(out); cap.field("id", r.id); cap.field("valid", r.valid); cap.field("current_rule", r.current_rule);
        cap.field("hard_surface", r.hard_surface); cap.field("granular_support", r.granular_support);
        cap.field("free_leveling_liquid", r.free_leveling_liquid); cap.field("pair_participant", r.pair_participant);
    });
    obj.table("appearance", c::kVisualStateSources, [&](const auto& source, auto i) {
        Object appearance(out); appearance.field("id", i); appearance.field("visual_state_source", source);
    });
    obj.key("interactions");
    {
        Object interaction(out);
        interaction.field("schema_id", c::kInteractionSchemaId);
        interaction.field("schema_version", c::kInteractionSchemaVersion);
        interaction.field("profile_id", c::kInteractionProfileId);
        interaction.field("profile_version", c::kInteractionProfileVersion);
        interaction.field("current_oracle_pair_rule_count", c::kCurrentOraclePairRuleCount);
        interaction.field("building_material_pass_id", c::kBuildingMaterialPassId);
#define TABLE(key, source, writer) interaction.table(key, source, [&](const auto& r, auto i) { writer(out, r, i); })
        TABLE("channels", c::kInteractionChannels, channel);
        TABLE("layer_kinds", c::kInteractionLayerKinds, layer_kind);
        TABLE("pairs", c::kPairInteractionRules, pair<true>);
        TABLE("specialized", c::kSpecializedInteractionRules, specialized<true>);
        TABLE("families", c::kSemanticFamilies, family);
        TABLE("memberships", c::kSemanticFamilyMemberships, membership);
        TABLE("coverage", c::kInteractionCoverage, coverage);
        TABLE("tuning_passes", c::kInteractionTuningPasses, tuning_pass);
#undef TABLE
        if (!c::kInteractionLayerDefinitions.empty()) throw std::runtime_error("candidate: retained layers must be empty");
        interaction.key("layers"); out << "[]";
    }
}

// The following small interpreter is deliberately independent of both the
// Python compiler and native query implementations. It reads generated facts
// only. It is a tooling consumer, never a production material dispatcher.
const auto& descriptor(unsigned id) {
    return c::kMaterialDefinitions[id < c::kMaterialDefinitions.size() ? id : 10U];
}
struct Match { bool matched = false; std::size_t slot = 0; bool reversed = false; };
struct Resolution {
    bool matched = false, selected = false;
    std::size_t slot = 0;
    bool reversed = false;
    unsigned source_product = 0, target_product = 0;
};
Match match(unsigned source, unsigned target) {
    for (const auto& rule : c::kPairInteractionRules) {
        if (source == rule.first && target == rule.second) return {true, rule.legacy_slot, false};
        if ((rule.match == 1U || rule.match == 2U) && source == rule.second && target == rule.first)
            return {true, rule.legacy_slot, true};
    }
    return {};
}
Resolution resolve(const Match& matched, unsigned roll) {
    if (!matched.matched) return {};
    const auto& row = c::kPairInteractionRules[matched.slot];
    const bool reverse_products = matched.reversed && row.match != 2U;
    return {true, roll <= row.probability, matched.slot, matched.reversed,
            reverse_products ? row.second_product : row.first_product,
            reverse_products ? row.first_product : row.second_product};
}
bool density_exchange(unsigned source, unsigned target, std::int64_t delta) {
    const auto& a = descriptor(source);
    const auto& b = descriptor(target);
    if (delta == 0 || (a.state == 2U && b.state == 2U) || (source == 16U && b.state == 2U)) return false;
    if (!a.valid || !b.valid || !b.current_rule_available || !b.accepts_density_exchange) return false;
    if (delta > 0) return a.density_motion == 1U && a.density > b.density;
    return a.density_motion == 2U && a.density < b.density;
}
unsigned lateral_rate(unsigned id, unsigned maximum) {
    const auto& row = descriptor(id);
    if (!maximum || row.lateral_flow == 0U) return 0;
    return 1U + ((255U - row.viscosity_index) * (maximum - 1U) + 127U) / 255U;
}
unsigned viscosity(unsigned id, unsigned requested) {
    const auto& row = descriptor(id);
    if (!requested || row.lateral_flow == 0U) return 0;
    return std::max(1U, (requested * (256U - row.viscosity_index) + 255U) / 256U);
}
unsigned projection(unsigned id, unsigned state_a, unsigned state_b, unsigned water_bits) {
    const auto source = id < c::kVisualStateSources.size() ? c::kVisualStateSources[id] : 0U;
    if (source == 2U) return state_b;
    if (source == 0U) return 0;
    if (id != 3U) return state_a & 255U;
    const unsigned maximum = (1U << water_bits) - 1U;
    return (std::min(state_a, maximum) * 255U + maximum / 2U) / maximum;
}
[[noreturn]] void mismatch(std::string_view name, unsigned a, unsigned b = 0, unsigned roll = 0) {
    throw std::runtime_error("parity: " + std::string(name) + " mismatch at " +
                             std::to_string(a) + "," + std::to_string(b) + "," + std::to_string(roll));
}
void run_parity(std::ostream& out) {
    if (c::kProductionAuthority || c::kScope != "current-shadow" || c::kSourceSchemaVersion != 1U)
        throw std::runtime_error("parity: candidate must remain schema-1 current-shadow metadata");
    if (c::kMaterialDefinitions.size() != 132U || c::kPairInteractionRules.size() != 56U ||
        c::kCapabilities.size() != 256U || c::kVisualStateSources.size() != 256U)
        throw std::runtime_error("parity: candidate dimensions differ from retained oracle");
    for (std::size_t i = 0; i < c::kPairInteractionRules.size(); ++i)
        if (c::kPairInteractionRules[i].legacy_slot != i) mismatch("legacy ordinal", i);
    std::uint64_t density_checks = 0, pair_checks = 0, family_checks = 0, projection_checks = 0;
    std::uint64_t rate_checks = 0, viscosity_checks = 0;
    for (unsigned id = 0; id <= 65535U; ++id) {
        const bool expected = id < c::kMaterialDefinitions.size() && descriptor(id).valid;
        if (n::MaterialRules::is_valid(id) != expected) mismatch("uint16 validity", id);
    }
    for (unsigned id = 0; id < 256U; ++id) {
        const auto mat = static_cast<n::Material>(id);
        const auto& row = descriptor(id);
        const auto& native_row = n::MaterialRules::descriptor(mat);
        // Covers the out-of-range descriptor fallback, independently of JSON
        // serialization of the allocated 132 rows.
        if (native_row.name != row.name || static_cast<unsigned>(native_row.state) != row.state ||
            native_row.density != row.density || native_row.rgba != row.rgba || native_row.movable != row.movable ||
            native_row.valid != row.valid || native_row.current_rule_available != row.current_rule_available ||
            static_cast<unsigned>(native_row.kernel) != row.kernel || native_row.initial_state_a != row.initial_state_a ||
            native_row.initial_state_b != row.initial_state_b || native_row.maximum_write_radius != row.maximum_write_radius ||
            static_cast<unsigned>(native_row.density_motion) != row.density_motion ||
            native_row.accepts_density_exchange != row.accepts_density_exchange ||
            static_cast<unsigned>(native_row.lateral_flow) != row.lateral_flow || native_row.viscosity_index != row.viscosity_index)
            mismatch("descriptor", id);
        const auto& cap = c::kCapabilities[id];
        if (cap.id != id || cap.valid != n::MaterialRules::is_valid(id) ||
            cap.current_rule != n::MaterialRules::has_current_rule(mat) ||
            cap.hard_surface != n::MaterialRules::is_hard_surface(mat) ||
            cap.granular_support != n::MaterialRules::supports_granular_load(mat) ||
            cap.free_leveling_liquid != n::MaterialRules::is_free_leveling_liquid(mat) ||
            cap.pair_participant != n::MaterialRules::has_pair_reactions(mat)) mismatch("capability", id);
        bool participant = false;
        for (const auto& rule : c::kPairInteractionRules) participant |= id == rule.first || id == rule.second;
        if (participant != cap.pair_participant) mismatch("derived pair participant", id);
        for (const auto& family : c::kSemanticFamilies) {
            bool member = false;
            for (const auto& membership : c::kSemanticFamilyMemberships)
                member |= membership.family_id == family.id && membership.material == id;
            if (n::InteractionRules::in_family(family.id, mat) != member) mismatch("family membership", id);
            ++family_checks;
        }
        if (n::InteractionRules::in_family("mat353.invalid-family", mat)) mismatch("unknown family", id);
        ++family_checks;
        for (unsigned maximum = 0; maximum < 256; ++maximum) {
            if (lateral_rate(id, maximum) != n::MaterialRules::discrete_lateral_flow_rate(mat, maximum)) mismatch("lateral rate", id, maximum);
            ++rate_checks;
        }
        for (unsigned requested = 0; requested <= 65535U; ++requested) {
            if (viscosity(id, requested) != n::MaterialRules::apply_lateral_viscosity(mat, requested)) mismatch("viscosity", id, requested);
            ++viscosity_checks;
        }
        // Full state_a lane, all six legal Water mass precisions for Water,
        // and an independent StateB sweep. Precision affects Water only;
        // state selection is orthogonal, so no redundant A x B product.
        for (unsigned bits = id == 3U ? 3U : 8U; bits <= 8; ++bits) {
            const n::WaterExperimentPolicy policy(static_cast<std::uint8_t>(bits));
            for (unsigned state_a = 0; state_a <= 65535U; ++state_a) {
                constexpr unsigned fixed_state_b = 173U;
                if (projection(id, state_a, fixed_state_b, bits) !=
                    n::project_visual_state(mat, state_a, fixed_state_b, policy)) mismatch("visual projection A", id, state_a, bits);
                ++projection_checks;
            }
        }
        for (unsigned state_b = 0; state_b < 256U; ++state_b) {
            if (projection(id, 65535U, state_b, 8U) != n::project_visual_state(mat, 65535U, state_b)) mismatch("visual projection B", id, state_b);
            ++projection_checks;
        }
        for (unsigned target = 0; target < 256U; ++target) {
            const auto target_mat = static_cast<n::Material>(target);
            for (const auto delta : std::array<std::int64_t, 5>{
                     std::numeric_limits<std::int64_t>::min(), -1, 0, 1, std::numeric_limits<std::int64_t>::max()}) {
                if (density_exchange(id, target, delta) != n::MaterialRules::can_density_exchange(mat, target_mat, delta)) mismatch("density exchange", id, target);
                ++density_checks;
            }
            // Matching is roll-independent. Precompute it once to avoid 16.8m
            // candidate scans while still testing every native roll result.
            const auto candidate_match = match(id, target);
            const auto native_match = n::InteractionRules::match_pair(mat, target_mat);
            if (candidate_match.matched != native_match.matched || candidate_match.slot != native_match.rule_index ||
                candidate_match.reversed != native_match.reversed ||
                candidate_match.matched != n::InteractionRules::may_pair(mat, target_mat)) mismatch("pair match", id, target);
            for (unsigned roll = 0; roll < 256U; ++roll) {
                const auto expected = resolve(candidate_match, roll);
                const auto actual = n::InteractionRules::resolve_pair(mat, target_mat, roll);
                if (actual.matched != expected.matched || actual.selected != expected.selected ||
                    actual.rule_index != expected.slot || actual.reversed != expected.reversed ||
                    static_cast<unsigned>(actual.source_product) != expected.source_product ||
                    static_cast<unsigned>(actual.target_product) != expected.target_product) mismatch("pair resolution", id, target, roll);
                const auto wrapper = n::MaterialRules::pair_reaction(mat, target_mat, roll);
                if (wrapper.has_value() != expected.selected || (wrapper &&
                    (static_cast<unsigned>(wrapper->source_product) != expected.source_product ||
                     static_cast<unsigned>(wrapper->target_product) != expected.target_product || wrapper->rule_index != expected.slot)))
                    mismatch("pair wrapper", id, target, roll);
                ++pair_checks;
            }
        }
    }
    for (unsigned kind = 0; kind < 256U; ++kind) {
        unsigned expected = 0;
        for (const auto& layer : c::kInteractionLayerKinds) if (layer.kind == kind) expected = layer.precedence;
        if (expected != n::InteractionRules::layer_precedence(static_cast<n::InteractionLayerKind>(kind))) mismatch("layer precedence", kind);
    }
    Object result(out);
    result.field("status", std::string_view("PASS")); result.field("descriptor_byte_ids", 256U);
    result.field("validity_uint16_inputs", 65536U); result.field("capability_byte_ids", 256U);
    result.field("pair_roll_cases", pair_checks); result.field("pair_wrapper_cases", pair_checks);
    result.field("density_exchange_cases", density_checks); result.field("family_membership_cases", family_checks);
    result.field("lateral_rate_cases", rate_checks); result.field("viscosity_cases", viscosity_checks);
    result.field("appearance_projection_cases", projection_checks); result.field("layer_kind_byte_ids", 256U);
    result.field("world_executed", false); result.field("physics_qualification", false);
}
#endif
}  // namespace

int main(int argc, char** argv) {
    try {
        const std::string_view mode = argc > 1 ? argv[1] : "--snapshot";
        if (argc > 2) throw std::runtime_error("expected exactly one mode");
        if (mode == "--snapshot") native_snapshot(std::cout);
#ifdef CYBERSAND_MATERIAL_CANDIDATE_HEADER
        else if (mode == "--candidate-snapshot") candidate_snapshot(std::cout);
        else if (mode == "--parity") run_parity(std::cout);
#endif
        else throw std::runtime_error("unsupported oracle mode");
        std::cout << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
