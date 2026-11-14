#!/usr/bin/env python3
"""RENDER-ACK-002: immutable-source Windows owner evaluation ZIP.

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
                 "LICENSE_STATUS.md", "docs/operations/explore001-desktop-playtest.md")
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


def launcher(gui: str, console: str, source_sha: str, policy: str) -> str:
    return (
        '@echo off\r\n'
        'setlocal\r\n'
        'cd /d "%~dp0"\r\n'
        f'set "CYBERSAND_SOURCE_REVISION={source_sha}"\r\n'
        f'"%~dp0{console}" --headless --path "%~dp0godot" --editor --quit\r\n'
        'if errorlevel 1 (\r\n'
        '  echo Godot project import failed.\r\n'
        '  pause\r\n'
        '  exit /b 1\r\n'
        ')\r\n'
        f'"%~dp0{gui}" --path "%~dp0godot" -- --workbench --render-ack-policy={policy}\r\n'
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
    stage = evidence / "CyberSand-RENDER-ACK-002-Windows"
    stage.mkdir()
    project = stage_source(source, stage)
    for name in (console.name, gui.name):
        shutil.copyfile(console.parent / name, stage / name)
    for policy in ("baseline", "gated"):
        (stage / f"Open Workbench ({policy.upper()}).cmd").write_bytes(
            launcher(gui.name, console.name, source, policy).encode("utf-8"))
    (stage / "README - RENDER-ACK-002.txt").write_text(
        "CyberSand RENDER-ACK-002 — research / Draft-HOLD Windows playtest\n"
        "Extract this complete ZIP into a new writable directory.\n\n"
        "Run Open Workbench (BASELINE).cmd for unchanged original behavior.\n"
        "Run Open Workbench (GATED).cmd for experimental ACK-aware native captures.\n"
        "The bundled pinned Godot editor imports the project on launch; do not\n"
        "move any files out of the directory. Both launchers use the same source.\n\n"
        "Acceptance: on Windows 11/NVIDIA, alternate baseline/gated/baseline/gated\n"
        "using exactly the same workbench map, brush strokes, Sand/Water simulation\n"
        "and 2048-square scenes. Look for delayed material appearance, visual stutter,\n"
        "incorrect collider/actor alignment, stale previous/current material frames,\n"
        "and lost edits; compare frame p95/p99 and not only FPS averages.\n"
        "Try save, close, reopen, load; also recording-start full refresh.\n"
        "To trace separately append --render-ack-trace to the user arguments;\n"
        "traces are diagnostic and may increase overhead.\n\n"
        "This build is NOT a release and does not authorize a merge.\n"
        "The existing CPU Image, ImageTexture.update, World and default remain unchanged.\n"
        "Microsoft Visual C++ Redistributable x64 (2015-2022) may be required.\n"
        "Official Microsoft installer: https://aka.ms/vs/17/release/vc_redist.x64.exe\n"
        "Source PR: https://github.com/techrote/cybersand/pull/585\n"
        f"Qualified application source: {source}\n"
        f"Godot version: {GODOT_VERSION}\n",
        encoding="utf-8")
    # Bundle MIT and third-party Godot notices from the official pinned tag.
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        notice = args.godot_notices / name
        if notice.stat().st_size < 200:
            raise ValueError("Godot engine license notice missing: " + name)
        shutil.copyfile(notice, stage / ("Godot-" + name))

    files = {p.relative_to(stage).as_posix(): sha(p)
             for p in sorted(stage.rglob("*")) if p.is_file()}
    manifest = {
        "schema": "render-ack-002-windows-playtest-v1",
        "status": "experimental-draft-hold",
        "application_commit": source,
        "application_tree": git("rev-parse", source + "^{tree}"),
        "packager_commit": git("rev-parse", "HEAD"),
        "qualification_workflow_run": 43563896102,
        "native_runtime": runtime,
        "godot": godot_identity,
        "project": project,
        "file_sha256": files,
        "policy_default": "baseline",
        "launchers": ["Open Workbench (BASELINE).cmd",
                      "Open Workbench (GATED).cmd"],
    }
    (stage / "evaluation-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    # Smoke the freshly staged copy rather than the Actions checkout.
    engine = str(stage / console.name)
    smoke = {}
    smoke["import"] = run(
        [engine, "--headless", "--path", str(stage / "godot"), "--editor", "--quit"],
        evidence / "smoke-import.log", 240)
    if not smoke["import"]["ok"]:
        raise RuntimeError("Staged import failed; see smoke-import.log")
    smoke["ack-policy-native"] = run(
        [engine, "--headless", "--path", str(stage / "godot"),
         "--script", "res://tests/test_render_ack_policy.gd"],
        evidence / "smoke-native-policy.log", 240)
    native_log = (evidence / "smoke-native-policy.log").read_text(encoding="utf-8")
    if (not smoke["ack-policy-native"]["ok"] or
            not re.search(r"RENDER_ACK_POLICY: \d+ assertions, 0 failures", native_log)):
        raise RuntimeError("Staged owner ACK policy source-native regression failed")
    smoke["gated-graphical"] = run(
        [engine, "--rendering-driver", "opengl3_angle", "--path", str(stage / "godot"),
         "--quit-after", "50", "--", "--workbench", "--render-ack-policy=gated"],
        evidence / "smoke-gated-graphical.log", 240)
    if not smoke["gated-graphical"]["ok"]:
        raise RuntimeError("Staged graphical Workbench launch failed")

    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6,
                         allowZip64=True) as package:
        for path in sorted(stage.rglob("*")):
            if path.is_file():
                package.write(path, path.relative_to(stage).as_posix())
    with zipfile.ZipFile(out) as package:
        bad = package.testzip()
        if bad:
            raise RuntimeError("Evaluation ZIP integrity error: " + bad)
        if "evaluation-manifest.json" not in package.namelist():
            raise RuntimeError("Missing evaluation manifest in ZIP")
    receipt = {
        "schema": "render-ack-002-packaging-receipt-v1",
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
        print(f"RENDER-ACK-002 package FAILED: {type(error).__name__}: {error}",
              file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
