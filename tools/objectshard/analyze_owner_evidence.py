#!/usr/bin/env python3
"""Verify the untouched 001R owner exports and derive limited, auditable facts.

This deliberately cannot turn the historical ring buffers into an input replay.
It accepts the extracted evidence directory and writes a derived JSON report;
neither the original files nor their supplied summary are modified.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re

NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?"
POSE = re.compile(rf"\[X: \(({NUMBER}), ({NUMBER})\), Y: \(({NUMBER}), ({NUMBER})\), O: \(({NUMBER}), ({NUMBER})\)\]")


def pose(value: str) -> dict:
    match = POSE.fullmatch(value)
    if match is None:
        raise ValueError("Expected historical Godot Transform2D string")
    xx, xy, yx, yy, x, y = map(float, match.groups())
    if abs(xx * yy - xy * yx - 1) > 0.00001:
        raise ValueError("Unexpected non-rigid historical pose")
    return {"x": x, "y": y, "rotation_radians": math.atan2(xy, xx)}


def analyze(directory: Path) -> dict:
    supplied_path = directory / "summary.json"
    supplied = json.loads(supplied_path.read_text(encoding="utf-8"))
    reports, originals = [], []
    for expected in supplied["reports"]:
        name = expected["filename"]
        if Path(name).name != name:
            raise ValueError("Non-local export filename")
        raw = (directory / "original_exports" / name).read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest != expected["sha256"] or len(raw) != expected["size_bytes"]:
            raise ValueError(f"Original evidence identity mismatch: {name}")
        data = json.loads(raw)
        if data["source_revision"] != supplied["runtime_commit"]:
            raise ValueError(f"Runtime identity differs from supplied evidence: {name}")
        for key in ("session", "scenario", "seed", "tick", "failed"):
            if data[key] != expected[key]:
                raise ValueError(f"Supplied summary differs for {name}: {key}")
        counts = Counter(event["kind"] for event in data["events"])
        owners = [{key: owner[key] for key in (
            "id", "generation", "session", "structural", "cargo", "products", "mass",
            "com_x", "com_y", "inertia", "geometry_revision", "applied_physics_revision")}
            | {"pose": pose(owner["actual_pose"])} for owner in data["owners"]]
        reports.append({
            "filename": name, "sha256": digest, "size_bytes": len(raw),
            "session": data["session"], "scenario": data["scenario"], "tick": data["tick"],
            "failed": data["failed"], "status": data["status"], "owners": owners,
            "retained_event_counts": dict(sorted(counts.items())),
            "retained_event_count": len(data["events"]), "ring_at_capacity": len(data["events"]) == 256,
            "first_retained_event_tick": data["events"][0]["tick"] if data["events"] else None,
            "last_retained_event_tick": data["events"][-1]["tick"] if data["events"] else None,
            "process_native_steps": data["native_metrics"]["steps"],
            "process_native_promotions": data["native_metrics"]["promotions"],
            "process_native_refusals": data["native_metrics"]["refusals"],
            "last_refusal": data["last_refusal"],
            "continuous_pose_velocity_sleep_history": False,
            "complete_input_replay_available": False,
        })
        originals.append(data)
    same_session_deltas = []
    for before, after in zip(reports, reports[1:]):
        if before["session"] != after["session"]:
            continue
        by_id = {owner["id"]: owner for owner in before["owners"]}
        for owner in after["owners"]:
            previous = by_id.get(owner["id"])
            if previous is None or previous["generation"] != owner["generation"]:
                continue
            angle = math.remainder(owner["pose"]["rotation_radians"] - previous["pose"]["rotation_radians"], 2 * math.pi)
            row = {
                "session": after["session"], "id": owner["id"], "from_tick": before["tick"], "to_tick": after["tick"],
                "wood_cell_loss": previous["structural"] - owner["structural"],
                "geometry_revision_advance": owner["geometry_revision"] - previous["geometry_revision"],
                "net_rotation_degrees": math.degrees(angle),
                "lattice_origin_displacement_cells": math.hypot(owner["pose"]["x"] - previous["pose"]["x"], owner["pose"]["y"] - previous["pose"]["y"]),
                "causality": "Not established: no intermediate pose, velocity, sleep or geometry-install trace",
            }
            if previous["mass"] - owner["mass"] == 1 and previous["cargo"] == owner["cargo"] == 0:
                row["inferred_removed_unit_mass_cell_center"] = [
                    previous["mass"] * previous[key] - owner["mass"] * owner[key] for key in ("com_x", "com_y")]
                row["mass_inference_assumption"] = "Exactly one unit-mass structural cell removed; no other mass exchange between snapshots"
            same_session_deltas.append(row)
    return {
        "schema": "objectshard-owner-forensics-v1",
        "source_runtime_commit": supplied["runtime_commit"],
        "supplied_summary_sha256": hashlib.sha256(supplied_path.read_bytes()).hexdigest(),
        "original_export_count": len(reports), "unique_sessions": len({r["session"] for r in reports}),
        "verified": True, "reports": reports, "same_session_deltas": same_session_deltas,
        "limits": [
            "Six exports describe five sessions; the two D exports are successive observations.",
            "Events are a bounded ring, and native metrics/accounting may span preceding resets.",
            "Exports contain final poses and frame costs, not continuous physics or complete input history.",
            "The World material raster and complete cut order are absent; the floating component cannot be reconstructed from these exports.",
            "Correlated geometry changes and net movement do not identify a unique physical cause.",
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence_directory", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.evidence_directory)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"verified_exports": result["original_export_count"], "unique_sessions": result["unique_sessions"], "output": str(args.output)}))


if __name__ == "__main__":
    main()
