#!/usr/bin/env python3
"""Read ENGINE-LAB pose-frame JSONL; attribute jumps without changing gameplay."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from math import hypot
from pathlib import Path
import sys


def vector_gap(a, b):
    if not isinstance(a, list) or not isinstance(b, list) or len(a) != 2 or len(b) != 2:
        return None
    return hypot(float(a[0]) - float(b[0]), float(a[1]) - float(b[1]))


def read_trace(path: Path):
    with path.open(encoding="utf-8") as stream:
        records = [json.loads(line) for line in stream if line.strip()]
    if len(records) < 3 or records[0].get("type") != "header" or records[-1].get("type") != "summary":
        raise ValueError("Incomplete ENGINE-LAB pose trace")
    if records[0].get("schema") != "cybersand-pose-trace-v1":
        raise ValueError("Unsupported trace schema")
    frames = records[1:-1]
    if any(r.get("type") != "frame" for r in frames):
        raise ValueError("Unexpected trace record type")
    if any(int(b.get("truncated_bodies", 0)) > 0 for b in frames):
        raise ValueError("Cannot attribute traces with truncated actors")
    count = int(records[-1].get("frames", -1))
    if len(frames) != count:
        raise ValueError("Trace frame count mismatch")
    return records[0], frames, records[-1]


def analyze(frames: list[dict], threshold_px: float = 8.0):
    if threshold_px <= 0:
        raise ValueError("Threshold must be positive")
    events = []
    last = {}
    source_count = Counter()
    mode_count = Counter()
    projection_errors = 0
    phase_jumps = 0
    largest_projection_residual_px = 0.0
    for frame in frames:
        number = int(frame.get("process_frame", -1))
        time_usec = int(frame.get("time_usec", -1))
        mode_count[str(frame.get("camera_mode", "?"))] += 1
        for body in frame.get("bodies", []):
            slot = int(body.get("slot", -1))
            source = str(body.get("source", "hidden"))
            source_count[source] += 1
            selected = body.get("selected_screen")
            if not isinstance(selected, list) or len(selected) != 2:
                last.pop(slot, None)
                continue
            proj = body.get("screen_selected")
            residual = float(proj.get("residual_magnitude_px", 0.0)) if isinstance(proj, dict) else 0.0
            largest_projection_residual_px = max(largest_projection_residual_px, residual)
            if residual > 1.0:
                projection_errors += 1
            prior = last.get(slot)
            if prior:
                step = vector_gap(selected, prior["selected"])
                camera_step = vector_gap(frame.get("camera_presented"), prior["camera"])
                phase = vector_gap(frame.get("camera_screen_phase_px"), prior["phase"])
                switched = prior["source"] != source
                lag = vector_gap(body.get("live_screen"), body.get("bound_screen"))
                if phase is not None and phase > 2.0:
                    phase_jumps += 1
                if (step is not None and step >= threshold_px) or switched or residual > 1.0:
                    if residual > 1.0:
                        cause = "spatial_projection_mismatch"
                    elif switched:
                        cause = "live_vs_bound_source_switch"
                    elif phase is not None and phase > 2.0:
                        cause = "camera_screen_phase_jump"
                    elif source == "mask_bound" and lag is not None and lag > threshold_px:
                        cause = "stale_mask_bound_pose"
                    else:
                        cause = "not_attributed"
                    events.append({
                        "frame": number, "time_usec": time_usec, "slot": slot,
                        "source": source, "prior_source": prior["source"],
                        "screen_jump_px": round(step, 3) if step is not None else None,
                        "camera_world_shift": round(camera_step, 3) if camera_step is not None else None,
                        "phase_jump_px": round(phase, 3) if phase is not None else None,
                        "live_bound_gap_px": round(lag, 3) if lag is not None else None,
                        "projection_residual_px": round(residual, 3),
                        "guard_reason": body.get("guard_reason"),
                        "cause": cause,
                    })
            last[slot] = {"selected": selected, "source": source,
                          "camera": frame.get("camera_presented"),
                          "phase": frame.get("camera_screen_phase_px")}
    ranked = sorted(events, key=lambda row: row.get("screen_jump_px") or 0, reverse=True)
    return {
        "frames": len(frames), "events": len(events),
        "camera_modes": dict(mode_count),
        "pose_sources": dict(source_count),
        "projection_residual_over_1px": projection_errors,
        "max_projection_residual_px": round(largest_projection_residual_px, 4),
        "camera_phase_jumps_over_2px": phase_jumps,
        "event_causes": dict(Counter(event["cause"] for event in events)),
        "largest_events": ranked,
        "interpretation": (
            "A spatial projection mismatch means the recorded overlay and shader use "
            "different screen transforms. A source switch or bound-pose lag indicates "
            "temporal incoherence. Neither result by itself proves actual GPU presentation timing."
        ),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="engine-lab-pose-*.jsonl")
    parser.add_argument("--threshold-px", type=float, default=8.0)
    parser.add_argument("--top", type=int, default=20)
    parser.add_argument("--output", type=Path, help="write full JSON analysis")
    args = parser.parse_args(argv)
    header, frames, footer = read_trace(args.trace)
    report = analyze(frames, args.threshold_px)
    report["capture_settings"] = header.get("settings")
    report["dropped_frames"] = footer.get("dropped", 0)
    report["duplicate_callback_frames"] = footer.get("duplicates", 0)
    report["capture_duration_seconds"] = footer.get("elapsed_seconds")
    report["largest_events"] = report["largest_events"][:max(0, args.top)]
    result = json.dumps(report, indent=2)
    if args.output:
        args.output.write_text(result + "\n", encoding="utf-8")
        print(f"Saved {args.output}")
    else:
        print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
