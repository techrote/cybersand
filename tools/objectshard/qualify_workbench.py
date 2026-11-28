#!/usr/bin/env python3
"""Source-bound ordinary Workbench qualification for the opt-in M4 candidate.

The real native extension and Rapier execute through the ordinary Main and
CyberSimulationWorker. File identity, native/semantic progression, graphical
draws and physical owner acceptance are separate fields in the final receipt.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy
import native_candidate_identity as native
import run_godot_regressions as runner
from native_receipt import verify as verify_linux_receipt
from qualify_lab import RAPIER_HASHES, VERSION, require_custody
from process_resources import run_observed_case

FOCUSED = (
    ("test_object_shard_lab", "objectshard-lab-integration-test-v1"),
    ("test_object_shard_fragment_motion", "objectshard-fragment-motion-v1"),
    ("test_object_shard_m4_remote_barrel", "objectshard-m4-remote-barrel-v1"),
    ("test_object_shard_m4_small_fragment_chain", "objectshard-m4-small-fragment-native-chain-v1"),
    ("test_object_shard_m4_sparse_parent_motion", "objectshard-m4-sparse-parent-motion-v1"),
    ("test_object_shard_m4_fresh_barrel", "objectshard-m4-fresh-barrel-v1"),
    ("test_object_shard_m4_camera_lifecycle", "objectshard-m4-camera-lifecycle-v1"),
    ("test_object_shard_m4_receipt_scheduling", "objectshard-m4-receipt-scheduling-v1"),
    ("test_object_shard_m4_latency_probe", "objectshard-m4-workbench-probe-test-v1"),
    ("test_object_shard_m4_edit_delivery_fence", "objectshard-m4-edit-delivery-fence-v1"),
    ("test_object_shard_m4_optional_diagnostics", "objectshard-m4-optional-diagnostics-v1"),
    ("test_object_shard_m4_same_world_extension", "objectshard-m4-actual-godot-sameworld-v1"),
    ("test_object_shard_m4_shared_main_rapier", "objectshard-m4-existing-main-rapier-v1"),
    ("test_object_shard_m4_same_world_physical_chain", "objectshard-m4-sameworld-rapier-physical-chain-v1"),
    ("test_object_shard_m4_compact_motion_packets", "objectshard-m4-compact-motion-packet-v1"),
    ("test_object_shard_m4_workbench_scene_refusal", "objectshard-m4-ordinary-scene-refusal-v1"),
    ("test_object_shard_m4_workbench_completion", "objectshard-m4-workbench-completion-v1"),
    ("test_object_shard_m4_material_only_workbench", "objectshard-m4-material-only-workbench-v1"),
    ("test_object_shard_m4_fragment_reabsorption", "objectshard-m4-fragment-reabsorption-v1"),
    ("test_object_shard_m4_lifecycle_adverse", "objectshard-m4-lifecycle-adverse-v1"),
    ("test_object_shard_m4_completed_sample", "objectshard-m4-completed-sample-v1"),
    ("test_object_shard_m4_equipment_completion", "objectshard-m4-equipment-completion-v1"),
    ("test_object_shard_m4_actor_clock", "objectshard-m4-actor-clock-v1"),
    ("test_object_shard_m4_long_burn", "objectshard-m4-long-burn-v1"),
    ("test_object_shard_m4_lifecycle_fuzz", "objectshard-m4-lifecycle-fuzz-v1"),
)
OWNER_REGRESSIONS = {
    "test_liquid_desktop_default_host": r"^LIQUID_DESKTOP_DEFAULT_HOST: ([1-9][0-9]*) assertions; 0 failures$",
    "test_liquid_trial_body": r"^LIQUID_TRIAL_BODY: ([1-9][0-9]*) assertions, 0 failures$",
    "test_persistent_area_owner_adversarial": r"^GEN006_OWNER_ADVERSARIAL assertions=([1-9][0-9]*) failures=0$",
}
REGRESSIONS = (
    "test_workbench_canvas", "test_workbench_wave", "test_workbench_wave_spill",
    "test_workbench_failure_containment", "test_workbench_failure_recovery",
    "test_workbench_liquid_equipment", "test_physical_actor_session",
    "test_actor_usables_integration", "test_physical_usable_equipment",
    "test_workbench_actor_composition_native", "test_workbench_actor_composition_session",
    "test_persistent_area_residency_native",
)
SCENES = ("tower", "viaduct", "timber", "mixed", "stress")


def save(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def completion(path: Path, schema: str) -> dict:
    matches = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("schema") == schema:
            matches.append(value)
    if len(matches) != 1:
        raise ValueError("Missing or duplicate completion receipt: " + schema)
    value = matches[0]
    failures = value.get("failures")
    if not ((type(failures) is int and failures == 0) or (isinstance(failures, list) and not failures)):
        raise ValueError("Unsuccessful completion receipt: " + schema)
    if type(value.get("checks")) is not int or value["checks"] < 1:
        raise ValueError("Empty completion receipt: " + schema)
    return value


def validate_profile(value: dict, source: str, rendered: bool) -> None:
    """Reject a successful-looking footer with no actual physical workload."""
    if value.get("source_commit") != source or value.get("scene") not in SCENES or value.get("camera") not in ("overview", "zoom"):
        raise ValueError("Profile workload or source identity mismatch")
    if value.get("sampling") not in ("cohorts", "light") or type(value.get("recording_enabled")) is not bool:
        raise ValueError("Profile must identify independent callback sampling and diagnostic recording")
    latency = value.get("latency", {})
    if latency.get("enabled") is not value["recording_enabled"]:
        raise ValueError("Profile recording state disagrees with its actual probe")
    if value["recording_enabled"] and (type(latency.get("events_retained")) is not int or latency["events_retained"] <= 0
                                      or not latency.get("cadence", {}).get("native_progress_delivery")):
        raise ValueError("Enabled profile has no actual diagnostic events or native delivery intervals")
    for field, minimum in (("completed_semantic_ticks", 180), ("actual_physics_steps", 1),
                           ("native_pose_acknowledgements", 1), ("active_body_count_max", 1), ("elapsed_usec", 1)):
        if type(value.get(field)) is not int or value[field] < minimum:
            raise ValueError("Incomplete actual profile workload: " + field)
    rate = value.get("semantic_ticks_per_wall_second")
    if type(rate) not in (int, float) or not math.isfinite(rate) or rate <= 0:
        raise ValueError("Invalid native progression rate")
    if not value.get("shard_dimensions") or not value.get("active_body_cohorts"):
        raise ValueError("Missing physical workload populations")
    if type(value.get("native_pose_echo_checks")) is not int or value["native_pose_echo_checks"] != value["native_pose_acknowledgements"]:
        raise ValueError("Native pose echoes do not cover every actual segment acknowledgement")
    submissions = value.get("render_submissions")
    if type(submissions) is not int or submissions < (1 if rendered else 0):
        raise ValueError("Missing renderer submission witness")
    if rendered == (value.get("display_driver") == "headless") or (not rendered and submissions != 0):
        raise ValueError("Graphical and headless evidence scopes disagree")
    intervals = value.get("completed_physical_intervals")
    if type(intervals) is not int or abs(intervals - value["completed_semantic_ticks"]) > 1:
        raise ValueError("Native and complete physical interval progression disagree")
    physical_seconds = value.get("simulated_physical_seconds")
    if type(physical_seconds) not in (int, float) or not math.isclose(physical_seconds, intervals / 60.0, abs_tol=1e-8):
        raise ValueError("Physical time is not bound to completed actual intervals")
    supports = value.get("before_cut_supports", {})
    if any(type(supports.get(key)) is not int for key in ("material_bodies_before_cut", "missing_support_cells", "support_cells")) or \
            supports["material_bodies_before_cut"] != 0 or supports["missing_support_cells"] != 0 or supports["support_cells"] <= 0:
        raise ValueError("Missing actual intact foundation witness")
    contacts = value.get("material_contact_deltas", {})
    for material, scenes in (("water", ("viaduct", "mixed")), ("sand", ("mixed",))):
        events = contacts.get("relocated_" + material + "_cells")
        if value["scene"] in scenes and (type(events) is not int or events <= 0):
            raise ValueError("Missing committed native " + material + " interaction")


def validate_throughput(value: dict, source: str, rendered: bool) -> None:
    """Bind the light matched window to actual clocks, populations and source."""
    workload = value.get("workload")
    if value.get("source_commit") != source or workload not in ("disabled", "empty", "tower", "stress", "sleeping"):
        raise ValueError("Throughput workload or source identity mismatch")
    if value.get("process_fps_cap") != 60 or value.get("canvas_extent") != [512, 512] or not re.fullmatch(
            r"[0-9a-f]{64}", str(value.get("authored_rectangles_sha256", ""))):
        raise ValueError("Throughput matched process cap or authored workload is missing")
    for field, minimum in (("elapsed_usec", 3_000_000), ("semantic_ticks", 1), ("rapier_segments", 1)):
        if type(value.get(field)) is not int or value[field] < minimum:
            raise ValueError("Throughput lacks actual clock progression: " + field)
    rate = value.get("semantic_ticks_per_second")
    if type(rate) not in (int, float) or not math.isfinite(rate) or not math.isclose(
            rate, value["semantic_ticks"] * 1_000_000 / value["elapsed_usec"], rel_tol=1e-8):
        raise ValueError("Throughput rate does not follow its measured native clock")
    draws = value.get("renderer_callbacks")
    if type(draws) is not int or draws < (1 if rendered else 0) or \
            rendered == (value.get("display_driver") == "headless") or (not rendered and draws != 0):
        raise ValueError("Throughput headless/rendered evidence scopes disagree")
    if type(value.get("recording_enabled")) is not bool or \
            value.get("latency", {}).get("enabled") is not value["recording_enabled"] or \
            (value["recording_enabled"] and value["latency"].get("events_retained", 0) <= 0):
        raise ValueError("Throughput recording state lacks its actual probe witness")
    expected = {"disabled": "0/0", "empty": "0/0", "tower": "1/1", "stress": "8/8", "sleeping": "1/0"}[workload]
    cohorts = value.get("cohorts", {})
    cohort = cohorts.get(expected, {})
    if type(cohort.get("wall_usec")) is not int or cohort["wall_usec"] <= 0 or \
            type(cohort.get("callbacks")) is not int or cohort["callbacks"] <= 0 or \
            (workload in ("disabled", "empty", "sleeping") and set(cohorts) != {expected}):
        raise ValueError("Throughput lacks the requested actual body cohort")
    if workload != "disabled":
        after = value.get("after", {})
        acknowledgements = after.get("native_pose_acknowledgements")
        if type(acknowledgements) is not int or type(after.get("native_pose_echo_checks")) is not int or \
                acknowledgements != after["native_pose_echo_checks"]:
            raise ValueError("Throughput loses a native pose acknowledgement echo")
        intervals = value.get("runtime_counter_deltas", {}).get("physical_intervals")
        if type(intervals) is not int or abs(intervals - value["semantic_ticks"]) > 1:
            raise ValueError("Throughput physical and semantic clocks disagree")


def validate_render_control(value: dict, source: str) -> None:
    if value.get("source_commit") != source or value.get("display_driver") in (None, "headless"):
        raise ValueError("Renderer controls need actual graphical exact-source observations")
    rows = value.get("windows", [])
    if [row.get("label") for row in rows] != ["intact_paused", "intact_playing", "detached_paused", "detached_playing"]:
        raise ValueError("Missing paired intact/detached pause/play windows")
    for row in rows:
        if row.get("elapsed_usec", 0) < 12_000_000 or row.get("render_submissions", 0) <= 0:
            raise ValueError("Incomplete actual renderer control window")
        if row.get("native_pose_echo_checks") != row.get("native_pose_acknowledgements"):
            raise ValueError("Renderer control lacks exact native pose echoes")
        if row["label"].endswith("paused"):
            if row.get("semantic_ticks") != 0 or row.get("actual_physics_steps") != 0:
                raise ValueError("Paused renderer control advanced simulation")
        elif row.get("semantic_ticks", 0) <= 0 or row.get("actual_physics_steps", 0) <= 0:
            raise ValueError("Playing renderer control did not progress")
    if max(rows[-1].get("awake_bodies_before", 0), rows[-1].get("awake_bodies_after", 0)) <= 0:
        raise ValueError("Detached renderer control never observed an awake body")


def validate_disabled_control(value: dict, source: str, rendered: bool) -> None:
    if value.get("source_commit") != source or value.get("scene") != "tower" or value.get("camera") != "overview":
        raise ValueError("Disabled control workload/source mismatch")
    if rendered == (value.get("display_driver") == "headless"):
        raise ValueError("Disabled control graphical/headless scope mismatch")
    if value.get("canvas_extent") != [512, 512] or not re.fullmatch(r"[0-9a-f]{64}", value.get("authored_rectangles_sha256", "")):
        raise ValueError("Disabled control lacks its exact native authoring identity")
    rows = value.get("windows", [])
    if [row.get("label") for row in rows] != ["disabled_intact_paused", "disabled_intact_playing"]:
        raise ValueError("Disabled control is missing its complete pause/play pair")
    for row in rows:
        if row.get("elapsed_usec", 0) < 12_000_000 or row.get("objectshard_enabled") is not False or row.get("objectshard_native_attached") is not False:
            raise ValueError("Disabled control is incomplete or attached ObjectShard")
        if row.get("material_body_count") != 0 or row.get("ordinary_actor_count") != 1 or row.get("worker_snapshot_calls") != 0:
            raise ValueError("Disabled control changed the declared physical workload")
        submissions = row.get("render_submissions")
        if type(submissions) is not int or (submissions <= 0 if rendered else submissions != 0):
            raise ValueError("Disabled control lacks a valid renderer witness")
        ticks, steps = row.get("semantic_ticks"), row.get("actual_physics_steps")
        if type(ticks) is not int or type(steps) is not int or (ticks != 0 or steps != 0 if row["label"].endswith("paused") else ticks <= 0 or steps <= 0):
            raise ValueError("Disabled control native/Rapier progression contradicts pause/play")


def committed_inputs() -> dict[str, str]:
    scopes = ("godot", "tools/objectshard", "tools/ci", "materials/catalogue")
    paths = subprocess.check_output(["git", "ls-files", "-z", "--", *scopes], cwd=ROOT).decode().split("\0")
    selected = sorted(p for p in paths if p and "/bin/" not in p and "/.godot/" not in p
                      and Path(p).suffix in (".gd", ".tscn", ".godot", ".py", ".json", ".gdextension", ".gdshader"))
    # Pass bounded scopes, not hundreds of source paths: Windows CreateProcess
    # has a small command-line limit. Intersect the full changed-path response
    # with the exact custody selection so runtime hydration remains excluded.
    changed = subprocess.check_output(["git", "diff", "--name-only", "-z", "HEAD", "--", *scopes],
                                      cwd=ROOT, timeout=120).decode().split("\0")
    dirty = sorted(set(selected).intersection(changed))
    if dirty:
        raise ValueError("Qualification source is not committed: " + ", ".join(dirty))
    return {p: runner.sha256(ROOT / p) for p in selected}


def verify_packaged_engine(package: Path, engine: Path, manifest: dict) -> Path:
    """Package replay must execute the manifest-bound engine in this extraction."""
    from verify_package import safe_path
    shipped = safe_path(package, "Godot_v4.7-stable_win64_console.exe").resolve()
    if engine.resolve() != shipped or runner.sha256(shipped) != manifest["godot"]["console_sha256"]:
        raise ValueError("Package replay requires its shipped console engine")
    return shipped


def qualify(args: argparse.Namespace) -> dict:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "objectshard-m4-workbench-qualification-v1", "status": "incomplete",
              "source_commit": args.expected_source_sha, "cases": [], "failures": [],
              "render_requested": args.render,
              "physical_owner_acceptance": "OWNER-PENDING: Windows 11/NVIDIA display and playfeel"}
    original_root = runner.ROOT
    try:
        if not re.fullmatch(r"[0-9a-f]{40}", args.expected_source_sha):
            raise ValueError("Expected a complete source commit")
        require_custody(sys.platform, args.native_candidate, args.package, args.native_receipt)
        commit, tree, inputs = native.source(ROOT)
        if commit != args.expected_source_sha:
            raise ValueError("Checked-out source differs from expected source")
        script_inputs = committed_inputs()
        report.update(source_tree=tree, native_source_inputs=inputs, executed_script_inputs=script_inputs)
        executed_root = ROOT
        if args.package:
            from verify_workbench_package import verify, verify_committed_godot_inputs
            manifest = verify(args.package)
            if manifest["source_commit"] != commit or manifest["source_tree"] != tree or manifest["native"]["source_inputs"] != inputs:
                raise ValueError("Packaged native source differs from qualification checkout")
            executed_root = args.package.resolve()
            import reciprocal_windows_package as reciprocal
            reciprocal.verify_package(executed_root, ROOT)
            report["packaged_godot_input_locations"] = verify_committed_godot_inputs(
                executed_root, script_inputs, foreign_paths=reciprocal.FOREIGN_PATHS)
            verify_packaged_engine(executed_root, args.godot, manifest)
            report["package_manifest_sha256"] = runner.sha256(executed_root / "objectshard-workbench-manifest.json")
        runner.ROOT = executed_root
        native_path, rapier_path = runner.runtime_paths()
        if sys.platform.startswith("linux"):
            report["native_build_receipt"] = verify_linux_receipt(args.native_receipt, native_path)
        elif args.native_candidate:
            candidate = native.verify(ROOT, args.native_candidate)
            if runner.sha256(native_path) != candidate["sha256"]:
                raise ValueError("Loaded DLL differs from exact-source candidate")
        if runner.sha256(rapier_path) != RAPIER_HASHES.get(sys.platform):
            raise ValueError("Rapier does not match the admitted runtime")
        engine = args.godot.resolve()
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        if version != VERSION:
            raise ValueError("Godot version differs from exact pin: " + version)
        report["runtime"] = {"godot_version": version, "godot_sha256": runner.sha256(engine),
                             "native_sha256": runner.sha256(native_path), "rapier_sha256": runner.sha256(rapier_path),
                             "platform": sys.platform}
        environment = dict(os.environ, CYBERSAND_SOURCE_REVISION=commit)
        environment.pop("CYBERSAND_PACKAGE_MANIFEST", None)
        if args.package:
            environment["CYBERSAND_PACKAGE_MANIFEST"] = str(executed_root / "objectshard-workbench-manifest.json")
        cases = [(runner.Case("m4_workbench_import", ("--editor", "--quit"),
                              int(execution_policy.watchdog_seconds("godot_import_seconds")), 0), None)]
        if args.regressions:
            discovered = {case.name: case for case in runner.discover_cases()}
            cases.extend((discovered[name], None) for name in OWNER_REGRESSIONS)
        for name, schema in FOCUSED:
            if args.render and name.endswith("long_burn"):
                continue # Natural lifetime/retirement is qualified in the headless lane.
            flags = runner.script_case_flags(name)
            graphical_diagnostics = (args.render and name.endswith("optional_diagnostics")) or ((args.render or args.package) and name.endswith("camera_lifecycle"))
            if name.endswith("camera_lifecycle"):
                flags += ("--output=" + str(output / "camera-lifecycle-captures"),)
            if graphical_diagnostics:
                flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") + flags
            cases.append((runner.Case(name, flags, int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0,
                                      graphical_diagnostics), schema))
            if name == "test_object_shard_m4_workbench_completion":
                reopen_flags = ("--script", "res://tests/fixtures/object_shard_m4_authored_reopen.gd",
                                "--", "--objectshard-m4-workbench")
                cases.append((runner.Case("m4_fresh_authored_reopen", reopen_flags, cases[-1][0].timeout, 0),
                              "objectshard-m4-fresh-authored-reopen-v1"))
        diagnostics_cli_flags = ("--script", "res://tests/test_object_shard_m4_optional_diagnostics.gd", "--",
                                 "--objectshard-m4-workbench", "--objectshard-diagnostics")
        if args.render:
            diagnostics_cli_flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") + diagnostics_cli_flags
        cases.append((runner.Case("test_object_shard_m4_optional_diagnostics_cli",
            diagnostics_cli_flags, int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0, args.render),
            "objectshard-m4-optional-diagnostics-v1"))
        if args.regressions:
            for name in REGRESSIONS:
                cases.append((runner.Case(name, ("--script", "res://tests/" + name + ".gd"),
                                          int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), None))
            cases.append((runner.Case("retained_lab_profile", ("--script", "res://tests/profile_object_shard_lab.gd", "--",
                "--objectshard-profile=" + str(output / "retained_lab_profile.json")),
                int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-lab-profile-v1"))
        if args.render or args.package:
            # DummyRenderer cannot supply texture updates/framebuffers. Both
            # source and clean extracted application execute these real draws.
            for name, schema in (("test_object_shard_m4_overlay_identity", "objectshard-m4-overlay-identity-v1"),
                                 ("test_object_shard_m4_material_preparation_render", "objectshard-m4-material-preparation-v1"),
                                 ("test_object_shard_m4_material_presentation_render", "objectshard-m4-material-presentation-v1")):
                flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3",
                         "--script", "res://tests/" + name + ".gd", "--",
                         "--output=" + str(output / "material-presentation-captures"))
                cases.append((runner.Case(name, flags, int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True), schema))
        if args.profile:
            for workload, recording in (("disabled", "off"), ("empty", "off"), ("tower", "off"),
                                        ("stress", "off"), ("sleeping", "off"), ("tower", "on")):
                name = f"m4_throughput_{workload}_{recording}_" + ("render" if args.render else "headless")
                flags = ("--max-fps", "60", "--script", "res://tests/profile_object_shard_m4_throughput.gd", "--")
                if workload != "disabled":
                    flags += ("--objectshard-m4-workbench",)
                flags += ("--workload=" + workload, "--seconds=6", "--recording=" + recording,
                          "--output=" + str(output / (name + ".json")))
                if args.render:
                    flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") + flags
                cases.append((runner.Case(name, flags,
                              int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, args.render),
                              "objectshard-m4-throughput-v1"))
            disabled_flags = ("--script", "res://tests/profile_object_shard_m4_disabled_control.gd", "--",
                              "--output=" + str(output / "m4_disabled_controls.json"))
            if args.render:
                disabled_flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") + disabled_flags
            cases.append((runner.Case("m4_disabled_controls", disabled_flags,
                          int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, args.render),
                          "objectshard-m4-disabled-control-v1"))
            if args.render:
                flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3",
                         "--script", "res://tests/profile_object_shard_m4_render_control.gd", "--",
                         "--objectshard-m4-workbench", "--output=" + str(output / "m4_render_controls.json"))
                cases.append((runner.Case("m4_render_controls", flags,
                              int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True),
                              "objectshard-m4-render-control-v1"))
            for scene in SCENES:
                for camera in ("overview", "zoom"):
                    name = f"m4_workbench_{scene}_{camera}_" + ("render" if args.render else "headless")
                    flags = ("--script", "res://tests/profile_object_shard_m4_workbench.gd", "--",
                             "--objectshard-m4-workbench", "--scene=" + scene, "--camera=" + camera,
                             "--output=" + str(output / (name + ".json")))
                    if args.render:
                        flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") + flags
                    cases.append((runner.Case(name, flags, int(execution_policy.watchdog_seconds("graphical_case_seconds")),
                                              0, args.render), "objectshard-m4-workbench-profile-v1"))
            for scene in ("tower", "stress"):
                name = f"m4_workbench_{scene}_overview_light_" + ("render" if args.render else "headless")
                flags = ("--script", "res://tests/profile_object_shard_m4_workbench.gd", "--",
                         "--objectshard-m4-workbench", "--scene=" + scene, "--camera=overview", "--sampling=light", "--recording=off",
                         "--output=" + str(output / (name + ".json")))
                if args.render:
                    flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") + flags
                cases.append((runner.Case(name, flags, int(execution_policy.watchdog_seconds("graphical_case_seconds")),
                                          0, args.render), "objectshard-m4-workbench-profile-v1"))
                if scene == "tower":
                    recorded_name = "m4_workbench_tower_overview_light_recording_" + ("render" if args.render else "headless")
                    recorded_flags = tuple("--recording=on" if flag == "--recording=off" else
                                           "--output=" + str(output / (recorded_name + ".json")) if flag.startswith("--output=") else flag
                                           for flag in flags)
                    cases.append((runner.Case(recorded_name, recorded_flags,
                                  int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, args.render),
                                  "objectshard-m4-workbench-profile-v1"))
        for case, schema in cases:
            user_root = output / "isolated-user-data" / case.name
            reopen_env = {}
            if case.name == "m4_fresh_authored_reopen":
                author = report["cases"][-1]
                if author["name"] != "test_object_shard_m4_workbench_completion" or author["name"] in report["failures"]:
                    raise ValueError("Fresh reopen requires the preceding successful authored Save/Open")
                witness = author["receipt"]["observations"]["authored_reopen"]
                user_root = user_root.with_name(author["name"])
                reopen_env = {"CYBERSAND_M4_AUTHOR_PID": str(witness["process_id"]),
                              "CYBERSAND_M4_AUTHORED_FILE": witness["file_sha256"],
                              "CYBERSAND_M4_INSTALLED_SETUP": witness["installed_sha256"]}
            else:
                user_root.mkdir(parents=True)
            case_env = dict(environment, XDG_DATA_HOME=str(user_root), APPDATA=str(user_root),
                            LOCALAPPDATA=str(user_root), **reopen_env)
            record, failed = run_observed_case(runner, str(engine), case, output, "ordinary-workbench-m4", env=case_env)
            if case.name in OWNER_REGRESSIONS and not failed:
                log = (output / record["log"]).read_text(encoding="utf-8")
                assertions = re.findall(OWNER_REGRESSIONS[case.name], log, flags=re.MULTILINE)
                if len(assertions) == 1:
                    record["owner_assertions"] = int(assertions[0])
                else:
                    record["receipt_error"] = "Expected one successful owner completion: " + case.name
                    failed = True
            if schema and not failed:
                try:
                    record["receipt"] = completion(output / record["log"], schema)
                    if schema == "objectshard-m4-workbench-profile-v1":
                        validate_profile(record["receipt"], commit, case.requires_display)
                    elif schema == "objectshard-m4-throughput-v1":
                        validate_throughput(record["receipt"], commit, case.requires_display)
                    elif schema == "objectshard-m4-render-control-v1":
                        validate_render_control(record["receipt"], commit)
                    elif schema == "objectshard-m4-disabled-control-v1":
                        validate_disabled_control(record["receipt"], commit, case.requires_display)
                    elif schema == "objectshard-lab-profile-v1":
                        from lab_performance import check as check_lab_budget
                        profile = json.loads((output / "retained_lab_profile.json").read_text(encoding="utf-8"))
                        budget = json.loads((ROOT / "tools/objectshard/lab_budgets.json").read_text(encoding="utf-8"))
                        record["retained_lab_budget"] = check_lab_budget(profile, budget, rendered=False)
                        if record["retained_lab_budget"]["status"] != "passed":
                            raise ValueError("Retained standalone Lab budgets failed: " + str(record["retained_lab_budget"]["failures"]))
                except ValueError as error:
                    record["receipt_error"] = str(error)
                    failed = True
            report["cases"].append(record)
            if failed:
                report["failures"].append(case.name)
            save(output / "qualification.json", report)
        if args.render and args.profile and not report["failures"]:
            disabled = json.loads((output / "m4_disabled_controls.json").read_text(encoding="utf-8"))
            enabled = json.loads((output / "m4_render_controls.json").read_text(encoding="utf-8"))
            control_fields = ("scene", "camera", "canvas_extent", "control_view", "authored_rectangles_sha256")
            if any(disabled.get(key) != enabled.get(key) for key in control_fields):
                raise ValueError("Disabled/enabled renderer controls do not have matching authoring and camera inputs")
            report["disabled_enabled_control_identity"] = {key: enabled[key] for key in control_fields}
        if committed_inputs() != script_inputs or native.source(ROOT) != (commit, tree, inputs):
            raise ValueError("Source changed during qualification")
        report["status"] = "passed" if not report["failures"] else "failed"
    except Exception as error:
        report["failures"].append(str(error))
        report["status"] = "failed"
    finally:
        runner.ROOT = original_root
        save(output / "qualification.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--native-candidate", type=Path)
    parser.add_argument("--native-receipt", type=Path)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--regressions", action="store_true")
    parser.add_argument("--profile", action="store_true")
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    if args.render and not args.profile:
        parser.error("--render requires --profile")
    report = qualify(args)
    print(json.dumps({"status": report["status"], "cases": len(report["cases"]), "failures": report["failures"]}))
    raise SystemExit(0 if report["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
