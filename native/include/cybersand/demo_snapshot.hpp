#pragma once

#include "cybersand/world.hpp"
#include <memory>
#include <span>
#include <stdexcept>
#include <vector>

namespace cybersand::demo {

// CYSD1 world payload: row-major material, state_a, state_b, temperature LE16.
// Tick epoch, scheduler queues, render leases and transient obstacles are not
// checkpoint data. Call only at a tick boundary with exclusive World ownership.
inline constexpr std::int32_t kWidth = 1024;
inline constexpr std::int32_t kHeight = 1024;
inline constexpr std::size_t kCellBytes = 5;
inline constexpr std::size_t kPayloadBytes = std::size_t{kWidth} * kHeight * kCellBytes;
inline constexpr std::size_t kMaximumRectangles = 4096;

[[nodiscard]] inline bool valid_material(std::int32_t id) noexcept {
    return id >= 0 && id <= 80 && id != 10;
}

inline void validate(std::span<const std::uint8_t> bytes) {
    if (bytes.size() != kPayloadBytes) throw std::invalid_argument("Wrong world payload length");
    for (std::size_t i = 0; i < bytes.size(); i += kCellBytes) {
        if (!valid_material(bytes[i])) throw std::invalid_argument("Invalid material ID");
    }
}

inline void copy_level(World& world, std::span<std::uint8_t> bytes) {
    if (bytes.size() != kPayloadBytes) throw std::invalid_argument("Wrong snapshot buffer length");
    // temperature() normally samples the occupancy mask. Remove only this
    // transient projection so saved temperatures describe stored cells. The
    // adapter must rebuild the obstacle mask before its next cellular tick.
    world.clear_transient_obstacles();
    std::size_t offset = 0;
    for (std::int32_t y = 0; y < kHeight; ++y) {
        for (std::int32_t x = 0; x < kWidth; ++x) {
            bytes[offset++] = static_cast<std::uint8_t>(world.stored_material(x, y));
            bytes[offset++] = world.stored_state_a(x, y);
            bytes[offset++] = world.stored_state_b(x, y);
            const auto temperature = static_cast<std::uint16_t>(world.temperature(x, y));
            bytes[offset++] = static_cast<std::uint8_t>(temperature & 255U);
            bytes[offset++] = static_cast<std::uint8_t>(temperature >> 8U);
        }
    }
}

[[nodiscard]] inline std::unique_ptr<World> empty_level(const WorldConfig& config) {
    auto candidate = std::make_unique<World>(config);
    candidate->reserve_region({0, 0, kWidth, kHeight});
    candidate->configure_transient_obstacles({0, 0, kWidth, kHeight});
    return candidate;
}

[[nodiscard]] inline std::unique_ptr<World> reconstruct(
    const WorldConfig& config, std::span<const std::uint8_t> bytes) {
    validate(bytes);  // Validate everything before allocating or changing a world.
    auto candidate = empty_level(config);
    std::size_t offset = 0;
    for (std::int32_t y = 0; y < kHeight; ++y) {
        for (std::int32_t x = 0; x < kWidth; ++x) {
            const auto material = static_cast<Material>(bytes[offset]);
            (void)candidate->set_cell_state(x, y, material, bytes[offset + 1], bytes[offset + 2]);
            const auto encoded = static_cast<std::uint16_t>(
                bytes[offset + 3] | (std::uint16_t{bytes[offset + 4]} << 8U));
            const auto temperature = static_cast<std::int16_t>(
                encoded <= 32767U ? static_cast<std::int32_t>(encoded)
                                  : static_cast<std::int32_t>(encoded) - 65536);
            if (temperature != config.ambient_temperature) candidate->set_temperature(x, y, temperature);
            offset += kCellBytes;
        }
    }
    return candidate;
}

// Ordered rectangles are a compact constructor command list, not a second
// simulation. Each record is x, y, width, height, material ID. Empty carves.
[[nodiscard]] inline std::unique_ptr<World> construct(
    const WorldConfig& config, std::span<const std::int32_t> rectangles) {
    if (rectangles.empty() || rectangles.size() % 5 != 0 ||
        rectangles.size() / 5 > kMaximumRectangles) {
        throw std::invalid_argument("Invalid demo rectangle count");
    }
    std::uint64_t total_area = 0;
    for (std::size_t i = 0; i < rectangles.size(); i += 5) {
        const auto x = rectangles[i], y = rectangles[i + 1];
        const auto w = rectangles[i + 2], h = rectangles[i + 3];
        if (x < 0 || y < 0 || w <= 0 || h <= 0 || w > kWidth || h > kHeight ||
            x > kWidth - w || y > kHeight - h || !valid_material(rectangles[i + 4])) {
            throw std::invalid_argument("Invalid demo rectangle");
        }
        total_area += static_cast<std::uint64_t>(w) * static_cast<std::uint64_t>(h);
        if (total_area > 8U * kWidth * kHeight) throw std::invalid_argument("Demo construction budget exceeded");
    }
    auto candidate = empty_level(config);
    for (std::size_t i = 0; i < rectangles.size(); i += 5) {
        for (auto y = rectangles[i + 1]; y < rectangles[i + 1] + rectangles[i + 3]; ++y) {
            for (auto x = rectangles[i]; x < rectangles[i] + rectangles[i + 2]; ++x) {
                candidate->set(x, y, static_cast<Material>(rectangles[i + 4]));
            }
        }
    }
    return candidate;
}

}  // namespace cybersand::demo
