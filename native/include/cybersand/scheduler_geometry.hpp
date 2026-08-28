#pragma once

#include <compare>
#include <cstdint>
#include <span>

namespace cybersand {

struct SchedulingCoreCoord {
    std::int64_t x = 0;
    std::int64_t y = 0;

    [[nodiscard]] friend constexpr bool operator==(const SchedulingCoreCoord&,
                                                   const SchedulingCoreCoord&) = default;
    [[nodiscard]] friend constexpr auto operator<=>(const SchedulingCoreCoord&,
                                                    const SchedulingCoreCoord&) = default;
};

struct CellRect {
    std::int64_t x = 0;
    std::int64_t y = 0;
    std::int64_t width = 0;
    std::int64_t height = 0;
};

// Geometry-only model for the Noita-style four-colour scheduler.
//
// A core belongs to one phase according to the parity of its global core
// coordinates. Cores in the same phase are separated by at least one whole
// core in both relevant directions. Expanding each core's write domain by at
// most half a core therefore cannot create same-phase overlap (half-open
// rectangles may touch, but never share a cell).
class SchedulerGeometry final {
public:
    static constexpr std::uint8_t kPhaseCount = 4;

    explicit SchedulerGeometry(std::int32_t core_size = 64, std::int32_t write_radius = 1);

    [[nodiscard]] std::int32_t core_size() const noexcept;
    [[nodiscard]] std::int32_t write_radius() const noexcept;
    [[nodiscard]] SchedulingCoreCoord core_for_cell(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint8_t phase(SchedulingCoreCoord core) const noexcept;
    [[nodiscard]] CellRect core_rect(SchedulingCoreCoord core) const noexcept;
    [[nodiscard]] CellRect write_domain(SchedulingCoreCoord core) const noexcept;

    [[nodiscard]] static bool overlaps(CellRect left, CellRect right) noexcept;
    [[nodiscard]] bool same_phase_domains_overlap(SchedulingCoreCoord left,
                                                  SchedulingCoreCoord right) const noexcept;
    [[nodiscard]] bool validate_non_overlapping_phase(
        std::span<const SchedulingCoreCoord> cores, std::uint8_t phase_index) const noexcept;

private:
    std::int32_t core_size_;
    std::int32_t write_radius_;
};

}  // namespace cybersand
