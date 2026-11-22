#!/usr/bin/env python3
"""Run the scoped PUBPRES authority and actual-renderer gates on fresh source.

Each child owns a fresh profile. The source checkout and its retained production
runtime are never replaced. Failed cases, original logs and process outcomes are
retained; these correctness runs are not performance samples.
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
import tarfile
import tempfile
import time

from build_runtime import bounded_process, committed_inputs, digest, git
import dependency_custody

ROOT = Path(__file__).resolve().parents[2]
from regression_contract import case_diagnostic_error
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))
from results import check_framebuffer
HEADLESS = (
    "test_pubpres_playability_native_probe", "test_pubpres_retained_baseline",
    "test_failed_world_status_survives", "test_simulation_worker_interest_ownership",
    "test_render_cadence_worker", "test_workbench_material_delivery_timing",
    "test_workbench_combined_authoring", "test_art_history_durability",
    "test_workbench_material_baseline", "test_physical_actor_integration",
)
SAME_FRAME_HEADLESS = (
    ("same-frame-unit-off", "test_workbench_same_frame_continuation", "off"),
    ("same-frame-integration-on", "test_workbench_same_frame_integration", "on"),
    ("physics-publication-off", "test_workbench_physics_publication", "off"),
    ("physics-publication-on", "test_workbench_physics_publication", "on"),
)
SAME_FRAME_COMPLETIONS = {
    "test_workbench_same_frame_continuation": (
        "SAME_FRAME_UNIT_RESULT ", "workbench-same-frame-unit-v1", 90),
    "test_workbench_same_frame_integration": (
        "SAME_FRAME_INTEGRATION_RESULT ", "workbench-same-frame-integration-v1", 52),
    "test_workbench_physics_publication": (
        "PHYSICS_PUBLICATION_RESULT ", "workbench-physics-publication-v1", 60),
}
AUTHORING_MODES = ("off", "on")
GRAPHICS = (
    ("test_material_staging_reachability", "safe", "eager"),
    ("test_material_staging_reachability", "separate", "eager"),
    ("test_material_tile_publication", "safe", "eager"),
    ("test_material_tile_publication", "safe", "reachable"),
    ("test_material_rectangular_staging_render", "safe", "reachable"),
    ("test_material_presentation_render", "safe", "reachable"),
    ("test_pubpres_transition_history_render", "safe", "reachable"),
    ("run_material_threaded_publication", "separate", "reachable"),
    ("test_native_pixel_camera", "safe", "reachable"),
)


def continuation_policy(mode: str) -> dict:
    """Explicit test configuration; it makes no continuation-causal step claim."""
    if mode not in ("off", "on"):
        raise ValueError("Same-frame authoring mode must be off or on")
    return {
        "schema": "pubpres-authoring-continuation-policy-v1",
        "mode": mode,
        "claim": "configuration-only",
        "selectors": {
            "CYBERSAND_DIAG_SAME_FRAME_CONTINUATION": "1" if mode == "on" else "0",
            "CYBERSAND_DIAG_NATIVE_RENDEZVOUS": "0",
            "CYBERSAND_DIAG_PHYSICS_PUBLICATION": "early",
            "CYBERSAND_DIAG_PRESENTATION": "coherent",
            "CYBERSAND_DIAG_MATERIAL_TIMING": "measured",
            "CYBERSAND_DIAG_RENDER_CADENCE": "repaired",
            "CYBERSAND_MATERIAL_PUBLICATION": "blit",
            "CYBERSAND_MATERIAL_QUEUE_THREAD": "safe",
            "CYBERSAND_DIAG_MATERIAL_POOL_POLICY": "eager",
        },
    }


def validate_continuation_evidence(evidence, mode: str) -> dict:
    policy = continuation_policy(mode)
    if (not isinstance(evidence, dict)
            or set(evidence) != {"schema", "mode", "claim", "before", "after"}
            or evidence.get("schema") != "pubpres-authoring-continuation-evidence-v1"
            or evidence.get("mode") != mode or evidence.get("claim") != "configuration-only"):
        raise ValueError("Combined authoring continuation policy differs")
    enabled = mode == "on"
    expected_status = {
        "version": 1, "requested": enabled, "enabled": enabled, "disabled_reason": "",
        "mode": "same_frame_once" if enabled else "off",
        "maximum_attempts_per_process_frame": 1, "maximum_mailbox_reads_per_attempt": 1,
        "wait_usec": 0, "new_physics_callbacks": 0, "carried_time_credit": False,
    }
    expected = {"selectors": policy["selectors"], "status": expected_status}
    for phase in ("before", "after"):
        # JSON comparison also distinguishes forged 0/1 from actual booleans.
        if json.dumps(evidence[phase], sort_keys=True) != json.dumps(expected, sort_keys=True):
            raise ValueError("Combined authoring continuation selectors/status differ: " + phase)
    return evidence


def invoke_authoring_pairs(invoke, display, graphical):
    """Keep independent profiles and retain every outcome, including failed OFF."""
    test = "test_workbench_combined_authoring"
    for mode in AUTHORING_MODES:
        label = test + "-" + mode
        options = [*display, "--script", "res://tests/" + test + ".gd"]
        invoke(label, options, graphical=graphical, same_frame=mode)
        invoke(label + "-reopen", options, graphical=graphical, profile_key=label,
               reopen=True, same_frame=mode)


def stage_source(root: Path, source: str, output: Path) -> Path:
    git(root, "diff", "--exit-code", source, "--", "godot", "examples/worldgen")
    unknown = git(root, "ls-files", "--others", "--exclude-standard", "--", "godot", "examples/worldgen").splitlines()
    if any(not name.endswith(".uid") for name in unknown):
        raise ValueError("Uncommitted project input")
    project = output / "project"
    with tempfile.TemporaryFile() as stream:
        subprocess.run(["git", "archive", "--format=tar", source, "--", "godot", "examples/worldgen"],
                       cwd=root, stdout=stream, check=True, timeout=120)
        stream.seek(0)
        with tarfile.open(fileobj=stream) as archive:
            for member in archive:
                if member.isdir():
                    continue
                path = Path(member.name)
                if not member.isfile() or path.is_absolute() or ".." in path.parts:
                    raise ValueError("Unexpected project archive member")
                target = project.joinpath(*path.parts[1:]) if path.parts[0] == "godot" else output / path
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as incoming, target.open("wb") as outgoing:
                    shutil.copyfileobj(incoming, outgoing)
    return project


def terminal_json(text: str, marker: str) -> dict:
    rows = [line[len(marker):] for line in text.splitlines() if line.startswith(marker)]
    if len(rows) != 1:
        raise ValueError("Missing or repeated completion record: " + marker)
    result = json.loads(rows[0])
    if not isinstance(result, dict) or type(result.get("checks")) is not int or result["checks"] <= 0:
        raise ValueError("No completed assertions in " + marker)
    if result.get("failures") not in ([], 0):
        raise ValueError("Fixture assertions failed")
    return result


def validate_completion(test: str, text: str, returncode, *, reopen=False) -> list[str]:
    errors = []
    if returncode != 0 or case_diagnostic_error(test, text, returncode):
        errors.append("Process or strict Godot diagnostic failure")
    if test == "import":
        return errors
    patterns = {
        "test_pubpres_playability_native_probe": r"^PUBPRES_NATIVE_PROBE checks=222 failures=0$",
        "test_pubpres_retained_baseline": r"^PUBPRES_RETAINED_BASELINE checks=[1-9][0-9]* failures=0$",
        "test_simulation_worker_interest_ownership": r"^SIMULATION_WORKER_INTEREST_OWNERSHIP: [1-9][0-9]* assertions; 0 failures$",
        "test_render_cadence_worker": r"^RENDER_CADENCE_WORKER: [1-9][0-9]* checks, 0 failures;",
        "test_workbench_material_baseline": r"^WORKBENCH_MATERIAL_BASELINE checks=[1-9][0-9]* failures=0$",
        "test_physical_actor_integration": r"^Physical actor integration: [1-9][0-9]* assertions, 0 failures$",
        "test_material_tile_publication": r"^MATERIAL_TILE_PUBLICATION: [1-9][0-9]* assertions, 0 failures$",
        "test_material_rectangular_staging_render": r"^MATERIAL_RECTANGULAR_STAGING: [1-9][0-9]* assertions, 0 failures$",
        "test_material_presentation_render": r"^MATERIAL_PRESENTATION_RENDER: actual pixels passed ",
        "test_pubpres_transition_history_render": r"^PUBPRES_TRANSITION_HISTORY staging_slots=[1-3] checks=[1-9][0-9]* failures=0$",
        "run_material_threaded_publication": r"^MATERIAL_THREADED_PUBLICATION: [1-9][0-9]* assertions, 0 failures$",
    }
    markers = {
        "test_failed_world_status_survives": "FAILED_WORLD_STATUS ",
        "test_workbench_material_delivery_timing": "MATERIAL_DELIVERY_TIMING_RESULT ",
        "test_workbench_combined_authoring": "WB_COMBINED_EVIDENCE ",
        "test_art_history_durability": "ART_HISTORY_DURABILITY_RESULT ",
        "test_material_staging_reachability": "MATERIAL_STAGING_REACHABILITY_RESULT ",
        "test_native_pixel_camera": "NATIVE_PIXEL_CAMERA_RESULT ",
    }
    try:
        if test in SAME_FRAME_COMPLETIONS:
            marker, schema, checks = SAME_FRAME_COMPLETIONS[test]
            result = terminal_json(text, marker)
            if (result.get("schema") != schema or result["checks"] != checks
                    or not isinstance(result.get("failures"), list) or result["failures"] != []):
                raise ValueError("Same-frame/publication schema or complete assertion count differs")
        elif test in patterns:
            if len(re.findall(patterns[test], text, re.M)) != 1:
                raise ValueError("Missing or repeated successful assertion footer")
        elif test in markers:
            result = terminal_json(text, markers[test])
            if test == "test_workbench_combined_authoring" and result.get("reopen_complete" if reopen else "author_complete") is not True:
                raise ValueError("Requested author/reopen transaction incomplete")
            if test == "test_failed_world_status_survives" and not all(result.get("sections", {}).values()):
                raise ValueError("Native failure-control section incomplete")
        else:
            raise ValueError("Unregistered regression case")
    except (ValueError, TypeError, KeyError) as error:
        errors.append(str(error))
    return errors


def combined_evidence(text, project, native_sha, screenshots, *, graphical, reopen, same_frame="off"):
    result = terminal_json(text, "WB_COMBINED_EVIDENCE ")
    if result.get("schema") != "workbench-combined-authoring-v2":
        raise ValueError("Combined authoring evidence schema differs")
    continuation = validate_continuation_evidence(result.get("same_frame_continuation"), same_frame)
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


def run(command, environment, folder, timeout):
    folder.mkdir(parents=True)
    start = time.monotonic()
    outcome = {"command": command, "timeout_seconds": timeout, "returncode": None, "timed_out": False}
    try:
        with (folder / "stdout.log").open("w", encoding="utf-8") as stream:
            outcome["returncode"], outcome["timed_out"] = bounded_process(
                command, env=environment, stdout=stream, timeout=timeout)
    except BaseException as error:
        outcome["terminal_interruption"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        display_path = folder / "display-owner.json"
        if any(Path(str(arg)).name == "owned_xvfb.py" for arg in command):
            outcome["display_wrapper_sha256"] = digest(next(Path(str(arg)) for arg in command
                                                           if Path(str(arg)).name == "owned_xvfb.py"))
            try:
                display = json.loads(display_path.read_text(encoding="utf-8"))
                outcome["display_owner_sha256"] = digest(display_path)
                outcome["display_owner_verified"] = bool(display.get("schema") == "pubpres-owned-display-v1"
                    and display.get("server_reaped") is True and display.get("forced_server_kill") is False
                    and display.get("server_tree_closed") is True and display.get("unexpected_server_members") is False
                    and display.get("server_returncode") in (0, -15)
                    and display.get("server_alive_before_requested_shutdown") is True
                    and display.get("application_returncode") == 0 and display.get("returncode") == 0
                    and display.get("application_timeout") is False and display.get("failure") is None)
            except (ValueError, OSError) as error:
                outcome.update(display_owner_verified=False, display_owner_error=str(error))
            if not outcome["display_owner_verified"] and outcome["returncode"] == 0:
                outcome["returncode"] = 125
        outcome.update(elapsed_seconds=time.monotonic() - start, log_sha256=digest(folder / "stdout.log"))
        (folder / "process.json").write_text(json.dumps(outcome, indent=2) + "\n")
    return outcome


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--headless-only", action="store_true")
    parser.add_argument("--display-wrapper", type=Path)
    args = parser.parse_args()
    root = args.source_root.resolve()
    output = args.output.resolve()
    if output.exists():
        raise ValueError("Keep original evidence; use a fresh output directory")
    source = git(root, "rev-parse", "HEAD")
    runtime = args.runtime.resolve()
    record = json.loads((runtime / "PUBPRES-RUNTIME.json").read_text())
    platform = "windows" if os.name == "nt" else "linux"
    filename = "cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so"
    if (record.get("schema") != "pubpres-playability-native-build-v1" or record.get("returncode") != 0
            or record.get("platform") != platform or record.get("source_commit") != source
            or record.get("source_tree") != git(root, "rev-parse", "HEAD^{tree}")
            or record.get("source_inputs_sha256") != committed_inputs(root, source)
            or record.get("runtime_file") != filename or digest(runtime / filename) != record.get("runtime_sha256")
            or (runtime / filename).stat().st_size != record.get("runtime_bytes")):
        raise ValueError("Native candidate is not this exact source/platform/input closure")
    dependency_custody.verify(runtime, record)
    dependency_custody.verify_driver(Path(__file__).parent, record)
    engine = args.engine.resolve()
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    if version != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Incorrect Godot version")
    rapier_manifest = root / ("godot/addons/godot-rapier2d/runtime-provenance.windows.json" if os.name == "nt"
                              else "godot/addons/godot-rapier2d/runtime-provenance.linux.json")
    rapier = json.loads(rapier_manifest.read_text())
    if digest(root / rapier["artifact"]) != rapier["sha256"]:
        raise ValueError("Rapier runtime is absent or differs")
    output.mkdir(parents=True)
    project = stage_source(root, source, output)
    shutil.copyfile(runtime / filename, project / "addons/cybersand_native/bin" / filename)
    shutil.copyfile(root / rapier["artifact"], project / Path(rapier["artifact"]).relative_to("godot"))
    source_files = {p.relative_to(output).as_posix(): digest(p) for directory in (project, output / "examples")
                    for p in directory.rglob("*") if p.is_file()}
    common = {k: v for k, v in os.environ.items() if not k.startswith(("CYBERSAND_", "WB_COMBINED_"))}
    common.update(CYBERSAND_SOURCE_REVISION=source, CYBERSAND_MATERIAL_PUBLICATION="blit",
                  CYBERSAND_DIAG_SAME_FRAME_CONTINUATION="0")
    outcomes = []
    def invoke(label, options, graphical=False, pool="eager", receipt_env=None, profile_key=None,
               reopen=False, same_frame=None):
        profile = output / ((profile_key or label) + "-profile")
        profile.mkdir(exist_ok=True)
        environment = dict(common, APPDATA=str(profile), LOCALAPPDATA=str(profile),
                           XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile), XDG_CACHE_HOME=str(profile),
                           CYBERSAND_DIAG_MATERIAL_POOL_POLICY=pool)
        environment["CYBERSAND_MATERIAL_QUEUE_THREAD"] = (
            options[options.index("--render-thread") + 1] if "--render-thread" in options else "safe")
        policy = continuation_policy(same_frame) if same_frame is not None else None
        if policy is not None:
            environment.update(policy["selectors"])
        environment["CYBERSAND_TEST_ARTIFACT_DIR"] = str(output / label / "receipts")
        if reopen:
            environment["WB_COMBINED_REOPEN"] = "1"
        if receipt_env:
            environment[receipt_env] = str(output / (label + ".json"))
        command = [str(engine), "--path", str(project), "--audio-driver", "Dummy", *options]
        if graphical and args.display_wrapper:
            if args.display_wrapper.suffix == ".py":
                command = [sys.executable, str(args.display_wrapper), *command]
            else:
                command = [str(args.display_wrapper), "-a", "-s", "-screen 0 1920x1080x24", *command]
            environment["PUBPRES_DISPLAY_RECEIPT"] = str(output / label / "display-owner.json")
        test = Path(options[options.index("--script") + 1]).stem if "--script" in options else "import"
        if test == "test_workbench_combined_authoring":
            environment.update(WB_COMBINED_SIDE="512", WB_COMBINED_WORKERS="1",
                               WB_COMBINED_REOPEN="1" if reopen else "0",
                               WB_COMBINED_SAME_FRAME=same_frame,
                               WB_COMBINED_REQUIRE_GRAPHICS="1" if graphical else "0",
                               WB_COMBINED_SCREENSHOTS=str(output / label / "screenshots"))
        item = run(command, environment, output / label, 600 if test == "test_workbench_combined_authoring" else 300)
        log_text = (output / label / "stdout.log").read_text(encoding="utf-8", errors="replace")
        item["validation_errors"] = validate_completion(test, log_text, item["returncode"], reopen=reopen)
        if test == "test_workbench_combined_authoring":
            try:
                item["authoring_evidence"] = combined_evidence(log_text, project, record["runtime_sha256"],
                    output / label / "screenshots", graphical=graphical, reopen=reopen, same_frame=same_frame)
                if reopen:
                    previous = next(x for x in outcomes if x["label"] == profile_key)
                    if item["authoring_evidence"]["prepared_sha256"] != previous.get("authoring_evidence", {}).get("prepared_sha256"):
                        raise ValueError("Reopened complete native material plane differs from previous process")
            except (ValueError, TypeError, KeyError, OSError, StopIteration) as error:
                item["validation_errors"].append(str(error))
        if receipt_env:
            try:
                receipt = json.loads((output / (label + ".json")).read_text())
                if receipt.get("failures") != [] or receipt.get("checks", 0) <= 0:
                    raise ValueError("Requested receipt did not complete assertions")
                if test == HEADLESS[0]:
                    if receipt.get("complete") is not True or receipt.get("source") != source or receipt.get("checks") != 222:
                        raise ValueError("Native probe receipt differs")
                else:
                    if (receipt.get("schema") != "material-staging-reachability-v1" or receipt.get("source_sha") != source
                            or receipt.get("engine_sha256") != digest(engine)
                            or receipt.get("render_thread_inline") != (environment["CYBERSAND_MATERIAL_QUEUE_THREAD"] == "safe")
                            or len(receipt.get("observations", [])) != 23 or len(receipt.get("queued_observations", [])) != 12
                            or any(not r.get("all_histories_verified") for r in receipt["observations"])
                            or any(not r.get("verified") for r in receipt["queued_observations"])
                            or receipt.get("display") == "headless"
                            or receipt.get("driver") != ("opengl3_angle" if os.name == "nt" else "opengl3")):
                        raise ValueError("Actual GPU receipt identity, coverage or ownership differs")
                    if set(receipt.get("source_files", {})) != {"res://scripts/blit_material_publisher.gd", "res://tests/test_material_staging_reachability.gd"}:
                        raise ValueError("GPU fixture source inventory differs")
                    if any(r.get("current_sha256") != r.get("expected_current_sha256")
                           or r.get("previous_sha256") != r.get("expected_previous_sha256")
                           for r in receipt["observations"] + receipt["queued_observations"]):
                        raise ValueError("Actual GPU history differs from its independent expected bytes")
                    for relative, wanted in receipt["source_files"].items():
                        if digest(project / relative.removeprefix("res://")) != wanted:
                            raise ValueError("GPU fixture source differs")
            except (ValueError, TypeError, KeyError, OSError) as error:
                item["validation_errors"].append(str(error))
        item.update(label=label, graphical=graphical, pool=pool)
        if policy is not None:
            item["same_frame_continuation_policy"] = policy
        (output / label / "process.json").write_text(json.dumps(item, indent=2) + "\n")
        outcomes.append(item)
        print(json.dumps({k: item[k] for k in ("label", "returncode", "timed_out", "elapsed_seconds")}), flush=True)
        return item["returncode"] == 0 and not item["timed_out"] and not item["validation_errors"]
    imported = invoke("import", ["--headless", "--editor", "--import"])
    if imported:
        for test in HEADLESS:
            graphical = test == "test_workbench_combined_authoring" and not args.headless_only
            display = (["--rendering-method", "gl_compatibility", "--rendering-driver",
                        "opengl3_angle" if os.name == "nt" else "opengl3", "--render-thread", "safe"]
                       if graphical else ["--headless"])
            if test == "test_workbench_combined_authoring":
                invoke_authoring_pairs(invoke, display, graphical)
            else:
                invoke(test, [*display, "--script", "res://tests/" + test + ".gd"], graphical=graphical,
                       receipt_env="CYBERSAND_PUBPRES_NATIVE_PROBE_OUTPUT" if test == HEADLESS[0] else None)
        for label, test, mode in SAME_FRAME_HEADLESS:
            invoke(label, ["--headless", "--script", "res://tests/" + test + ".gd"], same_frame=mode)
        if not args.headless_only:
            driver = "opengl3_angle" if os.name == "nt" else "opengl3"
            for test, thread, pool in GRAPHICS:
                invoke(test + "-" + thread + "-" + pool,
                       ["--rendering-method", "gl_compatibility", "--rendering-driver", driver,
                        "--render-thread", thread, "--script", "res://tests/" + test + ".gd"],
                       graphical=True, pool=pool, receipt_env="CYBERSAND_MATERIAL_STAGING_REACHABILITY_OUTPUT"
                       if test == "test_material_staging_reachability" else None)
    # Expand the one combined-authoring entry into separate author/reopen pairs.
    expected = (1 + len(HEADLESS) - 1 + 2 * len(AUTHORING_MODES) + len(SAME_FRAME_HEADLESS)
                + (0 if args.headless_only else len(GRAPHICS)))
    complete = imported and len(outcomes) == expected and all(
        x["returncode"] == 0 and not x["timed_out"] and not x["validation_errors"] for x in outcomes)
    summary = {"schema": "pubpres-scoped-regressions-v2", "source_commit": source,
               "source_tree": record["source_tree"], "native_runtime": record,
               "rapier_sha256": rapier["sha256"], "engine_version": version, "engine_sha256": digest(engine),
               "headless_only": args.headless_only, "complete": complete, "outcomes": outcomes,
               "expected_cases": expected, "staged_source_sha256": source_files,
               "authoring_modes": list(AUTHORING_MODES),
               "same_frame_cases": [{"label": label, "test": test, "mode": mode}
                                    for label, test, mode in SAME_FRAME_HEADLESS]}
    (output / "SUMMARY.json").write_text(json.dumps(summary, indent=2) + "\n")
    # Application copies are reproducible from the source and runtime receipts;
    # retain the smaller original logs/profiles, never confuse them with a ZIP.
    shutil.rmtree(project)
    shutil.rmtree(output / "examples")
    return 0 if complete else 1


if __name__ == "__main__":
    sys.exit(main())
