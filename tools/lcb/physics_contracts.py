#!/usr/bin/env python3
"""LCB physics acceptance contracts and their fixtures (LCB physics prepass).

Standard-library only. Writes:
  godot/tests/fixtures/lcb/acceptance/*.json         MicroScenario schema-2 fixtures
  godot/tests/fixtures/lcb/lcb-physics-contracts.json contract registry (read by
                                                      test_lcb_physics_contracts.gd)

Contracts reference catalogue scenarios by ID where one already exists (PR #217
IDs and goldens are reused, never regenerated). Every candidate-family arm is
BLOCKED until #200/#212/#201 provide it; thresholds below are frozen before any
candidate execution. Current-family values are characterization, not acceptance.

Usage:
  python tools/lcb/physics_contracts.py          # write
  python tools/lcb/physics_contracts.py --check  # fail if stale
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import scenario_catalogue as cat  # noqa: E402

OUT = ROOT / "godot/tests/fixtures/lcb/acceptance"
CONTRACTS = ROOT / "godot/tests/fixtures/lcb/lcb-physics-contracts.json"
WALL, WATER, OIL = cat.WALL, cat.WATER, cat.OIL

PF = {"family": "pressure_flow_v1", "depends_on": ["#213 LCB-000 PASS", "#200"]}
PF_DORMANT = {"family": "pressure_flow_v1/cached_dormant", "depends_on": ["#213 LCB-000 PASS", "#200", "#201"]}
IN = {"family": "inertial_cellular_v1", "depends_on": ["#200 per-material policy", "#212"]}
CY = {"family": "cellular_yield_v1 (Water, whole-cell)", "depends_on": ["#213 LCB-000 PASS", "#200"]}


def room(s: cat.Scenario, x0: int, interior_w: int = 10) -> None:
    """#200 reproducer room: walls x0..x0+w+1, y 8..20; Water floor y=19; air y 9..18."""
    right = x0 + interior_w + 1
    s.rect(x0, 8, interior_w + 2, 1, WALL).rect(x0, 20, interior_w + 2, 1, WALL)
    s.rect(x0, 8, 1, 13, WALL).rect(right, 8, 1, 13, WALL)
    s.fill(x0 + 1, 19, interior_w, 1)


def gas_fixture(sid, title, purpose, horizon, build):
    s = cat.Scenario(sid, "gas-acceptance", title, purpose, horizon, (0, 0, 64, 32),
                     {"free_play": False, "note": "controlled gas apparatus; Current has no gas state"})
    build(s)
    s.overview = [0, 0, 64, 32]
    return s


def fixtures() -> list[cat.Scenario]:
    out = []

    def single(s):
        room(s, 8)
        s.observe("water-t0", 0, (8, 8, 12, 13)).observe("water-t10", 10, (8, 8, 12, 13))
        s.region("pocket", "Sealed 10x10 pocket", (9, 9, 10, 10))
    out.append(gas_fixture("lcb.accept.gas.single-pocket.v1", "Sealed 10x10 air pocket",
        "#200 reproducer: one sealed 10x10 pocket over a Water floor. W-PF must keep gas amount 100 and pocket "
        "identity constant for every tick (control).", 10, single))

    def twin(s):
        room(s, 8)
        room(s, 32)
        for x in (8, 32):
            s.observe(f"water-{x}-t0", 0, (x, 8, 12, 13)).observe(f"water-{x}-t10", 10, (x, 8, 12, 13))
        s.region("pocket-a", "Pocket A", (9, 9, 10, 10)).region("pocket-b", "Pocket B", (33, 9, 10, 10))
    out.append(gas_fixture("lcb.accept.gas.twin-pockets.v1", "Two independent sealed pockets",
        "#200 reproducer: two identical independent pockets. The archived candidate cycled each amount "
        "100,50,25,12,6,3,1,100; W-PF must hold each at 100 with distinct stable identities.", 10, twin))

    def merge(s):
        room(s, 8)
        s.rect(19, 8, 14, 1, WALL).rect(19, 20, 14, 1, WALL).rect(32, 8, 1, 13, WALL)
        s.fill(20, 19, 12, 1)
        s.event(1, "erase", 19, 13, 1, 1)
        s.observe("water-t0", 0, (8, 8, 25, 13)).observe("water-t10", 10, (8, 8, 25, 13))
        s.region("pocket-a", "100-cell pocket", (9, 9, 10, 10)).region("pocket-b", "120-cell pocket", (20, 9, 12, 10))
        s.region("opening", "Opening at (19,13)", (19, 13, 1, 1))
    out.append(gas_fixture("lcb.accept.gas.unequal-merge.v1", "Unequal pocket merge",
        "#200 reproducer: 100- and 120-cell pockets share wall x=19; the wall cell (19,13) opens at tick 1. "
        "The archived candidate kept 120; W-PF must merge the amounts once to 220.", 10, merge))

    def vent(s):
        room(s, 8)
        s.event(1, "fill", 9, 14, 10, 5, 255, 0)
        s.event(5, "erase", 13, 8, 1, 1)
        s.event(9, "fill", 13, 8, 1, 1, 255, 0)
        s.observe("water-t0", 0, (8, 8, 12, 13)).observe("water-t12", 12, (8, 8, 12, 13))
        s.region("pocket", "Pocket", (9, 9, 10, 10)).region("vent", "Vent at (13,8)", (13, 8, 1, 1))
    out.append(gas_fixture("lcb.accept.gas.compress-vent-reseal.v1", "Compress, vent and reseal",
        "#200 reproducer: Water fills half the pocket at tick 1 (compression, amount stays 100), a roof cell opens "
        "at tick 5 (vent to atmosphere), and a Water plug reseals it at tick 9. The archived candidate kept 100; "
        "W-PF must reseal with the current volume's atmospheric amount and an explicit exchange ledger.", 12, vent))

    s = cat.Scenario("lcb.accept.dormant-water-active-oil.v1", "dormancy", "Resting deep Water beside falling Oil",
        "A full deep Water pool rests behind a divider while an Oil block is released at tick 120 in the next "
        "compartment. Current control: the pool sleeps and the Oil still moves. W-PF cached_dormant must never "
        "suppress the Oil motion or chemistry (#201, NC-4).", 600, (16, 16, 992, 272),
        {"free_play": True, "note": "disturb either side"})
    for r in cat.TANK.values():
        s.rect(*r, WALL)
    s.rect(480, 64, 8, 192, WALL).fill(40, 96, 440, 160)
    s.rect(600, 64, 64, 64, OIL).rect(600, 128, 64, 4, WALL)
    s.event(120, "erase", 600, 128, 64, 4)
    pool, right = (40, 64, 440, 192), (488, 64, 496, 192)
    s.observe("pool-t0", 0, pool).observe("pool-t600", 600, pool)
    s.observe("oil-t0", 0, right, OIL).observe("oil-low-t600", 600, (488, 224, 496, 32), OIL)
    s.observe("oil-t600", 600, right, OIL)
    s.condition("pool-t600", "eq", 440 * 160 * 255, "complete")
    s.region("pool", "Resting pool", pool).region("oil", "Oil block", (600, 64, 64, 64))
    s.overview = [32, 64, 960, 200]
    out.append(s)
    return out


SURGE = {
    "metric_definitions": {
        "front_distance": "rightmost Water cell on the floor row y=255 minus the gate face x=240, at the tick",
        "retained_fraction": "Water integer in the reservoir region [40,64,192,192] / initial Water integer",
        "depth_response": "front_distance(depth-160) / front_distance(depth-48) at the same tick",
        "centroid_x": "mass-weighted mean column of all Water inside the container (per-column water_integer)",
    },
    "current_characterization_2026_10_23": {
        "front_distance_t240": {"depth-48": 67, "depth-96": 70, "depth-160": 71},
        "front_distance_t1800": {"depth-48": 175, "depth-96": 185, "depth-160": 191},
        "front_growth_exponent_t120_t1800": {"depth-48": 0.48, "depth-160": 0.50},
        "retained_fraction_t1800": {"depth-48": 0.839, "depth-96": 0.841, "depth-160": 0.851},
        "depth_response_t240": 1.06,
        "note": "Current spreads diffusively (front ~ t^0.5) with almost no depth dependence; adhesion-off "
                "diagnostic changed nothing material.",
    },
    "screens": {
        "pressure_flow_v1": {"exact_quantity": "visible + overfill Water integer constant every tick",
                             "depth_response_t240_min": 1.5, "front_distance_t240_depth160_min": 213,
                             "retained_fraction_t1800_depth160_max": 0.50,
                             "worker_parity": "identical 1/4-worker observations and physical-state hash"},
        "inertial_cellular_v1": {"exact_quantity": "whole-cell Water count constant every tick",
                                 "depth_response_t240_min": 1.25, "front_distance_t240_depth160_min": 142,
                                 "retained_fraction_t1800_depth160_max": 0.70,
                                 "worker_parity": "identical 1/4-worker observations and physical-state hash"},
    },
    "rationale": "Shallow-water dam-break fronts advance ballistically at ~2*sqrt(g*h); sqrt(160/48)=1.83. "
                 "Screens allow dissipation and are deliberately loose; passing a screen is not owner feel "
                 "acceptance, and failing one is a recorded result, not a build blocker.",
}


def contracts(fx: list[cat.Scenario]) -> dict:
    defs = {s.id: s for s in fx}
    return {
        "schema": "lcb-physics-contracts-v1",
        "status": "LCB physics prepass. Executable contracts run on Current only; every candidate arm is BLOCKED "
                  "until its implementation exists. Thresholds are frozen before candidate execution.",
        "contracts": [
            {"id": "deep-release-depth-response", "scenarios": ["lcb.dam.water.freemass.depth-48.v1",
             "lcb.dam.water.freemass.depth-96.v1", "lcb.dam.water.freemass.depth-160.v1"],
             "purpose": "Separate deep-release surge from equalization; stop a conserving but immobile candidate "
                        "from passing on accounting alone.",
             "current_control": {"status": "executable", "test": "test_lcb_physics_contracts.gd::deep_release"},
             "surge": SURGE,
             "arms": [{"arm": "W-PF", **PF}, {"arm": "W-IN", **IN}, {"arm": "W-CY", **CY}]},
            {"id": "vented-head-equalization", "scenarios": ["lcb.head.vented-two-limb.v1", "lcb.head.narrow-passage.v1"],
             "purpose": "Vented/shared-atmosphere communicating head (#49 boundary assumption).",
             "current_control": {"status": "executable", "test": "test_lcb_physics_contracts.gd::heads",
                                 "characterization": "zero cells move in 2400 ticks; difference stays 120.0 rows"},
             "screens": {"pressure_flow_v1": {
                 "vented-two-limb": "limb level difference at t2400 <= 12 rows (10% of 120) with exact quantity",
                 "narrow-passage": "limb level difference at t2400 <= 60 rows (50% of 120) with exact quantity",
                 "stability": "after first reaching the bound, the difference never grows by more than 2 rows"},
                 "inertial_cellular_v1": "record only: a non-pressure family is not required to transmit head",
                 "cellular_yield_v1": "record only"},
             "arms": [{"arm": "W-PF", **PF}, {"arm": "W-IN", **IN}, {"arm": "W-CY", **CY}]},
            {"id": "sealed-headspace-gas", "scenarios": ["lcb.head.sealed-two-limb.v1"],
             "purpose": "Sealed headspaces settle at a gas-pressure-dependent difference, never the vented target.",
             "current_control": {"status": "executable", "test": "test_lcb_physics_contracts.gd::heads",
                                 "characterization": "identical to vented: Current has no gas state"},
             "target": {"law": "isothermal: p_i * V_i = p_atm * V_i0 per sealed limb; equilibrium "
                               "p_L + z_L = p_R + z_R (pressures in rows of Water head, z = surface height); "
                               "equal limb widths, so z_L + z_R is constant",
                        "parameters": "p_atm in rows is a declared pressure_flow_v1 family parameter in the receipt",
                        "tolerance_rows": 2,
                        "must_differ_from_vented_target": True},
             "arms": [{"arm": "W-PF", **PF}]},
            {"id": "gas-topology", "scenarios": [d for d in defs if d.startswith("lcb.accept.gas.")],
             "purpose": "#200 trapped-gas defect regressions: identity independent of amount, unequal merge once, "
                        "reseal from current volume, gas state in the physical hash.",
             "expected": {
                 "lcb.accept.gas.single-pocket.v1": "amount 100 and one stable pocket identity at every tick",
                 "lcb.accept.gas.twin-pockets.v1": "two identities, each amount 100 at every tick; no cycling",
                 "lcb.accept.gas.unequal-merge.v1": "after tick 1: one pocket, amount 220, generation advanced, "
                                                   "ancestry records both parents",
                 "lcb.accept.gas.compress-vent-reseal.v1": "t1-t4 amount 100 at volume 50 (pressure doubled); "
                     "t5 vented to atmosphere with exchange ledger; t9 resealed amount = atmospheric amount for "
                     "the current volume (50); each change alters the versioned physical-state hash"},
             "current_control": {"status": "geometry-only",
                                 "note": "Current runs check definitions and Water inventory only; it has no gas"},
             "blocked_native_cases": ["empty-only (unallocated) chunk gas survival: MicroScenario reserves the "
                                      "whole frame, so this needs a #200 native test",
                                      "physical-state hash detects a gas-only change: needs the #200 hash API"],
             "arms": [{"arm": "W-PF", **PF}]},
            {"id": "dormant-water-active-oil", "scenarios": ["lcb.accept.dormant-water-active-oil.v1"],
             "purpose": "Non-pressure liquid motion continues while Water rests (NC-4).",
             "current_control": {"status": "executable", "test": "test_lcb_physics_contracts.gd::dormancy"},
             "screens": {"pressure_flow_v1/cached_dormant": "Oil observations identical to the same setup "
                         "under pressure_flow_v1/reference; dormant Water blocks never block Oil"},
             "arms": [{"arm": "W-PF dormant", **PF_DORMANT}]},
            {"id": "material-accounting", "scenarios": ["lcb.mixed.water-oil-brine.v1", "lcb.granular.salt-dissolution.v1",
                                                        "lcb.mixed.sodium-oil-fire.v1"],
             "purpose": "Signed per-species ledgers; partial-Water reactions are #160 boundary events.",
             "current_control": {"status": "executable", "test": "test_lcb_physics_contracts.gd::accounting"},
             "rules": {"water-salt": "delta_brine = +2*s; delta_water = -sum(consumed masses) in [-255*s, -s]",
                       "steam-expiry": "current main writes Water at maximum() (#160 amplification; PR #162 unmerged)"},
             "arms": [{"arm": "M1", **IN}, {"arm": "M2", "family": "pressure_flow_v1 + inertial_cellular_v1",
                                           "depends_on": ["#213 LCB-000 PASS", "#200", "#212"]}]},
            {"id": "cross-family-ownership", "scenarios": [],
             "purpose": "State tuples move with their cells; no ghost or copied family state.",
             "current_control": {"status": "executable", "test": "test_lcb_physics_contracts.gd::ownership",
                                 "case": "Brine (state_b tag 77) sinks through partial Water (mass 200); both "
                                         "tuples arrive intact"},
             "blocked_cases": ["inertial velocity follows its cell through a density swap (#212)",
                               "pressure overfill follows Water through moves and retires on conversion (#200)",
                               "no optional state remains on an Empty vacancy (#200/#212)"],
             "arms": [{"arm": "M1", **IN}, {"arm": "W-PF", **PF}]},
            {"id": "water-material-hooks", "scenarios": [],
             "purpose": "Water chemistry, coherence, coupling and identity survive alternative motion.",
             "current_control": {"status": "blocked", "reason": "needs a selectable non-default Water family"},
             "blocked_cases": ["Water+Salt, Lava quench, Fire and Oil extinguish, Cement cure under W-CY/W-PF/W-IN",
                               "coherence countdown suppresses lateral motion under every family",
                               "transport carrying receives the real moved quantity",
                               "Water under W-CY never uses Paste/Slush viscosity"],
             "arms": [{"arm": "W-CY", **CY}, {"arm": "W-PF", **PF}, {"arm": "W-IN", **IN}]},
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    fx = fixtures()
    outputs = {OUT / f"{s.id}.json": json.dumps(s.definition(), indent=2) + "\n" for s in fx}
    data = contracts(fx)
    for s in fx:
        data.setdefault("fixtures", []).append({**s.metadata(), "definition_path": f"res://tests/fixtures/lcb/acceptance/{s.id}.json"})
    outputs[CONTRACTS] = json.dumps(data, indent=2) + "\n"
    stale = []
    for path, text in outputs.items():
        if args.check:
            current = path.read_text(encoding="utf-8").replace("\r\n", "\n") if path.exists() else None
            if current != text:
                stale.append(path.name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text.encode("utf-8"))
    if args.check:
        if stale:
            print(f"stale: {stale}", file=sys.stderr)
            return 1
        print(f"{len(fx)} acceptance fixtures and the contract registry match their source")
        return 0
    print(f"wrote {len(fx)} acceptance fixtures and {CONTRACTS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
