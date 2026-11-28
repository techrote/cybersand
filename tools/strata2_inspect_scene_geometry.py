#!/usr/bin/env python3
"""Independent inspection of shipped native rectangle recipes.

This does not import the scene generator, create a native World, render an
image, or certify traversal. It checks final authored material arrays and
untransformed occupancy grammar before actual native and visual qualification.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path


PLANES = ("play", "scripted", "effects", "background")
IDS = ("orbital-terminal", "neon-rain-arcology", "industrial-underworks", "abyss-foundry", "vertical-transfer-spine")
ROOT = Path(__file__).resolve().parents[1]


def materials(rows: list, width: int, height: int) -> bytearray:
    values = bytearray(width * height)
    for x, y, w, h, material in rows:
        assert all(type(v) is int for v in (x, y, w, h, material))
        assert 1 <= x and 1 <= y and 1 <= w and 1 <= h and x + w < width and y + h < height
        assert 0 <= material <= 255
        for yy in range(y, y + h):
            values[yy * width + x:yy * width + x + w] = bytes([material]) * w
    return values


def u16_digest(values: bytearray) -> str:
    encoded = bytearray(len(values) * 2)
    encoded[::2] = values
    return hashlib.sha256(encoded).hexdigest()


def region_clear(values: bytearray, width: int, height: int, x0: int, y0: int, x1: int, y1: int) -> bool:
    if x0 < 1 or y0 < 1 or x1 >= width - 1 or y1 >= height - 1:
        return False
    return not any(any(values[y * width + x0:y * width + x1 + 1]) for y in range(y0, y1 + 1))


def inspect(identity: str) -> dict:
    path = ROOT / "godot/data/strata2" / (identity + ".json")
    source = path.read_bytes()
    raw = json.loads(source)
    width, height = raw["extent"]
    arrays = {plane: materials(raw["play_rectangles"] if plane == "play" else raw["planes"][plane]["rectangles"], width, height) for plane in PLANES}
    plane_rows = {}
    occupied_nearer = bytearray(width * height)
    for plane in PLANES:
        values = arrays[plane]
        counts = Counter(values)
        nonempty = len(values) - counts[0]
        exposed = sum(material != 0 and not occupied_nearer[index] for index, material in enumerate(values))
        plane_rows[plane] = {"native_recipe_uint16le_sha256": u16_digest(values), "nonempty_cells": nonempty,
                             "nonempty_fraction": nonempty / len(values), "exposed_without_nearer_opaque_geometry": exposed,
                             "material_counts": dict(sorted((key, count) for key, count in counts.items() if key))}
        for index, material in enumerate(values):
            if material:
                occupied_nearer[index] = 1
    routes = []
    for probe in raw["route_probes"]:
        x0, y0 = probe["from"]
        x1, y1 = probe["to"]
        radius = probe["clearance_radius"]
        assert x0 == x1 or y0 == y1, "This independent straight-route check admits axis-aligned proposals only."
        clear = region_clear(arrays["play"], width, height, min(x0, x1) - radius, min(y0, y1) - radius,
                             max(x0, x1) + radius, max(y0, y1) + radius)
        routes.append({"id": probe["id"], "square_radius": radius, "clear": clear,
                       "length_cells": max(abs(x1 - x0), abs(y1 - y0)), "from": probe["from"], "to": probe["to"]})
        assert clear, (identity, probe["id"])
    sx, sy = raw["spawn"]
    spawn_radius = 0
    for radius in range(1, 257):
        if not region_clear(arrays["play"], width, height, sx - radius, sy - radius, sx + radius, sy + radius):
            break
        spawn_radius = radius
    assert spawn_radius >= 34, (identity, "spawn aperture")
    native_hashes = [plane_rows[plane]["native_recipe_uint16le_sha256"] for plane in PLANES]
    assert len(set(native_hashes)) == 4, (identity, "duplicated plane geometry")
    return {"id": identity, "source_file_sha256": hashlib.sha256(source).hexdigest(), "extent": raw["extent"],
            "planes": plane_rows, "all_native_union_cells": sum(occupied_nearer),
            "all_native_union_fraction": sum(occupied_nearer) / len(occupied_nearer),
            "spawn": raw["spawn"], "spawn_clear_square_radius": spawn_radius,
            "routes": routes, "atmosphere_effects": len(raw["atmosphere"]["effects"]),
            "bounded_visual_motifs": sum(effect["count"] for effect in raw["atmosphere"]["effects"]),
            "scope": "Final authored cells and untransformed opaque occupancy only. Opacity/parallax/physical stability and actual actor traversal require native/framebuffer witnesses."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    scenes = [inspect(identity) for identity in IDS]
    report = {"schema": "strata2-independent-geometry-review-v1", "check": "PASS", "scenes": scenes,
              "limitations": ["No native World or GPU execution in this inspection.", "Zero parallax and opaque silhouettes are analytic comparison controls, not actual composite visibility.", "Route geometry is not a movement, rotation, load or playability result."]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    for row in scenes:
        print(json.dumps({"id": row["id"], "play_fraction": round(row["planes"]["play"]["nonempty_fraction"], 4),
                          "native_union_fraction": round(row["all_native_union_fraction"], 4),
                          "unoccluded_distant_cells": row["planes"]["background"]["exposed_without_nearer_opaque_geometry"],
                          "spawn_clear_square_radius": row["spawn_clear_square_radius"], "geometric_routes": len(row["routes"])}))


if __name__ == "__main__":
    main()
