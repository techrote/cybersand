#!/usr/bin/env python3
"""Build and qualify untimed MAT-003 S2 candidate twins; never admit performance timing."""
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
PERF = Path("tools/experiments/mat003_perf")
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
        raise ValueError("cannot load captured apparatus: " + str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def command(argv: list[str], cwd: Path, output: Path, label: str, timeout: int,
            environment: dict[str, str]) -> dict:
    out = output / (label + ".stdout")
    err = output / (label + ".stderr")
    out.parent.mkdir(parents=True, exist_ok=True)
    row = {"argv": argv, "cwd": str(cwd), "timeout": timeout,
           "stdout": out.relative_to(output).as_posix(),
           "stderr": err.relative_to(output).as_posix(),
           "exit_code": None, "timed_out": False}
    with out.open("wb") as stdout, err.open("wb") as stderr:
        try:
            completed = subprocess.run(argv, cwd=cwd, env=environment, stdout=stdout,
                                       stderr=stderr, timeout=timeout, check=False)
            row["exit_code"] = completed.returncode
        except subprocess.TimeoutExpired:
            row["timed_out"] = True
        except OSError as exc:
            stderr.write(str(exc).encode("utf-8"))
            row["exit_code"] = -1
    return row


def succeeded(row: dict) -> bool:
    return row["exit_code"] == 0 and row["timed_out"] is False


def patch_twin_adapter(overlay: Path) -> dict:
    path = overlay / S1 / "world_adapter.hpp"
    before = path.read_text(encoding="utf-8")
    text = before
    marker = "struct DispatchObservations {"
    if text.count(marker) != 1:
        raise ValueError("candidate twin adapter marker drift")
    text = text.replace(
        marker,
        "#ifndef MAT003_TWIN_OBSERVERS\n"
        "#error \"MAT003_TWIN_OBSERVERS must be supplied by candidate twin build\"\n"
        "#endif\n\n" + marker,
        1,
    )

    replacements = [
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
}""",
        ),
        (
"""inline void observe_worker_task() noexcept {
    executed_worker_task_count.fetch_add(1, std::memory_order_relaxed);
}""",
"""inline void observe_worker_task() noexcept {
#if MAT003_TWIN_OBSERVERS
    executed_worker_task_count.fetch_add(1, std::memory_order_relaxed);
#endif
}""",
        ),
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
}""",
        ),
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
}""",
        ),
    ]
    for old, new in replacements:
        if text.count(old) != 1:
            raise ValueError("candidate twin adapter observer block drift")
        text = text.replace(old, new, 1)
    path.write_text(text, encoding="utf-8")
    return {"path": path.relative_to(overlay).as_posix(),
            "before_sha256": hashlib.sha256(before.encode()).hexdigest(),
            "after_sha256": digest(path),
            "patch_kind": "compile-time observer on/off only"}


def collect(output: Path, compiler_request: str, source_evidence: Path,
            source_readback: Path) -> dict:
    output = output.resolve()
    source_evidence = source_evidence.resolve()
    source_readback = source_readback.resolve()
    if output.exists():
        raise ValueError("output exists: candidate evidence is append-only")
    compiler = shutil.which(compiler_request)
    if compiler is None:
        raise ValueError("required compiler unavailable: " + compiler_request)
    compiler = str(Path(compiler).resolve())
    output.mkdir(parents=True)
    started = time.monotonic()
    environment = dict(os.environ)

    spec = json.loads((ROOT / PERF / "s2f_registration.json").read_text())
    s1_registration = json.loads((ROOT / S1 / "world_registration.json").read_text())
    twin = spec["candidate_twin_qualification"]
    limits = twin["execution"]
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()

    report = {
        "schema_version": 1, "stage": "S2-candidate-twins", "status": "incomplete",
        "performance_qualification": False, "formal_timing_admitted": False,
        "source_head": head,
        "source_status": subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines(),
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "platform": {"system": platform.system(), "machine": platform.machine(),
                     "kernel": platform.release(), "python": platform.python_version()},
        "compiler": compiler, "compiler_sha256": digest(Path(compiler)),
        "source_evidence": {}, "source_sha256": {}, "overlays": {},
        "binaries": {}, "processes": [], "errors": [], "files": {},
        "compile_count": 0, "fixture_count": 0,
    }

    def remaining(limit: int) -> int:
        left = limits["total_wall_budget_seconds"] - (time.monotonic() - started)
        if left <= 0:
            raise ValueError("candidate twin wall budget exhausted; evidence incomplete")
        return max(1, min(limit, int(left)))

    try:
        if spec["status"] != "preregistered-full-source-and-candidate-twins-untimed" or \
                spec["formal_timing_admitted"] is not False or \
                spec["performance_comparisons_admitted"] is not False or \
                twin["admitted"] is not True or twin["timed"] is not False:
            raise ValueError("candidate twin registration does not authorize this untimed stage")
        if platform.system() != "Linux" or platform.machine() != "x86_64":
            raise ValueError("candidate twins registered on Linux x86_64 only")

        readback = json.loads(source_readback.read_text())
        source_run = json.loads((source_evidence / "run.json").read_text())
        if readback.get("status") != "passed" or \
                readback.get("source_context_qualification") is not True or \
                len(readback.get("checked_cases", [])) != 24:
            raise ValueError("full source independent readback prerequisite did not pass")
        if source_run.get("status") != "passed-source-context-qualification" or \
                source_run.get("source_head") != head or len(source_run.get("processes", [])) != 24:
            raise ValueError("source qualification evidence does not bind this candidate head")
        report["source_evidence"] = {
            "run_sha256": digest(source_evidence / "run.json"),
            "readback_sha256": digest(source_readback),
            "source_head": source_run["source_head"],
            "process_count": len(source_run["processes"]),
        }

        source = output / "source"
        inputs = set(s1_registration["baseline_control_sha256"])
        for item in (ROOT / S1).iterdir():
            if item.is_file() and item.suffix in (".py", ".hpp", ".cpp", ".json"):
                inputs.add(item.relative_to(ROOT).as_posix())
        inputs.update({
            (PERF / "s2f_registration.json").as_posix(),
            (PERF / "candidate_twins.py").as_posix(),
            (PERF / "verify_candidate_twins.py").as_posix(),
            (PERF / "twin_fixture.cpp").as_posix(),
        })
        for name in sorted(inputs):
            original = ROOT / name
            frozen = source / name
            frozen.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, frozen)
            report["source_sha256"][name] = digest(frozen)

        for name, expected in s1_registration["baseline_control_sha256"].items():
            historical = subprocess.check_output(
                ["git", "show", spec["baseline_native_commit"] + ":" + name], cwd=ROOT)
            if hashlib.sha256(historical).hexdigest() != expected or \
                    report["source_sha256"][name] != expected:
                raise ValueError("candidate twin native control drift: " + name)

        version = command([compiler, "--version"], source, output, "compiler-version", 10, environment)
        linker = command(["ld", "--version"], source, output, "linker-version", 10, environment)
        if not succeeded(version) or not succeeded(linker):
            raise ValueError("candidate twin toolchain identification failed")
        if "13.3.0" not in (output / version["stdout"]).read_text():
            raise ValueError("candidate twin GCC 13.3.0 pin not satisfied")
        if "2.42" not in (output / linker["stdout"]).read_text():
            raise ValueError("candidate twin ld 2.42 pin not satisfied")
        report["compiler_version"] = version
        report["linker_version"] = linker

        overlay_module = load_module(source / S1 / "world_overlay.py", "mat003_candidate_twin_overlay")
        arm_map = {arm["id"]: arm for arm in s1_registration["arms"]}
        if twin["arms"] != [arm["id"] for arm in s1_registration["arms"]]:
            raise ValueError("candidate twin arm order differs from S1 registered arms")

        fixture = source / PERF / "twin_fixture.cpp"
        for arm_id in twin["arms"]:
            arm = arm_map[arm_id]
            overlay = output / "overlays" / arm_id
            receipt = overlay_module.prepare_overlay(source, overlay, arm)
            adapter_patch = patch_twin_adapter(overlay)
            overlay_sha = tree_digest(overlay)
            report["overlays"][arm_id] = {
                "tree_sha256": overlay_sha,
                "adapter_patch": adapter_patch,
                "world_overlay_receipt": receipt,
            }
            for mode, observer_value in (("observed", 1), ("timing-twin", 0)):
                report["compile_count"] += 1
                if report["compile_count"] > limits["maximum_arm_builds"]:
                    raise ValueError("candidate twin compile process budget exceeded")
                binary = output / "bin" / arm_id / mode
                binary.parent.mkdir(parents=True, exist_ok=True)
                argv = [
                    compiler, *limits["flags"], *receipt["compile_definitions"],
                    f"-DMAT003_TWIN_OBSERVERS={observer_value}",
                    "-I" + str(overlay / "native/include"),
                    "-I" + str(overlay / S1),
                    str(fixture), str(overlay / "native/src/world.cpp"),
                    *(str(overlay / name) for name in COMMON),
                    "-o", str(binary),
                ]
                label = "compile/" + arm_id + "-" + mode
                compile_receipt = command(
                    argv, source, output, label,
                    remaining(limits["compile_timeout_seconds"]), environment)
                if not succeeded(compile_receipt):
                    raise ValueError("candidate twin compile failed: " + arm_id + "/" + mode)
                if (output / compile_receipt["stderr"]).read_bytes().strip():
                    raise ValueError("candidate twin compile stderr not empty: " + arm_id + "/" + mode)
                report["binaries"][arm_id + "/" + mode] = {
                    "path": binary.relative_to(output).as_posix(),
                    "sha256": digest(binary),
                    "overlay_tree_sha256": overlay_sha,
                    "observer_define": observer_value,
                    "compile": compile_receipt,
                }

        if report["compile_count"] != limits["maximum_arm_builds"]:
            raise ValueError("candidate twin build matrix incomplete before seal")
        dump(output / "sealed-binaries.json", {
            "status": "sealed-before-any-fixture-execution",
            "source_head": head,
            "performance_qualification": False,
            "binaries": {key: {"path": value["path"], "sha256": value["sha256"],
                               "overlay_tree_sha256": value["overlay_tree_sha256"],
                               "observer_define": value["observer_define"]}
                         for key, value in report["binaries"].items()},
        })

        for arm_id in twin["arms"]:
            for mode in twin["observer_modes"]:
                binary_info = report["binaries"][arm_id + "/" + mode]
                binary = output / binary_info["path"]
                if digest(binary) != binary_info["sha256"]:
                    raise ValueError("candidate twin binary changed after seal: " + arm_id + "/" + mode)
                for anchor in twin["anchors"]:
                    report["fixture_count"] += 1
                    if report["fixture_count"] > limits["maximum_fixture_processes"]:
                        raise ValueError("candidate twin fixture process budget exceeded")
                    case_id = arm_id + "__" + mode + "__" + anchor["id"]
                    argv = [
                        str(binary), "--side", str(anchor["side"]),
                        "--workers", str(anchor["workers"]),
                        "--warmup", str(twin["warmup_ticks"]),
                        "--ticks", str(twin["sample_ticks"]),
                        "--seed", str(twin["seed"]),
                        "--scenario", anchor["scenario"],
                        "--observer", mode,
                    ]
                    receipt = command(
                        argv, source, output, "cases/" + case_id,
                        remaining(limits["fixture_timeout_seconds"]), environment)
                    report["processes"].append({
                        "id": case_id, "arm_id": arm_id, "observer_mode": mode,
                        "anchor_id": anchor["id"], "receipt": receipt,
                    })
                    if not succeeded(receipt):
                        raise ValueError("candidate twin fixture failed/timed out: " + case_id)
                    if (output / receipt["stderr"]).read_bytes().strip():
                        raise ValueError("candidate twin fixture stderr not empty: " + case_id)
                    observed = json.loads((output / receipt["stdout"]).read_text())
                    if observed.get("status") != "passed" or \
                            observed.get("performance_qualification") is not False or \
                            observed.get("formal_timing_admitted") is not False or \
                            observed.get("tick_ns") != [] or observed.get("input_ns") != []:
                        raise ValueError("candidate twin emitted timing or malformed result: " + case_id)

        if report["fixture_count"] != limits["maximum_fixture_processes"]:
            raise ValueError("candidate twin fixture matrix incomplete")
        report["status"] = "passed-candidate-twins"
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
    parser.add_argument("--source-evidence", required=True, type=Path)
    parser.add_argument("--source-readback", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = collect(args.output, args.compiler, args.source_evidence, args.source_readback)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(json.dumps({"status": result["status"], "formal_timing_admitted": False,
                      "performance_qualification": False, "errors": result["errors"]}, indent=2))
    return int(result["status"] != "passed-candidate-twins")


if __name__ == "__main__":
    raise SystemExit(main())
