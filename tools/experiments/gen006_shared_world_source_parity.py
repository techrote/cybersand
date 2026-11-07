#!/usr/bin/env python3
"""GEN-006 #512 independent real-native accepted-source parity + re-admission.

Usage (after setting up toolchain): python3 tools/experiments/gen006_shared_world_source_parity.py
Layout: WORKSPACE/candidate = stacked support PR; WORKSPACE/accepted = exact
base of #512 (24a8bbe8...). Never updates protected production source.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

PINNED_MAIN = "24a8bbe8ccf0d17196ebbab580b924930a964584"
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
]
HERE = Path(__file__).resolve()
CANDIDATE = HERE.parents[2]
ACCEPTED = CANDIDATE.parent / "accepted"
OUTPUT = CANDIDATE / "build" / "gen006-source-parity"
OUTPUT.mkdir(parents=True, exist_ok=True)


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def build(which: str, root: Path, compiler: str) -> Path:
    target = OUTPUT / (which + (".exe" if os.name == "nt" else ""))
    args = [compiler, "-std=c++20", "-O0", "-g0", "-I", str(root / "native/include")]
    if os.name != "nt":
        args += ["-pthread"]
    if which == "candidate":
        args += ["-DGEN006_TEST_RELEASE=1"]
    args += [str(root / s) for s in SOURCES]
    args += [str(CANDIDATE / "native/tests/gen006_shared_world_source_parity.cpp"),
             "-o", str(target)]
    with (OUTPUT / f"compile-{which}.log").open("w", encoding="utf-8") as log:
        code = subprocess.run(args, stdout=log, stderr=subprocess.STDOUT,
                              timeout=1600, check=False).returncode
    if code:
        print((OUTPUT / f"compile-{which}.log").read_text(encoding="utf-8")[-16000:],
              file=sys.stderr)
        raise RuntimeError(f"{which} native compile failed: {code}")
    return target


def execute(which: str, binary: Path, workers: int) -> list[str]:
    result = subprocess.run([str(binary), str(workers)], capture_output=True,
                            text=True, errors="replace", timeout=300)
    (OUTPUT / f"{which}-{workers}.out").write_text(result.stdout, encoding="utf-8")
    (OUTPUT / f"{which}-{workers}.err").write_text(result.stderr, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{which}/{workers} actual native run failed: "
                           f"{result.returncode}; stderr={result.stderr[-2500:]}")
    lines = [line for line in result.stdout.splitlines() if line.startswith("PARITY ")]
    if len(lines) != 6:
        raise RuntimeError(f"{which}/{workers} expected six native parity checkpoints, "
                           f"got {len(lines)}")
    if which == "candidate" and (
        f"GEN006_SHARED_WORLD_RELEASE_READMIT_PASS workers={workers}" not in result.stdout
    ):
        raise RuntimeError(f"{which}/{workers} genuine shared-World re-admission failed")
    return lines


def main() -> None:
    compiler = os.getenv("GEN006_CXX") or ("clang++" if os.name == "nt" else "g++-13")
    observed_head = git(CANDIDATE, "rev-parse", "HEAD")
    expected_head = os.environ.get("EXPECTED_HEAD", "").strip()
    if not expected_head or observed_head != expected_head:
        raise RuntimeError(f"candidate HEAD {observed_head} differs from {expected_head}")
    observed_main = git(ACCEPTED, "rev-parse", "HEAD")
    if observed_main != PINNED_MAIN:
        raise RuntimeError(f"accepted-main HEAD {observed_main} != {PINNED_MAIN}")

    compiler_version = subprocess.check_output([compiler, "--version"], text=True).splitlines()[0]
    receipt = {
        "candidate_sha": observed_head,
        "candidate_tree": git(CANDIDATE, "rev-parse", "HEAD^{tree}"),
        "accepted_source_sha": observed_main,
        "accepted_tree": git(ACCEPTED, "rev-parse", "HEAD^{tree}"),
        "candidate_world_blob": git(CANDIDATE, "hash-object", "native/src/world.cpp"),
        "accepted_world_blob": git(ACCEPTED, "hash-object", "native/src/world.cpp"),
        "candidate_test_blob": git(CANDIDATE, "hash-object", "native/tests/gen006_shared_world_source_parity.cpp"),
        "compiler": compiler_version,
        "platform": platform.platform(),
        "scope": "actual native World's pre/post source semantic parity and pristine same-World release/re-admission",
    }
    binaries = {tag: build(tag, root, compiler) for tag, root in (
        ("accepted", ACCEPTED), ("candidate", CANDIDATE)
    )}
    for workers in (1, 4):
        old = execute("accepted", binaries["accepted"], workers)
        new = execute("candidate", binaries["candidate"], workers)
        if old != new:
            (OUTPUT / f"parity-mismatch-{workers}.json").write_text(
                json.dumps({"accepted": old, "candidate": new}, indent=2),
                encoding="utf-8",
            )
            raise RuntimeError(f"GEN006_SOURCE_DEFAULT_PARITY_MISMATCH workers={workers}")
        digest = hashlib.sha256("\n".join(old).encode()).hexdigest()
        print(f"GEN006_ACCEPTED_DEFAULT_PARITY_PASS configured_workers={workers} "
              f"checkpoints={len(old)} sha256={digest}")
        print(f"GEN006_SHARED_WORLD_RELEASE_READMIT_PASS configured_workers={workers} "
              "actual_native_release=1 actual_regeneration=1 continuing_ticks=4")
    (OUTPUT / "source.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
