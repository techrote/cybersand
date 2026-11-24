#!/usr/bin/env python3
"""Four exact font controls followed by repaired-engine ordinary Main startup."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PureWindowsPath
import re
import shutil
import subprocess
import sys
import uuid

import engine_contract
import payload

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/pubpres003"))
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))
from run_focus import selectors, stage_committed_project, validate_runtime, verify_driver
from run_campaign import copy_project, execute, source_identity

need, digest, file_record = payload.need, payload.digest, payload.file_record
OBSERVER = "tests/pubpres_playability_owner_start.gd"
OVERRIDE = b"[cybersand]\nexperimental_wave_column_tiles=false\npubpres_wave_column_probe=false\n"
FONT_HASHES = {"project.godot": "310b0cee3c4654d90cbc29b5b3e9d539b3c11ba9497ba184e9ffa1eec00ec7b3",
               "font_probe.gd": "9e612d697a70e30a6499a679ac6d1593718e74dd6fd3074bf0bf18ff2078e3ae"}
OWNER_SHA = "0974b8c1511718552cceae43ec539bf751757565a557a3946cfc1fbba3fb3c5f"


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def inventory(folder: Path) -> dict:
    return {path.relative_to(folder).as_posix(): digest(path) for path in sorted(folder.rglob("*")) if path.is_file()}


def registration() -> dict:
    value = json.loads((HERE / "font_registration.json").read_bytes())
    need(value["schema"] == "pubpres-font-engine-registration-v1"
         and value["order"] == [{"engine": role, "render_thread": thread} for role, thread in
                                (("original", "safe"), ("original", "separate"), ("repaired", "safe"), ("repaired", "separate"))]
         and value["fixture_sha256"] == FONT_HASHES and value["font_mode"] == "text"
         and value["font_mipmaps"] is False and value["draws"] == 64 and value["glyph_calls"] == 6016
         and value["framebuffer_size"] == [1024, 640] and value["font_timeout_seconds"] == 60
         and value["import_timeout_seconds"] == 300 and value["startup_timeout_seconds"] == 360
         and value["startup_scene"] == "wave512" and value["startup_order"] == ["safe", "separate"]
         and value["startup_observer"] == "tools/pubpres_final_windows/owner_start.gd"
         and value["startup_observer_sha256"] == OWNER_SHA and value["platform"] == "Windows"
         and value["render_driver"] == "opengl3_angle", "Font/startup experiment differs from registered gates")
    return value


def driver_identity() -> dict:
    identity = verify_driver(ROOT)
    engine = engine_contract.verify_build_inputs(ROOT)
    identity["files_sha256"].update(engine["files_sha256"])
    names = ["tools/ci/restore_workbench_godot.py", "third_party/workbench-godot-evaluation.lock.json",
             "tools/pubpres_final_windows/owner_start.gd"]
    names += ["tools/pubpres_render_probes/projects/font/" + name for name in FONT_HASHES]
    for name in names:
        raw = payload.committed(ROOT, identity["source_commit"], name)
        need((ROOT / name).read_bytes() == raw, "Font/startup driver dependency differs: " + name)
        identity["files_sha256"][name] = hashlib.sha256(raw).hexdigest()
    need(digest(ROOT / "tools/pubpres_final_windows/owner_start.gd") == OWNER_SHA, "Ordinary startup observer changed")
    return identity


def logs(folder: Path) -> str:
    return "\n".join((folder / name).read_text(encoding="utf-8", errors="replace")
                     for name in ("stdout.log", "stderr.log") if (folder / name).is_file())


def process_clean(process: dict, *, zero: bool):
    need(process.get("timed_out") is False and process.get("surviving_children_at_exit") is False
         and process.get("interruption") is None and type(process.get("observed_application_pid")) is int
         and process["observed_application_pid"] > 0 and process.get("wrapper_pid") == process["observed_application_pid"],
         "Process identity, timeout or cleanup failed")
    need(process.get("exit_code") == 0 if zero else type(process.get("exit_code")) is int and process["exit_code"] != 0,
         "Unexpected process outcome")


def graphical_command(engine: str | Path, project: str | Path, thread: str, script: str) -> list[str]:
    need(thread in ("safe", "separate") and script in ("res://font_probe.gd", "res://" + OBSERVER),
         "Unregistered graphical command")
    return [str(engine), "--path", str(project), "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3_angle", "--render-thread", thread,
            "--audio-driver", "Dummy", "--script", script]


def validate_process_command(process: dict, *, source: str, engine: str | Path,
                             project: str | Path, thread: str, script: str):
    need(process.get("source_commit") == source
         and process.get("command") == graphical_command(engine, project, thread, script),
         "Actual process source/executable/project/driver/render-owner/script command differs")


def retained_path(base: str, *parts: str) -> str:
    # Original Windows command paths remain comparable after evidence relocation.
    path = PureWindowsPath(base)
    need(path.is_absolute() and ".." not in path.parts, "Retained launch path is not an absolute Windows path")
    return str(path.joinpath(*parts))


def validate_version(engine: dict, build: dict):
    need(all(engine.get(key) == value for key, value in
             {"major": 4, "minor": 7, "patch": 0, "status": "stable", "hash": build["upstream_commit"],
              "build": build["build_name"]}.items()), "Actual running engine version differs")


def validate_font(data: dict, process: dict, *, source: str, nonce: str, thread: str,
                  build: dict, engine_sha: str):
    process_clean(process, zero=True)
    need(data.get("schema") == "pubpres-isolated-font-probe-v1" and data.get("source_commit") == source
         and data.get("nonce") == nonce and data.get("pid") == process["observed_application_pid"]
         and data.get("engine_sha256") == engine_sha, "Font fixture process/source/engine identity differs")
    validate_version(data.get("engine", {}), build)
    need(data.get("script_sha256") == FONT_HASHES["font_probe.gd"] and data.get("project_sha256") == FONT_HASHES["project.godot"]
         and data.get("native_independent") is True and data.get("loaded_extensions") == []
         and data.get("mode") == "text" and data.get("font_mipmaps") is False and data.get("errors") == []
         and data.get("draws") == 64 and data.get("glyph_calls") == 6016
         and data.get("framebuffer_size") == [1024, 640] and payload.SHA.fullmatch(data.get("framebuffer_sha256", "")),
         "Font work, immutable fixture or framebuffer evidence differs")
    need(data.get("platform") == "Windows" and data.get("display") == "Windows"
         and data.get("driver") == "opengl3_angle" and isinstance(data.get("adapter"), str) and data["adapter"]
         and data.get("requested_thread") == thread and data.get("render_thread_inline") is (thread == "safe"),
         "Font graphical display, adapter or actual render owner differs")


def validate_retained_cowdata_negative(process: dict, text: str, *, receipt_exists: bool, build: dict):
    process_clean(process, zero=False)
    need(not receipt_exists, "Partial or failed receipt is not the registered missing-receipt native crash")
    starts = [line.split("ISOLATED_FONT_PROBE_SCRIPT_STARTED ", 1)[1] for line in text.splitlines()
              if line.startswith("ISOLATED_FONT_PROBE_SCRIPT_STARTED ")]
    need(len(starts) == 1, "Negative did not reach the actual isolated font script")
    start = json.loads(starts[0])
    need(start.get("pid") == process["observed_application_pid"], "Negative process identity differs")
    validate_version(start.get("engine", {}), build)
    plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    primary_errors = [line.strip() for line in plain.splitlines() if re.match(r"^\s*(?:ERROR:|FATAL:)", line)]
    allowed_error = re.compile(r"(?:ERROR:\s*(?:FATAL:\s*)?|FATAL:\s*)Index p_index = 0 is out of bounds \(size\(\) = 0\)\.")
    need(primary_errors and all(allowed_error.fullmatch(line) for line in primary_errors),
         "Historical negative contains an unrelated primary ERROR/FATAL diagnostic")
    need(re.search(r"CowData<unsigned char>::get", text) and re.search(r"p_index\s*=\s*0", text)
         and re.search(r"size\(\)\s*=\s*0", text) and "cowdata.h:197" in text
         and not any(marker in text for marker in ("Error initializing GLAD", "MakeCurrent failed", "SCRIPT ERROR:",
                                                  "Parse Error:", "Failed to load script", "Failed loading resource:")),
         "Old Separate did not reproduce the specifically registered font/CowData negative")


def font_arm(role: str, thread: str, engine: Path, build: dict, source: str, output: Path) -> dict:
    label = role + "-" + thread
    folder, project = output / "font" / label, output / "font-projects" / label
    project.mkdir(parents=True)
    for name, expected in FONT_HASHES.items():
        original = ROOT / "tools/pubpres_render_probes/projects/font" / name
        need(digest(original) == expected, "Frozen font fixture differs")
        shutil.copyfile(original, project / name)
    nonce, receipt = uuid.uuid4().hex, folder / "receipt.json"
    settings = {"PUBPRES_FONT_PROBE_MODE": "text", "PUBPRES_FONT_PROBE_MIPMAPS": "0",
                "PUBPRES_FONT_PROBE_OUTPUT": str(receipt), "PUBPRES_PROBE_SOURCE": source,
                "PUBPRES_PROBE_NONCE": nonce, "CYBERSAND_MATERIAL_QUEUE_THREAD": thread}
    result = {"engine": role, "render_thread": thread, "passed": False, "admissible_negative": False,
              "nonce": nonce, "settings": settings, "engine_sha256": digest(engine)}
    try:
        failure = None
        try:
            execute(engine, graphical_command(engine, project, thread, "res://font_probe.gd")[1:],
                    folder, source, settings, 60)
        except Exception as error:
            failure = str(error)
        process = json.loads((folder / "process.json").read_bytes())
        result["process"] = process
        validate_process_command(process, source=source, engine=engine, project=project, thread=thread, script="res://font_probe.gd")
        text = logs(folder)
        need(digest(engine) == result["engine_sha256"] and all(digest(project / name) == expected for name, expected in FONT_HASHES.items()),
             "Font source or engine changed during execution")
        if failure is None:
            need("ERROR:" not in text, "Strict font diagnostics failed")
            data = json.loads(receipt.read_bytes())
            validate_font(data, process, source=source, nonce=nonce, thread=thread, build=build, engine_sha=result["engine_sha256"])
            result.update(passed=True, receipt_sha256=digest(receipt), receipt=data)
        else:
            result["failure"] = failure
            need(role == "original" and thread == "separate", "Required repaired/control font arm failed: " + failure)
            validate_retained_cowdata_negative(process, text, receipt_exists=receipt.exists(), build=build)
            result.update(admissible_negative=True, classification="Observed historical font Image/CowData native crash; no gameplay or pass credit")
    except Exception as error:
        result["failure"] = str(error)
    write_json(folder / "qualification.json", result)
    return result


def validate_font_cohort(arms: list[dict]) -> dict:
    expected = [("original", "safe"), ("original", "separate"), ("repaired", "safe"), ("repaired", "separate")]
    need([(arm["engine"], arm["render_thread"]) for arm in arms] == expected, "Font control ordering or completeness differs")
    need(all(arm["passed"] for arm in (arms[0], arms[2], arms[3])), "Original Safe or repaired font control failed")
    need(arms[1]["passed"] or arms[1]["admissible_negative"], "Old Separate failed for an unregistered reason")
    reference = arms[0]["receipt"]
    for arm in arms:
        if arm["passed"]:
            need(arm["receipt"]["framebuffer_sha256"] == reference["framebuffer_sha256"], "Complete font framebuffer bytes differ")
            need(arm["receipt"]["adapter"] == reference["adapter"], "Font arms used different adapters")
    return {"passed": True, "framebuffer_sha256": reference["framebuffer_sha256"],
            "all_font_arms_passed": all(arm["passed"] for arm in arms),
            "retained_negative_observed": arms[1]["admissible_negative"],
            "scope": "Exact finite font pixels only; original Separate native failure is retained, not credited as a pass."}


def prepare_startup(source_root: Path, source: dict, engine: Path, output: Path, rapier_override: Path | None) -> tuple[Path, dict]:
    template = stage_committed_project(source_root, source["source_commit"], output)
    recipes = template.parent / "examples/worldgen"
    if recipes.is_dir():
        shutil.copytree(recipes, template / "authoring/worldgen", dirs_exist_ok=True)
    runtime = source["native_runtime"]
    shutil.copyfile(runtime["binary_path"], template / runtime["staged_relative_path"])
    rapier = json.loads(payload.committed(source_root, source["source_commit"], "godot/addons/godot-rapier2d/runtime-provenance.windows.json"))
    binary = rapier_override.resolve() if rapier_override else source_root / rapier["artifact"]
    need(file_record(binary) == {"bytes": rapier["size"], "sha256": rapier["sha256"]}, "Retained Rapier binary differs")
    for name, expected in rapier["source_inputs"].items():
        need(hashlib.sha256(payload.committed(source_root, source["source_commit"], name)).hexdigest() == expected,
             "Retained Rapier source input differs: " + name)
    shutil.copyfile(binary, template / Path(rapier["artifact"]).relative_to("godot"))
    need(not (template / "override.cfg").exists() and not (template / OBSERVER).exists(), "Unexpected startup overlay collision")
    (template / "override.cfg").write_bytes(OVERRIDE)
    shutil.copyfile(ROOT / "tools/pubpres_final_windows/owner_start.gd", template / OBSERVER)
    authored = inventory(template)
    imported_process = execute(engine, ["--headless", "--audio-driver", "Dummy", "--path", str(template), "--editor", "--import"],
                               output / "import", source["source_commit"], {}, 300)
    process_clean(imported_process, zero=True)
    need("ERROR:" not in logs(output / "import"), "Strict startup import diagnostics failed")
    imported = inventory(template)
    bootstrap = {".godot/global_script_class_cache.cfg", ".godot/extension_list.cfg"}
    mutations = [name for name, expected in authored.items() if name not in bootstrap and imported.get(name) != expected]
    write_json(output / "source-custody.json", {"source_commit": source["source_commit"], "source_tree": source["source_tree"],
               "authored_files_sha256": authored, "imported_files_sha256": imported, "authored_mutations": mutations,
               "native": runtime, "rapier": rapier, "observer_sha256": OWNER_SHA})
    need(not mutations, "Engine import changed source-exact authored startup inputs")
    return template, {"authored": {name: value for name, value in authored.items() if name not in bootstrap}, "rapier": rapier}


def validate_deadline_off(deadline):
    need(isinstance(deadline, dict) and deadline.get("schema") == "pubpres-material-deadline-v1"
         and deadline.get("enabled") is False and deadline.get("physical_credit") is False
         and all(type(deadline.get(key)) is int and deadline[key] == 0
                 for key in ("requested_hz", "interval_usec", "pending_count", "accepted_uploads")),
         "Ordinary startup enabled a material deadline treatment")


def validate_startup(data: dict, process: dict, *, source: dict, build: dict, engine_sha: str,
                     thread: str, custody: dict):
    process_clean(process, zero=True)
    authored = custody["authored"]
    need(data.get("schema") == "pubpres-final-owner-start-v1" and data.get("ready") is True
         and data.get("source_commit") == source["source_commit"] and data.get("process_id") == process["observed_application_pid"]
         and data.get("engine_sha256") == engine_sha and data.get("native_sha256") == source["native_runtime"]["binary_sha256"]
         and data.get("rapier_sha256") == custody["rapier"]["sha256"], "Ordinary startup source/runtime/engine/PID differs")
    validate_version(data.get("engine", {}), build)
    for field, path in (("main_sha256", "scripts/main.gd"), ("project_sha256", "project.godot"),
                        ("observer_sha256", OBSERVER), ("override_sha256", "override.cfg")):
        need(data.get(field) == authored[path], "Ordinary startup actual source bytes differ: " + field)
    need(data.get("platform") == "Windows" and data.get("render_driver") == "opengl3_angle"
         and data.get("render_thread_inline") is (thread == "safe") and isinstance(data.get("adapter"), str) and data["adapter"]
         and data.get("scene") == "wave512" and data.get("extent") == [512, 512] and data.get("authored_actor_count") == 1
         and data.get("wave_flow", {}).get("enabled") is True and data.get("physical_acceptance") == "HOLD",
         "Ordinary startup did not install the registered native World, actor, Wave Flow or render owner")
    for name in ("world_generation", "material_revision", "native_tick"):
        need(type(data.get(name)) is int and data[name] >= 0, "Invalid startup World/material/native observation")
    need(payload.SHA.fullmatch(data.get("authored_setup_sha256", "")), "Startup authored setup digest missing")
    material = data.get("material_publication", {})
    need(material.get("requested_mode") == "full" and material.get("backend") == "full" and material.get("fallback_reason") == ""
         and material.get("full_image_slots") == 2 and material.get("full_image_slots_requested") == "2",
         "Ordinary startup enabled a different material publication policy")
    continuation = data.get("same_frame_continuation", {})
    need(all(continuation.get(key) == value for key, value in
             {"version": 1, "requested": False, "enabled": False, "mode": "off", "disabled_reason": "",
              "wait_usec": 0, "new_physics_callbacks": 0, "carried_time_credit": False}.items()),
         "Ordinary startup changed physics admission/continuation policy")
    validate_deadline_off(data.get("material_deadline"))


def startup_arm(thread: str, engine: Path, build: dict, source: dict, template: Path, custody: dict, output: Path) -> dict:
    folder, project = output / "startup" / thread, output / "startup-projects" / thread
    project.parent.mkdir(parents=True, exist_ok=True)
    copy_project(template, project, imported=True)
    receipt = folder / "receipt.json"
    settings = selectors({"material": "full", "same_frame_continuation": False, "wave_column_probe": False, "causal": False}, uuid.uuid4().hex)
    settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2", CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="0",
                    CYBERSAND_MATERIAL_QUEUE_THREAD=thread, CYBERSAND_PLAYABILITY_RENDER_THREAD=thread,
                    CYBERSAND_FINAL_SCENE="wave512", CYBERSAND_PLAYABILITY_OWNER_RECEIPT=str(receipt),
                    CYBERSAND_PLAYABILITY_OWNER_QUIT_AFTER_READY="1")
    result = {"engine": "repaired", "render_thread": thread, "passed": False,
              "settings": settings, "engine_sha256": digest(engine), "physical_step_credit": False}
    try:
        process = execute(engine, graphical_command(engine, project, thread, "res://" + OBSERVER)[1:],
                          folder, source["source_commit"], settings, 360)
        validate_process_command(process, source=source["source_commit"], engine=engine, project=project,
                                 thread=thread, script="res://" + OBSERVER)
        need("ERROR:" not in logs(folder), "Strict ordinary Workbench diagnostics failed")
        data = json.loads(receipt.read_bytes())
        validate_startup(data, process, source=source, build=build, engine_sha=result["engine_sha256"], thread=thread, custody=custody)
        need(digest(engine) == result["engine_sha256"] and all(digest(project / name) == expected for name, expected in custody["authored"].items()),
             "Ordinary startup changed engine or authored source/runtime bytes")
        result.update(passed=True, receipt_sha256=digest(receipt), receipt=data, process=process)
        shutil.rmtree(project)
    except Exception as error:
        result["failure"] = str(error)
        if (folder / "process.json").is_file(): result["process"] = json.loads((folder / "process.json").read_bytes())
    write_json(folder / "qualification.json", result)
    return result


def source_binding(source: dict) -> dict:
    """Portable immutable source/runtime identity; build paths are not identity."""
    runtime = source["native_runtime"]
    return {"source_commit": source["source_commit"], "source_tree": source["source_tree"],
            "native_runtime": {key: value for key, value in runtime.items()
                               if key not in ("manifest_path", "binary_path")}}


def verify_qualification(summary_path: Path, *, source: dict, repaired_payload: Path,
                         build_source: str, build_run: int, build_attempt: int, proof_sha256: str) -> dict:
    """Revalidate retained raw evidence before a new engine enters timed work.

    No boolean or summary-only pass is trusted. Every live font/startup receipt,
    process/cleanup result, strict log, exact engine proof and source join is
    independently checked again. Evidence can be relocated after its run.
    """
    summary_path = Path(summary_path).resolve()
    folder = summary_path.parent
    report = json.loads(summary_path.read_bytes())
    reg, driver = registration(), driver_identity()
    identity = {"build_source": build_source, "build_run": build_run, "build_attempt": build_attempt, "proof_sha256": proof_sha256}
    repaired = payload.verify_payload(repaired_payload, **identity)
    need(report.get("schema") == "pubpres-font-engine-qualification-v1" and report.get("complete") is True
         and report.get("repair_gate_passed") is True and report.get("physical_acceptance") == "HOLD"
         and report.get("failures") == [] and report.get("registration") == reg
         and report.get("registration_sha256") == digest(HERE / "font_registration.json")
         and report.get("driver") == driver and report.get("repaired_engine_admission") == identity
         and source_binding(report["source"]) == source_binding(source), "Font/startup source, driver, admission or completion differs")
    need(source["source_commit"] == driver["source_commit"] and source["source_tree"] == driver["source_tree"],
         "Timed application and font/startup qualification source differ")
    old_restore = payload.load_module("font_original_revalidation", ROOT / "tools/ci/restore_workbench_godot.py")
    _, original_delivery = old_restore.locks()
    original_path = folder / "engine-original-build-provenance.json"
    repaired_path = folder / "engine-repaired-build-provenance.json"
    need(digest(original_path) == original_delivery["build_provenance_sha256"] and digest(repaired_path) == proof_sha256,
         "Retained original or repaired engine provenance differs")
    original = json.loads(original_path.read_bytes())
    need(json.loads(repaired_path.read_bytes()) == repaired and report["engine_builds"] == {"original": original, "repaired": repaired},
         "Font/startup embedded engine records differ from pinned proofs")
    builds = {"original": original, "repaired": repaired}
    need(set(report.get("engine_paths", {})) == set(builds), "Retained engine launch locations are incomplete")
    for role, build in builds.items():
        engine_path = PureWindowsPath(report["engine_paths"][role])
        need(engine_path.is_absolute() and ".." not in engine_path.parts
             and engine_path.name == Path(build["gui_executable"]).name and engine_path.parent.name == "bin",
             "Retained engine launch path is not the admitted direct GUI payload")
    arms = report["font_arms"]
    need(len(arms) == 4, "Missing font arms")
    for arm, planned in zip(arms, reg["order"]):
        role, thread = planned["engine"], planned["render_thread"]
        need(arm.get("engine") == role and arm.get("render_thread") == thread, "Font arm ordering differs")
        arm_folder = folder / "font" / (role + "-" + thread)
        process = json.loads((arm_folder / "process.json").read_bytes())
        need(arm["process"] == process and json.loads((arm_folder / "qualification.json").read_bytes()) == arm,
             "Font process or per-arm receipt differs from summary")
        validate_process_command(process, source=source["source_commit"], engine=report["engine_paths"][role],
                                 project=retained_path(report["output_path"], "font-projects", role + "-" + thread),
                                 thread=thread, script="res://font_probe.gd")
        build = builds[role]
        engine_sha = build["executables"][Path(build["gui_executable"]).name]["sha256"]
        need(arm["engine_sha256"] == engine_sha, "Font actual executable differs from pinned engine proof")
        receipt = arm_folder / "receipt.json"
        if arm["passed"]:
            need(arm["admissible_negative"] is False and "ERROR:" not in logs(arm_folder)
                 and digest(receipt) == arm["receipt_sha256"], "Passed font evidence changed or contains errors")
            data = json.loads(receipt.read_bytes())
            need(data == arm["receipt"], "Font live receipt differs from summary")
            validate_font(data, process, source=source["source_commit"], nonce=arm["nonce"], thread=thread, build=build, engine_sha=engine_sha)
        else:
            need(role == "original" and thread == "separate" and arm["admissible_negative"] is True,
                 "A required repaired/control font failure was relabelled")
            validate_retained_cowdata_negative(process, logs(arm_folder), receipt_exists=receipt.exists(), build=build)
    comparison = validate_font_cohort(arms)
    need(report["font_comparison"] == comparison and report["all_arms_passed"] == comparison["all_font_arms_passed"],
         "Font comparison or negative outcome classification changed")
    import_folder = folder / "startup-template/import"
    import_process = json.loads((import_folder / "process.json").read_bytes())
    process_clean(import_process, zero=True)
    need(import_process.get("source_commit") == source["source_commit"]
         and import_process.get("command") == [report["engine_paths"]["repaired"], "--headless", "--audio-driver", "Dummy", "--path",
                                               retained_path(report["output_path"], "startup-template", "project"), "--editor", "--import"]
         and "ERROR:" not in logs(import_folder), "Retained ordinary import process, source, engine or strict diagnostics differ")
    custody = json.loads((folder / "startup-template/source-custody.json").read_bytes())
    need(custody["source_commit"] == source["source_commit"] and custody["source_tree"] == source["source_tree"]
         and custody["authored_mutations"] == [] and custody["observer_sha256"] == OWNER_SHA,
         "Ordinary startup source import custody differs")
    rapier = json.loads(payload.committed(ROOT, source["source_commit"], "godot/addons/godot-rapier2d/runtime-provenance.windows.json"))
    authored = {name: hashlib.sha256(payload.committed(ROOT, source["source_commit"], "godot/" + name)).hexdigest()
                for name in ("scripts/main.gd", "project.godot")}
    authored.update({OBSERVER: OWNER_SHA, "override.cfg": hashlib.sha256(OVERRIDE).hexdigest(),
                     source["native_runtime"]["staged_relative_path"]: source["native_runtime"]["binary_sha256"],
                     Path(rapier["artifact"]).relative_to("godot").as_posix(): rapier["sha256"]})
    need(custody["rapier"] == rapier and all(custody["authored_files_sha256"].get(name) == expected for name, expected in authored.items()),
         "Startup imported actual source, observer, native or Rapier identity differs")
    startups = report["startup_arms"]
    need(len(startups) == 2, "Both repaired owners require ordinary startup qualification")
    for arm, thread in zip(startups, reg["startup_order"]):
        arm_folder = folder / "startup" / thread
        receipt = arm_folder / "receipt.json"
        process = json.loads((arm_folder / "process.json").read_bytes())
        data = json.loads(receipt.read_bytes())
        need(arm["engine"] == "repaired" and arm["render_thread"] == thread and arm["passed"] is True
             and arm["physical_step_credit"] is False and arm["process"] == process and arm["receipt"] == data
             and digest(receipt) == arm["receipt_sha256"] and "ERROR:" not in logs(arm_folder)
             and json.loads((arm_folder / "qualification.json").read_bytes()) == arm,
             "Ordinary startup raw process, receipt or strict diagnostics differ")
        validate_process_command(process, source=source["source_commit"], engine=report["engine_paths"]["repaired"],
                                 project=retained_path(report["output_path"], "startup-projects", thread),
                                 thread=thread, script="res://" + OBSERVER)
        engine_sha = repaired["executables"][Path(repaired["gui_executable"]).name]["sha256"]
        need(arm["engine_sha256"] == engine_sha, "Startup engine differs from repaired payload")
        validate_startup(data, process, source=source, build=repaired, engine_sha=engine_sha,
                         thread=thread, custody={"authored": authored, "rapier": rapier})
        need(data["adapter"] == arms[0]["receipt"]["adapter"], "Startup adapter differs from font controls")
    return {"summary_sha256": digest(summary_path), "repair_gate_passed": True,
            "all_arms_passed": report["all_arms_passed"], "retained_negative_observed": comparison["retained_negative_observed"],
            "font_arms": 4, "ordinary_startup_arms": 2, "source": source_binding(source),
            "engine_proof_sha256": proof_sha256, "physical_acceptance": "HOLD",
            "scope": "Revalidated finite font pixels and ordinary paused startup; no physical progression or sustained performance credit."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "runtime", "original-engine-root", "repaired-engine-root", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--rapier-runtime", type=Path)
    payload.add_identity_arguments(parser)
    args = parser.parse_args()
    need(os.name == "nt", "This registered font engine qualification requires Windows")
    output = args.output.resolve()
    need(not output.exists(), "Use a fresh font/startup evidence directory")
    reg, driver = registration(), driver_identity()
    source_root = args.source.resolve()
    source = source_identity(source_root)
    need(source["source_commit"] == driver["source_commit"] and source["source_tree"] == driver["source_tree"],
         "Ordinary application must be the exact qualification driver source")
    source["native_runtime"] = validate_runtime(source_root, source, args.runtime.resolve(), False)
    original_root, repaired_root = args.original_engine_root.resolve(), args.repaired_engine_root.resolve()
    old_restore = payload.load_module("font_original_engine", ROOT / "tools/ci/restore_workbench_godot.py")
    original = old_restore.verify_payload(original_root)
    new_identity = payload.identity_arguments(args)
    repaired = payload.verify_payload(repaired_root, **new_identity)
    engines = {"original": original_root / original["gui_executable"], "repaired": repaired_root / repaired["gui_executable"]}
    builds = {"original": original, "repaired": repaired}
    need(digest(engines["original"]) != digest(engines["repaired"]), "Engine arms share the same binary")
    output.mkdir(parents=True)
    shutil.copyfile(original_root / "build-provenance.json", output / "engine-original-build-provenance.json")
    shutil.copyfile(repaired_root / "build-provenance.json", output / "engine-repaired-build-provenance.json")
    report = {"schema": "pubpres-font-engine-qualification-v1", "registration": reg,
              "registration_sha256": digest(HERE / "font_registration.json"), "driver": driver, "source": source,
              "engine_paths": {role: str(engine) for role, engine in engines.items()}, "output_path": str(output),
              "engine_builds": builds, "repaired_engine_admission": new_identity,
              "font_arms": [], "startup_arms": [], "failures": [], "complete": False,
              "repair_gate_passed": False, "all_arms_passed": False, "physical_acceptance": "HOLD"}
    def save(): write_json(output / "SUMMARY.json", report)
    save()
    for arm in reg["order"]:
        report["font_arms"].append(font_arm(arm["engine"], arm["render_thread"], engines[arm["engine"]],
                                          builds[arm["engine"]], source["source_commit"], output))
        save()
    try:
        report["font_comparison"] = validate_font_cohort(report["font_arms"])
        save()
        template, custody = prepare_startup(source_root, source, engines["repaired"], output / "startup-template", args.rapier_runtime)
        for thread in reg["startup_order"]:
            report["startup_arms"].append(startup_arm(thread, engines["repaired"], repaired, source, template, custody, output))
            save()
        need(len(report["startup_arms"]) == 2 and all(arm["passed"] for arm in report["startup_arms"]), "Required ordinary repaired-engine startup failed")
        adapters = {arm["receipt"]["adapter"] for arm in report["startup_arms"]}
        need(adapters == {report["font_arms"][0]["receipt"]["adapter"]}, "Font and ordinary startup used different adapters")
        need(source_identity(source_root) == {key: value for key, value in source.items() if key != "native_runtime"},
             "Application source changed during font/startup qualification")
        need(validate_runtime(source_root, source, args.runtime.resolve(), False) == source["native_runtime"], "Native build changed during startup")
        need(old_restore.verify_payload(original_root) == original and payload.verify_payload(repaired_root, **new_identity) == repaired,
             "Engine payload changed during qualification")
        report["repair_gate_passed"] = True
        report["all_arms_passed"] = report["font_comparison"]["all_font_arms_passed"]
        report["complete"] = True
        shutil.rmtree(template)
    except Exception as error:
        report["failures"].append(str(error))
    save()
    if report["repair_gate_passed"]:
        try:
            checked = verify_qualification(output / "SUMMARY.json", source=source, repaired_payload=repaired_root, **new_identity)
            write_json(output / "verified-qualification.json", checked)
        except Exception as error:
            report["repair_gate_passed"] = False
            report["complete"] = False
            report["failures"].append("Independent retained-evidence replay: " + str(error))
            save()
    print(json.dumps({key: report[key] for key in ("complete", "repair_gate_passed", "all_arms_passed", "failures", "physical_acceptance")}))
    return 0 if report["repair_gate_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
