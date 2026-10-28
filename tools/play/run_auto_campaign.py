#!/usr/bin/env python3
"""Retain a source-bound, balanced native reference-worker measurement campaign.

One fresh Godot process/World per row; no retries or positive-scaling gate.
Reference native timings are not desktop rendering or human-feel qualification.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import check_repository
import run_godot_regressions as runner
import run_windows_godot_regressions as windows

COUNTS = [1, 2, 4, 6, 0]
SIZES = [480, 960]
MARKER = "PLAY_AUTO_CAMPAIGN_ROW "
SCHEMA = "play-auto-campaign-v1"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
RUNTIME_CHANGES = {
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "godot/addons/cybersand_native/runtime-provenance.json",
    "godot/addons/cybersand_native/runtime-provenance.linux.json",
}
TESTED = [
    "godot/scripts/worker_benchmark.gd", "godot/tests/run_play_auto_campaign.gd",
    "tools/play/run_auto_campaign.py", "tools/play/test_run_auto_campaign.py",
    "tools/ci/run_godot_regressions.py", "tools/ci/run_windows_godot_regressions.py",
    "tools/ci/godot_process_monitor.py", "tools/ci/godot_timeout_diagnostics.py",
    "tools/ci/physical_progress_watchdog.py", "tools/ci/check_repository.py",
    "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
    "godot/project.godot", "godot/third_party/rapier2d.lock.json",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def unique_object(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON field: " + key)
        result[key] = value
    return result


def load_json(text: str) -> object:
    def invalid_constant(value):
        raise ValueError("Non-finite JSON number: " + value)
    return json.loads(text, object_pairs_hook=unique_object, parse_constant=invalid_constant)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def integer(value: object, minimum: int = 0) -> bool:
    return type(value) is int and value >= minimum


def number(value: object, minimum: float = 0.0) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def stats(values: list[float]) -> dict:
    require(bool(values) and all(number(v) for v in values), "Invalid timing values")
    ordered = sorted(values)
    return {"count": len(values), "mean": sum(values) / len(values),
            "p50": ordered[math.ceil(len(values) * .50) - 1],
            "p95": ordered[math.ceil(len(values) * .95) - 1],
            "p99": ordered[math.ceil(len(values) * .99) - 1], "max": ordered[-1]}


def plan(config: dict) -> list[dict]:
    """Every count occupies every order position once in each five-repeat block."""
    result = []
    for repeat in range(config["repetitions"]):
        counts = COUNTS[repeat % len(COUNTS):] + COUNTS[:repeat % len(COUNTS)]
        # Also alternate which workload size runs first within each count.
        sizes = SIZES if repeat % 2 == 0 else list(reversed(SIZES))
        for order, requested in enumerate(counts):
            for side in sizes:
                result.append({"id": f"r{repeat:02d}-o{order}-{side}-w{requested}",
                               "repeat": repeat, "order": order, "side": side,
                               "requested_workers": requested})
    return result


def verify_config(config: dict) -> None:
    require(isinstance(config, dict) and config.get("requested_counts") == COUNTS
            and config.get("sizes") == SIZES and config.get("order") == "cyclic-per-repeat",
            "Unsupported campaign matrix/order")
    require(integer(config.get("repetitions"), 5) and config["repetitions"] <= 20
            and config["repetitions"] % len(COUNTS) == 0,
            "Repetitions must be a balanced multiple of five, from five through twenty")
    require(integer(config.get("warmup_ticks"), 60) and config["warmup_ticks"] <= 1000
            and integer(config.get("ticks"), 120) and config["ticks"] <= 1000
            and config.get("process_timeout_seconds") == 180,
            "Invalid warmup/sample/process bound")


def verify_process(record: dict) -> None:
    require(isinstance(record, dict) and record.get("status") == "passed"
            and type(record.get("returncode")) is int and record["returncode"] == 0
            and record.get("diagnostic_error") is False
            and record.get("launch_error") is None and record.get("capture_error") is None
            and record.get("skip_messages") == []
            and record.get("timeout_kind") is None
            and record.get("timeout_diagnostic_error") is None,
            "Non-passing campaign process")
    require(number(record.get("seconds")) and record.get("timeout_seconds") in (180, 240)
            and isinstance(record.get("command"), list) and bool(record["command"]),
            "Invalid process timing/command")


def verify_row(row: dict, expected: dict, config: dict) -> None:
    require(isinstance(row, dict) and all(row.get(k) == v and type(row.get(k)) is type(v)
            for k, v in expected.items()), "Missing, duplicate or out-of-order campaign row")
    require(row.get("schema") == "play-auto-campaign-row-v1"
            and isinstance(row.get("godot"), dict)
            and all(row["godot"].get(k) == v for k, v in {"major": 4, "minor": 7, "patch": 0, "status": "stable", "build": "official"}.items())
            and str(row["godot"].get("hash", "")).startswith("5b4e0cb0f")
            and isinstance(row.get("cpu_name"), str)
            and bool(row["cpu_name"]) and integer(row.get("logical_processors"), 1)
            and row.get("os") in ("Windows", "Linux") and isinstance(row.get("os_version"), str),
            "Missing actual-host row metadata")
    require(all(row.get(k) is False for k in ("rendered_gameplay_fps_measured",
                "concurrent_execution_measured", "worker_creation_count_measured")),
            "Reference campaign cannot claim gameplay, concurrency or created-thread measurement")
    value = row.get("result", {})
    require(isinstance(value, dict) and value.get("ok") is True
            and value.get("side") == expected["side"]
            and value.get("requested_workers") == expected["requested_workers"]
            and value.get("ticks") == config["ticks"]
            and value.get("warmup_ticks") == config["warmup_ticks"], "Refused or wrong sample")
    capacity = value.get("configured_worker_capacity")
    require(integer(capacity, 1) and capacity <= 32
            and all(type(value.get(k)) is int and value[k] == capacity
                    for k in ("actual_workers", "resolved_workers", "workers"))
            and value.get("readback_consistent") is True
            and value.get("logical_threads") == row["logical_processors"]
            and integer(value.get("auto_workers"), 1)
            and value.get("threaded_runtime") is True
            and value.get("worker_capacity_readback_kind") == "adapter-configured-count"
            and value.get("workers_created_count_measured") is False
            and value.get("concurrent_execution_measured") is False,
            "Invalid configured worker-capacity readback")
    requested = expected["requested_workers"]
    require(capacity == (value["auto_workers"] if requested == 0
                         else min(requested, row["logical_processors"], 32)),
            "Worker resolution disagrees with host policy")
    require(value.get("resolution_source") == ("native-auto-policy" if requested == 0
                                               else "explicit-request-clamped-to-host"),
            "Wrong worker resolution source")
    require(value.get("global_setting_unchanged") is True
            and type(value.get("global_setting_before")) is int
            and value["global_setting_before"] == value.get("global_setting_after"),
            "Campaign mutated process worker settings")
    require(re.fullmatch(r"[0-9a-f]{64}", str(value.get("level_hash", ""))) is not None
            and integer(value.get("moves"), 1) and integer(value.get("maximum_scheduler_jobs"), 1)
            and integer(value.get("maximum_eligible_blocks"), 1)
            and number(value.get("measured_wall_ms"), .000001)
            and number(value.get("completed_hz"), .000001)
            and number(value.get("terminal_export_hash_ms")), "Missing native work/timing/hash")
    samples = value.get("tick_samples", {})
    require(isinstance(samples, dict) and set(samples) == {
        "native_ms", "test_frame_interval_ms", "workers_observed", "parallel_phases"},
        "Missing raw tick samples")
    for key, values in samples.items():
        require(isinstance(values, list) and len(values) == config["ticks"], "Incomplete raw " + key)
    require(all(number(v) for v in samples["native_ms"])
            and sum(samples["native_ms"]) > 0
            and all(number(v, .000001) for v in samples["test_frame_interval_ms"]),
            "Invalid native/test-frame timing sample")
    require(all(integer(v, 1) and v <= capacity for v in samples["workers_observed"])
            and all(integer(v) and v <= 4 for v in samples["parallel_phases"]),
            "Participant/phase samples exceed actual capacity")
    for key, raw in (("native_ms", "native_ms"), ("frame_interval_ms", "test_frame_interval_ms")):
        expected_stats = stats(samples[raw])
        require(isinstance(value.get(key), dict)
                and all(number(value[key].get(k)) and math.isclose(value[key][k], v, rel_tol=1e-6, abs_tol=1e-6)
                        for k, v in expected_stats.items()), "Timing reduction differs from raw samples")
    observed = max(samples["workers_observed"])
    participating_ticks = sum(v > 1 for v in samples["workers_observed"])
    require(value.get("maximum_workers_observed") == observed
            and value.get("worker_participation_ticks") == participating_ticks
            and value.get("parallel_participation") is (observed > 1)
            and value.get("parallel_phase_ticks") == sum(v > 0 for v in samples["parallel_phases"])
            and value.get("parallel_phases") == sum(samples["parallel_phases"]),
            "Participant/phase summary differs from raw samples")
    require(row.get("process", {}).get("timeout_seconds") == 180, "Wrong row process bound")
    verify_process(row["process"])


def reduction(rows: list[dict]) -> list[dict]:
    controls = {(r["repeat"], r["side"]): r["result"]["native_ms"]["mean"]
                for r in rows if r["requested_workers"] == 1}
    result = []
    for side in SIZES:
        for requested in COUNTS:
            selected = [r for r in rows if r["side"] == side and r["requested_workers"] == requested]
            samples = [v for r in selected for v in r["result"]["tick_samples"]["native_ms"]]
            ratios = [controls[(r["repeat"], side)] / r["result"]["native_ms"]["mean"] for r in selected]
            result.append({"side": side, "requested_workers": requested,
                           "repeats": len(selected), "native_ms": stats(samples),
                           "paired_native_mean_ratio_to_serial": stats(ratios),
                           "slower_than_serial_repeats": [r["repeat"] for r, ratio in zip(selected, ratios) if ratio < 1.0],
                           "configured_capacities": sorted({r["result"]["configured_worker_capacity"] for r in selected}),
                           "maximum_workers_observed": max(r["result"]["maximum_workers_observed"] for r in selected)})
    return result


def verify_report(report: dict, expected_source_sha: str | None = None) -> dict:
    require(isinstance(report, dict) and report.get("schema") == SCHEMA
            and report.get("status") == "passed" and report.get("errors") == []
            and report.get("source_drift") == [], "Campaign did not pass without drift")
    require(report.get("platform") in ("windows", "linux")
            and re.fullmatch(r"[0-9a-f]{40}", str(report.get("source_sha", ""))) is not None
            and re.fullmatch(r"[0-9a-f]{40}", str(report.get("source_tree", ""))) is not None
            and (expected_source_sha is None or report["source_sha"] == expected_source_sha),
            "Campaign source/platform identity differs")
    for key in ("native_inputs", "tested_inputs"):
        require(isinstance(report.get(key), dict) and bool(report[key])
                and all(isinstance(p, str) and not p.startswith(("/", "\\")) and ".." not in Path(p).parts
                        and re.fullmatch(r"[0-9a-f]{64}", str(v)) is not None for p, v in report[key].items()),
                "Missing canonical " + key)
    require(set(TESTED).issubset(report["tested_inputs"]), "Campaign apparatus input ledger is incomplete")
    for key in ("native_runtime", "rapier_runtime"):
        value = report.get(key, {})
        require(isinstance(value, dict) and isinstance(value.get("path"), str)
                and re.fullmatch(r"[0-9a-f]{64}", str(value.get("sha256", ""))) is not None
                and integer(value.get("size"), 1024), "Missing materialized " + key)
    source_mode = report.get("runtime_source_mode")
    require((source_mode == "fresh-publisher-build-assertion"
             and report.get("built_runtime_source_assertion") == report["source_sha"])
            or (source_mode == "verified-retained-manifest"
                and re.fullmatch(r"[0-9a-f]{40}", str(report.get("retained_runtime_source", ""))) is not None),
            "Missing native runtime source premise")
    verify_config(report.get("config", {}))
    require(report.get("godot_version") == GODOT_VERSION, "Wrong pinned Godot version")
    rows = report.get("rows", [])
    expected = plan(report["config"])
    require(isinstance(rows, list) and len(rows) == len(expected), "Incomplete campaign row coverage")
    hashes = {}
    metadata = None
    for row, identity in zip(rows, expected):
        verify_row(row, identity, report["config"])
        key = row["side"]
        current = row["result"]["level_hash"]
        require(key not in hashes or hashes[key] == current, "Fixed-input terminal level parity failure")
        hashes[key] = current
        observed_metadata = {k: row[k] for k in ("cpu_name", "logical_processors", "os", "os_version", "godot")}
        require(metadata is None or observed_metadata == metadata, "Host metadata changed between rows")
        require(row["os"].lower() == report["platform"], "Row ran on a different target OS")
        metadata = observed_metadata
    require(report.get("summaries") == reduction(rows), "Campaign summary differs from raw rows")
    require(report.get("concurrent_execution_measured") is False
            and report.get("rendered_gameplay_fps_measured") is False
            and report.get("positive_speedup_required") is False
            and report.get("retries") == 0, "Unsupported qualification claim or retry")
    if any(r["result"]["configured_worker_capacity"] > 1 for r in rows):
        require(any(r["result"]["maximum_workers_observed"] > 1 for r in rows),
                "Eligible campaign observed no actual multiworker task participation")
    return report


def verify_directory(directory: Path, expected_source_sha: str | None = None) -> dict:
    """Validate retained evidence only; stage need not have bundle runtime installed."""
    report = verify_report(load_json((directory / "campaign.json").read_text(encoding="utf-8")), expected_source_sha)
    records = [*report.get("preflight_results", []), *[r["process"] for r in report["rows"]]]
    require(len(report.get("preflight_results", [])) == 1
            and report["preflight_results"][0].get("name") == "import", "Missing fresh import process")
    for record in records:
        verify_process(record)
        relative = record.get("log", "")
        require(isinstance(relative, str) and Path(relative).name == relative and bool(relative), "Unsafe log path")
        log = directory / relative
        require(report.get("log_sha256", {}).get(relative) == runner.sha256(log), "Campaign log hash differs")
        output = log.read_text(encoding="utf-8")
        require("SCRIPT ERROR:" not in output and "ERROR:" not in output
                and re.search(r"\bskipped\b|^\s*SKIP\b", output, re.I | re.M) is None,
                "Campaign log contains diagnostic failure")
    for row in report["rows"]:
        output = (directory / row["process"]["log"]).read_text(encoding="utf-8")
        lines = [line[len(MARKER):] for line in output.splitlines() if line.startswith(MARKER)]
        require(len(lines) == 1, "Missing or duplicate raw row marker")
        raw = load_json(lines[0])
        require(raw == {k: v for k, v in row.items() if k not in ("id", "process")},
                "Retained raw row differs from process log")
    return report


def source_identity() -> dict:
    changes = set(git("diff", "--name-only", "HEAD").splitlines())
    require(changes.issubset(RUNTIME_CHANGES), "Source checkout has tracked local changes: " + str(sorted(changes - RUNTIME_CHANGES)))
    untracked = git("ls-files", "--others", "--exclude-standard").splitlines()
    require(not any(p.endswith((".gd", ".py", ".cpp", ".hpp", ".yml", ".json")) for p in untracked),
            "Source checkout contains untracked implementation inputs")
    canonical = lambda p: digest((ROOT / p).read_bytes().replace(b"\r\n", b"\n"))
    return {"source_sha": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}"),
            "native_inputs": {p: canonical(p) for p in sorted(windows.native_input_paths(ROOT))},
            "tested_inputs": {p: canonical(p) for p in TESTED}}


def runtime_identity(path: Path) -> dict:
    require(path.is_file() and path.stat().st_size >= 1024, "Runtime is unavailable or an LFS pointer: " + str(path))
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": runner.sha256(path), "size": path.stat().st_size}


def host_conditions() -> dict:
    facts = {"python": sys.version, "platform": platform.platform(), "processor": platform.processor(),
             "cpu_count": os.cpu_count(), "load_average": list(os.getloadavg()) if hasattr(os, "getloadavg") else None,
             "affinity": None, "priority": None,
             "affinity_note": "Launcher observation only; engine child affinity/priority are not directly measured. Harness changes neither",
             "external_load_control": "uncontrolled; no claim of exclusive CPU ownership",
             "cpu_frequency_control": "not controlled or inferred",
             "github_run_id": os.environ.get("GITHUB_RUN_ID"), "github_job": os.environ.get("GITHUB_JOB")}
    if hasattr(os, "sched_getaffinity"):
        facts["affinity"] = sorted(os.sched_getaffinity(0))
        facts["priority"] = os.getpriority(os.PRIO_PROCESS, 0)
    elif sys.platform == "win32":
        try:
            import ctypes
            kernel = ctypes.windll.kernel32
            kernel.GetCurrentProcess.restype = ctypes.c_void_p
            process = kernel.GetCurrentProcess()
            process_mask, system_mask = ctypes.c_size_t(), ctypes.c_size_t()
            kernel.GetProcessAffinityMask.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_size_t)]
            if kernel.GetProcessAffinityMask(process, ctypes.byref(process_mask), ctypes.byref(system_mask)):
                facts["affinity"] = {"process_mask": hex(process_mask.value), "system_mask": hex(system_mask.value),
                                     "scope": "current processor group; cross-group scheduling unmeasured"}
            kernel.GetPriorityClass.argtypes = [ctypes.c_void_p]
            facts["priority"] = kernel.GetPriorityClass(process)
        except (OSError, AttributeError) as exc:
            facts["scheduling_unavailable"] = str(exc)
    return facts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--built-runtime-source", help="Explicit fresh-build source assertion for the publisher; must equal HEAD")
    parser.add_argument("--warmup", type=int, default=60)
    parser.add_argument("--ticks", type=int, default=120)
    parser.add_argument("--repetitions", type=int, default=5)
    args = parser.parse_args()
    # Never replace retained evidence; use a fresh output directory per attempt.
    args.output.mkdir(parents=True, exist_ok=False)
    report = {"schema": SCHEMA, "status": "failed", "errors": [], "source_drift": [],
              "platform": "windows" if sys.platform == "win32" else "linux",
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
              "command": [sys.executable, *sys.argv], "host_conditions": host_conditions(),
              "config": {"requested_counts": COUNTS, "sizes": SIZES, "repetitions": args.repetitions,
                         "warmup_ticks": args.warmup, "ticks": args.ticks,
                         "process_timeout_seconds": 180, "order": "cyclic-per-repeat"},
              "preflight_results": [], "rows": [], "log_sha256": {}, "summaries": [],
              "concurrent_execution_measured": False, "rendered_gameplay_fps_measured": False,
              "positive_speedup_required": False, "retries": 0,
              "method": "Fixed Sand/Water reference workload; fresh process/World per row. Native timings exclude copied statistics/export/hash. Test frame intervals and completed_hz include harness scheduling/readback, not gameplay rendering. Capacity getter is configured count; task participants do not prove concurrent execution. Paired ratios use the serial row of the same repeat/size; no outlier is discarded."}
    before = None
    try:
        require(sys.platform == "win32" or sys.platform.startswith("linux"), "Unsupported target platform")
        verify_config(report["config"])
        before = source_identity()
        report.update(before)
        native, rapier = runner.runtime_paths()
        report["native_runtime"] = runtime_identity(native)
        report["rapier_runtime"] = runtime_identity(rapier)
        if args.built_runtime_source:
            require(args.built_runtime_source == report["source_sha"], "Fresh-build source assertion differs from HEAD")
            report["runtime_source_mode"] = "fresh-publisher-build-assertion"
            report["built_runtime_source_assertion"] = args.built_runtime_source
        else:
            manifest_name = "runtime-provenance.json" if sys.platform == "win32" else "runtime-provenance.linux.json"
            manifest = load_json((native.parent.parent / manifest_name).read_text(encoding="utf-8"))
            require(not check_repository.verify_runtime(ROOT, manifest), "Retained runtime source/bytes do not match; rebuild through scoped publication")
            require(manifest.get("source_inputs") == before["native_inputs"], "Retained native input inventory differs")
            report["runtime_source_mode"] = "verified-retained-manifest"
            report["retained_runtime_source"] = manifest.get("source_commit")
        rapier_manifest = load_json((rapier.parent.parent / ("runtime-provenance." + report["platform"] + ".json")).read_text(encoding="utf-8"))
        require(not check_repository.verify_runtime(ROOT, rapier_manifest), "Selected Rapier source/bytes do not match retained provenance")
        report["godot_version"] = subprocess.check_output([args.godot, "--version"], text=True).strip()
        require(report["godot_version"] == GODOT_VERSION, "Pinned Godot version differs")
        env = os.environ.copy()
        env["CYBERSAND_SOURCE_REVISION"] = report["source_sha"]
        record, failed = runner.run_case(args.godot, runner.Case("import", ("--editor", "--import", "--quit"), 240, 0), args.output, "campaign-preflight", env=env)
        report["preflight_results"].append(record)
        report["log_sha256"][record["log"]] = runner.sha256(args.output / record["log"])
        require(not failed, "Campaign import failed")
        for identity in plan(report["config"]):
            flags = ("--script", "res://tests/run_play_auto_campaign.gd", "--",
                     f"--workers={identity['requested_workers']}", f"--side={identity['side']}",
                     f"--ticks={args.ticks}", f"--warmup={args.warmup}",
                     f"--repeat={identity['repeat']}", f"--order={identity['order']}")
            record, failed = runner.run_case(args.godot, runner.Case(identity["id"], flags, 180, 0), args.output, "native-reference-row", env=env)
            report["log_sha256"][record["log"]] = runner.sha256(args.output / record["log"])
            raw = (args.output / record["log"]).read_text(encoding="utf-8")
            lines = [line[len(MARKER):] for line in raw.splitlines() if line.startswith(MARKER)]
            row = {**identity, "process": record}
            report["rows"].append(row)  # retain the failing record before validation
            require(not failed, "Campaign row process failed: " + identity["id"])
            require(len(lines) == 1, "Missing or duplicate raw row result: " + identity["id"])
            value = load_json(lines[0])
            require(isinstance(value, dict), "Raw row is not an object")
            row.update(value)
            verify_row(row, identity, report["config"])
            # Retain completed rows immediately if a later process fails.
            runner.write_json(args.output / "campaign.json", report)
        report["summaries"] = reduction(report["rows"])
        require(source_identity() == before, "Source inputs changed during campaign")
        require(runtime_identity(native) == report["native_runtime"]
                and runtime_identity(rapier) == report["rapier_runtime"], "Runtime bytes changed during campaign")
        report["status"] = "passed"
        verify_report(report, report["source_sha"])
    except (RuntimeError, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as exc:
        report["status"] = "failed"
        report["errors"].append(str(exc))
        if before is not None:
            try:
                if source_identity() != before:
                    report["source_drift"].append("Source/input identity changed during execution")
            except (RuntimeError, OSError, subprocess.SubprocessError) as drift:
                report["source_drift"].append(str(drift))
    report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    runner.write_json(args.output / "campaign.json", report)
    if report["status"] == "passed":
        try:
            verify_directory(args.output, report["source_sha"])
        except (RuntimeError, OSError, ValueError, TypeError, KeyError) as exc:
            report["status"] = "failed"
            report["errors"].append(str(exc))
            runner.write_json(args.output / "campaign.json", report)
    print("PLAY_AUTO_CAMPAIGN_RESULT " + json.dumps({"status": report["status"],
          "source_sha": report.get("source_sha"), "platform": report["platform"],
          "rows": len(report["rows"]), "errors": report["errors"],
          "report_sha256": runner.sha256(args.output / "campaign.json")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
