// Included in CyberDemoBridge's public section. This cold, read-only boundary
// copies compiled descriptors and the actual predicates; it does not construct
// or mutate a World, replace material authority, or run on a pool worker.
[[nodiscard]] Dictionary inspect_material_catalogue() const {
    static constexpr std::array state_names{"Empty", "Solid", "Powder", "Liquid", "Gas", "Agent"};
    static constexpr std::array kernel_names{
        "None", "Sand", "Water", "Gas", "Cloner", "Fire", "Combustible", "Lava",
        "Ice", "Plant", "Acid", "Stone", "Dust", "Mite", "Oil", "Rocket", "Fungus",
        "Seed", "YieldingLiquid", "Steam", "Gunpowder", "Coal", "Metal", "Cement",
        "Spark", "MoltenGlass", "Foam"};
    static constexpr std::array motion_names{"None", "Down", "Up"};
    static constexpr std::array flow_names{"None", "FreeMass", "CellularYield"};
    static constexpr std::array visual_names{"Zero", "StateA", "StateB"};
    static_assert(kernel_names.size() == static_cast<std::size_t>(cybersand::RuleKernel::Foam) + 1U);
    Dictionary out;
    out["schema_version"] = 1;
    out["origin"] = "compiled-native-readback";
    out["descriptor_source"] = "native/include/cybersand/material.hpp";
    out["capability_source"] = "native/src/material_rules.cpp";
    out["appearance_source"] = "native/include/cybersand/material_appearance.hpp";
    out["runtime_mutable"] = false;
    out["world_eligibility_observed"] = false;
    out["default_liquid_policy"] = CyberNativeCellWorld::liquid_policy_receipt(
        cybersand::LiquidSolverPolicy{}, -1);
    out["water_yield_default_viscosity"] = static_cast<std::int64_t>(
        cybersand::WaterCellularYieldParameters::kDefaultViscosity);
    out["water_yield_material_block_version"] = static_cast<std::int64_t>(
        cybersand::WaterCellularYieldParameters::kMaterialBlockVersion);
    Array materials;
    const auto definitions = cybersand::MaterialRules::descriptors();
    for (std::size_t i = 0; i < definitions.size(); ++i) {
        const auto& d = definitions[i];
        const auto material = static_cast<cybersand::Material>(i);
        Dictionary item;
        item["id"] = static_cast<std::int64_t>(i);
        item["name"] = interaction_string(d.name);
        item["valid"] = d.valid;
        item["paintable"] = d.valid && material != cybersand::Material::Empty;
        item["state"] = static_cast<std::int64_t>(d.state);
        item["state_name"] = state_names[static_cast<std::size_t>(d.state)];
        item["density"] = static_cast<std::int64_t>(d.density);
        Array rgba;
        for (const auto value : d.rgba) rgba.push_back(static_cast<std::int64_t>(value));
        item["rgba"] = rgba;
        item["movable"] = d.movable;
        item["current_rule_available"] = d.current_rule_available;
        item["kernel"] = static_cast<std::int64_t>(d.kernel);
        item["kernel_name"] = kernel_names[static_cast<std::size_t>(d.kernel)];
        item["initial_state_a"] = static_cast<std::int64_t>(d.initial_state_a);
        item["initial_state_b"] = static_cast<std::int64_t>(d.initial_state_b);
        item["maximum_write_radius"] = static_cast<std::int64_t>(d.maximum_write_radius);
        item["density_motion"] = static_cast<std::int64_t>(d.density_motion);
        item["density_motion_name"] = motion_names[static_cast<std::size_t>(d.density_motion)];
        item["accepts_density_exchange"] = d.accepts_density_exchange;
        item["lateral_flow"] = static_cast<std::int64_t>(d.lateral_flow);
        item["lateral_flow_name"] = flow_names[static_cast<std::size_t>(d.lateral_flow)];
        item["viscosity_index"] = static_cast<std::int64_t>(d.viscosity_index);
        item["hard_surface"] = cybersand::MaterialRules::is_hard_surface(material);
        item["granular_support"] = cybersand::MaterialRules::supports_granular_load(material);
        item["has_pair_reactions"] = cybersand::MaterialRules::has_pair_reactions(material);
        item["families"] = interaction_families(material);
        const auto visual = cybersand::kVisualStateSources[i];
        item["visual_state"] = static_cast<std::int64_t>(visual);
        item["visual_state_name"] = visual_names[static_cast<std::size_t>(visual)];
        Array down;
        Array up;
        for (std::size_t j = 0; j < definitions.size(); ++j) {
            const auto other = static_cast<cybersand::Material>(j);
            if (cybersand::MaterialRules::can_density_exchange(material, other, 1))
                down.push_back(static_cast<std::int64_t>(j));
            if (cybersand::MaterialRules::can_density_exchange(material, other, -1))
                up.push_back(static_cast<std::int64_t>(j));
        }
        item["density_exchange_down"] = down;
        item["density_exchange_up"] = up;
        materials.push_back(item);
    }
    out["materials"] = materials;
    out["allocated_slots"] = static_cast<std::int64_t>(definitions.size());
    return out;
}
