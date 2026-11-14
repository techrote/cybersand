#!/usr/bin/env python3
"""RENDER-ACK-002: same-source/host ABBA actual Main/ImageTexture comparison.

One A-B-B-A cycle for each ordinary, delayed and ACK-withheld condition.
The application fixture replays 120 bounded edits, resets once, then drains.
Host performance observations are software-renderer results, not GPU claims.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import time

from analyze_trace import analyze, read_trace
from run_graphical import command, sha, GODOT_PIN, TRACE_PATH

ROOT = Path(__file__).resolve().parents[2]
SUCCESS = re.compile(r"RENDER_COPY_PUBLICATION:\s+arm=([NDW])\s+failures=0")


def quantiles(values: list[int]) -> dict:
    if not values:
        return {"count": 0}
    sorted_values = sorted(values)
    def pct(p: float) -> float:
        at = (len(sorted_values) - 1) * p
        left = int(at)
        frac = at - left
        right = min(left + 1, len(sorted_values) - 1)
        return sorted_values[left] * (1 - frac) + sorted_values[right] * frac
    return {
        "count": len(values),
        "mean": round(statistics.mean(values), 3),
        "p50": round(pct(0.50), 3),
        "p95": round(pct(0.95), 3),
        "p99": round(pct(0.99), 3),
        "max": max(values)
    }


def sum_matching(events: list[dict], name: str, field: str) -> list[int]:
    return [int(row[field]) for row in events
            if row.get("event") == name and type(row.get(field)) is int]


def run_one(godot: Path, runtime: Path, digest: str, out: Path,
            ack_arm: str, policy: str, repetition: int, driver: str,
            timeout: int) -> dict:
    name = f"{ack_arm}-{repetition:02d}-{policy}"
    receipt = out / (name + "-benchmark.json")
    args = [str(godot), "--path", str(ROOT / "godot"),
            "--rendering-driver", driver,
            "--script", "res://tests/bench_render_copy_publication.gd", "--",
            "--receipt=" + str(receipt), "--arm=" + ack_arm,
            "--candidate=" + ("gated" if policy == "gated" else "control"),
            "--render-ack-policy=" + policy,
            "--runtime-sha256=" + digest, "--runtime-path=" + str(runtime),
            "--render-ack-trace"]
    started = time.monotonic()
    proc = subprocess.run(args, cwd=ROOT, capture_output=True,
                          text=True, errors="replace", timeout=timeout,
                          env={**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1"})
    log = proc.stdout + "\n--- stderr ---\n" + proc.stderr
    process_log = out / (name + "-process.log")
    process_log.write_text(log, encoding="utf-8")
    if proc.returncode != 0 or not SUCCESS.search(log) or not receipt.is_file():
        raise RuntimeError(f"{name}: graphical fixture failed; see {process_log}")
    record = json.loads(receipt.read_text(encoding="utf-8"))
    if (record.get("failures") != 0 or record.get("arm") != ack_arm
            or record.get("policy") != policy
            or record.get("accepted_pulses") != 120
            or record.get("post_reset_cells_correct") != 60
            or record.get("final_cpu_native_equal") is not True
            or record.get("final_texture_image_equal") is not True
            or record.get("tail_drained") is not True
            or record.get("display") == "headless"
            or int(record.get("dropped", -1)) != 0
            or int(record.get("counts", {}).get("reject", 0)) != 0):
        raise RuntimeError(f"{name}: final-state/ownership/freshness oracle failed")
    candidates = TRACE_PATH.findall(log)
    if len(candidates) != 1:
        raise RuntimeError(f"{name}: expected exactly one Main ACK trace; got {candidates}")
    trace_source = Path(candidates[0].strip())
    if not trace_source.is_file():
        raise RuntimeError(f"{name}: trace file missing: {trace_source}")
    trace = out / (name + "-trace.jsonl")
    shutil.copyfile(trace_source, trace)
    reduction = analyze(read_trace(trace))
    if not reduction["complete_custody"]:
        raise RuntimeError(f"{name}: bounded trace lost events")
    analysis_path = out / (name + "-analysis.json")
    analysis_path.write_text(json.dumps(reduction, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    events = record.get("events", [])
    times = record.get("frame_usec", [])
    if len(times) != 240:
        raise RuntimeError(f"{name}: incomplete 240-frame measurement")
    packet_bytes = sum_matching(events, "native_end", "packet_bytes")
    native_copy = sum_matching(events, "native_end", "duration_usec")
    owner_copy = sum_matching(events, "owner_end", "duration_usec")
    native_status = reduction["native_status_counts"]
    return {
        "id": name, "arm": ack_arm, "policy": policy,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "source_trace_sha256": sha(trace), "process_log_sha256": sha(process_log),
        "receipt_sha256": sha(receipt), "analysis_sha256": sha(analysis_path),
        "display": record.get("display"), "renderer": record.get("renderer"),
        "adapter": record.get("adapter"), "engine": record.get("engine"),
        "counts": record.get("counts"), "native_status_counts": native_status,
        "native_full_reason_counts": reduction["native_full_reason_counts"],
        "pending_capacity_escalations": reduction["worker_pending_escalation_counts"],
        "accepted_upload_counts": reduction["main_accepted_upload_counts"],
        "worker_ack_latch_delay_usec": reduction["worker_ack_latch_delay_usec"],
        "ack_call_to_worker_receipt_usec": reduction["main_ack_call_to_worker_receipt_usec"],
        "main_upload_duration_usec": reduction["main_upload_duration_usec"],
        "frame_usec": quantiles([int(v) for v in times]),
        "native_packet_bytes": sum(packet_bytes),
        "native_packet_count": len(packet_bytes),
        "native_capture_usec": quantiles(native_copy),
        "owner_publication_usec": quantiles(owner_copy),
        "pending_high_water_bytes": record.get("pending_high_water"),
        "tail_elapsed_usec": record.get("tail_elapsed_usec"),
        "native_cpu_gpu_correct": True,
        "raw_paths": [receipt.name, trace.name, analysis_path.name, process_log.name,
                      (receipt.name + ".png")],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rendering-driver",
                        default="opengl3_angle" if sys.platform == "win32" else "opengl3")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    path = out / "summary.json"
    if path.exists():
        parser.error("Cannot overwrite an earlier campaign")
    result = {
        "schema": "render-ack-policy-graphical-abba-v1",
        "source_sha": None, "complete": False,
        "scope": "Actual Main full ImageTexture.update, native RG8 1024-square and 240-frame paused/reset; software backend not NVIDIA",
        "order": "baseline-gated-gated-baseline per ACK condition",
        "runs": [], "comparisons": {},
    }
    try:
        source = command("git", "rev-parse", "HEAD")
        if source != args.expected_sha:
            raise ValueError(f"exact-head source mismatch {source}")
        result["source_sha"] = source
        godot = args.godot.resolve(strict=True)
        version = command(str(godot), "--version")
        if version != GODOT_PIN:
            raise ValueError(f"pinned Godot mismatch {version}")
        result["godot"] = {"sha256": sha(godot), "version": version}
        platform = "windows" if sys.platform == "win32" else "linux"
        extension = ("cybersand_native.windows.x86_64.dll" if platform == "windows"
                     else "libcybersand_native.linux.x86_64.so")
        runtime = ROOT / "godot/addons/cybersand_native/bin" / extension
        provenance = ROOT / "godot/addons/cybersand_native" / (
            "runtime-provenance.json" if platform == "windows" else "runtime-provenance.linux.json")
        manifest = json.loads(provenance.read_text(encoding="utf-8"))
        digest = sha(runtime)
        if runtime.stat().st_size < 1024 or manifest.get("sha256") != digest:
            raise ValueError("source-matched native runtime/provenance mismatch")
        result["native"] = {"sha256": digest,
                            "source_commit": manifest.get("source_commit")}
        for arm in ("N", "D", "W"):
            for repetition, policy in enumerate(("baseline", "gated", "gated", "baseline"), 1):
                row = run_one(godot, runtime, digest, out, arm, policy, repetition,
                              args.rendering_driver, args.timeout)
                if result["runs"] and row["adapter"] != result["runs"][0]["adapter"]:
                    raise RuntimeError("graphic adapter changed between matched arms")
                result["runs"].append(row)
                print(f"{row['id']}: adapter={row['adapter']}; native bytes={row['native_packet_bytes']}; "
                      f"full={row['native_full_reason_counts']}; "
                      f"overflow={row['pending_capacity_escalations']}", flush=True)
            by_policy: dict[str, list[dict]] = defaultdict(list)
            for row in result["runs"]:
                if row["arm"] == arm:
                    by_policy[row["policy"]].append(row)
            baseline = by_policy["baseline"]
            gated = by_policy["gated"]
            result["comparisons"][arm] = {
                "baseline_native_bytes": [r["native_packet_bytes"] for r in baseline],
                "gated_native_bytes": [r["native_packet_bytes"] for r in gated],
                "baseline_frame_p95_usec": [r["frame_usec"]["p95"] for r in baseline],
                "gated_frame_p95_usec": [r["frame_usec"]["p95"] for r in gated],
                "baseline_full_snapshots": [sum(r["native_full_reason_counts"].values()) for r in baseline],
                "gated_full_snapshots": [sum(r["native_full_reason_counts"].values()) for r in gated],
                "baseline_pending_escalations": [sum(r["pending_capacity_escalations"].values()) for r in baseline],
                "gated_pending_escalations": [sum(r["pending_capacity_escalations"].values()) for r in gated],
            }
        negative = result["comparisons"]["W"]
        if (not all(n > 0 for n in negative["baseline_pending_escalations"])
                or any(n != 0 for n in negative["gated_pending_escalations"])
                or not all(g < b for g, b in zip(
                    negative["gated_full_snapshots"], negative["baseline_full_snapshots"]))
                or not all(g < b for g, b in zip(
                    negative["gated_native_bytes"], negative["baseline_native_bytes"]))):
            raise RuntimeError("Withheld ACK negative-control causality or reduction not established")
        result["complete"] = True
    except Exception as error:
        result["error"] = f"{type(error).__name__}: {error}"
        print(result["error"], file=sys.stderr, flush=True)
    finally:
        path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0 if result["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
