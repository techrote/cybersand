#include "cybersand/settled_discovery.hpp"
#include "cybersand/world.hpp"

#include <array>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <type_traits>

namespace {
using namespace cybersand::soliding;
using Tracker = SettledDiscovery<4, 16>;
void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}
DiscoverySignals quiet() { return {true, true, true, false, false, false}; }
constexpr DiscoveryCell wall{1, 255, 17, 200, false};
constexpr DiscoveryBounds tile{-2, -2, 2, 2};
static_assert(!std::is_copy_constructible_v<Tracker> && !std::is_move_constructible_v<Tracker>);
DiscoverySummary snapshot(const auto& tracker, DiscoveryHandle handle) {
    const auto result = tracker.snapshot(handle);
    require(result.has_value(), "snapshot present");
    return *result;
}
DiscoveryHandle add(auto& tracker, DiscoveryBounds bounds = tile, DiscoverySignals signals = quiet(), std::uint64_t tick = 0) {
    DiscoveryHandle handle;
    require(tracker.register_block(bounds, signals, tick, handle) == DiscoveryOutcome::Accepted, "registration admitted");
    return handle;
}
void work_budget_and_immutable_results() {
    Tracker tracker(1);
    const auto handle = add(tracker);
    std::size_t reads = 0;
    const auto read = [&](std::int64_t, std::int64_t) { ++reads; return wall; };
    require(tracker.advance(0, 0, read) == 0 && reads == 0, "zero work budget");
    require(tracker.advance(0, 1, read) == 1 && reads == 0, "start costs one work unit");
    for (unsigned i = 0; i < 4; ++i) {
        require(tracker.advance(0, 1, read) == 1 && reads == i + 1, "each cell costs one work unit");
        require(snapshot(tracker, handle).classification == DiscoveryClass::Invalid, "no partial publication");
    }
    require(tracker.advance(2, 1, read) == 1, "finalize costs one work unit");
    const auto retained = snapshot(tracker, handle);
    require(retained.classification == DiscoveryClass::Uniform && retained.uniform == wall, "complete exact uniform tuple");
    require(tracker.metrics().work_units == 6 && tracker.metrics().cells_inspected == 4, "exact start/read/finalize work counters");
    require(tracker.metrics().latency_max_ticks == 2 && tracker.pending() == 0, "publication latency and queue drain");
    require(tracker.advance(2, 100, read) == 0 && reads == 4, "quiet maintenance has no scans");
    require(tracker.dirty(handle, 3) == DiscoveryOutcome::Accepted, "dirty published block");
    require(snapshot(tracker, handle).classification == DiscoveryClass::Invalid, "dirty immediately invalidates result");
    require(retained.classification == DiscoveryClass::Uniform && retained.revision == 1, "retained result is immutable value");
    require(tracker.advance(3, 5, read) == 5 && snapshot(tracker, handle).classification == DiscoveryClass::Invalid, "full scan still needs publication budget");
    require(tracker.advance(3, 1, read) == 1 && snapshot(tracker, handle).revision == 2, "new generation publication");
}
void aba_and_exact_classification() {
    for (unsigned variation = 0; variation < 5; ++variation) {
        Tracker tracker(2 + variation);
        const auto handle = add(tracker);
        std::array<DiscoveryCell, 4> source{wall, wall, wall, wall};
        if (variation == 0) source[2].material = 0; // A hole is explicit mixed membership.
        if (variation == 1) source[2].material = 2;
        if (variation == 2) source[2].state_a = 1;
        if (variation == 3) source[2].state_b = 1;
        if (variation == 4) source[2].temperature = -273;
        const auto read = [&](std::int64_t x, std::int64_t y) { return source[static_cast<std::size_t>((y + 2) * 2 + x + 2)]; };
        require(tracker.advance(0, 6, read) == 6, "mixed full scan bounded");
        require(snapshot(tracker, handle).classification == DiscoveryClass::Mixed, "hole/material/state/temperature not uniform");
    }
    Tracker tracker(10);
    const auto handle = add(tracker);
    DiscoveryCell source = wall;
    const auto read = [&](std::int64_t, std::int64_t) { return source; };
    require(tracker.advance(0, 3, read) == 3, "partial scan");
    source.temperature = 600;
    require(tracker.dirty(handle, 1) == DiscoveryOutcome::Accepted, "change witness");
    source = wall;
    require(tracker.dirty(handle, 1) == DiscoveryOutcome::Accepted, "restore is a separate witness");
    require(tracker.pending() == 1 && snapshot(tracker, handle).revision == 3, "ABA dirty coalesces queue but retains revision");
    require(tracker.advance(1, 5, read) == 5 && snapshot(tracker, handle).classification == DiscoveryClass::Invalid, "old partial work cannot publish");
    require(tracker.advance(2, 1, read) == 1 && snapshot(tracker, handle).uniform == wall, "ABA result requires full new scan");
    require(tracker.metrics().cells_inspected == 6 && tracker.metrics().restarts == 1, "ABA restarted read count");
    require(snapshot(tracker, handle).dirty_tick == 0 && tracker.metrics().latency_max_ticks == 2, "churn does not reset oldest outstanding latency");
    require(tracker.dirty(handle, 3) == DiscoveryOutcome::Accepted, "occupied source invalidation");
    source.occupied = true;
    require(tracker.advance(3, 6, read) == 6 && snapshot(tracker, handle).classification == DiscoveryClass::Blocked, "cell occupancy prevents uniform admission");
    require(tracker.dirty(handle, 4) == DiscoveryOutcome::Accepted, "empty source invalidation");
    source = {};
    require(tracker.advance(4, 6, read) == 6 && snapshot(tracker, handle).classification == DiscoveryClass::Empty, "complete empty classification");
}
void signal_gates_and_capacity() {
    constexpr std::array gates{&DiscoverySignals::witness_complete, &DiscoverySignals::healthy,
        &DiscoverySignals::included, &DiscoverySignals::active, &DiscoverySignals::pending_event,
        &DiscoverySignals::occupied};
    for (const auto gate : gates) {
        Tracker tracker(11);
        auto signals = quiet(); signals.*gate = !(signals.*gate);
        const auto handle = add(tracker, tile, signals);
        std::size_t reads = 0;
        const auto read = [&](std::int64_t, std::int64_t) { ++reads; return wall; };
        require(tracker.advance(0, 1, read) == 1 && reads == 0, "blocked/excluded/unknown observation has no reads");
        require(snapshot(tracker, handle).classification == DiscoveryClass::Blocked, "signal blocks classification");
        require(tracker.observe(handle, signals, 3) == DiscoveryOutcome::Unchanged && tracker.pending() == 0, "unchanged excluded time creates no work/rest");
        require(tracker.observe(handle, quiet(), 4) == DiscoveryOutcome::Accepted, "reentry/gap recovery invalidates witness");
        require(snapshot(tracker, handle).classification == DiscoveryClass::Invalid, "reentry cannot reuse old classification");
        require(tracker.advance(4, 5, read) == 5 && snapshot(tracker, handle).classification == DiscoveryClass::Invalid, "reentry needs complete fresh scan");
        require(tracker.advance(4, 1, read) == 1 && snapshot(tracker, handle).classification == DiscoveryClass::Uniform, "fresh included scan completes");
    }
    SettledDiscovery<2, 4> tracker(12);
    const auto first = add(tracker);
    const auto second = add(tracker, {5, 5, 2, 2});
    DiscoveryHandle refused;
    require(tracker.register_block({10, 10, 2, 2}, quiet(), 0, refused) == DiscoveryOutcome::Capacity, "full registration refuses");
    require(tracker.pending() == 2 && tracker.size() == 2 && tracker.metrics().refusals == 1, "capacity leaves accepted slots intact");
    for (unsigned i = 0; i < 8; ++i) require(tracker.dirty(first, 0) == DiscoveryOutcome::Accepted, "coalesced dirty accepted");
    require(tracker.pending() == 2 && tracker.metrics().queue_high_water == 2, "dirty queue bounded to slots");
    require(tracker.advance(0, 12, [](auto, auto) { return wall; }) == 12, "both capacity survivors finish");
    require(snapshot(tracker, first).classification == DiscoveryClass::Uniform && snapshot(tracker, second).classification == DiscoveryClass::Uniform, "capacity refusal cannot destroy results");
    auto stale = first; ++stale.incarnation;
    require(tracker.advance(5, 0, [](auto, auto) { return wall; }) == 0, "advance current producer clock");
    for (const auto stale_tick : {std::uint64_t{0}, std::numeric_limits<std::uint64_t>::max()}) {
        require(tracker.dirty(stale, stale_tick) == DiscoveryOutcome::Stale, "stale dirty cannot alter clock");
        require(tracker.observe(stale, quiet(), stale_tick) == DiscoveryOutcome::Stale, "stale observation cannot alter clock");
    }
    require(!tracker.snapshot(stale) && tracker.halted() == DiscoveryHalt::None && snapshot(tracker, first).classification == DiscoveryClass::Uniform, "stale incarnation preserves valid result");
    require(tracker.register_block({10, 10, 2, 2}, quiet(), std::numeric_limits<std::uint64_t>::max(), refused) == DiscoveryOutcome::Capacity, "full registration cannot alter clock");
    require(tracker.dirty(first, 5) == DiscoveryOutcome::Accepted, "valid same-clock work survives stale future and full requests");
}
void exhaustion_failure_and_coordinates() {
    SettledDiscovery<2, 4, 2> tracker(13);
    const auto first = add(tracker);
    const auto second = add(tracker, {5, 5, 2, 2});
    require(tracker.advance(0, 12, [](auto, auto) { return wall; }) == 12, "preexhaustion publication");
    require(tracker.dirty(first, 1) == DiscoveryOutcome::Accepted, "revision last usable value");
    require(tracker.dirty(first, 1) == DiscoveryOutcome::Halted && tracker.halted() == DiscoveryHalt::RevisionExhausted, "nonwrapping revision exhaustion");
    require(!tracker.snapshot(first) && !tracker.snapshot(second), "exhaustion disables every stale summary");
    require(tracker.advance(2, 100, [](auto, auto) { return wall; }) == 0, "halted tracker performs no work");

    Tracker failed(14);
    const auto failed_handle = add(failed);
    bool threw = false;
    try { (void)failed.advance(0, 3, [](auto, auto) -> DiscoveryCell { throw std::runtime_error("injected read failure"); }); }
    catch (const std::runtime_error&) { threw = true; }
    require(threw && failed.halted() == DiscoveryHalt::SourceFailure && !failed.snapshot(failed_handle), "source throw globally suppresses results");
    Tracker producer_failed(15);
    const auto producer_handle = add(producer_failed);
    producer_failed.fail();
    require(!producer_failed.snapshot(producer_handle) && producer_failed.halted() == DiscoveryHalt::ProducerFailure, "producer failure has no results");
    Tracker first_failure(19);
    (void)add(first_failure);
    try {
        (void)first_failure.advance(0, 3, [&](auto, auto) -> DiscoveryCell {
            first_failure.fail(); throw std::runtime_error("secondary source failure");
        });
    } catch (const std::runtime_error&) {}
    require(first_failure.halted() == DiscoveryHalt::ProducerFailure, "first failure reason retained");
    Tracker clock_failed(16);
    const auto clock_handle = add(clock_failed, tile, quiet(), 2);
    require(clock_failed.dirty(clock_handle, 1) == DiscoveryOutcome::Halted && !clock_failed.snapshot(clock_handle), "regressing clock refuses latency underflow");

    constexpr auto lo = std::numeric_limits<std::int64_t>::min();
    constexpr auto hi = std::numeric_limits<std::int64_t>::max();
    Tracker coordinates(17);
    const auto low = add(coordinates, {lo, lo, 2, 2});
    const auto high = add(coordinates, {hi - 1, hi - 1, 2, 2});
    std::array<std::array<std::int64_t, 2>, 8> positions{};
    std::size_t index = 0;
    require(coordinates.advance(0, 12, [&](std::int64_t x, std::int64_t y) { positions[index++] = {x, y}; return wall; }) == 12, "extreme endpoints scan");
    require(index == 8 && positions[0] == std::array{lo, lo} && positions[3] == std::array{lo + 1, lo + 1} && positions[7] == std::array{hi, hi}, "exact signed endpoint coordinates");
    require(snapshot(coordinates, low).classification == DiscoveryClass::Uniform && snapshot(coordinates, high).classification == DiscoveryClass::Uniform, "extreme bounds valid");
    DiscoveryHandle refused;
    for (const auto bounds : {DiscoveryBounds{hi, 0, 2, 1}, DiscoveryBounds{0, hi, 1, 2},
             DiscoveryBounds{0, 0, 0, 1}, DiscoveryBounds{0, 0, 1, 0},
             DiscoveryBounds{0, 0, std::numeric_limits<std::uint32_t>::max(), std::numeric_limits<std::uint32_t>::max()}})
        require(coordinates.register_block(bounds, quiet(), 0, refused) == DiscoveryOutcome::Invalid, "bad/overflow/oversized bounds refused");
}
void competing_dirty_blocks_make_progress() {
    SettledDiscovery<2, 4> tracker(18);
    const auto churn = add(tracker);
    const auto quiet_block = add(tracker, {5, 5, 2, 2});
    for (std::uint64_t tick = 0; tick < 16; ++tick) {
        require(tracker.dirty(churn, tick) == DiscoveryOutcome::Accepted, "churning head invalidates");
        require(tracker.advance(tick, 3, [](auto, auto) { return wall; }) <= 3, "fairness keeps bounded work");
    }
    require(snapshot(tracker, quiet_block).classification == DiscoveryClass::Uniform, "churning first block must not starve unaffected queued block");
}
void supplied_signal_world_observer_is_neutral() {
    for (const auto workers : {1U, 4U}) {
        cybersand::WorldConfig config;
        config.worker_threads = workers;
        config.parallel_job_threshold = 1;
        cybersand::World control(config), observed(config);
        for (auto* world : {&control, &observed}) {
            world->reserve_region({0, 0, 256, 128});
            for (int x = 0; x < 256; ++x) world->set(x, 63, cybersand::Material::Wall);
            for (int x = 0; x < 96; ++x) world->set(x + 16, 12, cybersand::Material::Sand);
            for (int x = 0; x < 96; ++x) world->set(x + 136, 24, cybersand::Material::Water);
        }
        SettledDiscovery<1, 32> tracker(20 + workers);
        const auto handle = add(tracker, {0, 63, 32, 1});
        for (std::uint64_t tick = 0; tick < 24; ++tick) {
            const auto control_stats = control.tick();
            const auto observed_stats = observed.tick();
            require(control.state_hash() == observed.state_hash(), "paired World initial exact parity");
            require(tracker.dirty(handle, tick) == DiscoveryOutcome::Accepted, "fixture supplies conservative mutation signal");
            require(tracker.advance(tick, 34, [&](std::int64_t x, std::int64_t y) {
                return DiscoveryCell{static_cast<std::uint8_t>(observed.stored_material(x, y)),
                    observed.stored_state_a(x, y), observed.stored_state_b(x, y), observed.temperature(x, y),
                    observed.transient_obstacle_at(x, y) != 0};
            }) == 34, "bounded reader attached to owner-serialized World");
            require(control.state_hash() == observed.state_hash() && control.content_hash() == observed.content_hash(), "observer cannot change authoritative World hash");
            require(control_stats.visited_cells == observed_stats.visited_cells && control_stats.moved_cells == observed_stats.moved_cells &&
                control_stats.scheduled_cores == observed_stats.scheduled_cores && control_stats.active_blocks_after == observed_stats.active_blocks_after &&
                control.hard_surface_revision() == observed.hard_surface_revision() && control.dirty_chunk_count() == observed.dirty_chunk_count(), "observer cannot change scheduler/dirty/collision witnesses");
        }
    }
}
} // namespace
int main() {
    try {
        work_budget_and_immutable_results();
        aba_and_exact_classification();
        signal_gates_and_capacity();
        exhaustion_failure_and_coordinates();
        competing_dirty_blocks_make_progress();
        supplied_signal_world_observer_is_neutral();
        std::cout << "PASS settled discovery: exact work bounds, partial/ABA/tuple/signal/capacity/failure/coordinate/fairness tests; paired observer World neutrality workers1/4\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL settled discovery: " << error.what() << '\n';
        return 1;
    }
}
