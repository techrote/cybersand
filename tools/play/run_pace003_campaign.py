#!/usr/bin/env python3
"""Measure the actual composed desktop host with one-worker and Auto controls.

Every row is one fresh process, <=180 seconds, with no retries. Graphical rows
observe RenderingServer frame_post_draw submissions, not physical scanout or
human feel. The exact native/Rapier retained provenance must match local inputs.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import json
import math
import os
from pathlib import Path
import platform
import re
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import check_repository
import run_godot_regressions as runner
import run_windows_godot_regressions as windows

SCHEMA = "play-pace003-campaign-v1"
MARKER = "PLAY_PACE003_RESULT "
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
RIGS = ("stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel")
APPARATUS = (
    "godot/tests/play_pace003_shared_host.gd", "godot/tests/play_pace003_worker_probe.gd",
    "godot/tests/play_wait001_snapshot_probe.gd", "tools/play/run_pace003_campaign.py",
    "tools/play/test_pace003_campaign.py", ".github/workflows/play-pace003-host.yml",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def load_json(text: str) -> object:
    def unique(pairs):
        value = {}
        for key, item in pairs:
            require(key not in value, "Duplicate JSON key: " + key)
            value[key] = item
        return value

    def invalid(value):
        raise ValueError("Non-finite JSON number: " + value)

    return json.loads(text, object_pairs_hook=unique, parse_constant=invalid)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=60).strip()


def numeric(value: object, minimum: float = 0) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def stats(values: list) -> dict:
    require(all(numeric(value) for value in values), "Invalid nonnegative numeric samples")
    if not values:
        return {"count": 0, "mean": None, "p50": None, "p95": None, "p99": None, "max": None}
    ordered = sorted(values)
    return {"count": len(values), "mean": sum(values) / len(values),
            "p50": ordered[math.ceil(len(values) * .50) - 1],
            "p95": ordered[math.ceil(len(values) * .95) - 1],
            "p99": ordered[math.ceil(len(values) * .99) - 1], "max": ordered[-1]}


def intervals(values: list) -> list:
    require(all(type(value) is int and value >= 0 for value in values), "Invalid monotonic timestamp")
    result = [after - before for before, after in zip(values, values[1:])]
    require(all(value > 0 for value in result), "Timestamps must strictly increase")
    return result


def verify_row(value: dict, expected: dict) -> dict:
    require(isinstance(value, dict) and value.get("schema") == "play-pace003-shared-host-v1",
            "Missing apparatus row")
    for key in ("rig", "requested_workers", "policy_preset", "sample_seconds"):
        require(type(value.get(key)) is type(expected[key]) and value[key] == expected[key],
                "Row configuration differs: " + key)
    require(value.get("source_revision") == expected["source_sha"], "Row source differs")
    require(value.get("requested_rendering_driver") == expected["rendering_driver"],
            "Requested rendering driver differs")
    require(value.get("failures") == 0 and type(value.get("assertions")) is int
            and value["assertions"] == (15 if expected["headless"] else 17)
            and value.get("workers_joined") == 1 and value.get("rapier_sessions_retired") == 1
            and value.get("retries") == 0 and value.get("native_rows_overflow") is False,
            "Assertions, retirement, retry or sample-capacity failure")
    require(type(value.get("started_usec")) is int and type(value.get("ended_usec")) is int
            and value["ended_usec"] - value["started_usec"] == value.get("elapsed_usec")
            and value["elapsed_usec"] >= expected["sample_seconds"] * 1_000_000,
            "Incomplete measurement window")
    for initial, final, count, rate in (
        ("initial_main_native_tick", "final_main_native_tick", "native_ticks_observed_by_main", "native_hz_observed_by_main"),
        ("initial_rapier_tick", "final_rapier_tick", "rapier_ticks", "rapier_hz"),
    ):
        require(type(value.get(initial)) is int and type(value.get(final)) is int
                and type(value.get(count)) is int and value[count] > 0
                and value[final] - value[initial] == value[count]
                and numeric(value.get(rate))
                and math.isclose(value[rate], value[count] * 1_000_000 / value["elapsed_usec"], rel_tol=1e-6),
                "Completed-clock counts/rate disagree: " + count)
    require(value.get("viewport") == [960, 540] and value.get("canvas") == [960, 540],
            "Viewport/canvas dimensions differ")
    require(value.get("platform") == expected["platform"]
            and bool(value.get("cpu_name")) and numeric(value.get("logical_processors"), 1)
            and value.get("godot", {}).get("hash", "").startswith("5b4e0cb0f"),
            "Missing host/runtime identity")
    graphical = not expected["headless"]
    require((value.get("display_server") != "headless") is graphical
            and value.get("scope", {}).get("frame_submissions_measured") is graphical
            and value["scope"].get("physical_scanout_measured") is False
            and value["scope"].get("human_feel") is False
            and value["scope"].get("native_jobs_held") is False,
            "Incorrect rendering/qualification classification")
    framebuffer = value.get("framebuffer", {})
    if graphical:
        require(framebuffer.get("captured") is True and framebuffer.get("width") == 960
                and framebuffer.get("height") == 540 and framebuffer.get("captured_after_sample") is True
                and framebuffer.get("different_from_top_left_rgb", 0) > 25
                and re.fullmatch(r"[0-9a-f]{64}", framebuffer.get("png_sha256", "")) is not None,
                "Ordinary graphical capture missing, blank, wrong dimensions or not retained")
    else:
        require(framebuffer == {"captured": False, "reason": "headless"}, "Headless cannot claim a framebuffer")
    require(re.fullmatch(r"[0-9a-f]{64}", value.get("course_recipe_hash", "")) is not None
            and value.get("receipt", {}).get("kind") == "applied_run"
            and value["receipt"].get("policy_hash") == value.get("policy", {}).get("policy_hash"),
            "Missing native applied policy/recipe receipt")
    for key in ("construction_usec", "reset_usec", "scene_retirement_usec", "stop_join_usec"):
        require(numeric(value.get(key)), "Missing bounded lifecycle latency: " + key)
    raw = value.get("raw", {})
    main_times = raw.get("main_started_usec", [])
    require(len(main_times) > 1, "No Main samples")
    intervals(main_times)
    for key in ("main_callback_usec", "snapshot_mutex_wait_usec", "snapshot_mutex_critical_usec"):
        require(len(raw.get(key, [])) == len(main_times), "Missing Main sample: " + key)
        stats(raw[key])
    require(len(raw.get("physics_callback_usec", [])) > 1, "No actual physics callbacks")
    stats(raw["physics_callback_usec"])
    frames = raw.get("rendered_usec", [])
    require((len(frames) > 1) if graphical else frames == [], "No graphical samples or false headless frames")
    intervals(frames)
    snapshots = raw.get("snapshot_rows", [])
    require(len(snapshots) == len(main_times), "Incomplete Main-visible snapshot samples")
    last_serial = -1
    last_tick = -1
    for sample in snapshots:
        require(sample.get("generation") == value["generation"] and sample.get("epoch") == value["actor_epoch"]
                and sample.get("failed") is False and sample.get("serial", -1) >= last_serial
                and sample.get("tick", -1) >= last_tick
                and 0 <= sample.get("render_tick", -1) <= sample["tick"]
                and numeric(sample.get("observed_usec")) and numeric(sample.get("published_usec"))
                and sample["observed_usec"] >= sample["published_usec"],
                "Stale/failed/nonmonotonic snapshot in measurement window")
        last_serial, last_tick = sample["serial"], sample["tick"]
    require(snapshots[0]["tick"] >= value["initial_main_native_tick"]
            and snapshots[-1]["tick"] == value["final_main_native_tick"],
            "Main snapshot series disagrees with clock endpoints")
    native = raw.get("native_rows", [])
    require(len(native) > 1, "No native completion series")
    require(value.get("native_completion_count") == len(native)
            and value.get("native_vs_main_boundary_difference") == len(native) - value["native_ticks_observed_by_main"],
            "Native count/boundary difference does not match observed series")
    last_tick = None
    last_completed = None
    for sample in native:
        require(sample.get("statistics_ok") is True and sample.get("generation") == value["generation"]
                and sample.get("actor_epoch") == value["actor_epoch"]
                and type(sample.get("tick")) is int
                and sample.get("native_completed_tick") == sample["tick"]
                and (last_tick is None or sample["tick"] == last_tick + 1)
                and type(sample.get("completed_usec")) is int
                and value["started_usec"] <= sample["completed_usec"] < value["ended_usec"]
                and (last_completed is None or sample["completed_usec"] > last_completed),
                "Native series is missing, duplicated, outside window or wrong generation")
        for key in ("native_ms", "worker_step_ms", "probe_usec", "workers_observed", "parallel_phases", "jobs", "overruns"):
            require(numeric(sample.get(key)), "Missing native metric: " + key)
        require(type(sample.get("capacity")) is int and sample["capacity"] >= 1
                and sample["workers_observed"] <= sample["capacity"], "Invalid native participant count")
        if expected["requested_workers"] == 1:
            require(sample["capacity"] == 1 and sample["parallel_phases"] == 0
                    and sample["workers_observed"] <= 1, "Serial control reported parallel work")
        last_tick, last_completed = sample["tick"], sample["completed_usec"]
    require(len({sample["capacity"] for sample in native}) == 1, "Worker capacity changed within row")
    return value


def reduce_row(value: dict) -> dict:
    raw = value["raw"]
    native, snapshots = raw["native_rows"], raw["snapshot_rows"]
    frame_intervals = intervals(raw["rendered_usec"])
    serials = [sample["serial"] for sample in snapshots]
    serial_deltas = [right - left for left, right in zip(serials, serials[1:])]
    observed_age = [sample["observed_usec"] - sample["published_usec"] for sample in snapshots]
    render_age = [sample["observed_usec"] - sample["render_generated_usec"] for sample in snapshots
                  if sample["render_generated_usec"] > 0]
    return {"native_tick_ms": stats([sample["native_ms"] for sample in native]),
            "native_completed_per_second": len(native) * 1_000_000 / value["elapsed_usec"],
            "native_observed_by_main_per_second": value["native_hz_observed_by_main"],
            "rapier_completed_per_second": value["rapier_hz"],
            "worker_step_ms": stats([sample["worker_step_ms"] for sample in native]),
            "native_probe_usec": stats([sample["probe_usec"] for sample in native]),
            "main_callback_interval_usec": stats(intervals(raw["main_started_usec"])),
            "main_callback_usec": stats(raw["main_callback_usec"]),
            "physics_callback_usec": stats(raw["physics_callback_usec"]),
            "snapshot_mutex_wait_usec": stats(raw["snapshot_mutex_wait_usec"]),
            "snapshot_mutex_critical_usec": stats(raw["snapshot_mutex_critical_usec"]),
            "render_submission_interval_usec": stats(frame_intervals),
            "render_submission_long_intervals": {
                str(threshold): {"count": sum(value > threshold for value in frame_intervals),
                                "fraction": sum(value > threshold for value in frame_intervals) / len(frame_intervals)
                                if frame_intervals else None}
                for threshold in (16667, 33333, 50000, 100000, 250000, 1000000)},
            "snapshot_age_usec": stats(observed_age), "render_payload_age_usec": stats(render_age),
            "snapshot_serials_coalesced_between_Main_reads": sum(max(0, value - 1) for value in serial_deltas),
            "Main_callbacks_retaining_same_snapshot": sum(value == 0 for value in serial_deltas),
            "native_minus_render_tick": stats([max(0, sample["tick"] - sample["render_tick"]) for sample in snapshots]),
            "worker_deadline_overruns_delta": native[-1]["overruns"] - native[0]["overruns"],
            "worker_backlog_note": "Overruns count deadline resets after >3 missed intervals; no unobserved queue depth inferred",
            "worker_capacity": native[0]["capacity"],
            "max_task_participants": max(sample["workers_observed"] for sample in native),
            "ticks_with_multiple_task_participants": sum(sample["workers_observed"] > 1 for sample in native),
            "ticks_with_parallel_dispatch": sum(sample["parallel_phases"] > 0 for sample in native),
            "max_parallel_phases": max(sample["parallel_phases"] for sample in native),
            "construction_usec": value["construction_usec"], "reset_usec": value["reset_usec"],
            "stop_join_usec": value["stop_join_usec"], "scene_retirement_usec": value["scene_retirement_usec"]}


def source_identity() -> dict:
    # Full actual execution inputs, including tracked local changes. Development
    # runs are explicitly labelled, never misreported as clean-commit execution.
    inputs = windows.tested_inputs(ROOT)
    suffixes = {".gd", ".gdshader", ".tscn", ".tres", ".py", ".cpp", ".hpp", ".h", ".c", ".json", ".yml"}
    extra = git("ls-files", "--others", "--exclude-standard", "--", "godot", "native", "tools", *APPARATUS).splitlines()
    for relative in sorted(set(APPARATUS) | {path for path in extra if Path(path).suffix in suffixes}):
        if (ROOT / relative).is_file():
            inputs[relative] = windows.content_digest(ROOT, relative)
    changed = git("diff", "--name-only", "HEAD").splitlines()
    source_delta = sorted(path for path in set(changed) | set(extra) if path in inputs)
    return {"source_sha": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}"),
            "source_delta_paths": source_delta, "execution_inputs": inputs,
            "source_mode": "head-plus-recorded-local-inputs" if source_delta else "clean-recorded-inputs"}


def runtime_identity() -> dict:
    native, rapier = runner.runtime_paths()
    target = "windows" if sys.platform == "win32" else "linux"
    native_manifest_path = native.parent.parent / ("runtime-provenance.json" if target == "windows"
                                                    else "runtime-provenance.linux.json")
    rapier_manifest_path = rapier.parent.parent / ("runtime-provenance." + target + ".json")
    result = {}
    for key, path, manifest_path in (("native", native, native_manifest_path), ("rapier", rapier, rapier_manifest_path)):
        relative = path.relative_to(ROOT).as_posix()
        manifest_relative = manifest_path.relative_to(ROOT).as_posix()
        manifest_bytes = manifest_path.read_bytes()
        require(manifest_bytes.replace(b"\r\n", b"\n") == windows.git(ROOT, "show", "HEAD:" + manifest_relative),
                key + " runtime provenance differs from committed content")
        manifest = load_json(manifest_bytes.decode("utf-8"))
        require(manifest.get("schema_version") == 1 and manifest.get("artifact") == relative,
                key + " provenance artifact is not the actual selected runtime")
        size, digest = path.stat().st_size, runner.sha256(path)
        require(size > 1024, key + " is an unmaterialized LFS pointer")
        require(digest == manifest.get("sha256") and size == manifest.get("size"),
                key + " selected runtime hash/size differs from provenance")
        pointer = windows.git(ROOT, "show", "HEAD:" + relative)
        match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", pointer)
        require(match is not None, key + " runtime is not a canonical committed LFS pointer")
        require(digest == match[1].decode() and size == int(match[2]),
                key + " selected runtime differs from committed LFS identity")
        errors = check_repository.verify_runtime(ROOT, manifest)
        require(not errors, "; ".join(errors))
        if key == "native":
            require(bool(manifest["source_inputs"]) and set(manifest["source_inputs"]) == windows.native_input_paths(ROOT),
                    "Native provenance inventory omits current inputs")
        result[key] = {"path": relative, "size": size,
                       "sha256": digest, "manifest": manifest_relative,
                       "manifest_sha256": runner.sha256(manifest_path),
                       "published_source": manifest.get("source_commit", manifest.get("build_commit"))}
    return result


def verify_directory(directory: Path) -> dict:
    report = load_json((directory / "campaign.json").read_text(encoding="utf-8"))
    require(report.get("schema") == SCHEMA and report.get("status") == "passed"
            and report.get("errors") == [] and report.get("retries") == 0, "Campaign did not pass")
    require(len(report.get("rows", [])) == report["config"]["repetitions"] * 2, "Incomplete 1/Auto pairing")
    all_records = [report["import"], *[row["process"] for row in report["rows"]]]
    for process in all_records:
        require(process.get("status") == "passed" and process.get("returncode") == 0
                and process.get("timeout_kind") is None and process.get("diagnostic_error") is False
                and process.get("skip_messages") == [] and process.get("launch_error") is None
                and process.get("capture_error") is None and process.get("timeout_diagnostic_error") is None,
                "Nonpassing process in campaign")
        name = process.get("log", "")
        require(name and Path(name).name == name, "Unsafe log identity")
        log = directory / name
        require(runner.sha256(log) == report["log_sha256"].get(name), "Original log SHA-256 mismatch")
        text = log.read_text(encoding="utf-8")
        require("SCRIPT ERROR:" not in text and "ERROR:" not in text
                and re.search(r"\bskipped\b|^\s*SKIP\b", text, re.I | re.M) is None,
                "Process log contains error/skip")
    for index, row in enumerate(report["rows"]):
        repeat, order = divmod(index, 2)
        require(row["repeat"] == repeat and row["order"] == order
                and row["requested_workers"] == ([1, 0] if repeat % 2 == 0 else [0, 1])[order]
                and row["process"]["timeout_seconds"] == 180, "Invalid row order or timeout")
        expected = {**report["config"], **row, "source_sha": report["source_sha"], "platform": report["platform"]}
        verify_row(row["result"], expected)
        raw = (directory / row["process"]["log"]).read_text(encoding="utf-8")
        marked = [load_json(line[len(MARKER):]) for line in raw.splitlines() if line.startswith(MARKER)]
        require(marked == [row["result"]], "Result differs from original process log or duplicate marker")
        require(row["summary"] == reduce_row(row["result"]), "Summary differs from raw samples")
        framebuffer = row["result"]["framebuffer"]
        if framebuffer.get("captured"):
            filename = framebuffer.get("path", "")
            require(filename and Path(filename).name == filename and filename.endswith(".png"),
                    "Unsafe framebuffer path")
            require(runner.sha256(directory / filename) == framebuffer["png_sha256"],
                    "Retained PNG hash differs from actual viewport capture")
            header = (directory / filename).read_bytes()[:24]
            require(header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR"
                    and len(header) == 24 and struct.unpack(">II", header[16:24]) == (960, 540),
                    "Original PNG header/dimensions differ")
    require(report["import"]["timeout_seconds"] == 240, "Import timeout differs")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--seconds", type=int, choices=range(15, 31), default=15)
    parser.add_argument("--repetitions", type=int, choices=range(1, 6), default=2)
    parser.add_argument("--rig", choices=RIGS, default="jetbarrel")
    parser.add_argument("--policy", type=int, choices=[0, 2], default=0)
    parser.add_argument("--rendering-driver", choices=["opengl3", "opengl3_angle"],
                        help="Explicit graphical driver; recorded, without changing project defaults")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    report = {"schema": SCHEMA, "status": "failed", "errors": [], "rows": [], "log_sha256": {}, "retries": 0,
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
              "command": [sys.executable, *sys.argv], "platform": "Windows" if sys.platform == "win32" else "Linux",
              "config": {"headless": args.headless, "sample_seconds": args.seconds, "repetitions": args.repetitions,
                         "rig": args.rig, "policy_preset": args.policy, "order": "alternating-1-auto"},
              "host_conditions": {"platform": platform.platform(), "cpu_count": os.cpu_count(),
                                  "load_average": list(os.getloadavg()) if hasattr(os, "getloadavg") else None,
                                  "affinity": sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None,
                                  "external_load": "uncontrolled", "python": sys.version},
              "comparison_limit": "Same authored rig/policy/viewport/intended Rapier-tick input tape; native/Rapier tick skew is not fixed-input replay equivalence. One-worker is still asynchronous; no synchronous gameplay comparator."}
    report["config"]["rendering_driver"] = args.rendering_driver or "engine-default"
    before = None
    try:
        require(sys.platform == "win32" or sys.platform.startswith("linux"), "Unsupported target OS")
        require(not args.headless or args.rendering_driver is None, "Graphical driver cannot be requested for headless rows")
        before = source_identity()
        report.update(before)
        report["runtimes"] = runtime_identity()
        report["godot_sha256"] = runner.sha256(Path(args.godot))
        report["godot_version"] = subprocess.check_output([args.godot, "--version"], text=True, timeout=30).strip()
        require(report["godot_version"] == GODOT_VERSION, "Pinned Godot version differs")
        env = os.environ.copy()
        env["CYBERSAND_SOURCE_REVISION"] = report["source_sha"]
        env["CYBERSAND_PACE003_RENDERING_DRIVER"] = report["config"]["rendering_driver"]
        with (args.output / "runner-transcript.txt").open("w", encoding="utf-8") as transcript:
            with contextlib.redirect_stdout(transcript):
                process, failed = runner.run_case(args.godot, runner.Case("import", ("--editor", "--import", "--quit"), 240, 0),
                                                  args.output, "pace003-import", env=env)
            report["import"] = process
            report["log_sha256"][process["log"]] = runner.sha256(args.output / process["log"])
            require(not failed, "Fresh import failed")
            for repeat in range(args.repetitions):
                for order, count in enumerate([1, 0] if repeat % 2 == 0 else [0, 1]):
                    name = f"pace003-r{repeat}-o{order}-w{count}"
                    driver_flags = ("--rendering-driver", args.rendering_driver) if args.rendering_driver else ()
                    flags = (*driver_flags, "--script", "res://tests/play_pace003_shared_host.gd", "--",
                             f"--workers={count}", f"--seconds={args.seconds}", f"--rig={args.rig}", f"--policy={args.policy}")
                    env["CYBERSAND_PACE003_CAPTURE"] = str((args.output / (name + ".png")).resolve())
                    with contextlib.redirect_stdout(transcript):
                        process, failed = runner.run_case(args.godot, runner.Case(name, flags, 180, 0, not args.headless),
                                                          args.output, "pace003-shared-host", env=env)
                    row = {"repeat": repeat, "order": order, "requested_workers": count, "process": process}
                    report["rows"].append(row)
                    report["log_sha256"][process["log"]] = runner.sha256(args.output / process["log"])
                    runner.write_json(args.output / "campaign.json", report)
                    require(not failed, "Measurement process failed: " + name)
                    raw = (args.output / process["log"]).read_text(encoding="utf-8")
                    lines = [line[len(MARKER):] for line in raw.splitlines() if line.startswith(MARKER)]
                    require(len(lines) == 1, "Missing/duplicate measurement result: " + name)
                    row["result"] = load_json(lines[0])
                    verify_row(row["result"], {**report["config"], **row, "source_sha": report["source_sha"], "platform": report["platform"]})
                    row["summary"] = reduce_row(row["result"])
                    runner.write_json(args.output / "campaign.json", report)
                    print(json.dumps({"row": name, "status": "passed", "native_ticks": row["summary"]["native_tick_ms"]["count"],
                                      "rendered_intervals": row["summary"]["render_submission_interval_usec"]["count"]}), flush=True)
        require(source_identity() == before, "Source inputs changed during execution")
        require(runtime_identity() == report["runtimes"], "Runtime identity changed during execution")
        report["status"] = "passed"
    except Exception as exc:
        # A diagnostic/verifier programming error must also leave a failed
        # retained report, never a stale status=passed artifact. Interrupts still
        # propagate; processes retain the existing runner's cleanup contract.
        report["errors"].append(type(exc).__name__ + ": " + str(exc))
        if before is not None:
            try:
                report["source_unchanged_after_failure"] = source_identity() == before
            except (RuntimeError, OSError, subprocess.SubprocessError):
                report["source_unchanged_after_failure"] = False
    report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    runner.write_json(args.output / "campaign.json", report)
    if report["status"] == "passed":
        try:
            verify_directory(args.output)
        except Exception as exc:
            report["status"] = "failed"
            report["errors"].append(type(exc).__name__ + ": " + str(exc))
            runner.write_json(args.output / "campaign.json", report)
    print("PLAY_PACE003_CAMPAIGN " + json.dumps({"status": report["status"], "errors": report["errors"],
          "rows": len(report["rows"]), "report_sha256": runner.sha256(args.output / "campaign.json")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
