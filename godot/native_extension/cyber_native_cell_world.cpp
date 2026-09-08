#include "cyber_native_cell_world.hpp"

#include "cybersand/material_rules.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <numbers>
#include <span>
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

constexpr double kMaximumBodySweepDistance = 32.0;
constexpr double kBodySweepSampleSpacing = 1.0;
constexpr std::int32_t kMaximumBodySweepSteps = 24;
constexpr std::int32_t kMaximumEjectionDistance = 8;
constexpr double kBodyDisplacementReactionImpulse = 0.18;
constexpr double kBodyBoundaryPressureImpulse = 0.19;
constexpr double kBodyPixelContactImpulse = 0.025;
constexpr double kMaximumBodyImpulsePerTick = 3.0;

[[nodiscard]] double clamped_density_scale(cybersand::Material material,
                                           double minimum = 0.05) {
    const auto density = cybersand::MaterialRules::descriptor(material).density;
    return std::clamp(static_cast<double>(density) / 1000.0, minimum, 1.6);
}

[[nodiscard]] Vector2 normalized_or_zero(Vector2 value) {
    const auto length = value.length();
    return length > 0.000001 ? value / length : Vector2{};
}

}  // namespace

CyberNativeCellWorld::CyberNativeCellWorld() {
    create_world();
    reset_demo_world();
}

CyberNativeCellWorld::~CyberNativeCellWorld() = default;

void CyberNativeCellWorld::_bind_methods() {
    ClassDB::bind_static_method("CyberNativeCellWorld", D_METHOD("auto_worker_threads", "logical_threads"), &CyberNativeCellWorld::auto_worker_threads);
    ClassDB::bind_static_method("CyberNativeCellWorld", D_METHOD("logical_processor_count"), &CyberNativeCellWorld::logical_processor_count);
    ClassDB::bind_method(D_METHOD("reset_demo_world"),
                         &CyberNativeCellWorld::reset_demo_world);
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
    ClassDB::bind_method(D_METHOD("prepare_rigid_body_coupling", "states",
                                  "resolve_overlaps"),
                         &CyberNativeCellWorld::prepare_rigid_body_coupling,
                         DEFVAL(true));
    ClassDB::bind_method(D_METHOD("rigid_body_results"),
                         &CyberNativeCellWorld::rigid_body_results);
    ClassDB::bind_method(D_METHOD("material_at", "x", "y"),
                         &CyberNativeCellWorld::material_at);
    ClassDB::bind_method(D_METHOD("box_collides", "origin", "size"),
                         &CyberNativeCellWorld::box_collides);
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
        auto candidate = std::make_unique<cybersand::World>(world_->config());
        candidate->reserve_region({0, 0, kWorldWidth, kWorldHeight});
        candidate->configure_transient_obstacles({0, 0, kWorldWidth, kWorldHeight});
        candidate->set_liquid_surface_adhesion_enabled(liquid_surface_adhesion_enabled_);

        for (std::int32_t x = 0; x < kWorldWidth; ++x) {
            candidate->set(x, kWorldHeight - 1, cybersand::Material::Wall);
        }
        for (std::int32_t y = 0; y < kWorldHeight; ++y) {
            candidate->set(0, y, cybersand::Material::Wall);
            candidate->set(kWorldWidth - 1, y, cybersand::Material::Wall);
        }
        for (std::int32_t x = 1; x < kWorldWidth - 1; ++x) {
            auto floor_y = (kWorldHeight - 79) +
                           static_cast<std::int32_t>(18.0 * std::sin(x * 0.018));
            floor_y += static_cast<std::int32_t>(7.0 * std::sin(x * 0.071));
            for (std::int32_t y = floor_y; y < kWorldHeight - 1; ++y) {
                candidate->set(x, y, cybersand::Material::Wall);
            }
        }
        for (std::int32_t x = 18; x < 338; ++x) {
            candidate->set(x, 172, cybersand::Material::Wall);
        }
        for (std::int32_t y = 24; y < 112; ++y) {
            for (std::int32_t x = 55; x < 108; ++x) {
                if (((x * 17 + y * 31) % 7) < 4) candidate->set(x, y, cybersand::Material::Sand);
            }
        }
        for (std::int32_t y = 128; y < 172; ++y) {
            for (std::int32_t x = 216; x < 300; ++x) {
                if (((x + y) % 3) != 0) candidate->set(x, y, cybersand::Material::Water);
            }
        }
        for (std::int32_t platform = 0; platform < 5; ++platform) {
            const auto start_x = 360 + platform * 112;
            const auto platform_y = 128 + ((platform * 67) % 260);
            const auto end_x = std::min(kWorldWidth - 18, start_x + 92);
            for (auto x = start_x; x < end_x; ++x) {
                candidate->set(x, platform_y, cybersand::Material::Wall);
            }
        }
        for (std::int32_t y = kWorldHeight - 164; y < kWorldHeight - 106; ++y) {
            for (std::int32_t x = 430; x < 492; ++x) {
                if (((x * 13 + y * 19) % 9) < 5) candidate->set(x, y, cybersand::Material::Smoke);
            }
        }

        candidate->set_simulation_region(world_->simulation_region());
        world_.swap(candidate);
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
            auto state_b = definition.initial_state_b;
            if (material == cybersand::Material::Water && (emission_flags & 1) != 0) {
                state_b = static_cast<std::uint8_t>(kCoherentWaterDelayTicks);
            }
            if (!world_->set_cell_state(x, y, material, definition.initial_state_a, state_b)) {
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
    if (resolve_overlaps) accumulate_boundary_pressure();
    previous_bodies_ = current_bodies_;
}

void CyberNativeCellWorld::clear_observations() {
    observations_ = {};
}

void CyberNativeCellWorld::parse_body_states(const PackedFloat32Array& states) {
    current_bodies_ = {};
    const auto count = std::min<std::int64_t>(
        cybersand::World::kMaximumTransientBodies, states.size() / kInputStride);
    for (std::int64_t body_index = 0; body_index < count; ++body_index) {
        const auto offset = body_index * kInputStride;
        const auto id_value = static_cast<std::int64_t>(std::llround(states[offset + kInputBodyId]));
        if (id_value <= 0 || id_value > cybersand::World::kMaximumTransientBodies) continue;
        auto& body = current_bodies_[static_cast<std::size_t>(id_value)];
        if (body.valid) continue;
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
        body.sample_serial = static_cast<std::int32_t>(
            std::llround(states[offset + kInputSampleSerial]));
        body.valid = true;
    }
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
    const auto steps = std::clamp(
        static_cast<std::int32_t>(std::ceil(sweep_extent / kBodySweepSampleSpacing)),
        1, kMaximumBodySweepSteps);
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
    const auto cosine = std::cos(rotation);
    const auto sine = std::sin(rotation);
    const Vector2 extent{
        std::abs(cosine) * half_size.x + std::abs(sine) * half_size.y,
        std::abs(sine) * half_size.x + std::abs(cosine) * half_size.y,
    };
    const auto first_x = std::clamp(static_cast<std::int32_t>(std::floor(center.x - extent.x)),
                                    0, kWorldWidth - 1);
    const auto last_x = std::clamp(static_cast<std::int32_t>(std::ceil(center.x + extent.x)) - 1,
                                   0, kWorldWidth - 1);
    const auto first_y = std::clamp(static_cast<std::int32_t>(std::floor(center.y - extent.y)),
                                    0, kWorldHeight - 1);
    const auto last_y = std::clamp(static_cast<std::int32_t>(std::ceil(center.y + extent.y)) - 1,
                                   0, kWorldHeight - 1);
    for (auto y = first_y; y <= last_y; ++y) {
        for (auto x = first_x; x <= last_x; ++x) {
            const Vector2 delta{static_cast<double>(x) + 0.5 - center.x,
                                static_cast<double>(y) + 0.5 - center.y};
            const Vector2 local{cosine * delta.x + sine * delta.y,
                                -sine * delta.x + cosine * delta.y};
            if (std::abs(local.x) > half_size.x || std::abs(local.y) > half_size.y) continue;
            if (world_->set_transient_obstacle(x, y, body_id)) {
                raster_indices_.push_back(y * kWorldWidth + x);
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

    const auto target = find_ejection_target(x, y, outward, penetration);
    if (target.x < 0 || !world_->relocate_stored_cell(x, y, target.x, target.y)) {
        ++observation.unresolved;
        record_impulse(body_id, -outward * kBodyDisplacementReactionImpulse);
        return;
    }
    ++observation.displaced;
    record_impulse(body_id, -outward * kBodyDisplacementReactionImpulse *
                                clamped_density_scale(material));
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
                                                    Vector2 outward_normal,
                                                    double penetration) const {
    const Vector2 tangent{-outward_normal.y, outward_normal.x};
    const Vector2 source_center{static_cast<double>(source_x) + 0.5,
                                static_cast<double>(source_y) + 0.5};
    const auto first_distance = std::max(1, static_cast<std::int32_t>(std::ceil(penetration)));
    for (auto distance = first_distance;
         distance <= first_distance + kMaximumEjectionDistance; ++distance) {
        for (std::int32_t probe = 0; probe < 9; ++probe) {
            const auto tangent_offset = symmetric_probe_offset(probe);
            const auto candidate = source_center + outward_normal * distance +
                                   tangent * tangent_offset;
            const auto x = static_cast<std::int32_t>(std::floor(candidate.x));
            const auto y = static_cast<std::int32_t>(std::floor(candidate.y));
            if (!in_bounds(x, y) || world_->transient_obstacle_at(x, y) != 0U ||
                world_->stored_material(x, y) != cybersand::Material::Empty) {
                continue;
            }
            return {x, y};
        }
    }
    return {-1, -1};
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
            record_impulse(body_id, normal * kBodyBoundaryPressureImpulse *
                                        clamped_density_scale(material, 0.01));
        }
    }
}

void CyberNativeCellWorld::record_impulse(std::uint16_t body_id, Vector2 impulse) {
    if (body_id == 0U || body_id >= observations_.size()) return;
    auto combined = observations_[body_id].impulse + impulse;
    if (combined.length() > kMaximumBodyImpulsePerTick) {
        combined = combined.normalized() * kMaximumBodyImpulsePerTick;
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
            static_cast<double>(contact_x) / 1000.0 * kBodyPixelContactImpulse,
            static_cast<double>(contact_y) / 1000.0 * kBodyPixelContactImpulse,
        };
        if (observation.impulse.length() > kMaximumBodyImpulsePerTick) {
            observation.impulse = observation.impulse.normalized() *
                                  kMaximumBodyImpulsePerTick;
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

bool CyberNativeCellWorld::box_collides(Vector2 origin, Vector2 size) const {
    const auto first_x = static_cast<std::int32_t>(std::floor(origin.x + 0.001));
    const auto first_y = static_cast<std::int32_t>(std::floor(origin.y + 0.001));
    const auto last_x = static_cast<std::int32_t>(std::ceil(origin.x + size.x - 0.001)) - 1;
    const auto last_y = static_cast<std::int32_t>(std::ceil(origin.y + size.y - 0.001)) - 1;
    for (auto x = first_x; x <= last_x; ++x) {
        if (character_solid(static_cast<cybersand::Material>(material_at(x, first_y))) ||
            character_solid(static_cast<cybersand::Material>(material_at(x, last_y)))) {
            return true;
        }
    }
    for (auto y = first_y + 1; y < last_y; ++y) {
        if (character_solid(static_cast<cybersand::Material>(material_at(first_x, y))) ||
            character_solid(static_cast<cybersand::Material>(material_at(last_x, y)))) {
            return true;
        }
    }
    return false;
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
    // Collision chunks are intentionally smaller than storage chunks. The
    // main-thread PhysicsServer budget can stop only between complete chunks,
    // so 64x64 bounds a pathological fragmented replacement far better than
    // the previous 128x128 atomic unit.
    constexpr std::int32_t chunk_size = 64;
    constexpr std::int32_t chunk_columns = kWorldWidth / chunk_size;
    constexpr std::int32_t chunk_rows = kWorldHeight / chunk_size;
    constexpr std::int32_t chunk_count = chunk_columns * chunk_rows;
    static_assert(kWorldWidth % chunk_size == 0 && kWorldHeight % chunk_size == 0);

    const auto hard_revision = static_cast<std::uint64_t>(get_hard_surface_revision());
    if (hard_surface_chunk_rectangles_revision_ == hard_revision) {
        return hard_surface_chunk_rectangles_;
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

    std::array<std::vector<Rectangle>, chunk_count> chunk_rectangles;
    const auto* cells = render_cells_.ptr();
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
    hard_surface_chunk_rectangles_.resize(static_cast<std::int64_t>(
        header_size + rectangle_count * 4U));
    auto* packed = hard_surface_chunk_rectangles_.ptrw();
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
    hard_surface_chunk_rectangles_revision_ = hard_revision;
    return hard_surface_chunk_rectangles_;
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

bool CyberNativeCellWorld::character_solid(cybersand::Material material) {
    return cybersand::MaterialRules::is_hard_surface(material) ||
           material == cybersand::Material::Sand;
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
double CyberNativeCellWorld::get_simulation_time_ms() const { return simulation_time_ms_; }
std::int64_t CyberNativeCellWorld::get_worker_threads() const { return worker_threads_; }
String CyberNativeCellWorld::get_backend_name() const { return "native-phased"; }
String CyberNativeCellWorld::get_last_tick_error() const { return last_tick_error_; }
std::int64_t CyberNativeCellWorld::get_tick_failure_count() const {
    return static_cast<std::int64_t>(tick_failure_count_);
}

}  // namespace godot
