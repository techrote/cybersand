#!/usr/bin/env python3
"""Exhaust the two-step Water-IN travel ownership/occupancy dependency.

This overapproximates material decisions with Empty, blocked and downward
exchangeable grain. Carrying may fail for any reason or succeed only with a
grain below the actual carrier. Persistent occupancy makes a failed diagonal
and the later horizontal fallback the *same target*. It is a stencil proof,
not a material dynamics oracle or a replacement for actual worker execution.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, replace


@dataclass(frozen=True)
class Path:
    cells: dict[tuple[int, int], str]
    pos: tuple[int, int] = (0, 0)
    dx: int = 0
    dy: int = 0
    reads: int = 0
    writes: int = 0
    carries: int = 0
    stopped: bool = False

    def access(self, point: tuple[int, int], write: bool = False) -> Path:
        reach = max(map(abs, point))
        return replace(self, writes=max(self.writes, reach)) if write else replace(self, reads=max(self.reads, reach))


def observed(path: Path, point: tuple[int, int]):
    path = path.access(point)
    values = [path.cells[point]] if point in path.cells else ("E", "B", "G")
    for value in values:
        yield replace(path, cells=path.cells | {point: value}), value


def eligible(path: Path, dx: int, dy: int):
    target = path.pos[0] + dx, path.pos[1] + dy
    for candidate, material in observed(path, target):
        yield candidate, material == "E" or (dy == 1 and material == "G"), material


def moved(path: Path, dx: int, dy: int, target: str):
    origin = path.pos
    dest = origin[0] + dx, origin[1] + dy
    path = path.access(origin).access(dest).access(origin, True).access(dest, True)
    path = replace(path, cells=path.cells | {origin: target, dest: "W"}, pos=dest,
                   dx=path.dx + abs(dx), dy=path.dy + abs(dy))
    if target == "G":
        # Current Stone bracing can inspect target +/-1, -1.
        yield path.access((dest[0] - 1, dest[1] - 1)).access((dest[0] + 1, dest[1] - 1))
        return
    if dy != 0:
        yield path
        return
    grain = origin[0], origin[1] + 1
    # Coupling may stop before its grain/packing census, but the maximal census
    # is safe to charge even when a particular material/profile would stop.
    path = path.access(origin).access(dest)
    for candidate, material in observed(path, grain):
        yield candidate
        if material != "G":
            continue
        for oy in (-1, 0, 1):
            for ox in (-1, 0, 1):
                candidate = candidate.access((grain[0] + ox, grain[1] + oy))
        candidate = candidate.access(grain, True).access(dest, True)
        yield replace(candidate, cells=candidate.cells | {grain: "W", dest: "G"}, pos=grain,
                      carries=candidate.carries + 1)


def unit(path: Path, dx: int, dy: int, lateral_allowed: bool):
    if dy == 0 and not lateral_allowed:
        yield replace(path, dx=path.dx + abs(dx))
        return
    for candidate, permitted, material in eligible(path, dx, dy):
        if not permitted:
            # Landing may inspect either horizontal side before stopping.
            if dy:
                candidate = candidate.access((candidate.pos[0] - 1, candidate.pos[1]))
                candidate = candidate.access((candidate.pos[0] + 1, candidate.pos[1]))
            yield replace(candidate, stopped=True)
            continue
        # An otherwise exchangeable grain may fail bracing/epoch/permeability.
        if material == "G":
            dest = candidate.pos[0] + dx, candidate.pos[1] + dy
            candidate = candidate.access((dest[0] - 1, dest[1] - 1)).access((dest[0] + 1, dest[1] - 1))
            yield replace(candidate, stopped=True)
        yield from moved(candidate, dx, dy, material)


def walk(path: Path, nx: int, ny: int, lateral_allowed: bool, step: int = 1):
    steps = max(abs(nx), ny)
    if path.stopped or step > steps:
        yield path.access((path.pos[0], path.pos[1] + 1))
        return
    want_x = abs(nx) * step // steps - path.dx
    want_y = ny * step // steps - path.dy
    sx = 1 if nx > 0 else -1
    plans = []
    if want_x and want_y:
        for candidate, permitted, _ in eligible(path, sx, 1):
            plans.append((candidate, [(sx, 1)] if permitted else [(0, 1), (sx, 0)]))
    else:
        plans.append((path, ([(0, 1)] if want_y else []) + ([(sx, 0)] if want_x else [])))
    for candidate, plan in plans:
        current = [candidate]
        for dx, dy in plan:
            current = [out for item in current for out in ([item] if item.stopped else unit(item, dx, dy, lateral_allowed))]
        for item in current:
            yield from walk(item, nx, ny, lateral_allowed, step + 1)


def prove() -> dict:
    result = {"schema": "lcb-water-inertial-footprint-v1", "paths": 0, "maximum_read_reach": 0,
              "maximum_write_reach": 0, "maximum_carries": 0, "read3_witnesses": 0,
              "write2_witnesses": 0, "two_carry_witnesses": 0}
    for nx in range(-2, 3):
        for ny in range(3):
            for allowed in (False, True):
                # U1/U3 original support/diagonal probes are within one. The
                # travel's persisted target facts are deliberately otherwise free.
                initial = Path({(0, 0): "W"}, reads=1)
                for path in walk(initial, nx, ny, allowed):
                    result["paths"] += 1
                    result["maximum_read_reach"] = max(result["maximum_read_reach"], path.reads)
                    result["maximum_write_reach"] = max(result["maximum_write_reach"], path.writes)
                    result["maximum_carries"] = max(result["maximum_carries"], path.carries)
                    result["read3_witnesses"] += path.reads == 3
                    result["write2_witnesses"] += path.writes == 2
                    result["two_carry_witnesses"] += path.carries == 2
                    if path.reads > 3 or path.writes > 2:
                        raise AssertionError((nx, ny, allowed, path))
    assert result["maximum_read_reach"] == 3 and result["maximum_write_reach"] == 2
    assert result["two_carry_witnesses"] > 0
    return result


if __name__ == "__main__":
    print(json.dumps(prove(), indent=2, sort_keys=True))
