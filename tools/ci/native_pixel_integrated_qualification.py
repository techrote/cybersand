#!/usr/bin/env python3
"""Read-only #566 qualification of accepted main, camera and standalone authoring.

Privately compose the existing MAT/Workbench qualification profile and packager.
This entry point cannot publish runtimes, move refs, promote a PR or merge.
"""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BRANCH = "codex/native-pixel-scrolling-20261113"
WORKFLOW = ".github/workflows/native-pixel-integrated-qualification.yml"
ACCEPTED_MAIN = "ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742"
DISPATCH_WORKFLOWS = ("documentation.yml", "native.yml", "gdextension.yml", "palette-shader-qualification.yml")
CAMERA_LABELS = ["camera-import", "camera-coordinates", "camera-recording", "camera-framebuffer", "camera-effects",
                 "preserve-material_presentation", "preserve-water_presentation",
                 "preserve-material_vapour_pipeline", "preserve-palette_crossfade"]
PLAY_UI007_RIGS = ("acrobat", "arcadelander", "jetbarrel", "stuntbuggy", "trialsbike")
PLAY_UI007_LABELS = ["play-ui007-" + rig for rig in PLAY_UI007_RIGS]
# All five original graphical receipts from the repaired shared fixture have
# this count. Preserve their assertions field instead of manufacturing checks.
PLAY_UI007_ASSERTIONS = 71


def private_module(name: str, path: Path):
    spec = spec_from_file_location(name, path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


profile = private_module("_native_pixel_combined_profile", Path(__file__).with_name("mat_workbench_runtime_publication.py"))
engine = profile.engine
engine.BRANCH, engine.WORKFLOW = BRANCH, WORKFLOW
engine.EVIDENCE = "docs/audits/2026-11-13-native-pixel-final-integration.md"
engine.BUILD_EXACT |= {
    WORKFLOW, engine.EVIDENCE, "docs/audits/2026-11-13-native-pixel-scrolling.md", "tools/ci/native_pixel_integrated_qualification.py",
    "tools/ci/test_native_pixel_integrated_qualification.py", "tools/ci/check_windows_evaluation_zip.ps1",
    "tools/ci/run_integrated_camera_performance.py", "tools/ci/test_integrated_camera_performance.py",
}


def context(source: str) -> dict:
    engine.require(re.fullmatch(r"[0-9a-f]{40}", source) is not None, "Expected full source SHA")
    engine.require(engine.git("rev-parse", "HEAD").decode().strip() == source, "Checkout is not the qualified source")
    expected = {"GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_REF": "refs/heads/" + BRANCH,
                "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + BRANCH,
                "GITHUB_SHA": source}
    for key, value in expected.items():
        engine.require(os.environ.get(key) == value, "Unexpected qualification identity: " + key)
    engine.require(os.environ.get("GITHUB_EVENT_NAME") in {"push", "workflow_dispatch"}, "Expected explicit branch qualification")
    run, attempt = os.environ.get("GITHUB_RUN_ID", ""), os.environ.get("GITHUB_RUN_ATTEMPT", "")
    engine.require(run.isdecimal() and int(run) > 0 and attempt.isdecimal() and int(attempt) > 0, "Missing workflow identity")
    engine.git("merge-base", "--is-ancestor", ACCEPTED_MAIN, source)
    return {"source_commit": source, "source_tree": engine.git("rev-parse", source + "^{tree}").decode().strip(),
            "build_commit": source, "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" + run,
            "workflow_attempt": attempt}


# This private instance retains original assertion, runtime and receipt checks.
# Only its explicit, read-only qualification source context changes.
engine.context = context


def check_source(source: str) -> dict:
    identity = context(source)
    engine.require(engine.git("ls-remote", "--exit-code", "origin", "refs/heads/" + BRANCH).decode().strip() ==
                   source + "\trefs/heads/" + BRANCH, "Qualification branch moved")
    ledgers = engine.input_ledgers(source)
    # Published #565 native runtimes remain valid only while all actual native
    # inputs match. Fresh candidate builds do not rewrite retained provenance.
    for manifest in engine.MANIFESTS.values():
        retained = profile.read_json(ROOT / manifest)
        engine.require(retained["source_inputs"] == ledgers["source_inputs"], "Retained native inputs require separate publication")
    return identity | {"native_inputs": len(ledgers["source_inputs"]), "build_inputs": len(ledgers["build_inputs"])}


def camera_files(directory: Path) -> dict:
    return {p.relative_to(directory).as_posix(): engine.runner.sha256(p)
            for name in ("camera-source", "camera-installed", "camera-override")
            for p in sorted((directory / name).rglob("*")) if p.is_file()}


def play_ui007_command(godot: str, project: str, rig: str, platform: str) -> list[str]:
    command = [godot, "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility"]
    command += (["--rendering-driver", "opengl3_angle"] if platform == "windows" else ["--display-driver", "x11"])
    return command + ["--path", project, "--script", f"res://tests/test_play_ui007_{rig}_render.gd"]


def play_ui007_completion(log: Path, frames: Path, source: str, rig: str, platform: str) -> dict:
    """Re-read the original receipt and actual PNGs; never invent a checks count."""
    import run_workbench_qualification as wb
    text = log.read_text(encoding="utf-8", errors="replace")
    marker = "PLAY_UI007_RESULT "
    rows = [json.loads(line[len(marker):]) for line in text.splitlines() if line.startswith(marker)]
    engine.require(not wb.ERRORS.search(text) and len(rows) == 1, "Missing or failing PLAY_UI007 raw receipt")
    result = rows[0]
    engine.require(isinstance(result, dict) and result.get("schema") == "play-ui007-v1" and
                   result.get("source_revision") == source and result.get("rig") == rig and
                   str(result.get("display_server", "")).lower() == ("windows" if platform == "windows" else "x11") and
                   result.get("physics_engine") == "Rapier2D", "PLAY_UI007 source or graphical runtime differs")
    engine.require(type(result.get("assertions")) is int and result["assertions"] == PLAY_UI007_ASSERTIONS and
                   type(result.get("failures")) is int and result["failures"] == 0 and
                   all(result.get(key) is True for key in ("real_host", "automatic_callbacks", "worker_joined",
                                                         "session_retired", "graphical_capture_executed")) and
                   all(type(result.get(key)) is int and result[key] == 0 for key in ("manual_physics_calls", "retries")),
                   "PLAY_UI007 original assertions or real-owner teardown failed")
    row = result.get("row", {})
    engine.require(row.get("rig") == rig and row.get("completed") is True and
                   row.get("return_button_navigation") is True and
                   row.get("return_activation") == "actual_root_viewport_mouse_motion_press_release",
                   "PLAY_UI007 did not navigate through actual graphical Return input")
    focus, pointer = row.get("return_native_focus", {}), row.get("return_input", {})
    engine.require(focus.get("acknowledged") is True and focus.get("after_rendered_frame") is True and
                   pointer.get("hover_after_motion") is True and type(pointer.get("pressed_signals")) is int and
                   pointer["pressed_signals"] == 1,
                   "PLAY_UI007 native focus, hover or actual Button signal is missing")
    events = pointer.get("gui_events", [])
    engine.require(isinstance(events, list) and all(isinstance(item, dict) for item in events),
                   "PLAY_UI007 GUI event inventory is malformed")
    buttons = [item for item in events if item.get("kind") == "button"]
    motions = [item for item in events if item.get("kind") == "motion"]
    engine.require(bool(motions) and len(buttons) == 2 and
                   all(item.get("button_index") == 1 for item in buttons) and
                   buttons[0].get("pressed") is True and buttons[0].get("button_mask") == 1 and
                   buttons[1].get("pressed") is False and buttons[1].get("button_mask") == 0,
                   "PLAY_UI007 real GUI motion/press/release is incomplete")
    size = pointer.get("button_size", [])
    engine.require(isinstance(size, list) and len(size) == 2 and
                   all(type(value) in (int, float) and math.isfinite(value) and value > 0 for value in size),
                   "PLAY_UI007 button geometry is invalid")
    for event in [*motions, *buttons]:
        position = event.get("position", [])
        engine.require(isinstance(position, list) and len(position) == 2 and
                       all(type(value) in (int, float) and math.isfinite(value) and 0 <= value < size[axis]
                           for axis, value in enumerate(position)), "PLAY_UI007 GUI event missed the actual button")
    for camera in ("follow", "overview"):
        frame = row.get(camera + "_presentation", {})
        engine.require(frame.get("current_layout_acknowledged") is True and
                       frame.get("exact_published_layers_agree") is True and
                       type(frame.get("after_callback_exclusive")) is int and
                       type(frame.get("published_callback")) is int and
                       frame["published_callback"] > frame["after_callback_exclusive"] and
                       frame.get("presented_origin") is not None and
                       all(frame.get(key) == frame["presented_origin"]
                           for key in ("target_origin", "actor_origin", "terrain_origin")),
                       "PLAY_UI007 same-callback presentation is incomplete")
    captures = row.get("graphical_captures", [])
    engine.require(isinstance(captures, list) and [item.get("camera") for item in captures] == ["follow", "overview"],
                   "PLAY_UI007 needs both original graphical captures")
    for capture in captures:
        name = rig + "-" + capture["camera"] + ".png"
        path = frames / name
        # Resolve the expected retained file, never an absolute path from the
        # original machine. The raw path remains in the unmodified receipt.
        engine.require(str(capture.get("path", "")).replace("\\", "/").rsplit("/", 1)[-1] == name and
                       path.is_file() and engine.runner.sha256(path) == capture.get("sha256"),
                       "PLAY_UI007 original capture is missing or changed")
        header = path.read_bytes()[:24]
        engine.require(len(header) == 24 and header[:16] == b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR" and
                       struct.unpack(">II", header[16:24]) == (capture.get("width"), capture.get("height")) and
                       capture.get("width", 0) > 0 and capture.get("height", 0) > 0 and
                       capture.get("actor_parts", 0) > 0 and capture.get("identity", {}).get("rig") == rig,
                       "PLAY_UI007 capture dimensions or actual actor identity differ")
    return result


def play_ui007_runtime_files(godot: Path, project: Path, platform: str) -> dict:
    runtime = Path(engine.RUNTIMES[platform]).relative_to("godot")
    rapier = Path("addons/godot-rapier2d/bin") / ("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
              if platform == "windows" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
    engines = [godot]
    if platform == "windows":
        engine.require(godot.name.endswith("_console.exe"), "Expected the pinned Windows console launcher")
        engines.append(godot.with_name(godot.name.removesuffix("_console.exe") + ".exe"))
    return {"engine_files_sha256": {path.name: engine.runner.sha256(path) for path in engines},
            "runtime_files_sha256": {path.as_posix(): engine.runner.sha256(project / path) for path in (runtime, rapier)}}


def verify_play_ui007(evidence: Path, platform: str, source: str, camera_identity: dict, native_sha: str | None = None) -> None:
    identity = profile.read_json(evidence / "source-identity.json")
    engine.require(identity.get("schema") == "native-pixel-play-ui007-graphical-v1" and
                   identity.get("platform") == platform and identity.get("camera_source_identity") == camera_identity and
                   camera_identity.get("source_commit") == source,
                   "PLAY_UI007 source custody differs from the camera qualification")
    engine_name = str(camera_identity.get("godot", "")).replace("\\", "/").rsplit("/", 1)[-1]
    engine.require(identity.get("engine_files_sha256", {}).get(engine_name) == camera_identity.get("godot_sha256"),
                   "PLAY_UI007 engine custody differs from the camera qualification")
    if native_sha is not None:
        runtime = Path(engine.RUNTIMES[platform]).relative_to("godot").as_posix()
        engine.require(identity.get("runtime_files_sha256", {}).get(runtime) == native_sha,
                       "PLAY_UI007 native runtime differs from the qualified candidate")
    records = profile.verify_results(evidence / "results.json", PLAY_UI007_LABELS)
    for rig, record in zip(PLAY_UI007_RIGS, records):
        engine.require(record.get("command") == play_ui007_command(camera_identity["godot"], camera_identity["project"], rig, platform),
                       "PLAY_UI007 graphical wrapper command changed")
        raw = play_ui007_completion(evidence / (record["label"] + ".log"), evidence / "frames" / rig, source, rig, platform)
        engine.require(record.get("completion") == raw, "PLAY_UI007 result differs from its original raw receipt")


def play_ui007_cases(godot: Path, project: Path, evidence: Path, camera_identity: dict) -> None:
    import run_workbench_qualification as wb
    platform = "windows" if sys.platform == "win32" else "linux"
    engine.require(not evidence.exists(), "Do not overwrite earlier PLAY_UI007 evidence")
    runner = wb.Runner(argparse.Namespace(godot=godot, evidence=evidence))
    source = camera_identity["source_commit"]
    runner.env["CYBERSAND_SOURCE_REVISION"] = source
    engine.require(all(engine.runner.sha256(project / path) == digest
                       for path, digest in camera_identity["executed_source_sha256"].items()),
                   "PLAY_UI007 project source changed after the camera qualification")
    identity = {"schema": "native-pixel-play-ui007-graphical-v1", "platform": platform,
                "camera_source_identity": camera_identity, **play_ui007_runtime_files(godot, project, platform)}
    engine.write_json(runner.evidence / "source-identity.json", identity)
    failed = []
    for rig, label in zip(PLAY_UI007_RIGS, PLAY_UI007_LABELS):
        frames = runner.evidence / "frames" / rig
        try:
            runner.execute(label, play_ui007_command(str(godot.resolve()), str(project.resolve()), rig, platform),
                           env={"CYBERSAND_PLAY_UI007_CAPTURE_DIR": str(frames)},
                           validate=lambda: play_ui007_completion(runner.evidence / (label + ".log"), frames, source, rig, platform))
        except Exception as error:
            failed.append(label)
            print(f"FAIL {label}: {error}", flush=True)
    engine.require(play_ui007_runtime_files(godot, project, platform) ==
                   {key: identity[key] for key in ("engine_files_sha256", "runtime_files_sha256")},
                   "PLAY_UI007 engine or runtime changed during execution")
    engine.require(all(engine.runner.sha256(project / path) == digest
                       for path, digest in camera_identity["executed_source_sha256"].items()),
                   "PLAY_UI007 project source changed during execution")
    engine.require(not failed, "PLAY_UI007 graphical qualification failed: " + ", ".join(failed))
    verify_play_ui007(runner.evidence, platform, source, camera_identity)


def camera_cases(godot: Path, project: Path, evidence: Path) -> None:
    import run_workbench_qualification as wb
    wb.camera(argparse.Namespace(godot=godot, project=project, evidence=evidence))
    profile.verify_results(evidence / "results.json", CAMERA_LABELS)
    play_ui007_cases(godot, project, evidence / "play-ui007", profile.read_json(evidence / "source-identity.json"))


def camera(args) -> None:
    import run_workbench_qualification as wb
    profile.require_platform(args.platform)
    manifest = profile.verify_materials_bundle(args.bundle, args.platform, args.source_sha)
    engine.require(not (args.bundle / "camera.json").exists(), "Do not overwrite earlier camera evidence")
    if args.platform == "windows":
        godot, _ = engine.windows.prepare_godot(args.godot_archive)
    else:
        engine.require(engine.runner.sha256(args.godot_archive) == engine.GODOT_LINUX_SHA256, "Linux engine archive changed")
        godot = args.godot_archive.with_suffix("") / "Godot_v4.7-stable_linux.x86_64"
    report = context(args.source_sha) | {"schema": "native-pixel-integrated-camera-v1", "platform": args.platform,
              "native_sha256": manifest["sha256"], "completed": False, "status": "running"}
    try:
        camera_cases(godot, ROOT / "godot", args.bundle / "camera-source")
        runner = wb.Runner(argparse.Namespace(godot=godot, evidence=args.bundle / "camera-override"))
        runner.execute("recording-explicit-override", [str(godot.resolve()), "--headless", "--audio-driver", "Dummy",
                       "--path", str(ROOT / "godot"), "--script", "res://tests/test_gameplay_recorder.gd", "--",
                       "--recording-roi-override-test", "--record-roi=1000,700,100,120", "--record-hz=120", "--record-queue=0"],
                       marker="GAMEPLAY_RECORDER_RESULT")
        if args.platform == "linux":
            with tempfile.TemporaryDirectory(prefix="native-pixel-installed-") as temporary:
                destination = Path(temporary) / "package"
                wb.stage_linux(argparse.Namespace(output=destination))
                camera_cases(godot, destination / "godot", args.bundle / "camera-installed")
        report.update(status="passed", completed=True)
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report["files_sha256"] = camera_files(args.bundle)
        engine.write_json(args.bundle / "camera.json", report)


def verify_bundle(directory: Path, platform: str, source: str) -> dict:
    manifest = profile.verify_materials_bundle(directory, platform, source)
    report = profile.read_json(directory / "camera.json")
    profile.verify_context(report, source)
    engine.require(report.get("schema") == "native-pixel-integrated-camera-v1" and report.get("platform") == platform and
                   report.get("native_sha256") == manifest["sha256"] and report.get("status") == "passed" and
                   report.get("completed") is True and report.get("files_sha256") == camera_files(directory),
                   "Camera evidence is incomplete or changed")
    profile.verify_results(directory / "camera-source/results.json", CAMERA_LABELS)
    verify_play_ui007(directory / "camera-source/play-ui007", platform, source,
                      profile.read_json(directory / "camera-source/source-identity.json"), manifest["sha256"])
    profile.verify_results(directory / "camera-override/results.json", ["recording-explicit-override"])
    if platform == "linux":
        profile.verify_results(directory / "camera-installed/results.json", CAMERA_LABELS)
        verify_play_ui007(directory / "camera-installed/play-ui007", platform, source,
                          profile.read_json(directory / "camera-installed/source-identity.json"), manifest["sha256"])
    return manifest


def packager():
    sys.path.insert(0, str(ROOT / "tools"))
    package = private_module("_native_pixel_combined_packager", ROOT / "tools/package_mat_workbench_candidate.py")
    package.publication = profile
    package.engine = engine
    package.lab.publication = profile
    package.lab.engine = engine
    return package


def validate_archive_names(names: list[str], max_path: int | None) -> None:
    engine.require(bool(names), "Archive has no files")
    engine.require(len(set(n.casefold() for n in names)) == len(names), "Archive has Windows path collisions")
    for name in names:
        engine.require(max_path is None or len(name) <= max_path, "Archive path exceeds Windows extraction budget: " + name)
        for part in name.split("/"):
            engine.require(bool(part) and part not in {".", ".."} and not re.search(r'[<>:"\\|?*\x00-\x1f]', part) and not part.endswith((" ", ".")) and
                           not re.match(r"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)", part, re.I),
                           "Archive has a Windows-incompatible path: " + name)


def write_archive(directory: Path, archive: Path, *, max_path: int | None = None) -> dict:
    engine.require(not archive.exists(), "Do not overwrite an archive")
    entries = sorted(directory.rglob("*"))
    engine.require(not any(p.is_symlink() for p in entries), "Archive contains a symlink")
    paths = [p for p in entries if p.is_file()]
    names = [p.relative_to(directory).as_posix() for p in paths]
    validate_archive_names(names, max_path)
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=False) as output:
        for p, name in zip(paths, names):
            output.write(p, name)
    with zipfile.ZipFile(archive) as output:
        engine.require(output.testzip() is None and output.namelist() == names, "Created archive failed integrity verification")
    return {"sha256": engine.runner.sha256(archive), "bytes": archive.stat().st_size, "members": len(names),
            "maximum_relative_path": max(map(len, names)), "compression": "Deflate; no ZIP64"}


def package(args) -> None:
    pack = packager()
    if args.operation == "build":
        verify_bundle(args.bundle, "windows", args.source_sha)
        output = pack.build(args)
        identity = pack.verify(output)
        raw = output / "qualification"
        evidence_files = pack.lab.file_map(raw)
        evidence_zip = output / "qualification.zip"
        evidence_identity = write_archive(raw, evidence_zip)
        # Preserve every raw byte and original relative name inside the evidence
        # archive. Caches no longer create >260-character application paths.
        shutil.rmtree(raw)
        evidence_identity["files_sha256"] = evidence_files
        engine.write_json(output / "qualification-index.json", evidence_identity)
        readme = output / "README.txt"
        original = readme.read_text(encoding="utf-8")
        evidence_reference = "Original platform evidence: qualification/."
        engine.require(original.count(evidence_reference) == 1, "Combined package evidence guidance changed")
        original = original.replace(evidence_reference,
            "Original platform evidence: qualification.zip (file hashes: qualification-index.json).")
        with readme.open("w", encoding="utf-8") as stream:
            stream.write(original)
            stream.write("\nIntegrated native-pixel camera evaluation (#566, accepted #565 main).\n"
                         "Extract to a short writable path such as C:\\CyberSand566.\n"
                         "Original qualification bytes are in qualification.zip; qualification-index.json records their hashes.\n"
                         "Camera acceptance: slow pan at 2x/2.5x/4x; cursor zoom; precise paint/copy/paste;\n"
                         "shared Undo/Redo; Save/exit/reopen; moving-actor follow; glow/vapour alignment.\n"
                         "Evaluate frame pacing on your GPU and Windows scaling at 125%, 150%, 200% where practical.\n"
                         "Hosted graphical qualification does not establish physical GPU/DPI acceptance.\n")
        identity.update(camera_scope="Native display-pixel camera and corrected recorder edge capture on accepted main",
                        qualification_archive=evidence_identity, files_sha256=pack.lab.file_map(output))
        (output / pack.MANIFEST).write_bytes(pack.lab.canonical(identity))
        pack.verify(output)
    elif args.operation == "smoke":
        pack.smoke(args.output, args.evidence)
        # Run against the exact .NET-extracted delivery, with package-only tools.
        import run_workbench_qualification as wb
        old_root = wb.ROOT
        old_environment = dict(os.environ)
        try:
            environment = pack.lab.dependency_environment(args.output.resolve())
            os.environ.clear()
            os.environ.update(environment)
            with tempfile.TemporaryDirectory(prefix="native-pixel-delivered-") as temporary:
                wb.ROOT = Path(temporary) / "source"
                shutil.copytree(args.output.resolve() / "source", wb.ROOT)
                camera_cases(args.output / "Godot_v4.7-stable_win64_console.exe", wb.ROOT / "godot",
                             args.evidence / "camera-installed")
        finally:
            wb.ROOT = old_root
            os.environ.clear()
            os.environ.update(old_environment)
        pack.verify(args.output)
    else:
        pack.verify(args.output)


def archive_package(args) -> dict:
    pack = packager()
    identity = pack.verify(args.output)
    report = write_archive(args.output, args.archive, max_path=220)
    report.update(source_commit=identity["source_commit"], source_tree=identity["source_tree"],
                  native_sha256=identity["native_sha256"])
    args.archive.with_suffix(".zip.sha256").write_text(report["sha256"] + "  " + args.archive.name + "\n", encoding="ascii")
    engine.write_json(args.archive.with_suffix(".zip.json"), report)
    return report


def dispatch_existing(args) -> dict:
    check_source(args.source_sha)
    token = os.environ.get("GITHUB_TOKEN", "")
    engine.require(bool(token), "Scoped Actions dispatch token is unavailable")
    engine.require(not args.output.exists(), "Do not overwrite a dispatch receipt")
    report = context(args.source_sha) | {"schema": "native-pixel-full-gates-dispatch-v1", "status": "requesting",
                                        "completed": False, "requests": []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    engine.write_json(args.output, report)
    for workflow in DISPATCH_WORKFLOWS:
        check_source(args.source_sha)
        request = urllib.request.Request("https://api.github.com/repos/techrote/cybersand/actions/workflows/" + workflow + "/dispatches",
                    data=json.dumps({"ref": BRANCH}).encode(), method="POST", headers={"Authorization": "Bearer " + token,
                    "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28", "Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=60) as response:
            engine.require(response.status == 204, "Workflow dispatch was not acknowledged")
        check_source(args.source_sha)
        report["requests"].append({"workflow": workflow, "head_sha": args.source_sha, "status": "accepted"})
        engine.write_json(args.output, report)
    report.update(status="requested", completed=True, scope="Dispatch receipts only; inspect all resulting exact-source jobs independently")
    engine.write_json(args.output, report)
    return report


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command in {"record", "test", "catalogue-tests", "graphical", "workbench"}:
        return profile.main()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check-source", "camera", "verify", "package", "archive", "dispatch-existing"])
    parser.add_argument("--source-sha")
    parser.add_argument("--platform", choices=["linux", "windows"])
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--operation", choices=["build", "verify", "smoke"])
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--python-root", type=Path, default=Path(sys.base_prefix))
    parser.add_argument("--git-root", type=Path, default=Path(r"C:\Program Files\Git"))
    parser.add_argument("--compiler-root", type=Path, default=Path(r"C:\mingw64"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    actions = {"check-source": lambda: check_source(args.source_sha), "camera": lambda: camera(args),
               "verify": lambda: verify_bundle(args.bundle, args.platform, args.source_sha),
               "package": lambda: package(args), "archive": lambda: archive_package(args),
               "dispatch-existing": lambda: dispatch_existing(args)}
    result = actions[args.command]()
    print(json.dumps({"status": "passed", "command": args.command, "result": result}, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
