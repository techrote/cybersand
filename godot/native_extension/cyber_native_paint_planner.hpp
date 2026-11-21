#pragma once

#include "cybersand/paint_fill_planner.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/rect2i.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <cstdint>

namespace godot {

// A pure value-only convenience service. No World, rendering, or scene ownership.
class CyberNativePaintPlanner final : public RefCounted {
    GDCLASS(CyberNativePaintPlanner, RefCounted)

public:
    std::int64_t interface_version() const { return 1; }

    Dictionary fill_connected(
        Vector2i seed_cell, Vector2i sample_origin, Vector2i sample_size,
        const PackedInt32Array& sample_materials, Vector2i extent,
        std::int64_t cell_limit) const {
        const auto result = cybersand::paint_fill::plan(
            seed_cell.x, seed_cell.y, sample_origin.x, sample_origin.y,
            sample_size.x, sample_size.y,
            sample_materials.ptr(), static_cast<std::size_t>(sample_materials.size()),
            extent.x, extent.y, cell_limit);
        Dictionary answer;
        const bool accepted = result.outcome == cybersand::paint_fill::Outcome::accepted;
        answer["accepted"] = accepted;
        if (!accepted) {
            answer["cells"] = PackedInt32Array();
            answer["count"] = 0;
            if (result.outcome == cybersand::paint_fill::Outcome::budget_exceeded) {
                answer["error"] = String("Connected fill exceeds the ") +
                    String::num_int64(cell_limit) + "-cell operation budget; no partial fill.";
            } else {
                answer["error"] = String::utf8(cybersand::paint_fill::error(result.outcome));
            }
            if (result.outcome == cybersand::paint_fill::Outcome::unread_edge) {
                answer["unread_edge"] = String(result.first_unread_edge);
                answer["component_bounds"] = Rect2i(
                    Vector2i(result.min_x, result.min_y),
                    Vector2i(result.max_x - result.min_x + 1, result.max_y - result.min_y + 1));
            }
            return answer;
        }
        PackedInt32Array cells;
        cells.resize(static_cast<std::int64_t>(result.indices.size()) * 2);
        const std::int32_t width = sample_size.x;
        for (std::size_t i = 0; i < result.indices.size(); ++i) {
            const std::int32_t local = result.indices[i];
            cells.set(static_cast<std::int64_t>(i) * 2, sample_origin.x + local % width);
            cells.set(static_cast<std::int64_t>(i) * 2 + 1, sample_origin.y + local / width);
        }
        answer["cells"] = cells;
        answer["count"] = static_cast<std::int64_t>(result.indices.size());
        answer["clipped"] = false;
        answer["source_material_id"] = result.source_material;
        return answer;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("interface_version"), &CyberNativePaintPlanner::interface_version);
        ClassDB::bind_method(
            D_METHOD("fill_connected", "seed_cell", "sample_origin", "sample_size",
                     "sample_materials", "extent", "cell_limit"),
            &CyberNativePaintPlanner::fill_connected);
    }
};

} // namespace godot
