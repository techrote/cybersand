#!/usr/bin/env python3
"""Measure actual native residency RSS in a fresh Godot process per worker count.

The 250ms phase dwell is sampling time, never credited as native throughput.
Logical native capacity, reservation, checkpoint bytes and measured process RSS
are separate fields. Allocator-retained RSS after release remains visible.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import queue
import subprocess
import sys
import threading
import time


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def process_memory(process: subprocess.Popen) -> dict:
    try:
        if sys.platform == "win32":
            class Counters(ctypes.Structure):
                _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong)] + [
                    (name, ctypes.c_size_t) for name in (
                        "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                        "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage",
                        "PagefileUsage", "PeakPagefileUsage", "PrivateUsage")]
            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            psapi = ctypes.WinDLL("psapi", use_last_error=True)
            psapi.GetProcessMemoryInfo.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ulong]
            if not psapi.GetProcessMemoryInfo(int(process._handle), ctypes.byref(counters), counters.cb):
                return {}
            return {"rss_bytes": counters.WorkingSetSize, "peak_rss_bytes": counters.PeakWorkingSetSize,
                    "private_bytes": counters.PrivateUsage}
        if sys.platform.startswith("linux"):
            values = {}
            for line in Path(f"/proc/{process.pid}/status").read_text().splitlines():
                key, _, value = line.partition(":")
                if key in ("VmRSS", "VmHWM", "VmSize"):
                    values[{"VmRSS": "rss_bytes", "VmHWM": "peak_rss_bytes", "VmSize": "virtual_bytes"}[key]] = int(value.split()[0]) * 1024
                elif key == "Threads":
                    values["process_threads"] = int(value)
            fields = Path(f"/proc/{process.pid}/stat").read_text().rsplit(")", 1)[1].split()
            values["process_cpu_seconds"] = (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")
            return values
    except (FileNotFoundError, ProcessLookupError, OSError, ValueError, IndexError):
        return {}
    return {}


def run_one(args: argparse.Namespace, workers: int) -> dict:
    prefix = args.output / f"native-memory-w{workers}"
    script = args.repo / "godot/tests/test_persistent_area_residency_memory.gd"
    sources = [script, args.repo / "godot/tests/fixtures/persistent_area_native_fixture.gd",
               args.repo / "godot/scripts/microscenario_contract.gd"]
    hashes = {path.relative_to(args.repo).as_posix(): digest(path) for path in sources}
    native_sha, godot_sha, harness_sha = digest(args.native), digest(args.godot), digest(Path(__file__))
    command = [str(args.godot), "--headless", "--path", str(args.repo / "godot"), "--script",
               "res://tests/test_persistent_area_residency_memory.gd", "--", f"--residency-memory-workers={workers}"]
    started = time.monotonic()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    lines: queue.Queue[str | None] = queue.Queue()

    def consume() -> None:
        assert process.stdout is not None
        for line in process.stdout:
            lines.put(line)
        lines.put(None)

    reader = threading.Thread(target=consume, daemon=True)
    reader.start()
    phases, samples, log = [], [], []
    current_phase, completed, eof, timed_out = "process_start", None, False, False
    while not eof or process.poll() is None:
        now = time.monotonic()
        if now - started > args.timeout:
            timed_out = True
            process.kill()
        memory = process_memory(process)
        if memory:
            samples.append({"elapsed_seconds": now - started, "phase": current_phase, **memory})
        try:
            while True:
                line = lines.get_nowait()
                if line is None:
                    eof = True
                    break
                log.append(line)
                if line.startswith("GEN006_NATIVE_MEMORY_PHASE "):
                    event = json.loads(line.partition(" ")[2])
                    event["observed_elapsed_seconds"] = time.monotonic() - started
                    event["process_memory"] = process_memory(process)
                    phases.append(event)
                    current_phase = str(event["label"])
                elif line.startswith("GEN006_NATIVE_MEMORY_DONE "):
                    completed = json.loads(line.partition(" ")[2])
        except queue.Empty:
            pass
        if timed_out and process.poll() is not None:
            break
        time.sleep(0.02)
    code = process.wait(timeout=10)
    reader.join(timeout=5)
    prefix.with_suffix(".log").write_text("".join(log), encoding="utf-8")
    phase_stats = []
    for phase in phases:
        selected = [row for row in samples if row["phase"] == phase["label"]]
        rss = sorted(row["rss_bytes"] for row in selected if "rss_bytes" in row)
        phase_stats.append({"label": phase["label"], "samples": len(rss),
                            "rss_p50_bytes": rss[len(rss) // 2] if rss else None,
                            "rss_max_bytes": max(rss) if rss else None,
                            "native_owned_bytes": phase["native"].get("native_bytes", 0),
                            "native_reservation_bytes": sum(entry.get("native_reservation_bytes", 0)
                                                            for entry in phase["native"].get("entries", [])),
                            "warm_payload_bytes": phase["warm_payload_bytes"],
                            "extra_private_native_bytes": phase["extra_private_native_bytes"]})
    indexed = {phase["label"]: phase for phase in phase_stats}
    increments = {}
    for before, after in [("one_hot_world", "two_hot_worlds"), ("two_hot_worlds", "three_hot_worlds"),
                          ("three_hot_worlds", "three_hot_one_checkpoint"),
                          ("three_hot_one_checkpoint", "two_hot_one_warm"),
                          ("one_hot_world", "one_hot_buffers_released")]:
        if before in indexed and after in indexed:
            left, right = indexed[before]["rss_p50_bytes"], indexed[after]["rss_p50_bytes"]
            increments[before + " -> " + after] = right - left if left is not None and right is not None else None
    unchanged = all(digest(path) == hashes[path.relative_to(args.repo).as_posix()] for path in sources)
    binaries_unchanged = digest(args.native) == native_sha and digest(args.godot) == godot_sha
    harness_unchanged = digest(Path(__file__)) == harness_sha
    report = {"schema": 1, "command": command, "pid": process.pid, "exit_code": code,
              "timed_out": timed_out, "elapsed_seconds": time.monotonic() - started,
              "configured_workers": workers, "platform": platform.platform(),
              "godot_sha256": godot_sha, "native_sha256": native_sha, "binaries_unchanged": binaries_unchanged,
              "harness_sha256": harness_sha, "harness_unchanged": harness_unchanged,
              "source_inputs": hashes, "source_inputs_unchanged": unchanged,
              "completed": completed, "phases": phases, "phase_statistics": phase_stats,
              "rss_increments_bytes": increments, "samples": samples,
              "peak_sampled_rss_bytes": max((row.get("rss_bytes", 0) for row in samples), default=0),
              "sampling_dwell_is_not_simulation_work": True,
              "scope": "Native ownership fixture; process RSS includes Godot, libraries and allocator retention; no Main rendering/durability claim"}
    report["ok"] = bool(code == 0 and not timed_out and unchanged and binaries_unchanged and harness_unchanged
                        and completed and completed.get("ok")
                        and len(phases) == completed.get("phases") and samples)
    prefix.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return {key: report[key] for key in ("ok", "configured_workers", "exit_code", "elapsed_seconds",
                                       "peak_sampled_rss_bytes", "rss_increments_bytes", "native_sha256")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--native", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, nargs="+", choices=(1, 4), default=[1, 4])
    parser.add_argument("--timeout", type=int, default=240)
    args = parser.parse_args()
    args.repo, args.godot, args.output = args.repo.resolve(), args.godot.resolve(), args.output.resolve()
    if args.native is None:
        filename = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
        args.native = args.repo / "godot/addons/cybersand_native/bin" / filename
    args.output.mkdir(parents=True, exist_ok=True)
    reports = []
    for workers in args.workers:
        report = run_one(args, workers)
        reports.append(report)
        print(json.dumps(report), flush=True)
    return 0 if all(report["ok"] for report in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
