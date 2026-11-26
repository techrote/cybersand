#!/usr/bin/env python3
"""Export the actual laboratory reduction and run its constant unittest."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys

import regression_bundle
from run_goblin import ROOT, execute, sha_file, write_json


def qualify(laboratory: Path, output: Path) -> dict:
    # run_goblin gives each scripted test its own profile; the plain `profile`
    # directory belongs to the editor import and has no native laboratory run.
    candidates = list((laboratory / "profile-00-goblin_laboratory").rglob("goblin/reproduction.json"))
    if len(candidates) != 1:
        raise ValueError("Exactly one actual native laboratory reproduction bundle is required")
    raw = candidates[0]
    bundle = regression_bundle.read_json(raw)
    if bundle.get("schema") != "cybersand-goblin-reproduction-bundle-v1" or not bundle.get("reduced_tape"):
        raise ValueError("Actual reduced laboratory tape is absent")
    original, reduced = bundle["original_tape"], bundle["reduced_tape"]
    if not 0 < len(reduced["steps"]) < len(original["steps"]):
        raise ValueError("Native laboratory did not retain a shorter observed reproduction")
    regression_bundle.export_case(original, output, reduced, reduction=bundle.get("reduction"))
    shutil.copyfile(raw, output / "native-reproduction-bundle.json")
    write_json(output / "observed-transcript.json", reduced)
    reproduced = regression_bundle.assert_case(output, mode="reproduction")
    command = [sys.executable, "-m", "unittest", "discover", "-s", str(output), "-p", "test_goblin_regression.py"]
    process = execute(command, dict(os.environ), output / "unittest.log", 60)
    result = {"schema": "cybersand-goblin-regression-export-qualification-v1", "status": "pass" if process["status"] == "pass" else "failed",
              "source_bundle_sha256": sha_file(raw), "source_provenance": original["header"]["provenance"],
              "original_actions": len(original["steps"]), "reduced_actions": len(reduced["steps"]),
              "reproduction_check": reproduced, "unittest_process": process,
              "classification": "legal_unusual_gameplay", "gameplay_defect_confirmed": False,
              "scope": "Actual native laboratory reduction exported to ordinary unittest; legal semantic outcome, not a discovered defect"}
    write_json(output / "qualification.json", result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--laboratory", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = qualify(args.laboratory.resolve(strict=True), args.out.resolve())
        print(json.dumps({k: result[k] for k in ("status", "original_actions", "reduced_actions", "classification")}))
        return 0 if result["status"] == "pass" else 2
    except (OSError, ValueError, AssertionError, KeyError, TypeError) as error:
        print(json.dumps({"status": "failed", "error": str(error)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
