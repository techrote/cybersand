#pragma once

#include "cybersand/render_snapshot.hpp"

#include <mutex>
#include <optional>
#include <vector>

namespace cybersand::detail {

struct RenderSnapshotSlot {
    RenderSnapshotSlot(std::size_t patch_capacity, std::size_t byte_capacity)
        : patches(patch_capacity), cells(byte_capacity) {}

    std::vector<RenderSnapshotPatch> patches;
    std::vector<std::uint8_t> cells;
    std::size_t patch_count = 0;
    std::size_t byte_count = 0;
    std::uint64_t tick = 0;
    std::uint64_t serial = 0;
    std::size_t lease_count = 0;
};

struct RenderSnapshotState {
    RenderSnapshotState(std::size_t slot_count, std::size_t patch_capacity,
                        std::size_t byte_capacity)
        : patch_capacity_per_slot(patch_capacity),
          byte_capacity_per_slot(byte_capacity) {
        slots.reserve(slot_count);
        for (std::size_t index = 0; index < slot_count; ++index) {
            slots.emplace_back(patch_capacity, byte_capacity);
        }
        dirty_coordinate_scratch.reserve(patch_capacity);
    }

    const std::size_t patch_capacity_per_slot;
    const std::size_t byte_capacity_per_slot;
    mutable std::mutex mutex;
    std::vector<RenderSnapshotSlot> slots;
    std::vector<ChunkCoord> dirty_coordinate_scratch;
    std::optional<std::size_t> latest_slot;
    std::uint64_t next_serial = 0;
    std::size_t patch_high_water = 0;
    std::size_t byte_high_water = 0;
    std::uint64_t backpressure_count = 0;
    std::uint64_t capacity_failure_count = 0;
};

}  // namespace cybersand::detail
