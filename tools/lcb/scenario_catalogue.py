#!/usr/bin/env python3
"""LCB-003 scenario catalogue v1: versioned MicroScenario schema-2 definitions.

Standard-library only. Each scenario below is the single source of its frozen
JSON definition under godot/tests/fixtures/lcb/scenarios/. The two PR #215
protected fixtures are NOT generated here; they stay byte-for-byte unchanged.

Initial inventories are computed here by painting the setup in the same order
as cybersand::demo::construct (rectangles in order, then Water fills). The
Godot regression checks them independently against the native World.

Usage:
  python tools/lcb/scenario_catalogue.py            # write definitions
  python tools/lcb/scenario_catalogue.py --check    # fail if any definition is stale
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot/tests/fixtures/lcb/scenarios"
SIDE = 1024
MAX_OBS, MAX_EVENTS, MAX_TICK = 24, 24, 3600

EMPTY, WALL, SAND, WATER, SMOKE, FIRE = 0, 1, 2, 3, 4, 6
WATER_SEMANTICS = [1, 8, 12, 0]  # version 1, mass8, coherence 12, flags 0
OIL, PASTE, SLUSH, STEAM, SALT, BRINE, SODIUM, MERCURY = 16, 20, 21, 22, 23, 24, 25, 33
NAMES = {WALL: "wall", SAND: "sand", WATER: "water", SMOKE: "smoke", FIRE: "fire", OIL: "oil",
         PASTE: "paste", SLUSH: "slush", STEAM: "steam", SALT: "salt", BRINE: "brine",
         SODIUM: "sodium", MERCURY: "mercury"}

BASELINE = {"families": {"liquid": {"cadence": 1, "carrying": 0, "erosion": 0, "horizontal": 2, "permeability": 1},
                         "powder": {"mixing": 0, "packing": 8, "pickup": 64}},
            "materials": {"33": {"permeability": 30}}, "name": "Baseline", "pairs": [], "version": 1}
EROSION = {"families": {"liquid": {"cadence": 1, "carrying": 0, "erosion": 0, "horizontal": 2, "permeability": 1},
                        "powder": {"mixing": 96, "packing": 8, "pickup": 64}},
           "materials": {"33": {"permeability": 30}}, "name": "Threshold erosion",
           "pairs": [{"direction": "directed", "source": 3, "target": t, "values": {"carrying": 255, "erosion": 1}}
                     for t in (2, 14, 29)], "version": 1}
BOUNDS = [0, 0, SIDE, 1, WALL, 0, 0, 1, SIDE, WALL, SIDE - 1, 0, 1, SIDE, WALL, 0, SIDE - 1, SIDE, 1, WALL]


def inventory_of(rects: list, fills: list, water_semantics: list) -> dict:
    """Paint rectangles then Water fills in cybersand::demo::construct order (H3).

    Models the native constructor exactly for the supported domain:
    - a Water rectangle cell holds maximum() mass; any other rectangle clears it;
    - a fill's mass is (2 * m * maximum() + 255) // 510, and a zero-mass fill is a
      no-op (the native bridge skips it), leaving the underlying material;
    - only mass8 Water semantics (maximum() = 255) and catalogued material IDs are
      supported; anything else raises instead of deriving a wrong inventory.
    """
    if not isinstance(water_semantics, list) or len(water_semantics) < 2 or water_semantics[1] != 8:
        raise ValueError(f"inventory_of supports mass8 Water semantics only, got {water_semantics!r}")
    maximum = 255
    grid = bytearray(SIDE * SIDE)
    mass = {}
    for i in range(0, len(rects), 5):
        x, y, w, h, m = rects[i:i + 5]
        if m != EMPTY and m not in NAMES:
            raise ValueError(f"inventory_of has no catalogued name for material id {m}")
        for yy in range(y, y + h):
            grid[yy * SIDE + x: yy * SIDE + x + w] = bytes([m]) * w
            for xx in range(x, x + w):
                if m == WATER:
                    mass[yy * SIDE + xx] = maximum
                else:
                    mass.pop(yy * SIDE + xx, None)
    for i in range(0, len(fills), 6):
        x, y, w, h, nm, _ = fills[i:i + 6]
        value = (2 * nm * maximum + 255) // (2 * 255)
        if value == 0:
            continue
        for yy in range(y, y + h):
            grid[yy * SIDE + x: yy * SIDE + x + w] = bytes([WATER]) * w
            for xx in range(x, x + w):
                mass[yy * SIDE + xx] = value
    counts, xs, ys = {}, [], []
    for value in set(grid) - {EMPTY, WALL}:
        counts[NAMES[value]] = grid.count(value)
    for y in range(SIDE):
        row = grid[y * SIDE:(y + 1) * SIDE]
        if row.count(EMPTY) + row.count(WALL) != SIDE:
            ys.append(y)
            cells = [x for x in range(SIDE) if row[x] not in (EMPTY, WALL)]
            xs += [cells[0], cells[-1]]
    bbox = [min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1] if ys else [0, 0, 0, 0]
    return {"cells": dict(sorted(counts.items())), "water_integer": sum(mass.values()),
            "water_cells": counts.get("water", 0), "material_region": bbox}


class Scenario:
    def __init__(self, sid, category, title, purpose, horizon, interest, manual, transport=BASELINE):
        self.id, self.category, self.title, self.purpose = sid, category, title, purpose
        self.horizon, self.interest, self.manual, self.transport = horizon, interest, manual, transport
        self.rects, self.fills, self.events, self.obs, self.conditions, self.regions = list(BOUNDS), [], [], [], [], []
        self.overview = None

    def rect(self, x, y, w, h, m):
        self.rects += [x, y, w, h, m]
        return self

    def fill(self, x, y, w, h, mass=255, coherence=0):
        self.fills += [x, y, w, h, mass, coherence]
        return self

    def event(self, tick, kind, x, y, w, h, mass=0, coherence=0):
        self.events.append({"tick": tick, "kind": kind, "x": x, "y": y, "width": w, "height": h,
                            "material": WATER if kind == "fill" else 0,
                            "normalized_mass": mass, "coherence": coherence})
        return self

    def observe(self, oid, tick, region, material=WATER, metric=None):
        metric = metric or ("water_integer" if material == WATER else "material_cells")
        self.obs.append({"id": oid, "tick": tick, "metric": metric, "region": list(region), "material": material})
        return self

    def condition(self, oid, comparison, value, outcome):
        self.conditions.append({"observation": oid, "comparison": comparison, "value": value, "outcome": outcome})
        return self

    def region(self, rid, label, region):
        self.regions.append({"id": rid, "label": label, "region": list(region)})
        return self

    def inventory(self):
        return inventory_of(self.rects, self.fills, WATER_SEMANTICS)

    def definition(self):
        self.obs.sort(key=lambda o: o["tick"])
        self.events.sort(key=lambda e: e["tick"])
        area = sum(o["region"][2] * o["region"][3] for o in self.obs)
        assert len(self.obs) <= MAX_OBS and len(self.events) <= MAX_EVENTS, self.id
        assert area <= SIDE * SIDE, (self.id, area)
        assert self.horizon <= MAX_TICK and all(o["tick"] <= self.horizon for o in self.obs), self.id
        return {
            "schema_version": 2, "id": self.id, "recipe_version": 1, "seed": 0, "maturity": "reference",
            "rectangles": self.rects, "partial_water_fills": self.fills, "transport_profile": self.transport,
            "water_semantics": WATER_SEMANTICS, "player_start": [24, 222], "camera_origin": [0, 0],
            "player_enabled": False, "body_enabled": False, "tools": [],
            "interest": {"policy": "fixed", "region": list(self.interest)},
            "execution": {"policy": "fixed", "cadence_lod_enabled": False, "liquid_surface_adhesion_enabled": True},
            "events": self.events, "observations": self.obs, "conditions": self.conditions,
            "source_recipe": "LCB-003 scenario catalogue v1: " + self.category, "source_recipe_hash": "",
            "presentation": {"title": self.title, "instructions": self.purpose, "duration_ticks": self.horizon,
                             "baseline": "Current native defaults; controlled fixed-tick run",
                             "profile": self.transport["name"], "regions": self.regions[:12]},
        }

    def metadata(self):
        return {"id": self.id, "version": 1, "category": self.category, "title": self.title,
                "purpose": self.purpose, "horizon_ticks": self.horizon, "manual": self.manual,
                "overview": self.overview, "transport_profile": self.transport["name"],
                "initial_inventory": self.inventory()}


# ---------------------------------------------------------------------------
# Shared geometry
TANK = dict(floor=(32, 256, 960, 8), left=(32, 64, 8, 192), right=(984, 64, 8, 192))
BANDS6 = [(240 + 124 * i, 64, 124, 192) for i in range(6)]


def tank(s, gate=True):
    for r in TANK.values():
        s.rect(*r, WALL)
    if gate:
        s.rect(232, 64, 8, 192, WALL)
    s.overview = [32, 64, 960, 200]
    return s


def dam(sid, title, purpose, depth, transport=BASELINE, sand_bed=False):
    s = tank(Scenario(sid, "dam-ladder" if not sand_bed else "granular", title, purpose, 1800,
                      (16, 16, 992, 272), {"free_play": True, "note": "edit after release to probe surge"}, transport))
    if sand_bed:
        s.rect(240, 232, 744, 24, SAND)
    s.fill(40, 256 - depth, 192, depth)
    s.event(0, "erase", 232, 64, 8, 192)
    total = (40, 32, 944, 224)
    s.observe("total-t0", 0, total).observe("total-t1800", 1800, total)
    for t in (60, 240, 600, 1800):
        s.observe(f"reservoir-t{t}", t, (40, 64, 192, 192))
    if sand_bed:
        for i, b in enumerate([(240, 64, 248, 192), (488, 64, 248, 192), (736, 64, 248, 192)]):
            s.observe(f"sand-band{i + 1}-t0", 0, b, SAND).observe(f"sand-band{i + 1}-t1800", 1800, b, SAND)
            s.observe(f"water-band{i + 1}-t600", 600, b)
    else:
        for t in (240, 1200):
            for i, b in enumerate(BANDS6):
                s.observe(f"band{i + 1}-t{t}", t, b)
    s.condition("total-t1800", "eq", 192 * depth * 255, "complete")
    s.region("reservoir", "Reservoir", (40, 256 - depth, 192, depth)).region("gate", "Gate", (232, 64, 8, 192))
    s.region("runout", "Runout", (240, 64, 744, 192))
    return s


def two_limb(sid, title, purpose, passage, sealed=False):
    s = Scenario(sid, "communicating-head", title, purpose, 2400, (80, 48, 296, 224),
                 {"free_play": False, "note": "controlled head-leveling apparatus"})
    roof_h = 192 - passage
    s.rect(92, 256, 264, 8, WALL).rect(92, 64, 8, 192, WALL).rect(348, 64, 8, 192, WALL)
    s.rect(148, 64, 8, roof_h, WALL).rect(292, 64, 8, roof_h, WALL).rect(156, 64, 136, roof_h, WALL)
    if sealed:
        s.rect(100, 64, 48, 8, WALL).rect(300, 64, 48, 8, WALL)
    s.fill(100, 96, 48, 160).fill(300, 216, 48, 40).fill(148, 256 - passage, 152, passage)
    left, right = (100, 64, 48, 256 - passage - 64), (300, 64, 48, 256 - passage - 64)
    for t in (0, 300, 1200, 2400):
        s.observe(f"left-t{t}", t, left).observe(f"right-t{t}", t, right)
    total = (92, 48, 264, 216)
    s.observe("total-t0", 0, total).observe("total-t2400", 2400, total)
    s.condition("total-t2400", "eq", (48 * 160 + 48 * 40 + 152 * passage) * 255, "complete")
    s.region("left", "Left limb", left).region("right", "Right limb", right)
    s.region("passage", "Roofed passage", (148, 256 - passage, 152, passage))
    s.overview = [92, 64, 264, 200]
    return s


def lanes(sid, title, purpose, materials):
    s = Scenario(sid, "viscous", title, purpose, 1200, (0, 120, 1024, 408),
                 {"free_play": True, "note": "paint more liquid into a lane to compare spreading"})
    for k, m in enumerate(materials):
        x0, floor = 16 + (k % 3) * 336, 256 if k < 3 else 512
        s.rect(x0, floor, 320, 8, WALL).rect(x0, floor - 96, 8, 96, WALL).rect(x0 + 312, floor - 96, 8, 96, WALL)
        s.rect(x0 + 56, floor - 96, 8, 96, WALL)
        compartment = (x0 + 8, floor - 64, 48, 64)
        if m == WATER:
            s.fill(*compartment)
        else:
            s.rect(*compartment, m)
        s.event(0, "erase", x0 + 56, floor - 96, 8, 96)
        name = NAMES[m]
        runout = (x0 + 64, floor - 96, 248, 96)
        s.observe(f"{name}-compartment-t0", 0, compartment, m)
        s.observe(f"{name}-runout-t300", 300, runout, m).observe(f"{name}-runout-t1200", 1200, runout, m)
        s.region(name, name.capitalize() + " lane", (x0, floor - 96, 320, 104))
    s.overview = [16, 160, 992, 360]
    return s


def compartments(sid, category, title, purpose, left, right, gate_tick=30, horizon=1200):
    s = tank(Scenario(sid, category, title, purpose, horizon, (16, 16, 992, 272),
                      {"free_play": True, "note": "reopen/paint to repeat the exchange"}), gate=False)
    s.rect(500, 64, 8, 192, WALL)
    for (x, w), m in (((40, 460), left), ((508, 476), right)):
        if m == WATER:
            s.fill(x, 128, w, 128)
        else:
            s.rect(x, 128, w, 128, m)
    s.event(gate_tick, "erase", 500, 64, 8, 192)
    everything = (40, 64, 944, 192)
    for m in (left, right):
        s.observe(f"{NAMES[m]}-t0", 0, everything, m).observe(f"{NAMES[m]}-t{horizon}", horizon, everything, m)
    for t in (300, horizon):
        s.observe(f"{NAMES[left]}-in-right-bottom-t{t}", t, (508, 224, 476, 32), left)
        s.observe(f"{NAMES[right]}-in-left-bottom-t{t}", t, (40, 224, 460, 32), right)
        s.observe(f"{NAMES[right]}-in-left-top-t{t}", t, (40, 128, 460, 32), right)
    # No pair rule joins these liquids: whole-cell counts must be conserved.
    s.condition(f"{NAMES[left]}-t{horizon}", "eq", 460 * 128, "complete")
    s.region("left", NAMES[left].capitalize(), (40, 128, 460, 128)).region("right", NAMES[right].capitalize(), (508, 128, 476, 128))
    s.region("gate", "Gate", (500, 64, 8, 192))
    return s


def pool(s, x=40, w=944, top=96):
    s.fill(x, top, w, 256 - top)
    return s


def build() -> list[Scenario]:
    out: list[Scenario] = []
    # 1. Dam-break depth ladder ------------------------------------------------
    for depth in (48, 96, 160):
        out.append(dam(f"lcb.dam.water.freemass.depth-{depth}.v1", f"Dam Break depth {depth}",
            f"Depth ladder: identical gate/runout geometry to the protected reference with a {depth}-row full-cell "
            "reservoir. Compares release volume, retained reservoir and front band arrival against depth. "
            + ("Physics-identical to lcb.dam.water.freemass.reference.v1 (registry consistency control)." if depth == 160 else ""),
            depth))
    # 2. Shallow flow ----------------------------------------------------------
    s = tank(Scenario("lcb.shallow.stream-steps.v1", "shallow-flow", "Stepped stream from a scheduled source",
        "A 4x4 Water source fires every 30 ticks for 600 ticks onto six descending steps that empty into a flat runout. "
        "Exercises falling sheets, step overflow and explicit source accounting.", 1800, (16, 16, 992, 272),
        {"free_play": True, "note": "add obstacles on the steps"}), gate=False)
    for i in range(6):
        s.rect(40 + i * 80, 136 + i * 20, 80, 120 - i * 20, WALL)
    for t in range(0, 600, 30):
        s.event(t, "fill", 48, 124, 4, 4, 255, 0)
    steps, runout, total = (40, 64, 480, 192), (520, 64, 464, 192), (40, 32, 944, 224)
    for t in (600, 1800):
        s.observe(f"steps-t{t}", t, steps).observe(f"runout-t{t}", t, runout)
    s.observe("total-t0", 0, total).observe("total-t1800", 1800, total)
    s.region("source", "Source", (48, 124, 4, 4)).region("steps", "Steps", steps).region("runout", "Runout", runout)
    out.append(s)

    s = tank(Scenario("lcb.shallow.ledge-sheet-fall.v1", "shallow-flow", "Ledge sheet falling 128 rows",
        "An 8-row Water sheet on a raised shelf is released by removing its right lip; the sheet spills, falls 128 rows "
        "and spreads on the floor. Compares sheet thinning, falling-stream break-up and landing spread.", 900,
        (16, 16, 992, 272), {"free_play": True, "note": "refill the shelf with the paint tool"}), gate=False)
    s.rect(200, 120, 360, 8, WALL).rect(200, 104, 8, 16, WALL).rect(552, 104, 8, 16, WALL)
    s.fill(208, 112, 344, 8)
    s.event(0, "erase", 552, 104, 8, 16)
    shelf, floor_band, total = (200, 72, 368, 48), (40, 200, 944, 56), (40, 32, 944, 224)
    for t in (60, 240, 900):
        s.observe(f"shelf-t{t}", t, shelf).observe(f"floor-t{t}", t, floor_band)
    s.observe("total-t0", 0, total).observe("total-t900", 900, total)
    s.condition("total-t900", "eq", 344 * 8 * 255, "complete")
    s.region("shelf", "Shelf", shelf).region("floor", "Landing floor", floor_band)
    out.append(s)

    s = dam("lcb.shallow.obstacle-run.v1", "Shallow release over obstacles",
        "A 24-row reservoir releases a thin flow across three low wall obstacles. Compares overtopping, ponding "
        "behind obstacles and thin-front propagation.", 24)
    s.category = "shallow-flow"
    s.rect(360, 248, 8, 8, WALL).rect(520, 244, 8, 12, WALL).rect(680, 248, 16, 8, WALL)
    out.append(s)

    # 3. Communicating heads (vented; sealed is a characterization only) -------
    out.append(two_limb("lcb.head.vented-two-limb.v1", "Vented two-limb U-tube",
        "Two open (vented, shared-atmosphere) 48-wide limbs at 160 and 40 rows connect through an 8-row roofed "
        "passage. Equal levels are the valid target only because both headspaces are open (#49 boundary assumption).", 8))
    out.append(two_limb("lcb.head.narrow-passage.v1", "Vented limbs, 2-row passage",
        "Same vented limbs joined by a 2-row, 152-cell roofed passage. Compares head transmission through a narrow "
        "saturated connection.", 2))
    out.append(two_limb("lcb.head.sealed-two-limb.v1", "Roofed limbs (sealed geometry)",
        "Limb tops are roofed so each headspace is enclosed. Current Water has no gas state, so it behaves as vented; "
        "the Current result characterizes the missing gas model and is NOT a sealed-headspace control. A valid sealed "
        "target needs gas state (W-PF, #200).", 8, sealed=True))

    # 4. Rest and disturbance --------------------------------------------------
    s = pool(tank(Scenario("lcb.rest.deep-quiet-pool.v1", "rest-wake", "Deep quiet pool",
        "A 944x160 full-cell closed pool with no input. Rest control: mass, content hash and activity should settle "
        "and stay unchanged.", 600, (16, 16, 992, 272), {"free_play": True, "note": "drop objects or paint to disturb"}),
        gate=False))
    total = (40, 32, 944, 224)
    s.observe("total-t0", 0, total).observe("total-t600", 600, total)
    s.condition("total-t600", "eq", 944 * 160 * 255, "complete")
    s.region("pool", "Pool", (40, 96, 944, 160))
    out.append(s)

    s = pool(tank(Scenario("lcb.rest.remote-disturbance.v1", "rest-wake", "Remote source and sink in a deep pool",
        "Deep quiet pool; an 8x8 Water block is added above the far end at tick 300 (explicit source) and an 8x8 full "
        "block is erased at the near bottom at tick 900 (explicit sink). Compares remote wake and checks ledger "
        "closure: final mass equals the initial mass.", 1200, (16, 16, 992, 272),
        {"free_play": True, "note": "manual drops are exploratory"}), gate=False))
    s.event(300, "fill", 940, 72, 8, 8, 255, 0).event(900, "erase", 48, 240, 8, 8)
    pool_total = (40, 40, 944, 216)
    for t in (0, 300, 900, 1200):
        s.observe(f"total-t{t}", t, pool_total)
    s.observe("far-end-t600", 600, (840, 64, 144, 192)).observe("near-end-t1200", 1200, (40, 64, 144, 192))
    s.condition("total-t1200", "eq", 944 * 160 * 255, "complete")
    s.region("source", "Source", (940, 72, 8, 8)).region("sink", "Sink", (48, 240, 8, 8))
    out.append(s)

    s = tank(Scenario("lcb.rest.two-pool-partial-activity.v1", "rest-wake", "Two pools, one disturbed",
        "Two deep pools separated by a 64-wide wall; only pool A receives an 8x8 drop at tick 60. Pool B must stay "
        "unchanged; checkpoint activity counters show whether work stays local.", 600, (16, 16, 992, 272),
        {"free_play": True, "note": "disturb either pool"}), gate=False)
    s.rect(480, 64, 64, 192, WALL).fill(40, 96, 440, 160).fill(544, 96, 440, 160)
    s.event(60, "fill", 400, 72, 8, 8, 255, 0)
    a, b = (40, 64, 440, 192), (544, 64, 440, 192)
    for t in (0, 120, 600):
        s.observe(f"pool-a-t{t}", t, a).observe(f"pool-b-t{t}", t, b)
    s.condition("pool-b-t600", "eq", 440 * 160 * 255, "complete")
    s.region("pool-a", "Pool A", a).region("pool-b", "Pool B", b)
    out.append(s)

    # 5. Viscous liquids -------------------------------------------------------
    out.append(lanes("lcb.viscous.lane-gallery.v1", "Viscous lane gallery",
        "Six separate lanes release equal 48x64 blocks of Water, Oil, Brine, Slush, Paste and Mercury at tick 0. "
        "Runout cell counts compare spreading rate against viscosity with each kernel's specialization intact.",
        [WATER, OIL, BRINE, SLUSH, PASTE, MERCURY]))
    s = tank(Scenario("lcb.viscous.pour-heaps.v1", "viscous", "Dropped viscous blocks",
        "32x32 blocks of Paste, Slush, Oil, Brine and Mercury fall from removable shelves onto the floor. Low and high "
        "band counts compare heap retention against spreading.", 900, (16, 16, 992, 272),
        {"free_play": True, "note": "pour more material on the heaps"}), gate=False)
    for i, m in enumerate((PASTE, SLUSH, OIL, BRINE, MERCURY)):
        x = 96 + i * 184
        s.rect(x, 64, 32, 32, m).rect(x, 96, 32, 4, WALL)
        s.event(0, "erase", x, 96, 32, 4)
        s.observe(f"{NAMES[m]}-t0", 0, (x, 64, 32, 32), m)
        s.observe(f"{NAMES[m]}-low-t900", 900, (x - 70, 240, 172, 16), m)
        s.observe(f"{NAMES[m]}-high-t900", 900, (x - 70, 192, 172, 48), m)
        s.region(NAMES[m], NAMES[m].capitalize(), (x - 70, 64, 172, 192))
    out.append(s)

    # 6. Density and displacement ---------------------------------------------
    s = Scenario("lcb.density.inverted-column.v1", "density", "Inverted three-liquid column",
        "A 64-wide column starts inverted: Brine on top, Water in the middle, Oil at the bottom. Density exchange "
        "should invert it. Third-by-third counts compare sorting speed and residual mixing.", 1800,
        (456, 24, 112, 248), {"free_play": True, "note": "stir by erasing/painting"})
    s.rect(472, 256, 80, 8, WALL).rect(472, 40, 8, 216, WALL).rect(544, 40, 8, 216, WALL)
    s.rect(480, 192, 64, 64, OIL).rect(480, 64, 64, 64, BRINE).fill(480, 128, 64, 64)
    thirds = {"top": (480, 64, 64, 64), "middle": (480, 128, 64, 64), "bottom": (480, 192, 64, 64)}
    for t in (0, 600, 1800):
        for k, r in thirds.items():
            s.observe(f"oil-{k}-t{t}", t, r, OIL).observe(f"brine-{k}-t{t}", t, r, BRINE)
    for k, r in thirds.items():
        s.region(k, k.capitalize() + " third", r)
    s.overview = [472, 40, 80, 224]
    out.append(s)

    s = pool(tank(Scenario("lcb.density.mercury-drop.v1", "density", "Mercury block into Water",
        "A 32x32 Mercury block falls from a shelf into a 96-row Water pool and must sink through it. Compares dense "
        "displacement speed and Water conservation.", 600, (16, 16, 992, 272),
        {"free_play": True, "note": "drop more Mercury"}), gate=False), top=160)
    s.rect(480, 64, 32, 32, MERCURY).rect(480, 96, 32, 4, WALL).event(0, "erase", 480, 96, 32, 4)
    bottom = (40, 224, 944, 32)
    for t in (0, 120, 600):
        s.observe(f"mercury-bottom-t{t}", t, bottom, MERCURY)
    s.observe("water-t0", 0, total).observe("water-t600", 600, total)
    s.condition("water-t600", "eq", 944 * 96 * 255, "complete")
    s.region("mercury", "Mercury block", (480, 64, 32, 32)).region("bottom", "Pool bottom", bottom)
    out.append(s)

    out.append(compartments("lcb.density.water-brine-lock-exchange.v1", "density", "Brine/Water lock exchange",
        "Brine (left) and Water (right) half-basins open at tick 30; Brine should undercut Water. Compares unlike-liquid "
        "gravity current and interface mixing.", BRINE, WATER))
    out.append(compartments("lcb.density.oil-water-lock-exchange.v1", "density", "Oil/Water lock exchange",
        "Oil (left) and Water (right) open at tick 30; Oil should ride over Water. Compares buoyant spreading and the "
        "Oil kernel's retained behavior.", OIL, WATER))

    # 7. Granular interaction --------------------------------------------------
    out.append(dam("lcb.granular.water-sand-baseline.v1", "Dam release onto Sand (Baseline)",
        "A 96-row reservoir releases onto a 24-row Sand bed with Baseline transport (no carrying/erosion). Sand band "
        "counts record displacement by the existing density/movement rules only.", 96, BASELINE, sand_bed=True))
    out.append(dam("lcb.granular.water-sand-erosion.v1", "Dam release onto Sand (Threshold erosion)",
        "Same setup with the Threshold erosion transport profile (Water carries Sand, erosion on). Compares carrying "
        "and erosion against the Baseline control; transport tuning stays separate from solver family.", 96,
        EROSION, sand_bed=True))
    s = pool(tank(Scenario("lcb.granular.salt-dissolution.v1", "granular", "Salt heap dissolving into Brine",
        "A 64x32 Salt block falls into a full-cell Water pool. int.pair.water-salt.dissolve.v1 converts each Water+Salt "
        "pair to two Brine. Ledger identity: Water loss = 255 x Salt consumed while all reacting Water cells are full.",
        1200, (16, 16, 992, 272), {"free_play": True, "note": "add Salt"}), gate=False), top=160)
    s.rect(400, 96, 64, 32, SALT).rect(400, 128, 64, 4, WALL).event(0, "erase", 400, 128, 64, 4)
    tank_inner = (40, 96, 944, 160)
    s.observe("salt-t0", 0, (400, 96, 64, 32), SALT).observe("salt-t60", 60, (336, 96, 192, 160), SALT)
    s.observe("salt-t1200", 1200, tank_inner, SALT)
    s.observe("water-t0", 0, tank_inner).observe("water-t1200", 1200, tank_inner)
    s.observe("brine-t60", 60, tank_inner, BRINE).observe("brine-t1200", 1200, tank_inner, BRINE)
    s.region("salt", "Salt block", (400, 96, 64, 32))
    out.append(s)

    # 8. Mixed-fluid stress ----------------------------------------------------
    s = Scenario("lcb.mixed.repeated-openings.v1", "mixed-stress", "Staggered openings with Water pulses",
        "Brine | Water | Oil compartments open one gate at a time (ticks 30, 300, 600), then three Water pulses enter "
        "at ticks 900-1100 (explicit sources). Stresses repeated boundary changes, density exchange and accounting.",
        1500, (48, 56, 928, 216), {"free_play": True, "note": "manual reopen/paint"})
    s.rect(64, 256, 896, 8, WALL).rect(64, 96, 8, 160, WALL).rect(952, 96, 8, 160, WALL)
    for x in (296, 528, 760):
        s.rect(x, 96, 8, 160, WALL)
    s.rect(72, 136, 224, 120, BRINE).rect(536, 136, 224, 120, OIL).fill(304, 136, 224, 120)
    for t, x in ((30, 296), (300, 528), (600, 760)):
        s.event(t, "erase", x, 96, 8, 160)
    for t in (900, 1000, 1100):
        s.event(t, "fill", 600, 72, 8, 8, 255, 0)
    basin, run = (72, 96, 880, 160), (768, 96, 184, 160)
    for t in (0, 1500):
        s.observe(f"water-t{t}", t, basin).observe(f"oil-t{t}", t, basin, OIL).observe(f"brine-t{t}", t, basin, BRINE)
    for m in (WATER, OIL, BRINE):
        s.observe(f"{NAMES[m]}-runout-t1500", 1500, run, m)
    s.condition("oil-t1500", "eq", 224 * 120, "complete")
    s.region("brine", "Brine", (72, 136, 224, 120)).region("water", "Water", (304, 136, 224, 120))
    s.region("oil", "Oil", (536, 136, 224, 120)).region("runout", "Runout", run)
    s.overview = [64, 96, 896, 168]
    out.append(s)

    s = tank(Scenario("lcb.mixed.sodium-oil-fire.v1", "mixed-stress", "Sodium into Water beside Oil",
        "A Sodium block drops into a Water pool next to an Oil pool behind a low divider. Water+Sodium makes Steam and "
        "Fire; Fire may ignite Oil, and Water extinguishes burning Oil. Records native chemistry and phase products; "
        "material counts are not conserved by design.", 900, (16, 16, 992, 272),
        {"free_play": True, "note": "hazardous chemistry sandbox"}), gate=False)
    s.rect(480, 140, 8, 116, WALL).fill(40, 160, 440, 96).rect(488, 160, 496, 96, OIL)
    s.rect(440, 120, 16, 16, SODIUM).rect(440, 136, 16, 4, WALL).event(30, "erase", 440, 136, 16, 4)
    for t in (0, 300, 900):
        s.observe(f"pool-water-t{t}", t, (40, 96, 440, 160)).observe(f"oil-t{t}", t, (488, 96, 496, 160), OIL)
    for t in (60, 300):
        for m in (SODIUM, FIRE, STEAM):
            s.observe(f"{NAMES[m]}-window-t{t}", t, (360, 32, 256, 224), m)
    s.region("water", "Water pool", (40, 160, 440, 96)).region("oil", "Oil pool", (488, 160, 496, 96))
    s.region("sodium", "Sodium", (440, 120, 16, 16))
    out.append(s)

    # 9. Seams and world boundary ----------------------------------------------
    s = Scenario("lcb.seam.dam-on-chunk-seams.v1", "seams", "Dam across chunk/core/block seams",
        "Gate straddles the x=384 chunk seam; the reservoir crosses the y=256 chunk seam and x/y=320 core seams. "
        "Checks conservation and 1/4-worker parity across storage and scheduling seams.", 1800,
        (240, 80, 672, 328), {"free_play": False, "note": "controlled seam apparatus"})
    s.rect(256, 384, 640, 8, WALL).rect(256, 128, 8, 256, WALL).rect(888, 128, 8, 256, WALL).rect(380, 128, 8, 256, WALL)
    s.fill(264, 224, 116, 160).event(0, "erase", 380, 128, 8, 256)
    seam_total = (264, 96, 624, 288)
    s.observe("total-t0", 0, seam_total).observe("total-t1800", 1800, seam_total)
    for t in (240, 1200):
        for i, x in enumerate((388, 556, 724)):
            s.observe(f"band{i + 1}-t{t}", t, (x, 192, 164 if i == 2 else 168, 192))
    s.observe("reservoir-t240", 240, (264, 192, 116, 192)).observe("reservoir-t1800", 1800, (264, 192, 116, 192))
    s.condition("total-t1800", "eq", 116 * 160 * 255, "complete")
    s.region("gate", "Gate on x=384 seam", (380, 128, 8, 256)).region("reservoir", "Reservoir", (264, 224, 116, 160))
    s.overview = [256, 128, 640, 264]
    out.append(s)

    s = Scenario("lcb.seam.world-boundary.v1", "seams", "Dam against the world boundary",
        "Reservoir uses the world-bound wall (x=0) and bottom row (y=1023) as container, far from the origin "
        "(chunk row 7). Checks boundary handling and conservation at the frame edge.", 1800, (0, 784, 544, 240),
        {"free_play": False, "note": "controlled boundary apparatus"})
    s.rect(520, 863, 8, 160, WALL).rect(200, 863, 8, 160, WALL).fill(1, 903, 199, 120)
    s.event(0, "erase", 200, 863, 8, 160)
    edge_total = (1, 800, 519, 223)
    s.observe("total-t0", 0, edge_total).observe("total-t1800", 1800, edge_total)
    for t in (240, 1800):
        s.observe(f"runout-t{t}", t, (208, 800, 312, 223)).observe(f"reservoir-t{t}", t, (1, 800, 199, 223))
    s.condition("total-t1800", "eq", 199 * 120 * 255, "complete")
    s.region("reservoir", "Reservoir", (1, 903, 199, 120)).region("runout", "Runout", (208, 863, 312, 160))
    s.overview = [0, 848, 536, 176]
    out.append(s)
    ids = [x.id for x in out]
    assert len(ids) == len(set(ids)), "duplicate scenario id"
    return out


def render(definition: dict) -> str:
    return json.dumps(definition, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    scenarios = build()
    stale, expected = [], set()
    for s in scenarios:
        path = OUT / f"{s.id}.json"
        expected.add(path.name)
        text = render(s.definition())
        if args.check:
            current = path.read_text(encoding="utf-8").replace("\r\n", "\n") if path.exists() else None
            if current != text:
                stale.append(path.name)
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text.encode("utf-8"))
    extra = sorted(p.name for p in OUT.glob("*.json") if p.name not in expected) if OUT.exists() else []
    if args.check:
        if stale or extra:
            print(f"stale={stale} unexpected={extra}", file=sys.stderr)
            return 1
        print(f"{len(scenarios)} scenario definitions match the catalogue")
        return 0
    if extra:
        print(f"unexpected definitions present: {extra}", file=sys.stderr)
        return 1
    print(f"wrote {len(scenarios)} definitions to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
