#!/usr/bin/env python3
"""Reproduce Windows response-sharing denial using Godot and the real native ACK."""
import argparse
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--exe", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("This is a Windows file-sharing regression.")
    args.root.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, GEN006_READ_TEST_ROOT=str(args.root.resolve()),
               GEN006_SLICE_EXECUTABLE=str(Path(args.exe).resolve()))
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                  ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD,
                                  wintypes.HANDLE]
    kernel.CreateFileW.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = None
    with (args.root / "stdout.log").open("w") as out, (args.root / "stderr.log").open("w") as err:
        proc = subprocess.Popen([args.godot, "--rendering-driver", "opengl3",
                                 "--path", args.project, "--script",
                                 "res://tests/gen006_windows_response_read_qualification.gd"],
                                env=env, stdout=out, stderr=err)
        try:
            deadline = time.monotonic() + 25
            while time.monotonic() < deadline and proc.poll() is None:
                response = args.root / "ipc/response.txt"
                if handle is None and response.exists() and not (args.root / "released").exists():
                    candidate = kernel.CreateFileW(str(response.resolve()), 0x80000000,
                                                   0, None, 3, 0x80, None)
                    if candidate != ctypes.c_void_p(-1).value:
                        handle = candidate
                        (args.root / "locked").write_text("exclusive Windows read handle")
                if handle is not None and (args.root / "release").exists():
                    kernel.CloseHandle(handle)
                    handle = None
                    (args.root / "released").write_text("unlocked")
                time.sleep(0.005)
            code = proc.wait(timeout=2)
            (args.root / "exit-code.txt").write_text(str(code))
            print((args.root / "stdout.log").read_text())
            return code
        finally:
            if handle is not None:
                kernel.CloseHandle(handle)
            if proc.poll() is None:
                proc.kill()
                proc.wait()


if __name__ == "__main__":
    raise SystemExit(main())
