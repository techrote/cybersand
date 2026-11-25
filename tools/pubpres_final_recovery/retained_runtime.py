#!/usr/bin/env python3
"""Explicit reuse of a retained native build only across byte-identical build inputs.

Original native/dependency receipts and binary bytes are never rewritten. The
frozen validator still verifies the original build source; this additive join
separately binds a new committed application to the exact same complete inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "tools/pubpres_final"), str(ROOT / "tools/pubpres003"), str(ROOT / "tools/pubpres_playability_build"),
               str(ROOT / "tools/pubpres_playability")]
from run_focus import validate_runtime as exact_runtime
from run_campaign import source_identity
from runtime_replay import verify_recorded_runtime

BINDING = "PUBPRES-NATIVE-INPUT-REUSE.json"
SCHEMA = "pubpres-native-identical-input-reuse-v1"
SCOPES = ("native/include", "native/src", "godot/native_extension")
SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
EXTRA_INPUTS = ("third_party/native-toolchain.lock.json", "tools/requirements-build.txt",
                "tools/build_pinned_godot_cpp.sh", "tools/toolchains/g++")


def need(ok, message):
    if not ok:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(raw):
    return raw.replace(b"\r\n", b"\n")


def blob(root, ref, name):
    return subprocess.check_output(["git", "-C", str(root), "show", ref + ":" + name])


def tree(root, ref):
    return subprocess.check_output(["git", "-C", str(root), "rev-parse", ref + "^{tree}"], text=True).strip()


def build_inputs(root: Path, application: dict, runtime: dict) -> dict:
    """Refuse new/deleted native input paths and every byte or build-policy drift."""
    app = application["source_commit"]
    old = runtime["source_commit"]
    need(tree(root, app) == application["source_tree"] and tree(root, old) == runtime["source_tree"],
         "Application or retained native source tree differs")
    recorded = runtime["source_inputs_sha256"]
    names = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only", app,
                                     "--", *SCOPES], text=True).splitlines()
    need({name for name in names if Path(name).suffix in SUFFIXES} == set(recorded),
         "New application has a different native source closure")
    checks = dict(recorded)
    checks[runtime["build_script"]] = runtime["build_script_sha256"]
    checks.update({"tools/pubpres_playability_build/" + name: wanted
                   for name, wanted in runtime["driver_inputs_sha256"].items()})
    for name in EXTRA_INPUTS:
        checks[name] = digest(canonical(blob(root, old, name)))
    for name, expected in checks.items():
        need(digest(canonical(blob(root, old, name))) == expected,
             "Retained build receipt does not match original source: " + name)
        need(digest(canonical(blob(root, app, name))) == expected
             and digest(canonical((root / name).read_bytes())) == expected,
             "Changed native/build input requires an independent rebuild: " + name)
    return dict(sorted(checks.items()))


def make_binding(root: Path, application: dict, folder: Path, *, target_platform: str) -> dict:
    path = folder / "PUBPRES-RUNTIME.json"
    runtime = json.loads(path.read_bytes())
    need(target_platform in ("linux", "windows") and runtime["platform"] == target_platform,
         "Retained native platform differs")
    need(runtime.get("toolchain_drift_allowed") is False and runtime.get("production_runtime_promotion") is False,
         "Retained input reuse cannot grant a development build qualification or promotion")
    old = {key: runtime[key] for key in ("source_commit", "source_tree")}
    inputs = build_inputs(root, application, runtime)
    # This is the previously reviewed explicit-target offline custody reader.
    # Actual execution subsequently calls the unchanged host-platform gate.
    native = verify_recorded_runtime(root, old, folder, target_platform=target_platform)
    return {"schema": SCHEMA, "application": {key: application[key] for key in ("source_commit", "source_tree")},
            "original_build": old, "platform": target_platform, "original_manifest_sha256": digest(path.read_bytes()),
            "binary_sha256": native["binary_sha256"], "build_inputs_sha256": inputs,
            "dependency_builder_commit": native["dependency_builder_commit"],
            "scope": "New application, unchanged complete native/build inputs and retained original binary/receipts. This is input equivalence, not a build at the new application commit and not inherited gameplay qualification.",
            "production_runtime_promotion": False}


def validate_runtime(root, source, folder, allow_drift):
    root, folder = Path(root).resolve(), Path(folder).resolve()
    path = folder / BINDING
    if not path.exists():
        return exact_runtime(root, source, folder, allow_drift)
    need(allow_drift is False, "Retained reuse and development toolchain drift cannot combine")
    recorded = json.loads(path.read_bytes())
    platform = "windows" if os.name == "nt" else "linux"
    binding = make_binding(root, source, folder, target_platform=platform)
    need(recorded == binding, "Retained native input binding belongs to another application or changed bytes")
    runtime = json.loads((folder / "PUBPRES-RUNTIME.json").read_bytes())
    # The untouched frozen validator still checks actual executing-platform,
    # closure, binary, original build log and godot-cpp dependency custody.
    original = {key: runtime[key] for key in ("source_commit", "source_tree")}
    result = exact_runtime(root, original, folder, False)
    return {**result, "application_commit": source["source_commit"],
            "native_input_reuse": {"path": str(path), "sha256": digest(path.read_bytes()), "record": binding}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    args = parser.parse_args()
    root, original, output = args.source.resolve(), args.runtime.resolve(), args.output.resolve()
    need(not output.exists(), "Preserve original runtime and existing reuse bindings")
    application = source_identity(root)
    binding = make_binding(root, application, original, target_platform=args.platform)
    need(not (original / BINDING).exists(), "Rebind from the original retained artifact, not a prior application alias")
    shutil.copytree(original, output)
    (output / BINDING).write_text(json.dumps(binding, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"application": binding["application"], "original_build": binding["original_build"],
                      "platform": args.platform, "binary_sha256": binding["binary_sha256"],
                      "input_count": len(binding["build_inputs_sha256"]), "output": str(output)}))


if __name__ == "__main__":
    main()
