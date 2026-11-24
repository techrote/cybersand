#!/usr/bin/env python3
"""Describe tracing perturbation without granting optimization or step credit."""
from __future__ import annotations

import json
from pathlib import Path

from run_comparison import HERE
from run_campaign import physical_outcome_parity
from run_focus import validate_complete_comparison
from results import need
from independent_reduction import sha, witnessed_steps
from causal_intervals import aggregate, partition, union_intervals


def registration():
    value = json.loads((HERE / "causal_completion_registration.json").read_bytes())
    need(value.get("schema") == "pubpres-final-causal-completion-registration-v1"
         and value.get("platform") == "windows" and value.get("cases") == ["wave_512_follow"]
         and value.get("order") == [False, True, True, False]
         and all(type(item) is bool for item in value["order"])
         and all(type(value.get(key)) is type(expected) and value[key] == expected for key, expected in {
             "material": "full", "full_image_slots": 2, "render_thread": "safe", "physics": "early",
             "presentation": "coherent", "same_frame_continuation": False, "material_deadline_hz": 0,
             "material_step_interval": 0, "presentation_observer": True, "minimum_capture_usec": 10000000,
             "minimum_real_steps": 144, "maximum_capture_usec": 90000000}.items()),
         "Causal diagnostic differs from its narrow registered workload")
    return value


def summarize(arms):
    validate_complete_comparison(arms, 4)
    need(len({arm["statistics"]["source"] for arm in arms}) == 1,
         "Causal diagnostic mixed application/runtime source")
    need(all(type(arm.get("causal_enabled")) is bool for arm in arms)
         and [arm["causal_enabled"] for arm in arms] == [False, True, True, False],
         "Causal diagnostic must retain OFF/ON/ON/OFF order")
    parity = physical_outcome_parity(arms)
    need(parity["same_source_pairs_equal"] is True, "Tracing changed equal-step physical outcomes; causal attribution refused")
    readings = []
    for arm in arms:
        enabled, causal = arm["causal_enabled"], arm["causal"]
        stats = arm["statistics"]
        window = stats["windows"]["first_144_steps"]
        completed = stats["windows"]["whole_capture"]["completed_rapier_steps"]
        need(type(window.get("completed_rapier_steps")) is int and window["completed_rapier_steps"] == 144
             and type(completed) is int and completed >= 144 and causal.get("enabled") is enabled,
             "Physical window or actual causal selector differs")
        need(arm["observers"]["presentation_enabled"] is True
             and arm["observers"]["cpu"]["complete"] is True,
             "Causal arms must share complete pose and actual-process CPU observers")
        if enabled:
            need(type(causal.get("actual_completed_rapier_steps")) is int
                 and causal["actual_completed_rapier_steps"] == completed
                 and type(causal.get("exact_application_and_exit_joins")) is int
                 and causal["exact_application_and_exit_joins"] == completed
                 and type(causal.get("matched_native_to_rapier_transactions")) is int
                 and 0 < causal["matched_native_to_rapier_transactions"] <= completed
                 and isinstance(causal.get("unavailable_producer_joins"), list),
                 "Causal rows do not join every real native-application and physical exit")
        else:
            need(type(causal.get("causal_events")) is int and causal["causal_events"] == 0,
                 "Disabled tracing emitted causal events or an invalid count")
        readings.append({"index": arm["index"], "causal_enabled": enabled,
                         "steps_per_second": window["rapier_steps_per_second"],
                         "physical_gap_ms": window["physical_gap_ms"],
                         "physical_gap_counts": stats["physical_gap_counts_above_ms"]["first_144_steps"],
                         "cpu": arm["observers"]["cpu"],
                         "presentation": arm["observers"]["presentation"]["windows"],
                         "producer_joins": causal.get("matched_native_to_rapier_transactions"),
                         "unavailable_producer_joins": causal.get("unavailable_producer_joins")})
    ratios = []
    for on in (arms[1], arms[2]):
        for off in (arms[0], arms[3]):
            a, b = (arm["statistics"]["windows"]["first_144_steps"] for arm in (on, off))
            ratios.append({"on_index": on["index"], "off_index": off["index"],
                           "physical_rate_on_over_off": a["rapier_steps_per_second"] / b["rapier_steps_per_second"],
                           "physical_gap_on_over_off": {key: a["physical_gap_ms"][key] / b["physical_gap_ms"][key]
                               if b["physical_gap_ms"][key] > 0 else None for key in ("p50", "p95", "p99", "max")}})
    return {"physical_outcome_parity": parity, "readings": readings, "all_cross_arm_ratios": ratios,
            "performance_selection": "NOT_AN_OPTIMIZATION_COMPARISON",
            "scope": "Trace perturbation is observed, not assumed zero. Causal ON timelines explain only this instrumented execution; unavailable boundary joins remain unavailable and no display/GPU or physical NVIDIA timestamp is invented."}


def observed_intervals(receipt_path: Path, causal: dict) -> dict:
    """Apply the existing interval algebra after full causal/base admission.

    The historical file reader intentionally admits only its old disabled
    sidecar schema. Keep that reader unchanged: this new caller explicitly
    binds the already validated ON/OFF sidecar, then uses its unchanged generic
    partition/union functions on the independent base physical trace.
    """
    receipt_path = Path(receipt_path)
    data = json.loads(receipt_path.read_bytes())
    trace = receipt_path.with_name(receipt_path.stem + "-events.jsonl")
    sidecar = receipt_path.with_name(receipt_path.stem + "-causal-events.jsonl")
    need(sha(trace) == data["trace_sha256"] == causal.get("base_trace_sha256")
         and sha(sidecar) == causal.get("trace_sha256")
         and causal.get("source") == data["source_identity"]
         and type(causal.get("enabled")) is bool, "Interval inputs differ from admitted actual causal/base evidence")
    with sidecar.open(encoding="utf-8") as stream:
        identity = json.loads(stream.readline())
    need(identity.get("event") == "causal_identity" and identity.get("enabled") is causal["enabled"]
         and identity.get("source") == data["source_identity"]
         and identity.get("base_trace_sha256") == sha(trace)
         and identity.get("capture_start_usec") == data["capture_start_usec"]
         and identity.get("capture_end_usec") == data["capture_end_usec"]
         and data.get("observer_mode") == "full",
         "Interval causal selector, capture window or complete base observer differs")
    rows = [json.loads(line) for line in trace.read_text(encoding="utf-8").splitlines()]
    need(rows and rows[0].get("event") == "identity" and rows[0].get("source") == data["source_identity"],
         "Interval base source identity differs")
    rows = rows[1:]
    steps, witness = witnessed_steps(data, rows)
    native_rows = [row for row in rows if row.get("event") == "native_completion_observed"]
    native = {(row["world_generation"], row["tick_index"], row["body_sample"]): row for row in native_rows}
    need(len(native) == len(native_rows), "Duplicate independently observed native completion identity")
    uploads = [row for row in rows if row.get("event") == "texture_upload"]
    intervals = union_intervals((row["start_usec"], row["time_usec"]) for row in uploads)
    gaps = [partition(previous, current,
                      native.get((current["world_generation"], current["native_tick_used"], current["completed_body_sample"])),
                      intervals) for previous, current in zip(steps, steps[1:])]
    return {"schema": "pubpres-final-admitted-causal-base-intervals-v1", "receipt_sha256": sha(receipt_path),
            "base_trace_sha256": sha(trace), "causal_trace_sha256": sha(sidecar),
            "causal_enabled": causal["enabled"], "physical_witness": witness,
            "recorded_publication_transactions": len(uploads), "unioned_publication_intervals": len(intervals),
            "windows": {"whole_capture": aggregate(gaps), "first_144_steps": aggregate(gaps[:143])}, "gaps": gaps,
            "scope": "Independent base completion/observation/callback intervals and unioned Main publication occupancy only. Exact producer start/admission/terrain clocks remain in the separately validated causal analysis; no profiler duration is converted into a timestamp. Nonordered boundaries remain unavailable."}
