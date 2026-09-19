#!/usr/bin/env python3
"""Run the source-frozen Issue #26 baseline campaign and retain every attempt."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from reduce import summarize

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ("r8", "r24", "r40", "cp16", "ut96_48", "cn", "fd", "cs", "ls")
EXTENDABLE = {"cp16", "ut96_48", "cs"}
PLACEMENTS = (
    ("P0", 0, 0, 0),
    ("P1", -129, 0, 0),
    ("P2", 127, 1, 1),
    ("P3", -257, 1, 1),
    ("P4", 65, 0, 0),
)
SEMANTIC_KEYS = (
    "tick", "quantity", "content", "occupied", "partial", "com_x_num",
    "min_wet_x", "max_wet_x", "downstream", "left", "right",
    "wall_gap", "wall_gap_max_run", "components", "small_components",
)


def digest(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def execute(name: str, cmd: list[str], out: Path, timeout: int) -> Path:
    stdout = out / "raw" / f"{name}.jsonl"
    meta_path = out / "executions" / f"{name}.json"
    stdout.parent.mkdir(parents=True, exist_ok=True)
    meta_path.parent.mkdir(parents=True, exist_ok=True)
    if stdout.exists() or meta_path.exists():
        raise RuntimeError(f"refuse overwrite: {name}")
    meta = {
        "name": name,
        "command": cmd,
        "cwd": str(ROOT),
        "timeout_seconds": timeout,
        "started_unix": time.time(),
    }
    exit_code = None
    error = None
    with stdout.open("w", encoding="utf-8") as handle:
        try:
            proc = subprocess.run(
                cmd, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT,
                timeout=timeout, check=False, text=True,
            )
            exit_code = proc.returncode
        except subprocess.TimeoutExpired:
            exit_code = 124
            error = "timeout"
    meta["finished_unix"] = time.time()
    meta["seconds"] = meta["finished_unix"] - meta["started_unix"]
    meta["exit"] = exit_code
    meta["error"] = error
    meta["stdout_sha256"] = digest(stdout)
    meta["stdout_bytes"] = stdout.stat().st_size
    write_json(meta_path, meta)
    if exit_code != 0:
        raise RuntimeError(f"{name} failed with exit {exit_code}; evidence retained")
    return stdout


def rows(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def tick_semantics(path: Path) -> list[dict]:
    result = []
    for row in rows(path):
        if "tick" not in row:
            continue
        result.append({key: row.get(key) for key in SEMANTIC_KEYS if key in row})
    return result


def final_row(path: Path) -> dict:
    data = rows(path)
    if not data or not data[-1].get("result"):
        raise RuntimeError(f"{path}: no result row")
    return data[-1]


def command(exe: Path, fixture: str, sx: int, sy: int, mirror: int,
            workers: int, observer: int, horizon: int, mode: str) -> list[str]:
    return [
        str(exe), fixture, str(sx), str(sy), str(mirror),
        str(workers), str(observer), str(horizon), mode,
    ]


def compiler_identity(exe: Path) -> dict:
    cxx = os.environ.get("CXX", "g++")
    try:
        version = subprocess.check_output([cxx, "--version"], text=True).splitlines()[0]
    except (OSError, subprocess.CalledProcessError):
        version = "unavailable"
    return {
        "cxx": cxx,
        "version": version,
        "executable": str(exe),
        "executable_sha256": digest(exe),
    }


def source_identity(exe: Path) -> dict:
    tracked = [
        ROOT / "docs/operations/water-leveling-experiment.md",
        ROOT / "native/bench/water_leveling_characterisation.cpp",
        ROOT / "tools/water_leveling/reduce.py",
        Path(__file__),
    ]
    return {
        "head": git("rev-parse", "HEAD"),
        "tree": git("rev-parse", "HEAD^{tree}"),
        "status": git("status", "--short"),
        "files": {str(path.relative_to(ROOT)): digest(path) for path in tracked},
        "compiler": compiler_identity(exe),
    }


def run_trace(exe: Path, fixture: str, horizon: int, out: Path) -> tuple[Path, dict]:
    name = f"trace-{fixture}-{horizon}"
    path = execute(name, command(exe, fixture, 0, 0, 0, 1, 1, horizon, "trace"), out, 600)
    summary = summarize(path)
    summary_path = out / "reduced" / f"{name}.json"
    write_json(summary_path, summary)
    return path, summary


def needs_extension(fixture: str, summary: dict) -> bool:
    if fixture == "cs":
        return bool(summary["censored"]["time_to_flat"] or summary["censored"]["primary_local_slope_half_life"])
    if fixture in {"cp16", "ut96_48"}:
        return bool(summary["censored"]["arm_level_half_life"] or summary["censored"]["time_to_flat"])
    return False


def verify_determinism(exe: Path, out: Path) -> dict:
    records = []
    for fixture in FIXTURES:
        for placement, sx, sy, mirror in PLACEMENTS:
            reference = None
            reference_name = None
            for workers in (1, 4):
                for repeat in (0, 1):
                    name = f"verify-{fixture}-{placement}-w{workers}-r{repeat}"
                    path = execute(
                        name, command(exe, fixture, sx, sy, mirror, workers, 0, 1800, "verify"),
                        out, 300,
                    )
                    semantic = tick_semantics(path)
                    if reference is None:
                        reference = semantic
                        reference_name = name
                    elif semantic != reference:
                        raise RuntimeError(
                            f"determinism/worker mismatch {name} versus {reference_name}"
                        )
                    records.append({
                        "name": name,
                        "fixture": fixture,
                        "placement": placement,
                        "workers": workers,
                        "repeat": repeat,
                        "stdout_sha256": digest(path),
                        "final_content": final_row(path)["content"],
                    })
        print(f"verified repeat/worker parity: {fixture}", flush=True)
    return {"status": "passed", "runs": records}


def verify_observer_neutrality(exe: Path, out: Path) -> dict:
    records = []
    for fixture in FIXTURES:
        paths = {}
        for observer in (0, 1):
            name = f"observer-{fixture}-{observer}"
            paths[observer] = execute(
                name, command(exe, fixture, 0, 0, 0, 1, observer, 1800, "verify"),
                out, 300,
            )
        if tick_semantics(paths[0]) != tick_semantics(paths[1]):
            raise RuntimeError(f"observer changed authoritative behavior: {fixture}")
        records.append({
            "fixture": fixture,
            "off_sha256": digest(paths[0]),
            "on_sha256": digest(paths[1]),
            "final_content": final_row(paths[0])["content"],
        })
        print(f"verified observer neutrality: {fixture}", flush=True)
    return {"status": "passed", "runs": records}


def baseline_timing(exe: Path, out: Path) -> dict:
    records = []
    for fixture in FIXTURES:
        for workers in (1, 4):
            verify_name = f"timing-control-{fixture}-w{workers}"
            control = execute(
                verify_name, command(exe, fixture, 0, 0, 0, workers, 0, 1920, "verify"),
                out, 300,
            )
            timing_name = f"timing-{fixture}-w{workers}"
            timed = execute(
                timing_name, command(exe, fixture, 0, 0, 0, workers, 0, 1920, "timing"),
                out, 300,
            )
            cfinal, tfinal = final_row(control), final_row(timed)
            if cfinal["quantity"] != tfinal["quantity"] or cfinal["content"] != tfinal["content"]:
                raise RuntimeError(f"timing changed semantics: {fixture} worker {workers}")
            records.append({
                "fixture": fixture,
                "workers": workers,
                "control_sha256": digest(control),
                "timing_sha256": digest(timed),
                "quantity": tfinal["quantity"],
                "content": tfinal["content"],
                "total_us": tfinal["total_us"],
                "p50_us": tfinal["p50_us"],
                "p95_us": tfinal["p95_us"],
                "p99_us": tfinal["p99_us"],
                "max_us": tfinal["max_us"],
            })
        print(f"timed baseline: {fixture}", flush=True)
    return {"status": "passed", "warmup_ticks": 120, "steady_ticks": 1800, "runs": records}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    exe = args.exe.resolve()
    out = args.output.resolve()
    if not exe.is_file():
        raise SystemExit(f"missing executable: {exe}")
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f"refuse non-empty output: {out}")
    out.mkdir(parents=True, exist_ok=True)

    identity = source_identity(exe)
    write_json(out / "source.json", identity)

    canonical = {}
    for fixture in FIXTURES:
        trace_path, summary = run_trace(exe, fixture, 1800, out)
        attempts = [{"horizon": 1800, "trace": str(trace_path.relative_to(out)), "summary": summary}]
        if fixture in EXTENDABLE and needs_extension(fixture, summary):
            trace_path, summary = run_trace(exe, fixture, 7200, out)
            attempts.append({"horizon": 7200, "trace": str(trace_path.relative_to(out)), "summary": summary})
        canonical[fixture] = {
            "attempts": attempts,
            "selected_horizon": attempts[-1]["horizon"],
            "summary": summary,
        }
        print(
            f"trace {fixture}: horizon={attempts[-1]['horizon']} "
            f"flat={summary['time_to_flat_tick']} "
            f"arm_half={summary['arm_level_half_life_tick']} "
            f"local_half={summary['primary_local_slope_half_life_tick']} "
            f"surface_start={summary['registered_surface_start_tick']} "
            f"registered_hill={summary['registered_surface_max_hill_amplitude_cells']}",
            flush=True,
        )
    write_json(out / "canonical.json", canonical)

    deterministic = verify_determinism(exe, out)
    write_json(out / "determinism.json", deterministic)

    observer = verify_observer_neutrality(exe, out)
    write_json(out / "observer-neutrality.json", observer)

    timing = baseline_timing(exe, out)
    write_json(out / "timing.json", timing)

    result = {
        "schema": "cybersand-water-leveling-baseline-v2",
        "status": "passed",
        "source": identity,
        "canonical": canonical,
        "determinism": {"status": deterministic["status"], "run_count": len(deterministic["runs"])},
        "observer_neutrality": {"status": observer["status"], "run_count": len(observer["runs"])},
        "timing": timing,
        "limitations": [
            "Native authoritative baseline only; fixed-presentation rendered metrics are a later issue-26 gate.",
            "Hosted-runner timing is retained as platform-specific baseline context, not a desktop performance attestation.",
            "Human H acceptance is not established by this campaign.",
        ],
    }
    write_json(out / "baseline-summary.json", result)
    print(json.dumps({
        "status": result["status"],
        "head": identity["head"],
        "canonical": {
            fixture: {
                "horizon": data["selected_horizon"],
                "time_to_flat_tick": data["summary"]["time_to_flat_tick"],
                "arm_level_half_life_tick": data["summary"]["arm_level_half_life_tick"],
                "primary_local_slope_half_life_tick": data["summary"]["primary_local_slope_half_life_tick"],
                "max_hill_amplitude_cells": data["summary"]["max_hill_amplitude_cells"],
                "severe_terrace_lifetime_ticks": data["summary"]["severe_terrace_lifetime_ticks"],
                "registered_surface_start_tick": data["summary"]["registered_surface_start_tick"],
                "registered_surface_max_hill_amplitude_cells": data["summary"]["registered_surface_max_hill_amplitude_cells"],
                "registered_surface_severe_terrace_lifetime_ticks": data["summary"]["registered_surface_severe_terrace_lifetime_ticks"],
                "registered_surface_turnover_per_motion_cell_equivalent": data["summary"]["registered_surface_turnover_per_motion_cell_equivalent"],
                "registered_surface_low_motion_edge_turnover": data["summary"]["registered_surface_low_motion_edge_turnover"],
                "registered_surface_low_motion_transition_count": data["summary"]["registered_surface_low_motion_transition_count"],
                "max_wall_gap_area_cells": data["summary"]["max_wall_gap_area_cells"],
            }
            for fixture, data in canonical.items()
        },
        "determinism_runs": len(deterministic["runs"]),
        "observer_runs": len(observer["runs"]),
        "timing_runs": len(timing["runs"]),
    }, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
