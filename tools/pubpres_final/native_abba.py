#!/usr/bin/env python3
"""Validate and reduce retained native-only PUBPRES ABBA receipts.

The input preserves every byte of each benchmark stdout/stderr alongside its
execution manifest. This reducer does not pool per-run percentiles and does not
claim a Rapier, displayed-frame, or interactive-playability result.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


COHORTS = (
    ("current512-one", 512, 1, 0),
    ("current1024-one", 1024, 1, 0),
    ("current2048-one", 2048, 1, 0),
    ("historical512-one", 512, 1, 1),
    ("current2048-zero", 2048, 0, 0),
    ("current2048-eight", 2048, 8, 0),
)
ORDER = ("A", "B", "B", "A")
METRICS = (
    "tick_mean_ms", "tick_p50_ms", "tick_p95_ms", "tick_p99_ms",
    "tick_max_ms", "column_mean_ms", "flux_mean_ms", "apply_mean_ms",
    "prepare_mean_ms", "wave_storage_bytes",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def reduce_receipts(receipts: dict) -> dict:
    require(receipts["schema"] == "pubpres-native-abba-receipts-v1", "receipt schema")
    manifest = receipts["manifest"]
    require(manifest["schema"] == "pubpres-native-quiet-abba-v1", "manifest schema")
    require(manifest["order"] == list(ORDER), "registered ABBA order")
    require(manifest["ticks"] == 72 and manifest["workers"] == 4, "registered execution")
    require(len(manifest["runs"]) == len(COHORTS) * len(ORDER), "complete experiment")
    raw_runs = receipts["raw_runs"]
    require(len(raw_runs) == len(manifest["runs"]), "raw run cardinality")
    cohorts = []
    for cohort_index, (label, size, bodies, profile) in enumerate(COHORTS):
        rows = []
        for index, arm in enumerate(ORDER, 1):
            name = f"{label}-{index}-{arm}"
            execution = manifest["runs"][cohort_index * 4 + index - 1]
            require(execution["name"] == name and execution["arm"] == arm, name + ": execution order")
            require(execution["exit_code"] == 0, name + ": unsuccessful native process")
            require(execution["argv"][1:] == [str(size), str(bodies), "4", "72", str(profile)],
                    name + ": execution arguments")
            raw = raw_runs[name]
            require(hashlib.sha256(raw["stdout"].encode()).hexdigest() == raw["stdout_sha256"],
                    name + ": stdout digest")
            require(hashlib.sha256(raw["stderr"].encode()).hexdigest() == raw["stderr_sha256"],
                    name + ": stderr digest")
            require(raw["stderr"] == "", name + ": unexpected stderr")
            data = json.loads(raw["stdout"])
            require(data["schema"] == "pubpres-mask-bounds-native-v1" and data["scope"] == "native-only",
                    name + ": native scope")
            for key, expected in (("size", size), ("bodies", bodies), ("profile", profile),
                                  ("ticks", 72), ("workers", 4), ("workers_observed", 4)):
                require(data[key] == expected, name + ": " + key)
            for key in METRICS:
                require(isinstance(data[key], (int, float)) and math.isfinite(data[key]) and data[key] >= 0,
                        name + ": invalid " + key)
            require(0 < data["tick_p50_ms"] <= data["tick_p95_ms"] <= data["tick_p99_ms"] <= data["tick_max_ms"],
                    name + ": percentile order")
            require(len(data["checkpoints"]) == 6 * (3 + 3 * bodies), name + ": checkpoint cardinality")
            require(all(isinstance(value, int) and 0 <= value < 2 ** 64 for value in data["checkpoints"]),
                    name + ": invalid checkpoint")
            require(data["tick_mean_ms"] == execution["tick_mean_ms"], name + ": manifest mean")
            rows.append(data)
        for row in rows[1:]:
            for key in ("water_units", "launched_parcels", "checkpoints"):
                require(row[key] == rows[0][key], label + ": unequal " + key)
        arms = {arm: {key: [rows[i][key] for i in range(4) if ORDER[i] == arm]
                      for key in METRICS} for arm in ("A", "B")}
        a = arms["A"]["tick_mean_ms"]
        b = arms["B"]["tick_mean_ms"]
        cohorts.append({
            "cohort": label,
            "complete_checkpoint_parity": True,
            "water_units": rows[0]["water_units"],
            "launched_parcels": rows[0]["launched_parcels"],
            "metrics_in_run_order": arms,
            "candidate_mean_percent_change": 100 * (sum(b) / sum(a) - 1),
            "both_candidate_means_below_both_controls": max(b) < min(a),
            "both_candidate_means_above_both_controls": min(b) > max(a),
        })
    return {
        "schema": "pubpres-native-abba-reduction-v1",
        "scope": "native-only; no Rapier, presentation, or input-latency witness",
        "source_identities": {key: manifest[key] for key in ("predecessor_source", "candidate_source", "candidate_tree")},
        "percentile_policy": "Each percentile is a per-process value; no pooled percentile is recoverable from these aggregates.",
        "sampling_limit": "72 ticks per process, two processes per source per cohort; tail behavior is not a sustained gameplay qualification.",
        "cohorts": cohorts,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipts", type=Path)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    result = json.dumps(reduce_receipts(json.loads(arguments.receipts.read_text())), indent=2) + "\n"
    if arguments.output:
        arguments.output.write_text(result)
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
