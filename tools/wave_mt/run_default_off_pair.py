#!/usr/bin/env python3
"""Build and compare exact accepted main with the candidate, using default Water.

The same source-neutral harness and compiler flags build both executables. This
is a conservation/state-equivalence gate and retained performance measurement;
there is deliberately no elapsed-time pass threshold. --smoke is exploratory.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy

BASELINE_SHA = "018bd09503d7f079ddac52e225c2f7daf8d678bf"
HARNESS = ROOT / "native/bench/wave_default_off_pair.cpp"
SOURCES = ("world.cpp", "material_rules.cpp", "scheduler_geometry.cpp", "settled_world_discovery.cpp")
FLAGS = ("-std=c++20", "-O2", "-DNDEBUG", "-pthread")
CONFIGURATIONS = ((256, "dam"), (1024, "dam"), (2048, "sparse"), (2048, "idle"))
HEX16 = re.compile(r"[0-9a-f]{16}")


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def reject_constant(value: str):
    raise ValueError("nonfinite JSON constant: " + value)


def finite_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed):
        raise ValueError("nonfinite JSON number: " + value)
    return parsed


def git(root: Path, *arguments: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *arguments], text=True).strip()


def source_identity(root: Path, expected: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", expected) or git(root, "rev-parse", "HEAD") != expected:
        raise ValueError("source HEAD differs from its required immutable commit")
    if git(root, "status", "--porcelain", "--untracked-files=all", "--", "native/include", "native/src"):
        raise ValueError("native build inputs have tracked or untracked changes")
    paths = sorted([*root.glob("native/include/**/*"), *root.glob("native/src/**/*")])
    files = {path.relative_to(root).as_posix(): digest(path) for path in paths
             if path.is_file() and path.suffix in {".cpp", ".inc", ".hpp", ".h"}}
    if not files or any("native/src/" + name not in files for name in SOURCES):
        raise ValueError("native source inventory is incomplete")
    return {"commit": expected, "tree": git(root, "rev-parse", "HEAD^{tree}"), "files": files,
            "sha256": hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()}


def apparatus_identity(candidate_sha: str, smoke: bool) -> dict:
    paths = (HARNESS, Path(__file__).resolve(), ROOT / "tools/ci/execution_policy.py",
             ROOT / "godot/tests/support/ci_execution_policy.json")
    result = {path.relative_to(ROOT).as_posix(): digest(path) for path in paths}
    if not smoke:
        for relative, expected in result.items():
            committed = subprocess.check_output(["git", "-C", str(ROOT), "show", candidate_sha + ":" + relative])
            if hashlib.sha256(committed).hexdigest() != expected:
                raise ValueError("apparatus differs from candidate commit: " + relative)
    return result


def command(command: list[str], directory: Path, timeout: float) -> dict:
    """Retain both streams and original failure; kill this child's group only."""
    directory.mkdir(parents=True, exist_ok=False)
    result = {"command": command, "started_utc": utc(), "timeout_seconds": timeout,
              "returncode": None, "status": "RUNNING", "error": ""}
    write_json(directory / "process.json", result)
    started = time.monotonic()
    stdout = stderr = ""
    try:
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True, start_new_session=True)
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            result.update(status="TIMEOUT", error="child exceeded its execution allowance")
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass  # It exited after the watchdog; still drain original output.
            stdout, stderr = process.communicate()
        result["returncode"] = process.returncode
        if result["status"] != "TIMEOUT":
            result.update(status="PASS" if process.returncode == 0 else "FAIL",
                          error="" if process.returncode == 0 else f"exit {process.returncode}")
    except OSError as error:
        result.update(status="FAIL", error=str(error))
    result.update(wall_seconds=time.monotonic() - started, completed_utc=utc(), stdout=stdout, stderr=stderr)
    (directory / "stdout.txt").write_text(stdout, encoding="utf-8")
    (directory / "stderr.txt").write_text(stderr, encoding="utf-8")
    write_json(directory / "process.json", result)
    return result


def configurations(smoke: bool) -> list[dict]:
    rows = []
    cases = CONFIGURATIONS
    for repeat in range(1 if smoke else 3):
        for size, scene in cases:
            for workers in (1, 4):
                rows.append({"repeat": repeat, "size": size, "scene": scene, "workers": workers,
                             "warm": (8 if scene == "idle" else 4) if smoke else (240 if scene == "idle" else 30),
                             "ticks": 8 if smoke else 180})
    return rows


def pair_order(repeat: int) -> tuple[str, str]:
    return ("baseline", "candidate") if repeat % 2 == 0 else ("candidate", "baseline")


def validate_row(row: dict, expected: dict) -> None:
    wanted = {"schema": "wave-default-off-pair-v1", "size": expected["size"], "scene": expected["scene"],
              "workers_requested": expected["workers"], "workers_configured": expected["workers"],
              "warm_ticks": expected["warm"], "measured_ticks": expected["ticks"],
              "water_family": 1, "water_variant": 0, "conserved": True}
    if not isinstance(row, dict) or any(type(row.get(k)) is not type(v) or row.get(k) != v for k, v in wanted.items()):
        raise ValueError("row identity, default solver or conservation differs")
    observed = row.get("workers_observed")
    if type(observed) is not int or not 0 <= observed <= expected["workers"]:
        raise ValueError("invalid actual participant count")
    timing = row["timing"]
    samples = timing["tick_ns"]
    if (not isinstance(samples, list) or len(samples) != expected["ticks"]
            or any(type(value) is not int or value <= 0 for value in samples)):
        raise ValueError("missing or invalid complete-tick samples")
    ordered = sorted(samples)
    for percentile in (50, 95, 99):
        value = ordered[(len(ordered) * percentile + 99) // 100 - 1]
        if timing[f"tick_p{percentile}_ns"] != value:
            raise ValueError("tick percentile differs from raw samples")
    if timing["tick_max_ns"] != max(samples):
        raise ValueError("tick maximum differs from raw samples")
    for key in ("tick_mean_ns", "native_ticks_per_s"):
        if not isinstance(timing[key], (int, float)) or not math.isfinite(timing[key]) or timing[key] <= 0:
            raise ValueError("invalid timing summary")
    water = None
    for name, tick in (("start", 0), ("warm", expected["warm"]), ("final", expected["warm"] + expected["ticks"])):
        state = row["checkpoints"][name]
        if state["tick"] != tick or state["completed_tick"] != tick:
            raise ValueError("missing requested state checkpoint")
        if not all(isinstance(state[k], str) and HEX16.fullmatch(state[k]) for k in ("state_hash", "physical_hash")):
            raise ValueError("invalid state identity")
        if type(state["water_quantity"]) is not int or state["water_quantity"] < 0:
            raise ValueError("invalid water quantity")
        water = state["water_quantity"] if water is None else water
        if state["water_quantity"] != water or not isinstance(state["quantity_ledger"], dict):
            raise ValueError("quantity changed in a closed fixture")


def compare_pair(baseline: dict, candidate: dict) -> None:
    for key in ("water_family", "water_variant", "policy_hash", "visited_cells_total", "moved_cells_total", "scheduled_cores_total"):
        if baseline[key] != candidate[key]:
            raise ValueError("default-off paired state/work mismatch: " + key)
    for checkpoint in ("start", "warm", "final"):
        for key in ("tick", "completed_tick", "state_hash", "physical_hash_version", "physical_hash", "water_quantity", "quantity_ledger"):
            if baseline["checkpoints"][checkpoint][key] != candidate["checkpoints"][checkpoint][key]:
                raise ValueError("default-off paired checkpoint mismatch: " + checkpoint + "." + key)


def reduce_results(records: list[dict], planned: int, errors: list[str]) -> dict:
    pairs, ratios = {}, []
    for record in records:
        identity = record["configuration"]
        key = (identity["repeat"], identity["size"], identity["scene"], identity["workers"])
        pair = pairs.setdefault(key, {})
        if record["arm"] in pair:
            errors.append("duplicate paired process: " + str(key))
        pair[record["arm"]] = record
    for key, pair in pairs.items():
        if set(pair) != {"baseline", "candidate"} or any(row["status"] != "PASS" for row in pair.values()):
            errors.append("failed or incomplete pair: " + str(key))
            continue
        try:
            left, right = pair["baseline"]["result"], pair["candidate"]["result"]
            compare_pair(left, right)
            ratios.append({"repeat": key[0], "size": key[1], "scene": key[2], "workers": key[3],
                           **{f"candidate_over_baseline_p{p}": right["timing"][f"tick_p{p}_ns"] / left["timing"][f"tick_p{p}_ns"]
                              for p in (50, 95, 99)}})
        except (KeyError, ValueError, ZeroDivisionError) as error:
            errors.append(str(error) + ": " + str(key))
    if len(records) != planned:
        errors.append(f"incomplete process coverage: {len(records)}/{planned}")
    summary = []
    for size, scene, workers in sorted({(row["size"], row["scene"], row["workers"]) for row in ratios}):
        selected = [row for row in ratios if (row["size"], row["scene"], row["workers"]) == (size, scene, workers)]
        summary.append({"size": size, "scene": scene, "workers": workers, "paired_repeats": len(selected),
                        **{f"median_candidate_over_baseline_p{p}": statistics.median(row[f"candidate_over_baseline_p{p}"] for row in selected)
                           for p in (50, 95, 99)}})
    return {"status": "failed" if errors else "passed", "planned_processes": planned, "completed_processes": len(records),
            "errors": errors, "paired_ratios": ratios, "summary": summary,
            "interpretation": "Ratios above 1 mean slower candidate ticks. Performance is measured, not assigned a pass threshold; state and conservation equality are mandatory."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-source", type=Path, required=True)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cxx", default="g++-13")
    parser.add_argument("--smoke", action="store_true", help="Exploratory 16-process short run at all four sizes/scenes; never the full qualification")
    args = parser.parse_args()
    output, baseline = args.output.resolve(), args.baseline_source.resolve()
    output.mkdir(parents=True, exist_ok=False)
    compiler = shutil.which(args.cxx)
    records, errors = [], []
    rows = configurations(args.smoke)
    metadata = {"schema": "wave-default-off-pair-campaign-v1", "status": "running", "started_utc": utc(),
                "campaign": "exploratory-smoke" if args.smoke else "complete-paired-default-off",
                "planned_processes": 2 * len(rows), "configurations": rows,
                "host": {"platform": platform.platform(), "machine": platform.machine(), "logical_cpus": os.cpu_count()},
                "execution_policy": execution_policy.identity(), "builds": {}}
    cpu = Path("/proc/cpuinfo")
    if cpu.exists():
        for line in cpu.read_text().splitlines():
            if line.startswith("model name"):
                metadata["host"]["cpu_model"] = line.split(":", 1)[1].strip()
                break
    deadline = time.monotonic() + execution_policy.watchdog_seconds("native_suite_seconds")

    def allowance(key: str) -> float:
        seconds = execution_policy.watchdog_seconds(key)
        if deadline - time.monotonic() < seconds + execution_policy.watchdog_seconds("aggregate_headroom_seconds"):
            raise RuntimeError("remaining campaign budget cannot admit a full child allowance; coverage remains incomplete")
        return seconds

    def inputs() -> dict:
        return {"baseline": source_identity(baseline, BASELINE_SHA), "candidate": source_identity(ROOT, args.candidate_sha),
                "apparatus": apparatus_identity(args.candidate_sha, args.smoke), "compiler_sha256": digest(Path(compiler).resolve())}

    try:
        if compiler is None:
            raise ValueError("requested compiler is unavailable")
        metadata["compiler"] = {"path": compiler, "flags": FLAGS,
                                "version": subprocess.check_output([compiler, "--version"], text=True)}
        metadata["inputs_before"] = inputs()
        shutil.copyfile(HARNESS, output / "harness.cpp")
        write_json(output / "metadata.json", metadata)
        binaries = {}
        for arm, root in (("baseline", baseline), ("candidate", ROOT)):
            binary = output / arm
            argv = [compiler, *FLAGS, "-I", str(root / "native/include"),
                    *(str(root / "native/src" / name) for name in SOURCES), str(HARNESS), "-o", str(binary)]
            receipt = command(argv, output / ("build-" + arm), allowance("native_compile_seconds"))
            metadata["builds"][arm] = receipt
            if receipt["status"] != "PASS":
                raise RuntimeError(arm + " compilation failed; original process evidence retained")
            binaries[arm] = {"path": str(binary), "sha256": digest(binary)}
            if inputs() != metadata["inputs_before"]:
                raise RuntimeError("source, harness or compiler changed during compilation")
            write_json(output / "metadata.json", metadata)
        metadata["executables"] = binaries
        write_json(output / "metadata.json", metadata)
        with (output / "runs.jsonl").open("w", encoding="utf-8") as raw, (output / "rows.csv").open("w", newline="", encoding="utf-8") as table:
            fields = ("repeat", "size", "scene", "workers", "arm", "status", "error", "p50_ns", "p95_ns", "p99_ns", "workers_observed")
            writer = csv.DictWriter(table, fieldnames=fields)
            writer.writeheader()
            table.flush()
            for config in rows:
                for arm in pair_order(config["repeat"]):
                    binary = Path(binaries[arm]["path"])
                    if digest(binary) != binaries[arm]["sha256"]:
                        raise RuntimeError("executable changed before paired process")
                    argv = [str(binary), str(config["size"]), config["scene"], str(config["workers"]), str(config["warm"]), str(config["ticks"])]
                    record = command(argv, output / "processes" / f"{len(records):03}-{arm}", allowance("native_case_seconds"))
                    record.update(arm=arm, configuration=config, executable_sha256=binaries[arm]["sha256"])
                    if record["status"] == "PASS":
                        try:
                            record["result"] = json.loads(record["stdout"], parse_constant=reject_constant, parse_float=finite_float)
                            validate_row(record["result"], config)
                        except (ValueError, KeyError, TypeError) as error:
                            record.pop("result", None)
                            record.update(status="FAIL", error=str(error))
                    records.append(record)
                    raw.write(json.dumps(record, allow_nan=False) + "\n")
                    raw.flush()
                    result = record.get("result", {})
                    writer.writerow({**{key: config[key] for key in ("repeat", "size", "scene", "workers")},
                                     "arm": arm, "status": record["status"], "error": record["error"],
                                     **{f"p{p}_ns": result.get("timing", {}).get(f"tick_p{p}_ns", "") for p in (50, 95, 99)},
                                     "workers_observed": result.get("workers_observed", "")})
                    table.flush()
                    print(f"{len(records)}/{2 * len(rows)} {config} {arm}: {record['status']}", flush=True)
        metadata["inputs_after"] = inputs()
        if metadata["inputs_after"] != metadata["inputs_before"]:
            raise RuntimeError("source, harness or compiler changed during campaign")
        metadata["executables_after"] = {arm: digest(Path(info["path"])) for arm, info in binaries.items()}
        if any(metadata["executables_after"][arm] != info["sha256"] for arm, info in binaries.items()):
            raise RuntimeError("executable changed during campaign")
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        errors.append(str(error))
    report = reduce_results(records, 2 * len(rows), errors)
    metadata.update(status=report["status"], completed_utc=utc(), completed_processes=len(records))
    write_json(output / "metadata.json", metadata)
    write_json(output / "summary.json", report)
    lines = ["# Paired default-off Water performance", "", f"Campaign: {metadata['campaign']}. Status: {report['status']}. Processes: {len(records)}/{2 * len(rows)}.", "", report["interpretation"], "",
             "| Size | Scene | Workers | Paired repeats | Median p50 ratio | Median p95 ratio | Median p99 ratio |",
             "|---:|---|---:|---:|---:|---:|---:|"]
    for row in report["summary"]:
        lines.append(f"| {row['size']} | {row['scene']} | {row['workers']} | {row['paired_repeats']} | " + " | ".join(f"{row[f'median_candidate_over_baseline_p{p}']:.4f}" for p in (50, 95, 99)) + " |")
    if errors:
        lines += ["", "## Original failures", "", *["- " + error for error in errors]]
    (output / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines), flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
