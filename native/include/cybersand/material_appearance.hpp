#pragma once

#include "cybersand/material.hpp"
#include "cybersand/water_experiment_policy.hpp"

#include <array>
#include <cstddef>
#include <cstdint>

namespace cybersand {

// RenderBridge projection only. Authoritative material kernels retain both
// state bytes; the compact RG8 presentation stream selects the one channel
// that best communicates each material's current condition. Appearance code
// may read this projection but must never write it back into simulation.
enum class VisualStateSource : std::uint8_t {
    Zero = 0,
    StateA = 1,
    StateB = 2,
};

inline constexpr std::array<VisualStateSource, kMaterialDefinitions.size()>
    kVisualStateSources{{
        VisualStateSource::Zero,   // empty
        VisualStateSource::Zero,   // wall
        VisualStateSource::Zero,   // sand
        VisualStateSource::StateA, // water mass
        VisualStateSource::StateA, // smoke lifetime
        VisualStateSource::Zero,   // cloner
        VisualStateSource::StateA, // fire lifetime
        VisualStateSource::StateB, // wood burn progress
        VisualStateSource::Zero,   // lava
        VisualStateSource::Zero,   // ice
        VisualStateSource::Zero,   // invalid
        VisualStateSource::StateA, // plant energy
        VisualStateSource::StateA, // acid mass/state
        VisualStateSource::StateB, // stone collapse state
        VisualStateSource::Zero,   // dust
        VisualStateSource::StateA, // mite heading/state
        VisualStateSource::StateB, // oil burn progress
        VisualStateSource::StateA, // rocket flight state
        VisualStateSource::StateA, // fungus energy
        VisualStateSource::StateA, // seed growth stage
        VisualStateSource::Zero,   // paste
        VisualStateSource::Zero,   // slush
        VisualStateSource::StateA, // steam lifetime
        VisualStateSource::Zero,   // salt
        VisualStateSource::Zero,   // brine
        VisualStateSource::Zero,   // sodium
        VisualStateSource::Zero,   // gunpowder
        VisualStateSource::StateB, // coal burn progress
        VisualStateSource::StateB, // metal charge
        VisualStateSource::Zero,   // rust
        VisualStateSource::StateA, // cement cure remaining
        VisualStateSource::Zero,   // concrete
        VisualStateSource::Zero,   // toxic sludge
        VisualStateSource::Zero,   // mercury
        VisualStateSource::StateA, // spark lifetime
        VisualStateSource::Zero,   // glass
        VisualStateSource::StateA, // molten glass heat/cooling
        VisualStateSource::StateA, // foam lifetime
        VisualStateSource::Zero,   // limestone block
        VisualStateSource::Zero,   // sandstone block
        VisualStateSource::Zero,   // granite block
        VisualStateSource::Zero,   // cobblestone
        VisualStateSource::Zero,   // mossy cobblestone
        VisualStateSource::Zero,   // red brick
        VisualStateSource::Zero,   // lime plaster
        VisualStateSource::Zero,   // wattle and daub
        VisualStateSource::StateB, // oak timber burn progress
        VisualStateSource::StateB, // thatch burn progress
        VisualStateSource::Zero,   // terracotta tile
        VisualStateSource::Zero,   // slate
        VisualStateSource::Zero,   // wrought iron
        VisualStateSource::Zero,   // lead sheet
        VisualStateSource::Zero,   // bronze
        VisualStateSource::Zero,   // copper
        VisualStateSource::Zero,   // verdigris copper
        VisualStateSource::Zero,   // stained glass
        VisualStateSource::Zero,   // packed earth
        VisualStateSource::Zero,   // industrial brick
        VisualStateSource::Zero,   // reinforced concrete
        VisualStateSource::Zero,   // asphalt
        VisualStateSource::Zero,   // wet asphalt
        VisualStateSource::Zero,   // wet cobblestone
        VisualStateSource::Zero,   // steel plate
        VisualStateSource::Zero,   // painted steel
        VisualStateSource::Zero,   // corrugated steel
        VisualStateSource::Zero,   // rusted steel
        VisualStateSource::Zero,   // steel grating
        VisualStateSource::Zero,   // chainlink
        VisualStateSource::Zero,   // steel pipe
        VisualStateSource::Zero,   // copper pipe
        VisualStateSource::Zero,   // ceramic tile
        VisualStateSource::Zero,   // chemical glass
        VisualStateSource::Zero,   // dark glass
        VisualStateSource::Zero,   // rubber
        VisualStateSource::Zero,   // cable bundle
        VisualStateSource::Zero,   // insulation
        VisualStateSource::Zero,   // hazard stripe
        VisualStateSource::Zero,   // neon cyan
        VisualStateSource::Zero,   // neon magenta
        VisualStateSource::Zero,   // neon amber
        VisualStateSource::Zero,   // LED white
    }};

[[nodiscard]] constexpr std::uint8_t project_visual_state(
    Material material, std::uint16_t state_a, std::uint8_t state_b,
    const WaterExperimentPolicy& water_policy = WaterExperimentPolicy{}) noexcept {
    const auto index = static_cast<std::size_t>(material);
    if (index >= kVisualStateSources.size()) return 0;
    switch (kVisualStateSources[index]) {
        case VisualStateSource::StateA:
            return material == Material::Water
                       ? water_policy.normalized_mass(state_a)
                       : static_cast<std::uint8_t>(state_a);
        case VisualStateSource::StateB:
            return state_b;
        case VisualStateSource::Zero:
            return 0;
    }
    return 0;
}

}  // namespace cybersand
