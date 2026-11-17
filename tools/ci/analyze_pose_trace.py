#!/usr/bin/env python3
"""Analyze original POSE-TRACE frames/events without changing gameplay.

All rates use measured monotonic timestamps. A Main submission, frame_post_draw,
texture.update return, and physical display presentation are different events;
this tool never substitutes one for another. Legacy v1 frame-only traces remain
readable, but cannot supply exact native/Rapier completion intervals.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
from collections import Counter
import csv
import json
from math import hypot, isfinite
from pathlib import Path
import statistics
import sys


def vector(value):
    if isinstance(value, list) and len(value) == 2:
        try:
            result = [float(value[0]), float(value[1])]
            return result if all(map(isfinite, result)) else None
        except (TypeError, ValueError):
            pass
    return None


def vector_gap(a, b):
    a, b = vector(a), vector(b)
    return hypot(a[0] - b[0], a[1] - b[1]) if a is not None and b is not None else None


def subtract(a, b):
    a, b = vector(a), vector(b)
    return [a[0] - b[0], a[1] - b[1]] if a is not None and b is not None else None


def number(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool) and isfinite(value):
        return float(value)
    return None


def distribution(values):
    values = sorted(float(x) for x in values if number(x) is not None)
    if not values:
        return {"count": 0, "minimum": None, "median": None, "p95": None,
                "p99": None, "maximum": None, "mean": None}

    def quantile(fraction):
        index = (len(values) - 1) * fraction
        low = int(index)
        high = min(low + 1, len(values) - 1)
        return round(values[low] + (values[high] - values[low]) * (index - low), 6)

    return {"count": len(values), "minimum": round(values[0], 6),
            "median": quantile(.5), "p95": quantile(.95), "p99": quantile(.99),
            "maximum": round(values[-1], 6), "mean": round(statistics.mean(values), 6)}


def read_trace(path: Path):
    with path.open(encoding="utf-8-sig") as stream:
        records = [json.loads(line) for line in stream if line.strip()]
    if len(records) < 3 or records[0].get("type") != "header" or records[-1].get("type") != "summary":
        raise ValueError("Incomplete ENGINE-LAB pose trace")
    if records[0].get("schema") != "cybersand-pose-trace-v1":
        raise ValueError("Unsupported trace schema")
    frames, events = [], []
    for row in records[1:-1]:
        if row.get("type") == "frame":
            frames.append(row)
        elif row.get("type") == "event" and isinstance(row.get("event"), str):
            events.append(row)
        else:
            raise ValueError("Unexpected trace record type")
    if any(int(b.get("truncated_bodies", 0)) > 0 for b in frames):
        raise ValueError("Cannot attribute traces with truncated actors")
    if len(frames) != int(records[-1].get("frames", -1)):
        raise ValueError("Trace frame count mismatch")
    for before, after in zip(frames, frames[1:]):
        if int(after.get("process_frame", -1)) <= int(before.get("process_frame", -1)):
            raise ValueError("Main process frames must be strictly increasing")
        if int(after.get("time_usec", -1)) <= int(before.get("time_usec", -1)):
            raise ValueError("Main frame timestamps must be strictly increasing")
    validate_capture_identity(frames, events)
    footer = dict(records[-1])
    # Preserve read_trace's original 3-result API. These are the exact event
    # records, not resampled or inferred native/physics data.
    footer["_events"] = events
    return records[0], frames, footer


def validate_capture_identity(frames, events):
    """One trace's rate counters must refer to one World/actor lifetime."""
    cohorts = {
        "uploaded World generation": [r.get("uploaded_world_generation") for r in frames],
        "mask session": [r.get("mask_session") for r in frames if r.get("mask_receipt_render_valid", True)],
        "mask epoch": [r.get("mask_epoch") for r in frames if r.get("mask_receipt_render_valid", True)],
        "event World generation": [r.get("world_generation") for r in events],
        "Rapier event epoch": [r.get("epoch") for r in events if r.get("event") == "rapier_step"],
        "Rapier event session": [r.get("session") for r in events if r.get("event") == "rapier_step"],
    }
    for label, values in cohorts.items():
        known = {int(v) for v in values if number(v) is not None and v >= 0}
        if len(known) > 1:
            raise ValueError(f"Mixed {label} in one capture; split at owner/reset boundary before comparing rates")


def event_time(row):
    value = number(row.get("time_usec", row.get("completed_usec")))
    return value if value is not None and value >= 0 else None


def event_records(events, kind, identity=None):
    rows = [x for x in events if x.get("event") == kind and event_time(x) is not None]
    rows.sort(key=event_time)
    for row in rows:
        if number(row.get("start_usec")) is not None and row["start_usec"] > event_time(row):
            raise ValueError(f"Completion precedes start in {kind}")
    if identity is None:
        return rows
    seen, result = set(), []
    for row in rows:
        key = row.get(identity)
        if key is None or key in seen:
            continue
        seen.add(key)
        result.append(row)
    return result


def measured_rate(times):
    times = sorted(t for t in times if number(t) is not None)
    intervals = [float(b - a) / 1000 for a, b in zip(times, times[1:])]
    duration = (times[-1] - times[0]) / 1e6 if len(times) > 1 else 0
    return {"observations": len(times), "elapsed_seconds": round(duration, 6),
            "hz": round((len(times) - 1) / duration, 6) if duration > 0 else None,
            "interval_ms": distribution(intervals)}


def completed_rate(rows, identity):
    result = measured_rate([event_time(row) for row in rows])
    result["completed_delta"] = None
    result["unrecorded_completions"] = 0
    if len(rows) > 1:
        counters = [int(row[identity]) for row in rows]
        if any(b <= a for a, b in zip(counters, counters[1:])):
            raise ValueError(f"Completed {identity} ordering disagrees with timestamps")
        delta = counters[-1] - counters[0]
        result["completed_delta"] = delta
        result["unrecorded_completions"] = delta - (len(rows) - 1)
        elapsed = (event_time(rows[-1]) - event_time(rows[0])) / 1e6
        result["hz"] = round(delta / elapsed, 6) if elapsed > 0 else None
    return result


def analyze_physics_progress(frames, events):
    """Completed physics time is independent of the selected visual source.

    A still-authoritative live pose can be submitted many times while a native
    or terrain gate prevents the next physical step. Report those gaps even
    when the presentation contract has no holds or source reversals.
    """
    steps = event_records(events, "rapier_step", "step")
    holds = event_records(events, "rapier_hold")
    hold_times = [event_time(row) for row in holds]
    main_times = sorted(float(row["time_usec"]) for row in frames
                        if number(row.get("time_usec")) is not None)
    intervals, skipped = [], 0
    for previous, current in zip(steps, steps[1:]):
        if int(current["step"]) != int(previous["step"]) + 1:
            # Missing completion events cannot prove how long one step waited.
            skipped += 1
            continue
        start, end = event_time(previous), event_time(current)
        between = holds[bisect_right(hold_times, start):bisect_right(hold_times, end)]
        reasons = Counter(row.get("reason", "unknown") for row in between)
        work_start = number(current.get("start_usec"))
        interval = {
            "previous_step": previous["step"], "step": current["step"],
            "start_usec": start, "end_usec": end, "gap_ms": (end-start)/1000,
            "hold_reasons": dict(reasons), "includes_pause": "paused" in reasons,
            "main_submissions": bisect_right(main_times, end)-bisect_right(main_times, start),
            "step_work_ms": (end-work_start)/1000 if work_start is not None else None,
        }
        for field in ("solver_usec", "flush_usec"):
            value = number(current.get(field))
            interval[field.replace("_usec", "_ms")] = value/1000 if value is not None else None
        intervals.append(interval)
    active = [row for row in intervals if not row["includes_pause"]]
    known_frames = [(row.get("rapier_step"), bool(row.get("paused", False))) for row in frames
                    if number(row.get("rapier_step")) is not None]
    unchanged = sum(a[0] == b[0] and not a[1] and not b[1]
                    for a, b in zip(known_frames, known_frames[1:]))
    return {
        "consecutive_step_intervals": len(intervals),
        "unmeasured_intervals_with_missing_completions": skipped,
        "pause_spanning_intervals": len(intervals)-len(active),
        "active_completed_step_gap_ms": distribution([row["gap_ms"] for row in active]),
        "active_gaps_at_least_50ms": sum(row["gap_ms"] >= 50 for row in active),
        "active_gaps_at_least_100ms": sum(row["gap_ms"] >= 100 for row in active),
        "active_gaps_at_least_250ms": sum(row["gap_ms"] >= 250 for row in active),
        "active_gaps_at_least_1000ms": sum(row["gap_ms"] >= 1000 for row in active),
        "main_intervals_without_physics_progress": unchanged,
        "observed_main_intervals": max(0, len(known_frames)-1),
        "step_work_ms": distribution([(event_time(row)-float(row["start_usec"]))/1000
                                      for row in steps if number(row.get("start_usec")) is not None]),
        "solver_ms": distribution([float(row["solver_usec"])/1000 for row in steps
                                   if number(row.get("solver_usec")) is not None]),
        "flush_ms": distribution([float(row["flush_usec"])/1000 for row in steps
                                  if number(row.get("flush_usec")) is not None]),
        "largest_active_gaps": sorted(active, key=lambda row: row["gap_ms"], reverse=True)[:10],
        "meaning": "Wall-clock physical completions, separate from visual pose holds. "
                   "Hold reasons are observed gates, not complete causal attribution. "
                   "Step/solver timers include possible OS descheduling; no GPU scanout is measured.",
    }


def observed_counter_rate(frames, field):
    rows = [(number(x.get("time_usec")), number(x.get(field))) for x in frames]
    rows = [(t, c) for t, c in rows if t is not None and c is not None and c >= 0]
    if len(rows) < 2:
        return {"counter": field, "observations": len(rows), "completed_delta": None,
                "hz": None, "meaning": "Counter changes observed at Main callbacks; not completion timestamps"}
    first, last = rows[0], rows[-1]
    if any(b[1] < a[1] for a, b in zip(rows, rows[1:])):
        raise ValueError(f"Counter {field} moved backwards within one trace")
    seconds = (last[0] - first[0]) / 1e6
    return {"counter": field, "observations": len(rows), "completed_delta": int(last[1] - first[1]),
            "elapsed_seconds": round(seconds, 6),
            "hz": round((last[1] - first[1]) / seconds, 6) if seconds > 0 else None,
            "meaning": "Counter changes observed at Main callbacks; not completion timestamps"}


def independent_projection(frame, body):
    """Recompute the recorded intended projection, without trusting its residual."""
    pose = body.get("selected")
    at = vector(pose.get("xy")) if isinstance(pose, dict) else None
    bx, by = vector(frame.get("shader_basis_x")), vector(frame.get("shader_basis_y"))
    origin = vector(frame.get("shader_world_zero_screen_px"))
    if any(x is None for x in [at, bx, by, origin]):
        return None
    expected = [origin[i] + bx[i] * at[0] + by[i] * at[1] for i in range(2)]
    return vector_gap(body.get("selected_screen"), expected)


def actor_centre_inside_content(frame, point):
    point = vector(point)
    origin = vector(frame.get("screen_transform_origin"))
    bx, by = vector(frame.get("screen_basis_x")), vector(frame.get("screen_basis_y"))
    rect = frame.get("content_rect")
    if point is None or any(v is None for v in [origin, bx, by]) or not isinstance(rect, list) or len(rect) != 4:
        return None
    # Transform the point back to content-local space, including nonzero
    # viewport origin and nonuniform scale. Report centre visibility only.
    determinant = bx[0] * by[1] - bx[1] * by[0]
    if abs(determinant) < 1e-12:
        return None
    relative = [point[i] - origin[i] for i in range(2)]
    local = [(relative[0] * by[1] - relative[1] * by[0]) / determinant,
             (bx[0] * relative[1] - bx[1] * relative[0]) / determinant]
    return rect[0] <= local[0] < rect[0] + rect[2] and rect[1] <= local[1] < rect[1] + rect[3]


def _ages(frames, timestamp):
    values = []
    for row in frames:
        now, then = number(row.get("time_usec")), number(row.get(timestamp))
        if now is not None and then is not None and then > 0 and now >= then:
            values.append((now - then) / 1000)
    return distribution(values)


def presentation_identity(frame, body):
    """A selected time is comparable only within the same actor lifetime."""
    contract = frame.get("presentation", {})
    return (contract.get("session", frame.get("mask_session")),
            contract.get("epoch", frame.get("mask_epoch")),
            contract.get("world_generation", frame.get("uploaded_world_generation")),
            body.get("instance_id"), body.get("generation"))


def analyze_presentation_contract(frames):
    """Analyze explicit source time, independently of physical motion direction.

    A real rebound or teleport can reverse spatial motion while simulation time
    advances. Only a decreasing selected step within one uninterrupted actor
    lifetime is a source rewind. Legacy traces have no selected-step proof and
    retain their existing spatial/source-change diagnostics without inventing it.
    """
    previous, known_steps, rewinds, holds, lag_steps = {}, {}, [], [], []
    source_changes, reasons, policies = Counter(), Counter(), Counter()
    follow_residuals, follow_screen_residuals, resolve_costs = [], [], []
    known = unknown_visible = intentional = withheld = resets = follow_observations = 0
    hold_starts = {}
    for frame in frames:
        contract = frame.get("presentation", {})
        policies[str(contract.get("policy", "unrecorded"))] += 1
        cost = number(contract.get("resolve_usec"))
        if cost is not None and cost >= 0:
            resolve_costs.append(cost / 1000)
        now = number(frame.get("time_usec"))
        follow_id = contract.get("follow_instance_id", frame.get("pilot_instance_id"))
        follow_at = vector(contract.get("follow_position"))
        for body in frame.get("bodies", []):
            slot = int(body.get("slot", -1))
            identity = presentation_identity(frame, body)
            step = number(body.get("presentation_step"))
            desired = number(body.get("desired_step", frame.get("rapier_step")))
            # The resolver's negative sentinel means provenance is unknown,
            # not an earlier valid simulation step.
            step = step if step is not None and step >= 0 else None
            desired = desired if desired is not None and desired >= 0 else None
            source = str(body.get("source", "hidden"))
            reason = str(body.get("source_reason", body.get("guard_reason", "unrecorded")))
            reasons[reason] += 1
            reset = bool(body.get("timeline_reset", False))
            prior = previous.get(slot)
            known_prior = known_steps.get(slot)
            previous_identity = prior["identity"] if prior else known_prior["identity"] if known_prior else None
            if reset or (previous_identity is not None and previous_identity != identity):
                resets += 1
                if slot in hold_starts:
                    started, last_held = hold_starts.pop(slot)
                    holds.append((last_held - started) / 1000)
                prior = None
                known_prior = None
                previous.pop(slot, None)
                known_steps.pop(slot, None)
            held = bool(body.get("intentional_hold", False))
            intentional += int(held)
            selected = body.get("selected")
            selected_at = vector(selected.get("xy")) if isinstance(selected, dict) else None
            if selected_at is None:
                withheld += 1
                previous.pop(slot, None)
                if slot in hold_starts:
                    started, last_held = hold_starts.pop(slot)
                    holds.append((last_held - started) / 1000)
                continue
            if step is not None:
                known += 1
                if desired is not None:
                    lag_steps.append(desired-step)
                if known_prior is not None and step < known_prior["step"]-1e-6:
                    rewinds.append({"frame": frame.get("process_frame"), "time_usec": now,
                                    "slot": slot, "prior_step": known_prior["step"], "selected_step": step,
                                    "backward_steps": known_prior["step"]-step,
                                    "prior_source": known_prior["source"], "source": source,
                                    "source_reason": reason})
                known_steps[slot] = {"identity": identity, "step": step, "source": source}
            else:
                unknown_visible += 1
            if prior is not None and prior["source"] != source:
                source_changes[prior["source"] + "->" + source] += 1
            if held and now is not None:
                started = hold_starts.get(slot, (prior["time"] if prior and prior["time"] is not None else now, now))[0]
                hold_starts[slot] = (started, now)
            elif slot in hold_starts:
                started, last_held = hold_starts.pop(slot)
                holds.append((last_held-started) / 1000)
            if follow_at is not None and body.get("instance_id") == follow_id:
                follow_observations += 1
                gap = vector_gap(follow_at, selected_at)
                follow_residuals.append(gap)
                bx, by = vector(frame.get("shader_basis_x")), vector(frame.get("shader_basis_y"))
                if bx is not None and by is not None:
                    delta = subtract(follow_at, selected_at)
                    follow_screen_residuals.append(hypot(bx[0]*delta[0]+by[0]*delta[1],
                                                        bx[1]*delta[0]+by[1]*delta[1]))
            previous[slot] = {"identity": identity, "step": step, "source": source, "time": now}
    for started, last_held in hold_starts.values():
        holds.append((last_held-started) / 1000)
    callback_gaps = [int(b["process_frame"])-int(a["process_frame"])-1
                     for a, b in zip(frames, frames[1:])
                     if number(a.get("process_frame")) is not None and number(b.get("process_frame")) is not None]
    return {"policies": dict(policies), "selected_step_observations": known,
            "selected_step_unknown_visible_frames": unknown_visible,
            "source_time_rewind_count": len(rewinds), "source_time_rewinds": rewinds,
            "source_changes": dict(source_changes), "source_reasons": dict(reasons),
            "timeline_resets": resets, "intentional_hold_frames": intentional,
            "intentional_hold_duration_ms": distribution(holds), "withheld_body_frames": withheld,
            "desired_minus_selected_steps": distribution(lag_steps),
            "follow_target_observations": follow_observations,
            "follow_target_minus_selected_world_cells": distribution(follow_residuals),
            "follow_target_minus_selected_px": distribution(follow_screen_residuals),
            "resolve_cpu_ms": distribution(resolve_costs),
            "main_submission_interval_ms": measured_rate([x.get("time_usec") for x in frames])["interval_ms"],
            "callbacks_without_observed_submission": sum(max(0, n) for n in callback_gaps),
            "submission_gaps_in_callback_index": sum(n > 0 for n in callback_gaps),
            "interpretation": "Source time is recorded by the resolver; absent/negative selected steps are unknown and cannot prove monotonicity. The last visible known step survives hidden/unknown gaps within one actor lifetime. Spatial reversals with advancing source time are not rewinds. Callback gaps count Main indices without an overlay observation, not missed physical GPU presents."}


def paired_latency(events, before_kind, after_kind, cumulative=False):
    first = event_records(events, before_kind, "render_serial")
    after = event_records(events, after_kind, "render_serial")
    result, used_after = [], set()
    for before in first:
        matching = [row for row in after if event_time(row) >= event_time(before)
                    and (row["render_serial"] >= before["render_serial"] if cumulative
                         else row["render_serial"] == before["render_serial"])]
        if matching:
            row = matching[0]
            result.append((event_time(row) - event_time(before)) / 1000)
            used_after.add(row["render_serial"])
    report = distribution(result)
    report.update(before_observations=len(first), after_observations=len(after),
                  matched_before_observations=len(result), unpaired_before_observations=len(first)-len(result),
                  matched_after_observations=len(used_after),
                  matching="first observed cumulative ACK covering serial" if cumulative else "identical render serial only")
    return report


def completed_step_trajectory(events):
    validate_capture_identity([], events)
    result = {}
    for row in event_records(events, "rapier_step", "step"):
        for body in row.get("bodies", []):
            xy = vector(body.get("xy"))
            if xy is not None:
                result[(int(row["step"]), int(body.get("slot", -1)))] = {
                    "xy": xy, "velocity": vector(body.get("velocity")),
                    "angle": number(body.get("angle")), "time_usec": event_time(row),
                    "simulation_time_sec": number(row.get("simulation_time_sec")),
                    "fixed_delta": number(row.get("fixed_delta"))}
    return result


def compare_trajectories(events_a, events_b):
    """Compare completed simulation steps, never nearest render/wall-time frames."""
    a, b = completed_step_trajectory(events_a), completed_step_trajectory(events_b)
    matched = sorted(a.keys() & b.keys())
    position, velocity, angle, times = [], [], [], []
    incompatible_delta = 0
    for key in matched:
        aa, bb = a[key], b[key]
        position.append(vector_gap(aa["xy"], bb["xy"]))
        v = vector_gap(aa["velocity"], bb["velocity"])
        if v is not None:
            velocity.append(v)
        if aa["angle"] is not None and bb["angle"] is not None:
            from math import pi
            angle.append(abs((aa["angle"] - bb["angle"] + pi) % (2 * pi) - pi))
        if aa["fixed_delta"] is not None and bb["fixed_delta"] is not None:
            incompatible_delta += int(abs(aa["fixed_delta"] - bb["fixed_delta"]) > 1e-10)
        if aa["simulation_time_sec"] is not None and bb["simulation_time_sec"] is not None:
            times.append(abs(aa["simulation_time_sec"] - bb["simulation_time_sec"]))
    return {"matching_completed_step_bodies": len(matched), "only_a": len(a.keys() - b.keys()),
            "only_b": len(b.keys() - a.keys()), "position_delta_world_cells": distribution(position),
            "velocity_delta_world_cells_per_sim_second": distribution(velocity),
            "rotation_delta_radians": distribution(angle),
            "simulation_time_delta_seconds": distribution(times),
            "incompatible_fixed_step_rows": incompatible_delta,
            "complete_recording_required": True,
            "meaning": "Equal completed step numbers, not equal wall time. Source/World/tape identity and event-drop counters must also match before claiming a controlled A/B."}


def analyze(frames: list[dict], threshold_px: float = 8.0, events=None):
    if threshold_px <= 0:
        raise ValueError("Threshold must be positive")
    events = events or []
    validate_capture_identity(frames, events)
    jumps, last, timeline = [], {}, []
    source_count, mode_count, reason_count = Counter(), Counter(), Counter()
    projection_errors = phase_jumps = selected_holds_while_live_moves = 0
    largest_projection_residual_px = 0.0
    relative_steps, live_relative_steps, compensation_steps, lag_gaps = [], [], [], []
    independent_residuals, holds_ms = [], []
    centre_visibility = Counter()
    hold_started = {}
    for frame in frames:
        number_frame = int(frame.get("process_frame", -1))
        time_usec = int(frame.get("time_usec", -1))
        mode_count[str(frame.get("camera_mode", "?"))] += 1
        for body in frame.get("bodies", []):
            slot = int(body.get("slot", -1))
            source = str(body.get("source", "hidden"))
            source_count[source] += 1
            reason_count[str(body.get("guard_reason", "?"))] += 1
            selected = vector(body.get("selected_screen"))
            if selected is None:
                last.pop(slot, None)
                hold_started.pop(slot, None)
                continue
            proj = body.get("screen_selected")
            residual = float(proj.get("residual_magnitude_px", 0.0)) if isinstance(proj, dict) else 0.0
            independently_measured = independent_projection(frame, body)
            if independently_measured is not None:
                independent_residuals.append(independently_measured)
                residual = max(residual, independently_measured)
            largest_projection_residual_px = max(largest_projection_residual_px, residual)
            if residual > 1.0:
                projection_errors += 1
            relative = subtract(selected, frame.get("shader_world_zero_screen_px"))
            live_relative = subtract(body.get("live_screen"), frame.get("shader_world_zero_screen_px"))
            # This is an exact screen-domain difference for the SAME submitted
            # transform. Its changes cannot be explained by common camera pan.
            compensation = subtract(selected, body.get("live_screen"))
            lag = vector_gap(body.get("live_screen"), body.get("bound_screen"))
            if lag is not None:
                lag_gaps.append(lag)
            current = {"selected": selected, "source": source,
                       "camera": frame.get("camera_presented"),
                       "phase": frame.get("camera_screen_phase_px"),
                       "relative": relative, "live_relative": live_relative,
                       "compensation": compensation, "time_usec": time_usec,
                       "basis": [frame.get("shader_basis_x"), frame.get("shader_basis_y")],
                       "camera_mode": frame.get("camera_mode"),
                       "identity": presentation_identity(frame, body)}
            inside = actor_centre_inside_content(frame, selected)
            centre_visibility["unmeasured" if inside is None else ("inside" if inside else "outside")] += 1
            prior = last.get(slot)
            if bool(body.get("timeline_reset", False)) or (prior and prior["identity"] != current["identity"]):
                prior = None
                hold_started.pop(slot, None)
            row = {"frame": number_frame, "time_usec": time_usec, "slot": slot,
                   "source": source, "guard_reason": body.get("guard_reason"),
                   "selected_screen_x": selected[0], "selected_screen_y": selected[1],
                   "submitted_actor_centre_in_content": inside,
                   "live_bound_gap_px": lag, "projection_residual_px": residual,
                   "relative_step_px": None, "live_relative_step_px": None,
                   "compensation_step_px": None, "selected_hold_while_live_moves": False}
            if prior:
                step = vector_gap(selected, prior["selected"])
                camera_step = vector_gap(frame.get("camera_presented"), prior["camera"])
                phase = vector_gap(frame.get("camera_screen_phase_px"), prior["phase"])
                switched = prior["source"] != source
                if phase is not None and phase > 2.0:
                    phase_jumps += 1
                if current["basis"] == prior["basis"]:
                    relative_step = vector_gap(relative, prior["relative"])
                    live_relative_step = vector_gap(live_relative, prior["live_relative"])
                    compensation_step = vector_gap(compensation, prior["compensation"])
                    for values, value in [(relative_steps, relative_step),
                                          (live_relative_steps, live_relative_step),
                                          (compensation_steps, compensation_step)]:
                        if value is not None:
                            values.append(value)
                    row.update(relative_step_px=relative_step,
                               live_relative_step_px=live_relative_step,
                               compensation_step_px=compensation_step)
                    held = relative_step is not None and live_relative_step is not None \
                        and relative_step < .001 and live_relative_step > .001
                    row["selected_hold_while_live_moves"] = held
                    if held:
                        selected_holds_while_live_moves += 1
                        hold_started.setdefault(slot, prior["time_usec"])
                    elif slot in hold_started:
                        holds_ms.append((prior["time_usec"] - hold_started.pop(slot)) / 1000)
                if (step is not None and step >= threshold_px) or switched or residual > 1.0:
                    if residual > 1.0:
                        cause = "spatial_projection_mismatch"
                    elif current["camera_mode"] != prior["camera_mode"]:
                        cause = "camera_mode_change"
                    elif switched:
                        cause = "live_vs_bound_source_switch" if {source, prior["source"]} <= {"live", "mask_bound"} \
                            else "presentation_source_change"
                    elif phase is not None and phase > 2.0:
                        cause = "camera_screen_phase_jump"
                    elif source == "mask_bound" and lag is not None and lag > threshold_px:
                        cause = "stale_mask_bound_pose"
                    else:
                        cause = "not_attributed"
                    jumps.append({"frame": number_frame, "time_usec": time_usec, "slot": slot,
                                  "source": source, "prior_source": prior["source"],
                                  "screen_jump_px": round(step, 3) if step is not None else None,
                                  "camera_world_shift": round(camera_step, 3) if camera_step is not None else None,
                                  "phase_jump_px": round(phase, 3) if phase is not None else None,
                                  "live_bound_gap_px": round(lag, 3) if lag is not None else None,
                                  "projection_residual_px": round(residual, 3),
                                  "compensation_step_px": row["compensation_step_px"],
                                  "guard_reason": body.get("guard_reason"), "cause": cause})
            timeline.append(row)
            last[slot] = current
    for slot, started in hold_started.items():
        holds_ms.append((last[slot]["time_usec"] - started) / 1000)
    native = event_records(events, "native_tick", "tick_index")
    rapier = event_records(events, "rapier_step", "step")
    uploads = event_records(events, "texture_upload", "render_serial")
    publications = event_records(events, "render_publication", "render_serial")
    draw_notifications = event_records(events, "framebuffer_draw")
    unassociated_draws = any(row.get("draw_identity_associated") is False or
                            number(row.get("process_frame")) is None or row["process_frame"] < 0
                            for row in draw_notifications)
    draws = [] if unassociated_draws else event_records(events, "framebuffer_draw", "process_frame")
    draw_rate = measured_rate([event_time(x) for x in draws])
    draw_rate["available"] = not unassociated_draws
    if unassociated_draws:
        draw_rate["unavailable_reason"] = "Separate post-draw delivery has no exact draw identity; Main notification cadence is reported separately."
    simulation_speed = None
    if len(rapier) > 1:
        dt = event_time(rapier[-1]) - event_time(rapier[0])
        sa, sb = number(rapier[0].get("simulation_time_sec")), number(rapier[-1].get("simulation_time_sec"))
        if dt > 0 and sa is not None and sb is not None:
            simulation_speed = (sb - sa) / (dt / 1e6)
    return {
        "frames": len(frames), "events": len(jumps), "camera_modes": dict(mode_count),
        "pose_sources": dict(source_count), "guard_reasons": dict(reason_count),
        "submitted_actor_centre_visibility": dict(centre_visibility),
        "guard_cpu_ms": distribution([float(x["guard"]["elapsed_usec"]) / 1000 for x in frames
                                      if number(x.get("guard", {}).get("elapsed_usec")) is not None]),
        "projection_residual_over_1px": projection_errors,
        "max_projection_residual_px": round(largest_projection_residual_px, 6),
        "independently_recomputed_projection_residual_px": distribution(independent_residuals),
        "camera_phase_jumps_over_2px": phase_jumps,
        "event_causes": dict(Counter(event["cause"] for event in jumps)),
        "largest_events": sorted(jumps, key=lambda row: row.get("screen_jump_px") or 0, reverse=True),
        "rates": {
            "main_submissions": measured_rate([x.get("time_usec") for x in frames]),
            "native_completed": completed_rate(native, "tick_index"),
            "rapier_completed": completed_rate(rapier, "step"),
            "material_publications": measured_rate([event_time(x) for x in publications]),
            "texture_upload_returns": measured_rate([event_time(x) for x in uploads]),
            "frame_post_draw": draw_rate,
            "post_draw_main_notifications": measured_rate([event_time(x) for x in draw_notifications]),
            "native_observed_at_main": observed_counter_rate(frames, "native_tick"),
            "rapier_observed_at_main": observed_counter_rate(frames, "rapier_step"),
            "rapier_simulated_seconds_per_wall_second": simulation_speed,
            "physical_gpu_present": None,
        },
        "native_tick_wall_ms": distribution([(event_time(x) - x["start_usec"]) / 1000
                                              for x in native if number(x.get("start_usec")) is not None]),
        "upload_cpu_call_ms": distribution([(event_time(x) - x["start_usec"]) / 1000
                                           for x in uploads if number(x.get("start_usec")) is not None]),
        "publication_to_upload_ms": paired_latency(events, "render_publication", "texture_upload"),
        "upload_to_ack_issue_ms": paired_latency(events, "texture_upload", "render_ack"),
        "ack_issue_to_worker_observe_ms": paired_latency(events, "render_ack", "worker_ack"),
        "upload_to_cumulative_ack_issue_ms": paired_latency(events, "texture_upload", "render_ack", True),
        "ack_issue_to_cumulative_worker_observe_ms": paired_latency(events, "render_ack", "worker_ack", True),
        "age_at_main_ms": {field: _ages(frames, field) for field in [
            "native_completed_usec", "native_snapshot_published_usec", "snapshot_received_usec",
            "render_snapshot_built_usec", "upload_completed_usec", "mask_native_completed_usec"]},
        "native_scheduler_lateness_ms": distribution([float(x["native_scheduler_lateness_usec"]) / 1000
                                                      for x in frames if number(x.get("native_scheduler_lateness_usec")) is not None]),
        "worker_pending_patch_bytes": distribution([x["worker_pending_patch_bytes"] for x in frames
                                                    if number(x.get("worker_pending_patch_bytes")) is not None]),
        "event_types": dict(Counter(x.get("event", "unknown") for x in events)),
        "physics_hold_reasons": dict(Counter(x.get("reason", "unknown") for x in events
                                              if x.get("event") == "rapier_hold")),
        "physics_progress": analyze_physics_progress(frames, events),
        "native_response_refusals": dict(Counter(x.get("native_response", {}).get("refusal", "unknown")
                                                 for x in rapier if not x.get("native_response", {}).get("accepted", False))),
        "actor_relative_to_static_world_step_px": distribution(relative_steps),
        "live_actor_relative_to_static_world_step_px": distribution(live_relative_steps),
        "presentation_error_change_px": distribution(compensation_steps),
        "live_to_mask_separation_px": distribution(lag_gaps),
        "selected_holds_while_live_moves": selected_holds_while_live_moves,
        "selected_hold_duration_ms": distribution(holds_ms),
        "presentation_contract": analyze_presentation_contract(frames),
        "timeline": timeline,
        "interpretation": (
            "Projection is recomputed from intended submitted transforms; real framebuffer comparisons remain separate. "
            "Subtracting shader world-zero cancels common camera translation at fixed zoom, so relative motion and "
            "presentation-error changes isolate actor selection from camera motion. A live/mask switch is correlation "
            "until a same-source counterfactual demonstrates cause. Rates use elapsed wall time; physics parity uses "
            "completed simulation steps. texture.update return and frame_post_draw do not measure GPU completion or monitor present."
        ),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="engine-lab-pose-*.jsonl")
    parser.add_argument("--threshold-px", type=float, default=8.0)
    parser.add_argument("--top", type=int, default=20)
    parser.add_argument("--output", type=Path, help="write JSON analysis")
    parser.add_argument("--timeline-csv", type=Path, help="write per-frame actor/camera separation measurements")
    parser.add_argument("--compare", type=Path, help="compare actual completed Rapier steps with another original trace")
    args = parser.parse_args(argv)
    header, frames, footer = read_trace(args.trace)
    report = analyze(frames, args.threshold_px, footer["_events"])
    report["capture_settings"] = header.get("settings")
    report["dropped_frames"] = footer.get("dropped", 0)
    report["dropped_events"] = footer.get("events_dropped", 0)
    report["dropped_worker_events"] = footer.get("worker_events_dropped", 0)
    report["duplicate_callback_frames"] = footer.get("duplicates", 0)
    report["capture_duration_seconds"] = footer.get("elapsed_seconds")
    report["complete_recording"] = not any(report.get(k, 0) for k in [
        "dropped_frames", "dropped_events", "dropped_worker_events"])
    report["largest_events"] = report["largest_events"][:max(0, args.top)]
    timeline = report.pop("timeline")
    if args.timeline_csv and timeline:
        with args.timeline_csv.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(timeline[0]))
            writer.writeheader()
            writer.writerows(timeline)
    if args.compare:
        other_header, _, other_footer = read_trace(args.compare)
        report["comparison"] = compare_trajectories(footer["_events"], other_footer["_events"])
        report["comparison"]["settings_a"] = header.get("settings")
        report["comparison"]["settings_b"] = other_header.get("settings")
        report["comparison"]["other_trace_complete"] = not any(other_footer.get(k, 0) for k in [
            "dropped", "events_dropped", "worker_events_dropped"])
    result = json.dumps(report, indent=2, allow_nan=False)
    if args.output:
        args.output.write_text(result + "\n", encoding="utf-8")
        print(f"Saved {args.output}")
    else:
        print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
