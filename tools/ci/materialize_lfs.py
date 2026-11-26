#!/usr/bin/env python3
"""Retry transient LFS acquisition failures without changing selected inputs.

This is acquisition only. Callers must still authenticate materialized bytes and
source identity with their existing provenance gates. Permanent and ambiguous
failures stop immediately; every attempted command retains its original output.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import time

import execution_policy

ROOT = Path(__file__).resolve().parents[2]
PERMANENT = re.compile(
    r"\b(?:401|403|404)\b|authentication|authorization|access denied|permission denied|not found",
    re.IGNORECASE,
)
TRANSIENT = re.compile(
    r"couldn.t respond to your request in time|timed out|i/o timeout|connection reset|\b(?:429|502|503|504)\b",
    re.IGNORECASE,
)


def retryable(output: str) -> bool:
    return bool(TRANSIENT.search(output) and not PERMANENT.search(output))


def materialize(include: str, output: Path, *, run=subprocess.run, sleep=time.sleep,
                clock=time.monotonic, allowance=None) -> dict:
    if not include or "\n" in include or "\r" in include:
        raise ValueError("An explicit nonempty LFS include selection is required")
    # A failed attempt is evidence too. A rerun must choose a new directory.
    output.mkdir(parents=True, exist_ok=False)
    deadline = clock() + (execution_policy.watchdog_seconds("dependency_prepare_seconds")
                          if allowance is None else allowance)
    report = {"schema": 1, "status": "failed", "include": include,
              "attempts": [], "limits": ["Acquisition only; no binary or source admission is implied"]}

    def execute(arguments, name):
        path = output / name
        remaining = deadline - clock()
        if remaining <= 0:
            text, code = "LFS acquisition allowance exhausted before command launch.\n", None
        else:
            try:
                result = run(["git", "-C", str(ROOT), *arguments], stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=remaining, check=False)
                text = result.stdout.decode("utf-8", errors="replace")
                code = result.returncode
            except subprocess.TimeoutExpired as error:
                text = (error.stdout or b"").decode("utf-8", errors="replace")
                text += "\nLFS acquisition process exceeded the remaining allowance.\n"
                code = None
            except OSError as error:
                text, code = str(error) + "\n", None
        path.write_text(text, encoding="utf-8")
        print(text, end="" if text.endswith("\n") else "\n", flush=True)
        return {"log": name, "returncode": code}, text

    report["install"], _ = execute(["lfs", "install", "--local"], "install.log")
    if report["install"]["returncode"] == 0:
        for attempt in range(1, 4):
            record, text = execute(["lfs", "pull", "--include=" + include, "--exclude="],
                                   f"attempt-{attempt}.log")
            record["retryable"] = record["returncode"] not in (0, None) and retryable(text)
            report["attempts"].append(record)
            if record["returncode"] == 0:
                report["status"] = "passed"
                break
            delay = attempt * 3
            if attempt == 3 or not record["retryable"] or clock() + delay >= deadline:
                break
            sleep(delay)
    (output / "acquisition.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                                              encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--include", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    return 0 if materialize(args.include, args.output)["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
