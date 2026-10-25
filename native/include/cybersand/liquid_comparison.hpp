#pragma once

#include <cstdint>
#include <string_view>

namespace cybersand {

// Diagnostic observations, never scheduling or rest-certificate authority.
// Neither projection changes physical_state_hash or its continuation encoding.
enum class LiquidStateProjection : std::uint8_t {
    PressureVariantEquivalenceV1 = 1,
    QuiescentPhysicalContentV1 = 2,
};

[[nodiscard]] constexpr std::string_view liquid_state_projection_domain(
    LiquidStateProjection projection) noexcept {
    switch (projection) {
        case LiquidStateProjection::PressureVariantEquivalenceV1:
            return "lcb.pressure-variant-equivalence.v1";
        case LiquidStateProjection::QuiescentPhysicalContentV1:
            return "lcb.quiescent-physical-content.v1";
    }
    return {};
}

} // namespace cybersand
