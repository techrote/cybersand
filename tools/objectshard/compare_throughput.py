#!/usr/bin/env python3
"""Run one-at-a-time interleaved M4 comparisons with a common copied fixture.

This is a descriptive performance experiment, not a physical-display pass or a
source/publication qualification tool. Each fixture still requires its real
native, physical, ownership and requested-body-cohort checks to pass.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--baseline-native-source", required=True)
    parser.add_argument("--candidate-native-source", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--seconds", default=6, type=int)
    parser.add_argument("--replicates", default=2, type=int)
    parser.add_argument("--workloads", default="disabled,empty,tower,stress,sleeping")
    parser.add_argument("--recordings", default="off,on")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    projects = {"baseline": args.baseline.resolve(), "candidate": args.candidate.resolve()}
    fixture = "godot/tests/profile_object_shard_m4_throughput.gd"
    if sha(projects["baseline"] / fixture) != sha(projects["candidate"] / fixture):
        raise ValueError("Both projects must contain the exact same throughput fixture")
    identities = {}
    for label, root in projects.items():
        identities[label] = {
            "project": str(root),
            "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
            "tracked_changes": subprocess.check_output(["git", "diff", "--name-only"], cwd=root, text=True).splitlines(),
            "native_build_source": getattr(args, label + "_native_source"),
            "native_sha256": sha(root / "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
            "rapier_sha256": sha(root / "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"),
            "input_sha256": {name: sha(root / name) for name in [fixture,
                "godot/scripts/main.gd", "godot/scripts/simulation_worker.gd",
                "godot/scripts/object_shard_m4_runtime.gd", "godot/scripts/object_shard_physics_bridge.gd",
                "godot/scripts/object_shard_workbench_scenes.gd"]},
        }
    report = {
        "schema": "objectshard-m4-matched-throughput-v1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "godot_sha256": sha(args.godot), "identities": identities,
        "seconds_per_window": args.seconds, "replicates": args.replicates,
        "max_fps": 60, "display_driver": "headless", "runs": [], "comparisons": [],
        "scope": "Interleaved same-host actual native/Rapier workloads. Headless timing is not physical display FPS or owner hardware acceptance. Historical and candidate native identities/toolchains are reported explicitly.",
    }
    save(args.output / "summary.json", report)
    for recording in args.recordings.split(","):
        for workload in args.workloads.split(","):
            pair = {"baseline": [], "candidate": []}
            for replicate in range(args.replicates):
                order = ["baseline", "candidate"] if replicate % 2 == 0 else ["candidate", "baseline"]
                for label in order:
                    name = f"{workload}-{recording}-{replicate+1}-{label}"
                    result_path = args.output / (name + ".json")
                    command = [str(args.godot.resolve()), "--headless", "--max-fps", "60", "--path", "godot",
                               "--script", "res://tests/profile_object_shard_m4_throughput.gd", "--"]
                    if workload != "disabled": command.append("--objectshard-m4-workbench")
                    command += ["--workload=" + workload, "--seconds=" + str(args.seconds),
                                "--recording=" + recording, "--output=" + str(result_path.resolve())]
                    env = dict(os.environ, CYBERSAND_SOURCE_REVISION=identities[label]["head"])
                    with (args.output / (name + ".log")).open("w") as log:
                        completed = subprocess.run(command, cwd=projects[label], env=env, stdout=log,
                                                   stderr=subprocess.STDOUT, timeout=180)
                    value = json.loads(result_path.read_text()) if result_path.exists() else {}
                    passed = completed.returncode == 0 and value.get("schema") == "objectshard-m4-throughput-v1" \
                        and value.get("failures") == [] and value.get("checks", 0) > 0
                    row = {"name": name, "label": label, "workload": workload, "recording": recording,
                           "replicate": replicate + 1, "returncode": completed.returncode, "passed": passed,
                           "failures": value.get("failures"), "checks": value.get("checks"),
                           "semantic_ticks_per_second": value.get("semantic_ticks_per_second"),
                           "semantic_ticks": value.get("semantic_ticks"), "cohorts": value.get("cohorts"),
                           "worker_counter_deltas": value.get("worker_counter_deltas"),
                           "runtime_counter_deltas": value.get("runtime_counter_deltas"),
                           "control_timing_deltas": value.get("control_timing_deltas"),
                           "result_sha256": sha(result_path) if result_path.exists() else ""}
                    report["runs"].append(row)
                    save(args.output / "summary.json", report)
                    print(json.dumps({key: row[key] for key in ["name", "passed", "checks", "semantic_ticks_per_second", "failures"]}), flush=True)
                    if not passed:
                        return 1
                    pair[label].append(value["semantic_ticks_per_second"])
            baseline = statistics.median(pair["baseline"])
            candidate = statistics.median(pair["candidate"])
            report["comparisons"].append({"workload": workload, "recording": recording,
                "baseline_rates": pair["baseline"], "candidate_rates": pair["candidate"],
                "baseline_median": baseline, "candidate_median": candidate,
                "candidate_over_baseline": candidate / baseline})
            save(args.output / "summary.json", report)
    report["finished_utc"] = datetime.now(timezone.utc).isoformat()
    save(args.output / "summary.json", report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
