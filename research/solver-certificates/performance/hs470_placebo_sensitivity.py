#!/usr/bin/env python3
"""B4-007: source-pinned zero-packet placebo diagnostic on historical #470 A/B/B/A.

No new native benchmark. Difference-of-differences of *reported aggregate* timing
statistics is descriptive, not a causal estimator or per-tick paired statistic.
Usage from the B4 performance subtree:
    python3 hs470_placebo_sensitivity.py hs470_abba_profiles.json
    python3 hs470_placebo_sensitivity.py --self-test
"""
from __future__ import annotations

import argparse
from decimal import Decimal
import hashlib
import json
from pathlib import Path

from reduce_hs470_abba import reduce as verify_historical_profiles

PROFILE_BLOB = "40e0813ed6b80bef6feb8d721c196e43ea8d0517"
BASELINE = "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"
REAL_RUN = 42302283599
METRICS = ("p50_ms", "p95_ms", "mean_ms")
ARM = {1: "control", 2: "candidate", 3: "candidate", 4: "control"}
CANVASES = ("my-canvas", "bench-canvas", "stress-canvas")


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def dec(x: int | float | str) -> Decimal:
    if type(x) not in (int, float, str):
        raise ValueError("metric must be a concrete decimal quantity")
    result = Decimal(str(x))
    if not result.is_finite() or result <= 0:
        raise ValueError("requires positive finite timing statistic")
    return result


def summarize(records: list[dict]) -> dict:
    """A post-hoc diagnostic on separately sampled timing distributions.

    The real-data loader first invokes the accepted historical provenance
    validator; this small pure function additionally enforces pairing and the
    placebo's zero packet-stage exposure.
    """
    if type(records) is not list or len(records) != 12:
        raise ValueError("requires exactly 12 arm/canvas profiles")
    by = {}
    for row in records:
        if type(row) is not dict or type(row.get("run_index")) is not int:
            raise ValueError("malformed arm record")
        run = row["run_index"]
        profile = row.get("profile")
        if run not in ARM or row.get("arm") != ARM[run] or type(profile) is not dict:
            raise ValueError("arm or profile identity mismatch")
        canvas = profile.get("canvas")
        if canvas not in CANVASES or (canvas, run) in by:
            raise ValueError("missing/duplicate/unknown canvas")
        by[(canvas, run)] = profile
    if len(by) != 12:
        raise ValueError("incomplete arm/canvas cartesian product")
    for run in ARM:
        negative = by[("my-canvas", run)]["hard_surface_packet_executed"]
        if type(negative.get("samples")) is not int or negative["samples"] != 0:
            raise ValueError("placebo has packet events; null-stage control invalid")
    out = {}
    for c, b in ((1, 2), (4, 3)):
        pair = f"C{c}-B{b}"
        result = {"control_run": c, "candidate_run": b, "metrics": {}}
        for metric in METRICS:
            bc = dec(by[("bench-canvas", c)]["simulation"][metric])
            bv = dec(by[("bench-canvas", b)]["simulation"][metric])
            nc = dec(by[("my-canvas", c)]["simulation"][metric])
            nv = dec(by[("my-canvas", b)]["simulation"][metric])
            bench_gain = bc - bv
            placebo_gain = nc - nv
            difference_of_differences = bench_gain - placebo_gain
            result["metrics"][metric] = {
                "bench_control_ms": str(bc),
                "bench_candidate_ms": str(bv),
                "bench_gain_ms": str(bench_gain),
                "zero_packet_control_ms": str(nc),
                "zero_packet_candidate_ms": str(nv),
                "zero_packet_gain_ms": str(placebo_gain),
                "descriptive_difference_ms": str(difference_of_differences),
            }
        out[pair] = result
    return {
        "real_execution_utc": "2026-11-06",
        "reduced_utc": "2026-11-10",
        "historical_run": REAL_RUN,
        "accepted_main_at_review": BASELINE,
        "input_git_blob": PROFILE_BLOB,
        "qualification": "POST_HOC_DESCRIPTIVE_DIAGNOSTIC_ONLY",
        "no_packet_reference": "my-canvas; 0 packet calls in all 4 arms",
        "pairs": out,
        "unavailable": ["per_tick_samples", "actual_worker_participation",
                         "physical_hash_parity", "rss_or_allocations", "causal_identification"],
        "disposition": "GO published #470 packet stage; HOLD whole-tick attribution and B2/B3 performance",
    }


def run(path: Path) -> dict:
    data = path.read_bytes()
    if git_blob(data) != PROFILE_BLOB:
        raise ValueError("raw historical profile blob mismatch: refuse changed input")
    obj = json.loads(data)
    verify_historical_profiles(obj)  # checks host, arm, source/native hashes and sample windows
    return summarize(obj["records"])


def self_test() -> None:
    """Synthetic controls for code correctness, NEVER claimed as measured data."""
    from copy import deepcopy
    rec = []
    for arm_index in (1, 2, 3, 4):
        for canvas in CANVASES:
            base = 8 if canvas == "bench-canvas" else (4 if canvas == "my-canvas" else 30)
            # Forward: bench and placebo change equally; reverse slightly diverges.
            bump = {1: 0.2, 2: 0.0, 3: 0.0, 4: 0.1}[arm_index]
            if canvas == "bench-canvas" and arm_index == 4:
                bump = 0.12
            rec.append({"arm": ARM[arm_index], "run_index": arm_index, "profile": {
                "canvas": canvas,
                "simulation": {"p50_ms": base+bump, "p95_ms": base+bump+1,
                               "mean_ms": base+bump+0.5},
                "hard_surface_packet_executed": {"samples": 0 if canvas == "my-canvas" else 150},
            }})
    got = summarize(rec)
    assert Decimal(got["pairs"]["C1-B2"]["metrics"]["p50_ms"]["descriptive_difference_ms"]) == 0
    assert Decimal(got["pairs"]["C4-B3"]["metrics"]["p50_ms"]["descriptive_difference_ms"]) == Decimal("0.02")
    checks = [
        lambda x: x.pop(),
        lambda x: x.__setitem__(0, deepcopy(x[1])),
        lambda x: x[0].update(arm="candidate"),
        lambda x: x[0]["profile"]["hard_surface_packet_executed"].update(samples=1),
        lambda x: x[0]["profile"]["simulation"].update(p50_ms=0),
        lambda x: x[0]["profile"]["simulation"].update(p95_ms=float("nan")),
        lambda x: x[0]["profile"]["simulation"].update(mean_ms=True),
    ]
    for change in checks:
        candidate = deepcopy(rec)
        change(candidate)
        try:
            summarize(candidate)
        except ValueError:
            continue
        raise AssertionError("adversarial fixture not refused")
    assert git_blob(b"hello") == "b6fc4c620b67d95f953a5c1c1230aaab5db5a1b0"
    try:
        run(Path(__file__))
    except ValueError as e:
        assert "blob mismatch" in str(e)
    else:
        raise AssertionError("untrusted raw input accepted")
    print("PASS: 2 arithmetic controls, 7 adversarial refusals, 2 blob guards (synthetic test data)")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("profiles", nargs="?", type=Path)
    p.add_argument("--self-test", action="store_true")
    a = p.parse_args()
    if a.self_test:
        self_test()
    else:
        if a.profiles is None:
            p.error("profiles JSON required without --self-test")
        print(json.dumps(run(a.profiles), indent=2, sort_keys=True))
