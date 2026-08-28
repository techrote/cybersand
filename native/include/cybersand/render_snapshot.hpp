#pragma once

#include "cybersand/world.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>

namespace cybersand {

namespace detail {
struct RenderSnapshotState;
}

enum class RenderPublishStatus : std::uint8_t {
    NoChanges = 0,
    Published = 1,
    Backpressure = 2,
    CapacityExceeded = 3,
};

struct RenderSnapshotPatch {
    RectI64 world_rect;
    std::size_t data_offset = 0;
    std::size_t stride_bytes = 0;
};

struct RenderPublishResult {
    RenderPublishStatus status = RenderPublishStatus::NoChanges;
    std::uint64_t snapshot_serial = 0;
    std::size_t required_patches = 0;
    std::size_t required_bytes = 0;
};

class RenderSnapshotExchange;

class RenderSnapshotLease {
public:
    RenderSnapshotLease() = default;
    ~RenderSnapshotLease();

    RenderSnapshotLease(const RenderSnapshotLease&) = delete;
    RenderSnapshotLease& operator=(const RenderSnapshotLease&) = delete;
    RenderSnapshotLease(RenderSnapshotLease&& other) noexcept;
    RenderSnapshotLease& operator=(RenderSnapshotLease&& other) noexcept;

    [[nodiscard]] explicit operator bool() const noexcept;
    [[nodiscard]] std::uint64_t serial() const noexcept;
    [[nodiscard]] std::uint64_t tick() const noexcept;
    [[nodiscard]] std::span<const RenderSnapshotPatch> patches() const noexcept;
    [[nodiscard]] std::span<const std::uint8_t> cells() const noexcept;
    void reset() noexcept;

private:
    friend class RenderSnapshotExchange;
    RenderSnapshotLease(std::shared_ptr<detail::RenderSnapshotState> state,
                        std::size_t slot_index,
                        std::uint64_t serial) noexcept;

    std::shared_ptr<detail::RenderSnapshotState> state_;
    std::size_t slot_index_ = 0;
    std::uint64_t serial_ = 0;
};

// Single-producer, multi-consumer publication exchange. The producer must call
// publish() only at a World tick boundary and must serialize it with all World
// mutation. Consumers may acquire and read immutable leases concurrently.
class RenderSnapshotExchange {
public:
    RenderSnapshotExchange(std::size_t slot_count, std::size_t patch_capacity_per_slot,
                           std::size_t byte_capacity_per_slot);
    ~RenderSnapshotExchange() = default;

    RenderSnapshotExchange(const RenderSnapshotExchange&) = delete;
    RenderSnapshotExchange& operator=(const RenderSnapshotExchange&) = delete;
    RenderSnapshotExchange(RenderSnapshotExchange&&) = delete;
    RenderSnapshotExchange& operator=(RenderSnapshotExchange&&) = delete;

    [[nodiscard]] RenderPublishResult publish(World& world);
    [[nodiscard]] std::optional<RenderSnapshotLease> acquire_latest(
        std::uint64_t after_serial = 0);

    [[nodiscard]] std::size_t slot_count() const noexcept;
    [[nodiscard]] std::size_t patch_capacity_per_slot() const noexcept;
    [[nodiscard]] std::size_t byte_capacity_per_slot() const noexcept;
    [[nodiscard]] std::uint64_t latest_serial() const noexcept;
    [[nodiscard]] std::size_t patch_high_water() const noexcept;
    [[nodiscard]] std::size_t byte_high_water() const noexcept;
    [[nodiscard]] std::uint64_t backpressure_count() const noexcept;
    [[nodiscard]] std::uint64_t capacity_failure_count() const noexcept;

private:
    std::shared_ptr<detail::RenderSnapshotState> state_;
};

}  // namespace cybersand
