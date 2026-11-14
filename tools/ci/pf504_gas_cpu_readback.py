#!/usr/bin/env python3
"""Same-host attribution of PF504's real 2048x1024 stress-canvas gas CPU cost.

This is an EXPLICIT profiler: std::clock() on Linux is process CPU across all
threads. It brackets the native gas operator, head computation and the World
tick. It does NOT isolate gas-worker CPU if unrelated Godot threads run during
that interval. Pre-existing steady-clock counters remain stage wall metrics.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import statistics
import sys

BASE = "24a8bbe8ccf0d17196ebbab580b924930a964584"
CANDIDATE = "186452b9f035961325ad71917a76ba8834e30bcf"
RAPIER = "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"
MARKER = "PF_C2048_WORKBENCH_PROFILE "
ORDER = (("B1", "B", BASE), ("C1", "C", CANDIDATE),
         ("C2", "C", CANDIDATE), ("B2", "B", BASE))
TIMERS = ("gas_nanoseconds", "head_nanoseconds", "preparation_nanoseconds",
          "pf504_gas_process_cpu_ns", "pf504_head_process_cpu_ns",
          "native_cumulative_cpu_ns", "native_cpu_sample_count")
WORK = ("gas_reference_passes", "gas_reuses", "gas_seed_cells",
        "gas_seed_probes", "gas_bfs_cells", "gas_bfs_probes", "gas_bfs_nodes",
        "gas_relabel_cells", "gas_member_validations", "gas_component_reuses",
        "gas_cache_build_cells", "gas_cache_builds", "gas_capacity_fallbacks",
        "gas_budget_fallbacks", "gas_restart_fallbacks", "water_material_calls",
        "water_motion_calls", "reference_fallbacks", "columns_recomputed")
METRICS = ("simulation", "packet", "snapshot_publication")


def check(ok: bool, reason: str) -> None:
    if not ok:
        raise AssertionError(reason)


def median(values: list[float]) -> float:
    return float(statistics.median(values))


def speedup(a: float, b: float) -> float:
    check(a > 0.0 and b > 0.0, "nonpositive comparison")
    return (a - b) / a * 100.0


def parse(root: Path, name: str, arm: str, source: str, native: str) -> dict:
    file = root / f"stress-{name}.log"
    check(file.is_file(), name + ": missing raw Godot log")
    raw = file.read_text(errors="replace")
    data = [json.loads(line.split(MARKER, 1)[1].strip())
            for line in raw.splitlines() if MARKER in line and
            line.split(MARKER, 1)[1].strip().startswith("{")]
    check(len(data) == 1, name + ": expected exactly one real workbench receipt")
    check("PF_C2048_WORKBENCH_COMPLETE 1/1" in raw, name + ": test did not complete")
    o = data[0]
    check(o.get("source_sha") == source and o.get("benchmark_arm") == arm and
          o.get("benchmark_repetition") == int(name[1]),
          name + ": wrong source or BCCB order")
    check(o.get("canvas") == "stress-canvas" and o.get("extent") == [2048, 1024] and
          o.get("actual_installed_extent") == [2048, 1024] and
          o.get("capacity") == 2048 and not o.get("native_failed"),
          name + ": not healthy full-resolution C2048")
    check(o.get("actors_requested") == 8 and o.get("actual_installed_actor_count") == 8
          and o.get("actual_actor_steps", 0) >= 200 and
          o.get("observed_actor_samples", 0) >= 20,
          name + ": not eight live, coupled Rapier bodies")
    check(o.get("warmup_ticks") == 24 and o.get("requested_sample_ticks") == 240
          and o.get("observed_snapshots", 0) >= 200 and
          o.get("accepted_edit_requests", 0) >= 45 and
          o.get("observed_hard_revision_changes", 0) >= 35,
          name + ": incomplete bounded active-run or hard mask edits")
    p = o.get("pressure", {})
    check(p.get("family") == "pressure_flow_v1" and
          p.get("variant") == "cached_dormant" and p.get("gas_enabled") is True and
          p.get("parameters", {}).get("compartment_capacity") == 2048,
          name + ": wrong physical gas profile")
    check(o.get("ballistic_enabled") is True and o.get("spray_enabled") is True
          and o.get("jet_enabled") is True and
          o.get("ballistic_ledger", {}).get("launched_parcels", 0) +
          o.get("ballistic_ledger", {}).get("injected_parcels", 0) > 0,
          name + ": ballistic work missing")
    runtime = o.get("runtime", {})
    check(runtime.get("os") == "Linux" and
          str(runtime.get("godot", "")).startswith("4.7") and
          runtime.get("rapier_sha256") == RAPIER and
          runtime.get("native_sha256") == native,
          name + ": runtime, Godot or Rapier fingerprints changed")
    for metric in METRICS:
        q = o.get(metric, {})
        check(q.get("samples", 0) >= (10 if metric == "packet" else 70)
              and q.get("p50_ms", 0) > 0 and q.get("p95_ms", 0) > 0,
              name + ": missing measured " + metric)
    prof = o.get("pf504_stage_profiler", {})
    check(prof.get("schema") == "pf504-stage-cpu-interval-v1" and
          prof.get("samples", 0) >= 170 and
          prof.get("worker_observed_peak", 0) > 0 and
          prof.get("worker_observed_nonzero", 0) >= 100,
          name + ": gas CPU profiler or actual worker samples absent")
    first, last = prof.get("first", {}), prof.get("last", {})
    check(bool(first) and bool(last), name + ": missing cumulative interval endpoints")
    check(first.get("worker_capacity") == last.get("worker_capacity") and
          1 <= int(last.get("worker_capacity", 0)) <= 32,
          name + ": worker capacity changed")
    keys = TIMERS + WORK
    deltas = {}
    for key in keys:
        check(str(first.get(key, "")).isdigit() and str(last.get(key, "")).isdigit(),
              name + ": missing unsigned CPU/work counter " + key)
        before, after = int(first[key]), int(last[key])
        check(after >= before, name + ": nonmonotone native counter " + key)
        deltas[key] = after - before
    ticks = deltas["native_cpu_sample_count"]
    check(170 <= ticks <= 280, name + ": invalid measured native-tick accounting window")
    check(all(deltas[k] > 0 for k in
              ("native_cumulative_cpu_ns", "gas_nanoseconds",
               "pf504_gas_process_cpu_ns", "head_nanoseconds",
               "pf504_head_process_cpu_ns", "gas_reference_passes")),
          name + ": no active gas/CPU stage work")
    tick_cpu = deltas["native_cumulative_cpu_ns"]
    gas_cpu = deltas["pf504_gas_process_cpu_ns"]
    head_cpu = deltas["pf504_head_process_cpu_ns"]
    # The stage brackets are nested inside World::tick. If the CPU accounting
    # is grossly larger than the tick accounting, clocks or snapshots are wrong.
    check(gas_cpu + head_cpu <= tick_cpu * 1.15,
          name + ": stage CPU counters exceed complete native tick CPU accounting")
    o["_profile_delta"] = deltas
    o["_profile_ticks"] = ticks
    o["_profile_log_sha256"] = hashlib.sha256(file.read_bytes()).hexdigest()
    o["_profile_means_ms_per_tick"] = {
        "native_process_cpu": tick_cpu / ticks / 1e6,
        "gas_process_cpu": gas_cpu / ticks / 1e6,
        "head_process_cpu": head_cpu / ticks / 1e6,
        "non_pressure_process_cpu": (tick_cpu - gas_cpu - head_cpu) / ticks / 1e6,
        "gas_wall": deltas["gas_nanoseconds"] / ticks / 1e6,
        "head_wall": deltas["head_nanoseconds"] / ticks / 1e6,
        "preparation_wall": deltas["preparation_nanoseconds"] / ticks / 1e6,
    }
    o["_gas_process_cpu_share_percent"] = gas_cpu / tick_cpu * 100.0
    return o


def compare(root: Path) -> dict:
    builds = {}
    for arm in ("B", "C"):
        f = root / f"runtime-{arm}.sha256"
        check(f.is_file(), "missing distinct source-built runtime fingerprint")
        builds[arm] = f.read_text().strip().split()[0]
        check(len(builds[arm]) == 64, "invalid native DLL SHA256")
    check(builds["B"] != builds["C"], "baseline/optimized binary collision")
    overlay_file = root / "overlay-details.json"
    check(overlay_file.is_file(), "missing exact-source ephemeral CPU overlay manifest")
    overlay = json.loads(overlay_file.read_text())
    check(overlay.get("schema") == "pf504-gas-cpu-ephemeral-overlay-v1", "unexpected profiler source")
    check([a.get("source") for a in overlay.get("arms", [])] == [BASE, CANDIDATE],
          "profiler patched different production revisions")
    rows = {name: parse(root, name, arm, sha, builds[arm])
            for name, arm, sha in ORDER}
    contexts = {(x["runtime"]["os"], x["runtime"]["cpu"], x["runtime"]["godot"],
                 x["runtime"]["rapier_sha256"]) for x in rows.values()}
    check(len(contexts) == 1, "different hosts or dependencies in same-host pairing")
    pressure_hashes = {x["pressure"].get("policy_hash", "") for x in rows.values()}
    check(len(pressure_hashes) == 1 and "" not in pressure_hashes, "pressure policy changed")
    # Real workbench asynchronous actor scheduling may vary, but the source
    # comparison must still retain identical cumulative ballistic receipts.
    ledger_identity = {json.dumps(x.get("ballistic_ledger", {}), sort_keys=True)
                       for x in rows.values()}
    check(len(ledger_identity) == 1 and "{}" not in ledger_identity,
          "ballistic ledger drift: cannot attribute the complete workload")
    def paired(fn):
        return [speedup(fn(rows["B1"]), fn(rows["C1"])),
                speedup(fn(rows["B2"]), fn(rows["C2"]))]
    def group(fn):
        changes = paired(fn)
        return {
            "base_median": median([fn(rows["B1"]), fn(rows["B2"])]),
            "candidate_median": median([fn(rows["C1"]), fn(rows["C2"])]),
            "pair_speedup_pct": changes, "median_pair_speedup_pct": median(changes),
        }
    stage = {key: group(lambda row, k=key: row["_profile_means_ms_per_tick"][k])
             for key in rows["B1"]["_profile_means_ms_per_tick"]}
    wall = {metric: {p: group(lambda row, m=metric, q=p: float(row[m][q]))
                     for p in ("p50_ms", "p95_ms")} for metric in METRICS}
    # A zero reference count is an important result: this workload repeatedly
    # falls back to reference gas topology and never reuses its gas cache.
    # Do not divide by zero or manufacture a "speedup" for a 0/0 comparison.
    def work_group(field: str) -> dict:
        values = {name: float(row["_profile_delta"][field]) / row["_profile_ticks"]
                  for name, row in rows.items()}
        changes = []
        for bname, cname in (("B1", "C1"), ("B2", "C2")):
            before, after = values[bname], values[cname]
            if before == 0:
                changes.append(0.0 if after == 0 else None)
            else:
                changes.append((before - after) / before * 100.0)
        valid = [x for x in changes if x is not None]
        return {
            "baseline_per_tick": median([values["B1"], values["B2"]]),
            "candidate_per_tick": median([values["C1"], values["C2"]]),
            "paired_work_reduction_percent": changes,
            "median_work_reduction_percent": median(valid) if valid else None,
            "zero_baseline": values["B1"] == 0 or values["B2"] == 0,
            "interpretation": "counts, not elapsed time; 0/0 is unchanged zero work",
        }
    work = {k: work_group(k) for k in WORK}
    gas_share = group(lambda row: row["_gas_process_cpu_share_percent"])
    b = stage["native_process_cpu"]["base_median"]
    c = stage["native_process_cpu"]["candidate_median"]
    report = {
        "schema": "pf504-full-workbench-gas-stage-process-cpu-v1",
        "status": "CPU_STAGE_BRACKET_PROFILE_COMPLETE_PHYSICAL_HASH_UNQUALIFIED",
        "accepted_control": BASE, "optimized_candidate": CANDIDATE,
        "source_built_runtime_sha256": builds,
        "profiling_overlay": overlay,
        "original_full_stress_workbench": {
            "name": "workbench_setup.gd::stress_canvas",
            "size": [2048, 1024], "actual_rapier_barrels": 8,
            "water": "gas-enabled pressure_flow_v1/cached_dormant C2048",
            "ballistic_face_jet_spray": True,
            "warmup_native_ticks": 24, "measured_native_ticks": 240,
            "hard_edit_interval_ticks": 2, "run_order": [q[0] for q in ORDER],
        },
        "process_cpu_stage_ms_per_actual_native_tick": stage,
        "native_snapshot_wall_ms": wall,
        "gas_cpu_fraction_of_native_process_cpu_percent": gas_share,
        "gas_work_per_tick": work,
        "original_reports": rows,
        "limitations": [
            "std::clock on Linux measures PROCESS CPU time of all application threads during bracketed gas/head/tick intervals; unrelated main/render threads can contribute",
            "gas_nanoseconds, head_nanoseconds and simulation_time_ms are wall clocks, never mislabeled CPU",
            "the profiling-only C++ overlay adds clock measurements and copied GDScript counters to BOTH source builds; these instrumented results are not byte-identical uninstrumented 2.1686% benchmark",
            "ordinary asynchronous actor and jet motion is not a deterministic lockstep replay, so gas-work differences might reflect some divergent scene state",
            "native physical-state hash and complete Water/gas conservation are not established by this profiling experiment",
            "four workbench executions are not sufficient for general performance admission; no #504 merge or factorial authorized",
        ],
    }
    out = root / "gas-stage-cpu-profile.json"
    out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("PF504_GAS_PROCESS_CPU_PROFILE_PASS",
          "native_process_cpu_speedup_pct", round(speedup(b, c), 4),
          "gas_process_cpu_speedup_pct", round(stage["gas_process_cpu"]["median_pair_speedup_pct"], 4),
          "gas_process_cpu_share_base_pct", round(gas_share["base_median"], 4),
          "workbench_wall_tick_p50_speedup_pct", round(wall["simulation"]["p50_ms"]["median_pair_speedup_pct"], 4))
    return report


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: pf504_gas_cpu_readback.py <evidence-directory>")
    compare(Path(sys.argv[1]))
