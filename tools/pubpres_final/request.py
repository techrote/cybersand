#!/usr/bin/env python3
"""Validate a deliberately requested, branch-fenced PUBPRES successor campaign."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REQUEST = ".github/pubpres-playability-final-run.json"
BRANCH = "codex/pubpres-playability-final-001-20261124"
FROZEN = "c90dbc46e1f57f28e06b1f4205b83467335ff657"


def payload_fingerprint(root=ROOT, ref="HEAD"):
    """Hash the entire committed Git tree, excluding only the run request."""
    rows = subprocess.check_output(["git", "ls-tree", "-r", "-z", ref], cwd=root).split(b"\0")
    selected = []
    for row in rows:
        if not row:
            continue
        _metadata, name = row.split(b"\t", 1)
        if name.decode("utf-8") != REQUEST:
            selected.append(row)
    return hashlib.sha256(b"\0".join(selected) + b"\0").hexdigest()


def validate(root=ROOT):
    request = json.loads((root / REQUEST).read_text(encoding="utf-8"))
    if set(request) != {"schema", "phase", "purpose", "frozen_reference", "payload_sha256"}:
        raise ValueError("Unexpected run-request fields")
    if request["schema"] != "pubpres-playability-final-request-v1" or request["phase"] not in ("development", "final", "delivery", "progression"):
        raise ValueError("Unregistered campaign phase")
    if request["frozen_reference"] != FROZEN or not isinstance(request["purpose"], str) or not request["purpose"].strip():
        raise ValueError("Frozen reference or purpose differs")
    if request["payload_sha256"] != payload_fingerprint(root):
        raise ValueError("The run request does not identify the complete executed source tree")
    if os.environ.get("GITHUB_ACTIONS") == "true":
        if os.environ.get("GITHUB_REF") != "refs/heads/" + BRANCH or os.environ.get("GITHUB_EVENT_NAME") != "push":
            raise ValueError("Only the dedicated successor push may execute this campaign")
        actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
        if actual != os.environ.get("GITHUB_SHA"):
            raise ValueError("Workflow checkout is not the requested commit")
    return request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fingerprint", action="store_true")
    args = parser.parse_args()
    if args.fingerprint:
        print(payload_fingerprint())
        return
    request = validate()
    print(json.dumps(request, indent=2))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
            stream.write("phase=" + request["phase"] + "\n")


if __name__ == "__main__":
    main()
