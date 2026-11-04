#include "cybersand/world.hpp"
#include <array>
#include <atomic>
#include <cstdlib>
#include <initializer_list>
#include <iostream>
#include <new>
#include <stdexcept>
#include <utility>

// Every admitted move and supported refusal is exercised with allocations
// forbidden after fixture/configuration; this catches lazy thermal allocation.
static std::atomic<bool> forbid_allocation{false};
void* operator new(std::size_t n) {
    if (forbid_allocation.load()) throw std::bad_alloc();
    if (auto* p = std::malloc(n == 0 ? 1 : n)) return p;
    throw std::bad_alloc();
}
void* operator new[](std::size_t n) { return ::operator new(n); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t) noexcept { std::free(p); }
namespace cybersand {
class PrecisionProbe {
public:
    static void failed(World& w, bool value) { w.tick_failed_ = value; }
    static void busy(World& w, bool value) { w.tick_in_progress_ = value; }
};
}
using namespace cybersand;
using Outcome = ConservativeDisplacementOutcome;
static unsigned groups = 0, checks = 0;
void expect(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}
WorldConfig config(std::uint32_t workers = 1) {
    WorldConfig c;
    c.chunk_size = 16;
    c.activity_block_size = 8;
    c.scheduling_core_size = 16;
    c.maximum_chunk_count = c.active_chunk_capacity = c.active_core_capacity = 64;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.physics_diagnostics.enabled = true;
    return c;
}
void reserve(World& w) {
    w.reserve_region({-16, -16, 64, 64});
    w.configure_transient_obstacles({-16, -16, 64, 64});
}
ConservativeDisplacementCell capture(const World& w, std::int64_t x, std::int64_t y) {
    return {x, y, w.stored_material(x, y), w.stored_state_a(x, y),
        w.stored_state_b(x, y), w.stored_temperature(x, y)};
}
ConservativeDisplacementRequest request(const World& w,
    std::initializer_list<std::pair<std::int64_t, std::int64_t>> coords,
    std::uint16_t body = 0) {
    ConservativeDisplacementRequest r;
    r.expected_tick = w.tick_index(); r.source_body_id = body;
    for (const auto& [x, y] : coords) r.path[r.count++] = capture(w, x, y);
    return r;
}
ConservativeDisplacementResult execute(World& w, const ConservativeDisplacementRequest& r) {
    struct Guard { Guard() { forbid_allocation = true; } ~Guard() { forbid_allocation = false; } } guard;
    return w.conservative_displace_cells(r);
}
void exact_at(const World& w, std::int64_t x, std::int64_t y, const ConservativeDisplacementCell& expected) {
    expect(w.stored_material(x, y) == expected.expected_material, "exact parcel material");
    expect(w.stored_state_a(x, y) == expected.expected_state_a, "exact parcel state_a");
    expect(w.stored_state_b(x, y) == expected.expected_state_b, "exact parcel state_b");
    expect(w.stored_temperature(x, y) == expected.expected_temperature, "exact parcel temperature");
}
void refused(World& w, const ConservativeDisplacementRequest& r, Outcome reason) {
    const auto before = w.physical_state_hash();
    const auto count = w.chunk_count();
    const auto result = execute(w, r);
    expect(result.outcome == reason && result.moved_cells == 0, "exact refusal with zero prefix moves");
    expect(w.physical_state_hash() == before, "refusal retains complete physical state");
    expect(w.chunk_count() == count, "refusal does not manufacture residency");
}
std::uint64_t displacement_events(const World& w) {
    std::uint64_t count = 0;
    for (const auto& event : w.physics_diagnostics()->entries)
        if ((event.key >> 24U) == static_cast<std::uint8_t>(PhysicsEvent::BodyDisplacement)) count += event.count;
    return count;
}
void mixed_payload_and_bookkeeping() {
    for (const auto workers : {1U, 4U}) for (const auto observer : {false, true}) {
        auto c = config(workers); c.settled_discovery_enabled = observer;
        c.settled_discovery_tile_capacity = 256;
        World w(c); reserve(w); w.reserve_temperature_region({-16, -16, 64, 64});
        expect(w.set_cell_state(-1, 10, Material::Sand, 73, 17), "Sand fixture state");
        expect(w.set_cell_state(0, 10, Material::Water, 127, 5), "fractional Water fixture state");
        expect(w.set_cell_state(0, 11, Material::Sand, 91, 29), "second Sand fixture state");
        w.set_temperature(-1, 10, 245); w.set_temperature(0, 10, 310); w.set_temperature(0, 11, 175);
        expect(w.set_transient_obstacle(-1, 10, 7), "source own-body occupancy");
        const auto r = request(w, {{-1,10},{0,10},{0,11},{1,11}}, 7);
        const auto ledger = w.quantity_ledger();
        const auto events = displacement_events(w);
        const auto chunks = w.chunk_count();
        (void)w.take_dirty_chunks();
        const auto result = execute(w, r);
        expect(result.outcome == Outcome::Applied && result.moved_cells == 3, "three adjacent parcels shifted");
        for (std::size_t i = 1; i < r.count; ++i) exact_at(w, r.path[i].x, r.path[i].y, r.path[i-1]);
        exact_at(w, -1, 10, {0, 0, Material::Empty, 0, 0, 200});
        expect(w.quantity_ledger() == ledger, "entire material/Water/state quantity ledger conserved");
        expect(w.chunk_count() == chunks, "no allocation of chunks");
        expect(w.transient_obstacle_at(-1, 10) == 7 && w.get(-1, 10) == Material::Wall,
            "displacement does not retire or overwrite body collision owner");
        expect(displacement_events(w) == events + 3, "one ordinary displacement event per moved parcel");
        expect(w.dirty_chunk_count() == 2 && w.active_chunk_count() >= 2,
            "signed chunk seam dirties and wakes both touched chunks");
        if (!observer) {
            const auto hash = w.physical_state_hash();
            auto saved = w.save_physical_state();
            auto restored = World::restore_physical_state(c, saved);
            // CYPS deliberately omits host-owned body masks; restore that
            // independent owner before comparing the complete live state.
            restored->configure_transient_obstacles({-16, -16, 64, 64});
            expect(restored->set_transient_obstacle(-1, 10, 7), "restore independent host mask");
            expect(restored->physical_state_hash() == hash, "bookkeeping survives cells plus explicit host-mask restore");
        } else {
            expect(!w.settled_discovery_capacity_blocked() && w.settled_discovery_pending() > 0,
                "existing read-only discovery receives bounded ordinary mutation bookkeeping");
        }
        refused(w, r, Outcome::StalePayload);
        expect(displacement_events(w) == events + 3, "repeated contact cannot replay a parcel or event");
    }
}
void geometry_payload_and_capacity_refusals() {
    World w(config()); reserve(w);
    w.set(10, 10, Material::Sand); w.set(11, 10, Material::Water); w.set(12, 10, Material::Sand);
    auto r = request(w, {{10,10},{11,10},{12,10},{13,10}});
    auto bad = r; bad.count = 6; refused(w, bad, Outcome::Capacity);
    bad = r; bad.count = 1; refused(w, bad, Outcome::InvalidPath);
    bad = r; bad.path[2] = bad.path[0]; refused(w, bad, Outcome::InvalidPath);
    bad = request(w, {{10,10},{12,10},{13,10}}); refused(w, bad, Outcome::InvalidPath);
    bad = request(w, {{10,10},{11,11}}); refused(w, bad, Outcome::InvalidPath);
    bad = r; bad.path[0].x = 1'000'000'001; refused(w, bad, Outcome::InvalidPath);
    bad = r; ++bad.path[1].expected_state_a; refused(w, bad, Outcome::StalePayload);
    bad = r; ++bad.path[1].expected_temperature; refused(w, bad, Outcome::StalePayload);
    bad = r; ++bad.expected_tick; refused(w, bad, Outcome::StaleTick);
    bad = r; bad.aggregate_token = {11, 12}; bad.body_generation = 1;
    refused(w, bad, Outcome::StaleAggregate);
    w.set(13, 10, Material::Sand);
    refused(w, request(w, {{10,10},{11,10},{12,10},{13,10}}), Outcome::InvalidTerminal);
    w.set(13, 10, Material::Empty); w.set_temperature(13, 10, 201);
    refused(w, request(w, {{10,10},{11,10},{12,10},{13,10}}), Outcome::InvalidTerminal);
    w.set_temperature(13, 10, 200);
    for (const auto unsupported : {Material::Wood, Material::Acid, Material::Oil, Material::Wall}) {
        w.set(11, 10, unsupported);
        refused(w, request(w, {{10,10},{11,10},{12,10},{13,10}}), Outcome::UnsupportedMaterial);
    }
    w.set(11, 10, Material::Empty);
    refused(w, request(w, {{10,10},{11,10},{12,10},{13,10}}), Outcome::UnsupportedMaterial);
}
void masks_residency_and_thermal_capacity() {
    World w(config()); reserve(w);
    w.set(14, 10, Material::Sand); w.set(15, 10, Material::Water);
    auto r = request(w, {{14,10},{15,10},{16,10}}, 9);
    refused(w, r, Outcome::SourceMask); // A named owner may not be absent.
    expect(w.set_transient_obstacle(14, 10, 8), "foreign mask fixture");
    refused(w, r, Outcome::SourceMask);
    w.clear_transient_obstacles();
    expect(w.set_transient_obstacle(14, 10, 9), "matching source mask fixture");
    expect(w.set_transient_obstacle(15, 10, 9), "own-body destination mask fixture");
    refused(w, r, Outcome::DestinationMask);
    w.clear_transient_obstacles();
    expect(w.set_transient_obstacle(14, 10, 9), "matching source mask fixture");
    expect(w.set_transient_obstacle(16, 10, 10), "foreign terminal mask fixture");
    refused(w, r, Outcome::DestinationMask);
    w.clear_transient_obstacles();
    // The final cross-chunk Water move needs an absent thermal field. The
    // earlier Sand move must not occur as a partial prefix before refusal.
    w.set_temperature(15, 10, 333);
    r = request(w, {{14,10},{15,10},{16,10}});
    refused(w, r, Outcome::ThermalCapacity);
    w.reserve_temperature_region({16, 10, 1, 1});
    const auto result = execute(w, r);
    expect(result.outcome == Outcome::Applied && result.moved_cells == 2,
        "preallocated destination admits hot parcel without allocation");
    exact_at(w, 16, 10, r.path[1]); exact_at(w, 15, 10, r.path[0]);
    World nonresident(config()); nonresident.reserve_region({0,0,16,16});
    nonresident.set(15, 10, Material::Sand);
    refused(nonresident, request(nonresident, {{15,10},{16,10}}), Outcome::Nonresident);
    nonresident.set_simulation_region(RectI64{0,0,16,16});
    refused(nonresident, request(nonresident, {{14,10},{15,10}}), Outcome::Excluded);
    World excluded(config()); reserve(excluded); excluded.set_simulation_region(RectI64{0,0,16,16});
    (void)excluded.tick(); excluded.set(31, 10, Material::Sand);
    refused(excluded, request(excluded, {{31,10},{32,10}}), Outcome::Excluded);
}
void policy_tick_and_failed_world_refusals() {
    for (const auto family : {2, 3, 4}) {
        auto words = LiquidSolverPolicy::default_request(); words[21] = family;
        auto policy = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        expect(policy.accepted(), "candidate policy fixture admitted");
        auto c = config(); c.liquid_solver_policy = *policy.policy;
        if (family == 4) c.maximum_rule_radius = 3;
        World w(c); reserve(w); w.set(10, 10, Material::Sand);
        refused(w, request(w, {{10,10},{11,10}}), Outcome::UnsupportedPolicy);
    }
    World w(config()); reserve(w); w.set(10, 10, Material::Sand);
    const auto r = request(w, {{10,10},{11,10}});
    const auto before = w.content_hash();
    PrecisionProbe::busy(w, true);
    auto result = execute(w, r);
    expect(result.outcome == Outcome::TickInProgress && result.moved_cells == 0, "pool-active owner cannot mutate");
    PrecisionProbe::busy(w, false);
    PrecisionProbe::failed(w, true);
    result = execute(w, r);
    expect(result.outcome == Outcome::WorldFailed && result.moved_cells == 0, "failed owner cannot mutate");
    PrecisionProbe::failed(w, false);
    expect(w.content_hash() == before, "busy and failed guards preserve payload");
}
void transition_and_compound_generation_lease() {
    using namespace soliding;
    World w(config()); reserve(w);
    w.set(20, 20, Material::RedBrick); w.set(21, 20, Material::RedBrick); w.set(20, 21, Material::RedBrick);
    w.set(10, 10, Material::Sand);
    expect(w.configure_solid_detachment() == SolidOutcome::Accepted, "detachment configuration");
    expect(w.prepare_solid_detachment({{16,16,16,16},{0,40,48,8},20,20}) == SolidOutcome::Accepted,
        "real three-cell native compound preparation");
    auto r = request(w, {{10,10},{11,10}}, 6);
    auto result = execute(w, r);
    expect(result.outcome == Outcome::TransitionFenced && result.moved_cells == 0,
        "pending ownership transaction blocks displacement");
    const auto snapshot = w.inspect_solid_detachment();
    expect(snapshot.shape_count == 2, "L-shaped native component has two proxy IDs");
    expect(w.acknowledge_solid_detachment({snapshot.token,5,19,snapshot.payload_digest,snapshot.shape_digest,2}) ==
        SolidOutcome::Accepted, "compound native reservation");
    expect(w.commit_solid_detachment(snapshot.token) == SolidOutcome::Accepted, "native compound commit");
    const auto committed = w.inspect_solid_detachment();
    expect(w.finalize_solid_detachment({snapshot.token,5,19,committed.committed_terrain_revision,31}) ==
        SolidOutcome::Accepted, "native compound activation receipt");
    expect(w.set_transient_obstacle(10, 10, 6), "second compound proxy source mask");
    r.aggregate_token = snapshot.token; r.body_generation = 19;
    auto bad = r; ++bad.body_generation;
    result = execute(w, bad);
    expect(result.outcome == Outcome::StaleAggregate && result.moved_cells == 0, "stale body generation refused");
    bad = r; ++bad.aggregate_token.sequence;
    result = execute(w, bad);
    expect(result.outcome == Outcome::StaleAggregate && result.moved_cells == 0, "stale aggregate token refused");
    result = execute(w, r);
    expect(result.outcome == Outcome::Applied && result.moved_cells == 1,
        "non-first proxy of exactly bound aggregate may displace its source");
    w.clear(); reserve(w); w.set(10, 10, Material::Sand);
    result = execute(w, r);
    expect(result.outcome == Outcome::StaleAggregate && result.moved_cells == 0,
        "same tick and payload after reset cannot reuse old aggregate generation");
}
void maximum_chain_and_worker_order_parity() {
    World one(config(1)), four(config(4));
    for (auto* w : {&one, &four}) {
        reserve(*w);
        for (int x = 13; x < 17; ++x) w->set(x, 10, x % 2 == 0 ? Material::Water : Material::Sand);
        for (int x = 10; x < 22; ++x) w->set(x, 14, Material::Wall);
        const auto r = request(*w, {{13,10},{14,10},{15,10},{16,10},{17,10}});
        const auto result = execute(*w, r);
        expect(result.outcome == Outcome::Applied && result.moved_cells == 4, "exact maximum chain admitted");
        for (std::size_t i = 1; i < r.count; ++i) exact_at(*w, r.path[i].x, r.path[i].y, r.path[i-1]);
    }
    expect(one.content_hash() == four.content_hash(), "configured worker-independent synchronous displacement");
    for (int tick = 0; tick < 4; ++tick) {
        (void)one.tick(); (void)four.tick();
        expect(one.content_hash() == four.content_hash(), "ordinary subsequent native evolution matches workers1/4");
    }
}
int main() {
    try {
        const auto run = [](const char* name, auto test) { test(); ++groups; std::cout << "PASS " << name << '\n'; };
        run("mixed payload/quantity/thermal/dirty/activity/source mask/repeat contact", mixed_payload_and_bookkeeping);
        run("cyclic/noncardinal/capacity/stale/occupied/reactive refusal", geometry_payload_and_capacity_refusals);
        run("foreign masks/residency/exclusion/thermal preflight", masks_residency_and_thermal_capacity);
        run("policy/tick/failed owner refusal", policy_tick_and_failed_world_refusals);
        run("transition fence/compound proxy/generation/reset", transition_and_compound_generation_lease);
        run("maximum four-parcel chain and configured workers1/4", maximum_chain_and_worker_order_parity);
        std::cout << "CONSERVATIVE-DISPLACEMENT native: " << groups << " groups, " << checks << " checks passed.\n"
                  << "Transactional native parcel movement only; adapter geometric/force and actual Rapier admission are separate.\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL after " << groups << " groups: " << error.what() << '\n'; return 1;
    }
}
