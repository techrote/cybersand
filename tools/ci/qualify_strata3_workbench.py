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
import platform
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
                "tools/strata3_build_showcases.py", "tools/ci/test_strata3_qualification.py",
                "tools/package_strata3_workbench.py")
REGRESSIONS = {
    "test_actor_presentation_bounds":"STRATA003_ACTOR_BOUNDS ",
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
PLANES = {"play", "scripted", "effects", "background"}
PROGRESSION_PROFILES = ("classic", "gameplay_clarity", "architectural", "cinematic_deep_focus", "diorama")
MOTION_PROFILES = ("classic", "gameplay_clarity", "cinematic_deep_focus", "diorama")


def number(value, *, positive=False) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and (value > 0 if positive else value >= 0)


def validate_statistics(stats: dict, *, disabled=False) -> None:
    require(isinstance(stats, dict) and stats.get("play_processed") is False
            and all(stats.get(key) == 0 for key in ("additional_worlds", "additional_viewports", "additional_textures",
                                                    "native_captures", "native_writes", "texture_uploads"))
            and type(stats.get("material_count")) is int and 0 <= stats["material_count"] <= 3,
            "Optical resources, native isolation or crisp Play contract changed")
    if disabled:
        require(stats.get("active") is False and stats.get("active_planes") == []
                and stats.get("uniform_writes") == 0 and stats.get("material_count") == 0,
                "Fresh Classic performed optical shader or uniform work")


def distribution(values: list[int]) -> dict:
    require(isinstance(values, list) and values and all(type(x) is int and x > 0 for x in values),
            "Missing positive original interval population")
    ordered = sorted(values)
    return {"count": len(values), **{key: ordered[math.ceil(len(ordered)*q)-1]
            for key, q in (("p50", .5), ("p95", .95), ("p99", .99))}, "max": ordered[-1],
            "stalls_at_least_usec": {str(t): sum(x >= t for x in values) for t in (100000,250000,500000,1000000)}}


def validate_progression(result: dict) -> None:
    registration = result.get("progression_registration", {})
    require(registration.get("repeats") == 3 and registration.get("callbacks_per_sample") == 90
            and registration.get("per_sample_watchdog_usec") == 90000000
            and registration.get("order") == "forward/reverse/forward"
            and registration.get("geometry_reset_between_samples") is True,
            "Physical comparison changed the registered population or native reset")
    qualities = {name:("high" if name == "diorama" else "balanced") for name in PROGRESSION_PROFILES}
    require(registration.get("quality_by_profile") == qualities, "Physical comparison changed the registered quality tiers")
    samples = result.get("progression_samples", [])
    order = [(profile, repeat) for repeat in range(3)
             for profile in (PROGRESSION_PROFILES[::-1] if repeat % 2 else PROGRESSION_PROFILES)]
    require(isinstance(samples, list) and len(samples) == 15
            and [(x.get("profile"), x.get("repeat")) for x in samples] == order,
            "Incomplete or reordered actual physical comparison windows")
    initial = samples[0].get("initial_native_play_sha256", "")
    require(HEX64.fullmatch(str(initial)), "Missing initial native material readback")
    for sample in samples:
        require(sample.get("initial_native_play_sha256") == initial and sample.get("callbacks") == 90
                and number(sample.get("elapsed_usec"), positive=True) and sample["elapsed_usec"] <= 91000000
                and sample.get("native_capture_delta") == sample.get("decorative_upload_delta") == 0
                and sample.get("physical_gpu_acceptance") is False,
                "Timed window changed geometry, capture activity, callback budget or physical acceptance scope")
        require(sample.get("configuration", {}).get("profile") == sample["profile"],
                "Timed profile differs from actual configured profile")
        require(sample.get("quality") == qualities[sample["profile"]], "Timed optical quality differs from registered cohort")
        before, after = sample.get("before", {}), sample.get("after", {})
        keys = ("worker_id", "world_generation", "physical_epoch", "actor_session_id", "actor_body_ids")
        require(all(key in before and before[key] == after.get(key) for key in keys),
                "Physical owners changed inside timed window")
        completed = sample.get("completed_physical_steps", [])
        delta = after.get("rapier_tick", -1)-before.get("rapier_tick", -1)
        native_delta = after.get("native_tick", -1)-before.get("native_tick", -1)
        require(len(completed) >= 2 and len(completed) == delta and native_delta > 0,
                "Completed-step observer omitted actual physical progression")
        require([row.get("rapier_tick") for row in completed] == list(range(before["rapier_tick"]+1,after["rapier_tick"]+1)),
                "Actual physical completion sequence contains gaps")
        physical = [b["completed_usec"]-a["completed_usec"] for a,b in zip(completed,completed[1:])]
        require(sample.get("physical_intervals_usec") == physical
                and sample.get("physical_distribution_usec") == distribution(physical)
                and sum(physical) <= sample["elapsed_usec"],
                "Physical interval summary differs from original actual completions")
        callbacks = sample.get("callback_intervals_usec", [])
        require(len(callbacks) == 90 and sample.get("callback_distribution_usec") == distribution(callbacks)
                and len(sample.get("godot_process_ms", [])) == 90
                and all(number(x) for x in sample["godot_process_ms"]) and sum(callbacks) <= sample["elapsed_usec"],
                "Incomplete original callback/main-thread observations")
        publications = sample.get("native_publications", [])
        require(len(publications) >= 2 and all(before["native_tick"] <= row.get("native_tick",-1) <= after["native_tick"] for row in publications)
                and all(b["native_tick"] > a["native_tick"]
                for a,b in zip(publications,publications[1:])), "Native publication observations are absent or repeated")
        native_intervals = [b["published_usec"]-a["published_usec"] for a,b in zip(publications,publications[1:])]
        require(sample.get("native_publication_interval_distribution_usec") == distribution(native_intervals),
                "Native publication summary differs from original observations")
        for key, ticks in (("native_ticks_per_second",native_delta),("rapier_ticks_per_second",delta)):
            require(number(sample.get(key),positive=True) and math.isclose(sample[key],ticks*1e6/sample["elapsed_usec"],rel_tol=1e-10),
                    "Progress rate differs from actual ticks and monotonic elapsed time")
        start, end = sample.get("actor_position_before",[]), sample.get("actor_position_after",[])
        require(len(start) == len(end) == 2 and number(sample.get("actor_distance_cells"),positive=True)
                and math.isclose(sample["actor_distance_cells"], math.dist(start,end),rel_tol=1e-5,abs_tol=1e-5),
                "Timed sample lacks actual actor movement")
        require(number(sample.get("scene_admission_elapsed_ms"))
                and sample.get("scene_admission_target_met") is (sample["scene_admission_elapsed_ms"] <= 45000),
                "Timed scene replacement changed the45-second admission criterion")
        validate_statistics(sample.get("optical_statistics",{}),disabled=sample["profile"] == "classic")


def validate_motion(result: dict) -> None:
    registration = result.get("motion_registration",{})
    require(registration.get("profiles") == list(MOTION_PROFILES) and registration.get("frames_per_sequence") == 10
            and registration.get("actor_count") == 3 and len(registration.get("actor_variant",[])) == 3
            and registration.get("presentation_variant") == {"parallax_strength":.65,
                "layer_depths":{"scripted":.15,"effects":.4,"background":.7}},
            "Motion differs from its registered ordinary actor/parallax fixture variant")
    sequences = result.get("motion_sequences",[])
    require(len(sequences) == 4 and [x.get("profile") for x in sequences] == list(MOTION_PROFILES),
            "Missing actual native motion profile sequences")
    initial = None
    for sequence in sequences:
        profile = sequence["profile"]
        require(sequence.get("actor_count") == 3 and sequence.get("native_pose_injected") is False
                and sequence.get("extra_worlds") == 0 and sequence.get("physical_gpu_acceptance") is False
                and sequence.get("native_capture_delta") == sequence.get("decorative_upload_delta") == 0,
                "Motion changed native authority, actor poses or decorative publication activity")
        config = sequence.get("configuration",{})
        serialized = sequence.get("configuration_canonical_json","")
        require(config.get("profile") == profile and config.get("planes",{}).get("play",{}).get("participates") is False
                and json.loads(serialized) == config and hashlib.sha256(serialized.encode()).hexdigest() == sequence.get("configuration_sha256")
                and sequence.get("quality") == ("high" if profile == "diorama" else "balanced"),
                "Motion configuration or quality differs from its original authored settings")
        require(profile != "classic" or config.get("enabled") is False,"Motion Classic was optically processed")
        before,after = sequence.get("identity_before",{}),sequence.get("identity_after",{})
        require(len(before.get("actor_body_ids",[])) == 3 and all(key in before and before[key] == after.get(key)
                for key in ("worker_id","world_generation","physical_epoch","actor_session_id","actor_body_ids")),
                "Ordinary native or actor owners changed during motion")
        hashes,end = sequence.get("plane_native_hashes_before",{}),sequence.get("plane_native_hashes_after",{})
        require(set(hashes) == set(end) == PLANES and all(HEX64.fullmatch(str(x)) for x in [*hashes.values(),*end.values()])
                and all(hashes[x] == end[x] for x in PLANES-{"play"})
                and sequence.get("decorative_identity_before") == sequence.get("decorative_identity_after")
                and sequence.get("decorative_identity_before"),"Static native decoration changed during live motion")
        if initial is None: initial = hashes
        require(hashes == initial,"Motion profiles did not start from the same authored native geometry")
        steps = sequence.get("completed_physical_steps",[])
        require(len(steps) >= 60 and len(steps) == after.get("rapier_tick",-1)-before.get("rapier_tick",-1)
                and [x.get("rapier_tick") for x in steps] == list(range(before["rapier_tick"]+1,after["rapier_tick"]+1))
                and all(b["completed_usec"] > a["completed_usec"] for a,b in zip(steps,steps[1:])),
                "Motion lacks complete actual physical progression")
        frames = sequence.get("frames",[])
        require(len(frames) == 10,"Motion needs ten original framebuffer captures")
        for index,frame in enumerate(frames):
            require(frame.get("index") == index and frame.get("filename") == f"motion-{profile}-{index:02d}.png"
                    and HEX64.fullmatch(str(frame.get("sha256",""))) and len(frame.get("actual_image_size",[])) == 2
                    and all(type(x) is int and x > 0 for x in frame["actual_image_size"])
                    and number(frame.get("picking_error")) and frame["picking_error"] < .01
                    and frame.get("camera") and frame.get("actor_state") and frame.get("submitted_action"),
                    "Motion lacks actual image, camera, actor, input or exact Play picking")
            require(all(type(frame.get(key)) is int and frame[key] >= 0 for key in ("native_tick","rapier_tick","captured_usec")),
                    "Motion frame lacks actual monotonic counters")
            if index:
                require(all(frame[key] > frames[index-1][key] for key in ("native_tick","rapier_tick","captured_usec")),
                        "Motion frames did not observe advancing actual physical state")
                require(frame["rapier_tick"]-frames[index-1]["rapier_tick"] >= 6,"Motion capture skipped its registered completed-step spacing")
            require(frame["actor_state"].get("rapier_tick") == frame["rapier_tick"]
                    and before["rapier_tick"] < frame["rapier_tick"] <= after["rapier_tick"]
                    and before["native_tick"] < frame["native_tick"] <= after["native_tick"]
                    and frame["camera"].get("view_size") == ([480,270] if 4 <= index < 8 else [240,135]),
                    "Motion actor/camera/tick receipt differs from registered pan and zoom")
            action = frame["submitted_action"]
            require(isinstance(action.get("move"),list) and len(action["move"]) == 2
                    and all(type(x) in (int,float) and math.isfinite(x) and -1 <= x <= 1 for x in action["move"])
                    and action.get("primary") is True and number(action.get("effort")) and action["effort"] <= 1,
                    "Motion frame lacks bounded ordinary piloting input")
            validate_statistics(frame.get("optics_statistics",{}))
            if profile == "gameplay_clarity":
                require(3 <= frame["optics_statistics"].get("actor_reveal_rectangles",-1) <= 8,
                        "Clarity did not receive the three actual published actor bounds")
        require(math.dist(frames[0]["actor_state"]["position"],frames[-1]["actor_state"]["position"]) > 0,
                "Motion sequence did not move the selected ordinary actor")


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
    require(isinstance(value, str) and value and "\\" not in value
            and not any(ord(character) < 32 for character in value),
            "Empty or platform-dependent evidence path")
    # Evidence uses one canonical POSIX-relative spelling on both hosts. A
    # Windows Path('/outside') is rooted but is_absolute() is false without a
    # drive; validate the original components before host Path normalization.
    parts = value.split("/")
    require(all(part not in ("", ".", "..") for part in parts) and ":" not in value,
            "Unsafe evidence path")
    return Path(*parts)


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
    require(result.get("world_count") == {"decorative_owned":3,"play_borrowed":1}
            and result.get("teardown",{}).get("native_world_count") == 0
            and result.get("teardown",{}).get("pending_native_world_count") == 0,
            "Four-plane ownership or decorative retirement failed")
    if phase == "progression":
        validate_progression(result)
    elif phase == "motion":
        validate_motion(result)
    if phase != "progression":
        require(result.get("admission_target_ms") == 45000,
                "Original scene admission target changed")
        elapsed = result.get("admission_elapsed_ms")
        require(type(elapsed) in (int, float) and math.isfinite(elapsed) and elapsed >= 0
                and result.get("admission_target_met") is (elapsed <= 45000),
                "Admission result does not retain the original timing criterion")
    if phase == "install":
        classic = result.get("classic_return",{})
        require(classic.get("exact_equal") is True and classic.get("changed_pixels") == 0
                and classic.get("max_channel_difference_u8") == 0, "Classic return is not framebuffer exact")
        controls = result.get("optical_controls",{})
        require(controls.get("identity_before") and controls["identity_before"] == controls.get("identity_after")
                and controls.get("decorative_capture_delta") == controls.get("decorative_upload_delta") == 0
                and controls.get("native_edit_target_retained") is True,
                "Optical controls changed native ownership, editing authority or presentation capture activity")
        counts = controls.get("profile_switch_material_counts",[])
        require(len(counts) == 33 and all(type(x) is int and 0 <= x <= 3 for x in counts),
                "Repeated profile changes exceeded bounded material ownership")
        witnesses = result.get("native_edit_witnesses",[])
        if scene == "optics-readability-challenge":
            require(len(witnesses) == 2 and {x.get("plane") for x in witnesses} == {"play","background"}
                    and all(x.get("native_brush") == (58 if x.get("native_before") == 131 else 131)
                            and x.get("native_erase") == 0 and x.get("native_restored") == x.get("native_before") for x in witnesses),
                    "Missing native paint/erase/history restoration under active optics")
        transforms = result.get("transforms",{})
        require(transforms.get("samples",0) >= 24 and number(transforms.get("max_error"))
                and transforms["max_error"] < .01 and transforms.get("camera_floor_matches_host") is True,
                "Camera/picking round trips differ from authoritative Play mapping")
        lab = result.get("lab",{})
        require(lab.get("master_visible") is True and lab.get("tab_count") == 6 and lab.get("optics_tab_index") == 5
                and lab.get("native_target_before") == lab.get("native_target_after")
                and lab.get("custom_presets"), "Integrated visible authoring controls or named preset did not execute")
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
        actor = captures[0].get("actor_state")
        require(isinstance(actor,dict) and actor and all(row.get("actor_state") == actor for row in captures),
                "Matched optical images changed actor state")
        hashes = result.get("plane_native_hashes_before",{})
        canonical = result.get("native_hashes_canonical_json","")
        require(set(hashes) == PLANES and all(HEX64.fullmatch(str(x)) for x in hashes.values())
                and hashes == result.get("plane_native_hashes_after") and json.loads(canonical) == hashes,
                "Whole native planes lack unchanged source-bound readback")
        geometry = hashlib.sha256(canonical.encode()).hexdigest()
        require(all(row.get("geometry_group_sha256") == geometry for row in captures),
                "Matched optical images changed native geometry identity")
        for capture in captures: validate_statistics(capture.get("optics_statistics",{}))
    if phase == "reopen":
        require(result.get("fresh_process_reopen") is True and result.get("document_version") == 3
                and result.get("saved_optics",{}).get("inspection_after_reopen")
                == {"bypass":False,"clarity":False,"wipe":1.0,"focus_override":""},
                "Fresh process did not restore authored optics independently of inspection")


def validate_loaded_project_record(report: dict, source: dict) -> None:
    """Replay the existing project_identity contract, including portable SWARM.

    Accepted main permits an extracted installation to omit only the other
    platform's generator binding and records its actual, verified local CLI.
    All original scripts, host bindings, native libraries and raw art remain
    mandatory. The source checkout itself still uses the full source map.
    """
    runtime, project = report["runtime"], report.get("project", {})
    expected = {name.removeprefix("godot/"): digest for name, digest in source["source_inputs_sha256"].items()
                if name.startswith("godot/")}
    actual = project.get("inputs_sha256", {})
    windows = runtime["cybersand_runtime"]["path"].endswith(".dll")
    host, other = ("windows", "linux") if windows else ("linux", "windows")
    cli = "tools/gentek_reciprocal.exe" if windows else "tools/gentek_reciprocal"
    binding_name = "tools/swarm004-runtime." + host + ".json"
    other_binding = "tools/swarm004-runtime." + other + ".json"
    if cli in actual:
        raw = (ROOT / "godot" / binding_name).read_bytes()
        require(hashlib.sha256(raw.replace(b"\r\n", b"\n")).hexdigest() == expected.get(binding_name),
                "Installed CLI binding differs from the recorded source")
        binding = json.loads(raw)
        require(binding.get("artifact") == "godot/" + cli and binding.get("platform") == host
                and re.fullmatch(r"[0-9a-f]{64}", str(binding.get("sha256", ""))),
                "Installed CLI binding has an invalid target or hash")
        expected[cli] = binding["sha256"]
        if other_binding not in actual:
            expected.pop(other_binding, None)
    for key in ("cybersand_runtime", "rapier_runtime"):
        item = runtime[key]
        expected[item["path"].removeprefix("godot/")] = item["sha256"]
    require(expected and actual == expected
            and project.get("assets_sha256") == {k.removeprefix("godot/"): v for k, v in source["source_assets_sha256"].items()},
            "Actual loaded project lacks full source/runtime/raw artwork custody")


def verify_campaign(folder: Path, expected: dict | None = None, *, full: bool = True) -> dict:
    folder = folder.resolve(strict=True)
    report = json.loads((folder / "campaign.json").read_text(encoding="utf-8"))
    require(report.get("schema") == "strata3-workbench-campaign-v1" and report.get("status") == "passed"
            and report.get("completed") is True and report.get("input_custody") == "passed",
            "Incomplete or failing source-bound optical campaign")
    source = report.get("source_identity", {})
    if expected is None: expected = identity()
    require(source and source.get("local_delta") == [] and source == expected,
            "Optical campaign source differs or contains a local delta")
    platform = report.get("platform")
    engine = report.get("godot", {})
    require(platform in previous.GODOT_SHA256 and engine.get("sha256") == previous.GODOT_SHA256[platform]
            and engine.get("version") == previous.custody.windows.GODOT_VERSION,
            "Optical campaign engine differs from the official pinned runtime")
    require(report.get("runtime") == previous.retained_runtime_manifest(platform),
            "Optical campaign native/Rapier runtime differs from source-bound retained inputs")
    runtime = report["runtime"]
    require(all(source.get("source_inputs_sha256",{}).get(name) == digest
                for name,digest in runtime["native_source_inputs"].items()), "Native runtime no longer matches its production source")
    project = report.get("project",{})
    validate_loaded_project_record(report, source)
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
    require(report.get("suite") in ("shader","smoke","full") and isinstance(report.get("selected_scenes"),list)
            and report["selected_scenes"] == (list(SCENES) if report["suite"] == "full" else
                                               ["industrial-underworks"] if report["suite"] == "smoke" else []),
            "Optical suite selection changed or omitted native scenes")
    expected_labels.update(scene + "/" + phase for scene in selected for phase in ("install", "reopen"))
    if report.get("suite") == "full":
        expected_labels.update("optics-readability-challenge/"+phase for phase in ("progression","motion"))
    require({row["label"] for row in cases} == expected_labels, "Optical process coverage differs from admitted suite")
    for case in cases:
        directory = folder / safe_relative(case["output_dir"])
        process = json.loads((directory / "process.json").read_text(encoding="utf-8"))
        require(case.get("process") == process and process.get("status") == "passed"
                and case.get("exit_code") == process.get("exit_code") == 0,
                "Original optical process does not match the successful case")
        require(type(process.get("pid")) is int and process["pid"] > 0
                and number(process.get("timeout_seconds"),positive=True)
                and process["timeout_seconds"] == (1800 if case["phase"] == "progression" else 600)
                and number(process.get("seconds"),positive=True) and process["seconds"] <= process["timeout_seconds"]+5,
                "Original optical process lacks a bounded successful execution")
        base = [engine["path"],"--audio-driver","Dummy","--rendering-method","gl_compatibility",
                "--rendering-driver","opengl3","--path",project["path"]]
        if case["phase"] == "import": flags = ["--headless","--editor","--quit"]
        elif case["phase"] == "regression":
            name = case["label"].split("/")[-1]
            flags = ["--script","res://tests/"+name+".gd"]
            if name == "test_strata_optical_renderer":
                command = process.get("command",[])
                require(len(command) == len(base)+4 and command[-2] == "--"
                        and command[-1].startswith("--output=")
                        and command[-1].replace("\\","/").endswith("/"+case["label"]),
                        "Graphical shader evidence output differs from actual process")
                flags += command[-2:]
        else: flags = ["--script",HARNESS]
        require(process.get("command") == base+flags, "Actual optical command differs from the admitted graphical entry point")
        previous.verify_resource_receipt(folder,dict(process,label=case["label"]))
        log = directory / "process.log"
        text = log.read_text(encoding="utf-8")
        require(sha(log) == process.get("log_sha256") and not previous.custody.ERRORS.search(text)
                and "Godot Engine v" + engine["version"] in text,
                "Original optical process log differs, lacks engine identity or contains errors")
        if case["phase"] == "regression":
            require(REGRESSIONS[case["label"].split("/")[-1]] in text,
                    "Required optical regression completion marker is missing")
        elif case["phase"] in ("install", "reopen", "progression", "motion"):
            result_path = folder / safe_relative(case["result_path"])
            result = json.loads(result_path.read_text(encoding="utf-8"))
            require(result == case.get("result") and sha(result_path) == case.get("report_sha256"),
                    "Embedded optical result differs from original report")
            validate_result(result, case["scene"], case["phase"], source["source_commit"])
            require(result["display_server"] in (("Windows",) if platform == "win32" else ("X11", "Wayland")),
                    "Actual graphical display differs from claimed platform")
            if platform == "linux": require(result["process_id"] == process["pid"], "Actual Linux engine PID differs")
            previous.verify_resource_receipt(folder,dict(process,label=case["label"]),result["process_id"])
            captures = list(result.get("profile_captures", []))
            captures += [frame for sequence in result.get("motion_sequences",[]) for frame in sequence.get("frames",[])]
            for capture in captures:
                path = directory / safe_relative(capture["filename"])
                require(path.is_file() and path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
                        and path.relative_to(folder).as_posix() in ledger and sha(path) == capture.get("sha256"),
                        "Missing or changed original graphical profile capture")
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
              "platform":sys.platform,"suite":args.suite,"selected_scenes":selected,"cases":[],
              "host":{"system":platform.platform(),"machine":platform.machine(),"logical_cpu_count":os.cpu_count(),
                      "run_id":os.environ.get("GITHUB_RUN_ID",""),"run_attempt":os.environ.get("GITHUB_RUN_ATTEMPT",""),
                      "job":os.environ.get("GITHUB_JOB",""),"physical_gpu_acceptance":False},
              "observer_configuration":{"resource_sample_seconds":metrics.SAMPLE_SECONDS,"maximum_processes":metrics.MAX_PROCESSES,
                                        "progression_callbacks_per_sample":90,"progression_repeats":3}}
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
            process = metrics.execute(base + flags,location,env,timeout, maximum_timeout=timeout)
            row.update(process=process,exit_code=process["exit_code"])
            if phase in ("install","reopen","progression","motion") and (location / "result.json").is_file():
                result = json.loads((location / "result.json").read_text(encoding="utf-8"))
                row.update(result=result,result_path=label+"/result.json",report_sha256=sha(location/"result.json"))
            write_json(output/"campaign.json",report)
            require(process["status"] == "passed", process.get("error","Optical process failed"))
            if phase == "regression":
                marker = REGRESSIONS[label.split("/")[-1]]
                require(marker in (location/"process.log").read_text(encoding="utf-8"), "Missing actual regression marker " + marker)
            if phase in ("install","reopen","progression","motion"):
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
            label = scene+"/motion"
            env = previous.custody.case_environment(output/"userdata"/"motion")
            env.update(CYBERSAND_SOURCE_REVISION=source["source_commit"],STRATA_SCENE=scene,STRATA_PHASE="motion",
                       STRATA_EVIDENCE=str(output/label),STRATA_REPORT=str(output/label/"result.json"))
            run(label,["--script",HARNESS],env,"motion",scene)
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
