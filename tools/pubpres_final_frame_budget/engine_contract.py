#!/usr/bin/env python3
"""Exact additive bounded-render experiment; retain every preceding build gate."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = "tools/pubpres_final_frame_budget"
FONT_DIRECTORY = "tools/pubpres_final_engine"
FROZEN_BUILDER = "tools/ci/build_workbench_godot.py"
BUILD_NAME = "cybersand_egl_font_bounded"
FONT_CONTRACT_SHA256 = "13c4c67c440b8a6e07672ad3d9d0bf59d18491b610f82da97cdc9f926e575175"
FONT_PAYLOAD_SHA256 = "45931b78d5c0600b693a72b3112a323b50cadd8e39a266917c879e62ee6abe73"
PATCH_SHA256 = '23b6b04ea228a8ec7da73eae3802840f9d21e472459ba152fa41e634c7c74087'
PATCH_SOURCES = {'main/main.cpp': {'before_sha256': '2fa6ef2736aa28e2feced47ca872bce1a95e3e6c56bb6002a96660a008df8992', 'after_sha256': '2ea67893e1bf2e7d629546294d0be3934cecf81ea26eb6e7f68f31cff2ec2491'}, 'servers/rendering/rendering_server_default.cpp': {'before_sha256': '60cdf149a4cb8c8c7b49d562edcce2273e028e4a0a6cb067c7c478054a3dc3c9', 'after_sha256': 'ae0e2700ab0ea7c64ba486fc95bb2e47000851dc7f178d2ad6735b79851c3f32'}, 'servers/rendering/rendering_server_default.h': {'before_sha256': 'eff3cdd80dcfdb7643d5651f3a96fac12011414e4d5f8ecb3645638dfb43481b', 'after_sha256': '2b5af7ef8b4b3fdf760ba2eb3d7ee7e18977e01257f2a2c7cbd71f9137b873ed'}}
SOURCE_FIX = 'Preserves the original EGL handoff and font Image ownership repairs. Adds a default-off, GL Separate-owner experiment allowing at most4 deferred Main sync/draw opportunities per actual outstanding render draw, followed by the original barrier. Requires an actual current-process presentation-submission transaction connection. Preserves all physical work, real draw signals and elapsed shader/particle time. The bound permits at most5 subsequent producer turns before the barrier; it is not an absolute byte cap. CPU draw completion is not GPU completion or physical display presentation. All application, graphical and physical hardware acceptance remains pending.'
INPUT_SUFFIXES = (".py", ".json", ".patch", ".h", ".cpp")
LEGACY_INPUTS = {FROZEN_BUILDER, "third_party/workbench-godot.lock.json",
    "third_party/patches/godot-egl-current-window.patch",
    FONT_DIRECTORY + "/engine_contract.py", FONT_DIRECTORY + "/build_engine.py",
    FONT_DIRECTORY + "/engine.lock.json", FONT_DIRECTORY + "/godot-font-image-snapshot.patch",
    FONT_DIRECTORY + "/payload.py"}
CRITICAL_NAMES = ("build_engine.py", "engine.lock.json", "engine_contract.py", "payload.py",
                  "godot-bounded-main-turns.patch", "cybersand_frame_budget.h", "test_frame_budget.cpp")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def font_contract(root: Path):
    path = root / FONT_DIRECTORY / "engine_contract.py"
    if sha(path.read_bytes()) != FONT_CONTRACT_SHA256:
        raise ValueError("Frozen font engine contract differs")
    spec = importlib.util.spec_from_file_location("bounded_font_contract", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def replace_exact(data: bytes, changes: dict[bytes, bytes]) -> bytes:
    for old, new in changes.items():
        if data.count(old) != 1:
            raise ValueError("Derived reader/builder edit no longer has exactly one source location")
        data = data.replace(old, new)
    return data


def expected_builder(original: bytes, root: Path = ROOT) -> bytes:
    data = font_contract(root).expected_builder(original)
    return replace_exact(data, {b'ROOT / "tools/pubpres_final_engine/engine.lock.json"':
                               b'ROOT / "tools/pubpres_final_frame_budget/engine.lock.json"'})


def expected_payload(original: bytes) -> bytes:
    if sha(original) != FONT_PAYLOAD_SHA256:
        raise ValueError("Frozen font payload reader differs")
    return replace_exact(original, {
        b'and Path(name).suffix in (".py", ".json", ".patch")': b'and Path(name).suffix in contract.INPUT_SUFFIXES',
        b'("build_engine.py", "engine.lock.json", "engine_contract.py", "godot-font-image-snapshot.patch")': b'contract.CRITICAL_NAMES',
        b'legacy = {contract.FROZEN_BUILDER, "third_party/workbench-godot.lock.json",\n              "third_party/patches/godot-egl-current-window.patch"}': b'legacy = contract.LEGACY_INPUTS',
        b'return json.dumps(result, ensure_ascii=False, separators=(",", ":"))':
        b'# Distinct files may occur in patch-stack or git-diff alphabetical order.\n    # Every file path/mode and every ordered edit/coordinate remains exact.\n    return json.dumps(sorted(result, key=lambda row: row["path"]), ensure_ascii=False, separators=(",", ":"))'})


def expected_lock(original: dict, root: Path = ROOT) -> dict:
    result = font_contract(root).expected_lock(original)
    result["build_name"] = BUILD_NAME
    result["version"] = "4.7.stable." + BUILD_NAME + ".5b4e0cb0f"
    result["patches"].append({"path": DIRECTORY + "/godot-bounded-main-turns.patch",
                              "sha256": PATCH_SHA256, "files": PATCH_SOURCES})
    result["scope"]["source_fix"] = SOURCE_FIX
    return result


def validate_derivation(root: Path = ROOT) -> dict:
    font_contract(root).validate_derivation(root)
    original = (root / FROZEN_BUILDER).read_bytes()
    builder = (root / DIRECTORY / "build_engine.py").read_bytes()
    if builder != expected_builder(original, root):
        raise ValueError("Bounded engine builder changes an undeclared compiler/ABI/provenance gate")
    payload = (root / DIRECTORY / "payload.py").read_bytes()
    if payload != expected_payload((root / FONT_DIRECTORY / "payload.py").read_bytes()):
        raise ValueError("Bounded engine payload reader changes an undeclared acceptance gate")
    lock_path = root / DIRECTORY / "engine.lock.json"
    lock = json.loads(lock_path.read_bytes())
    if lock != expected_lock(json.loads((root / "third_party/workbench-godot.lock.json").read_bytes()), root):
        raise ValueError("Bounded engine lock changes an undeclared dependency, flag, patch or identity")
    for patch in lock["patches"]:
        if sha((root / patch["path"]).read_bytes()) != patch["sha256"]:
            raise ValueError("Exact engine patch differs: " + patch["path"])
    helper = (root / DIRECTORY / "cybersand_frame_budget.h").read_bytes()
    if not helper.startswith(b"#pragma once\n\n"):
        raise ValueError("Standalone frame budget helper header differs")
    added_helper = b"".join(b"+" + line for line in helper[len(b"#pragma once\n\n"):].splitlines(keepends=True))
    if (root / DIRECTORY / "godot-bounded-main-turns.patch").read_bytes().count(added_helper) != 1:
        raise ValueError("Engine embedded frame budget does not exactly match independently compiled helper")
    return {"original_builder_sha256": sha(original), "builder_sha256": sha(builder),
            "lock_sha256": sha(lock_path.read_bytes()), "version": lock["version"],
            "source_commit": lock["source_commit"], "patches": lock["patches"],
            "scope": "Exact predecessor build/compiler/dependency/source/ABI/PE gates retained; additive default-off bounded Main/draw scheduling only. No gameplay acceptance is implied."}


def verify_build_inputs(root: Path = ROOT) -> dict:
    root = root.resolve()
    result = validate_derivation(root)
    names = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only", "HEAD", "--", DIRECTORY], text=True).splitlines()
    wanted = {p.relative_to(root).as_posix() for p in (root / DIRECTORY).iterdir()
              if p.is_file() and p.suffix in INPUT_SUFFIXES}
    committed_names = {name for name in names if Path(name).parent.as_posix() == DIRECTORY and Path(name).suffix in INPUT_SUFFIXES}
    if not wanted or wanted != committed_names:
        raise ValueError("Bounded engine input inventory is uncommitted or differs")
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
