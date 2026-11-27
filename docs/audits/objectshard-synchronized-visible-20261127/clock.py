"""Bracket the instrumented Godot clock with Windows QPC in the probe directory."""
import ctypes
import json
import sys
import time
from pathlib import Path


def qpc():
    value = ctypes.c_longlong()
    if not ctypes.windll.kernel32.QueryPerformanceCounter(ctypes.byref(value)):
        raise OSError("QueryPerformanceCounter failed")
    return value.value


def sync(directory):
    samples = []
    for phase in ("pre", "post"):
        for index in range(8):
            tag = directory / f"sync-{phase}-{index}"
            request = tag.with_suffix(".req")
            response = tag.with_suffix(".res")
            if request.exists() or response.exists():
                raise ValueError(f"Clock exchange requires a fresh measurement directory: {tag}")
            before = qpc()
            request.write_bytes(b"1")
            deadline = time.monotonic() + 170
            while time.monotonic() < deadline:
                try:
                    reply = response.read_bytes()
                    if reply:
                        break
                except (FileNotFoundError, PermissionError):
                    pass
                time.sleep(.0003)
            else:
                raise TimeoutError(str(response))
            samples.append([phase, index, before, qpc(), int(reply)])
    (directory / "sync.json").write_text(json.dumps(samples), encoding="utf-8")


if __name__ == "__main__":
    sync(Path(sys.argv[1]))
