#!/usr/bin/env python3
"""Offline, source-bound audit of GitHub Actions job time (CI-OPT-002).

Inputs are retained GitHub Actions API run and complete jobs snapshots. No
network calls and no inference of unfinished runner time. Use gh api to
collect source-matched input snapshots; preserve URLs and all job pages.
"""
from __future__ import annotations
import argparse
from datetime import datetime
import json
from pathlib import Path
import re

SHA = re.compile(r"[0-9a-f]{40}\Z")
FINISHED = {"success", "skipped", "neutral", "failure", "cancelled", "timed_out", "action_required"}


def instant(value):
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def duration(start, end):
    if start is None or end is None or end < start:
        return None
    return (end - start).total_seconds() / 60


def category(name: str) -> str:
    if name.startswith("Pinned Linux Godot archive") or name.startswith("Pinned Windows Godot archive"):
        return "engine-preparation"
    if "regression shard " in name:
        return "godot-regression"
    if name.startswith("Native family / "):
        return "native-family"
    if "graphical owner workflow" in name or "graphical Workbench" in name:
        return "feature-graphical-owner"
    if "shader" in name.lower() or "ANGLE cohort" in name:
        return "shader"
    return "other"


def analyze(run: dict) -> dict:
    if not isinstance(run, dict) or not isinstance(run.get("jobs"), list):
        raise ValueError("run and full jobs array required")
    run_id = run.get("id")
    source = run.get("head_sha")
    if type(run_id) is not int or run_id <= 0 or not isinstance(source, str) or not SHA.fullmatch(source):
        raise ValueError("exact run ID and source SHA required")
    jobs = run["jobs"]
    if not jobs or type(run.get("total_count", len(jobs))) is not int or run.get("total_count", len(jobs)) != len(jobs):
        raise ValueError("incomplete or unpaged job inventory")
    seen = set()
    rows = []
    begins, ends = [], []
    totals = {}
    missing = 0
    for job in jobs:
        job_id = job.get("id")
        name = job.get("name")
        if type(job_id) is not int or job_id in seen or not isinstance(name, str) or not name:
            raise ValueError("bad or duplicate job identifier")
        seen.add(job_id)
        status = job.get("status")
        conclusion = job.get("conclusion")
        if status == "completed" and conclusion not in FINISHED:
            raise ValueError("completed job missing valid conclusion")
        start, end = instant(job.get("started_at")), instant(job.get("completed_at"))
        minutes = duration(start, end) if status == "completed" and conclusion != "skipped" else None
        if minutes is None and conclusion != "skipped":
            missing += 1
        if minutes is not None:
            begins.append(start)
            ends.append(end)
        group = category(name)
        totals[group] = totals.get(group, 0.0) + (minutes or 0)
        rows.append({"id": job_id, "name": name, "status": status,
                     "conclusion": conclusion, "group": group,
                     "runner_minutes": round(minutes, 3) if minutes is not None else None,
                     "url": job.get("html_url", "")})
    span = duration(min(begins), max(ends)) if begins else None
    return {"schema": "ci-opt-002-run-audit-v1", "run_id": run_id,
            "source_sha": source, "workflow": run.get("name", ""),
            "url": run.get("html_url", ""), "event": run.get("event", ""),
            "conclusion": run.get("conclusion"), "job_count": len(rows),
            "incomplete_jobs": missing, "complete": missing == 0,
            "known_runner_minutes": round(sum(x["runner_minutes"] or 0 for x in rows), 3),
            "runner_minutes_by_group": {k: round(v, 3) for k, v in sorted(totals.items())},
            "completed_job_span_minutes": round(span, 3) if span is not None else None,
            "jobs": rows}


def compare(before: dict, after: dict) -> dict:
    if before["workflow"] != after["workflow"] or before["source_sha"] != after["source_sha"]:
        raise ValueError("same workflow and same source required")
    if not before["complete"] or not after["complete"]:
        raise ValueError("incomplete or in-flight evidence cannot establish savings")
    def fingerprint(run):
        # New same-run preparation jobs count against runner cost but are
        # not required test coverage. Preserve every substantive test job.
        return sorted((job["name"], job["group"], job["conclusion"]) for job in run["jobs"]
                      if job["group"] != "engine-preparation")
    if fingerprint(before) != fingerprint(after) or any(
        row["conclusion"] != "success" for run in (before, after) for row in run["jobs"]
    ):
        raise ValueError("changed/failed/skipped test inventory cannot count as improvement")
    original, updated = before["known_runner_minutes"], after["known_runner_minutes"]
    return {"schema": "ci-opt-002-comparison-v1", "source_sha": before["source_sha"],
            "workflow": before["workflow"], "before_runner_minutes": original,
            "after_runner_minutes": updated,
            "change_percent": round(100 * (updated - original) / original, 2) if original else None,
            "before_completed_span_minutes": before["completed_job_span_minutes"],
            "after_completed_span_minutes": after["completed_job_span_minutes"],
            "caveat": "Full test assertion parity must also be verified from preserved source-bound receipts."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--compare", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    def inspect(path):
        return analyze(json.loads(path.read_text(encoding="utf-8")))
    result = inspect(args.run)
    if args.compare:
        result = compare(result, inspect(args.compare))
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
