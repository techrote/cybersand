#!/usr/bin/env python3
"""Source-sealed requests for the principal PUBPRES integration campaign."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REQUEST = ".github/pubpres-mainline-run.json"
BRANCH = "codex/pubpres-playability-final-001-20261124"
MAIN = "50e3bcb839211eac2abe1e065750cbcba4d36f8c"
OWNER = "9f2127256a555d177536cbb5fad2be7dcb322c8e"
PHASES = ("build", "qualify", "publish", "delivery")


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=120).decode().strip()


def fingerprint():
    entries = subprocess.check_output(["git", "-C", str(ROOT), "ls-tree", "-r", "-z", "HEAD"])
    selected = [row for row in entries.split(b"\0") if row and row.split(b"\t", 1)[1].decode() != REQUEST]
    return hashlib.sha256(b"\0".join(selected) + b"\0").hexdigest()


def validate_record(value):
    keys = {"schema", "phase", "purpose", "accepted_main", "owner_reference", "payload_sha256",
            "runtime_run", "runtime_attempt", "runtime_source", "physical_acceptance", "promotion"}
    if not isinstance(value, dict) or set(value) != keys or value["schema"] != "pubpres-mainline-request-v1":
        raise ValueError("Unknown integration request shape")
    if value["phase"] not in PHASES or value["accepted_main"] != MAIN or value["owner_reference"] != OWNER:
        raise ValueError("Unregistered phase or comparison sources")
    if value["physical_acceptance"] != "HOLD" or value["promotion"] != "DRAFT_ONLY":
        raise ValueError("This campaign cannot authorize physical acceptance or mainline promotion")
    if not isinstance(value["purpose"], str) or not value["purpose"].strip():
        raise ValueError("A concrete request purpose is required")
    if not re.fullmatch(r"[0-9a-f]{64}", value.get("payload_sha256", "")):
        raise ValueError("Missing complete source-tree seal")
    if value["phase"] == "build":
        if any(value[k] is not None for k in ("runtime_run", "runtime_attempt", "runtime_source")):
            raise ValueError("Fresh builds cannot impersonate an earlier runtime campaign")
    else:
        if not all(type(value[k]) is int and value[k] > 0 for k in ("runtime_run", "runtime_attempt")):
            raise ValueError("An exact original runtime run and attempt are required")
        if not isinstance(value["runtime_source"], str) or not re.fullmatch(r"[0-9a-f]{40}", value["runtime_source"]):
            raise ValueError("Missing exact runtime build source")
    return value


def validate():
    value = validate_record(json.loads((ROOT / REQUEST).read_bytes()))
    if subprocess.run(["git", "-C", str(ROOT), "diff", "--quiet", "HEAD"], check=False, timeout=120).returncode:
        raise ValueError("Tracked execution inputs differ from the sealed committed source")
    if value["payload_sha256"] != fingerprint():
        raise ValueError("Request seal does not identify every committed application input")
    if subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + REQUEST]) != (ROOT / REQUEST).read_bytes():
        raise ValueError("Working request differs from committed request")
    for source in (MAIN, OWNER):
        subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", source, "HEAD"], check=True, timeout=60)
    if os.environ.get("GITHUB_ACTIONS") == "true":
        expected = {"GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
                    "GITHUB_REF": "refs/heads/" + BRANCH, "GITHUB_SHA": git("rev-parse", "HEAD")}
        if any(os.environ.get(k) != v for k, v in expected.items()):
            raise ValueError("Only an exact principal-branch source-owned push can run this campaign")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seal", action="store_true")
    parser.add_argument("--phase", choices=PHASES, default="build")
    parser.add_argument("--purpose")
    parser.add_argument("--runtime-run", type=int)
    parser.add_argument("--runtime-attempt", type=int)
    parser.add_argument("--runtime-source")
    args = parser.parse_args()
    if args.seal:
        value = validate_record({"schema": "pubpres-mainline-request-v1", "phase": args.phase,
            "purpose": args.purpose, "accepted_main": MAIN, "owner_reference": OWNER,
            "payload_sha256": fingerprint(), "runtime_run": args.runtime_run,
            "runtime_attempt": args.runtime_attempt, "runtime_source": args.runtime_source,
            "physical_acceptance": "HOLD", "promotion": "DRAFT_ONLY"})
        (ROOT / REQUEST).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    else:
        value = validate()
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
                for key in ("phase", "runtime_run", "runtime_attempt", "runtime_source"):
                    stream.write(f"{key}={value[key] or ''}\n")
        print(json.dumps(value, indent=2))


if __name__ == "__main__":
    main()
