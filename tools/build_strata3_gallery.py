#!/usr/bin/env python3
"""Build an offline, source-bound gallery of original Strata Optics captures.

This program never generates, edits, crops or resamples an image. It validates
actual campaign receipts and original PNG bytes before emitting local HTML and
an input manifest. Unit-test fixtures are deliberately labelled synthetic and
do not constitute Godot, native, graphical or perceptual qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = "tools/build_strata3_gallery.py"
SCENES = ("orbital-terminal", "neon-rain-arcology", "industrial-underworks", "abyss-foundry", "vertical-transfer-spine",
          "sunward-freight-megastructure", "xeno-resonance-grotto", "lunar-terminator-observatory", "optics-readability-challenge")
PROFILES = {"classic":"Classic", "architectural":"Architectural", "gameplay_clarity":"Gameplay Clarity",
            "cinematic_deep_focus":"Cinematic Deep Focus", "optical_lens":"Optical Lens", "diorama":"Diorama",
            "atmospheric_industrial":"Atmospheric Industrial", "noir":"Noir", "cold_orbital":"Cold Orbital",
            "alien_bioluminescence":"Alien Bioluminescence", "sunlit_megastructure":"Sunlit Megastructure"}
PLANES = ("play", "scripted", "effects", "background")
SUPPLEMENTAL = {"classic-return", "compare-wipe", "clarity-assistance", "focus-play", "focus-scripted", "focus-effects", "focus-background", "optics-lab"}
MOTION_PROFILES = ("classic", "gameplay_clarity", "cinematic_deep_focus", "diorama")
HASH = re.compile(r"[0-9a-f]{64}\Z")
COMMIT = re.compile(r"[0-9a-f]{40}\Z")
IDENTITY = re.compile(r"[a-z0-9][a-z0-9_-]{0,79}\Z")
ENGINE_VERSION = "4.7.stable.official.5b4e0cb0f"
ENGINE_SHA = {"linux":"f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75",
              "win32":"d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c"}


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "Expected a JSON object: " + str(path))
    return value


def safe_path(root: Path, name: str) -> Path:
    require(isinstance(name, str) and bool(name) and "\\" not in name and ":" not in name,
            "Unsafe evidence path")
    parts = PurePosixPath(name)
    require(not parts.is_absolute() and ".." not in parts.parts and parts.as_posix() == name,
            "Unsafe evidence path")
    path = root
    for component in parts.parts:
        path = path / component
        require(not path.is_symlink(), "Linked evidence is not an original payload: " + name)
    require(path.resolve().is_relative_to(root.resolve()), "Evidence escapes its admitted root")
    return path


def png_extent(data: bytes) -> list[int]:
    require(len(data) >= 45 and data[:8] == b"\x89PNG\r\n\x1a\n", "Capture is not a PNG")
    offset, size, found_data, found_end = 8, None, False, False
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        require(length <= 128 * 1024 * 1024 and offset + length + 12 <= len(data), "Truncated or unbounded PNG chunk")
        body = data[offset + 8:offset + 8 + length]
        expected_crc = struct.unpack(">I", data[offset + 8 + length:offset + 12 + length])[0]
        require(zlib.crc32(kind + body) & 0xffffffff == expected_crc, "PNG chunk CRC changed")
        if offset == 8:
            require(kind == b"IHDR" and length == 13, "Missing native PNG header")
            width, height = struct.unpack(">II", body[:8])
            require(0 < width <= 8192 and 0 < height <= 8192, "Capture dimensions exceed the gallery budget")
            size = [width, height]
        elif kind == b"IHDR":
            raise ValueError("Duplicate PNG header")
        if kind == b"IDAT": found_data = True
        offset += length + 12
        if kind == b"IEND":
            require(length == 0 and offset == len(data), "Unexpected bytes after original PNG end")
            found_end = True
            break
    require(size is not None and found_data and found_end, "Incomplete original PNG")
    return size


def four_hashes(value: object) -> dict:
    require(isinstance(value, dict) and set(value) == set(PLANES)
            and all(isinstance(item, str) and HASH.fullmatch(item) for item in value.values()),
            "Missing authoritative four-plane material hashes")
    return value


def finite_vector(value: object, length: int) -> bool:
    return isinstance(value, list) and len(value) == length and all(type(x) in (int, float) and math.isfinite(x) for x in value)


def validate_camera(value: object) -> dict:
    require(isinstance(value, dict) and finite_vector(value.get("origin"), 2)
            and finite_vector(value.get("view_size"), 2) and min(value["view_size"]) > 0
            and finite_vector(value.get("world_rect"), 4) and min(value["world_rect"][2:]) > 0,
            "Missing finite actual camera mapping")
    return value


def admission_observation(result: dict) -> dict:
    elapsed = result.get("admission_elapsed_ms")
    require(type(elapsed) in (int, float) and math.isfinite(elapsed) and elapsed >= 0
            and result.get("admission_target_ms") == 45000
            and result.get("admission_target_met") is (elapsed <= 45000),
            "Scene admission must retain the actual observation and unchanged 45-second target")
    return {"elapsed_ms":elapsed, "target_ms":45000, "target_met":elapsed <= 45000,
            "scope":"Observed scene admission in this process; a target miss remains a performance limitation even when functional checks pass."}


def motion_observations(result: dict, case: dict, evidence) -> list[dict]:
    sequences = result.get("motion_sequences")
    require(isinstance(sequences, list) and len(sequences) == len(MOTION_PROFILES)
            and {item.get("profile") for item in sequences} == set(MOTION_PROFILES),
            "Motion inspection requires all four original profile sequences")
    observations = []
    for sequence in sequences:
        profile = sequence["profile"]
        config = sequence.get("configuration")
        serialized = sequence.get("configuration_canonical_json")
        require(isinstance(config, dict) and isinstance(serialized, str) and json.loads(serialized) == config
                and digest(serialized.encode()) == sequence.get("configuration_sha256")
                and config.get("profile") == profile
                and config.get("planes", {}).get("play", {}).get("participates") is False,
                "Motion settings differ from their original protected-Play configuration")
        if profile == "classic": require(config.get("enabled") is False, "Classic motion must remain disabled")
        require(sequence.get("quality") in ("low", "balanced", "high")
                and isinstance(sequence.get("scope"), str) and sequence["scope"],
                "Motion requires actual quality and an explicit instrumented scope")
        frames = sequence.get("frames")
        require(isinstance(frames, list) and len(frames) == 10, "Motion sequence requires ten actual frames")
        originals, previous, pixels = [], None, None
        for index, frame in enumerate(frames):
            filename = "motion-" + profile + "-" + f"{index:02d}" + ".png"
            require(isinstance(frame, dict) and type(frame.get("index")) is int and frame["index"] == index
                    and frame.get("filename") == filename, "Motion frame order or original filename changed")
            camera = validate_camera(frame.get("camera"))
            require(isinstance(frame.get("actor_state"), dict) and bool(frame["actor_state"])
                    and all(type(frame.get(name)) is int and frame[name] >= 0 for name in ("native_tick", "rapier_tick", "captured_usec")),
                    "Motion frame lacks actual actor, completed ticks or monotonic time")
            if previous is not None:
                require(all(frame[name] > previous[name] for name in ("native_tick", "rapier_tick", "captured_usec")),
                        "Motion frames must retain actual strictly advancing physical observations")
            raw, url = evidence(case["output_dir"] + "/" + filename)
            extent = png_extent(raw)
            require(digest(raw) == frame.get("sha256") and frame.get("actual_image_size") == extent,
                    "Motion image bytes or actual framebuffer dimensions differ from receipt")
            if pixels is None: pixels = extent
            require(extent == pixels, "Motion framebuffer extent changed within one review sequence")
            originals.append({"index":index, "url":url, "image_sha256":digest(raw), "pixels":extent,
                              "camera":camera, "actor_state":frame["actor_state"],
                              **{name:frame[name] for name in ("native_tick", "rapier_tick", "captured_usec")},
                              "picking_error":frame.get("picking_error"), "submitted_action":frame.get("submitted_action")})
            previous = frame
        observations.append({"id":profile, "label":PROFILES[profile], "configuration":config,
                             "configuration_sha256":sequence["configuration_sha256"], "quality":sequence["quality"],
                             "scope":sequence["scope"], "frames":originals,
                             "comparison_limit":"Original instrumented moving-world frames. Camera and physical state evolve; these are not matched paused profile stills. Playback cadence is arbitrary and establishes no rendering FPS or performance result."})
    observations.sort(key=lambda item:MOTION_PROFILES.index(item["id"]))
    return observations


def source_metadata(identity: str) -> tuple[dict, str]:
    if identity == "optics-readability-challenge":
        return {"id":identity, "title":"Physical readability challenge", "description":"Adversarial exact-native platforms, stairs and passages with deliberate decorative overlap. Read the fixture probes to establish actual Play authority."}, "godot/scripts/depth/strata_optics_fixtures.gd"
    directory = "strata2" if identity in SCENES[:5] else "strata3"
    name = "godot/data/" + directory + "/" + identity + ".json"
    metadata = read_json(safe_path(ROOT, name))
    require(metadata.get("id") == identity, "Native recipe identity changed")
    return metadata, name


def prepare(campaign: Path, output: Path) -> dict:
    campaign = campaign.resolve(strict=True)
    output = output.resolve()
    require(output.suffix.lower() == ".html" and output.parent.is_dir(), "Gallery output needs an existing directory and .html filename")
    require(campaign.is_relative_to(output.parent), "Original campaign must remain inside the offline package")
    report_path = safe_path(campaign, "campaign.json")
    require(report_path.is_file(), "Missing original campaign.json")
    report = read_json(report_path)
    require(report.get("schema") == "strata3-workbench-campaign-v1" and report.get("completed") is True
            and report.get("status") == "passed", "A completed passing campaign is required")
    source = report.get("source_identity", {})
    require(isinstance(source, dict) and COMMIT.fullmatch(str(source.get("source_commit", "")))
            and COMMIT.fullmatch(str(source.get("source_tree", ""))) and source.get("local_delta") == [],
            "Exact clean source identity is required")
    platform = report.get("platform")
    require(platform in ENGINE_SHA, "Unsupported actual execution platform")
    engine = report.get("godot", {})
    require(engine.get("version") == ENGINE_VERSION and engine.get("sha256") == ENGINE_SHA[platform],
            "Gallery requires the pinned official runtime identity")
    runtime = report.get("runtime", {})
    for name in ("cybersand_runtime", "rapier_runtime"):
        item = runtime.get(name, {})
        require(isinstance(item.get("path"), str) and HASH.fullmatch(str(item.get("sha256", "")))
                and type(item.get("size")) is int and item["size"] > 0, "Missing native/Rapier runtime byte identity")
    ledger = report.get("files_sha256")
    require(isinstance(ledger, dict) and bool(ledger), "Missing complete original evidence ledger")
    prefix = campaign.relative_to(output.parent).as_posix()
    used: dict[str, str] = {}

    def evidence(name: str) -> tuple[bytes, str]:
        require(name != "campaign.json" and isinstance(ledger.get(name), str) and HASH.fullmatch(ledger[name]),
                "Unrecorded evidence: " + name)
        path = safe_path(campaign, name)
        require(path.is_file(), "Missing original evidence: " + name)
        raw = path.read_bytes()
        require(digest(raw) == ledger[name], "Original evidence bytes changed: " + name)
        used[name] = ledger[name]
        return raw, (prefix + "/" + name if prefix != "." else name)

    # Validate the entire campaign ledger, including process logs and receipts,
    # rather than silently discarding an inconvenient changed non-image file.
    for name in sorted(ledger): evidence(name)
    inputs = source.get("source_inputs_sha256", {})
    require(isinstance(inputs, dict), "Missing source input ledger")
    relevant_source = [GENERATOR, "godot/scripts/depth/strata_optical_profiles.gd",
                       "godot/scripts/depth/strata_optics_configuration.gd", "godot/tools/qualify_workbench_strata3.gd"]
    metadata_rows = {}
    for scene_id in SCENES:
        metadata, source_path = source_metadata(scene_id)
        metadata_rows[scene_id] = (metadata, source_path)
        relevant_source.append(source_path)
    source_hashes = {}
    for name in relevant_source:
        path = safe_path(ROOT, name)
        require(path.is_file(), "Missing source-bound gallery input: " + name)
        hashed = digest(path.read_bytes().replace(b"\r\n", b"\n"))
        require(inputs.get(name) == hashed, "Gallery source differs from captured application: " + name)
        source_hashes[name] = hashed
    cases = report.get("cases")
    require(isinstance(cases, list) and bool(cases), "Missing original execution cases")
    labels = []
    scene_cases: dict[tuple[str, str], dict] = {}
    scene_processes = set()
    progression_reports = []
    motion_reports = []
    for case in cases:
        require(isinstance(case, dict) and isinstance(case.get("label"), str)
                and case["label"] not in labels and type(case.get("exit_code")) is int and case["exit_code"] == 0,
                "Duplicate or failed actual execution case")
        labels.append(case["label"])
        if case.get("phase") not in ("install", "reopen", "progression", "motion"): continue
        key = (case.get("scene"), case.get("phase"))
        require(key[0] in SCENES and key not in scene_processes, "Unexpected or duplicate scene process")
        scene_processes.add(key)
        raw, url = evidence(case.get("result_path", ""))
        result = json.loads(raw)
        require(digest(raw) == case.get("report_sha256") and result == case.get("result"),
                "Scene report differs from its original campaign witness")
        require(result.get("schema") == "strata3-workbench-execution-v1" and result.get("completed") is True
                and result.get("failures") == [] and result.get("scene") == key[0] and result.get("phase") == key[1]
                and result.get("source_revision") == source["source_commit"]
                and result.get("ordinary_workbench") is True and result.get("diagnostic_headless") is False
                and result.get("rendering_method") == "gl_compatibility"
                and result.get("display_server") in (["Windows"] if platform == "win32" else ["X11", "Wayland"])
                and type(result.get("process_id")) is int and result["process_id"] > 0,
                "Scene is not passing source-bound ordinary graphical execution")
        require(isinstance(case.get("output_dir"), str), "Missing original case output directory")
        safe_path(campaign, case["output_dir"])
        if key[1] == "motion":
            require(key[0] == "optics-readability-challenge", "Motion inspection must use the admitted native challenge")
            motion_reports.append({"scene":key[0], "url":url, "sha256":digest(raw),
                                   "sequences":motion_observations(result, case, evidence)})
            continue
        if key[1] == "progression":
            registration, samples = result.get("progression_registration"), result.get("progression_samples")
            require(isinstance(registration, dict) and bool(registration)
                    and isinstance(samples, list) and bool(samples), "Missing registered physical progression observations")
            summaries, sample_ids = [], set()
            for sample in samples:
                require(isinstance(sample, dict) and sample.get("profile") in PROFILES
                        and type(sample.get("repeat")) is int and sample["repeat"] >= 0
                        and type(sample.get("elapsed_usec")) is int and sample["elapsed_usec"] > 0
                        and type(sample.get("callbacks")) is int and sample["callbacks"] > 0
                        and isinstance(sample.get("physical_distribution_usec"), dict)
                        and isinstance(sample.get("observer_scope"), str) and sample["observer_scope"]
                        and sample.get("physical_gpu_acceptance") is False,
                        "Progression observation lacks its actual profile, duration or hosted scope")
                sample_id = (sample["profile"], sample["repeat"])
                require(sample_id not in sample_ids, "Duplicate profile/repeat progression observation")
                sample_ids.add(sample_id)
                fields = ("profile", "repeat", "quality", "elapsed_usec", "callbacks", "initial_native_play_sha256",
                          "scene_admission_elapsed_ms", "scene_admission_target_met", "callback_distribution_usec",
                          "physical_distribution_usec", "native_publication_interval_distribution_usec",
                          "native_ticks_per_second", "rapier_ticks_per_second", "actor_distance_cells",
                          "native_capture_delta", "decorative_upload_delta", "godot_tracked_memory_bytes",
                          "resource_count", "observer_scope", "physical_gpu_acceptance")
                summaries.append({name:sample[name] for name in fields if name in sample})
            progression_reports.append({"label":case["label"], "scene":key[0], "url":url,
                                        "sha256":digest(raw), "registration":registration, "samples":summaries})
            continue
        scene_cases[key] = {"case":case, "report":result, "url":url}
    require(set(scene_cases) == {(scene, phase) for scene in SCENES for phase in ("install", "reopen")},
            "All nine native scenes require install and fresh-process reopen")
    require(len(motion_reports) == 1, "Gallery requires the original instrumented motion inspection report")
    scenes = []
    for identity in SCENES:
        install = scene_cases[(identity, "install")]
        reopen = scene_cases[(identity, "reopen")]
        result, reopened = install["report"], reopen["report"]
        require(result["process_id"] != reopened["process_id"] and reopened.get("fresh_process_reopen") is True,
                "Fresh-process scene reopening is not established")
        before = four_hashes(result.get("plane_native_hashes_before"))
        require(before == four_hashes(result.get("plane_native_hashes_after")),
                "Optical comparison changed actual native material state")
        require(four_hashes(reopened.get("plane_native_hashes_before")) == before
                and four_hashes(reopened.get("plane_native_hashes_after")) == before,
                "Fresh-process reopening changed the captured authored native layout")
        saved, restored = result.get("saved_optics", {}), reopened.get("saved_optics", {})
        require(HASH.fullmatch(str(saved.get("sha256", ""))) and saved.get("sha256") == restored.get("sha256")
                and saved.get("configuration_canonical_json") == restored.get("configuration_canonical_json")
                and isinstance(saved.get("configuration_canonical_json"), str)
                and digest(saved["configuration_canonical_json"].encode()) == saved["sha256"],
                "Fresh-process reopening did not preserve exact authored optical settings")
        canonical_native = result.get("native_hashes_canonical_json")
        require(isinstance(canonical_native, str) and json.loads(canonical_native) == before,
                "Missing exact native comparison serialization")
        geometry_group = digest(canonical_native.encode())
        captures = result.get("profile_captures")
        require(isinstance(captures, list) and len(captures) == len(PROFILES)
                and {view.get("profile") for view in captures} == set(PROFILES),
                "Every scene requires all eleven matched profile captures")
        views, camera, actor, pixels = [], None, None, None
        for capture in captures:
            profile = capture["profile"]
            require(capture.get("filename") == "profile-" + profile + ".png", "Unexpected profile capture filename")
            capture_camera = validate_camera(capture.get("camera"))
            capture_actor = capture.get("actor_state")
            require(isinstance(capture_actor, dict) and bool(capture_actor), "Missing actual captured actor state")
            require(capture.get("geometry_group_sha256") == geometry_group, "Profile capture has a different native geometry group")
            config_json = capture.get("configuration_canonical_json")
            require(isinstance(config_json, str) and json.loads(config_json) == capture.get("configuration")
                    and digest(config_json.encode()) == capture.get("configuration_sha256"),
                    "Optical settings differ from their exact captured serialization")
            require(capture["configuration"].get("profile") == profile
                    and capture["configuration"].get("planes", {}).get("play", {}).get("participates") is False,
                    "Capture is not the identified protected-Play profile")
            if profile == "classic":
                require(capture["configuration"].get("enabled") is False, "Classic comparison was not disabled")
            name = install["case"]["output_dir"] + "/" + capture["filename"]
            raw, url = evidence(name)
            require(digest(raw) == capture.get("sha256"), "Profile capture hash differs from its actual receipt")
            capture_pixels = png_extent(raw)
            if camera is None:
                camera, actor, pixels = capture_camera, capture_actor, capture_pixels
            require(capture_camera == camera and capture_actor == actor and capture_pixels == pixels,
                    "Matched profile camera, actor state or framebuffer dimensions differ")
            views.append({"id":profile, "label":PROFILES[profile], "url":url, "image_sha256":digest(raw),
                          "pixels":capture_pixels, "configuration_sha256":capture["configuration_sha256"],
                          "configuration":capture["configuration"], "scope":"Matched paused native geometry, camera and actor state; presentation settings differ."})
        views.sort(key=lambda view:list(PROFILES).index(view["id"]))
        additional = []
        extra_ids = []
        for capture in result.get("additional_captures", []):
            extra_id = capture.get("id")
            require(isinstance(extra_id, str) and IDENTITY.fullmatch(extra_id) and extra_id not in extra_ids,
                    "Invalid or duplicate supplemental capture identity")
            extra_ids.append(extra_id)
            filename = capture.get("filename")
            require(isinstance(filename, str) and filename.endswith(".png") and "/" not in filename,
                    "Unsafe supplemental capture filename")
            require(isinstance(capture.get("scope"), str) and capture["scope"], "Supplemental view needs an explicit comparison scope")
            validate_camera(capture.get("camera"))
            require(HASH.fullmatch(str(capture.get("geometry_group_sha256", ""))), "Supplemental view lacks geometry identity")
            raw, url = evidence(install["case"]["output_dir"] + "/" + filename)
            require(digest(raw) == capture.get("sha256"), "Supplemental capture hash differs from receipt")
            additional.append({"id":extra_id, "label":extra_id.replace("-", " ").capitalize(), "url":url,
                               "image_sha256":digest(raw), "pixels":png_extent(raw), "scope":capture["scope"],
                               "camera":capture["camera"], "geometry_group_sha256":capture["geometry_group_sha256"]})
        require(SUPPLEMENTAL.issubset(extra_ids), "Missing actual focus, Classic return, assistance or Lab capture")
        metadata, recipe_path = metadata_rows[identity]
        extent = result.get("extent")
        require(finite_vector(extent, 2) and all(type(x) is int and 512 <= x <= 2048 for x in extent), "Missing actual native extent")
        if "extent" in metadata: require(metadata["extent"] == extent, "Actual canvas differs from source recipe")
        scenes.append({"id":identity, "title":metadata["title"], "description":metadata["description"], "extent":extent,
                       "views":views, "additional_views":additional, "camera":camera, "actor_state":actor,
                       "native_hashes":before, "geometry_group_sha256":geometry_group,
                       "install_report":install["url"], "reopen_report":reopen["url"], "recipe_path":recipe_path,
                       "motion":next((item for item in motion_reports if item["scene"] == identity), None),
                       "rendering_adapter":str(result.get("rendering_adapter", "unreported")),
                       "performance":{"admission":{"install":admission_observation(result), "reopen":admission_observation(reopened)},
                                      "optical_cost_observations":result.get("performance", result.get("cost_samples")),
                                      "progression":{"status":"recorded" if any(item["scene"] == identity for item in progression_reports) else "not_recorded",
                                                     "reports":[item for item in progression_reports if item["scene"] == identity],
                                                     "scope":"Missing observations are unrecorded, not zero cost. Hosted software rendering and scene admission do not establish physical Windows/NVIDIA responsiveness."}}})
    return {"schema":"strata3-offline-optical-gallery-v1", "draft_hold":True,
            "source_commit":source["source_commit"], "source_tree":source["source_tree"], "platform":platform,
            "godot":engine, "runtime":{name:runtime[name] for name in ("cybersand_runtime", "rapier_runtime")},
            "runtime_source_commit":runtime.get("runtime_source_commit", ""),
            "campaign_report":(prefix + "/campaign.json" if prefix != "." else "campaign.json"),
            "campaign_report_sha256":digest(report_path.read_bytes()), "source_inputs_sha256":source_hashes,
            "capture_inputs_sha256":dict(sorted(used.items())), "inputs_receipt":output.with_suffix(".inputs.json").name,
            "scenes":scenes, "progression_reports":progression_reports,
            "scope":"Original ordinary Workbench graphical captures on " + platform + ". Profile stills share actual native geometry, camera and actor state. No human perception, motion quality or physical Windows/NVIDIA performance acceptance is implied."}


STYLE = r"""
:root{color-scheme:dark;--bg:#0a1017;--panel:#111d26;--line:#2a3e4d;--ink:#e6eef2;--muted:#a2b7c2;--cyan:#83e1dd;--amber:#f2bf7a}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,Segoe UI,sans-serif}a{color:var(--cyan)}button,select,input{font:inherit}button,select{color:inherit;background:#1b2d39;border:1px solid #3b5360;border-radius:6px;padding:8px 12px}button{cursor:pointer}button:focus-visible,select:focus-visible,input:focus-visible,a:focus-visible{outline:3px solid var(--amber);outline-offset:2px}.shell{max-width:1640px;margin:auto;padding:30px clamp(18px,4vw,60px) 70px}.eyebrow{color:var(--cyan);letter-spacing:.18em;text-transform:uppercase;font-size:12px;font-weight:700}h1{font-size:clamp(32px,4.4vw,64px);line-height:1.07;margin:18px 0}h2{font-size:24px;line-height:1.2}p{color:var(--muted)}.intro{max-width:950px}.pill{color:var(--amber);border:1px solid #816140;border-radius:999px;padding:5px 12px;font-size:12px;display:inline-block}.controls{display:flex;flex-wrap:wrap;gap:12px;align-items:end;padding:18px;background:var(--panel);border:1px solid var(--line);border-radius:12px 12px 0 0;margin-top:28px}.controls label{display:grid;gap:5px;color:var(--muted);font-size:12px}.controls select{max-width:min(400px,80vw)}.control-note{font-size:12px;color:var(--muted);flex:1}.scene-copy{padding:16px 20px;background:var(--panel);border:1px solid var(--line);border-top:0}.scene-copy h2{margin:0}.scene-copy p{font-size:13px;margin:6px 0}.viewport{position:relative;border:1px solid var(--line);border-top:0;overflow:auto;background:#03070a;max-height:80vh}.image-stack{position:relative;width:100%}.image-stack img{display:block;width:100%;height:auto;image-rendering:pixelated}.image-stack .processed{position:absolute;inset:0;clip-path:inset(0 0 0 50%)}.image-stack.single .processed{clip-path:none}.image-stack.actual{width:max-content}.image-stack.actual img{width:auto;max-width:none}.divider{position:absolute;top:0;bottom:0;left:50%;width:2px;background:var(--amber);pointer-events:none}.image-stack.single .divider{display:none}.comparison-bar{display:flex;gap:16px;align-items:center;flex-wrap:wrap;padding:12px 20px;background:var(--panel);border:1px solid var(--line);border-top:0}.comparison-bar input{flex:1;min-width:130px;accent-color:var(--cyan)}.comparison-bar span{font-size:12px;color:var(--muted)}.details{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-top:20px}.details>div{padding:18px;border:1px solid var(--line);border-radius:10px;background:var(--panel)}.details p{font-size:13px}.digest{font:11px/1.6 ui-monospace,Consolas,monospace;overflow-wrap:anywhere;color:var(--muted)}.scenes{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:14px}.scene-card{text-align:left;padding:0;overflow:hidden;border-radius:10px;background:var(--panel);border-color:var(--line)}.scene-card[aria-pressed=true]{border-color:var(--cyan)}.scene-card img{display:block;width:100%;aspect-ratio:8/5;object-fit:contain;image-rendering:pixelated;background:#03070a}.scene-card strong,.scene-card small{display:block;padding:0 14px}.scene-card strong{padding-top:12px}.scene-card small{padding-bottom:14px;color:var(--muted);font-size:12px}.note{padding:16px 20px;background:#231e16;border-left:3px solid var(--amber);margin:24px 0;font-size:13px;color:#decba9}.custody{margin-top:24px;border-top:1px solid var(--line);padding-top:18px}.custody summary{color:var(--cyan);cursor:pointer}.custody pre{font:11px/1.6 ui-monospace,Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;color:var(--muted);max-height:400px;overflow:auto}.supplement{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:18px 0}.supplement label{font-size:13px;color:var(--muted)}.supplement select{max-width:70vw}.muted{font-size:12px;color:var(--muted)}@media(max-width:720px){.details{grid-template-columns:1fr}.controls{align-items:stretch}.controls label{width:100%}.controls select{max-width:100%}.comparison-bar{gap:8px}.comparison-bar span{max-width:40%}}
"""

SCRIPT = r"""
const data=JSON.parse(document.getElementById('gallery-data').textContent),byId=id=>document.getElementById(id);
let sceneIndex=0,profileId='architectural',comparison=true,actual=false,motionTimer=null,motionFrame=0;
function stopMotion(){if(motionTimer!==null)clearInterval(motionTimer);motionTimer=null;byId('motion-play').textContent='Play inspection';byId('motion-play').setAttribute('aria-pressed','false');}
function resetMotion(){stopMotion();byId('motion').value='';for(const id of ['motion-frame','motion-prev','motion-next','motion-play'])byId(id).disabled=true;byId('motion-position').textContent='Choose a sequence';}
function updateWipe(){const amount=Number(byId('wipe').value);byId('processed').style.clipPath=comparison?'inset(0 0 0 '+amount+'%)':'none';byId('divider').style.left=amount+'%';}
function viewProfile(){resetMotion();const scene=data.scenes[sceneIndex],classic=scene.views.find(v=>v.id==='classic'),view=scene.views.find(v=>v.id===profileId);byId('reference').src=classic.url;byId('reference').alt=scene.title+' — Classic';byId('processed').src=view.url;byId('processed').alt=scene.title+' — '+view.label;byId('selected-label').textContent=view.label;byId('view-scope').textContent=view.scope;byId('original-link').href=view.url;byId('original-link').textContent='Open original '+view.label+' PNG · '+view.pixels.join(' × ');byId('image-digest').textContent='PNG SHA-256 '+view.image_sha256;byId('settings').textContent=JSON.stringify(view.configuration,null,2);byId('supplement').value='';byId('image-stack').classList.toggle('single',!comparison);byId('wipe').disabled=!comparison;updateWipe();}
function showMotion(){
const motion=data.scenes[sceneIndex].motion,sequence=motion&&motion.sequences.find(item=>item.id===byId('motion').value);if(!sequence){viewProfile();return}
motionFrame=Math.max(0,Math.min(sequence.frames.length-1,motionFrame));const frame=sequence.frames[motionFrame];byId('processed').src=frame.url;byId('processed').alt=sequence.label+' motion inspection frame '+(motionFrame+1);byId('image-stack').classList.add('single');byId('processed').style.clipPath='none';byId('wipe').disabled=true;byId('supplement').value='';byId('selected-label').textContent=sequence.label+' · motion inspection';byId('view-scope').textContent=sequence.scope+' '+sequence.comparison_limit;byId('original-link').href=frame.url;byId('original-link').textContent='Open original motion PNG · '+frame.pixels.join(' × ');byId('image-digest').textContent='PNG SHA-256 '+frame.image_sha256;byId('settings').textContent=JSON.stringify({configuration:sequence.configuration,configuration_sha256:sequence.configuration_sha256,quality:sequence.quality,frame:frame},null,2);byId('motion-frame').max=String(sequence.frames.length-1);byId('motion-frame').value=String(motionFrame);byId('motion-position').textContent='Frame '+(motionFrame+1)+' / '+sequence.frames.length;for(const id of ['motion-frame','motion-prev','motion-next','motion-play'])byId(id).disabled=false;
}
function admissionText(label,observation){return label+' '+(observation.elapsed_ms/1000).toFixed(3)+' s · '+(observation.target_met?'met':'exceeded')+' unchanged 45 s target';}
function selectScene(index){
sceneIndex=index;const scene=data.scenes[index];byId('scene').value=String(index);byId('scene-title').textContent=scene.title;byId('scene-description').textContent=scene.description;byId('extent').textContent=scene.extent.join(' × ')+' native cells · '+scene.rendering_adapter;byId('install').href=scene.install_report;byId('reopen').href=scene.reopen_report;byId('native').textContent=JSON.stringify({material_hashes:scene.native_hashes,camera:scene.camera,actor_state:scene.actor_state},null,2);byId('performance').textContent=JSON.stringify(scene.performance,null,2);
byId('admission').textContent=admissionText('Install',scene.performance.admission.install)+'; '+admissionText('fresh reopen',scene.performance.admission.reopen)+'.';
byId('progression-scope').textContent=scene.performance.progression.status==='recorded'?'Physical progression observations were recorded for this scene; inspect the original registration, repeat spread and software-renderer scope.':'Physical progression is unrecorded for this scene. Missing observations do not mean zero optical cost; observations from other scenes do not establish this scene’s responsiveness.';
const progressionLinks=byId('progression-links');progressionLinks.replaceChildren();for(const report of data.progression_reports){const line=document.createElement('p'),link=document.createElement('a');link.href=report.url;link.textContent='Original physical progression report · '+report.scene;line.append(link);progressionLinks.append(line)}
const motion=byId('motion');motion.replaceChildren(new Option('Choose an original movement sequence…',''));byId('motion-controls').hidden=!scene.motion;byId('motion-unavailable').hidden=Boolean(scene.motion);if(scene.motion){for(const sequence of scene.motion.sequences)motion.add(new Option(sequence.label,sequence.id));byId('motion-report').href=scene.motion.url}
const extras=byId('supplement');extras.replaceChildren(new Option('Focus, comparison and actual Lab captures…',''));for(const item of scene.additional_views)extras.add(new Option(item.label,item.id));document.querySelectorAll('[data-scene]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.scene)===index)));viewProfile();}
byId('scene').addEventListener('change',e=>selectScene(Number(e.target.value)));byId('profile').addEventListener('change',e=>{profileId=e.target.value;viewProfile()});byId('wipe').addEventListener('input',updateWipe);byId('comparison').addEventListener('click',()=>{comparison=!comparison;byId('comparison').textContent=comparison?'Classic / processed wipe':'Processed only';byId('comparison').setAttribute('aria-pressed',String(comparison));viewProfile()});byId('sizing').addEventListener('click',()=>{actual=!actual;byId('image-stack').classList.toggle('actual',actual);byId('sizing').textContent=actual?'Image 100% · click to fit':'Fit image · click for 100%';byId('sizing').setAttribute('aria-pressed',String(actual))});byId('supplement').addEventListener('change',e=>{resetMotion();const view=data.scenes[sceneIndex].additional_views.find(v=>v.id===e.target.value);if(!view){viewProfile();return}byId('processed').src=view.url;byId('processed').alt=view.label;byId('image-stack').classList.add('single');byId('processed').style.clipPath='none';byId('wipe').disabled=true;byId('selected-label').textContent=view.label;byId('view-scope').textContent=view.scope;byId('original-link').href=view.url;byId('original-link').textContent='Open original supplemental PNG · '+view.pixels.join(' × ');byId('image-digest').textContent='PNG SHA-256 '+view.image_sha256;byId('settings').textContent=JSON.stringify({scope:view.scope,camera:view.camera,geometry_group_sha256:view.geometry_group_sha256},null,2)});
byId('motion').addEventListener('change',()=>{stopMotion();motionFrame=0;showMotion()});byId('motion-frame').addEventListener('input',e=>{stopMotion();motionFrame=Number(e.target.value);showMotion()});byId('motion-prev').addEventListener('click',()=>{stopMotion();motionFrame--;showMotion()});byId('motion-next').addEventListener('click',()=>{stopMotion();motionFrame++;showMotion()});byId('motion-play').addEventListener('click',()=>{if(motionTimer!==null){stopMotion();return}byId('motion-play').textContent='Pause inspection';byId('motion-play').setAttribute('aria-pressed','true');motionTimer=setInterval(()=>{const sequence=data.scenes[sceneIndex].motion.sequences.find(item=>item.id===byId('motion').value);motionFrame=(motionFrame+1)%sequence.frames.length;showMotion()},1000/3)});
document.querySelectorAll('[data-scene]').forEach(b=>b.addEventListener('click',()=>{selectScene(Number(b.dataset.scene));byId('viewer').scrollIntoView({behavior:'smooth',block:'start'})}));selectScene(0);
"""


def render(data: dict) -> str:
    escape = html.escape
    encoded = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")).replace("<", "\\u003c").replace("&", "\\u0026")
    first = data["scenes"][0]
    scene_options = ''.join(f'<option value="{i}">{escape(scene["title"])}</option>' for i, scene in enumerate(data["scenes"]))
    profile_options = ''.join(f'<option value="{escape(identity)}"'+(' selected' if identity == 'architectural' else '')+f'>{escape(label)}</option>' for identity,label in PROFILES.items())
    cards = ''.join(f'<button class="scene-card" data-scene="{i}" aria-pressed="{str(i == 0).lower()}"><img loading="lazy" src="{escape(scene["views"][0]["url"])}" alt="{escape(scene["title"])} — original Classic capture"><strong>{escape(scene["title"])}</strong><small>{scene["extent"][0]} × {scene["extent"][1]} native cells</small></button>' for i,scene in enumerate(data['scenes']))
    proof = {key:data[key] for key in ("source_commit","source_tree","platform","godot","runtime","runtime_source_commit","campaign_report_sha256")}
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; base-uri 'none'">
<title>Strata Optics Lab · Matched native capture gallery</title><style>{STYLE}</style></head>
<body><div class="shell"><header><div class="eyebrow">CyberSand / Strata Theatre 003</div><h1>Architecture with<br>optical depth.</h1><p class="intro">Nine native environments. Eleven editable presentation profiles. Every image is an original ordinary Workbench capture; the profile comparisons share the same native geometry, camera and paused actor state.</p><span class="pill">DRAFT / HOLD · artistic and physical owner acceptance pending</span><p class="muted">Launch <strong>Open Workbench.cmd</strong> and open <strong>Strata Theatre → Optics</strong> to experiment inside the playable world. <a href="OWNER-EVALUATION.md">Owner walkthrough and feedback</a></p></header>
<main id="viewer"><div class="controls"><label>Native environment<select id="scene">{scene_options}</select></label><label>Editable optical profile<select id="profile">{profile_options}</select></label><button id="comparison" aria-pressed="true">Classic / processed wipe</button><button id="sizing" aria-pressed="false" title="100% means one image pixel per CSS pixel. Browser and OS scaling still apply.">Fit image · click for 100%</button></div>
<div class="scene-copy"><h2 id="scene-title">{escape(first['title'])}</h2><p id="scene-description"></p><div id="extent" class="muted"></div></div>
<div class="viewport"><div class="image-stack" id="image-stack"><img id="reference" src="{escape(first['views'][0]['url'])}" alt="Original Classic capture"><img class="processed" id="processed" src="{escape(first['views'][1]['url'])}" alt="Original processed capture"><div class="divider" id="divider"></div></div></div>
<div class="comparison-bar"><span>Classic · left</span><input type="range" id="wipe" min="0" max="100" value="50" aria-label="Classic versus processed image wipe"><span id="selected-label">Architectural · right</span></div>
<div class="supplement"><label for="supplement">Additional original captures</label><select id="supplement"></select></div>
<div id="motion-controls" hidden><div class="supplement"><label for="motion">Movement and camera inspection</label><select id="motion"></select><button id="motion-prev" disabled aria-label="Previous captured movement frame">Previous</button><button id="motion-play" disabled aria-pressed="false">Play inspection</button><button id="motion-next" disabled aria-label="Next captured movement frame">Next</button></div><div class="comparison-bar"><span id="motion-position">Choose a sequence</span><input id="motion-frame" type="range" min="0" max="9" value="0" disabled aria-label="Captured movement frame"><span>Review at 3 frames/s · arbitrary cadence</span></div><p class="muted">These original framebuffer readbacks interrupt execution. Playback is for visual inspection and does not reproduce actual movement speed or establish rendering FPS. <a id="motion-report" href="#">Original instrumented motion report</a></p></div><p id="motion-unavailable" class="muted">Select Physical Readability Challenge to inspect original movement and camera sequences.</p>
<div class="details"><div><strong>Comparison scope</strong><p id="view-scope"></p><p><a id="original-link" href="{escape(first['views'][0]['url'])}">Open original PNG</a></p><div id="image-digest" class="digest"></div></div><div><strong>Read physical geometry first</strong><p>Play alone owns collision and actor physics. Bright or sharp rear architecture can still be decoration. Compare Gameplay Clarity and the temporary clarity-assistance capture, then inspect or pilot the actual Workbench. Colour is only one depth cue.</p><p><a id="install" href="{escape(first['install_report'])}">Original install report</a> · <a id="reopen" href="{escape(first['reopen_report'])}">Fresh-process reopen report</a></p></div></div>
<h2>Five retained places and four new challenges</h2><div class="scenes">{cards}</div>
<div class="note"><strong>Still images do not prove playfeel.</strong> These hosted {escape(data['platform'])} captures establish what the application rendered under the recorded conditions. Human perception, moving-camera clarity, physical progression and Windows 11/NVIDIA acceptance remain separate. The predecessor's five scene-admission misses against the unchanged 45-second target remain recorded.</div>
<details class="custody"><summary>Selected optical settings and native comparison witnesses</summary><p class="muted">The captured preset values remain editable in the Lab. The original PNG is never altered by this gallery.</p><pre id="settings"></pre><pre id="native"></pre></details>
<details class="custody"><summary>Recorded performance observations and their scope</summary><p id="admission"></p><p class="muted" id="progression-scope"></p><div id="progression-links"></div><p class="muted">Original observations only. Callback intervals, upload timing and hosted software rendering are not physical GPU FPS or proof of responsive native progression. The linked reports retain the full completed-step sequences; this panel shows recorded summaries without declaring a performance winner.</p><pre id="performance"></pre></details>
<details class="custody"><summary>Executed source, runtime and complete input custody</summary><p><a href="{escape(data['campaign_report'])}">Original campaign</a> · <a href="{escape(data['inputs_receipt'])}">Gallery input manifest</a></p><pre>{escape(json.dumps(proof,indent=2))}</pre><p class="muted">All ledger-listed process receipts, logs and PNGs were byte-checked before this gallery was emitted. The package manifest separately covers these HTML and manifest bytes.</p></details>
<noscript><p class="note">Local JavaScript enables the comparison controls. The original scene thumbnails and source links remain available without it.</p></noscript></main></div>
<script id="gallery-data" type="application/json">{encoded}</script><script>{SCRIPT}</script></body></html>\n'''


def build(campaign: Path, output: Path) -> dict:
    data = prepare(campaign, output)
    document = render(data)
    receipt = json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    output.write_text(document, encoding="utf-8", newline="\n")
    output.with_suffix(".inputs.json").write_text(receipt, encoding="utf-8", newline="\n")
    return {"schema":"strata3-gallery-build-v1", "source_commit":data["source_commit"], "platform":data["platform"],
            "html_sha256":digest(document.encode()), "inputs_sha256":digest(receipt.encode()),
            "scenes":len(data["scenes"]), "matched_profile_captures":sum(len(s["views"]) for s in data["scenes"]),
            "additional_captures":sum(len(s["additional_views"]) for s in data["scenes"])}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(build(args.campaign, args.output), indent=2))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(2, "Strata optical gallery refused: " + str(error) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
