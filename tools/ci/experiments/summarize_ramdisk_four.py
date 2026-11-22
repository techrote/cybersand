#!/usr/bin/env python3
"""Fail-closed complete four-by-six RAMdisk experiment artifact reducer.

Does not select only passing cohorts. Preserves original trial data and exposes
single-shard median comparisons; cannot claim complete CI speedup.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
import statistics
import sys

SHARDS = (2, 6, 12, 19)
MODES = ("stock", "ram")


def numbers(rows: list[dict], key: str) -> dict:
    vals = [r.get(key) for r in rows if r.get("status") == "passed"]
    if len(vals) != 3 or any(type(x) not in (int, float) or not math.isfinite(x) for x in vals):
        return {"count": len(vals), "median": None, "mean": None, "min": None, "max": None}
    return {"count": 3, "median": statistics.median(vals), "mean": statistics.mean(vals),
            "min": min(vals), "max": max(vals)}


def run(root: Path, output: Path) -> int:
    summaries = sorted(root.glob("ramdisk-four-shard-*/summary.json"))
    errors: list[str] = []
    if len(summaries) != len(SHARDS):
        errors.append(f"Expected 4 exact shard summaries; found {len(summaries)}")
    data: dict[int, dict] = {}
    for file in summaries:
        try:
            record = json.loads(file.read_text())
            shard = record["shard"]
            if shard not in SHARDS or shard in data:
                raise ValueError("Unexpected/duplicate shard")
            if len(record.get("trials", [])) != 6:
                raise ValueError("Not exactly six trials")
            data[shard] = record
        except (ValueError, KeyError, TypeError) as exc:
            errors.append(f"{file}: {exc}")
    modes_rows = []
    rows: list[dict] = []
    case_rows: list[dict] = []
    source_shas = set()
    runtime_shas = set()
    godot_shas = set()
    for shard in SHARDS:
        if shard not in data:
            errors.append(f"Shard {shard} absent")
            continue
        record = data[shard]
        host_file = next(root.glob(f"ramdisk-four-shard-{shard}-*/source-and-host.json"), None)
        if host_file is None:
            errors.append(f"Shard {shard} host/source metadata absent")
            continue
        host = json.loads(host_file.read_text())
        source_shas.add(host["source_sha"])
        runtime_shas.add(host["binaries"]["godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"])
        godot_shas.add(host["godot_sha256"])
        expected_names = host["cases"]
        observed = record["trials"]
        if sorted(r.get("trial") for r in observed) != list(range(1, 7)):
            errors.append(f"Shard {shard}: duplicate/nonsequential trial IDs")
        if len([r for r in observed if r.get("mode") == "stock"]) != 3 or len([r for r in observed if r.get("mode") == "ram"]) != 3:
            errors.append(f"Shard {shard}: missing mode repetitions")
        if tuple(r.get("mode") for r in observed) != tuple(host["mode_order"]):
            errors.append(f"Shard {shard}: observed order differs from predeclared plan")
        for row in observed:
            if row["status"] != "passed":
                errors.append(f"Shard {shard} trial {row['trial']} {row['mode']}: {row.get('error', 'not passed')}")
            elif (row.get("case_names") != expected_names or row.get("source_sha") != host["source_sha"]
                  or row.get("runtime_sha256") != host["binaries"]["godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"]
                  or row.get("godot_sha256") != host["godot_sha256"]):
                errors.append(f"Shard {shard} trial {row['trial']}: source/case/runtime identity mismatch")
            if row.get("filesystem") != ("tmpfs" if row["mode"] == "ram" else "overlayfs"):
                # GitHub-hosted stock can be ext2/ext4/overlayfs; any non-tmpfs is admissible.
                if not (row["mode"] == "stock" and row.get("filesystem") not in ("tmpfs", None)):
                    errors.append(f"Shard {shard} trial {row['trial']}: filesystem identity incorrect")
            rows.append({"shard": shard, "trial": row["trial"], "mode": row["mode"],
                         "status": row["status"], "execution_seconds": row.get("execution_seconds"),
                         "stage_seconds": row.get("stage_seconds"), "readback_seconds": row.get("readback_seconds"),
                         "copyback_seconds": row.get("copyback_seconds"),
                         "total_trial_seconds": row.get("total_trial_seconds"),
                         "import_seconds": row.get("import_seconds"),
                         "case_seconds_sum": row.get("case_seconds_sum"),
                         "cache_bytes": row.get("generated_godot_cache_bytes")})
        row_by_mode = {m: [r for r in observed if r.get("mode") == m] for m in MODES}
        stock = numbers(row_by_mode["stock"], "execution_seconds")
        ram = numbers(row_by_mode["ram"], "execution_seconds")
        saving = ((stock["median"] - ram["median"]) / stock["median"] * 100
                  if stock["median"] and ram["median"] is not None else None)
        modes_rows.append({"shard": shard, "case_count": len(expected_names),
                           "host_cpu": host["host"]["runner"]["cpu_model"],
                           "stock_execution": stock, "ram_execution": ram,
                           "stock_import": numbers(row_by_mode["stock"], "import_seconds"),
                           "ram_import": numbers(row_by_mode["ram"], "import_seconds"),
                           "stock_total": numbers(row_by_mode["stock"], "total_trial_seconds"),
                           "ram_total": numbers(row_by_mode["ram"], "total_trial_seconds"),
                           "median_execution_saving_percent": saving})
        for name in expected_names:
            values = {}
            for m in MODES:
                matching = [r.get("case_wall_seconds", {}).get(name) for r in row_by_mode[m]
                            if r.get("status") == "passed"]
                values[m] = statistics.median(matching) if len(matching) == 3 and all(type(x) in (int, float) for x in matching) else None
            case_rows.append({"shard": shard, "case": name,
                              "stock_median_seconds": values["stock"],
                              "ram_median_seconds": values["ram"]})
    if len(source_shas) != 1 or len(runtime_shas) != 1 or len(godot_shas) != 1:
        errors.append("Shard runners differ in source, native runtime, or Godot executable identity")
    output.mkdir(parents=True, exist_ok=True)
    result = {"schema": "cybersand-ramdisk-four-shard-six-run-v1",
              "status": "passed" if not errors else "failed", "errors": errors,
              "source_sha": next(iter(source_shas)) if len(source_shas) == 1 else None,
              "runtime_sha256": next(iter(runtime_shas)) if len(runtime_shas) == 1 else None,
              "shards": modes_rows, "experiment_not_full_ci_speedup": True,
              "methodology": "4 shards, same-host six serial trials each, 3 stock + 3 tmpfs; alternating ABBAAB/BAABBA; fresh workspaces and cache; no dropped cases; complete copy-back and failures retained"}
    (output / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    for name, data_rows in (("trials.csv", rows), ("case-medians.csv", case_rows)):
        if data_rows:
            with (output / name).open("w", newline="") as f:
                w = csv.DictWriter(f, fieldnames=list(data_rows[0]))
                w.writeheader(); w.writerows(data_rows)
    with (output / "report.md").open("w", encoding="utf-8") as report:
        report.write("# CyberSand four-shard stock versus RAMdisk experiment\n\n")
        report.write(f"**Qualification: {result['status'].upper()}**. Source: " + chr(96) + f"{result['source_sha']}" + chr(96) + ".\n\n")
        report.write("Each row contains three successful trials per arm only when all trials qualify. A negative saving means RAM was slower.\n\n")
        report.write("| Shard | Cases | Stock median runtime | RAM median runtime | RAM median saving |\n|---:|---:|---:|---:|---:|\n")
        for r in modes_rows:
            a, b, pct = r["stock_execution"]["median"], r["ram_execution"]["median"], r["median_execution_saving_percent"]
            report.write(f"| {r['shard']} | {r['case_count']} | {a:.2f}s | {b:.2f}s | {pct:+.2f}% |\n" if a is not None and b is not None and pct is not None else f"| {r['shard']} | {r['case_count']} | incomplete | incomplete | n/a |\n")
        report.write("\nThe underlying trial CSV separately records staging, execution, readback, output copy-back, complete trial time and import time. ")
        report.write("Those figures are per-shard and not a measured complete-GDExtension critical path. Host OS libraries and the Xvfb executable are not moved into tmpfs; the entire controlled checkout, Godot binary, per-trial temp/HOME/XDG caches and test output are staged there.\n")
        if errors:
            report.write("\n## Failure inventory\n\n" + "\n".join("- " + e for e in errors) + "\n")
    print((output / "report.md").read_text(), flush=True)
    return int(bool(errors))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    sys.exit(run(args.root, args.output))
