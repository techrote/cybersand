#!/usr/bin/env python3
"""Recovery correctness with unchanged frozen cases plus actual graphical gates.

Original source remains intact. The only native admission addition is explicit
byte-identical build-input reuse. Focused runs never grant full qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "tools/pubpres_final"), str(ROOT / "tools/pubpres003"), str(ROOT / "tools/pubpres_playability_build"),
               str(ROOT / "tools/pubpres_playability")]
from run_focus import ENGINE_SHA256
from retained_runtime import validate_runtime
from run_campaign import source_identity
from run_regressions import stage_source, run, validate_completion, terminal_json
from identity import driver_identity
from qualification_oracles import ring_result, transition_result, main_recovery_result
from material_deadline_oracle import main_history_result as deadline_history_result, headless_result as deadline_headless_result
from material_steps_oracle import main_history_result as steps_history_result, headless_result as steps_headless_result
import engine_admission


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def need(value, message):
    if not value:
        raise ValueError(message)


SUPPLEMENTAL = {
    "test_workbench_presentation_submission": {
        "prefix": "ACTUAL_SUBMISSION_RESULT ", "minimum_checks": 40,
        "environment": {"CYBERSAND_DIAG_ACTUAL_SUBMISSION": "1", "CYBERSAND_DIAG_WATER_COMPOSITION": "0"},
        "output_argument": "--submission-evidence=",
        "schema": "workbench-actual-submission-graphical-v1"},
    "test_workbench_water_composition": {
        "prefix": "PUBPRES_WATER_COMPOSITION_RESULT ", "minimum_checks": 48,
        "environment": {"CYBERSAND_DIAG_WATER_COMPOSITION": "1"}},
    "test_workbench_water_composition_native": {
        "prefix": "PUBPRES_WATER_COMPOSITION_NATIVE_RESULT ", "minimum_checks": 1,
        "environment": {"CYBERSAND_DIAG_ACTUAL_SUBMISSION": "1", "CYBERSAND_DIAG_WATER_COMPOSITION": "1"},
        "output_environment": "CYBERSAND_WATER_COMPOSITION_OUTPUT"},
}


def supplemental_result(test, text, folder, source, project):
    expected = SUPPLEMENTAL[test]
    lines = [line.removeprefix(expected["prefix"]) for line in text.splitlines() if line.startswith(expected["prefix"])]
    need(len(lines) == 1, "Missing/duplicate exact supplemental completion: " + test)
    terminal = json.loads(lines[0])
    need(terminal.get("failures") == [] and type(terminal.get("checks")) is int
         and terminal["checks"] >= expected["minimum_checks"], "Incomplete supplemental assertions: " + test)
    result = {"terminal": terminal, "test_sha256": digest(project / "tests" / (test + ".gd"))}
    if expected.get("output_environment") or expected.get("output_argument"):
        path = folder / "receipt.json"
        need(path.is_file(), "Supplemental graphical receipt was not retained: " + test)
        data = json.loads(path.read_bytes())
        need(data.get("failures") == [] and data.get("source_revision") == source["source_commit"],
             "Supplemental source/failure evidence differs: " + test)
        if "schema" in expected:
            need(data.get("schema") == expected["schema"], "Unknown supplemental receipt schema")
        if test == "test_workbench_presentation_submission":
            need(data.get("engine_atomic_admission") is True,
                 "Journal-only pre-draw refusal cannot reject already-flushed candidate pixels")
            refusals = data.get("refusal_framebuffers", [])
            need(isinstance(refusals, list) and refusals
                 and all(row.get("before_sha256") == row.get("after_sha256")
                         and isinstance(row.get("before_sha256"), str) and len(row["before_sha256"]) == 64
                         for row in refusals), "Stale candidate refusal lacks actual unchanged framebuffer evidence")
        need(data.get("display") not in (None, "", "headless"), "Supplemental graphical gate did not execute graphically")
        for name, sha in data.get("input_hashes", {}).items():
            need(name.startswith("res://") and digest(project / name.removeprefix("res://")) == sha,
                 "Supplemental input identity differs: " + name)
        need(data.get("input_hashes", {}).get("res://tests/" + test + ".gd") == result["test_sha256"],
             "Supplemental actual test bytes are missing from receipt")
        result.update(receipt_sha256=digest(path), receipt=data)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("runtime", "engine", "output"):
        parser.add_argument("--" + key, type=Path, required=True)
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--allow-development-toolchain-drift", action="store_true")
    parser.add_argument("--headless-only", action="store_true")
    parser.add_argument("--focus", choices=("all", "submission", "water", "frozen"), default="all")
    parser.add_argument("--render-thread", choices=("safe", "separate"), default="safe")
    parser.add_argument("--lookahead", type=int, choices=(0, 4), default=0)
    engine_admission.add_arguments(parser)
    args = parser.parse_args()
    source_root, engine, output = args.source.resolve(), args.engine.resolve(), args.output.resolve()
    need(not output.exists(), "Preserve original qualification evidence; output must be new")
    source = source_identity(source_root)
    native = validate_runtime(source_root, source, args.runtime.resolve(), args.allow_development_toolchain_drift)
    platform = "windows" if os.name == "nt" else "linux"
    engine_proof = None
    if args.engine_payload:
        actual, engine_proof = engine_admission.admit(args)
        need(actual == engine, "Actual correctness executable differs from admitted engine payload")
    else:
        need(digest(engine) == ENGINE_SHA256[platform], "Stock control requires the exact official Godot 4.7 executable")
        need(args.render_thread == "safe", "Unregistered stock Separate control")
        need(args.lookahead == 0, "Stock reference has no bounded engine treatment")
    need(args.render_thread == "safe" or args.focus in ("submission", "water"),
         "Frozen correctness inventory retains its original Safe owner; new Separate gates run separately")
    rapier = json.loads((source_root / f"godot/addons/godot-rapier2d/runtime-provenance.{platform}.json").read_text())
    need(digest(source_root / rapier["artifact"]) == rapier["sha256"], "Rapier runtime differs")
    for name, expected in rapier["source_inputs"].items():
        committed = subprocess.check_output(["git", "show", source["source_commit"] + ":" + name], cwd=source_root)
        need(hashlib.sha256(committed).hexdigest() == expected, "Rapier source differs: " + name)
    output.mkdir(parents=True)
    project = stage_source(source_root, source["source_commit"], output)
    shutil.copyfile(native["binary_path"], project / native["staged_relative_path"])
    shutil.copyfile(source_root / rapier["artifact"], project / Path(rapier["artifact"]).relative_to("godot"))
    authored = {path.relative_to(project).as_posix(): digest(path)
                for path in project.rglob("*") if path.is_file()}
    report = {"schema": "pubpres-recovery-correctness-v1", "source": source, "native": native,
              "engine_sha256": digest(engine), "rapier_sha256": rapier["sha256"], "outcomes": [],
              "driver": driver_identity(), "staged_input_files_sha256": authored,
              "complete": False, "physical_acceptance": "HOLD", "headless_only": args.headless_only,
              "focus": args.focus, "full_qualification": False,
              "engine_admission": engine_proof, "render_thread": args.render_thread,
              "lookahead": args.lookahead,
              "frozen_inventory_reader_sha256": digest(ROOT / "tools/pubpres_final/run_qualification.py")}
    def save():
        (output / "SUMMARY.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    save()
    clean = {key: value for key, value in os.environ.items() if not key.startswith(("CYBERSAND_", "WB_COMBINED_"))}
    driver = "opengl3_angle" if os.name == "nt" else "opengl3"
    def invoke(test, slots=2, graphical=False, extra=None):
        label = test + "-slots" + str(slots)
        folder = output / label
        profile = output / (label + "-profile")
        profile.mkdir()
        environment = dict(clean, APPDATA=str(profile), LOCALAPPDATA=str(profile), XDG_DATA_HOME=str(profile),
                           XDG_CONFIG_HOME=str(profile), XDG_CACHE_HOME=str(profile), CYBERSAND_SOURCE_REVISION=source["source_commit"],
                           CYBERSAND_MATERIAL_PUBLICATION="full", CYBERSAND_DIAG_FULL_IMAGE_SLOTS=str(slots),
                           CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="0",
                           CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL="0",
                           CYBERSAND_DIAG_PHYSICS_PUBLICATION="early", CYBERSAND_DIAG_PRESENTATION="coherent",
                           CYBERSAND_DIAG_SAME_FRAME_CONTINUATION="0", CYBERSAND_MATERIAL_QUEUE_THREAD="safe")
        if test in SUPPLEMENTAL:
            environment["CYBERSAND_MATERIAL_QUEUE_THREAD"] = args.render_thread
            environment["CYBERSAND_PLAYABILITY_RENDER_THREAD"] = args.render_thread
            if engine_proof:
                environment["CYBERSAND_ENGINE_RENDER_LOOKAHEAD"] = str(args.lookahead)
                environment["CYBERSAND_ENGINE_RENDER_LOOKAHEAD_TRACE"] = str(folder / "engine-draws.json")
        if test in SUPPLEMENTAL:
            environment.update(SUPPLEMENTAL[test]["environment"])
            if SUPPLEMENTAL[test].get("output_environment"):
                environment[SUPPLEMENTAL[test]["output_environment"]] = str(folder / "receipt.json")
        if test == "test_workbench_physics_causal_trace":
            environment["CYBERSAND_DIAG_PHYSICS_CAUSAL_TRACE"] = "1"
        command = [str(engine), "--path", str(project), "--audio-driver", "Dummy"]
        if graphical:
            command += ["--rendering-method", "gl_compatibility", "--rendering-driver", driver, "--render-thread", args.render_thread]
        else:
            command += ["--headless"]
        command += ["--editor", "--import"] if test == "import" else ["--script", "res://tests/" + test + ".gd"]
        if test in SUPPLEMENTAL and SUPPLEMENTAL[test].get("output_argument"):
            extra = list(extra or []) + [SUPPLEMENTAL[test]["output_argument"] + str(folder / "receipt.json")]
        if extra:
            command += ["--", *extra]
        if graphical and args.display_wrapper:
            command = [sys.executable, str(args.display_wrapper.resolve()), *command]
            environment["PUBPRES_DISPLAY_RECEIPT"] = str(folder / "display-owner.json")
        if test == "import":
            command += ["--quit"]
        item = run(command, environment, folder, 1200 if test == "import" else 600)
        item.update(test=test, slots=slots, graphical=graphical)
        text = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
        try:
            need(item["returncode"] == 0 and not item.get("timed_out", False), "Godot process failed or timed out")
            need("SCRIPT ERROR:" not in text and "ERROR:" not in text, "Strict Godot diagnostic failure")
            if test in SUPPLEMENTAL:
                item["evidence"] = supplemental_result(test, text, folder, source, project)
            elif test == "test_full_image_ring_publication":
                item["evidence"] = ring_result(text, source["source_commit"], project, driver, engine_sha256=report["engine_sha256"])
            elif test == "pubpres_full_image_ring_oracle":
                item["evidence"] = transition_result(output / "ring-transition.json", project, source=source["source_commit"], driver=driver, engine_sha256=report["engine_sha256"])
            elif test == "test_full_image_ring_main_recovery":
                item["evidence"] = main_recovery_result(text, source["source_commit"], project, driver, engine_sha256=report["engine_sha256"])
            elif test == "test_material_deadline_main_history":
                item["evidence"] = deadline_history_result(text, source["source_commit"], project, driver,
                                                            engine_sha256=report["engine_sha256"], slots=slots)
            elif test in ("test_material_publication_deadline", "test_material_deadline_main_identity"):
                item["evidence"] = deadline_headless_result(test, text, project)
            elif test == "test_material_steps_main_history":
                item["evidence"] = steps_history_result(text, source["source_commit"], project, driver,
                                                       engine_sha256=report["engine_sha256"])
            elif test in ("test_material_publication_steps", "test_material_steps_main_identity"):
                item["evidence"] = steps_headless_result(test, text, project)
            else:
                errors = validate_completion(test, text, item["returncode"], completion=True)
                need(not errors, "; ".join(errors))
            item["valid"] = True
        except (ValueError, KeyError, TypeError, OSError) as error:
            item.update(valid=False, failure=str(error))
        report["outcomes"].append(item)
        save()
        return item["valid"]
    imported = invoke("import")
    if imported:
        imported_files = {path.relative_to(project).as_posix(): digest(path)
                          for path in project.rglob("*") if path.is_file()}
        report["imported_files_sha256"] = imported_files
        bootstrap = {".godot/global_script_class_cache.cfg", ".godot/extension_list.cfg"}
        report["import_source_mutations"] = [name for name, expected in authored.items()
                                             if name not in bootstrap and imported_files.get(name) != expected]
        if report["import_source_mutations"]:
            imported = False
            report["outcomes"][-1].update(valid=False, failure="Import changed authored source")
        save()
    if imported and args.focus in ("all", "frozen"):
        for test in ("test_workbench_physics_publication", "test_workbench_physics_causal_trace",
                     "test_workbench_material_world_blend", "test_workbench_material_delivery_timing",
                     "test_physical_actor_integration", "test_render_cadence_worker",
                     "test_material_publication_deadline", "test_material_deadline_main_identity",
                     "test_material_publication_steps", "test_material_steps_main_identity"):
            invoke(test)
        if not args.headless_only:
            invoke("test_full_image_ring_publication", 3, True)
            invoke("test_full_image_ring_main_recovery", 3, True)
            invoke("pubpres_full_image_ring_oracle", 3, True,
                   ["--material=full", "--receipt=" + str(output / "ring-transition.json")])
            invoke("test_workbench_material_world_blend", 3, True)
            invoke("test_workbench_material_delivery_timing", 3, True)
            invoke("test_material_deadline_main_history", 2, True)
            invoke("test_material_deadline_main_history", 3, True)
            invoke("test_material_steps_main_history", 2, True)
    if imported and args.focus in ("all", "submission") and not args.headless_only:
        invoke("test_workbench_presentation_submission", 2, True)
    if imported and args.focus in ("all", "water"):
        invoke("test_workbench_water_composition")
        if not args.headless_only:
            invoke("test_workbench_water_composition", 3, True)
            invoke("test_workbench_water_composition_native", 2, True)
    report["final_source_mutations"] = [name for name, expected in authored.items()
                                        if name not in {".godot/global_script_class_cache.cfg", ".godot/extension_list.cfg"}
                                        and (not (project / name).is_file() or digest(project / name) != expected)]
    report["complete"] = imported and not report["final_source_mutations"] and all(row["valid"] for row in report["outcomes"])
    report["full_qualification"] = report["complete"] and args.focus == "all" and not args.headless_only
    save()
    print(json.dumps({"complete": report["complete"], "full_qualification": report["full_qualification"], "outcomes": len(report["outcomes"]), "output": str(output)}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
