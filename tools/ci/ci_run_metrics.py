#!/usr/bin/env python3
"""Reproduce Actions scheduling metrics from a complete, single-attempt job inventory.

Use authenticated gh for collection; raw API responses stay in --raw-directory.
The compact report retains timestamps and step costs but no runner names or URLs
containing signed credentials. Queue timestamps cannot separate matrix admission,
GitHub dispatch and account capacity; this tool deliberately makes no such claim.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess

SCHEMA = "github-actions-scheduling-v1"


def stamp(value: str | None) -> float | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parsed.timestamp() if parsed.tzinfo is not None else None
    except ValueError:
        return None


def elapsed(start: str | None, end: str | None) -> float | None:
    a, b = stamp(start), stamp(end)
    return round(b - a, 3) if a is not None and b is not None and b >= a else None


def distribution(values: list[float]) -> dict:
    values = sorted(values)
    if not values:
        return {"count": 0, "median": None, "p95": None, "max": None, "total": 0}
    # Nearest-rank p95; no interpolation implies nonexistent measurements.
    import math
    return {"count": len(values), "median": round(statistics.median(values), 3),
            "p95": values[math.ceil(.95 * len(values)) - 1], "max": values[-1],
            "total": round(sum(values), 3)}


def platform_group(name: str) -> str:
    if re.fullmatch(r"windows headless regression shard \d+", name):
        return "windows_regression"
    if re.fullmatch(r"linux regression shard \d+", name):
        return "linux_regression"
    return "other"


def step_phase(name: str) -> str:
    if name.startswith(("Run isolated regression shard", "Verify retained runtime and execute")):
        return "regression_step"
    if name.startswith(("Retain", "Post ", "Complete job")):
        return "publication_and_teardown"
    return "preparation_and_controls"


def peak_active(jobs: list[dict]) -> int:
    events = []
    for job in jobs:
        if job.get("conclusion") == "skipped":
            continue
        a, b = stamp(job.get("started_at")), stamp(job.get("completed_at"))
        if a is not None and b is not None and b > a:
            events.extend(((a, 1), (b, -1)))
    active = peak = 0
    # End-before-start tie handling gives half-open intervals [start,end).
    for _, change in sorted(events):
        active += change
        peak = max(peak, active)
    return peak


def flatten_pages(pages: list[dict], key: str) -> list[dict]:
    if not pages or any(not isinstance(p.get(key), list) for p in pages):
        raise ValueError("Missing or malformed paginated inventory")
    rows = [row for page in pages for row in page[key]]
    ids = [row.get("id") for row in rows]
    totals = {page.get("total_count") for page in pages}
    if None in ids or len(set(ids)) != len(ids):
        raise ValueError("Duplicate or missing IDs in paginated inventory")
    if len(totals) != 1 or next(iter(totals)) != len(rows):
        raise ValueError("Truncated or changing paginated inventory")
    return rows


def summarize(run: dict, jobs: list[dict], attempt: int) -> dict:
    if not jobs or len({job["id"] for job in jobs}) != len(jobs):
        raise ValueError("Empty or duplicate job inventory")
    if any(job.get("run_id") != run["id"] or job.get("run_attempt") != attempt for job in jobs):
        raise ValueError("Mixed run/attempt job inventory")
    if any(job.get("status") != "completed" for job in jobs):
        raise ValueError("Only completed attempt metrics are comparable")
    records, groups = [], defaultdict(list)
    for job in jobs:
        skipped = job.get("conclusion") == "skipped"
        record = {key: job.get(key) for key in
                  ("id", "name", "conclusion", "created_at", "started_at", "completed_at")}
        record["group"] = platform_group(job["name"])
        record["queue_seconds"] = None if skipped else elapsed(job.get("created_at"), job.get("started_at"))
        record["execution_seconds"] = None if skipped else elapsed(job.get("started_at"), job.get("completed_at"))
        record["steps"] = [{"name": step["name"], "conclusion": step.get("conclusion"),
                            "phase": step_phase(step["name"]),
                            "seconds": elapsed(step.get("started_at"), step.get("completed_at"))}
                           for step in job.get("steps", []) if step.get("conclusion") != "skipped"]
        record["phase_seconds"] = {phase: round(sum(step["seconds"] for step in record["steps"]
                                                     if step["phase"] == phase and step["seconds"] is not None), 3)
                                   for phase in ("preparation_and_controls", "regression_step", "publication_and_teardown")}
        records.append(record)
        groups[record["group"]].append(record)
    group_metrics = {}
    for key, rows in groups.items():
        group_metrics[key] = {"jobs": len(rows), "conclusions": dict(Counter(row["conclusion"] for row in rows)),
            "queue_seconds": distribution([r["queue_seconds"] for r in rows if r["queue_seconds"] is not None]),
            "execution_seconds": distribution([r["execution_seconds"] for r in rows if r["execution_seconds"] is not None]),
            "successful_execution_seconds": distribution([r["execution_seconds"] for r in rows if r["execution_seconds"] is not None and r["conclusion"] == "success"]),
            "phase_seconds": {phase: distribution([r["phase_seconds"][phase] for r in rows if r["conclusion"] != "skipped"])
                              for phase in ("preparation_and_controls", "regression_step", "publication_and_teardown")},
            "peak_active_jobs": peak_active([job for job in jobs if platform_group(job["name"]) == key])}
    first_created = min((j["created_at"] for j in jobs if stamp(j.get("created_at")) is not None), default=None)
    last_completed = max((j["completed_at"] for j in jobs if stamp(j.get("completed_at")) is not None), default=None)
    return {"schema": SCHEMA,
            "run": {key: run.get(key) for key in ("id", "run_number", "head_sha", "head_branch", "event", "html_url", "created_at", "run_started_at", "updated_at", "conclusion")},
            "attempt": attempt, "job_records": len(jobs),
            "executed_jobs": sum(j.get("conclusion") != "skipped" for j in jobs),
            "first_job_created_at": first_created, "last_job_completed_at": last_completed,
            "pre_dispatch_seconds": elapsed(run.get("created_at"), first_created) if attempt == 1 else None,
            "workflow_created_to_last_job_seconds": elapsed(run.get("created_at"), last_completed) if attempt == 1 else None,
            "jobs_created_to_last_completed_seconds": elapsed(first_created, last_completed),
            "total_runner_execution_seconds": round(sum(r["execution_seconds"] or 0 for r in records), 3),
            "successful_runner_execution_seconds": round(sum(r["execution_seconds"] or 0 for r in records if r["conclusion"] == "success"), 3),
            "unsuccessful_runner_execution_seconds": round(sum(r["execution_seconds"] or 0 for r in records if r["conclusion"] not in ("success", "skipped")), 3),
            "peak_active_jobs": peak_active(jobs), "groups": group_metrics,
            "limitations": ["Pre-dispatch interval includes workflow scheduling; concurrency causation needs other run evidence.",
                "Job creation-to-start includes matrix admission, dispatch and runner capacity; API does not distinguish them.",
                "Regression step includes import, evidence and readbacks; use case telemetry for useful process execution.",
                "Peak is this workflow only; other repositories and account capacity are not observed.",
                "API head_sha is a PR head; checkout may execute its merge SHA. Original artifacts own tested source identity.",
                "Step timestamps have one-second precision; phase sums exclude inter-step gaps."],
            "jobs": sorted(records, key=lambda row: row["id"])}


def gh_json(endpoint: str, paginate: bool = False):
    args = ["gh", "api"]
    if paginate:
        args += ["--paginate", "--slurp"]
    data = subprocess.check_output(args + [endpoint], timeout=120)
    return json.loads(data)


def summarize_evidence(root: Path, *, run_id: int, attempt: int) -> dict:
    """Reduce downloaded original artifacts without treating timing as acceptance."""
    plans = list(root.rglob("execution-plan.json"))
    if len(plans) != 1:
        raise ValueError("Expected exactly one original execution plan")
    plan = json.loads(plans[0].read_text(encoding="utf-8"))
    if not isinstance(plan, dict) or not plan or set(plan) - {"linux", "windows"}:
        raise ValueError("Invalid platform plan")
    sources = [item.get("source", {}) for item in plan.values()]
    source = sources[0]
    if (not re.fullmatch(r"[0-9a-f]{40}", source.get("commit", "")) or
            not re.fullmatch(r"[0-9a-f]{40}", source.get("tree", ""))):
        raise ValueError("Missing tested plan source")
    identity = {"commit": source["commit"], "tree": source["tree"],
                "run_id": str(run_id), "run_attempt": str(attempt)}
    def validate_source(value):
        if any(value.get(key) != expected for key, expected in identity.items()):
            raise ValueError("Evidence source/run/attempt differs from requested plan")
    for value in sources:
        validate_source(value)
    files = list(root.rglob("current.jsonl"))
    if len(files) != 1:
        raise ValueError("Expected exactly one consolidated current telemetry file")
    rows = [json.loads(line) for line in files[0].read_text(encoding="utf-8").splitlines() if line.strip()]
    for row in rows:
        validate_source(row.get("source", {}))
    result = {"limitation": "Telemetry inventories describe observed execution; original independent coverage verdicts remain authoritative.",
              "file_sha256": {str(path.relative_to(root)).replace("\\", "/"): hashlib.sha256(path.read_bytes()).hexdigest()
                              for path in [plans[0], files[0]]},
              "tested_sources": sorted({(r["source"].get("commit"), r["source"].get("tree"), r["source"].get("tracked_delta_sha256")) for r in rows}),
              "platforms": {}}
    for platform, expected_plan in plan.items():
        expected = [case["name"] for shard in expected_plan["shards"] for case in shard["cases"]]
        cases = [row for row in rows if row.get("phase") == "case" and row.get("host", {}).get("platform", "").lower() == platform]
        observed = [row["fixture"] for row in cases]
        counts = Counter(observed)
        successful = [row for row in cases if row.get("result") == "passed" and row.get("natural_completion") is True and row.get("watchdog_reached") is False]
        coverage_files = list(root.rglob(platform + "-coverage.json"))
        if len(coverage_files) > 1:
            raise ValueError("Duplicate original coverage receipts")
        coverage = json.loads(coverage_files[0].read_text(encoding="utf-8")) if len(coverage_files) == 1 else None
        if coverage and coverage.get("status") == "passed":
            validate_source({"commit": coverage.get("source_sha"), "tree": coverage.get("source_tree"),
                             "run_id": coverage.get("run_id"),
                             "run_attempt": coverage.get("run_attempt", coverage.get("attempt"))})
        if coverage_files:
            result["file_sha256"][str(coverage_files[0].relative_to(root)).replace("\\", "/")] = hashlib.sha256(coverage_files[0].read_bytes()).hexdigest()
        result["platforms"][platform] = {"planned_cases": len(expected), "planned_shards": expected_plan["shard_count"],
            "expected_case_names": sorted(expected), "observed_case_count": len(cases),
            "successful_natural_cases": len(successful), "missing_observed_cases": sorted(set(expected) - set(observed)),
            "unexpected_observed_cases": sorted(set(observed) - set(expected)),
            "duplicate_observed_cases": sorted(name for name, count in counts.items() if count > 1),
            "successful_case_seconds": distribution([row["wall_seconds"] for row in successful]),
            "case_seconds": [{"name": row["fixture"], "seconds": row["wall_seconds"], "result": row.get("result")}
                             for row in sorted(cases, key=lambda row: row["fixture"])],
            "coverage_verdict": {key: coverage.get(key) for key in ("schema", "status", "error", "applicable_case_count", "case_count", "shard_count", "raw_logs_verified") if key in coverage} if coverage else None}
    return result


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="techrote/cybersand")
    parser.add_argument("--run-id", required=True, type=int)
    parser.add_argument("--attempt", type=int)
    parser.add_argument("--raw-directory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence-directory", type=Path, help="Downloaded plan, consolidated telemetry and original coverage artifacts")
    parser.add_argument("--offline", action="store_true", help="Reduce previously collected complete API pages")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository) or args.run_id < 1:
        parser.error("Invalid repository/run")
    base = f"repos/{args.repository}/actions/runs/{args.run_id}"
    root = args.raw_directory
    if args.offline:
        run = json.loads((root / "run.json").read_text(encoding="utf-8-sig"))
        pages = json.loads((root / "job-pages.json").read_text(encoding="utf-8-sig"))
        artifacts = json.loads((root / "artifact-pages.json").read_text(encoding="utf-8-sig"))
    else:
        run = gh_json(base)
        attempt = args.attempt or run["run_attempt"]
        pages = gh_json(f"{base}/attempts/{attempt}/jobs?per_page=100", True)
        artifacts = gh_json(f"{base}/artifacts?per_page=100", True)
        for name, data in (("run", run), ("job-pages", pages), ("artifact-pages", artifacts)):
            write(root / (name + ".json"), data)
    if run["id"] != args.run_id:
        raise ValueError("Run ID differs from requested run")
    jobs = flatten_pages(pages, "jobs")
    artifact_rows = flatten_pages(artifacts, "artifacts")
    report = summarize(run, jobs, args.attempt or run["run_attempt"])
    report["api_inputs"] = {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
                            for name in ("run.json", "job-pages.json", "artifact-pages.json")}
    report["artifacts"] = [{key: row.get(key) for key in ("id", "name", "size_in_bytes", "expired", "digest")}
                           for row in artifact_rows]
    report["collection"] = {"job_pages": len(pages), "artifact_pages": len(artifacts),
                            "complete_job_inventory": True, "artifact_count": len(artifact_rows)}
    if args.evidence_directory:
        report["execution_evidence"] = summarize_evidence(args.evidence_directory,
            run_id=args.run_id, attempt=args.attempt or run["run_attempt"])
    write(args.output, report)
    print(json.dumps({key: report[key] for key in ("job_records", "executed_jobs", "pre_dispatch_seconds", "total_runner_execution_seconds", "peak_active_jobs", "groups")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
