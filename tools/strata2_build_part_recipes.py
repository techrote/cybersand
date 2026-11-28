#!/usr/bin/env python3
"""Original native parts and layered design recipes for the strict module codec.

The interchange remains explicit material rectangles.  The Strata module
builder must expand these into uint16LE material cells plus a separate write
mask and admit them through its own strict checksum/version contract.
Untouched cells mean no write; no part requests clearing existing materials.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct

from strata2_build_showcases import Layout, M, digest, effect, readable_json


def part(identity: str, name: str, size: tuple[int, int], rows: Layout,
         anchor: tuple[int, int] = (0, 0), clearances: list | None = None) -> dict:
    materials = sorted({r[4] for r in rows.rectangles})
    signals = [m for m in materials if m in (77, 78, 79, 80)]
    structure = [m for m in materials if m not in signals]
    roles = []
    if structure:
        roles.append({"name": "structure", "material_ids": structure,
                      "compatible_materials": [57, 58, 62, 63, 64, 65, 66, 68, 69, 72, 74, 100, 101, 114, 119, 128, 130], "source": "authored"})
    if signals:
        roles.append({"name": "signal", "material_ids": signals,
                      "compatible_materials": [77, 78, 79, 80], "source": "authored"})
    return {"id": identity, "name": name, "extent": list(size), "rectangles": rows.rectangles,
            "no_write_material": 0, "explicit_empty_cells": [],
            "anchor": list(anchor), "roles": roles, "clearances": clearances or [], "protected_regions": [],
            "provenance": {"kind": "original-native-part", "generator": "tools/strata2_build_part_recipes.py",
                           "generator_version": 1, "ordered_recipe_sha256": digest(rows.rectangles),
                           "authoring_semantics": "Original native material IDs; untouched cells are mask0/no-write; no claimed structural solver."}}


def parts() -> list[dict]:
    result = []
    g = Layout(128, 80)
    g.truss(7, 9, 114, 60, 3)
    g.r(12, 14, 18, 2, "amber")
    result.append(part("rear-truss-bay", "Rear truss bay", (128, 80), g, (7, 9)))
    g = Layout(128, 128)
    g.frame(8, 8, 112, 112, 8, "steel")
    g.frame(23, 23, 82, 82, 4, "copper_pipe")
    g.r(36, 38, 56, 7, "grating")
    g.r(36, 84, 56, 7, "grating")
    g.r(43, 29, 20, 3, "amber")
    result.append(part("reactor-window", "Hollow reactor window", (128, 128), g, (8, 8), [[36, 50, 56, 28]]))
    g = Layout(128, 96)
    g.pipe([(8, 16), (48, 16), (48, 66), (112, 66)], 7, "copper_pipe")
    for x, y in ((12, 14), (46, 42), (94, 64)):
        g.r(x, y, 11, 11, "steel")
    result.append(part("service-pipe", "Service pipe elbow", (128, 96), g, (8, 16)))
    g = Layout(64, 96)
    g.frame(8, 8, 48, 80, 4, "steel")
    for y, w, material in ((19, 24, "cyan"), (32, 32, "amber"), (45, 24, "cyan"), (58, 32, "white"), (71, 19, "magenta")):
        g.r(16, y, w, 4, material)
    result.append(part("signal-panel", "Signal panel", (64, 96), g, (8, 8)))
    g = Layout(96, 128)
    g.r(17, 94, 62, 18, "grating")
    g.r(14, 112, 68, 7, "steel")
    g.pipe([(24, 87), (24, 48), (40, 48)], 7, "pipe")
    g.pipe([(64, 87), (64, 30), (50, 30)], 7, "pipe")
    g.r(24, 94, 10, 3, "amber")
    result.append(part("vent-stack", "Paired vent stack", (96, 128), g, (14, 112), [[35, 6, 28, 18]]))
    g = Layout(128, 128)
    g.frame(5, 5, 118, 118, 5, "painted")
    for y in (20, 52, 84):
        for x in (18, 52, 86):
            g.frame(x, y, 24, 26, 3, "steel")
            g.r(x + 6, y + 8, 12, 9, "amber" if (x + y) % 3 else "cyan")
    result.append(part("habitation-lattice", "Habitation light lattice", (128, 128), g, (5, 5)))
    g = Layout(128, 96)
    g.cargo(12, 28, 104, 60, "corrugated")
    g.r(22, 16, 84, 12, "steel")
    result.append(part("cargo-cell", "Cargo cell", (128, 96), g, (12, 28)))
    g = Layout(96, 128)
    g.r(20, 35, 58, 86, "carbon")
    g.r(31, 20, 36, 15, "steel")
    g.r(47, 6, 5, 14, "aluminium")
    g.windows(28, 47, 42, 63, 19, "cyan", 17)
    result.append(part("distant-spire", "Distant service spire", (96, 128), g, (20, 121)))
    return result


def stage(identity: str, plane: str, module: dict, origin: tuple[int, int], dependencies: list[str] | None = None,
          transform: str = "identity") -> dict:
    # Each stage is one <=128-square part. Stages are intentionally serial so
    # native receipt ordering and per-plane history remain visible to the owner.
    width, height = module["extent"]
    if transform in ("rotate90", "rotate270"):
        width, height = height, width
    return {"id": identity, "plane": plane, "region": [*origin, width, height],
            "depends_on": dependencies or [], "allowed_materials": [0] + sorted({r[4] for r in module["rectangles"]}),
            "protected_regions": [], "placements": [{"module_id": module["id"], "origin": list(origin),
                                                       "transform": transform, "palette": {}, "empty_mode": "preserve"}]}


def compositions(available: list[dict]) -> list[dict]:
    modules = {p["id"]: p for p in available}
    result = []
    definitions = [
        ("factory-service-bay", "Factory service bay", [
            stage("rear-bay", "scripted", modules["rear-truss-bay"], (0, 0)),
            stage("cargo", "scripted", modules["cargo-cell"], (0, 92), ["rear-bay"]),
            stage("vent", "effects", modules["vent-stack"], (132, 56), ["rear-bay"]),
            stage("far-spire", "background", modules["distant-spire"], (64, 32)),
        ], effect("factory-steam", "steam", "effects", [150, 62, 60, 88], seed=101, count=22, speed=16.0,
                  strength=0.75, direction=[0.10, -1.0], colour=[0.62, 0.76, 0.82, 0.80])),
        ("reactor-service-arch", "Reactor service arch", [
            stage("reactor", "scripted", modules["reactor-window"], (0, 0)),
            stage("pipe", "scripted", modules["service-pipe"], (132, 16), ["reactor"]),
            stage("signals", "effects", modules["signal-panel"], (132, 114), ["reactor"]),
            stage("far-bay", "background", modules["rear-truss-bay"], (0, 130)),
        ], effect("reactor-beacons", "beacon", "scripted", [24, 12, 80, 8], seed=102, count=3, speed=0.80,
                  strength=0.80, direction=[1.0, 0.0], colour=[1.0, 0.33, 0.08, 0.85])),
        ("inhabited-skybridge", "Inhabited skybridge", [
            stage("rear-lattice", "scripted", modules["habitation-lattice"], (0, 0)),
            stage("bridge-a", "scripted", modules["rear-truss-bay"], (130, 48), ["rear-lattice"]),
            stage("bridge-b", "scripted", modules["rear-truss-bay"], (258, 48), ["bridge-a"]),
            stage("sign", "effects", modules["signal-panel"], (130, 136), ["rear-lattice"]),
            stage("far-spire", "background", modules["distant-spire"], (252, 2)),
        ], effect("skybridge-rain", "rain", "effects", [0, 0, 384, 230], seed=103, count=48, speed=42.0,
                  strength=0.75, direction=[0.20, 1.0], colour=[0.40, 0.68, 0.90, 0.75])),
    ]
    for identity, name, stages, atmosphere in definitions:
        visual_choices = {
            "factory-service-bay": (0.82, 0.30, 0.82, 0.15, 0.45, 0.82, 0.45, 0.28),
            "reactor-service-arch": (0.78, 0.28, 0.85, 0.16, 0.40, 0.82, 0.40, 0.30),
            "inhabited-skybridge": (0.78, 0.31, 0.85, 0.16, 0.44, 0.86, 0.50, 0.34),
        }
        opacity_s, depth_s, opacity_e, depth_e, opacity_b, depth_b, parallax, haze = visual_choices[identity]
        result.append({"format": "cybersand-strata-composition-v1", "id": identity, "name": name,
                       "modules": sorted({placement["module_id"] for entry in stages for placement in entry["placements"]}),
                       "stages": stages, "metadata": {
                           "provenance": {"kind": "original-layered-design", "generator": "tools/strata2_build_part_recipes.py",
                                          "generator_version": 1, "semantic_limits": "Explicit decorative parts, no Play mutation and no load-bearing solver."},
                           "visual_proposal": {"planes": [
                               {"id": "scripted", "opacity": opacity_s, "depth": depth_s},
                               {"id": "effects", "opacity": opacity_e, "depth": depth_e},
                               {"id": "background", "opacity": opacity_b, "depth": depth_b}],
                               "presentation": {"parallax_strength": parallax, "fog_strength": haze}},
                           "atmosphere_proposal": {"scope": "Anchor-relative regions; separately review and apply; native plan does not apply atmosphere.",
                                                   "configuration": {"version": 1, "enabled": True, "paused": False,
                                                                     "seed": 1207, "effects": [atmosphere]}}}})
    return result


def packaged_module(recipe: dict) -> dict:
    """Encode the frozen StrataModule-v1 contract; Godot independently validates."""
    width, height = recipe["extent"]
    cells = bytearray(width * height * 2)
    mask = bytearray(width * height)
    for x, y, w, h, material in recipe["rectangles"]:
        row = struct.pack("<H", material) * w
        for yy in range(y, y + h):
            start = yy * width + x
            cells[start * 2:(start + w) * 2] = row
            mask[start:start + w] = b"\1" * w
    for x, y, w, h in recipe["clearances"] + recipe["protected_regions"]:
        for yy in range(y, y + h):
            assert not any(mask[yy * width + x:yy * width + x + w]), recipe["id"]
    module = {"format": "cybersand-strata-module-v1", "id": recipe["id"], "name": recipe["name"],
              "extent": recipe["extent"], "anchor": recipe["anchor"],
              "allowed_transforms": ["identity", "mirror_x", "mirror_y", "rotate_90", "rotate_180", "rotate_270"],
              "roles": recipe["roles"], "clearances": recipe["clearances"], "protected_regions": recipe["protected_regions"],
              "geometry": {"encoding": "uint16-le-row-major", "cells_base64": base64.b64encode(cells).decode(),
                           "write_mask_base64": base64.b64encode(mask).decode(), "sha256": hashlib.sha256(cells).hexdigest(),
                           "mask_sha256": hashlib.sha256(mask).hexdigest()}, "provenance": recipe["provenance"]}
    module["content_sha256"] = digest(module)
    return module


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Optional recipe interchange destination; not itself an admitted native module.")
    parser.add_argument("--package", action="store_true", help="Write strict module and composition JSON files to the source catalogue.")
    parser.add_argument("--check", action="store_true", help="Check source catalogue bytes without rewriting them.")
    args = parser.parse_args()
    generated = parts()
    payload = {"format": "cybersand-strata-original-part-recipes-v1", "parts": generated, "compositions": compositions(generated)}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(readable_json(payload))
    if args.package or args.check:
        root = Path(__file__).resolve().parents[1] / "godot/data/strata2"
        documents = [("modules", packaged_module(recipe)) for recipe in generated]
        documents += [("compositions", preset) for preset in payload["compositions"]]
        for directory, document in documents:
            path = root / directory / (document["id"] + ".json")
            encoded = readable_json(document)
            if args.check:
                assert path.read_text() == encoded, f"Packaged source differs: {path}"
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(encoded)
    print(json.dumps({"output": str(args.output), "parts": len(generated), "compositions": len(payload["compositions"]),
                      "recipe_sha256": digest(payload), "explicit_empty_cells": 0, "maximum_part_cells": max(p["extent"][0] * p["extent"][1] for p in generated)}))


if __name__ == "__main__":
    main()
