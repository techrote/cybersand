"""Descriptive cursor-line diagnostics for D-1A DEVELOPMENT trajectories.

These geometry descriptors are NOT aesthetic scores, target-completion scores,
material readbacks, neural observations, or native evidence. An odd detour,
loop or retraced stroke can be a useful drawing-worm behaviour.
"""
from __future__ import annotations

from collections import Counter
from math import log2
from typing import Any, Sequence

VERSION = "d1a-cursor-line-character/1"
MAX_CURSOR_PATH_CELLS = 4097


def describe_cursor_path(path: Sequence[Sequence[int]]) -> dict[str, Any]:
    """Describe exact 4-connected cursor travel, including retraces and loops.

    Accepts Python tuple points or JSON-decoded list points. Each adjacent
    pair must be one legal cardinal cell. STOP never adds a cursor cell.
    This is deliberately independent of goals, wall-offset compliance, and
    subjective notions of a good drawing.
    """
    if not isinstance(path, (list, tuple)) or not 1 <= len(path) <= MAX_CURSOR_PATH_CELLS:
        raise ValueError("Expected a bounded, nonempty cursor path")
    points: list[tuple[int, int]] = []
    for p in path:
        if (not isinstance(p, (list, tuple)) or len(p) != 2 or
                any(type(v) is not int for v in p)):
            raise ValueError("Cursor points must have exactly two integer coordinates")
        points.append((p[0], p[1]))

    headings: list[tuple[int, int]] = []
    visited_at: dict[tuple[int, int], int] = {points[0]: 0}
    used_edges: set[tuple[tuple[int, int], tuple[int, int]]] = set()
    repeated_positions = 0
    repeated_edges = 0
    loop_closures = 0
    for i, (old, new) in enumerate(zip(points, points[1:]), start=1):
        delta = (new[0] - old[0], new[1] - old[1])
        if abs(delta[0]) + abs(delta[1]) != 1:
            raise ValueError("Cursor path is not four-connected at step " + str(i))
        headings.append(delta)
        if new in visited_at:
            repeated_positions += 1
            if i - visited_at[new] >= 4:
                loop_closures += 1
        visited_at[new] = i
        edge = tuple(sorted((old, new)))
        if edge in used_edges:
            repeated_edges += 1
        used_edges.add(edge)

    right = left = reversals = 0
    current_straight = longest_straight = 0
    for i, heading in enumerate(headings):
        if i == 0 or heading == headings[i - 1]:
            current_straight += 1
        else:
            longest_straight = max(longest_straight, current_straight)
            current_straight = 1
            prev = headings[i - 1]
            cross = prev[0] * heading[1] - prev[1] * heading[0]
            if cross > 0:
                right += 1  # screen/world Y grows downward
            elif cross < 0:
                left += 1
            else:
                reversals += 1
    longest_straight = max(longest_straight, current_straight)
    hist = Counter({"E": 0, "N": 0, "S": 0, "W": 0})
    symbols = {(1, 0): "E", (0, -1): "N", (0, 1): "S", (-1, 0): "W"}
    for heading in headings:
        hist[symbols[heading]] += 1
    steps = len(headings)
    entropy = -sum((v / steps) * log2(v / steps) for v in hist.values() if v) if steps else 0.0
    min_x, max_x = min(p[0] for p in points), max(p[0] for p in points)
    min_y, max_y = min(p[1] for p in points), max(p[1] for p in points)
    return {
        "version": VERSION,
        "evidence_kind": "descriptive_synthetic_cursor_geometry_only",
        "native_qualified": False,
        "artistic_quality_measured": False,
        "cursor_cells_including_start": len(points),
        "movement_cells": steps,
        "distinct_cursor_cells": len(visited_at),
        "revisited_cursor_steps": repeated_positions,
        "reused_undirected_edge_steps": repeated_edges,
        "nontrivial_loop_closures": loop_closures,
        "right_angle_clockwise_turns": right,
        "left_angle_counterclockwise_turns": left,
        "immediate_reverse_turns": reversals,
        "turn_fraction_per_heading_transition": round((left + right) / max(1, steps - 1), 6),
        "maximum_consecutive_straight_cells": longest_straight,
        "heading_counts": dict(hist),
        "heading_entropy_bits": round(entropy, 6),
        "bounding_box_xyxy": [min_x, min_y, max_x, max_y],
        "terminal_cursor": list(points[-1]),
    }


def audit_development_line_character(fixture: Any, episode: dict[str, Any]) -> dict[str, Any]:
    """Require complete original episode replay before describing its path.

    This entry point never executes a new controller, never opens held-out
    policy outcomes, and never upgrades a synthetic path to a PAINT receipt.
    """
    from . import paired

    custody = paired.verify_episode(fixture, episode)
    return {
        "version": VERSION,
        "evidence_kind": "replay_verified_development_cursor_geometry_only",
        "fixture_sha256": custody["fixture_sha256"],
        "original_trajectory_sha256": custody["path_sha256"],
        "original_policy": episode["policy"],
        "original_decision_count": custody["event_count"],
        "native_qualified": False,
        "model_evaluated": False,
        "heldout_behavior_evaluated": False,
        "character": describe_cursor_path(episode["path"]),
        "interpretation": "A descriptive sketchbook fingerprint, never an artistic ranking or controller success claim",
    }
