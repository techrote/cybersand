#!/usr/bin/env python3
"""Read-only independent reduction of source-matched CyberSand HS-PKT #470 logs.

Input is a verbatim, minimally wrapped capture of HARD_SURFACE_PROFILE records
from Actions job 128182806453. It is *not* a native benchmark or a physics oracle.
No third-party packages. python reduce_hs470_abba.py hs470_abba_profiles.json
"""
import argparse
import json
import math
import hashlib
from pathlib import Path

CANVASES = ("my-canvas", "bench-canvas", "stress-canvas")
ARM_ORDER = ("control", "candidate", "candidate", "control")
SOURCE = {
    "control": "4a80af2a891332176a3912a235582d77d076a185",
    "candidate": "6aa03fe21dbe88b308793f377e4d223a90e4da8f",
}
BINARY = {
    "control": "f47c0d6313bd6aa79767d2683c9273172822e6a04220a7a609f4c6d85dfb96a4",
    "candidate": "1409f2799da6335892a414ba2e87770549081602e5fb8528cdb2905af1ac30ea",
}
METRICS = ("simulation", "hard_surface_packet_executed", "render_exchange_executed",
           "publication_build", "snapshot_copy_total")
# Derived from the parsed, byte-verified historical Git blob 40e0813ed6b80bef6feb8d721c196e43ea8d0517.
# This is content equality, NOT a signature or independent source authentication.
PUBLISHED_CANONICAL_SHA256 = "34ed75b43b02058d52ce3fd68684a43d5afc241b3b8840a8696cb29d82caa4e2"


def canonical_digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=True, allow_nan=False).encode()).hexdigest()


class EvidenceError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise EvidenceError(message)


def checked_stats(stats, location):
    require(isinstance(stats, dict), f"{location}: not a record")
    n = stats.get("samples")
    require(type(n) is int and 0 <= n <= 100000, f"{location}: bad sample count")
    for k in ("p50_ms", "p95_ms", "mean_ms", "max_ms"):
        v = stats.get(k)
        require(type(v) in (int, float) and math.isfinite(v) and v >= 0, f"{location}: invalid {k}")
    if n == 0:
        require(all(stats[k] == 0 for k in ("p50_ms", "p95_ms", "mean_ms", "max_ms")),
                f"{location}: nonzero timing without samples")
    require(stats["p50_ms"] <= stats["p95_ms"] <= stats["max_ms"] + 1e-9,
            f"{location}: impossible percentile order")
    require(stats["mean_ms"] <= stats["max_ms"] + 1e-9,
            f"{location}: mean exceeds maximum")
    checked_producer_order_statistics(stats, location)


def checked_producer_order_statistics(stats, location):
    """Necessary quantile/mean feasibility for this source-pinned Godot producer.

    The Godot profiler reports sorted[int(round((n-1)*fraction))] using
    positive-half-away rounding, with fractions .50 and .95. These
    inequalities follow from ordering, nonnegative timings and exact sample
    count. They are necessary, NOT sufficient to authenticate raw samples.
    """
    n = stats["samples"]
    if not n:
        return
    midpoint = math.floor((n - 1) * 0.50 + 0.5)
    upper_rank = math.floor((n - 1) * 0.95 + 0.5)
    median, p95, maximum = (stats[k] for k in ("p50_ms", "p95_ms", "max_ms"))
    require(midpoint != upper_rank or median == p95,
            f"{location}: coincident producer quantiles disagree")
    require(upper_rank != n - 1 or p95 == maximum,
            f"{location}: producer p95 must equal maximum")
    min_mean = ((upper_rank - midpoint) * median
                + (n - 1 - upper_rank) * p95 + maximum) / n
    max_mean = ((midpoint + 1) * median
                + (upper_rank - midpoint) * p95
                + (n - 1 - upper_rank) * maximum) / n
    # 10 ns in milliseconds: larger than observed JSON floating-point rounding;
    # not an accuracy claim about any physical or native timing stage.
    tolerance_ms = 1e-8
    require(min_mean - tolerance_ms <= stats["mean_ms"] <= max_mean + tolerance_ms,
            f"{location}: infeasible producer mean/order statistics")


def reduce(dataset):
    require(type(dataset) is dict, "dataset must be a JSON object")
    input_digest = canonical_digest(dataset)
    source_matched = input_digest == PUBLISHED_CANONICAL_SHA256
    require(dataset.get("schema") == "b4-hs470-verbatim-profiles-v1", "wrong schema")
    provenance = dataset.get("provenance", {})
    require(type(provenance) is dict, "invalid provenance")
    require(type(provenance.get("run_id")) is int and type(provenance.get("job_id")) is int,
            "run/job IDs must be integers")
    require(provenance.get("run_id") == 42302283599 and provenance.get("job_id") == 128182806453,
            "unrecognized published run/job")
    observations = dataset.get("records")
    require(isinstance(observations, list) and len(observations) == 12,
            "require exactly 12 run/canvas records")
    hosts = set()
    by = {}
    for i, item in enumerate(observations):
        arm = ARM_ORDER[i // 3]
        canvas = CANVASES[i % 3]
        where = f"record {i} ({arm}/{canvas})"
        require(type(item) is dict, f"{where}: expected object")
        require(type(item.get("run_index")) is int, f"{where}: run_index must be integer")
        require(item.get("arm") == arm and item.get("run_index") == i // 3 + 1,
                f"{where}: ABBA arm/ordering mismatch")
        p = item.get("profile", {})
        require(p.get("canvas") == canvas, f"{where}: canvas/order mismatch")
        require(p.get("schema") == "cybersand-hard-surface-profile-v1",
                f"{where}: producer schema mismatch")
        require(p.get("source_sha") == SOURCE[arm], f"{where}: source mismatch")
        require(type(p.get("requested_sample_ticks")) is int and type(p.get("warmup_ticks")) is int,
                f"{where}: acquisition tick counts must be integers")
        require(p.get("requested_sample_ticks") == 180 and p.get("warmup_ticks") == 30,
                f"{where}: acquisition window mismatch")
        runtime = p.get("runtime", {})
        require(type(runtime) is dict, f"{where}: invalid runtime")
        require(runtime.get("native_sha256") == BINARY[arm], f"{where}: binary mismatch")
        window = runtime.get("window")
        require(type(runtime.get("logical_cpus")) is int and
                type(window) is list and len(window) == 2 and
                all(type(v) is int and v > 0 for v in window),
                f"{where}: malformed host CPU/window grammar")
        host = (runtime.get("os"), runtime.get("godot"), runtime.get("processor"),
                runtime.get("logical_cpus"), tuple(window))
        require(host[0] == "Linux" and host[3] == 4 and host[1], f"{where}: unexpected host")
        hosts.add(host)
        for metric in METRICS:
            checked_stats(p.get(metric), f"{where}.{metric}")
        # Producer hard_surface_packet_profile.gd appends exactly one value to
        # each whole-snapshot metric per observed snapshot. Its positive-only
        # executed-event stages are subsets, never more than one per snapshot.
        # These are provenance/feasibility guards, not performance thresholds.
        observed = p.get("observed_snapshots")
        require(type(observed) is int and 1 <= observed <= 100000,
                f"{where}: invalid observed snapshot count")
        for metric in ("simulation", "snapshot_copy_total", "publication_build"):
            require(p[metric]["samples"] == observed,
                    f"{where}.{metric}: whole-snapshot sample mismatch")
        for metric in ("render_exchange_executed", "hard_surface_packet_executed"):
            require(p[metric]["samples"] <= observed,
                    f"{where}.{metric}: executed event count exceeds snapshots")
        by[(i // 3, canvas)] = p
    require(len(hosts) == 1, "host/environment mismatch across arms")

    out = {"source": provenance,
           "historical_input_integrity": "MATCHED_PUBLISHED_FIXTURE" if source_matched else "UNVERIFIED_MODIFIED_INPUT",
           "canonical_input_sha256": input_digest,
           "scope": "independent reduction of existing hosted profiles; no new native run",
           "host": list(hosts)[0],
           "physical_parity": "NOT_OBSERVED_IN_THIS_PROFILE",
           "actual_worker_participation": "NOT_OBSERVED_IN_THIS_PROFILE",
           "canvases": {}}
    for canvas in CANVASES:
        p = [by[(i, canvas)] for i in range(4)]
        packets = [x["hard_surface_packet_executed"] for x in p]
        if all(q["samples"] == 0 for q in packets):
            gate, reason = "NO_PACKET_EVENTS", "zero measured packet samples in all four arms"
        elif min(q["samples"] for q in packets) < 100:
            gate, reason = "HOLD_LOW_SAMPLE", "fewer than 100 packet samples in at least one arm"
        else:
            gate, reason = "STAGE_ONLY", "packet p50/p95 source-matched; not physical or whole-tick admission"
        pairs = []
        for c, v in ((0, 1), (3, 2)):
            ctrl, cand = p[c], p[v]
            c_pkt, v_pkt = packets[c], packets[v]
            packet_reduction = None
            if c_pkt["samples"] and v_pkt["samples"] and c_pkt["p50_ms"] > 0:
                packet_reduction = round(100 * (1 - v_pkt["p50_ms"] / c_pkt["p50_ms"]), 3)
            pairs.append({"control_run": c + 1, "candidate_run": v + 1,
                          "control_packet_samples": c_pkt["samples"],
                          "candidate_packet_samples": v_pkt["samples"],
                          "packet_p50_reduction_pct": packet_reduction,
                          "control_packet_p95_ms": c_pkt["p95_ms"],
                          "candidate_packet_p95_ms": v_pkt["p95_ms"],
                          "simulation_p50_change_pct": round(
                              100 * (1 - cand["simulation"]["p50_ms"] / ctrl["simulation"]["p50_ms"]), 3),
                          "simulation_p95_control_ms": ctrl["simulation"]["p95_ms"],
                          "simulation_p95_candidate_ms": cand["simulation"]["p95_ms"]})
        out["canvases"][canvas] = {"gate": gate, "reason": reason, "pairs": pairs}
    bench = out["canvases"]["bench-canvas"]
    packet_stage_win = (bench["gate"] == "STAGE_ONLY" and
                        all(pair["packet_p50_reduction_pct"] is not None and
                            pair["packet_p50_reduction_pct"] > 0 and
                            pair["candidate_packet_p95_ms"] < pair["control_packet_p95_ms"]
                            for pair in bench["pairs"]))
    if source_matched and packet_stage_win:
        out["decision"] = (
            "GO for published #470 bench-canvas packet-stage reduction only; "
            "HOLD on whole-tick/FPS attribution and B2/B3 new-performance claims; "
            "stress packet count too small and my-canvas has zero packet samples")
    elif not source_matched:
        out["decision"] = (
            "HOLD: input differs from immutable published #470 fixture; "
            "no historical packet-stage GO or whole-tick inference permitted")
    else:
        out["decision"] = (
            "NO-GO: both A/B/B/A packet p50 and p95 comparisons must improve for "
            "a packet-stage win; no whole-tick inference permitted")
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("json_path", type=Path)
    args = parser.parse_args()
    print(json.dumps(reduce(json.loads(args.json_path.read_text(encoding="utf-8"))), indent=2))


if __name__ == "__main__":
    main()
