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


def compare_worker_profiles(control: dict, candidate: dict, source_commit: str) -> dict:
    """Qualify an identical live workload; timing is evidence, not a new budget."""
    schema = "objectshard-worker-scheduling-profile-v1"
    for label, value, pump in (("control", control, 0), ("candidate", candidate, 4000)):
        if value.get("schema") != schema or type(value.get("failures")) is not int or value["failures"] != 0:
            raise ValueError("Unsuccessful worker scheduling profile: " + label)
        if value.get("notifications") is not False or value.get("pump_budget_usec") != pump:
            raise ValueError("Wrong worker scheduling profile mode: " + label)
        required = {"completed_intervals": 240, "actual_live_inputs": 60, "actual_physics_steps": 954}
        if any(type(value.get(key)) is not int or value[key] != expected for key, expected in required.items()):
            raise ValueError("Incomplete actual worker scheduling workload: " + label)
        identity = value.get("identity", {})
        if identity.get("revision") != source_commit or not identity.get("files") or not identity.get("engine_sha256"):
            raise ValueError("Unbound worker scheduling source: " + label)
        digests = value.get("publication_digests")
        if not isinstance(digests, list) or len(digests) != 240 or any(
                not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest) for digest in digests):
            raise ValueError("Incomplete worker publication comparison: " + label)
        if not isinstance(value.get("native_accounting"), dict) or not value["native_accounting"]:
            raise ValueError("Missing actual worker quantity ledger: " + label)
        if type(value.get("play_elapsed_usec")) is not int or value["play_elapsed_usec"] <= 0:
            raise ValueError("Missing actual worker wall interval: " + label)
    matched = ["identity", "engine", "platform", "publication_digests", "native_accounting",
               "completed_intervals", "actual_live_inputs", "actual_physics_steps"]
    if any(control.get(key) != candidate.get(key) for key in matched):
        raise ValueError("Worker scheduling modes changed source, publication or quantity accounting")
    control_rate = 240_000_000.0 / control["play_elapsed_usec"]
    candidate_rate = 240_000_000.0 / candidate["play_elapsed_usec"]
    return {"status": "passed", "matched_fields": matched, "publication_count": 240,
            "control_semantic_ticks_per_wall_second": control_rate,
            "candidate_semantic_ticks_per_wall_second": candidate_rate,
            "wall_progression_ratio": candidate_rate / control_rate,
            "scope": "Same source/runtime and 240 per-interval material/pose publication digests. Timing is a paired hosted observation, not a new pass threshold or target GPU frame-rate claim."}


def validate_navigation_receipt(receipt: dict, source_commit: str) -> dict:
    expected_cases = ["active_pending_repeated", "naturally_sleeping", "opening", "reset_superseded",
                      "held_interval", "stop_delivery_faults", "already_closed_prior_policy", "window_close_upgrade"]
    if (receipt.get("schema") != "objectshard-worker-navigation-test-v1"
            or receipt.get("source_revision") != source_commit
            or type(receipt.get("checks")) is not int or receipt["checks"] < 100
            or type(receipt.get("failures")) is not int or receipt["failures"] != 0
            or receipt.get("cases") != expected_cases):
        raise ValueError("Incomplete or unbound actual navigation lifecycle qualification")
    children = [row for row in receipt.get("observations", []) if isinstance(row, dict)
                and row.get("case") == "window_close_upgrade"]
    if len(children) != 1:
        raise ValueError("Missing or duplicate actual window-close child receipt")
    row = children[0]
    child = row.get("child_report", {})
    if (type(row.get("child_exit_code")) is not int or row["child_exit_code"] != 0
            or not isinstance(child, dict) or child.get("schema") != "objectshard-worker-navigation-quit-child-v1"
            or child.get("source_revision") != source_commit
            or type(child.get("checks")) is not int or child["checks"] < 18
            or type(child.get("failures")) is not int or child["failures"] != 0):
        raise ValueError("Unsuccessful or incomplete actual window-close child")
    return {"status": "passed", "cases": expected_cases, "checks": receipt["checks"],
            "child_checks": child["checks"], "child_exit_code": row["child_exit_code"],
            "scope": "Actual F2/autoload navigation and real owner disposal; window-close process exit executes in a separate source-matched child. Stop-delivery fault injection is explicitly labelled."}


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
        lab_sources = ["godot/project.godot", "godot/scripts/feature_launcher.gd", "godot/scripts/feature_navigation.gd"]
        lab_sources += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / "godot").glob("object_shard_*.tscn"))]
        preflight = (ROOT / "godot/object_shard_worker_rehearsal.tscn").is_file()
        report["m3_preflight"] = preflight
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
        environment.pop("CYBERSAND_PACKAGE_MANIFEST", None)
        if args.package:
            environment["CYBERSAND_PACKAGE_MANIFEST"] = str((args.package / "objectshard-lab-manifest.json").resolve())
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
        if preflight:
            if args.stage != "m2":
                raise ValueError("M3 preflight requires the complete retained M2 suite")
            for name, schema in (
                    ("incremental_motion", "objectshard-incremental-motion-test-v1"),
                    ("native_worker", "objectshard-native-worker-test-v1"),
                    ("workbench_contract", "objectshard-workbench-boundary-test-v1"),
                    ("worker_rehearsal", "objectshard-worker-rehearsal-test-v1"),
                    ("worker_adverse", "objectshard-worker-adverse-test-v1"),
                    ("worker_recovery", "objectshard-worker-recovery-test-v1"),
                    ("worker_navigation", "objectshard-worker-navigation-test-v1"),
                    ("worker_replay_admission", "objectshard-worker-replay-admission-test-v1"),
                    ("worker_resources", "objectshard-worker-resource-test-v1"),
                    ("worker_commands", "objectshard-worker-command-test-v1"),
                    ("physics_identity", "objectshard-physics-identity-test-v1"),
                    ("worker_input_fences", "objectshard-worker-input-fences-v1"),
                    ("continuous_play", "objectshard-continuous-play-test-v1")):
                command = ("--script", "res://tests/test_object_shard_" + name + ".gd")
                if name == "continuous_play":
                    command += ("--", "--report-copy=" + str(output / "continuous-play.json"))
                elif name == "worker_replay_admission":
                    command += ("--", "--output-dir=" + str(output / "worker-replay-admission"))
                elif name == "worker_navigation":
                    command += ("--", "--output=" + str(output / "worker-navigation.json"))
                cases.append((runner.Case("objectshard_" + name, command,
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), schema))
            cases.append((runner.Case("objectshard_continuous_replay",
                ("--script", "res://tests/replay_object_shard_worker_trace.gd", "--",
                 "--objectshard-replay=" + str(output / "continuous-play.json.jsonl"),
                 "--objectshard-replay-report=" + str(output / "continuous-replay.json")),
                int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-worker-action-replay-v1"))
            cases.append((runner.Case("objectshard_continuous_physics",
                ("--script", "res://tests/test_object_shard_continuous_physics.gd", "--",
                 "--output=" + str(output / "continuous-physics.json"), "--trace=" + str(output / "continuous-physics.jsonl")),
                int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-continuous-physics-test-v1"))
            cases.append((runner.Case("objectshard_worker_scene",
                ("--script", "res://tests/test_object_shard_worker_scene.gd", "--",
                 "--report-copy=" + str(output / "worker-scene.json")),
                int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-worker-scene-test-v1"))
            cases.append((runner.Case("objectshard_worker_replay",
                ("--script", "res://tests/replay_object_shard_worker_trace.gd", "--",
                 "--objectshard-replay=" + str(output / "worker-scene.json.jsonl"),
                 "--objectshard-replay-report=" + str(output / "worker-replay.json")),
                int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-worker-action-replay-v1"))
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
            if preflight:
                cases.append((runner.Case("objectshard_continuous_play_rendered", ("--rendering-driver", driver, "--script",
                    "res://tests/test_object_shard_continuous_play.gd", "--",
                    "--report-copy=" + str(output / "continuous-play-rendered.json")),
                    int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True), "objectshard-continuous-play-test-v1"))
                cases.append((runner.Case("objectshard_continuous_rendered_replay",
                    ("--script", "res://tests/replay_object_shard_worker_trace.gd", "--",
                     "--objectshard-replay=" + str(output / "continuous-play-rendered.json.jsonl"),
                     "--objectshard-replay-report=" + str(output / "continuous-rendered-replay.json")),
                    int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-worker-action-replay-v1"))
                cases.append((runner.Case("objectshard_worker_render", ("--rendering-driver", driver, "--script",
                    "res://tests/capture_object_shard_worker.gd", "--", "--objectshard-capture=" + str(output / "frames-worker")),
                    int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True), "objectshard-worker-render-campaign-v1"))
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
            if preflight:
                for pump in (0, 4000):
                    name = "objectshard_worker_profile_" + str(pump)
                    cases.append((runner.Case(name,
                        ("--script", "res://tests/profile_object_shard_worker.gd", "--", "--notifications=off",
                         "--pump-usec=" + str(pump), "--output=" + str(output / (name + ".json"))),
                        int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-worker-scheduling-profile-v1"))
        for case, schema in cases:
            record, failed = runner.run_case(str(engine), case, output, "ObjectShard scoped qualification", env=environment)
            report["cases"].append(record)
            if failed:
                raise ValueError("Actual Godot process failed: " + case.name)
            if schema:
                receipt = footer(output / record["log"], schema)
                minimum_checks = {"objectshard-worker-adverse-test-v1": 23,
                                  "objectshard-worker-recovery-test-v1": 63,
                                  "objectshard-worker-navigation-test-v1": 100,
                                  "objectshard-worker-replay-admission-test-v1": 57,
                                  "objectshard-worker-input-fences-v1": 34,
                                  "objectshard-worker-resource-test-v1": 19,
                                  "objectshard-worker-scene-test-v1": 13,
                                  "objectshard-continuous-play-test-v1": 75,
                                  "objectshard-worker-command-test-v1": 29,
                                  "objectshard-physics-identity-test-v1": 70}.get(schema, 20)
                if (schema.endswith("test-v1") or schema == "objectshard-worker-input-fences-v1") and (type(receipt.get("checks")) is not int or receipt["checks"] < minimum_checks):
                    raise ValueError("Incomplete assertion inventory: " + case.name)
                record["completion_receipt"] = receipt
                if schema == "objectshard-worker-navigation-test-v1":
                    record["navigation_lifecycle"] = validate_navigation_receipt(receipt, args.expected_source_sha)
                if case.name == "objectshard_continuous_play_rendered":
                    live = json.loads((output / "continuous-play-rendered.json").read_text(encoding="utf-8"))
                    stages = live.get("timings_usec", {})
                    ui_stages = live.get("presentation_timing", {}).get("stages", {})
                    if stages.get("input_to_presented_usec", {}).get("count", 0) <= 0 or ui_stages.get("input_to_host_usec", {}).get("count", 0) <= 0:
                        raise ValueError("Rendered live input lacks actual scene-queue and presentation observations")
                    record["rendered_ui_timing"] = {"input_to_presented_usec": stages["input_to_presented_usec"],
                        "host_admission_to_presented_usec": stages.get("host_admission_to_presented_usec", {}),
                        "scene_input_to_host_usec": {key: value for key, value in ui_stages["input_to_host_usec"].items() if key != "retained_values_usec"},
                        "scope": "Actual source-matched rendered scene observations, including the original scene-intent queue timestamp; not monitor scanout or target GPU performance"}
                if schema == "objectshard-action-replay-v1" and (receipt.get("actions", 0) < 1 or receipt.get("steps", 0) < 1):
                    raise ValueError("Replay did not execute actual inputs and native steps")
                if schema == "objectshard-worker-action-replay-v1" and (receipt.get("actions", 0) < 1 or receipt.get("semantic_steps", 0) < 1):
                    raise ValueError("Worker replay did not execute actual inputs and completed semantic ticks")
                if schema in ("objectshard-rest-stability-probe-v1", "objectshard-retained-action-probe-v1"):
                    minimum = 20 if schema == "objectshard-rest-stability-probe-v1" else 17
                    if type(receipt.get("checks")) is not int or receipt["checks"] < minimum:
                        raise ValueError("Incomplete physical-probe assertion inventory: " + case.name)
                if schema in ("objectshard-render-campaign-v1", "objectshard-finisher-render-campaign-v1", "objectshard-worker-render-campaign-v1"):
                    expected_captures = {"m0": 4, "m1": 6, "m2": 10}[args.stage] if schema == "objectshard-render-campaign-v1" else (7 if schema == "objectshard-worker-render-campaign-v1" else 5)
                    images_directory = output / ({"objectshard-render-campaign-v1": "frames",
                                                  "objectshard-finisher-render-campaign-v1": "frames-finisher",
                                                  "objectshard-worker-render-campaign-v1": "frames-worker"}[schema])
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
        if args.profile and preflight:
            control = json.loads((output / "objectshard_worker_profile_0.json").read_text(encoding="utf-8"))
            candidate_profile = json.loads((output / "objectshard_worker_profile_4000.json").read_text(encoding="utf-8"))
            report["worker_scheduling_comparison"] = compare_worker_profiles(control, candidate_profile, commit)
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
