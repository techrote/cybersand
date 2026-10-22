#!/usr/bin/env python3
"""Collect the registered isolated native World correctness stage, never timings."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path("tools/experiments/mat003_prepass")
COMMON = ("native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
          "native/src/settled_world_discovery.cpp")


def sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError(f"cannot load captured apparatus: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def capture(command: list[str], output: Path, label: str, timeout: int,
            environment: dict[str, str], *, cwd: Path) -> dict:
    receipt = {"command": command, "cwd": str(cwd), "timeout_seconds": timeout,
               "stdout": label + ".stdout", "stderr": label + ".stderr",
               "exit_code": None, "timed_out": False}
    out = output / receipt["stdout"]
    err = output / receipt["stderr"]
    out.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    with out.open("wb") as stdout, err.open("wb") as stderr:
        try:
            result = subprocess.run(command, cwd=cwd, env=environment, stdout=stdout,
                                    stderr=stderr, timeout=timeout, check=False)
            receipt["exit_code"] = result.returncode
        except subprocess.TimeoutExpired:
            receipt["timed_out"] = True
        except OSError as exc:
            stderr.write(str(exc).encode("utf-8"))
            receipt["exit_code"] = -1
    # Required for the registered process/wall budget only. These are observer-on
    # correctness runs and must never be reduced as candidate performance data.
    receipt["elapsed_seconds_not_benchmark"] = time.monotonic() - started
    return receipt


def successful(receipt: dict) -> bool:
    return receipt["exit_code"] == 0 and receipt["timed_out"] is False


def collect(args: argparse.Namespace) -> dict:
    output = args.output.resolve()
    if output.exists():
        raise ValueError("output already exists; preserve it and choose a new directory")
    compiler = shutil.which(args.compiler)
    if compiler is None:
        raise ValueError("compiler unavailable: " + args.compiler)
    compiler = str(Path(compiler).resolve())
    output.mkdir(parents=True)
    started = time.monotonic()
    source = output / "source"
    registration_path = HERE / "world_registration.json"
    registration = json.loads((ROOT / registration_path).read_text())
    limits = registration["execution"]
    if limits["primary_timing_admitted"] is not False:
        raise ValueError("this collector cannot admit performance measurements")
    environment = dict(os.environ)
    environment.update(limits["sanitizer_environment"])
    report = {
        "schema_version": 1, "stage": "S1-World-correctness", "status": "failed",
        "scope": "isolated-native-World-correctness", "performance_qualification": False,
        "developer_attempt": args.developer,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_status": subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines(),
        "baseline_commit": registration["execution_baseline"],
        "baseline_control_sha256": registration["baseline_control_sha256"],
        "registration_file": "source/" + registration_path.as_posix(),
        "platform": {"system": platform.system(), "release": platform.release(),
                     "machine": platform.machine(), "python": platform.python_version()},
        "compiler": compiler, "compiler_binary_sha256": sha_file(Path(compiler)),
        "sanitizer_environment": limits["sanitizer_environment"],
        "source_sha256": {}, "configurations": [], "errors": [], "files": {},
        "process_counts": {"compile": 0, "test": 0},
    }

    def budget() -> None:
        if time.monotonic() - started >= limits["total_stage_budget_seconds"]:
            raise ValueError("registered collection wall budget exhausted: incomplete evidence")

    def invoke(command: list[str], label: str, kind: str) -> dict:
        budget()
        report["process_counts"][kind] += 1
        if report["process_counts"][kind] > limits[f"maximum_{kind}_processes"]:
            raise ValueError("registered " + kind + " process budget exhausted")
        left = max(1, int(limits["total_stage_budget_seconds"] - (time.monotonic() - started)))
        timeout = min(limits["compile_timeout_seconds" if kind == "compile" else "test_timeout_seconds"], left)
        return capture(command, output, label, timeout, environment, cwd=source)

    try:
        # All native dependencies and apparatus are copied BEFORE any compilation.
        # Neither generated overlays nor compiled commands read mutable worktree input.
        inputs = set(registration["baseline_control_sha256"])
        inputs.update(p.relative_to(ROOT).as_posix() for p in (ROOT / HERE).iterdir()
                      if p.is_file() and p.suffix in (".py", ".hpp", ".cpp", ".json"))
        inputs.add("third_party/native-toolchain.lock.json")
        for name in sorted(inputs):
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, path)
            report["source_sha256"][name] = sha_file(path)
        for name, digest in registration["baseline_control_sha256"].items():
            original = subprocess.check_output(["git", "show", registration["execution_baseline"] + ":" + name], cwd=ROOT)
            if hashlib.sha256(original).hexdigest() != digest or report["source_sha256"][name] != digest:
                raise ValueError("production control drift: " + name)
        write_json(output / "inputs.json", {"created_utc": report["created_utc"],
                   "source_head": report["source_head"], "source_status": report["source_status"],
                   "source_sha256": report["source_sha256"], "baseline_commit": report["baseline_commit"]})
        overlay_module = load_module(source / HERE / "world_overlay.py", "captured_world_overlay")
        report["compiler_version_receipt"] = capture([compiler, "--version"], output,
                                                      "compiler-version", 10, environment, cwd=source)
        if not successful(report["compiler_version_receipt"]):
            raise ValueError("compiler identity command failed")
        report["compiler_version"] = (output / "compiler-version.stdout").read_text().splitlines()[0]
        report["linker_version_receipt"] = capture(["ld", "--version"], output,
                                                    "linker-version", 10, environment, cwd=source)
        if not successful(report["linker_version_receipt"]):
            raise ValueError("linker identity command failed")
        arms = registration["arms"]
        configurations = limits["configurations"]
        if args.developer:
            if args.arms:
                wanted = set(args.arms)
                if not wanted.issubset({a["id"] for a in arms}):
                    raise ValueError("unknown developer arm")
                arms = [a for a in arms if a["id"] in wanted]
            if args.configurations:
                if not set(args.configurations).issubset(set(configurations)):
                    raise ValueError("unknown developer configuration")
                configurations = args.configurations
        elif args.arms or args.configurations:
            raise ValueError("subsets require --developer and never establish formal S1 acceptance")
        for configuration in configurations:
            flags = limits["normal_flags" if configuration == "normal" else "sanitizer_flags"]
            config_row = {"name": configuration, "common_compiles": [], "arms": []}
            report["configurations"].append(config_row)
            objects = []
            for name in COMMON:
                obj = output / configuration / "objects" / (Path(name).stem + ".o")
                obj.parent.mkdir(parents=True, exist_ok=True)
                cmd = [compiler, *flags, "-I" + str(source / "native/include"), "-c",
                       str(source / name), "-o", str(obj)]
                row = {"source": "source/" + name, "object": obj.relative_to(output).as_posix()}
                config_row["common_compiles"].append(row)
                row["compile"] = invoke(cmd, configuration + "/common-" + Path(name).stem, "compile")
                if not successful(row["compile"]):
                    raise ValueError(f"{configuration}: common compilation failed: {name}")
                objects.append(str(obj))
            for arm in arms:
                budget()
                identifier = arm["id"]
                arm_root = output / configuration / identifier
                arm_root.mkdir(parents=True)
                row = {"id": identifier}
                config_row["arms"].append(row)
                print(json.dumps({"configuration": configuration, "arm": identifier,
                                  "step": "prepare-and-compile"}), flush=True)
                overlay = overlay_module.prepare_overlay(source, arm_root / "overlay", arm)
                row["overlay_manifest"] = (arm_root / "overlay/overlay.json").relative_to(output).as_posix()
                binary = arm_root / ("world-tests.exe" if os.name == "nt" else "world-tests")
                cmd = [compiler, *flags, *overlay["compile_definitions"],
                       "-I" + overlay["include_dir"], "-I" + overlay["experiment_dir"],
                       str(Path(overlay["experiment_dir"]) / "test_world.cpp"), *objects, "-o", str(binary)]
                row["compile"] = invoke(cmd, configuration + "/" + identifier + "/compile", "compile")
                if not successful(row["compile"]):
                    raise ValueError(f"{configuration}/{identifier}: compile failed; original receipt retained")
                row["binary"] = binary.relative_to(output).as_posix()
                result_root = arm_root / "results"
                row["execute"] = invoke([str(binary), "--output", str(result_root)],
                                        configuration + "/" + identifier + "/execute", "test")
                if not successful(row["execute"]):
                    raise ValueError(f"{configuration}/{identifier}: fixture failed/timed out; original receipt retained")
                if (output / row["execute"]["stderr"]).read_bytes().strip():
                    raise ValueError(f"{configuration}/{identifier}: test/sanitizer stderr is not empty")
                result_path = result_root / "result.json"
                row["result_file"] = result_path.relative_to(output).as_posix()
                result = json.loads(result_path.read_text())
                if result != json.loads((output / row["execute"]["stdout"]).read_text()):
                    raise ValueError(f"{configuration}/{identifier}: stdout/result disagreement")
                if result.get("status") != "passed":
                    raise ValueError(f"{configuration}/{identifier}: fixture did not pass")
                print(json.dumps({"configuration": configuration, "arm": identifier,
                                  "step": "passed", "assertions": result.get("assertions")}), flush=True)
        report["status"] = "passed"
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        report["errors"].append(str(exc))
    finally:
        report["elapsed_seconds_not_benchmark"] = time.monotonic() - started
        for path in sorted(output.rglob("*")):
            if path.is_file() and path.name != "run.json":
                report["files"][path.relative_to(output).as_posix()] = {
                    "bytes": path.stat().st_size, "sha256": sha_file(path)}
        write_json(output / "run.json", report)
    if not args.developer and report["status"] == "passed":
        verifier = load_module(source / HERE / "world_verify.py", "captured_world_verify")
        readback = verifier.verify_directory(output)
        write_json(output / "readback.json", readback)
        report["files"]["readback.json"] = {
            "bytes": (output / "readback.json").stat().st_size,
            "sha256": sha_file(output / "readback.json")}
        if readback["status"] != "passed":
            report["status"] = "failed"
            report["errors"].extend(readback["errors"])
        report["elapsed_seconds_not_benchmark"] = time.monotonic() - started
        if report["elapsed_seconds_not_benchmark"] > limits["total_stage_budget_seconds"]:
            report["status"] = "failed"
            report["errors"].append("collection and independent readback exceeded registered wall budget")
        write_json(output / "run.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compiler", default="g++-13")
    parser.add_argument("--developer", action="store_true")
    parser.add_argument("--arms", nargs="+")
    parser.add_argument("--configurations", nargs="+")
    args = parser.parse_args()
    try:
        report = collect(args)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(json.dumps({"status": report["status"], "developer_attempt": report["developer_attempt"],
                      "performance_qualification": False, "errors": report["errors"],
                      "output": str(args.output.resolve())}, indent=2))
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
