#!/usr/bin/env python3
"""Run PLAY-BUSY-001C with the independent process/progress watchdog."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time

import godot_process_monitor as monitor
import godot_timeout_diagnostics as diagnostics


CASE = "play_busy001c_render"
ABSOLUTE_TIMEOUT_SECONDS = 120


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    log_path = args.output / "render-execution.log"
    diagnostic_path = args.output / "render-diagnostics"
    command = [
        args.godot,
        "--rendering-method", "gl_compatibility",
        "--audio-driver", "Dummy",
    ]
    if args.platform == "linux":
        command += ["--display-driver", "x11"]
    command += [
        "--path", "godot",
        "--script", "res://tests/play_busy001c_render.gd",
    ]

    started = time.perf_counter()
    timeout_events: list[float] = []
    with log_path.open("w", encoding="utf-8") as log:
        child = subprocess.Popen(
            command, stdout=log, stderr=subprocess.STDOUT,
            env=os.environ.copy(),
        )
        try:
            timed_out, timeout_kind, capture_error = monitor.wait(
                child, CASE, ABSOLUTE_TIMEOUT_SECONDS, started,
                log_path, diagnostic_path, on_timeout=timeout_events.append,
            )
            if timed_out:
                log.write(
                    f"\nPLAY_BUSY001C_EXTERNAL_TIMEOUT kind={timeout_kind} "
                    f"absolute_seconds={ABSOLUTE_TIMEOUT_SECONDS} "
                    f"capture_error={capture_error!r}\n"
                )
                log.flush()
                diagnostics.stop_process_tree(child)
                print(
                    "PLAY_BUSY001C_RUNNER timeout",
                    timeout_kind,
                    "capture_error=", capture_error,
                    flush=True,
                )
                return 1
            returncode = child.wait(timeout=5)
        finally:
            if child.poll() is None:
                diagnostics.stop_process_tree(child)

    if returncode:
        print(f"PLAY_BUSY001C_RUNNER child exit={returncode}", flush=True)
        return returncode
    elapsed = time.perf_counter() - started
    print(f"PLAY_BUSY001C_RUNNER passed elapsed_seconds={elapsed:.3f}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
