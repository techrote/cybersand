#!/usr/bin/env python3
"""Build and qualify #361-A native primitive controls, never desktop gameplay.

Each invocation owns a new output directory. An interrupted or failed invocation
cannot reuse a previous executable, stdout, or successful result record.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    "native/src/world.cpp",
    "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp",
    "native/src/settled_world_discovery.cpp",
    "native/tests/test_metered_liquid_drain.cpp",
]
PROFILES = (
    "water-in-3", "water-in-8", "water-fm-3", "water-fm-8",
    "brine-cy-8", "brine-in-8", "water-cy-3", "water-cy-8",
)
CONTROLS = {
    "refusal.complete-preflight": {
        "refusals": 16, "motion_witness": True, "spatial_wall_checks": True,
    },
    "hazard.raw-empty-under-mask": {
        "profiles": 8, "guarded_refusal_preserves_state": True, "raw_erasure_removes_stored_material": True,
    },
    "refusal.policy-and-fractional-whole-cell": {
        "water_quanta": [7, 255], "pressure_world_refused": True, "oil_in_refused": True,
        "water_cy_full_cells_only": True,
    },
    "capacity.resident-erase-and-failed-tick": {
        "resident_erase_at_chunk_limit": True, "failed_tick_quarantined": True, "clear_recovery": True,
    },
    "lifecycle.native-retirement-persistence-reconstruction": {
        "profiles": 8, "continuation_ticks_per_profile": 8,
        "native_motion_witness": True, "inertial_ledger_continuation_parity": True,
        "application_lifecycle_tested": False,
    },
    "oracle.complete-resident-census": {
        "resident_cells": 131072, "resident_chunks": 8, "negative_controls": 5,
    },
}
EXACT_FIELDS = {
    "case_id", "status", "cells", "water_units", "brine_cells", "initial_quantity",
    "remaining_quantity", "remaining_resource", "native_water_sink_delta", "mass_bits", "policy_hash",
}
WORKER_FIELDS = {
    "case_id", "status", "ticks_per_arm", "initial_quantity", "removed_quantity",
    "remaining_quantity", "operations_per_arm", "maximum_cells_per_operation", "workers1_observed",
    "workers4_observed", "phase_jobs_workers4", "moved_cells_after_stop_workers1",
    "moved_cells_after_stop_workers4", "water_units", "brine_cells", "physical_hash_parity",
    "flow_initial_water_model", "inertial_ledger_parity", "resident_census_cells",
    "resident_census_ticks", "resident_domain_chunk_count",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def integer(value: object, label: str, low: int = 0, high: int = (1 << 64) - 1) -> int:
    require(type(value) is int and low <= value <= high, f"{label}: invalid integer")
    return value


def exact(value: object, expected: object, label: str) -> None:
    require(type(value) is type(expected) and value == expected, f"{label}: value/type mismatch")
    if isinstance(expected, list):
        for index, item in enumerate(expected):
            exact(value[index], item, f"{label}[{index}]")


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON field: {key}")
        result[key] = value
    return result


def parse_result(raw: str) -> dict:
    def invalid_constant(value: str) -> None:
        raise ValueError(f"nonfinite JSON constant: {value}")
    result = json.loads(raw, object_pairs_hook=unique_object, parse_constant=invalid_constant)
    require(type(result) is dict and set(result) == {
        "schema", "scope", "production_application_executed", "status", "assertions", "cases",
    }, "result schema fields differ")
    exact(result["schema"], "metered-drain-native-primitives-v1", "schema")
    exact(result["scope"], "native-core-only", "scope")
    exact(result["production_application_executed"], False, "application scope")
    exact(result["status"], "pass", "status")
    integer(result["assertions"], "assertions", 1000)
    expected_ids = set(CONTROLS) | {
        f"exact.{profile}.{cells}" for profile in PROFILES for cells in (1, 16)
    } | {f"workers.{profile}" for profile in PROFILES}
    rows = result["cases"]
    require(type(rows) is list and len(rows) == len(expected_ids), "incomplete native result census")
    seen = set()
    for row in rows:
        require(type(row) is dict and type(row.get("case_id")) is str, "invalid case row")
        case = row["case_id"]
        require(case in expected_ids and case not in seen, "unknown or duplicate case")
        seen.add(case)
        exact(row.get("status"), "pass", case)
        if case in CONTROLS:
            expected = CONTROLS[case]
            require(set(row) == {"case_id", "status", *expected}, f"{case}: fields differ")
            for key, value in expected.items():
                exact(row[key], value, f"{case}.{key}")
            continue
        if case.startswith("exact."):
            require(set(row) == EXACT_FIELDS, f"{case}: fields differ")
            _, profile, count_text = case.split(".")
            count = int(count_text)
            bits = int(profile[-1])
            maximum = (1 << bits) - 1
            water = profile.startswith("water")
            expected = count if not water else count * maximum if "-fm-" not in profile else sum(
                1 + (index * 17 + 2) % (maximum - 1) for index in range(count)
            )
            for key, value in {
                "cells": count, "mass_bits": bits, "initial_quantity": expected, "remaining_quantity": 0,
                "remaining_resource": 11, "water_units": expected if water else 0,
                "brine_cells": 0 if water else expected, "native_water_sink_delta": expected if water else 0,
            }.items():
                exact(row[key], value, f"{case}.{key}")
            require(type(row["policy_hash"]) is str and re.fullmatch(r"[0-9a-f]{64}", row["policy_hash"]) is not None,
                    "invalid observed policy hash")
        else:
            require(set(row) == WORKER_FIELDS, f"{case}: fields differ")
            profile = case.removeprefix("workers.")
            water = profile.startswith("water")
            initial = 8 * 18 * 9 * (((1 << int(profile[-1])) - 1) if water else 1)
            exact(row["initial_quantity"], initial, "flow initial quantity")
            removed = integer(row["removed_quantity"], "flow removal", 1, initial - 1)
            remaining = integer(row["remaining_quantity"], "flow remaining", 1, initial - 1)
            require(removed + remaining == initial, "flow ledger fails to close")
            for key, value in {
                "ticks_per_arm": 64, "maximum_cells_per_operation": 16, "workers1_observed": 1,
                "physical_hash_parity": True, "flow_initial_water_model": "whole-cells-for-matched-geometry",
                "inertial_ledger_parity": True, "resident_census_cells": 131072,
                "resident_census_ticks": [0, 8, 20, 32, 64], "resident_domain_chunk_count": 8,
                "water_units": removed if water else 0, "brine_cells": 0 if water else removed,
            }.items():
                exact(row[key], value, f"{case}.{key}")
            integer(row["workers4_observed"], "actual four-worker claimants", 2, 4)
            integer(row["operations_per_arm"], "operations", 1, 40)
            integer(row["phase_jobs_workers4"], "phase jobs", 1)
            integer(row["moved_cells_after_stop_workers1"], "post-stop movement")
            integer(row["moved_cells_after_stop_workers4"], "post-stop movement")
            if water and "-fm-" not in profile:
                require(removed % ((1 << int(profile[-1])) - 1) == 0, "whole-cell family removed fractional Water")
    require(seen == expected_ids, "missing registered native controls")
    return result


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*arguments: str) -> str:
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()


def write_record(directory: Path, record: dict) -> None:
    temporary = directory / "record.pending.json"
    temporary.write_text(json.dumps(record, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    os.replace(temporary, directory / "record.json")


def command(argv: list[str], timeout: int, directory: Path, label: str) -> int:
    with (directory / f"{label}.stdout.log").open("wb") as out, (directory / f"{label}.stderr.log").open("wb") as err:
        proc = subprocess.Popen(argv, cwd=ROOT, stdout=out, stderr=err, start_new_session=os.name == "posix")
        try:
            return proc.wait(timeout)
        except subprocess.TimeoutExpired:
            if os.name == "posix":
                os.killpg(proc.pid, signal.SIGKILL)
            else:
                proc.kill()
            proc.wait()
            err.write(b"\nrunner timeout: this invocation is not a pass\n")
            return 124


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True, help="new directory, never an earlier evidence directory")
    parser.add_argument("--cxx", default="g++")
    parser.add_argument("--compile-timeout", type=int, default=600)
    parser.add_argument("--run-timeout", type=int, default=240)
    args = parser.parse_args()
    directory = args.output_dir.resolve()
    try:
        directory.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        print(f"Output directory refused: {error}", file=sys.stderr)
        return 1
    record = {
        "schema": "metered-drain-native-run-v1",
        "scope": "native-core-only", "production_application_executed": False,
        "started_at_utc": utc_now(), "status": "not-run",
        "limitations": [
            "Native test-side preflight, not execution of the production GDScript implementation",
            "No Godot, physical equipment, real Rapier, desktop input or session cancellation qualification",
            "Direct native fixtures do not issue a prepared-World construction receipt",
            "Elapsed times include checks/census/hash work; not a drain-overhead or native-tick benchmark",
            "No arbitrary near-overflow imported-history guarantee or native exception-containment claim",
        ],
    }
    write_record(directory, record)
    executable = directory / ("metered_drain.exe" if os.name == "nt" else "metered_drain")
    inputs: list[str] = []
    compiler: Path | None = None
    try:
        require(args.compile_timeout > 0 and args.run_timeout > 0, "timeouts must be positive")
        found = shutil.which(args.cxx)
        require(found is not None, "compiler unavailable")
        compiler = Path(found).resolve()
        inputs = sorted(set(SOURCES + [
            str(path.relative_to(ROOT)) for folder in ("native/include", "native/src")
            for path in (ROOT / folder).rglob("*") if path.is_file() and path.suffix in (".hpp", ".inc")
        ]))
        record.update({
            "git_commit": git("rev-parse", "HEAD"), "git_tree": git("rev-parse", "HEAD^{tree}"),
            "native_status": git("status", "--porcelain=v1", "--", "native", "tools/lcb/run_metered_drain_native.py"),
            "platform": platform.platform(), "machine": platform.machine(), "python": platform.python_version(),
            "compiler": str(compiler), "compiler_sha256": sha(compiler),
            "compiler_version": subprocess.check_output([str(compiler), "--version"], text=True).splitlines()[0],
            "input_sha256": {name: sha(ROOT / name) for name in inputs},
            "runner_sha256": sha(Path(__file__)),
        })
        argv = [str(compiler), "-std=c++20", "-O1", "-g", "-pthread", "-Wall", "-Wextra", "-Wpedantic",
                "-I", "native/include", *SOURCES, "-o", str(executable)]
        record["compile_command"] = argv
        record["timeouts_seconds"] = {"compile": args.compile_timeout, "run": args.run_timeout}
        started = time.monotonic()
        code = command(argv, args.compile_timeout, directory, "compile")
        record.update(compile_exit=code, compile_seconds=time.monotonic() - started)
        require(code == 0, f"compile failed: exit {code}")
        record["executable_sha256"] = sha(executable)
        record["run_command"] = [str(executable)]
        started = time.monotonic()
        code = command([str(executable)], args.run_timeout, directory, "run")
        record.update(run_exit=code, run_seconds=time.monotonic() - started)
        require(code == 0, f"run failed: exit {code}")
        record["results"] = parse_result((directory / "run.stdout.log").read_text(encoding="utf-8"))
        record["status"] = "pass"
    except (Exception, KeyboardInterrupt) as error:
        record.update(status="failed", error=f"{type(error).__name__}: {error}")
    try:
        if "input_sha256" in record:
            record["input_sha256_after"] = {name: sha(ROOT / name) for name in inputs}
            require(record["input_sha256_after"] == record["input_sha256"], "native source changed during execution")
            require(sha(Path(__file__)) == record["runner_sha256"], "runner changed during execution")
            require(sha(compiler) == record["compiler_sha256"], "compiler changed during execution")
            record["inputs_unchanged"] = True
        if "executable_sha256" in record:
            require(sha(executable) == record["executable_sha256"], "executable changed during execution")
            record["executable_unchanged"] = True
        record["log_sha256"] = {p.name: sha(p) for p in directory.glob("*.log")}
    except Exception as error:
        record.update(status="custody-failed", custody_error=f"{type(error).__name__}: {error}")
    record["finished_at_utc"] = utc_now()
    write_record(directory, record)
    print(json.dumps({"status": record["status"], "record": str(directory / "record.json"), "scope": record["scope"]}))
    return 0 if record["status"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
