#!/usr/bin/env python3
"""Run the unchanged revealed 006 corpus on the exact unified scientific build.

The frozen runner/harness use their normal C++ ABI and remain independent of the
portable distribution CLI's older string ABI. This is regression, never a new
unseen experiment or physical owner acceptance.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

import runtime_custody as custody
from shared import load


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cxx", default="/usr/bin/g++-13")
    parser.add_argument("--workers", type=int, choices=range(1, 5), default=2)
    args = parser.parse_args()
    context, source = custody.build_context(), custody.source()
    build, output = args.build.resolve(), args.output.resolve()
    custody.require(not build.exists() and not output.exists()
                    and not build.is_relative_to(custody.ROOT) and not output.is_relative_to(custody.ROOT),
                    "Scientific build and evidence must be fresh and outside the source checkout")
    output.parent.mkdir(parents=True, exist_ok=True)
    commands = (
        ("recovery-build", [sys.executable, str(custody.ROOT / "native/experiments/gentek_swarm/run_swarm006.py"),
                             "build", "--source-root", str(custody.ROOT), "--build", str(build),
                             "--variant", "swarm006", "--cxx", args.cxx]),
        ("recovery-replay", [sys.executable, str(custody.ROOT / "tools/swarm006/replay_finisher.py"),
                              "--build", str(build), "--out", str(output), "--workers", str(args.workers)]),
    )
    for label, command in commands:
        with (output.parent / (label + ".log")).open("w", encoding="utf-8") as stream:
            child = subprocess.run(command, cwd=custody.ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                   timeout=3300 if label == "recovery-replay" else 1200)
        custody.require(child.returncode == 0, "Scientific build/replay failed; original log retained: " + label)
    replay = load("swarm456_recovery_reader", "tools/swarm006/replay_finisher.py")
    receipt = replay.verified_build(build, replay.frozen_runner())
    custody.require(receipt["source_commit"] == source["source_commit"]
                    and receipt["definition_sha256"] == source["native_definition_sha256"]
                    and custody.source() == source, "Scientific source/definition changed")
    shutil.copyfile(build / "build.json", output / "native-build.json")
    for name in ("build-core.log", "build-driver.log"):
        shutil.copyfile(build / name, output / name)
    compiler = subprocess.check_output([args.cxx, "--version"], text=True, timeout=30)
    (output / "scientific-toolchain.txt").write_text(compiler, encoding="utf-8")
    custody.write_json(output / "unified-replay.json", {
        "schema": 1, "qualification_programme": custody.QUALIFICATION_PROGRAMME,
        "source": source, "build_context": context, "passed": True,
        "scope": "Revealed 96-case by 20-policy successor regression; original 90-second child limit; no unseen or owner-World claim",
        "repair_scope": "Unified SWARM005 charged receptor accounting plus SWARM006 reserve/debit/failure-receipt recovery; original budgets, ordering and registration retained",
        "files_sha256": custody.inventory(output), "owner_visual_acceptance": "pending"})
    print(json.dumps({"source": source["source_commit"], "passed": True, "executions": 1920}))


if __name__ == "__main__":
    main()
