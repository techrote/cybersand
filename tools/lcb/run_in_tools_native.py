#!/usr/bin/env python3
"""Build/run current-native #361 primitive probes; never a gameplay acceptance gate.

Uses an isolated executable and only test code. No production source, runtime
publication, adapter, active comparison host, or solver default is modified.
Outputs source/compiler/executable custody and retains stdout/stderr on failure.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    "native/src/world.cpp", "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp", "native/src/settled_world_discovery.cpp",
    "native/tests/test_in_tools_361_contract.cpp",
]
RESULT_SCHEMA = "in-tools-native-primitives-v2"
RECORD_SCHEMA = "in-tools-native-run-v1"
MAX_U64 = (1 << 64) - 1
CENSUS_NEGATIVE_CONTROLS = ["water-quantity-mismatch", "material-count-mismatch",
                            "escaped-liquid", "missing-wall", "extra-chunk"]
CENSUS_TICKS = [0, 8, 24, 32, 64, 224]
SINGLETONS = {
    "native.ingress.v1": {"water_quanta": [7, 255], "brine_quantum_cells": 1},
    "native.edit-refusals.v1": {
        "raw_erase_under_mask": True, "raw_replace_wall": True,
        "guarded_tool_api_exists": False,
    },
    "native.nozzle-no-input.v1": {
        "source_initial_velocity": [0, 0], "directed_gameplay_inlet_available": False,
    },
    "native.capacity-quarantine.v1": {"no_diagnostic_velocity_seed": True},
    "native.mask-barrier.v1": {
        "barrier_kind": "transient-native-mask-not-Rapier", "ticks_per_arm": 64,
    },
    "native.sink-exhaustion.v1": {"zero_removal_on_second_call": True},
    "native.owner-reconstruction.v1": {
        "restore_and_continue_ticks_per_arm": 8, "fresh_setup_pairs_per_arm": 3,
        "restore_inertial_ledger_parity": True,
    },
}
LEAK = "native.leak-closure-reopen.v1"
DRAIN = "native.drain-active-stopped-empty.v1"
FLOW_FIELDS = {
    "case_id", "status", "material", "family", "width", "ticks", "initial_quantity",
    "remaining_quantity", "removed_quantity", "first_reservoir_depletion_tick", "close_applied_tick",
    "close_refusals", "phase_jobs", "workers1_observed", "workers4_observed", "parity",
    "inertial_ledger_parity", "census_completed_ticks", "census_cells", "census_chunks",
    "restored_census_completed_tick",
    "inertial_slot_bytes", "inertial_slot_size", "inertial_total_component_bytes",
    "resident_cells_bytes", "instrumented_elapsed_ms_workers1", "instrumented_elapsed_ms_workers4",
}
EXPECTED_FLOWS = {
    (case, material, family, width)
    for case in (LEAK, DRAIN)
    for material, baseline in (("Water", "freemass_v1"), ("Brine", "cellular_yield_v1"))
    for family in (baseline, "inertial_cellular_v1")
    for width in (1, 4)
}


def literal(value: object, expected: object, label: str) -> None:
    """JSON equality with booleans kept distinct from integer quantities."""
    if type(value) is not type(expected) or value != expected:
        raise ValueError(f"{label}: expected {expected!r}")
    if isinstance(expected, list):
        for index, item in enumerate(expected):
            literal(value[index], item, f"{label}[{index}]")


def fields(value: object, expected: set[str], label: str) -> None:
    if type(value) is not dict or set(value) != expected:
        raise ValueError(f"{label}: fields do not match the registered schema")


def integer(value: object, label: str, minimum: int = 0, maximum: int = MAX_U64) -> int:
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"{label}: expected integer in {minimum}..{maximum}")
    return value


def validate_native_result(result: object) -> None:
    """Check the complete fixed probe registration, not just its top-level pass word.

    These checks corroborate the executable's assertions; supplied JSON alone
    cannot authenticate a native run, gameplay receipt or physics law.
    """
    fields(result, {"schema", "scope", "production_tool_implemented", "cases", "checks", "status",
                    "census_negative_controls"}, "result")
    literal(result["schema"], RESULT_SCHEMA, "schema")
    literal(result["scope"], "native-core-only", "scope")
    literal(result["production_tool_implemented"], False, "production_tool_implemented")
    literal(result["status"], "pass", "status")
    literal(result["census_negative_controls"], CENSUS_NEGATIVE_CONTROLS, "census_negative_controls")
    integer(result["checks"], "checks", 32 * 224)
    cases = result["cases"]
    if type(cases) is not list or len(cases) != len(SINGLETONS) + len(EXPECTED_FLOWS):
        raise ValueError("cases: expected seven singleton probes and sixteen flow pairs")
    seen_singletons: set[str] = set()
    seen_flows: set[tuple] = set()
    for case in cases:
        if type(case) is not dict or type(case.get("case_id")) is not str:
            raise ValueError("case: missing string case_id")
        case_id = case["case_id"]
        literal(case.get("status"), "pass", f"{case_id}.status")
        if case_id in SINGLETONS:
            expected = SINGLETONS[case_id]
            fields(case, {"case_id", "status", *expected}, case_id)
            if case_id in seen_singletons:
                raise ValueError(f"duplicate singleton: {case_id}")
            seen_singletons.add(case_id)
            for key, value in expected.items():
                literal(case[key], value, f"{case_id}.{key}")
            continue
        if case_id not in (LEAK, DRAIN):
            raise ValueError(f"unknown case: {case_id}")
        fields(case, FLOW_FIELDS, case_id)
        if type(case["material"]) is not str or type(case["family"]) is not str:
            raise ValueError(f"{case_id}: material/family must be strings")
        width = integer(case["width"], "width", 1, 4)
        key = (case_id, case["material"], case["family"], width)
        if key not in EXPECTED_FLOWS or key in seen_flows:
            raise ValueError(f"unregistered or duplicate flow pair: {key}")
        seen_flows.add(key)
        literal(case["ticks"], 224, "ticks")
        literal(case["parity"], True, "parity")
        literal(case["inertial_ledger_parity"], True, "inertial_ledger_parity")
        literal(case["census_completed_ticks"], CENSUS_TICKS, "census_completed_ticks")
        literal(case["census_cells"], 768 * 512, "census_cells")
        literal(case["census_chunks"], 24, "census_chunks")
        literal(case["restored_census_completed_tick"], 232, "restored_census_completed_tick")
        expected_initial = 8 * 18 * 9 * (255 if case["material"] == "Water" else 1)
        literal(case["initial_quantity"], expected_initial, "initial_quantity")
        remaining = integer(case["remaining_quantity"], "remaining_quantity", 0, expected_initial)
        removed = integer(case["removed_quantity"], "removed_quantity", 0, expected_initial)
        if remaining + removed != expected_initial:
            raise ValueError("flow quantity does not balance")
        if case["material"] == "Water" and case["family"] == "inertial_cellular_v1":
            if remaining % 255 or removed % 255:
                raise ValueError("IN Water flow quantities must contain complete 255-unit cells")
        first_flow = integer(case["first_reservoir_depletion_tick"], "first_reservoir_depletion_tick", 1, 224)
        closed = integer(case["close_applied_tick"], "close_applied_tick", 0, 199)
        refusals = integer(case["close_refusals"], "close_refusals", 0, 175)
        if case_id == LEAK:
            # The driver opens at boundary 8, tries closure on every boundary
            # from 24, and reopens eight ticks after the successful close.
            # There is no separately observed reopen receipt in this schema.
            if removed != 0 or not 9 <= first_flow <= closed or closed < 24:
                raise ValueError("leak must flow, close and retain its full quantity")
            if refusals != closed - 24 or closed + 8 >= 224:
                raise ValueError("leak closure/reopen schedule does not match the driver")
        elif closed != 0 or refusals != 0 or first_flow != 1 or removed == 0:
            raise ValueError("drain must remove liquid at its first pulse without valve events")
        integer(case["phase_jobs"], "phase_jobs", 1)
        literal(case["workers1_observed"], 1, "workers1_observed")
        # This deliberately busy eight-tank registration must exercise parallel
        # participation. Preserve the actual count; it is not utilization.
        integer(case["workers4_observed"], "workers4_observed", 2, 4)
        literal(case["inertial_slot_size"], 6, "inertial_slot_size")
        slots = integer(case["inertial_slot_bytes"], "inertial_slot_bytes")
        if case["family"] == "inertial_cellular_v1":
            if slots == 0 or slots % 6:
                raise ValueError("IN slot storage must contain complete six-byte slots")
        elif slots != 0:
            raise ValueError("non-IN control unexpectedly reports allocated IN slots")
        integer(case["inertial_total_component_bytes"], "inertial_total_component_bytes", max(1, slots))
        integer(case["resident_cells_bytes"], "resident_cells_bytes", 1)
        for name in ("instrumented_elapsed_ms_workers1", "instrumented_elapsed_ms_workers4"):
            value = case[name]
            if type(value) not in (int, float):
                raise ValueError(f"{name}: expected a finite positive number")
            try:
                finite = math.isfinite(value)
            except OverflowError:
                finite = False
            if not finite or value <= 0:
                raise ValueError(f"{name}: expected a finite positive number")
    if seen_singletons != set(SINGLETONS) or seen_flows != EXPECTED_FLOWS:
        raise ValueError("result omits a registered probe or flow pair")


def parse_native_result(raw: str) -> dict:
    def unique_object(pairs: list[tuple[str, object]]) -> dict:
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(f"duplicate JSON key: {key}")
            value[key] = item
        return value

    def invalid_constant(value: str) -> None:
        raise ValueError(f"nonfinite JSON number: {value}")

    result = json.loads(raw, object_pairs_hook=unique_object, parse_constant=invalid_constant)
    validate_native_result(result)
    return result


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def write_record(output: Path, record: dict) -> None:
    """Replace only the selected run record, without exposing half-written JSON."""
    temporary = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=output.parent,
                                         prefix=f"{output.name}.", suffix=".tmp", delete=False) as out:
            temporary = Path(out.name)
            json.dump(record, out, indent=2, sort_keys=True, allow_nan=False)
            out.write("\n")
        os.replace(temporary, output)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args: list[str], timeout: int, stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        try:
            return subprocess.run(args, cwd=ROOT, stdout=out, stderr=err,
                                  check=False, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            err.write(b"\nrunner timeout; result is not a pass\n")
            return 124


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/in-tools-361/native.json")
    parser.add_argument("--build-dir", type=Path, default=ROOT / "build/in-tools-361")
    parser.add_argument("--cxx", default="g++")
    parser.add_argument("--compile-timeout", type=int, default=600)
    parser.add_argument("--run-timeout", type=int, default=600)
    args = parser.parse_args()
    build = args.build_dir.resolve()
    output = args.output.resolve()
    executable = build / ("in_tools_361.exe" if os.name == "nt" else "in_tools_361")
    reserved = {executable, *(build / name for name in
                ("compile.stdout.log", "compile.stderr.log", "run.stdout.json", "run.stderr.log"))}
    try:
        if output in reserved:
            raise ValueError("output record must not replace an executable or raw log")
        if output.exists():
            prior = json.loads(output.read_text(encoding="utf-8"))
            if type(prior) is not dict or prior.get("schema") != RECORD_SCHEMA:
                raise ValueError("refusing to overwrite an existing non-run-record file")
        output.parent.mkdir(parents=True, exist_ok=True)
    except (OSError, ValueError) as error:
        print(f"IN-TOOLS output refused: {error}", file=sys.stderr)
        return 1
    def git(*arguments: str) -> str:
        return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()
    record = {
        "schema": RECORD_SCHEMA, "scope": "native-core-only",
        "production_tool_implemented": False,
        "limitations": ["No Godot, Rapier, desktop, Web, human feel, or input-lifecycle qualification",
                        "Guarded closure/drain protocol exists only in the test driver",
                        "Elapsed time includes full hashes/censuses/assertions; not a kernel or FPS benchmark",
                        "Configured workers are separate from observed task claimants"],
        "started_at_utc": utc_now(), "finished_at_utc": None,
        "status": "not-run",
    }
    # Retire any previous pass before compiler discovery, metadata capture or
    # execution. A crash/interruption can leave not-run, never an old pass.
    write_record(output, record)
    inputs: list[str] = []
    attempted_logs: list[Path] = []
    run_attempted = False
    try:
        if args.compile_timeout < 1 or args.run_timeout < 1:
            raise ValueError("timeouts must be positive seconds")
        compiler = shutil.which(args.cxx)
        if not compiler:
            raise ValueError(f"compiler unavailable: {args.cxx}")
        compiler = str(Path(compiler).resolve())
        build.mkdir(parents=True, exist_ok=True)
        inputs = sorted(set(SOURCES + [str(p.relative_to(ROOT)) for p in
                        (ROOT / "native/include/cybersand").glob("*") if p.is_file()] +
                        [str(p.relative_to(ROOT)) for p in (ROOT / "native/src").glob("*.inc")] +
                        [str(p.relative_to(ROOT)) for p in (ROOT / "native/src").glob("*.hpp")]))
        record.update({
            "git_commit": git("rev-parse", "HEAD"), "git_tree": git("rev-parse", "HEAD^{tree}"),
            "platform": platform.platform(), "python": platform.python_version(),
            "compiler": compiler, "compiler_sha256": sha(Path(compiler)),
            "compiler_version": subprocess.check_output([compiler, "--version"], text=True).splitlines()[0],
            "input_sha256": {p: sha(ROOT / p) for p in inputs},
            "runner_sha256": sha(Path(__file__)),
            "production_delta": git("diff", "HEAD", "--", "native/src", "native/include"),
        })
        compile_args = [compiler, "-std=c++20", "-O1", "-g", "-pthread", "-Wall", "-Wextra", "-Wpedantic",
                        "-I", "native/include", *SOURCES, "-o", str(executable)]
        record["compile_command"] = compile_args
        record["run_command"] = [str(executable)]
        record["timeouts_seconds"] = {"compile": args.compile_timeout, "run": args.run_timeout}
        # A successful wrapper/compiler exit is insufficient evidence that it
        # produced this run's binary. Retire any old output before compiling;
        # hashing below then fails closed if no fresh executable was written.
        executable.unlink(missing_ok=True)
        attempted_logs.extend([build/"compile.stdout.log", build/"compile.stderr.log"])
        started = time.monotonic()
        code = command(compile_args, args.compile_timeout, *attempted_logs[-2:])
        record["compile_seconds"] = time.monotonic()-started
        record["compile_exit"] = code
        if code:
            record["status"] = "compile-failed"
        else:
            record["executable_sha256"] = sha(executable)
            attempted_logs.append(build/"run.stderr.log")
            run_attempted = True
            started = time.monotonic()
            code = command([str(executable)], args.run_timeout, build/"run.stdout.json", attempted_logs[-1])
            record["run_seconds"] = time.monotonic()-started
            record["run_exit"] = code
            if code:
                record["status"] = "run-failed"
            else:
                try:
                    record["results"] = parse_native_result((build/"run.stdout.json").read_text(encoding="utf-8"))
                    record["status"] = "pass"
                except (ValueError, TypeError, KeyError) as error:
                    record["status"] = "malformed-result"
                    record["error"] = str(error)
    except (Exception, KeyboardInterrupt) as error:
        record["status"] = "runner-error"
        record["error"] = f"{type(error).__name__}: {error}"
    # Custody and logs are finalized even after failed parsing or an exception.
    # Only this invocation's attempted artifacts are attached; a compile failure
    # must not accidentally attach a prior run's stdout or executable.
    try:
        if "input_sha256" in record:
            record["input_sha256_after"] = {p: sha(ROOT / p) for p in inputs}
            record["inputs_unchanged"] = record["input_sha256"] == record["input_sha256_after"]
            record["runner_unchanged"] = record["runner_sha256"] == sha(Path(__file__))
            if not record["inputs_unchanged"] or not record["runner_unchanged"]:
                record["status"] = "source-changed-during-run"
            for name, path in (("compiler", Path(record["compiler"])), ("executable", executable)):
                if f"{name}_sha256" not in record:
                    continue
                record[f"{name}_sha256_after"] = sha(path)
                record[f"{name}_unchanged"] = record[f"{name}_sha256"] == record[f"{name}_sha256_after"]
                if not record[f"{name}_unchanged"]:
                    record["status"] = "artifact-changed-during-run"
        record["log_sha256"] = {p.name: sha(p) for p in attempted_logs if p.exists()}
        if run_attempted and (build/"run.stdout.json").exists():
            record["stdout_sha256"] = sha(build/"run.stdout.json")
    except Exception as error:
        record["status"] = "custody-failed"
        record["custody_error"] = f"{type(error).__name__}: {error}"
    record["finished_at_utc"] = utc_now()
    write_record(output, record)
    print(json.dumps({"status": record["status"], "output": str(output), "scope": record["scope"]}))
    return 0 if record["status"] == "pass" else 1

if __name__ == "__main__":
    sys.exit(main())
