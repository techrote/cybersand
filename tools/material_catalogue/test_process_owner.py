"""Actual compiler descendant lifetime checks on both Windows and POSIX.

No mocked taskkill, Job Object, process, or stream stands in for acceptance.
The Windows publisher executes these same fixtures using native Python.
"""

from __future__ import annotations

import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest

import lab


def running(pid: int) -> bool:
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        api.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
        api.OpenProcess.restype = wintypes.HANDLE
        api.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
        api.WaitForSingleObject.restype = wintypes.DWORD
        api.CloseHandle.argtypes = (wintypes.HANDLE,)
        api.CloseHandle.restype = wintypes.BOOL
        handle = api.OpenProcess(0x00100000, False, pid)  # SYNCHRONIZE
        if not handle:
            error = ctypes.get_last_error()
            if error == 87:  # ERROR_INVALID_PARAMETER: PID no longer exists.
                return False
            raise ctypes.WinError(error)
        try:
            result = api.WaitForSingleObject(handle, 0)
            if result == 0xFFFFFFFF:
                raise ctypes.WinError(ctypes.get_last_error())
            return result == 258  # WAIT_TIMEOUT
        finally:
            api.CloseHandle(handle)
    try:
        os.kill(pid, 0)
        status = Path(f"/proc/{pid}/stat")
        return not (status.exists() and status.read_text().split(") ", 1)[1].startswith("Z"))
    except ProcessLookupError:
        return False


class ProcessOwnerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="cybersand-process-owner-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.pid_paths = [self.directory / (name + ".pid") for name in ("driver", "child", "grandchild")]
        self.addCleanup(self._cleanup_fixture)

    def _cleanup_fixture(self):
        # Failure cleanup is limited to PIDs written by this fresh fixture.
        for path in reversed(self.pid_paths):
            if not path.exists():
                continue
            pid = int(path.read_text())
            if not running(pid):
                continue
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5, check=False)
            else:
                os.kill(pid, signal.SIGKILL)

    def _fixture(self, mode):
        leaf = "import os,sys,time; from pathlib import Path; Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(120)"
        middle = ("import os,subprocess,sys,time; from pathlib import Path; "
                  "Path(sys.argv[1]).write_text(str(os.getpid())); "
                  f"subprocess.Popen([sys.executable,'-c',{leaf!r},sys.argv[2]]); time.sleep(120)")
        redirect = ", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL" if mode == "redirected" else ""
        script = f"""import os,subprocess,sys,time
from pathlib import Path
Path({str(self.pid_paths[0])!r}).write_text(str(os.getpid()))
subprocess.Popen([sys.executable, '-c', {middle!r}, {str(self.pid_paths[1])!r}, {str(self.pid_paths[2])!r}]{redirect})
deadline=time.monotonic()+15
while not Path({str(self.pid_paths[2])!r}).exists():
    if time.monotonic() >= deadline: raise RuntimeError('descendant did not start')
    time.sleep(.01)
print('owned descendants ready', flush=True)
{"time.sleep(120)" if mode == "waiting" else ""}
"""
        return [sys.executable, "-c", script]

    def _assert_descendants_retired(self):
        self.assertTrue(all(path.exists() for path in self.pid_paths), "all real descendants must have executed")
        pids = [int(path.read_text()) for path in self.pid_paths]
        deadline = time.monotonic() + 5
        while any(running(pid) for pid in pids) and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertEqual([pid for pid in pids if running(pid)], [], "owned fixture processes survived operation retirement")

    def test_timeout_retires_driver_child_and_grandchild(self):
        with self.assertRaisesRegex(lab.LabError, "bounded process exceeded"):
            lab._run(self._fixture("waiting"), self.directory, 5)
        self._assert_descendants_retired()

    def test_cancellation_retires_driver_child_and_grandchild(self):
        cancel = self.directory / "cancel"
        def cancel_after_start():
            deadline = time.monotonic() + 15
            while not self.pid_paths[2].exists() and time.monotonic() < deadline:
                time.sleep(.01)
            cancel.touch()
        thread = threading.Thread(target=cancel_after_start, daemon=True)
        thread.start()
        try:
            with lab._cancellation_scope(cancel), self.assertRaises(lab.LabCancelled):
                lab._run(self._fixture("waiting"), self.directory, 20)
        finally:
            thread.join(timeout=16)
        self._assert_descendants_retired()

    def test_exited_driver_with_inherited_pipes_is_refused_and_retired(self):
        with self.assertRaisesRegex(lab.LabError, "before its child output streams closed"):
            lab._run(self._fixture("inherited"), self.directory, 20)
        self._assert_descendants_retired()

    def test_success_retires_redirected_descendants_after_driver_exit(self):
        result = lab._run(self._fixture("redirected"), self.directory, 20)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "owned descendants ready")
        self._assert_descendants_retired()


if __name__ == "__main__":
    unittest.main()
