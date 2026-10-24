#!/usr/bin/env python3
"""Build and untimed-qualify the preregistered MAT-003 S2A performance apparatus."""
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
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path("tools/experiments/mat003_s2a")
S1 = Path("tools/experiments/mat003_prepass")
COMMON = ("native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
          "native/src/settled_world_discovery.cpp")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def tree_digest(root: Path) -> str:
    h = hashlib.sha256()
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        rel = path.relative_to(root).as_posix().encode()
        h.update(len(rel).to_bytes(4, "little"))
        h.update(rel)
        h.update(bytes.fromhex(digest(path)))
    return h.hexdigest()


def dump(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError("cannot load frozen module: " + str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def command(argv: list[str], cwd: Path, output: Path, label: str,
            timeout: int, environment: dict[str, str]) -> dict:
    out = output / (label + ".stdout")
    err = output / (label + ".stderr")
    out.parent.mkdir(parents=True, exist_ok=True)
    row = {"argv": argv, "cwd": str(cwd), "timeout": timeout,
           "stdout": out.relative_to(output).as_posix(),
           "stderr": err.relative_to(output).as_posix(),
           "exit_code": None, "timed_out": False}
    with out.open("wb") as stdout, err.open("wb") as stderr:
        try:
            completed = subprocess.run(argv, cwd=cwd, env=environment,
                                       stdout=stdout, stderr=stderr,
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


def patch_observer_off(overlay: Path) -> dict:
    path = overlay / S1 / "world_adapter.hpp"
    before = path.read_text(encoding="utf-8")
    text = before
    marker = "struct DispatchObservations {"
    if text.count(marker) != 1:
        raise ValueError("S2A observer adapter marker drift")
    text = text.replace(
        marker,
        "#ifndef MAT003_TWIN_OBSERVERS\n"
        "#error \"MAT003_TWIN_OBSERVERS must be supplied by S2A build\"\n"
        "#endif\n\n" + marker, 1)

    blocks = [
        (
"""inline void observe_dispatch(std::size_t tasks) noexcept {
    dispatch_calls.fetch_add(1, std::memory_order_relaxed);
    dispatched_task_count.fetch_add(static_cast<std::uint64_t>(tasks),
                                    std::memory_order_relaxed);
}""",
"""inline void observe_dispatch(std::size_t tasks) noexcept {
#if MAT003_TWIN_OBSERVERS
    dispatch_calls.fetch_add(1, std::memory_order_relaxed);
    dispatched_task_count.fetch_add(static_cast<std::uint64_t>(tasks),
                                    std::memory_order_relaxed);
#else
    (void)tasks;
#endif
}"""),
        (
"""inline void observe_worker_task() noexcept {
    executed_worker_task_count.fetch_add(1, std::memory_order_relaxed);
}""",
"""inline void observe_worker_task() noexcept {
#if MAT003_TWIN_OBSERVERS
    executed_worker_task_count.fetch_add(1, std::memory_order_relaxed);
#endif
}"""),
        (
"""inline DispatchObservations dispatch_observations() noexcept {
    return {dispatch_calls.load(std::memory_order_relaxed),
            dispatched_task_count.load(std::memory_order_relaxed),
            executed_worker_task_count.load(std::memory_order_relaxed)};
}""",
"""inline DispatchObservations dispatch_observations() noexcept {
#if MAT003_TWIN_OBSERVERS
    return {dispatch_calls.load(std::memory_order_relaxed),
            dispatched_task_count.load(std::memory_order_relaxed),
            executed_worker_task_count.load(std::memory_order_relaxed)};
#else
    return {};
#endif
}"""),
        (
"""inline void reset_dispatch_observations() noexcept {
    dispatch_calls.store(0, std::memory_order_relaxed);
    dispatched_task_count.store(0, std::memory_order_relaxed);
    executed_worker_task_count.store(0, std::memory_order_relaxed);
}""",
"""inline void reset_dispatch_observations() noexcept {
#if MAT003_TWIN_OBSERVERS
    dispatch_calls.store(0, std::memory_order_relaxed);
    dispatched_task_count.store(0, std::memory_order_relaxed);
    executed_worker_task_count.store(0, std::memory_order_relaxed);
#endif
}""")
    ]
    for old, new in blocks:
        if text.count(old) != 1:
            raise ValueError("S2A observer block drift")
        text = text.replace(old, new, 1)
    path.write_text(text, encoding="utf-8")
    return {"path": path.relative_to(overlay).as_posix(),
            "before_sha256": hashlib.sha256(before.encode()).hexdigest(),
            "after_sha256": digest(path),
            "kind": "compile-time observer-off gate"}


def qualification_cases(reg: dict) -> list[dict]:
    seen: set[tuple[str, str]] = set()
    rows: list[dict] = []
    for contrast in reg["contrasts"]:
        anchor_key = contrast["anchor"]
        anchor = reg["anchors"][anchor_key]
        for arm in (contrast["a"], contrast["b"]):
            key = (arm, anchor_key)
            if key in seen:
                continue
            seen.add(key)
            rows.append({"arm_id": arm, "anchor_key": anchor_key, **anchor})
    return rows


def collect(output: Path, compiler_request: str) -> dict:
    output = output.resolve()
    if output.exists():
        raise ValueError("output exists: S2A apparatus evidence is append-only")
    compiler = shutil.which(compiler_request)
    if compiler is None:
        raise ValueError("required compiler unavailable: " + compiler_request)
    compiler = str(Path(compiler).resolve())
    output.mkdir(parents=True)
    environment = dict(os.environ)
    started = time.monotonic()

    registration = json.loads((ROOT / HERE / "registration.json").read_text())
    s1 = json.loads((ROOT / S1 / "world_registration.json").read_text())
    limits = registration["execution"]
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report = {
        "schema_version": 1, "stage": registration["stage"],
        "status": "incomplete", "apparatus_qualification": False,
        "formal_timing_admitted": False, "performance_comparisons_admitted": False,
        "source_head": head,
        "source_status": subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines(),
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "platform": {"system": platform.system(), "machine": platform.machine(),
                     "kernel": platform.release(), "python": platform.python_version()},
        "compiler": compiler, "compiler_sha256": digest(Path(compiler)),
        "source_sha256": {}, "overlays": {}, "binaries": {},
        "qualification_cases": [], "compile_count": 0,
        "qualification_process_count": 0, "errors": [], "files": {}
    }

    def remaining(limit: int) -> int:
        left = limits["apparatus_wall_budget_seconds"] - (time.monotonic() - started)
        if left <= 0:
            raise ValueError("S2A apparatus wall budget exhausted")
        return max(1, min(limit, int(left)))

    try:
        if registration["status"] != "preregistered-apparatus-qualification-only" or \
                registration["formal_timing_admitted"] is not False or \
                registration["performance_comparisons_admitted"] is not False:
            raise ValueError("S2A apparatus collector cannot run after timing admission")
        if registration["baseline_native_commit"] != s1["planning_commit"]:
            raise ValueError("S2A baseline disagrees with frozen S1 registration")
        if platform.system() != "Linux" or platform.machine() != "x86_64":
            raise ValueError("S2A apparatus is registered on Linux x86_64 only")

        cases = qualification_cases(registration)
        if len(cases) != registration["apparatus_qualification"]["expected_unique_arm_contexts"]:
            raise ValueError("S2A unique arm/context qualification set changed")

        source = output / "source"
        inputs = set(s1["baseline_control_sha256"])
        for item in (ROOT / S1).iterdir():
            if item.is_file() and item.suffix in (".py", ".hpp", ".cpp", ".json"):
                inputs.add(item.relative_to(ROOT).as_posix())
        for item in (ROOT / HERE).iterdir():
            if item.is_file() and item.suffix in (".py", ".hpp", ".cpp", ".json"):
                inputs.add(item.relative_to(ROOT).as_posix())

        for name in sorted(inputs):
            original = ROOT / name
            frozen = source / name
            frozen.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, frozen)
            report["source_sha256"][name] = digest(frozen)

        for name, expected in s1["baseline_control_sha256"].items():
            historical = subprocess.check_output(
                ["git", "show", registration["baseline_native_commit"] + ":" + name], cwd=ROOT)
            if hashlib.sha256(historical).hexdigest() != expected or \
                    report["source_sha256"][name] != expected:
                raise ValueError("S2A native source drift: " + name)

        version = command([compiler, "--version"], source, output, "compiler-version", 10, environment)
        linker = command(["ld", "--version"], source, output, "linker-version", 10, environment)
        if not succeeded(version) or not succeeded(linker):
            raise ValueError("S2A toolchain identification failed")
        if "13.3.0" not in (output / version["stdout"]).read_text():
            raise ValueError("S2A GCC 13.3.0 pin not satisfied")
        if "2.42" not in (output / linker["stdout"]).read_text():
            raise ValueError("S2A ld 2.42 pin not satisfied")
        report["compiler_version_receipt"] = version
        report["linker_version_receipt"] = linker

        overlay_module = load_module(source / S1 / "world_overlay.py", "mat003_s2a_overlay")
        arms = {arm["id"]: arm for arm in s1["arms"]}
        required_arm_order: list[str] = []
        for case in cases:
            if case["arm_id"] not in required_arm_order:
                required_arm_order.append(case["arm_id"])
        if len(required_arm_order) != limits["maximum_builds"]:
            raise ValueError("S2A required arm/build count changed")

        fixture = source / HERE / "fixture.cpp"
        for arm_id in required_arm_order:
            report["compile_count"] += 1
            overlay = output / "overlays" / arm_id
            receipt = overlay_module.prepare_overlay(source, overlay, arms[arm_id])
            observer_patch = patch_observer_off(overlay)
            overlay_sha = tree_digest(overlay)
            binary = output / "bin" / arm_id
            binary.parent.mkdir(parents=True, exist_ok=True)
            argv = [
                compiler, *limits["flags"], *receipt["compile_definitions"],
                "-DMAT003_TWIN_OBSERVERS=0",
                "-I" + str(overlay / "native/include"),
                "-I" + str(overlay / S1),
                str(fixture), str(overlay / "native/src/world.cpp"),
                *(str(overlay / name) for name in COMMON), "-o", str(binary)
            ]
            compile_receipt = command(
                argv, source, output, "compile/" + arm_id,
                remaining(limits["compile_timeout_seconds"]), environment)
            if not succeeded(compile_receipt):
                raise ValueError("S2A compile failed: " + arm_id)
            if (output / compile_receipt["stderr"]).read_bytes().strip():
                raise ValueError("S2A compile stderr not empty: " + arm_id)
            report["overlays"][arm_id] = {
                "tree_sha256": overlay_sha,
                "observer_patch": observer_patch,
                "world_overlay_receipt": receipt
            }
            report["binaries"][arm_id] = {
                "path": binary.relative_to(output).as_posix(),
                "sha256": digest(binary),
                "overlay_tree_sha256": overlay_sha,
                "compile": compile_receipt
            }

        if report["compile_count"] != limits["maximum_builds"]:
            raise ValueError("S2A build matrix incomplete")
        dump(output / "sealed-binaries.json", {
            "status": "sealed-before-qualification-and-timing",
            "source_head": head,
            "formal_timing_admitted": False,
            "binaries": {arm: {"path": row["path"], "sha256": row["sha256"],
                               "overlay_tree_sha256": row["overlay_tree_sha256"]}
                         for arm, row in report["binaries"].items()}
        })

        for case in cases:
            report["qualification_process_count"] += 1
            if report["qualification_process_count"] > limits["maximum_qualification_processes"]:
                raise ValueError("S2A qualification process budget exceeded")
            arm_id = case["arm_id"]
            binary_info = report["binaries"][arm_id]
            binary = output / binary_info["path"]
            if digest(binary) != binary_info["sha256"]:
                raise ValueError("S2A binary changed after seal: " + arm_id)
            argv = [
                str(binary), "--side", str(case["side"]), "--workers", str(case["workers"]),
                "--warmup", str(registration["inputs"]["warmup_ticks"]),
                "--ticks", str(registration["inputs"]["sample_ticks"]),
                "--seed", str(registration["inputs"]["seed"]),
                "--scenario", case["scenario"], "--mode", "qualify"
            ]
            case_id = arm_id + "__" + case["id"]
            receipt = command(
                argv, source, output, "qualify/" + case_id,
                remaining(limits["qualification_timeout_seconds"]), environment)
            report["qualification_cases"].append({
                "id": case_id, "arm_id": arm_id, "anchor_key": case["anchor_key"],
                "anchor_id": case["id"], "receipt": receipt
            })
            if not succeeded(receipt):
                raise ValueError("S2A qualifier failed/timed out: " + case_id)
            if (output / receipt["stderr"]).read_bytes().strip():
                raise ValueError("S2A qualifier stderr not empty: " + case_id)
            value = json.loads((output / receipt["stdout"]).read_text())
            if value.get("status") != "passed" or value.get("mode") != "qualify" or \
                    value.get("performance_qualification") is not False or \
                    value.get("formal_timing_admitted") is not False or \
                    value.get("tick_ns") != [] or value.get("input_ns") != [] or \
                    value.get("startup_ns") != 0:
                raise ValueError("S2A qualifier emitted timing or malformed result: " + case_id)

        if report["qualification_process_count"] != limits["maximum_qualification_processes"]:
            raise ValueError("S2A qualification matrix incomplete")
        report["status"] = "passed-apparatus-qualification"
        report["apparatus_qualification"] = True
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
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
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--compiler", default="g++-13")
    args = parser.parse_args()
    try:
        result = collect(args.output, args.compiler)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(json.dumps({
        "status": result["status"],
        "apparatus_qualification": result["apparatus_qualification"],
        "formal_timing_admitted": False,
        "compile_count": result["compile_count"],
        "qualification_process_count": result["qualification_process_count"],
        "errors": result["errors"]
    }, indent=2))
    return int(result["status"] != "passed-apparatus-qualification")


if __name__ == "__main__":
    raise SystemExit(main())
