#pragma once

#include "cybersand/settled_discovery.hpp"
#include "cybersand/bounded_ordered_index.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <type_traits>

// Stage-3 read-only connectivity over copied, complete tile revisions.
// Cells remain the sole material owner.
namespace cybersand::soliding {

using RegionTileKey = DiscoveryTileKey;
struct RegionTileInput {
    RegionTileKey key{};
    DiscoveryBounds bounds{};
    std::uint64_t revision{};
    std::int16_t ambient_temperature{};
    DiscoverySignals signals{};
    std::span<const DiscoveryCell> cells{};
    // North/east/south/west bits. A bit asserts no untracked continuation.
    std::uint8_t sealed_edges{};
};
enum class RegionOutcome : std::uint8_t { Accepted, Unchanged, Stale, Invalid, Capacity, Refused };
enum class RegionRefusal : std::uint8_t {
    None, InvalidInput, SignalIncomplete, Occupied, NoncanonicalEmpty,
    TileCapacity, ComponentCapacity, AdjacencyCapacity, FrontierCapacity, RegionCapacity,
    UnknownBoundary, RevisionChanged, SourceFailure, GenerationExhausted,
    SpatialIndexCapacity, DependencyCapacity, MemberCapacity, ManifestCapacity
};
struct RegionComponentKey {
    std::uint8_t material{};
    std::uint16_t state_a{};
    std::uint8_t state_b{};
    std::int16_t temperature{};
    bool operator==(const RegionComponentKey&) const = default;
};
struct SettledRegionHandle {
    std::uint64_t world_incarnation{};
    std::uint32_t slot{};
    std::uint64_t generation{};
    bool operator==(const SettledRegionHandle&) const = default;
};
struct SettledRegionSnapshot {
    SettledRegionHandle handle{};
    RegionComponentKey key{};
    std::int64_t min_x{}, min_y{}, max_x{}, max_y{};
    std::uint64_t area{};
    std::uint32_t tile_count{}, component_count{}, dependency_tile_count{};
    std::uint64_t member_digest{}, dependency_digest{}, publication_serial{};
    bool complete{};
};
struct SettledRegionMetrics {
    std::uint64_t tile_scans{}, cells_inspected{}, components{}, component_high_water{}, component_refusals{};
    std::uint64_t boundary_comparisons{}, adjacency_edges{}, adjacency_refusals{};
    std::uint64_t seed_probes{}, builds_started{}, builds_completed{}, builds_restarted{};
    std::uint64_t builds_refused{}, frontier_high_water{}, frontier_refusals{};
    std::uint64_t region_high_water{}, region_refusals{}, invalidated_regions{};
    std::uint64_t facing_invalidation_fanout{}, boundary_cell_checks{}, tile_lookup_probes{};
    std::uint64_t incident_edge_visits{}, edge_retirements{};
    std::uint64_t dependency_records{}, dependency_high_water{}, dependency_refusals{};
    std::uint64_t subscriber_invalidations{}, subscriber_reuses{}, absence_subscriptions{};
    std::uint64_t cleanup_registrations{}, cleanup_units{};
    std::uint64_t reconstruction_tickets{}, reconstruction_restarts{}, reconstruction_waits{};
    std::uint64_t reconstruction_service_units{}, reconstruction_remote_units{};
    std::uint64_t reconstruction_children_staged{}, reconstruction_batches_committed{};
    std::uint64_t member_records{}, member_high_water{}, member_refusals{}, member_reclaims{};
    std::uint64_t reclamation_units{}, reclamation_high_water{}, resource_generation{};
    std::uint64_t publications{}, work_units{}, area_total{}, area_max{};
    std::uint64_t latency_total_units{}, latency_max_units{};
};

namespace region_detail {
constexpr std::uint16_t invalid_index = std::numeric_limits<std::uint16_t>::max();
constexpr std::uint8_t north = 1U, east = 2U, south = 4U, west = 8U;
inline void hash_byte(std::uint64_t& hash, std::uint8_t value) noexcept { hash ^= value; hash *= 1099511628211ULL; }
template<class T> void hash_value(std::uint64_t& hash, T value) noexcept {
    using U = std::make_unsigned_t<T>;
    const auto bits = static_cast<U>(value);
    for (std::size_t i = 0; i < sizeof(T); ++i) hash_byte(hash, static_cast<std::uint8_t>(bits >> (i * 8U)));
}
inline RegionComponentKey component_key(const DiscoveryCell& cell) noexcept {
    return {cell.material, cell.state_a, cell.state_b, cell.temperature};
}
inline bool less(const RegionComponentKey& a, const RegionComponentKey& b) noexcept {
    if (a.material != b.material) return a.material < b.material;
    if (a.state_a != b.state_a) return a.state_a < b.state_a;
    if (a.state_b != b.state_b) return a.state_b < b.state_b;
    return a.temperature < b.temperature;
}
inline bool less(const RegionTileKey& a, const RegionTileKey& b) noexcept {
    return DiscoveryTileKeyLess{}(a, b);
}
inline std::uint64_t tile_hash(const RegionTileKey& key, std::uint64_t revision) noexcept {
    std::uint64_t hash = 1469598103934665603ULL;
    // The region handle carries observer identity. Keep the dependency digest
    // comparable across repeat and workers1/4 Worlds with identical geometry.
    hash_value(hash, key.chunk_y); hash_value(hash, key.chunk_x);
    hash_value(hash, key.activity_y); hash_value(hash, key.activity_x); hash_value(hash, key.subtile_y);
    hash_value(hash, key.subtile_x); hash_value(hash, revision); return hash;
}
} // namespace region_detail

template<std::size_t TileCapacity, std::size_t MaximumTileCells = 1024,
         std::size_t ComponentsPerTile = MaximumTileCells,
         std::size_t AdjacencyCapacity = TileCapacity * 128,
         std::size_t RegionCapacity = TileCapacity,
         std::size_t FrontierCapacity = TileCapacity * ComponentsPerTile,
         std::uint64_t GenerationLimit = std::numeric_limits<std::uint64_t>::max(),
         std::uint64_t PublicationLimit = std::numeric_limits<std::uint64_t>::max()>
class SettledRegions final {
    static_assert(TileCapacity > 0 && TileCapacity <= region_detail::invalid_index);
    static_assert(MaximumTileCells > 0 && MaximumTileCells <= region_detail::invalid_index);
    static_assert(ComponentsPerTile > 0 && ComponentsPerTile <= region_detail::invalid_index);
    static_assert(AdjacencyCapacity > 0 && RegionCapacity > 0 && FrontierCapacity > 0);
public:
    explicit SettledRegions(std::uint64_t incarnation,
                            std::size_t tile_capacity = TileCapacity,
                            std::size_t adjacency_capacity = AdjacencyCapacity,
                            std::size_t frontier_capacity = FrontierCapacity,
                            std::size_t dependency_capacity = 0);
    SettledRegions(const SettledRegions&) = delete;
    SettledRegions& operator=(const SettledRegions&) = delete;

    RegionOutcome register_unknown(RegionTileKey key, DiscoveryBounds bounds,
                                   std::uint64_t revision) noexcept {
        if (unavailable()) return RegionOutcome::Refused;
        if (incarnation_ == 0 || key.world_incarnation != incarnation_ || revision == 0 ||
            !valid_bounds(bounds) ||
            static_cast<std::uint64_t>(bounds.width) * bounds.height > MaximumTileCells)
            return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
        auto slot = find_tile(key);
        if (slot == tile_capacity_) {
            if (tile_count_ == tile_capacity_) {
                block_capacity(RegionRefusal::TileCapacity);
                return remember(RegionOutcome::Capacity, RegionRefusal::TileCapacity);
            }
            if (overlaps_bounds(bounds))
                return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
            slot = first_free_tile();
            tiles_[slot] = Tile{};
            tiles_[slot].used = true;
            tiles_[slot].key = key;
            tiles_[slot].bounds = bounds;
            tiles_[slot].neighbours.fill(region_detail::invalid_index);
            tiles_[slot].boundary_runs.fill(region_detail::invalid_index);
            if (!index_tile(slot)) {
                block_capacity(RegionRefusal::SpatialIndexCapacity);
                return remember(RegionOutcome::Capacity, RegionRefusal::SpatialIndexCapacity);
            }
            ++tile_count_;
            link_faces(slot);
        } else {
            if (tiles_[slot].bounds != bounds)
                return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
            if (revision < tiles_[slot].revision) return RegionOutcome::Stale;
        }
        prepare_tile_revision_change(slot);
        auto& tile = tiles_[slot];
        tile.revision = revision;
        tile.has_payload = false;
        tile.ready = false;
        tile.component_count = 0;
        tile.face_run_count = 0;
        tile.boundary_runs.fill(region_detail::invalid_index);
        for (auto& run : tile.face_runs) run = FaceRun{};
        tile.refusal = RegionRefusal::SignalIncomplete;
        work_possible_ = true;
        return remember(RegionOutcome::Accepted, RegionRefusal::None);
    }

    RegionOutcome upsert(const RegionTileInput& input) noexcept {
        if (unavailable()) return RegionOutcome::Refused;
        if (!valid_input(input) || incarnation_ == 0 || input.key.world_incarnation != incarnation_)
            return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
        auto slot = find_tile(input.key);
        if (slot == tile_capacity_) {
            if (tile_count_ == tile_capacity_) {
                block_capacity(RegionRefusal::TileCapacity);
                return remember(RegionOutcome::Capacity, RegionRefusal::TileCapacity);
            }
            if (overlaps_bounds(input.bounds))
                return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
            slot = first_free_tile();
            tiles_[slot] = Tile{};
            tiles_[slot].used = true; tiles_[slot].key = input.key; tiles_[slot].bounds = input.bounds;
            tiles_[slot].neighbours.fill(region_detail::invalid_index);
            tiles_[slot].boundary_runs.fill(region_detail::invalid_index);
            if (!index_tile(slot)) {
                block_capacity(RegionRefusal::SpatialIndexCapacity);
                return remember(RegionOutcome::Capacity, RegionRefusal::SpatialIndexCapacity);
            }
            ++tile_count_;
            link_faces(slot);
        } else {
            const auto& old = tiles_[slot];
            if (old.bounds != input.bounds) return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
            if (input.revision < old.revision) return RegionOutcome::Stale;
            if (input.revision == old.revision && old.has_payload) {
                if (same_payload(old, input)) return RegionOutcome::Unchanged;
                fail(RegionRefusal::RevisionChanged);
                return remember(RegionOutcome::Invalid, RegionRefusal::RevisionChanged);
            }
        }
        prepare_tile_revision_change(slot);
        work_possible_ = true;
        copy_input(tiles_[slot], input);
        const auto outcome = extract(slot);
        if (outcome != RegionOutcome::Accepted) return outcome;
        if (!rebuild_adjacencies(slot)) {
            remove_adjacencies(slot);
            tiles_[slot].ready = false;
            tiles_[slot].refusal = RegionRefusal::AdjacencyCapacity;
            return remember(RegionOutcome::Capacity, RegionRefusal::AdjacencyCapacity);
        }
        return remember(RegionOutcome::Accepted, RegionRefusal::None);
    }

    RegionOutcome invalidate(RegionTileKey key, std::uint64_t next_revision) noexcept {
        if (unavailable()) return RegionOutcome::Refused;
        const auto slot = find_tile(key);
        if (slot == tile_capacity_) return RegionOutcome::Stale;
        return invalidate_known(slot, key, next_revision);
    }

    // Owner adapters that retained the append-only registration slot may avoid
    // a key scan. The key check keeps a mismatched/stale adapter fail-closed.
    RegionOutcome invalidate_known(std::size_t slot, RegionTileKey key,
                                   std::uint64_t next_revision) noexcept {
        if (unavailable()) return RegionOutcome::Refused;
        if (slot >= tile_count_ || !(tiles_[slot].key == key))
            return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
        if (next_revision <= tiles_[slot].revision) return RegionOutcome::Stale;
        prepare_tile_revision_change(slot);
        auto& tile = tiles_[slot]; tile.revision = next_revision; tile.has_payload = false;
        tile.ready = false; tile.component_count = 0; tile.face_run_count = 0;
        tile.boundary_runs.fill(region_detail::invalid_index);
        for (auto& run : tile.face_runs) run = FaceRun{};
        tile.refusal = RegionRefusal::SignalIncomplete;
        work_possible_ = true;
        return remember(RegionOutcome::Accepted, RegionRefusal::None);
    }

    // One unit is one seed probe, component visit, dependency validation, or publication.
    // Local <=32x32 extraction and face rebuilding are separately bounded and counted.
    std::size_t advance(std::size_t budget) noexcept {
        if (unavailable() || incarnation_ == 0 || budget == 0) return 0;
        std::size_t used = 0;
        while (used < budget) {
            if (!work_possible_) {
                if (cleanup_pending_count_ == 0 || !cleanup_one_dependency()) break;
                consume(used);
                continue;
            }
            if (build_.phase == Phase::Idle) begin_seek();
            if (build_.phase == Phase::Seeking) {
                if (!seek_one()) {
                    if (!build_.seed_found) {
                        reset_build();
                        work_possible_ = false;
                        continue;
                    }
                    begin_traversal(); continue;
                }
                consume(used); continue;
            }
            if (build_.phase == Phase::Traversing) {
                if (build_.frontier_count == 0) {
                    build_.phase = Phase::Validating;
                    build_.validation_dependency = subscriber_dependency_head(build_.subscriber);
                    continue;
                }
                const auto ref = pop_frontier_min();
                if (!process_component(ref)) refuse_build(build_.failure);
                consume(used); continue;
            }
            if (dependency_handle_valid(build_.validation_dependency)) {
                const auto current = build_.validation_dependency;
                build_.validation_dependency =
                    dependencies_[current.slot].next_subscriber;
                if (!dependency_current(current)) {
                    refuse_build(RegionRefusal::RevisionChanged);
                    saturating_add(metrics_.builds_restarted);
                }
                consume(used); continue;
            }
            publish_build(); consume(used);
        }
        return used;
    }

    [[nodiscard]] std::optional<SettledRegionSnapshot> snapshot(SettledRegionHandle handle) const noexcept {
        if (unavailable() || handle.world_incarnation != incarnation_ || handle.slot >= RegionCapacity) return std::nullopt;
        const auto& region = regions_[handle.slot];
        return region.valid && region.generation == handle.generation ? std::optional{region.snapshot} : std::nullopt;
    }
    [[nodiscard]] std::optional<SettledRegionSnapshot> region_at(std::size_t slot) const noexcept {
        return slot < RegionCapacity && regions_[slot].valid && !unavailable() ? std::optional{regions_[slot].snapshot} : std::nullopt;
    }
    [[nodiscard]] std::size_t tile_count() const noexcept { return tile_count_; }
    [[nodiscard]] std::size_t region_count() const noexcept {
        return published_region_count_;
    }
    [[nodiscard]] std::size_t pending_components() const noexcept {
        if (unavailable()) return 0;
        std::size_t count = cleanup_pending_count_;
        for (std::size_t slot = 0; slot < tile_count_; ++slot)
            if (tiles_[slot].ready)
                for (std::size_t i = 0; i < tiles_[slot].component_count; ++i)
                    if (!assigned(tiles_[slot].components[i]) &&
                        !tiles_[slot].components[i].deferred) ++count;
        return count;
    }
    void fail(RegionRefusal reason = RegionRefusal::SourceFailure) noexcept {
        retire_all_regions();
        cancel_build(false);
        halted_ = true;
        last_refusal_ = reason;
    }
    [[nodiscard]] bool halted() const noexcept { return halted_; }
    [[nodiscard]] bool capacity_blocked() const noexcept { return coverage_capacity_exhausted_; }
    [[nodiscard]] RegionRefusal last_refusal() const noexcept { return last_refusal_; }
    [[nodiscard]] SettledRegionMetrics metrics() const noexcept { return metrics_; }
    [[nodiscard]] std::size_t adjacency_count() const noexcept { return adjacency_count_; }
    [[nodiscard]] std::size_t tile_capacity() const noexcept { return tile_capacity_; }
    [[nodiscard]] std::size_t adjacency_capacity() const noexcept { return adjacency_capacity_; }
    [[nodiscard]] std::size_t frontier_capacity() const noexcept { return frontier_capacity_; }
    [[nodiscard]] std::size_t dependency_capacity() const noexcept { return dependency_capacity_; }
    [[nodiscard]] std::size_t dependency_count() const noexcept { return dependency_count_; }
    [[nodiscard]] std::size_t cleanup_pending() const noexcept { return cleanup_pending_count_; }
    [[nodiscard]] std::size_t key_index_capacity() const noexcept { return tile_index_.capacity(); }
    [[nodiscard]] std::size_t row_interval_capacity() const noexcept { return row_index_.capacity(); }
    [[nodiscard]] std::optional<std::size_t> containing_tile(
        DiscoveryBounds bounds) const noexcept {
        return valid_bounds(bounds) ? containing_tile_impl(bounds) : std::nullopt;
    }
    [[nodiscard]] bool overlaps_registered(DiscoveryBounds bounds) const noexcept {
        return valid_bounds(bounds) && overlaps_bounds(bounds);
    }
    [[nodiscard]] static constexpr std::size_t publication_capacity() noexcept { return RegionCapacity; }
    [[nodiscard]] static constexpr std::size_t maximum_tile_cells() noexcept { return MaximumTileCells; }
    [[nodiscard]] static constexpr std::size_t components_per_tile() noexcept { return ComponentsPerTile; }
    [[nodiscard]] static constexpr std::size_t boundary_slots_per_tile() noexcept { return 128; }
    [[nodiscard]] std::size_t storage_bytes() const noexcept {
        return sizeof(SettledRegions) +
               tile_capacity_ * sizeof(Tile) +
               adjacency_capacity_ * sizeof(Adjacency) +
               frontier_capacity_ * 3U * sizeof(ComponentRef) +
               tile_capacity_ * 2U * sizeof(std::uint64_t) +
               dependency_capacity_ * sizeof(Dependency) +
               subscriber_capacity_ * sizeof(Subscriber) +
               member_capacity_ * sizeof(PublicationMember) +
               RegionCapacity * (sizeof(SourceRegion) + sizeof(ReconstructionTicket) + sizeof(StagedChild)) +
               frontier_capacity_ * (sizeof(ReconstructionSeed) + sizeof(StagedMember)) +
               tile_capacity_ * (sizeof(bool) + sizeof(std::size_t)) +
               (tile_index_.storage_bytes() - sizeof(TileIndex)) +
               (row_index_.storage_bytes() - sizeof(RowIndex));
    }

private:
    static constexpr std::uint32_t invalid_pool_index =
        std::numeric_limits<std::uint32_t>::max();

    struct ComponentRef {
        std::uint16_t tile{}, component{};
        bool operator==(const ComponentRef&) const = default;
    };
    struct EdgeHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const EdgeHandle&) const = default;
    };
    struct DependencyHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const DependencyHandle&) const = default;
    };
    struct SubscriberHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const SubscriberHandle&) const = default;
    };
    struct MemberHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const MemberHandle&) const = default;
    };
    struct TicketHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const TicketHandle&) const = default;
    };
    struct SourceHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const SourceHandle&) const = default;
    };
    struct SeedHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const SeedHandle&) const = default;
    };
    struct StagedMemberHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const StagedMemberHandle&) const = default;
    };
    struct StagedChildHandle {
        std::uint32_t slot{invalid_pool_index};
        std::uint64_t generation{};
        bool operator==(const StagedChildHandle&) const = default;
    };
    enum class DependencyKind : std::uint8_t { TileRevision, AbsenceFaceRun };
    enum class SubscriberKind : std::uint8_t { Build, Publication, Staged, Prepared };

    struct Component {
        RegionComponentKey key{};
        std::uint64_t area{}, digest{1469598103934665603ULL};
        std::int64_t min_x{}, min_y{}, max_x{}, max_y{};
        SettledRegionHandle assigned_region{};
        EdgeHandle incident_head{};
        std::uint64_t build_generation{};
        std::uint32_t reconstruction_ticket{invalid_pool_index};
        std::uint64_t reconstruction_ticket_generation{}, reconstruction_attempt{};
        bool used{}, in_build{}, deferred{};
    };
    struct FaceRun {
        std::uint8_t direction{};
        std::uint16_t component{region_detail::invalid_index};
        std::uint8_t first{}, last{};
        std::uint64_t revision{}, absence_generation{1}, build_dependency_generation{};
        DependencyHandle absence_subscribers{};
        bool used{};
    };
    struct Tile {
        RegionTileKey key{};
        DiscoveryBounds bounds{};
        std::uint64_t revision{};
        std::int16_t ambient_temperature{};
        DiscoverySignals signals{};
        std::uint8_t sealed_edges{};
        std::array<DiscoveryCell, MaximumTileCells> cells{};
        std::array<std::uint16_t, MaximumTileCells> labels{};
        std::array<Component, ComponentsPerTile> components{};
        std::array<std::uint16_t, 128> neighbours{};
        std::array<std::uint16_t, 128> boundary_runs{};
        std::array<FaceRun, 128> face_runs{};
        DependencyHandle revision_subscribers{};
        std::size_t area{}, component_count{}, face_run_count{};
        std::uint64_t observation_generation{1}, last_change_serial{};
        RegionRefusal refusal{RegionRefusal::None};
        bool used{}, has_payload{}, ready{};
    };
    struct Adjacency {
        ComponentRef a{}, b{};
        std::uint64_t a_revision{}, b_revision{}, generation{};
        EdgeHandle next_a{}, next_b{};
        std::uint32_t next_free{invalid_pool_index};
        bool active{};
    };
    struct Dependency {
        SubscriberHandle subscriber{};
        DependencyKind kind{DependencyKind::TileRevision};
        std::uint16_t tile{region_detail::invalid_index};
        std::uint16_t face_run{region_detail::invalid_index};
        std::uint64_t target_revision{}, target_generation{}, generation{};
        DependencyHandle next_target{}, previous_target{}, next_subscriber{};
        std::uint32_t next_free{invalid_pool_index};
        bool active{};
    };
    struct Subscriber {
        SubscriberKind kind{SubscriberKind::Build};
        std::uint32_t owner_slot{};
        std::uint64_t owner_generation{}, generation{};
        DependencyHandle dependency_head{};
        SubscriberHandle next_cleanup{};
        std::uint32_t next_free{invalid_pool_index};
        bool allocated{}, active{}, cleanup_pending{};
    };
    struct PublicationMember {
        ComponentRef ref{};
        std::uint64_t tile_revision{}, generation{};
        MemberHandle next{};
        std::uint32_t next_free{invalid_pool_index};
        bool active{};
    };
    struct Region {
        SettledRegionSnapshot snapshot{};
        SubscriberHandle subscriber{};
        MemberHandle member_head{};
        std::uint64_t generation{}, batch_serial{};
        TicketHandle preparation_ticket{};
        std::size_t member_count{};
        bool valid{}, reclaim_pending{};
    };
    struct SourceRegion {
        RegionComponentKey key{};
        MemberHandle member_head{};
        SourceHandle next{};
        std::uint64_t generation{}, source_region_generation{};
        std::uint32_t source_region_slot{}, next_free{invalid_pool_index};
        std::size_t member_count{};
        bool active{};
    };
    struct ReconstructionSeed {
        ComponentRef ref{};
        SeedHandle next{};
        std::uint64_t generation{};
        std::uint32_t next_free{invalid_pool_index};
        bool active{};
    };
    struct StagedMember {
        ComponentRef ref{};
        StagedMemberHandle next{};
        std::uint64_t generation{};
        std::uint32_t next_free{invalid_pool_index};
        bool active{};
    };
    struct StagedChild {
        SettledRegionSnapshot snapshot{};
        SubscriberHandle subscriber{};
        StagedMemberHandle member_head{}, member_tail{};
        StagedChildHandle next{};
        std::uint64_t generation{};
        std::uint32_t next_free{invalid_pool_index};
        std::size_t member_count{};
        bool active{};
    };
    enum class ReconstructionPhase : std::uint8_t {
        Admitting, Building, PreflightDependencies, PreflightRegions,
        Preparing, CommitReady, Blocked, Refused
    };
    struct ReconstructionTicket {
        SourceHandle source_head{}, source_tail{}, admit_source{};
        MemberHandle admit_member{};
        SeedHandle seed_head{}, seed_tail{}, next_seed{};
        StagedChildHandle child_head{}, child_tail{}, preflight_child{}, prepare_child{};
        DependencyHandle preflight_dependency{};
        TicketHandle next_queue{};
        RegionComponentKey scan_key{};
        std::uint64_t generation{}, attempt{1}, serial{}, admission_change_serial{};
        std::uint64_t wait_generation{}, wait_resource_generation{}, batch_serial{};
        std::uint32_t next_free{invalid_pool_index}, wait_tile{invalid_pool_index};
        std::size_t source_count{}, seed_count{}, child_count{}, staged_member_count{};
        std::size_t scan_component{}, preflight_region_scan{}, preflight_free_count{};
        std::size_t prepared_child_count{}, prepare_member_index{};
        ReconstructionPhase phase{ReconstructionPhase::Admitting};
        RegionRefusal refusal{RegionRefusal::None};
        bool allocated{}, queued{}, scanning_changed_tile{}, blocker_seen{}, restart_requested{};
    };
    enum class Phase : std::uint8_t {
        Idle, Seeking, Traversing, Validating, StagingMembers,
        StagingDependencies, StagingDigest
    };
    struct Build {
        Build(std::size_t frontier_capacity, std::size_t tile_capacity)
            : frontier(std::make_unique<ComponentRef[]>(frontier_capacity)),
              seen(std::make_unique<ComponentRef[]>(frontier_capacity)),
              members(std::make_unique<ComponentRef[]>(frontier_capacity)),
              dependency_marks(std::make_unique<std::uint64_t[]>(tile_capacity)),
              revisions(std::make_unique<std::uint64_t[]>(tile_capacity)) {}
        Phase phase{Phase::Idle};
        std::size_t seek_flat{}, frontier_count{}, seen_count{}, member_count{};
        ComponentRef best{}, seed{};
        DependencyHandle validation_dependency{};
        SubscriberHandle subscriber{};
        TicketHandle reconstruction_ticket{};
        StagedChildHandle staging_child{};
        DependencyHandle staging_dependency{};
        std::uint64_t generation{};
        std::size_t staging_member_index{}, staging_dependency_count{}, staging_digest_index{};
        bool seed_found{};
        RegionRefusal failure{RegionRefusal::None};
        std::unique_ptr<ComponentRef[]> frontier, seen, members;
        std::unique_ptr<std::uint64_t[]> dependency_marks, revisions;
        std::uint64_t started_work{};
    };

    struct RowKey {
        std::int64_t y{}, x{};
        bool operator==(const RowKey&) const = default;
    };
    struct RowValue {
        std::int64_t max_x{};
        std::uint16_t tile{region_detail::invalid_index};
    };
    struct RowKeyLess {
        bool operator()(const RowKey& a, const RowKey& b) const noexcept {
            return a.y != b.y ? a.y < b.y : a.x < b.x;
        }
    };
    using TileIndex =
        BoundedOrderedIndex<RegionTileKey, std::size_t, DiscoveryTileKeyLess>;
    using RowIndex =
        BoundedOrderedIndex<RowKey, RowValue, RowKeyLess>;

    static void saturating_add(std::uint64_t& value, std::uint64_t amount = 1) noexcept {
        const auto room = std::numeric_limits<std::uint64_t>::max() - value;
        value += amount > room ? room : amount;
    }
    [[nodiscard]] bool unavailable() const noexcept { return halted_ || coverage_capacity_exhausted_; }
    void block_capacity(RegionRefusal reason) noexcept {
        retire_all_regions();
        cancel_build(false);
        coverage_capacity_exhausted_ = true;
        last_refusal_ = reason;
    }
    void consume(std::size_t& used) noexcept { ++used; saturating_add(metrics_.work_units); }
    RegionOutcome remember(RegionOutcome outcome, RegionRefusal refusal) noexcept { last_refusal_ = refusal; return outcome; }
    static bool valid_bounds(DiscoveryBounds bounds) noexcept {
        if (bounds.width == 0 || bounds.height == 0 || bounds.width > 32 || bounds.height > 32) return false;
        return bounds.x <= std::numeric_limits<std::int64_t>::max() - static_cast<std::int64_t>(bounds.width - 1U) &&
               bounds.y <= std::numeric_limits<std::int64_t>::max() - static_cast<std::int64_t>(bounds.height - 1U);
    }
    static std::int64_t max_x(const DiscoveryBounds& bounds) noexcept {
        return bounds.x + static_cast<std::int64_t>(bounds.width - 1U);
    }
    static std::int64_t max_y(const DiscoveryBounds& bounds) noexcept {
        return bounds.y + static_cast<std::int64_t>(bounds.height - 1U);
    }
    static bool overlaps(const DiscoveryBounds& a, const DiscoveryBounds& b) noexcept {
        return a.x <= max_x(b) && b.x <= max_x(a) && a.y <= max_y(b) && b.y <= max_y(a);
    }
    static bool face_neighbours(const DiscoveryBounds& a, const DiscoveryBounds& b) noexcept {
        const bool east = max_x(a) != std::numeric_limits<std::int64_t>::max() && max_x(a) + 1 == b.x;
        const bool west = max_x(b) != std::numeric_limits<std::int64_t>::max() && max_x(b) + 1 == a.x;
        const bool south = max_y(a) != std::numeric_limits<std::int64_t>::max() && max_y(a) + 1 == b.y;
        const bool north = max_y(b) != std::numeric_limits<std::int64_t>::max() && max_y(b) + 1 == a.y;
        return ((east || west) && a.y <= max_y(b) && b.y <= max_y(a)) ||
               ((south || north) && a.x <= max_x(b) && b.x <= max_x(a));
    }
    static std::size_t boundary_index(const DiscoveryBounds& bounds, std::uint8_t direction,
                                      std::int64_t x, std::int64_t y) noexcept {
        if (direction == region_detail::north) return static_cast<std::size_t>(x - bounds.x);
        if (direction == region_detail::east) return 32U + static_cast<std::size_t>(y - bounds.y);
        if (direction == region_detail::south) return 64U + static_cast<std::size_t>(x - bounds.x);
        return 96U + static_cast<std::size_t>(y - bounds.y);
    }
    [[nodiscard]] std::optional<std::size_t> row_covering(
        std::int64_t y, std::int64_t x) const noexcept {
        std::size_t probes = 0;
        const RowKey query{y, x};
        const auto at_or_after = row_index_.lower_bound(query, &probes);
        if (at_or_after.has_value() && at_or_after->key.y == y &&
            at_or_after->key.x == x) {
            saturating_add(metrics_.tile_lookup_probes, probes);
            return static_cast<std::size_t>(at_or_after->value.tile);
        }
        const auto before = row_index_.predecessor(query, &probes);
        saturating_add(metrics_.tile_lookup_probes, probes);
        if (before.has_value() && before->key.y == y &&
            before->value.max_x >= x)
            return static_cast<std::size_t>(before->value.tile);
        return std::nullopt;
    }

    [[nodiscard]] bool row_overlaps(
        std::int64_t y, std::int64_t first_x, std::int64_t last_x) const noexcept {
        std::size_t probes = 0;
        const RowKey query{y, first_x};
        const auto at_or_after = row_index_.lower_bound(query, &probes);
        if (at_or_after.has_value() && at_or_after->key.y == y &&
            at_or_after->key.x <= last_x) {
            saturating_add(metrics_.tile_lookup_probes, probes);
            return true;
        }
        const auto before = row_index_.predecessor(query, &probes);
        saturating_add(metrics_.tile_lookup_probes, probes);
        return before.has_value() && before->key.y == y &&
               before->value.max_x >= first_x;
    }

    [[nodiscard]] bool overlaps_bounds(const DiscoveryBounds& bounds) const noexcept {
        const auto last_x = max_x(bounds);
        const auto last_y = max_y(bounds);
        for (auto y = bounds.y;; ++y) {
            if (row_overlaps(y, bounds.x, last_x)) return true;
            if (y == last_y) break;
        }
        return false;
    }

    [[nodiscard]] std::optional<std::size_t> containing_tile_impl(
        const DiscoveryBounds& bounds) const noexcept {
        const auto slot = row_covering(bounds.y, bounds.x);
        if (!slot.has_value() || *slot >= tile_count_) return std::nullopt;
        const auto& outer = tiles_[*slot].bounds;
        return outer.x <= bounds.x && outer.y <= bounds.y &&
               max_x(outer) >= max_x(bounds) && max_y(outer) >= max_y(bounds)
            ? slot : std::nullopt;
    }

    bool index_tile(std::size_t slot) noexcept {
        const auto& tile = tiles_[slot];
        if (tile_index_.size() == tile_index_.capacity() ||
            row_index_.capacity() - row_index_.size() < tile.bounds.height)
            return false;
        std::size_t probes = 0;
        const auto keyed = tile_index_.insert(tile.key, slot, &probes);
        saturating_add(metrics_.tile_lookup_probes, probes);
        if (keyed != TileIndex::InsertResult::Inserted) return false;

        const auto last_x = max_x(tile.bounds);
        const auto last_y = max_y(tile.bounds);
        for (auto y = tile.bounds.y;; ++y) {
            probes = 0;
            const auto row = row_index_.insert(
                RowKey{y, tile.bounds.x},
                RowValue{last_x, static_cast<std::uint16_t>(slot)}, &probes);
            saturating_add(metrics_.tile_lookup_probes, probes);
            if (row != RowIndex::InsertResult::Inserted) return false;
            if (y == last_y) break;
        }
        return true;
    }

    void link_faces(std::size_t slot) noexcept {
        auto& tile = tiles_[slot];
        tile.neighbours.fill(region_detail::invalid_index);
        const auto& bounds = tile.bounds;
        const auto last_x = max_x(bounds);
        const auto last_y = max_y(bounds);

        const auto connect = [this, slot](std::uint8_t from_direction,
                                          std::int64_t from_x, std::int64_t from_y,
                                          std::size_t other, std::uint8_t to_direction,
                                          std::int64_t to_x, std::int64_t to_y) {
            const auto from_index =
                boundary_index(tiles_[slot].bounds, from_direction, from_x, from_y);
            const auto to_index =
                boundary_index(tiles_[other].bounds, to_direction, to_x, to_y);
            const auto old = tiles_[other].neighbours[to_index];
            if (old == region_detail::invalid_index) {
                const auto run = tiles_[other].boundary_runs[to_index];
                if (run != region_detail::invalid_index &&
                    run < tiles_[other].face_run_count)
                    invalidate_absence_run(other, run);
            }
            tiles_[slot].neighbours[from_index] = static_cast<std::uint16_t>(other);
            tiles_[other].neighbours[to_index] = static_cast<std::uint16_t>(slot);
        };

        if (bounds.y != std::numeric_limits<std::int64_t>::min()) {
            const auto outside_y = bounds.y - 1;
            for (auto x = bounds.x;; ++x) {
                if (const auto other = row_covering(outside_y, x); other.has_value())
                    connect(region_detail::north, x, bounds.y, *other,
                            region_detail::south, x, max_y(tiles_[*other].bounds));
                if (x == last_x) break;
            }
        }
        if (last_x != std::numeric_limits<std::int64_t>::max()) {
            const auto outside_x = last_x + 1;
            for (auto y = bounds.y;; ++y) {
                if (const auto other = row_covering(y, outside_x); other.has_value())
                    connect(region_detail::east, last_x, y, *other,
                            region_detail::west, tiles_[*other].bounds.x, y);
                if (y == last_y) break;
            }
        }
        if (last_y != std::numeric_limits<std::int64_t>::max()) {
            const auto outside_y = last_y + 1;
            for (auto x = bounds.x;; ++x) {
                if (const auto other = row_covering(outside_y, x); other.has_value())
                    connect(region_detail::south, x, last_y, *other,
                            region_detail::north, x, tiles_[*other].bounds.y);
                if (x == last_x) break;
            }
        }
        if (bounds.x != std::numeric_limits<std::int64_t>::min()) {
            const auto outside_x = bounds.x - 1;
            for (auto y = bounds.y;; ++y) {
                if (const auto other = row_covering(y, outside_x); other.has_value())
                    connect(region_detail::west, bounds.x, y, *other,
                            region_detail::east, max_x(tiles_[*other].bounds), y);
                if (y == last_y) break;
            }
        }
    }

    bool valid_input(const RegionTileInput& input) const noexcept {
        const auto area = static_cast<std::uint64_t>(input.bounds.width) * input.bounds.height;
        return input.revision != 0 && valid_bounds(input.bounds) && area <= MaximumTileCells &&
               input.cells.size() == area && (input.sealed_edges & 0xf0U) == 0;
    }
    std::size_t find_tile(RegionTileKey key) const noexcept {
        std::size_t probes = 0;
        const auto slot = tile_index_.find(key, &probes);
        saturating_add(metrics_.tile_lookup_probes, probes);
        return slot.has_value() ? *slot : tile_capacity_;
    }
    std::size_t first_free_tile() const noexcept {
        return tile_count_ < tile_capacity_ ? tile_count_ : tile_capacity_;
    }
    bool same_payload(const Tile& tile, const RegionTileInput& input) const noexcept {
        if (tile.ambient_temperature != input.ambient_temperature || tile.signals != input.signals ||
            tile.sealed_edges != input.sealed_edges || tile.area != input.cells.size()) return false;
        for (std::size_t i = 0; i < tile.area; ++i) if (!(tile.cells[i] == input.cells[i])) return false;
        return true;
    }
    void copy_input(Tile& tile, const RegionTileInput& input) noexcept {
        tile.bounds = input.bounds; tile.revision = input.revision;
        tile.ambient_temperature = input.ambient_temperature; tile.signals = input.signals;
        tile.sealed_edges = input.sealed_edges; tile.area = input.cells.size();
        tile.has_payload = true; tile.ready = false; tile.component_count = 0;
        tile.face_run_count = 0; tile.refusal = RegionRefusal::None;
        tile.revision_subscribers = {};
        tile.boundary_runs.fill(region_detail::invalid_index);
        for (auto& run : tile.face_runs) run = FaceRun{};
        for (std::size_t i = 0; i < tile.area; ++i) tile.cells[i] = input.cells[i];
        for (auto& label : tile.labels) label = region_detail::invalid_index;
        for (auto& component : tile.components) component = Component{};
    }
    bool canonical_hole(const Tile& tile, std::size_t index) const noexcept {
        const auto& cell = tile.cells[index];
        return cell.material == 0 && cell.state_a == 0 && cell.state_b == 0 && cell.temperature == tile.ambient_temperature;
    }
    RegionOutcome extract(std::size_t slot) noexcept {
        auto& tile = tiles_[slot];
        if (!tile.signals.inspectable()) {
            tile.refusal = tile.signals.occupied ? RegionRefusal::Occupied : RegionRefusal::SignalIncomplete;
            return remember(RegionOutcome::Refused, tile.refusal);
        }
        for (std::size_t i = 0; i < tile.area; ++i) {
            if (tile.cells[i].occupied) {
                tile.refusal = RegionRefusal::Occupied; return remember(RegionOutcome::Refused, tile.refusal);
            }
            if (tile.cells[i].material == 0 && !canonical_hole(tile, i)) {
                tile.refusal = RegionRefusal::NoncanonicalEmpty;
                return remember(RegionOutcome::Refused, tile.refusal);
            }
        }
        saturating_add(metrics_.tile_scans); saturating_add(metrics_.cells_inspected, tile.area);
        for (std::size_t index = 0; index < tile.area; ++index) {
            if (tile.labels[index] != region_detail::invalid_index || canonical_hole(tile, index)) continue;
            if (tile.component_count == ComponentsPerTile) {
                tile.refusal = RegionRefusal::ComponentCapacity; saturating_add(metrics_.component_refusals);
                return remember(RegionOutcome::Capacity, tile.refusal);
            }
            const auto ci = tile.component_count++;
            if (tile.component_count > metrics_.component_high_water)
                metrics_.component_high_water = tile.component_count;
            auto& component = tile.components[ci]; component = Component{}; component.used = true;
            component.key = region_detail::component_key(tile.cells[index]);
            std::array<std::uint16_t, MaximumTileCells> queue{};
            std::size_t head = 0, tail = 0;
            queue[tail++] = static_cast<std::uint16_t>(index);
            tile.labels[index] = static_cast<std::uint16_t>(ci);
            while (head < tail) {
                const auto current = queue[head++];
                const auto x = static_cast<std::size_t>(current) % tile.bounds.width;
                const auto y = static_cast<std::size_t>(current) / tile.bounds.width;
                const auto wx = tile.bounds.x + static_cast<std::int64_t>(x);
                const auto wy = tile.bounds.y + static_cast<std::int64_t>(y);
                ++component.area;
                region_detail::hash_value(component.digest, wx); region_detail::hash_value(component.digest, wy);
                region_detail::hash_value(component.digest, component.key.material);
                region_detail::hash_value(component.digest, component.key.state_a);
                region_detail::hash_value(component.digest, component.key.state_b);
                region_detail::hash_value(component.digest, component.key.temperature);
                if (component.area == 1) {
                    component.min_x = component.max_x = wx; component.min_y = component.max_y = wy;
                } else {
                    if (wx < component.min_x) component.min_x = wx;
                    if (wx > component.max_x) component.max_x = wx;
                    if (wy < component.min_y) component.min_y = wy;
                    if (wy > component.max_y) component.max_y = wy;
                }
                constexpr std::array<std::int8_t, 4> dx{0, 1, 0, -1}, dy{-1, 0, 1, 0};
                for (std::size_t direction = 0; direction < 4; ++direction) {
                    const auto nx = static_cast<std::int64_t>(x) + dx[direction];
                    const auto ny = static_cast<std::int64_t>(y) + dy[direction];
                    if (nx < 0 || ny < 0 || nx >= tile.bounds.width || ny >= tile.bounds.height) continue;
                    const auto neighbour = static_cast<std::size_t>(ny) * tile.bounds.width + static_cast<std::size_t>(nx);
                    if (tile.labels[neighbour] == region_detail::invalid_index &&
                        region_detail::component_key(tile.cells[neighbour]) == component.key) {
                        tile.labels[neighbour] = static_cast<std::uint16_t>(ci);
                        queue[tail++] = static_cast<std::uint16_t>(neighbour);
                    }
                }
            }
        }
        build_face_runs(slot);
        tile.ready = true; saturating_add(metrics_.components, tile.component_count);
        return remember(RegionOutcome::Accepted, RegionRefusal::None);
    }
    [[nodiscard]] bool edge_handle_valid(EdgeHandle handle) const noexcept {
        return handle.slot < adjacency_capacity_ &&
               adjacencies_[handle.slot].active &&
               adjacencies_[handle.slot].generation == handle.generation;
    }
    [[nodiscard]] EdgeHandle edge_next(
        const Adjacency& edge, ComponentRef owner) const noexcept {
        if (edge.a == owner) return edge.next_a;
        if (edge.b == owner) return edge.next_b;
        return {};
    }
    void set_edge_next(Adjacency& edge, ComponentRef owner, EdgeHandle next) noexcept {
        if (edge.a == owner) edge.next_a = next;
        else if (edge.b == owner) edge.next_b = next;
    }
    void unlink_edge_from_component(ComponentRef owner, EdgeHandle target) noexcept {
        if (owner.tile >= tile_count_ ||
            owner.component >= tiles_[owner.tile].component_count) return;
        auto& component = tiles_[owner.tile].components[owner.component];
        EdgeHandle previous{};
        auto current = component.incident_head;
        while (edge_handle_valid(current)) {
            auto& edge = adjacencies_[current.slot];
            const auto next = edge_next(edge, owner);
            if (current == target) {
                if (edge_handle_valid(previous))
                    set_edge_next(adjacencies_[previous.slot], owner, next);
                else
                    component.incident_head = next;
                return;
            }
            previous = current;
            current = next;
            saturating_add(metrics_.incident_edge_visits);
        }
    }
    void release_edge(EdgeHandle handle) noexcept {
        if (!edge_handle_valid(handle)) return;
        auto& edge = adjacencies_[handle.slot];
        edge.active = false;
        edge.a = {}; edge.b = {};
        edge.next_a = {}; edge.next_b = {};
        edge.next_free = edge_free_head_;
        edge_free_head_ = handle.slot;
        --adjacency_count_;
        saturating_add(metrics_.edge_retirements);
    }
    void remove_component_edges(ComponentRef owner) noexcept {
        if (owner.tile >= tile_count_ ||
            owner.component >= tiles_[owner.tile].component_count) return;
        auto& component = tiles_[owner.tile].components[owner.component];
        while (edge_handle_valid(component.incident_head)) {
            const auto handle = component.incident_head;
            auto& edge = adjacencies_[handle.slot];
            const auto next = edge_next(edge, owner);
            const auto other = edge.a == owner ? edge.b : edge.a;
            unlink_edge_from_component(other, handle);
            component.incident_head = next;
            release_edge(handle);
        }
        component.incident_head = {};
    }
    void remove_adjacencies(std::size_t slot) noexcept {
        for (std::size_t component = 0;
             component < tiles_[slot].component_count; ++component)
            remove_component_edges({
                static_cast<std::uint16_t>(slot),
                static_cast<std::uint16_t>(component)});
    }
    bool adjacency_exists(ComponentRef a, ComponentRef b) const noexcept {
        if (a.tile >= tile_count_ || a.component >= tiles_[a.tile].component_count)
            return false;
        auto current = tiles_[a.tile].components[a.component].incident_head;
        while (edge_handle_valid(current)) {
            const auto& edge = adjacencies_[current.slot];
            if ((edge.a == a && edge.b == b) || (edge.a == b && edge.b == a))
                return edge.a_revision == tiles_[edge.a.tile].revision &&
                       edge.b_revision == tiles_[edge.b.tile].revision;
            current = edge_next(edge, a);
        }
        return false;
    }
    [[nodiscard]] std::optional<EdgeHandle> allocate_edge() noexcept {
        while (edge_free_head_ != invalid_pool_index) {
            const auto slot = edge_free_head_;
            auto& edge = adjacencies_[slot];
            edge_free_head_ = edge.next_free;
            if (edge.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            ++edge.generation;
            edge.active = true;
            edge.next_free = invalid_pool_index;
            return EdgeHandle{slot, edge.generation};
        }
        return std::nullopt;
    }
    bool add_adjacency(ComponentRef a, ComponentRef b) noexcept {
        if (adjacency_exists(a, b)) return true;
        const auto handle = allocate_edge();
        if (!handle.has_value()) {
            saturating_add(metrics_.adjacency_refusals);
            return false;
        }
        auto& edge = adjacencies_[handle->slot];
        edge.a = a; edge.b = b;
        edge.a_revision = tiles_[a.tile].revision;
        edge.b_revision = tiles_[b.tile].revision;
        edge.next_a = tiles_[a.tile].components[a.component].incident_head;
        edge.next_b = tiles_[b.tile].components[b.component].incident_head;
        tiles_[a.tile].components[a.component].incident_head = *handle;
        tiles_[b.tile].components[b.component].incident_head = *handle;
        ++adjacency_count_;
        saturating_add(metrics_.adjacency_edges);
        return true;
    }
    bool compare_face(std::size_t left_slot, std::size_t right_slot) noexcept {
        const auto& a = tiles_[left_slot]; const auto& b = tiles_[right_slot];
        if (!a.ready || !b.ready || !face_neighbours(a.bounds, b.bounds)) return true;
        auto compare = [&](std::uint8_t adirection, std::int64_t ax, std::int64_t ay,
                           std::uint8_t bdirection, std::int64_t bx, std::int64_t by) {
            saturating_add(metrics_.boundary_comparisons);
            const auto ai = boundary_index(a.bounds, adirection, ax, ay);
            const auto bi = boundary_index(b.bounds, bdirection, bx, by);
            const auto ar = a.boundary_runs[ai], br = b.boundary_runs[bi];
            if (ar == region_detail::invalid_index || br == region_detail::invalid_index ||
                ar >= a.face_run_count || br >= b.face_run_count) return true;
            const auto& af = a.face_runs[ar]; const auto& bf = b.face_runs[br];
            if (!af.used || !bf.used || af.revision != a.revision || bf.revision != b.revision)
                return true;
            if (!(a.components[af.component].key == b.components[bf.component].key))
                return true;
            return add_adjacency(
                {static_cast<std::uint16_t>(left_slot), af.component},
                {static_cast<std::uint16_t>(right_slot), bf.component});
        };
        if (max_x(a.bounds) != std::numeric_limits<std::int64_t>::max() &&
            max_x(a.bounds) + 1 == b.bounds.x) {
            const auto lo = a.bounds.y > b.bounds.y ? a.bounds.y : b.bounds.y;
            const auto hi = max_y(a.bounds) < max_y(b.bounds) ? max_y(a.bounds) : max_y(b.bounds);
            for (auto y = lo;; ++y) {
                if (!compare(region_detail::east, max_x(a.bounds), y,
                             region_detail::west, b.bounds.x, y)) return false;
                if (y == hi) break;
            }
        } else if (max_x(b.bounds) != std::numeric_limits<std::int64_t>::max() &&
                   max_x(b.bounds) + 1 == a.bounds.x) {
            return compare_face(right_slot, left_slot);
        } else if (max_y(a.bounds) != std::numeric_limits<std::int64_t>::max() &&
                   max_y(a.bounds) + 1 == b.bounds.y) {
            const auto lo = a.bounds.x > b.bounds.x ? a.bounds.x : b.bounds.x;
            const auto hi = max_x(a.bounds) < max_x(b.bounds) ? max_x(a.bounds) : max_x(b.bounds);
            for (auto x = lo;; ++x) {
                if (!compare(region_detail::south, x, max_y(a.bounds),
                             region_detail::north, x, b.bounds.y)) return false;
                if (x == hi) break;
            }
        } else if (max_y(b.bounds) != std::numeric_limits<std::int64_t>::max() &&
                   max_y(b.bounds) + 1 == a.bounds.y) {
            return compare_face(right_slot, left_slot);
        }
        return true;
    }
    [[nodiscard]] bool slots_face_linked(
        std::size_t left, std::size_t right) const noexcept {
        if (left == right) return true;
        for (const auto neighbour : tiles_[left].neighbours)
            if (neighbour != region_detail::invalid_index &&
                static_cast<std::size_t>(neighbour) == right) return true;
        return false;
    }
    template<class Function>
    bool for_each_facing(std::size_t slot, Function&& function) noexcept {
        const auto& neighbours = tiles_[slot].neighbours;
        for (std::size_t i = 0; i < neighbours.size(); ++i) {
            const auto raw = neighbours[i];
            if (raw == region_detail::invalid_index) continue;
            bool duplicate = false;
            for (std::size_t earlier = 0; earlier < i; ++earlier)
                if (neighbours[earlier] == raw) { duplicate = true; break; }
            if (!duplicate && !function(static_cast<std::size_t>(raw))) return false;
        }
        return true;
    }
    bool rebuild_adjacencies(std::size_t slot) noexcept {
        return for_each_facing(slot, [this, slot](std::size_t other) {
            return compare_face(slot, other);
        });
    }

    bool assigned(const Component& component) const noexcept {
        const auto handle = component.assigned_region;
        return handle.world_incarnation == incarnation_ && handle.slot < RegionCapacity &&
               regions_[handle.slot].valid && regions_[handle.slot].generation == handle.generation;
    }
    bool ref_less(ComponentRef a, ComponentRef b) const noexcept {
        const auto& ac = tiles_[a.tile].components[a.component];
        const auto& bc = tiles_[b.tile].components[b.component];
        if (ac.min_y != bc.min_y) return ac.min_y < bc.min_y;
        if (ac.min_x != bc.min_x) return ac.min_x < bc.min_x;
        if (region_detail::less(ac.key, bc.key)) return true;
        if (region_detail::less(bc.key, ac.key)) return false;
        if (region_detail::less(tiles_[a.tile].key, tiles_[b.tile].key)) return true;
        if (region_detail::less(tiles_[b.tile].key, tiles_[a.tile].key)) return false;
        return a.component < b.component;
    }
    void reset_build() noexcept {
        build_.phase = Phase::Idle;
        build_.seek_flat = 0;
        build_.frontier_count = 0;
        build_.seen_count = 0;
        build_.member_count = 0;
        build_.best = {};
        build_.seed = {};
        build_.validation_dependency = {};
        build_.subscriber = {};
        build_.generation = 0;
        build_.seed_found = false;
        build_.failure = RegionRefusal::None;
        build_.started_work = 0;
    }
    void begin_seek() noexcept {
        reset_build(); build_.phase = Phase::Seeking; build_.started_work = metrics_.work_units;
    }
    bool seek_one() noexcept {
        const auto total = tile_count_ * ComponentsPerTile;
        if (build_.seek_flat == total) return false;
        const auto flat = build_.seek_flat++;
        const auto tile_index = flat / ComponentsPerTile, component_index = flat % ComponentsPerTile;
        saturating_add(metrics_.seed_probes);
        const auto& tile = tiles_[tile_index];
        if (tile.ready && component_index < tile.component_count) {
            const auto& component = tile.components[component_index];
            const ComponentRef candidate{static_cast<std::uint16_t>(tile_index), static_cast<std::uint16_t>(component_index)};
            if (!assigned(component) && !component.deferred &&
                (!build_.seed_found || ref_less(candidate, build_.best))) {
                build_.best = candidate; build_.seed_found = true;
            }
        }
        return true;
    }
    void begin_traversal() noexcept {
        build_.phase = Phase::Traversing; build_.seed = build_.best;
        if (build_generation_serial_ == std::numeric_limits<std::uint64_t>::max()) {
            refuse_build(RegionRefusal::GenerationExhausted);
            return;
        }
        build_.generation = ++build_generation_serial_;
        const auto subscriber = allocate_subscriber(
            SubscriberKind::Build, 0, build_.generation);
        if (!subscriber.has_value()) {
            refuse_build(RegionRefusal::DependencyCapacity);
            return;
        }
        build_.subscriber = *subscriber;
        if (!push(build_.seed)) { refuse_build(RegionRefusal::FrontierCapacity); return; }
        saturating_add(metrics_.builds_started);
    }
    bool push(ComponentRef ref) noexcept {
        auto& component = tiles_[ref.tile].components[ref.component];
        if (component.in_build && component.build_generation == build_.generation)
            return true;
        if (build_.frontier_count == frontier_capacity_ ||
            build_.seen_count == frontier_capacity_) {
            build_.failure = RegionRefusal::FrontierCapacity; return false;
        }
        component.in_build = true;
        component.build_generation = build_.generation;
        build_.frontier[build_.frontier_count++] = ref;
        build_.seen[build_.seen_count++] = ref;
        if (build_.frontier_count > metrics_.frontier_high_water)
            metrics_.frontier_high_water = build_.frontier_count;
        return true;
    }
    ComponentRef pop_frontier_min() noexcept {
        std::size_t best = 0;
        for (std::size_t i = 1; i < build_.frontier_count; ++i)
            if (ref_less(build_.frontier[i], build_.frontier[best])) best = i;
        const auto result = build_.frontier[best];
        build_.frontier[best] = build_.frontier[--build_.frontier_count];
        return result;
    }
    void insert_member(ComponentRef ref) noexcept {
        auto at = build_.member_count;
        while (at != 0 && ref_less(ref, build_.members[at - 1])) {
            build_.members[at] = build_.members[at - 1]; --at;
        }
        build_.members[at] = ref; ++build_.member_count;
    }
    [[nodiscard]] bool dependency_handle_valid(
        DependencyHandle handle) const noexcept {
        return handle.slot < dependency_capacity_ &&
               dependencies_[handle.slot].active &&
               dependencies_[handle.slot].generation == handle.generation;
    }
    [[nodiscard]] bool subscriber_handle_valid(
        SubscriberHandle handle) const noexcept {
        return handle.slot < subscriber_capacity_ &&
               subscribers_[handle.slot].allocated &&
               subscribers_[handle.slot].generation == handle.generation;
    }
    [[nodiscard]] DependencyHandle subscriber_dependency_head(
        SubscriberHandle handle) const noexcept {
        return subscriber_handle_valid(handle)
            ? subscribers_[handle.slot].dependency_head
            : DependencyHandle{};
    }
    [[nodiscard]] std::optional<SubscriberHandle> allocate_subscriber(
        SubscriberKind kind, std::uint32_t owner_slot,
        std::uint64_t owner_generation) noexcept {
        while (subscriber_free_head_ != invalid_pool_index) {
            const auto slot = subscriber_free_head_;
            auto& subscriber = subscribers_[slot];
            subscriber_free_head_ = subscriber.next_free;
            if (subscriber.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            ++subscriber.generation;
            if (subscriber.generation > 1)
                saturating_add(metrics_.subscriber_reuses);
            subscriber.kind = kind;
            subscriber.owner_slot = owner_slot;
            subscriber.owner_generation = owner_generation;
            subscriber.dependency_head = {};
            subscriber.next_cleanup = {};
            subscriber.next_free = invalid_pool_index;
            subscriber.allocated = true;
            subscriber.active = true;
            subscriber.cleanup_pending = false;
            ++subscriber_count_;
            return SubscriberHandle{slot, subscriber.generation};
        }
        return std::nullopt;
    }
    void enqueue_cleanup(SubscriberHandle handle) noexcept {
        if (!subscriber_handle_valid(handle)) return;
        auto& subscriber = subscribers_[handle.slot];
        if (subscriber.cleanup_pending) return;
        subscriber.cleanup_pending = true;
        subscriber.next_cleanup = {};
        if (subscriber_handle_valid(cleanup_tail_))
            subscribers_[cleanup_tail_.slot].next_cleanup = handle;
        else
            cleanup_head_ = handle;
        cleanup_tail_ = handle;
        ++cleanup_pending_count_;
        saturating_add(metrics_.cleanup_registrations);
    }
    void retire_subscriber(SubscriberHandle handle) noexcept {
        if (!subscriber_handle_valid(handle)) return;
        auto& subscriber = subscribers_[handle.slot];
        if (!subscriber.active) return;
        subscriber.active = false;
        enqueue_cleanup(handle);
    }
    [[nodiscard]] std::optional<DependencyHandle> allocate_dependency() noexcept {
        while (dependency_free_head_ != invalid_pool_index) {
            const auto slot = dependency_free_head_;
            auto& dependency = dependencies_[slot];
            dependency_free_head_ = dependency.next_free;
            if (dependency.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            ++dependency.generation;
            dependency.active = true;
            dependency.next_free = invalid_pool_index;
            ++dependency_count_;
            saturating_add(metrics_.dependency_records);
            if (dependency_count_ > metrics_.dependency_high_water)
                metrics_.dependency_high_water = dependency_count_;
            return DependencyHandle{slot, dependency.generation};
        }
        saturating_add(metrics_.dependency_refusals);
        return std::nullopt;
    }
    void release_dependency(DependencyHandle handle) noexcept {
        if (!dependency_handle_valid(handle)) return;
        auto& dependency = dependencies_[handle.slot];
        dependency.active = false;
        dependency.next_target = {};
        dependency.previous_target = {};
        dependency.next_subscriber = {};
        dependency.next_free = dependency_free_head_;
        dependency_free_head_ = handle.slot;
        --dependency_count_;
    }
    [[nodiscard]] DependencyHandle* target_head(
        Dependency& dependency) noexcept {
        if (dependency.tile >= tile_count_) return nullptr;
        auto& tile = tiles_[dependency.tile];
        if (dependency.kind == DependencyKind::TileRevision) {
            if (tile.revision != dependency.target_revision) return nullptr;
            return &tile.revision_subscribers;
        }
        if (tile.revision != dependency.target_revision ||
            dependency.face_run >= tile.face_run_count)
            return nullptr;
        auto& run = tile.face_runs[dependency.face_run];
        if (!run.used || run.revision != dependency.target_revision ||
            run.absence_generation != dependency.target_generation)
            return nullptr;
        return &run.absence_subscribers;
    }
    void unlink_dependency_target(DependencyHandle handle) noexcept {
        if (!dependency_handle_valid(handle)) return;
        auto& dependency = dependencies_[handle.slot];
        auto* head = target_head(dependency);
        if (head == nullptr) return;
        if (dependency_handle_valid(dependency.previous_target))
            dependencies_[dependency.previous_target.slot].next_target =
                dependency.next_target;
        else if (*head == handle)
            *head = dependency.next_target;
        if (dependency_handle_valid(dependency.next_target))
            dependencies_[dependency.next_target.slot].previous_target =
                dependency.previous_target;
    }
    bool add_dependency(SubscriberHandle subscriber_handle,
                        DependencyKind kind, std::size_t tile_index,
                        std::size_t face_run = region_detail::invalid_index) noexcept {
        if (!subscriber_handle_valid(subscriber_handle) ||
            !subscribers_[subscriber_handle.slot].active ||
            tile_index >= tile_count_)
            return false;
        auto& tile = tiles_[tile_index];
        std::uint64_t target_generation = 0;
        DependencyHandle* head = nullptr;
        if (kind == DependencyKind::TileRevision) {
            head = &tile.revision_subscribers;
        } else {
            if (face_run >= tile.face_run_count) return false;
            auto& run = tile.face_runs[face_run];
            target_generation = run.absence_generation;
            head = &run.absence_subscribers;
        }
        const auto handle = allocate_dependency();
        if (!handle.has_value()) return false;
        auto& dependency = dependencies_[handle->slot];
        auto& subscriber = subscribers_[subscriber_handle.slot];
        dependency.subscriber = subscriber_handle;
        dependency.kind = kind;
        dependency.tile = static_cast<std::uint16_t>(tile_index);
        dependency.face_run = static_cast<std::uint16_t>(face_run);
        dependency.target_revision = tile.revision;
        dependency.target_generation = target_generation;
        dependency.previous_target = {};
        dependency.next_target = *head;
        dependency.next_subscriber = subscriber.dependency_head;
        if (dependency_handle_valid(*head))
            dependencies_[head->slot].previous_target = *handle;
        *head = *handle;
        subscriber.dependency_head = *handle;
        return true;
    }
    bool add_tile_dependency(std::size_t tile_index) noexcept {
        if (build_.dependency_marks[tile_index] == build_.generation)
            return build_.revisions[tile_index] == tiles_[tile_index].revision;
        if (!add_dependency(build_.subscriber, DependencyKind::TileRevision, tile_index))
            return false;
        build_.dependency_marks[tile_index] = build_.generation;
        build_.revisions[tile_index] = tiles_[tile_index].revision;
        return true;
    }
    bool add_absence_dependency(std::size_t tile_index, std::size_t face_run) noexcept {
        auto& run = tiles_[tile_index].face_runs[face_run];
        if (run.build_dependency_generation == build_.generation) return true;
        if (!add_dependency(build_.subscriber, DependencyKind::AbsenceFaceRun,
                            tile_index, face_run))
            return false;
        run.build_dependency_generation = build_.generation;
        saturating_add(metrics_.absence_subscriptions);
        return true;
    }
    [[nodiscard]] bool dependency_current(DependencyHandle handle) const noexcept {
        if (!dependency_handle_valid(handle)) return false;
        const auto& dependency = dependencies_[handle.slot];
        if (dependency.tile >= tile_count_) return false;
        const auto& tile = tiles_[dependency.tile];
        if (tile.revision != dependency.target_revision || !tile.ready) return false;
        if (dependency.kind == DependencyKind::TileRevision) return true;
        if (dependency.face_run >= tile.face_run_count) return false;
        const auto& run = tile.face_runs[dependency.face_run];
        return run.used && run.revision == dependency.target_revision &&
               run.absence_generation == dependency.target_generation;
    }
    void invalidate_subscriber(SubscriberHandle handle) noexcept {
        if (!subscriber_handle_valid(handle)) return;
        const auto subscriber = subscribers_[handle.slot];
        if (!subscriber.active) return;
        saturating_add(metrics_.subscriber_invalidations);
        if (subscriber.kind == SubscriberKind::Build) {
            if (build_.phase != Phase::Idle && build_.subscriber == handle)
                cancel_build(true);
            else
                retire_subscriber(handle);
            return;
        }
        retire_handle({incarnation_, subscriber.owner_slot,
                       subscriber.owner_generation});
    }
    void invalidate_target(DependencyHandle head) noexcept {
        auto current = head;
        while (dependency_handle_valid(current)) {
            const auto next = dependencies_[current.slot].next_target;
            invalidate_subscriber(dependencies_[current.slot].subscriber);
            current = next;
            saturating_add(metrics_.facing_invalidation_fanout);
        }
    }
    void invalidate_tile_subscribers(std::size_t tile_index) noexcept {
        auto& tile = tiles_[tile_index];
        const auto head = tile.revision_subscribers;
        tile.revision_subscribers = {};
        invalidate_target(head);
    }
    void invalidate_absence_run(std::size_t tile_index, std::size_t run_index) noexcept {
        auto& run = tiles_[tile_index].face_runs[run_index];
        const auto head = run.absence_subscribers;
        run.absence_subscribers = {};
        invalidate_target(head);
        if (run.absence_generation == std::numeric_limits<std::uint64_t>::max()) {
            fail(RegionRefusal::GenerationExhausted);
            return;
        }
        ++run.absence_generation;
    }
    void release_subscriber(SubscriberHandle handle) noexcept {
        if (!subscriber_handle_valid(handle)) return;
        auto& subscriber = subscribers_[handle.slot];
        subscriber.allocated = false;
        subscriber.active = false;
        subscriber.cleanup_pending = false;
        subscriber.dependency_head = {};
        subscriber.next_cleanup = {};
        subscriber.next_free = subscriber_free_head_;
        subscriber_free_head_ = handle.slot;
        --subscriber_count_;
    }
    bool cleanup_one_dependency() noexcept {
        if (!subscriber_handle_valid(cleanup_head_)) {
            cleanup_head_ = {};
            cleanup_tail_ = {};
            cleanup_pending_count_ = 0;
            return false;
        }
        const auto handle = cleanup_head_;
        auto& subscriber = subscribers_[handle.slot];
        if (dependency_handle_valid(subscriber.dependency_head)) {
            const auto dependency = subscriber.dependency_head;
            subscriber.dependency_head =
                dependencies_[dependency.slot].next_subscriber;
            unlink_dependency_target(dependency);
            release_dependency(dependency);
            saturating_add(metrics_.cleanup_units);
        }
        if (!dependency_handle_valid(subscriber.dependency_head)) {
            cleanup_head_ = subscriber.next_cleanup;
            if (!subscriber_handle_valid(cleanup_head_)) cleanup_tail_ = {};
            subscriber.next_cleanup = {};
            subscriber.cleanup_pending = false;
            if (cleanup_pending_count_ != 0) --cleanup_pending_count_;
            release_subscriber(handle);
        }
        return true;
    }
    bool boundary_complete(ComponentRef ref) noexcept {
        const auto& tile = tiles_[ref.tile];
        for (std::size_t run_index = 0; run_index < tile.face_run_count; ++run_index) {
            const auto& run = tile.face_runs[run_index];
            if (!run.used || run.revision != tile.revision ||
                run.component != ref.component) continue;
            bool saw_absence = false;
            for (std::size_t position = run.first; position <= run.last; ++position) {
                std::int64_t x = tile.bounds.x, y = tile.bounds.y;
                if (run.direction == region_detail::north ||
                    run.direction == region_detail::south) {
                    x += static_cast<std::int64_t>(position);
                    if (run.direction == region_detail::south) y = max_y(tile.bounds);
                } else {
                    y += static_cast<std::int64_t>(position);
                    if (run.direction == region_detail::east) x = max_x(tile.bounds);
                }
                const auto neighbour = tile.neighbours[
                    boundary_index(tile.bounds, run.direction, x, y)];
                saturating_add(metrics_.boundary_cell_checks);
                if (neighbour == region_detail::invalid_index) {
                    if ((tile.sealed_edges & run.direction) == 0) return false;
                    saw_absence = true;
                    continue;
                }
                if (!add_tile_dependency(neighbour)) {
                    build_.failure = RegionRefusal::DependencyCapacity;
                    return false;
                }
                if (!tiles_[neighbour].ready) return false;
            }
            if (saw_absence && !add_absence_dependency(ref.tile, run_index)) {
                build_.failure = RegionRefusal::DependencyCapacity;
                return false;
            }
        }
        return true;
    }
    bool process_component(ComponentRef ref) noexcept {
        auto& component = tiles_[ref.tile].components[ref.component];
        if (!tiles_[ref.tile].ready || assigned(component) || component.deferred ||
            !(component.key == tiles_[build_.seed.tile].components[build_.seed.component].key)) {
            build_.failure = RegionRefusal::RevisionChanged; return false;
        }
        if (!add_tile_dependency(ref.tile)) {
            build_.failure = RegionRefusal::DependencyCapacity; return false;
        }
        if (!boundary_complete(ref)) {
            if (build_.failure == RegionRefusal::None)
                build_.failure = RegionRefusal::UnknownBoundary;
            return false;
        }
        insert_member(ref);
        auto edge_handle = component.incident_head;
        while (edge_handle_valid(edge_handle)) {
            const auto& edge = adjacencies_[edge_handle.slot];
            saturating_add(metrics_.incident_edge_visits);
            const auto neighbour = edge.a == ref ? edge.b : edge.a;
            const auto next = edge_next(edge, ref);
            const bool current =
                edge.a.tile < tile_count_ && edge.b.tile < tile_count_ &&
                edge.a_revision == tiles_[edge.a.tile].revision &&
                edge.b_revision == tiles_[edge.b.tile].revision;
            if (current && !push(neighbour)) return false;
            edge_handle = next;
        }
        return true;
    }

    void clear_build_marks() noexcept {
        for (std::size_t i = 0; i < build_.seen_count; ++i) {
            auto& component =
                tiles_[build_.seen[i].tile].components[build_.seen[i].component];
            if (component.build_generation == build_.generation) {
                component.in_build = false;
                component.build_generation = 0;
            }
        }
    }
    void refuse_build(RegionRefusal reason) noexcept {
        if (build_.seen_count == 0 && build_.seed_found &&
            build_.seed.tile < tile_count_ &&
            build_.seed.component < tiles_[build_.seed.tile].component_count) {
            auto& seed = tiles_[build_.seed.tile].components[build_.seed.component];
            if (!seed.deferred) {
                seed.deferred = true;
                ++deferred_component_count_;
            }
        }
        for (std::size_t i = 0; i < build_.seen_count; ++i) {
            auto& component = tiles_[build_.seen[i].tile].components[build_.seen[i].component];
            if (component.build_generation == build_.generation) {
                component.in_build = false;
                component.build_generation = 0;
            }
            if (!component.deferred) {
                component.deferred = true;
                ++deferred_component_count_;
            }
        }
        retire_subscriber(build_.subscriber);
        last_refusal_ = reason; saturating_add(metrics_.builds_refused);
        if (reason == RegionRefusal::FrontierCapacity) saturating_add(metrics_.frontier_refusals);
        if (reason == RegionRefusal::DependencyCapacity) saturating_add(metrics_.dependency_refusals);
        if (reason == RegionRefusal::RegionCapacity || reason == RegionRefusal::GenerationExhausted)
            saturating_add(metrics_.region_refusals);
        reset_build();
    }
    void cancel_build(bool restarted) noexcept {
        if (build_.phase == Phase::Idle) return;
        const auto subscriber = build_.subscriber;
        clear_build_marks();
        retire_subscriber(subscriber);
        reset_build();
        if (restarted) saturating_add(metrics_.builds_restarted);
    }
    void cancel_related_build(std::size_t slot) noexcept {
        if (build_.phase == Phase::Idle) return;
        if (build_.phase == Phase::Seeking) {
            cancel_build(true);
            return;
        }
        for (std::size_t component = 0;
             component < tiles_[slot].component_count; ++component) {
            const auto& current = tiles_[slot].components[component];
            if (current.in_build &&
                current.build_generation == build_.generation) {
                cancel_build(true);
                return;
            }
        }
    }
    void prepare_tile_revision_change(std::size_t slot) noexcept {
        cancel_related_build(slot);
        invalidate_tile_subscribers(slot);
        clear_deferred_for_tile_and_faces(slot);
        remove_adjacencies(slot);
        auto& tile = tiles_[slot];
        tile.revision_subscribers = {};
        for (std::size_t run = 0; run < tile.face_run_count; ++run)
            tile.face_runs[run].absence_subscribers = {};
    }

    std::optional<std::size_t> allocate_region_slot() noexcept {
        for (std::size_t i = 0; i < RegionCapacity; ++i)
            if (!regions_[i].valid && regions_[i].generation < GenerationLimit) return i;
        return std::nullopt;
    }
    void publish_build() noexcept {
        const auto slot = allocate_region_slot();
        if (!slot.has_value()) {
            bool exhausted = true;
            for (const auto& region : regions_)
                if (region.valid || region.generation < GenerationLimit) exhausted = false;
            refuse_build(exhausted ? RegionRefusal::GenerationExhausted
                                   : RegionRefusal::RegionCapacity);
            return;
        }
        if (publication_serial_ == PublicationLimit) {
            refuse_build(RegionRefusal::GenerationExhausted); return;
        }
        auto& region = regions_[*slot];
        ++region.generation;
        region.valid = true;
        ++published_region_count_;
        auto& out = region.snapshot; out = SettledRegionSnapshot{};
        out.handle = {incarnation_, static_cast<std::uint32_t>(*slot), region.generation};
        out.key = tiles_[build_.seed.tile].components[build_.seed.component].key;
        out.complete = true; out.publication_serial = ++publication_serial_;
        std::uint64_t members = 1469598103934665603ULL;
        auto* member_tiles = member_tiles_scratch_.get();
        auto* dependency_slots = dependency_slots_scratch_.get();
        std::size_t dependency_count = 0;
        for (std::size_t i = 0; i < build_.member_count; ++i) {
            const auto ref = build_.members[i];
            auto& component = tiles_[ref.tile].components[ref.component];
            component.assigned_region = out.handle;
            component.in_build = false;
            component.build_generation = 0;
            if (!member_tiles[ref.tile]) {
                member_tiles[ref.tile] = true;
                ++out.tile_count;
            }
            if (i == 0) {
                out.min_x = component.min_x; out.min_y = component.min_y;
                out.max_x = component.max_x; out.max_y = component.max_y;
            } else {
                if (component.min_x < out.min_x) out.min_x = component.min_x;
                if (component.min_y < out.min_y) out.min_y = component.min_y;
                if (component.max_x > out.max_x) out.max_x = component.max_x;
                if (component.max_y > out.max_y) out.max_y = component.max_y;
            }
            out.area += component.area; ++out.component_count;
            region_detail::hash_value(members, component.digest);
            region_detail::hash_value(members, component.min_y);
            region_detail::hash_value(members, component.min_x);
        }
        auto dependency = subscriber_dependency_head(build_.subscriber);
        while (dependency_handle_valid(dependency)) {
            const auto& record = dependencies_[dependency.slot];
            if (record.kind == DependencyKind::TileRevision) {
                const auto tile_index = static_cast<std::size_t>(record.tile);
                auto at = dependency_count;
                while (at != 0 &&
                       region_detail::less(
                           tiles_[tile_index].key,
                           tiles_[dependency_slots[at - 1]].key)) {
                    dependency_slots[at] = dependency_slots[at - 1];
                    --at;
                }
                dependency_slots[at] = tile_index;
                ++dependency_count;
            }
            dependency = record.next_subscriber;
        }
        out.dependency_tile_count = static_cast<std::uint32_t>(dependency_count);
        std::uint64_t dependencies = 1469598103934665603ULL;
        for (std::size_t i = 0; i < dependency_count; ++i) {
            const auto tile_index = dependency_slots[i];
            region_detail::hash_value(
                dependencies,
                region_detail::tile_hash(
                    tiles_[tile_index].key,
                    build_.revisions[tile_index]));
        }
        for (std::size_t i = 0; i < build_.member_count; ++i)
            member_tiles[build_.members[i].tile] = false;
        out.member_digest = members; out.dependency_digest = dependencies;
        if (!subscriber_handle_valid(build_.subscriber)) {
            region.valid = false;
            --published_region_count_;
            refuse_build(RegionRefusal::RevisionChanged);
            return;
        }
        auto& subscriber = subscribers_[build_.subscriber.slot];
        subscriber.kind = SubscriberKind::Publication;
        subscriber.owner_slot = static_cast<std::uint32_t>(*slot);
        subscriber.owner_generation = region.generation;
        region.subscriber = build_.subscriber;
        build_.subscriber = {};
        saturating_add(metrics_.builds_completed); saturating_add(metrics_.publications);
        saturating_add(metrics_.area_total, out.area);
        if (out.area > metrics_.area_max) metrics_.area_max = out.area;
        const auto latency = metrics_.work_units - build_.started_work;
        saturating_add(metrics_.latency_total_units, latency);
        if (latency > metrics_.latency_max_units) metrics_.latency_max_units = latency;
        const auto count = region_count();
        if (count > metrics_.region_high_water) metrics_.region_high_water = count;
        reset_build();
    }
    void retire_handle(SettledRegionHandle handle) noexcept {
        if (handle.world_incarnation != incarnation_ || handle.slot >= RegionCapacity) return;
        auto& region = regions_[handle.slot];
        if (region.valid && region.generation == handle.generation) {
            region.valid = false;
            --published_region_count_;
            retire_subscriber(region.subscriber);
            region.subscriber = {};
            saturating_add(metrics_.invalidated_regions);
        }
    }
    void retire_all_regions() noexcept {
        for (std::size_t slot = 0; slot < RegionCapacity; ++slot) {
            if (!regions_[slot].valid) continue;
            retire_handle({incarnation_, static_cast<std::uint32_t>(slot),
                           regions_[slot].generation});
        }
    }
    void clear_deferred_for_tile_and_faces(std::size_t slot) noexcept {
        if (deferred_component_count_ == 0) return;
        const auto clear_tile = [this](std::size_t tile_index) {
            for (std::size_t component = 0;
                 component < tiles_[tile_index].component_count; ++component) {
                auto& current = tiles_[tile_index].components[component];
                if (current.deferred) {
                    current.deferred = false;
                    --deferred_component_count_;
                }
            }
            return true;
        };
        (void)clear_tile(slot);
        (void)for_each_facing(slot, clear_tile);
    }

    static std::size_t checked_capacity(std::size_t value, std::size_t maximum,
                                        const char* message) {
        if (value == 0 || value > maximum) throw std::invalid_argument(message);
        return value;
    }
    static std::size_t checked_dependency_capacity(
        std::size_t tile_capacity, std::size_t frontier_capacity,
        std::size_t requested) {
        if (requested != 0) {
            if (requested >= invalid_pool_index)
                throw std::invalid_argument("settled region dependency capacity is unsupported");
            return requested;
        }
        if (tile_capacity > std::numeric_limits<std::size_t>::max() / 16U)
            throw std::invalid_argument("settled region dependency capacity overflows size_t");
        // Keep enough bounded headroom for one active and one logically retired
        // isolated-tile generation while cleanup is deliberately deferred.
        const auto scaled = tile_capacity * 16U;
        const auto result = scaled > frontier_capacity ? scaled : frontier_capacity;
        if (result == 0 || result >= invalid_pool_index)
            throw std::invalid_argument("settled region dependency capacity is unsupported");
        return result;
    }
    static constexpr std::size_t checked_subscriber_capacity() {
        static_assert(
            RegionCapacity <=
                (static_cast<std::size_t>(invalid_pool_index) - 2U) / 2U,
            "settled region subscriber capacity exceeds handle range");
        return RegionCapacity * 2U + 2U;
    }
    static std::size_t face_length(const Tile& tile, std::uint8_t direction) noexcept {
        return direction == region_detail::north || direction == region_detail::south
            ? tile.bounds.width : tile.bounds.height;
    }
    static std::size_t face_cell_index(
        const Tile& tile, std::uint8_t direction, std::size_t position) noexcept {
        if (direction == region_detail::north) return position;
        if (direction == region_detail::south)
            return (tile.bounds.height - 1U) * tile.bounds.width + position;
        if (direction == region_detail::west) return position * tile.bounds.width;
        return position * tile.bounds.width + tile.bounds.width - 1U;
    }
    void build_face_runs(std::size_t slot) noexcept {
        auto& tile = tiles_[slot];
        tile.face_run_count = 0;
        tile.boundary_runs.fill(region_detail::invalid_index);
        constexpr std::array<std::uint8_t, 4> directions{
            region_detail::north, region_detail::east,
            region_detail::south, region_detail::west};
        for (const auto direction : directions) {
            const auto length = face_length(tile, direction);
            std::size_t position = 0;
            while (position < length) {
                const auto cell = face_cell_index(tile, direction, position);
                const auto component = tile.labels[cell];
                if (component == region_detail::invalid_index) {
                    ++position;
                    continue;
                }
                auto last = position;
                while (last + 1U < length &&
                       tile.labels[face_cell_index(tile, direction, last + 1U)] == component)
                    ++last;
                auto& run = tile.face_runs[tile.face_run_count];
                run = FaceRun{};
                run.used = true;
                run.direction = direction;
                run.component = component;
                run.first = static_cast<std::uint8_t>(position);
                run.last = static_cast<std::uint8_t>(last);
                run.revision = tile.revision;
                run.absence_generation = 1;
                for (auto at = position; at <= last; ++at) {
                    std::int64_t x = tile.bounds.x, y = tile.bounds.y;
                    if (direction == region_detail::north ||
                        direction == region_detail::south) {
                        x += static_cast<std::int64_t>(at);
                        if (direction == region_detail::south) y = max_y(tile.bounds);
                    } else {
                        y += static_cast<std::int64_t>(at);
                        if (direction == region_detail::east) x = max_x(tile.bounds);
                    }
                    tile.boundary_runs[
                        boundary_index(tile.bounds, direction, x, y)] =
                            static_cast<std::uint16_t>(tile.face_run_count);
                }
                ++tile.face_run_count;
                position = last + 1U;
            }
        }
    }

    static std::size_t checked_row_capacity(std::size_t tile_capacity) {
        if (tile_capacity > std::numeric_limits<std::size_t>::max() / 32U)
            throw std::invalid_argument("settled region row-interval capacity overflows size_t");
        return tile_capacity * 32U;
    }

    std::uint64_t incarnation_{}, publication_serial_{}, build_generation_serial_{};
    std::size_t tile_capacity_{}, adjacency_capacity_{}, frontier_capacity_{};
    std::size_t dependency_capacity_{}, subscriber_capacity_{};
    std::unique_ptr<Tile[]> tiles_;
    std::unique_ptr<Adjacency[]> adjacencies_;
    std::unique_ptr<Dependency[]> dependencies_;
    std::unique_ptr<Subscriber[]> subscribers_;
    std::unique_ptr<PublicationMember[]> members_;
    std::array<SourceRegion, RegionCapacity> sources_{};
    std::array<ReconstructionTicket, RegionCapacity> reconstruction_tickets_{};
    std::unique_ptr<ReconstructionSeed[]> reconstruction_seeds_;
    std::unique_ptr<StagedMember[]> staged_members_;
    std::array<StagedChild, RegionCapacity> staged_children_{};
    std::unique_ptr<std::size_t[]> preflight_region_slots_;
    TileIndex tile_index_;
    RowIndex row_index_;
    std::array<Region, RegionCapacity> regions_{};
    Build build_;
    std::unique_ptr<bool[]> member_tiles_scratch_;
    std::unique_ptr<std::size_t[]> dependency_slots_scratch_;
    mutable SettledRegionMetrics metrics_{};
    RegionRefusal last_refusal_{RegionRefusal::None};
    std::uint32_t edge_free_head_{invalid_pool_index};
    std::uint32_t dependency_free_head_{invalid_pool_index};
    std::uint32_t subscriber_free_head_{invalid_pool_index};
    std::uint32_t member_free_head_{invalid_pool_index};
    std::uint32_t source_free_head_{invalid_pool_index};
    std::uint32_t ticket_free_head_{invalid_pool_index};
    std::uint32_t seed_free_head_{invalid_pool_index};
    std::uint32_t staged_member_free_head_{invalid_pool_index};
    std::uint32_t staged_child_free_head_{invalid_pool_index};
    SubscriberHandle cleanup_head_{}, cleanup_tail_{};
    TicketHandle reconstruction_queue_head_{}, reconstruction_queue_tail_{}, current_change_ticket_{};
    SeedHandle stale_seed_cleanup_head_{}, stale_seed_cleanup_tail_{};
    StagedChildHandle stale_child_cleanup_head_{}, stale_child_cleanup_tail_{};
    SourceHandle source_cleanup_head_{}, source_cleanup_tail_{};
    std::uint64_t change_serial_{}, current_change_serial_{}, reconstruction_serial_{};
    std::uint64_t resource_generation_{1}, committed_batch_serial_{}, service_round_{};
    std::size_t member_capacity_{}, member_count_{}, source_count_{}, ticket_count_{}, seed_count_{};
    std::size_t staged_member_count_{}, staged_child_count_{};
    std::size_t tile_count_{}, adjacency_count_{}, dependency_count_{}, subscriber_count_{};
    std::size_t published_region_count_{}, deferred_component_count_{}, cleanup_pending_count_{};
    bool halted_{}, coverage_capacity_exhausted_{}, work_possible_{};
};

template<std::size_t TileCapacity, std::size_t MaximumTileCells,
         std::size_t ComponentsPerTile, std::size_t AdjacencyCapacity,
         std::size_t RegionCapacity, std::size_t FrontierCapacity,
         std::uint64_t GenerationLimit, std::uint64_t PublicationLimit>
SettledRegions<TileCapacity, MaximumTileCells, ComponentsPerTile, AdjacencyCapacity,
               RegionCapacity, FrontierCapacity, GenerationLimit, PublicationLimit>::SettledRegions(
    std::uint64_t incarnation, std::size_t tile_capacity,
    std::size_t adjacency_capacity, std::size_t frontier_capacity,
    std::size_t dependency_capacity)
    : incarnation_(incarnation),
      tile_capacity_(checked_capacity(tile_capacity, TileCapacity,
          "settled region runtime tile capacity is unsupported")),
      adjacency_capacity_(checked_capacity(adjacency_capacity, AdjacencyCapacity,
          "settled region runtime adjacency capacity is unsupported")),
      frontier_capacity_(checked_capacity(frontier_capacity, FrontierCapacity,
          "settled region runtime frontier capacity is unsupported")),
      dependency_capacity_(checked_dependency_capacity(
          tile_capacity_, frontier_capacity_, dependency_capacity)),
      subscriber_capacity_(checked_subscriber_capacity()),
      member_capacity_(frontier_capacity_ > std::numeric_limits<std::size_t>::max() / 2U
          ? throw std::invalid_argument("settled reconstruction member capacity overflows size_t")
          : frontier_capacity_ * 2U),
      tiles_(std::make_unique<Tile[]>(tile_capacity_)),
      adjacencies_(std::make_unique<Adjacency[]>(adjacency_capacity_)),
      dependencies_(std::make_unique<Dependency[]>(dependency_capacity_)),
      subscribers_(std::make_unique<Subscriber[]>(subscriber_capacity_)),
      members_(std::make_unique<PublicationMember[]>(member_capacity_)),
      reconstruction_seeds_(std::make_unique<ReconstructionSeed[]>(frontier_capacity_)),
      staged_members_(std::make_unique<StagedMember[]>(frontier_capacity_)),
      preflight_region_slots_(std::make_unique<std::size_t[]>(RegionCapacity)),
      tile_index_(tile_capacity_),
      row_index_(checked_row_capacity(tile_capacity_)),
      build_(frontier_capacity_, tile_capacity_),
      member_tiles_scratch_(std::make_unique<bool[]>(tile_capacity_)),
      dependency_slots_scratch_(std::make_unique<std::size_t[]>(tile_capacity_)) {
    static_assert(AdjacencyCapacity < invalid_pool_index,
                  "settled region edge capacity exceeds handle range");
    for (std::size_t i = 0; i < adjacency_capacity_; ++i)
        adjacencies_[i].next_free =
            i + 1U < adjacency_capacity_
                ? static_cast<std::uint32_t>(i + 1U)
                : invalid_pool_index;
    edge_free_head_ = adjacency_capacity_ == 0 ? invalid_pool_index : 0U;
    for (std::size_t i = 0; i < dependency_capacity_; ++i)
        dependencies_[i].next_free =
            i + 1U < dependency_capacity_
                ? static_cast<std::uint32_t>(i + 1U)
                : invalid_pool_index;
    dependency_free_head_ = dependency_capacity_ == 0 ? invalid_pool_index : 0U;
    for (std::size_t i = 0; i < subscriber_capacity_; ++i)
        subscribers_[i].next_free =
            i + 1U < subscriber_capacity_
                ? static_cast<std::uint32_t>(i + 1U)
                : invalid_pool_index;
    subscriber_free_head_ = subscriber_capacity_ == 0 ? invalid_pool_index : 0U;
    if (member_capacity_ >= invalid_pool_index)
        throw std::invalid_argument("settled reconstruction member capacity exceeds handle range");
    for (std::size_t i = 0; i < member_capacity_; ++i)
        members_[i].next_free = i + 1U < member_capacity_
            ? static_cast<std::uint32_t>(i + 1U) : invalid_pool_index;
    member_free_head_ = member_capacity_ == 0 ? invalid_pool_index : 0U;
    for (std::size_t i = 0; i < RegionCapacity; ++i) {
        sources_[i].next_free = i + 1U < RegionCapacity
            ? static_cast<std::uint32_t>(i + 1U) : invalid_pool_index;
        reconstruction_tickets_[i].next_free = i + 1U < RegionCapacity
            ? static_cast<std::uint32_t>(i + 1U) : invalid_pool_index;
        staged_children_[i].next_free = i + 1U < RegionCapacity
            ? static_cast<std::uint32_t>(i + 1U) : invalid_pool_index;
    }
    source_free_head_ = RegionCapacity == 0 ? invalid_pool_index : 0U;
    ticket_free_head_ = RegionCapacity == 0 ? invalid_pool_index : 0U;
    staged_child_free_head_ = RegionCapacity == 0 ? invalid_pool_index : 0U;
    for (std::size_t i = 0; i < frontier_capacity_; ++i) {
        reconstruction_seeds_[i].next_free = i + 1U < frontier_capacity_
            ? static_cast<std::uint32_t>(i + 1U) : invalid_pool_index;
        staged_members_[i].next_free = i + 1U < frontier_capacity_
            ? static_cast<std::uint32_t>(i + 1U) : invalid_pool_index;
    }
    seed_free_head_ = frontier_capacity_ == 0 ? invalid_pool_index : 0U;
    staged_member_free_head_ = frontier_capacity_ == 0 ? invalid_pool_index : 0U;
}

} // namespace cybersand::soliding
