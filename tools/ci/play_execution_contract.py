#!/usr/bin/env python3
"""Source-bound watchdog checks shared by current PLAY evidence readers.

Historical evidence retains its original reader and policy. A receipt never
chooses its own allowance: the checked-out source policy and explicit local
scale determine the expected identity and process budget.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

from execution_policy import identity, watchdog_seconds

ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = "godot/tests/support/ci_execution_policy.json"
MARKER = "CYBERSAND_CI_POLICY "
GODOT_KEYS = (
    "main_ack_seconds", "graphical_case_seconds", "godot_import_seconds",
    "operation_seconds", "complex_fixture_seconds", "hosted_job_minutes",
    "diagnostic_capture_seconds", "terminate_grace_seconds",
)


def _same(actual: object, expected: object) -> bool:
    """JSON numeric equality permits int/float, never boolean-as-one or NaN."""
    if type(expected) in (int, float):
        return type(actual) in (int, float) and math.isfinite(actual) and actual == expected
    if isinstance(expected, dict):
        return (isinstance(actual, dict) and actual.keys() == expected.keys()
                and all(_same(actual[key], value) for key, value in expected.items()))
    if isinstance(expected, list):
        return (isinstance(actual, list) and len(actual) == len(expected)
                and all(_same(a, b) for a, b in zip(actual, expected)))
    return type(actual) is type(expected) and actual == expected


def policy_matches(value: object) -> bool:
    return _same(value, identity())


def process_policy_matches(process: dict) -> bool:
    return policy_matches(process.get("execution_policy")) and process.get("natural_completion") is True


def verify_source_policy(source: str) -> dict:
    if not isinstance(source, str) or re.fullmatch(r"[0-9a-f]{40}", source) is None:
        raise ValueError("execution_policy_source_identity")
    expected = identity()
    data = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", source + ":" + POLICY_PATH],
        timeout=watchdog_seconds("operation_seconds"))
    if hashlib.sha256(data).hexdigest() != expected["sha256"]:
        raise ValueError("execution_policy_source_mismatch")
    return expected


def verify_log_policy(log: str, source: str) -> dict:
    expected = verify_source_policy(source)
    rows = [line[len(MARKER):] for line in log.splitlines() if line.startswith(MARKER)]
    if len(rows) != 1:
        raise ValueError("execution_policy_log_inventory")
    observed = json.loads(rows[0])
    if (not isinstance(observed, dict) or observed.get("ok") is not True
            or observed.get("path") != "res://tests/support/ci_execution_policy.json"
            or not _same(observed.get("schema_version"), expected["schema_version"])
            or not _same(observed.get("scale"), expected["scale"])
            or observed.get("sha256") != expected["sha256"]
            or not isinstance(observed.get("watchdogs"), dict)
            or not all(_same(observed["watchdogs"].get(key), expected["watchdogs"][key])
                       for key in GODOT_KEYS)):
        raise ValueError("execution_policy_log_mismatch")
    return expected
