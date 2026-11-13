// Included in CyberDemoBridge's public section. These cold, read-only boundaries
// copy compiled descriptors and exclusive-owner values. They do not construct
// or mutate a World, replace material authority, or run on a pool worker.
[[nodiscard]] Dictionary inspect_material_lab_cell(
    const Ref<CyberNativeCellWorld>& adapter, Vector2i point) const {
    if (adapter.is_null() || !adapter->world_)
        return cyber_observation::rejected("Native world unavailable");
    const auto& world = *adapter->world_;
    auto out = cyber_observation::cell(world, point);
    if (!static_cast<bool>(out.get("ok", false))) return out;
    const auto material = world.stored_material(point.x, point.y);
    const auto& descriptor = cybersand::MaterialRules::descriptor(material);
    out["schema_id"] = "cybersand.material-lab.cell";
    out["schema_version"] = 1;
    out["read_only"] = true;
    out["material_name"] = interaction_string(descriptor.name);
    out["kernel"] = static_cast<std::int64_t>(descriptor.kernel);
    out["current_rule_available"] = descriptor.current_rule_available;
    out["has_pair_reactions"] = cybersand::MaterialRules::has_pair_reactions(material);
    out["visible_material"] = static_cast<std::int64_t>(world.get(point.x, point.y));
    // This newer owner API exposes the real thermal storage even under a mask.
    // Preserve inspect_cell's established masked-temperature contract above.
    out["stored_temperature_raw"] = world.stored_temperature(point.x, point.y);
    out["stored_temperature_available"] = true;

    const cybersand::SchedulerGeometry geometry(world.config().scheduling_core_size,
                                                world.config().maximum_rule_radius);
    const auto core = geometry.core_for_cell(point.x, point.y);
    const auto contains = [core](const std::optional<cybersand::SimulationCoreRange>& range) {
        return !range || (core.x >= range->min_x && core.x <= range->max_x &&
                          core.y >= range->min_y && core.y <= range->max_y);
    };
    const auto encode_range = [](const std::optional<cybersand::SimulationCoreRange>& range) -> Variant {
        if (!range) return Variant();
        Array values;
        values.append(range->min_x); values.append(range->min_y);
        values.append(range->max_x); values.append(range->max_y);
        return values;
    };
    Array coordinate;
    coordinate.append(core.x); coordinate.append(core.y);
    Dictionary scheduler;
    scheduler["backend"] = static_cast<std::int64_t>(world.backend());
    scheduler["core_size"] = world.config().scheduling_core_size;
    scheduler["core_coordinate"] = coordinate;
    scheduler["phase"] = geometry.phase(core);
    scheduler["selected_core_range"] = encode_range(world.selected_simulation_cores());
    scheduler["selected_core_included"] = contains(world.selected_simulation_cores());
    scheduler["last_applied_core_range"] = encode_range(world.applied_simulation_cores());
    scheduler["last_applied_core_included"] = world.completed_tick_index() == 0U
        ? Variant() : Variant(contains(world.applied_simulation_cores()));
    scheduler["range_encoding"] = "inclusive min_core_x,min_core_y,max_core_x,max_core_y; null range is unrestricted";
    scheduler["scope"] = "Selected source-core window and preceding completed-tick applied window, not task dispatch or per-cell activity. Neighbour reads/writes may reach the source core halo.";
    out["scheduler"] = scheduler;
    if (const auto region = world.simulation_region()) {
        Array values;
        values.append(region->x); values.append(region->y);
        values.append(region->width); values.append(region->height);
        out["selected_region"] = values;
    } else {
        out["selected_region"] = Variant();
    }
    Array unobserved;
    unobserved.append("per-cell sleeping status");
    unobserved.append("activity-block active flag and future wake deadline");
    unobserved.append("cell epoch and actual task dispatch");
    unobserved.append("contact temporal lane and actual random byte");
    unobserved.append("earlier neighbour or specialised mechanism competition");
    out["unobserved"] = unobserved;
    out["scope"] = "Copied native stored/visible values and core-window facts, read between ticks by the exclusive owner. No reaction execution or next-tick eligibility guarantee.";
    return out;
}

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
