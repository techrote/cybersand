#!/usr/bin/env python3
"""B4 research-only: source-locked, event-exposure-adjusted packet cost.

Re-reduces historical real #470 Godot profiles; no native execution. The stage
budget is a descriptive fraction of measured wall time, not a causal bound on
all effects of the changed engine source.

python3 hs470_stage_wall_budget.py hs470_abba_profiles.json
python3 hs470_stage_wall_budget.py --self-test
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

INPUT_BLOB = "40e0813ed6b80bef6feb8d721c196e43ea8d0517"
CANVASES = ("my-canvas", "bench-canvas", "stress-canvas")


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def stage_budget(profile: dict) -> dict:
    stage = profile["hard_surface_packet_executed"]
    samples = stage["samples"]
    mean = stage["mean_ms"]
    snaps = profile["observed_snapshots"]
    wall = profile["wall_ms"]
    if (type(samples) is not int or samples < 0 or type(snaps) is not int or snaps <= 0
            or type(mean) not in (float, int) or not math.isfinite(mean) or mean < 0
            or type(wall) not in (float, int) or not math.isfinite(wall) or wall <= 0
            or samples > snaps or (samples == 0 and mean != 0)):
        raise ValueError("invalid packet-event/wall exposure fields")
    measured_sum = samples * mean
    if measured_sum > wall + 1e-9:
        raise ValueError("stage time exceeds recorded wall duration")
    return {
        "packet_events": samples,
        "snapshots": snaps,
        "packet_event_fraction": samples / snaps,
        "packet_stage_total_ms": measured_sum,
        "packet_stage_per_snapshot_ms": measured_sum / snaps,
        "packet_stage_fraction_of_wall_pct": 100 * measured_sum / wall,
        "wall_ms": wall,
    }


def paired(control: dict, candidate: dict) -> dict:
    wall_delta = control["wall_ms"] - candidate["wall_ms"]
    stage_delta = control["packet_stage_total_ms"] - candidate["packet_stage_total_ms"]
    return {
        "control_stage_wall_fraction_pct": control["packet_stage_fraction_of_wall_pct"],
        "candidate_stage_wall_fraction_pct": candidate["packet_stage_fraction_of_wall_pct"],
        "observed_wall_change_pct": 100 * wall_delta / control["wall_ms"],
        "stage_sum_difference_ms": stage_delta,
        "observed_wall_difference_ms": wall_delta,
        "non_stage_difference_ms": wall_delta - stage_delta,
        "packet_exposure_difference_per_snapshot_ms": (
            control["packet_stage_per_snapshot_ms"] - candidate["packet_stage_per_snapshot_ms"]
        ),
        "stage_accounting_alone_insufficient_for_wall_difference": (
            abs(wall_delta - stage_delta) > 1e-6
        ),
    }


def analyze(dataset: dict) -> dict:
    # Canonical B4 reducer owns arm ordering, exact binary/source, host, and
    # schema checks. Keep all provenance checks in one place rather than drift.
    from reduce_hs470_abba import reduce
    reduce(dataset)
    rows = dataset["records"]
    result = {
        "scope": "historical #470 host profiles; stage/wall accounting only",
        "input_git_blob": INPUT_BLOB,
        "event_unit": "one measured hard_surface_packet_executed call",
        "limitations": [
            "The stage sum assumes reported event means reflect their recorded calls",
            "The source change may have secondary costs/benefits outside this timer",
            "Wall elapsed includes headless startup/pacing; no paired per-tick wall evidence",
            "No native physical-hash, worker-participation, RSS or allocation evidence",
        ],
        "canvases": {},
    }
    for canvas in CANVASES:
        run_rows = [r for r in rows if r["profile"]["canvas"] == canvas]
        arms = [stage_budget(row["profile"]) for row in run_rows]
        result["canvases"][canvas] = {
            "arms_in_ABBA_order": arms,
            "forward_control1_candidate2": paired(arms[0], arms[1]),
            "reverse_control4_candidate3": paired(arms[3], arms[2]),
        }
    return result


def self_test() -> None:
    base = {"hard_surface_packet_executed": {"samples": 2, "mean_ms": 0.25},
            "observed_snapshots": 10, "wall_ms": 50.0}
    a = stage_budget(base)
    assert a["packet_stage_total_ms"] == 0.5
    assert a["packet_stage_per_snapshot_ms"] == 0.05
    assert a["packet_stage_fraction_of_wall_pct"] == 1.0
    b = stage_budget({"hard_surface_packet_executed": {"samples": 0, "mean_ms": 0.0},
                      "observed_snapshots": 10, "wall_ms": 50.0})
    assert paired(a, b)["stage_sum_difference_ms"] == 0.5
    assert paired(a, b)["non_stage_difference_ms"] == -0.5
    bad = [
        {**base, "observed_snapshots": 0},
        {**base, "wall_ms": 0},
        {**base, "wall_ms": float("nan")},
        {**base, "hard_surface_packet_executed": {"samples": 11, "mean_ms": 0.1}},
        {**base, "hard_surface_packet_executed": {"samples": 0, "mean_ms": 0.1}},
        {**base, "hard_surface_packet_executed": {"samples": 2, "mean_ms": -0.1}},
        {**base, "wall_ms": 0.1},
    ]
    for case in bad:
        try:
            stage_budget(case)
        except ValueError:
            pass
        else:
            raise AssertionError(f"bad exposure admitted: {case}")
    assert git_blob(b"hello\n") == "ce013625030ba8dba906f756967f9e9ca394464a"
    print("B4 STAGE/WALL SELF-TEST PASS: arithmetic, seven refusals, Git blob")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path, nargs="?")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        self_test()
        return
    if args.input is None:
        ap.error("provide the historical profile JSON or --self-test")
    raw = args.input.read_bytes()
    actual = git_blob(raw)
    if actual != INPUT_BLOB:
        raise ValueError(f"SOURCE_MISMATCH input Git blob expected={INPUT_BLOB} got={actual}")
    print(json.dumps(analyze(json.loads(raw)), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
