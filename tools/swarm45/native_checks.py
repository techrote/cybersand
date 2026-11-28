#!/usr/bin/env python3
"""Execute, on the target OS, all source-bound strict native and sanitizer tests."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import sys

import runtime_custody as custody
from shared import legacy

MARKERS = {
    "test_assembly": r"^SWARM004_ASSEMBLY: PASS checks=([1-9][0-9]*)$",
    "test_reciprocal_mosaic": r"^reciprocal MOSAIC tests: [1-9][0-9]* passed, 0 failed, ([1-9][0-9]*) checks$",
    "test_reciprocal": r"^reciprocal checks=([1-9][0-9]*) both=[1-9][0-9]* joints=[1-9][0-9]* complete=[0-9]+$",
    "test_swarm005": r"^SWARM005_NATIVE_PILOT: PASS tests=([1-9][0-9]*)/\1 assertions=([1-9][0-9]*)$",
    "test_swarm006_source": r"^SWARM006_SOURCE_OPPORTUNITIES: PASS tests=([1-9][0-9]*)/\1 assertions=([1-9][0-9]*)$",
    "test_swarm006_admission": r"^recovery admission tests: [1-9][0-9]* passed, 0 failed, ([1-9][0-9]*) assertions$",
    "test_custody_hash": r"^custody hash: ([1-9][0-9]*) assertions PASS$",
    "test_swarm006_recovery": r"^SWARM006 recovery: [1-9][0-9]* groups passed, 0 failed; ([1-9][0-9]*) assertions$",
    "test_workbench_authoring_patch": r"^WORKBENCH_AUTHORING_PATCH_NATIVE checks=([1-9][0-9]*) failures=0$",
}
SANITIZER_ERRORS = re.compile(r"AddressSanitizer:|LeakSanitizer:|UndefinedBehaviorSanitizer:|runtime error:")


def marker_valid(name: str, text: str) -> bool:
    return len(re.findall(MARKERS[name], text, re.MULTILINE)) == 1 and not SANITIZER_ERRORS.search(text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    runtime, output = args.runtime.resolve(), args.output.resolve()
    receipt = custody.verify(runtime)
    platform = "windows" if os.name == "nt" else "linux"
    custody.require(receipt["platform"] == platform, "Native tests must execute on their actual target OS")
    custody.require(not output.exists() or not any(output.iterdir()), "Native evidence must be new")
    output.mkdir(parents=True, exist_ok=True)
    floor = None
    if platform == "linux":
        import linux_floor
        floor = linux_floor.inspect([runtime / receipt["extension"], runtime / receipt["cli"]], output)
        custody.write_json(output / "linux-runtime-floor.json", floor)
    env = dict(os.environ, ASAN_OPTIONS="detect_leaks=1:strict_string_checks=1:halt_on_error=1",
               UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1")
    results = []
    for mode in ("strict", "sanitized") if platform == "linux" else ("strict",):
        for logical, binary in zip(custody.NATIVE_TESTS, receipt["tests"]):
            relative = binary if mode == "strict" else "sanitized/" + binary
            target = runtime / relative
            if platform == "linux":
                target.chmod(target.stat().st_mode | 0o111)
            label = mode + "-" + logical
            result = legacy.execute(label, [str(target)], env, output, 180)
            text = (output / (label + ".log")).read_text(encoding="utf-8", errors="replace")
            errors = [] if marker_valid(logical, text) else ["Missing complete native assertions or sanitizer diagnostics present"]
            result.update(binary_sha256=custody.sha(target), mode=mode)
            results.append(legacy.validate_result(result, errors, output))
    transport = (
        ("v1-v2-request", [sys.executable, str(custody.ROOT / "native/experiments/gentek_swarm/test_reciprocal_io.py"),
                           "--binary", str(runtime / receipt["cli"]), "-v"]),
        ("v3-request", [sys.executable, str(custody.ROOT / "tools/swarm005/test_v3_request.py"),
                         "--exe", str(runtime / receipt["cli"]), "--output", str(output / "v3")]),
        ("v4-request", [sys.executable, str(custody.ROOT / "tools/swarm006/test_v4_request.py"),
                         "--exe", str(runtime / receipt["cli"]), "--output", str(output / "v4"),
                         "--source", receipt["source_commit"]]),
    )
    for label, command in transport:
        result = legacy.execute(label, command, env, output, 180)
        text = (output / (label + ".log")).read_text(encoding="utf-8", errors="replace")
        errors = []
        if label == "v1-v2-request" and (not re.search(r"Ran [1-9][0-9]* tests? in", text) or "skipped" in text.lower() or not re.search(r"^OK$", text, re.MULTILINE)):
            errors.append("V1/V2 transport tests did not execute their complete real-binary inventory")
        result.update(binary_sha256=receipt["files"][receipt["cli"]]["sha256"],
                      test_script_sha256=custody.sha(Path(command[1])))
        results.append(legacy.validate_result(result, errors, output))
    expected = len(custody.NATIVE_TESTS) * (2 if platform == "linux" else 1) + len(transport)
    passed = len(results) == expected and all(record["passed"] for record in results)
    summary = {"schema": 1, "programme": custody.PROGRAMME, "source_commit": receipt["source_commit"],
               "source_tree": receipt["source_tree"], "build_context": receipt["build_context"],
               "runtime_manifest_sha256": custody.sha(runtime / custody.NAME), "platform": platform,
               "strict_tests": list(custody.NATIVE_TESTS), "sanitizers": ["address", "undefined"] if platform == "linux" else [],
               "passed": passed, "linux_runtime_floor": floor, "results": results, "files_sha256": custody.inventory(output)}
    custody.write_json(output / "native-qualification.json", summary)
    print({"platform": platform, "passed": passed, "cases": len(results)})
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
