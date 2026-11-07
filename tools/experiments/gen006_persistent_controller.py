#!/usr/bin/env python3
"""GEN-006 persistent native controller acceptance.

Launches one long-lived native process, drives file-backed request/response IPC,
proves autonomous ticks continue without command-triggered process restarts,
then crosses the LRU residency budget and verifies edited native state survives.
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import subprocess
import time

STATE = re.compile(
    r"GEN006_STREAM_SERVER_STATE pid=(\d+) request=(\d+) "
    r"continuous_ticks=(\d+) active=\((-?\d+),(-?\d+)\) resident=(\d+)"
)
READY = re.compile(
    r"GEN006_STREAM_SERVER_READY pid=(\d+) configured_workers=(\d+) tick_hz=(\d+)"
)


def require(value: bool, why: str) -> None:
    if not value:
        raise AssertionError(why)


def wait_file(path: pathlib.Path, proc: subprocess.Popen[str],
              timeout: float = 8.0) -> str:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.is_file():
            return path.read_text(encoding="utf-8", errors="replace")
        require(proc.poll() is None, f"native controller exited early: {proc.returncode}")
        time.sleep(0.005)
    raise AssertionError(f"timeout waiting for {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", required=True, type=pathlib.Path)
    parser.add_argument("--root", required=True, type=pathlib.Path)
    parser.add_argument("--ipc", required=True, type=pathlib.Path)
    parser.add_argument("--workers", required=True, type=int, choices=[1, 4])
    parser.add_argument("--tick-hz", type=int, default=30)
    args = parser.parse_args()

    exe = args.exe.resolve(strict=True)
    root = args.root.resolve()
    ipc = args.ipc.resolve()
    require(not root.exists(), "GEN006_PERSISTENT_REQUIRES_FRESH_ROOT")
    require(not ipc.exists(), "GEN006_PERSISTENT_REQUIRES_FRESH_IPC")
    ipc.mkdir(parents=True)

    stdout_path = ipc / "server.stdout.log"
    stderr_path = ipc / "server.stderr.log"
    with stdout_path.open("w", encoding="utf-8") as stdout, \
         stderr_path.open("w", encoding="utf-8") as stderr:
        proc = subprocess.Popen(
            [str(exe), "--serve", str(root), str(ipc),
             str(args.workers), str(args.tick_hz)],
            stdout=stdout, stderr=stderr, text=True,
        )
        try:
            ready_text = wait_file(ipc / "ready.txt", proc)
            ready = READY.search(ready_text)
            require(ready is not None, f"bad ready receipt: {ready_text}")
            native_pid = int(ready.group(1))
            require(native_pid == proc.pid,
                    f"PID mismatch receipt={native_pid} process={proc.pid}")
            require(int(ready.group(2)) == args.workers, "worker receipt mismatch")
            require(int(ready.group(3)) == args.tick_hz, "tick-rate receipt mismatch")

            sequence = 0

            def request(commands: str) -> tuple[str, re.Match[str]]:
                nonlocal sequence
                sequence += 1
                request_path = ipc / "request.txt"
                response_path = ipc / "response.txt"
                staging = ipc / "request.staging"
                response_path.unlink(missing_ok=True)
                require(not request_path.exists(), "previous request still outstanding")
                staging.write_text(
                    f"SEQ {sequence}\n{commands.rstrip()}\n",
                    encoding="utf-8",
                )
                os.replace(staging, request_path)
                response = wait_file(response_path, proc)
                response_path.unlink(missing_ok=True)
                require(response.startswith(f"SEQ {sequence}\n"),
                        f"sequence mismatch: {response[:80]}")
                require("REFUSED " not in response,
                        f"native request refused: {response}")
                state = STATE.search(response)
                require(state is not None, f"missing server state: {response}")
                require(int(state.group(1)) == native_pid,
                        "native process changed between requests")
                return response, state

            initial, state1 = request(
                "focus -1 -3\n"
                "wall 8 8\n"
                "wall 18 31\nwall 17 30\nwall 19 30\n"
                "watertemp 18 30 17 417\n"
                "inspect 8 8\ninspect 18 30\nrender\nstatus"
            )
            require("intent=1" in initial, "native edit intent absent")
            require("liquid=17 temp=417 intent=1" in initial,
                    "blocked Water17/temperature417 absent")
            require((root / "gen006-current.rgba").stat().st_size == 64 * 64 * 4,
                    "native RGBA frame missing")
            ticks1 = int(state1.group(3))

            time.sleep(max(0.20, 4.0 / float(args.tick_hz)))
            later, state2 = request("focus -1 -3\ninspect 8 8\nrender\nstatus")
            ticks2 = int(state2.group(3))
            require(ticks2 >= ticks1 + 2,
                    f"continuous native simulation did not advance: {ticks1}->{ticks2}")
            require("intent=1" in later, "Wall edit vanished during continuous ticks")

            crossed, state3 = request(
                "focus 0 -3\nfocus 24 -3\nfocus -1 -3\n"
                "inspect 8 8\ninspect 18 30\nrender\nstatus"
            )
            require("EVICT " in crossed and "RELOAD " in crossed,
                    "camera-driven LRU eviction/reload receipts missing")
            require("intent=1" in crossed, "restored edited Wall intent missing")
            require("liquid=17 temp=417 intent=1" in crossed,
                    "restored blocked Water17 state missing")
            require(int(state3.group(1)) == native_pid, "controller PID changed")

            stopped, _ = request("quit")
            require("REFUSED " not in stopped, "quit request refused")
            proc.wait(timeout=8)
            require(proc.returncode == 0, f"controller exit code {proc.returncode}")
            stop_text = wait_file(ipc / "stopped.txt", proc)
            require(f"pid={native_pid}" in stop_text, "stopped receipt PID mismatch")

            stdout.flush()
            stderr.flush()
            server_err = stderr_path.read_text(encoding="utf-8", errors="replace")
            require("REFUSED " not in server_err, f"server stderr refusal: {server_err}")
            print(
                "GEN006_PERSISTENT_CONTROLLER_PASS"
                f" configured_workers={args.workers}"
                f" pid={native_pid}"
                f" same_process=1"
                f" continuous_ticks={ticks2}"
                " camera_eviction_reload=1"
                " edited_state_restored=1"
                " native_rgba=1"
            )
            return 0
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
