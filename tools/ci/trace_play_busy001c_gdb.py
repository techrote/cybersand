#!/usr/bin/env python3
"""Best-effort, nonqualifying Linux debugger capture for stalled PLAY-BUSY-001C.

Start a *second* source-matched graphical Godot process under GDB so Linux
ptrace-parent restrictions do not prevent a native stack. The original failed
001C execution, timeouts and its raw evidence are never modified. A missing
GDB/stack is a recorded diagnostic refusal, not a qualification result.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import time

SCHEMA = "play-busy001c-gdb-diagnostic-v1"
MAX_TRANSCRIPT_BYTES = 2 * 1024 * 1024


def capture(gdb: str, godot: str, output: Path, hold_seconds: float,
            extra_args: list[str]) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    transcript = output / "gdb-mi.log"
    result = {
        "schema": SCHEMA,
        "status": "refused",
        "qualification": False,
        "source_sha": os.environ.get("GITHUB_SHA", "unknown"),
        "elapsed_seconds": None,
        "interrupt_stopped": False,
        "backtrace_completed": False,
        "timeout_seconds_before_interrupt": hold_seconds,
        "transcript": "gdb-mi.log",
        "reason": "unstarted",
    }
    command = [gdb, "--quiet", "--nx", "--interpreter=mi2", "--args", godot, *extra_args]
    started = time.monotonic()
    parts = bytearray()
    process = None
    try:
        process = subprocess.Popen(
            command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, start_new_session=True, bufsize=0,
        )
        fd = process.stdout.fileno()
        os.set_blocking(fd, False)

        def collect(until: float, predicate=None) -> bool:
            while time.monotonic() < until:
                try:
                    ready, _, _ = select.select(
                        [fd], [], [], min(0.2, max(0., until - time.monotonic())))
                except (ValueError, OSError):
                    break
                if ready:
                    data = os.read(fd, 65536)
                    if not data:
                        break
                    if len(parts) + len(data) > MAX_TRANSCRIPT_BYTES:
                        parts.extend(data[:max(0, MAX_TRANSCRIPT_BYTES - len(parts))])
                        result["reason"] = "transcript_limit"
                        break
                    parts.extend(data)
                    if predicate and predicate(parts):
                        return True
                if process.poll() is not None:
                    break
            return bool(predicate and predicate(parts))

        def command_mi(token: int, value: str) -> None:
            if process.poll() is not None:
                raise RuntimeError("debugger exited before request")
            process.stdin.write(f"{token}{value}\n".encode())
            process.stdin.flush()

        command_mi(100, "-gdb-set pagination off")
        command_mi(101, "-gdb-set print thread-events off")
        command_mi(102, "-gdb-set disable-randomization off")
        command_mi(103, "-gdb-set mi-async on")
        command_mi(104, "-exec-run")
        collect(started + hold_seconds)
        if process.poll() is not None:
            result["reason"] = "debugger_exited_before_interrupt"
        else:
            command_mi(105, "-exec-interrupt --all")
            previous = len(parts)
            stopped = collect(time.monotonic() + 6.,
                              lambda b: b"*stopped," in b[previous:])
            result["interrupt_stopped"] = stopped
            if stopped:
                # Preserve all thread stacks in the uploaded original transcript.
                command_mi(106, '-interpreter-exec console "thread apply all bt 16"')
                result["backtrace_completed"] = collect(
                    time.monotonic() + 7., lambda b: b"106^done" in b)
                result["reason"] = ("captured" if result["backtrace_completed"]
                                    else "backtrace_refused_or_timed_out")
            else:
                result["reason"] = "interrupt_refused_or_timed_out"
    except (OSError, RuntimeError, BrokenPipeError, ValueError) as error:
        result["reason"] = f"{type(error).__name__}: {str(error)[:220]}"
    finally:
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=3)
            if process.stdout is not None:
                try:
                    more = process.stdout.read(65536)
                    if more and len(parts) + len(more) <= MAX_TRANSCRIPT_BYTES:
                        parts.extend(more)
                except (OSError, ValueError):
                    pass
        transcript.write_bytes(parts)
        result["transcript_sha256"] = hashlib.sha256(parts).hexdigest()
        result["transcript_bytes"] = len(parts)
        result["elapsed_seconds"] = round(time.monotonic() - started, 3)
        result["status"] = "captured" if result["backtrace_completed"] else "refused"
        (output / "gdb-diagnostic.json").write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--gdb", default="gdb")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--hold-seconds", type=float, default=22.)
    args = parser.parse_args()
    if not 1 <= args.hold_seconds <= 30:
        parser.error("hold-seconds must be in 1..30")
    argv = [
        "--windowed", "--resolution", "960x540",
        "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
        "--display-driver", "x11", "--path", "godot",
        "--script", "res://tests/play_busy001c_render.gd",
    ]
    result = capture(args.gdb, args.godot, args.output, args.hold_seconds, argv)
    print("PLAY_BUSY001C_GDB_DIAGNOSTIC", json.dumps(result, sort_keys=True), flush=True)
    # This is NOT a second qualification or a retry. The original render
    # failure remains red regardless of debugger capture outcome.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
