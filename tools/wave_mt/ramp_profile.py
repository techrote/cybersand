"""Replay the owner's unmodified ordinary Workbench ramp setup in wave_waterwall.

prepare writes native rectangle input. summarize reads apparatus stdout, including
its floor-attached and airborne probes. No saved setups are modified.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path


def prepare(source, dest):
    data = source.read_bytes()
    if hashlib.sha256(data).hexdigest() != "7aba8a47c926cc1911bc4ee519179c595b686692d5c78db8f103b8b62d311acb":
        raise ValueError("expected the supplied setup-water-ramp.json")
    setup = json.loads(data)
    if (setup["version"] != 2 or setup["extent"] != [2048, 2048] or setup["actors"] or setup["source"]
            or len(setup["edits"]) != 635):
        raise ValueError("unexpected ramp setup")
    with dest.open("x", newline="\n") as out:
        for x, y, width, height, material in setup["edits"]:
            if (min(x, y) < 0 or min(width, height) < 1 or max(x + width, y + height) > 2048
                    or material not in (1, 3)):
                raise ValueError("unexpected ramp edit")
            out.write(f"{x} {y} {width} {height} {material}\n")


def summarize(log):
    lines = log.read_text().splitlines()
    if not lines or not lines[0].startswith("scene="):
        raise ValueError("missing initial scene inventory")
    initial = dict(part.split("=", 1) for part in lines[0].split())
    scene = initial["scene"]
    supported = {"ramp": 9773895, "flat_surge": 261120, "drop_surge": 261120, "uphill_surge": 261120}
    if scene not in supported or int(initial["water_units"]) != supported[scene]:
        raise ValueError("unexpected initial scene or Water quantity")
    rows = list(csv.DictReader(line for line in lines if line.startswith("tick,") or line[:1].isdigit()))
    if not rows or not lines[-1].startswith("overall_median_us=") or any(int(r["total_drift"]) for r in rows):
        raise ValueError("incomplete run or water lost")
    if scene != "ramp":
        return {
            "last_tick": int(rows[-1]["tick"]),
            "max_bulk_floor_rise": max(int(r["bulk_floor_rise"]) for r in rows),
            "max_grounded_units_at_rise16": max(int(r["rise16_units"]) for r in rows),
            "max_grounded_units_at_rise32": max(int(r["rise32_units"]) for r in rows),
            "mean_fraction_at_rise16_through_t400": (
                sum(int(r["rise16_units"]) for r in rows if int(r["tick"]) <= 400)
                / (sum(int(r["tick"]) <= 400 for r in rows) * supported[scene])
            ),
            "early": {r["tick"]: {k: float(r[k]) for k in (
                "left_bulk_distance", "right_bulk_distance", "grounded_units", "mass_weighted_outward_cells")}
                for r in rows if int(r["tick"]) in (8, 16, 32, 64)},
        }

    def arrival(key, threshold):
        return next((int(r["tick"]) for r in rows if int(r[key]) >= threshold), None)
    result = {
        "last_tick": int(rows[-1]["tick"]),
        "first_sample_front_900": arrival("floor_front_2x8", 900),
        "first_sample_front_960": arrival("floor_front_2x8", 960),
        "first_sample_128_cells_beyond_900": arrival("floor_units_900_1008", 128 * 255),
        "first_sample_128_cells_beyond_960": arrival("floor_units_960_1008", 128 * 255),
        "first_sample_parcel_900": arrival("parcel_front", 900),
        "final_floor_units_900": int(rows[-1]["floor_units_900_1008"]),
        "final_airborne_units_900": int(rows[-1]["parcel_units_900_1008"]),
    }
    if "bank_excess5" in rows[0]:
        wet = [r for r in rows if int(r["interior_surface_y"]) >= 0]
        result["bank_peak_above_interior_cells"] = max((float(r["bank_excess5"]) for r in wet), default=None)
        result["mean_bank_rise_above_interior_cells"] = (
            sum(float(r["bank_excess5"]) for r in wet) / len(wet) if wet else None
        )
        late = [r for r in wet if int(r["tick"]) >= 900]
        bank_units = sum(int(r["bank_connected_units"]) for r in late)
        result["late_fraction_above_fixed_rise32"] = (
            sum(int(r["bank_rise32_units"]) for r in late) / bank_units if bank_units else None
        )
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    cmd = parser.add_subparsers(required=True, dest="command")
    p = cmd.add_parser("prepare")
    p.add_argument("setup", type=Path)
    p.add_argument("stamps", type=Path)
    s = cmd.add_parser("summarize")
    s.add_argument("logs", nargs="+", type=Path)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.setup, args.stamps)
    else:
        print(json.dumps({str(log): summarize(log) for log in args.logs}, indent=2))
