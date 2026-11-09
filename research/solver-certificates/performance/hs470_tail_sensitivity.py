#!/usr/bin/env python3
"""B4: source-pinned p95/negative-control reduction of real #470 hosted profiles.

Descriptive reanalysis only; no native run or causal FPS inference.
Run in this directory: python3 hs470_tail_sensitivity.py hs470_abba_profiles.json
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
from reduce_hs470_abba import reduce

PROFILE_BLOB = "40e0813ed6b80bef6feb8d721c196e43ea8d0517"
MAIN = "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"
CANVASES = ("my-canvas", "bench-canvas", "stress-canvas")


def blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def change(c: float, b: float) -> float:
    if min(c, b) <= 0:
        raise ValueError("empty/nonpositive source timing")
    return round(100 * (1 - b / c), 4)


def summarize(records: list[dict]) -> dict:
    by = defaultdict(dict)
    for row in records:
        i, p = row["run_index"], row["profile"]
        canvas = p["canvas"]
        if (i not in (1, 2, 3, 4) or canvas not in CANVASES
                or i in by[canvas] or row["arm"] != ("control" if i in (1, 4) else "candidate")):
            raise ValueError("unknown, repeated or malformed ABBA arm/canvas")
        by[canvas][i] = p
    if len(records) != 12 or any(set(by.get(c, {})) != {1, 2, 3, 4} for c in CANVASES):
        raise ValueError("incomplete 12-profile source set")
    output = {}
    for canvas in CANVASES:
        p = by[canvas]
        pairs = []
        for label, a, b in (("A1/B1", 1, 2), ("A2/B2", 4, 3)):
            c, v = p[a], p[b]
            sc, sv = c["simulation"], v["simulation"]
            pc, pv = c["hard_surface_packet_executed"], v["hard_surface_packet_executed"]
            if min(sc["samples"], sv["samples"]) < 1:
                raise ValueError("missing native simulation sample")
            pairs.append({
                "order": label, "control_run": a, "candidate_run": b,
                "simulation_samples": [sc["samples"], sv["samples"]],
                "packet_samples": [pc["samples"], pv["samples"]],
                "packet_stage_sample_gate": min(pc["samples"], pv["samples"]) >= 100,
                "simulation_mean_change_pct": change(sc["mean_ms"], sv["mean_ms"]),
                "simulation_p50_change_pct": change(sc["p50_ms"], sv["p50_ms"]),
                "simulation_p95_change_pct": change(sc["p95_ms"], sv["p95_ms"]),
                "simulation_p95_ms": [sc["p95_ms"], sv["p95_ms"]],
            })
        output[canvas] = pairs
    if not (all(r["packet_samples"] == [0, 0] and r["simulation_p95_change_pct"] > 0
                for r in output["my-canvas"])
            and output["bench-canvas"][0]["simulation_p95_change_pct"]
                > output["bench-canvas"][1]["simulation_p95_change_pct"]
            and output["stress-canvas"][0]["simulation_p95_change_pct"] < 0
                < output["stress-canvas"][1]["simulation_p95_change_pct"]):
        raise ValueError("pre-registered tail/negative-control signature did not reproduce")
    return {
        "identity": {"accepted_main_at_capture": MAIN, "profiles_blob": PROFILE_BLOB,
                     "original_run": 42302283599, "executed_utc": "2026-11-06"},
        "comparisons": output,
        "source_limits": {
            "raw_per_tick_samples": False, "physical_hash_parity": False,
            "actual_worker_participation": False, "memory_rss": False,
            "allocations": False, "native_runner_executed_this_study": False},
        "disposition": "GO existing #470 packet-stage only; HOLD whole-tick causal or B2/B3 cost claims"
    }


def run(path: Path) -> dict:
    source = path.read_bytes()
    if blob(source) != PROFILE_BLOB:
        raise ValueError("source blob mismatch: refuse stale publication")
    records = json.loads(source)
    reduce(records)  # independent existing source/native binary/host/sample validator
    return summarize(records["records"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profiles", type=Path)
    args = parser.parse_args()
    print(json.dumps(run(args.profiles), indent=2, sort_keys=True))
