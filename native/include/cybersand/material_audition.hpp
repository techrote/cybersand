#pragma once

#include "cybersand/material.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/material_rules.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <utility>

namespace cybersand {

// Scene-local, existing-ID authoring. This is not a replacement catalogue.
// -1 means inherit the accepted descriptor/rule. Native validation occurs before
// narrowing, allocation or publication. The bridge must additionally reject
// duplicate/unknown JSON keys and rows rather than discarding them here.
struct MaterialAuditionProfile {
    static constexpr std::uint32_t kSchemaVersion = 1U;
    static constexpr std::size_t kMaximumProfileIdBytes = 64U;
    // An explicit UI action may scan resident cells once to wake affected
    // activity blocks. Ordinary 2048-square canvases fit comfortably; oversized
    // scenes receive a refusal before publication, never a partial transition.
    static constexpr std::uint64_t kMaximumWakeScanCells = 16U * 1024U * 1024U;
    std::uint32_t schema_version = kSchemaVersion;
    std::string profile_id = "default";
    std::array<std::int32_t, kMaterialDefinitions.size()> density;
    std::array<std::int32_t, kMaterialDefinitions.size()> viscosity;
    std::array<std::int32_t, kPairInteractionRules.size()> probability_threshold;

    MaterialAuditionProfile() {
        density.fill(-1);
        viscosity.fill(-1);
        probability_threshold.fill(-1);
    }
};

enum class MaterialAuditionOutcome : std::uint8_t {
    Applied,
    WorldMismatch,
    StaleRevision,
    WorldFailed,
    TickInProgress,
    InvalidProfile,
    UnsupportedProperty,
    InvalidValue,
    RevisionExhausted,
    AllocationFailed,
    CapacityExceeded,
};

struct MaterialAuditionResult {
    MaterialAuditionOutcome outcome = MaterialAuditionOutcome::InvalidProfile;
    std::string_view reason = "invalid profile";
    // field is empty for identity/lifetime refusal. index is a material or pair
    // slot; it is diagnostic data, not a second configuration authority.
    std::string_view field;
    std::int32_t index = -1;
    std::uint64_t world_id = 0;
    std::uint64_t prior_revision = 0;
    std::uint64_t revision = 0;
    std::uint64_t behavior_hash = 0;
    std::uint64_t woken_blocks = 0;
    std::uint64_t scanned_cells = 0;
    [[nodiscard]] bool applied() const noexcept {
        return outcome == MaterialAuditionOutcome::Applied;
    }
};

[[nodiscard]] constexpr bool material_audition_supports_density(Material material) noexcept {
    const auto& definition = material_definition(material);
    // The scoped consumer is directional cell exchange, not body mass/impulse.
    return definition.valid && definition.current_rule_available && definition.movable &&
           definition.accepts_density_exchange && definition.density_motion != DensityMotion::None;
}

[[nodiscard]] constexpr bool material_audition_supports_viscosity(Material material) noexcept {
    const auto kernel = material_definition(material).kernel;
    return kernel == RuleKernel::YieldingLiquid || kernel == RuleKernel::Cement ||
           kernel == RuleKernel::MoltenGlass;
}

// Prepared once at the serialized owner boundary. Workers only read the fixed
// arrays for the duration of a tick. No hot-path strings, locks or allocations.
struct MaterialAuditionState {
    MaterialAuditionProfile profile;
    std::array<std::uint16_t, kMaterialDefinitions.size()> density{};
    std::array<std::uint8_t, kMaterialDefinitions.size()> viscosity{};
    std::array<std::uint8_t, kPairInteractionRules.size()> probability_threshold{};
    bool density_changed = false;
    bool viscosity_changed = false;
    bool reactions_changed = false;
    std::uint64_t behavior_hash = 0;
    [[nodiscard]] bool changes_behavior() const noexcept {
        return density_changed || viscosity_changed || reactions_changed;
    }
};

// World moves transfer the token and retire the moved-from identity. A raw
// scalar's default move would otherwise leave two objects accepting one token.
struct MaterialAuditionWorldToken {
    std::uint64_t value = 0;
    explicit MaterialAuditionWorldToken(std::uint64_t identity = 0) noexcept : value(identity) {}
    MaterialAuditionWorldToken(const MaterialAuditionWorldToken&) = delete;
    MaterialAuditionWorldToken& operator=(const MaterialAuditionWorldToken&) = delete;
    MaterialAuditionWorldToken(MaterialAuditionWorldToken&& other) noexcept
        : value(std::exchange(other.value, 0)) {}
    MaterialAuditionWorldToken& operator=(MaterialAuditionWorldToken&& other) noexcept {
        if (this != &other) value = std::exchange(other.value, 0);
        return *this;
    }
};

}  // namespace cybersand
