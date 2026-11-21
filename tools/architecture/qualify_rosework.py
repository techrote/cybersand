#!/usr/bin/env python3
"""Qualify actual GEN-007 cells, including an independently compiled CLASSIC parent.

Usage: python3 tools/architecture/qualify_rosework.py --compiler g++ --output build/rosework-qualification
The parent is extracted from its immutable Git commit; no branch/worktree is edited.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import platform
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path

from classic_repair_comparison import COMPARISON_INPUTS, compare_legacy_snapshots

ORIGINAL_SHOWCASE_PARENT = "615828b28337f85e4663e03ba479616db4ddf764"
# The integration qualifies preservation against the authoritative repaired CLASSIC source.
PARENT = "e27ff75758ef51c7b7c8b4d8a7093343cc2ecede"
SOURCES = [
    "native/src/world_generation.cpp", "native/src/generation_fields.cpp",
    "native/src/generation_typed_fields.cpp", "native/src/generation_spatial.cpp",
    "native/src/generation_grammar.cpp", "native/src/generation_planes.cpp",
]
TEST = "native/tests/test_rosework_gatehouse.cpp"
DRIVER = "tools/architecture/qualify_rosework.py"
DRIVER_TEST = "tools/architecture/test_qualify_rosework.py"


def run(command: list[str], cwd: Path, *, timeout: int = 900) -> str:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True,
                               timeout=timeout, check=False)
    if completed.returncode:
        raise RuntimeError(f"Command failed ({completed.returncode}): {' '.join(command)}\n"
                           f"{completed.stdout}\n{completed.stderr}")
    return completed.stdout


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def save(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def source_input_paths(root: Path) -> list[str]:
    return sorted({*SOURCES, *COMPARISON_INPUTS, TEST, DRIVER, DRIVER_TEST, "Makefile",
                   *(str(path.relative_to(root))
                     for directory in (root / "native/include", root / "native/src")
                     for path in directory.rglob("*")
                     if path.is_file() and path.suffix in {".hpp", ".h", ".inc"})})


def capture_source_identity(root: Path) -> dict:
    """Bind clean on-disk inputs to their actual committed bytes before use."""
    paths = source_input_paths(root)
    head = run(["git", "rev-parse", "HEAD", "HEAD^{tree}"], root).splitlines()
    status_command = ["git", "status", "--porcelain", "--untracked-files=all",
                      "--ignored", "--", *paths]
    if run(status_command, root).strip():
        raise RuntimeError("Qualification source inputs must be clean and tracked before use")
    inputs = {path: digest((root / path).read_bytes()) for path in paths}

    # Compare bytes as well as Git status: preserved timestamps, an ignored new
    # header or an index refresh must not hide uncommitted build inputs.
    archive = subprocess.run(["git", "archive", "--format=tar", head[0], "--", *paths],
                             cwd=root, capture_output=True, check=True, timeout=60).stdout
    committed = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as package:
        for member in package.getmembers():
            if member.isfile() and member.name in inputs:
                stream = package.extractfile(member)
                assert stream is not None
                committed[member.name] = digest(stream.read())
    if committed != inputs:
        raise RuntimeError("Qualification input bytes do not match the recorded HEAD")
    if run(["git", "rev-parse", "HEAD", "HEAD^{tree}"], root).splitlines() != head or \
            run(status_command, root).strip():
        raise RuntimeError("Qualification source changed while capturing its identity")
    return {"commit": head[0], "tree": head[1], "inputs": inputs,
            "input_sha256": digest(json.dumps(inputs, sort_keys=True,
                                               separators=(",", ":")).encode())}


def require_unchanged_source(root: Path, before: dict) -> dict:
    # Enumerate again so newly added headers cannot escape the original ledger.
    after = capture_source_identity(root)
    if after != before:
        raise RuntimeError("Qualification source HEAD, tree or inputs changed during execution")
    return after


def qualify(root: Path, args: argparse.Namespace, output: Path,
            parent_sha: str, source: dict) -> dict:
    compiler_version = run([args.compiler, "--version"], root).splitlines()[0]
    candidate_build_command = ["make", "-B", "-j2", "build/test_rosework_gatehouse", f"CXX={args.compiler}"]
    (output / "candidate-build.log").write_text(run(candidate_build_command, root))
    candidate = root / "build/test_rosework_gatehouse"
    native = json.loads(run([str(candidate)], root))
    save(output / "native-tests.json", native)
    candidate_snapshot = output / "legacy-candidate.le16"
    parent_snapshot = output / "legacy-parent.le16"
    candidate_legacy = json.loads(run([str(candidate), "--legacy", str(candidate_snapshot)], root))
    candidate_viaduct = output / "viaduct-candidate.le16"
    parent_viaduct = output / "viaduct-parent.le16"
    run([str(candidate), "--viaduct", str(candidate_viaduct)], root)

    # Compile the same black-box fixture against only the parent native source.
    # Its --legacy mode does not request the new module and is deliberately
    # compilable with the unchanged public GEN-007 API from the parent commit.
    archive = subprocess.run(["git", "archive", "--format=tar", parent_sha, "native"],
                             cwd=root, capture_output=True, check=True, timeout=60).stdout
    with tempfile.TemporaryDirectory(prefix="rosework-parent-", dir=root / "build") as temporary:
        parent_root = Path(temporary)
        with tarfile.open(fileobj=io.BytesIO(archive)) as package:
            package.extractall(parent_root, filter="data")
        parent_binary = parent_root / "parent-qualification"
        parent_build_command = [args.compiler, "-std=c++20", "-O2", "-g", "-Wall", "-Wextra",
                                "-Wpedantic", "-Wconversion", "-Wshadow", "-Werror",
                                f"-I{parent_root / 'native/include'}"]
        parent_build_command += [str(parent_root / source) for source in SOURCES]
        parent_build_command += [str(root / TEST), "-o", str(parent_binary)]
        run(parent_build_command, root)
        parent_legacy = json.loads(run([str(parent_binary), "--legacy", str(parent_snapshot)], root))
        run([str(parent_binary), "--viaduct", str(parent_viaduct)], root)
        parent_binary_sha256 = digest(parent_binary.read_bytes())
    expected_cells = 72 * 3 * 4 * 64 * 64
    header = b"CLASSIC72-LE16-v1\n"
    per_module = 3 * (8 + 4 * (16 + 64 * 64 * 2))
    expected_length = len(header) + 72 * per_module
    before, after = parent_snapshot.read_bytes(), candidate_snapshot.read_bytes()
    if len(before) != expected_length or len(after) != expected_length:
        raise AssertionError("Legacy dump incomplete or unexpectedly sized")
    if not before.startswith(header) or not after.startswith(header):
        raise AssertionError("Unexpected legacy snapshot encoding")
    ids_match = re.search(r"classic_ids\{(.*?)\};", (root / TEST).read_text(), re.S)
    if ids_match is None:
        raise AssertionError("Could not read the exact tested catalogue")
    ids = re.findall(r'"([a-z_]+)"', ids_match.group(1))
    if len(ids) != 72 or len(set(ids)) != 72:
        raise AssertionError("Legacy fixture does not name 72 distinct modules")
    comparison = compare_legacy_snapshots(root, before, after, ids, parent_sha, header=header, palette="rosework")
    legacy = {"status": "pass", "parent_source": parent_sha, "modules": 72,
              "configurations_per_module": 3, "chunks_per_configuration": 4,
              "cells_compared": expected_cells, "exact_bytes_compared": len(before),
              "snapshot_sha256": digest(before), "parent_fixture": parent_legacy,
              "candidate_fixture": candidate_legacy, **comparison}
    save(output / "legacy-comparison.json", legacy)
    viaduct = {"status": "pass", "versions": [1,2], "material_cells": 98304,
                "snapshot_sha256": digest(parent_viaduct.read_bytes()),
                "exact_bytes_compared": len(parent_viaduct.read_bytes())}
    if candidate_viaduct.read_bytes() != parent_viaduct.read_bytes():
        raise AssertionError("Viaduct v1/v2 native cells or identity changed")
    save(output / "viaduct-comparison.json", viaduct)
    benchmark = None
    if not args.skip_benchmark:
        benchmark = json.loads(run([str(candidate), "--benchmark"], root))
        save(output / "benchmark.json", benchmark)
    return {"status": "pass", "source_commit": source["commit"], "source_tree": source["tree"], "source_inputs_dirty": False,
              "source_inputs_sha256": source["inputs"], "parent_source": parent_sha,
              "original_showcase_parent_source": ORIGINAL_SHOWCASE_PARENT,
              "candidate_build_command": candidate_build_command, "compiler": compiler_version, "platform": platform.platform(),
              "candidate_binary_sha256": digest(candidate.read_bytes()),
              "parent_binary_sha256": parent_binary_sha256,
              "native": native, "legacy": {key: value for key, value in legacy.items()
                                            if key not in {"module_receipts", "parent_fixture", "candidate_fixture"}},
              "viaduct": viaduct, "benchmark": benchmark,
              "scope": "Native CPU GEN-007 material generation; no physical GPU or owner aesthetic acceptance"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default="g++")
    parser.add_argument("--output", type=Path, default=Path("build/rosework-qualification"))
    parser.add_argument("--parent-ref", default=PARENT)
    parser.add_argument("--skip-benchmark", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    parent_sha = run(["git", "rev-parse", f"{args.parent_ref}^{{commit}}"], root).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", args.parent_ref) or parent_sha != args.parent_ref:
        raise ValueError("--parent-ref must be an immutable full 40-character commit SHA")

    # Refuse dirty inputs before compiling or running any native executable.
    source = capture_source_identity(root)
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # A failed or concurrently changed run must not overwrite prior successful
    # evidence, including intermediate test results and legacy cell snapshots.
    with tempfile.TemporaryDirectory(prefix="rosework-qualification-", dir=output.parent) as temporary:
        staging = Path(temporary)
        report = qualify(root, args, staging, parent_sha, source)
        after = require_unchanged_source(root, source)
        report["source_verification"] = {
            "before": {key: value for key, value in source.items() if key != "inputs"},
            "after": {key: value for key, value in after.items() if key != "inputs"},
            "clean_before_and_after": True, "identical_inputs_head_and_tree": True}
        save(staging / "qualification.json", report)
        output.mkdir(parents=True, exist_ok=True)
        for artifact in staging.iterdir():
            artifact.replace(output / artifact.name)
    print(json.dumps({"status": "pass", "output": str(output / "qualification.json"),
                      "assertions": report["native"]["assertions"],
                      "legacy_cells_compared": report["legacy"]["cells_compared"],
                      "parent_source": parent_sha, "source_commit": source["commit"]}))


if __name__ == "__main__":
    main()
