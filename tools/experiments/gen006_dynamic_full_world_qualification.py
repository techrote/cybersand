#!/usr/bin/env python3
"""GEN-006 real native signed-seam CYPS continuation, no protected source edit.

Run only from the checked-out PR exact head. Compiles native production World,
not a mock or independently reimplemented physics model. Original compiler,
stdout/stderr and source/build identities remain under build/gen006-dynamic.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "build" / "gen006-dynamic"
SOURCES = [
    "native/src/world.cpp",
    "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp",
    "native/src/settled_world_discovery.cpp",
    "native/src/world_generation.cpp",
    "native/src/generation_fields.cpp",
    "native/src/generation_typed_fields.cpp",
    "native/src/generation_spatial.cpp",
    "native/src/generation_grammar.cpp",
    "native/src/generation_planes.cpp",
    "native/tests/gen006_dynamic_full_world_continuation.cpp",
]
OWNED = [
    "native/include/cybersand/gen006_dynamic_full_world_stage.hpp",
    "native/include/cybersand/gen006_dynamic_bundle_admission.hpp",
    "native/tests/gen006_dynamic_full_world_continuation.cpp",
    "tools/experiments/gen006_dynamic_full_world_qualification.py",
    ".github/workflows/gen006-dynamic-full-world-continuation.yml",
]


def git(*arguments: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *arguments], text=True).strip()


def hash_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("EXPECTED_HEAD", "").strip()
    if not expected or head != expected:
        raise RuntimeError(f"exact candidate HEAD required: observed={head}, expected={expected}")
    compiler = os.environ.get("GEN006_CXX") or ("clang++" if os.name == "nt" else "g++-13")
    exe = OUTPUT / ("gen006-dynamic.exe" if os.name == "nt" else "gen006-dynamic")
    command = [compiler, "-std=c++20", "-O0", "-g0", "-I", str(ROOT / "native" / "include")]
    if os.name != "nt":
        command += ["-pthread"]
    command += [str(ROOT / path) for path in SOURCES]
    command += ["-o", str(exe)]
    compile_log = OUTPUT / "compile.log"
    with compile_log.open("w", encoding="utf-8") as f:
        compiled = subprocess.run(command, stdout=f, stderr=subprocess.STDOUT,
                                  timeout=1600, check=False)
    if compiled.returncode:
        print(compile_log.read_text(encoding="utf-8", errors="replace")[-16000:], file=sys.stderr)
        raise RuntimeError(f"native compilation failed: {compiled.returncode}")
    receipt = {
        "commit": head,
        "tree": git("rev-parse", "HEAD^{tree}"),
        "world_cpp_blob": git("hash-object", "native/src/world.cpp"),
        "world_hpp_blob": git("hash-object", "native/include/cybersand/world.hpp"),
        "compiler": subprocess.check_output([compiler, "--version"], text=True).splitlines()[0],
        "os": platform.platform(),
        "native_binary_sha256": hash_file(exe),
        "sources": {p: git("hash-object", p) for p in SOURCES + OWNED},
        "scope": "actual CYPS dynamic seam across signed chunks with privately staged FULL World only; NO selective eviction/durable storage",
    }
    (OUTPUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    for configured in (1, 4):
        result = subprocess.run([str(exe), str(configured)], capture_output=True,
                                text=True, errors="replace", timeout=300)
        (OUTPUT / f"workers-{configured}.stdout").write_text(result.stdout, encoding="utf-8")
        (OUTPUT / f"workers-{configured}.stderr").write_text(result.stderr, encoding="utf-8")
        markers = (
            f"GEN006_DYNAMIC_COMPLETE_RESIDENT_BUNDLE_PASS configured_workers={configured} ",
            f"GEN006_DYNAMIC_ATOMIC_CROSS_SEAM_EDIT_PASS configured_workers={configured} ",
            f"GEN006_DYNAMIC_FULL_WORLD_CONTINUATION_PASS configured_workers={configured} ",
        )
        if result.returncode or any(marker not in result.stdout for marker in markers):
            raise RuntimeError(f"actual native workers={configured} failed (rc={result.returncode}); "
                               f"stdout={result.stdout[-2000:]} stderr={result.stderr[-2000:]}")
        for marker in markers:
            print(next(line for line in result.stdout.splitlines() if line.startswith(marker)))
    print("GEN006_DYNAMIC_FULL_WORLD_NATIVE_QUALIFICATION_PASS exact_head=" + head)


if __name__ == "__main__":
    run()
