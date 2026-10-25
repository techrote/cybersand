#pragma once

#include "cybersand/material.hpp"
#include "cybersand/physics_diagnostics.hpp"
#include "cybersand/interaction_policy.hpp"
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/liquid_comparison.hpp"
#include "cybersand/pressure_flow.hpp"
#include "cybersand/inertial_cellular.hpp"
#include "cybersand/pressure_optimization.hpp"
#include "cybersand/quantity_ledger.hpp"
#include "cybersand/transport_policy.hpp"
#include "cybersand/scheduler_geometry.hpp"
#include "cybersand/settled_world_discovery.hpp"
#include "cybersand/water_experiment_policy.hpp"
#include "cybersand/water_cellular_yield.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <unordered_map>
#include <vector>

namespace cybersand {

class RenderSnapshotExchange;
class PreparedWorldBuilder;

enum class SimulationBackend : std::uint8_t {
    SerialInPlace = 0,
    PhasedInPlace = 1,
    Buffered = 2,
};

struct WorldConfig {
    std::int32_t chunk_size = 128;
    std::uint32_t sleep_after_quiet_ticks = 3;
    std::int16_t ambient_temperature = 200;
    std::size_t initial_chunk_reserve = 64;
    SimulationBackend backend = SimulationBackend::PhasedInPlace;
    std::int32_t activity_block_size = 32;
    std::int32_t scheduling_core_size = 64;
    std::int32_t maximum_rule_radius = 2;
    std::uint32_t worker_threads = 1;
    std::size_t parallel_job_threshold = 8;
    std::size_t active_core_capacity = 4'096;
    std::size_t active_chunk_capacity = 4'096;
    std::size_t maximum_chunk_count = 4'096;
    std::size_t deferred_event_capacity = 1'024;
    std::int32_t maximum_explosion_radius = 64;
    bool settled_discovery_enabled = false;
    std::size_t settled_discovery_tile_capacity = 4'096;
    std::size_t settled_discovery_tick_budget = 0;
    bool settled_region_connectivity_enabled = false;
    std::size_t settled_region_tick_budget = 0;
    PhysicsDiagnosticConfig physics_diagnostics{};
    InteractionPolicy interaction_policy{};
    TransportPolicy transport_policy{};
    WaterExperimentPolicy water_experiment_policy{};
    // Immutable per-World/per-material liquid solver policy (LCB-001 #200).
    // Defaults and source-qualified candidate cells are admitted; every other
    // assignment is refused at construction and never reaches a kernel.
    LiquidSolverPolicy liquid_solver_policy{};
    PressureOptimizationConfig pressure_optimization{};
};

struct ChunkCoord {
    std::int64_t x = 0;
    std::int64_t y = 0;

    [[nodiscard]] friend constexpr bool operator==(const ChunkCoord&, const ChunkCoord&) = default;
    [[nodiscard]] friend constexpr auto operator<=>(const ChunkCoord&, const ChunkCoord&) = default;
};

struct ChunkCoordHash {
    [[nodiscard]] std::size_t operator()(const ChunkCoord& coord) const noexcept;
};

enum class ChunkInstallOutcome : std::uint8_t {
    Installed,
    AlreadyResident,
    InvalidPayload,
    CoordinateOverflow,
    CapacityFull,
    TransientOccupancy,
    WorldFailed,
    TickInProgress,
};

struct RectI64 {
    std::int64_t x = 0;
    std::int64_t y = 0;
    std::int64_t width = 0;
    std::int64_t height = 0;
};

// Inclusive scheduling-core coordinates. Null coverage means unrestricted;
// requested coverage is immediate, while applied coverage latches at tick entry.
struct SimulationCoreRange {
    std::int64_t min_x, min_y, max_x, max_y;
    friend bool operator==(const SimulationCoreRange&, const SimulationCoreRange&) = default;
};

struct TickStats {
    std::uint64_t tick = 0;
    std::uint64_t visited_cells = 0;
    std::uint64_t moved_cells = 0;
    std::uint64_t active_chunks_before = 0;
    std::uint64_t active_chunks_after = 0;
    std::uint64_t active_blocks_after = 0; // resident active 32-cell activity blocks, including excluded work
    std::uint64_t dirty_chunks = 0;
    std::uint64_t scheduled_cores = 0;
    std::array<std::uint64_t, SchedulerGeometry::kPhaseCount> phase_jobs{};
    std::uint64_t chunk_allocations = 0;
    std::uint64_t temperature_field_allocations = 0;
    std::uint64_t deferred_events = 0;
    // Maximum distinct pool workers that executed tasks in one tick dispatch;
    // configured workers and actual participation are separate observations.
    std::uint32_t worker_threads_observed = 0;
};

struct DirtyChunk {
    ChunkCoord chunk;
    RectI64 local_rect;
};

// Optional, serialized player control over ordinary native Sand/Water cells.
// A field selects material by location/type, not by a hidden particle identity.
// It never creates material, exchanges with occupied cells or changes a kernel.
struct PlayerMaterialFieldCommand {
    static constexpr std::int32_t kRadius = 32;
    static constexpr std::size_t kMaximumParcels = 512;
    static constexpr std::uint32_t kMaximumStepsPerParcel = 4;
    std::int64_t center_x = 0;
    std::int64_t center_y = 0;
    double move_x = 0.0;
    double move_y = 0.0;
    Material material = Material::Sand;
    // 0: cohere/hover; 1: surge; 2: dry spread/liquid squeeze; 3: gather.
    std::uint32_t mode = 0;
    std::uint64_t phase = 0;
    RectI64 bounds{0, 0, 1024, 1024};
};

enum class PlayerMaterialFieldOutcome : std::uint8_t {
    Applied,
    InvalidCommand,
    WorldFailed,
    TickInProgress,
};

struct PlayerMaterialFieldResult {
    PlayerMaterialFieldOutcome outcome = PlayerMaterialFieldOutcome::InvalidCommand;
    std::uint32_t scanned_cells = 0;
    std::uint32_t observed_cells = 0;
    std::uint32_t controlled_cells = 0;
    std::uint32_t moved_cells = 0;
    std::uint32_t movement_steps = 0;
    std::uint32_t blocked_steps = 0;
    std::uint32_t storage_refusals = 0;
    std::uint64_t quantity = 0;
    double centroid_x = 0.0;
    double centroid_y = 0.0;
    bool truncated = false;
};

class PrecisionProbe;

class World {
    friend class PrecisionProbe;
public:
    // ACT-004 admits eight actors with at most eight rectangular parts each.
    // These are transient occupancy identities, never authoritative cell IDs.
    static constexpr std::uint16_t kMaximumTransientBodies = 64;

    explicit World(WorldConfig config = {});
    ~World();

    World(const World&) = delete;
    World& operator=(const World&) = delete;
    World(World&&) noexcept;
    World& operator=(World&&) noexcept;

    [[nodiscard]] const WorldConfig& config() const noexcept;
    [[nodiscard]] const LiquidSolverPolicy& liquid_solver_policy() const noexcept {
        return config_.liquid_solver_policy;
    }
    [[nodiscard]] SimulationBackend backend() const noexcept;
    [[nodiscard]] Material get(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] Material stored_material(std::int64_t x, std::int64_t y) const noexcept;
    // Serialized external-owner query. Never called from a rule kernel: its
    // bounded read neighbourhood extends beyond the kernel write domain.
    [[nodiscard]] bool granular_support_at(std::int64_t x, std::int64_t y,
                                           bool side = false,
                                           bool include_transient_obstacles = true) const noexcept;
    [[nodiscard]] std::uint16_t stored_state_a(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint8_t stored_state_b(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint16_t liquid_mass(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::int16_t temperature(std::int64_t x, std::int64_t y) const noexcept;
    // Exclusive owner readback of authoritative thermal storage, including
    // cells hidden by a transient body mask. Does not expose mutable storage.
    [[nodiscard]] std::int16_t stored_temperature(std::int64_t x, std::int64_t y) const noexcept;

    void set(std::int64_t x, std::int64_t y, Material material);
    [[nodiscard]] bool set_cell_state(std::int64_t x, std::int64_t y, Material material,
                                      std::uint16_t state_a_value,
                                      std::uint8_t state_b_value);
    void set_temperature(std::int64_t x, std::int64_t y, std::int16_t temperature);
    void paint_disc(std::int64_t centre_x, std::int64_t centre_y, std::int32_t radius, Material material);
    void reserve_region(RectI64 region);
    void reserve_temperature_region(RectI64 region);
    // Exclusive external owner only, between ticks. Accept exactly one absent
    // storage chunk; even a resident empty chunk is protected from regeneration.
    // Validate the entire immutable material payload before allocating/writing.
    // Allocation failures throw before cell authority changes. Caller owns the
    // generator/session revision check; this material-only API is not a receipt.
    [[nodiscard]] ChunkInstallOutcome install_generated_chunk(
        ChunkCoord coord, std::span<const Material> row_major_materials);
    void set_simulation_region(std::optional<RectI64> region);
    [[nodiscard]] std::optional<RectI64> simulation_region() const noexcept;
    [[nodiscard]] std::optional<SimulationCoreRange> selected_simulation_cores() const noexcept {
        return selected_core_region_;
    }
    [[nodiscard]] std::optional<SimulationCoreRange> applied_simulation_cores() const noexcept {
        return applied_core_region_;
    }
    void set_liquid_surface_adhesion_enabled(bool enabled) noexcept;
    [[nodiscard]] bool liquid_surface_adhesion_enabled() const noexcept;

    // Dynamic rigid bodies are represented by a transient collision field,
    // separate from authoritative material storage. The field is immutable
    // during tick() and therefore safe for phased worker reads without locks.
    void configure_transient_obstacles(RectI64 region);
    void clear_transient_obstacles();
    [[nodiscard]] bool set_transient_obstacle(std::int64_t x, std::int64_t y,
                                               std::uint16_t body_id);
    [[nodiscard]] std::uint16_t transient_obstacle_at(std::int64_t x,
                                                       std::int64_t y) const noexcept;
    [[nodiscard]] bool relocate_stored_cell(std::int64_t from_x, std::int64_t from_y,
                                            std::int64_t to_x, std::int64_t to_y);
    // Exclusive external owner, between ticks. The caller fences input leases
    // and reset identity. Fixed scratch, resident destinations and preallocated
    // thermal fields keep this operation free of World-owned allocations.
    [[nodiscard]] PlayerMaterialFieldResult apply_player_material_field(
        const PlayerMaterialFieldCommand& command);
    [[nodiscard]] std::uint64_t transient_contact_count(std::uint16_t body_id) const noexcept;
    [[nodiscard]] std::int64_t transient_contact_impulse_x(std::uint16_t body_id) const noexcept;
    [[nodiscard]] std::int64_t transient_contact_impulse_y(std::uint16_t body_id) const noexcept;
    [[nodiscard]] bool queue_explosion(std::int64_t x, std::int64_t y,
                                       std::int32_t radius,
                                       std::uint8_t collapse_strength = 255);
    void clear();

    [[nodiscard]] TickStats tick();
    // tick_index identifies attempts; only completed_tick_index is successful.
    // A thrown tick quarantines this World until clear() or replacement. No
    // rollback, in-place retry, or replay of pending/partially applied events.
    [[nodiscard]] bool has_failed() const noexcept;
    [[nodiscard]] std::uint64_t completed_tick_index() const noexcept;
    [[nodiscard]] std::uint64_t tick_index() const noexcept;
    [[nodiscard]] std::size_t chunk_count() const noexcept;
    [[nodiscard]] std::size_t active_chunk_count() const noexcept;
    [[nodiscard]] std::size_t resident_cell_bytes() const noexcept;
    [[nodiscard]] std::uint64_t state_hash() const noexcept;
    [[nodiscard]] std::uint64_t content_hash() const noexcept;
    [[nodiscard]] std::uint64_t hard_surface_revision() const noexcept;
    // Serialized owner query; nullptr when disabled. Never retain across reset.
    [[nodiscard]] const PhysicsTotals* physics_diagnostics() const noexcept;

    // Opt-in Stage-3 read-only observations. These never authorize simulation
    // skipping and expose immutable values rather than live World storage.
    [[nodiscard]] bool settled_discovery_enabled() const noexcept;
    [[nodiscard]] std::uint64_t settled_discovery_incarnation() const noexcept;
    [[nodiscard]] std::size_t settled_discovery_tile_count() const noexcept;
    [[nodiscard]] std::size_t settled_discovery_pending() const noexcept;
    [[nodiscard]] std::optional<soliding::WorldDiscoveryTileSnapshot>
        settled_discovery_tile(std::size_t index) const noexcept;
    [[nodiscard]] soliding::WorldDiscoveryMetrics settled_discovery_producer_metrics() const noexcept;
    [[nodiscard]] soliding::DiscoveryMetrics settled_discovery_journal_metrics() const noexcept;
    [[nodiscard]] soliding::DiscoveryCoverageState settled_discovery_coverage_state(
        std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] soliding::DiscoveryHalt settled_discovery_halted() const noexcept;
    [[nodiscard]] bool settled_discovery_capacity_blocked() const noexcept;
    [[nodiscard]] std::size_t settled_discovery_storage_bytes() const noexcept;
    std::size_t advance_settled_discovery(std::size_t budget);
    std::size_t advance_settled_regions(std::size_t budget) noexcept;
    [[nodiscard]] std::size_t settled_region_count() const noexcept;
    [[nodiscard]] std::optional<soliding::SettledRegionSnapshot>
        settled_region(std::size_t slot) const noexcept;
    [[nodiscard]] soliding::SettledRegionMetrics settled_region_metrics() const noexcept;
    [[nodiscard]] soliding::RegionRefusal settled_region_refusal() const noexcept;
    [[nodiscard]] std::size_t settled_region_storage_bytes() const noexcept;

    // LCB-001 pressure_flow_v1/reference (#200), active only when the applied
    // liquid policy assigns Water to it. Serialized owner queries between ticks.
    [[nodiscard]] bool pressure_flow_enabled() const noexcept;
    [[nodiscard]] PressureFlowParameters pressure_flow_parameters() const noexcept;
    [[nodiscard]] PressureCellState pressure_cell(std::int64_t x, std::int64_t y) const noexcept;
    // Copies the last pre-kernel derived head slot without preparing/allocating.
    // May be stale after transport/writes or unprepared after restore; no
    // freshness, authority or optimization-skip permission is implied.
    [[nodiscard]] PressureHeadSnapshot prepared_pressure_head(std::int64_t x, std::int64_t y) const noexcept;
    // Copies the actual resident chunk roster for head observations. Returns
    // the required count (zero without pressure); a short span is untouched.
    // Unordered copied coordinates may be sorted by the caller. No allocation,
    // preparation, storage exposure or freshness/skip authority is implied.
    [[nodiscard]] std::size_t copy_pressure_head_chunk_coordinates(std::span<ChunkCoord> output) const noexcept;
    [[nodiscard]] std::vector<GasCompartmentSnapshot> gas_compartments() const;
    [[nodiscard]] std::vector<GasHistoryRecord> gas_history() const;
    [[nodiscard]] GasLedger gas_ledger() const noexcept;
    [[nodiscard]] std::uint64_t gas_topology_revision() const noexcept;
    [[nodiscard]] std::uint32_t gas_next_id() const noexcept;
    [[nodiscard]] PressureFlowLedger pressure_flow_ledger() const noexcept;
    [[nodiscard]] QuantityLedgerSnapshot quantity_ledger() const;
    [[nodiscard]] PressureFlowDiagnostics pressure_flow_diagnostics() const noexcept;
    // Opt-in W-CY owns only Water motion/quantity; material identity and hooks
    // remain Water. No sidecar is needed for its indivisible full-cell state.
    [[nodiscard]] bool water_cellular_yield_enabled() const noexcept { return water_cellular_yield_; }
    [[nodiscard]] bool whole_cell_water_enabled() const noexcept {
        return water_cellular_yield_ || inertial_family(Material::Water);
    }
    [[nodiscard]] WaterCellularYieldParameters water_cellular_yield_parameters() const noexcept {
        return water_cellular_yield_parameters_;
    }
    // Authoritative Water quantity (visible state_a plus pressure overfill) of
    // stored cells, including cells under a transient body mask.
    [[nodiscard]] std::uint64_t water_quantity(RectI64 region) const;
    [[nodiscard]] bool inertial_enabled() const noexcept { return inertial_enabled_; }
    [[nodiscard]] bool inertial_family(Material material) const noexcept;
    [[nodiscard]] InertialParameters inertial_parameters() const noexcept { return inertial_parameters_; }
    [[nodiscard]] InertialCellState inertial_cell(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] InertialLedger inertial_ledger() const noexcept;
    [[nodiscard]] InertialStorageUsage inertial_storage_usage() const noexcept;
    // Serialized diagnostic owner only; true no-op seeds retain all witnesses.
    [[nodiscard]] bool diagnostic_set_inertial_cell(std::int64_t x,std::int64_t y,
        std::int16_t vx,std::int16_t vy,std::int8_t ax,std::int8_t ay);

    // Versioned complete physical-state hash (LCB-001). Covers every
    // future-affecting value: cells, epochs, temperatures, activity/deadlines,
    // pending events, policies, pressure sidecars and the gas table. Independent
    // of whether all-Empty, inactive chunks are allocated. content_hash() and
    // state_hash() keep their historical definitions.
    // Legacy non-IN stream. IN instances report and emit version3.
    static constexpr std::uint32_t kPhysicalStateHashVersion = 2;
    [[nodiscard]] std::uint32_t physical_state_hash_version() const noexcept { return inertial_enabled_ ? 3U : 2U; }
    [[nodiscard]] std::uint64_t physical_state_hash() const;

    // Explicit diagnostic domains. Same-tick equivalence normalizes only the
    // pressure implementation variant. Quiescent content additionally excludes
    // clocks, cell epochs, activity aging and cumulative accounting counters;
    // it retains pending events/deadlines, construction bindings and authority,
    // including actual IN parameters, velocity and subcell accumulators.
    // A constant quiescent hash does not establish future rest or justify skips.
    [[nodiscard]] std::uint64_t liquid_comparison_hash(LiquidStateProjection projection) const;
    [[nodiscard]] PressureOptimizationSnapshot pressure_optimization_snapshot() const;
    [[nodiscard]] std::optional<std::array<std::uint8_t,32>> pressure_optimization_identity() const noexcept;

    // Candidate-capable tick-boundary persistence (CYPS2, or IN-only CYPS3): exact
    // continuation of every physical value above. Transient body masks are
    // host-owned and not saved. restore validates everything before returning
    // a new World and throws std::invalid_argument for unknown, corrupt or
    // incompatible payloads; the caller's live World is never touched.
    static constexpr std::uint32_t kPhysicalStateFormatVersion = 2;
    [[nodiscard]] std::uint32_t physical_state_format_version() const noexcept { return inertial_enabled_ ? 3U : 2U; }
    [[nodiscard]] std::vector<std::uint8_t> save_physical_state() const;
    [[nodiscard]] static std::unique_ptr<World> restore_physical_state(
        const WorldConfig& execution, std::span<const std::uint8_t> bytes);

    [[nodiscard]] std::size_t dirty_chunk_count() const noexcept;
    [[nodiscard]] std::vector<DirtyChunk> take_dirty_chunks();
    void copy_render_cells(RectI64 region, std::span<std::uint8_t> destination,
                           std::size_t stride_bytes) const;
    // One display material byte per cell. Fractional Water uses stable
    // render-only coverage dithering; authoritative mass is never mutated.
    void copy_material_cells(RectI64 region, std::span<std::uint8_t> destination,
                             std::size_t stride_bytes) const;
    void copy_rgba(RectI64 region, std::span<std::uint8_t> destination, std::size_t stride_bytes) const;

private:
    [[nodiscard]] std::uint64_t physical_state_hash_impl(
        std::optional<LiquidStateProjection> projection) const;
    friend class PreparedWorldBuilder;
    friend class RenderSnapshotExchange;

    struct Chunk;
    struct PressureChunk;
    struct PressureState;
    struct PressureCache;
    struct Address;
    struct JobEffects;
    struct ParallelState;
    struct TransientObstacleState;
    struct ExplosionCommand {
        std::int64_t x = 0;
        std::int64_t y = 0;
        std::int32_t radius = 0;
        std::uint8_t collapse_strength = 0;
    };

    WorldConfig config_;
    bool water_cellular_yield_ = false;
    WaterCellularYieldParameters water_cellular_yield_parameters_{};
    bool flow_mixing_enabled_ = false;
    bool flow_carrying_enabled_ = false;
    std::unordered_map<ChunkCoord, std::unique_ptr<Chunk>, ChunkCoordHash> chunks_;
    std::vector<ChunkCoord> active_chunk_scratch_;
    std::vector<SchedulingCoreCoord> active_core_scratch_;
    std::vector<ExplosionCommand> pending_explosions_;
    SchedulerGeometry scheduler_geometry_;
    std::unique_ptr<ParallelState> parallel_;
    std::unique_ptr<TransientObstacleState> transient_obstacles_;
    std::unique_ptr<PhysicsTotals> physics_totals_;
    std::unique_ptr<soliding::SettledWorldDiscoveryCoordinator> settled_discovery_;
    std::unique_ptr<PressureState> pressure_;
    bool inertial_enabled_ = false;
    std::array<bool,kMaterialDefinitions.size()> inertial_materials_{};
    InertialLedger inertial_ledger_{};
    InertialParameters inertial_parameters_{};
    QuantityLedgerSnapshot quantity_{};
    void record_physics(PhysicsEvent kind, Material source, Material target,
                        std::int64_t dx, std::int64_t dy, JobEffects* effects,
                        std::uint64_t count = 1) noexcept;
    using CoreRange = SimulationCoreRange;
    [[nodiscard]] CoreRange block_core_range(ChunkCoord coord, std::size_t index) const noexcept;
    [[nodiscard]] static CoreRange clip_core_range(CoreRange block, std::optional<CoreRange> region) noexcept;
    std::optional<RectI64> simulation_region_;
    // Requested coverage is latched immediately; applied coverage changes only
    // at tick entry. Null means unbounded. Comparison uses whole selected cores.
    std::optional<CoreRange> selected_core_region_;
    std::optional<CoreRange> applied_core_region_;
    bool liquid_surface_adhesion_enabled_ = true;
    std::uint64_t tick_index_ = 0;
    std::uint64_t completed_tick_index_ = 0;
    std::uint8_t update_epoch_ = 0;
    bool tick_in_progress_ = false;
    bool tick_failed_ = false;
    std::uint64_t tick_chunk_allocations_ = 0;
    std::uint64_t tick_temperature_field_allocations_ = 0;
    std::uint64_t hard_surface_revision_ = 0;

    [[nodiscard]] Address address(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] Chunk* find_chunk(ChunkCoord coord) noexcept;
    [[nodiscard]] const Chunk* find_chunk(ChunkCoord coord) const noexcept;
    [[nodiscard]] Chunk& ensure_chunk(ChunkCoord coord);
    void ensure_temperature_field(Chunk& chunk);
    void apply_pending_explosions(TickStats& stats);
    void wake_cell_neighborhood(std::int64_t x, std::int64_t y,
                                bool reconcile_discovery = true);
    void keep_cell_active(std::int64_t x, std::int64_t y, JobEffects* effects) noexcept;
    void schedule_interaction_wake(std::int64_t x, std::int64_t y, std::uint64_t due,
                                   JobEffects* effects) noexcept;
    void schedule_pending_reaction_wake(Material material, std::int64_t x,
                                        std::int64_t y, JobEffects* effects) noexcept;
    struct MotionFootprint;
    [[nodiscard]] bool exchange_permitted(Material source, Material target,
        std::int64_t x, std::int64_t y, std::int64_t target_x, std::int64_t target_y,
        JobEffects* effects, MotionFootprint* footprint = nullptr);
    void mark_cell_dirty(Chunk& chunk, std::int32_t local_x, std::int32_t local_y);
    void move_cell(std::int64_t from_x, std::int64_t from_y, std::int64_t to_x,
                   std::int64_t to_y, bool swap, JobEffects* effects,
                   PhysicsEvent swap_event = PhysicsEvent::DensitySwap);
    std::pair<std::int64_t, std::int64_t> mix_after_motion(Material carrier, std::int64_t x, std::int64_t y,
        std::int64_t to_x, std::int64_t to_y, std::uint16_t mass, JobEffects* effects,
        MotionFootprint* footprint = nullptr);
    [[nodiscard]] bool lateral_due(Material material, std::int64_t x, std::int64_t y,
                                  JobEffects* effects, bool retain_wake = true) noexcept;
    [[nodiscard]] bool try_lateral(Material material, std::int64_t x, std::int64_t y,
        std::int32_t direction, bool swap, JobEffects* effects);
    [[nodiscard]] bool try_move(Material material, std::int64_t x, std::int64_t y, std::int64_t target_x,
                                std::int64_t target_y, bool allow_swap, JobEffects* effects);
    [[nodiscard]] bool update_cell(std::int64_t x, std::int64_t y, JobEffects* effects = nullptr);
    [[nodiscard]] bool update_water(std::int64_t x, std::int64_t y, JobEffects* effects);
    [[nodiscard]] bool update_water_cellular_yield(std::int64_t x, std::int64_t y, JobEffects* effects);
    [[nodiscard]] bool update_water_pressure(std::int64_t x, std::int64_t y, JobEffects* effects);
    [[nodiscard]] bool update_inertial(Material,std::int64_t,std::int64_t,JobEffects*);
    void retire_inertial_cell(Chunk&,std::size_t,JobEffects*) noexcept;
    void validate_inertial_ledger() const;
    void prepare_pressure_tick();
    void account_pressure_certificate_work() noexcept;
    void prepare_pressure_certificates() noexcept;
    void finish_pressure_certificate_tick() noexcept;
    void resolve_gas_topology(bool allow_cache = true);
    void prepare_pressure_gas_cache();
    [[nodiscard]] bool replay_pressure_gas_region(std::int64_t x, std::int64_t y,
                                                 std::uint32_t current, std::uint32_t stamp,
                                                 bool& retry_requested);
    void rebuild_pressure_gas_cache(std::uint32_t stamp);
    void compute_pressure_heads();
    void rebuild_pressure_index();
    void invalidate_pressure_input(ChunkCoord coord, std::int32_t min_x, std::int32_t min_y,
                                   std::int32_t max_x, std::int32_t max_y, bool gas);
    void invalidate_pressure_certificates(ChunkCoord coord, std::int32_t min_x, std::int32_t min_y,
                                          std::int32_t max_x, std::int32_t max_y);
    [[nodiscard]] std::int64_t pressure_lateral_gradient(std::int64_t x, std::int64_t y) const;
    [[nodiscard]] bool pressure_motion_is_noop(std::int64_t x, std::int64_t y, JobEffects* effects);
    void reset_pressure_cell(Chunk& chunk, std::size_t index, Material before, Material after,
                             bool external, JobEffects* effects) noexcept;
    void wake_activity_block(ChunkCoord coord, Chunk& chunk, std::size_t block_index);
    [[nodiscard]] std::uint16_t transfer_water(std::int64_t from_x, std::int64_t from_y,
                                               std::int64_t to_x, std::int64_t to_y,
                                               std::uint16_t requested, JobEffects* effects);
    [[nodiscard]] std::uint16_t state_a(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint8_t state_b(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] bool write_cell(std::int64_t x, std::int64_t y, Material material,
                                  std::uint16_t state_a_value, std::uint8_t state_b_value,
                                 JobEffects* effects, bool external = false,
                                 bool reaction_product = false,
                                 QuantityCause quantity_cause = {});
    void initialize_quantity_ledger(const QuantityConstructionSeed& seed);
    void reset_quantity_ledger() noexcept;
    void record_quantity_transition(Material before, std::uint16_t before_visible,
        std::uint16_t before_overfill, Material after, std::uint16_t after_visible,
        std::uint16_t after_overfill, JobEffects* effects, QuantityCause cause,
        bool source_sink = true, bool reaction_product = false);
    void record_quantity_pair_event(std::uint16_t rule, JobEffects* effects);
    void merge_quantity_effects(const JobEffects& effects, bool commit = true);
    void preflight_generated_quantity(std::span<const Material> materials);
    void preflight_absent_quantity(Material material, std::uint16_t visible,
                                   QuantityCause cause);
    void validate_quantity_ledger(bool scan_authority) const;
    void set_with_quantity_kind(std::int64_t x, std::int64_t y, Material material,
                               QuantityKind kind);
    void merge_pressure_effects(const JobEffects& effects) noexcept;
    [[nodiscard]] bool rule_is_active(Material material, std::uint16_t state_a_value,
                                      std::uint8_t state_b_value) const noexcept;
    [[nodiscard]] bool update_rule_kernel(RuleKernel kernel, Material source_material,
                                          std::int64_t x, std::int64_t y,
                                          JobEffects* effects);
    [[nodiscard]] std::uint8_t deterministic_random(std::int64_t x, std::int64_t y,
                                                    std::uint32_t stream) const noexcept;
    void record_transient_contact(std::uint16_t body_id, Material material,
                                  std::int64_t delta_x, std::int64_t delta_y) noexcept;
    [[nodiscard]] std::int32_t deterministic_direction(std::int64_t x, std::int64_t y) const noexcept;
    void begin_tick(TickStats& stats);
    void require_healthy() const;
    void finish_tick(TickStats& stats);
    [[nodiscard]] TickStats tick_serial();
    [[nodiscard]] TickStats tick_phased();
    void gather_active_cores();
    void scan_rect(CellRect rect, TickStats& stats, JobEffects* effects = nullptr);
    void prepare_write_domain(CellRect rect);
    void merge_job_effects(const JobEffects& effects);
    void initialize_settled_discovery();
    void register_discovery_chunk(ChunkCoord coord, const Chunk& chunk) noexcept;
    [[nodiscard]] soliding::DiscoveryTileKey discovery_tile_key(
        const Address& address) const noexcept;
    [[nodiscard]] soliding::DiscoveryParentKey discovery_parent_key(
        ChunkCoord coord, std::size_t activity_index) const noexcept;
    [[nodiscard]] soliding::DiscoverySignals discovery_signals(
        ChunkCoord coord, std::size_t activity_index,
        soliding::DiscoveryBounds bounds) const noexcept;
    [[nodiscard]] bool discovery_tile_fully_covered(
        soliding::DiscoveryBounds bounds,
        const std::optional<CoreRange>& coverage) const noexcept;
    [[nodiscard]] static std::optional<RectI64> checked_discovery_event_observation_rect(
        std::int64_t x, std::int64_t y, std::int32_t radius,
        std::int32_t rule_radius) noexcept;
    [[nodiscard]] std::optional<RectI64> discovery_event_observation_rect(
        std::int64_t x, std::int64_t y, std::int32_t radius) const noexcept;
    [[nodiscard]] std::optional<std::uint64_t> discovery_pending_event_count(
        soliding::DiscoveryBounds bounds) const noexcept;
    [[nodiscard]] std::uint64_t discovery_mask_occupancy_count(
        soliding::DiscoveryBounds bounds) const noexcept;
    void observe_discovery_activity_parent(ChunkCoord coord,
                                           std::size_t activity_index) noexcept;
    void witness_discovery_activity(ChunkCoord coord, std::size_t activity_index) noexcept;
    void service_discovery_deadlines() noexcept;
    void dirty_discovery_cell(std::int64_t x, std::int64_t y,
                              soliding::ProducerReason reason) noexcept;
    void fence_discovery(soliding::ProducerReason reason) noexcept;
    void witness_discovery_mask_cell(std::int64_t x, std::int64_t y,
                                     bool add) noexcept;
    bool witness_discovery_rect(RectI64 region,
                                soliding::ProducerReason reason,
                                int delta) noexcept;
    void reconcile_discovery_inclusion() noexcept;
    [[nodiscard]] static soliding::DiscoveryCell read_discovery_cell(
        const void* context, std::int64_t x, std::int64_t y);
    [[nodiscard]] static soliding::DiscoverySignals read_discovery_signals(
        const void* context, soliding::DiscoveryTileKey key,
        soliding::DiscoveryBounds bounds, soliding::DiscoverySignals previous);
};

}  // namespace cybersand
