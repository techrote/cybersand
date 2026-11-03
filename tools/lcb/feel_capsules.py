#!/usr/bin/env python3
"""Generate the LCB-FEEL #360 leak/drain comparison capsules.

Five new schema-2 MicroScenario definitions implement the #359 registration:
a two-cell-wall tank with outer half-open bounds [64,192) x [48,176), full-cell
Water [66,190) x [64,174), a 14-row headspace under a closed lid, and a wide
containing basin below. Variants open a side leak or a bottom drain at tick
120, each with the lid vent open from tick 0 or closed, plus a no-opening
control. Crossing an opening is internal transfer: no variant has a sink, so
complete Water is conserved. The event schema cannot place Wall, so the
proposed tick-600 closure is not representable; these capsules are open-only
through tick 1200 and closure belongs to #361's reversible-opening tools.

``--check`` fails when a committed capsule differs from the generator.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "godot/tests/fixtures/lcb/feel"
HORIZON = 1200
OPEN_TICK = 120
WATER = (66, 64, 124, 110)  # x, y, width, height of full-cell Water
TANK_INTERIOR = [66, 50, 124, 124]
BASIN = [40, 176, 944, 56]
TOTAL = [40, 32, 944, 200]
SIDE_LEAK = (190, 150, 2, 2)
BOTTOM_DRAIN = (128, 174, 2, 2)
LID_VENT = (128, 48, 2, 2)

TRANSPORT = {"families": {"liquid": {"cadence": 1, "carrying": 0, "erosion": 0, "horizontal": 2, "permeability": 1},
                          "powder": {"mixing": 0, "packing": 8, "pickup": 64}},
             "materials": {"33": {"permeability": 30}}, "name": "Baseline", "pairs": [], "version": 1}


def rectangles() -> list[int]:
    boxes = [
        (0, 0, 1024, 1), (0, 0, 1, 1024), (1023, 0, 1, 1024), (0, 1023, 1024, 1),  # World border
        (32, 232, 960, 8), (32, 32, 8, 200), (984, 32, 8, 200),                   # basin floor and side walls
        (64, 48, 128, 2), (64, 174, 128, 2),                                        # tank lid and bottom
        (64, 50, 2, 124), (190, 50, 2, 124),                                        # tank side walls
    ]
    return [value for box in boxes for value in (*box, 1)]


def erase(tick: int, box: tuple[int, int, int, int]) -> dict:
    return {"tick": tick, "kind": "erase", "x": box[0], "y": box[1], "width": box[2], "height": box[3],
            "material": 0, "normalized_mass": 0, "coherence": 0}


def observation(identifier: str, tick: int, region: list[int]) -> dict:
    return {"id": identifier, "tick": tick, "metric": "water_integer", "region": list(region), "material": 3}


def capsule(identifier: str, title: str, opening: tuple[int, int, int, int] | None, vented: bool, note: str) -> dict:
    events = []
    if vented:
        events.append(erase(0, LID_VENT))
    if opening is not None:
        events.append(erase(OPEN_TICK, opening))
    observations = [observation("total-t0", 0, TOTAL), observation("tank-t0", 0, TANK_INTERIOR)]
    for tick in (OPEN_TICK, 180, 240, 360, 600, 900, HORIZON):
        observations.append(observation(f"tank-t{tick}", tick, TANK_INTERIOR))
        observations.append(observation(f"basin-t{tick}", tick, BASIN))
    observations.append(observation(f"total-t{HORIZON}", HORIZON, TOTAL))
    quantity = WATER[2] * WATER[3] * 255
    regions = [{"id": "tank", "label": "Tank interior", "region": list(TANK_INTERIOR)},
               {"id": "basin", "label": "Basin below tank", "region": list(BASIN)}]
    if opening is not None:
        regions.append({"id": "opening", "label": "Opening (tick 120)", "region": list(opening)})
    if vented:
        regions.append({"id": "vent", "label": "Lid vent (tick 0)", "region": list(LID_VENT)})
    return {
        "schema_version": 2, "id": identifier, "recipe_version": 1, "seed": 359, "maturity": "exploratory",
        "rectangles": rectangles(), "partial_water_fills": [*WATER, 255, 0], "transport_profile": TRANSPORT,
        "water_semantics": [1, 8, 12, 0], "player_start": [24, 222], "camera_origin": [0, 0],
        "player_enabled": False, "body_enabled": False, "tools": [],
        "interest": {"policy": "fixed", "region": [16, 16, 992, 272]},
        "execution": {"policy": "fixed", "cadence_lod_enabled": False, "liquid_surface_adhesion_enabled": True},
        "events": events, "observations": observations,
        "conditions": [{"observation": f"total-t{HORIZON}", "comparison": "eq", "value": quantity, "outcome": "complete"}],
        "source_recipe": "LCB-FEEL #360 leak/drain capsule v1 (#359 registration)", "source_recipe_hash": "",
        "presentation": {"title": title, "instructions": note, "duration_ticks": HORIZON,
                         "baseline": "Registered comparison capsule; controlled fixed-tick run",
                         "profile": "Baseline", "regions": regions},
    }


def capsules() -> dict[str, dict]:
    common = (" Two-cell Wall tank, 13,640 full Water cells under a 14-row headspace above a wide basin."
              " Crossing the opening is internal transfer; there is no sink, so complete Water is conserved."
              " Open-only through tick 1200: closure is not representable by scheduled events.")
    items = [
        ("lcb.feel.leak-side.vented.v1", "Side leak, vented lid", SIDE_LEAK, True,
         "A 2x2 side puncture near the tank bottom opens at tick 120 with the lid vent open." + common),
        ("lcb.feel.leak-side.sealed.v1", "Side leak, sealed lid", SIDE_LEAK, False,
         "A 2x2 side puncture opens at tick 120 under a closed lid. Only PressureFlow tracks the headspace gas." + common),
        ("lcb.feel.drain-bottom.vented.v1", "Bottom drain, vented lid", BOTTOM_DRAIN, True,
         "A 2x2 bottom drain opens at tick 120 with the lid vent open." + common),
        ("lcb.feel.drain-bottom.sealed.v1", "Bottom drain, sealed lid", BOTTOM_DRAIN, False,
         "A 2x2 bottom drain opens at tick 120 under a closed lid. Apparent bubbles must be classified by state, not appearance." + common),
        ("lcb.feel.tank-closed.control.v1", "Closed tank control", None, False,
         "No opening: quantity, rest and idle-work control for the leak/drain capsules." + common),
    ]
    return {identifier: capsule(identifier, title, opening, vented, note) for identifier, title, opening, vented, note in items}


def encode(value: dict) -> str:
    return json.dumps(value, indent=2) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args(argv)
    stale = []
    for identifier, value in capsules().items():
        path = OUTPUT / (identifier + ".json")
        text = encode(value)
        if arguments.check:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                stale.append(path.relative_to(ROOT).as_posix())
        else:
            path.write_bytes(text.encode("utf-8"))
    if stale:
        print("Stale LCB-FEEL capsules:", ", ".join(stale), file=sys.stderr)
        return 1
    print(f"{'checked' if arguments.check else 'wrote'} {len(capsules())} LCB-FEEL capsules")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
