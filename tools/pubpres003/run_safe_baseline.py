#!/usr/bin/env python3
"""Run the three existing Safe/eager graphical gates, without a timing campaign.

The native runtime, dependency receipt, pinned engine and committed application
are checked before execution. Original full-byte history assertions and strict
Godot diagnostic rejection are reused unchanged. Separate/reachable failures
are separate evidence; this small baseline never declares those modes passed.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "tools/pubpres_playability_build"
sys.path.insert(0, str(BUILD))
sys.path.insert(0, str(ROOT / "tools/pubpres_render_probes"))
from build_runtime import canonical_digest, committed_inputs, digest, git
import dependency_custody
from run_regressions import run, stage_source, terminal_json, validate_completion
from run_probes import verify_engine

CASES = ("test_material_tile_publication", "test_pubpres_transition_history_render", "test_native_pixel_camera")
DRIVERS = ("tools/pubpres003/run_safe_baseline.py", "tools/pubpres_playability_build/run_regressions.py",
           "tools/pubpres_playability_build/build_runtime.py", "tools/pubpres_playability_build/process_owner.py",
           "tools/pubpres_playability_build/dependency_custody.py", "tools/pubpres_playability_build/regression_contract.py",
           "tools/pubpres_playability/results.py", "tools/pubpres_render_probes/run_probes.py")


def committed_driver_inputs(source: str, wrapper: Path | None) -> dict:
    names = list(DRIVERS)
    if wrapper is not None:
        if wrapper != BUILD / "owned_xvfb.py":
            raise ValueError("Use the in-checkout owned_xvfb.py display owner")
        names.append("tools/pubpres_playability_build/owned_xvfb.py")
    result = {}
    for name in names:
        blob = subprocess.check_output(["git", "-C", str(ROOT), "show", source + ":" + name], timeout=30)
        actual = (ROOT / name).read_bytes()
        if canonical_digest(blob) != canonical_digest(actual):
            raise ValueError("Uncommitted baseline driver: " + name)
        result[name] = {"committed_sha256": canonical_digest(blob), "working_sha256": digest(ROOT / name)}
    return result


def verify_runtime(root: Path, source: str, runtime: Path, platform: str) -> dict:
    record = json.loads((runtime / "PUBPRES-RUNTIME.json").read_text(encoding="utf-8"))
    filename = "cybersand_native.windows.x86_64.dll" if platform == "windows" else "libcybersand_native.linux.x86_64.so"
    if (record.get("schema") != "pubpres-playability-native-build-v1" or record.get("returncode") != 0
            or record.get("platform") != platform or record.get("source_commit") != source
            or record.get("source_tree") != git(root, "rev-parse", source + "^{tree}")
            or record.get("source_inputs_sha256") != committed_inputs(root, source)
            or record.get("runtime_file") != filename or digest(runtime / filename) != record.get("runtime_sha256")
            or (runtime / filename).stat().st_size != record.get("runtime_bytes")
            or record.get("production_runtime_promotion") is not False
            or digest(runtime / "build.log") != record.get("log_sha256")):
        raise ValueError("Native runtime differs from its exact source/platform/build receipt")
    dependency_custody.verify(runtime, record)
    dependency_custody.verify_driver(BUILD, record)
    return record


def camera_evidence(text: str, project: Path, source: str, engine_hash: str, native_hash: str) -> dict:
    receipt = terminal_json(text, "NATIVE_PIXEL_CAMERA_RESULT ")
    if (receipt.get("schema") != "native-pixel-camera-v1" or receipt.get("source_revision") != source
            or receipt.get("engine_sha256") != engine_hash or receipt.get("native_runtime_sha256") != native_hash
            or len(receipt.get("moving_follow_receipts", [])) != 12
            or len(receipt.get("root_stretch_receipts", [])) != 6):
        raise ValueError("Native camera source/runtime or genuine moving Follow evidence differs")
    follows = receipt["moving_follow_receipts"]
    steps = [row.get("physics_step") for row in follows]
    if (any(type(step) is not int or step <= 0 for step in steps)
            or any(a >= b for a, b in zip(steps, steps[1:]))
            or sum(a.get("position") != b.get("position") for a, b in zip(follows, follows[1:])) < 8):
        raise ValueError("Camera evidence omits distinct completed physics steps or changing actor poses")
    hashes = receipt.get("source_hashes", {})
    required = {"res://tests/test_native_pixel_camera.gd", "res://scripts/main.gd",
                "res://scripts/pixel_camera_transform.gd", "res://scripts/shared_workbench.gd",
                "res://scripts/workbench_paint_editor_controller.gd", "res://scripts/workbench_paint_editor_overlay.gd",
                "res://shaders/material_palette.gdshader"}
    if set(hashes) != required or any(digest(project / name.removeprefix("res://")) != value for name, value in hashes.items()):
        raise ValueError("Native camera fixture/application hashes differ")
    return receipt


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--display-wrapper", type=Path)
    args = parser.parse_args(argv)
    root, engine, runtime, output = (p.resolve() for p in (args.source_root, args.engine, args.runtime, args.output))
    wrapper = args.display_wrapper.resolve() if args.display_wrapper else None
    if output.exists():
        raise ValueError("Retain every previous result; use a new output directory")
    output.mkdir(parents=True)
    summary = {"schema": "pubpres003-safe-baseline-v1", "status": "HOLD", "complete": False,
               "expected_cases": ["import", *CASES], "outcomes": [], "failure": None,
               "scope": "Safe/eager graphical tile/history/native-camera correctness only; no timing, Separate, reachable or physical NVIDIA acceptance"}
    project = None
    try:
        source = git(root, "rev-parse", "HEAD")
        if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha) or source != args.source_sha:
            raise ValueError("Source checkout differs from the explicit full source SHA")
        driver_source = git(ROOT, "rev-parse", "HEAD")
        platform = "windows" if os.name == "nt" else "linux"
        if platform == "linux" and wrapper is None:
            raise ValueError("Linux baseline requires the owned Xvfb wrapper; no headless fallback")
        summary.update(source_commit=source, source_tree=git(root, "rev-parse", source + "^{tree}"),
                       driver_source_commit=driver_source, driver_inputs=committed_driver_inputs(driver_source, wrapper))
        record = verify_runtime(root, source, runtime, platform)
        engine_record = verify_engine(engine, platform)
        if subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip() != engine_record["version"]:
            raise ValueError("Actual engine version differs from the pinned archive")
        rapier_path = "godot/addons/godot-rapier2d/runtime-provenance." + platform + ".json"
        rapier_blob = subprocess.check_output(["git", "-C", str(root), "show", source + ":" + rapier_path], timeout=30)
        rapier = json.loads(rapier_blob)
        if (digest(root / rapier["artifact"]) != rapier["sha256"]
                or (root / rapier["artifact"]).stat().st_size != rapier["size"]):
            raise ValueError("Materialized Rapier does not match the committed dependency receipt")
        summary.update(native_runtime=record, rapier=rapier, engine=engine_record,
                       toolchain_drift_allowed=record.get("toolchain_drift_allowed", False))
        project = stage_source(root, source, output)
        shutil.copyfile(runtime / record["runtime_file"], project / "addons/cybersand_native/bin" / record["runtime_file"])
        shutil.copyfile(root / rapier["artifact"], project / Path(rapier["artifact"]).relative_to("godot"))
        summary["staged_source_sha256"] = {p.relative_to(output).as_posix(): digest(p)
            for directory in (project, output / "examples") for p in directory.rglob("*") if p.is_file()}
        common = {k: v for k, v in os.environ.items() if not k.startswith(("CYBERSAND_", "WB_COMBINED_", "PUBPRES_"))}
        common.update(CYBERSAND_SOURCE_REVISION=source, CYBERSAND_MATERIAL_PUBLICATION="blit",
                      CYBERSAND_DIAG_SAME_FRAME_CONTINUATION="0", CYBERSAND_DIAG_MATERIAL_POOL_POLICY="eager",
                      CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS="3", CYBERSAND_MATERIAL_QUEUE_THREAD="safe")
        driver = "opengl3_angle" if platform == "windows" else "opengl3"
        for case in ("import", *CASES):
            folder, profile = output / case, output / (case + "-profile")
            profile.mkdir()
            environment = dict(common, APPDATA=str(profile), LOCALAPPDATA=str(profile), XDG_DATA_HOME=str(profile),
                               XDG_CONFIG_HOME=str(profile), XDG_CACHE_HOME=str(profile),
                               CYBERSAND_TEST_ARTIFACT_DIR=str(folder / "receipts"))
            options = ["--headless", "--editor", "--import"] if case == "import" else [
                "--rendering-method", "gl_compatibility", "--rendering-driver", driver,
                "--render-thread", "safe", "--script", "res://tests/" + case + ".gd"]
            command = [str(engine), "--path", str(project), "--audio-driver", "Dummy", *options]
            if case != "import" and wrapper is not None:
                command = [sys.executable, str(wrapper), *command]
                environment["PUBPRES_DISPLAY_RECEIPT"] = str(folder / "display-owner.json")
            outcome = run(command, environment, folder, 300)
            text = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
            errors = validate_completion(case, text, outcome["returncode"])
            if case != "import" and not re.search(r"^OpenGL(?: ES)? API .+ - Compatibility - Using Device: .+$", text, re.M):
                errors.append("No actual Compatibility renderer/device startup evidence")
            if case == "test_native_pixel_camera":
                try:
                    outcome["camera_evidence"] = camera_evidence(text, project, source, engine_record["sha256"], record["runtime_sha256"])
                except (ValueError, KeyError, TypeError, OSError) as error:
                    errors.append(str(error))
            outcome.update(label=case, pool="eager", render_thread="safe", validation_errors=errors,
                           status="PASS" if outcome["returncode"] == 0 and not outcome["timed_out"] and not errors else "FAIL")
            (folder / "process.json").write_text(json.dumps(outcome, indent=2) + "\n", encoding="utf-8")
            summary["outcomes"].append(outcome)
            (output / "SUMMARY.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
            print(json.dumps({k: outcome[k] for k in ("label", "status", "returncode", "timed_out", "elapsed_seconds")}), flush=True)
            if case == "import" and outcome["status"] != "PASS":
                break
        summary["complete"] = len(summary["outcomes"]) == 4 and all(x["status"] == "PASS" for x in summary["outcomes"])
        summary["status"] = "PASS" if summary["complete"] else "FAIL"
    except Exception as error:
        summary.update(status="FAIL", failure=type(error).__name__ + ": " + str(error))
    finally:
        summary["not_run"] = [name for name in summary["expected_cases"] if name not in {x["label"] for x in summary["outcomes"]}]
        (output / "SUMMARY.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        if project is not None:
            shutil.rmtree(project)
        if (output / "examples").exists():
            shutil.rmtree(output / "examples")
    return 0 if summary["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
