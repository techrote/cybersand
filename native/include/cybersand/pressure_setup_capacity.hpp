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
    std::size_t capacity = PressureFlowParameters::kCompartmentCapacity;
    bool exceeds_capacity() const noexcept {
        return compartments > capacity;
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
                                                         const setup::SetupDomain& domain,
                                                         std::uint32_t maximum_side = 1024U,
                                                         bool retained_workbench = false) {
    InitialPressureCapacity result;
    if (!world.pressure_flow_enabled() || !world.pressure_flow_parameters().gas_enabled) return result;
    result.applicable = true;
    result.capacity = world.config().pressure_gas_compartment_capacity;
    if (world.tick_index() != 0U || (!retained_workbench && (world.gas_topology_revision() != 0U || world.gas_next_id() != 1U)))
        throw std::invalid_argument("initial pressure capacity requires a fresh prepared World");
    if (maximum_side > setup::kMaximumFiniteSetupSide || domain.width == 0U || domain.height == 0U || domain.width > maximum_side ||
        domain.height > maximum_side ||
        domain.x > std::numeric_limits<std::int64_t>::max() - (domain.width - 1U) ||
        domain.y > std::numeric_limits<std::int64_t>::max() - (domain.height - 1U))
        throw std::invalid_argument("invalid initial pressure capacity domain");

    auto scan=domain;
    if (retained_workbench) {
        if (domain.x || domain.y) throw std::invalid_argument("invalid retained workbench pressure origin");
        // PreparedWorldBuilder reserves a chunk (or larger rule radius) around
        // the authored grid. The workbench native adapter uses 128-cell chunks
        // and radius 2/3. Include the entire resident exterior rectangle.
        const auto chunk=static_cast<std::uint32_t>(world.config().chunk_size);
        const auto radius=static_cast<std::uint32_t>(world.config().maximum_rule_radius);
        const auto halo=std::max(chunk,radius);
        const auto left=((halo+chunk-1)/chunk)*chunk;
        scan.x=scan.y=-static_cast<std::int64_t>(left);
        const auto side=[&](std::uint32_t length) {return left+((length+halo+chunk-1)/chunk)*chunk;};
        scan.width=side(domain.width); scan.height=side(domain.height);
    }
    // No gas identity has ever been allocated in this candidate. Skip
    // millions of sidecar lookups in the common vented/empty workbench.
    const bool inspect_labels=retained_workbench && world.gas_next_id()!=1U;
    if (retained_workbench && !inspect_labels && world.quantity_ledger().water_visible==0U)
        return result;
    const auto width = scan.width;
    const auto count = static_cast<std::size_t>(width) * scan.height;
    // Each vector is bounded by the admitted finite domain and allocated only during preparation.
    // 0 blocked, 1 unseen Empty, 2 unmasked Water, 3 visited Empty, 4 inherited gas label.
    std::vector<std::uint8_t> cells(count, 0U);
    std::vector<std::uint32_t> queue;
    queue.reserve(count);
    for (std::uint32_t y = 0; y < scan.height; ++y)
        for (std::uint32_t x = 0; x < width; ++x) {
            const auto wx = scan.x + x, wy = scan.y + y;
            if (world.transient_obstacle_at(wx, wy) != 0U) continue;
            const auto material = world.get(wx, wy);
            auto& cell=cells[static_cast<std::size_t>(y) * width + x];
            cell=material==Material::Empty ? 1U : material==Material::Water ? 2U : 0U;
            if (cell==1U && inspect_labels) {
                const auto label=world.pressure_cell(wx,wy).gas;
                if (label && label!=kVacuumLabel && label!=kAtmosphereLabel) cell=4U;
            }
        }

    for (std::uint32_t seed = 0; seed < count; ++seed) {
        if (cells[seed] != 1U && cells[seed] != 4U) continue;
        bool seeded=cells[seed]==4U;
        queue.clear();
        queue.push_back(seed);
        cells[seed] = 3U;
        bool boundary = false;
        const auto visit = [&](std::uint32_t index) {
            if (cells[index] == 2U) seeded = true;
            else if (cells[index] == 1U || cells[index] == 4U) {
                seeded = seeded || cells[index] == 4U;
                cells[index] = 3U;
                queue.push_back(index);
            }
        };
        for (std::size_t head = 0; head < queue.size(); ++head) {
            const auto index = queue[head], x = index % width, y = index / width;
            boundary = boundary || x == 0U || y == 0U || x + 1U == width || y + 1U == scan.height;
            if (x != 0U) visit(index - 1U);
            if (x + 1U < width) visit(index + 1U);
            if (y != 0U) visit(index - width);
            if (y + 1U < scan.height) visit(index + width);
        }
        if (seeded && !boundary && queue.size() <= PressureFlowParameters::kCompartmentVolumeLimit) {
            if (++result.compartments > result.capacity) return result;
        }
    }
    return result;
}
} // namespace cybersand
