#include "cybersand/soliding_lifecycle.hpp"
#include "cybersand/material.hpp"

#include <array>
#include <iostream>
#include <stdexcept>
#include <type_traits>

namespace {
using namespace cybersand::soliding::model;
using Model = Registry<4, 8, 2>;
static_assert(!std::is_copy_constructible_v<Model> && !std::is_copy_assignable_v<Model>);
static_assert(!std::is_move_constructible_v<Model> && !std::is_move_assignable_v<Model>);
void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
Preflight ready() { return {true, true, true, true, true, true, true, true, true, true, true, true, true}; }
Topology visible() { return {true, true, true, true, true, true, true, true}; }
Eligibility coherent() { return {MaterialClass::IntrinsicCohesive, true, true, true, true, true, true}; }
constexpr std::array<Member, 3> payload{{
    {1, static_cast<std::uint8_t>(cybersand::Material::Wall), 255, 19, -273},
    {2, static_cast<std::uint8_t>(cybersand::Material::Wall), 2, 255, 1200},
    {3, static_cast<std::uint8_t>(cybersand::Material::Wall), 0, 0, 20}
}};
template<class R> typename R::Snapshot get(const R& registry, Handle handle) {
    typename R::Snapshot value;
    require(registry.snapshot(handle, value), "valid snapshot handle");
    return value;
}
template<class R> void exact(const R& registry, Handle handle, Owner expected) {
    const auto value = get(registry, handle);
    require(value.owner == expected, "sole owner");
    require(value.count == payload.size(), "payload count");
    for (std::size_t i = 0; i < payload.size(); ++i)
        require(value.members[i] == payload[i], "exact material/state/temperature/membership");
    const auto ledger = registry.accounting();
    require(ledger.total() == payload.size(), "no missing or duplicate payload");
    require(ledger.cells == (expected == Owner::Cells ? payload.size() : 0), "cell owner count");
    require(ledger.stationary_store == (expected == Owner::StationaryStore ? payload.size() : 0), "stationary owner count");
    require(ledger.aggregate_store == (expected == Owner::AggregateStore ? payload.size() : 0), "aggregate owner count");
}
Token prepare(Model& registry, Handle handle, Representation target) {
    Token token;
    require(registry.prepare(handle, target, get(registry, handle).revision, coherent(), ready(), token) == Outcome::Accepted,
            "prepare admitted");
    return token;
}
void finish(Model& registry, Token token) {
    require(registry.acknowledge(token, ready()) == Outcome::Accepted, "ack admitted");
    require(registry.commit(token, ready()) == Outcome::Accepted, "commit admitted");
    require(registry.finalize(token, visible()) == Outcome::Accepted, "finalize admitted");
}

void transitions_and_exact_accounting() {
    Model registry(1);
    Handle handle;
    require(registry.create(payload, handle) == Outcome::Accepted, "create source");
    const auto retained = get(registry, handle);
    constexpr std::array tiers{Representation::SleepingCells, Representation::SettledSummary,
        Representation::StationaryCells, Representation::StationaryPayload,
        Representation::DynamicAggregate, Representation::ActiveCells};
    for (unsigned cycle = 0; cycle < 64; ++cycle) for (const auto target : tiers) {
        const auto old_owner = get(registry, handle).owner;
        const auto token = prepare(registry, handle, target);
        exact(registry, handle, old_owner);
        require(!get(registry, handle).publishable() && !get(registry, handle).cell_save_admissible(), "pending visibility/save refused");
        require(registry.commit(token, ready()) == Outcome::Stale, "commit before ack refused");
        require(registry.acknowledge(token, ready()) == Outcome::Accepted, "ack");
        exact(registry, handle, old_owner);
        require(registry.acknowledge(token, ready()) == Outcome::Stale, "duplicate ack refused");
        require(registry.commit(token, ready()) == Outcome::Accepted, "commit");
        exact(registry, handle, owner_of(target));
        require(registry.cancel(token) == Outcome::Refused, "postcommit cancel forbidden");
        require(registry.commit(token, ready()) == Outcome::Stale, "duplicate commit refused");
        require(!get(registry, handle).publishable(), "postcommit fence");
        require(registry.finalize(token, visible()) == Outcome::Accepted, "topology finalize");
        require(get(registry, handle).publishable(), "finalized publication");
        require(get(registry, handle).cell_save_admissible() == (owner_of(target) == Owner::Cells), "save owner boundary");
        require(registry.pending() == 0, "reservation released once");
        require(registry.finalize(token, visible()) == Outcome::Stale, "duplicate finalize refused");
    }
    require(retained.representation == Representation::ActiveCells && retained.members[0] == payload[0], "immutable copied observation");
}

void preflight_cancel_and_stale() {
    constexpr std::array guards{&Preflight::healthy, &Preflight::included_with_halo, &Preflight::exclusive_fence,
        &Preflight::complete_membership, &Preflight::payload_reserved, &Preflight::shape_reserved,
        &Preflight::body_reserved, &Preflight::acknowledgement_reserved, &Preflight::result_reserved,
        &Preflight::destinations_reserved, &Preflight::topology_current, &Preflight::no_pending_events};
    for (const auto guard : guards) {
        Model registry(2);
        Handle handle;
        require(registry.create(payload, handle) == Outcome::Accepted, "guard source");
        Token token;
        auto bad = ready(); bad.*guard = false;
        require(registry.prepare(handle, Representation::DynamicAggregate, 1, coherent(), bad, token) == Outcome::Refused, "preflight prepare refusal");
        exact(registry, handle, Owner::Cells);
        token = prepare(registry, handle, Representation::DynamicAggregate);
        require(registry.acknowledge(token, bad) == Outcome::Refused, "ack guard refusal");
        require(registry.acknowledge(token, ready()) == Outcome::Accepted, "ack recovery before commit");
        require(registry.commit(token, bad) == Outcome::Refused, "commit guard refusal");
        exact(registry, handle, Owner::Cells);
        require(registry.cancel(token) == Outcome::Accepted, "cancel acknowledged");
        exact(registry, handle, Owner::Cells);
        require(registry.cancel(token) == Outcome::Refused, "cancel is once");
        require(registry.pending() == 0, "cancellation releases reservation");
    }
    Model registry(3);
    Handle handle;
    require(registry.create(payload, handle) == Outcome::Accepted, "stale source");
    auto token = prepare(registry, handle, Representation::DynamicAggregate);
    auto stale = token; ++stale.handle.incarnation;
    require(registry.acknowledge(stale, ready()) == Outcome::Stale, "cross-incarnation ack refused");
    stale = token; ++stale.sequence;
    require(registry.acknowledge(stale, ready()) == Outcome::Stale, "wrong transaction refused");
    stale = token; stale.target = Representation::StationaryPayload;
    require(registry.acknowledge(stale, ready()) == Outcome::Stale, "wrong direction refused");
    require(registry.invalidate(handle, Invalidation::Edit) == Outcome::Accepted, "edit invalidates pending");
    require(registry.acknowledge(token, ready()) == Outcome::Stale, "ABA revision refuses stale work");
    exact(registry, handle, Owner::Cells);
    require(registry.prepare(handle, Representation::DynamicAggregate, token.revision, coherent(), ready(), stale) == Outcome::Stale, "stale preparation refused");
}

void capacities_and_nonwrapping_identity() {
    Registry<1, 3, 1, 2> registry(4);
    Handle first, second, ignored;
    require(registry.create(payload, first) == Outcome::Accepted, "generation one");
    require(registry.untrack(first) == Outcome::Accepted, "untrack cells");
    require(registry.create(payload, second) == Outcome::Accepted && second.generation == 2, "generation two");
    require(registry.untrack(first) == Outcome::Stale, "retired identity rejected");
    require(registry.untrack(second) == Outcome::Accepted, "second untrack");
    require(registry.create(payload, ignored) == Outcome::Exhausted, "generation refuses wrap");
    Registry<1, 3, 1, 10, 2> sequence_registry(5);
    require(sequence_registry.create(payload, first) == Outcome::Accepted, "sequence source");
    Token token;
    for (unsigned i = 0; i < 2; ++i) {
        require(sequence_registry.prepare(first, Representation::SettledSummary, 1, coherent(), ready(), token) == Outcome::Accepted, "sequence generation");
        require(sequence_registry.cancel(token) == Outcome::Accepted, "sequence cancel");
    }
    require(sequence_registry.prepare(first, Representation::SettledSummary, 1, coherent(), ready(), token) == Outcome::Exhausted, "sequence refuses wrap");
    exact(sequence_registry, first, Owner::Cells);
    Registry<1, 3, 1, 10, 10, 2> revision_registry(6);
    require(revision_registry.create(payload, first) == Outcome::Accepted, "revision source");
    require(revision_registry.invalidate(first, Invalidation::Heat) == Outcome::Accepted, "revision increment");
    require(revision_registry.invalidate(first, Invalidation::Heat) == Outcome::Exhausted, "revision refuses wrap");
    require(revision_registry.prepare(first, Representation::SettledSummary, 2, coherent(), ready(), token) == Outcome::Exhausted, "exhausted revision cannot authorize work");
    exact(revision_registry, first, Owner::Cells);

    Registry<3, 3, 1> bounded(7);
    auto other_payload = payload;
    for (auto& member : other_payload) member.identity += 10;
    require(bounded.create(payload, first) == Outcome::Accepted, "queue first");
    require(bounded.create(other_payload, second) == Outcome::Accepted, "queue second");
    require(bounded.create(payload, ignored) == Outcome::Invalid, "duplicate membership ownership refused");
    require(bounded.prepare(first, Representation::SettledSummary, 1, coherent(), ready(), token) == Outcome::Accepted, "reserve bounded queue");
    Token refused;
    require(bounded.prepare(second, Representation::SettledSummary, 1, coherent(), ready(), refused) == Outcome::Capacity, "queue-full refusal");
    require(get(bounded, second).phase == Phase::Stable && bounded.accounting().cells == 6, "full queue retains old owners");
    require(bounded.cancel(token) == Outcome::Accepted, "free reservation");
    require(bounded.prepare(second, Representation::SettledSummary, 1, coherent(), ready(), refused) == Outcome::Accepted, "deferred request retries");
    Registry<1, 2, 1> too_small(8);
    require(too_small.create(payload, ignored) == Outcome::Capacity && too_small.accounting().total() == 0, "membership capacity cannot truncate");
}

void every_postcommit_guard_quarantines() {
    constexpr std::array guards{&Topology::healthy, &Topology::included_with_halo,
        &Topology::no_pending_events, &Topology::exclusive_fence, &Topology::target_collision_ready,
        &Topology::old_collision_retired, &Topology::occupancy_complete, &Topology::immutable_publication_ready};
    for (const auto guard : guards) {
        Model registry(12);
        Handle handle;
        require(registry.create(payload, handle) == Outcome::Accepted, "finalize guard source");
        const auto token = prepare(registry, handle, Representation::DynamicAggregate);
        require(registry.acknowledge(token, ready()) == Outcome::Accepted, "finalize guard ack");
        require(registry.commit(token, ready()) == Outcome::Accepted, "finalize guard commit");
        auto bad = visible(); bad.*guard = false;
        require(registry.finalize(token, bad) == Outcome::Quarantined, "every postcommit guard quarantines");
        exact(registry, handle, Owner::AggregateStore);
        require(!get(registry, handle).publishable() && registry.pending() == 1, "failed finalize preserves fence/reservations");
    }
    Model registry(13);
    Handle handle;
    require(registry.create(payload, handle) == Outcome::Accepted, "motion guard source");
    finish(registry, prepare(registry, handle, Representation::DynamicAggregate));
    const auto token = prepare(registry, handle, Representation::ActiveCells);
    auto unsafe = ready(); unsafe.safe_motion_return = false;
    require(registry.acknowledge(token, unsafe) == Outcome::Refused, "motion rechecked at return ack");
    require(registry.acknowledge(token, ready()) == Outcome::Accepted, "motion return ack");
    require(registry.commit(token, unsafe) == Outcome::Refused, "motion rechecked at return commit");
    exact(registry, handle, Owner::AggregateStore);
    require(registry.cancel(token) == Outcome::Accepted, "unsafe return preserves aggregate");
    const auto newer = prepare(registry, handle, Representation::ActiveCells);
    require(registry.cancel(token) == Outcome::Stale, "old cancel cannot cancel newer request");
    require(registry.acknowledge(newer, ready()) == Outcome::Accepted, "new return ack");
    require(registry.commit(newer, ready()) == Outcome::Accepted, "new return commit");
    require(registry.invalidate(handle, Invalidation::PendingEvent) == Outcome::Quarantined, "postcommit invalidation quarantines");
    exact(registry, handle, Owner::Cells);
}
void eligibility_pause_and_quarantine() {
    for (const auto category : {MaterialClass::LooseGranular, MaterialClass::StatefulGranular, MaterialClass::Reactive, MaterialClass::Mixed}) {
        auto e = coherent(); e.material_class = category;
        require(e.summary() && e.stationary() && !e.dynamic(), "rest/stationary never implies cohesion");
        Model registry(9);
        Handle handle;
        require(registry.create(payload, handle) == Outcome::Accepted, "eligibility source");
        Token token;
        require(registry.prepare(handle, Representation::DynamicAggregate, 1, e, ready(), token) == Outcome::Ineligible, "noncohesive dynamics refused");
        exact(registry, handle, Owner::Cells);
    }
    auto unsupported = coherent(); unsupported.cohesion_policy_authorized = false;
    require(!unsupported.dynamic(), "intrinsic class alone does not authorize material policy");
    unsupported = coherent(); unsupported.stable_witness = false;
    require(!unsupported.summary() && !unsupported.stationary() && !unsupported.dynamic(), "sleep alone is not stable evidence");

    Model registry(10);
    Handle handle;
    require(registry.create(payload, handle) == Outcome::Accepted, "pause source");
    for (unsigned i = 0; i < 8; ++i) require(registry.observe(handle, true, true, true) == Outcome::Accepted, "healthy observations");
    require(get(registry, handle).quiet_observations == 8, "quiet observations counted");
    for (unsigned i = 0; i < 64; ++i) require(registry.observe(handle, false, true, true) == Outcome::Accepted, "excluded observation");
    require(get(registry, handle).quiet_observations == 0 && !get(registry, handle).cell_save_admissible(), "exclusion earns no rest");
    require(registry.observe(handle, true, true, true) == Outcome::Accepted && get(registry, handle).quiet_observations == 0, "reentry begins fresh rest window");
    require(registry.observe(handle, true, true, true) == Outcome::Accepted && get(registry, handle).quiet_observations == 1, "only included new observation accrues");
    auto token = prepare(registry, handle, Representation::DynamicAggregate);
    finish(registry, token);
    auto unsafe = ready(); unsafe.safe_motion_return = false;
    require(registry.prepare(handle, Representation::ActiveCells, get(registry, handle).revision, coherent(), unsafe, token) == Outcome::Refused, "moving aggregate cannot become motionless cells");
    require(registry.untrack(handle) == Outcome::Refused, "aggregate cannot be silently destroyed");
    require(registry.invalidate(handle, Invalidation::BodyContact) == Outcome::Accepted, "body event invalidates witness");
    exact(registry, handle, Owner::AggregateStore);
    require(get(registry, handle).representation == Representation::DynamicAggregate, "contact cannot globally dissolve payload");
    token = prepare(registry, handle, Representation::ActiveCells);
    require(registry.acknowledge(token, ready()) == Outcome::Accepted, "reversal ack");
    require(registry.commit(token, ready()) == Outcome::Accepted, "reversal commit");
    auto broken = visible(); broken.old_collision_retired = false;
    require(registry.finalize(token, broken) == Outcome::Quarantined, "postcommit topology failure quarantines");
    exact(registry, handle, Owner::Cells);
    require(!get(registry, handle).publishable() && !get(registry, handle).cell_save_admissible(), "quarantine hides partial topology");
    require(registry.cancel(token) == Outcome::Refused && registry.pending() == 1, "quarantine has no invented rollback");
    require(registry.observe(handle, true, true, true) == Outcome::Quarantined, "quarantine cannot recover by observation");
    require(registry.finalize(token, visible()) == Outcome::Stale, "no in-place topology retry");
    Model failed(11);
    require(failed.create(payload, handle) == Outcome::Accepted, "failed source");
    require(failed.observe(handle, true, false, true) == Outcome::Quarantined, "failed world quarantines");
    exact(failed, handle, Owner::Cells);
}
} // namespace
int main() {
    try {
        transitions_and_exact_accounting();
        preflight_cancel_and_stale();
        capacities_and_nonwrapping_identity();
        eligibility_pause_and_quarantine();
        every_postcommit_guard_quarantines();
        std::cout << "PASS soliding lifecycle model: 384 complete transitions, 12 prepare/ack/commit guard refusals, 8 finalize quarantine guards, exact tuple/owner ledger, stale/cancel/capacity/exhaustion, eligibility/exclusion/quarantine\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL soliding lifecycle model: " << error.what() << '\n';
        return 1;
    }
}
