#!/usr/bin/env python3
"""Actual installed Full/two-slot author, Save and fresh-process graphical reopen.

The original authoring tape and every native/source/framebuffer gate are retained.
A named wrapper verifies the final evaluator publication policy. This is separate
from the older blit-profile qualification and never changes its evidence.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys

import package_windows as package
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))
from run_regressions import run, validate_completion, terminal_json, check_framebuffer, digest, continuation_policy


def full_policy():
    policy = continuation_policy("off")
    policy["selectors"]["CYBERSAND_MATERIAL_PUBLICATION"] = "full"
    policy["selectors"]["CYBERSAND_DIAG_FULL_IMAGE_SLOTS"] = "2"
    return policy


def validate_full_policy(evidence):
    expected = {"selectors": full_policy()["selectors"],
                "status": {"version": 1, "requested": False, "enabled": False, "disabled_reason": "", "mode": "off",
                           "maximum_attempts_per_process_frame": 1, "maximum_mailbox_reads_per_attempt": 1,
                           "wait_usec": 0, "new_physics_callbacks": 0, "carried_time_credit": False},
                "material": {"requested_mode": "full", "backend": "full", "full_image_slots": 2, "fallback_reason": ""}}
    package.need(isinstance(evidence, dict) and set(evidence) == {"schema", "mode", "claim", "before", "after"}
                 and evidence["schema"] == "pubpres-authoring-continuation-evidence-v1"
                 and evidence["mode"] == "off" and evidence["claim"] == "configuration-only",
                 "Final authoring continuation schema differs")
    for phase in ("before", "after"):
        package.need(json.dumps(evidence[phase], sort_keys=True) == json.dumps(expected, sort_keys=True),
                     "Final Full/two-slot/continuation policy differs: " + phase)
    return evidence


# The following source/framebuffer/transaction checks are retained from the
# predecessor combined_evidence function; only the named policy validator differs.
def authoring_evidence(text, project, native_sha, screenshots, *, graphical, reopen, same_frame="off"):
    result = terminal_json(text, "WB_COMBINED_EVIDENCE ")
    if result.get("schema") != "workbench-combined-authoring-v2":
        raise ValueError("Combined authoring evidence schema differs")
    continuation = validate_full_policy(result.get("same_frame_continuation"))
    identity = result["source_identity"]
    if identity.get("native_sha256") != native_sha or graphical and identity.get("display") == "headless":
        raise ValueError("Combined authoring did not use the requested native/graphical runtime")
    required_source = {"tests/test_workbench_combined_authoring.gd", "scripts/main.gd",
                       "scripts/workbench_same_frame_continuation.gd"}
    if not required_source.issubset(identity):
        raise ValueError("Combined authoring source identity missing")
    for name, value in identity.items():
        if "/" in name and digest(project / name) != value:
            raise ValueError("Combined authoring source differs: " + name)
    phases = ("discovery", "reopen", "continued_authoring") if reopen else (
        "discovery", "generation", "manual", "leases", "agent", "provider_fixture", "late_response",
        "human_after_agent", "stop", "agent_undo_saved", "simulation_equipment", "save")
    if any(result.get("phases", {}).get(name) is not True for name in phases):
        raise ValueError("Combined authoring omitted a mandatory transaction phase")
    if not re.fullmatch(r"[0-9a-f]{64}", result.get("prepared_sha256", "")) or result.get("map_side") != 512:
        raise ValueError("Complete saved native plane identity or requested map differs")
    images = {}
    framebuffer_dimensions = None
    if graphical:
        # The fixture requests a 1440x1000 window, but project.godot keeps the
        # 1920x1080 canvas aspect. get_texture() captures its 1440x810 viewport,
        # excluding the window's letterbox bars. Do not invent extra pixels.
        settings = (project / "project.godot").read_text(encoding="utf-8")
        required = ("window/size/viewport_width=1920", "window/size/viewport_height=1080",
                    'window/stretch/mode="canvas_items"')
        if any(line not in settings.splitlines() for line in required):
            raise ValueError("Combined graphical fixture viewport policy differs")
        aspect = re.search(r'^window/stretch/aspect=(.+)$', settings, re.M)
        if aspect and aspect.group(1).strip() != '"keep"':
            raise ValueError("Combined graphical fixture aspect policy differs")
        scale = min(1440 / 1920, 1000 / 1080)
        framebuffer_dimensions = [round(1920 * scale), round(1080 * scale)]
        labels = ("generator-profiles", "reopened-and-continued") if reopen else (
            "generator-profiles", "generator-preview", "agent-and-paint", "equipment-simulation", "authored-saved")
        for label in labels:
            path = screenshots / ("combined-" + label + ".png")
            check_framebuffer(path, {"width": framebuffer_dimensions[0], "height": framebuffer_dimensions[1]}, framebuffer_dimensions)
            images[path.name] = digest(path)
    return {"prepared_sha256": result["prepared_sha256"], "source_identity": identity,
            "phases": result["phases"], "screenshots_sha256": images, "checks": result["checks"],
            "framebuffer_dimensions": framebuffer_dimensions, "same_frame_continuation": continuation}



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    package.need(os.name == "nt", "Installed authoring requires actual Windows")
    payload, output = args.package.resolve(), args.output.resolve()
    package.need(not output.exists(), "Preserve previous evidence; output must be new")
    manifest = package.verify(payload, args.candidate)
    output.mkdir(parents=True)
    source = manifest["sources"]["C"]
    staged = output / "source"
    shutil.copytree(payload / source["root"], staged)
    project = staged / "godot"
    overlay = project / "tests/pubpres_final_authoring.gd"
    package.need(not overlay.exists(), "Run-only authoring observer collides with committed source")
    shutil.copyfile(payload / package.TOOLS / "authoring.gd", overlay)
    engine = payload / manifest["engine"]["gui"]["path"]
    authored = {p.relative_to(staged).as_posix(): digest(p) for p in staged.rglob("*")
                if p.is_file() and not p.relative_to(staged).as_posix().startswith("godot/.godot/")}
    environment = {key: value for key, value in os.environ.items() if not key.startswith(("CYBERSAND_", "WB_COMBINED_"))}
    for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = output / "profile" / name
        path.mkdir(parents=True)
        environment[name] = str(path)
    environment.update(full_policy()["selectors"])
    environment.update(CYBERSAND_SOURCE_REVISION=args.candidate, CYBERSAND_SOURCE_SHA=args.candidate,
                       WB_COMBINED_SIDE="512", WB_COMBINED_WORKERS="1", WB_COMBINED_REQUIRE_GRAPHICS="1",
                       WB_COMBINED_SAME_FRAME="off")
    prefix = [str(engine), "--path", str(project), "--audio-driver", "Dummy"]
    outcomes, failure = [], None
    try:
        item = run(prefix + ["--headless", "--editor", "--import", "--quit"], environment, output / "import", 300)
        item["validation_errors"] = validate_completion("import", (output / "import/stdout.log").read_text(errors="replace"), item["returncode"])
        outcomes.append(item)
        package.need(not item["validation_errors"] and not item["timed_out"], "Installed import failed")
        for reopen in (False, True):
            label = "reopen" if reopen else "author"
            folder = output / label
            environment.update(WB_COMBINED_REOPEN="1" if reopen else "0", WB_COMBINED_SCREENSHOTS=str(folder / "screenshots"))
            item = run(prefix + ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
                                "--render-thread", "safe", "--script", "res://tests/pubpres_final_authoring.gd"], environment, folder, 600)
            text = (folder / "stdout.log").read_text(errors="replace")
            item["validation_errors"] = validate_completion("test_workbench_combined_authoring", text, item["returncode"], reopen=reopen)
            outcomes.append(item)
            package.need(not item["validation_errors"] and not item["timed_out"] and "ERROR:" not in text, "Installed authoring/reopen failed")
            evidence = authoring_evidence(text, project, source["native"]["sha256"], folder / "screenshots", graphical=True, reopen=reopen)
            identity = evidence["source_identity"]
            package.need(identity["engine_sha256"] == manifest["engine"]["gui"]["sha256"] and identity["render_thread_inline"] is True
                         and identity["tests/pubpres_final_authoring.gd"] == digest(overlay), "Actual authoring engine/owner/wrapper differs")
            item["authoring_evidence"] = evidence
            if reopen:
                package.need(evidence["prepared_sha256"] == outcomes[1]["authoring_evidence"]["prepared_sha256"], "Fresh-process reopened complete native material digest differs")
            package.write_json(folder / "process.json", item)
        changed = [name for name, expected in authored.items() if not (staged / name).is_file() or digest(staged / name) != expected]
        package.need(not changed, "Authoring/import modified staged source: " + str(changed))
    except Exception as error:
        failure = type(error).__name__ + ": " + str(error)
    finally:
        try:
            package.verify(payload, args.candidate)
        except Exception as error:
            failure = (failure + "; " if failure else "") + "Pristine payload changed: " + str(error)
        summary = {"schema": "pubpres-final-installed-authoring-v1", "candidate": args.candidate,
                   "manifest_sha256": digest(payload / package.MANIFEST), "engine_sha256": digest(engine),
                   "native_sha256": source["native"]["sha256"], "overlay_sha256": digest(overlay),
                   "complete": failure is None and len(outcomes) == 3, "failure": failure, "outcomes": outcomes,
                   "policy": full_policy(), "physical_acceptance": "HOLD",
                   "scope": "Actual 512-square graphical native author/Save/fresh-process reopen under ordinary Full/two-slot/Safe; no sustained gameplay or physical NVIDIA acceptance."}
        package.write_json(output / "SUMMARY.json", summary)
    return 0 if summary["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
