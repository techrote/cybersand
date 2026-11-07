"""Assemble a local Windows Godot project from a specific committed workbench tree."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.stable.official.5b4e0cb0f"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path, help="Godot 4.7 Windows editor exe")
    parser.add_argument("--output", required=True, type=Path, help="new directory")
    args = parser.parse_args()
    engine = args.engine.resolve(strict=True)
    version = subprocess.check_output([engine, "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise SystemExit(f"Expected {VERSION}, got {version}")
    output = args.output.resolve()
    if output.exists():
        raise SystemExit(f"Refusing to overwrite {output}")
    project = git("ls-tree", "-rz", "--name-only", "HEAD", "--", "godot").decode().split("\0")
    # A source file must be the committed version, and LFS entries must have
    # their materialized contents. Ignore editor-generated files outside Git.
    if git("diff", "--name-only", "HEAD", "--", "godot", "native/include", "native/src"):
        raise SystemExit("Commit project and native input changes before packaging")
    lfs = {}
    for line in git("lfs", "ls-files", "--long").decode().splitlines():
        oid, _, path = line.split(maxsplit=2)
        if path.startswith("godot/"):
            lfs[path] = oid
    for path, oid in lfs.items():
        if digest(ROOT / path) != oid:
            raise SystemExit(f"Materialize the committed LFS file {path}")
    output.mkdir(parents=True)
    for path in filter(None, project):
        destination = output / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / path, destination)
    shutil.copyfile(engine, output / "Godot.exe")
    (output / "Open Workbench.cmd").write_bytes(
        b'@echo off\r\nstart "" "%~dp0Godot.exe" --path "%~dp0godot" -- --workbench\r\n')
    manifest = {
        "source": git("rev-parse", "HEAD").decode().strip(),
        "tree": git("rev-parse", "HEAD^{tree}").decode().strip(),
        "engine": version, "engine_sha256": digest(engine), "lfs": lfs,
    }
    (output / "review-manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print(output / "Open Workbench.cmd")


if __name__ == "__main__":
    main()
