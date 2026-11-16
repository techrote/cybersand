#!/usr/bin/env python3
"""Same-source, six-arm Windows material staging reuse probe.

Full, one-slot blit and two-slot blit run in forward/reverse order on one host.
The primary comparison is exactly completed physical steps 1..144; every raw
completion and whole-capture tail is retained. Functional completion is not a
performance pass or physical Windows 11/NVIDIA acceptance.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from contextlib import contextmanager
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
    "tools/ci/package_engine_lab_windows.py", ".github/workflows/material-staging-probe.yml",
)
ORDER = ("full", "blit1", "blit2", "blit2", "blit1", "full")
REQUIRED_STEPS = 144
ENVIRONMENT = {
    # All arms use this same source, so retain actual Main callback events.
    "CYBERSAND_DIAG_COMMON_OBSERVER": "0",
    "CYBERSAND_DIAG_PHYSICS_PUBLICATION": "early",
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


def validate_publications(events, backend, slots):
    uploads = [e for e in events if e.get("event") == "texture_upload"]
    need(bool(uploads), "No material publications were observed")
    generations = {e.get("world_generation") for e in uploads}
    need(len(generations) == 1 and all(integer(g) and g >= 0 for g in generations),
         "Unexpected World retirement/reset in the fixed staging workload")
    resources, reverse, previous, counts = {}, {}, {}, Counter()
    initializations, noops, records = [], 0, []
    allocation = set()
    for event in uploads:
        p = event.get("material_publication")
        need(isinstance(p, dict), "Missing material publication readback")
        need(p.get("backend") == backend and not p.get("fallback_reason"),
             "Wrong material backend or automatic fallback during probe")
        if backend == "full":
            continue
        need(integer(p.get("staging_slots")) and p["staging_slots"] == slots, "Wrong staging slot count")
        need(all(key in p for key in ("staging_slot", "staging_resource_rid", "atlas_capacity", "submitted_bytes")),
             "Missing actual staging resource identity")
        slot, rid, capacity, submitted = (p[k] for k in ("staging_slot", "staging_resource_rid", "atlas_capacity", "submitted_bytes"))
        need(all(integer(v) for v in (slot, rid, capacity, submitted)) and submitted >= 0,
             "Invalid staging resource or byte counters")
        need(integer(p.get("allocated_gpu_bytes")) and p["allocated_gpu_bytes"] > 0,
             "Missing bounded GPU allocation estimate")
        allocation.add(p["allocated_gpu_bytes"])
        if submitted == 0:
            need((slot, rid, capacity) == (-1, 0, 0), "No-op publication claimed a staging resource")
            noops += 1
            continue
        need(0 <= slot < slots and rid > 0 and capacity > 0, "Invalid nonempty staging selection")
        need(integer(p.get("tile_count")) and capacity <= p["tile_count"], "Staging capacity exceeds fixed World tiles")
        if p.get("initialization", False):
            # Setup aggregates allocations/priming and resets the pool cursor.
            # Preserve it, but do not infer ordinary rotation from its last RID.
            initializations.append(event)
            continue
        need(integer(p.get("tile_side")) and p["tile_side"] > 0 and p.get("logical_source_format") == "RG8",
             "Probe no longer uses exact RG8 material tiles")
        need(submitted == capacity * p["tile_side"] ** 2 * 2, "Staging bytes do not match reported RG8 capacity")
        key = (int(capacity), int(slot))
        need(key not in resources or resources[key] == rid, "Staging resource replaced within a fixed capacity/slot")
        need(rid not in reverse or reverse[rid] == key, "One RID aliases different staging capacity/slots")
        if capacity in previous:
            need(slot == (previous[capacity] + 1) % slots, "Staging slots do not rotate per nonempty capacity upload")
        resources[key], reverse[rid], previous[capacity] = int(rid), key, int(slot)
        counts[int(capacity)] += 1
        need(integer(p.get("staging_upload_usec")) and p["staging_upload_usec"] >= 0,
             "Missing staging call timing")
        records.append({"render_serial": event.get("render_serial"), "native_tick": event.get("native_tick"),
                        "completed_usec": event_time(event), "atlas_capacity": int(capacity),
                        "staging_slot": int(slot), "staging_resource_rid": int(rid), "submitted_bytes": int(submitted),
                        "staging_upload_ms": p["staging_upload_usec"] / 1000,
                        "full_refresh": event.get("full_refresh", False)})
    if backend == "blit":
        need(bool(records), "No noninitialization staging uploads were observed")
        need(len(allocation) == 1, "GPU allocation estimate changes within fixed staging workload")
        need(any(count >= max(4, slots * 2) for count in counts.values()), "Insufficient repeated staging reuse")
    return {"backend": backend, "staging_slots": slots, "upload_events": len(uploads), "world_generation": next(iter(generations)),
            "initialization_events": initializations, "no_change_events": noops,
            "allocated_gpu_bytes": sorted(allocation),
            "resource_ledger": [{"atlas_capacity": key[0], "staging_slot": key[1], "staging_resource_rid": value}
                                for key, value in sorted(resources.items())],
            "ordinary_upload_records": records}


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
                {"atlas_capacity": key[0], "staging_slot": key[1], "elapsed_ms": distribution(values),
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
    report = {"schema": "material-staging-reuse-comparison-v1", "source": args.source_sha,
              "order": list(ORDER), "required_physical_prefix": [1, REQUIRED_STEPS],
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
        need(imported.returncode == 0 and "SCRIPT ERROR:" not in (args.evidence / "import.log").read_text(errors="replace"), "Probe import failed")
        conditions_path = args.project / "tests/fixtures/engine_lab/coherence-conditions.json"
        condition = next(c for c in json.loads(conditions_path.read_text())["conditions"] if c["name"] == "interactive-follow")
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
                    receipt = json.loads(receipt_path.read_text())
                    need(receipt["physics_publication"] == "early", "Arm did not use actual early physical publication")
                    final = receipt["material_publication"]
                    need(final.get("backend") == backend and not final.get("fallback_reason"), "Final material mode readback differs")
                    if slots is not None:
                        need(final.get("staging_slots") == slots, "Final staging slot readback differs")
                    row["whole_capture"], _, header, events = timed_reduction(trace)
                    need(header.get("settings", {}).get("source_commit") == args.source_sha, "Trace source identity differs")
                    row["publication_validation"] = validate_publications(events, backend, slots)
                    row["matched_144"], states, _, _ = timed_reduction(trace, REQUIRED_STEPS)
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
        for indices in ((0, 1, 2), (5, 4, 3)):
            for left, right in ((indices[0], indices[1]), (indices[0], indices[2]), (indices[1], indices[2])):
                if all(report["cases"][i]["status"] == "passed" for i in (left, right)):
                    report["contrasts"].append(contrast(report["cases"][left], report["cases"][right]))
        report["complete"] = len(report["cases"]) == 6 and all(row["status"] == "passed" for row in report["cases"]) and not report["failures"]
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
        return {"event": "texture_upload", "world_generation": 3, "completed_usec": 100,
                "material_publication": {"backend": "blit", "fallback_reason": "", "staging_slots": slots,
                    "staging_slot": slot, "staging_resource_rid": rid, "atlas_capacity": capacity,
                    "submitted_bytes": capacity * 128 * 128 * 2, "tile_side": 128, "tile_count": 256,
                    "logical_source_format": "RG8", "allocated_gpu_bytes": 55902212,
                    "staging_upload_usec": 10, "initialization": initialization}}

    class EvidenceGuards(unittest.TestCase):
        def valid(self):
            return [event(0, 11), event(1, 12), event(0, 11), event(1, 12)]

        def test_distinct_resource_reuse_and_capacity_interleaving(self):
            rows = self.valid()
            rows.insert(1, event(1, 21, capacity=4))
            rows.insert(3, event(0, 22, capacity=4))
            result = validate_publications(rows, "blit", 2)
            self.assertEqual(len(result["resource_ledger"]), 4)

        def test_one_slot_control_reuses_one_resource(self):
            result = validate_publications([event(0, 11, slots=1) for _ in range(4)], "blit", 1)
            self.assertEqual(len(result["resource_ledger"]), 1)

        def test_initialization_and_noop_do_not_imply_cursor_rotation(self):
            rows = self.valid()
            rows.insert(0, event(1, 99, initialization=True))
            rows.insert(2, event(-1, 0, capacity=0))
            result = validate_publications(rows, "blit", 2)
            self.assertEqual(len(result["initialization_events"]), 1)
            self.assertEqual(result["no_change_events"], 1)

        def test_full_image_arm_has_no_staging_identity(self):
            result = validate_publications([{"event": "texture_upload", "world_generation": 3,
                "material_publication": {"backend": "full", "fallback_reason": ""}}], "full", None)
            self.assertEqual(result["resource_ledger"], [])

        def test_malformed_or_unexercised_treatments_are_refused(self):
            mutations = [
                ("fallback", lambda rows: rows[0]["material_publication"].update(fallback_reason="driver")),
                ("wrong backend", lambda rows: rows[0]["material_publication"].update(backend="full")),
                ("missing RID", lambda rows: rows[0]["material_publication"].pop("staging_resource_rid")),
                ("wrong count", lambda rows: rows[0]["material_publication"].update(staging_slots=1)),
                ("boolean count", lambda rows: rows[0]["material_publication"].update(staging_slots=True)),
                ("replaced resource", lambda rows: rows[2]["material_publication"].update(staging_resource_rid=17)),
                ("aliased resource", lambda rows: rows[1]["material_publication"].update(staging_resource_rid=11)),
                ("no rotation", lambda rows: rows[1]["material_publication"].update(staging_slot=0, staging_resource_rid=11)),
                ("World replaced", lambda rows: rows[2].update(world_generation=4)),
                ("allocation growth", lambda rows: rows[2]["material_publication"].update(allocated_gpu_bytes=55902216)),
                ("wrong byte count", lambda rows: rows[0]["material_publication"].update(submitted_bytes=8)),
                ("invalid noop", lambda rows: rows[0]["material_publication"].update(submitted_bytes=0)),
                ("infinite timer", lambda rows: rows[0]["material_publication"].update(staging_upload_usec=float("inf"))),
            ]
            for name, mutate in mutations:
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
