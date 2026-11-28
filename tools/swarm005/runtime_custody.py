#!/usr/bin/env python3
"""Bind the experimental reciprocal CLI to its exact committed native source.

This supplements the existing GDExtension candidate receipt. The producer and
consumer must share the same bounded Actions run; hashes do not prove a build.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import native_candidate_identity as native

NAME = "reciprocal-runtime-provenance.json"
CLI = "gentek_reciprocal.exe"
FIXTURE = "workbench_process_fixture.exe"
DIRECTORIES = ("native/experiments/gentek_swarm", "native/include", "native/src")
SUFFIXES = {".cpp", ".hpp", ".h", ".inc"}


def source(root: Path = ROOT) -> dict:
    def git(*args: str) -> str:
        return subprocess.check_output(["git", *args], cwd=root, text=True, timeout=60).strip()
    git("diff", "--exit-code", "HEAD", "--", *DIRECTORIES, "native/tests/workbench_process_fixture.cpp")
    tracked = set(git("ls-files", "--", *DIRECTORIES, "native/tests/workbench_process_fixture.cpp").splitlines())
    inputs = {}
    for directory in DIRECTORIES:
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and (path.suffix in SUFFIXES or path.name == "Makefile.reciprocal"):
                relative = path.relative_to(root).as_posix()
                if relative not in tracked:
                    raise ValueError("Untracked reciprocal source: " + relative)
                inputs[relative] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    fixture = "native/tests/workbench_process_fixture.cpp"
    if fixture not in tracked or not (root / "native/experiments/gentek_swarm/reciprocal_main.cpp").is_file():
        raise ValueError("Native reciprocal programme and lifecycle fixture must be committed first")
    inputs[fixture] = hashlib.sha256((root / fixture).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    return {"source_commit": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}"),
            "source_inputs_sha256": inputs, "source_hash_normalization": "CRLF to LF"}


def create(directory: Path, root: Path = ROOT) -> dict:
    extension = native.verify(root, directory)
    identity = source(root)
    files = {}
    for name in (CLI, FIXTURE, "toolchain.txt"):
        path = directory / name
        if not path.is_file() or (name.endswith(".exe") and path.read_bytes()[:2] != b"MZ"):
            raise ValueError("Missing source-built Windows payload: " + name)
        files[name] = {"sha256": native.sha(path), "bytes": path.stat().st_size}
    manifest = {"schema": 1, "programme": "GENTEK-SWARM-005", "draft_hold": True, **identity,
                "files": files, "extension_sha256": extension["sha256"],
                "build_custody": "Same-run source producer; verify source and binary hashes again in Windows consumer"}
    (directory / NAME).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def verify(directory: Path, root: Path = ROOT) -> dict:
    manifest = json.loads((directory / NAME).read_text(encoding="utf-8"))
    identity = source(root)
    extension = native.verify(root, directory)
    if manifest.get("schema") != 1 or manifest.get("programme") != "GENTEK-SWARM-005" or manifest.get("draft_hold") is not True:
        raise ValueError("Wrong experimental runtime receipt")
    if any(manifest.get(key) != value for key, value in identity.items()) or manifest.get("extension_sha256") != extension["sha256"]:
        raise ValueError("Reciprocal runtime is not bound to this source and native adapter")
    if set(manifest.get("files", {})) != {CLI, FIXTURE, "toolchain.txt"}:
        raise ValueError("Incomplete reciprocal runtime payload")
    for name, record in manifest["files"].items():
        path = directory / name
        if native.sha(path) != record.get("sha256") or path.stat().st_size != record.get("bytes"):
            raise ValueError("Reciprocal runtime payload changed: " + name)
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--create", action="store_true")
    args = parser.parse_args()
    result = create(args.directory) if args.create else verify(args.directory)
    print(result["source_commit"], result["files"][CLI]["sha256"])


if __name__ == "__main__":
    main()
