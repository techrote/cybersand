#pragma once

#include "cybersand/material.hpp"
#include "cybersand/physics_diagnostics.hpp"
#include "cybersand/interaction_policy.hpp"
#include "cybersand/transport_policy.hpp"
#include "cybersand/scheduler_geometry.hpp"
#include "cybersand/settled_world_discovery.hpp"
#include "cybersand/water_experiment_policy.hpp"

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

struct RectI64 {
    std::int64_t x = 0;
    std::int64_t y = 0;
    std::int64_t width = 0;
    std::int64_t height = 0;
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
};

struct DirtyChunk {
    ChunkCoord chunk;
    RectI64 local_rect;
};

class PrecisionProbe;

class World {
    friend class PrecisionProbe;
public:
    static constexpr std::uint16_t kMaximumTransientBodies = 16;

    explicit World(WorldConfig config = {});
    ~World();

    World(const World&) = delete;
    World& operator=(const World&) = delete;
    World(World&&) noexcept;
    World& operator=(World&&) noexcept;

    [[nodiscard]] const WorldConfig& config() const noexcept;
    [[nodiscard]] SimulationBackend backend() const noexcept;
    [[nodiscard]] Material get(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] Material stored_material(std::int64_t x, std::int64_t y) const noexcept;
    // Serialized external-owner query. Never called from a rule kernel: its
    // bounded read neighbourhood extends beyond the kernel write domain.
    [[nodiscard]] bool granular_support_at(std::int64_t x, std::int64_t y,
                                           bool side = false) const noexcept;
    [[nodiscard]] std::uint16_t stored_state_a(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint8_t stored_state_b(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint16_t liquid_mass(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::int16_t temperature(std::int64_t x, std::int64_t y) const noexcept;

    void set(std::int64_t x, std::int64_t y, Material material);
    [[nodiscard]] bool set_cell_state(std::int64_t x, std::int64_t y, Material material,
                                      std::uint16_t state_a_value,
                                      std::uint8_t state_b_value);
    void set_temperature(std::int64_t x, std::int64_t y, std::int16_t temperature);
    void paint_disc(std::int64_t centre_x, std::int64_t centre_y, std::int32_t radius, Material material);
    void reserve_region(RectI64 region);
    void reserve_temperature_region(RectI64 region);
    void set_simulation_region(std::optional<RectI64> region);
    [[nodiscard]] std::optional<RectI64> simulation_region() const noexcept;
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
    friend class RenderSnapshotExchange;

    struct Chunk;
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
    void record_physics(PhysicsEvent kind, Material source, Material target,
                        std::int64_t dx, std::int64_t dy, JobEffects* effects,
                        std::uint64_t count = 1) noexcept;
    struct CoreRange {
        std::int64_t min_x, min_y, max_x, max_y;
        friend bool operator==(const CoreRange&, const CoreRange&) = default;
    };
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
    [[nodiscard]] bool exchange_permitted(Material source, Material target,
        std::int64_t x, std::int64_t y, std::int64_t target_x, std::int64_t target_y,
        JobEffects* effects);
    void mark_cell_dirty(Chunk& chunk, std::int32_t local_x, std::int32_t local_y);
    void move_cell(std::int64_t from_x, std::int64_t from_y, std::int64_t to_x,
                   std::int64_t to_y, bool swap, JobEffects* effects,
                   PhysicsEvent swap_event = PhysicsEvent::DensitySwap);
    void mix_after_motion(Material carrier, std::int64_t x, std::int64_t y,
        std::int64_t to_x, std::int64_t to_y, std::uint16_t mass, JobEffects* effects);
    [[nodiscard]] bool lateral_due(Material material, std::int64_t x, std::int64_t y,
                                  JobEffects* effects) noexcept;
    [[nodiscard]] bool try_lateral(Material material, std::int64_t x, std::int64_t y,
        std::int32_t direction, bool swap, JobEffects* effects);
    [[nodiscard]] bool try_move(Material material, std::int64_t x, std::int64_t y, std::int64_t target_x,
                                std::int64_t target_y, bool allow_swap, JobEffects* effects);
    [[nodiscard]] bool update_cell(std::int64_t x, std::int64_t y, JobEffects* effects = nullptr);
    [[nodiscard]] bool update_water(std::int64_t x, std::int64_t y, JobEffects* effects);
    [[nodiscard]] std::uint16_t transfer_water(std::int64_t from_x, std::int64_t from_y,
                                               std::int64_t to_x, std::int64_t to_y,
                                               std::uint16_t requested, JobEffects* effects);
    [[nodiscard]] std::uint16_t state_a(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint8_t state_b(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] bool write_cell(std::int64_t x, std::int64_t y, Material material,
                                  std::uint16_t state_a_value, std::uint8_t state_b_value,
                                  JobEffects* effects);
    [[nodiscard]] bool rule_is_active(Material material, std::uint16_t state_a_value,
                                      std::uint8_t state_b_value) const noexcept;
    [[nodiscard]] bool update_rule_kernel(RuleKernel kernel, std::int64_t x, std::int64_t y,
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
