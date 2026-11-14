#!/usr/bin/env python3
"""Fail-closed promotion gate for the exact VOID fresh120 experiment.

A saved partial checkpoint is valuable evidence, but is not a completed 120-step
candidate and must never unlock the 120-step DEVELOPMENT job.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

TARGET = 120
CHECKPOINT = "checkpoint-000120"


def verify_completion(summary: dict, exit_code: int) -> dict:
    if type(exit_code) is not int or exit_code != 0:
        raise ValueError("trainer exit must be zero; partial/failure is non-promotable")
    if not isinstance(summary, dict):
        raise ValueError("training summary must be a JSON object")
    required = {
        "status": "completed",
        "global_step": TARGET,
        "checkpoint": CHECKPOINT,
        "actual_training": True,
        "checkpoint_readback_exact": True,
        "frozen_base_unchanged": True,
    }
    for key, expected in required.items():
        value = summary.get(key)
        if type(value) is not type(expected) or value != expected:
            raise ValueError(f"120-step qualification mismatch: {key}={value!r}")
    return {
        "status": summary["status"],
        "actual_steps": summary["global_step"],
        "checkpoint": summary["checkpoint"],
        "wall_seconds": summary.get("wall_seconds"),
        "peak_rss_kib": summary.get("peak_rss_kib"),
        "promotable": True,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--exit-code", type=int, required=True)
    args = parser.parse_args()
    summary = json.loads(args.summary.read_text(encoding="utf-8"))
    print(json.dumps(verify_completion(summary, args.exit_code), sort_keys=True))


if __name__ == "__main__":
    main()
