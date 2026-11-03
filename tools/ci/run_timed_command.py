#!/usr/bin/env python3
"""Run a command with a generous named watchdog and preserve every final exit."""

import argparse
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import execution_policy
import execution_telemetry
import godot_timeout_diagnostics as diagnostics


def process_table() -> dict:
    """Linux creation identities include detached nested command sessions."""
    rows = {}
    if not Path("/proc").is_dir():
        return rows
    # Some development sandboxes expose the host's /proc inside a different PID
    # namespace. Treating those PIDs as ours would corrupt ownership evidence.
    if int(Path("/proc/self/stat").read_text().split(" ", 1)[0]) != os.getpid():
        raise RuntimeError("Cannot establish process ownership: /proc PID namespace mismatch")
    for path in Path("/proc").glob("[0-9]*/stat"):
        try:
            parts = path.read_text().rsplit(")", 1)[1].split()
            rows[int(path.parent.name)] = {"state": parts[0], "parent": int(parts[1]),
                "group": int(parts[2]), "start": int(parts[19])}
        except (OSError, ValueError, IndexError):
            pass
    return rows


def observe_descendants(pid: int, identities: dict, preexisting=frozenset()) -> dict:
    table = process_table()
    adopted = {child for child, row in table.items()
               if row["parent"] == os.getpid() and (child, row["start"]) not in preexisting}
    owned = {pid} | adopted | {child for child, start in identities.items()
                    if table.get(child, {}).get("start") == start}
    while True:
        extra = {child for child, row in table.items()
                 if row["parent"] in owned or row["group"] == pid}
        if extra.issubset(owned):
            break
        owned |= extra
    for child in owned - {pid}:
        if child in table:
            identities[child] = table[child]["start"]
    return {child: row for child, row in table.items()
            if child != pid and identities.get(child) == row["start"] and row["state"] != "Z"}


def stop_owned(process: subprocess.Popen, identities: dict, preexisting=frozenset()) -> dict:
    live = observe_descendants(process.pid, identities, preexisting)
    terminated = dict(live)
    # Nested timed commands establish their own sessions so an inner timeout
    # cannot kill its outer evidence owner. The outer owner tracks creation
    # identities and terminates those descendants too, without a global kill.
    deadline = time.monotonic() + execution_policy.watchdog_seconds("terminate_grace_seconds")
    while True:
        for pid, row in live.items():
            try:
                if process_table().get(pid, {}).get("start") == row["start"]:
                    os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        if process.poll() is None:
            diagnostics.stop_process_tree(process, wait_seconds=max(.01, deadline - time.monotonic()))
        for pid in identities:
            try:
                os.waitpid(pid, os.WNOHANG)
            except (ChildProcessError, ProcessLookupError):
                pass
        live = observe_descendants(process.pid, identities, preexisting)
        terminated.update(live)
        if not live:
            return terminated
        if time.monotonic() >= deadline:
            raise RuntimeError("Owned descendants did not terminate within cleanup allowance")
        time.sleep(.01)


def write_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def recorded_processes(rows: dict) -> dict:
    """JSON object keys are strings in both the in-memory and sealed receipt."""
    return {str(pid): row for pid, row in rows.items()}


def run(command: list[str], *, timeout_seconds: float, label: str, output_dir: Path,
        root: Path = execution_policy.ROOT) -> dict:
    if not command or timeout_seconds <= 0:
        raise ValueError("A command and a positive timeout are required")
    output_dir.mkdir(parents=True, exist_ok=False)
    log_path = output_dir / "command.log"
    receipt = {"schema": "execution-command-v1", "label": label, "command": command,
        "execution_policy": execution_policy.identity(), "timeout_seconds": timeout_seconds,
        "status": "running", "returncode": None, "timed_out": False,
        "natural_completion": False, "complete": False,
        "started_utc": datetime.now(timezone.utc).isoformat(), "elapsed_seconds": 0.0,
        "source": execution_telemetry.source_identity(root), "log": "command.log",
        "resources": {"available": False, "scope": "direct_process_only"}}
    write_json(output_dir / "receipt.json", receipt)
    started = time.monotonic()
    process = None
    descendants = {}
    preexisting = frozenset()
    previous_subreaper = ctypes.c_int(0)
    libc = None
    try:
        if not sys.platform.startswith("linux"):
            raise RuntimeError("This native command owner requires Linux; Windows uses its separate Job owner")
        table = process_table()
        preexisting = frozenset((pid, row["start"]) for pid, row in table.items() if row["parent"] == os.getpid())
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(37, ctypes.byref(previous_subreaper), 0, 0, 0) or libc.prctl(36, 1, 0, 0, 0):
            raise OSError(ctypes.get_errno(), "Cannot establish child-subreaper ownership")
        with log_path.open("wb") as log:
            options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if sys.platform == "win32" else {"start_new_session": True}
            process = subprocess.Popen(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, **options)
            receipt["pid"] = process.pid
            write_json(output_dir / "receipt.json", receipt)
            capture_at = max(0, timeout_seconds - min(execution_policy.watchdog_seconds("diagnostic_capture_seconds"), timeout_seconds * 0.2))
            captured = False
            while process.poll() is None:
                elapsed = time.monotonic() - started
                observe_descendants(process.pid, descendants, preexisting)
                resources = execution_telemetry.observe_process(process.pid)
                if resources["available"]:
                    receipt["resources"] = resources
                if elapsed >= capture_at and not captured:
                    captured = True
                    # Nonblocking diagnostic snapshot retains last stage and CPU
                    # activity without consuming the command's remaining clock.
                    write_json(output_dir / "approaching-watchdog.json", {
                        "pid": process.pid, "elapsed_seconds": elapsed,
                        "resources": resources, "command": command})
                if elapsed >= timeout_seconds:
                    receipt["timed_out"] = True
                    receipt["terminated_descendants"] = recorded_processes(stop_owned(process, descendants, preexisting))
                    break
                try:
                    process.wait(timeout=min(0.1, max(0.001, timeout_seconds - elapsed)))
                except subprocess.TimeoutExpired:
                    pass
            receipt["returncode"] = process.poll()
            receipt["natural_completion"] = not receipt["timed_out"] and receipt["returncode"] is not None
            receipt["status"] = "timeout" if receipt["timed_out"] else ("passed" if process.returncode == 0 else "failed")
            live = observe_descendants(process.pid, descendants, preexisting)
            if live:
                receipt["surviving_descendants"] = recorded_processes(live)
                receipt["terminated_descendants"] = recorded_processes(stop_owned(process, descendants, preexisting))
                receipt["natural_completion"] = False
                if not receipt["timed_out"]:
                    receipt["status"] = "teardown_failed"
    except (OSError, RuntimeError) as error:
        receipt.update(status="launch_error", error=f"{type(error).__name__}: {error}")
    except BaseException:
        receipt.update(status="interrupted", natural_completion=False)
        raise
    finally:
        # Preserve the original exit and failure even if cleanup itself fails.
        # Such a receipt is evidence of failure, never proof of completion.
        if process is not None:
            try:
                remaining = observe_descendants(process.pid, descendants, preexisting)
                if process.poll() is None or remaining:
                    receipt["terminated_descendants"] = recorded_processes(stop_owned(process, descendants, preexisting))
            except (OSError, RuntimeError) as error:
                receipt.update(status="cleanup_failed", natural_completion=False,
                               cleanup_error=f"{type(error).__name__}: {error}")
        if libc is not None:
            libc.prctl(36, previous_subreaper.value, 0, 0, 0)
        receipt["elapsed_seconds"] = time.monotonic() - started
        receipt["complete"] = receipt["status"] not in {"interrupted", "cleanup_failed"}
        if log_path.exists():
            receipt["log_sha256"] = hashlib.sha256(log_path.read_bytes()).hexdigest()
        write_json(output_dir / "receipt.json", receipt)
        log_text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        execution_telemetry.record_case(output_dir, {**receipt, "name": label, "role": "native-command"}, log_text, root=root)
    # Full file-backed output cannot be held open by surviving inherited pipes.
    if log_path.exists():
        with log_path.open("r", encoding="utf-8", errors="replace") as stream:
            for chunk in iter(lambda: stream.read(65536), ""):
                print(chunk, end="", flush=True)
    print(f"EXECUTION_TIMING {label}: {receipt['status']} {receipt['elapsed_seconds']:.3f}s exit={receipt['returncode']}", flush=True)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy-key", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--timeout-seconds", type=float,
                        help="Derived aggregate allowance; may not undercut the named policy")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    allowance = execution_policy.watchdog_seconds(args.policy_key)
    if args.timeout_seconds is not None:
        if not __import__("math").isfinite(args.timeout_seconds) or args.timeout_seconds < allowance:
            parser.error("Derived timeout must be finite and at least the named policy allowance")
        allowance = args.timeout_seconds
    result = run(command, timeout_seconds=allowance,
                 label=args.label, output_dir=args.output_dir)
    return 124 if result["timed_out"] else (result["returncode"] if isinstance(result["returncode"], int) and result["returncode"] > 0 else (0 if result["status"] == "passed" else 1))


if __name__ == "__main__":
    raise SystemExit(main())
