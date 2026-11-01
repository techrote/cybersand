"""Fixed-horizon reduction; interpretation is gated by exact prefix and custody."""
from __future__ import annotations

import argparse
from collections import Counter
import json
import math
from pathlib import Path
import statistics

from post_arrest_accounting import account, sha, write


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def distribution(values):
    values = sorted(values)
    return {"count": len(values), "min": min(values), "p50": statistics.median(values),
            "p95": values[math.ceil(.95*len(values))-1], "max": max(values),
            "mean": statistics.mean(values), "negative": sum(v < 0 for v in values),
            "zero": values.count(0), "positive": sum(v > 0 for v in values)}


def episodes(flags):
    result = []
    start = None
    for i, flag in enumerate([*flags, False]):
        if flag and start is None:
            start = i
        if not flag and start is not None:
            result.append([start, i-1])
            start = None
    return result


def clearance(frames, consecutive=60):
    contact = [any(f["geometry"][k] > 0 for k in ("pre_overlap", "post_ejection_overlap", "post_tick_overlap_at_packed_pose")) for f in frames]
    overlap = [f["geometry"]["post_ejection_overlap"] > 0 or f["geometry"]["post_tick_overlap_at_packed_pose"] > 0 for f in frames]
    first_contact = next((i for i, value in enumerate(contact) if value), None)
    zero_runs = episodes([not value and first_contact is not None and i >= first_contact for i, value in enumerate(overlap)])
    sustained = next((a for a, b in zero_runs if b-a+1 >= consecutive), None)
    first_zero = zero_runs[0][0] if zero_runs else None
    recurrences = [a for a, b in episodes(overlap) if first_zero is not None and a > first_zero]
    after_sustained = [a for a in recurrences if sustained is not None and a >= sustained+consecutive]
    preceding = None
    if sustained is not None:
        preceding = next((b-a+1 for a, b in reversed(episodes(overlap)) if b == sustained-1), 0)
    return {"contact_prevented": first_contact is None, "first_observed_contact": first_contact,
            "first_zero_any_sample": next((i for i, flag in enumerate(overlap) if not flag), None),
            "first_zero_after_contact": first_zero, "first_sustained_clearance": sustained,
            "clearance_confirmed_at": sustained+consecutive-1 if sustained is not None else None,
            "clearance_time_seconds_from_sample0": sustained/60 if sustained is not None else None,
            "clearance_latency_seconds_from_first_contact": (sustained-first_contact)/60 if sustained is not None else None,
            "preceding_consecutive_overlap_frames": preceding,
            "contact_to_sustained_samples": sustained-first_contact if sustained is not None else None,
            "zero_runs_after_contact": zero_runs, "recurrence_samples": recurrences,
            "recurrence_periods_samples": [b-a for a, b in zip(recurrences, recurrences[1:])],
            "recurrence_after_sustained": after_sustained,
            "right_censored_at": len(frames) if first_contact is not None and sustained is None else None,
            "longest_overlap_episode": max((b-a+1 for a, b in episodes(overlap)), default=0),
            "longest_any_boundary_overlap_episode": max((b-a+1 for a, b in episodes(contact)), default=0)}


def limiter(frame):
    b = frame["bearing"]
    magnitude = -b["bearing_y"]
    if magnitude <= 0:
        return "inactive"
    return "+".join(name for name, value in (("arrest", b["arrest"]), ("yield", b["yield"]), ("capacity", b["capacity"]))
                    if math.isclose(value, magnitude, abs_tol=1e-9, rel_tol=1e-10)) or "unresolved"


def response(frames):
    details = [f["application_details"][0] for f in frames]
    return {"frames": len(frames), "correction_active_frames": sum(any(d["applied_correction"]) for d in details),
            "total_requested_correction": [sum(d["requested_correction"][i] for d in details) for i in range(2)],
            "total_applied_correction": [sum(d["applied_correction"][i] for d in details) for i in range(2)],
            "total_actual_correction_translation_y": sum(d["after_correction"][1]-d["before"][1] for d in details),
            "velocity_zeroing_frames": sum(any(d["before"][3+i]*d["applied_correction"][i] < 0 for i in range(2)) for d in details),
            "total_accepted_impulse": [sum(f["bridge_application"][1+i] for f in frames) for i in range(2)],
            "total_nominal_bearing_y": sum(f["bearing"]["bearing_y"] for f in frames),
            "bearing_limiter_distribution": dict(Counter(limiter(f) for f in frames)),
            "raw_support_distribution": dict(Counter(str(f["bearing"]["raw_support"]) for f in frames)),
            "support_with_zero_count_response_frames": sum(f["bearing"]["raw_support"] == 0 and
                (f["bearing"]["bearing_y"] != 0 or any(f["requested_results"][3:5])) for f in frames)}


def motion(frames):
    y = [f["after_application"][1] for f in frames]
    rapier = sum(f["after_step"][1]-f["before_step"][1] for f in frames)
    correction = sum(f["after_application"][1]-f["after_step"][1] for f in frames)
    net = frames[-1]["after_application"][1]-frames[0]["before_step"][1]
    center = (min(y)+max(y))/2
    previous = crossings = 0
    for value in y:
        sign = 1 if value > center+.5 else -1 if value < center-.5 else 0
        if sign and previous and sign != previous:
            crossings += 1
        if sign:
            previous = sign
    return {"center_y_span": max(y)-min(y), "center_net_drift": net,
            "full_cycles_above1px": crossings//2,
            "post_application_endpoint_drift": y[-1]-y[0], "rapier_positional_increment": rapier,
            "actual_correction_translation": correction, "resulting_translation": rapier+correction,
            "position_accounting_residual": net-rapier-correction,
            "absolute_vertical_velocity": distribution([abs(f["after_application"][4]) for f in frames]),
            "incoming_vertical_velocity": distribution([f["after_step"][4] for f in frames]),
            "outgoing_vertical_velocity": distribution([f["after_application"][4] for f in frames])}


def block(frames):
    measurements = {}
    for name in ("pre_overlap", "post_ejection_overlap", "post_tick_overlap_at_packed_pose"):
        values = [f["geometry"][name] for f in frames]
        measurements[name] = {"cell_ticks": sum(values), "frames": sum(v > 0 for v in values), "min": min(values), "max": max(values)}
    return {"samples": [frames[0]["tick"], frames[-1]["tick"]], "overlap": measurements,
            "motion": motion(frames), "response": response(frames)}


def disposition(clear, tail, blocks, thresholds):
    if clear["contact_prevented"]:
        return "contact prevented"
    if clear["first_sustained_clearance"] is not None:
        return "clears after finite withdrawal latency" if not clear["recurrence_after_sustained"] else "sustained clearance with later recurrence"
    if len(clear["recurrence_samples"]) >= 2:
        return "recurrent clearance failure; clearance right-censored at1800"
    near_static = (abs(tail["center_net_drift"]) <= thresholds["absolute_drift_px"] and
                   tail["center_y_span"] <= thresholds["span_px"] and
                   tail["absolute_vertical_velocity"]["p95"] <= thresholds["p95_absolute_vy"] and
                   tail["absolute_vertical_velocity"]["max"] <= thresholds["max_absolute_vy"] and
                   tail["incoming_vertical_velocity"]["max"]-tail["incoming_vertical_velocity"]["min"] <= thresholds["velocity_range"] and
                   tail["outgoing_vertical_velocity"]["max"]-tail["outgoing_vertical_velocity"]["min"] <= thresholds["velocity_range"])
    if blocks[-1]["overlap"]["post_tick_overlap_at_packed_pose"]["min"] > 0 and near_static:
        return "persistent near-static overlap within registered criteria; clearance right-censored at1800"
    changing = abs(blocks[-1]["overlap"]["post_tick_overlap_at_packed_pose"]["cell_ticks"] -
                   blocks[-2]["overlap"]["post_tick_overlap_at_packed_pose"]["cell_ticks"]) / 300 > thresholds["changing_overlap_mean_cells"]
    if tail["center_net_drift"] < -thresholds["measurable_upward_px"] and changing and not near_static:
        return "dynamic withdrawal, clearance right-censored at1800"
    return "unresolved finite-tail overlap, clearance right-censored at1800"


def custody(directory):
    receipt = read(directory/"receipt.json")
    if not receipt["ok"] or not receipt["prefix"]["pass"]:
        raise ValueError("prefix/measurement failure — no causal disposition")
    for name, expected in receipt["artifact_sha256"].items():
        if sha(directory/name) != expected:
            raise ValueError("changed acquisition artifact: "+name)
    frames = read(directory/"trajectory.json")["frames"]
    population = read(directory/"population-manifest.json")
    acquisition = read(directory/"acquisition.json")
    if len(frames) != 1800 or [f["tick"] for f in frames] != list(range(1800)) or acquisition["native_counters"]["dropped"]:
        raise ValueError("horizon/capacity failure")
    if receipt["attempts"] != population["attempts"] or receipt["replay_matches"] != population["attempts"]:
        raise ValueError("replay population incomplete")
    expected = frames[0]["stored_counts"]
    maximum = Counter()
    for i, f in enumerate(frames):
        if f["stored_counts"] != expected or f["bearing"]["probe_drops"] or f["candidate"] != receipt["candidate"]:
            raise ValueError("conservation/support/candidate failure")
        if any(f[k] for k in ("stored_water_mass", "pre_water_mass", "post_water_mass")):
            raise ValueError("quantity conservation failure")
        if f["body_input"][10] != i+1 or f["requested_results"][8] != i+1 or f["completed_tick"] != i+1:
            raise ValueError("sample identity mismatch")
        if f["application_details"][0]["age"] != 0 or f["bridge_application"][3:6] != [0, 0, 1]:
            raise ValueError("stale/duplicate application")
        row = account(f, frames[i+1] if i+1 < len(frames) else None)
        for k, v in row["residuals"].items():
            maximum[k] = max(maximum[k], v)
    # Single precision bridge addition may differ in backend unit conversion;
    # preserve the parent2e-5 boundary tolerance, never fit it to new results.
    if max(maximum.values(), default=0) > 2e-5:
        raise ValueError("unexplained material accounting residual")
    return receipt, frames, population, dict(maximum)


def describe(directory, protocol):
    directory = Path(directory)
    receipt, frames, population, residuals = custody(directory)
    if sha(protocol) != receipt["protocol_sha256"]:
        raise ValueError("preregistration changed")
    registration = read(protocol)
    clear = clearance(frames)
    blocks = [block(frames[i:i+300]) for i in range(0, 1800, 300)]
    tail = motion(frames[-300:])
    failures = [e for e in population["events"] if e["target"][0] < 0]
    selected = {str(i): {k: frames[i]["geometry"][k] for k in
                ("pre_overlap", "post_ejection_overlap", "post_tick_overlap_at_packed_pose")} for i in (600, 900, 1200, 1500, 1799)}
    # Reuse already registered contextual safety definitions, without weakening90.
    # Use literal frame predicates rather than600-only outcome helpers.
    no_support = [f["bearing"]["raw_support"] == 0 for f in frames]
    lift = [i > 0 and no_support[i] and frames[i-1]["after_step"][4] < 0 and f["after_step"][4] < 0 and
            f["after_step"][4] < frames[i-1]["after_step"][4]-.05 for i, f in enumerate(frames)]
    # Hover: no raw support, no contact and near-zero vy above the bank for30frames.
    hover = [no_support[i] and f["geometry"]["lower_extent"] < 159.5 and abs(f["after_step"][4]) <= 1 for i, f in enumerate(frames)]
    first = clear["first_sustained_clearance"]
    return {"schema": 1, "candidate": receipt["candidate"], "arm": receipt["arm"], "source": receipt["source"], "tree": receipt["tree"],
            "runtime": receipt["runtime"], "prefix": receipt["prefix"], "receipt_sha256": sha(directory/"receipt.json"),
            "clearance": clear, "classification": disposition(clear, tail, blocks, registration["near_static"]),
            "overlap_at_samples": selected, "blocks": blocks, "final300_motion": tail, "response_all": response(frames),
            "response_final300": response(frames[-300:]), "response_before_clearance": response(frames[:first]) if first else None,
            "tail_after_clearance": {"motion": motion(frames[first:]), "response": response(frames[first:])} if first is not None else None,
            "accounting_maximum_residuals": residuals, "ejection": {"attempts": population["attempts"],
                "no_target_positive_incoming_vy": sum(e["current_body"][7] > 0 for e in failures),
                "no_target_nonpositive_incoming_vy": sum(e["current_body"][7] <= 0 for e in failures),
                "note": "Descriptive deterministic attempts, not independent efficacy population"},
            "high_water": population["high_water"], "conservation_failures": 0,
            "context_control": {"delayed_overlap_after599": any(any(f["geometry"][k] > 0 for k in
                    ("pre_overlap", "post_ejection_overlap", "post_tick_overlap_at_packed_pose")) for f in frames[600:]),
                "longest_unsupported_hover_frames": max((b-a+1 for a, b in episodes(hover)), default=0),
                "longest_artificial_lift_frames": max((b-a+1 for a, b in episodes(lift)), default=0),
                "unsupported_response_frames": response(frames)["support_with_zero_count_response_frames"],
                "post_clearance_no_support_response_frames": sum(no_support[i] and
                    (f["bearing"]["bearing_y"] != 0 or any(f["requested_results"][3:5])) for i, f in enumerate(frames) if first is not None and i >= first),
                "support_distribution_final300": response(frames[-300:])["raw_support_distribution"]},
            "recurrence_handoff": [account(frames[i], frames[i+1] if i+1 < len(frames) else None) for i in clear["recurrence_samples"]]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--protocol", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    results = {name: describe(args.input/name, args.protocol) for name in ("B0-speed90", "Y1-speed90", "B0-speed30", "Y1-speed30")}
    if len({(r["source"], r["tree"], json.dumps(r["runtime"], sort_keys=True)) for r in results.values()}) != 1:
        raise ValueError("arms do not share common source/runtime")
    write(args.output, {"schema": 1, "cases": results, "production_selection": False})
    print(json.dumps({k: {"classification": r["classification"], "clearance": r["clearance"]["first_sustained_clearance"]} for k, r in results.items()}))
