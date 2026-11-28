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
BOUNDARIES = ("before_capture", "before_snapshot", "queued_dirty", "after_checkpoint", "after_stage", "after_previous", "before_publish", "after_publish", "newer_dirty_after_durable")
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|(?m:^ERROR:)")
MARKER = "GEN006_RAMCACHE_BARRIER "


def live_native_identity(launcher_pid: int, observed_pid: int) -> dict:
    """Prove whether stdout came from Godot itself or its Windows console child."""
    if type(observed_pid) is not int or observed_pid < 1:
        raise RuntimeError("Native Godot stdout has no valid native operating-system PID")
    if observed_pid == launcher_pid:
        return {"launcher_pid":launcher_pid,"native_pid":observed_pid,"relationship":"direct"}
    if os.name != "nt":
        raise RuntimeError("Native PID differs from the launched Linux process")
    query = f"(Get-CimInstance Win32_Process -Filter 'ProcessId = {observed_pid}').ParentProcessId"
    parent = subprocess.run(["powershell.exe","-NoProfile","-NonInteractive","-Command",query],
                            stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=20)
    if parent.returncode or not parent.stdout.strip().isdigit() or int(parent.stdout.strip()) != launcher_pid:
        raise RuntimeError("Observed Windows Godot PID is not the live native child of its console launcher")
    return {"launcher_pid":launcher_pid,"native_pid":observed_pid,
            "parent_pid":int(parent.stdout.strip()),"relationship":"windows-console-child"}



def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def command(engine: Path, project: Path, profile: Path, mode: str, extra: list[str]) -> list[str]:
    return [str(engine), "--headless", "--path", str(project), "--script", "tests/test_persistent_area_writeback.gd", "--",
            f"--writeback-profile={profile}", f"--writeback-mode={mode}", *extra]


def recover(engine: Path, project: Path, profile: Path, directory: Path, expected: int, timeout: int) -> dict:
    """Restore and independently inspect the manifest and actual native bytes."""
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
    native_pid = values.get("pid")
    printed_pid = re.search(r"\bpid=(\d+)\b", str(receipt.get("original","")))
    if values.get("failures") != 0 or values.get("mode") != "verify" or values.get("checks", 0) < 8 \
            or type(native_pid) is not int or native_pid < 1 \
            or printed_pid is None or int(printed_pid[1]) != native_pid \
            or (os.name != "nt" and native_pid != child.pid) \
            or values.get("checks") != receipt["checks"]:
        raise RuntimeError("Fresh recovery receipt is incomplete")
    native = values["events"][-1]
    manifest = native["fresh_owner_manifest"]
    area_clock, areas = manifest["clock"]["areas"], manifest["areas"]
    revision = 2 if expected == 4 else 1
    if native.get("native_tick") != expected or manifest["clock"]["game_ticks"] != expected \
            or manifest.get("revision") != revision or set(areas) != {"a", "b", "c"} \
            or set(area_clock) != {"a", "b", "c"}:
        raise RuntimeError("Recovered durable revision/native/game-time boundary differs from independent oracle")
    for id in ("a", "b", "c"):
        entry, clock = areas[id], area_clock[id]
        target_tick = expected if id == "a" else 0
        mutation = 1 if id == "a" and expected == 4 else 0
        if entry.get("area_id") != id or entry.get("completed_tick") != target_tick \
                or entry.get("mutation_generation") != mutation or clock.get("native_ticks") != target_tick \
                or clock.get("accounted_ticks") != target_tick \
                or re.fullmatch(r"[0-9a-f]{32}", str(entry.get("incarnation", ""))) is None \
                or any(re.fullmatch(r"[0-9a-f]{64}", str(entry.get(field, ""))) is None
                    for field in ("native_sha256", "authoring_sha256", "authored_source_sha256",
                                  "physics_profile_sha256", "policy_sha256")):
            raise RuntimeError(f"Durable area {id} identity, mutation or clock oracle failed")
    if areas["a"]["native_sha256"] != native["native_sha256"]:
        raise RuntimeError("Restored real native capsule differs from manifest's immutable checkpoint")
    stable = {"revision":revision, "game_ticks":expected, "clock":manifest["clock"],
              "areas":{id:{k:areas[id][k] for k in ("area_id","generation","incarnation",
                  "mutation_generation","completed_tick","native_sha256","authoring_sha256",
                  "authored_source_sha256","physics_profile_sha256","policy_sha256")} for id in ("a","b","c")}}
    return {"kind":"fresh_process_recovery", "pid":native_pid, "launcher_pid":child.pid, "observed_pid":native_pid, "argv":argv,
            "exit_code":child.returncode, "elapsed_s":time.monotonic()-started, "checks":receipt["checks"],
            "expected_tick":expected, "native_sha256":native["native_sha256"], "physical_hash":native["physical_hash"],
            "session_id":manifest["session_id"], "durable_oracle":stable, "evidence_sha256":sha(evidence),
            "log_sha256":sha(directory/"reopen.log"), "ok":True}


def seed_published_checkpoint(engine: Path, project: Path, profile: Path, directory: Path, timeout: int) -> dict:
    """Produce a real acknowledged tick-4 checkpoint in its own successful process."""
    folder = directory / "seed"
    folder.mkdir()
    argv = command(engine, project, profile, "seed", [])
    child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        output, _ = child.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        child.kill()
        output, _ = child.communicate()
        (folder / "seed.log").write_bytes(output)
        raise RuntimeError("Independent native seed process exceeded watchdog")
    (folder / "seed.log").write_bytes(output)
    text = output.decode("utf-8", errors="replace")
    if child.returncode != 0 or ERRORS.search(text):
        raise RuntimeError("Independent durable seed failed before process-death qualification")
    receipt = completion(text, "GEN006_RAMCACHE_WRITEBACK")
    seed_pid_match = re.search(r"\bpid=(\d+)\b",str(receipt.get("original","")))
    if seed_pid_match is None:
        raise RuntimeError("Native durable seed has no independently printed process identity")
    seed_native_pid = int(seed_pid_match[1])
    if seed_native_pid < 1 or (os.name != "nt" and seed_native_pid != child.pid):
        raise RuntimeError("Durable seed native process differs from its actual launcher")
    baseline = recover(engine, project, profile, folder, 4, timeout)
    if baseline["pid"] == child.pid or baseline["durable_oracle"]["revision"] != 2:
        raise RuntimeError("Seed's acknowledged native checkpoint was not independently durable")
    return {"pid":seed_native_pid, "launcher_pid":child.pid, "argv":argv, "exit_code":child.returncode,
            "checks":receipt["checks"], "log_sha256":sha(folder/"seed.log"),
            "baseline":baseline, "ok":True}


def kill_at_boundary(engine: Path, project: Path, profile: Path, directory: Path, boundary: str, timeout: int) -> dict:
    seed = seed_published_checkpoint(engine,project,profile,directory,timeout) \
        if boundary == "newer_dirty_after_durable" else None
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
    needed = {"before_snapshot","queued_dirty"} if boundary == "queued_dirty" else {boundary}
    witnesses: dict[str,dict] = {}
    failure: str | None = None
    forced_termination = False
    native_identity: dict = {}
    try:
        while time.monotonic()-started < timeout:
            try:
                line = observed.get(timeout=min(0.5, max(0.001, timeout-(time.monotonic()-started))))
            except queue.Empty:
                continue
            if line is None:
                failure = "Publisher ended before all required real process-death barriers"
                break
            text = line.decode("utf-8", errors="replace")
            if ERRORS.search(text):
                failure = "Publisher emitted an engine/script error before the crash boundary"
                break
            if text.startswith(MARKER):
                marker = json.loads(text[len(MARKER):])
                phase = marker.get("phase")
                if phase not in needed or phase in witnesses \
                        or type(marker.get("pid")) is not int or marker["pid"] < 1 \
                        or (os.name != "nt" and marker["pid"] != child.pid) \
                        or not re.fullmatch(r"[0-9a-f]{32}", str(marker.get("session_id", ""))):
                    failure = "Process-death barrier has mismatched phase/session/process identity"
                    break
                if witnesses and marker["session_id"] != next(iter(witnesses.values()))["session_id"]:
                    failure = "Asynchronous and Main process-death barriers identify different sessions"
                    break
                witnesses[phase] = marker
                if set(witnesses) == needed:
                    break
        else:
            failure = "Publisher never reached the complete requested crash boundaries"
        if failure is None and boundary in witnesses:
            try:
                native_identity = live_native_identity(child.pid,int(witnesses[boundary]["pid"]))
            except Exception as error:
                failure = str(error)
    finally:
        if child.poll() is None:
            if os.name == "nt":
                killed = subprocess.run(["taskkill.exe","/F","/T","/PID",str(child.pid)],
                                        stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
                if killed.returncode != 0:
                    failure = "Windows process-tree kill failed: " + killed.stderr.decode(errors="replace")
            else:
                child.kill()
            forced_termination = True
        child.wait(timeout=30)
        reader.join(timeout=10)
        log = directory / "killed.log"
        log.write_bytes(b"".join(chunks))
    marker = witnesses.get(boundary)
    if failure or marker is None or set(witnesses) != needed or child.returncode == 0 or not forced_termination \
            or reader.is_alive() or ERRORS.search(log.read_text(encoding="utf-8",errors="replace")):
        raise RuntimeError(failure or "Missing positively observed real process-death boundary")
    if seed and (seed["baseline"]["session_id"] != marker["session_id"] \
            or marker.get("revision") != 2 or marker.get("live_native_tick") != 6 \
            or marker.get("durable_native_tick") != 4):
        raise RuntimeError("Post-seed crash did not establish a newer dirty native generation")
    if boundary in ("before_capture","queued_dirty") and (
            marker.get("live_native_tick") != (6 if boundary == "queued_dirty" else 4) \
            or marker.get("durable_native_tick") != 0):
        raise RuntimeError("Prepublication crash did not witness actual newer dirty native work")
    if boundary == "queued_dirty" and marker.get("queued_requests") != 1:
        raise RuntimeError("Queued write-behind crash lacks coalesced unacknowledged work")
    value = {"kind":"intentional_process_death", "pid":marker["pid"], "launcher_pid":child.pid,
            "native_identity":native_identity, "argv":argv, "forced_termination":True,
            "exit_code":child.returncode, "elapsed_s":time.monotonic()-started, "observed_barrier":marker,
            "barrier_witnesses":list(witnesses.values()), "log_sha256":sha(log), "ok":True}
    if seed:
        value["seed"] = seed
    return value


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
            expected = 4 if boundary in ("after_publish", "newer_dirty_after_durable") else 0
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
            if (repeat["session_id"],repeat["native_sha256"],repeat["durable_oracle"]) != (recovered["session_id"],recovered["native_sha256"],recovered["durable_oracle"]):
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
