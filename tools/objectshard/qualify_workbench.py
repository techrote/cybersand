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
    ("test_object_shard_m4_latency_probe", "objectshard-m4-workbench-probe-test-v1"),
    ("test_object_shard_m4_same_world_extension", "objectshard-m4-actual-godot-sameworld-v1"),
    ("test_object_shard_m4_shared_main_rapier", "objectshard-m4-existing-main-rapier-v1"),
    ("test_object_shard_m4_same_world_physical_chain", "objectshard-m4-sameworld-rapier-physical-chain-v1"),
    ("test_object_shard_m4_compact_motion_packets", "objectshard-m4-compact-motion-packet-v1"),
    ("test_object_shard_m4_workbench_completion", "objectshard-m4-workbench-completion-v1"),
    ("test_object_shard_m4_material_only_workbench", "objectshard-m4-material-only-workbench-v1"),
    ("test_object_shard_m4_fragment_reabsorption", "objectshard-m4-fragment-reabsorption-v1"),
    ("test_object_shard_m4_lifecycle_adverse", "objectshard-m4-lifecycle-adverse-v1"),
    ("test_object_shard_m4_completed_sample", "objectshard-m4-completed-sample-v1"),
    ("test_object_shard_m4_equipment_completion", "objectshard-m4-equipment-completion-v1"),
    ("test_object_shard_m4_long_burn", "objectshard-m4-long-burn-v1"),
    ("test_object_shard_m4_lifecycle_fuzz", "objectshard-m4-lifecycle-fuzz-v1"),
)
REGRESSIONS = (
    "test_workbench_canvas", "test_workbench_wave", "test_workbench_wave_spill",
    "test_workbench_failure_containment", "test_workbench_failure_recovery",
    "test_workbench_liquid_equipment", "test_physical_actor_session",
    "test_actor_usables_integration", "test_physical_usable_equipment",
    "test_workbench_actor_composition_native", "test_workbench_actor_composition_session",
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
            from verify_workbench_package import verify
            manifest = verify(args.package)
            if manifest["source_commit"] != commit or manifest["source_tree"] != tree or manifest["native"]["source_inputs"] != inputs:
                raise ValueError("Packaged native source differs from qualification checkout")
            executed_root = args.package.resolve()
            # All committed Godot source must be the exact shipped bytes.
            for p, digest in script_inputs.items():
                if p.startswith("godot/") and runner.sha256(executed_root / p) != digest:
                    raise ValueError("Packaged Godot source differs: " + p)
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
        for name, schema in FOCUSED:
            if args.render and name.endswith("long_burn"):
                continue # Natural lifetime/retirement is qualified in the headless lane.
            flags = ("--script", "res://tests/" + name + ".gd")
            if name.endswith(("workbench_completion", "material_only_workbench", "fragment_reabsorption", "lifecycle_adverse", "lifecycle_fuzz", "completed_sample", "equipment_completion", "long_burn")):
                flags += ("--", "--objectshard-m4-workbench")
            cases.append((runner.Case(name, flags, int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), schema))
        if args.regressions:
            for name in REGRESSIONS:
                cases.append((runner.Case(name, ("--script", "res://tests/" + name + ".gd"),
                                          int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), None))
            cases.append((runner.Case("retained_lab_profile", ("--script", "res://tests/profile_object_shard_lab.gd", "--",
                "--objectshard-profile=" + str(output / "retained_lab_profile.json")),
                int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), "objectshard-lab-profile-v1"))
        if args.profile:
            if args.render:
                # Godot 4.7 DummyRenderer texture_2d_update is a no-op; real
                # ImageTexture pixel readback belongs only to a renderer lane.
                overlay_flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3",
                                 "--script", "res://tests/test_object_shard_m4_overlay_identity.gd")
                cases.append((runner.Case("test_object_shard_m4_overlay_identity", overlay_flags,
                              int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True),
                              "objectshard-m4-overlay-identity-v1"))
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
                         "--objectshard-m4-workbench", "--scene=" + scene, "--camera=overview", "--sampling=light",
                         "--output=" + str(output / (name + ".json")))
                if args.render:
                    flags = ("--rendering-driver", "opengl3_angle" if sys.platform == "win32" else "opengl3") + flags
                cases.append((runner.Case(name, flags, int(execution_policy.watchdog_seconds("graphical_case_seconds")),
                                          0, args.render), "objectshard-m4-workbench-profile-v1"))
        for case, schema in cases:
            user_root = output / "isolated-user-data" / case.name
            user_root.mkdir(parents=True)
            case_env = dict(environment, XDG_DATA_HOME=str(user_root), APPDATA=str(user_root), LOCALAPPDATA=str(user_root))
            record, failed = run_observed_case(runner, str(engine), case, output, "ordinary-workbench-m4", env=case_env)
            if schema and not failed:
                try:
                    record["receipt"] = completion(output / record["log"], schema)
                    if schema == "objectshard-m4-workbench-profile-v1":
                        validate_profile(record["receipt"], commit, case.requires_display)
                    elif schema == "objectshard-m4-render-control-v1":
                        validate_render_control(record["receipt"], commit)
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
