#!/usr/bin/env python3
"""Source-bound, sequential ABBA investigation of material texture publication.

This research-only runner reuses the repository's process monitor, runtime
provenance checks and host telemetry. It never changes a rendering default or
publishes a native runtime. Original samples and failed arms remain evidence.
"""
from __future__ import annotations

import argparse
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import check_repository
import execution_telemetry
import godot_process_monitor
from godot_timeout_diagnostics import stop_process_tree
from run_windows_godot_regressions import native_input_paths

GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
BENCHMARK = "res://tests/run_render_upload_577_benchmark.gd"
CORRECTNESS = "res://tests/test_material_upload_hybrid.gd"
SYNTHETIC_WORKLOADS = {"sparse", "regions", "dense", "full", "repeated", "coverage", "transition"}
SOURCE_SCOPES = (
    "godot/scripts", "godot/shaders", "godot/tests", "godot/project.godot", "godot/main.tscn",
    "native/include", "native/src", "godot/native_extension", "tools/render_upload_577",
    "tools/ci/execution_telemetry.py", "tools/ci/godot_process_monitor.py",
    "tools/ci/godot_timeout_diagnostics.py", ".github/workflows/render-upload-577.yml",
    "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
)
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|^ERROR:", re.M)
PID = re.compile(r"^RENDER_UPLOAD_PID\s+(\d+)\s*$", re.M)
ORDER = ("full", "hybrid", "hybrid", "full")


def case(workload: str, size: int = 2048, workers: int = 1, family: str = "freemass_v1", channels: int = 2,
         ack: str = "normal") -> dict:
    suffix = (("_" + family if family != "freemass_v1" else "") + ("_r8" if channels == 1 else "")
              + ("_ack_" + ack if ack != "normal" else ""))
    return {"id": f"{workload}_{size}_w{workers}{suffix}", "workload": workload,
            "size": size, "workers": workers, "family": family, "channels": channels, "ack": ack}


CASES = [
    case("sparse", 512), case("sparse", 1024), case("sparse", 2048),
    case("sparse", 1024, channels=1), case("regions"), case("repeated"),
    case("dense"), case("full"), case("coverage"), case("transition"),
    case("dormant"), case("burst"), case("manual"),
    case("active", 512, 1), case("active", 512, 4),
    case("active", 1024, 1), case("active", 1024, 4),
    case("active", 2048, 1), case("active", 2048, 4),
    case("active", 2048, 1, "pressure_flow_v1"), case("active", 2048, 4, "pressure_flow_v1"),
    case("active", 1024, 1, "inertial_cellular_v1"),
    case("actor", 1024, 1), case("actor", 2048, 4, "pressure_flow_v1"),
    case("manual", 1024, ack="delayed150"), case("manual", 1024, ack="withheld"),
]


def validate_complete_pairs(runs: list[dict], cases: list[dict], rounds: int) -> None:
    """A failed/missing/duplicate arm can never produce a complete comparison."""
    expected = {(c["id"], r, phase, strategy) for c in cases
                for r in range(rounds) for phase, strategy in enumerate(ORDER)}
    actual = [(r["case"]["id"], r["round"], r["phase"], r["strategy"]) for r in runs]
    if len(set(actual)) != len(actual) or set(actual) != expected:
        raise ValueError("Campaign has missing, duplicate or unexpected ABBA arms")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.PIPE,
                                   timeout=60).decode("utf-8").strip()


def source_inventory(tracked: list[str], untracked: list[str]) -> tuple[list[str], list[str]]:
    """Ignore only generated UID companions of already tracked Godot resources.

    Godot 4.7 import creates missing legacy UID companions. They are not edited
    resource source; committed companions and new/untracked resources remain
    part of the authenticated manifest and exact-source refusal contract.
    """
    known = set(tracked)
    source_untracked = [name for name in untracked if not (
        name.startswith("godot/") and name.endswith((".gd.uid", ".gdshader.uid")) and name[:-4] in known)]
    return sorted(known | set(source_untracked)), source_untracked


def source_identity(expected_sha: str | None, allow_dirty: bool) -> dict:
    commit = git("rev-parse", "HEAD")
    if expected_sha and (not re.fullmatch(r"[0-9a-f]{40}", expected_sha) or commit != expected_sha):
        raise ValueError("Research checkout is not the requested exact source")
    changed = git("diff", "--name-only", "HEAD", "--", *SOURCE_SCOPES).splitlines()
    tracked = git("ls-files", "--", *SOURCE_SCOPES).splitlines()
    paths, untracked = source_inventory(tracked, git("ls-files", "--others", "--exclude-standard", "--", *SOURCE_SCOPES).splitlines())
    if (changed or untracked) and not allow_dirty:
        raise ValueError("Research source differs from its commit: " + ", ".join(changed + untracked))
    manifest = {name: sha(ROOT / name) for name in paths if (ROOT / name).is_file()}
    return {"commit": commit, "tree": git("rev-parse", "HEAD^{tree}"),
            "modified_paths": changed, "untracked_paths": untracked, "source_files": manifest,
            "source_manifest_sha256": hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest(),
            "generated_uid_policy": "Only untracked .gd.uid/.gdshader.uid companions of tracked Godot resources are excluded as editor import output; committed UID files remain authenticated",
            "qualification_scope": "local-delta preflight" if changed or untracked else "exact committed source"}


def retained_runtime_identity() -> dict:
    """Verify actual platform bytes and exact current native source coverage."""
    windows = sys.platform == "win32"
    platform = "windows" if windows else "linux"
    name = "runtime-provenance.json" if windows else "runtime-provenance.linux.json"
    relative = "godot/addons/cybersand_native/" + name
    data = (ROOT / relative).read_bytes()
    committed = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + relative], timeout=60)
    if data != committed:
        raise ValueError("Native provenance differs from the committed source")
    native = json.loads(data)
    if set(native["source_inputs"]) != native_input_paths(ROOT):
        raise ValueError("Retained native provenance does not cover the exact current source/header set")
    errors = check_repository.verify_runtime(ROOT, native)
    rapier_relative = f"godot/addons/godot-rapier2d/runtime-provenance.{platform}.json"
    rapier = json.loads((ROOT / rapier_relative).read_text(encoding="utf-8"))
    errors += check_repository.verify_rapier_overrides(
        ROOT, json.loads((ROOT / "godot/third_party/rapier2d.lock.json").read_text(encoding="utf-8")))
    if errors:
        raise ValueError("; ".join(errors))
    identities = {}
    for kind, manifest in (("native", native), ("rapier", rapier)):
        artifact = manifest["artifact"]
        path = ROOT / artifact
        expected_magic = b"MZ" if windows else b"\x7fELF"
        if not path.read_bytes().startswith(expected_magic):
            raise ValueError("Materialized platform runtime required: " + artifact)
        pointer = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + artifact], timeout=60)
        match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", pointer)
        digest = sha(path)
        size = path.stat().st_size
        if (match is None or digest != match[1].decode() or size != int(match[2])
                or digest != manifest["sha256"] or size != manifest["size"]):
            raise ValueError("Runtime bytes differ from committed LFS/provenance: " + artifact)
        identities[kind] = {"path": artifact, "sha256": digest, "size": size,
                            "original_source_commit": manifest.get("source_commit", manifest.get("build_record", {}).get("source_sha")),
                            "original_build_commit": manifest["build_commit"]}
    identities["native_source_inputs"] = native["source_inputs"]
    identities["native_provenance_sha256"] = hashlib.sha256(data).hexdigest()
    identities["reuse_scope"] = "Unchanged native inputs; retained source-matched binary, new script/renderer experiment"
    return identities


def engine_identity(launcher: Path) -> dict:
    launcher = launcher.resolve(strict=True)
    runtime = launcher
    if launcher.name.lower().endswith("_console.exe"):
        runtime = launcher.with_name(launcher.name[:-len("_console.exe")] + ".exe").resolve(strict=True)
    version = subprocess.check_output([str(launcher), "--version"], text=True, timeout=30).strip()
    if version != GODOT_VERSION:
        raise ValueError("Pinned Godot runtime required, found " + version)
    return {"version": version, **{kind: {"path": str(path), "sha256": sha(path), "size": path.stat().st_size}
                                  for kind, path in (("launcher", launcher), ("runtime", runtime))}}


def observe_process(pid: int) -> dict:
    observation = execution_telemetry.observe_process(pid)
    if observation.get("available") or sys.platform != "win32":
        return observation
    # The repository's Linux telemetry explicitly marks unavailable counters.
    # Win32 counters query the actual engine, not its console launcher.
    try:
        from ctypes import wintypes
        class Counters(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                        *[(field, ctypes.c_size_t) for field in
                          ("PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                           "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage",
                           "PagefileUsage", "PeakPagefileUsage", "PrivateUsage")]]
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        psapi = ctypes.WinDLL("psapi", use_last_error=True)
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.GetProcessTimes.argtypes = [wintypes.HANDLE, *([ctypes.POINTER(wintypes.FILETIME)] * 4)]
        psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
        handle = kernel.OpenProcess(0x0400 | 0x0010, False, pid)
        if handle:
            try:
                counters = Counters()
                counters.cb = ctypes.sizeof(counters)
                created, exited, system, user = (wintypes.FILETIME() for _ in range(4))
                if (psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb)
                        and kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited),
                                                   ctypes.byref(system), ctypes.byref(user))):
                    ticks = lambda value: (value.dwHighDateTime << 32) | value.dwLowDateTime
                    return {"available": True, "scope": "direct_process_only", "method": "Win32 process counters",
                            "peak_rss_bytes": int(counters.PeakWorkingSetSize),
                            "rss_bytes": int(counters.WorkingSetSize),
                            "private_bytes": int(counters.PrivateUsage),
                            "cpu_seconds": (ticks(system) + ticks(user)) / 10_000_000}
            finally:
                kernel.CloseHandle(handle)
    except (OSError, ValueError, AttributeError):
        pass
    return observation


def child_environment(cache_root: Path, label: str, source_sha: str) -> dict:
    env = os.environ.copy()
    for key, child in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                       ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
        path = cache_root / label / child
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path.resolve())
    env.update(CYBERSAND_SOURCE_REVISION=source_sha, CYBERSAND_SOURCE_SHA=source_sha,
               CYBERSAND_SHADER_CACHE_STATE="fresh process and per-arm userdata; imported project cache retained")
    return env


def validate_process_errors(output_text: str, expected_error_lines: tuple[str, ...] = ()) -> None:
    """Only exact intentional diagnostics may pass; count/order also matter."""
    clean = re.sub(r"\x1b\[[0-9;]*m", "", output_text)
    if re.search(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:", clean):
        raise ValueError("Unexpected script, parse or resource error")
    errors = tuple(line.strip() for line in clean.splitlines() if line.lstrip().startswith("ERROR:"))
    if errors != expected_error_lines:
        raise ValueError("Actual ERROR diagnostics differ from the exact intentional fixture messages")


def execute(command: list[str], env: dict, folder: Path, timeout: float, *,
            expected_error_lines: tuple[str, ...] = ()) -> dict:
    folder.mkdir(parents=True, exist_ok=False)
    log = folder / "process.log"
    started = time.perf_counter()
    samples: list[dict] = []
    engine_pid = None

    def sample(launcher_pid: int) -> None:
        nonlocal engine_pid
        if engine_pid is None:
            with log.open("r", encoding="utf-8", errors="replace") as reader:
                prefix = reader.read(65536)
            match = PID.search(prefix)
            if match:
                engine_pid = int(match[1])
            else:
                for line in prefix.splitlines():
                    if line.startswith(("PALETTE_QUALIFICATION_CONTEXT ", "RENDER_UPLOAD_STATE ")):
                        try:
                            engine_pid = int(json.loads(line.partition(" ")[2])["process_id"])
                        except (ValueError, KeyError):
                            pass
                        break
        observed = observe_process(engine_pid if engine_pid is not None else launcher_pid)
        samples.append({**observed, "pid": engine_pid if engine_pid is not None else launcher_pid,
                        "engine_announced": engine_pid is not None,
                        "elapsed_s": time.perf_counter() - started})

    options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if sys.platform == "win32" else {"start_new_session": True}
    with log.open("w", encoding="utf-8") as output:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, **options)
        try:
            timed_out, timeout_kind, capture_error = godot_process_monitor.wait(
                child, "render-upload-577", timeout, started, log, folder / "timeout-diagnostics", on_sample=sample)
        finally:
            if child.poll() is None:
                stop_process_tree(child)
    available = [row for row in samples if row.get("available") and row.get("engine_announced")]
    result = {"command": command, "cwd": str(ROOT), "exit_code": child.returncode,
              "elapsed_s": time.perf_counter() - started, "timed_out": timed_out,
              "timeout_kind": timeout_kind, "diagnostic_capture_error": capture_error,
              "diagnostic_capture_started": (folder / "timeout-diagnostics").exists(),
              "launcher_pid": child.pid, "engine_pid": engine_pid, "process_samples": samples,
              "peak_rss_bytes": max((int(row.get("peak_rss_bytes") or 0) for row in available), default=None),
              "cpu_seconds": max((float(row.get("cpu_seconds") or 0) for row in available), default=None),
              "process_counter_scope": "Actual direct Godot process including native threads; approximately 100 ms polling; startup/setup included"}
    output_text = log.read_text(encoding="utf-8", errors="replace")
    result["renderer_banners"] = [line for line in output_text.splitlines()
                                  if line.startswith(("OpenGL API ", "Vulkan ", "Direct3D "))]
    result["intentional_error_lines"] = list(expected_error_lines)
    write(folder / "process.json", result)
    error_failure = None
    try:
        validate_process_errors(output_text, expected_error_lines)
    except ValueError as error:
        error_failure = str(error)
    if child.returncode != 0 or timed_out or error_failure:
        raise RuntimeError(f"Process failed at {folder.name}: exit={child.returncode}; timeout={timed_out}; {output_text[-2500:]}")
    if result["diagnostic_capture_started"]:
        raise RuntimeError("Timing cohort contaminated by watchdog diagnostics: " + folder.name)
    return result


def summary(values: list[float]) -> dict:
    if not values:
        return {"count": 0}
    if any(not math.isfinite(value) for value in values):
        raise ValueError("Nonfinite timing sample")
    ordered = sorted(values)
    percentile = lambda fraction: ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]
    return {"count": len(values), "p50": percentile(.5), "p95": percentile(.95), "p99": percentile(.99),
            "max": ordered[-1], "mean": statistics.fmean(values),
            "stdev": statistics.stdev(values) if len(values) > 1 else 0.0}


def numeric_columns(rows: list[dict]) -> dict:
    columns: dict[str, list[float]] = {}
    for row in rows:
        for key, value in row.items():
            if type(value) in (int, float):
                columns.setdefault(key, []).append(float(value))
    return {key: summary(values) for key, values in sorted(columns.items())}


def reduce_coverage(runs: list[dict]) -> list[dict]:
    """Compare each dirty fraction after its eight-frame history transition."""
    fractions = (0.01, 0.05, 0.1, 0.25, 0.5, 1.0)
    buckets: dict[float, list[dict]] = {fraction: [] for fraction in fractions}
    for run in runs:
        frames = run["data"]["frames"]
        uploads = run["data"]["uploads"]
        if len(uploads) != len(frames) or any(sample.get("accepted") is not True for sample in uploads):
            raise ValueError("Coverage requires one accepted synchronous upload per frame")
        per_fraction = {fraction: {"frames": [], "uploads": [], "excluded_frames": 0} for fraction in fractions}
        offset = 0
        for frame in frames:
            fraction = frame.get("coverage_fraction")
            phase_frame = frame.get("coverage_phase_frame")
            count = frame.get("upload_count")
            if (fraction not in per_fraction or type(phase_frame) is not int or phase_frame < 0
                    or type(count) is not int or count != 1 or offset + count > len(uploads)):
                raise ValueError("Coverage frame/phase/upload association is invalid")
            bucket = per_fraction[fraction]
            if phase_frame < 8:
                bucket["excluded_frames"] += 1
            else:
                bucket["frames"].append(frame)
                bucket["uploads"].extend(uploads[offset:offset + count])
            offset += count
        if offset != len(uploads):
            raise ValueError("Coverage frame associations did not exhaust upload samples")
        for fraction, bucket in per_fraction.items():
            if bucket["excluded_frames"] != 8 or len(bucket["frames"]) < 8:
                raise ValueError("Coverage stratum did not complete its transition and retained observations")
            buckets[fraction].append({"strategy": run["strategy"], **bucket})
    result = []
    for fraction, bucket_arms in buckets.items():
        row = {"nominal_dirty_fraction": fraction,
               "scope": "Same source/host/fraction; first eight frames of every phase excluded from this comparison but retained raw",
               "strategies": {}}
        for strategy in ORDER[:2]:
            arms = [arm for arm in bucket_arms if arm["strategy"] == strategy]
            frames = [frame for arm in arms for frame in arm["frames"]]
            uploads = [upload for arm in arms for upload in arm["uploads"]]
            modes: dict[str, int] = {}
            for upload in uploads:
                mode = str(upload.get("metrics", {}).get("mode", "unreported"))
                modes[mode] = modes.get(mode, 0) + 1
            row["strategies"][strategy] = {
                "arms": len(arms), "excluded_transition_frames": sum(arm["excluded_frames"] for arm in arms),
                "frame_metrics": numeric_columns(frames), "upload_metrics": numeric_columns(uploads),
                "repeat_frame_ms": [summary([float(frame["frame_ms"]) for frame in arm["frames"]]) for arm in arms],
                "repeat_submit_ms": [summary([float(upload["submit_ms"]) for upload in arm["uploads"]]) for arm in arms],
                "publication_mode_counts": modes,
                "totals": {key: sum(float(sample[key]) for sample in uploads if type(sample.get(key)) in (int, float))
                           for key in ("dirty_bytes", "logical_bytes")}}
        before = row["strategies"]["full"]["frame_metrics"].get("frame_ms", {})
        after = row["strategies"]["hybrid"]["frame_metrics"].get("frame_ms", {})
        if before.get("count") and after.get("count"):
            row["hybrid_minus_full_frame_ms"] = {
                metric: {"ms": after[metric] - before[metric],
                         "percent": 100 * (after[metric] - before[metric]) / before[metric] if before[metric] else None}
                for metric in ("p50", "p95", "p99")}
        result.append(row)
    return result


def reduce_runs(runs: list[dict]) -> list[dict]:
    """Keep per-arm distributions: pooled quantiles alone can hide variance."""
    result = []
    for case_id in dict.fromkeys(run["case"]["id"] for run in runs):
        selected = [run for run in runs if run["case"]["id"] == case_id]
        row = {"case": case_id, "cohort": selected[0]["data"].get("cohort"), "strategies": {}}
        for strategy in ORDER[:2]:
            arms = [run for run in selected if run["strategy"] == strategy]
            frames = [sample for arm in arms for sample in arm["data"]["frames"]]
            uploads = [sample for arm in arms for sample in arm["data"].get("uploads", [])]
            publications = [{key: value for key, value in sample.items() if key != "native_tick_ms"}
                            for arm in arms for sample in arm["data"].get("publications", [])]
            actions = [sample for arm in arms for sample in arm["data"].get("actions", [])]
            modes = {}
            for sample in uploads:
                mode = sample.get("metrics", {}).get("mode", "unreported")
                modes[mode] = modes.get(mode, 0) + 1
            row["strategies"][strategy] = {
                "publication_mode_counts": modes,
                "arms": len(arms), "frame_metrics": numeric_columns(frames), "upload_metrics": numeric_columns(uploads),
                "publication_metrics": numeric_columns(publications), "action_metrics": numeric_columns(actions),
                "publication_metrics_scope": "Observed immutable snapshot publications; repeated native-tick observations are not distinct completed work",
                "repeat_native_tick_ms": [arm["data"].get("distinct_observed_native_tick_ms") for arm in arms],
                "requested_workers": selected[0]["case"].get("workers"),
                "actual_native_worker_capacities": sorted({arm["data"]["actual_native_worker_capacity"] for arm in arms
                                                          if arm["data"].get("actual_native_worker_capacity") is not None}),
                "repeat_tick_progress": [arm["data"].get("tick_progress") for arm in arms],
                "repeat_observed_ticks_per_second": [arm["data"].get("observed_ticks_per_second") for arm in arms],
                "repeat_rapier_steps_per_second": [arm["data"].get("rapier_steps_per_second") for arm in arms],
                "repeat_accepted_updates_per_second": [arm["data"].get("accepted_updates_per_second") for arm in arms],
                "repeat_transport_full_publications": [arm["data"].get("transport_full_publications") for arm in arms],
                "repeat_native_full_refreshes": [arm["data"].get("native_full_refreshes") for arm in arms],
                "native_capture_ms": summary([sample["capture_usec"] / 1000.0 for arm in arms
                                                for sample in arm["data"].get("native_capture", {}).get("samples", [])]),
                "accepted_ack_to_worker_latch_ms": summary([
                    (sample["observed_usec"] - sample["requested_usec"]) / 1000.0 for arm in arms
                    for sample in arm["data"].get("ack_during_timing", {}).get("requests", [])
                    if sample["observed_usec"] > 0]),
                "ack_requests_unobserved_at_window_end": sum(
                    sample["observed_usec"] == 0 for arm in arms
                    for sample in arm["data"].get("ack_during_timing", {}).get("requests", [])),
                "repeat_frame_ms": [summary([float(sample["frame_ms"]) for sample in arm["data"]["frames"]]) for arm in arms],
                "peak_process_rss_bytes": max((arm["process"]["peak_rss_bytes"] for arm in arms
                                               if arm["process"]["peak_rss_bytes"] is not None), default=None),
                "totals": {key: sum(float(sample[key]) for sample in uploads if type(sample.get(key)) in (int, float))
                           for key in sorted({key for sample in uploads for key in sample
                                              if key.endswith("_bytes") or key.endswith("_count")})},
            }
        before = row["strategies"]["full"]["frame_metrics"].get("frame_ms", {})
        after = row["strategies"]["hybrid"]["frame_metrics"].get("frame_ms", {})
        if before.get("count") and after.get("count"):
            row["hybrid_minus_full_frame_ms"] = {
                metric: {"ms": after[metric] - before[metric],
                         "percent": 100 * (after[metric] - before[metric]) / before[metric] if before[metric] else None}
                for metric in ("p50", "p95", "p99")}
        if selected[0]["case"].get("workload") == "coverage":
            row["coverage_interpretation"] = "The pooled six-phase distribution is descriptive only; use coverage_strata for break-even evidence"
            row["coverage_strata"] = reduce_coverage(selected)
        result.append(row)
    return result


def expected_submit_usec(metrics: dict) -> float:
    """Sum separate staging APIs and destination API, never alias/nested timers."""
    key = "texture_submit_usec" if "texture_submit_usec" in metrics else "texture_update_usec"
    if key not in metrics:
        raise ValueError("Missing actual destination API interval")
    values = [metrics[key], metrics.get("source_create_usec", 0), metrics.get("source_update_usec", 0)]
    if any(type(v) not in (int, float) or not math.isfinite(v) or v < 0 for v in values):
        raise ValueError("Invalid renderer API timing interval")
    return sum(values)


def verify_upload_accounting(data: dict) -> None:
    uploads = data.get("uploads")
    if not isinstance(uploads, list):
        raise ValueError("Missing raw publication intervals")
    full_keys = set()
    for sample in uploads:
        if sample.get("accepted") is not True:
            raise ValueError("Unexpected refused publication in admitted timing cohort")
        expected = expected_submit_usec(sample.get("metrics", {})) / 1000.0
        if type(sample.get("submit_ms")) not in (int, float) or abs(sample["submit_ms"] - expected) > 1e-6:
            raise ValueError("Submission aggregate omits or double-counts raw API intervals")
        if sample.get("transport_full_refresh") is True and sample.get("render_serial", -1) >= 0:
            full_keys.add((sample["generation"], sample["render_serial"]))
    if data.get("transport_full_publications") != len(full_keys):
        raise ValueError("Transport full count differs from unique accepted material publications")


def verify_native_capture_accounting(data: dict) -> None:
    """Require source-capture observations, not cached transport flags."""
    if data.get("cohort") == "deterministic_renderer_seam":
        if data.get("native_full_refreshes") is not None:
            raise ValueError("Synthetic workload cannot report native capture calls")
        return
    capture = data.get("native_capture", {})
    if capture.get("dropped_samples") != 0 or not isinstance(capture.get("samples"), list):
        raise ValueError("Missing or truncated native capture observations")
    samples = capture["samples"]
    totals = {"calls": len(samples), "forced_full_requests": sum(s["forced_full"] for s in samples),
              "nonempty_packets": sum(s["nonempty"] for s in samples),
              "full_packets": sum(s["full_refresh"] for s in samples),
              "logical_bytes": sum(s["logical_bytes"] for s in samples),
              "capture_usec": sum(s["capture_usec"] for s in samples)}
    if capture.get("delta") != totals:
        raise ValueError("Native capture counter delta differs from raw adapter observations")
    for key, count in totals.items():
        if capture.get("after", {}).get(key, -1) - capture.get("before", {}).get(key, -1) != count:
            raise ValueError("Native capture before/after identities differ from raw counts")
    if data.get("native_full_refreshes") != totals["full_packets"]:
        raise ValueError("Native full count differs from source capture packets")
    for sample in samples:
        if sample["capture_usec"] < 0 or sample["end_usec"] - sample["start_usec"] != sample["capture_usec"]:
            raise ValueError("Invalid native adapter call interval")


def verify_actor_input_tape(data: dict) -> None:
    if data.get("workload") != "actor":
        return
    seen = set()
    for sample in data.get("actor_input_samples", []):
        index = sample["tape_index"]
        powered = index % 120 < 60
        if (index < 0 or index in seen or sample["accepted"] is not True
                or sample["completed_step"] - data["initial_rapier_step"] != index
                or len(sample["move"]) != 2
                or any(not math.isclose(actual, expected, abs_tol=1e-6) for actual, expected
                       in zip(sample["move"], [0.2, -0.6] if powered else [0, 0]))
                or sample["trim"] != (0.15 if powered else 0)
                or sample["effort"] != (0.5 if powered else 0)):
            raise ValueError("Actor input differs from the completed-physics-step tape")
        seen.add(index)
    if not seen:
        raise ValueError("Actor workload did not observe an admitted physical input")


def verify_ack_observations(data: dict) -> None:
    if data.get("cohort") == "deterministic_renderer_seam":
        return
    mode = data["config"]["ack"]
    evidence = data.get("ack_during_timing", {})
    if evidence.get("mode") != mode:
        raise ValueError("Missing or mislabeled ACK delivery policy")
    requests = evidence.get("requests", [])
    serials = [r["serial"] for r in requests]
    if serials != sorted(set(serials)):
        raise ValueError("ACK records lost monotonic accepted material identity")
    for record in requests:
        if record["delivered_usec"] and record["delivered_usec"] < record["requested_usec"]:
            raise ValueError("ACK delivery preceded accepted Main publication")
        if record["observed_usec"] and record["observed_usec"] < record["delivered_usec"]:
            raise ValueError("Worker ACK observation preceded delivery")
        if mode == "delayed150" and record["delivered_usec"] and record["delivered_usec"] - record["requested_usec"] < 150000:
            raise ValueError("Delayed-ACK workload did not enforce its declared delay")
        if mode == "withheld" and (record["delivered_usec"] or record["observed_usec"]):
            raise ValueError("Missing-ACK workload delivered ACKs inside the timed window")
    if mode != "normal":
        recovery = data.get("ack_recovery_outside_timing", {})
        if (not requests or recovery.get("converged") is not True
                or recovery.get("accepted_revision") != recovery.get("authoritative_revision")
                or recovery.get("final", {}).get("observed_serial", -1) < recovery.get("accepted_material_serial", 0)
                or any(not r["observed_usec"] for r in recovery.get("final", {}).get("requests", []))):
            raise ValueError("ACK fault recovery did not converge to current authoritative material")


def verify_runtime_result(data: dict, engine: dict, source: dict, *, process: dict, rendering_driver: str,
                          config: dict | None, frames: int | None, strategy: str | None,
                          fixture_sha256: str | None = None) -> dict:
    if data.get("ok") is not True or data.get("failures"):
        raise ValueError("Runtime receipt records failure or lacks explicit success")
    context = data.get("context", {})
    if (context.get("engine_sha256") != engine["runtime"]["sha256"]
            or Path(context.get("engine_path", "")).resolve() != Path(engine["runtime"]["path"])):
        raise ValueError("Runtime receipt does not identify the authenticated actual engine")
    if context.get("source_revision") != source["commit"]:
        raise ValueError("Runtime receipt identifies another source")
    if context.get("display_server") in (None, "headless"):
        raise ValueError("Graphical qualification requires an actual display server")
    if (context.get("backend") != rendering_driver
            or not isinstance(context.get("video_adapter"), str)
            or not context["video_adapter"].strip()
            or context["video_adapter"] == "headless"):
        raise ValueError("Runtime receipt identifies another driver or lacks an actual adapter")
    banners = process.get("renderer_banners", [])
    if (len(banners) != 1 or not banners[0].startswith("OpenGL API ")
            or " - Compatibility - Using Device: " not in banners[0]):
        raise ValueError("Actual process did not announce the required OpenGL Compatibility renderer/API")
    graphics = {key: context.get(key) for key in ("backend", "video_adapter", "display_server", "platform")}
    graphics["renderer_api_banner"] = banners[0]
    if fixture_sha256 is not None and context.get("fixture_sha256") != fixture_sha256:
        raise ValueError("Executed fixture differs from its authenticated source")
    if config is None:
        return graphics
    actual = data.get("config", data)
    for key in ("size", "workload", "workers", "family", "channels", "ack"):
        if actual.get(key) != config[key]:
            raise ValueError("Runtime configuration differs from requested " + key)
    if actual.get("strategy") != strategy:
        raise ValueError("Runtime used another publication strategy")
    for key in ("fixture_sha256", "initial_image_sha256", "final_image_sha256"):
        if not re.fullmatch(r"[0-9a-f]{64}", str(data.get(key, ""))):
            raise ValueError("Missing authenticated fixture image identity: " + key)
    expected_cohort = "deterministic_renderer_seam" if config["workload"] in SYNTHETIC_WORKLOADS else "mounted_native_workbench"
    if data.get("cohort") != expected_cohort:
        raise ValueError("Runtime cohort is mislabeled or differs from its declared workload")
    if expected_cohort == "mounted_native_workbench" and data.get("native_backend") != "native-phased":
        raise ValueError("Native workload did not execute its authoritative native backend")
    if expected_cohort == "mounted_native_workbench":
        capacity = data.get("actual_native_worker_capacity")
        if type(capacity) is not int or capacity <= 0 or data.get("requested_workers") != config["workers"]:
            raise ValueError("Native workload lacks positive actual worker capacity and requested-worker identity")
    if data.get("final_strategy", {}).get("active") != strategy:
        raise ValueError("Requested strategy fell back during the timed cohort")
    if data.get("final_current_texture_matches_cpu") is not True:
        raise ValueError("Final accepted texture does not equal the validated CPU image")
    if data.get("rejected_publications") != 0:
        raise ValueError("Unexpected rejection in an admitted timed cohort")
    verify_upload_accounting(data)
    verify_native_capture_accounting(data)
    verify_actor_input_tape(data)
    verify_ack_observations(data)
    samples = data.get("frames")
    if not isinstance(samples, list) or len(samples) != frames:
        raise ValueError("Runtime frame samples incomplete")
    if any(type(row.get("frame_ms")) not in (int, float) or row["frame_ms"] < 0 for row in samples):
        raise ValueError("Invalid frame-time samples")
    return graphics


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cache-root", type=Path)
    parser.add_argument("--source-sha")
    parser.add_argument("--allow-dirty", action="store_true", help="Local preflight only; explicitly excludes exact-source qualification")
    parser.add_argument("--cases", default="all", help="Comma-separated declared case IDs")
    parser.add_argument("--frames", type=int, default=240)
    parser.add_argument("--warmup", type=int, default=30)
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("--rendering-driver", default="opengl3_angle" if sys.platform == "win32" else "opengl3")
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--skip-correctness", action="store_true", help="Separate already-executed correctness must be cited")
    parser.add_argument("--correctness-only", action="store_true")
    args = parser.parse_args()
    if args.frames < 4 or args.warmup < 1 or args.rounds < 1 or args.timeout < 10:
        parser.error("frames>=4, warmup>=1, rounds>=1, timeout>=10 required")
    if args.allow_dirty and (args.source_sha or os.environ.get("GITHUB_ACTIONS") == "true"):
        parser.error("Local-delta preflight cannot claim an exact requested/hosted source")
    requested = set(args.cases.split(","))
    cases = [item for item in CASES if args.cases == "all" or item["id"] in requested]
    if not cases or (args.cases != "all" and requested != {item["id"] for item in cases}):
        parser.error("Unknown case IDs; available: " + ", ".join(item["id"] for item in CASES))
    if any(item["workload"] == "coverage" for item in cases) and (args.frames < 96 or args.frames % 6):
        parser.error("Coverage requires frames>=96 divisible by six for complete balanced strata")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / "campaign.json"
    if report_path.exists():
        raise ValueError("Refusing to overwrite original campaign evidence: " + str(report_path))
    cache_root = (args.cache_root or output.parent / (output.name + "-userdata")).resolve()
    if cache_root == output or output in cache_root.parents:
        raise ValueError("Per-arm caches must remain outside the retained evidence directory")
    report = {"schema": "render-upload-577-campaign-v1", "complete": False,
              "started_utc": datetime.now(timezone.utc).isoformat(), "host": execution_telemetry.host_identity(),
              "order": list(ORDER), "rounds": args.rounds, "frames_per_arm": args.frames,
              "warmup_per_arm": args.warmup, "cases": cases, "runs": [],
              "correctness": {"status": "not executed"},
              "environment": {key: os.environ.get(key) for key in
                              ("LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GALLIVM_PERF", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")},
              "limits": ["ImageTexture/DrawableTexture API duration is CPU call wall time, not completed GPU transfer",
                         "Logical submitted bytes are not measured PCIe traffic",
                         "Hosted llvmpipe/WARP results do not establish hardware GPU performance",
                         "Direct-process RSS includes startup/setup and native worker threads",
                         "Bounded p99 values are descriptive; raw and per-arm variance are retained",
                         "Framebuffer readback belongs to correctness, never timed frame cohorts"]}
    write(report_path, report)
    try:
        source = source_identity(args.source_sha, args.allow_dirty)
        runtime = retained_runtime_identity()
        engine = engine_identity(args.godot)
        report.update(source=source, runtime=runtime, engine=engine,
                      apparatus={"runner_sha256": sha(Path(__file__)),
                                 "benchmark_sha256": sha(ROOT / BENCHMARK.replace("res://", "godot/")),
                                 "correctness_sha256": sha(ROOT / CORRECTNESS.replace("res://", "godot/"))})
        write(report_path, report)
        basic = [engine["launcher"]["path"], "--audio-driver", "Dummy", "--path", str(ROOT / "godot")]
        graphical = [*basic, "--rendering-method", "gl_compatibility", "--rendering-driver", args.rendering_driver]
        if not args.skip_import:
            report["import"] = execute([*basic, "--headless", "--editor", "--import", "--quit"],
                child_environment(cache_root, "import", source["commit"]), output / "import", args.timeout)
            write(report_path, report)
        if not args.skip_correctness:
            folder = output / "correctness"
            env = child_environment(cache_root, "correctness", source["commit"])
            env["CYBERSAND_TEST_ARTIFACT_DIR"] = str(folder / "captures")
            process = execute([*graphical, "--script", CORRECTNESS, "--", "--output=" + str(folder / "runtime.json")],
                              env, folder, max(args.timeout, 600))
            data = json.loads((folder / "runtime.json").read_text(encoding="utf-8"))
            graphics = verify_runtime_result(data, engine, source, process=process, rendering_driver=args.rendering_driver,
                config=None, frames=None, strategy=None, fixture_sha256=report["apparatus"]["correctness_sha256"])
            report["correctness"] = {"status": "passed", "data": data, "process": process, "graphics": graphics}
            write(report_path, report)
        if not args.correctness_only:
            for config in cases:
                for round_index in range(args.rounds):
                    for phase, strategy in enumerate(ORDER):
                        label = f"{config['id']}-r{round_index}-{phase}-{strategy}"
                        folder = output / label
                        env = child_environment(cache_root, label, source["commit"])
                        command = [*graphical, "--script", BENCHMARK, "--",
                                   "--strategy=" + strategy, "--size=" + str(config["size"]),
                                   "--workload=" + config["workload"], "--workers=" + str(config["workers"]),
                                   "--frames=" + str(args.frames), "--warmup=" + str(args.warmup),
                                   "--family=" + config["family"],
                                   "--channels=" + str(config["channels"]),
                                   "--ack=" + config["ack"],
                                   "--render-upload=" + strategy,
                                   "--output=" + str(folder / "runtime.json")]
                        print("BEGIN " + label, flush=True)
                        process = execute(command, env, folder, args.timeout)
                        data = json.loads((folder / "runtime.json").read_text(encoding="utf-8"))
                        graphics = verify_runtime_result(data, engine, source, process=process,
                            rendering_driver=args.rendering_driver, config=config, frames=args.frames, strategy=strategy,
                            fixture_sha256=report["apparatus"]["benchmark_sha256"])
                        if data["context"].get("process_id") != process["engine_pid"]:
                            raise ValueError("Runtime/observed actual engine PID mismatch")
                        previous = [run for run in report["runs"] if run["case"]["id"] == config["id"]]
                        if previous:
                            if graphics != previous[0]["graphics"]:
                                raise ValueError("Matched arms changed actual renderer/API/driver/adapter/display identity")
                            keys = ["fixture_sha256", "initial_image_sha256", "cohort", "world_extent"]
                            if data["cohort"] == "mounted_native_workbench":
                                keys.append("actual_native_worker_capacity")
                            if data["cohort"] == "deterministic_renderer_seam":
                                keys.append("final_image_sha256")
                            for key in keys:
                                if data.get(key) != previous[0]["data"].get(key):
                                    raise ValueError("Matched source strategies have different " + key)
                        report["runs"].append({"case": config, "round": round_index, "phase": phase,
                                               "strategy": strategy, "folder": label, "data": data,
                                               "process": process, "graphics": graphics})
                        report["comparisons"] = reduce_runs(report["runs"])
                        write(report_path, report)
                        frame_summary = summary([float(sample["frame_ms"]) for sample in data["frames"]])
                        print(f"PASS {label} n={frame_summary['count']} p50={frame_summary['p50']:.3f}ms p95={frame_summary['p95']:.3f}ms", flush=True)
        validate_complete_pairs(report["runs"], cases if not args.correctness_only else [], args.rounds)
        if source_identity(args.source_sha, args.allow_dirty) != source or retained_runtime_identity() != runtime:
            raise ValueError("Source or retained native runtime changed during the campaign")
        if engine_identity(args.godot) != engine:
            raise ValueError("Godot launcher or actual engine changed during the campaign")
        report["complete"] = True
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        write(report_path, report)
        print(f"RENDER_UPLOAD_CAMPAIGN_PASS arms={len(report['runs'])} correctness={report['correctness']['status']}", flush=True)
        return 0
    except BaseException as error:
        report["failure"] = f"{type(error).__name__}: {error}"
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        write(report_path, report)
        raise


if __name__ == "__main__":
    raise SystemExit(main())
