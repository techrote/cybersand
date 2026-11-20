#!/usr/bin/env python3
"""Qualify actual GEN-007 cells, including an independently compiled CLASSIC parent.

Usage: python3 tools/architecture/qualify_metabolist.py --compiler g++ --output build/metabolist-qualification
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
TEST = "native/tests/test_metabolist_spine.cpp"


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


def source_identity(root: Path) -> dict:
    """Bind all consumed source bytes to a clean immutable Git commit."""
    paths = sorted({*SOURCES, *COMPARISON_INPUTS, TEST, "Makefile", "tools/architecture/qualify_metabolist.py",
                    *(str(path.relative_to(root)) for path in (root / "native/include").rglob("*.hpp")),
                    *(str(path.relative_to(root)) for path in (root / "native/include").rglob("*.h")),
                    *(str(path.relative_to(root)) for path in (root / "native/src").glob("*.inc"))})
    head = run(["git", "rev-parse", "HEAD"], root).strip()
    tree = run(["git", "rev-parse", "HEAD^{tree}"], root).strip()
    dirty = run(["git", "status", "--porcelain", "--untracked-files=all", "--", *paths], root)
    if dirty:
        raise RuntimeError("qualification requires committed clean source inputs:\n" + dirty)
    inputs = {path: digest((root / path).read_bytes()) for path in paths}
    # Compare actual bytes too: status alone may be defeated by cached stat data
    # or assume-unchanged flags. Every source input must exist in this exact HEAD.
    for path, actual in inputs.items():
        committed = subprocess.run(["git", "show", head + ":" + path], cwd=root,
                                   capture_output=True, check=False, timeout=30)
        if committed.returncode or digest(committed.stdout) != actual:
            raise RuntimeError("source input does not match HEAD: " + path)
    return {"commit": head, "tree": tree, "inputs": inputs}


def require_unchanged_source(root: Path, before: dict) -> None:
    if source_identity(root) != before:
        raise RuntimeError("source inputs, HEAD or tree changed during qualification; discard and rerun")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default="g++")
    parser.add_argument("--output", type=Path, default=Path("build/metabolist-qualification"))
    parser.add_argument("--parent-ref", default=PARENT)
    parser.add_argument("--skip-benchmark", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    parent_sha = run(["git", "rev-parse", f"{args.parent_ref}^{{commit}}"], root).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", args.parent_ref) or parent_sha != args.parent_ref:
        raise ValueError("--parent-ref must be an immutable full 40-character commit SHA")
    source_before = source_identity(root)
    source_sha = source_before["commit"]
    compiler_version = run([args.compiler, "--version"], root).splitlines()[0]
    # Rebuild consumed objects even when mtimes are unchanged: a cached make
    # target cannot attest which compiler or flags produced its existing bytes.
    run(["make", "-B", "-j2", "build/test_metabolist_spine", f"CXX={args.compiler}"], root)
    candidate = root / "build/test_metabolist_spine"
    native = json.loads(run([str(candidate)], root))
    save(output / "native-tests.json", native)
    candidate_snapshot = output / "legacy-candidate.le16"
    parent_snapshot = output / "legacy-parent.le16"
    candidate_legacy = json.loads(run([str(candidate), "--legacy", str(candidate_snapshot)], root))

    candidate_viaduct = output / "viaduct-candidate.le16"
    parent_viaduct = output / "viaduct-parent.le16"
    candidate_viaduct_result = json.loads(run([str(candidate), "--viaduct", str(candidate_viaduct)], root))

    # Compile the same black-box fixture against only the parent native source.
    # Its --legacy mode does not request the new module and is deliberately
    # compilable with the unchanged public GEN-007 API from the parent commit.
    archive = subprocess.run(["git", "archive", "--format=tar", parent_sha, "native"],
                             cwd=root, capture_output=True, check=True, timeout=60).stdout
    with tempfile.TemporaryDirectory(prefix="metabolist-parent-", dir=root / "build") as temporary:
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
        parent_viaduct_result = json.loads(run([str(parent_binary), "--viaduct", str(parent_viaduct)], root))
        parent_binary_sha256 = digest(parent_binary.read_bytes())
    if candidate_viaduct.read_bytes() != parent_viaduct.read_bytes():
        raise AssertionError("Accepted Viaduct v1/v2 materials, fingerprints or receipts changed")
    viaduct = {"status":"pass", "versions":[1,2], "material_cells":98304,
               "snapshot_sha256":digest(parent_viaduct.read_bytes()),
               "candidate_fixture":candidate_viaduct_result, "parent_fixture":parent_viaduct_result}
    save(output / "viaduct-comparison.json", viaduct)
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
    comparison = compare_legacy_snapshots(root, before, after, ids, parent_sha, header=header)
    legacy = {"status": "pass", "parent_source": parent_sha, "modules": 72,
              "configurations_per_module": 3, "chunks_per_configuration": 4,
              "cells_compared": expected_cells, "exact_bytes_compared": len(before),
              "snapshot_sha256": digest(before), "parent_fixture": parent_legacy,
              "candidate_fixture": candidate_legacy, **comparison}
    save(output / "legacy-comparison.json", legacy)
    benchmark = None
    if not args.skip_benchmark:
        benchmark = json.loads(run([str(candidate), "--benchmark"], root))
        save(output / "benchmark.json", benchmark)
    require_unchanged_source(root, source_before)
    source_inputs = source_before["inputs"]
    report = {"status": "pass", "source_commit": source_sha, "source_tree": source_before["tree"], "source_inputs_dirty": False,
              "source_identity_checked_before_and_after": True,
              "source_inputs_sha256": source_inputs, "parent_source": parent_sha,
              "original_showcase_parent_source": ORIGINAL_SHOWCASE_PARENT,
              "compiler": compiler_version, "platform": platform.platform(),
              "candidate_binary_sha256": digest(candidate.read_bytes()),
              "parent_binary_sha256": parent_binary_sha256,
              "native": native, "viaduct": viaduct, "legacy": {key: value for key, value in legacy.items()
                                            if key not in {"module_receipts", "parent_fixture", "candidate_fixture"}},
              "benchmark": benchmark,
              "scope": "Native CPU GEN-007 material generation; no physical GPU or owner aesthetic acceptance"}
    save(output / "qualification.json", report)
    print(json.dumps({"status": "pass", "output": str(output / "qualification.json"),
                      "assertions": native["assertions"], "legacy_cells_compared": expected_cells,
                      "parent_source": parent_sha, "source_commit": source_sha}))


if __name__ == "__main__":
    main()
