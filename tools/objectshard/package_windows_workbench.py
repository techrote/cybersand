#!/usr/bin/env python3
"""Seal a portable, opt-in ordinary Workbench evaluator from exact source."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import sys

from package_windows_lab import ROOT, copy_committed_tree, git, native, sha, stage_vc_runtime, verify_vc_runtime, windows
from verify_workbench_package import (CANDIDATE_PROVENANCE, CANDIDATE_REUSE_PROVENANCE, ENTRY, MANIFEST, RENDERING_DRIVER,
                                      RETAINED_PROVENANCE, RETAINED_REFERENCE, SCHEMA, verify)


def launchers(source: str) -> dict[str, str]:
    if not re.fullmatch(r"[0-9a-f]{40}", source):
        raise ValueError("A full source identity is required")
    common = ('@echo off\nsetlocal DisableDelayedExpansion\n'
              'set "OBJECTSHARD_PACKAGE_ROOT=%~dp0."\n'
              'cd /d "%OBJECTSHARD_PACKAGE_ROOT%"\nif errorlevel 1 exit /b 1\n'
              'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%OBJECTSHARD_PACKAGE_ROOT%\\tools\\objectshard\\verify_workbench_package.ps1" -Package "%OBJECTSHARD_PACKAGE_ROOT%"\n'
              'if errorlevel 1 goto failed\n')
    failure = ('\n:failed\necho Workbench could not start. See the message above.\n'
               'if /i not "%~1"=="--self-test" if /i not "%~1"=="--noninteractive" pause\nexit /b 1\n')
    graphical = ('"%OBJECTSHARD_PACKAGE_ROOT%\\Godot_v4.7-stable_win64.exe" '
                 f'--rendering-driver {RENDERING_DRIVER} --path "%OBJECTSHARD_PACKAGE_ROOT%\\godot"')
    workbench = '-- --shared-workbench --objectshard-m4-workbench --object-shard-scene=tower'
    launch = (common + f'set "CYBERSAND_SOURCE_REVISION={source}"\n'
              'set "CYBERSAND_PACKAGE_MANIFEST=%OBJECTSHARD_PACKAGE_ROOT%\\objectshard-workbench-manifest.json"\n'
              '"%OBJECTSHARD_PACKAGE_ROOT%\\Godot_v4.7-stable_win64_console.exe" --headless --path "%OBJECTSHARD_PACKAGE_ROOT%\\godot" --editor --quit\n'
              'if errorlevel 1 goto failed\n'
              'if /i "%~1"=="--self-test" goto selftest\n'
              f'start "CyberSand Workbench" {graphical} {workbench}\n'
              'exit /b %errorlevel%\n'
              '\n:selftest\nif not defined OBJECTSHARD_LAUNCH_RECEIPT goto failed\n'
              f'start "Workbench launch qualification" /wait {graphical} --script res://tests/probe_object_shard_workbench_package.gd {workbench}\n'
              'if errorlevel 1 goto failed\nexit /b 0\n' + failure)
    verifier = common + 'if /i not "%~1"=="--noninteractive" pause\nexit /b 0\n' + failure
    return {"Open Workbench.cmd": launch, "Verify Workbench.cmd": verifier}


def package(args: argparse.Namespace) -> dict:
    if args.output.exists():
        raise ValueError("Refusing to overwrite an evaluator")
    candidate = native.verify(ROOT, args.native_candidate)
    git("diff", "--exit-code", "HEAD", "--", "godot", "tools/objectshard", args.guide,
        ":!godot/addons/*/bin/*", ":!godot/.godot/*")
    engine, engine_identity = windows.prepare_godot(args.godot_archive)
    verify_vc_runtime(args.vc_runtime)
    if sha(ROOT / windows.RAPIER) != windows.RAPIER_SHA256:
        raise ValueError("Rapier does not match the admitted runtime")
    args.output.mkdir(parents=True)
    copy_committed_tree(args.output, args.native_candidate, args.guide)
    for name in ("Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe"):
        shutil.copyfile(engine.parent / name, args.output / name)
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        shutil.copyfile(args.engine_notices / name, args.output / ("Godot-" + name))
    vc_hash = stage_vc_runtime(args.vc_runtime, args.output)
    shutil.copyfile(args.native_candidate / native.NAME, args.output / CANDIDATE_PROVENANCE)
    reuse_receipt = args.native_candidate / native.REUSE_NAME
    if reuse_receipt.is_file():
        shutil.copyfile(reuse_receipt, args.output / CANDIDATE_REUSE_PROVENANCE)
    (args.output / RETAINED_PROVENANCE).rename(args.output / RETAINED_REFERENCE)
    shutil.copyfile(args.output / args.guide, args.output / "READ-ME.md")
    for name, content in launchers(candidate["source_commit"]).items():
        (args.output / name).write_text(content, encoding="utf-8", newline="\r\n")
    identity = {"schema": SCHEMA, "purpose": "Draft/HOLD ordinary Workbench owner evaluator; not a production release",
                "source_commit": candidate["source_commit"], "source_tree": candidate["source_tree"],
                "native": {"path": native.NATIVE, "sha256": candidate["sha256"], "source_inputs": candidate["source_inputs"]},
                "godot": engine_identity, "rapier": {"path": windows.RAPIER, "sha256": windows.RAPIER_SHA256},
                "vc_runtime_sha256": vc_hash, "ordinary_production_defaults_changed": False,
                "physical_owner_acceptance": "OWNER-PENDING: Windows 11/NVIDIA display and playfeel",
                "entry": ENTRY,
                "files_sha256": {p.relative_to(args.output).as_posix(): sha(p)
                                 for p in sorted(args.output.rglob("*")) if p.is_file()}}
    (args.output / MANIFEST).write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify(args.output)
    return identity


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("native-candidate", "godot-archive", "engine-notices", "vc-runtime", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--guide", default="docs/operations/objectshard-workbench-playtest.md")
    args = parser.parse_args()
    guide = Path(args.guide)
    if guide.is_absolute() or ".." in guide.parts or guide.suffix != ".md":
        raise ValueError("Guide must be a committed repository-relative Markdown path")
    result = package(args)
    print(json.dumps({"source_commit": result["source_commit"], "verified_files": len(result["files_sha256"]),
                      "launcher": str(args.output / "Open Workbench.cmd")}, indent=2))
