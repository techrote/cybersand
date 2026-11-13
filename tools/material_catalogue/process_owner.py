"""Own Windows compiler descendants before any child code can execute.

The unnamed Job Object is private to one Lab operation. It forbids breakaway
and kills its members when its final handle closes, including when the driver
has already exited or the Lab service itself is terminated. No PID tree walk
can provide that lifetime guarantee after the parent process has disappeared.
"""

from __future__ import annotations

import os

CREATE_SUSPENDED = 0x00000004


class WindowsJob:
    """Attach a freshly suspended Popen child, then resume its initial thread."""

    def __init__(self) -> None:
        if os.name != "nt":
            raise OSError("Windows Job Objects require a Windows host")
        import ctypes
        from ctypes import wintypes

        self._ctypes = ctypes
        self._api = ctypes.WinDLL("kernel32", use_last_error=True)
        api = self._api
        signatures = {
            "CreateJobObjectW": ([ctypes.c_void_p, wintypes.LPCWSTR], wintypes.HANDLE),
            "SetInformationJobObject": ([wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD], wintypes.BOOL),
            "AssignProcessToJobObject": ([wintypes.HANDLE, wintypes.HANDLE], wintypes.BOOL),
            "TerminateJobObject": ([wintypes.HANDLE, wintypes.UINT], wintypes.BOOL),
            "CloseHandle": ([wintypes.HANDLE], wintypes.BOOL),
            "OpenProcess": ([wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE),
            "CreateToolhelp32Snapshot": ([wintypes.DWORD, wintypes.DWORD], wintypes.HANDLE),
            "Thread32First": ([wintypes.HANDLE, ctypes.c_void_p], wintypes.BOOL),
            "Thread32Next": ([wintypes.HANDLE, ctypes.c_void_p], wintypes.BOOL),
            "OpenThread": ([wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE),
            "ResumeThread": ([wintypes.HANDLE], wintypes.DWORD),
        }
        for name, (arguments, result) in signatures.items():
            function = getattr(api, name)
            function.argtypes, function.restype = arguments, result

        class BasicLimits(ctypes.Structure):
            _fields_ = [("process_time", ctypes.c_longlong), ("job_time", ctypes.c_longlong),
                        ("flags", wintypes.DWORD), ("minimum_working_set", ctypes.c_size_t),
                        ("maximum_working_set", ctypes.c_size_t), ("active_process_limit", wintypes.DWORD),
                        ("affinity", ctypes.c_size_t), ("priority", wintypes.DWORD),
                        ("scheduling", wintypes.DWORD)]

        class ExtendedLimits(ctypes.Structure):
            _fields_ = [("basic", BasicLimits), ("io", ctypes.c_ulonglong * 6),
                        ("process_memory", ctypes.c_size_t), ("job_memory", ctypes.c_size_t),
                        ("peak_process_memory", ctypes.c_size_t), ("peak_job_memory", ctypes.c_size_t)]

        self._handle = api.CreateJobObjectW(None, None)
        if not self._handle:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = ExtendedLimits()
        limits.basic.flags = 0x00002000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; no breakaway.
        if not api.SetInformationJobObject(self._handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            error = ctypes.WinError(ctypes.get_last_error())
            self.close()
            raise error

    def assign_and_resume(self, process) -> None:
        """Fail closed if ownership cannot be established before execution."""
        ctypes, api = self._ctypes, self._api
        from ctypes import wintypes

        # A suspended process cannot create descendants between this assignment
        # and ResumeThread. Open only the access rights needed by assignment.
        child = api.OpenProcess(0x0101, False, process.pid)  # SET_QUOTA | TERMINATE
        if not child:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if not api.AssignProcessToJobObject(self._handle, child):
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            api.CloseHandle(child)

        # Popen closes the initial thread handle. Use documented Toolhelp APIs
        # to reopen only this still-suspended child's unique initial thread.
        class ThreadEntry(ctypes.Structure):
            _fields_ = [("size", wintypes.DWORD), ("usage", wintypes.DWORD),
                        ("thread_id", wintypes.DWORD), ("owner_pid", wintypes.DWORD),
                        ("base_priority", wintypes.LONG), ("delta_priority", wintypes.LONG),
                        ("flags", wintypes.DWORD)]

        snapshot = api.CreateToolhelp32Snapshot(0x00000004, 0)  # TH32CS_SNAPTHREAD
        if snapshot == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        thread_ids = []
        try:
            entry = ThreadEntry()
            entry.size = ctypes.sizeof(entry)
            present = api.Thread32First(snapshot, ctypes.byref(entry))
            while present:
                if entry.owner_pid == process.pid:
                    thread_ids.append(entry.thread_id)
                entry.size = ctypes.sizeof(entry)
                present = api.Thread32Next(snapshot, ctypes.byref(entry))
            if ctypes.get_last_error() != 18:  # ERROR_NO_MORE_FILES
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            api.CloseHandle(snapshot)
        if len(thread_ids) != 1:
            raise OSError("Cannot identify the owned child's unique suspended initial thread")
        thread = api.OpenThread(0x0002, False, thread_ids[0])  # THREAD_SUSPEND_RESUME
        if not thread:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            previous = api.ResumeThread(thread)
            if previous == 0xFFFFFFFF:
                raise ctypes.WinError(ctypes.get_last_error())
            if previous != 1:
                raise OSError("Owned child did not have exactly one initial suspension")
        finally:
            api.CloseHandle(thread)

    def terminate(self) -> None:
        if self._handle and not self._api.TerminateJobObject(self._handle, 1):
            raise self._ctypes.WinError(self._ctypes.get_last_error())

    def close(self) -> None:
        if self._handle:
            handle, self._handle = self._handle, None
            if not self._api.CloseHandle(handle):
                raise self._ctypes.WinError(self._ctypes.get_last_error())
