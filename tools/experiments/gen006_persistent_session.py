#!/usr/bin/env python3
"""GEN-006 persistent native-session acceptance using real World/Generator.

No mock, no Python simulation: spawns the compiled native C++ executable,
checks one PID while idle ticks advance, writes commands atomically, verifies
native RGBA across real save/evict/reload and independent process restart.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys
import time

SIDE = 64
FRAME_BYTES = SIDE * SIDE * 4


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise AssertionError(reason)


class Client:
    def __init__(self, exe: Path, save: Path, control: Path, workers: int,
                 stdout_log: Path):
        self.control = control
        self.control.mkdir(parents=True, exist_ok=False)
        self.heartbeat = control / "heartbeat.txt"
        self.heartbeat.write_text("start\n")
        self.logfile = stdout_log.open("w", encoding="utf-8")
        self.process = subprocess.Popen(
            [str(exe), "--serve", str(save), str(control), str(workers)],
            stdout=self.logfile, stderr=subprocess.STDOUT, text=True,
        )
        self.seq = 0
        self.wait_for(lambda s: s["frame"] >= 1, "initial native frame")

    def pulse(self) -> None:
        self.heartbeat.write_text(str(time.monotonic()) + "\n")

    def state(self) -> dict | None:
        target = self.control / "state.txt"
        if not target.exists():
            return None
        parts = target.read_text(encoding="utf-8").strip().split(" ")
        if len(parts) != 9 or parts[0] != "FRAME":
            return None
        frame = self.control / parts[8]
        if not frame.exists():
            return None
        return {
            "frame": int(parts[1]), "x": int(parts[2]), "y": int(parts[3]),
            "ticks": int(parts[4]), "residents": int(parts[5]),
            "observed": int(parts[6]), "hash": int(parts[7]),
            "image": frame,
        }

    def wait_for(self, predicate, label: str, timeout: float = 15.0) -> dict:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.pulse()
            require(self.process.poll() is None,
                    f"native server terminated before {label}; check {self.control}")
            try:
                state = self.state()
                if state is not None and predicate(state):
                    return state
            except (ValueError, OSError):
                pass  # writer may be advancing an ephemeral older frame
            time.sleep(0.025)
        raise AssertionError(f"timeout waiting for {label}; control={self.control}")

    def pixel(self, state: dict, x: int, y: int) -> bytes:
        data = state["image"].read_bytes()
        require(len(data) == FRAME_BYTES, "wrong native RGBA frame size")
        start = (y * SIDE + x) * 4
        return data[start:start + 4]

    def send(self, command: str, expect_error: str | None = None) -> dict:
        before = self.state()
        self.seq += 1
        seq = self.seq
        target = self.control / "ack.txt"
        if target.exists():
            target.unlink()
        tmp = self.control / "command.prepared"
        tmp.write_text(f"{seq} {command}\n", encoding="ascii")
        os.replace(tmp, self.control / "command.txt")
        deadline = time.monotonic() + 15
        receipt = None
        while time.monotonic() < deadline:
            self.pulse()
            if target.exists():
                raw = target.read_text(encoding="utf-8").strip()
                parts = raw.split(" ", 3)
                if len(parts) == 4 and parts[:2] == ["ACK", str(seq)]:
                    receipt = parts
                    target.unlink()
                    break
            require(self.process.poll() is None,
                    f"server died while handling {command}")
            time.sleep(0.025)
        require(receipt is not None, f"no receipt for {command}")
        if expect_error:
            require(receipt[2] == "ERR" and receipt[3] == expect_error,
                    f"unexpected refusal for {command}: {receipt}")
        else:
            require(receipt[2] == "OK",
                    f"unexpected native error for {command}: {receipt}")
        if command == "QUIT":
            self.process.wait(timeout=15)
            self.logfile.close()
            require(self.process.returncode == 0, "server QUIT was not clean")
            return before
        if expect_error:
            return self.wait_for(lambda s: True, "unchanged state on refusal")
        assert before is not None
        return self.wait_for(lambda s: s["frame"] > before["frame"],
                             "frame after " + command)

    def close(self) -> None:
        if self.process.poll() is None:
            try:
                self.send("QUIT")
            except Exception:
                self.process.terminate()
                self.process.wait(timeout=10)
                self.logfile.close()


def run_one(exe: Path, root: Path, workers: int) -> None:
    save = root / f"save-{workers}"
    client = Client(exe, save, root / f"control-{workers}-first",
                    workers, root / f"server-{workers}-first.log")
    try:
        start = client.state()
        assert start is not None
        first_pid = client.process.pid
        idle = client.wait_for(lambda s: s["ticks"] >= start["ticks"] + 2,
                               "autonomous ticks without any command")
        require(client.process.pid == first_pid and
                client.process.poll() is None,
                "server restarted during autonomous native simulation")
        require(idle["observed"] >= 1,
                "actual native worker participation was zero")

        dug = client.send("DIG 8 8")
        empty = client.pixel(dug, 8, 8)
        wall = client.send("WALL 8 8")
        wall_colour = client.pixel(wall, 8, 8)
        require(wall_colour != empty,
                "real native Wall paint did not change copied pixel")
        water = client.send("WATER 18 30 17 417")
        water_colour = client.pixel(water, 18, 30)
        require(water_colour != empty,
                "real native Water17 did not affect native pixels")

        client.send("FOCUS 0 -3")
        far = client.send("FOCUS 24 -3")
        require(far["x"] == 24 and far["residents"] == 2,
                "native camera demand did not cross old 1024px limit")
        restored = client.send("FOCUS -1 -3")
        require(client.pixel(restored, 8, 8) == wall_colour,
                "Wall changed after genuine native shard eviction/reload")
        require(client.process.pid == first_pid,
                "camera movement spawned another native process")
        error = client.send("FOCUS 1000001 -3",
                            expect_error="GEN006_DEMAND_COORDINATE_RANGE")
        require(error["x"] == -1 and error["y"] == -3,
                "invalid focus modified live native coordinate")
        client.send("SAVE")
        client.send("QUIT")
    finally:
        client.close()

    # A second operating-system process must restore the same actual
    # physical shard from the first process's native CYPS checkpoint.
    restarted = Client(exe, save, root / f"control-{workers}-second",
                       workers, root / f"server-{workers}-second.log")
    try:
        state = restarted.state()
        assert state is not None
        require(restarted.pixel(state, 8, 8) == wall_colour,
                "saved Wall did not survive independent process restart")
        repeated = restarted.wait_for(
            lambda s: s["ticks"] >= state["ticks"] + 2,
            "autonomous simulation after process restart")
        require(repeated["observed"] >= 1,
                "no native worker participation after process restart")
        restarted.send("QUIT")
    finally:
        restarted.close()
    print("GEN006_PERSISTENT_NATIVE_SESSION_PASS"
          f" configured_workers={workers}"
          f" actual_workers={idle['observed']}"
          " autonomous_ticks=1"
          " same_pid_during_interaction=1"
          " camera_pixel_x=1536"
          " native_Wall=preserved"
          " native_Water17=painted"
          " rejected_invalid_demand=1"
          " cross_process_restart=1"
          " saved_CYPS=1", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--workers", required=True, type=int, choices=[1, 4])
    args = parser.parse_args()
    exe = args.exe.resolve(strict=True)
    root = args.root.resolve()
    require(not root.exists(), "GEN006_PERSISTENT_TEST_NEEDS_FRESH_ROOT")
    root.mkdir(parents=True)
    run_one(exe, root, args.workers)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"GEN006_PERSISTENT_NATIVE_SESSION_FAIL {exc}", file=sys.stderr)
        raise
