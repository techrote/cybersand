#!/usr/bin/env python3
"""Deterministically author native four-plane Strata showcase recipes.

These are original material-ID constructions, not converted concept pictures.
Every plane has a separate architectural role.  The file records authored
geometry and proposed route clearances; it does not certify actual flight,
structural load bearing, evolved simulation, or owner aesthetic acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import re


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "godot/data/strata2"
PLANES = ("play", "scripted", "effects", "background")
M = {
    "rock": 13, "brick": 57, "concrete": 58, "asphalt": 59,
    "steel": 62, "painted": 63, "corrugated": 64, "rust": 65,
    "grating": 66, "pipe": 68, "copper_pipe": 69, "glass": 71,
    "dark_glass": 72, "cable": 74, "hazard": 76, "cyan": 77,
    "magenta": 78, "amber": 79, "white": 80, "moss": 97,
    "basalt": 100, "obsidian": 101, "aluminium": 114, "brass": 119,
    "quartz": 122, "polymer": 128, "solar": 129, "carbon": 130,
    "heatshield": 131,
}


def digest(value: object) -> str:
    return hashlib.sha256(json.dumps(value, separators=(",", ":"), sort_keys=True).encode()).hexdigest()


def readable_json(value: object) -> str:
    """Keep native rectangle rows inspectable without five lines per cell field."""
    rendered = json.dumps(value, indent=2, ensure_ascii=False)
    return re.sub(r"\[\n((?:[ \t]+-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?,?\n){1,5})[ \t]*\]",
                  lambda found: json.dumps(json.loads(found.group()), separators=(", ", ": ")), rendered) + "\n"


class Layout:
    def __init__(self, width: int, height: int):
        self.width, self.height = width, height
        self.rectangles: list[list[int]] = []

    def r(self, x: int, y: int, w: int, h: int, material: str | int) -> None:
        assert all(type(v) is int for v in (x, y, w, h)), (x, y, w, h)
        assert x >= 1 and y >= 1 and w > 0 and h > 0
        assert x + w <= self.width - 1 and y + h <= self.height - 1, (x, y, w, h, self.width, self.height)
        material_id = M[material] if isinstance(material, str) else material
        assert material_id in M.values()
        self.rectangles.append([x, y, w, h, material_id])

    def frame(self, x: int, y: int, w: int, h: int, thickness: int, material: str) -> None:
        assert w > thickness * 2 and h > thickness * 2
        self.r(x, y, w, thickness, material)
        self.r(x, y + h - thickness, w, thickness, material)
        self.r(x, y + thickness, thickness, h - thickness * 2, material)
        self.r(x + w - thickness, y + thickness, thickness, h - thickness * 2, material)

    def line(self, x0: int, y0: int, x1: int, y1: int, thickness: int, material: str) -> None:
        """Pixel-step brace; no perspective face or implicit native resampling."""
        steps = max(abs(x1 - x0), abs(y1 - y0))
        if steps == 0:
            self.r(x0, y0, thickness, thickness, material)
            return
        # Coalesce horizontal runs without changing the integer geometry.
        points = {(round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps)) for i in range(steps + 1)}
        by_row: dict[int, list[int]] = {}
        for x, y in points:
            by_row.setdefault(y, []).append(x)
        for y in sorted(by_row):
            xs = by_row[y]
            self.r(min(xs), y, max(xs) - min(xs) + thickness, thickness, material)

    def deck(self, x: int, y: int, w: int, depth: int = 18, light: str = "cyan") -> None:
        self.r(x, y, w, depth, "steel")
        self.r(x, y, w, 3, "aluminium")
        self.r(x, y + depth - 3, w, 3, "carbon")
        for bx in range(x + 14, x + w - 12, 32):
            self.r(bx, y + 6, 9, 3, "grating")
        self.r(x + 8, y + 4, min(22, w - 16), 2, light)
        self.r(x + w - 30, y + 4, 22, 2, light)

    def truss(self, x: int, y: int, w: int, h: int, bays: int, material: str = "painted") -> None:
        self.frame(x, y, w, h, 5, material)
        for i in range(bays):
            left = x + 7 + (w - 15) * i // bays
            right = x + 7 + (w - 15) * (i + 1) // bays
            self.line(left, y + 8, right, y + h - 11, 3, material)
            self.line(left, y + h - 11, right, y + 8, 3, material)
            if i:
                self.r(left - 1, y + 4, 4, h - 8, "steel")

    def windows(self, x: int, y: int, w: int, h: int, seed: int, light: str = "amber", spacing: int = 24) -> None:
        rng = random.Random(seed)
        for wy in range(y, y + h - 7, spacing):
            for wx in range(x, x + w - 7, spacing):
                if rng.random() < 0.58:
                    self.r(wx, wy, 6, 8, light if rng.random() < 0.52 else "dark_glass")

    def cargo(self, x: int, y: int, w: int, h: int, accent: str = "painted") -> None:
        self.r(x, y, w, h, accent)
        self.frame(x, y, w, h, 3, "steel")
        for bx in range(x + 8, x + w - 6, 12):
            self.r(bx, y + 6, 2, h - 12, "corrugated")
        self.r(x + 5, y + 7, min(22, w - 10), 4, "hazard")

    def pipe(self, points: list[tuple[int, int]], thickness: int = 6, material: str = "pipe") -> None:
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            assert x0 == x1 or y0 == y1
            self.r(min(x0, x1), min(y0, y1), abs(x1 - x0) + thickness, abs(y1 - y0) + thickness, material)

    def ring(self, cx: int, cy: int, rx: int, ry: int, thickness: int, material: str) -> None:
        """Exact native-cell front elevation of an annulus, no image resampling."""
        assert rx > 0 and ry > 0 and thickness > 0
        inner_x, inner_y = rx - thickness, ry - thickness
        for dy in range(-ry, ry + 1):
            outer = math.floor(rx * math.sqrt(max(0.0, 1.0 - (dy / ry) ** 2)))
            if inner_x > 0 and inner_y > 0 and abs(dy) <= inner_y:
                inner = math.floor(inner_x * math.sqrt(max(0.0, 1.0 - (dy / inner_y) ** 2)))
                if outer > inner:
                    self.r(cx - outer, cy + dy, outer - inner, 1, material)
                    self.r(cx + inner + 1, cy + dy, outer - inner, 1, material)
            else:
                self.r(cx - outer, cy + dy, 2 * outer + 1, 1, material)


def effect(effect_id: str, kind: str, plane: str, region: list[int], *, seed: int,
           count: int, speed: float, strength: float, direction: list[float], colour: list[float]) -> dict:
    return dict(id=effect_id, kind=kind, plane=plane, region=region, seed=seed, count=count,
                speed=speed, strength=strength, direction=direction, colour=colour, enabled=True)


def route(name: str, start: list[int], finish: list[int], radius: int = 34) -> dict:
    return {"id": name, "from": start, "to": finish, "clearance_radius": radius,
            "claim": "Authored geometric clearance only; actual actor traversal requires execution."}


def scene(identity: str, title: str, description: str, extent: tuple[int, int], seed: int) -> tuple[dict, dict[str, Layout]]:
    width, height = extent
    raw = {
        "format": "cybersand-strata-showcase", "version": 1, "id": identity,
        "title": title, "description": description, "extent": [width, height],
        "spawn": [128, height - 200],
        "presentation": {"fog_strength": 0.28, "parallax_strength": 0.45},
        "play_rectangles": [], "planes": {},
        "atmosphere": {"version": 1, "enabled": True, "paused": False, "seed": seed, "effects": []},
        "route_probes": [], "detail_views": [],
        "provenance": {"kind": "original-native-material-construction", "generator": "tools/strata2_build_showcases.py",
                       "generator_version": 2, "seed": seed, "source_art": "none",
                       "geometry_semantics": "Ordered exact material-ID rectangles, native grid, no raster resampling.",
                       "physical_claim": "One ordinary Play actor; rear native geometry remains static and noncolliding with Play.",
                       "plane_roles": {"play": "Physical traversal and collision", "scripted": "Rear architectural structure",
                                       "effects": "Sparse native detail plus separately labelled visual motifs",
                                       "background": "Distant silhouettes and deliberate empty space"}},
    }
    return raw, {plane: Layout(width, height) for plane in PLANES}


def finish(raw: dict, layers: dict[str, Layout], depths: tuple[float, float, float] = (0.28, 0.15, 0.82),
           opacities: tuple[float, float, float] = (0.80, 0.76, 0.48)) -> dict:
    raw["play_rectangles"] = layers["play"].rectangles
    for i, plane in enumerate(("scripted", "effects", "background")):
        raw["planes"][plane] = {"depth": depths[i], "opacity": opacities[i], "rectangles": layers[plane].rectangles}
    raw["provenance"]["plane_geometry_sha256"] = {plane: digest(layers[plane].rectangles) for plane in PLANES}
    raw["provenance"]["ordered_rectangles"] = {plane: len(layers[plane].rectangles) for plane in PLANES}
    raw["provenance"]["authored_write_cells"] = {plane: sum(r[2] * r[3] for r in layers[plane].rectangles) for plane in PLANES}
    # Independently evaluate final material occupancy and straight-line route
    # envelopes; these masks are authoring diagnostics, never native evidence.
    width, height = raw["extent"]
    occupancy = bytearray(width * height)
    for x, y, w, h, material in layers["play"].rectangles:
        row = bytes([material]) * w
        for yy in range(y, y + h):
            occupancy[yy * width + x:yy * width + x + w] = row
    for probe in raw["route_probes"]:
        x0, y0 = probe["from"]
        x1, y1 = probe["to"]
        radius = probe["clearance_radius"]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for t in range(steps + 1):
            cx, cy = round(x0 + (x1 - x0) * t / steps), round(y0 + (y1 - y0) * t / steps)
            for y in range(cy - radius, cy + radius + 1):
                assert not any(occupancy[y * width + cx - radius:y * width + cx + radius + 1]), (raw["id"], probe["id"], cx, cy, y)
        probe["generator_clearance_check"] = "PASS; rectangular swept envelope, no physical execution"
    assert max(len(layout.rectangles) for layout in layers.values()) <= 32768
    assert all(sum(r[2] * r[3] for r in layout.rectangles) <= 16 * 1024 * 1024 for layout in layers.values())
    assert len(raw["atmosphere"]["effects"]) <= 12
    assert sum(e["count"] for e in raw["atmosphere"]["effects"]) <= 384
    return raw


def orbital_terminal() -> dict:
    raw, layer = scene("orbital-terminal", "Orbital Fabrication Terminal", "Suspended fabrication gantries frame an open flight corridor, with rear megatrusses, cargo infrastructure and a distant orbital horizon.", (2048, 1024), 240711)
    p, s, e, b = (layer[k] for k in PLANES)
    p.deck(32, 914, 1984, 30)
    p.r(32, 180, 18, 734, "steel")
    p.r(1998, 180, 18, 734, "steel")
    p.deck(32, 180, 1984, 20, "amber")
    for x, y, w in ((64, 550, 380), (620, 550, 568), (1350, 550, 624), (64, 340, 280), (1620, 360, 354)):
        p.deck(x, y, w, 20)
        p.r(x + 18, 200, 7, y - 200, "cable")
        p.r(x + w - 25, 200, 7, y - 200, "cable")
        for rx in range(x + 52, x + w - 30, 110):
            p.r(rx, y - 28, 4, 28, "steel")
            p.r(rx, y - 28, 46, 3, "steel")
    for x, y, w, h in ((90, 854, 100, 60), (204, 870, 74, 44), (690, 838, 130, 76), (840, 864, 92, 50), (1700, 850, 118, 64), (1830, 878, 110, 36)):
        p.cargo(x, y, w, h, "painted" if x % 3 else "rust")
    p.r(54, 904, 1942, 4, "hazard")
    for x in (80, 498, 916, 1334, 1752):
        s.truss(x, 228, 208, 160, 2)
        s.r(x + 88, 388, 18, 366, "corrugated")
        s.r(x + 84, 744, 26, 74, "steel")
        s.frame(x + 15, 638, 176, 154, 9, "steel")
        s.r(x + 22, 644, 162, 4, "aluminium")
        for cx in range(x + 29, x + 165, 36):
            s.cargo(cx, 720, 27, 54, "corrugated")
    s.truss(80, 418, 1880, 73, 10, "steel")
    s.pipe([(80, 802), (1930, 802), (1930, 608), (1770, 608)], 8, "copper_pipe")
    s.pipe([(310, 246), (310, 612), (510, 612)], 9)
    for x in (310, 730, 1150, 1570):
        e.frame(x, 276, 120, 54, 3, "steel")
        e.r(x + 8, 286, 38, 3, "cyan")
        e.r(x + 8, 297, 75, 2, "white")
        e.r(x + 8, 306, 54, 2, "amber")
    for x in (462, 1252):
        e.r(x, 778, 45, 12, "grating")
        e.r(x + 4, 774, 37, 3, "amber")
    # Widely separated orbital silhouettes, never an opaque backing wall.
    for x, w, top in ((70, 190, 704), (355, 112, 744), (570, 230, 660), (940, 190, 725), (1240, 260, 682), (1655, 282, 702)):
        b.r(x, top, w, 200, "carbon")
        b.r(x + 14, top - 10, w - 28, 10, "steel")
        b.r(x + w // 2, top - 90, 7, 80, "aluminium")
        b.windows(x + 14, top + 18, w - 28, 110, x, "cyan", 32)
    # Connected orbital dock silhouette occupies a different architectural
    # scale from the near truss bays. Its arms are anchored to distant towers;
    # large real gaps remain above, below and between the docking fingers.
    for x, y, w, h in ((302, 314, 124, 478), (1560, 286, 118, 494)):
        b.r(x, y, w, h, "carbon")
        b.r(x + 12, y - 34, w - 24, 34, "corrugated")
        b.r(x + 30, y - 62, w - 60, 28, "steel")
        b.r(x + 8, y + 10, 4, h - 20, "painted")
        b.windows(x + 24, y + 56, w - 48, h - 100, x + 77, "cyan", 44)
    b.r(400, 332, 1182, 42, "carbon")
    b.r(400, 332, 1182, 5, "corrugated")
    b.r(744, 266, 468, 66, "carbon")
    b.r(782, 242, 392, 24, "steel")
    b.r(812, 229, 332, 13, "corrugated")
    b.r(772, 286, 412, 4, "painted")
    for x in range(780, 1180, 58):
        b.r(x, 305, 13, 3, "cyan")
    for x, bottom in ((590, 514), (1320, 554)):
        b.r(x, 374, 26, bottom - 374, "carbon")
        b.r(x, 374, 4, bottom - 374, "steel")
        b.r(x - 44, bottom, 114, 20, "corrugated")
        b.r(x - 35, bottom + 20, 96, 14, "carbon")
    b.r(1174, 392, 342, 24, "carbon")
    b.r(1174, 392, 342, 4, "painted")
    rng = random.Random(113)
    for _ in range(75):
        b.r(rng.randrange(60, 1980), rng.randrange(45, 620), 1, 1, "white")
    raw["spawn"] = [150, 730]
    raw["route_probes"] = [route("lower-flight-corridor", [150, 730], [1880, 730]), route("central-rise", [1260, 730], [1260, 240])]
    raw["detail_views"] = [{"id": "cargo-and-truss", "center": [760, 635], "zoom": 1.4}, {"id": "orbital-window", "center": [1250, 340], "zoom": 1.0}]
    raw["atmosphere"]["effects"] = [
        effect("terminal-haze", "haze", "effects", [80, 570, 1850, 300], seed=1, count=32, speed=4.0, strength=0.65, direction=[1.0, 0.02], colour=[0.30, 0.59, 0.72, 0.70]),
        effect("vent-left", "steam", "effects", [436, 572, 96, 204], seed=2, count=28, speed=22.0, strength=0.85, direction=[0.12, -1.0], colour=[0.58, 0.78, 0.88, 0.78]),
        effect("vent-right", "steam", "effects", [1228, 560, 98, 214], seed=3, count=26, speed=18.0, strength=0.75, direction=[-0.10, -1.0], colour=[0.62, 0.76, 0.83, 0.70]),
        effect("overhead-signal", "beacon", "scripted", [110, 236, 1810, 16], seed=4, count=8, speed=1.0, strength=0.82, direction=[1.0, 0.0], colour=[1.0, 0.36, 0.08, 0.85]),
        effect("conveyor-lights", "machinery", "scripted", [90, 798, 1836, 6], seed=5, count=20, speed=18.0, strength=0.80, direction=[1.0, 0.0], colour=[0.20, 0.90, 0.95, 0.80]),
    ]
    return finish(raw, layer)


def neon_arcology() -> dict:
    raw, layer = scene("neon-rain-arcology", "Rain over the Arcology", "Uneven inhabited rooftops and suspended routes overlook separate rear blocks and a sparse distant skyline. Rain is a visual motif behind physical Play.", (2048, 1024), 244982)
    p, s, e, b = (layer[k] for k in PLANES)
    p.deck(32, 932, 1984, 32, "magenta")
    p.r(32, 238, 20, 694, "brick")
    p.r(1996, 110, 20, 822, "concrete")
    for x, y, w in ((72, 690, 330), (500, 535, 500), (1170, 655, 310), (1610, 430, 350)):
        p.deck(x, y, w, 24, "magenta" if x % 3 == 0 else "cyan")
        # Short rooftop bodies leave a separate broad flight corridor below.
        p.r(x + 12, y + 24, w - 24, 70, "brick" if x < 1000 else "concrete")
        p.r(x + 20, y + 32, w - 40, 8, "corrugated")
        p.r(x + 34, y + 48, w - 68, 27, "dark_glass")
        for wx in range(x + 43, x + w - 40, 30):
            p.r(wx, y + 53, 3, 18, "steel")
        for sx in (x + 30, x + w - 42):
            p.r(sx, max(80, y - 260), 5, min(260, y - 80), "cable")
        p.r(x + 16, y - 10, w - 32, 4, "cyan" if x < 1100 else "magenta")
    p.deck(70, 330, 250, 18, "amber")
    p.deck(780, 265, 360, 18, "cyan")
    p.deck(1370, 180, 240, 18, "magenta")
    for x, y, w, h, mat in ((82, 615, 78, 75, "steel"), (310, 630, 65, 60, "corrugated"), (602, 455, 110, 80, "polymer"), (1255, 590, 104, 65, "steel"), (1760, 345, 106, 85, "corrugated")):
        p.cargo(x, y, w, h, mat)
    # Separate rear towers with broad holes rather than four duplicated maps.
    for x, y, w, h, material, light in ((110, 210, 220, 390, "corrugated", "cyan"), (430, 125, 230, 330, "brick", "amber"), (780, 360, 200, 420, "steel", "magenta"), (1080, 100, 210, 450, "concrete", "cyan"), (1430, 290, 230, 470, "painted", "amber"), (1770, 80, 180, 270, "corrugated", "magenta")):
        s.r(x, y, w, h, material)
        s.r(x + 7, y + 15, w - 14, h - 25, "dark_glass")
        s.frame(x, y, w, h, 6, "steel")
        s.windows(x + 17, y + 29, w - 34, h - 45, x + y, light, 24)
        for wy in range(y + 90, y + h - 12, 90):
            s.r(x + 6, wy, w - 12, 4, "aluminium")
        s.r(x + w // 2, y - 35, 5, 35, "steel")
    s.truss(320, 472, 450, 48, 5, "rust")
    s.truss(1278, 226, 490, 52, 6, "steel")
    for x, y, light in ((350, 380, "magenta"), (1010, 295, "cyan"), (1682, 528, "amber")):
        e.frame(x, y, 46, 125, 3, "steel")
        for yy in range(y + 12, y + 112, 18):
            e.r(x + 10, yy, 25, 5, light)
        e.r(x + 18, y - 18, 7, 18, "steel")
    # The far skyline rises through selected upper openings. Narrow stepped
    # towers and smaller window marks distinguish it from the inhabited rear
    # blocks; no opaque city wall fills the complete horizon.
    for x, w, y in ((60, 200, 760), (340, 104, 294), (670, 102, 176),
                    (992, 76, 424), (1304, 108, 216), (1662, 94, 338), (1800, 140, 722)):
        b.r(x, y, w, 944 - y, "carbon")
        b.r(x + 10, y - 28, w - 20, 28, "corrugated")
        b.r(x + 22, y - 54, w - 44, 26, "steel")
        b.r(x + w // 2, y - 88, 3, 34, "painted")
        b.r(x + 6, y + 10, 3, 918 - y, "painted")
        rng = random.Random(x + 81)
        for wy in range(y + 20, 920, 26):
            for wx in range(x + 18, x + w - 12, 22):
                if rng.random() < 0.45:
                    b.r(wx, wy, 3, 5, "cyan" if rng.random() < 0.8 else "amber")
        for wy in range(y + 102, 930, 148):
            b.r(x + 7, wy, w - 14, 3, "corrugated")
    b.r(704, 591, 342, 13, "carbon")
    b.r(704, 591, 342, 3, "steel")
    b.r(1342, 709, 365, 17, "carbon")
    b.r(1342, 709, 365, 3, "painted")
    raw["spawn"] = [160, 850]
    raw["route_probes"] = [route("street-flight", [160, 850], [1880, 850]), route("eastern-ascent", [1540, 850], [1540, 300])]
    raw["detail_views"] = [{"id": "rain-and-signs", "center": [1080, 460], "zoom": 1.5}, {"id": "inhabited-rear-block", "center": [470, 360], "zoom": 1.4}]
    raw["presentation"] = {"fog_strength": 0.34, "parallax_strength": 0.50}
    raw["atmosphere"]["effects"] = [
        effect("western-rain", "rain", "effects", [60, 70, 925, 790], seed=8, count=96, speed=54.0, strength=0.80, direction=[0.22, 1.0], colour=[0.40, 0.74, 0.98, 0.85]),
        effect("eastern-rain", "rain", "effects", [1020, 60, 950, 810], seed=9, count=96, speed=48.0, strength=0.80, direction=[0.20, 1.0], colour=[0.48, 0.68, 0.92, 0.85]),
        effect("street-haze", "haze", "effects", [72, 775, 1860, 135], seed=10, count=40, speed=7.0, strength=0.75, direction=[1.0, -0.03], colour=[0.45, 0.25, 0.66, 0.75]),
        effect("roof-signals", "beacon", "scripted", [450, 126, 826, 10], seed=11, count=5, speed=0.65, strength=0.80, direction=[1.0, 0.0], colour=[0.91, 0.14, 0.64, 0.85]),
    ]
    return finish(raw, layer, (0.31, 0.16, 0.86), (0.78, 0.85, 0.44))


def industrial_underworks() -> dict:
    raw, layer = scene("industrial-underworks", "Underworks / Reactor Service", "Three service tiers border a continuous central shaft. Hollow rear reactors, copper lines and signal motion establish depth without blocking the physical route.", (1024, 1024), 245921)
    p, s, e, b = (layer[k] for k in PLANES)
    p.deck(24, 926, 976, 36, "amber")
    p.r(24, 76, 22, 850, "concrete")
    p.r(978, 76, 22, 850, "concrete")
    p.deck(24, 76, 976, 22, "amber")
    for x, y, w in ((48, 760, 300), (654, 760, 322), (176, 506, 286), (602, 506, 210), (68, 302, 296), (640, 302, 306)):
        p.deck(x, y, w, 20, "amber")
        p.r(x + 12, y + 20, 10, 54, "steel")
        p.r(x + w - 22, y + 20, 10, 54, "steel")
        p.r(x + 10, y - 25, 5, 25, "steel")
        p.r(x + 10, y - 25, 65, 3, "steel")
    p.pipe([(62, 134), (62, 650), (164, 650)], 10, "pipe")
    p.pipe([(942, 134), (942, 652), (848, 652)], 10, "copper_pipe")
    p.cargo(66, 862, 100, 64, "rust")
    p.cargo(848, 860, 100, 66, "steel")
    for x, y, w, h in ((102, 386, 186, 320), (386, 156, 236, 276), (730, 380, 178, 324)):
        s.frame(x, y, w, h, 12, "steel")
        s.frame(x + 20, y + 22, w - 40, h - 44, 5, "copper_pipe")
        s.r(x + 36, y + 42, w - 72, 22, "grating")
        s.r(x + 36, y + h - 68, w - 72, 22, "grating")
        for yy in range(y + 92, y + h - 86, 35):
            s.r(x + 40, yy, w - 80, 4, "pipe")
            s.r(x + 45, yy + 9, 18, 3, "amber")
        s.pipe([(x + w // 2, y + h), (x + w // 2, 856)], 8, "copper_pipe")
    s.truss(76, 112, 864, 44, 9, "steel")
    s.truss(74, 864, 868, 38, 9, "rust")
    for x in (334, 670):
        e.r(x, 706, 28, 11, "grating")
        e.r(x + 4, 702, 20, 3, "amber")
        e.frame(x - 12, 580, 52, 68, 3, "steel")
        for yy in range(590, 636, 12):
            e.r(x - 3, yy, 30, 3, "cyan")
    # A large static rear turbine and pressure columns contrast with the
    # rectilinear foreground service racks. Native annuli retain actual voids;
    # neither the rotor nor the columns simulate motion or collide with Play.
    for x, y, w, h in ((112, 196, 108, 534), (794, 182, 102, 552)):
        b.r(x, y, w, h, "carbon")
        b.r(x + 12, y - 20, w - 24, 20, "corrugated")
        b.r(x + 20, y - 36, w - 40, 16, "steel")
        for yy in range(y + 74, y + h - 30, 108):
            b.r(x - 6, yy, w + 12, 8, "corrugated")
            b.r(x + 10, yy + 8, 3, 36, "pipe")
    b.ring(510, 598, 192, 178, 31, "carbon")
    b.ring(510, 598, 192, 178, 7, "corrugated")
    b.ring(510, 598, 143, 132, 4, "steel")
    for angle in (0, 60, 120):
        radians = math.radians(angle)
        dx, dy = round(140 * math.cos(radians)), round(129 * math.sin(radians))
        b.line(510 - dx, 598 - dy, 510 + dx, 598 + dy, 8, "painted")
    b.ring(510, 598, 31, 29, 32, "carbon")
    b.ring(510, 598, 31, 29, 5, "steel")
    b.pipe([(511, 420), (511, 236), (748, 236)], 10, "pipe")
    b.r(352, 782, 318, 22, "carbon")
    b.r(366, 782, 290, 5, "corrugated")
    b.r(84, 805, 854, 8, "steel")
    raw["spawn"] = [512, 842]
    raw["route_probes"] = [route("central-service-shaft", [512, 842], [512, 180]), route("lower-cross-passage", [230, 870], [790, 870])]
    raw["detail_views"] = [{"id": "reactor-window", "center": [292, 550], "zoom": 1.6}, {"id": "shaft-and-machinery", "center": [550, 430], "zoom": 1.25}]
    raw["atmosphere"]["effects"] = [
        effect("left-vent", "steam", "effects", [308, 480, 82, 223], seed=21, count=30, speed=19.0, strength=0.90, direction=[0.10, -1.0], colour=[0.67, 0.81, 0.82, 0.85]),
        effect("right-vent", "steam", "effects", [640, 498, 86, 205], seed=22, count=26, speed=22.0, strength=0.90, direction=[-0.14, -1.0], colour=[0.65, 0.74, 0.79, 0.85]),
        effect("reactor-warning", "beacon", "scripted", [410, 182, 185, 13], seed=23, count=3, speed=0.80, strength=0.95, direction=[1.0, 0.0], colour=[1.0, 0.30, 0.06, 0.90]),
        effect("rear-service-signal", "machinery", "background", [98, 801, 810, 11], seed=24, count=18, speed=20.0, strength=0.80, direction=[1.0, 0.0], colour=[0.95, 0.58, 0.12, 0.80]),
        effect("service-dust", "dust", "effects", [100, 250, 824, 620], seed=25, count=44, speed=2.5, strength=0.65, direction=[0.55, -0.12], colour=[0.87, 0.72, 0.49, 0.80]),
    ]
    return finish(raw, layer, (0.30, 0.16, 0.82), (0.77, 0.85, 0.40))


def abyss_foundry() -> dict:
    raw, layer = scene("abyss-foundry", "Abyss Foundry", "Irregular basalt shelves and an industrial incursion frame a large central void. Distant rock fins, rear maintenance works and cool mist remain distinct from physical terrain.", (1024, 1024), 246209)
    p, s, e, b = (layer[k] for k in PLANES)
    # Native rectangular steps retain deliberately rough orthographic contours.
    for x in range(1, 1023, 8):
        width = min(8, 1023 - x)
        top = 82 + round(24 * math.sin(x / 51) + 13 * math.sin(x / 17))
        if 690 < x < 810:
            top += round(115 * (1 - abs(x - 750) / 60))
        floor = 914 + round(19 * math.sin(x / 37) + 9 * math.cos(x / 19))
        p.r(x, 1, width, top, "basalt")
        p.r(x, top - 4, width, 4, "obsidian")
        p.r(x, floor, width, 1023 - floor, "basalt")
        p.r(x, floor, width, 4, "obsidian")
    for y in range(1, 903, 8):
        left = 48 + round(18 * math.sin(y / 54) + 11 * math.cos(y / 22))
        right = 65 + round(21 * math.sin(y / 47) + 7 * math.cos(y / 17))
        p.r(1, y, left, 8, "basalt")
        p.r(1023 - right, y, right, 8, "basalt")
    for x, y, w, h in ((46, 430, 230, 27), (666, 585, 298, 31), (90, 762, 332, 28), (640, 770, 300, 28)):
        p.r(x, y, w, h, "basalt")
        p.r(x + 8, y + h, w - 28, 16, "obsidian")
        p.deck(x + 12, y - 13, w - 24, 13, "amber")
    p.deck(126, 216, 240, 18, "cyan")
    p.r(140, 94, 6, 122, "cable")
    p.r(342, 88, 6, 128, "cable")
    p.pipe([(868, 168), (868, 550), (768, 550)], 9, "copper_pipe")
    p.cargo(680, 520, 84, 52, "rust")
    for x, y, w, h in ((148, 320, 172, 315), (658, 226, 200, 236)):
        s.frame(x, y, w, h, 9, "steel")
        s.r(x + 16, y + 16, w - 32, 4, "amber")
        s.pipe([(x + 30, y + 40), (x + 30, y + h - 40), (x + w - 30, y + h - 40)], 7, "copper_pipe")
    s.truss(270, 674, 466, 50, 5, "rust")
    for x in (352, 588):
        s.r(x, 380, 14, 270, "corrugated")
        s.r(x - 18, 380, 50, 15, "steel")
    # Attached far geology reveals a second chamber contour instead of four
    # disconnected rectangular rock strips. Every contour is native material.
    for x in range(84, 944, 10):
        bottom = 182 + round(38 * math.sin(x / 84) + 16 * math.cos(x / 31))
        b.r(x, 70, 10, bottom - 70, "basalt")
        b.r(x, bottom - 8, 10, 8, "obsidian")
    for x, top, base, width in ((224, 146, 674, 126), (708, 154, 608, 118)):
        for y in range(top, base, 12):
            t = (y - top) / (base - top)
            delta = round(13 * math.sin(y / 37 + x) + 7 * math.cos(y / 19))
            span = max(8, round(width * (1.0 - t) ** 0.68) + delta)
            b.r(x - span // 2, y, span, min(12, base - y), "obsidian")
    for y in range(190, 810, 12):
        left = 124 + round(30 * math.sin(y / 82) + 12 * math.cos(y / 33))
        right = 114 + round(24 * math.sin(y / 69) + 14 * math.cos(y / 29))
        b.r(70, y, left, 12, "basalt")
        b.r(944 - right, y, right, 12, "obsidian")
    for x in range(130, 910, 20):
        y = 842 + round(18 * math.sin(x / 49))
        b.r(x, y, 20, 100, "basalt")
    for x, y in ((230, 644), (757, 482), (846, 749)):
        e.r(x, y, 22, 9, "grating")
        e.r(x + 4, y - 4, 14, 3, "cyan")
    for x, y in ((115, 290), (837, 340), (317, 860), (714, 824)):
        e.r(x, y, 5, 12, "quartz")
        e.r(x + 5, y + 6, 7, 6, "quartz")
    raw["spawn"] = [512, 820]
    raw["route_probes"] = [route("abyss-central-rise", [512, 820], [512, 190]), route("lower-open-span", [200, 850], [850, 850])]
    raw["detail_views"] = [{"id": "industrial-intrusion", "center": [710, 430], "zoom": 1.4}, {"id": "mist-and-rock-depth", "center": [390, 690], "zoom": 1.25}]
    raw["presentation"] = {"fog_strength": 0.38, "parallax_strength": 0.48}
    raw["atmosphere"]["effects"] = [
        effect("abyss-mist", "haze", "effects", [110, 646, 800, 232], seed=31, count=38, speed=3.5, strength=0.85, direction=[0.75, 0.05], colour=[0.28, 0.65, 0.72, 0.88]),
        effect("mineral-dust", "dust", "effects", [130, 160, 740, 650], seed=32, count=58, speed=2.8, strength=0.80, direction=[0.35, -0.12], colour=[0.72, 0.68, 0.45, 0.75]),
        effect("left-fissure", "steam", "effects", [190, 470, 98, 170], seed=33, count=22, speed=13.0, strength=0.80, direction=[0.16, -1.0], colour=[0.32, 0.71, 0.80, 0.80]),
        effect("right-fissure", "steam", "effects", [719, 320, 98, 159], seed=34, count=18, speed=11.0, strength=0.75, direction=[-0.12, -1.0], colour=[0.42, 0.68, 0.72, 0.80]),
        effect("service-pulse", "beacon", "scripted", [160, 340, 145, 12], seed=35, count=3, speed=0.45, strength=0.75, direction=[1.0, 0.0], colour=[1.0, 0.56, 0.12, 0.80]),
    ]
    return finish(raw, layer, (0.32, 0.17, 0.88), (0.75, 0.86, 0.46))


def vertical_spine() -> dict:
    raw, layer = scene("vertical-transfer-spine", "Vertical Transfer Spine", "A tall orbital service spine: alternating landings flank an uninterrupted flight shaft while rear hoist architecture and distant habitation establish monumental scale.", (1024, 1536), 246735)
    p, s, e, b = (layer[k] for k in PLANES)
    p.deck(28, 1450, 968, 34, "cyan")
    p.r(28, 70, 26, 1380, "steel")
    p.r(970, 70, 26, 1380, "steel")
    p.deck(28, 70, 968, 24, "amber")
    for i, y in enumerate((320, 560, 800, 1040, 1280)):
        left_width = 300 if i % 2 == 0 else 238
        right_x = 694 if i % 2 == 0 else 628
        p.deck(54, y, left_width, 20, "cyan")
        p.deck(right_x, y - 94, 970 - right_x, 20, "amber")
        p.r(80, y + 20, 9, 92, "steel")
        p.r(932, y - 74, 9, 92, "steel")
        p.cargo(114, y - 58, 86, 58, "painted" if i % 2 else "rust")
        p.r(right_x + 18, y - 126, 4, 32, "steel")
        p.r(right_x + 18, y - 126, 76, 3, "steel")
    p.pipe([(76, 135), (76, 1390), (280, 1390)], 8, "copper_pipe")
    p.pipe([(944, 135), (944, 1370), (748, 1370)], 8, "pipe")
    for y in range(140, 1370, 240):
        s.truss(150, y, 720, 55, 8, "steel")
        if y + 189 < 1430:
            s.frame(355, y + 74, 316, 115, 7, "painted")
            s.r(363, y + 151, 300, 30, "carbon")
            s.r(382, y + 93, 262, 5, "grating")
            s.r(382, y + 171, 262, 5, "grating")
            for xx in range(390, 650, 44):
                s.r(xx, y + 98, 4, 53, "steel")
            s.r(488, y + 160, 48, 3, "cyan")
        rail_height = min(185, 1450 - y - 55)
        s.r(150, y + 55, 14, rail_height, "corrugated")
        s.r(856, y + 55, 14, rail_height, "corrugated")
        if y + 130 < 1430:
            e.frame(276, y + 78, 38, 52, 3, "steel")
            e.r(285, y + 87, 20, 3, "cyan")
            e.r(285, y + 98, 20, 3, "amber")
    s.r(363, 202, 4, 1188, "cable")
    s.r(655, 202, 4, 1188, "cable")
    s.ring(510, 161, 35, 31, 7, "corrugated")
    for x, y, w, h in ((204, 210, 120, 740), (714, 150, 122, 680), (310, 980, 140, 410), (580, 850, 126, 540)):
        b.r(x, y, w, h, "carbon")
        b.frame(x, y, w, h, 6, "steel")
        b.windows(x + 15, y + 24, w - 30, h - 42, x + y, "cyan", 36)
    raw["spawn"] = [512, 1360]
    raw["route_probes"] = [route("full-transfer-shaft", [512, 1360], [512, 160], 34)]
    raw["detail_views"] = [{"id": "transfer-hoist", "center": [520, 540], "zoom": 1.35}, {"id": "lower-service-deck", "center": [450, 1180], "zoom": 1.2}]
    raw["presentation"] = {"fog_strength": 0.32, "parallax_strength": 0.46}
    raw["atmosphere"]["effects"] = [
        effect("shaft-haze", "haze", "effects", [180, 210, 660, 1180], seed=41, count=42, speed=4.0, strength=0.70, direction=[0.3, -0.4], colour=[0.28, 0.55, 0.75, 0.80]),
        effect("hoist-signals", "machinery", "scripted", [168, 170, 9, 1210], seed=42, count=18, speed=22.0, strength=0.90, direction=[0.0, -1.0], colour=[0.18, 0.85, 0.96, 0.85]),
        effect("rear-vent", "steam", "effects", [760, 1050, 100, 320], seed=43, count=34, speed=20.0, strength=0.85, direction=[-0.05, -1.0], colour=[0.62, 0.76, 0.82, 0.80]),
        effect("top-warning", "beacon", "scripted", [200, 147, 620, 13], seed=44, count=6, speed=0.70, strength=0.85, direction=[1.0, 0.0], colour=[1.0, 0.38, 0.09, 0.90]),
    ]
    return finish(raw, layer, (0.31, 0.16, 0.84), (0.75, 0.80, 0.43))


BUILDERS = (orbital_terminal, neon_arcology, industrial_underworks, abyss_foundry, vertical_spine)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Refuse source drift without rewriting files.")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    index = []
    for builder in BUILDERS:
        document = builder()
        path = OUTPUT / f"{document['id']}.json"
        encoded = readable_json(document)
        if args.check:
            assert path.read_text() == encoded, f"Generated source differs: {path}"
        else:
            path.write_text(encoded)
        index.append({"id": document["id"], "extent": document["extent"],
                      "native_rectangles": document["provenance"]["ordered_rectangles"],
                      "native_write_cells": document["provenance"]["authored_write_cells"],
                      "visual_motifs": sum(e["count"] for e in document["atmosphere"]["effects"]),
                      "file_sha256": hashlib.sha256(encoded.encode()).hexdigest()})
    print(json.dumps({"generator_check": "PASS", "scenes": index}, indent=2))


if __name__ == "__main__":
    main()
