#include "cyber_native_cell_world.hpp"

#include "cybersand/material_rules.hpp"
#include "cybersand/default_demo_recipe.hpp"
#include "cybersand/ejection_search.hpp"
#include "cybersand/sha256.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <cmath>
#include <numbers>
#include <span>
#include <stdexcept>
#include <string>
#include <thread>
#include <unordered_map>

namespace godot {
namespace {

constexpr std::int32_t kInputBodyId = 0;
constexpr std::int32_t kInputCenterX = 1;
constexpr std::int32_t kInputCenterY = 2;
constexpr std::int32_t kInputRotation = 3;
constexpr std::int32_t kInputSizeX = 4;
constexpr std::int32_t kInputSizeY = 5;
constexpr std::int32_t kInputVelocityX = 6;
constexpr std::int32_t kInputVelocityY = 7;
constexpr std::int32_t kInputAngularVelocity = 8;
constexpr std::int32_t kInputMass = 9;
constexpr std::int32_t kInputSampleSerial = 10;
// All integer values up to this bound are exactly representable by the ABI's
// float32 carrier. The live bridge wraps its sample serial much earlier.
constexpr double kMaximumBodySampleSerial = 16'777'215.0;

constexpr double kMaximumBodySweepDistance = 32.0;
constexpr double kBodySweepSampleSpacing = 1.0;
constexpr std::int32_t kMaximumBodySweepSteps = 24;
constexpr std::int32_t kMaximumEjectionDistance = 8;
constexpr double kBodyDisplacementReactionImpulse = 0.18;
constexpr double kBodyBoundaryPressureImpulse = 0.19;
constexpr double kBodyPixelContactImpulse = 0.025;
constexpr double kMaximumBodyImpulsePerTick = 3.0;
constexpr double kGravityImpulsePerMassTick = 92.0 / 60.0;
constexpr double kGranularYieldVelocityResponse = 0.18;
constexpr double kGranularImpulseCapacityPerSample = 2.0;
constexpr double kMaximumGranularBearingImpulse = 20.0;
constexpr double kGranularSettleVelocity = 4.0;
constexpr double kMaximumGranularBearingCorrection = 0.5;
constexpr double kGranularBearingCorrectionFraction = 0.99;

[[nodiscard]] Vector2 normalized_or_zero(Vector2 value) {
    const auto length = value.length();
    return length > 0.000001 ? value / length : Vector2{};
}

template<class... Values>
Array ejection_array(Values... values) {
    Array out;
    (out.push_back(values), ...);
    return out;
}

void ejection_hash_word(std::string& bytes, std::uint64_t value) {
    for (unsigned i = 0; i < 8; ++i) bytes.push_back(static_cast<char>(value >> (i * 8U)));
}

String ejection_hex(std::uint64_t value) {
    char buffer[17]{};
    std::snprintf(buffer, sizeof(buffer), "%016llx", static_cast<unsigned long long>(value));
    return String(buffer);
}

}  // namespace

CyberNativeCellWorld::CyberNativeCellWorld() {
    create_world();
    reset_demo_world();
}

CyberNativeCellWorld::~CyberNativeCellWorld() = default;

void CyberNativeCellWorld::_bind_methods() {
    ClassDB::bind_method(D_METHOD("diagnostic_reset", "options"), &CyberNativeCellWorld::diagnostic_reset);
    ClassDB::bind_method(D_METHOD("diagnostic_fill_rect", "origin", "size", "material", "state_b"), &CyberNativeCellWorld::diagnostic_fill_rect, DEFVAL(0));
    ClassDB::bind_method(D_METHOD("diagnostic_relocate_cell", "from", "to"),
                         &CyberNativeCellWorld::diagnostic_relocate_cell);
    ClassDB::bind_method(D_METHOD("diagnostic_snapshot", "origin", "size", "include_histogram"), &CyberNativeCellWorld::diagnostic_snapshot, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("diagnostic_body_metrics"), &CyberNativeCellWorld::diagnostic_body_metrics);
    ClassDB::bind_method(D_METHOD("diagnostic_bearing_state"), &CyberNativeCellWorld::diagnostic_bearing_state);
    ClassDB::bind_method(D_METHOD("diagnostic_bearing_candidate"), &CyberNativeCellWorld::diagnostic_bearing_candidate);
    ClassDB::bind_method(D_METHOD("diagnostic_ejection_capture", "maximum_failed", "maximum_success"), &CyberNativeCellWorld::diagnostic_ejection_capture);
    ClassDB::bind_method(D_METHOD("diagnostic_ejection_stream"), &CyberNativeCellWorld::diagnostic_ejection_stream);
    ClassDB::bind_method(D_METHOD("diagnostic_take_ejection_events"), &CyberNativeCellWorld::diagnostic_take_ejection_events);
    ClassDB::bind_method(D_METHOD("diagnostic_ejection_corpus"), &CyberNativeCellWorld::diagnostic_ejection_corpus);
    ClassDB::bind_method(D_METHOD("diagnostic_replay_ejection", "capsule"), &CyberNativeCellWorld::diagnostic_replay_ejection);
    ClassDB::bind_method(D_METHOD("get_water_experiment_policy"),
                         &CyberNativeCellWorld::get_water_experiment_policy);
    ClassDB::bind_method(D_METHOD("get_liquid_solver_policy"),
                         &CyberNativeCellWorld::get_liquid_solver_policy);
    ClassDB::bind_method(D_METHOD("get_liquid_policy_session_generation"),
                         &CyberNativeCellWorld::get_liquid_policy_session_generation);
    ClassDB::bind_method(D_METHOD("water_experiment_fill_rect", "origin", "size",
                                  "normalized_mass", "coherence"),
                         &CyberNativeCellWorld::water_experiment_fill_rect);
    ClassDB::bind_method(D_METHOD("water_experiment_erase_rect", "origin", "size"),
                         &CyberNativeCellWorld::water_experiment_erase_rect);
    ClassDB::bind_method(D_METHOD("water_experiment_observation", "origin", "size"),
                         &CyberNativeCellWorld::water_experiment_observation);
    ClassDB::bind_method(D_METHOD("get_physical_state_hash"), &CyberNativeCellWorld::get_physical_state_hash);
    ClassDB::bind_method(D_METHOD("get_physical_state_hash_version"),
                         &CyberNativeCellWorld::get_physical_state_hash_version);
    ClassDB::bind_method(D_METHOD("get_physical_state_format_version"),
                         &CyberNativeCellWorld::get_physical_state_format_version);
    ClassDB::bind_method(D_METHOD("inspect_inertial_cell", "point"), &CyberNativeCellWorld::inspect_inertial_cell);
    ClassDB::bind_method(D_METHOD("inspect_gas_compartments"), &CyberNativeCellWorld::inspect_gas_compartments);
    ClassDB::bind_method(D_METHOD("inspect_pressure_cell", "point"), &CyberNativeCellWorld::inspect_pressure_cell);
    ClassDB::bind_method(D_METHOD("get_pressure_flow_ledger"), &CyberNativeCellWorld::get_pressure_flow_ledger);
    ClassDB::bind_method(D_METHOD("get_liquid_comparison_hash", "projection_id"),
                         &CyberNativeCellWorld::get_liquid_comparison_hash);
    ClassDB::bind_method(D_METHOD("inspect_pressure_optimization"),
                         &CyberNativeCellWorld::inspect_pressure_optimization);
    ClassDB::bind_method(D_METHOD("get_liquid_run_receipt", "setup"), &CyberNativeCellWorld::get_liquid_run_receipt);
    ClassDB::bind_method(D_METHOD("get_applied_liquid_construction_receipt"), &CyberNativeCellWorld::get_applied_liquid_construction_receipt);
    ClassDB::bind_method(D_METHOD("get_liquid_construction_attempt"), &CyberNativeCellWorld::get_liquid_construction_attempt);
    ClassDB::bind_static_method("CyberNativeCellWorld", D_METHOD("auto_worker_threads", "logical_threads"), &CyberNativeCellWorld::auto_worker_threads);
    ClassDB::bind_static_method("CyberNativeCellWorld", D_METHOD("logical_processor_count"), &CyberNativeCellWorld::logical_processor_count);
    ClassDB::bind_method(D_METHOD("reset_demo_world"),
                         &CyberNativeCellWorld::reset_demo_world);
    ClassDB::bind_method(D_METHOD("get_default_demo_identity"), &CyberNativeCellWorld::get_default_demo_identity);
    ClassDB::bind_method(D_METHOD("simulation_tick"),
                         &CyberNativeCellWorld::simulation_tick);
    ClassDB::bind_method(D_METHOD("has_failed"), &CyberNativeCellWorld::has_failed);
    ClassDB::bind_method(D_METHOD("get_attempted_tick_index"),
                         &CyberNativeCellWorld::get_attempted_tick_index);
    ClassDB::bind_method(D_METHOD("emit_disc", "centre_x", "centre_y", "radius",
                                  "material_id", "emission_flags"),
                         &CyberNativeCellWorld::emit_disc, DEFVAL(0));
    ClassDB::bind_method(D_METHOD("paint_disc", "centre_x", "centre_y", "radius",
                                  "material_id", "emission_flags"),
                         &CyberNativeCellWorld::paint_disc, DEFVAL(0));
    ClassDB::bind_method(D_METHOD("apply_player_material_field", "center", "direction",
                                  "material_id", "mode", "phase"),
                         &CyberNativeCellWorld::apply_player_material_field);
    ClassDB::bind_method(D_METHOD("prepare_rigid_body_coupling", "states",
                                  "resolve_overlaps"),
                         &CyberNativeCellWorld::prepare_rigid_body_coupling,
                         DEFVAL(true));
    ClassDB::bind_method(D_METHOD("rigid_body_results"),
                         &CyberNativeCellWorld::rigid_body_results);
    ClassDB::bind_method(D_METHOD("rigid_body_id_at", "x", "y"),
                         &CyberNativeCellWorld::rigid_body_id_at);
    ClassDB::bind_method(D_METHOD("material_at", "x", "y"),
                         &CyberNativeCellWorld::material_at);
    ClassDB::bind_method(D_METHOD("box_collides", "origin", "size"),
                         &CyberNativeCellWorld::box_collides);
    ClassDB::bind_method(D_METHOD("character_box_collides", "origin", "size", "mode"),
                         &CyberNativeCellWorld::character_box_collides);
    ClassDB::bind_method(D_METHOD("character_disturb_granular", "origin", "size", "impact_speed"),
                         &CyberNativeCellWorld::character_disturb_granular);
    ClassDB::bind_method(D_METHOD("get_cells"), &CyberNativeCellWorld::get_cells);
    ClassDB::bind_method(D_METHOD("take_render_snapshot", "force_full"),
                         &CyberNativeCellWorld::take_render_snapshot,
                         DEFVAL(false));
    ClassDB::bind_method(D_METHOD("get_hard_surface_rectangles"),
                         &CyberNativeCellWorld::get_hard_surface_rectangles);
    ClassDB::bind_method(D_METHOD("get_hard_surface_chunk_rectangles"),
                         &CyberNativeCellWorld::get_hard_surface_chunk_rectangles);
    ClassDB::bind_method(D_METHOD("set_interest_center", "world_cell"),
                         &CyberNativeCellWorld::set_interest_center);
    ClassDB::bind_method(D_METHOD("set_simulation_window", "view_origin", "view_size",
                                  "horizontal_buffer", "vertical_buffer"),
                         &CyberNativeCellWorld::set_simulation_window);
    ClassDB::bind_method(D_METHOD("set_simulation_window_enabled", "enabled"),
                         &CyberNativeCellWorld::set_simulation_window_enabled);
    ClassDB::bind_method(D_METHOD("get_simulation_window_enabled"),
                         &CyberNativeCellWorld::get_simulation_window_enabled);
    ClassDB::bind_method(D_METHOD("set_cadence_lod_enabled", "enabled"),
                         &CyberNativeCellWorld::set_cadence_lod_enabled);
    ClassDB::bind_method(D_METHOD("get_cadence_lod_enabled"),
                         &CyberNativeCellWorld::get_cadence_lod_enabled);
    ClassDB::bind_method(D_METHOD("set_liquid_surface_adhesion_enabled", "enabled"),
                         &CyberNativeCellWorld::set_liquid_surface_adhesion_enabled);
    ClassDB::bind_method(D_METHOD("get_liquid_surface_adhesion_enabled"),
                         &CyberNativeCellWorld::get_liquid_surface_adhesion_enabled);

#define CYBERSAND_BIND_GETTER(name) \
    ClassDB::bind_method(D_METHOD("get_" #name), &CyberNativeCellWorld::get_##name)
    CYBERSAND_BIND_GETTER(revision);
    CYBERSAND_BIND_GETTER(hard_surface_revision);
    CYBERSAND_BIND_GETTER(tick_index);
    CYBERSAND_BIND_GETTER(moves_last_tick);
    CYBERSAND_BIND_GETTER(scanned_last_tick);
    CYBERSAND_BIND_GETTER(dormant_cells_skipped_last_tick);
    CYBERSAND_BIND_GETTER(active_blocks_last_tick);
    CYBERSAND_BIND_GETTER(eligible_blocks_last_tick);
    CYBERSAND_BIND_GETTER(adaptive_block_stride_last_tick);
    CYBERSAND_BIND_GETTER(deferred_blocks_last_tick);
    CYBERSAND_BIND_GETTER(frozen_blocks_last_tick);
    CYBERSAND_BIND_GETTER(scheduler_jobs_last_tick);
    CYBERSAND_BIND_GETTER(scheduler_parallel_phases_last_tick);
    CYBERSAND_BIND_GETTER(sparse_flight_moves_last_tick);
    CYBERSAND_BIND_GETTER(rigid_body_contacts_last_tick);
    CYBERSAND_BIND_GETTER(rigid_body_displaced_last_tick);
    CYBERSAND_BIND_GETTER(rigid_body_unresolved_last_tick);
    CYBERSAND_BIND_GETTER(simulation_time_ms);
    CYBERSAND_BIND_GETTER(worker_threads);
    CYBERSAND_BIND_GETTER(backend_name);
    CYBERSAND_BIND_GETTER(last_tick_error);
    CYBERSAND_BIND_GETTER(tick_failure_count);
#undef CYBERSAND_BIND_GETTER

    ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY, "cells"), "", "get_cells");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "last_tick_error"), "",
                 "get_last_tick_error");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "tick_failure_count"), "",
                 "get_tick_failure_count");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "simulation_window_enabled"),
                 "set_simulation_window_enabled", "get_simulation_window_enabled");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "cadence_lod_enabled"),
                 "set_cadence_lod_enabled", "get_cadence_lod_enabled");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "revision"), "", "get_revision");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "hard_surface_revision"), "",
                 "get_hard_surface_revision");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "tick_index"), "", "get_tick_index");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "moves_last_tick"), "",
                 "get_moves_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "scanned_last_tick"), "",
                 "get_scanned_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "dormant_cells_skipped_last_tick"), "",
                 "get_dormant_cells_skipped_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "active_blocks_last_tick"), "",
                 "get_active_blocks_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "eligible_blocks_last_tick"), "",
                 "get_eligible_blocks_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "adaptive_block_stride_last_tick"), "",
                 "get_adaptive_block_stride_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "deferred_blocks_last_tick"), "",
                 "get_deferred_blocks_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "frozen_blocks_last_tick"), "",
                 "get_frozen_blocks_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "scheduler_jobs_last_tick"), "",
                 "get_scheduler_jobs_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "scheduler_parallel_phases_last_tick"), "",
                 "get_scheduler_parallel_phases_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "sparse_flight_moves_last_tick"), "",
                 "get_sparse_flight_moves_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "rigid_body_contacts_last_tick"), "",
                 "get_rigid_body_contacts_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "rigid_body_displaced_last_tick"), "",
                 "get_rigid_body_displaced_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "rigid_body_unresolved_last_tick"), "",
                 "get_rigid_body_unresolved_last_tick");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "simulation_time_ms"), "",
                 "get_simulation_time_ms");
}

std::int64_t CyberNativeCellWorld::auto_worker_threads(std::int64_t logical_threads) {
    return logical_threads < 4 ? 2 : logical_threads < 12 ? 4 : 6;
}

std::int64_t CyberNativeCellWorld::logical_processor_count() {
    return std::max(1U, std::thread::hardware_concurrency());
}

void CyberNativeCellWorld::create_world() {
    try {
        const auto processors = std::max(1U, std::thread::hardware_concurrency());
        const auto automatic_threads = static_cast<std::uint32_t>(auto_worker_threads(processors));
        const auto requested_threads = static_cast<std::int64_t>(
            ProjectSettings::get_singleton()->get_setting(
                "cybersand/native_worker_threads", 0));
        worker_threads_ = requested_threads > 0
                              ? static_cast<std::uint32_t>(std::clamp<std::int64_t>(
                                    requested_threads, 1, std::min<std::uint32_t>(32U, processors)))
                              : automatic_threads;
#if defined(__EMSCRIPTEN__) && !defined(__EMSCRIPTEN_PTHREADS__)
        worker_threads_ = 1; // No-thread Web cannot instantiate a pthread pool.
#endif
        cybersand::WorldConfig config{};
        config.worker_threads = worker_threads_;
        config.backend = cybersand::SimulationBackend::PhasedInPlace;
        config.initial_chunk_reserve = 64;
        config.maximum_chunk_count = 128;
        config.active_core_capacity = static_cast<std::size_t>(std::clamp<std::int64_t>(
            ProjectSettings::get_singleton()->get_setting(
                "cybersand/native_active_core_capacity", 1024), 1, 1024));
        config.active_chunk_capacity = 128;
        config.parallel_job_threshold = 2;
        world_ = std::make_unique<cybersand::World>(config);
        render_exchange_ = std::make_unique<cybersand::RenderSnapshotExchange>(
            3, 64, static_cast<std::size_t>(kWorldWidth) * kWorldHeight * 2U);
        world_->reserve_region({0, 0, kWorldWidth, kWorldHeight});
        world_->configure_transient_obstacles({0, 0, kWorldWidth, kWorldHeight});
    } catch (const std::exception& error) {
        UtilityFunctions::push_error(String("CyberNativeCellWorld initialization failed: ") +
                                     error.what());
        world_.reset();
    }
}

bool CyberNativeCellWorld::reset_demo_world() {
    if (world_ == nullptr) return false;
    try {
        auto config = world_->config();
        config.physics_diagnostics = {};
        config.interaction_policy = {};
        config.liquid_solver_policy = {}; // The ordinary demo runs every liquid's default.
        config.maximum_rule_radius = kProtectedCurrentRuleRadius;
        auto candidate = std::make_unique<cybersand::World>(config);
        candidate->reserve_region({0, 0, kWorldWidth, kWorldHeight});
        candidate->configure_transient_obstacles({0, 0, kWorldWidth, kWorldHeight});
        candidate->set_liquid_surface_adhesion_enabled(liquid_surface_adhesion_enabled_);

        cybersand::demo::visit_default_demo_recipe([&](std::int32_t x, std::int32_t y, cybersand::Material material) {
            candidate->set(x, y, material);
        });

        candidate->set_simulation_region(world_->simulation_region());
        world_.swap(candidate);
        retire_liquid_construction_identity();
        ++liquid_policy_session_generation_;
        clear_ejection_capture();
        default_demo_recipe_active_ = true;
        reset_demo_coupling_parameters();
        render_snapshot_full_refresh_required_ = true;
        current_bodies_ = {};
        previous_bodies_ = {};
        clear_observations();
        last_stats_ = {};
        simulation_time_ms_ = 0.0;
        tick_failure_count_ = 0;
        last_tick_error_ = String{};
        render_cells_revision_ = UINT64_MAX;
        hard_surface_rectangles_revision_ = UINT64_MAX;
        hard_surface_chunk_rectangles_revision_ = UINT64_MAX;
        ++hard_surface_revision_;
        ++revision_;
        refresh_simulation_region();
        return true;
    } catch (const std::exception& error) {
        last_tick_error_ = String("Reset failed: ") + error.what();
        return false;
    }
}

Dictionary CyberNativeCellWorld::get_default_demo_identity() const {
    if (!world_ || !default_demo_recipe_active_) return {};
    Dictionary identity;
    identity["native_recipe_id"] = String(cybersand::demo::kDefaultRecipeIdentity.data());
    identity["session_generation"] = static_cast<std::int64_t>(liquid_policy_session_generation_);
    identity["prepared"] = !applied_liquid_construction_receipt_.is_empty();
    identity["healthy"] = !world_->has_failed();
    return identity;
}

void CyberNativeCellWorld::reset_demo_coupling_parameters() noexcept {
    diagnostic_fixture_ = false;
    body_diagnostics_.reset();
    bearing_trace_.reset();
    bearing_candidate_ = cybersand::bearing_experiment::Mode::B0;
    candidate_observations_ = {};
    displacement_gain_ = kBodyDisplacementReactionImpulse;
    boundary_gain_ = kBodyBoundaryPressureImpulse;
    contact_gain_ = kBodyPixelContactImpulse;
    impulse_cap_ = kMaximumBodyImpulsePerTick;
    density_limit_ = 1.6;
}

bool CyberNativeCellWorld::simulation_tick() {
    if (world_ == nullptr || world_->has_failed()) return false;
    const auto start = std::chrono::steady_clock::now();
    bool succeeded = false;
    try {
        last_stats_ = world_->tick();
        if (last_stats_.moved_cells != 0U || last_stats_.deferred_events != 0U) ++revision_;
        succeeded = true;
    } catch (const std::exception& error) {
        ++tick_failure_count_;
        last_tick_error_ = error.what();
        // Do not turn partial cells/results into a new successful publication.
        last_stats_ = {};
        clear_observations();
    }
    simulation_time_ms_ = std::chrono::duration<double, std::milli>(
                              std::chrono::steady_clock::now() - start)
                              .count();
    return succeeded;
}

void CyberNativeCellWorld::emit_disc(std::int64_t centre_x, std::int64_t centre_y,
                                     std::int64_t radius, std::int64_t material_id,
                                     std::int64_t emission_flags) {
    if (world_ == nullptr || world_->has_failed() || radius < 0 || radius > 128 || material_id < 0 ||
        material_id > 255 || !cybersand::valid_material(static_cast<std::uint16_t>(material_id))) {
        return;
    }
    const auto material = static_cast<cybersand::Material>(material_id);
    const auto& definition = cybersand::MaterialRules::descriptor(material);
    const auto radius_squared = radius * radius;
    bool changed = false;
    bool hard_changed = false;
    for (auto offset_y = -radius; offset_y <= radius; ++offset_y) {
        for (auto offset_x = -radius; offset_x <= radius; ++offset_x) {
            if (offset_x * offset_x + offset_y * offset_y > radius_squared) continue;
            const auto x = centre_x + offset_x;
            const auto y = centre_y + offset_y;
            if (!in_bounds(x, y)) continue;
            const auto before = world_->stored_material(x, y);
            auto state_a = static_cast<std::uint16_t>(definition.initial_state_a);
            auto state_b = definition.initial_state_b;
            if (material == cybersand::Material::Water) {
                state_a = world_->config().water_experiment_policy.maximum();
            }
            if (material == cybersand::Material::Water && (emission_flags & 1) != 0) {
                state_b = world_->config().water_experiment_policy.coherence_ticks();
            }
            if (!world_->set_cell_state(x, y, material, state_a, state_b)) {
                continue;
            }
            changed = true;
            hard_changed = hard_changed ||
                           cybersand::MaterialRules::is_hard_surface(before) !=
                               cybersand::MaterialRules::is_hard_surface(material);
        }
    }
    if (changed) ++revision_;
    if (hard_changed) ++hard_surface_revision_;
}

void CyberNativeCellWorld::paint_disc(std::int64_t centre_x, std::int64_t centre_y,
                                      std::int64_t radius, std::int64_t material_id,
                                      std::int64_t emission_flags) {
    emit_disc(centre_x, centre_y, radius, material_id, emission_flags);
}

void CyberNativeCellWorld::prepare_rigid_body_coupling(
    const PackedFloat32Array& states, bool resolve_overlaps) {
    if (world_ == nullptr || world_->has_failed()) return;
    world_->clear_transient_obstacles();
    clear_observations();
    parse_body_states(states);

    raster_indices_.clear();
    for (std::size_t body_id = 1; body_id < current_bodies_.size(); ++body_id) {
        const auto& body = current_bodies_[body_id];
        if (!body.valid) continue;
        const auto& previous = previous_bodies_[body_id];
        if (previous.valid) rasterize_body_sweep(body, previous);
        else rasterize_body(body);
    }
    if (resolve_overlaps) reconcile_swept_overlaps();

    world_->clear_transient_obstacles();
    raster_indices_.clear();
    for (std::size_t body_id = 1; body_id < current_bodies_.size(); ++body_id) {
        if (current_bodies_[body_id].valid) rasterize_body(current_bodies_[body_id]);
    }
    if (resolve_overlaps) {
        accumulate_boundary_pressure();
        accumulate_granular_bearing();
    }
    previous_bodies_ = current_bodies_;
}

void CyberNativeCellWorld::clear_observations() {
    observations_ = {};
    if (diagnostic_fixture_) candidate_observations_ = {};
    if (body_diagnostics_) *body_diagnostics_ = {};
    if (bearing_trace_) *bearing_trace_ = {};
}

void CyberNativeCellWorld::parse_body_states(const PackedFloat32Array& states) {
    current_bodies_ = parse_body_state_values(states, false);
}

CyberNativeCellWorld::BodyStates CyberNativeCellWorld::parse_body_state_values(
    const PackedFloat32Array& states, bool strict) {
    BodyStates bodies{};
    if (strict && (states.size() % kInputStride != 0 ||
        states.size() / kInputStride > cybersand::World::kMaximumTransientBodies))
        throw std::invalid_argument("Initial body input exceeds its fixed record bound");
    const auto count = std::min<std::int64_t>(
        cybersand::World::kMaximumTransientBodies, states.size() / kInputStride);
    for (std::int64_t body_index = 0; body_index < count; ++body_index) {
        const auto offset = body_index * kInputStride;
        bool finite_record = true;
        for (std::int32_t field = 0; field < kInputStride; ++field) {
            finite_record = finite_record && std::isfinite(states[offset + field]);
        }
        if (!finite_record) {
            if (strict) throw std::invalid_argument("Initial body input contains a nonfinite value");
            continue;
        }
        const double input_id = states[offset + kInputBodyId];
        const double serial = states[offset + kInputSampleSerial];
        if (input_id < 1.0 || input_id > cybersand::World::kMaximumTransientBodies ||
            std::trunc(input_id) != input_id || serial < 0.0 ||
            serial > kMaximumBodySampleSerial || std::trunc(serial) != serial ||
            states[offset + kInputSizeX] <= 0.0F ||
            states[offset + kInputSizeY] <= 0.0F ||
            states[offset + kInputMass] <= 0.0F) {
            if (strict) throw std::invalid_argument("Initial body input has invalid identity, size, mass or serial");
            continue;
        }
        const auto id_value = static_cast<std::int64_t>(input_id);
        auto& body = bodies[static_cast<std::size_t>(id_value)];
        if (body.valid) {
            if (strict) throw std::invalid_argument("Initial body input duplicates a body identity");
            continue;
        }
        body.id = static_cast<std::uint16_t>(id_value);
        body.center = {states[offset + kInputCenterX], states[offset + kInputCenterY]};
        body.rotation = states[offset + kInputRotation];
        body.half_size = {
            std::max(0.5, static_cast<double>(states[offset + kInputSizeX]) * 0.5),
            std::max(0.5, static_cast<double>(states[offset + kInputSizeY]) * 0.5),
        };
        body.velocity = {states[offset + kInputVelocityX], states[offset + kInputVelocityY]};
        body.angular_velocity = states[offset + kInputAngularVelocity];
        body.mass = std::max(0.001, static_cast<double>(states[offset + kInputMass]));
        body.sample_serial = static_cast<std::int32_t>(serial);
        body.valid = true;
    }
    return bodies;
}

void CyberNativeCellWorld::rasterize_body(const BodyState& body) {
    rasterize_transform(body.id, body.center, body.rotation, body.half_size);
}

void CyberNativeCellWorld::rasterize_body_sweep(const BodyState& body,
                                                const BodyState& previous) {
    const auto travel = static_cast<double>(body.center.distance_to(previous.center));
    if (travel > kMaximumBodySweepDistance) {
        rasterize_body(body);
        return;
    }
    const auto rotation_delta = std::remainder(
        body.rotation - previous.rotation, 2.0 * std::numbers::pi);
    const auto rotational_travel = std::abs(rotation_delta) *
        std::max(body.half_size.length(), previous.half_size.length());
    const auto sweep_extent = std::max(travel, rotational_travel);
    if (sweep_extent <= kBodySweepSampleSpacing) {
        rasterize_body(body);
        return;
    }
    const auto steps = static_cast<std::int32_t>(std::clamp(
        std::ceil(sweep_extent / kBodySweepSampleSpacing),
        1.0, static_cast<double>(kMaximumBodySweepSteps)));
    for (std::int32_t step = 0; step <= steps; ++step) {
        const auto weight = static_cast<double>(step) / steps;
        rasterize_transform(
            body.id,
            previous.center.lerp(body.center, weight),
            previous.rotation + rotation_delta * weight,
            previous.half_size.lerp(body.half_size, weight));
    }
}

void CyberNativeCellWorld::rasterize_transform(std::uint16_t body_id, Vector2 center,
                                               double rotation, Vector2 half_size) {
    rasterize_transform_in(*world_, &raster_indices_, body_id, center, rotation, half_size);
}

void CyberNativeCellWorld::rasterize_transform_in(cybersand::World& world,
    std::vector<std::int32_t>* indices, std::uint16_t body_id, Vector2 center,
    double rotation, Vector2 half_size) {
    const auto cosine = std::cos(rotation);
    const auto sine = std::sin(rotation);
    const Vector2 extent{
        std::abs(cosine) * half_size.x + std::abs(sine) * half_size.y,
        std::abs(sine) * half_size.x + std::abs(cosine) * half_size.y,
    };
    // Clamp in floating point before conversion: an escaped body may be far
    // outside the cell world, but must not overflow an integer raster bound.
    const auto first_x = static_cast<std::int32_t>(std::clamp(
        std::floor(static_cast<double>(center.x) - extent.x), 0.0, double(kWorldWidth - 1)));
    const auto last_x = static_cast<std::int32_t>(std::clamp(
        std::ceil(static_cast<double>(center.x) + extent.x) - 1.0, 0.0, double(kWorldWidth - 1)));
    const auto first_y = static_cast<std::int32_t>(std::clamp(
        std::floor(static_cast<double>(center.y) - extent.y), 0.0, double(kWorldHeight - 1)));
    const auto last_y = static_cast<std::int32_t>(std::clamp(
        std::ceil(static_cast<double>(center.y) + extent.y) - 1.0, 0.0, double(kWorldHeight - 1)));
    for (auto y = first_y; y <= last_y; ++y) {
        for (auto x = first_x; x <= last_x; ++x) {
            const Vector2 delta{static_cast<double>(x) + 0.5 - center.x,
                                static_cast<double>(y) + 0.5 - center.y};
            const Vector2 local{cosine * delta.x + sine * delta.y,
                                -sine * delta.x + cosine * delta.y};
            if (std::abs(local.x) > half_size.x || std::abs(local.y) > half_size.y) continue;
            if (world.set_transient_obstacle(x, y, body_id)) {
                if (indices) indices->push_back(y * kWorldWidth + x);
            }
        }
    }
}

void CyberNativeCellWorld::reconcile_swept_overlaps() {
    for (const auto cell_index : raster_indices_) {
        const auto x = cell_index % kWorldWidth;
        const auto y = cell_index / kWorldWidth;
        const auto body_id = world_->transient_obstacle_at(x, y);
        if (body_id != 0U && world_->stored_material(x, y) != cybersand::Material::Empty) {
            reconcile_overlap(cell_index, body_id);
        }
    }
}

void CyberNativeCellWorld::reconcile_overlap(std::int32_t cell_index,
                                             std::uint16_t body_id) {
    if (body_id == 0U || body_id >= current_bodies_.size()) return;
    const auto& body = current_bodies_[body_id];
    if (!body.valid) return;
    const auto x = cell_index % kWorldWidth;
    const auto y = cell_index / kWorldWidth;
    const auto material = world_->stored_material(x, y);
    auto& observation = observations_[body_id];
    ++observation.contacts;

    double penetration = 0.5;
    Vector2 outward{};
    if (cell_inside_body(body, x, y)) {
        outward = overlap_normal(body, x, y, penetration);
    } else {
        const auto travel = body.center - previous_bodies_[body_id].center;
        outward = normalized_or_zero(travel);
        if (outward.length_squared() <= 0.000001) {
            outward = overlap_normal(body, x, y, penetration);
        }
    }

    if (cybersand::MaterialRules::is_hard_surface(material)) {
        // Rapier owns hard contacts through the separately generated static
        // collider. A second delayed correction here is the bounce/tunnelling bug.
        return;
    }
    if (!cybersand::MaterialRules::descriptor(material).movable) {
        ++observation.unresolved;
        return;
    }

    const auto target = find_ejection_target(x, y, body_id, outward, penetration);
    if (ejection_capture_stream_ || ejection_capture_failed_cap_ != 0 || ejection_capture_success_cap_ != 0)
        capture_ejection(x, y, body_id, outward, penetration, target);
    if (target.x < 0 || !world_->relocate_stored_cell(x, y, target.x, target.y)) {
        if (target.x >= 0 && (ejection_capture_stream_ || ejection_capture_failed_cap_ != 0 || ejection_capture_success_cap_ != 0))
            ++ejection_capture_relocation_refused_;
        ++observation.unresolved;
        const auto impulse = -outward * displacement_gain_;
        if (body_diagnostics_) (*body_diagnostics_)[body_id].displacement += impulse;
        record_impulse(body_id, impulse);
        return;
    }
    ++observation.displaced;
    const auto impulse = -outward * displacement_gain_ * density_scale(material);
    if (body_diagnostics_) (*body_diagnostics_)[body_id].displacement += impulse;
    record_impulse(body_id, impulse);
    ++revision_;
}

bool CyberNativeCellWorld::cell_inside_body(const BodyState& body,
                                            std::int32_t x, std::int32_t y) const {
    const auto cosine = std::cos(body.rotation);
    const auto sine = std::sin(body.rotation);
    const Vector2 delta{static_cast<double>(x) + 0.5 - body.center.x,
                        static_cast<double>(y) + 0.5 - body.center.y};
    const Vector2 local{cosine * delta.x + sine * delta.y,
                        -sine * delta.x + cosine * delta.y};
    return std::abs(local.x) <= body.half_size.x &&
           std::abs(local.y) <= body.half_size.y;
}

Vector2 CyberNativeCellWorld::overlap_normal(const BodyState& body,
                                             std::int32_t x, std::int32_t y,
                                             double& penetration) const {
    const auto cosine = std::cos(body.rotation);
    const auto sine = std::sin(body.rotation);
    const Vector2 delta{static_cast<double>(x) + 0.5 - body.center.x,
                        static_cast<double>(y) + 0.5 - body.center.y};
    const Vector2 local{cosine * delta.x + sine * delta.y,
                        -sine * delta.x + cosine * delta.y};
    const auto x_penetration = body.half_size.x - std::abs(local.x) + 0.5;
    const auto y_penetration = body.half_size.y - std::abs(local.y) + 0.5;
    Vector2 local_normal{};
    if (x_penetration < y_penetration) {
        local_normal = {local.x >= 0.0 ? 1.0 : -1.0, 0.0};
        penetration = std::max(0.5, x_penetration);
    } else {
        local_normal = {0.0, local.y >= 0.0 ? 1.0 : -1.0};
        penetration = std::max(0.5, y_penetration);
    }
    return {cosine * local_normal.x - sine * local_normal.y,
            sine * local_normal.x + cosine * local_normal.y};
}

Vector2i CyberNativeCellWorld::find_ejection_target(std::int32_t source_x,
                                                    std::int32_t source_y,
                                                    std::uint16_t source_body_id,
                                                    Vector2 outward_normal,
                                                    double penetration) const {
    const Vector2 tangent{-outward_normal.y, outward_normal.x};
    const Vector2 source_center{static_cast<double>(source_x) + 0.5,
                                static_cast<double>(source_y) + 0.5};
    const auto first = std::max(1, static_cast<std::int32_t>(std::ceil(penetration)));
    const auto point = cybersand::ejection::search({source_x, source_y}, source_body_id, first,
        [this](cybersand::ejection::Point p) {
            if (!in_bounds(p.x, p.y)) return cybersand::ejection::Cell{};
            return cybersand::ejection::Cell{true,
                world_->stored_material(p.x, p.y) == cybersand::Material::Empty,
                cybersand::MaterialRules::is_hard_surface(world_->stored_material(p.x, p.y)),
                world_->transient_obstacle_at(p.x, p.y)};
        },
        [source_center, outward_normal, tangent](std::int32_t distance, std::int32_t offset) {
            const auto candidate = source_center + outward_normal * distance + tangent * offset;
            return cybersand::ejection::Point{static_cast<std::int32_t>(std::floor(candidate.x)),
                                              static_cast<std::int32_t>(std::floor(candidate.y))};
        }, [](cybersand::ejection::Point, cybersand::ejection::Reason) {});
    return {point.x, point.y};
}

bool CyberNativeCellWorld::ejection_path_reachable(std::int32_t source_x,
                                                    std::int32_t source_y,
                                                    std::int32_t target_x,
                                                    std::int32_t target_y,
                                                    std::uint16_t source_body_id) const {
    return cybersand::ejection::path_reason({source_x, source_y}, {target_x, target_y}, source_body_id,
        [this](cybersand::ejection::Point p) {
            if (!in_bounds(p.x, p.y)) return cybersand::ejection::Cell{};
            return cybersand::ejection::Cell{true,
                world_->stored_material(p.x, p.y) == cybersand::Material::Empty,
                cybersand::MaterialRules::is_hard_surface(world_->stored_material(p.x, p.y)),
                world_->transient_obstacle_at(p.x, p.y)};
        }) == cybersand::ejection::Reason::Accepted;
}

void CyberNativeCellWorld::accumulate_boundary_pressure() {
    static constexpr std::array<Vector2i, 4> directions{{
        {0, -1}, {1, 0}, {0, 1}, {-1, 0},
    }};
    for (const auto cell_index : raster_indices_) {
        const auto x = cell_index % kWorldWidth;
        const auto y = cell_index / kWorldWidth;
        const auto body_id = world_->transient_obstacle_at(x, y);
        if (body_id == 0U || body_id >= observations_.size()) continue;
        for (const auto direction : directions) {
            const auto target_x = x + direction.x;
            const auto target_y = y + direction.y;
            if (!in_bounds(target_x, target_y) ||
                world_->transient_obstacle_at(target_x, target_y) != 0U) {
                continue;
            }
            const auto material = world_->stored_material(target_x, target_y);
            if (material == cybersand::Material::Wall ||
                !cybersand::MaterialRules::descriptor(material).movable) {
                continue;
            }
            ++observations_[body_id].contacts;
            const Vector2 normal{-static_cast<double>(direction.x),
                                 -static_cast<double>(direction.y)};
            const auto impulse = normal * boundary_gain_ * density_scale(material, 0.01);
            if (body_diagnostics_) {
                auto& diagnostic = (*body_diagnostics_)[body_id];
                diagnostic.boundary += impulse;
                const auto face = direction.y < 0 ? 0U : direction.x > 0 ? 1U : direction.y > 0 ? 2U : 3U;
                ++diagnostic.faces[face * cybersand::kMaterialDefinitions.size() +
                                   static_cast<std::size_t>(material)];
            }
            record_impulse(body_id, impulse);
        }
    }
}

void CyberNativeCellWorld::accumulate_granular_bearing() {
    std::array<std::uint16_t, cybersand::World::kMaximumTransientBodies + 1U>
        support_samples{};
    for (const auto cell_index : raster_indices_) {
        const auto x = cell_index % kWorldWidth;
        const auto y = cell_index / kWorldWidth;
        const auto body_id = world_->transient_obstacle_at(x, y);
        auto* trace = body_id == 1U ? bearing_trace_.get() : nullptr;
        if (trace) {
            ++trace->mask_cells;
            if (!in_bounds(x, y + 1)) ++trace->outside_below;
            else if (world_->transient_obstacle_at(x, y + 1) != 0U) ++trace->masked_below;
        }
        if (body_id == 0U || body_id >= current_bodies_.size() ||
            !in_bounds(x, y + 1) || world_->transient_obstacle_at(x, y + 1) != 0U) {
            continue;
        }
        if (!diagnostic_fixture_) {
            if (world_->granular_support_at(x,y+1,false,false)) ++support_samples[body_id];
            continue;
        }
        cybersand::World::GranularSupportInspection inspection;
        auto& work = candidate_observations_[body_id];
        ++work.boundaries;
        bool supported = false;
        std::int32_t selected_y = y + 1;
        cybersand::bearing_experiment::Ray ray;
        if (bearing_candidate_ == cybersand::bearing_experiment::Mode::A2 &&
            current_bodies_[body_id].velocity.y > 0) {
            const auto& body = current_bodies_[body_id];
            work.lookahead = cybersand::bearing_experiment::lookahead(body.velocity.y);
            const auto lower = cybersand::bearing_experiment::lower_edge(body.center.x, body.center.y,
                body.rotation, body.half_size.x, body.half_size.y, static_cast<double>(x)+0.5);
            std::array<cybersand::World::GranularSupportInspection,3> inspections{};
            std::size_t visited=0;
            ray = cybersand::bearing_experiment::admit(x,y+1,lower,work.lookahead,
                [this,&work,&inspections,&visited](std::int32_t px,std::int32_t py) {
                    auto& i=inspections[visited++];
                    i.reason=1;
                    cybersand::bearing_experiment::Cell cell;
                    cell.in_bounds=in_bounds(px,py);
                    if (!cell.in_bounds) return cell;
                    cell.hard=cybersand::MaterialRules::is_hard_surface(world_->stored_material(px,py));
                    cell.body=world_->transient_obstacle_at(px,py);
                    if (!cell.hard && cell.body==0U) {
                        ++work.predicate_queries;
                        cell.supported=world_->granular_support_at(px,py,false,false,&i);
                    } else i.reason=1;
                    cell.reason=i.reason;cell.stable_below=i.stable_below;
                    cell.paused=i.paused;cell.fresh=i.fresh;
                    cell.unsupported=i.unsupported;cell.missing=i.missing;
                    return cell;
                });
            work.cell_tests+=ray.used;
            work.extra_cells+=ray.used>0 ? ray.used-1U : 0U;
            work.maximum_ray_cells=std::max(work.maximum_ray_cells,ray.used);
            work.invalid_geometry+=ray.stop==cybersand::bearing_experiment::Stop::InvalidGeometry;
            const bool current=ray.used>0 && ray.steps[0].cell.supported;
            work.current_support+=current;
            supported=ray.selected>=0;
            if (supported) {
                selected_y=ray.steps[static_cast<std::size_t>(ray.selected)].y;
                inspection=inspections[static_cast<std::size_t>(ray.selected)];
                work.maximum_hit_distance=std::max(work.maximum_hit_distance,
                    ray.steps[static_cast<std::size_t>(ray.selected)].distance);
                work.predicted_only+=!current;
            } else if (ray.used>0) {
                inspection=inspections[ray.used-1U];selected_y=ray.steps[ray.used-1U].y;
            } else inspection.reason=1;
        } else {
            // B0/Y1 and zero/rising A2 retain the exact original query path.
            supported=world_->granular_support_at(x,y+1,false,false,trace ? &inspection : nullptr);
            ++work.cell_tests; ++work.predicate_queries;
            work.maximum_ray_cells=1;
            work.current_support+=supported;
        }
        work.selected_support+=supported;
        if (trace) {
            trace->raw_support += supported;
            if (trace->used < trace->probes.size()) {
                trace->admissions[trace->used]=ray;
                trace->probes[trace->used++] = {x, selected_y, inspection};
            }
            else ++trace->dropped;
        }
        if (supported) {
            ++support_samples[body_id];
        }
    }

    for (std::size_t body_id = 1; body_id < current_bodies_.size(); ++body_id) {
        const auto samples = support_samples[body_id];
        const auto& body = current_bodies_[body_id];
        if (body_id == 1U && bearing_trace_) {
            const auto& previous = previous_bodies_[body_id];
            bearing_trace_->previous_valid = previous.valid;
            bearing_trace_->downward_travel = previous.valid
                ? std::max(0.0, static_cast<double>(body.center.y - previous.center.y)) : 0.0;
        }
        if (!body.valid || samples == 0U || body.velocity.y <= 0.0) continue;

        const auto gravity = kGravityImpulsePerMassTick * body.mass;
        const auto arrest = body.velocity.y * body.mass;
        const auto yielding = gravity + std::max(
            0.0, body.velocity.y - kGravityImpulsePerMassTick) *
            body.mass * (bearing_candidate_ == cybersand::bearing_experiment::Mode::Y1
                ? 1.0 : kGranularYieldVelocityResponse);
        const auto capacity = std::min(
            kMaximumGranularBearingImpulse,
            static_cast<double>(samples) * kGranularImpulseCapacityPerSample);
        const auto magnitude = std::min({arrest, yielding, capacity});
        if (magnitude <= 0.0) continue;

        auto& observation = observations_[body_id];
        observation.bearing = {0.0, -magnitude};
        observation.contacts += samples;
        const auto& previous = previous_bodies_[body_id];
        if (previous.valid && body.velocity.y <= kGranularSettleVelocity) {
            const auto downward_travel = std::max(
                0.0, static_cast<double>(body.center.y - previous.center.y));
            observation.correction.y = -std::min(
                kMaximumGranularBearingCorrection,
                downward_travel * kGranularBearingCorrectionFraction);
        }
        if (body_diagnostics_) {
            auto& diagnostic = (*body_diagnostics_)[body_id];
            diagnostic.bearing = observation.bearing;
            diagnostic.support_samples = samples;
        }
    }
}

void CyberNativeCellWorld::record_impulse(std::uint16_t body_id, Vector2 impulse) {
    if (body_id == 0U || body_id >= observations_.size()) return;
    auto combined = observations_[body_id].impulse + impulse;
    if (combined.length() > impulse_cap_) {
        if (body_diagnostics_) ++(*body_diagnostics_)[body_id].intermediate_caps;
        combined = combined.normalized() * impulse_cap_;
    }
    observations_[body_id].impulse = combined;
}

PackedFloat32Array CyberNativeCellWorld::rigid_body_results() const {
    PackedFloat32Array results;
    if (world_ == nullptr || world_->has_failed()) return results;
    for (std::size_t body_id = 1; body_id < current_bodies_.size(); ++body_id) {
        const auto& body = current_bodies_[body_id];
        if (!body.valid) continue;
        auto observation = observations_[body_id];
        const auto contact_x = world_->transient_contact_impulse_x(
            static_cast<std::uint16_t>(body_id));
        const auto contact_y = world_->transient_contact_impulse_y(
            static_cast<std::uint16_t>(body_id));
        observation.contacts += world_->transient_contact_count(
            static_cast<std::uint16_t>(body_id));
        observation.impulse += Vector2{
            static_cast<double>(contact_x) / 1000.0 * contact_gain_,
            static_cast<double>(contact_y) / 1000.0 * contact_gain_,
        };
        if (observation.impulse.length() > impulse_cap_) {
            observation.impulse = observation.impulse.normalized() *
                                  impulse_cap_;
        }
        if (observation.bearing.y < 0.0) {
            observation.impulse += observation.bearing;
            // Boundary/contact response and bearing share the cellular owner.
            // Do not stack upward terms beyond the local load/yield target.
            observation.impulse.y = std::max(observation.impulse.y,
                                             observation.bearing.y);
        }
        results.append(static_cast<float>(body_id));
        results.append(static_cast<float>(observation.impulse.x));
        results.append(static_cast<float>(observation.impulse.y));
        results.append(static_cast<float>(observation.correction.x));
        results.append(static_cast<float>(observation.correction.y));
        results.append(static_cast<float>(observation.contacts));
        results.append(static_cast<float>(observation.displaced));
        results.append(static_cast<float>(observation.unresolved));
        results.append(static_cast<float>(body.sample_serial));
    }
    return results;
}

std::int64_t CyberNativeCellWorld::material_at(std::int64_t x, std::int64_t y) const {
    if (world_ == nullptr || !in_bounds(x, y)) {
        return static_cast<std::int64_t>(cybersand::Material::Wall);
    }
    return static_cast<std::int64_t>(world_->get(x, y));
}

std::int64_t CyberNativeCellWorld::rigid_body_id_at(std::int64_t x, std::int64_t y) const {
    if (world_ == nullptr || !in_bounds(x, y)) return 0;
    return world_->transient_obstacle_at(x, y);
}

bool CyberNativeCellWorld::box_collides(Vector2 origin, Vector2 size) const {
    return character_box_collides(origin, size, 0);
}

bool CyberNativeCellWorld::character_box_collides(Vector2 origin, Vector2 size, std::int64_t mode) const {
    return character_box_collides_in(world_.get(), origin, size, mode);
}

bool CyberNativeCellWorld::character_box_collides_in(
    const cybersand::World* world, Vector2 origin, Vector2 size, std::int64_t mode) {
    // 0: enclosure/volume, 1: downward feet, 2: sides, 3: upward head.
    // Bounded owner query; malformed/out-of-world queries fail closed.
    if (!origin.is_finite() || !size.is_finite() || size.x <= 0 || size.y <= 0 ||
        size.x > 32 || size.y > 32 || mode < 0 || mode > 3 ||
        origin.x < 0 || origin.y < 0 || origin.x + size.x > kWorldWidth ||
        origin.y + size.y > kWorldHeight || world == nullptr) return true;
    const auto first_x = static_cast<std::int32_t>(std::floor(origin.x + 0.001));
    const auto first_y = static_cast<std::int32_t>(std::floor(origin.y + 0.001));
    const auto last_x = static_cast<std::int32_t>(std::ceil(origin.x + size.x - 0.001)) - 1;
    const auto last_y = static_cast<std::int32_t>(std::ceil(origin.y + size.y - 0.001)) - 1;
    for (auto y = first_y; y <= last_y; ++y) for (auto x = first_x; x <= last_x; ++x) {
        const auto material = world->get(x, y);
        if (cybersand::MaterialRules::is_hard_surface(material)) return true;
        if ((mode == 1 && y != last_y) ||
            (mode == 2 && x != first_x && x != last_x) ||
            (mode == 3 && y != first_y)) continue;
        if (world->granular_support_at(x, y, mode >= 2)) return true;
    }
    return false;
}

std::int64_t CyberNativeCellWorld::character_disturb_granular(
    Vector2 origin, Vector2 size, double impact_speed) {
    if (world_ == nullptr || world_->has_failed() || !origin.is_finite() ||
        !size.is_finite() || !std::isfinite(impact_speed) || impact_speed < 24.0 ||
        size.x <= 0 || size.y <= 0 || size.x > 32 || size.y > 32 ||
        origin.x < 0 || origin.y < 0 || origin.x + size.x > kWorldWidth ||
        origin.y + size.y > kWorldHeight) {
        return 0;
    }

    const auto first_x = static_cast<std::int32_t>(std::floor(origin.x + 0.001));
    const auto first_y = static_cast<std::int32_t>(std::floor(origin.y + 0.001));
    const auto last_x = static_cast<std::int32_t>(std::ceil(origin.x + size.x - 0.001)) - 1;
    const auto contact_y =
        static_cast<std::int32_t>(std::ceil(origin.y + size.y - 0.001)) - 1;

    // A hard-surface collision remains wholly owned by the existing character /
    // terrain contract. Do not add granular disturbance merely because a mixed
    // contact also has an eligible grain at one foot edge.
    for (auto y = first_y; y <= contact_y; ++y) {
        for (auto x = first_x; x <= last_x; ++x) {
            if (cybersand::MaterialRules::is_hard_surface(
                    world_->stored_material(x, y))) {
                return 0;
            }
        }
    }

    const auto budget = impact_speed >= 72.0 ? 2 : 1;
    const bool left_first = (world_->tick_index() & 1U) == 0U;
    std::int64_t moved = 0;

    for (int pass = 0; pass < 2 && moved < budget; ++pass) {
        const bool use_left = pass == 0 ? left_first : !left_first;
        const auto source_x = use_left ? first_x : last_x;
        const auto outward = use_left ? -1 : 1;
        const auto target_x = source_x + outward;
        const auto target_y = contact_y - 1;
        if (!in_bounds(source_x, contact_y) || !in_bounds(target_x, target_y)) continue;

        const auto material = world_->stored_material(source_x, contact_y);
        if (!cybersand::MaterialRules::supports_granular_load(material) ||
            !world_->granular_support_at(source_x, contact_y, false, false)) {
            continue;
        }
        if (world_->relocate_stored_cell(source_x, contact_y, target_x, target_y)) {
            ++moved;
        }
    }

    if (moved != 0) ++revision_;
    return moved;
}

void CyberNativeCellWorld::refresh_render_cells() const {
    if (world_ == nullptr || world_->has_failed()) return;
    render_cells_.resize(static_cast<std::int64_t>(kWorldWidth) * kWorldHeight);
    auto* bytes = render_cells_.ptrw();
    world_->copy_material_cells(
        {0, 0, kWorldWidth, kWorldHeight},
        std::span<std::uint8_t>{bytes, static_cast<std::size_t>(render_cells_.size())},
        kWorldWidth);
    render_cells_revision_ = revision_;
}

PackedByteArray CyberNativeCellWorld::get_cells() const {
    if (render_cells_revision_ != revision_) refresh_render_cells();
    return render_cells_;
}

Dictionary CyberNativeCellWorld::take_render_snapshot(bool force_full) {
    Dictionary packet;
    if (has_failed()) {
        packet["failed"] = true;
        packet["error"] = last_tick_error_;
        return packet;
    }
    PackedInt32Array rectangles;
    PackedByteArray cells;
    std::uint64_t serial = 0;
    auto status = cybersand::RenderPublishStatus::NoChanges;
    bool full_refresh = force_full || render_snapshot_full_refresh_required_;

    if (world_ != nullptr && render_exchange_ != nullptr) {
        const auto publish_result = render_exchange_->publish(*world_);
        status = publish_result.status;
        serial = publish_result.snapshot_serial;

        if (status == cybersand::RenderPublishStatus::CapacityExceeded) {
            // The full packet is an explicit, correct recovery path. Dirty
            // state is acknowledged only after the complete world copy below.
            full_refresh = true;
        }

        if (full_refresh) {
            const auto width = static_cast<std::size_t>(kWorldWidth);
            const auto height = static_cast<std::size_t>(kWorldHeight);
            cells.resize(static_cast<std::int64_t>(width * height * 2U));
            world_->copy_render_cells(
                {0, 0, kWorldWidth, kWorldHeight},
                std::span<std::uint8_t>{cells.ptrw(), static_cast<std::size_t>(cells.size())},
                width * 2U);
            rectangles.resize(6);
            auto* metadata = rectangles.ptrw();
            metadata[0] = 0;
            metadata[1] = 0;
            metadata[2] = kWorldWidth;
            metadata[3] = kWorldHeight;
            metadata[4] = 0;
            metadata[5] = kWorldWidth * 2;
            if (status == cybersand::RenderPublishStatus::CapacityExceeded) {
                (void)world_->take_dirty_chunks();
            }
            render_snapshot_full_refresh_required_ = false;
        } else if (status == cybersand::RenderPublishStatus::Published) {
            auto lease = render_exchange_->acquire_latest(serial - 1U);
            if (lease.has_value()) {
                const auto patches = lease->patches();
                const auto source_cells = lease->cells();
                rectangles.resize(static_cast<std::int64_t>(patches.size() * 6U));
                cells.resize(static_cast<std::int64_t>(source_cells.size()));
                std::copy(source_cells.begin(), source_cells.end(), cells.ptrw());
                auto* metadata = rectangles.ptrw();
                for (std::size_t index = 0; index < patches.size(); ++index) {
                    const auto& patch = patches[index];
                    const auto base = index * 6U;
                    metadata[base] = static_cast<std::int32_t>(patch.world_rect.x);
                    metadata[base + 1U] = static_cast<std::int32_t>(patch.world_rect.y);
                    metadata[base + 2U] = static_cast<std::int32_t>(patch.world_rect.width);
                    metadata[base + 3U] = static_cast<std::int32_t>(patch.world_rect.height);
                    metadata[base + 4U] = static_cast<std::int32_t>(patch.data_offset);
                    metadata[base + 5U] = static_cast<std::int32_t>(patch.stride_bytes);
                }
            }
        }
    }

    packet["serial"] = static_cast<std::int64_t>(serial);
    packet["status"] = static_cast<std::int64_t>(status);
    packet["full_refresh"] = full_refresh;
    packet["channels"] = 2;
    packet["rectangles"] = rectangles;
    packet["cells"] = cells;
    return packet;
}

PackedInt32Array CyberNativeCellWorld::get_hard_surface_rectangles() const {
    if (has_failed()) return hard_surface_rectangles_;
    if (world_ == nullptr) return {};
    const auto hard_revision = static_cast<std::uint64_t>(get_hard_surface_revision());
    if (hard_surface_rectangles_revision_ == hard_revision) {
        return hard_surface_rectangles_;
    }
    if (render_cells_revision_ != revision_) refresh_render_cells();

    struct Rectangle {
        std::int32_t x = 0;
        std::int32_t y = 0;
        std::int32_t width = 0;
        std::int32_t height = 0;
    };
    const auto run_key = [](std::int32_t x, std::int32_t width) {
        return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(x)) << 32U) |
               static_cast<std::uint32_t>(width);
    };
    const auto append_rectangle = [](std::vector<Rectangle>& destination,
                                     const Rectangle& rectangle) {
        if (rectangle.width > 0 && rectangle.height > 0) destination.push_back(rectangle);
    };

    std::unordered_map<std::uint64_t, Rectangle> active;
    std::unordered_map<std::uint64_t, Rectangle> next;
    active.reserve(static_cast<std::size_t>(kWorldWidth / 2 + 1));
    next.reserve(static_cast<std::size_t>(kWorldWidth / 2 + 1));
    std::vector<Rectangle> completed;
    completed.reserve(1024);
    const auto* cells = render_cells_.ptr();
    for (std::int32_t y = 0; y < kWorldHeight; ++y) {
        next.clear();
        std::int32_t x = 0;
        while (x < kWorldWidth) {
            while (x < kWorldWidth &&
                   !cybersand::MaterialRules::is_hard_surface(
                       static_cast<cybersand::Material>(cells[y * kWorldWidth + x]))) {
                ++x;
            }
            if (x >= kWorldWidth) break;
            const auto first_x = x;
            while (x < kWorldWidth &&
                   cybersand::MaterialRules::is_hard_surface(
                       static_cast<cybersand::Material>(cells[y * kWorldWidth + x]))) {
                ++x;
            }
            const auto width = x - first_x;
            const auto key = run_key(first_x, width);
            auto previous = active.find(key);
            next.emplace(key, previous == active.end()
                                  ? Rectangle{first_x, y, width, 1}
                                  : Rectangle{previous->second.x, previous->second.y,
                                              previous->second.width,
                                              previous->second.height + 1});
        }
        for (const auto& [key, rectangle] : active) {
            if (!next.contains(key)) append_rectangle(completed, rectangle);
        }
        active.swap(next);
    }
    for (const auto& [key, rectangle] : active) {
        (void)key;
        append_rectangle(completed, rectangle);
    }
    std::sort(completed.begin(), completed.end(), [](const Rectangle& left,
                                                     const Rectangle& right) {
        if (left.y != right.y) return left.y < right.y;
        if (left.x != right.x) return left.x < right.x;
        if (left.height != right.height) return left.height < right.height;
        return left.width < right.width;
    });

    hard_surface_rectangles_.resize(static_cast<std::int64_t>(completed.size() * 4U));
    auto* packed = hard_surface_rectangles_.ptrw();
    for (std::size_t index = 0; index < completed.size(); ++index) {
        const auto& rectangle = completed[index];
        const auto offset = index * 4U;
        packed[offset] = rectangle.x;
        packed[offset + 1U] = rectangle.y;
        packed[offset + 2U] = rectangle.width;
        packed[offset + 3U] = rectangle.height;
    }
    hard_surface_rectangles_revision_ = hard_revision;
    return hard_surface_rectangles_;
}

PackedInt32Array CyberNativeCellWorld::get_hard_surface_chunk_rectangles() const {
    if (has_failed()) return hard_surface_chunk_rectangles_;
    if (world_ == nullptr) return {};
    const auto hard_revision = static_cast<std::uint64_t>(get_hard_surface_revision());
    if (hard_surface_chunk_rectangles_revision_ == hard_revision) return hard_surface_chunk_rectangles_;
    if (render_cells_revision_ != revision_) refresh_render_cells();
    hard_surface_chunk_rectangles_ = hard_surface_chunks_from_cells(render_cells_);
    hard_surface_chunk_rectangles_revision_ = hard_revision;
    return hard_surface_chunk_rectangles_;
}

PackedInt32Array CyberNativeCellWorld::hard_surface_chunks_from_cells(const PackedByteArray& material_cells) {
    if (material_cells.size() != static_cast<std::int64_t>(kWorldWidth) * kWorldHeight)
        throw std::invalid_argument("Finite material projection has an invalid size");
    PackedInt32Array result;
    // Collision chunks are intentionally smaller than storage chunks. The
    // main-thread PhysicsServer budget can stop only between complete chunks,
    // so 64x64 bounds a pathological fragmented replacement far better than
    // the previous 128x128 atomic unit.
    constexpr std::int32_t chunk_size = 64;
    constexpr std::int32_t chunk_columns = kWorldWidth / chunk_size;
    constexpr std::int32_t chunk_rows = kWorldHeight / chunk_size;
    constexpr std::int32_t chunk_count = chunk_columns * chunk_rows;
    static_assert(kWorldWidth % chunk_size == 0 && kWorldHeight % chunk_size == 0);

    struct Rectangle {
        std::int32_t x = 0;
        std::int32_t y = 0;
        std::int32_t width = 0;
        std::int32_t height = 0;
    };
    const auto run_key = [](std::int32_t x, std::int32_t width) {
        return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(x)) << 32U) |
               static_cast<std::uint32_t>(width);
    };

    std::array<std::vector<Rectangle>, chunk_count> chunk_rectangles;
    const auto* cells = material_cells.ptr();
    for (std::int32_t chunk_y = 0; chunk_y < chunk_rows; ++chunk_y) {
        for (std::int32_t chunk_x = 0; chunk_x < chunk_columns; ++chunk_x) {
            const auto chunk_index = chunk_y * chunk_columns + chunk_x;
            const auto minimum_x = chunk_x * chunk_size;
            const auto maximum_x = minimum_x + chunk_size;
            const auto minimum_y = chunk_y * chunk_size;
            const auto maximum_y = minimum_y + chunk_size;
            auto& completed = chunk_rectangles[static_cast<std::size_t>(chunk_index)];
            std::unordered_map<std::uint64_t, Rectangle> active;
            std::unordered_map<std::uint64_t, Rectangle> next;
            active.reserve(static_cast<std::size_t>(chunk_size / 2 + 1));
            next.reserve(static_cast<std::size_t>(chunk_size / 2 + 1));

            for (auto y = minimum_y; y < maximum_y; ++y) {
                next.clear();
                auto x = minimum_x;
                while (x < maximum_x) {
                    while (x < maximum_x &&
                           !cybersand::MaterialRules::is_hard_surface(
                               static_cast<cybersand::Material>(
                                   cells[y * kWorldWidth + x]))) {
                        ++x;
                    }
                    if (x >= maximum_x) break;
                    const auto first_x = x;
                    while (x < maximum_x &&
                           cybersand::MaterialRules::is_hard_surface(
                               static_cast<cybersand::Material>(
                                   cells[y * kWorldWidth + x]))) {
                        ++x;
                    }
                    const auto width = x - first_x;
                    const auto key = run_key(first_x, width);
                    const auto previous = active.find(key);
                    next.emplace(key, previous == active.end()
                                          ? Rectangle{first_x, y, width, 1}
                                          : Rectangle{previous->second.x,
                                                      previous->second.y,
                                                      previous->second.width,
                                                      previous->second.height + 1});
                }
                for (const auto& [key, rectangle] : active) {
                    if (!next.contains(key)) completed.push_back(rectangle);
                }
                active.swap(next);
            }
            for (const auto& [key, rectangle] : active) {
                (void)key;
                completed.push_back(rectangle);
            }
            std::sort(completed.begin(), completed.end(),
                      [](const Rectangle& left, const Rectangle& right) {
                          if (left.y != right.y) return left.y < right.y;
                          if (left.x != right.x) return left.x < right.x;
                          if (left.height != right.height) {
                              return left.height < right.height;
                          }
                          return left.width < right.width;
                      });
        }
    }

    std::size_t rectangle_count = 0;
    for (const auto& rectangles : chunk_rectangles) rectangle_count += rectangles.size();
    const auto header_size = static_cast<std::size_t>(chunk_count + 2);
    result.resize(static_cast<std::int64_t>(
        header_size + rectangle_count * 4U));
    auto* packed = result.ptrw();
    packed[0] = chunk_count;
    auto cursor = header_size;
    for (std::size_t chunk_index = 0; chunk_index < chunk_rectangles.size(); ++chunk_index) {
        packed[1U + chunk_index] = static_cast<std::int32_t>(cursor);
        for (const auto& rectangle : chunk_rectangles[chunk_index]) {
            packed[cursor++] = rectangle.x;
            packed[cursor++] = rectangle.y;
            packed[cursor++] = rectangle.width;
            packed[cursor++] = rectangle.height;
        }
    }
    packed[1U + chunk_rectangles.size()] = static_cast<std::int32_t>(cursor);
    return result;
}

void CyberNativeCellWorld::set_interest_center(Vector2i world_cell) {
    interest_center_.x = std::clamp<std::int64_t>(world_cell.x, 0, kWorldWidth - 1);
    interest_center_.y = std::clamp<std::int64_t>(world_cell.y, 0, kWorldHeight - 1);
}

void CyberNativeCellWorld::set_simulation_window(Vector2i view_origin, Vector2i view_size,
                                                 std::int64_t horizontal_buffer,
                                                 std::int64_t vertical_buffer) {
    last_view_origin_ = view_origin;
    last_view_size_ = view_size;
    last_horizontal_buffer_ = std::max<std::int64_t>(0, horizontal_buffer);
    last_vertical_buffer_ = std::max<std::int64_t>(0, vertical_buffer);
    refresh_simulation_region();
}

void CyberNativeCellWorld::refresh_simulation_region() {
    if (world_ == nullptr) return;
    if (!simulation_window_enabled_) {
        world_->set_simulation_region(cybersand::RectI64{0, 0, kWorldWidth, kWorldHeight});
        return;
    }
    const auto first_x = std::clamp<std::int64_t>(
        static_cast<std::int64_t>(last_view_origin_.x) - last_horizontal_buffer_, 0, kWorldWidth - 1);
    const auto first_y = std::clamp<std::int64_t>(
        static_cast<std::int64_t>(last_view_origin_.y) - last_vertical_buffer_, 0, kWorldHeight - 1);
    const auto last_x = std::clamp<std::int64_t>(
        static_cast<std::int64_t>(last_view_origin_.x) + last_view_size_.x +
            last_horizontal_buffer_,
        first_x + 1, kWorldWidth);
    const auto last_y = std::clamp<std::int64_t>(
        static_cast<std::int64_t>(last_view_origin_.y) + last_view_size_.y +
            last_vertical_buffer_,
        first_y + 1, kWorldHeight);
    world_->set_simulation_region(
        cybersand::RectI64{first_x, first_y, last_x - first_x, last_y - first_y});
}

void CyberNativeCellWorld::set_simulation_window_enabled(bool enabled) {
    if (simulation_window_enabled_ == enabled) return;
    simulation_window_enabled_ = enabled;
    refresh_simulation_region();
}

bool CyberNativeCellWorld::get_simulation_window_enabled() const {
    return simulation_window_enabled_;
}

void CyberNativeCellWorld::set_cadence_lod_enabled(bool enabled) {
    cadence_lod_enabled_ = enabled;
}

bool CyberNativeCellWorld::get_cadence_lod_enabled() const {
    return cadence_lod_enabled_;
}

void CyberNativeCellWorld::set_liquid_surface_adhesion_enabled(bool enabled) {
    liquid_surface_adhesion_enabled_ = enabled;
    if (world_ != nullptr) world_->set_liquid_surface_adhesion_enabled(enabled);
}

bool CyberNativeCellWorld::get_liquid_surface_adhesion_enabled() const {
    return liquid_surface_adhesion_enabled_;
}

std::int32_t CyberNativeCellWorld::symmetric_probe_offset(std::int32_t index) {
    if (index == 0) return 0;
    const auto magnitude = (index + 1) / 2;
    return (index & 1) != 0 ? magnitude : -magnitude;
}

bool CyberNativeCellWorld::in_bounds(std::int64_t x, std::int64_t y) {
    return x >= 0 && x < kWorldWidth && y >= 0 && y < kWorldHeight;
}


std::int64_t CyberNativeCellWorld::get_revision() const { return revision_; }
std::int64_t CyberNativeCellWorld::get_hard_surface_revision() const {
    return world_ == nullptr
               ? static_cast<std::int64_t>(hard_surface_revision_)
               : static_cast<std::int64_t>(world_->hard_surface_revision());
}
std::int64_t CyberNativeCellWorld::get_tick_index() const {
    return world_ == nullptr ? 0 : static_cast<std::int64_t>(world_->completed_tick_index());
}
bool CyberNativeCellWorld::has_failed() const { return world_ == nullptr || world_->has_failed(); }
std::int64_t CyberNativeCellWorld::get_attempted_tick_index() const {
    return world_ == nullptr ? 0 : static_cast<std::int64_t>(world_->tick_index());
}
std::int64_t CyberNativeCellWorld::get_moves_last_tick() const {
    return static_cast<std::int64_t>(last_stats_.moved_cells);
}
std::int64_t CyberNativeCellWorld::get_scanned_last_tick() const {
    return static_cast<std::int64_t>(last_stats_.visited_cells);
}
std::int64_t CyberNativeCellWorld::get_dormant_cells_skipped_last_tick() const { return 0; }
std::int64_t CyberNativeCellWorld::get_active_blocks_last_tick() const {
    std::uint64_t jobs = 0;
    for (const auto count : last_stats_.phase_jobs) jobs += count;
    return static_cast<std::int64_t>(jobs);
}
std::int64_t CyberNativeCellWorld::get_eligible_blocks_last_tick() const {
    return static_cast<std::int64_t>(last_stats_.scheduled_cores);
}
std::int64_t CyberNativeCellWorld::get_adaptive_block_stride_last_tick() const { return 1; }
std::int64_t CyberNativeCellWorld::get_deferred_blocks_last_tick() const { return 0; }
std::int64_t CyberNativeCellWorld::get_frozen_blocks_last_tick() const { return 0; }
std::int64_t CyberNativeCellWorld::get_scheduler_jobs_last_tick() const {
    return get_active_blocks_last_tick();
}
std::int64_t CyberNativeCellWorld::get_scheduler_parallel_phases_last_tick() const {
    if (worker_threads_ <= 1U) return 0;
    std::int64_t phases = 0;
    for (const auto count : last_stats_.phase_jobs) {
        if (count >= 2U) ++phases;
    }
    return phases;
}
std::int64_t CyberNativeCellWorld::get_sparse_flight_moves_last_tick() const { return 0; }
std::int64_t CyberNativeCellWorld::get_rigid_body_contacts_last_tick() const {
    std::uint64_t total = 0;
    for (std::size_t id = 1; id < observations_.size(); ++id) {
        total += observations_[id].contacts + world_->transient_contact_count(id);
    }
    return static_cast<std::int64_t>(total);
}
std::int64_t CyberNativeCellWorld::get_rigid_body_displaced_last_tick() const {
    std::uint64_t total = 0;
    for (std::size_t id = 1; id < observations_.size(); ++id) total += observations_[id].displaced;
    return static_cast<std::int64_t>(total);
}
std::int64_t CyberNativeCellWorld::get_rigid_body_unresolved_last_tick() const {
    std::uint64_t total = 0;
    for (std::size_t id = 1; id < observations_.size(); ++id) total += observations_[id].unresolved;
    return static_cast<std::int64_t>(total);
}
double CyberNativeCellWorld::density_scale(cybersand::Material material, double minimum) const {
    return std::clamp(static_cast<double>(cybersand::MaterialRules::descriptor(material).density) /
                      1000.0, minimum, density_limit_);
}

bool CyberNativeCellWorld::diagnostic_reset(const Dictionary& options) {
    // Explicit API, fresh construction, no live descriptor edits. A demo reset
    // restores production defaults. Validate before replacing existing authority.
    try {
        auto selected = cybersand::bearing_experiment::Mode::B0;
        if (options.has("bearing_candidate") || options.has("bearing_experiment")) {
            if (options.get("bearing_candidate", Variant()).get_type()!=Variant::STRING ||
                String(options.get("bearing_experiment", ""))!="GBD-2026-11-01") return false;
            const String mode=options["bearing_candidate"];
            const auto parsed=cybersand::bearing_experiment::parse(mode.utf8().get_data());
            if (!parsed) return false;
            selected=*parsed;
        }
        const auto workers = static_cast<std::int64_t>(options.get("workers", 1));
        if (workers < 1 || workers > 32) return false;
#if defined(__EMSCRIPTEN__) && !defined(__EMSCRIPTEN_PTHREADS__)
        if (workers != 1) return false;
#endif
        const auto gain = [&options](const char* name, double baseline) {
            const double value = options.get(name, baseline);
            if (!std::isfinite(value) || value < 0 || value > 16)
                throw std::invalid_argument("diagnostic gain outside 0..16");
            return value;
        };
        const auto displacement = gain("displacement", 0.18);
        const auto boundary = gain("boundary", 0.19);
        const auto contact = gain("contact", 0.025);
        const auto cap = gain("cap", 3.0);
        const auto density = gain("density_limit", 1.6);
        if (density < 0.05 || cap <= 0) return false;
        cybersand::WorldConfig config;
        config.worker_threads = static_cast<std::uint32_t>(workers);
        config.maximum_chunk_count = 128;
        config.active_chunk_capacity = 128;
        config.active_core_capacity = 1024;
        config.parallel_job_threshold = 2;
        if (static_cast<bool>(options.get("serial", false))) config.backend = cybersand::SimulationBackend::SerialInPlace;
        config.physics_diagnostics.enabled = options.get("telemetry", true);
        config.physics_diagnostics.disable_powder_exchange_targets = options.get("exchange_off", false);
        const auto viscosity = static_cast<std::int64_t>(options.get("viscosity", -1));
        if (viscosity < -1 || viscosity > 255) return false;
        config.physics_diagnostics.mercury_viscosity = static_cast<std::int16_t>(viscosity);
        const auto support_cells = static_cast<std::int64_t>(options.get("support_cells", 8));
        if (support_cells < 1 || support_cells > 9) return false;
        config.interaction_policy.downward_support_cells = static_cast<std::uint8_t>(support_cells);
        const auto period = static_cast<std::int64_t>(options.get("mercury_period", 30));
        if (period < 1 || period > 60) return false;
        config.interaction_policy.mercury_exchange_period = static_cast<std::uint32_t>(period);
        if(options.has("transport")) {
            if(options["transport"].get_type()!=Variant::PACKED_INT32_ARRAY) return false;
            const PackedInt32Array profile=options["transport"];
            config.transport_policy=cybersand::TransportPolicy::unpack(
                {profile.ptr(),static_cast<std::size_t>(profile.size())});
        }
        auto candidate = std::make_unique<cybersand::World>(config);
        candidate->reserve_region({0, 0, kWorldWidth, kWorldHeight});
        candidate->configure_transient_obstacles({0, 0, kWorldWidth, kWorldHeight});
        auto diagnostics = config.physics_diagnostics.enabled
            ? std::make_unique<BodyDiagnostics>() : nullptr;
        auto bearing_trace = static_cast<bool>(options.get("bearing_trace", false))
            ? std::make_unique<BearingTrace>() : nullptr;
        world_.swap(candidate);
        retire_liquid_construction_identity();
        ++liquid_policy_session_generation_;
        clear_ejection_capture();
        body_diagnostics_ = std::move(diagnostics);
        bearing_trace_ = std::move(bearing_trace);
        bearing_candidate_ = selected;
        diagnostic_fixture_ = true;
        worker_threads_ = config.worker_threads;
        displacement_gain_ = displacement; boundary_gain_ = boundary;
        contact_gain_ = contact; impulse_cap_ = cap; density_limit_ = density;
        current_bodies_ = {}; previous_bodies_ = {}; clear_observations();
        last_stats_ = {}; tick_failure_count_ = 0; last_tick_error_ = String{};
        render_cells_revision_ = hard_surface_rectangles_revision_ = hard_surface_chunk_rectangles_revision_ = UINT64_MAX;
        render_snapshot_full_refresh_required_ = true;
        ++revision_;
        refresh_simulation_region();
        return true;
    } catch (const std::exception& error) {
        last_tick_error_ = error.what();
        return false;
    }
}

void CyberNativeCellWorld::clear_ejection_capture() {
    ejection_capture_failed_cap_ = ejection_capture_success_cap_ = 0;
    ejection_capture_attempts_ = ejection_capture_duplicates_ = ejection_capture_dropped_ = 0;
    ejection_capture_failed_ = ejection_capture_success_ = 0;
    ejection_capture_no_target_ = ejection_capture_target_found_ = ejection_capture_relocation_refused_ = 0;
    ejection_capture_capacity_drops_ = ejection_capture_oversized_drops_ = 0;
    ejection_capture_stale_drops_ = ejection_capture_replay_disagreements_ = 0;
    ejection_capsules_.clear();
    ejection_capture_stream_ = false;
    ejection_capture_stream_emitted_ = 0;
    ejection_capture_pending_drops_ = ejection_capture_total_drops_ = 0;
}

bool CyberNativeCellWorld::diagnostic_ejection_capture(std::int64_t maximum_failed,
                                                       std::int64_t maximum_success) {
    if (!diagnostic_fixture_ || has_failed() || maximum_failed < 0 || maximum_failed > 64 ||
        maximum_success < 0 || maximum_success > 16 || world_->pressure_flow_enabled() ||
        world_->inertial_enabled()) return false;
    clear_ejection_capture();
    ejection_capture_failed_cap_ = maximum_failed;
    ejection_capture_success_cap_ = maximum_success;
    ejection_capture_generation_ = liquid_policy_session_generation_;
    return true;
}

bool CyberNativeCellWorld::diagnostic_ejection_stream() {
    if (!diagnostic_ejection_capture(0, 0)) return false;
    ejection_capture_stream_ = true;
    return true;
}

Dictionary CyberNativeCellWorld::diagnostic_take_ejection_events() {
    // Same owner, immutable value copy. Never installs state or changes fencing.
    auto out = diagnostic_ejection_corpus();
    if (ejection_capture_stream_) ejection_capsules_.clear();
    return out;
}

Dictionary CyberNativeCellWorld::diagnostic_ejection_corpus() const {
    Dictionary out;
    out["schema_version"] = 1;
    out["capsules"] = ejection_capsules_.duplicate(true);
    out["attempts"] = ejection_capture_attempts_;
    out["duplicates"] = ejection_capture_duplicates_;
    out["dropped"] = ejection_capture_dropped_;
    out["failed_unique"] = ejection_capture_failed_;
    out["success_unique"] = ejection_capture_success_;
    out["searched_no_target"] = ejection_capture_no_target_;
    out["target_found"] = ejection_capture_target_found_;
    out["relocation_refused"] = ejection_capture_relocation_refused_;
    out["dropped_capacity"] = ejection_capture_capacity_drops_;
    out["dropped_oversized"] = ejection_capture_oversized_drops_;
    out["dropped_stale_or_sidecar"] = ejection_capture_stale_drops_;
    out["replay_disagreements"] = ejection_capture_replay_disagreements_;
    out["maximum_failed"] = ejection_capture_failed_cap_;
    out["maximum_success"] = ejection_capture_success_cap_;
    out["maximum_footprint_side"] = 128;
    out["owner_current"] = ejection_capture_generation_ == liquid_policy_session_generation_;
    out["stream_mode"] = ejection_capture_stream_;
    out["stream_pending_limit"] = 256;
    out["stream_emitted"] = ejection_capture_stream_emitted_;
    out["stream_total_limit"] = 8192;
    out["stream_pending_drops"] = ejection_capture_pending_drops_;
    out["stream_total_drops"] = ejection_capture_total_drops_;
    out["capture_instance_id"] = String::num_uint64(get_instance_id());
    out["capture_reset_generation"] = String::num_uint64(ejection_capture_generation_);
    return out;
}

void CyberNativeCellWorld::capture_ejection(std::int32_t x, std::int32_t y,
    std::uint16_t body_id, Vector2 outward, double penetration, Vector2i target) {
    ++ejection_capture_attempts_;
    if (target.x < 0) ++ejection_capture_no_target_; else ++ejection_capture_target_found_;
    if (ejection_capture_generation_ != liquid_policy_session_generation_ ||
        world_->pressure_flow_enabled() || world_->inertial_enabled()) {
        ++ejection_capture_dropped_; ++ejection_capture_stale_drops_; return;
    }
    if (ejection_capture_stream_ && (ejection_capture_stream_emitted_ >= 8192 || ejection_capsules_.size() >= 256)) {
        ++ejection_capture_dropped_; ++ejection_capture_capacity_drops_;
        if (ejection_capture_stream_emitted_ >= 8192) ++ejection_capture_total_drops_;
        else ++ejection_capture_pending_drops_;
        return;
    }
    const Vector2 center{static_cast<double>(x) + 0.5, static_cast<double>(y) + 0.5};
    const Vector2 tangent{-outward.y, outward.x};
    const auto first = std::max(1, static_cast<std::int32_t>(std::ceil(penetration)));
    auto left = x, right = x, top = y, bottom = y;
    for (auto distance = first; distance <= first + 8; ++distance) {
        for (std::int32_t probe = 0; probe < 9; ++probe) {
            const auto candidate = center + outward * distance + tangent * cybersand::ejection::symmetric_offset(probe);
            const auto cx = static_cast<std::int32_t>(std::floor(candidate.x));
            const auto cy = static_cast<std::int32_t>(std::floor(candidate.y));
            left = std::min(left, cx); right = std::max(right, cx);
            top = std::min(top, cy); bottom = std::max(bottom, cy);
        }
    }
    --left; --top; ++right; ++bottom; // A diagnostic ring, never searched by production.
    const auto width = right - left + 1, height = bottom - top + 1;
    if (width > 128 || height > 128) {
        ++ejection_capture_dropped_; ++ejection_capture_oversized_drops_; return;
    }
    Dictionary capsule;
    capsule["schema_version"] = 1;
    capsule["source"] = ejection_array(x, y);
    capsule["body_id"] = body_id;
    capsule["normal"] = ejection_array(static_cast<double>(outward.x), static_cast<double>(outward.y));
    capsule["penetration"] = penetration;
    capsule["first_distance"] = first;
    capsule["maximum_distance"] = 8;
    capsule["tangent_probes"] = 9;
    capsule["bounds"] = ejection_array(left, top, width, height);
    capsule["world_bounds"] = ejection_array(0, 0, kWorldWidth, kWorldHeight);
    capsule["instance_id"] = String::num_uint64(get_instance_id());
    capsule["reset_generation"] = String::num_uint64(liquid_policy_session_generation_);
    capsule["tick"] = static_cast<std::int64_t>(world_->tick_index());
    capsule["revision"] = static_cast<std::int64_t>(revision_);
    const auto pack_body = [](const BodyState& b) {
        return ejection_array(b.id, static_cast<double>(b.center.x), static_cast<double>(b.center.y),
            b.rotation, static_cast<double>(b.half_size.x), static_cast<double>(b.half_size.y),
            static_cast<double>(b.velocity.x), static_cast<double>(b.velocity.y), b.angular_velocity,
            b.mass, b.sample_serial, b.valid);
    };
    capsule["current_body"] = pack_body(current_bodies_[body_id]);
    capsule["previous_body"] = pack_body(previous_bodies_[body_id]);
    capsule["sample_serial"] = current_bodies_[body_id].sample_serial;
    const bool inside = cell_inside_body(current_bodies_[body_id], x, y);
    capsule["inside_current_body"] = inside;
    const auto travel = current_bodies_[body_id].center - previous_bodies_[body_id].center;
    capsule["normal_mode"] = inside || normalized_or_zero(travel).length_squared() <= 0.000001
        ? "overlap_face" : "sweep";
    capsule["storage_policy"] = "default_cellular_no_pressure_or_inertial_sidecar";
    capsule["ambient_temperature"] = world_->config().ambient_temperature;
    Array cells;
    cells.resize(width * height);
    for (auto cy = top; cy <= bottom; ++cy) {
        for (auto cx = left; cx <= right; ++cx) {
            const bool valid = in_bounds(cx, cy);
            const auto material = valid ? world_->stored_material(cx, cy) : cybersand::Material::Empty;
            const auto state_a = valid ? world_->stored_state_a(cx, cy) : 0;
            cells[(cy - top) * width + cx - left] = ejection_array(
                static_cast<std::int64_t>(material), state_a,
                valid ? world_->stored_state_b(cx, cy) : 0,
                valid ? world_->stored_temperature(cx, cy) : world_->config().ambient_temperature,
                valid ? world_->transient_obstacle_at(cx, cy) : 0,
                cybersand::MaterialRules::is_hard_surface(material),
                cybersand::MaterialRules::descriptor(material).movable,
                material == cybersand::Material::Water ? state_a : 0,
                ejection_hex(valid ? world_->stored_cell_bits(cx, cy) : 0));
        }
    }
    capsule["cells"] = cells;
    const auto replay = diagnostic_replay_ejection(capsule);
    if (!static_cast<bool>(replay["valid"])) {
        ++ejection_capture_dropped_; ++ejection_capture_replay_disagreements_; return;
    }
    const Array replay_target = replay["target"];
    if (static_cast<std::int32_t>(replay_target[0]) != target.x ||
        static_cast<std::int32_t>(replay_target[1]) != target.y) {
        ++ejection_capture_dropped_; ++ejection_capture_replay_disagreements_; return;
    }
    const String hash = replay["replay_hash"];
    if (ejection_capture_stream_) {
        capsule["target"] = replay["target"];
        capsule["trace"] = replay["trace"];
        capsule["replay_hash"] = hash;
        capsule["event_ordinal"] = ejection_capture_attempts_;
        ejection_capsules_.push_back(capsule);
        ++ejection_capture_stream_emitted_;
        return;
    }
    for (std::int64_t i = 0; i < ejection_capsules_.size(); ++i) {
        const Dictionary retained = ejection_capsules_[i];
        if (static_cast<String>(retained["replay_hash"]) == hash) {
            ++ejection_capture_duplicates_; return;
        }
    }
    const bool success = target.x >= 0;
    if ((success && ejection_capture_success_ >= ejection_capture_success_cap_) ||
        (!success && ejection_capture_failed_ >= ejection_capture_failed_cap_)) {
        ++ejection_capture_dropped_; ++ejection_capture_capacity_drops_; return;
    }
    capsule["target"] = replay["target"];
    capsule["trace"] = replay["trace"];
    capsule["replay_hash"] = hash;
    ejection_capsules_.push_back(capsule);
    if (success) ++ejection_capture_success_; else ++ejection_capture_failed_;
}

Dictionary CyberNativeCellWorld::diagnostic_replay_ejection(const Dictionary& capsule) const {
    Dictionary out;
    out["valid"] = false;
    out["reason"] = "malformed_capsule";
    // This never installs state. Incarnation fields fence live application but do
    // not prevent offline replay by a different diagnostic World instance.
    const auto number = [](const Variant& v, double minimum, double maximum, bool integer) {
        if (v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT) return false;
        const double n = v;
        return std::isfinite(n) && n >= minimum && n <= maximum && (!integer || std::floor(n) == n);
    };
    const auto array_field = [&capsule](const char* key, std::int64_t count) {
        return capsule.has(key) && capsule[key].get_type() == Variant::ARRAY &&
               static_cast<Array>(capsule[key]).size() == count;
    };
    if (!number(capsule.get("schema_version", Variant()), 1, 1, true) ||
        !array_field("source", 2) || !array_field("normal", 2) ||
        !array_field("bounds", 4) || !array_field("world_bounds", 4) ||
        !capsule.has("cells") || capsule["cells"].get_type() != Variant::ARRAY ||
        !number(capsule.get("maximum_distance", Variant()), 8, 8, true) ||
        !number(capsule.get("tangent_probes", Variant()), 9, 9, true) ||
        !number(capsule.get("first_distance", Variant()), 1, 128, true) ||
        (capsule.has("replay_hash") && capsule["replay_hash"].get_type() != Variant::STRING)) return out;
    const Array source = capsule["source"], normal = capsule["normal"], bounds = capsule["bounds"];
    const Array world_bounds = capsule["world_bounds"], cells = capsule["cells"];
    for (std::int64_t i = 0; i < 4; ++i) {
        const double expected = i < 2 ? 0.0 : 1024.0;
        if (!number(world_bounds[i], expected, expected, true)) return out;
    }
    for (std::int64_t i = 0; i < 2; ++i)
        if (!number(source[i], 0, 1023, true) || !number(normal[i], -1.000001, 1.000001, false)) return out;
    for (std::int64_t i = 0; i < 4; ++i)
        if (!number(bounds[i], i < 2 ? -128 : 1, i < 2 ? 1152 : 128, true)) return out;
    if (!number(capsule.get("penetration", Variant()), 0.5, 128, false) ||
        !number(capsule.get("body_id", Variant()), 1, 64, true)) return out;
    const auto x = static_cast<std::int32_t>(source[0]), y = static_cast<std::int32_t>(source[1]);
    const auto left = static_cast<std::int32_t>(bounds[0]), top = static_cast<std::int32_t>(bounds[1]);
    const auto width = static_cast<std::int32_t>(bounds[2]), height = static_cast<std::int32_t>(bounds[3]);
    const auto body_id = static_cast<std::uint16_t>(static_cast<std::int64_t>(capsule["body_id"]));
    const double penetration = capsule["penetration"];
    const auto first = std::max(1, static_cast<std::int32_t>(std::ceil(penetration)));
    if (static_cast<std::int64_t>(capsule.get("first_distance", -1)) != first || cells.size() != width * height) return out;
    if (x < left || x >= left + width || y < top || y >= top + height) return out;
    for (std::int64_t i = 0; i < cells.size(); ++i) {
        if (cells[i].get_type() != Variant::ARRAY) return out;
        const Array row = cells[i];
        if (row.size() != 9 || !number(row[0], 0, static_cast<double>(cybersand::kLastMaterial), true) ||
            !number(row[1], 0, 65535, true) || !number(row[2], 0, 255, true) ||
            !number(row[3], -32768, 32767, true) || !number(row[4], 0, 64, true) ||
            row[5].get_type() != Variant::BOOL || row[6].get_type() != Variant::BOOL ||
            !number(row[7], 0, 65535, true) || row[8].get_type() != Variant::STRING) return out;
        const auto material = static_cast<cybersand::Material>(static_cast<std::int64_t>(row[0]));
        if (!cybersand::valid_material(static_cast<std::uint16_t>(material)) ||
            static_cast<bool>(row[5]) != cybersand::MaterialRules::is_hard_surface(material) ||
            static_cast<bool>(row[6]) != cybersand::MaterialRules::descriptor(material).movable) return out;
        const String raw = row[8];
        if (raw.length() != 16) return out;
        std::uint64_t bits = 0;
        for (std::int64_t digit = 0; digit < 16; ++digit) {
            const auto c = raw[digit];
            const auto value = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : 16;
            if (value > 15) return out;
            bits = (bits << 4U) | value;
        }
        if ((bits & 65535U) != static_cast<std::uint64_t>(material) ||
            ((bits >> 16U) & 65535U) != static_cast<std::uint64_t>(static_cast<std::int64_t>(row[1])) ||
            ((bits >> 32U) & 255U) != static_cast<std::uint64_t>(static_cast<std::int64_t>(row[2])) ||
            static_cast<std::int64_t>(row[7]) != (material == cybersand::Material::Water
                ? static_cast<std::int64_t>(row[1]) : 0)) return out;
    }
    const Vector2 outward{static_cast<double>(normal[0]), static_cast<double>(normal[1])};
    const Vector2 tangent{-outward.y, outward.x};
    const Vector2 center{static_cast<double>(x) + 0.5, static_cast<double>(y) + 0.5};
    Array trace;
    bool covered = true;
    std::string fingerprint;
    // Quotient by discrete search equivalence: raw normal/penetration and
    // provenance remain in the capsule, while only consulted relative positions
    // and search classifications enter identity. Sub-cell normal changes which
    // enumerate the same cells must not inflate the unique-contact corpus.
    const auto target = cybersand::ejection::search({x, y}, body_id, first,
        [&](cybersand::ejection::Point p) {
            const bool valid = in_bounds(p.x, p.y);
            ejection_hash_word(fingerprint, 0); // Tagged cell-read record.
            ejection_hash_word(fingerprint, static_cast<std::uint64_t>(static_cast<std::int64_t>(p.x) - x));
            ejection_hash_word(fingerprint, static_cast<std::uint64_t>(static_cast<std::int64_t>(p.y) - y));
            ejection_hash_word(fingerprint, valid ? 1 : 0);
            if (!valid) return cybersand::ejection::Cell{};
            if (p.x < left || p.x >= left + width || p.y < top || p.y >= top + height) {
                covered = false; return cybersand::ejection::Cell{};
            }
            const Array row = cells[(p.y - top) * width + p.x - left];
            const auto body = static_cast<std::uint16_t>(static_cast<std::int64_t>(row[4]));
            const bool empty = static_cast<std::int64_t>(row[0]) == 0, hard = row[5];
            ejection_hash_word(fingerprint, empty ? 1 : 0);
            ejection_hash_word(fingerprint, hard ? 1 : 0);
            ejection_hash_word(fingerprint, body == 0 ? 0 : body == body_id ? 1 : 2);
            return cybersand::ejection::Cell{true, empty, hard, body};
        },
        [center, outward, tangent](std::int32_t distance, std::int32_t offset) {
            const auto p = center + outward * distance + tangent * offset;
            return cybersand::ejection::Point{static_cast<std::int32_t>(std::floor(p.x)),
                                              static_cast<std::int32_t>(std::floor(p.y))};
        },
        [&](cybersand::ejection::Point p, cybersand::ejection::Reason reason) {
            ejection_hash_word(fingerprint, 1); // Tagged candidate boundary.
            ejection_hash_word(fingerprint, static_cast<std::uint64_t>(static_cast<std::int64_t>(p.x) - x));
            ejection_hash_word(fingerprint, static_cast<std::uint64_t>(static_cast<std::int64_t>(p.y) - y));
            ejection_hash_word(fingerprint, static_cast<std::uint64_t>(reason));
            trace.push_back(ejection_array(p.x, p.y, cybersand::ejection::reason_name(reason)));
        });
    if (!covered) { out["reason"] = "incomplete_footprint"; return out; }
    const auto digest = cybersand::Sha256::hex(cybersand::Sha256::of(
        {reinterpret_cast<const std::uint8_t*>(fingerprint.data()), fingerprint.size()}));
    const String hash(digest.c_str());
    if (capsule.has("replay_hash") && static_cast<String>(capsule["replay_hash"]) != hash) {
        out["reason"] = "hash_mismatch"; return out;
    }
    out["valid"] = true;
    out["reason"] = "ok";
    out["target"] = ejection_array(target.x, target.y);
    out["trace"] = trace;
    out["replay_hash"] = hash;
    return out;
}

bool CyberNativeCellWorld::diagnostic_fill_rect(Vector2i origin, Vector2i size,
    std::int64_t material, std::int64_t state_b) {
    if (!diagnostic_fixture_ || has_failed() || material < 0 ||
        material > static_cast<std::int64_t>(cybersand::kLastMaterial) ||
        !cybersand::valid_material(static_cast<std::uint16_t>(material)) || state_b < 0 || state_b > 255 ||
        size.x < 1 || size.y < 1 || size.x > kWorldWidth || size.y > kWorldHeight ||
        !in_bounds(origin.x, origin.y) || !in_bounds(static_cast<std::int64_t>(origin.x) + size.x - 1,
                                                   static_cast<std::int64_t>(origin.y) + size.y - 1)) return false;
    const auto value = static_cast<cybersand::Material>(material);
    const auto state_a = value == cybersand::Material::Water
        ? world_->config().water_experiment_policy.maximum()
        : static_cast<std::uint16_t>(cybersand::MaterialRules::descriptor(value).initial_state_a);
    for (auto y = origin.y; y < origin.y + size.y; ++y)
        for (auto x = origin.x; x < origin.x + size.x; ++x)
            (void)world_->set_cell_state(x, y, value, state_a,
                                       static_cast<std::uint8_t>(state_b));
    ++revision_;
    return true;
}

Dictionary CyberNativeCellWorld::apply_player_material_field(Vector2i center,
    Vector2 direction, std::int64_t material_id, std::int64_t mode, std::int64_t phase) {
    Dictionary result;
    result["accepted"] = false;
    result["reason"] = "invalid_command";
    if (world_ == nullptr || world_->has_failed()) {
        result["reason"] = "world_failed";
        return result;
    }
    if (!in_bounds(center.x, center.y) || !std::isfinite(direction.x) ||
        !std::isfinite(direction.y) ||
        (material_id != static_cast<std::int64_t>(cybersand::Material::Sand) &&
         material_id != static_cast<std::int64_t>(cybersand::Material::Water)) ||
        mode < 0 || mode > 3 || phase < 0 || phase > 2'147'483'647LL) {
        return result;
    }
    cybersand::PlayerMaterialFieldCommand command;
    command.center_x = center.x;
    command.center_y = center.y;
    command.move_x = direction.x;
    command.move_y = direction.y;
    command.material = static_cast<cybersand::Material>(material_id);
    command.mode = static_cast<std::uint32_t>(mode);
    command.phase = static_cast<std::uint64_t>(phase);
    command.bounds = {0, 0, kWorldWidth, kWorldHeight};
    const auto receipt = world_->apply_player_material_field(command);
    using Outcome = cybersand::PlayerMaterialFieldOutcome;
    result["accepted"] = receipt.outcome == Outcome::Applied;
    switch (receipt.outcome) {
        case Outcome::Applied: result["reason"] = "applied"; break;
        case Outcome::WorldFailed: result["reason"] = "world_failed"; break;
        case Outcome::TickInProgress: result["reason"] = "tick_in_progress"; break;
        case Outcome::InvalidCommand: break;
    }
    result["scanned_cells"] = receipt.scanned_cells;
    result["observed_cells"] = receipt.observed_cells;
    result["controlled_cells"] = receipt.controlled_cells;
    result["moved_cells"] = receipt.moved_cells;
    result["movement_steps"] = receipt.movement_steps;
    result["blocked_steps"] = receipt.blocked_steps;
    result["storage_refusals"] = receipt.storage_refusals;
    result["quantity"] = static_cast<std::int64_t>(receipt.quantity);
    result["centroid"] = Vector2(receipt.centroid_x, receipt.centroid_y);
    result["truncated"] = receipt.truncated;
    result["radius"] = cybersand::PlayerMaterialFieldCommand::kRadius;
    if (receipt.movement_steps > 0U) ++revision_;
    return result;
}

bool CyberNativeCellWorld::diagnostic_relocate_cell(Vector2i from, Vector2i to) {
    if (!diagnostic_fixture_ || world_ == nullptr || world_->has_failed() ||
        !in_bounds(from.x, from.y) || !in_bounds(to.x, to.y)) {
        return false;
    }
    const auto source = world_->stored_material(from.x, from.y);
    if (source == cybersand::Material::Empty ||
        cybersand::MaterialRules::is_hard_surface(source)) {
        return false;
    }
    if (!world_->relocate_stored_cell(from.x, from.y, to.x, to.y)) {
        return false;
    }
    ++revision_;
    return true;
}

Dictionary CyberNativeCellWorld::get_water_experiment_policy() const {
    Dictionary result;
    if (world_ == nullptr) return result;
    const auto& policy = world_->config().water_experiment_policy;
    result["version"] = policy.version();
    result["mass_bits"] = policy.mass_bits();
    result["coherence_ticks"] = policy.coherence_ticks();
    result["rest_policy"] = static_cast<std::uint8_t>(policy.rest_policy());
    result["maximum"] = policy.maximum();
    result["film"] = policy.film();
    result["tolerance"] = policy.tolerance();
    return result;
}

Dictionary CyberNativeCellWorld::liquid_policy_receipt(
    const cybersand::LiquidSolverPolicy& policy, std::int64_t session_generation,
    const cybersand::World* actual) {
    Dictionary result;
    result["version"] = static_cast<std::int64_t>(policy.policy_version());
    result["wire_version"] = static_cast<std::int64_t>(cybersand::LiquidSolverPolicy::kEnvelopeVersion);
    PackedInt32Array envelope;
    for (const auto word : policy.envelope()) envelope.push_back(word);
    result["envelope"] = envelope;
    result["session_generation"] = session_generation;
    result["policy_hash"] = String(policy.policy_hash_hex().c_str());
    result["catalogue_digest"] = String(cybersand::Sha256::hex(policy.catalogue_digest()).c_str());
    result["capability_matrix_digest"] =
        String(cybersand::Sha256::hex(policy.capability_matrix_digest()).c_str());
#if defined(__EMSCRIPTEN__)
    result["platform"] = "web";
#elif defined(_WIN32)
    result["platform"] = "windows";
#elif defined(__APPLE__)
    result["platform"] = "macos";
#else
    result["platform"] = "linux";
#endif
    // A policy equal to this build's default runs only Current defaults; any
    // other admitted policy is a qualified LCB candidate (pressure reference).
    result["admission"] = policy == cybersand::LiquidSolverPolicy{} ? "current_defaults_only"
                                                                    : "qualified_candidate";
    auto id = [](std::string_view text) { return String(std::string(text).c_str()); };
    Array assignments;
    for (const auto& item : policy.assignments()) {
        Dictionary entry;
        entry["material"] = static_cast<std::int64_t>(item.material);
        if (const auto* name = cybersand::liquid_policy_material_name(item.material)) entry["name"] = name;
        entry["requested_family"] = id(cybersand::liquid_solver_family_id(item.requested_family));
        entry["applied_family"] = id(cybersand::liquid_solver_family_id(item.family));
        entry["applied_variant"] = id(cybersand::liquid_solver_variant_id(item.variant));
        assignments.push_back(entry);
    }
    result["assignments"] = assignments;
    for (const auto family_blocks : {true, false}) {
        Array blocks;
        for (const auto& block : family_blocks ? policy.family_blocks() : policy.material_blocks()) {
            Dictionary entry;
            if (family_blocks)
                entry["family"] = id(cybersand::liquid_solver_family_id(
                    static_cast<cybersand::LiquidSolverFamily>(block.owner)));
            else
                entry["material"] = static_cast<std::int64_t>(block.owner);
            entry["block_version"] = static_cast<std::int64_t>(block.version);
            PackedInt32Array values;
            for (const auto value : block.values) values.push_back(value);
            entry["values"] = values;
            blocks.push_back(entry);
        }
        result[family_blocks ? "family_blocks" : "material_blocks"] = blocks;
    }
    Dictionary parameters;
    bool inertial = false;
    for (const auto& assignment : policy.assignments())
        inertial = inertial || assignment.family == cybersand::LiquidSolverFamily::InertialCellularV1;
    if (inertial) {
        const auto effective = actual ? actual->inertial_parameters() : cybersand::inertial_parameters_for_policy(policy);
        Dictionary value;
        value["family_version"] = static_cast<std::int64_t>(cybersand::InertialParameters::kVersion);
        value["block_version"] = static_cast<std::int64_t>(cybersand::InertialParameters::kFamilyBlockVersion);
        value["damping_numerator"] = static_cast<std::int64_t>(effective.damping_numerator);
        value["damping_denominator"] = static_cast<std::int64_t>(cybersand::InertialParameters::kDampingDenominator);
        value["minimum_rule_radius"] = static_cast<std::int64_t>(cybersand::InertialParameters::kExecutionRadius);
        value["extension_identity"] = String(cybersand::Sha256::hex(cybersand::inertial_extension_identity(effective)).c_str());
        value["readback_source"] = actual ? "applied_world" : "validated_policy";
        parameters["inertial_cellular_v1"] = value;
    }
    if (const auto water = policy.assignment(static_cast<std::uint16_t>(cybersand::Material::Water));
        water && water->family == cybersand::LiquidSolverFamily::PressureFlowV1) {
        cybersand::PressureFlowParameters effective;
        for (const auto& block : policy.family_blocks())
            if (block.owner == 3U && block.version == cybersand::LiquidPolicyBuild::kPressureBlockVersion &&
                block.values.size() == 2U) {
                effective.gas_enabled = block.values[0] != 0;
                effective.atmospheric_head_rows = block.values[1];
            }
        Dictionary pressure;
        pressure["family_version"] = static_cast<std::int64_t>(cybersand::PressureFlowParameters::kVersion);
        pressure["gas_enabled"] = effective.gas_enabled;
        pressure["atmospheric_head_rows"] = static_cast<std::int64_t>(effective.atmospheric_head_rows);
        pressure["flow_scale"] = static_cast<std::int64_t>(cybersand::PressureFlowParameters::kFlowScale);
        pressure["compartment_volume_limit"] =
            static_cast<std::int64_t>(cybersand::PressureFlowParameters::kCompartmentVolumeLimit);
        pressure["compartment_capacity"] =
            static_cast<std::int64_t>(cybersand::PressureFlowParameters::kCompartmentCapacity);
        pressure["acceleration"] = static_cast<std::int64_t>(cybersand::PressureFlowParameters::kAccelNumerator);
        pressure["retain_per_256"] = static_cast<std::int64_t>(cybersand::PressureFlowParameters::kRetain);
        pressure["friction"] = static_cast<std::int64_t>(cybersand::PressureFlowParameters::kFriction);
        pressure["start_dead_band_per_255"] =
            static_cast<std::int64_t>(cybersand::PressureFlowParameters::kStartDeadBand255);
        pressure["moving_dead_band_per_255"] =
            static_cast<std::int64_t>(cybersand::PressureFlowParameters::kMovingDeadBand255);
        pressure["overfill_limit"] = "maximum()";
        pressure["adhesion_film"] = "resting cells only";
        parameters["pressure_flow_v1"] = pressure;
    }
    result["family_parameters"] = parameters;
    result["physical_state_hash_version"] = static_cast<std::int64_t>(actual ? actual->physical_state_hash_version() : (inertial ? 3 : 2));
    result["physical_state_format_version"] = static_cast<std::int64_t>(actual ? actual->physical_state_format_version() : (inertial ? 3 : 2));
    result["minimum_rule_radius"] = static_cast<std::int64_t>(inertial ? cybersand::InertialParameters::kExecutionRadius : 2);
    result["maximum_rule_radius"] = actual ? Variant(static_cast<std::int64_t>(actual->config().maximum_rule_radius)) : Variant();
    result["normalization"] = Variant();
    result["refusal"] = Variant();
    return result;
}

String CyberNativeCellWorld::get_physical_state_hash() const {
    if (world_ == nullptr) return {};
    char text[17];
    std::snprintf(text, sizeof(text), "%016llx", static_cast<unsigned long long>(world_->physical_state_hash()));
    return String(text);
}

std::int64_t CyberNativeCellWorld::get_physical_state_hash_version() const {
    return world_ ? static_cast<std::int64_t>(world_->physical_state_hash_version()) : 0;
}

std::int64_t CyberNativeCellWorld::get_physical_state_format_version() const {
    return world_ ? static_cast<std::int64_t>(world_->physical_state_format_version()) : 0;
}

Dictionary CyberNativeCellWorld::inspect_inertial_cell(Vector2i point) const {
    if (!world_ || world_->has_failed() || point.x < 0 || point.y < 0 || point.x >= kWorldWidth || point.y >= kWorldHeight) {
        Dictionary refused; refused["ok"] = false; refused["error"] = "Healthy finite native cell required";
        return refused;
    }
    const auto state = world_->inertial_cell(point.x,point.y);
    Dictionary out;
    out["ok"] = true;
    out["available"] = state.available;
    out["material"] = static_cast<std::int64_t>(world_->stored_material(point.x,point.y));
    out["inertial_family"] = world_->inertial_family(world_->stored_material(point.x,point.y));
    out["vx"] = state.vx; out["vy"] = state.vy; out["ax"] = state.ax; out["ay"] = state.ay;
    out["physical_state_hash_version"] = static_cast<std::int64_t>(world_->physical_state_hash_version());
    return out;
}

namespace {
Dictionary gas_compartment_dictionary(const cybersand::GasCompartmentSnapshot& c) {
    Dictionary out;
    out["id"] = static_cast<std::int64_t>(c.id);
    out["generation"] = static_cast<std::int64_t>(c.generation);
    Array parents;
    for (std::size_t i = 0; i < c.parent_count; ++i) parents.push_back(static_cast<std::int64_t>(c.parents[i]));
    out["ancestry"] = parents;
    out["amount"] = static_cast<std::int64_t>(c.amount);
    out["volume"] = static_cast<std::int64_t>(c.volume);
    out["anchor"] = Vector2i(static_cast<std::int32_t>(c.anchor_x), static_cast<std::int32_t>(c.anchor_y));
    out["created_tick"] = static_cast<std::int64_t>(c.created_tick);
    out["topology_revision"] = static_cast<std::int64_t>(c.revision);
    out["gauge_mass"] = static_cast<std::int64_t>(c.gauge);
    out["vent_state"] = "sealed";
    return out;
}
}  // namespace

Dictionary CyberNativeCellWorld::inspect_gas_compartments() const {
    Dictionary out;
    out["available"] = world_ != nullptr && world_->pressure_flow_enabled();
    if (world_ == nullptr || !world_->pressure_flow_enabled()) return out;
    const auto parameters = world_->pressure_flow_parameters();
    out["gas_enabled"] = parameters.gas_enabled;
    out["atmospheric_head_rows"] = static_cast<std::int64_t>(parameters.atmospheric_head_rows);
    out["topology_revision"] = static_cast<std::int64_t>(world_->gas_topology_revision());
    out["next_id"] = static_cast<std::int64_t>(world_->gas_next_id());
    out["completed_tick"] = static_cast<std::int64_t>(world_->completed_tick_index());
    Array compartments;
    for (const auto& c : world_->gas_compartments()) compartments.push_back(gas_compartment_dictionary(c));
    out["compartments"] = compartments;
    Array history;
    for (const auto& record : world_->gas_history()) {
        auto entry = gas_compartment_dictionary(record.compartment);
        static constexpr const char* kReasons[] = {"", "merged", "split", "vented", "collapsed"};
        entry["vent_state"] = record.reason == cybersand::GasRetireReason::Vented ? "vented" : "retired";
        entry["retired"] = kReasons[static_cast<std::size_t>(record.reason)];
        Array successors;
        for (std::size_t i = 0; i < record.successor_count; ++i)
            successors.push_back(static_cast<std::int64_t>(record.successors[i]));
        entry["successors"] = successors;
        entry["retired_tick"] = static_cast<std::int64_t>(record.tick);
        history.push_back(entry);
    }
    out["history"] = history;
    const auto ledger = world_->gas_ledger();
    Dictionary book;
    book["created"] = static_cast<std::int64_t>(ledger.created);
    book["absorbed"] = static_cast<std::int64_t>(ledger.absorbed);
    book["vented"] = static_cast<std::int64_t>(ledger.vented);
    book["collapsed"] = static_cast<std::int64_t>(ledger.collapsed);
    book["merges"] = static_cast<std::int64_t>(ledger.merges);
    book["splits"] = static_cast<std::int64_t>(ledger.splits);
    book["creations"] = static_cast<std::int64_t>(ledger.creations);
    book["vents"] = static_cast<std::int64_t>(ledger.vents);
    book["collapses"] = static_cast<std::int64_t>(ledger.collapses);
    book["amount_live"] = static_cast<std::int64_t>(ledger.amount_live);
    book["closes"] = ledger.amount_live + ledger.vented + ledger.collapsed == ledger.created + ledger.absorbed;
    out["ledger"] = book;
    return out;
}

Dictionary CyberNativeCellWorld::inspect_pressure_cell(Vector2i point) const {
    Dictionary out;
    out["available"] = false;
    if (world_ == nullptr || !in_bounds(point.x, point.y)) return out;
    const auto state = world_->pressure_cell(point.x, point.y);
    out["available"] = state.available;
    out["material"] = static_cast<std::int64_t>(world_->stored_material(point.x, point.y));
    out["state_a"] = static_cast<std::int64_t>(world_->stored_state_a(point.x, point.y));
    out["overfill"] = static_cast<std::int64_t>(state.overfill);
    out["flow"] = static_cast<std::int64_t>(state.flow);
    String gas = "compartment";
    if (state.gas == cybersand::kAtmosphereLabel) gas = "atmosphere";
    else if (state.gas == cybersand::kVacuumLabel) gas = "vacuum";
    else if (state.gas == 0U) gas = "unresolved";
    out["gas"] = gas;
    out["gas_compartment"] = state.gas == 0U || state.gas >= cybersand::kVacuumLabel
        ? Variant() : Variant(static_cast<std::int64_t>(state.gas));
    return out;
}

Dictionary CyberNativeCellWorld::get_pressure_flow_ledger() const {
    Dictionary out;
    out["available"] = world_ != nullptr && world_->pressure_flow_enabled();
    if (world_ == nullptr || !world_->pressure_flow_enabled()) return out;
    const auto ledger = world_->pressure_flow_ledger();
    out["overfill_converted"] = static_cast<std::int64_t>(ledger.overfill_converted);
    out["overfill_external"] = static_cast<std::int64_t>(ledger.overfill_external);
    out["flow_remainder"] = static_cast<std::int64_t>(ledger.flow_remainder);
    out["contact_loss"] = static_cast<std::int64_t>(ledger.contact_loss);
    out["relief_cells"] = static_cast<std::int64_t>(ledger.relief_cells);
    const auto d = world_->pressure_flow_diagnostics();
    Dictionary diagnostics;
    diagnostics["head_cells"] = static_cast<std::int64_t>(d.head_cells);
    diagnostics["unknown_heads"] = static_cast<std::int64_t>(d.unknown_heads);
    diagnostics["gas_visited"] = static_cast<std::int64_t>(d.gas_visited);
    diagnostics["gas_regions"] = static_cast<std::int64_t>(d.gas_regions);
    diagnostics["atmosphere_regions"] = static_cast<std::int64_t>(d.atmosphere_regions);
    diagnostics["chunk_allocations"] = static_cast<std::int64_t>(d.chunk_allocations);
    diagnostics["woken_blocks"] = static_cast<std::int64_t>(d.woken_blocks);
    out["last_tick"] = diagnostics;
    return out;
}

Dictionary CyberNativeCellWorld::get_liquid_run_receipt(const Dictionary& setup) const {
    Dictionary out;
    if (world_ == nullptr) return out;
    const auto& config = world_->config();
    cybersand::Sha256 hash;
    const auto put = [&hash](const std::string& value) {
        const auto length = static_cast<std::uint32_t>(value.size());
        const std::array<std::uint8_t, 4> le{static_cast<std::uint8_t>(length), static_cast<std::uint8_t>(length >> 8U),
                                             static_cast<std::uint8_t>(length >> 16U),
                                             static_cast<std::uint8_t>(length >> 24U)};
        hash.update(le);
        hash.update({reinterpret_cast<const std::uint8_t*>(value.data()), value.size()});
    };
    put(std::string("lcb-run-receipt-v1"));
    Dictionary components;
    const auto add = [&](const char* key, const std::string& value) {
        put(key);
        put(value);
        components[key] = String(value.c_str());
    };
    add("policy_hash", world_->liquid_solver_policy().policy_hash_hex());
    const auto& water = config.water_experiment_policy;
    // Append-only assembly (liquid_policy_detail::concat): string&& + string&&
    // front insertion imports a GLIBCXX symbol above the Linux runtime floor.
    using cybersand::liquid_policy_detail::concat;
    add("water_policy", concat(static_cast<int>(water.version()), ":", static_cast<int>(water.mass_bits()), ":",
                               static_cast<int>(water.coherence_ticks()), ":", static_cast<int>(water.rest_policy())));
    std::string transport = "baseline";
    if (config.transport_policy.configured) {
        cybersand::Sha256 transport_hash;
        for (const auto n : config.transport_policy.horizontal) transport_hash.update(std::array<std::uint8_t, 1>{n});
        for (const auto n : config.transport_policy.cadence) transport_hash.update(std::array<std::uint8_t, 1>{n});
        for (const auto& pair : config.transport_policy.pairs)
            transport_hash.update(std::array<std::uint8_t, 6>{pair.mixing, pair.carrying, pair.pickup, pair.packing,
                                                              pair.erosion, pair.permeability});
        transport = cybersand::Sha256::hex(transport_hash.finish());
    }
    add("transport_profile", transport);
    add("interaction_policy", concat(static_cast<int>(config.interaction_policy.downward_support_cells), ":",
                                     static_cast<int>(config.interaction_policy.side_support_cells), ":",
                                     config.interaction_policy.mercury_exchange_period));
    add("workers", concat(config.worker_threads));
    add("backend", concat(static_cast<int>(config.backend)));
    add("scheduler", concat(config.chunk_size, ":", config.activity_block_size, ":", config.scheduling_core_size, ":",
                            config.maximum_rule_radius, ":", config.sleep_after_quiet_ticks));
    add("diagnostic_physics", concat(config.physics_diagnostics.disable_powder_exchange_targets ? 1 : 0, ":",
                                     config.physics_diagnostics.mercury_viscosity));
    add("execution", concat(simulation_window_enabled_ ? "window" : "full", ":", cadence_lod_enabled_ ? "lod" : "nolod",
                            ":", liquid_surface_adhesion_enabled_ ? "adhesion" : "noadhesion"));
    const auto region = world_->simulation_region();
    add("simulation_region", region ? concat(region->x, ":", region->y, ":", region->width, ":", region->height)
                                     : std::string("unrestricted"));
    add("physical_state_hash_version", concat(world_->physical_state_hash_version()));
    if (world_->inertial_enabled())
        add("inertial_parameter_identity", cybersand::Sha256::hex(cybersand::inertial_extension_identity(world_->inertial_parameters())));
    for (const char* key : {"setup_hash", "seed", "normalization_receipt", "source_revision", "native_binary_sha256",
                            "catalogue_digest"}) {
        const auto value = setup.has(key) ? std::string(String(setup[key]).utf8().get_data()) : std::string("none");
        add(key, value);
    }
    out["receipt_hash"] = String(cybersand::Sha256::hex(hash.finish()).c_str());
    out["components"] = components;
    out["tick"] = static_cast<std::int64_t>(world_->completed_tick_index());
    return out;
}

Dictionary CyberNativeCellWorld::get_applied_liquid_construction_receipt() const {
    // This is the immutable tick-zero value; ordinary ticks do not recapture it.
    return applied_liquid_construction_receipt_.duplicate(true);
}

void CyberNativeCellWorld::retire_liquid_construction_identity() {
    default_demo_recipe_active_ = false;
    pending_liquid_world_.reset();
    applied_liquid_construction_receipt_.clear();
    liquid_construction_attempt_.clear();
    applied_liquid_setup_ = {};
    applied_liquid_setup_.domain = {0, 0, kWorldWidth, kWorldHeight};
}

Dictionary CyberNativeCellWorld::get_liquid_construction_attempt() const {
    return liquid_construction_attempt_.duplicate(true);
}


Dictionary CyberNativeCellWorld::get_liquid_solver_policy() const {
    if (world_ == nullptr) return {};
    return liquid_policy_receipt(world_->liquid_solver_policy(),
                                 static_cast<std::int64_t>(liquid_policy_session_generation_),world_.get());
}

std::int64_t CyberNativeCellWorld::get_liquid_policy_session_generation() const {
    return static_cast<std::int64_t>(liquid_policy_session_generation_);
}

bool CyberNativeCellWorld::water_experiment_fill_rect(
    Vector2i origin, Vector2i size, std::int64_t normalized_mass,
    std::int64_t coherence) {
    if (world_ == nullptr || world_->has_failed() || normalized_mass < 1 ||
        normalized_mass > 255 || coherence < 0 ||
        coherence > world_->config().water_experiment_policy.coherence_ticks() ||
        size.x < 1 || size.y < 1 ||
        !in_bounds(origin.x, origin.y) ||
        !in_bounds(static_cast<std::int64_t>(origin.x) + size.x - 1,
                   static_cast<std::int64_t>(origin.y) + size.y - 1)) {
        return false;
    }
    const auto& policy = world_->config().water_experiment_policy;
    const auto mass = static_cast<std::uint16_t>(
        (2U * static_cast<std::uint32_t>(normalized_mass) * policy.maximum() + 255U) /
        (2U * 255U));
    // A registered physical source can sit below a candidate lattice's first
    // representable unit. It is a valid, observable zero-delta action, not a
    // runtime failure or hidden accumulation channel.
    if (mass == 0U) return true;
    bool changed = false;
    for (auto y = origin.y; y < origin.y + size.y; ++y) {
        for (auto x = origin.x; x < origin.x + size.x; ++x) {
            if (world_->stored_material(x, y) == cybersand::Material::Water &&
                world_->stored_state_a(x, y) == mass &&
                world_->stored_state_b(x, y) == coherence) {
                continue;
            }
            if (!world_->set_cell_state(x, y, cybersand::Material::Water, mass,
                                        static_cast<std::uint8_t>(coherence))) {
                return false;
            }
            changed = true;
        }
    }
    if (changed) ++revision_;
    return true;
}

bool CyberNativeCellWorld::water_experiment_erase_rect(Vector2i origin, Vector2i size) {
    if (world_ == nullptr || world_->has_failed() || size.x < 1 || size.y < 1 ||
        !in_bounds(origin.x, origin.y) ||
        !in_bounds(static_cast<std::int64_t>(origin.x) + size.x - 1,
                   static_cast<std::int64_t>(origin.y) + size.y - 1)) {
        return false;
    }
    bool changed = false;
    bool hard_surface_changed = false;
    for (auto y = origin.y; y < origin.y + size.y; ++y) {
        for (auto x = origin.x; x < origin.x + size.x; ++x) {
            const auto previous = world_->stored_material(x, y);
            if (previous == cybersand::Material::Empty) continue;
            if (!world_->set_cell_state(x, y, cybersand::Material::Empty, 0U, 0U)) {
                return false;
            }
            changed = true;
            hard_surface_changed = hard_surface_changed ||
                cybersand::MaterialRules::is_hard_surface(previous);
        }
    }
    if (changed) ++revision_;
    if (hard_surface_changed) ++hard_surface_revision_;
    return true;
}

Dictionary CyberNativeCellWorld::water_experiment_observation(
    Vector2i origin, Vector2i size) const {
    Dictionary result;
    if (world_ == nullptr || size.x < 1 || size.y < 1 ||
        !in_bounds(origin.x, origin.y) ||
        !in_bounds(static_cast<std::int64_t>(origin.x) + size.x - 1,
                   static_cast<std::int64_t>(origin.y) + size.y - 1)) {
        return result;
    }
    std::uint64_t water_integer = 0;
    std::uint64_t water_cells = 0;
    std::uint64_t water_overfill = 0;
    const bool pressure = world_->pressure_flow_enabled();
    for (auto y = origin.y; y < origin.y + size.y; ++y) {
        for (auto x = origin.x; x < origin.x + size.x; ++x) {
            if (world_->stored_material(x, y) == cybersand::Material::Water) {
                water_integer += world_->stored_state_a(x, y);
                if (pressure) water_overfill += world_->pressure_cell(x, y).overfill;
                ++water_cells;
            }
        }
    }
    result["tick"] = world_->tick_index();
    // pressure_flow_v1 quantity is visible state_a plus never-rendered overfill;
    // overfill is identically zero under every other family.
    result["water_visible"] = water_integer;
    result["water_overfill"] = water_overfill;
    water_integer += water_overfill;
    result["water_integer"] = water_integer;
    result["water_cells"] = water_cells;
    result["content_hash"] = String::num_uint64(world_->content_hash(), 16);
    result["state_hash"] = String::num_uint64(world_->state_hash(), 16);
    return result;
}

Dictionary CyberNativeCellWorld::diagnostic_snapshot(Vector2i origin, Vector2i size, bool include_histogram) const {
    Dictionary result;
    if (!diagnostic_fixture_ || size.x < 1 || size.y < 1 || size.x > 512 || size.y > 768 ||
        !in_bounds(origin.x, origin.y) || !in_bounds(static_cast<std::int64_t>(origin.x) + size.x - 1,
                                                   static_cast<std::int64_t>(origin.y) + size.y - 1)) return result;
    std::array<std::int64_t, cybersand::kMaterialDefinitions.size()> counts{}, sum_y{};
    PackedByteArray cells;
    cells.resize(static_cast<std::int64_t>(size.x) * size.y);
    auto* bytes = cells.ptrw();
    std::int64_t water = 0;
    for (auto y = 0; y < size.y; ++y) for (auto x = 0; x < size.x; ++x) {
        const auto m = static_cast<std::uint8_t>(world_->stored_material(origin.x + x, origin.y + y));
        bytes[y * size.x + x] = m;
        ++counts[m]; sum_y[m] += y + origin.y;
        // liquid_mass() is an occupancy query and hides cells under a body.
        // Conservation must count authoritative stored mass, including overlap.
        if (m == static_cast<std::uint8_t>(cybersand::Material::Water))
            water += world_->stored_state_a(origin.x + x, origin.y + y);
    }
    Array material_counts, material_sum_y;
    for (std::size_t i = 0; i < counts.size(); ++i) { material_counts.append(counts[i]); material_sum_y.append(sum_y[i]); }
    result["counts"] = material_counts; result["sum_y"] = material_sum_y;
    result["water_mass"] = water; result["cells"] = cells;
    result["hash"] = String::num_uint64(world_->state_hash(), 16);
    result["completed_ticks"] = static_cast<std::int64_t>(world_->completed_tick_index());
    result["attempted_ticks"] = static_cast<std::int64_t>(world_->tick_index());
    result["failed"] = world_->has_failed();
    result["chunks"] = static_cast<std::int64_t>(world_->chunk_count());
    result["active_chunks"] = static_cast<std::int64_t>(world_->active_chunk_count());
    result["cores"] = static_cast<std::int64_t>(last_stats_.scheduled_cores);
    result["chunk_allocations"] = static_cast<std::int64_t>(last_stats_.chunk_allocations);
    if (const auto* diagnostic = world_->physics_diagnostics()) {
        result["overflow"] = static_cast<std::int64_t>(diagnostic->overflow);
        result["histogram_used"] = static_cast<std::int64_t>(diagnostic->used);
        if (include_histogram) {
            Array histogram;
            for (const auto& entry : diagnostic->entries) if (entry.key != 0) {
                Array row; row.append(entry.key); row.append(static_cast<std::int64_t>(entry.count)); histogram.append(row);
            }
            result["histogram"] = histogram;
        }
    }
    return result;
}

Dictionary CyberNativeCellWorld::diagnostic_bearing_state() const {
    Dictionary result;
    if (!bearing_trace_ || !diagnostic_fixture_ || !world_ || has_failed() || !current_bodies_[1].valid)
        return result;
    const auto& trace = *bearing_trace_;
    const auto& body = current_bodies_[1];
    result["schema"] = 1;
    result["candidate"] = cybersand::bearing_experiment::name(bearing_candidate_);
    result["body_id"] = 1;
    result["sample_serial"] = body.sample_serial;
    result["owner"] = String::num_uint64(get_instance_id());
    result["generation"] = String::num_uint64(liquid_policy_session_generation_);
    result["revision"] = String::num_uint64(revision_);
    result["attempted_tick"] = static_cast<std::int64_t>(world_->tick_index());
    result["completed_tick"] = static_cast<std::int64_t>(world_->completed_tick_index());
    result["mask_cells"] = trace.mask_cells;
    result["masked_below"] = trace.masked_below;
    result["outside_below"] = trace.outside_below;
    result["raw_support"] = trace.raw_support;
    result["probe_capacity"] = 256;
    result["probe_drops"] = trace.dropped;
    Array probes;
    for (std::size_t index = 0; index < trace.used; ++index) {
        const auto& p = trace.probes[index];
        const auto& i = p.inspection;
        Array row;
        for (const auto value : {p.x, p.y, int(i.reason), int(i.stable_below), int(i.stable_around),
                                int(i.paused), int(i.fresh), int(i.unsupported), int(i.missing)}) row.append(value);
        probes.append(row);
    }
    result["probes"] = probes;
    const auto gravity = kGravityImpulsePerMassTick * body.mass;
    const auto arrest = body.velocity.y * body.mass;
    const auto yielding = gravity + std::max(0.0, body.velocity.y - kGravityImpulsePerMassTick) *
        body.mass * (bearing_candidate_ == cybersand::bearing_experiment::Mode::Y1
            ? 1.0 : kGranularYieldVelocityResponse);
    const auto capacity = std::min(kMaximumGranularBearingImpulse,
        static_cast<double>(trace.raw_support) * kGranularImpulseCapacityPerSample);
    result["gravity_reference"] = gravity;
    result["arrest"] = arrest;
    result["yield"] = yielding;
    result["sample_capacity"] = static_cast<double>(trace.raw_support) * kGranularImpulseCapacityPerSample;
    result["capacity"] = capacity;
    result["global_cap"] = kMaximumGranularBearingImpulse;
    result["velocity_gate"] = body.velocity.y > 0.0;
    result["correction_speed_gate"] = body.velocity.y <= kGranularSettleVelocity;
    result["previous_valid"] = trace.previous_valid;
    result["downward_travel"] = trace.downward_travel;
    result["bearing_y"] = observations_[1].bearing.y;
    result["correction_y"] = observations_[1].correction.y;
    Array admissions;
    if (bearing_candidate_ == cybersand::bearing_experiment::Mode::A2) {
        for (std::size_t index=0;index<trace.used;++index) {
            const auto& ray=trace.admissions[index];
            if (ray.used==0) continue; // zero/rising uses the original path
            Dictionary r;
            r["lower"]=ray.lower; r["q"]=ray.q; r["length"]=ray.length;
            r["selected"]=ray.selected; r["stop"]=static_cast<int>(ray.stop);
            Array steps;
            for (std::size_t j=0;j<ray.used;++j) {
                const auto& s=ray.steps[j]; Array row;
                row.append(s.x);row.append(s.y);row.append(s.distance);
                row.append(s.cell.in_bounds);row.append(s.cell.hard);row.append(s.cell.body);row.append(s.cell.supported);
                row.append(static_cast<int>(s.cell.reason));row.append(static_cast<int>(s.cell.stable_below));row.append(static_cast<int>(s.cell.paused));
                row.append(static_cast<int>(s.cell.fresh));row.append(static_cast<int>(s.cell.unsupported));row.append(static_cast<int>(s.cell.missing));
                steps.append(row);
            }
            r["steps"]=steps; admissions.append(r);
        }
    }
    result["admissions"]=admissions;
    return result;
}

Dictionary CyberNativeCellWorld::diagnostic_bearing_candidate() const {
    Dictionary result;
    result["candidate"]=cybersand::bearing_experiment::name(bearing_candidate_);
    result["yield_factor"]=cybersand::bearing_experiment::factor(bearing_candidate_);
    result["phase"]="post_Rapier_T_before_cell_tick; applied_before_Rapier_T_plus_1";
    const auto& w=candidate_observations_[1];
    result["boundaries"]=w.boundaries;result["current_support"]=w.current_support;
    result["selected_support"]=w.selected_support;result["predicted_only"]=w.predicted_only;
    result["cell_tests"]=w.cell_tests;result["predicate_queries"]=w.predicate_queries;
    result["extra_cells"]=w.extra_cells;result["maximum_ray_cells"]=w.maximum_ray_cells;
    result["lookahead"]=w.lookahead;result["maximum_hit_distance"]=w.maximum_hit_distance;
    result["invalid_geometry"]=w.invalid_geometry;
    return result;
}

Array CyberNativeCellWorld::diagnostic_body_metrics() const {
    Array result;
    if (!body_diagnostics_ || has_failed()) return result;
    for (std::size_t id = 1; id < current_bodies_.size(); ++id) {
        if (!current_bodies_[id].valid) continue;
        const auto& d = (*body_diagnostics_)[id];
        const auto& o = observations_[id];
        const Vector2 pixel{static_cast<double>(world_->transient_contact_impulse_x(static_cast<std::uint16_t>(id))) / 1000.0 * contact_gain_,
                            static_cast<double>(world_->transient_contact_impulse_y(static_cast<std::uint16_t>(id))) / 1000.0 * contact_gain_};
        auto pre_final = o.impulse + pixel;
        if (pre_final.length() > impulse_cap_) {
            pre_final = pre_final.normalized() * impulse_cap_;
        }
        if (o.bearing.y < 0.0) {
            pre_final += o.bearing;
            pre_final.y = std::max(pre_final.y, o.bearing.y);
        }
        Array row;
        row.append(static_cast<std::int64_t>(id)); row.append(current_bodies_[id].sample_serial);
        for (const auto v : {d.displacement, d.boundary, pixel, o.impulse, pre_final}) {
            row.append(v.x); row.append(v.y);
        }
        row.append(static_cast<std::int64_t>(d.intermediate_caps));
        row.append((o.impulse + pixel).length() > impulse_cap_);
        row.append(static_cast<std::int64_t>(o.displaced)); row.append(static_cast<std::int64_t>(o.unresolved));
        Array faces;
        for (const auto count : d.faces) faces.append(static_cast<std::int64_t>(count));
        row.append(faces);
        row.append(d.bearing.x); row.append(d.bearing.y);
        row.append(static_cast<std::int64_t>(d.support_samples));
        result.append(row);
    }
    return result;
}

double CyberNativeCellWorld::get_simulation_time_ms() const { return simulation_time_ms_; }
std::int64_t CyberNativeCellWorld::get_worker_threads() const { return worker_threads_; }
String CyberNativeCellWorld::get_backend_name() const { return "native-phased"; }
String CyberNativeCellWorld::get_last_tick_error() const { return last_tick_error_; }
std::int64_t CyberNativeCellWorld::get_tick_failure_count() const {
    return static_cast<std::int64_t>(tick_failure_count_);
}

#include "pressure_optimization_inspection.inc"

}  // namespace godot
