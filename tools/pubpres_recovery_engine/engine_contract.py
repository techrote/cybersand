#!/usr/bin/env python3
"""Fourth, independently identified atomic-admission engine; frozen gates remain."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = "tools/pubpres_recovery_engine"
BOUNDED_DIRECTORY = "tools/pubpres_final_frame_budget"
FROZEN_BUILDER = "tools/ci/build_workbench_godot.py"
BUILD_NAME = "cybersand_egl_font_atomic"
BOUNDED_CONTRACT_SHA256 = "3d0ba420e6ad277518354579ecbfc72fe2b19bd38351c0daeddcf1d2ce61c843"
BOUNDED_PAYLOAD_SHA256 = "b32ac21febeda8bde72fa1611a96d14903998a6419b81cb82e4b7737c7b96eca"
PATCH_SHA256 = 'f17555f97681bb1c843ade738c738405789f21aa4a487c70a0c778bf83cfb085'
COMBINED_SHA256 = '0f4491e7211f58e2b39d7a37878148e8bc0d94451f356c51796e26c15eda0571'
PATCH_SOURCES = {'main/main.cpp': {'before_sha256': '2ea67893e1bf2e7d629546294d0be3934cecf81ea26eb6e7f68f31cff2ec2491', 'after_sha256': '3bacaf979be7ff2b69c0bc0b0414d8b45ea6646f8f938332b1c30e0ce0eb45b7'}, 'servers/rendering/rendering_server_default.cpp': {'before_sha256': 'ae0e2700ab0ea7c64ba486fc95bb2e47000851dc7f178d2ad6735b79851c3f32', 'after_sha256': '38df3aeed8b72db4251c948734daf39976f04da8d16dd98682bafabef04fa89c'}, 'servers/rendering/rendering_server_default.h': {'before_sha256': '2b5af7ef8b4b3fdf760ba2eb3d7ee7e18977e01257f2a2c7cbd71f9137b873ed', 'after_sha256': '0b9c4f7d12c284b7b743ae1161f1c8c67483ea0ee1afabb444d73d397afa671d'}}
SOURCE_FIX = "Preserves the exact original EGL, font and bounded Main/render component. Adds engine-owned atomic application admission after message flush and before any actual draw serial or signal. A stale application candidate rejects the entire draw, conserves elapsed render time, and cannot grant completion or physical credit. Source/owner/candidate/submission identities join every admitted application frame to actual render-owner CPU evidence. No GPU/scanout, performance, gameplay or physical-device acceptance is implied."
INPUT_SUFFIXES = (".py", ".json", ".patch", ".h", ".cpp")
CRITICAL_NAMES = ("build_engine.py", "engine.lock.json", "engine_contract.py", "payload.py", "patch_stack.py",
                  "godot-atomic-submission.patch", "godot-final-source.patch", "patch-inputs.json",
                  "admission_clock.h", "test_admission_clock.cpp")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def bounded_contract(root=ROOT):
    path = root / BOUNDED_DIRECTORY / "engine_contract.py"
    if sha(path.read_bytes()) != BOUNDED_CONTRACT_SHA256:
        raise ValueError("Frozen bounded engine contract differs")
    return module("atomic_predecessor_contract", path)


LEGACY_INPUTS = bounded_contract().LEGACY_INPUTS | {
    BOUNDED_DIRECTORY + "/" + name for name in bounded_contract().CRITICAL_NAMES} | {
    BOUNDED_DIRECTORY + "/test_payload.py",
    "docs/audits/2026-11-24-pubpres-playability-final/font-engine-combined-source-lines.json"}


def replace_exact(data, changes):
    return bounded_contract().replace_exact(data, changes)


def expected_builder(original, root=ROOT):
    return replace_exact(bounded_contract(root).expected_builder(original, root), {
        b'ROOT / "tools/pubpres_final_frame_budget/engine.lock.json"':
        b'ROOT / "tools/pubpres_recovery_engine/engine.lock.json"'})


def expected_payload(original):
    if sha(original) != BOUNDED_PAYLOAD_SHA256:
        raise ValueError("Frozen bounded payload reader differs")
    return replace_exact(original, {
        b'expected = b"".join((root / patch["path"]).read_bytes() for patch in build["patches"])':
        b'contract.verify_patch_stack(root, normalized_patch)\n    expected = (root / contract.DIRECTORY / "godot-final-source.patch").read_bytes()'})


def expected_lock(original, root=ROOT):
    result = bounded_contract(root).expected_lock(original, root)
    result["build_name"] = BUILD_NAME
    result["version"] = "4.7.stable." + BUILD_NAME + ".5b4e0cb0f"
    result["patches"].append({"path": DIRECTORY + "/godot-atomic-submission.patch",
                              "sha256": PATCH_SHA256, "files": PATCH_SOURCES})
    result["scope"]["source_fix"] = SOURCE_FIX
    return result


def original_normalizer(root):
    path = root / BOUNDED_DIRECTORY / "payload.py"
    if sha(path.read_bytes()) != BOUNDED_PAYLOAD_SHA256:
        raise ValueError("Frozen bounded payload reader differs")
    previous = sys.modules.get("engine_contract")
    try:
        sys.modules["engine_contract"] = bounded_contract(root)
        return module("atomic_frozen_patch_parser", path).normalized_patch
    finally:
        if previous is None: sys.modules.pop("engine_contract", None)
        else: sys.modules["engine_contract"] = previous


def verify_patch_stack(root=ROOT, normalize=None):
    patch = root / DIRECTORY / "godot-atomic-submission.patch"
    combined = root / DIRECTORY / "godot-final-source.patch"
    if sha(patch.read_bytes()) != PATCH_SHA256 or sha(combined.read_bytes()) != COMBINED_SHA256:
        raise ValueError("Exact atomic or final combined patch differs")
    lock = expected_lock(json.loads((root / "third_party/workbench-godot.lock.json").read_bytes()), root)
    stages = [(root / item["path"]).read_bytes() for item in lock["patches"]]
    return module("atomic_patch_stack", root / DIRECTORY / "patch_stack.py").verify(
        stages, combined.read_bytes(), normalize or original_normalizer(root))


def validate_derivation(root=ROOT):
    bounded_contract(root).validate_derivation(root)
    original = (root / FROZEN_BUILDER).read_bytes()
    builder = (root / DIRECTORY / "build_engine.py").read_bytes()
    if builder != expected_builder(original, root):
        raise ValueError("Atomic builder changes an undeclared compiler/ABI/provenance gate")
    reader = (root / DIRECTORY / "payload.py").read_bytes()
    if reader != expected_payload((root / BOUNDED_DIRECTORY / "payload.py").read_bytes()):
        raise ValueError("Atomic payload reader changes an undeclared acceptance gate")
    lock_path = root / DIRECTORY / "engine.lock.json"
    lock = json.loads(lock_path.read_bytes())
    if lock != expected_lock(json.loads((root / "third_party/workbench-godot.lock.json").read_bytes()), root):
        raise ValueError("Atomic engine lock changes an undeclared dependency, flag, patch or identity")
    for patch in lock["patches"]:
        if sha((root / patch["path"]).read_bytes()) != patch["sha256"]:
            raise ValueError("Exact engine patch differs: " + patch["path"])
    manifest = json.loads((root / DIRECTORY / "patch-inputs.json").read_bytes())
    if manifest != {"patch_sha256": PATCH_SHA256, "combined_sha256": COMBINED_SHA256,
                    "files": PATCH_SOURCES, "helper": "admission_clock.h", "test": "test_admission_clock.cpp"}:
        raise ValueError("Atomic patch source manifest differs")
    helper = (root / DIRECTORY / "admission_clock.h").read_bytes()
    if not helper.startswith(b"#pragma once\n\n"):
        raise ValueError("Standalone admission clock helper differs")
    embedded = b"".join(b"+" + line for line in helper[len(b"#pragma once\n\n"):].splitlines(keepends=True))
    if (root / DIRECTORY / "godot-atomic-submission.patch").read_bytes().count(embedded) != 1:
        raise ValueError("Engine admission clock differs from independently compiled helper")
    composition = verify_patch_stack(root)
    return {"original_builder_sha256": sha(original), "builder_sha256": sha(builder),
            "lock_sha256": sha(lock_path.read_bytes()), "version": lock["version"],
            "source_commit": lock["source_commit"], "patches": lock["patches"], "patch_composition": composition,
            "scope": "Every frozen predecessor compiler/dependency/source/API/PE gate retained; atomic application admission is additional and requires separate actual graphical qualification."}


def verify_build_inputs(root=ROOT):
    root = root.resolve()
    result = validate_derivation(root)
    names = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only", "HEAD", "--", DIRECTORY], text=True).splitlines()
    wanted = {p.relative_to(root).as_posix() for p in (root / DIRECTORY).iterdir()
              if p.is_file() and p.suffix in INPUT_SUFFIXES}
    committed_names = {name for name in names if Path(name).parent.as_posix() == DIRECTORY and Path(name).suffix in INPUT_SUFFIXES}
    if not wanted or wanted != committed_names:
        raise ValueError("Atomic engine input inventory is uncommitted or differs")
    hashes = {}
    for name in sorted(wanted | LEGACY_INPUTS):
        committed = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + name])
        if (root / name).read_bytes() != committed:
            raise ValueError("Engine input differs from committed bytes: " + name)
        hashes[name] = sha(committed)
    result["application_source"] = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    result["files_sha256"] = hashes
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", required=True)
    parser.parse_args()
    print(json.dumps(verify_build_inputs(), indent=2))
