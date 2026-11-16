#!/usr/bin/env python3
"""Package the exact opt-in RENDER-UPLOAD-577 Workbench source for Windows."""
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
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
from run_windows_godot_regressions import verify_retained_runtime, GODOT_VERSION, GODOT_SHA512

BASE = "018bd09503d7f079ddac52e225c2f7daf8d678bf"
MANIFEST = "RENDER-UPLOAD-577-MANIFEST.json"
ENGINE = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
PRESERVED = ("native", "godot/native_extension", "godot/addons/cybersand_native",
             "godot/addons/godot-rapier2d", "godot/shaders/material_palette.gdshader",
             "godot/shaders/material_emission.gdshader", "godot/shaders/material_vapour_trail.gdshader",
             "third_party/native-toolchain.lock.json", "third_party/godot-runtime.lock.json")


def need(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def digest(path: Path, algorithm: str = "sha256") -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=120).strip()


def safe_path(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    need(bool(value) and not path.is_absolute() and str(path) == value
         and ".." not in path.parts and "\\" not in value, "Unsafe package path " + value)
    for part in path.parts:
        need(not re.search(r'[<>:"|?*\x00-\x1f]', part) and not part.endswith((".", " "))
             and not re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", part),
             "Windows-incompatible path " + value)
    return path


def files_map(folder: Path) -> dict[str, str]:
    return {p.relative_to(folder).as_posix(): digest(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p.relative_to(folder).as_posix() != MANIFEST}


def preflight(source: str) -> dict:
    need(bool(re.fullmatch(r"[0-9a-f]{40}", source)) and git("rev-parse", "HEAD") == source,
         "An exact checked-out source SHA is required")
    subprocess.run(["git", "merge-base", "--is-ancestor", BASE, source], cwd=ROOT, check=True)
    subprocess.run(["git", "diff", "--exit-code", BASE, source, "--", *PRESERVED], cwd=ROOT, check=True)
    # Package files come from Git, but a changed package builder must not claim
    # the committed source or silently introduce unpublished launcher logic.
    subprocess.run(["git", "diff", "--exit-code", source, "--", "godot", "tools/render_upload_577"],
                   cwd=ROOT, check=True)
    canonical = subprocess.check_output(["git", "show", source + ":tools/render_upload_577/package_windows.py"], cwd=ROOT)
    need(Path(__file__).read_bytes().replace(b"\r\n", b"\n") == canonical.replace(b"\r\n", b"\n"),
         "Package builder differs from exact committed source")
    verify_retained_runtime(ROOT)
    native = json.loads((ROOT / "godot/addons/cybersand_native/runtime-provenance.json").read_text())
    rapier = json.loads((ROOT / "godot/addons/godot-rapier2d/runtime-provenance.windows.json").read_text())
    return {"source_commit": source, "source_tree": git("rev-parse", source + "^{tree}"),
            "accepted_main": BASE, "native": native, "rapier": rapier,
            "owner_physical_gpu_acceptance": "pending"}


def stage_source(output: Path, identity: dict) -> None:
    source = identity["source_commit"]
    paths = ["godot", "examples/worldgen", "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md",
             "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
             "third_party/rapier-bvh-build.lock.json", "tools/render_upload_577/Test-It.ps1"]
    paths += list(identity["native"]["source_inputs"])
    paths += list(identity["rapier"]["source_inputs"])
    body = subprocess.check_output(["git", "archive", "--format=tar", source, "--", *sorted(set(paths))],
                                   cwd=ROOT, timeout=120)
    with tarfile.open(fileobj=io.BytesIO(body)) as archive:
        for member in archive:
            if not member.isfile():
                continue
            safe_path(member.name)
            if member.name.startswith("godot/.godot/"):
                continue
            if (Path(member.name).suffix.lower() in {".dll", ".so", ".dylib", ".wasm"}
                    or ".framework/" in member.name) and member.name not in {NATIVE, RAPIER}:
                continue
            stream = archive.extractfile(member)
            need(stream is not None, "Unreadable source file " + member.name)
            data = (ROOT / member.name).read_bytes() if member.name in {NATIVE, RAPIER} else stream.read()
            need(not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"),
                 "Unresolved LFS file " + member.name)
            target = output / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    profiles = output / "godot/authoring/worldgen"
    profiles.mkdir(parents=True, exist_ok=True)
    recipes = sorted((output / "examples/worldgen").glob("*.json"))
    need({"gen007-deepworks.json", "gen007-qualification.json"} <= {p.name for p in recipes},
         "Generator profiles missing")
    for recipe in recipes:
        need(isinstance(json.loads(recipe.read_text()), dict), "Invalid generator profile")
        shutil.copyfile(recipe, profiles / recipe.name)


def stage_dependencies(output: Path, engine_zip: Path, notices: Path, vc: Path) -> None:
    need(digest(engine_zip, "sha512") == GODOT_SHA512, "Pinned Godot archive mismatch")
    with zipfile.ZipFile(engine_zip) as archive:
        need(archive.testzip() is None, "Godot archive CRC failed")
        for name in (ENGINE, CONSOLE):
            (output / name).write_bytes(archive.read(name))
    version = subprocess.check_output([str(output / CONSOLE), "--version"], text=True, timeout=45).strip()
    need(version == GODOT_VERSION, "Actual packaged Godot version mismatch")
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        shutil.copyfile(notices / name, output / ("Godot-" + name))
    proof = json.loads((vc / "vc-runtime-provenance.json").read_text(encoding="utf-8-sig"))
    need(proof.get("schema") == 1 and proof.get("authenticode", {}).get("status") == "Valid",
         "Signed VC runtime provenance missing")
    need(set(proof["files_sha256"]) == {"vcruntime140.dll", "Microsoft-Visual-C-Runtime-LICENSE.docx",
                                       "Microsoft-Visual-Studio-2022-LICENSE.docx"},
         "Unexpected VC runtime inventory")
    for name, expected in proof["files_sha256"].items():
        safe_path(name)
        need(digest(vc / name) == expected, "VC dependency changed: " + name)
        shutil.copyfile(vc / name, output / name)
    shutil.copyfile(vc / "vc-runtime-provenance.json", output / "vc-runtime-provenance.json")


def launchers(output: Path, source: str) -> None:
    for name, strategy in (("Open Workbench.cmd", "full"), ("Open Baseline Workbench.cmd", "full"),
                           ("Open Candidate Workbench.cmd", "hybrid")):
        data = ('@echo off\nsetlocal\ncd /d "%~dp0"\n'
                'set "CYBERSAND_SOURCE_REVISION=' + source + '"\n'
                'set "CYBERSAND_RENDER_UPLOAD="\n'
                'echo CyberSand Workbench - ' + strategy + ' material publication\n'
                '"%~dp0' + CONSOLE + '" --headless --path "%~dp0godot" --editor --quit\n'
                'if errorlevel 1 (echo Project import failed. & pause & exit /b 1)\n'
                'start "" "%~dp0' + ENGINE + '" --path "%~dp0godot" -- --workbench --render-upload=' + strategy + '\n')
        (output / name).write_bytes(data.replace("\n", "\r\n").encode())
    (output / "Test It.cmd").write_bytes(
        b'@echo off\r\ncd /d "%~dp0"\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\\render_upload_577\\Test-It.ps1" %*\r\nif errorlevel 1 pause\r\n')


GUIDE = """# CyberSand material publication evaluation

Source: {source_commit}
Tree: {source_tree}
Accepted-main base: {accepted_main}

Extract this entire archive into a fresh writable folder. Godot 4.7, the native
and Rapier modules, Visual C++ runtime, generator profiles and notices are included.
No separate Python, Godot, Git or development tools are required.

* `Open Workbench.cmd` starts the unchanged full-image publication baseline.
* `Open Candidate Workbench.cmd` opts into hybrid sparse/dense publication and
  bounded pending-patch coalescing. Production defaults remain unchanged.
* `Open Baseline Workbench.cmd` explicitly selects the same control as the normal entry.
* `Test It.cmd` executes sequential matched ABBA captures and writes a portable
  evidence ZIP under `Test-It-Results`. `Test It.cmd -Quick` limits the campaign.

## Ordinary comparison

Save one authored start and use it for both launchers. Keep canvas size, solver,
worker count, window size, zoom, FPS and VSync identical. Close the application
between arms. Run baseline, candidate, candidate, baseline in that order.

1. On a paused 2048-square canvas, paint short repeated strokes and scattered dots.
   Watch response to a stroke and the longest visible pauses.
2. Generate a large architectural area. Fill/erase a large region, then Flatten,
   save, close and reopen. Dense/full publication must remain responsive and complete.
3. Run the same active Sand/Water scene with one and four workers. Try FreeMass,
   PressureFlow and Inertial Water separately, preserving every other setting.
4. Move a Rapier actor through terrain contact while panning and following the
   camera. Look for missing/new-old terrain patches, stale terrain, actor gaps
   and changes in physical progression.

The candidate uses partial drawable publication only while the bounded sparse
plan is worthwhile. Dense/full images use ordinary compact R8/RG8 ImageTexture
updates. Moving between resource types has explicit initialization cost; the
included evidence records transitions and negative cases. Shader/material laws,
native timestep and actor physics are unchanged.

CPU submission duration is not GPU completion time or measured bus traffic.
Hosted software graphics does not establish NVIDIA performance. Record Windows,
GPU/driver, CPU, display settings, perceived pauses and the generated evidence ZIP.
Owner physical acceptance and merge approval are still outstanding.
"""


def verify(folder: Path, source: str | None = None) -> dict:
    manifest = json.loads((folder / MANIFEST).read_text())
    need(manifest.get("schema") == "render-upload-577-windows-v1", "Wrong package manifest")
    if source:
        need(manifest.get("source_commit") == source, "Package source differs")
    need(files_map(folder) == manifest["files_sha256"], "Missing or changed package payload")
    for kind in ("native", "rapier"):
        runtime = manifest[kind]
        need(digest(folder / runtime["artifact"]) == runtime["sha256"], kind + " runtime mismatch")
        for name, expected in runtime["source_inputs"].items():
            safe_path(name)
            actual = hashlib.sha256((folder / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
            need(actual == expected, kind + " source ledger mismatch: " + name)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--godot-zip", type=Path)
    parser.add_argument("--notices", type=Path)
    parser.add_argument("--vc", type=Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    if args.verify:
        manifest = verify(output, args.source_sha)
        print("RENDER_UPLOAD_577_PACKAGE_VERIFIED", len(manifest["files_sha256"]), args.source_sha)
        return 0
    need(os.name == "nt", "Package and engine qualification must run on Windows")
    need(args.archive is not None and args.godot_zip and args.notices and args.vc,
         "Build requires archive, Godot ZIP, notices and staged VC runtime")
    need(not output.exists() and not args.archive.exists(), "Refusing to overwrite a package")
    identity = preflight(args.source_sha)
    output.mkdir(parents=True)
    stage_source(output, identity)
    stage_dependencies(output, args.godot_zip, args.notices, args.vc)
    launchers(output, args.source_sha)
    (output / "READ-ME.md").write_text(GUIDE.format(**identity), encoding="utf-8")
    identity.update(schema="render-upload-577-windows-v1", godot_version=GODOT_VERSION,
                    godot_zip_sha512=GODOT_SHA512, files_sha256=files_map(output))
    (output / MANIFEST).write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify(output, args.source_sha)
    paths = sorted(p for p in output.rglob("*") if p.is_file())
    names = [p.relative_to(output).as_posix() for p in paths]
    need(len(set(n.lower() for n in names)) == len(names) and max(map(len, names)) < 220,
         "Windows-incompatible archive names")
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path, name in zip(paths, names):
            archive.write(path, name)
    with zipfile.ZipFile(args.archive) as archive:
        need(archive.testzip() is None, "Package archive CRC failed")
    receipt = {"source_commit": args.source_sha, "source_tree": identity["source_tree"],
               "archive": args.archive.name, "sha256": digest(args.archive),
               "bytes": args.archive.stat().st_size, "files": len(paths),
               "owner_physical_gpu_acceptance": "pending"}
    args.archive.with_suffix(".zip.json").write_text(json.dumps(receipt, indent=2) + "\n")
    args.archive.with_suffix(".zip.sha256").write_text(receipt["sha256"] + "  " + args.archive.name + "\n")
    print("RENDER_UPLOAD_577_PACKAGE", json.dumps(receipt), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
