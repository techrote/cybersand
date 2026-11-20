#!/usr/bin/env python3
"""Bounded Windows WARP full-only storage experiment on the retained 673 package.

A calls ImageTexture.update; B calls ImageTexture.set_image with the same
detached Image. Both actual Main paths otherwise remain identical. Two untimed
180-by-two-history oracles gate fresh-process Wave Follow ABBA comparisons.
This is a disposable source overlay, not a production mode or acceptance gate.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import datetime
import difflib
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time
import uuid

from package_windows import GUI, MANIFEST, digest, need, verify, write_json
from source_results import canonical, check_material_status, distribution, reduce_receipt


SOURCE = "673204d1c887eeb32dae247007316b687f177727"
MANIFEST_SHA256 = "abf35956f7cfbd6558caba220b850b5806926cfb37ed9d4de15b6c5b5d1bbcb9"
MAIN_SHA256 = "33163b5411f2324cb4c3dbb2b94fd8ea1c225a4eb0cd0e0767afbc11b6031bbb"
ENGINE_SHA256 = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
MAIN = "scripts/main.gd"
GAMEPLAY = "tests/pubpres_source_gameplay.gd"
TRANSITION = "tests/pubpres_transition.gd"
ORACLE = "tests/pubpres_source_transition_oracle.gd"
SWITCH = "CYBERSAND_PUBPRES_PROBE_FULL_STORAGE"
STRATEGIES = {"A": "update", "B": "set_image"}
POLICY = {"backend": "full", "policy": "windows_angle_warp_full"}
ERRORS = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load script|Failed loading resource:|.*Error initializing GLAD|.*MakeCurrent failed)")
IMPORT_CRLF_PATHS = {
    "addons/godot-rapier2d/Radial2D.svg.import",
    "addons/godot-rapier2d/icons/Fluid2D.svg.import",
    "addons/godot-rapier2d/icons/StateManager2D.svg.import",
    "addons/godot-rapier2d/logo_square_2d.png.import",
}


def replace_once(original, before, after):
    need(original.count(before) == 1, "Guarded source anchor missing or ambiguous")
    return original.replace(before, after)


def main_overlay(original):
    """Preserve the original detached payload and pair owner; split its clocks."""
    text = original.decode("utf-8")
    for current, previous in (("image.duplicate()", "recovery_previous"),
                              ("current.duplicate()", "previous.duplicate()")):
        anchor = (f"\t\ttexture = ImageTexture.create_from_image({current})\n"
                  f"\t\tprevious_texture = ImageTexture.create_from_image({previous})\n")
        current_source = "image" if current == "image.duplicate()" else "current"
        previous_source = "recovery_previous" if previous == "recovery_previous" else "previous"
        text = replace_once(text, anchor, anchor +
                            f"\t\ttexture.set_meta(\"pubpres_full_descriptor\", _pubpres_full_descriptor({current_source}))\n"
                            f"\t\tprevious_texture.set_meta(\"pubpres_full_descriptor\", _pubpres_full_descriptor({previous_source}))\n")
    text = replace_once(text, "\t(texture as ImageTexture).update(image.duplicate())\n", '''\tvar detached: Image = image.duplicate()
\tvar detached_usec: int = Time.get_ticks_usec() - started
\tvar target: ImageTexture = texture as ImageTexture
\tvar descriptor: Vector4i = _pubpres_full_descriptor(detached)
\tvar storage_strategy: String = OS.get_environment("CYBERSAND_PUBPRES_PROBE_FULL_STORAGE")
\tvar valid_descriptor: bool = target != null and detached.get_format() in [Image.FORMAT_R8, Image.FORMAT_RG8] \\
\t\tand not detached.is_empty() and not detached.has_mipmaps() \\
\t\tand target.get_width() == detached.get_width() and target.get_height() == detached.get_height() \\
\t\tand target.get_meta("pubpres_full_descriptor", Vector4i()) == descriptor \\
\t\tand storage_strategy in ["update", "set_image"]
\tif not valid_descriptor:
\t\tpush_error("PUBPRES full storage descriptor or treatment refused")
\t\t(get_tree() if is_inside_tree() else Engine.get_main_loop()).quit(2)
\t\treturn
\tvar stable_rid: RID = target.get_rid()
\tvar api_started: int = Time.get_ticks_usec()
\tif storage_strategy == "set_image":
\t\ttarget.set_image(detached)
\telse:
\t\ttarget.update(detached)
\tvar api_usec: int = Time.get_ticks_usec() - api_started
\tif not stable_rid.is_valid() or target.get_rid() != stable_rid:
\t\tpush_error("PUBPRES full storage changed the logical history RID")
\t\t(get_tree() if is_inside_tree() else Engine.get_main_loop()).quit(2)
\t\treturn
''')
    text = replace_once(text, '\t\t"tile_assembly_usec":0, "backend_submit_usec":Time.get_ticks_usec() - started}\n', '''\t\t"tile_assembly_usec":0, "backend_submit_usec":Time.get_ticks_usec() - started,
\t\t"image_detach_usec":detached_usec, "texture_api_usec":api_usec,
\t\t"full_descriptor_valid":valid_descriptor, "full_storage_strategy":storage_strategy,
\t\t"full_storage_creations":int(storage_strategy == "set_image"),
\t\t"full_storage_replacements":int(storage_strategy == "set_image"),
\t\t"full_current_rid":stable_rid.get_id(), "full_previous_rid":previous_texture.get_rid().get_id()}
''')
    text = replace_once(text, "\nfunc _full_material_rectangle() -> PackedInt32Array:\n", '''
# Diagnostic construction provenance on Main's same two resources. No GPU
# readback or additional texture owner enters the timed publication path.
func _pubpres_full_descriptor(value: Image) -> Vector4i:
\treturn Vector4i(value.get_width(), value.get_height(), value.get_format(), int(value.has_mipmaps()))


func _full_material_rectangle() -> PackedInt32Array:
''')
    return text.encode("utf-8")


def oracle_overlay(original):
    return replace_once(original.decode("utf-8"),
                        "and texture_image.get_format() == Image.FORMAT_RG8 and texture_image.get_data() == pixels",
                        "and texture_image.get_format() == Image.FORMAT_RG8 and not texture_image.has_mipmaps() and texture_image.get_data() == pixels").encode("utf-8")


def copy_project(source, target, imported=False):
    def ignored(folder, names):
        if Path(folder).name == ".godot":
            return {name for name in names if name == "shader_cache"} if imported else set(names) - {".gdignore", "extension_list.cfg", "global_script_class_cache.cfg"}
        return {name for name in names if name in {".git", "__pycache__"}}
    shutil.copytree(source, target, ignore=ignored)


def project_drift(project, expected):
    # Godot is allowed to regenerate only its explicit import bootstrap. Every
    # production source, runtime, shader and registered fixture remains pinned.
    generated = {".godot/global_script_class_cache.cfg", ".godot/extension_list.cfg"}
    return [name for name, value in expected.items()
            if name not in generated and (not (project / name).is_file() or digest(project / name) != value)]


def require_project_identity(project, expected, label):
    changed = project_drift(project, expected)
    need(not changed, label + ": " + ", ".join(changed))


def restore_import_newlines(project, installed, expected, folder):
    """Record four observed editor metadata rewrites, then restore exact bytes.

    This is not an identity exception: the same complete source/runtime hash
    check runs after restoration. Missing files and every other drift fail.
    """
    folder.mkdir(parents=True)
    rows, replacements = [], []
    for index, name in enumerate(project_drift(project, expected)):
        original_path, imported_path = installed / "godot" / name, project / name
        original = original_path.read_bytes() if original_path.is_file() else None
        imported = imported_path.read_bytes() if imported_path.is_file() else None
        allowed = name in IMPORT_CRLF_PATHS and original is not None and imported is not None \
            and hashlib.sha256(original).hexdigest() == expected[name] \
            and b"\r\n" in original and imported != original and imported == original.replace(b"\r\n", b"\n")
        row = {"path": name, "expected_sha256": expected[name], "allowed_exact_crlf_to_lf": allowed,
               "original_sha256": hashlib.sha256(original).hexdigest() if original is not None else None,
               "imported_sha256": hashlib.sha256(imported).hexdigest() if imported is not None else None}
        for label, value in (("original", original), ("imported", imported)):
            if value is not None:
                filename = f"{index}-{label}.bin"
                (folder / filename).write_bytes(value)
                row[label + "_bytes_file"] = filename
        rows.append(row)
        if allowed:
            replacements.append((imported_path, original))
    write_json(folder / "observed.json", rows)
    refused = [row["path"] for row in rows if not row["allowed_exact_crlf_to_lf"]]
    need(not refused, "Unsupported import source/runtime drift: " + ", ".join(refused))
    for path, original in replacements:
        path.write_bytes(original)
    require_project_identity(project, expected, "Import source identity after exact byte restoration")
    write_json(folder / "restored.json", {"restored": [row["path"] for row in rows],
                                         "complete_expected_hashes_passed": True,
                                         "scope": "Only exact CRLF-to-LF rewrites of the four named non-executable icon import descriptors; original bytes restored before any oracle or gameplay process."})


class MemoryCounters(ctypes.Structure):
    _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                *[(name, ctypes.c_size_t) for name in ("PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                   "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage", "PrivateUsage")]]


def windows_memory_sampler():
    query = ctypes.WinDLL("psapi", use_last_error=True).GetProcessMemoryInfo
    query.argtypes = [wintypes.HANDLE, ctypes.POINTER(MemoryCounters), wintypes.DWORD]
    query.restype = wintypes.BOOL

    def sample(process, elapsed_ms):
        counters = MemoryCounters()
        counters.cb = ctypes.sizeof(counters)
        if not query(wintypes.HANDLE(int(process._handle)), ctypes.byref(counters), counters.cb):
            return None
        return {"pid": process.pid, "elapsed_ms": elapsed_ms, "working_set_bytes": counters.WorkingSetSize,
                "peak_working_set_bytes": counters.PeakWorkingSetSize, "private_bytes": counters.PrivateUsage,
                "pagefile_usage_bytes": counters.PagefileUsage, "peak_pagefile_usage_bytes": counters.PeakPagefileUsage}
    return sample


def execute(engine, arguments, folder, settings, timeout):
    folder.mkdir(parents=True, exist_ok=True)
    env = {key: value for key, value in os.environ.items() if not key.upper().startswith("CYBERSAND_")}
    local_settings = dict(settings, CYBERSAND_SOURCE_REVISION=SOURCE, CYBERSAND_SOURCE_SHA=SOURCE)
    for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = folder / "profile" / name
        path.mkdir(parents=True)
        local_settings[name] = str(path)
    env.update(local_settings)
    command = [str(engine), *arguments]
    started_utc = datetime.datetime.now(datetime.timezone.utc).isoformat()
    started = time.monotonic()
    samples, timed_out = [], False
    sample = windows_memory_sampler()
    with (folder / "stdout.log").open("wb") as out, (folder / "stderr.log").open("wb") as err:
        with subprocess.Popen(command, cwd=engine.parent, env=env, stdout=out, stderr=err,
                              creationflags=subprocess.CREATE_NO_WINDOW) as process:
            while process.poll() is None:
                elapsed = time.monotonic() - started
                if elapsed > timeout:
                    timed_out = True
                    subprocess.run([str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe"),
                                    "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=15, check=False)
                    break
                value = sample(process, elapsed * 1000)
                if value is not None:
                    samples.append(value)
                time.sleep(0.25)
            exit_code = process.wait(timeout=15)
            pid = process.pid
    record = {"command": command, "environment": local_settings, "source_commit": SOURCE,
              "started_utc": started_utc,
              "elapsed_seconds": time.monotonic() - started, "exit_code": exit_code, "timed_out": timed_out,
              "application_pid": pid, "receipt_pid_matched": None, "memory_samples": len(samples),
              "peak_working_set_bytes": max((s["peak_working_set_bytes"] for s in samples), default=None),
              "sampled_peak_private_bytes": max((s["private_bytes"] for s in samples), default=None),
              "memory_scope": "250ms samples of the directly launched Godot GUI PID, including setup and capture. Peak working set is the OS lifetime counter; private peak is only sampled. Valid only after exact receipt PID match. Logical video accounting does not measure retired driver storage."}
    write_json(folder / "process.json", record)
    write_json(folder / "process-memory.json", samples)
    logs = "\n".join((folder / name).read_text(encoding="utf-8-sig", errors="replace")
                     for name in ("stdout.log", "stderr.log", "godot.log") if (folder / name).is_file())
    logs = re.sub(r"\x1b\[[0-9;]*m", "", logs)
    need(not timed_out and exit_code == 0 and not any(ERRORS.match(line) for line in logs.splitlines()), "Godot process incomplete or reported runtime errors: " + str(folder))
    return record


def match_pid(record, value, folder):
    record["receipt_pid_matched"] = record["application_pid"] == value
    if not record["receipt_pid_matched"]:
        record["peak_working_set_bytes"] = record["sampled_peak_private_bytes"] = None
    write_json(folder / "process.json", record)
    need(record["receipt_pid_matched"] and record["memory_samples"] > 0, "Actual Godot PID/memory sample identity differs")


def check_warp(platform_name, driver, adapter):
    need(platform_name == "Windows" and driver == "opengl3_angle" and
         all(part in adapter.lower() for part in ("microsoft basic render driver", "direct3d11")),
         "This preregistered experiment requires actual Windows ANGLE D3D11 WARP")


def check_submission(value, strategy, arm):
    check_material_status(value, arm, POLICY)
    need(value.get("mode") == "full" and value.get("full_storage_strategy") == strategy and value.get("full_descriptor_valid"),
         "Observed full-only storage treatment differs")
    need(value["full_current_rid"] > 0 and value["full_previous_rid"] > 0 and value["full_current_rid"] != value["full_previous_rid"],
         "History RIDs alias or are invalid")
    need(value["full_storage_creations"] == value["full_storage_replacements"] == int(strategy == "set_image"), "Fresh storage creation count differs")
    need(value["image_detach_usec"] >= 0 and value["texture_api_usec"] >= 0 and
         value["backend_submit_usec"] >= value["image_detach_usec"] + value["texture_api_usec"], "Split clocks exceed the retained aggregate")


def read_oracle(path, campaign, expected, strategy, record, nonce):
    data = json.loads(path.read_text())
    context, arm = data["context"], campaign["arms"]["C"]
    check_warp(context["platform"], context["backend"], context["video_adapter"])
    need(context["source_revision"] == SOURCE and context["engine_sha256"] == ENGINE_SHA256 and
         context["fixture"] == "res://" + ORACLE and context["fixture_sha256"] == expected[ORACLE] and
         context["nonce"] == nonce and context["execution_policy"]["ok"] and context["display_server"] != "headless" and
         context["godot"]["hash"] == "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" and
         data["application_main_sha256"] == expected[MAIN], "Oracle source/runtime/fixture identity differs")
    match_pid(record, context["process_id"], path.parent)
    need(data["schema"] == "pubpres-source-transition-history-v1" and data["complete"] and not data["failures"] and
         data["frames_checked"] == data["current_matches"] == data["previous_matches"] == len(data["admissions"]) == 180 and
         data["sparse_entries"] == len(data["entry_history"]) == 15 and data["tape"] == "transition", "Both complete histories did not pass every revision")
    case = campaign["transition_case"]
    need(data["initial_plane_sha256"] == case["initial_plane_sha256"], "Initial history bytes differ")
    for section in ("history", "warmup_history"):
        for key in ("current_sha256", "previous_sha256"):
            need(data[section][key] == case[section][key], "Retained complete history sequence differs")
    pair = None
    for index, row in enumerate(data["admissions"]):
        need(row["sequence"] == index + 30 and row["revision"] == index + 31 and row["current_matches"] and row["previous_matches"], "Missing oracle admission")
        check_submission(row["material"], strategy, arm)
        value = (row["material"]["full_current_rid"], row["material"]["full_previous_rid"])
        need(pair is None or value == pair[::-1], "The same two full texture targets did not alternate")
        pair = value
    return {"strategy": strategy, "current_matches": 180, "previous_matches": 180, "entry_history": data["entry_history"],
            "history": data["history"], "warmup_history": data["warmup_history"], "context": context, "receipt_sha256": digest(path), "process": record}


def full_stages(path, stats, strategy, campaign):
    events = [json.loads(line) for line in path.with_name(path.stem + "-events.jsonl").read_text().splitlines()]
    uploads = [row for row in events if row["event"] == "texture_upload"]
    pair = None
    for row in uploads:
        value = row["material"]
        check_submission(value, strategy, campaign["arms"]["C"])
        current = (value["full_current_rid"], value["full_previous_rid"])
        need(pair is None or current == pair[::-1], "Gameplay did not retain alternating history RIDs")
        pair = current
    result = {}
    for name, window in stats["windows"].items():
        selected = [r for r in uploads if window["start_usec"] <= r["time_usec"] <= window["end_usec"]]
        result[name] = {"uploads": len(selected),
                        "stages_usec": {key: distribution(r["material"][key] for r in selected)
                                        for key in ("image_detach_usec", "texture_api_usec", "backend_submit_usec")},
                        "fresh_storage_creations": sum(r["material"]["full_storage_creations"] for r in selected),
                        "fresh_storage_replacements": sum(r["material"]["full_storage_replacements"] for r in selected),
                        "worst_api_calls": sorted(({"api_usec": r["material"]["texture_api_usec"], "detach_usec": r["material"]["image_detach_usec"],
                                                   "start_usec": r["start_usec"], "end_usec": r["time_usec"], "process_frame": r["process_frame"],
                                                   "render_serial": r["render_serial"], "tick_index": r["tick_index"]} for r in selected),
                                                  key=lambda r: r["api_usec"], reverse=True)[:12]}
    return result


def run(args):
    need(os.name == "nt", "Run the retained Windows executable on Windows")
    installed, output = args.installed.resolve(), args.output.resolve()
    need(not output.exists(), "Preserve original results: choose a new output directory")
    need(digest(installed / MANIFEST) == MANIFEST_SHA256, "Wrong retained673 package manifest")
    manifest = verify(installed, SOURCE)
    need(digest(installed / GUI) == ENGINE_SHA256 and digest(installed / "godot" / MAIN) == MAIN_SHA256, "Wrong retained engine or actual Main")
    campaign = json.loads(args.campaign.read_text())
    need(campaign["schema"] == "pubpres-source-campaign-v1", "Unknown registered gameplay campaign")
    arm = campaign["arms"]["C"]
    need(arm["material"] == "blit" and arm["physics"] == "early" and arm["presentation"] == "coherent" and
         arm["timing"] == "measured" and arm["cadence"] == "repaired" and arm["rendezvous"] == "0", "Registered selectors changed")
    cases = [r for r in campaign["cases"] if r["id"] in ("needle_wave_follow_landscape_w4", "needle_wave_follow_2048_w4")]
    need(len(cases) == 2 and all(r["workers"] == 4 and r["camera"] == "follow" and r["water_law"] == "wave_flow_v1" for r in cases), "Registered Wave Follow cases changed")
    inputs = {GAMEPLAY: args.gameplay, TRANSITION: args.transition, ORACLE: args.oracle}
    for name, source in inputs.items():
        expected_hash = (campaign["overlay_sha256"] if name == GAMEPLAY else campaign["transition_overlay_sha256"])[name]
        need(digest(source) == expected_hash, "Registered common fixture changed: " + name)
    for name, value in campaign["overlay_sha256"].items():
        if name != GAMEPLAY:
            need(digest(installed / "godot" / name) == value, "Retained setup/source fixture differs: " + name)
    output.mkdir(parents=True)
    shutil.copyfile(installed / MANIFEST, output / "package-manifest.json")
    shutil.copyfile(args.campaign, output / "source_campaign.json")
    shutil.copyfile(Path(__file__), output / "runner.py")
    expected = {name.removeprefix("godot/"): value for name, value in manifest["files_sha256"].items() if name.startswith("godot/")}
    originals = {MAIN: (installed / "godot" / MAIN).read_bytes(), **{name: source.read_bytes() for name, source in inputs.items()}}
    overlays = dict(originals, **{MAIN: main_overlay(originals[MAIN]), ORACLE: oracle_overlay(originals[ORACLE])})
    source_folder = output / "observation-source"
    for name, value in overlays.items():
        path = source_folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)
        expected[name] = hashlib.sha256(value).hexdigest()
        if originals[name] != value:
            patch = "".join(difflib.unified_diff(originals[name].decode().splitlines(keepends=True), value.decode().splitlines(keepends=True),
                                                fromfile="a/" + name, tofile="b/" + name))
            (output / (Path(name).stem + "-overlay.patch")).write_text(patch, encoding="utf-8")
    write_json(output / "expected-project-sha256.json", expected)
    plan = {"schema": "pubpres-full-storage-plan-v1", "registered_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "hypothesis": "The actual full-only RG8 ImageTexture.update wait observed in source673 Wave Follow blocks Main and authoritative physical admission. Fresh same-descriptor set_image may avoid updating busy sampled storage; later draw/API waits and process memory can negate the benefit.",
            "source": SOURCE, "package_manifest_sha256": MANIFEST_SHA256, "original_main_sha256": MAIN_SHA256,
            "engine_sha256": ENGINE_SHA256, "overlay_sha256": {name: expected[name] for name in overlays},
            "main_overlay_patch_sha256": digest(output / "main-overlay.patch"), "oracle_overlay_patch_sha256": digest(output / "pubpres_source_transition_oracle-overlay.patch"),
            "campaign_sha256": digest(args.campaign), "runner_sha256": digest(Path(__file__)), "strategies": STRATEGIES,
            "order_per_world": list("ABBA"), "cases": cases, "selectors": arm, "render_thread": "safe", "driver": "opengl3_angle",
            "oracle_gate": "Both separate 180-current/180-previous complete GPU readbacks, stable alternating RIDs and explicit GPU RG8/no-mipmaps before any timed gameplay.",
            "descriptor_scope": "Both arms stamp construction provenance from actual pair initialization Images (including structural recovery), then validate detached R8/RG8/no-mips and cached destination dimensions. No timed GPU readback.",
            "memory_scope": "Actual direct Godot PID working-set and private-byte samples every250ms, plus OS peak working-set counter; Godot static peak and logical final video memory. Driver-retired memory is not established by logical texture counts.",
            "cache_policy": "Fresh copied project, process, profile and shader nonce per arm; process-independent driver caches uncontrolled and order-balanced.",
            "import_metadata_policy": "After editor import, preserve observed bytes and restore only exact CRLF-to-LF rewrites of the four named Rapier icon import descriptors from the pinned originals. Then enforce the unchanged complete expected hash map. Missing files or any other drift fail.",
            "meaning": "Capture completion is not a performance win. Compare both repeats, all fixed windows, frame/native/physical tails and freshness. This software WARP experiment cannot qualify physical Windows/NVIDIA acceptance.",
            "host": {"platform": platform.platform(), "processor": platform.processor(), "logical_processors": os.cpu_count()}}
    write_json(output / "plan.json", plan)
    results, oracles, failures = [], [], []
    projects = output / "projects"
    template = projects / "template"
    try:
        copy_project(installed / "godot", template)
        for name, value in overlays.items():
            (template / name).parent.mkdir(parents=True, exist_ok=True)
            (template / name).write_bytes(value)
        require_project_identity(template, expected, "Prepared project differs outside declared overlays")
        print("Importing retained673 with identical bounded full-storage overlay", flush=True)
        execute(installed / GUI, ["--headless", "--path", str(template), "--audio-driver", "Dummy", "--log-file", str(output / "import/godot.log"),
                                 "--editor", "--import"], output / "import", {}, 300)
        restore_import_newlines(template, installed, expected, output / "import-newline-restoration")
        settings_base = {"CYBERSAND_MATERIAL_PUBLICATION": arm["material"], "CYBERSAND_DIAG_PHYSICS_PUBLICATION": arm["physics"],
                         "CYBERSAND_DIAG_PRESENTATION": arm["presentation"], "CYBERSAND_DIAG_MATERIAL_TIMING": arm["timing"],
                         "CYBERSAND_DIAG_RENDER_CADENCE": arm["cadence"], "CYBERSAND_DIAG_NATIVE_RENDEZVOUS": arm["rendezvous"],
                         "CYBERSAND_DIAG_COMMON_OBSERVER": "0", "CYBERSAND_SHADER_CACHE_STATE": "isolated-project-and-profile"}
        jobs = [("oracle-" + letter, letter, None) for letter in "AB"] + [(case["id"] + "/" + str(i) + "-" + letter, letter, case) for case in cases for i, letter in enumerate("ABBA")]
        for label, letter, case in jobs:
            if case is not None:
                need(len(oracles) == 2, "Both history oracles must pass before timing")
            folder = output / label
            project = projects / label.replace("/", "-")
            copy_project(template, project, imported=True)
            require_project_identity(project, expected, "Fresh process source differs")
            nonce = uuid.uuid4().hex
            settings = dict(settings_base, **{SWITCH: STRATEGIES[letter], "CYBERSAND_SHADER_NONCE": nonce})
            receipt = folder / "receipt.json"
            script = ORACLE if case is None else GAMEPLAY
            command = ["--path", str(project), "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle", "--render-thread", "safe",
                       "--audio-driver", "Dummy", "--log-file", str(folder / "godot.log"), "--script", "res://" + script, "--", f"--receipt={receipt}"]
            command += ["--material=blit"] if case is None else [f"--fixture={case['fixture']}", "--camera=follow", "--workers=4", "--water-law=wave_flow_v1"]
            print(label + " | " + STRATEGIES[letter], flush=True)
            record = execute(installed / GUI, command, folder, settings, 600 if case is None else 900)
            require_project_identity(project, expected, "Executed source/runtime changed")
            if case is None:
                oracles.append(read_oracle(receipt, campaign, expected, STRATEGIES[letter], record, nonce))
            else:
                data = json.loads(receipt.read_text())
                check_warp(data["platform"], data["renderer"], data["adapter"])
                need(data["source_identity"]["source_sha"] == SOURCE and data["case_nonce"] == nonce and
                     data["fixture"]["name"] == case["fixture"] and data["workers"] == 4 and data["camera"] == "follow" and data["water_law"] == "wave_flow_v1", "Actual gameplay case or source changed")
                match_pid(record, data["process_id"], folder)
                stats = reduce_receipt(receipt, campaign, project, installed / GUI, "C")
                stages = full_stages(receipt, stats, STRATEGIES[letter], campaign)
                write_json(folder / "analysis.json", stats)
                write_json(folder / "full-storage-stages.json", stages)
                results.append({"case": case["id"], "arm": letter, "strategy": STRATEGIES[letter], "folder": label,
                                "receipt_sha256": digest(receipt), "process": record, "statistics": stats, "full_storage": stages})
            write_json(output / "summary.json", {"complete": False, "physical_acceptance": "HOLD", "oracles": oracles, "arms": results, "failures": failures})
            shutil.rmtree(project)
        for case in cases:
            rows = [r for r in results if r["case"] == case["id"]]
            need([r["arm"] for r in rows] == list("ABBA"), "Incomplete balanced gameplay comparison")
            need(all(canonical(r["statistics"]["match"]) == canonical(rows[0]["statistics"]["match"]) for r in rows), "Hardware/display/fixture/policy or workload differs within ABBA")
            need(len({r["statistics"]["first_144_body_trajectory_sha256"] for r in rows}) == 1, "Actual first144 physical body trajectory differs within ABBA")
        need(oracles[0]["entry_history"] == oracles[1]["entry_history"], "History re-entry bytes differ between treatments")
    except Exception as error:
        failures.append(str(error))
        print("Incomplete; original evidence retained: " + str(error), flush=True)
    finally:
        try:
            need(digest(installed / MANIFEST) == MANIFEST_SHA256, "Installed manifest changed")
            verify(installed, SOURCE)
        except Exception as error:
            failures.append(str(error))
        complete = not failures and len(oracles) == 2 and len(results) == 8
        write_json(output / "summary.json", {"schema": "pubpres-full-storage-comparison-v1", "complete": complete,
                                            "physical_acceptance": "HOLD", "oracles": oracles, "arms": results, "failures": failures,
                                            "meaning": plan["meaning"], "plan_sha256": digest(output / "plan.json")})
        lines = ["Full-only texture storage comparison complete: " + str(complete) + "; physical acceptance HOLD.",
                 "A=ImageTexture.update; B=ImageTexture.set_image. Same detached R8/RG8 payload, source673, actual WARP full policy. ABBA per World.", plan["meaning"]]
        for result in results:
            for name, value in result["statistics"]["windows"].items():
                def values(key):
                    return "/".join(f"{value[key][q]:.3f}" for q in ("p50", "p95", "p99", "max"))
                lines.append(f"{result['folder']} {name}: frame {values('frame_ms')} ms; physical {values('physical_gap_ms')} ms; native {values('native_observed_gap_ms')} ms; ticks {value['native_ticks_per_second']:.2f}/s; steps {value['rapier_steps_per_second']:.2f}/s")
            lines.append(f"  PID-matched peak working set {result['process']['peak_working_set_bytes']} B; sampled peak private {result['process']['sampled_peak_private_bytes']} B")
        lines.extend("INCOMPLETE: " + error for error in failures)
        (output / "READ-RESULTS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
        if complete:
            shutil.rmtree(projects)
    return 0 if complete else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("installed", "output", "gameplay", "transition", "oracle", "campaign"):
        parser.add_argument("--" + name, type=Path, required=True)
    return run(parser.parse_args())


if __name__ == "__main__":
    sys.exit(main())
