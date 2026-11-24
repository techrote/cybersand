#!/usr/bin/env python3
"""Exploratory five-cell-square free-space review of retained native examples.

This is a geometric diagnostic for the owner handoff, not a frozen experiment
metric or actor/gameplay acceptance test. The square moves by unrestricted unit
translations in four directions, without gravity, jumping, speed, or physics.
Starts/goals are the integer centers of explicit stage-level clearance rectangles. Only the
chosen output is written; native planes and their original manifests are read.
"""

from __future__ import annotations

import argparse
from array import array
from collections import deque
import hashlib
import json
from pathlib import Path
import struct


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def components(mask: bytearray, width: int, height: int) -> array:
    labels = array("i", [-1]) * len(mask)
    component_count = 0
    for start, free in enumerate(mask):
        if not free or labels[start] >= 0:
            continue
        label = component_count
        component_count += 1
        labels[start] = label
        queue = deque([start])
        while queue:
            index = queue.popleft()
            x, y = index % width, index // width
            neighbors = []
            if x: neighbors.append(index - 1)
            if x + 1 < width: neighbors.append(index + 1)
            if y: neighbors.append(index - width)
            if y + 1 < height: neighbors.append(index + width)
            for neighbor in neighbors:
                if mask[neighbor] and labels[neighbor] < 0:
                    labels[neighbor] = label
                    queue.append(neighbor)
    return labels


def assess(directory: Path, row: dict) -> dict:
    width, height = row["extent"]
    plane = directory / row["plane"]
    assert digest(plane) == row["sha256"], "Native plane digest mismatch"
    data = plane.read_bytes()
    assert len(data) == 2 * width * height, "Native plane size mismatch"
    empty = bytearray(value[0] == 0 for value in struct.iter_unpack("<H", data))
    stride = width + 1
    integral = array("I", [0]) * ((width + 1) * (height + 1))
    for y in range(height):
        subtotal = 0
        for x in range(width):
            subtotal += not empty[y * width + x]
            integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + subtotal
    free = bytearray(width * height)
    for y in range(2, height - 2):
        for x in range(2, width - 2):
            occupied = (integral[(y + 3) * stride + x + 3] - integral[(y - 2) * stride + x + 3]
                        - integral[(y + 3) * stride + x - 2] + integral[(y - 2) * stride + x - 2])
            free[y * width + x] = occupied == 0
    labels = components(free, width, height)
    recipe = row["recipe"]
    if isinstance(recipe, str): recipe = json.loads((directory / recipe).read_text())
    ox, oy = recipe["origin"]
    rects = sorted({tuple(rect) for stage in recipe["stages"] for rect in stage["clearances"]})
    centers = []
    for x, y, w, h in rects:
        cx, cy = x - ox + w // 2, y - oy + h // 2
        assert 0 <= cx < width and 0 <= cy < height, "Clearance center outside native crop"
        label = labels[cy * width + cx]
        centers.append({"world_rectangle": [x, y, w, h], "local_center": [cx, cy],
                        "five_cell_square_fits": label >= 0, "component_id": label})
    groups: dict[int, list[int]] = {}
    for index, center in enumerate(centers):
        groups.setdefault(center["component_id"], []).append(index)
    return {"id": row["id"], "family": row["family"], "extent": [width, height],
            "native_material_sha256": row["sha256"],
            "declared_clearance_centers": centers,
            "center_groups_connected_under_square_proxy": [members for label, members in groups.items() if label >= 0],
            "all_clearance_centers_fit": all(c["five_cell_square_fits"] for c in centers),
            "all_clearance_centers_share_square_component": bool(centers) and len(groups) == 1 and -1 not in groups}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stages", required=True, type=Path)
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    rows, manifests = [], {}
    for filename in ("representatives.json", "module-compositions.json"):
        path = args.stages / filename
        document = json.loads(path.read_text())
        assert document["source_revision"] == args.expected_source, "Unexpected native source"
        manifests[filename] = digest(path)
        rows.extend(assess(args.stages, row) for row in document["examples"])
    result = {"schema_version": "cybersand.exploratory-negative-space-review.v1",
              "source_revision": args.expected_source, "audit_tool_sha256": digest(Path(__file__)),
              "input_manifest_sha256": manifests, "square_size_cells": [5, 5],
              "motion": "Four-neighbor unit translations; all five-by-five cells must be Empty and inside the retained native crop. No gravity, jumping, speed, materials dynamics, or actor assumptions.",
              "start_goal_rule": "Integer centers of every unique explicit stage-level clearance rectangle, converted from World to local coordinates. Module-local clearances and cavities are outside this probe set. All center pairs are compared by component membership; no authored spawn/goal is invented.",
              "scope": "Exploratory geometric review of explicit stage-level clearance relationships for owner handoff. Mutual connection of every declared clearance is not an acceptance requirement. Enclosed equipment and planting-container cavities are not route failures and are not scored. Not part of the frozen thirty-attempt comparison, not a new gate, and not a gameplay or physical actor acceptance certificate. A shared component is necessary only under these artificial movement assumptions, not sufficient for real gameplay.",
              "examples": rows}
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps([{key: row[key] for key in ("id", "all_clearance_centers_fit", "center_groups_connected_under_square_proxy")} for row in rows]))


if __name__ == "__main__":
    main()
