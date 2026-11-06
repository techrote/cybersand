#!/usr/bin/env python3
"""Six paired 1,800-tick experiments, six workers, source-identical code.

This supplements (does not replace) the 600-tick qualification. It isolates the
activity-grown final 600 ticks and avoids repeating the 188-test native suites.
"""
import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys

REF = "4a80af2a891332176a3912a235582d77d076a185"
EXPECTED_SHA = {
    "baseline": "5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d",
    "candidate": "bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868",
}
TCRIT_95_DF5 = 2.571


def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, sort_keys=True, indent=2, default=str) + "\n",
                    encoding="utf-8")


def git(cmd, cwd, log):
    p = subprocess.run(["git", *cmd], cwd=cwd, capture_output=True, text=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("$ git " + " ".join(map(str, cmd)) + "\n" +
                   p.stdout + "\n" + p.stderr + "\nexit=" + str(p.returncode) + "\n",
                   encoding="utf-8")
    if p.returncode:
        raise RuntimeError(f"Git operation failed: {log}")
    return p.stdout.strip()


def pct_pair(baseline, candidate):
    return 100.0 * (baseline - candidate) / baseline


def stat(values):
    avg = statistics.mean(values)
    std = statistics.stdev(values)
    halfwidth = TCRIT_95_DF5 * std / math.sqrt(len(values))
    return {"paired_speedup_pct": values, "mean_pct": avg, "std_pct": std,
            "ci_95_pct": [avg-halfwidth, avg+halfwidth],
            "reliably_positive_on_this_host": avg-halfwidth > 0}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--baseline", default=REF)
    parser.add_argument("--candidate", default="HEAD")
    a = parser.parse_args()
    root, out = a.repo.resolve(), a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(root / "native/bench"))
    import run_neighbour_cursor as bench

    heads = {}
    trees = {}
    for kind, ref in (("baseline", a.baseline), ("candidate", a.candidate)):
        head = git(["rev-parse", f"{ref}^{{commit}}"], root, out / (kind + "_rev.log"))
        trees[kind] = out / ("tree_" + kind)
        if trees[kind].exists():
            raise RuntimeError("refusing to overwrite an existing worktree")
        git(["worktree", "add", "--detach", str(trees[kind]), head],
            root, out / (kind + "_worktree.log"))
        digest = bench.sha_lf(trees[kind] / "native/src/world.cpp")
        if digest != EXPECTED_SHA[kind]:
            raise RuntimeError(f"{kind}: protected-source hash changed {digest}")
        heads[kind] = head

    apparatus = root / "native/bench"
    fixture = apparatus / "data/neighbour_stress_rectangles.txt"
    verified = bench.check_fixture(fixture, trees["candidate"] / "godot/scripts/workbench_setup.gd")
    save(out / "fixture.json", verified)
    if not verified["pass"]:
        raise RuntimeError("not the original Godot stress-canvas fixture")

    binaries = {}
    for kind, tree in trees.items():
        binaries[kind] = bench.benchmark_build(tree, apparatus, out / ("build_" + kind))

    info = {
        "repo": "techrote/cybersand", "source_heads": heads,
        "world_sha256": EXPECTED_SHA, "fixture_sha256": bench.sha_lf(fixture),
        "apparatus_sha256": bench.sha_lf(apparatus / "neighbour_cursor_bench.cpp"),
        "cpu": (Path("/proc/cpuinfo").read_text().split("model name",1)[1].split("\n",1)[0]
                if Path("/proc/cpuinfo").exists() else "unknown"),
        "logical_processors": os.cpu_count(), "os": platform.platform(),
        "workers": 6, "ticks": 1800, "cycles": 6,
        "target_window": "1201..1800, settled activity",
        "compiler_flags": "-O2 -g -fno-omit-frame-pointer",
    }
    save(out / "machine.json", info)

    trials = {}
    for cycle in range(6):
        order = ("baseline", "candidate") if cycle % 2 == 0 else ("candidate", "baseline")
        for kind in order:
            name = f"pair_{cycle+1:02d}_{kind}_6w_1800"
            row = bench.tick_run(binaries[kind], fixture, 6, 1800,
                                 out / "raw", name, trees[kind])
            row["cycle"] = cycle
            row["implementation"] = kind
            with Path(row["csv"]).open(newline="", encoding="utf-8") as stream:
                records = list(csv.DictReader(stream))
            if len(records) != 1800:
                raise AssertionError("incomplete extended CSV")
            row["last600_mean_ms"] = statistics.mean(
                float(record["ms"]) for record in records[1200:])
            row["last600_median_ms"] = statistics.median(
                float(record["ms"]) for record in records[1200:])
            row["last600_cores_mean"] = statistics.mean(
                int(record["cores"]) for record in records[1200:])
            row["last600_visited_mean"] = statistics.mean(
                int(record["visited"]) for record in records[1200:])
            trials[(cycle, kind)] = row
            save(out / "runs.json", [
                {key: value for key, value in r.items() if key != "_semantic_signature"}
                for r in trials.values()])
    rows = list(trials.values())
    failures = bench.compare_semantics(rows, [])
    if failures:
        save(out / "parity-failures.json", failures)
        raise RuntimeError("baseline/cursor or 6-worker repeat deterministic parity failure")

    summaries = {}
    for label, key in (("complete_1800", "mean_from_raw_ms"),
                       ("activity_grown_1201_1800", "last600_mean_ms")):
        pairs = [pct_pair(trials[(i,"baseline")][key],
                          trials[(i,"candidate")][key]) for i in range(6)]
        summaries[label] = stat(pairs)
        summaries[label]["baseline_mean_ms"] = statistics.mean(
            trials[(i,"baseline")][key] for i in range(6))
        summaries[label]["candidate_mean_ms"] = statistics.mean(
            trials[(i,"candidate")][key] for i in range(6))
    summary = {
        "source_heads": heads, "run_count": 12,
        "ticks_per_run": 1800, "workers": 6, "exactness_pass": True,
        "observed_workers": max(r["actual_workers_max"] for r in rows),
        "activity": {
            "last600_cores_mean": statistics.mean(r["last600_cores_mean"] for r in rows),
            "last600_visited_mean": statistics.mean(r["last600_visited_mean"] for r in rows),
        },
        "timing": summaries,
        "caution": "Hosted four-logical-CPU six-worker oversubscription; infer only for this host."
    }
    save(out / "summary.json", summary)
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
