#pragma once

#include "cybersand/demo_snapshot.hpp"
#include "cybersand/world.hpp"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace godot::cyber_observation {

// Serialized, exclusive-owner queries. These allocate only copied adapter values;
// they never wake cells, consume dirty state, clear body masks, or enter a worker.
inline Dictionary rejected(const char* reason) {
    Dictionary out;
    out["ok"] = false;
    out["error"] = reason;
    return out;
}

inline Dictionary cell(const cybersand::World& world, Vector2i point) {
    if (world.has_failed()) return rejected("World quarantined; fresh reset required");
    if (point.x < 0 || point.y < 0 || point.x >= cybersand::demo::kWidth ||
        point.y >= cybersand::demo::kHeight) return rejected("Cell outside finite demo world");
    Dictionary out;
    out["ok"] = true;
    out["x"] = point.x;
    out["y"] = point.y;
    out["completed_tick"] = static_cast<int64_t>(world.completed_tick_index());
    out["material"] = static_cast<int64_t>(world.stored_material(point.x, point.y));
    out["state_a"] = world.stored_state_a(point.x, point.y);
    out["state_b"] = world.stored_state_b(point.x, point.y);
    const auto body = world.transient_obstacle_at(point.x, point.y);
    out["transient_body_id"] = body;
    // World::temperature is occupancy-masked. Do not misreport ambient as the
    // hidden cell's temperature, or remove the mask to implement inspection.
    out["temperature_available"] = body == 0U;
    out["temperature_raw"] = body == 0U ? Variant(world.temperature(point.x, point.y)) : Variant();
    out["temperature_units"] = "engine raw integer; not a calibrated heat solver";
    Array chunk;
    chunk.append(point.x / world.config().chunk_size);
    chunk.append(point.y / world.config().chunk_size);
    out["chunk_coordinate"] = chunk;
    Array block;
    block.append(point.x / world.config().activity_block_size);
    block.append(point.y / world.config().activity_block_size);
    out["activity_block_coordinate"] = block;
    out["scope"] = "stored cell values; block coordinates are not a per-cell awake flag";
    return out;
}

inline Dictionary statistics(const cybersand::World& world, const cybersand::TickStats& last) {
    if (world.has_failed()) return rejected("World quarantined; no partial tick statistics exported");
    const auto& config = world.config();
    Dictionary limits;
    limits["maximum_chunks"] = static_cast<int64_t>(config.maximum_chunk_count);
    limits["active_chunks"] = static_cast<int64_t>(config.active_chunk_capacity);
    limits["active_cores"] = static_cast<int64_t>(config.active_core_capacity);
    limits["deferred_events"] = static_cast<int64_t>(config.deferred_event_capacity);
    limits["maximum_explosion_radius"] = config.maximum_explosion_radius;
    Dictionary values;
    values["resident_chunks"] = static_cast<int64_t>(world.chunk_count());
    values["active_chunks"] = static_cast<int64_t>(world.active_chunk_count());
    values["resident_cell_bytes"] = static_cast<int64_t>(world.resident_cell_bytes());
    values["active_blocks_after"] = static_cast<int64_t>(last.active_blocks_after);
    values["visited_cells"] = static_cast<int64_t>(last.visited_cells);
    values["moved_cells"] = static_cast<int64_t>(last.moved_cells);
    values["scheduled_cores"] = static_cast<int64_t>(last.scheduled_cores);
    values["chunk_allocations"] = static_cast<int64_t>(last.chunk_allocations);
    values["temperature_field_allocations"] = static_cast<int64_t>(last.temperature_field_allocations);
    values["deferred_events_processed"] = static_cast<int64_t>(last.deferred_events);
    Array phases;
    for (const auto jobs : last.phase_jobs) phases.append(static_cast<int64_t>(jobs));
    Dictionary out;
    out["ok"] = true;
    out["completed_tick"] = static_cast<int64_t>(world.completed_tick_index());
    out["limits"] = limits;
    out["values"] = values;
    out["phase_jobs_last_tick"] = phases;
    out["scope"] = "completed native tick counts and current storage; phase jobs are not per-worker utilization";
    Array unavailable;
    unavailable.append("total heap allocations");
    unavailable.append("per-worker utilization");
    unavailable.append("pending queue occupancy/high-water");
    unavailable.append("per-cell sleeping status");
    out["unavailable"] = unavailable;
    return out;
}

} // namespace godot::cyber_observation
