#!/usr/bin/env python3
"""Verify soliding object reuse preserves the original expanded compiler contract.

Uses forced-cold make dry-runs with a deliberately nonexistent compiler. The
configuration helper is printed as a recipe, never executed during this check.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
COMPILER = "soliding-inventory-compiler-must-not-execute"
CORE = ("world", "material_rules", "scheduler_geometry", "settled_world_discovery", "render_snapshot", "c_api")
TESTS = ("soliding_lifecycle", "settled_discovery", "settled_regions", "settled_world_discovery",
         "stage3b_runtime_storage", "stage3b_bounded_spatial_index", "stage3b_sparse_mutation_witness",
         "stage3b_sparse_activity_deadline")
HEADER_ONLY = {"soliding_lifecycle", "settled_regions"}
COMMON = ["-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow", "-Inative/include"]
ATOMIC = re.compile(r'^set -eu; temporary="([^" ]+)\.tmp\.\$\$"; trap \'rm -f "\$temporary"\' EXIT; '
                    r"trap 'exit 129' HUP; trap 'exit 130' INT; trap 'exit 143' TERM; +"
                    + COMPILER + r' (.+); +mv -f "\$temporary" "([^" ]+)"$')


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def expected_flags(sanitized: bool) -> list[str]:
    return COMMON + (["-O1", "-g", "-fno-omit-frame-pointer", "-fsanitize=address,undefined"]
                     if sanitized else ["-O0", "-g3"])


def original_contract(sanitized: bool) -> dict[str, list[str]]:
    suffix = "_sanitized" if sanitized else ""
    return {f"build/test_{name}{suffix}": [COMPILER, *expected_flags(sanitized),
            *([] if name in HEADER_ONLY else [f"native/src/{source}.cpp" for source in CORE]),
            f"native/tests/test_{name}.cpp", "-o", f"build/test_{name}{suffix}"] for name in TESTS}


def inspect(text: str, sanitized: bool) -> dict:
    family = "sanitized" if sanitized else "normal"
    suffix = "_sanitized" if sanitized else ""
    flags = expected_flags(sanitized)
    objects = {}
    links = {}
    tests = []
    configurations = 0
    for line in text.replace("\\\n", " ").splitlines():
        atomic = ATOMIC.fullmatch(line)
        if atomic:
            output, command, published = atomic.groups()
            require(output == published and output not in objects, "Wrong/duplicate atomic object publication")
            argv = shlex.split(command)
            name = Path(output).stem
            require(name in CORE and output == f"build/soliding-objects/{family}/{name}.o", "Wrong object profile")
            require(argv == [*flags, "-c", f"native/src/{name}.cpp", "-o", "$temporary"], "Object flags/source changed")
            objects[output] = f"native/src/{name}.cpp"
            continue
        argv = shlex.split(line)
        if not argv:
            continue
        if argv == ["mkdir", "-p", "build"]:
            continue
        if argv == ["python3", "tools/ci/native_build_configuration.py", "--output",
                    f"build/soliding-objects/{family}/configuration.json"]:
            configurations += 1
            continue
        if argv[0] == COMPILER:
            require(not tests and argv.count("-o") == 1 and argv[-2] == "-o", "Malformed/late link command")
            output = argv[-1]
            require(output not in links, "Duplicate test link")
            expanded = []
            for argument in argv:
                if argument.endswith(".o"):
                    require(argument in objects, "Link uses an absent or incompatible object")
                expanded.append(objects.get(argument, argument))
            links[output] = expanded
            continue
        require(len(argv) == 1 and argv[0].startswith("./build/test_"), "Unexpected build recipe: " + line)
        tests.append(argv[0])
    require(configurations == 1, "Compiler configuration guard missing/duplicated")
    require(set(objects.values()) == {f"native/src/{name}.cpp" for name in CORE}, "Missing core object")
    require(links == original_contract(sanitized), "Expanded original compile/link contract changed")
    require(tests == [f"./build/test_{name}{suffix}" for name in TESTS], "Eight-test execution order changed")
    return {"objects": objects, "expanded_original_commands": links, "ordered_tests": tests,
            "original_translation_unit_compilations": 44, "candidate_translation_unit_compilations": 14,
            "eliminated_translation_unit_compilations": 30}


def check(root: Path = ROOT) -> dict:
    env = os.environ.copy()
    env.pop("MAKEFLAGS", None)
    env.pop("MFLAGS", None)
    report = {}
    for target in ("soliding-test", "soliding-sanitize"):
        command = ["make", "--no-print-directory", "--dry-run", "--always-make", f"CXX={COMPILER}", target]
        run = subprocess.run(command, cwd=root, env=env, text=True, capture_output=True, check=True, timeout=30)
        require(not run.stderr, "Unexpected make diagnostic: " + run.stderr)
        report[target] = {"command": command, "dry_run_sha256": hashlib.sha256(run.stdout.encode()).hexdigest(),
                          **inspect(run.stdout, target.endswith("sanitize"))}
    return {"schema": "cybersand-soliding-build-inventory-v1", "status": "passed",
            "scope": "Cold dry-run build contract only; no compilation or tests executed",
            "makefile_sha256": hashlib.sha256((root / "Makefile").read_bytes()).hexdigest(), "families": report}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = check()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        result = {"status": "failed", "error": str(error)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "error": result.get("error", "")}))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
