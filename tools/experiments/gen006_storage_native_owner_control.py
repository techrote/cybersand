#!/usr/bin/env python3
"""G6J1 source-matched native-owner hard-crash CONTROL (full CYPS publication).

Runs the actual pinned #486 persistent native service at 30 Hz, sends real
edits through its file IPC, kills the *native World owner process* after
durable ACK (without quit/save_all), then restores in an independent native
process. This measures the incumbent full-checkpoint IPC ACK path ONLY.
It does not run G6J1 inside the native owner, establish journal speedup,
or guarantee recovery of subsequent uncheckpointed simulation ticks.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

from gen006_storage_native_pilot import (
    ACK, CHUNK, COMMANDS, native_cyps, native_record, require, run_native, status,
)

READY = re.compile(r"GEN006_STREAM_SERVER_READY pid=(\d+) configured_workers=(\d+) tick_hz=(\d+)")
STATE = re.compile(r"GEN006_STREAM_SERVER_STATE pid=(\d+) request=(\d+) continuous_ticks=(\d+)")
TIMEOUT_SECONDS = 75


def wait_file(path: Path, process: subprocess.Popen, deadline: float) -> str:
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise AssertionError("G6J_OWNER_EXITED_BEFORE_ACK")
        if path.is_file():
            try:
                return path.read_text(encoding="utf-8")
            except PermissionError:
                # A Windows filesystem read can race the publisher's close.
                pass
        time.sleep(0.005)
    raise AssertionError("G6J_OWNER_IPC_TIMEOUT: " + str(path))


def send_request(ipc: Path, process: subprocess.Popen, seq: int,
                 command: str) -> tuple[str, float]:
    request = ipc / "request.txt"
    staged = ipc / "request.python-stage"
    response = ipc / "response.txt"
    require(not request.exists() and not staged.exists(),
            "G6J_OWNER_REQUEST_BACKLOG_REFUSED")
    response.unlink(missing_ok=True)
    staged.write_text("SEQ {}\n{}\n".format(seq, command), encoding="utf-8")
    start = time.perf_counter_ns()
    os.replace(staged, request)
    packet = wait_file(response, process, time.monotonic() + TIMEOUT_SECONDS)
    elapsed_ms = (time.perf_counter_ns() - start) / 1_000_000
    require(packet.startswith("SEQ {}\n".format(seq)) and
            "REFUSED " not in packet and "GEN006_NATIVE_SHARDED_STREAM_FAIL" not in packet,
            "G6J_OWNER_REQUEST_REFUSED: " + packet[-1500:])
    fields = STATE.findall(packet)
    require(len(fields) == 1 and int(fields[0][0]) == process.pid and
            int(fields[0][1]) == seq, "G6J_OWNER_RESPONSE_IDENTITY_REFUSED")
    return packet, elapsed_ms


def percentile_nearest(samples: list[float], fraction: float) -> float:
    ordered = sorted(samples)
    index = max(0, min(len(ordered) - 1,
                       (int(len(ordered) * fraction + 0.999999999) - 1)))
    return ordered[index]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--workers", required=True, type=int, choices=(1, 4))
    parser.add_argument("--native-sha", required=True)
    args = parser.parse_args()

    exe = args.exe.resolve(strict=True)
    work = args.root.resolve()
    require(not work.exists(), "G6J_OWNER_CONTROL_REQUIRES_FRESH_WORKROOT")
    work.mkdir(parents=True)
    native_root = work / "world"
    ipc = work / "ipc"
    native_root.mkdir()
    ipc.mkdir()

    process = subprocess.Popen(
        [str(exe), "--serve", str(native_root), str(ipc), str(args.workers), "30"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, errors="replace")
    killed = False
    try:
        ready = wait_file(ipc / "ready.txt", process,
                          time.monotonic() + TIMEOUT_SECONDS)
        match = READY.search(ready)
        require(match is not None and
                (int(match[1]), int(match[2]), int(match[3])) ==
                (process.pid, args.workers, 30),
                "G6J_OWNER_READY_IDENTITY_REFUSED")
        # Separate IPC round trips ensure response publication follows every
        # genuine native durable edit ACK, not a one-shot post-save assertion.
        reply, _ = send_request(ipc, process, 1, "focus -1 -3\nstatus")
        require("chunk=(-1,-3)" in reply, "G6J_OWNER_FOCUS_REFUSED")
        latencies = []
        acknowledgments = []
        for i, (command, kind, x, y, amount, temp) in enumerate(COMMANDS):
            response, elapsed_ms = send_request(
                ipc, process, i + 2, command + "\nstatus")
            rows = [tuple(map(int, row)) for row in ACK.findall(response)]
            require(len(rows) == 1 and rows[0][0:2] == (x, y),
                    "G6J_OWNER_EDIT_ACK_MISSING")
            receipt = rows[0]
            require(status(response) == (receipt[2], receipt[3], receipt[4]),
                    "G6J_OWNER_EDIT_STATUS_DRIFT")
            require(native_record(native_root).is_file(),
                    "G6J_OWNER_ACK_WITHOUT_PERSISTED_CHECKPOINT")
            disk_gen, cyps = native_cyps(native_record(native_root).read_bytes())
            require(disk_gen == receipt[2] and cyps.startswith(b"CYPS"),
                    "G6J_OWNER_ACK_CHECKPOINT_GENERATION_DRIFT")
            if acknowledgments:
                require(receipt[2] > acknowledgments[-1][2] and
                        receipt[4] >= acknowledgments[-1][4],
                        "G6J_OWNER_NONMONOTONIC_NATIVE_EDIT")
            acknowledgments.append(receipt)
            latencies.append(elapsed_ms)

        # The last record must already be committed. Do not send "quit",
        # perform save_all, or otherwise request graceful owner shutdown.
        last = acknowledgments[-1]
        before = native_record(native_root).read_bytes()
        require(native_cyps(before)[0] == last[2],
                "G6J_OWNER_PREKILL_GENERATION_REFUSED")
        record_hash = hashlib.sha256(before).hexdigest()
        process.kill()  # SIGKILL on Linux, TerminateProcess on Windows
        killed = True
        stdout, stderr = process.communicate(timeout=15)
        (work / "killed-owner.stdout.txt").write_text(stdout, encoding="utf-8")
        (work / "killed-owner.stderr.txt").write_text(stderr, encoding="utf-8")
        require(process.returncode != 0 and
                not (ipc / "stopped.txt").exists(),
                "G6J_OWNER_NOT_AN_ABRUPT_TERMINATION")
        require(native_record(native_root).read_bytes() == before,
                "G6J_OWNER_DISK_CHANGED_AFTER_CRASH")

        # An entirely new native World process must restore exactly the
        # *acknowledged* state. Later in-memory ticks need not have been
        # persisted and are NOT claimed crash-recoverable.
        restored_out, restored_record = run_native(
            exe, native_root, work, [], args.workers, "restored-after-kill")
        require(status(restored_out) == (last[2], last[3], last[4]),
                "G6J_OWNER_CRASH_RESTORED_PHYSICAL_HASH_DRIFT")
        require(restored_record == before,
                "G6J_OWNER_RESTORED_CYPS_BYTES_DRIFT")
        require("local=(5,5)" in restored_out and
                "local=(18,30)" in restored_out and
                "liquid=17 temp=417 intent=1" in restored_out,
                "G6J_OWNER_RESTORED_WATER_OR_ERASURE_REFUSED")
        summary = {
            "native_reference_sha": args.native_sha,
            "workers": args.workers,
            "tick_hz": 30,
            "owner_pid": process.pid,
            "owner_returncode": process.returncode,
            "edits": len(acknowledgments),
            "native_ack_generations": [row[2] for row in acknowledgments],
            "native_ack_ticks": [row[4] for row in acknowledgments],
            "final_native_physical_hash": last[3],
            "ack_ipc_roundtrip_ms": latencies,
            "p50_ms": percentile_nearest(latencies, .50),
            "p95_ms": percentile_nearest(latencies, .95),
            "p99_ms": percentile_nearest(latencies, .99),
            "durable_checkpoint_bytes": len(before),
            "durable_checkpoint_sha256": record_hash,
            "after_kill_record_equal": True,
            "restart_cyps_bytes_equal": True,
            "journal_integrated": False,
            "latency_scope": "IPC round-trip INCLUDING native full-CYPS clone/fsync",
        }
        (work / "native-owner-crash-control.json").write_text(
            json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        print("GEN006_G6J1_NATIVE_OWNER_CRASH_CONTROL_PASS"
              " workers={} native_sha={} killed_pid={} edit_acks={}"
              " restored_generation={} restored_tick={}"
              " restored_hash={} snapshot_bytes={}"
              " ipc_p50_ms={:.3f} ipc_p95_ms={:.3f} ipc_p99_ms={:.3f}"
              " no_journal_speedup_claim=1".format(
                  args.workers, args.native_sha, process.pid, len(acknowledgments),
                  last[2], last[4], last[3], len(before),
                  summary["p50_ms"], summary["p95_ms"], summary["p99_ms"]))
        return 0
    finally:
        if process.poll() is None:
            process.kill()
        try:
            stdout, stderr = process.communicate(timeout=15)
            if not killed:
                (work / "failed-owner.stdout.txt").write_text(stdout, encoding="utf-8")
                (work / "failed-owner.stderr.txt").write_text(stderr, encoding="utf-8")
        except subprocess.TimeoutExpired:
            pass


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ValueError, OSError, subprocess.SubprocessError) as exc:
        import sys
        print("GEN006_G6J1_OWNER_CONTROL_FAIL " + str(exc), file=sys.stderr)
        raise SystemExit(1)
