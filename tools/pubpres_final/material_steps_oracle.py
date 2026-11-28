#!/usr/bin/env python3
"""Independent seven-pair GPU image, real-ACK and synthetic-policy ledger.

The fixture uses actual Main/worker/Image transactions but synthetic completion
witnesses and clocks. Its zero actual Rapier steps are mandatory, not a timing
result. Expected pixels and all fourteen admission boundaries are reconstructed
from the input tape independently of the fixture's success assertions.
"""
from __future__ import annotations

from pathlib import Path

from material_deadline_oracle import plane, patched_plane, _exact
from material_steps_status import validate_status, integer
from qualification_oracles import (_context, _history, _success, digest,
                                   file_digest, need, terminal)

FIXTURE = "res://tests/test_material_steps_main_history.gd"
POLICY = "scripts/material_publication_steps.gd"
HISTORY_LABELS = ("initial20", "coalesced24", "expired25", "same_size_world30",
                  "recovered33", "paused34", "no_owner35")
LABELS = ("initial20", "deferred21", "replaced22", "held24", "coalesced24", "pending25",
          "expired25", "pending26", "same_size_world30", "pending31", "closed",
          "recovered33", "paused34", "no_owner35")
IDENTITY_CASES = ("changed actor epoch", "changed actor session", "recreated bridge with equal session and epoch",
                  "missing World in material identity", "material versus authoritative World mismatch",
                  "pending actor reset", "pending physical replacement", "pending World transaction",
                  "native failure before drain", "failed latest snapshot", "failed offer retires old packet", "actual owner close")


def history_expectations() -> list[dict]:
    images = [plane(0, 0), plane(3, 137), patched_plane(3), patched_plane(4),
              plane(6, 120), plane(8, 103), plane(9, 101), plane(10, 99)]
    return [{"label": label, "uploaded_serial": serial, "uploaded_generation": 42 if index < 3 else 43,
             "current_sha256": digest(images[index + 1]), "previous_sha256": digest(images[index])}
            for index, (label, serial) in enumerate(zip(HISTORY_LABELS, (20, 24, 25, 30, 33, 34, 35)))]


def transaction_expectations(generated: int) -> list[dict]:
    need(integer(generated, 1), "Missing declared synthetic fixture clock origin")
    now, expired = generated + 1, generated + 1 + 5 + 16667 + 1000
    serials = (20, 20, 20, 20, 24, 24, 25, 25, 30, 30, 30, 33, 34, 35)
    pending = (-1, 21, 22, 24, -1, 25, -1, 26, -1, 31, -1, -1, -1, -1)
    offers = (1, 2, 3, 4, 4, 5, 5, 6, 7, 8, 8, 9, 10, 11)
    accepted = (1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5, 6, 7)
    anchors = (now, now, now, now, now + 4, now + 4, expired, expired,
               expired + 2, expired + 2, -1, expired + 5, expired + 6, expired + 7)
    first_offers = (-1, now + 1, now + 1, now + 1, -1, now + 5, -1, expired + 1,
                    -1, expired + 3, -1, -1, -1, -1)
    images = {row["uploaded_serial"]: row["current_sha256"] for row in history_expectations()}
    result = []
    for index, label in enumerate(LABELS):
        generation = 42 if index < 8 else 43
        anchor_step = 10 if index < 4 else -1 if index in (10, 13) else 12
        latest_consumed = 0 if index < 4 else 4 if index < 6 else 6 if index < 8 else 8 if index < 11 else index
        reason = {0: "initial_or_new_world", 4: "completed_step_interval", 6: "scheduled_hold_deadline",
                  8: "initial_or_new_world", 11: "initial_or_new_world", 12: "paused",
                  13: "no_compatible_completed_step"}[latest_consumed]
        consumed_at = (now if latest_consumed == 0 else now + 4 if latest_consumed == 4 else expired
                       if latest_consumed == 6 else expired + latest_consumed - 6)
        status = {"schema": "pubpres-material-steps-v1", "requested_interval": 2, "effective_interval": 2,
                  "enabled": True, "disabled_reason": "", "scheduled_added_hold_usec": 16667,
                  "source_age_guard_usec": 1000000, "pending_count": int(pending[index] != -1),
                  "pending_serial": pending[index], "pending_generation": generation if pending[index] != -1 else -1,
                  "pending_generated_usec": generated if pending[index] != -1 else -1,
                  "first_offer_usec": first_offers[index],
                  "deadline_usec": first_offers[index] + 16667 if first_offers[index] != -1 else -1,
                  "identity": [] if index == 10 else [0, 0, generation, 0],
                  "anchor_session_step": anchor_step,
                  "anchor_rapier_step": anchor_step + 100 if anchor_step > 0 else -1,
                  "anchor_uploaded_serial": -1 if index == 10 else serials[index], "anchor_uploaded_usec": anchors[index],
                  "paint_force": False, "paint_busy": False, "paint_idle_usec": -1,
                  "paint_generation": 0, "edit_requests": 0, "offers": offers[index],
                  "replaced_offers": 0 if index < 2 else 1 if index == 2 else 2,
                  "deferred_turns": 0 if index == 0 else 1 if index < 3 else 2,
                  "consumptions": accepted[index], "accepted_uploads": accepted[index],
                  "accepted_uploads_after_policy_cancellation": 0,
                  "cancellations": 0 if index < 8 else 1 if index < 10 else 2,
                  "last_cancel": "configuration" if index < 8 else "identity_changed" if index < 10 else "physical_owner_closed",
                  "last_offer_result": "offered", "last_consumption_reason": reason,
                  "last_hold_usec": 3 if latest_consumed == 4 else 17667 if latest_consumed == 6 else 0,
                  "last_deadline_overrun_usec": 1000 if latest_consumed == 6 else 0,
                  "maximum_deadline_overrun_usec": 0 if index < 6 else 1000,
                  "last_source_age_usec": consumed_at - generated,
                  "last_count_due": latest_consumed == 4, "last_deadline_due": latest_consumed == 6,
                  "physical_credit": False}
        witness_step = 10 if index == 0 else 11 if index < 4 else 12
        witness = {} if index == 13 else {"session_step": witness_step, "rapier_step": witness_step + 100,
                                         "completed_usec": generated}
        result.append({"label": label, "uploaded_serial": serials[index], "uploaded_generation": generation,
                       "cpu_current_sha256": images[serials[index]], "actual_rapier_steps": 0,
                       "acks": [20, 24, 25, 30, 33, 34, 35][:accepted[index]],
                       "synthetic_witness": witness, "status": status})
    return result


def main_history_result(text: str, source: str, project: Path, driver: str,
                        *, engine_sha256: str, separate: bool = False) -> dict:
    data = terminal(text, "MATERIAL_STEPS_MAIN_RESULT ")
    _success(data, "pubpres-material-steps-main-history-v1", 32)
    _context(data, source, project, driver, engine_sha256, separate, FIXTURE)
    need(data["synthetic_scheduling_clocks_and_completion_witness"] is True
         and data["performance_claim"] is False and data["physical_credit"] is False
         and type(data["actual_rapier_steps"]) is int and data["actual_rapier_steps"] == 0,
         "Synthetic scheduling fixture claimed physical/timing authority")
    for field, relative in (("main_sha256", "scripts/main.gd"), ("worker_sha256", "scripts/simulation_worker.gd"),
                            ("policy_sha256", POLICY)):
        need(data[field] == file_digest(project / relative), "Live count fixture source differs: " + relative)
    need(len(data["observations"]) == 7 and len(data["transactions"]) == 14, "Incomplete count history/transaction tape")
    for row, truth in zip(data["observations"], history_expectations()):
        for key in ("label", "uploaded_serial", "uploaded_generation"):
            _exact(row[key], truth[key], "history." + key)
        _history(row, truth["current_sha256"], truth["previous_sha256"], verified=True)
    origin = data["transactions"][0]["synthetic_witness"]["completed_usec"]
    for row, truth in zip(data["transactions"], transaction_expectations(origin)):
        validate_status(row["status"], 2, allow_ownerless=True)
        for key, expected in truth.items():
            actual = {name: row["status"][name] for name in expected} if key == "status" else row[key]
            _exact(actual, expected, "transaction." + truth["label"] + "." + key)
    data["independent_validation"] = {"schema": "pubpres-material-steps-independent-v1",
                                      "actual_engine_sha256": engine_sha256, "gpu_history_pairs": 7,
                                      "transaction_boundaries": 14, "actual_rapier_steps": 0,
                                      "physical_acceptance": "HOLD"}
    return data


def headless_result(test: str, text: str, project: Path) -> dict:
    if test == "test_material_publication_steps":
        data = terminal(text, "MATERIAL_STEPS_RESULT ")
        _success(data, "pubpres-material-steps-policy-v1", 123)
        need(data["synthetic_clocks_and_steps"] is True and data["physical_credit"] is False
             and data["policy_sha256"] == file_digest(project / POLICY), "Synthetic count policy source/authority differs")
        return data
    need(test == "test_material_steps_main_identity", "Unregistered count identity fixture")
    data = terminal(text, "MATERIAL_STEPS_IDENTITY_RESULT ")
    _success(data, "pubpres-material-steps-main-identity-v1", 47)
    _exact(data["cancelled_cases"], list(IDENTITY_CASES), "cancelled_cases")
    need(data["synthetic_identity_fields"] is True and data["physical_credit"] is False
         and all(type(data[key]) is int and data[key] == 0 for key in ("native_edits_executed", "actual_rapier_steps", "gpu_uploads"))
         and data["main_sha256"] == file_digest(project / "scripts/main.gd")
         and data["fixture_sha256"] == file_digest(project / "tests/test_material_steps_main_identity.gd"),
         "Count Main identity fixture source or authority differs")
    return data
