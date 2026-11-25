#!/usr/bin/env python3
"""Independently reduce the original sustained Workbench JSONL witness."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

MAX_ROWS = 60001
MAX_BYTES = 128 * 1024 * 1024
LATE_USEC = 45000000
PULSE_INTERVAL_USEC = 6000000
EVENTS = {"rapier_step", "worker_snapshot", "native_completion_observed", "physics_callback",
          "texture_upload", "main_callback", "framebuffer_draw", "worker_participation"}


def positive(value):
    return type(value) is int and value > 0


def need(condition, reason):
    if not condition:
        raise ValueError(reason)


def snapshot_key(row, tick_field):
    return (row[tick_field], row["completed_body_sample"], row["native_completed_usec"],
            row["physics_handoff_usec"], row["required_hard_revision"])


def water_closes(ledger):
    fields = ("visible", "overfill", "ballistic", "total", "expected")
    return (isinstance(ledger, dict) and all(type(ledger.get(key)) is int and ledger[key] >= 0 for key in fields)
            and ledger["visible"] + ledger["overfill"] + ledger["ballistic"] == ledger["total"] == ledger["expected"])


def reduce_trace(path, receipt):
    path = Path(path)
    need(0 < path.stat().st_size <= MAX_BYTES, "Sustained trace is empty or exceeds its byte allowance")
    start, end = receipt["capture_start_usec"], receipt["capture_end_usec"]
    extent = receipt["fixture"]["extent"]
    full_bytes = extent[0] * extent[1] * 2
    generation = receipt["resident_samples"][0]["world_generation"]
    steps, transitions = [], []
    dense_completions = {}
    worker_counts, native_counts, callbacks = set(), set(), {}
    completed_frames = set()
    last_dense = 0
    last_upload = 0
    last_worker_snapshot = 0
    owner = None
    terminal = None
    hashed = hashlib.sha256()
    row_count = 0
    with path.open("rb") as stream:
        for row_count, line in enumerate(stream, 1):
            need(row_count <= MAX_ROWS, "Sustained trace exceeds bounded owner event counts")
            hashed.update(line)
            row = json.loads(line)
            need(isinstance(row, dict) and isinstance(row.get("event"), str), "Invalid sustained trace row")
            event = row["event"]
            if row_count == 1:
                need(event == "identity" and row["source"] == receipt["source_identity"]
                     and row["fixture"] == receipt["fixture"], "Sustained trace identity differs")
                continue
            need(event in EVENTS, "Unknown sustained trace event or repeated identity")
            if event == "rapier_step":
                began, completed = row["start_usec"], row["time_usec"]
                step, manual = row["step"], row["manual_steps"]
                native_tick, sample, native_usec, handoff_usec, revision = snapshot_key(row, "native_tick_used")
                current_owner = (row["session"], row["epoch"])
                need(all(positive(value) for value in (step, manual, sample, native_tick, native_usec, handoff_usec,
                                                       row["native_snapshot_serial"], *current_owner))
                     and type(revision) is int and revision >= 0
                     and type(began) is int and type(completed) is int
                     and start <= began <= completed <= end and native_usec <= handoff_usec <= completed,
                     "Sustained Rapier step timing or native identity differs")
                need(math.isclose(row["fixed_delta"], 1 / 60, rel_tol=0, abs_tol=1e-12)
                     and row["pending_hard_chunks"] == 0 and row["installed_hard_revision"] == revision
                     and row["packet_hard_revision"] == revision and row["response_accepted"] is True
                     and row["response_refusal"] == "" and row["accepted_samples"] == [sample, sample]
                     and [(body["slot"], body["instance_id"]) for body in row["bodies"]] == [(0, 1), (1, 2)],
                     "Sustained Rapier step lacks exact sample, terrain, actor or fixed-step evidence")
                if owner is None:
                    owner = current_owner
                need(current_owner == owner, "Sustained physical owner changed")
                if terminal is not None:
                    need(step == terminal["step"] + 1 and manual == terminal["manual_steps"] + 1
                         and sample == terminal["completed_body_sample"] + 1
                         and native_tick > terminal["native_tick_used"] and completed > terminal["time_usec"],
                         "Duplicate, reordered or missing sustained physical completion")
                terminal = row
                steps.append(row)
            elif event == "worker_snapshot":
                serial = row["snapshot_serial"]
                need(positive(serial) and serial > last_worker_snapshot, "Duplicate or reordered sustained worker publication")
                last_worker_snapshot = serial
                if (row["failed"] is False and row["world_generation"] == generation
                        and row["hard_surface_revision"] == row["required_hard_revision"]
                        and row["water_ledger_healthy"] is True and water_closes(row.get("water_ledger"))):
                    worker_counts.add((serial, *snapshot_key(row, "tick_index")))
            elif event == "native_completion_observed":
                need(row["world_generation"] == generation, "Observed native completion belongs to a different World")
                key = (row["tick_index"], row["body_sample"])
                need(key not in native_counts, "Duplicate observed native completion")
                native_counts.add(key)
            elif event == "physics_callback" and row["after_step"] > row["before_step"]:
                key = (row["start_usec"], row["after_step"])
                frame = row["physics_frame"]
                need(key not in callbacks and positive(frame) and frame not in completed_frames
                     and row["after_step"] == row["before_step"] + 1
                     and type(row["time_usec"]) is int and row["time_usec"] <= end,
                     "Duplicate, multi-step or out-of-capture callback witness")
                callbacks[key] = row["time_usec"]
                completed_frames.add(frame)
            elif event == "texture_upload":
                serial, patch_bytes, completed = row["render_serial"], row["patch_bytes"], row["time_usec"]
                need(positive(serial) and serial > last_upload and type(patch_bytes) is int and patch_bytes >= 0
                     and row["world_generation"] == generation and start <= completed <= end
                     and type(row["full_refresh"]) is bool, "Invalid or duplicate sustained texture upload")
                last_upload = serial
                if row["full_refresh"]:
                    last_dense = serial
                    dense_completions[serial] = completed - start
                elif last_dense > 0 and patch_bytes < full_bytes:
                    transitions.append({"dense_serial": last_dense, "sparse_serial": serial,
                        "sparse_packet_bytes": patch_bytes, "publisher_history_copy": row["material"].get("history_copy", False),
                        "publisher_submitted_bytes": row["material"].get("submitted_bytes", 0), "elapsed_usec": completed - start})
                    last_dense = 0
    need(hashed.hexdigest() == receipt["trace_sha256"], "Sustained trace bytes differ")
    late = sum(row["time_usec"] - start >= LATE_USEC for row in steps)
    need(len(steps) >= 144 and late >= 12 and len(steps) == receipt["actual_rapier_steps"]
         and late == receipt["late_rapier_steps"], "Sustained actual or late physical witness count differs")
    need(all((row["native_snapshot_serial"], *snapshot_key(row, "native_tick_used")) in worker_counts
             and (row["native_tick_used"], row["completed_body_sample"]) in native_counts for row in steps),
         "Sustained completion lacks matching native World/sample publication evidence")
    need(len(callbacks) == len(steps) and all(
        callbacks.get((row["start_usec"], row["step"]), -1) >= row["time_usec"] for row in steps),
        "Sustained completion lacks its unique real physics callback")
    need(len(transitions) >= 10 and transitions == receipt["transition_receipts"],
         "Sustained dense-to-sparse transition witnesses differ")
    pulses = receipt["pulses"]
    need(len(pulses) == 10, "Expected ten registered recovery pulse receipts")
    for index, pulse in enumerate(pulses):
        elapsed = pulse["elapsed_usec"]
        next_pulse = pulses[index + 1]["elapsed_usec"] if index + 1 < len(pulses) else end - start + 1
        need(pulse["sequence"] == index and pulse["paint_admitted"] is True
             and pulse["camera"] == ("follow" if index % 2 == 0 else "free")
             and type(elapsed) is int and (index + 1) * PULSE_INTERVAL_USEC <= elapsed < next_pulse
             and positive(pulse["render_serial_before"]), "Invalid registered recovery pulse interval")
        need(any(pulse["render_serial_before"] < item["dense_serial"]
                 and elapsed <= dense_completions[item["dense_serial"]] < item["elapsed_usec"] < next_pulse
                 for item in transitions), "Recovery pulse lacks a matching dense-to-sparse transition")
    return {"trace_rows": row_count, "rapier_steps": len(steps), "late_rapier_steps": late,
            "dense_to_sparse": len(transitions), "session": owner[0], "epoch": owner[1],
            "observed_input_scope": "Frozen fixture checks tape activation internally. Raw V1 trace has no per-command witness.",
            "trace_sha256": hashed.hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    receipt = json.loads(args.receipt.read_bytes())
    trace = args.receipt.with_name(args.receipt.stem + "-events.jsonl")
    print(json.dumps(reduce_trace(trace, receipt), indent=2))


if __name__ == "__main__":
    main()
