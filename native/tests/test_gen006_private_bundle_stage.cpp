// GEN-006 #194: native private-stage ALL-OR-NONE bundle discriminator.
// Experimental host-only transaction; not a native chunk restore, live streamer,
// authorized World replacement, durable serializer or production implementation.
#include "cybersand/world.hpp"

#include <algorithm>
#include <cstdint>
#include <functional>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {
using cybersand::ChunkCoord;
using cybersand::ChunkInstallOutcome;
using cybersand::Material;
using cybersand::SimulationBackend;
using cybersand::World;
using cybersand::WorldConfig;

constexpr int kSide = 128;
constexpr ChunkCoord kAnchor{-9, 0};
constexpr ChunkCoord kWest{-1, 0};
constexpr ChunkCoord kEast{0, 0};
std::uint64_t assertions = 0;

void check(bool value, const char* why) {
    ++assertions;
    if (!value) throw std::runtime_error(why);
}
WorldConfig config_for(std::uint32_t workers, std::size_t capacity = 4) {
    WorldConfig c{};
    c.chunk_size = kSide;
    c.backend = SimulationBackend::PhasedInPlace;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.initial_chunk_reserve = capacity;
    c.maximum_chunk_count = capacity;
    c.active_chunk_capacity = 32;
    c.active_core_capacity = 512;
    c.deferred_event_capacity = 32;
    return c;
}
std::vector<Material> span_for(int x) {
    std::vector<Material> cells(static_cast<std::size_t>(kSide) * kSide, Material::Empty);
    cells[static_cast<std::size_t>(64) * kSide + static_cast<std::size_t>(x)] = Material::Wall;
    return cells;
}
struct Owner {
    WorldConfig config;
    std::unique_ptr<World> live;
    std::uint64_t session = 15;
    std::uint64_t recipe = 7;
    std::uint64_t mutation_generation = 3;
    std::uint32_t external_pins = 0;
    bool unsupported_sidecar = false;
};
Owner anchored(WorldConfig config) {
    Owner o{config, std::make_unique<World>(config)};
    check(o.live->install_generated_chunk(kAnchor, span_for(64)) ==
              ChunkInstallOutcome::Installed, "anchor native admission refused");
    check(o.live->chunk_count() == 1, "anchor not resident");
    return o;
}
struct Plan {
    std::uint64_t session;
    std::uint64_t recipe;
    std::uint64_t expected_generation;
    std::vector<Material> west;
    std::vector<Material> east;
};
Plan normal_plan(const Owner& o) {
    return {o.session, o.recipe, o.mutation_generation,
            span_for(kSide - 1), span_for(0)};
}
enum class Decision {
    Published, Stale, Pinned, Unsupported, Resident, Capacity, Invalid, Failed
};
Decision mapped(ChunkInstallOutcome outcome) {
    switch (outcome) {
    case ChunkInstallOutcome::AlreadyResident: return Decision::Resident;
    case ChunkInstallOutcome::CapacityFull: return Decision::Capacity;
    case ChunkInstallOutcome::InvalidPayload: return Decision::Invalid;
    case ChunkInstallOutcome::Installed: return Decision::Published;
    default: return Decision::Failed;
    }
}
bool identity_matches(const Owner& o, const Plan& p) {
    return o.session == p.session && o.recipe == p.recipe &&
           o.mutation_generation == p.expected_generation;
}
// A *test harness* controlled private whole-World clone and pointer publication.
// This is NOT a correct implementation for any World holding unsaved actor masks,
// optional arrival witnesses, external scene objects or unsupported native state.
Decision attempt(Owner& o, const Plan& p, const std::function<void()>& before_publish = {}) {
    if (!identity_matches(o, p)) return Decision::Stale;
    if (o.live->has_failed()) return Decision::Failed;
    if (o.external_pins) return Decision::Pinned;
    if (o.unsupported_sidecar) return Decision::Unsupported;
    auto staged = World::restore_physical_state(o.config, o.live->save_physical_state());
    if (!staged || staged->physical_state_hash() != o.live->physical_state_hash())
        return Decision::Unsupported; // No partial source promotion.
    const auto first = staged->install_generated_chunk(kWest, p.west);
    if (first != ChunkInstallOutcome::Installed) return mapped(first);
    const auto second = staged->install_generated_chunk(kEast, p.east);
    if (second != ChunkInstallOutcome::Installed) return mapped(second);
    if (before_publish) before_publish();
    // In an actual owner, every World, Godot, Rapier, lease and publication
    // lifetime must be fenced at this boundary. Only generation is modeled.
    if (!identity_matches(o, p)) return Decision::Stale;
    if (o.external_pins) return Decision::Pinned;
    if (o.unsupported_sidecar) return Decision::Unsupported;
    o.live.swap(staged);
    ++o.mutation_generation;
    return Decision::Published;
}
void assert_no_bridge(const Owner& o) {
    check(o.live->stored_material(-1, 64) == Material::Empty &&
              o.live->stored_material(0, 64) == Material::Empty,
          "failed transaction exposed partial bridge");
}
void run(std::uint32_t workers) {
    const auto cfg = config_for(workers);

    // Negative control A: resident-Empty east. Entire private clone is thrown
    // away after east refuses; original owner is not partially modified.
    auto resident = anchored(cfg);
    resident.live->reserve_region({0, 0, 1, 1});
    check(resident.live->chunk_count() == 2 &&
              resident.live->stored_material(0, 64) == Material::Empty,
          "resident Empty control missing");
    const auto resident_hash = resident.live->physical_state_hash();
    const auto resident_count = resident.live->chunk_count();
    check(attempt(resident, normal_plan(resident)) == Decision::Resident,
          "resident-Empty second half was not refused");
    check(resident.live->chunk_count() == resident_count &&
              resident.live->physical_state_hash() == resident_hash,
          "resident refusal mutated live source");
    assert_no_bridge(resident);

    // Negative control B: one free chunk, but two halves must commit together.
    auto capacity = anchored(config_for(workers, 2));
    const auto capacity_hash = capacity.live->physical_state_hash();
    check(attempt(capacity, normal_plan(capacity)) == Decision::Capacity,
          "capacity failure not reproduced inside private candidate");
    check(capacity.live->chunk_count() == 1 &&
              capacity.live->physical_state_hash() == capacity_hash,
          "capacity refusal exposed staged west half");
    assert_no_bridge(capacity);

    // Negative control C: malformed later material must not publish earlier half.
    auto malformed = anchored(cfg);
    const auto malformed_hash = malformed.live->physical_state_hash();
    auto bad_plan = normal_plan(malformed);
    bad_plan.east[0] = static_cast<Material>(0xffffU);
    check(attempt(malformed, bad_plan) == Decision::Invalid,
          "malformed later proposal did not refuse");
    check(malformed.live->chunk_count() == 1 &&
              malformed.live->physical_state_hash() == malformed_hash,
          "invalid later proposal committed first half");
    assert_no_bridge(malformed);

    // Negative control D: invalid caller session and cancelled generation.
    auto retired = anchored(cfg);
    auto old = normal_plan(retired);
    ++retired.session;
    check(attempt(retired, old) == Decision::Stale,
          "old session was accepted");
    assert_no_bridge(retired);

    // Negative control E: the live source mutates between preparation and
    // publication. This hook is deliberate, not evidence of worker overlap.
    auto race = anchored(cfg);
    auto race_plan = normal_plan(race);
    check(attempt(race, race_plan, [&]() {
              race.live->set(-9 * kSide + 20, 80, Material::Wall);
              ++race.mutation_generation;
          }) == Decision::Stale, "stale staged proposal replaced newer source");
    check(race.live->stored_material(-9 * kSide + 20, 80) == Material::Wall,
          "new authoritative source edit was lost");
    check(race.live->chunk_count() == 1, "stale transaction published chunks");
    assert_no_bridge(race);

    // Negative control F: transient actor masks and optional witness data are
    // outside this experimental proposal's admitted clone/swap domain.
    auto pinned = anchored(cfg);
    pinned.live->configure_transient_obstacles({-128, 0, 128, 128});
    check(pinned.live->set_transient_obstacle(-64, 40, 7),
          "native host-owned obstacle preflight refused");
    pinned.external_pins = 1;
    check(attempt(pinned, normal_plan(pinned)) == Decision::Pinned,
          "host actor pin failed to veto private publication");
    check(pinned.live->transient_obstacle_at(-64, 40) == 7,
          "actor pin refusal damaged transient body mask");
    assert_no_bridge(pinned);
    auto sidecar = anchored(cfg);
    sidecar.unsupported_sidecar = true;
    check(attempt(sidecar, normal_plan(sidecar)) == Decision::Unsupported,
          "unsupported sidecar was silently discarded");
    assert_no_bridge(sidecar);

    // Positive restricted domain: clone preserves exact initial World state;
    // both semantic halves appear together only at the final private swap.
    auto live = anchored(cfg);
    auto reference = anchored(cfg);
    check(attempt(live, normal_plan(live)) == Decision::Published,
          "clean candidate did not publish");
    check(live.live->chunk_count() == 3 &&
              live.live->stored_material(-1, 64) == Material::Wall &&
              live.live->stored_material(0, 64) == Material::Wall,
          "published native seam is incomplete");
    check(reference.live->install_generated_chunk(kWest, span_for(127)) ==
              ChunkInstallOutcome::Installed, "reference west refused");
    check(reference.live->install_generated_chunk(kEast, span_for(0)) ==
              ChunkInstallOutcome::Installed, "reference east refused");
    check(live.live->physical_state_hash() == reference.live->physical_state_hash(),
          "restricted whole-World stage differs from direct native installation");
    std::uint32_t observed_live = 0, observed_reference = 0;
    for (int n = 0; n < 3; ++n) {
        const auto a = live.live->tick();
        const auto b = reference.live->tick();
        observed_live = std::max(observed_live, a.worker_threads_observed);
        observed_reference = std::max(observed_reference, b.worker_threads_observed);
        check(!live.live->has_failed() && !reference.live->has_failed(),
              "native continuation quarantined World");
        check(live.live->physical_state_hash() == reference.live->physical_state_hash() &&
                  live.live->quantity_ledger() == reference.live->quantity_ledger() &&
                  a.tick == b.tick,
              "private publication diverged from direct native 3-tick control");
    }
    std::cout << "GEN006_PRIVATE_STAGE configured_workers=" << workers
              << " observed_live=" << observed_live
              << " observed_reference=" << observed_reference
              << " resident_empty_refused=1 capacity_refused=1 invalid_refused=1"
              << " stale_session_refused=1 stale_precommit_refused=1"
              << " actor_pin_refused=1 sidecar_refused=1"
              << " atomic_restricted_publish=1 continuation_ticks=3"
              << " result=PASS assertions_so_far=" << assertions << '\n';
}
} // namespace
int main() {
    try {
        run(1);
        run(4);
        std::cout << "GEN006_PRIVATE_STAGE_PASS assertions=" << assertions << '\n';
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_PRIVATE_STAGE_FAIL assertions=" << assertions
                  << " detail=" << e.what() << '\n';
        return 1;
    }
}
