#!/usr/bin/env python3
"""Collect isolated MAT-003PREPASS storage correctness; never benchmark World."""
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
from datetime import datetime, timezone

from verify import validate_result, verify_directory

ROOT = Path(__file__).resolve().parents[3]
HERE = Path("tools/experiments/mat003_prepass")
INPUTS = [str(HERE / name) for name in
          ("registration.json", "carriers.hpp", "test_carriers.cpp", "run.py", "verify.py", "test_evidence.py")]
INPUTS += ["native/include/cybersand/precision_storage.hpp", "native/include/cybersand/material.hpp",
           "third_party/native-toolchain.lock.json"]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def capture(command: list[str], output: Path, label: str, timeout: int, env: dict) -> dict:
    receipt = {"command": command, "timeout_seconds": timeout,
               "stdout": label + ".stdout", "stderr": label + ".stderr",
               "timed_out": False, "exit_code": None}
    try:
        completed = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, timeout=timeout, check=False)
        out, err = completed.stdout, completed.stderr
        receipt["exit_code"] = completed.returncode
    except subprocess.TimeoutExpired as exc:
        out, err = exc.stdout or b"", exc.stderr or b""
        receipt["timed_out"] = True
    except OSError as exc:
        out, err = b"", str(exc).encode()
        receipt["exit_code"] = -1
    (output / receipt["stdout"]).write_bytes(out)
    (output / receipt["stderr"]).write_bytes(err)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compiler", default="c++")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("output exists; use a new directory to preserve every attempt")
    compiler = shutil.which(args.compiler)
    if compiler is None:
        parser.error("compiler unavailable: " + args.compiler)
    output.mkdir(parents=True)
    started = time.monotonic()
    env = dict(os.environ)
    env["ASAN_OPTIONS"] = "detect_leaks=1:halt_on_error=1"
    env["UBSAN_OPTIONS"] = "halt_on_error=1:print_stacktrace=1"
    report = {"schema_version": 1, "status": "failed", "scope": "synthetic-storage-only",
              "created_utc": datetime.now(timezone.utc).isoformat(),
              "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_status": subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines(),
              "platform": {"system": platform.system(), "release": platform.release(),
                           "machine": platform.machine(), "python": platform.python_version()},
              "compiler": str(Path(compiler).resolve()),
              "compiler_binary_sha256": sha(Path(compiler).read_bytes()),
              "sanitizer_environment": {k: env[k] for k in ("ASAN_OPTIONS", "UBSAN_OPTIONS")},
              "source_sha256": {}, "configurations": [], "errors": [], "files": {}}
    try:
        for name in INPUTS:
            data = (ROOT / name).read_bytes()
            path = output / "source" / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            report["source_sha256"][name] = sha(data)
        registration_file = "source/" + str(HERE / "registration.json")
        report["registration_file"] = registration_file
        registration = json.loads((output / registration_file).read_text())
        report["baseline_commit"] = registration["execution_baseline"]
        report["baseline_control_sha256"] = {}
        for name, expected in registration["baseline_control_sha256"].items():
            original = subprocess.check_output(["git", "show", report["baseline_commit"] + ":" + name], cwd=ROOT)
            if sha(original) != expected or report["source_sha256"][name] != expected:
                raise ValueError("production control drift from registered baseline: " + name)
            report["baseline_control_sha256"][name] = expected
        limits = registration["execution"]
        if limits["primary_timing_admitted"] is not False:
            raise ValueError("S0 must not admit primary timings")
        version = capture([compiler, "--version"], output, "compiler-version", 10, env)
        if version["exit_code"] != 0:
            raise ValueError("cannot identify compiler")
        report["compiler_version_receipt"] = version
        report["compiler_version"] = (output / version["stdout"]).read_text().splitlines()[0]
        report["linker_version_receipt"] = capture(["ld", "--version"], output, "linker-version", 10, env)
        for mode, flags_key in (("normal", "normal_flags"), ("sanitized", "sanitizer_flags")):
            if time.monotonic() - started > limits["total_stage_budget_seconds"]:
                raise ValueError("registered collection budget exhausted")
            binary = output / (mode + (".exe" if os.name == "nt" else ""))
            flags = limits[flags_key]
            command = [compiler, *flags, "-I" + str(output / "source/native/include"),
                       str(output / "source" / HERE / "test_carriers.cpp"), "-o", str(binary)]
            row = {"name": mode}
            report["configurations"].append(row)
            row["compile"] = capture(command, output, mode + ".compile", limits["compile_timeout_seconds"], env)
            if row["compile"]["exit_code"] != 0 or row["compile"]["timed_out"]:
                raise ValueError(f"{mode} compilation failed/timed out; transcripts retained")
            row["binary"] = binary.name
            row["execute"] = capture([str(binary)], output, mode + ".execute", limits["test_timeout_seconds"], env)
            if row["execute"]["exit_code"] != 0 or row["execute"]["timed_out"]:
                raise ValueError(f"{mode} execution failed/timed out; transcripts retained")
            result = json.loads((output / row["execute"]["stdout"]).read_text())
            row["result_file"] = mode + ".json"
            write_json(output / row["result_file"], result)
            errors = validate_result(result, registration)
            if (output / row["execute"]["stderr"]).read_text().strip():
                errors.append("unexpected test/sanitizer stderr")
            if errors:
                raise ValueError(mode + ": " + "; ".join(errors))
            print(json.dumps({"configuration": mode, "status": "passed", "arms": len(result["arms"]),
                              "checks": result["checks"]}), flush=True)
        report["status"] = "passed"
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        report["errors"].append(str(exc))
    for path in sorted(output.rglob("*")):
        if path.is_file():
            data = path.read_bytes()
            report["files"][path.relative_to(output).as_posix()] = {"bytes": len(data), "sha256": sha(data)}
    write_json(output / "run.json", report)
    readback = verify_directory(output)
    if readback["status"] != "passed":
        report["status"] = "failed"
        report["errors"].extend(readback["errors"])
        write_json(output / "run.json", report)
    print(json.dumps({"status": report["status"], "scope": report["scope"], "output": str(output),
                      "errors": report["errors"]}, indent=2))
    return int(report["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
