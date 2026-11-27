"""Recheck original accepted-main and owner-launch evidence before publication."""
from __future__ import annotations

import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import struct
import sys
import zlib

import runtime_custody as custody
import accepted_main_smokes as smokes
from shared import legacy, load
from run_workbench_qualification import completion, ERRORS

FLATTEN = load("swarm456_flatten_original_validators", "tools/ci/gen008_flatten_runtime_publication.py")
_path = sys.path[:]
try:
    sys.path.insert(0, str(custody.ROOT / "tools/swarm006"))
    DISPATCH = load("swarm456_owner_original_validator", "tools/swarm006/owner_dispatch.py")
finally:
    sys.path[:] = _path

SMOKE_CASES = (
    ("import", None, None, False),
    ("workbench-canvas", "test_workbench_canvas", "WORKBENCH_CANVAS", False),
    ("workbench-wave", "test_workbench_wave", "WORKBENCH_WAVE_RESULT", True),
    ("paint-workbench-author", "test_paint_editor_workbench", "PAINT_EDITOR_WORKBENCH", True),
    ("paint-workbench-reopen", "test_paint_editor_workbench", "PAINT_EDITOR_WORKBENCH", True),
    ("paint-generated-author", "test_paint_editor_generated_workbench", "PAINT_EDITOR_GENERATED_WORKBENCH", True),
    ("paint-generated-reopen", "test_paint_editor_generated_workbench", "PAINT_EDITOR_GENERATED_WORKBENCH", True),
    ("art-provider", "test_art_provider", "ART_PROVIDER_KEYLESS", False),
    ("art-receipt-identity", "test_art_history_receipt_identity", "ART_HISTORY_RECEIPT_IDENTITY_RESULT", False),
    ("art-durability", "test_art_history_durability", "ART_HISTORY_SESSION_RESULT", False),
    ("art-native-render", "test_art_batch_native_render", "ART_STAGE1_RESULT", True),
    ("art-undo", "test_art_undo", "ART_UNDO_RESULT", False),
    ("actors-session", "test_workbench_actor_composition_session", "Workbench actor composition session:", False),
    ("actors-native", "test_workbench_actor_composition_native", "Workbench actor composition native:", False),
    ("actors-author", "test_workbench_actor_composition", "WB_ACTOR_COMPOSE", True),
    ("actors-reopen", "test_workbench_actor_composition", "WB_ACTOR_COMPOSE", True),
)
WATER_SECTIONS = {"activation", "parameters", "workers_substeps", "runtime_apply", "regeneration", "scenario_change",
                  "pause_resume", "invalid_recovery", "solver_switch", "comparison_scenes", "native_validation", "failure_recovery"}


def retained_text(directory: Path, name: str) -> str:
    path = directory / name
    custody.require(path.is_file() and not path.is_symlink() and path.stat().st_size > 0,
                    "Original named evidence is absent: " + name)
    return path.read_text(encoding="utf-8", errors="replace")


def process_log(directory: Path, row: dict) -> str:
    label = row.get("label", "")
    custody.require(isinstance(label, str) and re.fullmatch(r"[A-Za-z0-9_-]+", label)
                    and row.get("status") == "passed" and type(row.get("exit_code")) is int
                    and row["exit_code"] == 0 and not any(key in row for key in ("error", "failure", "cleanup_failure"))
                    and row.get("returncode", 0) == 0
                    and row.get("timed_out", False) is False and row.get("cancelled", False) is False
                    and row.get("validation_errors", []) == [], "Original smoke process failed: " + str(label))
    text = retained_text(directory, label + ".log")
    custody.require(not ERRORS.search(text), "Original smoke log contains a script failure: " + label)
    return text


def original_completion(text: str, marker: str) -> dict:
    custody.require(sum(line.startswith(marker + " ") for line in text.splitlines()) == 1,
                    "Original completion is absent or duplicated: " + marker)
    return completion(text, marker)


def godot_command(row: dict, platform: str, script: str | None, graphical: bool) -> tuple[str, str]:
    command = row.get("command", [])
    custody.require(isinstance(command, list) and all(isinstance(x, str) for x in command)
                    and len(command) > 4 and command.count("--path") == 1,
                    "Smoke lacks its original Godot command")
    engine = (PureWindowsPath if platform == "windows" else PurePosixPath)(command[0])
    custody.require(engine.is_absolute() and engine.name in (
        ("Godot_v4.7-stable_win64_console.exe", "Godot_v4.7-stable_win64.exe") if platform == "windows"
        else ("Godot_v4.7-stable_linux.x86_64",)), "Smoke used another engine executable")
    if script:
        custody.require(command.count("--script") == 1 and command[command.index("--script") + 1] == "res://tests/" + script + ".gd",
                        "Smoke executed another fixture")
    else:
        custody.require("--script" not in command and "--editor" in command and "--quit" in command,
                        "Import did not execute its original editor command")
    custody.require(("--headless" not in command) is graphical, "Smoke graphics mode differs from its required case")
    if graphical:
        driver = "opengl3_angle" if platform == "windows" else "x11"
        custody.require(driver in command and "gl_compatibility" in command, "Smoke lacks the target graphical driver")
    return command[0], command[command.index("--path") + 1]


def validate_flatten(directory: Path, value: dict, receipt: dict) -> None:
    platform = receipt["platform"]
    rows = json.loads(retained_text(directory, "results.json"))
    labels = ["flatten-import", "standalone-format-adversarial", "side-512-workers-1-author",
              "side-512-workers-1-reopen", "owner-failure-author", "owner-failure-reopen"]
    custody.require(isinstance(rows, list) and [row.get("label") for row in rows] == labels,
                    "Flatten original process inventory is incomplete")
    summary = legacy.read_report(directory / "qualification.json")
    custody.require(summary == {"status": "passed", "cases": [[512, 1]], "graphical": True,
                                "storage_faults": FLATTEN.verify_storage_faults(directory, platform)},
                    "Flatten original qualification or actual OS storage-fault evidence failed")
    native = receipt["files"][receipt["extension"]]["sha256"]
    normal = []
    for index, row in enumerate(rows):
        text = process_log(directory, row)
        custody.require(row.get("engine_executable_sha256") == value.get("godot_engine_sha256")
                        and re.fullmatch(r"[0-9a-f]{64}", str(value.get("godot_engine_sha256", "")))
                        and row.get("measurement_target") == "godot-engine-process"
                        and type(row.get("pid")) is int and row["pid"] > 0
                        and type(row.get("sampled_peak_rss_bytes")) is int and row["sampled_peak_rss_bytes"] > 0
                        and type(row.get("os_peak_rss_bytes")) is int and row["os_peak_rss_bytes"] > 0,
                        "Flatten process/engine/RSS identity is incomplete")
        custody.require(row.get("command", [None])[0] == row.get("engine_executable")
                        and PureWindowsPath(row["engine_executable"]).name == ("Godot_v4.7-stable_win64.exe" if platform == "windows"
                                                                                 else "Godot_v4.7-stable_linux.x86_64"),
                        "Flatten did not measure its original pinned engine process")
        if index == 0:
            godot_command(row, platform, None, False)
        elif index == 1:
            godot_command(row, platform, "test_workbench_material_baseline", False)
            custody.require(original_completion(text, "WORKBENCH_MATERIAL_BASELINE") == row.get("completion"),
                            "Flatten format receipt differs from its original log")
        elif index < 4:
            godot_command(row, platform, "test_workbench_flatten", True)
            phase = "author" if index == 2 else "reopen"
            result = original_completion(text, "FLATTEN_RESULT")
            custody.require(result == row.get("completion") and result.get("completed") is True
                            and result.get("phase") == phase and result.get("side") == 512 and result.get("workers") == 1
                            and result.get("canonical_bytes") == 524288 and result.get("pid") == row["pid"],
                            "Flatten complete original receipt differs")
            identity = result.get("source_identity", {})
            custody.require(identity.get("native_sha256") == native and identity.get("os") == ("Windows" if platform == "windows" else "Linux")
                            and identity.get("display", "").lower() == ("windows" if platform == "windows" else "x11")
                            and identity.get("godot") == FLATTEN.workbench.GODOT_DISPLAY_VERSION
                            and all(identity.get(path) == custody.sha(custody.ROOT / "godot" / path) for path in FLATTEN.SOURCE_PATHS),
                            "Flatten original source/runtime/graphical identity changed")
            phases = ({"startup", "generate", "construction", "simulation", "flatten_paused", "flatten_playing",
                       "post_flatten_history", "save", "complete", "failure_atomicity"} if phase == "author"
                      else {"startup", "reopen", "continued_authoring", "complete"})
            custody.require(all(result.get("phases", {}).get(name) is True for name in phases), "Flatten omitted an actual phase")
            witnesses = result.get("native_material_witnesses", [])
            custody.require(isinstance(witnesses, list) and witnesses
                            and all(isinstance(w, dict) and w.get("bytes") == 524288
                                    and re.fullmatch(r"[0-9a-f]{64}", str(w.get("sha256", ""))) for w in witnesses)
                            and len({w.get("label") for w in witnesses}) == len(witnesses), "Flatten native readback is incomplete")
            by_name = {w["label"]: w for w in witnesses}
            if phase == "author":
                required = {"before-simulation", "simulation-derived-materials", "after-flatten",
                            "post-flatten-edits-before-later-simulation", "later-simulation-excluded-from-save"}
                custody.require(required <= by_name.keys()
                                and by_name["before-simulation"]["sha256"] != by_name["simulation-derived-materials"]["sha256"]
                                and by_name["simulation-derived-materials"]["sha256"] == by_name["after-flatten"]["sha256"]
                                and by_name["post-flatten-edits-before-later-simulation"]["sha256"] != by_name["later-simulation-excluded-from-save"]["sha256"]
                                and all(by_name["simulation-derived-materials"].get(k) == by_name["after-flatten"].get(k)
                                        for k in ("generation", "native_generation", "tick", "revision")),
                                "Flatten raw native witnesses do not prove unchanged captured material")
            else:
                custody.require("fresh-process-reconstructed-plane" in by_name, "Flatten reopen omitted native readback")
            for name in (("flatten-identical-live-world.png", "flatten-explicitly-saved.png") if phase == "author"
                         else ("flatten-reopened-and-continued.png",)):
                custody.require(legacy.original_png(directory / (row["label"] + "-frames") / name), "Flatten original framebuffer is absent")
            custody.require(re.fullmatch(r"[0-9a-f]{32}", str(result.get("process_instance", ""))), "Flatten process identity is absent")
            normal.append(result)
        else:
            godot_command(row, platform, "test_workbench_flatten_owner_failure", True)
    custody.require(normal[0]["process_instance"] != normal[1]["process_instance"]
                    and normal[0]["pid"] != normal[1]["pid"] and normal[0]["source_identity"] == normal[1]["source_identity"],
                    "Flatten reopen reused a process or changed source/runtime")
    FLATTEN.verify_owner_failure_cases(directory, rows[4:], platform, native, custody.ROOT / "godot")


def validate_smokes(directory: Path, value: dict, receipt: dict) -> None:
    rows = json.loads(retained_text(directory, "results.json"))
    custody.require(rows == value.get("results") and [row.get("label") for row in rows] == list(smokes.REQUIRED),
                    "Smoke summary does not join the complete original process array")
    engine_project = None
    for row, (label, script, marker, graphical) in zip(rows, SMOKE_CASES):
        text = process_log(directory, row)
        pair = godot_command(row, receipt["platform"], script, graphical)
        engine_project = engine_project or pair
        custody.require(pair == engine_project, "Smoke changed its engine or source project")
        if marker:
            if label == "workbench-wave":
                original = smokes.wave_result(text, receipt["platform"])
            elif label == "art-durability":
                original = smokes.art_session_history_result(text)
            else:
                original = original_completion(text, marker)
            custody.require(original == row.get("completion"), "Smoke summary differs from original assertion receipt: " + label)
            if label == "workbench-wave":
                custody.require(set(original.get("sections", {})) == WATER_SECTIONS, "Water omitted a required actual Workbench section")
            if label.startswith("paint-"):
                custody.require(original.get("reopen") == ("1" if label.endswith("reopen") else "0")
                                and (not label.startswith("paint-generated") or original.get("completed") is True),
                                "Paint did not complete the requested author/reopen phase")
            if label.startswith("actors-") and label in ("actors-author", "actors-reopen"):
                custody.require(original == legacy.read_report(directory / (label + ".json"))
                                and original.get("headless") is False and original.get("preservation_notes") == []
                                and "SKIP WB_ACTOR_COMPOSE" not in text and bool(original.get("screenshots")),
                                "Actor graphical report is incomplete or differs from original log")
                for shot in original["screenshots"]:
                    name = PureWindowsPath(shot["path"]).name
                    custody.require(name.endswith(".png") and legacy.original_png(directory / (label + "-frames") / name),
                                    "Actor original framebuffer is absent")
        if label == "workbench-canvas":
            custody.require("skipped" not in text.lower(), "Canvas execution preserved unrelated user state")
    for folder, names in (("paint-workbench-frames", ("paint001-mixed-stamp-preview.png", "paint001-mounted-editor.png")),
                          ("paint-generated-frames", ("paint001-generated-authored.png", "paint001-generated-reopened.png")),
                          ("art-frames", ("native-material-readback.png", "stage1.png", "stage1-1280.png"))):
        for name in names:
            custody.require(legacy.original_png(directory / folder / name, 1 if name.startswith("native-") else 512),
                            "Original Paint/Art framebuffer is absent: " + name)
    process_log(directory, rows[-1])
    command = rows[-1].get("command", [])
    custody.require(len(command) >= 4 and PureWindowsPath(command[1]).name == "run_flatten_qualification.py"
                    and "--cases" in command and command[command.index("--cases") + 1] == "512x1"
                    and "--headless" not in command, "Smoke did not execute the actual scoped Flatten child")
    validate_flatten(directory / "flatten", value, receipt)


def owner_png(path: Path) -> dict:
    custody.require(legacy.original_png(path, 1), "Owner screenshot is not an original complete PNG")
    data = path.read_bytes()
    width, height, depth, kind, compression, filtering, interlace = struct.unpack(">IIBBBBB", data[16:29])
    custody.require(640 <= width <= 2560 and 360 <= height <= 1440 and (depth, kind, compression, filtering, interlace) == (8, 2, 0, 0, 0),
                    "Owner screenshot differs from the bounded actual Windows RGB capture")
    offset, encoded = 8, bytearray()
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b"IDAT": encoded.extend(data[offset + 8:offset + 8 + size])
        offset += size + 12
    expected = height * (1 + width * 3)
    decoder = zlib.decompressobj()
    raw = decoder.decompress(bytes(encoded), expected + 1)
    custody.require(len(raw) == expected and decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail
                    and all(raw[y * (width * 3 + 1)] == 0 for y in range(height)), "Owner screenshot raw pixels changed")
    rgb = b"".join(raw[y * (width * 3 + 1) + 1:(y + 1) * (width * 3 + 1)] for y in range(height))
    step = max(1, width * height // 8192)
    colors = len({rgb[i * 3:i * 3 + 3] for i in range(0, width * height, step)})
    return {"file": path.name, "sha256": custody.sha(path), "width": width, "height": height, "distinct_sampled_colors": colors}


def validate_owner_launcher(evidence: Path, graphical: dict, receipt: dict) -> dict:
    directory = evidence / "windows-launcher"
    value = legacy.read_report(directory / "owner-launcher-qualification.json")
    seal = legacy.read_report(evidence / "windows-package-seal.json")
    original_files = custody.inventory(directory)
    original_files.pop("owner-launcher-qualification.json", None)
    custody.require(value.get("files_sha256") == original_files, "Owner original evidence inventory changed or is incomplete")
    cases = (("direct-inner-archive", True, ""), ("github-nested-artifact", True, ""),
             ("stale-destination", False, "Destination already exists"), ("corrupted-archive", False, "ZIP SHA-256 mismatch"),
             ("wrong-sidecar-name", False, "sidecar does not name"), ("missing-sidecar", False, "Missing separate SHA-256 sidecar"))
    rows = value.get("results", [])
    custody.require([r.get("case") for r in rows] == [name for name, _, _ in cases] + ["actual-owner-graphical-dispatch"]
                    and receipt.get("platform") == "windows" and value.get("source_commit") == receipt["source_commit"] and value.get("passed") is True
                    and value.get("platform") == "Windows" and value.get("graphical_dispatch_passed") is True
                    and value.get("graphical_qualification") is False
                    and value.get("owner_nvidia_acceptance") == "pending"
                    and value.get("archive_sha256") == graphical.get("package_zip_sha256") == seal.get("archive_sha256")
                    and value.get("launcher_sha256") == seal.get("launcher_sha256") and seal.get("source_commit") == receipt["source_commit"],
                    "Owner launcher/source/archive qualification differs")
    for row, (name, success, reason) in zip(rows, cases):
        text = retained_text(directory, name + ".log")
        custody.require(row.get("passed") is True and row.get("expected_success") is success
                        and type(row.get("returncode")) is int and ((row["returncode"] == 0) is success)
                        and row.get("log_sha256") == custody.sha(directory / (name + ".log"))
                        and (reason in text if reason else receipt["source_commit"] in text),
                        "Owner original launcher process/refusal log failed: " + name)
    root = directory / "dispatch"
    path = root / "owner-dispatch-qualification.json"
    dispatch = legacy.read_report(path)
    custody.require(rows[-1].get("passed") is True and rows[-1].get("expected_success") is True
                    and rows[-1].get("evidence") == "dispatch/owner-dispatch-qualification.json"
                    and rows[-1].get("evidence_sha256") == custody.sha(path)
                    and dispatch.get("passed") is True and dispatch.get("validation_errors") == []
                    and dispatch.get("owner_nvidia_acceptance") == "pending"
                    and not any(key in dispatch for key in ("failure", "cleanup_failure", "log_failure"))
                    and dispatch.get("source_commit") == receipt["source_commit"]
                    and dispatch.get("archive_sha256") == seal["archive_sha256"]
                    and dispatch.get("launcher_sha256") == seal["launcher_sha256"]
                    and dispatch.get("manifest_sha256") == seal["manifest_sha256"]
                    and dispatch.get("manifest_sha256") == graphical.get("execution_layout", {}).get("manifest_sha256")
                    and dispatch.get("engine_sha256") == graphical.get("execution_layout", {}).get("files_sha256", {}).get("Godot_v4.7-stable_win64.exe")
                    and dispatch.get("native_sha256") == receipt["files"][receipt["extension"]]["sha256"]
                    and dispatch.get("reciprocal_cli_sha256") == receipt["files"][receipt["cli"]]["sha256"]
                    and dispatch.get("test_sha256") == custody.sha(custody.ROOT / "tools/swarm006/owner_dispatch.py")
                    and dispatch.get("job_helper_sha256") == custody.sha(DISPATCH.JOB_HELPER),
                    "Owner original graphical dispatch source/runtime/process receipt failed")
    original_logs = dispatch.get("logs_sha256")
    custody.require(isinstance(original_logs, dict) and 0 < len(original_logs) <= 32, "Owner original log inventory is absent")
    log_hashes = {name.replace("\\", "/"): digest for name, digest in original_logs.items()}
    custody.require(len(log_hashes) == len(original_logs), "Ambiguous Windows owner log paths")
    custody.verify_inventory(root, log_hashes)
    actual_logs = {"owner-dispatch.log", *(p.relative_to(root).as_posix() for p in (root / "isolated profile with spaces").rglob("godot*.log"))}
    custody.require(set(log_hashes) == actual_logs, "Owner dispatch omitted an original startup log")
    logs = {name: retained_text(root, name) for name in log_hashes}
    custody.require("owner-dispatch.log" in logs and DISPATCH.MARKER in "\n".join(logs.values())
                    and f'Verified GENTEK-SWARM-006 source {receipt["source_commit"]};' in logs["owner-dispatch.log"],
                    "Owner original logs do not show verified source and Workbench launch")
    classified = DISPATCH.classify_startup_logs(logs)
    saved = {key: dispatch.get(key) for key in classified}
    for key in ("recovered_audio_diagnostics", "pending_audio_diagnostics"):
        normalized = []
        for record in saved.get(key) or []:
            source = str(record.get("source_log", "")).replace("\\", "/")
            matches = [name for name in logs if source == name or source.endswith("/" + name)]
            custody.require(len(matches) == 1, "Owner audio recovery refers to another original log")
            normalized.append({**record, "source_log": matches[0]})
        saved[key] = normalized
    custody.require(saved == classified and dispatch.get("screenshot") == owner_png(root / "owner-workbench-window.png"),
                    "Owner raw logs/audio or original framebuffer disagree with the dispatch receipt")
    errors = DISPATCH.evidence_errors(dispatch)
    custody.require(not errors, "Owner original dispatch validation failed: " + "; ".join(errors))
    return {"report": "windows-launcher/owner-launcher-qualification.json", "sha256": custody.sha(directory / "owner-launcher-qualification.json")}
