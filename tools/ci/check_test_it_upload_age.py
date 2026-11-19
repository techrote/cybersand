#!/usr/bin/env python3
"""Independently check Test It PowerShell's frame upload-age distribution against JSONL.

'upload_age_ms' is an age measured on each submitted frame; it must not reuse
texture_upload-event snapshot ages ('snapshot_age_at_upload_ms').
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from tempfile import TemporaryDirectory


def distribution(values: list[float]) -> dict | None:
    if not values:
        return None
    ordered = sorted(values)
    def quantile(p: float) -> float:
        return ordered[max(0, math.ceil(len(ordered) * p) - 1)]
    return {"count": len(values), "min": ordered[0], "p50": quantile(.5),
            "p95": quantile(.95), "p99": quantile(.99), "max": ordered[-1]}


def verify(summary_path: Path) -> tuple[int, int]:
    summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    cases = summary.get("cases", [])
    if not cases:
        raise ValueError("No completed Test It cases")
    checked = 0
    measurements = 0
    for case in cases:
        name = case["name"]
        trace = summary_path.parent / "cases" / name / "receipt-poses.jsonl"
        if not trace.is_file():
            raise ValueError(f"{name}: missing raw trace {trace}")
        values: list[float] = []
        with trace.open(encoding="utf-8-sig") as stream:
            for line in stream:
                if not line.strip():
                    continue
                row = json.loads(line)
                if row.get("type") != "frame":
                    continue
                timing = (row.get("presentation") or {}).get("material_timing") or {}
                age = timing.get("upload_age_usec")
                if age is not None and isinstance(age, (int, float)) and age >= 0:
                    values.append(float(age) / 1000.0)
        expected = distribution(values)
        actual = case["statistics"]["delivery_timing"]["upload_age_ms"]
        if (actual is None) != (expected is None):
            raise ValueError(f"{name}: raw frame availability differs from reported upload age")
        if expected is not None:
            for key in ("count", "min", "p50", "p95", "p99", "max"):
                if not math.isclose(float(actual[key]), float(expected[key]),
                                    rel_tol=0.0, abs_tol=1e-6):
                    raise ValueError(f"{name}: {key} is {actual[key]}, raw frames require {expected[key]}")
            measurements += len(values)
        checked += 1
    if measurements == 0:
        raise ValueError("No per-frame upload-age observations to validate")
    return checked, measurements


def self_test() -> None:
    with TemporaryDirectory() as directory:
        root = Path(directory)
        case_dir = root / "cases" / "synthetic"
        case_dir.mkdir(parents=True)
        rows = [{"type": "frame", "presentation": {"material_timing": {"upload_age_usec": v}}}
                for v in (1000, 4000, 2500)]
        rows.append({"type": "event", "event": "texture_upload",
                     "generated_usec": 0, "completed_usec": 100000})
        (case_dir / "receipt-poses.jsonl").write_text(
            "".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
        summary = {"cases": [{"name": "synthetic", "statistics": {"delivery_timing": {
            "upload_age_ms": distribution([1.0, 4.0, 2.5])}}}]}
        path = root / "summary.json"
        path.write_text(json.dumps(summary), encoding="utf-8")
        assert verify(path) == (1, 3)
        summary["cases"][0]["statistics"]["delivery_timing"]["upload_age_ms"] = distribution([100.0])
        path.write_text(json.dumps(summary), encoding="utf-8")
        try:
            verify(path)
        except ValueError:
            pass
        else:
            raise AssertionError("Event snapshot-age substitution passed the negative control")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path, nargs="?")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("TEST_IT_UPLOAD_AGE_SELF_TEST PASS (positive and event-age negative control)")
    else:
        if args.summary is None:
            parser.error("summary.json is required outside --self-test")
        cases, ages = verify(args.summary)
        print(f"TEST_IT_UPLOAD_AGE PASS cases={cases} frame_age_observations={ages}")


if __name__ == "__main__":
    main()
