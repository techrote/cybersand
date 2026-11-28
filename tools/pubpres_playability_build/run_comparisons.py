#!/usr/bin/env python3
"""Run one complete matched source comparison or registered diagnostic.

Every failed invocation remains in the index. A negative performance result is
valid evidence; an incomplete capture or invalid physical comparison is not a
passing qualification. This driver never changes thresholds after results.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from build_runtime import bounded_process

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("main", "integration", "candidate", "engine", "runtime-root", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--case", required=True)
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--stage", choices=("source", "thread", "observer", "native-probe", "input", "same-frame"), required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError("Keep original comparison evidence; use a fresh output")
    output.mkdir(parents=True)
    command = [sys.executable, str(ROOT / "tools/pubpres_playability/run_campaign.py")]
    for key in ("main", "integration", "candidate", "engine"):
        command += ["--" + key, str(getattr(args, key).resolve())]
    for letter in ("M", "I", "C"):
        command += ["--runtime-" + letter, str(args.runtime_root.resolve() / letter)]
    command += ["--case", args.case, "--driver", "opengl3_angle" if os.name == "nt" else "opengl3"]
    if args.display_wrapper:
        command += ["--display-wrapper", str(args.display_wrapper.resolve())]
    registration = json.loads((ROOT / "tools/pubpres_playability/campaign.json").read_text())
    case = next(c for c in registration["cases"] if c["id"] == args.case)
    options = {"source": ("source-comparison", [], None),
               "thread": ("render-thread-abba", ["--thread-calibration"], "render_thread_calibration"),
               "observer": ("observer-abba", ["--observer-calibration"], "calibration"),
               "native-probe": ("native-probe-abba", ["--native-probe-calibration"], "native_probe_calibration"),
               "same-frame": ("same-frame-abba", ["--same-frame-calibration"], "same_frame_calibration"),
               "input": ("input-mode-abba", ["--input-equivalence"], "input_equivalence")}
    name, flags, key = options[args.stage]
    if key:
        spec = registration[key]
        if spec.get("enabled", True) is not True:
            raise ValueError("Diagnostic is retired in the selected registration")
        if args.case not in spec.get("cases", [spec.get("case")]):
            raise ValueError("Case is not registered for the selected diagnostic")
    stages = [(name, flags)]
    arms = len(registration[key]["order"]) if key else len(case.get("arm_order", registration["order"]))
    # Three complete source imports, every admitted 900-second child, an
    # untimed compatibility preflight and process-tree cleanup all fit inside
    # the enclosing allowance. Each paired order remains on a single host.
    allowance = 3 * (300 + 120) + arms * 900 + 300 + (arms + 7) * 30 + 60
    outcomes = []
    for name, flags in stages:
        argv = command + ["--output", str(output / name)] + flags
        started = time.monotonic()
        terminal = None
        with (output / (name + ".log")).open("w", encoding="utf-8") as log:
            try:
                returncode, timed_out = bounded_process(argv, stdout=log, timeout=allowance)
                result = {"returncode": returncode, "timeout": timed_out}
            except (subprocess.SubprocessError, OSError, RuntimeError) as error:
                result = {"returncode": None, "timeout": True, "cleanup_error": str(error)}
            except BaseException as error:
                terminal = error
                result = {"returncode": None, "timeout": False,
                          "terminal_interruption": type(error).__name__ + ": " + str(error)}
        result.update(name=name, command=argv, elapsed_seconds=time.monotonic() - started)
        outcomes.append(result)
        index = {"schema": "pubpres-comparison-campaign-index-v1", "case": args.case, "stage": args.stage,
                 "parent_allowance_seconds": allowance, "admitted_arm_timeout_seconds": 900,
                 "scope": "same-host software-renderer evidence; physical NVIDIA acceptance remains HOLD",
                 "outcomes": outcomes, "complete": len(outcomes) == len(stages)
                 and all(r["returncode"] == 0 and not r["timeout"] for r in outcomes)}
        (output / "INDEX.json").write_text(json.dumps(index, indent=2) + "\n")
        print(json.dumps({k: result[k] for k in ("name", "returncode", "timeout", "elapsed_seconds")}), flush=True)
        if terminal is not None:
            raise terminal
        if result["timeout"]:
            # A timing capture after timeout/uncertain cleanup cannot be paired
            # honestly with the preceding run. Retain the incomplete frontier.
            break
    return 0 if index["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
