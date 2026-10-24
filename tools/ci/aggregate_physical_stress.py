#!/usr/bin/env python3
"""Require every #233 stress attempt, aggregate timings, refuse missing or failed cases."""

import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import re

from physical_timing_report import DISTRIBUTION_FIELDS, distributions, emit

CASES = ("test_physical_actor_arena", "test_physical_actor_rigs", "test_physical_usable_course")


def valid_seconds(value: object) -> bool:
    if type(value) not in (int, float):
        return False
    try:
        return math.isfinite(value) and value >= 0
    except OverflowError:
        return False


def aggregate(files: list[Path], *, batches: int, per_batch: int,
              expected_source_sha: str, expected_run_id: str,
              expected_run_attempt: str) -> tuple[list[dict], list[str]]:
    seen = Counter()
    identities = defaultdict(set)
    godot_versions = set()
    records = []
    errors = []
    for path in files:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("summary must be an object")
        except (OSError, ValueError) as error:
            errors.append(f"{path}: unreadable stress summary: {error}")
            continue
        mode, host, batch = payload.get("mode"), payload.get("platform"), payload.get("batch")
        if mode not in ("serial", "parallel") or host not in ("win32", "linux") or type(batch) is not int:
            errors.append(f"{path}: unknown platform, mode or batch")
            continue
        platform = "windows" if host == "win32" else "linux"
        if batch < 0 or batch >= batches:
            errors.append(f"{path}: invalid batch {batch}")
        seen[(platform, mode, batch)] += 1
        for field, expected in (("source_sha", expected_source_sha),
                                ("run_id", expected_run_id),
                                ("run_attempt", expected_run_attempt)):
            if payload.get(field) != expected:
                errors.append(f"{path}: {field} {payload.get(field)!r} != registered {expected!r}")
        for field, length in (("source_sha", 40), ("native_sha256", 64), ("rapier_sha256", 64)):
            value = payload.get(field)
            if not isinstance(value, str) or not re.fullmatch(f"[0-9a-f]{{{length}}}", value):
                errors.append(f"{path}: missing or invalid {field}")
        version = payload.get("godot_version")
        if not isinstance(version, str) or not version.strip():
            errors.append(f"{path}: missing Godot identity")
        # Serial and parallel modes on each OS must use the same actual binaries.
        identities[platform].add(tuple(str(payload.get(field)) for field in
                                       ("source_sha", "godot_version", "native_sha256", "rapier_sha256")))
        godot_versions.add(str(version))
        if (payload.get("cases") != list(CASES) or type(payload.get("repetitions")) is not int
                or payload.get("repetitions") != per_batch):
            errors.append(f"{path}: declared cases or repetitions differ from campaign")
        if payload.get("completed") is not True or payload.get("status") != "passed":
            errors.append(f"{path}: incomplete or failed stress batch")
        results = payload.get("results")
        if not isinstance(results, list):
            errors.append(f"{path}: missing or invalid results array")
            results = []
        rows = []
        for index, row in enumerate(results):
            if not isinstance(row, dict):
                errors.append(f"{path}: result {index} is not an object")
                continue
            rows.append(row)
            if row.get("role") not in ("case", "preflight"):
                errors.append(f"{path}: result {index} has unknown role {row.get('role')!r}")
            if row.get("status") != "passed":
                errors.append(f"{path}: {row.get('name')} repeat {row.get('repetition')}: {row.get('status')}")
            if not valid_seconds(row.get("seconds")):
                errors.append(f"{path}: {row.get('name')} has missing or invalid elapsed seconds")
        preflights = [r for r in rows if r.get("role") == "preflight"]
        if len(preflights) != 1 or preflights[0].get("name") != "import":
            errors.append(f"{path}: expected exactly one import preflight")
        case_rows = [r for r in rows if r.get("role") == "case"]
        actual = Counter()
        for row in case_rows:
            name, repetition = row.get("name"), row.get("repetition")
            if not isinstance(name, str) or type(repetition) is not int:
                errors.append(f"{path}: case has invalid name or repetition")
            else:
                actual[(name, repetition)] += 1
            if row.get("timeout_seconds") != 180:
                errors.append(f"{path}: {name} has unregistered per-test timeout {row.get('timeout_seconds')!r}")
            records.append({
                "run_id": payload.get("run_id") or "",
                "run_attempt": payload.get("run_attempt") or "",
                "source_sha": payload.get("source_sha") or "",
                "godot_version": version or "",
                "native_sha256": payload.get("native_sha256") or "",
                "rapier_sha256": payload.get("rapier_sha256") or "",
                "platform": platform, "mode": "stress-" + mode, "batch": batch,
                "repetition": repetition, "test": name if isinstance(name, str) else "invalid-evidence",
                "seconds": row.get("seconds") if valid_seconds(row.get("seconds")) else None,
                "status": row.get("status") if isinstance(row.get("status"), str) else "invalid-evidence",
                "timeout_seconds": row.get("timeout_seconds"),
                "last_progress": row.get("last_progress") or "", "evidence": str(path),
                "timing_basis": "runner-elapsed",
            })
        expected = Counter((name, batch * per_batch + offset)
                           for name in CASES for offset in range(1, per_batch + 1))
        if actual != expected:
            errors.append(f"{path}: incomplete or duplicate case repetitions")
    for platform in ("windows", "linux"):
        if len(identities[platform]) != 1:
            errors.append(f"{platform}: inconsistent runtime/source identities across all modes")
        for mode in ("serial", "parallel"):
            for batch in range(batches):
                if seen[(platform, mode, batch)] != 1:
                    errors.append(f"{platform} {mode} batch {batch}: expected one file, got {seen[(platform, mode, batch)]}")
            for name in CASES:
                sample_count = sum(
                    row["platform"] == platform and row["mode"] == "stress-" + mode and row["test"] == name
                    for row in records
                )
                if sample_count != batches * per_batch:
                    errors.append(f"{platform} {mode} {name}: {sample_count} != {batches * per_batch}")
    if len(godot_versions) != 1:
        errors.append("Stress batches disagree on Godot version")
    return records, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--expected-run-id", required=True)
    parser.add_argument("--expected-run-attempt", required=True)
    parser.add_argument("--batches", type=int, default=5)
    parser.add_argument("--per-batch", type=int, default=10)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_source_sha):
        parser.error("expected source must be a full SHA-1 commit ID")
    if not re.fullmatch(r"[0-9]+", args.expected_run_id) or not re.fullmatch(r"[1-9][0-9]*", args.expected_run_attempt):
        parser.error("expected run ID and attempt must identify one Actions campaign")
    if args.batches < 1 or args.per_batch < 1:
        parser.error("batches and per-batch must be positive")
    files = sorted(args.input.rglob("stress-summary.json"))
    records, errors = aggregate(files, batches=args.batches, per_batch=args.per_batch,
                               expected_source_sha=args.expected_source_sha,
                               expected_run_id=args.expected_run_id,
                               expected_run_attempt=args.expected_run_attempt)
    args.output.mkdir(parents=True, exist_ok=True)
    from physical_timing_report import FIELDS
    emit(args.output / "stress-observations.csv", FIELDS, records)
    summary = distributions(records)
    emit(args.output / "stress-distributions.csv", DISTRIBUTION_FIELDS, summary)
    (args.output / "stress-audit.json").write_text(
        json.dumps({"source_files": [str(path) for path in files],
                    "expected_source_sha": args.expected_source_sha,
                    "expected_run_id": args.expected_run_id,
                    "expected_run_attempt": args.expected_run_attempt,
                    "expected_case_attempts": 4 * args.batches * args.per_batch * len(CASES),
                    "observed_case_attempts": len(records),
                    "errors": errors, "distributions": summary,
                    "status": "passed" if not errors else "failed"},
                   indent=2, sort_keys=True) + "\n", encoding="utf-8",
    )
    print(json.dumps({"status": "passed" if not errors else "failed", "errors": errors,
                      "distributions": summary}, indent=2))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
