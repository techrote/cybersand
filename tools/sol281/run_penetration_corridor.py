#!/usr/bin/env python3
"""Source-bound SOL364-B geometry admission against retained actual-host states.

This deliberately does not run a new Rapier trajectory, issue a live owner lease,
or turn a material-only historical snapshot into current temperature/residency
authority. Its native probe is a bounded pure diagnostic. Existing physics and
all historical physical/cost failures keep their original source identities.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

REPOSITORY = Path(__file__).resolve().parents[2]
HISTORICAL_HEAD = "957ce67df859315ed238b6bbec1eebc9a743aaba"
HISTORICAL_EXECUTION = "9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d"
REGISTRATION_TREE = "d7f87bd1212ba258b07ec3ce4c207b782237458a"
INPUTS = (
    "tools/sol281/penetration_corridor.hpp",
    "tools/sol281/penetration_corridor_probe.cpp",
    "tools/sol281/test_penetration_corridor.cpp",
    "tools/sol281/run_penetration_corridor.py",
    "native/include/cybersand/solid_contact_geometry.hpp",
    "docs/audits/2026-11-04-sol364b-corridor-registration.md",
)
DEFAULT_REPORTS = tuple(
    f"docs/audits/sol281-20261103/hosted/{HISTORICAL_EXECUTION}/cohorts/{platform}/mechanism/"
    f"{'host/' if platform == 'linux' else ''}synchronized-contact-w{workers}.json"
    for platform in ("linux", "windows") for workers in (1, 4)
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run(command: list[str], *, data: str | None = None) -> subprocess.CompletedProcess[str]:
    # Text-mode pipes translate LF to CRLF on Windows. The input SHA names the
    # exact canonical UTF-8 bytes sent to the probe on either actual host.
    completed = subprocess.run(command, input=None if data is None else data.encode("utf-8"),
                               capture_output=True, check=True, cwd=REPOSITORY, timeout=120)
    return subprocess.CompletedProcess(completed.args, completed.returncode,
                                       completed.stdout.decode("utf-8"), completed.stderr.decode("utf-8"))


def git(*arguments: str) -> str:
    return run(["git", *arguments]).stdout.strip()


def source_inputs() -> dict[str, str]:
    return {name: sha((REPOSITORY / name).read_bytes()) for name in INPUTS}


def historical_bytes(path: str) -> tuple[bytes, dict[str, str | int]]:
    if Path(path).is_absolute() or ".." in Path(path).parts:
        raise ValueError("historical paths must remain repository-relative")
    local = REPOSITORY / path
    expected = subprocess.run(["git", "show", f"{HISTORICAL_HEAD}:{path}"], cwd=REPOSITORY,
                              check=True, capture_output=True, timeout=120).stdout
    actual = local.read_bytes()
    match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", expected)
    if match:
        expected_hash = match[1].decode()
        expected_size = int(match[2])
        if len(actual) != expected_size or sha(actual) != expected_hash:
            raise ValueError(f"not materialized or mismatching historical LFS input: {path}")
        source_kind = "historical_git_lfs_pointer"
    else:
        if actual != expected:
            raise ValueError(f"historical Git bytes differ: {path}")
        expected_hash, expected_size, source_kind = sha(expected), len(expected), "historical_git_blob"
    return actual, {"path": path, "sha256": expected_hash, "bytes": expected_size,
                    "source_kind": source_kind, "historical_head": HISTORICAL_HEAD}


def material_field(field: dict) -> list[int]:
    size = field["size"]
    if len(size) != 2 or any(type(v) is not int or not 0 < v <= 1024 for v in size):
        raise ValueError("invalid historical native field dimensions")
    count = size[0] * size[1]
    cells: list[int] = []
    for material, repeat in field["material_runs"]:
        if type(material) is not int or type(repeat) is not int or material < 0 or material > 65535 or repeat <= 0:
            raise ValueError("invalid material run")
        if len(cells) + repeat > count:
            raise ValueError("native field RLE exceeds its complete rectangle")
        cells.extend([material] * repeat)
    if len(cells) != count:
        raise ValueError("incomplete native field RLE")
    return cells


def source_partition(source: dict) -> list[list[int]]:
    raw = source["rectangles"]
    members = source["members"]
    if len(raw) != 24 or len(members) != 3120 or int(source["member_count"]) != 520 or int(source["shape_count"]) != 6:
        raise ValueError("historical compound is not the retained 520-cell six-proxy source")
    shapes = [[int(x) for x in raw[i:i+4]] for i in range(0, len(raw), 4)]
    if any(float(raw[i]) != shapes[i//4][i%4] for i in range(len(raw))):
        raise ValueError("source partition is not the exact integer cell partition")
    occupied = {(int(members[i]), int(members[i+1])) for i in range(0, len(members), 6)}
    if len(occupied) != 520:
        raise ValueError("duplicate or missing source member")
    covered: set[tuple[int, int]] = set()
    for x, y, width, height in shapes:
        if width <= 0 or height <= 0:
            raise ValueError("invalid source proxy")
        for cy in range(y, y+height):
            for cx in range(x, x+width):
                if (cx, cy) not in occupied or (cx, cy) in covered:
                    raise ValueError("source proxy fills a hole or overlaps a sibling")
                covered.add((cx, cy))
    if occupied != covered or (60, 32) in covered or (68, 50) in covered:
        raise ValueError("the retained exact payload or either void changed")
    return shapes


def input_text(source: dict, geometry: dict, field: dict, shapes: list[list[int]], cells: list[int]) -> tuple[str, float]:
    pose = geometry["pose"]
    if len(pose) != 6 or not all(math.isfinite(v) for v in pose):
        raise ValueError("nonfinite recorded pose")
    angle = math.atan2(pose[1], pose[0])
    c, s = math.cos(angle), math.sin(angle)
    com = source["center"]
    maximum_corner_difference = 0.0
    for index, (x, y, width, height) in enumerate(shapes):
        for vertex, (lx, ly) in enumerate(((x, y), (x+width, y), (x+width, y+height), (x, y+height))):
            local_x, local_y = lx-com[0], ly-com[1]
            reconstructed = (pose[4]+c*local_x-s*local_y, pose[5]+s*local_x+c*local_y)
            recorded = geometry["proxies"][index][vertex]
            maximum_corner_difference = max(maximum_corner_difference, math.dist(reconstructed, recorded))
    # This is an input-correspondence check at the existing witness tolerance,
    # never a relaxed clearance tolerance. The exact drift is retained and
    # tiny hard contacts are not silently rounded into an absence of contact.
    if maximum_corner_difference > 0.001:
        raise ValueError("recorded proxy polygons do not correspond to the reconstructed shared rigid transform")
    origin, size = field["origin"], field["size"]
    lines = ["SOL364B_CORRIDOR_V1", f"{origin[0]} {origin[1]} {size[0]} {size[1]} {len(shapes)}",
             " ".join(format(v, ".17g") for v in (pose[4], pose[5], com[0], com[1], angle, 4.0))]
    lines.extend(" ".join(map(str, shape)) for shape in shapes)
    lines.append(" ".join(map(str, cells)))
    return "\n".join(lines)+"\n", maximum_corner_difference


def emit(path: Path, value: object) -> str:
    data = (json.dumps(value, indent=2, sort_keys=True, allow_nan=False)+"\n").encode()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return sha(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", required=True, type=Path, help="externally built native probe executable")
    parser.add_argument("--tests", type=Path, help="externally built native adversarial-test executable")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", action="append", help="one or more original repository-relative reports; defaults to all four hosts")
    parser.add_argument("--initial-only", action="store_true", help="initial target states only; default also evaluates all 180 stationary and rotated recorded states")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    inputs_before = source_inputs()
    head_before, tree_before = git("rev-parse", "HEAD"), git("rev-parse", "HEAD^{tree}")
    probe = args.probe.resolve()
    probe_hash_before = sha(probe.read_bytes())
    checks = 0
    tests: dict = {"status": "NOT_REQUESTED"}
    tests_executable: Path | None = None
    tests_hash_before: str | None = None
    if args.tests:
        tests_executable = args.tests.resolve()
        tests_hash_before = sha(tests_executable.read_bytes())
        completed = run([str(tests_executable)])
        if sha(tests_executable.read_bytes()) != tests_hash_before:
            raise ValueError("native test executable changed during execution")
        tests = {"status": "PASS", "sha256": tests_hash_before,
                 "result": json.loads(completed.stdout), "stderr": completed.stderr}
        if tests["result"].get("failures") != 0 or tests["result"].get("live_application") is not False:
            raise ValueError("invalid adversarial native test receipt")
    cases: list[dict] = []
    sources: list[dict] = []
    cache: dict[str, dict] = {}
    snapshot_source_values: set[str] = set()
    for report_path in args.report or DEFAULT_REPORTS:
        raw, receipt = historical_bytes(report_path)
        data = json.loads(raw)
        if data.get("schema") != "cybersand.sol364.synchronized-contact.v1" or data.get("failures") or not data.get("complete_replay"):
            raise ValueError("historical report is not a complete original synchronized replay")
        source = data["source"]
        shapes = source_partition(source)
        receipt.update({"platform": data["platform"], "workers": data["workers"], "engine": data["engine"],
                        "backend": data["backend"], "source_sha256": data["source_sha256"],
                        "original_physical_cases": len(data["cases"]),
                        "original_clearance_failures": sum(not c["physical_gates"]["sustained_clearance_pass"] for c in data["cases"])})
        sources.append(receipt)
        snapshot_source_values.add(json.dumps(source, sort_keys=True))
        selected: list[tuple[str, int, dict, str, dict]] = []
        interior = next(control for control in data["controls"] if control["id"] == "interior_without_face")
        selected.append(("nine_cell_interior", 0, interior["geometry"], interior["native_field"],
                         {"original_aggregate_owned": interior["aggregate_owned"], "payload_preserved": interior["payload_preserved"]}))
        for fixture in ("embedded_stationary", "rotated_compound"):
            case = next(case for case in data["cases"] if case["id"] == f"{fixture}/candidate")
            if case["steps"] != 180 or len(case["trace"]) != 180 or not case["payload_preserved"] or case["aggregate_owned"] != 520:
                raise ValueError("incomplete retained case ownership or step history")
            samples = [case["initial"]] + ([] if args.initial_only else case["trace"])
            for expected_step, sample in enumerate(samples):
                if sample["step"] != expected_step:
                    raise ValueError("historical replay step inventory is not complete and ordered")
                measurement = sample["measurement"]
                geometry = data["geometries"][measurement["geometry_id"]]
                state = sample["state"] if expected_step == 0 else sample["after"]
                if state["sleeping"] or not all(math.isfinite(v) for v in state["pose"]+state["velocity"]+[state["omega"], state["kinetic"]]):
                    raise ValueError("sleeping or nonfinite historical body state")
                selected.append((fixture, expected_step, geometry, case["native_field"],
                                 {"original_physical_gates": case["physical_gates"], "original_state": state,
                                  "original_measurement": measurement,
                                  "original_response": sample.get("response"), "payload_preserved": True,
                                  "original_aggregate_owned": 520}))
        fields = {key: material_field(value) for key, value in data["native_fields"].items()}
        for fixture, step, geometry, field_id, original in selected:
            field = data["native_fields"][field_id]
            text, difference = input_text(source, geometry, field, shapes, fields[field_id])
            digest = sha(text.encode())
            if digest not in cache:
                started = time.monotonic()
                completed = run([str(probe)], data=text)
                value = json.loads(completed.stdout)
                if value.get("schema") != "cybersand.sol364b.corridor-geometry.v1" or value.get("live_authority") is not False \
                        or value.get("application_count") != 0 or value.get("position_work_applied") != 0:
                    raise ValueError("invalid native geometry-only receipt")
                cache[digest] = value
                (output / "inputs").mkdir(exist_ok=True)
                (output / "inputs" / f"{digest}.txt").write_bytes(text.encode("utf-8"))
                emit(output / "certificates" / f"{digest}.json", {"input_sha256": digest, "probe_sha256": probe_hash_before,
                     "process_wall_seconds": time.monotonic()-started, "stderr": completed.stderr, "result": value})
            result = cache[digest]
            checks += 1
            cases.append({"source_report_sha256": receipt["sha256"], "platform": data["platform"], "workers": data["workers"],
                          "fixture": fixture, "retained_step": step, "certificate": digest,
                          "native_field_hash": field_id, "recorded_geometry_sha256": geometry.get("sha256"),
                          "shared_rigid_reconstruction_max_corner_difference": difference,
                          "original_total_overlap_area": geometry["overlap_area"],
                          "original_sand_overlap_area": geometry["sand_overlap_area"],
                          "original_maximum_depth": geometry["max_penetration"],
                          "outcome": result["outcome"], "geometric_routes": result["geometric_routes"],
                          "all_direction_clearance_bounds_exceed_four": bool(result["directions"]) and all(
                              d["required_distance"] is None or d["required_distance"] > 4.0 for d in result["directions"]),
                          "original": original})
    inputs_after = source_inputs()
    if inputs_after != inputs_before or sha(probe.read_bytes()) != probe_hash_before:
        raise ValueError("executable or checked analysis inputs changed during replay")
    if tests_executable and sha(tests_executable.read_bytes()) != tests_hash_before:
        raise ValueError("native test executable changed during replay")
    if head_before != git("rev-parse", "HEAD") or tree_before != git("rev-parse", "HEAD^{tree}"):
        raise ValueError("analysis source HEAD changed during replay")
    outcome_counts: dict[str, int] = {}
    for case in cases:
        outcome_counts[case["outcome"]] = outcome_counts.get(case["outcome"], 0)+1
    initial = [case for case in cases if case["retained_step"] == 0]
    unique_routes = [case for case in cases if case["outcome"] == "GeometryOnlyUniqueCorridor"]
    summary = {
        "schema": "cybersand.sol364b.retained-corridor-admission.v1",
        "analysis_git_head": head_before, "analysis_git_tree": tree_before,
        "checked_inputs": inputs_before, "checked_inputs_at_finish": inputs_after,
        "registration_tree": REGISTRATION_TREE,
        "historical_source_head": HISTORICAL_HEAD, "historical_executed_source": HISTORICAL_EXECUTION,
        "probe_sha256": probe_hash_before, "native_tests": tests, "sources": sources,
        "executable_provenance": "executable hashes and immutability are checked here; binding them to checked C++ inputs requires the separately retained compiler/build manifest",
        "source_payload_equal_across_reports": len(snapshot_source_values) == 1,
        "reports": len(sources), "retained_states_evaluated": len(cases), "unique_geometric_inputs": len(cache),
        "checks": checks, "failures": 0, "outcome_counts": outcome_counts,
        "initial_case_summary": initial, "geometry_only_unique_routes": len(unique_routes),
        "live_candidate_applications": 0, "candidate_physical_pass": False,
        "disposition": "BOUNDED_FAMILY_NO_GO" if not unique_routes else "GEOMETRIC_ROUTE_REQUIRES_LIVE_AUTHORITY_AND_WORK_REVIEW",
        "scope": "diagnostic continuous fixed-orientation finite-direction corridor analysis of original actual-host recorded states; no new Rapier trajectory or live correction",
        "eligibility_scope": "historical material RLE only; state/temperature/foreign masks/residency are not reconstructed from a hash, and no live eligibility or current-owner lease is asserted",
        "geometry_scope": "one exact shared rigid transform reconstructed from retained pose/source COM and exact integer source partition; all differences from recorded float32 corners are preserved",
        "runtime_scope": "original actual-host libraries remain historical controls; the probe is a separately compiled C++ diagnostic",
        "physical_inventory_scope": "all original 84 physical cases remain failed in their original scope; no case is removed when new topology admission refuses",
        "cpu_gate_scope": "original 24-group live CPU is historical; offline query wall times do not qualify a new live candidate",
        "limitation": "NO_GO covers only registered eight-or-fewer straight directions, four-cell cumulative budget, fixed orientation and no-new-pair policy; no arbitrary-path impossibility claim",
    }
    emit(output / "states.json", cases)
    emit(output / "summary.json", summary)
    print(json.dumps({key: summary[key] for key in ("schema", "analysis_git_head", "reports", "retained_states_evaluated",
          "unique_geometric_inputs", "outcome_counts", "geometry_only_unique_routes", "live_candidate_applications", "disposition")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, StopIteration, subprocess.SubprocessError) as error:
        print(f"SOL364B_CORRIDOR_REPLAY_FAILURE: {error}", file=sys.stderr)
        raise SystemExit(1)
