#!/usr/bin/env python3
"""Freeze a hosted qualification request outside the measured Git payload."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REQUEST = ".github/pubpres-completion-run.json"
REGISTRATION = "tools/pubpres_completion/registration.json"
BRANCH = "refs/heads/codex/pubpres-completion-001-20261122"
PHASES = ("delivery", "targeted", "final")
SCHEMA = "pubpres-completion-run-v1"


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=90)


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def payload_hash():
    entries = git("ls-tree", "-rz", "HEAD").split(b"\0")
    frozen = [entry for entry in entries if entry and entry.split(b"\t", 1)[1] != REQUEST.encode()]
    return sha256(b"\0".join(frozen) + b"\0")


def registration():
    content = (ROOT / REGISTRATION).read_bytes()
    if content != git("show", "HEAD:" + REGISTRATION):
        raise ValueError("Commit the exact registration before freezing a request")
    record = json.loads(content)
    if record["schema"] != "pubpres-completion-campaign-v1" or record["continuation_order"] != ["off", "on", "on", "off"]:
        raise ValueError("Unregistered programme or treatment order")
    return record, sha256(content)


def plan(request):
    settings, registered_sha = registration()
    if (set(request) != {"schema", "phase", "registration_sha256", "frozen_payload_tree_sha256", "purpose"}
            or request["schema"] != SCHEMA or request["phase"] not in PHASES
            or request["registration_sha256"] != registered_sha
            or request["frozen_payload_tree_sha256"] != payload_hash()
            or not isinstance(request["purpose"], str) or not 5 <= len(request["purpose"]) <= 500):
        raise ValueError("Qualification request does not match the exact frozen tree and registration")
    phase = request["phase"]
    cases = [] if phase == "delivery" else settings["development_cases" if phase == "targeted" else "final_cases"]
    if len(cases) != len(set(cases)) or len(cases) > 7:
        raise ValueError("Repeated or excessive comparison cases")
    rows = [{"case": case, "cohort": "donor", "include_diagnostics": case in settings["development_cases"]} for case in cases]
    if phase == "final":
        rows.append({"case": "registered_current_main", "cohort": "main", "include_diagnostics": False})
    return {"phase": phase, "comparisons": {"include": rows}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=PHASES)
    parser.add_argument("--purpose")
    parser.add_argument("--validate", action="store_true")
    args = parser.parse_args()
    if args.validate:
        if os.environ.get("GITHUB_REF") != BRANCH or git("rev-parse", "HEAD").decode().strip() != os.environ.get("GITHUB_SHA"):
            parser.error("Hosted validation requires the exact Completion push SHA")
        request = json.loads((ROOT / REQUEST).read_bytes())
        selected = plan(request)
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
            output.write("phase=" + selected["phase"] + "\n")
            output.write("comparisons=" + json.dumps(selected["comparisons"], separators=(",", ":")) + "\n")
        print(json.dumps({"request": request, "plan": selected, "candidate": os.environ["GITHUB_SHA"]}))
        return
    if not args.phase or not args.purpose:
        parser.error("Freeze an explicit phase and purpose")
    _, registered_sha = registration()
    record = {"schema": SCHEMA, "phase": args.phase, "purpose": args.purpose, "registration_sha256": registered_sha,
              "frozen_payload_tree_sha256": payload_hash()}
    plan(record)
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
