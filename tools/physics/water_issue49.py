"""Run the frozen issue #49 Water successor-apparatus v2 campaign.

The historical issue #26 runner remains untouched.  This runner is deliberately
failure-retaining: every registered attempt receives a durable disposition and a
completion manifest is written only after the full registered matrix is accounted.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import platform
import statistics
import subprocess
import time
from pathlib import Path
from typing import Any, Iterable

from run import ROOT, identity

APPARATUS_SCHEMA = "water-apparatus-v2"
FIXTURE_SCHEMA = "water-fixtures-v2"
METRIC_SCHEMA = "water-equilibrium-v2"
RUNNER_SCHEMA = "water-evidence-runner-v2"
SAMPLE_PERIOD = 60
SUSTAINED_SAMPLES = 5

SCENARIOS = [
    "head-shallow",
    "head-medium",
    "head-deep",
    "communicating-pools",
    "unequal-head-communicating-reservoir-v2",
    "unequal-head-two-limb-v2",
    "constriction",
    "fast-dump",
    "calm-settling",
    "ledge-sheet",
]
SHIFTS = [-65, 0, 63]
MIRRORS = [0, 1]
WORKERS = [1, 4]

TIMING_KEYS = {
    "setup_us",
    "total_us",
    "p50_us",
    "p95_us",
    "p99_us",
    "max_us",
    "active_total_us",
    "active_p50_us",
    "active_p95_us",
    "active_p99_us",
    "active_max_us",
    "quiescent_total_us",
    "quiescent_p50_us",
    "quiescent_p95_us",
    "quiescent_p99_us",
    "quiescent_max_us",
}
WORK_KEYS = {
    "visited",
    "active_block_sum",
    "moved",
    "water_transfers",
    "lateral_probes",
    "lateral_requests",
    "block_wakes",
    "block_sleeps",
    "active_tick_count",
    "quiescent_suffix_tick_count",
}


class EvidenceError(RuntimeError):
    """Evidence validation failed without erasing the attempt record."""


def prepare_output(path: Path) -> Path:
    path = path.resolve()
    if path.exists():
        try:
            next(path.iterdir())
        except StopIteration:
            pass
        else:
            raise EvidenceError(f"refusing non-empty evidence destination: {path}")
    path.mkdir(parents=True, exist_ok=True)
    return path


def _primary_kind(scenario: str) -> str | None:
    if scenario in {
        "communicating-pools",
        "unequal-head-communicating-reservoir-v2",
        "unequal-head-two-limb-v2",
    }:
        return "level_difference_milli"
    if scenario == "calm-settling":
        return "surface_spread_milli"
    return None


def _metric_observation(sample: dict[str, Any], scenario: str) -> int | None:
    kind = _primary_kind(scenario)
    if kind == "level_difference_milli":
        if not sample.get("level_difference_valid", False):
            return None
        value = sample.get(kind)
        return int(value) if value is not None else None
    if kind == "surface_spread_milli":
        if not sample.get("surface_coverage_valid", False):
            return None
        value = sample.get(kind)
        return int(value) if value is not None else None
    return None


def _first_crossing(
    samples: list[dict[str, Any]], scenario: str, predicate
) -> int | None:
    for sample in samples:
        if int(sample.get("tick", 0)) == 0:
            continue
        value = _metric_observation(sample, scenario)
        if value is not None and predicate(value):
            return int(sample["tick"])
    return None


def sustained_suffix_status(
    samples: list[dict[str, Any]],
    scenario: str,
    predicate,
    *,
    required_samples: int = SUSTAINED_SAMPLES,
) -> dict[str, Any]:
    """Return categorical sustained status for the final preregistered window.

    A previous passing streak does not survive a later regression.  Missing/dry
    coverage is categorical, not a numeric zero.
    """
    post_initial = [s for s in samples if int(s.get("tick", 0)) > 0]
    if len(post_initial) < required_samples:
        return {"status": "not_reached", "tick": None}
    final_window = post_initial[-required_samples:]
    values = [_metric_observation(s, scenario) for s in final_window]
    if any(v is None for v in values):
        return {"status": "invalid_coverage", "tick": None}
    if all(predicate(int(v)) for v in values):
        return {"status": "reached", "tick": int(final_window[0]["tick"])}
    return {"status": "not_reached", "tick": None}


def derive_equilibrium(row: dict[str, Any]) -> dict[str, Any]:
    scenario = str(row["scenario"])
    kind = _primary_kind(scenario)
    if kind is None:
        return {
            "primary": None,
            "half_life": {"status": "not_applicable", "tick": None},
            "one_cell": {"status": "not_applicable", "tick": None},
        }

    samples = list(row.get("samples", []))
    if not samples:
        raise EvidenceError("missing samples")
    initial = _metric_observation(samples[0], scenario)
    if initial is None:
        invalid = {"status": "invalid_coverage", "tick": None}
        return {"primary": kind, "initial": None, "half_life": invalid, "one_cell": invalid}

    half_predicate = lambda value: value * 2 <= initial
    one_cell_predicate = lambda value: value <= 1000
    half = sustained_suffix_status(samples, scenario, half_predicate)
    one_cell = sustained_suffix_status(samples, scenario, one_cell_predicate)
    half["first_crossing_tick"] = _first_crossing(samples, scenario, half_predicate)
    one_cell["first_crossing_tick"] = _first_crossing(samples, scenario, one_cell_predicate)
    return {
        "primary": kind,
        "initial": initial,
        "half_life": half,
        "one_cell": one_cell,
    }


def residual_terraces(contour: list[int | None], threshold: int = 750) -> dict[str, int]:
    """Classify discrete shelves after removing the best-fit monotonic slope."""
    points = [(i, int(y)) for i, y in enumerate(contour) if y is not None]
    if len(points) < 2:
        return {"count": 0, "max_step_milli": 0}
    mean_x = sum(x for x, _ in points) / len(points)
    mean_y = sum(y for _, y in points) / len(points)
    denom = sum((x - mean_x) ** 2 for x, _ in points)
    slope = (
        sum((x - mean_x) * (y - mean_y) for x, y in points) / denom
        if denom
        else 0.0
    )
    intercept = mean_y - slope * mean_x
    residual = {x: y - (intercept + slope * x) for x, y in points}
    count = 0
    maximum = 0
    for (x0, _), (x1, _) in zip(points, points[1:]):
        if x1 != x0 + 1:
            continue
        step = int(round(abs(residual[x1] - residual[x0])))
        if step >= threshold:
            count += 1
            maximum = max(maximum, step)
    return {"count": count, "max_step_milli": maximum}


def augment_row(row: dict[str, Any]) -> dict[str, Any]:
    row = dict(row)
    row["equilibrium_v2"] = derive_equilibrium(row)
    communicating_surface = _primary_kind(str(row["scenario"])) == "level_difference_milli"
    for sample in row.get("samples", []):
        if communicating_surface:
            sample["surface_defect_scope_v2"] = "separate_limb_free_surfaces"
            sample["residual_terraces_v2"] = None
            sample["left_residual_terraces_v2"] = residual_terraces(
                list(sample.get("left_surface_contour_milli", []))
            )
            sample["right_residual_terraces_v2"] = residual_terraces(
                list(sample.get("right_surface_contour_milli", []))
            )
        else:
            sample["surface_defect_scope_v2"] = "declared_surface_roi"
            sample["residual_terraces_v2"] = residual_terraces(
                list(sample.get("surface_contour_milli", []))
            )
        sample["wall_contact_expected"] = (
            row["scenario"] == "fast-dump"
            and int(sample.get("wall_contact_probe_rows", 0)) > 0
        )
    row["surface_sampling_contract"] = {
        "period_ticks": SAMPLE_PERIOD,
        "high_frequency_shimmer_claimed": False,
        "historical_hill_terrace_contact_metrics": "sampled_proxies",
    }
    return row


def validate_row(
    row: dict[str, Any],
    *,
    scenario: str,
    shift: int,
    workers: int,
    mirror: int,
) -> None:
    required = {
        "scenario": scenario,
        "shift": shift,
        "workers": workers,
        "mirror": mirror,
        "apparatus_schema": APPARATUS_SCHEMA,
        "fixture_schema": FIXTURE_SCHEMA,
        "metric_schema": METRIC_SCHEMA,
    }
    for field, expected in required.items():
        if row.get(field) != expected:
            raise EvidenceError(
                f"{field}: expected {expected!r}, observed {row.get(field)!r}"
            )
    if not row.get("mass_conserved", False):
        raise EvidenceError("closed Water mass was not conserved")
    if row.get("initial_mass") != row.get("final_mass"):
        raise EvidenceError("initial/final Water mass mismatch")
    if int(row.get("allocations", -1)) != 0:
        raise EvidenceError("post-setup allocation count was nonzero")
    samples = row.get("samples")
    if not isinstance(samples, list) or not samples:
        raise EvidenceError("missing native samples")
    for sample in samples:
        total = int(sample.get("surface_total_columns", -1))
        wet = int(sample.get("surface_wet_columns", -1))
        if total <= 0 or wet < 0 or wet > total:
            raise EvidenceError("invalid surface coverage accounting")
        contour = sample.get("surface_contour_milli")
        if not isinstance(contour, list) or len(contour) != total:
            raise EvidenceError("surface contour length does not match ROI")


def parity_projection(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "scenario": row["scenario"],
        "shift": row["shift"],
        "mirror": row["mirror"],
        "horizon": row["horizon"],
        "maximum_mass": row["maximum_mass"],
        "initial_mass": row["initial_mass"],
        "final_mass": row["final_mass"],
        "mass_conserved": row["mass_conserved"],
        "common_level_target_milli": row.get("common_level_target_milli"),
        "samples": row["samples"],
        **{key: row.get(key) for key in WORK_KEYS},
    }


def _write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True), encoding="utf-8")


def execute_attempt(
    command: list[str],
    *,
    timeout_seconds: int,
    cwd: Path,
    stdout_path: Path,
    execution_path: Path,
    metadata: dict[str, Any],
) -> tuple[str, dict[str, Any] | None, dict[str, Any]]:
    started = time.monotonic()
    record = dict(metadata)
    record.update({"command": command, "timeout_seconds": timeout_seconds})
    try:
        completed = subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )
        stdout_path.write_text(completed.stdout, encoding="utf-8")
        record["seconds"] = time.monotonic() - started
        record["exit"] = completed.returncode
        record["stderr"] = completed.stderr
        if completed.returncode != 0:
            record["disposition"] = "nonzero_exit"
            _write_json(execution_path, record)
            return "nonzero_exit", None, record
        try:
            row = json.loads(completed.stdout)
        except json.JSONDecodeError as error:
            record["disposition"] = "malformed_output"
            record["error"] = str(error)
            _write_json(execution_path, record)
            return "malformed_output", None, record
        record["disposition"] = "executed"
        _write_json(execution_path, record)
        return "executed", row, record
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        stdout_path.write_text(stdout, encoding="utf-8")
        record["seconds"] = time.monotonic() - started
        record["exit"] = None
        record["stderr"] = (
            error.stderr.decode("utf-8", errors="replace")
            if isinstance(error.stderr, bytes)
            else (error.stderr or "")
        )
        record["disposition"] = "timeout"
        _write_json(execution_path, record)
        return "timeout", None, record


def _status_counts(values: Iterable[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for value in values:
        key = str(value.get("status"))
        counts[key] = counts.get(key, 0) + 1
    return counts


def reached_median(values: Iterable[dict[str, Any]]) -> dict[str, Any]:
    values = list(values)
    ticks = [
        int(value["tick"])
        for value in values
        if value.get("status") == "reached" and value.get("tick") is not None
    ]
    return {
        "reached_tick_median": float(statistics.median(ticks)) if ticks else None,
        "status_counts": _status_counts(values),
    }


def summarize(results: list[dict[str, Any]]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for scenario in SCENARIOS:
        rows = [
            row
            for row in results
            if row["scenario"] == scenario and int(row["workers"]) == 1
        ]
        half = [row["equilibrium_v2"]["half_life"] for row in rows]
        one_cell = [row["equilibrium_v2"]["one_cell"] for row in rows]
        summary[scenario] = {
            "cases": len(rows),
            "half_life": reached_median(half),
            "one_cell": reached_median(one_cell),
            "initial_mass_median": (
                float(statistics.median([int(row["initial_mass"]) for row in rows]))
                if rows
                else None
            ),
            "active_p95_us_median": (
                float(statistics.median([float(row["active_p95_us"]) for row in rows]))
                if rows
                else None
            ),
            "quiescent_p95_us_median": (
                float(statistics.median([
                    float(row["quiescent_p95_us"])
                    for row in rows
                    if row.get("quiescent_p95_us") is not None
                ]))
                if any(row.get("quiescent_p95_us") is not None for row in rows)
                else None
            ),
            "quiescent_sampled_cases": sum(
                row.get("quiescent_p95_us") is not None for row in rows
            ),
            "total_us_median": (
                float(statistics.median([float(row["total_us"]) for row in rows]))
                if rows
                else None
            ),
            "mass_conserved_cases": sum(bool(row.get("mass_conserved")) for row in rows),
            "zero_allocation_cases": sum(int(row.get("allocations", -1)) == 0 for row in rows),
        }
    return summary


def registered_cases() -> list[dict[str, Any]]:
    return [
        {
            "scenario": scenario,
            "shift": shift,
            "mirror": mirror,
            "workers": workers,
            "case": f"{scenario}-s{shift}-m{mirror}-t{workers}",
        }
        for scenario in SCENARIOS
        for shift in SHIFTS
        for mirror in MIRRORS
        for workers in WORKERS
    ]


def build_executable(output: Path, cxx: str) -> tuple[Path, dict[str, Any]]:
    exe_name = "water_issue49.exe" if os.name == "nt" else "water_issue49"
    exe = (output / exe_name).resolve()
    command = [
        cxx,
        "-std=c++20",
        "-O3",
        "-DNDEBUG",
        "-pthread",
        "-Inative/include",
        "native/src/world.cpp",
        "native/src/material_rules.cpp",
        "native/src/scheduler_geometry.cpp",
        "native/src/settled_world_discovery.cpp",
        "native/src/render_snapshot.cpp",
        "native/bench/water_issue49.cpp",
        "-o",
        str(exe),
    ]
    started = time.monotonic()
    try:
        built = subprocess.run(
            command,
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=300,
        )
        record = {
            "command": command,
            "seconds": time.monotonic() - started,
            "exit": built.returncode,
            "stdout": built.stdout,
            "stderr": built.stderr,
            "timeout_seconds": 300,
            "disposition": "success" if built.returncode == 0 else "nonzero_exit",
        }
    except subprocess.TimeoutExpired as error:
        record = {
            "command": command,
            "seconds": time.monotonic() - started,
            "exit": None,
            "stdout": "",
            "stderr": str(error),
            "timeout_seconds": 300,
            "disposition": "timeout",
        }
    _write_json(output / "build.execution.json", record)
    return exe, record


def run_campaign(output: Path, cxx: str) -> int:
    output = prepare_output(output)
    cases = registered_cases()
    _write_json(
        output / "registration.json",
        {
            "runner_schema": RUNNER_SCHEMA,
            "apparatus_schema": APPARATUS_SCHEMA,
            "fixture_schema": FIXTURE_SCHEMA,
            "metric_schema": METRIC_SCHEMA,
            "sample_period": SAMPLE_PERIOD,
            "sustained_samples": SUSTAINED_SAMPLES,
            "scenarios": SCENARIOS,
            "shifts": SHIFTS,
            "mirrors": MIRRORS,
            "workers": WORKERS,
            "case_count": len(cases),
        },
    )

    exe, build = build_executable(output, cxx)
    attempts: list[dict[str, Any]] = []
    results: list[dict[str, Any]] = []
    controls: dict[tuple[str, int, int], dict[str, Any]] = {}

    if build["disposition"] != "success":
        for case in cases:
            attempts.append(
                {
                    **case,
                    "disposition": "build_failure",
                    "reason": build["disposition"],
                }
            )
    else:
        _write_json(
            output / "manifest.json",
            {
                **identity([exe]),
                "runner_schema": RUNNER_SCHEMA,
                "apparatus_schema": APPARATUS_SCHEMA,
                "fixture_schema": FIXTURE_SCHEMA,
                "metric_schema": METRIC_SCHEMA,
                "platform_detail": platform.platform(),
            },
        )
        for case in cases:
            key = case["case"]
            command = [
                str(exe),
                case["scenario"],
                str(case["shift"]),
                str(case["workers"]),
                str(case["mirror"]),
            ]
            disposition, raw, record = execute_attempt(
                command,
                timeout_seconds=240,
                cwd=ROOT,
                stdout_path=output / f"{key}.stdout.json",
                execution_path=output / f"{key}.execution.json",
                metadata=case,
            )
            if disposition != "executed" or raw is None:
                attempts.append({**case, "disposition": disposition})
                continue
            try:
                validate_row(
                    raw,
                    scenario=case["scenario"],
                    shift=case["shift"],
                    workers=case["workers"],
                    mirror=case["mirror"],
                )
                row = augment_row(raw)
                parity_key = (case["scenario"], case["shift"], case["mirror"])
                if case["workers"] == 1:
                    controls[parity_key] = row
                else:
                    control = controls.get(parity_key)
                    if control is None:
                        raise EvidenceError("missing successful 1-worker parity control")
                    if parity_projection(row) != parity_projection(control):
                        raise EvidenceError("1-worker/4-worker authoritative parity mismatch")
                results.append(row)
                record["disposition"] = "success"
                _write_json(output / f"{key}.execution.json", record)
                attempts.append({**case, "disposition": "success"})
            except (EvidenceError, KeyError, TypeError, ValueError) as error:
                record["disposition"] = "validation_error"
                record["error"] = str(error)
                _write_json(output / f"{key}.execution.json", record)
                attempts.append(
                    {**case, "disposition": "validation_error", "error": str(error)}
                )

    _write_json(output / "results.json", results)
    _write_json(output / "summary.json", summarize(results))
    dispositions: dict[str, int] = {}
    for attempt in attempts:
        name = str(attempt["disposition"])
        dispositions[name] = dispositions.get(name, 0) + 1
    complete = len(attempts) == len(cases)
    completion = {
        "runner_schema": RUNNER_SCHEMA,
        "registered_case_count": len(cases),
        "accounted_case_count": len(attempts),
        "complete_accounting": complete,
        "all_cases_successful": complete and dispositions == {"success": len(cases)},
        "dispositions": dispositions,
        "attempts": attempts,
    }
    if complete:
        _write_json(output / "completion-manifest.json", completion)
    if not completion["all_cases_successful"]:
        return 2
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--cxx", default=os.environ.get("CXX", "g++"))
    args = parser.parse_args()
    try:
        return run_campaign(args.output, args.cxx)
    except EvidenceError as error:
        print(f"water_issue49: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
