#pragma once

#include "cybersand/material.hpp"

#include <array>
#include <bit>
#include <cstdint>

namespace cybersand::material_lifecycle {

// OBJECTSHARD-001 shares only these existing decisions. Callers still own
// admission, neighbourhood reads, pair-reaction precedence, transport,
// accounting, activity and traversal. This is not a second material engine.
inline constexpr std::uint16_t kPolicyVersion = 1;
inline constexpr std::uint64_t kCombustionPeriod = 2;
inline constexpr std::uint32_t kCombustionStream = 191;
inline constexpr std::uint64_t kSmokePeriod = 8;
inline constexpr std::uint32_t kSmokeStream = 193;
inline constexpr std::uint16_t kWoodFireLifetime = 32;

struct NeighbourOffset {
    std::int8_t x = 0;
    std::int8_t y = 0;
};
inline constexpr std::array<NeighbourOffset, 8> kNeighbours{{
    {-1, -1}, {0, -1}, {1, -1}, {-1, 0},
    {1, 0}, {-1, 1}, {0, 1}, {1, 1},
}};

[[nodiscard]] constexpr std::uint64_t mix(std::uint64_t value) noexcept {
    value ^= value >> 30U;
    value *= 0xbf58476d1ce4e5b9ULL;
    value ^= value >> 27U;
    value *= 0x94d049bb133111ebULL;
    return value ^ (value >> 31U);
}

// Coordinates are immutable logical material coordinates. Rotating/translating
// a shard must not reseed its chemistry. These are World's existing streams.
[[nodiscard]] constexpr std::uint64_t lane_phase(
    std::int64_t x, std::int64_t y, std::uint64_t period,
    std::uint32_t stream) noexcept {
    return mix(static_cast<std::uint64_t>(x) * 0x9e3779b185ebca87ULL ^
               std::rotl(static_cast<std::uint64_t>(y), 23) ^
               static_cast<std::uint64_t>(stream) * 0xa0761d6478bd642fULL) % period;
}

[[nodiscard]] constexpr bool lane_due(std::uint64_t tick, std::int64_t x,
    std::int64_t y, std::uint64_t period, std::uint32_t stream) noexcept {
    return tick % period == lane_phase(x, y, period, stream);
}

[[nodiscard]] constexpr std::uint8_t random(std::uint64_t tick, std::int64_t x,
    std::int64_t y, std::uint32_t stream) noexcept {
    return static_cast<std::uint8_t>(mix(
        static_cast<std::uint64_t>(x) * 0x9e3779b185ebca87ULL ^
        std::rotl(static_cast<std::uint64_t>(y), 23) ^
        tick * 0xd6e8feb86659fd93ULL ^
        static_cast<std::uint64_t>(stream) * 0xa0761d6478bd642fULL) & 0xffU);
}

struct Transition {
    Material material = Material::Empty;
    std::uint16_t state_a = 0;
    std::uint8_t state_b = 0;
    bool write = false;
    bool keep_active = false;
    // A potential emission: the caller samples stream 12 after the source
    // decision and creates Fire only in an admitted Empty neighbour/carrier.
    bool sample_fire_emission = false;
};

[[nodiscard]] constexpr Transition combustible(Material material,
    std::uint16_t state_a, std::uint8_t burn, bool due,
    bool water_neighbour) noexcept {
    Transition step{material, state_a, burn};
    if (burn == 0U) return step;
    if (!due) {
        step.keep_active = true;
        return step;
    }
    step.write = true;
    if (water_neighbour) {
        step.state_b = 0;
    } else if (burn <= 1U) {
        step.material = Material::Empty;
        step.state_a = 0;
        step.state_b = 0;
    } else {
        step.state_b = static_cast<std::uint8_t>(burn - 1U);
        step.sample_fire_emission = (burn & 7U) == 0U;
    }
    return step;
}

[[nodiscard]] constexpr Transition fire_lifetime(std::uint16_t lifetime) noexcept {
    if (lifetime <= 1U) {
        const auto& smoke = material_definition(Material::Smoke);
        return {Material::Smoke, smoke.initial_state_a, smoke.initial_state_b, true};
    }
    // Preserve the existing kernel's byte narrowing for authored wide tuples.
    return {Material::Fire, static_cast<std::uint8_t>(lifetime - 1U), 0, true};
}

[[nodiscard]] constexpr Transition smoke_lifetime(Material material,
    std::uint16_t lifetime, std::uint8_t smoke_neighbours, bool due) noexcept {
    if (!due) return {material, lifetime, 0, false, true};
    if (lifetime == 0U) lifetime = material_definition(material).initial_state_a;
    const auto decay = static_cast<std::uint8_t>(smoke_neighbours >= 5U ? 2U : 1U);
    if (lifetime <= decay) return {Material::Empty, 0, 0, true};
    return {material, static_cast<std::uint8_t>(lifetime - decay), 0, true};
}

} // namespace cybersand::material_lifecycle
