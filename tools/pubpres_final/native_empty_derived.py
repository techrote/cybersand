#!/usr/bin/env python3
"""Independently reconstruct native Empty-cache timing from original tick clocks.

Every aggregate is rederived per process; no native clock/counter is a Rapier or
display witness. Preserve all six cohorts and A/B/B/A processes, including
adverse tails, and require exact complete semantic checkpoints throughout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from native_abba import COHORTS, ORDER, require

FIELDS = ("tick_mean_ms", "tick_p50_ms", "tick_p95_ms", "tick_p99_ms", "tick_max_ms")
PHASES = ("prepare", "column", "flux", "apply")


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def nearest(values: list[int], percentage: int) -> float:
    return sorted(values)[math.ceil(len(values) * percentage / 100) - 1] / 1e6


def reconstruct(data: dict) -> dict:
    require(data.get("schema") == "pubpres-empty-derived-native-v1" and data.get("scope") == "native-only",
            "Unregistered native timing schema or scope")
    ticks, raw, phases = data["ticks"], data["tick_nanoseconds"], data["phase_nanoseconds"]
    require(integer(ticks, 1) and ticks <= 4096 and isinstance(raw, list) and len(raw) == ticks
            and all(integer(value, 1) for value in raw), "Missing, truncated or noninteger tick clocks")
    require(data["phase_columns"] == list(PHASES) and isinstance(phases, list) and len(phases) == ticks
            and all(isinstance(row, list) and len(row) == 4 and all(integer(value) for value in row)
                    and sum(row) <= elapsed for row, elapsed in zip(phases, raw)),
            "Phase clocks changed order or exceed their actual containing tick")
    computed = {"tick_mean_ms": sum(raw) / ticks / 1e6,
                "tick_p50_ms": nearest(raw, 50), "tick_p95_ms": nearest(raw, 95),
                "tick_p99_ms": nearest(raw, 99), "tick_max_ms": max(raw) / 1e6}
    computed.update({phase + "_mean_ms": sum(row[index] for row in phases) / ticks / 1e6
                     for index, phase in enumerate(PHASES)})
    require(all(type(data.get(name)) in (int, float) and math.isfinite(data[name])
                and math.isclose(data[name], value, rel_tol=1e-12, abs_tol=1e-12)
                for name, value in computed.items()), "Reported timing does not reconstruct from raw clocks")
    checkpoints = data["checkpoints"]
    expected = math.ceil(ticks / 12) * (3 + 3 * data["bodies"])
    require(len(checkpoints) == expected and all(integer(value) and value < 2**64 for value in checkpoints),
            "Complete semantic checkpoint sequence is missing")
    require(integer(data["wave_storage_bytes"]) and integer(data["water_units"])
            and integer(data["launched_parcels"]), "Invalid retained storage or conservation observations")
    return {**computed, "wave_storage_bytes": data["wave_storage_bytes"],
            "tick_counts_above_ms": {str(limit): sum(value > limit * 1e6 for value in raw)
                                     for limit in (16.667, 33.334, 50, 100, 250, 500, 1000)}}


def reduce_receipts(receipts: dict) -> dict:
    require(receipts["schema"] == "pubpres-native-empty-derived-receipts-v1", "Unknown receipt schema")
    manifest = receipts["manifest"]
    require(manifest["schema"] == "pubpres-native-empty-derived-abba-v1"
            and manifest["order"] == list(ORDER) and manifest["ticks"] == 72 and manifest["workers"] == 4,
            "Native comparison differs from registration")
    require(len(manifest["runs"]) == 24 and len(receipts["raw_runs"]) == 24,
            "All original six-cohort A/B/B/A processes are required")
    builds = manifest["builds"]
    require(set(builds) == {"A", "B"} and builds["A"]["compiler"] == builds["B"]["compiler"]
            and builds["A"]["flags"] == builds["B"]["flags"]
            and builds["A"]["benchmark_sha256"] == builds["B"]["benchmark_sha256"],
            "Independent native arms changed compiler, flags or benchmark source")
    for arm in ORDER:
        require(builds[arm]["exit_code"] == 0 and len(builds[arm]["binary_sha256"]) == 64
                and len(builds[arm]["source_commit"]) == 40 and builds[arm]["source_inputs_sha256"],
                "Unsuccessful or unidentified independent native build")
    cohorts = []
    for cohort, (label, size, bodies, profile) in enumerate(COHORTS):
        original, measurements = [], []
        for index, arm in enumerate(ORDER, 1):
            run = manifest["runs"][cohort * 4 + index - 1]
            name = f"{label}-{index}-{arm}"
            require(run["name"] == name and run["arm"] == arm and run["exit_code"] == 0
                    and run["argv"][1:] == [str(size), str(bodies), "4", "72", str(profile)]
                    and run["binary_sha256"] == builds[arm]["binary_sha256"],
                    "Unsuccessful, reordered or different native process: " + name)
            raw = receipts["raw_runs"][name]
            require(raw["stderr"] == "" and all(hashlib.sha256(raw[key].encode()).hexdigest() == raw[key + "_sha256"]
                                                 for key in ("stdout", "stderr")), "Raw native output custody differs: " + name)
            data = json.loads(raw["stdout"])
            for key, value in (("size", size), ("bodies", bodies), ("profile", profile),
                               ("ticks", 72), ("workers", 4), ("workers_observed", 4)):
                require(type(data[key]) is int and data[key] == value, "Native case or worker participation differs: " + name)
            original.append(data)
            measurements.append({"name": name, "arm": arm, **reconstruct(data)})
        require(all(all(row[key] == original[0][key] for key in ("water_units", "launched_parcels", "checkpoints"))
                    for row in original[1:]), "Candidate changed semantic/conservation outcome: " + label)
        controls = [measurements[index] for index in (0, 3)]
        candidates = [measurements[index] for index in (1, 2)]
        strict = {field: max(row[field] for row in candidates) < min(row[field] for row in controls) for field in FIELDS}
        cohorts.append({"cohort": label, "complete_semantic_checkpoint_parity": True,
                        "measurements_in_order": measurements,
                        "mean_percent_change": 100 * (sum(row["tick_mean_ms"] for row in candidates)
                                                      / sum(row["tick_mean_ms"] for row in controls) - 1),
                        "both_candidates_below_both_controls": strict,
                        "all_registered_timing_directions_repeat": all(strict.values())})
    return {"schema": "pubpres-native-empty-derived-reduction-v1", "cohorts": cohorts,
            "source_identities": {arm: {key: builds[arm][key] for key in
                                  ("source_commit", "source_tree", "binary_sha256", "benchmark_sha256")}
                                  for arm in ("A", "B")},
            "percentile_policy": "Recomputed nearest-rank within each72-tick process; p99 equals max for72 samples. No averaging/merging of percentile estimates.",
            "scope": "Native-only completed tick/phase observations, no Rapier/presentation/input witness. All original adverse runs retained. Two processes per arm/cohort are a development screen, not sustained gameplay qualification.",
            "physical_acceptance": "HOLD"}


def main() -> None:
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
