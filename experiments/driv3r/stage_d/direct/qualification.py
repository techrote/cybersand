"""Exact-checkout, CPU-only qualification of the D-1A DEVELOPMENT suite.

Run as python -m experiments.driv3r.stage_d.direct.qualification from an
unmodified source checkout. No model, native Workbench, held-out evaluator,
training or GPU action is launched by this harness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from .m1_preflight import M1_SCHEMA_SHA256, M1_SOURCE_COMMIT, assert_approved_schema
from .inventory import TestInventoryError, audit_test_inventory

VERSION = "d1a-exact-head-offline-qualification/1"
LANE = "experiments/driv3r/stage_d/direct"
MINIMUM_TESTS = 130  # Independently inspected pre-inventory suite floor at f969338f.
_SHA = re.compile(r"[0-9a-f]{40}\Z")
_RESULT = re.compile(r"^Ran (\d+) tests? in [\d.]+s$", re.MULTILINE)
_SKIPPED = re.compile(r"skipped=(\d+)")


class QualificationError(ValueError):
    """A source/contract precondition failed; no test result is certified."""


def parse_unittest_result(log: str, returncode: int) -> dict:
    """Conservatively interpret unittest's footer, including skips/failures."""
    matches = _RESULT.findall(log)
    if len(matches) != 1:
        return {"test_count": None, "skipped": None, "passed": False,
                "reason": "missing_or_ambiguous_unittest_footer"}
    count = int(matches[0])
    tail = log[log.index("Ran "):]
    skipped_match = _SKIPPED.search(tail)
    skipped = int(skipped_match.group(1)) if skipped_match else 0
    passed = (returncode == 0 and count >= MINIMUM_TESTS and skipped == 0 and
              re.search(r"^OK$", tail, re.MULTILINE) is not None and
              "FAILED" not in tail)
    return {"test_count": count, "skipped": skipped, "passed": passed,
            "reason": "qualified" if passed else "failed_incomplete_or_skipped_suite"}


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=root, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          timeout=20, check=False)


def source_fence(root: Path) -> str:
    """Require exact SHA ancestry, frozen M1 schema and clean lane worktree."""
    head = _git(root, "rev-parse", "HEAD")
    if head.returncode or not _SHA.fullmatch(head.stdout.strip()):
        raise QualificationError("A valid repository HEAD is required")
    sha = head.stdout.strip()
    ancestor = _git(root, "merge-base", "--is-ancestor", M1_SOURCE_COMMIT, sha)
    if ancestor.returncode != 0:
        raise QualificationError("Accepted M1 source is not an ancestor of tested HEAD")
    # An exact commit is not a source guarantee if shared imports or other
    # worktree paths have been edited. Fail on any tracked or untracked change.
    dirty = _git(root, "status", "--porcelain", "--untracked-files=all")
    if dirty.returncode or dirty.stdout.strip():
        raise QualificationError("Source worktree dirty or Git status unavailable")
    # This stacked branch is D-1A-exclusive: immutable M1 plus lane files.
    # Reject even committed changes to shared contracts, frozen evidence or
    # production code; HEAD ancestry alone would not detect such changes.
    changed = _git(root, "diff", "--name-only", M1_SOURCE_COMMIT, sha)
    if changed.returncode or any(
        not name.startswith(LANE + "/") for name in changed.stdout.splitlines()
    ):
        raise QualificationError("HEAD differs from accepted M1 outside D-1A lane")
    try:
        assert_approved_schema(root)
    except (OSError, ValueError) as exc:
        raise QualificationError("Approved M1 schema bytes unavailable or mismatched") from exc
    return sha


def run_qualification(root: Path, timeout_seconds: int = 180) -> tuple[dict, str]:
    """Run every lane-owned unittest; preserve unfiltered first-pass failure log."""
    if type(timeout_seconds) is not int or not 1 <= timeout_seconds <= 600:
        raise QualificationError("CPU test timeout must be 1..600 seconds")
    root = root.resolve()
    source_sha = source_fence(root)
    try:
        inventory = audit_test_inventory(root)
    except TestInventoryError as exc:
        raise QualificationError("Offline source test inventory refused") from exc
    command = [sys.executable, "-m", "unittest", "discover", "-s", LANE,
               "-p", "test_*.py", "-v"]
    try:
        proc = subprocess.run(command, cwd=root, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True,
                              timeout=timeout_seconds, check=False)
        log, returncode, timed_out = proc.stdout, proc.returncode, False
    except subprocess.TimeoutExpired as exc:
        raw = exc.stdout or b""
        log = raw.decode("utf-8", "replace") if isinstance(raw, bytes) else raw
        returncode, timed_out = 124, True
    result = parse_unittest_result(log, returncode)
    if result["test_count"] != inventory["method_count"]:
        result["passed"] = False
        result["reason"] = "discovery_count_does_not_match_source_inventory"
    try:
        final_head = source_fence(root)
        same_source = source_sha == final_head
    except QualificationError:
        same_source = False
    result.update({
        "version": VERSION, "source_sha": source_sha,
        "approved_m1_commit": M1_SOURCE_COMMIT,
        "approved_m1_schema_sha256": M1_SCHEMA_SHA256,
        "minimum_expected_test_count": MINIMUM_TESTS,
        "source_test_inventory": inventory,
        "test_command": command, "timeout_seconds": timeout_seconds,
        "returncode": returncode, "timed_out": timed_out,
        "source_stable_and_clean_after_tests": same_source,
        "full_suite_passed": result["passed"] and same_source and not timed_out,
        "log_sha256": hashlib.sha256(log.encode("utf-8")).hexdigest(),
        "native_qualified": False, "sequential_native_receipts": 0,
        "heldout_model_outcomes_evaluated": False,
    })
    if not result["full_suite_passed"]:
        result["reason"] = ("source_changed_during_tests" if not same_source
                            else "timed_out" if timed_out else result["reason"])
    return result, log


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout-seconds", type=int, default=180)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    try:
        report, log = run_qualification(root, args.timeout_seconds)
        sys.stderr.write(log)
    except QualificationError as exc:
        report = {"version": VERSION, "full_suite_passed": False,
                  "reason": "precondition_refused", "detail": str(exc),
                  "native_qualified": False, "sequential_native_receipts": 0}
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["full_suite_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
