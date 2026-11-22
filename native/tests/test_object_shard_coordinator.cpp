#include "cybersand/object_shard_coordinator.hpp"
#include "cybersand/material_lifecycle.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <limits>
#include <stdexcept>
#include <vector>

// Test-only friend seam. These mutations execute real World APIs while command
// admission is paused, modelling an erroneous/stale external owner. Production
// callers have no mutable World access through Coordinator.
namespace cybersand::object_shard {
struct CoordinatorTestAccess {
    static World& world(Coordinator& coordinator) { return *coordinator.world_; }
    static Registry& registry(Coordinator& coordinator) { return coordinator.registry_; }
};
}

namespace {
using namespace cybersand;
using namespace cybersand::object_shard;
std::uint64_t checks{}, failures{};
void check(bool pass, const char* description, int line) {
    ++checks;
    if (!pass) { ++failures; std::fprintf(stderr, "FAIL %d: %s\n", line, description); }
}
#define CHECK(expression) check((expression), #expression, __LINE__)

Payload empty() { return {Material::Empty, 0, 0, 200}; }
Config small_config() {
    Config config;
    config.scenario = 0;
    config.world_bounds = {0, 0, 128, 96};
    return config;
}
void make_supported(Coordinator& coordinator, std::int64_t x = 30, std::int64_t y = 30,
        Material material = Material::Wood, std::uint8_t burn = 0) {
    for (int row = 0; row < 3; ++row) for (int column = 0; column < 3; ++column)
        CHECK(coordinator.edit(x + column, y + row,
            {material, static_cast<std::uint16_t>(170 + row * 3 + column), burn,
             static_cast<std::int16_t>(400 + row * 3 + column)}).outcome == Outcome::Accepted);
    for (int column = 0; column < 3; ++column)
        CHECK(coordinator.edit(x + column, y + 3, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
}
void erase_support(Coordinator& coordinator, std::int64_t x = 30, std::int64_t y = 30) {
    for (int column = 0; column < 3; ++column)
        CHECK(coordinator.edit(x + column, y + 3, empty()).outcome == Outcome::Accepted);
}
Result discover(Coordinator& coordinator) {
    Result result;
    // Initial residency invalidates the bounded window; a deliberately tiny
    // discovery budget legitimately needs several calls to drain empty seeds.
    const auto maximum_attempts = coordinator.config().world_bounds.area() /
        coordinator.config().discovery_budget + 128;
    for (unsigned attempt = 0; attempt < maximum_attempts; ++attempt) {
        result = coordinator.prepare_next();
        if (result.outcome == Outcome::Accepted) return result;
        if (result.outcome != Outcome::Busy && result.outcome != Outcome::Anchored) break;
    }
    std::fprintf(stderr, "Discovery result: %s (%s)\n", outcome_name(result.outcome), result.detail);
    return result;
}
Acknowledgement ack_for(Coordinator& coordinator, AckKind kind) {
    const auto snapshot = coordinator.snapshot();
    const auto& promotion = snapshot.promotion;
    const auto* shard = coordinator.registry().find(promotion.shard);
    CHECK(promotion.present && shard != nullptr);
    if (!shard) return {};
    const auto& geometry = shard->geometry();
    return {promotion.shard, promotion.transaction, promotion.shard.generation,
        promotion.payload_digest, geometry.revision, geometry.mask_digest,
        geometry.shape_digest, kind, kind == AckKind::TerrainInstalled ? promotion.terrain : std::span<const TerrainReceipt>{}};
}
bool activate(Coordinator& coordinator, Handle expected) {
    for (const auto kind : {AckKind::PhysicsReserved, AckKind::TerrainInstalled, AckKind::BodyActivated}) {
        const auto ack = ack_for(coordinator, kind);
        CHECK(ack.shard == expected);
        const auto result = coordinator.acknowledge(ack);
        CHECK(result.outcome == Outcome::Accepted);
        if (result.outcome != Outcome::Accepted) return false;
    }
    CHECK(!coordinator.paused());
    const auto* shard = coordinator.registry().find(expected);
    CHECK(shard != nullptr && shard->phase() == Phase::Active && shard->owns_inventory());
    return shard != nullptr && shard->phase() == Phase::Active;
}
std::vector<PoseSample> next_poses(Coordinator& coordinator) {
    std::vector<PoseSample> poses;
    for (const auto& body : coordinator.snapshot().bodies) if (body.has_body) {
        poses.push_back(body.pose);
        ++poses.back().pose_serial;
    }
    return poses;
}
std::uint64_t world_population(Coordinator& coordinator, Material material) {
    return coordinator.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(material)];
}
Acknowledgement geometry_ack(Coordinator& coordinator, Handle handle, AckKind kind = AckKind::GeometryInstalled) {
    const auto* shard = coordinator.registry().find(handle);
    CHECK(shard != nullptr);
    for (const auto& body : coordinator.snapshot().bodies) if (body.shard == handle) {
        const auto& geometry = shard->geometry();
        return {handle, body.transaction, body.body_generation, shard->payload_digest(),
            geometry.revision, geometry.mask_digest, geometry.shape_digest, kind, {}};
    }
    CHECK(false);
    return {};
}
void install_geometry(Coordinator& coordinator) {
    std::vector<Handle> pending;
    for (const auto& body : coordinator.snapshot().bodies)
        if (body.geometry_pending) pending.push_back(body.shard);
    for (const auto handle : pending) {
        const auto* shard = coordinator.registry().find(handle);
        CHECK(shard != nullptr);
        const auto kind = shard->counts().structural == 0 ? AckKind::BodyRetired : AckKind::GeometryInstalled;
        CHECK(coordinator.acknowledge(geometry_ack(coordinator, handle, kind)).outcome == Outcome::Accepted);
    }
}
void sleeping_step(Coordinator& coordinator) {
    auto poses = next_poses(coordinator);
    for (auto& pose : poses) pose.sleeping = true;
    CHECK(coordinator.step(poses).outcome == Outcome::Accepted);
    install_geometry(coordinator);
}

void finite_coordinate_configuration() {
    for (const auto value : {std::numeric_limits<std::int64_t>::min(),
                            std::numeric_limits<std::int64_t>::max(),
                            std::int64_t{-262145}, std::int64_t{262144}}) {
        for (const bool x_axis : {true, false}) {
            auto config = small_config();
            if (x_axis) config.world_bounds.x = value;
            else config.world_bounds.y = value;
            bool refused = false;
            try { Coordinator coordinator(config); }
            catch (const std::invalid_argument&) { refused = true; }
            CHECK(refused);
        }
    }
    for (const bool negative : {false, true}) {
        auto config = small_config();
        config.world_bounds.x = negative ? -262144 : 262144 - config.world_bounds.width;
        config.world_bounds.y = negative ? -262144 : 262144 - config.world_bounds.height;
        Coordinator coordinator(config);
        CHECK(coordinator.step().outcome == Outcome::Accepted);
        CHECK(!coordinator.world().has_failed());
    }
}

void ordinary_support_loss_and_exact_capture() {
    auto config = small_config(); config.world_bounds = {-64, -64, 128, 128};
    Coordinator coordinator(config);
    make_supported(coordinator, -1, -1);
    for (unsigned i = 0; i < 16; ++i) {
        const auto anchored = coordinator.prepare_next();
        CHECK(anchored.outcome == Outcome::Busy || anchored.outcome == Outcome::Anchored);
        CHECK(!coordinator.snapshot().promotion.present);
    }
    erase_support(coordinator, -1, -1);
    const auto before = coordinator.world().quantity_ledger();
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(coordinator.paused());
    const auto* shard = coordinator.registry().find(prepared.shard);
    CHECK(shard && !shard->owns_inventory());
    CHECK(coordinator.registry().inventory_counts().total() == 0);
    CHECK(shard->counts().structural == 9);
    CHECK(shard->geometry().shapes.size() == 1);
    const auto bounds = shard->bounds();
    CHECK(bounds.x == -2 && bounds.y == -2 && bounds.width == 5 && bounds.height == 5);
    std::array<Payload, 9> expected{};
    for (int y = 0; y < 3; ++y) for (int x = 0; x < 3; ++x) {
        const auto index = static_cast<std::size_t>(y * 3 + x);
        expected[index] = coordinator.inspect_world(x - 1, y - 1);
        CHECK(shard->payload(static_cast<std::size_t>(y + 1) * 5 + x + 1) == expected[index]);
    }
    CHECK(coordinator.edit(70, 70, empty()).outcome == Outcome::Fenced);
    const auto tick = coordinator.world().completed_tick_index();
    CHECK(coordinator.step().outcome == Outcome::Fenced);
    CHECK(coordinator.world().completed_tick_index() == tick);
    if (!activate(coordinator, prepared.shard)) return;
    CHECK(coordinator.registry().inventory_counts().structural == 9);
    CHECK(world_population(coordinator, Material::Wood) == 0);
    const auto after = coordinator.world().quantity_ledger();
    CHECK(after.water_visible == before.water_visible && after.water_overfill == before.water_overfill);
    CHECK(after.kinds == before.kinds); // Non-Water ownership transfer is not a Water sink.
    CHECK(coordinator.accounting().promoted[static_cast<std::uint8_t>(Material::Wood)] == 9);
    for (int y = 0; y < 3; ++y) for (int x = 0; x < 3; ++x) {
        CHECK(coordinator.inspect_world(x - 1, y - 1).material == Material::Empty);
        CHECK(coordinator.world().transient_obstacle_at(x - 1, y - 1) != 0);
        CHECK(shard->payload(static_cast<std::size_t>(y + 1) * 5 + x + 1) == expected[static_cast<std::size_t>(y * 3 + x)]);
    }
    auto poses = next_poses(coordinator);
    CHECK(poses.size() == 1);
    poses[0].x += 0.25; poses[0].rotation += 0.01;
    CHECK(coordinator.step(poses).outcome == Outcome::Accepted);
    CHECK(coordinator.world().completed_tick_index() == tick + 1);
    CHECK(shard->bounds() == bounds);
    CHECK(shard->counts().structural == 9);
}

void state_temperature_and_aba_refuse() {
    for (unsigned mutation = 0; mutation < 5; ++mutation) {
        Coordinator coordinator(small_config());
        make_supported(coordinator); erase_support(coordinator);
        const auto prepared = discover(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) continue;
        const auto original = coordinator.inspect_world(31, 31);
        auto& world = CoordinatorTestAccess::world(coordinator);
        if (mutation == 0) CHECK(world.set_cell_state(31, 31, Material::Wood, original.state_a + 1, original.state_b));
        if (mutation == 1) CHECK(world.set_cell_state(31, 31, Material::Wood, original.state_a, 3));
        if (mutation == 2) world.set_temperature(31, 31, original.temperature + 1);
        if (mutation == 3) {
            CHECK(world.set_cell_state(31, 31, Material::RedBrick, 0, 0));
            CHECK(world.set_cell_state(31, 31, Material::Wood, original.state_a, original.state_b));
            CHECK(coordinator.inspect_world(31, 31) == original);
        }
        if (mutation == 4) {
            world.set_temperature(31, 31, original.temperature + 1);
            world.set_temperature(31, 31, original.temperature);
            CHECK(coordinator.inspect_world(31, 31) == original);
        }
        const auto refused = coordinator.acknowledge(ack_for(coordinator, AckKind::PhysicsReserved));
        CHECK(refused.outcome == Outcome::Stale);
        CHECK(coordinator.registry().inventory_counts().total() == 0);
        CHECK(world_population(coordinator, Material::Wood) == 9);
        CHECK(coordinator.cancel(prepared.transaction).outcome == Outcome::Cancelled);
        CHECK(!coordinator.paused());
    }
}

void pending_event_and_malformed_receipts() {
    Coordinator coordinator(small_config());
    make_supported(coordinator); erase_support(coordinator);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    const auto valid = ack_for(coordinator, AckKind::PhysicsReserved);
    auto wrong = valid; wrong.kind = static_cast<AckKind>(255);
    CHECK(coordinator.acknowledge(wrong).outcome == Outcome::Invalid);
    wrong = valid; ++wrong.shard.generation;
    CHECK(coordinator.acknowledge(wrong).outcome == Outcome::Stale);
    wrong = valid; ++wrong.body_generation;
    CHECK(coordinator.acknowledge(wrong).outcome == Outcome::Stale);
    wrong = valid; ++wrong.payload_digest;
    CHECK(coordinator.acknowledge(wrong).outcome == Outcome::Stale);
    wrong = valid; ++wrong.shape_digest;
    CHECK(coordinator.acknowledge(wrong).outcome == Outcome::Stale);
    CHECK(coordinator.acknowledge(ack_for(coordinator, AckKind::BodyActivated)).outcome == Outcome::Stale);
    CHECK(coordinator.acknowledge(ack_for(coordinator, AckKind::TerrainInstalled)).outcome == Outcome::Stale);
    CHECK(CoordinatorTestAccess::world(coordinator).queue_explosion(31, 31, 2));
    CHECK(coordinator.acknowledge(valid).outcome == Outcome::Stale);
    CHECK(world_population(coordinator, Material::Wood) == 9);
    CHECK(coordinator.registry().inventory_counts().total() == 0);
    CHECK(coordinator.cancel(prepared.transaction).outcome == Outcome::Cancelled);

    Coordinator before_prepare(small_config());
    make_supported(before_prepare); erase_support(before_prepare);
    CHECK(CoordinatorTestAccess::world(before_prepare).queue_explosion(31, 31, 2));
    const auto event_refusal = discover(before_prepare);
    CHECK(event_refusal.outcome == Outcome::PendingEvent);
    CHECK(world_population(before_prepare, Material::Wood) == 9);
    CHECK(before_prepare.registry().inventory_counts().total() == 0);
}

void installed_receipts_and_chemistry_fence() {
    Coordinator coordinator(small_config());
    make_supported(coordinator, 30, 30, Material::Wood, 39); erase_support(coordinator);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    const auto reservation = ack_for(coordinator, AckKind::PhysicsReserved);
    CHECK(coordinator.acknowledge(reservation).outcome == Outcome::Accepted);
    auto* shard = coordinator.registry().find(prepared.shard);
    CHECK(shard->phase() == Phase::CommittedInactive);
    const auto digest = shard->payload_digest();
    const auto tick = coordinator.world().completed_tick_index();
    for (unsigned delay = 0; delay < 8; ++delay) CHECK(coordinator.step().outcome == Outcome::Fenced);
    CHECK(shard->payload_digest() == digest && coordinator.world().completed_tick_index() == tick);
    CHECK(coordinator.acknowledge(reservation).outcome == Outcome::Accepted);
    CHECK(coordinator.registry().inventory_counts().structural == 9);
    CHECK(coordinator.accounting().promoted[static_cast<std::uint8_t>(Material::Wood)] == 9);
    CHECK(coordinator.acknowledge(ack_for(coordinator, AckKind::BodyActivated)).outcome == Outcome::Stale);
    auto terrain = ack_for(coordinator, AckKind::TerrainInstalled);
    std::vector<TerrainReceipt> corrupted(terrain.terrain.begin(), terrain.terrain.end());
    CHECK(!corrupted.empty());
    ++corrupted[0].digest;
    auto wrong = terrain; wrong.terrain = corrupted;
    CHECK(coordinator.acknowledge(wrong).outcome == Outcome::Stale);
    wrong = terrain; wrong.terrain = {};
    CHECK(coordinator.acknowledge(wrong).outcome == Outcome::Stale);
    CHECK(shard->phase() == Phase::CommittedInactive);
    terrain = ack_for(coordinator, AckKind::TerrainInstalled);
    CHECK(coordinator.acknowledge(terrain).outcome == Outcome::Accepted);
    CHECK(shard->phase() == Phase::ReadyToActivate);
    CHECK(!shard->chemistry_allowed());
    CHECK(coordinator.world().transient_obstacle_at(31, 31) != 0); // Applied mask, not queued receipt.
    CHECK(coordinator.step().outcome == Outcome::Fenced);
    CHECK(shard->payload_digest() == digest);
    const auto activation = ack_for(coordinator, AckKind::BodyActivated);
    CHECK(coordinator.acknowledge(activation).outcome == Outcome::Accepted);
    CHECK(shard->phase() == Phase::Active && shard->chemistry_allowed());
    CHECK(coordinator.acknowledge(activation).outcome == Outcome::Accepted);
    CHECK(coordinator.acknowledge(reservation).outcome == Outcome::Accepted);
    CHECK(coordinator.registry().inventory_counts().structural == 9);
    auto stale = activation; ++stale.geometry_revision;
    CHECK(coordinator.acknowledge(stale).outcome != Outcome::Accepted);
}

void cancellation_reset_and_old_control() {
    Coordinator coordinator(small_config());
    make_supported(coordinator); erase_support(coordinator);
    auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    const auto before = coordinator.inspect_world(31, 31);
    const auto old_ack = ack_for(coordinator, AckKind::PhysicsReserved);
    CHECK(coordinator.cancel(prepared.transaction).outcome == Outcome::Cancelled);
    CHECK(coordinator.cancel(prepared.transaction).outcome == Outcome::Cancelled);
    CHECK(coordinator.inspect_world(31, 31) == before);
    CHECK(coordinator.registry().inventory_counts().total() == 0);
    CHECK(coordinator.acknowledge(old_ack).outcome != Outcome::Accepted);
    const auto old_transaction = prepared.transaction;
    CHECK(coordinator.reset(0, 12).outcome == Outcome::Accepted);
    make_supported(coordinator); erase_support(coordinator);
    prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(prepared.transaction != old_transaction);
    CHECK(coordinator.cancel(old_transaction).outcome == Outcome::Expired);
    CHECK(coordinator.snapshot().promotion.present);
    CHECK(coordinator.acknowledge(old_ack).outcome == Outcome::Retired);
    CHECK(coordinator.acknowledge(ack_for(coordinator, AckKind::PhysicsReserved)).outcome == Outcome::Accepted);
    CHECK(coordinator.cancel(prepared.transaction).outcome == Outcome::Quarantined);
    CHECK(coordinator.snapshot().quarantined);
    CHECK(coordinator.registry().inventory_counts().structural == 9);
    CHECK(world_population(coordinator, Material::Wood) == 0);
    CHECK(coordinator.step().outcome == Outcome::Quarantined);
    CHECK(coordinator.reset(0, 13).outcome == Outcome::Accepted);
    CHECK(coordinator.accounting().reset_disposed[static_cast<std::uint8_t>(Material::Wood)] == 9);
    CHECK(coordinator.registry().find(prepared.shard) == nullptr);
    CHECK(coordinator.registry().inventory_counts().total() == 0);
}

void capacities_epoch_wrap_and_three_owners() {
    auto limited = small_config(); limited.limits.max_area = 16; limited.limits.max_total_area = 48;
    Coordinator capacity(limited);
    make_supported(capacity); erase_support(capacity);
    CHECK(discover(capacity).outcome == Outcome::Capacity); // Nine cells need a 25-cell bbox+port ring.
    CHECK(world_population(capacity, Material::Wood) == 9);
    CHECK(capacity.registry().inventory_counts().total() == 0);

    auto small_discovery = small_config(); small_discovery.discovery_budget = 4;
    Coordinator incomplete(small_discovery);
    make_supported(incomplete); erase_support(incomplete);
    CHECK(discover(incomplete).outcome == Outcome::Capacity);
    CHECK(world_population(incomplete, Material::Wood) == 9);
    CHECK(incomplete.registry().inventory_counts().total() == 0);

    Coordinator coordinator(small_config());
    for (unsigned i = 0; i < 255; ++i) CHECK(coordinator.step().outcome == Outcome::Accepted);
    CHECK(coordinator.world().completed_tick_index() >= 256);
    for (int x : {20, 50, 80}) { make_supported(coordinator, x, 30); erase_support(coordinator, x, 30); }
    std::array<Handle, 3> handles{};
    for (auto& handle : handles) {
        const auto prepared = discover(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) return;
        handle = prepared.shard;
        CHECK(activate(coordinator, handle));
        const auto* shard = coordinator.registry().find(handle);
        CHECK(shard->captured_tick() >= 256);
        for (std::size_t index = 0; index < shard->area(); ++index) if (shard->occupied(index))
            CHECK(shard->schedule(index).next_due_tick > shard->captured_tick());
    }
    CHECK(handles[0].id != handles[1].id && handles[1].id != handles[2].id);
    CHECK(coordinator.registry().inventory_counts().structural == 27);
    CHECK(world_population(coordinator, Material::Wood) == 0);
    const auto tick = coordinator.world().completed_tick_index();
    CHECK(coordinator.step().outcome == Outcome::Stale); // All live bodies must be represented.
    CHECK(coordinator.world().completed_tick_index() == tick);
    auto poses = next_poses(coordinator);
    CHECK(poses.size() == 3);
    auto duplicate = poses; duplicate[1] = duplicate[0];
    CHECK(coordinator.step(duplicate).outcome == Outcome::Invalid);
    auto fast = poses; fast[0].x += 10;
    CHECK(coordinator.step(fast).outcome == Outcome::Unsupported);
    CHECK(coordinator.world().completed_tick_index() == tick);
    CHECK(coordinator.step(poses).outcome == Outcome::Accepted);
    CHECK(coordinator.world().completed_tick_index() == tick + 1);
    CHECK(coordinator.step(poses).outcome == Outcome::Stale); // Pose serial replay.
}

void pose_refusal_keeps_pose_and_mask_coherent() {
    Coordinator coordinator(small_config());
    make_supported(coordinator, 2, 30); erase_support(coordinator, 2, 30);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(activate(coordinator, prepared.shard));
    auto poses = next_poses(coordinator);
    const auto before = poses[0];
    const auto tick = coordinator.world().completed_tick_index();
    // This admitted translation has valid identity, but resulting occupancy is
    // outside the resident Lab. The new pose must not partly commit.
    poses[0].x -= 2.5;
    const auto refusal = coordinator.step(poses);
    CHECK(refusal.outcome == Outcome::NotResident || refusal.outcome == Outcome::Quarantined);
    CHECK(coordinator.world().completed_tick_index() == tick);
    if (refusal.outcome != Outcome::Quarantined) {
        for (const auto& body : coordinator.snapshot().bodies) if (body.has_body) {
            CHECK(body.pose.x == before.x && body.pose.y == before.y &&
                body.pose.rotation == before.rotation && body.pose.pose_serial + 1 == before.pose_serial);
        }
    }
    CHECK(coordinator.registry().inventory_counts().structural == 9);
    CHECK(coordinator.world().transient_obstacle_at(2, 30) != 0);
}

void disjoint_shapes_can_share_a_raster_cell() {
    Coordinator coordinator(small_config());
    for (int x : {10, 12}) {
        CHECK(coordinator.edit(x, 30, {Material::Wood, 0, 0, 200}).outcome == Outcome::Accepted);
        CHECK(coordinator.edit(x, 31, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
        CHECK(coordinator.edit(x, 31, empty()).outcome == Outcome::Accepted);
    }
    for (unsigned i = 0; i < 2; ++i) {
        const auto prepared = discover(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) return;
        CHECK(activate(coordinator, prepared.shard));
    }
    auto poses = next_poses(coordinator);
    CHECK(poses.size() == 2);
    for (auto& pose : poses) {
        const auto* shard = coordinator.registry().find(pose.shard);
        // Unit squares [10.2,11.2] and [11.8,12.8] have a physical gap of .6,
        // while both legitimately contribute to native raster cell 11.
        pose.x += shard->bounds().x == 9 ? .2 : -.2;
    }
    CHECK(coordinator.step(poses).outcome == Outcome::Accepted);
    CHECK(coordinator.world().transient_obstacle_at(11, 30) != 0);
    CHECK(coordinator.registry().inventory_counts().structural == 2);
    CHECK(world_population(coordinator, Material::Wood) == 0);
    CHECK(coordinator.accounting().promoted[static_cast<std::uint8_t>(Material::Wood)] == 2);
}

void one_mutation_discovers_every_disconnected_component() {
    Coordinator coordinator(small_config());
    for (const auto point : std::array<std::array<int, 2>, 4>{{{30, 30}, {29, 30}, {31, 30}, {30, 29}}})
        CHECK(coordinator.edit(point[0], point[1], {Material::Wood, 0, 0, 200}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(30, 31, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    // Consume all authoring dirty seeds while the single component is anchored.
    for (unsigned i = 0; i < 32; ++i) {
        const auto result = coordinator.prepare_next();
        CHECK(result.outcome == Outcome::Busy || result.outcome == Outcome::Anchored);
    }
    CHECK(coordinator.edit(30, 30, empty()).outcome == Outcome::Accepted);
    for (unsigned i = 0; i < 3; ++i) {
        const auto prepared = discover(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) return;
        CHECK(coordinator.registry().find(prepared.shard)->counts().structural == 1);
        CHECK(activate(coordinator, prepared.shard));
    }
    CHECK(world_population(coordinator, Material::Wood) == 0);
    CHECK(coordinator.registry().inventory_counts().structural == 3);
}

void burning_world_capture_continues_while_sleeping_and_moving() {
    namespace chemistry = material_lifecycle;
    Coordinator coordinator(small_config());
    constexpr std::int64_t x = 31, y = 31;
    CHECK(coordinator.edit(x, y, {Material::Wood, 219, 5, 654}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(x, y + 1, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    // These are actual World opportunities before promotion, not an authored
    // countdown substituted after the transfer.
    for (unsigned i = 0; i < 2; ++i) CHECK(coordinator.step().outcome == Outcome::Accepted);
    const auto captured = coordinator.inspect_world(x, y);
    CHECK(captured.material == Material::Wood && captured.state_b == 4);
    CHECK(captured.state_a == 219 && captured.temperature == 654);
    CHECK(coordinator.edit(x, y + 1, empty()).outcome == Outcome::Accepted);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(activate(coordinator, prepared.shard));
    const auto* shard = coordinator.registry().find(prepared.shard);
    const auto stable_bounds = shard->bounds();
    constexpr std::size_t cell = 4; // Centre of the tight one-cell payload plus port ring.
    CHECK(shard->payload(cell) == captured);
    auto expected = captured;
    for (unsigned i = 0; i < 12 && expected.material != Material::Empty; ++i) {
        const auto next_tick = coordinator.world().completed_tick_index() + 1;
        const auto transition = chemistry::combustible(expected.material, expected.state_a,
            expected.state_b, chemistry::lane_due(next_tick, x, y, 2, 191), false);
        if (transition.write) expected = {transition.material, transition.state_a, transition.state_b, expected.temperature};
        auto poses = next_poses(coordinator);
        CHECK(poses.size() == 1);
        poses[0].sleeping = true;
        poses[0].x += .15; poses[0].rotation += .01;
        CHECK(coordinator.step(poses).outcome == Outcome::Accepted);
        CHECK(coordinator.world().completed_tick_index() == next_tick);
        CHECK(shard->payload(cell) == expected);
        CHECK(shard->bounds() == stable_bounds); // Motion does not reseed logical lanes.
        install_geometry(coordinator);
    }
    CHECK(expected.material == Material::Empty);
    CHECK(shard->counts().structural == 0);
    CHECK(coordinator.accounting().destroyed[static_cast<std::uint8_t>(Material::Wood)] == 1);
    CHECK(coordinator.accounting().created[static_cast<std::uint8_t>(Material::Smoke)] == 0);
    CHECK(coordinator.accounting().created[static_cast<std::uint8_t>(Material::Fire)] == 0);
}

void blocked_product_lifetime_and_draining_inventory() {
    Coordinator coordinator(small_config());
    constexpr int x = 31, y = 31;
    CHECK(coordinator.edit(x, y, {Material::Wood, 77, 8, 510}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(x, y + 1, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(x, y + 1, empty()).outcome == Outcome::Accepted);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(activate(coordinator, prepared.shard));
    // Actual resident occupied destinations prevent output. The product must
    // still occupy one spatial local carrier; it is not an outbox copy.
    for (int dy = -4; dy <= 4; ++dy) for (int dx = -4; dx <= 4; ++dx)
        if (dx || dy) CHECK(coordinator.edit(x + dx, y + dy, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    const auto* shard = coordinator.registry().find(prepared.shard);
    for (unsigned i = 0; i < 3 && shard->counts().products == 0; ++i) sleeping_step(coordinator);
    CHECK(shard->counts().products == 1);
    std::size_t product = shard->area();
    for (std::size_t at = 0; at < shard->area(); ++at) if (shard->role(at) == Role::Product) product = at;
    CHECK(product < shard->area());
    if (product >= shard->area()) return;
    CHECK(shard->payload(product).material == Material::Fire && shard->payload(product).state_a == 32);
    CHECK(shard->schedule(product).birth_tick == coordinator.world().completed_tick_index());
    CHECK(shard->schedule(product).next_due_tick > shard->schedule(product).birth_tick);
    const auto birth = shard->schedule(product).birth_tick;
    const auto incarnation = shard->schedule(product).incarnation;
    for (unsigned tick = 1; tick <= 32; ++tick) {
        sleeping_step(coordinator);
        CHECK(shard->counts().products == 1);
        CHECK(shard->occupied(product) && !shard->structural(product));
        CHECK(coordinator.world().completed_tick_index() == birth + tick);
        if (tick < 32) {
            CHECK(shard->payload(product).material == Material::Fire);
            CHECK(shard->payload(product).state_a == 32 - tick);
            CHECK(shard->schedule(product).incarnation == incarnation);
        }
    }
    CHECK(shard->payload(product).material == Material::Smoke);
    CHECK(shard->payload(product).state_a == material_definition(Material::Smoke).initial_state_a);
    CHECK(shard->schedule(product).incarnation != incarnation);
    CHECK(shard->counts().structural == 0 && shard->phase() == Phase::Draining);
    CHECK(shard->owns_inventory() && shard->counts().products == 1);
    CHECK(coordinator.accounting().created[static_cast<std::uint8_t>(Material::Fire)] == 1);
    CHECK(coordinator.accounting().destroyed[static_cast<std::uint8_t>(Material::Fire)] == 1);
    CHECK(coordinator.accounting().created[static_cast<std::uint8_t>(Material::Smoke)] == 1);
    CHECK(coordinator.accounting().destroyed[static_cast<std::uint8_t>(Material::Wood)] == 1);
    CHECK(coordinator.accounting().emitted[static_cast<std::uint8_t>(Material::Fire)] == 0);
    CHECK(world_population(coordinator, Material::Fire) == 0);
    CHECK(world_population(coordinator, Material::Smoke) == 0);
}

void chemistry_perforates_geometry_beyond_eight_shapes() {
    Coordinator coordinator(small_config());
    std::uint32_t removed = 0;
    for (int y = 30; y < 45; ++y) for (int x = 30; x < 45; ++x) {
        const bool hole = x == 37 || (x > 30 && x < 44 && y > 30 && y < 44 && x % 2 == 0 && y % 2 == 0);
        removed += hole;
        CHECK(coordinator.edit(x, y, {Material::Wood, 0, static_cast<std::uint8_t>(hole ? 1 : 0), 200}).outcome == Outcome::Accepted);
    }
    for (int x = 30; x < 45; ++x)
        CHECK(coordinator.edit(x, 45, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    for (int x = 30; x < 45; ++x) CHECK(coordinator.edit(x, 45, empty()).outcome == Outcome::Accepted);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(activate(coordinator, prepared.shard));
    const auto* shard = coordinator.registry().find(prepared.shard);
    const auto origin = shard->bounds();
    for (unsigned tick = 0; tick < 2; ++tick) {
        const auto obsolete = geometry_ack(coordinator, prepared.shard);
        CHECK(coordinator.step(next_poses(coordinator)).outcome == Outcome::Accepted);
        CHECK(coordinator.paused());
        const auto now = coordinator.world().completed_tick_index();
        CHECK(coordinator.acknowledge(obsolete).outcome == Outcome::Stale);
        CHECK(coordinator.step(next_poses(coordinator)).outcome == Outcome::Fenced);
        CHECK(coordinator.world().completed_tick_index() == now);
        install_geometry(coordinator);
    }
    CHECK(shard->counts().structural == 225 - removed);
    CHECK(shard->geometry().shapes.size() > 8);
    CHECK(shard->geometry().split_pending && shard->geometry().islands == 2);
    CHECK(shard->geometry().mass.mass == 225 - removed);
    CHECK(shard->bounds() == origin);
    CHECK(shard->chemistry_allowed());
    std::vector<unsigned> cover(shard->area());
    for (const auto& shape : shard->geometry().shapes)
        for (unsigned y = shape.y; y < shape.y + shape.height; ++y)
            for (unsigned x = shape.x; x < shape.x + shape.width; ++x)
                ++cover[static_cast<std::size_t>(y) * origin.width + x];
    for (std::size_t at = 0; at < shard->area(); ++at)
        CHECK(cover[at] == static_cast<unsigned>(shard->structural(at)));
    const std::uint32_t surviving_cell = origin.width + 1;
    CHECK(coordinator.ignite_shard(prepared.shard, surviving_cell).outcome == Outcome::Accepted);
    sleeping_step(coordinator); sleeping_step(coordinator);
    CHECK(shard->payload(surviving_cell).material == Material::Wood);
    CHECK(shard->payload(surviving_cell).state_b < 240); // Split-pending does not freeze burning.
}
} // namespace

int main() {
    finite_coordinate_configuration();
    ordinary_support_loss_and_exact_capture();
    state_temperature_and_aba_refuse();
    pending_event_and_malformed_receipts();
    installed_receipts_and_chemistry_fence();
    cancellation_reset_and_old_control();
    capacities_epoch_wrap_and_three_owners();
    pose_refusal_keeps_pose_and_mask_coherent();
    disjoint_shapes_can_share_a_raster_cell();
    one_mutation_discovers_every_disconnected_component();
    burning_world_capture_continues_while_sleeping_and_moving();
    blocked_product_lifetime_and_draining_inventory();
    chemistry_perforates_geometry_beyond_eight_shapes();
    std::printf("ObjectShard coordinator: %llu checks, %llu failures\n",
        static_cast<unsigned long long>(checks), static_cast<unsigned long long>(failures));
    return failures == 0 ? 0 : 1;
}
