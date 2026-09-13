#pragma once

#include "cybersand/material.hpp"

#include <cstdint>
#include <optional>
#include <span>

namespace cybersand {

struct PairReactionResult {
    Material source_product = Material::Empty;
    Material target_product = Material::Empty;
};

// Immutable descriptor catalogue for the executable compact kernels owned by
// World. This type deliberately owns no per-cell state, scheduler, storage
// pointer, Godot object, random generator, or growing container.
class MaterialRules final {
public:
    MaterialRules() = delete;

    [[nodiscard]] static std::span<const MaterialDefinition> descriptors() noexcept;
    [[nodiscard]] static const MaterialDefinition& descriptor(Material material) noexcept;
    [[nodiscard]] static bool is_valid(std::uint16_t value) noexcept;
    [[nodiscard]] static bool has_current_rule(Material material) noexcept;
    [[nodiscard]] static bool can_density_exchange(Material source, Material target,
                                                   std::int64_t vertical_delta) noexcept;
    [[nodiscard]] static bool is_free_leveling_liquid(Material material) noexcept;
    [[nodiscard]] static bool is_hard_surface(Material material) noexcept;
    [[nodiscard]] static bool supports_granular_load(Material material) noexcept;
    [[nodiscard]] static bool has_pair_reactions(Material material) noexcept;
    [[nodiscard]] static std::optional<PairReactionResult> pair_reaction(
        Material source, Material target, std::uint8_t probability_roll) noexcept;
    // Serial/discrete reference tuning only; this value does not expand a
    // phased native kernel's declared write radius.
    [[nodiscard]] static std::uint8_t discrete_lateral_flow_rate(
        Material material, std::uint8_t maximum_rate = 24) noexcept;
    [[nodiscard]] static std::uint16_t apply_lateral_viscosity(
        Material material, std::uint16_t requested_transfer) noexcept;
};

}  // namespace cybersand
