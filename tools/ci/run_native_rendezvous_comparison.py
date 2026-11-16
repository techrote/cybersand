#!/usr/bin/env python3
"""Fixed-input rendering-thread/native-rendezvous factorial, with raw custody.

Every arm runs the original 2048-square Needle workload and normal coupling.
Requested callback rates are never substituted for completed physical steps.
The reverse order retains first-use and ordering effects. This focused mechanism
trial is separate from final source/control and installed-package qualification.
"""
from __future__ import annotations

import argparse
from collections import Counter
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from analyze_pose_trace import distribution, event_time, read_trace
from run_physics_freeze_comparison import (
    ROOT, exact_common_states, git, need, reduction, sha,
    verify_candidate_project, verify_runtime_project, write,
)
from run_render_cadence_matrix import run_case

MODES = {
    "safe-off": ("safe", "off"),
    "separate-off": ("separate", "off"),
    "safe-on": ("safe", "fixed16"),
    "separate-on": ("separate", "fixed16"),
    "safe-overlap": ("safe", "render-overlap"),
    "separate-overlap": ("separate", "render-overlap"),
}
SELECTORS = {"off": "0", "fixed16": "1", "render-overlap": "render-overlap"}
ORDER = ("safe-off", "separate-off", "separate-overlap", "separate-overlap", "separate-off", "safe-off")
EXTENSIONS = {".gd", ".gdshader", ".gdshaderinc", ".gdextension", ".tscn", ".tres", ".json", ".godot", ".cfg"}


@contextmanager
def environment(values):
    previous = {key: os.environ.get(key) for key in values}
    os.environ.update(values)
    try:
        yield
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def fingerprint(project, godot):
    return {
        "project": {p.relative_to(project).as_posix(): sha(p)
                    for p in sorted(project.rglob("*")) if p.is_file()
                    and p.suffix in EXTENSIONS
                    and not p.relative_to(project).as_posix().startswith(".godot/")},
        "engine": sha(godot),
        "native": {p.relative_to(project).as_posix(): sha(p)
                   for p in project.rglob("*") if p.is_file()
                   and p.suffix in (".so", ".dll") and p.stat().st_size > 1024},
        "harness": {name: sha(ROOT / "tools/ci" / name) for name in (
            "run_native_rendezvous_comparison.py", "run_render_cadence_matrix.py",
            "run_physics_freeze_comparison.py", "analyze_pose_trace.py")},
    }


def additional_metrics(trace, mode):
    header, frames, footer = read_trace(trace)
    status = header.get("settings", {}).get("native_rendezvous")
    need(isinstance(status, dict), "Missing actual rendezvous/thread status")
    thread, policy = MODES[mode]
    enabled = policy != "off"
    limit = 66667 if policy == "render-overlap" else 16667
    need(status.get("enabled") is enabled, "Wrong actual rendezvous mode")
    need(status.get("mode") == policy, "Wrong actual rendezvous policy")
    need(status.get("separate_render_thread") is (thread == "separate"),
         "Requested rendering thread did not become the actual context owner")
    need(status.get("max_frame_wait_usec") == limit and status.get("poll_usec") == 250,
         "Rendezvous budget differs from its registered policy")
    need(status.get("render_overlap_available") is (policy == "render-overlap" and thread == "separate"),
         "Wrong actual rendering-overlap availability")
    need(abs(status.get("fixed_physics_delta", 0) - 1 / 60) < 1e-12
         and status.get("waits_for_native_sample") is True, "Physical contract changed")
    events = footer["_events"]
    waits = [e for e in events if e.get("event") == "native_rendezvous"]
    need(enabled or not waits, "Disabled arm performed a rendezvous")
    budgets = {}
    markers = {}
    marker_frames = {}
    completed_markers = {}
    for event in waits:
        frame = event["process_frame"]
        need(event["callback_index"] >= 2, "Rendezvous ran in a first callback")
        started, ended, deadline = (event[k] for k in ("start_usec", "completed_usec", "deadline_usec"))
        need(ended >= started and deadline >= 0, "Invalid rendezvous clock")
        need(event.get("mode") == policy, "Event policy differs from actual configured mode")
        if policy == "render-overlap":
            if thread == "safe":
                need(event["status"] == "render_unavailable" and event["polls"] == event["sleeps"] == 0,
                     "Safe rendering added an overlap wait")
            else:
                marker = {key:event[key] for key in ("render_marker_id", "render_marker_frame", "render_marker_queued_usec")}
                need(marker["render_marker_id"] != 0 and marker["render_marker_frame"] == frame
                     and 0 < marker["render_marker_queued_usec"] <= started, "Wrong or missing render-queue marker")
                need(markers.setdefault(frame, marker) == marker, "A process frame queued more than one marker")
                need(marker_frames.setdefault(marker["render_marker_id"], frame) == frame,
                     "Different process frames reused a queued marker identity")
                observed = event["render_marker_observed_complete_usec"]
                if frame in completed_markers:
                    need(observed == completed_markers[frame] and event["status"] == "render_complete"
                         and event["polls"] == event["sleeps"] == 0,
                         "A completed marker was not latched or permitted another wait")
                if observed:
                    need(marker["render_marker_queued_usec"] <= observed <= ended,
                         "Render marker observation precedes its queue submission")
                    completed_markers[frame] = observed
                need(event["status"] != "ready" or observed == 0,
                     "Overlap admitted a ready wait after observing render completion")
                if event["status"] == "render_complete":
                    need(0 < event["render_marker_observed_complete_usec"] <= ended,
                         "Completed renderer lacks an observed queue receipt")
        if deadline == 0:
            need(policy == "render-overlap" and event["status"] in ("render_complete", "render_unavailable")
                 and event["polls"] == event["sleeps"] == event["requested_sleep_usec"] == 0,
                 "A callback without a wait deadline performed work")
            continue
        budget = budgets.setdefault(frame, {"deadline_usec": deadline, "first_wait_usec": started,
                                           "requested_sleep_usec": 0, "actual_wait_usec": 0, "maximum_deadline_overshoot_usec": 0})
        need(deadline == budget["deadline_usec"] and deadline - budget["first_wait_usec"] == limit,
             "Catch-up callbacks reset or enlarge the shared deadline")
        need(event["frame_wait_usec"] >= budget["actual_wait_usec"], "Cumulative wait moved backwards")
        need(event["requested_sleep_usec"] >= 0, "Negative requested sleep")
        budget["requested_sleep_usec"] += event["requested_sleep_usec"]
        budget["actual_wait_usec"] = event["frame_wait_usec"]
        # Expired callbacks can observe the same deadline later in the frame;
        # only callbacks that actually sleep contribute a wait overshoot.
        if event["sleeps"]:
            budget["maximum_deadline_overshoot_usec"] = max(budget["maximum_deadline_overshoot_usec"], ended - deadline, 0)
        need(budget["requested_sleep_usec"] <= limit, "Aggregate requested sleep exceeded the shared budget")
    if policy == "render-overlap" and thread == "separate":
        need(any(event["polls"] > 0 and event["sleeps"] > 0 for event in waits),
             "Separate render-overlap treatment never exercised an actual native wait")
    physical = [e for e in events if e.get("event") == "rapier_step"]
    matched = [e for e in physical if 1 <= e["step"] <= 144]
    need([e["step"] for e in matched] == list(range(1, 145)), "Missing/duplicate matched physical completion")
    frame_times = [event_time(f) for f in frames]
    frame_gaps = [(b - a) / 1000 for a, b in zip(frame_times, frame_times[1:])]
    need(all(gap > 0 for gap in frame_gaps), "Nonmonotonic Main submissions")
    window = [event_time(matched[0]), event_time(matched[-1])]
    matched_frames = [t for t in frame_times if window[0] <= t <= window[1]]
    return {
        "actual": status,
        "whole_capture_main_submission_gap_ms": distribution(frame_gaps),
        "matched_completion_window_usec": window,
        "matched_window_main_submission_gap_ms": distribution([(b-a)/1000 for a,b in zip(matched_frames,matched_frames[1:])]),
        "whole_capture_physical_completions": len(physical),
        "extra_physical_steps_outside_matched_prefix": [e["step"] for e in physical if not 1 <= e["step"] <= 144],
        "rendezvous_events": len(waits),
        "rendezvous_statuses": dict(Counter(str(e.get("status", "unknown")) for e in waits)),
        "rendezvous_events_raw": waits,
        "rendezvous_frame_budgets": budgets,
        "render_queue_markers": markers,
        "post_draw_association": (
            "Unavailable: threaded Godot defers post-draw notification to Main; "
            "its current process frame is not a certified draw identity."
            if thread == "separate" else "Ordinary same-thread post-draw notification"),
        "upload_scope_notice": (
            "Separate-thread upload timers measure command preparation/enqueue, not backend completion."
            if thread == "separate" else "Elapsed publication API scopes include waits and descheduling."),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--rendering-driver", choices=("opengl3", "opengl3_angle"), required=True)
    parser.add_argument("--modes", nargs="+", choices=tuple(MODES), default=list(ORDER))
    parser.add_argument("--condition", choices=("interactive-follow", "interactive-free"), default="interactive-follow")
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--development", action="store_true", help="Label an immutable working delta; never exact-source qualification")
    args = parser.parse_args()
    args.project, args.godot, args.evidence = args.project.resolve(), args.godot.resolve(), args.evidence.resolve()
    need(not args.evidence.exists(), "Fresh evidence directory required; retain failed attempts")
    need(git("rev-parse", "HEAD").decode().strip() == args.source_sha, "Wrong source parent")
    if not args.development:
        verify_candidate_project(args.source_sha, args.project)
    runtimes = verify_runtime_project(args.source_sha, args.project)
    matrix_path = args.project / "tests/fixtures/engine_lab/coherence-conditions.json"
    matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
    condition = next(c for c in matrix["conditions"] if c["name"] == args.condition)
    args.evidence.mkdir(parents=True)
    before = fingerprint(args.project, args.godot)
    report = {
        "schema": "native-rendezvous-factorial-v2", "source": args.source_sha,
        "source_qualification": "working-delta-development" if args.development else "exact-commit",
        "source_delta": git("diff", "--", "godot/scripts", "godot/tests", "godot/shaders", "godot/project.godot").decode(),
        "source_delta_scope": "Invoking repository worktree diff, not an alternate --project directory. Executed project identity is the complete inputs_before/after.project fingerprint.",
        "inputs_before": before, "runtimes": runtimes, "condition": condition,
        "matrix_sha256": sha(matrix_path), "order": args.modes, "arms": [], "pairs": [], "failures": [],
        "physical_acceptance": "HOLD: no physical Windows11/NVIDIA execution",
        "observer": "Identical event configuration, not an assertion of identical observer CPU cost",
        "complete": False,
    }
    output = args.evidence / "summary.json"
    write(output, report)
    reference = None
    for index, mode in enumerate(args.modes):
        thread, policy = MODES[mode]
        selected = dict(condition, name=f"{index:02d}-{mode}-{condition['name']}")
        args.render_thread, args.coherence = thread, True
        env = {"CYBERSAND_DIAG_NATIVE_RENDEZVOUS": SELECTORS[policy],
               "CYBERSAND_MATERIAL_PUBLICATION": "auto",
               "CYBERSAND_DIAG_COMMON_OBSERVER": "0", "CYBERSAND_DIAG_PHYSICS_PUBLICATION": "early",
               "CYBERSAND_DIAG_MATERIAL_COPY_MODE": "runs", "CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS": "3"}
        row = {"index": index, "mode": mode, "environment": env, "complete": False}
        report["arms"].append(row)
        try:
            row["inputs_before"] = fingerprint(args.project, args.godot)
            need(row["inputs_before"] == before, "Source/runtime drift before arm")
            with environment(env):
                result, _ = run_case(args, selected, "coherent")
            trace = args.evidence / "cases" / (selected["name"] + "-coherent") / "receipt-poses.jsonl"
            metrics, states = reduction(trace, 144)
            whole_metrics, whole_states = reduction(trace)
            need(metrics["source"] == args.source_sha, "Trace source identity changed")
            need(all(value == 0 for value in metrics["observer_drops"].values()), "Observer lost events")
            need(metrics["duplicate_render_publications"] == 0, "Duplicate graphical publication identity")
            need(metrics["backend_modes"] and set(metrics["backend_modes"]) == {"blit"}
                 and not metrics["fallback_reasons"], "Wrong or failed material backend")
            exact_common_states(states, states)
            row.update(result=result, metrics=metrics, whole_capture_metrics=whole_metrics,
                       whole_capture_step_bodies=len(whole_states),
                       scheduling=additional_metrics(trace, mode), complete=True)
            if reference is None:
                reference = (index, mode, states)
            else:
                comparison = exact_common_states(reference[2], states)
                report["pairs"].append({"left_index": reference[0], "right_index": index, **comparison})
                need(comparison["exact"], "Recorded physical bodies/associations differ at matched steps")
        except (RuntimeError, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
            row["failure"] = str(error)
            report["failures"].append({"index": index, "mode": mode, "error": str(error)})
        row["inputs_after"] = fingerprint(args.project, args.godot)
        if row["inputs_after"] != before:
            report["failures"].append({"index": index, "mode": mode, "error": "Source/runtime drift after arm"})
        write(output, report)
    after = fingerprint(args.project, args.godot)
    report["inputs_after"] = after
    if before != after:
        report["failures"].append({"error": "Executed source/runtime changed during experiment"})
    report["complete"] = not report["failures"] and all(row["complete"] for row in report["arms"])
    write(output, report)
    print(json.dumps({"complete": report["complete"], "arms": len(report["arms"]), "failures": report["failures"]}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
