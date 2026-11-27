#!/usr/bin/env python3
"""Recovery correctness with unchanged frozen cases plus actual graphical gates.

Original source remains intact. The only native admission addition is explicit
byte-identical build-input reuse. Focused runs never grant full qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
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
from results import check_framebuffer
from material_deadline_oracle import main_history_result as deadline_history_result, headless_result as deadline_headless_result
from material_steps_oracle import main_history_result as steps_history_result, headless_result as steps_headless_result
import engine_admission


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def need(value, message):
    if not value:
        raise ValueError(message)


def water_framebuffers(data, folder):
    labels = ["initial_authoring_framebuffer", "submerged_framebuffer", "water_refill_framebuffer",
              "restored_authoring_framebuffer", "multipart_limb_framebuffer"]
    rows = data["framebuffer"]
    need([row["label"] for row in rows] == labels and rows[-1]["slot"] == 4,
         "Native Water framebuffer phase or articulated foot inventory differs")
    motion = [row for row in data["lifecycle"] if row.get("stage") == "multipart_motion"]
    need(len(motion) == 1 and set(motion[0]["steps"]) == set(motion[0]["origins"]) == set(map(str, range(6)))
         and motion[0]["steps"]["4"] >= 8, "Moving six-member Water submission is missing")
    hashes = {}
    for row in rows:
        label = row["label"]
        width, height = row["size"]
        identity = row["shown_identity"]
        need(identity and identity == row["hidden_identity"] == row["restored_identity"]
             and row["policy_order"] == ["1", "0", "1"], label + " control identity differs")
        x, y = row["pixel_point"]
        pixels = row["pixels"]
        points = [[px, py] for py in range(max(0, y-2), min(height, y+3))
                  for px in range(max(0, x-2), min(width, x+3))]
        need(points and [p["pixel"] for p in pixels] == points, label + " sample locations differ")
        differences = {}
        for treatment in ("hidden", "restored"):
            need(all(len(p["shown"]) == len(p[treatment]) == 3 and
                     all(math.isfinite(v) for v in p["shown"] + p[treatment]) for p in pixels),
                 label + " RGB control is incomplete")
            differences[treatment] = max(abs(a-b) for p in pixels for a, b in zip(p["shown"], p[treatment]))
        need(differences["hidden"] > 0.025 and differences["restored"] < 0.025
             and math.isclose(row["maximum_visible_difference"], differences["hidden"], abs_tol=1e-6)
             and math.isclose(row["maximum_restored_error"], differences["restored"], abs_tol=1e-6),
             label + " visible/restored pixel errors differ")
        names = [label + "-" + state + ".png" for state in ("shown", "hidden-control", "restored")]
        if label == "multipart_limb_framebuffer":
            names.append("moving-runner.png")
        for name in names:
            path = folder / name
            check_framebuffer(path, {"width": width, "height": height}, row["size"])
            hashes[name] = digest(path)
        need(hashes[names[0]] != hashes[names[1]], label + " shown and hidden PNGs are identical")
    return hashes


SUPPLEMENTAL = {
    "test_workbench_presentation_history": {
        "text_footer": r"^WORKBENCH_PRESENTATION_HISTORY 17 checks; 0 failures$",
        "exact_checks": 17, "minimum_checks": 17, "environment": {}},
    "test_workbench_presentation_member_history": {
        "prefix": "PUBPRES_MEMBER_HISTORY_RESULT ", "exact_checks": 23,
        "minimum_checks": 23, "environment": {}},
    "test_workbench_member_presentation": {
        "prefix": "PUBPRES_MEMBER_PRESENTATION_RESULT ", "minimum_checks": 574, "exact_checks": 574,
        "environment": {"CYBERSAND_DIAG_PRESENTATION": "coherent"},
        "output_environment": "CYBERSAND_MEMBER_PRESENTATION_OUTPUT",
        "schema": "pubpres-member-presentation-v1"},
    "test_workbench_presentation_submission": {
        "prefix": "ACTUAL_SUBMISSION_RESULT ", "minimum_checks": 110,
        "environment": {"CYBERSAND_DIAG_ACTUAL_SUBMISSION": "1", "CYBERSAND_DIAG_WATER_COMPOSITION": "0"},
        "output_argument": "--submission-evidence=",
        "schema": "workbench-actual-submission-graphical-v1"},
    "test_workbench_water_composition": {
        "prefix": "PUBPRES_WATER_COMPOSITION_RESULT ", "minimum_checks": 48,
        "environment": {"CYBERSAND_DIAG_WATER_COMPOSITION": "1"}},
    "test_workbench_water_composition_native": {
        "prefix": "PUBPRES_WATER_COMPOSITION_NATIVE_RESULT ", "minimum_checks": 1,
        "schema": "pubpres-water-composition-native-v1",
        "environment": {"CYBERSAND_DIAG_WATER_COMPOSITION": "1"},
        "output_environment": "CYBERSAND_WATER_COMPOSITION_OUTPUT"},
}


def held_placement(data, atomic):
    row = data["held_limb_placement"]
    start, live, preview, drag, finish, installed = (
        row[key] for key in ("accepted_contact", "live_contact_before_press", "preview_contact",
                             "dragged_contact", "release_target", "installed_contact"))
    need(all(len(v) == 2 and all(math.isfinite(n) for n in v) for v in (start, live, preview, drag, finish, installed))
         and row["part_index"] == 4 and row["local_contact"] == [1.125, 0.25]
         and math.dist(start, live) > 5 and math.dist(start, preview) < 0.001
         and math.dist(finish, [start[0]+17.25, start[1]-6.75]) < 0.001
         and math.dist(finish, drag) < 0.001 and math.dist(finish, installed) < 0.002,
         "Held multipart contact, displayed anchor, unsnapped drag or adopted foot differs")
    before, rotated, adopted = row["limb_rotations"]
    old, new = row["epochs"]
    need(all(math.isfinite(v) for v in (before, rotated, adopted))
         and abs(math.remainder(rotated-before, math.tau)) > 0.4
         and abs(math.remainder(adopted-rotated, math.tau)) < 0.001
         and type(old) is int and type(new) is int and 0 <= old < new
         and row["generation_refusal"] is True and re.fullmatch("[0-9a-f]{64}", row["unchanged_framebuffer_sha256"])
         and type(row["submitted_serial"]) is int and (row["submitted_serial"] > 0 if atomic else row["submitted_serial"] == -1),
         "Held multipart rotation, generation refusal, owner adoption or submitted frame differs")
    inputs = {"res://scripts/" + name + ".gd" for name in ("main", "shared_workbench", "physical_actor_session",
              "physical_actor_rig", "workbench_presentation_submission", "workbench_actor_interaction", "workbench_actor_manipulator")}
    need(inputs <= data["input_hashes"].keys(), "Held placement source-input inventory is incomplete")


def supplemental_result(test, text, folder, source, project, *, engine_sha=None, expected_inline=None, expected_lookahead=None, expected_atomic=False, receipt_path=None, stock_held=False):
    expected = SUPPLEMENTAL[test]
    if stock_held:
        need(test == "test_workbench_presentation_submission" and not expected_atomic, "Stock held-placement scope differs")
        expected = {**expected, "minimum_checks": 12, "schema": "workbench-stock-held-limb-placement-v1"}
    if "text_footer" in expected:
        need(len(re.findall(expected["text_footer"], text, re.M)) == 1,
             "Missing/duplicate unchanged history completion: " + test)
        terminal = {"checks": expected["exact_checks"], "failures": []}
    else:
        lines = [line.removeprefix(expected["prefix"]) for line in text.splitlines() if line.startswith(expected["prefix"])]
        need(len(lines) == 1, "Missing/duplicate exact supplemental completion: " + test)
        terminal = json.loads(lines[0])
    need(terminal.get("failures") == [] and type(terminal.get("checks")) is int
         and terminal["checks"] >= expected["minimum_checks"], "Incomplete supplemental assertions: " + test)
    if "exact_checks" in expected:
        need(terminal["checks"] == expected["exact_checks"], "Supplemental assertion inventory differs: " + test)
    result = {"terminal": terminal, "test_sha256": digest(project / "tests" / (test + ".gd"))}
    if test == "test_workbench_water_composition" and terminal.get("graphical") is True:
        need(terminal.get("separate_first_draws") == (30 if expected_inline is False else 0),
             "Isolated Water readback did not capture the requested render thread's first draws")
    if expected.get("output_environment") or expected.get("output_argument"):
        path = receipt_path or folder / "receipt.json"
        need(path.is_file(), "Supplemental graphical receipt was not retained: " + test)
        data = json.loads(path.read_bytes())
        need(data.get("failures") == [] and data.get("source_revision") == source["source_commit"],
             "Supplemental source/failure evidence differs: " + test)
        if "schema" in expected:
            need(data.get("schema") == expected["schema"], "Unknown supplemental receipt schema")
        if test == "test_workbench_water_composition_native":
            need(data["graphical"] is True and data["checks"] == terminal["checks"]
                 and data["selectors"]["water_composition"] == "1"
                 and data["selectors"]["actual_submission"] == ("1" if expected_atomic else "0")
                 and (engine_sha is None or data["engine_sha256"] == engine_sha),
                 "Native Water execution, terminal or engine differs")
            for row in data["framebuffer"]:
                serials = row["control_submission_serials"]
                need(len(serials) == 4 and all(type(serial) is int for serial in serials)
                     and (all(a < b for a, b in zip(serials, serials[1:])) if expected_atomic else serials == [-1]*4),
                     row["label"] + " did not preserve the first read of three successive control states")
            result["water_framebuffer_sha256"] = water_framebuffers(data, folder)
        if test == "test_workbench_member_presentation":
            need(data == terminal and data.get("graphical") is True
                 and type(data.get("process_id")) is int and data["process_id"] > 0,
                 "Multipart terminal, actual graphical receipt or process identity differs")
            if engine_sha is not None:
                need(data.get("engine_sha256") == engine_sha
                     and data.get("render_thread_inline") is expected_inline
                     and data.get("actual_submission_enabled") is expected_atomic
                     and data.get("requested_render_lookahead") == (str(expected_lookahead) if expected_atomic else ""),
                     "Multipart engine, render owner, actual atomic mode or bounded selector differs")
            native_file = "cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so"
            rapier_file = "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if os.name == "nt" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
            need(data.get("native_sha256") == digest(project / "addons/cybersand_native/bin" / native_file)
                 and data.get("rapier_sha256") == digest(project / "addons/godot-rapier2d/bin" / rapier_file),
                 "Multipart native or Rapier bytes differ")
            observations = data.get("observations", [])
            expected_members = {(stage, slot) for stage in ("initialized", "completed", "replacement") for slot in range(24)}
            need(len(observations) == 72 and {(row.get("stage"), row.get("slot")) for row in observations} == expected_members
                 and all(row.get("valid") is True and row.get("pose") == row.get("observed_pose")
                         and row.get("step") == row.get("manual_steps") for row in observations),
                 "Multipart actual owner/member/physical history inventory is incomplete")
            picking = data.get("picking", [])
            root_clicks = [row for row in picking if row.get("kind") == "ordinary_mouse_click"]
            member_clicks = [row for row in picking if row.get("kind") == "individual_member_mouse_click"]
            need(len(root_clicks) == 12
                 and {(row.get("stage"),row.get("actor_slot")) for row in root_clicks} == {
                     (stage,slot) for stage in ("initialized","replacement") for slot in range(6)}
                 and len(member_clicks) == 72
                 and {(row.get("stage"),row.get("body_slot")) for row in member_clicks} == expected_members
                 and all(row.get("selected_id") == row.get("actor_id")
                         and row.get("step_before") == row.get("step_after") for row in root_clicks + member_clicks),
                 "Ordinary root/member mouse input or no-physical-credit inventory is incomplete")
            refusals = [row for row in picking if row.get("fixture_injected_refusal") is True]
            expected_refusals = {(stage,kind) for stage in ("initialized","replacement")
                                 for kind in ("withheld_root","wrong_member_generation")}
            expected_refusals.add(("replacement","retired_owner"))
            expected_refusals.update((stage,kind) for stage in ("initialized","completed","replacement")
                                     for kind in ("withheld_member","foreign_member_generation"))
            need(len(refusals) == 11 and {(row.get("stage"),row.get("kind")) for row in refusals} == expected_refusals
                 and all(row.get("selected_id") == 0 for row in refusals),
                 "Multipart withheld, foreign or retired owner refusal is incomplete")
            pixels = data.get("framebuffer", {})
            need(pixels.get("body_slot") == 23 and all(isinstance(pixels.get(key),list) and len(pixels[key]) == 4
                 for key in ("shown","hidden","restored"))
                 and max(abs(a-b) for a,b in zip(pixels["shown"],pixels["hidden"])) > 0.02
                 and max(abs(a-b) for a,b in zip(pixels["shown"],pixels["restored"])) < 0.005
                 and pixels.get("png_sha256") == digest(Path(path).with_suffix(".png")),
                 "Actual body23 framebuffer show/hide/restore control differs")
        if test == "test_workbench_presentation_submission":
            # A source-bound fixture predating held placement still replays with
            # its original atomic assertions. A missing new receipt cannot opt out.
            fixture = (project / "tests" / (test + ".gd")).read_bytes()
            if stock_held or b"func _held_limb_placement()" in fixture:
                need(terminal["checks"] == data["checks"] and data["engine_atomic_admission"] is (not stock_held)
                     and type(data["process_id"]) is int and data["process_id"] > 0
                     and (engine_sha is None or data["engine_sha256"] == engine_sha),
                     "Held placement engine, PID, selector or assertion count differs")
                if stock_held:
                    need(data["engine_sha256"] in ENGINE_SHA256.values() and data["render_thread_inline"] is True
                         and data["requested_render_lookahead"] == "", "Held placement did not run on official Stock Safe")
                held_placement(data, not stock_held)
                if b'"native_sha256"' in fixture:
                    mounted = {"Windows": ("cybersand_native.windows.x86_64.dll", "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"),
                               "Linux": ("libcybersand_native.linux.x86_64.so", "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")}
                    native_file, rapier_file = mounted[data["platform"]]
                    need(data["native_sha256"] == digest(project / "addons/cybersand_native/bin" / native_file)
                         and data["rapier_sha256"] == digest(project / "addons/godot-rapier2d/bin" / rapier_file),
                         "Held placement mounted native or Rapier bytes differ")
                    held = data["held_limb_placement"]
                    need(type(held["step_before"]) is int and held["step_before"] >= 0
                         and type(held["step_after_release"]) is int and held["step_after_release"] == held["step_before"]
                         and type(held["installed_step"]) is int and held["installed_step"] >= 0,
                         "Held placement fabricated a step in the original physical owner")
        if test == "test_workbench_presentation_submission" and not stock_held:
            if engine_sha is not None:
                need(data.get("engine_sha256") == engine_sha and type(data.get("process_id")) is int
                     and data["process_id"] > 0 and data.get("render_thread_inline") is expected_inline
                     and data.get("requested_render_lookahead") == str(expected_lookahead),
                     "Actual transaction executable, PID, render owner or bounded selector differs")
            need(data.get("engine_atomic_admission") is True,
                 "Journal-only pre-draw refusal cannot reject already-flushed candidate pixels")
            picking = data.get("unsubmitted_material_picking", {})
            need(all(type(picking.get(key)) is int for key in ("actor_id", "selected_id", "body_slot",
                 "submitted_revision", "previous_uploaded_revision", "uploaded_revision", "previous_uploaded_serial",
                 "uploaded_serial", "step_before", "step_after", "next_material_revision"))
                 and picking["actor_id"] > 0 and picking["selected_id"] == picking["actor_id"]
                 and picking["uploaded_material_id"] == 2
                 and picking["uploaded_revision"] > picking["previous_uploaded_revision"] == picking["submitted_revision"]
                 and picking["uploaded_serial"] > picking["previous_uploaded_serial"]
                 and picking["mapping_unchanged"] is True
                 and isinstance(picking.get("before_sha256"), str) and len(picking["before_sha256"]) == 64
                 and picking["held_sha256"] == picking["before_sha256"]
                 and picking["submission_delta"] == picking["pre_draw_delta"] == 0
                 and picking["step_before"] == picking["step_after"]
                 and picking["next_submission_delta"] == 1
                 and picking["next_material_revision"] == picking["uploaded_revision"],
                 "Actual newer native material must retain the unchanged submitted framebuffer and actor mouse mapping until a genuine draw")
            pick_refusals = picking.get("refusal_controls", [])
            need(len(pick_refusals) == 3
                 and {row.get("kind") for row in pick_refusals} == {"future_submission", "foreign_world", "material_join"}
                 and all(row.get("fixture_injected_refusal") is True and row.get("selected_id") == 0 for row in pick_refusals),
                 "Submitted-frame picking lacks serial, World or material join refusals")
            refusals = data.get("refusal_framebuffers", [])
            need(isinstance(refusals, list) and len(refusals) == 8
                 and {row.get("case") for row in refusals} == {
                     "owner", "material", "policy", "camera", "lifecycle", "physical_completion", "manual_before_flush", "manual_during_flush"}
                 and all(row.get("before_sha256") == row.get("after_sha256")
                         and isinstance(row.get("before_sha256"), str) and len(row["before_sha256"]) == 64
                         and row.get("mapping_unchanged") is True
                         and row.get("pre_draw_delta") == row.get("post_draw_delta") == row.get("submission_delta") == 0
                         for row in refusals), "Stale candidate refusal lacks actual unchanged framebuffer evidence")
            during = next(row for row in refusals if row["case"] == "manual_during_flush")
            need(during.get("journal_delta") == 0 and during.get("next_submission_delta") == 1
                 and type(during.get("staged_candidate_serial")) is int and during["staged_candidate_serial"] > 0
                 and during.get("next_candidate_serial") == during["staged_candidate_serial"]
                 and isinstance(during.get("next_framebuffer_sha256"), str) and len(during["next_framebuffer_sha256"]) == 64
                 and during["next_framebuffer_sha256"] != during["before_sha256"],
                 "Manual draw during message flush must refuse without consuming candidate, then actually draw it after flush")
            fallback = data.get("fallback_ui", [])
            need(isinstance(fallback, list) and len(fallback) == 4
                 and {row.get("case") for row in fallback} == {
                     "invalid_initial_source", "invalid_actor_receipt", "retired_physical_owner", "physical_owner_restart"},
                 "Atomic invalid-owner/source fallback inventory is incomplete")
            fallback = {row["case"]: row for row in fallback}
            initial = fallback["invalid_initial_source"]
            need(initial.get("enabled") is False and initial.get("refusal") == "source_identity_invalid"
                 and initial.get("handshake_absent") is True and initial.get("pre_draw_delta", 0) > 0
                 and initial.get("framebuffer_available") is True and initial.get("native_workbench_initialized") is True,
                 "Invalid atomic source must refuse opt-in while ordinary native UI still draws")
            for case in ("invalid_actor_receipt", "retired_physical_owner"):
                row = fallback[case]
                need(row.get("pre_draw_delta") == row.get("submission_delta") == 1
                     and row.get("frame_valid") is False and row.get("visible_parts") == 0,
                     "Invalid/retired actor owner must admit an actual safe empty-overlay UI draw")
            need(fallback["retired_physical_owner"].get("picking_refused") is True,
                 "Retired owner must refuse picking without a submitted map")
            restarted = fallback["physical_owner_restart"]
            need(type(restarted.get("retired_owner")) is int and restarted["retired_owner"] > 0
                 and type(restarted.get("new_owner")) is int and restarted["new_owner"] > 0
                 and restarted["new_owner"] != restarted["retired_owner"] and restarted.get("submission_delta", 0) > 0
                 and restarted.get("frame_valid") is True and restarted.get("visible_parts") == 2,
                 "Ordinary Restore must rebuild a different physical owner and actually draw its actor")
            completed = next(row for row in refusals if row["case"] == "physical_completion")
            need(completed.get("real_step_delta") == completed.get("real_manual_step_delta") == 1,
                 "Physical-completion refusal did not execute one real normal physical step")
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
    parser.add_argument("--focus", choices=("all", "submission", "held-placement", "water", "members", "frozen"), default="all")
    parser.add_argument("--render-thread", choices=("safe", "separate"), default="safe")
    parser.add_argument("--lookahead", type=int, choices=(0, 4), default=0)
    parser.add_argument("--development-engine-proof", type=Path,
                        help="Exact local Linux build custody; application qualification remains required")
    parser.add_argument("--import-engine", type=Path,
                        help="Pinned stock Linux editor used to import for a local template runtime")
    engine_admission.add_arguments(parser)
    args = parser.parse_args()
    source_root, engine, output = args.source.resolve(), args.engine.resolve(), args.output.resolve()
    need(not output.exists(), "Preserve original qualification evidence; output must be new")
    source = source_identity(source_root)
    native = validate_runtime(source_root, source, args.runtime.resolve(), args.allow_development_toolchain_drift)
    platform = "windows" if os.name == "nt" else "linux"
    engine_proof = None
    import_engine = engine
    if args.development_engine_proof:
        need(args.engine_payload is None and platform == "linux" and args.import_engine is not None,
             "Local development gates require an explicit stock importer and no Windows payload role")
        from development_engine import admit_build
        engine_proof = admit_build(engine, args.development_engine_proof)
        import_engine = args.import_engine.resolve()
        need(digest(import_engine) == ENGINE_SHA256["linux"], "Local template import requires exact official Godot4.7 editor bytes")
    elif args.engine_payload:
        need(args.import_engine is None, "Windows payload qualification uses its admitted editor")
        actual, engine_proof = engine_admission.admit(args)
        need(actual == engine, "Actual correctness executable differs from admitted engine payload")
    else:
        need(args.import_engine is None, "Stock control imports with its exact tested engine")
        need(digest(engine) == ENGINE_SHA256[platform], "Stock control requires the exact official Godot 4.7 executable")
        need(args.render_thread == "safe", "Unregistered stock Separate control")
        need(args.lookahead == 0, "Stock reference has no bounded engine treatment")
    need(args.render_thread == "safe" or args.focus in ("submission", "water", "members"),
         "Frozen correctness inventory retains its original Safe owner; new Separate gates run separately")
    need(args.focus != "held-placement" or (not args.headless_only and engine_proof is None),
         "Held placement requires actual graphical Stock Safe")
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
              "import_engine_sha256": digest(import_engine),
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
            if args.focus == "held-placement":
                environment["CYBERSAND_DIAG_ACTUAL_SUBMISSION"] = "0"
            if test in ("test_workbench_water_composition_native", "test_workbench_member_presentation"):
                environment["CYBERSAND_DIAG_ACTUAL_SUBMISSION"] = "1" if engine_proof else "0"
            if SUPPLEMENTAL[test].get("output_environment"):
                environment[SUPPLEMENTAL[test]["output_environment"]] = str(folder / "receipt.json")
        if test == "test_workbench_physics_causal_trace":
            environment["CYBERSAND_DIAG_PHYSICS_CAUSAL_TRACE"] = "1"
        command = [str(import_engine if test == "import" else engine), "--path", str(project), "--audio-driver", "Dummy"]
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
        if test in SUPPLEMENTAL:
            # Two paused history-retirement intervals require over 4,000 real
            # draws on the hosted Windows software adapter.
            water_on_angle = os.name == "nt" and test == "test_workbench_water_composition_native"
            item = run(command, environment, folder, 1800 if water_on_angle else 600)
        else:
            item = run(command, environment, folder, 1200 if test == "import" else 600)
        item.update(test=test, slots=slots, graphical=graphical)
        text = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
        try:
            need(item["returncode"] == 0 and not item.get("timed_out", False), "Godot process failed or timed out")
            need("SCRIPT ERROR:" not in text and "ERROR:" not in text, "Strict Godot diagnostic failure")
            if test in SUPPLEMENTAL:
                item["evidence"] = supplemental_result(test, text, folder, source, project, engine_sha=report["engine_sha256"],
                    expected_inline=args.render_thread == "safe", expected_lookahead=args.lookahead,
                    expected_atomic=bool(engine_proof), stock_held=args.focus == "held-placement")
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
    if imported and args.focus == "held-placement":
        invoke("test_workbench_presentation_submission", 2, True, ["--stock-held-limb-placement"])
    if imported and args.focus in ("all", "water"):
        invoke("test_workbench_water_composition")
        if not args.headless_only:
            invoke("test_workbench_water_composition", 3, True)
            invoke("test_workbench_water_composition_native", 2, True)
    if imported and args.focus in ("all", "members"):
        invoke("test_workbench_presentation_history")
        invoke("test_workbench_presentation_member_history")
        if not args.headless_only:
            invoke("test_workbench_member_presentation", 2, True)
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
