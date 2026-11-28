#!/usr/bin/env python3
"""Independent cumulative-image and admission ledger for deadline correctness.

This is a synthetic-clock, actual-GPU correctness fixture. It earns no timing,
physical-step or playability credit. The image tape, upload ledger and fixed
deadlines are reconstructed here instead of trusting the fixture's assertions.
"""
from __future__ import annotations

from pathlib import Path

from qualification_oracles import (_context, _history, _success, digest,
                                   file_digest, need, terminal)


FIXTURE = "res://tests/test_material_deadline_main_history.gd"
POLICY_FIXTURE = "res://tests/test_material_publication_deadline.gd"
IDENTITY_FIXTURE = "res://tests/test_material_deadline_main_identity.gd"
POLICY = "scripts/material_publication_deadline.gd"
EXTENT = (33, 19)
PATCHES = ((1, 2, 5, 3, 4, 81), (3, 3, 6, 4, 9, 77),
           (0, 0, 2, 19, 12, 63), (4, 4, 3, 2, 18, 42),
           (20, 10, 4, 4, 19, 33))
HISTORY_LABELS = ("initial20", "coalesced24", "delayed_ack25", "same_size_world30")
TRANSACTION_LABELS = ("initial20", "deferred21", "replaced22", "before_deadline24",
                      "coalesced24", "pending25", "delayed_ack25", "pending26",
                      "same_size_world30", "pending31", "closed")
IDENTITY_CASES = ["changed actor epoch", "changed actor session",
                  "incomplete material frame identity", "material and authoritative World disagreement",
                  "pending actor reset", "pending physical replacement", "pending World transaction",
                  "native failure before deadline drain", "failed latest snapshot before deadline drain",
                  "failed offer invalidates pending packet", "actual physical owner closure"]


def plane(material: int, condition: int) -> bytes:
    return bytes((material, condition)) * (EXTENT[0] * EXTENT[1])


def patched_plane(count: int) -> bytes:
    result = bytearray(plane(3, 137))
    for x, y, width, height, material, condition in PATCHES[:count]:
        row = bytes((material, condition)) * width
        for line in range(y, y + height):
            offset = (line * EXTENT[0] + x) * 2
            result[offset:offset + len(row)] = row
    return bytes(result)


def history_expectations() -> list[dict]:
    inputs = [plane(0, 0), plane(3, 137), patched_plane(3), patched_plane(4), plane(6, 120)]
    return [dict(label=label, uploaded_serial=serial, uploaded_generation=generation,
                 current_sha256=digest(inputs[index + 1]), previous_sha256=digest(inputs[index]))
            for index, (label, serial, generation) in enumerate(zip(HISTORY_LABELS, (20, 24, 25, 30), (42, 42, 42, 43)))]


def transaction_expectations(hz: int) -> list[dict]:
    """Registered admission outcomes, not an implementation of the scheduler."""
    need(type(hz) is int and hz in (30, 60), "Unregistered deadline")
    interval = 33334 if hz == 30 else 16667
    # label order follows the fixture's input tape. Omitted serials 21/22/26/31
    # never become accepted material; 25 deliberately replays an unretired prefix.
    uploads = (20, 20, 20, 20, 24, 24, 25, 25, 30, 30, 30)
    pending = (-1, 21, 22, 24, -1, 25, -1, 26, -1, 31, -1)
    offers = (1, 2, 3, 4, 4, 5, 5, 6, 7, 8, 8)
    replacements = (0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2)
    accepted = (1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 4)
    cancellations = (0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2)
    deadline = (-1, 100000 + interval, 100000 + interval, 100000 + interval, -1,
                100000 + 2 * interval, -1, 100000 + 3 * interval, -1, 100002 + 3 * interval, -1)
    next_upload = (100000 + interval,) * 4 + (100000 + 2 * interval,) * 2 \
        + (100000 + 3 * interval,) * 2 + (100002 + 3 * interval,) * 2 + (-1,)
    images = {row["uploaded_serial"]: row["current_sha256"] for row in history_expectations()}
    result = []
    for i, label in enumerate(TRANSACTION_LABELS):
        generation = 42 if i < 8 else 43
        result.append({"hz": hz, "label": label, "uploaded_serial": uploads[i],
                       "uploaded_generation": generation, "cpu_current_sha256": images[uploads[i]],
                       "actual_rapier_steps": 0, "acks": [20, 24, 25, 30][:accepted[i]],
                       "status": {"schema": "pubpres-material-deadline-v1", "requested_hz": hz,
                                  "enabled": True, "interval_usec": interval,
                                  "pending_count": int(pending[i] != -1), "pending_serial": pending[i],
                                  "pending_generation": generation if pending[i] != -1 else -1,
                                  "deadline_usec": deadline[i], "next_upload_usec": next_upload[i],
                                  "offers": offers[i], "replaced_offers": replacements[i],
                                  "consumptions": accepted[i], "accepted_uploads": accepted[i],
                                  "cancellations": cancellations[i], "physical_credit": False,
                                  "last_cancel": "physical_owner_closed" if i == 10 else "identity_changed",
                                  "last_offer_result": "offered"}})
    return result


def _exact(actual, expected, location: str):
    """Strict scalar types prevent bool-as-int and float-rounded identity credit."""
    need(type(actual) is type(expected), "Wrong value type: " + location)
    if isinstance(expected, dict):
        need(actual.keys() == expected.keys(), "Missing or extra ledger fields: " + location)
        for key in expected:
            _exact(actual[key], expected[key], location + "." + key)
    elif isinstance(expected, list):
        need(len(actual) == len(expected), "Incomplete or duplicate ledger: " + location)
        for index, (left, right) in enumerate(zip(actual, expected)):
            _exact(left, right, location + "[" + str(index) + "]")
    else:
        need(actual == expected, "Registered transaction differs: " + location)


def main_history_result(text: str, source: str, project: Path, driver: str,
                        *, engine_sha256: str, slots: int, separate: bool = False) -> dict:
    need(type(slots) is int and slots in (2, 3), "Unregistered Full slot count")
    data = terminal(text, "MATERIAL_DEADLINE_MAIN_RESULT ")
    _success(data, "pubpres-material-deadline-main-history-v1", 46)
    _context(data, source, project, driver, engine_sha256, separate, FIXTURE)
    need(data["synthetic_scheduling_clocks"] is True and data["performance_claim"] is False,
         "Synthetic-clock material fixture cannot earn timing/physical credit")
    for field, relative in (("main_sha256", "scripts/main.gd"),
                            ("worker_sha256", "scripts/simulation_worker.gd"),
                            ("policy_sha256", POLICY)):
        need(data[field] == file_digest(project / relative), "Live source differs: " + relative)
    observed = data["observations"]
    expected = [{"hz": hz, **row} for hz in (30, 60) for row in history_expectations()]
    need(len(observed) == len(expected) == 8, "Incomplete or duplicate GPU histories")
    for row, truth in zip(observed, expected):
        for key in ("hz", "label", "uploaded_serial", "uploaded_generation"):
            _exact(row[key], truth[key], "history." + key)
        _history(row, truth["current_sha256"], truth["previous_sha256"],
                 verified=True, expected_fields=True)
    transactions = [row for hz in (30, 60) for row in transaction_expectations(hz)]
    _exact(data["transactions"], transactions, "transactions")
    rates = [{"hz": hz, "acks": [20, 24, 25, 30], "actual_rapier_steps": 0,
              "full_image_slots": slots, "status": transaction_expectations(hz)[-1]["status"]}
             for hz in (30, 60)]
    _exact(data["rates"], rates, "rates")
    data["independent_validation"] = {"schema": "pubpres-material-deadline-independent-v1",
                                      "actual_engine_sha256": engine_sha256, "gpu_history_pairs": 8,
                                      "transaction_boundaries": 22, "actual_rapier_steps": 0,
                                      "physical_acceptance": "HOLD"}
    return data


def headless_result(test: str, text: str, project: Path) -> dict:
    if test == "test_material_publication_deadline":
        data = terminal(text, "MATERIAL_DEADLINE_RESULT ")
        _success(data, "pubpres-material-deadline-policy-v1", 57)
        need(data["synthetic_clocks"] is True and data["physical_credit"] is False
             and data["policy_sha256"] == file_digest(project / POLICY),
             "Headless policy source/authority differs")
        return data
    need(test == "test_material_deadline_main_identity", "Unregistered headless fixture")
    data = terminal(text, "MATERIAL_DEADLINE_IDENTITY_RESULT ")
    _success(data, "pubpres-material-deadline-main-identity-v1", 25)
    _exact(data["cancelled_cases"], IDENTITY_CASES, "cancelled_cases")
    need(data["synthetic_identity_fields"] is True and data["physical_credit"] is False
         and type(data["gpu_uploads"]) is int and data["gpu_uploads"] == 0
         and data["main_sha256"] == file_digest(project / "scripts/main.gd")
         and data["fixture_sha256"] == file_digest(project / IDENTITY_FIXTURE[6:]),
         "Headless Main identity source/authority differs")
    return data
