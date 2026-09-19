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
    TileCapacity, SpatialIndexCapacity, ComponentCapacity, AdjacencyCapacity, FrontierCapacity, RegionCapacity,
    UnknownBoundary, RevisionChanged, SourceFailure, GenerationExhausted
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
                            std::size_t frontier_capacity = FrontierCapacity);
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
            for (std::size_t i = 0; i < tile_count_; ++i)
                if (overlaps(tiles_[i].bounds, bounds))
                    return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
            slot = first_free_tile();
            tiles_[slot].used = true;
            tiles_[slot].key = key;
            tiles_[slot].bounds = bounds;
            tiles_[slot].neighbours.fill(region_detail::invalid_index);
            ++tile_count_;
            link_faces(slot);
        } else {
            if (tiles_[slot].bounds != bounds)
                return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
            if (revision < tiles_[slot].revision) return RegionOutcome::Stale;
        }
        retire_for_tile_and_faces(slot);
        cancel_related_build(slot);
        clear_deferred_for_tile_and_faces(slot);
        remove_adjacencies(slot);
        auto& tile = tiles_[slot];
        tile.revision = revision;
        tile.has_payload = false;
        tile.ready = false;
        tile.component_count = 0;
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
            for (std::size_t i = 0; i < tile_count_; ++i)
                if (overlaps(tiles_[i].bounds, input.bounds))
                    return remember(RegionOutcome::Invalid, RegionRefusal::InvalidInput);
            slot = first_free_tile();
            tiles_[slot].used = true; tiles_[slot].key = input.key; tiles_[slot].bounds = input.bounds;
            tiles_[slot].neighbours.fill(region_detail::invalid_index);
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
        retire_for_tile_and_faces(slot); cancel_related_build(slot); clear_deferred_for_tile_and_faces(slot);
        work_possible_ = true;
        remove_adjacencies(slot);
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
        retire_for_tile_and_faces(slot); cancel_related_build(slot); clear_deferred_for_tile_and_faces(slot);
        remove_adjacencies(slot);
        auto& tile = tiles_[slot]; tile.revision = next_revision; tile.has_payload = false;
        tile.ready = false; tile.component_count = 0; tile.refusal = RegionRefusal::SignalIncomplete;
        work_possible_ = true;
        return remember(RegionOutcome::Accepted, RegionRefusal::None);
    }

    // One unit is one seed probe, component visit, dependency validation, or publication.
    // Local <=32x32 extraction and face rebuilding are separately bounded and counted.
    std::size_t advance(std::size_t budget) noexcept {
        if (unavailable() || incarnation_ == 0 || !work_possible_) return 0;
        std::size_t used = 0;
        while (used < budget) {
            if (build_.phase == Phase::Idle) begin_seek();
            if (build_.phase == Phase::Seeking) {
                if (!seek_one()) {
                    if (!build_.seed_found) { reset_build(); work_possible_ = false; break; }
                    begin_traversal(); continue;
                }
                consume(used); continue;
            }
            if (build_.phase == Phase::Traversing) {
                if (build_.frontier_count == 0) { build_.phase = Phase::Validating; continue; }
                const auto ref = pop_frontier_min();
                if (!process_component(ref)) refuse_build(build_.failure);
                consume(used); continue;
            }
            if (build_.validation_cursor < tile_count_) {
                const auto index = build_.validation_cursor++;
                if (build_.dependencies[index] && (!tiles_[index].ready || tiles_[index].revision != build_.revisions[index])) {
                    refuse_build(RegionRefusal::RevisionChanged); saturating_add(metrics_.builds_restarted);
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
        std::size_t count = 0;
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
    [[nodiscard]] static constexpr std::size_t publication_capacity() noexcept { return RegionCapacity; }
    [[nodiscard]] static constexpr std::size_t maximum_tile_cells() noexcept { return MaximumTileCells; }
    [[nodiscard]] static constexpr std::size_t components_per_tile() noexcept { return ComponentsPerTile; }
    [[nodiscard]] static constexpr std::size_t boundary_slots_per_tile() noexcept { return 128; }
    [[nodiscard]] std::size_t storage_bytes() const noexcept {
        return sizeof(SettledRegions) +
               tile_capacity_ * sizeof(Tile) +
               adjacency_capacity_ * sizeof(Adjacency) +
               frontier_capacity_ * 3U * sizeof(ComponentRef) +
               tile_capacity_ * (sizeof(bool) + sizeof(std::uint64_t)) +
               tile_capacity_ * (sizeof(bool) + sizeof(std::size_t));
    }

private:
    struct ComponentRef { std::uint16_t tile{}, component{}; bool operator==(const ComponentRef&) const = default; };
    struct Component {
        RegionComponentKey key{};
        std::uint64_t area{}, digest{1469598103934665603ULL};
        std::int64_t min_x{}, min_y{}, max_x{}, max_y{};
        SettledRegionHandle assigned_region{};
        bool used{}, in_build{}, deferred{};
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
        std::size_t area{}, component_count{};
        RegionRefusal refusal{RegionRefusal::None};
        bool used{}, has_payload{}, ready{};
    };
    struct Adjacency { ComponentRef a{}, b{}; };
    struct Region { SettledRegionSnapshot snapshot{}; std::uint64_t generation{}; bool valid{}; };
    enum class Phase : std::uint8_t { Idle, Seeking, Traversing, Validating };
    struct Build {
        Build(std::size_t frontier_capacity, std::size_t tile_capacity)
            : frontier(std::make_unique<ComponentRef[]>(frontier_capacity)),
              seen(std::make_unique<ComponentRef[]>(frontier_capacity)),
              members(std::make_unique<ComponentRef[]>(frontier_capacity)),
              dependencies(std::make_unique<bool[]>(tile_capacity)),
              revisions(std::make_unique<std::uint64_t[]>(tile_capacity)) {}
        Phase phase{Phase::Idle};
        std::size_t seek_flat{}, frontier_count{}, seen_count{}, member_count{}, validation_cursor{};
        ComponentRef best{}, seed{};
        bool seed_found{};
        RegionRefusal failure{RegionRefusal::None};
        std::unique_ptr<ComponentRef[]> frontier, seen, members;
        std::unique_ptr<bool[]> dependencies;
        std::unique_ptr<std::uint64_t[]> revisions;
        std::uint64_t started_work{};
    };

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
    static std::int64_t max_x(const DiscoveryBounds& bounds) noexcept { return bounds.x + bounds.width - 1U; }
    static std::int64_t max_y(const DiscoveryBounds& bounds) noexcept { return bounds.y + bounds.height - 1U; }
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
    void link_faces(std::size_t slot) noexcept {
        const auto connect = [this](std::size_t from, std::uint8_t from_direction,
                                    std::size_t to, std::uint8_t to_direction,
                                    std::int64_t first, std::int64_t last, bool horizontal) {
            for (auto coordinate = first;; ++coordinate) {
                const auto fx = horizontal ? coordinate : tiles_[from].bounds.x;
                const auto fy = horizontal ? tiles_[from].bounds.y : coordinate;
                const auto tx = horizontal ? coordinate : tiles_[to].bounds.x;
                const auto ty = horizontal ? tiles_[to].bounds.y : coordinate;
                tiles_[from].neighbours[boundary_index(tiles_[from].bounds, from_direction, fx, fy)] =
                    static_cast<std::uint16_t>(to);
                tiles_[to].neighbours[boundary_index(tiles_[to].bounds, to_direction, tx, ty)] =
                    static_cast<std::uint16_t>(from);
                if (coordinate == last) break;
            }
        };
        for (std::size_t other = 0; other < tile_count_; ++other) {
            if (other == slot) continue;
            saturating_add(metrics_.tile_lookup_probes);
            const auto& a = tiles_[slot].bounds;
            const auto& b = tiles_[other].bounds;
            if (max_x(a) != std::numeric_limits<std::int64_t>::max() && max_x(a) + 1 == b.x &&
                a.y <= max_y(b) && b.y <= max_y(a)) {
                connect(slot, region_detail::east, other, region_detail::west,
                        std::max(a.y, b.y), std::min(max_y(a), max_y(b)), false);
            } else if (max_x(b) != std::numeric_limits<std::int64_t>::max() && max_x(b) + 1 == a.x &&
                       a.y <= max_y(b) && b.y <= max_y(a)) {
                connect(slot, region_detail::west, other, region_detail::east,
                        std::max(a.y, b.y), std::min(max_y(a), max_y(b)), false);
            } else if (max_y(a) != std::numeric_limits<std::int64_t>::max() && max_y(a) + 1 == b.y &&
                       a.x <= max_x(b) && b.x <= max_x(a)) {
                connect(slot, region_detail::south, other, region_detail::north,
                        std::max(a.x, b.x), std::min(max_x(a), max_x(b)), true);
            } else if (max_y(b) != std::numeric_limits<std::int64_t>::max() && max_y(b) + 1 == a.y &&
                       a.x <= max_x(b) && b.x <= max_x(a)) {
                connect(slot, region_detail::north, other, region_detail::south,
                        std::max(a.x, b.x), std::min(max_x(a), max_x(b)), true);
            }
        }
    }
    bool valid_input(const RegionTileInput& input) const noexcept {
        const auto area = static_cast<std::uint64_t>(input.bounds.width) * input.bounds.height;
        return input.revision != 0 && valid_bounds(input.bounds) && area <= MaximumTileCells &&
               input.cells.size() == area && (input.sealed_edges & 0xf0U) == 0;
    }
    std::size_t find_tile(RegionTileKey key) const noexcept {
        for (std::size_t i = 0; i < tile_count_; ++i) if (tiles_[i].key == key) return i;
        return tile_capacity_;
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
        tile.has_payload = true; tile.ready = false; tile.component_count = 0; tile.refusal = RegionRefusal::None;
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
        tile.ready = true; saturating_add(metrics_.components, tile.component_count);
        return remember(RegionOutcome::Accepted, RegionRefusal::None);
    }
    void remove_adjacencies(std::size_t slot) noexcept {
        std::size_t write = 0;
        for (std::size_t i = 0; i < adjacency_count_; ++i)
            if (adjacencies_[i].a.tile != slot && adjacencies_[i].b.tile != slot)
                adjacencies_[write++] = adjacencies_[i];
        adjacency_count_ = write;
    }
    bool adjacency_exists(ComponentRef a, ComponentRef b) const noexcept {
        for (std::size_t i = 0; i < adjacency_count_; ++i)
            if ((adjacencies_[i].a == a && adjacencies_[i].b == b) ||
                (adjacencies_[i].a == b && adjacencies_[i].b == a)) return true;
        return false;
    }
    bool add_adjacency(ComponentRef a, ComponentRef b) noexcept {
        if (adjacency_exists(a, b)) return true;
        if (adjacency_count_ == adjacency_capacity_) { saturating_add(metrics_.adjacency_refusals); return false; }
        adjacencies_[adjacency_count_++] = {a, b}; saturating_add(metrics_.adjacency_edges); return true;
    }
    bool compare_face(std::size_t left_slot, std::size_t right_slot) noexcept {
        const auto& a = tiles_[left_slot]; const auto& b = tiles_[right_slot];
        if (!a.ready || !b.ready || !face_neighbours(a.bounds, b.bounds)) return true;
        auto compare = [&](std::size_t ai, std::size_t bi) {
            saturating_add(metrics_.boundary_comparisons);
            const auto ac = a.labels[ai], bc = b.labels[bi];
            if (ac == region_detail::invalid_index || bc == region_detail::invalid_index ||
                !(a.components[ac].key == b.components[bc].key)) return true;
            return add_adjacency({static_cast<std::uint16_t>(left_slot), ac},
                                 {static_cast<std::uint16_t>(right_slot), bc});
        };
        if (max_x(a.bounds) != std::numeric_limits<std::int64_t>::max() && max_x(a.bounds) + 1 == b.bounds.x) {
            const auto lo = a.bounds.y > b.bounds.y ? a.bounds.y : b.bounds.y;
            const auto hi = max_y(a.bounds) < max_y(b.bounds) ? max_y(a.bounds) : max_y(b.bounds);
            for (auto y = lo;; ++y) {
                const auto ai = static_cast<std::size_t>(y - a.bounds.y) * a.bounds.width + a.bounds.width - 1U;
                const auto bi = static_cast<std::size_t>(y - b.bounds.y) * b.bounds.width;
                if (!compare(ai, bi)) return false;
                if (y == hi) break;
            }
        } else if (max_x(b.bounds) != std::numeric_limits<std::int64_t>::max() && max_x(b.bounds) + 1 == a.bounds.x) {
            return compare_face(right_slot, left_slot);
        } else if (max_y(a.bounds) != std::numeric_limits<std::int64_t>::max() && max_y(a.bounds) + 1 == b.bounds.y) {
            const auto lo = a.bounds.x > b.bounds.x ? a.bounds.x : b.bounds.x;
            const auto hi = max_x(a.bounds) < max_x(b.bounds) ? max_x(a.bounds) : max_x(b.bounds);
            for (auto x = lo;; ++x) {
                const auto ai = (a.bounds.height - 1U) * a.bounds.width + static_cast<std::size_t>(x - a.bounds.x);
                const auto bi = static_cast<std::size_t>(x - b.bounds.x);
                if (!compare(ai, bi)) return false;
                if (x == hi) break;
            }
        } else if (max_y(b.bounds) != std::numeric_limits<std::int64_t>::max() && max_y(b.bounds) + 1 == a.bounds.y) {
            return compare_face(right_slot, left_slot);
        }
        return true;
    }
    bool rebuild_adjacencies(std::size_t slot) noexcept {
        for (std::size_t other = 0; other < tile_count_; ++other)
            if (other != slot && face_neighbours(tiles_[slot].bounds, tiles_[other].bounds) &&
                !compare_face(slot, other)) return false;
        return true;
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
        build_.validation_cursor = 0;
        build_.best = {};
        build_.seed = {};
        build_.seed_found = false;
        build_.failure = RegionRefusal::None;
        std::fill_n(build_.dependencies.get(), tile_capacity_, false);
        std::fill_n(build_.revisions.get(), tile_capacity_, 0);
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
        if (!push(build_.seed)) { refuse_build(RegionRefusal::FrontierCapacity); return; }
        saturating_add(metrics_.builds_started);
    }
    bool push(ComponentRef ref) noexcept {
        auto& component = tiles_[ref.tile].components[ref.component];
        if (component.in_build) return true;
        if (build_.frontier_count == frontier_capacity_ || build_.seen_count == frontier_capacity_) {
            build_.failure = RegionRefusal::FrontierCapacity; return false;
        }
        component.in_build = true;
        build_.frontier[build_.frontier_count++] = ref;
        build_.seen[build_.seen_count++] = ref;
        if (build_.frontier_count > metrics_.frontier_high_water) metrics_.frontier_high_water = build_.frontier_count;
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
    bool check_outside(std::size_t tile_index, std::uint8_t direction,
                       std::int64_t x, std::int64_t y) noexcept {
        const auto neighbour = tiles_[tile_index].neighbours[
            boundary_index(tiles_[tile_index].bounds, direction, x, y)];
        if (neighbour == region_detail::invalid_index)
            return (tiles_[tile_index].sealed_edges & direction) != 0;
        build_.dependencies[neighbour] = true;
        build_.revisions[neighbour] = tiles_[neighbour].revision;
        return tiles_[neighbour].ready;
    }
    bool boundary_complete(ComponentRef ref) noexcept {
        const auto& tile = tiles_[ref.tile];
        for (std::size_t index = 0; index < tile.area; ++index) if (tile.labels[index] == ref.component) {
            const auto x = index % tile.bounds.width, y = index / tile.bounds.width;
            const auto wx = tile.bounds.x + static_cast<std::int64_t>(x);
            const auto wy = tile.bounds.y + static_cast<std::int64_t>(y);
            if (y == 0) { saturating_add(metrics_.boundary_cell_checks); if (!check_outside(ref.tile, region_detail::north, wx, wy)) return false; }
            if (x + 1U == tile.bounds.width) { saturating_add(metrics_.boundary_cell_checks); if (!check_outside(ref.tile, region_detail::east, wx, wy)) return false; }
            if (y + 1U == tile.bounds.height) { saturating_add(metrics_.boundary_cell_checks); if (!check_outside(ref.tile, region_detail::south, wx, wy)) return false; }
            if (x == 0) { saturating_add(metrics_.boundary_cell_checks); if (!check_outside(ref.tile, region_detail::west, wx, wy)) return false; }
        }
        return true;
    }
    bool process_component(ComponentRef ref) noexcept {
        auto& component = tiles_[ref.tile].components[ref.component];
        if (!tiles_[ref.tile].ready || assigned(component) || component.deferred ||
            !(component.key == tiles_[build_.seed.tile].components[build_.seed.component].key)) {
            build_.failure = RegionRefusal::RevisionChanged; return false;
        }
        build_.dependencies[ref.tile] = true; build_.revisions[ref.tile] = tiles_[ref.tile].revision;
        if (!boundary_complete(ref)) { build_.failure = RegionRefusal::UnknownBoundary; return false; }
        insert_member(ref);
        for (std::size_t i = 0; i < adjacency_count_; ++i) {
            std::optional<ComponentRef> neighbour;
            if (adjacencies_[i].a == ref) neighbour = adjacencies_[i].b;
            else if (adjacencies_[i].b == ref) neighbour = adjacencies_[i].a;
            if (neighbour.has_value() && !push(*neighbour)) return false;
        }
        return true;
    }
    void clear_build_marks() noexcept {
        for (std::size_t i = 0; i < build_.seen_count; ++i)
            tiles_[build_.seen[i].tile].components[build_.seen[i].component].in_build = false;
    }
    void refuse_build(RegionRefusal reason) noexcept {
        for (std::size_t i = 0; i < build_.seen_count; ++i) {
            auto& component = tiles_[build_.seen[i].tile].components[build_.seen[i].component];
            component.in_build = false;
            if (!component.deferred) {
                component.deferred = true;
                ++deferred_component_count_;
            }
        }
        last_refusal_ = reason; saturating_add(metrics_.builds_refused);
        if (reason == RegionRefusal::FrontierCapacity) saturating_add(metrics_.frontier_refusals);
        if (reason == RegionRefusal::RegionCapacity || reason == RegionRefusal::GenerationExhausted)
            saturating_add(metrics_.region_refusals);
        reset_build();
    }
    void cancel_build(bool restarted) noexcept {
        if (build_.phase == Phase::Idle) return;
        clear_build_marks(); reset_build();
        if (restarted) saturating_add(metrics_.builds_restarted);
    }
    bool build_related(std::size_t slot) const noexcept {
        for (std::size_t i = 0; i < build_.seen_count; ++i) {
            const auto member_slot = build_.seen[i].tile;
            if (member_slot == slot || face_neighbours(tiles_[member_slot].bounds, tiles_[slot].bounds)) return true;
        }
        for (std::size_t i = 0; i < tile_count_; ++i)
            if (build_.dependencies[i] && (i == slot || face_neighbours(tiles_[i].bounds, tiles_[slot].bounds))) return true;
        return false;
    }
    void cancel_related_build(std::size_t slot) noexcept {
        if (build_.phase == Phase::Idle) return;
        // A seek may already have inspected this tile, or an earlier canonical
        // position may have gained a candidate. Its best seed is not valid until
        // the complete canonical scan witnesses one stable tile set.
        if (build_.phase == Phase::Seeking || build_related(slot)) cancel_build(true);
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
            for (const auto& region : regions_) if (region.valid || region.generation < GenerationLimit) exhausted = false;
            refuse_build(exhausted ? RegionRefusal::GenerationExhausted : RegionRefusal::RegionCapacity);
            return;
        }
        if (publication_serial_ == PublicationLimit) { refuse_build(RegionRefusal::GenerationExhausted); return; }
        auto& region = regions_[*slot]; ++region.generation; region.valid = true;
        ++published_region_count_;
        auto& out = region.snapshot; out = SettledRegionSnapshot{};
        out.handle = {incarnation_, static_cast<std::uint32_t>(*slot), region.generation};
        out.key = tiles_[build_.seed.tile].components[build_.seed.component].key;
        out.complete = true; out.publication_serial = ++publication_serial_;
        std::uint64_t members = 1469598103934665603ULL;
        std::fill_n(member_tiles_scratch_.get(), tile_capacity_, false);
        auto* member_tiles = member_tiles_scratch_.get();
        auto* dependency_slots = dependency_slots_scratch_.get();
        std::size_t dependency_count = 0;
        for (std::size_t i = 0; i < build_.member_count; ++i) {
            const auto ref = build_.members[i]; auto& component = tiles_[ref.tile].components[ref.component];
            component.assigned_region = out.handle; component.in_build = false; member_tiles[ref.tile] = true;
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
        for (std::size_t i = 0; i < tile_count_; ++i) {
            if (member_tiles[i]) ++out.tile_count;
            if (build_.dependencies[i]) {
                ++out.dependency_tile_count;
                auto at = dependency_count;
                while (at != 0 && region_detail::less(tiles_[i].key, tiles_[dependency_slots[at - 1]].key)) {
                    dependency_slots[at] = dependency_slots[at - 1];
                    --at;
                }
                dependency_slots[at] = i;
                ++dependency_count;
            }
        }
        std::uint64_t dependencies = 1469598103934665603ULL;
        for (std::size_t i = 0; i < dependency_count; ++i) {
            const auto dependency = dependency_slots[i];
            region_detail::hash_value(dependencies,
                region_detail::tile_hash(tiles_[dependency].key, build_.revisions[dependency]));
        }
        out.member_digest = members; out.dependency_digest = dependencies;
        saturating_add(metrics_.builds_completed); saturating_add(metrics_.publications);
        saturating_add(metrics_.area_total, out.area); if (out.area > metrics_.area_max) metrics_.area_max = out.area;
        const auto latency = metrics_.work_units - build_.started_work;
        saturating_add(metrics_.latency_total_units, latency);
        if (latency > metrics_.latency_max_units) metrics_.latency_max_units = latency;
        const auto count = region_count(); if (count > metrics_.region_high_water) metrics_.region_high_water = count;
        reset_build();
    }
    void retire_handle(SettledRegionHandle handle) noexcept {
        if (handle.world_incarnation != incarnation_ || handle.slot >= RegionCapacity) return;
        auto& region = regions_[handle.slot];
        if (region.valid && region.generation == handle.generation) {
            region.valid = false;
            --published_region_count_;
            saturating_add(metrics_.invalidated_regions);
        }
    }
    void retire_for_tile_and_faces(std::size_t slot) noexcept {
        if (published_region_count_ == 0) return;
        for (std::size_t tile_index = 0; tile_index < tile_count_; ++tile_index) {
            if (tile_index != slot &&
                !face_neighbours(tiles_[tile_index].bounds, tiles_[slot].bounds)) continue;
            if (tile_index != slot) saturating_add(metrics_.facing_invalidation_fanout);
            for (std::size_t component = 0; component < tiles_[tile_index].component_count; ++component)
                retire_handle(tiles_[tile_index].components[component].assigned_region);
        }
    }
    void retire_all_regions() noexcept {
        for (auto& region : regions_) if (region.valid) {
            region.valid = false; saturating_add(metrics_.invalidated_regions);
        }
        published_region_count_ = 0;
    }
    void clear_deferred_for_tile_and_faces(std::size_t slot) noexcept {
        if (deferred_component_count_ == 0) return;
        for (std::size_t tile_index = 0; tile_index < tile_count_; ++tile_index) {
            if (tile_index != slot &&
                !face_neighbours(tiles_[tile_index].bounds, tiles_[slot].bounds)) continue;
            for (auto& component : tiles_[tile_index].components) if (component.deferred) {
                component.deferred = false;
                --deferred_component_count_;
            }
        }
    }

    static std::size_t checked_capacity(std::size_t value, std::size_t maximum,
                                        const char* message) {
        if (value == 0 || value > maximum) throw std::invalid_argument(message);
        return value;
    }

    std::uint64_t incarnation_{}, publication_serial_{};
    std::size_t tile_capacity_{}, adjacency_capacity_{}, frontier_capacity_{};
    std::unique_ptr<Tile[]> tiles_;
    std::unique_ptr<Adjacency[]> adjacencies_;
    std::array<Region, RegionCapacity> regions_{};
    Build build_;
    std::unique_ptr<bool[]> member_tiles_scratch_;
    std::unique_ptr<std::size_t[]> dependency_slots_scratch_;
    SettledRegionMetrics metrics_{};
    RegionRefusal last_refusal_{RegionRefusal::None};
    std::size_t tile_count_{}, adjacency_count_{}, published_region_count_{}, deferred_component_count_{};
    bool halted_{}, coverage_capacity_exhausted_{}, work_possible_{};
};

template<std::size_t TileCapacity, std::size_t MaximumTileCells,
         std::size_t ComponentsPerTile, std::size_t AdjacencyCapacity,
         std::size_t RegionCapacity, std::size_t FrontierCapacity,
         std::uint64_t GenerationLimit, std::uint64_t PublicationLimit>
SettledRegions<TileCapacity, MaximumTileCells, ComponentsPerTile, AdjacencyCapacity,
               RegionCapacity, FrontierCapacity, GenerationLimit, PublicationLimit>::SettledRegions(
    std::uint64_t incarnation, std::size_t tile_capacity,
    std::size_t adjacency_capacity, std::size_t frontier_capacity)
    : incarnation_(incarnation),
      tile_capacity_(checked_capacity(tile_capacity, TileCapacity,
          "settled region runtime tile capacity is unsupported")),
      adjacency_capacity_(checked_capacity(adjacency_capacity, AdjacencyCapacity,
          "settled region runtime adjacency capacity is unsupported")),
      frontier_capacity_(checked_capacity(frontier_capacity, FrontierCapacity,
          "settled region runtime frontier capacity is unsupported")),
      tiles_(std::make_unique<Tile[]>(tile_capacity_)),
      adjacencies_(std::make_unique<Adjacency[]>(adjacency_capacity_)),
      build_(frontier_capacity_, tile_capacity_),
      member_tiles_scratch_(std::make_unique<bool[]>(tile_capacity_)),
      dependency_slots_scratch_(std::make_unique<std::size_t[]>(tile_capacity_)) {}

} // namespace cybersand::soliding
