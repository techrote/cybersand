#!/usr/bin/env python3
"""Original exact-grid native compositions for Strata Optics Lab.

No artwork is rasterized. Four explicit native material recipes share the
existing bounded showcase contract. Route probes are geometric authoring
checks, never evidence of physical traversal or perceptual understanding.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from strata2_build_showcases import PLANES, Layout, effect, finish, readable_json, route, scene

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "godot/data/strata3"
GENERATOR = "tools/strata3_build_showcases.py"


def optics_scene(identity: str, title: str, description: str, extent: tuple[int, int], seed: int) -> tuple[dict, dict[str, Layout]]:
    raw, layers = scene(identity, title, description, extent, seed)
    raw["provenance"]["generator"] = GENERATOR
    raw["provenance"]["generator_version"] = 1
    return raw, layers


def sunward_freight() -> dict:
    raw, layers = optics_scene("sunward-freight-megastructure", "Sunward Freight Megastructure",
        "An open freight hall with physical maintenance terraces, a clear central flight shaft, rear crane ribs and a sunlit distant logistics horizon. Compare sharp architectural, warm scattering and shallow lens treatments without changing these native layouts.", (1536, 1024), 251103)
    p, s, e, b = (layers[k] for k in PLANES)
    p.deck(36, 906, 1464, 28, "amber")
    p.deck(36, 124, 1464, 24, "white")
    p.r(36, 148, 18, 758, "steel")
    p.r(1482, 148, 18, 758, "steel")
    for x, y, w in ((70, 620, 460), (1010, 470, 440), (110, 330, 330), (1110, 710, 340)):
        p.deck(x, y, w, 20, "amber")
        p.r(x + 18, 150, 6, y - 150, "cable")
        p.r(x + w - 22, 150, 6, y - 150, "cable")
        for bx in range(x + 45, x + w - 25, 100):
            p.r(bx, y - 28, 3, 28, "steel")
            p.r(bx, y - 28, 42, 3, "steel")
    for x, w, h in ((82, 130, 84), (228, 90, 58), (1270, 100, 74), (1382, 70, 50)):
        p.cargo(x, 906 - h, w, h, "rust" if x < 400 else "painted")
    p.r(64, 898, 1398, 4, "hazard")
    for x in (106, 446, 846, 1200):
        s.frame(x, 194, 214, 452, 8, "steel")
        s.r(x + 19, 215, 176, 44, "corrugated")
        s.truss(x + 10, 274, 194, 54, 3, "painted")
        s.r(x + 29, 334, 5, 260, "copper_pipe")
        s.r(x + 180, 334, 5, 260, "pipe")
        s.frame(x + 40, 470, 134, 144, 5, "painted")
        s.windows(x + 51, 483, 112, 112, x, "amber", 26)
    s.truss(100, 680, 1332, 64, 10, "steel")
    s.pipe([(100, 794), (1440, 794), (1440, 580)], 8, "copper_pipe")
    for x in (320, 660, 1060):
        s.frame(x, 196, 112, 74, 5, "steel")
        s.r(x + 24, 270, 5, 156, "cable")
        s.r(x + 82, 270, 5, 156, "cable")
        s.frame(x + 12, 424, 92, 60, 5, "rust")
    for x, y in ((206, 372), (584, 500), (954, 296), (1274, 610)):
        e.frame(x, y, 86, 42, 3, "carbon")
        e.r(x + 9, y + 10, 52, 3, "amber")
        e.r(x + 9, y + 20, 32, 2, "white")
        e.r(x + 67, y + 8, 3, 22, "cyan")
    for x, y, w, h in ((150, 300, 180, 528), (390, 380, 220, 448), (920, 310, 188, 518), (1164, 250, 230, 578)):
        b.r(x, y, w, h, "carbon")
        b.frame(x, y, w, h, 5, "corrugated")
        b.windows(x + 18, y + 28, w - 36, h - 60, x + y, "amber", 38)
        b.r(x + w // 3, y - 35, w // 3, 35, "steel")
    b.r(100, 824, 1330, 20, "corrugated")
    b.truss(330, 405, 588, 36, 8, "carbon")
    raw["spawn"] = [768, 814]
    raw["route_probes"] = [route("clear-central-freight-shaft", [768, 814], [768, 214]), route("lower-flight-corridor", [420, 814], [1180, 814])]
    raw["detail_views"] = [{"id":"physical-terrace-rear-crane", "center":[500, 590], "zoom":1.1}, {"id":"freight-light-and-silhouette", "center":[1080, 390], "zoom":1.25}]
    raw["presentation"] = {"fog_strength":0.20, "parallax_strength":0.42}
    raw["atmosphere"]["effects"] = [
        effect("sun-shafts", "light_shaft", "effects", [330, 155, 900, 680], seed=3, count=4, speed=0.0, strength=0.60, direction=[0.26, 1.0], colour=[1.0, 0.82, 0.48, 0.45]),
        effect("machine-pools", "light_pool", "scripted", [126, 670, 1280, 105], seed=4, count=5, speed=0.0, strength=0.7, direction=[0.0, 0.0], colour=[0.26, 0.70, 0.84, 0.42]),
        effect("suspended-freight-dust", "dust", "effects", [220, 240, 1100, 580], seed=5, count=34, speed=1.4, strength=0.45, direction=[0.6, -0.12], colour=[0.86, 0.71, 0.43, 0.60]),
        effect("rear-service-steam", "steam", "effects", [1040, 590, 100, 190], seed=6, count=12, speed=9.0, strength=0.45, direction=[-0.1, -1.0], colour=[0.63, 0.67, 0.61, 0.45]),
    ]
    return finish(raw, layers, (0.33, 0.17, 0.88), (0.78, 0.76, 0.47))


def xeno_grotto() -> dict:
    raw, layers = optics_scene("xeno-resonance-grotto", "Xeno Resonance Grotto",
        "An alien cave with exact horizontal physical shelves, rooted rear mineral ribs, a broad central void and sparse luminous growth. Violet distance and local cyan-green light challenge the industrial palette without changing native authority.", (1024, 1024), 251104)
    p, s, e, b = (layers[k] for k in PLANES)
    for x in range(24, 1000, 16):
        ceiling = 72 + round(28 * math.sin(x * 0.021) + 12 * math.sin(x * 0.067))
        floor_y = 928 + round(22 * math.sin(x * 0.017) + 9 * math.cos(x * 0.049))
        p.r(x, 24, 16, ceiling, "basalt")
        p.r(x, floor_y, 16, 1000 - floor_y, "basalt")
    for y in range(80, 928, 16):
        left = 42 + round(13 * math.sin(y * 0.019))
        right = 44 + round(14 * math.cos(y * 0.015))
        p.r(24, y, left, 16, "basalt")
        p.r(1000 - right, y, right, 16, "basalt")
    for x, y, w in ((80, 354, 272), (722, 512, 218), (112, 734, 262), (644, 790, 292)):
        p.r(x, y, w, 29, "basalt")
        p.r(x + 8, y + 29, w - 18, 17, "obsidian")
        p.deck(x + 9, y - 12, w - 18, 12, "cyan")
    p.r(92, 324, 6, 30, "steel")
    p.r(336, 324, 6, 30, "steel")
    p.cargo(150, 662, 92, 60, "painted")
    for cx, cy, rx, ry in ((230, 258, 136, 150), (800, 330, 138, 174), (228, 680, 146, 174), (812, 690, 138, 180)):
        s.ring(cx, cy, rx, ry, 13, "obsidian")
        s.ring(cx, cy, rx - 18, ry - 22, 3, "moss")
        s.r(cx - 3, cy + ry - 12, 7, min(50, 960 - cy - ry), "basalt")
    s.frame(318, 404, 112, 248, 7, "rust")
    s.frame(610, 420, 108, 270, 7, "rust")
    s.pipe([(338, 420), (338, 626), (410, 626)], 5, "copper_pipe")
    s.pipe([(630, 438), (630, 670), (700, 670)], 5, "pipe")
    s.truss(236, 854, 556, 34, 6, "steel")
    for x, y in ((146, 226), (300, 278), (770, 190), (878, 384), (210, 602), (838, 652), (384, 500), (668, 580)):
        e.ring(x, y, 12, 20, 4, "moss")
        e.r(x - 3, y - 10, 6, 19, "cyan")
        e.r(x - 1, y + 19, 3, 20, "moss")
    for x in range(64, 960, 32):
        height = 126 + round(30 * math.sin(x * 0.012))
        b.r(x, 70, 32, height, "obsidian")
        lower = 878 + round(32 * math.sin(x * 0.018))
        b.r(x, lower, 32, 970 - lower, "obsidian")
    for y in range(200, 870, 32):
        width = 105 + round(26 * math.sin(y * 0.020))
        b.r(60, y, width, 32, "carbon")
        b.r(964 - width, y, width, 32, "carbon")
    b.ring(512, 554, 330, 340, 24, "obsidian")
    raw["spawn"] = [512, 826]
    raw["route_probes"] = [route("clear-resonance-void", [512, 826], [512, 214])]
    raw["detail_views"] = [{"id":"physical-shelf-and-organic-rib", "center":[298, 350], "zoom":1.4}, {"id":"luminous-relic-and-void", "center":[644, 654], "zoom":1.25}]
    raw["presentation"] = {"fog_strength":0.24, "parallax_strength":0.40}
    raw["atmosphere"]["effects"] = [
        effect("organic-light", "light_pool", "effects", [118, 212, 800, 580], seed=11, count=6, speed=0.22, strength=0.62, direction=[0.0, 0.0], colour=[0.21, 0.84, 0.66, 0.42]),
        effect("mineral-mist", "haze", "effects", [180, 690, 650, 190], seed=12, count=24, speed=2.6, strength=0.55, direction=[0.4, -0.1], colour=[0.42, 0.30, 0.62, 0.55]),
        effect("floating-spores", "dust", "effects", [130, 200, 760, 640], seed=13, count=40, speed=1.2, strength=0.42, direction=[0.13, -0.36], colour=[0.44, 0.83, 0.60, 0.68]),
        effect("ceiling-light", "light_shaft", "background", [340, 156, 360, 700], seed=14, count=2, speed=0.0, strength=0.42, direction=[-0.08, 1.0], colour=[0.42, 0.55, 0.78, 0.40]),
    ]
    return finish(raw, layers, (0.34, 0.18, 0.91), (0.76, 0.76, 0.45))


def lunar_observatory() -> dict:
    raw, layers = optics_scene("lunar-terminator-observatory", "Lunar Terminator Observatory",
        "A sparse lunar facility with physical observation decks, separate rear instrument frames, distant stepped ridges and a planetary rim. Large negative sky space supports a low-haze, high-clarity optical study.", (1536, 768), 251105)
    p, s, e, b = (layers[k] for k in PLANES)
    p.r(26, 676, 1484, 48, "basalt")
    p.deck(26, 662, 1484, 14, "amber")
    for x, y, w in ((98, 458, 380), (1106, 420, 342)):
        p.deck(x, y, w, 20, "white")
        p.r(x + 24, y + 20, 12, 662 - y - 20, "aluminium")
        p.r(x + w - 34, y + 20, 12, 662 - y - 20, "aluminium")
        p.r(x + 14, y - 30, 3, 30, "steel")
        p.r(x + w - 17, y - 30, 3, 30, "steel")
        p.r(x + 14, y - 30, w - 28, 3, "steel")
    p.cargo(124, 604, 96, 58, "heatshield")
    p.cargo(1330, 608, 110, 54, "polymer")
    p.r(38, 656, 1458, 3, "hazard")
    s.frame(86, 178, 358, 224, 8, "aluminium")
    s.ring(264, 260, 124, 74, 7, "steel")
    s.ring(264, 260, 82, 48, 4, "solar")
    s.r(260, 332, 9, 254, "steel")
    s.truss(140, 560, 310, 36, 5, "steel")
    s.r(154, 596, 12, 54, "steel")
    s.r(418, 596, 12, 54, "steel")
    for x in (526, 744, 962):
        s.frame(x, 376, 164, 112, 5, "steel")
        s.r(x + 6, 382, 152, 100, "solar")
        for dx in range(18, 150, 24): s.r(x + dx, 382, 2, 100, "aluminium")
        for dy in (25, 51, 77): s.r(x + 6, 382 + dy, 152, 2, "aluminium")
        s.r(x + 76, 488, 10, 145, "steel")
    s.frame(1182, 190, 216, 168, 7, "aluminium")
    s.r(1204, 212, 174, 112, "dark_glass")
    s.r(1286, 102, 8, 88, "steel")
    s.r(1250, 130, 80, 4, "steel")
    s.r(1270, 112, 40, 4, "steel")
    s.pipe([(1130, 588), (1420, 588), (1420, 370)], 6, "pipe")
    for x, y in ((494, 516), (880, 536), (1130, 318)):
        e.frame(x, y, 68, 40, 3, "carbon")
        e.r(x + 8, y + 8, 46, 3, "cyan")
        e.r(x + 8, y + 19, 26, 2, "amber")
    b.ring(938, 238, 158, 144, 24, "carbon")
    b.ring(938, 238, 140, 126, 3, "aluminium")
    for x in range(46, 1488, 42):
        height = 70 + round(50 * (0.5 + 0.5 * math.sin(x * 0.009)))
        b.r(x, 646 - height, 42, height, "obsidian")
        if x % 3 == 0: b.r(x + 10, 630 - height, 22, 16, "carbon")
    b.frame(590, 488, 310, 134, 5, "carbon")
    b.windows(614, 510, 262, 90, 251105, "amber", 34)
    raw["spawn"] = [768, 588]
    raw["route_probes"] = [route("open-observatory-flight", [524, 588], [1030, 588]), route("clear-lunar-sky", [768, 588], [768, 162])]
    raw["detail_views"] = [{"id":"physical-deck-rear-instrument", "center":[350, 418], "zoom":1.3}, {"id":"solar-lattice-and-rim", "center":[994, 364], "zoom":1.3}]
    raw["presentation"] = {"fog_strength":0.16, "parallax_strength":0.34}
    raw["atmosphere"]["effects"] = [
        effect("instrument-light", "light_pool", "scripted", [510, 360, 640, 155], seed=21, count=3, speed=0.0, strength=0.42, direction=[0.0, 0.0], colour=[0.32, 0.60, 0.85, 0.38]),
        effect("sunward-rim-light", "light_shaft", "background", [320, 100, 940, 530], seed=22, count=2, speed=0.0, strength=0.32, direction=[0.42, 1.0], colour=[0.92, 0.82, 0.59, 0.32]),
        effect("observatory-signals", "beacon", "scripted", [1190, 186, 200, 10], seed=23, count=3, speed=0.30, strength=0.48, direction=[0.0, 0.0], colour=[0.96, 0.59, 0.18, 0.55]),
    ]
    return finish(raw, layers, (0.32, 0.16, 0.94), (0.76, 0.73, 0.44))


BUILDERS = (sunward_freight, xeno_grotto, lunar_observatory)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    results = []
    for builder in BUILDERS:
        document = builder()
        encoded = readable_json(document)
        path = OUTPUT / (document["id"] + ".json")
        if args.check:
            assert path.read_text() == encoded, f"Generated source differs: {path}"
        else:
            path.write_text(encoded)
        assert len(document["play_rectangles"]) <= 4096
        results.append({"id":document["id"], "extent":document["extent"],
            "native_rectangles":document["provenance"]["ordered_rectangles"],
            "native_write_cells":document["provenance"]["authored_write_cells"],
            "visual_motifs":sum(e["count"] for e in document["atmosphere"]["effects"]),
            "sha256":hashlib.sha256(encoded.encode()).hexdigest()})
    print(json.dumps({"generator_check":"PASS", "scenes":results}, indent=2))


if __name__ == "__main__":
    main()
