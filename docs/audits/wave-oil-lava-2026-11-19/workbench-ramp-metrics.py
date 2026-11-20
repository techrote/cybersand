"""Summarize raw material copies made by workbench-ramp-replay.gd."""

import argparse
from array import array
from collections import Counter
from math import ceil
import hashlib
import json
from pathlib import Path
from statistics import median
import sys


def measure(directory, stage):
    raw = (directory / stage["plane"]).read_bytes()
    assert len(raw) == 2048 * 2048 * 2
    assert hashlib.sha256(raw).hexdigest() == stage["sha256_material_plane"]
    plane = array("H")
    plane.frombytes(raw)
    if sys.byteorder != "little":
        plane.byteswap()
    count = Counter(plane)
    thickness = Counter()
    exposed = set()
    slick = set()
    oil_without_water_above = 0
    touching_water_above = 0
    in_original_disc = 0
    in_original_columns = 0
    bounds = []
    # The global count below ensures this crop covers every Oil cell. Scan
    # each full column from the top so an air gap does not hide Water above.
    for x in range(480, 1070):
        water_above = False
        for y in range(520):
            value = plane[2048 * y + x]
            if value == 3:
                water_above = True
            if value != 16:
                continue
            thickness[x] += 1
            bounds.append((x, y))
            if (x - 805) ** 2 + (y - 448) ** 2 <= 24 ** 2:
                in_original_disc += 1
            if 781 <= x <= 829:
                in_original_columns += 1
            above = plane[2048 * (y - 1) + x] if y else 0
            if above == 0:
                exposed.add(x)
            if above == 3:
                touching_water_above += 1
            if not water_above:
                slick.add(x)
                oil_without_water_above += 1
    assert sum(thickness.values()) == count[16], "Oil outside basin crop"
    x_values = [x for x, _ in bounds]
    y_values = [y for _, y in bounds]
    ordered_thickness = sorted(thickness.values())
    return {
        "tag": stage["tag"], "tick": stage["tick"], "oil_cells": count[16],
        "water_cells": count[3], "lava_cells": count[8],
        "steam_cells": count[22], "stone_cells": count[13],
        "oil_span_cells": max(x_values) - min(x_values) + 1 if bounds else 0,
        "oil_max_thickness": max(thickness.values(), default=0),
        "oil_median_occupied_thickness": median(thickness.values()) if bounds else 0,
        "oil_p90_occupied_thickness": ordered_thickness[ceil(0.9 * len(ordered_thickness)) - 1] if bounds else 0,
        "oil_in_original_brush_disc": in_original_disc,
        "oil_in_original_brush_columns": in_original_columns,
        "oil_exposed_columns": len(exposed),
        "oil_without_water_above": oil_without_water_above,
        "columns_oil_without_water_above": len(slick),
        "oil_cells_touching_water_above": touching_water_above,
        "oil_bbox": [min(x_values), min(y_values), max(x_values), max(y_values)] if bounds else [],
        "water_quantity": stage["water_quantity"],
        "material_plane_sha256": stage["sha256_material_plane"],
        "cumulative_spill_launched_units": stage["spill"]["launched_units"],
        "in_flight_units": stage["spray"]["in_flight_quantity"],
        "live": stage["spray"]["live"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    directory = parser.parse_args().directory
    receipt = json.loads((directory / "receipt.json").read_text(encoding="utf-8"))
    fields = ("godot", "display", "map_sha256", "dll_sha256", "extent", "failures", "paints")
    result = {name: receipt[name] for name in fields}
    if "native_failure" in receipt:
        result["native_failure"] = receipt["native_failure"]
    profile = receipt["profile"]
    result["controls"] = {k: profile[k] for k in ("parameters", "substeps", "workers_requested", "enabled")}
    result["controls"]["spill"] = {k: profile["spill"][k] for k in ("enabled", "parcels", "full_face", "fall")}
    result["rows"] = [measure(directory, stage) for stage in receipt["stages"]]
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
