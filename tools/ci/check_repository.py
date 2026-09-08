#!/usr/bin/env python3
"""Check current docs, dependency pins and published runtime identity."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from check_docs import check as check_docs

ROOT = Path(__file__).resolve().parents[2]
GODOT = "4.7.stable.official.5b4e0cb0f"
GODOT_CPP = "101ae38034304346a46ea9ea84ae156d3e860496"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def verify_runtime(root, manifest):
    errors = []
    platform = manifest.get("validated_platform", "runtime")
    for relative, expected in manifest["source_inputs"].items():
        path = root / relative
        if not path.is_file() or digest(path.read_bytes().replace(b"\r\n", b"\n")) != expected:
            errors.append(platform + " requires rebuild for source input: " + relative)
    data = (root / manifest["artifact"]).read_bytes()
    if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
        expected = f"oid sha256:{manifest['sha256']}\nsize {manifest['size']}\n".encode()
        if expected not in data:
            errors.append(platform + " LFS pointer differs from published runtime provenance")
    elif digest(data) != manifest["sha256"] or len(data) != manifest["size"]:
        errors.append(platform + " bytes differ from published provenance")
    return errors

def check(root, require_materialized=False):
    docs = check_docs(root)
    errors = list(docs["errors"])
    materialized, pointers = [], []
    try:
        def load(name):
            return json.loads((root / name).read_text(encoding="utf-8"))
        native = load("third_party/native-toolchain.lock.json")
        godot = load("third_party/godot-runtime.lock.json")
        rapier = load("godot/third_party/rapier2d.lock.json")
        if godot["godot_version"] != GODOT:
            errors.append("current Godot dependency differs from the approved pin")
        if rapier["rapier_tag"] != "v0.35.2":
            errors.append("current Rapier dependency differs from the approved pin")
        if not any(a.get("name") == "godot-cpp" and a.get("version") == GODOT_CPP for a in native["artifacts"]):
            errors.append("current godot-cpp dependency differs from the approved pin")
        for manifest_name in ("runtime-provenance.json", "runtime-provenance.linux.json"):
            errors.extend(verify_runtime(root, load("godot/addons/cybersand_native/" + manifest_name)))
        tracked = subprocess.check_output(["git", "-C", str(root), "ls-files", "godot/addons"], text=True).splitlines()
        for relative in tracked:
            if not (relative.endswith((".dll", ".so", ".dylib", ".wasm")) or ".framework/libgodot_rapier." in relative):
                continue
            committed = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + relative])
            match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", committed)
            if not match:
                errors.append("required runtime is not a committed LFS pointer: " + relative)
                continue
            data = (root / relative).read_bytes()
            if data == committed:
                pointers.append(relative)
                if require_materialized:
                    errors.append("runtime object is not materialized: " + relative)
            elif digest(data) == match[1].decode() and len(data) == int(match[2]):
                materialized.append(relative)
            else:
                errors.append("runtime differs from committed LFS identity: " + relative)
        for relative in ("THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md", "godot/.godot/.gdignore",
                         "godot/.godot/extension_list.cfg", "godot/.godot/global_script_class_cache.cfg",
                         "godot/addons/godot-rapier2d/LICENSE", "godot/addons/godot-rapier2d/THIRDPARTY.txt",
                         "godot/addons/cybersand_native/LICENSE-godot-cpp.md"):
            if not (root / relative).is_file():
                errors.append("required notice/bootstrap file missing: " + relative)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        errors.append("current provenance check failed: " + str(exc))
    return {"status": "failed" if errors else "passed", "scope": "current source/documentation and artifact identity",
            "documentation": docs, "materialized_runtime_files": materialized, "unmaterialized_runtime_files": pointers,
            "errors": errors, "limitations": ["Identity is not execution evidence; read the dated runtime acceptance report",
            "Retained vendor binaries and platform execution have separate dated provenance",
            "Historical M11 integrity is checked separately by check_m11_consistency.py"]}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--require-materialized", action="store_true")
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    result = check(args.root.resolve(), args.require_materialized)
    output = json.dumps(result, indent=2) + "\n"
    if args.json:
        args.json.write_text(output, encoding="utf-8")
    print(output, end="")
    return int(result["status"] != "passed")

if __name__ == "__main__":
    raise SystemExit(main())
