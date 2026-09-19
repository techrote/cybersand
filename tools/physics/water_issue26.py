"""Run the preregistered issue #26 Water baseline/candidate characterization matrix."""
from __future__ import annotations

import argparse
import json
import os
import platform
import statistics
import subprocess
from pathlib import Path

from run import ROOT, identity

SCENARIOS = [
    "head-shallow",
    "head-medium",
    "head-deep",
    "communicating-pools",
    "unequal-head-u-tube",
    "constriction",
    "fast-dump",
    "calm-settling",
    "ledge-sheet",
]
SHIFTS = [-65, 0, 63]
MIRRORS = [0, 1]
WORKERS = [1, 4]

p = argparse.ArgumentParser()
p.add_argument("output", type=Path)
p.add_argument("--cxx", default=os.environ.get("CXX", "g++"))
p.add_argument("--mode", choices=["baseline", "head"], default="baseline")
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)

exe_name = "water_issue26.exe" if os.name == "nt" else "water_issue26"
exe = (a.output / exe_name).resolve()
cmd = [
    a.cxx,
    "-std=c++20",
    "-O3",
    "-DNDEBUG",
    "-pthread",
    "-Inative/include",
    "native/src/world.cpp",
    "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp",
    "native/src/render_snapshot.cpp",
    "native/bench/water_issue26.cpp",
    "-o",
    str(exe),
]
built = subprocess.run(
    cmd,
    cwd=ROOT,
    capture_output=True,
    text=True,
    timeout=300,
)
(a.output / "build.log").write_text(
    json.dumps(cmd) + "\n" + built.stdout + built.stderr,
    encoding="utf-8",
)
if built.returncode != 0:
    print((a.output / "build.log").read_text(encoding="utf-8"), flush=True)
    built.check_returncode()

(a.output / "manifest.json").write_text(
    json.dumps(identity([exe]), indent=2), encoding="utf-8"
)

results: list[dict] = []
controls: dict[tuple[str, int, int], dict] = {}

TIMING_KEYS = {"total_us", "p50_us", "p95_us", "p99_us", "max_us"}
WORK_KEYS = {
    "visited",
    "active_block_sum",
    "moved",
    "water_transfers",
    "lateral_probes",
    "lateral_requests",
    "block_wakes",
    "block_sleeps",
}

for scenario in SCENARIOS:
    for shift in SHIFTS:
        for mirror in MIRRORS:
            for workers in WORKERS:
                key = f"{scenario}-s{shift}-m{mirror}-t{workers}"
                run_cmd = [str(exe), scenario, str(shift), str(workers), str(mirror), a.mode]
                completed = subprocess.run(
                    run_cmd,
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    timeout=240,
                )
                (a.output / f"{key}.stdout.json").write_text(
                    completed.stdout, encoding="utf-8"
                )
                (a.output / f"{key}.execution.json").write_text(
                    json.dumps(
                        {
                            "command": run_cmd,
                            "exit": completed.returncode,
                            "stderr": completed.stderr,
                            "timeout_seconds": 240,
                        },
                        indent=2,
                    ),
                    encoding="utf-8",
                )
                completed.check_returncode()
                row = json.loads(completed.stdout)
                assert row["scenario"] == scenario
                assert row["mode"] == a.mode
                assert row["workers"] == workers
                assert row["shift"] == shift
                assert row["mirror"] == mirror
                assert row["mass_conserved"]
                assert row["initial_mass"] == row["final_mass"]
                assert row["allocations"] == 0

                parity_key = (scenario, shift, mirror)
                if workers == 1:
                    controls[parity_key] = row
                else:
                    control = controls[parity_key]
                    # Authoritative snapshots must be exact across expected worker counts.
                    assert row["samples"] == control["samples"], parity_key
                    # Deterministic work/counter totals must also match. Timings are host noise.
                    for field in WORK_KEYS:
                        assert row[field] == control[field], (parity_key, field)

                results.append(row)
                print(
                    key,
                    "mass",
                    row["initial_mass"],
                    "half",
                    row["sustained_half_life_tick"],
                    "flat",
                    row["sustained_one_cell_tick"],
                    "recv300",
                    row["receive_mass_tick300"],
                    flush=True,
                )

(a.output / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")


def median_int(values: list[int | float]) -> float:
    return float(statistics.median(values)) if values else 0.0


summary: dict[str, dict] = {}
for scenario in SCENARIOS:
    rows = [r for r in results if r["scenario"] == scenario and r["workers"] == 1]
    final_samples = [r["samples"][-1] for r in rows]
    summary[scenario] = {
        "cases": len(rows),
        "initial_mass_median": median_int([r["initial_mass"] for r in rows]),
        "receive_mass_tick120_median": median_int(
            [r["receive_mass_tick120"] for r in rows]
        ),
        "receive_mass_tick300_median": median_int(
            [r["receive_mass_tick300"] for r in rows]
        ),
        "sustained_half_life_tick_median": median_int(
            [r["sustained_half_life_tick"] for r in rows]
        ),
        "sustained_one_cell_tick_median": median_int(
            [r["sustained_one_cell_tick"] for r in rows]
        ),
        "final_level_difference_milli_median": median_int(
            [s["level_difference_milli"] for s in final_samples]
        ),
        "final_surface_spread_milli_median": median_int(
            [s["surface_spread_milli"] for s in final_samples]
        ),
        "max_hill_milli_median": median_int([r["max_hill_milli"] for r in rows]),
        "max_terraces_median": median_int([r["max_terraces"] for r in rows]),
        "max_wall_gap_cells_median": median_int(
            [r["max_wall_gap_cells"] for r in rows]
        ),
        "surface_turnover_samples_median": median_int(
            [r["surface_turnover_samples"] for r in rows]
        ),
        "visited_median": median_int([r["visited"] for r in rows]),
        "p95_us_median": median_int([r["p95_us"] for r in rows]),
        "total_us_median": median_int([r["total_us"] for r in rows]),
    }

summary["_run"] = {
    "platform": platform.platform(),
    "mode": a.mode,
    "scenario_count": len(SCENARIOS),
    "case_count": len(results),
    "authoritative_worker_parity": True,
    "mass_conservation": True,
    "post_setup_allocations_zero": True,
}
(a.output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

print("ISSUE26_SUMMARY " + json.dumps(summary, sort_keys=True))
print(f"{len(results)} issue #26 cases passed conservation and worker-parity checks")
