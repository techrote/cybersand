#include "cybersand/default_demo_recipe.hpp"
#include "cybersand/prepared_world.hpp"

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
} // namespace

void test_pressure_setup_capacity() {
    exact_capacity(); atmospheric_rules(); actual_masks(); default_recipe_and_nonpressure();
    std::cout << "PRESSURE_SETUP_CAPACITY: " << assertions << " assertions; 0 failures\n";
}

#ifdef CYBERSAND_PRESSURE_SETUP_CAPACITY_STANDALONE
int main() {
    try { test_pressure_setup_capacity(); return 0; }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
#endif
