#!/usr/bin/env python3
"""Independent repeated experiments: preserve every failure, with no retries."""

import argparse
from collections import Counter
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

import run_godot_regressions as runner

SUSPECTS = ("test_physical_actor_arena", "test_physical_actor_rigs", "test_physical_usable_course")


def current_host() -> str:
    if sys.platform == "win32":
        return "windows"
    if sys.platform.startswith("linux"):
        return "linux"
    raise RuntimeError("Physical stress requires Windows or Linux")


def progress_phase(record: dict) -> str:
    marker = record.get("last_progress")
    if isinstance(marker, str):
        phase = re.search(r"\bphase=([^\s]+)", marker)
        if phase:
            return phase[1]
    for marker in (marker, record.get("last_heartbeat")):
        if isinstance(marker, dict) and isinstance(marker.get("phase"), str):
            return marker["phase"]
    return "before-first-marker"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--iterations", type=int, default=50)
    parser.add_argument("--host", choices=("windows", "linux"), required=True)
    parser.add_argument("--batch", type=int, required=True)
    parser.add_argument("--variant", choices=("retained", "control", "patched"), required=True)
    parser.add_argument("--rapier-build-manifest", type=Path)
    args = parser.parse_args()
    if not 1 <= args.iterations <= 100:
        parser.error("iterations must be between 1 and 100")
    if args.host != current_host() or args.batch not in range(5):
        parser.error("host must match this OS and batch must be between 0 and 4")
    if (args.variant == "retained") != (args.rapier_build_manifest is None):
        parser.error("control/patched variants require a build manifest; retained uses committed runtime")
    args.output.mkdir(parents=True, exist_ok=True)
    native, rapier = runner.runtime_paths()
    identity = {
        "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=runner.ROOT, text=True).strip(),
        "platform": platform.platform(), "python": platform.python_version(),
        "godot_version": subprocess.check_output([args.godot, "--version"], text=True, timeout=30).strip(),
        "native_sha256": runner.sha256(native), "rapier_sha256": runner.sha256(rapier),
        "run_id": os.environ.get("GITHUB_RUN_ID"), "attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "host": args.host, "batch": args.batch, "variant": args.variant,
        "local_delta": subprocess.check_output(["git", "diff", "HEAD", "--stat"], cwd=runner.ROOT, text=True),
    }
    if args.rapier_build_manifest:
        from rapier_candidate_identity import verify
        identity["rapier_build"] = verify(runner.ROOT, args.rapier_build_manifest)
        if identity["rapier_build"].get("variant") != args.variant:
            raise RuntimeError("Declared stress variant differs from the verified Rapier build")
    if sys.platform == "win32":
        from run_windows_godot_regressions import verify_retained_runtime
        identity["retained_runtime"] = verify_retained_runtime(runner.ROOT, rapier_build=args.rapier_build_manifest)
    runner.write_json(args.output / "identity.json", identity)
    results = []
    cases = {case.name: case for case in runner.discover_cases()}
    record, failed = runner.run_case(args.godot, runner.Case("import", ("--editor", "--quit"), 240, 3), args.output, "preflight")
    runner.write_json(args.output / "preflight.json", record)
    if failed:
        return 1
    for iteration in range(args.iterations):
        directory = args.output / f"iteration-{iteration:03d}"
        directory.mkdir()
        for name in SUSPECTS:
            record, _ = runner.run_case(args.godot, cases[name], directory, "case")
            record["iteration"] = iteration
            results.append(record)
            counts = {name: dict(Counter(r["status"] for r in results if r["name"] == name)) for name in SUSPECTS}
            hangs = Counter(
                r["name"] + "/" + progress_phase(r)
                for r in results if r["status"] == "timeout")
            runner.write_json(args.output / "stress.json", {
                "identity": identity, "iterations_requested": args.iterations,
                "completed": len(results) == args.iterations * len(SUSPECTS),
                "counts": counts, "timeouts_by_phase": dict(hangs), "results": results})
            print("Stress counts:", counts, "hang phases:", dict(hangs), flush=True)
    return int(any(record["status"] != "passed" for record in results))


if __name__ == "__main__":
    raise SystemExit(main())
