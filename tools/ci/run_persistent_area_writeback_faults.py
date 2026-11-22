#!/usr/bin/env python3
"""Kill actual asynchronous CYPA publishers, then verify native recovery anew.

Each boundary uses an independent isolated profile. A nonzero forced-termination
row is never classified as a normal passing test. The matching barrier and fresh
recovery process establish the expected old/new durable frontier instead.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import subprocess
import threading
import time

from run_persistent_areas_qualification import completion, source_identity

ROOT = Path(__file__).resolve().parents[2]
BOUNDARIES = ("before_snapshot", "after_checkpoint", "after_stage", "after_previous", "before_publish", "after_publish")
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|(?m:^ERROR:)")
MARKER = "GEN006_RAMCACHE_BARRIER "


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def command(engine: Path, project: Path, profile: Path, mode: str, extra: list[str]) -> list[str]:
    return [str(engine), "--headless", "--path", str(project), "--script", "tests/test_persistent_area_writeback.gd", "--",
            f"--writeback-profile={profile}", f"--writeback-mode={mode}", *extra]


def recover(engine: Path, project: Path, profile: Path, directory: Path, expected: int, timeout: int) -> dict:
    evidence = directory / "recovered.json"
    argv = command(engine, project, profile, "verify", [f"--writeback-expected-tick={expected}", f"--writeback-evidence={evidence}"])
    started = time.monotonic()
    child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        output, _ = child.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        child.kill()
        output, _ = child.communicate()
        (directory / "reopen.log").write_bytes(output)
        raise RuntimeError("Fresh native recovery exceeded its watchdog")
    (directory / "reopen.log").write_bytes(output)
    text = output.decode("utf-8", errors="replace")
    if child.returncode != 0 or ERRORS.search(text):
        raise RuntimeError(f"Fresh native recovery failed: exit {child.returncode}")
    receipt = completion(text, "GEN006_RAMCACHE_WRITEBACK")
    values = json.loads(evidence.read_text(encoding="utf-8"))
    if values.get("failures") != 0 or values.get("mode") != "verify" or values.get("checks", 0) < 8 \
            or values.get("pid") != child.pid or values.get("checks") != receipt["checks"]:
        raise RuntimeError("Fresh recovery receipt is incomplete")
    native = values["events"][-1]
    if native.get("native_tick") != expected or native["fresh_owner_manifest"]["clock"]["game_ticks"] != expected:
        raise RuntimeError("Recovered native/accounted frontier differs from the requested publication boundary")
    return {"kind":"fresh_process_recovery", "pid":child.pid, "observed_pid":values["pid"], "argv":argv, "exit_code":child.returncode,
            "elapsed_s":time.monotonic()-started, "checks":receipt["checks"], "expected_tick":expected,
            "native_sha256":native["native_sha256"], "physical_hash":native["physical_hash"],
            "session_id":native["fresh_owner_manifest"]["session_id"], "evidence_sha256":sha(evidence),
            "log_sha256":sha(directory/"reopen.log"), "ok":True}


def kill_at_boundary(engine: Path, project: Path, profile: Path, directory: Path, boundary: str, timeout: int) -> dict:
    argv = command(engine, project, profile, "crash", [f"--writeback-barrier={boundary}"])
    started = time.monotonic()
    child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    observed: queue.Queue[bytes | None] = queue.Queue()
    chunks: list[bytes] = []

    def read_output() -> None:
        assert child.stdout is not None
        for line in iter(child.stdout.readline, b""):
            chunks.append(line)
            observed.put(line)
        observed.put(None)

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    marker: dict | None = None
    failure: str | None = None
    forced_termination = False
    try:
        while time.monotonic()-started < timeout:
            try:
                line = observed.get(timeout=min(0.5, max(0.001, timeout-(time.monotonic()-started))))
            except queue.Empty:
                continue
            if line is None:
                failure = "Publisher ended before the required crash boundary"
                break
            text = line.decode("utf-8", errors="replace")
            if ERRORS.search(text):
                failure = "Publisher emitted an engine/script error before the crash boundary"
                break
            if text.startswith(MARKER):
                marker = json.loads(text[len(MARKER):])
                if marker.get("phase") != boundary or marker.get("pid") != child.pid \
                        or not re.fullmatch(r"[0-9a-f]{32}", marker.get("session_id", "")):
                    failure = "Publisher barrier has a mismatched phase/session/process identity"
                break
        else:
            failure = "Publisher never reached the requested crash boundary"
    finally:
        if child.poll() is None:
            child.kill()
            forced_termination = True
        child.wait(timeout=30)
        reader.join(timeout=10)
        log = directory / "killed.log"
        log.write_bytes(b"".join(chunks))
    if failure or marker is None or child.returncode == 0 or not forced_termination \
            or reader.is_alive() or ERRORS.search(log.read_text(encoding="utf-8",errors="replace")):
        raise RuntimeError(failure or "Missing observed process-death boundary")
    return {"kind":"intentional_process_death", "pid":child.pid, "argv":argv, "forced_termination":True,
            "exit_code":child.returncode, "elapsed_s":time.monotonic()-started, "observed_barrier":marker,
            "log_sha256":sha(log), "ok":True}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT/"godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--boundaries", nargs="+", choices=BOUNDARIES, default=list(BOUNDARIES))
    parser.add_argument("--diagnostic", action="store_true", help="Allow an explicitly unqualified dirty-source development run")
    args = parser.parse_args()
    engine, project, evidence = args.godot.resolve(), args.project.resolve(), args.evidence.resolve()
    if args.timeout < 30 or args.timeout > 1800:
        parser.error("timeout must be between 30 and 1800 seconds")
    evidence.mkdir(parents=True, exist_ok=False)
    binary = project/"addons/cybersand_native/bin"/("cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
    before = source_identity(project)
    binary_hashes = {str(engine):sha(engine), str(binary):sha(binary)}
    result = {"schema":1,"diagnostic":args.diagnostic,"platform":os.name,"source_before":before,
              "source_commit":before["source_commit"],"source_tree":before["source_tree"],
              "engine_sha256":sha(engine),"native_sha256":sha(binary),
              "binaries_before":binary_hashes,"rows":[],"ok":False}
    write(evidence/"source-before.json",before)
    try:
        if not args.diagnostic and (before["local_delta"] or before["missing_source_inputs"]):
            raise RuntimeError("Qualification requires committed clean source and complete native/Godot inputs")
        for boundary in args.boundaries:
            directory = evidence/boundary
            directory.mkdir()
            profile = directory/"profile"
            death = kill_at_boundary(engine,project,profile,directory,boundary,args.timeout)
            death["boundary"] = boundary
            result["rows"].append(death)
            expected = 4 if boundary == "after_publish" else 0
            recovered = recover(engine,project,profile,directory,expected,args.timeout)
            recovered["boundary"] = boundary
            if recovered["session_id"] != death["observed_barrier"]["session_id"]:
                raise RuntimeError("Fresh process restored a different profile session")
            result["rows"].append(recovered)
            # A second independent reopen proves that recovery itself did not
            # reapply progression or publish a different session generation.
            repeated = directory/"repeat"
            repeated.mkdir()
            repeat = recover(engine,project,profile,repeated,expected,args.timeout)
            repeat["boundary"] = boundary
            if (repeat["session_id"],repeat["native_sha256"]) != (recovered["session_id"],recovered["native_sha256"]):
                raise RuntimeError("Repeated fresh recovery changed native authority")
            if len({death["pid"],recovered["pid"],repeat["pid"]}) != 3:
                raise RuntimeError("Process-death recovery did not retain three distinct observed process identities")
            result["rows"].append(repeat)
            write(evidence/"results.json",result)
        after = source_identity(project)
        result["source_after"] = after
        result["binaries_after"] = {str(engine):sha(engine),str(binary):sha(binary)}
        result["source_unchanged"] = before == after and binary_hashes == result["binaries_after"]
        if not result["source_unchanged"] and not args.diagnostic:
            raise RuntimeError("Source/runtime changed during process-death qualification")
        result["qualified_source"] = result["source_unchanged"] and not args.diagnostic
        result["ok"] = True
    except Exception as error:
        result["error"] = str(error)
    finally:
        write(evidence/"results.json",result)
    print(json.dumps({"ok":result["ok"],"qualified_source":result.get("qualified_source",False),
                      "rows":len(result["rows"]),"error":result.get("error"),"evidence":str(evidence)}))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
