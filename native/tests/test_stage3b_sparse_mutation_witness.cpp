#include "cybersand/world.hpp"

#include <cstdint>
#include <iostream>
#include <optional>
#include <stdexcept>

namespace cybersand {
class PrecisionProbe {
public:
    static std::uint16_t transfer(World& world, std::int64_t from_x, std::int64_t from_y,
                                  std::int64_t to_x, std::int64_t to_y,
                                  std::uint16_t requested) {
        return world.transfer_water(from_x, from_y, to_x, to_y, requested, nullptr);
    }
};
} // namespace cybersand

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
    signals.active = false;
    return signals;
}

DiscoveryCell empty_cell(const void*, std::int64_t, std::int64_t) {
    return {0, 0, 0, 20, false};
}

DiscoverySignals quiet_signal_reader(
    const void*, DiscoveryTileKey, DiscoveryBounds, DiscoverySignals previous) {
    auto signals = quiet_signals();
    signals.occupied = previous.occupied;
    return signals;
}

DiscoverySignals throwing_signal_reader(
    const void*, DiscoveryTileKey, DiscoveryBounds, DiscoverySignals) {
    throw std::runtime_error("injected sparse signal source failure");
}

WorldConfig tracked_config(std::uint32_t workers = 1) {
    WorldConfig config{};
    config.chunk_size = 8;
    config.activity_block_size = 8;
    config.scheduling_core_size = 8;
    config.sleep_after_quiet_ticks = 1;
    config.ambient_temperature = 20;
    config.initial_chunk_reserve = 32;
    config.maximum_chunk_count = 64;
    config.active_chunk_capacity = 64;
    config.active_core_capacity = 256;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    config.settled_discovery_enabled = true;
    config.settled_discovery_tile_capacity = 256;
    return config;
}

WorldDiscoveryTileSnapshot tile_at(const World& world, std::int64_t x, std::int64_t y) {
    for (std::size_t index = 0; index < world.settled_discovery_tile_count(); ++index) {
        const auto tile = world.settled_discovery_tile(index);
        require(tile.has_value(), "registered tile snapshot available");
        const auto& bounds = tile->summary.bounds;
        const auto max_x = bounds.x + static_cast<std::int64_t>(bounds.width - 1U);
        const auto max_y = bounds.y + static_cast<std::int64_t>(bounds.height - 1U);
        if (bounds.x <= x && x <= max_x && bounds.y <= y && y <= max_y) return *tile;
    }
    throw std::runtime_error("requested discovery tile not found");
}

void service(World& world, std::size_t limit = 2'000'000) {
    std::size_t work = 0;
    while (world.settled_discovery_pending() != 0 && work < limit) {
        const auto used = world.advance_settled_discovery(257);
        require(used != 0 && used <= 257, "sparse discovery service remains live and bounded");
        work += used;
    }
    require(work < limit, "sparse discovery service terminates");
}

void batched_same_barrier_restore_preserves_revision() {
    constexpr std::uint64_t incarnation = 61001;
    SettledWorldDiscoveryCoordinator coordinator(incarnation, 4, false);
    const DiscoveryTileKey key{incarnation, 0, 0, 0, 0, 0, 0};
    require(coordinator.register_tile(key, {0, 0, 1, 1}, 20, quiet_signals(), 1) ==
                DiscoveryOutcome::Accepted,
            "coordinator tile registration accepted");
    while (coordinator.pending() != 0)
        require(coordinator.advance(1, 16, nullptr, &empty_cell) != 0,
                "initial coordinator scan drains");

    const auto handle = coordinator.find_handle(key);
    require(handle.has_value(), "coordinator handle available");
    const auto before = coordinator.tile(*handle);
    require(before.has_value(), "coordinator snapshot available");

    // A worker report may deduplicate change->restore to one tile record. The
    // mutation_count is the exact history witness carried through the barrier.
    require(coordinator.notify_payload(*handle, ProducerReason::WorkerMutation, 2, 2) ==
                DiscoveryOutcome::Accepted,
            "same-barrier change/restore report accepted");
    require(coordinator.notify_payload(*handle, ProducerReason::WorkerMutation, 2, 1) ==
                DiscoveryOutcome::Accepted,
            "later same-barrier write coalesces into the same deferred tile");
    const auto dirty = coordinator.tile(*handle);
    require(dirty.has_value() &&
            dirty->summary.revision == before->summary.revision + 3 &&
            dirty->summary.classification == DiscoveryClass::Invalid,
            "coalescing preserves all mutation witnesses rather than final tuple only");
    require(coordinator.pending_payload_work() == 1,
            "one deferred tile service entry represents coalesced mutations");
    const auto metrics = coordinator.producer_metrics();
    require(metrics.payload_mutations == 3 &&
            metrics.payload_work_enqueued == 1 &&
            metrics.payload_work_coalesced == 1,
            "payload metrics expose exact mutation/coalescing counts");

    require(coordinator.advance(2, 1, nullptr, &empty_cell, &quiet_signal_reader) == 1 &&
            coordinator.pending_payload_work() == 0,
            "deferred signal refresh is charged as one sparse work unit");
    while (coordinator.pending() != 0)
        require(coordinator.advance(2, 16, nullptr, &empty_cell) != 0,
                "journal scan drains after sparse payload service");
}

void sparse_signal_source_failure_quarantines_observation() {
    constexpr std::uint64_t incarnation = 61002;
    SettledWorldDiscoveryCoordinator coordinator(incarnation, 2, false);
    const DiscoveryTileKey key{incarnation, 0, 0, 0, 0, 0, 0};
    require(coordinator.register_tile(key, {0, 0, 1, 1}, 20, quiet_signals(), 1) ==
                DiscoveryOutcome::Accepted,
            "source-failure tile registration accepted");
    while (coordinator.pending() != 0)
        require(coordinator.advance(1, 16, nullptr, &empty_cell) != 0,
                "source-failure initial scan drains");
    const auto handle = coordinator.find_handle(key);
    require(handle.has_value(), "source-failure handle available");
    require(coordinator.notify_payload(*handle, ProducerReason::DirectMutation, 2) ==
                DiscoveryOutcome::Accepted,
            "source-failure payload witness accepted");
    bool threw = false;
    try {
        (void)coordinator.advance(
            2, 1, nullptr, &empty_cell, &throwing_signal_reader);
    } catch (const std::runtime_error&) {
        threw = true;
    }
    require(threw && coordinator.halted() == DiscoveryHalt::SourceFailure &&
            !coordinator.tile(*handle).has_value(),
            "deferred signal source failure preserves #58 fail-closed semantics");
}

void direct_aba_exact_tuple_heat_and_locality() {
    World world(tracked_config());
    world.reserve_region({0, 0, 128, 8});
    service(world);
    const auto local_before = tile_at(world, 0, 0);
    const auto far_before = tile_at(world, 120, 0);
    const auto metrics_before = world.settled_discovery_producer_metrics();

    require(world.set_cell_state(0, 0, Material::Empty, 7, 9),
            "state-only mutation accepted");
    require(world.set_cell_state(0, 0, Material::Empty, 0, 0),
            "state-only restore accepted");
    world.set_temperature(0, 0, 300);
    world.set_temperature(0, 0, 20);
    (void)world.take_dirty_chunks();

    const auto local_dirty = tile_at(world, 0, 0);
    const auto far_after = tile_at(world, 120, 0);
    const auto metrics_after = world.settled_discovery_producer_metrics();
    require(local_dirty.summary.revision == local_before.summary.revision + 4,
            "direct state/heat ABA advances the independent witness once per mutation");
    require(local_dirty.summary.classification == DiscoveryClass::Invalid &&
            far_after.summary.revision == far_before.summary.revision,
            "direct mutation invalidates only its canonical tile");
    require(metrics_after.payload_mutations == metrics_before.payload_mutations + 4 &&
            metrics_after.signal_observations == metrics_before.signal_observations + 1 &&
            metrics_after.activity_transitions == metrics_before.activity_transitions + 1,
            "direct payload hook retains exact #61 witnesses plus one parent-local #62 activity transition");
    require(world.stored_state_a(0, 0) == 0 && world.stored_state_b(0, 0) == 0 &&
            world.temperature(0, 0) == 20,
            "authoritative exact tuple and heat restore independently of observation");
}

void movement_and_water_endpoints() {
    World world(tracked_config());
    world.reserve_region({0, 0, 24, 8});
    world.set(0, 0, Material::Wall);
    service(world);
    const auto source_before = tile_at(world, 0, 0);
    const auto destination_before = tile_at(world, 8, 0);
    require(world.relocate_stored_cell(0, 0, 8, 0),
            "stored movement accepted");
    require(tile_at(world, 0, 0).summary.revision > source_before.summary.revision &&
            tile_at(world, 8, 0).summary.revision > destination_before.summary.revision,
            "movement witnesses both source and destination");

    require(world.set_cell_state(0, 1, Material::Water, 200, 7),
            "Water source accepted");
    require(world.set_cell_state(8, 1, Material::Water, 100, 3),
            "Water destination accepted");
    service(world);
    const auto water_source = tile_at(world, 0, 1);
    const auto water_destination = tile_at(world, 8, 1);
    require(PrecisionProbe::transfer(world, 0, 1, 8, 1, 50) == 50,
            "Water transfer accepted");
    require(tile_at(world, 0, 1).summary.revision > water_source.summary.revision &&
            tile_at(world, 8, 1).summary.revision > water_destination.summary.revision &&
            world.liquid_mass(0, 1) == 150 && world.liquid_mass(8, 1) == 150,
            "Water transfer witnesses both exact payload endpoints");
}

void seed_worker_fixture(World& world) {
    world.reserve_region({-8, -8, 32, 24});
    for (std::int64_t x = -8; x < 24; ++x) world.set(x, 7, Material::Wall);
    world.set(0, 0, Material::Sand);
    require(world.set_cell_state(1, 0, Material::Water, 255, 2),
            "worker Water fixture accepted");
}

void worker_one_four_parity() {
    World single(tracked_config(1));
    World parallel(tracked_config(4));
    seed_worker_fixture(single);
    seed_worker_fixture(parallel);
    service(single);
    service(parallel);
    for (int tick = 0; tick < 12; ++tick) {
        (void)single.tick();
        (void)parallel.tick();
        require(single.content_hash() == parallel.content_hash(),
                "workers 1/4 retain authoritative parity");
    }
    require(single.settled_discovery_tile_count() == parallel.settled_discovery_tile_count(),
            "workers 1/4 retain discovery coverage");
    for (std::size_t i = 0; i < single.settled_discovery_tile_count(); ++i) {
        const auto a = single.settled_discovery_tile(i);
        const auto b = parallel.settled_discovery_tile(i);
        require(a.has_value() && b.has_value() &&
                a->summary.bounds == b->summary.bounds &&
                a->summary.revision == b->summary.revision &&
                a->signals == b->signals,
                "deterministic barrier reduction makes workers 1/4 witness-equivalent");
    }
    require(single.settled_discovery_producer_metrics().worker_report_records != 0 &&
            parallel.settled_discovery_producer_metrics().worker_report_records != 0,
            "worker fixture exercised sparse native mutation reports");
}

void report_saturation_fences_observation_only() {
    auto observed_config = tracked_config(4);
    observed_config.chunk_size = 16;
    observed_config.activity_block_size = 1;
    observed_config.scheduling_core_size = 16;
    observed_config.maximum_chunk_count = 64;
    observed_config.active_chunk_capacity = 64;
    observed_config.active_core_capacity = 4'096;
    observed_config.settled_discovery_tile_capacity = 4'096;
    auto control_config = observed_config;
    control_config.settled_discovery_enabled = false;

    World observed(observed_config);
    World control(control_config);
    observed.reserve_region({0, 0, 16, 16});
    control.reserve_region({0, 0, 16, 16});
    for (std::int64_t y = 0; y < 8; ++y) {
        for (std::int64_t x = 0; x < 16; ++x) {
            observed.set(x, y, Material::Sand);
            control.set(x, y, Material::Sand);
        }
    }
    service(observed);

    const auto observed_stats = observed.tick();
    const auto control_stats = control.tick();
    require(!observed.has_failed() &&
            observed.content_hash() == control.content_hash() &&
            observed_stats.visited_cells == control_stats.visited_cells &&
            observed_stats.moved_cells == control_stats.moved_cells,
            "report saturation never changes or fails authoritative simulation");

    const auto metrics = observed.settled_discovery_producer_metrics();
    require(metrics.worker_report_overflows != 0 &&
            metrics.observation_fences != 0 &&
            metrics.global_fences != 0 &&
            observed.settled_discovery_halted() == DiscoveryHalt::ProducerFailure,
            "lost worker report capacity fail-closes observation instead of publishing stale data");
    require(!observed.settled_discovery_tile(0).has_value() &&
            observed.advance_settled_discovery(100) == 0,
            "fenced observation exposes no apparently current tile");
}

} // namespace

int main() {
    try {
        batched_same_barrier_restore_preserves_revision();
        sparse_signal_source_failure_quarantines_observation();
        direct_aba_exact_tuple_heat_and_locality();
        movement_and_water_endpoints();
        worker_one_four_parity();
        report_saturation_fences_observation_only();
        std::cout << "Stage-3B sparse mutation/witness tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Stage-3B sparse mutation/witness test failure: "
                  << error.what() << '\n';
        return 1;
    }
}
