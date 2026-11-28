#!/usr/bin/env python3
"""Validate an explicit SWARM-004 Windows run against immutable Git history.

This is an execution request, not a credential or permission mechanism. The
workflow keeps GitHub's existing branch access and read-only job permissions.
Ordinary source pushes do not match its exact request-path trigger.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BRANCH = "refs/heads/experiment/gentek-swarm-004-workbench"
REQUEST = ".github/swarm004-windows-request.json"
MAX_REQUEST_BYTES = 4096
MAX_REQUEST_COMMITS = 16
SHA = re.compile(r"[0-9a-f]{40}")
REQUEST_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,79}")
KEYS = {"schema", "programme", "action", "source_sha", "request_id"}


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def git(root: Path, *arguments: str) -> bytes:
    result = subprocess.run(["git", "-C", str(root), *arguments], capture_output=True, timeout=30)
    require(result.returncode == 0, "Git history lookup failed: " + " ".join(arguments))
    return result.stdout


def commit(root: Path, value: object) -> str:
    require(isinstance(value, str) and SHA.fullmatch(value) is not None,
            "Source identity must be a complete lowercase commit SHA")
    require(git(root, "cat-file", "-t", value).strip() == b"commit", "Source identity is not a commit")
    return value


def ancestor(root: Path, earlier: str, later: str) -> bool:
    result = subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", earlier, later],
                            capture_output=True, timeout=30)
    require(result.returncode in (0, 1), "Could not establish source ancestry")
    return result.returncode == 0


def changed(root: Path, earlier: str, later: str) -> list[str]:
    return [name.decode("utf-8") for name in git(root, "diff", "--name-only", "--no-renames", "-z",
                                               earlier, later, "--").split(b"\0") if name]


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def request_at(root: Path, execution: str) -> tuple[dict, bytes]:
    entry = git(root, "ls-tree", execution, "--", REQUEST).decode("utf-8").strip()
    fields = entry.split()
    require(len(fields) == 4 and fields[0] == "100644" and fields[1] == "blob" and fields[3] == REQUEST,
            "Execution requires the committed regular request file")
    length = int(git(root, "cat-file", "-s", fields[2]))
    require(0 < length <= MAX_REQUEST_BYTES, "Run request exceeds its 4 KiB budget")
    payload = git(root, "cat-file", "blob", fields[2])
    request = json.loads(payload, object_pairs_hook=unique_object)
    require(isinstance(request, dict) and set(request) == KEYS, "Run request has an unknown or missing field")
    require(type(request["schema"]) is int and request["schema"] == 1,
            "Run request schema must be integer1")
    require(request["programme"] == "GENTEK-SWARM-004" and request["action"] == "qualify-windows",
            "Run request is not for the bounded SWARM-004 Windows qualification")
    require(isinstance(request["request_id"], str) and REQUEST_ID.fullmatch(request["request_id"]) is not None,
            "Run request needs a bounded explicit request identifier")
    return request, payload


def validate(root: Path, event_name: str, ref: str, execution: str, target: str,
             event: dict | None = None) -> dict:
    require(ref == BRANCH, "Qualification is restricted to the exact experimental Workbench branch")
    execution = commit(root, execution)
    require(git(root, "rev-parse", "HEAD").decode().strip() == execution and target == execution,
            "Checkout, execution HEAD and qualification target must be identical")
    result = {"schema": 1, "event": event_name, "ref": ref, "execution_source_sha": execution,
              "frozen_source_sha": execution, "request_id": None, "request_sha256": None,
              "request_only_commits": [], "passed": True}
    if event_name == "workflow_dispatch":
        return result
    require(event_name == "push", "Only explicit manual dispatch or the committed run request is admitted")
    require(isinstance(event, dict) and event.get("ref") == BRANCH and event.get("after") == execution,
            "Push payload does not identify this exact branch and execution commit")
    require(event.get("created") is False and event.get("deleted") is False and event.get("forced") is False,
            "Run requests require an ordinary update of the already published branch")
    before = commit(root, event.get("before"))
    request, payload = request_at(root, execution)
    frozen = commit(root, request["source_sha"])
    require(frozen != execution and ancestor(root, frozen, execution),
            "Declared frozen source must be a proper ancestor of execution HEAD")
    require(before != execution and ancestor(root, frozen, before) and ancestor(root, before, execution),
            "Publish the frozen source before writing the separate execution request")
    commits = git(root, "rev-list", f"--max-count={MAX_REQUEST_COMMITS + 1}",
                  f"{frozen}..{execution}").decode().splitlines()
    require(0 < len(commits) <= MAX_REQUEST_COMMITS, "Request-only source ancestry exceeds its bounded history")
    for revision in commits:
        parents = git(root, "show", "--no-patch", "--format=%P", revision).decode().split()
        require(len(parents) == 1, "Run-request ancestry must be linear; merge commits are refused")
        require(changed(root, parents[0], revision) == [REQUEST],
                "Every commit after the frozen source must change only the request file")
    require(changed(root, frozen, execution) == [REQUEST] and changed(root, before, execution) == [REQUEST],
            "The current push must contain an actual request-file change and no source delta")
    result.update(frozen_source_sha=frozen, request_id=request["request_id"],
                  request_sha256=hashlib.sha256(payload).hexdigest(), request_only_commits=commits)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--event-name", default=os.environ.get("GITHUB_EVENT_NAME", ""))
    parser.add_argument("--ref", default=os.environ.get("GITHUB_REF", ""))
    parser.add_argument("--execution", default=os.environ.get("GITHUB_SHA", ""))
    parser.add_argument("--target", default=os.environ.get("TARGET_SOURCE", ""))
    parser.add_argument("--event-file", type=Path, default=os.environ.get("GITHUB_EVENT_PATH"))
    parser.add_argument("--expected-receipt", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    event = None
    if args.event_name == "push":
        require(args.event_file is not None and args.event_file.stat().st_size <= 4 * 1024 * 1024,
                "A bounded GitHub push event is required")
        event = json.loads(args.event_file.read_bytes(), object_pairs_hook=unique_object)
    result = validate(args.root, args.event_name, args.ref, args.execution, args.target, event)
    if args.expected_receipt is not None:
        require(args.expected_receipt.stat().st_size <= MAX_REQUEST_BYTES * 2,
                "Producer request receipt exceeds its finite budget")
        expected = json.loads(args.expected_receipt.read_bytes(), object_pairs_hook=unique_object)
        require(expected == result, "Producer and consumer run-request validation differ")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
