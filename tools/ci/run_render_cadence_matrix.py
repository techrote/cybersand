#!/usr/bin/env python3
"""Run the packaged Test It fixture's shared, matched cadence matrix on Linux.

Each legacy/repaired pair runs sequentially on one host. Independent pairs can
be sharded across hosted jobs. Source/World/tape fences are checked from actual
receipts; requested clocks never stand in for measured rates or GPU acceptance.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import time


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def distribution(values):
    values = sorted(values)
    if not values:
        return None
    return {"count": len(values), "min": values[0], "p50": values[math.ceil(len(values) * .5) - 1],
            "p95": values[math.ceil(len(values) * .95) - 1],
            "p99": values[math.ceil(len(values) * .99) - 1], "max": values[-1]}


def gap(a, b):
    if not isinstance(a, list) or not isinstance(b, list) or len(a) != 2 or len(b) != 2:
        return None
    return math.hypot(a[0] - b[0], a[1] - b[1])


def reduce_trace(path):
    rows = [json.loads(line) for line in Path(path).read_text(encoding="utf-8").splitlines() if line]
    need(len(rows) > 2 and rows[0]["type"] == "header" and rows[-1]["type"] == "summary", "Incomplete trace")
    frames = [row for row in rows if row["type"] == "frame"]
    events = [row for row in rows if row["type"] == "event"]
    need(len(frames) == rows[-1]["frames"] and len(frames) > 1, "Missing frame submissions")
    need(rows[-1].get("dropped", 0) == 0, "Trace frame overflow")
    need(rows[-1].get("events_dropped", 0) == 0, "Trace event overflow")
    need(rows[-1].get("worker_events_dropped", 0) == 0, "Worker trace overflow")
    intervals = [(b["time_usec"] - a["time_usec"]) / 1000 for a, b in zip(frames, frames[1:])]
    need(all(value > 0 for value in intervals), "Nonmonotonic frame times")
    span = (frames[-1]["time_usec"] - frames[0]["time_usec"]) / 1e6
    last = {}
    reasons, sources = Counter(), Counter()
    holds = switches = 0
    residuals, steps, lags = [], [], []
    for frame in frames:
        for body in frame.get("bodies", []):
            slot = body["slot"]
            sources[body["source"]] += 1
            reasons[body.get("guard_reason", "unknown")] += 1
            selected = body.get("screen_selected")
            if isinstance(selected, dict):
                residuals.append(selected.get("residual_magnitude_px", 0))
            lag = gap(body.get("selected_screen"), body.get("live_screen"))
            if lag is not None:
                lags.append(lag)
            if slot in last:
                prior = last[slot]
                switches += prior["source"] != body["source"]
                step = gap(body.get("selected_screen"), prior.get("selected_screen"))
                if step is not None:
                    steps.append(step)
                before, after = prior.get("selected"), body.get("selected")
                if isinstance(before, dict) and isinstance(after, dict):
                    d = gap(before.get("xy"), after.get("xy"))
                    holds += d is not None and d < 1e-6 and abs(before["radians"] - after["radians"]) < 1e-6
            last[slot] = body
    trajectory = {}
    for event in events:
        if event.get("event") != "rapier_step":
            continue
        for body in event.get("bodies", []):
            key = (event["step"], body["slot"])
            need(key not in trajectory, f"Duplicate completed Rapier event: {key}")
            trajectory[key] = body | {"native_tick_used": event.get("native_tick_used")}
    uploads = {e["render_serial"]: e["completed_usec"] for e in events
               if e.get("event") == "texture_upload" and e.get("completed_usec", -1) > 0}
    ack_latencies, unmatched_acks = [], 0
    for event in events:
        if event.get("event") != "render_ack":
            continue
        uploaded = uploads.get(event["render_serial"])
        acknowledged = event.get("time_usec", -1)
        if uploaded is not None and acknowledged >= uploaded:
            ack_latencies.append((acknowledged - uploaded) / 1000)
        else:
            unmatched_acks += 1
    stats = {
        "measurement": "Main overlay submission, not GPU scanout", "frames": len(frames), "span_seconds": span,
        "achieved_overlay_fps": (len(frames) - 1) / span,
        "achieved_native_hz": (frames[-1]["native_tick"] - frames[0]["native_tick"]) / span,
        "achieved_rapier_hz": (frames[-1]["rapier_step"] - frames[0]["rapier_step"]) / span,
        "achieved_upload_hz": sum(a["uploaded_render_serial"] != b["uploaded_render_serial"] for a, b in zip(frames, frames[1:])) / span,
        "frame_interval_ms": distribution(intervals), "screen_step_px": distribution(steps),
        "submitted_to_live_gap_px": distribution(lags), "projection_residual_px": distribution(residuals),
        "selected_world_pose_holds": holds, "source_switches": switches,
        "source_counts": dict(sources), "guard_reasons": dict(reasons),
        "event_counts": dict(Counter(row.get("event", "unknown") for row in events)),
        "event_rates_hz": {},
        "snapshot_age_at_presentation_ms": distribution([(f["time_usec"] - f["render_snapshot_built_usec"]) / 1000 for f in frames if f.get("render_snapshot_built_usec", -1) >= 0]),
        "bound_native_age_at_presentation_ms": distribution([(f["time_usec"] - f["mask_native_completed_usec"]) / 1000 for f in frames if f.get("mask_native_completed_usec", -1) >= 0]),
        "native_tick_wall_ms": distribution([(e["completed_usec"] - e["start_usec"]) / 1000 for e in events if e.get("event") == "native_tick"]),
        "texture_upload_cpu_call_ms": distribution([(e["completed_usec"] - e["start_usec"]) / 1000 for e in events if e.get("event") == "texture_upload"]),
        "snapshot_age_at_upload_ms": distribution([(e["completed_usec"] - e["generated_usec"]) / 1000 for e in events if e.get("event") == "texture_upload" and e.get("generated_usec", -1) >= 0]),
        "upload_to_ack_issue_ms": distribution(ack_latencies), "ack_latency_unavailable": unmatched_acks,
        "dropped_frames": rows[-1].get("dropped", 0), "duplicate_callbacks": rows[-1].get("duplicates", 0),
        "actual_first_view": frames[0]["view_world_cells"], "actual_last_view": frames[-1]["view_world_cells"],
    }
    for kind in stats["event_counts"]:
        times = sorted(e.get("time_usec", e.get("completed_usec", -1)) for e in events if e.get("event") == kind)
        times = [value for value in times if value >= 0]
        if len(times) > 1 and times[-1] > times[0]:
            stats["event_rates_hz"][kind] = (len(times) - 1) * 1e6 / (times[-1] - times[0])
    from analyze_pose_trace import analyze_physics_progress, analyze_presentation_contract
    stats["presentation_contract"] = analyze_presentation_contract(frames)
    stats["physics_progress"] = analyze_physics_progress(frames, events)
    progress = stats["physics_progress"]
    stats["physics_timing_observation"] = (
        "unavailable_no_consecutive_active_steps" if not progress["active_completed_step_gap_ms"]["count"] else
        "performance_concern_100ms_plus" if progress["active_gaps_at_least_100ms"] else
        "no_100ms_gap_observed_not_acceptance")
    stats["physics_hold_reasons"] = dict(Counter(
        row.get("reason", "unknown") for row in events if row.get("event") == "rapier_hold"))
    return stats, trajectory


def compare_steps(before, after):
    common = sorted(before.keys() & after.keys())
    positions, velocities, angles = [], [], []
    changed_inputs = 0
    for key in common:
        a, b = before[key], after[key]
        for values, field in ((positions, "xy"), (velocities, "velocity")):
            value = gap(a.get(field), b.get(field))
            if value is not None:
                values.append(value)
        angle = a["angle"] - b["angle"]
        angles.append(abs(math.atan2(math.sin(angle), math.cos(angle))))
        changed_inputs += a["native_tick_used"] != b["native_tick_used"]
    return {
        "comparison_clock": "same completed Rapier step and body slot; fixed 1/60 simulated seconds per step",
        "common_step_bodies": len(positions), "legacy_step_bodies": len(before), "repaired_step_bodies": len(after),
        "position_delta_cells": distribution(positions), "velocity_delta": distribution(velocities),
        "angle_delta_radians": distribution(angles), "different_native_tick_inputs": changed_inputs,
        "status": "unavailable" if not positions else "physical_trajectory_differs" if max(positions) > .001 else "matched_within_0.001_cells",
    }


def run_case(args, condition, presentation):
    name = condition["name"] + "-" + presentation
    directory = args.evidence / "cases" / name
    directory.mkdir(parents=True, exist_ok=False)
    receipt = directory / "receipt.json"
    env = os.environ.copy()
    cadence = "repaired" if args.coherence else presentation
    pose_selection = presentation if args.coherence else "legacy"
    env.update({"CYBERSAND_SOURCE_REVISION": args.source_sha, "CYBERSAND_DIAG_RENDER_CADENCE": "legacy" if cadence == "legacy" else "",
                "CYBERSAND_DIAG_PRESENTATION": "legacy" if pose_selection == "legacy" else "",
                "CYBERSAND_DIAG_FLYER_POSE": "mask" if condition["pose"] == "mask" else "",
                "XDG_DATA_HOME": str(directory / "userdata"), "APPDATA": str(directory / "userdata")})
    display_profile = condition.get("display_profile", "scripted")
    workers = condition.get("workers", 1)
    params = {"family": "freemass", "workers": workers, "repeat": 1, "camera": condition["camera"], "pose": condition["pose"],
              "pixel-hz": condition["pixel"], "publication-hz": condition["publication"], "fps": condition["fps"],
              "rapier-hz": condition["rapier"], "ack-delay": condition["ack"], "ack-gated": int(condition["gated"]),
              "wait-sample": int(condition["wait"]), "sample-wake": int(condition["wake"]), "smoothing": int(condition["smoothing"]),
              "cadence": cadence, "presentation": pose_selection, "fire-mode": condition.get("fire", "unchanged"),
              "display-profile": display_profile, "cadence-tape": 1, "receipt": str(receipt)}
    command = [str(args.godot)]
    render_thread = getattr(args, "render_thread", None)
    if render_thread is not None:
        need(render_thread in ("safe", "separate"), "Invalid rendering thread control")
        command += ["--render-thread", render_thread]
    if display_profile == "scripted":
        command += ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--max-fps", str(condition["fps"])]
    if getattr(args, "rendering_driver", None):
        command += ["--rendering-driver", args.rendering_driver]
    command += ["--path", str(args.project), "--script", "res://tests/test_engine_lab_physical_test_it.gd", "--", "--engine-lab-scripted",
                *("--" + key + "=" + str(value) for key, value in params.items())]
    write(directory / "case.json", {"name": name, "source_sha": args.source_sha, "condition": condition,
                                   "command": command, "isolated_user_profile": env["APPDATA"],
                                   "render_thread_override": render_thread,
                                   "rendering_driver_override": getattr(args, "rendering_driver", None)})
    print("RENDER_CADENCE_START", name, flush=True)
    start = time.monotonic()
    with (directory / "console.log").open("w", encoding="utf-8") as log:
        completed = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
    need(completed.returncode == 0, f"{name}: exit {completed.returncode}; see console.log")
    data = json.loads(receipt.read_text(encoding="utf-8"))
    need(data["complete"] and data["status"] == "passed", f"{name}: incomplete receipt")
    need(data["source_sha"] == args.source_sha, "Source changed")
    need(data["presentation_mode"] == pose_selection and data["cadence_mode"] == cadence, "Wrong comparison arm")
    need(data["native_workers"]["requested"] == workers and data["native_workers"]["observed_request"] == workers
         and data["native_workers"]["resolved_capacity"] > 0, "Native worker request/capacity not verified")
    need(data["cpu"]["model"] and data["cpu"]["logical_processors"] > 0, "CPU identity missing")
    effective = data["effective_pacing"]
    need(effective["pixel_hz"] == condition["pixel"] and effective["rapier_callback_hz"] == condition["rapier"]
         and effective["wait_native_sample"] == condition["wait"] and effective["sample_wake"] == condition["wake"]
         and effective["graphical_fps_cap"] == condition["fps"] and effective["publication_hz"] == condition["publication"]
         and effective["ack_delay_frames"] == condition["ack"] and effective["ack_gated_publication"] == condition["gated"]
         and effective["smoothing"] == condition["smoothing"], "Effective pacing differs from requested settings")
    need(data["display"]["profile"] == display_profile, "Wrong display profile")
    if display_profile == "interactive-default":
        need(data["display"]["vsync_mode"] == data["display"]["startup"]["vsync_mode"], "Changed ordinary startup VSync")
    if condition.get("fire") == "on-off":
        fire = data["fire_schedule"]["events"]
        need(len(fire) == 2 and [e["observed_step"] for e in fire] == [0, 60]
             and [e["enabled"] for e in fire] == [True, False], "Fire schedule incomplete")
    expected_view = [480, 270] if display_profile == "interactive-default" else [240, 135]
    need(data["world_size"] == [2048, 2048] and data["view_size"] == expected_view, "Wrong World/view")
    need(data["reference"]["json_sha256"] == "b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954", "Wrong owner reference")
    need(data["reference"]["generated_material_sha256"] == "71610b37531531e284f069cf1e07c151283a441c9b0ff32a4fcc1dbb6c997a7a", "Wrong native World")
    need(data["reference"]["native_receipts"] == 256, "Missing generation receipts")
    tape = data["input_tape"]
    need(tape["complete"] and len(tape["observed"]) == 11 and tape["identity"] == "original8_plus_cadence_30_90_120", "Incomplete cadence input tape")
    need(data["native_ticks"] > 0 and data["rapier_steps"] >= 144, "No required simulation progress")
    need(len(data["framebuffer_captures"]) == 2, "Missing actual framebuffers")
    for image in data["framebuffer_captures"]:
        need(sha(image["path"]) == image["sha256"], "Framebuffer hash drift")
    trace = receipt.with_name("receipt-poses.jsonl")
    stats, trajectory = reduce_trace(trace)
    need(trajectory, "Missing completed-step physics events")
    need(stats["physics_progress"]["consecutive_step_intervals"] > 0, "Missing exact completed Rapier intervals")
    write(directory / "analysis.json", stats)
    if args.coherence and pose_selection == "coherent":
        contract = stats["presentation_contract"]
        need(contract["selected_step_observations"] > 0 and contract["source_time_rewind_count"] == 0,
             "Missing or rewinding selected presentation timeline")
        if condition["camera"] == "follow":
            residual = contract["follow_target_minus_selected_world_cells"]
            need(residual is not None and residual["count"] > 0
                 and residual["maximum"] is not None and residual["maximum"] <= 1e-6,
                 "Follow target differs from selected pose")
    result = {"name": name, "condition": condition, "cadence_mode": cadence,
              "presentation_mode": pose_selection, "fire_schedule": data["fire_schedule"], "display": data["display"], "passed": True,
              "cpu": data["cpu"], "native_workers": data["native_workers"], "effective_pacing": effective,
              "render_driver": data["render_driver"],
              "elapsed_seconds": time.monotonic() - start, "receipt_sha256": sha(receipt), "trace_sha256": sha(trace),
              "statistics": stats, "video_adapter": data["video_adapter"]}
    print("RENDER_CADENCE_PASS", name, json.dumps(stats, sort_keys=True), flush=True)
    return result, trajectory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--source-sha", default=os.environ.get("CYBERSAND_EVAL_SOURCE_SHA"), required=not os.environ.get("CYBERSAND_EVAL_SOURCE_SHA"))
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument("--conditions", nargs="*", default=[])
    parser.add_argument("--coherence", action="store_true", help="Compare original guarded vs coherent timeline, preserving repaired ACK/history")
    parser.add_argument("--rendering-driver", choices=["opengl3", "opengl3_angle"],
                        help="Explicit graphical driver override; otherwise preserve the project/platform default")
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    args.godot = args.godot.resolve()
    args.project = args.project.resolve()
    args.evidence = args.evidence.resolve()
    need(0 <= args.shard_index < args.shard_count, "Invalid shard")
    matrix_file = args.project / "tests/fixtures/engine_lab" / (
        "coherence-conditions.json" if args.coherence else "render-cadence-conditions.json")
    matrix = json.loads(matrix_file.read_text(encoding="utf-8"))
    need(matrix["schema"] == ("camera-stack-coherence-conditions-v1" if args.coherence else "render-cadence-conditions-v1"), "Wrong matrix schema")
    conditions = matrix["conditions"]
    names = [row["name"] for row in conditions]
    need(len(names) == len(set(names)) and set(args.conditions) <= set(names), "Unknown/duplicate condition")
    conditions = [row for i, row in enumerate(conditions) if i % args.shard_count == args.shard_index and (not args.conditions or row["name"] in args.conditions)]
    need(conditions, "Empty selected matrix")
    args.evidence.mkdir(parents=True, exist_ok=True)
    summary = {"schema": "camera-stack-coherence-matrix-v1" if args.coherence else "render-cadence-matrix-v1", "source_sha": args.source_sha, "matrix_sha256": sha(matrix_file),
               "shard_index": args.shard_index, "shard_count": args.shard_count, "conditions": conditions, "cases": [], "pairs": [], "failures": [],
               "complete": False, "physical_gpu_acceptance": "pending_owner_NVIDIA_review", "physics_rate_semantics": matrix["semantics"]}
    summary["rendering_driver_override"] = args.rendering_driver
    summary["case_profile_notice"] = "Fresh isolated profiles leave owner preferences unchanged. Auto0 matches a fresh launcher; saved explicit worker overrides differ. Functional completion does not establish smooth physics or physical GPU acceptance."
    report = args.evidence / "summary.json"
    write(report, summary)
    for condition in conditions:
        trajectories, results = {}, {}
        arms = ("legacy", "coherent") if args.coherence else ("legacy", "repaired")
        for presentation in arms:
            try:
                result, trajectory = run_case(args, condition, presentation)
                results[presentation], trajectories[presentation] = result, trajectory
                summary["cases"].append(result)
            except (RuntimeError, ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
                summary["failures"].append({"condition": condition["name"], "presentation": presentation, "error": str(error)})
                print("RENDER_CADENCE_INCOMPLETE", condition["name"], presentation, str(error), flush=True)
            write(report, summary)
        if len(trajectories) == 2:
            candidate = arms[1]
            summary["pairs"].append({"condition": condition["name"], "legacy": results["legacy"]["name"], candidate: results[candidate]["name"],
                                     "physical_trajectory": compare_steps(trajectories["legacy"], trajectories[candidate]),
                                     "legacy_statistics": results["legacy"]["statistics"],
                                     "candidate_statistics": results[candidate]["statistics"]})
            write(report, summary)
    summary["complete"] = not summary["failures"] and len(summary["cases"]) == 2 * len(conditions)
    summary["status"] = "passed" if summary["complete"] else "incomplete"
    write(report, summary)
    print("RENDER_CADENCE_MATRIX", json.dumps({"status": summary["status"], "cases": len(summary["cases"]), "failures": summary["failures"]}), flush=True)
    return 0 if summary["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
