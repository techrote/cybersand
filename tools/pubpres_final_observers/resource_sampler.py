#!/usr/bin/env python3
"""Read actual process CPU accounting without changing child ownership.

Each Windows handle is opened, queried and closed within one sample. It cannot
outlive the existing runner's sampling iteration or retain an exited Job member.
Counters include the Godot process's threads; they exclude other processes.
"""
from __future__ import annotations

import ctypes
import hashlib
import math
import os
from pathlib import Path
import sys
import time


def _filetime(value) -> int:
    return (int(value.dwHighDateTime) << 32) | int(value.dwLowDateTime)


def linux_stat_sample(text: str, pid: int, elapsed_ms: float, ticks_per_second: int) -> dict:
    # comm can contain spaces and closing parentheses; the final ')' terminates
    # that field. Fields after it begin with state (field 3).
    prefix, fields = text.rsplit(")", 1)
    values = fields.split()
    if int(prefix.split("(", 1)[0].strip()) != pid or len(values) < 20 or ticks_per_second <= 0:
        raise ValueError("Incomplete process CPU identity")
    user, kernel, start = (int(values[index]) for index in (11, 12, 19))
    if min(user, kernel, start) < 0:
        raise ValueError("Negative process CPU accounting")
    return {"pid": pid, "elapsed_ms": elapsed_ms, "creation_identity": "linux-start-ticks:" + str(start),
            "user_units": user, "kernel_units": kernel, "units_per_second": ticks_per_second,
            "user_seconds": user / ticks_per_second, "kernel_seconds": kernel / ticks_per_second,
            "accounting": "Linux /proc/PID/stat utime+stime; child-process cutime/cstime excluded"}


def _raw_cpu_sample(pid: int, elapsed_ms: float) -> dict:
    if type(pid) is not int or pid <= 0 or not math.isfinite(elapsed_ms) or elapsed_ms < 0:
        raise ValueError("Invalid process sampling request")
    if os.name == "nt":
        from ctypes import wintypes as w
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = (w.DWORD, w.BOOL, w.DWORD)
        kernel.OpenProcess.restype = w.HANDLE
        kernel.GetProcessTimes.argtypes = (w.HANDLE, ctypes.POINTER(w.FILETIME), ctypes.POINTER(w.FILETIME),
                                          ctypes.POINTER(w.FILETIME), ctypes.POINTER(w.FILETIME))
        kernel.GetProcessTimes.restype = w.BOOL
        kernel.CloseHandle.argtypes = (w.HANDLE,)
        kernel.CloseHandle.restype = w.BOOL
        handle = kernel.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION only.
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        created, exited, system, user = (w.FILETIME() for _ in range(4))
        try:
            if not kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited),
                                          ctypes.byref(system), ctypes.byref(user)):
                raise ctypes.WinError(ctypes.get_last_error())
            user_units, kernel_units = _filetime(user), _filetime(system)
            return {"pid": pid, "elapsed_ms": elapsed_ms,
                    "creation_identity": "windows-filetime:" + str(_filetime(created)),
                    "user_units": user_units, "kernel_units": kernel_units, "units_per_second": 10_000_000,
                    "user_seconds": user_units / 10_000_000, "kernel_seconds": kernel_units / 10_000_000,
                    "accounting": "Windows GetProcessTimes user+kernel accounting, in 100ns units"}
        finally:
            if not kernel.CloseHandle(handle):
                raise ctypes.WinError(ctypes.get_last_error())
    if sys.platform.startswith("linux"):
        return linux_stat_sample(Path(f"/proc/{pid}/stat").read_text(), pid, elapsed_ms, os.sysconf("SC_CLK_TCK"))
    raise OSError("Only actual Windows and Linux process CPU accounting are registered")


def process_cpu_sample(pid: int, elapsed_ms: float) -> dict:
    started = time.perf_counter_ns()
    try:
        row = _raw_cpu_sample(pid,elapsed_ms)
    except (OSError, ValueError) as error:
        error.sampler_elapsed_usec = (time.perf_counter_ns()-started+999)//1000
        raise
    row["sampler_elapsed_usec"] = (time.perf_counter_ns()-started+999)//1000
    return row


def summarize_cpu(samples: list[dict], *, expected_pid: int | None, errors: list[dict], dropped: int = 0) -> dict:
    """No interpolation into Godot capture clocks and no unseen exit credit."""
    problems = []
    if len(samples) < 2:
        problems.append("At least two actual process CPU samples are required")
    identities = {(row.get("pid"), row.get("creation_identity"), row.get("units_per_second")) for row in samples}
    if len(identities) != 1 or any(row.get("pid") != expected_pid for row in samples):
        problems.append("Process PID or creation identity changed or disagrees with the owned child")
    for index, row in enumerate(samples):
        if not (type(row.get("pid")) is int and row["pid"] > 0
                and isinstance(row.get("creation_identity"), str) and row["creation_identity"]
                and type(row.get("units_per_second")) is int and row["units_per_second"] > 0
                and all(type(row.get(key)) is int and row[key] >= 0 for key in ("user_units", "kernel_units"))
                and type(row.get("sampler_elapsed_usec")) is int and row["sampler_elapsed_usec"] >= 0
                and type(row.get("elapsed_ms")) in (int, float) and math.isfinite(row["elapsed_ms"]) and row["elapsed_ms"] >= 0):
            problems.append("Malformed CPU sample")
            break
        if row.get("user_seconds") != row["user_units"] / row["units_per_second"] or row.get("kernel_seconds") != row["kernel_units"] / row["units_per_second"]:
            problems.append("CPU seconds do not match raw accounting units")
        if index and (row["elapsed_ms"] <= samples[index-1]["elapsed_ms"]
                      or row["user_units"] < samples[index-1]["user_units"]
                      or row["kernel_units"] < samples[index-1]["kernel_units"]):
            problems.append("CPU or sample clock regressed")
    if dropped:
        problems.append("Bounded CPU sample capacity was exceeded")
    if not all(type(error.get("sampler_elapsed_usec")) is int and error["sampler_elapsed_usec"] >= 0 for error in errors):
        problems.append("Failed CPU query cost is missing")
    result = {"schema": "pubpres-final-process-cpu-summary-v1", "complete": not problems,
              "problems": problems, "samples": len(samples), "sample_errors": len(errors), "dropped": dropped,
              "expected_pid": expected_pid,
              "sampler_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "external_sampler_wall_usec": sum(row.get("sampler_elapsed_usec",0) for row in samples) + sum(error.get("sampler_elapsed_usec",0) or 0 for error in errors),
              "external_sampler_max_read_usec": max([row.get("sampler_elapsed_usec",0) for row in samples] + [error.get("sampler_elapsed_usec",0) or 0 for error in errors],default=0),
              "scope": "Actual owned Godot process CPU accounting, all its threads. Includes scene setup and capture inside the sampled process lifetime. Samples are not aligned to Godot capture clocks. The unobserved launch/exit tail is excluded from interval deltas; last cumulative counters are lower bounds on lifetime CPU. Read time for successful and failed queries is external sampler wall cost, not Godot CPU; elapsed_ms marks query request, not an instantaneous kernel accounting timestamp. No GPU busy-time or hardware utilization claim."}
    if problems:
        return result
    first, last = samples[0], samples[-1]
    wall = (last["elapsed_ms"] - first["elapsed_ms"]) / 1000
    user = (last["user_units"] - first["user_units"]) / first["units_per_second"]
    kernel = (last["kernel_units"] - first["kernel_units"]) / first["units_per_second"]
    result.update(creation_identity=first["creation_identity"], first_sample_elapsed_ms=first["elapsed_ms"],
                  last_sample_elapsed_ms=last["elapsed_ms"], observed_interval_seconds=wall,
                  observed_user_seconds=user, observed_kernel_seconds=kernel,
                  mean_cpu_core_equivalents=(user + kernel) / wall,
                  last_cumulative_user_seconds=last["user_seconds"], last_cumulative_kernel_seconds=last["kernel_seconds"],
                  maximum_sample_gap_ms=max(b["elapsed_ms"]-a["elapsed_ms"] for a, b in zip(samples, samples[1:])))
    return result
