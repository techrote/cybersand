"""Summarize material planes from the full-size Windows Workbench impingement replay."""
from argparse import ArgumentParser
from array import array
from hashlib import sha256
import json
from pathlib import Path
from statistics import pstdev
import sys

# The basin floor under these columns is contiguous Steel, before the ramp.
COLUMNS = range(56, 167)
WATER, OIL, STEEL = 3, 16, 1


def sample(directory, stage):
    data = (directory / stage["plane"]).read_bytes()
    assert len(data) == 2 * 2048 * 2048
    assert sha256(data).hexdigest() == stage["sha256_material_plane"]
    cells = array("H")
    cells.frombytes(data)
    if sys.byteorder != "little":
        cells.byteswap()
    rows = []
    oil_contacts = 0
    for x in COLUMNS:
        floor = next(y for y in range(125, 170) if cells[2048 * y + x] == STEEL)
        top = floor
        while top and cells[2048 * (top - 1) + x] == WATER:
            top -= 1
        rows.append(top if top < floor else None)
        if top < floor and cells[2048 * (top - 1) + x] == OIL:
            oil_contacts += 1
    wet = [y for y in rows if y is not None]
    water = stage["spray"]["water"]
    assert water["total"] == water["expected"] == water["visible"] + water["ballistic"]
    return dict(
        tick=stage["tick"], plane_sha256=stage["sha256_material_plane"],
        water_total=water["total"], in_flight_water=water["ballistic"],
        water_cells=cells.count(WATER), oil_cells=cells.count(OIL),
        cumulative_thrown_water=stage["spill"]["launched_units"], wet_columns=len(wet),
        oil_contact_columns=oil_contacts, contact_relief=max(wet) - min(wet) if wet else None,
        contact_sd=round(pstdev(wet), 3) if wet else None,
        floor_connected_water_top_rows=rows,
    )


def summarize(directory):
    receipt = json.loads((directory / "receipt.json").read_bytes())
    assert not receipt["failures"] and "native_failure" not in receipt
    profile = receipt["profile"]
    report = {key: receipt[key] for key in ["godot", "display", "extent", "map_sha256", "dll_sha256", "paints"]}
    report["requested_workers"] = profile["workers_requested"]
    report["substeps"] = profile["substeps"]
    report["wave_parameters"] = profile["parameters"]
    report["spill_controls"] = {key: profile["spill"][key] for key in
        ["enabled", "parcels", "blobs", "full_face", "fall", "sheet_rate", "draw", "draw_head", "coyote_ticks"]}
    report["first_x"] = COLUMNS.start
    report["last_x"] = COLUMNS.stop - 1
    report["stages"] = [sample(directory, stage) for stage in receipt["stages"]]
    assert len(set(stage["oil_cells"] for stage in report["stages"])) == 1
    return report


def write_summary(report, destination):
    # Keep a column profile on one line so it can be compared across ticks.
    header = {key: value for key, value in report.items() if key != "stages"}
    lines = [json.dumps(header, indent=2)[:-2] + ',\n  "stages": [']
    lines.append(",\n".join("    " + json.dumps(stage) for stage in report["stages"]))
    lines.append("  ]\n}\n")
    destination.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    write_summary(summarize(args.directory), args.output)
