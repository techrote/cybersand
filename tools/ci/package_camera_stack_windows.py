#!/usr/bin/env python3
"""Package exact reconciliation source with the unchanged accepted-main runtimes.

This evaluation builder cannot publish native libraries, mutate refs or release.
Retained native build provenance remains intact; application execution identifies
its newer Git commit separately. Windows is required only for package creation.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ACCEPTED_MAIN = "018bd09503d7f079ddac52e225c2f7daf8d678bf"
MANIFEST = "CAMERA-STACK-MANIFEST.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
NATIVE_PROVENANCE = "godot/addons/cybersand_native/runtime-provenance.json"
ENGINE = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
ENGINE_VERSION = "4.7.stable.official.5b4e0cb0f"
ENGINE_ZIP_SHA512 = ("41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
                     "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9")
PRESERVED = ("native", "godot/native_extension", "godot/addons/cybersand_native",
             "godot/addons/godot-rapier2d", "third_party/native-toolchain.lock.json",
             "third_party/godot-runtime.lock.json", "godot/third_party/rapier2d.lock.json")
APPLICATION_PATHS = ("godot/scripts", "godot/tests", "godot/shaders", "godot/project.godot", "godot/main.tscn",
                     "tools/ci/package_camera_stack_windows.py", "tools/ci/run_camera_stack_windows.ps1")
SOURCE_PATHS = ("godot", "native/include", "native/src", "examples/worldgen", "third_party",
                "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md", "AGENTS.md",
                "tools/architecture/capture_legacy.gd", "tools/architecture/legacy-materials-ac0d9fb9.json",
                "tools/ci/run_camera_stack_windows.ps1", "tools/ci/build_rapier_bvh_candidate.py",
                ".github/workflows/rapier-bvh-build.yml")


def need(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path, algorithm="sha256"):
    h = hashlib.new(algorithm)
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=120).decode().strip()


def safe_name(name):
    path = PurePosixPath(name)
    need(name and path.parts and str(path) == name and not path.is_absolute() and ".." not in path.parts and "\\" not in name,
         "Unsafe package path: " + name)
    need(all(part and not re.search(r'[<>:"|?*\x00-\x1f]', part) and not part.endswith((".", " "))
             and not re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", part)
             for part in path.parts), "Windows-incompatible package path: " + name)
    return path


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def verify_runtime(root, provenance, *, kind="native"):
    """Authenticate retained bytes and every compiler input without relabelling."""
    inputs = provenance.get("source_inputs")
    need(isinstance(inputs, dict) and inputs, "Missing native source-input ledger")
    if kind == "native":
        need(re.fullmatch(r"[0-9a-f]{40}", provenance.get("source_commit", "")), "Missing native build identity")
    elif kind == "rapier":
        build = provenance.get("build_record", {})
        need(provenance.get("schema_version") == 1 and
             provenance.get("status") == "source-matched-cooperative-bvh-backport" and
             re.fullmatch(r"[0-9a-f]{40}", provenance.get("build_commit", "")) and
             build.get("source_sha") == provenance["build_commit"] and build.get("variant") == "patched" and
             build.get("godot_version") == ENGINE_VERSION and build.get("join_regression_exit") == 0 and
             build.get("artifacts", {}).get(Path(provenance.get("artifact", "")).name) == provenance.get("sha256"),
             "Missing or inconsistent Rapier build-record identity")
    else:
        raise ValueError("Unknown retained runtime schema: " + kind)
    for name, expected in inputs.items():
        safe_name(name)
        file = root / name
        need(file.is_file(), "Missing native source: " + name)
        actual = hashlib.sha256(file.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        need(actual == expected, "Retained runtime native source mismatch: " + name)
    artifact = provenance.get("artifact", "")
    safe_name(artifact)
    file = root / artifact
    need(file.is_file() and not file.read_bytes().startswith(b"version https://git-lfs"),
         "Required runtime is not materialized: " + artifact)
    need(sha(file) == provenance.get("sha256") and file.stat().st_size == provenance.get("size"),
         "Retained runtime bytes differ: " + artifact)


def preflight(source, platform=None):
    need(re.fullmatch(r"[0-9a-f]{40}", source or ""), "Full application source SHA required")
    need(git("rev-parse", "HEAD") == source, "Checkout HEAD differs from requested package source")
    git("merge-base", "--is-ancestor", ACCEPTED_MAIN, source)
    git("diff", "--exit-code", ACCEPTED_MAIN, source, "--", *PRESERVED)
    # Current source/runtime custody is verified before any archive is produced.
    git("diff", "--exit-code", source, "--", *PRESERVED)
    git("diff", "--exit-code", source, "--", *APPLICATION_PATHS)
    untracked = git("ls-files", "--others", "--exclude-standard", "--", *APPLICATION_PATHS).splitlines()
    need(not any(Path(name).suffix in (".gd", ".gdshader", ".py", ".ps1") for name in untracked),
         "Untracked application/qualification source prevents exact-source execution")
    selected = platform or ("windows" if os.name == "nt" else "linux")
    manifest = ROOT / "godot/addons/cybersand_native" / (
        "runtime-provenance.json" if selected == "windows" else "runtime-provenance.linux.json")
    provenance = read_json(manifest)
    verify_runtime(ROOT, provenance)
    rapier = read_json(ROOT / ("godot/addons/godot-rapier2d/runtime-provenance." + selected + ".json"))
    verify_runtime(ROOT, rapier, kind="rapier")
    return {"schema": "camera-stack-source-custody-v1", "source_commit": source,
            "source_tree": git("rev-parse", source + "^{tree}"), "accepted_main": ACCEPTED_MAIN,
            "accepted_main_tree": git("rev-parse", ACCEPTED_MAIN + "^{tree}"),
            "native_build_commit": provenance["source_commit"], "native_sha256": provenance["sha256"],
            "native_source_inputs": provenance["source_inputs"], "rapier_sha256": rapier["sha256"],
            "rapier_build_commit": rapier["build_commit"],
            "platform": selected, "retained_native_unchanged": True}


def test_plan():
    cases = []

    def add(name, script, marker, *, graphical=False, group=None, env=None,
            kind="json", extra=None, depends=None, timeout=900, pngs=None):
        cases.append(dict(name=name, script=script, marker=marker, graphical=graphical,
                          group=group or name, env=env or {}, kind=kind, extra=extra or [],
                          depends=depends or [], timeout_seconds=timeout, pngs=pngs or []))

    add("camera-coordinates", "test_native_pixel_camera.gd", "NATIVE_PIXEL_CAMERA_RESULT")
    add("recording", "test_gameplay_recorder.gd", "GAMEPLAY_RECORDER_RESULT")
    add("native-recording", "test_camera_stack_recording.gd", "CAMERA_STACK_RECORDING_RESULT", graphical=True,
        env={"CAMERA_STACK_RECORDING_OUTPUT": "{case}/recording"})
    add("recording-override", "test_gameplay_recorder.gd", "GAMEPLAY_RECORDER_RESULT",
        extra=["--recording-roi-override-test", "--record-roi=1000,700,100,120", "--record-hz=120", "--record-queue=0"])
    add("camera-framebuffer", "test_native_pixel_scrolling_render.gd", "NATIVE_PIXEL_SCROLLING_RESULT",
        graphical=True, env={"CYBERSAND_TEST_ARTIFACT_DIR": "{case}/frames"}, timeout=1200)
    add("camera-effects", "test_native_camera_effects_render.gd", "NATIVE_CAMERA_EFFECTS_RESULT",
        graphical=True, env={"CYBERSAND_TEST_ARTIFACT_DIR": "{case}/frames"})
    add("mask-receipts", "test_workbench_mask_receipt.gd", "WORKBENCH_MASK_RECEIPT_RESULT")
    add("engine-lab", "test_workbench_engine_lab.gd", "ENGINE_LAB_RESULT", graphical=True,
        env={"CYBERSAND_ENGINE_LAB_SCREENSHOT": "{case}/engine-lab.png"})
    add("cross-clocks", "test_camera_stack_clocks.gd", "CAMERA_STACK_CLOCKS_RESULT", graphical=True)
    add("architecture-contract", "test_architectural_project_contract.gd", "ARCHITECTURAL_PROJECT_CONTRACT", kind="counts")
    add("architecture-native", "test_architectural_generator.gd", "ARCHITECTURE_RESULTS",
        kind="architecture", env={"CYBERSAND_ARCHITECTURE_PHASE": "native",
                                  "CYBERSAND_ARCHITECTURE_OUTPUT": "{case}"})
    add("architecture-ui", "test_architectural_generator_ui.gd", "ARCHITECTURAL_UI", kind="counts", graphical=True)
    for phase in ("author", "reopen", "multistyle-author", "multistyle-reopen"):
        add("architecture-" + phase, "test_architectural_generator.gd", "ARCHITECTURE_RESULTS",
            kind="architecture", graphical=True, group="architecture",
            depends=["architecture-" + phase.replace("reopen", "author")] if "reopen" in phase else [],
            env={"CYBERSAND_ARCHITECTURE_PHASE": phase, "CYBERSAND_ARCHITECTURE_OUTPUT": "{case}",
                 "CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS": "1"}, timeout=1200)
    add("legacy-materials", "../tools/architecture/capture_legacy.gd", "ARCHITECTURE_LEGACY", kind="legacy",
        env={"CYBERSAND_LEGACY_OUTPUT": "{case}/legacy-materials.json"})
    add("baseline-format", "test_workbench_material_baseline.gd", "WORKBENCH_MATERIAL_BASELINE", kind="counts")
    for phase in ("author", "reopen"):
        add("flatten-" + phase, "test_workbench_flatten.gd", "FLATTEN_RESULT", kind="flatten",
            graphical=True, group="flatten", depends=["flatten-author"] if phase == "reopen" else [],
            env={"FLATTEN_SIDE": "512", "FLATTEN_WORKERS": "1", "FLATTEN_REOPEN": "1" if phase == "reopen" else "0",
                 "FLATTEN_REQUIRE_GRAPHICS": "1", "FLATTEN_SCREENSHOTS": "{case}/frames"}, timeout=1200,
            pngs=["flatten-reopened-and-continued.png"] if phase == "reopen" else
                 ["flatten-identical-live-world.png", "flatten-explicitly-saved.png"])
        add("owner-recovery-" + phase, "test_workbench_flatten_owner_failure.gd", "FLATTEN_OWNER_FAILURE_RESULT",
            kind="recovery", graphical=True, group="owner-recovery",
            depends=["owner-recovery-author"] if phase == "reopen" else [],
            env={"FLATTEN_OWNER_FAILURE_REOPEN": "1" if phase == "reopen" else "0",
                 "FLATTEN_REQUIRE_GRAPHICS": "1", "FLATTEN_SIDE": "512", "FLATTEN_WORKERS": "1"}, timeout=1200)
        add("combined-" + phase, "test_workbench_combined_authoring.gd", "WB_COMBINED_EVIDENCE", kind="combined",
            graphical=True, group="combined", depends=["combined-author"] if phase == "reopen" else [],
            env={"WB_COMBINED_SIDE": "512", "WB_COMBINED_WORKERS": "1",
                 "WB_COMBINED_REOPEN": "1" if phase == "reopen" else "0",
                 "WB_COMBINED_REQUIRE_GRAPHICS": "1", "WB_COMBINED_SCREENSHOTS": "{case}/frames"}, timeout=1200,
            pngs=["combined-generator-profiles.png", "combined-reopened-and-continued.png"] if phase == "reopen" else
                 ["combined-generator-profiles.png", "combined-generator-preview.png", "combined-agent-and-paint.png",
                  "combined-equipment-simulation.png", "combined-authored-saved.png"])
    return {"schema": "camera-stack-installed-test-plan-v1", "cases": cases,
            "scope": "native/Godot integration; physical NVIDIA smoothness and OS DPI require owner review"}


def export_source(output, source):
    data = subprocess.check_output(["git", "-C", str(ROOT), "archive", "--format=tar", source,
                                    "--", *SOURCE_PATHS], timeout=180)
    inventory = {}
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive:
            if member.isdir():
                continue
            need(member.isfile(), "Source archive contains a non-file member: " + member.name)
            name = member.name
            safe_name(name)
            if name.startswith("godot/.godot/"):
                continue
            if (Path(name).suffix.lower() in {".dll", ".so", ".dylib", ".wasm"} or ".framework/" in name) and name not in (NATIVE, RAPIER):
                continue
            body = (ROOT / name).read_bytes() if name in (NATIVE, RAPIER) else archive.extractfile(member).read()
            need(not body.startswith(b"version https://git-lfs.github.com/spec/v1"), "Unmaterialized source payload: " + name)
            target = output / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(body)
            inventory[name] = hashlib.sha256(body).hexdigest()
    return inventory


def inventory(root, *, used=False):
    result = {}
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        name = path.relative_to(root).as_posix()
        if name == MANIFEST:
            continue
        if used and (name.startswith(("godot/.godot/", "Test-It-Results/")) or name.endswith(".import")):
            continue
        result[name] = sha(path)
    return result


def verify(output, *, used=False):
    manifest = read_json(output / MANIFEST)
    need(manifest.get("schema") == "camera-stack-windows-evaluation-v1", "Wrong package schema")
    need(manifest.get("accepted_main") == ACCEPTED_MAIN and manifest.get("retained_native_unchanged") is True,
         "Accepted-main native custody missing")
    need(re.fullmatch(r"[0-9a-f]{40}", manifest.get("source_commit", "")), "Source commit missing")
    expected = manifest.get("files_sha256", {})
    need(bool(expected), "Empty package inventory")
    for name in expected:
        safe_name(name)
    if used:
        expected = {name: value for name, value in expected.items() if not name.endswith(".import")}
    actual = inventory(output, used=used)
    if used:
        # Import may create UIDs for newly authored scripts. Existing tracked
        # UIDs stay protected; only new metadata beside an authenticated source
        # script/shader/extension can be ignored.
        for name in set(actual) - set(expected):
            if (name.endswith(".uid") and name[:-4] in expected and
                    Path(name[:-4]).suffix in (".gd", ".gdshader", ".gdextension")):
                del actual[name]
    need(actual == expected, "Package files are missing, unexpected or changed")
    verify_runtime(output, read_json(output / NATIVE_PROVENANCE))
    verify_runtime(output, read_json(output / "godot/addons/godot-rapier2d/runtime-provenance.windows.json"), kind="rapier")
    need(sha(output / NATIVE) == manifest["native_sha256"] and sha(output / RAPIER) == manifest["rapier_sha256"],
         "Package runtime identity differs")
    for name in (ENGINE, CONSOLE, "Test It.cmd", "Run-Camera-Stack.ps1", "Open Workbench.cmd", "Test-Plan.json"):
        need(name in expected, "Required runnable package payload missing: " + name)
    need(sha(output / "Run-Camera-Stack.ps1") == manifest["source_files_sha256"]["tools/ci/run_camera_stack_windows.ps1"],
         "Installed test script differs from exact Git source")
    need(read_json(output / "Test-Plan.json") == test_plan(), "Installed qualification plan changed")
    for name, value in manifest["generator_profiles_sha256"].items():
        need(sha(output / "examples/worldgen" / name) == value and
             sha(output / "godot/authoring/worldgen" / name) == value, "Generator profile mismatch: " + name)
    return manifest


def build(args):
    need(os.name == "nt", "Build and verify the engine on actual Windows")
    identity = preflight(args.source, "windows")
    need(not args.output.exists() and not args.archive.exists(), "Refusing to overwrite evaluation or archive")
    need(sha(args.godot_zip, "sha512") == ENGINE_ZIP_SHA512, "Official Godot archive hash mismatch")
    args.output.mkdir(parents=True)
    source_files = export_source(args.output, args.source)
    with zipfile.ZipFile(args.godot_zip) as archive:
        need(archive.testzip() is None, "Godot archive CRC failure")
        for name in (ENGINE, CONSOLE):
            (args.output / name).write_bytes(archive.read(name))
    # Existing repository verifier requires exact source-authenticated VC bytes.
    from importlib.util import module_from_spec, spec_from_file_location
    spec = spec_from_file_location("_camera_stack_runtime_stage", ROOT / "tools/package_explore001_candidate.py")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    module.stage_vc_runtime(args.vc, args.output)
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        need((args.notices / name).is_file(), "Missing official Godot notices")
        shutil.copyfile(args.notices / name, args.output / ("Godot-" + name))
    version = subprocess.check_output([str(args.output / CONSOLE), "--version"], text=True, timeout=45).strip()
    need(version == ENGINE_VERSION, "Executed Godot version mismatch: " + version)
    profiles = {p.name: sha(p) for p in sorted((args.output / "examples/worldgen").glob("*.json"))}
    need({"gen007-deepworks.json", "gen007-qualification.json"} <= profiles.keys(), "Generator catalogue missing")
    resource = args.output / "godot/authoring/worldgen"
    resource.mkdir(parents=True, exist_ok=True)
    for name in profiles:
        shutil.copyfile(args.output / "examples/worldgen" / name, resource / name)
    for case in test_plan()["cases"]:
        path = (args.output / "tools/architecture/capture_legacy.gd" if case["kind"] == "legacy"
                else args.output / "godot/tests" / case["script"])
        need(path.is_file(), "Qualification fixture missing from exact source: " + str(path))
    legacy = read_json(args.legacy_reference)
    need(legacy.get("source_commit") == ACCEPTED_MAIN and legacy.get("platform") == "win32" and
         legacy.get("runtime_sha256") == identity["native_sha256"] and legacy.get("complete") is True,
         "Legacy reconstruction needs a successful same-platform accepted-main capture")
    (args.output / "qualification").mkdir()
    shutil.copyfile(args.legacy_reference, args.output / "qualification/accepted-main-legacy.json")
    shutil.copyfile(args.output / "tools/ci/run_camera_stack_windows.ps1", args.output / "Run-Camera-Stack.ps1")
    write_json(args.output / "Test-Plan.json", test_plan())
    test_cmd = ('@echo off\nsetlocal\ncd /d "%~dp0"\n'
                'rem Isolate Windows PowerShell from inherited PowerShell Core module paths.\n'
                'set "PSModulePath=%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\Modules"\n'
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Camera-Stack.ps1" %*\n'
                'set "CYBERSAND_TEST_EXIT=%errorlevel%"\n'
                'if not defined CI if not "%CYBERSAND_TEST_AUTOMATED%"=="1" pause\n'
                'exit /b %CYBERSAND_TEST_EXIT%\n')
    (args.output / "Test It.cmd").write_bytes(test_cmd.replace("\n", "\r\n").encode())
    launch = ('@echo off\nsetlocal\ncd /d "%~dp0"\n'
              'set "CYBERSAND_SOURCE_REVISION=' + args.source + '"\n'
              'set "CYBERSAND_EVAL_SOURCE_SHA=' + args.source + '"\n'
              '"%~dp0' + CONSOLE + '" --headless --path "%~dp0godot" --editor --quit\n'
              'if errorlevel 1 (echo Import failed. & pause & exit /b 1)\n'
              'start "" "%~dp0' + ENGINE + '" --path "%~dp0godot" -- --workbench\n')
    (args.output / "Open Workbench.cmd").write_bytes(launch.replace("\n", "\r\n").encode())
    (args.output / "READ-ME.txt").write_text(
        "CyberSand camera-stack reconciliation — conditional owner evaluation\n\n"
        f"Application source: {args.source}\nAccepted-main base: {ACCEPTED_MAIN}\n"
        f"Native build retained from: {identity['native_build_commit']}\nNative DLL: {identity['native_sha256']}\n\n"
        "Extract the whole ZIP into a fresh writable folder. Double-click Test It.cmd.\n"
        "It verifies the source/runtime inventory, runs real graphical integration fixtures,\n"
        "and saves original logs, receipts and screenshots under Test-It-Results, plus a ZIP.\n"
        "No downloads, installers, Python or Git are required on your computer.\n"
        "Double-click Open Workbench.cmd for manual authoring and camera evaluation.\n\n"
        "Retained: accepted GEN-007/Flatten, #566 camera, separately reconciled Engine Lab.\n"
        "The #593 guarded live-pose algorithm and #609 moving repair are not accepted here.\n"
        "Pixel/Rapier target changes retain fixed simulated step durations and therefore\n"
        "change simulation speed. Requested rates are not achieved-rate promises.\n\n"
        "Physical review: test Free/Follow camera; pan/zoom/cell painting at 1x and fractional\n"
        "scales; five architecture styles; Fill/Undo/Redo; Flatten then edit/save/exit/reopen.\n"
        "Inspect moving actors at low native rates and unequal Pixel/Rapier/render targets.\n"
        "Record NVIDIA GPU/driver, Windows display scale (100/125/150/200%), VSync and\n"
        "reproduction steps. Automated PASS does not establish motion smoothness.\n"
        "Existing Linux software-renderer cost and the owner-reported stutter remain open.\n"
        "No production release or merge acceptance is implied.\n", encoding="utf-8")
    manifest = {**identity, "schema": "camera-stack-windows-evaluation-v1", "godot_version": ENGINE_VERSION,
                "godot_archive_sha512": ENGINE_ZIP_SHA512, "source_files_sha256": source_files,
                "generator_profiles_sha256": profiles, "physical_gpu_acceptance": "pending",
                "files_sha256": inventory(args.output)}
    write_json(args.output / MANIFEST, manifest)
    verify(args.output)
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=False) as archive:
        for path in sorted(args.output.rglob("*")):
            if path.is_file():
                name = path.relative_to(args.output).as_posix()
                safe_name(name)
                archive.write(path, name)
    with zipfile.ZipFile(args.archive) as archive:
        need(archive.testzip() is None, "Evaluation archive CRC failure")
    args.archive.with_suffix(".zip.sha256").write_text(sha(args.archive) + "  " + args.archive.name + "\n")
    write_json(args.archive.with_suffix(".zip.json"), {"source_commit": args.source,
               "source_tree": identity["source_tree"], "sha256": sha(args.archive), "bytes": args.archive.stat().st_size,
               "physical_gpu_acceptance": "pending", "hosted_installed_qualification": "separate required workflow gate"})
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("preflight", "build", "verify"))
    parser.add_argument("--source")
    parser.add_argument("--platform", choices=("linux", "windows"))
    parser.add_argument("--used", action="store_true", help="Allow generated imports/cache and local test evidence")
    for name in ("godot-zip", "notices", "vc", "output", "archive", "legacy-reference"):
        parser.add_argument("--" + name, type=Path)
    args = parser.parse_args()
    if args.command == "preflight":
        result = preflight(args.source, args.platform)
    elif args.command == "build":
        need(all(getattr(args, key) is not None for key in ("source", "godot_zip", "notices", "vc", "output", "archive", "legacy_reference")),
             "Build requires exact source, engine/notices/VC inputs, output and archive")
        result = build(args)
    else:
        need(args.output is not None, "Verification requires package output directory")
        result = verify(args.output, used=args.used)
    print(json.dumps({"status": "passed", "operation": args.command, "source_commit": result["source_commit"],
                      "native_sha256": result["native_sha256"], "native_build_commit": result["native_build_commit"]}))


if __name__ == "__main__":
    main()
