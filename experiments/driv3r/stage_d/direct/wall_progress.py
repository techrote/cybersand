"""Source-replayed DEVELOPMENT-only progress along the *selected* wall.

The v1 score's max-Y progress can read 100% when a cursor traverses the
World far from the selected wall. This supplementary diagnostic does not
rewrite frozen episode metrics, fixture identities, or native evidence.
"""
from __future__ import annotations

from typing import Any, Callable

from . import offline as d
from . import paired

VERSION = "d1a-selected-wall-ordered-progress/2"


def _summarize_wall_progress(
    path: list[d.Point], first_y: int, last_y: int,
    selected_wall_distance: Callable[[d.Point], float],
) -> dict[str, Any]:
    """Count band-qualified *ordered* wall rows, not arbitrary vertical travel."""
    if not path or first_y >= last_y:
        raise ValueError("A nonempty increasing wall profile is required")
    next_row = first_y
    qualified_rows: set[int] = set()
    off_band_steps = 0
    longest_off_band_run = 0
    current_off_band_run = 0
    exits = 0
    reentries = 0
    previous_in_band = None
    first_exit_index = None
    # This counts a *physically continuous* advancing in-band row run.
    # Mere visits to every row can otherwise conceal long off-band detours.
    previous_forward_row = None
    consecutive_forward_rows = 0
    longest_forward_rows = 0
    longest_forward_start_row = None
    longest_forward_end_row = None
    for cell_index, point in enumerate(path):
        clearance = selected_wall_distance(point)
        in_band = 6.0 <= clearance <= 10.0
        if in_band and first_y <= point[1] <= last_y:
            qualified_rows.add(point[1])
            if point[1] == next_row:
                next_row += 1
        if in_band and first_y <= point[1] <= last_y:
            if previous_forward_row is None:
                consecutive_forward_rows = 1
            elif point[1] == previous_forward_row + 1:
                consecutive_forward_rows += 1
            elif point[1] != previous_forward_row:
                # A backward move or a sparse row jump starts a new run.
                consecutive_forward_rows = 1
            previous_forward_row = point[1]
            if consecutive_forward_rows > longest_forward_rows:
                longest_forward_rows = consecutive_forward_rows
                longest_forward_start_row = point[1] - consecutive_forward_rows + 1
                longest_forward_end_row = point[1]
        else:
            # Departing the selected band or the target's row range severs
            # continuity, even if later row visits complete ordered coverage.
            consecutive_forward_rows = 0
            previous_forward_row = None
        if not in_band:
            off_band_steps += 1
            current_off_band_run += 1
            longest_off_band_run = max(longest_off_band_run, current_off_band_run)
        else:
            current_off_band_run = 0
        if previous_in_band is True and not in_band:
            exits += 1
            if first_exit_index is None:
                first_exit_index = cell_index
        if previous_in_band is False and in_band:
            reentries += 1
        previous_in_band = in_band
    profile_rows = last_y - first_y + 1
    ordered = next_row - first_y
    # Starting on the first qualified row is zero *traversal* progress.
    ordered_progress = max(0.0, (ordered - 1) / (last_y - first_y))
    raw_progress = max(0.0, min(1.0,
        (max(p[1] for p in path) - first_y) / (last_y - first_y)))
    return {
        "profile_row_count": profile_rows,
        "ordered_band_qualified_rows": ordered,
        "ordered_band_progress_fraction": round(ordered_progress, 6),
        "longest_contiguous_forward_band_rows": longest_forward_rows,
        "longest_contiguous_forward_band_progress_fraction": round(
            max(0, longest_forward_rows - 1) / (last_y - first_y), 6),
        "longest_contiguous_forward_band_start_row": longest_forward_start_row,
        "longest_contiguous_forward_band_end_row": longest_forward_end_row,
        "distinct_band_qualified_rows": len(qualified_rows),
        "distinct_band_row_coverage_fraction": round(len(qualified_rows) / profile_rows, 6),
        "ungated_max_y_progress_fraction": round(raw_progress, 6),
        "ungated_minus_ordered_progress": round(raw_progress - ordered_progress, 6),
        "off_band_path_cells": off_band_steps,
        "longest_consecutive_off_band_path_cells": longest_off_band_run,
        "band_exits": exits,
        "band_reentries": reentries,
        "first_band_exit_path_index": first_exit_index,
    }


def audit_development_wall_progress(fixture: d.Fixture,
                                    episode: dict[str, Any]) -> dict[str, Any]:
    """Use independently replayed original cursor cells; never run a new arm."""
    custody = paired.verify_episode(fixture, episode)  # Seals held-out/source mutations.
    if fixture.task != "wall_offset":
        raise ValueError("Selected-wall progress requires a wall-offset fixture")
    first_y = fixture.start[1]
    last_y = fixture.target[1]
    summary = _summarize_wall_progress(
        [tuple(p) for p in episode["path"]], first_y, last_y,
        lambda p: d.wall_distance(fixture, p),
    )
    if summary["ungated_max_y_progress_fraction"] != episode["metrics"]["route_progress_fraction"]:
        raise ValueError("Replay-qualified v1 progress does not match diagnostic")
    return {
        "version": VERSION,
        "evidence_class": "replay_verified_offline_geometry_only",
        "native_qualified": False,
        "model_evaluated": False,
        "heldout_behavior_evaluated": False,
        "fixture_sha256": fixture.sha256,
        "verified_original_trajectory_sha256": custody["path_sha256"],
        "selected_wall_id": fixture.fixture_id + "/selected-wall",
        "band_distance_cells": [6, 10],
        "terminal_arrival_from_original_score": episode["metrics"]["arrived"],
        "summary": summary,
        "interpretation": "Band-qualified ordered row progress is not native or controller success",
    }
