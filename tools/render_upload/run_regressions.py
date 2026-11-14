#!/usr/bin/env python3
"""Bounded existing integration gates for the opt-in material upload experiment.

Mounted Workbench cases must announce an active drawable strategy throughout.
Existing headless ownership/recording and isolated graphical controls retain
their original default path; their results are not relabelled as candidate
coverage. Process supervision, timeout evidence and source/runtime verification
are shared with run_campaign.py. No native runtime is rebuilt or republished.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sys

import run_campaign as campaign


def case(name: str, script: str, marker: str, *, graphical: bool = False,
         candidate: bool = False, group: str | None = None, dependency: str | None = None,
         phase: str | None = None, env: dict | None = None, scope: str = "") -> dict:
    return {"id": name, "script": "res://tests/" + script + ".gd", "marker": marker,
            "graphical": graphical, "candidate": candidate, "userdata_group": group or name,
            "dependency": dependency, "phase": phase, "environment": env or {}, "scope": scope}


CASES = [
    case("patch-handoff", "test_render_patch_handoff_regression", "Render patch handoff regression passed",
         scope="Default headless immutable handoff, metadata bounds and explicit ACK control"),
    case("world-generation", "test_render_world_generation", "RENDER_WORLD_GENERATION:",
         scope="Default headless native/R8 generation, paused refresh and replacement control"),
    case("native-art", "test_art_batch_native_render", "ART_STAGE1_RESULT", graphical=True, candidate=True,
         scope="Mounted native Art/manual authoring, Stop, save/load and World replacement; fixture requests two native workers"),
    case("paint-author", "test_paint_editor_generated_workbench", "PAINT_EDITOR_GENERATED_WORKBENCH",
         graphical=True, candidate=True, group="paint-generated", phase="author",
         scope="Mounted generated-map PAINT, copy/paste, history and persisted native evidence"),
    case("paint-reopen", "test_paint_editor_generated_workbench", "PAINT_EDITOR_GENERATED_WORKBENCH",
         graphical=True, candidate=True, group="paint-generated", dependency="paint-author", phase="reopen",
         env={"PAINT_GENERATED_REOPEN": "1"}, scope="Fresh-process reopen and continued PAINT with the same isolated userdata"),
    case("combined-author", "test_workbench_combined_authoring", "WB_COMBINED_EVIDENCE",
         graphical=True, candidate=True, group="combined", phase="author",
         env={"WB_COMBINED_REQUIRE_GRAPHICS": "1", "WB_COMBINED_WORKERS": "1", "WB_COMBINED_SIDE": "512"},
         scope="Mounted manual/agent authoring, Undo/Redo, deterministic provider fixture, simulation equipment and save; no model inference"),
    case("combined-reopen", "test_workbench_combined_authoring", "WB_COMBINED_EVIDENCE",
         graphical=True, candidate=True, group="combined", dependency="combined-author", phase="reopen",
         env={"WB_COMBINED_REOPEN": "1", "WB_COMBINED_REQUIRE_GRAPHICS": "1", "WB_COMBINED_WORKERS": "1", "WB_COMBINED_SIDE": "512"},
         scope="Fresh-process combined Workbench reopen and continued authoring"),
    case("materials-author", "test_material_lab_workbench_integration", "MAT_WB_EVIDENCE",
         graphical=True, candidate=True, group="materials", phase="author", env={"ART_UNDO_WORKERS": "1"},
         scope="Mounted Materials Lab/native Workbench authoring and material witnesses with one native worker"),
    case("materials-reopen", "test_material_lab_workbench_integration", "MAT_WB_EVIDENCE",
         graphical=True, candidate=True, group="materials", dependency="materials-author", phase="reopen",
         env={"MAT_WB_REOPEN": "1", "ART_UNDO_WORKERS": "1"},
         scope="Fresh-process Materials Lab Workbench reopen and continued authoring with one native worker"),
    case("recorder", "test_gameplay_recorder", "Gameplay recorder regression passed",
         scope="Default headless recording/provenance contract; does not qualify a mounted candidate recording session"),
    case("overlay", "test_play_ui007_overlay_render", "PLAY_UI007_PIXELS_RESULT", graphical=True,
         scope="Existing isolated overlay pixels; no Main/native actor or terrain qualification"),
    case("palette", "test_palette_crossfade_render", "PALETTE_CROSSFADE_RENDER_RESULT", graphical=True,
         scope="Existing explicit bounded-palette shader oracle at blend 0/0.5/1 and camera pan, default ImageTextures"),
    case("vapour", "test_material_vapour_pipeline_render", "MATERIAL_VAPOUR_PIPELINE:", graphical=True,
         scope="Existing actual-pixel vapour history/reset and RG8/R8 control, default ImageTextures"),
]

PHASE_ENV = ("PAINT_GENERATED_REOPEN", "WB_COMBINED_REOPEN", "MAT_WB_REOPEN")
CAPTURE_ENV = ("CYBERSAND_TEST_ARTIFACT_DIR", "WB_ART_EVIDENCE_DIR", "PAINT_CAPTURE_DIR",
               "WB_COMBINED_SCREENSHOTS", "MAT_WB_SCREENSHOTS", "CYBERSAND_PALETTE_CROSSFADE_OUTPUT",
               "CYBERSAND_SHADER_CAPTURE", "CYBERSAND_PRESENTATION_EVIDENCE")


def json_lines(text: str, prefix: str) -> list[dict]:
    values = []
    for line in text.splitlines():
        if line.startswith(prefix + " "):
            value = json.loads(line[len(prefix) + 1:])
            if not isinstance(value, dict):
                raise ValueError(prefix + " did not contain a JSON object")
            values.append(value)
    return values


def validate(item: dict, text: str, source: dict, engine: dict, driver: str) -> dict:
    states = json_lines(text, "RENDER_UPLOAD_STATE")
    contexts = json_lines(text, "PALETTE_QUALIFICATION_CONTEXT")
    if item["candidate"]:
        if not states:
            raise ValueError("Mounted test did not prove drawable admission")
        for state in states:
            if (state.get("requested") != "drawable" or state.get("active") != "drawable"
                    or state.get("fallback_reason") or state.get("waiting_for_full_refresh")
                    or state.get("canary", {}).get("passed") is not True
                    or state.get("display_server") in (None, "headless")
                    or state.get("renderer") != "gl_compatibility" or state.get("driver") != driver):
                raise ValueError("Mounted candidate fell back, rejected an update, or used another backend: " + json.dumps(state))
    elif states:
        raise ValueError("Default control unexpectedly requested the drawable experiment")
    for context in contexts:
        if (context.get("source_revision") != source["commit"]
                or context.get("fixture") != item["script"]
                or context.get("engine_sha256") != engine["runtime"]["sha256"]
                or (item["graphical"] and (context.get("display_server") in (None, "headless")
                    or context.get("backend") != driver))):
            raise ValueError("Graphical context differs from the declared source, engine or backend")
    if item["id"] in ("palette", "vapour") and not contexts:
        raise ValueError("Existing graphical test did not emit its runtime/source context")
    if item["id"] in ("patch-handoff", "recorder"):
        if text.splitlines().count(item["marker"]) != 1:
            raise ValueError("Missing or repeated terminal success marker")
        evidence = {"terminal_marker": item["marker"]}
    elif item["id"] in ("world-generation", "vapour"):
        prefix = ("RENDER_WORLD_GENERATION: " if item["id"] == "world-generation"
                  else "MATERIAL_VAPOUR_PIPELINE: actual pixels, ")
        matches = re.findall(r"^" + re.escape(prefix) + r"(\d+) assertions, (\d+) failures$", text, re.M)
        if len(matches) != 1 or int(matches[0][0]) <= 0 or int(matches[0][1]) != 0:
            raise ValueError("Test did not complete positive assertions with zero failures")
        evidence = {"assertions": int(matches[0][0]), "failures": int(matches[0][1])}
    else:
        records = json_lines(text, item["marker"])
        if len(records) != 1:
            raise ValueError("Missing or repeated terminal JSON marker: " + item["marker"])
        evidence = records[0]
        failures = evidence.get("failures")
        no_failures = (type(failures) is int and failures == 0) or (isinstance(failures, list) and not failures)
        checks = evidence.get("checks", evidence.get("assertions", 0))
        if not no_failures or type(checks) is not int or checks <= 0:
            raise ValueError("Terminal evidence has failures or no positive check count")
        if item["id"].startswith("paint-"):
            if (evidence.get("completed") is not True
                    or (evidence.get("reopen") == "1") != (item["phase"] == "reopen")):
                raise ValueError("Generated PAINT did not complete the requested author/reopen phase")
        if item["id"].startswith("combined-") and evidence.get(item["phase"] + "_complete") is not True:
            raise ValueError("Combined Workbench did not complete the requested phase")
        if item["id"].startswith("materials-"):
            if evidence.get("complete") is not True or evidence.get("phase") != item["phase"] or evidence.get("workers") != 1:
                raise ValueError("Materials Workbench did not complete the requested phase/workers")
        if item["id"] == "overlay" and (evidence.get("real_graphical_pixels") is not True
                or evidence.get("display_server") in (None, "headless")
                or evidence.get("source_revision") != source["commit"]):
            raise ValueError("Overlay did not establish actual graphical pixels at the requested source")
        if item["id"] == "native-art" and evidence.get("last_native_backend") != "CyberNativeCellWorld":
            raise ValueError("Art did not establish its native backend")
    return {"terminal_evidence": evidence, "candidate_states": states, "runtime_contexts": contexts,
            "renderer_banner": [line for line in text.splitlines() if line.startswith(("Godot Engine v", "OpenGL API", "Vulkan "))]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cache-root", type=Path)
    parser.add_argument("--source-sha")
    parser.add_argument("--allow-dirty", action="store_true", help="Local preflight only; cannot claim exact hosted source")
    parser.add_argument("--timeout", type=float, default=600)
    parser.add_argument("--rendering-driver", default="opengl3_angle" if sys.platform == "win32" else "opengl3")
    args = parser.parse_args()
    if args.timeout < 10:
        parser.error("timeout>=10 required")
    if args.allow_dirty and (args.source_sha or os.environ.get("GITHUB_ACTIONS") == "true"):
        parser.error("Local-delta preflight cannot claim an exact requested/hosted source")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / "integration-summary.json"
    if report_path.exists():
        raise ValueError("Refusing to overwrite original integration evidence: " + str(report_path))
    cache_root = (args.cache_root or output.parent / (output.name + "-userdata")).resolve()
    if cache_root == output or output in cache_root.parents:
        raise ValueError("Userdata must remain outside retained evidence")
    report = {"schema": "render-upload-integration-v1", "complete": False, "passed": False,
              "started_utc": datetime.now(timezone.utc).isoformat(),
              "host": campaign.execution_telemetry.host_identity(), "cases": CASES, "results": [],
              "environment": {key: os.environ.get(key) for key in
                              ("LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")},
              "limits": ["Existing fixtures retain their native/material assertions and visual oracles",
                         "Only mounted Workbench fixtures require drawable admission; default controls are labelled separately",
                         "No model inference, hardware GPU claim or performance result is established by these regressions",
                         "Process time/RSS include startup and correctness readbacks; they are not benchmark samples"]}
    campaign.write(report_path, report)
    try:
        source = campaign.source_identity(args.source_sha, args.allow_dirty)
        runtime = campaign.retained_runtime_identity()
        engine = campaign.engine_identity(args.godot)
        report.update(source=source, runtime=runtime, engine=engine,
                      runner_sha256=campaign.sha(Path(__file__)),
                      fixture_sha256={item["script"]: campaign.sha(campaign.ROOT / item["script"].replace("res://", "godot/"))
                                      for item in CASES})
        campaign.write(report_path, report)
        groups = {"import", *(item["userdata_group"] for item in CASES)}
        if any((cache_root / group).exists() for group in groups):
            raise ValueError("Fresh integration userdata groups required; refusing stale persisted fixtures")
        basic = [engine["launcher"]["path"], "--audio-driver", "Dummy", "--path", str(campaign.ROOT / "godot")]
        report["import"] = campaign.execute([*basic, "--headless", "--editor", "--import", "--quit"],
            campaign.child_environment(cache_root, "import", source["commit"]), output / "import", args.timeout)
        if campaign.source_identity(args.source_sha, args.allow_dirty) != source:
            raise ValueError("Import changed authenticated source; generated legacy UID companions alone are permitted")
        campaign.write(report_path, report)
        by_name: dict[str, dict] = {}
        for item in CASES:
            folder = output / item["id"]
            result = {"id": item["id"], "status": "not executed", "folder": item["id"],
                      "scope": item["scope"], "candidate_required": item["candidate"]}
            dependency = item["dependency"]
            if dependency and by_name[dependency]["status"] != "passed":
                result.update(status="blocked", reason="Author fixture did not pass: " + dependency)
            else:
                env = campaign.child_environment(cache_root, item["userdata_group"], source["commit"])
                for key in PHASE_ENV:
                    env.pop(key, None)
                env.update(item["environment"])
                for key in CAPTURE_ENV:
                    env[key] = str(folder / "captures")
                env["CYBERSAND_SHADER_CACHE_STATE"] = "isolated integration userdata; author/reopen pair shared; imported project cache retained"
                command = [*basic]
                if item["graphical"]:
                    command += ["--rendering-method", "gl_compatibility", "--rendering-driver", args.rendering_driver]
                else:
                    command += ["--headless"]
                command += ["--script", item["script"]]
                if item["candidate"]:
                    command += ["--", "--render-upload=drawable"]
                try:
                    result["process"] = campaign.execute(command, env, folder, args.timeout)
                    text = (folder / "process.log").read_text(encoding="utf-8", errors="replace")
                    result.update(validate(item, text, source, engine, args.rendering_driver), status="passed")
                except (OSError, RuntimeError, ValueError) as error:
                    result.update(status="failed", reason=f"{type(error).__name__}: {error}")
                    if (folder / "process.json").is_file():
                        result["process"] = json.loads((folder / "process.json").read_text(encoding="utf-8"))
                campaign.write(folder / "qualification.json", result)
            report["results"].append(result)
            by_name[item["id"]] = result
            campaign.write(report_path, report)
            print(f"RENDER_UPLOAD_INTEGRATION {item['id']} {result['status']}", flush=True)
        if (campaign.source_identity(args.source_sha, args.allow_dirty) != source
                or campaign.retained_runtime_identity() != runtime or campaign.engine_identity(args.godot) != engine):
            raise ValueError("Source, retained native runtime or pinned engine changed during integration")
        report["complete"] = True
        report["passed"] = all(item["status"] == "passed" for item in report["results"])
        report["counts"] = {status: sum(item["status"] == status for item in report["results"])
                            for status in ("passed", "failed", "blocked")}
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        campaign.write(report_path, report)
        print("RENDER_UPLOAD_INTEGRATION_RESULT " + json.dumps({key: report[key] for key in ("complete", "passed", "counts")}), flush=True)
        return 0 if report["passed"] else 1
    except BaseException as error:
        report["failure"] = f"{type(error).__name__}: {error}"
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        campaign.write(report_path, report)
        raise


if __name__ == "__main__":
    raise SystemExit(main())
