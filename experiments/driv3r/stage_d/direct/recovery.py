"""Development-only oracle disagreement and hypothetical recovery audit.

No model prediction, native authority, brush action, material rollback or
evaluation of structurally held-out policy outcomes occurs here. This module
measures *opportunities* for a future recovery supervisor, not its efficacy.
"""
from __future__ import annotations

import random
from typing import Any

from . import offline as d
from . import paired

VERSION = "d1a-offline-recovery-opportunities/1"


def _oracle_policy(fixture: d.Fixture) -> str:
    return "contour_astar" if fixture.task == "wall_offset" else "astar"


def _oracle_continuation(fixture: d.Fixture, origin: d.Point,
                         lengths: tuple[int, ...], capacity: int) -> dict[str, Any]:
    """Replay a purely hypothetical geometric oracle from a synthetic cursor.

    It does not modify the original episode or pretend to undo a prior edit.
    The prospective oracle is replanned at each resulting cursor with the
    same legal menu and remaining *decision* cap, rather than estimating
    decisions from distance/maximum macro length.
    """
    d.require_development_fixture(fixture)
    if not 0 <= capacity <= fixture.budget or not fixture.legal(origin):
        raise ValueError("Invalid hypothetical rescue origin/budget")
    position = origin
    moves = 0
    cells = 0
    policy = _oracle_policy(fixture)
    rng = random.Random(0)  # Oracle policy makes no random draws.
    while position != fixture.target and moves < capacity:
        options = d.candidates(fixture, position, lengths)
        selected = d.select_candidate(fixture, position, options, policy, rng)
        if selected.stop or not selected.path:
            break
        if not all(fixture.legal(p) for p in selected.path):
            raise AssertionError("Oracle continuation crossed forbidden cells")
        position = selected.path[-1]
        moves += 1
        cells += len(selected.path)
    return {
        "arrives_within_remaining_decisions": position == fixture.target,
        "hypothetical_oracle_decisions": moves,
        "hypothetical_cursor_cell_steps": cells,
        "remaining_decision_capacity": capacity,
        "final_synthetic_cursor": list(position),
    }


def audit_development_recovery(fixture: d.Fixture,
                               episode: dict[str, Any]) -> dict[str, Any]:
    """Inspect a verified DEVELOPMENT trace without changing its choices.

    An oracle disagreement is an *intervention candidate*, not proof of an
    erroneous choice. Only the FIRST disagreement gets a hypothetical
    deterministic continuation. It starts at the actually simulated
    post-choice cursor, never substitutes a better action into the trace,
    and never reopens a STOP-terminated episode.
    """
    if fixture.split != "development":
        raise ValueError("Held-out behavioral outcomes are sealed")
    custody = paired.verify_episode(fixture, episode)
    lengths = tuple(episode["macro_lengths"])
    policy = _oracle_policy(fixture)
    windows = []
    seen = {fixture.start}
    first = None

    for event in episode["events"]:
        before = tuple(event["observation"]["position"])
        options = d.candidates(fixture, before, lengths)
        by_id = {item.candidate_id: item for item in options}
        chosen = by_id[event["choice_id"]]
        oracle = d.select_candidate(fixture, before, options, policy, random.Random(0))
        newly_retraced = sum(point in seen for point in chosen.path)
        seen.update(chosen.path)
        disagreement = chosen.candidate_id != oracle.candidate_id
        window = {
            "decision_index": event["seq"],
            "pre_cursor": list(before),
            "post_cursor": list(event["simulated_post_position"]),
            "selected_candidate_id": chosen.candidate_id,
            "deterministic_oracle_candidate_id": oracle.candidate_id,
            "oracle_choice_disagreement": disagreement,
            "selected_terminal_stop": chosen.stop,
            "newly_retraced_swept_cells": newly_retraced,
            "remaining_decisions_after_choice": fixture.budget - event["seq"] - 1,
            "original_candidate_set_sha256": event["observation"]["candidate_set_sha256"],
        }
        windows.append(window)
        if disagreement and first is None:
            first = window

    recovery = None
    if first is not None:
        if first["selected_terminal_stop"]:
            recovery = {
                "status": "terminal_stop",
                "arrives_within_remaining_decisions": False,
                "reason": "STOP terminates the original episode; no synthetic resumption or rollback",
                "remaining_decision_capacity": first["remaining_decisions_after_choice"],
            }
        else:
            recovery = {
                "status": "hypothetical_geometric_oracle_continuation",
                **_oracle_continuation(
                    fixture, tuple(first["post_cursor"]), lengths,
                    first["remaining_decisions_after_choice"]
                ),
                "reason": "Counterfactual cursor-only continuation, not native recovery evidence",
            }

    return {
        "version": VERSION,
        "source_kind": "offline_simulation_only",
        "native_qualified": False,
        "sequential_native_receipts": 0,
        "model_evaluated": False,
        "heldout_policy_outcomes_evaluated": False,
        "fixture_sha256": fixture.sha256,
        "verified_original_trajectory_sha256": custody["path_sha256"],
        "verified_original_metrics_sha256": custody["metrics_sha256"],
        "policy_under_audit": episode["policy"],
        "deterministic_reference_policy": policy,
        "decision_windows": windows,
        "first_oracle_choice_disagreement_index":
            None if first is None else first["decision_index"],
        "first_disagreement_recovery": recovery,
        "interpretation": "Oracle disagreement is not an error or demonstrated model value",
    }
