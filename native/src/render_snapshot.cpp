#include "cybersand/render_snapshot.hpp"

#include "render_snapshot_internal.hpp"

#include <stdexcept>
#include <utility>

namespace cybersand {

RenderSnapshotLease::RenderSnapshotLease(
    std::shared_ptr<detail::RenderSnapshotState> state, std::size_t slot_index,
    std::uint64_t serial) noexcept
    : state_(std::move(state)), slot_index_(slot_index), serial_(serial) {}

RenderSnapshotLease::~RenderSnapshotLease() { reset(); }

RenderSnapshotLease::RenderSnapshotLease(RenderSnapshotLease&& other) noexcept
    : state_(std::move(other.state_)), slot_index_(other.slot_index_),
      serial_(other.serial_) {
    other.serial_ = 0;
}

RenderSnapshotLease& RenderSnapshotLease::operator=(RenderSnapshotLease&& other) noexcept {
    if (this == &other) return *this;
    reset();
    state_ = std::move(other.state_);
    slot_index_ = other.slot_index_;
    serial_ = other.serial_;
    other.serial_ = 0;
    return *this;
}

RenderSnapshotLease::operator bool() const noexcept { return state_ != nullptr; }

std::uint64_t RenderSnapshotLease::serial() const noexcept { return serial_; }

std::uint64_t RenderSnapshotLease::tick() const noexcept {
    return state_ == nullptr ? 0 : state_->slots[slot_index_].tick;
}

std::span<const RenderSnapshotPatch> RenderSnapshotLease::patches() const noexcept {
    if (state_ == nullptr) return {};
    const auto& slot = state_->slots[slot_index_];
    return {slot.patches.data(), slot.patch_count};
}

std::span<const std::uint8_t> RenderSnapshotLease::cells() const noexcept {
    if (state_ == nullptr) return {};
    const auto& slot = state_->slots[slot_index_];
    return {slot.cells.data(), slot.byte_count};
}

void RenderSnapshotLease::reset() noexcept {
    if (state_ != nullptr) {
        std::scoped_lock lock(state_->mutex);
        if (slot_index_ < state_->slots.size()) {
            auto& slot = state_->slots[slot_index_];
            if (slot.serial == serial_ && slot.lease_count != 0) --slot.lease_count;
        }
    }
    state_.reset();
    serial_ = 0;
}

RenderSnapshotExchange::RenderSnapshotExchange(std::size_t slot_count,
                                               std::size_t patch_capacity_per_slot,
                                               std::size_t byte_capacity_per_slot)
{
    if (slot_count == 0 || patch_capacity_per_slot == 0 || byte_capacity_per_slot == 0) {
        throw std::invalid_argument("render snapshot capacities must be greater than zero");
    }
    state_ = std::make_shared<detail::RenderSnapshotState>(
        slot_count, patch_capacity_per_slot, byte_capacity_per_slot);
}

std::optional<RenderSnapshotLease> RenderSnapshotExchange::acquire_latest(
    std::uint64_t after_serial) {
    std::scoped_lock lock(state_->mutex);
    if (!state_->latest_slot.has_value()) return std::nullopt;
    auto& slot = state_->slots[*state_->latest_slot];
    if (slot.serial <= after_serial) return std::nullopt;
    ++slot.lease_count;
    return RenderSnapshotLease(state_, *state_->latest_slot, slot.serial);
}

std::size_t RenderSnapshotExchange::slot_count() const noexcept { return state_->slots.size(); }
std::size_t RenderSnapshotExchange::patch_capacity_per_slot() const noexcept {
    return state_->patch_capacity_per_slot;
}
std::size_t RenderSnapshotExchange::byte_capacity_per_slot() const noexcept {
    return state_->byte_capacity_per_slot;
}

std::uint64_t RenderSnapshotExchange::latest_serial() const noexcept {
    std::scoped_lock lock(state_->mutex);
    return state_->next_serial;
}

std::size_t RenderSnapshotExchange::patch_high_water() const noexcept {
    std::scoped_lock lock(state_->mutex);
    return state_->patch_high_water;
}

std::size_t RenderSnapshotExchange::byte_high_water() const noexcept {
    std::scoped_lock lock(state_->mutex);
    return state_->byte_high_water;
}

std::uint64_t RenderSnapshotExchange::backpressure_count() const noexcept {
    std::scoped_lock lock(state_->mutex);
    return state_->backpressure_count;
}

std::uint64_t RenderSnapshotExchange::capacity_failure_count() const noexcept {
    std::scoped_lock lock(state_->mutex);
    return state_->capacity_failure_count;
}

}  // namespace cybersand
