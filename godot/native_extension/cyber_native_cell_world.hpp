#pragma once

#include "cybersand/render_snapshot.hpp"
#include "cyber_object_shard_lab.hpp"
#include "cybersand/world.hpp"
#include "cybersand/prepared_world.hpp"
#include "cybersand/granular_contact_response.hpp"
#include <godot_cpp/variant/packed_float64_array.hpp>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/rect2i.hpp>

#include <array>
#include <cstdint>
#include <memory>
#include <thread>
#include <vector>

namespace godot {

class CyberNativeCellWorld final : public RefCounted {
    GDCLASS(CyberNativeCellWorld, RefCounted)

public:
    static constexpr std::int32_t kWorldWidth = 1024;
    static constexpr std::int32_t kWorldHeight = 1024;
    static constexpr std::int32_t kProtectedCurrentRuleRadius = 2;
    static constexpr std::int32_t kInputStride = 11;
    static constexpr std::int32_t kResultStride = 9;
    explicit CyberNativeCellWorld(bool gameplay_water = false);
    [[nodiscard]] static Ref<CyberNativeCellWorld> create_gameplay_world();
    ~CyberNativeCellWorld() override;

    [[nodiscard]] static std::int64_t auto_worker_threads(std::int64_t logical_threads);
    [[nodiscard]] static std::int64_t logical_processor_count();

    [[nodiscard]] static Dictionary gameplay_water_options();
    bool reset_demo_world(bool gameplay_water = false);
    [[nodiscard]] Dictionary get_default_demo_identity() const;
    [[nodiscard]] bool simulation_tick();
    // Optional same-World native operations, worker exclusive and value-only.
    [[nodiscard]] Dictionary object_shard_attach(Rect2i bounds);
    [[nodiscard]] Dictionary object_shard_status() const;
    [[nodiscard]] Dictionary object_shard_snapshot(bool include_world = true);
    [[nodiscard]] Dictionary object_shard_workbench_action(const Dictionary& request);
    // Worker-only native edits and exact payload inspections in this SAME World.
    [[nodiscard]] Dictionary object_shard_edit_cell(Vector2i cell, std::int64_t material,
        std::int64_t state_a, std::int64_t state_b, std::int64_t temperature);
    [[nodiscard]] Dictionary object_shard_inspect_cell(Vector2i cell) const;
    [[nodiscard]] Dictionary object_shard_prepare_next();
    [[nodiscard]] Dictionary object_shard_acknowledge(const Dictionary& receipt);
    [[nodiscard]] Dictionary object_shard_accept_motion(const Array& poses);
    [[nodiscard]] Dictionary object_shard_accept_workbench_motion(const Array& poses,
        const PackedFloat64Array& states, const PackedFloat64Array& geometry, const Array& bodies,
        std::int64_t session, std::int64_t epoch);
    [[nodiscard]] Dictionary object_shard_erase_shard(const Dictionary& receipt);
    [[nodiscard]] Dictionary object_shard_ignite_shard(std::int64_t id,
        std::int64_t generation, std::int64_t cell);
    [[nodiscard]] bool object_shard_retire();
    [[nodiscard]] bool has_failed() const;
    [[nodiscard]] std::int64_t get_attempted_tick_index() const;
    void emit_disc(std::int64_t centre_x, std::int64_t centre_y,
                   std::int64_t radius, std::int64_t material_id,
                   std::int64_t emission_flags = 0);
    void paint_disc(std::int64_t centre_x, std::int64_t centre_y,
                    std::int64_t radius, std::int64_t material_id,
                    std::int64_t emission_flags = 0);
    // Synchronous player playground only; the exclusive owner fences lifecycle
    // and input leases before invoking this bounded native material operation.
    [[nodiscard]] Dictionary apply_player_material_field(Vector2i center, Vector2 direction,
        std::int64_t material_id, std::int64_t mode, std::int64_t phase);

    void prepare_rigid_body_coupling(const PackedFloat32Array& states,
                                     bool resolve_overlaps = true);
    [[nodiscard]] PackedFloat32Array rigid_body_results() const;

    [[nodiscard]] std::int64_t material_at(std::int64_t x, std::int64_t y) const;
    // Authoritative stored identity, without the transient rigid-body overlay.
    // Editing callers must still check rigid_body_id_at before mutating a cell.
    [[nodiscard]] std::int64_t stored_material_at(std::int64_t x, std::int64_t y) const;
    [[nodiscard]] std::int64_t rigid_body_id_at(std::int64_t x, std::int64_t y) const;
    [[nodiscard]] bool box_collides(Vector2 origin, Vector2 size) const;
    [[nodiscard]] bool character_box_collides(Vector2 origin, Vector2 size, std::int64_t mode) const;
    [[nodiscard]] std::int64_t character_disturb_granular(
        Vector2 origin, Vector2 size, double impact_speed);
    [[nodiscard]] PackedByteArray get_cells() const;
    [[nodiscard]] Dictionary take_render_snapshot(bool force_full = false);
    [[nodiscard]] PackedInt32Array get_hard_surface_rectangles() const;
    [[nodiscard]] PackedInt32Array get_hard_surface_chunk_rectangles() const;

    void set_interest_center(Vector2i world_cell);
    void set_simulation_window(Vector2i view_origin, Vector2i view_size,
                               std::int64_t horizontal_buffer,
                               std::int64_t vertical_buffer);
    void set_simulation_window_enabled(bool enabled);
    [[nodiscard]] bool get_simulation_window_enabled() const;
    void set_cadence_lod_enabled(bool enabled);
    [[nodiscard]] bool get_cadence_lod_enabled() const;
    void set_liquid_surface_adhesion_enabled(bool enabled);
    [[nodiscard]] bool get_liquid_surface_adhesion_enabled() const;

    [[nodiscard]] std::int64_t get_revision() const;
    [[nodiscard]] std::int64_t get_hard_surface_revision() const;
    [[nodiscard]] std::int64_t get_tick_index() const;
    [[nodiscard]] std::int64_t get_moves_last_tick() const;
    [[nodiscard]] std::int64_t get_scanned_last_tick() const;
    [[nodiscard]] std::int64_t get_dormant_cells_skipped_last_tick() const;
    [[nodiscard]] std::int64_t get_active_blocks_last_tick() const;
    [[nodiscard]] std::int64_t get_eligible_blocks_last_tick() const;
    [[nodiscard]] std::int64_t get_adaptive_block_stride_last_tick() const;
    [[nodiscard]] std::int64_t get_deferred_blocks_last_tick() const;
    [[nodiscard]] std::int64_t get_frozen_blocks_last_tick() const;
    [[nodiscard]] std::int64_t get_scheduler_jobs_last_tick() const;
    [[nodiscard]] std::int64_t get_scheduler_parallel_phases_last_tick() const;
    [[nodiscard]] std::int64_t get_sparse_flight_moves_last_tick() const;
    [[nodiscard]] std::int64_t get_rigid_body_contacts_last_tick() const;
    [[nodiscard]] std::int64_t get_rigid_body_displaced_last_tick() const;
    [[nodiscard]] std::int64_t get_rigid_body_unresolved_last_tick() const;
    [[nodiscard]] double get_simulation_time_ms() const;
    [[nodiscard]] std::int64_t get_worker_threads() const;
    [[nodiscard]] String get_backend_name() const;
    bool prepare_workbench_coupling(const PackedFloat64Array& states, const PackedFloat64Array& geometry,
        const Array& bodies, std::int64_t session, std::int64_t epoch, bool resolve_overlaps);
    [[nodiscard]] Dictionary workbench_coupling_results() const;
    [[nodiscard]] String get_last_tick_error() const;
    [[nodiscard]] Dictionary get_water_experiment_policy() const;
    // Copied experimental construction, quantity and worker diagnostics. The
    // caller is the exclusive World owner, between ticks.
    [[nodiscard]] Dictionary get_wave_flow_status() const;
    [[nodiscard]] Dictionary inspect_wave_flow_cell(Vector2i point) const;
    // Applied LCB-001 liquid solver policy receipt of the live World. The
    // generation counts committed World replacements; refusals never advance it.
    [[nodiscard]] Dictionary get_liquid_solver_policy() const;
    [[nodiscard]] std::int64_t get_liquid_policy_session_generation() const;
    // MAT-AUDITION-LIVE-001. Exclusive native owner only, between ticks; all
    // dictionaries are copied values and never expose mutable World storage.
    [[nodiscard]] Dictionary get_material_audition_state() const;
    [[nodiscard]] Dictionary apply_material_audition(const Dictionary& request);
    [[nodiscard]] static Dictionary liquid_policy_receipt(
        const cybersand::LiquidSolverPolicy& policy, std::int64_t session_generation,
        const cybersand::World* actual = nullptr);
    bool water_experiment_fill_rect(Vector2i origin, Vector2i size,
                                    std::int64_t normalized_mass,
                                    std::int64_t coherence);
    bool water_experiment_erase_rect(Vector2i origin, Vector2i size);
    [[nodiscard]] Dictionary water_experiment_observation(
        Vector2i origin, Vector2i size) const;
    // LCB-001 pressure_flow_v1 (#200) inspection. Serialized owner-only reads of
    // immutable values; nothing exposes live World storage.
    [[nodiscard]] String get_physical_state_hash() const;
    [[nodiscard]] std::int64_t get_physical_state_hash_version() const;
    [[nodiscard]] std::int64_t get_physical_state_format_version() const;
    [[nodiscard]] Dictionary inspect_inertial_cell(Vector2i point) const;
    [[nodiscard]] Dictionary inspect_gas_compartments() const;
    [[nodiscard]] Dictionary inspect_pressure_cell(Vector2i point) const;
    [[nodiscard]] Dictionary get_pressure_flow_ledger() const;
    // Exclusive-owner diagnostic observations. Unknown projection IDs return
    // no hash; optimization counters/budgets use exact unsigned decimal strings.
    [[nodiscard]] String get_liquid_comparison_hash(std::int64_t projection_id) const;
    [[nodiscard]] Dictionary inspect_pressure_optimization() const;
    // Run receipt: binds the applied policy and every World execution input with
    // the caller's setup identity into one SHA-256 receipt hash.
    [[nodiscard]] Dictionary get_liquid_run_receipt(const Dictionary& setup) const;
    // Typed native v1 construction values, copied at the exclusive owner boundary.
    [[nodiscard]] Dictionary get_applied_liquid_construction_receipt() const;
    [[nodiscard]] Dictionary get_liquid_construction_attempt() const;
    // Isolated fresh-world experiment API. Called only by the exclusive owner.
    bool diagnostic_reset(const Dictionary& options);
    bool diagnostic_fill_rect(Vector2i origin, Vector2i size, std::int64_t material,
                              std::int64_t state_b = 0);
    // Serialized diagnostic-only relocation through World::relocate_stored_cell.
    // Hard-surface sources are rejected so this helper cannot bypass collider ownership.
    bool diagnostic_relocate_cell(Vector2i from, Vector2i to);
    [[nodiscard]] Dictionary diagnostic_snapshot(Vector2i origin, Vector2i size,
                                                  bool include_histogram = false) const;
    [[nodiscard]] Array diagnostic_body_metrics() const;
    [[nodiscard]] std::int64_t get_tick_failure_count() const;
    // WCX/BW-001 experimental Water spray (adapter launch law over the native
    // ballistic_water_v1 owner). Exclusive owner only, between ticks.
    [[nodiscard]] Dictionary set_water_spray(const Dictionary& settings);
    [[nodiscard]] Dictionary get_water_spray() const;
    void water_spray_before_tick();
    [[nodiscard]] String inject_water_parcel(Vector2 position, Vector2 velocity_cells_per_tick, std::int64_t quantity);
    [[nodiscard]] PackedFloat64Array inspect_ballistic_parcels(std::int64_t maximum) const;

protected:
    static void _bind_methods();

private:
    // The demo adapter exchanges owned byte arrays, never native pointers.
    // Both adapters must be called by the same exclusive tick-boundary owner.
    friend class CyberDemoBridge;

    struct BodyState {
        std::uint16_t id = 0;
        Vector2 center{};
        double rotation = 0.0;
        Vector2 half_size{0.5, 0.5};
        Vector2 velocity{};
        double angular_velocity = 0.0;
        double mass = 1.0;
        std::int32_t sample_serial = 0;
        double inertia = 1, friction = 0, dt = 0;
        Vector2 com{};
        bool valid = false;
    };

    using BodyStates = std::array<BodyState, cybersand::World::kMaximumTransientBodies + 1U>;

    struct BodyObservation {
        Vector2 impulse{};
        Vector2 bearing{};
        Vector2 correction{};
        std::uint64_t contacts = 0;
        std::uint64_t displaced = 0;
        std::uint64_t unresolved = 0;
    };
    struct BodyDiagnostic {
        Vector2 displacement{};
        Vector2 boundary{};
        Vector2 bearing{};
        std::uint64_t support_samples = 0;
        std::uint64_t intermediate_caps = 0;
        std::array<std::uint64_t, 4 * cybersand::kMaterialDefinitions.size()> faces{};
    };
    using BodyDiagnostics =
        std::array<BodyDiagnostic, cybersand::World::kMaximumTransientBodies + 1U>;
    std::unique_ptr<BodyDiagnostics> body_diagnostics_;
    bool diagnostic_fixture_ = false;
    bool default_demo_recipe_active_ = false;
    double displacement_gain_ = 0.18;
    double boundary_gain_ = 0.19;
    double contact_gain_ = 0.025;
    double impulse_cap_ = 3.0;
    double density_limit_ = 1.6;
    [[nodiscard]] double density_scale(cybersand::Material material, double minimum = 0.05) const;
    // Wave Body push / Push by amount applied to a Water cell's push on a body;
    // 1 for every other material and for non-Wave Worlds.
    [[nodiscard]] double water_push_scale(cybersand::Material material, std::int32_t x, std::int32_t y) const;

    std::unique_ptr<cybersand::World> world_;
    // Destroy before any World replacement. Never owns or ticks another World.
    Ref<CyberObjectShardLab> shard_lab_;
    std::thread::id shard_owner_thread_{};
    bool shard_quarantined_{};
    std::vector<std::uint16_t> shard_gcr_mask_;
    std::vector<cybersand::World::TransientCompositionCell> shard_gcr_cells_;
    [[nodiscard]] bool shard_owner() const noexcept {
        return world_ && shard_lab_.is_valid() && shard_lab_->coordinator_ &&
            shard_lab_->coordinator_->same_world_attached(*world_) &&
            std::this_thread::get_id() == shard_owner_thread_;
    }
    [[nodiscard]] bool shard_retains_inventory() const noexcept {
        return shard_lab_.is_valid() && shard_lab_->coordinator_ &&
            !shard_lab_->coordinator_->can_detach();
    }
    void retire_shard_for_world_replacement() noexcept;
    [[nodiscard]] bool compose_shard_with_workbench_occupancy();
    std::unique_ptr<cybersand::RenderSnapshotExchange> render_exchange_;
    cybersand::TickStats last_stats_{};
    BodyStates current_bodies_{};
    BodyStates previous_bodies_{};
    std::array<BodyObservation, cybersand::World::kMaximumTransientBodies + 1U> observations_{};
    std::vector<std::int32_t> raster_indices_;
    mutable PackedByteArray render_cells_;
    mutable PackedInt32Array hard_surface_rectangles_;
    mutable PackedInt32Array hard_surface_chunk_rectangles_;
    // Incremental chunk packet: the hard-surface mask behind the last packet
    // and each 64x64 collision chunk's rectangles, a pure function of its mask
    // block. A chunk whose block is unchanged reuses its rectangles.
    struct HardSurfaceRectangle { std::int32_t x = 0, y = 0, width = 0, height = 0; };
    mutable std::vector<std::uint64_t> hard_surface_bits_;
    mutable std::vector<std::vector<HardSurfaceRectangle>> hard_surface_chunk_cache_;
    // The invalidation stream is consumed before packet assembly. A partial
    // rebuild must not allow the next query to trust residual tile bits.
    mutable bool hard_surface_cache_valid_ = false;
    mutable const cybersand::World* hard_surface_cache_world_ = nullptr;
    mutable Vector2i hard_surface_cache_extent_{};
    mutable std::uint64_t hard_surface_chunks_rebuilt_ = 0, hard_surface_chunks_reused_ = 0;
    mutable std::uint64_t hard_surface_full_mask_copies_ = 0;
    mutable std::uint64_t hard_surface_tile_mask_copies_ = 0;
    mutable std::uint64_t hard_surface_recovery_full_refreshes_ = 0;
    mutable std::uint64_t hard_surface_last_invalidated_tiles_ = 0;
    mutable std::uint64_t hard_surface_last_changed_tiles_ = 0;
    mutable std::uint64_t render_cells_revision_ = UINT64_MAX;
    mutable std::uint64_t hard_surface_rectangles_revision_ = UINT64_MAX;
    mutable std::uint64_t hard_surface_chunk_rectangles_revision_ = UINT64_MAX;
    Vector2i interest_center_{kWorldWidth / 2, kWorldHeight / 2};
    Vector2i last_view_origin_{};
    Vector2i last_view_size_{320, 180};
    std::int64_t last_horizontal_buffer_ = 32;
    std::int64_t last_vertical_buffer_ = 36;
    std::uint32_t worker_threads_ = 1;
    std::uint64_t revision_ = 0;
    std::uint64_t hard_surface_revision_ = 0;
    // Failure reporting is owner-only diagnostic state, including when an
    // observational binding discovers an invalid World. Keep the first cause.
    mutable std::uint64_t tick_failure_count_ = 0;
    std::uint64_t liquid_policy_session_generation_ = 0;
    Vector2i extent_{kWorldWidth, kWorldHeight};
    // Configured authored actors can own multiple real parts, including released
    // equipment. Each physical body retains its own response and mask budget.
    static constexpr std::size_t kWorkbenchBodies = cybersand::World::kMaximumTransientBodies;
    struct WorkbenchBody {
        std::int64_t instance = 0, generation = 0;
        std::int32_t first = 0, count = 0;
        double budget = 20, gravity = 0;
        bool external_drive = false;
    };
    struct WorkbenchSample {
        BodyStates proxies{};
        std::array<std::array<double,4>, cybersand::World::kMaximumTransientBodies + 1> geometry{};
        std::array<WorkbenchBody,kWorkbenchBodies + 1> owners{};
        std::array<std::uint16_t,cybersand::World::kMaximumTransientBodies + 1> owner_of{};
        std::int64_t session = 0, epoch = 0;
    };
    struct Workbench {
        String response;
        WorkbenchSample sample;
        // Reused heap-owned parse destination: no population-sized stack frame
        // or allocation during an ordinary physical publication.
        WorkbenchSample pending;
        bool valid = false, sampled = false;
        std::uint64_t prepared_tick = 0;
        std::array<std::array<cybersand::gcr::Bin,8>,cybersand::World::kMaximumTransientBodies + 1> bins{};
        cybersand::gcr::CompoundWorkspace workspace{};
    };
    std::unique_ptr<Workbench> workbench_;
    struct WaterSpraySettings {
        bool enabled = false;          // impact spray from body overlap
        double launch_scale = 1.6;     // parcel speed per unit of body push speed
        double threshold = 0.3;        // push (cells/tick) needed to launch
        double upward_bias = 0.72;     // 0: along the push normal; 1: straight up
        double spread = 0.55;          // lateral outward component when biased up
        double jitter = 0.35;          // deterministic angle/speed variation
        std::int64_t budget = 64;      // launches per body per coupling cycle
        double reaction_gain = 0.0;    // extra stylized body reaction (0 keeps accepted feel)
        double droplet_gain = 2e-7;    // droplet->body impulse per quantity*q256 momentum
        bool submerged_lift = true;    // lift otherwise-unresolved submerged Water to the surface
        std::int64_t lift_reach = 48;  // rows searched upward
        bool jet_enabled = false;
        Vector2i jet_origin{256, 320};
        double jet_angle = -75.0;      // degrees; -90 is straight up
        double jet_speed = 3.2;        // cells per tick
        std::int64_t jet_rate = 3;     // parcels per tick
        std::int64_t jet_quantity = 128;
        double jet_spread = 5.0;       // degrees
        double nozzle_speed = 2.5;     // flyer Water nozzle parcel speed, cells per tick
    };
    struct WaterSprayCounters {
        std::int64_t launched = 0, lifted = 0, budget_hits = 0, refused = 0, jet = 0, jet_refused = 0;
    };
    WaterSpraySettings spray_{};
    WaterSprayCounters spray_tick_{}, spray_total_{};
    std::array<std::int64_t, cybersand::World::kMaximumTransientBodies + 1U> spray_budget_used_{};
    std::uint64_t spray_jet_phase_ = 0;
    [[nodiscard]] static Dictionary water_spray_settings_dictionary(const WaterSpraySettings& settings);
    [[nodiscard]] Vector2i find_spray_lift_spawn(std::int32_t x, std::int32_t y, std::uint16_t body_id,
                                                 std::int32_t lateral) const;
    [[nodiscard]] bool try_water_spray(const BodyState& body, std::uint16_t body_id, std::int32_t x, std::int32_t y,
                                       Vector2 outward, Vector2i target);
    [[nodiscard]] Vector2 spray_droplet_impulse(std::uint16_t body_id) const;
    static bool parse_workbench_sample(WorkbenchSample& out, const Workbench& retained,
        const PackedFloat64Array& states, const PackedFloat64Array& geometry, const Array& owners,
        std::int64_t session, std::int64_t epoch);
    void prepare_body_coupling(bool resolve_overlaps);
    void accumulate_workbench_contacts();
    bool authored_entry_normal(std::uint16_t proxy, std::int32_t x, std::int32_t y,
        Vector2& outward, double& penetration) const;
    Dictionary workbench_body_result(std::size_t id) const;
    struct PendingLiquidWorld {
        std::unique_ptr<Workbench> workbench;
        Vector2i extent{kWorldWidth,kWorldHeight};
        std::unique_ptr<cybersand::World> world;
        std::unique_ptr<cybersand::RenderSnapshotExchange> exchange;
        cybersand::setup::SetupDescriptor setup;
        Dictionary receipt;
        // GEN-006 continuation has distinct authority from the tick-zero
        // authored-source construction receipt. Both are copied values.
        Dictionary continuation_identity, continuation_capsule, source_construction_receipt;
        String source_checkpoint_sha256;
        std::uint64_t source_checkpoint_tick = 0;
        bool continuation = false, continuation_dirty = false;
        BodyStates initial_bodies{};
        PackedFloat32Array initial_body_input;
        String initial_body_digest, workbench_initial_digest;
        std::uint64_t token = 0, retained_generation = 0, retained_revision = 0, retained_hash = 0;
        bool retains_cells = false;
        Vector2i origin{}, size{};
        bool cadence = false, adhesion = true, window = true;
        bool reset_demo_coupling = false;
        bool retained_cadence = false, retained_window = true;
    };
    std::unique_ptr<PendingLiquidWorld> pending_liquid_world_;
    // The same exclusive desktop owner owns every inactive native allocation.
    // An active record has no payload; exactly one bundle is installed in this
    // adapter. Handles are never reused, including after eviction.
    struct ResidentArea {
        Dictionary identity;
        String physics_profile;
        std::unique_ptr<PendingLiquidWorld> payload;
        std::uint64_t handle = 0, generation = 1, mutation = 0;
        std::uint64_t active_construction_generation = 0;
    };
    std::vector<std::unique_ptr<ResidentArea>> resident_areas_;
    std::uint64_t active_resident_handle_ = 0, next_resident_handle_ = 0;
    std::uint64_t resident_hot_activations_ = 0, resident_captures_ = 0, resident_steps_ = 0;
    std::uint64_t resident_admissions_ = 0, resident_releases_ = 0, resident_imports_ = 0;
    std::uint64_t resident_source_constructions_ = 0, resident_native_restorations_ = 0;
    String resident_last_operation_;
    std::uint64_t next_liquid_preparation_token_ = 0;
    cybersand::setup::SetupDescriptor applied_liquid_setup_ = [] {
        cybersand::setup::SetupDescriptor value;
        value.domain = {0, 0, kWorldWidth, kWorldHeight};
        return value;
    }();
    Dictionary applied_liquid_construction_receipt_;
    Dictionary liquid_construction_attempt_;
    mutable String last_tick_error_{};
    struct CouplingFailureContext {
        const char* stage = nullptr;
        std::uint16_t body = 0;
        std::int32_t source_x = -1, source_y = -1;
        std::int32_t target_x = -1, target_y = -1;
    };
    mutable CouplingFailureContext coupling_failure_context_{};
    // These boundaries do not recover partially mutated native state. They
    // quarantine it, retain one cause, and let the worker publish its last
    // valid snapshot. Native pool workers never call these Godot methods.
    void record_native_failure(const char* operation, const char* detail) const noexcept;
    [[nodiscard]] Dictionary native_failure_status() const;
    double simulation_time_ms_ = 0.0;
    bool simulation_window_enabled_ = true;
    bool cadence_lod_enabled_ = true;
    bool liquid_surface_adhesion_enabled_ = true;
    bool render_snapshot_full_refresh_required_ = true;

    [[nodiscard]] static bool character_box_collides_in(const cybersand::World* world, Vector2i extent, Vector2 origin, Vector2 size, std::int64_t mode);
    static void select_gameplay_water(cybersand::WorldConfig& config, bool enabled);
    void create_world();
    void retire_liquid_construction_identity();
    void reset_demo_coupling_parameters() noexcept;
    void refresh_simulation_region();
    void refresh_render_cells() const;
    void clear_observations();
    static void parse_body_state_values(BodyStates& out, const PackedFloat32Array& states, bool strict);
    [[nodiscard]] static PackedInt32Array hard_surface_chunks_from_cells(const PackedByteArray& cells, Vector2i extent);
    // Diagnostic: the chunk packet rebuilt in full from the display projection.
    [[nodiscard]] PackedInt32Array diagnostic_full_hard_surface_chunk_rectangles() const;
    [[nodiscard]] Dictionary diagnostic_hard_surface_packet_stats() const;
    static void rasterize_transform_in(cybersand::World& world, Vector2i extent, std::vector<std::int32_t>* indices,
        std::uint16_t body_id, Vector2 center, double rotation, Vector2 half_size,
        std::vector<std::uint16_t>* staging_mask = nullptr);
    void parse_body_states(const PackedFloat32Array& states);
    void rasterize_body(const BodyState& body);
    void rasterize_body_sweep(const BodyState& body, const BodyState& previous);
    void rasterize_transform(std::uint16_t body_id, Vector2 center,
                             double rotation, Vector2 half_size);
    void reconcile_swept_overlaps();
    void reconcile_overlap(std::int32_t cell_index, std::uint16_t body_id);
    void accumulate_boundary_pressure();
    void accumulate_granular_bearing();
    [[nodiscard]] bool cell_inside_body(const BodyState& body,
                                        std::int32_t x, std::int32_t y) const;
    [[nodiscard]] Vector2 overlap_normal(const BodyState& body,
                                         std::int32_t x, std::int32_t y,
                                         double& penetration) const;
    [[nodiscard]] Vector2i find_ejection_target(std::int32_t source_x,
                                                std::int32_t source_y,
                                                std::uint16_t source_body_id,
                                                Vector2 outward_normal,
                                                double penetration) const;
    [[nodiscard]] bool ejection_path_reachable(std::int32_t source_x,
                                                std::int32_t source_y,
                                                std::int32_t target_x,
                                                std::int32_t target_y,
                                                std::uint16_t source_body_id) const;
    void record_impulse(std::uint16_t body_id, Vector2 impulse);
    [[nodiscard]] static std::int32_t symmetric_probe_offset(std::int32_t index);
    [[nodiscard]] bool in_bounds(std::int64_t x, std::int64_t y) const;
};

}  // namespace godot
