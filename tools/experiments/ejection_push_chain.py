"""Stage C: finite conservative push chains on copied default-cellular state.

This diagnostic never accesses a simulation World. A chain contains the displaced
source and at most three further movable parcels, ending at an unmasked Empty.
All hops are four-connected, inside Stage B's interior AABB, and point strictly
forward or nonrearward under the selected policy. The AABB is the documented
geometric overapproximation of the existing production search, not its outer ring.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
import math
from pathlib import Path

try:
    from .ejection_topology import Grid, DIRECTIONS, canonical_hash, vector_comparison
except ImportError:
    from ejection_topology import Grid, DIRECTIONS, canonical_hash, vector_comparison

POLICIES = ("forward", "forward_lateral")
CAPS = (1, 2, 3, 4)


def hop_allowed(normal: tuple, delta: tuple, policy: str) -> bool:
    if policy not in POLICIES:
        raise ValueError("unknown directional policy")
    dot = normal[0] * delta[0] + normal[1] * delta[1]
    return dot > 0 if policy == "forward" else dot >= 0


def _check_parameters(grid: Grid, policy: str, cap: int) -> None:
    if policy not in POLICIES or type(cap) is not int or cap not in CAPS:
        raise ValueError("oracle requires a registered policy and moved-parcel cap1..4")
    if not all(math.isfinite(x) for x in grid.normal) or math.hypot(*grid.normal) == 0:
        raise ValueError("normal must be finite and nonzero")
    if grid.capsule.get("storage_policy", "default_cellular_no_pressure_or_inertial_sidecar") != "default_cellular_no_pressure_or_inertial_sidecar":
        raise ValueError("pressure and inertial sidecars are outside this oracle")


def enumerate_chains(capsule: dict, policy: str, cap: int) -> tuple[list[list[tuple]], dict]:
    """Enumerate deterministic simple parcel chains, with a hard four-move cap."""
    grid = Grid(capsule)
    _check_parameters(grid, policy, cap)
    source_row = grid.row(grid.source)
    reasons = Counter()
    if source_row[0] == 0 or source_row[5] or not source_row[6]:
        return [], {"source_not_movable": 1}
    if source_row[4] != grid.body_id:
        return [], {"source_not_owned_contact": 1}
    chains = []

    def visit(movers: list[tuple]) -> None:
        x, y = movers[-1]
        for dx, dy in DIRECTIONS:
            point = x + dx, y + dy
            if not grid.interior(point) or not grid.in_world(point):
                reasons["outside_neighborhood"] += 1
                continue
            if not hop_allowed(grid.normal, (dx, dy), policy):
                reasons["direction_refused"] += 1
                continue
            if point in movers:
                reasons["cycle"] += 1
                continue
            row = grid.row(point)
            if row[5]:
                reasons["hard_surface"] += 1
            elif row[4] != 0:
                reasons["source_body" if row[4] == grid.body_id else "foreign_body"] += 1
            elif row[0] == 0:
                chains.append([*movers, point])
            elif not row[6]:
                reasons["immovable"] += 1
            elif len(movers) == cap:
                # This is a bounded frontier, not proof a longer chain exists.
                reasons["chain_cap_frontier"] += 1
            else:
                visit([*movers, point])

    visit([grid.source])
    chains.sort(key=lambda path: (len(path), tuple(path)))
    return chains, dict(sorted(reasons.items()))


def _parcels(rows: list) -> Counter:
    # Body IDs belong to positions; every other field of a nonempty parcel,
    # including raw carrier epoch/spare bits and persistent temperature, moves.
    return Counter(tuple(row[:4]) + tuple(row[5:]) for row in rows if row[0] != 0)


def _quantity(rows: list) -> int:
    return sum(int(row[7]) for row in rows if row[0] == 3)


def apply_chain(capsule: dict, path: list, policy: str, cap: int) -> tuple[dict, dict]:
    """Validate independently, apply tail-first to a copy, and prove invariants."""
    original_hash = canonical_hash(capsule)
    grid = Grid(capsule)
    _check_parameters(grid, policy, cap)
    points = [tuple(p) for p in path]
    if not 2 <= len(points) <= cap + 1 or points[0] != grid.source or len(set(points)) != len(points):
        raise ValueError("invalid chain identity, length or repeated position")
    source = grid.row(points[0])
    if source[4] != grid.body_id:
        raise ValueError("source is not the captured body contact")
    for index, point in enumerate(points):
        if not grid.interior(point) or not grid.in_world(point):
            raise ValueError("chain left existing interior neighborhood")
        row = grid.row(point)
        if row[5] or (index and row[4] != 0):
            raise ValueError("chain crosses hard surface or body occupancy")
        if index == len(points) - 1:
            if row[0] != 0:
                raise ValueError("chain has no terminal empty cell")
        elif row[0] == 0 or not row[6]:
            raise ValueError("chain contains empty or immovable parcel")
        if index:
            delta = point[0] - points[index - 1][0], point[1] - points[index - 1][1]
            if abs(delta[0]) + abs(delta[1]) != 1 or not hop_allowed(grid.normal, delta, policy):
                raise ValueError("chain has nonlocal or directionally forbidden hop")
    after = copy.deepcopy(capsule)
    before_rows = capsule["cells"]
    after_rows = after["cells"]
    ambient = int(capsule.get("ambient_temperature", 200))

    def at(point: tuple) -> int:
        return (point[1] - grid.top) * grid.width + point[0] - grid.left

    for index in range(len(points) - 2, -1, -1):
        origin, destination = at(points[index]), at(points[index + 1])
        moved = list(after_rows[origin])
        moved[4] = after_rows[destination][4]
        after_rows[destination] = moved
        after_rows[origin] = [0, 0, 0, ambient, after_rows[origin][4], False, False, 0, "0000000000000000"]
    mask_before = [row[4] for row in before_rows]
    mask_after = [row[4] for row in after_rows]
    overlap_before = sum(row[0] != 0 and row[4] != 0 for row in before_rows)
    overlap_after = sum(row[0] != 0 and row[4] != 0 for row in after_rows)
    moved_positions = set(points)
    unchanged_outside = all(before_rows[i] == after_rows[i] for i in range(len(before_rows))
                            if (grid.left + i % grid.width, grid.top + i // grid.width) not in moved_positions)
    conservation = _parcels(before_rows) == _parcels(after_rows)
    quantities = _quantity(before_rows) == _quantity(after_rows)
    counts = Counter(row[0] for row in before_rows) == Counter(row[0] for row in after_rows)
    masks = mask_before == mask_after
    source_empty = after_rows[at(grid.source)][0] == 0
    new_overlap = sum(after_rows[at(p)][0] != 0 and after_rows[at(p)][4] != 0 for p in points[1:])
    checks = {"parcel_conservation": conservation, "quantity_conservation": quantities,
              "material_counts_conserved": counts, "body_masks_unchanged": masks,
              "outside_chain_unchanged": unchanged_outside, "source_empty": source_empty,
              "source_overlap_removed": overlap_after == overlap_before - 1,
              "new_body_overlaps": new_overlap, "barrier_violations": 0,
              "overlap_before": overlap_before, "overlap_after": overlap_after,
              "input_nonmutation": canonical_hash(capsule) == original_hash}
    if not all((conservation, quantities, counts, masks, unchanged_outside, source_empty,
                checks["source_overlap_removed"], new_overlap == 0, checks["input_nonmutation"])):
        raise AssertionError(f"oracle conservation/overlap failure: {checks}")
    return after, checks


def solve(capsule: dict, policy: str, cap: int) -> dict:
    before = canonical_hash(capsule)
    grid = Grid(capsule)
    chains, reasons = enumerate_chains(capsule, policy, cap)
    result = {"legal": bool(chains), "cap": cap, "chain_count": len(chains),
              "multiple_valid_chains": len(chains) > 1, "encountered_refusals": reasons}
    if chains:
        path = chains[0]
        terminal = path[-1]
        after, checks = apply_chain(capsule, path, policy, cap)
        delta = terminal[0] - grid.source[0], terminal[1] - grid.source[1]
        result.update({"minimum_chain_length": len(path) - 1, "path": [list(p) for p in path],
                       "terminal_void": list(terminal), "endpoint_distance": math.hypot(*delta),
                       "endpoint_chebyshev_distance": max(map(abs, delta)),
                       "endpoint_direction": vector_comparison(grid.normal, delta),
                       "material_sequence": [grid.row(p)[0] for p in path[:-1]],
                       "zero_dot_hops": sum(grid.normal[0] * (b[0] - a[0]) + grid.normal[1] * (b[1] - a[1]) == 0
                                             for a, b in zip(path, path[1:])),
                       "checks": checks, "after_semantic_hash": canonical_hash(after), "refusal": None})
    else:
        voids = sum(grid.void(p) for p in grid.points())
        refusal = "no_terminal_void_in_neighborhood" if voids == 0 else "no_legal_chain_within_policy_and_cap"
        if "source_not_movable" in reasons or "source_not_owned_contact" in reasons:
            refusal = next(iter(reasons))
        result.update({"minimum_chain_length": None, "path": None, "terminal_void": None,
                       "material_sequence": [], "refusal": refusal, "terminal_void_count": voids})
    result["input_nonmutation"] = before == canonical_hash(capsule)
    if not result["input_nonmutation"]:
        raise AssertionError("solver mutated capsule")
    return result


def analyze_corpus(data: dict) -> dict:
    before = canonical_hash(data)
    capsules = data["capsules"]
    rows = []
    for capsule in capsules:
        rows.append({"replay_hash": capsule["replay_hash"], "source": capsule["source"],
                     "source_material": Grid(capsule).row(tuple(capsule["source"]))[0],
                     "production_success": capsule["target"][0] >= 0,
                     "policies": {policy: {str(cap): solve(capsule, policy, cap) for cap in CAPS} for policy in POLICIES}})
    failed = [row for row in rows if not row["production_success"]]
    baseline = len(rows) - len(failed)
    policies = {}
    for policy in POLICIES:
        cumulative = {}
        for cap in CAPS:
            recovered = [row for row in failed if row["policies"][policy][str(cap)]["legal"]]
            cumulative[str(cap)] = {"unresolved_recovered": len(recovered), "unresolved_total": len(failed),
                                    "total_recovered": baseline + len(recovered), "total_contacts": len(rows),
                                    "total_fraction": (baseline + len(recovered)) / len(rows) if rows else 0,
                                    "unresolved_fraction": len(recovered) / len(failed) if failed else 0,
                                    "materials": dict(sorted(Counter(str(row["source_material"]) for row in recovered).items()))}
        policies[policy] = cumulative
    applied = [result for row in rows for policy in POLICIES for result in row["policies"][policy].values() if result["legal"]]
    report = {"schema_version": 1, "corpus_semantic_sha256": before, "baseline_direct": {"recovered": baseline, "total": len(rows),
              "fraction": baseline / len(rows) if rows else 0, "unresolved": len(failed)},
              "semantics": {"length": "moved parcels including source, hard caps1..4",
                            "neighborhood": "Stage-B interior AABB; outer ring excluded",
                            "policies": {"forward": "every unit hop dot normal >0", "forward_lateral": "every unit hop dot normal >=0; exact, no epsilon"},
                            "lateral_qualification": "a four-connected hop is exactly lateral only for axis-aligned normals; rotated nonzero components produce identical policies",
                            "conservation": "every nonempty raw-carrier/state/temperature parcel; body IDs remain positional; vacated Empty resets to ambient; Empty temperature is not a conserved parcel",
                            "native_gap": "native copied-World validation imports semantic material/state/temperature, not raw carrier epoch/spare bits"},
              "policies": policies,
              "lateral_marginal": {str(cap): policies["forward_lateral"][str(cap)]["unresolved_recovered"] - policies["forward"][str(cap)]["unresolved_recovered"] for cap in CAPS},
              "normal_geometry": {"contacts_with_both_normal_components_nonzero": sum(a["normal"][0] != 0 and a["normal"][1] != 0 for a in capsules),
                                  "contacts_admitting_exact_lateral_cardinal_hop": sum(a["normal"][0] == 0 or a["normal"][1] == 0 for a in capsules)},
              "invariants": {"copied_applications": len(applied), "conservation_failures": 0,
                             "barrier_violations": sum(result["checks"]["barrier_violations"] for result in applied),
                             "new_body_overlaps": sum(result["checks"]["new_body_overlaps"] for result in applied)},
              "source_materials": dict(sorted(Counter(str(row["source_material"]) for row in rows).items())),
              "unresolved_refusals_at_cap4": {policy: dict(sorted(Counter(row["policies"][policy]["4"]["refusal"] for row in failed if not row["policies"][policy]["4"]["legal"]).items())) for policy in POLICIES},
              "capsules": rows, "input_nonmutation": before == canonical_hash(data)}
    if not report["input_nonmutation"]:
        raise AssertionError("corpus mutated")
    return report


def _row(material: int, state_a: int = 0, state_b: int = 0, temperature: int = 200,
         body: int = 0, *, hard: bool = False, movable: bool = True, spare: int = 0) -> list:
    bits = material | state_a << 16 | state_b << 32 | spare << 40
    return [material, state_a, state_b, temperature, body, hard, movable if material else False,
            state_a if material == 3 else 0, f"{bits:016x}"]


def synthetic_cases() -> dict[str, dict]:
    def base(name: str) -> dict:
        cells = [_row(1, hard=True, movable=False) for _ in range(121)]
        result = {"schema_version": 1, "replay_hash": "synthetic_" + name, "source": [3, 5], "body_id": 1,
                  "normal": [1., 0.], "bounds": [0, 0, 11, 11], "world_bounds": [0, 0, 1024, 1024],
                  "ambient_temperature": 200, "storage_policy": "default_cellular_no_pressure_or_inertial_sidecar",
                  "cells": cells, "target": [-1, -1]}
        put(result, (3, 5), _row(2, 17, 23, 510, body=1, spare=0x5A1234))
        return result

    def put(capsule: dict, point: tuple, row: list) -> None:
        capsule["cells"][point[1] * 11 + point[0]] = row

    cases = {}
    for name in ("direct_sand", "two_sand", "water", "mixed", "hard_barrier", "foreign_body", "own_body", "immovable",
                 "jammed", "cap_overflow", "four_parcels", "rear_only", "lateral", "overlapping_paths"):
        cases[name] = base(name)
    for name in ("direct_sand", "water"):
        put(cases[name], (4, 5), _row(0, temperature=888))
    put(cases["water"], (3, 5), _row(3, 73, 11, 777, body=1, spare=0xA51234))
    put(cases["two_sand"], (4, 5), _row(2, 71, 31, -120, spare=0xF01234))
    put(cases["two_sand"], (5, 5), _row(0))
    put(cases["mixed"], (4, 5), _row(3, 73, 11, 777, spare=0xA51234))
    put(cases["mixed"], (5, 5), _row(16, 91, 13, -80, spare=0xC01234))
    put(cases["mixed"], (6, 5), _row(0))
    for name, obstacle in (("hard_barrier", _row(1, hard=True, movable=False)),
                           ("foreign_body", _row(2, body=2)), ("own_body", _row(2, body=1)),
                           ("immovable", _row(5, movable=False))):
        put(cases[name], (4, 5), obstacle)
        put(cases[name], (5, 5), _row(0))
    for name, length in (("cap_overflow", 5), ("four_parcels", 4)):
        for offset in range(1, length):
            put(cases[name], (3 + offset, 5), _row(2, offset * 7, offset, 200 + offset))
        put(cases[name], (3 + length, 5), _row(0))
    put(cases["rear_only"], (2, 5), _row(0))
    put(cases["lateral"], (3, 4), _row(0))
    for point in ((4, 5), (3, 4), (4, 4)):
        put(cases["overlapping_paths"], point, _row(2, 17, 23, 510))
    put(cases["overlapping_paths"], (5, 4), _row(0))
    return cases


def export_native_cases(data: dict, output: Path) -> int:
    """Separate copied-World oracle input; semantic tuple import is explicit."""
    inputs = [("real_" + str(i), capsule) for i, capsule in enumerate(data["capsules"])]
    inputs += [("synthetic_" + name, capsule) for name, capsule in synthetic_cases().items()]
    cases = []
    for identity, capsule in inputs:
        grid = Grid(capsule)
        for policy in POLICIES:
            for cap in CAPS:
                result = solve(capsule, policy, cap)
                if result["legal"]:
                    cases.append((identity, capsule, grid, policy, cap, result["path"]))
    lines = [f"EJECTION_CHAINS_V1 {len(cases)}"]
    for identity, capsule, grid, policy, cap, path in cases:
        lines.append(f"CASE {identity} {policy} {cap} {len(grid.cells)} {len(path)} {grid.normal[0]:.17g} {grid.normal[1]:.17g}")
        for i, row in enumerate(grid.cells):
            x, y = grid.left + i % grid.width, grid.top + i // grid.width
            lines.append(f"{x} {y} {row[0]} {row[1]} {row[2]} {row[3]} {row[4]}")
        lines.extend(f"{p[0]} {p[1]}" for p in path)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(cases)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--native-cases", type=Path)
    args = parser.parse_args()
    paths = [args.input, args.output] + ([args.native_cases] if args.native_cases else [])
    for index, left in enumerate(paths):
        for right in paths[index + 1:]:
            if left.resolve() == right.resolve() or (left.exists() and right.exists() and left.samefile(right)):
                parser.error("input, JSON output and native-case paths must be distinct; frozen input is read-only")
    input_bytes = args.input.read_bytes()
    data = json.loads(input_bytes.decode("utf-8"))
    result = analyze_corpus(data)
    result["corpus_file_sha256"] = hashlib.sha256(input_bytes).hexdigest()
    if args.input.read_bytes() != input_bytes:
        raise RuntimeError("frozen input file changed during analysis")
    if args.native_cases:
        result["native_copied_world_cases_exported"] = export_native_cases(data, args.native_cases)
    result["input_file_nonmutation"] = args.input.read_bytes() == input_bytes
    if not result["input_file_nonmutation"]:
        raise RuntimeError("frozen input file changed during native-case export")
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    if args.input.read_bytes() != input_bytes:
        raise RuntimeError("frozen input file changed during result export")
    print(json.dumps({k: v for k, v in result.items() if k not in ("capsules", "semantics")}, sort_keys=True))


if __name__ == "__main__":
    main()
