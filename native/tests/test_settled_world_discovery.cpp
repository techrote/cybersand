#include "cybersand/world.hpp"

#include <cstdint>
#include <iostream>
#include <limits>
#include <new>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>

namespace cybersand {
class PrecisionProbe {
public:
    static std::uint16_t transfer(World& world, std::int64_t from_x, std::int64_t from_y,
                                  std::int64_t to_x, std::int64_t to_y,
                                  std::uint16_t requested) {
        return world.transfer_water(from_x, from_y, to_x, to_y, requested, nullptr);
    }
    static std::uint8_t coherence(const World& world, std::int64_t x, std::int64_t y) {
        return world.state_b(x, y);
    }
};
} // namespace cybersand

namespace {
using namespace cybersand;
using namespace cybersand::soliding;

#if defined(__GNUC__) || defined(__clang__)
#define CYBERSAND_TEST_NOINLINE __attribute__((noinline))
#else
#define CYBERSAND_TEST_NOINLINE
#endif

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

template<class Test>
void run_named(const char* name, Test&& test) {
    try {
        test();
    } catch (...) {
        std::cerr << "while running " << name << '\n';
        throw;
    }
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
        require(used <= 17, "World discovery respects service budget");
        require(used != 0, "pending World discovery remains serviceable");
        work += used;
    }
    require(work < limit, "World discovery service terminates");
}

void service_regions(World& world, std::size_t limit = 1'000'000) {
    std::size_t work = 0;
    while (work < limit) {
        const auto used = world.advance_settled_regions(8192);
        require(used <= 8192, "World region traversal respects service budget");
        work += used;
        if (used == 0) break;
    }
    require(work < limit, "World region service terminates");
}

WorldDiscoveryTileSnapshot tile_at(const World& world, std::int64_t x, std::int64_t y) {
    for (std::size_t index = 0; index < world.settled_discovery_tile_count(); ++index) {
        const auto tile = world.settled_discovery_tile(index);
        if (!tile.has_value()) {
            throw std::runtime_error(
                "registered tile snapshot unavailable while locating (" +
                std::to_string(x) + "," + std::to_string(y) + "); halt=" +
                std::to_string(static_cast<unsigned>(
                    world.settled_discovery_halted())));
        }
        const auto& bounds = tile->summary.bounds;
        if (bounds.x <= x && x <= bounds.x + static_cast<std::int64_t>(bounds.width - 1U) &&
            bounds.y <= y && y <= bounds.y + static_cast<std::int64_t>(bounds.height - 1U)) return *tile;
    }
    throw std::runtime_error(
        "requested discovery tile not found at (" + std::to_string(x) + "," +
        std::to_string(y) + ")");
}

CYBERSAND_TEST_NOINLINE void direct_aba_exact_tuple_and_render_independence() {
    auto config = tracked_config();
    World world(config);
    world.reserve_region({0, 0, 8, 8});
    service(world);
    const auto initial = tile_at(world, 0, 0);
    require(initial.summary.classification == DiscoveryClass::Empty &&
            initial.summary.uniform.temperature == 20,
            "reserved canonical Empty tile classified exactly");

    require(world.set_cell_state(0, 0, Material::Empty, 7, 9), "state-only mutation accepted");
    require(world.set_cell_state(0, 0, Material::Empty, 0, 0), "state-only restore accepted");
    (void)world.take_dirty_chunks();
    const auto state_aba = tile_at(world, 0, 0);
    require(state_aba.summary.revision >= initial.summary.revision + 2 &&
            state_aba.summary.classification == DiscoveryClass::Invalid,
            "state ABA remains invalid despite render-dirty consumption");

    world.set_temperature(0, 0, 300);
    world.set_temperature(0, 0, 20);
    const auto heat_aba = tile_at(world, 0, 0);
    require(heat_aba.summary.revision >= state_aba.summary.revision + 2,
            "hot Empty ABA has independent witnesses");
    world.set(0, 0, Material::Wall);
    world.set(0, 0, Material::Empty);
    const auto material_aba = tile_at(world, 0, 0);
    require(material_aba.summary.revision >= heat_aba.summary.revision + 2,
            "material ABA has independent witnesses");
    (void)world.tick();
    service(world);
    const auto restored = tile_at(world, 0, 0);
    require(restored.summary.classification == DiscoveryClass::Empty &&
            restored.summary.uniform == DiscoveryCell{0, 0, 0, 20, false},
            "ABA requires and receives a complete fresh exact scan");
}

CYBERSAND_TEST_NOINLINE void canonical_geometry_registration_and_capacity() {
    auto config = tracked_config();
    config.chunk_size = 64;
    config.activity_block_size = 64;
    config.scheduling_core_size = 64;
    World subdivided(config);
    subdivided.reserve_region({0, 0, 64, 64});
    require(subdivided.settled_discovery_tile_count() == 4,
            "64-cell activity block is canonically split into four 32x32 tiles");
    for (std::size_t index = 0; index < 4; ++index) {
        const auto tile = subdivided.settled_discovery_tile(index);
        require(tile.has_value() && tile->summary.bounds.width == 32 &&
                tile->summary.bounds.height == 32,
                "canonical subtile bounds are 32x32");
    }

    config = tracked_config();
    config.settled_discovery_tile_capacity = 1;
    config.settled_region_connectivity_enabled = true;
    World constrained(config);
    constrained.reserve_region({0, 0, 16, 8});
    require(constrained.chunk_count() == 2 && constrained.settled_discovery_capacity_blocked(),
            "tracking capacity refusal leaves authoritative chunk reservation intact");
    require(constrained.settled_discovery_tile(0) == std::nullopt,
            "capacity-unrepresentable coverage exposes no stale usable snapshot");
    require(constrained.settled_region_count() == 0 &&
            constrained.settled_region_refusal() == RegionRefusal::TileCapacity &&
            constrained.settled_discovery_coverage_state(0, 0) ==
                DiscoveryCoverageState::CapacityRefused,
            "producer capacity refusal quarantines connectivity without partial publication");
}

CYBERSAND_TEST_NOINLINE void movement_mask_event_and_far_locality() {
    World world(tracked_config());
    world.reserve_region({0, 0, 24, 8});
    service(world);
    world.set(0, 0, Material::Wall);
    (void)world.tick();
    service(world);
    const auto source_before = tile_at(world, 0, 0);
    const auto destination_before = tile_at(world, 8, 0);
    const auto far_before = tile_at(world, 16, 0);
    require(world.relocate_stored_cell(0, 0, 8, 0), "cross-tile stored-cell move accepted");
    const auto source_after = tile_at(world, 0, 0);
    const auto destination_after = tile_at(world, 8, 0);
    require(source_after.summary.revision > source_before.summary.revision &&
            destination_after.summary.revision > destination_before.summary.revision,
            "movement invalidates both source and destination tiles");

    world.configure_transient_obstacles({0, 0, 8, 8});
    require(world.set_transient_obstacle(1, 1, 1), "transient mask add accepted");
    const auto masked = tile_at(world, 1, 1);
    require(masked.signals.occupied && masked.summary.classification == DiscoveryClass::Invalid,
            "mask add immediately blocks its local tile");
    world.clear_transient_obstacles();
    const auto cleared = tile_at(world, 1, 1);
    require(!cleared.signals.occupied && cleared.summary.revision > masked.summary.revision,
            "mask clear ABA produces a new local revision");
    require(tile_at(world, 16, 0).summary.revision == far_before.summary.revision,
            "far mask changes do not invalidate unrelated tiles");
    const auto before_reconfigure = cleared.summary.revision;
    world.configure_transient_obstacles({0, 0, 4, 4});
    world.configure_transient_obstacles({2, 2, 4, 4});
    require(tile_at(world, 1, 1).summary.revision > before_reconfigure &&
            tile_at(world, 16, 0).summary.revision == far_before.summary.revision,
            "empty mask reconfiguration is witnessed locally without far reset");

    require(world.queue_explosion(8, 2, 1, 0), "bounded explosion accepted");
    const auto pending = tile_at(world, 8, 2);
    require(pending.signals.pending_event && pending.summary.classification == DiscoveryClass::Invalid,
            "accepted event blocks affected coverage before execution");
    (void)world.tick();
    require(!tile_at(world, 8, 2).signals.pending_event,
            "pending-event signal clears only after owner-side drain");
}

CYBERSAND_TEST_NOINLINE void sparse_mask_coverage_and_inclusion_epochs() {
    auto disabled_config = tracked_config();
    disabled_config.settled_discovery_enabled = false;
    World disabled(disabled_config);
    disabled.reserve_region({0, 0, 8, 8});
    require(disabled.settled_discovery_coverage_state(0, 0) ==
                DiscoveryCoverageState::ResidentUntracked,
            "resident coverage is explicit when observation is disabled");

    World world(tracked_config());
    require(world.settled_discovery_coverage_state(0, 0) ==
                DiscoveryCoverageState::NotResident,
            "absence is explicit before residency");
    world.reserve_region({0, 0, 16, 8});
    require(world.settled_discovery_coverage_state(0, 0) ==
                DiscoveryCoverageState::RegisteredUnknown,
            "new residency is registered unknown before payload classification");
    service(world);
    require(world.settled_discovery_coverage_state(0, 0) ==
                DiscoveryCoverageState::Ready,
            "registered unknown becomes ready only after exact payload service");

    const auto initial = tile_at(world, 0, 0);
    const auto far_initial = tile_at(world, 8, 0);
    world.configure_transient_obstacles({0, 0, 8, 8});
    const auto reconfigured = tile_at(world, 0, 0);
    require(reconfigured.mask_revision > initial.mask_revision &&
            reconfigured.mask_occupancy_count == 0 &&
            tile_at(world, 8, 0).summary.revision == far_initial.summary.revision,
            "empty mask reconfiguration is a local generation witness");

    require(world.set_transient_obstacle(1, 1, 1), "first mask occupancy accepted");
    require(world.set_transient_obstacle(2, 1, 2), "second mask occupancy accepted");
    const auto two_masks = tile_at(world, 1, 1);
    require(two_masks.mask_occupancy_count == 2 && two_masks.signals.occupied &&
            two_masks.coverage == DiscoveryCoverageState::Blocked,
            "multiple mask incidences keep an exact local occupancy count");
    const auto occupied_revision = two_masks.mask_revision;
    world.clear_transient_obstacles();
    const auto cleared = tile_at(world, 1, 1);
    require(cleared.mask_occupancy_count == 0 && !cleared.signals.occupied &&
            cleared.mask_revision >= occupied_revision + 2,
            "two clears cannot collapse into a boolean ABA");
    const auto cleared_generation = cleared.mask_revision;
    world.configure_transient_obstacles({0, 0, 4, 4});
    world.configure_transient_obstacles({2, 0, 4, 4});
    world.configure_transient_obstacles({0, 0, 4, 4});
    require(tile_at(world, 1, 1).mask_revision > cleared_generation,
            "mask configuration change-and-restore cannot reuse an earlier generation");

    service(world);
    const auto before_exclusion = tile_at(world, 0, 0);
    world.set_simulation_region(RectI64{128, 128, 8, 8});
    const auto requested = tile_at(world, 0, 0);
    require(requested.coverage == DiscoveryCoverageState::Excluded &&
            requested.requested_inclusion_epoch > before_exclusion.requested_inclusion_epoch &&
            requested.applied_inclusion_epoch == before_exclusion.applied_inclusion_epoch,
            "requested inclusion epoch fences excluded coverage before application");
    (void)world.tick();
    const auto applied = tile_at(world, 0, 0);
    require(applied.applied_inclusion_epoch == applied.requested_inclusion_epoch &&
            applied.coverage == DiscoveryCoverageState::Excluded,
            "applied inclusion epoch catches up only at tick entry");

    world.set_simulation_region(std::nullopt);
    const auto reentry_requested = tile_at(world, 0, 0);
    require(reentry_requested.requested_inclusion_epoch > applied.requested_inclusion_epoch &&
            reentry_requested.applied_inclusion_epoch == applied.applied_inclusion_epoch &&
            !reentry_requested.signals.included,
            "requested re-entry cannot alias the still-excluded applied generation");
    (void)world.tick();
    const auto reentry_applied = tile_at(world, 0, 0);
    require(reentry_applied.applied_inclusion_epoch ==
                reentry_applied.requested_inclusion_epoch &&
            reentry_applied.signals.included,
            "applied re-entry receives a fresh generation before reuse");

    World aba(tracked_config());
    aba.reserve_region({0, 0, 8, 8});
    service(aba);
    const auto aba_base = tile_at(aba, 0, 0);
    aba.set_simulation_region(RectI64{128, 128, 8, 8});
    const auto aba_away = tile_at(aba, 0, 0);
    aba.set_simulation_region(std::nullopt);
    const auto aba_restored_request = tile_at(aba, 0, 0);
    require(aba_restored_request.requested_inclusion_epoch >
                aba_away.requested_inclusion_epoch &&
            aba_restored_request.applied_inclusion_epoch ==
                aba_base.applied_inclusion_epoch &&
            aba_restored_request.signals.included,
            "request ABA restores effective inclusion without aliasing requested epoch");
    (void)aba.tick();
    const auto aba_acknowledged = tile_at(aba, 0, 0);
    require(aba_acknowledged.applied_inclusion_epoch ==
                aba_acknowledged.requested_inclusion_epoch &&
            aba_acknowledged.requested_inclusion_epoch >
                aba_base.requested_inclusion_epoch,
            "tick acknowledges the newest inclusion epoch even when geometry ABA-restores");
}

CYBERSAND_TEST_NOINLINE void event_halo_overlap_and_signed_geometry() {
    auto config = tracked_config();
    config.activity_block_size = 1;
    config.settled_discovery_tile_capacity = 256;
    World world(config);
    world.reserve_region({-8, 0, 17, 1});
    service(world);

    const auto halo_before = tile_at(world, 5, 0);
    require(world.queue_explosion(0, 0, 1, 0), "minimum-radius event accepted");
    if (world.settled_discovery_halted() != DiscoveryHalt::None) {
        const auto metrics = world.settled_discovery_producer_metrics();
        throw std::runtime_error(
            "event acceptance fenced discovery: halt=" +
            std::to_string(static_cast<unsigned>(world.settled_discovery_halted())) +
            " global_fences=" + std::to_string(metrics.global_fences) +
            " observation_fences=" + std::to_string(metrics.observation_fences) +
            " generation_exhaustions=" +
            std::to_string(metrics.nonpayload_generation_exhaustions) +
            " event_witnesses=" + std::to_string(metrics.event_witnesses));
    }
    const auto halo_pending = tile_at(world, 5, 0);
    require(halo_pending.pending_event_count == 1 &&
            halo_pending.signals.pending_event &&
            halo_pending.event_revision > halo_before.event_revision,
            "default r=2 marks the halo-only P=R+4 tile");
    require(tile_at(world, -5, 0).signals.pending_event,
            "negative-coordinate halo uses the same signed geometry");
    (void)world.tick();
    const auto halo_drained = tile_at(world, 5, 0);
    require(halo_drained.pending_event_count == 0 &&
            !halo_drained.signals.pending_event,
            "halo-only pending state drains after event execution");

    auto small_config = config;
    small_config.maximum_rule_radius = 1;
    World small(small_config);
    small.reserve_region({0, 0, 8, 1});
    service(small);
    require(small.queue_explosion(0, 0, 1, 0), "r=1 event accepted");
    require(tile_at(small, 4, 0).signals.pending_event,
            "r=1 uses P=(R+2)+1 rather than R+2");

    auto large_config = config;
    large_config.maximum_rule_radius = 3;
    World large(large_config);
    large.reserve_region({0, 0, 8, 1});
    service(large);
    require(large.queue_explosion(0, 0, 1, 0), "r=3 event accepted");
    require(tile_at(large, 6, 0).signals.pending_event,
            "r>2 is added to the event effect reach");

    World late(config);
    require(late.queue_explosion(0, 0, 1, 0),
            "event may be accepted before destination coverage is resident");
    late.reserve_region({0, 0, 8, 1});
    require(tile_at(late, 5, 0).pending_event_count == 1,
            "new residency inherits an outstanding event before payload readiness");

    World corner(tracked_config());
    corner.reserve_region({0, 0, 16, 16});
    service(corner);
    require(corner.queue_explosion(3, 3, 1, 0), "corner-crossing event accepted");
    require(tile_at(corner, 8, 3).signals.pending_event &&
            tile_at(corner, 8, 8).signals.pending_event,
            "#57 halo covers both discovery-tile face and corner crossings");

    World rejected(config);
    const auto event_before = rejected.settled_discovery_producer_metrics().event_witnesses;
    require(!rejected.queue_explosion(0, 0, 0, 0),
            "radius zero remains authoritatively rejected");
    require(rejected.settled_discovery_producer_metrics().event_witnesses == event_before,
            "rejected event creates no observation witness");

    World observation_overflow(tracked_config());
    const auto accepted_x = std::numeric_limits<std::int64_t>::max() - 3;
    require(observation_overflow.queue_explosion(accepted_x, 0, 1, 0),
            "authoritative R+2 extent remains accepted at the signed endpoint");
    require(observation_overflow.settled_discovery_halted() ==
                DiscoveryHalt::ProducerFailure,
            "unrepresentable wider P halo fail-closes observation without rejecting event");
}

CYBERSAND_TEST_NOINLINE void overlapping_event_counts_and_generation_fence() {
    SettledWorldDiscoveryCoordinator coordinator(7001, 4, false);
    const DiscoveryTileKey key{7001, 0, 0, 0, 0, 0, 0};
    const DiscoveryBounds bounds{0, 0, 8, 8};
    const DiscoverySignals signals{true, true, true, false, false, false};
    require(coordinator.register_tile(key, bounds, 20, signals, 0) ==
                DiscoveryOutcome::Accepted,
            "direct sparse-event fixture registered");
    const auto handle = coordinator.find_handle(key);
    require(handle.has_value(), "direct sparse-event handle available");
    require(coordinator.witness_event(*handle, true, 0) == DiscoveryOutcome::Accepted &&
            coordinator.witness_event(*handle, true, 0) == DiscoveryOutcome::Accepted,
            "overlapping events add independent incidences");
    auto state = coordinator.tile(*handle);
    require(state.has_value() && state->pending_event_count == 2 &&
            state->signals.pending_event,
            "overlap retains exact pending count two");
    require(coordinator.witness_event(*handle, false, 0) == DiscoveryOutcome::Accepted,
            "first overlapping event drains");
    state = coordinator.tile(*handle);
    require(state.has_value() && state->pending_event_count == 1 &&
            state->signals.pending_event,
            "first drain cannot clear the second event obligation");
    require(coordinator.witness_event(*handle, false, 0) == DiscoveryOutcome::Accepted,
            "second overlapping event drains");
    state = coordinator.tile(*handle);
    require(state.has_value() && state->pending_event_count == 0 &&
            !state->signals.pending_event,
            "last drain clears pending state without underflow");
    const auto layout = coordinator.storage_layout();
    const auto producer_metrics = coordinator.producer_metrics();
    require(layout.sparse_witness_record_capacity == 4 &&
            layout.sparse_witness_record_storage_bytes ==
                layout.owner_record_storage_bytes &&
            producer_metrics.event_pending_high_water == 2,
            "non-payload witness storage is construction-bounded with exact high-water accounting");

    testing::set_next_nonpayload_generation_limit(2);
    SettledWorldDiscoveryCoordinator exhausted(7002, 1, false);
    const DiscoveryTileKey exhausted_key{7002, 0, 0, 0, 0, 0, 0};
    require(exhausted.register_tile(
                exhausted_key, bounds, 20, signals, 0) == DiscoveryOutcome::Accepted,
            "generation-exhaustion fixture registered");
    const auto exhausted_handle = exhausted.find_handle(exhausted_key);
    require(exhausted_handle.has_value() &&
            exhausted.witness_event(*exhausted_handle, true, 0) ==
                DiscoveryOutcome::Accepted,
            "last representable event generation accepted");
    require(exhausted.witness_event(*exhausted_handle, true, 0) ==
                DiscoveryOutcome::Halted &&
            exhausted.halted() == DiscoveryHalt::ProducerFailure,
            "generation exhaustion fences instead of aliasing a reused witness");
}

CYBERSAND_TEST_NOINLINE void nonpayload_quiet_world_locality() {
    World world(tracked_config());
    world.reserve_region({0, 0, 24, 8});
    service(world);
    const auto before = world.settled_discovery_producer_metrics();
    const auto far_revision = tile_at(world, 16, 0).summary.revision;
    for (int tick = 0; tick < 8; ++tick) {
        (void)world.tick();
        service(world);
    }
    const auto after = world.settled_discovery_producer_metrics();
    require(after.mask_witnesses == before.mask_witnesses &&
            after.event_witnesses == before.event_witnesses &&
            after.inclusion_witnesses == before.inclusion_witnesses &&
            after.signal_observations == before.signal_observations &&
            tile_at(world, 16, 0).summary.revision == far_revision,
            "unchanged worlds perform no #63 resident-wide signal polling");
}

CYBERSAND_TEST_NOINLINE void occupancy_preserves_exact_underlying_tuple() {
    auto config = tracked_config();
    config.chunk_size = 8;
    config.activity_block_size = 1;
    config.scheduling_core_size = 8;
    World world(config);
    require(world.set_cell_state(0, 0, Material::Wall, 17, 3),
            "under-occupancy tuple fixture accepted");
    world.set_temperature(0, 0, 222);
    (void)world.tick();
    service(world);
    const auto before = tile_at(world, 0, 0);
    require(before.summary.classification == DiscoveryClass::Uniform &&
            before.summary.uniform == DiscoveryCell{1, 17, 3, 222, false},
            "complete observation contains exact stored tuple before occupancy");

    world.configure_transient_obstacles({0, 0, 1, 1});
    require(world.set_transient_obstacle(0, 0, 1), "one-cell obstacle accepted");
    (void)world.tick();
    service(world);
    require(tile_at(world, 0, 0).summary.classification == DiscoveryClass::Blocked,
            "occupancy blocks publication without replacing stored tuple");
    world.clear_transient_obstacles();
    (void)world.tick();
    service(world);
    const auto after = tile_at(world, 0, 0);
    require(after.summary.classification == DiscoveryClass::Uniform &&
            after.summary.uniform == DiscoveryCell{1, 17, 3, 222, false},
            "mask removal reobserves exact material/state/temperature beneath occupancy");
}

CYBERSAND_TEST_NOINLINE void water_transfer_witnesses_both_endpoints() {
    World world(tracked_config());
    require(world.set_cell_state(0, 0, Material::Water, 200, 7),
            "Water source tuple accepted");
    require(world.set_cell_state(8, 0, Material::Water, 100, 3),
            "Water destination tuple accepted");
    const auto source_before = tile_at(world, 0, 0);
    const auto destination_before = tile_at(world, 8, 0);

    require(PrecisionProbe::transfer(world, 0, 0, 8, 0, 50) == 50,
            "direct Water quantity transfer accepted");
    const auto source_dirty = tile_at(world, 0, 0);
    const auto destination_dirty = tile_at(world, 8, 0);
    require(source_dirty.summary.revision > source_before.summary.revision &&
            destination_dirty.summary.revision > destination_before.summary.revision,
            "Water transfer witnesses both source and destination tuples");
    require(world.liquid_mass(0, 0) == 150 && world.liquid_mass(8, 0) == 150 &&
            PrecisionProbe::coherence(world, 0, 0) == 7 &&
            PrecisionProbe::coherence(world, 8, 0) == 7,
            "Water transfer retains exact mass and max coherence authority");
}

CYBERSAND_TEST_NOINLINE void no_write_activity_deadline_and_epoch_wrap() {
    auto config = tracked_config();
    World active(config);
    active.reserve_region({0, 0, 8, 8});
    require(active.set_cell_state(0, 0, Material::Wood, 0, 5),
            "burning combustible fixture accepted");
    bool saw_no_write = false;
    for (int attempt = 0; attempt < 12 && !saw_no_write; ++attempt) {
        const auto before = active.content_hash();
        (void)active.tick();
        if (active.content_hash() == before) {
            saw_no_write = true;
            require(tile_at(active, 0, 0).signals.active,
                    "no-write keep-active work blocks settled observation");
        }
    }
    require(saw_no_write, "fixture reached a deterministic no-write lifecycle lane");

    config.chunk_size = 32;
    config.activity_block_size = 32;
    config.scheduling_core_size = 32;
    config.interaction_policy.mercury_exchange_period = 30;
    World deadline(config);
    for (int x = -2; x <= 2; ++x)
        for (int y = -2; y <= 3; ++y) deadline.set(x, y, Material::Wall);
    deadline.set(0, 0, Material::Mercury);
    deadline.set(0, 1, Material::Sand);
    for (int tick = 1; tick < 30; ++tick) (void)deadline.tick();
    require(deadline.active_chunk_count() == 0 && tile_at(deadline, 0, 0).signals.active,
            "sleeping block with a future interaction deadline remains uninspectable");

    World epoch(tracked_config());
    epoch.reserve_region({0, 0, 8, 8});
    service(epoch);
    const auto before_wrap = tile_at(epoch, 0, 0).summary.revision;
    for (int tick = 0; tick < 260; ++tick) (void)epoch.tick();
    require(tile_at(epoch, 0, 0).summary.revision == before_wrap,
            "epoch maintenance wrap never masquerades as material mutation");
}

CYBERSAND_TEST_NOINLINE void custom_geometry_signed_endpoints_and_policy_fence() {
    auto config = tracked_config();
    config.chunk_size = 10;
    config.activity_block_size = 6;
    config.scheduling_core_size = 8;
    World partial(config);
    partial.reserve_region({-10, -10, 10, 10});
    require(partial.settled_discovery_tile_count() == 4,
            "partial activity-block edges become four canonical bounded tiles");
    require(tile_at(partial, -1, -1).summary.bounds.width == 4 &&
            tile_at(partial, -1, -1).summary.bounds.height == 4,
            "negative partial edge bounds are exact");

    World maximum(tracked_config());
    maximum.reserve_region({std::numeric_limits<std::int64_t>::max(), 0, 1, 1});
    maximum.set(std::numeric_limits<std::int64_t>::max(), 0, Material::Wall);
    require(tile_at(maximum, std::numeric_limits<std::int64_t>::max(), 0).summary.classification ==
                DiscoveryClass::Invalid,
            "maximum signed endpoint maps without overflow");
    World minimum(tracked_config());
    minimum.reserve_region({std::numeric_limits<std::int64_t>::min(), 0, 1, 1});
    minimum.set(std::numeric_limits<std::int64_t>::min(), 0, Material::Wall);
    require(tile_at(minimum, std::numeric_limits<std::int64_t>::min(), 0).summary.classification ==
                DiscoveryClass::Invalid,
            "minimum signed endpoint maps without overflow");

    World policy(tracked_config());
    policy.reserve_region({0, 0, 8, 8});
    service(policy);
    const auto before = tile_at(policy, 0, 0).summary.revision;
    policy.set_liquid_surface_adhesion_enabled(false);
    require(tile_at(policy, 0, 0).summary.revision > before &&
            tile_at(policy, 0, 0).summary.classification == DiscoveryClass::Invalid &&
            policy.settled_discovery_producer_metrics().global_fences == 1,
            "live semantic policy toggle fences prior observations");
}

CYBERSAND_TEST_NOINLINE void inclusion_reset_move_and_failure_quarantine() {
    auto config = tracked_config();
    World world(config);
    world.reserve_region({0, 0, 8, 8});
    service(world);
    const auto original = tile_at(world, 0, 0);
    const auto incarnation = world.settled_discovery_incarnation();
    world.set_simulation_region(RectI64{128, 128, 8, 8});
    const auto excluded = tile_at(world, 0, 0);
    require(!excluded.signals.included && excluded.summary.revision > original.summary.revision &&
            excluded.summary.classification == DiscoveryClass::Invalid,
            "requested exclusion immediately fences old summaries");
    (void)world.tick();
    world.set_simulation_region(std::nullopt);
    require(!tile_at(world, 0, 0).signals.included,
            "re-entry request cannot reuse quiet age before application");
    (void)world.tick();
    service(world);
    require(tile_at(world, 0, 0).signals.included,
            "re-entry application requires a fresh included observation");

    World moved(std::move(world));
    require(moved.settled_discovery_incarnation() == incarnation &&
            !world.settled_discovery_enabled(),
            "World move transfers the observer and leaves no duplicate identity");
    moved.clear();
    require(moved.settled_discovery_incarnation() != incarnation &&
            moved.settled_discovery_tile_count() == 0,
            "clear retires the old incarnation and reconstructs empty tracking");

    config.active_core_capacity = 1;
    config.settled_region_connectivity_enabled = true;
    World failed(config);
    failed.set(0, 0, Material::Sand);
    failed.set(16, 0, Material::Sand);
    bool threw = false;
    try { (void)failed.tick(); } catch (const std::runtime_error&) { threw = true; }
    require(threw && failed.has_failed() &&
            failed.settled_discovery_halted() == DiscoveryHalt::ProducerFailure &&
            failed.settled_discovery_coverage_state(0, 0) ==
                DiscoveryCoverageState::Failed &&
            !failed.settled_discovery_tile(0).has_value() &&
            failed.advance_settled_discovery(100) == 0 &&
            failed.settled_region_count() == 0 &&
            failed.settled_region_refusal() == RegionRefusal::SourceFailure,
            "failed tick immediately quarantines discovery and connectivity snapshots");
}

void seed_fixture(World& world) {
    world.reserve_region({-8, -8, 32, 24});
    for (std::int64_t x = -8; x < 24; ++x) world.set(x, 7, Material::Wall);
    require(world.set_cell_state(0, 0, Material::Water, 255, 2), "Water fixture accepted");
    world.set(1, 0, Material::Sand);
    world.set_temperature(2, 0, 500);
}

CYBERSAND_TEST_NOINLINE void reset_replacement_failure_retires_before_authority_loss() {
    auto config = tracked_config();
    World world(config);
    world.reserve_region({0, 0, 8, 8});
    service(world);
    const auto original = tile_at(world, 0, 0);
    const auto original_handle = original.summary.handle;
    const auto original_incarnation = world.settled_discovery_incarnation();
    require(original_handle.incarnation == original_incarnation &&
            original.summary.classification != DiscoveryClass::Invalid,
            "pre-reset observation is live and belongs to the current incarnation");

    world.clear();
    const auto replacement_incarnation = world.settled_discovery_incarnation();
    require(world.settled_discovery_enabled() &&
            replacement_incarnation != 0 &&
            replacement_incarnation > original_incarnation &&
            world.settled_discovery_tile_count() == 0 &&
            !world.settled_discovery_tile(original_handle.slot).has_value(),
            "clear retires the old observer before exposing an empty replacement");

    world.reserve_region({0, 0, 8, 8});
    service(world);
    auto replacement = tile_at(world, 0, 0);
    require(replacement.summary.handle.slot == original_handle.slot &&
            replacement.summary.handle != original_handle &&
            replacement.summary.handle.incarnation == replacement_incarnation,
            "slot reuse cannot make a pre-reset discovery handle current again");

    auto prior_incarnation = replacement_incarnation;
    auto stale_handle = replacement.summary.handle;
    for (int cycle = 0; cycle < 8; ++cycle) {
        world.clear();
        const auto current_incarnation = world.settled_discovery_incarnation();
        require(current_incarnation > prior_incarnation &&
                !world.settled_discovery_tile(stale_handle.slot).has_value(),
                "repeated clear advances incarnation before any slot can be reused");
        world.reserve_region({0, 0, 8, 8});
        service(world);
        replacement = tile_at(world, 0, 0);
        require(replacement.summary.handle.incarnation == current_incarnation &&
                replacement.summary.handle != stale_handle,
                "repeated replacement never revives the prior object/slot identity");
        stale_handle = replacement.summary.handle;
        prior_incarnation = current_incarnation;
    }

    world.set(3, 3, Material::Stone);
    service(world);
    const auto pre_fault = tile_at(world, 3, 3);
    const auto pre_fault_incarnation = world.settled_discovery_incarnation();

    testing::fail_next_settled_world_discovery_construction();
    bool allocation_failed = false;
    try {
        world.clear();
    } catch (const std::bad_alloc&) {
        allocation_failed = true;
    }
    require(allocation_failed &&
            !world.has_failed() &&
            !world.settled_discovery_enabled() &&
            world.settled_discovery_incarnation() == 0 &&
            world.settled_discovery_tile_count() == 0 &&
            world.settled_discovery_pending() == 0 &&
            world.settled_discovery_halted() == DiscoveryHalt::None &&
            world.settled_region_refusal() == RegionRefusal::None &&
            world.advance_settled_discovery(100) == 0 &&
            !world.settled_discovery_tile(pre_fault.summary.handle.slot).has_value(),
            "post-reset replacement allocation failure leaves discovery explicitly unavailable");
    require(world.chunk_count() == 0 && world.get(3, 3) == Material::Empty,
            "allocation failure occurs after the existing authoritative clear contract");

    auto disabled = config;
    disabled.settled_discovery_enabled = false;
    World control(disabled);
    seed_fixture(world);
    seed_fixture(control);
    for (int tick = 0; tick < 16; ++tick) {
        const auto unavailable_stats = world.tick();
        const auto control_stats = control.tick();
        require(unavailable_stats.visited_cells == control_stats.visited_cells &&
                unavailable_stats.moved_cells == control_stats.moved_cells &&
                world.content_hash() == control.content_hash(),
                "discovery-unavailable World remains authoritative-simulation neutral");
    }
    require(!world.settled_discovery_enabled() && !world.has_failed(),
            "normal discovery unavailability is distinct from failed-World quarantine");

    world.clear();
    require(world.settled_discovery_enabled() &&
            world.settled_discovery_incarnation() > pre_fault_incarnation &&
            world.settled_discovery_tile_count() == 0,
            "later successful reset constructs a fresh incarnation without resurrecting the failed one");
}

CYBERSAND_TEST_NOINLINE void disabled_neutrality_and_worker_parity() {
    auto tracked = tracked_config();
    tracked.maximum_chunk_count = 64;
    tracked.active_chunk_capacity = 64;
    tracked.active_core_capacity = 512;
    auto disabled = tracked;
    disabled.settled_discovery_enabled = false;
    World observed(tracked), control(disabled);
    seed_fixture(observed);
    seed_fixture(control);
    for (int tick = 0; tick < 24; ++tick) {
        const auto observed_stats = observed.tick();
        const auto control_stats = control.tick();
        require(observed_stats.visited_cells == control_stats.visited_cells &&
                observed_stats.moved_cells == control_stats.moved_cells &&
                observed.content_hash() == control.content_hash(),
                "opt-in discovery cannot alter authoritative simulation work or state");
    }

    auto single_config = tracked;
    auto parallel_config = tracked;
    parallel_config.worker_threads = 4;
    World single(single_config), parallel(parallel_config);
    seed_fixture(single);
    seed_fixture(parallel);
    for (int tick = 0; tick < 24; ++tick) {
        (void)single.tick();
        (void)parallel.tick();
        require(single.content_hash() == parallel.content_hash(),
                "worker count changed authoritative fixture state");
    }
    require(single.settled_discovery_tile_count() == parallel.settled_discovery_tile_count(),
            "worker count changed canonical registration");
    for (std::size_t index = 0; index < single.settled_discovery_tile_count(); ++index) {
        const auto a = single.settled_discovery_tile(index);
        const auto b = parallel.settled_discovery_tile(index);
        require(a.has_value() && b.has_value(), "worker parity tile snapshots available");
        require(a->summary.bounds == b->summary.bounds &&
                a->summary.revision == b->summary.revision &&
                a->summary.classification == b->summary.classification &&
                a->signals == b->signals,
                "workers1/4 produce equivalent tile witnesses");
    }
}

CYBERSAND_TEST_NOINLINE void integrated_region_publication_split_merge_and_refusal() {
    auto config = tracked_config();
    config.settled_region_connectivity_enabled = true;
    World world(config);
    world.reserve_region({0, 0, 16, 8});
    for (std::int64_t y = 0; y < 8; ++y)
        for (std::int64_t x = 0; x < 16; ++x) world.set(x, y, Material::Wall);
    (void)world.tick();
    service(world);
    service_regions(world);
    require(world.settled_region_storage_bytes() != 0,
            "opt-in World reports explicit connectivity storage");
    require(world.settled_region_count() == 1,
            "adjacent complete World tiles publish one region");
    const auto joined = world.settled_region(0);
    require(joined.has_value() && joined->complete && joined->area == 128 &&
            joined->tile_count == 2 && joined->component_count == 2,
            "World publication contains the exact two-tile component");
    const auto old_handle = joined->handle;

    for (std::int64_t y = 0; y < 8; ++y) world.set(7, y, Material::Empty);
    require(!world.settled_region(0).has_value() && world.settled_region_count() == 0,
            "first bridge mutation retires the old region before rescanning");
    (void)world.tick();
    service(world);
    service_regions(world);
    require(!world.settled_region(0).has_value() ||
            world.settled_region(0)->handle != old_handle,
            "retired region handle cannot alias a replacement generation");
    require(world.settled_region_count() == 2,
            "removed bridge column republishes two complete islands");
    std::uint64_t split_area = 0;
    for (std::size_t slot = 0; slot < 64; ++slot) {
        const auto region = world.settled_region(slot);
        if (region.has_value()) split_area += region->area;
    }
    require(split_area == 120, "split regions preserve the exact remaining solid area");

    for (std::int64_t y = 0; y < 8; ++y) world.set(7, y, Material::Wall);
    (void)world.tick();
    service(world);
    service_regions(world);
    require(world.settled_region_count() == 1,
            "restored bridge republishes one merged region");
    std::optional<SettledRegionSnapshot> merged;
    for (std::size_t slot = 0; slot < 64 && !merged.has_value(); ++slot)
        merged = world.settled_region(slot);
    require(merged.has_value() && merged->area == 128 && merged->tile_count == 2,
            "merged World region recovers exact area and tile membership");

    world.configure_transient_obstacles({0, 0, 8, 8});
    require(world.set_transient_obstacle(1, 1, 1), "integrated mask fixture accepted");
    require(world.settled_region_count() == 0,
            "mask add retires the connected publication immediately");
    (void)world.tick();
    service(world);
    service_regions(world);
    require(world.settled_region_count() == 0 &&
            world.settled_region_refusal() == RegionRefusal::UnknownBoundary,
            "blocked tile prevents its facing neighbor from publishing complete");
    world.clear_transient_obstacles();
    (void)world.tick();
    service(world);
    service_regions(world);
    require(world.settled_region_count() == 1,
            "mask removal requires fresh payloads before merged republication");

    world.set_temperature(0, 0, 21);
    require(world.settled_region_count() == 0,
            "hot Empty candidate mutation retires prior publication immediately");
    world.set(0, 0, Material::Empty);
    (void)world.tick();
    service(world);
    require(world.settled_region_refusal() == RegionRefusal::NoncanonicalEmpty,
            "noncanonical Empty tile is explicitly refused at ingestion");
    service_regions(world);
    require(world.settled_region_count() == 0 &&
            world.settled_region_refusal() == RegionRefusal::UnknownBoundary,
            "neighboring coverage remains incomplete after a refused tile");
}

CYBERSAND_TEST_NOINLINE void integrated_new_tile_registration_retires_facing_region() {
    auto config = tracked_config();
    config.settled_region_connectivity_enabled = true;
    World world(config);
    world.reserve_region({0, 0, 8, 8});
    for (std::int64_t y = 0; y < 8; ++y)
        for (std::int64_t x = 0; x < 8; ++x) world.set(x, y, Material::Wall);
    (void)world.tick();
    service(world);
    service_regions(world);
    require(world.settled_region_count() == 1,
            "single sealed World tile publishes a complete region");

    world.reserve_region({8, 0, 8, 8});
    require(world.settled_region_count() == 0,
            "new unknown facing tile retires the old sealed-edge publication immediately");
    (void)world.tick();
    service(world);
    service_regions(world);
    require(world.settled_region_count() == 1,
            "old material republishes only after the new Empty neighbor is witnessed");
    std::optional<SettledRegionSnapshot> region;
    for (std::size_t slot = 0; slot < 64 && !region.has_value(); ++slot)
        region = world.settled_region(slot);
    require(region.has_value() && region->area == 64 && region->tile_count == 1 &&
            region->dependency_tile_count == 2,
            "republished region depends on the witnessed facing Empty tile");
}

CYBERSAND_TEST_NOINLINE void integrated_region_worker_parity() {
    auto single_config = tracked_config(1);
    auto parallel_config = tracked_config(4);
    single_config.settled_region_connectivity_enabled = true;
    parallel_config.settled_region_connectivity_enabled = true;
    World single(single_config), parallel(parallel_config);
    for (auto* world : {&single, &parallel}) {
        world->reserve_region({-8, 0, 16, 8});
        for (std::int64_t y = 0; y < 8; ++y)
            for (std::int64_t x = -8; x < 8; ++x) world->set(x, y, Material::Wall);
        (void)world->tick();
        service(*world);
        service_regions(*world);
    }
    require(single.content_hash() == parallel.content_hash() &&
            single.settled_region_count() == 1 && parallel.settled_region_count() == 1,
            "workers1/4 integrated fixtures reach the same complete topology");
    std::optional<SettledRegionSnapshot> a, b;
    for (std::size_t slot = 0; slot < 64; ++slot) {
        if (!a.has_value()) a = single.settled_region(slot);
        if (!b.has_value()) b = parallel.settled_region(slot);
    }
    require(a.has_value() && b.has_value() && a->key == b->key &&
            a->min_x == b->min_x && a->min_y == b->min_y &&
            a->max_x == b->max_x && a->max_y == b->max_y &&
            a->area == b->area && a->tile_count == b->tile_count &&
            a->component_count == b->component_count &&
            a->dependency_tile_count == b->dependency_tile_count &&
            a->member_digest == b->member_digest &&
            a->dependency_digest == b->dependency_digest,
            "workers1/4 publish equivalent normalized region summaries and digests");
}
} // namespace

int main() {
    try {
        run_named("direct_aba_exact_tuple_and_render_independence", [] { direct_aba_exact_tuple_and_render_independence(); });
        run_named("canonical_geometry_registration_and_capacity", [] { canonical_geometry_registration_and_capacity(); });
        run_named("movement_mask_event_and_far_locality", [] { movement_mask_event_and_far_locality(); });
        run_named("sparse_mask_coverage_and_inclusion_epochs", [] { sparse_mask_coverage_and_inclusion_epochs(); });
        run_named("event_halo_overlap_and_signed_geometry", [] { event_halo_overlap_and_signed_geometry(); });
        run_named("overlapping_event_counts_and_generation_fence", [] { overlapping_event_counts_and_generation_fence(); });
        run_named("nonpayload_quiet_world_locality", [] { nonpayload_quiet_world_locality(); });
        run_named("occupancy_preserves_exact_underlying_tuple", [] { occupancy_preserves_exact_underlying_tuple(); });
        run_named("water_transfer_witnesses_both_endpoints", [] { water_transfer_witnesses_both_endpoints(); });
        run_named("no_write_activity_deadline_and_epoch_wrap", [] { no_write_activity_deadline_and_epoch_wrap(); });
        run_named("custom_geometry_signed_endpoints_and_policy_fence", [] { custom_geometry_signed_endpoints_and_policy_fence(); });
        run_named("inclusion_reset_move_and_failure_quarantine", [] { inclusion_reset_move_and_failure_quarantine(); });
        run_named("reset_replacement_failure_retires_before_authority_loss", [] { reset_replacement_failure_retires_before_authority_loss(); });
        run_named("disabled_neutrality_and_worker_parity", [] { disabled_neutrality_and_worker_parity(); });
        run_named("integrated_region_publication_split_merge_and_refusal", [] { integrated_region_publication_split_merge_and_refusal(); });
        run_named("integrated_new_tile_registration_retires_facing_region", [] { integrated_new_tile_registration_retires_facing_region(); });
        run_named("integrated_region_worker_parity", [] { integrated_region_worker_parity(); });
        std::cout << "settled World discovery tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "settled World discovery test failure: " << error.what() << '\n';
        return 1;
    }
}
