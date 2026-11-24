#!/usr/bin/env python3
"""Build, verify and execute a portable current-scene Materials Lab evaluator.

Reuses the accepted Lab's offline source/history, Python, Git and compiler
packaging.  It has a distinct candidate manifest and never overwrites retained
runtime provenance or changes the canonical material catalogue.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import run_material_audition_qualification as qualification
import package_materials_lab_candidate as lab
from package_explore001_candidate import stage_generator_profiles, stage_vc_runtime, verify_vc_runtime

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


def verified_execution(directory: Path, manifest: dict, *, graphical: bool) -> dict:
    result = json.loads((directory / "execution.json").read_text(encoding="utf-8"))
    qualification.require(result.get("schema") == "cybersand.material-audition.execution" and
                          result.get("status") == "passed" and result.get("platform") == "windows" and
                          result.get("graphical") is graphical, "Actual Windows execution is required")
    for key in ("source_commit", "source_tree", "native_sha256"):
        qualification.require(result.get(key) == manifest.get(key), "Windows evidence identity mismatch: " + key)
    expected = {"import", *(name for name, _marker in qualification.CASES)}
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
    for name, marker in qualification.CASES:
        qualification.completion((directory / (name + ".log")).read_text(encoding="utf-8"), marker)
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
             '"%~dp0Godot_v4.7-stable_win64.exe" --rendering-method gl_compatibility --rendering-driver opengl3_angle --path "%~dp0source\\godot" ' + entry]
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
    verified_execution(package / "qualification/source-execution", candidate, graphical=True)
    return identity


def build(args: argparse.Namespace) -> Path:
    qualification.require(os.name == "nt", "Portable evaluator assembly requires actual Windows execution")
    candidate = qualification.verify(ROOT, args.candidate, "windows")
    qualification.require(not candidate.get("toolchain_drift", True), "Development toolchain drift cannot qualify the Windows evaluator")
    verified_execution(args.evidence, candidate, graphical=True)
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
        profiles = stage_generator_profiles(source)
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
            "Use the supplied demonstration starts, or experiment in your own authored scene.\n"
            "Save a named material profile explicitly. Authored scene saves and material\n"
            "profiles are separate; a scene save is not a live simulation checkpoint.\n\n"
            "The existing Inspect and isolated comparison facilities are retained. Python,\n"
            "Git history and a C++ compiler are included for isolated candidate authoring.\n"
            "The first launch imports the project. Keep source and dependencies together.\n\n"
            f"Source: {candidate['source_commit']}\nNative DLL SHA-256: {candidate['native_sha256']}\n"
            "Original Windows qualification: qualification/source-execution/.\n"
            "This is a Draft/HOLD evaluator. Physical Windows/GPU playfeel and owner\n"
            "acceptance remain separate. Canonical material defaults are unchanged.\n", encoding="utf-8")
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


def smoke(package: Path, evidence: Path) -> dict:
    identity = verify(package)
    qualification.require(os.name == "nt", "Extracted evaluator execution requires Windows")
    qualification.require(not evidence.exists(), "Choose a new immutable package evidence directory")
    with tempfile.TemporaryDirectory(prefix="CyberSand Material Audition Relocated ") as temporary:
        copied = Path(temporary) / "writable evaluation"
        shutil.copytree(package, copied)
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
        for name, marker in (("test_material_lab_ui", "MATERIAL_LAB_UI:"),
                             ("test_material_lab_world", "Materials Lab World UI:")):
            command = [str(copied / "Godot_v4.7-stable_win64_console.exe"), "--headless", "--path",
                       str(copied / "source/godot"), "--script", "res://tests/" + name + ".gd"]
            qualification.run_process(command, evidence / (name + ".log"), environment, 1800, marker)
    verify(package)
    result["package_manifest_sha256"] = qualification.sha(package / MANIFEST)
    result["relocated_with_bundled_tools"] = True
    result["files_sha256"] = {path.relative_to(evidence).as_posix(): qualification.sha(path)
                               for path in sorted(evidence.rglob("*")) if path.is_file() and
                               path.name not in {"execution.json", "package-execution.json"} and
                               not any("userdata" in part for part in path.relative_to(evidence).parts)}
    qualification.write(evidence / "package-execution.json", result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "verify", "smoke"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--evidence", type=Path)
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
        qualification.require(args.evidence is not None, "Smoke requires a new evidence directory")
        smoke(args.output, args.evidence)
    else:
        verify(args.output)
    print(json.dumps({"status": "passed", "command": args.command, "output": str(args.output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
