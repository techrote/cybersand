"""Actual Windows sharing-lock fixture for bounded storage qualification.

Extracted unchanged from ULTIMA checkpoint 7919e8a752e87e68c4193b3a04960164ab62e117,
run_workbench_save_qualification.py (original helper donor 0395a0e1dcb8d397943883a675ca9861cf62acdd).
The held READ handle refuses DELETE sharing; the fixture verifies that Windows
actually returns sharing violation 32 before yielding it. This supplies a fault
boundary, not a production lock or a claim of platform qualification.
"""
from __future__ import annotations

from contextlib import contextmanager
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


@contextmanager
def windows_lock(path: Path, *, source: bool = False):
    """An actual READ handle; omit DELETE sharing for the selected endpoint."""
    import ctypes
    from ctypes import wintypes
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    create = kernel.CreateFileW
    create.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                       ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    create.restype = wintypes.HANDLE
    close = kernel.CloseHandle
    close.argtypes = [wintypes.HANDLE]
    close.restype = wintypes.BOOL
    handle = create(str(path), 0x80000000, 3 if source else 1, None, 3, 0x80, None)
    require(handle != wintypes.HANDLE(-1).value,
            f"Could not establish Windows sharing lock: {ctypes.get_last_error()}")
    try:
        # Verify the actual causal fence, without deleting or modifying a file.
        probe = create(str(path), 0x10000, 7, None, 3, 0x80, None)
        error = ctypes.get_last_error()
        if probe != wintypes.HANDLE(-1).value:
            close(probe)
            raise RuntimeError("Windows fixture did not deny DELETE access")
        require(error == 32, f"Expected Windows sharing violation 32, observed {error}")
        yield {"desired_access": 0x80000000, "share_mode": 3 if source else 1,
               "delete_access_probe_error": error}
    finally:
        require(bool(close(handle)), "Could not close Windows sharing-lock handle")
