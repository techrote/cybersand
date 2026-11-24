#!/usr/bin/env python3
"""Verify the exact-source ordinary Workbench evaluator without running it."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from verify_package import NATIVE, RAPIER, digest, safe_path

MANIFEST = "objectshard-workbench-manifest.json"
SCHEMA = "objectshard-m4-workbench-package-v1"
REQUIRED = {
    NATIVE, RAPIER, "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe",
    "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt", "vcruntime140.dll",
    "Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx",
    "source-built-candidate-provenance.json", "godot/project.godot", "godot/main.tscn",
    "godot/scripts/main.gd", "godot/scripts/shared_workbench.gd", "godot/scripts/simulation_worker.gd",
    "godot/scripts/object_shard_m4_runtime.gd", "godot/scripts/object_shard_workbench_scenes.gd",
    "godot/scripts/object_shard_physics_bridge.gd", "godot/tests/test_object_shard_m4_workbench_completion.gd",
    "godot/tests/test_object_shard_m4_material_only_workbench.gd",
    "godot/tests/test_object_shard_m4_fragment_reabsorption.gd",
    "godot/tests/probe_object_shard_workbench_package.gd", "godot/tests/profile_object_shard_m4_workbench.gd",
    "godot/addons/godot-rapier2d/runtime-provenance.windows.json", "READ-ME.md",
    "Open Workbench.cmd", "Verify Workbench.cmd", "tools/objectshard/verify_workbench_package.ps1",
}


def verify(root: Path) -> dict:
    manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    if manifest.get("schema") != SCHEMA:
        raise ValueError("Unsupported ordinary Workbench evaluator manifest")
    if any(not re.fullmatch(r"[0-9a-f]{40}", manifest.get(k, "")) for k in ("source_commit", "source_tree")):
        raise ValueError("Missing exact source identity")
    if manifest.get("entry") != {"scene": "godot/main.tscn", "host": "ordinary-workbench",
                                 "launcher": "Open Workbench.cmd", "opt_in": True,
                                 "scenario_ids": ["tower", "viaduct", "timber", "mixed", "stress"]}:
        raise ValueError("Incomplete ordinary Workbench entry contract")
    if manifest.get("ordinary_production_defaults_changed") is not False:
        raise ValueError("Evaluator must retain opt-in activation")
    inventory = manifest.get("files_sha256", {})
    if not isinstance(inventory, dict) or not REQUIRED.issubset(inventory):
        raise ValueError("Incomplete Workbench package inventory: " + str(sorted(REQUIRED - inventory.keys())))
    for relative, expected in inventory.items():
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise ValueError("Malformed digest: " + relative)
        if digest(safe_path(root, relative)) != expected:
            raise ValueError("Package file changed: " + relative)
    for kind, relative in (("native", NATIVE), ("rapier", RAPIER)):
        identity = manifest.get(kind, {})
        if identity.get("path") != relative or identity.get("sha256") != inventory[relative]:
            raise ValueError(kind + " runtime identity mismatch")
    if manifest.get("rapier", {}).get("sha256") != "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7":
        raise ValueError("Rapier differs from the admitted binary")
    if manifest.get("godot", {}).get("version") != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Unexpected pinned engine version")
    for field, relative in (("runtime_sha256", "Godot_v4.7-stable_win64.exe"),
                            ("console_sha256", "Godot_v4.7-stable_win64_console.exe")):
        if manifest["godot"].get(field) != inventory[relative]:
            raise ValueError("Windows engine identity mismatch")
    if manifest.get("vc_runtime_sha256") != inventory["vcruntime140.dll"]:
        raise ValueError("VC runtime identity mismatch")
    candidate = json.loads(safe_path(root, "source-built-candidate-provenance.json").read_text(encoding="utf-8"))
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
    result = verify(parser.parse_args().package)
    print(json.dumps({"verified_files": len(result["files_sha256"]), "source_commit": result["source_commit"],
                      "physical_owner_acceptance": "not established by file verification"}))
