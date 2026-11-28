#!/usr/bin/env python3
"""Independently re-reduce retained PUBPRES v3 traces without rewriting them.

The frozen v3 validator remains the admission oracle for the original fixture,
actors, input leases, native responses, terrain, Water ledger and callback
credit. This module independently computes the selected timing statistics and
checks them against the original analysis. It does not claim to re-execute an
old binary, prove GPU completion, or qualify a successor implementation.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import copy
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys

LEGACY = Path(__file__).resolve().parents[1] / "pubpres_playability"
sys.path.insert(0, str(LEGACY))
from results_same_frame import reduce_receipt  # noqa: E402


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def distribution(values):
    """Registered linear quantiles, independently implemented here."""
    items = sorted(values)
    require(all(math.isfinite(v) and v >= 0 for v in items), "Invalid duration")
    if not items:
        return None

    def percentile(fraction):
        position = fraction * (len(items) - 1)
        lower = math.floor(position)
        upper = math.ceil(position)
        return items[lower] + (items[upper] - items[lower]) * (position - lower)

    return {"count": len(items), "p50": percentile(.5), "p95": percentile(.95),
            "p99": percentile(.99), "max": items[-1]}


def packet_key(row, step=False):
    # V3 worker snapshots do not expose session/epoch. Do not manufacture them.
    # Its strict validator independently enforces the one live physical owner.
    return (row["world_generation"], row["native_tick_used" if step else "tick_index"],
            row["completed_body_sample"], row["required_hard_revision"])


def first_healthy_handoffs(events):
    first = {}
    for row in events:
        if row["event"] != "worker_snapshot" or row["failed"]:
            continue
        if row["hard_surface_revision"] != row["required_hard_revision"]:
            continue
        stamp = row.get("physics_handoff_usec")
        if not isinstance(stamp, (int, float)) or stamp <= 0:
            continue
        key = packet_key(row)
        first[key] = min(first.get(key, stamp), stamp)
    return first


def independent_window(events, receipt, end):
    start = receipt["capture_start_usec"]
    require(start < end <= receipt["capture_end_usec"], "Window exceeds actual capture")
    inside = [r for r in events if start <= r["time_usec"] <= end]

    def rows(kind, clock="time_usec"):
        return sorted((r for r in inside if r["event"] == kind), key=lambda r: r[clock])

    def gaps(items, clock="time_usec"):
        return distribution((b[clock] - a[clock]) / 1000 for a, b in zip(items, items[1:]))

    def spans(items):
        return distribution((r["time_usec"] - r["start_usec"]) / 1000 for r in items)

    steps = rows("rapier_step", "step")
    native = rows("native_completion_observed", "tick_index")
    main = rows("main_callback", "start_usec")
    callbacks = rows("physics_callback", "start_usec")
    attempts = rows("physics_continuation", "start_usec")
    uploads = rows("texture_upload")
    first = first_healthy_handoffs(events)
    completions = {(r["world_generation"], r["tick_index"]): r for r in events
                   if r["event"] == "native_completion_observed"}
    pre_handoff, ready_wait, ready_to_complete = [], [], []
    for step in steps:
        key = packet_key(step, step=True)
        # Bootstrap and a possible trailing unfinished full-publication hook
        # remain unavailable, not fabricated zero-latency observations.
        if key not in first or key[:2] not in completions:
            continue
        stamp = first[key]
        require(stamp <= step["time_usec"], "Consumed packet published after step")
        ready_to_complete.append((step["time_usec"] - stamp) / 1000)
        if stamp <= step["start_usec"]:
            ready_wait.append((step["start_usec"] - stamp) / 1000)
        completed = step.get("native_completed_usec")
        if completed is not None and completed > 0:
            require(completed <= stamp, "Native completion follows first healthy handoff")
            pre_handoff.append((stamp - completed) / 1000)
    unique = {}
    for row in rows("worker_snapshot"):
        unique.setdefault((row["world_generation"], row["tick_index"]), row)
    tick_work = [r["native_tick_ms"] for key, r in unique.items()
                 if key in completions and start <= completions[key]["time_usec"] <= end]
    duration = (end - start) / 1e6
    return {
        "start_usec": start, "end_usec": end, "duration_seconds": duration,
        "completed_rapier_steps": len(steps), "completed_native_ticks": len(native),
        "rapier_steps_per_second": len(steps) / duration,
        "native_ticks_per_second": len(native) / duration,
        "physical_gap_ms": gaps(steps), "frame_ms": gaps(main, "start_usec"),
        "physical_no_step_prefix_ms": (steps[0]["time_usec"] - start) / 1000 if steps else duration * 1000,
        "physical_no_step_suffix_ms": (end - steps[-1]["time_usec"]) / 1000 if steps else duration * 1000,
        "native_tick_ms": distribution(tick_work),
        "native_exact_to_first_physics_handoff_ms": distribution(pre_handoff),
        "first_physics_handoff_to_execution_start_ms": distribution(ready_wait),
        "first_physics_handoff_to_rapier_ms": distribution(ready_to_complete),
        "rapier_solver_ms": distribution(r["solver_usec"] / 1000 for r in steps),
        "main_callback_ms": spans(main), "material_submission_ms": spans(uploads),
        "material_age_at_main_end_ms": distribution(
            (r["time_usec"] - r["uploaded_generated_usec"]) / 1000
            for r in main if r.get("uploaded_generated_usec", 0) > 0),
        "physics_callback_count": len(callbacks),
        "callback_burst_sizes": dict(sorted(Counter(Counter(r["process_frame"] for r in callbacks).values()).items())),
        "callbacks_without_step": sum(r["before_step"] == r["after_step"] for r in callbacks),
        "callbacks_with_pending_terrain": sum(r["pending_hard_chunks"] > 0 for r in callbacks),
        "continuation_attempts": len(attempts),
        "continuation_completed": sum(bool(r["advanced"]) for r in attempts),
        "continuation_outcomes": dict(sorted(Counter(r["status"] for r in attempts).items())),
    }


COMPARABLE = (
    "duration_seconds", "completed_rapier_steps", "completed_native_ticks",
    "rapier_steps_per_second", "native_ticks_per_second", "physical_gap_ms",
    "frame_ms", "physical_no_step_prefix_ms", "physical_no_step_suffix_ms",
    "native_tick_ms", "native_exact_to_first_physics_handoff_ms",
    "first_physics_handoff_to_execution_start_ms", "first_physics_handoff_to_rapier_ms",
    "rapier_solver_ms", "main_callback_ms", "material_submission_ms",
    "material_age_at_main_end_ms",
)


def assert_selected_equal(actual, expected, path=""):
    """Only tolerate floating arithmetic roundoff, not scientific differences."""
    if isinstance(actual, dict):
        for key, value in actual.items():
            require(key in expected, "Missing original statistic: " + path + key)
            assert_selected_equal(value, expected[key], path + key + ".")
    elif isinstance(actual, (float, int)) and not isinstance(actual, bool):
        require(isinstance(expected, (float, int)) and
                math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-9),
                f"Independent statistic differs at {path}: {actual} versus {expected}")
    else:
        require(actual == expected, "Independent statistic differs at " + path)


def audit_arm(path):
    receipt = json.loads(path.read_text())
    arm_path = path.with_name("arm.json")
    arm = json.loads(arm_path.read_text())
    campaign_path = next(p / "campaign.json" for p in path.parents if (p / "campaign.json").is_file())
    campaign = json.loads(campaign_path.read_text())
    effective = copy.deepcopy(campaign)
    letter = path.parent.name.split("-")[-1]
    effective["arms"][letter] = arm["arm"]
    require(receipt["source_identity"]["source_sha"] == arm["source"]["source_commit"], "Arm source differs")
    require(receipt["case_nonce"] == arm["nonce"], "Arm nonce differs")
    require(arm["source"]["qualified_exact_head"] is True and
            not arm["source"]["working_tree_changes"] and
            not arm["source"]["untracked_source_files"], "Original arm source was not exact")
    native = arm["source"]["native_runtime"]
    resource = "res://" + native["staged_relative_path"].replace("\\", "/")
    require(receipt["source_identity"]["files"].get(resource) == native["binary_sha256"], "Runtime receipt differs")
    require(native["build_commit"] == arm["source"]["source_commit"], "Runtime built from another source")
    # The preserved strict validator verifies actual PNG bytes as well as the
    # frozen fixture/Water/actor/sample/terrain/callback evidence. No project or
    # engine is supplied: archived hash custody is not a fresh binary replay.
    validated = reduce_receipt(path, effective, arm_letter=letter)
    trace = path.with_name(path.stem + "-events.jsonl")
    events = [json.loads(line) for line in trace.read_text().splitlines()][1:]
    steps = sorted((r for r in events if r["event"] == "rapier_step"), key=lambda r: r["step"])
    ends = {"first_10s": receipt["capture_start_usec"] + 10_000_000,
            "first_144_steps": steps[143]["time_usec"], "whole_capture": receipt["capture_end_usec"]}
    original_path = path.with_name("analysis.json")
    original = json.loads(original_path.read_text())
    windows = {}
    for name, end in ends.items():
        windows[name] = independent_window(events, receipt, end)
        selected = {k: windows[name][k] for k in COMPARABLE}
        assert_selected_equal(selected, original["windows"][name])
        assert_selected_equal(selected, validated["windows"][name])
    process = json.loads(path.with_name("process.json").read_text())
    require(process["exit_code"] == 0 and not process["timed_out"], "Original process did not exit cleanly")
    workers = [r["sample"] for r in events if r["event"] == "worker_participation"]
    return {
        "receipt": str(path), "receipt_sha256": sha256(path), "trace_sha256": sha256(trace),
        "arm_sha256": sha256(arm_path), "registration_sha256": sha256(campaign_path),
        "original_analysis_sha256": sha256(original_path),
        "source_commit": arm["source"]["source_commit"], "source_tree": arm["source"]["source_tree"],
        "native_runtime_sha256": native["binary_sha256"],
        "native_source_inputs_sha256": native["source_inputs_sha256"],
        "engine_sha256": receipt["source_identity"]["engine_sha256"],
        "rapier_runtime_hashes": {k: v for k, v in receipt["source_identity"]["files"].items()
                                  if "godot-rapier2d/bin/" in k},
        "platform": receipt["platform"], "cpu": receipt["cpu"], "adapter": receipt["adapter"],
        "logical_processors": receipt["logical_processors"], "case": arm["scenario"]["id"],
        "diagnostic": campaign_path.parent.name, "order_index": arm["order_index"],
        "treatment": arm["arm"], "water_profile": receipt["water_profile"],
        "fixture": receipt["fixture"], "worker_capacity": sorted({r["worker_capacity"] for r in workers}),
        "workers_observed_range": [min(r["workers_observed"] for r in workers), max(r["workers_observed"] for r in workers)],
        "physical_outcome_sha256": validated["first_144_body_trajectory_sha256"],
        "admitted_moves_sha256": validated["first_144_admitted_moves_sha256"],
        "water_ledger_before": validated["water_ledger_before"], "water_ledger_after": validated["water_ledger_after"],
        "strict_original_evidence_validation": "PASS", "independent_metric_crosscheck": "PASS",
        "callback_credit": validated["same_frame_continuation"], "windows": windows,
        "process_peak_rss_bytes": process.get("sampled_peak_rss_bytes") if process.get("app_sampler_pid_matched") else None,
        "godot_static_peak_bytes": receipt["static_memory_peak_bytes"],
        "reported_video_final_bytes": receipt["video_memory_bytes"],
    }


def summarize_cohorts(arms):
    groups = defaultdict(list)
    for arm in arms:
        groups[(arm["platform"], arm["case"], arm["diagnostic"])].append(arm)
    result = []
    for (platform, case, diagnostic), rows in sorted(groups.items()):
        rows.sort(key=lambda r: r["order_index"])
        knob = "wave_column_probe" if "native-probe" in diagnostic else "same_frame_continuation"
        require([r["order_index"] for r in rows] == [0, 1, 2, 3], "Incomplete ABBA group")
        require([r["treatment"][knob] for r in rows] == [False, True, True, False], "ABBA treatment order differs")
        for field in ("source_commit", "source_tree", "native_runtime_sha256", "engine_sha256",
                      "cpu", "adapter", "water_profile", "fixture", "worker_capacity"):
            require(all(r[field] == rows[0][field] for r in rows), "Comparison identity differs: " + field)
        treatment = [{k: v for k, v in r["treatment"].items() if k != knob} for r in rows]
        require(all(t == treatment[0] for t in treatment), "Uncontrolled treatment in paired group")
        parity = len({r["physical_outcome_sha256"] for r in rows}) == 1 and len({r["admitted_moves_sha256"] for r in rows}) == 1
        require(parity, "Same-source physical outcome or admitted-move divergence")
        cohort = {"platform": platform, "case": case, "diagnostic": diagnostic, "knob": knob,
                  "paired_identity": "PASS", "first_144_physical_parity": "PASS", "settings": {}}
        for selected in (False, True):
            subset = [r for r in rows if r["treatment"][knob] == selected]
            cohort["settings"]["ON" if selected else "OFF"] = {
                name: {"steps_per_second_runs": [r["windows"][name]["rapier_steps_per_second"] for r in subset],
                       "steps_per_second_mean": statistics.mean(r["windows"][name]["rapier_steps_per_second"] for r in subset),
                       "physical_p95_ms_runs": [r["windows"][name]["physical_gap_ms"]["p95"] for r in subset],
                       "physical_p99_ms_runs": [r["windows"][name]["physical_gap_ms"]["p99"] for r in subset],
                       "physical_max_ms_runs": [r["windows"][name]["physical_gap_ms"]["max"] for r in subset],
                       "continuation_completed": sum(r["windows"][name]["continuation_completed"] for r in subset),
                       "continuation_outcomes": dict(sum((Counter(r["windows"][name]["continuation_outcomes"]) for r in subset), Counter()))}
                for name in ("first_10s", "first_144_steps", "whole_capture")}
        result.append(cohort)
    return result


def report_markdown(result):
    lines = ["# PUBPRES-003 independent audit of retained PUBPRES-001 traces", "",
             "This is a fresh reduction of immutable old captures, not a new software execution or successor qualification.", "",
             f"Validated arms: **{len(result['arms'])}**. Refused records: **{len(result['failures'])}**. "
             "Every admitted arm passes the unchanged v3 evidence validator and an independent numerical cross-check.", "",
             "## Paired startup progression", "",
             "Rates are the mean of two run-level first-10-second rates. Gap quantiles remain per-run; they are not averaged or pooled.", "",
             "| Platform | Workload | Intervention | OFF steps/s | ON steps/s | OFF p95 gaps (ms) | ON p95 gaps (ms) |",
             "|---|---|---|---:|---:|---|---|"]
    for c in result["cohorts"]:
        off, on = (c["settings"][s]["first_10s"] for s in ("OFF", "ON"))
        nums = lambda values: ", ".join("unavailable" if v is None else f"{v:.1f}" for v in values)
        lines.append(f"| {c['platform']} | {c['case']} | {c['knob']} | {off['steps_per_second_mean']:.2f} | {on['steps_per_second_mean']:.2f} | {nums(off['physical_p95_ms_runs'])} | {nums(on['physical_p95_ms_runs'])} |")
    lines += ["", "## Individual continuation arms", "",
              "The table retains each first-10-second observation. Full-capture and equal-144-step windows, source/runtime identities, original hashes and refusal counts are in the adjacent JSON.", "",
              "| Platform / workload | Arm | Steps/s | Physical p95 / p99 / max (ms) | Native tick p50 / p95 (ms) | First handoff wait p50 / p95 (ms) |",
              "|---|---|---:|---|---|---|"]
    for a in result["arms"]:
        if "same-frame" not in a["diagnostic"]:
            continue
        w = a["windows"]["first_10s"]
        fmt = lambda d, keys: " / ".join("unavailable" if d is None or d[k] is None else f"{d[k]:.1f}" for k in keys)
        lines.append(f"| {a['platform']} / {a['case']} | {a['order_index']} {'ON' if a['treatment']['same_frame_continuation'] else 'OFF'} | {w['rapier_steps_per_second']:.2f} | {fmt(w['physical_gap_ms'],('p95','p99','max'))} | {fmt(w['native_tick_ms'],('p50','p95'))} | {fmt(w['first_physics_handoff_to_execution_start_ms'],('p50','p95'))} |")
    lines += ["", "## Interpretation limits", "",
              "Historical Wave uses one round without spill or ballistic transport. Current gameplay uses two rounds with the registered spill/parcels/ballistic mechanics. These are different workloads.", "",
              "First healthy handoff joins native World, tick, body sample and terrain revision. Repeated status publication cannot reset packet age. The v3 worker events do not expose every session/epoch or actual Main mailbox-observation/install boundary, so these captures cannot distinguish delayed observation from every form of later admission delay.", "",
              "Main frame gaps and frame_post_draw callbacks are CPU event-loop observations. They do not establish GPU completion, scanout or physical NVIDIA performance. Windows captures used the recorded hosted ANGLE adapter.", "",
              "Original failed/incomplete records are retained and listed below; none is promoted to a successful generation.", ""]
    lines.extend(f"- {f['receipt']}: {f['reason']}" for f in result["failures"])
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="Retained extracted campaign folder(s)")
    parser.add_argument("--output", type=Path, required=True, help="New audit JSON; refuses existing files")
    args = parser.parse_args()
    markdown = args.output.with_suffix(".md")
    require(not args.output.exists() and not markdown.exists(), "Refusing to overwrite existing evidence")
    arms, failures = [], []
    for path in sorted(args.root.rglob("receipt.json")):
        if not path.with_name("arm.json").is_file():
            continue
        try:
            arms.append(audit_arm(path))
        except (ValueError, KeyError, OSError, StopIteration) as error:
            failures.append({"receipt": str(path), "reason": str(error)})
    require(arms or failures, "No retained arm receipts found")
    cohorts = []
    try:
        cohorts = summarize_cohorts(arms)
    except ValueError as error:
        failures.append({"receipt": "paired_cohort_validation", "reason": str(error)})
    result = {"schema": "pubpres003-retained-trace-audit-v1", "physical_acceptance": "HOLD",
              "scope": "Original v3 oracle plus independent selected timing reduction; no fresh binary execution.",
              "auditor_sha256": sha256(__file__), "arms": arms, "cohorts": cohorts, "failures": failures}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    markdown.write_text(report_markdown(result))
    print(json.dumps({"audit": str(args.output), "arms": len(arms), "failures": failures, "physical_acceptance": "HOLD"}))
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
