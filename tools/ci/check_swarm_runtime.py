#!/usr/bin/env python3
"""Cheap source/CLI binding gate; never execute a research corpus in ordinary CI."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
PROGRAMME = "GENTEK-SWARM-004-005-MAINLINE"
ARTIFACTS = {"linux": "godot/tools/gentek_reciprocal", "windows": "godot/tools/gentek_reciprocal.exe"}
EXTRA = ("native/src/generation_spatial.cpp", "native/include/cybersand/material.hpp",
         "native/include/cybersand/generation_spatial.hpp", "native/include/cybersand/generation_numeric.hpp")
POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def definition_inputs(root: Path) -> tuple[str, dict[str, str]]:
    directory = root / "native/experiments/gentek_swarm"
    local = sorted(directory.glob("*.cpp")) + sorted(directory.glob("*.hpp"))
    if not local or any(not (root / name).is_file() for name in EXTRA):
        raise ValueError("incomplete native definition source")
    # Match Makefile.reciprocal's path spelling/order, with repository LF text
    # attributes. Keep the per-file custody inventory repository-relative.
    files = [(path.name, path) for path in local] + [("../../../" + name, root / name) for name in EXTRA]
    content = [(name, path, path.read_bytes().replace(b"\r\n", b"\n")) for name, path in files]
    definition = sha(b"".join(name.encode() + b"\0" + data for name, _path, data in content))
    return definition, {path.relative_to(root).as_posix(): sha(data) for _name, path, data in content}


def binary_format(data: bytes, platform: str) -> bool:
    if platform == "linux":
        return len(data) >= 64 and data[:6] == b"\x7fELF\x02\x01" and struct.unpack_from("<H", data, 18)[0] == 62
    if len(data) < 64 or data[:2] != b"MZ":
        return False
    offset = struct.unpack_from("<I", data, 0x3c)[0]
    return offset + 6 <= len(data) and data[offset:offset + 6] == b"PE\0\0\x64\x86"


def check(root: Path, require_materialized: bool = False) -> dict:
    errors, platforms = [], {}
    try:
        definition, inputs = definition_inputs(root)
        text = (root / "godot/scripts/workbench_reciprocal_protocol.gd").read_text(encoding="utf-8")
        pin = re.findall(r'^const NATIVE_DEFINITION := "([0-9a-f]{64})"$', text, re.MULTILINE)
        if pin != [definition]:
            errors.append("Workbench native definition admission pin differs from current source")
        for platform, artifact in ARTIFACTS.items():
            manifest_path = root / f"godot/tools/swarm004-runtime.{platform}.json"
            try:
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                if not isinstance(manifest, dict):
                    raise ValueError("binding must be an object")
                if (type(manifest.get("schema")) is not int or manifest["schema"] != 1 or
                        manifest.get("programme") != PROGRAMME or manifest.get("platform") != platform or
                        manifest.get("artifact") != artifact or
                        not re.fullmatch(r"[0-9a-f]{40}", str(manifest.get("source", ""))) or
                        not re.fullmatch(r"[0-9a-f]{64}", str(manifest.get("sha256", ""))) or
                        type(manifest.get("bytes")) is not int or manifest["bytes"] <= 0):
                    raise ValueError("malformed or foreign executable/source binding")
                if manifest.get("native_definition_sha256") != definition or \
                        manifest.get("native_definition_inputs_sha256") != inputs:
                    raise ValueError("requires rebuild for changed native definition inputs")
                path = root / artifact
                data = path.read_bytes()
                pointer = POINTER.fullmatch(data)
                if pointer:
                    if pointer[1].decode() != manifest["sha256"] or int(pointer[2]) != manifest["bytes"]:
                        raise ValueError("LFS pointer differs from executable binding")
                    if require_materialized:
                        raise ValueError("executable LFS object is not materialized")
                elif sha(data) != manifest["sha256"] or len(data) != manifest["bytes"] or not binary_format(data, platform):
                    raise ValueError("executable bytes/target format differ from source binding")
                elif platform == "linux" and os.name != "nt" and not path.stat().st_mode & 0o111:
                    raise ValueError("Linux executable has no execute permission")
                platforms[platform] = {"artifact": artifact, "source": manifest["source"],
                    "sha256": manifest["sha256"], "materialized": pointer is None}
            except (OSError, ValueError, KeyError) as error:
                errors.append(f"SWARM {platform}: {error}")
    except (OSError, ValueError) as error:
        errors.append("SWARM definition custody: " + str(error))
    return {"status": "failed" if errors else "passed", "platforms": platforms, "errors": errors,
            "scope": "source identity and native executable binding; execution and owner acceptance are separate"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--require-materialized", action="store_true")
    args = parser.parse_args()
    result = check(args.root.resolve(), args.require_materialized)
    print(json.dumps(result, indent=2))
    return result["status"] != "passed"


if __name__ == "__main__":
    raise SystemExit(main())
