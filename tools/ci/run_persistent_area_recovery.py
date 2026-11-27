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
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time

from run_persistent_areas_qualification import ERRORS, completion, direct_engine, source_identity

MARKER = "GEN006_NATIVE_FAILED_ACTIVE_RECOVERY"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_child(mode: str, pid: int, exit_code: int, output: str, observed: dict,
                   seed: dict | None = None) -> dict:
    """Bind the original completion and native receipt to the actual child."""
    if exit_code != 0 or ERRORS.search(output):
        raise RuntimeError("Recovery child failed or emitted an engine/script error")
    done = completion(output, MARKER)
    if not isinstance(observed, dict) or observed.get("schema") != 1 or observed.get("mode") != mode \
            or observed.get("failures") != 0 or type(observed.get("checks")) is not int or observed["checks"] < 1:
        raise RuntimeError("Recovery child did not produce a complete original receipt")
    native = observed.get("observations", {})
    if type(native.get("pid")) is not int or native["pid"] != pid \
            or any(done.get(key) != value for key, value in
                   {"mode": mode, "checks": observed["checks"], "failures": 0, "pid": pid}.items()):
        raise RuntimeError("Recovery completion, receipt and actual process identity differ")
    if mode == "seed":
        if native.get("active_failed") is not True or native.get("active_unsaved_empty_retained") is not True \
                or native.get("ordinary_save_all_claimed") is not False:
            raise RuntimeError("Recovery did not retain the actual failed active owner")
        states = native.get("expected", {})
    else:
        if not isinstance(seed, dict) or native.get("seed_pid") != seed.get("observations", {}).get("pid") \
                or native.get("seed_pid") == pid or native.get("manifest") != seed["observations"].get("manifest"):
            raise RuntimeError("Fresh recovery is not bound to the original independent seed process/manifest")
        states = native.get("restored", {})
        if states != seed["observations"].get("expected"):
            raise RuntimeError("Fresh recovery changed complete native identity or completed time")
    if not isinstance(states, dict) or set(states) != {"a", "b", "c"}:
        raise RuntimeError("Recovery omitted an independently retained area")
    for area, expected_tick in (("a", 0), ("b", 7), ("c", 3)):
        state = states[area]
        if not isinstance(state, dict) or state.get("tick") != expected_tick \
                or re.fullmatch(r"[0-9a-f]{64}", str(state.get("native_sha256", ""))) is None \
                or re.fullmatch(r"[0-9a-f]{16}", str(state.get("physical_hash", ""))) is None:
            raise RuntimeError("Recovery native identity or expected tick interval is incomplete")
    return done


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--native", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=180.0)
    parser.add_argument("--diagnostic", action="store_true", help="Permit explicitly unqualified dirty-source development")
    args = parser.parse_args()
    args.repo, args.godot, args.output = args.repo.resolve(), args.godot.resolve(), args.output.resolve()
    if not 30 <= args.timeout <= 1800:
        parser.error("timeout must be bounded from 30 through 1800 seconds")
    args.godot = direct_engine(args.godot, sys.platform)
    name = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
    installed_native = (args.repo / "godot/addons/cybersand_native/bin" / name).resolve()
    if args.native is None:
        args.native = installed_native
    args.native = args.native.resolve()
    if args.native != installed_native:
        parser.error("native identity must refer to the runtime actually installed in this project")
    if args.output.exists():
        parser.error("Output already exists; choose a fresh evidence directory")
    args.output.mkdir(parents=True, exist_ok=False)
    profile = args.output / "profile"
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
                "source_files": {path.relative_to(args.repo).as_posix(): digest(path) for path in source_files}}

    before = identities()
    source_before = source_identity(args.repo / "godot")
    source_before["source_inputs_sha256"]["tools/ci/run_persistent_area_recovery.py"] = digest(Path(__file__))
    results = []
    seed_path, seed_receipt, error = args.output / "seed.json", None, None
    env = dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1", XDG_DATA_HOME=str(args.output/"userdata"),
               APPDATA=str(args.output/"userdata"), LOCALAPPDATA=str(args.output/"localdata"))
    try:
        if not args.diagnostic and (source_before["local_delta"] or source_before["missing_source_inputs"]):
            raise RuntimeError("Qualification requires committed clean source and complete inputs")
        for mode in ("seed", "verify"):
            evidence, log = args.output / f"{mode}.json", args.output / f"{mode}.log"
            command = [str(args.godot), "--headless", "--path", str(args.repo / "godot"), "--script",
                       "res://tests/test_persistent_area_recovery.gd", "--", f"--recovery-mode={mode}",
                       f"--recovery-profile={profile}", f"--recovery-output={evidence}", f"--recovery-seed={seed_path}"]
            started = time.monotonic()
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
            timed_out = False
            try:
                output, _ = process.communicate(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                process.kill()
                output, _ = process.communicate(timeout=30)
            log.write_bytes(output)
            result = {"mode": mode, "command": command, "exit_code": process.returncode, "pid": process.pid,
                      "timed_out": timed_out, "elapsed_seconds": time.monotonic()-started,
                      "log": log.name, "log_sha256": digest(log), "evidence": evidence.name,
                      "evidence_sha256": digest(evidence) if evidence.is_file() else None, "passed": False}
            results.append(result)
            observed = json.loads(evidence.read_text(encoding="utf-8")) if evidence.is_file() else {}
            done = validate_child(mode, process.pid, process.returncode,
                                  output.decode("utf-8", errors="replace"), observed, seed_receipt)
            if timed_out:
                raise RuntimeError("Recovery process exceeded its finite watchdog")
            if mode == "seed":
                seed_receipt = observed
            else:
                if digest(seed_path) != results[0]["evidence_sha256"]:
                    raise RuntimeError("The original seed evidence changed during fresh recovery")
            result.update(passed=True, observed_pid=observed["observations"]["pid"], checks=done["checks"],
                          failures=done["failures"], completion=done)
            print(json.dumps(result), flush=True)
    except Exception as failure:
        error = str(failure)
        if results and not results[-1]["passed"]:
            results[-1]["error"] = error
    after = identities()
    source_after = source_identity(args.repo / "godot")
    source_after["source_inputs_sha256"]["tools/ci/run_persistent_area_recovery.py"] = digest(Path(__file__))
    source_unchanged = source_before == source_after
    if not source_unchanged and not args.diagnostic:
        error = "Source changed during qualification"
    report = {"schema": 1, "scope": "Real native + durable Store + fresh-process integrity fixture; no Main/graphics claim",
              "platform": platform.platform(), "source_head": source_before["source_commit"],
              "source_before": source_before, "source_after": source_after, "source_unchanged": source_unchanged,
              "diagnostic": args.diagnostic, "qualified_source": not args.diagnostic and source_unchanged and before == after,
              "before": before, "after": after,
              "inputs_unchanged": before == after, "runs": results,
              "error": error,
              "passed": error is None and before == after and len(results) == 2 and all(result["passed"] for result in results)}
    report["qualified_source"] = report["qualified_source"] and report["passed"]
    (args.output / "report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps({key:report[key] for key in ("passed", "qualified_source", "inputs_unchanged", "error")}),flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
