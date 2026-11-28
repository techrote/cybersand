#!/usr/bin/env python3
"""Supplement validated V3 receipts with narrowly defined responsiveness clocks.

This module is not a replacement for results_same_frame.reduce_receipt. The
runner invokes that frozen oracle first. No input-delivery, GPU-completion,
scanout or actual displayed-pose timestamps exist in that observation stream.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pubpres_playability"))
from results import distribution, need
from identity_domains import object_id, texture_rid


def _duration(rows):
    return distribution((row["time_usec"] - row["start_usec"]) / 1000 for row in rows)


def supplementary_metrics(receipt: Path) -> dict:
    """Read immutable evidence after the caller has passed the original oracle."""
    data = json.loads(receipt.read_bytes())
    trace = receipt.with_name(receipt.stem + "-events.jsonl")
    need(hashlib.sha256(trace.read_bytes()).hexdigest() == data["trace_sha256"],
         "Supplementary trace hash differs")
    rows = [json.loads(line) for line in trace.read_text().splitlines()]
    need(rows[0]["event"] == "identity" and rows[0]["source"] == data["source_identity"],
         "Supplementary trace identity differs")
    steps = sorted((row for row in rows if row["event"] == "rapier_step"), key=lambda row: row["step"])
    need(len(steps) >= 144 and all(b["step"] == a["step"] + 1
                                 and b["time_usec"] >= a["time_usec"]
                                 for a, b in zip(steps, steps[1:])), "Invalid actual physical sequence")
    return {
        "schema": "pubpres-final-supplementary-metrics-v1",
        "receipt_sha256": hashlib.sha256(receipt.read_bytes()).hexdigest(),
        "trace_sha256": data["trace_sha256"],
        "source": data["source_identity"]["source_sha"],
        "windows": {
            "first_144_steps": measure_window(rows, data, steps[143]["time_usec"]),
            "whole_capture": measure_window(rows, data, data["capture_end_usec"]),
        },
        "scope": {
            "admission_latency": "Actual application command admission to the next completed physical step. Input is tick-addressed; this is NOT wall-clock device/input-delivery latency.",
            "draw_delivery": "Main-thread frame_post_draw delivery, NOT a GPU fence or physical scanout.",
            "material_age": "Original native material generation to matching inline Main render-serial notification only. Separate notifications are deferred to Main and have no upload-specific draw identity; those material-age joins remain unavailable.",
            "physical_age": "Age of the latest completed physical step when draw callback is delivered. This is NOT proof that that pose was displayed.",
            "native_duration": "Native-reported elapsed tick duration from the first healthy packet per consumed sample; may include scheduling/preemption.",
            "overlap": "Observed interval overlap is descriptive. It does NOT by itself assign a driver, hardware or scheduler root cause.",
            "validation": "Supplementary timing only; original V3 source/native/terrain/callback/body/input/Water/current-GPU gates must independently pass.",
        },
    }


def measure_window(rows: list[dict], data: dict, end: int) -> dict:
    start = data["capture_start_usec"]
    selected = [row for row in rows if start <= row.get("time_usec", -1) <= end]
    by_kind = {kind: sorted((row for row in selected if row["event"] == kind),
                            key=lambda row: row["time_usec"])
               for kind in ("rapier_step", "command_attempt", "texture_upload", "framebuffer_draw",
                            "main_callback", "physics_callback")}
    steps = by_kind["rapier_step"]
    commands = by_kind["command_attempt"]
    first_commands = {}
    commands_by_sequence = {}
    for row in commands:
        first_commands.setdefault(row["absolute_tick"], row)
        commands_by_sequence[row["sequence_after"]] = row
    first_latency, consumed_latency = [], []
    for step in steps:
        first = first_commands.get(step["step"] - 1)
        consumed = commands_by_sequence.get(step["command_sequence"])
        need(first is not None and consumed is not None
             and first["time_usec"] <= consumed["time_usec"] <= step["time_usec"],
             "Completed step has no preceding admitted command for supplementary clocks")
        first_latency.append((step["time_usec"] - first["time_usec"]) / 1000)
        consumed_latency.append((step["time_usec"] - consumed["time_usec"]) / 1000)

    packets = {}
    for row in sorted((row for row in rows if row["event"] == "worker_snapshot"),
                      key=lambda row: row["time_usec"]):
        if not row["failed"] and row["hard_surface_revision"] == row["required_hard_revision"]:
            key = (row["world_generation"], row["tick_index"], row["completed_body_sample"],
                   row["required_hard_revision"])
            packets.setdefault(key, row)
    durations, native_to_handoff, handoff_to_callback = [], [], []
    completion_during_upload = 0
    for step in steps:
        key = (step["world_generation"], step["native_tick_used"], step["completed_body_sample"],
               step["required_hard_revision"])
        packet = packets.get(key)
        if packet is not None:
            durations.append(packet["native_tick_ms"])
            completed = step.get("native_completed_usec")
            handoff = packet.get("physics_handoff_usec")
            if completed is not None and completed > 0 and handoff is not None and handoff > 0:
                need(handoff >= completed, "Earliest eligible handoff predates actual native completion")
                native_to_handoff.append((handoff - completed) / 1000)
                # A negative value is legal if a real callback already began
                # before a nonblocking handoff. Preserve it, do not clamp it.
                handoff_to_callback.append((step["start_usec"] - handoff) / 1000)
        completed = step.get("native_completed_usec")
        if completed is not None and completed > 0 and any(
                upload["start_usec"] <= completed <= upload["time_usec"]
                for upload in by_kind["texture_upload"]):
            completion_during_upload += 1

    draws = by_kind["framebuffer_draw"]
    uploads = by_kind["texture_upload"]
    draw_identity_available = bool(draws) and all(draw.get("inline_main") is True
                                                 and type(draw.get("render_serial")) is int
                                                 and draw["render_serial"] > 0 for draw in draws)
    material_age, upload_to_draw, unmatched = [], [], 0
    for upload in uploads:
        if not draw_identity_available:
            continue
        matching = next((draw for draw in draws
                         if draw["time_usec"] >= upload["time_usec"]
                         and draw["render_serial"] == upload["render_serial"]), None)
        if matching is None:
            unmatched += 1
            continue
        upload_to_draw.append((matching["time_usec"] - upload["time_usec"]) / 1000)
        if upload["generated_usec"] > 0:
            material_age.append((matching["time_usec"] - upload["generated_usec"]) / 1000)
    physical_age = []
    for draw in draws:
        preceding = [step for step in steps if step["time_usec"] <= draw["time_usec"]]
        if preceding:
            physical_age.append((draw["time_usec"] - preceding[-1]["time_usec"]) / 1000)
    gaps = [(b["time_usec"] - a["time_usec"]) / 1000 for a, b in zip(steps, steps[1:])]
    callbacks = by_kind["physics_callback"]
    need(all(step["execution_kind"] == "physics_callback" for step in steps),
         "This registration only accepts ordinary physical callbacks")
    return {
        "start_usec": start, "end_usec": end, "completed_real_steps": len(steps),
        "actual_engine_callbacks": len(callbacks),
        "completed_steps_per_second": len(steps) / ((end - start) / 1_000_000),
        "physical_completion_gaps_ms": distribution(gaps),
        "gap_counts_above_ms": {str(value): sum(gap > value for gap in gaps)
                                for value in (100, 250, 500, 1000)},
        "first_admitted_command_for_tick_to_step_ms": distribution(first_latency),
        "consumed_command_to_step_ms": distribution(consumed_latency),
        "native_tick_ms": distribution(durations),
        "native_complete_to_first_eligible_handoff_ms": distribution(native_to_handoff),
        "first_eligible_handoff_to_callback_start_ms": distribution(handoff_to_callback),
        "native_completion_during_observed_upload_count": completion_during_upload,
        "rapier_solver_ms": distribution(step["solver_usec"] / 1000 for step in steps),
        "real_callback_to_completion_ms": _duration(steps),
        "main_callback_ms": _duration(by_kind["main_callback"]),
        "upload_call_ms": _duration(uploads),
        "upload_count": len(uploads),
        "material_draw_identity_available": draw_identity_available,
        "unknown_draw_identity_notifications": sum(draw.get("inline_main") is not True for draw in draws),
        "material_draw_unavailable_reason": None if draw_identity_available else
            "No complete inline draw identity: Separate delivers notifications later on Main, so its live material serial cannot identify the completed draw.",
        "unmatched_uploads_at_window_end": unmatched if draw_identity_available else None,
        "matching_upload_return_to_draw_delivery_ms": distribution(upload_to_draw),
        "matching_material_generation_to_draw_delivery_ms": distribution(material_age),
        "latest_physical_completion_age_at_draw_delivery_ms": distribution(physical_age),
        "delivered_draw_gap_ms": distribution((b["time_usec"] - a["time_usec"]) / 1000
                                              for a, b in zip(draws, draws[1:])),
    }


def validate_deadline_baseline(data, *, required: bool):
    """An ordinary control cannot silently acquire the new deadline treatment."""
    need(type(required) is bool, "Deadline baseline availability must be explicit")
    for phase in ("selectors_before", "selectors_after"):
        selected = data[phase]
        need(selected["requested"].get("CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ") == "0"
             and "material_deadline" in selected, "Ordinary deadline control was not observed")
        status = selected["material_deadline"]
        if not required:
            need(status is None, "Frozen source unexpectedly acquired a material deadline API")
            continue
        need(isinstance(status, dict) and status.get("schema") == "pubpres-material-deadline-v1"
             and status.get("enabled") is False and status.get("physical_credit") is False,
             "Ordinary source acquired enabled deadline policy or lost effective status")
        for key in ("requested_hz", "interval_usec", "pending_count", "offers", "replaced_offers",
                    "consumptions", "accepted_uploads", "cancellations"):
            need(type(status.get(key)) is int and status[key] == 0,
                 "Ordinary off control acquired material scheduling work: " + key)
        for key in ("pending_serial", "pending_generation", "deadline_usec", "next_upload_usec"):
            need(type(status.get(key)) is int and status[key] == -1,
                 "Ordinary off control retained pending material authority: " + key)
    return {"requested_hz": 0, "effective_api_present": required, "verified_off": required,
            "frozen_absence_verified": not required,
            "scope": "Source-bound policy observation only; no physical, draw or upload credit."}


def validate_slot_treatment(data: dict, events: list[dict], slots: int, require_status: bool,
                            *, expected_extent: list[int] | None = None) -> dict:
    """Adversarial treatment validation independent of the publisher's oracle."""
    need(type(slots) is int and slots in (2, 3), "Unregistered slot treatment")
    extent = None
    if slots == 3:
        # Authored fixtures include extent in their receipt. The unchanged
        # generated reference2048 fixture instead records its recipe/generated
        # hashes; its dimensions come from the source-bound campaign that the
        # complete physical reducer has already validated. Never infer dimensions
        # from claimed allocation bytes, or fill a missing size with a guess.
        observed_extent = data.get("fixture", {}).get("extent")
        extent = expected_extent if expected_extent is not None else observed_extent
        need(isinstance(extent, list) and len(extent) == 2
             and all(type(value) is int and value > 0 for value in extent),
             "Ring allocation has no valid registered fixture extent")
        if observed_extent is not None:
            need(observed_extent == extent and all(type(value) is int for value in observed_extent),
                 "Observed fixture extent differs from registered extent")
    for phase in ("selectors_before", "selectors_after"):
        selector = data[phase]
        need(selector["requested"].get("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") == str(slots),
             "Requested slot treatment differs")
        status = selector["material"]
        need(status["backend"] == "full", "Slot experiment changed material backend")
        if require_status or "full_image_slots" in status:
            need(status.get("full_image_slots_requested") == str(slots)
                 and status.get("full_image_slots") == slots, "Slot treatment did not reach live publisher")
        else:
            need(slots == 2, "Historical publisher cannot supply three slots")
    uploads = [row["material"] for row in events if row["event"] == "texture_upload"]
    need(uploads, "No actual uploads in slot experiment")
    identities = []
    allocation = None
    for status in uploads:
        need(status["backend"] == "full", "Upload changed material backend")
        if require_status or "full_image_slots" in status:
            need(status.get("full_image_slots_requested") == str(slots)
                 and status.get("full_image_slots") == slots, "Upload changed effective slot treatment")
        if slots == 3:
            need(status.get("full_image_slot_count") == 3, "Ring has a different slot count")
            ids, rids = status.get("texture_ids"), status.get("texture_rids")
            need(isinstance(ids, list) and isinstance(rids, list)
                 and len(ids) == len(set(ids)) == len(rids) == len(set(rids)) == 3
                 and all(object_id(value) for value in ids) and all(texture_rid(value) for value in rids),
                 "Ring texture identities are missing or alias")
            identity = (tuple(ids), tuple(rids))
            identities.append(identity)
            current, previous, spare, upload = (status.get(key) for key in
                                                ("current_slot", "previous_slot", "spare_slot", "upload_slot"))
            need({current, previous, spare} == {0, 1, 2} and upload == current,
                 "Ring slot role or published upload slot is inconsistent")
            declared_bytes = status.get("allocated_logical_gpu_bytes")
            need(declared_bytes == 3 * extent[0] * extent[1] * 2,
                 "Ring logical RG8 storage differs from registered extent")
            allocation = declared_bytes
    if slots == 3:
        need(len(set(identities)) == 1, "Ring replaced texture identities during capture")
    return {"requested_slots": slots, "effective_slots_verified": require_status or slots == 3,
            "historical_two_slot_scope": not require_status,
            "uploads_checked": len(uploads), "fixed_texture_ids": list(identities[0][0]) if identities else None,
            "fixed_texture_rids": list(identities[0][1]) if identities else None,
            "logical_gpu_bytes": allocation, "registered_extent": extent,
            "scope": "Fixed logical allocation/roles and requested/effective treatment, not GPU residency or fence proof."}
