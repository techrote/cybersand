#!/usr/bin/env python3
"""Own a complete child tree without adding sampling work to a timed capture.

Linux adopts orphan descendants with a scoped child subreaper. Windows assigns
the suspended child to a kill-on-close Job before its first instruction. Neither
backend relies on a detached grandchild sharing the immediate child's group.
"""
from __future__ import annotations

import ctypes
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


class ProcessCancelled(KeyboardInterrupt):
    """Terminal cancellation; an ordinary failed-arm handler must not retry."""


class OwnershipFailure(BaseException):
    """Uncertain cleanup is terminal, never an ordinary retryable arm failure."""


def _children(pid):
    result = set()
    # Some Linux procfs implementations omit task/children. PPid in stat is
    # the portable procfs ownership field; only disappearing processes may be
    # ignored. An unavailable inventory must never mean an empty owned tree.
    for path in Path("/proc").iterdir():
        if not path.name.isdigit():
            continue
        try:
            fields = (path / "stat").read_text().rsplit(")", 1)[1].split()
            if int(fields[1]) == pid:
                result.add(int(path.name))
        except (FileNotFoundError, ProcessLookupError):
            continue
    return result


class OwnedProcess:
    def __init__(self, command, **kwargs):
        self.process = None
        self.closed = False
        self.had_survivors = False
        self.old_term = signal.getsignal(signal.SIGTERM)
        self.job = None
        self.old_subreaper = ctypes.c_int()
        if os.name == "nt":
            self._windows_prepare()
            kwargs["creationflags"] = kwargs.get("creationflags", 0) | 0x4  # CREATE_SUSPENDED
        elif sys.platform.startswith("linux"):
            self.libc = ctypes.CDLL(None, use_errno=True)
            if self.libc.prctl(37, ctypes.byref(self.old_subreaper), 0, 0, 0) != 0 or self.libc.prctl(36, 1, 0, 0, 0) != 0:
                raise OSError(ctypes.get_errno(), "Cannot establish child subreaper ownership")
            self.baseline_children = _children(os.getpid())
            kwargs["start_new_session"] = True
        else:
            raise RuntimeError("This qualification owner supports Linux and Windows only")
        try:
            self.process = subprocess.Popen(command, **kwargs)
            if os.name == "nt":
                self._windows_assign_and_resume()
            signal.signal(signal.SIGTERM, self._cancel)
        except BaseException:
            self.close()
            raise

    @staticmethod
    def _cancel(signum, frame):
        raise ProcessCancelled("Qualification process cancelled by SIGTERM")

    def _windows_prepare(self):
        from ctypes import wintypes as w
        self.k = ctypes.WinDLL("kernel32", use_last_error=True)
        class Basic(ctypes.Structure):
            _fields_ = [("process_time", ctypes.c_int64), ("job_time", ctypes.c_int64),
                        ("flags", w.DWORD), ("min_ws", ctypes.c_size_t), ("max_ws", ctypes.c_size_t),
                        ("active_limit", w.DWORD), ("affinity", ctypes.c_size_t),
                        ("priority", w.DWORD), ("scheduling", w.DWORD)]
        class Extended(ctypes.Structure):
            _fields_ = [("basic", Basic), ("io", ctypes.c_uint64 * 6),
                        ("process_memory", ctypes.c_size_t), ("job_memory", ctypes.c_size_t),
                        ("peak_process", ctypes.c_size_t), ("peak_job", ctypes.c_size_t)]
        signatures = {
            "CreateJobObjectW": ([ctypes.c_void_p, w.LPCWSTR], w.HANDLE),
            "SetInformationJobObject": ([w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD], w.BOOL),
            "QueryInformationJobObject": ([w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD, ctypes.c_void_p], w.BOOL),
            "AssignProcessToJobObject": ([w.HANDLE, w.HANDLE], w.BOOL),
            "TerminateJobObject": ([w.HANDLE, w.UINT], w.BOOL),
            "OpenProcess": ([w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
            "OpenThread": ([w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
            "ResumeThread": ([w.HANDLE], w.DWORD),
            "CreateToolhelp32Snapshot": ([w.DWORD, w.DWORD], w.HANDLE),
            "Thread32First": ([w.HANDLE, ctypes.c_void_p], w.BOOL),
            "Thread32Next": ([w.HANDLE, ctypes.c_void_p], w.BOOL),
            "CloseHandle": ([w.HANDLE], w.BOOL),
        }
        for name, (arguments, result) in signatures.items():
            function = getattr(self.k, name)
            function.argtypes, function.restype = arguments, result
        self.job = self.k.CreateJobObjectW(None, None)
        if not self.job:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = Extended()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not self.k.SetInformationJobObject(self.job, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            self.k.CloseHandle(self.job)
            self.job = None
            raise ctypes.WinError(ctypes.get_last_error())

    def _windows_assign_and_resume(self):
        from ctypes import wintypes as w
        handle = self.k.OpenProcess(0x100 | 0x1, False, self.process.pid)  # SET_QUOTA | TERMINATE
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if not self.k.AssignProcessToJobObject(self.job, handle):
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            self.k.CloseHandle(handle)
        class Thread(ctypes.Structure):
            _fields_ = [("size", w.DWORD), ("usage", w.DWORD), ("tid", w.DWORD),
                        ("pid", w.DWORD), ("priority", w.LONG), ("delta", w.LONG), ("flags", w.DWORD)]
        snapshot = self.k.CreateToolhelp32Snapshot(0x4, 0)  # TH32CS_SNAPTHREAD
        if snapshot == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        found = []
        try:
            entry = Thread()
            entry.size = ctypes.sizeof(entry)
            more = self.k.Thread32First(snapshot, ctypes.byref(entry))
            while more:
                if entry.pid == self.process.pid:
                    found.append(entry.tid)
                more = self.k.Thread32Next(snapshot, ctypes.byref(entry))
        finally:
            self.k.CloseHandle(snapshot)
        if len(found) != 1:
            raise RuntimeError("Suspended process did not have exactly one initial thread")
        thread = self.k.OpenThread(0x2, False, found[0])  # THREAD_SUSPEND_RESUME
        if not thread:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if self.k.ResumeThread(thread) == 0xffffffff:
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            self.k.CloseHandle(thread)

    def _windows_active(self):
        from ctypes import wintypes as w
        class Accounting(ctypes.Structure):
            _fields_ = [("times", ctypes.c_int64 * 4), ("faults", w.DWORD),
                        ("total", w.DWORD), ("active", w.DWORD), ("terminated", w.DWORD)]
        value = Accounting()
        if not self.k.QueryInformationJobObject(self.job, 1, ctypes.byref(value), ctypes.sizeof(value), None):
            raise ctypes.WinError(ctypes.get_last_error())
        return value.active

    def _windows_release_parent_handle(self):
        # Job accounting retains an exited process until all references are
        # released. Popen caches returncode, so subsequent poll/wait calls do
        # not need its private Windows handle once wait has completed.
        if self.process is not None and self.process.returncode is not None:
            self.process._handle.Close()

    def _close(self):
        if self.closed:
            return self.had_survivors
        self.closed = True
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        try:
            if os.name == "nt":
                if self.process is not None and self.process.poll() is not None:
                    self._windows_release_parent_handle()
                if self.job:
                    self.had_survivors = self._windows_active() > 0
                    if not self.k.TerminateJobObject(self.job, 125):
                        raise ctypes.WinError(ctypes.get_last_error())
                # Also covers an error before the suspended child was assigned.
                if self.process is not None and self.process.poll() is None:
                    self.process.kill()
                if self.process is not None:
                    self.process.wait(timeout=30)
                    self._windows_release_parent_handle()
                deadline = time.monotonic() + 30
                while self.job and self._windows_active():
                    if time.monotonic() >= deadline:
                        raise RuntimeError("Owned Windows Job did not empty after termination")
                    time.sleep(0.02)
            else:
                pending = _children(os.getpid()) - self.baseline_children
                if self.process is not None and self.process.poll() is None:
                    pending.add(self.process.pid)
                self.had_survivors = bool(pending)
                deadline = time.monotonic() + 30
                while pending:
                    owned = set()
                    queue = list(pending)
                    while queue:
                        pid = queue.pop()
                        if pid in owned:
                            continue
                        owned.add(pid)
                        try:
                            os.kill(pid, signal.SIGSTOP)
                        except ProcessLookupError:
                            pass
                        queue.extend(_children(pid))
                    for pid in owned:
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    if self.process is not None:
                        self.process.wait(timeout=30)
                    for pid in owned:
                        try:
                            os.waitpid(pid, os.WNOHANG)
                        except (ChildProcessError, ProcessLookupError):
                            pass
                    pending = _children(os.getpid()) - self.baseline_children
                    if pending and time.monotonic() >= deadline:
                        raise RuntimeError("Owned Linux descendants survived termination")
                    if pending:
                        time.sleep(0.01)
        finally:
            try:
                if os.name == "nt":
                    try:
                        if self.process is not None:
                            if self.process.poll() is None:
                                self.process.kill()
                                self.process.wait(timeout=30)
                            self._windows_release_parent_handle()
                    finally:
                        if self.job:
                            self.k.CloseHandle(self.job)
                            self.job = None
                else:
                    try:
                        if self.process is not None and self.process.poll() is None:
                            # Even an inventory failure must retire the known process.
                            try:
                                os.killpg(self.process.pid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                            self.process.kill()
                            self.process.wait(timeout=30)
                    finally:
                        self.libc.prctl(36, self.old_subreaper.value, 0, 0, 0)
            finally:
                signal.signal(signal.SIGTERM, self.old_term)
        return self.had_survivors

    def close(self):
        try:
            return self._close()
        except Exception as error:
            raise OwnershipFailure("Owned process teardown could not be established: " + str(error)) from error

    def __enter__(self):
        return self

    def __exit__(self, kind, value, traceback):
        self.close()


def bounded_process(command, *, cwd=None, env=None, stdout=None, timeout: int):
    with OwnedProcess(command, cwd=cwd, env=env, stdout=stdout, stderr=subprocess.STDOUT) as owner:
        try:
            code = owner.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            owner.close()
            return 124, True
        survivors = owner.close()
        return (125 if survivors and code == 0 else code), False
