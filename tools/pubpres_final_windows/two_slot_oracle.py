#!/usr/bin/env python3
"""Independent exact-byte/owner validation for the frozen two-slot GPU oracle."""
from __future__ import annotations

import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pubpres_final"))
from qualification_oracles import _context, _history, _success, file_digest, need, transition_expectations

FIXTURE = "res://tests/pubpres_final_two_slot_oracle.gd"


def validate(path: Path, project: Path, *, source: str, driver: str,
             engine_sha256: str, separate: bool) -> dict:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    _success(data, "pubpres-source-transition-history-v1")
    # The inherited fixture emits these additional live observations inside its
    # final history dictionary. Pass that exact observation to the shared custody
    # checker without changing the original receipt or any expected value.
    context_view = dict(data, render_thread_inline=data["history"]["render_thread_inline"],
                        publisher_sha256=data["history"]["publisher_sha256"])
    _context(context_view, source, project, driver, engine_sha256, separate, FIXTURE, shader=True)
    need(data["application_main_sha256"] == file_digest(project / "scripts/main.gd"), "Two-slot Main differs")
    need(data["frames_checked"] == data["current_matches"] == data["previous_matches"] == 180
         and data["case"] == "transition_2048_w1" and data["tape"] == "transition"
         and data["sparse_entries"] == 15, "Two-slot tape/first-read coverage differs")
    expected = transition_expectations()
    need(data["initial_plane_sha256"] == expected["initial"], "Two-slot initial substrate differs")
    _history(data["warmup_history"], *expected["warmup"])
    _history(data["history"], *expected["terminal"])
    need(data["entry_history"] == expected["entries"], "Two-slot exact sparse-entry GPU histories differ")
    rows = data["admissions"]
    need(len(rows) == 180, "Two-slot admissions missing")
    owners = None
    previous_pair = None
    for sequence, row in enumerate(rows, 30):
        need(row["sequence"] == sequence and row["revision"] == sequence + 1
             and row["current_matches"] is True and row["previous_matches"] is True,
             "Two-slot admission ordering or first-read history differs")
        status = row["material"]
        need(status["requested_mode"] == status["mode"] == status["backend"] == "full"
             and status["driver"] == driver and status["fallback_reason"] == ""
             and status["full_image_slots_requested"] == "2" and status["full_image_slots"] == 2
             and status["logical_source_format"] == status["gpu_storage_format"] == "RG8"
             and status["submitted_bytes"] == 2048 * 2048 * 2, "Two-slot policy/bytes differ")
        pair = (status["two_slot_current_rid"], status["two_slot_previous_rid"])
        need(pair[0] != pair[1] and all(type(value) is int and value > 0 for value in pair), "Two-slot owners alias")
        if owners is None:
            owners = set(pair)
        need(set(pair) == owners and (previous_pair is None or pair == previous_pair[::-1]), "Two-slot owners changed or did not alternate")
        previous_pair = pair
    data["independent_validation"] = {"schema": "pubpres-final-two-slot-oracle-v1", "exact_hashes_checked": 35,
                                      "slot_admissions_checked": 180, "actual_engine_sha256": engine_sha256,
                                      "scope": "Untimed first GPU reads; no physical progression or scanout claim."}
    return data
