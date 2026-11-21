// GEN-006 #194: native signed-coordinate camera-interest demand/saturation control.
// Experimental harness only: no streaming, eviction, persistence, or host adapter.
#include "cybersand/world.hpp"
#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace {
using cybersand::ChunkCoord;
using cybersand::ChunkInstallOutcome;
using cybersand::Material;
using cybersand::SimulationBackend;
using cybersand::World;
using cybersand::WorldConfig;
using cybersand::generation::Generator;
using cybersand::generation::HardOverride;
using cybersand::generation::Recipe;
using cybersand::generation::ResultState;

constexpr std::int64_t kSide = 128;
constexpr std::size_t kBudget = 3;
// Both sides of the signed origin and beyond the finite 1024-pixel adapter.
// This is a predeclared synthetic interest route, not a Godot camera journey.
constexpr std::array<ChunkCoord, 5> kRoute{{{-9,0}, {-1,0}, {0,0}, {9,0}, {10,0}}};
std::uint64_t assertions = 0;

void check(bool truth, const char* detail) {
    ++assertions;
    if (!truth) throw std::runtime_error(detail);
}
WorldConfig make_config(std::uint32_t workers) {
    WorldConfig c{};
    c.chunk_size = static_cast<std::int32_t>(kSide);
    c.backend = SimulationBackend::PhasedInPlace;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.initial_chunk_reserve = kBudget;
    c.maximum_chunk_count = kBudget;
    c.active_chunk_capacity = 32;
    c.active_core_capacity = 512;
    return c;
}
std::shared_ptr<const Generator> make_generator() {
    Recipe r{};
    r.schema = cybersand::generation::kSchemaVersion;
    r.seed = 194;
    r.revision = 6;
    r.chunk_size = static_cast<std::int32_t>(kSide);
    // Keep native follow-on physics controlled: static Wall across the entire
    // finite route, instead of an accidentally moving default terrain sample.
    HardOverride h{};
    h.id = "interest-budget-static-wall";
    h.bounds = {-1280, 0, 2816, 128};
    h.material = Material::Wall;
    r.overrides.push_back(std::move(h));
    return Generator::compile(std::move(r));
}
void run(std::uint32_t workers) {
    const auto cfg = make_config(workers);
    const auto generator = make_generator();
    World world(cfg);
    std::vector<cybersand::generation::ChunkResult> installed;
    installed.reserve(kBudget);
    std::size_t maximum_live_proposals = 0;
    std::uint64_t charged_operations = 0;

    for (std::size_t index = 0; index < kRoute.size(); ++index) {
        const auto coord = kRoute[index];
        const std::int64_t x = coord.x * kSide;
        // Interest rectangle is a scheduling filter, not a native residency
        // manager; requests are supplied by this external synthetic driver.
        world.set_simulation_region(cybersand::RectI64{x, 0, kSide, kSide});
        auto proposal = generator->generate(coord);
        maximum_live_proposals = std::max(maximum_live_proposals, std::size_t{1});
        charged_operations += proposal.operations;
        check(proposal.state == ResultState::Ready && generator->accepts(proposal),
              "native generator failed the exact original recipe receipt");
        check(proposal.chunk == coord &&
              proposal.cells.size() == static_cast<std::size_t>(kSide * kSide),
              "generated route chunk has invalid coordinates or dimensions");
        check(proposal.cells[64 * static_cast<std::size_t>(kSide)] == Material::Wall,
              "controlled native recipe did not produce a static Wall");

        const auto count_before = world.chunk_count();
        const auto hash_before = world.physical_state_hash();
        const auto outcome = world.install_generated_chunk(coord, proposal.cells);
        if (index < kBudget) {
            check(outcome == ChunkInstallOutcome::Installed,
                  "within-budget admission of a fresh native chunk refused");
            check(world.chunk_count() == index + 1 &&
                  world.stored_material(x, 64) == Material::Wall,
                  "accepted chunk did not become an authoritative native resident");
            installed.push_back(std::move(proposal));
        } else {
            check(outcome == ChunkInstallOutcome::CapacityFull,
                  "over-budget native generation was not explicitly refused");
            check(world.chunk_count() == count_before &&
                  world.physical_state_hash() == hash_before,
                  "capacity refusal mutated native resident physical authority");
            check(world.stored_material(x, 64) == Material::Empty,
                  "capacity-refused chunk was silently populated");
        }
        std::cout << "GEN006_ROUTE_STOP configured_workers=" << workers
                  << " index=" << index << " chunk_x=" << coord.x
                  << " origin_x=" << x
                  << " outcome=" << (index < kBudget ? "Installed" : "CapacityFull")
                  << " residents=" << world.chunk_count()
                  << " budget=" << kBudget << '\n';
    }

    check(world.chunk_count() == kBudget && maximum_live_proposals == 1,
          "residency or synchronous proposal bound exceeded");
    // An old off-camera authoritative mutation must not disappear as the
    // synthetic interest moves through two refused distant destinations.
    world.set(-9 * kSide, 64, Material::Glass);
    check(world.stored_material(-9 * kSide, 64) == Material::Glass,
          "off-camera native mutation was not retained");
    const auto hash_before_reoffer = world.physical_state_hash();
    check(world.install_generated_chunk(kRoute.front(), installed.front().cells) ==
              ChunkInstallOutcome::AlreadyResident,
          "repeat proposal regenerated a resident edited chunk");
    check(world.physical_state_hash() == hash_before_reoffer &&
          world.stored_material(-9 * kSide, 64) == Material::Glass,
          "native resident replacement erased an edit");

    // Independent matched World; it never encounters rejected proposals or
    // the unadmitted fourth/fifth camera position. Refusal must leave valid
    // subsequent simulation indistinguishable at the same owner tick boundary.
    World control(cfg);
    for (std::size_t i = 0; i < kBudget; ++i) {
        check(control.install_generated_chunk(kRoute[i], installed[i].cells) ==
                  ChunkInstallOutcome::Installed,
              "independent reference installation refused");
    }
    control.set(-9 * kSide, 64, Material::Glass);
    // Match requested interest before comparing future-affecting physical state.
    control.set_simulation_region(cybersand::RectI64{10 * kSide, 0, kSide, kSide});
    check(world.physical_state_hash() == control.physical_state_hash() &&
          world.quantity_ledger() == control.quantity_ledger(),
          "capacity refusals changed native physical authority before ticks");

    std::uint32_t observed = 0;
    for (const auto coord : std::array<ChunkCoord, 3>{{{10,0}, {-9,0}, {0,0}}}) {
        const cybersand::RectI64 interest{coord.x * kSide, 0, kSide, kSide};
        world.set_simulation_region(interest);
        control.set_simulation_region(interest);
        const auto a = world.tick();
        const auto b = control.tick();
        observed = std::max(observed, a.worker_threads_observed);
        check(!world.has_failed() && !control.has_failed(),
              "native World quarantined after region transition");
        check(a.tick == b.tick &&
              world.completed_tick_index() == control.completed_tick_index() &&
              world.physical_state_hash() == control.physical_state_hash() &&
              world.quantity_ledger() == control.quantity_ledger(),
              "failed demand changed native fixed-tick continuation");
        check(world.chunk_count() == kBudget &&
              world.stored_material(-9 * kSide, 64) == Material::Glass,
              "camera/interest movement evicted or erased an old edit");
    }

    std::cout << "GEN006_INTEREST_BUDGET configured_workers=" << workers
              << " observed_workers_max=" << observed
              << " demand_stops=5 resident_budget=" << kBudget
              << " admitted=3 capacity_refused=2"
              << " offscreen_edit_retained=1 duplicate_refused=1"
              << " continuation_ticks=3" 
              << " max_inflight_proposals=" << maximum_live_proposals
              << " recipe_operations=" << charged_operations
              << " result=PASS checks_so_far=" << assertions << '\n';
}
} // namespace

int main() {
    try {
        run(1);
        run(4);
        std::cout << "GEN006_INTEREST_BUDGET_PASS checks=" << assertions << '\n';
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_INTEREST_BUDGET_FAIL checks=" << assertions
                  << " detail=" << e.what() << '\n';
        return 1;
    }
}
