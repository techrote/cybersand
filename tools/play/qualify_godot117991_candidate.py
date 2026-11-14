#!/usr/bin/env python3
"""Qualify the *retained* Godot #117991 B editor against current CyberSand on actual Windows.

This is not a production pin migration or a full platform-coverage acceptance.
Preserve real process exits, imports, original case logs, DLL provenance, and source drift.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import run_godot_regressions as runner
import run_windows_godot_regressions as windows

ROOT = runner.ROOT
EXPECTED_EXE = "4e6a001ecc6a1f8df820f4c788a3bc0d4e42595b28ffea41fbf7b5666d70e26b"
EXPECTED_PDB = "5a881c2db0b23fb1cd3773be76e5c3c8e5100d0182f979235555c23cc880573b"
EXPECTED_VERSION = "4.7.stable.custom_build.5b4e0cb0f"
SELECTED_CASES = (
    "test_liquid_desktop_default_host",
    "test_lcb_pressure_reference",
    "test_play_pace002_acrobat",
    "test_gen007_qualification",
    "test_cell_world",
    "test_native_edge_contact_regression",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    hash_ = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(4 * 1024 * 1024), b""):
            hash_.update(block)
    return hash_.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--pdb", type=Path, required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    report = {
        "schema": "godot117991-candidate-current-main-windows-v1",
        "purpose": "Representative qualification only; not full Windows/Linux/rendered gameplay matrix",
        "status": "running", "completed": False, "errors": [], "results": [],
        "run_id": os.getenv("GITHUB_RUN_ID"), "attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
        "platform": platform.platform(), "python": platform.python_version(),
        "selected_cases": list(SELECTED_CASES), "log_sha256": {},
        "executed_case_count": 0,
    }
    start = time.monotonic()
    runner.write_json(out / "candidate-report.json", report)
    try:
        require(sys.platform == "win32", "Real Windows host required")
        with windows.metadata_budget():
            source = windows.git(ROOT, "rev-parse", "HEAD").decode().strip()
            require(source == args.expected_source_sha, "Checkout/source SHA differs from requested head")
            tree = windows.git(ROOT, "rev-parse", "HEAD^{tree}").decode().strip()
            report.update({"source_commit": source, "source_tree": tree})
            report.update(windows.verify_retained_runtime(ROOT))
            before = windows.tested_inputs(ROOT)
            report["source_input_count"] = len(before)
            godot, pdb = args.godot.resolve(), args.pdb.resolve()
            require(godot.is_file() and pdb.is_file(), "Retained B engine/PDB not materialized")
            engine_sha, pdb_sha = sha256(godot), sha256(pdb)
            require(engine_sha == EXPECTED_EXE and pdb_sha == EXPECTED_PDB,
                    "Retained #401 B engine/PDB identity mismatch")
            version = subprocess.check_output([str(godot), "--version"], text=True, timeout=45).strip()
            require(version == EXPECTED_VERSION, "Unexpected Godot engine version: " + version)
            report["engine"] = {
                "sha256": engine_sha, "size": godot.stat().st_size,
                "pdb_sha256": pdb_sha, "pdb_size": pdb.stat().st_size,
                "version": version,
                "source": "original PR #401 B from run 41958413986",
                "godot_source": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
                "patch_sha256": "7ef6a13fd52939830eb14ae9391c0e80449db5107f894972ef6e81b6e54d70f5",
            }
        os.environ["CYBERSAND_SOURCE_REVISION"] = source
        discovered = {case.name: case for case in runner.discover_cases()}
        require(all(name in discovered for name in SELECTED_CASES), "Requested case missing from source")
        cases = [discovered[name] for name in SELECTED_CASES]
        require(not any(case.requires_display for case in cases), "Graphical case assigned to headless Windows")
        windows.execute_cases(str(godot), out, report, cases, shard_count=1, shard_index=0)
        case = next((row for row in report["results"]
                     if row.get("name") == "test_liquid_desktop_default_host"), None)
        require(case is not None, "Crash-reproducer fixture was not executed")
        footer = (out / case["log"]).read_text(encoding="utf-8", errors="replace")
        match = re.search(r"LIQUID_DESKTOP_DEFAULT_HOST:\s*(\d+) assertions;\s*0 failures", footer)
        require(match is not None and int(match.group(1)) >= 1,
                "Current-main liquid host footer absent or failures reported")
        report["liquid_host_assertion_count"] = int(match.group(1))
        with windows.metadata_budget():
            after = windows.tested_inputs(ROOT)
            changed = sorted(path for path in before.keys() | after.keys()
                             if before.get(path) != after.get(path))
            require(not changed, "Tested source/runtime drift: " + ", ".join(changed))
        require(report["completed"], "Not all selected Windows cases completed")
        require(all(row["status"] == "passed" and row["returncode"] == 0
                    for row in report["results"]), "One or more actual process exits failed")
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["errors"].append(type(error).__name__ + ": " + str(error))
    report["seconds"] = round(time.monotonic() - start, 3)
    runner.write_json(out / "candidate-report.json", report)
    print(json.dumps({"status": report["status"], "errors": report["errors"],
                      "source": report.get("source_commit"),
                      "results": [{"name": row["name"], "exit": row.get("returncode"),
                                   "status": row["status"]} for row in report["results"]]},
                     indent=2, sort_keys=True), flush=True)
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
