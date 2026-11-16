#!/usr/bin/env python3
"""Same-source, eight-arm Windows independent-array staging ring probe.

Full and one/two/three independent one-layer array rings run in forward/reverse order.
Row coalescing is held constant across ring arms; runs versus tiles is not isolated.
The primary comparison is exactly completed physical steps 1..144; every raw
completion and whole-capture tail is retained. Functional completion is not a
performance pass or physical Windows 11/NVIDIA acceptance.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from contextlib import contextmanager
from itertools import combinations
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

from analyze_pose_trace import analyze_presentation_contract, distribution, event_time, read_trace
from package_engine_lab_windows import ENGINE_VERSION
from run_physics_freeze_comparison import (
    ROOT, exact_common_states, git, need, reduction, sha,
    verify_candidate_project, verify_runtime_project, write,
)
from run_render_cadence_matrix import run_case

SOURCE_EXTENSIONS = {".gd", ".gdshader", ".gdshaderinc", ".gdextension", ".tscn", ".tres", ".json", ".godot", ".cfg"}
HARNESS = (
    "tools/ci/run_material_staging_comparison.py", "tools/ci/run_physics_freeze_comparison.py",
    "tools/ci/run_render_cadence_matrix.py", "tools/ci/analyze_pose_trace.py",
    "tools/ci/package_engine_lab_windows.py", "tools/ci/run_camera_coherence_regressions.py",
    ".github/workflows/material-staging-probe.yml",
)
ORDER = ("full", "ring1", "ring2", "ring3", "ring3", "ring2", "ring1", "full")
REQUIRED_STEPS = 144
MINIMUM_COALESCED_PUBLICATIONS = 4
ENVIRONMENT = {
    # All arms use this same source, so retain actual Main callback events.
    "CYBERSAND_DIAG_COMMON_OBSERVER": "0",
    "CYBERSAND_DIAG_PHYSICS_PUBLICATION": "early",
    "CYBERSAND_DIAG_MATERIAL_COPY_MODE": "runs",
}


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


def normalized_sha(path):
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def fingerprint(project, godot, runtimes):
    sources = {p.relative_to(project).as_posix(): normalized_sha(p) for p in project.rglob("*")
               if p.is_file() and p.suffix in SOURCE_EXTENSIONS
               and not p.relative_to(project).as_posix().startswith(".godot/")}
    return {"project": sources, "harness": {name: normalized_sha(ROOT / name) for name in HARNESS},
            "runtime": {row["artifact"]: sha(project / row["artifact"]) for row in runtimes},
            "godot": sha(godot), "head": git("rev-parse", "HEAD").decode().strip()}


def integer(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and int(value) == value


def validate_copy_metrics(p, copy_mode="runs"):
    """Check declared copy work for the fixed, tile-aligned 2048-square fixture.

    Exact GPU bytes/history remain independently checked by the graphical gate.
    These counters cannot establish GPU execution time or causality.
    """
    need(p.get("copy_mode") == copy_mode, "Wrong actual material copy mode")
    keys = ("copy_destinations", "copy_run_count", "updated_tiles", "gpu_blit_calls",
            "uncoalesced_gpu_blit_calls", "coalesced_gpu_blit_calls_saved", "blit_pixels",
            "uncoalesced_blit_pixels", "estimated_target_write_bytes", "retirement_blit_calls",
            "estimated_retirement_write_bytes")
    need(all(integer(p.get(key)) and p[key] >= 0 for key in keys), "Missing or invalid actual copy counters")
    need(p["copy_destinations"] == 1, "Ordinary publication does not target exactly one history plane")
    if p["submitted_bytes"] == 0:
        need(all(p[key] == 0 for key in keys if key != "copy_destinations"), "No-op publication claimed GPU copy work")
        return {"sparse": False, "coalesced": False}
    updated, tile_side, tiles = p["updated_tiles"], p["tile_side"], p["tile_count"]
    need(1 <= updated <= tiles and tiles * tile_side ** 2 == 2048 ** 2,
         "Copy counters no longer describe the fixed tile-aligned World")
    capacity = next((n for n in (1, 4, 16, 64, 256) if n >= updated), None)
    need(capacity is not None and p["atlas_capacity"] == capacity,
         "Copy planning increased staging capacity beyond the unchanged tile list")
    need(isinstance(p.get("whole_gpu_copy"), bool), "Missing whole-copy distinction")
    whole = p["whole_gpu_copy"]
    need(whole == (capacity == tiles), "Whole-copy path differs from the fixed staging capacity")
    runs = p["copy_run_count"]
    need((whole and runs == 1) or (not whole and 1 <= runs <= updated), "Invalid copy-run count")
    baseline = 1 if whole else updated
    need(p["uncoalesced_gpu_blit_calls"] == baseline and p["gpu_blit_calls"] == runs,
         "Actual/baseline copy counts disagree with runs and destinations")
    need(p["coalesced_gpu_blit_calls_saved"] == baseline - runs, "Incorrect saved-copy count")
    need(not whole or p["coalesced_gpu_blit_calls_saved"] == 0, "Pre-existing full copy counted as coalescing")
    need(copy_mode != "tiles" or p["coalesced_gpu_blit_calls_saved"] == 0,
         "Per-tile control unexpectedly coalesced GPU copies")
    pixels = (tiles if whole else updated) * tile_side ** 2
    need(p["blit_pixels"] == p["uncoalesced_blit_pixels"] == pixels,
         "Coalescing changed declared destination pixels")
    need(p["estimated_target_write_bytes"] == 4 * pixels,
         "RGBA destination-write estimate disagrees with exact copy area")
    need(p["retirement_blit_calls"] == 1 and p["estimated_retirement_write_bytes"] == 4,
         "Missing or miscounted separate retirement draw")
    return {"sparse": not whole, "coalesced": not whole and runs < updated}


def validate_publications(events, backend, slots):
    uploads = [e for e in events if e.get("event") == "texture_upload"]
    need(bool(uploads), "No material publications were observed")
    generations = {e.get("world_generation") for e in uploads}
    need(len(generations) == 1 and all(integer(g) and g >= 0 for g in generations),
         "Unexpected World retirement/reset in the fixed staging workload")
    resources, reverse, previous, counts = {}, {}, {}, Counter()
    initializations, noops, records = [], 0, []
    allocation, coalesced = set(), 0
    for event in uploads:
        p = event.get("material_publication")
        need(isinstance(p, dict), "Missing material publication readback")
        need(p.get("backend") == backend and not p.get("fallback_reason"),
             "Wrong material backend or automatic fallback during probe")
        if backend == "full":
            continue
        need(p.get("staging_backend") == "texture2d_array", "Wrong staging resource kind")
        need(integer(p.get("staging_slots")) and p["staging_slots"] == slots, "Wrong staging slot count")
        need(integer(p.get("staging_resource_layers")) and p["staging_resource_layers"] == 1,
             "Staging resource is not an independent one-layer array")
        need(p.get("copy_mode") == "runs", "Copy mode changed between ring arms")
        identity_keys = ("staging_slot", "staging_layer", "staging_resource_rid", "atlas_capacity", "submitted_bytes")
        need(all(key in p for key in identity_keys), "Missing actual staging resource identity")
        slot, layer, rid, capacity, submitted = (p[k] for k in identity_keys)
        need(all(integer(v) for v in (slot, layer, rid, capacity, submitted)) and submitted >= 0,
             "Invalid staging resource or byte counters")
        expected_payload = 33554437 + 11173888 * slots
        need(integer(p.get("allocated_gpu_bytes")) and p["allocated_gpu_bytes"] == expected_payload,
             "GPU texture payload estimate differs from the bounded 2048-square ring")
        allocation.add(p["allocated_gpu_bytes"])
        if submitted == 0:
            need((slot, layer, rid, capacity) == (-1, -1, 0, 0), "No-op publication claimed a staging resource")
            validate_copy_metrics(p)
            noops += 1
            continue
        need(0 <= slot < slots and layer == 0 and rid > 0 and capacity > 0,
             "Invalid independent staging resource/layer selection")
        need(integer(p.get("tile_count")) and capacity <= p["tile_count"], "Staging capacity exceeds fixed World tiles")
        if p.get("initialization", False):
            # Setup aggregates both histories and priming. Preserve it; ordinary
            # rotation/copy equations start afterward, from the actual cursor.
            initializations.append(event)
            continue
        need(integer(p.get("tile_side")) and p["tile_side"] > 0 and p.get("logical_source_format") == "RG8",
             "Probe no longer uses exact RG8 material tiles")
        need(submitted == capacity * p["tile_side"] ** 2 * 2, "Staging bytes do not match reported RG8 capacity")
        copy = validate_copy_metrics(p)
        coalesced += int(copy["coalesced"])
        key = (int(capacity), int(slot))
        need(key not in resources or resources[key] == rid, "Staging resource replaced within a fixed capacity/slot")
        need(rid not in reverse or reverse[rid] == key, "One staging RID aliases different ring slots or capacities")
        if capacity in previous:
            need(slot == (previous[capacity] + 1) % slots, "Staging slots do not rotate per nonempty capacity upload")
        resources[key], reverse[int(rid)], previous[int(capacity)] = int(rid), key, int(slot)
        counts[int(capacity)] += 1
        need(integer(p.get("staging_upload_usec")) and p["staging_upload_usec"] >= 0,
             "Missing staging call timing")
        records.append({"render_serial": event.get("render_serial"), "native_tick": event.get("native_tick"),
                        "completed_usec": event_time(event), "atlas_capacity": int(capacity),
                        "staging_backend": "texture2d_array", "staging_slot": int(slot), "staging_layer": 0,
                        "staging_resource_layers": 1, "staging_resource_rid": int(rid),
                        "submitted_bytes": int(submitted), "staging_upload_ms": p["staging_upload_usec"] / 1000,
                        "full_refresh": event.get("full_refresh", False), "whole_gpu_copy": p["whole_gpu_copy"],
                        **{name: p[name] for name in ("copy_mode", "copy_destinations", "copy_run_count", "updated_tiles",
                           "gpu_blit_calls", "uncoalesced_gpu_blit_calls", "coalesced_gpu_blit_calls_saved",
                           "blit_pixels", "uncoalesced_blit_pixels", "retirement_blit_calls")}})
    if backend == "blit":
        need(bool(records), "No noninitialization staging uploads were observed")
        need(len(allocation) == 1, "GPU allocation estimate changes within fixed staging workload")
        need(any(count >= max(4, slots * 2) for count in counts.values()), "Insufficient repeated staging reuse")
        need(coalesced >= MINIMUM_COALESCED_PUBLICATIONS, "Fewer than four ordinary sparse publications exercised coalescing")
    return {"backend": backend, "staging_backend": "texture2d_array" if backend == "blit" else None,
            "staging_slots": slots, "staging_resource_layers": 1 if backend == "blit" else None,
            "copy_mode": "runs" if backend == "blit" else None,
            "upload_events": len(uploads), "world_generation": next(iter(generations)),
            "initialization_events": initializations, "no_change_events": noops,
            "ordinary_coalesced_publications": coalesced, "allocated_gpu_bytes": sorted(allocation),
            "allocation_meaning": "Declared texture payload estimate; driver overhead is not measured",
            "resource_ledger": [{"atlas_capacity": key[0], "staging_backend": "texture2d_array", "staging_slot": key[1],
                                 "staging_layer": 0, "staging_resource_layers": 1, "staging_resource_rid": value}
                                for key, value in sorted(resources.items())],
            "ordinary_upload_records": records}


def copy_statistics(events):
    rows = [e["material_publication"] for e in events if e.get("event") == "texture_upload"
            and e.get("material_publication", {}).get("backend") == "blit"
            and not e["material_publication"].get("initialization", False)
            and e["material_publication"].get("submitted_bytes", 0) > 0]
    sparse = [p for p in rows if not p["whole_gpu_copy"]]
    merged = [p for p in sparse if p["coalesced_gpu_blit_calls_saved"] > 0]
    return {"ordinary_nonempty_publications": len(rows), "ordinary_sparse_publications": len(sparse),
            "ordinary_sparse_coalesced_publications": len(merged),
            "minimum_coalesced_publications": MINIMUM_COALESCED_PUBLICATIONS,
            "coalescing_exercised": len(merged) >= MINIMUM_COALESCED_PUBLICATIONS,
            "copy_modes": dict(Counter(p["copy_mode"] for p in rows)),
            "sparse_uncoalesced_calls": sum(p["uncoalesced_gpu_blit_calls"] for p in sparse),
            "sparse_actual_calls": sum(p["gpu_blit_calls"] for p in sparse),
            "sparse_saved_calls": sum(p["coalesced_gpu_blit_calls_saved"] for p in sparse),
            "sparse_copied_pixels": sum(p["blit_pixels"] for p in sparse),
            "sparse_uncoalesced_pixels": sum(p["uncoalesced_blit_pixels"] for p in sparse),
            "meaning": "Observed sparse copy reduction, excluding initialization, dense full copies and retirement. "
                       "Runs versus tiles is not causally isolated by this timing experiment; physical/frame tails remain decisive."}


def staging_statistics(events):
    groups = defaultdict(list)
    initialized = []
    for event in events:
        if event.get("event") != "texture_upload":
            continue
        p = event.get("material_publication", {})
        if p.get("initialization", False):
            initialized.append(event)
        elif p.get("backend") == "blit" and p.get("submitted_bytes", 0) > 0:
            groups[(p["atlas_capacity"], p["staging_slot"])].append(p["staging_upload_usec"] / 1000)
    return {"initialization_events": initialized,
            "steady_by_capacity_and_slot": [
                {"atlas_capacity": key[0], "staging_backend": "texture2d_array", "staging_slot": key[1],
                 "staging_layer": 0, "staging_resource_layers": 1, "elapsed_ms": distribution(values),
                 "calls_at_least_ms": {str(limit): sum(v >= limit for v in values) for limit in (50, 100, 250, 1000)}}
                for key, values in sorted(groups.items())],
            "meaning": "Elapsed staging API calls, including possible waits/descheduling; not isolated CPU or GPU execution. "
                       "Only initialization=true is excluded from these steady staging groups; physical/frame tails exclude no stalls."}


def timed_reduction(trace, maximum_step=None):
    reduced, states = reduction(trace, maximum_step)
    header, frames, footer = read_trace(trace)
    events = footer["_events"]
    if maximum_step is not None:
        steps = [e for e in events if e.get("event") == "rapier_step" and 1 <= int(e["step"]) <= maximum_step]
        need(len(steps) == maximum_step, "Missing exact 1..144 physical comparison prefix")
        begin, end = min(map(event_time, steps)), max(map(event_time, steps))
        frames = [f for f in frames if begin <= event_time(f) <= end]
        events = [e for e in events if event_time(e) is not None and begin <= event_time(e) <= end]
    reduced["frame_submission_interval_ms"] = distribution([
        (event_time(b) - event_time(a)) / 1000 for a, b in zip(frames, frames[1:])])
    reduced["presentation_contract"] = analyze_presentation_contract(frames)
    reduced["event_counts"] = dict(Counter(e.get("event", "unknown") for e in events))
    reduced["staging"] = staging_statistics(events)
    reduced["copy_coalescing"] = copy_statistics(events)
    need(reduced["main_callback_elapsed_ms"]["count"] > 0, "Full common observer did not record Main callback durations")
    need(not any(reduced["observer_drops"].values()), "Observer overflow invalidates staging comparison")
    return reduced, states, header, events


def host_contract(receipt):
    return {key: receipt[key] for key in ("cpu", "native_workers", "effective_pacing", "display", "video_adapter", "render_driver")}


def compare_metric(before, after):
    return {"before": before, "after": after,
            "delta": after - before if isinstance(before, (int, float)) and isinstance(after, (int, float)) else None}


def contrast(left, right):
    a, b = left["matched_144"], right["matched_144"]
    pa, pb = a["physics"], b["physics"]
    return {"before_order": left["order"], "after_order": right["order"],
            "before_arm": left["arm"], "after_arm": right["arm"],
            "rates_hz": {key: compare_metric(a["rates_hz"].get(key), b["rates_hz"].get(key)) for key in ("rapier", "native", "main")},
            "physical_gap_ms": {key: compare_metric(pa["active_completed_step_gap_ms"].get(key), pb["active_completed_step_gap_ms"].get(key))
                                for key in ("median", "p95", "p99", "maximum")},
            "physical_gap_counts": {str(limit): compare_metric(pa[f"active_gaps_at_least_{limit}ms"], pb[f"active_gaps_at_least_{limit}ms"])
                                    for limit in (50, 100, 250, 1000)},
            "frame_interval_ms": {key: compare_metric(a["frame_submission_interval_ms"].get(key), b["frame_submission_interval_ms"].get(key))
                                  for key in ("median", "p95", "p99", "maximum")},
            "main_callback_ms": {key: compare_metric(a["main_callback_elapsed_ms"].get(key), b["main_callback_elapsed_ms"].get(key))
                                 for key in ("median", "p95", "p99", "maximum")}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--rendering-driver", choices=["opengl3", "opengl3_angle"], default="opengl3_angle")
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    args.project, args.evidence, args.godot = (p.resolve() for p in (args.project, args.evidence, args.godot))
    need(not args.evidence.exists(), "Use a fresh evidence directory; failed attempts must remain intact")
    args.evidence.mkdir(parents=True)
    output = args.evidence / "summary.json"
    report = {"schema": "material-independent-array-ring-comparison-v1", "source": args.source_sha,
              "order": list(ORDER), "required_physical_prefix": [1, REQUIRED_STEPS],
              "copy_mode_timing_scope": "runs held constant across ring arms; tiles control appears only in the GPU correctness gate",
              "minimum_ordinary_coalesced_publications": MINIMUM_COALESCED_PUBLICATIONS,
              "copy_coverage_gate_meaning": "Feature exercise only; failure retains raw evidence as unexercised coverage and does not justify changing the fixed workload",
              "cases": [], "physical_comparisons": [], "contrasts": [], "failures": [], "complete": False,
              "observer": {"environment": ENVIRONMENT, "all_arms_identical": True, "main_callback_events": "required", "drops_allowed": 0},
              "performance_acceptance": "unqualified_probe_requires_independent_tail_review",
              "physical_acceptance": "pending_owner_Windows11_NVIDIA", "runner_sha256": sha(Path(__file__))}
    write(output, report)
    before = None
    try:
        need(git("rev-parse", "HEAD").decode().strip() == args.source_sha, "Probe source is not current exact HEAD")
        report["source_tree"] = git("rev-parse", args.source_sha + "^{tree}").decode().strip()
        report["source_inputs"] = verify_candidate_project(args.source_sha, args.project)
        report["runtimes"] = verify_runtime_project(args.source_sha, args.project)
        for name in HARNESS:
            need((ROOT / name).read_bytes().replace(b"\r\n", b"\n") == git("show", args.source_sha + ":" + name).replace(b"\r\n", b"\n"),
                 "Uncommitted or substituted probe harness: " + name)
        version = subprocess.check_output([str(args.godot), "--version"], text=True, timeout=30).strip()
        need(version == ENGINE_VERSION, "Probe is not running pinned Godot 4.7")
        report["godot"] = {"path": str(args.godot), "version": version, "sha256": sha(args.godot)}
        before = fingerprint(args.project, args.godot, report["runtimes"])
        write(args.evidence / "frozen-inputs.json", before)
        with (args.evidence / "import.log").open("w", encoding="utf-8") as log:
            imported = subprocess.run([str(args.godot), "--headless", "--path", str(args.project), "--editor", "--quit"],
                                      stdout=log, stderr=subprocess.STDOUT, timeout=240)
        need(imported.returncode == 0 and "SCRIPT ERROR:" not in (args.evidence / "import.log").read_text(encoding="utf-8", errors="replace"), "Probe import failed")
        conditions_path = args.project / "tests/fixtures/engine_lab/coherence-conditions.json"
        condition = next(c for c in json.loads(conditions_path.read_text(encoding="utf-8"))["conditions"] if c["name"] == "interactive-follow")
        ordinary = {"pixel": 60, "rapier": 60, "fps": 0, "publication": 60,
                    "camera": "follow", "pose": "guarded", "ack": 0, "gated": False,
                    "wait": True, "wake": True, "smoothing": True, "fire": "on-off",
                    "workers": 0, "display_profile": "interactive-default"}
        need(all(condition.get(key) == value for key, value in ordinary.items()),
             "Probe no longer uses ordinary coupled Follow defaults")
        report["condition"] = condition
        report["condition_sha256"] = sha(conditions_path)
        states_by_arm, common_host = {}, None
        with environment(ENVIRONMENT):
            for index, arm in enumerate(ORDER):
                need(fingerprint(args.project, args.godot, report["runtimes"]) == before, "Source/runtime/harness changed before arm")
                backend, slots = ("full", None) if arm == "full" else ("blit", int(arm[-1]))
                arm_env = {"CYBERSAND_MATERIAL_PUBLICATION": backend,
                           "CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS": str(slots or 1)}
                directory = args.evidence / f"{index}-{arm}"
                trace = directory / "cases/interactive-follow-coherent/receipt-poses.jsonl"
                receipt_path = trace.with_name("receipt.json")
                row = {"order": index, "arm": arm, "backend": backend, "staging_slots": slots,
                       "environment": {**ENVIRONMENT, **arm_env}, "status": "running", "trace": str(trace)}
                report["cases"].append(row)
                write(output, report)
                try:
                    run_args = argparse.Namespace(**vars(args), coherence=True)
                    run_args.evidence = directory
                    with environment(arm_env):
                        row["case"], _ = run_case(run_args, condition, "coherent")
                    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
                    need(receipt["physics_publication"] == "early", "Arm did not use actual early physical publication")
                    final = receipt["material_publication"]
                    need(final.get("backend") == backend and not final.get("fallback_reason"), "Final material mode readback differs")
                    if slots is not None:
                        need(final.get("staging_slots") == slots, "Final staging slot readback differs")
                        need(final.get("staging_backend") == "texture2d_array", "Final staging resource kind differs")
                        need(final.get("staging_resource_layers") == 1 and final.get("copy_mode") == "runs",
                             "Final ring resource or copy mode differs")
                    row["whole_capture"], _, header, events = timed_reduction(trace)
                    need(header.get("settings", {}).get("source_commit") == args.source_sha, "Trace source identity differs")
                    row["publication_validation"] = validate_publications(events, backend, slots)
                    row["matched_144"], states, _, _ = timed_reduction(trace, REQUIRED_STEPS)
                    if slots is not None:
                        need(row["matched_144"]["copy_coalescing"]["coalescing_exercised"],
                             "Coalescing was not repeatedly exercised inside the exact physical comparison prefix")
                    equality = exact_common_states(states, states, required_steps=REQUIRED_STEPS)
                    need(equality["step_range"] == [1, REQUIRED_STEPS], "Primary comparison is not exactly steps 1..144")
                    states_by_arm[index] = states
                    current_host = host_contract(receipt)
                    if common_host is None:
                        common_host = current_host
                    need(current_host == common_host, "Host/display/worker/pacing settings changed between arms")
                    row["status"] = "passed"
                except (RuntimeError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
                    row["status"], row["error"] = "failed", str(error)
                    report["failures"].append({"arm": index, "error": str(error)})
                write(output, report)
                need(fingerprint(args.project, args.godot, report["runtimes"]) == before, "Source/runtime/harness changed during arm")
        report["host_contract"] = common_host
        for left in sorted(states_by_arm):
            for right in sorted(states_by_arm):
                if right <= left:
                    continue
                equality = exact_common_states(states_by_arm[left], states_by_arm[right], required_steps=REQUIRED_STEPS)
                report["physical_comparisons"].append({"left_order": left, "right_order": right, **equality})
                if not equality["exact"]:
                    report["failures"].append({"physical_comparison": [left, right], "error": "Physical state or feedback/terrain associations differ"})
        for indices in ((0, 1, 2, 3), (7, 6, 5, 4)):
            for left, right in combinations(indices, 2):
                if all(report["cases"][i]["status"] == "passed" for i in (left, right)):
                    report["contrasts"].append(contrast(report["cases"][left], report["cases"][right]))
        report["complete"] = len(report["cases"]) == len(ORDER) and all(row["status"] == "passed" for row in report["cases"]) and not report["failures"]
    except (RuntimeError, OSError, ValueError, KeyError, TypeError, StopIteration, subprocess.SubprocessError) as error:
        report["failures"].append({"scope": "campaign", "error": str(error)})
    finally:
        if before is not None:
            try:
                after = fingerprint(args.project, args.godot, report["runtimes"])
                write(args.evidence / "frozen-inputs-after.json", after)
                if before != after:
                    report["complete"] = False
                    report["failures"].append({"scope": "campaign", "error": "Final source/runtime/harness fingerprint changed"})
            except (OSError, subprocess.SubprocessError) as error:
                report["complete"] = False
                report["failures"].append({"scope": "final_fingerprint", "error": str(error)})
        write(output, report)
    print("MATERIAL_STAGING_COMPARISON", json.dumps({key: report[key] for key in ("complete", "failures", "source", "order", "performance_acceptance")}), flush=True)
    return 0 if report["complete"] else 1


def self_test():
    """Adversarial evidence gates; no Godot process or synthetic performance claim."""
    import copy
    import unittest

    def event(slot, rid, *, slots=2, capacity=16, initialization=False):
        updated = capacity // 4 + 1 if capacity else 0
        whole = capacity == 256
        runs = (1 if whole or updated == 1 else max(1, updated // 2)) if capacity else 0
        baseline = 1 if whole else updated
        pixels = (256 if whole else updated) * 128 ** 2
        return {"event": "texture_upload", "world_generation": 3, "completed_usec": 100,
                "material_publication": {"backend": "blit", "fallback_reason": "", "staging_slots": slots,
                    "staging_backend": "texture2d_array", "staging_layer": 0 if capacity else -1,
                    "staging_resource_layers": 1, "staging_slot": slot, "staging_resource_rid": rid,
                    "atlas_capacity": capacity, "submitted_bytes": capacity * 128 * 128 * 2,
                    "tile_side": 128, "tile_count": 256, "updated_tiles": updated,
                    "logical_source_format": "RG8", "allocated_gpu_bytes": 33554437 + 11173888 * slots,
                    "staging_upload_usec": 10, "initialization": initialization,
                    "copy_mode": "runs", "copy_destinations": 2 if initialization else 1,
                    "copy_run_count": runs, "whole_gpu_copy": whole, "gpu_blit_calls": runs,
                    "uncoalesced_gpu_blit_calls": baseline, "coalesced_gpu_blit_calls_saved": baseline - runs,
                    "blit_pixels": pixels, "uncoalesced_blit_pixels": pixels,
                    "estimated_target_write_bytes": 4 * pixels, "retirement_blit_calls": int(capacity > 0),
                    "estimated_retirement_write_bytes": 4 * int(capacity > 0)}}

    class EvidenceGuards(unittest.TestCase):
        def valid(self):
            return [event(0, 11), event(1, 12), event(0, 11), event(1, 12)]

        def test_independent_resource_reuse_and_capacity_interleaving(self):
            rows = self.valid()
            rows.insert(1, event(1, 21, capacity=4))
            rows.insert(3, event(0, 22, capacity=4))
            result = validate_publications(rows, "blit", 2)
            self.assertEqual(len(result["resource_ledger"]), 4)
            self.assertEqual(len({row["staging_resource_rid"] for row in result["resource_ledger"]}), 4)
            self.assertTrue(all(row["staging_layer"] == 0 for row in result["resource_ledger"]))

        def test_three_slots_all_recur_as_independent_one_layer_resources(self):
            result = validate_publications([event(i % 3, 11 + i % 3, slots=3) for i in range(6)], "blit", 3)
            self.assertEqual({row["staging_slot"] for row in result["resource_ledger"]}, {0, 1, 2})
            self.assertEqual(result["allocated_gpu_bytes"], [67076101])

        def test_one_slot_control_reuses_one_resource(self):
            result = validate_publications([event(0, 11, slots=1) for _ in range(4)], "blit", 1)
            self.assertEqual(len(result["resource_ledger"]), 1)

        def test_initialization_and_noop_do_not_imply_cursor_rotation_or_copy_gain(self):
            rows = self.valid()
            rows.insert(0, event(1, 99, initialization=True))
            rows.insert(2, event(-1, 0, capacity=0))
            result = validate_publications(rows, "blit", 2)
            self.assertEqual(len(result["initialization_events"]), 1)
            self.assertEqual(result["no_change_events"], 1)
            stats = copy_statistics(rows)
            self.assertEqual(stats["ordinary_sparse_coalesced_publications"], 4)
            self.assertEqual(stats["sparse_saved_calls"], 12)
            self.assertEqual(stats["sparse_copied_pixels"], stats["sparse_uncoalesced_pixels"])

        def test_dense_full_copy_is_never_counted_as_a_new_coalescing_gain(self):
            p = event(0, 11, capacity=256)["material_publication"]
            self.assertEqual(validate_copy_metrics(p), {"sparse": False, "coalesced": False})
            p["coalesced_gpu_blit_calls_saved"] = 255
            with self.assertRaises(RuntimeError):
                validate_copy_metrics(p)

        def test_exact_per_tile_control_can_be_checked_without_coalescing_credit(self):
            p = event(0, 11)["material_publication"]
            p.update(copy_mode="tiles", copy_run_count=5, gpu_blit_calls=5, coalesced_gpu_blit_calls_saved=0)
            self.assertEqual(validate_copy_metrics(p, "tiles"), {"sparse": True, "coalesced": False})

        def test_full_image_arm_has_no_staging_identity(self):
            result = validate_publications([{"event": "texture_upload", "world_generation": 3,
                "material_publication": {"backend": "full", "fallback_reason": ""}}], "full", None)
            self.assertEqual(result["resource_ledger"], [])

        def test_coalescing_must_be_exercised_repeatedly(self):
            rows = self.valid()
            rows[0]["material_publication"].update(copy_run_count=5, gpu_blit_calls=5, coalesced_gpu_blit_calls_saved=0)
            with self.assertRaisesRegex(RuntimeError, "Fewer than four"):
                validate_publications(rows, "blit", 2)

        def test_malformed_or_unexercised_treatments_are_refused(self):
            mutations = [
                ("fallback", lambda p: p.update(fallback_reason="driver")),
                ("wrong backend", lambda p: p.update(backend="full")),
                ("missing RID", lambda p: p.pop("staging_resource_rid")),
                ("missing layer", lambda p: p.pop("staging_layer")),
                ("wrong resource kind", lambda p: p.update(staging_backend="image_texture")),
                ("nonzero layer", lambda p: p.update(staging_layer=1)),
                ("multiple resource layers", lambda p: p.update(staging_resource_layers=2)),
                ("wrong slot count", lambda p: p.update(staging_slots=1)),
                ("boolean count", lambda p: p.update(staging_slots=True)),
                ("wrong allocation", lambda p: p.update(allocated_gpu_bytes=1)),
                ("wrong byte count", lambda p: p.update(submitted_bytes=8)),
                ("invalid noop", lambda p: p.update(submitted_bytes=0)),
                ("infinite timer", lambda p: p.update(staging_upload_usec=float("inf"))),
                ("wrong copy mode", lambda p: p.update(copy_mode="tiles")),
                ("missing copy count", lambda p: p.pop("gpu_blit_calls")),
                ("extra staging capacity", lambda p: p.update(atlas_capacity=64, submitted_bytes=64*128*128*2)),
                ("extra target pixels", lambda p: p.update(blit_pixels=p["blit_pixels"]+128*128)),
                ("false baseline pixels", lambda p: p.update(uncoalesced_blit_pixels=0)),
                ("extra history destination", lambda p: p.update(copy_destinations=2)),
                ("wrong saved calls", lambda p: p.update(coalesced_gpu_blit_calls_saved=99)),
                ("wrong RGBA bytes", lambda p: p.update(estimated_target_write_bytes=1)),
                ("retirement included in copies", lambda p: p.update(gpu_blit_calls=p["gpu_blit_calls"]+1)),
                ("missing retirement", lambda p: p.update(retirement_blit_calls=0)),
            ]
            for name, mutate in mutations:
                with self.subTest(name=name):
                    rows = copy.deepcopy(self.valid())
                    mutate(rows[0]["material_publication"])
                    with self.assertRaises(RuntimeError):
                        validate_publications(rows, "blit", 2)
            sequence_mutations = [
                ("shared RID across slots", lambda rows: rows[1]["material_publication"].update(staging_resource_rid=11)),
                ("replaced resource", lambda rows: rows[2]["material_publication"].update(staging_resource_rid=17)),
                ("alias across capacities", lambda rows: rows.append(event(0, 11, capacity=4))),
                ("no rotation", lambda rows: rows[1]["material_publication"].update(staging_slot=0, staging_resource_rid=11)),
                ("World replaced", lambda rows: rows[2].update(world_generation=4)),
            ]
            for name, mutate in sequence_mutations:
                with self.subTest(name=name):
                    rows = copy.deepcopy(self.valid())
                    mutate(rows)
                    with self.assertRaises(RuntimeError):
                        validate_publications(rows, "blit", 2)
            with self.assertRaises(RuntimeError):
                validate_publications(self.valid()[:1], "blit", 2)

    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(EvidenceGuards))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(self_test() if sys.argv[1:] == ["--self-test"] else main())
