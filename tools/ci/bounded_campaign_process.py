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

    def retirement_proof(self) -> dict:
        return {"complete": True, "scope": "cooperating Linux process group"}


class _WindowsJob:
    method = "suspended-windows-process-job"

    def __init__(self) -> None:
        from ctypes import wintypes as w
        self.process: subprocess.Popen | None = None
        self.assigned = False
        self.retained: dict[int, int] = {}
        self.owned_handles: list[int] = []
        self.snapshot_total: int | None = None
        self.snapshot_stable = False
        self.termination_requested = False

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

        class ProcessIds(ctypes.Structure):
            # Defensive CI supervision bound, unrelated to native World limits.
            _fields_ = [("assigned", w.DWORD), ("listed", w.DWORD),
                ("pids", ctypes.c_size_t*4096)]

        self.Accounting, self.ThreadEntry, self.ProcessIds = Accounting, ThreadEntry, ProcessIds
        self.Bool = w.BOOL
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
            "OpenProcess": ([w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
            "IsProcessInJob": ([w.HANDLE, w.HANDLE, ctypes.POINTER(w.BOOL)], w.BOOL),
            "WaitForSingleObject": ([w.HANDLE, w.DWORD], w.DWORD),
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

    def _accounting(self):
        account = self.Accounting()
        if not self.api.QueryInformationJobObject(self.handle, 1, ctypes.byref(account), ctypes.sizeof(account), None):
            raise ctypes.WinError(ctypes.get_last_error())
        return account

    def _retain_members(self) -> None:
        self.snapshot_total = self._accounting().total
        if self.assigned:
            # The original Popen handle was retained before Job assignment.
            self.retained[self.process.pid] = int(self.process._handle)
        members = self.ProcessIds()
        if not self.api.QueryInformationJobObject(self.handle, 3, ctypes.byref(members), ctypes.sizeof(members), None):
            raise ctypes.WinError(ctypes.get_last_error())
        if members.listed != members.assigned or members.listed > 4096:
            raise CampaignRetirementError("Job process identity list is incomplete")
        for pid in members.pids[:members.listed]:
            if pid in self.retained:
                continue
            handle = self.api.OpenProcess(0x101000, False, pid)  # SYNCHRONIZE | QUERY_LIMITED_INFORMATION
            if not handle:
                raise ctypes.WinError(ctypes.get_last_error())
            self.owned_handles.append(handle)
            belongs = self.Bool()
            if not self.api.IsProcessInJob(handle, self.handle, ctypes.byref(belongs)):
                raise ctypes.WinError(ctypes.get_last_error())
            if not belongs.value:
                raise CampaignRetirementError("Opened process no longer belongs to the campaign Job")
            self.retained[pid] = handle
        self.snapshot_stable = self._accounting().total == self.snapshot_total

    def active(self) -> list[int]:
        account = self._accounting()
        unassigned = [self.process.pid] if not self.assigned and self.process is not None \
            and self.process.poll() is None else []
        pending = []
        for pid, handle in self.retained.items():
            result = self.api.WaitForSingleObject(handle, 0)
            if result == 258:  # WAIT_TIMEOUT: termination is not yet witnessed.
                pending.append(pid)
            elif result != 0:
                raise CampaignRetirementError("Exact process-handle termination query failed")
        return [0] * account.active + unassigned + pending

    def terminate(self) -> None:
        try:
            try:
                self._retain_members()
            finally:
                if self.handle and not self.api.TerminateJobObject(self.handle, 1):
                    raise ctypes.WinError(ctypes.get_last_error())
                self.termination_requested = True
        finally:
            # Assignment may have failed. Kill only the exact Popen handle that
            # we created; Job retirement alone cannot cover this suspended child.
            if not self.assigned and self.process is not None and self.process.poll() is None:
                self.process.kill()

    def retirement_proof(self) -> dict:
        final = self._accounting()
        complete = self.snapshot_stable and self.snapshot_total == final.total \
            and len(self.retained) == final.total and not self.active()
        # A process removed from the current PID list is not a termination
        # witness. Earlier, unobserved lifetime admissions make proof unknown.
        return {"complete": complete, "scope": "exact retained Windows process handles",
            "job_lifetime_processes": final.total, "retained_job_pids": sorted(self.retained),
            "stable_lifetime_count": self.snapshot_stable and self.snapshot_total == final.total,
            "unassigned_direct_child": self.process.pid if self.process is not None and not self.assigned else None,
            "termination_requested": self.termination_requested}

    def close(self) -> None:
        error = None
        for handle in self.owned_handles:
            if not self.api.CloseHandle(handle):
                error = ctypes.WinError(ctypes.get_last_error())
        self.owned_handles.clear()
        if self.handle:
            handle, self.handle = self.handle, None
            if not self.api.CloseHandle(handle):
                error = ctypes.WinError(ctypes.get_last_error())
        if error is not None:
            raise error


def run_campaign(command: list[str], *, cwd: Path, timeout: float,
                 record_path: Path | None = None) -> subprocess.CompletedProcess:
    """Bound cleanup, separately record proven retirement, preserve failures.

An aggregate timeout is raised after retirement, never converted to a pass.
A parent that reports success while leaving live descendants is also refused.
The fixed 10-second cleanup allowance is separate from the campaign deadline.
Windows lifetime members absent from the retained handle set leave retirement
explicitly unproven. A normal parent return is then only its return status; the
caller must independently verify complete campaign child-wait/custody evidence.
Unknown retirement never authorizes uploading a failed mutable profile tree.
"""
    if not command or any(not isinstance(arg, str) or "\0" in arg for arg in command) \
            or isinstance(timeout, bool) or not isinstance(timeout, (int, float)) \
            or not math.isfinite(timeout) or timeout <= 0:
        raise ValueError("Campaign command and finite positive timeout are required")
    record = {"schema":"gen006-campaign-process-owner-v1","command":command,
        "timeout_seconds":timeout,"retired":False,"status":"preparing","pid":None,
        "process_created":False}
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
        record.update(pid=process.pid,process_created=True,method=owner.method,status="running")
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
                record.update(pid=process.pid,process_created=True,method=owner.method)
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
                proof = owner.retirement_proof()
                record["retirement_proof"] = proof
                record["retired"] = proof["complete"]
            else:
                # The owner constructor has not launched a process.
                record["retired"] = True
                record["retirement_proof"] = {"complete":True,
                    "scope":"no process created", "no_process_created":True}
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
    record.update(status="retired" if record["retired"] else
        ("retirement-failed" if retirement_error is not None else "retirement-unproven"),
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
