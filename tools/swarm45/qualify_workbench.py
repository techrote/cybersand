#!/usr/bin/env python3
"""Source-bound Linux/Windows graphical gates and the real extracted evaluator.

Both SWARM004 recipes, V3 Irregular and blocked Viaduct, all five V4 recovery
examples, actual input gestures and child lifecycle remain required per layout.
Automated results never claim physical owner or research-programme acceptance.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys

import runtime_custody as custody
from shared import (HEADLESS_CASES, graphical_processes, historical_refresh_errors, input_report_errors, layout_identity,
                    legacy, package_identity, qualification_engine, ui_report_errors, verify_engine, verify_project)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--package-zip", type=Path)
    args = parser.parse_args()
    platform = "windows" if os.name == "nt" else "linux"
    runtime, project, output = (p.resolve() for p in (args.runtime, args.project, args.output))
    engine = qualification_engine(args.godot, platform)
    custody.require(sys.platform in ("linux", "win32"), "Unsupported execution OS")
    custody.require(not output.exists() or not any(output.iterdir()), "Graphical evidence must be new")
    receipt = custody.verify(runtime)
    custody.require(receipt["platform"] == platform, "Graphical target OS differs from built runtime")
    verify_project(project, receipt)
    version = verify_engine(engine)
    binding_path = project / "tools" / ("swarm004-runtime." + platform + ".json")
    custody.require(legacy.read_report(binding_path) == custody.cli_binding(receipt)
                    and custody.sha(project / "tools" / receipt["cli"]) == receipt["files"][receipt["cli"]]["sha256"],
                    "Ordinary runtime lookup must use this run's exact CLI and OS-specific source binding")
    package = None
    if args.package:
        package = package_identity(args.package.resolve(), receipt)
        custody.require(platform == "windows" and args.package_zip is not None,
                        "The evaluator gate requires a real Windows ZIP extraction")
        custody.require(project == args.package.resolve() / "godot" and engine.parent == args.package.resolve(),
                        "Evaluator must run its own extracted project and engine")
        custody.require(custody.sha(project / "tools" / receipt["cli"]) == receipt["files"][receipt["cli"]]["sha256"],
                        "Evaluator CLI differs from built bytes")
        from package_owner import verify_extracted_zip
        verify_extracted_zip(args.package_zip.resolve(), args.package.resolve(), package)
    else:
        custody.require(args.package_zip is None, "ZIP custody requires the extracted package")
    layout = layout_identity(project)
    output.mkdir(parents=True, exist_ok=True)
    identity = {"schema": 1, "programme": custody.PROGRAMME, "qualification_programme": custody.QUALIFICATION_PROGRAMME,
                "source_commit": receipt["source_commit"],
                "source_tree": receipt["source_tree"], "platform": platform, "godot_version": version,
                "godot_sha256": custody.sha(engine), "native_adapter_sha256": receipt["files"][receipt["extension"]]["sha256"],
                "runtime_manifest_sha256": custody.sha(runtime / custody.NAME), "build_context": receipt["build_context"],
                "graphical_required": True, "package": bool(package),
                "package_zip_sha256": custody.sha(args.package_zip) if args.package_zip else None,
                "execution_layout": layout,
                "fixed_examples": {name: legacy.expected_recipe(name) for name in legacy.EXAMPLES}}
    custody.write_json(output / "source-runtime-identity.json", identity)
    env = dict(os.environ, CYBERSAND_SOURCE_REVISION=receipt["source_commit"])
    for key in ("CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"):
        env.pop(key, None)
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    display = ["--rendering-method", "gl_compatibility", "--max-fps", "60"]
    display += ["--rendering-driver", "opengl3_angle"] if platform == "windows" else ["--display-driver", "x11"]
    headless = output / "headless"
    headless_env = legacy.isolated_environment(env, headless, "transaction")
    results = [legacy.execute("import", [*base, "--headless", "--editor", "--quit"], headless_env, headless, 180)]
    if results[-1]["passed"]:
        adapter_env = dict(headless_env, WB_AUTHORING_PATCH_REPORT=str(headless / "native-adapter.json"))
        result = legacy.execute("native-adapter", [*base, "--headless", "--script", "res://tests/test_workbench_authoring_patch.gd"],
                                adapter_env, headless, 180)
        report = legacy.read_report(headless / "native-adapter.json")
        errors = legacy.assertion_errors(report)
        if report.get("passed") is not True:
            errors.append("native adapter assertions did not pass")
        results.append(legacy.validate_result(result, errors, headless))
    for name, script, marker, timeout in HEADLESS_CASES:
        if not results[-1]["passed"]:
            break
        result = legacy.execute(name, [*base, "--headless", "--script", "res://tests/" + script], headless_env, headless, timeout)
        results.append(legacy.validate_result(result, legacy.marker_errors(headless / (name + ".log"), marker,
                                                                           name == "controller-mechanical"), headless))
    input_integrity_passed = False
    if len(results) == 2 + len(HEADLESS_CASES) and all(result["passed"] for result in results):
        directory = output / "input-integrity"
        input_env = legacy.isolated_environment(env, directory, "transaction")
        result = legacy.execute("input-integrity", [*base, *display, "--script", "res://" + legacy.INPUT_SCRIPT], input_env, directory, 180)
        report = legacy.read_report(directory / "input-integrity.json")
        errors = legacy.marker_errors(directory / "input-integrity.log", "SWARM006_INPUT_INTEGRITY ")
        errors.extend(input_report_errors(directory, report, receipt["source_commit"], receipt["files"][receipt["cli"]]["sha256"],
                                          custody.sha(project / legacy.INPUT_SCRIPT), platform))
        result = legacy.validate_result(result, errors, directory)
        results.append(result)
        input_integrity_passed = result["passed"]
    examples, lifecycle_passed = {}, False
    if input_integrity_passed and all(result["passed"] for result in results):
        test_sha, cli_sha = custody.sha(project / legacy.UI_SCRIPT), receipt["files"][receipt["cli"]]["sha256"]
        for example, definition in legacy.EXAMPLES.items():
            directory = output / example
            example_env = legacy.isolated_environment(env, directory, example)
            reports, example_results = {}, []
            modes = ["blocked"] if definition.get("negative") else (["evaluate"] if definition.get("evaluate") else ["create", "reopen"])
            for mode in modes:
                result = legacy.execute(mode, [*base, *display, "--script", "res://" + legacy.UI_SCRIPT],
                                        dict(example_env, SWARM004_UI_MODE=mode), directory, 420)
                report = legacy.read_report(directory / (mode + ".json"))
                errors = ui_report_errors(report, mode, example, receipt["source_commit"], cli_sha, test_sha, platform)
                if example == "transaction" and mode == "reopen":
                    errors.extend(historical_refresh_errors(directory, report, receipt))
                result.update(example=example, report_sha256=custody.sha(directory / (mode + ".json")) if report else None)
                results.append(legacy.validate_result(result, errors, directory))
                example_results.append(result)
                reports[mode] = report
                if not result["passed"]:
                    break
                if mode == "evaluate" and report.get("native_can_apply") is True:
                    modes.append("reopen")
            negative = definition.get("negative") or (definition.get("evaluate") and reports.get("evaluate", {}).get("native_can_apply") is False)
            record = (legacy.blocked_evidence(directory, reports.get("blocked", reports.get("evaluate", {}))) if negative
                      else legacy.example_evidence(directory, reports))
            examples[example] = {"scope": definition["scope"], **record,
                                 "passed": bool(record["passed"] and len(reports) == len(modes)
                                                and all(result["passed"] for result in example_results))}
            primary = reports.get("create", reports.get("evaluate", reports.get("blocked", {})))
            examples[example]["native_outcome"] = {key: primary.get(key) for key in (
                "native_status", "native_reason", "native_stop_reason", "native_can_apply", "material_count",
                "joint_count", "obligation_count", "reciprocal_witness", "native_work", "native_evidence_sha256")}
            examples[example]["native_outcome"].update(legacy.closure_outcome(primary.get("native_status"), primary.get("native_work")))
        directory = output / "lifecycle"
        lifecycle_env = legacy.isolated_environment(env, directory, "transaction")
        lifecycle_env.update(SWARM004_UI_MODE="lifecycle", CYBERSAND_SWARM004_CLI=str(runtime / receipt["fixture"]),
                             CYBERSAND_SWARM004_SOURCE="lifecycle-fixture-no-assembly",
                             CYBERSAND_SWARM004_SHA256=receipt["files"][receipt["fixture"]]["sha256"])
        result = legacy.execute("lifecycle", [*base, *display, "--script", "res://" + legacy.UI_SCRIPT], lifecycle_env, directory, 300)
        result["fixture_sha256"] = receipt["files"][receipt["fixture"]]["sha256"]
        report = legacy.read_report(directory / "lifecycle.json")
        result = legacy.validate_result(result, ui_report_errors(report, "lifecycle", "transaction", receipt["source_commit"],
                                                                 cli_sha, test_sha, platform), directory)
        lifecycle_passed = result["passed"]
        results.append(result)
    complete = (input_integrity_passed and set(examples) == set(legacy.EXAMPLES) and all(record["passed"] for record in examples.values())
                and lifecycle_passed and all(result["passed"] for result in results))
    expected_processes = graphical_processes(examples) if complete else []
    complete = complete and [(row.get("case"), row.get("example")) for row in results] == expected_processes
    # Verify immutable source/runtime bytes again after all child processes.
    custody.require(custody.verify(runtime) == receipt, "Runtime custody changed during graphical qualification")
    verify_project(project, receipt)
    custody.require(layout_identity(project) == layout, "Raw execution source/package bytes changed during graphics")
    summary = {**identity, "passed": bool(complete), "owner_visual_acceptance": "pending",
               "reciprocal_programme_acceptance": False, "examples": examples,
               "lifecycle_passed": lifecycle_passed, "input_integrity_passed": input_integrity_passed,
               "expected_processes": expected_processes, "terminal_identity_revalidated": True, "results": results,
               "files_sha256": custody.inventory(output)}
    custody.write_json(output / "qualification.json", summary)
    print({key: summary[key] for key in ("source_commit", "platform", "package", "passed", "owner_visual_acceptance")})
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
