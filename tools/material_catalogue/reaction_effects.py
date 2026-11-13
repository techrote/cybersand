#!/usr/bin/env python3
"""Explicit endpoint effects for external Materials Lab Worlds only.

Production catalogue, resolver, World and quantity codec remain unchanged.
The generated fixed-size table is consumed only by a source-bound adapter in
an external World copy; there is no runtime metadata parsing or allocation.
"""
from __future__ import annotations

HEADER_NAME = "lab-reaction-effects.hpp"
STATE_B_KERNELS = {6: "Combustible burn countdown", 22: "Metal charge countdown"}
EFFECT_KINDS = ("replace_with_defaults", "keep_existing", "set_state")


def validate_rule(rule: dict, native: dict, pointer: str) -> None:
    """Validate endpoint semantics after the caller validates sparse identity."""
    import lab
    at = pointer + "/effects"
    effects = lab.fields(rule["effects"], ("version", "first", "second"), at)
    version = effects["version"]
    if type(version) is not int or version not in (1, 2):
        lab.fail(at + "/version", "expected endpoint-effects version 1 or 2")
    for endpoint in ("first", "second"):
        path = at + "/" + endpoint
        effect = effects[endpoint]
        if type(effect) is not dict or effect.get("kind") not in EFFECT_KINDS:
            lab.fail(path + "/kind", "choose replace_with_defaults, keep_existing, or supported set_state")
        kind = effect["kind"]
        lab.fields(effect, ("kind", "state_b") if kind == "set_state" else ("kind",), path)
        if kind == "replace_with_defaults":
            continue
        if version != 2:
            lab.fail(path + "/kind", "keep_existing and set_state require explicit endpoint-effects version 2; version 1 retains legacy replacement")
        if rule["match"] == 2:
            lab.fail(pointer + "/match", "non-replacement effects require Ordered or Unordered role-preserving matching; positional Symmetric effects are not admitted")
        participant = lab.integer(rule[endpoint], 1, 131, pointer + "/" + endpoint)
        if participant == 3:
            lab.fail(path, "Water retention/state effects require a separate quantity and family-state contract; keep the Water endpoint replace_with_defaults")
        if not native["materials"][participant]["valid"]:
            lab.fail(path, "reserved invalid identities cannot retain or set state")
        if rule[endpoint + "_product"] != participant:
            lab.fail(pointer + "/" + endpoint + "_product", "keep_existing/set_state retain this participant's identity; set its product to the same input material")
        if kind == "set_state":
            kernel = native["materials"][participant]["kernel"]
            if kernel not in STATE_B_KERNELS:
                lab.fail(path + "/state_b", "state_b setting is admitted only for the Metal charge or Combustible burn countdown; this template has no supported register contract")
            lab.integer(effect["state_b"], 0, 255, path + "/state_b")
    if all(effects[endpoint]["kind"] == "keep_existing" for endpoint in ("first", "second")):
        lab.fail(at, "both endpoints keep_existing is a selected no-op; retain at least one replacement or supported state update")


def has_extended(candidate: dict) -> bool:
    return any(rule["effects"][endpoint]["kind"] != "replace_with_defaults"
               for rule in candidate["reactions"] for endpoint in ("first", "second"))


def describe(rule: dict, native: dict) -> str:
    parts = []
    for endpoint in ("first", "second"):
        effect = rule["effects"][endpoint]
        material = native["materials"][rule[endpoint]]["name"]
        product = native["materials"][rule[endpoint + "_product"]]["name"]
        if effect["kind"] == "replace_with_defaults":
            parts.append(f"{endpoint}: replace {material} with {product} using legacy defaults")
        elif effect["kind"] == "keep_existing":
            parts.append(f"{endpoint}: retain {material}, state_a, state_b and temperature")
        else:
            parts.append(f"{endpoint}: retain {material}/state_a/temperature; set state_b={effect['state_b']}")
    return (f"candidate effects v{rule['effects']['version']}: " + "; ".join(parts) +
            "; extended endpoints are non-Water, marked processed and use existing future-contact wake scheduling; "
            "external compiled World tests only, not production activation")


def header(candidate: dict, native: dict) -> bytes:
    """Generate a fixed-size table from validated sparse edits."""
    import lab
    slots = len(native["interactions"]["pairs"])
    if slots != 56:
        lab.fail("/effects", "the external effects adapter requires the reviewed 56 sparse slots")
    rows = ["    Pair{{Kind::ReplaceWithDefaults, 0}, {Kind::ReplaceWithDefaults, 0}}" for _ in range(slots)]
    kinds = {"replace_with_defaults": "ReplaceWithDefaults", "keep_existing": "KeepExisting", "set_state": "SetStateB"}
    seen = set()
    for index, rule in enumerate(candidate["reactions"]):
        at = f"/reactions/{index}"
        slot = lab.integer(rule["slot"], 0, slots - 1, at + "/slot")
        if slot in seen:
            lab.fail(at + "/slot", "duplicate effect slot")
        seen.add(slot)
        validate_rule(rule, native, at)
        values = []
        for endpoint in ("first", "second"):
            effect = rule["effects"][endpoint]
            values.append("{Kind::" + kinds[effect["kind"]] + ", " + str(effect.get("state_b", 0)) + "}")
        rows[slot] = "    Pair{" + ", ".join(values) + "}"
    return ("""// EXTERNAL MATERIALS LAB WORLD ONLY. No production consumer.
#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
namespace cybersand::material_lab_effects {
enum class Kind : std::uint8_t { ReplaceWithDefaults, KeepExisting, SetStateB };
struct Endpoint { Kind kind; std::uint8_t state_b; };
struct Pair { Endpoint first; Endpoint second; };
inline constexpr unsigned kEffectsVersion = 2;
inline constexpr std::array<Pair, 56> kPairs{{
""" + ",\n".join(rows) + """
}};
[[nodiscard]] constexpr bool is_extended(std::size_t slot) noexcept {
    return slot < kPairs.size() &&
        (kPairs[slot].first.kind != Kind::ReplaceWithDefaults ||
         kPairs[slot].second.kind != Kind::ReplaceWithDefaults);
}
} // namespace cybersand::material_lab_effects
""").encode("utf-8")


# The entire exact block is matched; changed native code requires source review.
LEGACY_APPLICATION = """            const auto& source_definition =
                MaterialRules::descriptor(reaction->source_product);
            const auto& target_definition =
                MaterialRules::descriptor(reaction->target_product);
            const auto source_state_a = reaction->source_product == Material::Water
                ? config_.water_experiment_policy.maximum()
                : static_cast<std::uint16_t>(source_definition.initial_state_a);
            const auto target_state_a = reaction->target_product == Material::Water
                ? config_.water_experiment_policy.maximum()
                : static_cast<std::uint16_t>(target_definition.initial_state_a);
            bool changed = write_cell(
                target_x, target_y, reaction->target_product,
                target_state_a, target_definition.initial_state_b,
                effects, false, true, {QuantityKind::PairReaction, reaction->rule_index});
            changed = write_cell(
                          x, y, reaction->source_product,
                          source_state_a,
                          source_definition.initial_state_b, effects, false, true,
                          {QuantityKind::PairReaction, reaction->rule_index}) ||
                      changed;
            record_quantity_pair_event(reaction->rule_index, effects);
            return changed;"""

EXTENDED_APPLICATION = """            // EXTERNAL MATERIALS LAB ONLY: admitted non-Water effects-v2.
            if (material_lab_effects::is_extended(reaction->rule_index)) {
                using material_lab_effects::Kind;
                const auto& pair = material_lab_effects::kPairs[reaction->rule_index];
                const auto& rule = InteractionRules::pair_rules()[reaction->rule_index];
                const bool reversed = !(material == rule.first && target == rule.second);
                const auto source_effect = reversed ? pair.second : pair.first;
                const auto target_effect = reversed ? pair.first : pair.second;
                const auto apply_endpoint = [&](std::int64_t px, std::int64_t py,
                    Material input, Material product, material_lab_effects::Endpoint endpoint) {
                    if (endpoint.kind != Kind::ReplaceWithDefaults) {
                        if (input == Material::Water || input != product ||
                            transient_obstacle_at(px, py) != 0U || stored_material(px, py) != input)
                            throw std::logic_error("unadmitted isolated endpoint-effect owner/state");
                        if (endpoint.kind == Kind::KeepExisting) return false;
                        // Internal state mutation retains temperature and family state.
                        return write_cell(px, py, input, state_a(px, py), endpoint.state_b,
                            effects, false, false, {QuantityKind::PairReaction, reaction->rule_index});
                    }
                    const auto& definition = MaterialRules::descriptor(product);
                    const auto initial_a = product == Material::Water
                        ? config_.water_experiment_policy.maximum()
                        : static_cast<std::uint16_t>(definition.initial_state_a);
                    return write_cell(px, py, product, initial_a, definition.initial_state_b,
                        effects, false, true, {QuantityKind::PairReaction, reaction->rule_index});
                };
                // Preserve native target-before-source endpoint ordering.
                bool changed = apply_endpoint(target_x, target_y, target,
                    reaction->target_product, target_effect);
                changed = apply_endpoint(x, y, material, reaction->source_product,
                    source_effect) || changed;
                const auto retain_participant = [&](std::int64_t px, std::int64_t py,
                    Material input, material_lab_effects::Endpoint endpoint) {
                    if (endpoint.kind == Kind::ReplaceWithDefaults) return;
                    const auto at = address(px, py);
                    auto* owner = find_chunk(at.chunk);
                    if (owner == nullptr || owner->cells[at.index].material_value() != input)
                        throw std::logic_error("isolated endpoint retention lost its native owner");
                    // Retention is not replacement. Stamp only the ordinary processed
                    // epoch so this cell cannot initiate another update in this tick.
                    // As in production, other sources may select a stamped neighbour.
                    owner->cells[at.index].set_epoch(update_epoch_);
                    const KernelReadCursor retained_cursor{*this, owner, at, px, py};
                    schedule_pending_reaction_wake(input, px, py, effects, retained_cursor);
                };
                retain_participant(target_x, target_y, target, target_effect);
                retain_participant(x, y, material, source_effect);
                record_quantity_pair_event(reaction->rule_index, effects);
                return changed;
            }
"""


def stage_world(source_text: str) -> str:
    """Insert effects into an external source copy with exact source anchors."""
    import lab
    include = '#include "cybersand/world.hpp"'
    newline = "\r\n" if "\r\n" in source_text else "\n"
    legacy = LEGACY_APPLICATION.replace("\n", newline)
    extended = EXTENDED_APPLICATION.replace("\n", newline)
    if source_text.count(include) != 1 or source_text.count(legacy) != 1:
        lab.fail("/stage/native/src/world.cpp", "native pair application changed; endpoint-effects staging requires source review")
    return source_text.replace(include, include + newline + '#include "' + HEADER_NAME + '"', 1).replace(
        legacy, extended + legacy, 1)
