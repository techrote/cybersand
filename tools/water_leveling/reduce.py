#!/usr/bin/env python3
"""Reduce preregistered CyberSand issue #26 Water-leveling JSONL traces.

The formulas in this module are intentionally mechanical translations of
docs/operations/water-leveling-experiment.md.  Do not tune thresholds here after
baseline data exist; change the registration version instead.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Iterable, Sequence

MASS_MAX = 255
FIXTURES = {
    "r8": {"bed": 72, "leveling_rois": [(4, 47)], "surface_rois": [(4, 47)]},
    "r24": {"bed": 72, "leveling_rois": [(4, 47)], "surface_rois": [(4, 47)]},
    "r40": {"bed": 72, "leveling_rois": [(4, 47)], "surface_rois": [(4, 47)]},
    "cp16": {
        "bed": 72,
        "leveling_rois": [(8, 55), (72, 119)],
        "surface_rois": [(8, 55), (72, 119)],
        "arm_width": 48,
    },
    "ut96_48": {
        "bed": 116,
        "leveling_rois": [(36, 43), (84, 91)],
        "surface_rois": [(36, 43), (84, 91)],
        "arm_width": 8,
    },
    "cn": {"bed": 72, "leveling_rois": [(4, 63)], "surface_rois": [(4, 63)]},
    "fd": {
        "bed": 88,
        "leveling_rois": [(33, 126)],
        "surface_rois": [(33, 126)],
        "defect_rois": [(36, 123)],
    },
    "cs": {"bed": 88, "leveling_rois": [(1, 126)], "surface_rois": [(1, 126)]},
    "ls": {
        "bed": 104,
        "leveling_rois": [(64, 126)],
        "surface_rois": [(64, 126)],
        "defect_rois": [(68, 123)],
    },
}
FLAT_FIXTURES = {"cp16", "ut96_48", "cs"}


def read_jsonl(path: Path) -> tuple[dict, list[dict], dict]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not rows or not rows[0].get("metadata"):
        raise ValueError(f"{path}: missing metadata row")
    if not rows[-1].get("result"):
        raise ValueError(f"{path}: missing result row")
    trace = [row for row in rows[1:-1] if "tick" in row]
    if not trace or trace[0]["tick"] != 0:
        raise ValueError(f"{path}: trace must start at tick 0")
    return rows[0], trace, rows[-1]


def ols_slope(points: Sequence[tuple[float, float]]) -> float | None:
    if len(points) < 2:
        return None
    mx = sum(x for x, _ in points) / len(points)
    my = sum(y for _, y in points) / len(points)
    den = sum((x - mx) ** 2 for x, _ in points)
    if den == 0:
        return None
    return sum((x - mx) * (y - my) for x, y in points) / den


def surface_height(q: int, bed: int) -> float:
    return float(bed) - float(q) / MASS_MAX


def roi_points(columns: Sequence[int], roi: tuple[int, int], bed: int, wet_only: bool) -> list[tuple[float, float]]:
    x0, x1 = roi
    out = []
    for x in range(x0, x1 + 1):
        q = columns[x]
        if wet_only and q == 0:
            continue
        out.append((float(x), surface_height(q, bed)))
    return out


def max_abs_global_slope(columns: Sequence[int], rois: Sequence[tuple[int, int]], bed: int, wet_only: bool) -> float:
    values = []
    for roi in rois:
        slope = ols_slope(roi_points(columns, roi, bed, wet_only))
        if slope is not None:
            values.append(abs(slope))
    return max(values, default=0.0)


def max_abs_local_slope(
    columns: Sequence[int],
    rois: Sequence[tuple[int, int]],
    bed: int,
    *,
    wet_only: bool,
    window: int = 9,
) -> float:
    values: list[float] = []
    for x0, x1 in rois:
        for start in range(x0, x1 - window + 2):
            xs = range(start, start + window)
            if wet_only and any(columns[x] == 0 for x in xs):
                continue
            points = [(float(x), surface_height(columns[x], bed)) for x in xs]
            slope = ols_slope(points)
            if slope is not None:
                values.append(abs(slope))
    return max(values, default=0.0)


def cliff_counts(columns: Sequence[int], rois: Sequence[tuple[int, int]]) -> tuple[set[int], set[int]]:
    internal: set[int] = set()
    leveling: set[int] = set()
    for x0, x1 in rois:
        for x in range(x0, x1):
            a, b = columns[x], columns[x + 1]
            if abs(a - b) > MASS_MAX:
                leveling.add(x)
                if a > 0 and b > 0:
                    internal.add(x)
    return internal, leveling


def fit_hill_residuals(
    columns: Sequence[int],
    rois: Sequence[tuple[int, int]],
    bed: int,
) -> dict[int, float]:
    residuals: dict[int, float] = {}
    for x0, x1 in rois:
        for x in range(x0, x1 + 1):
            if columns[x] == 0:
                continue
            left_positions = list(range(max(x0, x - 12), max(x0, x - 3) + 1))
            right_positions = list(range(min(x1, x + 3), min(x1, x + 12) + 1))
            left = [sx for sx in left_positions if sx <= x - 3 and columns[sx] > 0]
            right = [sx for sx in right_positions if sx >= x + 3 and columns[sx] > 0]
            support = left + right
            if len(support) < 8:
                continue
            left_available = any(sx <= x - 3 for sx in range(max(x0, x - 12), min(x1, x - 3) + 1))
            right_available = any(sx >= x + 3 for sx in range(max(x0, x + 3), min(x1, x + 12) + 1))
            if left_available and right_available and (len(left) < 3 or len(right) < 3):
                continue
            points = [(float(sx), surface_height(columns[sx], bed)) for sx in support]
            slope = ols_slope(points)
            if slope is None:
                continue
            mx = sum(px for px, _ in points) / len(points)
            my = sum(py for _, py in points) / len(points)
            baseline = my + slope * (x - mx)
            residuals[x] = max(0.0, baseline - surface_height(columns[x], bed))
    return residuals


def hill_metrics(columns: Sequence[int], rois: Sequence[tuple[int, int]], bed: int) -> tuple[float, int]:
    residuals = fit_hill_residuals(columns, rois, bed)
    if not residuals:
        return 0.0, 0
    peak_x, amplitude = max(residuals.items(), key=lambda item: item[1])
    if amplitude <= 0.0:
        return 0.0, 0
    width = 1 if residuals.get(peak_x, 0.0) >= 0.25 else 0
    if width:
        x = peak_x - 1
        while residuals.get(x, 0.0) >= 0.25:
            width += 1
            x -= 1
        x = peak_x + 1
        while residuals.get(x, 0.0) >= 0.25:
            width += 1
            x += 1
    return amplitude, width


def quarter_bin(q: int, bed: int) -> int:
    # floor(4*H + 1/2); keeping the integer bin avoids float equality in terraces.
    return math.floor(4.0 * surface_height(q, bed) + 0.5)


def terrace_metrics(
    columns: Sequence[int],
    rois: Sequence[tuple[int, int]],
    bed: int,
) -> tuple[int, int, int, float, bool, set[int]]:
    runs: list[tuple[int, int, int]] = []
    edge_positions: set[int] = set()
    for x0, x1 in rois:
        current_start: int | None = None
        current_bin: int | None = None
        previous_wet_x: int | None = None
        previous_bin: int | None = None
        for x in range(x0, x1 + 1):
            q = columns[x]
            if q == 0:
                if current_start is not None and previous_wet_x is not None:
                    runs.append((current_start, previous_wet_x, int(current_bin)))
                current_start = None
                current_bin = None
                previous_wet_x = None
                previous_bin = None
                continue
            b = quarter_bin(q, bed)
            if current_start is None:
                current_start, current_bin = x, b
            elif b != current_bin or previous_wet_x != x - 1:
                runs.append((current_start, int(previous_wet_x), int(current_bin)))
                current_start, current_bin = x, b
            previous_wet_x, previous_bin = x, b
        if current_start is not None and previous_wet_x is not None:
            runs.append((current_start, previous_wet_x, int(current_bin)))

    by_start = sorted(runs)
    for left, right in zip(by_start, by_start[1:]):
        if left[1] + 1 != right[0] or left[2] == right[2]:
            continue
        left_extent = left[1] - left[0] + 1
        right_extent = right[1] - right[0] + 1
        if left_extent >= 3 or right_extent >= 3:
            edge_positions.add(left[1])

    terraces = [run for run in runs if run[1] - run[0] + 1 >= 3]
    count = len(terraces)
    total_extent = sum(end - start + 1 for start, end, _ in terraces)
    largest_extent = max((end - start + 1 for start, end, _ in terraces), default=0)

    largest_step_bins = 0
    severe = False
    for idx, run in enumerate(by_start):
        start, end, b = run
        extent = end - start + 1
        adjacent_steps: list[int] = []
        if idx > 0 and by_start[idx - 1][1] == start - 1:
            adjacent_steps.append(abs(b - by_start[idx - 1][2]))
        if idx + 1 < len(by_start) and end + 1 == by_start[idx + 1][0]:
            adjacent_steps.append(abs(b - by_start[idx + 1][2]))
        if adjacent_steps:
            local_step = max(adjacent_steps)
            largest_step_bins = max(largest_step_bins, local_step)
            if extent >= 6 and local_step >= 2:
                severe = True
    return count, total_extent, largest_extent, largest_step_bins / 4.0, severe, edge_positions


def persistent_first(values: Sequence[float], predicate, duration: int) -> int | None:
    run = 0
    start = 0
    for index, value in enumerate(values):
        if predicate(value):
            if run == 0:
                start = index
            run += 1
            if run >= duration:
                return start
        else:
            run = 0
    return None


def longest_true_run(flags: Iterable[bool]) -> int:
    best = run = 0
    for value in flags:
        if value:
            run += 1
            best = max(best, run)
        else:
            run = 0
    return best


def edge_lifetimes(edge_sets: Sequence[set[int]]) -> tuple[int, int]:
    active: dict[int, int] = {}
    longest = 0
    total = 0
    for edges in edge_sets:
        total += len(edges)
        next_active: dict[int, int] = {}
        for edge in edges:
            length = active.get(edge, 0) + 1
            next_active[edge] = length
            longest = max(longest, length)
        active = next_active
    return longest, total


def metric_rows(fixture: str, rows: Sequence[dict]) -> list[dict]:
    cfg = FIXTURES[fixture]
    bed = cfg["bed"]
    out = []
    for row in rows:
        columns = row.get("columns")
        if columns is None:
            raise ValueError("reduction requires trace rows with columns")
        global_leveling = max_abs_global_slope(columns, cfg["leveling_rois"], bed, False)
        local_leveling = max_abs_local_slope(columns, cfg["leveling_rois"], bed, wet_only=False)
        defect_rois = cfg.get("defect_rois", cfg["surface_rois"])
        global_surface = max_abs_global_slope(columns, defect_rois, bed, True)
        local_surface = max_abs_local_slope(columns, defect_rois, bed, wet_only=True)
        internal, leveling = cliff_counts(columns, cfg["leveling_rois"])
        hill_amp, hill_width = hill_metrics(columns, defect_rois, bed)
        terrace_count, terrace_extent, terrace_largest, terrace_step, severe, edges = terrace_metrics(
            columns, defect_rois, bed
        )
        quantities = [columns[x] for x0, x1 in cfg["leveling_rois"] for x in range(x0, x1 + 1)]
        arm_difference = None
        if fixture == "cp16":
            arm_difference = abs(row["left"] / (48.0 * MASS_MAX) - row["right"] / (48.0 * MASS_MAX))
        elif fixture == "ut96_48":
            arm_difference = abs(row["left"] / (8.0 * MASS_MAX) - row["right"] / (8.0 * MASS_MAX))
        flat_conditions = (
            max(quantities, default=0) - min(quantities, default=0) <= MASS_MAX
            and local_leveling <= 1.0 / 16.0
            and not leveling
            and (arm_difference is None or arm_difference <= 0.5)
        )
        out.append({
            "tick": row["tick"],
            "quantity": row["quantity"],
            "global_leveling_slope": global_leveling,
            "local_leveling_slope": local_leveling,
            "global_surface_slope": global_surface,
            "local_surface_slope": local_surface,
            "internal_cliffs": internal,
            "leveling_cliffs": leveling,
            "hill_amplitude": hill_amp,
            "hill_width": hill_width,
            "terrace_count": terrace_count,
            "terrace_extent": terrace_extent,
            "terrace_largest_extent": terrace_largest,
            "terrace_largest_step": terrace_step,
            "severe_terrace": severe,
            "terrace_edges": edges,
            "arm_difference": arm_difference,
            "flat_conditions": flat_conditions,
            "downstream": row.get("downstream", 0),
            "range": row.get("max_wet_x", 0) - row.get("min_wet_x", 0),
            "wall_gap": row.get("wall_gap", 0),
            "wall_gap_max_run": row.get("wall_gap_max_run", 0),
            "components": row.get("components", 0),
            "small_components": row.get("small_components", 0),
            "occupied": row.get("occupied", 0),
            "partial": row.get("partial", 0),
            "visited": row.get("visited", 0),
            "moved": row.get("moved", 0),
            "active_blocks": row.get("active_blocks", 0),
        })
    return out


def surface_phase_start(fixture: str, rows: Sequence[dict]) -> int | None:
    cfg = FIXTURES[fixture]
    defect_rois = cfg.get("defect_rois", cfg["surface_rois"])
    if fixture == "cs":
        flags = []
        for row in rows:
            columns = row["columns"]
            quantities = [
                columns[x]
                for x0, x1 in cfg["leveling_rois"]
                for x in range(x0, x1 + 1)
            ]
            flags.append(max(quantities, default=0) - min(quantities, default=0) <= 4 * MASS_MAX)
        index = persistent_first(flags, bool, 60)
        return None if index is None else rows[index]["tick"]
    if fixture == "fd":
        for row in rows:
            if row["columns"][126] > 0:
                return row["tick"]
        return None
    if fixture == "ls":
        flags = []
        for row in rows:
            columns = row["columns"]
            flags.append(all(
                columns[x] > 0
                for x0, x1 in defect_rois
                for x in range(x0, x1 + 1)
            ))
        index = persistent_first(flags, bool, 60)
        return None if index is None else rows[index]["tick"]
    return rows[0]["tick"] if rows else None


def surface_l1_cell_equivalents(
    before: Sequence[int],
    after: Sequence[int],
    rois: Sequence[tuple[int, int]],
) -> float:
    return sum(
        abs(after[x] - before[x])
        for x0, x1 in rois
        for x in range(x0, x1 + 1)
    ) / MASS_MAX


def summarize(path: Path) -> dict:
    metadata, rows, final = read_jsonl(path)
    fixture = metadata["fixture"]
    if fixture not in FIXTURES:
        raise ValueError(f"unregistered fixture {fixture}")
    metrics = metric_rows(fixture, rows)
    ticks = [row["tick"] for row in metrics]
    if ticks != list(range(ticks[-1] + 1)):
        raise ValueError("trace must contain every tick")

    local = [row["local_leveling_slope"] for row in metrics]
    primary_half = None
    if local[0] > 0:
        index = persistent_first(local, lambda v: v <= local[0] / 2.0, 60)
        primary_half = None if index is None else ticks[index]

    global_values = [row["global_leveling_slope"] for row in metrics]
    global_half = None
    if global_values[0] > 0:
        index = persistent_first(global_values, lambda v: v <= global_values[0] / 2.0, 60)
        global_half = None if index is None else ticks[index]

    arm_values = [row["arm_difference"] for row in metrics]
    arm_half = None
    if arm_values[0] is not None and arm_values[0] > 0:
        index = persistent_first(arm_values, lambda v: v is not None and v <= arm_values[0] / 2.0, 60)
        arm_half = None if index is None else ticks[index]

    time_to_flat = None
    if fixture in FLAT_FIXTURES:
        index = persistent_first([1.0 if row["flat_conditions"] else 0.0 for row in metrics], lambda v: v == 1.0, 120)
        time_to_flat = None if index is None else ticks[index]

    internal_sets = [row["internal_cliffs"] for row in metrics]
    leveling_sets = [row["leveling_cliffs"] for row in metrics]
    internal_life, internal_edge_ticks = edge_lifetimes(internal_sets)
    leveling_life, leveling_edge_ticks = edge_lifetimes(leveling_sets)

    hill_flags = [row["hill_amplitude"] >= 0.5 for row in metrics]
    terrace_flags = [row["severe_terrace"] for row in metrics]
    wall_flags = [row["wall_gap"] > 0 for row in metrics]

    surface_start = surface_phase_start(fixture, rows)
    registered_metrics = (
        [row for row in metrics if row["tick"] >= surface_start]
        if surface_start is not None else []
    )
    registered_rows = (
        [row for row in rows if row["tick"] >= surface_start]
        if surface_start is not None else []
    )
    registered_hill_flags = [row["hill_amplitude"] >= 0.5 for row in registered_metrics]
    registered_terrace_flags = [row["severe_terrace"] for row in registered_metrics]
    registered_turnover = 0
    registered_low_motion_turnover = 0
    registered_low_motion_transitions = 0
    registered_motion_l1 = 0.0
    defect_rois = FIXTURES[fixture].get("defect_rois", FIXTURES[fixture]["surface_rois"])
    for before_metric, after_metric, before_row, after_row in zip(
        registered_metrics, registered_metrics[1:], registered_rows, registered_rows[1:]
    ):
        turnover = len(before_metric["terrace_edges"].symmetric_difference(after_metric["terrace_edges"]))
        registered_turnover += turnover
        motion = surface_l1_cell_equivalents(before_row["columns"], after_row["columns"], defect_rois)
        registered_motion_l1 += motion
        if motion <= 1.0:
            registered_low_motion_transitions += 1
            registered_low_motion_turnover += turnover
    registered_seconds = (
        max(1, registered_metrics[-1]["tick"] - registered_metrics[0]["tick"]) / 60.0
        if registered_metrics else 0.0
    )

    edge_turnover = 0
    for a, b in zip(metrics, metrics[1:]):
        edge_turnover += len(a["terrace_edges"].symmetric_difference(b["terrace_edges"]))
    simulated_seconds = max(1, ticks[-1]) / 60.0

    by_tick = {row["tick"]: row for row in metrics}
    early = {}
    for tick in (30, 60, 120, 240):
        if tick in by_tick:
            early[str(tick)] = {
                "downstream_units": by_tick[tick]["downstream"],
                "downstream_cell_equivalents": by_tick[tick]["downstream"] / MASS_MAX,
            }

    return {
        "schema": "cybersand-water-leveling-reduction-v2",
        "source_trace": str(path),
        "fixture": fixture,
        "horizon": ticks[-1],
        "initial_quantity": metadata["initial_quantity"],
        "final_quantity": final["quantity"],
        "conserved": metadata["initial_quantity"] == final["quantity"] == rows[-1]["quantity"],
        "primary_local_slope_half_life_tick": primary_half,
        "global_slope_half_life_tick": global_half,
        "arm_level_half_life_tick": arm_half,
        "time_to_flat_tick": time_to_flat,
        "initial_arm_difference_cells": arm_values[0],
        "final_arm_difference_cells": arm_values[-1],
        "peak_global_leveling_slope": max(global_values, default=0.0),
        "peak_local_leveling_slope": max(local, default=0.0),
        "final_global_leveling_slope": global_values[-1],
        "final_local_leveling_slope": local[-1],
        "max_hill_amplitude_cells": max((row["hill_amplitude"] for row in metrics), default=0.0),
        "max_hill_width_cells": max((row["hill_width"] for row in metrics), default=0),
        "hill_lifetime_ticks": longest_true_run(hill_flags),
        "max_terrace_count": max((row["terrace_count"] for row in metrics), default=0),
        "max_terrace_extent_cells": max((row["terrace_extent"] for row in metrics), default=0),
        "max_terrace_step_cells": max((row["terrace_largest_step"] for row in metrics), default=0.0),
        "severe_terrace_lifetime_ticks": longest_true_run(terrace_flags),
        "terrace_edge_turnover": edge_turnover,
        "terrace_edge_turnover_per_sim_second": edge_turnover / simulated_seconds,
        "internal_cliff_lifetime_ticks": internal_life,
        "internal_cliff_edge_ticks": internal_edge_ticks,
        "leveling_cliff_lifetime_ticks": leveling_life,
        "leveling_cliff_edge_ticks": leveling_edge_ticks,
        "max_wall_gap_area_cells": max((row["wall_gap"] for row in metrics), default=0),
        "max_wall_gap_vertical_run_cells": max((row["wall_gap_max_run"] for row in metrics), default=0),
        "wall_gap_lifetime_ticks": longest_true_run(wall_flags),
        "registered_surface_start_tick": surface_start,
        "registered_surface_censored": surface_start is None,
        "registered_surface_max_hill_amplitude_cells": max(
            (row["hill_amplitude"] for row in registered_metrics), default=None
        ),
        "registered_surface_max_hill_width_cells": max(
            (row["hill_width"] for row in registered_metrics), default=None
        ),
        "registered_surface_hill_lifetime_ticks": (
            longest_true_run(registered_hill_flags) if registered_metrics else None
        ),
        "registered_surface_max_terrace_count": max(
            (row["terrace_count"] for row in registered_metrics), default=None
        ),
        "registered_surface_max_terrace_step_cells": max(
            (row["terrace_largest_step"] for row in registered_metrics), default=None
        ),
        "registered_surface_severe_terrace_lifetime_ticks": (
            longest_true_run(registered_terrace_flags) if registered_metrics else None
        ),
        "registered_surface_terrace_edge_turnover": (
            registered_turnover if registered_metrics else None
        ),
        "registered_surface_turnover_per_sim_second": (
            registered_turnover / registered_seconds if registered_seconds > 0 else None
        ),
        "registered_surface_motion_l1_cell_equivalents": (
            registered_motion_l1 if registered_metrics else None
        ),
        "registered_surface_turnover_per_motion_cell_equivalent": (
            registered_turnover / max(1.0, registered_motion_l1)
            if registered_metrics else None
        ),
        "registered_surface_low_motion_edge_turnover": (
            registered_low_motion_turnover if registered_metrics else None
        ),
        "registered_surface_low_motion_transition_count": (
            registered_low_motion_transitions if registered_metrics else None
        ),
        "peak_range_cells": max((row["range"] for row in metrics), default=0),
        "peak_small_components": max((row["small_components"] for row in metrics), default=0),
        "peak_components": max((row["components"] for row in metrics), default=0),
        "max_occupied_cells": max((row["occupied"] for row in metrics), default=0),
        "max_partial_cells": max((row["partial"] for row in metrics), default=0),
        "early_discharge": early,
        "work": {
            "visited_total": sum(row["visited"] for row in metrics),
            "moved_total": sum(row["moved"] for row in metrics),
            "active_block_ticks": sum(row["active_blocks"] for row in metrics),
        },
        "censored": {
            "primary_local_slope_half_life": primary_half is None,
            "arm_level_half_life": arm_values[0] is not None and arm_half is None,
            "time_to_flat": fixture in FLAT_FIXTURES and time_to_flat is None,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    summary = summarize(args.trace)
    rendered = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
