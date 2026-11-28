#!/usr/bin/env python3
"""Admit only the declared font ownership repair and unchanged build gates."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = "tools/pubpres_final_engine"
FROZEN_BUILDER = "tools/ci/build_workbench_godot.py"
FROZEN_BUILDER_SHA256 = "9bd4f14084b1fdeb49056a64a435adeb2f693b9ab8208d04d0c3b4a867db4cbe"
BUILD_NAME = "cybersand_egl_font_snapshot"
FONT_PATCH_SHA256 = "49f06da6478582499adf5f466daec1d20981c5facbd2ef5a0acfa61cc6f788a6"
FONT_SOURCES = {
    "modules/text_server_adv/text_server_adv.cpp": {
        "before_sha256": "f156a5b0100ab39d588a3abc09a013c468b49dbff0ed085b7cb9c2a3e577cfcf",
        "after_sha256": "12e8c7e36b6845a82cc2db5a514b7b97e051c23f6783c560bf2a3fe15caa9a5b"},
    "modules/text_server_fb/text_server_fb.cpp": {
        "before_sha256": "b1a6a009a89007bcbf48f3c70a8a02da037e9aef6d9cf9fa22b9f003c756a6d7",
        "after_sha256": "637d19f1e4cd55a0f3b10fa307646dc2d72d0a637de827d8be86e6d4132c35a1"}}
SOURCE_FIX = ("Original EGL current-window handoff repair plus private Image snapshots at all font-atlas publication boundaries in TextServerAdvanced and TextServerFallback. Material publication, Main/render synchronization, font glyph/mipmap/alpha rules and public APIs are unchanged. All application and graphical acceptance remains pending.")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def expected_builder(original: bytes) -> bytes:
    if sha(original) != FROZEN_BUILDER_SHA256:
        raise ValueError("Original source-bound engine builder differs")
    replacements = {
        b"from pathlib import Path, PurePosixPath":
            b"from pathlib import Path, PurePosixPath\nfrom engine_contract import verify_build_inputs",
        b"def build(args: argparse.Namespace) -> None:\n":
            b"def build(args: argparse.Namespace) -> None:\n    admitted_inputs = verify_build_inputs()\n",
        b'"application_source": git(ROOT, "rev-parse", "HEAD"),':
            b'"application_source": git(ROOT, "rev-parse", "HEAD"),\n                  "input_admission": admitted_inputs,',
        b'ROOT / "third_party/workbench-godot.lock.json"':
            b'ROOT / "tools/pubpres_final_engine/engine.lock.json"'}
    for old, new in replacements.items():
        if original.count(old) != 1:
            raise ValueError("Declared builder edit does not have one source location")
        original = original.replace(old, new)
    return original


def expected_lock(original: dict) -> dict:
    result = json.loads(json.dumps(original))
    result["build_name"] = BUILD_NAME
    result["version"] = "4.7.stable." + BUILD_NAME + ".5b4e0cb0f"
    result["patches"].append({"path": DIRECTORY + "/godot-font-image-snapshot.patch",
                              "sha256": FONT_PATCH_SHA256, "files": FONT_SOURCES})
    result["scope"]["source_fix"] = SOURCE_FIX
    return result


def validate_derivation(root: Path = ROOT) -> dict:
    original = (root / FROZEN_BUILDER).read_bytes()
    builder = (root / DIRECTORY / "build_engine.py").read_bytes()
    if builder != expected_builder(original):
        raise ValueError("New engine builder changes an undeclared original build/ABI/provenance gate")
    lock_path = root / DIRECTORY / "engine.lock.json"
    lock = json.loads(lock_path.read_bytes())
    original_lock = json.loads((root / "third_party/workbench-godot.lock.json").read_bytes())
    if lock != expected_lock(original_lock):
        raise ValueError("New engine lock changes an undeclared dependency, build flag, patch or identity")
    for patch in lock["patches"]:
        if sha((root / patch["path"]).read_bytes()) != patch["sha256"]:
            raise ValueError("Exact engine patch bytes differ: " + patch["path"])
    return {"original_builder_sha256": sha(original), "builder_sha256": sha(builder),
            "lock_sha256": sha(lock_path.read_bytes()), "version": lock["version"],
            "source_commit": lock["source_commit"], "patches": lock["patches"],
            "scope": "Only new input admission, separate lock selection and font ownership patch; every original compiler, dependency, source-delta, API/ABI and payload gate remains exact."}


def verify_build_inputs(root: Path = ROOT) -> dict:
    root = root.resolve()
    result = validate_derivation(root)
    names = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only", "HEAD", "--", DIRECTORY], text=True).splitlines()
    wanted = {path.relative_to(root).as_posix() for path in (root / DIRECTORY).iterdir()
              if path.is_file() and path.suffix in (".py", ".json", ".patch")}
    if not wanted or wanted != {name for name in names if Path(name).suffix in (".py", ".json", ".patch")}:
        raise ValueError("New engine input inventory is uncommitted or differs")
    wanted.update((FROZEN_BUILDER, "third_party/workbench-godot.lock.json", "third_party/patches/godot-egl-current-window.patch"))
    hashes = {}
    for name in sorted(wanted):
        committed = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + name])
        if (root / name).read_bytes() != committed:
            raise ValueError("Engine build input differs from committed bytes: " + name)
        hashes[name] = sha(committed)
    result["application_source"] = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    result["files_sha256"] = hashes
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", required=True)
    parser.parse_args()
    print(json.dumps(verify_build_inputs(), indent=2))
