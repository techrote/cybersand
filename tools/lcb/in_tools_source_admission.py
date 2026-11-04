#!/usr/bin/env python3
"""Explicit #379 source re-admission for accepted main's #390 worker change.

The original v1 plan and source_check remain historical, immutable and strict.
This separately reviewed record changes one source identity, not any fixture,
quantity predicate, comparison input or runtime-qualification claim. Every
current input and all nine pinned comparison inputs must still authenticate.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess

from in_tools_contract import (ContractError, PLAN, ROOT, parse_json, require,
                               source_check, validate_plan)

ADMISSION = ROOT / "godot/tests/fixtures/lcb/in_tools/in-tools-source-admission.2026-11-04.json"
ORIGINAL_PATH = "godot/tests/fixtures/lcb/in_tools/in-tools-admission.v1.json"
ORIGINAL_COMMIT = "1aaab324a9bccbaa7f868798dbb4f9fd9b4a7718"
ORIGINAL_SHA256 = "8e5e12a5cbaf0ccf554f07dfc49ea17757112445bf23d6dc144154b6165b735a"
ACCEPTED_MAIN = "751edc0b495dc85484ad5509a7c95f863651c76b"
ACCEPTED_TREE = "b0d42a256285e6049a6d3bdd1613d7ecd89f43c6"
SOURCE_COMMIT = "9a9e63a0091f3a64e038892e651d0591d135241a"
WORKER = "godot/scripts/simulation_worker.gd"
BEFORE_WORKER = "7facdb0cd1a59a039fb78c22298b7422f656f733082228ea178d7917234a2dd0"
AFTER_WORKER = "6b1c27ff4e0013db58436079834ceae2c26589a752ee166462437c9aff2dbdbf"
COMPARISON = "fbe82bcab8f821aac442c2bf59eb57b279717873"
AUTHORITY = "docs/audits/2026-11-04-in-tools-379-current-main-readmission.md"
RECORD_KEYS = {"schema", "id", "scope", "original_plan", "accepted_main", "accepted_tree",
               "reviewed_changes", "source_inputs", "comparison_commit", "authority",
               "gameplay_qualified", "runtime_qualified"}


def canonical_sha(raw: bytes) -> str:
    """Use the same canonical text-byte rule as the original inspected lock."""
    return hashlib.sha256(raw.replace(b"\r\n", b"\n")).hexdigest()


def admitted_plan(original: bytes, admission: dict) -> dict:
    """Derive a checked in-memory view; never write or mutate the v1 plan."""
    require(hashlib.sha256(original).hexdigest() == ORIGINAL_SHA256, "original v1 plan changed")
    plan = parse_json(original.decode("utf-8"))
    validate_plan(plan)
    require(type(admission) is dict and set(admission) == RECORD_KEYS,
            "source-admission record fields differ")
    require(admission["schema"] == "in-tools-source-admission-v1" and
            admission["id"] == "in-tools-main-751edc0b-20261104" and
            admission["scope"] == "source-admission-only", "unreviewed source admission")
    require(admission["original_plan"] == {"path": ORIGINAL_PATH, "commit": ORIGINAL_COMMIT,
            "sha256": ORIGINAL_SHA256}, "original plan identity differs")
    require(admission["accepted_main"] == ACCEPTED_MAIN and
            admission["accepted_tree"] == ACCEPTED_TREE, "unreviewed accepted-main identity")
    require(admission["comparison_commit"] == COMPARISON == plan["comparison"]["commit"],
            "pinned comparison identity changed")
    require(admission["authority"] == AUTHORITY, "source-admission authority differs")
    require(admission["gameplay_qualified"] is False and admission["runtime_qualified"] is False,
            "source admission cannot claim runtime or gameplay qualification")
    require(admission["reviewed_changes"] == [{"path": WORKER, "before_sha256": BEFORE_WORKER,
            "after_sha256": AFTER_WORKER, "source_commit": SOURCE_COMMIT,
            "integration_commit": ACCEPTED_MAIN}], "unreviewed or incomplete source transition")
    expected = dict(plan["source_inputs"])
    require(len(expected) == 25 and expected[WORKER] == BEFORE_WORKER,
            "original source inventory differs")
    expected[WORKER] = AFTER_WORKER
    require(admission["source_inputs"] == expected,
            "source inventory changed beyond the one reviewed worker identity")
    effective = copy.deepcopy(plan)
    effective["source_inputs"] = expected
    effective["accepted_main"] = ACCEPTED_MAIN
    effective["accepted_tree"] = ACCEPTED_TREE
    return effective


def git_bytes(root: Path, *args: str) -> bytes:
    try:
        return subprocess.check_output(["git", "-C", str(root), *args],
                                       stderr=subprocess.PIPE, timeout=30)
    except (subprocess.SubprocessError, OSError) as error:
        raise ContractError("required Git source/ancestry unavailable: " + " ".join(args)) from error


def check(root: Path = ROOT, admission_path: Path = ADMISSION) -> dict:
    original = (root / ORIGINAL_PATH).read_bytes()
    admission = parse_json(admission_path.read_text(encoding="utf-8"))
    plan = admitted_plan(original, admission)
    historical = git_bytes(root, "show", f"{ORIGINAL_COMMIT}:{ORIGINAL_PATH}")
    require(hashlib.sha256(historical).hexdigest() == ORIGINAL_SHA256,
            "original Git plan identity differs")
    require(hashlib.sha256(git_bytes(root, "show", f"HEAD:{ORIGINAL_PATH}")).hexdigest()
            == ORIGINAL_SHA256, "committed original v1 plan differs")
    require(git_bytes(root, "rev-parse", ACCEPTED_MAIN + "^{tree}").decode().strip() == ACCEPTED_TREE,
            "accepted-main Git tree differs")
    git_bytes(root, "merge-base", "--is-ancestor", ACCEPTED_MAIN, "HEAD")
    # Authenticate the complete inventory against accepted Git source, the
    # claimed HEAD and actual checkout bytes. A repaired worktree cannot hide
    # an unreviewed committed source change. Git blobs use their exact bytes;
    # source_check retains its historical working-file newline compatibility.
    for relative, expected in plan["source_inputs"].items():
        require(hashlib.sha256(git_bytes(root, "show", f"{ACCEPTED_MAIN}:{relative}")).hexdigest() == expected,
                f"admitted input differs from accepted main: {relative}")
        require(hashlib.sha256(git_bytes(root, "show", f"HEAD:{relative}")).hexdigest() == expected,
                f"committed source differs from admission: {relative}")
    result = source_check(plan, root, comparison=True)
    # The original comparison records contain independent blob IDs in addition
    # to their SHA-256. Keep both boundaries when authenticating external reuse.
    for entry in plan["comparison"]["reuse"]:
        actual = git_bytes(root, "rev-parse", f"{COMPARISON}:{entry['path']}").decode().strip()
        require(actual == entry["git_blob"], f"comparison Git blob differs: {entry['path']}")
    require(result["source_inputs_checked"] == 25 and result["comparison_inputs_checked"] == 9,
            "incomplete admitted inventory")
    return {**validate_plan(plan), **result, "status": "source-admitted",
            "admission_id": admission["id"], "accepted_main": ACCEPTED_MAIN,
            "accepted_tree": ACCEPTED_TREE, "original_plan_sha256": ORIGINAL_SHA256,
            "reviewed_source_changes": [WORKER], "runtime_qualified": False,
            "native_receipt_authenticated": False,
            "git_commit": git_bytes(root, "rev-parse", "HEAD").decode().strip(),
            "git_tree": git_bytes(root, "rev-parse", "HEAD^{tree}").decode().strip()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--admission", type=Path, default=ADMISSION)
    args = parser.parse_args()
    try:
        print(json.dumps(check(admission_path=args.admission), indent=2))
        return 0
    except (ContractError, KeyError, TypeError, ValueError, OSError) as error:
        print(json.dumps({"status": "refused", "reason": str(error),
                          "gameplay_qualified": False, "runtime_qualified": False}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
