#!/usr/bin/env python3
"""Render the source-colour Signal Orchard SVG. Does not simulate native physics."""
import json
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
p = json.loads((here / "pack.json").read_text())
mat = {m["id"]: m for m in p["palette"]}
features = p["features"]
placements = p["scene"]["placements"]

def R(r):
    m = mat[r[4]]
    colour = ",".join(map(str, m["rgba"][:3]))
    opacity = m["rgba"][3] / 255
    return ('<rect x="' + str(r[0]) + '" y="' + str(r[1])
            + '" width="' + str(r[2]) + '" height="' + str(r[3])
            + '" fill="rgb(' + colour + ')" opacity="' + f"{opacity:.3f}" + '"/>')

out = [
    '<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="980" viewBox="0 0 1440 980" role="img" aria-label="Signal Orchard material cells">',
    '<rect width="1440" height="980" fill="#0b131b"/>',
    '<rect width="1440" height="102" fill="#192830"/>',
    '<text x="50" y="44" font-family="monospace" font-size="34" fill="#e9f3e1">SIGNAL / ORCHARD</text>',
    '<text x="50" y="75" font-family="monospace" font-size="14" fill="#a2d4bf">CYBERSAND WORLD DESIGN 007 • SOURCE-COLOUR PROPOSAL / T=0</text>',
    '<text x="50" y="124" font-family="monospace" font-size="16" fill="#b6e8d2">01 / QUIET SIGNAL PROSPECT • 1220 x 296 DRY CELLS</text>',
    '<rect x="45" y="138" width="1350" height="320" rx="8" fill="#070e18" stroke="#4b6260"/>',
    '<g transform="translate(80 146) scale(1.04)">',
    *map(R, p["scene"]["terrain_rectangles"]),
]
for z in placements:
    f = next(f for f in features if f["id"] == z["feature"])
    v = next(v for v in f["variants"] if v["id"] == z["variant"])
    out.append('<g transform="translate(' + str(z["x"]) + ' ' + str(z["y"]) + ')">')
    for r in f["rectangles"]:
        out.append(R([*r[:4], v["swap"].get(str(r[4]), r[4])]))
    out.append("</g>")
out.extend([
    "</g>",
    '<text x="50" y="488" font-family="monospace" font-size="16" fill="#b6e8d2">02 / EIGHT ORIGINAL MODULES • 07 &amp; 08 MOBILE, UNTESTED</text>',
])
for k, f in enumerate(features):
    xx = 50 + (k % 4) * 348
    yy = 530 + (k // 4) * 212
    colour = "#f2b78a" if f["kind"] == "active-dynamic" else "#9ed3be"
    label = "MOBILE T=0 / NOT QUALIFIED" if f["kind"] == "active-dynamic" else "FIXED KERNEL-NONE"
    out.extend([
        '<rect x="' + str(xx) + '" y="' + str(yy - 24) + '" width="326" height="201" rx="8" fill="#14272e" stroke="#46645f"/>',
        '<text x="' + str(xx + 11) + '" y="' + str(yy) + '" font-family="monospace" font-size="13" fill="#e6ead8">' + str(k + 1).zfill(2) + " " + f["title"] + "</text>",
        '<text x="' + str(xx + 11) + '" y="' + str(yy + 19) + '" font-family="monospace" font-size="11" fill="' + colour + '">' + "x".join(map(str, f["size"])) + " • " + label + "</text>",
        '<rect x="' + str(xx + 9) + '" y="' + str(yy + 27) + '" width="307" height="144" fill="#07131c"/>',
        '<g transform="translate(' + str(xx + 100) + ' ' + str(yy + 31) + ') scale(1.1)">',
        *map(R, f["rectangles"]),
        "</g>",
    ])
out.extend([
    '<text x="50" y="969" font-family="monospace" font-size="12" fill="#9db4a9">DESIGN ONLY • DRY SCENE SUBSTITUTES WATER / SPARK • NOT SIMULATION OR GODOT RENDER</text>',
    "</svg>",
])
actual = "\n".join(out) + "\n"
path = here / "preview.svg"
if "--check" in sys.argv:
    if actual != path.read_text():
        print("FAIL: preview differs; source or renderer drift", file=sys.stderr)
        sys.exit(1)
    print(f"PASS preview identity ({len(actual)} characters)")
else:
    path.write_text(actual)
    print(f"Wrote {path}")
