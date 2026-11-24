#!/usr/bin/env python3
"""Reduce the separately registered native mask-applicability screen.

This never substitutes for the rejected original 24-process screen. All native
tick/phase clocks retain its exact benchmark and quantile definition. Added CPU
usage is kernel child accounting across the entire benchmark process, including
setup and semantic checks, and is not joined to the in-tick timing window.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from native_abba import require
from native_empty_derived import FIELDS, reconstruct

ORDER = ("A", "B", "C", "C", "B", "A")
COHORTS = (("current512-one", 512, 1, 0),
           ("current2048-zero", 2048, 0, 0),
           ("current2048-one", 2048, 1, 0))
CPU_KEYS = ("user_seconds", "system_seconds")
CPU_SCOPE = "whole-child-process-including-setup-and-semantic-checks"
BENCHMARK_SHA256 = "0ee16b0592fd2be58543020c258dab23801e4b89318469bf0e94b1b393a6a2f8"
BENCHMARK_PATH = "native/bench/pubpres_empty_derived.cpp"


def sha256(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def finite_nonnegative(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def cpu_observation(run: dict, elapsed_ticks_ns: int) -> dict:
    before, after = run["children_cpu_before"], run["children_cpu_after"]
    wall = run["whole_process_wall_nanoseconds"]
    require(run.get("cpu_scope") == CPU_SCOPE and type(run.get("pid")) is int and run["pid"] > 0,
            "Missing actual process identity or changed whole-child CPU scope")
    require(set(before) == set(after) == set(CPU_KEYS)
            and all(finite_nonnegative(before[key]) and finite_nonnegative(after[key])
                    and after[key] >= before[key] for key in CPU_KEYS),
            "Invalid, reversed or nonnumeric kernel child CPU readings")
    require(type(wall) is int and wall >= elapsed_ticks_ns > 0,
            "Whole-process wall duration excludes contained native ticks")
    user, system = (after[key] - before[key] for key in CPU_KEYS)
    total = user + system
    require(total > 0, "Successful native process has no accounted child CPU")
    return {"whole_child_user_seconds": user, "whole_child_system_seconds": system,
            "whole_child_cpu_seconds": total, "whole_process_wall_seconds": wall / 1e9,
            "whole_child_average_cpu_cores": total / (wall / 1e9)}


def reduce_receipts(receipts: dict) -> dict:
    require(receipts.get("schema") == "pubpres-native-mask-applicability-receipts-v1",
            "Unknown native applicability receipt schema")
    require(receipts.get("failures") == [], "Retained native process failures forbid qualification")
    manifest = receipts["manifest"]
    require(manifest.get("schema") == "pubpres-native-mask-applicability-screen-v1"
            and manifest["order"] == list(ORDER) and manifest["cohorts"] == [list(row) for row in COHORTS]
            and type(manifest["ticks"]) is int and manifest["ticks"] == 72
            and type(manifest["workers"]) is int and manifest["workers"] == 4,
            "Native applicability registration changed")
    require(len(manifest["runs"]) == len(receipts["raw_runs"]) == 18,
            "All original three-cohort A/B/C/C/B/A processes are required")
    require(sha256(receipts["runner_source"]) == manifest["runner_source_sha256"],
            "Measured runner source custody differs")
    builds = manifest["builds"]
    require(set(builds) == {"A", "B", "C"}, "All independently built source arms are required")
    for arm, build in builds.items():
        require(type(build["exit_code"]) is int and build["exit_code"] == 0 and len(build["binary_sha256"]) == 64
                and len(build["source_commit"]) == 40 and len(build["source_tree"]) == 40
                and build["source_inputs_sha256"], "Unsuccessful or unidentified native build: " + arm)
        require(all(build[key] == builds["A"][key] for key in ("compiler", "flags", "benchmark_sha256")),
                "Native arms changed compiler, flags or benchmark")
        require(build["benchmark_sha256"] == BENCHMARK_SHA256
                and build["source_inputs_sha256"].get(BENCHMARK_PATH) == BENCHMARK_SHA256,
                "Original benchmark source is absent or changed in the build closure")
    require(builds["A"]["source_commit"] == "27a08efb4a78186c0e2b19176576752e2503b998"
            and builds["B"]["source_commit"] == "fa34fc2129125d77a5255c95bfa82af91eff05a5",
            "Original occupied-bounds or unconditional-cache source was replaced")
    require(len({build["source_commit"] for build in builds.values()}) == 3,
            "Applicability candidate must retain a distinct source identity")
    cohorts = []
    previous_cpu = None
    for cohort_index, (label, size, bodies, profile) in enumerate(COHORTS):
        data_rows, measurements = [], []
        for index, arm in enumerate(ORDER, 1):
            name = f"{label}-{index}-{arm}"
            run = manifest["runs"][cohort_index * 6 + index - 1]
            require(run["name"] == name and run["arm"] == arm
                    and type(run["exit_code"]) is int and run["exit_code"] == 0
                    and run["argv"][0] == builds[arm]["binary_path"]
                    and run["argv"][1:] == [str(size), str(bodies), "4", "72", str(profile)]
                    and run["binary_sha256"] == builds[arm]["binary_sha256"],
                    "Unsuccessful, reordered or changed native process: " + name)
            raw = receipts["raw_runs"][name]
            require(raw["stderr"] == "" and all(sha256(raw[key]) == raw[key + "_sha256"]
                                                  for key in ("stdout", "stderr")),
                    "Original native output custody differs: " + name)
            data = json.loads(raw["stdout"])
            for key, expected in (("size", size), ("bodies", bodies), ("profile", profile),
                                  ("workers", 4), ("workers_observed", 4), ("ticks", 72)):
                require(type(data[key]) is int and data[key] == expected,
                        "Native case or registered worker participation differs: " + name)
            timing = reconstruct(data)
            cpu = cpu_observation(run, sum(data["tick_nanoseconds"]))
            require(previous_cpu is None or previous_cpu == run["children_cpu_before"],
                    "Another child process entered the serial CPU measurement chain")
            previous_cpu = run["children_cpu_after"]
            measurements.append({"name": name, "arm": arm, **timing, **cpu})
            data_rows.append(data)
        require(all(all(row[key] == data_rows[0][key]
                        for key in ("water_units", "launched_parcels", "checkpoints"))
                    for row in data_rows[1:]), "Native semantic/conservation sequence changed: " + label)
        comparisons = []
        for control_arm, candidate_arm in (("A", "B"), ("A", "C"), ("B", "C")):
            control = [row for row in measurements if row["arm"] == control_arm]
            candidate = [row for row in measurements if row["arm"] == candidate_arm]
            strict = {field: max(row[field] for row in candidate) < min(row[field] for row in control)
                      for field in (*FIELDS, "whole_child_cpu_seconds")}
            changes = {field: 100 * (sum(row[field] for row in candidate) /
                                     sum(row[field] for row in control) - 1)
                       for field in ("tick_mean_ms", "whole_child_cpu_seconds")}
            comparisons.append({"control": control_arm, "candidate": candidate_arm,
                                "percent_change": changes, "both_candidates_below_both_controls": strict,
                                "all_native_timing_directions_repeat": all(strict[field] for field in FIELDS)})
        cohorts.append({"cohort": label, "complete_semantic_checkpoint_parity": True,
                        "measurements_in_order": measurements, "comparisons": comparisons})
    return {"schema": "pubpres-native-mask-applicability-reduction-v1", "cohorts": cohorts,
            "source_identities": {arm: {key: builds[arm][key] for key in
                                  ("source_commit", "source_tree", "binary_sha256", "benchmark_sha256")}
                                  for arm in ("A", "B", "C")},
            "percentile_policy": "Recomputed nearest-rank within each 72-tick process; p99 equals max. No averaged percentile estimates.",
            "cpu_scope": CPU_SCOPE,
            "limits": "Two processes per arm/cohort are a development screen. Host stationarity is unproven. Kernel CPU includes setup and semantic checks outside the native tick window. No Rapier, presented-frame or input responsiveness witness. The previous 24-run refusal and adverse results remain unchanged.",
            "physical_acceptance": "HOLD"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipts", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = json.dumps(reduce_receipts(json.loads(args.receipts.read_bytes())), indent=2) + "\n"
    if args.output:
        args.output.write_text(result)
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
