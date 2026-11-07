#include "cybersand/default_demo_recipe.hpp"
#include "cybersand/prepared_world.hpp"
#include "cybersand/liquid_run_receipt_native_capture.hpp"

#include <iostream>
#include <memory>
#include <stdexcept>

namespace {
using namespace cybersand;
std::size_t assertions = 0;
void expect(bool ok, const char* detail) {
    ++assertions;
    if (!ok) throw std::runtime_error(detail);
}
std::unique_ptr<WorldConfig> config(int family = 3, int variant = 0, bool gas = true) {
    auto result = std::make_unique<WorldConfig>();
    auto request = LiquidSolverPolicy::default_request();
    request[21] = family; request[22] = variant;
    if (!gas) {
        const auto at = request.size() - 2U;
        request[at] = 1;
        request.insert(request.begin() + static_cast<std::ptrdiff_t>(at) + 1, {3, 1, 2, 0, 32});
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    expect(decoded.accepted(), "capacity test policy prerequisite refused");
    result->liquid_solver_policy = *decoded.policy;
    return result;
}
void fill(World& world, setup::SetupDomain domain, Material material) {
    for (std::uint32_t y = 0; y < domain.height; ++y)
        for (std::uint32_t x = 0; x < domain.width; ++x)
            world.set(domain.x + x, domain.y + y, material);
}
std::unique_ptr<World> holes(std::size_t number, bool seeded, int variant = 0) {
    auto cfg = config(3, variant);
    auto world = std::make_unique<World>(*cfg);
    fill(*world, {0, 0, 98, 134}, Material::Wall);
    for (std::size_t i = 0; i < number; ++i) {
        const auto x = static_cast<std::int64_t>(1U + (i % 32U) * 3U);
        const auto y = static_cast<std::int64_t>(1U + (i / 32U) * 4U);
        world->set(x, y, Material::Empty);
        if (seeded) world->set(x, y + 1, Material::Water);
    }
    return world;
}
void exact_capacity() {
    auto world = holes(1024, true);
    const setup::SetupDomain domain{0, 0, 98, 134};
    const auto before = world->save_physical_state();
    const auto found = initial_pressure_capacity(*world, domain);
    expect(found.applicable && found.compartments == 1024 && !found.exceeds_capacity(),
           "exactly 1024 initial compartments did not fit");
    expect(!PreparedWorldBuilder::validate_initial_pressure_capacity(*world, domain),
           "exact native compartment bound refused");
    expect(world->save_physical_state() == before, "admission mutated actual candidate authority");
    (void)world->tick();
    const auto ledger = world->gas_ledger();
    expect(!world->has_failed() && world->gas_compartments().size() == 1024 &&
           ledger.amount_live + ledger.vented + ledger.collapsed == ledger.created + ledger.absorbed,
           "admitted exact-boundary census disagreed with actual gas operator");
    const auto late = PreparedWorldBuilder::validate_initial_pressure_capacity(*world, domain);
    expect(late && late->policy_refusal()->code == LiquidPolicyRefusalCode::MalformedPolicy,
           "running topology was mislabeled a fresh setup capacity check");

    auto excessive = holes(1025, true);
    expect(!PreparedWorldBuilder::validate_initial_pressure_capacity(*excessive,{0,0,64,64},64),
           "canvas-only pressure census unexpectedly counted exterior pockets");
    const auto boundary=PreparedWorldBuilder::validate_initial_pressure_capacity(*excessive,{0,0,64,64},64,true);
    expect(boundary && boundary->policy_refusal()->code==LiquidPolicyRefusalCode::CapacityRefused,
           "retained pressure halo missed actual 1025th compartment outside canvas");
    const auto untouched = excessive->save_physical_state();
    const auto refused = PreparedWorldBuilder::validate_initial_pressure_capacity(*excessive, domain);
    expect(initial_pressure_capacity(*excessive, domain).compartments == 1025 && refused &&
           refused->outcome_kind() == ConstructionOutcomeKind::PolicyOrSetupRefused &&
           refused->request_scope() == ConstructionRequestScope::NormalizedPolicyEnvelope &&
           refused->policy_refusal()->code == LiquidPolicyRefusalCode::CapacityRefused &&
           refused->policy_refusal()->material == static_cast<std::uint16_t>(Material::Water),
           "1025 actual pockets did not mint a typed Water capacity refusal");
    expect(excessive->save_physical_state() == untouched && !excessive->has_failed(),
           "capacity refusal mutated or quarantined the unexposed candidate");
    bool runtime_refused = false;
    try { (void)excessive->tick(); }
    catch (const std::runtime_error& error) {
        runtime_refused = std::string(error.what()) == "pressure gas compartment capacity exhausted";
    }
    expect(runtime_refused && excessive->has_failed(), "uncensored over-capacity control did not reproduce quarantine");

    auto unrelated = holes(1025, false);
    expect(initial_pressure_capacity(*unrelated, domain).compartments == 0 &&
           !PreparedWorldBuilder::validate_initial_pressure_capacity(*unrelated, domain),
           "unseeded sealed holes caused false admission refusal");
    (void)unrelated->tick();
    expect(unrelated->gas_compartments().empty() && !unrelated->has_failed(),
           "unseeded-hole control disagreed with actual gas discovery");
}
void atmospheric_rules() {
    auto cfg = config();
    const setup::SetupDomain domain{0, 0, 132, 131};
    for (const bool extra : {false, true}) {
        auto world = std::make_unique<World>(*cfg);
        fill(*world, domain, Material::Wall);
        fill(*world, {1, 1, 128, 128}, Material::Empty);
        world->set(1, 129, Material::Water);
        if (extra) world->set(129, 1, Material::Empty);
        const auto found = initial_pressure_capacity(*world, domain);
        expect(found.compartments == (extra ? 0U : 1U), "16384/16385 volume atmosphere boundary changed");
        (void)world->tick();
        const auto gas = world->gas_compartments();
        expect(!world->has_failed() && gas.size() == (extra ? 0U : 1U) &&
               (extra || gas.front().volume == 16384U), "volume census disagreed with native atmosphere rule");
    }
    auto edge = std::make_unique<World>(*cfg);
    fill(*edge, {0, 0, 5, 5}, Material::Wall);
    edge->set(0, 2, Material::Empty); edge->set(1, 2, Material::Empty);
    edge->set(1, 3, Material::Water);
    expect(initial_pressure_capacity(*edge, {0, 0, 5, 5}).compartments == 0,
           "finite-domain edge failed to vent to unbounded Empty exterior");
    (void)edge->tick();
    expect(!edge->has_failed() && edge->gas_compartments().empty(), "edge census disagreed with native exterior discovery");
}
void actual_masks() {
    auto cfg = config();
    auto world = std::make_unique<World>(*cfg);
    const setup::SetupDomain domain{-5, -3, 9, 7};
    fill(*world, domain, Material::Wall);
    world->set(-3, -1, Material::Empty); world->set(-2, -1, Material::Empty);
    world->set(-1, -1, Material::Empty);
    world->set(-3, 0, Material::Water); world->set(-1, 0, Material::Water);
    world->configure_transient_obstacles({domain.x, domain.y, domain.width, domain.height});
    expect(initial_pressure_capacity(*world, domain).compartments == 1, "connected initial void split without a mask");
    expect(world->set_transient_obstacle(-2, -1, 7), "mask fixture connector not installed");
    const auto before = world->save_physical_state();
    expect(initial_pressure_capacity(*world, domain).compartments == 2,
           "actual body mask did not split gas connectivity");
    expect(world->set_transient_obstacle(-3, 0, 7), "mask fixture Water seed not installed");
    expect(initial_pressure_capacity(*world, domain).compartments == 1,
           "masked Water incorrectly seeded its isolated Empty pocket");
    expect(world->save_physical_state() == before && world->transient_obstacle_at(-2, -1) == 7 &&
           world->transient_obstacle_at(-3, 0) == 7, "census changed authority or actual masks");
    (void)world->tick();
    expect(!world->has_failed() && world->gas_compartments().size() == 1,
           "actual masked gas operator disagreed with construction census");
}
void default_recipe_and_nonpressure() {
    const setup::SetupDomain domain{0, 0, demo::kWidth, demo::kHeight};
    auto retained = std::make_unique<World>();
    retained->set(11, 12, Material::Oil);
    const auto old = retained->save_physical_state();
    auto* old_owner = retained.get();
    for (int variant = 0; variant != 3; ++variant) {
        auto cfg = config(3, variant);
        auto candidate = std::make_unique<World>(*cfg);
        demo::visit_default_demo_recipe([&](auto x, auto y, auto material) { candidate->set(x, y, material); });
        candidate->configure_transient_obstacles({0, 0, demo::kWidth, demo::kHeight});
        expect(candidate->set_transient_obstacle(124, 92, 1), "default mask fixture not installed");
        const auto before = candidate->physical_state_hash();
        const auto refused = PreparedWorldBuilder::validate_initial_pressure_capacity(*candidate, domain);
        if (!refused) retained.swap(candidate);
        expect(refused && refused->policy_refusal()->code == LiquidPolicyRefusalCode::CapacityRefused &&
               initial_pressure_capacity(*candidate, domain).compartments == 1025,
               "actual default pressure variant was not refused before owner replacement");
        expect(retained.get() == old_owner && retained->save_physical_state() == old &&
               candidate->physical_state_hash() == before && candidate->transient_obstacle_at(124, 92) == 1,
               "refused default changed retained owner or candidate state/masks");
    }
    for (const int family : {1, 2}) {
        auto cfg = config(family);
        auto world = std::make_unique<World>(*cfg);
        demo::visit_default_demo_recipe([&](auto x, auto y, auto material) { world->set(x, y, material); });
        expect(!initial_pressure_capacity(*world, domain).applicable &&
               !PreparedWorldBuilder::validate_initial_pressure_capacity(*world, domain),
               "FM/CY default construction incorrectly acquired a gas limit");
    }
    auto cfg = config(3, 0, false);
    auto disabled = std::make_unique<World>(*cfg);
    expect(!initial_pressure_capacity(*disabled, domain).applicable &&
           !PreparedWorldBuilder::validate_initial_pressure_capacity(*disabled, domain),
           "explicit gas-disabled policy incorrectly acquired a compartment limit");
}

void c2048_capacity_contract() {
    // No silent opt-in: a high budget is legal only with gas-enabled PF Water.
    {
        auto invalid = std::make_unique<WorldConfig>();
        invalid->pressure_gas_compartment_capacity = 2048;
        bool refused = false;
        try { World candidate(*invalid); } catch (const std::invalid_argument&) { refused = true; }
        expect(refused, "non-pressure World silently admitted C2048");
        auto disabled = config(3, 0, false);
        disabled->pressure_gas_compartment_capacity = 2048;
        refused = false;
        try { World candidate(*disabled); } catch (const std::invalid_argument&) { refused = true; }
        expect(refused, "gas-disabled PF silently admitted C2048");
        auto unsupported = config();
        unsupported->pressure_gas_compartment_capacity = 2049;
        refused = false;
        try { World candidate(*unsupported); } catch (const std::invalid_argument&) { refused = true; }
        expect(refused, "unsupported C2049 profile did not fail closed");
    }
    const auto high_config = []() {
        auto cfg = config();
        cfg->pressure_gas_compartment_capacity = PressureFlowParameters::kAdmittedCompartmentCapacity;
        return cfg;
    };
    const auto wide_holes = [&](std::size_t count, int variant) {
        auto cfg = config(3, variant);
        cfg->pressure_gas_compartment_capacity = 2048;
        auto world = std::make_unique<World>(*cfg);
        constexpr std::size_t columns = 64;
        const std::uint32_t height = static_cast<std::uint32_t>(((count + columns - 1) / columns) * 4 + 4);
        const setup::SetupDomain domain{0, 0, 194, height};
        fill(*world, domain, Material::Wall);
        for (std::size_t i = 0; i < count; ++i) {
            const auto x = static_cast<std::int64_t>(1 + (i % columns) * 3);
            const auto y = static_cast<std::int64_t>(1 + (i / columns) * 4);
            world->set(x, y, Material::Empty);
            world->set(x, y + 1, Material::Water);
        }
        return std::pair<std::unique_ptr<World>, setup::SetupDomain>(std::move(world), domain);
    };
    auto [at_limit, domain] = wide_holes(2048, 0);
    const auto preflight = initial_pressure_capacity(*at_limit, domain);
    expect(preflight.applicable && preflight.capacity == 2048 && preflight.compartments == 2048 &&
           !preflight.exceeds_capacity(), "explicit C2048 exact boundary not admitted");
    expect(!PreparedWorldBuilder::validate_initial_pressure_capacity(*at_limit, domain),
           "C2048 preflight refused its exact capacity");
    (void)at_limit->tick();
    expect(!at_limit->has_failed() && at_limit->gas_compartments().size() == 2048 &&
           at_limit->physical_state_hash_version() == 5 && at_limit->physical_state_format_version() == 5 &&
           at_limit->pressure_flow_parameters().gas_compartment_capacity == 2048,
           "C2048 native tick, applied readback or versioned hash/format incorrect");
    auto cfg = high_config();
    const auto saved = at_limit->save_physical_state();
    auto restored = World::restore_physical_state(*cfg, saved);
    expect(restored->physical_state_hash() == at_limit->physical_state_hash() &&
           restored->save_physical_state() == saved,
           "CYPS5 exact C2048 continuation failed");
    auto ordinary = config();
    bool refused = false;
    try { (void)World::restore_physical_state(*ordinary, saved); }
    catch (const std::invalid_argument& e) {
        refused = std::string(e.what()).find("gas capacity profile mismatch") != std::string::npos;
    }
    expect(refused, "C1024 receiver silently imported C2048 CYPS5");
    World old(*ordinary);
    const auto old_save = old.save_physical_state();
    expect(old.physical_state_format_version() == 2 && old.physical_state_hash_version() == 2,
           "ordinary C1024 physical identity drifted");
    refused = false;
    try { (void)World::restore_physical_state(*cfg, old_save); }
    catch (const std::invalid_argument& e) {
        refused = std::string(e.what()).find("legacy save requires default gas capacity profile") != std::string::npos;
    }
    expect(refused, "C2048 receiver silently reinterpreted historical CYPS2");
    auto [over_limit, excess_domain] = wide_holes(2049, 0);
    const auto expected = initial_pressure_capacity(*over_limit, excess_domain);
    const auto refusal = PreparedWorldBuilder::validate_initial_pressure_capacity(*over_limit, excess_domain);
    expect(expected.compartments == 2049 && expected.exceeds_capacity() && refusal &&
           refusal->policy_refusal()->code == LiquidPolicyRefusalCode::CapacityRefused &&
           refusal->policy_refusal()->detail.find("2048") != std::string::npos,
           "C2048+1 did not produce typed capacity refusal with actual declared limit");
    refused = false;
    try { (void)over_limit->tick(); }
    catch (const std::runtime_error& e) {
        refused = std::string(e.what()) == "pressure gas compartment capacity exhausted";
    }
    expect(refused && over_limit->has_failed() && over_limit->completed_tick_index() == 0,
           "C2048+1 tick did not quarantine at the correct boundary");

    // Native receipt identity is extended *only* for the opt-in capacity.
    setup::SetupDescriptor descriptor;
    descriptor.domain = {0, 0, 8, 8};
    World low_receipt(*ordinary), high_receipt(*cfg);
    const auto before = receipt::capture_native_facts(low_receipt, descriptor);
    const auto after = receipt::capture_native_facts(high_receipt, descriptor);
    receipt::encoding::Writer default_bytes, raised_bytes;
    receipt::detail::native_facts(default_bytes, before);
    receipt::detail::native_facts(raised_bytes, after);
    expect(default_bytes.bytes != raised_bytes.bytes &&
           after.values().physical_hash_version == 5 &&
           before.values().physical_hash_version == 2,
           "explicit C2048 native fact/receipt identity absent");

    // Actual authored demo previously fails for C1024 (retained control above).
    const setup::SetupDomain demo_domain{0, 0, demo::kWidth, demo::kHeight};
    for (int variant = 0; variant < 3; ++variant) {
        auto variant_config = config(3, variant);
        variant_config->pressure_gas_compartment_capacity = 2048;
        World demo_world(*variant_config);
        demo::visit_default_demo_recipe([&](auto x, auto y, auto material) { demo_world.set(x, y, material); });
        demo_world.configure_transient_obstacles({0, 0, demo::kWidth, demo::kHeight});
        expect(demo_world.set_transient_obstacle(124, 92, 1), "default C2048 mask not installed");
        const auto actual = initial_pressure_capacity(demo_world, demo_domain);
        expect(actual.compartments == 1175 && !actual.exceeds_capacity() &&
               !PreparedWorldBuilder::validate_initial_pressure_capacity(demo_world, demo_domain),
               "C2048 default native demo did not admit the complete 1175-compartment census");
        (void)demo_world.tick();
        expect(!demo_world.has_failed(), "C2048 default native demo quarantined on its first tick");
    }
}
} // namespace

void test_pressure_setup_capacity() {
    // The workbench widens only prepared finite extent. The ordinary construction
    // default still refuses >1024, and the compartment ceiling remains independent.
    World large(*config());
    large.set(1740,1620,Material::Water);
    const setup::SetupDomain canvas{0,0,2048,2048};
    expect(PreparedWorldBuilder::validate_initial_pressure_capacity(large,canvas).has_value(),
           "ordinary initial pressure census admitted workbench-only extent");
    expect(!PreparedWorldBuilder::validate_initial_pressure_capacity(large,canvas,2048),
           "2048 workbench census refused a distant vented Water cell");
    expect(PreparedWorldBuilder::validate_initial_pressure_capacity(large,{0,0,2049,2048},2048).has_value(),
           "workbench allowed a census outside its finite limit");

    exact_capacity(); atmospheric_rules(); actual_masks(); default_recipe_and_nonpressure();
    c2048_capacity_contract();
    std::cout << "PRESSURE_SETUP_CAPACITY: " << assertions << " assertions; 0 failures\n";
}

#ifdef CYBERSAND_PRESSURE_SETUP_CAPACITY_STANDALONE
int main() {
    try { test_pressure_setup_capacity(); return 0; }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
#endif
