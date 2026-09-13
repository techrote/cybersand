#pragma once

#include <cstdint>

namespace cybersand {

// Version 1: occupancy is a local gameplay support approximation, not density
// or a rigid-body bearing model. Construction-only; no live policy mutation.
struct InteractionPolicy {
    static constexpr std::uint32_t version = 1;
    std::uint8_t downward_support_cells = 8; // ceil(0.8 * 9)
    std::uint8_t side_support_cells = 9;     // ceil(0.95 * 9)
    std::uint32_t mercury_exchange_period = 30; // completed simulation opportunities, 60 Hz
};

} // namespace cybersand
