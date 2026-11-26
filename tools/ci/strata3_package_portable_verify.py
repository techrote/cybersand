#!/usr/bin/env python3
"""External Linux re-reading of the exact frozen Strata003 Windows evaluator.

The original package verifier runs unchanged. Its only supplied function is the
separately reviewed predecessor.verify with one platform-aware basename fix.
This command never invokes Godot or changes any original package/source file.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import types
import zipfile

import strata3_predecessor_portable_verify as paired

PACKAGE_READER = "tools/package_strata3_workbench.py"
MANIFEST = "evaluation-manifest.json"
EXPECTED_PATH_REFUSAL = "Observation did not execute the external graphical driver"
require = paired.require


def file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def archive_member_name(value: str) -> Path:
    require(isinstance(value, str) and value and not re.search(r'[\x00-\x1f<>:"|?*\\]', value),
            "Unsafe or platform-dependent ZIP member")
    parts = value.split("/")
    require(all(part and part not in (".", "..") and not part.endswith((" ", "."))
                and part.split(".")[0].upper() not in
                {"CON", "PRN", "AUX", "NUL", *("COM" + str(i) for i in range(1, 10)),
                 *("LPT" + str(i) for i in range(1, 10))} for part in parts),
            "Unsafe or ambiguous ZIP member")
    return Path(*parts)


def snapshot(folder: Path) -> dict[str, str]:
    result = {}
    for path in sorted(folder.rglob("*")):
        require(not path.is_symlink(), "Linked extracted payload")
        if path.is_file():
            result[path.relative_to(folder).as_posix()] = file_sha(path)
    return result


def inspect_archive(archive: Path, expected_sha: str, expected_manifest_sha: str):
    require(all(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value)
                and value != "0" * 64 for value in (expected_sha, expected_manifest_sha)),
            "Supply actual lowercase ZIP and manifest SHA-256 identities")
    require(archive.is_file() and not archive.is_symlink() and archive.stat().st_size <= 2 * 1024**3
            and file_sha(archive) == expected_sha, "Original evaluator ZIP identity differs")
    files, folded, total = {}, set(), 0
    with zipfile.ZipFile(archive) as bundle:
        require(0 < len(bundle.infolist()) <= 50000, "Unbounded evaluator ZIP inventory")
        for item in bundle.infolist():
            # zipfile can normalize backslashes on Windows or truncate NUL names.
            require(item.orig_filename == item.filename, "ZIP member spelling was normalized")
            archive_member_name(item.orig_filename)
            require(not item.is_dir() and stat.S_IFMT(item.external_attr >> 16) in (0, stat.S_IFREG)
                    and not item.flag_bits & 1 and item.filename.casefold() not in folded,
                    "Duplicate, encrypted or non-file ZIP member")
            folded.add(item.filename.casefold())
            total += item.file_size
            require(item.file_size <= 1024**3 and total <= 8 * 1024**3, "Evaluator exceeds bounded extraction size")
            digest = hashlib.sha256()
            with bundle.open(item) as source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(block)
            files[item.filename] = digest.hexdigest()
        require(files.get(MANIFEST) == expected_manifest_sha, "Original evaluator manifest identity differs")
        manifest = json.loads(bundle.read(MANIFEST))
    return manifest, files, total


def extract_original(archive: Path, folder: Path, files: dict) -> None:
    require(not folder.exists() and not folder.is_symlink(), "Use an absent extraction directory")
    folder.mkdir(parents=True)
    with zipfile.ZipFile(archive) as bundle:
        for name in files:
            target = folder / archive_member_name(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.open(name) as source, target.open("xb") as output:
                shutil.copyfileobj(source, output, 1024 * 1024)
    require(snapshot(folder) == files, "Extracted bytes differ from the original ZIP")


def frozen_module_inputs(root: Path, package) -> dict[str, str]:
    expected = {
        "tools/ci/qualify_strata3_workbench.py": package.optics,
        "tools/ci/qualify_strata2_workbench.py": package.compatibility,
        paired.READER: package.predecessor,
        "tools/build_strata3_gallery.py": package.gallery,
        "tools/package_strata2_workbench.py": package.base,
        "tools/qualify_workbench_landscapes.py": package.compatibility.custody,
        "tools/ci/strata_process_metrics.py": package.predecessor.metrics,
    }
    for name in ("package_wave_flow_candidate", "package_explore001_candidate", "package_workbench_landscape_review"):
        expected["tools/" + name + ".py"] = sys.modules[name]
    for name, module in expected.items():
        require(Path(module.__file__).resolve() == root / name,
                "Package dependency loaded outside the frozen application: " + name)
    inputs = {}
    for module in [package, *list(sys.modules.values())]:
        filename = getattr(module, "__file__", None)
        if not filename:
            continue
        path = Path(filename).resolve()
        if path.suffix != ".py" or not path.is_relative_to(root):
            continue
        name = path.relative_to(root).as_posix()
        raw = path.read_bytes()
        committed = subprocess.check_output(["git", "-C", str(root), "show", paired.APPLICATION + ":" + name],
                                            stderr=subprocess.PIPE)
        require(raw == committed, "Frozen package dependency bytes changed: " + name)
        inputs[name] = paired.digest(raw)
    require(PACKAGE_READER in inputs and set(expected) <= set(inputs), "Incomplete frozen package module custody")
    return inputs


def load_package_reader(source_repo: Path):
    root = source_repo.resolve()
    frozen_paired, portable_verify, paired_identity = paired.load_frozen_reader(root)
    path = root / PACKAGE_READER
    raw = path.read_bytes()
    committed = subprocess.check_output(["git", "-C", str(root), "show", paired.APPLICATION + ":" + PACKAGE_READER],
                                        stderr=subprocess.PIPE)
    require(raw == committed, "Frozen package reader differs from exact application source")
    package = types.ModuleType("_strata3_package_frozen_fd")
    package.__file__ = str(path)
    exec(compile(raw, str(path), "exec"), package.__dict__)
    inputs = frozen_module_inputs(root, package)
    require(package.ROOT == root and package.compatibility.identity() == frozen_paired.previous.identity(),
            "Frozen package and paired reader source identities differ")
    return package, portable_verify, paired_identity, inputs


def invoke_frozen_package(package, portable_verify, folder: Path):
    original = package.predecessor.verify
    try:
        original_manifest = package.verify(folder, pristine=True)
        original_outcome = {"status": "passed"}
    except Exception as error:
        require(str(error) == EXPECTED_PATH_REFUSAL,
                "Original package reader failed outside the registered path limitation: " + str(error))
        original_manifest = None
        original_outcome = {"status": "rejected", "reason": str(error)}
    try:
        package.predecessor.verify = portable_verify
        portable_manifest = package.verify(folder, pristine=True)
    finally:
        package.predecessor.verify = original
    require(package.predecessor.verify is original, "Frozen predecessor function was not restored")
    if original_manifest is not None:
        require(original_manifest == portable_manifest, "Original and portable package manifests disagree")
    return original_outcome, portable_manifest


def verify_package(source_repo: Path, archive: Path, folder: Path, expected_sha: str, expected_manifest_sha: str):
    root, archive, folder = source_repo.resolve(), archive.absolute(), folder.resolve(strict=False)
    require(not folder.is_relative_to(root), "Keep external extraction outside the frozen application")
    package, portable_verify, paired_identity, inputs_before = load_package_reader(root)
    manifest, files, uncompressed_bytes = inspect_archive(archive, expected_sha, expected_manifest_sha)
    extract_original(archive, folder, files)
    outcome, admitted_manifest = invoke_frozen_package(package, portable_verify, folder)
    require(admitted_manifest == manifest, "Frozen package result differs from original ZIP manifest")
    require(snapshot(folder) == files and file_sha(archive) == expected_sha,
            "Original extracted payload or ZIP changed during read-only verification")
    inputs_after = frozen_module_inputs(root, package)
    require(inputs_after == inputs_before, "Frozen package verifier module inventory changed")
    return {
        "schema": "strata3-portable-package-verification-v1", "status": "passed",
        "application_source": paired.APPLICATION, "application_tree": paired.APPLICATION_TREE,
        "package": {"archive_filename": archive.name, "archive_bytes": archive.stat().st_size,
                    "archive_sha256": expected_sha, "manifest_sha256": expected_manifest_sha,
                    "file_count_including_manifest": len(files), "uncompressed_bytes": uncompressed_bytes},
        "reader_identity": {"frozen_package_reader": PACKAGE_READER,
                            "frozen_package_reader_sha256": inputs_before[PACKAGE_READER],
                            "external_adapter_sha256": file_sha(Path(__file__)),
                            "paired_adapter": paired_identity, "frozen_module_inputs_sha256": inputs_before},
        "original_frozen_package_reader_outcome": outcome,
        "portable_frozen_package_reader_outcome": {"status": "passed", "pristine": True},
        "original_archive_and_extracted_bytes_unchanged": True,
        "original_predecessor_function_restored": True,
        "godot_invocations": 0,
        "scope": "Complete frozen static package verifier, with only the reviewed one-expression predecessor path adapter supplied in memory. Expected archive/manifest hashes come from separate download custody. No application execution, package rewrite, or weakening of any other package gate.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-repo", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--extract-to", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.output:
            require(not args.output.exists(), "Use a fresh portable package receipt")
            require(not args.output.resolve().is_relative_to(args.extract_to.resolve())
                    and not args.output.resolve().is_relative_to(args.source_repo.resolve()),
                    "Keep the external receipt outside the pristine payload and frozen source")
        result = verify_package(args.source_repo, args.archive, args.extract_to, args.archive_sha256, args.manifest_sha256)
        raw = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(raw, encoding="utf-8")
        print(raw)
        return 0
    except Exception as error:
        print("PORTABLE_PACKAGE_REJECTED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
