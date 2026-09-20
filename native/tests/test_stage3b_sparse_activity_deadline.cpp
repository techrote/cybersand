#include "cybersand/world.hpp"

#include <cstdint>
#include <iostream>
#include <limits>
#include <optional>
#include <stdexcept>
#include <vector>

namespace {
using namespace cybersand;
using namespace cybersand::soliding;

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

DiscoverySignals quiet_signals() {
    DiscoverySignals signals{};
    signals.witness_complete = true;
    signals.healthy = true;
    signals.included = true;
    return signals;
}

DiscoveryParentKey parent_key(std::uint64_t incarnation, std::int64_t chunk_x) {
    return {incarnation, 0, chunk_x, 0, 0};
}

DiscoveryTileKey tile_key(std::uint64_t incarnation, std::int64_t chunk_x) {
    return {incarnation, 0, chunk_x, 0, 0, 0, 0};
}

void register_parent(SettledWorldDiscoveryCoordinator& coordinator,
                     std::uint64_t incarnation, std::int64_t chunk_x,
                     std::uint64_t deadline_due = 0) {
    require(coordinator.register_tile(
                tile_key(incarnation, chunk_x),
                {chunk_x, 0, 1, 1}, 20, quiet_signals(), 1) ==
                DiscoveryOutcome::Accepted,
            "represented deadline parent tile registers");
    require(coordinator.register_activity_parent(
                parent_key(incarnation, chunk_x), false, deadline_due) ==
                DiscoveryOutcome::Accepted,
            "represented deadline parent state registers");
}

WorldConfig tracked_config(std::uint32_t workers = 1) {
    WorldConfig config{};
    config.chunk_size = 8;
    config.activity_block_size = 8;
    config.scheduling_core_size = 8;
    config.sleep_after_quiet_ticks = 1;
    config.ambient_temperature = 20;
    config.initial_chunk_reserve = 4;
    config.maximum_chunk_count = 32;
    config.active_chunk_capacity = 32;
    config.active_core_capacity = 128;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    config.settled_discovery_enabled = true;
    config.settled_discovery_tile_capacity = 64;
    return config;
}

void service(World& world, std::size_t limit = 1'000'000) {
    std::size_t work = 0;
    while (world.settled_discovery_pending() != 0 && work < limit) {
        const auto used = world.advance_settled_discovery(17);
        require(used != 0 && used <= 17,
                "pending sparse discovery remains bounded and serviceable");
        work += used;
    }
    require(work < limit, "sparse discovery service terminates");
}

WorldDiscoveryTileSnapshot tile_at(const World& world, std::int64_t x, std::int64_t y) {
    for (std::size_t index = 0; index < world.settled_discovery_tile_count(); ++index) {
        const auto tile = world.settled_discovery_tile(index);
        require(tile.has_value(), "registered discovery tile remains available");
        const auto& bounds = tile->summary.bounds;
        if (bounds.x <= x &&
            x <= bounds.x + static_cast<std::int64_t>(bounds.width - 1U) &&
            bounds.y <= y &&
            y <= bounds.y + static_cast<std::int64_t>(bounds.height - 1U)) return *tile;
    }
    throw std::runtime_error("requested sparse discovery tile not found");
}

void bounded_deadline_lifecycle_and_canonical_order() {
    constexpr std::uint64_t incarnation = 6201;
    SettledWorldDiscoveryCoordinator coordinator(incarnation, 4, false);
    register_parent(coordinator, incarnation, 5);
    register_parent(coordinator, incarnation, 1);
    register_parent(coordinator, incarnation, 3);
    register_parent(coordinator, incarnation, 7);

    const auto high = parent_key(incarnation, 5);
    const auto low = parent_key(incarnation, 1);
    require(coordinator.schedule_deadline(high, 40) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_heap_size() == 1,
            "deadline insertion creates exactly one indexed heap entry");
    const auto first = coordinator.deadline_state(high);
    require(first.has_value() && first->due_tick == 40 && first->generation != 0,
            "inserted deadline exposes exact due tick and nonzero generation");

    require(coordinator.schedule_deadline(high, 20) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_heap_size() == 1,
            "earlier replacement updates in place without a stale heap entry");
    const auto replaced = coordinator.deadline_state(high);
    require(replaced.has_value() && replaced->due_tick == 20 &&
                replaced->generation > first->generation,
            "earlier replacement advances generation and replaces due tick");
    require(coordinator.schedule_deadline(high, 30) == DiscoveryOutcome::Unchanged &&
                coordinator.deadline_heap_size() == 1 &&
                coordinator.deadline_state(high)->due_tick == 20,
            "later request cannot supersede an earlier current obligation");

    const auto replacement_generation = replaced->generation;
    require(coordinator.cancel_deadline(high) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_heap_size() == 0 &&
                coordinator.deadline_state(high)->due_tick == 0,
            "deadline cancellation removes the indexed entry in place");
    require(coordinator.schedule_deadline(high, 50) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_state(high)->generation > replacement_generation,
            "post-cancellation deadline cannot alias the obsolete generation");
    require(coordinator.schedule_deadline(low, 50) == DiscoveryOutcome::Accepted,
            "second equal-due deadline inserts");
    require(coordinator.deadline_heap_size() == 2,
            "equal-due deadlines retain one entry per parent");
    auto next = coordinator.next_deadline();
    require(next.has_value() && next->due_tick == 50 && next->parent == low,
            "equal-due ordering is canonical by parent identity, not insertion order");

    require(coordinator.mark_deadline_ready(low) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_heap_size() == 1 &&
                coordinator.deadline_ready_count() == 1,
            "ready deadline leaves the due heap without a tombstone");
    require(coordinator.consume_deadline(low) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_ready_count() == 0 &&
                coordinator.deadline_state(low)->due_tick == 0,
            "consumption clears the exact ready obligation");
    next = coordinator.next_deadline();
    require(next.has_value() && next->parent == high && next->due_tick == 50,
            "obsolete equal-due entry cannot resurrect after consumption");

    require(coordinator.cancel_deadline(high) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_heap_size() == 0,
            "final cancellation leaves no latent heap state");
    const auto metrics = coordinator.producer_metrics();
    require(metrics.deadline_insertions >= 3 &&
                metrics.deadline_replacements == 1 &&
                metrics.deadline_cancellations == 2 &&
                metrics.deadline_consumptions == 1 &&
                metrics.deadline_heap_high_water == 2,
            "deadline lifecycle metrics account for bounded in-place operations");
}

void bounded_storage_retains_every_obligation() {
    constexpr std::uint64_t incarnation = 6202;
    constexpr std::size_t capacity = 8;
    SettledWorldDiscoveryCoordinator coordinator(incarnation, capacity, false);
    for (std::size_t index = 0; index < capacity; ++index) {
        register_parent(coordinator, incarnation, static_cast<std::int64_t>(index),
                        100 + index);
    }
    require(coordinator.activity_parent_count() == capacity &&
                coordinator.deadline_heap_size() == capacity,
            "exact-capacity parent/deadline storage retains every obligation");

    for (std::size_t index = 0; index < capacity; ++index) {
        const auto next = coordinator.next_deadline();
        require(next.has_value() && next->due_tick == 100 + index &&
                    next->parent == parent_key(incarnation, static_cast<std::int64_t>(index)),
                "bounded heap yields every obligation in canonical due order");
        require(coordinator.mark_deadline_ready(next->parent) == DiscoveryOutcome::Accepted,
                "bounded obligation becomes ready");
        require(coordinator.consume_deadline(next->parent) == DiscoveryOutcome::Accepted,
                "bounded obligation consumes without stale state");
    }
    require(coordinator.deadline_heap_size() == 0 &&
                coordinator.deadline_ready_count() == 0,
            "drained bounded storage contains no stale deadline entries");
}

void parked_overdue_state_and_reentry_consumption() {
    constexpr std::uint64_t incarnation = 6203;
    SettledWorldDiscoveryCoordinator coordinator(incarnation, 2, false);
    register_parent(coordinator, incarnation, 0, 12);
    const auto parent = parent_key(incarnation, 0);
    require(coordinator.park_deadline(parent) == DiscoveryOutcome::Accepted &&
                coordinator.deadline_heap_size() == 0,
            "excluded overdue obligation parks outside the due heap");
    const auto parked = coordinator.deadline_state(parent);
    require(parked.has_value() && parked->parked && !parked->ready &&
                parked->due_tick == 12,
            "parking retains the exact overdue due tick");
    require(coordinator.consume_deadline(parent) == DiscoveryOutcome::Accepted,
            "re-entry consumes the retained overdue obligation");
    const auto cleared = coordinator.deadline_state(parent);
    require(cleared.has_value() && !cleared->parked && !cleared->ready &&
                cleared->due_tick == 0,
            "re-entry leaves no obsolete parked obligation");
    const auto metrics = coordinator.producer_metrics();
    require(metrics.deadline_parks == 1 && metrics.deadline_reentries == 1 &&
                metrics.deadline_consumptions == 1,
            "parking and re-entry are explicitly accounted");
}

void deadline_generation_exhaustion_fail_closes_observation() {
    constexpr std::uint64_t incarnation = 6204;
    testing::set_next_deadline_generation_limit(2);
    SettledWorldDiscoveryCoordinator coordinator(incarnation, 1, false);
    register_parent(coordinator, incarnation, 0);
    const auto parent = parent_key(incarnation, 0);
    require(coordinator.schedule_deadline(parent, 30) == DiscoveryOutcome::Accepted,
            "generation fixture inserts first deadline");
    require(coordinator.schedule_deadline(parent, 20) == DiscoveryOutcome::Accepted,
            "generation fixture performs one earlier replacement");
    const auto before = coordinator.deadline_state(parent);
    require(before.has_value() && before->generation == 2,
            "generation fixture reaches the configured terminal generation");
    require(coordinator.cancel_deadline(parent) == DiscoveryOutcome::Halted &&
                coordinator.halted() == DiscoveryHalt::ProducerFailure,
            "generation exhaustion fail-closes observation rather than wrapping");
    const auto after = coordinator.deadline_state(parent);
    require(after.has_value() && after->generation == 2 && after->due_tick == 20 &&
                coordinator.producer_metrics().deadline_generation_exhaustions == 1,
            "generation exhaustion preserves the last unambiguous obligation");
}

void quiet_world_has_no_resident_signal_polling() {
    auto config = tracked_config();
    config.chunk_size = 32;
    config.activity_block_size = 32;
    config.scheduling_core_size = 32;
    World world(config);
    world.reserve_region({0, 0, 96, 32});
    service(world);
    const auto before = world.settled_discovery_producer_metrics();
    const auto revisions = [&world] {
        std::vector<std::uint64_t> values;
        for (std::size_t index = 0; index < world.settled_discovery_tile_count(); ++index) {
            const auto tile = world.settled_discovery_tile(index);
            require(tile.has_value(), "quiet represented tile remains available");
            values.push_back(tile->summary.revision);
        }
        return values;
    }();

    for (int tick = 0; tick < 300; ++tick) {
        const auto stats = world.tick();
        require(stats.scheduled_cores == 0 && stats.active_chunks_after == 0,
                "quiet observer fixture unexpectedly scheduled simulation work");
    }
    const auto after = world.settled_discovery_producer_metrics();
    require(after.signal_observations == before.signal_observations,
            "quiet ticks performed resident-wide activity/deadline signal observations");
    require(after.activity_witnesses == before.activity_witnesses &&
                after.deadline_insertions == before.deadline_insertions,
            "quiet ticks manufactured sparse activity/deadline witnesses");
    for (std::size_t index = 0; index < revisions.size(); ++index) {
        const auto tile = world.settled_discovery_tile(index);
        require(tile.has_value() && tile->summary.revision == revisions[index],
                "quiet maintenance changed an unchanged discovery revision");
    }
}

void ordinary_sleep_wake_and_no_write_keep_active() {
    World sleep(tracked_config());
    sleep.reserve_region({0, 0, 8, 8});
    sleep.set(0, 0, Material::Wall);
    service(sleep);
    require(tile_at(sleep, 0, 0).signals.active,
            "direct write wakes the represented activity parent");
    (void)sleep.tick();
    require(!tile_at(sleep, 0, 0).signals.active,
            "ordinary quiet aging sparsely records the sleep transition");
    sleep.set(1, 0, Material::Wall);
    require(tile_at(sleep, 0, 0).signals.active,
            "ordinary direct edit sparsely records the wake transition");

    for (const std::uint32_t workers : {1U, 4U}) {
        World active(tracked_config(workers));
        active.reserve_region({0, 0, 8, 8});
        require(active.set_cell_state(0, 0, Material::Wood, 0, 5),
                "no-write combustible fixture accepted");
        service(active);
        const auto before = active.settled_discovery_producer_metrics().activity_witnesses;
        bool saw_no_write = false;
        for (int attempt = 0; attempt < 12 && !saw_no_write; ++attempt) {
            const auto hash = active.content_hash();
            (void)active.tick();
            if (active.content_hash() == hash) {
                saw_no_write = true;
                require(tile_at(active, 0, 0).signals.active,
                        "no-write keep-active witness remains blocking");
            }
        }
        require(saw_no_write,
                "no-write activity fixture reached no deterministic keep-active tick");
        require(active.settled_discovery_producer_metrics().activity_witnesses > before,
                "no-write keep-active path emitted no sparse activity witness");
    }
}

void pending_payload_no_write_signal_coalesces_revision() {
    World world(tracked_config(4));
    world.reserve_region({0, 0, 8, 8});
    service(world);
    require(world.set_cell_state(0, 0, Material::Wood, 0, 5),
            "pending-payload combustible fixture accepted");

    bool saw_no_write = false;
    std::uint64_t sparse_revision = 0;
    for (int attempt = 0; attempt < 12 && !saw_no_write; ++attempt) {
        const auto before_hash = world.content_hash();
        const auto before_tile = tile_at(world, 0, 0);
        (void)world.tick();
        if (world.content_hash() == before_hash) {
            saw_no_write = true;
            const auto after_tile = tile_at(world, 0, 0);
            require(after_tile.signals.active,
                    "pending #61 payload work dropped the no-write keep-active witness");
            require(after_tile.summary.revision == before_tile.summary.revision,
                    "sparse signal reconciliation manufactured a second payload revision");
            sparse_revision = after_tile.summary.revision;
        }
    }
    require(saw_no_write,
            "pending-payload fixture reached no deterministic no-write keep-active tick");

    service(world);
    const auto serviced = tile_at(world, 0, 0);
    require(serviced.summary.revision == sparse_revision,
            "servicing the pending payload resurrected a coalesced signal revision");
    require(serviced.signals.active,
            "payload service lost the coalesced blocking activity state");
}

void seed_deadline_fixture(World& world) {
    for (int x = -2; x <= 2; ++x)
        for (int y = -2; y <= 3; ++y) world.set(x, y, Material::Wall);
    world.set(0, 0, Material::Mercury);
    world.set(0, 1, Material::Sand);
}

void future_deadline_parking_reentry_and_observer_neutrality() {
    auto config = tracked_config();
    config.chunk_size = 32;
    config.activity_block_size = 32;
    config.scheduling_core_size = 32;
    config.interaction_policy.mercury_exchange_period = 30;
    World world(config);
    seed_deadline_fixture(world);
    service(world);

    (void)world.tick();
    const auto after_schedule = world.settled_discovery_producer_metrics();
    require(after_schedule.deadline_insertions != 0,
            "future interaction created no sparse deadline obligation");
    for (int tick = 2; tick < 30; ++tick) (void)world.tick();
    require(world.active_chunk_count() == 0 &&
                tile_at(world, 0, 0).signals.active,
            "future sleeping deadline stopped blocking before it was due");

    world.set_simulation_region(RectI64{768, 768, 32, 32});
    for (int tick = 30; tick <= 35; ++tick) (void)world.tick();
    const auto parked = world.settled_discovery_producer_metrics();
    require(parked.deadline_parks != 0 &&
                world.get(0, 0) == Material::Mercury,
            "excluded overdue deadline was not parked or exclusion advanced material");

    world.set_simulation_region(std::nullopt);
    (void)world.tick();
    const auto reentered = world.settled_discovery_producer_metrics();
    require(reentered.deadline_reentries != 0 &&
                reentered.deadline_consumptions != 0,
            "re-entry failed to reconcile and consume the already-due obligation");
    require(tile_at(world, 0, 0).signals.included,
            "re-entry failed to restore #63-owned inclusion state");

    auto observed_config = config;
    auto control_config = config;
    control_config.settled_discovery_enabled = false;
    World observed(observed_config);
    World control(control_config);
    seed_deadline_fixture(observed);
    seed_deadline_fixture(control);
    for (int tick = 0; tick < 70; ++tick) {
        const auto a = observed.tick();
        const auto b = control.tick();
        require(observed.content_hash() == control.content_hash() &&
                    a.visited_cells == b.visited_cells &&
                    a.moved_cells == b.moved_cells &&
                    a.scheduled_cores == b.scheduled_cores,
                "observer-enabled sparse state changed authoritative behavior");
    }
}

void workers_one_four_sparse_state_parity() {
    auto one_config = tracked_config(1);
    auto four_config = tracked_config(4);
    for (auto* config : {&one_config, &four_config}) {
        config->chunk_size = 32;
        config->activity_block_size = 32;
        config->scheduling_core_size = 32;
        config->interaction_policy.mercury_exchange_period = 30;
    }
    World one(one_config);
    World four(four_config);
    seed_deadline_fixture(one);
    seed_deadline_fixture(four);
    service(one);
    service(four);

    for (int tick = 0; tick < 70; ++tick) {
        (void)one.tick();
        (void)four.tick();
        require(one.content_hash() == four.content_hash(),
                "workers 1/4 changed authoritative deadline behavior");
        require(one.settled_discovery_tile_count() == four.settled_discovery_tile_count(),
                "workers 1/4 changed represented coverage");
        for (std::size_t index = 0; index < one.settled_discovery_tile_count(); ++index) {
            const auto a = one.settled_discovery_tile(index);
            const auto b = four.settled_discovery_tile(index);
            require(a.has_value() && b.has_value() &&
                        a->summary.bounds == b->summary.bounds &&
                        a->signals == b->signals,
                    "workers 1/4 changed sparse activity/deadline signals");
        }
    }
}

} // namespace

int main() {
    try {
        bounded_deadline_lifecycle_and_canonical_order();
        bounded_storage_retains_every_obligation();
        parked_overdue_state_and_reentry_consumption();
        deadline_generation_exhaustion_fail_closes_observation();
        quiet_world_has_no_resident_signal_polling();
        ordinary_sleep_wake_and_no_write_keep_active();
        pending_payload_no_write_signal_coalesces_revision();
        future_deadline_parking_reentry_and_observer_neutrality();
        workers_one_four_sparse_state_parity();
        std::cout << "Stage-3B sparse activity/deadline tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Stage-3B sparse activity/deadline test failure: "
                  << error.what() << '\n';
        return 1;
    }
}
