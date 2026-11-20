"""Compare returning waves and a dropped blob with spill and release enabled.

The bench samples real native state, outside the timed tick. Output preserves
signed long-mode traces and transverse column heights at matched wave phases.
Run from a source checkout, with a freshly built make wave-waterwall binary.
"""
import argparse
import csv
import hashlib
import json
import statistics
import subprocess
from pathlib import Path

MAX_SPILL = dict(spill=1, ballistic=1, sheet_rate=64, draw=127, draw_head=65535,
                 fall=8, launch_budget=128, coyote_ticks=4, catch=1)
SLOSHY = dict(gain=32, deep_gain=16, flux_smoothing=16, coast=64, damp_shift=16,
              level_shift=3, calm_damp_shift=8, calm=128, stick=128, sleep_after=90)
HIGH_GAIN = dict(gain=256, deep_gain=48, flux_smoothing=12, coast=127, empty_pour_shift=1)
FLOOR = dict(floor_gain=1024, deep_gain=32, coast=32, empty_pour_shift=2, substeps=2)
TRACE = ("long_mode_cells", "broad_range_cells", "broad_slope_cells_per_cell", "curvature_rms_cells")
DEPTHS = {"standard": (11, 6), "deep": (22, 10), "full_band": (30, 6)}
EVERY = 2


def run(binary, scene, ticks, workers, options, probes=()):
    cmd = [str(binary), scene, "size=128", f"ticks={ticks}", f"every={EVERY}", f"workers={workers}",
           *(f"{k}={v}" for k, v in options.items()), *probes]
    text = subprocess.run(cmd, capture_output=True, text=True, timeout=180, check=True).stdout
    samples = (line for line in text.splitlines() if line.startswith("tick,") or line[:1].isdigit())
    records = list(csv.DictReader(samples))
    if not records or int(records[-1]["tick"]) != ticks or any(int(r["total_drift"]) for r in records):
        raise ValueError(f"partial run or mass drift: {cmd}")
    return records, text.strip().rsplit(" hash=", 1)[1]


def crests(records):
    """Find one extremum per signed half-wave; reject incomplete terminal swings."""
    peaks = []
    for i, row in enumerate(records):
        amplitude = float(row["long_mode_cells"])
        if abs(amplitude) < 0.04:
            continue
        if not peaks or float(records[peaks[-1]]["long_mode_cells"]) * amplitude < 0:
            peaks.append(i)
        elif abs(amplitude) > abs(float(records[peaks[-1]]["long_mode_cells"])):
            peaks[-1] = i
    if abs(float(records[-1]["long_mode_cells"])) >= 0.04:
        peaks = peaks[:-1]
    return peaks


def tank(binary, workers, name, fixture, settings, traces, shapes):
    depth, step = DEPTHS[fixture]
    probes = [f"probe{x}={17 + x},0,1,56" for x in range(64)]
    probes.append("probe64=17,0,64,56")
    options = dict(settings, tank_depth=depth, tank_step=step, tank_shape=1)
    rows, state = run(binary, "tank", 1600, workers, options, probes)
    peaks = crests(rows)
    for r in rows[::4]:
        traces.writerow([name, fixture, r["tick"], *[r[k] for k in TRACE], r["probe64"]])
    peak_curvature = max(float(r["curvature_rms_cells"]) for r in rows)
    result = {"end_hash": state, "initial_depth_step": [depth, step],
              "max_curvature_cells": peak_curvature,
              "min_retained_grid_cells": min(float(r["probe64"]) for r in rows)}
    if len(peaks) >= 5:
        first_return, second_return = peaks[2], peaks[4]
        t = int(rows[first_return]["tick"])
        result.update(first_return_tick=t, second_return_tick=int(rows[second_return]["tick"]),
                      first_return={k: float(rows[first_return][k]) for k in TRACE},
                      second_return_mode_cells=float(rows[second_return]["long_mode_cells"]),
                      curvature_between_returns=statistics.mean(
                          float(r["curvature_rms_cells"]) for r in rows[first_return:second_return + 1]))
        # Compare physical columns at the same phase, even when periods differ.
        for phase, i in (("initial", 0), ("first_reversal", peaks[1]), ("first_return", first_return),
                         ("second_return", second_return)):
            shapes.writerow([name, fixture, phase, rows[i]["tick"],
                             *[rows[i][f"probe{x}"] for x in range(64)]])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--workers", type=int, default=6)
    args = parser.parse_args()
    binary = args.binary.resolve(strict=True)
    args.output.mkdir(exist_ok=True, parents=True)
    sloshy = {**MAX_SPILL, **SLOSHY}
    high_gain = {**sloshy, **HIGH_GAIN}
    floor = {**sloshy, **FLOOR}
    profiles = {"floor_255": {**floor, "draw_head": 255}, "floor_512": {**floor, "draw_head": 512},
                "sloshy": sloshy, "sloshy_two_rounds": {**sloshy, "substeps": 2},
                "wave_spill": MAX_SPILL, "high_gain": high_gain,
                "high_gain_two_rounds": {**high_gain, "substeps": 2},
                "less_smoothing": {**high_gain, "flux_smoothing": 4},
                "high_deep_gain": {**high_gain, "deep_gain": 96, "flux_smoothing": 16}}
    report = {"binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(), "workers": args.workers,
              "sample_every_ticks": EVERY, "profiles": {}}
    with (
        (args.output / "tank-traces.csv").open("w", newline="") as trace_file,
        (args.output / "tank-profiles.csv").open("w", newline="") as shape_file,
    ):
        traces = csv.writer(trace_file, lineterminator="\n")
        shapes = csv.writer(shape_file, lineterminator="\n")
        traces.writerow(["settings", "fixture", "tick", *TRACE, "tank_grid_cells"])
        shapes.writerow(["settings", "fixture", "phase", "tick", *(f"x{x}" for x in range(17, 81))])
        for name, settings in profiles.items():
            stats = {fixture: tank(binary, args.workers, name, fixture, settings, traces, shapes) for fixture in DEPTHS}
            rows, state = run(binary, "blob", 200, args.workers, settings)
            stats["blob"] = {
                "end_hash": state,
                "front_x": {r["tick"]: int(r["front_right_32"]) for r in rows},
                "first_x100_tick": next((int(r["tick"]) for r in rows if int(r["front_right_32"]) >= 100), None),
            }
            report["profiles"][name] = {"settings": settings, **stats}
            print(name, {fixture: stats[fixture].get("first_return_tick") for fixture in DEPTHS},
                  "blob x100", stats["blob"]["first_x100_tick"], flush=True)
    (args.output / "tank-results.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
