#!/usr/bin/env python3
"""Source-bound AMBIENT-001 qualification using unchanged verified runtimes.

Runs real Godot processes sequentially, preserves failures, and labels local
source deltas explicitly. A successful exit is never physical Windows playfeel
acceptance. The package builder requires the complete committed-source campaign.
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
import time

from qualify_workbench_landscapes import (
    ROOT, case_environment, execute, git, project_identity, require, sha,
    source_identity as host_source_identity, verify_runtime_identity, write_json,
)

sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy

GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
# Linux member independently decoded from the archive pinned in
# third_party/godot-runtime.lock.json; Windows pins are shared with the accepted
# landscape evaluator and the verified official Windows archive helper.
GODOT_LINUX_SHA256 = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
GODOT_WINDOWS_CONSOLE_SHA256 = "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c"
GODOT_WINDOWS_GUI_SHA256 = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
OWN_INPUTS = (
    "tools/qualify_ambient.py", "tools/package_ambient_evaluator.py",
    "tools/ci/test_ambient_delivery.py",
    ".github/workflows/ambient-001-qualification.yml",
    "tools/fixtures/ambient-001-qualification-request.json",
    "godot/data/ambient/profiles.json",
    "godot/examples/workbench/ambient-oil-water.json",
    "godot/examples/workbench/ambient-ledge-walkway.json",
    "godot/examples/workbench/ambient-industrial-yard.json",
    "godot/examples/workbench/ambient-settlement.json",
    "godot/examples/workbench/ambient-flight.json",
)
CASES = (
    ("engine", "test_ambient_engine", ()),
    ("independent", "test_ambient_independent", ()),
    ("perception", "test_ambient_perception", ()),
    ("ledge_geometry", "test_ambient_ledge_geometry", ()),
    ("clock", "test_ambient_clock", ()),
    ("authoring_save", "test_ambient_authoring", ("--save", "ambient-qualified")),
    ("authoring_reopen", "test_ambient_authoring", ("--reopen", "ambient-qualified")),
    ("editor", "test_ambient_profile_editor", ()),
    ("native_motion", "test_ambient_native_motion", ()),
    ("personalities", "test_ambient_personalities_native", ()),
    ("workbench", "test_ambient_workbench", ()),
    ("examples", "test_ambient_examples_native", ()),
    ("legacy_catalog", "test_workbench_actor_catalog", ()),
    ("legacy_composition", "test_workbench_actor_composition", ()),
    ("legacy_session", "test_workbench_actor_composition_session", ()),
    ("legacy_physical", "test_physical_actor_session", ()),
)
REPORTS = {
    "perception": "CYBERSAND_AMBIENT_PERCEPTION_REPORT",
    "editor": "CYBERSAND_AMBIENT_EDITOR_REPORT",
    "native_motion": "CYBERSAND_AMBIENT_MOTION_REPORT",
    "personalities": "CYBERSAND_AMBIENT_PERSONALITIES_REPORT",
    "workbench": "CYBERSAND_AMBIENT_WORKBENCH_REPORT",
    "examples": "CYBERSAND_AMBIENT_EXAMPLES_REPORT",
}
TERMINALS = {
    "engine": "AMBIENT_ENGINE_RESULT", "independent": "AMBIENT_INDEPENDENT",
    "perception": "AMBIENT_PERCEPTION", "ledge_geometry": "AMBIENT_LEDGE_GEOMETRY",
    "clock": "AMBIENT_CLOCK", "authoring_save": "AMBIENT_AUTHORING",
    "authoring_reopen": "AMBIENT_AUTHORING", "editor": "AMBIENT_EDITOR",
    "native_motion": "AMBIENT_NATIVE_MOTION", "personalities": "AMBIENT_PERSONALITIES",
    "legacy_composition": "WB_ACTOR_COMPOSE",
}
TEXT_TERMINALS = {
    "workbench": r"^AMBIENT_WORKBENCH checks=(\d+) failures=(\d+) phases=\d+$",
    "examples": r"^AMBIENT_EXAMPLES checks=(\d+) failures=(\d+) cases=5$",
    "legacy_catalog": r"^WB_ACTOR_CATALOG checks=(\d+) failures=(\d+) models=\d+ prepared_workshop_bodies=\d+$",
    "legacy_session": r"^Workbench actor composition session: (\d+) checks, (\d+) failures$",
    "legacy_physical": r"^Physical actor session: (\d+) assertions, (\d+) failures$",
}
EXAMPLES = {"ambient-oil-water", "ambient-ledge-walkway", "ambient-industrial-yard",
            "ambient-settlement", "ambient-flight"}
CAPTURES = {name + suffix + ".png" for name in EXAMPLES for suffix in ("-authored", "-playing")} | {
    "ambient-oil-water-overlay.png", "ambient-behaviour-profile-editor.png"}


def source_identity(allow_delta: bool = False) -> dict:
    identity = host_source_identity(allow_delta=True)
    for relative in OWN_INPUTS:
        path = ROOT / relative
        require(path.is_file() and not path.is_symlink(), "Missing qualification input: " + relative)
        data = path.read_bytes().replace(b"\r\n", b"\n")
        identity["source_inputs_sha256"][relative] = hashlib.sha256(data).hexdigest()
        try:
            committed = git("show", "HEAD:" + relative).replace(b"\r\n", b"\n")
        except subprocess.CalledProcessError:
            committed = None
        if committed != data:
            identity["local_delta"].append(relative)
    identity["local_delta"] = sorted(set(identity["local_delta"]))
    require(allow_delta or not identity["local_delta"],
            "Commit all execution inputs before qualification: " + ", ".join(identity["local_delta"]))
    return identity


def engine_identity(binary: Path) -> dict:
    expected = GODOT_WINDOWS_CONSOLE_SHA256 if sys.platform == "win32" else GODOT_LINUX_SHA256
    require(sys.platform == "win32" or sys.platform.startswith("linux"), "Unsupported execution platform")
    require(sha(binary) == expected, "Godot executable differs from the authenticated official pin")
    identity = {"binary": str(binary), "sha256": expected}
    if sys.platform == "win32":
        gui = binary.with_name("Godot_v4.7-stable_win64.exe")
        require(gui.is_file() and sha(gui) == GODOT_WINDOWS_GUI_SHA256,
                "Windows console wrapper's actual engine differs from the official pin")
        identity["gui_sha256"] = GODOT_WINDOWS_GUI_SHA256
    return identity


def completion(name: str, log: Path) -> dict:
    text = re.sub(r"\x1b\[[0-9;]*m", "", log.read_text(encoding="utf-8", errors="replace"))
    require("SKIP WB_ACTOR_COMPOSE" not in text, "Existing Workbench regression skipped its real owner")
    if name in TERMINALS:
        lines = [line[len(TERMINALS[name])+1:] for line in text.splitlines() if line.startswith(TERMINALS[name] + " ")]
        require(len(lines) == 1, "Missing or repeated terminal result for " + name)
        result = json.loads(lines[0])
        checks, failures = result.get("checks", 0), result.get("failures")
    elif name in TEXT_TERMINALS:
        matches = re.findall(TEXT_TERMINALS[name], text, flags=re.MULTILINE)
        require(len(matches) == 1, "Missing or repeated terminal result for " + name)
        checks, failures = map(int, matches[0])
    else:
        raise RuntimeError("Unknown completion contract: " + name)
    require(type(checks) is int and checks > 0 and (failures == [] or type(failures) is int and failures == 0),
            "Terminal result has no successful completed assertions: " + name)
    return {"checks": checks, "failures": 0}


def validate_capture_report(folder: Path, result: dict) -> dict:
    require(result.get("failures") == [] and result.get("display") not in (None, "", "headless")
            and result.get("renderer"), "Capture requires a successful real renderer")
    phases = result.get("phases", [])
    require(len(phases) == len(EXAMPLES) and {row.get("example") for row in phases} == EXAMPLES
            and all(row.get("passed") is True and row.get("physical_ticks", 0) >= 120
                    and row.get("native_ticks", 0) >= 119 for row in phases),
            "Capture must progress every actual ordinary example exactly once")
    captures = result.get("captures", [])
    require(len(captures) == len(CAPTURES) and {Path(row.get("path", "")).name for row in captures} == CAPTURES,
            "Capture requires all twelve unique example, overlay and editor images")
    images = {}
    for item in captures:
        material = item.get("material_display", {})
        require(all(type(material.get(key)) is int and material[key] >= 0
                    for key in ("generation", "render_serial", "revision")),
                "Captured pixels lack an explicit uploaded material identity")
        displayed = item.get("rendered_actor_frame", {})
        require(type(displayed.get("available")) is bool and bool(displayed.get("mode")),
                "Displayed actor-frame availability must be explicit")
        if displayed["available"]:
            require(displayed.get("world_generation") == material["generation"]
                    and displayed.get("revision") == material["revision"]
                    and type(displayed.get("epoch")) is int and displayed["epoch"] >= 0,
                    "Displayed actor frame is not bound to the uploaded material/owner")
        path = Path(item["path"]).resolve()
        require(path.is_relative_to(folder.resolve()) and path.is_file()
                and path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), "Missing actual captured PNG")
        images[path.name] = sha(path)
    return images


def capture(binary: Path, project: Path, output: Path, identity: dict) -> dict:
    folder = output / "captures"
    environment = case_environment(output / "userdata" / "capture")
    environment["CYBERSAND_SOURCE_REVISION"] = identity["source_commit"]
    environment["CYBERSAND_AMBIENT_CAPTURE"] = str(folder)
    # Hosted graphical workers need no audio device. Select the accepted silent
    # backend explicitly instead of allowing an audio error and fallback, while
    # keeping the strict process-error guard and actual renderer requirements.
    command = [str(binary), "--audio-driver", "Dummy", "--path", str(project),
               "--rendering-method", "gl_compatibility"]
    command += ["--rendering-driver", "opengl3_angle"] if sys.platform == "win32" else ["--display-driver", "x11"]
    command += ["--script", "res://tests/capture_ambient_examples.gd"]
    record = execute(command, output / "graphical", environment, execution_policy.complex_process_seconds())
    record["process_sha256"] = sha(output / "graphical/process.json")
    require(record["status"] == "passed", "Graphical capture failed; original process output retained")
    detail = folder / "capture-report.json"
    result = json.loads(detail.read_text(encoding="utf-8"))
    expected_engine = GODOT_WINDOWS_GUI_SHA256 if sys.platform == "win32" else GODOT_LINUX_SHA256
    expected_driver = "opengl3_angle" if sys.platform == "win32" else "opengl3"
    require(result.get("source_revision") == identity["source_commit"] and result.get("engine_sha256") == expected_engine,
            "Actual graphical process source or executing engine differs from the qualified input")
    require(result.get("rendering_method") == "gl_compatibility" and result.get("rendering_driver") == expected_driver,
            "Actual graphical renderer differs from the requested supported backend")
    images = validate_capture_report(folder, result)
    return {"process": record, "report_sha256": sha(detail), "images_sha256": images,
            "display": result["display"], "renderer": result["renderer"],
            "rendering_method": result["rendering_method"], "rendering_driver": result["rendering_driver"],
            "renderer_vendor": result.get("renderer_vendor", ""), "owner_playfeel_accepted": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--case", action="append", choices=[row[0] for row in CASES], dest="selected")
    parser.add_argument("--capture", action="store_true", help="Separate actual graphical evidence; no headless substitute")
    parser.add_argument("--allow-source-delta", action="store_true", help="Development only; never packageable")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = args.project.resolve(strict=True)
    binary = args.godot.resolve(strict=True)
    report = {"schema_version": 1, "kind": "ambient-001-qualification", "status": "running",
              "platform": sys.platform, "headless": not args.capture, "cases": [], "input_custody": "pending",
              "limits": ["No physical Windows/NVIDIA playfeel acceptance",
                         "No cross-platform Rapier trajectory bit-determinism claim",
                         "Timing values are observations on this host, not release thresholds"]}
    start = time.monotonic()
    try:
        identity = source_identity(args.allow_source_delta)
        report.update(identity)
        runtime = verify_runtime_identity()
        report["runtime"] = runtime
        report["project_inputs_sha256"] = project_identity(project, identity, runtime)
        engine = engine_identity(binary)
        version = subprocess.check_output([str(binary), "--version"], text=True,
                                          timeout=execution_policy.watchdog_seconds("operation_seconds")).strip()
        require(version == GODOT_VERSION, "Godot differs from the accepted pin: " + version)
        report["godot"] = {"version": version, **engine}
        report["execution_policy"] = execution_policy.identity()
        selected = [row for row in CASES if not args.selected or row[0] in args.selected]
        require(not args.capture or not args.selected, "Graphical capture is a separate complete example pass")
        require(not args.selected or "authoring_reopen" not in args.selected or "authoring_save" in args.selected,
                "A selected reopen requires its fresh save in the same campaign")
        report["complete_campaign"] = not args.capture and len(selected) == len(CASES)
        write_json(output / "qualification.json", report)
        import_record = execute([str(binary), "--headless", "--path", str(project), "--editor", "--quit"],
                                output / "import", case_environment(output / "userdata" / "import"),
                                execution_policy.watchdog_seconds("godot_import_seconds"))
        import_record["process_sha256"] = sha(output / "import/process.json")
        report["import"] = import_record
        require(import_record["status"] == "passed", "Godot import failed")
        if args.capture:
            report["graphical"] = capture(binary, project, output, identity)
        for name, script, arguments in ([] if args.capture else selected):
            environment = case_environment(output / "userdata" / ("authoring" if name.startswith("authoring_") else name))
            environment["CYBERSAND_SOURCE_REVISION"] = identity["source_commit"]
            if name in REPORTS:
                environment[REPORTS[name]] = str(output / name / "report.json")
            command = [str(binary), "--headless", "--path", str(project),
                       "--script", f"res://tests/{script}.gd", "--", "--ci", *arguments]
            print("AMBIENT qualification:", name, flush=True)
            record = execute(command, output / name, environment,
                             execution_policy.complex_process_seconds())
            record["process_sha256"] = sha(output / name / "process.json")
            record.update({"name": name, "script": script})
            if record["status"] == "passed":
                record["completion"] = completion(name, output / name / "process.log")
            detail = output / name / "report.json"
            if name in REPORTS and record["status"] == "passed":
                require(detail.is_file(), "Missing completed report for " + name)
                result = json.loads(detail.read_text(encoding="utf-8"))
                require(result.get("checks", 0) > 0 and result.get("failures") in ([], 0),
                        "Incomplete or failing result for " + name)
                record["report_sha256"] = sha(detail)
                record["checks"] = result["checks"]
            report["cases"].append(record)
            write_json(output / "qualification.json", report)
            require(record["status"] == "passed",
                    "Case failed; original process receipts retained and later cases not started: " + name)
        require(all(row["status"] == "passed" for row in report["cases"]),
                "One or more cases failed; original process logs and reports retained")
        after = source_identity(args.allow_source_delta)
        require(after == identity, "Execution source changed during the campaign")
        require(project_identity(project, identity, runtime) == report["project_inputs_sha256"],
                "Loaded project changed during the campaign")
        require(verify_runtime_identity() == runtime and engine_identity(binary) == engine,
                "A retained runtime or engine changed during the campaign")
        report["input_custody"] = "passed"
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["input_custody"] = "failed_or_incomplete"
        report["error"] = str(error)
        print(str(error), file=sys.stderr, flush=True)
    finally:
        report["elapsed_seconds"] = round(time.monotonic() - start, 3)
        write_json(output / "qualification.json", report)
    print(output / "qualification.json", flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
