#!/usr/bin/env python3
"""Creation-bound process custody for the one original PLAY-BUSY-001C launch.

Construct before spawning, observe immediately and at least every 0.1 seconds,
then call remaining() after the launcher exits. Any observation error invalidates
a positive result, including when later cleanup succeeds. Cleanup never supplies
natural-retirement evidence. Only recorded creation identities may be terminated.
"""
from __future__ import annotations

import ctypes as C
import os
from pathlib import Path
import signal
import sys
import time


class CustodyError(RuntimeError):
    pass


class _Linux:
    def __init__(self):
        self.previous_subreaper = C.c_int()
        self.libc = C.CDLL(None, use_errno=True)
        self.table()  # Refuse a different PID namespace before changing ownership.
        if self.libc.prctl(37, C.byref(self.previous_subreaper), 0, 0, 0):
            raise CustodyError("Cannot inspect Linux child-subreaper state")
        if self.libc.prctl(36, 1, 0, 0, 0):
            raise CustodyError("Cannot establish Linux child-subreaper custody")

    @staticmethod
    def _read(pid):
        try:
            fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        except (FileNotFoundError, ProcessLookupError):
            return None
        except (OSError, IndexError) as error:
            raise CustodyError(f"Cannot read process {pid}: {error}") from error
        try:
            return {"pid": pid, "parent_pid": int(fields[1]),
                    "creation_time": int(fields[19]), "state": fields[0],
                    "group": int(fields[2]), "session": int(fields[3])}
        except (ValueError, IndexError) as error:
            raise CustodyError(f"Invalid process identity for {pid}") from error

    def table(self):
        try:
            proc_pid = int(Path("/proc/self/stat").read_text().split(" ", 1)[0])
        except (OSError, ValueError) as error:
            raise CustodyError("Linux process inventory is unavailable") from error
        if proc_pid != os.getpid():
            raise CustodyError("Cannot establish process custody: /proc PID namespace mismatch")
        result = {}
        for path in Path("/proc").glob("[0-9]*/stat"):
            row = self._read(int(path.parent.name))
            if row is not None:
                result[row["pid"]] = row
        return result

    def identity(self, pid):
        return self._read(pid)

    def alive(self, row):
        current = self.identity(row["pid"])
        return (current is not None and current["creation_time"] == row["creation_time"]
                and current["state"] not in ("Z", "X"))

    def terminate(self, row):
        # A pidfd binds the signal to the process object even if a PID is reused
        # between checking /proc and sending the signal. Never use a global kill.
        if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
            raise CustodyError("Creation-bound Linux cleanup requires pidfd support")
        try:
            fd = os.pidfd_open(row["pid"], 0)
        except ProcessLookupError:
            return
        try:
            if self.alive(row):
                signal.pidfd_send_signal(fd, signal.SIGKILL)
        except ProcessLookupError:
            pass
        finally:
            os.close(fd)

    def reap(self, row, launcher_pid):
        current = self.identity(row["pid"])
        if (row["pid"] != launcher_pid and current is not None
                and current["creation_time"] == row["creation_time"]
                and current["state"] == "Z" and current["parent_pid"] == os.getpid()):
            try:
                os.waitpid(row["pid"], os.WNOHANG)
            except (ChildProcessError, ProcessLookupError):
                pass

    def close(self):
        if self.libc.prctl(36, self.previous_subreaper.value, 0, 0, 0):
            raise CustodyError("Cannot restore Linux child-subreaper state")


class _FileTime(C.Structure):
    _fields_ = [("low", C.c_uint32), ("high", C.c_uint32)]

    def value(self):
        return self.low | (self.high << 32)


class _ProcessEntry(C.Structure):
    _fields_ = [("size", C.c_uint32), ("usage", C.c_uint32),
                ("pid", C.c_uint32), ("heap", C.c_size_t),
                ("module", C.c_uint32), ("threads", C.c_uint32),
                ("parent", C.c_uint32), ("priority", C.c_int32),
                ("flags", C.c_uint32), ("name", C.c_wchar * 260)]


class _Windows:
    def __init__(self):
        self.kernel = C.WinDLL("kernel32.dll", use_last_error=True)
        self.handles = {}
        ptr, u32, flag = C.c_void_p, C.c_uint32, C.c_int32
        signatures = {
            "CreateToolhelp32Snapshot": ([u32, u32], ptr),
            "Process32FirstW": ([ptr, C.POINTER(_ProcessEntry)], flag),
            "Process32NextW": ([ptr, C.POINTER(_ProcessEntry)], flag),
            "OpenProcess": ([u32, flag, u32], ptr),
            "GetProcessTimes": ([ptr, *([C.POINTER(_FileTime)] * 4)], flag),
            "WaitForSingleObject": ([ptr, u32], u32),
            "TerminateProcess": ([ptr, u32], flag),
            "CloseHandle": ([ptr], flag),
        }
        for name, (arguments, result) in signatures.items():
            method = getattr(self.kernel, name)
            method.argtypes, method.restype = arguments, result

    def table(self):
        snapshot = self.kernel.CreateToolhelp32Snapshot(2, 0)
        if snapshot in (None, C.c_void_p(-1).value):
            raise CustodyError(f"Process snapshot failed: {C.get_last_error()}")
        try:
            row, result = _ProcessEntry(), {}
            row.size = C.sizeof(row)
            more = self.kernel.Process32FirstW(snapshot, C.byref(row))
            while more:
                result[row.pid] = {"pid": int(row.pid), "parent_pid": int(row.parent)}
                more = self.kernel.Process32NextW(snapshot, C.byref(row))
            if C.get_last_error() != 18:  # ERROR_NO_MORE_FILES
                raise CustodyError(f"Incomplete process snapshot: {C.get_last_error()}")
            return result
        finally:
            self.kernel.CloseHandle(snapshot)

    def identity(self, pid):
        handle = self.handles.get(pid)
        if handle is None:
            handle = self.kernel.OpenProcess(0x1000 | 0x100000 | 1, False, pid)
            if not handle:
                if C.get_last_error() == 87:  # Process disappeared, not access denied.
                    return None
                raise CustodyError(f"Cannot open process {pid}: {C.get_last_error()}")
            self.handles[pid] = handle
        created, exited, kernel, user = (_FileTime() for _ in range(4))
        if not self.kernel.GetProcessTimes(handle, C.byref(created), C.byref(exited),
                                           C.byref(kernel), C.byref(user)):
            raise CustodyError(f"Cannot read creation identity for {pid}: {C.get_last_error()}")
        if created.value() <= 0:
            raise CustodyError(f"Invalid creation identity for {pid}")
        return {"pid": pid, "creation_time": created.value()}

    def alive(self, row):
        identity = self.identity(row["pid"])
        if identity is None or identity["creation_time"] != row["creation_time"]:
            return False
        state = self.kernel.WaitForSingleObject(self.handles[row["pid"]], 0)
        if state not in (0, 258):
            raise CustodyError(f"Cannot observe process {row['pid']} retirement: {state}")
        return state == 258

    def terminate(self, row):
        if self.alive(row) and not self.kernel.TerminateProcess(self.handles[row["pid"]], 1):
            if self.alive(row):
                raise CustodyError(f"Cannot terminate owned process {row['pid']}: {C.get_last_error()}")

    def reap(self, row, launcher_pid):
        pass

    def close(self):
        for handle in self.handles.values():
            self.kernel.CloseHandle(handle)
        self.handles.clear()


class ProcessCustody:
    """Observe one process tree without trusting PID reuse or wrapper exit."""

    def __init__(self, platform, *, _backend=None):
        if platform not in ("linux", "windows"):
            raise CustodyError("Unsupported process custody platform")
        if _backend is None and ((platform == "windows") != (sys.platform == "win32")):
            raise CustodyError("Requested process platform differs from observer")
        self.platform = platform
        self.backend = _backend or (_Windows() if platform == "windows" else _Linux())
        self.launcher_pid = None
        self._observed = {}
        self.observation_errors = []
        self._closed = False
        try:
            table = self.backend.table()
            self._preexisting_children = {(pid, row.get("creation_time"))
                                          for pid, row in table.items()
                                          if row["parent_pid"] == os.getpid()}
        except Exception:
            self.backend.close()
            raise

    @property
    def observed_processes(self):
        return {str(pid): dict(row) for pid, row in sorted(self._observed.items())}

    def _record(self, pid, table, role="host", popen_owner=False):
        identity = self.backend.identity(pid)
        if identity is None:
            raise CustodyError(f"Process {pid} disappeared before creation identity was recorded")
        row = dict(table[pid]) | identity | {"role": role, "popen_owner": popen_owner}
        if pid in self._observed and self._observed[pid]["creation_time"] != row["creation_time"]:
            raise CustodyError(f"Owned PID {pid} was reused")
        self._observed.setdefault(pid, row)

    def register_auxiliary(self, pid):
        """Register a diagnostic Popen child explicitly created by the caller.

        This must immediately follow diagnostic spawning. It is never an engine
        candidate: its subtree has role=diagnostic and is still checked for exit.
        Its own Popen owner retains responsibility for reaping its exit status.
        """
        try:
            if self._closed or self.launcher_pid is None or not self._observed:
                raise CustodyError("Host custody must precede diagnostic registration")
            if type(pid) is not int or pid <= 0 or pid in self._observed:
                raise CustodyError("Invalid or already registered diagnostic PID")
            table = self.backend.table()
            if pid not in table or table[pid]["parent_pid"] != os.getpid():
                raise CustodyError("Diagnostic must be an observed direct child of this runner")
            identity = self.backend.identity(pid)
            if identity is None:
                raise CustodyError("Diagnostic exited before its creation identity was recorded")
            if identity["creation_time"] < self._observed[self.launcher_pid]["creation_time"]:
                raise CustodyError("Diagnostic predates its host launch")
            self._record(pid, table, role="diagnostic", popen_owner=True)
            return dict(self._observed[pid])
        except (OSError, ValueError, CustodyError) as error:
            self.observation_errors.append(str(error))
            raise CustodyError(str(error)) from error

    def observe(self, launcher_pid):
        try:
            if self._closed:
                raise CustodyError("Process custody is closed")
            if type(launcher_pid) is not int or launcher_pid <= 0 or launcher_pid == os.getpid():
                raise CustodyError("Invalid launcher PID")
            if self.launcher_pid not in (None, launcher_pid):
                raise CustodyError("Process custody cannot change its launcher")
            self.launcher_pid = launcher_pid
            table = self.backend.table()
            if not self._observed:
                if launcher_pid not in table:
                    raise CustodyError("Launcher exited before custody was established")
                self._record(launcher_pid, table, popen_owner=True)
                if self.platform == "linux" and (
                        self._observed[launcher_pid].get("session") != launcher_pid
                        or self._observed[launcher_pid].get("group") != launcher_pid):
                    raise CustodyError("Linux launcher must own its new process session")
            live = {pid for pid, row in self._observed.items() if self.backend.alive(row)}
            while True:
                additions = []
                for pid, row in table.items():
                    if pid in self._observed:
                        continue
                    parent = row["parent_pid"]
                    if parent in live:
                        identity = self.backend.identity(pid)
                        if identity is None:
                            raise CustodyError(f"Descendant {pid} vanished before identity capture")
                        if identity["creation_time"] < self._observed[parent]["creation_time"]:
                            raise CustodyError(f"Descendant {pid} predates its observed parent")
                        self._record(pid, table, role=self._observed[parent]["role"])
                        additions.append(pid)
                if not additions:
                    break
                live.update(pid for pid in additions if self.backend.alive(self._observed[pid]))
            if self.platform == "linux":
                # A short-lived, detached intermediary may disappear between
                # samples. Subreaper adoption makes that uncertainty observable;
                # do not invent parentage or kill an unattributed process.
                unknown = [pid for pid, row in table.items()
                           if row["parent_pid"] == os.getpid()
                           and (pid, row.get("creation_time")) not in self._preexisting_children
                           and pid not in self._observed]
                if unknown:
                    raise CustodyError(f"Unattributed adopted/direct children prevent retirement proof: {unknown}")
            return self.observed_processes
        except (OSError, ValueError, CustodyError) as error:
            self.observation_errors.append(str(error))
            raise CustodyError(str(error)) from error

    def remaining(self):
        if self.launcher_pid is None:
            raise CustodyError("No launcher has been observed")
        self.observe(self.launcher_pid)
        live = {}
        for pid, row in self._observed.items():
            if self.backend.alive(row):
                live[str(pid)] = dict(row)
            elif not row["popen_owner"]:
                self.backend.reap(row, self.launcher_pid)
        return live

    def stop_remaining(self, timeout_seconds=3.0):
        """Bounded failure cleanup; returned identities are never a pass receipt."""
        if not 0 < timeout_seconds <= 30:
            raise ValueError("Cleanup timeout must be in (0, 30]")
        deadline, attempted = time.monotonic() + timeout_seconds, {}
        while True:
            # Cleanup recorded identities even if another observation is refused.
            observation_error = None
            try:
                live = self.remaining()
            except CustodyError as error:
                observation_error = error
                live = {str(pid): dict(row) for pid, row in self._observed.items()
                        if self.backend.alive(row)}
            if not live:
                if observation_error is not None:
                    raise observation_error
                return attempted
            for key, row in live.items():
                self.backend.terminate(row)
                attempted[key] = row
            if time.monotonic() >= deadline:
                raise CustodyError("Owned processes remain after bounded failure cleanup")
            time.sleep(0.01)

    def close(self):
        if not self._closed:
            self.backend.close()
            self._closed = True
