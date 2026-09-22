#include "cybersand/settled_world_discovery.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>

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

DiscoveryTileKey key(std::uint64_t incarnation, std::int64_t x) {
    return {incarnation, 0, 0, 0, 0, 0, x};
}

bool same_summary(const DiscoverySummary& a, const DiscoverySummary& b) {
    return a.handle == b.handle &&
           a.bounds == b.bounds &&
           a.classification == b.classification &&
           a.uniform == b.uniform &&
           a.revision == b.revision &&
           a.classified_tick == b.classified_tick &&
           a.dirty_tick == b.dirty_tick;
}

bool same_region(const SettledRegionSnapshot& a, const SettledRegionSnapshot& b) {
    return a.handle == b.handle &&
           a.key == b.key &&
           a.min_x == b.min_x && a.min_y == b.min_y &&
           a.max_x == b.max_x && a.max_y == b.max_y &&
           a.area == b.area &&
           a.tile_count == b.tile_count &&
           a.component_count == b.component_count &&
           a.dependency_tile_count == b.dependency_tile_count &&
           a.member_digest == b.member_digest &&
           a.dependency_digest == b.dependency_digest &&
           a.publication_serial == b.publication_serial &&
           a.complete == b.complete;
}

template<class Journal>
void drain_journal(Journal& journal, std::size_t capacity) {
    const DiscoveryCell cell{1, 0, 0, 20, false};
    std::size_t guard = 0;
    while (journal.pending() != 0) {
        const auto used = journal.advance(9, 257, [cell](auto, auto) { return cell; });
        require(used != 0 && used <= 257, "journal drain remains bounded and live");
        guard += used;
        require(guard <= capacity * 4U + 16U, "journal drain terminates");
    }
}

template<std::size_t Capacity>
void journal_stage3a_parity() {
    using Reference = SettledDiscovery<Capacity, 1>;
    using Runtime = SettledDiscovery<kMaximumWorldDiscoveryTiles, 1>;
    constexpr std::uint64_t incarnation = 1000U + Capacity;
    Reference reference(incarnation);
    Runtime runtime(incarnation, Capacity);
    std::unique_ptr<DiscoveryHandle[]> expected(new DiscoveryHandle[Capacity]);
    std::unique_ptr<DiscoveryHandle[]> actual(new DiscoveryHandle[Capacity]);

    for (std::size_t i = 0; i < Capacity; ++i) {
        const DiscoveryBounds bounds{static_cast<std::int64_t>(i), 0, 1, 1};
        const auto a = reference.register_unique_block(bounds, quiet(), 7, expected[i]);
        const auto b = runtime.register_unique_block(bounds, quiet(), 7, actual[i]);
        require(a == DiscoveryOutcome::Accepted && b == a && actual[i] == expected[i],
                "runtime journal registration matches fixed Stage-3A contract");
    }

    DiscoveryHandle expected_refused{}, actual_refused{};
    const DiscoveryBounds one_past{static_cast<std::int64_t>(Capacity), 0, 1, 1};
    const auto expected_outcome =
        reference.register_unique_block(one_past, quiet(), 7, expected_refused);
    const auto actual_outcome =
        runtime.register_unique_block(one_past, quiet(), 7, actual_refused);
    require(expected_outcome == DiscoveryOutcome::Capacity &&
            actual_outcome == expected_outcome,
            "runtime journal one-past refusal matches fixed Stage-3A contract");

    drain_journal(reference, Capacity);
    drain_journal(runtime, Capacity);
    for (std::size_t i = 0; i < Capacity; ++i) {
        const auto a = reference.snapshot(expected[i]);
        const auto b = runtime.snapshot(actual[i]);
        require(a.has_value() && b.has_value() && same_summary(*a, *b),
                "runtime journal normalized output matches fixed Stage-3A contract");
    }
    require(reference.halted() == runtime.halted() &&
            reference.pending() == runtime.pending() &&
            reference.size() == runtime.size(),
            "runtime journal final refusal/drain state matches fixed Stage-3A contract");
}

template<class Regions>
struct RegionResult {
    RegionOutcome first{};
    RegionOutcome second{};
    RegionRefusal refusal{};
    std::size_t count{};
    std::optional<SettledRegionSnapshot> snapshot;
};

template<class Regions>
RegionResult<Regions> exercise_region_pair(Regions& regions, std::uint64_t incarnation) {
    const std::array<DiscoveryCell, 1> one{DiscoveryCell{1, 0, 0, 20, false}};
    const RegionTileInput left{
        key(incarnation, 0), {0, 0, 1, 1}, 1, 20, quiet(),
        std::span<const DiscoveryCell>{one}, 0x0d};
    const RegionTileInput right{
        key(incarnation, 1), {1, 0, 1, 1}, 1, 20, quiet(),
        std::span<const DiscoveryCell>{one}, 0x07};
    RegionResult<Regions> out{};
    out.first = regions.upsert(left);
    out.second = regions.upsert(right);
    std::size_t guard = 0;
    while (true) {
        const auto used = regions.advance(257);
        guard += used;
        require(guard < 100000, "region drain terminates");
        if (used == 0) break;
    }
    out.refusal = regions.last_refusal();
    out.count = regions.region_count();
    for (std::size_t slot = 0; slot < Regions::publication_capacity(); ++slot) {
        const auto snapshot = regions.region_at(slot);
        if (snapshot.has_value()) {
            out.snapshot = snapshot;
            break;
        }
    }
    return out;
}

template<std::size_t Capacity>
void region_stage3a_parity() {
    using Reference = SettledRegions<Capacity, 1, 1, Capacity * 64U, 4096, Capacity * 32U>;
    using Runtime = SettledRegions<4096, 1, 1, 4096U * 64U, 4096, 4096U * 32U>;
    constexpr std::uint64_t incarnation = 2000U + Capacity;

    Reference reference(incarnation);
    Runtime runtime(incarnation, Capacity, Capacity * 64U, Capacity * 32U);
    const auto a = exercise_region_pair(reference, incarnation);
    const auto b = exercise_region_pair(runtime, incarnation);

    require(a.first == b.first && a.second == b.second &&
            a.refusal == b.refusal && a.count == b.count,
            "runtime region outcomes/refusal match fixed Stage-3A capacity contract");
    require(a.snapshot.has_value() == b.snapshot.has_value(),
            "runtime region publication presence matches fixed Stage-3A contract");
    require(!a.snapshot.has_value() || same_region(*a.snapshot, *b.snapshot),
            "runtime region normalized publication matches fixed Stage-3A contract");
}

template<std::size_t Capacity>
void production_capacity_boundary() {
    constexpr std::uint64_t incarnation = 3000U + Capacity;
    SettledWorldDiscoveryCoordinator coordinator(incarnation, Capacity, false);
    for (std::size_t i = 0; i < Capacity; ++i) {
        const auto outcome = coordinator.register_tile(
            key(incarnation, static_cast<std::int64_t>(i)),
            {static_cast<std::int64_t>(i), 0, 1, 1}, 20, quiet(), 1);
        require(outcome == DiscoveryOutcome::Accepted,
                "production coordinator accepts every slot through exact T");
    }
    const auto refused = coordinator.register_tile(
        key(incarnation, static_cast<std::int64_t>(Capacity)),
        {static_cast<std::int64_t>(Capacity), 0, 1, 1}, 20, quiet(), 1);
    require(refused == DiscoveryOutcome::Capacity &&
            coordinator.size() == Capacity &&
            coordinator.capacity_blocked() &&
            coordinator.halted() == DiscoveryHalt::ProducerFailure,
            "production coordinator deterministically refuses one past T");
}

template<std::size_t Capacity>
WorldDiscoveryStorageLayout layout_case() {
    SettledWorldDiscoveryCoordinator coordinator(4000U + Capacity, Capacity, true);
    const auto layout = coordinator.storage_layout();
    require(layout.effective_tile_capacity == Capacity &&
            layout.journal_capacity == Capacity &&
            layout.region_tile_capacity == Capacity,
            "T sizes journal and region tile storage exactly");
    require(layout.region_edge_capacity == Capacity * 64U,
            "edge storage is exactly 64T");
    require(layout.region_frontier_capacity == Capacity * 32U &&
            layout.region_seen_capacity == Capacity * 32U &&
            layout.region_member_capacity == Capacity * 32U,
            "frontier/seen/member storage is exactly 32T");
    require(layout.region_publication_member_capacity == Capacity * 64U &&
            layout.region_reconstruction_seed_capacity == Capacity * 32U &&
            layout.region_staged_member_capacity == Capacity * 32U,
            "reconstruction publication/seed/staging pools are exactly 64T/32T/32T");
    require(layout.region_reconstruction_ticket_capacity == 4096 &&
            layout.region_staged_child_capacity == 4096,
            "reconstruction ticket and staged-child pools remain fixed at P=4096");
    require(layout.region_dependency_capacity == Capacity * 32U &&
            layout.region_revision_capacity == Capacity,
            "dependency backing is 32T while revision backing follows T");
    require(layout.key_index_capacity == Capacity,
            "bounded canonical key index is exactly T");
    require(layout.payload_queue_capacity == Capacity &&
            layout.payload_queue_storage_bytes == Capacity * sizeof(std::size_t),
            "sparse payload service queue is fixed exactly at T with no hot growth");
    require(layout.activity_parent_capacity == Capacity &&
            layout.activity_parent_index_capacity == Capacity &&
            layout.deadline_heap_capacity == Capacity,
            "activity parent index and deadline heap are fixed exactly at T");
    require(layout.activity_parent_storage_bytes != 0 &&
            layout.activity_parent_index_storage_bytes != 0 &&
            layout.deadline_heap_storage_bytes == Capacity * sizeof(std::size_t),
            "activity/deadline structural storage is construction-bounded and accounted");
    require(layout.region_key_index_capacity == Capacity &&
            layout.region_row_interval_capacity == Capacity * 32U,
            "region key and row-interval indexes are exactly T and 32T");
    require(layout.region_tile_cell_capacity == 1024 &&
            layout.region_components_per_tile == 32 &&
            layout.region_boundary_slots_per_tile == 128,
            "C=1024 K=32 B=128 remain frozen");
    require(layout.publication_capacity == 4096,
            "publication capacity remains fixed at P=4096");
    require(layout.journal_storage_bytes != 0 &&
            layout.region_storage_bytes != 0 &&
            coordinator.storage_bytes() != 0,
            "structural byte accounting is populated");
    return layout;
}

template<std::size_t Capacity>
void allocation_failure_is_atomic() {
    testing::fail_next_settled_world_discovery_construction();
    bool threw = false;
    try {
        SettledWorldDiscoveryCoordinator failed(5000U + Capacity, Capacity, true);
        (void)failed;
    } catch (const std::bad_alloc&) {
        threw = true;
    }
    require(threw, "deterministic construction allocation failure is observable");
    SettledWorldDiscoveryCoordinator recovered(6000U + Capacity, Capacity, true);
    require(recovered.storage_layout().effective_tile_capacity == Capacity &&
            recovered.size() == 0 && recovered.pending() == 0 &&
            recovered.halted() == DiscoveryHalt::None,
            "failed construction exposes no partial storage and a clean retry succeeds");
}

template<std::size_t Capacity>
void capacity_case() {
    journal_stage3a_parity<Capacity>();
    region_stage3a_parity<Capacity>();
    production_capacity_boundary<Capacity>();
    allocation_failure_is_atomic<Capacity>();
}

} // namespace

int main() {
    try {
        const auto l64 = layout_case<64>();
        const auto l256 = layout_case<256>();
        const auto l1024 = layout_case<1024>();
        const auto l4096 = layout_case<4096>();
        require(l64.journal_storage_bytes < l256.journal_storage_bytes &&
                l256.journal_storage_bytes < l1024.journal_storage_bytes &&
                l1024.journal_storage_bytes < l4096.journal_storage_bytes,
                "journal structural storage scales with T");
        require(l64.region_storage_bytes < l256.region_storage_bytes &&
                l256.region_storage_bytes < l1024.region_storage_bytes &&
                l1024.region_storage_bytes < l4096.region_storage_bytes,
                "region structural storage scales with T despite fixed P=4096");

        capacity_case<64>();
        capacity_case<256>();
        capacity_case<1024>();
        capacity_case<4096>();

        std::cout << "Stage-3B runtime-sized storage tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Stage-3B runtime-sized storage test failure: " << error.what() << '\n';
        return 1;
    }
}
