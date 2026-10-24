#!/usr/bin/env python3
"""Require every #233 stress attempt, aggregate timings, refuse missing or failed cases."""

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

from physical_timing_report import distributions, emit


def aggregate(files: list[Path], *, batches: int, per_batch: int) -> tuple[list[dict], list[str]]:
    expected_cases = ("test_physical_actor_arena", "test_physical_actor_rigs", "test_physical_usable_course")
    seen = Counter()
    identities = defaultdict(set)
    records = []
    errors = []
    sources = set()
    for path in files:
        payload = json.loads(path.read_text(encoding="utf-8"))
        mode, host, batch = payload.get("mode"), payload.get("platform"), payload.get("batch")
        if mode not in ("serial", "parallel") or host not in ("win32", "linux") or not isinstance(batch, int):
            errors.append(f"{path}: unknown platform, mode or batch")
            continue
        platform = "windows" if host == "win32" else "linux"
        key = (platform, mode)
        if batch < 0 or batch >= batches:
            errors.append(f"{path}: invalid batch {batch}")
        seen[(platform, mode, batch)] += 1
        identities[key].add((payload.get("source_sha"), payload.get("godot_version"),
                             payload.get("native_sha256"), payload.get("rapier_sha256")))
        sources.add(payload.get("source_sha"))
        if not payload.get("completed") or payload.get("status") != "passed":
            errors.append(f"{path}: incomplete or failed stress batch")
        case_rows = [r for r in payload.get("results", []) if r.get("role") == "case"]
        actual = Counter((r.get("name"), r.get("repetition")) for r in case_rows)
        expected = Counter((name, batch * per_batch + offset)
                           for name in expected_cases for offset in range(1, per_batch + 1))
        if actual != expected:
            errors.append(f"{path}: incomplete or duplicate case repetitions")
        for row in case_rows:
            if row.get("status") != "passed":
                errors.append(f"{path}: {row.get('name')} repeat {row.get('repetition')}: {row.get('status')}")
            records.append({
                "run_id": payload.get("run_id") or "",
                "run_attempt": payload.get("run_attempt") or "",
                "source_sha": payload.get("source_sha") or "",
                "platform": platform, "mode": "stress-" + mode, "batch": batch,
                "repetition": row.get("repetition"), "test": row.get("name"),
                "seconds": row.get("seconds", 0), "status": row.get("status"),
                "timeout_seconds": row.get("timeout_seconds"),
                "last_progress": row.get("last_progress") or "", "evidence": str(path),
            })
    for platform in ("windows", "linux"):
        for mode in ("serial", "parallel"):
            for batch in range(batches):
                if seen[(platform, mode, batch)] != 1:
                    errors.append(f"{platform} {mode} batch {batch}: expected one file, got {seen[(platform, mode, batch)]}")
            if len(identities[(platform, mode)]) != 1:
                errors.append(f"{platform} {mode}: inconsistent runtime/source identities")
            for name in expected_cases:
                sample_count = sum(
                    row["platform"] == platform and row["mode"] == "stress-" + mode and row["test"] == name
                    for row in records
                )
                if sample_count != batches * per_batch:
                    errors.append(f"{platform} {mode} {name}: {sample_count} != {batches * per_batch}")
    if len(sources) != 1 or None in sources or "" in sources:
        errors.append("Stress batches disagree on source SHA")
    return records, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--batches", type=int, default=5)
    parser.add_argument("--per-batch", type=int, default=10)
    args = parser.parse_args()
    files = sorted(args.input.rglob("stress-summary.json"))
    records, errors = aggregate(files, batches=args.batches, per_batch=args.per_batch)
    args.output.mkdir(parents=True, exist_ok=True)
    from physical_timing_report import FIELDS
    emit(args.output / "stress-observations.csv", FIELDS, records)
    summary = distributions(records)
    emit(args.output / "stress-distributions.csv",
         ("platform", "mode", "test", "samples", "timeouts", "nonpassing",
          "median_s", "p95_s", "max_s"), summary)
    (args.output / "stress-audit.json").write_text(
        json.dumps({"source_files": [str(path) for path in files],
                    "errors": errors, "distributions": summary,
                    "status": "passed" if not errors else "failed"},
                   indent=2, sort_keys=True) + "\n", encoding="utf-8",
    )
    print(json.dumps({"status": "passed" if not errors else "failed", "errors": errors,
                      "distributions": summary}, indent=2))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
