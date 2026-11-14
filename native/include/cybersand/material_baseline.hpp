#pragma once

#include "cybersand/world.hpp"

#include <cstddef>
#include <cstdint>
#include <span>
#include <stdexcept>

namespace cybersand::material_baseline {

// Finite Workbench authored material layout, not a physical-state checkpoint.
// The portable payload is exactly two little-endian bytes for each row-major
// stored ID. Material's current catalogue remains unchanged (including holes).
inline constexpr std::int32_t kSchema = 1;
inline constexpr std::int32_t kMinimumSide = 512;
inline constexpr std::int32_t kMaximumSide = 2048;
inline constexpr std::size_t kCellBytes = 2;
inline constexpr std::size_t kMaximumBytes = std::size_t{kMaximumSide} * kMaximumSide * kCellBytes;

[[nodiscard]] inline std::size_t byte_count(std::int32_t width, std::int32_t height,
                                           std::size_t maximum_bytes = kMaximumBytes) {
    if (width < kMinimumSide || height < kMinimumSide || width > kMaximumSide ||
        height > kMaximumSide || width % 64 != 0 || height % 64 != 0)
        throw std::invalid_argument("Material baseline extent must be a multiple of 64 in 512..2048");
    const auto bytes = static_cast<std::size_t>(width) * static_cast<std::size_t>(height) * kCellBytes;
    if (bytes > maximum_bytes)
        throw std::length_error("Material baseline staging capacity exceeded");
    return bytes;
}

// Call after complete length validation; index is a cell offset, not a byte.
[[nodiscard]] inline std::uint16_t decode(std::span<const std::uint8_t> bytes, std::size_t index) noexcept {
    const auto offset = index * kCellBytes;
    return static_cast<std::uint16_t>(bytes[offset] | (std::uint16_t{bytes[offset + 1]} << 8U));
}

inline void validate(std::span<const std::uint8_t> bytes, std::int32_t width, std::int32_t height) {
    if (bytes.size() != byte_count(width, height))
        throw std::invalid_argument("Material baseline payload length differs from complete LE16 plane");
    for (std::size_t index = 0; index < bytes.size() / kCellBytes; ++index)
        if (!valid_material(decode(bytes, index)))
            throw std::invalid_argument("Material baseline contains an unsupported stored material ID");
}

// Exclusive external owner only, between ticks. No synchronization is added:
// the caller must already own World access. The checks reject invalid owner
// states; they are not a lock or a safe concurrent tick probe. Destination is
// caller-owned staging, never a borrowed pointer into native cell storage.
// Publication occurs only after this complete copy succeeds.
inline void copy(const World& world, std::span<std::uint8_t> destination,
                 std::int32_t width, std::int32_t height) {
    if (destination.size() != byte_count(width, height))
        throw std::invalid_argument("Material baseline capture buffer must cover the complete LE16 plane");
    if (world.has_failed())
        throw std::logic_error("Cannot capture a failed native World");
    if (world.is_tick_in_progress() || world.tick_index() != world.completed_tick_index())
        throw std::logic_error("Material baseline capture requires a completed native tick boundary");
    std::size_t offset = 0;
    for (std::int32_t y = 0; y < height; ++y) {
        for (std::int32_t x = 0; x < width; ++x) {
            const auto id = static_cast<std::uint16_t>(world.stored_material(x, y));
            if (!valid_material(id))
                throw std::logic_error("Native stored material is unsupported by the current catalogue");
            destination[offset++] = static_cast<std::uint8_t>(id & 255U);
            destination[offset++] = static_cast<std::uint8_t>(id >> 8U);
        }
    }
}

} // namespace cybersand::material_baseline
