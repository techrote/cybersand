#!/usr/bin/env python3
"""Exact-source Strata Optics Lab graphical campaign and independent reader.

No runtime publication, default activation or acceptance on physical NVIDIA is
performed. The explicit branch workflow executes the actual pinned Linux and
Windows engines; headless results cannot satisfy graphical cases.
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
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import qualify_strata2_workbench as previous
import strata_process_metrics as metrics

require, sha, write_json = previous.require, previous.sha, previous.write_json
SCENES = (*previous.SCENES, "sunward-freight-megastructure", "xeno-resonance-grotto",
          "lunar-terminator-observatory", "optics-readability-challenge")
PROFILES = ("classic", "architectural", "gameplay_clarity", "cinematic_deep_focus", "optical_lens",
            "diorama", "atmospheric_industrial", "noir", "cold_orbital", "alien_bioluminescence", "sunlit_megastructure")
HARNESS = "res://tools/qualify_workbench_strata3.gd"
EXTRA_INPUTS = ("tools/ci/qualify_strata3_workbench.py", ".github/workflows/strata-theatre-003.yml",
                "tools/ci/strata3-qualification-request.json", "tools/build_strata3_gallery.py",
                "tools/strata3_build_showcases.py")
REGRESSIONS = {
    "test_strata_optics_configuration":"STRATA3_CONFIGURATION_RESULT ",
    "test_strata_optics_ui":"STRATA3_UI_RESULT ",
    "test_strata_optical_profiles":"STRATA_OPTICAL_PROFILES ",
    "test_strata_optical_showcases":"STRATA_OPTICAL_SHOWCASES ",
    "test_strata_atmosphere":"STRATA_ATMOSPHERE ",
    "test_strata_optical_renderer":"STRATA003_OPTICAL_RENDERER graphical_required=false",
    "test_workbench_strata_document":"STRATA_DOCUMENT ",
    "test_workbench_strata_layers":"STRATA_LAYER_REGRESSION ",
    "test_strata2_authoring_ui":"STRATA2_UI_RESULT ",
}
HEX64 = re.compile(r"[0-9a-f]{64}")


def identity(allow_delta: bool = False) -> dict:
    result = previous.identity(allow_delta)
    for name in EXTRA_INPUTS:
        path = ROOT / name
        require(path.is_file() and not path.is_symlink(), "Missing optical campaign input: " + name)
        data = path.read_bytes().replace(b"\r\n", b"\n")
        result["source_inputs_sha256"][name] = hashlib.sha256(data).hexdigest()
        try:
            committed = previous.custody.git("show", "HEAD:" + name)
        except subprocess.CalledProcessError:
            committed = b""
        if data != committed and name not in result["local_delta"]:
            result["local_delta"].append(name)
    result["local_delta"].sort()
    require(allow_delta or not result["local_delta"], "Commit all optical campaign inputs before execution")
    return result


def safe_relative(value: str) -> Path:
    require(isinstance(value, str) and value and "\\" not in value,
            "Empty or platform-dependent evidence path")
    path = Path(value)
    require(not path.is_absolute() and ".." not in path.parts and ":" not in value,
            "Unsafe evidence path")
    return path


def evidence_files(folder: Path) -> dict:
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p != folder / "campaign.json" and "userdata" not in p.parts}


def validate_result(result: dict, scene: str, phase: str, source: str) -> None:
    require(result.get("schema") == "strata3-workbench-execution-v1"
            and result.get("completed") is True and result.get("failures") == []
            and type(result.get("checks")) is int and result["checks"] > 0,
            "Incomplete or failing actual optics execution")
    require(result.get("scene") == scene and result.get("phase") == phase
            and result.get("source_revision") == source, "Optics execution source/case identity mismatch")
    require(result.get("ordinary_workbench") is True
            and result.get("diagnostic_headless") is False
            and result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility",
            "Actual ordinary graphical Workbench is required")
    require(type(result.get("process_id")) is int and result["process_id"] > 0,
            "Missing actual engine process identity")
    if phase != "progression":
        require(result.get("admission_target_ms") == 45000,
                "Original scene admission target changed")
        elapsed = result.get("admission_elapsed_ms")
        require(type(elapsed) in (int, float) and math.isfinite(elapsed) and elapsed >= 0
                and result.get("admission_target_met") is (elapsed <= 45000),
                "Admission result does not retain the original timing criterion")
    if phase == "install":
        captures = result.get("profile_captures", [])
        require(len(captures) == len(PROFILES) and {row.get("profile") for row in captures} == set(PROFILES),
                "Matched profile comparison coverage is incomplete or duplicated")
        for capture in captures:
            safe_relative(capture.get("filename"))
            require(capture["filename"].endswith(".png"), "Profile evidence must be an actual PNG capture")
            serialized = capture.get("configuration_json", "")
            require(isinstance(serialized, str) and serialized
                    and hashlib.sha256(serialized.encode()).hexdigest() == capture.get("configuration_sha256")
                    and json.loads(serialized) == capture.get("configuration"),
                    "Optical configuration lacks exact serialized custody")
            require(capture["configuration"].get("profile") == capture["profile"],
                    "Profile label differs from actual configured profile")
        camera = captures[0].get("camera")
        require(isinstance(camera, dict) and camera and all(row.get("camera") == camera for row in captures),
                "Profile captures do not share the same ordinary camera")


def verify_campaign(folder: Path, expected: dict | None = None, *, full: bool = True) -> dict:
    folder = folder.resolve(strict=True)
    report = json.loads((folder / "campaign.json").read_text(encoding="utf-8"))
    require(report.get("schema") == "strata3-workbench-campaign-v1" and report.get("status") == "passed"
            and report.get("completed") is True and report.get("input_custody") == "passed",
            "Incomplete or failing source-bound optical campaign")
    source = report.get("source_identity", {})
    require(source and source.get("local_delta") == [] and (expected is None or source == expected),
            "Optical campaign source differs or contains a local delta")
    platform = report.get("platform")
    engine = report.get("godot", {})
    require(platform in previous.GODOT_SHA256 and engine.get("sha256") == previous.GODOT_SHA256[platform]
            and engine.get("version") == previous.custody.windows.GODOT_VERSION,
            "Optical campaign engine differs from the official pinned runtime")
    require(report.get("runtime") == previous.retained_runtime_manifest(platform),
            "Optical campaign native/Rapier runtime differs from source-bound retained inputs")
    require(not full or report.get("suite") == "full", "Full optical corpus required for owner packaging")
    ledger = report.get("files_sha256", {})
    require(isinstance(ledger, dict) and ledger and ledger == evidence_files(folder),
            "Optical evidence inventory has changed, omitted or extra files")
    for name in ledger:
        path = folder / safe_relative(name)
        require(not path.is_symlink(), "Linked evidence is not admitted")
    cases = report.get("cases", [])
    require(cases and len({row.get("label") for row in cases}) == len(cases), "Empty or duplicate optical cases")
    expected_labels = {"import", *("regressions/" + name for name in REGRESSIONS)}
    selected = SCENES if full else report.get("selected_scenes", [])
    expected_labels.update(scene + "/" + phase for scene in selected for phase in ("install", "reopen"))
    if report.get("suite") == "full": expected_labels.add("optics-readability-challenge/progression")
    require({row["label"] for row in cases} == expected_labels, "Optical process coverage differs from admitted suite")
    for case in cases:
        directory = folder / safe_relative(case["output_dir"])
        process = json.loads((directory / "process.json").read_text(encoding="utf-8"))
        require(case.get("process") == process and process.get("status") == "passed"
                and case.get("exit_code") == process.get("exit_code") == 0,
                "Original optical process does not match the successful case")
        log = directory / "process.log"
        text = log.read_text(encoding="utf-8")
        require(sha(log) == process.get("log_sha256") and not previous.custody.ERRORS.search(text)
                and "Godot Engine v" + engine["version"] in text,
                "Original optical process log differs, lacks engine identity or contains errors")
        if case["phase"] == "regression":
            require(REGRESSIONS[case["label"].split("/")[-1]] in text,
                    "Required optical regression completion marker is missing")
        elif case["phase"] in ("install", "reopen", "progression"):
            result_path = folder / safe_relative(case["result_path"])
            result = json.loads(result_path.read_text(encoding="utf-8"))
            require(result == case.get("result") and sha(result_path) == case.get("report_sha256"),
                    "Embedded optical result differs from original report")
            validate_result(result, case["scene"], case["phase"], source["source_commit"])
            require(result["display_server"] in (("Windows",) if platform == "win32" else ("X11", "Wayland")),
                    "Actual graphical display differs from claimed platform")
            if platform == "linux": require(result["process_id"] == process["pid"], "Actual Linux engine PID differs")
            for capture in result.get("profile_captures", []):
                path = directory / safe_relative(capture["filename"])
                require(path.is_file() and path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
                        and path.relative_to(folder).as_posix() in ledger, "Missing original graphical profile capture")
    for scene in selected:
        pair = {row["phase"]: row for row in cases if row["scene"] == scene and row["phase"] in ("install", "reopen")}
        before, after = pair["install"]["result"], pair["reopen"]["result"]
        require(before["process_id"] != after["process_id"], "Fresh reopen reused the previous process")
        require(before.get("plane_native_hashes_before") == before.get("plane_native_hashes_after")
                == after.get("plane_native_hashes_before") == after.get("plane_native_hashes_after")
                and set(before.get("plane_native_hashes_before",{})) == {"play","scripted","effects","background"},
                "Native material planes changed during optical use or fresh reopening")
        for key in ("configuration", "configuration_canonical_json", "sha256"):
            require(key in before.get("saved_optics",{}) and before["saved_optics"][key] == after.get("saved_optics",{}).get(key),
                    "Fresh reopen changed authored optics " + key)
        require(before.get("save", {}).get("sha256") == after.get("save", {}).get("sha256")
                and HEX64.fullmatch(str(before.get("save", {}).get("sha256", ""))),
                "Fresh reopen lost the exact authored save")
    return report


def run_campaign(args) -> int:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    selected = list(SCENES) if args.suite == "full" else ["industrial-underworks"] if args.suite == "smoke" else []
    report = {"schema":"strata3-workbench-campaign-v1", "status":"running", "completed":False,
              "platform":sys.platform,"suite":args.suite,"selected_scenes":selected,"cases":[]}
    source = runtime = project_inputs = assets = None
    try:
        source = identity(args.allow_source_delta)
        runtime = previous.custody.verify_runtime_identity()
        project = args.project.resolve(strict=True)
        project_inputs = previous.custody.project_identity(project, source, runtime)
        assets = previous.project_assets_identity(project, source)
        godot = args.godot.resolve(strict=True)
        version = subprocess.check_output([str(godot),"--version"],text=True,timeout=30).strip()
        require(sys.platform in previous.GODOT_SHA256 and sha(godot) == previous.GODOT_SHA256[sys.platform]
                and version == previous.custody.windows.GODOT_VERSION, "Exact official Godot pin required")
        report.update(source_identity=source,runtime=runtime,
                      godot={"path":str(godot),"version":version,"sha256":sha(godot)},
                      project={"path":str(project),"inputs_sha256":project_inputs,"assets_sha256":assets})
        base = [str(godot),"--audio-driver","Dummy","--rendering-method","gl_compatibility",
                "--rendering-driver","opengl3","--path",str(project)]

        def run(label: str, flags: list[str], env: dict, phase: str, scene: str = "") -> dict:
            location = output / label
            row = {"label":label,"scene":scene,"phase":phase,"output_dir":label,"result_path":""}
            report["cases"].append(row)
            timeout = 1800 if phase == "progression" else 600
            # One bounded 15-sample progression process owns fresh scene
            # admission between samples. Preserve the same0.5s observer cadence.
            metrics.MAX_SAMPLES = 3603 if phase == "progression" else 1203
            process = metrics.execute(base + flags,location,env,timeout)
            row.update(process=process,exit_code=process["exit_code"])
            if phase in ("install","reopen","progression") and (location / "result.json").is_file():
                result = json.loads((location / "result.json").read_text(encoding="utf-8"))
                row.update(result=result,result_path=label+"/result.json",report_sha256=sha(location/"result.json"))
            write_json(output/"campaign.json",report)
            require(process["status"] == "passed", process.get("error","Optical process failed"))
            if phase == "regression":
                marker = REGRESSIONS[label.split("/")[-1]]
                require(marker in (location/"process.log").read_text(encoding="utf-8"), "Missing actual regression marker " + marker)
            if phase in ("install","reopen","progression"):
                require("result" in row, "Actual optical process did not write its report")
                validate_result(row["result"],scene,phase,source["source_commit"])
            print("STRATA3_CASE", label, process["seconds"], flush=True)
            return row

        env = previous.custody.case_environment(output / "userdata" / "bootstrap")
        env["CYBERSAND_SOURCE_REVISION"] = source["source_commit"]
        run("import",["--headless","--editor","--quit"],env,"import")
        for name in REGRESSIONS:
            label = "regressions/"+name
            test_env = previous.custody.case_environment(output/"userdata"/name)
            test_env.update(CYBERSAND_SOURCE_REVISION=source["source_commit"],STRATA3_TEST_ISOLATED_USERDATA="1")
            flags = ["--script","res://tests/"+name+".gd"]
            if name == "test_strata_optical_renderer": flags += ["--","--output="+str(output/label)]
            run(label,flags,test_env,"regression")
        for scene in selected:
            env = previous.custody.case_environment(output/"userdata"/scene)
            env.update(CYBERSAND_SOURCE_REVISION=source["source_commit"],STRATA_SCENE=scene)
            for phase in ("install","reopen"):
                label = scene+"/"+phase
                phase_env = dict(env,STRATA_PHASE=phase,STRATA_EVIDENCE=str(output/label),STRATA_REPORT=str(output/label/"result.json"))
                run(label,["--script",HARNESS],phase_env,phase,scene)
        if args.suite == "full":
            scene = "optics-readability-challenge"
            label = scene+"/progression"
            env = previous.custody.case_environment(output/"userdata"/"progression")
            env.update(CYBERSAND_SOURCE_REVISION=source["source_commit"],STRATA_SCENE=scene,STRATA_PHASE="progression",
                       STRATA_EVIDENCE=str(output/label),STRATA_REPORT=str(output/label/"result.json"))
            run(label,["--script",HARNESS],env,"progression",scene)
        report["status"] = "passed"
    except Exception as error:
        report.update(status="failed",error=str(error))
        print("STRATA3_FAILED", str(error), file=sys.stderr, flush=True)
    finally:
        if source is not None:
            try:
                require(identity(args.allow_source_delta) == source,"Optical source changed during campaign")
                require(previous.custody.verify_runtime_identity() == runtime,"Runtime changed during optical campaign")
                if project_inputs is not None:
                    require(previous.custody.project_identity(project,source,runtime) == project_inputs,"Loaded optical project changed")
                    require(previous.project_assets_identity(project,source) == assets,"Loaded source assets changed")
                report["input_custody"] = "passed"
            except Exception as error:
                report.update(status="failed",input_custody="failed",custody_error=str(error))
        report.update(completed=True,elapsed_seconds=round(time.monotonic()-started,3))
        report["files_sha256"] = evidence_files(output)
        write_json(output/"campaign.json",report)
    if report["status"] == "passed":
        verify_campaign(output,source,full=args.suite == "full")
    print(json.dumps({"status":report["status"],"source":source.get("source_commit") if source else None,"platform":sys.platform}))
    return int(report["status"] != "passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",type=Path)
    parser.add_argument("--project",type=Path,default=ROOT/"godot")
    parser.add_argument("--output",type=Path)
    parser.add_argument("--suite",choices=("shader","smoke","full"),default="full")
    parser.add_argument("--allow-source-delta",action="store_true")
    parser.add_argument("--verify",type=Path)
    parser.add_argument("--request",type=Path)
    args = parser.parse_args()
    if args.request:
        request = json.loads(args.request.read_text(encoding="utf-8"))
        require(set(request) == {"version","sequence","suite","purpose"}
                and request["version"] == 1 and type(request["sequence"]) is int and request["sequence"] > 0
                and request["suite"] in ("shader","smoke","full")
                and isinstance(request["purpose"],str) and request["purpose"], "Invalid explicit optical qualification request")
        args.suite = request["suite"]
    if args.verify:
        verify_campaign(args.verify,identity(),full=args.suite == "full")
        print("STRATA3_VERIFIED",args.verify)
        return 0
    require(args.godot is not None and args.output is not None,"Engine and new output directory are required")
    return run_campaign(args)


if __name__ == "__main__":
    raise SystemExit(main())
