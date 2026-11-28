#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"

#include <array>
#include <cstdint>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <utility>

namespace cybersand {
class PrecisionProbe {
public:
    static void in_tick(World& world, bool value) { world.tick_in_progress_ = value; }
    static void revision(World& world, std::uint64_t value) { world.material_audition_revision_ = value; }
    static bool density(const World& world, Material a, Material b, std::int64_t dy) {
        return world.material_audition_can_density_exchange(a, b, dy);
    }
    static std::optional<PairReactionResult> reaction(
        const World& world, Material a, Material b, std::uint8_t roll) {
        return world.material_audition_pair_reaction(a, b, roll);
    }
};
}

namespace {
using namespace cybersand;
std::uint64_t assertions = 0;

void require(bool value, const char* message) {
    ++assertions;
    if (!value) throw std::runtime_error(message);
}

template<class F> void refuses(F&& operation, const char* message) {
    bool refused = false;
    try { operation(); } catch (const std::exception&) { refused = true; }
    require(refused, message);
}

MaterialAuditionResult apply(World& world, const MaterialAuditionProfile& profile) {
    const auto identity = world.material_audition_world_id();
    const auto tick = world.completed_tick_index();
    const auto result = world.apply_material_audition(identity, world.material_audition_revision(), profile);
    require(result.applied(), result.reason.data());
    require(result.world_id == identity && world.material_audition_world_id() == identity,
        "profile application replaced the World");
    require(world.completed_tick_index() == tick, "profile application advanced or reset simulation time");
    return result;
}

MaterialAuditionProfile density_profile(std::int32_t density) {
    MaterialAuditionProfile profile;
    profile.profile_id = "sand-density";
    profile.density[static_cast<std::size_t>(Material::Sand)] = density;
    return profile;
}

void vertical_bay(World& world, int x = 10, int y = 10) {
    for (int dy = 0; dy < 4; ++dy) for (int dx = 0; dx < 3; ++dx)
        world.set(x + dx, y + dy, Material::Wall);
    world.set(x + 1, y + 1, Material::Sand);
    world.set(x + 1, y + 2, Material::Oil);
}

void profile_identity_validation_and_atomic_refusal() {
    World world;
    vertical_bay(world);
    const auto identity = world.material_audition_world_id();
    const auto before = world.physical_state_hash();
    const auto baseline = world.material_audition_behavior_hash();
    const auto check_refusal = [&](MaterialAuditionProfile profile, MaterialAuditionOutcome expected) {
        const auto result = world.apply_material_audition(identity, 0, profile);
        require(result.outcome == expected && !result.applied(), "wrong profile refusal");
        require(world.material_audition_revision() == 0 && world.physical_state_hash() == before &&
                world.material_audition_behavior_hash() == baseline,
            "refused profile partially changed configuration or World");
    };
    auto profile = density_profile(500);
    profile.viscosity[static_cast<std::size_t>(Material::Oil)] = 32;
    check_refusal(profile, MaterialAuditionOutcome::UnsupportedProperty);
    profile = density_profile(0); check_refusal(profile, MaterialAuditionOutcome::InvalidValue);
    profile = density_profile(65536); check_refusal(profile, MaterialAuditionOutcome::InvalidValue);
    profile = density_profile(-2); check_refusal(profile, MaterialAuditionOutcome::InvalidValue);
    profile = {}; profile.density[10] = 1;
    check_refusal(profile, MaterialAuditionOutcome::UnsupportedProperty);
    profile = {}; profile.density[static_cast<std::size_t>(Material::Wood)] = 800;
    check_refusal(profile, MaterialAuditionOutcome::UnsupportedProperty);
    for (const auto material : {Material::Water, Material::Lava, Material::Acid, Material::Oil}) {
        profile = {}; profile.viscosity[static_cast<std::size_t>(material)] = 128;
        check_refusal(profile, MaterialAuditionOutcome::UnsupportedProperty);
    }
    for (const auto value : {-2, 256, 65536}) {
        profile = {}; profile.viscosity[20] = value;
        check_refusal(profile, MaterialAuditionOutcome::InvalidValue);
        profile = {}; profile.probability_threshold[2] = value;
        check_refusal(profile, MaterialAuditionOutcome::InvalidValue);
    }
    profile = {}; profile.schema_version = 2;
    check_refusal(profile, MaterialAuditionOutcome::InvalidProfile);
    for (const auto& name : {std::string{}, std::string("bad id"), std::string(65, 'a'), std::string("../bad/name")}) {
        profile = {}; profile.profile_id = name;
        check_refusal(profile, MaterialAuditionOutcome::InvalidProfile);
    }
    profile = density_profile(500);
    require(world.apply_material_audition(identity + 1, 0, profile).outcome == MaterialAuditionOutcome::WorldMismatch,
        "wrong World identity admitted");
    require(world.apply_material_audition(identity, 1, profile).outcome == MaterialAuditionOutcome::StaleRevision,
        "future revision admitted");
    PrecisionProbe::in_tick(world, true);
    require(world.apply_material_audition(identity, 0, profile).outcome == MaterialAuditionOutcome::TickInProgress,
        "in-progress tick admitted");
    PrecisionProbe::in_tick(world, false);
    require(world.physical_state_hash() == before, "identity/lifetime refusal changed authority");
    apply(world, profile);
    const auto active = world.physical_state_hash();
    require(world.apply_material_audition(identity, 0, density_profile(2000)).outcome == MaterialAuditionOutcome::StaleRevision,
        "older competing edit overwrote newer intent");
    require(world.physical_state_hash() == active && world.material_audition_effective_density(Material::Sand) == 500,
        "stale transaction was not atomic");
    world.quarantine_external_coupling();
    require(world.apply_material_audition(identity, 1, profile).outcome == MaterialAuditionOutcome::WorldFailed,
        "quarantined World admitted profile");
}

void identity_retirement_move_and_revision_exhaustion() {
    World first;
    World second;
    const auto first_id = first.material_audition_world_id();
    const auto second_id = second.material_audition_world_id();
    require(first_id != 0 && first_id != second_id, "World identities are not distinct");
    apply(first, density_profile(500));
    World moved(std::move(first));
    require(moved.material_audition_world_id() == first_id && first.material_audition_world_id() == 0,
        "move constructor duplicated a live World token");
    require(first.apply_material_audition(first_id, 1, {}).outcome == MaterialAuditionOutcome::WorldMismatch,
        "moved-from World accepted old identity");
    second = std::move(moved);
    require(second.material_audition_world_id() == first_id && moved.material_audition_world_id() == 0,
        "move assignment duplicated a live World token");
    require(second.apply_material_audition(second_id, 0, {}).outcome == MaterialAuditionOutcome::WorldMismatch,
        "replaced destination World retained its token");
    second.clear();
    require(second.material_audition_world_id() != first_id && second.material_audition_revision() == 0 &&
            !second.material_audition_changes_behavior(), "clear did not retire profile and identity");
    require(second.apply_material_audition(first_id, 0, {}).outcome == MaterialAuditionOutcome::WorldMismatch,
        "pre-clear transaction configured cleared scene");
    PrecisionProbe::revision(second, std::numeric_limits<std::uint64_t>::max());
    require(second.apply_material_audition(second.material_audition_world_id(),
                std::numeric_limits<std::uint64_t>::max(), {}).outcome == MaterialAuditionOutcome::RevisionExhausted,
        "revision exhaustion wrapped into a reusable identity");
}

void equivalent_defaults_preserve_exact_world_and_saves() {
    for (const auto workers : {1U, 4U}) {
        WorldConfig config;
        config.worker_threads = workers;
        config.parallel_job_threshold = 1;
        World baseline(config), explicit_defaults(config);
        MaterialAuditionProfile profile;
        profile.profile_id = "explicit-accepted-defaults";
        for (std::size_t id = 0; id < kMaterialDefinitions.size(); ++id) {
            const auto material = static_cast<Material>(id);
            if (material_audition_supports_density(material)) profile.density[id] = kMaterialDefinitions[id].density;
            if (material_audition_supports_viscosity(material)) profile.viscosity[id] = kMaterialDefinitions[id].viscosity_index;
        }
        for (std::size_t slot = 0; slot < kPairInteractionRules.size(); ++slot)
            profile.probability_threshold[slot] = kPairInteractionRules[slot].probability;
        for (auto* world : {&baseline, &explicit_defaults}) {
            for (std::uint16_t id = 1; id < kMaterialDefinitions.size(); ++id) {
                if (!valid_material(id)) continue;
                const auto x = static_cast<int>(id % 16) * 12;
                const auto y = static_cast<int>(id / 16) * 12;
                for (int dx = 0; dx < 5; ++dx) world->set(x + dx, y + 4, Material::Wall);
                world->set(x + 2, y, static_cast<Material>(id));
                world->set(x + 2, y + 2, Material::Oil);
            }
        }
        const auto receipt = apply(explicit_defaults, profile);
        require(receipt.scanned_cells == 0 && receipt.woken_blocks == 0 &&
                !explicit_defaults.material_audition_changes_behavior(), "default equivalent profile woke native state");
        require(explicit_defaults.material_audition_behavior_hash() == baseline.material_audition_behavior_hash(),
            "explicit equivalent defaults changed behavior identity");
        require(explicit_defaults.physical_state_hash() == baseline.physical_state_hash() &&
                explicit_defaults.save_physical_state() == baseline.save_physical_state(),
            "equivalent defaults changed native hash or serialized bytes");
        for (int tick = 0; tick < 32; ++tick) {
            (void)baseline.tick(); (void)explicit_defaults.tick();
            require(explicit_defaults.physical_state_hash() == baseline.physical_state_hash(),
                "explicit default profile changed continuing native behavior");
        }
        require(explicit_defaults.save_physical_state() == baseline.save_physical_state(),
            "equivalent default continuation changed CYPS bytes");
    }
}

void density_actual_consumer_reversion_and_world_isolation() {
    World baseline, trial;
    vertical_bay(baseline); vertical_bay(trial);
    const auto world_id = trial.material_audition_world_id();
    const auto profile = density_profile(500);
    apply(trial, profile);
    const auto repeated_hash = trial.physical_state_hash();
    const auto repeated = apply(trial, profile);
    require(repeated.scanned_cells == 0 && repeated.woken_blocks == 0 && trial.physical_state_hash() == repeated_hash,
        "repeated identical profile perturbed scheduling or physical identity");
    for (int tick = 0; tick < 12; ++tick) { (void)baseline.tick(); (void)trial.tick(); }
    require(baseline.stored_material(11, 12) == Material::Sand && trial.stored_material(11, 11) == Material::Sand,
        "density control did not alter actual directional exchange");
    require(MaterialRules::descriptor(Material::Sand).density == 1600 &&
            baseline.material_audition_effective_density(Material::Sand) == 1600,
        "scene-local density changed a global descriptor or independent World");
    const auto cells_before_revert = trial.content_hash();
    const auto tick_before_revert = trial.completed_tick_index();
    const auto reverted = apply(trial, {});
    require(reverted.scanned_cells > 0 && reverted.woken_blocks > 0,
        "returning density did not wake a sleeping relevant block");
    require(trial.content_hash() == cells_before_revert && trial.completed_tick_index() == tick_before_revert,
        "reverting configuration restored or rewound simulation cells");
    for (int tick = 0; tick < 4; ++tick) (void)trial.tick();
    require(trial.stored_material(11, 12) == Material::Sand && trial.material_audition_world_id() == world_id,
        "same native World did not resume default exchange after revert");
    for (const auto value : {1, 800, 801, 65535}) {
        World world; vertical_bay(world); apply(world, density_profile(value));
        for (int tick = 0; tick < 4; ++tick) (void)world.tick();
        require((world.stored_material(11, 12) == Material::Sand) == (value > 800),
            "density threshold alternatives do not reach the native consumer");
    }
}

std::uint64_t viscosity_moves(std::int32_t viscosity, std::uint32_t workers,
                              Material material = Material::Paste) {
    WorldConfig config; config.worker_threads = workers; config.parallel_job_threshold = 1;
    World world(config);
    for (int bay = 0; bay < 96; ++bay) {
        const int x = (bay % 16) * 6, y = (bay / 16) * 8;
        for (int dx = 0; dx <= 4; ++dx) { world.set(x + dx, y, Material::Wall); world.set(x + dx, y + 2, Material::Wall); }
        world.set(x, y + 1, Material::Wall); world.set(x + 4, y + 1, Material::Wall);
        world.set(x + 2, y + 1, material);
    }
    MaterialAuditionProfile profile; profile.profile_id = "viscosity-trial";
    profile.viscosity[static_cast<std::size_t>(material)] = viscosity;
    apply(world, profile);
    const auto identity = world.material_audition_world_id();
    (void)world.tick();
    std::uint64_t moved = 0;
    for (int bay = 0; bay < 96; ++bay)
        moved += world.stored_material((bay % 16) * 6 + 2, (bay / 16) * 8 + 1) != material;
    require(world.material_audition_world_id() == identity && world.completed_tick_index() == 1,
        "viscosity trial replaced/reset native World");
    return moved;
}

void viscosity_actual_consumer_and_diagnostic_ownership() {
    for (const auto material : {Material::Paste, Material::Slush, Material::Brine, Material::Cement,
                               Material::ToxicSludge, Material::Mercury, Material::MoltenGlass}) {
        const auto fast = viscosity_moves(0, 1, material);
        const auto medium = viscosity_moves(128, 1, material);
        const auto slow = viscosity_moves(255, 1, material);
        require(fast > medium && medium > slow, "three viscosities did not alter an admitted family's native lateral motion");
        require(viscosity_moves(0, 4, material) == fast && viscosity_moves(128, 4, material) == medium &&
                viscosity_moves(255, 4, material) == slow, "viscosity outcomes changed with worker configuration");
        std::cout << "{\"experiment\":\"viscosity\",\"material_id\":" << static_cast<unsigned>(material)
                  << ",\"bays\":96,\"ticks\":1,\"moves_nu0\":" << fast
                  << ",\"moves_nu128\":" << medium << ",\"moves_nu255\":" << slow << "}\n";
    }
    WorldConfig config; config.physics_diagnostics.mercury_viscosity = 224;
    World diagnostic(config);
    require(!diagnostic.material_audition_viscosity_available(Material::Mercury) &&
            diagnostic.material_audition_effective_viscosity(Material::Mercury) == 224,
        "readback hid the existing Mercury diagnostic consumer");
    MaterialAuditionProfile profile; profile.viscosity[33] = 224;
    require(diagnostic.apply_material_audition(diagnostic.material_audition_world_id(), 0, profile).outcome ==
                MaterialAuditionOutcome::UnsupportedProperty, "profile bypassed diagnostic ownership");
}

void solver_specific_consumer_admission() {
    auto words = LiquidSolverPolicy::default_request();
    words[20U + 6U * 3U + 1U] = 4; // Authenticated default row6 is Brine; IN family.
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "Brine IN fixture policy refused");
    WorldConfig config;
    config.liquid_solver_policy = *decoded.policy;
    config.maximum_rule_radius = InertialParameters::kExecutionRadius;
    World inertial(config);
    require(inertial.inertial_family(Material::Brine) && !inertial.material_audition_viscosity_available(Material::Brine),
        "IN descriptor viscosity incorrectly advertised effective");
    MaterialAuditionProfile profile;
    profile.viscosity[24] = 0;
    require(inertial.apply_material_audition(inertial.material_audition_world_id(), 0, profile).outcome ==
                MaterialAuditionOutcome::UnsupportedProperty, "IN viscosity bypass admitted");

    WorldConfig wave_config; wave_config.wave_flow.enabled = true;
    World wave(wave_config);
    std::size_t clay_slot = 0;
    for (; clay_slot < kPairInteractionRules.size(); ++clay_slot)
        if (kPairInteractionRules[clay_slot].id == "int.pair.water-raw-clay.slake.v1") break;
    require(clay_slot < kPairInteractionRules.size(), "native clay pair not found");
    require(!wave.material_audition_probability_available(clay_slot),
        "Wave Water plus inert RawClay advertised a nonexistent initiator");
    profile = {}; profile.probability_threshold[clay_slot] = 255;
    require(wave.apply_material_audition(wave.material_audition_world_id(), 0, profile).outcome ==
                MaterialAuditionOutcome::UnsupportedProperty, "ineffective Wave pair profile admitted");
    require(wave.material_audition_probability_available(2), "active Salt may initiate against Wave Water");
    profile = {}; profile.probability_threshold[2] = 0;
    apply(wave, profile);
}

std::uint64_t reaction_events(std::int32_t threshold, std::uint32_t workers) {
    WorldConfig config; config.worker_threads = workers; config.parallel_job_threshold = 1;
    World world(config);
    for (int bay = 0; bay < 96; ++bay) {
        const int x = (bay % 16) * 6, y = (bay / 16) * 8;
        for (int dx = 0; dx < 4; ++dx) for (int dy = 0; dy < 3; ++dy)
            world.set(x + dx, y + dy, Material::Wall);
        world.set(x + 1, y + 1, Material::Water); world.set(x + 2, y + 1, Material::Salt);
    }
    MaterialAuditionProfile profile; profile.profile_id = "salt-reaction"; profile.probability_threshold[2] = threshold;
    apply(world, profile);
    const auto identity = world.material_audition_world_id();
    for (int tick = 0; tick < 4; ++tick) (void)world.tick();
    const auto ledger = world.quantity_ledger();
    require(world.material_audition_world_id() == identity && world.completed_tick_index() == 4,
        "reaction trial replaced/reset native World");
    std::uint64_t completed_pairs = 0;
    for (int bay = 0; bay < 96; ++bay) {
        const int x = (bay % 16) * 6, y = (bay / 16) * 8;
        completed_pairs += world.stored_material(x + 1, y + 1) == Material::Brine &&
                           world.stored_material(x + 2, y + 1) == Material::Brine;
    }
    require(ledger.pair_events[2] == completed_pairs, "reaction witness is not corroborated by actual stored products");
    const auto cells = world.content_hash();
    apply(world, {});
    require(world.content_hash() == cells && world.quantity_ledger().pair_events[2] == completed_pairs,
        "configuration revert falsely undid reacted cells or event history");
    return completed_pairs;
}

void reaction_actual_execution_thresholds_and_worker_parity() {
    const auto low = reaction_events(0, 1), medium = reaction_events(63, 1), high = reaction_events(255, 1);
    require(low < medium && medium < high && high == 96,
        "reaction thresholds did not change actual native execution");
    require(reaction_events(0, 4) == low && reaction_events(63, 4) == medium && reaction_events(255, 4) == high,
        "reaction execution changed with worker configuration");
    std::cout << "{\"experiment\":\"water-salt\",\"bays\":96,\"ticks\":4,\"events_t0\":" << low
              << ",\"events_t63\":" << medium << ",\"events_t255\":" << high << "}\n";
}

std::uint64_t authored_pair_events(std::size_t slot, std::int32_t threshold, bool reversed) {
    World world;
    const auto& rule = kPairInteractionRules[slot];
    for (int bay = 0; bay < 32; ++bay) {
        const int x = (bay % 8) * 6, y = (bay / 8) * 8;
        for (int dx = 0; dx < 4; ++dx) for (int dy = 0; dy < 3; ++dy)
            world.set(x + dx, y + dy, Material::Wall);
        world.set(x + 1, y + 1, reversed ? rule.second : rule.first);
        world.set(x + 2, y + 1, reversed ? rule.first : rule.second);
    }
    MaterialAuditionProfile profile;
    profile.profile_id = "authored-pair-contact";
    profile.probability_threshold[slot] = threshold;
    apply(world, profile);
    for (int tick = 0; tick < 4; ++tick) (void)world.tick();
    // Products may already execute a later lifecycle kernel. The ledger is an
    // actual compact-pair execution witness; the role resolver is checked below.
    return world.quantity_ledger().pair_events[slot];
}

void every_authored_reaction_threshold_role_and_execution() {
    World queries;
    for (std::size_t slot = 0; slot < kPairInteractionRules.size(); ++slot) {
        const auto& rule = kPairInteractionRules[slot];
        require(queries.material_audition_probability_available(slot), "default World lost an authored pair consumer");
        for (const auto threshold : {0, 31, 255}) {
            MaterialAuditionProfile profile;
            profile.profile_id = "authored-role-query";
            profile.probability_threshold[slot] = threshold;
            apply(queries, profile);
            for (const auto reversed : {false, true}) {
                const auto source = reversed ? rule.second : rule.first;
                const auto target = reversed ? rule.first : rule.second;
                const auto authored = MaterialRules::pair_reaction(source, target, 0);
                require(authored && authored->rule_index == slot, "fixture does not select the expected authored pair");
                require(authored->source_product == (reversed ? rule.second_product : rule.first_product) &&
                        authored->target_product == (reversed ? rule.first_product : rule.second_product),
                    "authored resolver lost endpoint product roles");
                for (unsigned roll = 0; roll < 256; ++roll) {
                    const auto observed = PrecisionProbe::reaction(queries, source, target, static_cast<std::uint8_t>(roll));
                    require(observed.has_value() == (roll <= static_cast<unsigned>(threshold)),
                        "profile threshold failed the inclusive native probability contract");
                    if (observed)
                        require(observed->rule_index == slot && observed->source_product == authored->source_product &&
                                observed->target_product == authored->target_product,
                            "profile changed a reaction identity or endpoint product role");
                }
            }
        }
        std::array<std::uint64_t, 2> low{}, high{};
        for (std::size_t orientation = 0; orientation < 2; ++orientation) {
            low[orientation] = authored_pair_events(slot, 0, orientation != 0);
            high[orientation] = authored_pair_events(slot, 255, orientation != 0);
            require(high[orientation] > low[orientation] && high[orientation] <= 32,
                "authored threshold did not reach an actual native contact consumer");
        }
        std::cout << "{\"experiment\":\"authored-pair-contact\",\"slot\":" << slot
                  << ",\"bays\":32,\"ticks\":4,\"events_t0\":[" << low[0] << ',' << low[1]
                  << "],\"events_t255\":[" << high[0] << ',' << high[1] << "]}\n";
    }
}

void exhaustive_default_and_unrelated_consumer_parity() {
    World defaults, trial;
    MaterialAuditionProfile profile = density_profile(500);
    profile.probability_threshold[2] = 0;
    apply(trial, profile);
    for (unsigned a = 0; a < 256; ++a) for (unsigned b = 0; b < 256; ++b) {
        const auto source = static_cast<Material>(a), target = static_cast<Material>(b);
        for (const auto dy : {-1, 0, 1}) {
            const auto original = MaterialRules::can_density_exchange(source, target, dy);
            require(PrecisionProbe::density(defaults, source, target, dy) == original, "default density query parity");
            if (source != Material::Sand && target != Material::Sand)
                require(PrecisionProbe::density(trial, source, target, dy) == original, "unrelated density changed");
        }
        for (unsigned roll = 0; roll < 256; ++roll) {
            const auto byte = static_cast<std::uint8_t>(roll);
            const auto original = MaterialRules::pair_reaction(source, target, byte);
            const auto plain = PrecisionProbe::reaction(defaults, source, target, byte);
            const auto changed = PrecisionProbe::reaction(trial, source, target, byte);
            require(plain.has_value() == original.has_value(), "default reaction query parity");
            const auto authored = MaterialRules::pair_reaction(source, target, 0);
            if (authored && authored->rule_index == 2) {
                require(changed.has_value() == (roll == 0), "threshold0 did not preserve exactly1/256");
            } else require(changed.has_value() == original.has_value(), "unrelated reaction changed");
            if (changed && authored)
                require(changed->source_product == authored->source_product && changed->target_product == authored->target_product &&
                        changed->rule_index == authored->rule_index, "profile changed role-preserving products or rule identity");
        }
    }
    require(!PrecisionProbe::density(trial, Material::Sand, Material::Dust, 1),
        "density overlay enabled forbidden powder-powder swaps");
    require(!PrecisionProbe::density(trial, Material::Oil, Material::Sand, 1),
        "density overlay removed Oil's no-powder-penetration policy");
}

void physical_hash_and_persistence_scope() {
    World world;
    const auto base_hash = world.physical_state_hash();
    const auto bytes = world.save_physical_state();
    auto profile = density_profile(500);
    apply(world, profile);
    require(world.physical_state_hash_version() == 7 && world.physical_state_format_version() == 0 &&
            world.physical_state_hash() != base_hash, "nondefault profile missing from physical identity");
    refuses([&]{ (void)world.save_physical_state(); }, "CYPS silently discarded profile authority");
    const auto configured_hash = world.physical_state_hash();
    profile.profile_id = "same-values-different-name";
    apply(world, profile);
    require(world.physical_state_hash() == configured_hash, "profile name or revision entered physical hash");
    auto detached = world.material_audition_profile();
    detached.density[2] = 9999;
    require(world.material_audition_effective_density(Material::Sand) == 500, "profile readback aliases World authority");
    apply(world, {});
    require(world.physical_state_hash_version() == 2 && world.physical_state_hash() == base_hash &&
            world.save_physical_state() == bytes, "empty-World revert did not restore exact default identity and save");
}

void bounded_transition_refuses_before_publication() {
    WorldConfig config; config.chunk_size = 1024;
    World world(config);
    for (int chunk = 0; chunk < 17; ++chunk) world.set(chunk * 1024 + 8, 8, Material::Sand);
    const auto revision = world.material_audition_revision();
    const auto profile_hash = world.material_audition_behavior_hash();
    const auto result = world.apply_material_audition(world.material_audition_world_id(), revision, density_profile(500));
    require(result.outcome == MaterialAuditionOutcome::CapacityExceeded &&
            world.material_audition_revision() == revision && world.material_audition_behavior_hash() == profile_hash,
        "oversized scan partially activated material configuration");
    require(apply(world, {}).scanned_cells == 0, "equivalent defaults unnecessarily scanned an oversized scene");
}

}  // namespace

int main() {
    try {
        profile_identity_validation_and_atomic_refusal();
        identity_retirement_move_and_revision_exhaustion();
        equivalent_defaults_preserve_exact_world_and_saves();
        density_actual_consumer_reversion_and_world_isolation();
        viscosity_actual_consumer_and_diagnostic_ownership();
        solver_specific_consumer_admission();
        reaction_actual_execution_thresholds_and_worker_parity();
        every_authored_reaction_threshold_role_and_execution();
        exhaustive_default_and_unrelated_consumer_parity();
        physical_hash_and_persistence_scope();
        bounded_transition_refuses_before_publication();
        std::cout << "{\"status\":\"PASS\",\"suite\":\"material-audition-native\",\"assertions\":" << assertions << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "material audition FAIL: " << error.what() << "\n";
        return 1;
    }
}
