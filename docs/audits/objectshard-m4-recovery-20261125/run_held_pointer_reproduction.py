#!/usr/bin/env python3
"""Observed actual Godot replay; no source mutation or engine state injection."""
from pathlib import Path
import argparse
import contextlib
import hashlib
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/objectshard"))
import qualify_workbench as qualification


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", required=True)
    parser.add_argument("--import-only", action="store_true")
    args = parser.parse_args()
    directory = ROOT / "build/recovery-held-pointer" / args.label
    directory.mkdir(parents=True, exist_ok=False)
    source = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    env = dict(os.environ, XDG_DATA_HOME=str(directory / "user-data"), CYBERSAND_SOURCE_REVISION=source)
    fixture = ROOT / "godot/tests/test_object_shard_m4_fragment_reabsorption.gd"
    name = "held_pointer_import" if args.import_only else "test_object_shard_m4_fragment_reabsorption"
    flags = ("--editor", "--quit") if args.import_only else (
        "--script", "res://tests/test_object_shard_m4_fragment_reabsorption.gd", "--", "--objectshard-m4-workbench")
    case = qualification.runner.Case(name, flags, 300, 0)
    engine = "/home/agent/objectshard-recovery-20261125/shared-runtime/Godot_v4.7-stable_linux.x86_64"
    with (directory / "driver.log").open("w") as output, contextlib.redirect_stdout(output):
        record, failed = qualification.run_observed_case(qualification.runner, engine, case, directory, "focused-reproduction", env=env)
    receipts = []
    for line in (directory / record["log"]).read_text(errors="replace").splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("schema") == "objectshard-m4-fragment-reabsorption-v1":
            receipts.append(value)
    result = {"schema": "objectshard-m4-observed-held-pointer-replay-v1", "source_commit": source,
              "source_tree": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD^{tree}"], text=True).strip(),
              "fixture_sha256": digest(fixture), "record": record, "runner_failed": bool(failed),
              "completion_receipts": receipts, "runtime_custody_sha256": digest(ROOT / "build/recovery-held-pointer/runtime-custody.json"),
              "runner_sha256": digest(Path(__file__)), "scope": "Local Linux headless; real native worker and Rapier; no physical GPU acceptance."}
    (directory / "result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"directory": str(directory), "status": record["status"], "returncode": record["returncode"],
                      "seconds": record["seconds"], "receipt_count": len(receipts),
                      "checks": receipts[0].get("checks") if len(receipts) == 1 else None,
                      "failures": receipts[0].get("failures") if len(receipts) == 1 else None}))


if __name__ == "__main__":
    main()
