#!/usr/bin/env python3
"""Verify an ObjectShard evaluation directory without executing its binaries."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

MANIFEST = "objectshard-lab-manifest.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
REQUIRED = {NATIVE, RAPIER, "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe",
            "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt", "vcruntime140.dll",
            "Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx",
            "source-built-candidate-provenance.json", "godot/project.godot", "godot/object_shard_lab.tscn",
            "godot/scripts/object_shard_lab.gd", "godot/scripts/object_shard_lab_session.gd",
            "godot/scripts/object_shard_lab_view.gd", "godot/scripts/object_shard_physics_bridge.gd",
            "godot/addons/godot-rapier2d/runtime-provenance.windows.json", "READ-ME.md",
            "Open ObjectShard Lab.cmd", "Verify ObjectShard Lab.cmd", "tools/objectshard/verify_package.ps1",
            "godot/tests/probe_object_shard_package_boot.gd"}


PREFLIGHT = {"schema": "objectshard-m3-preflight-v1", "host": "standalone-exclusive-worker-rehearsal",
             "scene": "godot/object_shard_worker_rehearsal.tscn",
             "launcher": "Open ObjectShard M3 Preflight.cmd", "production_workbench": False,
             "replay_driver": "godot/tests/replay_object_shard_worker_trace.gd"}
PREFLIGHT_REQUIRED = {PREFLIGHT["scene"], PREFLIGHT["launcher"], PREFLIGHT["replay_driver"],
                      "godot/scripts/feature_launcher.gd", "godot/scripts/object_shard_native_worker.gd", "godot/scripts/object_shard_worker_host.gd",
                      "godot/scripts/object_shard_worker_rehearsal.gd", "godot/tests/probe_object_shard_worker_package_boot.gd",
                      "docs/operations/objectshard-m3-preflight-playtest.md"}


def digest(path: Path, *, source: bool = False) -> str:
    data = path.read_bytes()
    return hashlib.sha256(data.replace(b"\r\n", b"\n") if source else data).hexdigest()


def safe_path(root: Path, relative: str) -> Path:
    path = PurePosixPath(relative)
    if not relative or "\\" in relative or ":" in relative or path.is_absolute() or ".." in path.parts:
        raise ValueError("Unsafe package path: " + relative)
    result = root / path
    if result.is_symlink() or not result.is_file() or not result.resolve().is_relative_to(root.resolve()):
        raise ValueError("Missing or external package file: " + relative)
    return result


def verify(root: Path) -> dict:
    manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    if manifest.get("schema") != "objectshard-lab-package-v1":
        raise ValueError("Unsupported ObjectShard package schema")
    if any(not re.fullmatch(r"[0-9a-f]{40}", manifest.get(key, "")) for key in ("source_commit", "source_tree")):
        raise ValueError("Missing exact source identity")
    inventory = manifest.get("files_sha256", {})
    if not isinstance(inventory, dict) or not REQUIRED.issubset(inventory):
        raise ValueError("Incomplete package inventory")
    if "preflight" in manifest or PREFLIGHT["scene"] in inventory:
        if manifest.get("preflight") != PREFLIGHT or not PREFLIGHT_REQUIRED.issubset(inventory):
            raise ValueError("Incomplete or misleading M3 preflight identity")
    for relative, expected in inventory.items():
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise ValueError("Malformed digest: " + relative)
        if digest(safe_path(root, relative)) != expected:
            raise ValueError("Package file changed: " + relative)
    for kind, relative in (("native", NATIVE), ("rapier", RAPIER)):
        identity = manifest.get(kind, {})
        if identity.get("path") != relative or identity.get("sha256") != inventory[relative]:
            raise ValueError(kind + " runtime identity mismatch")
    if manifest.get("godot", {}).get("version") != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Unexpected Windows engine version")
    for field, relative in (("runtime_sha256", "Godot_v4.7-stable_win64.exe"),
                            ("console_sha256", "Godot_v4.7-stable_win64_console.exe")):
        if manifest["godot"].get(field) != inventory[relative]:
            raise ValueError("Windows engine file identity mismatch")
    if manifest.get("vc_runtime_sha256") != inventory["vcruntime140.dll"]:
        raise ValueError("VC runtime identity mismatch")
    candidate = json.loads((root / "source-built-candidate-provenance.json").read_text(encoding="utf-8"))
    for field in ("source_commit", "source_tree"):
        if candidate.get(field) != manifest[field]:
            raise ValueError("Candidate source identity mismatch")
    inputs = manifest["native"].get("source_inputs", {})
    if not inputs or candidate.get("source_inputs") != inputs or candidate.get("sha256") != inventory[NATIVE]:
        raise ValueError("Native build ledger mismatch")
    for relative, expected in inputs.items():
        if relative not in inventory or digest(safe_path(root, relative), source=True) != expected:
            raise ValueError("Native source differs from built candidate: " + relative)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    args = parser.parse_args()
    result = verify(args.package)
    print(json.dumps({"verified_files": len(result["files_sha256"]), "source_commit": result["source_commit"],
                      "physical_owner_acceptance": "not established by file verification"}))
