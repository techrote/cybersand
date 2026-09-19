#include "cybersand/bounded_ordered_index.hpp"
#include "cybersand/settled_world_discovery.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <limits>
#include <optional>
#include <span>
#include <stdexcept>
#include <vector>

namespace {
using namespace cybersand::soliding;

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

DiscoverySignals quiet() {
    DiscoverySignals signals{};
    signals.witness_complete = true;
    signals.healthy = true;
    signals.included = true;
    signals.active = false;
    return signals;
}

DiscoveryTileKey key(std::uint64_t incarnation, std::int64_t id) {
    return {incarnation, id / 64, id % 64, id / 16, id % 16, id / 4, id};
}

struct IntLess {
    bool operator()(int a, int b) const noexcept { return a < b; }
};

void bounded_ordered_index_contract() {
    constexpr std::size_t capacity = 1024;
    BoundedOrderedIndex<int, int, IntLess> forward(capacity), reverse(capacity);

    for (int value = 0; value < static_cast<int>(capacity); ++value)
        require(forward.insert(value, value * 3) ==
                    BoundedOrderedIndex<int, int, IntLess>::InsertResult::Inserted,
                "forward AVL insertion succeeds");
    for (int value = static_cast<int>(capacity) - 1; value >= 0; --value)
        require(reverse.insert(value, value * 3) ==
                    BoundedOrderedIndex<int, int, IntLess>::InsertResult::Inserted,
                "reverse AVL insertion succeeds");

    require(forward.height() <= 20 && reverse.height() <= 20,
            "ordered index remains height bounded under adversarial insertion");

    std::vector<int> a, b;
    forward.for_each_in_order([&](int k, int) { a.push_back(k); });
    reverse.for_each_in_order([&](int k, int) { b.push_back(k); });
    require(a == b && a.size() == capacity,
            "canonical traversal is insertion and rotation independent");
    for (std::size_t i = 0; i < a.size(); ++i)
        require(a[i] == static_cast<int>(i), "canonical traversal is sorted");

    require(forward.find(511).has_value() && *forward.find(511) == 1533,
            "bounded ordered lookup returns stored value");
    require(forward.lower_bound(511).has_value() &&
            forward.lower_bound(511)->key == 511,
            "lower bound finds exact key");
    require(forward.predecessor(511).has_value() &&
            forward.predecessor(511)->key == 510,
            "predecessor is strict");
    require(forward.insert(511, 0) ==
                BoundedOrderedIndex<int, int, IntLess>::InsertResult::Duplicate,
            "duplicate remains duplicate at exact capacity");
    require(forward.insert(static_cast<int>(capacity), 0) ==
                BoundedOrderedIndex<int, int, IntLess>::InsertResult::Capacity,
            "one-past ordered index refuses deterministically");
}

void coordinator_direct_handle_contract() {
    constexpr std::uint64_t incarnation = 6001;
    SettledWorldDiscoveryCoordinator coordinator(incarnation, 8, false);
    const auto signals = quiet();

    for (std::int64_t i = 7; i >= 0; --i)
        require(coordinator.register_tile(
                    key(incarnation, i), {i * 2, -4, 1, 1}, 20, signals, 1) ==
                    DiscoveryOutcome::Accepted,
                "reverse canonical registration is accepted");

    const auto layout = coordinator.storage_layout();
    require(layout.key_index_capacity == 8,
            "coordinator balanced key index is runtime capacity T");

    const auto handle = coordinator.find_handle(key(incarnation, 3));
    require(handle.has_value(), "canonical key resolves an owner handle");
    const auto snapshot = coordinator.tile(*handle);
    require(snapshot.has_value() && snapshot->key == key(incarnation, 3),
            "owner handle resolves the same tile");

    const auto probes_after_find = coordinator.producer_metrics().index_probes;
    require(coordinator.dirty(*handle, ProducerReason::DirectMutation, 2) ==
                DiscoveryOutcome::Accepted,
            "direct owner handle invalidates without another key lookup");
    require(coordinator.observe(*handle, signals, ProducerReason::DirectMutation, 2) ==
                DiscoveryOutcome::Unchanged,
            "direct owner handle observes without another key lookup");
    require(coordinator.producer_metrics().index_probes == probes_after_find,
            "direct owner operations do not probe the key index");

    const WorldDiscoveryTileHandle wrong_incarnation{incarnation + 1, handle->slot};
    const WorldDiscoveryTileHandle wrong_slot{incarnation, 99};
    require(coordinator.dirty(wrong_incarnation, ProducerReason::DirectMutation, 2) ==
                DiscoveryOutcome::Stale &&
            coordinator.observe(wrong_slot, signals, ProducerReason::DirectMutation, 2) ==
                DiscoveryOutcome::Stale &&
            !coordinator.tile(wrong_incarnation).has_value(),
            "incarnation and slot qualification fail closed");
}

template<class Regions>
RegionOutcome put(Regions& regions, RegionTileKey tile_key, DiscoveryBounds bounds,
                  std::uint64_t revision, std::span<const DiscoveryCell> cells,
                  std::uint8_t sealed_edges = 0x0f) {
    return regions.upsert(RegionTileInput{
        tile_key, bounds, revision, 20, quiet(), cells, sealed_edges});
}

template<class Regions>
void drain(Regions& regions, std::size_t limit = 100000) {
    std::size_t work = 0;
    while (regions.pending_components() != 0) {
        const auto used = regions.advance(257);
        require(used != 0, "region work remains live");
        work += used;
        require(work < limit, "region work remains bounded");
    }
}

template<class Regions>
std::optional<SettledRegionSnapshot> only_region(const Regions& regions) {
    std::optional<SettledRegionSnapshot> result;
    for (std::size_t i = 0; i < Regions::publication_capacity(); ++i) {
        const auto candidate = regions.region_at(i);
        if (!candidate.has_value()) continue;
        require(!result.has_value(), "fixture publishes only one region");
        result = candidate;
    }
    return result;
}

void generic_rectangle_compatibility() {
    using Regions = SettledRegions<8, 64, 64, 128, 16, 256>;
    constexpr std::uint64_t incarnation = 7001;
    Regions regions(incarnation);

    require(regions.key_index_capacity() == 8 &&
            regions.row_interval_capacity() == 8 * 32,
            "generic compatibility indexes are bounded at T and 32T");

    require(regions.register_unknown(
                key(incarnation, 1), {-8, -4, 4, 3}, 1) ==
                RegionOutcome::Accepted,
            "negative custom rectangle registers");
    require(regions.overlaps_registered({-7, -3, 2, 1}),
            "generic overlap query finds a contained rectangle");
    require(!regions.overlaps_registered({0, -4, 2, 3}),
            "generic overlap query rejects a disjoint rectangle");
    const auto contained = regions.containing_tile({-7, -3, 2, 1});
    require(contained.has_value() && *contained == 0,
            "generic containment resolves the owning rectangle");
    require(!regions.containing_tile({-7, -3, 8, 1}).has_value(),
            "containment rejects a query crossing the owner boundary");

    require(regions.register_unknown(
                key(incarnation, 2), {-6, -3, 4, 2}, 1) ==
                RegionOutcome::Invalid,
            "overlapping arbitrary rectangle is rejected");
    require(regions.register_unknown(
                key(incarnation, 3), {0, -4, 2, 3}, 1) ==
                RegionOutcome::Accepted,
            "disjoint arbitrary rectangle is accepted");
}

struct RegionDigest {
    std::uint64_t member{}, dependency{};
    std::uint64_t area{};
    std::uint32_t tiles{}, components{}, dependencies{};
};

RegionDigest partial_face_fixture(bool reverse) {
    using Regions = SettledRegions<4, 16, 16, 64, 8, 64>;
    constexpr std::uint64_t incarnation = 8001;
    Regions regions(incarnation);
    const std::array<DiscoveryCell, 16> left_cells{{
        {1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},
        {1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},
        {1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},
        {1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},
    }};
    const std::array<DiscoveryCell, 4> top_cells{{
        {1,0,0,20,false},{1,0,0,20,false},
        {1,0,0,20,false},{1,0,0,20,false},
    }};
    const std::array<DiscoveryCell, 6> bottom_cells{{
        {1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},
        {1,0,0,20,false},{1,0,0,20,false},{1,0,0,20,false},
    }};

    const auto left = [&] {
        return put(regions, key(incarnation, 10), {-4, 0, 4, 4}, 1,
                   std::span<const DiscoveryCell>{left_cells}, 0x0d);
    };
    const auto top = [&] {
        return put(regions, key(incarnation, 11), {0, 0, 2, 2}, 1,
                   std::span<const DiscoveryCell>{top_cells}, 0x07);
    };
    const auto bottom = [&] {
        return put(regions, key(incarnation, 12), {0, 2, 3, 2}, 1,
                   std::span<const DiscoveryCell>{bottom_cells}, 0x07);
    };

    if (!reverse) {
        require(left() == RegionOutcome::Accepted &&
                top() == RegionOutcome::Accepted &&
                bottom() == RegionOutcome::Accepted,
                "forward partial-face registration succeeds");
    } else {
        require(bottom() == RegionOutcome::Accepted &&
                top() == RegionOutcome::Accepted &&
                left() == RegionOutcome::Accepted,
                "reverse partial-face registration succeeds");
    }

    drain(regions);
    const auto snapshot = only_region(regions);
    require(snapshot.has_value() && snapshot->area == 26 &&
            snapshot->tile_count == 3 && snapshot->complete,
            "partial face runs map to one complete exact region");
    return {snapshot->member_digest, snapshot->dependency_digest, snapshot->area,
            snapshot->tile_count, snapshot->component_count,
            snapshot->dependency_tile_count};
}

void partial_face_and_determinism() {
    const auto forward = partial_face_fixture(false);
    const auto reverse = partial_face_fixture(true);
    require(forward.member == reverse.member &&
            forward.dependency == reverse.dependency &&
            forward.area == reverse.area &&
            forward.tiles == reverse.tiles &&
            forward.components == reverse.components &&
            forward.dependencies == reverse.dependencies,
            "normalized region result is insertion-order independent");
}

void signed_endpoint_safety() {
    using Regions = SettledRegions<8, 4, 4, 32, 8, 32>;
    constexpr std::uint64_t incarnation = 9001;
    Regions regions(incarnation);
    const auto max = std::numeric_limits<std::int64_t>::max();
    const auto min = std::numeric_limits<std::int64_t>::min();

    require(regions.register_unknown(key(incarnation, 1), {max, 0, 1, 1}, 1) ==
                RegionOutcome::Accepted,
            "maximum signed endpoint is representable");
    require(regions.register_unknown(key(incarnation, 2), {min, 2, 1, 1}, 1) ==
                RegionOutcome::Accepted,
            "minimum signed endpoint is representable");
    require(regions.register_unknown(key(incarnation, 3), {max, 4, 2, 1}, 1) ==
                RegionOutcome::Invalid,
            "positive endpoint overflow is rejected");

    Regions positive_face(incarnation + 1);
    require(positive_face.register_unknown(
                key(incarnation + 1, 1), {max - 1, 0, 1, 1}, 1) ==
                RegionOutcome::Accepted &&
            positive_face.register_unknown(
                key(incarnation + 1, 2), {max, 0, 1, 1}, 1) ==
                RegionOutcome::Accepted,
            "checked positive face derivation reaches INT64_MAX");

    Regions negative_face(incarnation + 2);
    require(negative_face.register_unknown(
                key(incarnation + 2, 1), {min, 0, 1, 1}, 1) ==
                RegionOutcome::Accepted &&
            negative_face.register_unknown(
                key(incarnation + 2, 2), {min + 1, 0, 1, 1}, 1) ==
                RegionOutcome::Accepted,
            "checked negative face derivation starts at INT64_MIN");
}

void capacity_refusal() {
    using Regions = SettledRegions<2, 1, 1, 4, 4, 8>;
    constexpr std::uint64_t incarnation = 10001;
    Regions regions(incarnation);
    require(regions.register_unknown(key(incarnation, 1), {0, 0, 1, 1}, 1) ==
                RegionOutcome::Accepted &&
            regions.register_unknown(key(incarnation, 2), {2, 0, 1, 1}, 1) ==
                RegionOutcome::Accepted,
            "generic index accepts exact T");
    require(regions.register_unknown(key(incarnation, 3), {4, 0, 1, 1}, 1) ==
                RegionOutcome::Capacity &&
            regions.last_refusal() == RegionRefusal::TileCapacity,
            "generic index refuses one-past T without overflow");
}

} // namespace

int main() {
    try {
        bounded_ordered_index_contract();
        coordinator_direct_handle_contract();
        generic_rectangle_compatibility();
        partial_face_and_determinism();
        signed_endpoint_safety();
        capacity_refusal();
        std::cout << "Stage-3B bounded spatial-index tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Stage-3B bounded spatial-index test failure: "
                  << error.what() << '\n';
        return 1;
    }
}
