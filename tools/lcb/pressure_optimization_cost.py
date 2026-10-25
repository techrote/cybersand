#!/usr/bin/env python3
"""Build/fence and run the registered LCB-002 six-profile total-cost campaign.

Examples (all outputs must be outside the checkout):
  python tools/lcb/pressure_optimization_cost.py inspect --plan PATH
  python tools/lcb/pressure_optimization_cost.py build --plan PATH --core-head SHA --compiler PATH --out DIR
  python tools/lcb/pressure_optimization_cost.py run --plan PATH --build DIR/build.json --out DIR/results

Run --qualification-only first to exercise every fixture/worker/subcase once.
That output is explicitly not the five-replicate campaign. No speedup threshold
is applied: slower arms, sleeping negatives and fallback costs are retained.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import struct
import subprocess
import sys
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
BENCH = ROOT / "native/bench/lcb_pressure_optimization.cpp"
PROFILES = (
    "awake-boxed-water", "ordinary-sleeping-water", "two-sealed-rooms-local-change",
    "remote-gas-and-moving-mask", "continuous-topology-churn", "explicit-capacity-budget-fallback",
)
FALLBACKS = ("index", "head", "member", "pair")
ARMS = ("reference", "cached", "dormant")
EXECUTION = 3
CERTIFICATE_WORK_MODEL = {
    "id": "certificate_work_credits_v1", "trial_ticks": 8, "suspension_ticks": 32,
    "warmup_visits": 1, "backoff_visits": 8,
    "invalidation_charge": 1, "proof_charge": 40, "reuse_charge": 1, "saved_call_credit": 8,
}
PHASES = {"cold": 8, "warm": 48, "disturbed": 32}
CORE = ["world.cpp", "material_rules.cpp", "scheduler_geometry.cpp",
        "settled_world_discovery.cpp", "render_snapshot.cpp", "c_api.cpp"]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, encoding="utf-8").strip()


def outside(path: Path) -> Path:
    path = path.resolve()
    if path == ROOT or ROOT in path.parents:
        raise ValueError("benchmark outputs must be outside the source checkout")
    return path


def fence() -> dict[str, str]:
    paths = {BENCH}
    for folder in (ROOT / "native/include", ROOT / "native/src"):
        paths.update(p for p in folder.rglob("*") if p.is_file() and p.suffix in {".h", ".hpp", ".cpp", ".inc"})
    paths.update(ROOT / p for p in (
        "third_party/native-toolchain.lock.json", "docs/reference/liquid-solver-capability-matrix.json",
    ))
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(paths)}


def process_inventory() -> dict:
    """Read names and CPU totals only; never collect process command lines."""
    if os.name == "nt":
        command = ["powershell", "-NoProfile", "-Command",
                   "Get-Process | Select-Object Id,ProcessName,CPU | ConvertTo-Json -Compress"]
        result = subprocess.run(command, capture_output=True, timeout=20)
        return {"utc": utc(), "exit": result.returncode, "names_and_cpu_seconds":
                json.loads(result.stdout.decode("utf-8-sig")) if result.returncode == 0 else None}
    proc = Path("/proc")
    return {"utc": utc(), "process_names": {p.name: (p / "comm").read_text().strip()
            for p in proc.iterdir() if p.name.isdigit() and (p / "comm").is_file()} if proc.is_dir() else None}


def pe_stack(binary: Path) -> dict | None:
    data = binary.read_bytes()
    if data[:2] != b"MZ":
        return None
    optional = struct.unpack_from("<I", data, 0x3c)[0] + 24
    if struct.unpack_from("<H", data, optional)[0] != 0x20b:
        raise ValueError("expected the pinned x86_64 PE optional header")
    return {"reserve_bytes": struct.unpack_from("<Q", data, optional+72)[0],
            "commit_bytes": struct.unpack_from("<Q", data, optional+80)[0]}


def registration(path: Path) -> dict:
    plan = json.loads(path.read_text(encoding="utf-8-sig"))
    if (plan.get("schema") != "lcb002-total-optimization-cost-plan-v1" or
            tuple(p["id"] for p in plan["profiles"]) != PROFILES or
            plan["workers"] != [1, 4] or plan["replicates"] != 5):
        raise ValueError("plan differs from the registered six profiles / workers1,4 / five replicates")
    return {"path": str(path.resolve()), "sha256": digest(path), "value": plan}


def inspect(plan: dict) -> dict:
    text = BENCH.read_text(encoding="utf-8")
    if any('"' + profile + '"' not in text for profile in PROFILES):
        raise ValueError("native apparatus omits a registered profile")
    header = (ROOT / "native/include/cybersand/pressure_optimization.hpp").read_text(encoding="utf-8")
    bodies = [re.search(r"struct " + name + r"[^\{]*\{(.*?)\n\};", header, re.S).group(1)
              for name in ("PressureKernelWork", "PressureOptimizationCounters")]
    fields = {name for body in bodies for statement in body.split(";") if "std::uint64_t" in statement
              for name in re.findall(r"(\w+)\s*=", statement)}
    macro = text.split("#define LCB_OPT_COUNTERS(X)", 1)[1].split("\n\n", 1)[0]
    emitted = set(re.findall(r"X\((\w+)\)", macro))
    if fields != emitted:
        raise ValueError(f"counter emission differs: missing={fields-emitted}, extra={emitted-fields}")
    return {"schema": "lcb002-cost-apparatus-inspection-v2", "utc": utc(), "head": git("rev-parse", "HEAD"),
            "execution": EXECUTION, "benchmark_sha256": digest(BENCH), "runner_sha256": digest(Path(__file__)),
            "registration": plan, "profiles": PROFILES, "fallback_subcases": FALLBACKS,
            "phase_ticks": PHASES, "counter_fields": sorted(fields),
            "timing": "each complete tick only; edits/setup separately; one parity/head/ROI observation per World after all three timers",
            "head_measurement": "preallocated native chunk roster and maximum-admitted head buffers cover every actual resident cell; statuses match and numeric signed/absolute sums, maximum error and comparison count are recorded in Water mass units; last pre-kernel field may be stale after mutations",
            "boundary_measurement": "declared ROI Water end-start at zero host Water edits and zero tick Water source/sink counters; inferred NET boundary inflow only, not gross/per-face flux",
            "participants": "TickStats worker_threads_observed; max distinct task-claiming pool participants in any dispatch of that tick",
            "memory": "peak RSS is the process containing three simultaneous Worlds, pools and parity/apparatus; declared fields are partial capacities",
            "status": "static inspection only; not a compile, correctness or performance result"}


def build(args: argparse.Namespace, plan: dict) -> None:
    out = outside(args.out)
    out.mkdir(parents=True, exist_ok=False)
    compiler = args.compiler.resolve()
    if git("rev-parse", "HEAD") != args.core_head:
        raise ValueError("HEAD is not the explicitly sealed core")
    check = inspect(plan)
    before = fence()
    write(out / "inputs-before.json", before)
    write(out / "apparatus-inspection.json", check)
    suffix = ".exe" if os.name == "nt" else ""
    binary = out / ("lcb_pressure_optimization" + suffix)
    command = [str(compiler), "-std=c++20", "-O3", "-DNDEBUG", "-pthread", "-Wall", "-Wextra", "-Wpedantic",
               "-Inative/include", *["native/src/" + name for name in CORE], str(BENCH), "-o", str(binary)]
    if os.name == "nt":
        command.append("-lpsapi")
    write(out / "command.json", command)
    start = time.perf_counter()
    process = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=300)
    (out / "build.stdout.log").write_bytes(process.stdout)
    (out / "build.stderr.log").write_bytes(process.stderr)
    after = fence()
    write(out / "inputs-after.json", after)
    result = {"schema": "lcb002-cost-build-v2", "utc": utc(), "head": args.core_head, "source": str(ROOT),
              "execution": EXECUTION, "registration": plan, "host": platform.platform(), "command": command,
              "compiler": str(compiler), "compiler_sha256": digest(compiler),
              "compiler_version": subprocess.check_output([str(compiler), "--version"], text=True, encoding="utf-8"),
              "exit": process.returncode, "seconds": time.perf_counter()-start,
              "inputs": before, "fence_unchanged": before == after,
              "runner_sha256": digest(Path(__file__)), "binary": str(binary),
              "binary_sha256": digest(binary) if binary.exists() else None,
              "pe_stack": pe_stack(binary) if binary.exists() else None}
    write(out / "build.json", result)
    if process.returncode or before != after:
        raise RuntimeError(f"build refused; preserved logs under {out}")
    print(json.dumps({"build": str(out / "build.json"), "binary_sha256": result["binary_sha256"]}))


def validate_rows(rows: list[dict], profile: str, fallback: str, workers: int, replicate: int) -> dict:
    header = rows[0]
    if (header.get("event") != "header" or header.get("schema") != "lcb002-total-cost-v2" or header.get("execution") != EXECUTION or
            header.get("profile") != profile or header.get("fallback") != fallback or
            header.get("workers") != workers or header.get("replicate") != replicate or header.get("phase_ticks") != list(PHASES.values())):
        raise ValueError("native header differs from requested immutable profile")
    if header.get("certificate_work_model") != CERTIFICATE_WORK_MODEL:
        raise ValueError("certificate work model differs from prospective execution3 registration")
    boxed = profile in PROFILES[:2]
    domain = [0, 0, 128, 128] if boxed else [0, 0, 416, 24] if profile == PROFILES[4] else [0, 0, 88, 8]
    roi = [0, 0, 32, 128] if boxed else [0, 0, 8, 8]
    chunk_size = 32 if boxed else 8
    if (header.get("head_sample_domain_hint") != domain or header.get("head_coverage") != "copied_sorted_native_resident_chunk_roster" or header.get("boundary_flux_roi") != roi or
            header.get("chunk_size") != chunk_size):
        raise ValueError("head roster coverage declaration, authored domain hint or boundary-flux ROI differs from registration")
    if rows[-1].get("event") != "complete" or rows[-1].get("valid") is not True:
        raise ValueError("native apparatus did not complete all parity/opportunity checks")
    setups = [row for row in rows if row.get("event") == "setup"]
    if sorted(row["arm"] for row in setups) != sorted(ARMS):
        raise ValueError("expected exactly one setup per arm")
    total = {arm: {phase: 0 for phase in PHASES} for arm in ARMS}
    edits = {arm: {phase: 0 for phase in PHASES} for arm in ARMS}
    seen = set()
    head_totals = {arm: {phase: {"sampled_cells": 0, "resident_cells": 0, "prepared_cells": 0,
        "numeric_comparisons": 0, "absolute_error_sum": 0, "max_absolute_error": 0} for phase in PHASES} for arm in ARMS}
    boundary_totals = {arm: {phase: {"net_inflow": 0, "positive_net_ticks": 0, "negative_net_ticks": 0} for phase in PHASES} for arm in ARMS}
    paired = {}
    previous_roi_end = {}
    for row in rows:
        if row.get("event") != "tick":
            continue
        key = row["arm"], row["tick"]
        if key in seen or row["arm"] not in ARMS or row["phase"] not in PHASES or row["tick_ns"] < 0:
            raise ValueError("duplicate or invalid native timing row")
        seen.add(key)
        expected_phase = "cold" if row["tick"] <= 8 else "warm" if row["tick"] <= 56 else "disturbed"
        if row["phase"] != expected_phase or row["order_position"] != (ARMS.index(row["arm"])-replicate-row["tick"]+1) % 3:
            raise ValueError("phase boundary or rotated arm order differs from registration")
        head = row["prepared_head"]
        if (head["sampled_cells"] != head["resident_cells"] or
                head["resident_cells"] != row["memory"]["resident_chunks"]*chunk_size*chunk_size or
                head["resident_cells"] != head["prepared_cells"]+head["no_head_cells"] or
                head["numeric_comparisons"] != head["prepared_cells"] or
                any(head[key] != 0 for key in ("unresolved_cells", "status_mismatches", "nonzero_errors", "signed_error_sum", "absolute_error_sum", "max_absolute_error"))):
            raise ValueError("incomplete resident head coverage or prepared-field discrepancy")
        if head["prepared_cells"] and head["minimum_head"] > head["maximum_head"]:
            raise ValueError("invalid prepared head range")
        boundary = row["boundary_water"]
        if (any(boundary[key] != 0 for key in ("host_produced", "host_consumed", "tick_produced", "tick_consumed", "balance_residual")) or
                boundary["end_quantity"]-boundary["start_quantity"] != boundary["net_inflow"]):
            raise ValueError("ROI net boundary balance does not match declared zero-source measurement")
        if row["arm"] in previous_roi_end and boundary["start_quantity"] != previous_roi_end[row["arm"]]:
            raise ValueError("zero-host-edit ROI balance is discontinuous between ticks")
        previous_roi_end[row["arm"]] = boundary["end_quantity"]
        observation = {key: head[key] for key in ("sampled_cells", "resident_cells", "prepared_cells", "no_head_cells", "prepared_head_sum", "minimum_head", "maximum_head")}, boundary
        if row["tick"] in paired and paired[row["tick"]] != observation:
            raise ValueError("per-tick prepared field/ROI balance differs across pressure variants")
        paired[row["tick"]] = observation
        accumulated = head_totals[row["arm"]][row["phase"]]
        for field in accumulated:
            if field == "max_absolute_error": accumulated[field] = max(accumulated[field], head[field])
            else: accumulated[field] += head[field]
        flow = boundary_totals[row["arm"]][row["phase"]]
        flow["net_inflow"] += boundary["net_inflow"]
        flow["positive_net_ticks"] += boundary["net_inflow"] > 0
        flow["negative_net_ticks"] += boundary["net_inflow"] < 0
        total[row["arm"]][row["phase"]] += row["tick_ns"]
        edits[row["arm"]][row["phase"]] += row["edit_ns"]
    if seen != {(arm, tick) for arm in ARMS for tick in range(1, sum(PHASES.values())+1)}:
        raise ValueError("incomplete raw tick matrix")
    return {"profile": profile, "fallback": fallback, "workers": workers, "replicate": replicate,
            "tick_phase_total_ns": total, "edit_phase_total_ns": edits,
            "edit_plus_tick_phase_total_ns": {a: {p: total[a][p]+edits[a][p] for p in PHASES} for a in ARMS},
            "head_phase_metrics": head_totals, "boundary_phase_metrics": boundary_totals,
            "head_sample_domain_hint": domain, "head_coverage": header["head_coverage"], "boundary_flux_roi": roi, "setup": setups, "complete": rows[-1]}


def run(args: argparse.Namespace, plan: dict) -> None:
    out = outside(args.out)
    out.mkdir(parents=True, exist_ok=False)
    proof = json.loads(args.build.read_text(encoding="utf-8"))
    binary = Path(proof["binary"])
    if (proof["schema"] != "lcb002-cost-build-v2" or proof.get("execution") != EXECUTION or proof["exit"] or not proof["fence_unchanged"] or
            proof["registration"]["sha256"] != plan["sha256"] or proof["runner_sha256"] != digest(Path(__file__)) or
            proof["inputs"] != fence() or proof["head"] != git("rev-parse", "HEAD") or digest(binary) != proof["binary_sha256"]):
        raise ValueError("binary/source/runner/registration differs from the fenced optimized build")
    before = fence()
    write(out / "inputs-before.json", before)
    write(out / "host-load-before.json", process_inventory())
    cases = [(p, f) for p in PROFILES for f in (FALLBACKS if p == PROFILES[-1] else ("none",))]
    records = []
    environment = os.environ.copy()
    environment["PATH"] = str(Path(proof["compiler"]).parent) + os.pathsep + environment.get("PATH", "")
    for replicate in range(1 if args.qualification_only else 5):
        rotated = cases[replicate % len(cases):] + cases[:replicate % len(cases)]
        for profile, fallback in rotated:
            for workers in ([1, 4] if replicate % 2 == 0 else [4, 1]):
                if digest(binary) != proof["binary_sha256"]:
                    raise ValueError("optimized executable changed during campaign")
                name = f"{profile}-{fallback}-w{workers}-r{replicate}"
                command = [str(binary), profile, str(workers), str(replicate)] + ([] if fallback == "none" else [fallback])
                write(out / (name + ".command.json"), command)
                start = time.perf_counter()
                try:
                    process = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True, timeout=120)
                    stdout, stderr, code = process.stdout, process.stderr, process.returncode
                except subprocess.TimeoutExpired as error:
                    stdout, stderr, code = error.stdout or b"", error.stderr or b"", "timeout"
                (out / (name + ".jsonl")).write_bytes(stdout)
                (out / (name + ".stderr.log")).write_bytes(stderr)
                write(out / (name + ".result.json"), {"exit": code, "seconds": time.perf_counter()-start, "timeout": 120})
                if code != 0 or stderr:
                    raise RuntimeError(f"native qualification failed: {name}; all raw output retained")
                result = validate_rows([json.loads(line) for line in stdout.decode("utf-8").splitlines()], profile, fallback, workers, replicate)
                result["raw"] = name + ".jsonl"
                records.append(result)
                write(out / "completed-runs.json", records)
                print(f"completed {name}", flush=True)
    after = fence()
    write(out / "inputs-after.json", after)
    write(out / "host-load-after.json", process_inventory())
    if before != after or digest(binary) != proof["binary_sha256"]:
        raise ValueError("source or executable changed during campaign; raw measurements are unqualified")
    comparisons = []
    for profile, fallback in cases:
        for workers in (1, 4):
            group = [record for record in records if (record["profile"], record["fallback"], record["workers"]) == (profile, fallback, workers)]
            for phase in PHASES:
                raw = {arm: [r["tick_phase_total_ns"][arm][phase] for r in group] for arm in ARMS}
                ratios = {arm: [r["tick_phase_total_ns"][arm][phase] / r["tick_phase_total_ns"]["reference"][phase] for r in group] for arm in ARMS[1:]}
                comparisons.append({"profile": profile, "fallback": fallback, "workers": workers, "phase": phase,
                                    "raw_replicate_total_ns": raw, "median_total_ns": {arm: statistics.median(values) for arm, values in raw.items()},
                                    "candidate_over_reference_ratios": ratios,
                                    "median_ratio": {arm: statistics.median(values) for arm, values in ratios.items()},
                                    "edit_plus_tick_raw_replicate_total_ns": {a: [r["edit_plus_tick_phase_total_ns"][a][phase] for r in group] for a in ARMS},
                                    "edit_plus_tick_median_ratio": {a: statistics.median(r["edit_plus_tick_phase_total_ns"][a][phase] /
                                        r["edit_plus_tick_phase_total_ns"]["reference"][phase] for r in group) for a in ARMS[1:]}})
    artifacts = {p.name: {"bytes": p.stat().st_size, "sha256": digest(p)} for p in out.iterdir() if p.is_file()}
    write(out / "summary.json", {"schema": "lcb002-total-cost-campaign-v2", "utc": utc(), "head": proof["head"],
          "execution": EXECUTION, "status": "fixture qualification only" if args.qualification_only else "five rotated replicates complete",
          "build_receipt": str(args.build.resolve()), "build_receipt_sha256": digest(args.build),
          "binary_sha256": proof["binary_sha256"], "registration": plan, "source_fence_unchanged": True,
          "replicates": 1 if args.qualification_only else 5, "runs": len(records), "comparisons": comparisons,
          "head_and_boundary_metrics": [{"profile": r["profile"], "fallback": r["fallback"], "workers": r["workers"], "replicate": r["replicate"],
              "head_sample_domain_hint": r["head_sample_domain_hint"], "head_coverage": r["head_coverage"], "boundary_flux_roi": r["boundary_flux_roi"],
              "head_phase_metrics": r["head_phase_metrics"], "boundary_phase_metrics": r["boundary_phase_metrics"]} for r in records],
          "head_scope": "all resident final prepared head slots, copied outside timers; may be stale after transport/writes and are not authority",
          "boundary_scope": "inferred signed NET inflow from ROI Water balance at zero host/tick Water source/sink; not gross or per-face flux",
          "peak_rss_scope": "each child process contains three simultaneous Worlds/pools, parity observations and apparatus; not per-arm RSS",
          "ratio_scope": "candidate/reference total tick cost within each rotated replicate; ratios above1 are slower and are preserved",
          "participants_scope": "maximum distinct task-claiming pool threads in any single dispatch of a tick; not configured workers, union across phases, or sum across arms",
          "host_timing_scope": "local desktop host, uncontrolled background apps/scheduling; process-name/CPU inventories retained before and after; not isolated target performance",
          "artifacts": artifacts})
    print(json.dumps({"summary": str(out / "summary.json"), "sha256": digest(out / "summary.json")}))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="action", required=True)
    for action in ("inspect", "build", "run"):
        sub = commands.add_parser(action)
        sub.add_argument("--plan", required=True, type=Path)
        if action == "build":
            sub.add_argument("--compiler", required=True, type=Path)
            sub.add_argument("--core-head", required=True)
            sub.add_argument("--out", required=True, type=Path)
        if action == "run":
            sub.add_argument("--build", required=True, type=Path)
            sub.add_argument("--out", required=True, type=Path)
            sub.add_argument("--qualification-only", action="store_true")
    args = parser.parse_args()
    try:
        plan = registration(args.plan)
        if args.action == "inspect":
            print(json.dumps(inspect(plan), indent=2))
        elif args.action == "build":
            build(args, plan)
        else:
            run(args, plan)
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"LCB-002 cost campaign refused: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
