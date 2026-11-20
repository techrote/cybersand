#!/usr/bin/env python3
"""Bind native Cathedral captures to unchanged source bytes and runtime inputs.

Take `snapshot` immediately before the native build. `verify` after rendering
rejects source drift. `seal` also records all retained output SHA-256 values.
This ledger does not manufacture runtime provenance from an arbitrary binary:
its build invocation and toolchain fields must accompany the actual build log.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(root: Path, *arguments: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *arguments], text=True).strip()


def sources(root: Path) -> dict[str, str]:
    paths: set[Path] = set()
    for directory in ("native/include", "native/src", "native/tests", "godot/native_extension", "godot/scripts", "godot/tests"):
        paths.update(path for path in (root / directory).rglob("*") if path.is_file() and path.suffix in (".cpp", ".h", ".hpp", ".inc", ".gd", ".gdshader"))
    paths.update(root / name for name in (
        "Makefile", "tools/build_native_extension.sh", "tools/build_pinned_godot_cpp.sh",
        "tools/requirements-build.txt", "tools/toolchains/g++", "tools/verify_pinned_source_tree.py",
        "third_party/native-toolchain.lock.json", "third_party/godot-runtime.lock.json",
        "godot/third_party/rapier2d.lock.json", "godot/addons/cybersand_native/cybersand_native.gdextension",
        "godot/addons/godot-rapier2d/godot-rapier2d.gdextension", "godot/project.godot",
        "tools/ci/gentek_cathedral_evidence.py",
        ".github/workflows/gentek-cathedral-showcase.yml",
        "examples/worldgen/architectural/cathedral-megaframe.style.json"))
    return {str(path.relative_to(root)): digest(path) for path in sorted(paths) if path.is_file()}


def fingerprint(files: dict[str, str]) -> str:
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("snapshot", "verify", "seal"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--godot-cpp", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    path = output / "source-ledger.json"
    current = sources(root)
    if args.action == "snapshot":
        data = {"schema": 1, "case": "GENTEK-SHOWCASE-CATHEDRAL-001", "source_commit": git(root, "rev-parse", "HEAD"),
                "source_tree": git(root, "rev-parse", "HEAD^{tree}"), "branch": git(root, "branch", "--show-current"),
                "parent_commit": "615828b28337f85e4663e03ba479616db4ddf764",
                "source_files_sha256": current, "source_inputs_sha256": fingerprint(current),
                "working_tree_status": git(root, "status", "--short"),
                "build_boundary": "snapshot before native build; source comparison after native execution"}
        if args.godot_cpp:
            data["godot_cpp_commit"] = git(args.godot_cpp.resolve(), "rev-parse", "HEAD")
            library = args.godot_cpp / "bin/libgodot-cpp.linux.template_debug.x86_64.a"
            if library.is_file():
                data["godot_cpp_library_sha256"] = digest(library)
        path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
        print(f"SNAPSHOT {data['source_commit']} inputs={data['source_inputs_sha256']} files={len(current)}")
        return
    original = json.loads(path.read_text())
    changed = sorted(name for name in current.keys() | original["source_files_sha256"].keys()
                     if current.get(name) != original["source_files_sha256"].get(name))
    if changed:
        raise SystemExit("Source changed during build/capture; rebuild and rerun: " + ", ".join(changed))
    print(f"VERIFIED unchanged source inputs {fingerprint(current)}")
    if args.action == "verify":
        return
    report = json.loads((output / "cathedral-showcase-report.json").read_text())
    if report.get("failures") != 0 or report.get("partial_iteration") is not False:
        raise SystemExit("Cannot seal incomplete or failed showcase campaign")
    if not args.runtime or not args.runtime.is_file():
        raise SystemExit("seal requires the actual executed --runtime")
    runtime_hash = digest(args.runtime)
    if runtime_hash != report.get("runtime_sha256"):
        raise SystemExit("Executed runtime hash differs from the retained runtime")
    if report.get("source_commit") != original["source_commit"]:
        raise SystemExit("Capture process reported another source commit")
    final = {"schema": 1, "source_commit": original["source_commit"], "source_inputs_sha256": fingerprint(current),
             "runtime_sha256": runtime_hash, "source_unchanged_through_execution": True,
             "godot_version": report["godot"], "os": report["os"],
             "checks": report["checks"], "failures": report["failures"],
             "artifact_files_sha256": {str(p.relative_to(output)): digest(p) for p in sorted(output.rglob("*"))
                                        if p.is_file() and p.name != "artifact-ledger.json"}}
    if args.godot:
        final["godot_binary_sha256"] = digest(args.godot)
    (output / "artifact-ledger.json").write_text(json.dumps(final, indent=2, sort_keys=True) + "\n")
    print(f"SEALED runtime={runtime_hash} files={len(final['artifact_files_sha256'])}")


if __name__ == "__main__":
    main()
