#!/usr/bin/env python3
"""Independent four-connected Wood/Wall oracle for the Lab's authored fixtures.

Input is the exact JSON exported by CyberObjectShardLabPresets.edits, not a
reimplementation of its scene authoring. This utility never reads production
component labels, mutation queues, body geometry or admission decisions. It
checks the declared scenario-0 perimeter and ordinary Wood-only horizontal cut.
It does not claim arbitrary material cohesion, exact Rapier shapes or motion.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
from pathlib import Path


def components(image: list[int], width: int, height: int) -> list[dict]:
    seen: set[tuple[int, int]] = set()
    result: list[dict] = []
    for y in range(height):
        for x in range(width):
            if image[y * width + x] != 7 or (x, y) in seen:
                continue
            frontier = deque([(x, y)])
            seen.add((x, y))
            members: list[tuple[int, int]] = []
            anchored = unknown = False
            while frontier:
                cx, cy = frontier.popleft()
                members.append((cx, cy))
                for dx, dy in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                    nx, ny = cx + dx, cy + dy
                    if not 0 <= nx < width or not 0 <= ny < height:
                        unknown = True
                        continue
                    material = image[ny * width + nx]
                    anchored |= material == 1
                    if material == 7 and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        frontier.append((nx, ny))
            min_x = min(a for a, _ in members)
            min_y = min(b for _, b in members)
            max_x = max(a for a, _ in members)
            max_y = max(b for _, b in members)
            result.append({
                "cells": len(members), "bounds": [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1],
                "bbox_area_with_ring": (max_x - min_x + 3) * (max_y - min_y + 3),
                "anchored": anchored, "unknown_boundary": unknown,
                "membership_sha256": hashlib.sha256(json.dumps(sorted(members)).encode()).hexdigest(),
            })
    return result


def inspect(document: dict, max_area: int = 4096) -> dict:
    cases = []
    for case in document["cases"]:
        preset = case["preset"]
        width, height = preset["width"], preset["height"]
        if (preset["scenario"] != 0 or type(width) is not int or type(height) is not int or
                not 64 <= width <= 512 or not 64 <= height <= 512 or width * height > 262144):
            raise ValueError("oracle supports bounded scenario-0 authored fixtures only")
        image = [0] * (width * height)
        for y in range(height):
            for x in range(width):
                if x in (0, width - 1) or y in (0, height - 1, height - 2):
                    image[y * width + x] = 1
        for operation in case["edits"]:
            x, y = operation["position"]
            material = operation["material"]
            if (type(x) is not int or type(y) is not int or not 0 <= x < width or not 0 <= y < height or
                    type(material) is not int or material not in (0, 1, 7)):
                raise ValueError("fixture outside the explicit Empty/Wall/Wood oracle capability")
            image[y * width + x] = material
        before = components(image, width, height)
        cut_y = case["cut_y"]
        if type(cut_y) is not int or not 0 <= cut_y < height:
            raise ValueError("ordinary cut lies outside resident fixture")
        cut_count = 0
        for x in range(width):
            if image[cut_y * width + x] == 7:
                image[cut_y * width + x] = 0
                cut_count += 1
        after = components(image, width, height)
        eligible = lambda rows: [row for row in rows if not row["anchored"] and
            not row["unknown_boundary"] and row["bbox_area_with_ring"] <= max_area]
        cases.append({
            "id": preset["id"], "width": width, "height": height,
            "before_cut": before, "after_cut": after, "wood_cells_erased": cut_count,
            "initial_eligible": len(eligible(before)), "cut_eligible": len(eligible(after)),
            "largest_three_cells_before_shape_admission": sorted((row["cells"] for row in eligible(after)), reverse=True)[:3],
        })
    return {"schema": "objectshard-independent-preset-connectivity-v1",
        "preset_source_sha256": document["source_sha256"], "max_area": max_area, "cases": cases,
        "scope": "Four-connected Wood, explicit Wall anchor, resident boundaries and padded area only; exact shape and physics admission remain native gates."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--max-area", type=int, default=4096)
    args = parser.parse_args()
    if not 1 <= args.max_area <= 65536:
        parser.error("max-area must be between 1 and 65536")
    payload = args.manifest.read_bytes()
    report = inspect(json.loads(payload), args.max_area)
    report["input_sha256"] = hashlib.sha256(payload).hexdigest()
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
