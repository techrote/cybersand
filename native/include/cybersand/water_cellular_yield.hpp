#pragma once

#include <cstdint>

namespace cybersand {

// LCB-001 opt-in whole-cell Water motion. Material block v1 remains the
// illustrative Gate-C flow_rate_permille schema; v2 is the actual native law.
struct WaterCellularYieldParameters {
    static constexpr std::uint16_t kVersion = 1;
    static constexpr std::uint16_t kMaterialBlockVersion = 2;
    static constexpr std::uint8_t kDefaultViscosity = 0;
    std::uint8_t viscosity_index = kDefaultViscosity;
};

} // namespace cybersand
