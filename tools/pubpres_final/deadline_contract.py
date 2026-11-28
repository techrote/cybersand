#!/usr/bin/env python3
"""Additive material scheduling evidence after the unchanged physical V3 oracle.

No counter in this module is a physical-step witness. Actual physical progression,
terrain/body/sample ownership and current GPU bytes must first pass frozen V3.
"""
from __future__ import annotations

import json
from pathlib import Path

from run_comparison import ROOT
from run_campaign import physical_outcome_parity
from run_focus import validate_complete_comparison
from run_source_abba import compare_registered_direction
from renderer_contract import FROZEN_V3_SHA256
from results import digest, distribution, need

OBSERVER = "tests/pubpres_final_deadline_gameplay.gd"
RESOURCE = "tests/pubpres_final_deadline_registration.json"
COUNTERS = ("offers", "replaced_offers", "consumptions", "accepted_uploads", "cancellations")


def integer(value, minimum=0) -> bool:
    """New scheduling evidence uses real JSON integers; bool/float are refused."""
    return type(value) is int and value >= minimum


def verify_deadline_contract(root: Path = ROOT) -> dict:
    frozen = root / "tools/pubpres_playability/results_same_frame.py"
    need(digest(frozen) == FROZEN_V3_SHA256, "Frozen physical V3 reducer changed")
    observer = root / "tools/pubpres_final/pubpres_final_deadline_gameplay.gd"
    need(observer.read_text().startswith('extends "res://tests/pubpres_final_gameplay.gd"\n'),
         "Deadline observer no longer inherits the registered sole-worker/callback fixture")
    return {"frozen_v3_sha256": digest(frozen), "deadline_observer_sha256": digest(observer),
            "scope": "Unchanged complete physical V3 validation plus additive requested/effective deadline, exact upload and bounded status-sidecar checks."}


def validate_status(status: dict, hz: int) -> None:
    need(type(hz) is int and hz in (0, 30, 60), "Unregistered material deadline")
    interval = {0: 0, 30: 33334, 60: 16667}[hz]
    need(isinstance(status, dict) and status.get("schema") == "pubpres-material-deadline-v1"
         and integer(status.get("requested_hz")) and status["requested_hz"] == hz
         and status.get("enabled") is (hz != 0) and integer(status.get("interval_usec"))
         and status["interval_usec"] == interval and status.get("physical_credit") is False,
         "Requested material deadline did not reach live policy")
    need(all(integer(status.get(key)) for key in COUNTERS), "Deadline counter is invalid")
    need(status["accepted_uploads"] <= status["consumptions"] <= status["offers"]
         and status["replaced_offers"] <= status["offers"], "Impossible policy accounting")
    pending = status.get("pending_count")
    need(type(pending) is int and pending in (0, 1), "Unbounded pending material snapshots")
    if pending:
        need(hz != 0 and integer(status.get("pending_serial"), 1)
             and integer(status.get("pending_generation")) and integer(status.get("deadline_usec"), 1),
             "Pending material lacks a real serial, World or deadline")
    else:
        need(all(type(status.get(key)) is int and status[key] == -1
                 for key in ("pending_serial", "pending_generation", "deadline_usec")),
             "Empty pending slot retains material authority")
    need(integer(status.get("next_upload_usec"), -1), "Invalid next upload deadline")
    if hz == 0:
        need(all(status[key] == 0 for key in COUNTERS) and pending == 0
             and status["next_upload_usec"] == -1, "Off control acquired scheduling work")


def _material(value: dict) -> dict:
    need(isinstance(value, dict) and integer(value.get("serial"), 1)
         and integer(value.get("generation"), 1) and integer(value.get("generated_usec"), 1),
         "Uploaded material identity/clock is unavailable")
    return value


def validate_deadline_evidence(data: dict, events: list[dict], header: dict,
                               rows: list[dict], hz: int, maximum: int = 6000) -> dict:
    """Validate decoded observations; caller authenticates files and frozen V3 first."""
    begin, end = data["capture_start_usec"], data["capture_end_usec"]
    need(integer(begin, 1) and integer(end, begin + 1) and header.get("event") == "material_deadline_identity"
         and header.get("schema") == "pubpres-material-deadline-observer-v1"
         and header.get("source") == data["source_identity"] and header.get("case_nonce") == data["case_nonce"]
         and integer(header.get("capture_start_usec"), 1) and integer(header.get("capture_end_usec"), 1)
         and header["capture_start_usec"] == begin and header["capture_end_usec"] == end,
         "Deadline sidecar belongs to another capture or source")
    need(header.get("overflow") is False and integer(header.get("maximum_samples"), 1)
         and header["maximum_samples"] == maximum and integer(header.get("samples"), 1)
         and header["samples"] == len(rows) and 0 < len(rows) <= maximum,
         "Missing or truncated deadline observation stream")
    before = data["selectors_before"]
    after = data["selectors_after"]
    for selected in (before, after):
        need(selected["requested"].get("CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ") == str(hz),
             "Actual requested material rate differs")
        validate_status(selected.get("material_deadline"), hz)
    need(header["start_status"] == before["material_deadline"]
         and header["start_material"] == before["material_deadline_uploaded"],
         "Pre-capture policy/material identity differs")
    initial, final = _material(header["start_material"]), _material(header["end_material"])
    start_status, end_status = header["start_status"], header["end_status"]
    validate_status(end_status, hz)
    draws = [row for row in events if row["event"] == "framebuffer_draw"]
    uploads = sorted((row for row in events if row["event"] == "texture_upload"), key=lambda r: r["time_usec"])
    need(uploads and len(rows) == len(draws), "Deadline polls do not cover each real draw notification")
    draws.sort(key=lambda row: row["time_usec"])
    previous = start_status
    material = initial
    upload_index = 0
    prior_clock = begin
    for row, draw in zip(rows, draws):
        need(row.get("event") == "material_deadline_delivery"
             and integer(row.get("time_usec"), 1) and prior_clock <= row["time_usec"] <= end
             and integer(row.get("delivered_draw_usec"), 1)
             and row["delivered_draw_usec"] == draw["time_usec"] <= row["time_usec"]
             and integer(row.get("process_frame")) and row["process_frame"] == draw["process_frame"]
             and integer(row.get("rendered_frames")) and row["rendered_frames"] == draw["rendered_frames"]
             and row.get("inline_main") is True and draw.get("inline_main") is True
             and integer(row.get("draw_render_serial"), 1) and integer(row.get("uploaded_serial"), 1)
             and integer(row.get("uploaded_generation"), 1) and integer(row.get("uploaded_generated_usec"), 1)
             and row.get("draw_render_serial") == draw["render_serial"] == row.get("uploaded_serial"),
             "Deadline poll is reordered or lacks its actual Safe draw identity")
        need(integer(row.get("observer_usec")), "Deadline observer cost missing")
        while upload_index < len(uploads) and uploads[upload_index]["time_usec"] <= row["delivered_draw_usec"]:
            upload = uploads[upload_index]
            material = {"serial": upload["render_serial"], "generation": upload["world_generation"],
                        "generated_usec": upload["generated_usec"]}
            upload_index += 1
        need({"serial": row["uploaded_serial"], "generation": row.get("uploaded_generation"),
              "generated_usec": row.get("uploaded_generated_usec")} == material
             and material["generated_usec"] <= row["delivered_draw_usec"],
             "Draw material identity or age was fabricated from a newer native snapshot")
        status = row.get("status")
        validate_status(status, hz)
        need(all(status[key] >= previous[key] for key in COUNTERS), "Deadline counter regressed")
        if status["pending_count"]:
            need(status["pending_serial"] > row["uploaded_serial"]
                 and status["pending_generation"] == row["uploaded_generation"],
                 "Pending material is stale or belongs to another World")
            if previous["pending_count"] and status["consumptions"] == previous["consumptions"] \
                    and status["cancellations"] == previous["cancellations"]:
                need(status["deadline_usec"] == previous["deadline_usec"],
                     "Replacing an unconsumed material offer renewed its fixed deadline")
        previous, prior_clock = status, row["time_usec"]
    need(all(end_status[key] >= previous[key] and after["material_deadline"][key] >= end_status[key]
             for key in COUNTERS), "End-of-capture policy counters precede their observations")
    last = uploads[-1]
    need(final == {"serial": last["render_serial"], "generation": last["world_generation"],
                   "generated_usec": last["generated_usec"]}, "End material differs from actual last upload")
    delta = {key: end_status[key] - start_status[key] for key in COUNTERS}
    if hz:
        need(delta["consumptions"] == delta["accepted_uploads"] == len(uploads)
             and delta["cancellations"] == 0,
             "Material treatment bypassed its policy, rejected work, or changed owner during capture")
        need(delta["offers"] == delta["accepted_uploads"] + delta["replaced_offers"]
             + end_status["pending_count"] - start_status["pending_count"],
             "Deferred/cumulative offer accounting does not balance")
        interval = end_status["interval_usec"]
        need(all(b["start_usec"] >= a["time_usec"] + interval for a, b in zip(uploads, uploads[1:])),
             "Actual material upload violated the registered completion-based minimum interval")
    steps = sorted((r for r in events if r["event"] == "rapier_step"), key=lambda r: r["step"])
    need(len(steps) >= 144, "Deadline metrics require independently validated actual physical completions")
    return {"schema": "pubpres-material-deadline-analysis-v1", "requested_hz": hz,
            "effective_interval_usec": end_status["interval_usec"], "capture_policy_counters": delta,
            "physical_credit": False,
            "windows": {"first_144_steps": _window(rows, uploads, header, steps[143]["time_usec"]),
                        "whole_capture": _window(rows, uploads, header, end)},
            "scope": {"physical": "All genuine step counts/gaps are supplied by unchanged frozen V3, never by these counters.",
                      "deferral": "Pending-at-draw observations describe deferred presentation; they are sampled frames, not a guessed count of native or Rapier completions.",
                      "material_age": "Actual last uploaded native material generation to its matching Safe Main post-draw delivery; not a GPU fence or scanout.",
                      "first_144_counters": "Counter observations stop at the last draw poll at/before step144; trailing unsampled time is explicit. Whole-capture counters use the pre-cleanup snapshot.",
                      "cadence": "Requested interval is not an effective render/physics rate. Actual upload rate/spacing and zero-suppression arms remain explicit."}}


def _window(rows: list[dict], uploads: list[dict], header: dict, end: int) -> dict:
    begin = header["capture_start_usec"]
    selected = [row for row in rows if begin <= row["time_usec"] <= end]
    chosen_uploads = [row for row in uploads if begin <= row["time_usec"] <= end]
    pending = [row for row in selected if row["status"]["pending_count"]]
    if end == header["capture_end_usec"]:
        final, sampled_through = header["end_status"], end
    elif selected:
        final, sampled_through = selected[-1]["status"], selected[-1]["time_usec"]
    else:
        final, sampled_through = header["start_status"], begin
    return {"start_usec": begin, "end_usec": end,
            "actual_uploads": len(chosen_uploads),
            "actual_uploads_per_second": len(chosen_uploads) * 1000000 / (end - begin),
            "upload_return_spacing_ms": distribution((b["time_usec"] - a["time_usec"]) / 1000
                                                       for a, b in zip(chosen_uploads, chosen_uploads[1:])),
            "policy_counters_observed_through_usec": sampled_through,
            "policy_counter_trailing_unsampled_ms": (end - sampled_through) / 1000,
            "policy_counter_deltas": {key: final[key] - header["start_status"][key] for key in COUNTERS},
            "draw_polls": len(selected), "pending_at_draw_count": len(pending),
            "pending_before_fixed_deadline_count": sum(row["time_usec"] < row["status"]["deadline_usec"] for row in pending),
            "pending_overdue_at_draw_count": sum(row["time_usec"] >= row["status"]["deadline_usec"] for row in pending),
            "pending_deadline_overrun_ms": distribution((row["time_usec"] - row["status"]["deadline_usec"]) / 1000
                                                         for row in pending if row["time_usec"] >= row["status"]["deadline_usec"]),
            "material_generation_to_each_draw_delivery_ms": distribution((row["delivered_draw_usec"] - row["uploaded_generated_usec"]) / 1000
                                                                         for row in selected),
            "status_observer_usec": distribution(row["observer_usec"] for row in selected)}


def reduce_deadline_evidence(receipt: Path, events: list[dict], hz: int) -> dict:
    data = json.loads(receipt.read_bytes())
    proof = data["selectors_after"].get("material_deadline_observer", {})
    path = receipt.with_name(receipt.stem + "-deadline-events.jsonl")
    need(proof.get("schema") == "pubpres-material-deadline-sidecar-v1"
         and proof.get("sha256") == digest(path) and proof.get("overflow") is False
         and type(proof.get("maximum_samples")) is int and proof["maximum_samples"] == 6000,
         "Deadline sidecar custody or capacity differs")
    lines = [json.loads(line) for line in path.read_text().splitlines()]
    need(lines and integer(proof.get("samples"), 1) and proof["samples"] == len(lines) - 1,
         "Deadline sidecar count differs")
    result = validate_deadline_evidence(data, events, lines[0], lines[1:], hz)
    result.update(receipt_sha256=digest(receipt), sidecar_sha256=digest(path))
    return result


def validate_deadline_cohort(arms: list[dict], registration: dict) -> dict:
    order = registration["order"]
    validate_complete_comparison(arms, len(order))
    need([arm["requested_hz"] for arm in arms] == order, "Deadline rates or counterbalanced order differ")
    need(len({arm["statistics"]["source"] for arm in arms}) == 1, "Deadline cohort changed application source")
    for arm, hz in zip(arms, order):
        stats = arm["statistics"]
        need(arm["deadline"]["requested_hz"] == hz and arm["deadline"]["physical_credit"] is False
             and arm["slots"]["requested_slots"] == 2 and arm["slots"]["effective_slots_verified"] is True
             and stats["registered_material_treatment"] == {"backend": "full", "policy": ""}
             and stats["same_frame_continuation"]["enabled"] is False, "Unregistered extra deadline treatment")
        need(arm["observers"]["presentation_enabled"] is True
             and isinstance(arm["observers"]["presentation"], dict)
             and isinstance(arm["observers"]["cpu"], dict),
             "Deadline arm lacks its independently validated submitted-pose/CPU sidecars")
        for phase in ("selectors_before", "selectors_after"):
            selected = stats[phase]
            validate_status(selected["material_deadline"], hz)
            need(selected["physics"] == "early" and selected["presentation"] == "coherent"
                 and selected["cadence"] == "repaired" and selected["rendezvous"]["mode"] == "off",
                 "Deadline cohort changed native/physical/presentation policy")
    parity = physical_outcome_parity(arms)
    need(parity["same_source_pairs_equal"] is True,
         "Deadline arm changed equal-step body/admitted-input outcomes; causal timing attribution refused")
    comparisons = {}
    for name, indices in registration["comparisons"].items():
        subset = [dict(arms[index], index=position, arm="D" if position in (0, 3) else "C")
                  for position, index in enumerate(indices)]
        comparisons[name] = compare_registered_direction(subset)
    return {"physical_outcome_parity": parity, "registered_directions": comparisons,
            "physical_acceptance": "HOLD", "scope": "All six same-source arms and negative controls retained; rate selection also requires freshness/visual and sustained mixed evidence."}
