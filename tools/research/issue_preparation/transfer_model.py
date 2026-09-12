"""Bounded abstract transfer checks for #20/#12 design; not engine code.

Two identifiable payloads; cell/pool authority independent from protocol phase.
Revision counters never wrap in the safe model. No scheduling, C++ memory model,
Rapier topology, physical collision or liveness claim is made.
"""
from __future__ import annotations
from collections import deque
from dataclasses import dataclass, replace
from typing import Iterator

C, CP, CA, P, PP, PA = range(6)


@dataclass(frozen=True)
class Unit:
    cell: bool = True
    pool: bool = False
    phase: int = C
    revision: int = 0
    ticket: int = -1
    destination_free: bool = True


@dataclass(frozen=True)
class State:
    units: tuple[Unit, ...] = (Unit(), Unit())
    failed: bool = False


def invariant(state: State, capacity: int) -> bool:
    if any(int(u.cell) + int(u.pool) != 1 for u in state.units):
        return False
    # Promotion reservations consume capacity but own no additional material.
    reserved = sum(u.pool or u.phase in (CP, CA) for u in state.units)
    if reserved > capacity:
        return False
    return all((u.cell == (u.phase in (C, CP, CA))) and
               (u.ticket == -1 if u.phase in (C, P) else u.ticket >= 0)
               for u in state.units)


def successors(state: State, capacity: int, mutant: str = "safe") -> Iterator[tuple[str, State]]:
    if state.failed:
        return  # Explicit reset/replacement is outside this model.
    yield "quarantine", replace(state, failed=True)
    occupied = sum(u.pool or u.phase in (CP, CA) for u in state.units)
    for i, unit in enumerate(state.units):
        options: list[tuple[str, Unit]] = []
        if unit.revision < 2:
            options.append(("edit_revision", replace(unit, revision=unit.revision + 1)))
        options.append(("change_destination", replace(unit, destination_free=not unit.destination_free)))
        if unit.phase == C and occupied < capacity:
            options.append(("prepare_promotion", replace(unit, phase=CP, ticket=unit.revision,
                                                          cell=mutant != "early_release")))
        if unit.phase in (CP, CA):
            options.append(("cancel_promotion", replace(unit, phase=C, ticket=-1)))
        if unit.phase in (PP, PA):
            options.append(("cancel_return", replace(unit, phase=P, ticket=-1)))
        valid = unit.ticket == unit.revision
        if unit.phase == CP and (valid or mutant == "stale_ack"):
            options.append(("ack_promotion", replace(unit, phase=CA)))
        if unit.phase == CA and valid:
            options.append(("commit_promotion", replace(unit, cell=mutant == "duplicate_owner",
                                                         pool=True, phase=P, ticket=-1)))
        if unit.phase == P:
            if unit.destination_free:
                options.append(("prepare_return", replace(unit, phase=PP, ticket=unit.revision)))
            elif mutant == "drop_on_full":
                options.append(("failed_return_drops_payload", replace(unit, pool=False)))
        if unit.phase == PP and valid and unit.destination_free:
            options.append(("ack_return", replace(unit, phase=PA)))
        if unit.phase == PA and valid and unit.destination_free:
            options.append(("commit_return", replace(unit, cell=True, pool=False, phase=C, ticket=-1)))
        for action, changed in options:
            units = list(state.units)
            units[i] = changed
            yield f"{i}:{action}", replace(state, units=tuple(units))


def explore(capacity: int, mutant: str = "safe", depth: int = 10,
            state_limit: int = 60000) -> dict:
    start = State()
    parents: dict[State, tuple[State | None, str]] = {start: (None, "start")}
    queue = deque([(start, 0)])
    edges = 0
    depth_cut = False
    limit_hit = False
    while queue:
        state, distance = queue.popleft()
        if distance == depth:
            depth_cut = True
            continue
        for action, following in successors(state, capacity, mutant):
            edges += 1
            stale_accepted = action.endswith("ack_promotion") and any(
                b.phase == CP and a.phase == CA and b.ticket != b.revision
                for b, a in zip(state.units, following.units))
            if not invariant(following, capacity) or stale_accepted:
                trace = [action]
                cursor = state
                while parents[cursor][0] is not None:
                    previous, event = parents[cursor]
                    trace.append(event)
                    assert previous is not None
                    cursor = previous
                return {"capacity": capacity, "variant": mutant, "states": len(parents),
                        "transitions": edges, "counterexample": list(reversed(trace)),
                        "depth_limit": depth, "state_limit": state_limit,
                        "claim": "bounded abstract-model counterexample"}
            if following not in parents:
                if len(parents) >= state_limit:
                    limit_hit = True
                    queue.clear()
                    break
                parents[following] = (state, action)
                queue.append((following, distance + 1))
        if limit_hit:
            break
    return {"capacity": capacity, "variant": mutant, "states": len(parents),
            "transitions": edges, "counterexample": None, "depth_limit": depth,
            "state_limit": state_limit, "depth_cut": depth_cut, "state_limit_hit": limit_hit,
            "claim": "no violation in enumerated bounded model; not engine proof or liveness"}
