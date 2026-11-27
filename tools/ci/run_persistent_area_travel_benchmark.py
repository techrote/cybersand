#!/usr/bin/env python3
"""Controlled zero-debt donor/successor cold travel with real process telemetry."""
from __future__ import annotations
import argparse
import ctypes
import json
import math
import os
import platform
from pathlib import Path
import subprocess
import sys
import time
from run_persistent_areas_qualification import ERRORS, ProcessMemory, cpu_seconds, direct_engine, sha, source_identity, write


def process_io(process: subprocess.Popen) -> dict:
    try:
        if os.name != "nt":
            return {k: int(v) for k, v in (line.split(": ") for line in Path(f"/proc/{process.pid}/io").read_text().splitlines())}
        class Counters(ctypes.Structure):
            _fields_ = [(name, ctypes.c_ulonglong) for name in (
                "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
                "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]
        counters = Counters()
        function = ctypes.windll.kernel32.GetProcessIoCounters
        function.argtypes = [ctypes.c_void_p, ctypes.POINTER(Counters)]
        if function(int(process._handle), ctypes.byref(counters)):
            return {name: int(getattr(counters, name)) for name, _ in counters._fields_}
    except (OSError, ValueError):
        pass
    return {}


def run(args: argparse.Namespace) -> dict:
    output, project = args.output.resolve(), args.project.resolve()
    output.mkdir(parents=True, exist_ok=False)
    engine = direct_engine(args.godot, sys.platform)
    script = Path(__file__).with_name("benchmark_persistent_area_travel.gd")
    native = project/"addons/cybersand_native/bin"/("cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
    before = source_identity(project)
    if before["source_commit"] != args.expected_source or sha(native) != args.expected_native:
        raise RuntimeError("Benchmark source/native identity differs from explicit admission")
    if not args.diagnostic and (before["local_delta"] or before["missing_source_inputs"]):
        raise RuntimeError("Controlled benchmark needs clean complete project source")
    env = dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1", XDG_DATA_HOME=str(output/"userdata"),
        APPDATA=str(output/"userdata"), LOCALAPPDATA=str(output/"localdata"))
    identity = {"native_sha256": sha(native), "godot_sha256": sha(engine), "harness_sha256": sha(Path(__file__)), "script_sha256": sha(script)}
    report = {"schema": "gen006-ramcache-travel-benchmark-v1", "source_before": before, **identity,
        "diagnostic": args.diagnostic, "graphical": not args.headless, "samples": [], "status": "running",
        "hardware": {"platform": platform.platform(), "processor": platform.processor(), "logical_cpus": os.cpu_count()},
        "process_io_scope": "Whole engine process including resources/logs; not attributed profile checkpoint I/O"}
    if args.expected_source == "d0d043f4740ffed5f0dbb4120e437458d7a9bd57":
        provenance = json.loads((project/"addons/cybersand_native"/("runtime-provenance.json" if os.name == "nt" else "runtime-provenance.linux.json")).read_text())
        if provenance.get("sha256") != args.expected_native or provenance.get("source_commit") != "1ceac7e3d4d9e9f6b24833ced340286a4a15d01e" \
                or not provenance.get("source_inputs") or any(before["source_inputs_sha256"].get(path) != digest
                    for path, digest in provenance["source_inputs"].items()):
            raise RuntimeError("Donor retained binary does not match its qualified product inputs")
        report["donor_runtime_provenance"] = provenance
    process = None
    started = time.monotonic()
    try:
        imported = subprocess.run([str(engine), "--headless", "--path", str(project), "--editor", "--import", "--quit"],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        (output/"import.log").write_bytes(imported.stdout)
        if imported.returncode or ERRORS.search(imported.stdout.decode(errors="replace")):
            raise RuntimeError("Benchmark project import failed")
        command = [str(engine), "--path", str(project), "--audio-driver", "Dummy"]
        command += ["--headless"] if args.headless else ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]
        command += ["--script", str(script), "--", "--persistent-start-paused", "--persistent-cache-off",
            f"--persistent-profile={output/'profile'}", f"--baseline-output={output/'travel.json'}",
            f"--baseline-workers={args.workers}", f"--baseline-samples={args.samples}"]
        report["command"] = command
        with (output/"execution.log").open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(command, cwd=output, env=env, stdout=stream, stderr=subprocess.STDOUT)
            report["pid"] = process.pid
            memory = ProcessMemory(process)
            while process.poll() is None:
                sample = memory.sample()
                report["samples"].append({"elapsed_s": time.monotonic()-started,
                    "rss_bytes": sample[0] if sample else None, "peak_rss_bytes": sample[1] if sample else None,
                    "cpu_seconds": cpu_seconds(process), "process_io": process_io(process)})
                if time.monotonic()-started > 1800:
                    raise TimeoutError("Controlled cold travel exceeded its bounded process watchdog")
                time.sleep(0.02)
        report["exit_code"] = process.returncode
        receipt = json.loads((output/"travel.json").read_text())
        text = (output/"execution.log").read_text(errors="replace")
        if process.returncode or ERRORS.search(text) or receipt.get("passed") is not True or receipt.get("pid") != process.pid:
            raise RuntimeError("Actual controlled travel process or bound receipt failed")
        if not args.headless and (receipt.get("graphics") in (None, "", "headless") or not receipt.get("renderer")
                or receipt.get("rendering_method") != "gl_compatibility"):
            raise RuntimeError("Requested graphical benchmark lacks actual renderer observations")
        travels = [row for row in receipt["rows"] if row["kind"] == "travel"]
        if len(travels) != args.samples or any(row["game_tick"] != 0 or row["native_tick"] != 0 for row in travels):
            raise RuntimeError("Cold baseline workload performed unaccounted native progression")
        values = sorted(float(row["elapsed_ms"]) for row in travels)
        n = len(values)
        report["statistics"] = {"samples": n, "p50_ms": (values[(n-1)//2]+values[n//2])/2,
            "p95_ms": values[math.ceil(n*0.95)-1], "worst_ms": values[-1],
            "maximum_correlated_main_frame_ms": max(row["max_frame_gap_ms"] for row in travels)}
        report["receipt"] = receipt
        report["source_after"] = source_identity(project)
        report["source_unchanged"] = before == report["source_after"]
        report["binaries_unchanged"] = sha(native) == identity["native_sha256"] and sha(engine) == identity["godot_sha256"]
        report["harness_unchanged"] = sha(script) == identity["script_sha256"] and sha(Path(__file__)) == identity["harness_sha256"]
        if not all(report[key] for key in ("source_unchanged", "binaries_unchanged", "harness_unchanged")):
            raise RuntimeError("Source, runtime or benchmark changed during execution")
        report["status"] = "passed"
    except Exception as error:
        report.update(status="failed", error=str(error))
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait(timeout=15)
        report["elapsed_s"] = time.monotonic()-started
        write(output/"benchmark.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--expected-native", required=True)
    parser.add_argument("--workers", type=int, choices=(1, 4), default=1)
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--diagnostic", action="store_true")
    args = parser.parse_args()
    if not 1 <= args.samples <= 100: parser.error("samples must be bounded from 1 to 100")
    report = run(args)
    print(json.dumps({key: report.get(key) for key in ("status", "statistics", "error")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
