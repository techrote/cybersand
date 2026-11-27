#pragma once

// SCRIPT-HOTPATH-001: pure, value-only connected-component planner.
// No Godot API, World access, threads, rendering, or mutable live state.
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace cybersand::paint_fill {

constexpr std::int64_t kMaxSampleCells = 262144;
constexpr std::int32_t kMaxExtent = 2048;
constexpr std::int32_t kMaxMaterialId = 131;

enum class Outcome {
    accepted,
    invalid_limit,
    invalid_extent,
    empty_sample,
    outside_source,
    oversized_sample,
    size_mismatch,
    seed_outside,
    invalid_material,
    budget_exceeded,
    unread_edge
};

struct Plan {
    Outcome outcome = Outcome::invalid_limit;
    std::vector<std::int32_t> indices; // Sample-local row-major indices, sorted on acceptance.
    std::int32_t source_material = 0;
    const char* first_unread_edge = "";
    std::int32_t min_x = 0, min_y = 0, max_x = 0, max_y = 0;
};

inline const char* error(Outcome outcome) {
    switch (outcome) {
        case Outcome::invalid_limit: return "Operation cell budget must be between 1 and 262144.";
        case Outcome::invalid_extent: return "Canvas extent is not an admitted 512–2048 multiple of 64.";
        case Outcome::empty_sample: return "Connected fill requires a nonempty native source sample.";
        case Outcome::outside_source: return "Connected fill source sample lies outside the native canvas.";
        case Outcome::oversized_sample: return "Connected fill source sample exceeds 262144 material cells.";
        case Outcome::size_mismatch: return "Connected fill requires exactly one authoritative material ID per sampled cell.";
        case Outcome::seed_outside: return "Connected fill seed lies outside the captured source sample.";
        case Outcome::invalid_material: return "Connected fill source contains an unknown or reserved native material ID.";
        case Outcome::budget_exceeded: return "Connected fill exceeds the operation cell budget; no partial fill.";
        case Outcome::unread_edge: return "Connected fill reaches an unread capture edge.";
        case Outcome::accepted: return "";
    }
    return "Unknown connected fill planner result.";
}

inline Plan plan(
    std::int32_t seed_x, std::int32_t seed_y,
    std::int32_t origin_x, std::int32_t origin_y,
    std::int32_t sample_w, std::int32_t sample_h,
    const std::int32_t* materials, std::size_t material_count,
    std::int32_t extent_w, std::int32_t extent_h,
    std::int64_t cell_limit) {
    Plan result;
    auto refuse = [&result](Outcome outcome) {
        result.outcome = outcome;
        result.indices.clear();
        return result;
    };
    if (cell_limit < 1 || cell_limit > kMaxSampleCells)
        return refuse(Outcome::invalid_limit);
    if (extent_w < 512 || extent_h < 512 || extent_w > kMaxExtent ||
        extent_h > kMaxExtent || extent_w % 64 != 0 || extent_h % 64 != 0)
        return refuse(Outcome::invalid_extent);
    if (sample_w <= 0 || sample_h <= 0)
        return refuse(Outcome::empty_sample);
    if (origin_x < 0 || origin_y < 0 || origin_x >= extent_w || origin_y >= extent_h ||
        static_cast<std::int64_t>(origin_x) + sample_w > extent_w ||
        static_cast<std::int64_t>(origin_y) + sample_h > extent_h)
        return refuse(Outcome::outside_source);
    const auto area = static_cast<std::int64_t>(sample_w) * sample_h;
    if (area > kMaxSampleCells)
        return refuse(Outcome::oversized_sample);
    if (material_count != static_cast<std::size_t>(area) || materials == nullptr)
        return refuse(Outcome::size_mismatch);
    if (seed_x < origin_x || seed_y < origin_y ||
        static_cast<std::int64_t>(seed_x) >= static_cast<std::int64_t>(origin_x) + sample_w ||
        static_cast<std::int64_t>(seed_y) >= static_cast<std::int64_t>(origin_y) + sample_h)
        return refuse(Outcome::seed_outside);
    // Match the script's all-sample validation before exploring the seed component.
    for (std::size_t i = 0; i < material_count; ++i)
        if (materials[i] < 0 || materials[i] > kMaxMaterialId || materials[i] == 10)
            return refuse(Outcome::invalid_material);

    const std::int32_t local_x = seed_x - origin_x;
    const std::int32_t local_y = seed_y - origin_y;
    const auto seed_index = local_y * sample_w + local_x;
    result.source_material = materials[seed_index];
    result.min_x = result.max_x = seed_x;
    result.min_y = result.max_y = seed_y;
    std::vector<std::uint8_t> visited(static_cast<std::size_t>(area), 0);
    visited[static_cast<std::size_t>(seed_index)] = 1;
    result.indices.reserve(std::min(static_cast<std::size_t>(cell_limit), material_count));
    result.indices.push_back(seed_index);

    // FIFO queue and result vector are one allocation; no dictionary or recursion.
    for (std::size_t head = 0; head < result.indices.size(); ++head) {
        const std::int32_t index = result.indices[head];
        const std::int32_t x = index % sample_w;
        const std::int32_t y = index / sample_w;
        const std::int32_t wx = origin_x + x;
        const std::int32_t wy = origin_y + y;
        if (result.first_unread_edge[0] == '\0') {
            if (x == 0 && wx > 0) result.first_unread_edge = "left";
            else if (x == sample_w - 1 && wx < extent_w - 1) result.first_unread_edge = "right";
            else if (y == 0 && wy > 0) result.first_unread_edge = "top";
            else if (y == sample_h - 1 && wy < extent_h - 1) result.first_unread_edge = "bottom";
        }
        result.min_x = std::min(result.min_x, wx);
        result.min_y = std::min(result.min_y, wy);
        result.max_x = std::max(result.max_x, wx);
        result.max_y = std::max(result.max_y, wy);
        // Fixed left/right/top/bottom order matches the original planner exactly.
        for (int direction = 0; direction < 4; ++direction) {
            const std::int32_t nx = x + (direction == 0 ? -1 : direction == 1 ? 1 : 0);
            const std::int32_t ny = y + (direction == 2 ? -1 : direction == 3 ? 1 : 0);
            if (nx < 0 || ny < 0 || nx >= sample_w || ny >= sample_h)
                continue;
            const std::size_t next = static_cast<std::size_t>(ny * sample_w + nx);
            if (visited[next] || materials[next] != result.source_material)
                continue;
            if (result.indices.size() >= static_cast<std::size_t>(cell_limit))
                return refuse(Outcome::budget_exceeded);
            visited[next] = 1;
            result.indices.push_back(static_cast<std::int32_t>(next));
        }
    }

    if (result.first_unread_edge[0] != '\0')
        return refuse(Outcome::unread_edge);
    std::sort(result.indices.begin(), result.indices.end());
    result.outcome = Outcome::accepted;
    return result;
}

} // namespace cybersand::paint_fill
