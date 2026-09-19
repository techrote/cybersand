#include "cybersand/world.hpp"

#include <cstdint>
#include <iostream>
#include <limits>
#include <optional>
#include <stdexcept>
#include <utility>

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
        require(tile.has_value(), "registered tile snapshot available");
        const auto& bounds = tile->summary.bounds;
        if (bounds.x <= x && x <= bounds.x + static_cast<std::int64_t>(bounds.width - 1U) &&
            bounds.y <= y && y <= bounds.y + static_cast<std::int64_t>(bounds.height - 1U)) return *tile;
    }
    throw std::runtime_error("requested discovery tile not found");
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
            constrained.settled_region_refusal() == RegionRefusal::TileCapacity,
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
        direct_aba_exact_tuple_and_render_independence();
        canonical_geometry_registration_and_capacity();
        movement_mask_event_and_far_locality();
        no_write_activity_deadline_and_epoch_wrap();
        custom_geometry_signed_endpoints_and_policy_fence();
        inclusion_reset_move_and_failure_quarantine();
        disabled_neutrality_and_worker_parity();
        integrated_region_publication_split_merge_and_refusal();
        integrated_new_tile_registration_retires_facing_region();
        integrated_region_worker_parity();
        std::cout << "settled World discovery tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "settled World discovery test failure: " << error.what() << '\n';
        return 1;
    }
}
