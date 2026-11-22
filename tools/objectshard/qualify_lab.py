#!/usr/bin/env python3
"""Run the scoped Lab through existing process/watchdog ownership, retaining failures.

This does not replace ordinary repository qualification or publish a runtime.
Windows package replay reads the delivered project and its exact candidate DLL.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy
import native_candidate_identity
import run_godot_regressions as runner
from verify_package import verify as verify_package
from native_receipt import verify as verify_linux_receipt
from lab_performance import check as check_performance

VERSION = "4.7.stable.official.5b4e0cb0f"
RAPIER_HASHES = {"linux": "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a",
                 "win32": "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"}


def save(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def footer(path: Path, schema: str) -> dict:
    matches = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("schema") == schema:
            matches.append(value)
    if len(matches) != 1 or type(matches[0].get("failures")) is not int or matches[0]["failures"] != 0:
        raise ValueError("Missing, duplicate or unsuccessful completion receipt: " + schema)
    return matches[0]


def require_custody(platform: str, candidate: Path | None, package: Path | None, receipt: Path | None) -> None:
    if platform == "win32":
        if bool(candidate) == bool(package) or receipt:
            raise ValueError("Windows qualification requires exactly one source-bound native candidate or delivered package")
    elif platform.startswith("linux"):
        if not receipt or candidate or package:
            raise ValueError("Linux qualification requires its sealed precompile source receipt")
    else:
        raise ValueError("Unsupported ObjectShard qualification platform")


def verify_scripts(project_root: Path, expected: dict[str, str]) -> dict[str, str]:
    actual = {path: runner.sha256(project_root / path) for path in expected}
    if actual != expected:
        raise ValueError("Executed Lab source differs from the committed source contract")
    return actual


def qualify(args: argparse.Namespace) -> dict:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "objectshard-hosted-qualification-v1", "source_commit": args.expected_source_sha,
              "stage": args.stage, "status": "incomplete", "cases": [], "failures": [],
              "physical_owner_acceptance": "unrecorded; automated qualification is not owner physical acceptance"}
    try:
        if not re.fullmatch(r"[0-9a-f]{40}", args.expected_source_sha):
            raise ValueError("A complete expected source SHA is required")
        require_custody(sys.platform, args.native_candidate, args.package, args.native_receipt)
        commit, tree, inputs = native_candidate_identity.source(ROOT)
        if commit != args.expected_source_sha:
            raise ValueError("Checked-out source differs from requested source")
        report.update(source_tree=tree, native_source_inputs=inputs)
        lab_sources = ["godot/project.godot", "godot/object_shard_lab.tscn"]
        lab_sources += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / "godot/scripts").glob("object_shard_*.gd"))]
        lab_sources += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / "godot/tests").glob("*object_shard*.gd"))]
        lab_sources += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / "godot/tests/fixtures").glob("objectshard_*.json"))]
        lab_sources += ["godot/tests/test_rapier_manual_step.gd", "godot/tests/test_material_lab_experiment.gd"]
        lab_sources += ["tools/objectshard/lab_budgets.json"]
        subprocess.run(["git", "-C", str(ROOT), "diff", "--exit-code", "HEAD", "--", *lab_sources], check=True, timeout=120)
        script_inputs = {path: runner.sha256(ROOT / path) for path in lab_sources}
        report["lab_source_inputs"] = script_inputs
        qualifier_sources = [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / "tools/objectshard").glob("*.py"))]
        qualifier_sources += ["tools/ci/" + name for name in ("run_godot_regressions.py", "execution_policy.py", "native_candidate_identity.py")]
        qualifier_sources += ["godot/tests/support/ci_execution_policy.json"]
        subprocess.run(["git", "-C", str(ROOT), "ls-files", "--error-unmatch", "--", *lab_sources, *qualifier_sources],
                       check=True, timeout=120, stdout=subprocess.DEVNULL)
        subprocess.run(["git", "-C", str(ROOT), "diff", "--exit-code", "HEAD", "--", *qualifier_sources], check=True, timeout=120)
        qualifier_inputs = {path: runner.sha256(ROOT / path) for path in qualifier_sources}
        report["qualification_tool_inputs"] = qualifier_inputs
        executed_source = ROOT
        if args.package:
            package = verify_package(args.package)
            if package["source_commit"] != commit or package["source_tree"] != tree or package["native"]["source_inputs"] != inputs:
                raise ValueError("Delivered package differs from checked-out candidate source")
            runner.ROOT = args.package.resolve()
            executed_source = args.package.resolve()
            verify_scripts(executed_source, script_inputs)
            report["package_manifest_sha256"] = runner.sha256(args.package / "objectshard-lab-manifest.json")
        elif args.native_candidate and sys.platform == "win32":
            candidate = native_candidate_identity.verify(ROOT, args.native_candidate)
            actual = ROOT / native_candidate_identity.NATIVE
            if runner.sha256(actual) != candidate["sha256"]:
                raise ValueError("Loaded native DLL differs from the same-run candidate")
        native_path, rapier_path = runner.runtime_paths()
        if sys.platform.startswith("linux"):
            if not args.native_receipt:
                raise ValueError("Linux qualification requires a sealed precompile source receipt")
            report["native_build_receipt"] = verify_linux_receipt(args.native_receipt, native_path)
        if runner.sha256(rapier_path) != RAPIER_HASHES.get(sys.platform):
            raise ValueError("Selected platform Rapier identity mismatch")
        engine = args.godot.resolve()
        version = subprocess.check_output([str(engine), "--version"], text=True,
                    timeout=execution_policy.watchdog_seconds("operation_seconds")).strip()
        if version != VERSION:
            raise ValueError("Qualification requires the exact pinned engine: " + version)
        report["runtime"] = {"godot_version": version, "godot_sha256": runner.sha256(engine),
                             "native_sha256": runner.sha256(native_path), "rapier_sha256": runner.sha256(rapier_path),
                             "platform": sys.platform}
        environment = dict(os.environ, CYBERSAND_SOURCE_REVISION=commit)
        cases = [(runner.Case("objectshard_import", ("--editor", "--quit"),
                    int(execution_policy.watchdog_seconds("godot_import_seconds")), 0), None),
                 (runner.Case("test_rapier_manual_step", ("--script", "res://tests/test_rapier_manual_step.gd"),
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), None),
                 (runner.Case("test_material_lab_experiment", ("--script", "res://tests/test_material_lab_experiment.gd"),
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), None),
                 (runner.Case("objectshard_bridge", ("--script", "res://tests/test_object_shard_physics_bridge.gd"),
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-physics-bridge-test-v1"),
                 (runner.Case("objectshard_lab", ("--script", "res://tests/test_object_shard_lab.gd", "--",
                    "--objectshard-stage=" + args.stage, "--objectshard-report=" + str(output / "lab-result.json")),
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-lab-integration-test-v1"),
                 (runner.Case("objectshard_capture", ("--script", "res://tests/test_object_shard_capture.gd"),
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-capture-contract-test-v1")]
        if args.stage == "m2":
            cases += [(runner.Case("objectshard_motion_segments", ("--script", "res://tests/test_object_shard_motion_segments.gd"),
                        int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-motion-segment-test-v1"),
                      (runner.Case("objectshard_rest_contacts", ("--script", "res://tests/test_object_shard_rest_contacts.gd"),
                        int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-rest-contact-test-v1"),
                      (runner.Case("objectshard_boundary", ("--script", "res://tests/test_object_shard_boundary.gd"),
                        int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-boundary-contract-test-v1"),
                      (runner.Case("objectshard_playability", ("--script", "res://tests/test_object_shard_playability.gd", "--",
                        "--objectshard-playability-report=" + str(output / "playability-result.json"),
                        "--objectshard-playability-trace=" + str(output / "reproduction.trace.jsonl")),
                        int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-playability-contract-test-v1"),
                      (runner.Case("objectshard_action_replay", ("--script", "res://tests/replay_object_shard_trace.gd", "--",
                        "--objectshard-replay=" + str(output / "reproduction.trace.jsonl"),
                        "--objectshard-replay-report=" + str(output / "replay-result.json")),
                        int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-action-replay-v1")]
            for variant in ("erode", "replace-identical", "mass-only"):
                name = "objectshard_rest_" + variant.replace("-", "_")
                cases.append((runner.Case(name, ("--script", "res://tests/probe_object_shard_rest_stability.gd", "--",
                    "--variant=" + variant, "--bodies=3", "--output=" + str(output / (name + ".json"))),
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-rest-stability-probe-v1"))
            cases.append((runner.Case("objectshard_owner_d", ("--script", "res://tests/probe_object_shard_retained_actions.gd", "--",
                "--input=res://tests/fixtures/objectshard_owner_d_retained_actions.json", "--end-tick=3600",
                "--output=" + str(output / "owner-d-result.json")),
                int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-retained-action-probe-v1"))
        if args.render:
            driver = "opengl3_angle" if sys.platform == "win32" else "opengl3"
            cases.append((runner.Case("objectshard_render", ("--rendering-driver", driver, "--script",
                "res://tests/capture_object_shard_lab.gd", "--", "--objectshard-stage=" + args.stage,
                "--objectshard-capture=" + str(output / "frames")),
                int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True), "objectshard-render-campaign-v1"))
            if args.stage == "m2":
                cases.append((runner.Case("objectshard_finisher_render", ("--rendering-driver", driver, "--script",
                    "res://tests/capture_object_shard_finisher.gd", "--", "--objectshard-capture=" + str(output / "frames-finisher")),
                    int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True), "objectshard-finisher-render-campaign-v1"))
        if args.profile:
            if args.stage != "m2":
                raise ValueError("Complete Lab performance qualification requires implemented M2")
            for rendered in ([False, True] if args.render else [False]):
                name = "objectshard_profile_rendered" if rendered else "objectshard_profile_headless"
                command = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") if rendered else ()
                command += ("--script", "res://tests/profile_object_shard_lab.gd", "--",
                            "--objectshard-profile=" + str(output / (name + ".json")))
                if rendered:
                    command += ("--objectshard-profile-rendered",)
                cases.append((runner.Case(name, command,
                    int(execution_policy.watchdog_seconds("graphical_case_seconds" if rendered else "ordinary_case_seconds")), 0, rendered),
                    "objectshard-lab-profile-v1"))
        for case, schema in cases:
            record, failed = runner.run_case(str(engine), case, output, "ObjectShard scoped qualification", env=environment)
            report["cases"].append(record)
            if failed:
                raise ValueError("Actual Godot process failed: " + case.name)
            if schema:
                receipt = footer(output / record["log"], schema)
                if schema.endswith("test-v1") and (type(receipt.get("checks")) is not int or receipt["checks"] < 20):
                    raise ValueError("Incomplete assertion inventory: " + case.name)
                record["completion_receipt"] = receipt
                if schema == "objectshard-action-replay-v1" and (receipt.get("actions", 0) < 1 or receipt.get("steps", 0) < 1):
                    raise ValueError("Replay did not execute actual inputs and native steps")
                if schema in ("objectshard-rest-stability-probe-v1", "objectshard-retained-action-probe-v1"):
                    minimum = 20 if schema == "objectshard-rest-stability-probe-v1" else 17
                    if type(receipt.get("checks")) is not int or receipt["checks"] < minimum:
                        raise ValueError("Incomplete physical-probe assertion inventory: " + case.name)
                if schema in ("objectshard-render-campaign-v1", "objectshard-finisher-render-campaign-v1"):
                    expected_captures = {"m0": 4, "m1": 6, "m2": 10}[args.stage] if schema == "objectshard-render-campaign-v1" else 5
                    images_directory = output / ("frames" if schema == "objectshard-render-campaign-v1" else "frames-finisher")
                    campaign = json.loads((images_directory / "render-campaign.json").read_text(encoding="utf-8"))
                    images = [row.get("image", "") for row in campaign.get("observations", [])]
                    if receipt.get("captures") != expected_captures or len(images) != expected_captures or len(set(images)) != expected_captures:
                        raise ValueError("Incomplete actual-render inventory")
                    record["rendered_images"] = {}
                    for name in images:
                        if Path(name).name != name or not name.endswith(".png"):
                            raise ValueError("Invalid rendered image path")
                        picture = images_directory / name
                        if picture.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
                            raise ValueError("Missing actual PNG evidence")
                        record["rendered_images"][name] = runner.sha256(picture)
                if schema == "objectshard-lab-profile-v1":
                    profile = json.loads((output / (case.name + ".json")).read_text(encoding="utf-8"))
                    budget = json.loads((ROOT / "tools/objectshard/lab_budgets.json").read_text(encoding="utf-8"))
                    record["budget_qualification"] = check_performance(profile, budget, rendered=case.name.endswith("rendered"))
                    if record["budget_qualification"]["status"] != "passed":
                        raise ValueError("Registered Lab budget qualification failed: " + case.name)
            save(output / "qualification.json", report)
        lab = json.loads((output / "lab-result.json").read_text(encoding="utf-8"))
        required = {"m0": {1}, "m1": {1, 2}, "m2": {1, 2, 3, 4}}[args.stage]
        completed = {row.get("scenario") for row in lab.get("scenarios", []) if not row.get("failed", True)}
        if lab.get("failures") != 0 or not required.issubset(completed):
            raise ValueError("Mandatory executable scenario inventory is incomplete")
        if native_candidate_identity.source(ROOT) != (commit, tree, inputs) or runner.sha256(native_path) != report["runtime"]["native_sha256"] \
                or verify_scripts(ROOT, script_inputs) != script_inputs or verify_scripts(executed_source, script_inputs) != script_inputs \
                or verify_scripts(ROOT, qualifier_inputs) != qualifier_inputs:
            raise ValueError("Candidate source/runtime changed during qualification")
        report["status"] = "passed"
    except Exception as error:
        report["failures"].append(f"{type(error).__name__}: {error}")
        report["status"] = "failed"
    finally:
        save(output / "qualification.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--stage", choices=("m0", "m1", "m2"), default="m2")
    parser.add_argument("--native-candidate", type=Path)
    parser.add_argument("--native-receipt", type=Path)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--profile", action="store_true", help="Measure complete headless and, when requested, rendered M2 workload matrices")
    arguments = parser.parse_args()
    result = qualify(arguments)
    print(json.dumps({"status": result["status"], "source": result["source_commit"], "failures": result["failures"]}))
    raise SystemExit(0 if result["status"] == "passed" else 1)
