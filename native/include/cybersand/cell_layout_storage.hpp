#pragma once

// Issue16 experiment branch: identical legacy accessors for byte and packed cells.
#include "cybersand/material.hpp"
#include <cstddef>
#include <cstdint>
#include <type_traits>

#ifndef CYBERSAND_CELL_LAYOUT_ALIGNMENT
#define CYBERSAND_CELL_LAYOUT_ALIGNMENT 1
#endif

#ifndef CYBERSAND_CELL_LAYOUT_EPOCH_BITS
#define CYBERSAND_CELL_LAYOUT_EPOCH_BITS 8
#endif
static_assert(CYBERSAND_CELL_LAYOUT_EPOCH_BITS == 8 || CYBERSAND_CELL_LAYOUT_EPOCH_BITS == 6);
#if CYBERSAND_CELL_LAYOUT_EPOCH_BITS == 6
#if !defined(CYBERSAND_CELL_LAYOUT_PACKED) || !CYBERSAND_CELL_LAYOUT_PACKED || CYBERSAND_CELL_LAYOUT_EXPERIMENT != 4
#error "Six-bit epochs require the packed32 experiment"
#endif
#endif
namespace cybersand::detail {

#if defined(CYBERSAND_CELL_LAYOUT_PACKED) && CYBERSAND_CELL_LAYOUT_PACKED
struct CellLayoutStorage {
    static_assert(CYBERSAND_CELL_LAYOUT_EXPERIMENT == 4 || CYBERSAND_CELL_LAYOUT_EXPERIMENT == 8);
    using Word = std::conditional_t<CYBERSAND_CELL_LAYOUT_EXPERIMENT == 8, std::uint64_t, std::uint32_t>;
    static constexpr bool wide = sizeof(Word) == 8;
    static constexpr unsigned a_shift = wide ? 16U : 8U;
    static constexpr unsigned b_shift = wide ? 24U : 16U;
    static_assert(!wide || CYBERSAND_CELL_LAYOUT_EPOCH_BITS == 8);
    static constexpr unsigned epoch_shift = wide ? 56U : (CYBERSAND_CELL_LAYOUT_EPOCH_BITS == 6 ? 26U : 24U);
    static constexpr Word epoch_limit = (Word{1} << CYBERSAND_CELL_LAYOUT_EPOCH_BITS) - 1;
    static constexpr Word material_mask = wide ? Word{65535} : Word{255};
    static constexpr Word a_mask = Word{255} << a_shift;
    static constexpr Word b_mask = Word{255} << b_shift;
    static constexpr Word epoch_mask = epoch_limit << epoch_shift;
    static constexpr Word used_mask = material_mask | a_mask | b_mask | epoch_mask;
    static_assert((material_mask & a_mask) == 0 && (a_mask & b_mask) == 0 && (b_mask & epoch_mask) == 0);
    Word bits = 0;

    [[nodiscard]] constexpr Material material_value() const noexcept {
        // The legacy enum is still8-bit: upper ID bits are not migration evidence.
        return static_cast<Material>(bits & material_mask);
    }
    [[nodiscard]] constexpr std::uint8_t state_a_value() const noexcept { return static_cast<std::uint8_t>((bits & a_mask) >> a_shift); }
    [[nodiscard]] constexpr std::uint8_t state_b_value() const noexcept { return static_cast<std::uint8_t>((bits & b_mask) >> b_shift); }
    [[nodiscard]] constexpr std::uint8_t epoch_value() const noexcept { return static_cast<std::uint8_t>((bits & epoch_mask) >> epoch_shift); }
    constexpr void set_material(Material v) noexcept { bits = (bits & ~material_mask) | static_cast<Word>(v); }
    constexpr void set_state_a(std::uint8_t v) noexcept { bits = (bits & ~a_mask) | (static_cast<Word>(v) << a_shift); }
    constexpr void set_state_b(std::uint8_t v) noexcept { bits = (bits & ~b_mask) | (static_cast<Word>(v) << b_shift); }
    constexpr void set_epoch(std::uint8_t v) noexcept { bits = (bits & ~epoch_mask) | ((static_cast<Word>(v) & epoch_limit) << epoch_shift); }
    [[nodiscard]] constexpr bool unused_zero() const noexcept { return (bits & ~used_mask) == 0 && (!wide || (bits & Word{65280}) == 0); }
#else
struct alignas(CYBERSAND_CELL_LAYOUT_ALIGNMENT) CellLayoutStorage {
    Material material_byte = Material::Empty;
    std::uint8_t a_byte = 0, b_byte = 0, epoch_byte = 0;
#if defined(CYBERSAND_CELL_LAYOUT_EXPERIMENT) && CYBERSAND_CELL_LAYOUT_EXPERIMENT == 8
    std::uint8_t unused[4] = {};
#endif
    [[nodiscard]] constexpr Material material_value() const noexcept { return material_byte; }
    [[nodiscard]] constexpr std::uint8_t state_a_value() const noexcept { return a_byte; }
    [[nodiscard]] constexpr std::uint8_t state_b_value() const noexcept { return b_byte; }
    [[nodiscard]] constexpr std::uint8_t epoch_value() const noexcept { return epoch_byte; }
    constexpr void set_material(Material v) noexcept { material_byte = v; }
    constexpr void set_state_a(std::uint8_t v) noexcept { a_byte = v; }
    constexpr void set_state_b(std::uint8_t v) noexcept { b_byte = v; }
    constexpr void set_epoch(std::uint8_t v) noexcept { epoch_byte = v; }
    [[nodiscard]] constexpr bool unused_zero() const noexcept {
#if defined(CYBERSAND_CELL_LAYOUT_EXPERIMENT) && CYBERSAND_CELL_LAYOUT_EXPERIMENT == 8
        for (auto v : unused) if (v != 0) return false;
#endif
        return true;
    }
#endif
    [[nodiscard]] static constexpr CellLayoutStorage for_material(Material value) noexcept {
        const auto& definition = material_definition(value);
        CellLayoutStorage cell{};
        cell.set_material(value);
        cell.set_state_a(definition.initial_state_a);
        cell.set_state_b(definition.initial_state_b);
        return cell;
    }
};

static_assert(std::is_trivially_copyable_v<CellLayoutStorage>);
#if !defined(CYBERSAND_CELL_LAYOUT_PACKED) || !CYBERSAND_CELL_LAYOUT_PACKED
static_assert(offsetof(CellLayoutStorage, material_byte) == 0 && offsetof(CellLayoutStorage, a_byte) == 1 &&
              offsetof(CellLayoutStorage, b_byte) == 2 && offsetof(CellLayoutStorage, epoch_byte) == 3);
#endif
#ifdef CYBERSAND_CELL_LAYOUT_EXPERIMENT
static_assert(sizeof(CellLayoutStorage) == CYBERSAND_CELL_LAYOUT_EXPERIMENT);
static_assert(alignof(CellLayoutStorage) == CYBERSAND_CELL_LAYOUT_ALIGNMENT);
#else
static_assert(sizeof(CellLayoutStorage) == 4 && alignof(CellLayoutStorage) == 1);
#endif

} // namespace cybersand::detail
