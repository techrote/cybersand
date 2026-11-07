#!/usr/bin/env python3
"""Deterministic flat-colour SVG of the Mini Vault scene. Default writes preview.svg; --check compares."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
pack = json.loads((HERE / "pack.json").read_text(encoding="utf-8"))
colour = {m["id"]: "#%02x%02x%02x" % tuple(m["rgba"][:3]) for m in pack["palette"]}
scene = pack["scene"]
w, h = scene["size"]
rows = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (w * 8, h * 8, w, h),
        '<rect width="%d" height="%d" fill="%s"/>' % (w, h, colour[0])]


def stamp(items, ox, oy):
    for x, y, rw, rh, m in items:
        rows.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % (ox + x, oy + y, rw, rh, colour[m]))


stamp(scene["foundation"], 0, 0)
features = {f["id"]: f for f in pack["features"]}
for p in scene["placements"]:
    stamp(features[p["feature"]]["rectangles"], p["x"], p["y"])
rows.append("</svg>")
svg = "\n".join(rows) + "\n"
target = HERE / "preview.svg"
if "--check" in sys.argv:
    if not target.is_file() or target.read_text(encoding="utf-8") != svg:
        print("FAIL: preview.svg is stale")
        sys.exit(1)
    print("PASS: preview matches deterministic renderer")
else:
    target.write_text(svg, encoding="utf-8", newline="\n")
    print("WROTE preview.svg")
