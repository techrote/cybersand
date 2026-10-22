#pragma once
// MAT-003PREPASS S1 only. Included by generated copies, never production inputs.
#include "carriers.hpp"
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <type_traits>

#ifndef MAT003_STORAGE_KIND
#error "MAT003_STORAGE_KIND must come from the registered World overlay"
#endif
#ifndef MAT003_EPOCH_BITS
#error "MAT003_EPOCH_BITS must come from the registered World overlay"
#endif
#ifndef MAT003_EXTRA_BYTES
#error "MAT003_EXTRA_BYTES must come from the registered World overlay"
#endif
#ifndef MAT003_SPLIT
#error "MAT003_SPLIT must come from the registered World overlay"
#endif

namespace mat003_world {

// Kind values are emitted by world_overlay.py from registered arm records.
// 0=exact source, 1=word, 2=padded, 3=packed, 4=aligned, 5=split.
inline constexpr bool source_control = MAT003_STORAGE_KIND == 0;
inline constexpr bool dispatch_observed = !source_control;
inline constexpr bool split_storage = MAT003_SPLIT != 0;
inline constexpr unsigned epoch_bits = MAT003_EPOCH_BITS;
inline constexpr unsigned extra_bytes = MAT003_EXTRA_BYTES;
using Epoch = std::conditional_t<epoch_bits == 8, std::uint8_t, std::uint16_t>;
using Tail = std::conditional_t<extra_bytes == 1, std::uint8_t, std::uint16_t>;
static_assert(epoch_bits == 8 || epoch_bits == 16);
static_assert(extra_bytes <= 2);
static_assert(!source_control || (epoch_bits == 8 && extra_bytes == 0));
static_assert(split_storage == (MAT003_STORAGE_KIND == 5));

#if MAT003_STORAGE_KIND == 0
using Representation = mat003::Source;
#elif MAT003_STORAGE_KIND == 1 || MAT003_STORAGE_KIND == 5
using Representation = mat003::Word;
#elif MAT003_STORAGE_KIND == 2
using Representation = mat003::Padded;
#elif MAT003_STORAGE_KIND == 3
using Representation = mat003::Packed<MAT003_EXTRA_BYTES>;
#elif MAT003_STORAGE_KIND == 4
using Representation = mat003::Aligned<MAT003_EXTRA_BYTES>;
#else
#error "Unknown MAT003_STORAGE_KIND"
#endif

struct EngineCell : mat003::Cell<Representation, epoch_bits> {
    using Base = mat003::Cell<Representation, epoch_bits>;
    cybersand::Material material_value() const noexcept {
        return static_cast<cybersand::Material>(Base::material());
    }
    std::uint16_t state_a_value() const noexcept { return Base::a(); }
    std::uint8_t state_b_value() const noexcept {
        return static_cast<std::uint8_t>(Base::b() & delay_mask());
    }
    Epoch epoch_value() const noexcept { return Base::epoch(); }
    std::uint8_t delay_mask() const noexcept {
        return material_value() == cybersand::Material::Water
            ? static_cast<std::uint8_t>((1U << CYBERSAND_DELAY_BITS) - 1U)
            : std::uint8_t{255};
    }
    void set_material(cybersand::Material value) noexcept {
        Base::material(static_cast<std::uint16_t>(value));
    }
    void set_state_a(std::uint16_t value) noexcept { Base::a(value); }
    void set_state_b(std::uint8_t value) noexcept { Base::b(value & delay_mask()); }
    void set_epoch(Epoch value) noexcept { Base::epoch(value); }
    std::uint16_t neutral_extra() const noexcept { return Base::extra(); }
    void set_neutral_extra(std::uint16_t value) noexcept { (void)Base::extra(value); }
    static EngineCell for_material(cybersand::Material value) noexcept {
        const auto& definition = cybersand::material_definition(value);
        EngineCell cell;
        cell.set_material(value);
        cell.set_state_a(static_cast<std::uint16_t>(
            value == cybersand::Material::Water ? cybersand::precision::maximum
                                               : definition.initial_state_a));
        cell.set_state_b(definition.initial_state_b);
        return cell;
    }
};

// Keeping the exact source type for the source arm preserves every source byte
// and its existing accessor implementation, including the original counter type.
using Cell = std::conditional_t<source_control,
                               cybersand::detail::PrecisionStorage, EngineCell>;
static_assert(std::is_trivially_copyable_v<Cell>);
static_assert(sizeof(EngineCell) == sizeof(Representation));
static_assert(!split_storage || sizeof(Cell) == 8);
static_assert(MAT003_STORAGE_KIND != 3 || sizeof(Cell) == 8 + extra_bytes);

inline std::uint16_t get_extra(const Cell& cell) noexcept {
#if MAT003_STORAGE_KIND == 0
    (void)cell;
    return 0;
#else
    return cell.neutral_extra();
#endif
}
inline void set_extra(Cell& cell, std::uint16_t value) noexcept {
#if MAT003_STORAGE_KIND == 0
    (void)cell;
    (void)value;
#else
    cell.set_neutral_extra(value);
#endif
}

struct DispatchObservations {
    std::uint64_t calls = 0;
    std::uint64_t dispatched_tasks = 0;
    std::uint64_t worker_tasks = 0;
};
inline std::atomic<std::uint64_t> dispatch_calls{0};
inline std::atomic<std::uint64_t> dispatched_task_count{0};
inline std::atomic<std::uint64_t> executed_worker_task_count{0};

// Correctness observers only. No elapsed times with these atomics are a
// performance result. The unchanged source arm does not invoke these hooks.
inline void observe_dispatch(std::size_t tasks) noexcept {
    dispatch_calls.fetch_add(1, std::memory_order_relaxed);
    dispatched_task_count.fetch_add(static_cast<std::uint64_t>(tasks),
                                    std::memory_order_relaxed);
}
inline void observe_worker_task() noexcept {
    executed_worker_task_count.fetch_add(1, std::memory_order_relaxed);
}
inline DispatchObservations dispatch_observations() noexcept {
    return {dispatch_calls.load(std::memory_order_relaxed),
            dispatched_task_count.load(std::memory_order_relaxed),
            executed_worker_task_count.load(std::memory_order_relaxed)};
}
// Call only between completed fixture Worlds, with no dispatch in progress.
inline void reset_dispatch_observations() noexcept {
    dispatch_calls.store(0, std::memory_order_relaxed);
    dispatched_task_count.store(0, std::memory_order_relaxed);
    executed_worker_task_count.store(0, std::memory_order_relaxed);
}

} // namespace mat003_world
