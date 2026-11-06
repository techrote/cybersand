#!/usr/bin/env python3
"""Paired, exact-source native World::tick qualification for PR #471.

Both detached worktrees compile the SAME neutral benchmark source with the same
g++-13 flags and link the four Makefile SIMULATION_SOURCES. All 600/1800 tick
outputs, native test logs, paired statistics and available perf samples survive
in --out. Never cherry-picks a harness into the baseline or modifies branch refs.
"""
import argparse
import csv
import hashlib
import json
import math
import os
import platform
import shlex
import shutil
import statistics
import subprocess
import sys
from pathlib import Path

from verify_neighbour_stress import check_fixture

ORIGINAL = "4a80af2a891332176a3912a235582d77d076a185"
SIMULATION_SOURCES = (
    "native/src/world.cpp",
    "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp",
    "native/src/settled_world_discovery.cpp",
)
# Six cycles: four configurations each cycle, balanced baseline/candidate order.
ORDERS = (
    (("baseline", 1), ("candidate", 1), ("candidate", 6), ("baseline", 6)),
    (("candidate", 1), ("baseline", 1), ("baseline", 6), ("candidate", 6)),
    (("baseline", 6), ("candidate", 6), ("candidate", 1), ("baseline", 1)),
    (("candidate", 6), ("baseline", 6), ("baseline", 1), ("candidate", 1)),
    (("baseline", 1), ("candidate", 1), ("candidate", 6), ("baseline", 6)),
    (("candidate", 6), ("baseline", 6), ("baseline", 1), ("candidate", 1)),
)
WORK_KEYS = ("visited", "moved", "cores", "active_blocks", "chunk_allocations",
             "temperature_field_allocations", "deferred_events", "dirty_chunks",
             "active_chunks_before", "active_chunks_after")


def sha_lf(path):
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run(cmd, *, cwd, log, env=None, check=True, timeout=1800):
    cmd = [str(part) for part in cmd]
    process = subprocess.run(cmd, cwd=cwd, env=env, text=True, errors="replace",
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             timeout=timeout, check=False)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("$ " + shlex.join(cmd) + "\n" + process.stdout +
                   "\nexit=" + str(process.returncode) + "\n", encoding="utf-8")
    if check and process.returncode:
        raise RuntimeError(f"exit={process.returncode}: {log}")
    return process


def records(path):
    with path.open(newline="", encoding="utf-8") as handle:
        result = list(csv.DictReader(handle))
    for number, row in enumerate(result, 1):
        if int(row["tick"]) != number:
            raise AssertionError(f"{path}: discontinuous tick at {number}")
    return result


def record_signature(row, csv_path):
    sampled = records(csv_path)
    if len(sampled) != row["ticks"]:
        raise AssertionError(f"{csv_path}: expected {row['ticks']} rows, got {len(sampled)}")
    if len(row["checkpoints"]) != row["ticks"] // 150:
        raise AssertionError("missing checkpoint hashes")
    times = [float(tick["ms"]) for tick in sampled]
    if not all(math.isfinite(t) and t > 0 for t in times):
        raise AssertionError("nonpositive/nonfinite World::tick duration")
    row["median_ms"] = statistics.median(times)
    row["mean_from_raw_ms"] = statistics.mean(times)
    row["std_tick_ms"] = statistics.stdev(times) if len(times) > 1 else 0.0
    row["min_ms"] = min(times)
    row["max_from_raw_ms"] = max(times)
    row["actual_workers_min"] = min(int(t["workers_observed"]) for t in sampled)
    row["actual_workers_max"] = max(int(t["workers_observed"]) for t in sampled)
    row["actual_workers_mean"] = statistics.mean(int(t["workers_observed"]) for t in sampled)
    row["last_active_blocks"] = int(sampled[-1]["active_blocks"])
    row["first_active_blocks"] = int(sampled[0]["active_blocks"])
    row["last_scheduled_cores"] = int(sampled[-1]["cores"])
    row["first_scheduled_cores"] = int(sampled[0]["cores"])
    row["observed_early_cores_mean"] = statistics.mean(
        int(t["cores"]) for t in sampled[:min(180, len(sampled))])
    row["observed_late_cores_mean"] = statistics.mean(
        int(t["cores"]) for t in sampled[-min(180, len(sampled)):])
    row["work_totals"] = {key: sum(int(t[key]) for t in sampled) for key in WORK_KEYS}
    row["phase_totals"] = {key: sum(int(t[key]) for t in sampled)
                            for key in sampled[0] if key.startswith("phase_jobs_")}
    # The observed participant count is NOT a deterministic work result.
    row["_semantic_signature"] = {
        "checkpoints": row["checkpoints"],
        "state_hash": row["state_hash"],
        "physical_state_hash": row["physical_state_hash"],
        "work_per_tick": [[t[key] for key in WORK_KEYS] +
                          [t[k] for k in sorted(t) if k.startswith("phase_jobs_")]
                          for t in sampled],
    }
    return row


def build_native(root, out, *, sanitizers=False, tsan=False):
    target = "build/tests_tsan" if tsan else ("build/tests_sanitized" if sanitizers else "build/tests")
    run(["make", "CXX=g++-13", target], cwd=root, log=out / ("build_" + target.split("/")[-1] + ".log"))
    return root / target


def benchmark_build(root, apparatus, out, verify=False):
    binary = out / ("neighbour_verify" if verify else "neighbour_bench")
    cmd = ["g++-13", "-std=c++20", "-O2", "-g", "-fno-omit-frame-pointer",
           "-pthread", "-I", root / "native/include"]
    if verify:
        cmd.append("-DCYBERSAND_VERIFY_LOCAL_NEIGHBOUR")
    cmd += [root / name for name in SIMULATION_SOURCES]
    cmd += [apparatus / "neighbour_cursor_bench.cpp", "-o", binary]
    run(cmd, cwd=root, log=out / ("compile_oracle.log" if verify else "compile.log"))
    return binary


def tick_run(binary, scene, workers, ticks, out, label, cwd):
    per_tick = out / (label + ".csv")
    result = run([binary, scene, workers, ticks, per_tick], cwd=cwd, log=out / (label + ".log"))
    try:
        row = json.loads(result.stdout.strip())
    except json.JSONDecodeError as exc:
        raise ValueError(f"{label}: invalid benchmark JSON") from exc
    if (row["workers"], row["ticks"], row["rectangles"]) != (workers, ticks, 129):
        raise AssertionError("benchmark returned wrong configuration")
    row = record_signature(row, per_tick)
    row["csv"] = str(per_tick)
    row["label"] = label
    row["binary"] = str(binary)
    return row


def compare_semantics(rows, extended):
    all_rows = rows + extended
    if not all_rows:
        raise AssertionError("no samples")
    expected = {}
    problems = []
    for row in all_rows:
        key = row["ticks"]
        signature = row["_semantic_signature"]
        if key not in expected:
            expected[key] = (row["label"], signature)
        elif signature != expected[key][1]:
            problems.append({"ticks": key, "row": row["label"], "reference": expected[key][0],
                             "hash_checkpoints_match": signature["checkpoints"] ==
                                 expected[key][1]["checkpoints"],
                             "full_state_match": (signature["state_hash"], signature["physical_state_hash"]) ==
                                 (expected[key][1]["state_hash"], expected[key][1]["physical_state_hash"]),
                             "work_per_tick_match": signature["work_per_tick"] ==
                                 expected[key][1]["work_per_tick"]})
    return problems


def metrics(rows, cycles):
    report = {}
    for workers in (1, 6):
        baseline = [r for r in rows if r["implementation"] == "baseline" and r["workers"] == workers]
        candidate = [r for r in rows if r["implementation"] == "candidate" and r["workers"] == workers]
        if len(baseline) != cycles or len(candidate) != cycles:
            raise AssertionError("missing balanced replicates")
        pairs = []
        for cycle in range(cycles):
            b = next(r for r in baseline if r["cycle"] == cycle)
            c = next(r for r in candidate if r["cycle"] == cycle)
            pairs.append(100 * (b["mean_from_raw_ms"] - c["mean_from_raw_ms"]) / b["mean_from_raw_ms"])
        avg, sd = statistics.mean(pairs), statistics.stdev(pairs)
        # Student-t 95% two-sided critical values for n=5..10, dof=n-1.
        t95 = {5: 2.776, 6: 2.571, 7: 2.447, 8: 2.365, 9: 2.306, 10: 2.262}[cycles]
        margin = t95 * sd / math.sqrt(cycles)
        report[str(workers)] = {
            "baseline_mean_tick_ms": statistics.mean(r["mean_from_raw_ms"] for r in baseline),
            "candidate_mean_tick_ms": statistics.mean(r["mean_from_raw_ms"] for r in candidate),
            "baseline_median_tick_ms": statistics.median(r["median_ms"] for r in baseline),
            "candidate_median_tick_ms": statistics.median(r["median_ms"] for r in candidate),
            "baseline_across_run_mean_std_ms": statistics.stdev(r["mean_from_raw_ms"] for r in baseline),
            "candidate_across_run_mean_std_ms": statistics.stdev(r["mean_from_raw_ms"] for r in candidate),
            "baseline_across_run_range_ms": [
                min(r["mean_from_raw_ms"] for r in baseline),
                max(r["mean_from_raw_ms"] for r in baseline)],
            "candidate_across_run_range_ms": [
                min(r["mean_from_raw_ms"] for r in candidate),
                max(r["mean_from_raw_ms"] for r in candidate)],
            "paired_speedups_pct": pairs,
            "paired_speedup_mean_pct": avg,
            "paired_speedup_std_pct": sd,
            "paired_speedup_95pct_ci_pct": [avg-margin, avg+margin],
            "statistically_positive": avg - margin > 0,
            "candidate_actual_workers_max": max(r["actual_workers_max"] for r in candidate),
            "baseline_actual_workers_max": max(r["actual_workers_max"] for r in baseline),
        }
    return report


def maybe_profile(binary, scene, cwd, out, label):
    profiler = shutil.which("perf")
    if not profiler:
        return {"status": "unavailable", "reason": "perf not installed"}
    capture = run(["perf", "record", "--call-graph", "fp", "-F", "199",
                   "-o", out / (label + ".perf.data"), "--", binary, scene, 6, 600],
                  cwd=cwd, log=out / (label + "_perf_record.log"), check=False)
    if capture.returncode:
        return {"status": "blocked", "reason": f"perf record exit={capture.returncode}; see log"}
    outputs = {}
    for kind, sort in (("functions", "symbol"), ("lines", "symbol,srcline")):
        analysis = run(["perf", "report", "-i", out / (label + ".perf.data"),
                        "--stdio", "--no-children", "-n", "--sort", sort],
                       cwd=cwd, log=out / (label + "_perf_" + kind + ".log"), check=False)
        outputs[kind] = {"status": "pass" if analysis.returncode == 0 else "failed",
                         "log": str(out / (label + "_perf_" + kind + ".log"))}
    return {"status": "recorded", "reports": outputs}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=Path, default=Path("."))
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--baseline", default=ORIGINAL)
    ap.add_argument("--candidate", default="HEAD")
    ap.add_argument("--cycles", type=int, default=6)
    ap.add_argument("--extended", action="store_true")
    ap.add_argument("--native-tests", action="store_true")
    ap.add_argument("--sanitizers", action="store_true")
    ap.add_argument("--tsan", action="store_true")
    ap.add_argument("--verify-cursor", action="store_true")
    ap.add_argument("--no-perf", action="store_true")
    opts = ap.parse_args()
    if opts.cycles < 5 or opts.cycles > 10:
        ap.error("minimum 5, maximum 10 balanced cycles")
    if not shutil.which("g++-13"):
        ap.error("g++-13 required: this harness will not substitute another compiler")
    root, out = opts.repo.resolve(), opts.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = root / "native/bench"
    if not (source / "neighbour_cursor_bench.cpp").is_file():
        ap.error("--repo must refer to the candidate source checkout")
    info = {"os": platform.platform(), "cpu_count": os.cpu_count(),
            "cpu_model": next((ln.partition(":")[2].strip()
                               for ln in Path("/proc/cpuinfo").read_text().splitlines()
                               if ln.startswith("model name")), "unknown"),
            "compiler": run(["g++-13", "--version"], cwd=root, log=out / "compiler.log").stdout.splitlines()[0],
            "run_parameters": vars(opts)}
    info["requested_baseline"] = opts.baseline
    info["requested_candidate"] = opts.candidate
    heads = {}
    for kind, ref in (("baseline", opts.baseline), ("candidate", opts.candidate)):
        head = run(["git", "rev-parse", f"{ref}^{{commit}}"], cwd=root,
                   log=out / (kind + "_revision.log")).stdout.strip()
        heads[kind] = head
    info["heads"] = heads
    save(out / "machine.json", info)

    trees = {}
    for kind in ("baseline", "candidate"):
        worktree = out / ("worktree_" + kind)
        if worktree.exists():
            raise RuntimeError(f"refusing to replace existing worktree: {worktree}")
        run(["git", "worktree", "add", "--detach", worktree, heads[kind]],
            cwd=root, log=out / ("worktree_" + kind + ".log"))
        trees[kind] = worktree
    for name in ("godot/scripts/workbench_setup.gd",):
        hashes = {kind: sha_lf(wt / name) for kind, wt in trees.items()}
        if hashes["baseline"] != hashes["candidate"]:
            raise AssertionError(f"non-identical Godot scene in baseline and candidate: {hashes}")

    # Use precisely one apparatus byte stream outside either worktree.
    apparatus = out / "apparatus"
    apparatus.mkdir(exist_ok=False)
    for name in ("neighbour_cursor_bench.cpp", "data/neighbour_stress_rectangles.txt"):
        src = source / name
        dst = apparatus / Path(name).name
        shutil.copyfile(src, dst)
    fixture = check_fixture(apparatus / "neighbour_stress_rectangles.txt",
                            trees["candidate"] / "godot/scripts/workbench_setup.gd")
    save(out / "fixture_verification.json", fixture)
    if not fixture["pass"]:
        raise AssertionError("stress fixture differs from authored GDScript")
    info["apparatus_sha256"] = {
        "cpp": sha_lf(apparatus / "neighbour_cursor_bench.cpp"),
        "fixture": sha_lf(apparatus / "neighbour_stress_rectangles.txt"),
    }
    save(out / "machine.json", info)

    if opts.native_tests:
        for kind, tree in trees.items():
            binary = build_native(tree, out / ("native_" + kind))
            run([binary], cwd=tree, log=out / ("native_" + kind) / "full_suite.log")
    if opts.sanitizers:
        binary = build_native(trees["candidate"], out / "asan_ubsan", sanitizers=True)
        env = os.environ.copy()
        env.update(ASAN_OPTIONS="detect_leaks=1:halt_on_error=1", UBSAN_OPTIONS="halt_on_error=1")
        run([binary], cwd=trees["candidate"], log=out / "asan_ubsan" / "full_suite.log", env=env)
    tsan_results = []
    if opts.tsan:
        binary = build_native(trees["candidate"], out / "tsan", tsan=True)
        for fragment in ("complete material worker parity", "determinism", "phased",
                         "explosion worker parity", "Workbench parallel PressureFlow heads",
                         "Water IN real workers", "BW-001 ballistic Water persistence"):
            log = out / "tsan" / (fragment.replace(" ", "_") + ".log")
            result = run([binary, fragment], cwd=trees["candidate"], log=log, check=False)
            tsan_results.append({"filter": fragment, "exit": result.returncode,
                                 "log": str(log)})
        save(out / "tsan" / "result.json", tsan_results)

    binaries = {kind: benchmark_build(tree, apparatus, out / kind)
                for kind, tree in trees.items()}
    scene = apparatus / "neighbour_stress_rectangles.txt"
    runs = []
    for cycle in range(opts.cycles):
        for position, (kind, workers) in enumerate(ORDERS[cycle % len(ORDERS)]):
            label = f"r{cycle+1:02d}_p{position+1}_{kind}_{workers}w_600"
            row = tick_run(binaries[kind], scene, workers, 600, out / "raw",
                           label, trees[kind])
            row["implementation"], row["cycle"], row["position"] = kind, cycle, position
            runs.append(row)
            save(out / "raw" / "runs.json", runs)
    extended = []
    if opts.extended:
        for kind, workers in (("baseline", 1), ("candidate", 1),
                              ("candidate", 6), ("baseline", 6)):
            label = f"extended_{kind}_{workers}w_1800"
            row = tick_run(binaries[kind], scene, workers, 1800, out / "raw",
                           label, trees[kind])
            row["implementation"] = kind
            extended.append(row)
            save(out / "raw" / "extended.json", extended)

    oracle = []
    if opts.verify_cursor:
        binary = benchmark_build(trees["candidate"], apparatus, out / "candidate", verify=True)
        for workers in (1, 6):
            label = f"cursor_oracle_{workers}w_600"
            row = tick_run(binary, scene, workers, 600, out / "raw", label, trees["candidate"])
            oracle.append(row)
            save(out / "raw" / "oracle.json", oracle)
    parity_problems = compare_semantics(runs, extended + oracle)
    results = metrics(runs, opts.cycles)
    profiles = {}
    if not opts.no_perf:
        for kind in ("baseline", "candidate"):
            profiles[kind] = maybe_profile(binaries[kind], scene, trees[kind], out / "perf", kind)
    else:
        profiles = {"baseline": {"status": "disabled"}, "candidate": {"status": "disabled"}}
    summary = {
        "source_heads": heads, "fixture_exact": fixture["pass"],
        "cycles": opts.cycles, "600_tick_run_count": len(runs),
        "1800_tick_run_count": len(extended), "oracle_run_count": len(oracle),
        "all_worker_and_build_parity": not parity_problems,
        "parity_problems": parity_problems, "metrics_by_workers": results,
        "tsan": tsan_results, "perf": profiles,
        "note": "CI/hardware-specific observations; perf absent or blocked is not a pass.",
    }
    save(out / "summary.json", summary)
    print(json.dumps(summary, indent=2, sort_keys=True))
    if parity_problems:
        raise SystemExit("FAIL: exact hashes or deterministic per-tick counters differ")
    if tsan_results and any(r["exit"] != 0 for r in tsan_results):
        raise SystemExit("FAIL: focused TSan tests failed or could not execute")


if __name__ == "__main__":
    main()
