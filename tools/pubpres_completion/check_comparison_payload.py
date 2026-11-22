#!/usr/bin/env python3
"""Verify the published comparison tree contains its original capture files."""

import os
from pathlib import Path
import sys


def main():
    root = Path(sys.argv[1])
    traces = []
    for directory, children, files in os.walk(root):
        children[:] = [name for name in children if name != "template"]
        if "receipt-events.jsonl" not in files:
            continue
        arm = Path(directory)
        originals = {name for name in files if (arm / name).stat().st_size > 0}
        if not {"receipt-events.jsonl", "receipt.json"} <= originals or not {"stdout.log", "stderr.log", "godot.log"} & originals:
            raise ValueError(f"Original comparison capture files are incomplete: {arm}")
        traces.append((arm / "receipt-events.jsonl").relative_to(root).as_posix())
    if len(traces) < 4:
        raise ValueError("Registered comparison payload lacks four original arm event streams")
    print(f"Retained {len(traces)} original comparison receipt, event and process-log bundles")


if __name__ == "__main__":
    main()
