"""Package committed EXPLORE source with an attested source-built Windows DLL."""
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

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import native_candidate_identity as native

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.stable.official.5b4e0cb0f"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True, help="official Godot Windows GUI executable")
    parser.add_argument("--engine-notices", type=Path, required=True)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = native.verify(ROOT, args.native_candidate)
    console = args.engine.with_name(args.engine.stem + "_console.exe")
    version = subprocess.check_output([str(console), "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise ValueError("Godot version differs from the pin")
    if args.output.exists():
        raise ValueError("Candidate destination must be a new directory")
    # Read source from the Git tree. Never package editor imports, untracked
    # files, local source deltas, credentials or another worktree's DLL.
    names = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json",
             "third_party/native-toolchain.lock.json", "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md",
             "docs/operations/explore001-desktop-playtest.md"]
    payload = subprocess.check_output(["git", "archive", "HEAD", "--", *names], cwd=ROOT, timeout=60)
    args.output.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for entry in archive:
            if not entry.isfile() or entry.name.startswith("godot/.godot/"):
                continue
            if "/bin/" in entry.name and entry.name not in (native.NATIVE, RAPIER):
                continue
            stream = archive.extractfile(entry)
            data = stream.read()
            if entry.name == native.NATIVE:
                data = (args.native_candidate / Path(native.NATIVE).name).read_bytes()
            elif data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                data = (ROOT / entry.name).read_bytes()
                if match is None or hashlib.sha256(data).hexdigest() != match[1].decode() or len(data) != int(match[2]):
                    raise ValueError("Unmaterialized or changed LFS payload: " + entry.name)
            target = args.output / entry.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    profiles = stage_generator_profiles(args.output)
    for engine in (args.engine, console):
        shutil.copyfile(engine, args.output / engine.name)
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        shutil.copyfile(args.engine_notices / name, args.output / ("Godot-" + name))
    shutil.copyfile(args.native_candidate / native.NAME, args.output / "source-built-candidate-provenance.json")
    # Retained provenance belongs to historical committed bytes. Give the
    # delivered DLL its own manifest rather than presenting the old one.
    runtime_manifest = args.output / "godot/addons/cybersand_native/runtime-provenance.json"
    runtime_manifest.rename(runtime_manifest.with_name("retained-runtime-provenance.reference.json"))
    (args.output / "Open Workbench.cmd").write_text(
        '@echo off\ncd /d "%~dp0"\n'
        f'set CYBERSAND_SOURCE_REVISION={manifest["source_commit"]}\n'
        f'"%~dp0{console.name}" --headless --path "%~dp0godot" --editor --quit\n'
        'if errorlevel 1 (pause & exit /b 1)\n'
        f'start "" "%~dp0{args.engine.name}" --path "%~dp0godot" -- --workbench\n',
        encoding="utf-8", newline="\r\n")
    shutil.copyfile(ROOT / "docs/operations/explore001-desktop-playtest.md", args.output / "READ-ME.md")
    files = {p.relative_to(args.output).as_posix(): native.sha(p)
             for p in sorted(args.output.rglob("*")) if p.is_file()}
    identity = {"schema": 1, "purpose": "owner desktop playtest candidate; not a production release",
                "source_commit": manifest["source_commit"], "source_tree": manifest["source_tree"],
                "godot_version": version, "native_sha256": manifest["sha256"],
                "generator_profiles_sha256": profiles, "files_sha256": files}
    (args.output / "candidate-manifest.json").write_text(json.dumps(identity, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(args.output / "Open Workbench.cmd")


if __name__ == "__main__": main()
