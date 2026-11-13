#!/usr/bin/env python3
"""Qualify the single native capability consumer against an authenticated source.

Builds original and candidate native queries/Worlds, compares their byte-domain
oracles, executes all four Water solver families with actual one/four workers,
and exchanges the unchanged CYPS checkpoint in both directions. This is a
bounded source transition, not new physics, a runtime installer or a lock update.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time

import compiler
import compatibility
import native_capabilities

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "f684dcffb18614dd9557e85d3c811abcb28cf325"
WORLD_SOURCES = ("world.cpp", "material_rules.cpp", "scheduler_geometry.cpp", "settled_world_discovery.cpp")
TOOLS = ("native_oracle.cpp", "capability_world_probe.cpp", "check_capability_transition.py",
         "native_capabilities.py", "compiler.py")
EQUAL_FIELDS = ("family", "checkpoint_tick", "final_tick", "checkpoint_physical_hash",
                "checkpoint_cells_sha256", "final_physical_hash", "final_cells_sha256",
                "final_save_sha256", "policy_hash", "water_visible", "water_overfill",
                "quantity_balanced", "status")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inventory(root: Path) -> dict[str, str]:
    names = [path for path in (root / "native").rglob("*")
             if path.is_file() and path.suffix in (".h", ".hpp", ".cpp", ".inc")]
    names.extend(root / "tools/material_catalogue" / name for name in TOOLS)
    names.extend(root / name for name in ("materials/catalogue/catalogue.json",
                                         "materials/catalogue/compatibility-lock.json"))
    return {path.relative_to(root).as_posix(): sha(compatibility.lf(path.read_bytes()))
            for path in sorted(names)}


def run(argv: list[str], directory: Path, label: str, *, timeout: int = 300,
        expected: int = 0, environment: dict | None = None) -> subprocess.CompletedProcess:
    started = time.monotonic()
    result = subprocess.run(argv, cwd=directory, capture_output=True, timeout=timeout,
                            env=environment or os.environ.copy())
    logs = directory / "logs"
    logs.mkdir(exist_ok=True)
    (logs / (label + ".stdout")).write_bytes(result.stdout)
    (logs / (label + ".stderr")).write_bytes(result.stderr)
    (logs / (label + ".command.json")).write_bytes(compiler.canonical_json(
        {"argv": argv, "exit_code": result.returncode, "seconds": time.monotonic() - started}))
    if result.returncode != expected:
        raise RuntimeError(f"{label}: expected exit {expected}, got {result.returncode}: "
                           + result.stderr.decode("utf-8", errors="replace")[-6000:])
    return result


def qualify(output: Path, *, cxx: str = "c++", sanitize: bool = False) -> dict:
    output = output.resolve()
    if output.exists():
        raise ValueError("choose a new output directory; previous qualification is never overwritten")
    output.mkdir(parents=True)
    before = inventory(ROOT)
    catalogue = compiler.load_catalogue(native_capabilities.SOURCE)
    native_capabilities.generate(check=True)
    immutable = (*compatibility.CATALOGUE_SOURCES,
                 "materials/catalogue/compatibility-lock.json",
                 "docs/reference/liquid-solver-capability-matrix.json",
                 "native/include/cybersand/liquid_policy_catalogue.hpp")
    for name in immutable:
        original = compatibility._git(ROOT, "show", f"{BASELINE}:{name}")
        if original.returncode or original.stdout != (ROOT / name).read_bytes():
            raise RuntimeError(f"source identity owner changed: {name}")
    original = compatibility._git(ROOT, "archive", "--format=tar", BASELINE, "native")
    if original.returncode:
        raise RuntimeError("could not authenticate original native source archive")
    reference = output / "reference"
    reference.mkdir()
    with tarfile.open(fileobj=io.BytesIO(original.stdout)) as archive:
        archive.extractall(reference, filter="data")
    candidate = output / "candidate"
    shutil.copytree(ROOT / "native", candidate / "native")
    for stage in (reference, candidate):
        for name in TOOLS[:2]:
            shutil.copy2(ROOT / "tools/material_catalogue" / name, stage / name)
        (stage / "catalogue.shadow.hpp").write_bytes(compiler.render_outputs(catalogue)["catalogue.shadow.hpp"])
    base_flags = [cxx, "-std=c++20", "-Wall", "-Wextra", "-Werror", "-pthread", "-I", "native/include", "-I", "."]
    flags = ["-O1", "-g", "-fno-omit-frame-pointer", "-fsanitize=address,undefined"] if sanitize else ["-O2"]
    environment = os.environ.copy()
    if sanitize:
        environment["ASAN_OPTIONS"] = "detect_leaks=0:strict_string_checks=1"
        environment["UBSAN_OPTIONS"] = "halt_on_error=1"
    result = {"schema_id": "cybersand.material-capability-transition", "schema_version": 1,
              "baseline": BASELINE, "candidate_head": compatibility._git(ROOT, "rev-parse", "HEAD").stdout.decode().strip(),
              "source_inputs": before, "sanitizers": {key: environment[key] for key in ("ASAN_OPTIONS", "UBSAN_OPTIONS") if key in environment},
              "compiler": run([cxx, "--version"], output, "compiler").stdout.decode().splitlines()[0],
              "builds": {}, "world_comparisons": []}
    snapshots = []
    suffix = ".exe" if os.name == "nt" else ""
    for name, stage in (("reference", reference), ("candidate", candidate)):
        oracle = stage / ("oracle" + suffix)
        world = stage / ("world" + suffix)
        oracle_args = [*base_flags, *flags, '-DCYBERSAND_MATERIAL_CANDIDATE_HEADER="catalogue.shadow.hpp"',
                       "native/src/material_rules.cpp", "native_oracle.cpp", "-o", str(oracle)]
        run(oracle_args, stage, "compile-oracle", timeout=600)
        snapshot = run([str(oracle), "--snapshot"], stage, "snapshot", environment=environment).stdout
        snapshots.append(snapshot)
        parity = json.loads(run([str(oracle), "--parity"], stage, "parity", environment=environment).stdout)
        run([*base_flags, *flags, *("native/src/" + source for source in WORLD_SOURCES),
             "capability_world_probe.cpp", "-o", str(world)], stage, "compile-world", timeout=600)
        result["builds"][name] = {"oracle_sha256": sha(oracle.read_bytes()), "world_sha256": sha(world.read_bytes()),
                                 "snapshot_sha256": sha(snapshot), "pure_query_parity": parity}
    if snapshots[0] != snapshots[1]:
        raise RuntimeError("independent original/candidate native metadata snapshots differ")
    for family in range(1, 5):
        observed = []
        for name, stage in (("reference", reference), ("candidate", candidate)):
            executable = str(stage / ("world" + suffix))
            for workers in (1, 4):
                checkpoint = stage / f"family{family}-workers{workers}.cyps"
                capture = json.loads(run([executable, "create", str(family), str(workers), str(checkpoint)],
                                         stage, f"family{family}-create-{workers}", timeout=300, environment=environment).stdout)
                observed.append(capture)
                other = candidate if name == "reference" else reference
                restored = json.loads(run([str(other / ("world" + suffix)), "restore", str(family), str(workers), str(checkpoint)],
                                          other, f"family{family}-from-{name}-{workers}", timeout=300, environment=environment).stdout)
                if any(capture[field] != restored[field] for field in EQUAL_FIELDS):
                    raise RuntimeError(f"family{family} workers{workers}: cross-build checkpoint continuation differs")
                result["world_comparisons"].append({"family": family, "workers": workers,
                    "checkpoint_producer": name, "checkpoint_sha256": sha(checkpoint.read_bytes()),
                    "continuous": capture, "other_build_restore": restored, "identical": True})
        if any(any(observed[0][field] != current[field] for field in EQUAL_FIELDS) for current in observed[1:]):
            raise RuntimeError(f"family{family}: source/worker execution differs")
    # Compiled poison proves that production MaterialRules actually reads the
    # generated table. It is isolated and never touches the candidate source.
    poison = output / "poison"
    shutil.copytree(candidate / "native", poison / "native")
    shutil.copy2(candidate / "native_oracle.cpp", poison / "native_oracle.cpp")
    shutil.copy2(candidate / "catalogue.shadow.hpp", poison / "catalogue.shadow.hpp")
    poisoned = copy.deepcopy(catalogue)
    poisoned["native"]["capabilities"][7]["hard_surface"] = False
    (poison / "native/include/cybersand/material_capabilities.hpp").write_bytes(native_capabilities.render(poisoned))
    oracle = poison / ("oracle" + suffix)
    run([*base_flags, *flags, '-DCYBERSAND_MATERIAL_CANDIDATE_HEADER="catalogue.shadow.hpp"',
         "native/src/material_rules.cpp", "native_oracle.cpp", "-o", str(oracle)], poison, "compile-poison", timeout=600)
    refused = run([str(oracle), "--parity"], poison, "poison-parity", expected=1, environment=environment)
    if b"capability" not in refused.stderr:
        raise RuntimeError("compiled poison failed for an unrelated reason")
    result["poison_control"] = {"material": 7, "field": "hard_surface", "expected_exit": 1,
                                "diagnostic": refused.stderr.decode().strip()}
    if inventory(ROOT) != before:
        raise RuntimeError("candidate source changed while qualification ran")
    result["status"] = "PASS"
    result["source_unchanged_through_execution"] = True
    (output / "receipt.json").write_bytes(compiler.canonical_json(result))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cxx", default="c++")
    parser.add_argument("--sanitize", action="store_true")
    args = parser.parse_args()
    result = qualify(args.output, cxx=args.cxx, sanitize=args.sanitize)
    print(json.dumps({"status": result["status"], "world_comparisons": len(result["world_comparisons"]),
                      "receipt": str(args.output / "receipt.json")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
