"""Repeat both visible-gap joins from retained DXGI and occupied-cell data."""
from __future__ import annotations

import csv
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent


def read(name):
    return json.loads((HERE / name).read_bytes())


def transform(body, point, native=False):
    x, y, angle = body[6:9] if native else body[2:5]
    c, s = math.cos(angle), math.sin(angle)
    return (x + c*point[0] - s*point[1], y + s*point[0] + c*point[1])


def verify_interval(data, retained, index, interval, mask_points, bounds):
    f = data["frequency"]
    a, b = interval["desktop_qpc"]
    lo, hi = bounds
    indices = [i for i, r in enumerate(index) if lo+r[0]*f/1e6 > a and hi+r[1]*f/1e6 < b]
    assert len(indices) == interval["wholly_interior_observations"] >= 2
    rows = [retained[i] for i in indices]
    assert [rows[0][2], rows[-1][2]] == interval["native_ticks"]
    assert [rows[0][4], rows[-1][4]] == interval["physical_steps"]
    assert [rows[0][5], rows[-1][5]] == interval["pose_acknowledgements"]
    crop_x, crop_y, width, height = data["crop_world"]

    def inside(point):
        return crop_x+2 <= point[0] < crop_x+width-2 and crop_y+2 <= point[1] < crop_y+height-2

    for key, expected in interval["bodies"].items():
        track = [next(body for body in row[6] if body[0] == key) for row in rows]
        assert len({body[1] for body in track}) == 1
        for native in (False, True):
            maximum = 0.0
            moved = 0
            for previous, current in zip(track, track[1:]):
                movement = 0.0
                for point in mask_points[key]:
                    p0 = transform(previous, point, native)
                    p1 = transform(current, point, native)
                    if inside(p0) and inside(p1):
                        movement = max(movement, math.dist(p0, p1))
                maximum = max(maximum, movement)
                moved += movement > 0.001
            label = "native" if native else "rapier"
            assert abs(maximum - expected["max_" + label + "_in_crop_delta_cells"]) < 1e-8
            assert moved == expected["native_moving_pairs_in_crop" if native else "moving_pairs_in_crop"]


def main():
    data = read("qualification.json")
    samples = read("pose-samples.json")
    with (HERE / "visible.csv").open(newline="") as stream:
        trace = [{key: int(value) for key, value in r.items()} for r in csv.DictReader(stream)]
    active = [r for r in trace if r["phase"] == 2 and r["changed_pixels"] >= 0]
    changed = [r["desktop_qpc"] for r in active if r["changed_pixels"] > 0]
    assert len(changed) == data["active_any_changed"]
    assert sum(r["accumulated"] > 1 for r in trace) == data["accumulated_multi_frames"]
    assert sum(r["changed_pixels"] == -2 for r in trace) == data["invalid_visible_samples"]
    longest = max(zip(changed, changed[1:]), key=lambda t: t[1]-t[0])
    assert list(longest) == data["longest_between_visible_changes"]["desktop_qpc"]
    assert [active[0]["desktop_qpc"], changed[0]] == data["startup_before_first_change"]["desktop_qpc"]
    assert active[-1]["desktop_qpc"] == changed[-1]
    assert all(r["changed_pixels"] <= 0 for r in trace if r["phase"] == 1)
    f = data["frequency"]
    brackets = read("clock-brackets.json")
    bounds = (max(a-stamp*f/1e6-f/1e6 for _, _, a, b, stamp in brackets),
              min(b-stamp*f/1e6+f/1e6 for _, _, a, b, stamp in brackets))
    assert 0 <= bounds[1]-bounds[0] < f * 0.04
    assert list(bounds) == data["sample_clock"]["qpc_minus_godot_time_bounds"]
    with (HERE / "callback-index.csv").open(newline="") as stream:
        index = [list(map(int, row.values())) for row in csv.DictReader(stream)]
    retained = dict(zip(samples["captured_indices"], samples["rows"], strict=True))
    assert len(index) == samples["full_capture_count"]
    assert all(index[i] == row[:6] for i, row in retained.items())
    points = {}
    for key, identity in samples["shapes"].items():
        shape = samples["masks"][identity]
        width = shape["width"]
        points[key] = [(i % width + .5, i // width + .5)
                       for start, count in shape["occupied_flat_index_ranges"]
                       for i in range(start, start + count)]
    for field in ("longest_between_visible_changes", "startup_before_first_change"):
        interval = data[field]
        verify_interval(data, retained, index, interval, points, bounds)
        print(field, interval["duration_seconds"], interval["native_ticks"], interval["physical_steps"])


if __name__ == "__main__":
    main()
