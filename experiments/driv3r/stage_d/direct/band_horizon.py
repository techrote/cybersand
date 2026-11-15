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

VERSION = "d1a-selected-wall-band-horizon/2"


def scan_swept_band_transitions(
    start: tuple[int, int], sweeps: list[list[tuple[int, int]]],
    selected_clearance: Callable[[tuple[int, int]], float],
) -> dict[str, Any]:
    """Count selected-wall band exits/reentries on every swept cell.

    Endpoint-only horizon checks cannot tell whether an admitted long cursor
    macro briefly left and reentered the band. This is an observed-path
    diagnostic, not another legality policy or a reconstructed native edit.
    """
    if not callable(selected_clearance):
        raise ValueError("Selected-wall clearance callback is required")

    def inside(point: tuple[int, int]) -> bool:
        distance = selected_clearance(point)
        if type(distance) not in (int, float) or not isfinite(distance):
            raise ValueError("Selected-wall clearance must be finite and numeric")
        return 6.0 <= distance <= 10.0

    previous = inside(start)
    initial = previous
    exits = reentries = outside = 0
    first_exit = first_reentry = None
    per_decision = []
    for decision, cells in enumerate(sweeps):
        event_exits = event_reentries = event_outside = 0
        for swept_index, point in enumerate(cells, 1):
            current = inside(point)
            if not current:
                outside += 1
                event_outside += 1
            if previous and not current:
                exits += 1
                event_exits += 1
                if first_exit is None:
                    first_exit = {"decision_index": decision,
                                  "swept_step_in_decision": swept_index}
            elif not previous and current:
                reentries += 1
                event_reentries += 1
                if first_reentry is None:
                    first_reentry = {"decision_index": decision,
                                     "swept_step_in_decision": swept_index}
            previous = current
        per_decision.append({
            "swept_band_exits": event_exits,
            "swept_band_reentries": event_reentries,
            "swept_out_of_band_cells": event_outside,
        })
    return {
        "initial_in_band": initial,
        "swept_band_exits": exits,
        "swept_band_reentries": reentries,
        "swept_out_of_band_cells": outside,
        "first_swept_band_exit": first_exit,
        "first_swept_band_reentry": first_reentry,
        "per_decision": per_decision,
    }


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
    # Replay-verified original sweeps can briefly leave and reenter the band
    # inside one macro, even if both endpoint cursors appear admissible.
    original_sweeps = [
        next(item["path"] for item in event["observation"]["candidates"]
             if item["candidate_id"] == event["choice_id"])
        for event in episode["events"]
    ]
    swept_band = scan_swept_band_transitions(
        fixture.start, original_sweeps,
        lambda p: d.wall_distance(fixture, tuple(p)))
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
            "original_swept_band_transitions": swept_band["per_decision"][index],
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
        "initial_cursor_within_selected_band": swept_band["initial_in_band"],
        "first_swept_band_exit": swept_band["first_swept_band_exit"],
        "first_swept_band_reentry": swept_band["first_swept_band_reentry"],
        "swept_band_exit_count": swept_band["swept_band_exits"],
        "swept_band_reentry_count": swept_band["swept_band_reentries"],
        "swept_out_of_band_cells": swept_band["swept_out_of_band_cells"],
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


MONOTONE_VERSION = "d1a-selected-wall-monotone-band-horizon/1"


def exact_monotone_band_decisions(
    width: int, height: int, target: tuple[int, int],
    legal_cell: Callable[[tuple[int, int]], bool],
    selected_clearance: Callable[[tuple[int, int]], float],
    lengths: tuple[int, ...] = (1,),
) -> dict[tuple[int, int], int]:
    """Exact remaining macro decisions under an optional nondecreasing-Y rule.

    This is a *strict control ablation*, not the normative definition of a
    successful contour: legitimate obstacle recovery may need backward Y.
    The entire swept macro remains within the identified 6–10-cell band.
    Reverse BFS examines only backwards-horizontal or backwards-upstream
    predecessors (Y does not decrease during forward travel). The complete
    undirected band-reachable set safely screens intermediate macro cells.
    """
    from collections import deque

    band_reachable = exact_band_decisions(
        width, height, target, legal_cell, selected_clearance, lengths)
    permitted = set(lengths)
    maximum = max(lengths)
    goal = tuple(target)
    distances = {goal: 0}
    pending = deque([goal])
    while pending:
        endpoint = pending.popleft()
        next_cost = distances[endpoint] + 1
        for dx, dy in ((1, 0), (-1, 0), (0, -1)):
            for step in range(1, maximum + 1):
                predecessor = (endpoint[0] + dx * step,
                               endpoint[1] + dy * step)
                # The legal swept segment is reversible. If any intermediate
                # cell cannot reach the target within the strict band, the
                # longer macro also cannot be a valid path to this endpoint.
                if predecessor not in band_reachable:
                    break
                if step in permitted and predecessor not in distances:
                    distances[predecessor] = next_cost
                    pending.append(predecessor)
    return distances


def audit_development_monotone_band_horizon(
    fixture: d.Fixture, episode: dict[str, Any],
) -> dict[str, Any]:
    """Supplementary replay-verified DEVELOPMENT-only monotone-Y ablation."""
    custody = paired.verify_episode(fixture, episode)
    if fixture.task != "wall_offset":
        raise ValueError("Monotone band analysis requires a selected-wall fixture")
    lengths = tuple(episode["macro_lengths"])
    clearance = lambda p: d.wall_distance(fixture, p)
    strict = exact_band_decisions(
        fixture.width, fixture.height, fixture.target, fixture.legal,
        clearance, lengths)
    monotone = exact_monotone_band_decisions(
        fixture.width, fixture.height, fixture.target, fixture.legal,
        clearance, lengths)
    prefix_band = 6.0 <= clearance(fixture.start) <= 10.0
    prefix_nondecreasing_y = True
    previous = tuple(fixture.start)
    first_backward_step = None
    first_budget_deficit = None
    decision_rows = []
    for event in episode["events"]:
        index = event["seq"]
        selected = next(item for item in event["observation"]["candidates"]
                        if item["candidate_id"] == event["choice_id"])
        for swept_index, raw in enumerate(selected["path"], 1):
            point = tuple(raw)
            prefix_band = prefix_band and 6.0 <= clearance(point) <= 10.0
            if point[1] < previous[1]:
                prefix_nondecreasing_y = False
                if first_backward_step is None:
                    first_backward_step = {
                        "decision_index": index,
                        "swept_step_in_decision": swept_index,
                    }
            previous = point
        after = tuple(event["simulated_post_position"])
        remaining = fixture.budget - index - 1
        minimum = monotone.get(after)
        feasible = minimum is not None and minimum <= remaining
        if first_budget_deficit is None and not feasible:
            first_budget_deficit = index
        decision_rows.append({
            "decision_index": index,
            "original_choice_id": event["choice_id"],
            "minimum_strict_band_decisions_after": strict.get(after),
            "minimum_monotone_band_decisions_after": minimum,
            "remaining_decisions_after": remaining,
            "monotone_band_slack_after": (
                None if minimum is None else remaining - minimum),
            "hypothetical_monotone_completion_feasible": feasible,
            "original_prefix_in_band": prefix_band,
            "original_prefix_nondecreasing_y": prefix_nondecreasing_y,
            "original_prefix_preserving_monotone_completion": (
                prefix_band and prefix_nondecreasing_y and feasible
                and event["choice_id"] != "STOP"),
        })
    return {
        "version": MONOTONE_VERSION,
        "evidence_class": "replay_verified_offline_geometry_only",
        "fixture_sha256": fixture.sha256,
        "verified_original_path_sha256": custody["path_sha256"],
        "minimum_initial_strict_band_decisions": strict.get(fixture.start),
        "minimum_initial_monotone_band_decisions": monotone.get(fixture.start),
        "first_original_backward_y_step": first_backward_step,
        "first_monotone_budget_deficit_index": first_budget_deficit,
        "original_arrived": episode["metrics"]["arrived"],
        "original_stop_reason": episode["metrics"]["stop_reason"],
        "decision_horizons": decision_rows,
        "native_qualified": False,
        "model_evaluated": False,
        "heldout_behavior_evaluated": False,
        "sequential_native_receipts": 0,
        "interpretation": (
            "Strict Y-monotone continuous-band geometric lower bound only; "
            "not a required contour strategy, native receipt or controller result"),
    }
