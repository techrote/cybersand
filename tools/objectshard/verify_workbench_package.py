#!/usr/bin/env python3
"""Verify the exact-source ordinary Workbench evaluator without running it."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

from verify_package import NATIVE, RAPIER, digest, safe_path

MANIFEST = "objectshard-workbench-manifest.json"
SCHEMA = "objectshard-m4-workbench-package-v1"
RENDERING_DRIVER = "opengl3_angle"
RETAINED_PROVENANCE = "godot/addons/cybersand_native/runtime-provenance.json"
RETAINED_REFERENCE = "godot/addons/cybersand_native/retained-runtime-provenance.reference.json"
CANDIDATE_PROVENANCE = "source-built-candidate-provenance.json"
CANDIDATE_REUSE_PROVENANCE = "qualified-candidate-reuse-provenance.json"
WINDOWS_RECIPROCAL = "godot/tools/gentek_reciprocal.exe"
WINDOWS_RECIPROCAL_BINDING = "godot/tools/swarm004-runtime.windows.json"

ENTRY = {"scene": "godot/main.tscn", "startup_scene": "godot/feature_launcher.tscn", "host": "ordinary-workbench",
         "launcher": "Open Workbench.cmd", "opt_in": True, "rendering_driver": RENDERING_DRIVER,
         "scenario_ids": ["tower", "viaduct", "timber", "mixed", "stress", "perforated", "weathered", "editing_yard", "owner_tower"]}
REQUIRED = {
    NATIVE, RAPIER, "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe",
    "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt", "vcruntime140.dll",
    "Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx",
    CANDIDATE_PROVENANCE, RETAINED_REFERENCE, "godot/project.godot", "godot/main.tscn",
    "godot/feature_launcher.tscn", "godot/scripts/feature_launcher.gd",
    "godot/scripts/main.gd", "godot/scripts/shared_workbench.gd", "godot/scripts/simulation_worker.gd",
    "godot/scripts/object_shard_m4_runtime.gd", "godot/scripts/object_shard_workbench_scenes.gd",
    "godot/data/objectshard_owner_tower2_authored_start.json",
    "godot/scripts/object_shard_live_edit_diagnostics.gd",
    "godot/tests/test_object_shard_live_edit_diagnostics.gd",
    "godot/tests/test_object_shard_live_edit_contract.gd",
    "godot/tests/test_object_shard_m4_creative_scenes.gd",
    "godot/tests/test_object_shard_m4_creative_constructions.gd",
    "godot/tests/test_object_shard_m4_edit_preview_render.gd",
    "godot/tests/test_object_shard_m4_disabled_input.gd",
    "godot/tests/test_object_shard_m4_live_input.gd",
    "godot/tests/test_object_shard_m4_live_tools.gd",
    "godot/tests/test_object_shard_m4_live_stress.gd",
    "godot/tests/test_object_shard_m4_owner_authored.gd",
    "godot/tests/test_object_shard_m4_visible_footprints.gd",
    "godot/tests/support/object_shard_m4_live_input_fixture.gd",
    "godot/scripts/object_shard_physics_bridge.gd", "godot/tests/test_object_shard_m4_workbench_completion.gd",
    "godot/tests/test_object_shard_physics_bridge.gd", "godot/tests/test_object_shard_rest_contacts.gd",
    "godot/tests/test_object_shard_m4_material_only_workbench.gd",
    "godot/tests/test_object_shard_m4_fragment_reabsorption.gd",
    "godot/tests/test_object_shard_m4_lifecycle_adverse.gd",
    "godot/tests/test_object_shard_m4_completed_sample.gd",
    "godot/tests/test_object_shard_m4_equipment_completion.gd",
    "godot/tests/test_object_shard_m4_long_burn.gd",
    "godot/tests/test_object_shard_m4_lifecycle_fuzz.gd",
    "godot/tests/test_object_shard_m4_overlay_identity.gd", "godot/tests/profile_object_shard_m4_render_control.gd",
    "godot/tests/probe_object_shard_workbench_package.gd", "godot/tests/profile_object_shard_m4_workbench.gd",
    "godot/addons/godot-rapier2d/runtime-provenance.windows.json", "READ-ME.md",
    "Open Workbench.cmd", "Verify Workbench.cmd", "tools/objectshard/verify_workbench_package.ps1",
}


def verify_committed_godot_inputs(root: Path, expected: dict[str, str], *, foreign_paths=()) -> dict[str, str]:
    """Bind shipped source bytes, including the deliberately renamed old ledger.

    The production ledger describes another retained DLL. Packaging preserves
    those exact committed bytes only as a reference; the candidate ledger owns
    the executable DLL. This is an exact one-path relocation, never a fallback
    to the checkout or permission to omit a provenance assertion.
    """
    if (root / RETAINED_PROVENANCE).exists():
        raise ValueError("Active retained runtime provenance is forbidden in an evaluator")
    if RETAINED_PROVENANCE not in expected:
        raise ValueError("Committed retained provenance is absent from source custody")
    locations = {}
    for relative, expected_digest in expected.items():
        if relative in foreign_paths:
            if (root / relative).exists():
                raise ValueError("Foreign-platform input in Windows package: " + relative)
            continue
        if not relative.startswith("godot/"):
            continue
        shipped = RETAINED_REFERENCE if relative == RETAINED_PROVENANCE else relative
        if digest(safe_path(root, shipped)) != expected_digest:
            raise ValueError("Packaged Godot source differs: " + relative + " -> " + shipped)
        locations[relative] = shipped
    return locations


def _input_digest(inputs: dict[str, str]) -> str:
    payload = json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def verify_candidate(root: Path, manifest: dict) -> None:
    """Require the original build ledger and, when reused, its explicit equivalence receipt."""
    inventory = manifest["files_sha256"]
    binary = safe_path(root, NATIVE)
    candidate = json.loads(safe_path(root, CANDIDATE_PROVENANCE).read_text(encoding="utf-8"))
    if (type(candidate.get("schema_version")) is not int or candidate["schema_version"] != 1
            or candidate.get("kind") != "source-built-windows-candidate"
            or candidate.get("artifact") != NATIVE
            or type(candidate.get("size")) is not int or candidate["size"] != binary.stat().st_size):
        raise ValueError("Native candidate provenance contract mismatch")
    with binary.open("rb") as stream:
        if stream.read(2) != b"MZ":
            raise ValueError("Native candidate is not a Windows PE runtime")
    inputs = manifest["native"].get("source_inputs", {})
    if not inputs or candidate.get("source_inputs") != inputs or candidate.get("sha256") != inventory[NATIVE]:
        raise ValueError("Native build ledger mismatch")
    same_source = (candidate.get("source_commit") == manifest["source_commit"]
                   and candidate.get("source_tree") == manifest["source_tree"]
                   and candidate.get("build_commit") == manifest["source_commit"])
    if not same_source:
        reuse_path = root / CANDIDATE_REUSE_PROVENANCE
        if CANDIDATE_REUSE_PROVENANCE not in inventory or not reuse_path.is_file():
            raise ValueError("Reused native candidate lacks explicit equivalence provenance")
        reuse = json.loads(reuse_path.read_text(encoding="utf-8"))
        if (reuse.get("schema_version") != 1
                or reuse.get("kind") != "qualified-windows-candidate-input-equivalence"
                or reuse.get("artifact") != NATIVE
                or reuse.get("qualified_source_commit") != candidate.get("source_commit")
                or candidate.get("build_commit") != candidate.get("source_commit")
                or reuse.get("current_source_commit") != manifest["source_commit"]
                or reuse.get("current_source_tree") != manifest["source_tree"]
                or reuse.get("source_inputs_sha256") != _input_digest(inputs)
                or reuse.get("source_input_count") != len(inputs)
                or reuse.get("sha256") != inventory[NATIVE]
                or reuse.get("size") != binary.stat().st_size
                or type(reuse.get("qualified_workflow_run")) is not int
                or reuse["qualified_workflow_run"] <= 0
                or type(reuse.get("qualified_artifact_id")) is not int
                or reuse["qualified_artifact_id"] <= 0):
            raise ValueError("Reused native candidate equivalence provenance mismatch")
    for relative, expected in inputs.items():
        if relative not in inventory or digest(safe_path(root, relative), source=True) != expected:
            raise ValueError("Native source differs from built candidate: " + relative)


def verify_inventory(root: Path, inventory: dict) -> None:
    """Reject unlisted loadable inputs; permit only ordinary generated cache."""
    code_suffixes = {".exe", ".dll", ".so", ".dylib", ".gdextension", ".gd", ".gdc", ".cs",
                     ".tscn", ".tres", ".pck", ".gdshader", ".gdshaderinc", ".ps1", ".cmd", ".bat", ".py"}
    for path in root.rglob("*"):
        if path.is_symlink():
            raise ValueError("External package path: " + path.relative_to(root).as_posix())
        if not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        if relative in inventory or relative == MANIFEST:
            continue
        suffix = path.suffix.lower()
        generated_cache = relative.startswith("godot/.godot/") and suffix not in code_suffixes
        generated_uid = relative.endswith((".gd.uid", ".gdshader.uid")) and relative[:-4] in inventory
        generated_import = relative.startswith("godot/") and relative.endswith(".import") and relative[:-7] in inventory
        if not (generated_cache or generated_uid or generated_import):
            raise ValueError("Unlisted package input: " + relative)


def verify(root: Path) -> dict:
    manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    if manifest.get("schema") != SCHEMA:
        raise ValueError("Unsupported ordinary Workbench evaluator manifest")
    if any(not re.fullmatch(r"[0-9a-f]{40}", manifest.get(k, "")) for k in ("source_commit", "source_tree")):
        raise ValueError("Missing exact source identity")
    if manifest.get("entry") != ENTRY:
        raise ValueError("Incomplete ordinary Workbench entry contract")
    if manifest.get("ordinary_production_defaults_changed") is not False:
        raise ValueError("Evaluator must retain opt-in activation")
    if (root / RETAINED_PROVENANCE).exists():
        raise ValueError("Active retained runtime provenance is forbidden in an evaluator")
    inventory = manifest.get("files_sha256", {})
    if not isinstance(inventory, dict):
        raise ValueError("Invalid Workbench package inventory")
    if {"godot/tools/gentek_reciprocal", "godot/tools/swarm004-runtime.linux.json"}.intersection(inventory):
        raise ValueError("Windows package contains a Linux reciprocal generator or binding")
    reciprocal_inputs = {WINDOWS_RECIPROCAL, WINDOWS_RECIPROCAL_BINDING}
    has_reciprocal = ("native/include/cybersand/workbench_authoring_patch.hpp" in manifest.get("native", {}).get("source_inputs", {})
                      or "godot/scripts/workbench_reciprocal_panel.gd" in inventory
                      or bool(reciprocal_inputs.intersection(inventory)))
    required = REQUIRED
    if has_reciprocal:
        required = REQUIRED | reciprocal_inputs | {"godot/tests/fixtures/object_shard_m4_authored_reopen.gd"}
    if not required.issubset(inventory):
        raise ValueError("Incomplete Workbench package inventory: " + str(sorted(required - inventory.keys())))
    if has_reciprocal:
        binding = json.loads(safe_path(root, WINDOWS_RECIPROCAL_BINDING).read_bytes())
        if (binding.get("artifact") != WINDOWS_RECIPROCAL or binding.get("platform") != "windows"
                or binding.get("bytes") != safe_path(root, WINDOWS_RECIPROCAL).stat().st_size
                or binding.get("sha256") != inventory[WINDOWS_RECIPROCAL]):
            raise ValueError("Windows reciprocal generator differs from its packaged source binding")
    verify_inventory(root, inventory)
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
    verify_candidate(root, manifest)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    result = verify(parser.parse_args().package)
    print(json.dumps({"verified_files": len(result["files_sha256"]), "source_commit": result["source_commit"],
                      "physical_owner_acceptance": "not established by file verification"}))
