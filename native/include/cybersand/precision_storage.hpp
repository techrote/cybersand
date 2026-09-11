#pragma once
// Issue17 only. L2 validated uint64 mask/shift carrier, using its spare state capacity.
#include "cybersand/material.hpp"
#include <cstdint>
#include <type_traits>
#ifndef CYBERSAND_MASS_BITS
#define CYBERSAND_MASS_BITS 8
#endif
#ifndef CYBERSAND_DELAY_BITS
#define CYBERSAND_DELAY_BITS 8
#endif
#ifndef CYBERSAND_LITERAL_TOLERANCE
#define CYBERSAND_LITERAL_TOLERANCE 0
#endif
namespace cybersand::precision {
static_assert(CYBERSAND_MASS_BITS == 4 || CYBERSAND_MASS_BITS == 6 || CYBERSAND_MASS_BITS == 8 || CYBERSAND_MASS_BITS == 10);
static_assert(CYBERSAND_DELAY_BITS == 4 || CYBERSAND_DELAY_BITS == 8);
inline constexpr unsigned maximum = (1U << CYBERSAND_MASS_BITS) - 1;
constexpr unsigned quantize(unsigned n, unsigned d = 255) { return (2*n*maximum+d)/(2*d); }
inline constexpr unsigned film = quantize(48);
inline constexpr unsigned tolerance = CYBERSAND_LITERAL_TOLERANCE ? 1 : quantize(1);
}
namespace cybersand::detail {
struct PrecisionStorage {
    using Word = std::uint64_t;
    Word bits = 0;
    static constexpr Word material_mask = 65535;
    static constexpr Word a_mask = Word{65535} << 16;
    static constexpr Word b_mask = Word{255} << 32;
    static constexpr Word epoch_mask = Word{255} << 56;
    constexpr Material material_value() const noexcept { return static_cast<Material>(bits & material_mask); }
    constexpr std::uint16_t state_a_value() const noexcept { return static_cast<std::uint16_t>((bits & a_mask) >> 16); }
    constexpr std::uint8_t state_b_value() const noexcept { return static_cast<std::uint8_t>((bits >> 32) & delay_mask()); }
    constexpr std::uint8_t epoch_value() const noexcept { return static_cast<std::uint8_t>(bits >> 56); }
    constexpr Word delay_mask() const noexcept { return material_value() == Material::Water ? ((Word{1} << CYBERSAND_DELAY_BITS)-1) : 255; }
    constexpr void set_material(Material v) noexcept { bits = (bits & ~material_mask) | static_cast<Word>(v); }
    constexpr void set_state_a(std::uint16_t v) noexcept { bits = (bits & ~a_mask) | (Word{v} << 16); }
    constexpr void set_state_b(std::uint8_t v) noexcept { bits = (bits & ~b_mask) | ((Word{v} & delay_mask()) << 32); }
    constexpr void set_epoch(std::uint8_t v) noexcept { bits = (bits & ~epoch_mask) | (Word{v} << 56); }
    static constexpr PrecisionStorage for_material(Material value) noexcept {
        const auto& d = material_definition(value);
        PrecisionStorage c;
        c.set_material(value);
        c.set_state_a(static_cast<std::uint16_t>(value == Material::Water ? precision::maximum : d.initial_state_a));
        c.set_state_b(d.initial_state_b);
        return c;
    }
};
static_assert(sizeof(PrecisionStorage) == 8 && alignof(PrecisionStorage) == 8);
static_assert(std::is_trivially_copyable_v<PrecisionStorage>);
}
