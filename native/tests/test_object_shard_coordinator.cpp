#include "cybersand/object_shard_coordinator.hpp"
#include "cybersand/object_shard_m4_mutable_adapter.hpp"
#include "cybersand/object_shard_contact.hpp"
#include "cybersand/object_shard_mutation.hpp"
#include "cybersand/material_lifecycle.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <limits>
#include <stdexcept>
#include <vector>
#include <thread>

// Test-only friend seam. These mutations execute real World APIs while command
// admission is paused, modelling an erroneous/stale external owner. Production
// callers have no mutable World access through Coordinator.
namespace cybersand::object_shard {
struct MutationJournalTestAccess {
    static void generations(MutationJournal& journal,std::uint64_t material,std::uint64_t topology) {
        journal.revision_=material;journal.topology_revision_=topology;
    }
};
struct CoordinatorTestAccess {
    static World& world(Coordinator& coordinator) { return *coordinator.world_; }
    static Registry& registry(Coordinator& coordinator) { return coordinator.registry_; }
    static std::span<const Exposure> exposures(const Coordinator& coordinator) { return coordinator.exposures_; }
    static std::size_t ingress_fences(const Coordinator& coordinator) { return coordinator.ingress_fences_.size(); }
    static bool pocket_fenced(const Coordinator& coordinator,Handle handle,std::uint32_t cell) {
        return coordinator.pocket_fenced(handle,cell);
    }
    static void remove_ingress_history_capacity(Coordinator& coordinator) {
        decltype(coordinator.ingress_fences_) empty;
        coordinator.ingress_fences_.swap(empty);
    }
    static auto restrict_ingress_history_capacity(Coordinator& coordinator) {
        auto bounded=coordinator.ingress_fences_;
        bounded.swap(coordinator.ingress_fences_);return bounded;
    }
    template<class T> static void restore_ingress_history_capacity(Coordinator& coordinator,T& previous) {
        coordinator.ingress_fences_.swap(previous);
    }
    static auto remove_relocation_capacity(Coordinator& coordinator) {
        decltype(coordinator.relocations_) previous;
        previous.swap(coordinator.relocations_);
        return previous;
    }
    template<class T> static void restore_relocation_capacity(Coordinator& coordinator, T& previous) {
        coordinator.relocations_.swap(previous);
    }
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
    // Initial discovery and a deliberately tiny budget can span many calls.
    // This is a work limit per call, never an implicit component-size limit.
    const auto maximum_attempts = 3 * coordinator.config().world_bounds.area() /
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
std::uint64_t owned_population(Coordinator& coordinator, Material material) {
    auto count = world_population(coordinator, material);
    for (const auto& shard : coordinator.registry().shards()) if (shard.owns_inventory())
        for (std::size_t at = 0; at < shard.area(); ++at)
            count += shard.occupied(at) && shard.payload(at).material == material;
    return count;
}
void check_population_balance(Coordinator& coordinator) {
    const auto& accounting = coordinator.accounting();
    auto actual = coordinator.world().quantity_ledger().material_cells;
    for (const auto& shard : coordinator.registry().shards()) if (shard.owns_inventory())
        for (std::size_t at = 0; at < shard.area(); ++at) if (shard.occupied(at))
            ++actual[static_cast<std::uint8_t>(shard.payload(at).material)];
    bool balanced = true;
    for (std::size_t index = 1; index < kQuantityMaterialSlots; ++index) {
        const auto expected = static_cast<std::int64_t>(accounting.setup_created[index]) +
            static_cast<std::int64_t>(accounting.authored_created[index]) -
            static_cast<std::int64_t>(accounting.authored_destroyed[index]) +
            accounting.world_tick_delta[index] + static_cast<std::int64_t>(accounting.created[index]) -
            static_cast<std::int64_t>(accounting.destroyed[index]) -
            static_cast<std::int64_t>(accounting.expired[index]) -
            static_cast<std::int64_t>(accounting.reset_disposed[index]);
        if (static_cast<std::int64_t>(actual[index]) != expected) {
            balanced = false;
            std::fprintf(stderr, "Population imbalance material %zu: actual %llu, accounted %lld\n", index,
                static_cast<unsigned long long>(actual[index]), static_cast<long long>(expected));
        }
    }
    CHECK(balanced);
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
TransferRequest transfer_request(Coordinator& coordinator, Handle handle, std::uint32_t cell,
        std::int64_t world_x, std::int64_t world_y, Payload expected) {
    const auto* shard = coordinator.registry().find(handle);
    CHECK(shard != nullptr && cell < shard->area());
    for (const auto& body : coordinator.snapshot().bodies) if (body.shard == handle) {
        TransferRequest request{handle, coordinator.next_transaction(), body.body_generation,
            shard->geometry().revision, body.pose.pose_serial, cell, shard->schedule(cell).incarnation,
            world_x, world_y, expected};
        request.world_witness = coordinator.world_witness(world_x, world_y);
        return request;
    }
    CHECK(false);
    return {};
}
Handle single_wood(Coordinator& coordinator, int x, int y, std::uint8_t burn) {
    CHECK(coordinator.edit(x, y, {Material::Wood, 77, burn, 510}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(x, y + 1, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(x, y + 1, empty()).outcome == Outcome::Accepted);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome == Outcome::Accepted) CHECK(activate(coordinator, prepared.shard));
    return prepared.shard;
}
Handle open_pocket(Coordinator& coordinator, int clear_width = 1, int center = 31) {
    const int left = center - clear_width / 2 - 1, right = left + clear_width + 1;
    for (int x : {left, right})
        CHECK(coordinator.edit(x, 31, {Material::Wood, 0, 0, 200}).outcome == Outcome::Accepted);
    for (int x = left; x <= right; ++x)
        CHECK(coordinator.edit(x, 32, {Material::Wood, 0, 0, 200}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(center, 33, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(center, 33, empty()).outcome == Outcome::Accepted);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome == Outcome::Accepted) CHECK(activate(coordinator, prepared.shard));
    return prepared.shard;
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
    const auto first_disposed = coordinator.accounting().reset_disposed[static_cast<std::uint8_t>(Material::Wood)];
    const auto first_owned = owned_population(coordinator, Material::Wood);
    CHECK(coordinator.reset(0, 12).outcome == Outcome::Accepted);
    CHECK(coordinator.accounting().reset_disposed[static_cast<std::uint8_t>(Material::Wood)] == first_disposed + first_owned);
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
    const auto second_disposed = coordinator.accounting().reset_disposed[static_cast<std::uint8_t>(Material::Wood)];
    const auto second_owned = owned_population(coordinator, Material::Wood);
    CHECK(coordinator.reset(0, 13).outcome == Outcome::Accepted);
    CHECK(coordinator.accounting().reset_disposed[static_cast<std::uint8_t>(Material::Wood)] == second_disposed + second_owned);
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
    const auto resumed=discover(incomplete);
    CHECK(resumed.outcome == Outcome::Accepted);
    CHECK(incomplete.snapshot().admission.work_peak<=small_discovery.discovery_budget);
    CHECK(world_population(incomplete, Material::Wood) == 9);
    CHECK(incomplete.registry().inventory_counts().total() == 0);
    if (resumed.outcome==Outcome::Accepted) CHECK(incomplete.cancel(resumed.transaction).outcome==Outcome::Cancelled);

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
    auto config = small_config(); config.transfer_budget = 0;
    Coordinator coordinator(config);
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

void authentic_fire_output_world_smoke_and_receipt_retirement() {
    auto config = small_config(); config.transfer_budget = 0;
    Coordinator coordinator(config);
    const auto handle = single_wood(coordinator, 31, 31, 8);
    const auto* shard = coordinator.registry().find(handle);
    CHECK(shard != nullptr);
    if (!shard) return;
    for (unsigned i = 0; i < 3 && shard->counts().products == 0; ++i) sleeping_step(coordinator);
    std::uint32_t product = static_cast<std::uint32_t>(shard->area());
    for (std::uint32_t at = 0; at < shard->area(); ++at)
        if (shard->payload(at).material == Material::Fire) product = at;
    CHECK(product < shard->area());
    if (product >= shard->area()) return;
    const auto payload = shard->payload(product);
    CHECK(payload.material == Material::Fire && payload.state_a == 32);
    const auto bounds = shard->bounds();
    const auto wx = bounds.x + product % bounds.width, wy = bounds.y + product / bounds.width;
    CHECK(coordinator.edit(wx, wy, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    const auto blocked = transfer_request(coordinator, handle, product, wx, wy, payload);
    CHECK(coordinator.emit(blocked).outcome == Outcome::DestinationUnavailable);
    CHECK(shard->payload(product) == payload && shard->counts().products == 1);
    CHECK(coordinator.accounting().emitted[static_cast<std::uint8_t>(Material::Fire)] == 0);
    CHECK(coordinator.edit(wx, wy, empty()).outcome == Outcome::Accepted);
    // A prior refusal stays terminal even after its destination becomes empty.
    CHECK(coordinator.emit(blocked).outcome == Outcome::DestinationUnavailable);
    CHECK(coordinator.inspect_world(wx, wy).material == Material::Empty);
    auto delivered = transfer_request(coordinator, handle, product, wx, wy, payload);
    auto future = delivered; future.sequence += 17;
    const auto sequence = coordinator.next_transaction();
    CHECK(coordinator.emit(future).outcome == Outcome::Stale);
    CHECK(coordinator.next_transaction() == sequence);
    CHECK(coordinator.emit(delivered).outcome == Outcome::Accepted);
    CHECK(coordinator.inspect_world(wx, wy) == payload);
    CHECK(shard->role(product) == Role::Empty && !shard->occupied(product));
    CHECK(coordinator.accounting().emitted[static_cast<std::uint8_t>(Material::Fire)] == 1);
    CHECK(world_population(coordinator, Material::Fire) == 1);
    CHECK(coordinator.emit(delivered).outcome == Outcome::Accepted);
    CHECK(world_population(coordinator, Material::Fire) == 1);
    check_population_balance(coordinator);
    auto altered = delivered; --altered.expected.state_a;
    CHECK(coordinator.emit(altered).outcome == Outcome::Stale);
    bool world_smoke = false;
    for (unsigned tick = 0; tick < 40 && !world_smoke; ++tick) {
        sleeping_step(coordinator);
        world_smoke = world_population(coordinator, Material::Smoke) != 0;
    }
    CHECK(world_smoke);
    CHECK(coordinator.accounting().created[static_cast<std::uint8_t>(Material::Smoke)] == 0);
    check_population_balance(coordinator);
    const auto population = coordinator.world().quantity_ledger().material_cells;
    // Evict detailed receipts; the monotonic retired sequence may not reopen.
    for (unsigned i = 0; i < 80; ++i) {
        auto refused = delivered; refused.sequence = coordinator.next_transaction();
        ++refused.capability_version;
        CHECK(coordinator.emit(refused).outcome != Outcome::Accepted);
    }
    CHECK(coordinator.emit(delivered).outcome == Outcome::Expired);
    CHECK(coordinator.world().quantity_ledger().material_cells == population);
    CHECK(coordinator.reset(0, 1).outcome == Outcome::Accepted);
    CHECK(coordinator.emit(delivered).outcome == Outcome::Retired);
    check_population_balance(coordinator);
}

void real_falling_sand_ingress_aba_and_destroyed_pocket() {
    auto config = small_config(); config.transfer_budget = 0;
    Coordinator coordinator(config);
    const auto handle = open_pocket(coordinator);
    auto* shard = CoordinatorTestAccess::registry(coordinator).find(handle);
    CHECK(shard != nullptr);
    if (!shard) return;
    const auto bounds = shard->bounds();
    const auto pocket = static_cast<std::uint32_t>((31 - bounds.y) * bounds.width + 31 - bounds.x);
    CHECK(shard->role(pocket) == Role::Empty);
    const auto geometry_before = shard->geometry();
    CHECK(coordinator.edit(31, 27, {Material::Sand, 213, 217, -470}).outcome == Outcome::Accepted);
    bool arrived = false;
    for (unsigned step = 0; step < 16 && !arrived; ++step) {
        sleeping_step(coordinator);
        arrived = coordinator.inspect_world(31, 31).material == Material::Sand;
    }
    CHECK(arrived);
    CHECK(coordinator.inspect_world(31, 27).material == Material::Empty);
    if (!arrived) return;
    const auto payload = coordinator.inspect_world(31, 31);
    CHECK(payload.temperature == -470);
    auto unsupported = transfer_request(coordinator, handle, pocket, 31, 31, payload);
    unsupported.expected.material = Material::Water;
    CHECK(coordinator.ingest(unsupported).outcome == Outcome::Unsupported);
    CHECK(coordinator.inspect_world(31, 31) == payload && shard->counts().cargo == 0);
    const auto stale = transfer_request(coordinator, handle, pocket, 31, 31, payload);
    auto& world = CoordinatorTestAccess::world(coordinator);
    CHECK(world.set_cell_state(31, 31, Material::Dust, 0, 0));
    CHECK(world.set_cell_state(31, 31, Material::Sand, payload.state_a, payload.state_b));
    world.set_temperature(31, 31, payload.temperature);
    CHECK(coordinator.inspect_world(31, 31) == payload);
    CHECK(coordinator.ingest(stale).outcome == Outcome::Stale);
    CHECK(world_population(coordinator, Material::Sand) == 1 && shard->counts().cargo == 0);
    const auto request = transfer_request(coordinator, handle, pocket, 31, 31, payload);
    CHECK(coordinator.ingest(request).outcome == Outcome::Accepted);
    CHECK(coordinator.inspect_world(31, 31).material == Material::Empty);
    CHECK(shard->payload(pocket) == payload && shard->role(pocket) == Role::Cargo);
    CHECK(!shard->structural(pocket) && shard->counts().structural == 5 && shard->counts().cargo == 1);
    CHECK(coordinator.accounting().ingested[static_cast<std::uint8_t>(Material::Sand)] == 1);
    CHECK(coordinator.ingest(request).outcome == Outcome::Accepted);
    CHECK(shard->counts().cargo == 1 && world_population(coordinator, Material::Sand) == 0);
    check_population_balance(coordinator);
    sleeping_step(coordinator);
    CHECK(shard->geometry().mass.mass == 6);
    CHECK(shard->geometry().mask_digest == geometry_before.mask_digest);
    CHECK(shard->geometry().shape_digest != geometry_before.shape_digest); // Mass is bound to the receipt.
    CHECK(coordinator.world().transient_obstacle_at(31, 31) != 0); // Cargo reserves native occupancy.
    // A deterministic material-state fixture makes the next real combustion
    // opportunities consume the retainers. The Sand is never a structural bond.
    const auto tick = coordinator.world().completed_tick_index();
    for (std::uint32_t at = 0; at < shard->area(); ++at) if (shard->structural(at)) {
        auto burning = shard->payload(at); burning.state_b = 1;
        CHECK(shard->set_cell(at, burning, Role::Structural, tick) == Outcome::Accepted);
    }
    sleeping_step(coordinator); sleeping_step(coordinator);
    CHECK(shard->counts().structural == 0 && shard->counts().cargo == 1);
    CHECK(shard->phase() == Phase::Draining && shard->owns_inventory());
    CHECK(shard->payload(pocket) == payload);
    sleeping_step(coordinator); // Retired body mask is now absent; release anchor remains.
    CHECK(coordinator.world().transient_obstacle_at(31, 31) == 0);
    CHECK(coordinator.edit(31, 31, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    auto release = transfer_request(coordinator, handle, pocket, 31, 31, payload);
    CHECK(coordinator.emit(release).outcome == Outcome::DestinationUnavailable);
    CHECK(shard->payload(pocket) == payload);
    CHECK(coordinator.edit(31, 31, empty()).outcome == Outcome::Accepted);
    release = transfer_request(coordinator, handle, pocket, 31, 31, payload);
    CHECK(coordinator.emit(release).outcome == Outcome::Accepted);
    CHECK(coordinator.inspect_world(31, 31) == payload && shard->counts().cargo == 0);
    CHECK(coordinator.accounting().emitted[static_cast<std::uint8_t>(Material::Sand)] == 1);
    CHECK(coordinator.emit(release).outcome == Outcome::Accepted);
    CHECK(world_population(coordinator, Material::Sand) == 1);
    check_population_balance(coordinator);
}

void wide_rotated_pocket_admits_real_falling_sand() {
    Coordinator coordinator(small_config());
    const auto handle = open_pocket(coordinator, 3);
    const auto* shard = coordinator.registry().find(handle);
    CHECK(shard != nullptr);
    if (!shard) return;
    auto poses = next_poses(coordinator);
    poses[0].x += .13; poses[0].y += .07; poses[0].rotation = .01;
    CHECK(coordinator.step(poses).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(31, 27, {Material::Sand, 213, 217, -470}).outcome == Outcome::Accepted);
    Payload at_aperture{};
    bool observed_world_arrival = false;
    for (unsigned tick = 0; tick < 16 && shard->counts().cargo == 0; ++tick) {
        sleeping_step(coordinator);
        const auto source = coordinator.inspect_world(31, 31);
        if (source.material == Material::Sand) {at_aperture = source; observed_world_arrival = true;}
    }
    CHECK(observed_world_arrival);
    CHECK(shard->counts().cargo == 1);
    CHECK(coordinator.accounting().ingested[static_cast<std::uint8_t>(Material::Sand)] == 1);
    CHECK(world_population(coordinator, Material::Sand) == 0);
    for (std::size_t at = 0; at < shard->area(); ++at) if (shard->role(at) == Role::Cargo) {
        CHECK(shard->payload(at) == at_aperture);
        CHECK(!shard->structural(at));
    }
    CHECK(shard->geometry().mass.mass == 8); // Seven retainers and one actual grain.
}

void overlap_relocation_cannot_create_a_pocket_entry_witness() {
    Coordinator coordinator(small_config());
    const auto handle = open_pocket(coordinator, 3);
    const auto* shard = coordinator.registry().find(handle);
    CHECK(shard != nullptr);
    if (!shard) return;
    const auto before = next_poses(coordinator)[0];
    std::array<std::pair<int, int>, 256> origins{};
    std::array<Outcome, 256> entry_outcomes{};
    unsigned next_identity = 1;
    for (int y = 27; y <= 36; ++y) for (int x = 25; x <= 38; ++x) {
        if (coordinator.world().transient_obstacle_at(x, y) || (y == 31 && x >= 30 && x <= 32)) continue;
        CHECK(coordinator.edit(x, y, {Material::Sand, static_cast<std::uint16_t>(next_identity), 217, -470}).outcome
            == Outcome::Accepted);
        origins[next_identity++] = {x, y};
    }
    auto after = next_poses(coordinator);
    after[0].x += .25;
    for (unsigned id = 1; id < next_identity; ++id) {
        const auto [x, y] = origins[id];
        entry_outcomes[id] = contact::sand_pocket_witness(*shard,
            {before.x, before.y, before.rotation}, {after[0].x, after[0].y, after[0].rotation},
            {x + .5, y + .5}).outcome;
    }
    // Mechanical overlap resolution is conservative World relocation, never
    // permission to create ingress through a retaining side/floor. Preserve
    // each original World source witness before any relocation can erase it.
    CHECK(coordinator.step(after).outcome == Outcome::Accepted);
    for (std::size_t at = 0; at < shard->area(); ++at) if (shard->role(at) == Role::Cargo) {
        const auto payload = shard->payload(at);
        CHECK(payload.state_a > 0 && payload.state_a < next_identity);
        if (payload.state_a > 0 && payload.state_a < next_identity)
            CHECK(entry_outcomes[payload.state_a] == Outcome::Accepted);
        CHECK(payload.state_b == 217 && payload.temperature == -470);
    }
    CHECK(owned_population(coordinator, Material::Sand) == next_identity - 1);
    check_population_balance(coordinator);
}

void side_entry_refusal_cannot_be_laundered_by_a_stationary_pose() {
    for (const bool reset : {false, true}) {
        Coordinator coordinator(small_config());
        auto handle = open_pocket(coordinator);
        const Shard* shard = coordinator.registry().find(handle);
        CHECK(shard != nullptr);
        if (!shard) return;
        auto right = next_poses(coordinator); right[0].x += 2;
        CHECK(coordinator.step(right).outcome == Outcome::Accepted);
        CHECK(coordinator.edit(31, 31, {Material::Sand, 213, 217, -470}).outcome == Outcome::Accepted);
        const auto original_witness = coordinator.world_witness(31, 31);
        auto left = next_poses(coordinator); left[0].x -= 2;
        CHECK(coordinator.step(left).outcome == Outcome::Accepted);
        CHECK(shard->counts().cargo == 0);
        // If swept collision relocated the grain and ordinary World transport
        // admitted it through the aperture afterward, that is legitimate. If
        // the exact World carrier never moved, "already inside" cannot erase
        // its known invalid entry on the next stationary pose.
        const bool unchanged_enclosure = coordinator.inspect_world(31, 31).material == Material::Sand &&
            coordinator.world_witness(31, 31) == original_witness;
        for (unsigned tick = 0; tick < 4; ++tick) {
            sleeping_step(coordinator);
            CHECK(!unchanged_enclosure || shard->counts().cargo == 0);
            CHECK(CoordinatorTestAccess::ingress_fences(coordinator) <= 1);
        }
        CHECK(world_population(coordinator, Material::Sand) + shard->counts().cargo == 1);
        check_population_balance(coordinator);
        if (reset) {
            const auto retired_handle=handle;
            CHECK(coordinator.reset(0, 18).outcome == Outcome::Accepted);
            CHECK(CoordinatorTestAccess::ingress_fences(coordinator) == 0);
            handle = open_pocket(coordinator);
            shard = coordinator.registry().find(handle);
            CHECK(handle.id>retired_handle.id && handle.session>retired_handle.session);
            const auto pocket=static_cast<std::uint32_t>((31-shard->bounds().y)*shard->bounds().width+31-shard->bounds().x);
            CHECK(!CoordinatorTestAccess::pocket_fenced(coordinator,handle,pocket));
            CHECK(CoordinatorTestAccess::pocket_fenced(coordinator,retired_handle,pocket));
            auto stale=handle;++stale.generation;
            CHECK(CoordinatorTestAccess::pocket_fenced(coordinator,stale,pocket));
            stale=handle;++stale.session;
            CHECK(CoordinatorTestAccess::pocket_fenced(coordinator,stale,pocket));
        } else {
            CHECK(coordinator.edit(31, 31, empty()).outcome == Outcome::Accepted);
            sleeping_step(coordinator); // An actually empty aperture clears its history.
            CHECK(CoordinatorTestAccess::ingress_fences(coordinator) == 0);
        }
        CHECK(coordinator.edit(31, 27, {Material::Sand, 137, 41, 315}).outcome == Outcome::Accepted);
        for (unsigned tick = 0; tick < 16 && shard->counts().cargo == 0; ++tick) sleeping_step(coordinator);
        CHECK(shard->counts().cargo == 1 && world_population(coordinator, Material::Sand) == 0);
        check_population_balance(coordinator);
    }
}

void segmented_motion_preserves_invalid_pocket_entry_until_semantic_ingress() {
    Coordinator coordinator(small_config());
    const auto handle=open_pocket(coordinator);
    const auto* shard=coordinator.registry().find(handle);CHECK(shard!=nullptr);
    if (!shard) return;
    const auto tick=coordinator.world().completed_tick_index();
    auto right=next_poses(coordinator);right[0].x+=2;
    CHECK(coordinator.accept_motion(right).outcome==Outcome::Accepted);
    CHECK(coordinator.edit(31,31,{Material::Sand,213,217,-470}).outcome==Outcome::Accepted);
    const auto source=coordinator.world_witness(31,31);
    auto left=next_poses(coordinator);left[0].x-=2;
    const auto contact_ns_before=coordinator.metrics().contact_ns;
    CHECK(coordinator.accept_motion(left).outcome==Outcome::Accepted);
    CHECK(coordinator.metrics().contact_ns>contact_ns_before);
    CHECK(coordinator.world().completed_tick_index()==tick);
    CHECK(shard->counts().cargo==0);
    CHECK(coordinator.inspect_world(31,31).material==Material::Sand);
    CHECK(coordinator.world_witness(31,31)==source);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator)==1);
    // Several accepted no-advance pose segments cannot relabel a known side
    // entry as a legitimate stationary "already inside" carrier on next tick.
    for (unsigned segment=0;segment<3;++segment) {
        CHECK(coordinator.accept_motion(next_poses(coordinator)).outcome==Outcome::Accepted);
        CHECK(coordinator.world().completed_tick_index()==tick);
        CHECK(shard->counts().cargo==0);
        CHECK(CoordinatorTestAccess::ingress_fences(coordinator)==1);
    }
    sleeping_step(coordinator);
    CHECK(shard->counts().cargo==0);
    CHECK(world_population(coordinator,Material::Sand)==1);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator)==1);
    check_population_balance(coordinator);
    CHECK(coordinator.edit(31,31,empty()).outcome==Outcome::Accepted);
    CHECK(coordinator.accept_motion(next_poses(coordinator)).outcome==Outcome::Accepted);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator)==0);
}

void refused_motion_preserves_existing_invalid_entry_history() {
    Coordinator coordinator(small_config());
    const auto handle=open_pocket(coordinator);
    const auto* shard=coordinator.registry().find(handle);
    CHECK(shard!=nullptr);
    if (!shard) return;
    auto right=next_poses(coordinator);right[0].x+=2;
    CHECK(coordinator.accept_motion(right).outcome==Outcome::Accepted);
    const Payload sand{Material::Sand,213,217,-470};
    CHECK(coordinator.edit(31,31,sand).outcome==Outcome::Accepted);
    auto left=next_poses(coordinator);left[0].x-=2;
    CHECK(coordinator.accept_motion(left).outcome==Outcome::Accepted);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator)==1);
    const auto witness=coordinator.world_witness(31,31);
    const auto original=coordinator.snapshot().bodies[0].pose;
    const auto tick=coordinator.world().completed_tick_index();
    CHECK(coordinator.edit(34,31,{Material::Sand,71,0,200}).outcome==Outcome::Accepted);
    auto capacity=CoordinatorTestAccess::remove_relocation_capacity(coordinator);
    right=next_poses(coordinator);right[0].x+=2;
    // The proposed aperture is clear, but another grain blocks the proposed
    // collider and forces precommit refusal. A discarded pose cannot erase
    // the old aperture's still-applicable side-entry history.
    CHECK(coordinator.accept_motion(right).outcome==Outcome::Capacity);
    CHECK(coordinator.world().completed_tick_index()==tick);
    CHECK(coordinator.snapshot().bodies[0].pose.x==original.x);
    CHECK(coordinator.snapshot().bodies[0].pose.pose_serial==original.pose_serial);
    CHECK(coordinator.inspect_world(31,31)==sand && coordinator.world_witness(31,31)==witness);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator)==1);
    CoordinatorTestAccess::restore_relocation_capacity(coordinator,capacity);
    CHECK(coordinator.accept_motion(next_poses(coordinator)).outcome==Outcome::Accepted);
    CHECK(coordinator.step(next_poses(coordinator)).outcome==Outcome::Accepted);
    CHECK(shard->counts().cargo==0);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator)==1);
    CHECK(world_population(coordinator,Material::Sand)==2);
    check_population_balance(coordinator);
}

void injected_ingress_history_capacity_keeps_inventory_and_reset_live() {
    Coordinator coordinator(small_config());
    const auto handle = open_pocket(coordinator);
    auto right = next_poses(coordinator); right[0].x += 2;
    CHECK(coordinator.step(right).outcome == Outcome::Accepted);
    const Payload sand{Material::Sand, 213, 217, -470};
    CHECK(coordinator.edit(31, 31, sand).outcome == Outcome::Accepted);
    CoordinatorTestAccess::remove_ingress_history_capacity(coordinator);
    const auto tick = coordinator.world().completed_tick_index();
    auto left = next_poses(coordinator); left[0].x -= 2;
    CHECK(coordinator.step(left).outcome == Outcome::Quarantined);
    CHECK(coordinator.world().completed_tick_index() == tick);
    CHECK(coordinator.inspect_world(31, 31) == sand);
    CHECK(coordinator.registry().find(handle)->counts().cargo == 0);
    CHECK(coordinator.registry().find(handle)->counts().structural == 5);
    check_population_balance(coordinator);
    CHECK(coordinator.reset(0, 19).outcome == Outcome::Accepted);
    CHECK(coordinator.registry().find(handle) == nullptr);
    CHECK(!coordinator.snapshot().quarantined);
    check_population_balance(coordinator);
}

void zero_automatic_budget_cannot_bypass_history_through_public_ingress() {
    auto config = small_config(); config.transfer_budget = 0;
    Coordinator coordinator(config);
    const auto handle = open_pocket(coordinator);
    const auto* shard = coordinator.registry().find(handle);
    CHECK(shard != nullptr);
    if (!shard) return;
    const auto bounds = shard->bounds();
    const auto pocket = static_cast<std::uint32_t>((31 - bounds.y) * bounds.width + 31 - bounds.x);
    auto right = next_poses(coordinator); right[0].x += 2;
    CHECK(coordinator.step(right).outcome == Outcome::Accepted);
    const Payload sand{Material::Sand, 213, 217, -470};
    CHECK(coordinator.edit(31, 31, sand).outcome == Outcome::Accepted);
    auto left = next_poses(coordinator); left[0].x -= 2;
    CHECK(coordinator.step(left).outcome == Outcome::Accepted);
    sleeping_step(coordinator);
    CHECK(shard->counts().cargo == 0 && coordinator.inspect_world(31, 31) == sand);
    const auto request = transfer_request(coordinator, handle, pocket, 31, 31, sand);
    CHECK(coordinator.ingest(request).outcome == Outcome::Fenced);
    CHECK(shard->counts().cargo == 0 && coordinator.inspect_world(31, 31) == sand);
    CHECK(coordinator.ingest(request).outcome == Outcome::Fenced);
    check_population_balance(coordinator);
    CHECK(coordinator.edit(31, 31, empty()).outcome == Outcome::Accepted);
    sleeping_step(coordinator);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator) == 0);
    CHECK(coordinator.edit(31, 27, sand).outcome == Outcome::Accepted);
    for (unsigned tick = 0; tick < 16 && coordinator.inspect_world(31, 31).material != Material::Sand; ++tick)
        sleeping_step(coordinator);
    CHECK(coordinator.inspect_world(31, 31).material == Material::Sand);
    const auto fresh = transfer_request(coordinator, handle, pocket, 31, 31, coordinator.inspect_world(31, 31));
    CHECK(coordinator.ingest(fresh).outcome == Outcome::Accepted);
    CHECK(shard->counts().cargo == 1 && world_population(coordinator, Material::Sand) == 0);
    check_population_balance(coordinator);
}

void exhausted_transfer_budget_still_records_later_body_entry_history() {
    auto config = small_config(); config.transfer_budget = 1;
    Coordinator coordinator(config);
    const auto first_handle = open_pocket(coordinator, 1, 31);
    const auto second_handle = open_pocket(coordinator, 1, 71);
    const auto* first = coordinator.registry().find(first_handle);
    const auto* second = coordinator.registry().find(second_handle);
    CHECK(first && second);
    if (!first || !second) return;
    auto right = next_poses(coordinator);
    for (auto& pose : right) if (pose.shard == second_handle) pose.x += 2;
    CHECK(coordinator.step(right).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(31, 27, {Material::Sand, 213, 217, -470}).outcome == Outcome::Accepted);
    for (unsigned tick = 0; tick < 16 && coordinator.inspect_world(31, 31).material != Material::Sand; ++tick)
        sleeping_step(coordinator);
    CHECK(coordinator.inspect_world(31, 31).material == Material::Sand && first->counts().cargo == 0);
    CHECK(coordinator.edit(71, 31, {Material::Sand, 213, 217, -470}).outcome == Outcome::Accepted);
    const auto witness = coordinator.world_witness(71, 31);
    auto left = next_poses(coordinator);
    for (auto& pose : left) if (pose.shard == second_handle) pose.x -= 2;
    CHECK(coordinator.step(left).outcome == Outcome::Accepted);
    CHECK(first->counts().cargo == 1 && second->counts().cargo == 0);
    const bool unchanged_enclosure = coordinator.inspect_world(71, 31).material == Material::Sand &&
        coordinator.world_witness(71, 31) == witness;
    install_geometry(coordinator); sleeping_step(coordinator);
    CHECK(!unchanged_enclosure || second->counts().cargo == 0);
    CHECK(world_population(coordinator, Material::Sand) + first->counts().cargo + second->counts().cargo == 2);
    CHECK(CoordinatorTestAccess::ingress_fences(coordinator) <= 1);
    check_population_balance(coordinator);
}

void historical_water_exposure_survives_geometry_and_rejects_replacement() {
    namespace chemistry = material_lifecycle;
    for (const bool replace_cell : {false, true}) {
        auto config = small_config(); config.transfer_budget = 0;
        Coordinator coordinator(config);
        constexpr int y = 31;
        int x = 20;
        while (x < 60 && !(chemistry::lane_phase(x, y, 2, 191) == 1 &&
                          chemistry::lane_phase(x + 1, y, 2, 191) == 0)) ++x;
        CHECK(x < 60);
        CHECK(coordinator.edit(x, y, {Material::Wood, 177, 11, 520}).outcome == Outcome::Accepted);
        CHECK(coordinator.edit(x + 1, y, {Material::Wood, 0, 1, 200}).outcome == Outcome::Accepted);
        CHECK(coordinator.edit(x, y + 1, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
        CHECK(coordinator.edit(x, y + 1, empty()).outcome == Outcome::Accepted);
        const auto prepared = discover(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) return;
        CHECK(activate(coordinator, prepared.shard));
        auto* shard = CoordinatorTestAccess::registry(coordinator).find(prepared.shard);
        const auto bounds = shard->bounds();
        const auto target = static_cast<std::uint32_t>((y - bounds.y) * bounds.width + x - bounds.x);
        const auto incarnation = shard->schedule(target).incarnation;
        const auto original_geometry = shard->geometry().revision;
        CHECK(coordinator.edit(x - 1, y - 1, {Material::Water, 255, 0, 200}).outcome == Outcome::Accepted);
        const auto quantity = coordinator.world().quantity_ledger().water_visible;
        CHECK(coordinator.step(next_poses(coordinator)).outcome == Outcome::Accepted);
        CHECK(shard->payload(target).state_b == 11); // Contact arrived on the off-lane tick.
        CHECK(shard->geometry().revision > original_geometry);
        CHECK(coordinator.accounting().accepted_exposures >= 1 && coordinator.accounting().consumed_exposures == 0);
        CHECK(!CoordinatorTestAccess::exposures(coordinator).empty());
        CHECK(CoordinatorTestAccess::exposures(coordinator).front().geometry_revision == original_geometry);
        install_geometry(coordinator);
        if (replace_cell) {
            // The same historical fact may not act on a replacement owner.
            const auto wb = coordinator.config().world_bounds;
            for (auto wy = wb.y; wy < wb.y + wb.height; ++wy)
                for (auto wx = wb.x; wx < wb.x + wb.width; ++wx)
                    if (coordinator.inspect_world(wx, wy).material == Material::Water)
                        CHECK(coordinator.edit(wx, wy, empty()).outcome == Outcome::Accepted);
            CHECK(shard->set_cell(target, shard->payload(target), Role::Structural,
                coordinator.world().completed_tick_index(), true) == Outcome::Accepted);
            CHECK(shard->schedule(target).incarnation != incarnation);
        }
        auto departed = next_poses(coordinator);
        departed[0].x += 3.0;
        CHECK(coordinator.step(departed).outcome == Outcome::Accepted);
        if (replace_cell) {
            CHECK(shard->payload(target).state_b == 10);
            CHECK(coordinator.accounting().extinguished == 0 && coordinator.accounting().consumed_exposures == 0);
        } else {
            CHECK(shard->payload(target).state_b == 0);
            CHECK(shard->payload(target).state_a == 177 && shard->payload(target).temperature == 520);
            CHECK(shard->schedule(target).incarnation == incarnation);
            CHECK(coordinator.accounting().extinguished == 1 && coordinator.accounting().consumed_exposures == 1);
            CHECK(coordinator.world().quantity_ledger().water_visible == quantity);
            bool current_water = false;
            for (int dy = -1; dy <= 1; ++dy) for (int dx = -1; dx <= 1; ++dx)
                current_water = current_water || coordinator.inspect_world(x + 3 + dx, y + dy).material == Material::Water;
            CHECK(!current_water); // The valid earlier exposure survived departure.
            CHECK(coordinator.ignite_shard(prepared.shard, target).outcome == Outcome::Accepted);
            auto further = next_poses(coordinator); further[0].x += 3.0;
            CHECK(coordinator.step(further).outcome == Outcome::Accepted);
            install_geometry(coordinator);
            sleeping_step(coordinator);
            CHECK(shard->payload(target).state_b > 0 && shard->payload(target).state_b < 240);
            CHECK(coordinator.accounting().consumed_exposures == 1); // No stale replay after re-ignition.
        }
    }
}

void exposure_capacity_refuses_without_partial_pose_or_clock() {
    auto config = small_config(); config.exposure_capacity = 1;
    Coordinator coordinator(config);
    make_supported(coordinator, 30, 30, Material::Wood, 11); erase_support(coordinator);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(activate(coordinator, prepared.shard));
    for (int x = 30; x <= 32; ++x)
        CHECK(coordinator.edit(x, 29, {Material::Water, 255, 0, 200}).outcome == Outcome::Accepted);
    auto poses = next_poses(coordinator);
    const auto previous = poses[0];
    poses[0].x += .25;
    const auto tick = coordinator.world().completed_tick_index();
    const auto inventory = coordinator.registry().find(prepared.shard)->payload_digest();
    CHECK(coordinator.step(poses).outcome == Outcome::Capacity);
    CHECK(coordinator.world().completed_tick_index() == tick);
    CHECK(coordinator.registry().find(prepared.shard)->payload_digest() == inventory);
    CHECK(CoordinatorTestAccess::exposures(coordinator).empty());
    CHECK(coordinator.accounting().accepted_exposures == 0);
    CHECK(coordinator.metrics().exposure_overflows == 1);
    for (const auto& body : coordinator.snapshot().bodies) if (body.has_body)
        CHECK(body.pose.x == previous.x && body.pose.pose_serial + 1 == previous.pose_serial);
    CHECK(coordinator.reset(0, 4).outcome == Outcome::Accepted); // Control is live despite full data capacity.
}

void two_shards_contend_for_one_real_output_destination() {
    auto config = small_config(); config.transfer_budget = 0;
    Coordinator coordinator(config);
    const std::array<Handle, 2> handles{single_wood(coordinator, 30, 30, 8), single_wood(coordinator, 34, 30, 8)};
    sleeping_step(coordinator); sleeping_step(coordinator);
    std::array<std::uint32_t, 2> products{};
    std::array<std::array<std::int64_t, 2>, 2> ports{};
    for (unsigned i = 0; i < 2; ++i) {
        const auto* shard = coordinator.registry().find(handles[i]);
        CHECK(shard != nullptr && shard->counts().products == 1);
        if (!shard || shard->counts().products != 1) return;
        for (std::uint32_t at = 0; at < shard->area(); ++at)
            if (shard->role(at) == Role::Product) products[i] = at;
        const auto bounds = shard->bounds();
        ports[i] = {bounds.x + products[i] % bounds.width, bounds.y + products[i] / bounds.width};
    }
    const auto wx = (ports[0][0] + ports[1][0]) / 2, wy = (ports[0][1] + ports[1][1]) / 2;
    auto poses = next_poses(coordinator);
    for (auto& pose : poses) for (unsigned i = 0; i < 2; ++i) if (pose.shard == handles[i]) {
        // Adversarial admitted pose samples align the two nonstructural ports.
        // Inventory arbitration is under test; Rapier collision is a separate gate.
        pose.x += wx - ports[i][0]; pose.y += wy - ports[i][1];
    }
    CHECK(coordinator.step(poses).outcome == Outcome::Accepted);
    CHECK(coordinator.world().transient_obstacle_at(wx, wy) == 0);
    const auto* first = coordinator.registry().find(handles[0]);
    const auto* second = coordinator.registry().find(handles[1]);
    const auto second_payload = second->payload(products[1]);
    const auto first_request = transfer_request(coordinator, handles[0], products[0], wx, wy, first->payload(products[0]));
    CHECK(coordinator.emit(first_request).outcome == Outcome::Accepted);
    const auto second_request = transfer_request(coordinator, handles[1], products[1], wx, wy, second_payload);
    CHECK(coordinator.emit(second_request).outcome == Outcome::DestinationUnavailable);
    CHECK(first->counts().products == 0 && second->counts().products == 1);
    CHECK(second->payload(products[1]) == second_payload);
    CHECK(world_population(coordinator, Material::Fire) == 1);
    CHECK(coordinator.accounting().created[static_cast<std::uint8_t>(Material::Fire)] == 2);
    CHECK(coordinator.accounting().emitted[static_cast<std::uint8_t>(Material::Fire)] == 1);
    CHECK(coordinator.emit(second_request).outcome == Outcome::DestinationUnavailable);
    CHECK(second->counts().products + world_population(coordinator, Material::Fire) == 2);
}

void three_independent_burning_owners() {
    auto config = small_config(); config.transfer_budget = 0;
    Coordinator coordinator(config);
    std::array<Handle, 3> handles{};
    for (unsigned i = 0; i < 3; ++i) handles[i] = single_wood(coordinator, 20 + static_cast<int>(30 * i), 31,
        static_cast<std::uint8_t>(3 + 2 * i));
    CHECK(handles[0].id != handles[1].id && handles[1].id != handles[2].id);
    for (unsigned tick = 0; tick < 16; ++tick) sleeping_step(coordinator);
    CHECK(coordinator.registry().inventory_counts().total() == 0);
    CHECK(coordinator.accounting().promoted[static_cast<std::uint8_t>(Material::Wood)] == 3);
    CHECK(coordinator.accounting().destroyed[static_cast<std::uint8_t>(Material::Wood)] == 3);
    CHECK(coordinator.accounting().created[static_cast<std::uint8_t>(Material::Fire)] == 0);
    for (const auto handle : handles) CHECK(coordinator.registry().find(handle) == nullptr);
    check_population_balance(coordinator);
}

void population_accounting_covers_world_ticks_edits_transfers_and_resets() {
    Coordinator coordinator(small_config());
    check_population_balance(coordinator);
    CHECK(coordinator.edit(12,14,{Material::Water,0,0,200}).outcome==Outcome::Unsupported);
    CHECK(coordinator.inspect_world(12,14).material==Material::Empty);
    CHECK(coordinator.edit(12,14,{Material::Wood,17,0,410}).outcome==Outcome::Accepted);
    CHECK(coordinator.edit(12,14,{Material::Water,0,0,200}).outcome==Outcome::Unsupported);
    CHECK(coordinator.inspect_world(12,14)==(Payload{Material::Wood,17,0,410}));
    check_population_balance(coordinator);
    CHECK(coordinator.edit(12,14,empty()).outcome==Outcome::Accepted);
    CHECK(coordinator.edit(12, 15, {Material::Sand, 73, 14, -370}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(17, 15, {Material::Water, 255, 0, 200}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(40, 20, {Material::Wood, 55, 8, 510}).outcome == Outcome::Accepted);
    CHECK(coordinator.edit(40, 21, {Material::Wall, 0, 0, 200}).outcome == Outcome::Accepted);
    check_population_balance(coordinator);
    CHECK(coordinator.step().outcome == Outcome::Accepted);
    CHECK(coordinator.step().outcome == Outcome::Accepted);
    check_population_balance(coordinator);
    CHECK(coordinator.edit(40, 21, empty()).outcome == Outcome::Accepted);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    check_population_balance(coordinator); // Non-authoritative preparation counts once.
    CHECK(activate(coordinator, prepared.shard));
    check_population_balance(coordinator);
    for (unsigned tick = 0; tick < 40; ++tick) {
        sleeping_step(coordinator);
        check_population_balance(coordinator);
    }
    const auto water = coordinator.world().quantity_ledger().water_visible;
    const auto disposed_before = coordinator.accounting().reset_water_quanta;
    CHECK(coordinator.reset(0, 21).outcome == Outcome::Accepted);
    CHECK(coordinator.accounting().reset_water_quanta >= disposed_before + water);
    check_population_balance(coordinator);
}

void m4_same_world_promotion_and_exact_motion() {
    namespace gate = cybersand::object_shard::m4;
    Coordinator coordinator(small_config());
    World* const world = &cybersand::object_shard::CoordinatorTestAccess::world(coordinator);
    const auto initial = coordinator.snapshot();
    const gate::OwnerIdentity owner{11, 22, 33, initial.session, initial.world_incarnation};
    gate::MutableBodyGate adapter(*world, coordinator, owner);
    CHECK(adapter.initially_bound());
    CHECK(&coordinator.world() == world);
    CHECK(adapter.registered_bodies() == 0);
    const auto snapshot_time_before = coordinator.metrics().snapshot_ns;
    for (unsigned repeat = 0; repeat < 20; ++repeat) {
        const auto proof = coordinator.m4_owner_readback();
        CHECK(proof.world_available && proof.session == initial.session);
        CHECK(proof.tick == world->completed_tick_index());
        CHECK(proof.active_count == 0 && !proof.truncated);
    }
    // The fixed-size M4 proof must never rebuild the presentation snapshot.
    CHECK(coordinator.metrics().snapshot_ns == snapshot_time_before);
    gate::MotionTicket motion{};
    CHECK(adapter.issue_motion(*world, coordinator, owner, motion) == gate::Verdict::Fenced);
    CHECK(adapter.grant_completed_tick(*world, coordinator, owner, world->completed_tick_index()) == gate::Verdict::Stale);

    make_supported(coordinator);
    erase_support(coordinator);
    const auto before = owned_population(coordinator, Material::Wood);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(adapter.registered_bodies() == 0); // Preparation never owns a physical body.
    CHECK(activate(coordinator, prepared.shard));
    CHECK(owned_population(coordinator, Material::Wood) == before);
    CHECK(&coordinator.world() == world);

    gate::GeometryTicket installation{};
    CHECK(adapter.stage_geometry(*world, coordinator, owner, prepared.shard, installation) == gate::Verdict::Accepted);
    CHECK(adapter.registered_bodies() == 1);
    auto forged = installation;
    forged.body.mass += 1.;
    CHECK(adapter.acknowledge_geometry(*world, coordinator, owner, forged) == gate::Verdict::Stale);
    forged = installation;
    forged.body.inertia += 1.;
    CHECK(adapter.acknowledge_geometry(*world, coordinator, owner, forged) == gate::Verdict::Stale);
    forged = installation;
    ++forged.body.material_revision;
    CHECK(adapter.acknowledge_geometry(*world, coordinator, owner, forged) == gate::Verdict::Stale);
    forged = installation;
    ++forged.body.geometry_revision;
    CHECK(adapter.acknowledge_geometry(*world, coordinator, owner, forged) == gate::Verdict::Stale);
    CHECK(adapter.issue_motion(*world, coordinator, owner, motion) == gate::Verdict::Fenced);
    CHECK(adapter.acknowledge_geometry(*world, coordinator, owner, installation) == gate::Verdict::Accepted);
    CHECK(adapter.acknowledge_geometry(*world, coordinator, owner, installation) == gate::Verdict::Stale);
    gate::GeometryTicket duplicate{};
    CHECK(adapter.stage_geometry(*world, coordinator, owner, prepared.shard, duplicate) == gate::Verdict::Busy);
    CHECK(adapter.issue_motion(*world, coordinator, owner, motion) == gate::Verdict::Fenced);

    // The real coordinator advances exactly one semantic native tick.
    const auto before_tick = world->completed_tick_index();
    CHECK(coordinator.step(next_poses(coordinator)).outcome == Outcome::Accepted);
    CHECK(world->completed_tick_index() == before_tick + 1);
    CHECK(adapter.grant_completed_tick(*world, coordinator, owner, before_tick) == gate::Verdict::Stale);
    CHECK(adapter.grant_completed_tick(*world, coordinator, owner, before_tick + 1) == gate::Verdict::Accepted);
    CHECK(adapter.grant_completed_tick(*world, coordinator, owner, before_tick + 1) == gate::Verdict::Stale);
    CHECK(adapter.issue_motion(*world, coordinator, owner, motion) == gate::Verdict::Accepted);
    CHECK(motion.count == 1);
    CHECK(motion.completed_tick == before_tick + 1);
    CHECK(adapter.motion_outstanding());
    gate::MotionTicket second{};
    CHECK(adapter.issue_motion(*world, coordinator, owner, second) == gate::Verdict::Held);
    CHECK(adapter.grant_completed_tick(*world, coordinator, owner, before_tick + 1) == gate::Verdict::Held);
    CHECK(adapter.accept_applied_motion(*world, coordinator, owner, motion) == gate::Verdict::Stale);
    auto altered = motion;
    ++altered.bodies[0].pose_serial;
    CHECK(adapter.accept_applied_motion(*world, coordinator, owner, altered) == gate::Verdict::Stale);
    CHECK(adapter.motion_outstanding());
    // Only the real M3 native application changes the accepted serial.
    CHECK(coordinator.accept_motion(next_poses(coordinator)).outcome == Outcome::Accepted);
    CHECK(adapter.accept_applied_motion(*world, coordinator, owner, motion) == gate::Verdict::Accepted);
    CHECK(!adapter.motion_outstanding());
    CHECK(adapter.accept_applied_motion(*world, coordinator, owner, motion) == gate::Verdict::Stale);
    CHECK(adapter.issue_motion(*world, coordinator, owner, second) == gate::Verdict::Accepted);
    CHECK(second.sequence > motion.sequence);
    CHECK(coordinator.accept_motion(next_poses(coordinator)).outcome == Outcome::Accepted);
    CHECK(adapter.accept_applied_motion(*world, coordinator, owner, second) == gate::Verdict::Accepted);
    // The M3 bridge retains its original 16-segment physical interval cap.
    for (std::uint32_t segment = 2; segment < gate::kSegmentLimit; ++segment) {
        gate::MotionTicket accepted_segment{};
        CHECK(adapter.issue_motion(*world, coordinator, owner, accepted_segment) == gate::Verdict::Accepted);
        CHECK(coordinator.accept_motion(next_poses(coordinator)).outcome == Outcome::Accepted);
        CHECK(adapter.accept_applied_motion(*world, coordinator, owner, accepted_segment) == gate::Verdict::Accepted);
    }
    gate::MotionTicket over_budget{};
    CHECK(adapter.issue_motion(*world, coordinator, owner, over_budget) == gate::Verdict::Capacity);
    CHECK(world->completed_tick_index() == before_tick + 1);

    // A real state-only Wood ignition increments material identity while
    // preserving collider geometry. It must re-ticket the material and
    // invalidate the old completed-tick motion permit.
    const auto* physical = coordinator.registry().find(prepared.shard);
    CHECK(physical != nullptr);
    if (!physical) return;
    std::uint32_t structural_cell = 0;
    for (; structural_cell < physical->area(); ++structural_cell)
        if (physical->structural(structural_cell)) break;
    CHECK(structural_cell < physical->area());
    if (structural_cell >= physical->area()) return;
    const auto geometry_before = physical->geometry().revision;
    const auto material_before = physical->material_revision();
    CHECK(coordinator.ignite_shard(prepared.shard, structural_cell).outcome == Outcome::Accepted);
    const auto* ignited = coordinator.registry().find(prepared.shard);
    CHECK(ignited && ignited->geometry().revision == geometry_before);
    CHECK(ignited && ignited->material_revision() > material_before);
    CHECK(adapter.issue_motion(*world, coordinator, owner, over_budget) == gate::Verdict::Fenced);
    gate::GeometryTicket state_only{};
    CHECK(adapter.stage_geometry(*world, coordinator, owner, prepared.shard, state_only) == gate::Verdict::Accepted);
    CHECK(state_only.body.geometry_revision == geometry_before);
    CHECK(state_only.body.material_revision > material_before);
    CHECK(adapter.acknowledge_geometry(*world, coordinator, owner, state_only) == gate::Verdict::Accepted);
    CHECK(adapter.issue_motion(*world, coordinator, owner, over_budget) == gate::Verdict::Fenced);
    CHECK(adapter.grant_completed_tick(*world, coordinator, owner, before_tick + 1) == gate::Verdict::Stale);
    CHECK(owned_population(coordinator, Material::Wood) == before);
    CHECK(adapter.release_when_empty(*world, coordinator, owner) == gate::Verdict::Held);
    CHECK(&coordinator.world() == world);
}

void m4_cancel_does_not_consume_world_and_replacement_fences() {
    namespace gate = cybersand::object_shard::m4;
    Coordinator coordinator(small_config());
    const auto initial = coordinator.snapshot();
    const gate::OwnerIdentity owner{10, 4, 9, initial.session, initial.world_incarnation};
    gate::MutableBodyGate adapter(cybersand::object_shard::CoordinatorTestAccess::world(coordinator), coordinator, owner);
    make_supported(coordinator);
    erase_support(coordinator);
    const auto before = owned_population(coordinator, Material::Wood);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    gate::GeometryTicket staged_not_active{};
    CHECK(adapter.stage_geometry(cybersand::object_shard::CoordinatorTestAccess::world(coordinator), coordinator,
              owner, prepared.shard, staged_not_active) == gate::Verdict::Fenced);
    CHECK(coordinator.cancel(prepared.transaction).outcome == Outcome::Cancelled);
    CHECK(owned_population(coordinator, Material::Wood) == before);
    CHECK(adapter.registered_bodies() == 0);
    CHECK(adapter.release_when_empty(cybersand::object_shard::CoordinatorTestAccess::world(coordinator), coordinator,
              owner) == gate::Verdict::Accepted);
    CHECK(!adapter.initially_bound());
    gate::GeometryTicket stale{};
    CHECK(adapter.stage_geometry(cybersand::object_shard::CoordinatorTestAccess::world(coordinator), coordinator,
              owner, prepared.shard, stale) == gate::Verdict::Retired);

    Coordinator another(small_config());
    const auto other_stamp = another.snapshot();
    const gate::OwnerIdentity other{10, 4, 10, other_stamp.session, other_stamp.world_incarnation};
    gate::MutableBodyGate isolated(cybersand::object_shard::CoordinatorTestAccess::world(another), another, other);
    CHECK(isolated.initially_bound());
    CHECK(isolated.grant_completed_tick(cybersand::object_shard::CoordinatorTestAccess::world(coordinator),
              coordinator, other, 1) == gate::Verdict::WrongWorld);
    gate::Verdict foreign = gate::Verdict::Accepted;
    std::size_t foreign_count = 99;
    bool foreign_bound = true;
    World& live_other_world = cybersand::object_shard::CoordinatorTestAccess::world(another);
    std::thread hostile([&] {
        gate::MotionTicket ignored{};
        foreign = isolated.issue_motion(live_other_world, another, other, ignored);
        foreign_count = isolated.registered_bodies();
        foreign_bound = isolated.initially_bound();
    });
    hostile.join();
    CHECK(foreign == gate::Verdict::WrongOwner);
    CHECK(foreign_count == 0 && !foreign_bound);
    CHECK(another.reset(0, 888).outcome == Outcome::Accepted);
    gate::MotionTicket after_reset{};
    CHECK(isolated.issue_motion(cybersand::object_shard::CoordinatorTestAccess::world(another), another,
              other, after_reset) == gate::Verdict::WrongWorld);
}

void m4_exclusive_mutable_capacity_refuses_fourth_real_owner() {
    namespace gate = cybersand::object_shard::m4;
    Config config = small_config();
    config.limits.max_shards = 4;
    Coordinator coordinator(config);
    const auto native_stamp = coordinator.snapshot();
    const gate::OwnerIdentity owner{17, 21, 31, native_stamp.session, native_stamp.world_incarnation};
    gate::MutableBodyGate adapter(cybersand::object_shard::CoordinatorTestAccess::world(coordinator), coordinator, owner);
    CHECK(adapter.initially_bound());
    constexpr std::array<std::int64_t, 4> columns{{16, 42, 68, 94}};
    for (auto x : columns) {
        make_supported(coordinator, x, 30);
        erase_support(coordinator, x, 30);
    }
    for (std::size_t i = 0; i < columns.size(); ++i) {
        const auto prepared = discover(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) break;
        CHECK(activate(coordinator, prepared.shard));
        const auto proof = coordinator.m4_owner_readback();
        CHECK(proof.active_count == i + 1);
        CHECK(proof.truncated == (i >= OwnerReadback::kBodySlots));
        gate::GeometryTicket ticket{};
        const auto outcome = adapter.stage_geometry(cybersand::object_shard::CoordinatorTestAccess::world(coordinator),
            coordinator, owner, prepared.shard, ticket);
        CHECK(outcome == (i < gate::kBodyLimit ? gate::Verdict::Accepted : gate::Verdict::Capacity));
        if (outcome == gate::Verdict::Accepted)
            CHECK(adapter.acknowledge_geometry(cybersand::object_shard::CoordinatorTestAccess::world(coordinator),
                coordinator, owner, ticket) == gate::Verdict::Accepted);
    }
    CHECK(adapter.registered_bodies() == gate::kBodyLimit);
    gate::MotionTicket denied{};
    CHECK(adapter.issue_motion(cybersand::object_shard::CoordinatorTestAccess::world(coordinator),
        coordinator, owner, denied) == gate::Verdict::Fenced);
}


void m4_partial_physics_commit_is_still_exclusive_material() {
    namespace gate = cybersand::object_shard::m4;
    Coordinator coordinator(small_config());
    const auto initial = coordinator.snapshot();
    const gate::OwnerIdentity owner{31, 37, 41, initial.session, initial.world_incarnation};
    gate::MutableBodyGate adapter(cybersand::object_shard::CoordinatorTestAccess::world(coordinator), coordinator, owner);
    make_supported(coordinator);
    erase_support(coordinator);
    const auto before = owned_population(coordinator, Material::Wood);
    const auto prepared = discover(coordinator);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    const auto reserve_receipt = ack_for(coordinator, AckKind::PhysicsReserved);
    CHECK(coordinator.acknowledge(reserve_receipt).outcome == Outcome::Accepted);
    CHECK(owned_population(coordinator, Material::Wood) == before);
    const auto* captured = coordinator.registry().find(prepared.shard);
    CHECK(captured && captured->owns_inventory());
    CHECK(captured && captured->phase() == Phase::CommittedInactive);
    gate::GeometryTicket blocked{};
    CHECK(adapter.stage_geometry(cybersand::object_shard::CoordinatorTestAccess::world(coordinator),
        coordinator, owner, prepared.shard, blocked) == gate::Verdict::Fenced);
    CHECK(coordinator.cancel(prepared.transaction).outcome == Outcome::Quarantined);
    CHECK(owned_population(coordinator, Material::Wood) == before);
    CHECK(adapter.release_when_empty(cybersand::object_shard::CoordinatorTestAccess::world(coordinator),
        coordinator, owner) == gate::Verdict::Held);
    CHECK(coordinator.reset(0, 426).outcome == Outcome::Accepted);
    CHECK(coordinator.accounting().reset_disposed[static_cast<std::uint8_t>(Material::Wood)] >= before);
    CHECK(owned_population(coordinator, Material::Wood) == 0);
    gate::MotionTicket old{};
    CHECK(adapter.issue_motion(cybersand::object_shard::CoordinatorTestAccess::world(coordinator),
        coordinator, owner, old) == gate::Verdict::WrongWorld);
    CHECK(adapter.registered_bodies() == 0);
}

} // namespace

// M4 native arbitration runs against the real World field, not a mock mask.
// The ordinary GCR and mutable shard domain must submit one combined owner
// publication. Rejected composition cannot clear or perturb an active mask.
void m4_composed_transient_collision_is_atomic() {
    using Cell = World::TransientCompositionCell;
    using Outcome = World::TransientCompositionOutcome;
    World world;
    world.configure_transient_obstacles({0, 0, 64, 64}, true);
    const std::array<Cell, 2> gcr{{{5, 6, 1}, {8, 6, 2}}};
    const std::array<Cell, 2> shards{{{6, 6, 62}, {9, 6, 63}}};
    const auto initial_tick = world.completed_tick_index();
    const auto applied = world.compose_transient_obstacles(gcr, shards, 62);
    CHECK(applied.outcome == Outcome::Applied);
    CHECK(applied.revision == 1 && applied.completed_tick == initial_tick);
    CHECK(applied.gcr_cells == 2 && applied.shard_cells == 2);
    CHECK(world.transient_composition_current(applied));
    CHECK(world.transient_obstacle_at(5, 6) == 1 && world.transient_obstacle_at(8, 6) == 2);
    CHECK(world.transient_obstacle_at(6, 6) == 62 && world.transient_obstacle_at(9, 6) == 63);
    // Cross-domain occupation of one cell is prohibited even if both source
    // lists individually satisfy strict ordering and valid ID partitions.
    const std::array<Cell, 1> overlap{{{5, 6, 62}}};
    const auto rejected = world.compose_transient_obstacles(gcr, overlap, 62);
    CHECK(rejected.outcome == Outcome::Overlap && rejected.revision == applied.revision);
    CHECK(world.transient_obstacle_at(5, 6) == 1 && world.transient_obstacle_at(6, 6) == 62);
    CHECK(!world.transient_composition_current(applied));
    CHECK(!world.has_failed());
    const std::array<Cell, 1> bad_domain{{{10, 6, 62}}};
    const auto invalid = world.compose_transient_obstacles(bad_domain, shards, 62);
    CHECK(invalid.outcome == Outcome::Invalid && invalid.revision == applied.revision);
    CHECK(world.transient_obstacle_at(9, 6) == 63);
    CHECK(!world.transient_composition_current(applied));
    const std::array<Cell, 2> duplicate{{{5, 6, 1}, {5, 6, 2}}};
    CHECK(world.compose_transient_obstacles(duplicate, shards, 62).outcome == Outcome::Invalid);
    CHECK(world.transient_obstacle_at(5, 6) == 1);
    const auto cleared = world.compose_transient_obstacles({}, {}, 62);
    CHECK(cleared.outcome == Outcome::Applied && cleared.revision == 2);
    CHECK(world.transient_obstacle_at(5, 6) == 0 && world.transient_obstacle_at(9, 6) == 0);
    CHECK(world.transient_composition_current(cleared));
    CHECK(world.set_transient_obstacle(20, 8, 1));
    CHECK(!world.transient_composition_current(cleared));
    // Executable negative: the still-unmodified Workbench GCR clear-and-
    // rebuild procedure erases any shard occupancy left by a prior publication.
    // Do not enable both producers until the owner switches to composition.
    const auto before_legacy = world.compose_transient_obstacles(gcr, shards, 62);
    CHECK(before_legacy.outcome == Outcome::Applied);
    world.clear_transient_obstacles();
    CHECK(world.set_transient_obstacle(5, 6, 1));
    CHECK(world.set_transient_obstacle(8, 6, 2));
    CHECK(world.transient_obstacle_at(6, 6) == 0 && world.transient_obstacle_at(9, 6) == 0);
    CHECK(!world.transient_composition_current(before_legacy));
    CHECK(!world.has_failed());
    // Two distinct World generations can issue the same numeric revision.
    // Never let the new owner accept a previous incarnation's receipt.
    World replacement;
    replacement.configure_transient_obstacles({0, 0, 64, 64}, true);
    const auto new_receipt = replacement.compose_transient_obstacles(gcr, shards, 62);
    CHECK(new_receipt.outcome == Outcome::Applied && new_receipt.revision == applied.revision);
    CHECK(new_receipt.world_token != applied.world_token);
    CHECK(!replacement.transient_composition_current(applied));
    CHECK(replacement.transient_composition_current(new_receipt));
}


// Positive owner-local proof: this is the exact same native World before and
// after authoritative transfer; only the external owner advances its tick.
// Rapier installation is a SEPARATE Godot integration gate, not asserted here.
void m4_attached_owner_one_world_native_material_and_mask() {
    using Cell = World::TransientCompositionCell;
    WorldConfig wc;
    wc.chunk_size = 32;
    wc.activity_block_size = 16;
    wc.scheduling_core_size = 32;
    wc.backend = SimulationBackend::SerialInPlace;
    wc.worker_threads = 1;
    World owner(wc);
    const RectI64 domain{0, 0, 128, 96};
    owner.reserve_region({-32, -32, 192, 160});
    owner.reserve_temperature_region({-32, -32, 192, 160});
    owner.set_simulation_region(domain);
    owner.configure_transient_obstacles(domain, true);
    (void)owner.tick();
    const auto created_tick = owner.completed_tick_index();
    Coordinator attached(owner, small_config());
    CHECK(attached.same_world_attached(owner));
    CHECK(&attached.world() == &owner);
    check_population_balance(attached);
    CHECK(owner.completed_tick_index() == created_tick);
    CHECK(attached.step().outcome == Outcome::Unsupported);
    CHECK(owner.completed_tick_index() == created_tick);
    make_supported(attached);
    erase_support(attached);
    check_population_balance(attached);
    CHECK(attached.begin_owner_world_tick().outcome == Outcome::Accepted);
    (void)owner.tick();
    CHECK(owner.completed_tick_index() == created_tick + 1);
    CHECK(attached.after_owner_world_tick().outcome == Outcome::Accepted);
    CHECK(attached.after_owner_world_tick().outcome == Outcome::Stale);
    CHECK(owner.completed_tick_index() == created_tick + 1);
    const auto wood_before = owned_population(attached, Material::Wood);
    CHECK(wood_before >= 9);
    const auto prepared = discover(attached);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome != Outcome::Accepted) return;
    CHECK(activate(attached, prepared.shard));
    CHECK(attached.same_world_attached(owner));
    CHECK(owned_population(attached, Material::Wood) == wood_before);
    CHECK(attached.registry().find(prepared.shard)->owns_inventory());
    check_population_balance(attached);
    const std::array<Cell, 1> immutable{{{6, 7, 1}}};
    CHECK(attached.set_immutable_occupancy(immutable).outcome == Outcome::Accepted);
    CHECK(owner.transient_obstacle_at(6, 7) == 1);
    CHECK(owner.transient_obstacle_at(31, 31) >= Coordinator::kFirstMutableBodyId);
    auto poses = next_poses(attached);
    for (auto& pose: poses) { pose.y += 1.0; pose.pose_serial += 1; }
    CHECK(attached.accept_motion(poses).outcome == Outcome::Accepted);
    CHECK(owner.transient_obstacle_at(6, 7) == 1);
    CHECK(owned_population(attached, Material::Wood) == wood_before);
    check_population_balance(attached);
    // Dynamic Water remains native World-owned and is not silently imported
    // into the shard's structural inventory.
    CHECK(attached.edit(60, 38, {Material::Water, 128, 0, 350}).outcome == Outcome::Accepted);
    const auto water_before = owned_population(attached, Material::Water);
    CHECK(water_before >= 1);
    const auto before_physics_tick = owner.completed_tick_index();
    CHECK(attached.begin_owner_world_tick().outcome == Outcome::Accepted);
    (void)owner.tick();
    poses = next_poses(attached);
    CHECK(attached.after_owner_world_tick(poses).outcome == Outcome::Accepted);
    CHECK(owner.completed_tick_index() == before_physics_tick + 1);
    CHECK(owned_population(attached, Material::Wood) == wood_before);
    check_population_balance(attached);
    CHECK(attached.reset(0, 55).outcome == Outcome::Unsupported);
    CHECK(attached.same_world_attached(owner));
    CHECK(owner.completed_tick_index() == before_physics_tick + 1);
}

void m4_sparse_occupancy_matches_legacy_and_reuse_requires_fresh_witnesses() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World owner(wc);
    const RectI64 domain{0,0,128,96};
    owner.reserve_region({-32,-32,192,160});owner.reserve_temperature_region({-32,-32,192,160});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);
    (void)owner.tick();
    Coordinator attached(owner,small_config()), legacy(small_config());
    for (auto* coordinator:{&attached,&legacy}) {
        make_supported(*coordinator);erase_support(*coordinator);
        const auto prepared=discover(*coordinator);CHECK(prepared.outcome==Outcome::Accepted);
        if (prepared.outcome!=Outcome::Accepted) return;
        CHECK(activate(*coordinator,prepared.shard));
    }
    // The legacy path retains its full row-major mask scan. Compare the whole
    // actual native field through varied accepted physical poses, including
    // old cells that the sparse clear must retire after every rotation.
    for (int step=0;step<24;++step) {
        for (auto* coordinator:{&attached,&legacy}) {
            auto poses=next_poses(*coordinator);
            poses[0].x+=.43;poses[0].y+=.21;
            poses[0].rotation=.12*std::sin(static_cast<double>(step)*.4);
            CHECK(coordinator->accept_motion(poses).outcome==Outcome::Accepted);
        }
        bool identical=true;
        for (int y=0;y<96;++y) for (int x=0;x<128;++x)
            identical=identical && (owner.transient_obstacle_at(x,y)!=0)==
                (legacy.world().transient_obstacle_at(x,y)!=0);
        CHECK(identical);
        CHECK(owned_population(attached,Material::Wood)==owned_population(legacy,Material::Wood));
    }
    // Walk a rotated body partly over the resident edge. Refusal occurs
    // during raster construction after some cells have already been visited;
    // a subsequent valid pose must clear that scratch without ghost cells.
    bool edge_refused=false;
    for (int step=0;step<128 && !edge_refused;++step) {
        std::array<Outcome,2> outcomes{};std::size_t index=0;
        for (auto* coordinator:{&attached,&legacy}) {
            auto poses=next_poses(*coordinator);poses[0].x+=1.0;
            outcomes[index++]=coordinator->accept_motion(poses).outcome;
        }
        CHECK(outcomes[0]==outcomes[1]);
        CHECK(outcomes[0]==Outcome::Accepted || outcomes[0]==Outcome::NotResident);
        edge_refused=outcomes[0]==Outcome::NotResident;
    }
    CHECK(edge_refused && !attached.paused());
    for (auto* coordinator:{&attached,&legacy}) {
        auto poses=next_poses(*coordinator);poses[0].x-=1.0;poses[0].rotation=-poses[0].rotation;
        CHECK(coordinator->accept_motion(poses).outcome==Outcome::Accepted);
    }
    bool retry_identical=true;
    for (int y=0;y<96;++y) for (int x=0;x<128;++x)
        retry_identical=retry_identical && (owner.transient_obstacle_at(x,y)!=0)==
            (legacy.world().transient_obstacle_at(x,y)!=0);
    CHECK(retry_identical);
    using Cell=World::TransientCompositionCell;
    const std::array<Cell,1> gcr{{{5,6,1}}};
    CHECK(attached.set_immutable_occupancy(gcr).outcome==Outcome::Accepted);
    auto reused=attached.metrics().composed_reuses;
    const auto mask_cells=attached.metrics().mask_cells;
    CHECK(attached.set_immutable_occupancy(gcr).outcome==Outcome::Accepted);
    CHECK(attached.metrics().composed_reuses==reused+1 && attached.metrics().mask_cells==mask_cells);
    reused=attached.metrics().composed_reuses;
    // Legacy clear/set invalidates the actual World receipt even though the
    // immutable input and material revisions have not changed.
    owner.clear_transient_obstacles();CHECK(owner.set_transient_obstacle(5,6,1));
    CHECK(attached.set_immutable_occupancy(gcr).outcome==Outcome::Accepted);
    CHECK(attached.metrics().composed_reuses==reused);
    bool restored=true;
    for (int y=0;y<96;++y) for (int x=0;x<128;++x)
        if (legacy.world().transient_obstacle_at(x,y))
            restored=restored && owner.transient_obstacle_at(x,y)>=Coordinator::kFirstMutableBodyId;
    CHECK(restored);
    // A native World material edit forces renewed overlap validation even
    // though the exact GCR field and geometry remain unchanged.
    CHECK(attached.edit(70,30,{Material::Sand,91,37,270}).outcome==Outcome::Accepted);
    CHECK(attached.set_immutable_occupancy(gcr).outcome==Outcome::Accepted);
    CHECK(attached.metrics().composed_reuses==reused);
    CHECK(attached.set_immutable_occupancy(gcr).outcome==Outcome::Accepted);
    CHECK(attached.metrics().composed_reuses==++reused);
    CHECK(attached.begin_owner_world_tick().outcome==Outcome::Accepted);(void)owner.tick();
    CHECK(attached.after_owner_world_tick().outcome==Outcome::Accepted);
    CHECK(attached.set_immutable_occupancy(gcr).outcome==Outcome::Accepted);
    CHECK(attached.metrics().composed_reuses==reused);
    const std::array<Cell,1> moved{{{6,6,1}}};
    CHECK(attached.set_immutable_occupancy(moved).outcome==Outcome::Accepted);
    CHECK(attached.metrics().composed_reuses==reused);
    CHECK(owner.transient_obstacle_at(5,6)==0 && owner.transient_obstacle_at(6,6)==1);
    CHECK(attached.set_immutable_occupancy(moved).outcome==Outcome::Accepted);
    CHECK(attached.metrics().composed_reuses==reused+1);
    check_population_balance(attached);
}

void m4_attached_displacement_crosses_original_mixed_pool_with_exact_inventory() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World owner(wc);
    const RectI64 domain{0,0,512,512};
    owner.reserve_region({-32,-32,576,576});owner.reserve_temperature_region({-32,-32,576,576});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);
    (void)owner.tick();
    auto config=small_config();config.world_bounds={0,0,512,512};
    config.limits.max_shards=16;config.limits.max_area=16384;config.limits.max_total_area=65536;
    config.limits.max_shapes=512;
    Coordinator attached(owner,config);
    const auto box=[&](int x,int y,int width,int height,Material material) {
        bool admitted=true;
        const auto amount=material==Material::Water ? owner.config().water_experiment_policy.maximum() : 0;
        for (int row=0;row<height;++row) for (int column=0;column<width;++column)
            admitted=attached.edit(x+column,y+row,{material,static_cast<std::uint16_t>(amount),0,200}).outcome==Outcome::Accepted && admitted;
        CHECK(admitted);
    };
    // Same facade, supports and 136x22 Water over 136x12 Sand as the ordinary
    // mixed Workbench preset; no thinner substitute population is admitted.
    box(0,464,512,48,Material::Wall);box(0,0,3,512,Material::Wall);box(509,0,3,512,Material::Wall);
    box(120,244,96,8,Material::RedBrick);
    box(120,252,8,112,Material::Wood);box(208,252,8,112,Material::Wood);
    for (const int y:{276,308,340,360}) box(120,y,96,4,Material::RedBrick);
    box(164,252,6,108,Material::Wood);
    for (const int x:{138,194}) box(x,364,4,100,Material::Wall);
    box(108,452,136,12,Material::Sand);box(108,430,136,22,Material::Water);
    box(104,430,4,34,Material::Wall);box(244,430,4,34,Material::Wall);
    for (const int x:{137,193}) box(x,366,6,98,Material::Empty);
    const auto prepared=discover(attached);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(attached,prepared.shard));
    const auto wood=owned_population(attached,Material::Wood);
    const auto sand=owned_population(attached,Material::Sand);
    const auto starting=owner.quantity_ledger();
    const auto water=starting.water_visible+starting.water_overfill+starting.water_ballistic;
    bool completed=true;
    for (int step=0;step<77;++step) {
        const auto before=owner.quantity_ledger();
        auto poses=next_poses(attached);poses[0].y+=1.25;
        const auto accepted=attached.accept_motion(poses);
        CHECK(accepted.outcome==Outcome::Accepted);
        if (accepted.outcome!=Outcome::Accepted) {
            std::fprintf(stderr,"Mixed pool stopped at segment %d: %s (%s)\n",step,outcome_name(accepted.outcome),accepted.detail);
            completed=false;break;
        }
        const auto after=owner.quantity_ledger();
        CHECK(after.material_cells==before.material_cells);
        CHECK(after.water_visible==before.water_visible && after.water_overfill==before.water_overfill &&
            after.water_ballistic==before.water_ballistic);
        if (step%4==3) {
            CHECK(attached.begin_owner_world_tick().outcome==Outcome::Accepted);(void)owner.tick();
            CHECK(attached.after_owner_world_tick().outcome==Outcome::Accepted);
        }
    }
    CHECK(completed);
    CHECK(attached.metrics().relocated_water_cells>0 && attached.metrics().relocated_sand_cells>0);
    CHECK(attached.metrics().relocation_probe_limit_hits==0 && !attached.paused() && !owner.has_failed());
    CHECK(owned_population(attached,Material::Wood)==wood && owned_population(attached,Material::Sand)==sand);
    const auto final=owner.quantity_ledger();
    CHECK(final.water_visible+final.water_overfill+final.water_ballistic==water);
    check_population_balance(attached);
}

void m4_displacement_radius_and_work_refuse_before_any_material_move() {
    const auto exercise=[](bool limited_work) {
        WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
        World owner(wc);
        const RectI64 domain{0,0,128,96};
        owner.reserve_region({-32,-32,192,160});owner.reserve_temperature_region({-32,-32,192,160});
        owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);
        (void)owner.tick();
        auto config=small_config();
        if (limited_work) config.relocation_probe_budget=1;
        Coordinator attached(owner,config);
        const auto amount=static_cast<std::uint16_t>(owner.config().water_experiment_policy.maximum());
        bool authored=true;
        if (!limited_work) {
            for (int y=0;y<96;++y) for (int x=0;x<128;++x)
                authored=attached.edit(x,y,{Material::Water,amount,0,200}).outcome==Outcome::Accepted && authored;
            // An Empty destination exists, but lies beyond the declared 64-cell
            // attached search radius. The solver may not teleport to it.
            authored=attached.edit(100,30,empty()).outcome==Outcome::Accepted && authored;
        }
        for (int y=30;y<33;++y) for (int x=30;x<33;++x)
            authored=attached.edit(x,y,{Material::Wood,47,0,231}).outcome==Outcome::Accepted && authored;
        if (limited_work) for (int x=30;x<33;++x)
            authored=attached.edit(x,34,{Material::Water,amount,0,200}).outcome==Outcome::Accepted && authored;
        CHECK(authored);
        const auto prepared=discover(attached);CHECK(prepared.outcome==Outcome::Accepted);
        if (prepared.outcome!=Outcome::Accepted) return;
        CHECK(activate(attached,prepared.shard));
        std::vector<Payload> before;std::vector<std::uint16_t> mask;
        for (int y=0;y<96;++y) for (int x=0;x<128;++x) {
            before.push_back(attached.inspect_world(x,y));mask.push_back(owner.transient_obstacle_at(x,y));
        }
        const auto prior=attached.m4_owner_readback().bodies[0].pose;
        auto poses=next_poses(attached);
        poses[0].y+=limited_work ? 1.5 : .25;
        if (!limited_work) poses[0].x+=.25;
        const auto result=attached.accept_motion(poses);
        CHECK(result.outcome==(limited_work ? Outcome::Capacity : Outcome::DestinationUnavailable));
        const auto retained=attached.m4_owner_readback().bodies[0].pose;
        CHECK(retained.x==prior.x && retained.y==prior.y && retained.pose_serial==prior.pose_serial);
        bool unchanged=true;std::size_t at=0;
        for (int y=0;y<96;++y) for (int x=0;x<128;++x,++at)
            unchanged=unchanged && attached.inspect_world(x,y)==before[at] && owner.transient_obstacle_at(x,y)==mask[at];
        CHECK(unchanged && !owner.has_failed() && !attached.paused());
        CHECK(attached.metrics().relocated_cells==0 && attached.metrics().relocated_water_cells==0);
        CHECK(attached.metrics().relocation_probe_limit_hits==(limited_work ? 1U : 0U));
        if (limited_work) CHECK(attached.metrics().relocation_probes==1);
        check_population_balance(attached);
    };
    exercise(false);exercise(true);
    // Preserve the original laboratory contract behaviorally: a large Empty
    // escape region exists eleven cells from the entering material, but its
    // native solver still refuses beyond radius8 rather than adopting M4's
    // wider bounded displacement policy implicitly.
    Coordinator standalone(small_config());bool authored=true;
    for (int y=0;y<96;++y) for (int x=0;x<128;++x)
        authored=standalone.edit(x,y,{Material::Water,255,0,200}).outcome==Outcome::Accepted && authored;
    for (int y=24;y<40;++y) for (int x=44;x<52;++x)
        authored=standalone.edit(x,y,empty()).outcome==Outcome::Accepted && authored;
    for (int y=30;y<33;++y) for (int x=30;x<33;++x)
        authored=standalone.edit(x,y,{Material::Wood}).outcome==Outcome::Accepted && authored;
    CHECK(authored);
    const auto prepared=discover(standalone);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(standalone,prepared.shard));
    const auto original=standalone.m4_owner_readback().bodies[0].pose;
    auto poses=next_poses(standalone);poses[0].x+=.25;poses[0].y+=.25;
    CHECK(standalone.accept_motion(poses).outcome==Outcome::DestinationUnavailable);
    const auto retained=standalone.m4_owner_readback().bodies[0].pose;
    CHECK(retained.x==original.x && retained.y==original.y && retained.pose_serial==original.pose_serial);
    CHECK(standalone.metrics().relocated_cells==0 && !standalone.world().has_failed());
    check_population_balance(standalone);
}

void m4_rooted_mixed_architecture_keeps_severed_wall_caps_and_atomic_masks() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    wc.initial_chunk_reserve=32;wc.maximum_chunk_count=128;
    wc.active_chunk_capacity=128;wc.active_core_capacity=128;
    World owner(wc);
    const RectI64 domain{0,0,128,96};
    owner.reserve_region({-32,-32,192,160});owner.reserve_temperature_region({-32,-32,192,160});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);
    (void)owner.tick();
    Coordinator attached(owner,small_config());
    CHECK(attached.can_detach());
    bool competing_owner_refused=false;
    try {Coordinator second(owner,small_config());}
    catch (const std::invalid_argument&) {competing_owner_refused=true;}
    CHECK(competing_owner_refused);
    for (int x=0;x<128;++x) CHECK(attached.edit(x,88,{Material::Wall}).outcome==Outcome::Accepted);
    for (int y=60;y<88;++y) CHECK(attached.edit(30,y,{Material::Wall}).outcome==Outcome::Accepted);
    for (int y=40;y<60;++y) for (int x=26;x<46;++x) {
        const auto material=x<36 ? Material::Wood : x<41 ? Material::RedBrick : Material::Concrete;
        CHECK(attached.edit(x,y,{material}).outcome==Outcome::Accepted);
    }
    for (int i=0;i<30 && !attached.snapshot(false).admission.census_complete;++i)
        CHECK(attached.prepare_next().outcome!=Outcome::Accepted);
    CHECK(attached.snapshot(false).admission.eligible==0);
    // Only the middle is erased. The small Wall cap still touches the facade;
    // it must travel with the disconnected mixed structure, not pin it forever.
    for (int y=64;y<68;++y) CHECK(attached.edit(30,y,empty()).outcome==Outcome::Accepted);
    const auto prepared=discover(attached);
    CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(attached,prepared.shard));
    const auto* shard=attached.registry().find(prepared.shard);
    CHECK(shard && shard->counts().structural==404);
    CHECK(attached.accounting().promoted[static_cast<unsigned>(Material::Wall)]==4);
    CHECK(attached.accounting().promoted[static_cast<unsigned>(Material::Wood)]==200);
    CHECK(attached.accounting().promoted[static_cast<unsigned>(Material::RedBrick)]==100);
    CHECK(attached.accounting().promoted[static_cast<unsigned>(Material::Concrete)]==100);
    check_population_balance(attached);
    CHECK(!attached.can_detach());
    CHECK(attached.detach().outcome==Outcome::Fenced);
    CHECK(attached.same_world_attached(owner));
    using Cell=World::TransientCompositionCell;
    const std::array<Cell,2> touching{{{30,50,1},{80,80,2}}};
    CHECK(attached.set_immutable_occupancy(touching).outcome==Outcome::Accepted);
    CHECK(owner.transient_obstacle_at(30,50)==1);
    CHECK(owner.transient_obstacle_at(31,50)>=Coordinator::kFirstMutableBodyId);
    CHECK(owner.transient_obstacle_at(80,80)==2);
    CHECK(attached.metrics().composed_overlap_cells>0);
    const std::array<Cell,2> duplicate{{{30,50,1},{30,50,2}}};
    CHECK(attached.set_immutable_occupancy(duplicate).outcome==Outcome::Invalid);
    CHECK(owner.transient_obstacle_at(30,50)==1);
    CHECK(owner.transient_obstacle_at(31,50)>=Coordinator::kFirstMutableBodyId);
    CHECK(!attached.snapshot(false).quarantined && !owner.has_failed());
    CHECK(attached.set_immutable_occupancy({}).outcome==Outcome::Accepted);
    CHECK(owner.transient_obstacle_at(30,50)>=Coordinator::kFirstMutableBodyId);
    CHECK(owner.transient_obstacle_at(80,80)==0);
    check_population_balance(attached);
    CHECK(attached.snapshot(false).world_materials.empty());
    CHECK(attached.snapshot(true).world_materials.size()==128U*96U);
}

void m4_sixteen_attached_owners_preserve_seventeenth_inventory() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    wc.initial_chunk_reserve=64;wc.maximum_chunk_count=256;
    wc.active_chunk_capacity=256;wc.active_core_capacity=256;
    World owner(wc);
    const RectI64 domain{0,0,256,128};
    owner.reserve_region({-32,-32,320,192});owner.reserve_temperature_region({-32,-32,320,192});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);
    (void)owner.tick();
    auto config=small_config();config.world_bounds={0,0,256,128};
    config.limits.max_shards=16;config.limits.max_total_area=32768;
    Coordinator attached(owner,config);
    for (int n=0;n<17;++n) for (int y=0;y<3;++y) for (int x=0;x<3;++x)
        CHECK(attached.edit(8+(n%8)*29+x,8+(n/8)*30+y,{Material::Wood}).outcome==Outcome::Accepted);
    for (int n=0;n<16;++n) {
        const auto prepared=discover(attached);
        CHECK(prepared.outcome==Outcome::Accepted);
        if (prepared.outcome!=Outcome::Accepted) return;
        CHECK(activate(attached,prepared.shard));
        CHECK(attached.m4_owner_readback().active_count==static_cast<unsigned>(n+1));
        check_population_balance(attached);
    }
    CHECK(!attached.m4_owner_readback().truncated);
    CHECK(attached.prepare_next().outcome==Outcome::Capacity);
    CHECK(world_population(attached,Material::Wood)==9);
    CHECK(owned_population(attached,Material::Wood)==17U*9U);
    CHECK(attached.snapshot(false).admission.reason==AdmissionReason::BodySlots);
    check_population_balance(attached);
}

void m4_fragmentation_is_exact_staged_and_conserves_rigid_velocity() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World owner(wc);const RectI64 domain{0,0,128,96};
    owner.reserve_region({-32,-32,192,160});owner.reserve_temperature_region({-32,-32,192,160});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);(void)owner.tick();
    Coordinator attached(owner,small_config());
    for (int y=20;y<25;++y) for (int x=20;x<35;++x)
        CHECK(attached.edit(x,y,{Material::Wood,static_cast<std::uint16_t>(x+y),0,350}).outcome==Outcome::Accepted);
    const auto prepared=discover(attached);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(attached,prepared.shard));
    auto motion=next_poses(attached);motion[0].rotation=.1;motion[0].vx=2.;motion[0].vy=3.;motion[0].angular_velocity=.5;
    CHECK(attached.accept_motion(motion).outcome==Outcome::Accepted);
    const auto request=[&](std::uint32_t at) {
        const auto* shard=attached.registry().find(prepared.shard);
        const auto proof=attached.m4_owner_readback();const auto pose=proof.bodies[0].pose;
        return ShardEditRequest{prepared.shard,attached.next_transaction(),pose.body_generation,
            shard->geometry().revision,pose.pose_serial,shard->material_revision(),at,
            shard->schedule(at).incarnation,shard->payload(at)};
    };
    auto* parent=attached.registry().find(prepared.shard);const auto bounds=parent->bounds();
    const auto observed_cell=static_cast<std::uint32_t>((21-bounds.y)*bounds.width+21-bounds.x);
    const auto observed=request(observed_cell);
    CHECK(attached.act_on_shard(observed,ShardAction::Inspect).outcome==Outcome::Accepted);
    const auto old_digest=parent->payload_digest();
    CHECK(attached.act_on_shard(observed,ShardAction::Inspect).outcome==Outcome::Accepted);
    CHECK(parent->payload_digest()==old_digest);
    auto stale=request(observed_cell);++stale.incarnation;
    CHECK(attached.act_on_shard(stale,ShardAction::Ignite).outcome==Outcome::Stale);
    CHECK(parent->payload_digest()==old_digest);
    CHECK(attached.act_on_shard(request(observed_cell),ShardAction::Ignite).outcome==Outcome::Accepted);
    const auto uncut_mass=parent->geometry().mass;
    const auto uncut_pose=attached.m4_owner_readback().bodies[0].pose;
    for (int y=20;y<25;++y) {
        const auto local=static_cast<std::uint32_t>((y-bounds.y)*bounds.width+26-bounds.x);
        CHECK(attached.erase_shard(request(local)).outcome==Outcome::Accepted);
        install_geometry(attached);
    }
    CHECK(parent->geometry().islands==2 && parent->counts().structural==70);
    const auto cut_pose=attached.m4_owner_readback().bodies[0].pose;
    const auto cut_dx=parent->geometry().mass.com_x-uncut_mass.com_x;
    const auto cut_dy=parent->geometry().mass.com_y-uncut_mass.com_y;
    const auto cut_cs=std::cos(uncut_pose.rotation),cut_sn=std::sin(uncut_pose.rotation);
    CHECK(std::abs(cut_pose.vx-(uncut_pose.vx-uncut_pose.angular_velocity*(cut_sn*cut_dx+cut_cs*cut_dy)))<1e-10);
    CHECK(std::abs(cut_pose.vy-(uncut_pose.vy+uncut_pose.angular_velocity*(cut_cs*cut_dx-cut_sn*cut_dy)))<1e-10);
    CHECK(cut_pose.angular_velocity==uncut_pose.angular_velocity);
    check_population_balance(attached);
    const auto source_schedule=parent->schedule(observed_cell);const auto source_payload=parent->payload(observed_cell);
    const auto original_digest=parent->payload_digest();const auto original_geometry=parent->geometry();
    const auto source_pose=attached.m4_owner_readback().bodies[0].pose;
    const auto staged=attached.prepare_next();CHECK(staged.outcome==Outcome::Accepted);
    const auto* child=attached.registry().find(staged.shard);
    CHECK(child && !child->owns_inventory() && parent->payload_digest()==original_digest);
    CHECK(attached.snapshot(false).promotion.source_parent==prepared.shard);
    CHECK(owned_population(attached,Material::Wood)==70);
    // Cancellation before any physical reservation leaves every source tuple.
    CHECK(attached.cancel(staged.transaction).outcome==Outcome::Cancelled);
    CHECK(parent->payload_digest()==original_digest && parent->geometry().revision==original_geometry.revision);
    const auto retry=attached.prepare_next();CHECK(retry.outcome==Outcome::Accepted);
    child=attached.registry().find(retry.shard);
    CHECK(child && child->counts().structural==30);
    if (!child) return;
    const auto child_bounds=child->bounds();
    const auto child_cell=static_cast<std::uint32_t>((21-child_bounds.y)*child_bounds.width+21-child_bounds.x);
    CHECK(child->payload(child_cell)==source_payload);
    CHECK(child->schedule(child_cell).birth_tick==source_schedule.birth_tick);
    CHECK(child->schedule(child_cell).next_due_tick==source_schedule.next_due_tick);
    CHECK(child->schedule(child_cell).incarnation==source_schedule.incarnation);
    CHECK(attached.acknowledge(ack_for(attached,AckKind::PhysicsReserved)).outcome==Outcome::Accepted);
    CHECK(parent->counts().structural==40 && child->owns_inventory());
    CHECK(parent->payload(observed_cell).material==Material::Empty);
    CHECK(owned_population(attached,Material::Wood)==70 && world_population(attached,Material::Wood)==0);
    CHECK(attached.acknowledge(ack_for(attached,AckKind::TerrainInstalled)).outcome==Outcome::Accepted);
    CHECK(attached.acknowledge(ack_for(attached,AckKind::BodyActivated)).outcome==Outcome::Fenced);
    install_geometry(attached);
    CHECK(attached.acknowledge(ack_for(attached,AckKind::BodyActivated)).outcome==Outcome::Accepted);
    CHECK(!attached.paused() && attached.m4_owner_readback().active_count==2);
    const auto proof=attached.m4_owner_readback();
    const auto cs=std::cos(source_pose.rotation),sn=std::sin(source_pose.rotation);
    double px=0,py=0;
    for (std::size_t i=0;i<proof.copied_count;++i) {
        const auto& physical=proof.bodies[i];const auto* shard=attached.registry().find(physical.shard);
        const auto& mass=shard->geometry().mass;
        const auto dx=static_cast<double>(shard->bounds().x-bounds.x)+mass.com_x-original_geometry.mass.com_x;
        const auto dy=static_cast<double>(shard->bounds().y-bounds.y)+mass.com_y-original_geometry.mass.com_y;
        CHECK(std::abs(physical.pose.vx-(source_pose.vx-source_pose.angular_velocity*(sn*dx+cs*dy)))<1e-10);
        CHECK(std::abs(physical.pose.vy-(source_pose.vy+source_pose.angular_velocity*(cs*dx-sn*dy)))<1e-10);
        CHECK(physical.pose.angular_velocity==source_pose.angular_velocity);
        px+=mass.mass*physical.pose.vx;py+=mass.mass*physical.pose.vy;
    }
    CHECK(std::abs(px-original_geometry.mass.mass*source_pose.vx)<1e-9);
    CHECK(std::abs(py-original_geometry.mass.mass*source_pose.vy)<1e-9);
    CHECK(attached.metrics().fragments==1);
    check_population_balance(attached);
    CHECK(attached.begin_owner_world_tick().outcome==Outcome::Accepted);(void)owner.tick();
    CHECK(attached.after_owner_world_tick().outcome==Outcome::Accepted);
    CHECK(child->payload(child_cell).state_b==source_payload.state_b-1);
    install_geometry(attached);check_population_balance(attached);
}

void m4_attached_replacement_destroys_coordinator_before_world() {
    const auto new_world=[] {
        WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
        auto owner=std::make_unique<World>(wc);const RectI64 domain{0,0,128,96};
        owner->reserve_region({-32,-32,192,160});owner->reserve_temperature_region({-32,-32,192,160});
        owner->set_simulation_region(domain);owner->configure_transient_obstacles(domain,true);(void)owner->tick();
        return owner;
    };
    auto owner=new_world();auto attached=std::make_unique<Coordinator>(*owner,small_config());
    for (int replacement=0;replacement<4;++replacement) {
        CHECK(attached->edit(30,30,{Material::Wood}).outcome==Outcome::Accepted);
        const auto pending=discover(*attached);CHECK(pending.outcome==Outcome::Accepted);
        if (pending.outcome!=Outcome::Accepted) return;
        CHECK(activate(*attached,pending.shard));
        const auto stale=geometry_ack(*attached,pending.shard);
        const auto before=owned_population(*attached,Material::Wood);
        auto candidate=new_world();
        // The retained-cell preparation admission does not discard a live
        // owner merely because a replacement World was successfully built.
        CHECK(!attached->can_detach());CHECK(attached->same_world_attached(*owner));
        CHECK(owned_population(*attached,Material::Wood)==before);
        // Exact lifetime order used at all native facade replacement fences.
        attached.reset();owner.swap(candidate);candidate.reset();
        attached=std::make_unique<Coordinator>(*owner,small_config());
        CHECK(attached->acknowledge(stale).outcome==Outcome::Retired);
        CHECK(attached->set_immutable_occupancy({}).outcome==Outcome::Accepted);
        CHECK(attached->begin_owner_world_tick().outcome==Outcome::Accepted);(void)owner->tick();
        CHECK(attached->after_owner_world_tick().outcome==Outcome::Accepted);
        CHECK(owned_population(*attached,Material::Wood)==0);
        CHECK(!owner->has_failed());
    }
}

void m4_settled_reabsorption_preserves_world_and_waits_for_physical_retirement() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World owner(wc);const RectI64 domain{0,0,128,96};
    owner.reserve_region({-32,-32,192,160});owner.reserve_temperature_region({-32,-32,192,160});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);(void)owner.tick();
    Coordinator attached(owner,small_config());
    for (int y=20;y<23;++y) for (int x=20;x<23;++x)
        CHECK(attached.edit(x,y,{Material::Wood,static_cast<std::uint16_t>(x+y),0,420}).outcome==Outcome::Accepted);
    const auto promotion=discover(attached);CHECK(promotion.outcome==Outcome::Accepted);
    if (promotion.outcome!=Outcome::Accepted) return;
    CHECK(activate(attached,promotion.shard));
    const auto* shard=attached.registry().find(promotion.shard);
    const auto cell=static_cast<std::uint32_t>(shard->bounds().width+1);
    const auto request=[&] {
        const auto proof=attached.m4_owner_readback();const auto pose=proof.bodies[0].pose;
        return ShardEditRequest{promotion.shard,attached.next_transaction(),pose.body_generation,
            shard->geometry().revision,pose.pose_serial,shard->material_revision(),cell,
            shard->schedule(cell).incarnation,shard->payload(cell)};
    };
    auto motion=next_poses(attached);motion[0].vx=1.;
    CHECK(attached.accept_motion(motion).outcome==Outcome::Accepted);
    CHECK(attached.act_on_shard(request(),ShardAction::Reabsorb).outcome==Outcome::Busy);
    motion=next_poses(attached);motion[0].vx=0;motion[0].rotation=.1;
    CHECK(attached.accept_motion(motion).outcome==Outcome::Accepted);
    CHECK(attached.act_on_shard(request(),ShardAction::Reabsorb).outcome==Outcome::Unsupported);
    motion=next_poses(attached);motion[0].rotation=0;motion[0].sleeping=true;
    CHECK(attached.accept_motion(motion).outcome==Outcome::Accepted);
    const std::array<World::TransientCompositionCell,1> actor{{{20,20,1}}};
    CHECK(attached.set_immutable_occupancy(actor).outcome==Outcome::Accepted);
    CHECK(attached.act_on_shard(request(),ShardAction::Reabsorb).outcome==Outcome::DestinationUnavailable);
    CHECK(shard->counts().total()==9 && world_population(attached,Material::Wood)==0);
    CHECK(attached.set_immutable_occupancy({}).outcome==Outcome::Accepted);
    const auto digest=shard->payload_digest();const auto staged=attached.act_on_shard(request(),ShardAction::Reabsorb);
    CHECK(staged.outcome==Outcome::Accepted && attached.paused());
    CHECK(attached.snapshot(false).reabsorption.present && !attached.snapshot(false).promotion.present);
    CHECK(shard->payload_digest()==digest && world_population(attached,Material::Wood)==0);
    CHECK(attached.cancel(staged.transaction).outcome==Outcome::Cancelled);
    CHECK(!attached.paused() && shard->payload_digest()==digest);
    const auto final_request=request();const auto final=attached.act_on_shard(final_request,ShardAction::Reabsorb);
    CHECK(final.outcome==Outcome::Accepted);
    const auto ack=[&](AckKind kind) {
        const auto view=attached.snapshot(false).reabsorption;
        return Acknowledgement{view.shard,view.transaction,view.body_generation,view.payload_digest,
            view.geometry_revision,view.mask_digest,view.shape_digest,kind,
            kind==AckKind::ReabsorptionComplete ? view.terrain : std::span<const TerrainReceipt>{}};
    };
    auto bad=ack(AckKind::ReabsorptionFrozen);++bad.payload_digest;
    CHECK(attached.acknowledge(bad).outcome==Outcome::Stale);
    CHECK(world_population(attached,Material::Wood)==0 && shard->counts().total()==9);
    CHECK(attached.edit(40,40,{Material::Sand}).outcome==Outcome::Fenced);
    const auto frozen=ack(AckKind::ReabsorptionFrozen);
    const auto transferred=attached.acknowledge(frozen);
    if (transferred.outcome!=Outcome::Accepted)
        std::fprintf(stderr,"Reabsorption freeze refused: %s (%s)\n",outcome_name(transferred.outcome),transferred.detail);
    CHECK(transferred.outcome==Outcome::Accepted);
    CHECK(attached.snapshot(false).reabsorption.world_committed && attached.paused());
    CHECK(shard->counts().total()==0 && world_population(attached,Material::Wood)==9);
    CHECK(attached.inspect_world(20,20)==(Payload{Material::Wood,40,0,420}));
    CHECK(owner.transient_obstacle_at(20,20)==0);
    CHECK(attached.begin_owner_world_tick().outcome==Outcome::Fenced);
    CHECK(attached.cancel(final.transaction).outcome==Outcome::Fenced);
    CHECK(attached.acknowledge(frozen).outcome==Outcome::Accepted);
    check_population_balance(attached);
    const auto completion=ack(AckKind::ReabsorptionComplete);
    CHECK(!completion.terrain.empty());
    auto wrong_terrain=completion;wrong_terrain.terrain={};
    CHECK(attached.acknowledge(wrong_terrain).outcome==Outcome::Stale);
    CHECK(attached.acknowledge(completion).outcome==Outcome::Accepted);
    CHECK(attached.registry().find(promotion.shard)==nullptr && !attached.paused());
    CHECK(attached.m4_owner_readback().active_count==0 && attached.can_detach());
    CHECK(attached.acknowledge(completion).outcome==Outcome::Accepted);
    CHECK(attached.act_on_shard(final_request,ShardAction::Reabsorb).outcome==Outcome::Accepted);
    CHECK(attached.metrics().reabsorptions==1);
    check_population_balance(attached);
    CHECK(attached.detach().outcome==Outcome::Retired);
    CHECK(!attached.same_world_attached(owner));
    CHECK(owner.stored_material(20,20)==Material::Wood && !owner.has_failed());
    CHECK(attached.snapshot(false).last_result.outcome==Outcome::Retired);
    CHECK(attached.snapshot(false).world_materials.empty() && attached.paused());
    CHECK(attached.inspect_world(20,20).material==Material::Empty && attached.world_witness(20,20)==0);
    CHECK(attached.edit(20,20,empty()).outcome==Outcome::Fenced);
    CHECK(attached.accept_motion({}).outcome==Outcome::Fenced);
    CHECK(attached.begin_owner_world_tick().outcome==Outcome::Fenced);
    CHECK(attached.after_owner_world_tick().outcome==Outcome::Retired);
    CHECK(owner.stored_material(20,20)==Material::Wood);
}

void m4_fragmentation_does_not_launder_invalid_sand_entry() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World owner(wc);const RectI64 domain{0,0,128,96};
    owner.reserve_region({-32,-32,192,160});owner.reserve_temperature_region({-32,-32,192,160});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);(void)owner.tick();
    Coordinator attached(owner,small_config());
    for (int x:{30,32}) CHECK(attached.edit(x,31,{Material::Wood}).outcome==Outcome::Accepted);
    for (int x=30;x<38;++x) CHECK(attached.edit(x,32,{Material::Wood}).outcome==Outcome::Accepted);
    for (int y=30;y<36;++y) for (int x=38;x<44;++x)
        CHECK(attached.edit(x,y,{Material::Wood}).outcome==Outcome::Accepted);
    const auto prepared=discover(attached);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(attached,prepared.shard));
    const auto* parent=attached.registry().find(prepared.shard);
    auto right=next_poses(attached);right[0].x+=2;
    CHECK(attached.accept_motion(right).outcome==Outcome::Accepted);
    CHECK(attached.edit(31,31,{Material::Sand,213,217,-470}).outcome==Outcome::Accepted);
    auto left=next_poses(attached);left[0].x-=2;
    CHECK(attached.accept_motion(left).outcome==Outcome::Accepted);
    CHECK(CoordinatorTestAccess::ingress_fences(attached)==1);
    const auto pose=attached.m4_owner_readback().bodies[0].pose;
    const auto bounds=parent->bounds();
    const auto cut=static_cast<std::uint32_t>((32-bounds.y)*bounds.width+35-bounds.x);
    const ShardEditRequest request{prepared.shard,attached.next_transaction(),pose.body_generation,
        parent->geometry().revision,pose.pose_serial,parent->material_revision(),cut,
        parent->schedule(cut).incarnation,parent->payload(cut)};
    CHECK(attached.erase_shard(request).outcome==Outcome::Accepted);install_geometry(attached);
    const auto digest=parent->payload_digest();
    auto capacity=CoordinatorTestAccess::restrict_ingress_history_capacity(attached);
    CHECK(attached.prepare_next().outcome!=Outcome::Accepted);
    CHECK(!attached.paused() && parent->payload_digest()==digest);
    CHECK(attached.m4_owner_readback().bodies[0].fragment_deferred);
    CHECK(CoordinatorTestAccess::ingress_fences(attached)==1);
    CoordinatorTestAccess::restore_ingress_history_capacity(attached,capacity);
    const auto split=attached.prepare_next();CHECK(split.outcome==Outcome::Accepted);
    if (split.outcome!=Outcome::Accepted) return;
    const auto* child=attached.registry().find(split.shard);
    CHECK(attached.acknowledge(ack_for(attached,AckKind::PhysicsReserved)).outcome==Outcome::Accepted);
    const auto child_cell=static_cast<std::uint32_t>((31-child->bounds().y)*child->bounds().width+31-child->bounds().x);
    CHECK(CoordinatorTestAccess::pocket_fenced(attached,split.shard,child_cell));
    CHECK(CoordinatorTestAccess::ingress_fences(attached)==2);
    install_geometry(attached);
    CHECK(attached.acknowledge(ack_for(attached,AckKind::TerrainInstalled)).outcome==Outcome::Accepted);
    CHECK(attached.acknowledge(ack_for(attached,AckKind::BodyActivated)).outcome==Outcome::Accepted);
    CHECK(attached.accept_motion(next_poses(attached)).outcome==Outcome::Accepted);
    CHECK(attached.begin_owner_world_tick().outcome==Outcome::Accepted);(void)owner.tick();
    CHECK(attached.after_owner_world_tick().outcome==Outcome::Accepted);
    CHECK(child->counts().cargo==0 && world_population(attached,Material::Sand)==1);
    CHECK(CoordinatorTestAccess::pocket_fenced(attached,split.shard,child_cell));
    CHECK(attached.edit(31,31,empty()).outcome==Outcome::Accepted);
    CHECK(attached.accept_motion(next_poses(attached)).outcome==Outcome::Accepted);
    CHECK(!CoordinatorTestAccess::pocket_fenced(attached,split.shard,child_cell));
    check_population_balance(attached);
}

void m4_returned_inventory_resumes_exact_ordinary_world_chemistry() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World owner(wc),reference(wc);
    const auto initialize=[](World& world) {
        const RectI64 domain{0,0,128,96};
        world.reserve_region({-32,-32,192,160});world.reserve_temperature_region({-32,-32,192,160});
        world.set_simulation_region(domain);world.configure_transient_obstacles(domain,true);
        for (int tick=0;tick<17;++tick) (void)world.tick();
    };
    initialize(owner);initialize(reference);
    Coordinator attached(owner,small_config());
    for (int y=20;y<25;++y) for (int x=20;x<25;++x)
        CHECK(attached.edit(x,y,{Material::Wood,37,0,402}).outcome==Outcome::Accepted);
    const auto prepared=discover(attached);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(attached,prepared.shard));
    auto& registry=CoordinatorTestAccess::registry(attached);auto* shard=registry.find(prepared.shard);
    const auto bounds=shard->bounds();const auto tick=owner.completed_tick_index();
    const auto local=[&](int x,int y){return static_cast<std::uint32_t>((y-bounds.y)*bounds.width+x-bounds.x);};
    // Explicit native carrier fixtures isolate the ownership boundary from
    // random product emission. Exact remaining life and burn state, not a
    // restarted material default, must continue in the ordinary destination.
    CHECK(shard->set_cell(local(20,20),{Material::Wood,37,7,402},Role::Structural,tick)==Outcome::Accepted);
    CHECK(shard->set_cell(local(21,21),{Material::Fire,90,0,500},Role::Product,tick)==Outcome::Accepted);
    CHECK(shard->set_cell(local(23,21),{Material::Smoke,189,0,350},Role::Product,tick)==Outcome::Accepted);
    CHECK(shard->set_cell(local(22,23),{Material::Sand,213,217,-470},Role::Cargo,tick)==Outcome::Accepted);
    CHECK(registry.rebuild_geometry(prepared.shard,tick)==Outcome::Accepted);
    CHECK(attached.acknowledge(geometry_ack(attached,prepared.shard)).outcome==Outcome::Accepted);
    struct Seed {std::int64_t x,y;Payload value;};
    std::vector<Seed> source;
    for (std::size_t at=0;at<shard->area();++at) if (shard->occupied(at))
        source.push_back({bounds.x+static_cast<std::int64_t>(at%bounds.width),
            bounds.y+static_cast<std::int64_t>(at/bounds.width),shard->payload(at)});
    const auto pose=attached.m4_owner_readback().bodies[0].pose;const auto cell=local(20,20);
    const ShardEditRequest request{prepared.shard,attached.next_transaction(),pose.body_generation,
        shard->geometry().revision,pose.pose_serial,shard->material_revision(),cell,
        shard->schedule(cell).incarnation,shard->payload(cell)};
    CHECK(attached.act_on_shard(request,ShardAction::Reabsorb).outcome==Outcome::Accepted);
    const auto acknowledgement=[&](AckKind kind) {
        const auto value=attached.snapshot(false).reabsorption;
        return Acknowledgement{value.shard,value.transaction,value.body_generation,value.payload_digest,
            value.geometry_revision,value.mask_digest,value.shape_digest,kind,
            kind==AckKind::ReabsorptionComplete ? value.terrain : std::span<const TerrainReceipt>{}};
    };
    CHECK(attached.acknowledge(acknowledgement(AckKind::ReabsorptionFrozen)).outcome==Outcome::Accepted);
    CHECK(attached.acknowledge(acknowledgement(AckKind::ReabsorptionComplete)).outcome==Outcome::Accepted);
    CHECK(owner.completed_tick_index()==tick && tick==17);
    CHECK(attached.detach().outcome==Outcome::Retired);
    for (const auto& seed:source) {
        CHECK(owner.stored_material(seed.x,seed.y)==seed.value.material);
        CHECK(owner.stored_state_a(seed.x,seed.y)==seed.value.state_a);
        CHECK(owner.stored_state_b(seed.x,seed.y)==seed.value.state_b);
        CHECK(owner.stored_temperature(seed.x,seed.y)==seed.value.temperature);
        CHECK(reference.set_cell_state(seed.x,seed.y,seed.value.material,seed.value.state_a,seed.value.state_b));
        reference.set_temperature(seed.x,seed.y,seed.value.temperature);
    }
    for (unsigned step=0;step<12;++step) {
        (void)owner.tick();(void)reference.tick();
        bool identical=true;
        for (int y=0;y<96;++y) for (int x=0;x<128;++x) {
            const auto material=owner.stored_material(x,y);
            identical=identical && material==reference.stored_material(x,y);
            if (material!=Material::Empty) identical=identical &&
                owner.stored_state_a(x,y)==reference.stored_state_a(x,y) &&
                owner.stored_state_b(x,y)==reference.stored_state_b(x,y) &&
                owner.stored_temperature(x,y)==reference.stored_temperature(x,y);
        }
        CHECK(identical);
        CHECK(owner.completed_tick_index()==tick+step+1 && reference.completed_tick_index()==owner.completed_tick_index());
        CHECK(owner.quantity_ledger().material_cells==reference.quantity_ledger().material_cells);
        CHECK(!owner.has_failed() && !reference.has_failed());
    }
}

void small_low_inertia_fragment_accepts_bounded_actual_segment() {
    Coordinator coordinator(small_config());
    CHECK(coordinator.edit(40,30,{Material::Wood,170,0,200}).outcome==Outcome::Accepted);
    CHECK(coordinator.edit(40,31,{Material::Wall,0,0,200}).outcome==Outcome::Accepted);
    CHECK(coordinator.edit(40,31,empty()).outcome==Outcome::Accepted);
    const auto prepared=discover(coordinator);
    CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(coordinator,prepared.shard));
    const auto* shard=coordinator.registry().find(prepared.shard);
    CHECK(shard && shard->counts().structural==1);
    if (!shard) return;
    CHECK(shard->bounds().width==3 && shard->bounds().height==3);
    const auto original=shard->payload_digest();
    const auto tick=coordinator.world().completed_tick_index();
    auto poses=next_poses(coordinator);
    poses[0].x+=.804;poses[0].rotation+=.274462;poses[0].angular_velocity=68.27;
    CHECK(coordinator.accept_motion(poses).outcome==Outcome::Accepted);
    CHECK(coordinator.world().completed_tick_index()==tick);
    const auto accepted=coordinator.snapshot().bodies[0].pose;
    CHECK(accepted.rotation==poses[0].rotation && accepted.angular_velocity==68.27);
    CHECK(accepted.pose_serial==poses[0].pose_serial && shard->payload_digest()==original);
    CHECK(owned_population(coordinator,Material::Wood)==1);
    check_population_balance(coordinator);
    CHECK(coordinator.accept_motion(poses).outcome==Outcome::Stale);
    auto refused=next_poses(coordinator);refused[0].rotation+=.95;
    CHECK(coordinator.accept_motion(refused).outcome==Outcome::Unsupported);
    CHECK(coordinator.snapshot().bodies[0].pose.pose_serial==accepted.pose_serial);
    refused=next_poses(coordinator);refused[0].x+=4.001;
    CHECK(coordinator.accept_motion(refused).outcome==Outcome::Unsupported);
    CHECK(coordinator.world().completed_tick_index()==tick);
    poses=next_poses(coordinator);poses[0].rotation+=.296369716;
    CHECK(coordinator.accept_motion(poses).outcome==Outcome::Accepted);
    CHECK(coordinator.world().completed_tick_index()==tick);
    CHECK(coordinator.step(next_poses(coordinator)).outcome==Outcome::Accepted);
    CHECK(coordinator.world().completed_tick_index()==tick+1);
    CHECK(owned_population(coordinator,Material::Wood)==1);
    check_population_balance(coordinator);
}


Handle batch_fixture(Coordinator& coordinator,bool mixed=false) {
    for (int y=20;y<28;++y) for (int x=20;x<28;++x)
        CHECK(coordinator.edit(x,y,{mixed && (x%2) ? Material::RedBrick : Material::Wood,37,0,402}).outcome==Outcome::Accepted);
    const auto prepared=discover(coordinator);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return {};
    CHECK(activate(coordinator,prepared.shard));return prepared.shard;
}
std::vector<ShardEditRequest> batch_witnesses(Coordinator& coordinator,Handle handle) {
    std::vector<ShardEditRequest> requests;
    const auto* shard=coordinator.registry().find(handle);
    if (!shard) {CHECK(false);return requests;}
    PoseSample pose;
    for (const auto& body:coordinator.snapshot(false).bodies) if (body.shard==handle) pose=body.pose;
    for (std::uint32_t at=0;at<shard->area();++at) if (shard->structural(at))
        requests.push_back({handle,coordinator.next_transaction(),pose.body_generation,shard->geometry().revision,
            pose.pose_serial,shard->material_revision(),at,shard->schedule(at).incarnation,shard->payload(at)});
    return requests;
}
void m4_batch_world_generation_preflight_is_nonwrapping() {
    MutationJournal journal(0,0,1,1);
    MutationJournalTestAccess::generations(journal,UINT64_MAX-3,UINT64_MAX-1);
    CHECK(journal.can_observe(2,1));
    CHECK(!journal.can_observe(4,1));
    CHECK(!journal.can_observe(2,2));
    journal.observe(0,0,Material::Wood);
    CHECK(journal.revision()==UINT64_MAX-2 && journal.topology_revision()==UINT64_MAX);
    CHECK(journal.can_observe(2,0));
    CHECK(!journal.can_observe(1,1));
    journal.observe(0,0,Material::Wood);journal.observe(0,0,Material::Wood);
    CHECK(journal.revision()==UINT64_MAX && !journal.exhausted());
    CHECK(!journal.can_observe(1,0));
    journal.observe(0,0,Material::Wood);
    CHECK(journal.exhausted() && !journal.can_observe(0,0));
}
void m4_batch_fragment_capacity_retains_inventory_and_recovers() {
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World owner(wc);const RectI64 domain{0,0,128,96};
    owner.reserve_region({-32,-32,192,160});owner.reserve_temperature_region({-32,-32,192,160});
    owner.set_simulation_region(domain);owner.configure_transient_obstacles(domain,true);(void)owner.tick();
    auto config=small_config();config.limits.max_shards=2;
    Coordinator coordinator(owner,config);
    const auto parent=batch_fixture(coordinator);if (!parent.id) return;
    CHECK(coordinator.edit(65,40,{Material::Wood,37,0,402}).outcome==Outcome::Accepted);
    const auto prepared=discover(coordinator);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    const auto blocker=prepared.shard;CHECK(activate(coordinator,blocker));
    CHECK(coordinator.m4_owner_readback().active_count==2 && owned_population(coordinator,Material::Wood)==65);
    const auto* source=coordinator.registry().find(parent);
    auto cut=batch_witnesses(coordinator,parent);
    std::erase_if(cut,[&](const auto& request){return source->bounds().x+request.cell%source->bounds().width!=24;});
    CHECK(cut.size()==8);
    const auto result=coordinator.act_on_shard_batch(cut,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Accepted && result.stats.removed_cells==8 && result.stats.geometry_rebuilds==1);
    CHECK(result.stats.islands_after==2 && source->counts().structural==56);
    install_geometry(coordinator);
    const auto retained=source->payload_digest();
    CHECK(coordinator.prepare_next().outcome!=Outcome::Accepted);
    CHECK(!coordinator.paused() && source->payload_digest()==retained && source->counts().structural==56);
    bool deferred=false;
    for (const auto& body:coordinator.m4_owner_readback().bodies) if (body.shard==parent) deferred=body.fragment_deferred;
    CHECK(deferred && owned_population(coordinator,Material::Wood)==57 && world_population(coordinator,Material::Wood)==0);
    CHECK(coordinator.accept_motion(next_poses(coordinator)).outcome==Outcome::Accepted);
    CHECK(source->payload_digest()==retained);check_population_balance(coordinator);
    const auto erase_blocker=coordinator.act_on_shard_batch(batch_witnesses(coordinator,blocker),ShardAction::Erase);
    CHECK(erase_blocker.result.outcome==Outcome::Accepted && erase_blocker.stats.removed_cells==1);
    install_geometry(coordinator);
    CHECK(coordinator.m4_owner_readback().active_count==1 && owned_population(coordinator,Material::Wood)==56);
    // Existing retirement policy reclaims an empty draining carrier during
    // the next real semantic exchange interval, after physical retirement.
    CHECK(coordinator.begin_owner_world_tick().outcome==Outcome::Accepted);(void)owner.tick();
    CHECK(coordinator.after_owner_world_tick().outcome==Outcome::Accepted);
    CHECK(coordinator.registry().find(blocker)==nullptr);
    const auto split=coordinator.prepare_next();CHECK(split.outcome==Outcome::Accepted);
    if (split.outcome!=Outcome::Accepted) return;
    CHECK(coordinator.acknowledge(ack_for(coordinator,AckKind::PhysicsReserved)).outcome==Outcome::Accepted);
    install_geometry(coordinator);
    CHECK(coordinator.acknowledge(ack_for(coordinator,AckKind::TerrainInstalled)).outcome==Outcome::Accepted);
    CHECK(coordinator.acknowledge(ack_for(coordinator,AckKind::BodyActivated)).outcome==Outcome::Accepted);
    CHECK(!coordinator.paused() && coordinator.m4_owner_readback().active_count==2);
    CHECK(owned_population(coordinator,Material::Wood)==56 && world_population(coordinator,Material::Wood)==0);
    CHECK(coordinator.accounting().authored_destroyed[static_cast<std::uint8_t>(Material::Wood)]==9);
    check_population_balance(coordinator);
}
void m4_batch_witness_atomicity_and_material_accounting() {
    Coordinator coordinator(small_config());const auto handle=batch_fixture(coordinator);
    if (!handle.id) return;
    auto requests=batch_witnesses(coordinator,handle);
    const auto* shard=coordinator.registry().find(handle);
    const auto original=shard->payload_digest(),original_geometry=shard->geometry().revision;
    auto invalid=requests;invalid.back().expected.state_a^=1;
    auto result=coordinator.act_on_shard_batch(invalid,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Stale && result.stats.changed_cells==0);
    CHECK(shard->payload_digest()==original && shard->geometry().revision==original_geometry);
    requests=batch_witnesses(coordinator,handle);invalid=requests;invalid.back().shard.id+=1;
    result=coordinator.act_on_shard_batch(invalid,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Stale && result.stats.changed_cells==0);
    CHECK(shard->payload_digest()==original);
    requests=batch_witnesses(coordinator,handle);invalid=requests;
    invalid.push_back(invalid[0]);invalid.back().incarnation+=1;
    result=coordinator.act_on_shard_batch(invalid,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Stale && result.stats.changed_cells==0);
    CHECK(shard->payload_digest()==original);
    requests=batch_witnesses(coordinator,handle);invalid=requests;invalid[0].shard.session+=1;
    const auto sequence=coordinator.next_transaction();
    result=coordinator.act_on_shard_batch(invalid,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Retired && coordinator.next_transaction()==sequence);
    invalid=std::vector<ShardEditRequest>(kMaximumEditCells+1,requests[0]);
    result=coordinator.act_on_shard_batch(invalid,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Capacity && coordinator.next_transaction()==sequence);
    result=coordinator.act_on_shard_batch({},ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Invalid && coordinator.next_transaction()==sequence);
    result=coordinator.act_on_shard_batch(requests,ShardAction::Erase,{1'000'001,0,-1});
    CHECK(result.result.outcome==Outcome::Invalid && shard->payload_digest()==original);
    result=coordinator.act_on_shard_batch(requests,ShardAction::Erase,{0,16,-1});
    CHECK(result.result.outcome==Outcome::Accepted && result.stats.eligible_cells==64 && result.stats.changed_cells==0);
    CHECK(result.stats.geometry_rebuilds==0 && shard->geometry().revision==original_geometry && shard->payload_digest()==original);

    // Real accepted rotating/sleeping source pose remains editable. Removal
    // preserves the velocity field of surviving cells and wakes its geometry.
    auto poses=next_poses(coordinator);poses[0].rotation=0.10;poses[0].vx=3.0;poses[0].vy=4.0;
    poses[0].angular_velocity=0.75;poses[0].sleeping=true;
    CHECK(coordinator.accept_motion(poses).outcome==Outcome::Accepted);
    requests=batch_witnesses(coordinator,handle);requests.resize(8);requests.push_back(requests[0]);
    const auto old_mass=shard->geometry().mass;const auto tick=coordinator.world().completed_tick_index();
    result=coordinator.act_on_shard_batch(requests,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Accepted && result.stats.requested_cells==9 && result.stats.unique_cells==8);
    CHECK(result.stats.eligible_cells==8 && result.stats.changed_cells==8 && result.stats.removed_cells==8);
    CHECK(result.stats.geometry_rebuilds==1 && shard->geometry().revision==original_geometry+1);
    CHECK(shard->geometry().mass.mass==56 && coordinator.world().completed_tick_index()==tick);
    const auto after_pose=coordinator.snapshot(false).bodies[0].pose;
    const auto dx=shard->geometry().mass.com_x-old_mass.com_x,dy=shard->geometry().mass.com_y-old_mass.com_y;
    CHECK(std::abs(after_pose.vx-(3.0-.75*(std::sin(.10)*dx+std::cos(.10)*dy)))<1e-12);
    CHECK(std::abs(after_pose.vy-(4.0+.75*(std::cos(.10)*dx-std::sin(.10)*dy)))<1e-12);
    CHECK(after_pose.angular_velocity==.75 && !after_pose.sleeping && coordinator.paused());
    check_population_balance(coordinator);
    const auto remaining=owned_population(coordinator,Material::Wood);
    const auto replay=coordinator.act_on_shard_batch(requests,ShardAction::Erase);
    CHECK(replay.replayed && replay.stats.removed_cells==8 && replay.result.outcome==Outcome::Accepted);
    CHECK(owned_population(coordinator,Material::Wood)==remaining);
    requests[0].expected.state_b=1;
    CHECK(coordinator.act_on_shard_batch(requests,ShardAction::Erase).result.outcome==Outcome::Stale);
    install_geometry(coordinator);CHECK(!coordinator.paused());
    requests=batch_witnesses(coordinator,handle);
    result=coordinator.act_on_shard_batch(requests,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Accepted && result.stats.removed_cells==56 && result.stats.geometry_rebuilds==1);
    CHECK(shard->counts().structural==0 && shard->geometry().mass.mass==0 && shard->geometry().shapes.empty());
    install_geometry(coordinator);CHECK(!coordinator.paused());
    CHECK(owned_population(coordinator,Material::Wood)==0);check_population_balance(coordinator);
}
void m4_batch_weathering_and_ignition_are_deterministic() {
    // Mixed architectural materials belong to ordinary M4, while the retained
    // standalone Lab deliberately discovers its original Wood-only domain.
    WorldConfig wc;wc.backend=SimulationBackend::SerialInPlace;wc.worker_threads=1;
    World first_world(wc),second_world(wc);
    for (World* world:{&first_world,&second_world}) {
        world->reserve_region({-32,-32,192,160});world->reserve_temperature_region({-32,-32,192,160});
        world->set_simulation_region(RectI64{0,0,128,96});world->configure_transient_obstacles({0,0,128,96},true);
        (void)world->tick();
    }
    Coordinator first(first_world,small_config()),second(second_world,small_config());
    const auto a=batch_fixture(first,true),b=batch_fixture(second,true);
    if (!a.id || !b.id) return;
    auto wa=batch_witnesses(first,a),wb=batch_witnesses(second,b);
    std::reverse(wb.begin(),wb.end());wb.push_back(wb.front());
    const EditSelection weather{470'000,123456,static_cast<int>(Material::Wood)};
    const auto ra=first.act_on_shard_batch(wa,ShardAction::Erase,weather);
    const auto rb=second.act_on_shard_batch(wb,ShardAction::Erase,weather);
    CHECK(ra.result.outcome==Outcome::Accepted && rb.result.outcome==Outcome::Accepted);
    CHECK(ra.stats.eligible_cells==32 && rb.stats.eligible_cells==32);
    CHECK(ra.stats.changed_cells>0 && ra.stats.changed_cells<32 && ra.stats.changed_cells==rb.stats.changed_cells);
    const auto* sa=first.registry().find(a);const auto* sb=second.registry().find(b);
    CHECK(sa->payload_digest()==sb->payload_digest());
    CHECK(sa->geometry().shape_digest==sb->geometry().shape_digest);
    CHECK(owned_population(first,Material::RedBrick)==32 && owned_population(second,Material::RedBrick)==32);
    check_population_balance(first);check_population_balance(second);
    install_geometry(first);install_geometry(second);
    wa=batch_witnesses(first,a);
    const auto revision=sa->geometry().revision;
    auto ignition=first.act_on_shard_batch(wa,ShardAction::Ignite);
    CHECK(ignition.result.outcome==Outcome::Accepted && ignition.stats.changed_cells==32-ra.stats.removed_cells);
    CHECK(ignition.stats.removed_cells==0 && ignition.stats.geometry_rebuilds==0 && sa->geometry().revision==revision);
    const auto material_revision=sa->material_revision();
    wa=batch_witnesses(first,a);ignition=first.act_on_shard_batch(wa,ShardAction::Ignite);
    CHECK(ignition.result.outcome==Outcome::Accepted && ignition.stats.changed_cells==0 && ignition.stats.eligible_cells==0);
    CHECK(sa->material_revision()==material_revision);
    for (const auto& cell:wa) if (cell.expected.material==Material::Wood) {
        auto value=cell.expected;value.state_b=117;
        CHECK(CoordinatorTestAccess::registry(first).find(a)->set_cell(cell.cell,value,Role::Structural,first.world().completed_tick_index())==Outcome::Accepted);
        CHECK(first.ignite_shard(a,cell.cell).outcome==Outcome::Accepted);
        CHECK(sa->payload(cell.cell).state_b==117);
        break;
    }
    wa=batch_witnesses(first,a);ignition=first.act_on_shard_batch(wa,ShardAction::Ignite);
    CHECK(ignition.stats.changed_cells==0);check_population_balance(first);
}
void m4_world_batch_is_witnessed_deduplicated_and_owner_protected() {
    Coordinator coordinator(small_config());
    for (int x=30;x<38;++x) CHECK(coordinator.edit(x,40,{Material::Wood,37,0,402}).outcome==Outcome::Accepted);
    const auto witnesses=[&]() {
        std::vector<WorldEditTarget> targets;
        for (int x=30;x<38;++x) targets.push_back({x,40,coordinator.inspect_world(x,40),coordinator.world_witness(x,40)});
        targets.push_back(targets[0]);return targets;
    };
    auto targets=witnesses();const auto revision=coordinator.world_material_revision();
    auto result=coordinator.act_on_world_batch(coordinator.m4_owner_readback().session,coordinator.next_transaction(),revision+1,targets,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Stale && world_population(coordinator,Material::Wood)==8);
    targets=witnesses();targets.back().expected.state_b=1;
    result=coordinator.act_on_world_batch(coordinator.m4_owner_readback().session,coordinator.next_transaction(),revision,targets,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Stale && world_population(coordinator,Material::Wood)==8);
    targets=witnesses();
    result=coordinator.act_on_world_batch(coordinator.m4_owner_readback().session,coordinator.next_transaction(),revision,targets,ShardAction::Ignite);
    CHECK(result.result.outcome==Outcome::Accepted && result.stats.requested_cells==9 && result.stats.unique_cells==8 && result.stats.changed_cells==8);
    CHECK(result.stats.removed_cells==0 && result.stats.geometry_rebuilds==0);
    targets=witnesses();
    result=coordinator.act_on_world_batch(coordinator.m4_owner_readback().session,coordinator.next_transaction(),coordinator.world_material_revision(),targets,ShardAction::Ignite);
    CHECK(result.result.outcome==Outcome::Accepted && result.stats.changed_cells==0);
    CHECK(coordinator.inspect_world(30,40).state_b==240);
    auto burning=coordinator.inspect_world(30,40);burning.state_b=31;
    CHECK(coordinator.edit(30,40,burning).outcome==Outcome::Accepted);
    CHECK(coordinator.ignite(30,40).outcome==Outcome::Accepted && coordinator.inspect_world(30,40).state_b==31);
    targets=witnesses();
    result=coordinator.act_on_world_batch(coordinator.m4_owner_readback().session,coordinator.next_transaction(),coordinator.world_material_revision(),targets,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::Accepted && result.stats.removed_cells==8);
    CHECK(world_population(coordinator,Material::Wood)==0);check_population_balance(coordinator);

    const auto owner=batch_fixture(coordinator);
    if (!owner.id) return;
    CHECK(coordinator.edit(70,70,{Material::RedBrick,0,0,200}).outcome==Outcome::Accepted);
    targets={{70,70,coordinator.inspect_world(70,70),coordinator.world_witness(70,70)},
        {23,23,coordinator.inspect_world(23,23),coordinator.world_witness(23,23)}};
    result=coordinator.act_on_world_batch(coordinator.m4_owner_readback().session,coordinator.next_transaction(),coordinator.world_material_revision(),targets,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::DestinationUnavailable && result.stats.changed_cells==0);
    CHECK(coordinator.inspect_world(70,70).material==Material::RedBrick);
    CHECK(owned_population(coordinator,Material::Wood)==64);check_population_balance(coordinator);
    // Product carriers remain visibly owned even inside a true collider hole.
    // Deliberately seed hidden ordinary terrain via the test-only World seam
    // to prove the batch never falls through a visible, uncuttable carrier.
    auto hole=batch_witnesses(coordinator,owner);
    const auto bounds=coordinator.registry().find(owner)->bounds();
    std::erase_if(hole,[&](const auto& r) {
        const auto x=bounds.x+r.cell%bounds.width,y=bounds.y+r.cell/bounds.width;
        return x<22 || x>24 || y<22 || y>24;
    });
    CHECK(coordinator.act_on_shard_batch(hole,ShardAction::Erase).result.outcome==Outcome::Accepted);
    install_geometry(coordinator);
    const auto center=static_cast<std::uint32_t>((23-bounds.y)*bounds.width+23-bounds.x);
    auto* carrier=CoordinatorTestAccess::registry(coordinator).find(owner);
    CHECK(carrier->set_cell(center,{Material::Smoke,100,0,350},Role::Product,coordinator.world().completed_tick_index())==Outcome::Accepted);
    CHECK(!coordinator.world().transient_obstacle_at(23,23));
    CHECK(CoordinatorTestAccess::world(coordinator).set_cell_state(23,23,Material::RedBrick,0,0));
    targets={{23,23,coordinator.inspect_world(23,23),coordinator.world_witness(23,23)}};
    result=coordinator.act_on_world_batch(coordinator.m4_owner_readback().session,coordinator.next_transaction(),coordinator.world_material_revision(),targets,ShardAction::Erase);
    CHECK(result.result.outcome==Outcome::DestinationUnavailable && result.stats.changed_cells==0);
    CHECK(coordinator.inspect_world(23,23).material==Material::RedBrick);
}


void m4_matched_native_batch_performance() {
    using Clock=std::chrono::steady_clock;
    for (const int radius:{1,4,8,16,0}) for (int sample=0;sample<3;++sample) {
        Coordinator single(small_config()),batch(small_config());
        const auto prepare=[](Coordinator& coordinator) {
            bool authored=true;
            for (int y=16;y<64;++y) for (int x=24;x<72;++x)
                authored=coordinator.edit(x,y,{Material::Wood,37,0,402}).outcome==Outcome::Accepted && authored;
            CHECK(authored);
            const auto promoted=discover(coordinator);CHECK(promoted.outcome==Outcome::Accepted);
            if (promoted.outcome!=Outcome::Accepted) return Handle{};
            CHECK(activate(coordinator,promoted.shard));return promoted.shard;
        };
        const auto a=prepare(single),b=prepare(batch);
        if (!a.id || !b.id) return;
        const auto* sa=single.registry().find(a);const auto* sb=batch.registry().find(b);
        std::vector<std::uint32_t> cells;
        const auto bounds=sa->bounds();
        for (std::uint32_t at=0;at<sa->area();++at) if (sa->structural(at)) {
            const auto x=static_cast<int>(bounds.x+at%bounds.width),y=static_cast<int>(bounds.y+at/bounds.width);
            if (radius ? (x-48)*(x-48)+(y-40)*(y-40)<=radius*radius : x==48) cells.push_back(at);
        }
        const auto witness=[](Coordinator& coordinator,Handle handle,std::uint32_t at) {
            const auto* shard=coordinator.registry().find(handle);
            const auto proof=coordinator.m4_owner_readback();PoseSample pose;
            for (std::size_t index=0;index<proof.copied_count;++index)
                if (proof.bodies[index].shard==handle) pose=proof.bodies[index].pose;
            return ShardEditRequest{handle,coordinator.next_transaction(),pose.body_generation,
                shard->geometry().revision,pose.pose_serial,shard->material_revision(),at,
                shard->schedule(at).incarnation,shard->payload(at)};
        };
        const auto installed=[](Coordinator& coordinator,Handle handle) {
            const auto* shard=coordinator.registry().find(handle);const auto proof=coordinator.m4_owner_readback();
            for (std::size_t index=0;index<proof.copied_count;++index) if (proof.bodies[index].shard==handle) {
                const auto& body=proof.bodies[index];const auto& g=shard->geometry();
                return coordinator.acknowledge({handle,body.transaction,body.body_generation,shard->payload_digest(),
                    g.revision,g.mask_digest,g.shape_digest,AckKind::GeometryInstalled,{}}).outcome==Outcome::Accepted;
            }
            return false;
        };
        const auto a_revision=sa->geometry().revision,b_revision=sb->geometry().revision;
        bool single_ok=true;
        const auto single_start=Clock::now();
        for (const auto cell:cells) {
            single_ok=single.erase_shard(witness(single,a,cell)).outcome==Outcome::Accepted && single_ok;
            single_ok=installed(single,a) && single_ok;
        }
        const auto single_ns=std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-single_start).count();
        const auto batch_start=Clock::now();
        std::vector<ShardEditRequest> requests;requests.reserve(cells.size());
        for (const auto cell:cells) requests.push_back(witness(batch,b,cell));
        const auto receipt=batch.act_on_shard_batch(requests,ShardAction::Erase);
        const bool batch_ok=installed(batch,b);
        const auto batch_ns=std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-batch_start).count();
        CHECK(single_ok && batch_ok && receipt.result.outcome==Outcome::Accepted);
        CHECK(sa->payload_digest()==sb->payload_digest());
        CHECK(sa->geometry().mask_digest==sb->geometry().mask_digest);
        CHECK(sa->geometry().shape_digest==sb->geometry().shape_digest);
        CHECK(sa->geometry().mass.mass==sb->geometry().mass.mass);
        CHECK(sa->geometry().mass.com_x==sb->geometry().mass.com_x && sa->geometry().mass.com_y==sb->geometry().mass.com_y);
        CHECK(sa->geometry().mass.inertia==sb->geometry().mass.inertia);
        CHECK(sa->geometry().revision-a_revision==cells.size() && sb->geometry().revision-b_revision==1);
        CHECK(receipt.stats.removed_cells==cells.size() && receipt.stats.geometry_rebuilds==1);
        check_population_balance(single);check_population_balance(batch);
        std::printf("M4_BATCH_BENCH {\"radius\":%d,\"slice\":%s,\"sample\":%d,\"body_area\":%zu,\"initial_material_cells\":2304,\"removed_cells\":%zu,\"single_ns\":%lld,\"batch_ns\":%lld,\"single_geometry_rebuilds\":%llu,\"batch_geometry_rebuilds\":%u,\"batch_target_ns\":%llu,\"batch_mutation_ns\":%llu,\"batch_geometry_ns\":%llu,\"matched\":%s}\n",
            radius,radius ? "false" : "true",sample,sa->area(),cells.size(),
            static_cast<long long>(single_ns),static_cast<long long>(batch_ns),
            static_cast<unsigned long long>(sa->geometry().revision-a_revision),receipt.stats.geometry_rebuilds,
            static_cast<unsigned long long>(receipt.stats.target_ns),static_cast<unsigned long long>(receipt.stats.mutation_ns),
            static_cast<unsigned long long>(receipt.stats.geometry_ns),
            single_ok && batch_ok && sa->payload_digest()==sb->payload_digest() && sa->geometry().shape_digest==sb->geometry().shape_digest ? "true" : "false");
        std::fflush(stdout);
    }
}

int main() {
    m4_matched_native_batch_performance();
    m4_batch_world_generation_preflight_is_nonwrapping();
    m4_batch_fragment_capacity_retains_inventory_and_recovers();
    m4_batch_witness_atomicity_and_material_accounting();
    m4_batch_weathering_and_ignition_are_deterministic();
    m4_world_batch_is_witnessed_deduplicated_and_owner_protected();
    small_low_inertia_fragment_accepts_bounded_actual_segment();
    m4_attached_displacement_crosses_original_mixed_pool_with_exact_inventory();
    m4_displacement_radius_and_work_refuse_before_any_material_move();
    m4_sparse_occupancy_matches_legacy_and_reuse_requires_fresh_witnesses();
    m4_returned_inventory_resumes_exact_ordinary_world_chemistry();
    m4_fragmentation_does_not_launder_invalid_sand_entry();
    m4_settled_reabsorption_preserves_world_and_waits_for_physical_retirement();
    m4_attached_replacement_destroys_coordinator_before_world();
    m4_fragmentation_is_exact_staged_and_conserves_rigid_velocity();
    m4_rooted_mixed_architecture_keeps_severed_wall_caps_and_atomic_masks();
    m4_sixteen_attached_owners_preserve_seventeenth_inventory();
    m4_attached_owner_one_world_native_material_and_mask();
    m4_composed_transient_collision_is_atomic();
    m4_same_world_promotion_and_exact_motion();
    m4_cancel_does_not_consume_world_and_replacement_fences();
    m4_exclusive_mutable_capacity_refuses_fourth_real_owner();
    m4_partial_physics_commit_is_still_exclusive_material();
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
    authentic_fire_output_world_smoke_and_receipt_retirement();
    real_falling_sand_ingress_aba_and_destroyed_pocket();
    wide_rotated_pocket_admits_real_falling_sand();
    overlap_relocation_cannot_create_a_pocket_entry_witness();
    side_entry_refusal_cannot_be_laundered_by_a_stationary_pose();
    segmented_motion_preserves_invalid_pocket_entry_until_semantic_ingress();
    refused_motion_preserves_existing_invalid_entry_history();
    injected_ingress_history_capacity_keeps_inventory_and_reset_live();
    zero_automatic_budget_cannot_bypass_history_through_public_ingress();
    exhausted_transfer_budget_still_records_later_body_entry_history();
    historical_water_exposure_survives_geometry_and_rejects_replacement();
    exposure_capacity_refuses_without_partial_pose_or_clock();
    two_shards_contend_for_one_real_output_destination();
    three_independent_burning_owners();
    population_accounting_covers_world_ticks_edits_transfers_and_resets();
    std::printf("ObjectShard coordinator: %llu checks, %llu failures\n",
        static_cast<unsigned long long>(checks), static_cast<unsigned long long>(failures));
    return failures == 0 ? 0 : 1;
}
