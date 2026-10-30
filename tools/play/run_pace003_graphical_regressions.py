#!/usr/bin/env python3
"""Run focused real-display regressions after the original PACE003 campaign.

Each required fixture has one fresh process and the unchanged 180-second cap.
These are correctness/lifecycle oracles, not additional PACE measurements, FPS
or physical-device qualification. Original campaign evidence is read-only.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

import run_pace003_campaign as campaign

runner = campaign.runner
require = campaign.require
SCHEMA = "play-pace003-graphical-regressions-v1"
CASES = (
    ("test_play_life007_failed_session_restart", "PLAY_LIFE007_RESULT ", 151),
    ("test_play_life008_recovery_navigation", "PLAY_LIFE008_RESULT ", 62),
    ("test_play_ui005_session_selection", "PLAY_UI005_RESULT ", 90),
    ("test_play_ui003_physics_cadence", "PLAY_UI003_PHYSICS_RESULT ", 41),
    ("test_material_presentation_render", "MATERIAL_PRESENTATION_RENDER: ", 0),
    ("test_material_vapour_pipeline_render", "MATERIAL_VAPOUR_PIPELINE: ", 26),
    ("test_water_presentation_render", "WATER_PRESENTATION_RENDER: ", 0),
)
MATERIAL_SUCCESS = ("actual pixels passed (time override, still scenery, anchoring, crossfade endpoints, "
                    "conditions, all 132 ID slots, invalid bounds, growth blockers, vapour footprint, "
                    "half-resolution single-cell fireworks)")
WATER_SUCCESS = "actual pixels coverage=2/4 at 2x, 8/16 at 4x; oriented right edge passed"
SOURCE_KEYS = ("source_sha", "source_tree", "source_mode", "source_delta_paths", "execution_inputs")
FORBIDDEN_ENV = ("LD_AUDIT", "LD_PRELOAD", "CYBERSAND_GL_TRACE_DIR", "CYBERSAND_ATLAS_SHADER",
                 "CYBERSAND_PACE003_DIAGNOSTIC_VARIANT")


def inventory(directory: Path) -> dict:
    """Retain hashes of original bytes, including timeout captures; reject links."""
    require(directory.is_dir() and not directory.is_symlink(), "Missing/non-directory evidence")
    files = {}
    for path in sorted(directory.rglob("*")):
        require(not path.is_symlink(), "Evidence must not contain symbolic links")
        if path.is_file():
            files[path.relative_to(directory).as_posix()] = {
                "size": path.stat().st_size, "sha256": runner.sha256(path)}
    return files


def case_for(name: str, driver: str):
    return runner.Case(name, ("--rendering-driver", driver, "--script", f"res://tests/{name}.gd"),
                       180, 0, True)


def check_result(name: str, raw: str) -> dict:
    spec = next(item for item in CASES if item[0] == name)
    lines = [line[len(spec[1]):] for line in raw.splitlines() if line.startswith(spec[1])]
    require(len(lines) == 1, name + ": missing or duplicate original success marker")
    if name == "test_material_presentation_render":
        require(lines[0] == MATERIAL_SUCCESS, "Material pixel oracle incomplete")
        return {"actual_pixels": True, "material_slots": 132, "marker": lines[0]}
    if name == "test_water_presentation_render":
        require(lines[0] == WATER_SUCCESS, "Water pixel oracle incomplete")
        return {"actual_pixels": True, "marker": lines[0]}
    if name == "test_material_vapour_pipeline_render":
        match = re.fullmatch(r"actual pixels, ([0-9]+) assertions, 0 failures", lines[0])
        require(match is not None and int(match[1]) >= spec[2], "Vapour pixel oracle incomplete")
        return {"actual_pixels": True, "assertions": int(match[1]), "failures": 0}
    result = campaign.load_json(lines[0])
    require(type(result) is dict and type(result.get("failures")) is int and result["failures"] == 0
            and type(result.get("assertions")) is int and result["assertions"] >= spec[2],
            name + ": incomplete/failed assertions")
    if name.endswith("life007_failed_session_restart"):
        require(result.get("retries") == 0 and result.get("real_native_failure") is True
                and result.get("synthesized_failure") is False
                and result.get("native_healthy_guard_changed") is False
                and result.get("injected_setting_restored_before_first_ready") is True
                and result.get("internal_budget_ms") == 150000, "LIFE007 fixture contract changed")
        rows = result.get("rows", [])
        require([row.get("rig") for row in rows] == list(campaign.RIGS), "LIFE007 omitted a preset")
        require(all(all(row.get(key) is True for key in (
            "old_worker_joined", "old_worker_destroyed", "old_adapter_destroyed", "recovered_owner_joined"))
                    and campaign.numeric(row.get("recovery_usec"), 1) for row in rows),
                "LIFE007 owner retirement/recovery missing")
    elif name.endswith("life008_recovery_navigation"):
        require(result.get("retries") == 0 and result.get("real_native_failure") is True
                and result.get("synthetic_world") is False and result.get("native_jobs_held") is False
                and result.get("maximum_observed_live_owners") == 1 and result.get("ready_hosts") == 6
                and result.get("internal_budget_ms") == 150000, "LIFE008 owner/navigation contract changed")
        rows = result.get("rows", [])
        require([row.get("ordering") for row in rows] == [
            "restart_then_f2", "f2_then_restart", "pending_reload_then_f2"], "LIFE008 omitted an ordering")
        require(all(all(row.get(key) is True for key in (
            "old_owner_joined", "accepted_and_pending_graphs_retired", "old_worker_destroyed",
            "old_adapter_destroyed", "normal_selector_reentry")) and row.get("ready_hosts") == 2
                    for row in rows), "LIFE008 incomplete retirement or reentry")
        require(rows[2].get("actual_pending_reload_observed") is True,
                "LIFE008 did not observe the real deferred scene transition")
    elif name.endswith("ui005_session_selection"):
        require(result.get("retries") == 0 and result.get("accepted_sessions") == 5
                and result.get("policy_retaining_resets") == 5 and result.get("native_refusals") == 1
                and result.get("window_layout_checked") is True
                and result.get("real_host") == "main.tscn+CyberSimulationWorker+main-thread-Rapier",
                "UI005 graphical all-preset session/refusal coverage incomplete")
        require([row.get("rig") for row in result.get("rows", [])] == list(campaign.RIGS),
                "UI005 omitted a preset")
    else:
        require(result.get("real_host_completed_step_visits") == 1
                and result.get("negative_control_render_only") == 1 and result.get("model_only") is False
                and result.get("test_only_rapier_fixture_reposition") is True
                and result.get("source") == "original-course+existing-native-worker+real-rapier",
                "UI003 real step/pause/stale epoch or negative control missing")
    return result


def check_process(process: dict, raw: str, name: str, driver: str,
                  platform_name: str | None = None, checkout_root: str | None = None) -> None:
    require(process.get("name") == name and process.get("requires_display") is True
            and process.get("status") == "passed" and process.get("returncode") == 0
            and process.get("timeout_seconds") == 180 and process.get("timeout_kind") is None
            and process.get("diagnostic_error") is False and process.get("skip_messages") == []
            and all(process.get(key) is None for key in (
                "launch_error", "capture_error", "timeout_diagnostic_error")),
            name + ": nonpassing, skipped or differently bounded process")
    command = process.get("command", [])
    require(type(command) is list and bool(command), "Missing graphical command")
    target = "win32" if platform_name == "Windows" else "linux" if platform_name == "Linux" else sys.platform
    expected = runner.case_command(command[0], case_for(name, driver), target)
    path_index = expected.index("--path") + 1
    recorded_root = checkout_root or str(campaign.ROOT)
    require(recorded_root.startswith("/") or re.match(r"^[A-Za-z]:[\\/]", recorded_root) is not None,
            "Recorded checkout root is not absolute")
    expected[path_index] = recorded_root.rstrip("/\\").replace("\\", "/") + "/godot"
    normalized = command.copy()
    if len(normalized) > path_index:
        normalized[path_index] = normalized[path_index].replace("\\", "/")
    require(normalized == expected
            and "--headless" not in command, "Wrong graphical fixture/renderer command")
    require("SCRIPT ERROR:" not in raw and "ERROR:" not in raw
            and re.search(r"\bskipped\b|^\s*SKIP\b", raw, re.I | re.M) is None,
            "Original process log contains error or skip")
    require(re.search(r"OpenGL API .+Compatibility.+Using Device:", raw) is not None,
            "Original engine log lacks an actual OpenGL Compatibility device")


def check_cache(row: dict, directory: Path, platform_name: str) -> None:
    # Existing fixtures do not expose OS.get_user_data_dir; do not fabricate an
    # engine-observed path. The retained process environment and inventories
    # establish private directories, and this limitation remains in the report.
    receipt, name = row["cold_cache"], row["name"]
    require(receipt.get("schema") == campaign.CACHE_SCHEMA and receipt.get("row") == name
            and receipt.get("fresh_process") is True and receipt.get("complete") is True
            and receipt.get("project_restored") is True
            and receipt.get("project_at_launch") == {"present": False, "files": {}},
            "Incomplete per-case cache isolation")
    keys = campaign.PRIVATE_CACHE_DIRECTORIES[platform_name]
    require(receipt.get("private_at_launch") == {key: {"present": True, "files": {}} for key, _ in keys},
            "Private user/cache directories were not empty at launch")
    root = directory / "cache" / name
    require(campaign.load_json((root / "receipt.json").read_text(encoding="utf-8")) == receipt,
            "Cache receipt differs from retained original")
    require(campaign.cache_inventory(root / "generated-project-cache") == receipt["generated_project"],
            "Generated project cache differs")
    for key, folder in keys:
        require(row["environment"].get(key) == receipt["private_paths"].get(key)
                and campaign.cache_inventory(root / folder) == receipt["generated_private"][key],
                "Private environment/cache differs")


def check_pixels(name: str, directory: Path) -> dict:
    expected = ("material-id-slots-000-131.png",) if name == "test_material_presentation_render" else (
        "vapour-seeded.exr", "vapour-decayed.exr", "vapour-reset.exr"
    ) if name == "test_material_vapour_pipeline_render" else ()
    files = inventory(directory)
    require(set(files) == set(expected), "Missing/unexpected retained pixel evidence: " + name)
    for filename in expected:
        data = (directory / filename).read_bytes()
        if filename.endswith(".png"):
            require(len(data) > 24 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR"
                    and struct.unpack(">II", data[16:24]) == (576, 264), "Invalid retained material PNG")
        else:
            require(len(data) > 32 and data[:4] == b"\x76\x2f\x31\x01", "Invalid retained float framebuffer")
    return files


def verify_directory(directory: Path, preceding_campaign: Path | None = None) -> dict:
    report = campaign.load_json((directory / "regressions.json").read_text(encoding="utf-8"))
    require(report.get("schema") == SCHEMA and report.get("status") == "passed"
            and report.get("errors") == [] and report.get("retries") == 0
            and report.get("source_unchanged") is True and report.get("runtime_unchanged") is True
            and report.get("preceding_campaign_unchanged") is True
            and report.get("source_mode") == "clean-recorded-inputs"
            and report.get("pace_measurement") is False, "Graphical regression campaign did not pass")
    require(report.get("platform") in ("Linux", "Windows")
            and report.get("rendering_driver") == ("opengl3_angle" if report["platform"] == "Windows" else "opengl3")
            and report.get("godot_version") == campaign.GODOT_VERSION, "Original platform/engine controls changed")
    require([row.get("name") for row in report.get("rows", [])] == [case[0] for case in CASES],
            "Required graphical fixture omitted, repeated or reordered")
    for row in report["rows"]:
        require(row.get("attempt") == 1 and row.get("errors") == [], "Fixture retried or failed")
        path = directory / (row["name"] + ".log")
        require(row["process"].get("log") == path.name and runner.sha256(path) == row["log_sha256"],
                "Original graphical log identity/hash differs")
        raw = path.read_text(encoding="utf-8")
        check_process(row["process"], raw, row["name"], report["rendering_driver"],
                      report["platform"], report["checkout_root"])
        require(check_result(row["name"], raw) == row["result"], "Result differs from original marker")
        check_cache(row, directory, report["platform"])
        require(check_pixels(row["name"], directory / "pixels" / row["name"]) == row["pixels"],
                "Original pixel evidence differs")
    require(inventory(directory / "preceding-campaign") == report["preceding_campaign_receipt_files"],
            "Retained preceding-campaign manifest changed")
    prior_directory = preceding_campaign or directory.parent / "campaign"
    prior_files = campaign.load_json((directory / "preceding-campaign/original-files.json").read_text(encoding="utf-8"))
    require(inventory(prior_directory) == prior_files
            and runner.sha256(prior_directory / "campaign.json") == report["preceding_campaign_sha256"],
            "Original PACE first-attempt evidence changed")
    prior = campaign.load_json((prior_directory / "campaign.json").read_text(encoding="utf-8"))
    require(all(prior.get(key) == report.get(key) for key in (*SOURCE_KEYS, "runtimes", "godot_sha256", "godot_version"))
            and prior.get("status") == report["preceding_campaign_status"]
            and dt.datetime.fromisoformat(prior["finished_utc"]) <= dt.datetime.fromisoformat(report["started_utc"]),
            "Graphical source/runtime or ordering differs from original PACE")
    require({name: value for name, value in inventory(directory).items() if name != "regressions.json"}
            == report["artifact_files"], "Original graphical evidence files changed")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--preceding-campaign", required=True, type=Path)
    parser.add_argument("--rendering-driver", required=True, choices=("opengl3", "opengl3_angle"))
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.preceding_campaign = args.preceding_campaign.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    report = {"schema": SCHEMA, "status": "failed", "errors": [], "rows": [], "retries": 0,
              "pace_measurement": False, "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
              "platform": "Windows" if sys.platform == "win32" else "Linux",
              "checkout_root": str(campaign.ROOT),
              "rendering_driver": args.rendering_driver, "command": [sys.executable, *sys.argv],
              "qualification_scope": "Existing graphical correctness/lifecycle fixtures after original PACE003",
              "limitations": ["No FPS or pacing measurement", "No physical keyboard/gamepad or human feel qualification",
                              "UI005 focus/device enumeration and UI003 fixture reposition retain explicit test seams",
                              "Private cache paths selected through environment; fixtures do not report engine user-data path",
                              "Windows OS/D3D and other driver caches remain uncontrolled"]}
    before = runtimes = prior_files = None
    try:
        require(sys.platform == "win32" or sys.platform.startswith("linux"), "Unsupported platform")
        require(args.rendering_driver == ("opengl3_angle" if sys.platform == "win32" else "opengl3"),
                "Platform renderer differs from original PACE003 controls")
        require(not any(os.environ.get(key) for key in FORBIDDEN_ENV), "Diagnostic instrumentation in qualification environment")
        require(not args.output.is_relative_to(args.preceding_campaign)
                and not args.preceding_campaign.is_relative_to(args.output), "Evidence directories must be disjoint")
        before = campaign.source_identity()
        report.update(before)
        require(before["source_mode"] == "clean-recorded-inputs", "Qualification needs committed exact source")
        runtimes = campaign.runtime_identity()
        report["runtimes"] = runtimes
        report["godot_sha256"] = runner.sha256(Path(args.godot))
        report["godot_version"] = subprocess.check_output([args.godot, "--version"], text=True, timeout=30).strip()
        require(report["godot_version"] == campaign.GODOT_VERSION, "Pinned engine version differs")
        prior = campaign.load_json((args.preceding_campaign / "campaign.json").read_text(encoding="utf-8"))
        require(prior.get("schema") == campaign.SCHEMA and prior.get("status") in ("passed", "failed")
                and dt.datetime.fromisoformat(prior["finished_utc"]) <= dt.datetime.fromisoformat(report["started_utc"])
                and all(prior.get(key) == before[key] for key in SOURCE_KEYS)
                and prior.get("runtimes") == runtimes and prior.get("godot_sha256") == report["godot_sha256"]
                and prior.get("godot_version") == campaign.GODOT_VERSION
                and prior.get("config", {}).get("headless") is False
                and prior["config"].get("rendering_driver") == args.rendering_driver
                and prior.get("import", {}).get("status") == "passed",
                "Original PACE campaign must finish first on these exact source/runtime/renderer inputs")
        if prior["status"] == "passed":
            campaign.verify_directory(args.preceding_campaign)
        prior_files = inventory(args.preceding_campaign)
        receipts = args.output / "preceding-campaign"
        receipts.mkdir()
        runner.write_json(receipts / "original-files.json", prior_files)
        report["preceding_campaign_receipt_files"] = inventory(receipts)
        report["preceding_campaign_status"] = prior["status"]
        report["preceding_campaign_sha256"] = runner.sha256(args.preceding_campaign / "campaign.json")
        env = os.environ.copy()
        env["CYBERSAND_SOURCE_REVISION"] = before["source_sha"]
        with (args.output / "runner-transcript.txt").open("w", encoding="utf-8") as transcript:
            for name, _marker, _assertions in CASES:
                row = {"name": name, "attempt": 1, "errors": []}
                report["rows"].append(row)
                try:
                    pixels = args.output / "pixels" / name
                    pixels.mkdir(parents=True)
                    env["CYBERSAND_PRESENTATION_EVIDENCE"] = str(pixels)
                    with campaign.cold_cache_environment(args.output, name, env) as (child_env, cache):
                        row["cold_cache"] = cache
                        row["environment"] = {key: child_env.get(key) for key in (
                            "CYBERSAND_SOURCE_REVISION", "CYBERSAND_PRESENTATION_EVIDENCE",
                            "DISPLAY", "LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GALLIVM_PERF",
                            *[key for key, _ in campaign.PRIVATE_CACHE_DIRECTORIES[report["platform"]]])}
                        runner.write_json(args.output / "regressions.json", report)
                        with contextlib.redirect_stdout(transcript):
                            process, failed = runner.run_case(args.godot, case_for(name, args.rendering_driver),
                                                             args.output, "pace003-graphical-correctness", env=child_env)
                        row["process"] = process
                        row["log_sha256"] = runner.sha256(args.output / process["log"])
                    require(not failed, name + ": first-attempt process failed")
                    raw = (args.output / process["log"]).read_text(encoding="utf-8")
                    check_process(process, raw, name, args.rendering_driver)
                    row["result"] = check_result(name, raw)
                    check_cache(row, args.output, report["platform"])
                    row["pixels"] = check_pixels(name, pixels)
                except Exception as exc:
                    error = name + ": " + type(exc).__name__ + ": " + str(exc)
                    row["errors"].append(error)
                    report["errors"].append(error)
                print(json.dumps({"case": name, "errors": row["errors"], "attempt": 1}), flush=True)
                runner.write_json(args.output / "regressions.json", report)
                require(campaign.source_identity() == before and campaign.runtime_identity() == runtimes,
                        "Source/runtime changed between required graphical cases")
    except Exception as exc:
        report["errors"].append(type(exc).__name__ + ": " + str(exc))
    finally:
        for key, expected, current in (
            ("source_unchanged", before, campaign.source_identity),
            ("runtime_unchanged", runtimes, campaign.runtime_identity),
            ("preceding_campaign_unchanged", prior_files, lambda: inventory(args.preceding_campaign)),
        ):
            try:
                report[key] = expected is not None and current() == expected
            except Exception as exc:
                report[key] = False
                report["errors"].append(key + ": " + str(exc))
            if not report[key]:
                report["errors"].append(key + ": identity fence failed")
        report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        report["status"] = "failed" if report["errors"] else "passed"
        report["artifact_files"] = {name: value for name, value in inventory(args.output).items()
                                    if name != "regressions.json"}
        runner.write_json(args.output / "regressions.json", report)
    if report["status"] == "passed":
        try:
            verify_directory(args.output, args.preceding_campaign)
        except Exception as exc:
            report["status"] = "failed"
            report["errors"].append(type(exc).__name__ + ": " + str(exc))
            runner.write_json(args.output / "regressions.json", report)
    print("PLAY_PACE003_GRAPHICAL_REGRESSIONS " + json.dumps({"status": report["status"],
          "cases": len(report["rows"]), "errors": report["errors"],
          "report_sha256": runner.sha256(args.output / "regressions.json")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
