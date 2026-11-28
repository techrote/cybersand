"""Bounded, read-only CPU/RSS observations for Strata qualification processes.

This keeps the established landscape runner's command, log and timeout contract.
It observes the actual launched process and sampled descendants, including the
Windows console wrapper's Godot engine. It does not alter renderer scheduling.
The process APIs follow execution_telemetry.py, run_flatten_qualification.py and
palette_windows_compiler.py; none of those existing observers enumerates trees.
"""
from __future__ import annotations

import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import qualify_workbench_landscapes as custody

SAMPLE_SECONDS = 0.5
MAX_INVENTORY = 16384
MAX_PROCESSES = 128
MAX_SAMPLES = 1203


class LinuxReader:
    def __init__(self):
        own = int(Path("/proc/self/stat").read_text().split(" ", 1)[0])
        if own != os.getpid():
            raise RuntimeError("proc_pid_namespace_mismatch")
        self.clock = os.sysconf("SC_CLK_TCK")
        self.page = os.sysconf("SC_PAGE_SIZE")

    def inventory(self) -> dict:
        result = {}
        for path in Path("/proc").iterdir():
            if not path.name.isdigit():
                continue
            if len(result) >= MAX_INVENTORY:
                raise RuntimeError("process_inventory_bound_exceeded")
            try:
                text = (path / "stat").read_text()
                fields = text.rsplit(")", 1)[1].split()
                result[int(path.name)] = {
                    "pid": int(path.name), "parent_pid": int(fields[1]), "start_id": int(fields[19]),
                    "image_name": text.split("(", 1)[1].rsplit(")", 1)[0],
                    "cpu_seconds": (int(fields[11]) + int(fields[12])) / self.clock,
                    "rss_bytes": max(0, int(fields[21])) * self.page,
                }
            except (OSError, ValueError, IndexError):
                # Unrelated processes routinely exit during enumeration.
                continue
        return result

    def observe(self, row: dict) -> dict:
        result = dict(row, os_peak_rss_bytes=None)
        try:
            for line in Path(f"/proc/{row['pid']}/status").read_text().splitlines():
                if line.startswith("VmHWM:"):
                    result["os_peak_rss_bytes"] = int(line.split()[1]) * 1024
                    break
        except (OSError, ValueError, IndexError):
            pass
        return result


class WindowsReader:
    """Typed query-only Win32 handles; every snapshot/process handle is closed."""
    def __init__(self):
        import ctypes as C
        from ctypes import wintypes as W

        class ProcessEntry(C.Structure):
            # https://learn.microsoft.com/windows/win32/api/tlhelp32/ns-tlhelp32-processentry32w
            _fields_ = [("size", W.DWORD), ("usage", W.DWORD), ("pid", W.DWORD),
                        ("heap", C.c_size_t), ("module", W.DWORD), ("threads", W.DWORD),
                        ("parent", W.DWORD), ("priority", W.LONG), ("flags", W.DWORD),
                        ("image", W.WCHAR * 260)]

        class FileTime(C.Structure):
            _fields_ = [("low", W.DWORD), ("high", W.DWORD)]

            def value(self):
                return int(self.low) | (int(self.high) << 32)

        class Memory(C.Structure):
            _fields_ = [("size", W.DWORD), ("faults", W.DWORD)] + [(name, C.c_size_t) for name in (
                "peak_rss", "rss", "peak_paged", "paged", "peak_nonpaged", "nonpaged", "pagefile", "peak_pagefile")]

        self.C, self.Entry, self.Time, self.Memory = C, ProcessEntry, FileTime, Memory
        self.kernel = C.WinDLL("kernel32.dll", use_last_error=True)
        self.psapi = C.WinDLL("psapi.dll", use_last_error=True)
        signatures = {
            "CreateToolhelp32Snapshot": ([W.DWORD, W.DWORD], W.HANDLE),
            "Process32FirstW": ([W.HANDLE, C.POINTER(ProcessEntry)], W.BOOL),
            "Process32NextW": ([W.HANDLE, C.POINTER(ProcessEntry)], W.BOOL),
            "OpenProcess": ([W.DWORD, W.BOOL, W.DWORD], W.HANDLE),
            "CloseHandle": ([W.HANDLE], W.BOOL),
            "GetProcessTimes": ([W.HANDLE, *([C.POINTER(FileTime)] * 4)], W.BOOL),
        }
        for name, (arguments, returns) in signatures.items():
            function = getattr(self.kernel, name)
            function.argtypes, function.restype = arguments, returns
        self.psapi.GetProcessMemoryInfo.argtypes = [W.HANDLE, C.POINTER(Memory), W.DWORD]
        self.psapi.GetProcessMemoryInfo.restype = W.BOOL

    def inventory(self) -> dict:
        C, api = self.C, self.kernel
        handle = api.CreateToolhelp32Snapshot(0x00000002, 0)  # TH32CS_SNAPPROCESS
        if handle == C.c_void_p(-1).value:
            raise C.WinError(C.get_last_error())
        result = {}
        try:
            entry = self.Entry()
            entry.size = C.sizeof(entry)
            present = api.Process32FirstW(handle, C.byref(entry))
            while present:
                if len(result) >= MAX_INVENTORY:
                    raise RuntimeError("process_inventory_bound_exceeded")
                result[int(entry.pid)] = {"pid": int(entry.pid), "parent_pid": int(entry.parent),
                                          "image_name": str(entry.image)}
                present = api.Process32NextW(handle, C.byref(entry))
            if C.get_last_error() not in (0, 18):  # ERROR_NO_MORE_FILES
                raise C.WinError(C.get_last_error())
        finally:
            api.CloseHandle(handle)
        return result

    def observe(self, row: dict) -> dict:
        C, api = self.C, self.kernel
        handle = api.OpenProcess(0x0400 | 0x0010, False, row["pid"])  # QUERY_INFORMATION | VM_READ
        if not handle:
            raise C.WinError(C.get_last_error())
        try:
            created, exited, kernel, user = (self.Time() for _ in range(4))
            if not api.GetProcessTimes(handle, C.byref(created), C.byref(exited), C.byref(kernel), C.byref(user)):
                raise C.WinError(C.get_last_error())
            memory = self.Memory()
            memory.size = C.sizeof(memory)
            if not self.psapi.GetProcessMemoryInfo(handle, C.byref(memory), memory.size):
                raise C.WinError(C.get_last_error())
            return dict(row, start_id=created.value(), cpu_seconds=(kernel.value() + user.value()) / 10_000_000,
                        rss_bytes=int(memory.rss), os_peak_rss_bytes=int(memory.peak_rss))
        finally:
            api.CloseHandle(handle)


class ProcessTree:
    def __init__(self, pid: int, started: float):
        self.pid, self.started = pid, started
        self.reader = WindowsReader() if sys.platform == "win32" else LinuxReader()
        self.root_start = None
        self.latest = {}
        self.samples = []
        self.errors = []
        self.observer_seconds = 0.0

    def error(self, message: str) -> None:
        if message not in self.errors and len(self.errors) < 32:
            self.errors.append(message)

    def sample(self) -> None:
        began = time.monotonic()
        try:
            if len(self.samples) >= MAX_SAMPLES:
                raise RuntimeError("sample_count_bound_exceeded")
            inventory = self.reader.inventory()
            active = {}
            attempted = set()

            def observe(pid: int, expected_start=None, parent_start=None):
                if pid in attempted or pid not in inventory:
                    return
                attempted.add(pid)
                try:
                    row = self.reader.observe(inventory[pid])
                    if expected_start is not None and row["start_id"] != expected_start:
                        self.error("pid_reuse_rejected:" + str(pid))
                        return
                    if parent_start is not None and row["start_id"] < parent_start:
                        self.error("older_process_cannot_be_descendant:" + str(pid))
                        return
                    active[pid] = row
                except (OSError, ValueError, IndexError) as error:
                    self.error("process_observation_unavailable:" + str(pid) + ":" + type(error).__name__)

            observe(self.pid, self.root_start)
            if self.pid in active and self.root_start is None:
                self.root_start = active[self.pid]["start_id"]
            for pid, start_id in self.latest:
                observe(pid, start_id)
            changed = True
            while changed:
                changed = False
                for pid, row in inventory.items():
                    parent = active.get(row["parent_pid"])
                    if pid not in attempted and parent is not None:
                        if len(active) >= MAX_PROCESSES:
                            raise RuntimeError("descendant_count_bound_exceeded")
                        observe(pid, parent_start=parent["start_id"])
                        changed = changed or pid in active
            for row in active.values():
                identity = (row["pid"], row["start_id"])
                previous = self.latest.get(identity)
                if previous is None and len(self.latest) >= MAX_PROCESSES:
                    raise RuntimeError("observed_process_identity_bound_exceeded")
                if previous is not None and row["cpu_seconds"] < previous["cpu_seconds"]:
                    self.error("cpu_counter_regressed:" + str(row["pid"]))
                    continue
                self.latest[identity] = row
            self.samples.append({"elapsed_seconds": round(began - self.started, 6),
                                 "processes": sorted(active.values(), key=lambda row: row["pid"]),
                                 "tree_cpu_seconds_observed": sum(row["cpu_seconds"] for row in self.latest.values()),
                                 "tree_rss_bytes": sum(row["rss_bytes"] for row in active.values())})
        except (OSError, RuntimeError, ValueError, IndexError) as error:
            self.error(str(error))
        finally:
            self.observer_seconds += time.monotonic() - began

    def receipt(self) -> dict:
        return {"schema": "strata-process-resources-v1", "available": bool(self.latest),
                "scope": "observed_process_and_descendants", "sample_interval_seconds": SAMPLE_SECONDS,
                "root_pid": self.pid, "root_start_id": self.root_start,
                "process_identities": [list(identity) for identity in sorted(self.latest)],
                "sample_count": len(self.samples), "samples": self.samples,
                "observed_cpu_seconds": sum(row["cpu_seconds"] for row in self.latest.values()),
                "peak_observed_tree_rss_bytes": max((sample["tree_rss_bytes"] for sample in self.samples), default=0),
                "observer_wall_seconds": self.observer_seconds, "observation_errors": self.errors,
                "semantics": "Last observed per-process user+kernel CPU counters; sampled simultaneous RSS/working-set sum. "
                             "Short-lived descendants and exit tails may be missed; shared pages may be counted more than once. "
                             "OS per-process peak counters are separate. No GPU-memory or presented-FPS measurement."}


def execute(command: list[str], location: Path, environment: dict, timeout: float,
            *, maximum_timeout: float = 600) -> dict:
    """The custody.execute API, with original logs plus bounded resource samples."""
    custody.require(type(maximum_timeout) in (int, float) and math.isfinite(maximum_timeout)
                    and 0 < maximum_timeout <= 1800,
                    "Invalid explicitly bounded observation ceiling")
    custody.require(type(timeout) in (int, float) and math.isfinite(timeout) and 0 < timeout <= maximum_timeout,
                    "Invalid resource-observation process timeout")
    location.mkdir(parents=True, exist_ok=False)
    log = location / "process.log"
    record = {"command": command, "timeout_seconds": timeout, "status": "running"}
    started = time.monotonic()
    process = observer = None
    resources = {"schema": "strata-process-resources-v1", "available": False,
                 "scope": "observed_process_and_descendants", "reason": "process_not_started"}
    try:
        with log.open("w", encoding="utf-8") as output:
            process = subprocess.Popen(command, cwd=custody.ROOT, env=environment, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=(sys.platform != "win32"))
            record["pid"] = process.pid
            try:
                observer = ProcessTree(process.pid, started)
            except (OSError, RuntimeError, ValueError) as error:
                resources["reason"] = str(error)
            while process.poll() is None:
                remaining = timeout - (time.monotonic() - started)
                if remaining <= 0:
                    if sys.platform == "win32":
                        # The pinned Godot wrapper owns a kill-on-close job.
                        process.kill()
                    else:
                        os.killpg(process.pid, signal.SIGKILL)
                    record["exit_code"] = process.wait(timeout=15)
                    record["status"] = "timeout"
                    raise RuntimeError("Godot process exceeded its recorded timeout")
                if observer is not None:
                    observer.sample()
                remaining = timeout - (time.monotonic() - started)
                try:
                    process.wait(timeout=max(0.001, min(SAMPLE_SECONDS, remaining)))
                except subprocess.TimeoutExpired:
                    pass
            record["exit_code"] = process.returncode
        text = log.read_text(encoding="utf-8", errors="replace")
        custody.require(record["exit_code"] == 0 and not custody.ERRORS.search(text),
                        "Godot process failed; inspect " + str(log))
        record["status"] = "passed"
    except Exception as error:
        record["error"] = str(error)
        if record["status"] == "running":
            record["status"] = "failed"
    finally:
        if process is not None and process.poll() is None:
            # An observer or I/O exception must not leave an unbounded target.
            try:
                if sys.platform == "win32":
                    process.kill()
                else:
                    os.killpg(process.pid, signal.SIGKILL)
                record["exit_code"] = process.wait(timeout=15)
            except (OSError, subprocess.TimeoutExpired) as error:
                record["cleanup_error"] = str(error)
        if observer is not None:
            resources = observer.receipt()
        resource_path = location / "resources.json"
        custody.write_json(resource_path, resources)
        record["resources"] = {key: value for key, value in resources.items() if key != "samples"}
        record["resources_sha256"] = custody.sha(resource_path)
        record["seconds"] = round(time.monotonic() - started, 3)
        record["log_sha256"] = custody.sha(log) if log.exists() else None
        custody.write_json(location / "process.json", record)
    return record
