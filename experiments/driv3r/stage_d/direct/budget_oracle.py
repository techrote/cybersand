"""Decision-budget-constrained geometric oracle for D-1A DEVELOPMENT only.

An unbounded lexicographic planner can favour zero out-of-band cells on a
route requiring more than 36 decisions. This separate comparator optimizes
wall-band fidelity *among routes which actually arrive within the budget*.
It does not alter the frozen baseline, create a controller episode, infer a
model choice or claim a native Workbench receipt.
"""
from __future__ import annotations

from functools import lru_cache
from math import isfinite
from typing import Callable

from .macro_oracle import CARDINAL, VERSION as UNBOUNDED_VERSION, _require_menu

VERSION = "d1a-decision-budget-constrained-oracle/1"
Point = tuple[int, int]
Cost = tuple[int, int, int, int]


def bounded_optimal_route(
    width: int, height: int, start: Point, target: Point,
    legal_cell: Callable[[Point], bool], lengths: tuple[int, ...] = (1, 2, 4, 8),
    selected_clearance: Callable[[Point], float] | None = None,
    *, decision_budget: int = 36,
) -> dict:
    """Find a lexicographically optimal arriving path using <= budget moves.

    Routing minimizes (decisions, swept distance); wall tracing minimizes
    (out-of-band swept cells, backwards-Y cells, decisions, swept distance)
    subject to the hard decision horizon. Source geometry must be an
    immutable snapshot; legality and clearance are memoized. Every macro's
    swept cells are checked, including the end and excluding its origin.
    The exact-k dynamic programme keeps the choice at each (k, origin) state,
    rather than prematurely pruning a feasible more-expensive short route.
    """
    _require_menu(width, height, target, lengths, legal_cell, selected_clearance)
    if (type(start) not in (tuple, list) or len(start) != 2 or
            any(type(v) is not int for v in start) or
            not (0 <= start[0] < width and 0 <= start[1] < height)):
        raise ValueError("Start must be a bounded integer point")
    if type(decision_budget) is not int or not 1 <= decision_budget <= 144:
        raise ValueError("Decision budget must be in 1..144")
    start, target = tuple(start), tuple(target)

    @lru_cache(maxsize=None)
    def legal(p: Point) -> bool:
        if not (0 <= p[0] < width and 0 <= p[1] < height):
            return False
        result = legal_cell(p)
        if type(result) is not bool:
            raise ValueError("Hard legality callback must return bool")
        return result

    if not legal(start) or not legal(target):
        raise ValueError("Start or target blocked by hard permissions")

    @lru_cache(maxsize=None)
    def penalty(p: Point) -> int:
        if selected_clearance is None:
            return 0
        value = selected_clearance(p)
        if type(value) not in (int, float) or not isfinite(value):
            raise ValueError("Selected wall clearance must be finite numeric")
        return int(not 6.0 <= value <= 10.0)

    # Each layer contains optimal cost for precisely k moves. Do not merge
    # different k states: the remaining decision budget is a hard constraint.
    layers: list[dict[Point, Cost]] = [{target: (0, 0, 0, 0)}]
    choice: dict[tuple[int, Point], tuple[str, tuple[Point, ...]]] = {}
    for k in range(1, decision_budget + 1):
        current: dict[Point, Cost] = {}
        for endpoint, suffix in layers[-1].items():
            for direction, dx, dy in CARDINAL:
                swept_penalty = 0
                for length in range(1, max(lengths) + 1):
                    predecessor = (endpoint[0] + dx*length,
                                   endpoint[1] + dy*length)
                    if not legal(predecessor):
                        break
                    cell = endpoint if length == 1 else (
                        endpoint[0] + dx*(length-1),
                        endpoint[1] + dy*(length-1))
                    swept_penalty += penalty(cell)
                    if length not in lengths:
                        continue
                    backwards = (length if selected_clearance is not None
                                 and dy > 0 else 0)
                    edge = ((swept_penalty, backwards, 1, length)
                            if selected_clearance is not None
                            else (0, 0, 1, length))
                    proposed = tuple(suffix[i] + edge[i] for i in range(4))
                    if predecessor not in current or proposed < current[predecessor]:
                        current[predecessor] = proposed
                        forward = {"E":"W", "W":"E", "N":"S", "S":"N"}[direction]
                        sweep = tuple((predecessor[0]-dx*i,
                                       predecessor[1]-dy*i)
                                      for i in range(1, length+1))
                        choice[(k, predecessor)] = (forward + str(length), sweep)
        layers.append(current)

    feasible = [(cost, k) for k, state in enumerate(layers)
                if (cost := state.get(start)) is not None]
    winning = min(feasible) if feasible else None
    cost, k = winning if winning is not None else (None, None)
    path = [start]
    actions = []
    position = start
    remaining = k
    while remaining:
        move, swept = choice[(remaining, position)]
        actions.append({"candidate_id": move, "origin": list(position),
                        "swept_cells": [list(p) for p in swept]})
        path.extend(swept)
        position = swept[-1]
        remaining -= 1
    if winning is not None and position != target:
        raise AssertionError("Budget-constrained route failed reconstruction")
    return {
        "version": VERSION,
        "comparator": "hypothetical_budget_constrained_geometry_only",
        "reference_unbounded_oracle": UNBOUNDED_VERSION,
        "objective": ("band_departures_then_backwards_then_decisions_then_distance"
                      if selected_clearance is not None else "decisions_then_distance"),
        "start": list(start), "target": list(target),
        "decision_budget": decision_budget, "macro_lengths": list(lengths),
        "feasible_arrival_within_budget": winning is not None,
        "optimal_cost_within_budget": list(cost) if cost is not None else None,
        "decisions": actions, "cursor_path": [list(p) for p in path],
        "native_qualified": False, "sequential_native_receipts": 0,
        "model_evaluated": False, "heldout_model_outcomes_evaluated": False,
    }


def audit_development_budget_route(fixture, lengths=(1, 2, 4, 8)) -> dict:
    """Allowlisted DEVELOPMENT fixture only; do not evaluate held-out outcomes."""
    from . import offline
    offline.require_development_fixture(fixture)
    if fixture.task not in ("wall_offset", "avoid_z"):
        raise ValueError("Unsupported spatial-control task")
    clearance = ((lambda p: offline.wall_distance(fixture, p))
                 if fixture.task == "wall_offset" else None)
    report = bounded_optimal_route(
        fixture.width, fixture.height, fixture.start, fixture.target,
        fixture.legal, lengths, clearance, decision_budget=fixture.budget)
    report.update({"fixture_id": fixture.fixture_id,
                   "fixture_sha256": fixture.sha256,
                   "structural_split": "development",
                   "native_material_changes": 0})
    return report
