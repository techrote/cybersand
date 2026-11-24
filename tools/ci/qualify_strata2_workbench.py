#!/usr/bin/env python3
"""Source-bound ordinary Workbench Strata graphical and fresh-process campaign.

Retained native provenance is verified without rewriting its build identity.
Every invocation has a new output directory and original process/log/result
receipts. This is scoped Draft qualification, not a replacement for release CI.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import qualify_workbench_landscapes as custody
import strata_process_metrics as process_metrics

SCENES = ("orbital-terminal", "neon-rain-arcology", "industrial-underworks", "abyss-foundry", "vertical-transfer-spine")
REFERENCE_FIXTURES = {"orbital-terminal":"asteroid-service-gallery", "neon-rain-arcology":"rocket-hangar-frame"}
HARNESS = "res://tools/qualify_workbench_strata2.gd"
MAXIMUM_HARNESS = "res://tools/qualify_workbench_strata_maximum.gd"
EXTRA_INPUTS = (
    "tools/ci/qualify_strata2_workbench.py", "tools/ci/test_strata2_qualification.py",
    "tools/ci/test_strata2_campaign_custody.py", "tools/ci/strata_process_metrics.py",
    "tools/ci/test_strata_process_metrics.py",
    "tools/package_strata2_workbench.py", ".github/workflows/strata-theatre-002.yml",
    "tools/strata2_build_showcases.py",
    "tools/build_strata2_gallery.py", "tools/ci/test_strata2_gallery.py",
)
GODOT_SHA256 = {
    "linux": "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75",
    "win32": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
}
GODOT_GUI_SHA256 = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
BINARY_SOURCE_ROOT = "godot/data/strata2/"
BINARY_SOURCE_SUFFIXES = {".png"}
require, sha, write_json = custody.require, custody.sha, custody.write_json
PROSPECTIVE_TARGETS = {
    "scene_admission_callback_ms": 45000,
    "native_authoring_cells_per_chunk": 4096,
    "stop_no_further_native_write_callbacks": 2,
    "unchanged_decorative_native_captures": 0,
    "unchanged_decorative_texture_uploads": 0,
    "atmosphere_regions": 12, "atmosphere_motifs": 384,
    "route_completed_rapier_ticks": 60,
    "timing_scope": "Callback/admission targets retain misses; process/campaign limits are independent watchdogs. No hosted metric claims physical GPU FPS.",
}


def identity(allow_delta: bool = False) -> dict:
    result = custody.source_identity(allow_delta)
    for name in EXTRA_INPUTS:
        path = ROOT / name
        require(path.is_file() and not path.is_symlink(), "Missing qualification input: " + name)
        data = path.read_bytes().replace(b"\r\n", b"\n")
        digest = hashlib.sha256(data).hexdigest()
        result["source_inputs_sha256"][name] = digest
        try:
            committed = custody.git("show", "HEAD:" + name)
        except subprocess.CalledProcessError:
            committed = b""
        if data != committed and name not in result["local_delta"]:
            result["local_delta"].append(name)
    # PNG signatures contain CRLF. Binary source artwork and masks must never
    # pass through the inherited text-input newline normalization.
    committed_assets = custody.git("ls-tree", "-r", "--name-only", "HEAD", "--", BINARY_SOURCE_ROOT).decode().splitlines()
    asset_names = {name for name in committed_assets if Path(name).suffix.lower() in BINARY_SOURCE_SUFFIXES}
    asset_names.update(path.relative_to(ROOT).as_posix() for path in (ROOT / BINARY_SOURCE_ROOT).rglob("*")
                       if path.is_file() and path.suffix.lower() in BINARY_SOURCE_SUFFIXES)
    assets = {}
    for name in sorted(asset_names):
        path = ROOT / name
        require(path.is_file() and not path.is_symlink(), "Missing or linked binary source asset: " + name)
        data = path.read_bytes()
        assets[name] = hashlib.sha256(data).hexdigest()
        committed = custody.git("show", "HEAD:" + name) if name in committed_assets else None
        if data != committed and name not in result["local_delta"]:
            result["local_delta"].append(name)
    require(assets, "No committed Strata import artwork or masks were identified")
    result["source_assets_sha256"] = assets
    result["local_delta"].sort()
    require(allow_delta or not result["local_delta"], "Commit qualification source changes before frozen execution")
    return result


def project_assets_identity(project: Path, source: dict) -> dict:
    """Raw-byte custody for actual loaded PNG artwork/masks, including packages."""
    expected = source.get("source_assets_sha256")
    require(isinstance(expected, dict) and expected, "Missing binary source asset identity")
    loaded = {}
    for name, digest in expected.items():
        require(name.startswith(BINARY_SOURCE_ROOT) and Path(name).suffix.lower() in BINARY_SOURCE_SUFFIXES
                and ".." not in Path(name).parts and "\\" not in name
                and re.fullmatch(r"[0-9a-f]{64}", str(digest)), "Invalid binary source asset identity")
        relative = name.removeprefix("godot/")
        path = project / relative
        require(path.is_file() and not path.is_symlink(), "Missing binary project asset: " + relative)
        loaded[relative] = sha(path)
        require(loaded[relative] == digest, "Loaded binary asset differs from committed raw bytes: " + relative)
    actual = {path.relative_to(project).as_posix() for path in (project / BINARY_SOURCE_ROOT.removeprefix("godot/")).rglob("*")
              if path.is_file() and path.suffix.lower() in BINARY_SOURCE_SUFFIXES}
    require(actual == set(loaded), "Loaded project has missing or unrecorded binary import assets")
    return loaded



def instance_id(value) -> bool:
    # RefCounted IDs set the high bit and appear as signed int64 in GDScript.
    # Decimal strings preserve all64bits across JSON consumers.
    return (isinstance(value, str) and re.fullmatch(r"-?[1-9][0-9]{0,18}", value) is not None
            and -(1 << 63) <= int(value) < (1 << 63))

def validate_ready_review(review: dict, filename: str, token: str | None = None) -> None:
    require(review.get("filename") == filename and review.get("status") == "ready"
            and review.get("approval_enabled") is True and review.get("approval_visible") is True
            and review.get("proposal_visible") is True
            and type(review.get("scroll_vertical")) is int and review["scroll_vertical"] >= 0,
            "Actual scrolled ready proposal and enabled approval were not visible together")
    require(isinstance(review.get("reviewed_token"), str) and review["reviewed_token"]
            and review["reviewed_token"] == review.get("backend_token")
            and (token is None or review["reviewed_token"] == token),
            "Displayed approval is not bound to the exact reviewed native token")
    require(isinstance(review.get("displayed_status"), str)
            and review["displayed_status"].startswith("Review exact material-ID projection, then Approve.")
            and isinstance(review.get("backend_message"), str)
            and review["displayed_status"] == review["backend_message"].strip(),
            "Visible status did not describe the completed zero-write native preview")


def validate_visibility_probe(result: dict) -> None:
    visibility = result.get("play_visibility_pixels", {})
    probe = visibility.get("background_probe", {})
    require(visibility.get("background_remains_visible") is True
            and probe.get("native_inspection_required") is True
            and probe.get("requested_cell") == [596,246] == probe.get("sampled_native_cell")
            and probe.get("sampled_material") == 131 and probe.get("tolerance") == 0.08
            and probe.get("view_size") == [1024,576],
            "Exact background colour lacks the controlled native-texel identity witness")
    for key, length in (("pixels_per_cell",2), ("camera_origin",2), ("physical_pixel",2),
                        ("projected_native_centre",2), ("expected_rgba",4), ("observed_rgba",4)):
        values = probe.get(key)
        require(isinstance(values,list) and len(values) == length
                and all(type(value) in (int,float) and math.isfinite(value) for value in values),
                "Malformed actual pixel-oracle observation: " + key)
    require(all(value >= 1.0 for value in probe["pixels_per_cell"])
            and all(type(value) is int and value >= 0 for value in probe["physical_pixel"])
            and [math.floor(value) for value in probe["projected_native_centre"]] == probe["physical_pixel"],
            "The background colour oracle downsampled or sampled an unrecorded framebuffer pixel")
    require(all(0 <= value <= 1 for key in ("expected_rgba","observed_rgba") for value in probe[key]),
            "Pixel-oracle colours are not actual normalized RGBA values")
    error = max(abs(a-b) for a,b in zip(probe["expected_rgba"][:3],probe["observed_rgba"][:3]))
    require(type(probe.get("max_rgb_error")) in (int,float) and math.isfinite(probe["max_rgb_error"])
            and math.isclose(error,probe["max_rgb_error"],rel_tol=1e-6,abs_tol=1e-6)
            and error < 0.08, "Actual background colour disagrees with its unchanged exact-colour tolerance")


def validate_result(result: dict, scene: str, phase: str, source: str) -> None:
    """Read actual witnesses independently of the GDScript assertions."""
    require(result.get("schema") == "strata2-workbench-execution-v1", "Wrong Strata execution schema")
    require(result.get("completed") is True and result.get("failures") == []
            and isinstance(result.get("checks"), int) and result["checks"] > 0,
            "Incomplete or failing Strata execution")
    require(result.get("scene") == scene and result.get("phase") == phase
            and result.get("source_revision") == source, "Strata execution identity mismatch")
    require(result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility", "Actual graphical rendering was not established")
    require(result.get("ordinary_workbench") is True, "Standalone depth is not ordinary Workbench qualification")
    require(result.get("diagnostic_headless") is False and result.get("document_version") == 2,
            "A headless diagnostic or legacy-only layout cannot qualify the successor")
    require(re.fullmatch(r"[0-9a-f]{64}", str(result.get("authored_settings_sha256", ""))),
            "Missing exact authored settings identity")
    require(result.get("admission_target_ms") == 45000 and type(result.get("admission_elapsed_ms")) is int
            and result["admission_elapsed_ms"] >= 0
            and result.get("admission_target_met") == (result["admission_elapsed_ms"] <= 45000),
            "Admission timing must preserve the predeclared45second target and honest overruns")
    require(set(result.get("plane_native_hashes", {})) == {"play", "scripted", "effects", "background"},
            "Missing a native material plane readback")
    for digest in result["plane_native_hashes"].values():
        require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest), "Invalid native plane digest")
    require(result.get("world_count") == {"play_borrowed": 1, "decorative_owned": 3},
            "Wrong native ownership cardinality")
    require(re.fullmatch(r"[0-9a-f]{64}", str(result.get("save", {}).get("sha256", "")))
            and isinstance(result["save"].get("path"), str) and result["save"]["path"], "No authored composition save identity")
    saved = result.get("saved_authoring", {})
    marker = saved.get("native_marker", {})
    require(marker.get("plane") == "background" and marker.get("point") == [96,96]
            and type(marker.get("material")) is int and marker["material"] in (58,131),
            "Fresh-save witness lacks its actual durable native edit")
    require(all(re.fullmatch(r"[0-9a-f]{64}", str(saved.get(key,""))) for key in ("authoring_sha256","atmosphere_sha256"))
            and type(saved.get("authoring_records")) is int and saved["authoring_records"] >= 0,
            "Fresh-save witness lacks exact authored metadata/effect identities")
    saved_atmosphere = saved.get("atmosphere", {})
    require(saved_atmosphere.get("paused") is True and isinstance(saved_atmosphere.get("effects"),list)
            and saved_atmosphere["effects"], "Fresh-save witness lost explicit authored atmosphere settings")
    historical = saved.get("raster_imports", [])
    require(isinstance(historical,list) and len(historical) <= saved["authoring_records"], "Invalid saved import history count")
    if scene in REFERENCE_FIXTURES:
        reference_provenance = json.loads((ROOT / "godot/data/strata2/reference-imports" / (REFERENCE_FIXTURES[scene]+".provenance.json")).read_text())
        require(any(row.get("source_sha256") == reference_provenance["crop_file_sha256"]
                    and row.get("plane") == "scripted" and row.get("status") == "completed"
                    and row.get("historical") is True
                    and all(re.fullmatch(r"[0-9a-f]{64}",str(row.get(key,""))) for key in ("geometry_sha256","actual_sha256"))
                    for row in historical), "Fresh-save witness lost the admitted reference source/native history")
    if phase == "install":
        mutation = result.get("authored_mutations", {})
        require(mutation.get("plane") == marker["plane"] and mutation.get("point") == marker["point"]
                and type(mutation.get("before")) is int and mutation["before"] != mutation.get("after") == marker["material"]
                and type(mutation.get("effect_strength_before")) in (int,float)
                and type(mutation.get("effect_strength_after")) in (int,float)
                and mutation["effect_strength_before"] != mutation["effect_strength_after"]
                and any(effect.get("id") == mutation.get("effect_id")
                        and effect.get("strength") == mutation["effect_strength_after"] for effect in saved_atmosphere["effects"]),
                "Only a baseline preset was saved; durable native/effect edits were not demonstrated")
        native_details = result.get("native_grid_details", [])
        require(len(native_details) == 2 and {row.get("plane") for row in native_details} == {"play","scripted"}
                and all(type(row.get(key)) in (int,float) and math.isfinite(row[key]) and abs(row[key]-1.0) < 0.01
                        for row in native_details for key in ("pixels_per_cell_x","pixels_per_cell_y")),
                "Native-resolution detail captures lack actual one-cell/one-framebuffer-pixel transforms")
        if scene in REFERENCE_FIXTURES:
            imported = result.get("reference_import", {})
            reference = REFERENCE_FIXTURES[scene]
            provenance = json.loads((ROOT / "godot/data/strata2/reference-imports" / (reference + ".provenance.json")).read_text())
            require(imported.get("id") == reference and imported.get("plane") == "scripted"
                    and imported.get("source_sha256") == provenance["crop_file_sha256"]
                    and imported.get("mask_sha256") == provenance["mask_sha256"]
                    and imported.get("geometry_sha256") == provenance["proposed_uint16le_sha256"]
                    and imported.get("write_mask_sha256") == provenance["proposed_write_mask_sha256"],
                    "Actual reference import lacks source/mask/mapping fidelity")
            require(imported.get("mapped") == provenance["proposal_counts"]["mapped"]
                    and imported.get("no_write") == provenance["proposal_counts"]["source_pixels"]-imported["mapped"]
                    and imported.get("completed_status") == "completed"
                    and isinstance(imported.get("approved_token"),str) and imported["approved_token"]
                    and type(imported.get("history_chunks")) is int and 0 < imported["history_chunks"] <= 8,
                    "Actual reference import lacks explicit approval, bounded native completion and no-write accounting")
            require(all(re.fullmatch(r"[0-9a-f]{64}",str(imported.get(key,""))) for key in
                        ("before_sha256","expected_sha256","actual_sha256","restored_sha256","play_before_sha256","play_after_sha256"))
                    and imported["actual_sha256"] == imported["expected_sha256"] != imported["before_sha256"]
                    and imported["restored_sha256"] == imported["before_sha256"]
                    and imported["play_before_sha256"] == imported["play_after_sha256"]
                    and imported.get("visual_difference",{}).get("changed_samples",0) >= 8,
                    "Actual reference import/Undo lacks independent native or framebuffer evidence")
            review = imported.get("ready_review", {})
            validate_ready_review(review, "reference-import-"+reference+"-approval.png", imported["approved_token"])
            require(isinstance(review.get("changed_counts"),str) and review["changed_counts"],
                    "Visible import approval omitted changed/no-write proposal accounting")
            fixture = json.loads((ROOT / "godot/data/strata2/reference-imports" / (reference + ".fixture.json")).read_text())
            expected_region = fixture["options"]["origin"] + fixture["options"]["crop"][2:]
            prefix = "Target: scripted · region "
            require(review.get("expected_region") == expected_region
                    and isinstance(review.get("region_label"),str) and review["region_label"].startswith(prefix),
                    "Import review omitted its explicit target origin and extent")
            try:
                displayed_region = json.loads(review["region_label"][len(prefix):])
            except (ValueError,TypeError) as exc:
                raise RuntimeError("Import review target region is not a complete native coordinate array") from exc
            require(displayed_region == expected_region and all(type(value) is int for value in displayed_region),
                    "Displayed import region differs from the independently pinned fixture placement")
        if scene == "orbital-terminal":
            validate_visibility_probe(result)
            review = result.get("composition_review", {})
            validate_ready_review(review, "composition-ready-approval.png")
            require(type(review.get("stage_count")) is int and review["stage_count"] >= 2
                    and review.get("approved") is False and review.get("cancelled_without_approval") is True,
                    "A real multi-plane composition was not reviewed and cancelled without approval")
            stop = review.get("stop", {})
            require(stop.get("status") == "cancelled" and stop.get("token") == ""
                    and stop.get("can_approve") is False and stop.get("applied_cells") == 0
                    and stop.get("approval_disabled") is True,
                    "Actual Compose Stop did not retire its ready token before any native write")
            before_hashes, after_hashes = (review.get(key,{}) for key in ("native_hashes_before","native_hashes_after"))
            require(set(before_hashes) == {"play","scripted","effects","background"} and before_hashes == after_hashes
                    and all(re.fullmatch(r"[0-9a-f]{64}",str(value)) for value in before_hashes.values()),
                    "Unapproved composition review changed or omitted actual native material planes")
        transitions = result.get("transitions", [])
        require(len(transitions) >= 12, "Insufficient mode/lifecycle transitions")
        for entry in transitions:
            before, after = entry.get("before", {}), entry.get("after", {})
            for key in ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids"):
                require(key in before and before[key] == after.get(key), "Presentation replaced play authority: " + key)
                if key in ("world_generation", "physical_epoch"):
                    require(type(before[key]) is int and before[key] > 0, "Invalid actual play identity: " + key)
                elif key != "actor_body_ids":
                    require(instance_id(before[key]), "Invalid exact actual instance identity: " + key)
            require(isinstance(before.get("actor_body_ids"), list) and before["actor_body_ids"]
                    and all(instance_id(value) for value in before["actor_body_ids"]), "Identity witness has no exact actual actor body")
        require(type(result.get("edit_readback", {}).get("material")) is int
                and 0 < result["edit_readback"]["material"] <= 255
                and re.fullmatch(r"[0-9a-f]{64}", str(result["edit_readback"].get("play_hash_before", "")))
                and result["edit_readback"].get("target_after") == result["edit_readback"].get("material")
                and result["edit_readback"].get("play_hash_before") == result["edit_readback"].get("play_hash_after"),
                "Decorative edit lacks actual target/read-only play witnesses")
        guards = result.get("refusals", {})
        for key in ("locked", "hidden", "outside", "invalid_document", "stale_generation"):
            require(guards.get(key) is True, "Missing reason-specific refusal: " + key)
        require(result.get("undo_redo", {}).get("undo_native") is True
                and result["undo_redo"].get("redo_native") is True, "Per-plane history lacks native readback")
        transforms = result.get("transforms", {})
        require(transforms.get("samples", 0) >= 24 and 0 <= transforms.get("max_error", -1) < 0.01,
                "Coordinate coverage/roundtrip failed")
        require(len(result.get("cost_samples", [])) >= 3, "Missing matched disabled/flat/stack observation")
        costs = result["cost_samples"]
        require(len(costs) == 4 and {(r.get("mode"), r.get("atmosphere_enabled")) for r in costs} ==
                {("disabled", False), ("flat", False), ("stack", False), ("stack", True)},
                "Missing matched static and presentation-animation controls")
        for sample in costs:
            require(sample.get("native_snapshots_during_sample") == 0
                    and sample.get("decorative_uploads_during_sample") == 0,
                    "Unchanged static/animated decoration performed recurring native captures or uploads")
        atmosphere = result.get("atmosphere", {})
        material_time = atmosphere.get("play_material_time", {})
        require(type(material_time.get("fixed")) in (int, float) and math.isfinite(material_time["fixed"])
                and material_time["fixed"] >= 0 and instance_id(material_time.get("shader_instance"))
                and instance_id(material_time.get("emission_shader_instance"))
                and material_time.get("restored") is True and material_time.get("emission_restored") is True,
                "Atmosphere framebuffer comparison did not isolate and restore borrowed Play material animation")
        require(atmosphere.get("visual_difference", {}).get("changed_samples", 0) >= 8
                and atmosphere.get("solo_leakage", {}).get("changed_samples") == 0,
                "Atmosphere lacks actual framebuffer effect or leaks through excluded planes")
        require(atmosphere.get("native_hashes_before") == atmosphere.get("native_hashes_after")
                and set(atmosphere.get("native_hashes_before", {})) == {"play", "scripted", "effects", "background"}
                and atmosphere.get("native_capture_delta") == 0,
                "Atmosphere altered native geometry or performed recurring capture")
        for first, second in (("paused_before", "paused_after"), ("hidden_before", "hidden_after")):
            require(set(atmosphere.get(first, {})) == {"scripted", "effects", "background"}
                    and set(atmosphere.get(second, {})) == {"scripted", "effects", "background"},
                    "Missing atmosphere plane clock witnesses")
            require(all(atmosphere[first][name]["phase_seconds"] == atmosphere[second][name]["phase_seconds"]
                        for name in atmosphere[first]), "Paused or hidden plane clock advanced")
        require(set(atmosphere.get("moving_before", {})) == {"scripted", "effects", "background"}
                and set(atmosphere.get("moving_after", {})) == {"scripted", "effects", "background"}
                and any(atmosphere["moving_after"][name]["phase_seconds"] > atmosphere["moving_before"][name]["phase_seconds"]
                        for name in atmosphere["moving_before"]), "Visible atmosphere never advanced")
        route = result.get("route_probe", {})
        require(type(route.get("completed_rapier_ticks")) is int and route["completed_rapier_ticks"] >= 60
                and type(route.get("completed_native_ticks")) is int and route["completed_native_ticks"] > 0
                and type(route.get("forward_cells")) in (int, float) and math.isfinite(route["forward_cells"])
                and route["forward_cells"] > 1 and isinstance(route.get("samples"), list) and route["samples"],
                "Actual actor route segment/native progression lacks measured execution")
        require(route["completed_rapier_ticks"] == route.get("after", {}).get("rapier_tick", -1) - route.get("before", {}).get("rapier_tick", 0)
                and route["completed_native_ticks"] == route.get("after", {}).get("native_tick", -1) - route.get("before", {}).get("native_tick", 0),
                "Claimed completed ticks disagree with actual before/after counters")
        live_edit = route.get("live_decorative_edit", {})
        require(live_edit.get("plane") == "background" and live_edit.get("committed") is True
                and type(live_edit.get("marker")) is int and 0 < live_edit["marker"] <= 255
                and live_edit.get("native_written") == live_edit["marker"] != live_edit.get("native_before")
                and live_edit.get("native_restored") == live_edit.get("native_before")
                and live_edit.get("receipt",{}).get("ok") is True
                and live_edit.get("receipt",{}).get("published") is True
                and route["after"]["native_tick"] > live_edit.get("after",{}).get("native_tick",2**63)
                and route["after"]["rapier_tick"] > live_edit.get("after",{}).get("rapier_tick",2**63),
                "No acknowledged decorative native edit/Undo with continued actual Play progression")
        for key in ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids"):
            require(route.get("before", {}).get(key) is not None
                    and route["before"][key] == route.get("after", {}).get(key),
                    "Live route toggles changed Play/actor ownership")
            require(live_edit.get("before",{}).get(key) == route["before"][key] == live_edit.get("after",{}).get(key),
                    "Live decorative edit changed Play/actor identity")
    else:
        require(result.get("fresh_process_reopen") is True, "Reopen did not use the authored composition loader")


def validate_maximum(result: dict, source: str) -> None:
    require(result.get("schema") == "strata-maximum-execution-v1" and result.get("completed") is True
            and result.get("failures") == [] and result.get("checks", 0) > 0 and result.get("source_revision") == source,
            "Maximum extent execution is incomplete, failed or unbound")
    require(type(result.get("process_id")) is int and result["process_id"] > 0, "Maximum lacks actual engine PID")
    require(result.get("ordinary_workbench") is True and result.get("extent") == [2048,2048]
            and result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility", "Maximum extent was not actually rendered in ordinary Workbench")
    require(result.get("world_count") == {"play_borrowed":1, "decorative_owned":3}, "Maximum extent has wrong native ownership")
    before, after = (result.get("identity", {}).get(key, {}) for key in ("before", "after"))
    for key in ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids"):
        require(key in before and before[key] == after.get(key), "Maximum extent changed live play identity")
    require(all(type(before[k]) is int and before[k] > 0 for k in ("world_generation", "physical_epoch"))
            and all(instance_id(before[k]) for k in ("worker_id", "actor_session_id"))
            and isinstance(before["actor_body_ids"], list) and before["actor_body_ids"]
            and all(instance_id(x) for x in before["actor_body_ids"]),
            "Maximum extent lacks exact actual World and actor instance IDs")
    require(re.fullmatch(r"[0-9a-f]{64}", str(result.get("play_hash_before", "")))
            and result.get("play_hash_after") == result["play_hash_before"], "Maximum extent edits changed Play materials")
    planes = result.get("planes", {})
    require(set(planes) == {"scripted", "effects", "background"}, "Maximum extent omits a native plane")
    for plane in planes.values():
        require(plane.get("extent") == [2048,2048] and plane.get("native_material") == 131
                and type(plane.get("pixel_delta")) in (int, float) and math.isfinite(plane["pixel_delta"])
                and plane["pixel_delta"] > 0.025 and instance_id(plane.get("owner")),
                "Maximum plane dimensions, native material or actual pixel witness is absent")
    require(result.get("teardown", {}).get("native_world_count") == 0
            and result.get("teardown", {}).get("pending_native_world_count") == 0, "Maximum owners did not retire")


def verify_resource_receipt(folder: Path, case: dict, engine_pid: int | None = None) -> None:
    path = folder / case["label"] / "resources.json"
    require(sha(path) == case.get("resources_sha256"), "Original resource samples changed")
    raw = json.loads(path.read_text(encoding="utf-8"))
    require(raw.get("schema") == "strata-process-resources-v1" and raw.get("root_pid") == case["pid"]
            and {k:v for k,v in raw.items() if k != "samples"} == case.get("resources"), "Resource receipt differs from original samples")
    latest, sampled_pids = {}, set()
    peak_rss = 0
    samples = raw.get("samples", [])
    require(isinstance(samples, list) and len(samples) == raw.get("sample_count"), "Resource sample count differs from original rows")
    for sample in samples:
        rss = 0
        for row in sample.get("processes", []):
            require(type(row.get("pid")) is int and row["pid"] > 0 and type(row.get("start_id")) is int
                    and row["start_id"] > 0 and type(row.get("rss_bytes")) is int and row["rss_bytes"] >= 0
                    and type(row.get("cpu_seconds")) in (int, float) and math.isfinite(row["cpu_seconds"])
                    and row["cpu_seconds"] >= 0, "Malformed observed process counter")
            key = (row["pid"], row["start_id"])
            require(row["cpu_seconds"] >= latest.get(key, 0), "Observed process CPU counter regressed")
            latest[key] = row["cpu_seconds"]
            sampled_pids.add(row["pid"])
            rss += row["rss_bytes"]
        require(sample.get("tree_rss_bytes") == rss and math.isclose(sample.get("tree_cpu_seconds_observed", -1),
                sum(latest.values()), rel_tol=1e-9, abs_tol=1e-9), "Resource sample aggregate differs from actual process rows")
        peak_rss = max(peak_rss, rss)
    require(raw.get("process_identities") == [list(key) for key in sorted(latest)]
            and raw.get("peak_observed_tree_rss_bytes") == peak_rss
            and type(raw.get("observed_cpu_seconds")) in (int, float) and math.isfinite(raw["observed_cpu_seconds"])
            and math.isclose(raw["observed_cpu_seconds"], sum(latest.values()), rel_tol=1e-9, abs_tol=1e-9),
            "Resource summary differs from actual sampled counters")
    if engine_pid is not None:
        require(raw.get("available") is True and len(samples) >= 2 and engine_pid in sampled_pids and peak_rss > 0,
                "CPU/memory observation did not include the actual Godot engine")


REGRESSIONS = {
    "test_depth_compositor": "Depth compositor regression passed",
    "test_workbench_strata_layers": "STRATA_LAYER_REGRESSION ",
    "test_workbench_strata_document": "STRATA_DOCUMENT ",
    "test_depth_dimensions_render": "Depth dimension pixels:",
    "test_workbench_edit_ordering": "EDIT_ORDER_RESULT ",
    "test_workbench_deferred_paint": "WB_DEFERRED_PAINT ",
    "test_strata_import_codec": "STRATA_IMPORT ",
    "test_strata_reference_imports": "STRATA_REFERENCE_IMPORTS ",
    "test_strata_construction_session": "STRATA_SESSION ",
    "test_strata_authoring_library": "STRATA_AUTHORING_LIBRARY ",
    "test_strata_atmosphere": "STRATA_ATMOSPHERE ",
    "test_strata_showcases": "STRATA_SHOWCASES ",
    "test_strata2_authoring_ui": "STRATA2_UI_RESULT ",
    "test_strata2_mounted_failures": "STRATA2_MOUNTED_FAILURES ",
    "test_strata2_workflow": "STRATA2_WORKFLOW ",
    "test_strata2_actor_route": "STRATA2_ACTOR_ROUTE ",
}

NATIVE_REPORTS = {"test_strata2_mounted_failures", "test_strata2_workflow"}


def validate_native_report(result: dict, label: str, source: str) -> None:
    require(result.get("completed") is True and result.get("failures") == []
            and type(result.get("checks")) is int and result["checks"] >= 40
            and result.get("source_revision") == source, "Incomplete/unbound native successor witness")
    if label == "test_strata2_mounted_failures":
        require(result.get("schema") == "strata2-mounted-failures-v1", "Wrong mounted-failure schema")
        prefix = result.get("partial", {})
        require(prefix.get("receipt", {}).get("status") == "partial" and prefix["receipt"].get("applied") == 1
                and prefix.get("native_before") == [0, 0] and prefix.get("native_after") == [131, 0]
                and prefix.get("quarantined") is True and prefix.get("authored_retained") is True,
                "Partial mutation lacks actual prefix/quarantine/baseline evidence")
        committed = result.get("committed_stale_view", {})
        require(committed.get("returned_committed") is True and committed.get("native_after") == 131
                and committed.get("receipt", {}).get("ok") is True and committed["receipt"].get("published") is False
                and committed.get("revision_after") == committed.get("revision_before", -2) + 1
                and committed.get("copied_pixels_retained") is True,
                "Committed native edit was lost or mislabeled after failed publication")
        ack = result.get("failed_play_ack", {})
        require(ack.get("serial", 0) > 0 and instance_id(ack.get("instance_id"))
                and ack.get("pending_native_worlds") == 0 and ack.get("previous_document_retained") is True,
                "Failed Play ACK lacks actual prepared identity or retired candidates")
        before, after = ack.get("before", {}), ack.get("after", {})
        require(re.fullmatch(r"[0-9a-f]{64}", str(result.get("play_hash_before", "")))
                and result.get("play_hash_before") == result.get("play_hash_after"), "Fault changed actual Play materials")
    else:
        require(result.get("schema") == "strata2-workflow-v1", "Wrong native workflow schema")
        require(re.fullmatch(r"[0-9a-f]{64}", str(result.get("input_sha256", "")))
                and all(re.fullmatch(r"[0-9a-f]{64}", str(result.get(key, "")))
                        for key in ("play_hash_original", "play_hash_imported", "play_hash_restored"))
                and result.get("play_hash_original") != result.get("play_hash_imported")
                and result.get("play_hash_original") == result.get("play_hash_restored"),
                "Play import/Undo lacks source and actual before/after readback")
        require(result.get("provenance", {}).get("records"), "Native imports omitted authored provenance")
        before, after = result.get("play_identity_before", {}), result.get("play_identity_after", {})
    for key in ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids"):
        require(key in before and before[key] == after.get(key), "Native exercise changed Play identity: " + key)
        if key in ("world_generation", "physical_epoch"):
            require(type(before[key]) is int and before[key] > 0, "Native exercise lacks actual Play generation/epoch")
        elif key != "actor_body_ids":
            require(instance_id(before[key]), "Native exercise lacks exact actual owner instance identity")
    require(isinstance(before.get("actor_body_ids"), list) and before["actor_body_ids"]
            and all(instance_id(value) for value in before["actor_body_ids"]),
            "Native exercise lacks actual actor body identities")


def retained_runtime_manifest(platform: str) -> dict:
    """Read the exact committed retained identity on either packaging platform."""
    require(platform in GODOT_SHA256, "Unknown execution platform")
    name = "godot/addons/cybersand_native/runtime-provenance" + (".linux" if platform == "linux" else "") + ".json"
    raw = custody.git("show", "HEAD:" + name)
    manifest = json.loads(raw)
    native = {"path": manifest["artifact"], "sha256": manifest["sha256"], "size": manifest["size"]}
    rapier_path = ("godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
                   if platform == "linux" else custody.windows.RAPIER)
    pointer = custody.git("show", "HEAD:" + rapier_path).decode()
    match = re.fullmatch(r"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize (\d+)\n", pointer)
    require(match is not None, "Retained Rapier is not an exact committed LFS identity")
    native_pointer = custody.git("show", "HEAD:" + native["path"]).decode()
    require(native_pointer == "version https://git-lfs.github.com/spec/v1\noid sha256:" + native["sha256"] +
            "\nsize " + str(native["size"]) + "\n", "Native provenance differs from committed runtime pointer")
    return {"runtime_source_commit": manifest["source_commit"], "runtime_build_commit": manifest["build_commit"],
            "runtime_provenance": {"path": name, "sha256": hashlib.sha256(raw).hexdigest()},
            "native_source_inputs": manifest["source_inputs"], "cybersand_runtime": native,
            "rapier_runtime": {"path": rapier_path, "sha256": match[1], "size": int(match[2])}}


def verify_campaign(folder: Path, expected: dict | None = None, *, full: bool = True) -> dict:
    report = json.loads((folder / "qualification.json").read_text(encoding="utf-8"))
    require(report.get("schema") == "strata2-workbench-qualification-v1" and report.get("status") == "passed"
            and report.get("completed") is True and report.get("input_custody") == "passed"
            and report.get("local_delta") == [], "Campaign is incomplete, failed, or contains local changes")
    require(report.get("prospective_targets") == PROSPECTIVE_TARGETS, "Qualification changed its predeclared targets")
    if expected is None:
        expected = identity()
    for key in ("source_commit", "source_tree", "source_inputs_sha256", "source_assets_sha256"):
        require(report.get(key) == expected[key], "Campaign differs from current source: " + key)
    platform = report.get("platform")
    require(platform in GODOT_SHA256, "Unknown campaign platform")
    engine = report.get("godot", {})
    require(engine.get("version") == custody.windows.GODOT_VERSION
            and engine.get("sha256") == GODOT_SHA256[platform] and isinstance(engine.get("path"), str)
            and engine["path"], "Missing exact official Godot receipt")
    runtime = retained_runtime_manifest(platform)
    require(report.get("runtime") == runtime, "Runtime receipt differs from retained source-bound identity")
    for name, digest in runtime["native_source_inputs"].items():
        require(expected["source_inputs_sha256"].get(name) == digest, "Runtime no longer matches native source input: " + name)
    project = report.get("project", {})
    project_inputs = {k.removeprefix("godot/"):v for k,v in expected["source_inputs_sha256"].items() if k.startswith("godot/")}
    for kind in ("cybersand_runtime", "rapier_runtime"):
        item = runtime[kind]; project_inputs[item["path"].removeprefix("godot/")] = item["sha256"]
    require(isinstance(project.get("path"), str) and project["path"]
            and project.get("inputs_sha256") == project_inputs and project_inputs,
            "Loaded project lacks complete source/runtime custody")
    expected_assets = {name.removeprefix("godot/"): digest for name, digest in expected["source_assets_sha256"].items()}
    require(expected_assets and project.get("assets_sha256") == expected_assets,
            "Loaded project lacks exact raw-byte source artwork/mask custody")
    scenes = report.get("scenes", [])
    requested = list(SCENES) if full else report.get("selected_scenes", [])
    require(requested and set(requested) <= set(SCENES) and len(requested) == len(set(requested))
            and set(report.get("selected_scenes", [])) == set(requested)
            and {r["name"] for r in scenes} == set(requested)
            and len(scenes) == len(requested), "Wrong/duplicate scene coverage")
    expected_labels = {"import", "maximum", *REGRESSIONS, *(scene + "/" + phase for scene in requested for phase in ("install", "reopen"))}
    cases = report.get("cases", [])
    require(len(cases) == len(expected_labels) and {r.get("label") for r in cases} == expected_labels,
            "Missing or duplicate import/regression/execution cases")
    cases_by_label = {r["label"]:r for r in cases}
    base = [engine["path"], "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3", "--path", project["path"]]
    for label, embedded in cases_by_label.items():
        path = folder / label / "process.json"
        raw = json.loads(path.read_text(encoding="utf-8"))
        require(raw == {k:v for k,v in embedded.items() if k != "label"}, "Embedded process differs from original process: " + label)
        require(raw.get("status") == "passed" and raw.get("exit_code") == 0 and type(raw.get("pid")) is int
                and raw["pid"] > 0 and type(raw.get("timeout_seconds")) in (int, float)
                and math.isfinite(raw["timeout_seconds"]) and 0 < raw["timeout_seconds"] <= 600
                and type(raw.get("seconds")) in (int, float) and math.isfinite(raw["seconds"])
                and 0 < raw["seconds"] <= raw["timeout_seconds"] + 5,
                "Original bounded Godot process did not succeed: " + label)
        flags = (["--headless", "--editor", "--quit"] if label == "import" else
                 ["--script", "res://tests/" + label + ".gd"] if label in REGRESSIONS else
                 ["--script", MAXIMUM_HARNESS if label == "maximum" else HARNESS])
        require(raw.get("command") == base + flags, "Wrong actual Godot command: " + label)
        log = path.with_name("process.log")
        text = log.read_text(encoding="utf-8")
        require(sha(log) == raw["log_sha256"] and not custody.ERRORS.search(text)
                and "Godot Engine v" + custody.windows.GODOT_VERSION in text,
                "Original Godot log changed, lacks engine identity, or contains an error: " + label)
        marker = REGRESSIONS.get(label, "STRATA_MAXIMUM " if label == "maximum" else "STRATA2_WORKBENCH " if label != "import" else "Godot Engine v")
        require(marker in text, "Required actual execution marker absent: " + label)
        verify_resource_receipt(folder, embedded)
        if label in NATIVE_REPORTS:
            result_path = folder / label / "result.json"
            result = json.loads(result_path.read_text(encoding="utf-8"))
            validate_native_report(result, label, report["source_commit"])
            require(result.get("display_server") in (("Windows",) if platform == "win32" else ("X11", "Wayland")),
                    "Mounted native exercise did not run on the claimed graphical platform")
            verify_resource_receipt(folder, embedded, result.get("process_id"))
    maximum = report.get("maximum", {})
    maximum_path = folder / "maximum" / "maximum.json"
    require(sha(maximum_path) == maximum.get("report_sha256"), "Maximum original result changed")
    maximum_result = json.loads(maximum_path.read_text(encoding="utf-8"))
    require(maximum_result == maximum.get("result") and maximum.get("process") == cases_by_label["maximum"],
            "Maximum embedded receipt differs from its original process/result")
    validate_maximum(maximum_result, report["source_commit"])
    require(maximum_result["display_server"] in (("Windows",) if platform == "win32" else ("X11", "Wayland")),
            "Maximum display differs from its platform")
    if platform == "linux":
        require(maximum_result["process_id"] == cases_by_label["maximum"]["pid"], "Maximum Linux engine PID differs from process owner")
    verify_resource_receipt(folder, cases_by_label["maximum"], maximum_result.get("process_id"))
    for entry in scenes:
        require(entry.get("status") == "passed" and set(entry["phases"]) == {"install", "reopen"}, "Incomplete scene phases")
        for phase, receipt in entry["phases"].items():
            path = folder / entry["name"] / (phase + ".json")
            require(sha(path) == receipt["report_sha256"], "Original scene result changed")
            result = json.loads(path.read_text(encoding="utf-8"))
            require(result == receipt["result"], "Embedded receipt differs from original execution")
            validate_result(result, entry["name"], phase, report["source_commit"])
            require(result["display_server"] in (("Windows",) if platform == "win32" else ("X11", "Wayland")),
                    "Graphical display differs from claimed platform")
            process = cases_by_label[entry["name"] + "/" + phase]
            require(receipt["process"] == process, "Scene process differs from campaign case")
            verify_resource_receipt(folder, process, result.get("process_id"))
            require(type(result.get("process_id")) is int and result["process_id"] > 0,
                    "Missing actual Godot process identity")
            if platform == "linux":
                require(result["process_id"] == process["pid"], "Linux Godot PID differs from process owner")
        before, after = (entry["phases"][p] for p in ("install", "reopen"))
        require(before["process"]["pid"] != after["process"]["pid"] and
                before["result"]["process_id"] != after["result"]["process_id"], "Reopen reused an existing process")
        require(before["result"]["save"]["sha256"] == after["result"]["save"]["sha256"], "Save identity differs across fresh processes")
        require(before["result"]["plane_native_hashes"] == after["result"]["plane_native_hashes"], "Native material planes differ across fresh processes")
        require(before["result"]["authored_settings_sha256"] == after["result"]["authored_settings_sha256"],
                "Authored settings, effects or provenance differ across fresh processes")
        require(before["result"]["saved_authoring"] == after["result"]["saved_authoring"],
                "Explicit native edit, admitted import history or atmosphere settings differ across fresh processes")
    ledger = report.get("evidence_sha256", {})
    files = {p.relative_to(folder).as_posix():p for p in folder.rglob("*") if p.is_file()
             and p.name != "qualification.json" and "userdata" not in p.parts and "bootstrap-userdata" not in p.parts}
    require(ledger and set(ledger) == set(files), "Evidence ledger is absent, incomplete or contains unlisted files")
    for name, digest in ledger.items():
        require(not files[name].is_symlink() and sha(files[name]) == digest, "Original evidence changed: " + name)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--scene", action="append", choices=SCENES)
    parser.add_argument("--allow-source-delta", action="store_true", help="Local diagnostics only; never package")
    parser.add_argument("--process-timeout", type=int, default=600)
    parser.add_argument("--campaign-timeout", type=int, default=3600)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "strata2-workbench-qualification-v1", "status": "running", "platform": sys.platform,
              "cases": [], "scenes": [], "selected_scenes": args.scene or list(SCENES), "completed": False,
              "prospective_targets": PROSPECTIVE_TARGETS}
    source = runtime = loaded = loaded_assets = None
    started = time.monotonic()
    deadline = started + args.campaign_timeout
    try:
        require(60 <= args.process_timeout <= 600 and 120 <= args.campaign_timeout <= 3600, "Invalid campaign budget")
        source = identity(args.allow_source_delta)
        runtime = custody.verify_runtime_identity()
        project = args.project.resolve(strict=True)
        loaded = custody.project_identity(project, source, runtime)
        loaded_assets = project_assets_identity(project, source)
        report.update(source)
        report.update(runtime=runtime, project={"path": str(project), "inputs_sha256": loaded, "assets_sha256": loaded_assets})
        godot = args.godot.resolve(strict=True)
        require(sys.platform in GODOT_SHA256, "Unsupported execution platform")
        version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
        require(version == custody.windows.GODOT_VERSION and sha(godot) == GODOT_SHA256[sys.platform],
                "Godot executable differs from exact official pin")
        if sys.platform == "win32":
            require(sha(godot.with_name("Godot_v4.7-stable_win64.exe")) == GODOT_GUI_SHA256, "Godot GUI pin mismatch")
        report["godot"] = {"path": str(godot), "version": version, "sha256": sha(godot)}
        base = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                "--rendering-driver", "opengl3", "--path", str(project)]
        def run(label: str, flags: list[str], environment: dict) -> dict:
            remaining = deadline - time.monotonic()
            require(remaining > 1, "Campaign deadline exhausted")
            record = process_metrics.execute(base + flags, output / label, environment, min(args.process_timeout, remaining))
            record["label"] = label
            report["cases"].append(record)
            write_json(output / "qualification.json", report)
            require(record["status"] == "passed", record.get("error", "Godot process failed"))
            return record
        env = custody.case_environment(output / "bootstrap-userdata")
        env["CYBERSAND_SOURCE_REVISION"] = source["source_commit"]
        run("import", ["--headless", "--editor", "--quit"], env)
        for script, marker in REGRESSIONS.items():
            regression_env = dict(env, STRATA_EVIDENCE=str(output / script), STRATA_REPORT=str(output / script / "result.json"))
            row = run(script, ["--script", "res://tests/" + script + ".gd"], regression_env)
            require(marker in (output / script / "process.log").read_text(encoding="utf-8"), "Missing retained depth regression marker")
            if script in NATIVE_REPORTS:
                result = json.loads((output / script / "result.json").read_text(encoding="utf-8"))
                validate_native_report(result, script, source["source_commit"])
                verify_resource_receipt(output, row, result.get("process_id"))
        maximum_path = output / "maximum" / "maximum.json"
        maximum_env = custody.case_environment(output / "maximum-userdata" / "userdata")
        maximum_env.update(CYBERSAND_SOURCE_REVISION=source["source_commit"], STRATA_EVIDENCE=str(output / "maximum"),
                           STRATA_REPORT=str(maximum_path))
        report["maximum"] = {"status":"running"}
        try:
            maximum_process = run("maximum", ["--script", MAXIMUM_HARNESS], maximum_env)
            maximum_result = json.loads(maximum_path.read_text(encoding="utf-8"))
            validate_maximum(maximum_result, source["source_commit"])
            verify_resource_receipt(output, maximum_process, maximum_result.get("process_id"))
            report["maximum"] = {"status":"passed", "report_sha256":sha(maximum_path), "result":maximum_result, "process":maximum_process}
        except Exception as error:
            report["maximum"].update(status="failed", error=str(error))
            print("STRATA_MAXIMUM_FAIL", str(error), flush=True)
        write_json(output / "qualification.json", report)
        for scene in report["selected_scenes"]:
            entry = {"name": scene, "status": "running", "phases": {}}
            report["scenes"].append(entry)
            userdata = output / scene / "userdata"
            environment = custody.case_environment(userdata)
            environment.update(CYBERSAND_SOURCE_REVISION=source["source_commit"], STRATA_SCENE=scene,
                               STRATA_EVIDENCE=str(output / scene))
            try:
                for phase in ("install", "reopen"):
                    path = output / scene / (phase + ".json")
                    row = run(scene + "/" + phase, ["--script", HARNESS],
                              dict(environment, STRATA_PHASE=phase, STRATA_REPORT=str(path)))
                    result = json.loads(path.read_text(encoding="utf-8"))
                    validate_result(result, scene, phase, source["source_commit"])
                    verify_resource_receipt(output, row, result.get("process_id"))
                    saved = Path(result["save"]["path"]).resolve()
                    require(saved.is_relative_to(userdata.resolve()) and sha(saved) == result["save"]["sha256"],
                            "Saved composition is absent, changed, or outside isolated user data")
                    entry["phases"][phase] = {"report_sha256": sha(path), "process": row, "result": result}
                require(entry["phases"]["install"]["process"]["pid"] != entry["phases"]["reopen"]["process"]["pid"],
                        "Reopen requires a distinct process")
                require(entry["phases"]["install"]["result"]["save"]["sha256"] ==
                        entry["phases"]["reopen"]["result"]["save"]["sha256"], "Fresh process lost saved identity")
                require(entry["phases"]["install"]["result"]["plane_native_hashes"] ==
                        entry["phases"]["reopen"]["result"]["plane_native_hashes"], "Fresh process lost a native material plane")
                require(entry["phases"]["install"]["result"]["authored_settings_sha256"] ==
                        entry["phases"]["reopen"]["result"]["authored_settings_sha256"], "Fresh process lost exact authored effects/settings/provenance")
                require(entry["phases"]["install"]["result"]["saved_authoring"] ==
                        entry["phases"]["reopen"]["result"]["saved_authoring"], "Fresh process lost explicit native edit, import history or authored atmosphere")
                entry["status"] = "passed"
                print("STRATA_PASS", scene, flush=True)
            except Exception as error:
                entry.update(status="failed", error=str(error))
                print("STRATA_FAIL", scene, str(error), flush=True)
            finally:
                write_json(output / "qualification.json", report)
        require(report["maximum"]["status"] == "passed", "Maximum extent qualification failed")
        require(all(row["status"] == "passed" for row in report["scenes"]), "One or more scenes failed")
        report["status"] = "passed"
    except Exception as error:
        report.update(status="failed", error=str(error))
        print("STRATA_QUALIFICATION_FAILED", error, file=sys.stderr, flush=True)
    finally:
        if source is not None:
            try:
                require(identity(args.allow_source_delta) == source, "Source changed during campaign")
                require(custody.verify_runtime_identity() == runtime, "Runtime changed during campaign")
                if loaded is not None:
                    require(custody.project_identity(project, source, runtime) == loaded, "Loaded project changed during campaign")
                if loaded_assets is not None:
                    require(project_assets_identity(project, source) == loaded_assets, "Loaded binary assets changed during campaign")
                report["input_custody"] = "passed"
            except Exception as error:
                report.update(status="failed", input_custody="failed", custody_error=str(error))
        report.update(completed=True, elapsed_seconds=round(time.monotonic() - started, 3))
        report["evidence_sha256"] = {p.relative_to(output).as_posix(): sha(p) for p in sorted(output.rglob("*"))
            if p.is_file() and p.name != "qualification.json" and "userdata" not in p.parts and "bootstrap-userdata" not in p.parts}
        write_json(output / "qualification.json", report)
    print(json.dumps({"status": report["status"], "source": report.get("source_commit"), "platform": sys.platform}))
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
