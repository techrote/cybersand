#!/usr/bin/env python3
"""Controlled same-host comparisons of exact accepted/integrated applications.

Both checkout runtimes must be built before this runner starts. This apparatus
does not replace native libraries, edit application sources, or select solvers.
The same external GDScript bytes execute against each checkout in ABBA order.
"""
from __future__ import annotations

import argparse
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
import time

import execution_telemetry
import godot_process_monitor
from godot_timeout_diagnostics import stop_process_tree

ROOT = Path(__file__).resolve().parents[2]
PRODUCT_PATHS = ("godot/scripts", "godot/shaders", "godot/main.tscn", "godot/project.godot",
                 "native/src", "native/include", "godot/native_extension")
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")


def case(name, side, occupancy, *, camera="stationary", active=False, workers=1,
         effects=False, activity="idle", large=False, zoom=2.5):
    return dict(id=name, side=side, occupancy=occupancy, camera=camera, active=active,
                workers=workers, effects=effects, activity=activity, zoom=zoom,
                window=[1280, 960] if large else [960, 720], view=[240, 135])


CASES = [
    case("stationary_512_palette", 512, "sparse", zoom=2.0),
    case("slow_pan_512_palette", 512, "sparse", camera="slow_pan"),
    case("dense_1024_pan_large", 1024, "dense", camera="pan", large=True, zoom=4.0),
    case("mixed_1024_effects", 1024, "mixed", effects=True, zoom=2.0),
    case("mixed_1024_zoom_effects", 1024, "mixed", camera="zoom", effects=True, large=True),
    case("active_512_w1", 512, "sand_water", active=True, effects=True, workers=1),
    case("active_512_w4", 512, "sand_water", active=True, effects=True, workers=4),
    case("active_2048_w1", 2048, "sand_water", camera="pan", active=True, workers=1),
    case("active_2048_w4", 2048, "sand_water", camera="pan", active=True, workers=4),
    case("stationary_2048_palette", 2048, "mixed", workers=4, large=True, zoom=1.0),
    case("manual_2048", 2048, "sparse", activity="manual", workers=4),
    case("agent_2048", 2048, "sparse", activity="agent", workers=4, large=True),
    case("actor_follow_1024", 1024, "sparse", camera="follow", active=True, effects=True, large=True),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git(root: Path, *args) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True,
                                   stderr=subprocess.PIPE, timeout=60).strip()


def identity(root: Path) -> dict:
    changed = git(root, "diff", "--name-only", "HEAD", "--", *PRODUCT_PATHS)
    if changed:
        raise ValueError(f"Application source differs from its exact commit in {root}: {changed}")
    files = git(root, "ls-files", "--", *PRODUCT_PATHS).splitlines()
    manifest = {name: sha(root / name) for name in files if (root / name).is_file()}
    windows = sys.platform == "win32"
    native = root / "godot/addons/cybersand_native/bin" / (
        "cybersand_native.windows.x86_64.dll" if windows else "libcybersand_native.linux.x86_64.so")
    if not native.is_file() or native.stat().st_size < 1024:
        raise ValueError(f"Materialized source-built native runtime required: {native}")
    return {"commit": git(root, "rev-parse", "HEAD"), "tree": git(root, "rev-parse", "HEAD^{tree}"),
            "source_files": manifest, "source_manifest_sha256": hashlib.sha256(
                json.dumps(manifest, sort_keys=True).encode()).hexdigest(),
            "native_path": str(native.relative_to(root)), "native_sha256": sha(native),
            "native_size": native.stat().st_size,
            "build_custody": "Caller supplies independently source-built runtime; original build receipts belong to the enclosing qualification workflow."}


def summary(values):
    if not values:
        return {"count": 0}
    ordered = sorted(values)
    def percentile(q):
        return ordered[max(0, math.ceil(len(ordered) * q) - 1)]
    return {"count": len(values), "mean": statistics.fmean(values), "p50": percentile(.5),
            "p95": percentile(.95), "p99": percentile(.99), "max": ordered[-1],
            "stdev": statistics.stdev(values) if len(values) > 1 else 0.0}


def observe_process(pid: int) -> dict:
    value = execution_telemetry.observe_process(pid)
    if value.get("available"):
        return value
    if value.get("reason") == "proc_pid_namespace_mismatch":
        return value
    if sys.platform == "win32":
        # Query the actual Godot PID, not its console launcher. No optional
        # Python dependency is needed on the hosted Windows image.
        try:
            import ctypes
            from ctypes import wintypes
            class Counters(ctypes.Structure):
                _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                            *[(name, ctypes.c_size_t) for name in ("PeakWorkingSetSize", "WorkingSetSize",
                               "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
                               "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage", "PrivateUsage")]]
            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            psapi = ctypes.WinDLL("psapi", use_last_error=True)
            kernel.OpenProcess.restype = wintypes.HANDLE
            kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            kernel.GetProcessTimes.argtypes = [wintypes.HANDLE, *([ctypes.POINTER(wintypes.FILETIME)]*4)]
            psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
            handle = kernel.OpenProcess(0x0400 | 0x0010, False, pid)
            if handle:
                try:
                    counters = Counters()
                    counters.cb = ctypes.sizeof(counters)
                    created, exited, system, user = (wintypes.FILETIME() for _ in range(4))
                    memory_ok = psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb)
                    time_ok = kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited),
                                                     ctypes.byref(system), ctypes.byref(user))
                    if memory_ok and time_ok:
                        ticks = lambda t: (t.dwHighDateTime << 32) | t.dwLowDateTime
                        return {"scope": "direct_process_only", "available": True,
                                "cpu_seconds": (ticks(system)+ticks(user))/10_000_000,
                                "peak_rss_bytes": int(counters.PeakWorkingSetSize),
                                "rss_bytes": int(counters.WorkingSetSize), "method": "Win32 process counters"}
                finally:
                    kernel.CloseHandle(handle)
        except (OSError, ValueError, AttributeError):
            pass
    # Optional psutil supplies Windows process counters. Its absence is explicit.
    try:
        import psutil
        process = psutil.Process(pid)
        memory = process.memory_info()
        cpu = process.cpu_times()
        return {"scope": "direct_process_only", "available": True,
                "cpu_seconds": cpu.user + cpu.system,
                "peak_rss_bytes": getattr(memory, "peak_wset", memory.rss),
                "rss_bytes": memory.rss}
    except Exception:
        return value


def execute(command, cwd: Path, env: dict, folder: Path, timeout: float) -> dict:
    folder.mkdir(parents=True, exist_ok=True)
    log = folder / "process.log"
    started = time.perf_counter()
    samples = []
    engine_pid = None
    def sample(pid):
        nonlocal engine_pid
        if engine_pid is None and log.exists():
            # The pinned engine console wrapper has a different PID on Windows.
            # The trusted harness announces its actual PID before fixture setup.
            with log.open("r", encoding="utf-8", errors="replace") as reader:
                prefix = reader.read(131072)
            match = re.search(r"^INTEGRATED_CAMERA_PERF_PID (\d+)$", prefix, re.M)
            if match:
                engine_pid = int(match[1])
            else:
                for line in prefix.splitlines():
                    if line.startswith("PALETTE_QUALIFICATION_CONTEXT "):
                        try:
                            engine_pid = int(json.loads(line.partition(" ")[2])["process_id"])
                        except (ValueError, KeyError):
                            pass
                        break
        observed = observe_process(engine_pid if engine_pid is not None else pid)
        observed["pid"] = engine_pid if engine_pid is not None else pid
        observed["engine_announced"] = engine_pid is not None
        observed["elapsed_s"] = time.perf_counter() - started
        samples.append(observed)
    options = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
               if sys.platform == "win32" else {"start_new_session": True})
    with log.open("w", encoding="utf-8") as output:
        child = subprocess.Popen(command, cwd=cwd, env=env, stdout=output,
                                 stderr=subprocess.STDOUT, **options)
        try:
            timed_out, timeout_kind, capture_error = godot_process_monitor.wait(
                child, "integrated-camera-performance", timeout, started, log,
                folder / "timeout-diagnostics", on_sample=sample)
        finally:
            if child.poll() is None:
                stop_process_tree(child)
        code = child.returncode
    elapsed = time.perf_counter()-started
    available = [x for x in samples if x.get("available") and (engine_pid is None or x.get("engine_announced"))]
    record = {"command": command, "elapsed_s": elapsed, "exit_code": code,
              "timed_out": timed_out, "timeout_kind": timeout_kind,
              "diagnostic_capture_error": capture_error,
              "diagnostic_capture_started": (folder / "timeout-diagnostics").exists(),
              "launcher_pid": child.pid, "announced_engine_pid": engine_pid,
              "process_samples": samples,
              "peak_rss_bytes": max((int(x.get("peak_rss_bytes") or 0) for x in available), default=None),
              "cpu_seconds": max((float(x.get("cpu_seconds") or 0) for x in available), default=None),
              "process_counter_scope": "Godot direct process, including its native worker threads; 100 ms polling; startup and setup included"}
    write(folder / "process.json", record)
    text = log.read_text(encoding="utf-8", errors="replace")
    if code != 0 or timed_out or ERRORS.search(text):
        raise RuntimeError(f"Benchmark process failed in {folder}: exit={code}, timeout={timed_out}; {text[-3000:]}")
    if record["diagnostic_capture_started"]:
        raise RuntimeError(f"Timing cohort contaminated by watchdog diagnostics: {folder}")
    return record


def env_for(folder: Path) -> dict:
    env = os.environ.copy()
    user = folder / "userdata"
    for key, child in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                       ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"),
                       ("LOCALAPPDATA", "local")):
        path = user / child
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path.resolve())
    return env


def reduce_runs(runs: list[dict]) -> list[dict]:
    comparisons = []
    for name in dict.fromkeys(run["case"] for run in runs):
        selected = [run for run in runs if run["case"] == name]
        row = {"case": name, "subjects": {}}
        for subject in ("A", "B"):
            arms = [run for run in selected if run["subject"] == subject]
            frame_values = [frame["frame_ms"] for arm in arms for frame in arm["data"]["frames"]]
            record = {"frames_ms": summary(frame_values),
                      "repeat_medians_ms": [arm["data"]["summary"]["frame_ms"]["p50"] for arm in arms],
                      "repeat_p95_ms": [arm["data"]["summary"]["frame_ms"]["p95"] for arm in arms],
                      "peak_process_rss_bytes": max((arm["process"].get("peak_rss_bytes") or 0 for arm in arms), default=0),
                      "source_commit": arms[0]["source_commit"] if arms else None,
                      "native_tick_ms": summary([x["native_tick_ms"] for arm in arms for x in arm["data"]["publications"]]),
                      "upload_ms": summary([x["upload_ms"] for arm in arms for x in arm["data"]["uploads"]]),
                      "uploaded_texture_bytes": sum(x["submitted_texture_bytes"] for arm in arms for x in arm["data"]["uploads"]),
                      "copied_patch_bytes": sum(x["patch_bytes"] for arm in arms for x in arm["data"]["uploads"]),
                      "authoring_receipt_ms": summary([x["receipt_latency_ms"] for arm in arms for x in arm["data"]["actions"]]),
                      "authoring_presentation_ms": summary([x["presentation_latency_ms"] for arm in arms for x in arm["data"]["actions"]])}
            for metric in ("main_process_ms", "shader_update_ms", "snapshot_consume_ms", "worker_frame_state_ms", "godot_process_ms"):
                record[metric] = summary([x[metric] for arm in arms for x in arm["data"]["frames"]])
            record["tick_progress"] = [arm["data"].get("tick_progress") for arm in arms]
            record["motion_windows"] = []
            for arm in arms:
                snapshots = arm["data"]["publications"]
                width = max(1, len(snapshots)//4)
                record["motion_windows"].append({"phase": arm["phase"],
                    "early_moves": summary([x["moves"] for x in snapshots[:width]]),
                    "late_moves": summary([x["moves"] for x in snapshots[-width:]]),
                    "observed_moving_publications": sum(x["moves"] > 0 for x in snapshots),
                    "total_observed_publications": len(snapshots)})
            record["worst_frames"] = sorted(
                ({**frame, "phase": arm["phase"]} for arm in arms for frame in arm["data"]["frames"]),
                key=lambda x: x["frame_ms"], reverse=True)[:5]
            row["subjects"][subject] = record
        if all(row["subjects"][x]["frames_ms"].get("count") for x in ("A", "B")):
            row["candidate_minus_baseline"] = {}
            for metric in ("p50", "p95", "p99"):
                before = row["subjects"]["A"]["frames_ms"][metric]
                after = row["subjects"]["B"]["frames_ms"][metric]
                row["candidate_minus_baseline"][metric] = {"ms": after-before, "percent": 100*(after-before)/before}
        comparisons.append(row)
    return comparisons


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-repo", type=Path, required=True)
    parser.add_argument("--candidate-repo", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--harness", type=Path, default=ROOT / "godot/tests/run_integrated_camera_performance.gd")
    parser.add_argument("--cases", default="all", help="Comma-separated case IDs, or all")
    parser.add_argument("--samples", type=int, default=180)
    parser.add_argument("--warmup", type=int, default=32)
    parser.add_argument("--order", default="ABBA", choices=("ABBA", "BAAB", "AB", "A", "B"))
    parser.add_argument("--rounds", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("--rendering-driver", default="opengl3_angle" if sys.platform == "win32" else "opengl3")
    parser.add_argument("--skip-import", action="store_true", help="Caller has already imported both exact projects")
    parser.add_argument("--skip-shader-abba", action="store_true", help="Skip the separate historical shader control; useful only for apparatus smoke")
    args = parser.parse_args()
    if args.samples < 4 or args.warmup < 1 or args.rounds < 1:
        parser.error("samples >= 4, warmup >= 1, rounds >= 1 required")
    roots = {"A": args.baseline_repo.resolve(), "B": args.candidate_repo.resolve()}
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    godot = args.godot.resolve()
    version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
    if not version.startswith("4.7.stable"):
        raise ValueError(f"Pinned Godot 4.7 required, found {version}")
    requested = args.cases.split(",")
    cases = [item for item in CASES if args.cases == "all" or item["id"] in requested]
    if not cases or (args.cases != "all" and set(requested) != {item["id"] for item in cases}):
        parser.error("Unknown case: " + args.cases)
    identities = {key: identity(root) for key, root in roots.items()}
    harness = output / "run_integrated_camera_performance.gd"
    shutil.copyfile(args.harness.resolve(), harness)
    report = {"schema": "integrated-camera-abba-v1", "complete": False,
              "subjects": identities, "host": execution_telemetry.host_identity(),
              "engine": {"version": version, "sha256": sha(godot)},
              "apparatus": {"runner_sha256": sha(Path(__file__)), "harness_sha256": sha(harness)},
              "order": args.order, "rounds": args.rounds, "samples_per_phase": args.samples,
              "warmup_per_phase": args.warmup, "cases": cases, "runs": [],
              "limits": ["Software-renderer cohorts do not establish target-PC GPU performance",
                         "Active workloads retain identical starts, but asynchronous simulation can progress by different tick counts",
                         "p99 estimates from bounded cohorts are descriptive, not high-confidence tail guarantees",
                         "Main/shader timers overlap; do not add them", "RSS sampling includes startup and World replacement"]}
    write(output / "report.json", report)
    try:
        if not args.skip_import:
            for subject, root in roots.items():
                folder = output / ("import-"+subject)
                execute([str(godot), "--headless", "--editor", "--path", str(root / "godot"), "--import", "--quit"],
                        root, env_for(folder), folder, args.timeout)
        for config in cases:
            for round_index in range(args.rounds):
                for phase, subject in enumerate(args.order):
                    folder = output / f"{config['id']}-r{round_index}-{phase}-{subject}"
                    folder.mkdir(parents=True, exist_ok=True)
                    env = env_for(folder)
                    full_config = {**config, "samples": args.samples, "warmup": args.warmup}
                    env.update(CYBERSAND_CAMERA_PERF_CASE=json.dumps(full_config),
                               CYBERSAND_CAMERA_PERF_OUTPUT=str(folder / "runtime.json"),
                               CYBERSAND_SOURCE_REVISION=identities[subject]["commit"],
                               CYBERSAND_SHADER_CACHE_STATE="fresh-process; per-phase user cache; project import cache retained")
                    command = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                               "--rendering-driver", args.rendering_driver, "--path", str(roots[subject] / "godot"),
                               "--script", str(harness)]
                    print(f"BEGIN {config['id']} round={round_index} phase={phase} subject={subject}", flush=True)
                    process = execute(command, roots[subject], env, folder, args.timeout)
                    data = json.loads((folder / "runtime.json").read_text(encoding="utf-8"))
                    if not data.get("ok") or data.get("smoke_only") or len(data.get("frames", [])) != args.samples:
                        raise ValueError(f"Incomplete runtime receipt: {folder}")
                    if data["context"]["engine_sha256"] != report["engine"]["sha256"]:
                        raise ValueError(f"Executed engine hash mismatch: {folder}")
                    if data["context"]["process_id"] != process["announced_engine_pid"]:
                        raise ValueError(f"Actual Godot PID mismatch: {folder}")
                    if data["context"]["fixture_sha256"] != report["apparatus"]["harness_sha256"]:
                        raise ValueError(f"Executed external harness mismatch: {folder}")
                    prior = [x for x in report["runs"] if x["case"] == config["id"]]
                    if prior and data["fixture_sha256"] != prior[0]["data"]["fixture_sha256"]:
                        raise ValueError(f"Initial authored fixture changed between subjects: {folder}")
                    if prior and data["initial_material_plane_sha256"] != prior[0]["data"]["initial_material_plane_sha256"]:
                        raise ValueError(f"Initial copied native material plane differs between subjects: {folder}")
                    run = {"case": config["id"], "subject": subject, "round": round_index, "phase": phase,
                           "source_commit": identities[subject]["commit"], "folder": str(folder.relative_to(output)),
                           "data": data, "process": process}
                    report["runs"].append(run)
                    report["comparisons"] = reduce_runs(report["runs"])
                    write(output / "report.json", report)
                    print(f"PASS {config['id']} {subject} p50={data['summary']['frame_ms']['p50']:.3f}ms "
                          f"p95={data['summary']['frame_ms']['p95']:.3f}ms n={len(data['frames'])}", flush=True)
        if not args.skip_shader_abba:
            folder = output / "historical-shader-abba"
            folder.mkdir(parents=True, exist_ok=True)
            env = env_for(folder)
            env.update(CYBERSAND_CAMERA_PACING_EXTENDED="1", CYBERSAND_TEST_ARTIFACT_DIR=str(folder),
                       CYBERSAND_SOURCE_REVISION=identities["B"]["commit"])
            command = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                       "--rendering-driver", args.rendering_driver, "--path", str(roots["B"] / "godot"),
                       "--script", "res://tests/test_native_pixel_scrolling_render.gd"]
            print("BEGIN historical same-source shader-coordinate ABBA", flush=True)
            process = execute(command, roots["B"], env, folder, max(args.timeout, 420))
            data = json.loads((folder / "native-pixel-scrolling-render.json").read_text(encoding="utf-8"))
            pacing = data.get("comparative_pacing", {})
            if data.get("failures") or len(pacing.get("extended_abba", [])) != 4:
                raise ValueError("Historical shader ABBA did not complete all four controlled cohorts")
            if data["context"]["engine_sha256"] != report["engine"]["sha256"]:
                raise ValueError("Historical shader ABBA executed a different engine")
            report["historical_shader_abba"] = {"data": pacing, "process": process,
                                                "scope": "Same-process frozen palette coordinate-only control, separate from exact application A/B"}
            write(output / "report.json", report)
        for subject, root in roots.items():
            if identity(root) != identities[subject]:
                raise ValueError(f"Application/runtime changed during measurement: {subject}")
        report["complete"] = True
        write(output / "report.json", report)
        print(f"INTEGRATED_CAMERA_ABBA_PASS cases={len(cases)} phases={len(report['runs'])}", flush=True)
        return 0
    except BaseException as error:
        report["failure"] = f"{type(error).__name__}: {error}"
        write(output / "report.json", report)
        raise


if __name__ == "__main__":
    raise SystemExit(main())
