#!/usr/bin/env python3
"""Source-locked, process-isolated sanitizer coverage for PR #290.

This helper is a *verification-only* harness, never an engine source or
runtime publisher. It shatters the 165-test registry into disjoint, fixed
index shards; each test is run by its exact registered filter, and the final
reducer checks the union of 165 labels and the immutable binary identity.

The test executable's historical CLI is substring-based, so additional
matching labels are permitted but recorded; every requested label MUST pass.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

EXPECTED_TESTS = 165
EXPECTED_WORLD_BLOB = "a6afd8cad4264ac2eca0362d14711158e3606760"
EXPECTED_TEST_BLOB = "5613d2166c71fa49fd2b8f65e8caa93857b5d65f"
EXPECTED_NATIVE_SOURCE = "60915dc86631271ea8661377a3458149adda9361"
SHARDS = 4
REGISTRY = Path("native/tests/test_world.cpp")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def test_names() -> list[str]:
    text = REGISTRY.read_text(encoding="utf-8")
    match = re.search(r"const Test tests\[\]\s*=\s*\{(.*?)^\s*\};", text, re.S | re.M)
    if not match:
        raise RuntimeError("Cannot locate native test registration")
    names = re.findall(r'\{\s*"([^"]+)"\s*,\s*[A-Za-z_][A-Za-z_0-9]*\s*\}', match[1])
    if len(names) != EXPECTED_TESTS or len(names) != len(set(names)):
        raise RuntimeError(f"Expected exactly {EXPECTED_TESTS} unique native tests; got {len(names)}")
    return names


def check_source() -> dict:
    source_head = git("rev-parse", "HEAD")
    # A single workflow/helper-only descendant of the known corrected source.
    base = git("merge-base", "HEAD", EXPECTED_NATIVE_SOURCE)
    if base != EXPECTED_NATIVE_SOURCE:
        raise RuntimeError("Branch is not descended from the frozen corrected source")
    files = git("diff", "--name-only", EXPECTED_NATIVE_SOURCE, "HEAD").splitlines()
    allowed = {
        ".github/workflows/render-copy-290-sanitizer-shards.yml",
        "tools/ci/render_copy_290_sanitizer_shard.py",
        # The frozen PR-head successor carries source-matched evidence only.
        "docs/audits/2026-10-28-render-copy-per-run.md",
        "docs/audits/2026-10-29-render-copy-int64-qualification-receipt.json",
        "docs/reference/validation-evidence.md",
    }
    if set(files) != allowed:
        raise RuntimeError("Non-harness delta against source: " + repr(files))
    blobs = {
        path: git("hash-object", path)
        for path in ("native/src/world.cpp", "native/tests/test_world.cpp")
    }
    if blobs["native/src/world.cpp"] != EXPECTED_WORLD_BLOB or blobs["native/tests/test_world.cpp"] != EXPECTED_TEST_BLOB:
        raise RuntimeError("Corrected native source or test changed from review freeze")
    return {"execution_source": EXPECTED_NATIVE_SOURCE, "verification_head": source_head,
            "source_tree": git("rev-parse", EXPECTED_NATIVE_SOURCE + "^{tree}"),
            "source_blobs": blobs, "harness_delta": files}


def registry_document() -> dict:
    names = test_names()
    return {"schema": "cybersand.render-copy290-sharded-sanitizer-registry.v1",
            "source": check_source(), "names": names, "count": len(names),
            "registry_sha256": digest("\n".join(names).encode())}


def one_test(binary: Path, name: str, timeout: int) -> dict:
    start = time.monotonic()
    output = ""
    rc = None
    try:
        task = subprocess.run([str(binary.resolve()), name],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, encoding="utf-8", errors="replace", timeout=timeout)
        output = task.stdout
        rc = task.returncode
    except subprocess.TimeoutExpired as err:
        output = (err.stdout or b"").decode("utf-8", "replace") if isinstance(err.stdout, bytes) else (err.stdout or "")
        rc = "timeout"
    elapsed_ms = round((time.monotonic() - start) * 1000, 3)
    passes = re.findall(r"^\[pass\] (.+)$", output, flags=re.M)
    bad = bool(re.search(r"(?m)^\[fail\]|runtime error:|AddressSanitizer|UndefinedBehaviorSanitizer|SUMMARY: UndefinedBehaviorSanitizer", output))
    ok = rc == 0 and name in passes and not bad
    return {"requested": name, "returncode": rc, "passed": ok, "observed_passes": passes,
            "elapsed_ms": elapsed_ms, "stdout_sha256": digest(output.encode()), "stdout": output}


def run_shard(args):
    names = test_names()
    identity = check_source()
    if not (0 <= args.shard < SHARDS):
        raise RuntimeError("Out-of-range shard")
    binary = args.binary.resolve()
    if not binary.is_file():
        raise RuntimeError("Sanitizer binary not found")
    target = names[args.shard::SHARDS]
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(args.build_manifest.read_text(encoding="utf-8"))
    if manifest["source"] != identity["execution_source"] or manifest["binary_sha256"] != digest(binary.read_bytes()):
        raise RuntimeError("Source/bin archive mismatch before running")
    results = []
    for index, name in enumerate(target):
        result = one_test(binary, name, args.per_test_timeout)
        (out / f"test-{index:03d}.txt").write_text(result.pop("stdout"), encoding="utf-8")
        results.append(result)
        print(f"[{args.shard}:{index}/{len(target)}] {name} -> {result['returncode']}, {result['elapsed_ms']}ms", flush=True)
        if not result["passed"]:
            break
    report = {"schema": "cybersand.render-copy290-sanitizer-shard.v1",
              "source": identity["execution_source"], "verification_head": identity["verification_head"],
              "binary_sha256": manifest["binary_sha256"], "shard": args.shard,
              "shards": SHARDS, "expected_names": target, "test_names_sha256": digest("\n".join(names).encode()),
              "results": results, "completed_all": len(results) == len(target) and all(r["passed"] for r in results)}
    (out / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if not report["completed_all"]:
        raise RuntimeError(f"Shard {args.shard} failed after {len(results)} / {len(target)} test invocations")


def aggregate(args):
    names = test_names()
    identity = check_source()
    reports = []
    selected = []
    all_observed = set()
    binary_hashes = set()
    for shard in range(SHARDS):
        path = args.input / f"shard-{shard}" / "report.json"
        report = json.loads(path.read_text(encoding="utf-8"))
        target = names[shard::SHARDS]
        results = report["results"]
        if (report["source"] != identity["execution_source"] or report["shard"] != shard
            or report["shards"] != SHARDS or report["expected_names"] != target
            or len(results) != len(target) or not report["completed_all"]
            or [r["requested"] for r in results] != target
            or any(not r["passed"] for r in results)):
            raise RuntimeError(f"Shard {shard} source, coverage, or success mismatch")
        binary_hashes.add(report["binary_sha256"])
        selected.extend(r["requested"] for r in results)
        for r in results:
            all_observed.update(r["observed_passes"])
        reports.append({"shard": shard, "tests": len(results),
                        "elapsed_ms_sum": round(sum(r["elapsed_ms"] for r in results), 3),
                        "max_case_ms": max(r["elapsed_ms"] for r in results)})
    if len(binary_hashes) != 1 or len(selected) != EXPECTED_TESTS or set(selected) != set(names) or set(all_observed) != set(names):
        raise RuntimeError("All-test sanitizer coverage/identity mismatch")
    result = {"schema":"cybersand.render-copy290-all-test-sanitizer.v1",
              "source":identity, "count":EXPECTED_TESTS, "binary_sha256": next(iter(binary_hashes)),
              "shards":reports, "all_tests_covered":True,
              "test_names_sha256":digest("\n".join(names).encode()),
              "qualification":"all 165 named test functions executed under ASan+UBSan in isolated processes; not the old monolithic single-process runner"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(json.dumps(result, sort_keys=True))


def main():
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest="command", required=True)
    reg=sub.add_parser("registry")
    reg.add_argument("--output", type=Path, required=True)
    run=sub.add_parser("run")
    run.add_argument("--shard", type=int, required=True)
    run.add_argument("--binary", type=Path, required=True)
    run.add_argument("--build-manifest", type=Path, required=True)
    run.add_argument("--output", type=Path, required=True)
    run.add_argument("--per-test-timeout", type=int, default=300)
    agg=sub.add_parser("aggregate")
    agg.add_argument("--input", type=Path, required=True)
    agg.add_argument("--output", type=Path, required=True)
    args=parser.parse_args()
    if args.command=="registry":
        doc=registry_document()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(doc, indent=2, sort_keys=True)+"\n", encoding="utf-8")
        print(f"Verified {doc['count']} registry entries at frozen source")
    elif args.command=="run": run_shard(args)
    else: aggregate(args)


if __name__=="__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError, KeyError) as error:
        print("RENDER_COPY290_SHARD_FAILURE: "+str(error), file=sys.stderr)
        sys.exit(1)
