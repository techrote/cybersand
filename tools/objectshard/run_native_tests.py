#!/usr/bin/env python3
"""Build and execute the source-matched ObjectShard native qualification suites.

Every invocation freezes its source inputs and builds a fresh shared object set.
The report binds source hashes, compiler identity, commands, binaries and counts;
it is native evidence, not a claim of Godot/Rapier or Windows gameplay acceptance.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
WORLD = ("world", "material_rules", "scheduler_geometry", "settled_world_discovery")
SUITES = {
    "storage": ("object_shard",),
    "contact": ("object_shard",),
    "coordinator": (*WORLD, "object_shard", "object_shard_coordinator"),
    "chemistry": WORLD,
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git_value(*arguments: str) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *arguments], capture_output=True, text=True, check=False
    )
    return result.stdout.strip() if result.returncode == 0 else None


def inputs(suites: list[str]) -> list[Path]:
    files = [
        path
        for directory in (ROOT / "native/include", ROOT / "native/src")
        for path in directory.rglob("*")
        if path.is_file()
    ]
    files.extend(ROOT / f"native/tests/test_object_shard_{suite}.cpp" for suite in suites)
    files.append(Path(__file__).resolve())
    return sorted(set(files))


def command_record(
    command: list[str], log: Path, timeout: float, environment: dict[str, str] | None = None
) -> dict[str, object]:
    start = time.monotonic()
    timed_out = False
    try:
        result = subprocess.run(
            command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", timeout=timeout,
            env=environment, check=False,
        )
        output, returncode = result.stdout, result.returncode
    except subprocess.TimeoutExpired as error:
        timed_out = True
        captured = error.stdout or b""
        output = captured.decode("utf-8", errors="replace") if isinstance(captured, bytes) else captured
        output += f"\nTIMEOUT after {timeout:g} seconds\n"
        returncode = None
    except OSError as error:
        output, returncode = f"Command could not execute: {error}\n", None
    log.write_text(output, encoding="utf-8")
    return {
        "command": command, "returncode": returncode, "timed_out": timed_out,
        "elapsed_seconds": time.monotonic() - start, "log": str(log),
    }


def counts(output: str) -> tuple[int | None, int | None]:
    match = re.search(r"(\d+) checks, (\d+) failures", output)
    if match:
        return int(match.group(1)), int(match.group(2))
    for line in reversed(output.splitlines()):
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(record, dict):
            checks, failures = record.get("checks"), record.get("failures")
            if type(checks) is int and type(failures) is int and min(checks, failures) >= 0:
                return checks, failures
    return None, None


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--output", type=Path, default=ROOT / "build/objectshard-native",
                        help="Evidence directory; each invocation retains a separate timestamped run.")
    parser.add_argument("--suite", action="append", choices=(*SUITES, "all"),
                        help="Select a suite; repeat to combine. Default: all four suites.")
    parser.add_argument("--compiler", default=os.environ.get("CXX", "g++"),
                        help="GCC/Clang C++ compiler command (default: CXX or g++); no shell is used.")
    parser.add_argument("--jobs", type=int, default=min(2, os.cpu_count() or 1),
                        help="Concurrent compiler processes, 1–16 (default: at most 2).")
    parser.add_argument("--sanitize", action="store_true",
                        help="Enable AddressSanitizer and UndefinedBehaviorSanitizer; requires compiler support.")
    parser.add_argument("--timeout", type=float, default=180,
                        help="Timeout in seconds for each test executable (default: 180).")
    parser.add_argument("--build-timeout", type=float, default=420,
                        help="Timeout in seconds for each compile/link process (default: 420).")
    args = parser.parse_args()
    if not 1 <= args.jobs <= 16:
        parser.error("--jobs must be between 1 and 16")
    if any(not math.isfinite(value) or value <= 0 for value in (args.timeout, args.build_timeout)):
        parser.error("timeouts must be finite positive numbers")
    return args


def main() -> int:
    args = parse_arguments()
    start = time.monotonic()
    suites = list(SUITES) if not args.suite or "all" in args.suite else list(dict.fromkeys(args.suite))
    compiler = shlex.split(args.compiler, posix=os.name != "nt")
    if not compiler:
        raise ValueError("the compiler command is empty")
    version = subprocess.run(
        [*compiler, "--version"], capture_output=True, text=True, timeout=30, check=False
    )
    if version.returncode:
        raise RuntimeError(f"compiler identity failed: {version.stderr.strip()}")

    # Read and verify before building. A concurrent edit during capture is an
    # explicit refusal, never evidence labelled as a coherent changing tree.
    captured_head = git_value("rev-parse", "HEAD")
    paths = inputs(suites)
    source_bytes = {str(path.relative_to(ROOT)): path.read_bytes() for path in paths}
    if (git_value("rev-parse", "HEAD") != captured_head or inputs(suites) != paths or
            any((ROOT / path).read_bytes() != data for path, data in source_bytes.items())):
        raise RuntimeError("source changed during input capture; rerun after the edit completes")
    ledger = {path: sha256(data) for path, data in source_bytes.items()}
    flags = ["-std=c++20", "-O1", "-g", "-pthread", "-Wall", "-Wextra", "-Wpedantic", "-Werror"]
    if args.sanitize:
        flags.extend(["-fsanitize=address,undefined", "-fno-omit-frame-pointer"])
    specification = {
        "schema": 1, "sources": ledger, "compiler": compiler,
        "compiler_version": version.stdout.strip(), "flags": flags,
        "suites": suites, "platform": sys.platform,
    }
    digest = sha256(json.dumps(specification, sort_keys=True).encode("utf-8"))
    output = args.output.resolve()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    run = output / f"{stamp}-{digest[:12]}"
    snapshot, objects, logs = run / "source", run / "objects", run / "logs"
    for directory in (snapshot, objects, logs):
        directory.mkdir(parents=True, exist_ok=False)
    for name, data in source_bytes.items():
        destination = snapshot / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    write_json(run / "inputs.json", {
        **specification, "input_digest": digest, "git_head": captured_head,
        "git_status": git_value("status", "--short"), "source_root": str(ROOT),
    })
    print(f"ObjectShard source input: {digest}\nEvidence: {run}", flush=True)
    include = ["-I", str(snapshot / "native/include")]
    names = list(dict.fromkeys(name for suite in suites for name in SUITES[suite]))
    build_records: dict[str, dict[str, object]] = {}

    def compile_one(name: str) -> tuple[str, dict[str, object]]:
        command = [*compiler, *flags, *include, "-c", str(snapshot / f"native/src/{name}.cpp"),
                   "-o", str(objects / f"{name}.o")]
        record = command_record(command, logs / f"build-{name}.log", args.build_timeout)
        if record["returncode"] == 0:
            record["object_sha256"] = sha256((objects / f"{name}.o").read_bytes())
        return name, record

    # These objects are shared only by suites in this invocation; no stale
    # object or binary from an earlier run participates in the qualification.
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        pending = [pool.submit(compile_one, name) for name in names]
        for future in as_completed(pending):
            name, record = future.result()
            build_records[name] = record
            print(f"Build {name}: {'PASS' if record['returncode'] == 0 else 'FAIL'} "
                  f"({record['elapsed_seconds']:.2f}s)", flush=True)
    write_json(run / "builds.json", build_records)
    environment = os.environ.copy()
    if args.sanitize:
        environment["ASAN_OPTIONS"] = "detect_leaks=0:strict_string_checks=1"
        environment["UBSAN_OPTIONS"] = "halt_on_error=1:print_stacktrace=1"
    suite_records: dict[str, dict[str, object]] = {}
    for suite in suites:
        dependencies = SUITES[suite]
        failed_dependencies = [name for name in dependencies if build_records[name]["returncode"] != 0]
        if failed_dependencies:
            suite_records[suite] = {"status": "not_run", "failed_dependencies": failed_dependencies,
                                    "checks": None, "failures": None}
            continue
        executable = run / f"test_object_shard_{suite}{'.exe' if os.name == 'nt' else ''}"
        command = [*compiler, *flags, *include, str(snapshot / f"native/tests/test_object_shard_{suite}.cpp"),
                   *(str(objects / f"{name}.o") for name in dependencies), "-o", str(executable)]
        link = command_record(command, logs / f"link-{suite}.log", args.build_timeout)
        record: dict[str, object] = {"link": link, "checks": None, "failures": None}
        if link["returncode"] != 0:
            record["status"] = "build_failed"
        else:
            record["binary_sha256"] = sha256(executable.read_bytes())
            test_log = logs / f"test-{suite}.log"
            execution = command_record([str(executable)], test_log, args.timeout, environment)
            checks, failures = counts(test_log.read_text(encoding="utf-8"))
            record.update(execution=execution, checks=checks, failures=failures)
            record["status"] = "passed" if execution["returncode"] == 0 and checks is not None and checks > 0 and failures == 0 else "failed"
            if checks is None:
                record["count_status"] = "no complete explicit count record; not a qualifying PASS"
        suite_records[suite] = record
        print(f"Suite {suite}: {record['status']} — {record['checks']} checks, "
              f"{record['failures']} failures", flush=True)
    summary = {
        "schema": 1, "input_digest": digest, "run_directory": str(run),
        "git_head": captured_head, "suites": suite_records,
        "status": "passed" if all(record["status"] == "passed" for record in suite_records.values()) else "failed",
        "checks_reported": sum(record["checks"] or 0 for record in suite_records.values()),
        "failures_reported": sum(record["failures"] or 0 for record in suite_records.values()),
        "counts_complete": all(record["checks"] is not None and record["failures"] is not None for record in suite_records.values()),
        "elapsed_seconds": time.monotonic() - start, "sanitizers": args.sanitize,
        "leak_sanitizer": False, "qualification_scope": "Native C++ only; no rendered, Rapier or owner physical acceptance claim.",
    }
    write_json(run / "summary.json", summary)
    write_json(output / "summary.json", summary)
    print(f"Overall: {summary['status']} — {summary['checks_reported']} checks reported; "
          f"summary {output / 'summary.json'}", flush=True)
    return 0 if summary["status"] == "passed" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"ObjectShard qualification refused: {error}", file=sys.stderr)
        raise SystemExit(2) from error
