#pragma once

#include "cybersand/water_normalization.hpp"
#include "cybersand/world.hpp"

namespace godot::prepared_liquid_detail {

// Called by the exclusive desktop owner during preparation only. Stored lanes
// ignore transient Rapier masks. The normal prepared builder validates or
// explicitly normalizes these quantities against the requested target policy.
inline void workbench_copy_retained_cells(const cybersand::World& source,
                                          cybersand::normalization::FinalSetupInput& input) {
    const auto& domain = input.setup.domain;
    if (domain.x != 0 || domain.y != 0 || domain.width > 2048 || domain.height > 2048 ||
        input.mass_bits != source.config().water_experiment_policy.mass_bits() ||
        input.ambient_temperature != source.config().ambient_temperature)
        throw std::invalid_argument("Incompatible retained workbench extent, Water precision or ambient temperature");

    const auto inventory = source.quantity_ledger();
    decltype(inventory.material_cells) copied_materials{};
    std::uint64_t copied_water = 0;
    input.cells.clear();
    input.setup.kind = cybersand::setup::SetupKind::NativeCellFixture;
    input.setup.coverage = cybersand::setup::SetupCoverage::NativePayloadOnly;
    input.setup.definition_digest.reset();
    input.setup.definition_schema = 1;
    for (std::int64_t y = 0; y < domain.height; ++y) {
        for (std::int64_t x = 0; x < domain.width; ++x) {
            const auto material = source.stored_material(x, y);
            const auto temperature = source.stored_temperature(x, y);
            if (material == cybersand::Material::Empty && temperature == input.ambient_temperature) continue;
            if (material != cybersand::Material::Empty)
                ++copied_materials[static_cast<std::uint8_t>(material)];
            if (material == cybersand::Material::Water) copied_water += source.stored_state_a(x,y);
            input.cells.push_back({x, y, material, source.stored_state_a(x, y),
                                   source.stored_state_b(x, y), temperature});
        }
    }
    if (copied_materials != inventory.material_cells || copied_water != inventory.water_visible)
        throw std::invalid_argument("Retained material inventory extends outside the starting-setup canvas");
}

} // namespace godot::prepared_liquid_detail
