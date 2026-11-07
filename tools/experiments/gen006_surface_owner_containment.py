#!/usr/bin/env python3
"""GEN-006 real-native regression: isolate unsupported surface ticks and preserve edits.

This is the repaired acceptance successor to experimental support PR #507's
expected-crash fixture. It tests one REAL compiled C++ controller and its
native World objects per process, not a mock or synthetic checkpoint.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def require(value: bool, reason: str) -> None:
    if not value:
        raise AssertionError(reason)


class NativeService:
    def __init__(self, exe: Path, root: Path, evidence: Path,
                 label: str, workers: int) -> None:
        self.workers = workers
        self.ipc = evidence / (label + "-ipc")
        self.ipc.mkdir(parents=True, exist_ok=False)
        self.stdout_path = evidence / (label + "-stdout.txt")
        self.stderr_path = evidence / (label + "-stderr.txt")
        # Opening the log files in the parent and immediately closing them
        # leaves the child with valid inherited descriptors on both OSes.
        with self.stdout_path.open("w", encoding="utf-8") as stdout, \
             self.stderr_path.open("w", encoding="utf-8") as stderr:
            self.proc = subprocess.Popen(
                [str(exe), "--serve", str(root), str(self.ipc),
                 str(workers), "2"],
                stdout=stdout, stderr=stderr, text=True,
            )
        self.seq = 0
        ready = self._await(self.ipc / "ready.txt", 12.0)
        match = re.search(
            r"GEN006_STREAM_SERVER_READY pid=(\d+) configured_workers=(\d+) tick_hz=2",
            ready,
        )
        require(match is not None, "native ready receipt invalid: " + ready)
        require(int(match.group(1)) == self.proc.pid and
                int(match.group(2)) == workers, "native PID/workers changed")
        self.pid = self.proc.pid

    def _await(self, path: Path, timeout: float = 8.0) -> str:
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if path.is_file():
                return path.read_text(encoding="utf-8", errors="replace")
            if self.proc.poll() is not None:
                raise AssertionError(
                    "native owner died pid={} rc={} stderr={}".format(
                        self.proc.pid, self.proc.returncode,
                        self.stderr_path.read_text(
                            encoding="utf-8", errors="replace")[-1800:]
                    )
                )
            time.sleep(0.02)
        raise AssertionError("native response timeout: " + str(path))

    def request(self, commands: str) -> str:
        require(self.proc.poll() is None, "native process already died")
        self.seq += 1
        (self.ipc / "response.txt").unlink(missing_ok=True)
        tmp = self.ipc / "request.staging"
        require(not (self.ipc / "request.txt").exists(), "outstanding request")
        tmp.write_text("SEQ {}\n{}\n".format(self.seq, commands),
                       encoding="utf-8")
        os.replace(tmp, self.ipc / "request.txt")
        receipt = self._await(self.ipc / "response.txt")
        require(receipt.startswith("SEQ {}\n".format(self.seq)),
                "wrong response sequence")
        require("GEN006_STREAM_SERVER_STATE pid={}".format(self.pid)
                in receipt, "request switched native PID")
        return receipt

    def stop(self) -> None:
        response = self.request("quit")
        require("REFUSED " not in response, "quit request refused")
        self.proc.wait(timeout=8)
        require(self.proc.returncode == 0,
                "graceful owner shutdown returned " + str(self.proc.returncode))
        stopped = (self.ipc / "stopped.txt").read_text(encoding="utf-8")
        require("GEN006_STREAM_SERVER_STOPPED pid={}".format(self.pid)
                in stopped, "durable save-all stopped receipt absent")

    def close(self) -> None:
        if self.proc.poll() is None:
            self.proc.kill()
        self.proc.wait(timeout=5)


def safe_cell_intent(owner: NativeService) -> int:
    output = owner.request("focus -2 2\ninspect 5 5")
    cells = [line for line in output.splitlines()
             if line.startswith("CELL chunk=(-2,2) local=(5,5)")]
    require(len(cells) == 1, "no real-native signed cell readback")
    match = re.search(r"\bintent=(\d+)\b", cells[0])
    require(match is not None, "native Empty-intent readback absent")
    return int(match.group(1))


def edit_safe_cell(owner: NativeService) -> None:
    receipt = owner.request("focus -2 2\ndig 5 5\ninspect 5 5")
    require("REFUSED " not in receipt and
            "CELL chunk=(-2,2) local=(5,5)" in receipt and
            "intent=1" in receipt, "live native Empty edit did not apply")


def status_line(status: str, c: tuple[int, int]) -> str:
    marker = "chunk=({},{})".format(*c)
    matches = [s for s in status.splitlines()
               if s.startswith("  chunk=") and marker in s]
    require(len(matches) == 1,
            "missing or repeated native resident {} in {}".format(marker, status))
    return matches[0]


def tick_index(status: str, c: tuple[int, int]) -> int:
    line = status_line(status, c)
    m = re.search(r"\bticks=(\d+)\b", line)
    require(m is not None, "native tick index unavailable: " + line)
    return int(m.group(1))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--logs", type=Path, required=True)
    parser.add_argument("--workers", type=int, choices=(1, 4), required=True)
    args = parser.parse_args()

    exe = args.exe.resolve(strict=True)
    require(not args.root.exists(), "fresh save root required")
    require(not args.logs.exists(), "fresh logs root required")
    root = args.root.resolve()
    logs = args.logs.resolve()
    logs.mkdir(parents=True)
    owner: NativeService | None = None

    try:
        # Positive process control: normal quit/restart persists an Empty tombstone.
        normal_root = root / "normal"
        owner = NativeService(exe, normal_root, logs, "normal-first", args.workers)
        edit_safe_cell(owner)
        require(safe_cell_intent(owner) == 1, "normal edit intent absent")
        owner.stop()
        owner = NativeService(exe, normal_root, logs, "normal-restart", args.workers)
        require(safe_cell_intent(owner) == 1,
                "normal native restart lost Empty intent")
        owner.stop()
        owner = None

        # Reproduce the identical real surface-triggering workload of PR #507.
        surface_root = root / "surface"
        owner = NativeService(exe, surface_root, logs, "surface-first", args.workers)
        edit_safe_cell(owner)
        original_pid = owner.pid
        require(safe_cell_intent(owner) == 1, "pre-pin unsaved edit missing")
        first = owner.request("status")
        first_safe_tick = tick_index(first, (-2, 2))
        admission = owner.request("focus -2 1")
        require("GENERATE x=-2 y=1 resident=2" in admission,
                "native surface chunk not generated/admitted")
        require("REFUSED " not in admission, "surface focus prematurely refused")
        # The unsupported surface should try and fail at a real autonomous tick,
        # roll back its native CYPS checkpoint and become explicitly pinned.
        pinned = ""
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            status = owner.request("status")
            surface = status_line(status, (-2, 1))
            safe = status_line(status, (-2, 2))
            if "pinned=1" in surface:
                require("reason=GEN006_UNSUPPORTED_NATIVE_TICK" in surface,
                        "surface pin has no explicit reason")
                require("pinned=0" in safe,
                        "healthy native resident incorrectly quarantined")
                pinned = status
                break
            time.sleep(0.10)
        require(bool(pinned), "real native surface never produced visible pin")

        # Crucially: same native PID, safe World still ticking while the
        # quarantined World cannot perform another partial mutation.
        pinned_surface_tick = tick_index(pinned, (-2, 1))
        time.sleep(1.20)
        later = owner.request("status")
        require(owner.proc.poll() is None and owner.pid == original_pid,
                "unsupported native tick killed/restarted the owner")
        require("pinned=1" in status_line(later, (-2, 1)),
                "failed native World became silently unpinned")
        require(tick_index(later, (-2, 1)) == pinned_surface_tick,
                "quarantined native shard was ticked again")
        require(tick_index(later, (-2, 2)) > first_safe_tick,
                "healthy native shard stopped after unrelated surface failure")
        require(safe_cell_intent(owner) == 1,
                "acknowledged in-memory Empty intent lost after surface pin")

        # Normal save-all after the refusal and fresh native process must
        # preserve the old safe tombstone; never regenerate over it.
        owner.stop()
        owner = NativeService(exe, surface_root, logs, "surface-restart", args.workers)
        require(safe_cell_intent(owner) == 1,
                "cross-process restart lost retained Empty edit after surface pin")
        owner.stop()
        owner = None

        log = (logs / "surface-first-stderr.txt").read_text(
            encoding="utf-8", errors="replace")
        require("SIMULATION_PIN chunk=(-2,1)" in log,
                "actual native pin diagnostic was not emitted")
        print("GEN006_SURFACE_OWNER_CONTAINMENT_PASS"
              " configured_workers={} native_pid_survived=1"
              " unsupported_surface_pinned=1"
              " safe_native_ticks_continued=1"
              " Empty_intent_restart=1"
              " separate_native_processes=1"
              " surface=(-2,1) safe=(-2,2)"
              .format(args.workers))
        return 0
    finally:
        if owner is not None:
            owner.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, subprocess.SubprocessError) as exc:
        print("GEN006_SURFACE_OWNER_CONTAINMENT_FAIL " + str(exc),
              file=sys.stderr)
        raise SystemExit(1)
