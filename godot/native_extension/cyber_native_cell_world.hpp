#pragma once

#include "cybersand/render_snapshot.hpp"
#include "cybersand/world.hpp"
#include "cybersand/prepared_world.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <array>
#include <cstdint>
#include <memory>
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
    CyberNativeCellWorld();
    ~CyberNativeCellWorld() override;

    [[nodiscard]] static std::int64_t auto_worker_threads(std::int64_t logical_threads);
    [[nodiscard]] static std::int64_t logical_processor_count();

    bool reset_demo_world();
    [[nodiscard]] Dictionary get_default_demo_identity() const;
    [[nodiscard]] bool simulation_tick();
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
    [[nodiscard]] String get_last_tick_error() const;
    [[nodiscard]] Dictionary get_water_experiment_policy() const;
    // Applied LCB-001 liquid solver policy receipt of the live World. The
    // generation counts committed World replacements; refusals never advance it.
    [[nodiscard]] Dictionary get_liquid_solver_policy() const;
    [[nodiscard]] std::int64_t get_liquid_policy_session_generation() const;
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

    std::unique_ptr<cybersand::World> world_;
    std::unique_ptr<cybersand::RenderSnapshotExchange> render_exchange_;
    cybersand::TickStats last_stats_{};
    BodyStates current_bodies_{};
    BodyStates previous_bodies_{};
    std::array<BodyObservation, cybersand::World::kMaximumTransientBodies + 1U> observations_{};
    std::vector<std::int32_t> raster_indices_;
    mutable PackedByteArray render_cells_;
    mutable PackedInt32Array hard_surface_rectangles_;
    mutable PackedInt32Array hard_surface_chunk_rectangles_;
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
    std::uint64_t tick_failure_count_ = 0;
    std::uint64_t liquid_policy_session_generation_ = 0;
    struct PendingLiquidWorld {
        std::unique_ptr<cybersand::World> world;
        std::unique_ptr<cybersand::RenderSnapshotExchange> exchange;
        cybersand::setup::SetupDescriptor setup;
        Dictionary receipt;
        BodyStates initial_bodies{};
        PackedFloat32Array initial_body_input;
        String initial_body_digest;
        std::uint64_t token = 0, retained_generation = 0, retained_revision = 0, retained_hash = 0;
        Vector2i origin{}, size{};
        bool cadence = false, adhesion = true, window = true;
        bool reset_demo_coupling = false;
        bool retained_cadence = false, retained_window = true;
    };
    std::unique_ptr<PendingLiquidWorld> pending_liquid_world_;
    std::uint64_t next_liquid_preparation_token_ = 0;
    cybersand::setup::SetupDescriptor applied_liquid_setup_ = [] {
        cybersand::setup::SetupDescriptor value;
        value.domain = {0, 0, kWorldWidth, kWorldHeight};
        return value;
    }();
    Dictionary applied_liquid_construction_receipt_;
    Dictionary liquid_construction_attempt_;
    String last_tick_error_{};
    double simulation_time_ms_ = 0.0;
    bool simulation_window_enabled_ = true;
    bool cadence_lod_enabled_ = true;
    bool liquid_surface_adhesion_enabled_ = true;
    bool render_snapshot_full_refresh_required_ = true;

    [[nodiscard]] static bool character_box_collides_in(const cybersand::World* world, Vector2 origin, Vector2 size, std::int64_t mode);
    void create_world();
    void retire_liquid_construction_identity();
    void reset_demo_coupling_parameters() noexcept;
    void refresh_simulation_region();
    void refresh_render_cells() const;
    void clear_observations();
    [[nodiscard]] static BodyStates parse_body_state_values(const PackedFloat32Array& states, bool strict);
    [[nodiscard]] static PackedInt32Array hard_surface_chunks_from_cells(const PackedByteArray& cells);
    static void rasterize_transform_in(cybersand::World& world, std::vector<std::int32_t>* indices,
        std::uint16_t body_id, Vector2 center, double rotation, Vector2 half_size);
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
    [[nodiscard]] static bool in_bounds(std::int64_t x, std::int64_t y);
};

}  // namespace godot
