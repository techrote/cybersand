#!/usr/bin/env python3
"""Read-only #566 qualification of accepted main, camera and standalone authoring.

Privately compose the existing MAT/Workbench qualification profile and packager.
This entry point cannot publish runtimes, move refs, promote a PR or merge.
"""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re
import shutil
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
    "tools/ci/run_integrated_camera_performance.py",
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


def camera_cases(godot: Path, project: Path, evidence: Path) -> None:
    import run_workbench_qualification as wb
    wb.camera(argparse.Namespace(godot=godot, project=project, evidence=evidence))
    profile.verify_results(evidence / "results.json", CAMERA_LABELS)


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
    profile.verify_results(directory / "camera-override/results.json", ["recording-explicit-override"])
    if platform == "linux":
        profile.verify_results(directory / "camera-installed/results.json", CAMERA_LABELS)
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
        with (output / "README.txt").open("a", encoding="utf-8") as stream:
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
