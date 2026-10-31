#!/usr/bin/env python3
"""Check bounded worldgen prerequisite parallelism without executing a compiler.

The sentinel compiler is intentionally nonexistent. These are forced cold
dry-runs only; real compilation and all nine ordered tests remain within their
original workflow command deadline.
"""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
COMPILER = "worldgen-inventory-compiler-must-not-execute"
SOURCES = ("world_generation", "generation_fields", "generation_typed_fields",
           "generation_spatial", "generation_grammar", "generation_planes")
TESTS = ("world_generation", "world_generation_install", "generation_fields",
         "generation_modifiers", "generation_typed", "generation_typed_integration",
         "generation_spatial", "generation_grammar", "generation_planes")
THREADED = frozenset(("generation_typed", "generation_typed_integration", "generation_spatial",
                      "generation_grammar", "generation_planes"))
COMMON = ("-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow", "-Inative/include")
CORE = ("world", "material_rules", "scheduler_geometry", "settled_world_discovery", "render_snapshot", "c_api")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def flags(sanitized: bool, threaded: bool, install: bool = False) -> list[str]:
    result = list(COMMON) + (["-O1", "-g"] if sanitized else ["-O2", "-g"])
    if threaded:
        result.append("-pthread")
    if sanitized:
        result += ["-fno-omit-frame-pointer", "-fsanitize=address,undefined"]
    elif not install:
        result.append("-Werror")
    return result


def expected_commands(sanitized: bool) -> dict[str, list[str]]:
    family = "sanitized" if sanitized else "normal"
    suffix = "_sanitized" if sanitized else ""
    expected: dict[str, list[str]] = {}
    for threaded in (False, True):
        folder = family + ("-threaded" if threaded else "")
        for source in SOURCES:
            output = f"build/worldgen-objects/{folder}/{source}.o"
            expected[output] = [COMPILER, *flags(sanitized, threaded), "-c",
                                f"native/src/{source}.cpp", "-o", output]
    for test in TESTS:
        threaded = test in THREADED
        folder = family + ("-threaded" if threaded else "")
        if test == "world_generation_install":
            inputs = [f"native/src/{source}.cpp" for source in CORE]
        else:
            selected = (("generation_fields",) if test == "generation_fields" else
                        ("generation_spatial",) if test == "generation_spatial" else
                        ("generation_typed_fields", "generation_spatial") if test == "generation_typed" else SOURCES)
            inputs = [f"build/worldgen-objects/{folder}/{source}.o" for source in selected]
        output = f"build/test_{test}{suffix}"
        expected[output] = [COMPILER, *flags(sanitized, threaded, test == "world_generation_install"),
                            *inputs, f"native/tests/test_{test}.cpp", "-o", output]
    return expected


def inspect_commands(text: str, sanitized: bool) -> dict:
    expected = expected_commands(sanitized)
    suffix = "_sanitized" if sanitized else ""
    compile_commands: list[list[str]] = []
    tests: list[str] = []
    outputs: set[str] = set()
    for line in text.splitlines():
        command = shlex.split(line)
        if not command:
            continue
        if command[:2] == ["mkdir", "-p"]:
            require(len(command) == 3 and command[2] in {
                "build", "build/worldgen-objects/normal", "build/worldgen-objects/normal-threaded",
                "build/worldgen-objects/sanitized", "build/worldgen-objects/sanitized-threaded",
            }, "Unexpected directory prerequisite")
        elif command[0] == COMPILER:
            require(not tests, "Compilation appears after test execution starts")
            require(command.count("-o") == 1 and command[-2] == "-o", "Malformed compiler output")
            output = command[-1]
            require(output in expected and output not in outputs, "Wrong or duplicate object/binary family")
            require(command == expected[output], "Compiler flag/source contract changed: " + output)
            outputs.add(output)
            compile_commands.append(command)
        else:
            require(len(command) == 1 and command[0].startswith("./build/test_"),
                    "Unexpected executable command in dry-run")
            tests.append(command[0])
    require(outputs == set(expected), "Missing compilation or link prerequisite")
    require(tests == [f"./build/test_{test}{suffix}" for test in TESTS],
            "Nine-test inventory/order changed")
    return {"compile_link_commands":compile_commands, "ordered_tests":tests,
            "object_count":sum(output.endswith(".o") for output in outputs),
            "binary_count":sum(not output.endswith(".o") for output in outputs)}


def compare(serial: str, bounded: str, sanitized: bool) -> dict:
    first, second = inspect_commands(serial, sanitized), inspect_commands(bounded, sanitized)
    require(Counter(map(tuple, first["compile_link_commands"])) ==
            Counter(map(tuple, second["compile_link_commands"])), "Parallel prerequisite inventory changed")
    require(first["ordered_tests"] == second["ordered_tests"], "Parallel test order changed")
    return second


def dry_run(root: Path, target: str, jobs: int) -> dict:
    require(target in {"worldgen-test", "worldgen-sanitize"} and jobs in {1, 2},
            "Unbounded or unrelated make request")
    command = ["make", "--no-print-directory", "--dry-run", "--always-make",
               f"-j{jobs}", f"CXX={COMPILER}", target]
    env = os.environ.copy()
    for variable in ("MAKEFLAGS", "MFLAGS"):
        env.pop(variable, None)
    process = subprocess.run(command, cwd=root, env=env, text=True,
                             capture_output=True, timeout=15, check=True)
    require(not process.stderr.strip(), "Unexpected make diagnostic: " + process.stderr.strip())
    return {"command":command, "stdout":process.stdout,
            "stdout_sha256":hashlib.sha256(process.stdout.encode()).hexdigest()}


def check(root: Path) -> dict:
    reports = {}
    for target in ("worldgen-test", "worldgen-sanitize"):
        serial, bounded = dry_run(root, target, 1), dry_run(root, target, 2)
        inventory = compare(serial["stdout"], bounded["stdout"], target == "worldgen-sanitize")
        reports[target] = {"serial":serial, "two_jobs":bounded, **inventory}
    return {
        "schema":"cybersand-worldgen-build-inventory-v1", "status":"passed",
        "scope":"forced cold dry-run prerequisite/flag/test-order equivalence; no compiler or test executed",
        "source_revision":subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "makefile_sha256":hashlib.sha256((root / "Makefile").read_bytes()).hexdigest(),
        "helper_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "make_version":subprocess.check_output(["make", "--version"], text=True).splitlines()[0],
        "compiler_substitution":COMPILER, "families":reports,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = check(args.root.resolve())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        report = {"status":"failed", "error":str(error)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status":report["status"],
                      "families":{name:{"objects":row["object_count"], "binaries":row["binary_count"],
                                        "ordered_tests":len(row["ordered_tests"])}
                                  for name, row in report.get("families", {}).items()},
                      "error":report.get("error", "")}))
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
