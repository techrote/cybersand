"""Exact, DEVELOPMENT-only remaining-decision feasibility for D-1A paths.

This diagnostic asks whether a cursor *could* still reach its goal within the
36-decision budget using the same collision-checked cardinal macro menu.
It is not a recovery policy, a model result, or a native execution adapter.
"""
from __future__ import annotations

from collections import deque
from typing import Any, Callable

VERSION = "d1a-offline-decision-horizon/1"
_DIRECTIONS = ((1, 0), (0, -1), (0, 1), (-1, 0))


def exact_remaining_decisions(width: int, height: int, target: tuple[int, int],
                              legal_cell: Callable[[tuple[int, int]], bool],
                              lengths: tuple[int, ...] = (1,)) -> dict[tuple[int, int], int]:
    """Reverse BFS over symmetric host-legal cardinal macro endpoints.

    Each distance is the exact minimum number of *decisions*, not the number
    of cells divided by maximum macro length. Reverse traversal is sound
    because every legal straight swept segment can be traversed in reverse.
    This small bounded synthetic grid is not a native World legality oracle.
    """
    if (type(width) is not int or type(height) is not int or
            not 1 <= width <= 65536 or not 1 <= height <= 65536 or
            width * height > 65536):
        raise ValueError("Offline decision-horizon grid must be bounded")
    if (type(target) not in (tuple, list) or len(target) != 2 or
            any(type(c) is not int for c in target) or
            not 0 <= target[0] < width or not 0 <= target[1] < height):
        raise ValueError("Invalid target coordinate")
    if (type(lengths) not in (tuple, list) or not lengths or
            any(type(n) is not int or n not in (1, 2, 4, 8) for n in lengths) or
            list(lengths) != sorted(set(lengths)) or 1 not in lengths):
        raise ValueError("Macro menu must be sorted, unique and include one-cell steps")
    if not callable(legal_cell):
        raise ValueError("A host-like legality callback is mandatory")

    def admissible(p: tuple[int, int]) -> bool:
        x, y = p
        if not (0 <= x < width and 0 <= y < height):
            return False
        response = legal_cell(p)
        if type(response) is not bool:
            raise ValueError("Legality callback must return a real boolean")
        return response

    target = tuple(target)
    if not admissible(target):
        raise ValueError("Blocked target")
    distances = {target: 0}
    pending = deque([target])
    permitted = set(lengths)
    max_length = max(lengths)
    while pending:
        pos = pending.popleft()
        cost = distances[pos] + 1
        for dx, dy in _DIRECTIONS:
            for length in range(1, max_length + 1):
                endpoint = (pos[0] + dx * length, pos[1] + dy * length)
                if not admissible(endpoint):
                    break  # A macro cannot jump over a protected/blocked cell.
                if length in permitted and endpoint not in distances:
                    distances[endpoint] = cost
                    pending.append(endpoint)
    return distances


def audit_development_horizon(fixture: Any, episode: dict[str, Any]) -> dict[str, Any]:
    """Audit original replay-verified DEVELOPMENT positions, never rerun a policy.

    Remaining-budget feasibility is *counterfactual*. It cannot turn an
    observed STOP or failed trajectory into an arrival, and does not claim
    source-qualified native admission, material edits or model performance.
    """
    from . import offline, paired

    custody = paired.verify_episode(fixture, episode)  # Enforces source/split seal.
    remaining = exact_remaining_decisions(fixture.width, fixture.height,
                                         fixture.target, fixture.legal,
                                         tuple(episode["macro_lengths"]))
    start_min = remaining.get(fixture.start)
    if start_min is None:
        raise ValueError("Frozen development start unexpectedly unreachable")
    rows = []
    first_deficit = None
    for event in episode["events"]:
        index = event["seq"]
        before = tuple(event["observation"]["position"])
        after = tuple(event["simulated_post_position"])
        minimum_before = remaining.get(before)
        minimum_after = remaining.get(after)
        before_budget = fixture.budget - index
        after_budget = fixture.budget - index - 1
        feasible = minimum_after is not None and minimum_after <= after_budget
        if first_deficit is None and not feasible:
            first_deficit = index
        rows.append({
            "decision_index": index,
            "original_selected_id": event["choice_id"],
            "cursor_before": list(before), "cursor_after": list(after),
            "minimum_decisions_before": minimum_before,
            "minimum_decisions_after": minimum_after,
            "remaining_budget_before": before_budget,
            "remaining_budget_after": after_budget,
            "decision_slack_before": None if minimum_before is None else
                before_budget - minimum_before,
            "decision_slack_after": None if minimum_after is None else
                after_budget - minimum_after,
            "hypothetically_feasible_after_choice": feasible,
            "terminal_stop_cannot_be_resumed": event["choice_id"] == "STOP",
        })
    return {
        "version": VERSION, "evidence_class": "replayed_offline_geometry_only",
        "fixture_sha256": fixture.sha256,
        "original_path_sha256": custody["path_sha256"],
        "native_qualified": False, "model_evaluated": False,
        "heldout_behavior_evaluated": False, "sequential_native_receipts": 0,
        "macro_lengths": list(episode["macro_lengths"]),
        "minimum_initial_decisions": start_min,
        "initial_36_decision_budget_feasible": start_min <= fixture.budget,
        "original_terminal_arrival": episode["metrics"]["arrived"],
        "original_stop_reason": episode["metrics"]["stop_reason"],
        "first_budget_infeasible_post_choice_index": first_deficit,
        "original_decision_horizons": rows,
        "interpretation": (
            "A feasible geometric continuation is hypothetical and does not "
            "resume STOP, repair choices, grant native admission or prove model success"
        ),
    }
