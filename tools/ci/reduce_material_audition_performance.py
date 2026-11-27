#!/usr/bin/env python3
"""Check cross-source default parity and summarize advisory audition timings."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics

SEMANTIC = ("initial_content_hash", "content_hash", "physical_hash", "physical_hash_version", "counts",
            "moved_cells", "visited_cells")


def read(path: Path) -> dict[tuple, dict]:
    rows = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        value = json.loads(line)
        if value.get("schema") != "material-audition-performance-v1":
            raise ValueError("Unexpected benchmark schema")
        key = (value["side"], value["workers"], value["ticks"], value["repeat"], value["profile"])
        if key in rows:
            raise ValueError("Duplicate benchmark sample: " + str(key))
        rows[key] = value
    if not rows:
        raise ValueError("Empty benchmark evidence")
    return rows


def summarize(baseline: Path, candidate: Path) -> dict:
    before, after = read(baseline), read(candidate)
    default_keys = set(before)
    if any(key[-1] != "default" or row.get("candidate_api") is not False for key, row in before.items()):
        raise ValueError("Baseline must execute the accepted source without an audition API")
    if set(after) != {(*key[:-1], mode) for key in default_keys for mode in ("default", "equivalent", "modified")}:
        raise ValueError("Candidate must retain every matched default, equivalent and modified arm")
    for key, reference in before.items():
        for mode in ("default", "equivalent"):
            actual = after[(*key[:-1], mode)]
            if actual.get("candidate_api") is not True or any(reference[field] != actual[field] for field in SEMANTIC):
                raise ValueError("Cross-source native parity failed: " + str(key) + "/" + mode)
        equal = after[(*key[:-1], "equivalent")]
        if equal["scanned_cells"] != 0 or equal["woken_blocks"] != 0:
            raise ValueError("Equivalent defaults unexpectedly scan or wake the World")
    groups = []
    for side, workers, ticks in sorted({key[:3] for key in default_keys}):
        controls = [row for key, row in before.items() if key[:3] == (side, workers, ticks)]
        reference_ms = statistics.median(row["elapsed_ms"] for row in controls)
        report = {"side": side, "workers": workers, "ticks": ticks, "repeats": len(controls),
                  "accepted_default_elapsed_ms": reference_ms, "arms": {}}
        for mode in ("default", "equivalent", "modified"):
            values = [row for key, row in after.items() if key[:3] == (side, workers, ticks) and key[-1] == mode]
            elapsed = statistics.median(row["elapsed_ms"] for row in values)
            report["arms"][mode] = {
                "elapsed_median_ms": elapsed,
                "elapsed_min_ms": min(row["elapsed_ms"] for row in values),
                "elapsed_max_ms": max(row["elapsed_ms"] for row in values),
                "elapsed_ratio_to_accepted_default": elapsed / reference_ms,
                "tick_median_ms": statistics.median(row["tick_median_ms"] for row in values),
                "tick_p95_ms": statistics.median(row["tick_p95_ms"] for row in values),
                "activation_median_ms": statistics.median(row["activation_ms"] for row in values),
                "scanned_cells": sorted({row["scanned_cells"] for row in values}),
                "woken_blocks": sorted({row["woken_blocks"] for row in values}),
                "observed_workers": sorted({row["observed_workers"] for row in values}),
            }
        report["modified_cell_effect_observed"] = any(
            after[(*key[:-1], "modified")]["content_hash"] != row["content_hash"]
            for key, row in before.items() if key[:3] == (side, workers, ticks))
        groups.append(report)
    return {"schema": "cybersand.material-audition.performance-summary", "schema_version": 1,
            "status": "passed", "default_cross_source_parity": True, "equivalent_default_parity": True,
            "matched_default_samples": len(before), "candidate_samples": len(after),
            "timing_status": "advisory; shared-host runtime, changed material dynamics change work volume",
            "baseline_sha256": hashlib.sha256(baseline.read_bytes()).hexdigest(),
            "candidate_sha256": hashlib.sha256(candidate.read_bytes()).hexdigest(), "groups": groups}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Choose a new output; original evidence is immutable")
    result = summarize(args.baseline, args.candidate)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "matched_default_samples": result["matched_default_samples"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
