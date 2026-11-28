#!/usr/bin/env python3
"""Reconstruct the retained headless submerged-actor diagnostic from RG8 crops.

This is deliberately separate from the gameplay reducers. It never confers
timing, GPU, scanout or historical-capture equivalence on this causal probe.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import subprocess

ENGINE_SHA256 = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
NATIVE_SHA256 = "33d9c39ecfca71c800f538dbf3edbbb85675c0c65be35d6af525f699b7d15dc0"
RAPIER_SHA256 = "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"
NATIVE_BUILD_SOURCE = "c2f8a73d34448bc1496ecd84bca02f0812c80d27"
APPLICATION_SOURCE = "498fa47da062db702a74665f177e06f454d956aa"
FIXTURE = "tests/pubpres_endpoint_diagnostic.gd"
SOURCE_FILES = ("scripts/main.gd", "scripts/workbench_presentation_coherence.gd")
LABELS = ("paused_initial", "ordinary_step_120", "ordinary_step_240", "ordinary_step_360",
          "ordinary_step_480", "ordinary_step_600", "paused_camera_return")


def need(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pose(value: dict) -> tuple[float, float, float]:
    need(type(value) is dict and set(value) == {"xy", "radians"}, "Missing actual rigid pose")
    need(type(value["xy"]) is list and len(value["xy"]) == 2, "Missing pose center")
    values = (*value["xy"], value["radians"])
    need(all(type(v) in (int, float) and math.isfinite(v) for v in values), "Nonfinite pose")
    return values


def footprint(actual_pose: dict, record: dict) -> int:
    px, py, angle = pose(actual_pose)
    co, si = math.cos(angle), math.sin(angle)
    occupied = []
    cells = 0
    crops = record["crops"]
    need(type(crops) is list and 1 <= len(crops) <= 8, "Unbounded copied geometry")
    for crop in crops:
        raw = base64.b64decode(crop["bytes_base64"], validate=True)
        need(sha(raw) == crop["sha256"], "Copied material bytes changed")
        rect = crop["rect"]
        need(type(rect) is list and len(rect) == 4 and all(type(v) is int for v in rect), "Invalid crop bounds")
        x, y, width, height = rect
        need(0 <= x < 512 and 0 <= y < 512 and 0 < width <= 64 and 0 < height <= 64
             and x + width <= 512 and y + height <= 512, "Unbounded or out-of-World crop")
        need(type(crop["format"]) is int and crop["format"] == 3 and len(raw) == width * height * 2,
             "Expected actual RG8 material plane")
        cx, cy = crop["local_center"]
        sx, sy = crop["size"]
        need(all(type(v) in (int, float) and math.isfinite(v) for v in (cx, cy, sx, sy))
             and sx > 0 and sy > 0, "Invalid copied rectangle")
        center = (px + co * cx - si * cy, py + si * cx + co * cy)
        extent = (abs(co) * sx / 2 + abs(si) * sy / 2, abs(si) * sx / 2 + abs(co) * sy / 2)
        for iy in range(max(0, math.floor(center[1] - extent[1]) - 1), min(512, math.ceil(center[1] + extent[1]) + 1)):
            for ix in range(max(0, math.floor(center[0] - extent[0]) - 1), min(512, math.ceil(center[0] + extent[0]) + 1)):
                dx, dy = ix + 0.5 - px, iy + 0.5 - py
                lx, ly = co * dx + si * dy - cx, -si * dx + co * dy - cy
                if abs(lx) <= sx / 2 + 0.0001 and abs(ly) <= sy / 2 + 0.0001:
                    need(x <= ix < x + width and y <= iy < y + height, "Copied crop omits an actual body cell center")
        for iy in range(height):
            for ix in range(width):
                dx, dy = x + ix + 0.5 - px, y + iy + 0.5 - py
                lx, ly = co * dx + si * dy - cx, -si * dx + co * dy - cy
                # The actual retained stimulus is away from cell-edge ambiguity.
                # Refuse an ambiguous reconstruction rather than certify Godot's
                # float32 inverse from a rounded rotation representation.
                need(min(abs(abs(lx) - sx / 2 - 0.0001), abs(abs(ly) - sy / 2 - 0.0001)) > 0.00001,
                     "Pose representation is too close to a footprint boundary")
                if abs(lx) > sx / 2 + 0.0001 or abs(ly) > sy / 2 + 0.0001:
                    continue
                cells += 1
                offset = 2 * (iy * width + ix)
                if raw[offset]:
                    occupied.append({"x": x + ix, "y": y + iy, "material": raw[offset], "state": raw[offset + 1]})
    need(type(record["cells"]) is int and record["cells"] == cells and record["occupied"] == occupied,
         "Reported footprint differs from independent RG8/cell-center reconstruction")
    return len(crops)


def validate(receipt: Path, repository: Path) -> dict:
    raw = receipt.read_bytes()
    data = json.loads(raw)
    need(data["schema"] == "pubpres-endpoint-causal-diagnostic-v1" and data["failures"] == [], "Incomplete diagnostic")
    identity = data["identity"]
    need(identity["source"] == APPLICATION_SOURCE and identity["display"] == "headless"
         and identity["engine_sha256"] == ENGINE_SHA256, "Unregistered application/engine/display identity")
    for relative in SOURCE_FILES:
        committed = subprocess.check_output(["git", "-C", str(repository), "show", APPLICATION_SOURCE + ":godot/" + relative])
        need(identity["res://" + relative] == sha(committed), "Actual application source differs: " + relative)
    fixture_sha = sha((repository / "godot" / FIXTURE).read_bytes())
    need(identity["res://" + FIXTURE] == fixture_sha, "Declared diagnostic overlay differs from executed bytes")
    need(identity["res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"] == NATIVE_SHA256
         and identity["res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"] == RAPIER_SHA256,
         "Native or Rapier runtime differs")
    captures = data["captures"]
    need([row["label"] for row in captures] == list(LABELS), "Incomplete causal observation sequence")
    planes = crops = 0
    owners = None
    for index, row in enumerate(captures):
        need(type(row["step"]) is int and type(row["actual_manual_steps"]) is int
             and row["step"] == row["actual_manual_steps"] == (120 * index if index < 6 else 600),
             "Session progress is not paired with real bridge manual-step observations")
        need(len(row["bodies"]) == 8 and [body["slot"] for body in row["bodies"]] == list(range(8)),
             "Incomplete actor ownership")
        current_owners = [body["rid"] for body in row["bodies"]]
        need(len(set(current_owners)) == 8 and (owners is None or current_owners == owners),
             "Actual body RID ownership changed or aliases another actor")
        owners = current_owners
        for body in row["bodies"]:
            need(body["live"] == body["actual_rid_pose"] and type(body["rid"]) is str and int(body["rid"]) > 0,
                 "Bridge pose differs from actual Rapier RID observation")
            for history in ("current", "previous"):
                if body[history]:
                    expected_size = [7.0, 3.0] if body["slot"] < 7 else [8.0, 14.0]
                    need(len(body[history]["crops"]) == 1 and body[history]["crops"][0]["size"] == expected_size
                         and body[history]["crops"][0]["local_center"] == [0.0, 0.0], "Fixture's actual geometry changed")
                    crops += footprint(body["live"], body[history])
                    planes += 1
    terminal = captures[-1]
    need(terminal["latest"]["step"] == 600 and terminal["latest"]["guard"]["budget_vetoes"] == 0,
         "Terminal omission may be a different step or budget refusal")
    terminal_rows = terminal["gcr"]["rows"]
    frame, gcr = terminal["latest"]["native_frame"], terminal["gcr"]
    need(all(type(v) is int for v in (terminal["native_tick"], frame["tick"], terminal["world_generation"],
         frame["world_generation"], gcr["session"], frame["session"], gcr["epoch"], frame["epoch"],
         gcr["sample_tick"], frame["sample_tick"], terminal["latest"]["time_usec"], terminal["time_usec"])),
         "Terminal native identity was coerced")
    need(terminal["native_tick"] == frame["tick"] == terminal["step"] == 600
         and terminal["world_generation"] == frame["world_generation"] == 3
         and gcr["session"] == frame["session"] == 1 and gcr["epoch"] == frame["epoch"] == 1
         and gcr["sample_tick"] == frame["sample_tick"] == 599
         and terminal["latest"]["time_usec"] <= terminal["time_usec"],
         "Terminal native/material/physical owner or sample identity differs")
    need(terminal["gcr"]["valid"] is True and terminal["unresolved"] == 63,
         "Missing actual unresolved native-overlap observation")
    for slot in (4, 5, 6):
        body = terminal["bodies"][slot]
        need(terminal["latest"]["sources"][str(slot)] == "hidden", "Expected omitted actor is visible")
        row = next(row for row in terminal_rows if row["id"] == slot + 1)
        bound = frame["instances"][str(slot + 1)]
        need(all(type(v) is int for v in (row["id"], row["instance_id"], row["unresolved"], row["displaced"],
             body["state"]["instance_id"], row["generation"], bound["generation"], body["state"]["generation"],
             row["sample"], bound["sample"])), "Actor endpoint identity was coerced")
        need(row["instance_id"] == slot + 1 and row["unresolved"] == 21 and row["displaced"] == 0,
             "Native overlap belongs to another body or disposition")
        need(row["instance_id"] == body["state"]["instance_id"]
             and row["generation"] == bound["generation"] == body["state"]["generation"] == 1
             and row["sample"] == bound["sample"] == 601, "Actor generation or consumed sample differs")
        for history in ("current", "previous"):
            need(len(body[history]["occupied"]) == 21
                 and {cell["material"] for cell in body[history]["occupied"]} == {3},
                 "Endpoint obstacle is not the observed retained Water footprint")
        queries = [q for q in terminal["latest"]["queries"] if q["slot"] == slot]
        need([q["result"]["reason"] for q in queries]
             == ["bounded_pose_delta", "material_in_swept_mask", "material_in_swept_mask"],
             "Actual endpoint refusals differ from the causal finding")
        need(all(q["endpoint_only"] is True and q["target"] == q["start"] == body["live"]
                 and q["result"]["safe"] is False for q in queries[1:]), "Endpoint test did not inspect actual current body pose")
    return {"schema": "pubpres-endpoint-crop-byte-reconstruction-v1", "receipt_sha256": sha(raw),
            "application_source": APPLICATION_SOURCE, "diagnostic_overlay_sha256": fixture_sha,
            "native_build_source": NATIVE_BUILD_SOURCE, "native_sha256": NATIVE_SHA256,
            "engine_sha256": ENGINE_SHA256, "crop_planes_checked": planes, "crops_checked": crops,
            "terminal_actual_session_and_manual_steps": 600, "hidden_slots": [4, 5, 6],
            "unresolved_and_current_previous_water_cells_per_hidden_slot": 21,
            "actual_rids_unique_and_stable": True, "terminal_native_identity_joined": True,
            "terminal_guard_budget_vetoes": 0, "performance_claim": False, "gpu_visibility_claim": False,
            "historical_mixed_capture_equivalence": False, "physical_acceptance": "HOLD"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = validate(args.receipt, args.repository)
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
