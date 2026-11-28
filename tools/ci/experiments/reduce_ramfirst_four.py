#!/usr/bin/env python3
"""Strict readback of CI-RAMFIRST-002, four directly checked-out paired hosts."""
from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
import statistics
import sys

SHARDS = {2, 6, 12, 19}
MODES = ("stock", "ram")


def finite(x):
    return type(x) in (float, int) and math.isfinite(x) and x >= 0


def distribution(xs):
    if len(xs) != 3 or not all(finite(x) for x in xs):
        return None
    return {"median": statistics.median(xs), "mean": statistics.mean(xs),
            "min": min(xs), "max": max(xs), "values": xs}


def readback(directory: Path, output: Path) -> int:
    errors = []
    files = [p for p in directory.rglob("summary.json") if p.parent.name == "report"]
    cohorts = {}
    for file in files:
        try:
            data = json.loads(file.read_text(encoding="utf-8"))
            shard = data["shard"]
            if data.get("schema") != "cybersand-ramfirst-four-shards-v2" or shard not in SHARDS or shard in cohorts:
                raise ValueError("Wrong schema, shard, or duplicate cohort")
            cohorts[shard] = data
        except (KeyError, TypeError, ValueError) as exc:
            errors.append(f"{file}: {type(exc).__name__}: {exc}")
    if set(cohorts) != SHARDS:
        errors.append(f"Missing/extra shards: {sorted(SHARDS - set(cohorts))} / {sorted(set(cohorts) - SHARDS)}")
    source = set()
    runtime = set()
    godot = set()
    rapier = set()
    cases_count = 0
    raw = []
    summary = []
    case_rows = []
    for shard in sorted(SHARDS & set(cohorts)):
        data = cohorts[shard]
        if data.get("status") != "passed":
            errors.append(f"Shard {shard} not passed: {data.get('error')}")
        host = data.get("host", {})
        if host.get("run", {}).get("GITHUB_SHA") is None:
            errors.append(f"Shard {shard}: missing exact GitHub source identity")
        arms = data.get("arms", {})
        if set(arms) != set(MODES):
            errors.append(f"Shard {shard}: missing arm preparation")
            continue
        for mode in MODES:
            arm = arms[mode]
            if arm.get("status") != "prepared":
                errors.append(f"Shard {shard} {mode}: preparation failed: {arm.get('error')}")
            source.add(arm.get("source", {}).get("head"))
            runtime.add(arm.get("runtime_sha256"))
            godot.add(arm.get("godot_sha256"))
            rapier.add(arm.get("rapier_sha256"))
            if arm.get("source", {}).get("head") != host.get("run", {}).get("GITHUB_SHA"):
                errors.append(f"Shard {shard} {mode}: source != workflow HEAD")
            if mode == "ram" and arm.get("source", {}).get("fs") != "tmpfs":
                errors.append(f"Shard {shard} RAM checkout is not tmpfs")
            if mode == "stock" and arm.get("source", {}).get("fs") == "tmpfs":
                errors.append(f"Shard {shard} stock checkout unexpectedly tmpfs")
        cases = arms["stock"].get("case_names", [])
        if not cases or cases != arms["ram"].get("case_names"):
            errors.append(f"Shard {shard}: source-derived case inventory differs")
        cases_count += len(cases)
        trials = data.get("trials", [])
        if len(trials) != 6 or [t.get("sequence") for t in trials] != list(range(1, 7)):
            errors.append(f"Shard {shard}: six sequential trials not present")
        if tuple(t.get("mode") for t in trials) != tuple(data.get("order", [])):
            errors.append(f"Shard {shard}: execution order differs from predeclared plan")
        arm_rows = {}
        for mode in MODES:
            these = [t for t in trials if t.get("mode") == mode]
            if len(these) != 3 or [t.get("repeat") for t in these] != [1, 2, 3]:
                errors.append(f"Shard {shard} {mode}: not exactly three original trial receipts")
            for trial in these:
                if trial.get("status") != "passed" or trial.get("completed_cases") != len(cases):
                    errors.append(f"Shard {shard} {mode} repeat {trial.get('repeat')}: incomplete/failed: {trial.get('error')}")
                if trial.get("filesystem") != ("tmpfs" if mode == "ram" else arms[mode]["source"]["fs"]):
                    errors.append(f"Shard {shard} {mode} repeat {trial.get('repeat')}: incorrect filesystem")
                if set(trial.get("case_seconds", {})) != set(cases):
                    errors.append(f"Shard {shard} {mode} repeat {trial.get('repeat')}: case inventory mismatch")
                raw.append({"shard": shard, "mode": mode, "repeat": trial.get("repeat"),
                            "sequence": trial.get("sequence"), "status": trial.get("status"),
                            "execution_seconds": trial.get("execution_seconds"),
                            "import_seconds": trial.get("import_seconds"),
                            "test_seconds": trial.get("test_seconds"),
                            "readback_seconds": trial.get("readback_seconds"),
                            "godot_cache_bytes": trial.get("godot_cache_bytes")})
            arm_rows[mode] = these
        stock = distribution([x.get("execution_seconds") for x in arm_rows["stock"]])
        ram = distribution([x.get("execution_seconds") for x in arm_rows["ram"]])
        delta = 100 * (stock["median"] - ram["median"]) / stock["median"] if stock and ram and stock["median"] else None
        summary.append({"shard": shard, "case_count": len(cases),
                        "cpu": host.get("cpu"), "stock_median": stock["median"] if stock else None,
                        "ram_median": ram["median"] if ram else None, "ram_saving_percent": delta,
                        "stock_prepare_seconds": arms["stock"].get("preparation_seconds"),
                        "ram_prepare_seconds": arms["ram"].get("preparation_seconds"),
                        "stock_cold_seconds": arm_rows["stock"][0].get("execution_seconds") if arm_rows["stock"] else None,
                        "ram_cold_seconds": arm_rows["ram"][0].get("execution_seconds") if arm_rows["ram"] else None})
        for case in cases:
            vals = {}
            for mode in MODES:
                xs = [t.get("case_seconds", {}).get(case) for t in arm_rows[mode]]
                distribution_result = distribution(xs)
                vals[mode] = distribution_result["median"] if distribution_result else None
            case_rows.append({"shard": shard, "case": case, "stock_median": vals["stock"],
                              "ram_median": vals["ram"]})
    if len(source) != 1 or None in source:
        errors.append("Across-host source hash mismatch/missing")
    if len(runtime) != 1 or None in runtime:
        errors.append("Across-host native runtime bytes not identical")
    if len(godot) != 1 or None in godot:
        errors.append("Across-host pinned Godot executable bytes not identical")
    if len(rapier) != 1 or None in rapier:
        errors.append("Across-host pinned Rapier bytes not identical")
    output.mkdir(parents=True, exist_ok=True)
    verdict = {"schema": "cybersand-ramfirst-four-shard-results-v1",
               "status": "failed" if errors else "passed", "errors": errors,
               "shards": summary, "source_sha": next(iter(source)) if len(source) == 1 else None,
               "unique_cases_in_four_selected_shards": cases_count,
               "is_complete_CI_speedup": False,
               "experiment": "two direct checkouts per same runner: RAM tmpfs mounted before checkout; both dependencies built natively in their filesystem; ABBAAB/BAABBA; three trials per mode"}
    (output / "summary.json").write_text(json.dumps(verdict, indent=2) + "\n")
    for name, rows in (("trials.csv", raw), ("case-medians.csv", case_rows)):
        if rows:
            with (output / name).open("w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, fieldnames=list(rows[0]))
                writer.writeheader()
                writer.writerows(rows)
    report = ["# CI-RAMFIRST-002 — RAM-mounted before checkout", "",
              "**Verdict: " + verdict["status"].upper() + "**", "",
              "Exact source: " + str(verdict["source_sha"]) + ".",
              "Each of 4 hosts performs three full regression trials from an independently obtained and built SSD worktree, and three from an independently obtained and built RAM worktree, using no inter-filesystem staging. Only three valid complete trials qualify each median.",
              "",
              "| Shard | Cases | SSD median | RAM median | RAM saving | SSD build/prep | RAM build/prep |",
              "|---:|---:|---:|---:|---:|---:|---:|"]
    for row in summary:
        fmt = lambda x: f"{x:.2f}s" if finite(x) else "n/a"
        pct = f"{row['ram_saving_percent']:+.2f}%" if row["ram_saving_percent"] is not None else "n/a"
        report.append(f"| {row['shard']} | {row['case_count']} | {fmt(row['stock_median'])} | {fmt(row['ram_median'])} | {pct} | {fmt(row['stock_prepare_seconds'])} | {fmt(row['ram_prepare_seconds'])} |")
    report += ["", "The file trials.csv contains every measurement including failures; case-medians.csv preserves per-case comparison. First trials include cold Godot import; subsequent trials reuse each independent arm's Godot cache. Each host's CPU, memory, source and original evidence remain in its artifact. The Linux operating system, runner agent, system compiler binaries and GitHub Action internals are necessarily outside either controlled worktree. This is not a claim of complete-CI speedup."] 
    if errors:
        report.extend(["", "## Errors", ""] + ["- " + e for e in errors])
    (output / "report.md").write_text("\n".join(report) + "\n")
    print("\n".join(report), flush=True)
    return int(bool(errors))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    sys.exit(readback(args.root, args.output))
