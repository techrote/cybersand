#!/usr/bin/env python3
"""ENG-LAB-001: exact-qualified Windows/NVIDIA real Needle benchmark owner ZIP.

Only packages a previously source-qualified Git commit, signed/pinned Godot,
committed and LFS-authenticated Godot project, and two explicit launchers.
The packager is not part of the application. No production default changes.
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
import sys
import tarfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
from run_windows_godot_regressions import (
    GODOT_VERSION, prepare_godot, verify_retained_runtime,
)

REQUIRED = (
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
)
SOURCE_SCOPES = ("godot", "examples/worldgen", "THIRD_PARTY_NOTICES.md",
                 "LICENSE_STATUS.md", "docs/operations/engine-lab-passive-benchmark.md",
                 "docs/operations/engine-lab-water-family-comparison.md",
                 "tools/engine_lab/run_water_family_matrix.py")
LFS_POINTER = re.compile(
    rb"version https://git-lfs.github.com/spec/v1\n"
    rb"oid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n"
)
BAD_LOG = re.compile(r"(?im)(?:SCRIPT ERROR:|Parse Error:|Failed to load script|Unable to open dynamic library)")


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args],
                                   timeout=60, text=True).strip()


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(cmd: list[str], log: Path, seconds: int) -> dict:
    begin = time.monotonic()
    result: dict = {"command": cmd, "timeout_s": seconds, "ok": False}
    try:
        p = subprocess.run(cmd, cwd=log.parent, timeout=seconds, text=True,
                           errors="replace", capture_output=True,
                           env={**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1"})
        output = p.stdout + "\n--- stderr ---\n" + p.stderr
        result.update(returncode=p.returncode,
                      ok=(p.returncode == 0 and BAD_LOG.search(output) is None))
    except subprocess.TimeoutExpired as exc:
        output = str(exc)
        result["error"] = "timeout"
    log.write_text(output, encoding="utf-8")
    result.update(elapsed_s=round(time.monotonic()-begin, 3), log_sha256=sha(log))
    return result


def stage_source(source_sha: str, destination: Path) -> dict:
    archive = subprocess.check_output(["git", "archive", "--format=tar", source_sha,
                                       "--", *SOURCE_SCOPES], cwd=ROOT, timeout=180)
    lfs_hashes = {}
    count = 0
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as tf:
        for entry in tf:
            if entry.isdir():
                continue
            if not entry.isfile():
                raise ValueError("Refusing a non-regular Git archive member: " + entry.name)
            path = PurePosixPath(entry.name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("Invalid archive path")
            # Godot discovers only Windows GDExtension libraries in this
            # evaluation. Do not ship unmaterialized Unix/WASM binary pointers.
            if ("/bin/" in f"/{entry.name}/" and
                    not entry.name in REQUIRED):
                continue
            if entry.name.startswith("godot/.godot/"):
                continue
            source = tf.extractfile(entry)
            if source is None:
                raise ValueError("Unreadable archive file: " + entry.name)
            data = source.read()
            match = LFS_POINTER.fullmatch(data)
            if match is not None:
                materialized = ROOT / entry.name
                data = materialized.read_bytes()
                if (len(data) != int(match[2]) or
                        hashlib.sha256(data).hexdigest() != match[1].decode()):
                    raise ValueError("Missing or mismatched LFS bytes: " + entry.name)
                lfs_hashes[entry.name] = match[1].decode()
            elif data.startswith(b"version https://git-lfs.github.com/spec/v1"):
                raise ValueError("Malformed LFS pointer: " + entry.name)
            output = destination / entry.name
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(data)
            count += 1
    for name in REQUIRED:
        output = destination / name
        if not output.exists() or not output.read_bytes().startswith(b"MZ"):
            raise ValueError("Windows PE runtime not materialized: " + name)
    profiles = sorted((destination / "examples/worldgen").glob("*.json"))
    if len(profiles) < 2 or not any(p.name == "gen007-deepworks.json" for p in profiles):
        raise ValueError("Required generator recipes missing")
    target = destination / "godot/authoring/worldgen"
    target.mkdir(parents=True, exist_ok=True)
    for profile in profiles:
        if len(profile.read_bytes()) > 1024 * 1024:
            raise ValueError("Oversize generator profile")
        json.loads(profile.read_text(encoding="utf-8"))
        shutil.copyfile(profile, target / profile.name)
    return {"committed_file_count": count, "lfs_verified": lfs_hashes,
            "generator_profile_count": len(profiles)}


def launcher(gui: str, console: str, source_sha: str) -> str:
    return (
        '@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\n'
        f'set "CYBERSAND_SOURCE_REVISION={source_sha}"\r\n'
        f'"%~dp0{console}" --headless --path "%~dp0godot" --editor --quit\r\n'
        'if errorlevel 1 (echo Godot import FAILED & pause & exit /b 1)\r\n'
        f'"%~dp0{gui}" --rendering-method gl_compatibility --rendering-driver opengl3 --path "%~dp0godot" -- --workbench\r\n'
    )


def gpu_benchmark_launcher(mode: str) -> str:
    return (
        '@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\n'
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-NVIDIA-Benchmarks.ps1"'
        + (" -Smoke" if mode == "Quick" else "") + '\r\n'
        'set "rc=%errorlevel%"\r\n'
        'echo.\r\n'
        'echo Benchmarked source or partial evidence is in Benchmark-Results.\r\n'
        'pause\r\nexit /b %rc%\r\n'
    )


def build(args: argparse.Namespace) -> dict:
    if sys.platform != "win32":
        raise RuntimeError("The owner evaluation packager must run on Windows")
    source = args.source_sha.lower()
    if not re.fullmatch(r"[0-9a-f]{40}", source):
        raise ValueError("Expected an immutable 40-character source SHA")
    if not git("merge-base", "--is-ancestor", source, "HEAD") == "":
        raise RuntimeError("Qualified source is not an ancestor of this packaging branch")
    # Only the workflow/packager can differ. Application, recipes and
    # native/Rapier sources must be the EXACT previously tested bytes.
    delta = subprocess.run(["git", "-C", str(ROOT), "diff", "--quiet", source, "HEAD",
                            "--", *SOURCE_SCOPES, "native", "godot/native_extension"],
                           timeout=60)
    if delta.returncode != 0:
        raise RuntimeError("Application source differs from the qualified head")
    if git("status", "--porcelain"):
        raise RuntimeError("Refusing a dirty source checkout")

    runtime = verify_retained_runtime(ROOT)
    out = args.output.resolve()
    evidence = args.evidence.resolve()
    if out.exists() or evidence.exists():
        raise ValueError("Evaluation output/evidence must be fresh")
    out.parent.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=False)

    # Official Godot ZIP SHA-512 and engine --version are checked by the
    # existing pinned upstream CyberSand CI helper, not merely trusted here.
    console, godot_identity = prepare_godot(args.godot_archive)
    gui = console.with_name("Godot_v4.7-stable_win64.exe")
    if not gui.is_file():
        raise RuntimeError("Pinned official Godot GUI is missing")
    stage = evidence / "CyberSand-EngineLab-NVIDIA-Windows"
    stage.mkdir()
    project = stage_source(source, stage)
    for name in (console.name, gui.name):
        shutil.copyfile(console.parent / name, stage / name)
    (stage / "Open Workbench (NVIDIA).cmd").write_bytes(
        launcher(gui.name,console.name,source).encode("utf-8"))
    for mode in ("Quick","Full"):
        (stage / f"Benchmark ({mode}) NVIDIA.cmd").write_bytes(
            gpu_benchmark_launcher(mode).encode("utf-8"))
    shutil.copyfile(ROOT / "tools/engine_lab/windows_gpu_runner.ps1",
                    stage / "Run-NVIDIA-Benchmarks.ps1")
    (stage / "README - Engine Lab GPU.txt").write_text(
        "CyberSand ENG-LAB-001 — Windows 11/NVIDIA Workbench research build\n"
        "Draft/HOLD. Not a production build. Does NOT contain RENDER-ACK-002 gating.\n\n"
        "Extract the entire inner evaluation ZIP to a NEW WRITABLE directory.\n"
        "Bundled official Godot 4.7, Windows native World and Rapier2D.\n"
        "Windows 11 PowerShell is sufficient for the unattended benchmark.\n"
        "Microsoft Visual C++ x64 Redistributable 2015-2022 may be needed:\n"
        "https://aka.ms/vs/17/release/vc_redist.x64.exe\n\n"
        "Open Workbench (NVIDIA).cmd — interactive Workbench; Engine Lab menu\n"
        "opens the clock monitor with 10-second Benchmark button.\n\n"
        "Benchmark (Quick) NVIDIA.cmd — ONE real 1024-square FreeMass/Needle\n"
        "hardware-GPU smoke; native/actor/source/policy/clock report must pass.\n"
        "Benchmark (Full) NVIDIA.cmd — 16 independent processes, four native\n"
        "Water families x 1/4 workers x 2 repetitions; no injected input.\n"
        "Each program uses the native OpenGL3 hardware path (not ANGLE).\n"
        "A genuine NVIDIA adapter reported by Godot is mandatory for the normal\n"
        "launchers. DO NOT minimize the graphical window or use controls.\n"
        "Source/geometry, camera, material, worker counts, GPU and actual\n"
        "window size are matched and verified within each campaign.\n"
        "The full benchmark can be substantially longer than a 10-second run:\n"
        "each case prepares a fresh native World, warms up and then samples.\n"
        "Raw JSON and process logs: Benchmark-Results/NVIDIA-*/\n"
        "Please return summary.json plus the individual w*.json files.\n\n"
        "Native solver families: FreeMass/reference, PressureFlow/cached_dormant,\n"
        "Cellular Yield/reference and Inertial Cellular/reference.\n"
        "Inertial's required native radius3 differs from the usual radius2;\n"
        "the campaign explicitly records that legally configured confound.\n"
        "Rapier/World/renderer laws, defaults, clocks and ACK remain UNCHANGED.\n"
        "No hardware-GPU performance or physics stability is accepted until\n"
        "the owner runs and reviews the exact resulting receipts.\n\n"
        "Research PR: https://github.com/techrote/cybersand/pull/604\n"
        f"Qualified executable source: {source}\n"
        f"Engine: {GODOT_VERSION}\n"
        "Previously qualified Windows ANGLE/Linux llvmpipe graphical matrix:\n"
        "https://github.com/techrote/cybersand/actions/runs/43632420337\n",
        encoding="utf-8"
    )
    # Bundle MIT and third-party Godot notices from the official pinned tag.
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        notice = args.godot_notices / name
        if notice.stat().st_size < 200:
            raise ValueError("Godot engine license notice missing: " + name)
        shutil.copyfile(notice, stage / ("Godot-" + name))

    files = {p.relative_to(stage).as_posix(): sha(p)
             for p in sorted(stage.rglob("*")) if p.is_file()}
    manifest = {
        "schema": "eng-lab-001-nvidia-windows-v1",
        "status": "experimental-draft-hold",
        "application_commit": source,
        "application_tree": git("rev-parse", source + "^{tree}"),
        "packager_commit": git("rev-parse", "HEAD"),
        "qualification_workflow_run": 43632420337,
        "native_runtime": runtime,
        "godot": godot_identity,
        "project": project,
        "file_sha256": files,
        "policy_default": "baseline-no-render-ack-gating",
        "launchers": ["Open Workbench (NVIDIA).cmd",
                      "Benchmark (Quick) NVIDIA.cmd", "Benchmark (Full) NVIDIA.cmd"],
    }
    (stage / "evaluation-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6,
                         allowZip64=True) as package:
        # Freeze and seal the exact Git-archive bytes BEFORE Godot's importer
        # can rewrite .import descriptor line endings or create editor caches.
        # Never package imported/modified files from the smoke copy.
        for name in sorted(files):
            package.write(stage / name, name)
        package.write(stage / "evaluation-manifest.json", "evaluation-manifest.json")
    with zipfile.ZipFile(out) as package:
        bad = package.testzip()
        if bad:
            raise RuntimeError("Evaluation ZIP integrity error: " + bad)
        names = set(package.namelist())
        if names != set(files) | {"evaluation-manifest.json"}:
            raise RuntimeError("Bundled payload inventory differs from frozen source manifest")
        for name, expected in files.items():
            if hashlib.sha256(package.read(name)).hexdigest() != expected:
                raise RuntimeError("Bundled file changed after source capture: " + name)
    # Execute smoke on the post-archive stage. These tests may legitimately
    # rewrite generated Godot .import caches without changing the sealed ZIP.
    engine = str(stage / console.name)
    smoke = {}
    smoke["import"] = run(
        [engine, "--headless", "--path", str(stage / "godot"), "--editor", "--quit"],
        evidence / "smoke-import.log", 240)
    if not smoke["import"]["ok"]:
        raise RuntimeError("Staged import failed; see smoke-import.log")
    smoke["passive-recorder-unit"] = run(
        [engine, "--headless", "--path", str(stage / "godot"),
         "--script", "res://tests/test_engine_lab_passive_recorder.gd"],
        evidence / "smoke-passive-unit.log", 240)
    unit_log = (evidence / "smoke-passive-unit.log").read_text(encoding="utf-8")
    if (not smoke["passive-recorder-unit"]["ok"] or
            not re.search(r"ENG_LAB_PASSIVE: \d+ checks, 0 failures", unit_log)):
        raise RuntimeError("Staged passive recorder regression failed")

    # Hosted Windows ANGLE is SOFTWARE only. Exercise the exact supplied
    # PowerShell one-click runner in this deliberately non-NVIDIA mode; the
    # owner-facing launcher still uses native opengl3 and requires NVIDIA.
    powershell = Path(os.environ.get("SystemRoot",r"C:\Windows")) / (
        "System32/WindowsPowerShell/v1.0/powershell.exe")
    smoke["one-click-ANGLE-control"] = run(
        [str(powershell),"-NoProfile","-NonInteractive",
         "-ExecutionPolicy","Bypass","-File",
         str(stage / "Run-NVIDIA-Benchmarks.ps1"),
         "-Smoke","-AllowOtherAdapter","-RenderingDriver","opengl3_angle"],
        evidence / "smoke-quick-ANGLE.log", 600)
    if not smoke["one-click-ANGLE-control"]["ok"]:
        raise RuntimeError("Bundled actual PowerShell one-click graphical smoke failed")

    receipt = {
        "schema": "eng-lab-001-gpu-packaging-receipt-v1",
        "status": "passed", "source": source, "packager": git("rev-parse", "HEAD"),
        "godot": godot_identity, "native_runtime": runtime,
        "zip": out.name, "zip_sha256": sha(out), "zip_bytes": out.stat().st_size,
        "file_count": len(files) + 1, "smoke": smoke,
        "software_renderer_only": True, "nvidia_owner_acceptance": False,
    }
    (evidence / "packaging-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "zip": out.name,
                      "sha256": receipt["zip_sha256"],
                      "bytes": receipt["zip_bytes"], "source": source},
                     sort_keys=True), flush=True)
    return receipt


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source-sha", required=True)
    p.add_argument("--godot-archive", type=Path, required=True)
    p.add_argument("--godot-notices", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--evidence", type=Path, required=True)
    args = p.parse_args()
    try:
        build(args)
    except Exception as error:
        if args.evidence.is_dir():
            (args.evidence / "packaging-error.txt").write_text(str(error) + "\n", encoding="utf-8")
        print(f"ENG-LAB-001 GPU package FAILED: {type(error).__name__}: {error}",
              file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
