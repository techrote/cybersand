#pragma once

#include "cybersand/prepared_setup_identity.hpp"
#include "cybersand/world.hpp"

#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <vector>

namespace cybersand {

struct InitialPressureCapacity final {
    bool applicable = false;
    std::size_t compartments = 0;
    bool exceeds_capacity() const noexcept {
        return compartments > PressureFlowParameters::kCompartmentCapacity;
    }
};

// Construction only, after initial masks are rasterized. The domain must cover
// the complete finite prepared payload and its masks; outside it is unbounded
// Empty. This is an initial-capacity check, not a future topology guarantee.
// Fresh gas discovery seeds only Empty regions beside unmasked Water. It never
// creates compartments for unrelated sealed holes. A region reaching the domain
// boundary vents through the unbounded exterior; a larger-than-v1-limit region
// is atmosphere even when enclosed. No World state, labels or ledgers change.
inline InitialPressureCapacity initial_pressure_capacity(const World& world,
                                                         const setup::SetupDomain& domain) {
    InitialPressureCapacity result;
    if (!world.pressure_flow_enabled() || !world.pressure_flow_parameters().gas_enabled) return result;
    result.applicable = true;
    if (world.tick_index() != 0U || world.gas_topology_revision() != 0U || world.gas_next_id() != 1U)
        throw std::invalid_argument("initial pressure capacity requires a fresh prepared World");
    constexpr std::uint32_t maximum_side = 1024U;
    if (domain.width == 0U || domain.height == 0U || domain.width > maximum_side ||
        domain.height > maximum_side ||
        domain.x > std::numeric_limits<std::int64_t>::max() - (domain.width - 1U) ||
        domain.y > std::numeric_limits<std::int64_t>::max() - (domain.height - 1U))
        throw std::invalid_argument("invalid initial pressure capacity domain");

    const auto width = domain.width;
    const auto count = static_cast<std::size_t>(width) * domain.height;
    // Each vector has at most 1024^2 entries, allocated only during preparation.
    // 0 blocked, 1 unseen Empty, 2 unmasked Water, 3 visited Empty.
    std::vector<std::uint8_t> cells(count, 0U);
    std::vector<std::uint32_t> queue;
    queue.reserve(count);
    for (std::uint32_t y = 0; y < domain.height; ++y)
        for (std::uint32_t x = 0; x < width; ++x) {
            const auto wx = domain.x + x, wy = domain.y + y;
            if (world.transient_obstacle_at(wx, wy) != 0U) continue;
            const auto material = world.get(wx, wy);
            cells[static_cast<std::size_t>(y) * width + x] =
                material == Material::Empty ? 1U : material == Material::Water ? 2U : 0U;
        }

    for (std::uint32_t seed = 0; seed < count; ++seed) {
        if (cells[seed] != 1U) continue;
        queue.clear();
        queue.push_back(seed);
        cells[seed] = 3U;
        bool boundary = false, touches_water = false;
        const auto visit = [&](std::uint32_t index) {
            if (cells[index] == 2U) touches_water = true;
            else if (cells[index] == 1U) {
                cells[index] = 3U;
                queue.push_back(index);
            }
        };
        for (std::size_t head = 0; head < queue.size(); ++head) {
            const auto index = queue[head], x = index % width, y = index / width;
            boundary = boundary || x == 0U || y == 0U || x + 1U == width || y + 1U == domain.height;
            if (x != 0U) visit(index - 1U);
            if (x + 1U < width) visit(index + 1U);
            if (y != 0U) visit(index - width);
            if (y + 1U < domain.height) visit(index + width);
        }
        if (touches_water && !boundary && queue.size() <= PressureFlowParameters::kCompartmentVolumeLimit) {
            if (++result.compartments > PressureFlowParameters::kCompartmentCapacity) return result;
        }
    }
    return result;
}
} // namespace cybersand
