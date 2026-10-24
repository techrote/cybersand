#!/usr/bin/env python3
"""Independent readback for an admitted MAT-003 S2A paired timing collection."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def nearest_rank(values: list[int], p: float) -> int:
    ordered = sorted(values)
    require(bool(ordered), "empty timing sample")
    rank = max(1, math.ceil(p * len(ordered)))
    return ordered[rank - 1]


def timing_stats(values: list[int]) -> dict:
    require(bool(values), "empty timing sample")
    total = sum(values)
    return {
        "count": len(values), "total_ns": total, "mean_ns": total / len(values),
        "p50_ns": nearest_rank(values, 0.50), "p95_ns": nearest_rank(values, 0.95),
        "p99_ns": nearest_rank(values, 0.99), "max_ns": max(values)
    }


def schedule(reg: dict) -> list[dict]:
    rows: list[dict] = []
    ordinal = 0
    for contrast in reg["contrasts"]:
        anchor = reg["anchors"][contrast["anchor"]]
        for pair_index, order in enumerate(reg["pair_orders"]):
            arms = (contrast["a"], contrast["b"]) if order == "AB" else (contrast["b"], contrast["a"])
            for within_pair, arm in enumerate(arms):
                ordinal += 1
                rows.append({
                    "ordinal": ordinal, "contrast_id": contrast["id"],
                    "pair_index": pair_index, "pair_order": order,
                    "within_pair": within_pair,
                    "role": "A" if arm == contrast["a"] else "B",
                    "arm_id": arm, "anchor_key": contrast["anchor"], **anchor
                })
    return rows


def qualifier_values(apparatus: Path) -> dict[tuple[str, str], dict]:
    run = json.loads((apparatus / "run.json").read_text())
    values: dict[tuple[str, str], dict] = {}
    for row in run["qualification_cases"]:
        receipt = row["receipt"]
        values[(row["arm_id"], row["anchor_key"])] = json.loads(
            (apparatus / receipt["stdout"]).read_text())
    return values


def verify(root: Path, apparatus: Path) -> dict:
    root = root.resolve()
    apparatus = apparatus.resolve()
    errors: list[str] = []
    checked_files: list[str] = []
    checked_processes: list[str] = []
    try:
        run = json.loads((root / "run.json").read_text())
        reg = json.loads((Path(__file__).resolve().parent / "registration.json").read_text())
        require(reg["status"] == "admitted-paired-timing" and
                reg["formal_timing_admitted"] is True and
                reg["performance_comparisons_admitted"] is True,
                "current S2A registration is not admitted")
        require(run["status"] == "passed" and run["errors"] == [] and
                run["formal_timing_admitted"] is True and
                run["performance_comparisons_admitted"] is True,
                "S2A timing collection did not pass admitted state")
        require(run["registration_sha256"] ==
                digest(Path(__file__).resolve().parent / "registration.json"),
                "S2A timing collection registration identity changed")

        for rel, receipt in run["files"].items():
            item = Path(rel)
            require(not item.is_absolute() and ".." not in item.parts,
                    "path traversal in S2A timing evidence")
            path = root / item
            require(path.is_file() and path.stat().st_size == receipt["bytes"] and
                    digest(path) == receipt["sha256"],
                    "missing/changed S2A timing evidence: " + rel)
            checked_files.append(rel)

        apparatus_run = json.loads((apparatus / "run.json").read_text())
        readback = json.loads((apparatus / "independent-readback.json").read_text())
        require(apparatus_run["status"] == "passed-apparatus-qualification" and
                readback["status"] == "passed",
                "S2A apparatus prerequisite is not passed")
        admission = reg["admission_evidence"]
        require(digest(apparatus / "run.json") == admission["run_json_sha256"] and
                digest(apparatus / "independent-readback.json") == admission["readback_sha256"] and
                digest(apparatus / "sealed-binaries.json") == admission["sealed_binaries_sha256"],
                "S2A admitted apparatus identities changed")

        expected = schedule(reg)
        require(len(expected) == 224 and len(run["schedule"]) == 224 and
                len(run["processes"]) == 224,
                "S2A timing matrix is not exactly 224 processes")
        require(run["schedule"] == expected, "S2A timing schedule changed from registration")
        qvalues = qualifier_values(apparatus)

        process_values: dict[tuple[str, int, str], dict] = {}
        semantic_fields = (
            "scenario", "side", "workers_configured", "seed", "warmup_ticks",
            "sample_ticks", "completed_ticks", "resident_cells", "chunk_count",
            "positive_visit_ticks", "warmup_input_calls", "sample_input_calls",
            "warmup_water_added", "warmup_water_removed", "sample_water_added",
            "sample_water_removed", "initial_water_mass", "final_water_mass",
            "content_hash", "state_hash", "cell_stride", "cell_alignment",
            "epoch_bits", "summary", "clear_ticks", "visits", "phase_jobs"
        )

        for expected_row, row in zip(expected, run["processes"]):
            for key, value in expected_row.items():
                require(row[key] == value,
                        f'process {expected_row["ordinal"]}: schedule field changed: {key}')
            receipt = row["receipt"]
            require(receipt["exit_code"] == 0 and receipt["timed_out"] is False,
                    f'process {row["ordinal"]}: failed/timed out')
            require((root / receipt["stderr"]).read_bytes().strip() == b"",
                    f'process {row["ordinal"]}: stderr not empty')
            value = json.loads((root / receipt["stdout"]).read_text())
            require(value["status"] == "passed" and value["mode"] == "measure" and
                    value["performance_qualification"] is True and
                    value["formal_timing_admitted"] is False,
                    f'process {row["ordinal"]}: malformed measurement result')
            tick_ns = value["tick_ns"]
            input_ns = value["input_ns"]
            require(len(tick_ns) == 256 and len(input_ns) == 256 and
                    all(type(x) is int and x >= 0 for x in tick_ns + input_ns),
                    f'process {row["ordinal"]}: invalid timing samples')
            qualifier = qvalues[(row["arm_id"], row["anchor_key"])]
            for field in semantic_fields:
                require(value[field] == qualifier[field],
                        f'process {row["ordinal"]}: diverges from untimed qualifier: {field}')
            process_values[(row["contrast_id"], row["pair_index"], row["role"])] = {
                "value": value, "tick_stats": timing_stats(tick_ns),
                "input_stats": timing_stats(input_ns)
            }
            checked_processes.append(str(row["ordinal"]))

        require(len(run["contrasts"]) == 16, "S2A contrast summary count changed")
        summary_by_id = {row["id"]: row for row in run["contrasts"]}
        for contrast in reg["contrasts"]:
            reported = summary_by_id[contrast["id"]]
            require(reported["a"] == contrast["a"] and reported["b"] == contrast["b"] and
                    reported["anchor"] == contrast["anchor"] and len(reported["pairs"]) == 7,
                    contrast["id"] + ": malformed contrast summary")
            ratios: list[float] = []
            for pair_index, order in enumerate(reg["pair_orders"]):
                a = process_values[(contrast["id"], pair_index, "A")]
                b = process_values[(contrast["id"], pair_index, "B")]
                ratio = b["tick_stats"]["mean_ns"] / a["tick_stats"]["mean_ns"]
                ratios.append(ratio)
                pair = reported["pairs"][pair_index]
                require(pair["pair_index"] == pair_index and pair["order"] == order and
                        pair["a_tick_stats"] == a["tick_stats"] and
                        pair["b_tick_stats"] == b["tick_stats"] and
                        pair["a_input_stats"] == a["input_stats"] and
                        pair["b_input_stats"] == b["input_stats"] and
                        pair["b_over_a_mean_tick_ratio"] == ratio,
                        contrast["id"] + f": pair {pair_index} reduction mismatch")
            median = statistics.median(ratios)
            deviations = [abs(x - median) for x in ratios]
            expected_summary = {
                "ratios": ratios, "median": median, "min": min(ratios),
                "max": max(ratios),
                "median_absolute_deviation": statistics.median(deviations)
            }
            require(reported["ratio_summary"] == expected_summary,
                    contrast["id"] + ": ratio summary mismatch")
    except (OSError, ValueError, KeyError, TypeError, IndexError, ZeroDivisionError) as exc:
        errors.append(str(exc))
    return {
        "stage": "S2A-paired-performance-readback",
        "status": "passed" if not errors else "failed",
        "checked_file_count": len(checked_files),
        "checked_process_count": len(checked_processes),
        "errors": errors
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--apparatus", required=True, type=Path)
    args = parser.parse_args()
    result = verify(args.root, args.apparatus)
    print(json.dumps(result, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
