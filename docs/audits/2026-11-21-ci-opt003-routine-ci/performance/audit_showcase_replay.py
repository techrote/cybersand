#!/usr/bin/env python3
"""Supplement the frozen runtime proof reader with byte-exact showcase replay coupling."""
import argparse
from collections import Counter
from functools import lru_cache
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

CANDIDATE = "19023b4016facfda2b13b9a1503742e4a9fe1982"
PROOF = "cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147"
COMMON_PATH = "tools/ci/ci_opt003_worldgen_runtime_proof/common.py"
COMMON_DIGEST = "8263b339bde686eb41dc3d4de1471ecbe60ac79e47b0b5075b269b6018c750d4"
DEFAULT_REPOSITORY = Path(__file__).resolve().parents[2] / "cybersand"
SHOWCASES = ("megatruss_station", "seeded_typology_megablock", "metabolist_spine",
             "interlaced_viaduct", "rosework_gatehouse", "interlock_brutalism", "suspended_arcology")
FAILURES = (b"[fail]", b"ERROR: AddressSanitizer", b"SUMMARY: AddressSanitizer",
            b"WARNING: ThreadSanitizer", b"SUMMARY: ThreadSanitizer", b"runtime error:")

@lru_cache(maxsize=4)
def source_contract(repository):
    """Read immutable Git source, never code or boundary declarations from an artifact."""
    def blob(revision, path):
        return subprocess.check_output(["git", "-C", str(repository), "show", revision + ":" + path], timeout=300)

    raw = blob(PROOF, COMMON_PATH)
    if hashlib.sha256(raw).hexdigest() != COMMON_DIGEST:
        raise ValueError("Frozen source contract differs")
    with tempfile.TemporaryDirectory(prefix="showcase-source-contract-") as temporary:
        path = Path(temporary) / "frozen_common.py"
        path.write_bytes(raw)
        spec = importlib.util.spec_from_file_location("ci003_frozen_showcase_contract", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with module.canonical(repository, "candidate") as verifier:
            expected = module.contract(repository, "candidate", verifier)
    if expected["source"]["source_sha"] != CANDIDATE:
        raise ValueError("Unexpected immutable source")
    text = blob(CANDIDATE, "Makefile").decode()
    directories = set()
    for targets, recipe in re.findall(r"^([^\n]+):\n\tmkdir -p (\$@|\$\(BUILD_DIR\))\n", text, re.M):
        if recipe == "$(BUILD_DIR)":
            directories.add("build")
        else:
            directories.update(targets.replace("$(BUILD_DIR)", "build").split())
    required_dirs = {"build", *("build/worldgen-objects/" + name for name in
                               ("normal", "normal-threaded", "sanitized", "sanitized-threaded"))}
    if not required_dirs.issubset(directories):
        raise ValueError("Original Make directory prerequisite recipes differ")
    return expected, required_dirs


def audit(directory, run_id, attempt, repository=None):
    if type(run_id) is not int or run_id <= 0 or type(attempt) is not int or attempt <= 0:
        raise ValueError("Invalid expected run identity")
    expected, directories = source_contract((repository or DEFAULT_REPOSITORY).resolve())
    root = directory / "candidate/source/build"
    results = []
    for target, suffix in (("worldgen-test", ""), ("worldgen-sanitize", "_sanitized")):
        replay_path = root / "native-parallel/worldgen/commands" / target / "command.log"
        if not replay_path.is_file() or replay_path.is_symlink():
            raise ValueError("Missing/nonregular target replay")
        replay = replay_path.read_bytes()
        lines = replay.splitlines(keepends=True)
        headers = {"test_" + name + suffix:
                   f"source_sha={CANDIDATE} run_id={run_id} run_attempt={attempt} binary=test_{name}{suffix}\n".encode()
                   for name in SHOWCASES}
        observed_headers = [line for line in lines if line.startswith(b"source_sha=")]
        if Counter(observed_headers) != Counter(headers.values()):
            raise ValueError("Wrong context, duplicate context, or incomplete showcase replay headers")
        marker_prefix = b"Running sanitized " if suffix else b"Running "
        markers = {binary: marker_prefix + b"build/" + binary.encode() + b"\n" for binary in headers}
        if any(lines.count(marker) != 1 for marker in markers.values()):
            raise ValueError("Missing or duplicate source-derived Running marker")
        # GNU Make --output-sync=target keeps a showcase recipe's echo and cat
        # together. The next complete target can be another showcase, a compiler
        # (with following diagnostics), a directory recipe, or the main test tail.
        # Stop at exact immutable source-derived command lines, not generic text
        # prefixes or the raw file's length: a truncated raw prefix must fail.
        compiler_lines = {shlex.join(command).encode() + b"\n"
                          for command in expected["compiler_commands"][target].values()}
        directory_lines = {b"mkdir -p " + name.encode() + b"\n" for name in directories}
        first_main = expected["tests"][target]["ordered_main_tests"][0].encode() + b"\n"
        if lines.count(first_main) != 1:
            raise ValueError("Missing or duplicate first main-test boundary")
        main_index = lines.index(first_main)
        boundaries = compiler_lines | directory_lines | set(markers.values()) | {first_main}
        for name in SHOWCASES:
            binary = "test_" + name + suffix
            path = root / "worldgen-showcase-logs" / (binary + ".log")
            if not path.is_file() or path.is_symlink():
                raise ValueError("Missing/nonregular original showcase log")
            raw = path.read_bytes()
            header = headers[binary]
            if not raw.startswith(header) or len(raw) <= len(header):
                raise ValueError("Wrong context or empty original showcase output")
            if any(marker in raw for marker in FAILURES):
                raise ValueError("Failure marker in original showcase log")
            start = lines.index(header)
            if start == 0 or lines[start - 1] != markers[binary] or start >= main_index:
                raise ValueError("Original showcase header is outside its source-derived recipe group")
            end = next((index for index in range(start + 1, len(lines)) if lines[index] in boundaries), None)
            if end is None or b"".join(lines[start:end]) != raw:
                raise ValueError("Original showcase payload differs from the complete replay group")
            results.append({"target": target, "binary": binary, "bytes": len(raw),
                            "sha256": hashlib.sha256(raw).hexdigest(), "replay_count": 1,
                            "complete_group": True})
    return {"schema": "ci-opt003-independent-showcase-replay-v2", "status": "passed",
            "candidate_sha": CANDIDATE, "run_id": run_id, "run_attempt": attempt,
            "source_contract_proof_sha": PROOF, "source_contract_sha256": COMMON_DIGEST,
            "logs": results, "scope": "Supplement only; canonical paired-family admission remains required."}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--run-attempt", type=int, required=True)
    parser.add_argument("--repository", type=Path, default=DEFAULT_REPOSITORY)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.directory, args.run_id, args.run_attempt, args.repository)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print("passed: 14 original showcase payloads match complete target replay exactly once")

