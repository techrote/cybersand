#!/usr/bin/env python3
"""Derive the LCB material x solver-family capability matrix from native source.

Standard-library only. Reads the checked-in material descriptor table and pair
rules; it never runs a solver. `current_default` cells execute unchanged;
source-qualified opt-in candidate variants are listed explicitly by
EXECUTABLE_CANDIDATES. Design classifications alone do not establish execution.

Usage:
  python tools/lcb/derive_capability_matrix.py            # rewrite the JSON
  python tools/lcb/derive_capability_matrix.py --check    # fail if stale
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MATERIAL_HPP = ROOT / "native/include/cybersand/material.hpp"
RULES_HPP = ROOT / "native/include/cybersand/interaction_rules.hpp"
OUTPUT = ROOT / "docs/reference/liquid-solver-capability-matrix.json"

FAMILIES = ("freemass_v1", "cellular_yield_v1", "pressure_flow_v1", "inertial_cellular_v1")
VARIANTS = {
    "freemass_v1": ["reference"],
    "cellular_yield_v1": ["reference"],
    "pressure_flow_v1": ["reference", "cached", "cached_dormant"],
    "inertial_cellular_v1": ["reference"],
}
LEGACY_ARMS = {
    "current": {"material": "water", "family": "freemass_v1", "variant": "reference"},
    "pressure": {"material": "water", "family": "pressure_flow_v1", "variant": "reference"},
    "pressure_cached": {"material": "water", "family": "pressure_flow_v1", "variant": "cached"},
    "pressure_dormant": {"material": "water", "family": "pressure_flow_v1", "variant": "cached_dormant"},
}
DEFAULT_FAMILY = {"FreeMass": "freemass_v1", "CellularYield": "cellular_yield_v1"}
# Kernel-owned behavior beyond generic CellularYield motion, from World::update_cell.
KERNEL_SPECIALIZATION = {
    "Water": "FreeMass pairwise mass transfer, coherent emission, adhesion (World::update_water)",
    "Oil": "ignition from hot neighbours, burn countdown in state_b, Water extinguishes, Fire emission",
    "Lava": "hot material; ignites/quenches through pair rules",
    "Acid": "corrosion/dissolution kernel",
    "Cement": "cure lifecycle toward Concrete on air/Water/Brine/Concrete contact",
    "MoltenGlass": "cooling lifecycle toward Glass",
    "YieldingLiquid": "generic heap-capable CellularYield motion (flow_as_yielding_liquid)",
}
# Candidate cells the running build compiles and qualifies, with the variants it
# executes (LCB-001 #200 and the unmerged native #201 candidate). This is
# executable source admission, not full application/platform acceptance.
EXECUTABLE_CANDIDATES = {
    ("water", "inertial_cellular_v1"): ["reference"],
    ("brine", "inertial_cellular_v1"): ["reference"],
    ("water", "pressure_flow_v1"): ["reference", "cached", "cached_dormant"],
    ("water", "cellular_yield_v1"): ["reference"],
}
# Gate C/D design classifications. Keys are descriptor names.
PROPOSED = {
    ("water", "cellular_yield_v1"): ("proposed_experimental",
        "LCB-001 #200 whole-cell Water reference executes with Water-specific viscosity material block v2; no fractional transfer or adhesion"),
    ("water", "pressure_flow_v1"): ("proposed_experimental",
        "LCB-001 #200 reference plus unmerged #201 cached/cached_dormant native candidates; full gas-repair, application and platform acceptance remain separate"),
    ("water", "inertial_cellular_v1"): ("proposed_experimental",
        "LCB-005 #212 native whole-cell Water adapter with coherence, body contact and actual-carrier transport hooks; full Gate D/application/platform qualification remains separate"),
    ("brine", "inertial_cellular_v1"): ("proposed_experimental",
        "first non-Water inertial candidate: generic YieldingLiquid kernel; aqueous pair rules need #212 qualification"),
    ("toxic-sludge", "inertial_cellular_v1"): ("proposed_alternate",
        "documented fallback inertial candidate if Brine fails qualification: generic YieldingLiquid kernel"),
}


def source_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def parse_materials(text: str) -> list[dict]:
    enum = text[text.index("enum class Material : std::uint8_t {"):]
    enum = enum[:enum.index("};")]
    ids = {int(v): n for n, v in re.findall(r"^\s*([A-Z]\w*)\s*=\s*(\d+),", enum, re.M)}
    table = text[text.index("kMaterialDefinitions{{"):]
    row = re.compile(
        r'\{"([^"]+)",\s*MaterialState::(\w+),\s*([\d\']+),\s*\{[^}]*\},\s*(\w+),\s*(\w+),\s*(\w+),'
        r'\s*RuleKernel::(\w+),\s*([^,]+),\s*([^,]+),\s*(\d+),\s*DensityMotion::(\w+),\s*(\w+),'
        r'\s*LateralFlowMode::(\w+),\s*(\d+)\}', re.S)
    result = []
    for index, m in enumerate(row.finditer(table)):
        result.append({
            "id": index, "enum": ids.get(index), "name": m.group(1), "state": m.group(2),
            "density": int(m.group(3).replace("'", "")), "movable": m.group(4) == "true",
            "valid": m.group(5) == "true", "kernel": m.group(7),
            "initial_state_a": m.group(8).strip(), "density_motion": m.group(11),
            "accepts_density_exchange": m.group(12) == "true", "lateral_flow": m.group(13),
            "viscosity_index": int(m.group(14)),
        })
    return result


def parse_pair_rules(text: str) -> list[dict]:
    rows = re.findall(r'\{"(int\.pair\.[^"]+)",.*?Material::(\w+),\s*Material::(\w+),\s*'
                      r'Material::(\w+),\s*Material::(\w+),\s*(\d+),', text, re.S)
    return [{"id": r[0], "reactants": [r[1], r[2]], "products": [r[3], r[4]],
             "probability": int(r[5])} for r in rows]


def family_cell(material: dict, family: str) -> dict:
    default = DEFAULT_FAMILY.get(material["lateral_flow"])
    if family == default:
        return {"status": "current_default", "executable_today": True, "selectable": True,
                "variants": ["reference"], "classification": "source fact (LateralFlowMode)",
                "note": "unchanged production behavior; protected control"}
    key = (material["name"], family)
    if key in PROPOSED:
        status, note = PROPOSED[key]
        cell = {"status": status, "executable_today": key in EXECUTABLE_CANDIDATES,
                "selectable": status == "proposed_experimental",
                "variants": VARIANTS[family] if status == "proposed_experimental" else [],
                "classification": "reviewed design classification (PROPOSED table)", "note": note}
        if key in EXECUTABLE_CANDIDATES:
            cell["executable_variants"] = EXECUTABLE_CANDIDATES[key]
        return cell
    reasons = {
        "freemass_v1": "FreeMass is the Water kernel's fractional solver; #15 selected no FreeMass conversion for other liquids",
        "cellular_yield_v1": "not applicable",
        "pressure_flow_v1": "pressure_flow_v1 v1 scope is Water only (corrected 7ef2aac candidate)",
        "inertial_cellular_v1": "not proposed for v1; kernel specialization or chemistry not qualified by #212",
    }
    return {"status": "rejected", "executable_today": False, "selectable": False, "variants": [],
            "classification": "reviewed design classification (default rejection)", "note": reasons[family]}


def build() -> dict:
    materials = parse_materials(MATERIAL_HPP.read_text(encoding="utf-8"))
    rules = parse_pair_rules(RULES_HPP.read_text(encoding="utf-8"))
    liquids = [m for m in materials if m["valid"] and (m["state"] == "Liquid" or m["lateral_flow"] != "None")]
    rows = []
    for m in liquids:
        reactions = [r["id"] for r in rules if m["enum"] in r["reactants"]]
        produced_by = [r["id"] for r in rules if m["enum"] in r["products"] and m["enum"] not in r["reactants"]]
        rows.append({
            "material_id": m["id"], "enum": m["enum"], "name": m["name"], "density": m["density"],
            "kernel": m["kernel"], "lateral_flow": m["lateral_flow"],
            "viscosity_index": m["viscosity_index"], "density_motion": m["density_motion"],
            "accepts_density_exchange": m["accepts_density_exchange"],
            "kernel_specialization": KERNEL_SPECIALIZATION.get(m["kernel"], m["kernel"] + " kernel"),
            "provenance": {
                "source_facts": ["material_id", "enum", "name", "density", "kernel", "lateral_flow",
                                 "viscosity_index", "density_motion", "accepts_density_exchange",
                                 "pair_reactions_as_reactant", "pair_reactions_producing"],
                "reviewed_design": ["kernel_specialization", "families"]},
            "mercury_viscosity_diagnostic_override": m["enum"] == "Mercury",
            "pair_reactions_as_reactant": reactions, "pair_reactions_producing": produced_by,
            "current_default_family": DEFAULT_FAMILY[m["lateral_flow"]],
            "families": {f: family_cell(m, f) for f in FAMILIES},
        })
    non_liquid = [m["name"] for m in materials if m["valid"] and m not in liquids]
    return {
        "schema": "lcb-liquid-capability-matrix-v1",
        "status": "LCB-000 Gate C classifications with source-qualified execution. Descriptor fields are parsed source facts; family statuses, variants and kernel_specialization text remain reviewed design classifications. Current defaults execute unchanged; executable_today and executable_variants identify qualified opt-in candidates.",
        "sources": {
            "native/include/cybersand/material.hpp": source_digest(MATERIAL_HPP),
            "native/include/cybersand/interaction_rules.hpp": source_digest(RULES_HPP),
        },
        "families": {f: {"variants": VARIANTS[f]} for f in FAMILIES},
        "legacy_arms": LEGACY_ARMS,
        "status_vocabulary": {
            "current_default": "executes today as the unchanged production default",
            "proposed_experimental": "Gate C/D design classification; only explicitly qualified executable_today/executable_variants run, all other variants must be refused",
            "proposed_alternate": "documented substitute candidate; NOT selectable (refused as not_selectable) until its owner qualifies it",
            "rejected": "construction must refuse this mapping before replacing any session",
        },
        "material_descriptor_count": len(materials),
        "liquid_rows": rows,
        "non_liquid_policy": {
            "status": "rejected",
            "note": "family assignment applies to liquid descriptors only; any assignment for these materials is refused",
            "count": len(non_liquid),
        },
    }


def render(data: dict) -> str:
    return json.dumps(data, indent=2, sort_keys=False) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = render(build())
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8").replace("\r\n", "\n") if OUTPUT.exists() else ""
        if current != text:
            print(f"stale: {OUTPUT.relative_to(ROOT)}; rerun without --check", file=sys.stderr)
            return 1
        print("capability matrix matches source")
        return 0
    OUTPUT.write_bytes(text.encode("utf-8"))
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
