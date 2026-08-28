#include "cybersand/scheduler_geometry.hpp"

#include <stdexcept>

namespace cybersand {
namespace {

[[nodiscard]] constexpr std::int64_t floor_div(std::int64_t value, std::int64_t divisor) noexcept {
    const auto quotient = value / divisor;
    const auto remainder = value % divisor;
    return remainder < 0 ? quotient - 1 : quotient;
}

[[nodiscard]] constexpr std::uint8_t parity(std::int64_t value) noexcept {
    const auto remainder = value % 2;
    return static_cast<std::uint8_t>(remainder < 0 ? remainder + 2 : remainder);
}

}  // namespace

SchedulerGeometry::SchedulerGeometry(std::int32_t core_size, std::int32_t write_radius)
    : core_size_(core_size), write_radius_(write_radius) {
    if (core_size_ < 2 || (core_size_ & 1) != 0) {
        throw std::invalid_argument("scheduler core_size must be a positive even value");
    }
    if (write_radius_ < 0 || write_radius_ > core_size_ / 2) {
        throw std::invalid_argument("scheduler write_radius must be between zero and half core_size");
    }
}

std::int32_t SchedulerGeometry::core_size() const noexcept { return core_size_; }
std::int32_t SchedulerGeometry::write_radius() const noexcept { return write_radius_; }

SchedulingCoreCoord SchedulerGeometry::core_for_cell(std::int64_t x, std::int64_t y) const noexcept {
    return {floor_div(x, core_size_), floor_div(y, core_size_)};
}

std::uint8_t SchedulerGeometry::phase(SchedulingCoreCoord core) const noexcept {
    return static_cast<std::uint8_t>(parity(core.x) | static_cast<std::uint8_t>(parity(core.y) << 1U));
}

CellRect SchedulerGeometry::core_rect(SchedulingCoreCoord core) const noexcept {
    return {core.x * core_size_, core.y * core_size_, core_size_, core_size_};
}

CellRect SchedulerGeometry::write_domain(SchedulingCoreCoord core) const noexcept {
    const auto base = core_rect(core);
    return {
        base.x - write_radius_,
        base.y - write_radius_,
        base.width + static_cast<std::int64_t>(write_radius_) * 2,
        base.height + static_cast<std::int64_t>(write_radius_) * 2,
    };
}

bool SchedulerGeometry::overlaps(CellRect left, CellRect right) noexcept {
    if (left.width <= 0 || left.height <= 0 || right.width <= 0 || right.height <= 0) return false;
    return left.x < right.x + right.width && right.x < left.x + left.width &&
           left.y < right.y + right.height && right.y < left.y + left.height;
}

bool SchedulerGeometry::same_phase_domains_overlap(SchedulingCoreCoord left,
                                                   SchedulingCoreCoord right) const noexcept {
    if (phase(left) != phase(right)) return false;
    return overlaps(write_domain(left), write_domain(right));
}

bool SchedulerGeometry::validate_non_overlapping_phase(
    std::span<const SchedulingCoreCoord> cores, std::uint8_t phase_index) const noexcept {
    if (phase_index >= kPhaseCount) return false;
    for (std::size_t left_index = 0; left_index < cores.size(); ++left_index) {
        if (phase(cores[left_index]) != phase_index) continue;
        for (std::size_t right_index = left_index + 1; right_index < cores.size(); ++right_index) {
            if (phase(cores[right_index]) != phase_index) continue;
            if (overlaps(write_domain(cores[left_index]), write_domain(cores[right_index]))) return false;
        }
    }
    return true;
}

}  // namespace cybersand
