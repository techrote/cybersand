"""Explicit experimental runtime identity, separate from retained-runtime gates."""

import hashlib
import json
from pathlib import Path
import subprocess


def verify(root: Path, manifest_path: Path) -> dict:
    record = json.loads(manifest_path.read_text(encoding="utf-8"))
    lock_path = root / "third_party/rapier-bvh-build.lock.json"
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    variant = record.get("variant")
    if (record.get("schema_version") != 1 or variant not in ("control", "patched")
            or record.get("source_sha") != source or record.get("build_inputs") != lock
            or record.get("build_lock_sha256") != sha(lock_path)
            or lock["patch_sha256"] != sha(root / lock["patch"])
            or record.get("join_regression_exit") != (124 if variant == "control" else 0)
            or not record.get("rustc", "").startswith("rustc " + lock["rust_toolchain"] + " ")):
        raise RuntimeError("Candidate runtime has invalid or stale build provenance")
    expected_join = lock["base_join_source_sha256"] if variant == "control" else lock["patched_join_source_sha256"]
    if (record.get("join_source_sha256") != expected_join
            or record.get("upstream_cargo_lock_sha256") != lock["upstream_cargo_lock_sha256"]):
        raise RuntimeError("Candidate changed the pinned join or upstream dependency lock")
    platform = record.get("platform")
    filenames = {"windows": "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
                 "linux": "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"}
    if platform not in filenames:
        raise RuntimeError("Unknown candidate platform")
    filename = filenames[platform]
    actual = root / "godot/addons/godot-rapier2d/bin" / filename
    if sha(actual) != record.get("artifacts", {}).get(filename):
        raise RuntimeError("Installed candidate differs from its build artifact")
    return record
