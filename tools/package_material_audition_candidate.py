#!/usr/bin/env python3
"""Build, verify and execute a portable current-scene Materials Lab evaluator.

Reuses the accepted Lab's offline source/history, Python, Git and compiler
packaging.  It has a distinct candidate manifest and never overwrites retained
runtime provenance or changes the canonical material catalogue.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import secrets
import subprocess
import struct
import sys
import tempfile
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import run_material_audition_qualification as qualification
import package_materials_lab_candidate as lab
from package_explore001_candidate import stage_vc_runtime, verify_vc_runtime

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "material-audition-evaluator.json"
NOTICES = {
    "LICENSE.txt": "b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
    "COPYRIGHT.txt": "cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d",
}


def files(directory: Path) -> dict[str, str]:
    result = {}
    for path in sorted(directory.rglob("*")):
        qualification.require(not path.is_symlink(), "Evaluator must not depend on symlinks: " + str(path))
        if path.is_file() and path != directory / MANIFEST:
            result[path.relative_to(directory).as_posix()] = qualification.sha(path)
    return result


def verified_execution(directory: Path, manifest: dict, *, graphical: bool,
                       candidate_digest: str | None = None, godot_digest: str | None = None,
                       platform: str = "windows", cases: tuple | None = None) -> dict:
    qualification.require(platform in ("windows","linux"), "Unsupported execution platform")
    qualification.require(manifest.get("platform") == platform,"Execution platform differs from its native candidate")
    cases = qualification.CASES if cases is None else cases
    result = json.loads((directory / "execution.json").read_text(encoding="utf-8"))
    qualification.require(result.get("schema") == "cybersand.material-audition.execution" and
            result.get("status") == "passed" and result.get("platform") == platform and
            result.get("graphical") is graphical, "Actual " + platform.capitalize() + " execution is required")
    for key in ("source_commit", "source_tree", "native_sha256"):
        qualification.require(result.get(key) == manifest.get(key), "Windows evidence identity mismatch: " + key)
    qualification.require(result.get("godot_version") == qualification.VERSION,
                          "Windows evidence used a different Godot version")
    engine_sha = result.get("godot_sha256")
    qualification.require(isinstance(engine_sha,str) and len(engine_sha) == 64 and
                          all(letter in "0123456789abcdef" for letter in engine_sha) and
                          (godot_digest is None or engine_sha == godot_digest), "Windows engine byte identity mismatch")
    expected_candidate = candidate_digest or hashlib.sha256(qualification.canonical(manifest)).hexdigest()
    qualification.require(result.get("candidate_sha256") == expected_candidate, "Windows candidate manifest identity mismatch")
    expected = {"import", *(name for name, _marker in cases)}
    actual = {item.get("name") for item in result.get("cases", []) if item.get("status") == "passed"}
    qualification.require(expected == actual and len(result["cases"]) == len(expected),
                          "Windows execution omitted or duplicated required cases")
    qualification.require(all(item.get("status") == "passed" and item.get("exit_code") == 0
                              for item in result["cases"]), "Windows evidence includes a failed process")
    inventory = result.get("files_sha256", {})
    qualification.require(isinstance(inventory, dict) and all(name + suffix in inventory
                          for name in expected for suffix in (".log", ".receipt.json")),
                          "Original logs and process receipts are required")
    for relative, expected_sha in inventory.items():
        path = Path(relative)
        qualification.require(not path.is_absolute() and ".." not in path.parts,
                              "Evidence inventory contains an unsafe path")
        qualification.require(qualification.sha(directory / path) == expected_sha,
                              "Original Windows evidence changed: " + relative)
    markers = dict(cases)
    completions = {}
    for summary in result["cases"]:
        name = summary["name"]
        receipt = json.loads((directory / (name + ".receipt.json")).read_text(encoding="utf-8"))
        qualification.require(receipt == {key:value for key,value in summary.items() if key != "name"},
                              "Original process receipt disagrees with execution summary: " + name)
        qualification.require(receipt.get("status") == "passed" and type(receipt.get("exit_code")) is int and
                              receipt["exit_code"] == 0, "Original process did not succeed: " + name)
        log = directory / (name + ".log")
        qualification.require(receipt.get("log_sha256") == qualification.sha(log), "Process log identity mismatch: " + name)
        text = log.read_text(encoding="utf-8", errors="replace")
        qualification.require(not qualification.ERRORS.search(text), "Original process contains script errors: " + name)
        if name in markers:
            completions[name] = qualification.completion(text,markers[name])
            qualification.require(receipt.get("completion") == completions[name], "Original completion receipt mismatch: " + name)
    if graphical:
        completed = completions["test_material_audition"]
        qualification.require(completed.get("display") not in (None,"","headless"), "Graphical evidence actually used a headless display")
        raw = "frames/native-readback.json"
        qualification.require(raw in inventory and json.loads((directory / raw).read_text(encoding="utf-8")) == completed,
                              "Actual native graphical readback is absent or inconsistent")
        required = {"current-scene-density","current-scene-1000x650","current-scene-1280x720",
                    "density-sorter","viscosity-channel","reaction-contact","industrial-loop"}
        frames = completed.get("frames",[])
        qualification.require(isinstance(frames,list) and {row.get("name") for row in frames} == required and len(frames) == len(required),
                              "Current-scene graphical framebuffer evidence is incomplete")
        for row in frames:
            filename = row.get("file")
            qualification.require(filename == row["name"] + ".png", "Unexpected graphical frame path")
            relative = "frames/" + filename
            qualification.require(relative in inventory and row.get("sha256") == inventory[relative], "Graphical frame byte identity mismatch")
            header = (directory / relative).read_bytes()[:24]
            qualification.require(len(header) == 24 and header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR",
                                  "Graphical frame is not a PNG")
            width,height = struct.unpack(">II",header[16:24])
            qualification.require(width == row.get("width") and height == row.get("height") and width >= 400 and height >= 300,
                                  "Graphical frame dimensions disagree with actual PNG")
        kinds = {row.get("kind") for row in completed.get("native_witnesses",[])}
        qualification.require({"density","viscosity","reaction","owner-adversaries","ordinary-workbench","ordinary-demo"} <= kinds,
                              "Current-scene native witness families are incomplete")
    return result


def launcher(source_commit: str, *, laboratory: bool = False) -> bytes:
    entry = "res://materials_lab.tscn" if laboratory else "-- --workbench"
    rows = ["@echo off", "setlocal", 'cd /d "%~dp0"',
            'set "PYTHONHOME="', 'set "PYTHONPATH="', 'set "PYTHONNOUSERSITE=1"', 'set "PYTHONUTF8=1"']
    rows += ['set "' + key + '="' for key in sorted(lab.GIT_LOCATION)]
    rows += ['set "GIT_CONFIG_NOSYSTEM=1"', 'set "GIT_CONFIG_GLOBAL=NUL"',
             'set "PATH=%~dp0dependencies\\python;%~dp0dependencies\\git\\cmd;%~dp0dependencies\\git\\ucrt64\\bin;%~dp0dependencies\\git\\mingw64\\bin;%~dp0dependencies\\cxx\\bin;%SystemRoot%\\System32;%SystemRoot%"',
             'set "CYBERSAND_LAB_CXX=%~dp0dependencies\\cxx\\bin\\g++.exe"',
             f'set "CYBERSAND_SOURCE_REVISION={source_commit}"',
             '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0source\\godot" --editor --quit',
             'if errorlevel 1 (pause & exit /b 1)',
             'start "" /wait "%~dp0Godot_v4.7-stable_win64.exe" %* --rendering-method gl_compatibility --rendering-driver opengl3_angle --path "%~dp0source\\godot" ' + entry,
             'exit /b %errorlevel%']
    return ("\r\n".join(rows) + "\r\n").encode()


def verify(package: Path) -> dict:
    identity = json.loads((package / MANIFEST).read_text(encoding="utf-8"))
    qualification.require(identity.get("schema") == "cybersand.material-audition.evaluator" and
                          identity.get("schema_version") == 1 and identity.get("platform") == "windows",
                          "Unsupported evaluator manifest")
    qualification.require(identity.get("files_sha256") == files(package), "Evaluator inventory changed")
    candidate = qualification.verify(package / "source", package / "qualification/candidate", "windows")
    for key in ("source_commit", "source_tree", "native_sha256"):
        qualification.require(identity.get(key) == candidate.get(key), "Evaluator source identity mismatch: " + key)
    qualification.require(qualification.sha(package / "source" / qualification.RUNTIMES["windows"]) ==
                          candidate["native_sha256"], "Evaluator installed runtime differs from qualified candidate")
    qualification.require((package / "Open Workbench.cmd").read_bytes() == launcher(identity["source_commit"]),
                          "Ordinary Workbench launcher changed")
    qualification.require((package / "Open Materials Lab.cmd").read_bytes() == launcher(identity["source_commit"], laboratory=True),
                          "Standalone Lab launcher changed")
    verify_vc_runtime(package)
    verified_execution(package / "qualification/source-execution", candidate, graphical=True,
                       candidate_digest=qualification.sha(package / "qualification/candidate" / qualification.MANIFEST),
                       godot_digest=qualification.sha(package / "Godot_v4.7-stable_win64_console.exe"))
    return identity


def build(args: argparse.Namespace) -> Path:
    qualification.require(os.name == "nt", "Portable evaluator assembly requires actual Windows execution")
    candidate = qualification.verify(ROOT, args.candidate, "windows")
    qualification.require(not candidate.get("toolchain_drift", True), "Development toolchain drift cannot qualify the Windows evaluator")
    verified_execution(args.evidence, candidate, graphical=True,
                       candidate_digest=qualification.sha(args.candidate / qualification.MANIFEST),
                       godot_digest=qualification.sha(args.engine.with_name(args.engine.stem + "_console.exe")))
    qualification.require(not args.output.exists() and not args.output.resolve().is_relative_to(ROOT),
                          "Choose a new evaluator directory outside the source checkout")
    console = args.engine.with_name(args.engine.stem + "_console.exe")
    version = subprocess.check_output([str(console), "--version"], text=True, timeout=30).strip()
    qualification.require(version == qualification.VERSION, "Evaluator Godot version differs from the repository pin")
    for name, expected in NOTICES.items():
        qualification.require(qualification.sha(args.engine_notices / name) == expected,
                              "Godot notice identity mismatch: " + name)
    qualification.require((args.compiler_root / "bin/g++.exe").is_file(), "Bundled isolated-authoring C++ compiler is required")
    qualification.require(any(path.is_file() and any(part.lower().startswith(("copying", "license")) for part in path.parts)
                              for path in args.compiler_root.rglob("*")), "Compiler dependency notices are required")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".material-audition-", dir=args.output.parent) as temporary:
        package = Path(temporary) / "evaluation"
        package.mkdir()
        history = lab.clean_source_repository(ROOT, candidate["source_commit"], package / "source")
        source = package / "source"
        shutil.copyfile(args.candidate / Path(candidate["artifact"]).name, source / candidate["artifact"])
        rapier = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
        pointer = qualification.git(ROOT, "cat-file", "blob", "HEAD:" + rapier).decode()
        expected = next(line.removeprefix("oid sha256:") for line in pointer.splitlines() if line.startswith("oid sha256:"))
        qualification.require(qualification.sha(ROOT / rapier) == expected, "Pinned Windows Rapier must be materialized")
        shutil.copyfile(ROOT / rapier, source / rapier)
        # Keep the inherited runtime manifest explicitly labelled as a reference.
        retained = source / "godot/addons/cybersand_native/runtime-provenance.json"
        retained.rename(retained.with_name("retained-runtime-provenance.reference.json"))
        # This evaluator retains the complete source tree. Workbench already
        # discovers its tracked examples/worldgen directory; adding duplicate
        # untracked project recipes would violate the execution source receipt.
        recipes = sorted((source / "examples/worldgen").glob("*.json"))
        qualification.require({"gen007-deepworks.json", "gen007-qualification.json"} <=
                              {path.name for path in recipes}, "Required generator profiles are missing")
        qualification.require(all(path.stat().st_size <= 1024 * 1024 and
                                  isinstance(json.loads(path.read_text(encoding="utf-8")), dict)
                                  for path in recipes), "Invalid bundled generator profile")
        profiles = {path.name: qualification.sha(path) for path in recipes}
        for engine in (args.engine, console):
            shutil.copyfile(engine, package / engine.name)
        for name in NOTICES:
            shutil.copyfile(args.engine_notices / name, package / ("Godot-" + name))
        vc_runtime = stage_vc_runtime(args.vc_runtime, package)
        dependencies = package / "dependencies"
        dependencies.mkdir()
        lab.copy_python(args.python_root, dependencies / "python")
        lab.copy_git(args.git_root, dependencies / "git")
        lab.copy_portable_tree(args.compiler_root, dependencies / "cxx")
        shutil.copytree(args.candidate, package / "qualification/candidate")
        shutil.copytree(args.evidence, package / "qualification/source-execution", ignore=shutil.ignore_patterns("userdata"))
        (package / "Open Workbench.cmd").write_bytes(launcher(candidate["source_commit"]))
        (package / "Open Materials Lab.cmd").write_bytes(launcher(candidate["source_commit"], laboratory=True))
        (package / "README.txt").write_text(
            "CyberSand - current-scene material audition\n\n"
            "Extract the whole ZIP into a writable folder and run Open Workbench.cmd.\n"
            "Open Materials Lab in Workbench, then Current scene. Select a supported property,\n"
            "edit its draft value and Apply. The current native World continues. Revert\n"
            "configuration restores settings, not cells consumed or moved by simulation.\n"
            "Quick trial: select 024 / brine, scroll to Demonstration scene and choose\n"
            "Brine flow channels. Load demo asks for confirmation because it replaces the\n"
            "scene. Wait for its acknowledgement, then choose Use active as draft. Apply\n"
            "viscosity 240, start Play, then Apply 0 while playing and watch the covered\n"
            "channels and drops. Apply keeps the same World; Revert restores 240 without\n"
            "moving flowed cells back. Reset to accepted defaults restores Brine 32.\n\n"
            "Save named profile saves the draft; first use Active as draft to save active\n"
            "values. Load named profile prepares a draft and still requires Apply.\n"
            "Authored scene saves and material\n"
            "profiles are separate; a scene save is not a live simulation checkpoint.\n\n"
            "The existing Inspect and isolated comparison facilities are retained. Python,\n"
            "Git history and a C++ compiler are included for isolated candidate authoring.\n"
            "The first launch imports the project. Keep source and dependencies together.\n\n"
            f"Source: {candidate['source_commit']}\nNative DLL SHA-256: {candidate['native_sha256']}\n"
            "Original Windows qualification: qualification/source-execution/.\n"
            "This is a Draft/HOLD evaluator. Physical Windows/GPU playfeel and owner\n"
            "acceptance remain separate. Canonical material defaults are unchanged.\n"
            "Implementation and decision packet: https://github.com/techrote/cybersand/pull/768\n"
            "Consumer map: source/docs/systems/material-audition-consumers.md\n", encoding="utf-8")
        identity = {"schema": "cybersand.material-audition.evaluator", "schema_version": 1,
                    "platform": "windows", "source_commit": candidate["source_commit"],
                    "source_tree": candidate["source_tree"], "native_sha256": candidate["native_sha256"],
                    "godot_version": version, "source_history": history,
                    "vc_runtime_sha256": vc_runtime, "generator_profiles_sha256": profiles,
                    "default_profile_active": True, "scene_local_audition_supported": True,
                    "canonical_defaults_changed": False, "human_acceptance": "OWNER-PENDING",
                    "tools_sha256": {"python": qualification.sha(dependencies / "python/python.exe"),
                                     "compiler": qualification.sha(dependencies / "cxx/bin/g++.exe")},
                    "files_sha256": files(package)}
        qualification.write(package / MANIFEST, identity)
        verify(package)
        package.rename(args.output)
    return args.output


def verified_launcher(directory: Path, manifest: dict, recorded: dict) -> dict:
    process = json.loads((directory / "shipped-launcher.receipt.json").read_text(encoding="utf-8"))
    qualification.require(process == recorded.get("process") and process.get("status") == "passed" and
                          type(process.get("exit_code")) is int and process["exit_code"] == 0,
                          "Shipped launcher process receipt is inconsistent or failed")
    log = directory / "shipped-launcher.log"
    qualification.require(process.get("log_sha256") == qualification.sha(log) and
                          not qualification.ERRORS.search(log.read_text(encoding="utf-8",errors="replace")),
                          "Shipped launcher process log is inconsistent or failed")
    result = json.loads((directory / "shipped-launcher-native.json").read_text(encoding="utf-8"))
    qualification.require(result.get("schema") == "cybersand.material-audition.launcher" and
                          result.get("schema_version") == 1 and result.get("status") == "passed" and
                          result.get("failures") == 0 and result.get("nonce") == recorded.get("nonce") and
                          isinstance(recorded.get("nonce"),str) and len(recorded["nonce"]) == 32,
                          "Shipped launcher did not produce its nonce-bound readiness receipt")
    qualification.require(result.get("source_commit") == manifest["source_commit"] and
                          result.get("native_sha256") == manifest["native_sha256"] and
                          result.get("display") not in (None,"","headless") and
                          result.get("workbench_visible") is True and
                          result.get("host_scene") == "res://main.tscn" and
                          isinstance(result.get("world_id"),str) and result["world_id"].isdigit() and int(result["world_id"]) > 0 and
                          result.get("configuration_revision") == 0 and result.get("native_world_generation",0) > 0 and
                          result.get("profile",{}).get("materials") == [] and result.get("profile",{}).get("reactions") == [],
                          "Shipped launcher did not observe the actual ordinary native Workbench at defaults")
    engine_log = (directory / "shipped-launcher-engine.log").read_text(encoding="utf-8",errors="replace")
    qualification.require(not qualification.ERRORS.search(engine_log) and
                          qualification.completion(engine_log,"MATERIAL_AUDITION_LAUNCHER_RESULT") == result,
                          "Shipped launcher engine log does not corroborate its original readiness receipt")
    frame = result.get("frame",{})
    qualification.require(frame.get("file") == "shipped-launcher-native.png", "Shipped launcher frame path mismatch")
    png = directory / frame["file"]
    header = png.read_bytes()[:24]
    qualification.require(frame.get("sha256") == qualification.sha(png) and len(header) == 24 and
                          header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR" and
                          struct.unpack(">II",header[16:24]) == (frame.get("width"),frame.get("height")) and
                          frame.get("width",0) >= 400 and frame.get("height",0) >= 300,
                          "Shipped launcher graphical frame is missing or inconsistent")
    return result


def verify_extracted_execution(evidence: Path, candidate: dict, archive: Path,
                              *, candidate_digest: str | None = None, godot_digest: str | None = None) -> dict:
    report = json.loads((evidence / "package-execution.json").read_text(encoding="utf-8"))
    qualification.require(report.get("status") == "passed" and report.get("relocated_zip_executed") is True and
                          report.get("relocated_with_bundled_tools") is True,
                          "Actual relocated ZIP execution is required")
    recorded = report.get("delivered_archive",{})
    qualification.require(recorded.get("sha256") == qualification.sha(archive) and recorded.get("bytes") == archive.stat().st_size,
                          "Delivered archive differs from the extracted and executed ZIP")
    with zipfile.ZipFile(archive) as zipped:
        package_identity = zipped.read(MANIFEST)
    qualification.require(report.get("package_manifest_sha256") == hashlib.sha256(package_identity).hexdigest(),
                          "Extracted evaluator manifest identity mismatch")
    verified_execution(evidence,candidate,graphical=True,candidate_digest=candidate_digest,godot_digest=godot_digest)
    inventory = report.get("files_sha256",{})
    for name, digest in inventory.items():
        relative = Path(name)
        qualification.require(not relative.is_absolute() and ".." not in relative.parts and
                              qualification.sha(evidence / relative) == digest,"Original extracted-package evidence changed: " + name)
    required = {"shipped-launcher.log","shipped-launcher.receipt.json","shipped-launcher-native.json",
                "shipped-launcher-native.png","shipped-launcher-engine.log"}
    qualification.require(required <= set(inventory),"Original shipped-launcher evidence is incomplete")
    verified_launcher(evidence,candidate,report.get("shipped_launcher",{}))
    for name,marker in (("test_material_lab_ui","MATERIAL_LAB_UI:"),("test_material_lab_world","Materials Lab World UI:")):
        base = "isolated-" + name
        qualification.require({base+".log",base+".receipt.json"} <= set(inventory),"Bundled isolated-authoring receipts are incomplete")
        receipt = json.loads((evidence / (base+".receipt.json")).read_text(encoding="utf-8"))
        text = (evidence / (base+".log")).read_text(encoding="utf-8",errors="replace")
        qualification.require(receipt == report.get("isolated_authoring",{}).get(name) and
                              receipt.get("status") == "passed" and type(receipt.get("exit_code")) is int and receipt["exit_code"] == 0 and
                              receipt.get("log_sha256") == qualification.sha(evidence / (base+".log")) and
                              not qualification.ERRORS.search(text) and receipt.get("completion") == qualification.completion(text,marker),
                              "Bundled isolated-authoring execution is inconsistent or failed")
    return report


def smoke(package: Path, evidence: Path, archive: Path) -> dict:
    package,evidence,archive = package.resolve(),evidence.resolve(),archive.resolve()
    identity = verify(package)
    qualification.require(os.name == "nt", "Extracted evaluator execution requires Windows")
    qualification.require(not evidence.exists(), "Choose a new immutable package evidence directory")
    qualification.require(not archive.exists() and not archive.is_relative_to(package) and archive.suffix == ".zip",
                          "Choose a new delivered ZIP outside the source package")
    archive.parent.mkdir(parents=True,exist_ok=True)
    produced = Path(shutil.make_archive(str(archive.with_suffix("")),"zip",package))
    qualification.require(produced == archive,"Delivered ZIP path mismatch")
    archive_identity = {"file":archive.name,"sha256":qualification.sha(archive),"bytes":archive.stat().st_size}
    with tempfile.TemporaryDirectory(prefix="CyberSand Material Audition Relocated ") as temporary:
        copied = Path(temporary) / "writable evaluation"
        copied.mkdir()
        with zipfile.ZipFile(archive) as zipped:
            for entry in zipped.infolist():
                name = Path(entry.filename)
                qualification.require(not name.is_absolute() and ".." not in name.parts,"Unsafe delivered ZIP member")
            zipped.extractall(copied)
        verify(copied)
        result = qualification.execute(
            copied / "source", copied / "qualification/candidate",
            copied / "Godot_v4.7-stable_win64_console.exe", evidence, graphical=True,
            inherited_environment=lab.dependency_environment(copied))
        # Exercise the existing external authoring UI and compiled Worlds using
        # only the shipped tools. These are separate from live-scene witnesses.
        environment = lab.dependency_environment(copied)
        environment.update(APPDATA=str(evidence / "isolated-userdata"), XDG_DATA_HOME=str(evidence / "isolated-userdata"),
                           CYBERSAND_SOURCE_REVISION=identity["source_commit"])
        result["isolated_authoring"] = {}
        for name, marker in (("test_material_lab_ui", "MATERIAL_LAB_UI:"),
                             ("test_material_lab_world", "Materials Lab World UI:")):
            command = [str(copied / "Godot_v4.7-stable_win64_console.exe"), "--headless", "--path",
                       str(copied / "source/godot"), "--script", "res://tests/" + name + ".gd"]
            result["isolated_authoring"][name] = qualification.run_process(command, evidence / ("isolated-" + name + ".log"), environment, 1800, marker)
        # Execute the exact shipped .cmd, including its own dependency setup and
        # headless import, then witness the actual ordinary Workbench startup.
        nonce = secrets.token_hex(16)
        environment.update(APPDATA=str(evidence / "launcher-userdata"),XDG_DATA_HOME=str(evidence / "launcher-userdata"),
                           MAT_AUDITION_LAUNCHER_RECEIPT=str(evidence / "shipped-launcher-native.json"),
                           MAT_AUDITION_LAUNCHER_NONCE=nonce)
        command = [str(copied / "Open Workbench.cmd"),"--quit-after","1800","--max-fps","30",
                   "--log-file",str(evidence / "shipped-launcher-engine.log")]
        process = qualification.run_process(command,evidence / "shipped-launcher.log",environment,300)
        result["shipped_launcher"] = {"nonce":nonce,"process":process}
        verified_launcher(evidence,identity,result["shipped_launcher"])
    verify(package)
    result["package_manifest_sha256"] = qualification.sha(package / MANIFEST)
    result["relocated_with_bundled_tools"] = True
    result["relocated_zip_executed"] = True
    result["delivered_archive"] = archive_identity
    result["files_sha256"] = {path.relative_to(evidence).as_posix(): qualification.sha(path)
                               for path in sorted(evidence.rglob("*")) if path.is_file() and
                               path.name not in {"execution.json", "package-execution.json"} and
                               not any("userdata" in part for part in path.relative_to(evidence).parts)}
    qualification.write(evidence / "package-execution.json", result)
    candidate = json.loads((package / "qualification/candidate" / qualification.MANIFEST).read_text(encoding="utf-8"))
    verify_extracted_execution(evidence,candidate,archive,
        candidate_digest=qualification.sha(package / "qualification/candidate" / qualification.MANIFEST),
        godot_digest=qualification.sha(package / "Godot_v4.7-stable_win64_console.exe"))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "verify", "smoke"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--python-root", type=Path, default=Path(sys.base_prefix))
    parser.add_argument("--git-root", type=Path, default=Path(r"C:\Program Files\Git"))
    parser.add_argument("--compiler-root", type=Path, default=Path(r"C:\mingw64"))
    args = parser.parse_args()
    if args.command == "build":
        qualification.require(all(getattr(args, name) is not None for name in
                                  ("candidate", "evidence", "engine", "engine_notices", "vc_runtime")),
                              "Build requires qualified candidate/evidence, pinned engine/notices and licensed VC runtime")
        build(args)
    elif args.command == "smoke":
        qualification.require(args.evidence is not None and args.archive is not None,"Smoke requires a new evidence directory and delivered ZIP path")
        smoke(args.output, args.evidence, args.archive)
    else:
        verify(args.output)
    print(json.dumps({"status": "passed", "command": args.command, "output": str(args.output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
