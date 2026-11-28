#!/usr/bin/env python3
"""Additive count-admission evidence after the unchanged complete V3 oracle.

No scheduling counter is a physical witness. Each new accepted anchor must join
an original actual Rapier event, while every delivered material identity joins
the original upload trace. An unobserved transaction is refused, not guessed.
"""
from __future__ import annotations

from bisect import bisect_right
import json
from pathlib import Path

from run_comparison import ROOT
from run_campaign import physical_outcome_parity
from run_focus import validate_complete_comparison
from run_source_abba import compare_registered_direction
from renderer_contract import FROZEN_V3_SHA256
from results import digest, distribution, need
from material_steps_status import COUNTERS, SELECTOR, integer, live_bridge_identity, signed64, validate_status
from metrics import validate_deadline_baseline

OBSERVER = "tests/pubpres_final_material_steps_gameplay.gd"
RESOURCE = "tests/pubpres_final_material_steps_registration.json"


def validate_registration(registration: dict) -> None:
    need(type(registration) is dict
         and registration.get("schema") == "pubpres-final-material-steps-registration-v1"
         and type(registration.get("order")) is list
         and all(type(value) is int for value in registration["order"])
         and registration["order"] == [0, 2, 2, 0]
         and registration.get("primary_cases") == ["wave_512_follow", "wave_gameplay_2048_follow"]
         and all(type(registration.get(key)) is type(expected) and registration[key] == expected
                 for key, expected in {"material": "full", "full_image_slots": 2, "render_thread": "safe",
                     "physics": "early", "presentation": "coherent", "material_deadline_hz": 0,
                     "same_frame_continuation": False, "presentation_observer": True,
                     "minimum_capture_usec": 10000000, "minimum_real_steps": 144,
                     "maximum_capture_usec": 90000000, "maximum_status_samples": 6000,
                     "scheduled_added_hold_usec": 16667, "source_age_guard_usec": 1000000}.items())
         and registration.get("require_treatment_exercise") == ["deferred_turns", "replaced_offers", "independently_joined_count_due"],
         "Count registration changed a control, scalar domain or treatment-exercise premise")


def verify_contract(root: Path = ROOT) -> dict:
    frozen = root / "tools/pubpres_playability/results_same_frame.py"
    observer = root / "tools/pubpres_final/pubpres_final_material_steps_gameplay.gd"
    registration = json.loads((root / "tools/pubpres_final/material_steps_registration.json").read_bytes())
    need(digest(frozen) == FROZEN_V3_SHA256, "Frozen complete physical oracle changed")
    need(observer.read_text().startswith('extends "res://tests/pubpres_final_gameplay.gd"\n'),
         "Count observer no longer inherits the original sole-worker/real-callback fixture")
    validate_registration(registration)
    need(digest(root / "godot/scripts/material_publication_steps.gd") == registration["policy_sha256"],
         "Count experiment changed its registered policy law")
    return {"frozen_v3_sha256": digest(frozen), "observer_sha256": digest(observer),
            "policy_sha256": registration["policy_sha256"], "physical_credit": False}


def _material(value: dict) -> dict:
    need(type(value) is dict and set(value) == {"serial", "generation", "generated_usec"}
         and all(integer(value.get(key), 1) for key in value), "Actual uploaded material identity is unavailable")
    return value


def _same_material(upload: dict) -> dict:
    return {"serial": upload["render_serial"], "generation": upload["world_generation"],
            "generated_usec": upload["generated_usec"]}


def validate_evidence(data: dict, events: list[dict], header: dict, rows: list[dict], interval: int,
                      maximum: int = 6000) -> dict:
    begin, end = data["capture_start_usec"], data["capture_end_usec"]
    need(integer(begin, 1) and integer(end, begin + 1)
         and header.get("event") == "material_steps_identity"
         and header.get("schema") == "pubpres-material-steps-observer-v1"
         and header.get("source") == data["source_identity"] and header.get("case_nonce") == data["case_nonce"]
         and type(header.get("capture_start_usec")) is int and header["capture_start_usec"] == begin
         and type(header.get("capture_end_usec")) is int and header["capture_end_usec"] == end,
         "Count sidecar belongs to another capture/source")
    need(header.get("overflow") is False and type(header.get("maximum_samples")) is int
         and header["maximum_samples"] == maximum and integer(header.get("samples"), 1)
         and header["samples"] == len(rows) and 0 < len(rows) <= maximum,
         "Missing or truncated count observation stream")
    for selected in (data["selectors_before"], data["selectors_after"]):
        need(selected["requested"].get(SELECTOR) == str(interval)
             and selected.get("material_steps_api_present") is True, "Count request/API changed")
        validate_status(selected.get("material_steps"), interval)
    validate_deadline_baseline(data, required=True)
    before, after = data["selectors_before"], data["selectors_after"]
    need(header["start_status"] == before["material_steps"]
         and header["start_material"] == before["material_steps_uploaded"], "Pre-capture count/material identity differs")
    initial, final = _material(header["start_material"]), _material(header["end_material"])
    start, ending = header["start_status"], header["end_status"]
    validate_status(ending, interval)
    owner = data["physical_owner_before"]
    expected_owner = [owner["session"], owner["epoch"], initial["generation"], live_bridge_identity(owner["bridge"])]
    need(all(signed64(value) and value > 0 for value in expected_owner[:3]),
         "Count capture lacks its actual fixed physical owner")
    boundary_step = data["capture_physical_tick_start"]
    need(integer(boundary_step), "Missing exact pre-capture physical boundary")
    steps = sorted((row for row in events if row["event"] == "rapier_step"), key=lambda row: row["step"])
    need(len(steps) >= 144 and steps[0]["step"] == boundary_step + 1
         and all(integer(row.get(key), 1) for row in steps for key in ("step", "manual_steps", "time_usec"))
         and all([row["session"], row["epoch"], row["world_generation"]] == expected_owner[:3]
                 and begin <= row["time_usec"] <= end for row in steps)
         and all(b["step"] == a["step"] + 1 and b["manual_steps"] == a["manual_steps"] + 1
                 and b["time_usec"] > a["time_usec"] for a, b in zip(steps, steps[1:])),
         "Count observations require complete independently validated physical completions")
    step_clocks = [row["time_usec"] for row in steps]
    boundary_manual = steps[0]["manual_steps"] - 1
    uploads = sorted((row for row in events if row["event"] == "texture_upload"), key=lambda row: row["time_usec"])
    draws = sorted((row for row in events if row["event"] == "framebuffer_draw"), key=lambda row: row["time_usec"])
    need(uploads and len(rows) == len(draws), "Count polls do not cover actual draw notifications")
    previous, material, uploaded_index, previous_clock = start, initial, 0, begin
    accepted = []

    def observe(status: dict, clock: int, selected_uploads: list[dict]):
        nonlocal previous
        validate_status(status, interval)
        need(all(status[key] >= previous[key] for key in COUNTERS), "Count counter regressed")
        if interval:
            need(status["identity"] in ([], expected_owner)
                 and status["cancellations"] == previous["cancellations"]
                 and status["accepted_uploads_after_policy_cancellation"] == previous["accepted_uploads_after_policy_cancellation"]
                 and status["edit_requests"] == previous["edit_requests"]
                 and status["paint_generation"] == previous["paint_generation"]
                 and status["paint_force"] is False and status["paint_busy"] is False,
                 "Ordinary count capture changed owner, rejected an upload or acquired a paint escape")
            count = status["accepted_uploads"] - previous["accepted_uploads"]
            need(count == status["consumptions"] - previous["consumptions"] == len(selected_uploads)
                 and count <= 1, "Status polls cannot certify every actual accepted material transaction")
            if selected_uploads:
                upload = selected_uploads[0]
                need(status["identity"] == expected_owner and status["anchor_uploaded_serial"] == upload["render_serial"]
                     and upload["time_usec"] <= status["anchor_uploaded_usec"] <= clock,
                     "Accepted count anchor is not the actual uploaded material")
                need(status["last_source_age_usec"] >= 0, "Accepted material has no comparable source clock")
                taken = upload["generated_usec"] + status["last_source_age_usec"]
                need(previous_clock <= taken <= upload["start_usec"]
                     and status["last_hold_usec"] <= taken
                     and taken - status["last_hold_usec"] >= previous["anchor_uploaded_usec"],
                     "Policy take/first-offer clocks contradict actual Main upload ordering")
                completed_count = bisect_right(step_clocks, taken)
                joined = completed_count > 0
                if joined:
                    latest = steps[completed_count - 1]
                    expected_anchor = (latest["step"], latest["manual_steps"])
                    join_scope = "latest_observed_completion_at_take"
                else:
                    # The unchanged physical oracle binds the capture boundary
                    # and contiguous first observed step. This proves the live
                    # counter at entry, not an unseen pre-capture completion time.
                    expected_anchor = (boundary_step, boundary_manual) if boundary_step > 0 else (-1, -1)
                    join_scope = "pre_capture_boundary" if boundary_step > 0 else "pre_capture_without_completion"
                need((status["anchor_session_step"], status["anchor_rapier_step"]) == expected_anchor,
                     "Material anchor is not the latest genuinely completed step at policy take")
                # take_due -> consume_render_snapshot -> complete is synchronous
                # on Main; neither upload nor policy completion yields a callback.
                need(bisect_right(step_clocks, status["anchor_uploaded_usec"]) == completed_count,
                     "A Rapier completion appeared inside the synchronous Main material transaction")
                prior_step = previous["anchor_session_step"]
                due = prior_step > 0 and status["anchor_session_step"] - prior_step >= interval
                if prior_step > 0 and status["anchor_session_step"] > 0:
                    need(status["anchor_session_step"] - prior_step == status["anchor_rapier_step"] - previous["anchor_rapier_step"],
                         "Count anchor advanced incompatible physical counters")
                need(status["last_count_due"] is due, "Count eligibility differs from independently joined actual steps")
                reason = status["last_consumption_reason"]
                need(reason in ("completed_step_interval", "scheduled_hold_deadline", "initial_or_new_world", "no_compatible_completed_step"),
                     "Ordinary capture used an unregistered immediate-material escape")
                if reason == "completed_step_interval":
                    need(due, "Count-triggered upload lacks actual completed-step eligibility")
                if reason == "scheduled_hold_deadline":
                    need(status["last_deadline_due"] is True and not due, "Deadline fallback forged count priority")
                if prior_step > 0:
                    need(reason in ("completed_step_interval", "scheduled_hold_deadline"),
                         "Established ordinary owner unexpectedly lost its physical completion witness")
                if previous["pending_count"]:
                    need(taken - status["last_hold_usec"] == previous["first_offer_usec"],
                         "Pending replacement renewed the original first-offer clock")
                    # A replacement may shorten the source-age guard, never extend it.
                    need((not status["last_deadline_due"] and taken < previous["deadline_usec"])
                         or status["last_deadline_due"] and status["last_deadline_overrun_usec"] >= max(0, taken - previous["deadline_usec"]),
                         "Pending fixed deadline was renewed or its actual overrun hidden")
                accepted.append({"uploaded_serial": upload["render_serial"], "upload_start_usec": upload["start_usec"],
                                 "upload_return_usec": upload["time_usec"], "policy_taken_usec": taken,
                                 "independently_joined_step": status["anchor_session_step"] if joined else None,
                                 "anchor_join_scope": join_scope,
                                 "previous_anchor_step": prior_step, "reason": reason,
                                 "count_due": due, "deadline_due": status["last_deadline_due"],
                                 "hold_usec": status["last_hold_usec"], "deadline_overrun_usec": status["last_deadline_overrun_usec"],
                                 "source_age_usec": status["last_source_age_usec"]})
            if status["pending_count"]:
                need(status["pending_serial"] > material["serial"]
                     and status["pending_generation"] == material["generation"]
                     and 0 < status["pending_generated_usec"] <= clock
                     and 0 < status["first_offer_usec"] <= clock,
                     "Pending material is stale, foreign or uses an invented source clock")
                if previous["pending_count"] and not selected_uploads:
                    need(status["first_offer_usec"] == previous["first_offer_usec"]
                         and status["deadline_usec"] <= previous["deadline_usec"],
                         "Replacing a pending offer renewed its fixed hold")
        previous = status

    for row, draw in zip(rows, draws):
        need(row.get("event") == "material_steps_delivery"
             and integer(row.get("time_usec"), 1) and previous_clock <= row["time_usec"] <= end
             and integer(row.get("delivered_draw_usec"), 1)
             and row["delivered_draw_usec"] == draw["time_usec"] <= row["time_usec"]
             and all(integer(row.get(key)) and row[key] == draw[key] for key in ("process_frame", "rendered_frames"))
             and row.get("inline_main") is True and draw.get("inline_main") is True
             and all(integer(row.get(key), 1) for key in ("draw_render_serial", "uploaded_serial", "uploaded_generation", "uploaded_generated_usec"))
             and row["draw_render_serial"] == row["uploaded_serial"] == draw["render_serial"]
             and integer(row.get("observer_usec")), "Count observation lacks its actual Safe draw and material identity")
        chosen = []
        while uploaded_index < len(uploads) and uploads[uploaded_index]["time_usec"] <= draw["time_usec"]:
            upload = uploads[uploaded_index]
            need(begin <= upload["start_usec"] <= upload["time_usec"] <= end, "Actual upload left the measured interval")
            material = _same_material(upload)
            chosen.append(upload)
            uploaded_index += 1
        need(_material({"serial": row["uploaded_serial"], "generation": row["uploaded_generation"],
                        "generated_usec": row["uploaded_generated_usec"]}) == material
             and material["generated_usec"] <= draw["time_usec"], "Displayed material age uses a newer unuploaded packet")
        observe(row["status"], row["time_usec"], chosen)
        previous_clock = row["time_usec"]
    trailing = uploads[uploaded_index:]
    if trailing:
        material = _same_material(trailing[-1])
    need(final == material == _same_material(uploads[-1]), "End material differs from the last actual upload")
    observe(ending, end, trailing)
    need(all(after["material_steps"][key] >= ending[key] for key in COUNTERS),
         "Post-cleanup policy counters precede capture-end counters")
    delta = {key: ending[key] - start[key] for key in COUNTERS}
    if interval:
        need(delta["consumptions"] == delta["accepted_uploads"] == len(uploads)
             and delta["offers"] == delta["accepted_uploads"] + delta["replaced_offers"]
                 + ending["pending_count"] - start["pending_count"],
             "Actual upload and cumulative immutable offer accounting does not balance")
    exercise = {"deferred_turns": delta["deferred_turns"] > 0,
                "replaced_offers": delta["replaced_offers"] > 0,
                "independently_joined_count_due": any(row["reason"] == "completed_step_interval"
                     and row["count_due"] and row["independently_joined_step"] is not None for row in accepted)}
    independent_count = any(row["count_due"] and not row["deadline_due"]
                            and row["independently_joined_step"] is not None for row in accepted)
    return {"schema": "pubpres-material-steps-analysis-v1", "requested_interval": interval,
            "effective_interval": ending["effective_interval"], "capture_policy_counters": delta,
            "accepted_transactions": accepted, "treatment_exercise": exercise,
            "treatment_exercised": interval == 2 and all(exercise.values()), "physical_credit": False,
            "independent_count_before_deadline_observed": independent_count,
            "independent_count_before_deadline_attribution": "OBSERVED" if independent_count else "NOT_ESTABLISHED",
            "coalescing_population": "observed_coalescing" if delta["replaced_offers"] > 0 else "no_coalescing",
            "windows": {"first_144_steps": _window(rows, uploads, accepted, header, steps[143]["time_usec"]),
                        "whole_capture": _window(rows, uploads, accepted, header, end)},
            "scope": {"physical": "Only the unchanged complete V3 oracle supplies actual Rapier steps; each accepted policy anchor must equal the latest original completion at take, with no completion during the synchronous Main upload/complete transaction. Before the first observed completion, only the exact capture boundary counter is admitted and it cannot supply independent treatment exercise.",
                      "display": "Safe draw delivery binds actual uploaded material; GPU completion, scanout and physical display latency remain unknown.",
                      "status": "Every accepted transaction is observed individually; captures with multiple uploads between status observations are refused rather than reconstructed.",
                      "first_144_counters": "At step144, policy deltas end at the last preceding draw poll; trailing unsampled time is explicit.",
                      "selection": "No-op, deadline-only and adverse arms remain evidence. All three registered exercise premises are mandatory before attributing a count2 treatment."}}


def _window(rows, uploads, accepted, header, end):
    begin = header["capture_start_usec"]
    selected = [row for row in rows if begin <= row["time_usec"] <= end]
    chosen = [row for row in uploads if begin <= row["time_usec"] <= end]
    transactions = [row for row in accepted if row["upload_return_usec"] <= end]
    pending = [row for row in selected if row["status"]["pending_count"]]
    final, through = (header["end_status"], end) if end == header["capture_end_usec"] else \
        (selected[-1]["status"], selected[-1]["time_usec"]) if selected else (header["start_status"], begin)
    return {"start_usec": begin, "end_usec": end, "actual_uploads": len(chosen),
            "actual_uploads_per_second": len(chosen) * 1000000 / (end - begin),
            "upload_return_spacing_ms": distribution((b["time_usec"] - a["time_usec"]) / 1000 for a, b in zip(chosen, chosen[1:])),
            "policy_counters_observed_through_usec": through, "policy_counter_trailing_unsampled_ms": (end - through) / 1000,
            "policy_counter_deltas": {key: final[key] - header["start_status"][key] for key in COUNTERS},
            "draw_polls": len(selected), "pending_at_draw_count": len(pending),
            "oldest_uploaded_material_at_draw_ms": max(((row["delivered_draw_usec"] - row["uploaded_generated_usec"]) / 1000 for row in selected), default=None),
            "material_generation_to_draw_delivery_ms": distribution((row["delivered_draw_usec"] - row["uploaded_generated_usec"]) / 1000 for row in selected),
            "pending_source_age_ms": distribution((row["time_usec"] - row["status"]["pending_generated_usec"]) / 1000 for row in pending),
            "pending_overdue_at_draw_count": sum(row["time_usec"] >= row["status"]["deadline_usec"] for row in pending),
            "actual_selected_hold_ms": distribution(row["hold_usec"] / 1000 for row in transactions),
            "actual_selected_deadline_overrun_ms": distribution(row["deadline_overrun_usec"] / 1000 for row in transactions),
            "count_due_transactions": sum(row["count_due"] for row in transactions),
            "count_due_before_deadline_transactions": sum(row["count_due"] and not row["deadline_due"] for row in transactions),
            "simultaneous_count_and_deadline_transactions": sum(row["count_due"] and row["deadline_due"] for row in transactions),
            "deadline_only_transactions": sum(row["deadline_due"] and not row["count_due"] for row in transactions),
            "deadline_due_transactions": sum(row["deadline_due"] for row in transactions),
            "accepted_eligibility_populations": {
                "count_only": sum(row["count_due"] and not row["deadline_due"] for row in transactions),
                "both": sum(row["count_due"] and row["deadline_due"] for row in transactions),
                "deadline_only": sum(row["deadline_due"] and not row["count_due"] for row in transactions),
                "neither_initial_or_immediate": sum(not row["count_due"] and not row["deadline_due"] for row in transactions)},
            "status_observer_usec": distribution(row["observer_usec"] for row in selected)}


def reduce_evidence(receipt: Path, events: list[dict], interval: int) -> dict:
    data = json.loads(receipt.read_bytes())
    path = receipt.with_name(receipt.stem + "-material-steps-events.jsonl")
    proof = data["selectors_after"].get("material_steps_observer", {})
    need(proof.get("schema") == "pubpres-material-steps-sidecar-v1" and proof.get("sha256") == digest(path)
         and proof.get("overflow") is False and type(proof.get("maximum_samples")) is int
         and proof["maximum_samples"] == 6000, "Count sidecar custody or capacity differs")
    lines = [json.loads(line) for line in path.read_text().splitlines()]
    need(lines and integer(proof.get("samples"), 1) and proof["samples"] == len(lines) - 1, "Count sidecar count differs")
    result = validate_evidence(data, events, lines[0], lines[1:], interval)
    result.update(receipt_sha256=digest(receipt), sidecar_sha256=digest(path))
    return result


def validate_cohort(arms: list[dict], registration: dict) -> dict:
    validate_registration(registration)
    validate_complete_comparison(arms, 4)
    need(all(type(arm.get("index")) is int and type(arm.get("requested_interval")) is int for arm in arms)
         and [arm["requested_interval"] for arm in arms] == registration["order"] == [0, 2, 2, 0]
         and len({arm["statistics"]["source"] for arm in arms}) == 1, "Count cohort changed source or complete registered order")
    for arm in arms:
        stats, policy = arm["statistics"], arm["material_steps"]
        validate_deadline_baseline(stats, required=True)
        need(all(type(policy.get(key)) is int and policy[key] == arm["requested_interval"]
                 for key in ("requested_interval", "effective_interval"))
             and type(policy.get("treatment_exercised")) is bool
             and type(policy.get("independent_count_before_deadline_observed")) is bool
             and policy["physical_credit"] is False
             and type(arm["slots"].get("requested_slots")) is int and arm["slots"]["requested_slots"] == 2
             and arm["slots"]["effective_slots_verified"] is True
             and stats["registered_material_treatment"] == {"backend": "full", "policy": ""}
             and stats["same_frame_continuation"]["enabled"] is False,
             "Count cohort changed material ownership or physical continuation")
        need(arm["observers"]["presentation_enabled"] is True
             and isinstance(arm["observers"]["presentation"], dict) and isinstance(arm["observers"]["cpu"], dict)
             and type(arm["observers"]["material_steps_policy"].get("requested_interval")) is int
             and arm["observers"]["material_steps_policy"]["requested_interval"] == arm["requested_interval"],
             "Count cohort lacks independently verified source-bound policy, presentation or CPU evidence")
        need(type(stats["windows"]["first_144_steps"].get("completed_rapier_steps")) is int
             and stats["windows"]["first_144_steps"]["completed_rapier_steps"] == 144,
             "Count cohort physical-step window uses a coerced or incomplete count")
        for phase in ("selectors_before", "selectors_after"):
            selected = stats[phase]
            validate_status(selected["material_steps"], arm["requested_interval"])
            need(selected["physics"] == "early" and selected["presentation"] == "coherent"
                 and selected["cadence"] == "repaired" and selected["rendezvous"]["mode"] == "off",
                 "Count cohort changed physical/native/cadence policy")
    parity = physical_outcome_parity(arms)
    need(parity["same_source_pairs_equal"] is True, "Count arm changed equal-step physical/input outcomes")
    direction = compare_registered_direction([dict(arm, arm="D" if index in (0, 3) else "C") for index, arm in enumerate(arms)])
    exercised = all(arm["material_steps"]["treatment_exercised"] is True for arm in arms if arm["requested_interval"] == 2)
    # Retain the full physical and presentation result even for a valid no-op.
    # The runner records failure of the exercise gate after saving this packet.
    return {"physical_outcome_parity": parity, "registered_direction": direction,
            "treatment_exercised_in_both_arms": exercised, "physical_acceptance": "HOLD",
            "readings": [{"index": arm["index"], "requested_interval": arm["requested_interval"],
                          "physical_windows": arm["statistics"]["windows"],
                          "material_steps": arm["material_steps"], "supplementary": arm["supplementary"],
                          "presentation": arm["observers"]["presentation"], "cpu": arm["observers"]["cpu"]} for arm in arms],
            "scope": "All four arms, negative/no-op outcomes and complete withholding/censored episodes are retained. Visible-only pose age is not all-actor presentation acceptance; no physical display or default promotion."}
