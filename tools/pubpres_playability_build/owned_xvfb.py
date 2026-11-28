#!/usr/bin/env python3
"""One private X server per invocation, explicitly joined before wrapper exit.

Unlike a shell EXIT trap which only sends Xvfb a signal, this owner waits for
its exact server process. The ordinary child-tree owner still rejects an
application that exits leaving descendants. Nothing runs inside the capture.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import secrets
import selectors
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time

from process_owner import OwnedProcess, ProcessCancelled, bounded_process


def authority_bytes(cookie: bytes) -> bytes:
    # Xsecurity(7): FamilyWild matches every display. The server and client
    # share one private MIT-MAGIC-COOKIE-1 file; TCP is never enabled.
    assert len(cookie) == 16
    fields = (b"", b"", b"MIT-MAGIC-COOKIE-1", cookie)
    return struct.pack(">H", 65535) + b"".join(struct.pack(">H", len(v)) + v for v in fields)


def ready_display(server: subprocess.Popen, descriptor: int, timeout: float = 30) -> str:
    deadline = time.monotonic() + timeout
    received = b""
    with selectors.DefaultSelector() as poll:
        poll.register(descriptor, selectors.EVENT_READ)
        while b"\n" not in received:
            if server.poll() is not None:
                raise RuntimeError("Xvfb exited before display readiness")
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Xvfb display readiness exceeded 30 seconds")
            if not poll.select(min(remaining, 0.1)):
                continue
            part = os.read(descriptor, 64 - len(received))
            if not part or len(received) + len(part) >= 64:
                raise RuntimeError("Xvfb returned an incomplete or oversized display identity")
            received += part
    if not received.endswith(b"\n") or not received[:-1].isdigit() or not 0 <= int(received[:-1]) <= 65535:
        raise RuntimeError("Xvfb returned an invalid display identity")
    return ":" + received[:-1].decode("ascii")


def run(command: list[str], receipt: Path, *, server_command: list[str] | None = None) -> int:
    if sys.platform != "linux" or not command:
        raise ValueError("A Linux application command is required")
    if receipt.exists():
        raise ValueError("Refusing to overwrite display-owner evidence")
    receipt.parent.mkdir(parents=True, exist_ok=True)
    executable = shutil.which("Xvfb") if server_command is None else server_command[0]
    if not executable:
        raise RuntimeError("Xvfb is not installed")
    prefix = [executable] if server_command is None else server_command
    record = {"schema": "pubpres-owned-display-v1", "wrapper_pid": os.getpid(),
              "server_executable": executable,
              "server_executable_sha256": hashlib.sha256(Path(executable).read_bytes()).hexdigest(),
              "server_pid": None, "display": None, "server_reaped": False,
              "server_tree_closed": False, "unexpected_server_members": False,
              "server_alive_before_requested_shutdown": None, "forced_server_kill": False,
              "application_returncode": None, "application_timeout": False,
              "authorization": "private MIT-MAGIC-COOKIE-1 FamilyWild; TCP disabled",
              "screen": "0 1920x1080x24", "failure": None}
    old_term = signal.getsignal(signal.SIGTERM)
    def cancelled(_signum, _frame):
        raise ProcessCancelled("Owned graphical invocation cancelled")
    signal.signal(signal.SIGTERM, cancelled)
    server = None
    server_owner = None
    read_fd = write_fd = None
    code = 125
    terminal = None
    try:
        with tempfile.TemporaryDirectory(prefix="pubpres-display-") as private:
            auth = Path(private) / "authority"
            auth.write_bytes(authority_bytes(secrets.token_bytes(16)))
            auth.chmod(0o600)
            read_fd, write_fd = os.pipe()
            try:
                server_owner = OwnedProcess(prefix + ["-displayfd", str(write_fd), "-screen", "0", "1920x1080x24",
                                            "-nolisten", "tcp", "-auth", str(auth)], pass_fds=(write_fd,))
                server = server_owner.process
                record["server_pid"] = server.pid
                os.close(write_fd)
                write_fd = None
                display = ready_display(server, read_fd)
                record["display"] = display
                environment = dict(os.environ, DISPLAY=display, XAUTHORITY=str(auth))
                # The outer campaign owns its existing 900/300/600-second
                # allowance. This enclosing ceiling cannot extend that bound.
                code, timeout = bounded_process(command, env=environment, timeout=7200)
                record.update(application_returncode=code, application_timeout=timeout)
            finally:
                if server is not None:
                    try:
                        record["server_alive_before_requested_shutdown"] = server.poll() is None
                        if server.poll() is None:
                            server.terminate()
                        try:
                            server.wait(timeout=30)
                        except subprocess.TimeoutExpired:
                            record["forced_server_kill"] = True
                            server.kill()
                            server.wait(timeout=30)
                    finally:
                        # Covers a signal during wait and any display-side
                        # descendants, including detached children. Merely
                        # joining the Xvfb PID is not complete ownership.
                        record["unexpected_server_members"] = server_owner.close()
                        record.update(server_tree_closed=True, server_reaped=server.poll() is not None,
                                      server_returncode=server.returncode)
    except BaseException as error:
        record["failure"] = type(error).__name__ + ": " + str(error)
        terminal = error
    finally:
        try:
            for descriptor in (read_fd, write_fd):
                if descriptor is not None:
                    os.close(descriptor)
            if code == 0 and (not record["server_reaped"] or record["forced_server_kill"]
                              or not record["server_tree_closed"] or record["unexpected_server_members"]
                              or record.get("server_returncode") not in (0, -signal.SIGTERM)
                              or not record["server_alive_before_requested_shutdown"]):
                code = 125
                record["failure"] = record["failure"] or "Unexpected display-server lifecycle"
            record["returncode"] = code
            receipt.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        finally:
            signal.signal(signal.SIGTERM, old_term)
    if terminal is not None:
        raise terminal
    return code


if __name__ == "__main__":
    destination = os.environ.get("PUBPRES_DISPLAY_RECEIPT")
    if not destination:
        raise SystemExit("PUBPRES_DISPLAY_RECEIPT is required")
    raise SystemExit(run(sys.argv[1:], Path(destination)))
