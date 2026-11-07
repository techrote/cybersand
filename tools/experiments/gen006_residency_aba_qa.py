#!/usr/bin/env python3
"""GEN006 QA: compile actual shared World and reject replayed old residency ACK.

This is the independent fail-closed acceptance for the protected #512 source.
Exit 1 while the ABA defect remains; preserve the original negative results.
It is deliberately not a synthetic World model or a production implementation.
"""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "build" / "gen006-source-parity" / "residency-aba"
OUTPUT.mkdir(parents=True, exist_ok=True)
SOURCES = [
    "native/src/world.cpp", "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp", "native/src/settled_world_discovery.cpp",
    "native/src/world_generation.cpp", "native/src/generation_fields.cpp",
    "native/src/generation_typed_fields.cpp", "native/src/generation_spatial.cpp",
    "native/src/generation_grammar.cpp", "native/src/generation_planes.cpp",
]

def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args],
                                   text=True).strip()

def main() -> None:
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("EXPECTED_HEAD", "").strip()
    if head != expected:
        raise RuntimeError(f"GEN006_ABA_SOURCE_ID_MISMATCH {head} != {expected}")
    compiler = os.getenv("GEN006_CXX") or ("clang++" if os.name == "nt" else "g++-13")
    binary = OUTPUT / ("aba.exe" if os.name == "nt" else "aba")
    receipt = {
        "head": head,
        "tree": git("rev-parse", "HEAD^{tree}"),
        "native_world_blob": git("hash-object", "native/src/world.cpp"),
        "checkpoint_blob": git("hash-object", "native/src/world_chunk_checkpoint.inc"),
        "test_blob": git("hash-object", "native/tests/gen006_residency_ack_aba.cpp"),
        "compiler": subprocess.check_output([compiler, "--version"],
                                           text=True).splitlines()[0],
        "platform": platform.platform(),
        "expected": "previously durable A ACK must not evict distinct native residency B",
    }
    (OUTPUT / "source.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                         encoding="utf-8")
    args = [compiler, "-std=c++20", "-O0", "-g0",
            "-I", str(ROOT / "native/include")]
    if os.name != "nt":
        args += ["-pthread"]
    args += [str(ROOT / p) for p in SOURCES]
    args += [str(ROOT / "native/tests/gen006_residency_ack_aba.cpp"),
             "-o", str(binary)]
    with (OUTPUT / "compile.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(args, stdout=log, stderr=subprocess.STDOUT,
                                timeout=1600)
    if result.returncode:
        raise RuntimeError("GEN006_ABA_COMPILE_FAILED " +
                           (OUTPUT / "compile.log").read_text(
                               encoding="utf-8", errors="replace")[-3000:])
    failures = []
    for workers in (1, 4):
        root = OUTPUT / f"saved-{workers}"
        run = subprocess.run([str(binary), str(root), str(workers)],
                             capture_output=True, text=True, errors="replace",
                             timeout=200)
        (OUTPUT / f"native-{workers}.stdout").write_text(
            run.stdout, encoding="utf-8")
        (OUTPUT / f"native-{workers}.stderr").write_text(
            run.stderr, encoding="utf-8")
        print(run.stdout, end="")
        print(run.stderr, end="", file=sys.stderr)
        if run.returncode:
            failures.append(f"workers={workers} return={run.returncode}")
    (OUTPUT / "disposition.json").write_text(json.dumps({
        "failed": failures,
        "gate": "GEN006_RESIDENCY_INCARCATION_FENCE",
        "source": head,
        "test": "real native ACK(A), evict(A), restore(B), replay ACK(A), protect B",
    }, indent=2) + "\n", encoding="utf-8")
    if failures:
        raise RuntimeError("GEN006_RESIDENCY_ABA_ACCEPTANCE_FAIL: " +
                           ", ".join(failures))
    print("GEN006_RESIDENCY_ABA_ACCEPTANCE_PASS real_native=1 workers=1,4")

if __name__ == "__main__":
    main()
