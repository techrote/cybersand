#pragma once

#include "cybersand/precision_storage.hpp"
#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

// OBJECTSHARD-001: compact material ownership, never a rigid-body solver.
// The caller is the one exclusive native coordinator. No World or Godot types
// cross this storage interface. Preparation allocates; admitted cell writes and
// geometry rebuilds use already reserved, bounding-box-budgeted storage.
namespace cybersand::object_shard {

inline constexpr std::uint32_t kCapabilityVersion = 1;
inline constexpr std::uint32_t kPolicyVersion = 1;
inline constexpr std::uint32_t kMaximumShards = 64;
inline constexpr std::uint32_t kMaximumArea = 65'536;
inline constexpr std::uint32_t kMaximumShapes = 4'096;
// A live edit is bounded independently of a body's storage area. Geometry and
// connectivity are rebuilt once for this entire owner-local cell set.
inline constexpr std::uint32_t kMaximumEditCells = 4'096;

enum class Outcome : std::uint8_t {
    Accepted, Invalid, Stale, Capacity, Unsupported, Busy, Fenced, Expired,
    Retired, UnknownBoundary, DestinationUnavailable, PendingEvent,
    Quarantined, GenerationExhausted, Anchored, NotResident, Cancelled
};
enum class Phase : std::uint8_t {
    Empty, Prepared, PhysicsReserved, CommittedInactive, TerrainInstalled,
    MaskApplied, ReadyToActivate, Active, Draining, Suspended, Quarantined, Retired
};
enum class Role : std::uint8_t { Empty, Structural, Product, Cargo };

struct Payload {
    Material material{Material::Empty};
    std::uint16_t state_a{};
    std::uint8_t state_b{};
    std::int16_t temperature{200};
    bool operator==(const Payload&) const = default;
};
struct Handle {
    std::uint64_t session{}, id{}, generation{};
    bool operator==(const Handle&) const = default;
};
struct Bounds {
    std::int64_t x{}, y{};
    std::uint16_t width{}, height{};
    bool operator==(const Bounds&) const = default;
    [[nodiscard]] std::size_t area() const noexcept {
        return static_cast<std::size_t>(width) * height;
    }
};
struct Rect {
    std::uint16_t x{}, y{}, width{}, height{};
    bool operator==(const Rect&) const = default;
};
struct Limits {
    std::uint32_t max_shards{3};
    std::uint32_t max_area{4'096};
    std::uint32_t max_total_area{12'288};
    std::uint32_t max_shapes{256};
    bool temperature_storage{true};
    std::int16_t ambient_temperature{200};
};
struct CellSchedule {
    std::uint64_t birth_tick{}, next_due_tick{};
    std::uint32_t incarnation{1};
};
struct MassProperties {
    // Declared gameplay policy: each structural cell and lodged Sand cell has
    // unit mass; products have zero rigid mass. COM is relative to the stable
    // local lattice origin, and square-cell intrinsic inertia is 1/6.
    double mass{}, com_x{}, com_y{}, inertia{};
};
struct Geometry {
    std::uint64_t revision{}, material_revision{}, topology_revision{};
    // shape_digest binds the exact rectangle cover AND unit-mass carrier
    // positions/policy, so unchanged colliders cannot conceal changed cargo COM.
    std::uint64_t mask_digest{}, shape_digest{};
    MassProperties mass{};
    std::vector<Rect> shapes;
    std::uint32_t islands{};
    bool split_pending{};
};
struct Counts {
    std::uint32_t structural{}, products{}, cargo{};
    [[nodiscard]] std::uint32_t total() const noexcept {
        return structural + products + cargo;
    }
};
struct MemoryUsage {
    std::size_t live_bytes{}, retained_bytes{}, peak_bytes{};
    std::uint64_t construction_allocations{}, steady_state_allocations{};
};
struct StructuralEditTiming {
    std::uint64_t mutation_ns{}, geometry_ns{};
};

class Registry;
class GeometryScratch;

class Shard {
public:
    Shard() = default;
    Shard(const Shard&) = delete;
    Shard& operator=(const Shard&) = delete;
    Shard(Shard&&) noexcept = default;
    Shard& operator=(Shard&&) noexcept = default;
    [[nodiscard]] Handle handle() const noexcept { return handle_; }
    [[nodiscard]] std::uint64_t world_incarnation() const noexcept { return world_incarnation_; }
    [[nodiscard]] Bounds bounds() const noexcept { return bounds_; }
    [[nodiscard]] Phase phase() const noexcept { return phase_; }
    [[nodiscard]] bool owns_inventory() const noexcept { return authoritative_; }
    [[nodiscard]] bool chemistry_allowed() const noexcept {
        return authoritative_ && (phase_ == Phase::Active || phase_ == Phase::Draining);
    }
    [[nodiscard]] std::size_t area() const noexcept { return cells_.size(); }
    [[nodiscard]] Counts counts() const noexcept { return counts_; }
    [[nodiscard]] std::uint64_t captured_tick() const noexcept { return captured_tick_; }
    [[nodiscard]] std::uint64_t material_revision() const noexcept { return material_revision_; }
    [[nodiscard]] std::uint64_t topology_revision() const noexcept { return topology_revision_; }
    [[nodiscard]] std::uint64_t applied_physics_revision() const noexcept { return applied_physics_revision_; }
    [[nodiscard]] std::uint64_t geometry_dirty_tick() const noexcept { return geometry_dirty_tick_; }
    [[nodiscard]] bool geometry_dirty() const noexcept { return geometry_dirty_; }
    [[nodiscard]] const Geometry& geometry() const noexcept { return geometry_; }
    [[nodiscard]] Payload payload(std::size_t index) const noexcept;
    [[nodiscard]] Role role(std::size_t index) const noexcept;
    [[nodiscard]] const CellSchedule& schedule(std::size_t index) const noexcept;
    [[nodiscard]] bool occupied(std::size_t index) const noexcept;
    [[nodiscard]] bool structural(std::size_t index) const noexcept;
    [[nodiscard]] bool surface(std::size_t index) const noexcept;
    [[nodiscard]] std::span<const std::uint64_t> occupied_mask() const noexcept { return occupied_mask_; }
    [[nodiscard]] std::span<const std::uint64_t> structural_mask() const noexcept { return structural_mask_; }
    [[nodiscard]] std::uint64_t payload_digest() const noexcept;
    [[nodiscard]] MemoryUsage memory_usage() const noexcept;

    // Semantic payload only: World traversal epoch never becomes shard state.
    // Same-material state/temperature changes preserve cell incarnation unless
    // replace_identity is explicit. A change of material always advances it.
    // Under the exclusive coordinator, preflight the destination before a
    // source debit. With no intervening mutation, set_cell cannot then refuse.
    [[nodiscard]] Outcome validate_cell_write(std::size_t index, Payload value, Role role,
        std::uint64_t semantic_tick, bool replace_identity = false) const noexcept;
    [[nodiscard]] Outcome set_cell(std::size_t index, Payload value, Role role,
        std::uint64_t semantic_tick, bool replace_identity = false) noexcept;
    [[nodiscard]] Outcome set_due(std::size_t index, std::uint64_t next_tick) noexcept;
    [[nodiscard]] Outcome acknowledge_geometry(std::uint64_t revision,
        std::uint64_t mask_digest, std::uint64_t shape_digest) noexcept;

private:
    friend class Registry;
    Outcome prepare(Handle handle, std::uint64_t world, Bounds bounds,
        std::uint64_t captured_tick, const Limits& limits);
    Outcome rebuild_geometry(GeometryScratch& scratch, std::uint64_t tick,
        bool prepared_cover = false) noexcept;
    Outcome build_shape_cover(GeometryScratch& scratch, std::size_t erased_cell,
        std::span<const std::uint8_t> excluded = {}) const noexcept;
    void clear_inventory() noexcept;
    void refresh_surface(std::size_t index) noexcept;
    void refresh_neighbor_surfaces(std::size_t index) noexcept;

    Handle handle_{};
    std::uint64_t world_incarnation_{}, captured_tick_{};
    std::uint64_t material_revision_{}, topology_revision_{}, applied_physics_revision_{};
    std::uint64_t geometry_dirty_tick_{};
    Bounds bounds_{};
    Phase phase_{Phase::Empty};
    bool authoritative_{}, geometry_dirty_{};
    std::int16_t ambient_temperature_{200};
    std::uint32_t max_shapes_{};
    Counts counts_{};
    std::vector<detail::PrecisionStorage> cells_;
    std::vector<Role> roles_;
    std::vector<CellSchedule> schedule_;
    std::vector<std::int16_t> temperatures_;
    std::vector<std::uint64_t> occupied_mask_, structural_mask_, surface_mask_;
    Geometry geometry_{};
    std::size_t peak_bytes_{};
    std::uint64_t construction_allocations_{};
};

// Scratch is shared by the registry's exclusive owner, not duplicated per shard.
class GeometryScratch {
public:
    explicit GeometryScratch(const Limits& limits);
private:
    friend class Shard;
    friend class Registry;
    std::vector<std::uint32_t> queue_;
    std::vector<std::uint8_t> seen_;
    std::vector<std::uint32_t> labels_;
    std::vector<Rect> shapes_;
};

class Registry {
public:
    explicit Registry(Limits limits = {}, std::uint64_t session = 1,
        std::uint64_t world_incarnation = 1);
    Registry(const Registry&) = delete;
    Registry& operator=(const Registry&) = delete;
    Registry(Registry&&) noexcept = default;
    Registry& operator=(Registry&&) noexcept = default;
    [[nodiscard]] const Limits& limits() const noexcept { return limits_; }
    [[nodiscard]] std::uint64_t session() const noexcept { return session_; }
    [[nodiscard]] std::uint64_t world_incarnation() const noexcept { return world_incarnation_; }
    [[nodiscard]] std::span<const Shard> shards() const noexcept { return shards_; }
    [[nodiscard]] Shard* find(Handle handle) noexcept;
    [[nodiscard]] const Shard* find(Handle handle) const noexcept;
    [[nodiscard]] Outcome prepare(Bounds bounds, std::uint64_t captured_tick, Handle& result);
    [[nodiscard]] Outcome finish_preparation(Handle handle) noexcept;
    // Stage one complete disconnected island, with nearest-island product and
    // cargo carriers, without taking inventory from its current owner. The
    // largest island remains with the parent. Captured clocks and lattice
    // coordinates survive the later exclusive parent-to-child transfer.
    [[nodiscard]] Outcome prepare_fragment(Handle parent, std::uint64_t semantic_tick,
        Handle& child);
    [[nodiscard]] Outcome commit_fragment(Handle parent, Handle child,
        std::uint64_t semantic_tick) noexcept;
    // Preflight the exact post-erase cover before changing material inventory.
    // Expected capacity refusal leaves payload, clocks and geometry unchanged.
    [[nodiscard]] Outcome erase_structural(Handle handle, std::size_t cell,
        std::uint64_t semantic_tick) noexcept;
    [[nodiscard]] Outcome erase_structural_batch(Handle handle,
        std::span<const std::uint32_t> cells, std::uint64_t semantic_tick,
        StructuralEditTiming* timing = nullptr) noexcept;
    [[nodiscard]] Outcome reserve_physics(Handle handle) noexcept;
    [[nodiscard]] Outcome commit(Handle handle) noexcept;
    // Coordinator validates real installed terrain/mask/body receipts first.
    // Storage enforces order but cannot prove external Godot calls occurred.
    [[nodiscard]] Outcome advance(Handle handle, Phase expected, Phase next) noexcept;
    [[nodiscard]] Outcome cancel_precommit(Handle handle) noexcept;
    // Unexpected exclusive commit failure: retain only the exact source cells
    // actually debited before failure. All undebited staging ceases to be
    // inventory. The coordinator supplies its preallocated successful-prefix
    // ledger; no World or external callback is consulted here.
    [[nodiscard]] Outcome quarantine_partial_commit(Handle handle,
        std::span<const std::uint32_t> actually_debited_local_cells) noexcept;
    [[nodiscard]] Outcome quarantine(Handle handle) noexcept;
    [[nodiscard]] Outcome retire(Handle handle) noexcept;
    [[nodiscard]] Outcome rebuild_geometry(Handle handle, std::uint64_t semantic_tick) noexcept;
    [[nodiscard]] Counts inventory_counts() const noexcept;
    [[nodiscard]] MemoryUsage memory_usage() const noexcept;
    // Explicit whole-session disposal. Returns exact disposed role counts; old
    // handles remain invalid even when their roster slots are reused.
    [[nodiscard]] Outcome reset(std::uint64_t new_session,
        std::uint64_t new_world_incarnation, Counts& disposed) noexcept;

private:
    Limits limits_{};
    std::uint64_t session_{}, world_incarnation_{}, next_id_{};
    std::vector<Shard> shards_;
    std::vector<std::uint64_t> slot_generations_;
    GeometryScratch scratch_;
    std::size_t peak_retained_bytes_{};
    std::uint64_t construction_allocations_{5};
};

[[nodiscard]] const char* outcome_name(Outcome value) noexcept;
[[nodiscard]] const char* phase_name(Phase value) noexcept;
[[nodiscard]] bool valid_bounds(Bounds bounds) noexcept;
[[nodiscard]] constexpr bool structural_material_supported(Material material) noexcept {
    // Explicitly admitted inert architecture and the continuing Wood lifecycle.
    // Do not infer admission from hard-surface appearance or MaterialState.
    switch (material) {
    case Material::Wood: case Material::Wall: case Material::RedBrick:
    case Material::Concrete: case Material::GraniteBlock:
    case Material::IndustrialBrick: case Material::ReinforcedConcrete:
    case Material::SteelPlate: case Material::PaintedSteel:
    case Material::CorrugatedSteel: case Material::SteelGrating:
    case Material::CeramicTile: case Material::ChemicalGlass: case Material::DarkGlass:
        return true;
    default: return false;
    }
}

} // namespace cybersand::object_shard
