#!/usr/bin/env python3
"""Reproduce registered offline preparation. Python 3.10+, standard library only.

Run from any directory: python path/to/precompute.py --out OUTPUT_DIRECTORY
Outputs are deterministic compact evidence, not engine or graphics benchmarks.
"""
from __future__ import annotations
import argparse
from collections import Counter
import csv
from dataclasses import asdict
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import platform
from typing import Any

from policy import WaterPolicy, PresentationPolicy, quantize, canonical_json, digest, lateral_pair, visible_level, projected_condition
from geometry import normals, intercept, clip, area, sample
from transfer_model import explore

BASE = "d39e31f03f2e39b0022d507b79fbee5c2439436d"
REGISTRATION = "aaa811ea6e0a76811999ee95eb93312b78bf7a74"
SEED = 20260912


def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        raise ValueError("empty output table")
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def arithmetic(out: Path) -> dict:
    rows, vectors, coverage = [], [], []
    counts = Counter()
    for bits in range(3, 9):
        reference = WaterPolicy(mass_bits=bits)
        maximum = reference.maximum
        errors = []
        for n in range(256):
            q = quantize(n, 255, maximum)
            error = Fraction(q, maximum) - Fraction(n, 255)
            assert abs(error) <= Fraction(1, 2 * maximum)
            assert 0 <= q <= maximum
            errors.append(error)
            counts["byte_normalized_inputs"] += 1
        # Halfway values deliberately stress the exact rounding rule.
        for k in range(maximum):
            assert quantize(2 * k + 1, 2 * maximum, maximum) == k + 1
            counts["halfway_inputs"] += 1
        rows.append({"mass_bits": bits, "maximum": maximum, "film": reference.film,
                     "normalized_tolerance": reference.tolerance, "literal_tolerance": 1,
                     "one_over_255_input_units": quantize(1, 255, maximum),
                     "max_input_error": str(max(map(abs, errors))),
                     "mean_input_error": str(sum(errors) / len(errors)),
                     "positive_byte_inputs_quantized_to_empty": sum(quantize(n, 255, maximum) == 0 for n in range(1, 256))})
        for rest in ("normalized", "literal_one"):
            policy = WaterPolicy(mass_bits=bits, rest_policy=rest)
            for a in range(maximum + 1):
                for b in range(maximum + 1):
                    aa, bb, moved = lateral_pair(a, b, policy)
                    assert aa + bb == a + b
                    assert 0 <= aa <= maximum and 0 <= bb <= maximum
                    assert 0 <= moved <= a
                    counts["local_pair_cases"] += 1
            for duration in range(13):
                p = WaterPolicy(mass_bits=bits, coherence_ticks=duration, rest_policy=rest)
                assert WaterPolicy.from_json(canonical_json(p.record())) == p
                vectors.append({"policy": p.record(), "mass_max": maximum, "film": p.film,
                                "tolerance": p.tolerance, "semantic_sha256": p.identity()})
        for method in ("nearest", "positive_nearest", "ceiling"):
            errors = [visible_level(m, maximum, method) - Fraction(m, maximum) for m in range(1, maximum + 1)]
            coverage.append({"mass_bits": bits, "method": method, "nonempty_levels": "1/4;1/2;3/4;1",
                             "positive_mass_states": maximum,
                             "hidden_positive_states": sum(visible_level(m, maximum, method) == 0 for m in range(1, maximum + 1)),
                             "max_absolute_area_error": str(max(map(abs, errors))),
                             "mean_signed_area_error": str(sum(errors) / maximum),
                             "one_unit_area_multiplier": str(visible_level(1, maximum, method) * maximum)})
    # Countdown semantics: suppression is tested BEFORE decrement.
    for duration in range(13):
        for initial in range(duration + 1):
            delay = initial
            suppressed = 0
            for _ in range(duration + 2):
                was_suppressed = delay > 0
                delay = max(0, delay - 1)
                suppressed += was_suppressed
            assert suppressed == initial and delay == 0
            counts["countdown_cases"] += 1
        for a in range(duration + 1):
            for b in range(duration + 1):
                merged = max(a, b)
                assert (merged & 15) == merged <= duration
                counts["delay_merge_cases"] += 1
    counts["legal_policy_vectors"] = len(vectors)
    write_csv(out / "quantization.csv", rows)
    write_csv(out / "coverage.csv", coverage)
    write_json(out / "policy-vectors.json", {"schema": 1, "kind": "standalone-reference", "vectors": vectors})
    return {"counts": dict(counts), "status": "all assertions passed",
            "scope": "registered rational arithmetic and local pair operation, not World::tick"}


def geometric(out: Path) -> dict:
    table, samples = [], []
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1050" height="540" viewBox="0 0 1050 540">',
           '<rect width="1050" height="540" fill="white"/>',
           '<text x="16" y="25" font-family="sans-serif" font-size="16">Synthetic half-plane coverage atlas — not a game screenshot</text>']
    errors = []
    for i, (nx, ny) in enumerate(normals()):
        x, y = 16 + (i % 8) * 130, 55 + (i // 8) * 245
        svg.append(f'<text x="{x}" y="{y}" font-family="sans-serif" font-size="12">normal {i * 22.5:g}°</text>')
        for level in range(1, 5):
            fraction = level / 4
            alpha = intercept(nx, ny, fraction)
            polygon = clip(nx, ny, alpha)
            actual = area(polygon)
            error = abs(actual - fraction)
            assert error < 1e-12
            errors.append(error)
            assert abs(actual + area(clip(-nx, -ny, -alpha)) - 1) < 1e-12
            table.append({"normal_index": i, "nx": nx, "ny": ny, "level": level,
                          "coverage": fraction, "alpha": alpha, "area": actual,
                          "absolute_area_error": error})
            for size in (1, 4, 8):
                for phase in (.125, .5, .875):
                    raster = sample(nx, ny, alpha, size, phase)
                    samples.append({"normal_index": i, "level": level, "grid": size, "phase": phase,
                                    "geometric_area": fraction, "sampled_area": raster,
                                    "absolute_sampling_error": abs(raster - fraction)})
            yy = y + 12 + (level - 1) * 48
            points = " ".join(f"{x + (px + .5) * 40:.5f},{yy + (py + .5) * 40:.5f}" for px, py in polygon)
            svg.append(f'<rect x="{x}" y="{yy}" width="40" height="40" fill="none" stroke="black"/>')
            svg.append(f'<polygon points="{points}"/>')
            svg.append(f'<text x="{x+48}" y="{yy+26}" font-family="sans-serif" font-size="12">{level}/4</text>')
    svg.append('</svg>')
    (out / "interface-atlas.svg").write_text("\n".join(svg) + "\n", encoding="utf-8")
    write_csv(out / "interface-lut.csv", table)
    # Aggregate without discarding worst cases; full small sample matrix retained.
    write_csv(out / "sampling.csv", samples)
    return {"normal_count": 16, "lookup_rows": len(table), "raster_cases": len(samples),
            "max_geometric_error": max(errors),
            "max_sample_error_by_grid": {str(g): max(r["absolute_sampling_error"] for r in samples if r["grid"] == g) for g in (1, 4, 8)},
            "scope": "double-precision square clipping and point samples; no shader, temporal sequence, GPU or native snapshot test"}


def storage(out: Path) -> dict:
    cells = 1024 * 1024
    block_cells = 32 * 32
    blocks = cells // block_cells
    # Explicit hypothetical layout; NOT sizeof of any engine sidecar.
    payload, header, directory_entry = 2, 32, 8
    block_bytes = block_cells * payload + header
    rows = []
    for p in (0, .0001, .001, .01, .05, .15, .5, 1):
        used = math.floor(cells * p + .5)
        iid_probability = 1.0 if p == 1 else -math.expm1(block_cells * math.log1p(-p))
        packed_blocks = math.ceil(used / block_cells)
        dispersed_blocks = min(used, blocks)  # constructive one-per-block worst case, then fill.
        rows.append({"cell_density": p, "rounded_used_cells": used,
                     "iid_expected_touched_blocks": iid_probability * blocks,
                     "iid_touched_block_fraction": iid_probability,
                     "clustered_min_touched_blocks": packed_blocks,
                     "dispersed_max_touched_blocks": dispersed_blocks,
                     "directory_bytes": blocks * directory_entry,
                     "clustered_extra_bytes": blocks * directory_entry + packed_blocks * block_bytes,
                     "iid_expected_extra_bytes": blocks * directory_entry + iid_probability * blocks * block_bytes,
                     "dispersed_max_extra_bytes": blocks * directory_entry + dispersed_blocks * block_bytes,
                     "universal_4_to_8_extra_bytes": 4 * cells})
    write_csv(out / "storage.csv", rows)
    return {"scope": "analytic allocation footprint only; no lookup/cache/allocator/performance measurements",
            "resident_cells": cells, "block_cells": block_cells, "resident_blocks": blocks,
            "assumed_payload_bytes_per_reserved_cell": payload, "assumed_header_bytes_per_allocated_block": header,
            "assumed_directory_entry_bytes_per_resident_block": directory_entry,
            "excludes": ["allocator overhead", "sparse indices", "queue storage", "snapshots", "history transfers", "CPU work"],
            "one_percent_iid_touched_fraction": next(r["iid_touched_block_fraction"] for r in rows if r["cell_density"] == .01)}


def balanced_orders(n: int) -> list[list[int]]:
    """Even-n Williams order: each position and directed adjacency balanced once."""
    if type(n) is not int or n < 2 or n % 2:
        raise ValueError("even candidate count >=2 required")
    first, lo, hi = [0], 1, n - 1
    while len(first) < n:
        first.append(lo)
        lo += 1
        if len(first) < n:
            first.append(hi)
            hi -= 1
    result = [[(v + row) % n for v in first] for row in range(n)]
    assert all(Counter(row[col] for row in result) == Counter(range(n)) for col in range(n))
    adjacent = Counter((a, b) for row in result for a, b in zip(row, row[1:]))
    assert len(adjacent) == n * (n - 1) and set(adjacent.values()) == {1}
    return result


def fixture(name: str) -> dict:
    # Geometry recipe, not a Godot scene or accepted material-ID mapping.
    width, height = 50, 48
    barriers = {(x, y) for x in range(width) for y in range(height)
                if x in (0, width - 1) or y in (0, height - 1)}
    water: list[tuple[int, int, int, int]]
    events = []
    if name == "basin48":
        water = [(x, y, 1, 1) for x in range(1, 13) for y in range(15, 47)]
    elif name == "supported-film":
        water = [(12, 46, 48, 255)]
    elif name == "support-removal":
        barriers.update((x, 23) for x in range(1, 49))
        water = [(12, 22, 1, 1)]
        events = [{"before_tick": 601, "action": "remove_barrier", "cells": [[x, 23] for x in range(1, 49)]}]
    elif name == "ledge":
        barriers.update((x, 23) for x in range(1, 25))
        water = [(x, y, 1, 1) for x in range(17, 25) for y in range(15, 23)]
    elif name == "tiny-inputs":
        water = [(5 + 6 * i, 46, n, 255) for i, n in enumerate((1, 2, 4, 8, 16, 48, 128))]
        # Independent chambers suppress inter-lane transport in an eventual interpreter.
        for i in range(1, 7):
            barriers.update((2 + 6 * i, y) for y in range(1, 47))
    else:
        raise ValueError(name)
    positions = [(x, y) for x, y, _, _ in water]
    assert len(positions) == len(set(positions)) and not set(positions) & barriers
    requested = sum((Fraction(n, d) for _, _, n, d in water), Fraction(0))
    record = {"schema": 1, "scenario_id": name, "extent": [width, height], "seed": SEED,
              "barriers": [list(v) for v in sorted(barriers)],
              "water": [{"x": x, "y": y, "numerator": n, "denominator": d} for x, y, n, d in water],
              "scheduled_events": events, "requested_initial_volume": str(requested),
              "camera": {"center": [25, 24], "reset_required": True},
              "boundary_mapping": "hard barrier role; implementation must map to verified nonreactive native material",
              "scope": "deterministic geometric input; not an executed native fixture"}
    record["recipe_sha256"] = digest(record)
    record["initial_ledgers"] = [{"mass_bits": b, "integer_quantity": sum(quantize(n, d, (1 << b) - 1) for _, _, n, d in water),
                                  "initial_quantization_error": str(Fraction(sum(quantize(n, d, (1 << b) - 1) for _, _, n, d in water), (1 << b) - 1) - requested)}
                                 for b in range(3, 9)]
    return record


def apparatus(out: Path) -> dict:
    axes = {"mass": [WaterPolicy(mass_bits=b) for b in range(3, 9)],
            "coherence": [WaterPolicy(coherence_ticks=d) for d in (0, 3, 7, 12)]}
    hidden, visible = {}, {}
    for axis, candidates in axes.items():
        # Stable deterministic shuffle; blinding is UI concealment, not cryptographic secrecy.
        candidates = sorted(candidates, key=lambda p: digest({"seed": SEED, "axis": axis, "policy": p.record()}))
        labels = [chr(65 + i) for i in range(len(candidates))]
        hidden[axis] = {label: {"policy": p.record(), "semantic_sha256": p.identity()}
                        for label, p in zip(labels, candidates)}
        visible[axis] = {"orders": [[labels[i] for i in row] for row in balanced_orders(len(candidates))],
                         "scenario_and_seed_fixed_within_block": True,
                         "presentation": asdict(PresentationPolicy()),
                         "status": "preparation example; not a conducted or authorized human study"}
    write_json(out / "blind-key.example.json", {"seed": SEED, "hidden_mapping": hidden,
                "warning": "Do not expose this mapping, policy hash or reveal-bearing logs in the blinded UI."})
    write_json(out / "candidate-orders.json", visible)
    recipes = [fixture(name) for name in ("basin48", "supported-film", "support-removal", "ledge", "tiny-inputs")]
    write_json(out / "recipes.json", recipes)
    families = [
        ("pooling", ["broad shallow", "deep", "wide calm", "connected unequal levels"]),
        ("small-quantity", ["isolated fractions", "repeated tiny drips", "low-flow trickle", "residual pockets"]),
        ("geometry", ["narrow/broad channel", "stairs", "U-vessel", "nozzle", "irregular slope"]),
        ("release", ["reservoir dump", "slow gate", "fall", "ledge sheet", "thin stream", "shower"]),
        ("direction", ["vertical jet", "horizontal emission", "diagonal emission"]),
        ("terrain", ["excavate/refill", "remove support", "cavity drain", "real void", "thin barrier"]),
        ("material", ["Water/Sand Baseline", "deposition", "separate Mercury reference"]),
        ("player-body", ["source-supported player disturbance", "body displacement only after prerequisite check"]),
        ("boundary", ["supported film", "underside", "side", "droplet across positive and negative seams"]),
        ("long-tail", ["rest", "micro-motion", "crawl/stick", "abrupt stop", "repeat reset"])]
    write_json(out / "scenario-coverage.json", {"status": "implementation checklist, not completed scenes",
                "geometric_recipes_available": [r["scenario_id"] for r in recipes],
                "families": [{"family": name, "required_cases": cases, "native_run": False, "walkthrough": False} for name, cases in families]})
    return {"mass_orders": 6, "coherence_orders": 4, "distinct_semantic_candidates": 9,
            "position_and_directed_adjacency_balanced_within_each_axis": True,
            "geometric_recipes": len(recipes), "human_observations": 0,
            "warning": "not H-ready; fixtures are unexecuted interpreter-neutral geometry"}


def projection(out: Path) -> dict:
    rows = []
    for bits in range(3, 9):
        policy = WaterPolicy(mass_bits=bits)
        maximum = policy.maximum
        roundtrip = mismatch = 0
        for mass in range(maximum + 1):
            byte = projected_condition(mass, policy)
            roundtrip += quantize(byte, 255, maximum) != mass
            for method in ("nearest", "positive_nearest", "ceiling"):
                mismatch += visible_level(mass, maximum, method) != visible_level(byte, 255, method)
        assert roundtrip == 0 and projected_condition(maximum, policy) == 255
        rows.append({"mass_bits": bits, "states": maximum + 1,
                     "roundtrip_failures": roundtrip, "coverage_mismatches": mismatch,
                     "full_condition_byte": projected_condition(maximum, policy)})
    write_csv(out / "projection.csv", rows)
    return {"states": sum(row["states"] for row in rows),
            "coverage_comparisons": 3 * sum(row["states"] for row in rows),
            "roundtrip_failures": sum(row["roundtrip_failures"] for row in rows),
            "coverage_mismatches": sum(row["coverage_mismatches"] for row in rows),
            "scope": "proposed normalized display byte; never a material mutation or tested native bridge"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    summary = {"schema": 1, "date": "2026-09-12", "base_source": BASE, "registration_commit": REGISTRATION,
               "engine_execution": False, "arithmetic": arithmetic(out), "geometry": geometric(out),
               "storage": storage(out), "apparatus": apparatus(out), "projection": projection(out)}
    model = [explore(capacity) for capacity in (1, 2)]
    model += [explore(2, mutant=variant) for variant in ("early_release", "duplicate_owner", "drop_on_full", "stale_ack")]
    assert all(row["counterexample"] is None and not row["state_limit_hit"] for row in model[:2])
    assert all(row["counterexample"] for row in model[2:])
    write_json(out / "transfer-model.json", model)
    summary["transfer_model"] = model
    extended = [explore(capacity, depth=64) for capacity in (1, 2)]
    assert all(row["counterexample"] is None and not row["state_limit_hit"] for row in extended)
    write_json(out / "transfer-model-extended.json", extended)
    summary["transfer_model_extended"] = extended
    write_json(out / "summary.json", summary)
    sources = sorted(p for p in Path(__file__).parent.iterdir() if p.suffix in (".py", ".cpp"))
    outputs = sorted(p for p in out.iterdir() if p.is_file() and p.name != "manifest.json")
    manifest = {"schema": 1, "base_source": BASE, "registration_commit": REGISTRATION,
                "python": platform.python_version(), "platform": platform.platform(),
                "source_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
                "output_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in outputs},
                "engine_artifact": None, "gpu": None, "engine_tests_run": False,
                "source_identity_is_research_code_not_engine_build": True}
    write_json(out / "manifest.json", manifest)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
