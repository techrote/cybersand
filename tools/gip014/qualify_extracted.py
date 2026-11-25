#!/usr/bin/env python3
"""Bound the fixed extracted Windows evaluator self-test and its owned children."""
import argparse
import json
import os
from pathlib import Path

from owned_process import execute, read_log_prefix


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    args = parser.parse_args()
    root = args.package.resolve(strict=True)
    if os.name != "nt" or not (root / "Open goblin.ps1").is_file():
        parser.error("Extracted qualification requires the actual Windows package")
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "Open goblin.ps1"),
               "-Mode", "SelfTest", "-GraphicalSmoke"]
    result = execute(command, dict(os.environ), args.log, 1200, cwd=root, memory_limit_mib=3072)
    args.log.with_suffix(".process.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    markers = [line for line in read_log_prefix(args.log).splitlines()
               if line.startswith("GOBLIN_PACKAGE_SELFTEST_PASS ")]
    if result["status"] != "pass" or len(markers) != 1:
        print(json.dumps({"status": result["status"], "completion_markers": len(markers), "retained_log": str(args.log)}))
        return 2
    print(markers[0])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
