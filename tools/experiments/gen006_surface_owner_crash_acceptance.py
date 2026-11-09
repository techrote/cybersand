#!/usr/bin/env python3
"""GEN-006 #486 independent real-process continuity acceptance.

Expected NEGATIVE on the unrepaired sharded demo: a legitimate surface chunk
causes an autonomous native tick to terminate the entire long-lived owner,
before its still-resident player's Empty-intent edit is durably saved.
Compare with normal quit on the same compiled native executable. No fake
World, no process monkeypatch, no modification of the builder's source.

When repaired, replace this expected-failure acceptance with an owner-visible
PIN/REFUSED + live-PID + preserved-edit positive assertion. Do not keep an
expected-crash fixture as evidence that the feature works.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def require(ok: bool, why: str) -> None:
    if not ok:
        raise AssertionError(why)


class NativeService:
    def __init__(self, executable: Path, root: Path, evidence: Path, label: str):
        self.ipc = evidence / (label + "-ipc")
        self.ipc.mkdir(parents=True, exist_ok=False)
        self.stdout_path = evidence / (label + "-stdout.txt")
        self.stderr_path = evidence / (label + "-stderr.txt")
        # The *actual* C++ owner process, native World, native ticks, and
        # existing .g6s persistence implementation are unchanged.
        with self.stdout_path.open("w", encoding="utf-8") as out, \
                self.stderr_path.open("w", encoding="utf-8") as err:
            self.proc = subprocess.Popen(
                [str(executable), "--serve", str(root), str(self.ipc), "1", "2"],
                stdout=out, stderr=err, text=True,
            )
        self.seq = 0
        receipt = self._await(self.ipc / "ready.txt", timeout=12.0)
        m = re.search(r"GEN006_STREAM_SERVER_READY pid=(\d+) configured_workers=1 tick_hz=2", receipt)
        require(m is not None, "unexpected real native ready receipt: " + receipt)
        require(int(m.group(1)) == self.proc.pid, "native PID mismatch")
        self.pid = self.proc.pid

    def _await(self, path: Path, timeout: float = 8.0) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if path.is_file():
                return path.read_text(encoding="utf-8", errors="replace")
            if self.proc.poll() is not None:
                raise AssertionError(
                    "native process exited before receipt: pid={} rc={} stderr={}".format(
                        self.proc.pid, self.proc.returncode,
                        self.stderr_path.read_text(encoding="utf-8", errors="replace")[-1000:]
                    )
                )
            time.sleep(0.020)
        raise AssertionError("native owner receipt timed out: " + str(path))

    def request(self, text: str) -> str:
        require(self.proc.poll() is None, "native process died before request")
        self.seq += 1
        response = self.ipc / "response.txt"
        response.unlink(missing_ok=True)
        staging = self.ipc / "request.txt.staging"
        staging.write_text("SEQ {}\n{}\n".format(self.seq, text), encoding="utf-8")
        os.replace(staging, self.ipc / "request.txt")
        result = self._await(response)
        require(result.startswith("SEQ {}\n".format(self.seq)), "incorrect response sequence")
        require("GEN006_STREAM_SERVER_STATE pid={}".format(self.pid) in result,
                "response did not belong to the running owner")
        return result

    def stop(self) -> None:
        response = self.request("quit")
        require("REFUSED " not in response, "clean quit refused")
        self.proc.wait(timeout=8.0)
        require(self.proc.returncode == 0, "clean quit failed rc=" + str(self.proc.returncode))
        receipt = (self.ipc / "stopped.txt").read_text(encoding="utf-8")
        require("GEN006_STREAM_SERVER_STOPPED pid={}".format(self.pid) in receipt,
                "clean native save-all receipt missing")

    def close(self) -> None:
        if self.proc.poll() is None:
            self.proc.kill()
        self.proc.wait(timeout=5.0)


def inspect_intent(service: NativeService) -> int:
    response = service.request("inspect 5 5")
    lines = [line for line in response.splitlines()
             if line.startswith("CELL chunk=(-2,2) local=(5,5)")]
    require(len(lines) == 1, "native signed-coordinate cell readback missing")
    m = re.search(r"\bintent=(\d+)\b", lines[0])
    require(m is not None, "native Empty-intent receipt missing")
    return int(m.group(1))


def edit_intent(service: NativeService) -> None:
    response = service.request("dig 5 5\ninspect 5 5")
    require("REFUSED " not in response, "native player edit refused")
    require("CELL chunk=(-2,2) local=(5,5)" in response and "intent=1" in response,
            "unsaved native Empty tombstone not present immediately after edit")
    require(inspect_intent(service) == 1, "native player Empty intent vanished")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--logs", type=Path, required=True)
    args = parser.parse_args()
    exe = args.exe.resolve(strict=True)
    require(not args.root.exists(), "fresh save-root required")
    require(not args.logs.exists(), "fresh evidence-root required")
    root = args.root.resolve()
    logs = args.logs.resolve()
    logs.mkdir(parents=True)
    controller: NativeService | None = None
    try:
        # Positive control: a normal quit persists the same actual native edit.
        normal_root = root / "normal"
        controller = NativeService(exe, normal_root, logs, "normal-first")
        edit_intent(controller)
        controller.stop()
        controller = NativeService(exe, normal_root, logs, "normal-restart")
        require(inspect_intent(controller) == 1,
                "normal cross-process native restart lost explicit Empty intent")
        controller.stop()
        controller = None

        # Failure control: keep a single unsaved resident, then admit the
        # known surface chunk (-2,1) without exhausting the 2-resident LRU.
        # Its real native tick tries to expand beyond the one-chunk shard
        # limit. No deliberate record corruption or artificial native fault.
        crash_root = root / "surface"
        controller = NativeService(exe, crash_root, logs, "surface-first")
        edit_intent(controller)
        requested = controller.request("focus -2 1")
        require("GENERATE x=-2 y=1 resident=2" in requested,
                "surface fixture was not genuinely generated/admitted")
        require("REFUSED " not in requested, "surface focus refused before tick")

        deadline = time.monotonic() + 10.0
        while controller.proc.poll() is None and time.monotonic() < deadline:
            time.sleep(0.050)
        require(controller.proc.poll() is not None,
                "unrepaired service did not exit under autonomous surface tick")
        failed_pid = controller.pid
        rc = controller.proc.returncode
        stderr = controller.stderr_path.read_text(encoding="utf-8", errors="replace")
        require(rc != 0, "unsafe surface tick exited successfully")
        require("GEN006_NATIVE_SHARDED_STREAM_FAIL" in stderr
                and ("maximum chunk capacity exhausted" in stderr
                     or "GEN006_CROSS_CHUNK_DOMAIN_PIN" in stderr
                     or "GEN006_WORLD_QUARANTINED" in stderr),
                "native owner exited for unrelated reason: " + stderr[-1200:])
        require(not (controller.ipc / "stopped.txt").exists(),
                "unexpected graceful save-all after native tick failure")
        require(not (crash_root / "chunk_x-2_y2.g6s").exists(),
                "native edit was already durably saved: test no longer isolates loss")
        controller = None

        # Reopen the *same* save root through a new real C++ process.
        # The unsaved tombstone was present in native memory but never
        # reached disk, so an unprotected process death loses it.
        controller = NativeService(exe, crash_root, logs, "surface-restart")
        require(inspect_intent(controller) == 0,
                "expected legacy unsaved edit loss was NOT observed; investigate")
        controller.stop()
        controller = None

        print("GEN006_REAL_OWNER_FAILURE_NEGATIVE_CONFIRMED"
              " native_process_exit=1 cross_chunk_capacity=1"
              " pending_Empty_intent_lost=1 normal_exit_intent_restored=1"
              " restarted_native_process=1 configured_workers=1"
              " unsafe_surface=(-2,1) saved_chunk=(-2,2)"
              " failed_pid={}".format(failed_pid))
    finally:
        if controller is not None:
            controller.close()


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError, subprocess.SubprocessError) as exc:
        print("GEN006_REAL_OWNER_FAILURE_NEGATIVE_INCONCLUSIVE " + str(exc),
              file=sys.stderr)
        raise SystemExit(1)
