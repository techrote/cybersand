"""Reduce the tank/blob CSV section of one wave_waterwall run."""
import argparse
import csv
import io
import json
import math
from pathlib import Path
import statistics


def measure(path):
    lines = path.read_text().splitlines()
    rows = list(csv.DictReader(io.StringIO("\n".join(
        line for line in lines if line.startswith("tick,") or line[:1].isdigit()))))
    if not rows or any(int(row["total_drift"]) != 0 for row in rows):
        raise ValueError(f"missing samples or unclosed Water quantity in {path}")
    if not any(line.startswith("overall_median_us=") for line in lines):
        raise ValueError(f"incomplete apparatus output in {path}")
    scene = lines[0].split()[0].split("=")[1]
    if scene == "blob":
        return {"scene": scene, "front_right_x": {
            int(row["tick"]): int(row["front_right_32"])
            for row in rows if int(row["tick"]) in (0, 20, 40, 80, 120, 160)}}
    if scene not in ("tank", "tank_open"):
        raise ValueError(f"expected tank, tank_open or blob in {path}")
    # A full swing goes from an extremum to the next of the same sign.
    # One maximum per signed excursion suppresses quantisation chatter.
    # A final excursion which never returned to the noise floor may still
    # be rising at the end of the recording.
    peaks = []
    curvatures = []
    for row in rows:
        tick = int(row["tick"])
        amplitude = float(row["long_mode_cells"])
        if 20 <= tick <= 300:
            curvatures.append(float(row["curvature_rms_cells"]))
        if abs(amplitude) < 0.04:
            continue
        if not peaks or math.copysign(1, peaks[-1][1]) != math.copysign(1, amplitude):
            peaks.append((tick, amplitude))
        elif abs(peaks[-1][1]) < abs(amplitude):
            peaks[-1] = (tick, amplitude)
    if abs(float(rows[-1]["long_mode_cells"])) >= 0.04:
        peaks = peaks[:-1]
    # Use successive positive extrema inclusive of the initial displacement.
    # All three comparison arms resolve two full periods over this fixture.
    primary = peaks[::2][:3]
    periods = [b[0] - a[0] for a, b in zip(primary, primary[1:])]
    return {"scene": scene, "positive_extrema_tick_cells": primary,
            "period_ticks": statistics.mean(periods) if periods else None,
            "amplitude_retained_per_period": (primary[-1][1] / primary[0][1]) ** (1 / len(periods)) if periods else None,
            "mean_curvature_rms_cells_t20_300": statistics.mean(curvatures) if curvatures else None}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", nargs="+", type=Path)
    args = parser.parse_args()
    print(json.dumps({p.name: measure(p) for p in args.logs}, indent=2))
