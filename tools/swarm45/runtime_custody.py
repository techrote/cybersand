#!/usr/bin/env python3
"""Source and target-OS custody for the unified SWARM-004/005/006 integration.

This does not rebuild, publish, retag a donor, or accept a local diagnostic.
Hosted producer/consumer identity and original build bytes remain explicit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import native_candidate_identity as native

NAME = "swarm45-runtime-provenance.json"
PROGRAMME = "GENTEK-SWARM-004-005-MAINLINE"
QUALIFICATION_PROGRAMME = "GENTEK-SWARM-004-005-006-UNIFIED"
BRANCH = "integration/swarm004-005-006-unified-20261122"
WORKFLOW = ".github/workflows/swarm456-qualification.yml"
GODOT_CPP = "101ae38034304346a46ea9ea84ae156d3e860496"
RECIPROCAL_TESTS = ("test_assembly", "test_reciprocal_mosaic", "test_reciprocal", "test_swarm005",
                    "test_swarm006_source", "test_swarm006_admission", "test_custody_hash", "test_swarm006_recovery")
NATIVE_TESTS = (*RECIPROCAL_TESTS, "test_workbench_authoring_patch")
EXTENSIONS = {
    "linux": "libcybersand_native.linux.x86_64.so",
    "windows": "cybersand_native.windows.x86_64.dll",
}
NATIVE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
SOURCE_DIRECTORIES = ("native/include", "native/src", "godot/native_extension", "native/experiments/gentek_swarm")
BUILD_DIRECTORIES = (*SOURCE_DIRECTORIES, "native/tests", "godot/scripts", "godot/tests", "godot/shaders",
                     "godot/authoring", "godot/examples", "examples/worldgen", "tools", ".github/workflows", "third_party")
BUILD_EXACT = (".gitattributes", "Makefile", "godot/project.godot", "godot/main.tscn",
               "godot/feature_launcher.tscn", "godot/third_party/rapier2d.lock.json",
               "godot/addons/cybersand_native/cybersand_native.gdextension",
               "godot/addons/godot-rapier2d/godot-rapier2d.gdextension",
               "godot/addons/godot-rapier2d/runtime-provenance.linux.json",
               "godot/addons/godot-rapier2d/runtime-provenance.windows.json",
               "godot/addons/godot-rapier2d/Radial2D.svg.import",
               "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
               "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
               "godot/addons/godot-rapier2d/logo_square_2d.png.import")
DEFINITION_EXTRA = ("../../../native/src/generation_spatial.cpp", "../../../native/include/cybersand/material.hpp",
                    "../../../native/include/cybersand/generation_spatial.hpp", "../../../native/include/cybersand/generation_numeric.hpp")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"))


def git(root: Path, *arguments: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *arguments], text=True, timeout=120).strip()


def canonical(path: Path) -> str:
    require(path.is_file() and not path.is_symlink(), "Missing or symlinked source: " + str(path))
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def definition_hash(root: Path = ROOT) -> str:
    """Exactly reproduce Makefile.reciprocal's ordered path-and-byte definition."""
    directory = root / "native/experiments/gentek_swarm"
    names = [p.name for p in sorted(directory.glob("*.cpp"))] + [p.name for p in sorted(directory.glob("*.hpp"))]
    require(bool(names), "Missing reciprocal source")
    paths = names + list(DEFINITION_EXTRA)
    return hashlib.sha256(b"".join(name.encode() + b"\0" + (directory / name).read_bytes()
                                    for name in paths)).hexdigest()


def definition_inputs(root: Path = ROOT) -> dict[str, str]:
    directory = root / "native/experiments/gentek_swarm"
    paths = [*sorted(directory.glob("*.cpp")), *sorted(directory.glob("*.hpp")),
             *(directory / name for name in DEFINITION_EXTRA)]
    require(bool(paths), "Native definition inputs missing")
    return {path.resolve().relative_to(root.resolve()).as_posix(): canonical(path) for path in paths}


def source(root: Path = ROOT, require_clean: bool = True) -> dict:
    """Return the actual source inventory; dirty snapshots are diagnostic only."""
    root = root.resolve()
    paths = (*BUILD_DIRECTORIES, *BUILD_EXACT)
    if require_clean:
        git(root, "diff", "--exit-code", "HEAD", "--", *paths)
    tracked = git(root, "ls-files", "-z", "--", *paths).split("\0")
    tracked = sorted(name for name in tracked if name)
    require(len(tracked) == len(set(tracked)) and bool(tracked), "Missing or ambiguous source inventory")
    if require_clean:
        untracked = git(root, "ls-files", "--others", "--exclude-standard", "--", *paths)
        require(not untracked, "Untracked build inputs: " + untracked)
    build_inputs = {name: canonical(root / name) for name in tracked}
    native_inputs = {name: digest for name, digest in build_inputs.items()
                     if any(name.startswith(directory + "/") for directory in SOURCE_DIRECTORIES)
                     and (Path(name).suffix in NATIVE_SUFFIXES or Path(name).name == "Makefile.reciprocal")}
    fixture = "native/tests/workbench_process_fixture.cpp"
    require(fixture in build_inputs and len(native_inputs) > 4, "Incomplete reciprocal/native build inventory")
    native_inputs[fixture] = build_inputs[fixture]
    extension_inputs = {name: digest for name, digest in native_inputs.items()
                        if any(name.startswith(directory + "/") for directory in SOURCE_DIRECTORIES[:3])
                        and Path(name).suffix in NATIVE_SUFFIXES}
    return {"source_commit": git(root, "rev-parse", "HEAD"), "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
            "source_inputs_sha256": native_inputs, "extension_inputs_sha256": extension_inputs,
            "build_inputs_sha256": build_inputs, "native_definition_sha256": definition_hash(root),
            "native_definition_inputs_sha256": definition_inputs(root),
            "source_hash_normalization": "CRLF to LF; compiled definition uses exact LF native bytes",
            "clean_source_required": require_clean}


def names(platform: str) -> dict:
    require(platform in EXTENSIONS, "Unsupported target OS")
    suffix = ".exe" if platform == "windows" else ""
    return {"cli": "gentek_reciprocal" + suffix, "fixture": "workbench_process_fixture" + suffix,
            "extension": EXTENSIONS[platform], "tests": [name + suffix for name in NATIVE_TESTS]}


def cli_binding(receipt: dict) -> dict:
    """OS-specific ordinary-checkout binding; build source is never retagged."""
    return {"schema": 1, "programme": PROGRAMME, "qualification_programme": QUALIFICATION_PROGRAMME, "draft_hold": True,
            "platform": receipt["platform"], "source": receipt["source_commit"],
            "artifact": "godot/tools/" + receipt["cli"],
            "source_commit": receipt["source_commit"], "build_commit": receipt["build_commit"],
            "source_tree": receipt["source_tree"], "native_definition_sha256": receipt["native_definition_sha256"],
            "native_definition_inputs_sha256": receipt["native_definition_inputs_sha256"],
            "sha256": receipt["files"][receipt["cli"]]["sha256"],
            "bytes": receipt["files"][receipt["cli"]]["bytes"],
            "build_context": receipt["build_context"], "owner_visual_acceptance": "pending"}


def binary_format(path: Path, platform: str) -> bool:
    data = path.read_bytes()
    if platform == "linux":
        return len(data) >= 64 and data[:6] == b"\x7fELF\x02\x01" and struct.unpack_from("<H", data, 18)[0] == 62
    if len(data) < 64 or data[:2] != b"MZ":
        return False
    offset = struct.unpack_from("<I", data, 0x3c)[0]
    return offset + 6 <= len(data) and data[offset:offset + 6] == b"PE\0\0\x64\x86"


def build_context() -> dict:
    require(os.environ.get("GITHUB_REPOSITORY") == "techrote/cybersand", "Hosted repository custody absent")
    require(os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH, "Wrong integration branch")
    require(os.environ.get("GITHUB_WORKFLOW_REF") == "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + BRANCH,
            "Wrong integration workflow source")
    require(os.environ.get("GITHUB_EVENT_NAME") in ("push", "workflow_dispatch"), "Unsupported qualification trigger")
    run, attempt = os.environ.get("GITHUB_RUN_ID", ""), os.environ.get("GITHUB_RUN_ATTEMPT", "")
    require(run.isdecimal() and attempt.isdecimal() and int(attempt) > 0, "Missing run/attempt custody")
    return {"repository": "techrote/cybersand", "branch": BRANCH, "workflow": WORKFLOW,
            "run_id": run, "run_attempt": attempt,
            "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" + run}


def expected_files(platform: str) -> set[str]:
    payload = names(platform)
    files = {payload["cli"], payload["fixture"], payload["extension"], *payload["tests"], "toolchain.txt"}
    if platform == "linux":
        files.update("sanitized/" + name for name in payload["tests"])
        files.add("replay_swarm005_known")
    return files


def create(directory: Path, platform: str, root: Path = ROOT, local_preflight: bool = False) -> dict:
    identity = source(root)
    context = {} if local_preflight else build_context()
    if context:
        require(os.environ.get("GITHUB_SHA") == identity["source_commit"], "Build is not the workflow source")
    records = {}
    for name in sorted(expected_files(platform)):
        path = directory / name
        require(path.is_file() and not path.is_symlink(), "Missing source-built payload: " + name)
        if name != "toolchain.txt":
            require(binary_format(path, platform), "Wrong target binary format: " + name)
        records[name] = {"sha256": sha(path), "bytes": path.stat().st_size}
    toolchain = (directory / "toolchain.txt").read_text(encoding="utf-8")
    require("godot_cpp_commit=" + GODOT_CPP in toolchain, "Toolchain record lacks pinned godot-cpp")
    require("native_definition_sha256=" + identity["native_definition_sha256"] in toolchain,
            "Compiler receipt definition differs from actual source")
    if not local_preflight:
        require("compiler_policy=pinned-hosted" in toolchain and "toolchain_drift=false" in toolchain,
                "Hosted qualification cannot admit local compiler drift")
    manifest = {"schema": 1, "programme": PROGRAMME, "qualification_programme": QUALIFICATION_PROGRAMME, "platform": platform,
                "qualification_kind": "local-preflight" if local_preflight else "hosted-source-bound",
                "build_commit": identity["source_commit"], **identity, "build_context": context,
                "files": records, **names(platform), "owner_visual_acceptance": "pending"}
    if platform == "windows":
        native.create(root, directory)
    write_json(directory / NAME, manifest)
    return manifest


def verify(directory: Path, root: Path = ROOT, allow_local: bool = False, same_run: bool = True) -> dict:
    manifest = json.loads((directory / NAME).read_text(encoding="utf-8"))
    require(manifest.get("schema") == 1 and manifest.get("programme") == PROGRAMME
            and manifest.get("qualification_programme") == QUALIFICATION_PROGRAMME, "Wrong runtime schema/programme")
    platform = manifest.get("platform")
    require(platform in EXTENSIONS, "Wrong runtime platform")
    identity = source(root)
    require(all(manifest.get(key) == value for key, value in identity.items()), "Runtime source identity changed")
    require(manifest.get("build_commit") == identity["source_commit"], "Runtime cannot be retagged to another build")
    require(all(manifest.get(key) == value for key, value in names(platform).items()), "Payload names changed")
    require(set(manifest.get("files", {})) == expected_files(platform), "Incomplete/excess runtime binary inventory")
    for name, record in manifest["files"].items():
        path = directory / name
        require(path.is_file() and not path.is_symlink() and sha(path) == record.get("sha256")
                and path.stat().st_size == record.get("bytes"), "Runtime bytes changed: " + name)
        if name != "toolchain.txt":
            require(binary_format(path, platform), "Wrong target binary format: " + name)
    if manifest.get("qualification_kind") == "local-preflight":
        require(allow_local, "Local diagnostics cannot qualify publication")
    else:
        require(manifest.get("qualification_kind") == "hosted-source-bound", "Unknown build custody")
        if same_run:
            require(manifest.get("build_context") == build_context(), "Producer and consumer run/attempt differ")
            require(os.environ.get("GITHUB_SHA") == identity["source_commit"], "Consumer source changed")
    if platform == "windows":
        native.verify(root, directory)
    return manifest


def inventory(directory: Path) -> dict[str, str]:
    result = {}
    for path in sorted(directory.rglob("*")):
        require(not path.is_symlink(), "Evidence symlink is not permitted")
        if path.is_file():
            result[path.relative_to(directory).as_posix()] = sha(path)
    return result


def verify_inventory(directory: Path, records: dict) -> None:
    require(isinstance(records, dict) and bool(records), "Evidence inventory absent")
    for name, digest in records.items():
        pure = PurePosixPath(name)
        require(not pure.is_absolute() and pure.as_posix() == name and ".." not in pure.parts
                and "\\" not in name and re.fullmatch(r"[0-9a-f]{64}", str(digest)) is not None,
                "Unsafe evidence path or digest")
        path = directory / name
        require(path.is_file() and not path.is_symlink() and sha(path) == digest, "Changed evidence: " + name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--platform", choices=EXTENSIONS)
    parser.add_argument("--create", action="store_true")
    parser.add_argument("--local-preflight", action="store_true")
    parser.add_argument("--inspect", action="store_true", help="Verify bytes/source without claiming a same-run execution")
    args = parser.parse_args()
    if args.create:
        require(bool(args.platform), "Creation requires the actual target platform")
        receipt = create(args.directory, args.platform, local_preflight=args.local_preflight)
    else:
        receipt = verify(args.directory, allow_local=args.local_preflight, same_run=not args.inspect)
    print(json.dumps({key: receipt[key] for key in ("source_commit", "source_tree", "native_definition_sha256", "platform", "qualification_kind")}))


if __name__ == "__main__":
    main()
