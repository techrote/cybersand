#!/usr/bin/env python3
"""MAP-AUTO-03 structural/visual *pilot* gate for three source-pinned Atlas lanes.

This does NOT decide artistic taste or compare against the human reference gallery.
It rejects geometry detached from pre-existing mass, overwritten cells, custody
drift, non-static changes, bad receipts and non-Godot before/after evidence.
"""
from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from atlas_agent import captures, receipt


def cells(rects: list, width: int, height: int) -> dict[tuple[int, int], int]:
    out = {}
    for r in rects:
        if (not isinstance(r, list) or len(r) != 5 or any(type(n) is not int for n in r)):
            raise ValueError("invalid rectangle shape")
        x, y, w, h, material = r
        if x < 0 or y < 0 or w < 1 or h < 1 or x + w > width or y + h > height:
            raise ValueError(f"out-of-bounds rectangle {r}")
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                out[(xx, yy)] = material
    return out


def attached_components(added: set[tuple[int, int]], base: set[tuple[int, int]]) -> tuple[int, int]:
    remaining = set(added)
    components = detached = 0
    while remaining:
        components += 1
        stack = [remaining.pop()]
        supported = False
        while stack:
            x, y = stack.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in base:
                    supported = True
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    stack.append(neighbor)
        if not supported:
            detached += 1
    return components, detached


def evaluate(before: dict, after: dict, allowed: set[str]) -> dict:
    problems = []
    metrics = []
    old = copy.deepcopy(before)
    new = copy.deepcopy(after)
    old_features = old.pop("features")
    new_features = new.pop("features")
    if old != new:
        problems.append("non-feature pack metadata, palette or scene placements changed")
    if [f.get("id") for f in old_features] != [f.get("id") for f in new_features]:
        problems.append("feature identities or order changed")
    palette = {m["id"]: m for m in before["palette"]}
    total = 0
    for before_f, after_f in zip(old_features, new_features):
        name = before_f["id"]
        a, b = copy.deepcopy(before_f), copy.deepcopy(after_f)
        old_rects = a.pop("rectangles")
        new_rects = b.pop("rectangles")
        if a != b:
            problems.append(f"{name}: feature metadata or variants changed")
        if new_rects[:len(old_rects)] != old_rects:
            problems.append(f"{name}: prior rectangles overwritten/reordered/removed")
            continue
        added_rects = new_rects[len(old_rects):]
        if name not in allowed and added_rects:
            problems.append(f"{name}: lane pilot edited a non-approved feature")
            continue
        if not added_rects:
            continue
        if not str(before_f.get("status") or before_f.get("kind") or "").endswith("static"):
            # 'static' and 'inert-static' are explicitly accepted; dynamic feature families are denied.
            problems.append(f"{name}: edits to non-static features refused")
            continue
        if len(added_rects) > 20:
            problems.append(f"{name}: more than 20 added rectangles")
        for rect in added_rects:
            material = palette.get(rect[4])
            if not material or material.get("movable") or material.get("kernel", 0) != 0:
                problems.append(f"{name}: dynamic or unknown new material {rect[4]}")
        width, height = before_f["size"]
        before_cells = cells(old_rects, width, height)
        after_cells = cells(new_rects, width, height)
        # Even identical-material overlays are placement-rule intersections.
        overwritten = set()
        for x, y, w, h, _material in added_rects:
            overwritten.update((xx, yy) for yy in range(y, y + h)
                               for xx in range(x, x + w) if (xx, yy) in before_cells)
        added = set(after_cells) - set(before_cells)
        components, detached = attached_components(added, set(before_cells))
        total += len(added)
        metrics.append({"feature": name, "new_rectangles": len(added_rects),
                        "new_cells": len(added), "overwritten_cells": len(overwritten),
                        "new_components": components, "unsupported_components": detached})
        if overwritten:
            problems.append(f"{name}: overwrote {len(overwritten)} existing cells")
        if detached:
            problems.append(f"{name}: {detached} new components detached from old structure")
    if total < 20:
        problems.append("fewer than 20 meaningful new structure cells")
    if total > 2500:
        problems.append("more than 2500 new cells; pilot should be bounded")
    if not metrics:
        problems.append("no approved geometry changes found")
    return {"status": "pass" if not problems else "fail", "problems": problems,
            "total_new_cells": total, "features": metrics,
            "artistic_acceptance": "pending_independent_human_reference_review"}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--allowed-feature", action="append", required=True)
    parser.add_argument("--before-bundle", type=Path, required=True)
    parser.add_argument("--after-bundle", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        original = json.loads(args.before.read_text(encoding="utf-8"))
        candidate = json.loads(args.after.read_text(encoding="utf-8"))
        report = evaluate(original, candidate, set(args.allowed_feature))
        problems = receipt.verify_receipt(args.receipt)
        r = json.loads(args.receipt.read_text(encoding="utf-8"))
        if r["status"]["final"] != "success":
            problems.append("runner did not complete successfully")
        if r["run"]["mode"] != "dry-run":
            problems.append("the keyless qualification unexpectedly used charged API mode")
        comparison = captures.compare_bundles(args.before_bundle, args.after_bundle)
        if not comparison["godot_to_godot"] or not comparison["comparable"]:
            problems.append("real Godot source-matched captures are not comparable")
        if not comparison["visual_change_observed"]:
            problems.append("real Godot pixels/pack did not change")
        report["visual_evidence"] = comparison
        report["problems"] += problems
        if problems:
            report["status"] = "fail"
    except Exception as exc:
        report = {"status": "fail", "problems": [f"{type(exc).__name__}: {exc}"],
                  "artistic_acceptance": "pending_independent_human_reference_review"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print("ATLAS_PILOT_QUALITY " + json.dumps({"status": report["status"], "problems": report["problems"],
                                                "artistic_acceptance": report["artistic_acceptance"]}))
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
