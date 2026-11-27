"""Package committed EXPLORE source with an attested source-built Windows DLL."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import native_candidate_identity as native

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.stable.official.5b4e0cb0f"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
VC_RUNTIME_FILES = {"vcruntime140.dll", "Microsoft-Visual-C-Runtime-LICENSE.docx",
                    "Microsoft-Visual-Studio-2022-LICENSE.docx"}


def committed_archive(names, root=ROOT):
    """Archive canonical text while retaining explicit per-file eol attributes.

    Windows autocrlf otherwise changes tracked Godot import metadata to CRLF;
    the pinned editor rewrites it to LF on import, breaking the sealed payload
    hash despite identical settings. These child-only defaults preserve every
    sidecar and authored setting without changing Git configuration or checks.
    """
    return subprocess.check_output(["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf",
                                    "archive", "HEAD", "--", *names], cwd=root, timeout=90)


def verify_vc_runtime(directory):
    """Reject incomplete or changed output from the signed VS redist stager."""
    provenance = json.loads((directory / "vc-runtime-provenance.json").read_text(encoding="utf-8-sig"))
    if provenance.get("schema") != 1 or set(provenance.get("files_sha256", {})) != VC_RUNTIME_FILES:
        raise ValueError("VC runtime stage must contain the runtime and both applicable licences")
    for name, expected in provenance["files_sha256"].items():
        if not re.fullmatch(r"[0-9a-f]{64}", expected) or native.sha(directory / name) != expected:
            raise ValueError("VC runtime stage hash mismatch: " + name)
    data = (directory / "vcruntime140.dll").read_bytes()
    if len(data) < 64 or data[:2] != b"MZ":
        raise ValueError("VC runtime is not a Windows PE file")
    offset = struct.unpack_from("<I", data, 0x3c)[0]
    if offset + 6 > len(data) or data[offset:offset + 6] != b"PE\x00\x00\x64\x86":
        raise ValueError("VC runtime is not x64")
    return provenance


def stage_vc_runtime(directory, destination):
    provenance = verify_vc_runtime(directory)
    for name in sorted(VC_RUNTIME_FILES | {"vc-runtime-provenance.json"}):
        shutil.copyfile(directory / name, destination / name)
    return provenance["files_sha256"]["vcruntime140.dll"]


def stage_generator_profiles(package_root):
    """Copy archived canonical recipes inside the standalone Godot project.

    Keep examples/worldgen for existing tools and provenance. Both byte-exact
    copies enter the payload manifest; no second recipe catalogue is authored.
    """
    recipes = sorted((package_root / "examples/worldgen").glob("*.json"))
    required = {"gen007-deepworks.json", "gen007-qualification.json"}
    if not required.issubset({p.name for p in recipes}):
        raise ValueError("Standalone package is missing required GEN-007 profiles")
    destination = package_root / "godot/authoring/worldgen"
    destination.mkdir(parents=True, exist_ok=True)
    for recipe in recipes:
        payload = recipe.read_bytes()
        if len(payload) > 1024 * 1024 or not isinstance(json.loads(payload), dict):
            raise ValueError("Invalid or oversized bundled generation profile: " + recipe.name)
        (destination / recipe.name).write_bytes(payload)
    return {p.name: native.sha(p) for p in recipes}


def stage_project_archive(payload, native_candidate, destination, root=ROOT, *, actor_evaluator=False):
    """Stage committed Windows inputs; never require the Linux reciprocal LFS object."""
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for entry in archive:
            if not entry.isfile() or entry.name.startswith("godot/.godot/"):
                continue
            # The Actor evaluator regenerates these mutable editor descriptors at first import.
            if actor_evaluator and entry.name.startswith("godot/") and entry.name.endswith(".import"):
                continue
            if entry.name in {"godot/tools/gentek_reciprocal", "godot/tools/swarm004-runtime.linux.json"}:
                continue
            if "/bin/" in entry.name and entry.name not in (native.NATIVE, RAPIER):
                continue
            stream = archive.extractfile(entry)
            data = stream.read()
            if entry.name == native.NATIVE and native_candidate is not None:
                data = (native_candidate / Path(native.NATIVE).name).read_bytes()
            elif data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                data = (root / entry.name).read_bytes()
                if match is None or hashlib.sha256(data).hexdigest() != match[1].decode() or len(data) != int(match[2]):
                    raise ValueError("Unmaterialized or changed LFS payload: " + entry.name)
            target = destination / entry.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    binding = destination / "godot/tools/swarm004-runtime.windows.json"
    cli = destination / "godot/tools/gentek_reciprocal.exe"
    if (destination / "godot/scripts/workbench_reciprocal_protocol.gd").exists() or binding.exists() or cli.exists():
        if not binding.is_file() or not cli.is_file():
            raise ValueError("Missing Windows reciprocal generator or source binding")
        record = json.loads(binding.read_bytes())
        if (record.get("platform") != "windows" or record.get("artifact") != cli.relative_to(destination).as_posix()
                or cli.stat().st_size != record.get("bytes") or native.sha(cli) != record.get("sha256")):
            raise ValueError("Packaged reciprocal generator differs from its Windows source binding")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True, help="official Godot Windows GUI executable")
    parser.add_argument("--engine-notices", type=Path, required=True)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--vc-runtime", type=Path, required=True,
                        help="verified output from tools/ci/stage_windows_vc_runtime.ps1")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--readme", type=Path,
                        default=Path("docs/operations/explore001-desktop-playtest.md"),
                        help="committed repository guide to include as READ-ME.md")
    args = parser.parse_args()
    if args.readme.is_absolute() or ".." in args.readme.parts or args.readme.suffix != ".md":
        raise ValueError("Candidate guide must be a repository-relative Markdown path")
    manifest = native.verify(ROOT, args.native_candidate)
    verify_vc_runtime(args.vc_runtime)
    console = args.engine.with_name(args.engine.stem + "_console.exe")
    version = subprocess.check_output([str(console), "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise ValueError("Godot version differs from the pin")
    if args.output.exists():
        raise ValueError("Candidate destination must be a new directory")
    # Read source from the Git tree. Never package editor imports, untracked
    # files, local source deltas, credentials or another worktree's DLL.
    names = ["godot", "examples/worldgen", "tools/acceptance/gentek80_owner.ps1",
             "docs/operations/gentek80-physical-owner-acceptance.md", "third_party/godot-runtime.lock.json",
             "third_party/native-toolchain.lock.json", "third_party/rapier-bvh-build.lock.json",
             "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
             "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md",
             args.readme.as_posix()]
    actor_evaluator = args.readme.as_posix() == "docs/operations/workbench-actor-composition.md"
    if actor_evaluator:
        names.append("tools/ci/actor_results_collector.ps1")
    payload = committed_archive(names)
    args.output.mkdir(parents=True)
    stage_project_archive(payload, args.native_candidate, args.output, actor_evaluator=actor_evaluator)
    profiles = stage_generator_profiles(args.output)
    for engine in (args.engine, console):
        shutil.copyfile(engine, args.output / engine.name)
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        shutil.copyfile(args.engine_notices / name, args.output / ("Godot-" + name))
    vc_runtime_sha256 = stage_vc_runtime(args.vc_runtime, args.output)
    shutil.copyfile(args.native_candidate / native.NAME, args.output / "source-built-candidate-provenance.json")
    # Retained provenance belongs to historical committed bytes. Give the
    # delivered DLL its own manifest rather than presenting the old one.
    runtime_manifest = args.output / "godot/addons/cybersand_native/runtime-provenance.json"
    runtime_manifest.rename(runtime_manifest.with_name("retained-runtime-provenance.reference.json"))
    # The historical entry name is preserved, but no longer bypasses the
    # source-pinned offline verification gate: both batch entry points check
    # every immutable delivered file before invoking the bundled Godot.
    (args.output / "Open Workbench.cmd").write_text(
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'call "%~dp0Verify and Open Workbench.cmd"\n'
        'exit /b %errorlevel%\n',
        encoding="utf-8", newline="\r\n")
    if actor_evaluator:
        # Manifest-bound, local-only acceptance collector; the original file
        # is committed and extracted from the same Git tree as the application.
        collector = args.output / "tools/ci/actor_results_collector.ps1"
        collector.rename(args.output / "Actor Results Collector.ps1")
        (args.output / "Collect Actor Results.cmd").write_text(
            '@echo off\ncd /d "%~dp0"\n'
            'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Actor Results Collector.ps1"\n'
            'if errorlevel 1 (echo Actor regression failed. Logs are retained. & pause & exit /b 1)\n'
            'echo Actor evidence has been saved.\npause\n',
            encoding="utf-8", newline="\r\n")
    # The guide follows the same committed source as the application payload;
    # a working-tree documentation edit must not enter a source-matched package.
    shutil.copyfile(args.output / args.readme, args.output / "READ-ME.md")
    shutil.copyfile(args.output / "docs/operations/gentek80-physical-owner-acceptance.md",
                    args.output / "OWNER-ACCEPTANCE.md")
    # The original entry point now delegates to this checked launcher.
    # New packages expose a fail-closed owner launcher: pin source and check
    # every immutable package file before importing or starting the GUI.
    (args.output / "Verify and Open Workbench.cmd").write_text(
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '
        '"%~dp0tools\\acceptance\\gentek80_owner.ps1" -Action Launch -PackagePath "%~dp0" '
        f'-ExpectedSource {manifest["source_commit"]}\n'
        'exit /b %errorlevel%\n',
        encoding="utf-8", newline="\r\n")
    files = {p.relative_to(args.output).as_posix(): native.sha(p)
             for p in sorted(args.output.rglob("*")) if p.is_file()}
    identity = {"schema": 1, "purpose": "owner desktop playtest candidate; not a production release",
                "source_commit": manifest["source_commit"], "source_tree": manifest["source_tree"],
                "godot_version": version, "native_sha256": manifest["sha256"],
                "vc_runtime_sha256": vc_runtime_sha256,
                "generator_profiles_sha256": profiles, "files_sha256": files}
    (args.output / "candidate-manifest.json").write_text(json.dumps(identity, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(args.output / "Open Workbench.cmd")


if __name__ == "__main__": main()
