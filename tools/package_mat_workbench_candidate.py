#!/usr/bin/env python3
"""Compose the existing standalone Lab and Workbench evaluation deliveries."""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import mat_workbench_runtime_publication as publication
import native_candidate_identity
import run_workbench_qualification as wb
from package_explore001_candidate import stage_generator_profiles, stage_vc_runtime, verify_vc_runtime

_spec = spec_from_file_location("_mat_workbench_private_packager", Path(__file__).with_name("package_materials_lab_candidate.py"))
lab = module_from_spec(_spec)
_spec.loader.exec_module(lab)
lab.publication = publication
lab.engine = publication.engine
engine = publication.engine
MANIFEST = lab.MANIFEST


def workbench_launcher(lab_launcher: str) -> str:
    old = 'res://materials_lab.tscn'
    engine.require(lab_launcher.count(old) == 1, "Expected the existing Materials Lab launcher entry once")
    return lab_launcher.replace(old, '-- --workbench')


def verify(package: Path) -> dict:
    identity = lab.verify_package(package)
    engine.require(identity.get("integration_scope") == "MAT-AUTH #562 + Integrated Workbench #564",
                   "Combined evaluation identity is missing")
    vc = verify_vc_runtime(package)
    engine.require(identity.get("vc_runtime_sha256") == vc["files_sha256"]["vcruntime140.dll"],
                   "Combined package VC runtime differs")
    inventories = [{p.name: lab.sha(p) for p in (package / "source" / name).glob("*.json")}
                   for name in ("examples/worldgen", "godot/authoring/worldgen")]
    engine.require(bool(inventories[0]) and inventories[0] == inventories[1] == identity.get("generator_profiles_sha256"),
                   "Combined package generator profiles are missing or different")
    expected = workbench_launcher((package / "Open-Materials-Lab.cmd").read_bytes().decode("utf-8"))
    engine.require((package / "Open Workbench.cmd").read_bytes().decode("utf-8") == expected,
                   "Workbench launcher lost bundled authoring environment or source identity")
    return identity


def build(args) -> Path:
    package = lab.build(args)
    identity = lab.verify_package(package)
    profiles = stage_generator_profiles(package / "source")
    vc_sha = stage_vc_runtime(args.vc_runtime, package)
    launcher = (package / "Open-Materials-Lab.cmd").read_bytes().decode("utf-8")
    (package / "Open Workbench.cmd").write_bytes(workbench_launcher(launcher).encode("utf-8"))
    (package / "README.txt").write_text(
        "CyberSand combined Materials Lab + Workbench evaluation\n\n"
        "Extract the complete archive into a writable folder. Run Open Workbench.cmd.\n"
        "The first launch imports the project. Keep source and dependencies together.\n"
        "Open Materials Lab from Workbench, or use Open-Materials-Lab.cmd.\n"
        "Godot, Python, Git, C++ tools, source history and runtime dependencies are included.\n\n"
        "Acceptance (use Undo/Redo while paused):\n"
        "1. Generate and install a map; check the Profile list is populated.\n"
        "2. Alternate manual paint and bounded agent edits; Undo and Redo both in order.\n"
        "3. Stop a longer agent draw, undo its completed prefix, then keep painting.\n"
        "4. Open Materials Lab, inspect/edit/validate an admitted material, run its isolated World,\n"
        "   save and reopen a preset, then return to the unchanged Workbench and its edit history.\n"
        "5. Exercise simulation and equipment; pause, save a named start, exit completely,\n"
        "   reopen/load and check terrain, actors/settings and continued editing.\n\n"
        "Material candidates run in isolated native Worlds; production installation is outside this build.\n"
        "Undo history is session-local; the resulting authored layout persists. Simulation and\n"
        "World replacement retire unsafe history. Saves retain existing authored-start semantics.\n\n"
        f"Source: {identity['source_commit']}\nNative DLL SHA-256: {identity['native_sha256']}\n"
        "Original platform evidence: qualification/. Full instructions: source/docs/operations/.\n"
        "This is an evaluation candidate; owner desktop acceptance and merge approval are separate.\n",
        encoding="utf-8")
    identity.update(integration_scope="MAT-AUTH #562 + Integrated Workbench #564",
                    generator_profiles_sha256=profiles, vc_runtime_sha256=vc_sha,
                    files_sha256=lab.file_map(package))
    (package / MANIFEST).write_bytes(lab.canonical(identity))
    verify(package)
    return package


def smoke(package: Path, evidence: Path) -> dict:
    identity = verify(package)
    # The unchanged Lab qualification includes real compiled candidate Worlds and
    # native contacts from a disposable copy with only bundled prerequisites.
    lab.smoke(package, evidence / "materials-lab")
    report = {"schema": "mat-workbench-package-execution-v1", "source_commit": identity["source_commit"],
              "native_sha256": identity["native_sha256"], "completed": False, "status": "running"}
    report_path = evidence / "combined-package-execution.json"
    engine.write_json(report_path, report)
    original_root = wb.ROOT
    try:
        with tempfile.TemporaryDirectory(prefix="CyberSand Combined Evaluation ") as temporary:
            root = Path(temporary)
            candidate = root / "evaluation"
            shutil.copytree(package, candidate)
            environment = lab.dependency_environment(candidate)
            source = candidate / "source"
            wb.ROOT = source
            godot = candidate / "Godot_v4.7-stable_win64_console.exe"
            runner = wb.Runner(argparse.Namespace(godot=godot, evidence=evidence / "combined"))
            runner.env.update(environment)
            runner.env["APPDATA"] = str(runner.evidence / "userdata")
            runner.env["XDG_DATA_HOME"] = str(runner.evidence / "userdata")
            runner.godot(source / "godot", "combined-import")
            wb.combined_authoring(runner, source / "godot", "delivered-combined-1024", side=1024)
            publication.combined_lab_workbench(runner, source / "godot")
            for workers in (1, 4):
                runner.godot(source / "godot", f"delivered-agent-undo-{workers}", "test_art_undo", "ART_UNDO_RESULT",
                             env={"ART_UNDO_WORKERS": str(workers)})
            expected = ["combined-import", *[f"delivered-combined-1024-workers-{workers}-{phase}"
                        for workers in (1, 4) for phase in ("author", "reopen")],
                        *publication.integration_labels(), "delivered-agent-undo-1", "delivered-agent-undo-4"]
            publication.verify_results(evidence / "combined/results.json", expected)

            # Reuse the original installed profile-discovery negatives and exact
            # source manifest on a second view built from the delivered source.
            native_dir, notices = root / "native", root / "notices"
            native_dir.mkdir(); notices.mkdir()
            shutil.copyfile(source / native_candidate_identity.NATIVE, native_dir / Path(native_candidate_identity.NATIVE).name)
            native_candidate_identity.create(source, native_dir)
            for name in ("LICENSE.txt", "COPYRIGHT.txt"):
                shutil.copyfile(candidate / ("Godot-" + name), notices / name)
            command = [str(candidate / "dependencies/python/python.exe"),
                       str(source / "tools/package_explore001_candidate.py"),
                       "--engine", str(candidate / "Godot_v4.7-stable_win64.exe"),
                       "--engine-notices", str(notices), "--vc-runtime", str(candidate),
                       "--native-candidate", str(native_dir), "--output", str(root / "workbench-view"),
                       "--readme", "docs/operations/wb-art-paint-integrated-candidate.md"]
            result = subprocess.run(command, env=environment, cwd=source, text=True, capture_output=True, timeout=300)
            (evidence / "workbench-view-build.log").write_text(result.stdout + result.stderr, encoding="utf-8")
            engine.require(result.returncode == 0, "Delivered source could not build the installed Workbench view")
            wb.installed(argparse.Namespace(godot=godot, evidence=evidence / "installed", package=root / "workbench-view",
                                            scratch=root / "installed-copies", combined=True))
            publication.verify_results(evidence / "installed/results.json", publication.installed_labels())
            powershell = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/WindowsPowerShell/v1.0/powershell.exe"
            subprocess.run([str(powershell), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                            str(source / "tools/ci/check_windows_package_modules.ps1"), "-Package", str(candidate),
                            "-Combined", "-Evidence", str((evidence / "runtime-modules.json").resolve())],
                           env=environment, cwd=source, check=True, timeout=180)
        verify(package)
        report.update(status="passed", completed=True)
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        wb.ROOT = original_root
        report["files_sha256"] = {p.relative_to(evidence).as_posix(): lab.sha(p)
                                   for p in sorted(evidence.rglob("*")) if p.is_file() and p != report_path}
        engine.write_json(report_path, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "verify", "smoke"])
    parser.add_argument("--source-sha")
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--python-root", type=Path, default=Path(sys.base_prefix))
    parser.add_argument("--git-root", type=Path, default=Path(r"C:\Program Files\Git"))
    parser.add_argument("--compiler-root", type=Path, default=Path(r"C:\mingw64"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        if any(value is None for value in (args.source_sha, args.bundle, args.godot_archive, args.engine_notices, args.vc_runtime)):
            parser.error("Build requires source, qualified bundle, Godot archive/notices and verified VC runtime")
        build(args)
    elif args.command == "smoke":
        if args.evidence is None: parser.error("Smoke evidence directory is required")
        smoke(args.output, args.evidence)
    else:
        verify(args.output)
    print(json.dumps({"status": "passed", "command": args.command, "output": str(args.output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
