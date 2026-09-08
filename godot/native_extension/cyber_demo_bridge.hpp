#pragma once

#include "cyber_native_cell_world.hpp"
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
    [[nodiscard]] String get_last_error() const { return error_; }

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
            auto candidate = cybersand::demo::construct(adapter->world_->config(),
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
        ClassDB::bind_method(D_METHOD("export_level", "world"), &CyberDemoBridge::export_level);
        ClassDB::bind_method(D_METHOD("import_level", "world", "bytes"), &CyberDemoBridge::import_level);
        ClassDB::bind_method(D_METHOD("build_world", "world", "rectangles"), &CyberDemoBridge::build_world);
        ClassDB::bind_method(D_METHOD("queue_explosion", "world", "x", "y", "radius"), &CyberDemoBridge::queue_explosion);
        ClassDB::bind_method(D_METHOD("get_last_error"), &CyberDemoBridge::get_last_error);
    }
};

}  // namespace godot
