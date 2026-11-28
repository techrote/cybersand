#!/usr/bin/env python3
"""Isolate ANGLE/WARP whole-plane work on the retained 8503 Windows package."""
import argparse
import collections
import datetime
import difflib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import time
import uuid

from package_windows import CONSOLE, GUI, MANIFEST, digest, need, safe_name, verify, write_json


SOURCE = "8503ec19e4d620e125dc6df2c5c6571b1256cb92"
TREE = "ece848ad77c06fafb60d597d87f9f53f7bc211f1"
MANIFEST_SHA256 = "2ddd8ddd29f34b11ae6519b93697e433e0fa7a06daf91223a3ec070b9b9f571c"
PACKAGE_ARTIFACT = "https://github.com/techrote/cybersand/actions/runs/44706204266/artifacts/14616761210"
ORIGINAL_ARTIFACT = "https://github.com/techrote/cybersand/actions/runs/44706204266/artifacts/14617316032"
SWITCH = "CYBERSAND_PUBPRES_PROBE_SKIP_HISTORY"
STEADY_SWITCH = "CYBERSAND_PUBPRES_PROBE_STEADY_SPARSE"
FIXED_MATERIAL_SWITCH = "CYBERSAND_PUBPRES_PROBE_FIXED_MATERIAL"
DIRECT_SWITCH = "CYBERSAND_PUBPRES_PROBE_DIRECT_DRAWABLE"
FRESH_SWITCH = "CYBERSAND_PUBPRES_PROBE_FRESH_DRAWABLE"
STAGE_SWITCH = "CYBERSAND_PUBPRES_PROBE_FRESH_STAGING"
PUBLISHER = "scripts/blit_material_publisher.gd"
FIXTURE = "tests/pubpres_transition.gd"
ORACLE = "tests/pubpres_warp_transition_oracle.gd"
ORDERS = {"reentry": "RABBAR", "steady-sparse": "RSABBASR", "fixed-material": "RSABBASR",
          "direct-drawable": "RABBAR", "fresh-drawable": "RABBAR", "sparse-storage": "RABBAR"}
TAPE_VARIANTS = {"steady-sparse": "steady_sparse", "fixed-material": "fixed_material"}
TAPE_PAIRS = ((3, 2), (4, 5), (3, 1), (4, 6), (2, 0), (5, 7), (1, 0), (6, 7))
PAIRINGS = {
    "reentry": ((2, 1), (3, 4), (2, 0), (3, 5), (1, 0), (4, 5)),
    "steady-sparse": TAPE_PAIRS,
    "fixed-material": TAPE_PAIRS,
    "direct-drawable": ((2, 1), (3, 4), (2, 0), (3, 5), (1, 0), (4, 5)),
    "fresh-drawable": ((2, 1), (3, 4), (2, 0), (3, 5), (1, 0), (4, 5)),
    "sparse-storage": ((2, 1), (3, 4), (2, 0), (3, 5), (1, 0), (4, 5)),
}
PHASES = ("enter_dense", "dense", "enter_sparse", "sparse")
EXPECTED_IMAGE_HASHES = {
    "current_sha256": "14f53c3a4451cdd0b64ae87457c71ae9366cabe609a51be1d180491a4c0011d9",
    "previous_sha256": "75f6f9c13da5687b4c5197741b1e96c3f223a29feaba32d3ff324b92cc8da90f",
}
INITIAL_PLANE = "20ad8501b542f948305b5979ed20180264726a8259766bf5ccd401339fce6959"
# Independent byte layout: an RG8 (58, 157) substrate, with an 8×8 patch
# at (96, 96) for current index 209 (58, 53) or previous index 208 (3, 16).
STEADY_INITIAL_PLANE = "bba669d64ff29015f86451843053132ee64b16ee3c6fdfe3745912d895497c43"
STEADY_IMAGE_HASHES = {
    "current_sha256": "cf7710f232e509dac78d5fd504f5168b8eeba5e28cb53b82763122200ed8f5ee",
    "previous_sha256": "e4ba27eec142ec9a2bc47c61140e5357ffeeac365c94d00905079e5fd37c7825",
}
EXPECTED_WARMUP_HISTORY = {
    "current_matches": True, "previous_matches": True,
    "current_sha256": "34899f9afac5f9626be3ba2d44852ca37650ab8e42744169bf2e6670bbd860bb",
    "previous_sha256": "c5645572e1bd5e439b94d656234b09efc2dbe958f1ba8f75d02e58a15b258aa5",
}
SHADER_SOURCE = "b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f"
SHADER_ANGLE = "6a1b5ea80bb034c41f93bb994e59791d25739c040b35caf2f24aa143cc12f52b"
ERRORS = re.compile(r"(?m)^(?:[ \t]*(?:(?:SCRIPT |USER )?ERROR:|Parse Error:))")
SCOPE = (
    "Windows ANGLE/D3D11 Microsoft Basic Render Driver transition mechanism probe on the retained installed package. "
    "Frame samples end at post-draw, not GPU completion. No native gameplay owner or physical GPU acceptance."
)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def tape_for(arm, experiment):
    return TAPE_VARIANTS.get(experiment, "transition") if arm in ("S", "B") else "transition"


def material_for(arm):
    return "full" if arm in ("R", "S") else "blit"


def direct_for(arm, experiment):
    return (experiment in ("direct-drawable", "fresh-drawable") and arm == "B"
            or experiment == "sparse-storage" and arm in ("A", "B"))


def fresh_for(arm, experiment):
    return (experiment == "fresh-drawable" and arm == "B"
            or experiment == "sparse-storage" and arm in ("A", "B"))


def initial_hash(tape):
    return STEADY_INITIAL_PLANE if tape == "steady_sparse" else INITIAL_PLANE


def expected_history(tape):
    hashes = STEADY_IMAGE_HASHES if tape == "steady_sparse" else EXPECTED_IMAGE_HASHES
    return {"current_matches": True, "previous_matches": True, **hashes}


def apply_overlay(project, output, expected, relative, changed, diff_name):
    target = project / relative
    original = target.read_bytes()
    need(changed != original, f"Overlay did not alter {relative}")
    overlay = "".join(difflib.unified_diff(
        original.decode().splitlines(keepends=True), changed.decode().splitlines(keepends=True),
        f"a/godot/{relative}", f"b/godot/{relative}",
    ))
    (output / diff_name).write_bytes(overlay.encode())
    target.write_bytes(changed)
    expected[relative] = digest(target)


def direct_drawable_overlay(original):
    # This diagnostic changes whole-plane transfer only. Sparse stages, both
    # drawable identities, validation and immutable logical histories remain
    # the retained application implementation. The public Godot 4.7 update
    # requires matching RGBA8 dimensions/format for these drawable RIDs.
    selector = b"\tif reuse_current:\n"
    need(original.count(selector) == 1, "Pinned publisher history-copy branch differs")
    changed = original.replace(selector, f'\tif reuse_current and OS.get_environment("{DIRECT_SWITCH}") != "1":\n'.encode())
    anchor = b"\tvar pool: StagingPool = full_staging if whole else (\n"
    need(changed.count(anchor) == 1, "Pinned publisher whole-plane selection differs")
    replacement = '''\tif whole and OS.get_environment("CYBERSAND_PUBPRES_PROBE_DIRECT_DRAWABLE") == "1":
		# Scratch causal probe: same persistent RGBA8 drawable identities,
		# immutable source and histories, direct whole-plane public RS upload.
		var direct: Image = source.duplicate()
		direct.convert(Image.FORMAT_RGBA8)
		last_update.atlas_assembly_usec = Time.get_ticks_usec()-started
		started = Time.get_ticks_usec()
		for plane: MaterialPlane in destinations:
			RenderingServer.texture_2d_update(plane.drawable.get_rid(),direct,0)
		last_update.staging_upload_usec = Time.get_ticks_usec()-started
		for plane: MaterialPlane in destinations:
			plane.exact_whole_bytes = source.get_data()
			plane.bytes.fill(PackedByteArray())
			plane.pending.fill(0)
		last_update.updated_tiles = pending_count if direct_whole else changed.size()
		last_update.submitted_bytes = extent.x*extent.y*4*destinations.size()
		last_update["direct_drawable_update"] = true
		last_update["direct_whole"] = true
		last_update["whole_gpu_copy"] = false
		_finish_metrics()
		return true
'''.encode()
    return changed.replace(anchor, replacement + anchor)


def fresh_drawable_overlay(original):
    # Keep the rejected update-in-place probe available unchanged. This new
    # experiment targets only recovery of the old drawable's GPU storage.
    changed = direct_drawable_overlay(original)
    anchor = b'''\t\tfor plane: MaterialPlane in destinations:
\t\t\tRenderingServer.texture_2d_update(plane.drawable.get_rid(),direct,0)
\t\tlast_update.staging_upload_usec = Time.get_ticks_usec()-started
'''
    need(changed.count(anchor) == 1, "Pinned direct drawable transfer differs")
    replacement = b'''\t\tvar fresh_storage := OS.get_environment("CYBERSAND_PUBPRES_PROBE_FRESH_DRAWABLE") == "1"
\t\tvar create_usec := 0
\t\tvar replace_usec := 0
\t\tfor plane: MaterialPlane in destinations:
\t\t\tif fresh_storage:
\t\t\t\t# Each replacement consumes its distinct donor RID. Queued calls
\t\t\t\t# retain the immutable Image; the destination RID stays stable.
\t\t\t\tvar transfer_started := Time.get_ticks_usec()
\t\t\t\tvar donor: RID = RenderingServer.texture_2d_create(direct)
\t\t\t\tcreate_usec += Time.get_ticks_usec()-transfer_started
\t\t\t\tif not donor.is_valid(): return false
\t\t\t\ttransfer_started = Time.get_ticks_usec()
\t\t\t\tRenderingServer.texture_replace(plane.drawable.get_rid(),donor)
\t\t\t\treplace_usec += Time.get_ticks_usec()-transfer_started
\t\t\telse:
\t\t\t\tRenderingServer.texture_2d_update(plane.drawable.get_rid(),direct,0)
\t\tlast_update.staging_upload_usec = Time.get_ticks_usec()-started
\t\tlast_update["fresh_drawable_storage"] = fresh_storage
\t\tlast_update["whole_storage_creations"] = destinations.size() if fresh_storage else 0
\t\tlast_update["whole_storage_replacements"] = destinations.size() if fresh_storage else 0
\t\tlast_update["whole_storage_create_usec"] = create_usec
\t\tlast_update["whole_storage_replace_usec"] = replace_usec
'''
    return changed.replace(anchor, replacement)


def fresh_oracle_overlay(original):
    selector = b'\tvar direct := OS.get_environment("CYBERSAND_PUBPRES_PROBE_DIRECT_DRAWABLE") == "1"\n'
    mode = b'\tvar mode := "direct_drawable" if direct else ("compact" if compact else "clone")'
    validation = b'\t\tif is_steady:\n'
    need(original.count(selector) == 1 and original.count(mode) == 1 and original.count(validation) == 1,
         "Pinned direct drawable history oracle differs")
    changed = original.replace(selector, selector + b'\tvar fresh := OS.get_environment("CYBERSAND_PUBPRES_PROBE_FRESH_DRAWABLE") == "1"\n')
    changed = changed.replace(mode, b'\tvar mode := "fresh_drawable" if fresh else ("direct_drawable" if direct else ("compact" if compact else "clone"))')
    checks = b'''\t\tif fresh:
\t\t\tvar whole: bool = row.phase in ["enter_dense", "dense", "enter_sparse"]
\t\t\t_check(bool(material.get("fresh_drawable_storage", false)) == whole,
\t\t\t\t"generation %d did not follow the fresh-storage selector" % index)
\t\t\t_check(int(material.get("whole_storage_creations", 0)) == int(whole)
\t\t\t\tand int(material.get("whole_storage_replacements", 0)) == int(whole),
\t\t\t\t"generation %d did not consume exactly one fresh storage donor" % index)
'''
    return changed.replace(validation, checks + validation)


def sparse_storage_overlay(original):
    changed = fresh_drawable_overlay(original)
    anchor = b"\tstage.update_layer(atlas,0)\n"
    need(changed.count(anchor) == 1, "Pinned sparse array upload differs")
    replacement = b'''\tif OS.get_environment("CYBERSAND_PUBPRES_PROBE_FRESH_STAGING") == "1":
\t\t# Immutable layered donor replaces only the existing stage storage;
\t\t# its Texture2DArray object, sampler and logical RID remain owned.
\t\tvar layers: Array[Image] = [atlas]
\t\tvar transfer_started := Time.get_ticks_usec()
\t\tvar donor: RID = RenderingServer.texture_2d_layered_create(layers,RenderingServer.TEXTURE_LAYERED_2D_ARRAY)
\t\tlast_update["staging_storage_create_usec"] = Time.get_ticks_usec()-transfer_started
\t\tif not donor.is_valid(): return false
\t\ttransfer_started = Time.get_ticks_usec()
\t\tRenderingServer.texture_replace(stage.get_rid(),donor)
\t\tlast_update["staging_storage_replace_usec"] = Time.get_ticks_usec()-transfer_started
\t\tlast_update["fresh_staging_storage"] = true
\t\tlast_update["staging_storage_creations"] = 1
\t\tlast_update["staging_storage_replacements"] = 1
\telse:
\t\tstage.update_layer(atlas,0)
'''
    changed = changed.replace(anchor, replacement)
    initialization = b'\t\tfor key: String in ["submitted_bytes", "atlas_assembly_usec", "staging_upload_usec",\n'
    need(changed.count(initialization) == 1, "Pinned distinct-history initialization counters differ")
    counters = b'\t\t\t\t"whole_storage_creations", "whole_storage_replacements", "whole_storage_create_usec", "whole_storage_replace_usec",\n'
    return changed.replace(initialization, initialization + counters)


def sparse_oracle_overlay(original):
    changed = fresh_oracle_overlay(original)
    selector = b'\tvar fresh := OS.get_environment("CYBERSAND_PUBPRES_PROBE_FRESH_DRAWABLE") == "1"\n'
    validation = b'\t\tif is_steady:\n'
    need(changed.count(selector) == 1 and changed.count(validation) == 1,
         "Pinned fresh storage oracle differs")
    changed = changed.replace(selector, selector + b'\tvar fresh_stage := OS.get_environment("CYBERSAND_PUBPRES_PROBE_FRESH_STAGING") == "1"\n')
    changed = changed.replace(b'\tif is_steady:\n', b'\tif fresh_stage: mode = "fresh_staging"\n\tif is_steady:\n', 1)
    checks = b'''\t\tif fresh_stage:
\t\t\tvar sparse: bool = row.phase == "sparse"
\t\t\t_check(bool(material.get("fresh_staging_storage", false)) == sparse,
\t\t\t\t"generation %d did not follow the fresh-stage selector" % index)
\t\t\t_check(int(material.get("staging_storage_creations", 0)) == int(sparse)
\t\t\t\tand int(material.get("staging_storage_replacements", 0)) == int(sparse),
\t\t\t\t"generation %d did not consume exactly one fresh stage donor" % index)
'''
    return changed.replace(validation, checks + validation)


def prepare_project(installed, project, output, manifest, oracle, experiment="reentry", fixture=None):
    expected = {}
    for name, sha in manifest["files_sha256"].items():
        if not name.startswith("godot/"):
            continue
        path = safe_name(name)
        relative = path.relative_to("godot").as_posix()
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(installed / path, target)
        expected[relative] = sha

    if experiment == "reentry":
        original = (project / PUBLISHER).read_bytes()
        selector = b"\t\treuse_current = incoming.count(1) <= 4\n"
        new_line = selector.rstrip(b"\n") + f' and OS.get_environment("{SWITCH}") != "1"\n'.encode()
        need(original.count(selector) == 1, "Pinned publisher eligibility gate differs")
        apply_overlay(project, output, expected, PUBLISHER, original.replace(selector, new_line), "publisher-overlay.patch")
    elif experiment == "direct-drawable":
        original = (project / PUBLISHER).read_bytes()
        apply_overlay(project, output, expected, PUBLISHER, direct_drawable_overlay(original), "publisher-overlay.patch")
    elif experiment == "fresh-drawable":
        original = (project / PUBLISHER).read_bytes()
        apply_overlay(project, output, expected, PUBLISHER, fresh_drawable_overlay(original), "publisher-overlay.patch")
    elif experiment == "sparse-storage":
        original = (project / PUBLISHER).read_bytes()
        apply_overlay(project, output, expected, PUBLISHER, sparse_storage_overlay(original), "publisher-overlay.patch")

    if fixture is not None:
        apply_overlay(project, output, expected, FIXTURE, fixture.read_bytes(), "fixture-overlay.patch")
        shutil.copyfile(project / FIXTURE, output / Path(FIXTURE).name)

    need(ORACLE not in expected, "The oracle would overwrite a retained package file")
    oracle_source = output / Path(ORACLE).name
    shutil.copyfile(oracle, project / ORACLE)
    if experiment == "fresh-drawable":
        apply_overlay(project, output, expected, ORACLE, fresh_oracle_overlay(oracle.read_bytes()), "oracle-overlay.patch")
    elif experiment == "sparse-storage":
        apply_overlay(project, output, expected, ORACLE, sparse_oracle_overlay(oracle.read_bytes()), "oracle-overlay.patch")
    shutil.copyfile(project / ORACLE, oracle_source)
    expected[ORACLE] = digest(oracle_source)
    need(not project_drift(project, expected), "Scratch project failed exact copy verification")
    return expected


def project_drift(project, expected):
    return [name for name, sha in expected.items() if not (project / name).is_file() or digest(project / name) != sha]


def capture(installed, project, folder, profiles, script=None, material="blit", skip=None, tape="transition", direct=None, fresh=None, fresh_stage=None):
    folder.mkdir()
    created = datetime.datetime.now(datetime.timezone.utc)
    nonce = uuid.uuid4().hex
    env = {key: value for key, value in os.environ.items() if not key.upper().startswith("CYBERSAND_")}
    settings = {
        "CYBERSAND_SOURCE_REVISION": SOURCE,
        "CYBERSAND_MATERIAL_PUBLICATION": material,
        "CYBERSAND_SHADER_NONCE": nonce,
        "CYBERSAND_SHADER_CACHE_STATE": "isolated-process-profile",
    }
    if skip is not None:
        settings[SWITCH] = str(int(skip))
    if tape == "steady_sparse":
        settings[STEADY_SWITCH] = "1"
    if tape == "fixed_material":
        settings[FIXED_MATERIAL_SWITCH] = "1"
    if direct is not None:
        settings[DIRECT_SWITCH] = str(int(direct))
    if fresh is not None:
        settings[FRESH_SWITCH] = str(int(fresh))
    if fresh_stage is not None:
        settings[STAGE_SWITCH] = str(int(fresh_stage))
    profile = profiles / folder.name
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        target = profile / key
        target.mkdir(parents=True)
        settings[key] = str(target)
    env.update(settings)
    command = [str(installed / CONSOLE), "--path", str(project), "--audio-driver", "Dummy",
               "--log-file", str(folder / "godot.log")]
    if script is None:
        command += ["--headless", "--editor", "--import"]
    else:
        command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
                    "--render-thread", "safe", "--script", "res://" + script, "--",
                    f"--material={material}", f"--receipt={folder / 'receipt.json'}"]
    record = {"command": command, "environment": settings, "started_utc": created.isoformat(),
              "timeout_seconds": 480, "timed_out": False}
    started = time.monotonic()
    try:
        with (folder / "stdout.log").open("wb") as stdout, (folder / "stderr.log").open("wb") as stderr:
            with subprocess.Popen(command, cwd=installed, env=env, stdout=stdout, stderr=stderr,
                                  creationflags=subprocess.CREATE_NO_WINDOW) as process:
                record["console_wrapper_pid"] = process.pid
                try:
                    process.wait(timeout=record["timeout_seconds"])
                except subprocess.TimeoutExpired:
                    record["timed_out"] = True
                    kill = str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe")
                    subprocess.run([kill, "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=15, check=False)
                    process.wait(timeout=15)
                record["exit"] = process.returncode
    except (OSError, subprocess.SubprocessError) as error:
        record["process_error"] = str(error)
    finally:
        if script != ORACLE:
            record["process_wall_seconds"] = time.monotonic() - started
        write_json(folder / "process.json", record)
    return record


def check_process(folder, record):
    need(not record["timed_out"] and record.get("exit") == 0, "Godot did not complete within its process limit")
    lines = []
    for name in ("stdout.log", "stderr.log", "godot.log"):
        text = (folder / name).read_text(encoding="utf-8-sig", errors="replace")
        lines.extend(re.sub(r"\x1b\[[0-9;]*m", "", text).splitlines())
    need(not any(ERRORS.match(line) for line in lines), "Godot diagnostics include runtime errors")
    return next((line for line in lines if line.startswith("OpenGL API")), "")


def check_context(context, record, script, script_sha, manifest, renderer):
    settings = record["environment"]
    need(context["source_revision"] == SOURCE and context["engine_sha256"] == manifest["engine"]["gui_sha256"]
         and context["godot"]["hash"] == "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
         and context["fixture"] == "res://" + script and context["fixture_sha256"] == script_sha
         and context["nonce"] == settings["CYBERSAND_SHADER_NONCE"] and context["cache_state"] == settings["CYBERSAND_SHADER_CACHE_STATE"]
         and context["execution_policy"]["ok"], "Recorded source/engine/fixture/process identity differs")
    need(context["platform"] == "Windows" and context["display_server"] == "Windows"
         and context["backend"] == "opengl3_angle", "A fresh real Windows ANGLE device is required")
    adapter = context["video_adapter"]
    need("Microsoft Basic Render Driver (0x0000008C)" in adapter and "Direct3D11" in adapter
         and adapter in renderer and "ANGLE" in renderer,
         "Microsoft Basic Render Driver on ANGLE D3D11/WARP was not observed")
    need(Path(context["engine_path"]).resolve() == Path(record["command"][0]).with_name(GUI).resolve()
         and Path(settings["APPDATA"]).resolve() in Path(context["user_data_dir"]).resolve().parents
         and context["process_id"] > 0, "Wrong engine location, process or isolated profile")
    shader = context["shader"]
    need(shader["variant"] == "angle_bounded_crossfade" and shader["source_bound"] and shader["source_file_bound"]
         and shader["source_file_sha256"] == SHADER_SOURCE and shader["source_sha256"] == SHADER_SOURCE
         and shader["variant_sha256"] == SHADER_ANGLE, "Expected retained ANGLE palette shader was not observed")


def distribution(values):
    values = sorted(value for value in values if value is not None)
    if not values:
        return None
    result = {"count": len(values), "max": values[-1]}
    for quantile in (50, 95, 99):
        index = (len(values) - 1) * quantile / 100
        low = math.floor(index)
        high = math.ceil(index)
        result[f"p{quantile}"] = values[low] + (values[high] - values[low]) * (index - low)
    return result


def timing_statistics(rows):
    result = {name: distribution(row[name] for row in rows)
              for name in ("frame_ms", "publication_ms", "godot_static_memory_peak_bytes", "reported_video_memory_bytes")}
    for name in ("staging_upload_usec", "atlas_assembly_usec", "history_copy_usec",
                 "gpu_blit_submit_usec", "backend_submit_usec", "image_patch_usec", "content_cache_usec",
                 "submitted_bytes", "allocated_gpu_bytes", "estimated_history_read_bytes",
                 "whole_storage_create_usec", "whole_storage_replace_usec",
                 "staging_storage_create_usec", "staging_storage_replace_usec"):
        result[name] = distribution(row["material"].get(name) for row in rows)
    result["history_copy_count"] = sum(bool(row["material"].get("history_copy")) for row in rows)
    result["history_staging_count"] = sum(bool(row["material"].get("history_staging")) for row in rows)
    result["direct_whole_count"] = sum(bool(row["material"].get("direct_whole")) for row in rows)
    result["direct_drawable_update_count"] = sum(bool(row["material"].get("direct_drawable_update")) for row in rows)
    result["fresh_drawable_storage_count"] = sum(bool(row["material"].get("fresh_drawable_storage")) for row in rows)
    result["fresh_staging_storage_count"] = sum(bool(row["material"].get("fresh_staging_storage")) for row in rows)
    for name in ("whole_storage_creations", "whole_storage_replacements", "staging_storage_creations", "staging_storage_replacements"):
        result[name + "_total"] = sum(row["material"].get(name, 0) for row in rows)
    result["whole_gpu_copy_count"] = sum(bool(row["material"].get("whole_gpu_copy")) for row in rows)
    result["submitted_bytes_total"] = sum(row["material"]["submitted_bytes"] for row in rows)
    result["frames_at_least_30ms"] = sum(row["frame_ms"] >= 30 for row in rows)
    result["outside_publication_ms"] = distribution(row["frame_ms"] - row["publication_ms"] for row in rows)
    return result


def read_timed(receipt, arm, folder, experiment="reentry"):
    material = material_for(arm)
    tape = tape_for(arm, experiment)
    steady = tape == "steady_sparse"
    rows = receipt["samples"]
    need(receipt["schema"] == "pubpres-transition-v1" and receipt["case"] == "transition_2048_w1"
         and receipt["complete"] and not receipt["failures"] and len(rows) == 180 and receipt["warmup_frames"] == 30
         and receipt["material_strategy"] == material and receipt["size"] == [2048, 2048] and receipt["channels"] == 2
         and receipt["initial_plane_sha256"] == initial_hash(tape)
         and receipt.get("tape", "transition" if experiment == "reentry" else None) == tape,
         "Timed fixture closure, geometry or input drift")
    need(receipt["display"] == {"max_fps": 0, "vsync_mode": 0, "window": [960, 720]}, "Expected uncapped display and VSync off")
    need(receipt["history"] == expected_history(tape),
         "Final exact current or previous GPU material history differs from retained tape")
    need(digest(folder / "receipt-after.png") == receipt["screenshot_sha256"], "Original screenshot missing or changed")

    phases = collections.defaultdict(list)
    entry_followers = collections.defaultdict(list)
    sequence_offsets = collections.defaultdict(list)
    targets = None
    stage_targets = {}
    previous_stage_slot = None
    for index, row in enumerate(rows, start=30):
        offset = index % 12
        phase = "sparse" if steady else PHASES[min(offset, 3)]
        dense = not steady and offset < 2
        need(row["sequence"] == index and row["sample"] == index - 30 and row["accepted"] is True
             and row["accepted_revision"] == index + 1 and row["dense"] == dense and row["phase"] == phase
             and row["patch_bytes"] == (8388608 if dense else 128), f"Revision {index + 1} input or acceptance differs")
        need(math.isfinite(row["frame_ms"]) and row["frame_ms"] > 0
             and math.isfinite(row["publication_ms"]) and row["publication_ms"] >= 0
             and row["publish_end_usec"] >= row["publish_begin_usec"]
             and math.isclose(row["publication_ms"], (row["publish_end_usec"] - row["publish_begin_usec"]) / 1000),
             f"Revision {index + 1} timeline is invalid")
        update = row["material"]
        cloned = offset == 2 and experiment != "sparse-storage" and (arm == "A" or (experiment == "fixed-material" and arm == "B"))
        compact = experiment == "reentry" and arm == "B" and offset == 2
        direct = direct_for(arm, experiment) and offset <= 2
        fresh = fresh_for(arm, experiment) and offset <= 2
        fresh_stage = experiment == "sparse-storage" and arm == "B" and offset >= 3
        whole = material == "blit" and (dense or compact or direct)
        need(update["requested_mode"] == material and update["backend"] == material and update["driver"] == "opengl3_angle"
             and not update["fallback_reason"] and bool(update.get("history_copy")) == cloned
             and bool(update.get("history_staging")) == cloned
             and bool(update.get("direct_whole")) == whole and bool(update.get("whole_gpu_copy")) == (whole and not direct)
             and bool(update.get("direct_drawable_update")) == direct
             and bool(update.get("fresh_drawable_storage")) == fresh
             and bool(update.get("fresh_staging_storage")) == fresh_stage,
             f"Revision {index + 1} used a different publisher or copy mechanism")
        need(update["submitted_bytes"] == (16777216 if direct else (8388608 if whole or material == "full" else 32768)),
             f"Revision {index + 1} staged unexpected bytes")
        if direct:
            need(update["gpu_blit_calls"] == 0 and update["blit_pixels"] == 0
                 and update["retirement_blit_calls"] == 0 and update["staging_slot"] == -1,
                 f"Revision {index + 1} retained a whole-plane draw or used a staging slot")
        need(update.get("whole_storage_creations", 0) == int(fresh)
             and update.get("whole_storage_replacements", 0) == int(fresh),
             f"Revision {index + 1} created or consumed an unexpected storage donor")
        if fresh:
            need(update["whole_storage_create_usec"] >= 0 and update["whole_storage_replace_usec"] >= 0
                 and update["whole_storage_create_usec"] + update["whole_storage_replace_usec"] <= update["staging_upload_usec"],
                 f"Revision {index + 1} has invalid fresh storage timing")
        need(update.get("staging_storage_creations", 0) == int(fresh_stage)
             and update.get("staging_storage_replacements", 0) == int(fresh_stage),
             f"Revision {index + 1} created or consumed an unexpected stage donor")
        if fresh_stage:
            need(update["staging_storage_create_usec"] >= 0 and update["staging_storage_replace_usec"] >= 0
                 and update["staging_storage_create_usec"] + update["staging_storage_replace_usec"] <= update["staging_upload_usec"],
                 f"Revision {index + 1} has invalid fresh stage timing")
        if material == "blit":
            pair = (update["current_texture_rid"], update["previous_texture_rid"])
            need(pair[0] > 0 and pair[1] > 0 and pair[0] != pair[1]
                 and (targets is None or pair == targets[::-1]), f"Revision {index + 1} did not reuse the two alternating draw targets")
            targets = pair
            if not whole:
                need(update["atlas_capacity"] == 1 and update["staging_width"] == 128 and update["staging_height"] == 128,
                     f"Revision {index + 1} did not stage one 128×128 RG8 tile")
                if experiment == "sparse-storage":
                    slot, rid = update["staging_slot"], update["staging_resource_rid"]
                    need(update["staging_slots"] == 3 and 0 <= slot < 3 and rid > 0 and rid not in pair
                         and update["staging_layer"] == 0 and update["staging_resource_layers"] == 1
                         and (previous_stage_slot is None or slot == (previous_stage_slot + 1) % 3),
                         f"Revision {index + 1} changed the independent three-slot sparse ring")
                    if slot in stage_targets:
                        need(stage_targets[slot] == rid, f"Revision {index + 1} changed the logical sparse stage RID")
                    else:
                        need(rid not in stage_targets.values(), f"Revision {index + 1} aliased two sparse slots")
                        stage_targets[slot] = rid
                    previous_stage_slot = slot
        if cloned:
            need(update["atlas_capacity"] == 1 and update["estimated_history_read_bytes"] == 16777216
                 and update["history_copy_usec"] >= 0, f"Revision {index + 1} is missing the GPU history clone receipt")
        phases[phase].append(row)
        sequence_offsets[offset].append(row["frame_ms"])
        if not steady and 2 <= offset <= (8 if experiment == "sparse-storage" else 5):
            entry_followers[f"entry_plus_{offset - 2}"].append(row)
    expected_phases = {"sparse": 180} if steady else dict(zip(PHASES, (15, 15, 15, 135)))
    need({name: len(group) for name, group in phases.items()} == expected_phases, "Input tape phase coverage differs")
    if experiment == "sparse-storage" and material == "blit":
        need(len(stage_targets) == 3, "Sparse storage experiment did not exercise every independent stage slot")
    return {
        "tape": tape,
        "accepted_revisions": len(rows), "accepted_updates_per_second": 1000 * len(rows) / sum(row["frame_ms"] for row in rows),
        "setup_usec": receipt["setup_usec"], "overall": timing_statistics(rows),
        "phases": {phase: timing_statistics(group) for phase, group in phases.items()},
        "frame_ms_by_sequence_mod_12": {offset: distribution(values) for offset, values in sorted(sequence_offsets.items())},
        "first_sparse_and_following_callbacks": {name: timing_statistics(group) for name, group in entry_followers.items()},
        "history": receipt["history"], "screenshot_sha256": receipt["screenshot_sha256"],
    }


def read_oracle(receipt, arm, experiment="reentry"):
    tape = tape_for(arm, experiment)
    mode = "clone" if arm == "A" else {"fresh-drawable": "fresh_drawable", "direct-drawable": "direct_drawable",
                                       "reentry": "compact", "sparse-storage": "fresh_staging", **TAPE_VARIANTS}[experiment]
    if experiment == "sparse-storage":
        mode = "fresh_drawable" if arm == "A" else "fresh_staging"
    sparse_entries = 0 if tape == "steady_sparse" else 15
    need(receipt["schema"] == "pubpres-warp-history-oracle-v1" and receipt["case"] == "transition_2048_w1"
         and receipt["complete"] and not receipt["failures"] and receipt["mode"] == mode
         and receipt["frames_checked"] == 180 and receipt["current_matches"] == 180 and receipt["previous_matches"] == 180
         and receipt["sparse_entries"] == sparse_entries and receipt["initial_plane_sha256"] == initial_hash(tape)
         and receipt.get("tape", "transition" if experiment == "reentry" else None) == tape,
         "Untimed all-revision GPU or first-sparse mechanism oracle failed")
    entries = receipt["entry_history"]
    expected_sequence = [i for i in range(30, 210) if i % 12 == 2] if sparse_entries else []
    need([entry["sequence"] for entry in entries] == expected_sequence,
         "Oracle sparse-entry sequence differs")
    for entry in entries:
        need(all(re.fullmatch("[0-9a-f]{64}", entry[key]) for key in EXPECTED_IMAGE_HASHES),
             "Missing first-sparse per-plane history hash")
    required_history = ("history", "warmup_history") if experiment in TAPE_VARIANTS else ()
    for key, expected in (("history", expected_history(tape)), ("warmup_history", EXPECTED_WARMUP_HISTORY)):
        if key in receipt or key in required_history:
            need(receipt[key] == expected, f"Independent oracle {key} differs from the exact tape")
    result = {key: receipt[key] for key in ("mode", "frames_checked", "current_matches", "previous_matches", "entry_history")}
    result.update(tape=tape, history=receipt.get("history"), warmup_history=receipt.get("warmup_history"))
    return result


def run_arm(installed, project, folder, profiles, manifest, project_hashes, arm, oracle=False, experiment="reentry"):
    fixture = ORACLE if oracle else FIXTURE
    tape = tape_for(arm, experiment)
    record = capture(installed, project, folder, profiles, fixture, material_for(arm),
                     skip=arm == "B" if experiment == "reentry" else None, tape=tape,
                     direct=direct_for(arm, experiment) if experiment in ("direct-drawable", "fresh-drawable", "sparse-storage") else None,
                     fresh=fresh_for(arm, experiment) if experiment in ("fresh-drawable", "sparse-storage") else None,
                     fresh_stage=arm == "B" if experiment == "sparse-storage" else None)
    result = {"arm": arm, "tape": tape, "status": "FAIL", "process": record}
    try:
        renderer = check_process(folder, record)
        result["renderer"] = renderer
        receipt = load_json(folder / "receipt.json")
        result["context"] = receipt["context"]
        check_context(receipt["context"], record, fixture, project_hashes[fixture], manifest, renderer)
        result["analysis"] = read_oracle(receipt, arm, experiment) if oracle else read_timed(receipt, arm, folder, experiment)
        result["status"] = "PASS"
    except (KeyError, TypeError, ValueError, OSError) as error:
        result["failure"] = str(error)
    write_json(folder / "analysis.json", result)
    print(folder.name, result["status"], result.get("failure", ""), flush=True)
    return result


def check_campaign(timed, oracles, experiment="reentry"):
    runs = timed + oracles
    need("".join(run["arm"] for run in timed) == ORDERS[experiment] and "".join(run["arm"] for run in oracles) == "AB"
         and all(run["status"] == "PASS" for run in runs), "A timed or oracle arm was missing or failed")
    for identity in ("process_id", "nonce", "user_data_dir"):
        need(len({arm["context"][identity] for arm in runs}) == len(runs), "Reused process, receipt identity or user profile")
    ignored = {"process_id", "nonce", "user_data_dir", "fixture", "fixture_sha256"}
    known = {key: value for key, value in runs[0]["context"].items() if key not in ignored}
    need(all(
        {key: value for key, value in arm["context"].items() if key not in ignored} == known
        and arm["renderer"] == runs[0]["renderer"] for arm in runs
    ), "Renderer or fixture context changed between fresh-process captures")
    first, second = (oracle["analysis"] for oracle in oracles)
    need(first["warmup_history"] == second["warmup_history"], "Untimed histories differ at the warmup boundary")
    if experiment != "steady-sparse":
        need(first["entry_history"] == second["entry_history"], "Untimed first-sparse GPU history hashes differ")


def compare_arms(timed, experiment="reentry"):
    comparisons = []
    for left, right in PAIRINGS[experiment]:
        trial, control = (timed[index]["analysis"] for index in (left, right))
        scopes = {"overall": trial["overall"], **trial["first_sparse_and_following_callbacks"]}
        controls = {"overall": control["overall"], **control["first_sparse_and_following_callbacks"]}
        comparisons.append({
            "trial": f"{left}-{timed[left]['arm']}", "control": f"{right}-{timed[right]['arm']}",
            "accepted_updates_per_second_delta": trial["accepted_updates_per_second"] - control["accepted_updates_per_second"],
            "trial_minus_control_ms": {
                scope: {metric: {quantile: values[metric][quantile] - controls[scope][metric][quantile]
                                 for quantile in ("p50", "p95", "p99", "max")}
                        for metric in ("frame_ms", "publication_ms", "outside_publication_ms")}
                for scope, values in scopes.items() if scope in controls
            },
        })
    return comparisons


def tape_interactions(timed):
    interactions = []
    for indices in ((2, 0, 3, 1), (5, 7, 4, 6)):
        a, r, b, s = (timed[index]["analysis"] for index in indices)
        frame_p95 = [arm["overall"]["frame_ms"]["p95"] for arm in (a, r, b, s)]
        cadence = [arm["accepted_updates_per_second"] for arm in (a, r, b, s)]
        interactions.append({
            "formula": "(A - R) - (B - S)",
            "arm_order": [f"{index}-{timed[index]['arm']}" for index in indices],
            "frame_p95_ms": (frame_p95[0] - frame_p95[1]) - (frame_p95[2] - frame_p95[3]),
            "accepted_updates_per_second": (cadence[0] - cadence[1]) - (cadence[2] - cadence[3]),
        })
    return interactions


def host_identity(output):
    data = {"platform": platform.platform(), "processor": platform.processor(), "logical_processors": os.cpu_count(),
            "runner_os": os.environ.get("RUNNER_OS"), "runner_image_os": os.environ.get("ImageOS"),
            "runner_image_version": os.environ.get("ImageVersion")}
    try:
        command = ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                   "@{gpu=@(Get-CimInstance Win32_VideoController | Select Name,DriverVersion); "
                   "cpu=@(Get-CimInstance Win32_Processor | Select Name,NumberOfCores,NumberOfLogicalProcessors); "
                   "os=Get-CimInstance Win32_OperatingSystem | Select Caption,Version,BuildNumber} | ConvertTo-Json -Depth 4"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=20, check=True)
        data["windows"] = json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        data["cim_unavailable"] = str(error)
    write_json(output / "hardware.json", data)


def run(installed, output, oracle, experiment="reentry", fixture=None):
    summary = {"scope": SCOPE, "experiment": experiment, "source": SOURCE, "tree": TREE, "package_artifact": PACKAGE_ARTIFACT,
               "original_evidence_artifact": ORIGINAL_ARTIFACT, "timed": [], "untimed_oracles": [],
               "status": "HOLD", "complete": False, "performance_status": "MEASUREMENTS_ONLY"}
    host_identity(output)
    try:
        need(digest(installed / MANIFEST) == MANIFEST_SHA256, "Extract the exact hosted package artifact from run 44706204266")
        manifest = verify(installed, SOURCE)
        need(manifest["source_tree"] == TREE, "Retained package tree differs")
        shutil.copyfile(installed / MANIFEST, output / "package-manifest.json")
        with tempfile.TemporaryDirectory(prefix="pubpres-warp-") as scratch:
            project = Path(scratch) / "project"
            profiles = Path(scratch) / "profiles"
            expected = prepare_project(installed, project, output, manifest, oracle, experiment, fixture)
            order = ORDERS[experiment]
            plan = {"experiment": experiment, "order": list(order), "arms": {
                    arm: {"tape": tape_for(arm, experiment), "material": material_for(arm),
                          "bypass_history": (experiment == "reentry" and arm == "B") or direct_for(arm, experiment),
                          "direct_drawable": direct_for(arm, experiment),
                          "fresh_drawable_storage": fresh_for(arm, experiment),
                          "fresh_staging_storage": experiment == "sparse-storage" and arm == "B"} for arm in sorted(set(order))},
                    "oracle_order": ["A", "B"],
                    "untimed_oracles_before_timing": experiment in ("fresh-drawable", "sparse-storage"),
                    "manifest_sha256": MANIFEST_SHA256, "source_publisher_sha256": manifest["files_sha256"]["godot/" + PUBLISHER],
                    "probe_publisher_sha256": expected[PUBLISHER], "oracle_sha256": expected[ORACLE],
                    "source_fixture_sha256": manifest["files_sha256"]["godot/" + FIXTURE],
                    "probe_fixture_sha256": expected[FIXTURE],
                    "publisher_overlay_sha256": digest(output / "publisher-overlay.patch") if experiment in ("reentry", "direct-drawable", "fresh-drawable", "sparse-storage") else None,
                    "oracle_source_sha256": digest(oracle),
                    "oracle_overlay_sha256": digest(output / "oracle-overlay.patch") if experiment in ("fresh-drawable", "sparse-storage") else None,
                    "fixture_overlay_sha256": digest(output / "fixture-overlay.patch") if fixture is not None else None,
                    "project_inputs_sha256": expected}
            if experiment in TAPE_VARIANTS:
                need(plan["source_publisher_sha256"] == plan["probe_publisher_sha256"], "Tape comparisons require the unchanged production publisher")
            if experiment == "fresh-drawable":
                plan["hypothesis"] = (
                    "The first dense RGBA8 upload after sparse FBO writes may recover the existing ANGLE Image11 GPU storage "
                    "before mapping its CPU staging data. A fresh immutable RGBA8 texture followed by texture_replace "
                    "targets that wait while preserving the same two logical texture RIDs and subsequent sparse path. "
                    "This is a source-supported mechanism hypothesis, not an observed GPU call trace."
                )
                plan["fresh_storage_contract"] = {
                    "image": "distinct immutable RGBA8 image, exact drawable dimensions",
                    "ownership": "one fresh donor RID per destination; texture_replace consumes donor; destination RID unchanged",
                    "unchanged": "source packet, both complete histories, sparse stages, copy shader, tape, engine and runtime",
                    "source_inspected": ["godotengine/godot@4.7-stable", "google/angle@aaebda1c5a40"],
                    "memory_limit": "reported_video_memory counts logical GL allocation; it cannot prove driver-inflight residency",
                }
            if experiment == "sparse-storage":
                plan["hypothesis"] = (
                    "Fresh whole storage removed the first dense update wait but retained slow first sparse-stage ring reuse "
                    "and later frame tails. A fresh immutable layered RG8 donor consumed by texture_replace tests that "
                    "stage reuse wait without changing logical stage RIDs, fixed samplers, ring size or sparse draw work. "
                    "Upstream render-target promotion remains an alternative cause; total frame tails, not moved waits, decide."
                )
                plan["control"] = "A is fresh whole storage only, the rejected treatment from run 44745728887; R is full RG8"
                plan["fresh_storage_contract"] = {
                    "image": "distinct immutable RG8 atlas, one layer, exact owned stage dimensions",
                    "ownership": "one fresh layered donor per sparse submission; texture_replace consumes donor; stage RID and sampler unchanged",
                    "unchanged": "both complete histories, whole-storage path, ring capacity, copy shader, tape, engine and runtime",
                    "initialization_receipts": "distinct-history initialization sums whole-storage donor counts for both targets",
                    "source_inspected": ["godotengine/godot@4.7-stable", "google/angle@aaebda1c5a40"],
                    "memory_limit": "reported_video_memory counts logical GL allocation; it cannot prove driver-inflight residency",
                }
            write_json(output / "probe-plan.json", plan)
            folder = output / "import"
            check_process(folder, capture(installed, project, folder, profiles))
            drift = project_drift(project, expected)
            mutable = [name for name in drift if name == ".godot/global_script_class_cache.cfg" or name.endswith(".import")]
            summary["import_changed_metadata"] = mutable
            need(set(drift) == set(mutable), "Editor import changed a pinned source, oracle or runtime")
            for name in mutable:
                expected[name] = digest(project / name)
            if experiment in ("fresh-drawable", "sparse-storage"):
                for arm in ("A", "B"):
                    folder = output / f"oracle-{arm}"
                    summary["untimed_oracles"].append(run_arm(installed, project, folder, profiles, manifest, expected, arm,
                                                             oracle=True, experiment=experiment))
                need(all(run["status"] == "PASS" for run in summary["untimed_oracles"]),
                     "Fresh storage history oracle failed; timed arms were not started")
            for index, arm in enumerate(order):
                folder = output / f"timed-{index}-{arm}"
                summary["timed"].append(run_arm(installed, project, folder, profiles, manifest, expected, arm, experiment=experiment))
            if experiment not in ("fresh-drawable", "sparse-storage"):
                for arm in ("A", "B"):
                    folder = output / f"oracle-{arm}"
                    summary["untimed_oracles"].append(run_arm(installed, project, folder, profiles, manifest, expected, arm,
                                                             oracle=True, experiment=experiment))
            summary["scratch_final_drift"] = project_drift(project, expected)
            need(not summary["scratch_final_drift"], "Scratch source or runtime changed during the replay")
        verify(installed, SOURCE)
        need(digest(installed / MANIFEST) == MANIFEST_SHA256, "Installed package identity changed on disk")
        check_campaign(summary["timed"], summary["untimed_oracles"], experiment)
        summary["paired_comparisons"] = compare_arms(summary["timed"], experiment)
        if experiment in TAPE_VARIANTS:
            summary["paired_interaction"] = tape_interactions(summary["timed"])
        summary["complete"] = True
        summary["status"] = "PASS"
    except (KeyError, TypeError, ValueError, OSError) as error:
        summary["failure"] = str(error)
    finally:
        write_json(output / "summary.json", summary)
    print("WARP transition", summary["status"], summary.get("failure", ""), flush=True)
    return int(summary["status"] != "PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installed", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--oracle", required=True, type=Path)
    parser.add_argument("--experiment", choices=tuple(ORDERS), default="reentry")
    parser.add_argument("--fixture", type=Path, help="Checkout-only transition fixture with the selected input tape")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("Windows ANGLE/D3D11 WARP is required")
    installed = args.installed.resolve(strict=True)
    oracle = args.oracle.resolve(strict=True)
    fixture = args.fixture.resolve(strict=True) if args.fixture is not None else None
    output = args.output.resolve()
    if not installed.is_dir() or not oracle.is_file() or oracle.suffix != ".gd":
        parser.error("Expected a fresh installed package directory and a GDScript oracle file")
    if args.experiment in TAPE_VARIANTS and fixture is None:
        parser.error(f"{args.experiment} requires --fixture")
    if fixture is not None and (not fixture.is_file() or fixture.suffix != ".gd"):
        parser.error("Expected a GDScript tape fixture")
    if output.exists() or installed in output.parents:
        parser.error("Expected a new artifact directory outside the installed package")
    output.mkdir(parents=True)
    return run(installed, output, oracle, args.experiment, fixture)


if __name__ == "__main__":
    raise SystemExit(main())
