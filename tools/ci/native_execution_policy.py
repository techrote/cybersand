#!/usr/bin/env python3
"""Derive complete Native family and hosted-job budgets from shared watchdogs."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from execution_policy import identity

PHYSICS_INVOCATIONS = 154
PHYSICS_DISPATCH_WORKERS = 8
MAX_HOSTED_JOB_MINUTES = 360

ASAN = ["env", "ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1", "UBSAN_OPTIONS=halt_on_error=1"]
# The twenty accepted invocations, in source order. This independent inventory
# prevents a changed shell wrapper from silently reducing qualification work.
COMMANDS = {
    "tsan": [
        ("build-tests-tsan", "native_compile_seconds", ["make", "build/tests_tsan"]),
        ("tests-tsan", "native_case_seconds", ["env", "TSAN_OPTIONS=halt_on_error=1", "./build/tests_tsan"]),
    ],
    "native-normal": [
        ("c-header-check", "operation_seconds", ["make", "c-header-check"]),
        ("build-tests", "native_compile_seconds", ["make", "build/tests"]),
        ("tests", "native_case_seconds", ["./build/tests"]),
        ("shared", "native_compile_seconds", ["make", "shared"]),
        ("build-benchmark", "native_compile_seconds", ["make", "build/benchmark"]),
        ("benchmark", "native_case_seconds", ["./build/benchmark"]),
    ],
    "asan-ubsan": [
        ("build-tests-sanitized", "native_compile_seconds", ["make", "build/tests_sanitized"]),
        ("tests-sanitized", "native_case_seconds", [*ASAN, "./build/tests_sanitized"]),
    ],
    "worldgen": [
        ("physics-characterisation-sanitize", "native_case_seconds", [
            "env", "ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1",
            "UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1", "make", "physics-characterisation-sanitize"]),
        ("worldgen-test", "native_case_seconds", ["/usr/bin/time", "-v", "make", "-j2", "worldgen-test"]),
        ("worldgen-sanitize", "native_case_seconds", [*ASAN, "/usr/bin/time", "-v", "make", "-j2", "worldgen-sanitize"]),
    ],
    "soliding-normal": [
        (target, "native_case_seconds", ["make", target]) for target in (
            "soliding-test", "soliding-benchmark-smoke",
            "soliding-stage3b-validation-apparatus-test", "soliding-stage3-cost-smoke")
    ],
    "soliding-asan": [
        ("build-settled-regions-sanitized", "native_compile_seconds", [
            "/usr/bin/time", "-v", "make", "build/test_settled_regions_sanitized"]),
        ("build-soliding-sanitized", "native_compile_seconds", ["make", *[
            f"build/test_{name}_sanitized" for name in (
                "soliding_lifecycle", "settled_discovery", "settled_regions",
                "settled_world_discovery", "stage3b_runtime_storage", "stage3b_bounded_spatial_index",
                "stage3b_sparse_mutation_witness", "stage3b_sparse_activity_deadline",
                "solid_detachment", "conservative_displacement")]]),
        ("soliding-sanitize", "native_case_seconds", [*ASAN, "make", "soliding-sanitize"]),
    ],
}


def _values(policy=None):
    return (identity() if policy is None else policy)["watchdogs"]


def command_timeout_seconds(suite, label, policy=None):
    values = _values(policy)
    key = next(key for name, key, _ in COMMANDS[suite] if name == label)
    if suite == "worldgen" and label == "physics-characterisation-sanitize":
        waves = math.ceil(PHYSICS_INVOCATIONS / PHYSICS_DISPATCH_WORKERS)
        return math.ceil(max(values[key], values["native_compile_seconds"]
                             + waves * values["operation_seconds"]
                             + values["aggregate_headroom_seconds"]))
    return math.ceil(values[key])


def family_timeout_seconds(suite, policy=None):
    values = _values(policy)
    cleanup = values["diagnostic_capture_seconds"] + values["terminate_grace_seconds"]
    children = sum(command_timeout_seconds(suite, label, policy) + cleanup
                   for label, _, _ in COMMANDS[suite])
    return math.ceil(max(values["native_suite_seconds"],
                         children + values["aggregate_headroom_seconds"]))


def hosted_job_minutes(suite, policy=None):
    values = _values(policy)
    preparation_and_capture = sum(values[key] for key in (
        "dependency_prepare_seconds", "aggregate_headroom_seconds",
        "diagnostic_capture_seconds", "terminate_grace_seconds"))
    return math.ceil(max(values["hosted_job_minutes"],
                         (family_timeout_seconds(suite, policy) + preparation_and_capture) / 60))


def budget_inventory(policy=None):
    policy = identity() if policy is None else policy
    families = {}
    for suite, commands in COMMANDS.items():
        families[suite] = {
            "commands": [{"label": label, "policy_key": key, "command": command,
                          "timeout_seconds": command_timeout_seconds(suite, label, policy)}
                         for label, key, command in commands],
            "family_timeout_seconds": family_timeout_seconds(suite, policy),
            "hosted_job_minutes": hosted_job_minutes(suite, policy),
        }
    return {"schema": "native-execution-budgets-v1", "execution_policy": policy,
            "physics_invocations": PHYSICS_INVOCATIONS,
            "physics_dispatch_workers": PHYSICS_DISPATCH_WORKERS,
            "physics_dispatch_waves": math.ceil(PHYSICS_INVOCATIONS / PHYSICS_DISPATCH_WORKERS),
            "families": families}


def matrix(policy=None):
    inventory = budget_inventory(policy)
    rows = []
    for suite, row in inventory["families"].items():
        if row["hosted_job_minutes"] > MAX_HOSTED_JOB_MINUTES:
            raise ValueError("Native execution allowance exceeds the supported hosted job limit: " + suite)
        rows.append({"suite": suite, "job_minutes": row["hosted_job_minutes"],
                     "family_seconds": row["family_timeout_seconds"]})
    return {"include": rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("command-seconds", "family-seconds", "matrix", "inventory"))
    parser.add_argument("suite", nargs="?", choices=tuple(COMMANDS))
    parser.add_argument("label", nargs="?")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.operation == "command-seconds":
        if args.suite is None or args.label not in {label for label, _, _ in COMMANDS[args.suite]}:
            parser.error("A registered Native suite and command label are required")
        result = command_timeout_seconds(args.suite, args.label)
    elif args.operation == "family-seconds":
        if args.suite is None:
            parser.error("A registered Native suite is required")
        result = family_timeout_seconds(args.suite)
    elif args.operation == "matrix":
        result = matrix()
    else:
        result = budget_inventory()
    output = json.dumps(result, separators=(",", ":"))
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output + "\n", encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
