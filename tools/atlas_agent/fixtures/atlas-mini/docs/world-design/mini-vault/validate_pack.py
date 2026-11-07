#!/usr/bin/env python3
"""Validate the synthetic Mini Vault pack against the fixture native IDs and catalogue."""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def check(condition, why):
    if not condition:
        print("FAIL: " + why)
        sys.exit(1)


pack = json.loads((HERE / "pack.json").read_text(encoding="utf-8"))
native = (ROOT / "native/include/cybersand/material.hpp").read_text(encoding="utf-8")
native_ids = {int(n) for n in re.findall(r"^\s*[A-Za-z][A-Za-z0-9]*\s*=\s*(\d+),", native, re.M)}
catalogue = json.loads((ROOT / "materials/catalogue/catalogue.json").read_text(encoding="utf-8"))
authority = {m["id"]: m for m in catalogue["native"]["materials"]}
palette = {m["id"]: m for m in pack["palette"]}

check(pack["schema_id"] == "cybersand.world-feature-pack.proposal", "wrong schema")
for material_id, description in palette.items():
    check(material_id in native_ids, f"unknown native material {material_id}")
    check(all(description[k] == authority[material_id][k] for k in ("name", "rgba", "state", "movable", "kernel")),
          f"palette mismatch at {material_id}")


def rectangles(items, extent, label):
    for r in items:
        check(type(r) is list and len(r) == 5 and all(type(x) is int for x in r), f"{label}: invalid rectangle {r}")
        x, y, w, h, m = r
        check(x >= 0 and y >= 0 and w > 0 and h > 0 and x + w <= extent[0] and y + h <= extent[1],
              f"{label}: out of bounds {r}")
        check(m in palette and not palette[m]["movable"], f"{label}: bad material {m}")


features = {f["id"]: f for f in pack["features"]}
check(len(features) == len(pack["features"]) == 2, "missing or duplicate feature")
for name, feature in features.items():
    rectangles(feature["rectangles"], feature["size"], name)
scene = pack["scene"]
rectangles(scene["foundation"], scene["size"], "foundation")
for p in scene["placements"]:
    f = features[p["feature"]]
    check(p["x"] >= 0 and p["y"] >= 0 and p["x"] + f["size"][0] <= scene["size"][0]
          and p["y"] + f["size"][1] <= scene["size"][1], f"placement out of bounds {p}")
print("PASS: %d features / %d rectangles / %d placements" % (
    len(features), sum(len(f["rectangles"]) for f in features.values()), len(scene["placements"])))
