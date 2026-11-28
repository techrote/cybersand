#!/usr/bin/env python3
"""Five-minute external observer for the immutable Strata003 application.

The application and observer have independent Git identities. The observer is
never installed in the application project. Actual completion timestamps, live
UI callback timings and original process counters are retained and re-read.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

OBSERVER_ROOT = Path(__file__).resolve().parents[2]
APPLICATION = "fd0830abcfadd9ae19162e5677943bb131223e59"
APPLICATION_TREE = "fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499"
FILES = ("tools/ci/strata3_sustained.gd", "tools/ci/strata3_sustained.py", "tools/ci/test_strata3_sustained.py")
PROFILES = ("classic", "architectural", "gameplay_clarity", "cinematic_deep_focus")
PLANES = {"play", "scripted", "effects", "background"}
HEX64 = re.compile(r"[0-9a-f]{64}")
HEX40 = re.compile(r"[0-9a-f]{40}")
OWNER_FIELDS = ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids")
SCOPE = "One five-minute hosted session with evolving Play geometry. No physical Windows/NVIDIA acceptance or long-duration leak claim."


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], timeout=60)


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def number(value, minimum=0):
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def path_in(folder, name):
    require(isinstance(name, str) and name and "\\" not in name and ":" not in name
            and not any(ord(char) < 32 for char in name)
            and all(part not in ("", ".", "..") for part in name.split("/")), "Unsafe evidence path")
    value = folder.joinpath(*name.split("/"))
    cursor = folder
    for part in name.split("/"):
        cursor = cursor / part
        require(not cursor.is_symlink(), "Linked evidence ancestor or file: " + name)
    require(value.is_file() and value.resolve().is_relative_to(folder.resolve()), "Missing or escaped original evidence: " + name)
    return value


def same_owner(before, after):
    require(isinstance(before, dict) and isinstance(after, dict)
            and all(key in before and before[key] == after.get(key) for key in OWNER_FIELDS), "Native owner changed")
    for key in ("worker_id", "actor_session_id"):
        require(isinstance(before[key], str) and re.fullmatch(r"-?[1-9][0-9]{0,18}", before[key]), "Missing actual native owner ID")
    require(isinstance(before["actor_body_ids"], list) and before["actor_body_ids"]
            and all(isinstance(item, str) and re.fullmatch(r"-?[1-9][0-9]{0,18}", item)
                    for item in before["actor_body_ids"]), "Missing actual physical actor IDs")
    require(all(integer(before.get(key)) and integer(after.get(key), before[key])
                for key in ("native_tick", "rapier_tick")), "Invalid actual progression counters")


def vector(value):
    return isinstance(value, list) and len(value) == 2 and all(number(item, -1000000) for item in value)


def pose(value):
    require(isinstance(value, dict) and vector(value.get("position")) and vector(value.get("linear_velocity"))
            and number(value.get("rotation"), -1000000) and integer(value.get("rapier_tick")), "Missing actual published actor pose")


def configuration(row, when):
    value, canonical = row.get("configuration_" + when), row.get("configuration_" + when + "_json")
    require(isinstance(value, dict) and isinstance(canonical, str)
            and json.loads(canonical) == value
            and hashlib.sha256(canonical.encode()).hexdigest() == row.get("configuration_" + when + "_sha256")
            and value.get("planes", {}).get("play", {}).get("participates") is False,
            "Authored optical configuration witness changed")
    return value


def resources(value):
    require(isinstance(value, dict) and all(integer(value.get(key)) for key in
            ("tracked_memory_bytes", "resource_count", "node_count", "object_count", "observer_retained_completed_steps")),
            "Missing bounded resource counters")
    optics = value.get("optics", {})
    require(optics.get("play_processed") is False and integer(optics.get("material_count"))
            and optics["material_count"] <= 3
            and all(optics.get(key) == 0 for key in ("additional_worlds", "additional_viewports", "additional_textures",
                                                    "native_captures", "native_writes", "texture_uploads")),
            "Optical/native resource isolation failed")


def visibility(value):
    require(isinstance(value, dict) and value.get("window_visible") is True and value.get("slider_visible") is True
            and value.get("fully_enclosed") is True and integer(value.get("scroll_vertical")),
            "Tonal control is not visibly enclosed by its scroll viewport")
    for key in ("slider_rect", "viewport_rect"):
        rect = value.get(key)
        require(isinstance(rect, list) and len(rect) == 4 and all(number(item, -100000) for item in rect)
                and rect[2] > 0 and rect[3] > 0, "Invalid actual control/viewport rectangle")
    x, y, width, height = value["slider_rect"]
    left, top, view_width, view_height = value["viewport_rect"]
    require(x >= left and y >= top and x+width <= left+view_width and y+height <= top+view_height,
            "Tonal control rectangle lies outside the recorded viewport")


def distribution(values):
    require(values and all(integer(value) for value in values), "Missing original timing population")
    ordered = sorted(values)
    return {"count": len(ordered), "p50": ordered[math.ceil(len(ordered)*.5)-1],
            "p95": ordered[math.ceil(len(ordered)*.95)-1], "p99": ordered[math.ceil(len(ordered)*.99)-1],
            "maximum": ordered[-1]}


def validate_observation(result, *, observer_sha256, observer_source_revision):
    require(result.get("schema") == "strata3-sustained-observation-v2"
            and result.get("phase") == "sustained-session" and result.get("scene") == "optics-readability-challenge"
            and result.get("completed") is True and result.get("failures") == [] and integer(result.get("checks"), 1),
            "Incomplete sustained session")
    require(result.get("source_revision") == APPLICATION and result.get("observer_sha256") == observer_sha256
            and result.get("observer_source_revision") == observer_source_revision, "Application/observer identities are not separate and exact")
    require(result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility" and result.get("diagnostic_headless") is False
            and isinstance(result.get("rendering_adapter"), str) and result["rendering_adapter"]
            and result.get("ordinary_workbench") is True and integer(result.get("process_id"), 1), "Actual ordinary graphical execution required")
    require(result.get("admission_target_ms") == 45000 and integer(result.get("admission_elapsed_ms"))
            and result.get("admission_target_met") == (result["admission_elapsed_ms"] <= 45000), "The unchanged 45-second admission target was misreported")
    require(result.get("world_count") == {"play_borrowed": 1, "decorative_owned": 3}
            and result.get("extent") == [1024, 768]
            and result.get("teardown", {}).get("native_world_count") == 0
            and result.get("teardown", {}).get("pending_native_world_count") == 0, "Four-plane ownership or teardown failed")
    registration = result.get("registration", {})
    require(registration.get("window_count") == 12 and registration.get("window_usec") == 25000000
            and registration.get("total_minimum_usec") == 300000000 and registration.get("profiles") == list(PROFILES)
            and registration.get("quality") == "balanced" and registration.get("per_window_observer_cap") == 8192
            and registration.get("resource_and_node_range_bound_after_first_cycle") == 16
            and registration.get("slider_offsets_usec") == [2000000, 6000000, 10000000, 14000000, 18000000, 22000000]
            and registration.get("camera_offsets_usec") == [0, 5000000, 10000000, 15000000, 20000000]
            and all(registration.get(key) == 0 for key in ("image_readbacks_during_windows", "native_material_readbacks_during_windows",
                       "geometry_resets_during_windows", "pose_injections", "extra_native_turns", "extra_worlds")), "Sustained registration changed")
    before_hashes, after_hashes = result.get("plane_native_hashes_before", {}), result.get("plane_native_hashes_after", {})
    require(set(before_hashes) == set(after_hashes) == PLANES and all(HEX64.fullmatch(str(value))
            for value in (*before_hashes.values(), *after_hashes.values()))
            and all(before_hashes[key] == after_hashes[key] for key in PLANES - {"play"}),
            "Actual static decorative material preservation failed")
    visibility(result.get("live_ui_before"))
    session = result.get("session", {})
    require(integer(session.get("start_usec"), 1) and integer(session.get("end_usec"), session["start_usec"] + 300000000)
            and session.get("elapsed_usec") == session["end_usec"] - session["start_usec"]
            and session["elapsed_usec"] <= 540000000, "Five minutes of actual uninterrupted time was not observed")
    same_owner(session.get("before"), session.get("after"))
    same_owner(session["after"], result.get("owner_after_pause"))
    require(session.get("decorative_before") == session.get("decorative_after")
            and set(session.get("decorative_before", {})) == PLANES - {"play"}
            and session.get("native_capture_delta") == session.get("decorative_upload_delta") == 0
            and session.get("native_edit_target") == "play", "Sustained decorative ownership/isolation failed")
    for plane, item in session["decorative_before"].items():
        # WorkbenchLayerOwner uses its opaque session:generation:plane fence.
        # Only native_instance_id is a numeric Godot ObjectID.
        require(isinstance(item.get("owner_id"), str) and 1 <= len(item["owner_id"]) <= 128
                and item["owner_id"].endswith(":" + plane)
                and len(item["owner_id"].rsplit(":", 2)) == 3
                and item["owner_id"].rsplit(":", 2)[0]
                and item["owner_id"].rsplit(":", 2)[1].isdigit()
                and int(item["owner_id"].rsplit(":", 2)[1]) >= 1
                and not any(ord(character) < 32 for character in item["owner_id"])
                and isinstance(item.get("native_instance_id"), str)
                and re.fullmatch(r"-?[1-9][0-9]{0,18}", item["native_instance_id"])
                and integer(item.get("native_tick")) and integer(item.get("native_revision")), "Missing actual decorative owner witness")
    rows = result.get("windows", [])
    require(isinstance(rows, list) and len(rows) == 12, "Missing sustained window")
    completions, slider_authored, slider_draw, summaries = [], [], [], []
    previous_end, previous_owner = session["start_usec"], session["before"]
    actor_distance, total_steps = 0.0, 0
    resource_counts, node_counts = [], []
    for index, row in enumerate(rows):
        require(row.get("index") == index and row.get("selected_profile") == PROFILES[index % 4]
                and row.get("quality") == "balanced" and row.get("start_usec") == previous_end
                and integer(row.get("end_usec"), previous_end + 25000000)
                and row.get("elapsed_usec") == row["end_usec"] - previous_end
                and row["elapsed_usec"] <= 45000000, "Incomplete, discontinuous or unbounded timed window")
        before, after = row.get("before", {}), row.get("after", {})
        require(before == previous_owner, "Native progression omitted between windows")
        same_owner(before, after)
        require(after["native_tick"] > before["native_tick"] and after["rapier_tick"] > before["rapier_tick"], "No actual physical/native progression in window")
        require(row.get("observer_overflow") is False and row.get("paused_callbacks") == 0
                and row.get("native_capture_delta") == row.get("decorative_upload_delta") == 0
                and row.get("native_edit_target") == "play"
                and row.get("decorative_identity") == session["decorative_before"], "Timed window paused, overflowed or changed native authority")
        initial, final = configuration(row, "before"), configuration(row, "after")
        require(initial.get("profile") == PROFILES[index % 4] and math.isclose(final.get("tonal", -1), .67, abs_tol=1e-8), "Live optical control did not reach authored state")
        if index % 4 == 0:
            require(initial.get("enabled") is False and final.get("enabled") is False, "Classic window silently enabled optics")
        resources(row.get("resources_before")); resources(row.get("resources_after"))
        require(row["resources_before"]["observer_retained_completed_steps"] == total_steps, "Observer retention accounting changed")
        steps = row.get("completed_physical_steps", [])
        require(isinstance(steps, list) and 2 <= len(steps) <= 8192 and len(steps) == after["rapier_tick"] - before["rapier_tick"], "Actual completed Rapier population missing")
        for offset, step in enumerate(steps):
            require(step.get("rapier_tick") == before["rapier_tick"] + offset + 1
                    and integer(step.get("completed_usec"), row["start_usec"])
                    and step["completed_usec"] <= row["end_usec"], "Gap or impossible actual completion timestamp")
        intervals = [right["completed_usec"] - left["completed_usec"] for left, right in zip(steps, steps[1:])]
        require(all(value > 0 for value in intervals) and intervals == row.get("physical_intervals_usec"), "Physical interval tails do not match completions")
        publications = row.get("native_publications", [])
        require(isinstance(publications, list) and 1 <= len(publications) <= 8192, "Missing bounded native publications")
        last_tick, last_time = before["native_tick"] - 1, row["start_usec"] - 1
        for publication in publications:
            require(integer(publication.get("native_tick"), last_tick + 1) and publication["native_tick"] <= after["native_tick"]
                    and integer(publication.get("observed_usec"), last_time + 1) and publication["observed_usec"] <= row["end_usec"]
                    and integer(publication.get("published_usec")) and integer(publication.get("serial"))
                    and integer(publication.get("world_revision")) and integer(publication.get("render_revision"))
                    and number(publication.get("worker_step_ms")), "Malformed native publication observation")
            last_tick, last_time = publication["native_tick"], publication["observed_usec"]
        callbacks = row.get("callbacks", [])
        require(isinstance(callbacks, list) and 2 <= len(callbacks) <= 8192, "Incomplete bounded display observations")
        require(row.get("slider_visibility_checks") == len(callbacks) and row.get("slider_visibility_failures") == 0,
                "Live tonal control visibility was not maintained through profile refreshes")
        previous_callback = row["start_usec"]
        for callback in callbacks:
            require(integer(callback.get("observed_usec"), previous_callback + 1)
                    and callback["observed_usec"] <= row["end_usec"]
                    and callback.get("interval_usec") == callback["observed_usec"] - previous_callback
                    and number(callback.get("process_ms")), "Callback observation population changed")
            previous_callback = callback["observed_usec"]
        responses = row.get("slider_responses", [])
        require(isinstance(responses, list) and len(responses) == 6, "Missing actual live slider responses")
        for offset, response in enumerate(responses):
            target = .31 if offset % 2 == 0 else .67
            start, authored, draw = (response.get(key) for key in ("callback_entry_usec", "authored_observed_usec", "draw_completed_usec"))
            require(number(response.get("requested")) and number(response.get("authored"))
                    and math.isclose(response["requested"], target, abs_tol=1e-8)
                    and math.isclose(response["authored"], target, abs_tol=1e-8)
                    and integer(start, row["start_usec"] + registration["slider_offsets_usec"][offset])
                    and integer(authored, start) and integer(draw, authored) and draw <= row["end_usec"]
                    and response.get("callback_to_authored_usec") == authored - start
                    and response.get("callback_to_next_completed_draw_usec") == draw - start
                    and response.get("original_callback_invocations") == 1
                    and response.get("native_edit_target") == "play" and response.get("physical_paused") is False,
                    "Slider timing is not bound to the original callback and actual completed draw")
            slider_authored.append(authored-start); slider_draw.append(draw-start)
            visibility(response.get("callback_visibility")); visibility(response.get("draw_visibility"))
        cameras = row.get("camera_events", [])
        require(isinstance(cameras, list) and len(cameras) == 5, "Missing actual ordinary pan/zoom events")
        for offset, event in enumerate(cameras):
            camera = event.get("camera", {})
            expected_size = [240, 135] if (index+offset) % 2 == 0 else [480, 270]
            require(event.get("ordinary_set_view") is True and number(event.get("picking_error"))
                    and event["picking_error"] < .01 and vector(camera.get("origin"))
                    and camera.get("view_size") == expected_size and camera.get("window_size") == [1600, 1000]
                    and isinstance(camera.get("world_rect"), list) and len(camera["world_rect"]) == 4
                    and all(number(value, -100000) for value in camera["world_rect"])
                    and integer(event.get("observed_usec"), row["start_usec"] + registration["camera_offsets_usec"][offset])
                    and event["observed_usec"] <= row["end_usec"], "Actual camera/picking witness changed")
            pose(event.get("actor_state"))
            action = event.get("submitted_action", {})
            require(vector(action.get("move")) and all(-1 <= value <= 1 for value in action["move"])
                    and action.get("primary") is True and number(action.get("effort")) and action["effort"] <= 1,
                    "Ordinary bounded actor input is missing")
        pose(row.get("actor_before")); pose(row.get("actor_after"))
        require(row["actor_before"]["rapier_tick"] == before["rapier_tick"]
                and row["actor_after"]["rapier_tick"] == after["rapier_tick"], "Actor pose is not bound to actual completed physical tick")
        distance = math.dist(row["actor_before"]["position"], row["actor_after"]["position"])
        actor_distance += distance
        total_steps += len(steps)
        require(row["resources_after"]["observer_retained_completed_steps"] == total_steps, "Retained-step memory accounting incomplete")
        resource_counts.append(row["resources_after"]["resource_count"])
        node_counts.append(row["resources_after"]["node_count"])
        completions.extend(steps)
        summaries.append({"index": index, "profile": row["selected_profile"], "elapsed_usec": row["elapsed_usec"],
                          "completed_steps": len(steps), "native_tick_delta": after["native_tick"]-before["native_tick"],
                          "rapier_ticks_per_second": len(steps)*1e6/row["elapsed_usec"],
                          "native_ticks_per_second": (after["native_tick"]-before["native_tick"])*1e6/row["elapsed_usec"],
                          "physical_intervals_usec": distribution(intervals), "actor_distance_cells": distance,
                          "resource_count": resource_counts[-1], "node_count": node_counts[-1]})
        previous_end, previous_owner = row["end_usec"], after
    require(previous_end == session["end_usec"] and previous_owner == session["after"]
            and total_steps == session.get("completed_step_count") == session["after"]["rapier_tick"]-session["before"]["rapier_tick"]
            and actor_distance > 1, "Five-minute physical continuity or actual movement was not established")
    all_intervals = [right["completed_usec"] - left["completed_usec"] for left, right in zip(completions, completions[1:])]
    require(all(value > 0 for value in all_intervals), "Physical boundary intervals are nonmonotonic")
    # The first complete catalogue cycle permits lazy cache creation. Subsequent
    # resource/node counts are bounded; sampled CPU/RSS are reported separately.
    require(max(resource_counts[3:])-min(resource_counts[3:]) <= 16
            and max(node_counts[3:])-min(node_counts[3:]) <= 16, "Sustained resource/node accumulation exceeded the registered bound")
    return {"scope": SCOPE, "elapsed_usec": session["elapsed_usec"], "completed_physical_steps": total_steps,
            "native_tick_delta": session["after"]["native_tick"]-session["before"]["native_tick"],
            "physical_intervals_usec_including_boundaries": distribution(all_intervals),
            "slider_callback_to_authored_usec": distribution(slider_authored),
            "slider_callback_to_next_completed_draw_usec": distribution(slider_draw),
            "slider_draw_scope": "Completed-draw observation, not input-to-photon latency.",
            "resource_range_after_first_catalogue_cycle": max(resource_counts[3:])-min(resource_counts[3:]),
            "node_range_after_first_catalogue_cycle": max(node_counts[3:])-min(node_counts[3:]),
            "actor_distance_sum_of_window_endpoints_cells": actor_distance, "windows": summaries,
            "comparison_limit": "Sequential windows have evolving geometry and actor states; these are sustained observations, not matched profile-cost comparisons."}


def application_modules(root):
    require(git(root, "rev-parse", "HEAD").decode().strip() == APPLICATION
            and git(root, "rev-parse", "HEAD^{tree}").decode().strip() == APPLICATION_TREE,
            "The application checkout must be the exact frozen fd0830ab source")
    sys.path.insert(0, str(root / "tools/ci"))
    sys.path.insert(0, str(root / "tools"))
    qualification = importlib.import_module("qualify_strata3_workbench")
    predecessor = importlib.import_module("strata3_predecessor_compare")
    require(qualification.ROOT.resolve() == root and qualification.previous.ROOT.resolve() == root
            and qualification.previous.custody.ROOT.resolve() == root and predecessor.ROOT.resolve() == root,
            "Source custody imported the observer checkout instead of the application")
    return qualification, predecessor


def evidence_files(folder):
    return {path.relative_to(folder).as_posix(): sha(path) for path in sorted(folder.rglob("*"))
            if path.is_file() and path != folder / "annex.json" and "userdata" not in path.relative_to(folder).parts}


def observer_identity():
    commit = git(OBSERVER_ROOT, "rev-parse", "HEAD").decode().strip()
    inputs = {}
    for name in FILES:
        content = (OBSERVER_ROOT / name).read_bytes()
        require(content.replace(b"\r\n", b"\n") == git(OBSERVER_ROOT, "show", commit + ":" + name),
                "Commit external observer input before execution: " + name)
        inputs[name] = hashlib.sha256(content).hexdigest()
    return {"source_commit": commit, "source_tree": git(OBSERVER_ROOT, "rev-parse", "HEAD^{tree}").decode().strip(),
            "source_inputs_raw_sha256": inputs, "location": "external-to-application-project"}


def verify(folder, application_root):
    q, predecessor = application_modules(application_root)
    record = json.loads((folder / "annex.json").read_text(encoding="utf-8"))
    require(record.get("schema") == "strata3-sustained-annex-v2" and record.get("completed") is True
            and record.get("failures") == [] and record.get("application_project_unchanged") is True,
            "Incomplete sustained annex")
    source = q.identity()
    require(record.get("application_source") == source and source["source_commit"] == APPLICATION
            and source["source_tree"] == APPLICATION_TREE and source["local_delta"] == [], "Application source custody changed")
    ledger = record.get("files_sha256", {})
    require(ledger == evidence_files(folder), "Original sustained evidence hash ledger changed")
    observer = record.get("observer_source", {})
    require(HEX40.fullmatch(str(observer.get("source_commit", "")))
            and observer.get("source_tree") == git(OBSERVER_ROOT, "rev-parse", observer["source_commit"] + "^{tree}").decode().strip()
            and observer.get("location") == "external-to-application-project"
            and set(observer.get("source_inputs_raw_sha256", {})) == set(FILES), "Missing separate external observer identity")
    for name in FILES:
        retained = path_in(folder, "observer/" + Path(name).name)
        require(sha(retained) == observer["source_inputs_raw_sha256"][name]
                and retained.read_bytes().replace(b"\r\n", b"\n") == git(OBSERVER_ROOT, "show", observer["source_commit"] + ":" + name),
                "External observer bytes changed: " + name)
    runtime = record.get("runtime", {})
    expected_loaded = {name.removeprefix("godot/"): value for name, value in source["source_inputs_sha256"].items()
                       if name.startswith("godot/")}
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = runtime.get(kind, {})
        require(isinstance(entry.get("path"), str) and HEX64.fullmatch(str(entry.get("sha256", ""))) and integer(entry.get("size"), 1),
                "Missing retained runtime identity")
        require(git(application_root, "show", APPLICATION + ":" + entry["path"]) ==
                f"version https://git-lfs.github.com/spec/v1\noid sha256:{entry['sha256']}\nsize {entry['size']}\n".encode(),
                "Observed runtime differs from frozen source LFS identity")
        expected_loaded[entry["path"].removeprefix("godot/")] = entry["sha256"]
    require(record.get("application_loaded_source_sha256") == expected_loaded
            and record.get("application_assets_sha256") == {name.removeprefix("godot/"): value
                for name, value in source["source_assets_sha256"].items()}, "Loaded application source/asset map changed")
    provenance = runtime.get("runtime_provenance", {})
    require(isinstance(provenance.get("path"), str) and HEX64.fullmatch(str(provenance.get("sha256", "")))
            and hashlib.sha256(git(application_root, "show", APPLICATION + ":" + provenance["path"])).hexdigest() == provenance["sha256"],
            "Retained native build provenance changed")
    native_manifest = json.loads(git(application_root, "show", APPLICATION + ":" + provenance["path"]))
    require(runtime.get("native_source_inputs") == native_manifest.get("source_inputs")
            and all(source["source_inputs_sha256"].get(name) == value for name, value in runtime["native_source_inputs"].items()),
            "Retained native runtime is not bound to application source inputs")
    require(record.get("godot", {}).get("sha256") == q.previous.GODOT_SHA256.get(record.get("host", {}).get("platform"))
            and record["godot"].get("version") == q.previous.custody.windows.GODOT_VERSION, "Unqualified Godot runtime")
    process = json.loads(path_in(folder, "session/process.json").read_text(encoding="utf-8"))
    require(process == record.get("process") and process.get("status") == "passed" and process.get("exit_code") == 0
            and process.get("timeout_seconds") == 600 and process.get("log_sha256") == sha(path_in(folder, "session/process.log"))
            and not q.previous.custody.ERRORS.search(path_in(folder, "session/process.log").read_text(encoding="utf-8", errors="replace")),
            "Actual sustained process failed or logged a script error")
    command = process.get("command", [])
    require(command == [record["godot"]["execution_path"], "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                        "--rendering-driver", "opengl3", "--path", record["application_execution_project"],
                        "--script", record["observer_execution_script"]], "The external graphical command changed")
    result = json.loads(path_in(folder, "session/report.json").read_text(encoding="utf-8"))
    summary = validate_observation(result, observer_sha256=observer["source_inputs_raw_sha256"][FILES[0]],
                                   observer_source_revision=observer["source_commit"])
    q.previous.verify_resource_receipt(folder, dict(process, label="session"), result["process_id"])
    raw_resources = json.loads(path_in(folder, "session/resources.json").read_text(encoding="utf-8"))
    sampled_times = [sample.get("elapsed_seconds") for sample in raw_resources["samples"]
                     if any(item["pid"] == result["process_id"] for item in sample["processes"])]
    require(process["resources"].get("available") is True and raw_resources.get("sample_interval_seconds") == .5
            and len(sampled_times) >= 300 and all(number(value) for value in sampled_times)
            and all(right > left for left, right in zip(sampled_times, sampled_times[1:]))
            and sampled_times[-1]-sampled_times[0] >= result["session"]["elapsed_usec"]/1e6-1,
            "Actual engine CPU/RSS observation did not span five minutes")
    captures = result.get("captures", [])
    require(len(captures) == 2, "Missing original before/after framebuffer")
    for index, capture in enumerate(captures):
        name = "sustained-before.png" if index == 0 else "sustained-after.png"
        image_path = path_in(folder, "session/" + name)
        require(capture.get("filename") == name and capture.get("sha256") == sha(image_path)
                and capture.get("outside_timed_windows") is True, "Original before/after capture changed")
        width, height, _ = predecessor.png_rgba(image_path.read_bytes())
        require(capture.get("actual_image_size") == [width, height], "Actual framebuffer extent differs from capture")
        require(capture.get("captured_usec", -1) < result["session"]["start_usec"] if index == 0 else
                capture.get("captured_usec", -1) > result["session"]["end_usec"], "Image readback entered the timed session")
    lab = result.get("lab_capture", {})
    lab_path = path_in(folder, "session/sustained-optics-lab.png")
    require(lab.get("filename") == "sustained-optics-lab.png" and lab.get("sha256") == sha(lab_path)
            and lab.get("outside_timed_windows") is True and integer(lab.get("captured_usec"), 1)
            and lab["captured_usec"] < result["session"]["start_usec"] and lab.get("visibility") == result["live_ui_before"],
            "Actual visible tonal-control screenshot is missing or entered timing")
    width, height, _ = predecessor.png_rgba(lab_path.read_bytes())
    require(lab.get("actual_image_size") == [width, height], "Actual Lab framebuffer extent changed")
    require(record.get("summary") == summary, "Sustained summary differs from actual raw observations")
    return summary


def run(args):
    root, output, godot = args.application_root.resolve(), args.output.resolve(), args.godot.resolve()
    require(not output.exists(), "Use a fresh evidence directory; retain failures")
    require(root != OBSERVER_ROOT.resolve() and not output.is_relative_to(root / "godot"),
            "External observer/evidence must remain outside the immutable application project")
    q, _ = application_modules(root)
    previous, custody = q.previous, q.previous.custody
    require(sha(godot) == previous.GODOT_SHA256.get(sys.platform), "Godot differs from pinned4.7")
    version = subprocess.check_output([str(godot), "--version"], timeout=20).decode().strip()
    require(version == custody.windows.GODOT_VERSION, "Wrong exact Godot version")
    source, runtime, observer = q.identity(), custody.verify_runtime_identity(), observer_identity()
    project = root / "godot"
    loaded, assets = custody.project_identity(project, source, runtime), previous.project_assets_identity(project, source)
    output.mkdir(parents=True)
    retained = output / "observer"
    retained.mkdir()
    for name in FILES:
        shutil.copyfile(OBSERVER_ROOT / name, retained / Path(name).name)
    script = retained / "strata3_sustained.gd"
    record = {"schema": "strata3-sustained-annex-v2", "completed": False, "failures": [],
              "application_source": source, "application_loaded_source_sha256": loaded, "application_assets_sha256": assets,
              "application_execution_project": str(project), "observer_source": observer, "observer_execution_script": str(script),
              "runtime": runtime, "godot": {"sha256": sha(godot), "version": version, "execution_path": str(godot)},
              "host": {"platform": sys.platform, "system": platform.platform(), "machine": platform.machine(),
                       "logical_cpu_count": os.cpu_count(), "job": os.environ.get("GITHUB_JOB", ""),
                       "run_id": os.environ.get("GITHUB_RUN_ID", ""), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "")}}
    try:
        environment = custody.case_environment(output / "userdata")
        record["import"] = q.metrics.execute([str(godot), "--headless", "--editor", "--path", str(project), "--quit"],
                                              output / "bootstrap", environment, 300)
        require(record["import"]["status"] == "passed", "Immutable application import failed")
        environment.update(STRATA_EVIDENCE=str(output / "session"), STRATA_REPORT=str(output / "session/report.json"),
                           CYBERSAND_SOURCE_REVISION=APPLICATION, STRATA3_DRIVER_SHA256=sha(script),
                           STRATA3_OBSERVER_SOURCE_REVISION=observer["source_commit"])
        environment.pop("STRATA3_DIAGNOSTIC_HEADLESS", None)
        command = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                   "--rendering-driver", "opengl3", "--path", str(project), "--script", str(script)]
        record["process"] = q.metrics.execute(command, output / "session", environment, 600)
        require(record["process"]["status"] == "passed", "Actual sustained process failed")
        result = json.loads((output / "session/report.json").read_text(encoding="utf-8"))
        record["summary"] = validate_observation(result, observer_sha256=sha(script), observer_source_revision=observer["source_commit"])
        require(q.identity() == source and custody.project_identity(project, source, runtime) == loaded
                and previous.project_assets_identity(project, source) == assets, "Application project changed during observation")
        record["application_project_unchanged"] = True
        record["completed"] = True
    except Exception as error:
        record["failures"].append(str(error))
    finally:
        record["files_sha256"] = evidence_files(output)
        write_json(output / "annex.json", record)
    require(record["completed"] and not record["failures"], "Sustained annex rejected: " + "; ".join(record["failures"]))
    verify(output, root)
    return record["summary"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application-root", type=Path, required=True)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args()
    try:
        if args.verify:
            summary = verify(args.verify.resolve(), args.application_root.resolve())
        else:
            require(args.godot is not None and args.output is not None, "--godot and --output are required")
            summary = run(args)
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0
    except (RuntimeError, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        print("SUSTAINED_ANNEX_REJECTED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
