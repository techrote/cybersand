"""Bounded external resource observations for actual Workbench subprocesses.

These samples explain a failed or pressured run; they do not establish why the
kernel or an external supervisor sent a signal. No Godot frame work is added.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import time


def memory_fields(text: str, names: tuple[str, ...]) -> dict[str, int]:
    result = {}
    for name in names:
        match = re.search(r"^" + re.escape(name) + r":\s*(\d+)\s+kB\s*$", text, re.M)
        if match:
            result[name] = int(match[1]) * 1024
    return result


class ProcessResources:
    """One sample per wall second, retaining peaks after a child becomes zombie."""

    def __init__(self, path: Path, observer, *, proc_root: Path = Path("/proc"), clock=time.monotonic):
        self.path, self.observer, self.proc_root, self.clock = path, observer, proc_root, clock
        self.started = clock()
        self.previous_sample = float("-inf")
        self.samples = 0
        self.peak_rss = None
        self.minimum_available = None
        self.last = {"available": False, "scope": "direct_process_only"}

    def observe(self, pid: int) -> dict:
        now = self.clock()
        if now - self.previous_sample < 1.0:
            return self.last
        self.previous_sample = now
        value = dict(self.observer(pid))
        row = {"elapsed_seconds": now - self.started, "pid": pid,
               "scope": "direct_process_only", "available": value.get("available", False)}
        # Respect the shared observer's namespace refusal. An unrelated host
        # process with the same numeric PID is never a valid fallback witness.
        if value.get("reason") == "proc_pid_namespace_mismatch":
            row["reason"] = value["reason"]
        elif value.get("available"):
            try:
                status = (self.proc_root / str(pid) / "status").read_text()
                memory = memory_fields(status, ("VmRSS", "VmHWM"))
                row.update(rss_bytes=memory.get("VmRSS"), peak_rss_bytes=memory.get("VmHWM"))
                state = re.search(r"^State:\s*(.+)$", status, re.M)
                row["state"] = state[1] if state else "unknown"
            except OSError:
                row["process_memory_reason"] = "process_status_unavailable"
        row["cpu_seconds"] = value.get("cpu_seconds")
        candidates = [n for n in (self.peak_rss, value.get("peak_rss_bytes"),
                                  row.get("peak_rss_bytes"), row.get("rss_bytes")) if type(n) is int]
        self.peak_rss = max(candidates) if candidates else None
        try:
            host = memory_fields((self.proc_root / "meminfo").read_text(), ("MemAvailable", "MemTotal"))
            row["host_mem_available_bytes"] = host.get("MemAvailable")
            row["host_mem_total_bytes"] = host.get("MemTotal")
            available = host.get("MemAvailable")
            if available is not None:
                self.minimum_available = available if self.minimum_available is None else min(self.minimum_available, available)
        except OSError:
            row["host_memory_reason"] = "proc_meminfo_unavailable"
        self.samples += 1
        with self.path.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(row, sort_keys=True, allow_nan=False) + "\n")
        self.last = {**value, "peak_rss_bytes": self.peak_rss,
                     "rss_bytes": row.get("rss_bytes"), "minimum_host_mem_available_bytes": self.minimum_available,
                     "resource_sample_count": self.samples, "resource_samples": self.path.name,
                     "resource_sampling_scope": "external direct child and host /proc observations at most once per wall second; no inferred termination cause"}
        return self.last

    def finish(self, record: dict) -> dict:
        row = {"kind": "termination", "elapsed_seconds": self.clock() - self.started,
               "returncode": record.get("returncode"), "status": record.get("status"),
               "timeout_kind": record.get("timeout_kind"), "samples": self.samples,
               "peak_rss_bytes": self.peak_rss, "minimum_host_mem_available_bytes": self.minimum_available,
               "termination_cause": "not established by these observations"}
        with self.path.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(row, sort_keys=True, allow_nan=False) + "\n")
        return row


def run_observed_case(runner, godot: str, case, output: Path, role: str, *, env=None):
    """Keep the shared runner's existing watchdog and evidence readers intact."""
    original = runner.execution_telemetry.observe_process
    samples = output / (case.name + "-resources.jsonl")
    if samples.exists():
        raise ValueError("Resource observations already exist; choose a fresh evidence directory: " + str(samples))
    recorder = ProcessResources(samples, original)
    runner.execution_telemetry.observe_process = recorder.observe
    try:
        record, failed = runner.run_case(godot, case, output, role, env=env)
        record["resource_termination"] = recorder.finish(record)
        record["resource_samples"] = samples.name
        return record, failed
    finally:
        runner.execution_telemetry.observe_process = original
