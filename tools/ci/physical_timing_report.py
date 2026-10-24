#!/usr/bin/env python3
"""Reduce physical actor/usable/flight timing evidence; do not discard failures."""

import argparse
import csv
from collections import defaultdict
from datetime import datetime
import json
from pathlib import Path
import re
import statistics

PREFIXES = ("test_physical_actor", "test_physical_usable", "test_physical_usables", "test_physical_flight")
FIELDS = ("run_id", "run_attempt", "source_sha", "platform", "mode", "batch",
          "repetition", "test", "seconds", "status", "timeout_seconds", "last_progress", "evidence")


def percentile95(numbers: list[float]) -> float:
    values = sorted(numbers)
    return values[(95 * len(values) + 99) // 100 - 1]


def rows_from_json(path: Path, run_id: str, attempt: str) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if path.name == "windows-execution.json":
        platform = "windows"
        mode = "ci"
        source = payload.get("source_commit", "")
        rows = payload.get("results", [])
    elif path.name == "timings.json":
        platform = "linux"
        mode = "ci"
        source = payload.get("identity", {}).get("source_sha", "")
        rows = payload.get("results", [])
    elif path.name == "stress-summary.json":
        platform = "windows" if payload.get("platform") == "win32" else "linux"
        mode = "stress-" + payload.get("mode", "unknown")
        source = payload.get("source_sha", "")
        rows = payload.get("results", [])
    else:
        return []
    if not isinstance(rows, list):
        raise ValueError(f"Invalid results array: {path}")
    result = []
    for row in rows:
        if row.get("role") != "case" or not row.get("name", "").startswith(PREFIXES):
            continue
        result.append({
            "run_id": payload.get("run_id") or run_id,
            "run_attempt": payload.get("run_attempt") or attempt,
            "source_sha": source, "platform": platform, "mode": mode,
            "batch": payload.get("batch", ""),
            "repetition": row.get("repetition", ""),
            "test": row["name"], "seconds": row["seconds"],
            "status": row["status"], "timeout_seconds": row["timeout_seconds"],
            "last_progress": row.get("last_progress") or "",
            "evidence": str(path),
        })
    return result


# Historical Actions job log fallback for runs whose artifact has expired.
# These values include a small, explicit runner gap after test completion;
# prefer JSON's measured seconds whenever it is available.
START = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z) Running (\w+), timeout (\d+)s:")
STAMP = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z)")
TIMEOUT = re.compile(r"\bTIMEOUT after (\d+)s")


def historical_log_rows(path: Path, platform: str, run_id: str, attempt: str) -> list[dict]:
    rows = []
    active = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        start = START.search(line)
        stamp = STAMP.search(line)
        if start:
            if active and active["test"].startswith(PREFIXES):
                end = datetime.fromisoformat(start.group(1).replace("Z", "+00:00"))
                active["seconds"] = round((end - active.pop("_started")).total_seconds(), 3)
                rows.append(active)
            active = {
                "run_id": run_id, "run_attempt": attempt, "source_sha": "",
                "platform": platform, "mode": "historical-job-log",
                "batch": "", "repetition": "", "test": start.group(2),
                "seconds": 0, "status": "passed", "timeout_seconds": int(start.group(3)),
                "last_progress": "", "evidence": str(path),
                "_started": datetime.fromisoformat(start.group(1).replace("Z", "+00:00")),
            }
        elif active and TIMEOUT.search(line):
            active["status"] = "timeout"
        elif active and "REGRESSION_PROGRESS " in line:
            active["last_progress"] = line.split("REGRESSION_PROGRESS ", 1)[1].strip()
    # The final test has no next-start boundary; deliberately mark it unknown.
    # A missing duration must never be counted as a successful observation.
    if active and active["test"].startswith(PREFIXES):
        if active["status"] == "timeout" and stamp:
            active["seconds"] = float(active["timeout_seconds"])
            active.pop("_started")
            rows.append(active)
    return rows


def distributions(rows: list[dict]) -> list[dict]:
    groups = defaultdict(list)
    for row in rows:
        groups[(row["platform"], row["mode"], row["test"])].append(row)
    summary = []
    for (platform, mode, test), group in sorted(groups.items()):
        lengths = [float(row["seconds"]) for row in group]
        summary.append({
            "platform": platform, "mode": mode, "test": test,
            "samples": len(group), "timeouts": sum(row["status"] == "timeout" for row in group),
            "nonpassing": sum(row["status"] != "passed" for row in group),
            "median_s": round(statistics.median(lengths), 3),
            "p95_s": round(percentile95(lengths), 3), "max_s": round(max(lengths), 3),
        })
    return summary


def emit(path: Path, fieldnames: tuple[str, ...], rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path, help="recursive artifact download root")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--run-id", default="")
    parser.add_argument("--attempt", default="")
    parser.add_argument("--job-log", action="append", type=Path, default=[])
    parser.add_argument("--log-platform", choices=("linux", "windows"))
    args = parser.parse_args()
    if args.job_log and not args.log_platform:
        parser.error("--log-platform is required for historical --job-log inputs")
    files = sorted({p for filename in ("timings.json", "windows-execution.json", "stress-summary.json")
                    for p in args.root.rglob(filename)})
    rows = []
    for path in files:
        rows.extend(rows_from_json(path, args.run_id, args.attempt))
    for path in args.job_log:
        rows.extend(historical_log_rows(path, args.log_platform, args.run_id, args.attempt))
    args.output.mkdir(parents=True, exist_ok=True)
    emit(args.output / "physical-timing-records.csv", FIELDS, rows)
    summary = distributions(rows)
    fields = ("platform", "mode", "test", "samples", "timeouts", "nonpassing",
              "median_s", "p95_s", "max_s")
    emit(args.output / "physical-timing-distributions.csv", fields, summary)
    (args.output / "summary.json").write_text(
        json.dumps({"sources": [str(p) for p in files], "count": len(rows),
                    "distributions": summary}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Physical timing: {len(rows)} observations from {len(files)} JSON sources")
    return int(not rows)


if __name__ == "__main__":
    raise SystemExit(main())
