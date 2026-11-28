#!/usr/bin/env python3
"""Capture only stable identities before or after one interleaved experiment."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    native = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
    rapier = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
    paths = [
        "godot/tests/profile_object_shard_m4_throughput.gd",
        "godot/tests/support/object_shard_m4_workbench_fixture.gd",
        "godot/scripts/workbench_setup.gd",
        "godot/scripts/main.gd",
        "godot/scripts/shared_workbench.gd",
        "godot/scripts/simulation_worker.gd",
        "godot/scripts/object_shard_m4_runtime.gd",
        "godot/scripts/object_shard_m4_workbench_port.gd",
        "godot/scripts/object_shard_workbench_overlay.gd",
        "godot/scripts/object_shard_physics_bridge.gd",
        "godot/scripts/object_shard_workbench_scenes.gd",
        "tools/objectshard/compare_throughput.py",
        native, rapier,
    ]
    result = {"godot_sha256": sha(args.godot), "projects": {}}
    for label in ("baseline", "candidate"):
        root = getattr(args, label)
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
        changes = subprocess.check_output(["git", "diff", "HEAD", "--name-only"], cwd=root, text=True).splitlines()
        assert set(changes) <= {native, rapier, "godot/.godot/global_script_class_cache.cfg"}, changes
        files = {path: sha(root / path) for path in paths}
        for path in paths:
            if path in (native, rapier):
                continue
            expected = hashlib.sha256(subprocess.check_output(["git", "show", head + ":" + path], cwd=root)).hexdigest()
            assert files[path] == expected, (label, path)
        result["projects"][label] = {
            "head": head,
            "tree": subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=root, text=True).strip(),
            "files": files,
            "native_bytes": (root / native).stat().st_size,
        }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"output": str(args.output), "godot_sha256": result["godot_sha256"],
                      "projects": {key: {"head": value["head"], "native_sha256": value["files"][native]} for key, value in result["projects"].items()}}, indent=2))


if __name__ == "__main__":
    main()
