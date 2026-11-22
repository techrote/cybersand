#!/usr/bin/env python3
"""Run actual Godot 4.7 source-matched M4 refusal/latency and Workbench regressions.

The native same-World adapter is not present in frozen M3. This runner MUST NOT
interpret these tests as successful ObjectShard native/physics integration.
All test processes and raw logs are retained. No native build is performed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot"
CASES = (
    ("m4_real_worker_refusal", "test_object_shard_m4_workbench_port.gd",
     "objectshard-m4-workbench-contract-v1"),
    ("m4_latency_value_contract", "test_object_shard_m4_latency_probe.gd",
     "objectshard-m4-workbench-probe-test-v1"),
    ("m4_real_scene_pointer_refusal", "test_object_shard_m4_workbench_scene_refusal.gd",
     "objectshard-m4-ordinary-scene-refusal-v1"),
    ("existing_native_mutable_refusal", "test_object_shard_workbench_contract.gd",
     "objectshard-workbench-boundary-test-v1"),
)
REGRESSIONS = (
    ("ordinary_paint_ordering", "test_workbench_edit_ordering.gd", ""),
    ("ordinary_physics", "test_workbench_physics_play.gd", ""),
    ("water_live_edits", "test_workbench_live_liquid_edit.gd", ""),
    ("water_wave", "test_workbench_wave.gd", ""),
)
M3_CONTROLS = (
    ("m3_input_fences", "test_object_shard_worker_input_fences.gd", ""),
    ("m3_lifecycle", "test_object_shard_worker_navigation.gd", ""),
    ("m3_capacity", "test_object_shard_worker_resources.gd", ""),
)
PROTECTED_SOURCES = (
    "godot/scripts/main.gd",
    "godot/scripts/shared_workbench.gd",
    "godot/scripts/simulation_worker.gd",
    "godot/scripts/workbench_physics_bridge.gd",
    "godot/scripts/object_shard_m4_workbench_port.gd",
    "godot/scripts/object_shard_m4_latency_probe.gd",
    "godot/tests/test_object_shard_m4_workbench_port.gd",
    "godot/tests/test_object_shard_m4_latency_probe.gd",
    "godot/tests/test_object_shard_m4_workbench_scene_refusal.gd",
    "godot/tests/test_object_shard_workbench_contract.gd",
    "tools/objectshard/qualify_m4_workbench.py",
)


def source_identity(expected_sha: str) -> dict:
    revision = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"], capture_output=True, text=True,
        check=True, timeout=30,
    ).stdout.strip()
    if not re.fullmatch(r"[a-f0-9]{40}", expected_sha) or revision != expected_sha:
        raise ValueError("Source mismatch: actual=%s expected=%s" % (revision, expected_sha))
    tree = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD^{tree}"],
        capture_output=True, text=True, check=True, timeout=30,
    ).stdout.strip()
    # A matching HEAD SHA alone does not identify tests executed from a
    # dirty checkout. Fail closed on staged, unstaged or untracked source edits.
    dirty = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain=v1", "--", *PROTECTED_SOURCES],
        capture_output=True, text=True, check=True, timeout=30,
    ).stdout.strip()
    if dirty:
        raise ValueError("M4 executable source is dirty; commit or restore changes:\n" + dirty)
    files = {}
    for path in PROTECTED_SOURCES:
        content = (ROOT / path).read_bytes()
        files[path] = hashlib.sha256(content).hexdigest()
    return {"commit": revision, "tree": tree, "files": files,
            "protected_source_clean": True, "native_build_claimed": False}


def complete_receipt(text: str, schema: str) -> dict:
    """Only one real test's exact terminal receipt can qualify that case."""
    found = []
    for line in text.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("schema") == schema:
            found.append(value)
    if len(found) != 1:
        raise ValueError("Missing/duplicate JSON completion receipt: %s" % schema)
    receipt = found[0]
    if (type(receipt.get("checks")) is not int or receipt["checks"] <= 0
            or type(receipt.get("failures")) is not int or receipt["failures"] != 0):
        raise ValueError("Failed/invalid test completion: %s" % schema)
    if schema == "objectshard-m4-workbench-contract-v1":
        if (receipt.get("same_world_mutation_integration") != "BLOCKED_UNTIL_NATIVE_ADAPTER"
                or receipt.get("real_physics_assertions") != 0):
            raise ValueError("M4 negative boundary misrepresented as integrated physics")
    if schema == "objectshard-m4-ordinary-scene-refusal-v1":
        if (receipt.get("actual_ordinary_native_world_used") is not True
                or receipt.get("same_world_mutation_integration") != "BLOCKED_UNTIL_NATIVE_ADAPTER"):
            raise ValueError("Ordinary scene negative check misrepresented as integrated physics")
    return receipt


def run_case(godot: Path, output: Path, name: str, script: str,
             schema: str, timeout: int) -> dict:
    path = PROJECT / "tests" / script
    if not path.is_file():
        raise ValueError("Missing required Godot test: " + script)
    command = [str(godot), "--headless", "--path", str(PROJECT),
               "--script", "res://tests/" + script]
    if script == "test_object_shard_m4_workbench_scene_refusal.gd":
        command += ["--", "--objectshard-m4-workbench"]
    log = output / (name + ".log")
    result = {"name": name, "script": script, "expected_schema": schema,
              "raw_log": str(log), "command": command, "status": "failed",
              "scope": "real_Godot_execution_not_same_World_mutation"}
    try:
        process = subprocess.run(
            command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace", cwd=ROOT, timeout=timeout, check=False,
        )
        log.write_text(process.stdout, encoding="utf-8")
        result["exit_code"] = process.returncode
        if process.returncode != 0:
            result["error"] = "Godot process exited nonzero"
            return result
        if schema:
            result["receipt"] = complete_receipt(process.stdout, schema)
        result["status"] = "passed"
        return result
    except subprocess.TimeoutExpired as exc:
        log.write_text(
            (exc.stdout or b"").decode("utf-8", errors="replace")
            if isinstance(exc.stdout, bytes) else (exc.stdout or ""),
            encoding="utf-8",
        )
        result["error"] = "Process exceeded %ds; recorded partial stdout" % timeout
        return result
    except (ValueError, OSError) as exc:
        result["error"] = str(exc)
        if not log.exists():
            log.write_text("Qualification exception: " + str(exc) + "\n", encoding="utf-8")
        return result


def qualify(args: argparse.Namespace) -> dict:
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    identity = source_identity(args.expected_source_sha)
    godot = args.godot.expanduser().resolve()
    if not godot.is_file():
        raise ValueError("Actual Godot executable required; missing " + str(godot))
    version = subprocess.run(
        [str(godot), "--version"], capture_output=True, text=True,
        timeout=60, check=True,
    ).stdout.strip()
    if not version.startswith("4.7."):
        raise ValueError("Godot 4.7 required; observed " + version)
    results = []
    cases = CASES + (REGRESSIONS if args.regressions else ())
    if args.m3_controls:
        cases += M3_CONTROLS
    for name, script, schema in cases:
        results.append(run_case(godot, output, name, script, schema, args.timeout_seconds))
    passed = sum(item["status"] == "passed" for item in results)
    report = {
        "schema": "objectshard-m4-workbench-source-qualification-v1",
        "source": identity, "engine_version": version,
        "status": "passed_negative_and_regression_checks" if passed == len(results) else "failed",
        "completed_cases": passed, "requested_cases": len(results), "cases": results,
        "same_world_shard_terrain_physics": "BLOCKED_UNTIL_NATIVE_ADAPTER",
        "Windows_GPU_frame_latency": "NOT_MEASURED_BY_HEADLESS_RUNNER",
        "publication_claim": "Godot test process output only; no graphical presentation or FPS",
        "requires_native_rig_receipts_for_integration": True,
    }
    (output / "m4-qualification.json").write_text(json.dumps(report, indent=2) + "\n",
                                                   encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", type=Path, default=Path("build/objectshard-m4"))
    parser.add_argument("--timeout-seconds", type=int, default=240)
    parser.add_argument("--regressions", action="store_true",
                        help="Add ordinary Workbench brush, physics and Water tests")
    parser.add_argument("--m3-controls", action="store_true",
                        help="Add M3 standalone control tests (not same-World proof)")
    args = parser.parse_args()
    if args.timeout_seconds < 1 or args.timeout_seconds > 3600:
        parser.error("timeout-seconds must be 1..3600")
    try:
        report = qualify(args)
    except (ValueError, subprocess.SubprocessError, OSError) as exc:
        print(json.dumps({"schema": "objectshard-m4-workbench-runner-refusal-v1",
                          "status": "refused", "reason": str(exc)}))
        return 2
    print(json.dumps({"schema": report["schema"], "status": report["status"],
                      "completed_cases": report["completed_cases"],
                      "requested_cases": report["requested_cases"],
                      "source_sha": report["source"]["commit"],
                      "same_world_integration": "BLOCKED_UNTIL_NATIVE_ADAPTER"}))
    return 0 if report["status"] == "passed_negative_and_regression_checks" else 1


if __name__ == "__main__":
    sys.exit(main())
