#!/usr/bin/env python3
"""Non-publishing, exact-source Linux/Windows authored-workflow qualification.

Uses the existing engine pins, runtime provenance and regression process monitor.
This does not replace the owner-controlled published-runtime or physical gate.
"""
from __future__ import annotations

import argparse
from dataclasses import replace
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import zipfile

import check_repository
import execution_policy
import run_godot_regressions as regression
import run_windows_godot_regressions as windows

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args],
                                   timeout=execution_policy.watchdog_seconds("operation_seconds"))


def inputs():
    paths = git("ls-files", "-z").decode().split("\0")
    # The accepted runner permits only newline normalization of four known
    # Rapier import descriptors; preserve the same narrow rule here.
    return {path: windows.content_digest(ROOT, path) for path in paths
            if path and not path.startswith("godot/.godot/")}


def prepare(archive):
    require(sys.platform in ("linux", "win32"), "Actual Linux or Windows required")
    if sys.platform == "win32":
        return windows.prepare_godot(archive)
    lock = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text())
    data = archive.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    require(len(data) == lock["editor"]["size"] and digest == lock["editor"]["sha256"],
            "Official Linux archive differs from the unchanged dependency lock")
    destination = Path(tempfile.mkdtemp(prefix="ultima-engine-", dir=archive.parent))
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, "Official Linux archive CRC failure")
        bundle.extractall(destination)
    engine = destination / "Godot_v4.7-stable_linux.x86_64"
    engine.chmod(0o755)
    version = subprocess.check_output([str(engine), "--version"], text=True,
                                     timeout=execution_policy.watchdog_seconds("operation_seconds")).strip()
    require(version == lock["godot_version"], "Extracted engine version mismatch")
    return engine, {"version":version, "archive_sha256":digest, "archive_size":len(data),
                    "runtime_sha256":hashlib.sha256(engine.read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive", type=Path, required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {"schema":"ultima-nonpublishing-qualification-v2", "status":"failed", "completed":False,
              "platform":platform.platform(), "host":sys.platform, "cases":[], "errors":[],
              "run_id":os.getenv("GITHUB_RUN_ID"), "run_attempt":os.getenv("GITHUB_RUN_ATTEMPT"),
              "limits":["No runtime publication or export", "No physical NVIDIA acceptance",
                        "No power-loss durability claim", "Headless functional execution; GUI evidence is separate"]}
    try:
        source = git("rev-parse", "HEAD").decode().strip()
        require(source == args.expected_source_sha, "Checkout differs from requested source")
        # A matching revision string does not authenticate dirty input bytes.
        # The committed Godot import caches are the existing explicit exception;
        # the engine regenerates them from the authenticated source below.
        git("diff", "--exit-code", "HEAD", "--", ".", ":!godot/.godot")
        report.update(source_head=source, source_tree=git("rev-parse", "HEAD^{tree}").decode().strip())
        provenance = check_repository.check(ROOT, require_materialized=True)
        write(output / "materialized-provenance.json", provenance)
        require(provenance["status"] == "passed", "Materialized source/dependency check failed; read materialized-provenance.json")
        before = inputs()
        write(output / "source-inputs.json", before)
        report["source_inputs_sha256"] = hashlib.sha256((output / "source-inputs.json").read_bytes()).hexdigest()
        engine, report["engine"] = prepare(args.godot_archive.resolve())
        profile = Path(tempfile.mkdtemp(prefix="ultima-profile-", dir=output))
        env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile),
                   GODOT_SILENCE_ROOT_WARNING="1", CYBERSAND_SOURCE_REVISION=source,
                   CYBERSAND_WORKBENCH_TEST_NAME="ultima-ci-canvas")
        import_case = regression.Case("import", ("--editor", "--quit"),
                                      execution_policy.watchdog_seconds("godot_import_seconds"), 3.0)
        record, failed = regression.run_case(str(engine), import_case, output, "preflight", env=env)
        report["cases"].append(record)
        require(not failed, "Source-matched Godot import failed")
        fault = subprocess.run([sys.executable, str(ROOT / "tools/ci/run_workbench_save_qualification.py"),
                                "--godot", str(engine), "--project", str(ROOT / "godot"),
                                "--evidence", str(output / "persistence")], env=env, cwd=ROOT,
                               timeout=execution_policy.watchdog_seconds("complex_fixture_seconds"))
        require(fault.returncode == 0, "Persistence fault matrix failed")
        report["persistence"] = json.loads((output / "persistence/report.json").read_text())
        capture = subprocess.run([sys.executable, str(ROOT / "tools/ci/run_microscenario_capture_qualification.py"),
                                  "--godot", str(engine), "--project", str(ROOT / "godot"),
                                  "--evidence", str(output / "microscenario-capture")], env=env, cwd=ROOT,
                                 timeout=execution_policy.watchdog_seconds("complex_fixture_seconds"))
        require(capture.returncode == 0, "MicroScenario capture fault matrix failed")
        report["microscenario_capture"] = json.loads((output / "microscenario-capture/report.json").read_text())
        recorder = subprocess.run([sys.executable, str(ROOT / "tools/ci/run_recorder_storage_qualification.py"),
                                   "--godot", str(engine), "--project", str(ROOT / "godot"),
                                   "--evidence", str(output / "recorder-storage")], env=env, cwd=ROOT,
                                  timeout=execution_policy.watchdog_seconds("complex_fixture_seconds"))
        require(recorder.returncode == 0, "Recorder storage fault matrix failed")
        report["recorder_storage"] = json.loads((output / "recorder-storage/report.json").read_text())
        for key, runner, directory in (
                ("profile_save", "run_profile_save_qualification.py", "profile-save"),
                ("art_storage", "run_art_storage_qualification.py", "art-storage"),
                ("diagnostic_storage", "run_diagnostic_storage_qualification.py", "diagnostic-storage"),
                ("tower_observation", "run_tower_observation_qualification.py", "tower-observation")):
            result = subprocess.run([sys.executable, str(ROOT / "tools/ci" / runner),
                                     "--godot", str(engine), "--project", str(ROOT / "godot"),
                                     "--evidence", str(output / directory)], env=env, cwd=ROOT,
                                    timeout=execution_policy.watchdog_seconds("complex_fixture_seconds"))
            require(result.returncode == 0, key + " fault matrix failed")
            report[key] = json.loads((output / directory / "report.json").read_text())
        available = {case.name:case for case in regression.discover_cases()}
        plan = [
            ("test_gameplay_recorder", {}),
            ("test_goblin_contract", {}),
            ("test_goblin_policies", {}),
            ("test_physics_instrumentation", {}),
            ("test_thunderbowl_arena", {}),
            ("test_thunderbowl_controllers", {}),
            ("test_worldgen_workbench", {}),
            ("test_material_lab_experiment", {}),
            ("test_transport_profiles", {}),
            ("test_water_feel_controller", {}),
            ("test_art_storage_integrity", {}),
            ("test_art_traffic_integrity", {}),
            ("test_art_traffic_panel_safety", {}),
            ("test_art_session_log", {}),
            ("test_art_panel_ui", {}),
            ("test_art_history_receipt_identity", {}),
            ("test_workbench_material_baseline", {}),
            ("test_architectural_generator_ui", {}),
            ("test_workbench_generator_discovery", {}),
            ("test_paint_editor_history", {}),
            ("test_paint_editor_history", {"CYBERSAND_PAINT_HISTORY_REOPEN":"1"}),
            ("test_workbench_canvas", {}),
            ("test_workbench_canvas", {"CYBERSAND_WORKBENCH_REOPEN":"1"}),
            ("test_explore001_generated_workbench", {}),
            ("test_explore001_generated_workbench", {"CYBERSAND_EXPLORE_REOPEN":"1"}),
        ]
        for name, extra in plan:
            require(name in available, "Required workflow regression is missing: " + name)
            case = available[name]
            if extra:
                case = replace(case, name=name + "-reopen")
            record, failed = regression.run_case(str(engine), case, output, "authored-workflow", env=env | extra)
            report["cases"].append(record)
            require(not failed, "Workflow failed: " + case.name)
        after = inputs()
        report["changed_inputs"] = sorted(path for path in set(before) | set(after) if before.get(path) != after.get(path))
        require(not report["changed_inputs"], "Qualification changed tracked source/runtime bytes")
        report.update(status="passed", completed=True)
        return 0
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as error:
        report["errors"].append(str(error))
        print(str(error), file=sys.stderr)
        return 1
    finally:
        write(output / "qualification.json", report)


if __name__ == "__main__":
    raise SystemExit(main())
