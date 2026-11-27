#!/usr/bin/env python3
"""Package the Art finisher from committed source and unchanged qualified runtimes.

The installed Windows evaluator requires no Git, compiler or Python. Its ordinary
Workbench uses a package-local profile and an optional in-memory timing observer.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

import package_explore001_candidate as retained

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
from check_repository import verify_runtime
from art_evaluator_qualification_scope import validate_completed_decision

NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
GUIDE = "docs/operations/art-workbench-final-evaluation.md"
MANIFEST = "candidate-manifest.json"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def check_source_inputs(inputs: list[str]) -> None:
    # Validators import additional local tools. Gate the whole tools tree so
    # no changed or untracked transitive dependency can attest committed source.
    status = git("status", "--porcelain=v1", "--untracked-files=all", "--", *inputs, "tools")
    # Godot imports create UID sidecars; the committed archive never consumes
    # those generated files. Any other untracked source/tool can shadow imports
    # and must be committed or removed before source-qualified packaging.
    dirty = [line for line in status.splitlines() if not (
        line.startswith("?? godot/") and line.endswith((".gd.uid", ".gdshader.uid")))]
    if dirty:
        raise ValueError("Commit application/package inputs before source-qualified packaging; rejected status rows:\n" + "\n".join(dirty))



def qualification_source(path: Path | None, source: str, tree: str) -> dict | None:
    if path is None:
        return None
    proof = json.loads(path.read_text(encoding="utf-8"))
    return validate_completed_decision(proof, source, tree)


def archive_source(inputs: list[str]) -> bytes:
    # Git archive honors checkout EOL settings. Windows CRLF export changes
    # committed .import descriptors; export canonical LF before first launch.
    # Keep unspecified text LF; explicit .gitattributes rules still apply.
    # Leave LFS pointers for the hash-checked Windows materialization below.
    return subprocess.check_output(
        ["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf",
         "archive", "HEAD", "--", *inputs], cwd=ROOT,
        env=dict(os.environ, GIT_LFS_SKIP_SMUDGE="1"), timeout=120)


def build(args: argparse.Namespace) -> dict:
    if os.name != "nt":
        raise ValueError("Build and qualify this Windows evaluator on Windows")
    output = args.output.resolve()
    if output.exists():
        raise ValueError("Choose a new package directory; existing profiles are never overwritten")
    inputs = ["godot", "examples/worldgen", "third_party", "tools/package_art_workbench_final.py",
              "tools/package_explore001_candidate.py", "tools/ci/check_repository.py",
              "tools/ci/art_evaluator_qualification_scope.py",
              "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md", GUIDE]
    check_source_inputs(inputs)
    source = git("rev-parse", "HEAD")
    tree = git("rev-parse", "HEAD^{tree}")
    qualification = qualification_source(args.qualification_source, source, tree)
    native_manifest = json.loads((ROOT / "godot/addons/cybersand_native/runtime-provenance.json").read_text())
    errors = verify_runtime(ROOT, native_manifest)
    if errors:
        raise ValueError("; ".join(errors))
    if (ROOT / NATIVE).read_bytes().startswith(b"version https://git-lfs"):
        raise ValueError("Materialize the exact Windows native runtime")
    console = args.engine.with_name("Godot_v4.7-stable_win64_console.exe")
    version = subprocess.check_output([str(console), "--version"], text=True, timeout=30).strip()
    if version != retained.VERSION:
        raise ValueError("Godot version differs from the exact 4.7 pin")
    retained.verify_vc_runtime(args.vc_runtime)
    expected_notices = {"LICENSE.txt":"b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
                        "COPYRIGHT.txt":"cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d"}
    for name, expected in expected_notices.items():
        if sha(args.engine_notices / name) != expected:
            raise ValueError("Godot notice mismatch: " + name)
    archive = archive_source(inputs)
    output.mkdir(parents=True)
    retained.stage_project_archive(archive, None, output, ROOT)
    profiles = retained.stage_generator_profiles(output)
    for engine in (args.engine, console):
        shutil.copyfile(engine, output / engine.name)
    for name in expected_notices:
        shutil.copyfile(args.engine_notices / name, output / ("Godot-" + name))
    vc_sha = retained.stage_vc_runtime(args.vc_runtime, output)
    shutil.copyfile(output / GUIDE, output / "READ-ME.md")
    if qualification is not None:
        # This binds application evidence to the package's committed source.
        # It does not attest package acceptance before the actual installed
        # launcher and module-path gates execute on this new installation.
        (output / "APPLICATION-QUALIFICATION.json").write_text(
            json.dumps(qualification, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    # This launcher is also executed by the installed-copy smoke check. The
    # smoke-only environment knob closes the SAME interactive code after a few
    # seconds; it never switches to a detached mock application.
    launcher = (
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'if not exist "profile" mkdir "profile"\n'
        'if not exist "diagnostics" mkdir "diagnostics"\n'
        'set "APPDATA=%~dp0profile"\nset "LOCALAPPDATA=%~dp0profile-local"\n'
        f'set "CYBERSAND_SOURCE_REVISION={source}"\n'
        'set "WB_ART_DIAGNOSTIC_PATH=%~dp0diagnostics\\art-responsiveness.json"\n'
        'set "ART_EVALUATOR_RENDER_ARGS="\n'
        'if "%WB_ART_EVALUATOR_SOFTWARE%"=="1" set "ART_EVALUATOR_RENDER_ARGS=--rendering-driver opengl3_angle"\n'
        'if not exist "godot\\.godot\\global_script_class_cache.cfg" (\n'
        '  echo Preparing the Workbench for first launch...\n'
        f'  "{console.name}" --headless --path "%~dp0godot" --editor --import > "diagnostics\\import.log" 2>&1\n'
        '  if errorlevel 1 goto failed\n)\n'
        f'"{console.name}" --path "%~dp0godot" --resolution 1280x720 %ART_EVALUATOR_RENDER_ARGS% --script res://tests/run_art_owner_evaluator.gd > "diagnostics\\workbench.log" 2>&1\n'
        'if errorlevel 1 goto failed\nexit /b 0\n:failed\n'
        'echo Workbench could not start. See diagnostics\\import.log and diagnostics\\workbench.log.\n'
        'if not defined WB_ART_EVALUATOR_SMOKE_SECONDS pause\nexit /b 1\n')
    (output / "Open Workbench.cmd").write_text(launcher, encoding="utf-8", newline="\r\n")
    (output / "Open diagnostics.cmd").write_text(
        '@echo off\nif not exist "%~dp0diagnostics" mkdir "%~dp0diagnostics"\n'
        'start "" "%~dp0diagnostics"\n', encoding="utf-8", newline="\r\n")
    identity = {"schema":"art-workbench-final-evaluator-v1", "source_commit":source, "source_tree":tree,
                "godot_version":version, "native_sha256":sha(output / NATIVE),
                "native_source_commit":native_manifest["source_commit"],
                "native_source_unchanged":True, "vc_runtime_sha256":vc_sha,
                "generator_profiles_sha256":profiles, "automatic_model_requests":False,
                "profile":"package-local", "status":"Draft/HOLD",
                "qualification_scope_file":"APPLICATION-QUALIFICATION.json" if qualification is not None else None,
                "application_qualification":{key:qualification[key] for key in (
                    "mode","application_source_commit","application_source_tree")} if qualification is not None else None,
                "files_sha256":{p.relative_to(output).as_posix():sha(p) for p in sorted(output.rglob("*")) if p.is_file()}}
    (output / MANIFEST).write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return identity


def verify(package: Path) -> dict:
    identity = json.loads((package / MANIFEST).read_text(encoding="utf-8"))
    if identity.get("schema") != "art-workbench-final-evaluator-v1":
        raise ValueError("Unexpected evaluator manifest")
    for relative, expected in identity["files_sha256"].items():
        path = package / relative
        if not path.is_file() or sha(path) != expected:
            raise ValueError("Packaged file changed: " + relative)
    return identity


def import_descriptor_snapshot(package: Path, identity: dict) -> dict:
    """Retain exact public source metadata, including newlines, around import."""
    result = {}
    source_root = package.resolve() / "godot"
    for relative in sorted(identity["files_sha256"]):
        if not relative.startswith("godot/") or not relative.endswith(".import"):
            continue
        if ("\\" in relative or ":" in relative or
                any(part in ("", ".", "..") for part in relative.split("/")) or
                source_root.resolve() != source_root):
            raise ValueError("Invalid import descriptor path: " + relative)
        path = (package / relative).resolve()
        if not path.is_relative_to(source_root):
            raise ValueError("Invalid import descriptor path: " + relative)
        if not path.is_file():
            result[relative] = {"missing": True}
            continue
        size = path.stat().st_size
        if size > 65536:
            result[relative] = {"bytes": size, "content_omitted": "oversized import descriptor"}
            continue
        data = path.read_bytes()
        record = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        try:
            record["utf8"] = data.decode("utf-8")
        except UnicodeDecodeError:
            record["content_omitted"] = "non-UTF8 import descriptor"
        result[relative] = record
    return result


def smoke(args: argparse.Namespace) -> None:
    identity = verify(args.output)
    args.evidence.mkdir(parents=True, exist_ok=True)
    imports_before = import_descriptor_snapshot(args.output, identity)
    env = dict(os.environ, WB_ART_EVALUATOR_SMOKE_SECONDS="5", WB_ART_EVALUATOR_SOFTWARE="1")
    log = args.evidence / "installed-launcher.log"
    timed_out = False
    exit_code = None
    try:
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(["cmd.exe", "/d", "/c", str(args.output.resolve() / "Open Workbench.cmd")],
                                       cwd=args.output, env=env, stdout=stream, stderr=subprocess.STDOUT)
            try:
                exit_code = process.wait(timeout=240)
            except subprocess.TimeoutExpired:
                timed_out = True
                # Kill only this owned launcher and its descendants; retain the
                # pre-teardown timing report when a child has become stuck.
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               stdout=stream, stderr=subprocess.STDOUT, timeout=30, check=False)
                process.wait(timeout=30)
    finally:
        (args.evidence / "installed-import-descriptors.json").write_text(json.dumps({
            "source_commit": identity["source_commit"], "before": imports_before,
            "after": import_descriptor_snapshot(args.output, identity)}, indent=2) + "\n", encoding="utf-8")
        for name in ("import.log", "workbench.log", "art-responsiveness.json"):
            source = args.output / "diagnostics" / name
            if source.is_file(): shutil.copyfile(source, args.evidence / name)
        (args.evidence / "installed-execution.json").write_text(json.dumps({
            "source_commit":identity["source_commit"], "timed_out":timed_out,
            "exit_code":exit_code, "watchdog_seconds":240}, indent=2) + "\n")
    logs = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in args.evidence.glob("*.log"))
    if timed_out or exit_code != 0 or "SCRIPT ERROR:" in logs or "Parse Error:" in logs:
        raise ValueError("Installed launcher failed; original logs retained")
    timing = json.loads((args.evidence / "art-responsiveness.json").read_text())
    if timing["source_commit"] != identity["source_commit"] or timing["display"] == "headless":
        raise ValueError("Installed source/display receipt does not match")
    if not any(row["event"] == "workbench_ready" for row in timing["events"]):
        raise ValueError("Installed native Workbench did not become ready")
    if not timing.get("teardown_completed"):
        raise ValueError("Installed Workbench did not finish orderly teardown")
    verify(args.output)
    (args.evidence / "installed-result.json").write_text(json.dumps({
        "status":"passed", "source_commit":identity["source_commit"], "actual_launcher":True,
        "display":timing["display"], "automatic_model_requests":False}, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "verify", "smoke", "zip"])
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--qualification-source", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        if not all((args.engine, args.engine_notices, args.vc_runtime)): parser.error("build requires engine, notices and VC runtime")
        build(args)
    elif args.command == "smoke":
        if args.evidence is None: parser.error("smoke requires evidence")
        smoke(args)
    elif args.command == "zip":
        identity = verify(args.output)
        destination = args.output.with_suffix(".zip")
        # Package only the immutable payload: never the smoke profile, generated
        # imports, credentials or owner diagnostics produced while testing it.
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for relative in sorted([*identity["files_sha256"], MANIFEST]):
                archive.write(args.output / relative, args.output.name + "/" + relative)
        destination.with_suffix(".zip.sha256").write_text(sha(destination) + "  " + destination.name + "\n")
    else:
        verify(args.output)
    print(json.dumps({"status":"passed", "command":args.command, "output":str(args.output)}))


if __name__ == "__main__":
    main()
