#!/usr/bin/env python3
"""Small paired advisory timing of already-qualified native capability builds.

No pass threshold is inferred from timing. The fixed World process measurement
includes construction, 48 native ticks, checkpoint IO and native hash/readback;
it is not a tick-only measurement or a representative gameplay claim.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import time

import compiler

ROOT = Path(__file__).resolve().parents[2]


def measure(qualification: Path, output: Path, cxx: str = "c++") -> dict:
    receipt = json.loads((qualification / "receipt.json").read_text())
    if receipt.get("status") != "PASS" or receipt.get("sanitizers"):
        raise ValueError("timing requires successful unsanitized transition qualification")
    if output.exists():
        raise ValueError("output already exists")
    query_executables = {}
    sizes = {}
    for label in ("reference", "candidate"):
        stage = qualification / label
        world = stage / "world"
        if hashlib.sha256(world.read_bytes()).hexdigest() != receipt["builds"][label]["world_sha256"]:
            raise ValueError("qualified native World executable changed")
        query = stage / "capability-benchmark"
        subprocess.run([cxx, "-std=c++20", "-O2", "-Wall", "-Wextra", "-Werror", "-pthread",
                        "-I", str(stage / "native/include"), str(stage / "native/src/material_rules.cpp"),
                        str(ROOT / "tools/material_catalogue/capability_benchmark.cpp"), "-o", str(query)],
                       check=True, capture_output=True, timeout=300)
        query_executables[label] = query
        sizes[label] = {"query_executable_bytes": query.stat().st_size,
                        "world_executable_bytes": world.stat().st_size,
                        "size_output": subprocess.run(["size", str(query), str(world)], check=True,
                                                       capture_output=True, text=True).stdout}
    observations = []
    checksum = None
    for block in range(4):
        for label in ("reference", "candidate", "candidate", "reference"):
            query = subprocess.run([str(query_executables[label]), "50000000"], check=True,
                                   capture_output=True, text=True, timeout=60)
            record = json.loads(query.stdout)
            if checksum is not None and record["checksum"] != checksum:
                raise ValueError("native query checksum differs")
            checksum = record["checksum"]
            observations.append({"block": block, "build": label, "kind": "query", **record})
    for family in (1, 2, 3, 4):
        for workers in (1, 4):
            for label in ("reference", "candidate", "candidate", "reference"):
                stage = qualification / label
                checkpoint = stage / "timing.cyps"
                start = time.perf_counter_ns()
                process = subprocess.run([str(stage / "world"), "create", str(family), str(workers), str(checkpoint)],
                                         check=True, capture_output=True, text=True, timeout=300)
                elapsed = time.perf_counter_ns() - start
                record = json.loads(process.stdout)
                controls = [row["continuous"] for row in receipt["world_comparisons"]
                            if row["family"] == family and row["workers"] == workers and row["checkpoint_producer"] == label]
                if len(controls) != 1 or any(record[key] != controls[0][key]
                                            for key in ("final_physical_hash", "final_cells_sha256", "final_save_sha256", "policy_hash")):
                    raise ValueError("timed World differs from qualification")
                observations.append({"build": label, "kind": "world_process", "family": family,
                                     "workers": workers, "nanoseconds": elapsed,
                                     "observed_workers": record["observed_workers"]})
    medians = {kind: {label: statistics.median(row["nanoseconds"] for row in observations
                if row["kind"] == kind and row["build"] == label) for label in ("reference", "candidate")}
                for kind in ("query", "world_process")}
    result = {"schema_id": "cybersand.material-capability-transition.advisory-timing", "schema_version": 1,
              "platform": platform.platform(), "compiler": receipt["compiler"], "flags": "-O2 -pthread; no LTO",
              "qualification_receipt_sha256": hashlib.sha256((qualification / "receipt.json").read_bytes()).hexdigest(),
              "query_scope": "100 million combined hard/granular calls per process; permuted complete byte domain",
              "world_scope": "512x256 all-material chamber fixture; construction + 48 native ticks + checkpoint IO + stored-state readback",
              "timing_is_advisory": True, "shared_host": True, "sizes": sizes, "medians_ns": medians,
              "observations": observations, "correctness": "all query checksums and World outputs match qualified source controls"}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(compiler.canonical_json(result))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qualification", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cxx", default="c++")
    args = parser.parse_args()
    result = measure(args.qualification.resolve(), args.output.resolve(), args.cxx)
    print(json.dumps({"medians_ns": result["medians_ns"], "timing_is_advisory": True}, sort_keys=True))
