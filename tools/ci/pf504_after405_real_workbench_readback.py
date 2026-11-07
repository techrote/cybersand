#!/usr/bin/env python3
"""Fail-closed comparison of actual 2048x1024 workbench stress-canvas source A/B.

The two source binaries run on one hosted Linux machine in B-C-C-B order.
Successful execution does NOT establish physical-hash equality or native gas
stage CPU parity; neither is exposed by this Godot workbench observation.
"""
from __future__ import annotations

import hashlib
import json
import os
import statistics
import sys
from pathlib import Path

BASE = "81bbd5ff5cf366159e2b8a630609359c13560080"
CANDIDATE = os.environ.get("CANDIDATE_SOURCE","")
RAPIER_LINUX = "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"
ORDER = (("B1", "B", BASE), ("C1", "C", CANDIDATE),
         ("C2", "C", CANDIDATE), ("B2", "B", BASE))
MARKER = "PF_C2048_WORKBENCH_PROFILE "


def require(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError(message)


def percent_change(base: float, candidate: float) -> float:
    require(base > 0 and candidate > 0, "nonpositive measured duration")
    return 100.0 * (base - candidate) / base


def read_one(root: Path, name: str, arm: str, source: str, expected_binary: str) -> dict:
    path = root / f"stress-{name}.log"
    require(path.is_file(), f"{name}: missing original Godot log")
    raw = path.read_text(errors="replace")
    matches = []
    for line in raw.splitlines():
        if MARKER not in line:
            continue
        payload = line.split(MARKER, 1)[1].strip()
        if payload.startswith("{"):
            matches.append(json.loads(payload))
    require(len(matches) == 1, f"{name}: expected exactly one real authored stress-canvas receipt")
    require("PF_C2048_WORKBENCH_COMPLETE 1/1" in raw,
            f"{name}: actual workbench did not certify a completed stress-canvas")
    data = matches[0]
    prefix = name + ": "
    require(data.get("schema") == "pf-c2048-extended-workbench-v1", prefix + "wrong receipt schema")
    require(data.get("source_sha") == source, prefix + "wrong compiled source")
    require(data.get("benchmark_arm") == arm and data.get("benchmark_repetition") == int(name[1]),
            prefix + "wrong source arm or repetition")
    require(data.get("capacity") == 2048 and data.get("native_failed") is False,
            prefix + "missing active C2048 or native execution failed")
    require(data.get("canvas") == "stress-canvas" and data.get("extent") == [2048, 1024]
            and data.get("actual_installed_extent") == [2048, 1024],
            prefix + "not the complete authored workbench stress-canvas")
    require(data.get("actors_requested") == 8 and data.get("actual_installed_actor_count") == 8,
            prefix + "not eight installed Rapier barrels")
    require(data.get("warmup_ticks") == 24 and data.get("requested_sample_ticks") == 240,
            prefix + "staged workload changed")
    require(data.get("last_snapshot_tick", 0) >= 264,
            prefix + "did not finish the required 264-tick workbench window")
    require(data.get("observed_snapshots", 0) >= 200
            and data.get("actual_actor_steps", 0) >= 200
            and data.get("observed_actor_samples", 0) >= 20,
            prefix + "native/Rapier physical execution too short")
    require(data.get("accepted_edit_requests", 0) >= 45
            and data.get("observed_hard_revision_changes", 0) >= 35,
            prefix + "no sustained real hard-surface edits")
    pressure = data.get("pressure", {})
    require(pressure.get("family") == "pressure_flow_v1"
            and pressure.get("variant") == "cached_dormant"
            and pressure.get("gas_enabled") is True
            and pressure.get("parameters", {}).get("compartment_capacity") == 2048,
            prefix + "wrong applied gas/capacity/variant")
    require(data.get("ballistic_enabled") is True
            and data.get("spray_enabled") is True
            and data.get("jet_enabled") is True,
            prefix + "ballistic Water/spray/jet not active")
    ledger = data.get("ballistic_ledger", {})
    require(ledger.get("launched_parcels", 0) + ledger.get("injected_parcels", 0) > 0,
            prefix + "no real ballistic parcels")
    runtime = data.get("runtime", {})
    require(runtime.get("os") == "Linux"
            and str(runtime.get("godot", "")).startswith("4.7")
            and runtime.get("native_sha256") == expected_binary
            and runtime.get("rapier_sha256") == RAPIER_LINUX,
            prefix + "runtime SHA, Godot version, or pinned Rapier mismatch")
    for stage in ("simulation", "packet", "snapshot_publication"):
        v = data.get(stage, {})
        require(v.get("samples", 0) >= (40 if stage == "packet" else 70),
                prefix + stage + " missing live timing samples")
        require(float(v.get("p50_ms", 0)) > 0 and float(v.get("p95_ms", 0)) > 0,
                prefix + stage + " missing nonzero timing distribution")
    data["_original_log_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    return data


def compare(root: Path) -> dict:
    require(len(CANDIDATE)==40 and set(CANDIDATE) <=set("abcdef0123456789"), "Unpinned exact-head candidate source SHA")
    binary = {}
    for arm in "BC":
        f = root / f"runtime-{arm}.sha256"
        require(f.is_file(), "missing independently compiled native binary fingerprint: " + arm)
        value = f.read_text().split()[0].strip()
        require(len(value) == 64, "invalid native binary SHA-256: " + arm)
        binary[arm] = value
    require(binary["B"] != binary["C"], "source-distinct binaries unexpectedly byte-identical")
    records = {name: read_one(root, name, arm, source, binary[arm])
               for name, arm, source in ORDER}
    hashes = {v["pressure"].get("policy_hash") for v in records.values()}
    require(len(hashes) == 1 and "" not in hashes,
            "source arms applied different PressureFlow policy identities")
    hardware = {(v["runtime"]["os"], v["runtime"]["cpu"], v["runtime"]["godot"],
                 v["runtime"]["rapier_sha256"]) for v in records.values()}
    require(len(hardware) == 1, "A/B executions used different hosts or dependencies")
    def metric(stage: str, percentile: str) -> dict:
        by_run = {k: float(v[stage][percentile]) for k, v in records.items()}
        changes = [percent_change(by_run["B1"], by_run["C1"]),
                   percent_change(by_run["B2"], by_run["C2"])]
        return {
            "baseline_median_ms": statistics.median([by_run["B1"], by_run["B2"]]),
            "candidate_median_ms": statistics.median([by_run["C1"], by_run["C2"]]),
            "two_paired_speedup_percent": changes,
            "median_paired_speedup_percent": statistics.median(changes),
            "units": "observed Godot workbench snapshot wall milliseconds",
        }
    metrics = {stage: {p: metric(stage, p) for p in ("p50_ms", "p95_ms")}
               for stage in ("simulation", "packet", "snapshot_publication")}
    result = {
        "schema": "pf504-post405-real-workbench-stress-ab-v1",
        "status": "MEASUREMENT_VALID_PHYSICAL_ACCEPTANCE_NOT_PROVEN",
        "comparison": "accepted C2048 source vs PR504 optimized PF gas BFS",
        "base_source": BASE,
        "optimized_source": CANDIDATE,
        "builds": {"baseline_sha256": binary["B"], "candidate_sha256": binary["C"]},
        "workload": {"source": "workbench_setup.gd::stress_canvas",
                     "canvas": "stress-canvas", "extent": [2048, 1024], "real_rapier_actors": 8,
                     "gas_capacity": 2048, "pf_variant": "cached_dormant",
                     "ballistic": True, "spray": True, "jet": True,
                     "hard_edit_period_native_ticks": 2,
                     "warmup_native_ticks": 24, "requested_sample_native_ticks": 240,
                     "order": [k for k, _, _ in ORDER], "same_host": True},
        "metrics": metrics,
        "source_reports": records,
        "limitations": [
            "Snapshot simulation_time_ms is elapsed native tick wall time, not gas-stage or process CPU",
            "GDScript workbench lacks native physical-state hash and full gas/Water conservation ledger",
            "Ordinary asynchronous native/Rapier scheduling may give different actor/jet timing; no physical identity claimed",
            "Two same-host paired repetitions of one 2048x1024 canvas do not establish universal performance",
            "No merger or production runtime publication is authorized by this experimental measurement",
        ],
    }
    out = root / "workbench-stress-comparison.json"
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print("PF504_STRESS_WORKBENCH_AB_PASS", "B-C-C-B",
          "native_tick_p50_median_speedup_percent",
          round(metrics["simulation"]["p50_ms"]["median_paired_speedup_percent"], 4),
          "gas_stage_cpu_unavailable", "physical_hash_unavailable")
    return result


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: pf504_stress_workbench_readback.py <retained-evidence-dir>")
    compare(Path(sys.argv[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
