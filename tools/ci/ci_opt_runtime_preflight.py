#!/usr/bin/env python3
"""Cheap fail-closed native runtime provenance preflight (CI-OPT-002).

Works on an ordinary Git checkout containing LFS *pointers*, before downloading
Godot, Rapier or any binaries. A positive result proves source-input identity,
manifest structure and an artifact's committed LFS identity, NOT execution.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

NATIVE = {
    "linux": (
        "godot/addons/cybersand_native/runtime-provenance.linux.json",
        "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    ),
    "windows": (
        "godot/addons/cybersand_native/runtime-provenance.json",
        "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    ),
}
DIGEST = re.compile(r"[0-9a-f]{64}\Z")
POINTER = re.compile(
    rb"version https://git-lfs.github.com/spec/v1\n"
    rb"oid sha256:([0-9a-f]{64})\nsize ([1-9][0-9]*)\n?\Z"
)


def safe_path(root: Path, name: str) -> Path:
    if not isinstance(name, str) or not name or "\\" in name or "\x00" in name:
        raise ValueError("malformed input path")
    path = Path(name)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        raise ValueError("input path escapes checkout")
    target = root.joinpath(path)
    # Reject symlinks in every component, not just at the leaf.
    for part in [root.joinpath(*path.parts[:index]) for index in range(1, len(path.parts) + 1)]:
        if part.is_symlink():
            raise ValueError("symlinked native input")
    if not target.is_file():
        raise ValueError("missing native input")
    return target


def sha256(path: Path, *, normalize_lf: bool = False) -> str:
    digest = hashlib.sha256()
    if normalize_lf:
        digest.update(path.read_bytes().replace(b"\r\n", b"\n"))
    else:
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
    return digest.hexdigest()


def check_platform(root: Path, platform: str) -> dict:
    manifest_name, artifact_name = NATIVE[platform]
    problems: list[str] = []
    result: dict = {"platform": platform, "manifest": manifest_name,
                    "artifact": artifact_name, "checked_inputs": 0,
                    "runtime_form": "missing", "errors": problems}
    try:
        manifest = json.loads(safe_path(root, manifest_name).read_text(encoding="utf-8"))
        if not isinstance(manifest, dict):
            raise ValueError("runtime manifest is not an object")
        if manifest.get("platform") != platform:
            problems.append("platform mismatch")
        if manifest.get("status") != "validated-development-runtime":
            problems.append("native runtime is not qualified")
        if manifest.get("artifact") != artifact_name:
            problems.append("artifact path mismatch")
        size = manifest.get("size")
        digest = manifest.get("sha256")
        if type(size) is not int or not 0 < size < 2**31 or not isinstance(digest, str) or not DIGEST.fullmatch(digest):
            raise ValueError("invalid artifact digest or size")
        inputs = manifest.get("source_inputs")
        if not isinstance(inputs, dict) or len(inputs) < 1 or len(inputs) > 20000:
            raise ValueError("missing or unbounded native input ledger")
        for name, expected in sorted(inputs.items()):
            if not isinstance(expected, str) or not DIGEST.fullmatch(expected):
                problems.append("invalid input hash: " + str(name))
                continue
            try:
                path = safe_path(root, name)
            except ValueError as err:
                problems.append(f"input path refused: {name}: {err}")
                continue
            result["checked_inputs"] += 1
            if sha256(path, normalize_lf=True) != expected:
                problems.append("source changed since binary build: " + name)
        artifact = safe_path(root, artifact_name)
        if artifact.stat().st_size < 512:
            match = POINTER.fullmatch(artifact.read_bytes().replace(b"\r\n", b"\n"))
            if not match:
                problems.append("artifact is not a valid Git LFS pointer or binary")
            else:
                result["runtime_form"] = "committed-lfs-pointer"
                if match[1].decode() != digest or int(match[2]) != size:
                    problems.append("LFS pointer identity differs from runtime provenance")
        else:
            result["runtime_form"] = "materialized"
            if artifact.stat().st_size != size or sha256(artifact) != digest:
                problems.append("materialized runtime differs from provenance")
        result["artifact_sha256"] = digest
    except (ValueError, OSError, UnicodeError, TypeError, json.JSONDecodeError) as err:
        problems.append("runtime evidence unreadable or invalid: " + str(err))
    result["status"] = "blocked_unpublished_runtime" if problems else "admitted"
    return result


def check(root: Path, platforms: tuple[str, ...]) -> dict:
    root = root.resolve()
    rows = [check_platform(root, platform) for platform in platforms]
    return {"schema": "ci-opt-002-runtime-preflight-v1",
            "status": "admitted" if all(row["status"] == "admitted" for row in rows)
            else "blocked_unpublished_runtime",
            "scope": "source inputs + provenance + LFS identity only; no execution claim",
            "platforms": rows}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--platform", choices=["linux", "windows", "both"], default="both")
    parser.add_argument("--expect-sha", help="Optional exact 40-character Git HEAD binding")
    args = parser.parse_args()
    result = check(args.root, tuple(NATIVE) if args.platform == "both" else (args.platform,))
    if args.expect_sha:
        if not re.fullmatch(r"[0-9a-f]{40}", args.expect_sha):
            result["status"] = "blocked_unpublished_runtime"
            result["source_error"] = "malformed expected source SHA"
        else:
            try:
                actual = subprocess.check_output(["git", "-C", str(args.root), "rev-parse", "HEAD"],
                                                 text=True, timeout=10).strip()
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
                actual = ""
            if actual != args.expect_sha:
                result["status"] = "blocked_unpublished_runtime"
                result["source_error"] = "checkout does not match requested SHA"
        result["requested_source"] = args.expect_sha
    print(json.dumps(result, indent=2, sort_keys=True))
    # A blocked prepublication candidate must not turn a required check green.
    return 0 if result["status"] == "admitted" else 1


if __name__ == "__main__":
    raise SystemExit(main())
