#!/usr/bin/env python3
"""Build an exact-source ObjectShard Lab evaluation directory, never a release.

Run on Windows after the source-matched candidate and Lab qualification. The
official pinned Godot ZIP is verified independently of its supplied filename.
No export templates, retained native DLL reuse, Git checkout metadata or local
editor state enter the package.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
sys.path.insert(0, str(ROOT / "tools"))
import native_candidate_identity as native
import run_windows_godot_regressions as windows
from package_explore001_candidate import stage_vc_runtime, verify_vc_runtime
from verify_package import verify as verify_package

MANIFEST = "objectshard-lab-manifest.json"


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=120)


def copy_committed_tree(destination: Path, candidate: Path, guide: str) -> None:
    paths = ["godot", "native/include", "native/src", "tools/objectshard", guide,
             "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
             "third_party/rapier-bvh-build.lock.json", "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
             "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"]
    with tarfile.open(fileobj=io.BytesIO(git("archive", "HEAD", "--", *paths))) as archive:
        for member in archive:
            if not member.isfile() or member.name.startswith("godot/.godot/"):
                continue
            if "/bin/" in member.name and member.name not in (native.NATIVE, windows.RAPIER):
                continue
            stream = archive.extractfile(member)
            assert stream is not None
            data = stream.read()
            if member.name == native.NATIVE:
                data = (candidate / Path(native.NATIVE).name).read_bytes()
            elif data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                data = (ROOT / member.name).read_bytes()
                if pointer is None or hashlib.sha256(data).hexdigest() != pointer[1].decode() or len(data) != int(pointer[2]):
                    raise ValueError("Unmaterialized or modified LFS payload: " + member.name)
            target = destination / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)


def package(args: argparse.Namespace) -> dict:
    if args.output.exists():
        raise ValueError("Refusing to overwrite an evaluation directory")
    candidate = native.verify(ROOT, args.native_candidate)
    # Packaging also binds scripts/scenarios/launchers, beyond the native ledger.
    git("diff", "--exit-code", "HEAD", "--", "godot", "tools/objectshard", args.guide,
        ":!godot/addons/*/bin/*", ":!godot/.godot/*")
    engine, engine_identity = windows.prepare_godot(args.godot_archive)
    verify_vc_runtime(args.vc_runtime)
    rapier = ROOT / windows.RAPIER
    if sha(rapier) != windows.RAPIER_SHA256:
        raise ValueError("Rapier bytes differ from the selected cooperative-BVH runtime")
    args.output.mkdir(parents=True)
    copy_committed_tree(args.output, args.native_candidate, args.guide)
    for filename in ["Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe"]:
        shutil.copyfile(engine.parent / filename, args.output / filename)
    for filename in ["LICENSE.txt", "COPYRIGHT.txt"]:
        shutil.copyfile(args.engine_notices / filename, args.output / ("Godot-" + filename))
    vc_hash = stage_vc_runtime(args.vc_runtime, args.output)
    shutil.copyfile(args.native_candidate / native.NAME, args.output / "source-built-candidate-provenance.json")
    retained = args.output / "godot/addons/cybersand_native/runtime-provenance.json"
    retained.rename(retained.with_name("retained-runtime-provenance.reference.json"))
    shutil.copyfile(args.output / args.guide, args.output / "READ-ME.md")
    verifier = args.output / "tools/objectshard/verify_package.ps1"
    if not verifier.is_file():
        raise ValueError("Committed package verifier is absent")
    source = candidate["source_commit"]
    launcher = (
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\\objectshard\\verify_package.ps1" -Package "%~dp0"\n'
        'if errorlevel 1 (echo Package verification FAILED. & pause & exit /b 1)\n'
        f'set CYBERSAND_SOURCE_REVISION={source}\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0godot" --editor --quit\n'
        'if errorlevel 1 (echo Godot import FAILED. & pause & exit /b 1)\n'
        'start "ObjectShard Lab" "%~dp0Godot_v4.7-stable_win64.exe" --path "%~dp0godot" res://object_shard_lab.tscn\n'
    )
    (args.output / "Open ObjectShard Lab.cmd").write_text(launcher, encoding="utf-8", newline="\r\n")
    (args.output / "Verify ObjectShard Lab.cmd").write_text(
        '@echo off\ncd /d "%~dp0"\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\\objectshard\\verify_package.ps1" -Package "%~dp0"\npause\n',
        encoding="utf-8", newline="\r\n")
    identity = {"schema": "objectshard-lab-package-v1", "purpose": "Draft/HOLD owner evaluation; not a production release",
                "source_commit": source, "source_tree": candidate["source_tree"],
                "native": {"path": native.NATIVE, "sha256": candidate["sha256"], "source_inputs": candidate["source_inputs"]},
                "godot": engine_identity, "rapier": {"path": windows.RAPIER, "sha256": windows.RAPIER_SHA256,
                    "provenance_sha256": sha(args.output / "godot/addons/godot-rapier2d/runtime-provenance.windows.json")},
                "vc_runtime_sha256": vc_hash, "scenario_schema": "objectshard-lab-v1",
                "capability_version": 1, "ordinary_production_defaults_changed": False,
                "physical_owner_acceptance": "not established by automated qualification",
                "files_sha256": {p.relative_to(args.output).as_posix(): sha(p)
                                 for p in sorted(args.output.rglob("*")) if p.is_file()}}
    (args.output / MANIFEST).write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify_package(args.output)
    return identity


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--godot-archive", type=Path, required=True)
    parser.add_argument("--engine-notices", type=Path, required=True)
    parser.add_argument("--vc-runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--guide", default="docs/operations/objectshard-lab-playtest.md")
    args = parser.parse_args()
    guide = Path(args.guide)
    if guide.is_absolute() or ".." in guide.parts or guide.suffix != ".md":
        raise ValueError("Guide must be a committed repository-relative Markdown path")
    result = package(args)
    print(json.dumps({"source_commit": result["source_commit"], "manifest": str(args.output / MANIFEST),
                      "launcher": str(args.output / "Open ObjectShard Lab.cmd")}, indent=2))


if __name__ == "__main__":
    main()
