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
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import check_repository
import run_godot_regressions as runner
import run_windows_godot_regressions as windows

SCHEMA = "play-pace003-campaign-v1"
CACHE_SCHEMA = "play-pace003-cold-cache-v2"
PRIVATE_CACHE_DIRECTORIES = {
    "Linux": (("XDG_CACHE_HOME", "xdg-cache"), ("XDG_CONFIG_HOME", "xdg-config"),
              ("XDG_DATA_HOME", "xdg-data"), ("MESA_SHADER_CACHE_DIR", "mesa-cache")),
    "Windows": (("APPDATA", "appdata"), ("LOCALAPPDATA", "localappdata")),
}
MARKER = "PLAY_PACE003_RESULT "
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
RIGS = ("stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel")
PRESENTATION_SHADERS = (
    "shaders/material_palette.gdshader", "shaders/material_emission.gdshader",
    "shaders/glow_composite.gdshader", "shaders/material_vapour_trail.gdshader",
    "shaders/material_vapour_trail.gdshader",
)
PRESENTATION_CONSUMERS = (
    "Layout/World", "MaterialGlowViewport/MaterialEmissionSource", "Layout/World/MaterialGlow",
    "MaterialVapourTrail0/VapourTrailSource", "MaterialVapourTrail1/VapourTrailSource",
)
# shared_host selects the mechanical course's overview camera before Build.
# PlayerCourse.VIEW is 512x256; the initial sandbox's 320x180 is not this workload.
COURSE_VIEW_SIZE = [512, 256]
APPARATUS = (
    "godot/tests/play_pace003_shared_host.gd", "godot/tests/play_pace003_worker_probe.gd",
    "godot/tests/play_wait001_snapshot_probe.gd", "tools/play/run_pace003_campaign.py",
    "tools/play/test_pace003_campaign.py", "tools/ci/check_repository.py",
    ".github/workflows/play-pace003-host.yml",
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


def window_cadence(timestamps: list, started: int, ended: int) -> dict:
    """Expose unsampled window edges without inventing event times outside it."""
    adjacent = intervals(timestamps)
    require(type(started) is int and type(ended) is int and ended > started
            and all(started <= timestamp < ended for timestamp in timestamps),
            "Cadence events must lie inside their complete measurement window")
    leading = timestamps[0] - started if timestamps else ended - started
    trailing = ended - timestamps[-1] if timestamps else ended - started
    gaps = [leading, *adjacent, trailing] if timestamps else [ended - started]
    return {"observed_events": len(timestamps), "elapsed_usec": ended - started,
            "events_per_second": len(timestamps) * 1_000_000 / (ended - started),
            "leading_gap_usec": leading, "trailing_gap_usec": trailing,
            "max_gap_including_boundaries_usec": max(gaps),
            "long_gap_counts_including_boundaries": {
                str(threshold): sum(gap > threshold for gap in gaps)
                for threshold in (16667, 33333, 50000, 100000, 250000, 1000000)},
            "scope": "Count over the entire measured window; boundary gaps are observed lower bounds, not complete adjacent-event intervals or proof of waiting"}


def cache_inventory(directory: Path) -> dict:
    """Hash generated cache bytes outside the measured process; never follow links."""
    require(not directory.is_symlink(), "Cache directory must not be a symbolic link")
    if not directory.exists():
        return {"present": False, "files": {}}
    require(directory.is_dir(), "Cache path must be a directory")
    files = {}
    for path in sorted(directory.rglob("*")):
        require(not path.is_symlink(), "Cache inventory must not follow a symbolic link")
        if path.is_file():
            files[path.relative_to(directory).as_posix()] = {
                "size": path.stat().st_size, "sha256": runner.sha256(path)}
    return {"present": True, "files": files}


@contextlib.contextmanager
def cold_cache_environment(output: Path, name: str, environment: dict):
    """Isolate each new process without deleting the caller's existing cache.

    Generated project shader cache is quarantined; resource import stays intact.
    Godot's user://shader_cache is isolated through private user-data directories,
    alongside Linux XDG/Mesa caches or Windows AppData/LocalAppData. Windows
    OS/D3D driver caches are not controlled and must never be reported empty.
    All inventories/moves happen outside the unchanged case timer.
    """
    platform_name = "Linux" if sys.platform.startswith("linux") else "Windows" if sys.platform == "win32" else ""
    require(platform_name in PRIVATE_CACHE_DIRECTORIES, "Unsupported cache-isolation platform")
    project = ROOT / "godot/.godot/shader_cache"
    location = output.resolve() / "cache" / name
    require(name not in ("", ".", "..") and "/" not in name and "\\" not in name
            and not location.exists(), "Cache row identity is not fresh")
    require(not location.is_relative_to(project.resolve()), "Evidence cannot be inside the shader cache")
    before = cache_inventory(project)
    location.mkdir(parents=True)
    preserved = location / "preserved-project-cache"
    generated = location / "generated-project-cache"
    if before["present"]:
        shutil.move(str(project), str(preserved))
    env = environment.copy()
    private = {}
    receipt = {"schema": CACHE_SCHEMA, "row": name, "fresh_process": True,
               "project_before": before, "project_at_launch": cache_inventory(project),
               "private_at_launch": {}, "private_paths": {},
               "generated_project": None, "generated_private": {},
               "project_restored": False, "complete": False,
               "windows_driver_cache": "uncontrolled", "other_driver_caches": "uncontrolled",
               "linux_private_cache": platform_name == "Linux",
               "windows_private_cache": platform_name == "Windows"}
    try:
        for key, folder in PRIVATE_CACHE_DIRECTORIES[platform_name]:
            path = location / folder
            path.mkdir()
            private[key] = path
            env[key] = str(path)
            receipt["private_paths"][key] = str(path)
            receipt["private_at_launch"][key] = cache_inventory(path)
        require(receipt["project_at_launch"] == {"present": False, "files": {}},
                "Project shader cache was not isolated before the process")
        yield env, receipt
    finally:
        try:
            receipt["generated_project"] = cache_inventory(project)
            receipt["generated_private"] = {key: cache_inventory(path) for key, path in private.items()}
        finally:
            # A failed/timeout process is already reaped by run_case. Preserve its
            # newly generated cache and restore the exact pre-existing one.
            if project.exists() or project.is_symlink():
                shutil.move(str(project), str(generated))
            if preserved.exists():
                project.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(preserved), str(project))
            receipt["project_restored"] = cache_inventory(project) == before
            receipt["complete"] = True
            runner.write_json(location / "receipt.json", receipt)
        require(receipt["project_restored"], "Pre-existing project shader cache was not restored")


def verify_cold_cache(row: dict, platform_name: str, directory: Path) -> None:
    receipt = row.get("cold_cache", {})
    name = row["process"]["name"]
    require(type(name) is str and name not in ("", ".", "..") and "/" not in name and "\\" not in name,
            "Unsafe cold-cache row identity")
    require(receipt.get("schema") == CACHE_SCHEMA and receipt.get("row") == name
            and receipt.get("fresh_process") is True and receipt.get("complete") is True
            and receipt.get("project_restored") is True
            and receipt.get("project_at_launch") == {"present": False, "files": {}}
            and receipt.get("windows_driver_cache") == "uncontrolled"
            and receipt.get("other_driver_caches") == "uncontrolled"
            and receipt.get("linux_private_cache") is (platform_name == "Linux")
            and receipt.get("windows_private_cache") is (platform_name == "Windows"),
            "Missing, incomplete or falsely qualified cold-cache custody")
    private = receipt.get("private_at_launch", {})
    expected_directories = PRIVATE_CACHE_DIRECTORIES.get(platform_name, ())
    expected_keys = {key for key, _folder in expected_directories}
    require(set(private) == expected_keys and all(
        entry == {"present": True, "files": {}} for entry in private.values()),
        "Private user-data/cache directories were not empty at process launch")
    require(set(receipt.get("private_paths", {})) == expected_keys
            and set(receipt.get("generated_private", {})) == expected_keys,
            "Private user-data/cache paths or inventories are missing")

    def recorded_path(value: object) -> PurePosixPath:
        require(type(value) is str and bool(value), "Missing engine/cache path")
        text = value.replace("\\", "/")
        require((text.startswith("/") or re.match(r"^[A-Za-z]:/", text) is not None)
                and ".." not in text.split("/"), "Unsafe engine/cache path")
        return PurePosixPath(text.casefold() if platform_name == "Windows" else text)

    private_paths = {}
    for key, folder in expected_directories:
        path = recorded_path(receipt["private_paths"][key])
        suffix = ("cache", name, folder)
        if platform_name == "Windows":
            suffix = tuple(part.casefold() for part in suffix)
        require(path.parts[-3:] == suffix, "Private cache path belongs to another row")
        private_paths[key] = path
    require(len({path.parent for path in private_paths.values()}) == 1,
            "Private cache paths do not share this row's evidence directory")
    engine = row.get("result", {}).get("cache_paths", {})
    user_data = recorded_path(engine.get("user_data_dir"))
    shader_cache = recorded_path(engine.get("shader_cache_dir"))
    data_keys = ("XDG_DATA_HOME",) if platform_name == "Linux" else ("APPDATA", "LOCALAPPDATA")
    require(any(key in private_paths and user_data != private_paths[key]
                and user_data.is_relative_to(private_paths[key]) for key in data_keys)
            and shader_cache == user_data / "shader_cache",
            "Engine user shader cache escaped this row's private user-data directory")
    root = directory / "cache" / name
    require(load_json((root / "receipt.json").read_text(encoding="utf-8")) == receipt,
            "Cold-cache receipt differs from retained original")
    require(cache_inventory(root / "generated-project-cache") == receipt.get("generated_project"),
            "Generated project cache differs from retained inventory")
    for key, folder in expected_directories:
        require(cache_inventory(root / folder) == receipt["generated_private"][key],
                "Generated private cache differs from retained inventory")


def verify_setup(value: dict, graphical: bool) -> None:
    """Bind the actual Main acknowledgement to the original pre-Build deadline."""
    observation = value.get("setup_observation", {})
    acknowledgement = value.get("setup_acknowledgement", {})
    require(acknowledgement.get("predicate") == "actor_ready"
            and acknowledgement.get("observer") == "after_actual_Main_process",
            "Setup must observe the exact existing predicate after actual Main")
    keys = ("form_started_usec", "request_started_usec", "deadline_usec", "acknowledged_usec", "polled_usec", "poll_elapsed_usec")
    require(all(type(acknowledgement.get(key)) is int and acknowledgement[key] >= 0 for key in keys),
            "Missing/nonmonotonic setup acknowledgement timestamps")
    form, request, deadline, acknowledged, polled, elapsed = (acknowledgement[key] for key in keys)
    require(0 < form <= request <= acknowledged <= deadline and deadline - request == 30_000_000
            and acknowledged <= polled and elapsed == polled - request
            and value.get("construction_usec") == polled - form,
            "Absent, late or backward setup acknowledgement, changed deadline or poll latency")
    require(acknowledgement.get("identity") == {"rig": value["rig"], "actor_epoch": value["actor_epoch"],
                                               "generation": value["generation"]},
            "Setup acknowledgement belongs to another accepted session")
    require(all(type(observation.get(key)) is int for key in ("started_usec", "ready_completed_usec", "ended_usec"))
            and 0 < observation["started_usec"] <= observation["ready_completed_usec"] <= form
            and polled <= observation["ended_usec"] <= value["started_usec"]
            and observation.get("max_samples_per_series") == 8192,
            "Missing/backward/unbounded setup observation")
    for kind, count_key, time_key, duration_key in (
        ("main", "main_calls", "main_started_usec", "main_callback_usec"),
        ("physics", "physics_calls", "physics_started_usec", "physics_callback_usec"),
        ("render", "render_submissions", "rendered_usec", None),
    ):
        count, timestamps = observation.get(count_key), observation.get(time_key, [])
        require(type(count) is int and count >= 0 and len(timestamps) == min(count, 8192)
                and observation.get(kind + "_samples_truncated") is (count > 8192),
                "Missing or mislabelled bounded setup samples: " + kind)
        intervals(timestamps)
        require(all(observation["ready_completed_usec"] <= timestamp <= observation["ended_usec"]
                    for timestamp in timestamps), "Setup sample lies outside observed window")
        if duration_key:
            durations = observation.get(duration_key, [])
            require(count > 0 and len(durations) == len(timestamps)
                    and all(type(duration) is int and duration >= 0 for duration in durations),
                    "Missing actual setup callback durations: " + kind)
            require(all(timestamp + duration <= observation["ended_usec"]
                        for timestamp, duration in zip(timestamps, durations)), "Setup callback ends after observation")
    require((observation["render_submissions"] > 0) if graphical else observation["render_submissions"] == 0,
            "Setup graphical submissions missing or falsely claimed for headless")
    # The first true predicate is latched at the end of an actually recorded
    # Main callback. A caller cannot substitute a later poll's wall time.
    require(acknowledged in [timestamp + duration for timestamp, duration in zip(
        observation["main_started_usec"], observation["main_callback_usec"])],
        "Setup acknowledgement is not an actual retained Main callback completion")
    scene = value.get("scene_startup", {})
    phase_keys = ("scene_load_started_usec", "scene_load_completed_usec",
                  "scene_instantiate_started_usec", "scene_instantiate_completed_usec",
                  "scene_add_child_started_usec", "scene_add_child_completed_usec")
    require(set(scene) == set(phase_keys) and all(type(scene[key]) is int and scene[key] > 0 for key in phase_keys),
            "Missing scene/resource construction timestamps")
    ordered = [scene[key] for key in phase_keys]
    require(all(left <= right for left, right in zip(ordered, ordered[1:]))
            and scene["scene_add_child_started_usec"] <= observation["started_usec"]
            <= observation["ready_completed_usec"] <= scene["scene_add_child_completed_usec"] <= form,
            "Scene construction and actual Main readiness are out of order")


def verify_row(value: dict, expected: dict) -> dict:
    require(isinstance(value, dict) and value.get("schema") == "play-pace003-shared-host-v1",
            "Missing apparatus row")
    for key in ("rig", "requested_workers", "policy_preset", "sample_seconds"):
        require(type(value.get(key)) is type(expected[key]) and value[key] == expected[key],
                "Row configuration differs: " + key)
    require(value.get("source_revision") == expected["source_sha"], "Row source differs")
    require(value.get("requested_rendering_driver") == expected["rendering_driver"],
            "Requested rendering driver differs")
    shader_rows = value.get("presentation_shaders", [])
    require(len(shader_rows) == len(PRESENTATION_SHADERS), "Production shader resources are missing")
    for index, (shader, relative, consumer) in enumerate(zip(
            shader_rows, PRESENTATION_SHADERS, PRESENTATION_CONSUMERS)):
        digest = expected.get("execution_inputs", {}).get("godot/" + relative)
        require(re.fullmatch(r"[0-9a-f]{64}", digest or "") is not None
                and shader.get("resource_path") == "res://" + relative
                and shader.get("file_sha256") == digest
                and shader.get("loaded_code_sha256") == digest,
                "Actual attached shader differs from recorded production source: " + relative)
        require(shader.get("consumer_path") == consumer
                and all(shader.get(key) is True for key in (
                    "owner_node_matches", "owner_material_matches", "inside_tree", "visible_in_tree",
                    "viewport_matches_owner", "viewport_inside_tree", "viewport_hdr_2d", "intersects_viewport"))
                and shader.get("use_parent_material") is False
                and shader.get("effective_alpha") == 1.0
                and len(shader.get("size", [])) == 2 and all(numeric(side, .001) for side in shader["size"]),
                "Actual presentation consumer is hidden, detached, replaced or not using its owned shader: " + consumer)
        viewport_size = [256, 128] if index == 1 else COURSE_VIEW_SIZE if index >= 3 else [960, 540]
        # UPDATE_ONCE becomes UPDATE_DISABLED after submission. Both are valid
        # for the two alternating trail buffers; the glow source stays ALWAYS.
        allowed_modes = (0, 1) if index >= 3 else (4,) if index == 1 else (-1,)
        require(shader.get("viewport_size") == viewport_size
                and type(shader.get("viewport_update_mode")) is int
                and shader["viewport_update_mode"] in allowed_modes,
                "Presentation viewport size or update mode differs: " + consumer)
    pipeline = value.get("presentation_pipeline", {})
    require(pipeline.get("view_size") == COURSE_VIEW_SIZE
            and all(pipeline.get(key) is True for key in (
                "world_texture_matches_owner", "world_current_texture_matches", "world_previous_texture_matches",
                "world_palette_lut_matches", "world_program_lut_matches", "glow_enabled", "glow_world_texture_matches",
                "glow_output_texture_matches", "vapour_trail_enabled", "vapour_output_texture_matches"))
            and pipeline.get("vapour_history_links") == [True, True]
            and type(pipeline.get("vapour_trail_latest")) is int and pipeline["vapour_trail_latest"] in (0, 1)
            and pipeline.get("vapour_trail_strength") == 1.0
            and type(pipeline.get("vapour_trail_updated_usec")) is int
            and value["started_usec"] <= pipeline["vapour_trail_updated_usec"] <= value["ended_usec"],
            "Actual World/glow/vapour inputs or live presentation dependencies differ")
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
    verify_setup(value, graphical)
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
    require(all(value["started_usec"] <= timestamp < value["ended_usec"] for timestamp in main_times),
            "Main callbacks are absent/frozen or outside the measurement window")
    for key in ("main_callback_usec", "snapshot_mutex_wait_usec", "snapshot_mutex_critical_usec"):
        require(len(raw.get(key, [])) == len(main_times), "Missing Main sample: " + key)
        stats(raw[key])
    require(len(raw.get("physics_callback_usec", [])) > 1, "No actual physics callbacks")
    stats(raw["physics_callback_usec"])
    frames = raw.get("rendered_usec", [])
    require((len(frames) > 1) if graphical else frames == [], "No graphical samples or false headless frames")
    intervals(frames)
    require(all(value["started_usec"] <= timestamp < value["ended_usec"] for timestamp in frames),
            "Graphical submissions are stale or outside the measurement window")
    snapshots = raw.get("snapshot_rows", [])
    require(len(snapshots) == len(main_times), "Incomplete Main-visible snapshot samples")
    last_serial = -1
    last_tick = -1
    for index, sample in enumerate(snapshots):
        require(sample.get("generation") == value["generation"] and sample.get("epoch") == value["actor_epoch"]
                and sample.get("failed") is False and sample.get("serial", -1) >= last_serial
                and sample.get("tick", -1) >= last_tick
                and 0 <= sample.get("render_tick", -1) <= sample["tick"]
                and numeric(sample.get("observed_usec")) and numeric(sample.get("published_usec"))
                and sample["observed_usec"] >= sample["published_usec"]
                and sample["observed_usec"] == main_times[index] + raw["main_callback_usec"][index]
                and sample["observed_usec"] < value["ended_usec"],
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
    setup, acknowledgement = value["setup_observation"], value["setup_acknowledgement"]
    scene = value["scene_startup"]
    native, snapshots = raw["native_rows"], raw["snapshot_rows"]
    frame_intervals = intervals(raw["rendered_usec"])
    serials = [sample["serial"] for sample in snapshots]
    serial_deltas = [right - left for left, right in zip(serials, serials[1:])]
    observed_age = [sample["observed_usec"] - sample["published_usec"] for sample in snapshots]
    render_age = [sample["observed_usec"] - sample["render_generated_usec"] for sample in snapshots
                  if sample["render_generated_usec"] > 0]
    return {"setup_acknowledgement_latency_usec": acknowledgement["acknowledged_usec"] - acknowledgement["request_started_usec"],
            "scene_load_usec": scene["scene_load_completed_usec"] - scene["scene_load_started_usec"],
            "scene_instantiate_usec": scene["scene_instantiate_completed_usec"] - scene["scene_instantiate_started_usec"],
            "scene_add_child_usec": scene["scene_add_child_completed_usec"] - scene["scene_add_child_started_usec"],
            "Main_ready_usec": setup["ready_completed_usec"] - setup["started_usec"],
            "setup_poll_elapsed_usec": acknowledgement["poll_elapsed_usec"],
            "setup_acknowledgement_to_poll_usec": acknowledgement["polled_usec"] - acknowledgement["acknowledged_usec"],
            "setup_first_render_from_ready_usec": setup["rendered_usec"][0] - setup["ready_completed_usec"]
            if setup["rendered_usec"] else None,
            "setup_main_callback_usec": stats(setup["main_callback_usec"]),
            "setup_main_callback_interval_usec": stats(intervals(setup["main_started_usec"])),
            "setup_physics_callback_usec": stats(setup["physics_callback_usec"]),
            "setup_render_submission_interval_usec": stats(intervals(setup["rendered_usec"])),
            "setup_note": "Original cold/setup samples retained, including delays outside Main callbacks; late polling is accepted only with a recorded acknowledgement within the original pre-Build 30-second deadline",
            "native_tick_ms": stats([sample["native_ms"] for sample in native]),
            "native_completed_per_second": len(native) * 1_000_000 / value["elapsed_usec"],
            "native_observed_by_main_per_second": value["native_hz_observed_by_main"],
            "rapier_completed_per_second": value["rapier_hz"],
            "worker_step_ms": stats([sample["worker_step_ms"] for sample in native]),
            "native_probe_usec": stats([sample["probe_usec"] for sample in native]),
            "main_callback_window": window_cadence(raw["main_started_usec"], value["started_usec"], value["ended_usec"]),
            "main_callback_interval_usec": stats(intervals(raw["main_started_usec"])),
            "main_callback_usec": stats(raw["main_callback_usec"]),
            "physics_callback_usec": stats(raw["physics_callback_usec"]),
            "snapshot_mutex_wait_usec": stats(raw["snapshot_mutex_wait_usec"]),
            "snapshot_mutex_critical_usec": stats(raw["snapshot_mutex_critical_usec"]),
            "render_submission_interval_usec": stats(frame_intervals),
            "render_submission_window": window_cadence(raw["rendered_usec"], value["started_usec"], value["ended_usec"])
            if value["scope"]["frame_submissions_measured"] else None,
            "render_rate_scope": "Submission event count over the complete measured window; physical scanout is unmeasured; headless has no graphical rate",
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
    suffixes = {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".tres", ".py", ".cpp", ".hpp", ".h", ".c", ".json", ".yml"}
    extra = git("ls-files", "--others", "--exclude-standard", "--", "godot", "native", "tools", *APPARATUS).splitlines()
    tracked_play = git("ls-files", "--", "tools/play").splitlines()
    for relative in sorted(set(APPARATUS) | {path for path in extra + tracked_play if Path(path).suffix in suffixes}):
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
                and row.get("attempt") == 1 and row.get("errors") == []
                and row["process"]["timeout_seconds"] == 180, "Invalid row order or timeout")
        verify_cold_cache(row, report["platform"], directory)
        expected = {**report["config"], **row, "source_sha": report["source_sha"], "platform": report["platform"],
                    "execution_inputs": report["execution_inputs"]}
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
        require(not os.environ.get("CYBERSAND_PACE003_DIAGNOSTIC_VARIANT"),
                "Explicit diagnostic variants cannot run as qualifying PACE003 rows")
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
                    row = {"repeat": repeat, "order": order, "requested_workers": count, "attempt": 1, "errors": []}
                    report["rows"].append(row)
                    try:
                        env["CYBERSAND_PACE003_CAPTURE"] = str((args.output / (name + ".png")).resolve())
                        with cold_cache_environment(args.output, name, env) as (row_env, cache):
                            row["cold_cache"] = cache
                            runner.write_json(args.output / "campaign.json", report)
                            with contextlib.redirect_stdout(transcript):
                                process, failed = runner.run_case(
                                    args.godot, runner.Case(name, flags, 180, 0, not args.headless),
                                    args.output, "pace003-shared-host", env=row_env)
                            row["process"] = process
                            report["log_sha256"][process["log"]] = runner.sha256(args.output / process["log"])
                        require(not failed, "Measurement process failed: " + name)
                        raw = (args.output / process["log"]).read_text(encoding="utf-8")
                        lines = [line[len(MARKER):] for line in raw.splitlines() if line.startswith(MARKER)]
                        require(len(lines) == 1, "Missing/duplicate measurement result: " + name)
                        row["result"] = load_json(lines[0])
                        verify_row(row["result"], {**report["config"], **row, "source_sha": report["source_sha"],
                                   "platform": report["platform"], "execution_inputs": report["execution_inputs"]})
                        verify_cold_cache(row, report["platform"], args.output)
                        row["summary"] = reduce_row(row["result"])
                        print(json.dumps({"row": name, "status": "passed", "native_ticks": row["summary"]["native_tick_ms"]["count"],
                                          "rendered_intervals": row["summary"]["render_submission_interval_usec"]["count"]}), flush=True)
                    except Exception as exc:
                        error = name + ": " + type(exc).__name__ + ": " + str(exc)
                        row["errors"].append(error)
                        report["errors"].append(error)
                        print(json.dumps({"row": name, "status": "failed", "error": error}), flush=True)
                    # Both worker controls get one first attempt. A later pass
                    # never removes a failed row or changes the aggregate result.
                    runner.write_json(args.output / "campaign.json", report)
        require(source_identity() == before, "Source inputs changed during execution")
        require(runtime_identity() == report["runtimes"], "Runtime identity changed during execution")
        report["status"] = "failed" if report["errors"] else "passed"
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
