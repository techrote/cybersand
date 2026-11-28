#!/usr/bin/env python3
"""Independently validate and condense a completed matched throughput experiment."""
import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import statistics


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--custody", required=True, type=Path)
    parser.add_argument("--expected-recordings", default="off,on")
    args = parser.parse_args()
    summary_path = args.directory / "summary.json"
    summary = json.loads(summary_path.read_text())
    assert summary.get("finished_utc"), "Experiment did not finish"
    assert summary["display_driver"] == "headless"
    assert summary["replicates"] == 2 and summary["seconds_per_window"] == 6
    identities = summary["identities"]
    assert set(identities) == {"baseline", "candidate"}
    custody = json.loads(args.custody.read_text())
    assert custody["before"] == custody["after"], "Runtime, source or observer input changed during the experiment"
    assert custody["before"]["godot_sha256"] == summary["godot_sha256"]
    common_fixture = "godot/tests/profile_object_shard_m4_throughput.gd"
    assert identities["baseline"]["input_sha256"][common_fixture] == identities["candidate"]["input_sha256"][common_fixture]
    assert identities["baseline"]["rapier_sha256"] == identities["candidate"]["rapier_sha256"]
    common_paths = [common_fixture, "godot/tests/support/object_shard_m4_workbench_fixture.gd", "godot/scripts/workbench_setup.gd"]
    for path in common_paths:
        assert custody["before"]["projects"]["baseline"]["files"][path] == custody["before"]["projects"]["candidate"]["files"][path]
    native_path = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
    rapier_path = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
    for label, identity in identities.items():
        project = custody["before"]["projects"][label]
        provenance = custody["verified_runtime_provenance"][label]
        assert project["head"] == identity["head"] == identity["native_build_source"] == provenance["source_commit"]
        assert project["files"][native_path] == identity["native_sha256"] == provenance["sha256"]
        assert project["native_bytes"] == provenance["size"]
        assert project["files"][rapier_path] == identity["rapier_sha256"]
        for path, expected_hash in identity["input_sha256"].items():
            assert project["files"][path] == expected_hash
    recordings = args.expected_recordings.split(",")
    assert len(set(recordings)) == len(recordings) and set(recordings) <= {"off", "on"}
    workloads = ["disabled", "empty", "tower", "stress", "sleeping"]
    expected_matrix = {(workload, recording, replicate, label)
        for workload in workloads for recording in recordings
        for replicate in range(1, summary["replicates"] + 1)
        for label in ("baseline", "candidate")}
    observed_matrix = set()
    observed_names = set()
    control_fields = set()
    recipes = defaultdict(set)
    pairs = defaultdict(lambda: defaultdict(list))
    cohorts = defaultdict(lambda: {"wall_usec": 0, "semantic_ticks": 0, "callbacks": 0, "samples": 0})
    runs = []
    for row in summary["runs"]:
        key = (row["workload"], row["recording"], row["replicate"], row["label"])
        assert key in expected_matrix and key not in observed_matrix
        observed_matrix.add(key)
        assert row["name"] == f'{row["workload"]}-{row["recording"]}-{row["replicate"]}-{row["label"]}'
        assert row["name"] not in observed_names
        observed_names.add(row["name"])
        path = args.directory / (row["name"] + ".json")
        assert digest(path) == row["result_sha256"], row["name"]
        raw = json.loads(path.read_text())
        assert raw["schema"] == "objectshard-m4-throughput-v1"
        assert row["passed"] and row["returncode"] == 0
        assert raw["checks"] > 0 and raw["failures"] == []
        assert raw["source_commit"] == identities[row["label"]]["head"]
        assert raw["display_driver"] == "headless"
        assert raw["recording_enabled"] == (row["recording"] == "on")
        assert raw["workload"] == row["workload"]
        assert raw["requested_seconds"] == summary["seconds_per_window"]
        assert raw["process_fps_cap"] == summary["max_fps"] == 60
        assert raw["elapsed_usec"] >= summary["seconds_per_window"] * 1_000_000
        assert raw["renderer_callbacks"] == 0
        for field in ("semantic_ticks", "process_callbacks", "elapsed_usec", "rapier_segments"):
            assert type(raw[field]) is int and raw[field] >= 0
        for field, count in (("semantic_ticks_per_second", "semantic_ticks"), ("process_callbacks_per_second", "process_callbacks")):
            assert math.isfinite(raw[field])
            assert math.isclose(raw[field], raw[count] * 1e6 / raw["elapsed_usec"], rel_tol=1e-9, abs_tol=1e-8)
        assert raw["semantic_ticks_per_second"] == row["semantic_ticks_per_second"]
        control_fields.add(json.dumps({field: raw[field] for field in ["engine_version", "canvas_extent", "camera_origin", "view_size"]}, sort_keys=True))
        recipes[row["workload"]].add(raw["authored_rectangles_sha256"])
        pairs[(row["workload"], row["recording"])][row["label"]].append(raw["semantic_ticks_per_second"])
        cohort_records = []
        for key, cohort in raw["cohorts"].items():
            assert key == f'{cohort["owned"]}/{cohort["awake"]}'
            assert 0 <= cohort["awake"] <= cohort["owned"]
            for field in ("wall_usec", "semantic_ticks", "callbacks"):
                assert type(cohort[field]) is int and cohort[field] >= 0
            assert cohort["wall_usec"] > 0
            combined = cohorts[(row["workload"], row["recording"], row["label"], key)]
            for field in ("wall_usec", "semantic_ticks", "callbacks"):
                combined[field] += cohort[field]
            combined["samples"] += 1
            cohort_records.append(dict(cohort, semantic_ticks_per_second=cohort["semantic_ticks"] * 1e6 / cohort["wall_usec"]))
        assert sum(value["semantic_ticks"] for value in raw["cohorts"].values()) == raw["semantic_ticks"]
        assert sum(value["callbacks"] for value in raw["cohorts"].values()) == raw["process_callbacks"]
        assert sum(value["wall_usec"] for value in raw["cohorts"].values()) <= raw["elapsed_usec"]
        runs.append({
            "name": row["name"], "label": row["label"], "workload": row["workload"],
            "recording": row["recording"], "replicate": row["replicate"],
            "result_sha256": row["result_sha256"], "checks": raw["checks"], "failures": [],
            "elapsed_usec": raw["elapsed_usec"], "semantic_ticks": raw["semantic_ticks"],
            "semantic_ticks_per_second": raw["semantic_ticks_per_second"],
            "process_callbacks_per_second": raw["process_callbacks_per_second"],
            "renderer_callbacks": raw["renderer_callbacks"], "rapier_segments": raw["rapier_segments"],
            "authored_rectangles_sha256": raw["authored_rectangles_sha256"],
            "cohorts": cohort_records,
            "native_pose_acknowledgements_delta": raw["runtime_counter_deltas"].get("native_pose_acknowledgements"),
            "native_pose_echo_checks_delta": raw["runtime_counter_deltas"].get("native_pose_echo_checks"),
        })
    assert all(len(values) == 1 for values in recipes.values()), "Authored material differs between paired workloads"
    assert observed_matrix == expected_matrix, "Missing workload/recording/replicate/label combination"
    assert len(control_fields) == 1, "Engine, canvas or camera controls differ across measured windows"
    assert len(runs) == len(pairs) * 2 * summary["replicates"]
    comparisons = []
    for (workload, recording), arms in pairs.items():
        assert set(arms) == {"baseline", "candidate"}
        assert all(len(values) == summary["replicates"] for values in arms.values())
        baseline = statistics.median(arms["baseline"])
        candidate = statistics.median(arms["candidate"])
        comparisons.append({"workload": workload, "recording": recording,
            "baseline_rates": arms["baseline"], "candidate_rates": arms["candidate"],
            "baseline_median": baseline, "candidate_median": candidate,
            "candidate_change_percent": (candidate / baseline - 1) * 100})
    pooled = []
    for (workload, recording, label, key), value in sorted(cohorts.items()):
        owned, awake = map(int, key.split("/"))
        pooled.append(dict(value, workload=workload, recording=recording, label=label,
                          owned=owned, awake=awake,
                          semantic_ticks_per_second=value["semantic_ticks"] * 1e6 / value["wall_usec"]))
    report = {
        "schema": "objectshard-m4-independent-matched-throughput-v1",
        "status": "passed_all_workload_invariants",
        "measured_source": identities["candidate"]["native_build_source"],
        "baseline_source": identities["baseline"]["native_build_source"],
        "experiment_started_utc": summary["started_utc"],
        "experiment_finished_utc": summary["finished_utc"],
        "reviewed_utc": datetime.now(timezone.utc).isoformat(),
        "summary_sha256": digest(summary_path),
        "reviewer_script_sha256": digest(Path(__file__)),
        "godot_sha256": summary["godot_sha256"], "identities": identities,
        "runtime_and_source_custody": custody,
        "custody_sha256": digest(args.custody),
        "expected_unique_windows": len(expected_matrix),
        "common_observer_inputs": {path: custody["before"]["projects"]["baseline"]["files"][path] for path in common_paths},
        "common_control_fields": json.loads(next(iter(control_fields))),
        "seconds_per_window": summary["seconds_per_window"], "replicates": summary["replicates"],
        "display_driver": "headless", "max_fps": summary["max_fps"],
        "design": "One process at a time; baseline/candidate order alternates by replicate; exact common observer, engine, Rapier and authored rectangles; explicit recording off/on arms.",
        "limitations": [
            "Short descriptive same-host windows are not statistical equivalence or a hardware performance guarantee.",
            "Native semantic ticks are distinct from process callbacks and physical display frames; the headless renderer has no display FPS measurement.",
            "Owned and awake bodies are reported separately. Full-window rates can include multiple awake cohorts as bodies settle.",
            "Cohorts use callback-end observed state; a transition interval can include its preceding state.",
            "The active-window workloads contain no edit gesture. Editing latency and native batch cost are separate experiments.",
        ],
        "authored_material_equal_across_all_arms": True,
        "authored_rectangles_by_workload": {key: next(iter(values)) for key, values in recipes.items()},
        "comparisons": comparisons, "pooled_cohorts": pooled, "runs": runs,
    }
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"output": str(args.output), "status": report["status"], "runs": len(runs), "comparisons": comparisons}, indent=2))


if __name__ == "__main__":
    main()
