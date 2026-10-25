#pragma once
// Exclusive native owner/preparation boundary only. No Godot calls or file I/O.
#include "cybersand/liquid_run_receipt.hpp"

namespace cybersand::receipt {
inline NativeFacts capture_native_facts(const World& world, const SetupDescriptor& setup) {
    validate_setup_descriptor(setup);
    if (world.has_failed() || world.tick_index() != world.completed_tick_index())
        throw std::invalid_argument("native receipt capture requires a healthy completed boundary");
    const auto& config = world.config();
    std::vector<normalization::FinalSetupCell> cells;
    const auto& d = setup.domain;
    cells.reserve(static_cast<std::size_t>(d.width) * d.height);
    for (std::uint32_t dy = 0; dy < d.height; ++dy) for (std::uint32_t dx = 0; dx < d.width; ++dx) {
        const auto x = d.x + dx, y = d.y + dy;
        const auto material = world.stored_material(x, y);
        const auto temperature = world.stored_temperature(x, y);
        if (material == Material::Empty && temperature == config.ambient_temperature) continue;
        cells.push_back({x, y, material, world.stored_state_a(x, y), world.stored_state_b(x, y), temperature});
    }
    NativeFactValues value;
    value.config = config; value.setup = setup;
    value.prepared_native_payload = normalization::native_payload_digest(config.water_experiment_policy.mass_bits(),
        config.ambient_temperature, d, cells);
    value.selected_region = world.simulation_region(); value.adhesion = world.liquid_surface_adhesion_enabled();
    value.selected_cores = world.selected_simulation_cores();
    value.applied_cores = world.applied_simulation_cores();
    value.attempted_tick = world.tick_index(); value.completed_tick = world.completed_tick_index();
    value.quantity = world.quantity_ledger();
    value.physical_hash = world.physical_state_hash(); value.physical_hash_version = world.physical_state_hash_version();
    if (world.pressure_flow_enabled()) {
        const auto optimization_identity=world.pressure_optimization_identity();
        value.solver_state_extensions.push_back({3, PressureFlowParameters::kVersion,
            static_cast<std::uint16_t>(optimization_identity ? 1 : 0), optimization_identity});
        value.effective_pressure=world.pressure_flow_parameters();
    }
    if (world.inertial_enabled())
        value.solver_state_extensions.push_back({4,InertialParameters::kVersion,1,inertial_extension_identity(world.inertial_parameters())});
    return NativeFacts(std::move(value));
}
} // namespace cybersand::receipt
