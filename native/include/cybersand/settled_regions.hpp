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
        begin_graph_change();
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
        if (unavailable()) return RegionOutcome::Refused;
        auto& tile = tiles_[slot];
        tile.revision = revision;
        tile.has_payload = false;
        tile.ready = false;
        if (!advance_observation_generation(tile)) return RegionOutcome::Refused;
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
        begin_graph_change();
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
        if (unavailable()) return RegionOutcome::Refused;
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
        begin_graph_change();
        if (unavailable()) return RegionOutcome::Refused;
        if (slot >= tile_count_ || !(tiles_[slot].key == key))
            return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
        if (next_revision <= tiles_[slot].revision) return RegionOutcome::Stale;
        prepare_tile_revision_change(slot);
        if (unavailable()) return RegionOutcome::Refused;
        auto& tile = tiles_[slot]; tile.revision = next_revision; tile.has_payload = false;
        tile.ready = false;
        if (!advance_observation_generation(tile)) return RegionOutcome::Refused;
        tile.component_count = 0; tile.face_run_count = 0;
        tile.boundary_runs.fill(region_detail::invalid_index);
        for (auto& run : tile.face_runs) run = FaceRun{};
        tile.refusal = RegionRefusal::SignalIncomplete;
        work_possible_ = true;
        return remember(RegionOutcome::Accepted, RegionRefusal::None);
    }

    // One unit is one seed probe, exact-graph component visit, dependency action,
    // staged member/digest action, publication preparation step, or reclamation action.
    // Local <=32x32 extraction and face rebuilding remain separately bounded.
    std::size_t advance(std::size_t budget) noexcept {
        if (unavailable() || incarnation_ == 0 || budget == 0) return 0;
        std::size_t used = 0;
        while (used < budget) {
            if (ticket_count_ != 0 && build_.phase != Phase::Idle &&
                !ticket_handle_valid(build_.reconstruction_ticket))
                cancel_build(true);
            bool did_work = false;
            bool reconstruction_work = false;
            const bool cleanup_turn = (service_round_ & 7U) == 7U;
            const bool reconstruction_turn = (service_round_ & 3U) != 0U;

            if (cleanup_turn && cleanup_one_any()) {
                did_work = true;
                saturating_add(metrics_.cleanup_units);
            } else if (build_.phase != Phase::Idle) {
                reconstruction_work = ticket_handle_valid(build_.reconstruction_ticket);
                did_work = service_active_build_one();
            } else {
                if (reconstruction_turn && ticket_handle_valid(reconstruction_queue_head_)) {
                    did_work = service_reconstruction_ticket_one();
                    reconstruction_work = did_work;
                }
                const bool reconstruction_exclusive = ticket_count_ != 0;
                if (!did_work && work_possible_ && !reconstruction_exclusive) {
                    begin_seek();
                    did_work = service_active_build_one();
                }
                if (!did_work && !reconstruction_turn &&
                    ticket_handle_valid(reconstruction_queue_head_)) {
                    did_work = service_reconstruction_ticket_one();
                    reconstruction_work = did_work;
                }
                if (!did_work && cleanup_one_any()) {
                    did_work = true;
                    saturating_add(metrics_.cleanup_units);
                }
            }

            if (!did_work) break;
            consume(used);
            ++service_round_;
            if (reconstruction_work)
                saturating_add(metrics_.reconstruction_service_units);
            else if (ticket_count_ != 0 && !cleanup_turn)
                saturating_add(metrics_.reconstruction_remote_units);
        }
        return used;
    }

    [[nodiscard]] std::optional<SettledRegionSnapshot> snapshot(SettledRegionHandle handle) const noexcept {
        if (unavailable() || handle.world_incarnation != incarnation_ || handle.slot >= RegionCapacity) return std::nullopt;
        const auto& region = regions_[handle.slot];
        return region_visible(region) && region.generation == handle.generation
            ? std::optional{region.snapshot} : std::nullopt;
    }
    [[nodiscard]] std::optional<SettledRegionSnapshot> region_at(std::size_t slot) const noexcept {
        return slot < RegionCapacity && region_visible(regions_[slot]) && !unavailable()
            ? std::optional{regions_[slot].snapshot} : std::nullopt;
    }
    [[nodiscard]] std::size_t tile_count() const noexcept { return tile_count_; }
    [[nodiscard]] std::size_t region_count() const noexcept {
        return published_region_count_;
    }
    [[nodiscard]] std::size_t pending_components() const noexcept {
        if (unavailable()) return 0;
        std::size_t count = cleanup_pending_count_ + ticket_count_ +
                            region_reclaim_count_;
        if (source_handle_valid(source_cleanup_head_)) ++count;
        if (seed_handle_valid(stale_seed_cleanup_head_)) ++count;
        if (staged_child_handle_valid(stale_child_cleanup_head_)) ++count;
        for (std::size_t slot = 0; slot < tile_count_; ++slot)
            if (tiles_[slot].ready)
                for (std::size_t i = 0; i < tiles_[slot].component_count; ++i)
                    if (!assigned(tiles_[slot].components[i]) &&
                        !tiles_[slot].components[i].deferred) ++count;
        return count;
    }
    void fail(RegionRefusal reason = RegionRefusal::SourceFailure) noexcept {
        current_change_serial_ = 0;
        current_change_ticket_ = {};
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
    [[nodiscard]] std::size_t publication_member_capacity() const noexcept { return member_capacity_; }
    [[nodiscard]] std::size_t reconstruction_ticket_capacity() const noexcept { return RegionCapacity; }
    [[nodiscard]] std::size_t reconstruction_seed_capacity() const noexcept { return frontier_capacity_; }
    [[nodiscard]] std::size_t staged_member_capacity() const noexcept { return frontier_capacity_; }
    [[nodiscard]] std::size_t staged_child_capacity() const noexcept { return RegionCapacity; }
    [[nodiscard]] std::size_t cleanup_pending() const noexcept {
        return cleanup_pending_count_ + region_reclaim_count_ +
               (source_handle_valid(source_cleanup_head_) ? 1U : 0U) +
               (seed_handle_valid(stale_seed_cleanup_head_) ? 1U : 0U) +
               (staged_child_handle_valid(stale_child_cleanup_head_) ? 1U : 0U);
    }
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
        std::uint64_t observation_generation{1}, last_change_serial{}, staging_mark_generation{};
        std::uint64_t dependency_digest_mark_generation{};
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
        bool valid{}, reclaim_pending{}, reclaim_enqueued{}, on_free_list{},
             generation_exhausted_recorded{};
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
    enum class StagedChildPhase : std::uint8_t {
        Traversing, GatherMembers, SortMembers, FoldMembers,
        GatherDependencies, SortDependencies, FoldDependencies, Complete
    };
    struct StagedChild {
        SettledRegionSnapshot snapshot{};
        SubscriberHandle subscriber{};
        StagedMemberHandle member_head{}, member_tail{}, digest_member{};
        SeedHandle frontier_head{}, frontier_tail{};
        DependencyHandle digest_dependency{};
        StagedChildHandle next{};
        std::uint64_t generation{}, build_generation{}, digest_generation{};
        std::uint32_t next_free{invalid_pool_index}, target_region_slot{invalid_pool_index};
        std::size_t member_count{}, frontier_count{};
        std::size_t scratch_member_count{}, sort_i{}, sort_j{}, sort_best{}, fold_i{};
        std::size_t scratch_dependency_count{}, dep_sort_i{}, dep_sort_j{}, dep_sort_best{}, dep_fold_i{};
        StagedChildPhase phase{StagedChildPhase::Traversing};
        bool active{};
    };
    enum class ReconstructionPhase : std::uint8_t {
        Admitting, Building, PreflightDependencies, PreflightRegions,
        Preparing, CommitReady, RestartCleanup, Blocked, Refused
    };
    enum class ReconstructionResource : std::uint8_t {
        None, Region, Member, Frontier, Dependency, Manifest
    };
    struct ReconstructionTicket {
        SourceHandle source_head{}, source_tail{}, admit_source{};
        MemberHandle admit_member{};
        SeedHandle seed_head{}, seed_tail{}, next_seed{};
        StagedChildHandle child_head{}, child_tail{}, preflight_child{}, prepare_child{}, active_child{}, restart_child{};
        StagedMemberHandle prepare_member{};
        DependencyHandle preflight_dependency{};
        TicketHandle next_queue{};
        RegionComponentKey scan_key{};
        std::uint64_t generation{}, attempt{1}, serial{}, admission_change_serial{}, scan_generation{};
        std::uint64_t wait_generation{}, wait_resource_generation{}, batch_serial{};
        std::uint64_t publication_base_serial{}, publication_end_serial{};
        std::uint64_t staged_area_total{}, staged_area_max{}, started_work{};
        std::uint32_t next_free{invalid_pool_index}, wait_tile{invalid_pool_index};
        std::size_t source_count{}, seed_count{}, child_count{}, staged_member_count{};
        std::size_t scan_component{}, scan_tile{}, preflight_region_scan{}, preflight_free_count{};
        std::size_t prepared_child_count{}, prepare_member_index{}, restart_cleanup_index{};
        ReconstructionPhase phase{ReconstructionPhase::Admitting};
        ReconstructionResource wait_resource{ReconstructionResource::None};
        RegionRefusal refusal{RegionRefusal::None};
        bool allocated{}, queued{}, scanning_changed_tile{}, blocker_seen{}, restart_requested{},
             publication_reserved{};
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
        SettledRegionSnapshot staging_snapshot{};
        std::uint64_t generation{}, staging_member_digest{1469598103934665603ULL};
        std::uint64_t staging_dependency_digest{1469598103934665603ULL};
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
    [[nodiscard]] std::uint64_t resource_generation(
        ReconstructionResource resource) const noexcept {
        switch (resource) {
        case ReconstructionResource::Region: return region_resource_generation_;
        case ReconstructionResource::Member: return member_resource_generation_;
        case ReconstructionResource::Frontier: return frontier_resource_generation_;
        case ReconstructionResource::Dependency: return dependency_resource_generation_;
        case ReconstructionResource::Manifest: return manifest_resource_generation_;
        case ReconstructionResource::None: return resource_generation_;
        }
        return resource_generation_;
    }
    void bump_resource_generation(
        ReconstructionResource resource = ReconstructionResource::None) noexcept {
        auto bump = [](std::uint64_t& value) noexcept {
            if (value != std::numeric_limits<std::uint64_t>::max()) ++value;
        };
        bump(resource_generation_);
        switch (resource) {
        case ReconstructionResource::Region: bump(region_resource_generation_); break;
        case ReconstructionResource::Member: bump(member_resource_generation_); break;
        case ReconstructionResource::Frontier: bump(frontier_resource_generation_); break;
        case ReconstructionResource::Dependency: bump(dependency_resource_generation_); break;
        case ReconstructionResource::Manifest: bump(manifest_resource_generation_); break;
        case ReconstructionResource::None: break;
        }
        metrics_.resource_generation = resource_generation_;
    }
    [[nodiscard]] static ReconstructionResource resource_for_refusal(
        RegionRefusal reason) noexcept {
        switch (reason) {
        case RegionRefusal::RegionCapacity:
            return ReconstructionResource::Region;
        case RegionRefusal::MemberCapacity:
            return ReconstructionResource::Member;
        case RegionRefusal::FrontierCapacity:
            return ReconstructionResource::Frontier;
        case RegionRefusal::DependencyCapacity:
            return ReconstructionResource::Dependency;
        case RegionRefusal::ManifestCapacity:
        case RegionRefusal::RevisionChanged:
            return ReconstructionResource::Manifest;
        default:
            return ReconstructionResource::None;
        }
    }
    void begin_graph_change() noexcept {
        if (change_serial_ == std::numeric_limits<std::uint64_t>::max()) {
            fail(RegionRefusal::GenerationExhausted);
            return;
        }
        current_change_serial_ = ++change_serial_;
        current_change_ticket_ = {};
    }
    bool advance_observation_generation(Tile& tile) noexcept {
        if (tile.observation_generation == std::numeric_limits<std::uint64_t>::max()) {
            fail(RegionRefusal::GenerationExhausted);
            return false;
        }
        ++tile.observation_generation;
        return true;
    }
    [[nodiscard]] bool region_visible(const Region& region) const noexcept {
        return region.valid &&
               (region.batch_serial == 0 ||
                !ticket_handle_valid(region.preparation_ticket));
    }
    void block_capacity(RegionRefusal reason) noexcept {
        current_change_serial_ = 0;
        current_change_ticket_ = {};
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
        if (!advance_observation_generation(tile)) return;
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
        tile.ready = true;
        if (!advance_observation_generation(tile)) return RegionOutcome::Refused;
        saturating_add(metrics_.components, tile.component_count);
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
    bool ticket_handle_valid(TicketHandle handle) const noexcept {
        return handle.slot < RegionCapacity &&
               reconstruction_tickets_[handle.slot].allocated &&
               reconstruction_tickets_[handle.slot].generation == handle.generation;
    }
    bool component_reserved(const Component& component) const noexcept {
        if (component.reconstruction_ticket >= RegionCapacity) return false;
        const auto handle = TicketHandle{
            component.reconstruction_ticket,
            component.reconstruction_ticket_generation};
        if (!ticket_handle_valid(handle)) return false;
        return reconstruction_tickets_[handle.slot].attempt == component.reconstruction_attempt;
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
        build_.reconstruction_ticket = {};
        build_.staging_child = {};
        build_.staging_dependency = {};
        build_.staging_snapshot = {};
        build_.generation = 0;
        build_.staging_member_digest = 1469598103934665603ULL;
        build_.staging_dependency_digest = 1469598103934665603ULL;
        build_.staging_member_index = 0;
        build_.staging_dependency_count = 0;
        build_.staging_digest_index = 0;
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
            if (!assigned(component) && !component.deferred && !component_reserved(component) &&
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
        if (ticket_handle_valid(build_.reconstruction_ticket)) {
            const auto handle = build_.reconstruction_ticket;
            if (component_reserved(component) &&
                !seed_belongs_to_ticket(component, handle)) {
                const auto other = TicketHandle{
                    component.reconstruction_ticket,
                    component.reconstruction_ticket_generation};
                if (ticket_handle_valid(other) &&
                    reconstruction_tickets_[other.slot].serial <
                        reconstruction_tickets_[handle.slot].serial) {
                    build_.failure = RegionRefusal::RevisionChanged;
                    return false;
                }
            }
            component.reconstruction_ticket = handle.slot;
            component.reconstruction_ticket_generation = handle.generation;
            component.reconstruction_attempt = reconstruction_tickets_[handle.slot].attempt;
        }
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
        bump_resource_generation(ReconstructionResource::Dependency);
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
            else {
                request_ticket_restart(
                    TicketHandle{subscriber.owner_slot, subscriber.owner_generation});
                retire_subscriber(handle);
            }
            return;
        }
        if (subscriber.kind == SubscriberKind::Staged) {
            request_ticket_restart(
                TicketHandle{subscriber.owner_slot, subscriber.owner_generation});
            retire_subscriber(handle);
            return;
        }
        if (subscriber.kind == SubscriberKind::Prepared) {
            if (subscriber.owner_slot < RegionCapacity) {
                const auto ticket = regions_[subscriber.owner_slot].preparation_ticket;
                request_ticket_restart(ticket);
            }
            retire_handle({incarnation_, subscriber.owner_slot,
                           subscriber.owner_generation});
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
        const auto kind = subscriber.kind;
        const auto owner_slot = subscriber.owner_slot;
        const auto owner_generation = subscriber.owner_generation;
        subscriber.allocated = false;
        subscriber.active = false;
        subscriber.cleanup_pending = false;
        subscriber.dependency_head = {};
        subscriber.next_cleanup = {};
        subscriber.next_free = subscriber_free_head_;
        subscriber_free_head_ = handle.slot;
        --subscriber_count_;
        bump_resource_generation(ReconstructionResource::Dependency);
        if ((kind == SubscriberKind::Publication || kind == SubscriberKind::Prepared) &&
            owner_slot < RegionCapacity) {
            auto& region = regions_[owner_slot];
            if (region.generation == owner_generation && region.reclaim_pending)
                region.subscriber = {};
        }
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
        if (!tiles_[ref.tile].ready || assigned(component) ||
            (component.deferred && !ticket_handle_valid(build_.reconstruction_ticket)) ||
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


    void begin_staging_reconstruction_child() noexcept {
        const auto ticket_handle = build_.reconstruction_ticket;
        if (!ticket_handle_valid(ticket_handle)) {
            refuse_build(RegionRefusal::RevisionChanged);
            return;
        }
        const auto child = allocate_staged_child();
        if (!child.has_value()) {
            refuse_build(RegionRefusal::RegionCapacity);
            return;
        }
        build_.staging_child = *child;
        auto& staged = staged_children_[child->slot];
        staged.subscriber = build_.subscriber;
        build_.staging_snapshot = {};
        build_.staging_snapshot.key =
            tiles_[build_.seed.tile].components[build_.seed.component].key;
        build_.staging_snapshot.complete = true;
        build_.staging_member_digest = 1469598103934665603ULL;
        build_.staging_dependency_digest = 1469598103934665603ULL;
        build_.staging_member_index = 0;
        build_.staging_dependency_count = 0;
        build_.staging_digest_index = 0;
        build_.phase = Phase::StagingMembers;
    }
    bool stage_reconstruction_member_one() noexcept {
        if (!staged_child_handle_valid(build_.staging_child) ||
            !ticket_handle_valid(build_.reconstruction_ticket)) {
            refuse_build(RegionRefusal::RevisionChanged);
            return true;
        }
        if (build_.staging_member_index >= build_.member_count) {
            build_.phase = Phase::StagingDependencies;
            build_.staging_dependency = subscriber_dependency_head(build_.subscriber);
            return false;
        }
        const auto ref = build_.members[build_.staging_member_index++];
        const auto staged_member = allocate_staged_member(ref);
        if (!staged_member.has_value()) {
            refuse_build(RegionRefusal::MemberCapacity);
            return true;
        }
        auto& child = staged_children_[build_.staging_child.slot];
        if (staged_member_handle_valid(child.member_tail))
            staged_members_[child.member_tail.slot].next = *staged_member;
        else
            child.member_head = *staged_member;
        child.member_tail = *staged_member;
        ++child.member_count;
        auto& component = tiles_[ref.tile].components[ref.component];
        const auto ticket_handle = build_.reconstruction_ticket;
        component.reconstruction_ticket = ticket_handle.slot;
        component.reconstruction_ticket_generation = ticket_handle.generation;
        component.reconstruction_attempt =
            reconstruction_tickets_[ticket_handle.slot].attempt;
        component.in_build = false;
        component.build_generation = 0;
        auto& out = build_.staging_snapshot;
        auto& tile = tiles_[ref.tile];
        if (tile.staging_mark_generation != build_.generation) {
            tile.staging_mark_generation = build_.generation;
            ++out.tile_count;
        }
        if (out.component_count == 0) {
            out.min_x = component.min_x; out.min_y = component.min_y;
            out.max_x = component.max_x; out.max_y = component.max_y;
        } else {
            if (component.min_x < out.min_x) out.min_x = component.min_x;
            if (component.min_y < out.min_y) out.min_y = component.min_y;
            if (component.max_x > out.max_x) out.max_x = component.max_x;
            if (component.max_y > out.max_y) out.max_y = component.max_y;
        }
        out.area += component.area;
        ++out.component_count;
        region_detail::hash_value(build_.staging_member_digest, component.digest);
        region_detail::hash_value(build_.staging_member_digest, component.min_y);
        region_detail::hash_value(build_.staging_member_digest, component.min_x);
        return true;
    }
    bool stage_reconstruction_dependency_one() noexcept {
        if (!ticket_handle_valid(build_.reconstruction_ticket)) {
            refuse_build(RegionRefusal::RevisionChanged);
            return true;
        }
        if (dependency_handle_valid(build_.staging_dependency)) {
            const auto current = build_.staging_dependency;
            build_.staging_dependency = dependencies_[current.slot].next_subscriber;
            if (!dependency_current(current)) {
                request_ticket_restart(build_.reconstruction_ticket);
                return true;
            }
            const auto& record = dependencies_[current.slot];
            if (record.kind == DependencyKind::TileRevision) {
                const auto tile_index = static_cast<std::size_t>(record.tile);
                auto at = build_.staging_dependency_count;
                while (at != 0 &&
                       region_detail::less(
                           tiles_[tile_index].key,
                           tiles_[dependency_slots_scratch_[at - 1]].key)) {
                    dependency_slots_scratch_[at] =
                        dependency_slots_scratch_[at - 1];
                    --at;
                }
                dependency_slots_scratch_[at] = tile_index;
                ++build_.staging_dependency_count;
            }
            return true;
        }
        build_.staging_snapshot.dependency_tile_count =
            static_cast<std::uint32_t>(build_.staging_dependency_count);
        build_.phase = Phase::StagingDigest;
        build_.staging_digest_index = 0;
        return false;
    }
    void finish_staged_reconstruction_child() noexcept {
        const auto ticket_handle = build_.reconstruction_ticket;
        if (!ticket_handle_valid(ticket_handle) ||
            !staged_child_handle_valid(build_.staging_child)) {
            refuse_build(RegionRefusal::RevisionChanged);
            return;
        }
        auto& ticket = reconstruction_tickets_[ticket_handle.slot];
        auto& child = staged_children_[build_.staging_child.slot];
        build_.staging_snapshot.member_digest = build_.staging_member_digest;
        build_.staging_snapshot.dependency_digest = build_.staging_dependency_digest;
        child.snapshot = build_.staging_snapshot;
        if (subscriber_handle_valid(build_.subscriber)) {
            auto& subscriber = subscribers_[build_.subscriber.slot];
            subscriber.kind = SubscriberKind::Staged;
            subscriber.owner_slot = ticket_handle.slot;
            subscriber.owner_generation = ticket_handle.generation;
        }
        child.subscriber = build_.subscriber;
        if (staged_child_handle_valid(ticket.child_tail))
            staged_children_[ticket.child_tail.slot].next = build_.staging_child;
        else
            ticket.child_head = build_.staging_child;
        ticket.child_tail = build_.staging_child;
        ++ticket.child_count;
        ticket.staged_member_count += child.member_count;
        saturating_add(ticket.staged_area_total, child.snapshot.area);
        if (child.snapshot.area > ticket.staged_area_max)
            ticket.staged_area_max = child.snapshot.area;
        saturating_add(metrics_.reconstruction_children_staged);
        build_.subscriber = {};
        reset_build();
        if (ticket_handle_valid(reconstruction_queue_head_) &&
            reconstruction_queue_head_ == ticket_handle)
            rotate_reconstruction_head();
    }
    bool stage_reconstruction_digest_one() noexcept {
        if (build_.staging_digest_index < build_.staging_dependency_count) {
            const auto tile_index =
                dependency_slots_scratch_[build_.staging_digest_index++];
            region_detail::hash_value(
                build_.staging_dependency_digest,
                region_detail::tile_hash(
                    tiles_[tile_index].key, build_.revisions[tile_index]));
            return true;
        }
        finish_staged_reconstruction_child();
        return true;
    }
    bool service_active_build_one() noexcept {
        while (build_.phase != Phase::Idle) {
            if (ticket_handle_valid(build_.reconstruction_ticket) &&
                reconstruction_tickets_[build_.reconstruction_ticket.slot].restart_requested) {
                begin_ticket_restart(build_.reconstruction_ticket);
                return true;
            }
            if (build_.phase == Phase::Seeking) {
                if (!seek_one()) {
                    if (!build_.seed_found) {
                        reset_build();
                        work_possible_ = false;
                        return false;
                    }
                    begin_traversal();
                    continue;
                }
                return true;
            }
            if (build_.phase == Phase::Traversing) {
                if (build_.frontier_count == 0) {
                    build_.phase = Phase::Validating;
                    build_.validation_dependency =
                        subscriber_dependency_head(build_.subscriber);
                    continue;
                }
                const auto ref = pop_frontier_min();
                if (!process_component(ref)) refuse_build(build_.failure);
                return true;
            }
            if (build_.phase == Phase::Validating) {
                if (dependency_handle_valid(build_.validation_dependency)) {
                    const auto current = build_.validation_dependency;
                    build_.validation_dependency =
                        dependencies_[current.slot].next_subscriber;
                    if (!dependency_current(current)) {
                        if (ticket_handle_valid(build_.reconstruction_ticket))
                            request_ticket_restart(build_.reconstruction_ticket);
                        else {
                            refuse_build(RegionRefusal::RevisionChanged);
                            saturating_add(metrics_.builds_restarted);
                        }
                    }
                    return true;
                }
                publish_build();
                return true;
            }
            if (build_.phase == Phase::StagingMembers) {
                if (stage_reconstruction_member_one()) return true;
                continue;
            }
            if (build_.phase == Phase::StagingDependencies) {
                if (stage_reconstruction_dependency_one()) return true;
                continue;
            }
            if (build_.phase == Phase::StagingDigest)
                return stage_reconstruction_digest_one();
        }
        return false;
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
        if (ticket_handle_valid(build_.reconstruction_ticket)) {
            const auto ticket_handle = build_.reconstruction_ticket;
            auto& ticket = reconstruction_tickets_[ticket_handle.slot];
            ticket.phase = ReconstructionPhase::Refused;
            ticket.refusal = reason;
            last_refusal_ = reason;
            if (staged_child_handle_valid(build_.staging_child)) {
                auto& child = staged_children_[build_.staging_child.slot];
                append_child_cleanup(build_.staging_child, build_.staging_child);
                build_.staging_child = {};
                child.next = {};
            }
            retire_subscriber(build_.subscriber);
            reset_build();
            saturating_add(metrics_.builds_refused);
            if (reason == RegionRefusal::FrontierCapacity)
                saturating_add(metrics_.frontier_refusals);
            if (reason == RegionRefusal::DependencyCapacity)
                saturating_add(metrics_.dependency_refusals);
            if (reason == RegionRefusal::MemberCapacity)
                saturating_add(metrics_.member_refusals);
            if (reason == RegionRefusal::RegionCapacity ||
                reason == RegionRefusal::GenerationExhausted)
                saturating_add(metrics_.region_refusals);
            return;
        }
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
        const auto ticket = build_.reconstruction_ticket;
        if (ticket_handle_valid(ticket)) {
            if (restarted) request_ticket_restart(ticket);
        } else {
            clear_build_marks();
        }
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
        tiles_[slot].last_change_serial = current_change_serial_;
        for (std::size_t component = 0;
             component < tiles_[slot].component_count; ++component) {
            const auto& current = tiles_[slot].components[component];
            if (!component_reserved(current)) continue;
            request_ticket_restart(TicketHandle{
                current.reconstruction_ticket,
                current.reconstruction_ticket_generation});
        }
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
        while (region_free_count_ != 0) {
            const auto slot = static_cast<std::size_t>(
                region_free_stack_[--region_free_count_]);
            auto& region = regions_[slot];
            region.on_free_list = false;
            if (!region.valid && !region.reclaim_pending &&
                !member_handle_valid(region.member_head) &&
                region.generation < GenerationLimit)
                return slot;
        }
        return std::nullopt;
    }
    void return_region_slot(std::size_t slot) noexcept {
        if (slot >= RegionCapacity) return;
        auto& region = regions_[slot];
        if (region.on_free_list || region.valid || region.reclaim_pending ||
            region.reclaim_enqueued || member_handle_valid(region.member_head))
            return;
        if (region.generation >= GenerationLimit) {
            if (!region.generation_exhausted_recorded) {
                region.generation_exhausted_recorded = true;
                ++region_generation_exhausted_count_;
                bump_resource_generation(ReconstructionResource::Region);
            }
            return;
        }
        region_free_stack_[region_free_count_++] = static_cast<std::uint32_t>(slot);
        region.on_free_list = true;
        bump_resource_generation(ReconstructionResource::Region);
    }
    void publish_build() noexcept {
        if (publication_serial_ == PublicationLimit) {
            refuse_build(RegionRefusal::GenerationExhausted); return;
        }
        if (member_capacity_ - member_count_ < build_.member_count) {
            refuse_build(RegionRefusal::MemberCapacity);
            saturating_add(metrics_.member_refusals);
            return;
        }
        const auto slot = allocate_region_slot();
        if (!slot.has_value()) {
            refuse_build(region_generation_exhausted_count_ == RegionCapacity
                ? RegionRefusal::GenerationExhausted
                : RegionRefusal::RegionCapacity);
            return;
        }
        auto& region = regions_[*slot];
        ++region.generation;
        region.valid = true;
        region.reclaim_pending = false;
        region.on_free_list = false;
        region.batch_serial = 0;
        region.preparation_ticket = {};
        region.member_head = {};
        region.member_count = 0;
        ++published_region_count_;
        auto& out = region.snapshot; out = SettledRegionSnapshot{};
        out.handle = {incarnation_, static_cast<std::uint32_t>(*slot), region.generation};
        out.key = tiles_[build_.seed.tile].components[build_.seed.component].key;
        out.complete = true;
        if (publication_reservation_serial_ == PublicationLimit) {
            region.valid = false;
            --published_region_count_;
            return_region_slot(*slot);
            refuse_build(RegionRefusal::GenerationExhausted);
            return;
        }
        out.publication_serial = ++publication_reservation_serial_;
        if (out.publication_serial > publication_serial_)
            publication_serial_ = out.publication_serial;
        std::uint64_t members = 1469598103934665603ULL;
        auto* member_tiles = member_tiles_scratch_.get();
        auto* dependency_slots = dependency_slots_scratch_.get();
        std::size_t dependency_count = 0;
        for (std::size_t i = 0; i < build_.member_count; ++i) {
            const auto ref = build_.members[i];
            auto& component = tiles_[ref.tile].components[ref.component];
            const auto member = allocate_publication_member(ref);
            if (!member.has_value()) {
                fail(RegionRefusal::MemberCapacity);
                return;
            }
            members_[member->slot].next = region.member_head;
            region.member_head = *member;
            ++region.member_count;
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
    void enqueue_region_reclamation(std::size_t slot) noexcept {
        if (slot >= RegionCapacity) return;
        auto& region = regions_[slot];
        if (!region.reclaim_pending || region.reclaim_enqueued) return;
        if (region_reclaim_count_ == RegionCapacity) {
            fail(RegionRefusal::ManifestCapacity);
            return;
        }
        region_reclaim_queue_[region_reclaim_tail_] =
            static_cast<std::uint32_t>(slot);
        region_reclaim_tail_ = (region_reclaim_tail_ + 1U) % RegionCapacity;
        ++region_reclaim_count_;
        region.reclaim_enqueued = true;
        if (region_reclaim_count_ > metrics_.reclamation_high_water)
            metrics_.reclamation_high_water = region_reclaim_count_;
    }

    void retire_handle(SettledRegionHandle handle) noexcept {
        if (handle.world_incarnation != incarnation_ || handle.slot >= RegionCapacity) return;
        auto& region = regions_[handle.slot];
        if (region.valid && region.generation == handle.generation) {
            const bool was_visible = region_visible(region);
            region.valid = false;
            if (was_visible && published_region_count_ != 0) --published_region_count_;
            if (was_visible && current_change_serial_ != 0 &&
                !attach_retired_region_to_current_change(handle.slot, region)) {
                saturating_add(metrics_.invalidated_regions);
                return;
            }
            retire_subscriber(region.subscriber);
            region.reclaim_pending = subscriber_handle_valid(region.subscriber) ||
                                     member_handle_valid(region.member_head);
            if (!region.reclaim_pending) {
                region.subscriber = {};
                return_region_slot(handle.slot);
            } else {
                enqueue_region_reclamation(handle.slot);
            }
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


    [[nodiscard]] bool member_handle_valid(MemberHandle handle) const noexcept {
        return handle.slot < member_capacity_ && members_[handle.slot].active &&
               members_[handle.slot].generation == handle.generation;
    }
    [[nodiscard]] std::optional<MemberHandle> allocate_publication_member(
        ComponentRef ref) noexcept {
        while (member_free_head_ != invalid_pool_index) {
            const auto slot = member_free_head_;
            auto& member = members_[slot];
            member_free_head_ = member.next_free;
            if (member.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            ++member.generation;
            member.ref = ref;
            member.tile_revision = ref.tile < tile_count_ ? tiles_[ref.tile].revision : 0;
            member.next = {};
            member.next_free = invalid_pool_index;
            member.active = true;
            ++member_count_;
            saturating_add(metrics_.member_records);
            if (member_count_ > metrics_.member_high_water)
                metrics_.member_high_water = member_count_;
            return MemberHandle{slot, member.generation};
        }
        saturating_add(metrics_.member_refusals);
        return std::nullopt;
    }
    void release_publication_member(MemberHandle handle) noexcept {
        if (!member_handle_valid(handle)) return;
        auto& member = members_[handle.slot];
        member.active = false;
        member.next = {};
        member.next_free = member_free_head_;
        member_free_head_ = handle.slot;
        --member_count_;
        saturating_add(metrics_.member_reclaims);
        bump_resource_generation(ReconstructionResource::Member);
    }
    [[nodiscard]] bool source_handle_valid(SourceHandle handle) const noexcept {
        return handle.slot < RegionCapacity && sources_[handle.slot].active &&
               sources_[handle.slot].generation == handle.generation;
    }
    [[nodiscard]] std::optional<SourceHandle> allocate_source_region() noexcept {
        while (source_free_head_ != invalid_pool_index) {
            const auto slot = source_free_head_;
            auto& source = sources_[slot];
            source_free_head_ = source.next_free;
            if (source.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            const auto generation = source.generation + 1U;
            source = SourceRegion{};
            source.generation = generation;
            source.active = true;
            source.next_free = invalid_pool_index;
            ++source_count_;
            return SourceHandle{slot, generation};
        }
        return std::nullopt;
    }
    [[nodiscard]] std::optional<TicketHandle> allocate_reconstruction_ticket() noexcept {
        while (ticket_free_head_ != invalid_pool_index) {
            const auto slot = ticket_free_head_;
            auto& ticket = reconstruction_tickets_[slot];
            ticket_free_head_ = ticket.next_free;
            if (ticket.generation == std::numeric_limits<std::uint64_t>::max() ||
                reconstruction_serial_ == std::numeric_limits<std::uint64_t>::max())
                continue;
            const auto generation = ticket.generation + 1U;
            ticket = ReconstructionTicket{};
            ticket.generation = generation;
            ticket.serial = ++reconstruction_serial_;
            ticket.admission_change_serial = change_serial_;
            ticket.started_work = metrics_.work_units;
            ticket.allocated = true;
            ticket.queued = true;
            ticket.next_free = invalid_pool_index;
            ++ticket_count_;
            saturating_add(metrics_.reconstruction_tickets);
            const auto handle = TicketHandle{slot, generation};
            if (ticket_handle_valid(reconstruction_queue_tail_))
                reconstruction_tickets_[reconstruction_queue_tail_.slot].next_queue = handle;
            else
                reconstruction_queue_head_ = handle;
            reconstruction_queue_tail_ = handle;
            return handle;
        }
        return std::nullopt;
    }
    [[nodiscard]] TicketHandle ensure_current_change_ticket() noexcept {
        if (ticket_handle_valid(current_change_ticket_)) return current_change_ticket_;
        const auto ticket = allocate_reconstruction_ticket();
        if (!ticket.has_value()) {
            last_refusal_ = RegionRefusal::ManifestCapacity;
            saturating_add(metrics_.builds_refused);
            return {};
        }
        current_change_ticket_ = *ticket;
        return *ticket;
    }
    bool attach_retired_region_to_current_change(
        std::size_t region_slot, Region& region) noexcept {
        if (region.member_head.slot == invalid_pool_index || region.member_count == 0)
            return true;
        const auto ticket_handle = ensure_current_change_ticket();
        if (!ticket_handle_valid(ticket_handle)) {
            last_refusal_ = RegionRefusal::ManifestCapacity;
            halted_ = true;
            saturating_add(metrics_.builds_refused);
            return false;
        }
        const auto source_handle = allocate_source_region();
        if (!source_handle.has_value()) {
            last_refusal_ = RegionRefusal::ManifestCapacity;
            halted_ = true;
            saturating_add(metrics_.builds_refused);
            return false;
        }
        auto& source = sources_[source_handle->slot];
        source.key = region.snapshot.key;
        source.member_head = region.member_head;
        source.member_count = region.member_count;
        source.source_region_slot = static_cast<std::uint32_t>(region_slot);
        source.source_region_generation = region.generation;
        region.member_head = {};
        region.member_count = 0;
        auto& ticket = reconstruction_tickets_[ticket_handle.slot];
        if (source_handle_valid(ticket.source_tail))
            sources_[ticket.source_tail.slot].next = *source_handle;
        else
            ticket.source_head = *source_handle;
        ticket.source_tail = *source_handle;
        ++ticket.source_count;
        return true;
    }


    [[nodiscard]] bool seed_handle_valid(SeedHandle handle) const noexcept {
        return handle.slot < frontier_capacity_ &&
               reconstruction_seeds_[handle.slot].active &&
               reconstruction_seeds_[handle.slot].generation == handle.generation;
    }
    [[nodiscard]] bool staged_member_handle_valid(StagedMemberHandle handle) const noexcept {
        return handle.slot < frontier_capacity_ && staged_members_[handle.slot].active &&
               staged_members_[handle.slot].generation == handle.generation;
    }
    [[nodiscard]] bool staged_child_handle_valid(StagedChildHandle handle) const noexcept {
        return handle.slot < RegionCapacity && staged_children_[handle.slot].active &&
               staged_children_[handle.slot].generation == handle.generation;
    }
    void release_source_region(SourceHandle handle) noexcept {
        if (!source_handle_valid(handle)) return;
        auto& source = sources_[handle.slot];
        source.active = false;
        source.member_head = {};
        source.next = {};
        source.next_free = source_free_head_;
        source_free_head_ = handle.slot;
        if (source_count_ != 0) --source_count_;
        bump_resource_generation(ReconstructionResource::Manifest);
    }
    [[nodiscard]] std::optional<SeedHandle> allocate_seed_node(
        ComponentRef ref) noexcept {
        while (seed_free_head_ != invalid_pool_index) {
            const auto slot = seed_free_head_;
            auto& seed = reconstruction_seeds_[slot];
            seed_free_head_ = seed.next_free;
            if (seed.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            const auto generation = seed.generation + 1U;
            seed = ReconstructionSeed{};
            seed.generation = generation;
            seed.active = true;
            seed.ref = ref;
            seed.next_free = invalid_pool_index;
            ++seed_count_;
            return SeedHandle{slot, generation};
        }
        return std::nullopt;
    }
    [[nodiscard]] std::optional<SeedHandle> allocate_reconstruction_seed(
        TicketHandle ticket_handle, ComponentRef ref) noexcept {
        if (!ticket_handle_valid(ticket_handle) || ref.tile >= tile_count_ ||
            ref.component >= tiles_[ref.tile].component_count)
            return std::nullopt;
        auto& component = tiles_[ref.tile].components[ref.component];
        if (component_reserved(component)) {
            const auto other = TicketHandle{
                component.reconstruction_ticket,
                component.reconstruction_ticket_generation};
            if (other == ticket_handle &&
                component.reconstruction_attempt ==
                    reconstruction_tickets_[ticket_handle.slot].attempt)
                return SeedHandle{};
            if (ticket_handle_valid(other) &&
                reconstruction_tickets_[other.slot].serial <
                    reconstruction_tickets_[ticket_handle.slot].serial)
                return SeedHandle{};
        }
        const auto handle = allocate_seed_node(ref);
        if (!handle.has_value()) return std::nullopt;
        auto& ticket = reconstruction_tickets_[ticket_handle.slot];
        if (seed_handle_valid(ticket.seed_tail))
            reconstruction_seeds_[ticket.seed_tail.slot].next = *handle;
        else
            ticket.seed_head = *handle;
        ticket.seed_tail = *handle;
        ++ticket.seed_count;
        component.reconstruction_ticket = ticket_handle.slot;
        component.reconstruction_ticket_generation = ticket_handle.generation;
        component.reconstruction_attempt = ticket.attempt;
        component.build_generation = 0;
        component.in_build = false;
        return handle;
    }
    void release_reconstruction_seed(SeedHandle handle) noexcept {
        if (!seed_handle_valid(handle)) return;
        auto& seed = reconstruction_seeds_[handle.slot];
        seed.active = false;
        seed.next = {};
        seed.next_free = seed_free_head_;
        seed_free_head_ = handle.slot;
        if (seed_count_ != 0) --seed_count_;
        bump_resource_generation(ReconstructionResource::Frontier);
    }
    [[nodiscard]] std::optional<StagedMemberHandle> allocate_staged_member(
        ComponentRef ref) noexcept {
        while (staged_member_free_head_ != invalid_pool_index) {
            const auto slot = staged_member_free_head_;
            auto& member = staged_members_[slot];
            staged_member_free_head_ = member.next_free;
            if (member.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            const auto generation = member.generation + 1U;
            member = StagedMember{};
            member.generation = generation;
            member.active = true;
            member.ref = ref;
            member.next_free = invalid_pool_index;
            ++staged_member_count_;
            return StagedMemberHandle{slot, generation};
        }
        return std::nullopt;
    }
    void release_staged_member(StagedMemberHandle handle) noexcept {
        if (!staged_member_handle_valid(handle)) return;
        auto& member = staged_members_[handle.slot];
        member.active = false;
        member.next = {};
        member.next_free = staged_member_free_head_;
        staged_member_free_head_ = handle.slot;
        if (staged_member_count_ != 0) --staged_member_count_;
        bump_resource_generation(ReconstructionResource::Member);
    }
    [[nodiscard]] std::optional<StagedChildHandle> allocate_staged_child() noexcept {
        while (staged_child_free_head_ != invalid_pool_index) {
            const auto slot = staged_child_free_head_;
            auto& child = staged_children_[slot];
            staged_child_free_head_ = child.next_free;
            if (child.generation == std::numeric_limits<std::uint64_t>::max())
                continue;
            const auto generation = child.generation + 1U;
            child = StagedChild{};
            child.generation = generation;
            child.active = true;
            child.next_free = invalid_pool_index;
            ++staged_child_count_;
            return StagedChildHandle{slot, generation};
        }
        return std::nullopt;
    }
    void release_staged_child(StagedChildHandle handle) noexcept {
        if (!staged_child_handle_valid(handle)) return;
        auto& child = staged_children_[handle.slot];
        if (subscriber_handle_valid(child.subscriber))
            retire_subscriber(child.subscriber);
        child.active = false;
        child.member_head = {};
        child.member_tail = {};
        child.subscriber = {};
        child.next = {};
        child.next_free = staged_child_free_head_;
        staged_child_free_head_ = handle.slot;
        if (staged_child_count_ != 0) --staged_child_count_;
        bump_resource_generation(ReconstructionResource::Manifest);
    }
    void append_seed_cleanup(SeedHandle head, SeedHandle tail) noexcept {
        if (!seed_handle_valid(head)) return;
        if (seed_handle_valid(stale_seed_cleanup_tail_))
            reconstruction_seeds_[stale_seed_cleanup_tail_.slot].next = head;
        else
            stale_seed_cleanup_head_ = head;
        stale_seed_cleanup_tail_ = seed_handle_valid(tail) ? tail : head;
    }
    void append_child_cleanup(StagedChildHandle head, StagedChildHandle tail) noexcept {
        if (!staged_child_handle_valid(head)) return;
        if (staged_child_handle_valid(stale_child_cleanup_tail_))
            staged_children_[stale_child_cleanup_tail_.slot].next = head;
        else
            stale_child_cleanup_head_ = head;
        stale_child_cleanup_tail_ = staged_child_handle_valid(tail) ? tail : head;
    }
    void append_source_cleanup(SourceHandle head, SourceHandle tail) noexcept {
        if (!source_handle_valid(head)) return;
        if (source_handle_valid(source_cleanup_tail_))
            sources_[source_cleanup_tail_.slot].next = head;
        else
            source_cleanup_head_ = head;
        source_cleanup_tail_ = source_handle_valid(tail) ? tail : head;
    }
    void queue_ticket_attempt_artifacts(ReconstructionTicket& ticket) noexcept {
        append_seed_cleanup(ticket.seed_head, ticket.seed_tail);
        append_child_cleanup(ticket.child_head, ticket.child_tail);
        ticket.seed_head = {};
        ticket.seed_tail = {};
        ticket.next_seed = {};
        ticket.child_head = {};
        ticket.child_tail = {};
        ticket.preflight_child = {};
        ticket.prepare_child = {};
        ticket.prepare_member = {};
        ticket.active_child = {};
        const auto ticket_slot =
            static_cast<std::uint32_t>(&ticket - reconstruction_tickets_.data());
        if (digest_owner_ticket_.slot == ticket_slot &&
            digest_owner_ticket_.generation == ticket.generation) {
            digest_owner_ticket_ = {};
            digest_owner_child_ = {};
        }
        ticket.seed_count = 0;
        ticket.child_count = 0;
        ticket.staged_member_count = 0;
        ticket.staged_area_total = 0;
        ticket.staged_area_max = 0;
    }
    void request_ticket_restart(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return;
        reconstruction_tickets_[handle.slot].restart_requested = true;
    }
    void rotate_reconstruction_head() noexcept {
        if (!ticket_handle_valid(reconstruction_queue_head_) ||
            reconstruction_queue_head_ == reconstruction_queue_tail_)
            return;
        const auto old = reconstruction_queue_head_;
        auto& ticket = reconstruction_tickets_[old.slot];
        reconstruction_queue_head_ = ticket.next_queue;
        ticket.next_queue = {};
        reconstruction_tickets_[reconstruction_queue_tail_.slot].next_queue = old;
        reconstruction_queue_tail_ = old;
    }
    void release_reconstruction_ticket(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (reconstruction_queue_head_ == handle) {
            reconstruction_queue_head_ = ticket.next_queue;
            if (!ticket_handle_valid(reconstruction_queue_head_))
                reconstruction_queue_tail_ = {};
        }
        ticket.allocated = false;
        ticket.queued = false;
        ticket.next_queue = {};
        ticket.next_free = ticket_free_head_;
        ticket_free_head_ = handle.slot;
        if (ticket_count_ != 0) --ticket_count_;
        bump_resource_generation(ReconstructionResource::Manifest);
    }
    void advance_source_cursor(ReconstructionTicket& ticket) noexcept {
        if (!source_handle_valid(ticket.admit_source)) {
            ticket.admit_member = {};
            return;
        }
        auto& source = sources_[ticket.admit_source.slot];
        if (member_handle_valid(ticket.admit_member)) {
            ticket.admit_member = members_[ticket.admit_member.slot].next;
            if (member_handle_valid(ticket.admit_member)) return;
        }
        ticket.admit_source = source.next;
        ticket.admit_member = source_handle_valid(ticket.admit_source)
            ? sources_[ticket.admit_source.slot].member_head : MemberHandle{};
    }
    void reset_ticket_admission(ReconstructionTicket& ticket) noexcept {
        ticket.phase = ReconstructionPhase::Admitting;
        ticket.admission_change_serial = change_serial_;
        ticket.admit_source = ticket.source_head;
        ticket.admit_member = source_handle_valid(ticket.admit_source)
            ? sources_[ticket.admit_source.slot].member_head : MemberHandle{};
        ticket.scanning_changed_tile = false;
        ticket.scan_component = 0;
        ticket.scan_tile = 0;
        ticket.scan_generation = 0;
        ticket.blocker_seen = false;
        ticket.wait_tile = invalid_pool_index;
        ticket.wait_generation = 0;
        ticket.refusal = RegionRefusal::None;
        ticket.restart_requested = false;
    }
    void begin_ticket_restart(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (digest_owner_ticket_ == handle) {
            digest_owner_ticket_ = {};
            digest_owner_child_ = {};
        }
        if (build_.phase != Phase::Idle && build_.reconstruction_ticket == handle) {
            if (staged_child_handle_valid(build_.staging_child)) {
                auto& child = staged_children_[build_.staging_child.slot];
                append_child_cleanup(build_.staging_child, build_.staging_child);
                build_.staging_child = {};
                child.next = {};
            }
            const auto subscriber = build_.subscriber;
            retire_subscriber(subscriber);
            reset_build();
        }
        ticket.restart_child = ticket.child_head;
        ticket.phase = ReconstructionPhase::RestartCleanup;
        ticket.restart_cleanup_index = 0;
        ticket.restart_requested = false;
        saturating_add(metrics_.reconstruction_restarts);
    }
    bool service_ticket_restart_cleanup(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];

        if (staged_child_handle_valid(ticket.restart_child)) {
            auto& child = staged_children_[ticket.restart_child.slot];
            if (child.target_region_slot != invalid_pool_index) {
                const auto slot = static_cast<std::size_t>(child.target_region_slot);
                if (slot < RegionCapacity) {
                    auto& region = regions_[slot];
                    if (region.preparation_ticket == handle) {
                        if (region.valid) {
                            region.valid = false;
                            retire_subscriber(region.subscriber);
                        }
                        region.reclaim_pending =
                            subscriber_handle_valid(region.subscriber) ||
                            member_handle_valid(region.member_head);
                        region.preparation_ticket = {};
                        if (!region.reclaim_pending)
                            return_region_slot(slot);
                        else
                            enqueue_region_reclamation(slot);
                    } else {
                        return_region_slot(slot);
                    }
                }
                child.target_region_slot = invalid_pool_index;
            }
            ticket.restart_child = child.next;
            return true;
        }

        queue_ticket_attempt_artifacts(ticket);
        if (ticket.attempt == std::numeric_limits<std::uint64_t>::max()) {
            ticket.phase = ReconstructionPhase::Refused;
            ticket.refusal = RegionRefusal::GenerationExhausted;
            last_refusal_ = ticket.refusal;
            return true;
        }
        ++ticket.attempt;
        ticket.prepared_child_count = 0;
        ticket.preflight_region_scan = 0;
        ticket.preflight_free_count = 0;
        ticket.batch_serial = 0;
        ticket.publication_base_serial = 0;
        ticket.publication_end_serial = 0;
        ticket.publication_reserved = false;
        ticket.restart_child = {};
        reset_ticket_admission(ticket);
        if (ticket_handle_valid(reconstruction_queue_head_) &&
            reconstruction_queue_head_ == handle)
            rotate_reconstruction_head();
        return true;
    }
    bool add_ticket_seed(TicketHandle handle, ComponentRef ref) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto before = reconstruction_tickets_[handle.slot].seed_count;
        const auto seed = allocate_reconstruction_seed(handle, ref);
        if (!seed.has_value()) {
            block_reconstruction_ticket(handle, RegionRefusal::FrontierCapacity);
            return false;
        }
        (void)before;
        return true;
    }
    bool service_ticket_admission(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (!source_handle_valid(ticket.admit_source)) {
            if (ticket.blocker_seen) {
                ticket.phase = ReconstructionPhase::Blocked;
                ticket.refusal = RegionRefusal::UnknownBoundary;
                ticket.wait_resource = ReconstructionResource::None;
                ticket.wait_resource_generation = 0;
                last_refusal_ = ticket.refusal;
                saturating_add(metrics_.reconstruction_waits);
            } else {
                ticket.phase = ReconstructionPhase::Building;
                ticket.next_seed = ticket.seed_head;
            }
            return true;
        }
        auto& source = sources_[ticket.admit_source.slot];
        if (ticket.scanning_changed_tile) {
            if (ticket.scan_tile >= tile_count_) {
                request_ticket_restart(handle);
                return true;
            }
            auto& tile = tiles_[ticket.scan_tile];
            if (tile.observation_generation != ticket.scan_generation) {
                request_ticket_restart(handle);
                return true;
            }
            if (ticket.scan_component < tile.component_count) {
                const auto component_index = ticket.scan_component++;
                if (tile.ready && tile.components[component_index].key == ticket.scan_key) {
                    if (!add_ticket_seed(handle, ComponentRef{
                        static_cast<std::uint16_t>(ticket.scan_tile),
                        static_cast<std::uint16_t>(component_index)}))
                        return true;
                }
                return true;
            }
            ticket.scanning_changed_tile = false;
            ticket.scan_component = 0;
            advance_source_cursor(ticket);
            return true;
        }
        if (!member_handle_valid(ticket.admit_member)) {
            advance_source_cursor(ticket);
            return true;
        }
        const auto member = members_[ticket.admit_member.slot];
        if (member.ref.tile >= tile_count_) {
            request_ticket_restart(handle);
            return true;
        }
        auto& tile = tiles_[member.ref.tile];
        if (tile.last_change_serial > ticket.admission_change_serial) {
            request_ticket_restart(handle);
            return true;
        }
        if (!tile.ready) {
            if (!ticket.blocker_seen) {
                ticket.wait_tile = member.ref.tile;
                ticket.wait_generation = tile.observation_generation;
            }
            ticket.blocker_seen = true;
            advance_source_cursor(ticket);
            return true;
        }
        if (tile.revision == member.tile_revision &&
            member.ref.component < tile.component_count &&
            tile.components[member.ref.component].key == source.key) {
            (void)add_ticket_seed(handle, member.ref);
            advance_source_cursor(ticket);
            return true;
        }
        ticket.scanning_changed_tile = true;
        ticket.scan_tile = member.ref.tile;
        ticket.scan_component = 0;
        ticket.scan_generation = tile.observation_generation;
        ticket.scan_key = source.key;
        return true;
    }
    bool seed_belongs_to_ticket(const Component& component, TicketHandle handle) const noexcept {
        return ticket_handle_valid(handle) &&
               component.reconstruction_ticket == handle.slot &&
               component.reconstruction_ticket_generation == handle.generation &&
               component.reconstruction_attempt ==
                   reconstruction_tickets_[handle.slot].attempt;
    }

    void block_reconstruction_ticket(
        TicketHandle handle, RegionRefusal reason,
        std::uint32_t wait_tile = invalid_pool_index,
        std::uint64_t wait_generation = 0) noexcept {
        if (!ticket_handle_valid(handle)) return;
        auto& ticket = reconstruction_tickets_[handle.slot];
        ticket.phase = ReconstructionPhase::Blocked;
        ticket.refusal = reason;
        ticket.wait_tile = wait_tile;
        ticket.wait_generation = wait_generation;
        ticket.wait_resource = resource_for_refusal(reason);
        ticket.wait_resource_generation =
            resource_generation(ticket.wait_resource);
        last_refusal_ = reason;
        saturating_add(metrics_.reconstruction_waits);
        if (reason == RegionRefusal::FrontierCapacity)
            saturating_add(metrics_.frontier_refusals);
        if (reason == RegionRefusal::DependencyCapacity)
            saturating_add(metrics_.dependency_refusals);
        if (reason == RegionRefusal::MemberCapacity)
            saturating_add(metrics_.member_refusals);
        if (reason == RegionRefusal::RegionCapacity)
            saturating_add(metrics_.region_refusals);
    }

    bool ticket_frontier_push(
        TicketHandle handle, StagedChildHandle child_handle, ComponentRef ref,
        std::optional<SeedHandle> reused = std::nullopt) noexcept {
        if (!ticket_handle_valid(handle) || !staged_child_handle_valid(child_handle) ||
            ref.tile >= tile_count_ || ref.component >= tiles_[ref.tile].component_count)
            return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        auto& child = staged_children_[child_handle.slot];
        auto& component = tiles_[ref.tile].components[ref.component];
        if (component.build_generation == child.build_generation)
            return true;
        if (seed_belongs_to_ticket(component, handle) &&
            component.build_generation != 0)
            return true;

        if (component_reserved(component) && !seed_belongs_to_ticket(component, handle)) {
            const auto other = TicketHandle{
                component.reconstruction_ticket,
                component.reconstruction_ticket_generation};
            if (ticket_handle_valid(other) &&
                reconstruction_tickets_[other.slot].serial < ticket.serial) {
                block_reconstruction_ticket(handle, RegionRefusal::RevisionChanged);
                return false;
            }
            request_ticket_restart(other);
        }

        SeedHandle node{};
        if (reused.has_value() && seed_handle_valid(*reused)) {
            node = *reused;
            reconstruction_seeds_[node.slot].ref = ref;
            reconstruction_seeds_[node.slot].next = {};
        } else {
            const auto allocated = allocate_seed_node(ref);
            if (!allocated.has_value()) {
                block_reconstruction_ticket(handle, RegionRefusal::FrontierCapacity);
                return false;
            }
            node = *allocated;
        }
        if (seed_handle_valid(child.frontier_tail))
            reconstruction_seeds_[child.frontier_tail.slot].next = node;
        else
            child.frontier_head = node;
        child.frontier_tail = node;
        ++child.frontier_count;

        component.reconstruction_ticket = handle.slot;
        component.reconstruction_ticket_generation = handle.generation;
        component.reconstruction_attempt = ticket.attempt;
        component.build_generation = child.build_generation;
        component.in_build = true;
        return true;
    }

    bool pop_ticket_frontier_min(
        StagedChild& child, SeedHandle& out_handle, ComponentRef& out_ref) noexcept {
        if (!seed_handle_valid(child.frontier_head)) return false;
        SeedHandle previous{}, current = child.frontier_head;
        SeedHandle best_previous{}, best = current;
        while (seed_handle_valid(current)) {
            if (ref_less(reconstruction_seeds_[current.slot].ref,
                         reconstruction_seeds_[best.slot].ref)) {
                best = current;
                best_previous = previous;
            }
            previous = current;
            current = reconstruction_seeds_[current.slot].next;
        }
        const auto next = reconstruction_seeds_[best.slot].next;
        if (seed_handle_valid(best_previous))
            reconstruction_seeds_[best_previous.slot].next = next;
        else
            child.frontier_head = next;
        if (child.frontier_tail == best)
            child.frontier_tail = best_previous;
        reconstruction_seeds_[best.slot].next = {};
        if (child.frontier_count != 0) --child.frontier_count;
        out_handle = best;
        out_ref = reconstruction_seeds_[best.slot].ref;
        return true;
    }

    bool add_ticket_dependency(
        TicketHandle handle, StagedChild& child, DependencyKind kind,
        std::size_t tile_index,
        std::size_t face_run = region_detail::invalid_index) noexcept {
        if (add_dependency(child.subscriber, kind, tile_index, face_run)) {
            if (kind == DependencyKind::AbsenceFaceRun)
                saturating_add(metrics_.absence_subscriptions);
            return true;
        }
        block_reconstruction_ticket(handle, RegionRefusal::DependencyCapacity);
        return false;
    }

    bool ticket_boundary_complete(
        TicketHandle handle, StagedChild& child, ComponentRef ref) noexcept {
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
                    // Subscribe even for an unsealed unknown run so newly registered
                    // residency is the exact retry trigger rather than polling.
                    if (!add_ticket_dependency(
                            handle, child, DependencyKind::AbsenceFaceRun,
                            ref.tile, run_index))
                        return false;
                    if ((tile.sealed_edges & run.direction) == 0) {
                        block_reconstruction_ticket(
                            handle, RegionRefusal::UnknownBoundary,
                            static_cast<std::uint32_t>(ref.tile),
                            tile.observation_generation);
                        return false;
                    }
                    saw_absence = true;
                    continue;
                }
                if (!add_ticket_dependency(
                        handle, child, DependencyKind::TileRevision, neighbour))
                    return false;
                if (!tiles_[neighbour].ready) {
                    block_reconstruction_ticket(
                        handle, RegionRefusal::UnknownBoundary,
                        static_cast<std::uint32_t>(neighbour),
                        tiles_[neighbour].observation_generation);
                    return false;
                }
            }
            if (saw_absence) {
                // The dependency above is both the absence proof and its exact
                // new-residency invalidation trigger.
            }
        }
        return true;
    }

    bool start_ticket_child(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        while (seed_handle_valid(ticket.seed_head)) {
            const auto seed_handle = ticket.seed_head;
            const auto next = reconstruction_seeds_[seed_handle.slot].next;
            const auto ref = reconstruction_seeds_[seed_handle.slot].ref;
            ticket.seed_head = next;
            if (!seed_handle_valid(next)) ticket.seed_tail = {};
            reconstruction_seeds_[seed_handle.slot].next = {};
            if (ticket.seed_count != 0) --ticket.seed_count;

            if (ref.tile >= tile_count_ ||
                ref.component >= tiles_[ref.tile].component_count) {
                release_reconstruction_seed(seed_handle);
                continue;
            }
            auto& component = tiles_[ref.tile].components[ref.component];
            if (!seed_belongs_to_ticket(component, handle) || assigned(component) ||
                (component.build_generation != 0 &&
                 component.reconstruction_attempt == ticket.attempt)) {
                release_reconstruction_seed(seed_handle);
                continue;
            }
            if (build_generation_serial_ == std::numeric_limits<std::uint64_t>::max()) {
                ticket.phase = ReconstructionPhase::Refused;
                ticket.refusal = RegionRefusal::GenerationExhausted;
                last_refusal_ = ticket.refusal;
                release_reconstruction_seed(seed_handle);
                return true;
            }
            const auto child_handle = allocate_staged_child();
            if (!child_handle.has_value()) {
                // Put the seed back at the head and wait for staged-child capacity.
                reconstruction_seeds_[seed_handle.slot].next = ticket.seed_head;
                ticket.seed_head = seed_handle;
                if (!seed_handle_valid(ticket.seed_tail)) ticket.seed_tail = seed_handle;
                ++ticket.seed_count;
                block_reconstruction_ticket(handle, RegionRefusal::RegionCapacity);
                return true;
            }
            const auto subscriber = allocate_subscriber(
                SubscriberKind::Staged, handle.slot, handle.generation);
            if (!subscriber.has_value()) {
                release_staged_child(*child_handle);
                reconstruction_seeds_[seed_handle.slot].next = ticket.seed_head;
                ticket.seed_head = seed_handle;
                if (!seed_handle_valid(ticket.seed_tail)) ticket.seed_tail = seed_handle;
                ++ticket.seed_count;
                block_reconstruction_ticket(handle, RegionRefusal::DependencyCapacity);
                return true;
            }
            auto& child = staged_children_[child_handle->slot];
            child.subscriber = *subscriber;
            child.snapshot = {};
            child.snapshot.key = component.key;
            child.snapshot.complete = true;
            child.snapshot.member_digest = 1469598103934665603ULL;
            child.snapshot.dependency_digest = 1469598103934665603ULL;
            child.build_generation = ++build_generation_serial_;
            child.phase = StagedChildPhase::Traversing;
            if (staged_child_handle_valid(ticket.child_tail))
                staged_children_[ticket.child_tail.slot].next = *child_handle;
            else
                ticket.child_head = *child_handle;
            ticket.child_tail = *child_handle;
            ticket.active_child = *child_handle;
            (void)ticket_frontier_push(handle, *child_handle, ref, seed_handle);
            saturating_add(metrics_.builds_started);
            return true;
        }
        ticket.phase = ReconstructionPhase::PreflightDependencies;
        ticket.preflight_child = ticket.child_head;
        ticket.preflight_dependency = {};
        return true;
    }

    bool process_ticket_child_component(
        TicketHandle handle, StagedChildHandle child_handle) noexcept {
        if (!ticket_handle_valid(handle) || !staged_child_handle_valid(child_handle))
            return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        auto& child = staged_children_[child_handle.slot];
        SeedHandle frontier_node{};
        ComponentRef ref{};
        if (!pop_ticket_frontier_min(child, frontier_node, ref)) {
            child.phase = StagedChildPhase::GatherMembers;
            return true;
        }

        const auto release_frontier = [this, frontier_node]() noexcept {
            release_reconstruction_seed(frontier_node);
        };
        if (ref.tile >= tile_count_ ||
            ref.component >= tiles_[ref.tile].component_count) {
            release_frontier();
            request_ticket_restart(handle);
            return true;
        }
        auto& component = tiles_[ref.tile].components[ref.component];
        if (!tiles_[ref.tile].ready || assigned(component) ||
            !seed_belongs_to_ticket(component, handle) ||
            !(component.key == child.snapshot.key)) {
            release_frontier();
            request_ticket_restart(handle);
            return true;
        }
        if (!add_ticket_dependency(
                handle, child, DependencyKind::TileRevision, ref.tile)) {
            release_frontier();
            return true;
        }
        if (!ticket_boundary_complete(handle, child, ref)) {
            release_frontier();
            return true;
        }

        const auto staged_member = allocate_staged_member(ref);
        if (!staged_member.has_value()) {
            release_frontier();
            block_reconstruction_ticket(handle, RegionRefusal::MemberCapacity);
            return true;
        }
        if (staged_member_handle_valid(child.member_tail))
            staged_members_[child.member_tail.slot].next = *staged_member;
        else
            child.member_head = *staged_member;
        child.member_tail = *staged_member;
        ++child.member_count;
        component.in_build = false;

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
            if (current &&
                tiles_[neighbour.tile].components[neighbour.component].key ==
                    child.snapshot.key &&
                !ticket_frontier_push(handle, child_handle, neighbour)) {
                release_frontier();
                return true;
            }
            edge_handle = next;
        }
        release_frontier();
        return true;
    }

    bool claim_child_digest(
        TicketHandle handle, StagedChildHandle child_handle) noexcept {
        if (!ticket_handle_valid(handle) || !staged_child_handle_valid(child_handle))
            return false;
        if (ticket_handle_valid(digest_owner_ticket_)) {
            return digest_owner_ticket_ == handle &&
                   digest_owner_child_ == child_handle;
        }
        if (digest_generation_serial_ == std::numeric_limits<std::uint64_t>::max()) {
            auto& ticket = reconstruction_tickets_[handle.slot];
            ticket.phase = ReconstructionPhase::Refused;
            ticket.refusal = RegionRefusal::GenerationExhausted;
            last_refusal_ = ticket.refusal;
            return false;
        }
        digest_owner_ticket_ = handle;
        digest_owner_child_ = child_handle;
        auto& child = staged_children_[child_handle.slot];
        child.digest_generation = ++digest_generation_serial_;
        child.digest_member = child.member_head;
        child.scratch_member_count = 0;
        child.sort_i = child.sort_j = child.sort_best = child.fold_i = 0;
        child.digest_dependency = {};
        child.scratch_dependency_count = 0;
        child.dep_sort_i = child.dep_sort_j = child.dep_sort_best = child.dep_fold_i = 0;
        child.snapshot.area = 0;
        child.snapshot.tile_count = 0;
        child.snapshot.component_count = 0;
        child.snapshot.dependency_tile_count = 0;
        child.snapshot.member_digest = 1469598103934665603ULL;
        child.snapshot.dependency_digest = 1469598103934665603ULL;
        return true;
    }

    void release_child_digest_owner(
        TicketHandle handle, StagedChildHandle child_handle) noexcept {
        if (digest_owner_ticket_ == handle && digest_owner_child_ == child_handle) {
            digest_owner_ticket_ = {};
            digest_owner_child_ = {};
        }
    }

    bool service_child_digest(
        TicketHandle handle, StagedChildHandle child_handle) noexcept {
        if (!claim_child_digest(handle, child_handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        auto& child = staged_children_[child_handle.slot];

        if (child.phase == StagedChildPhase::GatherMembers) {
            if (staged_member_handle_valid(child.digest_member)) {
                if (child.scratch_member_count == frontier_capacity_) {
                    block_reconstruction_ticket(handle, RegionRefusal::MemberCapacity);
                    release_child_digest_owner(handle, child_handle);
                    return true;
                }
                build_.members[child.scratch_member_count++] =
                    staged_members_[child.digest_member.slot].ref;
                child.digest_member = staged_members_[child.digest_member.slot].next;
                return true;
            }
            child.phase = StagedChildPhase::SortMembers;
            child.sort_i = 0;
            child.sort_best = 0;
            child.sort_j = child.scratch_member_count > 1 ? 1 : 0;
            return true;
        }

        if (child.phase == StagedChildPhase::SortMembers) {
            if (child.scratch_member_count <= 1 ||
                child.sort_i + 1 >= child.scratch_member_count) {
                child.phase = StagedChildPhase::FoldMembers;
                child.fold_i = 0;
                return true;
            }
            if (child.sort_j < child.scratch_member_count) {
                if (ref_less(build_.members[child.sort_j],
                             build_.members[child.sort_best]))
                    child.sort_best = child.sort_j;
                ++child.sort_j;
                return true;
            }
            if (child.sort_best != child.sort_i)
                std::swap(build_.members[child.sort_i],
                          build_.members[child.sort_best]);
            ++child.sort_i;
            child.sort_best = child.sort_i;
            child.sort_j = child.sort_i + 1;
            return true;
        }

        if (child.phase == StagedChildPhase::FoldMembers) {
            if (child.fold_i < child.scratch_member_count) {
                const auto ref = build_.members[child.fold_i++];
                if (ref.tile >= tile_count_ ||
                    ref.component >= tiles_[ref.tile].component_count) {
                    request_ticket_restart(handle);
                    release_child_digest_owner(handle, child_handle);
                    return true;
                }
                auto& component = tiles_[ref.tile].components[ref.component];
                if (!seed_belongs_to_ticket(component, handle) ||
                    !tiles_[ref.tile].ready ||
                    !(component.key == child.snapshot.key)) {
                    request_ticket_restart(handle);
                    release_child_digest_owner(handle, child_handle);
                    return true;
                }
                auto& out = child.snapshot;
                if (out.component_count == 0) {
                    out.min_x = component.min_x; out.min_y = component.min_y;
                    out.max_x = component.max_x; out.max_y = component.max_y;
                } else {
                    if (component.min_x < out.min_x) out.min_x = component.min_x;
                    if (component.min_y < out.min_y) out.min_y = component.min_y;
                    if (component.max_x > out.max_x) out.max_x = component.max_x;
                    if (component.max_y > out.max_y) out.max_y = component.max_y;
                }
                out.area += component.area;
                ++out.component_count;
                if (tiles_[ref.tile].staging_mark_generation != child.digest_generation) {
                    tiles_[ref.tile].staging_mark_generation = child.digest_generation;
                    ++out.tile_count;
                }
                region_detail::hash_value(out.member_digest, component.digest);
                region_detail::hash_value(out.member_digest, component.min_y);
                region_detail::hash_value(out.member_digest, component.min_x);
                return true;
            }
            child.phase = StagedChildPhase::GatherDependencies;
            child.digest_dependency = subscriber_dependency_head(child.subscriber);
            return true;
        }

        if (child.phase == StagedChildPhase::GatherDependencies) {
            if (dependency_handle_valid(child.digest_dependency)) {
                const auto current = child.digest_dependency;
                child.digest_dependency = dependencies_[current.slot].next_subscriber;
                if (!dependency_current(current)) {
                    request_ticket_restart(handle);
                    release_child_digest_owner(handle, child_handle);
                    return true;
                }
                const auto& dependency = dependencies_[current.slot];
                if (dependency.kind == DependencyKind::TileRevision) {
                    const auto tile_index = static_cast<std::size_t>(dependency.tile);
                    if (tiles_[tile_index].dependency_digest_mark_generation !=
                        child.digest_generation) {
                        tiles_[tile_index].dependency_digest_mark_generation =
                            child.digest_generation;
                        if (child.scratch_dependency_count == tile_capacity_) {
                            block_reconstruction_ticket(
                                handle, RegionRefusal::DependencyCapacity);
                            release_child_digest_owner(handle, child_handle);
                            return true;
                        }
                        dependency_slots_scratch_[child.scratch_dependency_count++] =
                            tile_index;
                    }
                }
                return true;
            }
            child.phase = StagedChildPhase::SortDependencies;
            child.dep_sort_i = 0;
            child.dep_sort_best = 0;
            child.dep_sort_j = child.scratch_dependency_count > 1 ? 1 : 0;
            return true;
        }

        if (child.phase == StagedChildPhase::SortDependencies) {
            if (child.scratch_dependency_count <= 1 ||
                child.dep_sort_i + 1 >= child.scratch_dependency_count) {
                child.phase = StagedChildPhase::FoldDependencies;
                child.dep_fold_i = 0;
                return true;
            }
            if (child.dep_sort_j < child.scratch_dependency_count) {
                const auto candidate =
                    dependency_slots_scratch_[child.dep_sort_j];
                const auto best =
                    dependency_slots_scratch_[child.dep_sort_best];
                if (region_detail::less(
                        tiles_[candidate].key, tiles_[best].key))
                    child.dep_sort_best = child.dep_sort_j;
                ++child.dep_sort_j;
                return true;
            }
            if (child.dep_sort_best != child.dep_sort_i)
                std::swap(
                    dependency_slots_scratch_[child.dep_sort_i],
                    dependency_slots_scratch_[child.dep_sort_best]);
            ++child.dep_sort_i;
            child.dep_sort_best = child.dep_sort_i;
            child.dep_sort_j = child.dep_sort_i + 1;
            return true;
        }

        if (child.phase == StagedChildPhase::FoldDependencies) {
            if (child.dep_fold_i < child.scratch_dependency_count) {
                const auto tile_index =
                    dependency_slots_scratch_[child.dep_fold_i++];
                region_detail::hash_value(
                    child.snapshot.dependency_digest,
                    region_detail::tile_hash(
                        tiles_[tile_index].key, tiles_[tile_index].revision));
                return true;
            }
            child.snapshot.dependency_tile_count =
                static_cast<std::uint32_t>(child.scratch_dependency_count);
            child.phase = StagedChildPhase::Complete;
            ++ticket.child_count;
            ticket.staged_member_count += child.member_count;
            saturating_add(ticket.staged_area_total, child.snapshot.area);
            if (child.snapshot.area > ticket.staged_area_max)
                ticket.staged_area_max = child.snapshot.area;
            saturating_add(metrics_.reconstruction_children_staged);
            ticket.active_child = {};
            release_child_digest_owner(handle, child_handle);
            return true;
        }

        return false;
    }

    bool service_ticket_active_child(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (!staged_child_handle_valid(ticket.active_child))
            return start_ticket_child(handle);
        auto& child = staged_children_[ticket.active_child.slot];
        if (child.phase == StagedChildPhase::Traversing) {
            if (seed_handle_valid(child.frontier_head))
                return process_ticket_child_component(handle, ticket.active_child);
            child.phase = StagedChildPhase::GatherMembers;
            return true;
        }
        return service_child_digest(handle, ticket.active_child);
    }

    bool begin_reconstruction_traversal(TicketHandle handle, ComponentRef seed) noexcept {
        if (!ticket_handle_valid(handle) || seed.tile >= tile_count_ ||
            seed.component >= tiles_[seed.tile].component_count)
            return false;
        reset_build();
        build_.phase = Phase::Traversing;
        build_.seed = seed;
        build_.best = seed;
        if (build_generation_serial_ == std::numeric_limits<std::uint64_t>::max()) {
            reconstruction_tickets_[handle.slot].phase = ReconstructionPhase::Refused;
            reconstruction_tickets_[handle.slot].refusal = RegionRefusal::GenerationExhausted;
            return false;
        }
        build_.generation = ++build_generation_serial_;
        const auto subscriber = allocate_subscriber(
            SubscriberKind::Build, handle.slot, handle.generation);
        if (!subscriber.has_value()) {
            reconstruction_tickets_[handle.slot].phase = ReconstructionPhase::Refused;
            reconstruction_tickets_[handle.slot].refusal = RegionRefusal::DependencyCapacity;
            return false;
        }
        build_.subscriber = *subscriber;
        build_.reconstruction_ticket = handle;
        if (!push(seed)) {
            refuse_build(build_.failure);
            return false;
        }
        saturating_add(metrics_.builds_started);
        return true;
    }
    bool service_ticket_building(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        return service_ticket_active_child(handle);
    }
    bool service_ticket_preflight_dependencies(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (!staged_child_handle_valid(ticket.preflight_child)) {
            ticket.phase = ReconstructionPhase::PreflightRegions;
            ticket.preflight_region_scan = 0;
            ticket.preflight_free_count = 0;
            ticket.preflight_child = ticket.child_head;
            return true;
        }
        auto& child = staged_children_[ticket.preflight_child.slot];
        if (!dependency_handle_valid(ticket.preflight_dependency)) {
            ticket.preflight_dependency = subscriber_dependency_head(child.subscriber);
            if (!dependency_handle_valid(ticket.preflight_dependency)) {
                ticket.preflight_child = child.next;
                return true;
            }
        }
        const auto current = ticket.preflight_dependency;
        const auto next = dependencies_[current.slot].next_subscriber;
        if (!dependency_current(current)) request_ticket_restart(handle);
        if (dependency_handle_valid(next)) {
            ticket.preflight_dependency = next;
        } else {
            ticket.preflight_dependency = {};
            ticket.preflight_child = child.next;
        }
        return true;
    }
    bool service_ticket_preflight_regions(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];

        if (!ticket.publication_reserved) {
            if (ticket.child_count > PublicationLimit - publication_reservation_serial_ ||
                batch_serial_generation_ == std::numeric_limits<std::uint64_t>::max()) {
                ticket.phase = ReconstructionPhase::Refused;
                ticket.refusal = RegionRefusal::GenerationExhausted;
                last_refusal_ = ticket.refusal;
                return true;
            }
            ticket.publication_base_serial =
                publication_reservation_serial_ + 1U;
            publication_reservation_serial_ += ticket.child_count;
            ticket.publication_end_serial = publication_reservation_serial_;
            ticket.batch_serial = ++batch_serial_generation_;
            ticket.publication_reserved = true;
            return true;
        }

        if (region_free_count_ < ticket.child_count - ticket.preflight_free_count) {
            if (region_generation_exhausted_count_ == RegionCapacity) {
                ticket.phase = ReconstructionPhase::Refused;
                ticket.refusal = RegionRefusal::GenerationExhausted;
                last_refusal_ = ticket.refusal;
                saturating_add(metrics_.region_refusals);
                return true;
            }
            block_reconstruction_ticket(handle, RegionRefusal::RegionCapacity);
            return true;
        }
        if (member_capacity_ - member_count_ < ticket.staged_member_count) {
            block_reconstruction_ticket(handle, RegionRefusal::MemberCapacity);
            return true;
        }

        while (staged_child_handle_valid(ticket.preflight_child) &&
               staged_children_[ticket.preflight_child.slot].target_region_slot !=
                   invalid_pool_index) {
            ticket.preflight_child =
                staged_children_[ticket.preflight_child.slot].next;
        }
        if (staged_child_handle_valid(ticket.preflight_child)) {
            const auto slot = allocate_region_slot();
            if (!slot.has_value()) {
                ticket.phase = ReconstructionPhase::Blocked;
                ticket.refusal = RegionRefusal::RegionCapacity;
                ticket.wait_resource_generation = resource_generation_;
                last_refusal_ = ticket.refusal;
                saturating_add(metrics_.reconstruction_waits);
                saturating_add(metrics_.region_refusals);
                return true;
            }
            auto& child = staged_children_[ticket.preflight_child.slot];
            child.target_region_slot = static_cast<std::uint32_t>(*slot);
            ++ticket.preflight_free_count;
            ticket.preflight_child = child.next;
            return true;
        }

        ticket.phase = ReconstructionPhase::Preparing;
        ticket.prepare_child = ticket.child_head;
        ticket.prepare_member = {};
        ticket.prepared_child_count = 0;
        ticket.prepare_member_index = 0;
        return true;
    }

    bool service_ticket_preparing(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (!staged_child_handle_valid(ticket.prepare_child)) {
            ticket.phase = ReconstructionPhase::CommitReady;
            return true;
        }
        auto& child = staged_children_[ticket.prepare_child.slot];
        if (child.target_region_slot == invalid_pool_index ||
            child.target_region_slot >= RegionCapacity) {
            request_ticket_restart(handle);
            return true;
        }
        const auto slot = static_cast<std::size_t>(child.target_region_slot);

        if (!staged_member_handle_valid(ticket.prepare_member) &&
            ticket.prepare_member_index == 0) {
            auto& region = regions_[slot];
            ++region.generation;
            region.valid = true;
            region.reclaim_pending = false;
            region.on_free_list = false;
            region.batch_serial = ticket.batch_serial;
            region.preparation_ticket = handle;
            region.member_head = {};
            region.member_count = 0;
            region.snapshot = child.snapshot;
            region.snapshot.handle = {
                incarnation_, static_cast<std::uint32_t>(slot), region.generation};
            region.snapshot.publication_serial =
                ticket.publication_base_serial + ticket.prepared_child_count;
            region.subscriber = child.subscriber;
            if (subscriber_handle_valid(region.subscriber)) {
                auto& subscriber = subscribers_[region.subscriber.slot];
                subscriber.kind = SubscriberKind::Prepared;
                subscriber.owner_slot = static_cast<std::uint32_t>(slot);
                subscriber.owner_generation = region.generation;
            }
            child.subscriber = {};
            ticket.prepare_member = child.member_head;
            ticket.prepare_member_index = 1;
            return true;
        }
        if (staged_member_handle_valid(ticket.prepare_member)) {
            const auto staged = staged_members_[ticket.prepare_member.slot];
            auto& region = regions_[slot];
            const auto member = allocate_publication_member(staged.ref);
            if (!member.has_value()) {
                request_ticket_restart(handle);
                return true;
            }
            members_[member->slot].next = region.member_head;
            region.member_head = *member;
            ++region.member_count;
            if (staged.ref.tile < tile_count_ &&
                staged.ref.component < tiles_[staged.ref.tile].component_count)
                tiles_[staged.ref.tile].components[staged.ref.component].assigned_region =
                    region.snapshot.handle;
            ticket.prepare_member = staged.next;
            return true;
        }
        ++ticket.prepared_child_count;
        ticket.prepare_child = child.next;
        ticket.prepare_member = {};
        ticket.prepare_member_index = 0;
        return true;
    }

    void finalize_ticket_commit(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (ticket.batch_serial > committed_batch_serial_)
            committed_batch_serial_ = ticket.batch_serial;
        if (ticket.publication_end_serial > publication_serial_)
            publication_serial_ = ticket.publication_end_serial;
        published_region_count_ += ticket.child_count;
        saturating_add(metrics_.publications, ticket.child_count);
        saturating_add(metrics_.builds_completed, ticket.child_count);
        saturating_add(metrics_.area_total, ticket.staged_area_total);
        if (ticket.staged_area_max > metrics_.area_max)
            metrics_.area_max = ticket.staged_area_max;
        const auto latency = metrics_.work_units >= ticket.started_work
            ? metrics_.work_units - ticket.started_work : 0;
        saturating_add(metrics_.latency_total_units, latency);
        if (latency > metrics_.latency_max_units) metrics_.latency_max_units = latency;
        if (published_region_count_ > metrics_.region_high_water)
            metrics_.region_high_water = published_region_count_;
        saturating_add(metrics_.reconstruction_batches_committed);
        last_refusal_ = RegionRefusal::None;
        append_source_cleanup(ticket.source_head, ticket.source_tail);
        ticket.source_head = {};
        ticket.source_tail = {};
        append_seed_cleanup(ticket.seed_head, ticket.seed_tail);
        ticket.seed_head = {};
        ticket.seed_tail = {};
        append_child_cleanup(ticket.child_head, ticket.child_tail);
        ticket.child_head = {};
        ticket.child_tail = {};
        release_reconstruction_ticket(handle);
    }
    bool service_ticket_blocked(TicketHandle handle) noexcept {
        if (!ticket_handle_valid(handle)) return false;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (ticket.refusal == RegionRefusal::UnknownBoundary &&
            ticket.wait_tile < tile_count_) {
            if (tiles_[ticket.wait_tile].observation_generation != ticket.wait_generation) {
                request_ticket_restart(handle);
                return true;
            }
        } else if (ticket.wait_resource != ReconstructionResource::None &&
                   ticket.wait_resource_generation !=
                       resource_generation(ticket.wait_resource)) {
            request_ticket_restart(handle);
            return true;
        }
        return false;
    }
    bool service_reconstruction_ticket_one() noexcept {
        if (!ticket_handle_valid(reconstruction_queue_head_)) return false;
        const auto handle = reconstruction_queue_head_;
        auto& ticket = reconstruction_tickets_[handle.slot];
        if (ticket.restart_requested &&
            ticket.phase != ReconstructionPhase::RestartCleanup)
            begin_ticket_restart(handle);

        bool did_work = false;
        switch (ticket.phase) {
        case ReconstructionPhase::RestartCleanup:
            did_work = service_ticket_restart_cleanup(handle); break;
        case ReconstructionPhase::Admitting:
            did_work = service_ticket_admission(handle); break;
        case ReconstructionPhase::Building:
            did_work = service_ticket_building(handle); break;
        case ReconstructionPhase::PreflightDependencies:
            did_work = service_ticket_preflight_dependencies(handle); break;
        case ReconstructionPhase::PreflightRegions:
            did_work = service_ticket_preflight_regions(handle); break;
        case ReconstructionPhase::Preparing:
            did_work = service_ticket_preparing(handle); break;
        case ReconstructionPhase::CommitReady:
            finalize_ticket_commit(handle);
            did_work = true;
            break;
        case ReconstructionPhase::Blocked:
            did_work = service_ticket_blocked(handle); break;
        case ReconstructionPhase::Refused:
            did_work = false;
            break;
        }
        if (ticket_handle_valid(handle) && reconstruction_queue_head_ == handle)
            rotate_reconstruction_head();
        return did_work;
    }
    bool cleanup_one_reconstruction_artifact() noexcept {
        if (source_handle_valid(source_cleanup_head_)) {
            auto& source = sources_[source_cleanup_head_.slot];
            if (member_handle_valid(source.member_head)) {
                const auto member = source.member_head;
                source.member_head = members_[member.slot].next;
                release_publication_member(member);
            } else {
                const auto old = source_cleanup_head_;
                source_cleanup_head_ = source.next;
                if (!source_handle_valid(source_cleanup_head_)) source_cleanup_tail_ = {};
                release_source_region(old);
            }
            saturating_add(metrics_.reclamation_units);
            return true;
        }
        if (staged_child_handle_valid(stale_child_cleanup_head_)) {
            auto& child = staged_children_[stale_child_cleanup_head_.slot];
            if (seed_handle_valid(child.frontier_head)) {
                const auto seed = child.frontier_head;
                child.frontier_head = reconstruction_seeds_[seed.slot].next;
                if (!seed_handle_valid(child.frontier_head)) child.frontier_tail = {};
                if (child.frontier_count != 0) --child.frontier_count;
                release_reconstruction_seed(seed);
                saturating_add(metrics_.reclamation_units);
                return true;
            }
            if (staged_member_handle_valid(child.member_head)) {
                const auto member = child.member_head;
                child.member_head = staged_members_[member.slot].next;
                release_staged_member(member);
            } else {
                const auto old = stale_child_cleanup_head_;
                stale_child_cleanup_head_ = child.next;
                if (!staged_child_handle_valid(stale_child_cleanup_head_))
                    stale_child_cleanup_tail_ = {};
                release_staged_child(old);
            }
            saturating_add(metrics_.reclamation_units);
            return true;
        }
        if (seed_handle_valid(stale_seed_cleanup_head_)) {
            const auto old = stale_seed_cleanup_head_;
            stale_seed_cleanup_head_ = reconstruction_seeds_[old.slot].next;
            if (!seed_handle_valid(stale_seed_cleanup_head_)) stale_seed_cleanup_tail_ = {};
            release_reconstruction_seed(old);
            saturating_add(metrics_.reclamation_units);
            return true;
        }
        if (region_reclaim_count_ != 0) {
            const auto cleanup_slot =
                static_cast<std::size_t>(region_reclaim_queue_[region_reclaim_head_]);
            auto& region = regions_[cleanup_slot];
            if (!region.valid && region.reclaim_pending &&
                member_handle_valid(region.member_head)) {
                const auto member = region.member_head;
                region.member_head = members_[member.slot].next;
                if (region.member_count != 0) --region.member_count;
                release_publication_member(member);
                saturating_add(metrics_.reclamation_units);
                return true;
            }
            if (!region.valid && region.reclaim_pending &&
                !member_handle_valid(region.member_head) &&
                !subscriber_handle_valid(region.subscriber)) {
                region.reclaim_pending = false;
                region.reclaim_enqueued = false;
                region.subscriber = {};
                region_reclaim_head_ = (region_reclaim_head_ + 1U) % RegionCapacity;
                --region_reclaim_count_;
                return_region_slot(cleanup_slot);
                saturating_add(metrics_.reclamation_units);
                return true;
            }
        }
        return false;
    }
    bool cleanup_one_any() noexcept {
        if (cleanup_pending_count_ != 0 && cleanup_one_dependency()) {
            saturating_add(metrics_.reclamation_units);
            return true;
        }
        return cleanup_one_reconstruction_artifact();
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

    std::uint64_t incarnation_{}, publication_serial_{}, publication_reservation_serial_{},
                  batch_serial_generation_{}, build_generation_serial_{};
    std::size_t tile_capacity_{}, adjacency_capacity_{}, frontier_capacity_{};
    std::size_t dependency_capacity_{}, subscriber_capacity_{}, member_capacity_{};
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
    TileIndex tile_index_;
    RowIndex row_index_;
    std::array<Region, RegionCapacity> regions_{};
    std::array<std::uint32_t, RegionCapacity> region_free_stack_{};
    std::array<std::uint32_t, RegionCapacity> region_reclaim_queue_{};
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
    TicketHandle digest_owner_ticket_{};
    StagedChildHandle digest_owner_child_{};
    SeedHandle stale_seed_cleanup_head_{}, stale_seed_cleanup_tail_{};
    StagedChildHandle stale_child_cleanup_head_{}, stale_child_cleanup_tail_{};
    SourceHandle source_cleanup_head_{}, source_cleanup_tail_{};
    std::uint64_t change_serial_{}, current_change_serial_{}, reconstruction_serial_{}, digest_generation_serial_{};
    std::uint64_t resource_generation_{1}, region_resource_generation_{1},
                  member_resource_generation_{1}, frontier_resource_generation_{1},
                  dependency_resource_generation_{1}, manifest_resource_generation_{1},
                  committed_batch_serial_{}, service_round_{};
    std::size_t region_free_count_{RegionCapacity};
    std::size_t region_reclaim_head_{}, region_reclaim_tail_{}, region_reclaim_count_{};
    std::size_t region_generation_exhausted_count_{};
    std::size_t member_count_{}, source_count_{}, ticket_count_{}, seed_count_{};
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
        region_free_stack_[i] = static_cast<std::uint32_t>(RegionCapacity - 1U - i);
        regions_[i].on_free_list = true;
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
    metrics_.resource_generation = resource_generation_;
}

} // namespace cybersand::soliding
