// Cold-path semantic assertions for the external candidate World test backend.
// This uses the same native World, state API and physical-state codec as the bay.
#pragma once
#include "lab-reaction-effects.hpp"
#include "cybersand/world.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/material_rules.hpp"
#include <sstream>
#include <stdexcept>
#include <string>

namespace cybersand::material_lab_effects_probe {
inline void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}

// These are deliberately named and bounded semantic fixtures. Unrelated edited
// pairs still execute in the primary bay; absence of a focused fixture is
// reported as not_applicable rather than fabricated as coverage of that effect.
inline std::string verify() {
    using material_lab_effects::Kind;
    std::ostringstream output;
    output << "{\"backend\":\"native_world_endpoint_contract_v2\",\"cases\":[";
    unsigned cases = 0;
    for (const auto slot : {2U, 9U}) {
        const auto& rule = kPairInteractionRules[slot];
        const auto& effect = material_lab_effects::kPairs[slot];
        const bool salt = slot == 2U && rule.first == Material::Water && rule.second == Material::Salt &&
            rule.first_product == Material::Brine && rule.second_product == Material::Salt &&
            effect.first.kind == Kind::ReplaceWithDefaults && effect.second.kind == Kind::KeepExisting;
        const bool retained_first = slot == 9U && effect.first.kind == Kind::SetStateB;
        const auto retained_material = retained_first ? rule.first : rule.second;
        const auto replaced_material = retained_first ? rule.second : rule.first;
        const auto retained_product = retained_first ? rule.first_product : rule.second_product;
        const auto replaced_product = retained_first ? rule.second_product : rule.first_product;
        const auto retained_effect = retained_first ? effect.first : effect.second;
        const auto replaced_effect = retained_first ? effect.second : effect.first;
        const auto retained_kernel = MaterialRules::descriptor(retained_material).kernel;
        const bool counter = slot == 9U && replaced_material == Material::Acid &&
            replaced_product == Material::Smoke && retained_product == retained_material &&
            (retained_kernel == RuleKernel::Metal || retained_kernel == RuleKernel::Combustible) &&
            replaced_effect.kind == Kind::ReplaceWithDefaults && retained_effect.kind == Kind::SetStateB;
        const bool no_op = slot == 9U && rule.first == Material::Sand && rule.second == Material::Metal &&
            rule.first_product == Material::Sand && rule.second_product == Material::Metal &&
            effect.first.kind == Kind::KeepExisting && effect.second.kind == Kind::SetStateB && effect.second.state_b == 0U;
        if ((!salt && !counter && !no_op) || rule.probability != 255U ||
            rule.match == InteractionMatchKind::Symmetric ||
            (retained_first && rule.match == InteractionMatchKind::Ordered)) continue;
        for (unsigned layout = 0; layout < 2; ++layout) {
            WorldConfig config;
            config.worker_threads = 1;
            config.initial_chunk_reserve = 8;
            config.maximum_chunk_count = 8;
            World world(config);
            // Counter fixtures make contact on tick1, before Acid's separate
            // lifecycle corrosion can consume the target on a non-contact tick.
            const std::int64_t y = counter ? 66 : 65;
            const std::int64_t left = counter ? 68 : 65;
            const std::int64_t first_x = layout == 0U ? left : left + 1;
            const std::int64_t retained_x = layout == 0U ? left + 1 : left;
            world.reserve_region({left - 1, y - 1, 4, 3});
            for (std::int64_t py = y - 1; py <= y + 1; ++py)
                for (std::int64_t px = left - 1; px <= left + 2; ++px)
                    world.set(px, py, Material::Wall);
            world.set(first_x, y, replaced_material);
            world.set(retained_x, y, retained_material);
            if (salt) require(world.set_cell_state(first_x, y, Material::Water, 83, 0),
                "Effects fixture could not create partial native Water");
            if (no_op) {
                require(world.set_cell_state(first_x, y, Material::Sand, 81, 77), "No-op fixture Sand state setup failed");
                world.set_temperature(first_x, y, 314);
            }
            require(world.set_cell_state(retained_x, y, retained_material, 173, salt ? 91 : 0),
                "Effects fixture could not seed non-default retained state");
            world.set_temperature(retained_x, y, 371);
            unsigned ticks = 0;
            while (world.quantity_ledger().pair_events[slot] == 0U && ticks < 16U) {
                (void)world.tick();
                ++ticks;
            }
            require(!world.has_failed(), "Endpoint fixture native World failed");
            const auto ledger = world.quantity_ledger();
            require(ledger.pair_events[slot] == 1U, "Endpoint fixture did not execute exactly one selected pair");
            require(world.stored_material(retained_x, y) == retained_material &&
                world.stored_material(first_x, y) == replaced_product,
                "Endpoint fixture lost participant identity or legacy replacement product");
            require(world.stored_state_a(retained_x, y) == 173U,
                "Extended effect replaced retained state_a with descriptor defaults");
            const auto expected_b = salt ? 91U : static_cast<unsigned>(retained_effect.state_b);
            require(world.stored_state_b(retained_x, y) == expected_b,
                "Extended effect lost state_b or permitted a second same-tick source update");
            require(world.stored_temperature(retained_x, y) == 371,
                "Extended effect changed retained native temperature");
            require(ledger.pair_rules[slot].produced == 0U &&
                ledger.pair_rules[slot].consumed == (salt ? 83U : 0U),
                "Endpoint effect did not preserve native per-rule quantity accounting");
            const auto bytes = world.save_physical_state();
            const auto restored = World::restore_physical_state(config, bytes);
            require(restored->physical_state_hash() == world.physical_state_hash() &&
                restored->quantity_ledger() == ledger &&
                restored->stored_state_a(retained_x, y) == 173U &&
                restored->stored_state_b(retained_x, y) == expected_b &&
                restored->stored_temperature(retained_x, y) == 371,
                "Extended endpoint state failed same-build native persistence");
            // Salt's two coordinates share lane phase2. At tick2 row65 scans
            // right-to-left, so x66 initiates. Swapping layout therefore exercises
            // both native source orientations for role-preserving matching.
            if (salt) require(ticks == 2U, "Salt orientation fixture's reviewed lane/scan premise changed");
            if (counter) require(ticks == 1U, "Counter fixture must select its pair before specialised Acid corrosion");
            unsigned after_b = expected_b, zero_visited_ticks = 0;
            std::uint64_t later_moves = 0;
            if (counter && expected_b > 0U) {
                for (unsigned step = 0; step < 4; ++step) (void)world.tick();
                after_b = world.stored_state_b(retained_x, y);
                const auto after_material = world.stored_material(retained_x, y);
                require(after_b < expected_b &&
                    (after_material == retained_material ||
                     (retained_kernel == RuleKernel::Combustible && expected_b <= 2U && after_material == Material::Empty)),
                    "Authored state_b did not reach its real charge/burn countdown consumer");
            }
            if (no_op) {
                while (world.completed_tick_index() < 20U) {
                    const auto stats = world.tick();
                    zero_visited_ticks += stats.visited_cells == 0U;
                    later_moves += stats.moved_cells;
                }
                require(later_moves == 0U && zero_visited_ticks > 0U && world.quantity_ledger().pair_events[slot] >= 4U,
                    "Selected no-value-change effect lost bounded sleep/wake cadence or reported fake motion");
                require(world.stored_material(first_x, y) == Material::Sand &&
                    world.stored_state_a(first_x, y) == 81U && world.stored_state_b(first_x, y) == 77U &&
                    world.stored_temperature(first_x, y) == 314 && world.stored_state_b(retained_x, y) == 0U,
                    "Selected no-value-change effect changed preserved values");
            }
            if (cases++) output << ',';
            output << "{\"name\":\"" << (salt ? "salt_retains_registers_and_temperature" :
                    (no_op ? "selected_no_value_change_preserves_bounded_wakes" :
                     (retained_kernel == RuleKernel::Metal ? "metal_sets_declared_charge_register" : "combustible_sets_declared_burn_register")))
                << "\",\"slot\":" << slot << ",\"layout\":" << layout << ",\"ticks_to_reaction\":" << ticks
                << ",\"retained_material\":" << static_cast<unsigned>(retained_material)
                << ",\"source_role\":\"" << (salt && rule.match != InteractionMatchKind::Ordered ?
                    (layout == 0U ? "second" : "first") : (retained_first ? "second" : "first")) << '"'
                << ",\"state_a\":173,\"state_b\":" << expected_b << ",\"temperature\":371"
                << ",\"state_b_after_four_ticks\":" << after_b
                << ",\"no_value_change\":" << (no_op ? "true" : "false")
                << ",\"zero_visited_ticks\":" << zero_visited_ticks << ",\"later_moved_cells\":" << later_moves
                << ",\"future_pair_events\":" << world.quantity_ledger().pair_events[slot]
                << ",\"pair_events\":1,\"water_produced\":0,\"water_consumed\":" << ledger.pair_rules[slot].consumed
                << ",\"same_build_persistence\":true}";
        }
    }
    output << "],\"case_count\":" << cases << ",\"status\":\"" << (cases ? "passed" : "not_applicable")
        << "\",\"boundary\":\"Named isolated endpoint fixtures; primary bay separately exercises the authored pair configuration\"}";
    return output.str();
}
} // namespace cybersand::material_lab_effects_probe
