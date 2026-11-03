#pragma once

// Test/benchmark-only literal oracle. The cell loop is current-main
// 25ce0731 World::copy_render_cells; the refusal preflight is corrected #290
// 60915dc8. No ordinary runtime includes this file or selects this path.
#include "cybersand/material_appearance.hpp"
#include "cybersand/world.hpp"

#include <cstddef>
#include <cstdint>
#include <limits>
#include <span>
#include <stdexcept>

namespace render_copy_reference {

inline void copy(const cybersand::World& world, cybersand::RectI64 region,
                 std::span<std::uint8_t> destination, std::size_t stride_bytes) {
    if (region.width < 0 || region.height < 0)
        throw std::invalid_argument("reference region dimensions must not be negative");
    const auto width = static_cast<std::uint64_t>(region.width);
    const auto height = static_cast<std::uint64_t>(region.height);
    constexpr auto addressable = std::numeric_limits<std::size_t>::max();
    if (width > addressable / 2U)
        throw std::overflow_error("reference row byte count exceeds addressable size");
    const auto row_bytes = static_cast<std::size_t>(width) * 2U;
    if (stride_bytes < row_bytes)
        throw std::invalid_argument("reference destination stride is too small");
    std::size_t required = 0;
    if (height != 0U) {
        if (stride_bytes != 0U && height - 1U > (addressable - row_bytes) / stride_bytes)
            throw std::overflow_error("reference destination byte count exceeds addressable size");
        required = static_cast<std::size_t>(height - 1U) * stride_bytes + row_bytes;
    }
    if (destination.size() < required)
        throw std::invalid_argument("reference destination buffer is too small");
    if (region.width == 0 || region.height == 0) return;
    constexpr auto highest = std::numeric_limits<std::int64_t>::max();
    if (region.x > highest - (region.width - 1) ||
        region.y > highest - (region.height - 1))
        throw std::overflow_error("reference render region exceeds signed coordinate range");

    for (std::int64_t row = 0; row < region.height; ++row) {
        auto* output = destination.data() + static_cast<std::size_t>(row) * stride_bytes;
        for (std::int64_t column = 0; column < region.width; ++column) {
            const auto world_x = region.x + column;
            const auto world_y = region.y + row;
            const auto offset = static_cast<std::size_t>(column) * 2U;
            const auto material = world.stored_material(world_x, world_y);
            output[offset] = static_cast<std::uint8_t>(material);
            output[offset + 1U] = cybersand::project_visual_state(
                material, world.stored_state_a(world_x, world_y),
                world.stored_state_b(world_x, world_y), world.config().water_experiment_policy);
        }
    }
}

// Derived source-level operation counts, not observed/hardware counters.
// This helper is used only with the bounded, valid benchmark rectangles.
inline std::uint64_t row_runs(cybersand::RectI64 region, std::int32_t chunk_size) {
    if (region.width == 0 || region.height == 0) return 0;
    const auto remainder = region.x % chunk_size;
    const auto local_x = static_cast<std::uint64_t>(
        remainder < 0 ? remainder + chunk_size : remainder);
    const auto runs = 1U + (static_cast<std::uint64_t>(region.width) - 1U + local_x) /
        static_cast<std::uint64_t>(chunk_size);
    return runs * static_cast<std::uint64_t>(region.height);
}

}  // namespace render_copy_reference
