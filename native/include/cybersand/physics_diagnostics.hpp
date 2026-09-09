#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace cybersand {

// Experiment-only construction options. Defaults preserve the production rules.
// No descriptor mutation, new random draws, or live worker reconfiguration.
struct PhysicsDiagnosticConfig {
    bool enabled = false;
    bool disable_powder_exchange_targets = false;
    std::int16_t mercury_viscosity = -1;
};

enum class PhysicsEvent : std::uint8_t {
    EmptyMove = 1, DensitySwap, Conversion, WaterTransfer, RejectedMove,
    BodyDisplacement, BodyContact, PowderMix, GrainTransport, LateralProbe, FlowProbe
};

// Fixed open-addressing counters, not an event log. Overflow drops observations,
// never simulation work. Keys encode kind/source/target/sign(dy)/sign(dx).
template <std::size_t Capacity> struct PhysicsHistogram {
    struct Entry { std::uint32_t key = 0; std::uint64_t count = 0; };
    std::array<Entry, Capacity> entries{};
    std::uint64_t overflow = 0;
    std::size_t used = 0;
    void add(std::uint32_t key, std::uint64_t count = 1) noexcept {
        auto slot = static_cast<std::size_t>((key * 2654435761U) % Capacity);
        for (std::size_t probe = 0; probe < Capacity; ++probe) {
            auto& entry = entries[slot];
            if (entry.key == 0 || entry.key == key) {
                if (entry.key == 0) { entry.key = key; ++used; }
                if (count > std::numeric_limits<std::uint64_t>::max() - entry.count) {
                    ++overflow;
                } else { entry.count += count; }
                return;
            }
            slot = (slot + 1) % Capacity;
        }
        ++overflow;
    }
};
using PhysicsJobHistogram = PhysicsHistogram<256>;
using PhysicsTotals = PhysicsHistogram<8192>;

inline std::uint32_t physics_event_key(PhysicsEvent kind, std::uint8_t source,
    std::uint8_t target, std::int64_t dx, std::int64_t dy) noexcept {
    const auto direction = static_cast<std::uint32_t>(
        ((dy > 0) - (dy < 0) + 1) * 3 + (dx > 0) - (dx < 0) + 1);
    return (static_cast<std::uint32_t>(kind) << 24U) |
        (static_cast<std::uint32_t>(source) << 16U) |
        (static_cast<std::uint32_t>(target) << 8U) | direction;
}
} // namespace cybersand
