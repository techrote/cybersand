"""Read-only topology diagnosis for frozen ejection capsules.

The interior is the AABB of the source and all 81 production endpoint cells.
It is an explicit geometric overapproximation, not an expanded production
search. The captured one-cell boundary is examined separately as an outer ring.
Graph costs count intermediate movable cells, exclude the displaced source,
and do not assert that a graph route is a legal material rearrangement.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import heapq
import json
import math
from pathlib import Path
import struct
from typing import Iterable

Point = tuple[int, int]
DIRECTIONS = ((-1, 0), (0, -1), (0, 1), (1, 0))
BINS = ("0", "1", "2", "3", "4+", "unreachable")


def canonical_hash(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


def enumerate_candidates(capsule: dict) -> list[Point]:
    """Mirror individual Godot single-precision Vector2 operators, in order."""
    sx, sy = capsule["source"]
    nx, ny = map(f32, capsule["normal"])
    cx, cy = f32(sx + .5), f32(sy + .5)
    points = []
    first = capsule["first_distance"]
    for distance in range(first, first + capsule["maximum_distance"] + 1):
        for probe in range(capsule["tangent_probes"]):
            offset = 0 if probe == 0 else ((probe + 1) // 2) * (1 if probe & 1 else -1)
            x = f32(f32(cx + f32(nx * f32(distance))) + f32(-ny * f32(offset)))
            y = f32(f32(cy + f32(ny * f32(distance))) + f32(nx * f32(offset)))
            points.append((math.floor(x), math.floor(y)))
    return points


class Grid:
    """Owned immutable views of a capsule's copied cell rows (no World API)."""
    def __init__(self, capsule: dict):
        self.capsule = capsule
        self.source = tuple(capsule["source"])
        self.normal = tuple(capsule["normal"])
        self.body_id = capsule["body_id"]
        self.left, self.top, self.width, self.height = capsule["bounds"]
        self.world_bounds = tuple(capsule["world_bounds"])
        if not 3 <= self.width <= 128 or not 3 <= self.height <= 128:
            raise ValueError("invalid bounded capsule dimensions")
        if len(capsule["cells"]) != self.width * self.height:
            raise ValueError("incomplete copied cells")
        self.cells = tuple(tuple(row) for row in capsule["cells"])
        if any(len(row) != 9 for row in self.cells):
            raise ValueError("invalid cell tuple")
        if not self.interior(self.source):
            raise ValueError("source outside interior")

    def in_world(self, p: Point) -> bool:
        x, y, w, h = self.world_bounds
        return x <= p[0] < x + w and y <= p[1] < y + h

    def inside(self, p: Point) -> bool:
        return self.left <= p[0] < self.left + self.width and self.top <= p[1] < self.top + self.height

    def interior(self, p: Point) -> bool:
        return self.left + 1 <= p[0] < self.left + self.width - 1 and self.top + 1 <= p[1] < self.top + self.height - 1

    def row(self, p: Point) -> tuple:
        if not self.inside(p):
            raise ValueError(f"cell outside copied bounds: {p}")
        return self.cells[(p[1] - self.top) * self.width + p[0] - self.left]

    def points(self, ring: bool = False) -> Iterable[Point]:
        inset = 0 if ring else 1
        for y in range(self.top + inset, self.top + self.height - inset):
            for x in range(self.left + inset, self.left + self.width - inset):
                if self.in_world((x, y)):
                    yield x, y

    def void(self, p: Point) -> bool:
        row = self.row(p)
        return row[0] == 0 and row[4] == 0

    def barrier(self, p: Point) -> str | None:
        row = self.row(p)
        if row[5]:
            return "hard"
        if row[4] not in (0, self.body_id):
            return "foreign"
        if row[0] != 0 and not row[6]:
            return "immovable"
        return None


def production_replay(grid: Grid) -> tuple[list[int], list[list]]:
    """Diagnostic Python differential, checked against every captured trace."""
    source = grid.source
    trace = []
    for p in enumerate_candidates(grid.capsule):
        reason = "accepted"
        if not grid.in_world(p):
            reason = "bounds"
        else:
            row = grid.row(p)
            if row[4]:
                reason = "source_body" if row[4] == grid.body_id else "foreign_body"
            elif row[0]:
                reason = "non_empty"
            else:
                dx, dy = p[0] - source[0], p[1] - source[1]
                samples = max(abs(dx), abs(dy)) * 2
                for sample in range(1, samples):
                    step = (source[0] + math.floor(dx * sample / samples + .5),
                            source[1] + math.floor(dy * sample / samples + .5))
                    if not grid.in_world(step):
                        reason = "path_bounds"
                        break
                    through = grid.row(step)
                    if through[4] not in (0, grid.body_id):
                        reason = "path_foreign"
                        break
                    if through[5]:
                        reason = "path_hard"
                        break
        trace.append([*p, reason])
        if reason == "accepted":
            return list(p), trace
    return [-1, -1], trace


def dijkstra(grid: Grid, *, ring: bool = False, strict: bool = False,
             ignore: frozenset[str] = frozenset()) -> tuple[dict[Point, tuple[int, int]], dict[Point, Point]]:
    """Cost/step/coordinate ties are deterministic; source cost is zero."""
    allowed = set(grid.points(ring=ring))
    distance = {grid.source: (0, 0)}
    parent = {}
    heap = [(0, 0, *grid.source)]
    while heap:
        cost, steps, x, y = heapq.heappop(heap)
        p = (x, y)
        if distance.get(p) != (cost, steps):
            continue
        for dx, dy in DIRECTIONS:
            q = x + dx, y + dy
            if q not in allowed:
                continue
            row = grid.row(q)
            barrier = grid.barrier(q)
            if barrier and barrier not in ignore:
                continue
            if strict and not grid.void(q):
                continue
            proposal = (cost + int(row[0] != 0), steps + 1)
            if proposal < distance.get(q, (math.inf, math.inf)):
                distance[q] = proposal
                parent[q] = p
                heapq.heappush(heap, (*proposal, *q))
    return distance, parent


def route(parent: dict[Point, Point], source: Point, target: Point) -> list[list[int]]:
    path = [target]
    while path[-1] != source:
        path.append(parent[path[-1]])
    return [list(p) for p in reversed(path)]


def vector_comparison(normal: tuple, vector: tuple) -> dict:
    magnitude = math.hypot(*vector)
    normal_length = math.hypot(*normal)
    dot = sum(a * b for a, b in zip(normal, vector))
    cosine = dot / (magnitude * normal_length) if magnitude and normal_length else None
    angle = math.degrees(math.acos(max(-1., min(1., cosine)))) if cosine is not None else None
    return {"vector": list(vector), "dot": dot, "cosine": cosine, "angle_degrees": angle}


def void_geometry(grid: Grid, p: Point, enumerated: set[Point], considered: set[Point]) -> dict:
    vector = p[0] - grid.source[0], p[1] - grid.source[1]
    values = vector_comparison(grid.normal, vector)
    angle = values["angle_degrees"]
    return {"cell": list(p), "region": "interior" if grid.interior(p) else "outer_ring",
            "chebyshev_distance": max(map(abs, vector)), "euclidean_distance": math.hypot(*vector),
            **values, "sector": "forward" if angle <= 45 + 1e-10 else "lateral" if angle <= 135 + 1e-10 else "rear",
            "production_enumerated": p in enumerated, "production_considered": p in considered}


def _lowest(voids: list[dict], distance: dict, parent: dict, source: Point) -> dict | None:
    reachable = [v for v in voids if tuple(v["cell"]) in distance]
    if not reachable:
        return None
    selected = min(reachable, key=lambda v: (*distance[tuple(v["cell"])], v["cell"][1], v["cell"][0]))
    point = tuple(selected["cell"])
    return {**selected, "cost": distance[point][0], "steps": distance[point][1],
            "route": route(parent, source, point)}


def cost_bin(cost: int | None) -> str:
    return "unreachable" if cost is None else str(cost) if cost < 4 else "4+"


def normal_geometry(grid: Grid) -> dict:
    body = grid.capsule.get("current_body")
    previous = grid.capsule.get("previous_body")
    result = {"mode": grid.capsule.get("normal_mode", "unknown")}
    if not body:
        return result
    radial = f32(grid.source[0] + .5 - body[1]), f32(grid.source[1] + .5 - body[2])
    result["radial"] = vector_comparison(grid.normal, radial)
    if previous and previous[11]:
        travel = f32(body[1] - previous[1]), f32(body[2] - previous[2])
        result["translation"] = vector_comparison(grid.normal, travel)
    result["linear_velocity"] = vector_comparison(grid.normal, tuple(body[6:8]))
    cosine, sine = math.cos(body[3]), math.sin(body[3])
    local = f32(cosine * radial[0] + sine * radial[1]), f32(-sine * radial[0] + cosine * radial[1])
    x_pen = f32(body[4] - abs(local[0])) + .5
    y_pen = f32(body[5] - abs(local[1])) + .5
    axis = 0 if x_pen < y_pen else 1
    result["overlap_face"] = ("positive_" if local[axis] >= 0 else "negative_") + ("x" if axis == 0 else "y")
    result["face_penetrations"] = [x_pen, y_pen]
    return result


def analyze_capsule(capsule: dict) -> dict:
    before = canonical_hash(capsule)
    grid = Grid(capsule)
    points = enumerate_candidates(capsule)
    expected_interior = (min([grid.source[0]] + [p[0] for p in points]),
                         min([grid.source[1]] + [p[1] for p in points]),
                         max([grid.source[0]] + [p[0] for p in points]),
                         max([grid.source[1]] + [p[1] for p in points]))
    actual_interior = grid.left + 1, grid.top + 1, grid.left + grid.width - 2, grid.top + grid.height - 2
    if expected_interior != actual_interior:
        raise ValueError("copied ring does not enclose the exact production AABB")
    target, trace = production_replay(grid)
    if target != capsule["target"] or trace != capsule["trace"]:
        raise ValueError("Python float32 enumeration/rejection differential failed")
    considered = {tuple(row[:2]) for row in capsule["trace"]}
    voids = [void_geometry(grid, p, set(points), considered) for p in grid.points(ring=True) if grid.void(p)]
    interior_voids = [v for v in voids if v["region"] == "interior"]
    ring_voids = [v for v in voids if v["region"] == "outer_ring"]
    distance, parent = dijkstra(grid)
    strict, _ = dijkstra(grid, strict=True)
    expanded, expanded_parent = dijkstra(grid, ring=True)
    lowest = _lowest(interior_voids, distance, parent, grid.source)
    lowest_ring = _lowest(ring_voids, expanded, expanded_parent, grid.source)
    for v in voids:
        p = tuple(v["cell"])
        v["interior_cost"] = distance[p][0] if p in distance else None
        v["strict_empty_reachable"] = p in strict
        v["ring_expanded_cost"] = expanded[p][0] if p in expanded else None
    reachable = [v for v in interior_voids if tuple(v["cell"]) in distance]
    low_complexity = [v for v in reachable if v["sector"] != "rear" and distance[tuple(v["cell"])][0] in (1, 2)]
    nonnegative_dot_low_complexity = [v for v in reachable if v["dot"] >= 0 and distance[tuple(v["cell"])][0] in (1, 2)]
    barriers = Counter(grid.barrier(p) for p in grid.points() if grid.barrier(p))
    refusal = "none" if lowest else "no_interior_void" if not interior_voids else "barrier_separated"
    blocked_by = []
    if lowest is None and interior_voids:
        for barrier in ("hard", "foreign", "immovable"):
            relaxed, _ = dijkstra(grid, ignore=frozenset({barrier}))
            if any(tuple(v["cell"]) in relaxed for v in interior_voids):
                blocked_by.append(barrier)
        if not blocked_by:
            blocked_by.append("combined_barriers")
    result = {"replay_hash": capsule["replay_hash"], "source": list(grid.source),
              "production_success": target[0] >= 0, "production_target": target,
              "candidate_count": len(points), "candidate_unique_cells": len(set(points)),
              "candidate_trace_differential": True, "interior_bounds": list(actual_interior),
              "void_count": len(interior_voids), "outer_ring_void_count": len(ring_voids),
              "strict_empty_route": any(tuple(v["cell"]) in strict for v in interior_voids),
              "permissive_movable_route": lowest is not None,
              "minimum_cost": lowest["cost"] if lowest else None,
              "minimum_cost_bin": cost_bin(lowest["cost"] if lowest else None),
              "lowest_void": lowest, "lowest_outer_ring_void": lowest_ring,
              "outer_ring_reachable_only": lowest is None and lowest_ring is not None,
              "ring_void_exists_without_interior_void": not interior_voids and bool(ring_voids),
              "no_void_interior_or_ring": not voids,
              "enumerated_empty_void_count": sum(v["production_enumerated"] for v in interior_voids),
              "nonnegative_dot_cost_1_or_2": bool(nonnegative_dot_low_complexity),
              "forward_or_lateral_cost_1_or_2": bool(low_complexity),
              "forward_or_lateral_low_complexity_voids": [v["cell"] for v in low_complexity],
              "barrier_cell_counts": dict(sorted(barriers.items())), "refusal": refusal,
              "disconnecting_barrier_classes": blocked_by, "normal": normal_geometry(grid),
              "voids": voids}
    result["nonmutation_verified"] = before == canonical_hash(capsule)
    if not result["nonmutation_verified"]:
        raise AssertionError("topology analysis mutated frozen capsule")
    return result


def distribution(rows: list[dict]) -> dict:
    bins = Counter(row["minimum_cost_bin"] for row in rows)
    sectors = Counter(row["lowest_void"]["sector"] if row["lowest_void"] else "unreachable" for row in rows)
    return {"contacts": len(rows), "minimum_cost": {key: bins[key] for key in BINS},
            "lowest_route_sector": {key: sectors[key] for key in ("forward", "lateral", "rear", "unreachable")},
            "strict_empty_routes": sum(row["strict_empty_route"] for row in rows),
            "permissive_movable_routes": sum(row["permissive_movable_route"] for row in rows),
            "forward_or_lateral_cost_1_or_2": sum(row["forward_or_lateral_cost_1_or_2"] for row in rows),
            "outer_ring_reachable_only": sum(row["outer_ring_reachable_only"] for row in rows),
            "ring_void_exists_without_interior_void": sum(row["ring_void_exists_without_interior_void"] for row in rows),
            "no_void_interior_or_ring": sum(row["no_void_interior_or_ring"] for row in rows),
            "nonnegative_dot_cost_1_or_2": sum(row["nonnegative_dot_cost_1_or_2"] for row in rows),
            "contacts_with_enumerated_empty_void": sum(row["enumerated_empty_void_count"] > 0 for row in rows),
            "refusals": dict(sorted(Counter(row["refusal"] for row in rows).items())),
            "disconnecting_barrier_classes": dict(sorted(Counter(x for row in rows for x in row["disconnecting_barrier_classes"]).items())),
            "overlap_faces": dict(sorted(Counter(row["normal"].get("overlap_face", "unknown") for row in rows).items()))}


def analyze_corpus(data: dict) -> dict:
    before = canonical_hash(data)
    rows = [analyze_capsule(c) for c in data["capsules"]]
    return {"schema_version": 1, "corpus_semantic_sha256": before,
            "semantics": {"interior": "AABB(source, all81production_endpoint_cells), geometric overapproximation",
                          "outer_ring": "captured one-cell boundary, diagnostic only",
                          "minimum_cost": "intermediate movable cells; displaced source excluded; not a legal-move proof",
                          "own_body_mask": "permissive graph may traverse own mask; strict graph requires empty/unmasked after source",
                          "sectors": "forward angle<=45; lateral45<angle<=135; rear angle>135",
                          "ties": "lowest void: cost, steps, y, x; deterministic predecessor discovery: cost, steps, x, y"},
            "unresolved": distribution([r for r in rows if not r["production_success"]]),
            "positive_controls": distribution([r for r in rows if r["production_success"]]),
            "capsules": rows, "nonmutation_verified": before == canonical_hash(data)}


def synthetic_cases() -> dict[str, dict]:
    """Seven controlled fixtures using the actual rightward production AABB."""
    def make(name: str, changes: dict[Point, tuple]) -> dict:
        source = (32, 32)
        bounds = [31, 27, 12, 11]
        wall = (1, 0, 0, 200, 0, True, False, 0, "0000000000000001")
        sand = (2, 0, 0, 200, 0, False, True, 0, "0000000000000002")
        if name == "jammed":
            base = sand
        else:
            base = wall
        c = {"schema_version": 1, "source": list(source), "normal": [1., 0.], "penetration": .5,
             "body_id": 1, "first_distance": 1, "maximum_distance": 8, "tangent_probes": 9,
             "bounds": bounds, "world_bounds": [0, 0, 1024, 1024], "replay_hash": "synthetic-" + name,
             "cells": [list(base) for _ in range(bounds[2] * bounds[3])]}
        changes = {source: (*sand[:4], 1, *sand[5:]), **changes}
        for (x, y), row in changes.items():
            c["cells"][(y - bounds[1]) * bounds[2] + x - bounds[0]] = list(row)
        c["target"], c["trace"] = production_replay(Grid(c))
        return c
    empty = (0, 0, 0, 200, 0, False, False, 0, "0000000000000000")
    sand = (2, 0, 0, 200, 0, False, True, 0, "0000000000000002")
    foreign = (0, 0, 0, 200, 2, False, False, 0, "0000000000000000")
    return {
        "direct_forward_empty": make("direct_forward_empty", {(33, 32): empty}),
        "one_movable_forward": make("one_movable_forward", {(33, 32): sand, (34, 32): empty}),
        "lateral_void": make("lateral_void", {(32, 31): empty}),
        "rear_only_void": make("rear_only_void", {(31, 32): empty}),
        "hard_wall": make("hard_wall", {(34, 32): empty}),
        "foreign_body": make("foreign_body", {(33, 32): foreign, (34, 32): empty}),
        "jammed": make("jammed", {}),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("read-only analysis requires a separate output path")
    original = args.input.read_bytes()
    result = analyze_corpus(json.loads(original))
    result["input_file_sha256"] = hashlib.sha256(original).hexdigest()
    result["synthetic_cases"] = {name: analyze_capsule(c) for name, c in synthetic_cases().items()}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    if args.input.read_bytes() != original:
        raise AssertionError("input file changed during read-only analysis")
    print(json.dumps({key: result[key] for key in ("unresolved", "positive_controls", "nonmutation_verified")}, sort_keys=True))


if __name__ == "__main__":
    main()
