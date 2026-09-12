#pragma once

#include <algorithm>
#include <cstdint>
#include <stdexcept>

namespace cybersand {

enum class WaterRestPolicy : std::uint8_t { CurrentNormalizedV1 = 0 };

// Immutable once copied into a World. The uint16 lane is an experiment
// carrier; mass_bits selects semantics, not a production Cell layout.
class WaterExperimentPolicy final {
public:
    static constexpr std::uint8_t kVersion = 1;
    static constexpr std::uint8_t kMaximumCoherenceTicks = 12;

    constexpr explicit WaterExperimentPolicy(
        std::uint8_t mass_bits = 8,
        std::uint8_t coherence_ticks = kMaximumCoherenceTicks,
        WaterRestPolicy rest_policy = WaterRestPolicy::CurrentNormalizedV1)
        : mass_bits_(mass_bits), coherence_ticks_(coherence_ticks),
          rest_policy_(rest_policy), maximum_(derive_maximum(mass_bits)),
          film_(quantize_ratio(48U, 255U, maximum_)),
          tolerance_(quantize_ratio(1U, 255U, maximum_)) {
        validate();
    }

    constexpr void validate() const {
        if (mass_bits_ < 3U || mass_bits_ > 8U)
            throw std::invalid_argument("Water mass_bits must be between 3 and 8");
        if (coherence_ticks_ > kMaximumCoherenceTicks)
            throw std::invalid_argument("Water coherence_ticks must be between 0 and 12");
        if (rest_policy_ != WaterRestPolicy::CurrentNormalizedV1)
            throw std::invalid_argument("unsupported Water rest policy");
    }

    [[nodiscard]] constexpr std::uint8_t version() const noexcept { return kVersion; }
    [[nodiscard]] constexpr std::uint8_t mass_bits() const noexcept { return mass_bits_; }
    [[nodiscard]] constexpr std::uint8_t coherence_ticks() const noexcept { return coherence_ticks_; }
    [[nodiscard]] constexpr WaterRestPolicy rest_policy() const noexcept { return rest_policy_; }
    [[nodiscard]] constexpr std::uint16_t maximum() const noexcept { return maximum_; }
    [[nodiscard]] constexpr std::uint16_t film() const noexcept { return film_; }
    [[nodiscard]] constexpr std::uint16_t tolerance() const noexcept { return tolerance_; }

    // Nearest-half-up projection into the immutable RG8 condition channel.
    [[nodiscard]] constexpr std::uint8_t normalized_mass(std::uint16_t mass) const noexcept {
        return static_cast<std::uint8_t>(
            quantize_ratio(std::min(mass, maximum_), maximum_, 255U));
    }

    [[nodiscard]] friend constexpr bool operator==(
        const WaterExperimentPolicy&, const WaterExperimentPolicy&) = default;

private:
    [[nodiscard]] static constexpr std::uint16_t derive_maximum(std::uint8_t bits) noexcept {
        return bits >= 3U && bits <= 8U
            ? static_cast<std::uint16_t>((1U << bits) - 1U) : std::uint16_t{0};
    }
    [[nodiscard]] static constexpr std::uint16_t quantize_ratio(
        std::uint32_t n, std::uint32_t d, std::uint32_t maximum) noexcept {
        return d == 0U ? 0U : static_cast<std::uint16_t>((2U*n*maximum+d)/(2U*d));
    }

    std::uint8_t mass_bits_;
    std::uint8_t coherence_ticks_;
    WaterRestPolicy rest_policy_;
    std::uint16_t maximum_;
    std::uint16_t film_;
    std::uint16_t tolerance_;
};

static_assert(WaterExperimentPolicy{}.maximum() == 255U);
static_assert(WaterExperimentPolicy{}.film() == 48U);
static_assert(WaterExperimentPolicy{}.tolerance() == 1U);
static_assert(WaterExperimentPolicy{3U, 0U}.maximum() == 7U);
static_assert(WaterExperimentPolicy{3U, 0U}.film() == 1U);
static_assert(WaterExperimentPolicy{3U, 0U}.tolerance() == 0U);

}  // namespace cybersand
