#!/usr/bin/env python3
"""INV-004 Windows Rapier space_step CPU/off-CPU discriminator.

Runs the frozen #449 workload without changing production source:
1. one unchanged #449 reproduction run;
2. three unprofiled and three GetThreadTimes-profiled repeats of the same
   60-frame warmup + 4x4s A-B-B-A workload;
3. one best-effort WPR/ETW GeneralProfile capture if Windows permits it.

The per-thread fallback deliberately classifies only the synchronous Godot main
thread. It can distinguish CPU-running occupancy from off-CPU wall time, but it
cannot distinguish blocking from scheduler descheduling.
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import threading
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "inv154-threadstate"
ENGINE_DIR = OUT / "engine"
ORIGINAL_FIXTURE = "res://tests/performance/test_main_rapier_bridge_split_windows.gd"
THREADSTATE_FIXTURE = "res://tests/performance/test_main_rapier_threadstate_windows.gd"
FROZEN_449 = "2e937ee37532b06d46fa49205ff2e51c1a9baa2e"
FROZEN_MAIN_BLOB = "791ef440efd6edb206c6f1be33989cb62e9213b2"
FROZEN_BRIDGE_BLOB = "87eea1f36b11375eb40be6a833433871000fbb2e"
GODOT_URL = "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_win64.exe.zip"
PROFILE_INTERVAL_SECONDS = 0.001
LONG_USEC = 40_000
MIN_LONG_EVENTS = 20

DIAGNOSTIC_PATHS = {
    ".github/workflows/inv154-rapier-threadstate-windows.yml",
    "godot/tests/performance/test_main_rapier_threadstate_windows.gd",
    "tools/performance/run_inv154_windows_threadstate.py",
}

def sh(*args: str, timeout: int = 60) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True, timeout=timeout).strip()

def run_cmd(args, *, timeout=120, cwd=ROOT, env=None):
    return subprocess.run(
        args, cwd=cwd, env=env, text=True, capture_output=True, timeout=timeout
    )

def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8")

def percentile(values, q):
    if not values:
        return None
    data = sorted(values)
    return data[int(round((len(data) - 1) * q))]

def distribution(values):
    if not values:
        return {"n": 0}
    return {
        "n": len(values),
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "max": max(values),
    }

def validate_source() -> dict:
    head = sh("git", "rev-parse", "HEAD")
    tree = sh("git", "rev-parse", "HEAD^{tree}")
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", FROZEN_449, head],
        cwd=ROOT,
    ).returncode == 0
    if not ancestor:
        raise RuntimeError("diagnostic head does not descend from frozen #449 head")

    changed = [
        p for p in sh("git", "diff", "--name-only", FROZEN_449, head).splitlines() if p
    ]
    unexpected = sorted(set(changed) - DIAGNOSTIC_PATHS)
    if unexpected:
        raise RuntimeError("unexpected delta beyond scoped diagnostics: " + repr(unexpected))

    main_blob = sh("git", "hash-object", "godot/scripts/main.gd")
    bridge_blob = sh("git", "hash-object", "godot/scripts/rapier_physics_bridge.gd")
    if main_blob != FROZEN_MAIN_BLOB:
        raise RuntimeError("production Main blob changed from #449 source")
    if bridge_blob != FROZEN_BRIDGE_BLOB:
        raise RuntimeError("Rapier bridge blob changed from #449 source")

    source = (ROOT / "godot/scripts/main.gd").read_text(encoding="utf-8")
    sample_path = ROOT / "godot/tests/performance/test_main_rapier_threadstate_windows.gd"
    sample = sample_path.read_text(encoding="utf-8")
    origparts = source.split("func _physics_process(_delta: float) -> void:\n", 1)
    if len(origparts) != 2:
        raise RuntimeError("Main physical dispatcher missing")
    expected = origparts[1].split("\nfunc workbench_source(", 1)[0].rstrip()
    fragments = sample.split("\tfunc _instrumented_dispatch(_delta: float) -> void:\n", 1)
    if len(fragments) != 2:
        raise RuntimeError("thread-state instrumented dispatcher missing")
    copied = fragments[1].split("\nfunc retain_physics(", 1)[0]
    lines = [line[1:] for line in copied.splitlines() if line.startswith("\t")][1:]
    clocks = re.compile(
        r'^\s*(?:'
        r'stage_started_usec = Time\.get_ticks_usec\(\)|'
        r'observe_wrapper\("(?:session_suspend|take_snapshot|session_advance|rapier_step|session_complete)", stage_started_usec\)|'
        r'rapier_step_begin_usec = stage_started_usec|'
        r'rapier_step_end_usec = Time\.get_ticks_usec\(\)'
        r')$'
    )
    restored = "\n".join(line for line in lines if not clocks.fullmatch(line)).rstrip()
    if restored != expected:
        raise RuntimeError("test-only dispatcher differs from frozen Main beyond clocks")

    required = (
        '"rapier_step_begin_usec":rapier_step_begin_usec',
        '"rapier_step_end_usec":rapier_step_end_usec',
        '"schema": "inv154-threadstate-v1"',
        'record_sync("warmup_start")',
    )
    for token in required:
        if token not in sample:
            raise RuntimeError("missing thread-state fixture token: " + token)

    return {
        "head": head,
        "tree": tree,
        "frozen_449_parent": FROZEN_449,
        "frozen_449_is_ancestor": True,
        "changed_paths_from_449": changed,
        "main_blob": main_blob,
        "bridge_blob": bridge_blob,
        "threadstate_fixture_sha256": hashlib.sha256(sample_path.read_bytes()).hexdigest(),
        "original_fixture_sha256": hashlib.sha256(
            (ROOT / "godot/tests/performance/test_main_rapier_bridge_split_windows.gd").read_bytes()
        ).hexdigest(),
        "restored_dispatch_sha256": hashlib.sha256(restored.encode()).hexdigest(),
        "source_equivalent_after_stripping_test_clocks": True,
    }

def runtime_identity() -> dict:
    sys.path.insert(0, str(ROOT / "tools/ci"))
    import run_windows_godot_regressions as runtime
    with runtime.metadata_budget():
        identity = runtime.verify_retained_runtime(ROOT)
    return {"identity": identity, "godot_sha512": runtime.GODOT_SHA512}

def host_identity() -> dict:
    commands = {
        "video_controllers": "Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,VideoProcessor,PNPDeviceID | ConvertTo-Json -Depth 5",
        "processor": "Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | ConvertTo-Json -Depth 4",
        "os": "Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber | ConvertTo-Json -Depth 4",
        "computer": "Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,NumberOfProcessors,NumberOfLogicalProcessors | ConvertTo-Json -Depth 4",
    }
    result = {}
    for name, command in commands.items():
        proc = run_cmd(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", command],
            timeout=45,
        )
        result[name] = {
            "exit": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
        if proc.returncode:
            raise RuntimeError("host identity query failed: " + name)
    return result

def prepare_engine(runtime: dict) -> Path:
    ENGINE_DIR.mkdir(parents=True, exist_ok=True)
    archive = OUT / "official-godot.zip"
    urllib.request.urlretrieve(GODOT_URL, archive)
    digest = hashlib.sha512(archive.read_bytes()).hexdigest()
    if digest != runtime["godot_sha512"]:
        raise RuntimeError("official Godot SHA512 pin changed")
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise RuntimeError("Godot archive CRC failure")
        for member in (
            "Godot_v4.7-stable_win64.exe",
            "Godot_v4.7-stable_win64_console.exe",
        ):
            if z.namelist().count(member) != 1:
                raise RuntimeError("Godot executable missing: " + member)
            z.extract(member, ENGINE_DIR)
    archive.unlink()
    write_json(
        OUT / "engine-identity.json",
        {"version": "4.7-stable", "url": GODOT_URL, "archive_sha512": digest},
    )
    return ENGINE_DIR / "Godot_v4.7-stable_win64_console.exe"

def import_project(engine: Path, source_revision: str) -> None:
    env = os.environ.copy()
    env.update(
        {
            "GODOT_SILENCE_ROOT_WARNING": "1",
            "CYBERSAND_SOURCE_REVISION": source_revision,
        }
    )
    proc = run_cmd(
        [str(engine), "--headless", "--editor", "--path", "godot", "--import"],
        timeout=180,
        env=env,
    )
    write_text(OUT / "import.log", proc.stdout + "\n" + proc.stderr)
    if proc.returncode:
        raise RuntimeError("project import failed: " + str(proc.returncode))

if os.name == "nt":
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    TH32CS_SNAPTHREAD = 0x00000004
    THREAD_QUERY_LIMITED_INFORMATION = 0x0800
    INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value

    class THREADENTRY32(ctypes.Structure):
        _fields_ = [
            ("dwSize", wintypes.DWORD),
            ("cntUsage", wintypes.DWORD),
            ("th32ThreadID", wintypes.DWORD),
            ("th32OwnerProcessID", wintypes.DWORD),
            ("tpBasePri", wintypes.LONG),
            ("tpDeltaPri", wintypes.LONG),
            ("dwFlags", wintypes.DWORD),
        ]

    kernel32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel32.Thread32First.argtypes = [wintypes.HANDLE, ctypes.POINTER(THREADENTRY32)]
    kernel32.Thread32First.restype = wintypes.BOOL
    kernel32.Thread32Next.argtypes = [wintypes.HANDLE, ctypes.POINTER(THREADENTRY32)]
    kernel32.Thread32Next.restype = wintypes.BOOL
    kernel32.OpenThread.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenThread.restype = wintypes.HANDLE
    kernel32.GetThreadTimes.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
    ]
    kernel32.GetThreadTimes.restype = wintypes.BOOL
    kernel32.QueryThreadCycleTime.argtypes = [wintypes.HANDLE, ctypes.POINTER(ctypes.c_ulonglong)]
    kernel32.QueryThreadCycleTime.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    _GetThreadDescription = getattr(kernel32, "GetThreadDescription", None)
    if _GetThreadDescription is not None:
        _GetThreadDescription.argtypes = [wintypes.HANDLE, ctypes.POINTER(ctypes.c_wchar_p)]
        _GetThreadDescription.restype = ctypes.c_long

def ft_to_int(ft: wintypes.FILETIME) -> int:
    return (int(ft.dwHighDateTime) << 32) | int(ft.dwLowDateTime)

def enumerate_thread_ids(pid: int) -> list[int]:
    if os.name != "nt":
        return []
    snap = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
    if snap == INVALID_HANDLE_VALUE:
        return []
    entry = THREADENTRY32()
    entry.dwSize = ctypes.sizeof(THREADENTRY32)
    ids = []
    try:
        ok = kernel32.Thread32First(snap, ctypes.byref(entry))
        while ok:
            if int(entry.th32OwnerProcessID) == pid:
                ids.append(int(entry.th32ThreadID))
            ok = kernel32.Thread32Next(snap, ctypes.byref(entry))
    finally:
        kernel32.CloseHandle(snap)
    return ids

def open_thread(tid: int):
    if os.name != "nt":
        return None
    handle = kernel32.OpenThread(THREAD_QUERY_LIMITED_INFORMATION, False, tid)
    return handle if handle else None

def thread_times(handle) -> dict | None:
    creation = wintypes.FILETIME()
    exit_ft = wintypes.FILETIME()
    kernel = wintypes.FILETIME()
    user = wintypes.FILETIME()
    if not kernel32.GetThreadTimes(
        handle,
        ctypes.byref(creation),
        ctypes.byref(exit_ft),
        ctypes.byref(kernel),
        ctypes.byref(user),
    ):
        return None
    cycles = ctypes.c_ulonglong()
    cycle_ok = bool(kernel32.QueryThreadCycleTime(handle, ctypes.byref(cycles)))
    return {
        "creation_100ns": ft_to_int(creation),
        "kernel_100ns": ft_to_int(kernel),
        "user_100ns": ft_to_int(user),
        "cpu_100ns": ft_to_int(kernel) + ft_to_int(user),
        "cycles": int(cycles.value) if cycle_ok else None,
    }

def thread_description(handle) -> str:
    if os.name != "nt" or _GetThreadDescription is None:
        return ""
    value = ctypes.c_wchar_p()
    hr = _GetThreadDescription(handle, ctypes.byref(value))
    if hr != 0 or not value.value:
        return ""
    text = value.value
    try:
        kernel32.LocalFree(value)
    except Exception:
        pass
    return text

def thread_snapshot(pid: int) -> dict[int, dict]:
    data = {}
    for tid in enumerate_thread_ids(pid):
        handle = open_thread(tid)
        if not handle:
            continue
        try:
            times = thread_times(handle)
            if times:
                times["description"] = thread_description(handle)
                data[tid] = times
        finally:
            kernel32.CloseHandle(handle)
    return data

class MainThreadSampler:
    def __init__(self, pid: int, output_dir: Path):
        self.pid = pid
        self.output_dir = output_dir
        self.stop_event = threading.Event()
        self.thread = None
        self.main_tid = None
        self.samples = []
        self.participation = {}
        self.errors = []
        self.sample_gaps_us = []

    def _merge_participation(self, snapshot: dict[int, dict], unix_ns: int):
        for tid, row in snapshot.items():
            key = str(tid)
            rec = self.participation.setdefault(
                key,
                {
                    "tid": tid,
                    "description": row.get("description", ""),
                    "creation_100ns": row["creation_100ns"],
                    "first_cpu_100ns": row["cpu_100ns"],
                    "last_cpu_100ns": row["cpu_100ns"],
                    "first_unix_ns": unix_ns,
                    "last_unix_ns": unix_ns,
                },
            )
            rec["last_cpu_100ns"] = row["cpu_100ns"]
            rec["last_unix_ns"] = unix_ns
            if not rec.get("description") and row.get("description"):
                rec["description"] = row["description"]

    def _run(self):
        try:
            deadline = time.monotonic() + 10.0
            snap = {}
            while time.monotonic() < deadline and not snap and not self.stop_event.is_set():
                snap = thread_snapshot(self.pid)
                if not snap:
                    time.sleep(0.005)
            if not snap:
                self.errors.append("no process threads became queryable")
                return
            self.main_tid = min(snap, key=lambda tid: snap[tid]["creation_100ns"])
            self._merge_participation(snap, time.time_ns())
            handle = open_thread(self.main_tid)
            if not handle:
                self.errors.append("failed to open inferred main thread")
                return
            try:
                last_perf = None
                next_full = time.monotonic()
                while not self.stop_event.is_set():
                    perf_ns = time.perf_counter_ns()
                    unix_ns = time.time_ns()
                    row = thread_times(handle)
                    if row is None:
                        self.errors.append("GetThreadTimes failed during sampling")
                        break
                    sample = {
                        "perf_ns": perf_ns,
                        "unix_ns": unix_ns,
                        "cpu_100ns": row["cpu_100ns"],
                        "cycles": row["cycles"],
                        "tid": self.main_tid,
                    }
                    if last_perf is not None:
                        self.sample_gaps_us.append((perf_ns - last_perf) / 1000.0)
                    last_perf = perf_ns
                    self.samples.append(sample)
                    now = time.monotonic()
                    if now >= next_full:
                        self._merge_participation(thread_snapshot(self.pid), unix_ns)
                        next_full = now + 0.25
                    time.sleep(PROFILE_INTERVAL_SECONDS)
            finally:
                kernel32.CloseHandle(handle)
                self._merge_participation(thread_snapshot(self.pid), time.time_ns())
        except Exception as exc:
            self.errors.append(repr(exc))

    def start(self):
        self.thread = threading.Thread(target=self._run, name="inv154-thread-sampler", daemon=True)
        self.thread.start()

    def stop(self):
        self.stop_event.set()
        if self.thread is not None:
            self.thread.join(timeout=5)
        participation = []
        for rec in self.participation.values():
            item = dict(rec)
            item["observed_cpu_usec"] = (
                item["last_cpu_100ns"] - item["first_cpu_100ns"]
            ) / 10.0
            participation.append(item)
        participation.sort(key=lambda x: x["observed_cpu_usec"], reverse=True)
        meta = {
            "pid": self.pid,
            "main_tid": self.main_tid,
            "sample_count": len(self.samples),
            "errors": self.errors,
            "interval_target_usec": PROFILE_INTERVAL_SECONDS * 1_000_000.0,
            "sample_gap_usec": distribution(self.sample_gaps_us),
            "thread_participation": participation,
        }
        write_json(self.output_dir / "thread-sampler-meta.json", meta)
        with (self.output_dir / "thread-samples.jsonl").open("w", encoding="utf-8") as fh:
            for row in self.samples:
                fh.write(json.dumps(row, separators=(",", ":")) + "\n")
        return meta

def parse_result_line(log: str, prefix: str) -> dict:
    matches = [
        line.split(prefix, 1)[1]
        for line in log.splitlines()
        if line.startswith(prefix)
    ]
    if len(matches) != 1:
        raise RuntimeError("expected exactly one result line " + prefix + ", got " + str(len(matches)))
    return json.loads(matches[0])

def run_fixture(
    engine: Path,
    fixture: str,
    label: str,
    *,
    sampler_enabled: bool,
    source_revision: str,
) -> dict:
    trial_dir = OUT / label
    trial_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(
        {
            "GODOT_SILENCE_ROOT_WARNING": "1",
            "PYTHONUTF8": "1",
            "CYBERSAND_PHASE_OUTPUT": str(trial_dir),
            "CYBERSAND_SOURCE_REVISION": source_revision,
        }
    )
    argv = [
        str(engine),
        "--rendering-driver",
        "opengl3_angle",
        "--path",
        "godot",
        "--script",
        fixture,
    ]
    write_json(trial_dir / "command.json", argv)
    log_path = trial_dir / "godot.log"
    started_unix_ns = time.time_ns()
    proc = subprocess.Popen(
        argv,
        cwd=ROOT,
        env=env,
        stdout=log_path.open("w", encoding="utf-8"),
        stderr=subprocess.STDOUT,
        text=True,
    )
    sampler = MainThreadSampler(proc.pid, trial_dir) if sampler_enabled else None
    if sampler:
        sampler.start()
    timed_out = False
    try:
        exit_code = proc.wait(timeout=800)
    except subprocess.TimeoutExpired:
        timed_out = True
        proc.kill()
        exit_code = proc.wait(timeout=30)
    sampler_meta = sampler.stop() if sampler else None
    ended_unix_ns = time.time_ns()
    log = log_path.read_text(encoding="utf-8", errors="replace")
    write_json(
        trial_dir / "process-exit.json",
        {
            "pid": proc.pid,
            "exit_code": exit_code,
            "timed_out": timed_out,
            "started_unix_ns": started_unix_ns,
            "ended_unix_ns": ended_unix_ns,
            "sampler_enabled": sampler_enabled,
        },
    )
    if timed_out or exit_code != 0:
        raise RuntimeError(label + " Godot exit " + str(exit_code) + ", timed_out=" + str(timed_out))

    if fixture == ORIGINAL_FIXTURE:
        summary = parse_result_line(log, "INV154_BRIDGE_SPLIT ")
        raw_path = trial_dir / "physics-bridge-split.json"
        expected_schema = "inv154-bridge-split-v1"
    else:
        summary = parse_result_line(log, "INV154_THREADSTATE ")
        raw_path = trial_dir / "threadstate-fixture.json"
        expected_schema = "inv154-threadstate-v1"
    if summary.get("schema") != expected_schema:
        raise RuntimeError(label + " wrong fixture schema")
    if summary.get("platform") != "Windows" or summary.get("display_server") == "headless":
        raise RuntimeError(label + " was not actual graphical Windows")
    if summary.get("failures") != 0 or not summary.get("joined_worker") or summary.get("overflow"):
        raise RuntimeError(label + " lifecycle/assertion gate failed")
    raw = json.loads(raw_path.read_text(encoding="utf-8"))
    return {
        "label": label,
        "fixture": fixture,
        "process_pid": proc.pid,
        "sampler_enabled": sampler_enabled,
        "sampler_meta": sampler_meta,
        "summary": summary,
        "raw_path": str(raw_path.relative_to(ROOT)),
        "raw": raw,
    }

def timed_long_rows(raw: dict) -> list[dict]:
    rows = []
    for row in raw["physics_rows"]:
        if row.get("phase") not in ("timed_a", "timed_b"):
            continue
        if int(row.get("bridge_step_delta", 0)) != 1:
            continue
        if int(row.get("bridge_step_usec", -1)) >= LONG_USEC:
            rows.append(row)
    return rows

def summarize_trial(trial: dict) -> dict:
    rows = [
        row for row in trial["raw"]["physics_rows"]
        if row.get("phase") in ("timed_a", "timed_b")
    ]
    long_rows = timed_long_rows(trial["raw"])
    callback_ms = [int(row["duration_usec"]) / 1000.0 for row in rows]
    step_ms = [
        int(row["bridge_step_usec"]) / 1000.0
        for row in rows
        if int(row.get("bridge_step_usec", -1)) >= 0
    ]
    long_callback_usec = sum(int(row["duration_usec"]) for row in long_rows)
    long_step_usec = sum(int(row["bridge_step_usec"]) for row in long_rows)
    return {
        "label": trial["label"],
        "sampler_enabled": trial["sampler_enabled"],
        "physics_callbacks_timed": len(rows),
        "long_space_step_events": len(long_rows),
        "timed_callback_ms": distribution(callback_ms),
        "space_step_ms": distribution(step_ms),
        "long_callback_usec": long_callback_usec,
        "long_space_step_usec": long_step_usec,
        "space_step_over_long_callback_fraction": (
            long_step_usec / long_callback_usec if long_callback_usec else None
        ),
        "native_ticks_per_second": {
            phase: trial["summary"][phase].get("native_ticks_per_second")
            for phase in ("baseline_a", "timed_a", "timed_b", "baseline_b")
        },
        "rapier_steps_per_second": {
            phase: trial["summary"][phase].get("rapier_steps_per_second")
            for phase in ("baseline_a", "timed_a", "timed_b", "baseline_b")
        },
        "process_pid_reported": trial["summary"].get("process_pid"),
    }

def interpolate_cpu(samples: list[dict], target_unix_ns: int):
    if len(samples) < 2:
        return None
    lo = 0
    hi = len(samples) - 1
    if target_unix_ns < samples[0]["unix_ns"] or target_unix_ns > samples[-1]["unix_ns"]:
        return None
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if samples[mid]["unix_ns"] <= target_unix_ns:
            lo = mid
        else:
            hi = mid
    a = samples[lo]
    b = samples[hi]
    span = b["unix_ns"] - a["unix_ns"]
    if span <= 0:
        return None
    frac = (target_unix_ns - a["unix_ns"]) / span
    cpu = a["cpu_100ns"] + frac * (b["cpu_100ns"] - a["cpu_100ns"])
    cycles = None
    if a.get("cycles") is not None and b.get("cycles") is not None:
        cycles = a["cycles"] + frac * (b["cycles"] - a["cycles"])
    return {
        "cpu_100ns": cpu,
        "cycles": cycles,
        "bracket_gap_usec": span / 1000.0,
    }

def align_trial(trial: dict) -> dict:
    trial_dir = ROOT / Path(trial["raw_path"]).parent
    sample_path = trial_dir / "thread-samples.jsonl"
    samples = [
        json.loads(line)
        for line in sample_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not samples:
        raise RuntimeError(trial["label"] + " has no thread samples")
    samples.sort(key=lambda row: row["unix_ns"])

    result = trial["summary"]
    sync = result.get("sync_points") or []
    if len(sync) < 4:
        raise RuntimeError(trial["label"] + " has insufficient timing sync points")
    offsets = [int(p["unix_usec"]) - int(p["ticks_usec"]) for p in sync]
    offset_usec = int(round(statistics.median(offsets)))
    offset_spread_usec = max(offsets) - min(offsets)

    if int(result.get("process_pid", -1)) != int(trial["process_pid"]):
        raise RuntimeError(
            trial["label"] + " Godot reported PID does not match sampled process"
        )

    events = []
    for row in timed_long_rows(trial["raw"]):
        begin = int(row.get("rapier_step_begin_usec", -1))
        end = int(row.get("rapier_step_end_usec", -1))
        if begin < 0 or end <= begin:
            continue
        internal = int(row["bridge_step_usec"])
        boundary = end - begin
        boundary_delta = boundary - internal
        start_unix_ns = (begin + offset_usec) * 1000
        end_unix_ns = (end + offset_usec) * 1000
        a = interpolate_cpu(samples, start_unix_ns)
        b = interpolate_cpu(samples, end_unix_ns)
        if a is None or b is None:
            continue
        cpu_usec = (b["cpu_100ns"] - a["cpu_100ns"]) / 10.0
        wall_usec = end - begin
        occupancy = max(0.0, min(1.5, cpu_usec / wall_usec))
        events.append(
            {
                "phase": row["phase"],
                "physics_frames": row.get("physics_frames"),
                "wall_usec": wall_usec,
                "bridge_internal_usec": internal,
                "boundary_minus_internal_usec": boundary_delta,
                "main_thread_cpu_usec": cpu_usec,
                "cpu_running_occupancy": occupancy,
                "off_cpu_fraction": max(0.0, 1.0 - occupancy),
                "start_sample_gap_usec": a["bracket_gap_usec"],
                "end_sample_gap_usec": b["bracket_gap_usec"],
            }
        )

    return {
        "label": trial["label"],
        "sync_offset_usec_median": offset_usec,
        "sync_offset_spread_usec": offset_spread_usec,
        "events": events,
        "event_count": len(events),
        "cpu_occupancy": distribution([e["cpu_running_occupancy"] for e in events]),
        "off_cpu_fraction": distribution([e["off_cpu_fraction"] for e in events]),
        "cpu_ge_80_count": sum(e["cpu_running_occupancy"] >= 0.80 for e in events),
        "offcpu_ge_60_count": sum(e["off_cpu_fraction"] >= 0.60 for e in events),
        "max_sample_bracket_gap_usec": max(
            [
                max(e["start_sample_gap_usec"], e["end_sample_gap_usec"])
                for e in events
            ],
            default=None,
        ),
    }

def classify(aligned: list[dict], profiler_perturbation_excessive: bool) -> dict:
    events = [event for trial in aligned for event in trial["events"]]
    n = len(events)
    cpu_count = sum(e["cpu_running_occupancy"] >= 0.80 for e in events)
    off_count = sum(e["off_cpu_fraction"] >= 0.60 for e in events)
    cpu_fraction = cpu_count / n if n else 0.0
    off_fraction = off_count / n if n else 0.0
    max_gap = max(
        [
            max(e["start_sample_gap_usec"], e["end_sample_gap_usec"])
            for e in events
        ],
        default=float("inf"),
    )
    alignment_ok = (
        n >= MIN_LONG_EVENTS
        and all(t["sync_offset_spread_usec"] <= 5000 for t in aligned)
        and max_gap <= 5000
    )
    if profiler_perturbation_excessive or not alignment_ok:
        verdict = "INCONCLUSIVE"
    elif cpu_fraction >= 0.80:
        verdict = "CPU_DOMINATED"
    elif off_fraction >= 0.80:
        verdict = "OFF_CPU_DOMINATED"
    else:
        verdict = "INCONCLUSIVE"
    return {
        "classification": verdict,
        "long_events": n,
        "cpu_running_ge_80_events": cpu_count,
        "cpu_running_ge_80_fraction": cpu_fraction,
        "off_cpu_ge_60_events": off_count,
        "off_cpu_ge_60_fraction": off_fraction,
        "alignment_ok": alignment_ok,
        "max_sample_bracket_gap_usec": max_gap if math.isfinite(max_gap) else None,
        "profiler_perturbation_excessive": profiler_perturbation_excessive,
        "state_detail": (
            "Per-thread CPU-time fallback only; blocked versus ready/descheduled "
            "requires ETW scheduler-state analysis."
        ),
    }

def perturbation(off_summaries: list[dict], on_summaries: list[dict]) -> dict:
    off_p50 = [x["timed_callback_ms"]["p50"] for x in off_summaries]
    on_p50 = [x["timed_callback_ms"]["p50"] for x in on_summaries]
    off_rates = [
        x["long_space_step_events"] / x["physics_callbacks_timed"]
        for x in off_summaries
    ]
    on_rates = [
        x["long_space_step_events"] / x["physics_callbacks_timed"]
        for x in on_summaries
    ]
    p50_off = statistics.median(off_p50)
    p50_on = statistics.median(on_p50)
    rate_off = statistics.median(off_rates)
    rate_on = statistics.median(on_rates)
    p50_ratio = p50_on / p50_off if p50_off else None
    rate_ratio = rate_on / rate_off if rate_off else None
    excessive = (
        p50_ratio is None
        or rate_ratio is None
        or p50_ratio > 1.25
        or p50_ratio < 0.80
        or rate_ratio > 1.50
        or rate_ratio < (1 / 1.50)
    )
    return {
        "unprofiled_timed_callback_p50_ms_median": p50_off,
        "profiled_timed_callback_p50_ms_median": p50_on,
        "profiled_over_unprofiled_p50_ratio": p50_ratio,
        "unprofiled_long_event_rate_median": rate_off,
        "profiled_long_event_rate_median": rate_on,
        "profiled_over_unprofiled_long_event_rate_ratio": rate_ratio,
        "excessive": excessive,
        "guard": (
            "Marked excessive if median callback p50 shifts outside 0.80-1.25x "
            "or long-event rate outside 0.667-1.50x."
        ),
    }

def executable(name: str) -> str | None:
    return shutil.which(name)

def etw_capability() -> dict:
    tools = {
        name: executable(name)
        for name in ("wpr", "wpaexporter", "xperf", "wpa", "tracerpt")
    }
    result = {"tools": tools, "start_attempted": False, "start_exit": None}
    if tools["wpr"]:
        detail = run_cmd(["wpr", "-profiledetails", "GeneralProfile"], timeout=60)
        result["general_profile_details_exit"] = detail.returncode
        result["general_profile_details"] = detail.stdout + "\n" + detail.stderr
    return result

def run_etw_trial(engine: Path, source_revision: str, capability: dict) -> dict:
    if not capability["tools"].get("wpr"):
        capability["unavailable_reason"] = "wpr.exe not present"
        return {"captured": False}
    cancel = run_cmd(["wpr", "-cancel"], timeout=30)
    capability["pre_cancel_exit"] = cancel.returncode
    start = run_cmd(["wpr", "-start", "GeneralProfile", "-filemode"], timeout=60)
    capability["start_attempted"] = True
    capability["start_exit"] = start.returncode
    capability["start_stdout"] = start.stdout
    capability["start_stderr"] = start.stderr
    if start.returncode != 0:
        capability["unavailable_reason"] = "WPR GeneralProfile start failed"
        return {"captured": False}
    trial = None
    stop = None
    try:
        trial = run_fixture(
            engine,
            THREADSTATE_FIXTURE,
            "etw1",
            sampler_enabled=True,
            source_revision=source_revision,
        )
    finally:
        trace = OUT / "etw1" / "rapier-space-step.etl"
        stop = run_cmd(["wpr", "-stop", str(trace)], timeout=180)
        capability["stop_exit"] = stop.returncode
        capability["stop_stdout"] = stop.stdout
        capability["stop_stderr"] = stop.stderr
        capability["trace_exists"] = trace.exists()
        capability["trace_size"] = trace.stat().st_size if trace.exists() else 0
        if stop.returncode != 0:
            run_cmd(["wpr", "-cancel"], timeout=30)
    return {
        "captured": bool(capability.get("trace_exists")),
        "trial_summary": summarize_trial(trial) if trial else None,
        "note": (
            "Raw ETL captured with GeneralProfile. Automatic WPA table export and "
            "symbol resolution are only claimed if a supported exporter/profile is available."
        ),
    }

def main() -> int:
    if os.name != "nt":
        raise RuntimeError("this runner requires Windows")
    OUT.mkdir(parents=True, exist_ok=True)
    provider = run_cmd([sys.executable, "tools/ci/check_ci_provider_policy.py"], timeout=60)
    write_text(OUT / "provider-policy.log", provider.stdout + "\n" + provider.stderr)
    if provider.returncode:
        raise RuntimeError("CI provider policy check failed")
    diff = run_cmd(["git", "diff", "--check"], timeout=60)
    write_text(OUT / "git-diff-check.log", diff.stdout + "\n" + diff.stderr)
    if diff.returncode:
        raise RuntimeError("git diff --check failed")

    source = validate_source()
    runtime = runtime_identity()
    write_json(OUT / "source-and-runtime.json", {"source": source, "runtime": runtime})
    write_json(OUT / "host-identity.json", host_identity())
    engine = prepare_engine(runtime)
    import_project(engine, source["head"])

    reproduction = run_fixture(
        engine,
        ORIGINAL_FIXTURE,
        "reproduction",
        sampler_enabled=False,
        source_revision=source["head"],
    )
    reproduction_summary = summarize_trial(reproduction)
    reproduction_ok = (
        reproduction_summary["long_space_step_events"] >= MIN_LONG_EVENTS
        and reproduction_summary["space_step_over_long_callback_fraction"] is not None
        and reproduction_summary["space_step_over_long_callback_fraction"] >= 0.80
    )
    write_json(
        OUT / "reproduction-summary.json",
        {**reproduction_summary, "long_tail_reproduced": reproduction_ok},
    )
    if not reproduction_ok:
        raise RuntimeError("previous #449 long-tail behavior did not reproduce")

    order = [
        ("off1", False),
        ("on1", True),
        ("on2", True),
        ("off2", False),
        ("off3", False),
        ("on3", True),
    ]
    trials = []
    trial_summaries = []
    aligned = []
    for label, enabled in order:
        trial = run_fixture(
            engine,
            THREADSTATE_FIXTURE,
            label,
            sampler_enabled=enabled,
            source_revision=source["head"],
        )
        trials.append(trial)
        summary = summarize_trial(trial)
        trial_summaries.append(summary)
        write_json(OUT / label / "trial-summary.json", summary)
        if enabled:
            alignment = align_trial(trial)
            aligned.append(alignment)
            write_json(OUT / label / "cpu-alignment.json", alignment)

    off_summaries = [x for x in trial_summaries if not x["sampler_enabled"]]
    on_summaries = [x for x in trial_summaries if x["sampler_enabled"]]
    perturb = perturbation(off_summaries, on_summaries)
    verdict = classify(aligned, perturb["excessive"])

    capability = etw_capability()
    etw_result = run_etw_trial(engine, source["head"], capability)
    write_json(OUT / "etw-capability.json", capability)
    write_json(OUT / "etw-result.json", etw_result)

    final = {
        "schema": "inv154-rapier-threadstate-result-v1",
        "source": source,
        "reproduction": {**reproduction_summary, "long_tail_reproduced": reproduction_ok},
        "trial_order": order,
        "trial_summaries": trial_summaries,
        "profiler_perturbation": perturb,
        "aligned_profiled_trials": aligned,
        "classification": verdict,
        "etw": etw_result,
        "etw_capability": capability,
        "limitations": [
            "GetThreadTimes fallback measures the inferred earliest-created Godot main thread.",
            "Fallback cannot distinguish blocking from ready-but-descheduled time.",
            "Raw ETW can supply scheduler-state evidence only if captured and later resolved/exported.",
            "Microsoft Basic Render Driver is a hosted software-renderer cohort, not discrete-GPU qualification.",
        ],
    }
    write_json(OUT / "final-classification.json", final)
    print("INV154_THREADSTATE_CLASSIFICATION " + json.dumps(verdict, sort_keys=True))
    print("INV154_REPRODUCTION " + json.dumps(final["reproduction"], sort_keys=True))
    print("INV154_PERTURBATION " + json.dumps(perturb, sort_keys=True))
    print("INV154_ETW " + json.dumps(etw_result, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
