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
import inertial_contract as inertial  # noqa: E402
import scenario_catalogue as cat  # noqa: E402

OUT = ROOT / "godot/tests/fixtures/lcb/acceptance"
CONTRACTS = ROOT / "godot/tests/fixtures/lcb/lcb-physics-contracts.json"
WALL, WATER, OIL = cat.WALL, cat.WATER, cat.OIL

PF = {"family": "pressure_flow_v1", "depends_on": ["#213 LCB-000 PASS", "#200"]}
PF_DORMANT = {"family": "pressure_flow_v1/cached_dormant", "depends_on": ["#213 LCB-000 PASS", "#200", "#201"]}
IN = {"family": "inertial_cellular_v1", "depends_on": ["#200 per-material policy", "#212"]}
CY = {"family": "cellular_yield_v1 (Water, whole-cell)", "depends_on": ["#213 LCB-000 PASS", "#200"]}
RESEAL_EXPECTED: dict = {}
SPLIT_EXPECTED: dict = {}


def room(s: cat.Scenario, x0: int, interior_w: int = 10) -> None:
    """#200 reproducer room: walls x0..x0+w+1, y 8..20; Water floor y=19; air y 9..18."""
    right = x0 + interior_w + 1
    s.rect(x0, 8, interior_w + 2, 1, WALL).rect(x0, 20, interior_w + 2, 1, WALL)
    s.rect(x0, 8, 1, 13, WALL).rect(right, 8, 1, 13, WALL)
    s.fill(x0 + 1, 19, interior_w, 1)


def gas_volume(s: cat.Scenario, tick: int, seed=(13, 10), box=(0, 0, 64, 32)) -> dict:
    """Static geometry after scheduled events up to `tick`: connected Empty volume
    containing `seed`, and whether it reaches the box edge (open atmosphere).
    Ignores liquid motion; used only to preregister expected volumes."""
    x0, y0, w, h = box
    grid = {}
    for i in range(0, len(s.rects), 5):
        x, y, rw, rh, m = s.rects[i:i + 5]
        for yy in range(max(y, y0), min(y + rh, y0 + h)):
            for xx in range(max(x, x0), min(x + rw, x0 + w)):
                grid[(xx, yy)] = m
    for i in range(0, len(s.fills), 6):
        x, y, rw, rh = s.fills[i:i + 4]
        for yy in range(y, y + rh):
            for xx in range(x, x + rw):
                grid[(xx, yy)] = WATER
    for e in s.events:
        if e["tick"] > tick or e["kind"] == "sample":
            continue
        for yy in range(e["y"], e["y"] + e["height"]):
            for xx in range(e["x"], e["x"] + e["width"]):
                grid[(xx, yy)] = WATER if e["kind"] == "fill" else 0
    seen, stack, vented = {seed}, [seed], False
    while stack:
        cx, cy = stack.pop()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if not (x0 <= nx < x0 + w and y0 <= ny < y0 + h):
                vented = True
                continue
            if (nx, ny) not in seen and grid.get((nx, ny), 0) == 0:
                seen.add((nx, ny))
                stack.append((nx, ny))
    return {"volume": len(seen), "vented": vented}


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
        # v2: the vent path leaves through the right wall, runs along a roofed
        # channel and through a dry U-trap whose bottom row rests on a Wall
        # floor. Resealing fills that bottom row with Water, which is supported
        # and cannot fall; v1 used an unsupported roof plug (review on #226).
        room(s, 8)
        s.rect(20, 11, 5, 1, WALL).rect(20, 13, 3, 1, WALL).rect(22, 13, 1, 4, WALL)
        s.rect(24, 11, 1, 5, WALL).rect(22, 17, 5, 1, WALL).rect(26, 9, 1, 9, WALL)
        s.event(1, "fill", 9, 14, 10, 5, 255, 0)
        s.event(5, "erase", 19, 12, 1, 1)
        s.event(9, "fill", 23, 16, 3, 1, 255, 0)
        room_region, trap = (8, 8, 12, 13), (23, 16, 3, 1)
        s.observe("room-water-t0", 0, room_region).observe("room-water-t4", 4, room_region)
        s.observe("trap-water-t10", 10, trap).observe("room-water-t30", 30, room_region)
        s.observe("trap-water-t30", 30, trap)
        s.region("pocket", "Pocket", (9, 9, 10, 10)).region("closure", "Closure (19,12), erased at t5", (19, 12, 1, 1))
        s.region("trap", "U-trap seal row", trap)
    out.append(gas_fixture("lcb.accept.gas.compress-vent-reseal.v2", "Compress, vent and reseal (U-trap)",
        "#200 reproducer: Water fills half the pocket at tick 1 (compression, amount stays 100); the wall cell "
        "(19,12) opens at tick 5, venting the pocket through a channel and a dry U-trap; at tick 9 Water fills the "
        "trap's supported bottom row and reseals it. The archived candidate kept 100; W-PF must reseal from the "
        "current volume at atmospheric amount with an explicit exchange ledger, and hold it to tick 30.", 30, vent))

    def split(s):
        # One sealed compartment spans room A, a channel/U-trap path and room B.
        # Filling the trap's Wall-supported bottom row at tick 3 closes the path
        # and splits it into two compartments; the plug cannot fall.
        room(s, 8)
        room(s, 32)
        s.rect(20, 11, 12, 1, WALL).rect(20, 13, 3, 1, WALL).rect(22, 13, 1, 4, WALL)
        s.rect(24, 12, 1, 4, WALL).rect(22, 17, 5, 1, WALL).rect(26, 13, 1, 4, WALL)
        s.rect(26, 13, 6, 1, WALL)
        s.rect(19, 12, 1, 1, 0).rect(32, 12, 1, 1, 0)
        s.event(3, "fill", 23, 16, 3, 1, 255, 0)
        whole, trap = (8, 8, 36, 13), (23, 16, 3, 1)
        s.observe("water-t0", 0, whole).observe("trap-water-t5", 5, trap)
        s.observe("trap-water-t30", 30, trap).observe("water-t30", 30, whole)
        s.region("room-a", "Room A pocket", (9, 9, 10, 10)).region("room-b", "Room B pocket", (33, 9, 10, 10))
        s.region("trap", "U-trap closure row", trap)
    out.append(gas_fixture("lcb.accept.gas.split.v1", "Split one sealed compartment",
        "One sealed compartment spans two rooms joined through a channel and a dry U-trap. At tick 3 Water fills "
        "the trap's supported bottom row, closing the path: W-PF must split the amount deterministically by "
        "volume into two NEW compartments with ancestry, book the split exactly, and hold both to tick 30.",
        30, split))

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
    "admission_criteria": {
        "pressure_flow_v1": ["exact visible+overfill quantity every tick", "closed gas and Water ledgers",
                             "identical 1/4-worker observations and physical-state hash", "no fallback",
                             "bounded writes/allocation", "default goldens unchanged"],
        "inertial_cellular_v1": ["exact whole-cell count every tick", "momentum ledger closes every tick",
                                 "static closed pool keeps every velocity exactly 0 and its hash constant",
                                 "identical 1/4-worker observations and physical-state hash", "no fallback",
                                 "bounded writes/allocation", "default goldens unchanged"],
    },
    "characterization_screens": {
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
                 "Characterization screens allow dissipation and are deliberately loose: they are recorded per "
                 "arm, are NOT admission criteria, and passing one is not owner feel acceptance. Admission "
                 "criteria are the correctness invariants listed separately.",
    "inertial_lateral_sources": "inertial-update-v1 (contract 'inertial-update'): horizontal momentum arises "
        "only from diagonal re-aim (A) and blocked-fall deflection of velocity carried in from earlier ticks (B); "
        "support cancels the current tick's gravity first, so a supported cell at rest never drifts; no pressure "
        "or column-height term",
}


def contracts(fx: list[cat.Scenario]) -> dict:
    defs = {s.id: s for s in fx}
    global RESEAL_EXPECTED
    v = defs["lcb.accept.gas.compress-vent-reseal.v2"]
    phases = {name: gas_volume(v, tick) for name, tick in (("t0", 0), ("t1-t4", 1), ("t5-t8", 5), ("t9-t30", 9))}
    assert not phases["t1-t4"]["vented"] and phases["t5-t8"]["vented"] and not phases["t9-t30"]["vented"]
    global SPLIT_EXPECTED
    sp = defs["lcb.accept.gas.split.v1"]
    before = gas_volume(sp, 0, seed=(13, 10))
    after_a, after_b = gas_volume(sp, 3, seed=(13, 10)), gas_volume(sp, 3, seed=(37, 10))
    assert before == gas_volume(sp, 0, seed=(37, 10)) and not before["vented"]
    assert not after_a["vented"] and not after_b["vented"]
    assert after_a["volume"] + after_b["volume"] == before["volume"] - 3
    amount = before["volume"]  # sealed at atmospheric: amount in atmospheric cell-equivalents
    share_a = amount * after_a["volume"] // (after_a["volume"] + after_b["volume"])
    share_b = amount * after_b["volume"] // (after_a["volume"] + after_b["volume"])
    SPLIT_EXPECTED = {
        "geometry_volumes": {"t0-t2": before, "t3-t30 room A side": after_a, "t3-t30 room B side": after_b},
        "t0-t2": f"one sealed compartment of volume {before['volume']} at atmospheric amount ({amount} in "
                 "atmospheric cell-equivalents); one id",
        "t3": "the trap fill removes 3 cells of gas volume and closes the path in the same event: the parent id "
              "is retired; two NEW ids with ancestry = parent; generation advances; one split ledger entry whose "
              "parts sum exactly to the parent amount",
        "allocation_rule": "volume-proportional floor shares; the integer remainder goes to the compartment "
                           "containing the lowest (y, x) cell",
        "worked_example_atmospheric_cell_equivalents": {
            "parent_amount": amount, "volumes": [after_a["volume"], after_b["volume"]],
            "floor_shares": [share_a, share_b], "remainder": amount - share_a - share_b,
            "result": [share_a + (amount - share_a - share_b), share_b]},
        "t4-t30": "both ids, volumes and amounts constant; trap Water stays 3 full cells (stationary closure)",
        "hash": "the split changes the versioned physical-state hash; nothing else does after t3",
        "inspect_at": [2, 3, 4, 30],
    }
    RESEAL_EXPECTED = {
        "geometry_volumes": phases,
        "t1-t4": "one sealed compartment, amount 100 (atmospheric for the original 100 cells), volume "
                 f"{phases['t1-t4']['volume']}, pressure derived accordingly; same id and generation as t0",
        "t5-t8": "vented: connected to atmosphere; amount relaxes toward atmospheric with an explicit exchange "
                 "ledger entry; vent state recorded",
        "t9": f"reseal: a NEW compartment id (old id never reused), volume {phases['t9-t30']['volume']}, "
              "amount = atmospheric amount for that volume, ledger entry for the reseal",
        "t10-t30": "id, generation, volume and amount constant; trap Water stays 3 full cells (stationary seal)",
        "hash": "every amount, volume, vent or id change alters the versioned physical-state hash",
        "inspect_at": [4, 5, 8, 9, 10, 30],
    }
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
             "characterization_screens": {"pressure_flow_v1": {
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
                 "lcb.accept.gas.compress-vent-reseal.v2": RESEAL_EXPECTED,
                 "lcb.accept.gas.split.v1": SPLIT_EXPECTED},
             "withdrawn": {"lcb.accept.gas.compress-vent-reseal.v1":
                           "Water roof plug above an Empty cell can fall and reopen the vent (review on #226); "
                           "never accepted; replaced by v2"},
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
            {"id": "inertial-update", "scenarios": [],
             "purpose": "One ordered, bounded, exact-integer inertial cell update with a signed per-component "
                        "momentum ledger and a separate non-negative speed-loss ledger (re-review finding 2).",
             "current_control": {"status": "contract-model",
                                 "test": "tools/lcb/test_inertial_contract.py (standalone oracle; no World)"},
             "contract": inertial.registry(),
             "native_registrations_for_212": [
                 "reproduce every worked example on a single inertial cell in a native World fixture",
                 "per-tick signed momentum and speed-loss ledgers close on the dam ladder and lock exchanges",
                 "static closed pool and a supported cell with a free side keep every velocity exactly 0",
                 "Wall, body mask and same-family contacts produce identical ledgers for identical geometry",
                 "1/4-worker identical velocity/accumulator state in the physical-state hash"],
             "arms": [{"arm": "W-IN", **IN}, {"arm": "BRINE-IN", **IN}]},
            {"id": "cross-family-ownership", "scenarios": [],
             "purpose": "State tuples move with their cells; no ghost or copied family state.",
             "current_control": {"status": "executable", "test": "test_lcb_physics_contracts.gd::ownership",
                                 "case": "Brine (state_b tag 77) sinks through partial Water (mass 200); both "
                                         "tuples arrive intact"},
             "blocked_cases": ["inertial static closed pool: every velocity exactly 0, physical hash constant (#212)",
                               "inertial-update-v1 signed momentum and speed-loss ledgers close every tick "
                               "on the dam ladder (#212)",
                               "inertial dam release: vx becomes nonzero only through a re-aim or deflection "
                               "ledger entry (#212)",
                               "inertial velocity follows its cell through a density swap (#212)",
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
    stale = [p.name for p in OUT.glob("*.json") if p not in outputs] if OUT.exists() else []
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
