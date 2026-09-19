#pragma once

#include "cyber_native_cell_world.hpp"
#include "cyber_observation_values.hpp"
#include "cybersand/demo_snapshot.hpp"
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

// This adapter is not a simulation backend. It constructs/reconstructs the
// existing World and transfers owned packed values at an exclusive boundary.
class CyberDemoBridge final : public RefCounted {
    GDCLASS(CyberDemoBridge, RefCounted)
    String error_;

    static void install(CyberNativeCellWorld& adapter, std::unique_ptr<cybersand::World> candidate) {
        auto exchange = std::make_unique<cybersand::RenderSnapshotExchange>(
            3, 64, std::size_t{cybersand::demo::kWidth} * cybersand::demo::kHeight * 2);
        candidate->set_liquid_surface_adhesion_enabled(adapter.liquid_surface_adhesion_enabled_);
        candidate->set_simulation_region(adapter.world_->simulation_region());
        // All fallible allocation and validation precede these no-throw swaps.
        adapter.world_.swap(candidate);
        adapter.render_exchange_.swap(exchange);
        adapter.current_bodies_ = {};
        adapter.previous_bodies_ = {};
        adapter.clear_observations();
        adapter.raster_indices_.clear();
        adapter.last_stats_ = {};
        adapter.simulation_time_ms_ = 0;
        adapter.tick_failure_count_ = 0;
        adapter.last_tick_error_ = String();
        adapter.render_cells_revision_ = UINT64_MAX;
        adapter.hard_surface_rectangles_revision_ = UINT64_MAX;
        adapter.hard_surface_chunk_rectangles_revision_ = UINT64_MAX;
        adapter.render_snapshot_full_refresh_required_ = true;
        ++adapter.revision_;
        ++adapter.hard_surface_revision_;
    }

public:
    [[nodiscard]] Dictionary inspect_cell(const Ref<CyberNativeCellWorld>& adapter, Vector2i point) const {
        if (adapter.is_null() || !adapter->world_) return cyber_observation::rejected("Native world unavailable");
        return cyber_observation::cell(*adapter->world_, point);
    }

    [[nodiscard]] Dictionary inspect_statistics(const Ref<CyberNativeCellWorld>& adapter) const {
        if (adapter.is_null() || !adapter->world_) return cyber_observation::rejected("Native world unavailable");
        return cyber_observation::statistics(*adapter->world_, adapter->last_stats_);
    }

    [[nodiscard]] String get_last_error() const { return error_; }

    [[nodiscard]] bool build_tuned_world(const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles, const PackedInt32Array& profile) {
        error_ = String();
        if(adapter.is_null() || !adapter->world_) { error_="Native world unavailable"; return false; }
        try {
            auto config = adapter->world_->config();
            config.transport_policy = cybersand::TransportPolicy::unpack(
                {profile.ptr(),static_cast<std::size_t>(profile.size())});
            config.physics_diagnostics = {}; config.physics_diagnostics.enabled = true;
            config.interaction_policy = {};
            config.water_experiment_policy = cybersand::WaterExperimentPolicy{};
            auto candidate=cybersand::demo::construct(config,
                {rectangles.ptr(),static_cast<std::size_t>(rectangles.size())});
            install(*adapter.ptr(),std::move(candidate));
            return true;
        } catch(const std::exception& error) { error_=error.what(); return false; }
    }

    [[nodiscard]] bool build_water_feel_world(
        const Ref<CyberNativeCellWorld>& adapter,
        const PackedInt32Array& rectangles,
        const PackedInt32Array& profile,
        const PackedInt32Array& policy,
        const PackedInt32Array& water_fills) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            if (policy.size() != 4 || policy[0] != 1 || policy[1] < 3 || policy[1] > 8 ||
                policy[2] < 0 || policy[2] > 12 || policy[3] != 0) {
                throw std::invalid_argument("Invalid Water experiment policy");
            }
            if (water_fills.size() % 6 != 0 ||
                water_fills.size() / 6 >
                    static_cast<std::int64_t>(cybersand::demo::kMaximumRectangles)) {
                throw std::invalid_argument("Invalid Water fill count");
            }
            std::uint64_t fill_area = 0;
            for (std::int64_t i = 0; i < water_fills.size(); i += 6) {
                const auto x = water_fills[i], y = water_fills[i + 1];
                const auto width = water_fills[i + 2], height = water_fills[i + 3];
                const auto normalized_mass = water_fills[i + 4];
                const auto coherence = water_fills[i + 5];
                if (x < 0 || y < 0 || width <= 0 || height <= 0 ||
                    width > cybersand::demo::kWidth || height > cybersand::demo::kHeight ||
                    x > cybersand::demo::kWidth - width ||
                    y > cybersand::demo::kHeight - height ||
                    normalized_mass < 0 || normalized_mass > 255 ||
                    coherence < 0 || coherence > 12) {
                    throw std::invalid_argument("Invalid Water fill");
                }
                fill_area += static_cast<std::uint64_t>(width) *
                             static_cast<std::uint64_t>(height);
                if (fill_area > static_cast<std::uint64_t>(cybersand::demo::kWidth) *
                                    cybersand::demo::kHeight) {
                    throw std::invalid_argument("Water fill budget exceeded");
                }
            }

            auto config = adapter->world_->config();
            config.transport_policy = cybersand::TransportPolicy::unpack(
                {profile.ptr(), static_cast<std::size_t>(profile.size())});
            config.physics_diagnostics = {};
            config.physics_diagnostics.enabled = true;
            config.interaction_policy = {};
            config.water_experiment_policy = cybersand::WaterExperimentPolicy(
                static_cast<std::uint8_t>(policy[1]),
                static_cast<std::uint8_t>(policy[2]),
                cybersand::WaterRestPolicy::CurrentNormalizedV1);
            auto candidate = cybersand::demo::construct(
                config, {rectangles.ptr(), static_cast<std::size_t>(rectangles.size())});
            const auto& water_policy = candidate->config().water_experiment_policy;
            for (std::int64_t i = 0; i < water_fills.size(); i += 6) {
                const auto mass = static_cast<std::uint16_t>(
                    (2U * static_cast<std::uint32_t>(water_fills[i + 4]) *
                         water_policy.maximum() + 255U) /
                    (2U * 255U));
                const auto coherence = static_cast<std::uint8_t>(
                    (2U * static_cast<std::uint32_t>(water_fills[i + 5]) *
                         water_policy.coherence_ticks() + 12U) /
                    (2U * 12U));
                if (mass == 0U) continue;
                for (auto y = water_fills[i + 1];
                     y < water_fills[i + 1] + water_fills[i + 3]; ++y) {
                    for (auto x = water_fills[i];
                         x < water_fills[i] + water_fills[i + 2]; ++x) {
                        if (!candidate->set_cell_state(
                                x, y, cybersand::Material::Water, mass, coherence)) {
                            throw std::invalid_argument("Water fill could not be applied");
                        }
                    }
                }
            }
            install(*adapter.ptr(), std::move(candidate));
            return true;
        } catch (const std::exception& error) {
            error_ = error.what();
            return false;
        }
    }

    [[nodiscard]] PackedByteArray export_level(const Ref<CyberNativeCellWorld>& adapter) {
        error_ = String();
        PackedByteArray bytes;
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return bytes;
        }
        try {
            bytes.resize(static_cast<std::int64_t>(cybersand::demo::kPayloadBytes));
            cybersand::demo::copy_level(*adapter->world_,
                {bytes.ptrw(), static_cast<std::size_t>(bytes.size())});
        } catch (const std::exception& error) {
            error_ = error.what();
            bytes = PackedByteArray();
        }
        return bytes;
    }

    [[nodiscard]] bool import_level(const Ref<CyberNativeCellWorld>& adapter, const PackedByteArray& bytes) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            auto candidate = cybersand::demo::reconstruct(adapter->world_->config(),
                {bytes.ptr(), static_cast<std::size_t>(bytes.size())});
            install(*adapter.ptr(), std::move(candidate));
            return true;
        } catch (const std::exception& error) {
            error_ = error.what();
            return false;
        }
    }

    [[nodiscard]] bool build_world(const Ref<CyberNativeCellWorld>& adapter, const PackedInt32Array& rectangles) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_) {
            error_ = "Native world unavailable";
            return false;
        }
        try {
            auto config = adapter->world_->config();
            config.transport_policy = {}; // Ordinary demos retain production Baseline.
            config.water_experiment_policy = cybersand::WaterExperimentPolicy{};
            auto candidate = cybersand::demo::construct(config,
                {rectangles.ptr(), static_cast<std::size_t>(rectangles.size())});
            install(*adapter.ptr(), std::move(candidate));
            return true;
        } catch (const std::exception& error) {
            error_ = error.what();
            return false;
        }
    }

    [[nodiscard]] bool queue_explosion(const Ref<CyberNativeCellWorld>& adapter,
        std::int64_t x, std::int64_t y, std::int64_t radius) {
        error_ = String();
        if (adapter.is_null() || !adapter->world_ || x < 0 || y < 0 ||
            x >= cybersand::demo::kWidth || y >= cybersand::demo::kHeight || radius < 1 || radius > 64) {
            error_ = "Explosion outside supported bounds";
            return false;
        }
        if (adapter->world_->has_failed()) {
            error_ = "World failed; reset or replace it before accepting explosions";
            return false;
        }
        if (!adapter->world_->queue_explosion(x, y, static_cast<std::int32_t>(radius))) {
            error_ = "Explosion queue capacity exhausted";
            return false;
        }
        return true;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("inspect_cell", "world", "point"), &CyberDemoBridge::inspect_cell);
        ClassDB::bind_method(D_METHOD("inspect_statistics", "world"), &CyberDemoBridge::inspect_statistics);
        ClassDB::bind_method(D_METHOD("export_level", "world"), &CyberDemoBridge::export_level);
        ClassDB::bind_method(D_METHOD("import_level", "world", "bytes"), &CyberDemoBridge::import_level);
        ClassDB::bind_method(D_METHOD("build_world", "world", "rectangles"), &CyberDemoBridge::build_world);
        ClassDB::bind_method(D_METHOD("build_tuned_world", "world", "rectangles", "profile"), &CyberDemoBridge::build_tuned_world);
        ClassDB::bind_method(D_METHOD("build_water_feel_world", "world", "rectangles",
                                     "profile", "policy", "water_fills"),
                             &CyberDemoBridge::build_water_feel_world);
        ClassDB::bind_method(D_METHOD("queue_explosion", "world", "x", "y", "radius"), &CyberDemoBridge::queue_explosion);
        ClassDB::bind_method(D_METHOD("get_last_error"), &CyberDemoBridge::get_last_error);
    }
};

}  // namespace godot
