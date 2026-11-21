#!/usr/bin/env python3
"""Require a real, monotonic, final-commit Gentek publish request (CI-OPT-002)."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import subprocess


def sequence(current: dict, previous: dict | None) -> int:
    if not isinstance(current, dict) or type(current.get("request_sequence")) is not int:
        raise ValueError("Missing typed current publication request sequence")
    value = current["request_sequence"]
    if value < 1 or value >= 1_000_000_000:
        raise ValueError("Out-of-range publication request")
    if previous is not None:
        if (not isinstance(previous, dict) or
                type(previous.get("request_sequence")) is not int or
                value <= previous["request_sequence"]):
            raise ValueError("New request_sequence must strictly increase")
        if {k: v for k, v in previous.items() if k != "request_sequence"} != {
                k: v for k, v in current.items() if k != "request_sequence"}:
            raise ValueError("Publication request schema/scope was changed; seek separate source review")
    return value


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args], timeout=20)


def check(root: Path, source_sha: str, relative: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise ValueError("Missing exact source SHA")
    if relative != "tools/ci/gentek80_water_publish_request.json":
        raise ValueError("Only the canonical Gentek publisher request is admitted")
    if git(root, "rev-parse", "HEAD").decode().strip() != source_sha:
        raise ValueError("Worktree is not the requested source")
    content = git(root, "show", source_sha + ":" + relative)
    if (root / relative).read_bytes().replace(b"\r\n", b"\n") != content:
        raise ValueError("Checkout request differs from committed source")
    old = subprocess.run(["git", "-C", str(root), "show", source_sha + "^:" + relative],
                         timeout=20, capture_output=True, check=False)
    if old.returncode != 0:
        raise ValueError("No prior accepted request to increment")
    current = json.loads(content)
    previous = json.loads(old.stdout)
    value = sequence(current, previous)
    return {"schema": "ci-opt-002-publish-request-v1", "status": "admitted",
            "source_sha": source_sha, "request_sequence": value,
            "previous_sequence": previous["request_sequence"],
            "scope": "request only; source/runtime/branch leases remain in original publisher"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--path", default="tools/ci/gentek80_water_publish_request.json")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    try:
        result = check(args.root, args.source_sha, args.path)
    except (ValueError, OSError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        result = {"schema": "ci-opt-002-publish-request-v1", "status": "blocked",
                  "reason": str(exc), "source_sha": args.source_sha}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "admitted" else 1


if __name__ == "__main__":
    raise SystemExit(main())
