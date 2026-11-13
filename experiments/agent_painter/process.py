"""Bounded POSIX child-tree ownership adapted from #567's repaired Stop loop.

Windows inference spawning is deliberately refused before spawn. The donor's
post-spawn Job Object assignment has an acknowledged race; it is not silently
promoted here. Native Windows Art Stop remains the existing application path.
"""
from __future__ import annotations

import math
import os
import signal
import subprocess
import time


class ProcessRefusal(RuntimeError):
    pass


def stop_group(process: subprocess.Popen) -> None:
    """Fence descendants even when their direct parent has already exited."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=0.4)
    except subprocess.TimeoutExpired:
        pass
    time.sleep(0.1)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=3)


def run_owned(command: list[str], log, seconds: float, *, canceled=lambda: False) -> int:
    if os.name != "posix":
        raise ProcessRefusal("Inference process-tree ownership is qualified only on POSIX; refused before spawn")
    if not math.isfinite(seconds) or not 0 < seconds <= 3600:
        raise ProcessRefusal("Invalid subprocess deadline")
    if type(command) is not list or not command or any(type(x) is not str for x in command):
        raise ProcessRefusal("Explicit argv required; shells are not accepted")
    if canceled():
        raise ProcessRefusal("Canceled before spawn")
    process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log,
                               stderr=subprocess.STDOUT, start_new_session=True)
    deadline = time.monotonic() + seconds
    try:
        while True:
            if canceled():
                raise ProcessRefusal("Canceled; no proposal returned")
            if time.monotonic() >= deadline:
                raise ProcessRefusal("Subprocess deadline exceeded; no proposal returned")
            code = process.poll()
            if code is not None:
                return code
            time.sleep(min(0.05, max(0, deadline-time.monotonic())))
    finally:
        # Also clean up descendants on nominal parent success. A process exit
        # is not evidence that its child tree has stopped producing output.
        stop_group(process)
