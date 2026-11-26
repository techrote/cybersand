#!/usr/bin/env python3
"""Source-pinned A1 optical cost research against the immutable fd0830ab app.

This external reader never adopts a shader or promotes performance acceptance.
It keeps exact pixels, completed-step populations and whole-process counters
separate. The application and observer retain independent Git identities.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import sys

import strata3_sustained as shared

ROOT = Path(__file__).resolve().parents[2]
APPLICATION, APPLICATION_TREE = shared.APPLICATION, shared.APPLICATION_TREE
ORIGINAL = "b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb"
CANDIDATE = "50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f"
DRIVER = "tools/ci/strata3_shader_cost.gd"
WRAPPER = "tools/ci/experiments/strata3_optical_override_test.gd"
SHADER = "tools/ci/experiments/strata3_optical_empty_coverage_a1.gdshader"
DIAGNOSTIC = "tools/ci/experiments/strata3_shader_identity_diagnostic.gd"
DIAGNOSTIC_SCOPE = "Headless resource/constant evaluation diagnostic; not graphical or performance qualification"
ENGINE_VERSION = {"build": "official", "hash": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88", "hex": 263936,
                  "major": 4, "minor": 7, "patch": 0, "status": "stable", "string": "4.7-stable (official)", "timestamp": 0}
FILES = (DRIVER, "tools/ci/strata3_shader_cost.py", "tools/ci/test_strata3_shader_cost.py",
         WRAPPER, SHADER, DIAGNOSTIC, "tools/ci/strata3_sustained.py")
CASES = (("classic-original", "classic", "original"),
         ("architectural-original", "architectural", "original"),
         ("architectural-empty-coverage", "architectural", "empty-coverage"),
         ("clarity-original", "gameplay_clarity", "original"),
         ("clarity-empty-coverage", "gameplay_clarity", "empty-coverage"))
PNG_NAMES = ("actor-reveal", "classic-alpha", "detail-preserving", "frequency-aperture-0",
             "frequency-aperture-1", "frequency-aperture-2", "frequency-aperture-3", "frequency-aperture-6",
             "frequency-detail", "frequency-diffusion", "frequency-haze-opacity-classic",
             "frequency-haze-opacity-wipe", "frequency-low-aperture", "frequency-reference",
             "highlight-diffusion", "pixel-aperture", "processed-alpha", "wipe-alpha")
# The final frozen test saves eighteen PNGs. Its109 assertions include the new
# Classic baseline save; PNG count is derived from the actual capture names.
require, sha, write_json, git = shared.require, shared.sha, shared.write_json, shared.git
integer, number, path_in = shared.integer, shared.number, shared.path_in
SCOPE = ("Hosted A1 runtime shader override experiment; frozen application files unchanged. "
         "No application adoption, perceptual proof, physical NVIDIA acceptance or per-profile GPU/CPU timing.")


def distribution(values):
    require(isinstance(values, list) and values and all(integer(value, 1) for value in values),
            "Missing positive original timing population")
    ordered = sorted(values)
    return {"count": len(values), **{key: ordered[math.ceil(len(ordered)*fraction)-1]
            for key, fraction in (("p50", .5), ("p95", .95), ("p99", .99))}, "max": ordered[-1],
            "stalls_at_least_usec": {str(value): sum(item >= value for item in values)
                                     for value in (100000, 250000, 500000, 1000000)}}


def validate_statistics(value, profile):
    # The pinned runtime retains the original value of this constant-resource
    # expression. The per-host diagnostic proves that observed distinction; actual
    # runtime code and drawable attachments are mandatory in validate_binding.
    require(isinstance(value, dict) and value.get("shader_sha256") == ORIGINAL and value.get("profile") == profile
            and value.get("play_processed") is False and value.get("quality") == "balanced"
            and integer(value.get("material_count")) and value["material_count"] == (0 if profile == "classic" else 3)
            and all(value.get(key) == 0 for key in ("additional_worlds", "additional_viewports", "additional_textures",
                                                   "native_captures", "native_writes", "texture_uploads")),
            "Frozen shader-source metadata, bounded resources or native isolation changed")
    require(value.get("inspection") == {"bypass": False, "clarity": False, "wipe": 1.0, "focus_override": ""}
            and value.get("transitioning") is False, "Timed optical inspection or unsettled focus changed")
    if profile == "classic":
        require(value.get("active") is False and value.get("active_planes") == []
                and value.get("material_count") == value.get("uniform_writes") == 0,
                "Fresh Classic performed optical work")
    else:
        require(value.get("active") is True and set(value.get("active_planes", [])) == shared.PLANES - {"play"},
                "Candidate/original optical profile did not actually execute")


def instance_id(value):
    return isinstance(value, str) and re.fullmatch(r"-?[1-9][0-9]{0,18}", value) is not None


def validate_binding(binding, shader, profile):
    require(isinstance(binding, dict) and instance_id(binding.get("shader_instance_id"))
            and binding.get("shader_sha256") == shader and binding.get("statistics_shader_sha256") == ORIGINAL
            and binding.get("profile") == profile and integer(binding.get("cached_material_count")),
            "Actual presenter Shader attachment identity differs")
    materials = binding.get("materials")
    require(isinstance(materials, dict), "Missing actual material attachments")
    if profile == "classic":
        require(binding.get("cached_material_count") == 0 and materials == {}
                and binding.get("classic_materials_restored") is True, "Classic did not restore original material attachments")
    else:
        require(binding.get("cached_material_count") == 3 and set(materials) == shared.PLANES - {"play"}
                and binding.get("classic_materials_restored") is False, "Missing one or more active rear-plane attachments")
        material_ids = set()
        for material in materials.values():
            require(isinstance(material, dict) and instance_id(material.get("material_instance_id"))
                    and material.get("cached_shader_instance_id") == material.get("drawable_shader_instance_id") == binding["shader_instance_id"]
                    and material.get("shader_sha256") == shader and material.get("cache_is_drawable_material") is True,
                    "Detached cached material or drawable shader")
            material_ids.add(material["material_instance_id"])
        require(len(material_ids) == 3, "Rear planes unexpectedly share one mutable ShaderMaterial")
    return binding["shader_instance_id"]


def validate_identity_diagnostic(value, diagnostic_sha256):
    require(isinstance(value, dict) and value.get("schema") == "strata3-live-shader-identity-v1"
            and value.get("application") == APPLICATION and value.get("diagnostic_sha256") == diagnostic_sha256
            and value.get("scope") == DIAGNOSTIC_SCOPE and value.get("display_server") == "headless"
            and value.get("version") == ENGINE_VERSION and value.get("same_resource") is True
            and instance_id(value.get("live_id")) and value["live_id"] == value.get("separate_id"),
            "Actual platform shader-identity diagnostic is missing or changed")
    require(value.get("before") == {"runtime_code_sha256": ORIGINAL, "statistics_sha256": ORIGINAL}
            and value.get("after") == {"runtime_code_sha256": CANDIDATE, "separate_runtime_code_sha256": CANDIDATE,
                                      "material_runtime_code_sha256": CANDIDATE, "statistics_sha256": ORIGINAL,
                                      "script_constant_property_sha256": ORIGINAL}
            and value.get("restored") == ORIGINAL,
            "Runtime shader code and compiled source-expression semantics were not demonstrated")
    return value


def valid_camera(camera):
    require(isinstance(camera, dict) and shared.vector(camera.get("origin"))
            and shared.vector(camera.get("view_size")) and all(item > 0 for item in camera["view_size"])
            and shared.vector(camera.get("window_size")) and all(item > 0 for item in camera["window_size"])
            and number(camera.get("content_scale_factor"), .01), "Missing actual ordinary camera")
    rect = camera.get("world_rect")
    require(isinstance(rect, list) and len(rect) == 4 and all(number(item, -1000000) for item in rect)
            and rect[2] > 0 and rect[3] > 0, "Missing actual world framebuffer rectangle")


def validate_observation(result, *, observer_sha256, observer_source_revision):
    require(result.get("schema") == "strata3-shader-cost-observation-v2" and result.get("phase") == "progression"
            and result.get("scene") == "optics-readability-challenge" and result.get("completed") is True
            and result.get("failures") == [] and integer(result.get("checks"), 1), "Incomplete actual cost probe")
    require(result.get("source_revision") == APPLICATION and result.get("observer_sha256") == observer_sha256
            and result.get("observer_source_revision") == observer_source_revision,
            "Application and external observer identities differ")
    require(result.get("diagnostic_headless") is False and result.get("ordinary_workbench") is True
            and result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility"
            and isinstance(result.get("rendering_adapter"), str) and result["rendering_adapter"]
            and integer(result.get("process_id"), 1), "Actual ordinary graphical Workbench is required")
    require(result.get("original_shader_sha256") == ORIGINAL and result.get("candidate_shader_sha256") == CANDIDATE
            and result.get("original_shader_restored") is True, "Exact original/candidate shader boundary failed")
    require(result.get("world_count") == {"play_borrowed": 1, "decorative_owned": 3}
            and result.get("extent") == [1024, 768]
            and result.get("teardown", {}).get("native_world_count") == 0
            and result.get("teardown", {}).get("pending_native_world_count") == 0,
            "Four-plane ownership or retirement failed")
    require(result.get("admission_target_ms") == 45000 and integer(result.get("admission_elapsed_ms"))
            and result.get("admission_target_met") is (result["admission_elapsed_ms"] <= 45000),
            "Initial admission changed the original45-second criterion")
    registration = result.get("probe_registration", {})
    require(registration.get("cases") == [list(row) for row in CASES]
            and registration.get("repeats") == 3 and registration.get("callbacks_per_sample") == 90
            and registration.get("order") == "forward/reverse/forward" and registration.get("quality") == "balanced"
            and registration.get("geometry_reset_between_samples") is True
            and registration.get("per_sample_watchdog_usec") == 90000000
            and registration.get("shader_compilation_and_captures_before_timing") is True
            and registration.get("minimum_native_rate_ratio_to_classic") == .90
            and registration.get("minimum_rapier_rate_ratio_to_classic") == .90
            and registration.get("p95_ratio") == 1.20 and registration.get("p95_allowance_usec") == 10000,
            "Registered cost comparison changed")
    order = [(case, repeat) for repeat in range(3) for case in (CASES[::-1] if repeat % 2 else CASES)]
    rows = result.get("probe_samples", [])
    require(isinstance(rows, list) and len(rows) == 15, "Incomplete fifteen-window comparison")
    initial_hashes, camera, actor, configurations = None, None, None, {}
    summaries = []
    live_shader_ids = set()
    for row, (case, repeat) in zip(rows, order):
        case_id, profile, variant = case
        shader = ORIGINAL if variant == "original" else CANDIDATE
        require(row.get("case_id") == case_id and row.get("profile") == profile
                and row.get("variant") == variant and row.get("repeat") == repeat
                and row.get("quality") == "balanced" and row.get("shader_sha256") == shader,
                "Actual profile, variant, quality, shader or repeat order changed")
        require(row.get("callbacks") == 90 and integer(row.get("elapsed_usec"), 1)
                and row["elapsed_usec"] <= 91000000 and row.get("physical_gpu_acceptance") is False
                and row.get("native_capture_delta") == row.get("decorative_upload_delta") == 0,
                "Timed window omitted callbacks, overflowed or recaptured native content")
        capture = row.get("paused_capture", {})
        tag = case_id + "-" + str(repeat)
        require(capture.get("tag") == tag and capture.get("filename") == tag + ".png"
                and shared.HEX64.fullmatch(str(capture.get("sha256", "")))
                and capture.get("physical_paused") is True and capture.get("outside_timed_window") is True
                and capture.get("shader_sha256") == shader and integer(capture.get("captured_usec"), 1),
                "Missing actual paused pre-timing framebuffer")
        binding = capture.get("live_shader_binding")
        live_shader_ids.add(validate_binding(binding, shader, profile))
        validate_binding(row.get("live_shader_binding_after"), shader, profile)
        require(row["live_shader_binding_after"] == binding, "Live shader/material attachments changed during the timed window")
        hashes = capture.get("plane_native_hashes", {})
        require(set(hashes) == shared.PLANES and all(shared.HEX64.fullmatch(str(value)) for value in hashes.values())
                and hashes["play"] == row.get("initial_native_play_sha256"), "Initial native plane readback missing")
        if initial_hashes is None: initial_hashes = hashes
        require(hashes == initial_hashes, "Four initial native plane byte identities differ between windows")
        valid_camera(capture.get("camera")); shared.pose(capture.get("actor"))
        if camera is None: camera, actor = capture["camera"], capture["actor"]
        require(capture["camera"] == camera and capture["actor"] == actor, "Matched camera or initial actor state differs")
        config, canonical = capture.get("configuration"), capture.get("configuration_json")
        require(isinstance(config, dict) and isinstance(canonical, str) and json.loads(canonical) == config
                and hashlib.sha256(canonical.encode()).hexdigest() == capture.get("configuration_sha256")
                and config == row.get("configuration") and config.get("profile") == profile
                and config.get("enabled") is (profile != "classic")
                and config.get("planes", {}).get("play", {}).get("participates") is False,
                "Actual configured profile or canonical parameter custody changed")
        if profile not in configurations: configurations[profile] = config
        require(config == configurations[profile], "Original/candidate or repeats use different optical parameters")
        before, after = row.get("before", {}), row.get("after", {})
        shared.same_owner(before, after)
        delta, native_delta = after["rapier_tick"] - before["rapier_tick"], after["native_tick"] - before["native_tick"]
        completed = row.get("completed_physical_steps", [])
        require(isinstance(completed, list) and 2 <= len(completed) <= 8192 and len(completed) == delta and native_delta > 0,
                "Actual completed-step population is missing")
        for offset, step in enumerate(completed):
            require(step.get("rapier_tick") == before["rapier_tick"] + offset + 1
                    and integer(step.get("completed_usec"), capture["captured_usec"] + 1),
                    "Completion sequence has gaps or pre-timing capture entered physical progression")
        physical = [right["completed_usec"] - left["completed_usec"] for left, right in zip(completed, completed[1:])]
        require(row.get("physical_intervals_usec") == physical and row.get("physical_distribution_usec") == distribution(physical)
                and sum(physical) <= row["elapsed_usec"], "Physical interval summary differs from actual completions")
        callbacks = row.get("callback_intervals_usec", [])
        require(len(callbacks) == 90 and row.get("callback_distribution_usec") == distribution(callbacks)
                and sum(callbacks) <= row["elapsed_usec"] and len(row.get("godot_process_ms", [])) == 90
                and all(number(value) for value in row["godot_process_ms"]), "Callback/main-thread population differs")
        publications = row.get("native_publications", [])
        require(isinstance(publications, list) and 2 <= len(publications) <= 8192, "Missing native publication observations")
        for publication in publications:
            require(integer(publication.get("native_tick"), before["native_tick"])
                    and publication["native_tick"] <= after["native_tick"]
                    and integer(publication.get("observed_usec"), capture["captured_usec"] + 1)
                    and integer(publication.get("published_usec"), 1)
                    and publication["published_usec"] <= publication["observed_usec"]
                    and all(integer(publication.get(key)) for key in ("serial", "world_revision", "render_revision"))
                    and number(publication.get("worker_step_ms")), "Malformed native publication witness")
        require(all(right["native_tick"] > left["native_tick"] and right["observed_usec"] > left["observed_usec"]
                    for left, right in zip(publications, publications[1:])), "Native publication sequence repeated or regressed")
        native_intervals = [right["published_usec"] - left["published_usec"] for left, right in zip(publications, publications[1:])]
        require(row.get("native_publication_interval_distribution_usec") == distribution(native_intervals),
                "Native publication summary differs from observed samples")
        for key, ticks in (("native_ticks_per_second", native_delta), ("rapier_ticks_per_second", delta)):
            require(number(row.get(key), .000001) and math.isclose(row[key], ticks*1e6/row["elapsed_usec"], rel_tol=1e-10),
                    "Progress rate differs from actual counters and monotonic elapsed time")
        require(shared.vector(row.get("actor_position_before")) and shared.vector(row.get("actor_position_after"))
                and row["actor_position_before"] == capture["actor"]["position"]
                and capture["actor"]["rapier_tick"] == before["rapier_tick"]
                and number(row.get("actor_distance_cells"), .000001)
                and math.isclose(row["actor_distance_cells"], math.dist(row["actor_position_before"], row["actor_position_after"]),
                                 rel_tol=1e-5, abs_tol=1e-5), "Actual actor progression missing")
        require(integer(row.get("scene_admission_elapsed_ms"))
                and row.get("scene_admission_target_met") is (row["scene_admission_elapsed_ms"] <= 45000),
                "Scene replacement changed the45-second admission criterion")
        validate_statistics(row.get("optical_statistics"), profile)
        require(integer(row.get("resource_count")) and integer(row.get("godot_tracked_memory_bytes")),
                "Missing per-window engine resource observations")
        summaries.append({key: row[key] for key in ("case_id", "profile", "variant", "repeat", "elapsed_usec",
                         "native_ticks_per_second", "rapier_ticks_per_second", "physical_distribution_usec",
                         "callback_distribution_usec", "native_publication_interval_distribution_usec", "actor_distance_cells",
                         "scene_admission_elapsed_ms", "scene_admission_target_met", "resource_count", "godot_tracked_memory_bytes")})
    restored = result.get("restored_shader_resources", [])
    require(isinstance(restored, list) and 1 <= len(restored) <= 15
            and all(isinstance(row, dict) and instance_id(row.get("shader_instance_id"))
                    and row.get("shader_sha256") == ORIGINAL for row in restored)
            and len({row["shader_instance_id"] for row in restored}) == len(restored)
            and {row["shader_instance_id"] for row in restored} == live_shader_ids,
            "Every actual touched Shader resource must be restored exactly once")
    equivalence = result.get("pixel_equivalence", [])
    expected_pairs = [(prefix + "-original-" + str(repeat), prefix + "-empty-coverage-" + str(repeat), repeat)
                      for repeat in range(3) for prefix in ("architectural", "clarity")]
    require(isinstance(equivalence, list) and len(equivalence) == 6
            and [(row.get("original"), row.get("candidate"), row.get("repeat")) for row in equivalence] == expected_pairs
            and all(row.get("exact_equal") is True and row.get("changed_pixels") == row.get("max_channel_difference_u8") == 0
                    and integer(row.get("pixels"), 1) for row in equivalence), "Paired world pixels are not exact")
    groups = {case[0]: [row for row in summaries if row["case_id"] == case[0]] for case in CASES}
    classic = groups["classic-original"]
    baseline_native = statistics.median(row["native_ticks_per_second"] for row in classic)
    baseline_rapier = statistics.median(row["rapier_ticks_per_second"] for row in classic)
    baseline_p95 = statistics.median(row["physical_distribution_usec"]["p95"] for row in classic)
    limit = max(1.2*baseline_p95, baseline_p95+10000)
    comparisons = {}
    for name, population in groups.items():
        native = statistics.median(row["native_ticks_per_second"] for row in population)
        rapier = statistics.median(row["rapier_ticks_per_second"] for row in population)
        p95 = statistics.median(row["physical_distribution_usec"]["p95"] for row in population)
        comparisons[name] = {"repeats": population, "median_native_rate_ratio_to_classic": native/baseline_native,
                             "median_rapier_rate_ratio_to_classic": rapier/baseline_rapier,
                             "median_physical_p95_usec": p95, "physical_p95_limit_usec": limit,
                             "observed_native_rate_target_met": native/baseline_native >= .90,
                             "observed_rapier_rate_target_met": rapier/baseline_rapier >= .90,
                             "observed_physical_p95_target_met": p95 <= limit}
    for prefix in ("architectural", "clarity"):
        original = groups[prefix + "-original"]
        candidate = groups[prefix + "-empty-coverage"]
        original_native = statistics.median(row["native_ticks_per_second"] for row in original)
        original_rapier = statistics.median(row["rapier_ticks_per_second"] for row in original)
        original_p95 = statistics.median(row["physical_distribution_usec"]["p95"] for row in original)
        comparisons[prefix + "-empty-coverage"]["comparison_to_same_profile_original"] = {
            "median_native_rate_ratio": statistics.median(row["native_ticks_per_second"] for row in candidate)/original_native,
            "median_rapier_rate_ratio": statistics.median(row["rapier_ticks_per_second"] for row in candidate)/original_rapier,
            "median_physical_p95_ratio": statistics.median(row["physical_distribution_usec"]["p95"] for row in candidate)/original_p95,
            "per_repeat_rate_ratios": [{"repeat": repeat,
                "native_rate_ratio": candidate[repeat]["native_ticks_per_second"]/original[repeat]["native_ticks_per_second"],
                "rapier_rate_ratio": candidate[repeat]["rapier_ticks_per_second"]/original[repeat]["rapier_ticks_per_second"]}
                for repeat in range(3)]}
    return {"scope": SCOPE, "adjudication": "PENDING independent review; numeric flags are not automatic acceptance",
            "initial_admission_elapsed_ms": result["admission_elapsed_ms"],
            "initial_admission_target_met": result["admission_target_met"], "native_initial_plane_hashes": initial_hashes,
            "camera": camera, "initial_actor": actor, "comparisons": comparisons,
            "live_shader_attachment": {"actual_shader_resources": len(live_shader_ids), "windows_with_unchanged_attachment": 15,
                                       "all_touched_resources_restored": True,
                                       "statistics_hash_scope": "Frozen original-source expression; live shader/material code is validated separately"},
            "sampling_limit": "Three registered sequential repeats; no claim of statistical independence. Native publications may coalesce; only Rapier completion intervals cover every step.",
            "resource_scope": "Per-window engine counters are retained. Whole-process CPU/RSS includes bootstrap, initial admission, fifteen reloads, compilation, readbacks, warmups and timing; it is not per-profile CPU/GPU cost."}


def observer_identity():
    commit = git(ROOT, "rev-parse", "HEAD").decode().strip()
    inputs = {}
    for name in FILES:
        content = (ROOT / name).read_bytes()
        require(content.replace(b"\r\n", b"\n") == git(ROOT, "show", commit + ":" + name),
                "Commit external experiment input before execution: " + name)
        inputs[name] = hashlib.sha256(content).hexdigest()
    require(inputs[SHADER] == CANDIDATE, "External A1 candidate bytes changed")
    return {"source_commit": commit, "source_tree": git(ROOT, "rev-parse", "HEAD^{tree}").decode().strip(),
            "source_inputs_raw_sha256": inputs, "location": "external-to-application-project"}


def graphical_command(record, script):
    return [record["godot"]["execution_path"], "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3", "--path", record["application_execution_project"], "--script", script]


def verify_process(folder, label, record, command, timeout, q, engine_pid=None):
    process = json.loads(path_in(folder, label + "/process.json").read_text(encoding="utf-8"))
    text = path_in(folder, label + "/process.log").read_text(encoding="utf-8", errors="replace")
    require(process == record["processes"].get(label) and process.get("status") == "passed"
            and process.get("exit_code") == 0 and process.get("timeout_seconds") == timeout
            and number(process.get("seconds"), .000001) and process["seconds"] <= timeout + 5
            and integer(process.get("pid"), 1) and process.get("command") == command
            and process.get("log_sha256") == sha(path_in(folder, label + "/process.log"))
            and not q.previous.custody.ERRORS.search(text)
            and "Godot Engine v" + record["godot"]["version"] in text, "Changed or failing actual process: " + label)
    q.previous.verify_resource_receipt(folder, dict(process, label=label), engine_pid)
    return process, text


def marker(text, prefix):
    matches = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
    require(len(matches) == 1, "Missing or duplicate actual graphical marker: " + prefix)
    return json.loads(matches[0])


def equal_rgba(first, second, label):
    require(first[0:2] == second[0:2] and first[2] == second[2], "Original/candidate decoded RGBA differs: " + label)
    return {"width": first[0], "height": first[1], "compared_bytes": len(first[2]), "changed_channels": 0}


def region(image, rectangle):
    width, height, data = image
    left, top, span_x, span_y = [int(value) for value in rectangle]
    right, bottom = min(width, left+span_x), min(height, top+span_y)
    left, top = max(0, left), max(0, top)
    require(right > left and bottom > top, "Empty or invalid world pixel region")
    return [left, top, right-left, bottom-top], b"".join(data[(y*width+left)*4:(y*width+right)*4] for y in range(top, bottom))


def verify_shader_pixels(folder, predecessor):
    synthetic = {}
    for label in ("shader-original", "shader-candidate"):
        require({path.name for path in (folder / label).glob("*.png")} == {name + ".png" for name in PNG_NAMES},
                "Synthetic renderer PNG inventory differs")
    for name in PNG_NAMES:
        a = predecessor.png_rgba(path_in(folder, "shader-original/" + name + ".png").read_bytes())
        b = predecessor.png_rgba(path_in(folder, "shader-candidate/" + name + ".png").read_bytes())
        require(a[:2] == b[:2] == (192, 64), "Synthetic renderer extent changed")
        synthetic[name] = equal_rgba(a, b, name)
    for label in ("shader-original", "shader-candidate"):
        a = predecessor.png_rgba(path_in(folder, label + "/frequency-haze-opacity-classic.png").read_bytes())
        b = predecessor.png_rgba(path_in(folder, label + "/frequency-haze-opacity-wipe.png").read_bytes())
        require(region(a, [128, 0, 64, 64]) == region(b, [128, 0, 64, 64]), "Actual Classic haze/opacity wipe is not exact")
    return {"synthetic_png_pairs": len(synthetic),
            "synthetic_compared_bytes": sum(row["compared_bytes"] for row in synthetic.values())}


def verify_pixels(folder, result, predecessor):
    summary = verify_shader_pixels(folder, predecessor)
    images = {}
    for row in result["probe_samples"]:
        capture = row["paused_capture"]
        path = path_in(folder, "progression/" + capture["filename"])
        require(sha(path) == capture["sha256"], "Original native-scene capture changed")
        decoded = predecessor.png_rgba(path.read_bytes())
        require(capture.get("actual_image_size") == list(decoded[:2]), "Recorded capture extent differs from original PNG")
        images[capture["tag"]] = region(decoded, capture["camera"]["world_rect"])
    for pair in result["pixel_equivalence"]:
        a, b = images[pair["original"]], images[pair["candidate"]]
        require(a == b and a[0] == pair.get("world_rect") and pair["pixels"] == a[0][2]*a[0][3],
                "Actual unresampled native-scene world pixels differ from recorded exact comparison")
    return {**summary, "world_png_pairs": 6,
            "world_compared_pixels": sum(row["pixels"] for row in result["pixel_equivalence"]), "exact": True}


def verify_custody(folder, record, application_root, q):
    source = q.identity()
    require(record.get("application_source") == source and source["source_commit"] == APPLICATION
            and source["source_tree"] == APPLICATION_TREE and source["local_delta"] == [], "Frozen application source changed")
    observer = record.get("observer_source", {})
    require(shared.HEX40.fullmatch(str(observer.get("source_commit", "")))
            and observer.get("source_tree") == git(ROOT, "rev-parse", observer["source_commit"] + "^{tree}").decode().strip()
            and observer.get("location") == "external-to-application-project"
            and set(observer.get("source_inputs_raw_sha256", {})) == set(FILES), "Missing separate external experiment identity")
    for name in FILES:
        retained = path_in(folder, "observer/" + Path(name).name)
        require(sha(retained) == observer["source_inputs_raw_sha256"][name]
                and retained.read_bytes().replace(b"\r\n", b"\n") == git(ROOT, "show", observer["source_commit"] + ":" + name),
                "External experiment bytes changed: " + name)
    require(observer["source_inputs_raw_sha256"][SHADER] == CANDIDATE, "Unregistered candidate shader")
    runtime = record.get("runtime", {})
    loaded = {name.removeprefix("godot/"): value for name, value in source["source_inputs_sha256"].items() if name.startswith("godot/")}
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = runtime.get(kind, {})
        require(isinstance(entry.get("path"), str) and shared.HEX64.fullmatch(str(entry.get("sha256", "")))
                and integer(entry.get("size"), 1), "Missing exact runtime identity")
        require(git(application_root, "show", APPLICATION + ":" + entry["path"]) ==
                f"version https://git-lfs.github.com/spec/v1\noid sha256:{entry['sha256']}\nsize {entry['size']}\n".encode(),
                "Observed runtime differs from frozen LFS identity")
        loaded[entry["path"].removeprefix("godot/")] = entry["sha256"]
    assets = {name.removeprefix("godot/"): value for name, value in source["source_assets_sha256"].items()}
    require(record.get("application_loaded_source_sha256") == loaded and record.get("application_assets_sha256") == assets
            and record.get("application_after") == {"source": source, "loaded_source_sha256": loaded, "assets_sha256": assets},
            "Application before/after source or asset snapshots differ")
    provenance = runtime.get("runtime_provenance", {})
    require(isinstance(provenance.get("path"), str) and shared.HEX64.fullmatch(str(provenance.get("sha256", "")))
            and hashlib.sha256(git(application_root, "show", APPLICATION + ":" + provenance["path"])).hexdigest() == provenance["sha256"],
            "Retained native provenance differs")
    manifest = json.loads(git(application_root, "show", APPLICATION + ":" + provenance["path"]))
    require(runtime.get("native_source_inputs") == manifest.get("source_inputs")
            and all(source["source_inputs_sha256"].get(name) == value for name, value in runtime["native_source_inputs"].items()),
            "Native runtime is not bound to application inputs")
    require(record.get("godot", {}).get("sha256") == q.previous.GODOT_SHA256.get(record.get("host", {}).get("platform"))
            and record["godot"].get("version") == q.previous.custody.windows.GODOT_VERSION, "Unqualified Godot runtime")
    return observer


def identity_command(record, paths):
    return [record["godot"]["execution_path"], "--headless", "--path", record["application_execution_project"],
            "--script", paths["diagnostic"], "--", "--optical-shader-override=" + paths["shader"]]


def verify_identity_process(folder, record, observer, paths, q):
    _, text = verify_process(folder, "identity-diagnostic", record, identity_command(record, paths), 60, q)
    require(not re.search(r"^OpenGL API ", text, re.MULTILINE), "Resource diagnostic must remain explicitly headless")
    return validate_identity_diagnostic(marker(text, "STRATA3_SHADER_RESOURCE_DIAGNOSTIC "),
                                        observer["source_inputs_raw_sha256"][DIAGNOSTIC])


def verify_shader_processes(folder, record, observer, paths, q):
    backends = []
    for label in ("shader-original", "shader-candidate"):
        script = "res://tests/test_strata_optical_renderer.gd" if label == "shader-original" else paths["wrapper"]
        command = graphical_command(record, script) + ["--", "--output=" + paths[label]]
        if label == "shader-candidate": command += ["--optical-shader-override=" + paths["shader"]]
        _, text = verify_process(folder, label, record, command, 600, q)
        require(text.count("STRATA003_OPTICAL_RENDERER graphical_required=false checks=109 failures=0") == 1
                and "graphical_required=true" not in text, "The unchanged109 actual renderer assertions did not pass")
        backend = re.findall(r"^OpenGL API [^\r\n]+", text, re.MULTILINE)
        require(len(backend) == 1 and "Using Device:" in backend[0], "Missing actual graphical backend")
        backends.append(backend[0])
        require(marker(text, "STRATA003_CLASSIC_WIPE_PRECISION ") ==
                {"changed_channels": 0, "compared_bytes": 16384, "maximum_u8_delta": 0}, "Classic exactness marker changed")
        progression = marker(text, "STRATA003_APERTURE_PROGRESSION ")
        require([row.get("radius_cells") for row in progression] == [0, 1, 2, 3, 6]
                and .75 < progression[0].get("checker_contrast", -1) < .85
                and all(row.get("checker_contrast") == 0 and row.get("thin_white_hue_preserved") is True for row in progression[1:])
                and progression[0].get("thin_white_hue_preserved") is True, "Dense aperture graphical witness changed")
        if label == "shader-candidate":
            receipt = marker(text, "STRATA003_SHADER_OVERRIDE ")
            require(receipt.get("application") == APPLICATION and receipt.get("original_shader_sha256") == ORIGINAL
                    and receipt.get("candidate_shader_sha256") == CANDIDATE
                    and receipt.get("wrapper_sha256") == observer["source_inputs_raw_sha256"][WRAPPER], "Runtime shader override receipt differs")
        else:
            require("STRATA003_SHADER_OVERRIDE " not in text, "Original shader case was overridden")
    require(backends[0] == backends[1], "Original/candidate shader fixtures used different backends")
    return backends[0]


def validate_execution_paths(execution_root, paths):
    require(isinstance(execution_root, str) and execution_root, "Missing original evidence execution location")
    normalized = execution_root.replace("\\", "/").rstrip("/")
    require(normalized.startswith("/") or re.match(r"^[A-Za-z]:/", normalized), "Evidence execution location must be absolute")
    expected = {"driver": "observer/" + Path(DRIVER).name, "wrapper": "observer/" + Path(WRAPPER).name,
                "shader": "observer/" + Path(SHADER).name, "diagnostic": "observer/" + Path(DIAGNOSTIC).name,
                "shader-original": "shader-original", "shader-candidate": "shader-candidate"}
    require(set(paths) == set(expected) and all(isinstance(paths[key], str)
            and paths[key].replace("\\", "/") == normalized + "/" + relative for key, relative in expected.items()),
            "Actual execution paths do not bind the retained observer and capture locations")


def verify(folder, application_root):
    q, predecessor = shared.application_modules(application_root)
    record = json.loads((folder / "annex.json").read_text(encoding="utf-8"))
    require(record.get("schema") == "strata3-shader-cost-annex-v2" and record.get("completed") is True
            and record.get("failures") == [] and record.get("application_project_unchanged") is True,
            "Incomplete shader cost annex")
    require(record.get("files_sha256") == shared.evidence_files(folder), "Original experiment evidence inventory changed")
    for name in record["files_sha256"]: path_in(folder, name)
    observer = verify_custody(folder, record, application_root, q)
    paths = record.get("execution_paths", {})
    validate_execution_paths(record.get("execution_evidence_root"), paths)
    require(set(record.get("processes", {})) == {"bootstrap", "identity-diagnostic", "shader-original", "shader-candidate", "progression"},
            "Missing actual experiment process")
    verify_process(folder, "bootstrap", record, [record["godot"]["execution_path"], "--headless", "--editor", "--path",
                   record["application_execution_project"], "--quit"], 300, q)
    require(record.get("identity_diagnostic") == verify_identity_process(folder, record, observer, paths, q),
            "Retained shader-identity diagnostic differs from original process")
    backend = verify_shader_processes(folder, record, observer, paths, q)
    result = json.loads(path_in(folder, "progression/report.json").read_text(encoding="utf-8"))
    summary = validate_observation(result, observer_sha256=observer["source_inputs_raw_sha256"][DRIVER],
                                   observer_source_revision=observer["source_commit"])
    process, text = verify_process(folder, "progression", record, graphical_command(record, paths["driver"]), 1800, q, result["process_id"])
    require(re.findall(r"^OpenGL API [^\r\n]+", text, re.MULTILINE) == [backend], "Native cost probe used another renderer")
    require(result["display_server"] in (("Windows",) if record["host"]["platform"] == "win32" else ("X11", "Wayland")),
            "Actual graphical platform differs from host")
    if record["host"]["platform"] == "linux": require(result["process_id"] == process["pid"], "Actual engine PID differs")
    raw = json.loads(path_in(folder, "progression/resources.json").read_text(encoding="utf-8"))
    times = [row.get("elapsed_seconds") for row in raw["samples"] if any(item["pid"] == result["process_id"] for item in row["processes"])]
    require(raw.get("sample_interval_seconds") == .5 and 2 <= len(times) <= 3603
            and all(number(value) for value in times) and all(b > a for a, b in zip(times, times[1:]))
            and times[-1] - times[0] >= sum(row["elapsed_usec"] for row in result["probe_samples"])/1e6 - 1,
            "Bounded CPU/RSS observation did not span actual timed populations")
    summary["pixel_equivalence"] = verify_pixels(folder, result, predecessor)
    summary["actual_renderer"] = backend
    summary["whole_progression_process_seconds"] = process["seconds"]
    summary["whole_progression_process_resources"] = process["resources"]
    require(record.get("summary") == summary, "Cost summary differs from original evidence")
    return summary


def run(args):
    root, output, godot = args.application_root.resolve(), args.output.resolve(), args.godot.resolve()
    require(not output.exists(), "Use a fresh evidence directory; retain failures")
    require(root != ROOT.resolve() and not output.is_relative_to(root / "godot"), "Experiment must remain external to application")
    q, predecessor = shared.application_modules(root)
    previous, custody = q.previous, q.previous.custody
    require(sha(godot) == previous.GODOT_SHA256.get(sys.platform), "Godot differs from pinned4.7")
    version = subprocess.check_output([str(godot), "--version"], timeout=20).decode().strip()
    require(version == custody.windows.GODOT_VERSION, "Wrong exact Godot version")
    source, runtime, observer = q.identity(), custody.verify_runtime_identity(), observer_identity()
    require(source["local_delta"] == [], "Immutable application has a local source delta")
    project = root / "godot"
    loaded, assets = custody.project_identity(project, source, runtime), previous.project_assets_identity(project, source)
    output.mkdir(parents=True)
    retained = output / "observer"; retained.mkdir()
    for name in FILES: shutil.copyfile(ROOT / name, retained / Path(name).name)
    paths = {"driver": str(retained / Path(DRIVER).name), "wrapper": str(retained / Path(WRAPPER).name),
             "shader": str(retained / Path(SHADER).name), "diagnostic": str(retained / Path(DIAGNOSTIC).name),
             "shader-original": str(output / "shader-original"),
             "shader-candidate": str(output / "shader-candidate")}
    record = {"schema": "strata3-shader-cost-annex-v2", "completed": False, "failures": [], "processes": {},
              "application_source": source, "application_loaded_source_sha256": loaded, "application_assets_sha256": assets,
              "application_execution_project": str(project), "observer_source": observer, "execution_paths": paths,
              "execution_evidence_root": str(output),
              "runtime": runtime, "godot": {"sha256": sha(godot), "version": version, "execution_path": str(godot)},
              "host": {"platform": sys.platform, "system": platform.platform(), "machine": platform.machine(),
                       "logical_cpu_count": os.cpu_count(), "job": os.environ.get("GITHUB_JOB", ""),
                       "run_id": os.environ.get("GITHUB_RUN_ID", ""), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "")}}
    try:
        q.metrics.MAX_SAMPLES = 1203
        environment = custody.case_environment(output / "userdata/bootstrap")
        record["processes"]["bootstrap"] = q.metrics.execute([str(godot), "--headless", "--editor", "--path", str(project), "--quit"],
                                                             output / "bootstrap", environment, 300)
        require(record["processes"]["bootstrap"]["status"] == "passed", "Immutable application import failed")
        environment = custody.case_environment(output / "userdata/identity-diagnostic")
        record["processes"]["identity-diagnostic"] = q.metrics.execute(identity_command(record, paths),
                                                                       output / "identity-diagnostic", environment, 60)
        record["identity_diagnostic"] = verify_identity_process(output, record, observer, paths, q)
        for label in ("shader-original", "shader-candidate"):
            environment = custody.case_environment(output / "userdata" / label)
            script = "res://tests/test_strata_optical_renderer.gd" if label == "shader-original" else paths["wrapper"]
            command = graphical_command(record, script) + ["--", "--output=" + paths[label]]
            if label == "shader-candidate": command += ["--optical-shader-override=" + paths["shader"]]
            record["processes"][label] = q.metrics.execute(command, output / label, environment, 600)
            require(record["processes"][label]["status"] == "passed", "Actual renderer fixture failed: " + label)
        # Reject shader correctness/equivalence before spending native timing.
        verify_shader_processes(output, record, observer, paths, q)
        verify_shader_pixels(output, predecessor)
        environment = custody.case_environment(output / "userdata/progression")
        environment.update(STRATA_SCENE="optics-readability-challenge", STRATA_PHASE="progression",
                           STRATA_EVIDENCE=str(output / "progression"), STRATA_REPORT=str(output / "progression/report.json"),
                           CYBERSAND_SOURCE_REVISION=APPLICATION, STRATA3_DRIVER_SHA256=sha(Path(paths["driver"])),
                           STRATA3_OBSERVER_SOURCE_REVISION=observer["source_commit"],
                           STRATA3_SHADER_OVERRIDE_PATH=paths["shader"], STRATA3_SHADER_OVERRIDE_SHA256=CANDIDATE)
        environment.pop("STRATA3_DIAGNOSTIC_HEADLESS", None)
        q.metrics.MAX_SAMPLES = 3603
        record["processes"]["progression"] = q.metrics.execute(graphical_command(record, paths["driver"]), output / "progression",
                                                               environment, 1800, maximum_timeout=1800)
        require(record["processes"]["progression"]["status"] == "passed", "Actual native cost process failed")
        result = json.loads((output / "progression/report.json").read_text(encoding="utf-8"))
        summary = validate_observation(result, observer_sha256=sha(Path(paths["driver"])), observer_source_revision=observer["source_commit"])
        summary["pixel_equivalence"] = verify_pixels(output, result, predecessor)
        log = (output / "progression/process.log").read_text(encoding="utf-8")
        backends = re.findall(r"^OpenGL API [^\r\n]+", log, re.MULTILINE)
        require(len(backends) == 1, "Actual rendering backend missing")
        summary["actual_renderer"] = backends[0]
        summary["whole_progression_process_seconds"] = record["processes"]["progression"]["seconds"]
        summary["whole_progression_process_resources"] = record["processes"]["progression"]["resources"]
        record["summary"] = summary
        record["application_after"] = {"source": q.identity(), "loaded_source_sha256": custody.project_identity(project, source, runtime),
                                       "assets_sha256": previous.project_assets_identity(project, source)}
        require(record["application_after"] == {"source": source, "loaded_source_sha256": loaded, "assets_sha256": assets},
                "Application source or assets changed during runtime shader experiment")
        record["application_project_unchanged"] = True
        record["completed"] = True
    except Exception as error:
        record["failures"].append(str(error))
    finally:
        record["files_sha256"] = shared.evidence_files(output)
        write_json(output / "annex.json", record)
    require(record["completed"] and not record["failures"], "Cost annex rejected: " + "; ".join(record["failures"]))
    return verify(output, root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application-root", type=Path, required=True)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args()
    try:
        if args.verify: summary = verify(args.verify.resolve(), args.application_root.resolve())
        else:
            require(args.godot is not None and args.output is not None, "--godot and --output are required")
            summary = run(args)
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0
    except (RuntimeError, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        print("SHADER_COST_ANNEX_REJECTED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
