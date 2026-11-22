#!/usr/bin/env python3
"""Bound the GEN-006 aggregate runner and retire its descendants before upload.

This is CI process ownership, not simulation or persistence logic. Linux uses a
new process group for the known campaign commands (which do not detach from it).
Windows assigns a suspended process to an unnamed, non-breakaway Job Object
before resuming its initial thread. No process-name matching is used.

Windows contracts: https://learn.microsoft.com/windows/win32/procthread/job-objects
and the documented Tool Help Thread32First/Thread32Next/OpenThread/ResumeThread
APIs. Popen closes the original primary-thread handle; it is not borrowed here.
"""
from __future__ import annotations

import ctypes
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


class CampaignRetirementError(RuntimeError):
    """A campaign left live descendants or their retirement was not proven."""


class _LinuxGroup:
    method = "owned-linux-process-group"

    def __init__(self) -> None:
        self.pid = 0
        self.process: subprocess.Popen | None = None

    def launch(self, command: list[str], cwd: Path) -> subprocess.Popen:
        process = subprocess.Popen(command, cwd=cwd, start_new_session=True)
        self.process = process
        if process.pid <= 1 or process.pid == os.getpgrp():
            raise CampaignRetirementError("Campaign did not acquire a distinct process group")
        self.pid = process.pid
        return process

    def active(self) -> list[int]:
        result = []
        if not self.pid:
            return [self.process.pid] if self.process is not None and self.process.poll() is None else []
        for folder in Path("/proc").iterdir():
            if not folder.name.isdecimal():
                continue
            try:
                text = (folder/"stat").read_text()
            except (FileNotFoundError, ProcessLookupError):
                continue
            fields = text[text.rfind(")")+2:].split()
            if len(fields) >= 3 and int(fields[2]) == self.pid and fields[0] not in ("Z", "X"):
                result.append(int(folder.name))
        return result

    def terminate(self) -> None:
        if self.pid:
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        elif self.process is not None and self.process.poll() is None:
            self.process.kill()

    def close(self) -> None:
        self.pid = 0


class _WindowsJob:
    method = "suspended-windows-process-job"

    def __init__(self) -> None:
        from ctypes import wintypes as w
        self.process: subprocess.Popen | None = None
        self.assigned = False

        class BasicLimits(ctypes.Structure):
            _fields_ = [("process_time", ctypes.c_longlong), ("job_time", ctypes.c_longlong),
                ("flags", w.DWORD), ("minimum_working_set", ctypes.c_size_t),
                ("maximum_working_set", ctypes.c_size_t), ("active_limit", w.DWORD),
                ("affinity", ctypes.c_size_t), ("priority", w.DWORD), ("scheduling", w.DWORD)]

        class IO(ctypes.Structure):
            _fields_ = [("values", ctypes.c_ulonglong*6)]

        class ExtendedLimits(ctypes.Structure):
            _fields_ = [("basic", BasicLimits), ("io", IO), ("process_memory", ctypes.c_size_t),
                ("job_memory", ctypes.c_size_t), ("peak_process_memory", ctypes.c_size_t),
                ("peak_job_memory", ctypes.c_size_t)]

        class Accounting(ctypes.Structure):
            _fields_ = [("times", ctypes.c_longlong*4), ("faults", w.DWORD),
                ("total", w.DWORD), ("active", w.DWORD), ("terminated", w.DWORD)]

        class ThreadEntry(ctypes.Structure):
            _fields_ = [("size", w.DWORD), ("usage", w.DWORD), ("thread_id", w.DWORD),
                ("process_id", w.DWORD), ("base_priority", w.LONG),
                ("delta_priority", w.LONG), ("flags", w.DWORD)]

        self.Accounting, self.ThreadEntry = Accounting, ThreadEntry
        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        declarations = {
            "CreateJobObjectW": ([ctypes.c_void_p, w.LPCWSTR], w.HANDLE),
            "SetInformationJobObject": ([w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD], w.BOOL),
            "QueryInformationJobObject": ([w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD, ctypes.c_void_p], w.BOOL),
            "AssignProcessToJobObject": ([w.HANDLE, w.HANDLE], w.BOOL),
            "TerminateJobObject": ([w.HANDLE, w.UINT], w.BOOL),
            "CloseHandle": ([w.HANDLE], w.BOOL),
            "CreateToolhelp32Snapshot": ([w.DWORD, w.DWORD], w.HANDLE),
            "Thread32First": ([w.HANDLE, ctypes.POINTER(ThreadEntry)], w.BOOL),
            "Thread32Next": ([w.HANDLE, ctypes.POINTER(ThreadEntry)], w.BOOL),
            "OpenThread": ([w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
            "GetProcessIdOfThread": ([w.HANDLE], w.DWORD),
            "ResumeThread": ([w.HANDLE], w.DWORD),
        }
        for name, (args, result) in declarations.items():
            function = getattr(self.api, name)
            function.argtypes, function.restype = args, result
        self.handle = self.api.CreateJobObjectW(None, None)
        if not self.handle:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = ExtendedLimits()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; no breakaway.
        if not self.api.SetInformationJobObject(self.handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            error = ctypes.WinError(ctypes.get_last_error())
            self.close()
            raise error

    def launch(self, command: list[str], cwd: Path) -> subprocess.Popen:
        process = subprocess.Popen(command, cwd=cwd, creationflags=0x4)  # CREATE_SUSPENDED
        # Retain the exact child before any fallible assignment/resume operation.
        # An empty Job is not proof of retirement if this child was not assigned.
        self.process = process
        if not self.api.AssignProcessToJobObject(self.handle, int(process._handle)):
            raise ctypes.WinError(ctypes.get_last_error())
        self.assigned = True
        self._resume_initial_thread(process.pid)
        return process

    def _resume_initial_thread(self, pid: int) -> None:
        snapshot = self.api.CreateToolhelp32Snapshot(0x4, 0)  # TH32CS_SNAPTHREAD
        if snapshot == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            entry = self.ThreadEntry()
            entry.size = ctypes.sizeof(entry)
            found = []
            more = self.api.Thread32First(snapshot, ctypes.byref(entry))
            while more:
                if entry.process_id == pid:
                    found.append(entry.thread_id)
                entry.size = ctypes.sizeof(entry)
                more = self.api.Thread32Next(snapshot, ctypes.byref(entry))
            if ctypes.get_last_error() != 18:  # ERROR_NO_MORE_FILES
                raise ctypes.WinError(ctypes.get_last_error())
            if len(found) != 1:
                raise CampaignRetirementError("Suspended campaign has no unique initial thread")
            # Verify the opened handle, not only the earlier numeric snapshot ID.
            thread = self.api.OpenThread(0x0802, False, found[0])  # QUERY_LIMITED_INFORMATION | SUSPEND_RESUME
            if not thread:
                raise ctypes.WinError(ctypes.get_last_error())
            try:
                if self.api.GetProcessIdOfThread(thread) != pid:
                    raise CampaignRetirementError("Opened initial thread no longer belongs to the campaign")
                if self.api.ResumeThread(thread) != 1:
                    raise CampaignRetirementError("Campaign initial thread did not resume from one suspension")
            finally:
                self.api.CloseHandle(thread)
        finally:
            self.api.CloseHandle(snapshot)

    def active(self) -> list[int]:
        account = self.Accounting()
        if not self.api.QueryInformationJobObject(self.handle, 1, ctypes.byref(account), ctypes.sizeof(account), None):
            raise ctypes.WinError(ctypes.get_last_error())
        # Only cardinality is required; no unrelated system PID is inspected.
        unassigned = [self.process.pid] if not self.assigned and self.process is not None \
            and self.process.poll() is None else []
        return [0] * account.active + unassigned

    def terminate(self) -> None:
        try:
            if self.handle and not self.api.TerminateJobObject(self.handle, 1):
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            # Assignment may have failed. Kill only the exact Popen handle that
            # we created; Job retirement alone cannot cover this suspended child.
            if not self.assigned and self.process is not None and self.process.poll() is None:
                self.process.kill()

    def close(self) -> None:
        if self.handle:
            handle, self.handle = self.handle, None
            if not self.api.CloseHandle(handle):
                raise ctypes.WinError(ctypes.get_last_error())


def run_campaign(command: list[str], *, cwd: Path, timeout: float,
                 record_path: Path | None = None) -> subprocess.CompletedProcess:
    """Return only after the owned process scope is quiescent; preserve failures.

An aggregate timeout is raised after retirement, never converted to a pass.
A parent that reports success while leaving live descendants is also refused.
The fixed 10-second cleanup allowance is separate from the campaign deadline.
"""
    if not command or any(not isinstance(arg, str) or "\0" in arg for arg in command) \
            or isinstance(timeout, bool) or not isinstance(timeout, (int, float)) \
            or not math.isfinite(timeout) or timeout <= 0:
        raise ValueError("Campaign command and finite positive timeout are required")
    record = {"schema":"gen006-campaign-process-owner-v1","command":command,
        "timeout_seconds":timeout,"retired":False,"status":"preparing","pid":None}
    def write_record() -> None:
        if record_path is not None:
            temporary = Path(record_path).with_name(Path(record_path).name+".tmp")
            temporary.write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
            temporary.replace(record_path)
    write_record()  # Storage refusal occurs before launching any descendant.
    owner = None
    process = None
    outcome: BaseException | None = None
    retirement_error: BaseException | None = None
    escaped_success = False
    left_descendants = False
    began = time.monotonic()
    try:
        if os.name == "nt":
            owner = _WindowsJob()
        elif sys.platform.startswith("linux"):
            owner = _LinuxGroup()
        else:
            raise CampaignRetirementError("Only qualified Linux and Windows campaign owners are supported")
        process = owner.launch(command, Path(cwd))
        record.update(pid=process.pid,method=owner.method,status="running")
        write_record()
        process.wait(timeout=timeout)
        left_descendants = bool(owner.active())
        escaped_success = process.returncode == 0 and left_descendants
    except BaseException as error:
        outcome = error
    finally:
        if owner is not None and process is None:
            process = owner.process
            if process is not None:
                record.update(pid=process.pid, method=owner.method)
        try:
            if owner is not None:
                # Retire even on launch/resume/observation failure or early exit.
                deadline = time.monotonic()+10
                owner.terminate()
                if process is not None:
                    process.wait(timeout=max(0.001,deadline-time.monotonic()))
                while owner.active():
                    if time.monotonic() >= deadline:
                        raise CampaignRetirementError("Campaign descendants did not retire before evidence upload")
                    time.sleep(0.02)
                record["retired"] = True
            else:
                # The owner constructor has not launched a process.
                record["retired"] = True
        except BaseException as error:
            retirement_error = error
            record["retired"] = False
        finally:
            if owner is not None:
                try:
                    owner.close()
                except BaseException as error:
                    retirement_error = error
                    record["retired"] = False
    record.update(status="retired" if record["retired"] else "retirement-failed",
        returncode=process.returncode if process is not None else None,
        timed_out=isinstance(outcome,subprocess.TimeoutExpired),parent_left_descendants=left_descendants,
        elapsed_seconds=time.monotonic()-began,
        original_error=repr(outcome) if outcome is not None else "",
        retirement_error=repr(retirement_error) if retirement_error is not None else "")
    write_record()
    print("GEN006_CAMPAIGN_PROCESS_OWNER "+json.dumps(record),flush=True)
    if retirement_error is not None:
        raise CampaignRetirementError("Campaign process retirement could not be proven") from retirement_error
    if outcome is not None:
        raise outcome
    if escaped_success:
        raise CampaignRetirementError("Campaign parent exited successfully with live descendants")
    return subprocess.CompletedProcess(command, process.returncode)
