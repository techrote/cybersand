#!/usr/bin/env python3
"""Source-matched graphical Main/ImageTexture trace; N normal ACK, W withheld ACK."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from analyze_trace import analyze, read_trace

ROOT = Path(__file__).resolve().parents[2]
GODOT_PIN = "4.7.stable.official.5b4e0cb0f"
TRACE_PATH = re.compile(r"^RENDER_ACK_TRACE_PATH\s+(.+?)\s*$", re.M)
SUCCESS = re.compile(r"RENDER_COPY_PUBLICATION:\s+arm=(N|W)\s+failures=0")

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def command(*args: str) -> str:
    return subprocess.check_output(list(args), cwd=ROOT, text=True, stderr=subprocess.PIPE, timeout=30).strip()

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", type=Path, required=True)
    p.add_argument("--expected-sha", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--rendering-driver", default="opengl3_angle" if sys.platform == "win32" else "opengl3")
    p.add_argument("--timeout", type=int, default=600)
    args = p.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    summary = out / "summary.json"
    if summary.exists():
        p.error("Refusing to overwrite retained graphical evidence")
    report: dict = {"schema":"render-ack-graphical-v1", "ok":False,
                    "expected_sha":args.expected_sha, "arms":{},
                    "scope":"Real graphical Main/ImageTexture; virtual/software adapter is not hardware GPU"}
    try:
        got_sha = command("git","rev-parse","HEAD")
        if got_sha != args.expected_sha: raise ValueError("Exact source SHA mismatch: "+got_sha)
        report["source_sha"] = got_sha
        godot = args.godot.resolve(strict=True)
        version = command(str(godot),"--version")
        if version != GODOT_PIN: raise ValueError("Pinned Godot version mismatch: "+version)
        report["godot"] = {"version":version,"path":str(godot),"sha256":sha(godot)}
        platform = "windows" if sys.platform == "win32" else "linux"
        extension = ("cybersand_native.windows.x86_64.dll" if platform == "windows"
                     else "libcybersand_native.linux.x86_64.so")
        runtime = ROOT / "godot" / "addons" / "cybersand_native" / "bin" / extension
        provenance_path = ROOT / "godot" / "addons" / "cybersand_native" / (
            "runtime-provenance.json" if platform == "windows" else "runtime-provenance.linux.json")
        manifest = json.loads(provenance_path.read_text(encoding="utf-8"))
        digest = sha(runtime)
        if runtime.stat().st_size < 1024 or digest != manifest["sha256"]:
            raise ValueError("Native runtime fails source-matched provenance")
        report["native"] = {"path":str(runtime),"sha256":digest,"source_commit":manifest.get("source_commit")}
        for arm in ("N","W"):
            result_file = out / (arm+"-benchmark.json")
            godot_args = [str(godot),"--path",str(ROOT/"godot"),"--rendering-driver",
                args.rendering_driver,"--script","res://tests/bench_render_copy_publication.gd","--",
                "--receipt="+str(result_file),"--arm="+arm,"--candidate=control",
                "--runtime-sha256="+digest,"--runtime-path="+str(runtime),"--render-ack-trace"]
            started = time.monotonic()
            process = subprocess.run(godot_args,cwd=ROOT,capture_output=True,text=True,
                                     errors="replace",timeout=args.timeout,
                                     env={**os.environ,"GODOT_SILENCE_ROOT_WARNING":"1"})
            log = process.stdout+"\n--- stderr ---\n"+process.stderr
            log_file = out / (arm+"-process.log")
            log_file.write_text(log,encoding="utf-8")
            arm_result = {"exit_code":process.returncode,
                "elapsed_seconds":round(time.monotonic()-started,3),
                "process_log_sha256":sha(log_file)}
            report["arms"][arm] = arm_result
            if process.returncode or not SUCCESS.search(log) or not result_file.exists():
                raise RuntimeError(f"Graphical Main benchmark {arm} failed; see {log_file}")
            benchmark = json.loads(result_file.read_text(encoding="utf-8"))
            if (benchmark.get("failures") != 0 or benchmark.get("arm") != arm
                    or benchmark.get("final_cpu_native_equal") is not True
                    or benchmark.get("final_texture_image_equal") is not True
                    or benchmark.get("tail_drained") is not True):
                raise RuntimeError(f"Graphical Main benchmark {arm} failed exact-state oracle")
            candidates = TRACE_PATH.findall(log)
            if len(candidates) != 1:
                raise RuntimeError(f"Exactly one Main trace required, arm {arm}: {candidates}")
            actual_trace = Path(candidates[0].strip())
            if not actual_trace.is_file():
                raise RuntimeError("Expected Godot trace file missing: "+str(actual_trace))
            trace = out / (arm+"-trace.jsonl")
            shutil.copyfile(actual_trace,trace)
            reduction = analyze(read_trace(trace))
            reduced_path = out / (arm+"-analysis.json")
            reduced_path.write_text(json.dumps(reduction,indent=2,sort_keys=True)+"\n",encoding="utf-8")
            arm_result.update({"adapter":benchmark.get("adapter"),"display":benchmark.get("display"),
                "renderer":benchmark.get("renderer"),"accepted_pulses":benchmark.get("accepted_pulses"),
                "native_final_equal":benchmark.get("final_cpu_native_equal"),
                "texture_final_equal":benchmark.get("final_texture_image_equal"),
                "trace_sha256":sha(trace),"analysis_sha256":sha(reduced_path),
                "trace_complete":reduction["complete_custody"],
                "native_full_reason_counts":reduction["native_full_reason_counts"],
                "worker_pending_escalation_counts":reduction["worker_pending_escalation_counts"],
                "main_accepted_upload_counts":reduction["main_accepted_upload_counts"],
                "main_upload_duration_usec":reduction["main_upload_duration_usec"]})
            if not reduction["complete_custody"]:
                raise RuntimeError("Trace event ring overflow; cause counts nonexhaustive")
            print(f"{arm}: {arm_result['elapsed_seconds']}s, {arm_result['adapter']}, "
                  f"full={arm_result['native_full_reason_counts']}, "
                  f"pending={arm_result['worker_pending_escalation_counts']}",flush=True)
        report["ok"] = True
    except Exception as error:
        report["error"] = type(error).__name__+": "+str(error)
        print(report["error"],file=sys.stderr,flush=True)
    finally:
        summary.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    return 0 if report["ok"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
