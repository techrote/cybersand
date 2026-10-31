#!/usr/bin/env python3
"""Shared execution allowances; elapsed-time advice is never a correctness gate.

The JSON is a Godot resource so Python, GDScript and shell callers consume the
same committed values. Environment scaling can enlarge allowances, never shrink
them. Deliberately small adverse-control bounds are explicit fixture inputs and
do not go through this policy.
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / "godot/tests/support/ci_execution_policy.json"
SCALE_ENV = "CYBERSAND_CI_WATCHDOG_SCALE"
REQUIRED_KEYS = (
    "main_ack_seconds", "graphical_case_seconds", "godot_import_seconds",
    "operation_seconds", "complex_fixture_seconds", "hosted_job_minutes",
    "diagnostic_capture_seconds", "terminate_grace_seconds",
)


def validate_policy(document: object, scale_text: str = "") -> dict:
    if not isinstance(document, dict) or type(document.get("schema_version")) is not int or document["schema_version"] != 1:
        raise ValueError("Unsupported execution policy schema")
    raw = document.get("watchdogs")
    if not isinstance(raw, dict) or not set(REQUIRED_KEYS).issubset(raw):
        raise ValueError("Missing execution watchdogs")
    try:
        scale = float(scale_text) if scale_text else 1.0
    except (TypeError, ValueError) as error:
        raise ValueError("Watchdog scale must be a finite number >= 1") from error
    if not math.isfinite(scale) or scale < 1:
        raise ValueError("Watchdog scale must be a finite number >= 1")
    effective = {}
    for key, value in raw.items():
        if not isinstance(key, str) or not key.endswith(("_seconds", "_minutes")):
            raise ValueError("Invalid watchdog name")
        if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
            raise ValueError("Invalid positive watchdog: " + key)
        scaled = value * scale
        if not math.isfinite(scaled) or scaled > 9_000_000_000_000:
            raise ValueError("Watchdog conversion would overflow: " + key)
        effective[key] = scaled
    if any(effective[key] > effective["complex_fixture_seconds"] for key in ("main_ack_seconds", "operation_seconds")):
        raise ValueError("Fixture watchdog must include setup and operation allowances")
    return {"schema_version": 1, "policy_id": document.get("policy_id", "unknown"),
            "scale": scale, "watchdogs": effective,
            "advisories": document.get("advisories", {})}


def identity() -> dict:
    data = POLICY_PATH.read_bytes()
    result = validate_policy(json.loads(data), os.environ.get(SCALE_ENV, ""))
    return {**result, "path": POLICY_PATH.relative_to(ROOT).as_posix(),
            "sha256": hashlib.sha256(data).hexdigest()}


def watchdog_seconds(key: str) -> float:
    if not key.endswith("_seconds"):
        raise ValueError("Expected seconds watchdog: " + key)
    return identity()["watchdogs"][key]


def watchdog_microseconds(key: str) -> int:
    return math.ceil(watchdog_seconds(key) * 1_000_000)


def complex_process_seconds() -> float:
    """Allow the inner fixture to fail, unwind, and preserve diagnostics first."""
    values = identity()["watchdogs"]
    return sum(values[key] for key in (
        "complex_fixture_seconds", "operation_seconds",
        "diagnostic_capture_seconds", "terminate_grace_seconds"))


def case_seconds(name: str, requires_display: bool = False, *, complex_fixture: bool = False) -> float:
    # Tests with an internal whole-fixture watchdog must have a strictly larger
    # parent; ordinary rendered cases and scripts have distinct allowances.
    if (complex_fixture or name.startswith(("test_play_", "test_physical_", "test_liquid_", "test_lcb_"))
            or name in {"profile_native_world", "profile_scheduler"}):
        return complex_process_seconds()
    return watchdog_seconds("graphical_case_seconds" if requires_display else "ordinary_case_seconds")


def aggregate_seconds(children: list[float], *, include_import: bool = True) -> float:
    values = identity()["watchdogs"]
    if any(type(value) not in (int, float) or not math.isfinite(value) or value <= 0 for value in children):
        raise ValueError("Aggregate children must have finite positive allowances")
    return sum(children) + values["aggregate_headroom_seconds"] + (
        values["godot_import_seconds"] if include_import else 0)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("unit", choices=("seconds", "minutes", "identity"))
    parser.add_argument("key", nargs="?")
    args = parser.parse_args()
    policy = identity()
    if args.unit == "identity":
        print(json.dumps(policy, sort_keys=True))
    elif args.key == "complex_process_seconds":
        print(math.ceil(complex_process_seconds()))
    else:
        if args.key not in policy["watchdogs"] or not args.key.endswith("_" + args.unit):
            parser.error("Key/unit mismatch")
        print(math.ceil(policy["watchdogs"][args.key]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
