"""Strict selected-wall band feasibility beside unconstrained D-1A horizons.

DEVELOPMENT-only geometry analysis: every cell swept by a future move must
remain 6-10 cells from the *selected* wall. This is a necessary feasibility
check for uninterrupted band traversal, not proof of forward contour progress,
native admission, a model's choice, or material edits.
"""
from __future__ import annotations

from math import isfinite
from typing import Any, Callable

from . import horizon, offline as d, paired

VERSION = "d1a-selected-wall-band-horizon/1"


def exact_band_decisions(width: int, height: int, target: tuple[int, int],
                         legal_cell: Callable[[tuple[int, int]], bool],
                         selected_clearance: Callable[[tuple[int, int]], float],
                         lengths: tuple[int, ...] = (1,)) -> dict[tuple[int, int], int]:
    """Exact macro count inside the 6-10-cell band; unreachable cells omitted.

    Unlike an endpoint-only band check, an eight-cell macro is forbidden if
    *any* intermediate cell leaves the clearance band or is otherwise blocked.
    The underlying reverse BFS assumes symmetric, cardinal geometry; it does
    not impose a forward-row/no-retrace constraint.
    """
    if not callable(legal_cell) or not callable(selected_clearance):
        raise ValueError("Host-like legality and selected-wall clearance are required")

    def in_band(p: tuple[int, int]) -> bool:
        admitted = legal_cell(p)
        if type(admitted) is not bool:
            raise ValueError("Host-like legality must return a boolean")
        if not admitted:
            return False
        clearance = selected_clearance(p)
        if type(clearance) not in (int, float) or not isfinite(clearance):
            raise ValueError("Selected-wall clearance must be finite and numeric")
        return 6.0 <= clearance <= 10.0

    if not in_band(target):
        raise ValueError("Selected-wall target is not inside the required band")
    return horizon.exact_remaining_decisions(width, height, target, in_band, lengths)


def audit_development_band_horizon(fixture: d.Fixture,
                                   episode: dict[str, Any]) -> dict[str, Any]:
    """Source-replay original DEVELOPMENT choices without altering trajectories.

    Report an exact *strict band* lower bound on remaining decisions. A missing
    band route does not make an otherwise legal native cursor position illegal;
    it only rules out an all-in-band completion from that cursor. A reachable
    target remains insufficient evidence of ordered, uninterrupted tracing.
    """
    custody = paired.verify_episode(fixture, episode)
    if fixture.task != "wall_offset":
        raise ValueError("Selected-wall band horizon requires a wall fixture")
    lengths = tuple(episode["macro_lengths"])
    unrestricted = horizon.exact_remaining_decisions(
        fixture.width, fixture.height, fixture.target, fixture.legal, lengths)
    restricted = exact_band_decisions(
        fixture.width, fixture.height, fixture.target, fixture.legal,
        lambda p: d.wall_distance(fixture, p), lengths)
    rows = []
    first_band_deficit = None
    first_band_exit = None
    original_prefix_in_band = (6.0 <= d.wall_distance(fixture, fixture.start) <= 10.0)
    for event in episode["events"]:
        index = event["seq"]
        before = tuple(event["observation"]["position"])
        after = tuple(event["simulated_post_position"])
        band_before, band_after = restricted.get(before), restricted.get(after)
        full_after = unrestricted.get(after)
        selected = next(item for item in event["observation"]["candidates"]
                        if item["candidate_id"] == event["choice_id"])
        original_prefix_in_band = original_prefix_in_band and all(
            6.0 <= d.wall_distance(fixture, tuple(cell)) <= 10.0
            for cell in selected["path"])
        budget_after = fixture.budget - index - 1
        band_feasible = band_after is not None and band_after <= budget_after
        if first_band_deficit is None and not band_feasible:
            first_band_deficit = index
        if first_band_exit is None and band_before is not None and band_after is None:
            first_band_exit = index
        rows.append({
            "decision_index": index,
            "original_choice_id": event["choice_id"],
            "cursor_before": list(before), "cursor_after": list(after),
            "minimum_unrestricted_decisions_after": full_after,
            "minimum_strict_band_decisions_before": band_before,
            "minimum_strict_band_decisions_after": band_after,
            "remaining_budget_after": budget_after,
            "strict_band_slack_after": None if band_after is None else budget_after - band_after,
            "hypothetical_strict_band_completion_feasible": band_feasible,
            "original_prefix_entirely_in_band": original_prefix_in_band,
            "hypothetical_continuous_band_completion_preserving_prefix": (
                original_prefix_in_band and band_feasible and
                event["choice_id"] != "STOP"),
            "original_stop_is_terminal": event["choice_id"] == "STOP",
        })
    return {
        "version": VERSION,
        "evidence_class": "replay_verified_offline_geometry_only",
        "fixture_sha256": fixture.sha256,
        "verified_original_path_sha256": custody["path_sha256"],
        "selected_wall_id": fixture.fixture_id + "/selected-wall",
        "allowed_selected_wall_clearance_cells": [6, 10],
        "macro_lengths": list(lengths),
        "minimum_initial_unrestricted_decisions": unrestricted.get(fixture.start),
        "minimum_initial_strict_band_decisions": restricted.get(fixture.start),
        "first_strict_band_budget_deficit_index": first_band_deficit,
        "first_loss_of_strict_band_reachability_index": first_band_exit,
        "original_arrived": episode["metrics"]["arrived"],
        "original_stop_reason": episode["metrics"]["stop_reason"],
        "decision_horizons": rows,
        "native_qualified": False,
        "model_evaluated": False,
        "heldout_behavior_evaluated": False,
        "sequential_native_receipts": 0,
        "interpretation": (
            "Necessary geometric feasibility only; forward row order, retraces, "
            "STOP, native execution and model utility are not proven"
        ),
    }
