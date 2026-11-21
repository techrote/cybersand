"""Allowlisted subprocess execution: fixed executables, no shell, sanitized
environment (never the API key), bounded time and captured output, cwd pinned."""
from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from .errors import SandboxViolation

_ENV_KEEP = ("PATH", "SYSTEMROOT", "SystemRoot", "WINDIR", "windir", "COMSPEC", "PATHEXT", "TEMP", "TMP", "TMPDIR",
             "LANG", "LC_ALL", "SYSTEMDRIVE", "DISPLAY", "XAUTHORITY", "LIBGL_ALWAYS_SOFTWARE",
             "GODOT_SILENCE_ROOT_WARNING")
ALLOWED_EXECUTABLE_NAMES = ("python", "node")


def resolve_executables() -> dict[str, str]:
    found = {"python": sys.executable}
    node = shutil.which("node")
    if node:
        found["node"] = node
    return found


def clean_env() -> dict[str, str]:
    env = {key: os.environ[key] for key in _ENV_KEEP if key in os.environ}
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    return env


def _kill_tree(proc: subprocess.Popen) -> None:
    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True, timeout=15)
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except (OSError, subprocess.SubprocessError):
        pass
    try:
        proc.kill()
    except OSError:
        pass


def run_allowlisted(argv: list[str], cwd: Path, timeout: float, max_output_bytes: int,
                    executables: dict[str, str]) -> dict:
    """Run ``argv`` (argv[0] must be a resolved allowlisted executable) with limits."""
    if not argv or argv[0] not in executables.values():
        raise SandboxViolation(f"executable not on the allowlist: {argv[:1]}", "executable_not_allowed")
    if any(not isinstance(a, str) or "\x00" in a for a in argv):
        raise SandboxViolation("invalid process argument", "invalid_argument")
    started = time.monotonic()
    timed_out = False
    kwargs: dict = {}
    if os.name == "nt":
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["start_new_session"] = True
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        proc = subprocess.Popen(argv, cwd=str(cwd), stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                env=clean_env(), shell=False, **kwargs)
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            _kill_tree(proc)
            proc.wait()
        out.seek(0)
        err.seek(0)
        stdout, stderr = out.read(max_output_bytes + 1), err.read(max_output_bytes + 1)
    truncated = len(stdout) > max_output_bytes or len(stderr) > max_output_bytes
    return {
        "exit_code": -9 if timed_out else proc.returncode,
        "timed_out": timed_out,
        "duration_seconds": round(time.monotonic() - started, 3),
        "stdout": stdout[:max_output_bytes].decode("utf-8", errors="replace"),
        "stderr": stderr[:max_output_bytes].decode("utf-8", errors="replace"),
        "output_truncated": truncated,
    }
