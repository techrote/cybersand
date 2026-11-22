#!/usr/bin/env python3
"""Freeze, build and measure the actual native ObjectShard implementation.

This is a native cost experiment with synthetic pose/acknowledgement values.
It does not execute Rapier, render frames or establish Windows playability.
The comparison uses release optimisation without LTO, in one isolated process.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import platform
import shlex
import subprocess
import sys
import time

import run_native_tests as native


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=native.ROOT / "build/objectshard-benchmarks")
    parser.add_argument("--compiler", default=os.environ.get("CXX", "g++"))
    parser.add_argument("--jobs", type=int, default=min(2, os.cpu_count() or 1))
    parser.add_argument("--ticks", type=int, default=480)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--case", help="Run one named workload; default runs the complete matrix.")
    parser.add_argument("--qualify", action="store_true", help="Enforce the registered development-host native budgets on the complete matrix.")
    parser.add_argument("--timeout", type=float, default=240)
    parser.add_argument("--build-timeout", type=float, default=420)
    args = parser.parse_args()
    if not 1 <= args.jobs <= 16:
        parser.error("--jobs must be between 1 and 16")
    if min(args.ticks, args.repetitions) < 1 or args.ticks * args.repetitions > 100000:
        parser.error("positive tick/repetition counts with at most 100000 samples are required")
    if any(not math.isfinite(value) or value <= 0 for value in (args.timeout, args.build_timeout)):
        parser.error("timeouts must be finite positive numbers")
    if args.qualify and args.case:
        parser.error("budget qualification requires the complete workload matrix")
    return args


def check_budgets(report: dict[str, object], budget: dict[str, object]) -> dict[str, object]:
    failures: list[str] = []
    checked = 0

    def admit(name: str, actual: int | float, maximum: int | float) -> None:
        nonlocal checked
        checked += 1
        if not math.isfinite(actual) or actual > maximum:
            failures.append(f"{name}: observed {actual}, registered maximum {maximum}")

    expected = {"empty_lab", "inert_stationary", "inert_moving", "reacting_one", "reacting_three",
        "perforated_reacting", "saturated_world_destinations", "dormant_twelve", "wake_burst_twelve",
        "compact_vs_tuned_serial_miniature"}
    actual_names = {case["name"] for case in report["cases"]}
    if actual_names != expected:
        failures.append(f"workload inventory differs: missing {sorted(expected - actual_names)}, unexpected {sorted(actual_names - expected)}")
    limits = budget["integrated_limits"]
    for case in report["cases"]:
        name = case["name"]
        if name == "compact_vs_tuned_serial_miniature":
            for candidate in ("compact", "miniature"):
                admit(f"{name}.{candidate}.steady_allocations", case["memory"][f"{candidate}_steady_allocations"],
                    budget["comparison_requirements"]["steady_cpp_allocations_each_candidate"])
            continue
        frame = case["timings"]["native_frame_including_snapshot_receipt"]
        if frame["samples"] < budget["minimum_frame_samples_per_workload"]:
            failures.append(f"{name}: {frame['samples']} samples are insufficient for final percentile qualification")
        for percentile in ("p95", "p99", "max"):
            admit(f"{name}.frame.{percentile}_us", frame[f"{percentile}_us"], limits[f"native_frame_{percentile}_us"])
        for metric in ("cpp_live_max_bytes", "cpp_peak_max_bytes", "registry_retained_max_bytes"):
            admit(f"{name}.{metric}", case["memory"][metric], limits[metric])
        admit(f"{name}.steady_allocations", case["memory"]["steady_allocations"], limits["steady_cpp_allocations"])
        admit(f"{name}.geometry_age_ticks", case["observations"]["geometry_age_max_ticks"], limits["geometry_age_max_ticks"])
    return {"status": "passed" if not failures else "failed", "limits_checked": checked, "failures": failures}


def main() -> int:
    args = parse_arguments()
    started = time.monotonic()
    compiler = shlex.split(args.compiler, posix=os.name != "nt")
    if not compiler:
        raise ValueError("empty compiler command")
    version = subprocess.run([*compiler, "--version"], capture_output=True, text=True, timeout=30, check=True)
    benchmark = native.ROOT / "native/tests/benchmark_object_shard.cpp"
    budget_path = native.ROOT / "tools/objectshard/native_budgets.json"
    paths = sorted(set([*native.inputs([]), benchmark, budget_path, Path(__file__).resolve()]))
    head = native.git_value("rev-parse", "HEAD")
    captured = {str(path.relative_to(native.ROOT)): path.read_bytes() for path in paths}
    if native.git_value("rev-parse", "HEAD") != head or any(
        (native.ROOT / name).read_bytes() != data for name, data in captured.items()
    ):
        raise RuntimeError("source changed during capture; no changing-tree qualification was attempted")
    flags = ["-std=c++20", "-O3", "-DNDEBUG", "-pthread", "-Wall", "-Wextra", "-Wpedantic", "-Werror"]
    specification = {
        "schema": 1, "sources": {name: native.sha256(data) for name, data in captured.items()},
        "compiler": compiler, "compiler_version": version.stdout.strip(), "flags": flags,
        "platform": platform.platform(), "machine": platform.machine(), "processor": platform.processor(),
        "logical_cpus": os.cpu_count(), "ticks": args.ticks, "repetitions": args.repetitions, "case": args.case,
    }
    cpuinfo = Path("/proc/cpuinfo")
    if cpuinfo.is_file():
        specification["cpu_model"] = next((line.split(":", 1)[1].strip()
            for line in cpuinfo.read_text().splitlines() if line.startswith("model name")), "unknown")
    digest = native.sha256(json.dumps(specification, sort_keys=True).encode())
    output = args.output.resolve()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    run = output / f"{stamp}-{digest[:12]}"
    source, objects, logs = run / "source", run / "objects", run / "logs"
    for directory in (source, objects, logs):
        directory.mkdir(parents=True, exist_ok=False)
    for name, data in captured.items():
        destination = source / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    native.write_json(run / "inputs.json", {**specification, "input_digest": digest,
        "git_head": head, "git_status": native.git_value("status", "--short"), "source_root": str(native.ROOT)})
    print(f"ObjectShard benchmark input: {digest}\nEvidence: {run}", flush=True)
    names = (*native.WORLD, "object_shard", "object_shard_coordinator")
    include = ["-I", str(source / "native/include")]
    builds: dict[str, object] = {}

    def compile_one(name: str) -> tuple[str, dict[str, object]]:
        record = native.command_record([*compiler, *flags, *include, "-c", str(source / f"native/src/{name}.cpp"),
            "-o", str(objects / f"{name}.o")], logs / f"compile-{name}.log", args.build_timeout)
        if record["returncode"] == 0:
            record["object_sha256"] = native.sha256((objects / f"{name}.o").read_bytes())
        return name, record

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for future in as_completed(pool.submit(compile_one, name) for name in names):
            name, record = future.result()
            builds[name] = record
    native.write_json(run / "builds.json", builds)
    summary: dict[str, object] = {"schema": 1, "input_digest": digest, "git_head": head,
        "run_directory": str(run), "qualification_scope": __doc__, "status": "build_failed"}
    if all(record["returncode"] == 0 for record in builds.values()):
        executable = run / ("benchmark_object_shard.exe" if os.name == "nt" else "benchmark_object_shard")
        summary["link"] = native.command_record([*compiler, *flags, *include,
            str(source / "native/tests/benchmark_object_shard.cpp"),
            *(str(objects / f"{name}.o") for name in names), "-o", str(executable)],
            logs / "link.log", args.build_timeout)
        if summary["link"]["returncode"] == 0:
            summary["binary_sha256"] = native.sha256(executable.read_bytes())
            command = [str(executable), "--ticks", str(args.ticks), "--repetitions", str(args.repetitions)]
            if args.case:
                command.extend(["--case", args.case])
            summary["execution"] = native.command_record(command, logs / "benchmark.log", args.timeout)
            summary["status"] = "execution_failed"
            if summary["execution"]["returncode"] == 0:
                report = json.loads((logs / "benchmark.log").read_text())
                if report.get("failures") != 0 or not report.get("cases"):
                    raise RuntimeError("benchmark completed without valid observations")
                native.write_json(run / "benchmark.json", report)
                summary["report"] = str(run / "benchmark.json")
                summary["checks"] = report["checks"]
                summary["failures"] = report["failures"]
                summary["status"] = "measured"
                if args.qualify:
                    budget = json.loads(captured[str(budget_path.relative_to(native.ROOT))])
                    summary["budget_qualification"] = check_budgets(report, budget)
                    summary["status"] = "qualified" if summary["budget_qualification"]["status"] == "passed" else "budget_failed"
    summary["elapsed_seconds"] = time.monotonic() - started
    native.write_json(run / "summary.json", summary)
    native.write_json(output / "summary.json", summary)
    print(json.dumps(summary, indent=2, sort_keys=True), flush=True)
    return 0 if summary["status"] in ("measured", "qualified") else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"ObjectShard benchmark refused: {error}", file=sys.stderr)
        raise SystemExit(1)
