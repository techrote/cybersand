#!/usr/bin/env python3
"""Validate Lumen Fault authoring-proposal geometry against current local native IDs."""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def check(cond, why):
    if not cond:
        raise ValueError(why)

pack = json.loads((HERE / "pack.json").read_text(encoding="utf-8"))
native = (ROOT / "native/include/cybersand/material.hpp").read_text(encoding="utf-8")
native_ids = {int(n) for n in re.findall(r"^\s*[A-Za-z][A-Za-z0-9]*\s*=\s*(\d+),", native, re.M)}
shadow = json.loads((ROOT / "materials/catalogue/catalogue.json").read_text(encoding="utf-8"))
auth = {m["id"]: m for m in shadow["native"]["materials"]}
palette = {m["id"]: m for m in pack["palette"]}

check(pack["schema_id"] == "cybersand.world-feature-pack.proposal", "wrong draft schema")
for material_id, description in palette.items():
    check(material_id in native_ids and material_id != 10, "invalid native material ID "+str(material_id))
    check(material_id in auth and auth[material_id]["valid"], "missing catalogue record")
    check(all(description[key] == auth[material_id][key] for key in ("name","rgba","state","movable","kernel")),
          "shadow RGBA/physics mismatch at "+str(material_id))

def rectangles(items, extent, label, moving):
    for r in items:
        check(type(r) is list and len(r) == 5 and all(type(x) is int for x in r), label+" invalid rectangle")
        x,y,w,h,m = r
        check(x >= 0 and y >= 0 and w > 0 and h > 0 and x+w <= extent[0] and y+h <= extent[1],
              label+" out of bounds "+str(r))
        check(m in palette, label+" unknown material "+str(m))
        check(moving or not palette[m]["movable"], label+" static module contains movable material")

features = {f["id"]: f for f in pack["features"]}
check(len(features) == len(pack["features"]) == 8, "missing or duplicate feature")
for name,f in features.items():
    rectangles(f["rectangles"],f["size"],name,f["status"] != "static")
    present = {r[4] for r in f["rectangles"]}
    for variant in f["variants"]:
        for old,new in variant["swap"].items():
            check(int(old) in present and new in native_ids and new in auth and auth[new]["valid"],
                  "invalid material swap "+name+"/"+variant["id"])

scene = pack["scene"]
rectangles(scene["rectangles"],scene["size"],"composite",False)
for placement in scene["placements"]:
    f = features[placement["feature"]]
    x,y = placement["x"],placement["y"]
    check(x >= 0 and y >= 0 and x+f["size"][0] <= scene["size"][0] and y+f["size"][1] <= scene["size"][1],
          "out-of-bounds composite placement")
check(sum(r[4] == 3 for f in features.values() for r in f["rectangles"]) == 1, "cistern Water count drift")
print("PASS: 8 source-checked authoring pieces, bounds/variant/classification checks; native execution NOT performed")
