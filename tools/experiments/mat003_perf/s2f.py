#!/usr/bin/env python3
"""MAT-003PREPASS S2F: immutable source-control fixture preflight, NO timing admission."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path("tools/experiments/mat003_perf")
S1 = Path("tools/experiments/mat003_prepass/world_registration.json")
COMMON = ["native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
          "native/src/settled_world_discovery.cpp"]
# Formal S2F source qualification executes the complete registered context list
# in literal order. It is still untimed and cannot admit S2A/S2B comparisons.


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def dump(path: Path, item: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(item, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def command(argv: list[str], directory: Path, base: Path,
            label: str, timeout: int) -> dict:
    out = base / (label + ".stdout")
    err = base / (label + ".stderr")
    out.parent.mkdir(parents=True, exist_ok=True)
    row: dict = {"argv": argv, "cwd": str(directory), "timeout": timeout,
                 "stdout": out.relative_to(base).as_posix(),
                 "stderr": err.relative_to(base).as_posix(),
                 "exit_code": None, "timed_out": False}
    with out.open("wb") as stdout, err.open("wb") as stderr:
        try:
            completed = subprocess.run(argv, cwd=directory, stdout=stdout, stderr=stderr,
                                       timeout=timeout, check=False)
            row["exit_code"] = completed.returncode
        except subprocess.TimeoutExpired:
            row["timed_out"] = True
        except OSError as exc:
            stderr.write(str(exc).encode("utf-8"))
            row["exit_code"] = -1
    return row


def succeeded(row: dict) -> bool:
    return row["exit_code"] == 0 and row["timed_out"] is False


def collect(output: Path, compiler_request: str) -> dict:
    output = output.resolve()
    if output.exists():
        raise ValueError("output exists: append-only evidence requires a new path")
    compiler = shutil.which(compiler_request)
    if compiler is None:
        raise ValueError("required compiler unavailable: " + compiler_request)
    compiler = str(Path(compiler).resolve())
    output.mkdir(parents=True)
    started = time.monotonic()
    spec = json.loads((ROOT / HERE / "s2f_registration.json").read_text())
    s1 = json.loads((ROOT / S1).read_text())
    limits = spec["execution"]
    report: dict = {
        "stage": "S2F-source-feasibility", "schema_version": 1,
        "status": "incomplete", "performance_qualification": False,
        "formal_timing_admitted": False, "preflight_only": False,
        "source_context_qualification": True, "candidate_twin_qualification": False,
        "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"],
                                               cwd=ROOT, text=True).strip(),
        "source_status": subprocess.check_output(["git", "status", "--porcelain"],
                                                 cwd=ROOT, text=True).splitlines(),
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "platform": {"system": platform.system(), "machine": platform.machine(),
                     "kernel": platform.release(), "python": platform.python_version()},
        "compiler": compiler, "compiler_sha256": digest(Path(compiler)),
        "baseline_native_commit": spec["baseline_native_commit"],
        "native_control_sha256": s1["baseline_control_sha256"],
        "input_sha256": {}, "binary_sha256": None, "processes": [],
        "compile": None, "errors": [], "files": {},
    }

    def remaining(limit: int) -> int:
        seconds = limits["total_wall_budget_seconds"] - (time.monotonic() - started)
        if seconds <= 0:
            raise ValueError("registered wall budget exhausted; preflight incomplete")
        return max(1, min(limit, int(seconds)))

    try:
        if spec["status"] != "preregistered-full-source-and-candidate-twins-untimed" or \
                spec["formal_timing_admitted"] is not False or \
                spec["performance_comparisons_admitted"] is not False or \
                spec["source_context_qualification"]["admitted"] is not True or \
                spec["source_context_qualification"]["timed"] is not False:
            raise ValueError("source qualification registration cannot promote S2 to timing")
        if spec["baseline_native_commit"] != s1["planning_commit"]:
            raise ValueError("baseline disagrees with S1 frozen native control")
        if platform.system() != "Linux" or platform.machine() != "x86_64":
            raise ValueError("S2F preflight registered on Linux x86_64 only")
        source = output / "source"
        inputs = set(s1["baseline_control_sha256"])
        inputs.update({S1.as_posix(), (HERE / "fixture.cpp").as_posix(),
                       (HERE / "s2f.py").as_posix(),
                       (HERE / "verify_s2f.py").as_posix(),
                       (HERE / "s2f_registration.json").as_posix()})
        # Freeze every compiled source, dependency, fixture and verifier before
        # compiling anything. Native bytes must equal registered S1 control AND
        # the actual immutable baseline git object.
        for name in sorted(inputs):
            original = ROOT / name
            frozen = source / name
            frozen.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, frozen)
            report["input_sha256"][name] = digest(frozen)
        for name, expected in s1["baseline_control_sha256"].items():
            historical = subprocess.check_output(
                ["git", "show", spec["baseline_native_commit"] + ":" + name],
                cwd=ROOT)
            if hashlib.sha256(historical).hexdigest() != expected or \
                    report["input_sha256"][name] != expected:
                raise ValueError("native control drift: " + name)
        dump(output / "frozen-inputs.json",
             {"input_sha256": report["input_sha256"],
              "baseline_native_commit": spec["baseline_native_commit"],
              "source_head": report["source_head"],
              "preflight_only": False,
              "source_context_qualification": True})
        version = command([compiler, "--version"], source, output, "compiler-version", 10)
        linker = command(["ld", "--version"], source, output, "linker-version", 10)
        report["compiler_version"] = version
        report["linker_version"] = linker
        if not succeeded(version) or not succeeded(linker):
            raise ValueError("toolchain identification failed")
        if "13.3.0" not in (output / "compiler-version.stdout").read_text():
            raise ValueError("GCC 13.3.0 pin not satisfied")
        if "2.42" not in (output / "linker-version.stdout").read_text():
            raise ValueError("ld 2.42 pin not satisfied")
        flags = limits["flags"]
        binary = output / "bin" / "source-world-qualifier"
        binary.parent.mkdir(parents=True)
        compile_argv = [
            compiler, *flags, "-I" + str(source / "native/include"),
            str(source / HERE / "fixture.cpp"), str(source / "native/src/world.cpp"),
            *(str(source / name) for name in COMMON), "-o", str(binary)
        ]
        report["compile"] = command(
            compile_argv, source, output, "compile", remaining(limits["compile_timeout_seconds"]))
        if not succeeded(report["compile"]):
            raise ValueError("source-control qualifier compile failed")
        report["binary_sha256"] = digest(binary)
        # Intentionally freeze the exact binary SHA before ANY fixture process.
        dump(output / "sealed-binary.json",
             {"path": "bin/source-world-qualifier", "sha256": report["binary_sha256"],
              "source_sha256": report["input_sha256"],
              "status": "formal-source-qualification-not-timing"})
        contexts = spec["contexts"]
        if len(contexts) != 24 or len({item["id"] for item in contexts}) != 24:
            raise ValueError("formal source context registration must contain 24 unique contexts")
        for case in contexts:
            case_id = case["id"]
            timeout = remaining(limits["fixture_timeout_seconds"])
            if digest(binary) != report["binary_sha256"]:
                raise ValueError("binary changed after pre-execution seal")
            argv = [str(binary), "--side", str(case["side"]), "--workers",
                    str(case["workers"]), "--warmup", str(spec["inputs"]["warmup_ticks"]),
                    "--ticks", str(spec["inputs"]["measured_ticks"]), "--seed",
                    str(spec["inputs"]["seed"]), "--scenario", case["scenario"],
                    "--mode", "qualify"]
            receipt = command(argv, source, output, "cases/" + case_id, timeout)
            report["processes"].append({"id": case_id, "receipt": receipt})
            if not succeeded(receipt):
                raise ValueError("source qualification fixture failed/timed out: " + case_id)
            if (output / receipt["stderr"]).read_bytes().strip():
                raise ValueError("source qualification fixture stderr not empty: " + case_id)
            observed = json.loads((output / receipt["stdout"]).read_text())
            if observed.get("status") != "passed" or observed.get("mode") != "qualify" or \
                    observed.get("tick_ns") != [] or observed.get("input_ns") != []:
                raise ValueError("source qualification emitted timing or malformed outcome: " + case_id)
        report["status"] = "passed-source-context-qualification"
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        report["status"] = "incomplete"
        report["errors"].append(str(exc))
    finally:
        report["elapsed_seconds_budget_only_not_benchmark"] = time.monotonic() - started
        for path in sorted(output.rglob("*")):
            if path.is_file() and path.name != "run.json":
                report["files"][path.relative_to(output).as_posix()] = {
                    "bytes": path.stat().st_size, "sha256": digest(path)}
        dump(output / "run.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compiler", default="g++-13")
    args = parser.parse_args()
    try:
        result = collect(args.output, args.compiler)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(json.dumps({"status": result["status"], "preflight_only": False,
                      "source_context_qualification": True,
                      "errors": result["errors"]}, indent=2))
    return int(result["status"] != "passed-source-context-qualification")


if __name__ == "__main__":
    raise SystemExit(main())
