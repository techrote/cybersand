#!/usr/bin/env python3
"""Build/fence, run and reduce the registered #201 PressureFlow idle-cost cohort.

Reuses the LCB-002 total-cost runner's source fence, process inventory, PE
stack reader and its unchanged ``validate_rows`` reducer for the small-scale
profiles. All outputs must be outside the checkout.

  python tools/lcb/pressure_idle_cost.py build --plan PLAN --core-head SHA --compiler CXX --out DIR
  python tools/lcb/pressure_idle_cost.py run --plan PLAN --build DIR/build.json --cohort windows|linux --out DIR
  python tools/lcb/pressure_idle_cost.py reduce --plan PLAN --runs DIR [--runs DIR ...] --out SUMMARY

No speedup threshold is applied; slower arms, fallbacks and failures are kept.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pressure_optimization_cost as lcb002  # noqa: E402  (reused fences and reducer)

ROOT = lcb002.ROOT
SCALE_BENCH = ROOT / "native/bench/lcb201_pressure_idle_cost.cpp"
SMALL_BENCH = lcb002.BENCH
SCHEMA = "lcb201-idle-cost-plan-v1"
SCALE_PROFILES = ("pool-vented", "pool-sealed", "pool-sealed-remote-gas",
                  "pool-vented-moving-mask", "pool-vented-boundary-churn")
SMALL_PROFILES = ("awake-boxed-water", "ordinary-sleeping-water", "continuous-topology-churn")
ARMS = ("reference", "cached", "dormant", "freemass")
PHASES = {"cold": 8, "settle": 56, "quiet": 96, "tail": 96}
COUNTERS = ("preparation_nanoseconds", "gas_nanoseconds", "head_nanoseconds", "water_material_calls",
            "water_motion_calls", "other_liquid_calls", "certificate_attempts", "certificate_reuses",
            "certificate_saved_calls", "certificate_declines", "certificate_suspended_ticks",
            "certificate_work_suspensions", "certificate_cold_reset_cells",
            "gas_reference_passes", "gas_reuses", "gas_seed_cells", "gas_seed_probes", "gas_bfs_cells",
            "gas_relabel_cells", "gas_component_reuses", "gas_restart_fallbacks", "columns_recomputed",
            "rows_recomputed", "base_cells_written", "final_cells_written", "reference_fallbacks",
            "index_rebuilds", "invalidation_rects", "certificate_invalidation_cells")


def fence() -> dict[str, str]:
    inputs = lcb002.fence()
    inputs[SCALE_BENCH.relative_to(ROOT).as_posix()] = lcb002.digest(SCALE_BENCH)
    return dict(sorted(inputs.items()))


def registration(path: Path) -> dict:
    plan = json.loads(path.read_text(encoding="utf-8"))
    scale, small = plan["scale_apparatus"], plan["small_scale_apparatus"]
    if (plan.get("schema") != SCHEMA or tuple(p["id"] for p in scale["profiles"]) != SCALE_PROFILES or
            tuple(scale["arms"]) != ARMS or scale["phase_ticks"] != PHASES or scale["workers"] != [1, 4] or
            scale["replicates"] != 3 or tuple(small["profiles"]) != SMALL_PROFILES or small["replicates"] != 3):
        raise ValueError("plan differs from the registered #201 idle-cost cohort")
    return {"path": str(path.resolve()), "sha256": lcb002.digest(path), "value": plan}


def compile_command(compiler: Path, bench: Path, binary: Path) -> list[str]:
    command = [str(compiler), "-std=c++20", "-O3", "-DNDEBUG", "-pthread", "-Wall", "-Wextra", "-Wpedantic",
               "-Inative/include", *["native/src/" + name for name in lcb002.CORE], str(bench), "-o", str(binary)]
    return command + (["-lpsapi"] if os.name == "nt" else [])


def build(args: argparse.Namespace, plan: dict) -> None:
    out = lcb002.outside(args.out)
    out.mkdir(parents=True, exist_ok=False)
    compiler = args.compiler.resolve()
    if lcb002.git("rev-parse", "HEAD") != args.core_head:
        raise ValueError("HEAD is not the explicitly sealed core")
    before = fence()
    lcb002.write(out / "inputs-before.json", before)
    suffix = ".exe" if os.name == "nt" else ""
    targets = {"scale": (SCALE_BENCH, out / ("lcb201_pressure_idle_cost" + suffix)),
               "small": (SMALL_BENCH, out / ("lcb_pressure_optimization" + suffix))}
    commands = {name: compile_command(compiler, bench, binary) for name, (bench, binary) in targets.items()}
    lcb002.write(out / "commands.json", commands)
    start = time.perf_counter()
    processes = {name: subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                 for name, command in commands.items()}
    exits = {}
    for name, process in processes.items():
        stdout, stderr = process.communicate(timeout=600)
        (out / f"build-{name}.stdout.log").write_bytes(stdout)
        (out / f"build-{name}.stderr.log").write_bytes(stderr)
        exits[name] = process.returncode
    after = fence()
    lcb002.write(out / "inputs-after.json", after)
    result = {"schema": "lcb201-idle-cost-build-v1", "utc": lcb002.utc(), "head": args.core_head,
              "tree": lcb002.git("rev-parse", "HEAD^{tree}"), "status_porcelain": lcb002.git("status", "--porcelain"),
              "registration": plan, "host": platform.platform(), "commands": commands, "compiler": str(compiler),
              "compiler_sha256": lcb002.digest(compiler),
              "compiler_version": subprocess.check_output([str(compiler), "--version"], text=True, encoding="utf-8"),
              "exits": exits, "seconds": time.perf_counter() - start, "inputs": before, "fence_unchanged": before == after,
              "runner_sha256": lcb002.digest(Path(__file__)), "lcb002_runner_sha256": lcb002.digest(Path(lcb002.__file__)),
              "binaries": {name: {"path": str(binary), "sha256": lcb002.digest(binary) if binary.exists() else None,
                                  "pe_stack": lcb002.pe_stack(binary) if binary.exists() else None}
                           for name, (_, binary) in targets.items()}}
    lcb002.write(out / "build.json", result)
    if any(exits.values()) or before != after:
        raise RuntimeError(f"build refused; preserved logs under {out}")
    print(json.dumps({"build": str(out / "build.json"), "binaries": {k: v["sha256"] for k, v in result["binaries"].items()}}))


def schedule(plan: dict, cohort: str) -> list[tuple[str, str, int, int, int]]:
    """Ordered (apparatus, profile, workers, replicate, timeout) children."""
    children = []
    if cohort == "windows":
        for apparatus, key, profiles in (("scale", "scale_apparatus", SCALE_PROFILES),
                                         ("small", "small_scale_apparatus", SMALL_PROFILES)):
            section = plan[key]
            for replicate in range(section["replicates"]):
                rotated = profiles[replicate % len(profiles):] + profiles[:replicate % len(profiles)]
                for profile in rotated:
                    for workers in ([1, 4] if replicate % 2 == 0 else [4, 1]):
                        children.append((apparatus, profile, workers, replicate, section["timeout_seconds"]))
    elif cohort == "linux":
        section = plan["platform_check"]
        for profile in section["profiles"]:
            for workers in section["workers"]:
                children.append(("scale", profile, workers, 0, section["timeout_seconds"]))
    else:
        raise ValueError("unknown cohort")
    return children


def run(args: argparse.Namespace, plan: dict) -> None:
    out = lcb002.outside(args.out)
    out.mkdir(parents=True, exist_ok=False)
    proof = json.loads(args.build.read_text(encoding="utf-8"))
    if (proof["schema"] != "lcb201-idle-cost-build-v1" or any(proof["exits"].values()) or not proof["fence_unchanged"] or
            proof["registration"]["sha256"] != plan["sha256"] or proof["runner_sha256"] != lcb002.digest(Path(__file__)) or
            proof["inputs"] != fence() or proof["head"] != lcb002.git("rev-parse", "HEAD") or
            any(lcb002.digest(Path(b["path"])) != b["sha256"] for b in proof["binaries"].values())):
        raise ValueError("binary/source/runner/registration differs from the fenced build")
    children = schedule(plan["value"], args.cohort)
    lcb002.write(out / "schedule.json", children)
    lcb002.write(out / "inputs-before.json", fence())
    lcb002.write(out / "host-load-before.json", lcb002.process_inventory())
    environment = os.environ.copy()
    environment["PATH"] = str(Path(proof["compiler"]).parent) + os.pathsep + environment.get("PATH", "")
    records = []
    for apparatus, profile, workers, replicate, timeout in children:
        binary = Path(proof["binaries"][apparatus]["path"])
        if lcb002.digest(binary) != proof["binaries"][apparatus]["sha256"]:
            raise ValueError("executable changed during campaign")
        name = f"{apparatus}-{profile}-w{workers}-r{replicate}"
        command = [str(binary), profile, str(workers), str(replicate)]
        start = time.perf_counter()
        try:
            process = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True, timeout=timeout)
            stdout, stderr, code = process.stdout, process.stderr, process.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr, code = error.stdout or b"", error.stderr or b"", "timeout"
        seconds = time.perf_counter() - start
        (out / (name + ".jsonl")).write_bytes(stdout)
        (out / (name + ".stderr.log")).write_bytes(stderr)
        lcb002.write(out / (name + ".result.json"), {"command": command, "exit": code, "seconds": seconds, "timeout": timeout})
        records.append({"name": name, "apparatus": apparatus, "profile": profile, "workers": workers,
                        "replicate": replicate, "exit": code, "seconds": seconds,
                        "jsonl_sha256": lcb002.digest(out / (name + ".jsonl"))})
        lcb002.write(out / "completed-runs.json", records)
        if code != 0 or stderr:
            raise RuntimeError(f"child failed: {name}; all raw output retained")
        print(f"completed {name} {seconds:.1f}s", flush=True)
    after = fence()
    lcb002.write(out / "inputs-after.json", after)
    lcb002.write(out / "host-load-after.json", lcb002.process_inventory())
    if after != proof["inputs"]:
        raise ValueError("source changed during campaign; raw measurements are unqualified")
    lcb002.write(out / "cohort.json", {"schema": "lcb201-idle-cost-cohort-v1", "utc": lcb002.utc(), "cohort": args.cohort,
        "host": platform.platform(), "build_receipt_sha256": lcb002.digest(args.build), "binaries": proof["binaries"],
        "head": proof["head"], "children": len(records), "source_fence_unchanged": True})


def quantile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(q * (len(ordered) - 1) + 0.5))]


def reduce_scale(rows: list[dict], profile: str, workers: int, replicate: int) -> dict:
    header, complete = rows[0], rows[-1]
    if (header.get("schema") != "lcb201-idle-cost-v1" or header.get("profile") != profile or
            header.get("workers") != workers or header.get("replicate") != replicate or
            header.get("phase_ticks") != list(PHASES.values()) or complete.get("event") != "complete" or complete.get("valid") is not True):
        raise ValueError(f"scale child header/completion differs: {profile} w{workers} r{replicate}")
    ticks = [row for row in rows if row.get("event") == "tick"]
    if {(r["arm"], r["tick"]) for r in ticks} != {(a, t) for a in ARMS for t in range(1, sum(PHASES.values()) + 1)} or len(ticks) != 4 * 256:
        raise ValueError("incomplete raw tick matrix")
    projections = {}
    for row in ticks:
        if row["arm"] == "freemass":
            continue
        head = row.get("prepared_head")
        if head is not None and (head["status_mismatches"] or head["nonzero_errors"] or head["unresolved_cells"]):
            raise ValueError("prepared head discrepancy")
        if projections.setdefault(row["tick"], row["projection"]) != row["projection"]:
            raise ValueError("pressure-variant projection mismatch in raw rows")
    out = {"profile": profile, "workers": workers, "replicate": replicate, "peak_rss_bytes": complete["peak_rss_bytes"],
           "max_observed_participants": dict(zip(ARMS, complete["max_observed_participants"])),
           "setup": {r["arm"]: {"prepare_ns": r["prepare_ns"], "resident_chunks": r["resident_chunks"],
                                "derived_capacity_bytes": r["memory"]["derived_capacity_bytes"],
                                "certificate_buffer_capacity_bytes": r["memory"]["certificate_buffer_capacity_bytes"],
                                "worker_counter_capacity_bytes": r["memory"]["worker_counter_capacity_bytes"]}
                     for r in rows if r.get("event") == "setup"},
           "phases": {}}
    for phase in PHASES:
        out["phases"][phase] = {}
        for arm in ARMS:
            group = [r for r in ticks if r["arm"] == arm and r["phase"] == phase]
            ms = [r["tick_ns"] / 1e6 for r in group]
            mean = lambda key: sum(r["counter_delta"][key] for r in group) / len(group)  # noqa: E731
            out["phases"][phase][arm] = {
                "ticks": len(group), "p50_ms": quantile(ms, .5), "p95_ms": quantile(ms, .95),
                "p99_ms": quantile(ms, .99), "max_ms": max(ms), "mean_ms": sum(ms) / len(ms), "total_ms": sum(ms),
                "mean_counters": {key: mean(key) for key in COUNTERS},
                "mean_visited_cells": sum(r["visited_cells"] for r in group) / len(group),
                "mean_moved_cells": sum(r["moved_cells"] for r in group) / len(group),
                "mean_phase_jobs": sum(sum(r["phase_jobs"]) for r in group) / len(group),
                "max_phase_jobs": max(sum(r["phase_jobs"]) for r in group),
                "max_claimants": max(r["worker_threads_observed"] for r in group),
                "ticks_with_jobs": sum(1 for r in group if sum(r["phase_jobs"])),
                "chunk_allocations": sum(r["chunk_allocations"] for r in group),
                "body_contacts_max": max(r["body_contacts"] for r in group),
                "woken_blocks": sum(r["pressure_diagnostics"]["woken_blocks"] for r in group),
                "gas_compartments_end": group[-1]["gas_compartments"], "overfill_end": group[-1]["overfill"]}
    return out


def reduce(args: argparse.Namespace, plan: dict) -> None:
    summary = {"schema": "lcb201-idle-cost-summary-v1", "utc": lcb002.utc(), "registration_sha256": plan["sha256"],
               "cohorts": [], "scale": [], "small": [], "comparisons": []}
    for folder in args.runs:
        folder = folder.resolve()
        cohort = json.loads((folder / "cohort.json").read_text(encoding="utf-8"))
        completed = json.loads((folder / "completed-runs.json").read_text(encoding="utf-8"))
        if len(completed) != cohort["children"]:
            raise ValueError("incomplete cohort")
        summary["cohorts"].append({"folder": folder.name, **{k: cohort[k] for k in ("cohort", "host", "head", "children", "binaries")}})
        for record in completed:
            raw = folder / (record["name"] + ".jsonl")
            if lcb002.digest(raw) != record["jsonl_sha256"]:
                raise ValueError("raw child output changed after the run")
            rows = [json.loads(line) for line in raw.read_text(encoding="utf-8").splitlines()]
            if record["apparatus"] == "scale":
                result = reduce_scale(rows, record["profile"], record["workers"], record["replicate"])
                result["cohort"] = cohort["cohort"]
                summary["scale"].append(result)
            else:
                result = lcb002.validate_rows(rows, record["profile"], "none", record["workers"], record["replicate"])
                summary["small"].append({"cohort": cohort["cohort"], "profile": record["profile"], "workers": record["workers"],
                    "replicate": record["replicate"], "tick_phase_total_ns": result["tick_phase_total_ns"],
                    "peak_rss_bytes": result["complete"]["peak_rss_bytes"],
                    "max_observed_participants": result["complete"]["max_observed_participants"]})
    for cohort in sorted({r["cohort"] for r in summary["scale"]}):
        for profile in SCALE_PROFILES:
            for workers in (1, 4):
                group = [r for r in summary["scale"] if (r["cohort"], r["profile"], r["workers"]) == (cohort, profile, workers)]
                if not group:
                    continue
                for phase in PHASES:
                    entry = {"cohort": cohort, "profile": profile, "workers": workers, "phase": phase, "replicates": len(group)}
                    for stat in ("p50_ms", "p95_ms", "p99_ms", "max_ms", "mean_ms"):
                        entry[stat] = {arm: statistics.median(r["phases"][phase][arm][stat] for r in group) for arm in ARMS}
                    entry["median_total_ratio_to_reference"] = {arm: statistics.median(
                        r["phases"][phase][arm]["total_ms"] / r["phases"][phase]["reference"]["total_ms"] for r in group) for arm in ARMS[1:]}
                    entry["median_mean_counters"] = {arm: {key: statistics.median(r["phases"][phase][arm]["mean_counters"][key] for r in group)
                                                           for key in COUNTERS} for arm in ARMS[:3]}
                    entry["max_claimants"] = {arm: max(r["phases"][phase][arm]["max_claimants"] for r in group) for arm in ARMS}
                    entry["ticks_with_jobs"] = {arm: max(r["phases"][phase][arm]["ticks_with_jobs"] for r in group) for arm in ARMS}
                    summary["comparisons"].append(entry)
    for cohort in sorted({r["cohort"] for r in summary["small"]}):
        for profile in SMALL_PROFILES:
            for workers in (1, 4):
                group = [r for r in summary["small"] if (r["cohort"], r["profile"], r["workers"]) == (cohort, profile, workers)]
                for phase in lcb002.PHASES:
                    summary["comparisons"].append({"cohort": cohort, "apparatus": "lcb002", "profile": profile, "workers": workers,
                        "phase": phase, "replicates": len(group),
                        "median_total_ms": {a: statistics.median(r["tick_phase_total_ns"][a][phase] / 1e6 for r in group) for a in lcb002.ARMS},
                        "median_total_ratio_to_reference": {a: statistics.median(r["tick_phase_total_ns"][a][phase] /
                            r["tick_phase_total_ns"]["reference"][phase] for r in group) for a in lcb002.ARMS[1:]}})
    args.out.write_text(json.dumps(summary, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"summary": str(args.out), "sha256": lcb002.digest(args.out)}))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="action", required=True)
    for action in ("build", "run", "reduce"):
        sub = commands.add_parser(action)
        sub.add_argument("--plan", required=True, type=Path)
        if action == "build":
            sub.add_argument("--compiler", required=True, type=Path)
            sub.add_argument("--core-head", required=True)
            sub.add_argument("--out", required=True, type=Path)
        if action == "run":
            sub.add_argument("--build", required=True, type=Path)
            sub.add_argument("--cohort", required=True, choices=("windows", "linux"))
            sub.add_argument("--out", required=True, type=Path)
        if action == "reduce":
            sub.add_argument("--runs", required=True, type=Path, action="append")
            sub.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    try:
        plan = registration(args.plan)
        {"build": build, "run": run, "reduce": reduce}[args.action](args, plan)
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError, KeyError) as error:
        print(f"#201 idle-cost cohort refused: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
