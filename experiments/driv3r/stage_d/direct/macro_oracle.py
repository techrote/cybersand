"""CPU-only, deterministic bounded-macro oracle for D-1A DEVELOPMENT geometry.

This is a *planning reference*, not a controller session: no model calls,
no native actions, no World snapshots, no held-out policy evaluation. It uses
only a caller-supplied hard legality predicate. Every macro's intermediate
cells are checked. A wall preference is a soft geometric objective, never a
permission to cross blocked material.
"""
from __future__ import annotations

from heapq import heappop, heappush
from math import isfinite
from typing import Callable

VERSION = "d1a-macro-lexicographic-oracle/1"
CARDINAL = (("E", 1, 0), ("N", 0, -1), ("S", 0, 1), ("W", -1, 0))
Point = tuple[int, int]
Cost = tuple[int, int, int, int]


def _require_menu(width: int, height: int, target: Point,
                  lengths: tuple[int, ...], legal_cell: Callable[[Point], bool],
                  selected_clearance: Callable[[Point], float] | None) -> None:
    if (type(width) is not int or type(height) is not int or
            not (1 <= width <= 256 and 1 <= height <= 256) or
            width * height > 65536):
        raise ValueError("Bounded positive offline grid dimensions required")
    if (type(target) not in (tuple, list) or len(target) != 2 or
            any(type(n) is not int for n in target) or
            not (0 <= target[0] < width and 0 <= target[1] < height)):
        raise ValueError("Target outside bounded grid")
    if (type(lengths) not in (tuple, list) or not lengths or
            any(type(n) is not int or n not in (1, 2, 4, 8) for n in lengths) or
            list(lengths) != sorted(set(lengths)) or 1 not in lengths):
        raise ValueError("Macro menu must be sorted, unique, and include 1")
    if not callable(legal_cell) or (selected_clearance is not None and
                                     not callable(selected_clearance)):
        raise ValueError("Geometry must be supplied by explicit callbacks")


def reverse_lexicographic_plan(
    width: int, height: int, target: Point,
    legal_cell: Callable[[Point], bool], lengths: tuple[int, ...] = (1, 2, 4, 8),
    selected_clearance: Callable[[Point], float] | None = None,
) -> dict[Point, tuple[Cost, str, tuple[Point, ...]]]:
    """One optimal next move per reachable origin, using reverse Dijkstra.

    Routing minimizes (decisions, cell steps). Wall tracing minimizes
    (out-of-selected-band swept cells, backwards-Y steps, decisions, steps).
    Costs are additive, so any output has a globally optimal total under its
    declared objective. Stable cardinal/length enumeration breaks ties.
    No point is deemed legal unless callback returns an actual bool.
    """
    _require_menu(width, height, target, lengths, legal_cell, selected_clearance)

    def legal(p: Point) -> bool:
        if not (0 <= p[0] < width and 0 <= p[1] < height):
            return False
        value = legal_cell(p)
        if type(value) is not bool:
            raise ValueError("Hard legality callback must return bool")
        return value

    def band_penalty(p: Point) -> int:
        if selected_clearance is None:
            return 0
        clearance = selected_clearance(p)
        if type(clearance) not in (int, float) or not isfinite(clearance):
            raise ValueError("Selected-wall clearance must be finite")
        return int(not 6.0 <= clearance <= 10.0)

    target = tuple(target)
    if not legal(target):
        raise ValueError("Target blocked by host-like permissions")
    # The canonical priority is four components in both arms; unused wall
    # components are always zero in A-to-B routing, without hidden weighting.
    best: dict[Point, Cost] = {target: (0, 0, 0, 0)}
    steps: dict[Point, tuple[str, tuple[Point, ...]]] = {}
    queue: list[tuple[Cost, int, Point]] = [((0, 0, 0, 0), 0, target)]
    order = 0
    while queue:
        total, _, endpoint = heappop(queue)
        if best[endpoint] != total:
            continue
        for name, dx, dy in CARDINAL:
            # Forward control from predecessor to endpoint is opposite the
            # ray from endpoint. Scan all *swept* cells, not only endpoints.
            forward_dx, forward_dy = -dx, -dy
            out_of_band = 0
            for length in range(1, max(lengths) + 1):
                predecessor = (endpoint[0] + dx*length,
                               endpoint[1] + dy*length)
                if not legal(predecessor):
                    break
                # The cell just introduced as we extend the reverse ray is
                # part of the forward sweep except the far predecessor;
                # endpoint is always swept and the predecessor is not.
                if length == 1:
                    out_of_band = band_penalty(endpoint)
                else:
                    near_endpoint = (endpoint[0] + dx*(length-1),
                                     endpoint[1] + dy*(length-1))
                    out_of_band += band_penalty(near_endpoint)
                if length not in lengths:
                    continue
                swept = tuple((predecessor[0] + forward_dx*i,
                               predecessor[1] + forward_dy*i)
                              for i in range(1, length+1))
                backwards = length if selected_clearance is not None and forward_dy < 0 else 0
                if selected_clearance is None:
                    edge = (0, 0, 1, length)
                else:
                    edge = (out_of_band, backwards, 1, length)
                proposal = tuple(total[i] + edge[i] for i in range(4))
                if predecessor not in best or proposal < best[predecessor]:
                    best[predecessor] = proposal
                    steps[predecessor] = ({"E":"W","W":"E","N":"S","S":"N"}[name] + str(length), swept)
                    order += 1
                    heappush(queue, (proposal, order, predecessor))
    return {p: (cost, steps[p][0], steps[p][1]) for p, cost in best.items()
            if p != target}


def trace_planned_route(start: Point, target: Point,
                        plan: dict[Point, tuple[Cost, str, tuple[Point, ...]]],
                        *, max_decisions: int = 36) -> dict:
    """Return a hypothetical plan with explicit decision budget, not an episode."""
    if type(max_decisions) is not int or not 1 <= max_decisions <= 144:
        raise ValueError("Plan horizon must be 1..144")
    if (type(start) not in (tuple, list) or len(start) != 2 or
            any(type(n) is not int for n in start)):
        raise ValueError("Start must be an integer point")
    if (type(target) not in (tuple, list) or len(target) != 2 or
            any(type(n) is not int for n in target)):
        raise ValueError("Target must be an integer point")
    pos = tuple(start)
    target = tuple(target)
    origins = set()
    path = [pos]
    decisions = []
    while pos != target and len(decisions) < max_decisions:
        if pos in origins:
            raise AssertionError("Reverse optimal policy formed a cycle")
        origins.add(pos)
        if pos not in plan:
            break
        cost, move, cells = plan[pos]
        if (not cells or move not in {name + str(len(cells)) for name, _, _ in CARDINAL}
                or len(cells) not in (1, 2, 4, 8) or
                any(abs(a[0]-b[0])+abs(a[1]-b[1]) != 1
                    for a,b in zip((pos,)+cells[:-1], cells)) or
                any(cell != (pos[0] + next(dx for name,dx,dy in CARDINAL
                                           if name == move[0])*i,
                             pos[1] + next(dy for name,dx,dy in CARDINAL
                                           if name == move[0])*i)
                    for i,cell in enumerate(cells,1))):
            raise AssertionError("Claimed cardinal macro mismatches its swept path")
        decisions.append({"candidate_id":move, "origin":list(pos),
                          "swept_cells":[list(p) for p in cells],
                          "remaining_optimal_cost_before":list(cost)})
        path.extend(cells)
        pos = cells[-1]
    return {
        "version": VERSION, "kind": "hypothetical_offline_oracle_route",
        "native_qualified": False, "sequential_native_receipts": 0,
        "model_evaluated": False, "heldout_model_outcomes_evaluated": False,
        "start": list(start), "target": list(target),
        "cursor_path": [list(p) for p in path],
        "decisions": decisions, "decision_budget": max_decisions,
        "arrived_in_hypothetical_plan": pos == target,
        "decision_budget_exhausted": len(decisions) >= max_decisions and pos != target,
    }


def audit_development_macro_plan(fixture, lengths: tuple[int, ...] = (1, 2, 4, 8)) -> dict:
    """Guard the only scenario-facing API with source-pinned DEVELOPMENT custody.

    Runs no observed/model/native controller: these are hypothetical oracle moves.
    Official D-1A v1 baseline records and held-out outcomes remain unchanged.
    """
    from . import offline
    offline.require_development_fixture(fixture)
    if fixture.task not in ("wall_offset", "avoid_z"):
        raise ValueError("Unsupported development geometry task")
    clearance = (lambda point: offline.wall_distance(fixture, point)) if fixture.task == "wall_offset" else None
    plan = reverse_lexicographic_plan(fixture.width, fixture.height, fixture.target,
                                      fixture.legal, lengths, clearance)
    route = trace_planned_route(fixture.start, fixture.target, plan,
                                max_decisions=fixture.budget)
    route.update({"fixture_sha256": fixture.sha256, "fixture_id": fixture.fixture_id,
                  "structural_split": "development", "macro_lengths": list(lengths),
                  "objective": ("selected_wall_band_then_forward_then_decisions_then_length"
                                if clearance is not None else "decisions_then_length"),
                  "actual_native_actions": 0, "native_material_readbacks": 0})
    return route
