#!/usr/bin/env python3
"""Qualify healthy inactive rescue under a failed active native World.

Runs real native/Store seed and recovery in separate Godot processes. This is
an integrity fixture, not graphical Main acceptance or a whole Save-all claim.
The intentionally failed active World is never reset or silently discarded.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import time


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--native", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=180.0)
    args = parser.parse_args()
    args.repo, args.godot, args.output = args.repo.resolve(), args.godot.resolve(), args.output.resolve()
    if args.native is None:
        name = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
        args.native = args.repo / "godot/addons/cybersand_native/bin" / name
    args.native = args.native.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    profile = args.output / "profile"
    if profile.exists():
        parser.error("Output already contains a profile; choose a fresh evidence directory")
    source_files = [args.repo / name for name in (
        "godot/tests/test_persistent_area_recovery.gd",
        "godot/tests/fixtures/persistent_area_native_fixture.gd",
        "godot/scripts/persistent_area_recovery.gd", "godot/scripts/persistent_area_store.gd",
        "godot/scripts/persistent_area_clock.gd", "godot/scripts/workbench_setup.gd",
        "godot/scripts/microscenario_contract.gd", "tools/ci/run_persistent_area_recovery.py")]
    for directory in ("native/include", "native/src", "godot/native_extension"):
        source_files.extend(sorted(path for path in (args.repo / directory).rglob("*")
                                   if path.is_file() and path.suffix in (".hpp", ".h", ".cpp", ".inc")))

    def identities() -> dict:
        return {"godot_sha256": digest(args.godot), "native_sha256": digest(args.native),
                "source_files": {str(path.relative_to(args.repo)): digest(path) for path in source_files}}

    before = identities()
    results = []
    seed = args.output / "seed.json"
    for mode in ("seed", "verify"):
        evidence = args.output / f"{mode}.json"
        command = [str(args.godot), "--headless", "--path", str(args.repo / "godot"), "--script",
                   "res://tests/test_persistent_area_recovery.gd", "--", f"--recovery-mode={mode}",
                   f"--recovery-profile={profile}", f"--recovery-output={evidence}", f"--recovery-seed={seed}"]
        started = time.monotonic()
        try:
            process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=args.timeout)
            output, exit_code = process.stdout, process.returncode
        except subprocess.TimeoutExpired as error:
            output, exit_code = error.stdout or b"", 124
        log = args.output / f"{mode}.log"
        log.write_bytes(output)
        observed = json.loads(evidence.read_text()) if evidence.exists() else {}
        result = {"mode": mode, "command": command, "exit_code": exit_code,
                  "elapsed_seconds": time.monotonic() - started, "log_sha256": digest(log),
                  "checks": observed.get("checks", 0), "failures": observed.get("failures"),
                  "pid": observed.get("observations", {}).get("pid"),
                  "evidence_sha256": digest(evidence) if evidence.exists() else None}
        result["passed"] = exit_code == 0 and result["checks"] > 0 and result["failures"] == 0
        results.append(result)
        print(json.dumps(result), flush=True)
        if not result["passed"]:
            break
    after = identities()
    try:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=args.repo, text=True).strip()
    except (FileNotFoundError, subprocess.CalledProcessError):
        head = None
    report = {"schema": 1, "scope": "Real native + durable Store + fresh-process integrity fixture; no Main/graphics claim",
              "platform": platform.platform(), "source_head": head, "before": before, "after": after,
              "inputs_unchanged": before == after, "runs": results,
              "passed": before == after and len(results) == 2 and all(result["passed"] for result in results)}
    (args.output / "report.json").write_text(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
