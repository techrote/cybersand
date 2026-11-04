#!/usr/bin/env python3
"""Compile and authenticate the separate SOL364-B diagnostic on its actual host.

The existing SOL281 Godot inventory and runtime publisher are not changed. This
receipt qualifies the diagnostic compiler/tests and replay of historical states,
never a new live positional recovery mechanism or a passing physical gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

import run_penetration_corridor as replay

ROOT = replay.REPOSITORY
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import execution_policy as policy

INPUTS = (*replay.INPUTS, "tools/sol281/qualify_penetration_corridor.py",
          "tools/sol281/run_msvc_contact.cmd", ".github/workflows/sol281-current-main.yml",
          "tools/ci/execution_policy.py", "godot/tests/support/ci_execution_policy.json")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs() -> dict[str, str]:
    result = {}
    for name in INPUTS:
        original = subprocess.run(["git", "show", "HEAD:"+name], cwd=ROOT,
                                  capture_output=True, check=True,
                                  timeout=policy.watchdog_seconds("operation_seconds")).stdout
        actual = (ROOT/name).read_bytes()
        if actual != original:
            raise ValueError("diagnostic checkout differs from exact Git input: "+name)
        result[name] = hashlib.sha256(actual).hexdigest()
    return result


def identity() -> dict[str, str]:
    return {"sha": replay.git("rev-parse", "HEAD"), "tree": replay.git("rev-parse", "HEAD^{tree}")}


def save(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False)+"\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=("linux", "windows"))
    parser.add_argument("--compiler", help="GCC13 or MSVC compiler, inherited from the actual host")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--prepare-historical", action="store_true",
                        help="fetch only immutable957 source and materialize the four named historical inputs")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": "cybersand.sol364b.diagnostic-qualification.v1", "status": "running",
               "platform": platform.system(), "platform_detail": platform.platform(),
               "run_id": os.environ.get("GITHUB_RUN_ID"), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
               "execution_policy": policy.identity(),
               "commands": [], "executables": {}, "tool_executables": {}, "live_candidate_applications": 0,
               "scope": "fresh actual-host C++ diagnostic execution; original Linux/Windows Rapier states are historical inputs",
               "physical_disposition": "NO_GO; no live recovery has been implemented or admitted"}
    record = output/"qualification.json"

    def execute(label: str, command: list[str], *, environment: dict[str, str] | None = None,
                accept: tuple[int, ...] = (0,), policy_key: str = "operation_seconds") -> subprocess.CompletedProcess[bytes]:
        timeout = policy.watchdog_seconds(policy_key)
        item = {"label": label, "command": command, "environment_overrides": environment or {},
                "policy_key": policy_key, "timeout_seconds": timeout}
        receipt["commands"].append(item)
        save(record, receipt)
        start = time.monotonic()
        try:
            completed = subprocess.run(command, cwd=ROOT, env={**os.environ, **(environment or {})},
                                       capture_output=True, timeout=timeout)
            item.update({"returncode": completed.returncode, "elapsed_seconds": time.monotonic()-start,
                         "stdout": completed.stdout.decode("utf-8", errors="replace"),
                         "stderr": completed.stderr.decode("utf-8", errors="replace"),
                         "stdout_bytes_sha256": hashlib.sha256(completed.stdout).hexdigest(),
                         "stderr_bytes_sha256": hashlib.sha256(completed.stderr).hexdigest()})
            save(record, receipt)
            if completed.returncode not in accept:
                raise ValueError(f"{label} returned {completed.returncode}")
            return completed
        except subprocess.TimeoutExpired as error:
            item.update({"timed_out": True, "elapsed_seconds": time.monotonic()-start,
                         "stdout": (error.stdout or b"").decode("utf-8", errors="replace"),
                         "stderr": (error.stderr or b"").decode("utf-8", errors="replace"),
                         "stdout_bytes_sha256": hashlib.sha256(error.stdout or b"").hexdigest(),
                         "stderr_bytes_sha256": hashlib.sha256(error.stderr or b"").hexdigest()})
            save(record, receipt)
            raise

    try:
        expected_host = "Linux" if args.platform == "linux" else "Windows"
        if platform.system() != expected_host:
            raise ValueError("requested diagnostic platform is not the actual execution host")
        receipt["source"] = identity()
        if os.environ.get("GITHUB_SHA") and os.environ["GITHUB_SHA"] != receipt["source"]["sha"]:
            raise ValueError("workflow SHA differs from checked diagnostic source")
        receipt["inputs_before"] = inputs()
        compiler = shutil.which(args.compiler or ("g++-13" if args.platform == "linux" else "cl"))
        if not compiler:
            raise ValueError("requested native compiler is unavailable")
        receipt["compiler_path"] = compiler
        for name, path in (("compiler", Path(compiler)), ("python", Path(sys.executable))):
            receipt["tool_executables"][name] = {"path": str(path), "sha256": digest(path), "bytes": path.stat().st_size}
        receipt["tool_executables"]["python"]["version"] = sys.version
        execute("compiler-version", [compiler, "--version"] if args.platform == "linux" else [compiler],
                accept=(0,) if args.platform == "linux" else (0, 2))
        if args.prepare_historical:
            execute("immutable-historical-source", ["git", "fetch", "--no-tags", "--depth=1", "origin", replay.HISTORICAL_HEAD],
                    policy_key="dependency_prepare_seconds")
            execute("lfs-local", ["git", "lfs", "install", "--local"])
            execute("original-state-bytes", ["git", "lfs", "pull", "--include="+",".join(replay.DEFAULT_REPORTS), "--exclude="],
                    policy_key="dependency_prepare_seconds")
        binary_directory = output/"bin"
        binary_directory.mkdir(exist_ok=True)
        for name, source in (("probe", "penetration_corridor_probe.cpp"), ("tests", "test_penetration_corridor.cpp")):
            executable = binary_directory/(name+(".exe" if args.platform == "windows" else ""))
            if args.platform == "linux":
                command = [compiler, "-std=c++20", "-O2", "-Wall", "-Wextra", "-Wpedantic", "-I", "native/include",
                           "tools/sol281/"+source, "-o", str(executable)]
            else:
                command = [compiler, "/std:c++20", "/EHsc", "/W4", "/O2", "/Bv", "/I", "native/include",
                           "/Fo:"+str(binary_directory/(name+".obj")), "/Fe:"+str(executable), "tools/sol281/"+source]
            execute("compile-"+name, command, policy_key="native_compile_seconds")
            receipt["executables"][name] = {"path": str(executable), "sha256": digest(executable), "bytes": executable.stat().st_size}
        if args.platform == "linux":
            executable = binary_directory/"tests-sanitize"
            execute("compile-sanitizers", [compiler, "-std=c++20", "-O1", "-g", "-fno-omit-frame-pointer",
                    "-fsanitize=address,undefined", "-Wall", "-Wextra", "-Wpedantic", "-I", "native/include",
                    "tools/sol281/test_penetration_corridor.cpp", "-o", str(executable)], policy_key="native_compile_seconds")
            receipt["executables"]["sanitizers"] = {"path": str(executable), "sha256": digest(executable), "bytes": executable.stat().st_size}
            # Retain the exact local environment boundary. Address/UB coverage
            # is separate from LeakSanitizer, which is explicitly not claimed.
            completed = execute("address-undefined-tests", [str(executable)], policy_key="native_case_seconds",
                                environment={"ASAN_OPTIONS": "detect_leaks=0:strict_string_checks=1:abort_on_error=1",
                                             "UBSAN_OPTIONS": "halt_on_error=1:print_stacktrace=1"})
            result = json.loads(completed.stdout)
            if result.get("failures") != 0 or result.get("checks", 0) < 142:
                raise ValueError("incomplete sanitizer diagnostic test receipt")
            receipt["leak_sanitizer"] = "NOT_EXERCISED; detect_leaks=0 explicitly recorded"
        else:
            receipt["sanitizers"] = "NOT_APPLICABLE_TO_MSVC_COHORT; covered separately on actual Linux"
        execute("retained-state-replay", [sys.executable, "tools/sol281/run_penetration_corridor.py",
                "--probe", receipt["executables"]["probe"]["path"], "--tests", receipt["executables"]["tests"]["path"],
                "--output", str(output/"replay")], policy_key="native_case_seconds")
        summary_path = output/"replay"/"summary.json"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        if summary["disposition"] != "BOUNDED_FAMILY_NO_GO" or summary["reports"] != 4 or summary["retained_states_evaluated"] != 1452 \
                or summary["live_candidate_applications"] != 0 or summary["native_tests"]["result"]["checks"] < 142:
            raise ValueError("registered original-state admission inventory changed or is incomplete")
        if summary["analysis_git_head"] != receipt["source"]["sha"] or summary["analysis_git_tree"] != receipt["source"]["tree"]:
            raise ValueError("replay source differs from the compiled diagnostic source")
        receipt["summary_sha256"] = digest(summary_path)
        receipt["inputs_after"] = inputs()
        receipt["source_after"] = identity()
        if receipt["inputs_before"] != receipt["inputs_after"] or receipt["source"] != receipt["source_after"]:
            raise ValueError("diagnostic source changed during compilation or replay")
        for executable in (*receipt["executables"].values(), *receipt["tool_executables"].values()):
            if digest(Path(executable["path"])) != executable["sha256"]:
                raise ValueError("diagnostic executable or tool changed during qualification")
        receipt["status"] = "passed"
        receipt["result"] = {key: summary[key] for key in ("reports", "retained_states_evaluated", "unique_geometric_inputs",
                            "outcome_counts", "live_candidate_applications", "disposition")}
        save(record, receipt)
        print(json.dumps({"schema": receipt["schema"], "status": receipt["status"], "source": receipt["source"],
                          "platform": receipt["platform"], "result": receipt["result"]}, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        receipt["status"] = "failed"
        receipt["error"] = str(error)
        save(record, receipt)
        print("SOL364B_DIAGNOSTIC_FAILURE: "+str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
