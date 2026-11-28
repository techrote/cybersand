"""Bound only the explicitly launched test process tree and retain its outcome.

The game never calls this module. Repository qualification supplies a fixed Godot
command as an argv list, never a shell. RSS and log limits are sampled every
100ms, so reported resource ceilings are monitoring bounds, not allocator laws.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import signal
import subprocess
import time

try:
    import psutil
except ImportError:
    psutil = None

MAX_LOG_BYTES = 16 * 1024 * 1024
ERROR_MARKERS = ("SCRIPT ERROR:", "Parse Error:", "ERROR:", "Fatal signal", "Segmentation fault")


def read_log_prefix(path: Path) -> str:
    """Read only the bounded diagnostic prefix; oversized raw logs stay on disk."""
    with path.open("rb") as stream:
        return stream.read(MAX_LOG_BYTES).decode("utf-8", errors="replace")


def _identity(process):
    try:
        return process.pid, process.create_time()
    except psutil.Error:
        return None


def _alive(process, identity) -> bool:
    try:
        return _identity(process) == identity and process.is_running() and process.status() != psutil.STATUS_ZOMBIE
    except psutil.Error:
        return False


def _stop_owned(root_pid: int, known: dict) -> list[int]:
    """PID creation times prevent an old sample from killing a reused PID."""
    victims = [p for ident, p in known.items() if _alive(p, ident)]
    if os.name != "nt":
        # Popen created this group. Only use the group while its original root
        # identity remains ours; otherwise terminate the retained children.
        root = next((p for p in victims if p.pid == root_pid), None)
        if root is not None:
            try:
                os.killpg(root_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
    for p in reversed(victims):
        try:
            p.terminate()
        except psutil.Error:
            pass
    _, living = psutil.wait_procs(victims, timeout=2)
    for p in living:
        if _identity(p) in known:
            try:
                p.kill()
            except psutil.Error:
                pass
    _, living = psutil.wait_procs(living, timeout=2)
    return [p.pid for ident, p in known.items() if _alive(p, ident)]


def execute(command: list[str], env: dict, log: Path, timeout: int | None, *, cwd: Path,
            memory_limit_mib: int = 3072, cancel_path: Path | None = None) -> dict:
    if psutil is None:
        raise ValueError("Bounded qualification requires psutil==7.2.2 (tools/gip014/requirements.txt)")
    if not 256 <= memory_limit_mib <= 8192 or (timeout is not None and not 1 <= timeout <= 5400):
        raise ValueError("Process bounds must be memory256..8192MiB and wall1..5400seconds")
    started = time.monotonic()
    status, code, peak, samples, known, living = "execution_error", None, 0, 0, {}, []
    interrupted = False
    log.parent.mkdir(parents=True, exist_ok=True)
    process = None
    with log.open("w", encoding="utf-8") as output:
        try:
            flags = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
            process = subprocess.Popen(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT, **flags)
            try:
                root = psutil.Process(process.pid)
            except psutil.NoSuchProcess:
                # A short successful child can exit before its first sample.
                # Its return code remains authoritative; no resource sample is
                # invented and there is no retained PID to terminate.
                root = None
            initial = _identity(root) if root is not None else None
            if initial is not None:
                known[initial] = root
            while process.poll() is None:
                try:
                    children = [root, *root.children(recursive=True)] if root is not None else []
                except psutil.Error:
                    children = list(known.values())
                for child in children:
                    ident = _identity(child)
                    if ident is not None:
                        known[ident] = child
                rss = 0
                for ident, child in list(known.items()):
                    if _alive(child, ident):
                        try:
                            rss += child.memory_info().rss
                        except psutil.Error:
                            pass
                samples += 1
                peak = max(peak, rss)
                elapsed = time.monotonic() - started
                if cancel_path is not None and cancel_path.is_file():
                    status = "cancelled"
                elif timeout is not None and elapsed > timeout:
                    status = "timeout"
                elif rss > memory_limit_mib * 1024 * 1024:
                    status = "resource_limit"
                elif log.stat().st_size > MAX_LOG_BYTES:
                    status = "output_limit"
                else:
                    time.sleep(0.1)
                    continue
                living = _stop_owned(process.pid, known)
                process.wait(timeout=5)
                break
            else:
                code = process.returncode
                status = "pass" if code == 0 else ("crash" if code < 0 else "test_failure")
        except KeyboardInterrupt:
            interrupted = True
            status = "cancelled"
        except (OSError, subprocess.SubprocessError, psutil.Error) as error:
            output.write("\nGOBLIN_PROCESS_ERROR " + str(error) + "\n")
            status = "execution_error"
        finally:
            if process is not None:
                surviving = [p for ident, p in known.items() if _alive(p, ident)]
                if surviving:
                    if status == "pass":
                        status = "leaked_child"
                    living = _stop_owned(process.pid, known)
                try:
                    code = process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    code = process.wait(timeout=5)
                output.write("\nGOBLIN_PROCESS_TERMINAL " + status + "\n")
    # A short child may finish between samples. Keep the complete log on disk,
    # hash it incrementally, and bound the diagnostic buffer even in that case.
    fingerprint = hashlib.sha256()
    prefix = bytearray()
    log_bytes = 0
    with log.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            fingerprint.update(block)
            log_bytes += len(block)
            if len(prefix) < MAX_LOG_BYTES:
                prefix.extend(block[:MAX_LOG_BYTES - len(prefix)])
    process_exit_status = status
    if log_bytes > MAX_LOG_BYTES:
        status = "output_limit"
    text = prefix.decode("utf-8", errors="replace")
    errors = [line[:1000] for line in text.splitlines() if any(marker in line for marker in ERROR_MARKERS)]
    if errors and status == "pass":
        status = "diagnostic_failure"
    return {"status": status, "exit_code": code, "elapsed_seconds": round(time.monotonic() - started, 3),
            "timeout_seconds": timeout, "command": command, "log_sha256": fingerprint.hexdigest(),
            "diagnostic_errors": errors[:40], "peak_tree_rss_bytes": peak, "memory_limit_mib": memory_limit_mib,
            "resource_samples": samples, "observed_processes": len(known), "surviving_owned_pids": living,
            "resource_scope": "launched process tree RSS sampled every100ms; no global process monitoring",
            "log_limit_bytes": MAX_LOG_BYTES, "log_bytes": log_bytes, "interrupted": interrupted,
            "process_exit_status": process_exit_status, "diagnostic_prefix_bytes": len(prefix),
            "diagnostic_scope": "bounded log prefix; complete on-disk log retained and streamed into its digest"}
