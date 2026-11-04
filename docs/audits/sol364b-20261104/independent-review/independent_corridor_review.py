#!/usr/bin/env python3
"""Independent read-only geometry review of authenticated SOL364 host reports.

This script imports no candidate solver. It uses actual reported convex proxy
polygons and native material RLE, direct projection intervals and polygon
clipping. It computes necessary clearance distances for the registered finite
straight-translation family; it never authorizes or applies a correction.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import math
import platform
from pathlib import Path
import subprocess
import sys

START = "957ce67df859315ed238b6bbec1eebc9a743aaba"
REGISTRATION = "33203c5d5928ac53e5cc624e5dc1c3d26255f45b"
RUNTIME_SOURCE = "9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d"
MAX_DISTANCE = 4.0
AREA_FILTER = 1e-9
BASE = Path("docs/audits/sol281-20261103/hosted") / RUNTIME_SOURCE / "cohorts"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def canonical_hash(value):
    return sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode())


def authenticated_bytes(repository, relative):
    data = (repository / relative).read_bytes()
    expected = subprocess.check_output(
        ["git", "-C", str(repository), "rev-parse", f"{START}:{relative.as_posix()}"], text=True
    ).strip()
    actual = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
    if expected != actual:
        raise ValueError(f"working bytes differ from original tracked blob: {relative}")
    return data, {"path": relative.as_posix(), "size_bytes": len(data),
                  "sha256": sha256(data), "git_blob": actual,
                  "original_git_blob_authenticated": True}


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def axes(polygon):
    result = [(1.0, 0.0), (0.0, 1.0)]
    for i in range(len(polygon)):
        p, q = polygon[i], polygon[(i + 1) % len(polygon)]
        edge = (q[0] - p[0], q[1] - p[1])
        length = math.hypot(*edge)
        if not length > 0:
            raise ValueError("degenerate recorded polygon")
        normal = (-edge[1] / length, edge[0] / length)
        # Duplicated parallel axes cannot change an intersection of intervals.
        if not any(abs(dot(normal, existing)) > 1.0 - 1e-12 for existing in result):
            result.append(normal)
    return result


def projections(polygon, cell):
    x, y, _material = cell
    square = ((x, y), (x + 1, y), (x + 1, y + 1), (x, y + 1))
    result = []
    for normal in axes(polygon):
        p = [dot(point, normal) for point in polygon]
        q = [dot(point, normal) for point in square]
        # Positive overlap requires left < distance*speed < right.
        result.append((normal, min(q) - max(p), max(q) - min(p)))
    return result


def overlap_interval(projected, direction):
    lower, upper = -math.inf, math.inf
    for normal, left, right in projected:
        speed = dot(direction, normal)
        if abs(speed) < 1e-12:
            if not left < 0 < right:
                return None
        else:
            a, b = left / speed, right / speed
            lower, upper = max(lower, min(a, b)), min(upper, max(a, b))
            if lower >= upper:
                return None
    return (lower, upper)


def clipped_area(polygon, cell):
    x, y, _material = cell
    points = [(a - x, b - y) for a, b in polygon]
    for axis, bound, sign in ((0, 0, 1), (0, 1, -1), (1, 0, 1), (1, 1, -1)):
        result = []
        if not points:
            return 0.0
        previous = points[-1]
        previous_inside = (previous[axis] - bound) * sign >= 0
        for current in points:
            current_inside = (current[axis] - bound) * sign >= 0
            if current_inside != previous_inside:
                t = (bound - previous[axis]) / (current[axis] - previous[axis])
                result.append((previous[0] + t * (current[0] - previous[0]),
                               previous[1] + t * (current[1] - previous[1])))
            if current_inside:
                result.append(current)
            previous, previous_inside = current, current_inside
        points = result
    if len(points) < 3:
        return 0.0
    return abs(sum(points[i][0] * points[(i + 1) % len(points)][1]
                   - points[i][1] * points[(i + 1) % len(points)][0]
                   for i in range(len(points)))) * 0.5


def sanity():
    rect = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]
    cell = (0, 0, 2)
    assert clipped_area(rect, cell) == 1.0
    assert overlap_interval(projections(rect, cell), (1, 0)) == (-1.0, 2.0)
    assert overlap_interval(projections(rect, cell), (-1, 0)) == (-2.0, 1.0)
    assert overlap_interval(projections(rect, (3, 0, 2)), (1, 0)) == (2.0, 5.0)
    assert overlap_interval(projections(rect, (3, 0, 2)), (0, 1)) is None
    assert clipped_area(rect, (1, 0, 2)) == 0.0
    return {"analytic_checks": 6, "status": "pass",
            "scope": "independent axis-aligned containment, separation, touching and swept-interior sanity"}


def field_cells(field):
    width, height = field["size"]
    ox, oy = field["origin"]
    result, index = [], 0
    for material, count in field["material_runs"]:
        if not isinstance(material, int) or not isinstance(count, int) or count <= 0:
            raise ValueError("invalid material RLE")
        for _ in range(count):
            if material:
                result.append((index % width + ox, index // width + oy, material))
            index += 1
    if index != width * height:
        raise ValueError("incomplete material RLE")
    return result


def inspect_geometry(label, geometry, field):
    cells = field_cells(field)
    polygons, pose = geometry["proxies"], geometry["pose"]
    raw_directions = (("world+x", (1, 0)), ("world-x", (-1, 0)),
                      ("world+y", (0, 1)), ("world-y", (0, -1)),
                      ("body+x", (pose[0], pose[1])), ("body-x", (-pose[0], -pose[1])),
                      ("body+y", (pose[2], pose[3])), ("body-y", (-pose[2], -pose[3])))
    directions = []
    for name, value in raw_directions:
        length = math.hypot(*value)
        direction = (value[0] / length, value[1] / length)
        if not any(math.dist(direction, prior) < 1e-10 for _name, prior in directions):
            directions.append((name, direction))

    pairs, initial, hard = [], [], []
    for number, polygon in enumerate(polygons, 1):
        xs, ys = [p[0] for p in polygon], [p[1] for p in polygon]
        for cell in cells:
            x, y, material = cell
            # A conservative 4-cell-expanded AABB is broad phase only.
            if x + 1 < min(xs) - MAX_DISTANCE or x > max(xs) + MAX_DISTANCE \
                    or y + 1 < min(ys) - MAX_DISTANCE or y > max(ys) + MAX_DISTANCE:
                continue
            area = clipped_area(polygon, cell)
            pair = [number, x, y, material, area]
            pairs.append((pair, projections(polygon, cell)))
            if area > AREA_FILTER:
                initial.append(pair)
                if material != 2:
                    hard.append(pair)

    result = {
        "fixture": label, "input_geometry_sha256": canonical_hash(geometry),
        "input_material_field_sha256": canonical_hash(field),
        "recorded_polygons": polygons, "recorded_pose": pose,
        "relevant_nonempty_pairs": len(pairs), "initial_pairs": len(initial),
        "initial_sand_area_reconstructed": sum(row[4] for row in initial if row[3] == 2),
        "initial_non_sand_pairs": hard, "all_initial_pair_rows": initial,
        "initial_pair_columns": ["proxy", "cell_x", "cell_y", "material", "area"],
        "direction_results": [],
    }
    for name, direction in directions:
        initial_sand_intervals, new_intervals = [], []
        for pair, projected in pairs:
            interval = overlap_interval(projected, direction)
            if interval is None:
                continue
            lower, upper = interval
            if pair[4] > AREA_FILTER and pair[3] == 2:
                initial_sand_intervals.append(pair[:4] + [lower, upper])
            elif pair[4] <= AREA_FILTER and max(lower, 0) < min(upper, MAX_DISTANCE):
                new_intervals.append(pair[:4] + [max(lower, 0), min(upper, MAX_DISTANCE)])
        limiting = max(initial_sand_intervals, key=lambda row: row[-1], default=None)
        required = limiting[-1] if limiting else 0.0
        result["direction_results"].append({
            "name": name, "unit_direction": direction,
            "necessary_distance_to_clear_initial_sand_pairs": required,
            "necessary_distance_exceeds_4": required > MAX_DISTANCE,
            "limiting_initial_pair": limiting,
            "initial_sand_intervals": initial_sand_intervals,
            "new_pair_intervals_within4": new_intervals,
            "new_pair_count_within4": len(new_intervals),
            "interval_columns": ["proxy", "cell_x", "cell_y", "material", "open_interval_begin", "open_interval_end"],
        })
    result["all_directions_fail_distance_necessary_condition"] = all(
        row["necessary_distance_exceeds_4"] for row in result["direction_results"])
    result["geometric_rejection"] = bool(hard) or result["all_directions_fail_distance_necessary_condition"]
    return result


def run(repository):
    source_tree = subprocess.check_output(
        ["git", "-C", str(repository), "rev-parse", f"{START}^{{tree}}"], text=True).strip()
    registration_data = subprocess.check_output(
        ["git", "-C", str(repository), "show", f"{REGISTRATION}:docs/audits/2026-11-04-sol364b-corridor-registration.md"])
    script = Path(__file__).resolve()
    result = {
        "schema": "cybersand.sol364b.independent-corridor-review.v1",
        "reviewed_source": START, "reviewed_tree": source_tree,
        "preregistration_commit": REGISTRATION, "preregistration_sha256": sha256(registration_data),
        "historical_runtime_source": RUNTIME_SOURCE,
        "executed_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "command": [sys.executable, str(script), "--repository", str(repository)],
        "reviewer_runtime": {"python": sys.version, "executable": sys.executable,
                             "executable_sha256": sha256(Path(sys.executable).read_bytes()),
                             "platform": platform.platform(), "script_sha256": sha256(script.read_bytes())},
        "method": "independent normalized convex-polygon SAT projection intervals and Sutherland-Hodgman clipping; no candidate imports",
        "bounds": {"distance": MAX_DISTANCE, "initial_area_filter": AREA_FILTER,
                   "direction_deduplication": 1e-10, "zero_projection_speed": 1e-12},
        "interpretation": [
            "Necessary escape lower bounds inspect every initially overlapping Sand/proxy pair; new overlaps can only increase requirements or refuse.",
            "Reported values are from recorded float32 proxy polygon corners, not newly executed live native/Rapier geometry.",
            "Differences from native double reconstruction are retained; >1-cell rejection margins do not depend on tiny hard-contact rounding.",
            "No final-gap, continuous-depth, thermal/residency or live-lease PASS is granted by this necessary-condition review.",
            "Material RLE is not a complete reconstructible state/temperature/residency snapshot. Authoring/reset source establishes the historical fixture scope.",
            "No new physics execution, correction, native mutation, runtime qualification, or blanket topology impossibility is claimed.",
        ],
        "sanity": sanity(), "hosts": [],
    }
    for os_name in ("linux", "windows"):
        folder = BASE / os_name / "mechanism"
        if os_name == "linux":
            folder /= "host"
        cohort_bytes, cohort_identity = authenticated_bytes(repository, folder / "report.json")
        cohort = json.loads(cohort_bytes)
        for workers in (1, 4):
            relative = folder / f"synchronized-contact-w{workers}.json"
            data, identity = authenticated_bytes(repository, relative)
            raw = json.loads(data)
            if raw["workers"] != workers or raw["case_count"] != 21 or raw["backend"] != "Rapier2D":
                raise ValueError("unexpected historical report envelope")
            host = {
                "platform": raw["platform"], "workers": workers, "raw_report": identity,
                "cohort_manifest": cohort_identity, "historical_runtime": {
                    "source": cohort["source"], "engine": cohort["engine"],
                    "native": cohort["runtime"], "rapier": cohort["rapier"],
                    "build_manifest_sha256": cohort["build_manifest_sha256"],
                },
                "source_payload_sha256": raw["source_sha256"],
                "source_payload_canonical_sha256": canonical_hash(raw["source"]),
                "historical_fixture_input_hashes": raw["input_hashes"],
                "results": [],
            }
            for control in raw["controls"]:
                if control["id"] == "interior_without_face":
                    host["results"].append(inspect_geometry(
                        "nine_cell_interior", control["geometry"], raw["native_fields"][control["native_field"]]))
            for case in raw["cases"]:
                if case["arm"] == "candidate" and case["fixture"] in ("embedded_stationary", "rotated_compound"):
                    geometry = raw["geometries"][case["initial"]["measurement"]["geometry_id"]]
                    host["results"].append(inspect_geometry(
                        case["fixture"], geometry, raw["native_fields"][case["native_field"]]))
            if len(host["results"]) != 3:
                raise ValueError("missing target fixture")
            result["hosts"].append(host)
    result["all_original_target_states_reject_registered_family"] = all(
        fixture["geometric_rejection"] for host in result["hosts"] for fixture in host["results"])
    result["disposition"] = "NO-GO: registered finite translation family" if result["all_original_target_states_reject_registered_family"] else "Independent review incomplete"
    result["source_and_field_equivalence"] = {
        "source_payloads_equal": len({host["source_payload_canonical_sha256"] for host in result["hosts"]}) == 1,
        "fixtures": {label: {
            "native_material_fields_equal": len({case["input_material_field_sha256"] for host in result["hosts"] for case in host["results"] if case["fixture"] == label}) == 1,
            "recorded_geometries_equal": len({case["input_geometry_sha256"] for host in result["hosts"] for case in host["results"] if case["fixture"] == label}) == 1,
            "recorded_polygons_and_pose_equal": len({canonical_hash([case["recorded_polygons"], case["recorded_pose"]]) for host in result["hosts"] for case in host["results"] if case["fixture"] == label}) == 1,
            "necessary_distances_equal": len({canonical_hash([row["necessary_distance_to_clear_initial_sand_pairs"] for row in case["direction_results"]]) for host in result["hosts"] for case in host["results"] if case["fixture"] == label}) == 1,
        } for label in ("nine_cell_interior", "embedded_stationary", "rotated_compound")},
    }
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(run(args.repository.resolve()), sort_keys=True, indent=2, allow_nan=False))
