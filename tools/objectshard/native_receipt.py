#!/usr/bin/env python3
"""Bind a one-run Linux candidate to source captured before its compilation."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
from native_candidate_identity import source

CONTRACT = ("tools/build_native_extension.sh", "tools/build_pinned_godot_cpp.sh",
            "tools/toolchains/g++",
            "third_party/native-toolchain.lock.json", "tools/requirements-build.txt")


def identity(root: Path) -> dict:
    commit, tree, inputs = source(root)
    subprocess.run(["git", "-C", str(root), "diff", "--exit-code", "HEAD", "--", *CONTRACT], check=True, timeout=120)
    return {"source_commit": commit, "source_tree": tree, "source_inputs": inputs,
            "build_contract_inputs": {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in CONTRACT}}


def runtime(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20 or data[:6] != b"\x7fELF\x02\x01" or data[18:20] != b"\x3e\x00":
        raise ValueError("Candidate must be a Linux x86_64 ELF runtime")
    return {"sha256": hashlib.sha256(data).hexdigest(), "size": len(data), "platform": "linux-x86_64"}


def verify(receipt: Path, binary: Path, root: Path = ROOT) -> dict:
    document = json.loads(receipt.read_text(encoding="utf-8"))
    if document.get("schema") != "objectshard-linux-native-v1" or document.get("phase") != "sealed":
        raise ValueError("Incomplete Linux native receipt")
    if document.get("source") != identity(root) or document.get("runtime") != runtime(binary):
        raise ValueError("Linux source/runtime receipt mismatch")
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("snapshot", "seal", "verify"))
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--expected-source-sha", required=True)
    args = parser.parse_args()
    current = identity(ROOT)
    if current["source_commit"] != args.expected_source_sha:
        raise ValueError("Unexpected source commit")
    if args.action == "snapshot":
        if args.receipt.exists():
            raise ValueError("Refusing to overwrite an earlier source snapshot")
        document = {"schema": "objectshard-linux-native-v1", "phase": "captured", "source": current}
    else:
        if not args.runtime:
            parser.error("--runtime is required for seal/verify")
        if args.action == "verify":
            print(json.dumps(verify(args.receipt, args.runtime)))
            return
        document = json.loads(args.receipt.read_text(encoding="utf-8"))
        if document.get("schema") != "objectshard-linux-native-v1" or document.get("phase") != "captured" or document.get("source") != current:
            raise ValueError("Source changed since the precompile capture")
        document.update(phase="sealed", runtime=runtime(args.runtime))
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"phase": document["phase"], "source_commit": current["source_commit"]}))


if __name__ == "__main__":
    main()
