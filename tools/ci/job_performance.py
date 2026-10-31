"""Bind completed GitHub job wall times to observations from that exact runner."""

from datetime import datetime
import hashlib
import json
import re

import execution_telemetry


def sha(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def observations(jobs: list, records: list, run_id: str, attempt: str) -> tuple[list, list]:
    results, unavailable = [], []
    for job in jobs:
        if job.get("status") != "completed" or job.get("conclusion") == "skipped":
            continue
        identity = sha(job.get("runner_name") or "")
        matches = [row for row in records if row.get("source", {}).get("runner_name_sha256") == identity
                   and str(row["source"].get("run_id")) == run_id
                   and str(row["source"].get("run_attempt")) == attempt]
        if not matches or len({json.dumps(row["host"], sort_keys=True) for row in matches}) != 1:
            unavailable.append({"job_id": job.get("id"), "reason": "no_unique_original_runner_observation"})
            continue
        if len({(row["source"].get("commit"), row["source"].get("tree")) for row in matches}) != 1:
            unavailable.append({"job_id": job.get("id"), "reason": "inconsistent_source_observations"})
            continue
        try:
            started = datetime.fromisoformat(job["started_at"].replace("Z", "+00:00"))
            completed = datetime.fromisoformat(job["completed_at"].replace("Z", "+00:00"))
            if started.tzinfo is None or completed.tzinfo is None or completed <= started:
                raise ValueError("invalid job clock")
        except (KeyError, TypeError, ValueError):
            unavailable.append({"job_id": job.get("id"), "reason": "invalid_completed_job_timestamps"})
            continue
        first = matches[0]
        workload = sorted(json.dumps({key: row.get(key) for key in ("fixture", "phase", "configuration")}, sort_keys=True)
                          for row in matches if row.get("phase") != "hosted-job")
        results.append({"schema": execution_telemetry.SCHEMA, "recorded_utc": job["completed_at"],
            "source": first["source"], "host": first["host"], "fixture": job["name"],
            "fixture_sha256": None, "test_version": "hosted-job-v1", "phase": "hosted-job",
            "renderer": {"backend": "complete-job-workload", "driver": "not-applicable",
                "compiler": "not-applicable", "variant": "not-applicable", "cache_state": "not-applicable",
                "shader_source_sha256": None, "shader_variant_sha256": None},
            "configuration": {"workload_sha256": sha(json.dumps(workload)), "observations": len(workload)},
            "wall_seconds": (completed - started).total_seconds(),
            "result": "passed" if job["conclusion"] == "success" else job["conclusion"],
            "natural_completion": job["conclusion"] == "success",
            "watchdog_reached": job["conclusion"] == "timed_out", "watchdog_seconds": None,
            "resources": {"available": False, "scope": "whole_job", "reason": "Actions API supplies wall time only"},
            "metrics": {}, "last_progress": None, "raw_log": None,
            "execution_policy": first.get("execution_policy"),
            "job_clock": {"job_id": job["id"], "started_at": job["started_at"],
                "completed_at": job["completed_at"], "conclusion": job["conclusion"],
                "scope": "GitHub job start through completion; queue delay excluded"}})
    return results, unavailable


def collect(repository: str, run_id: str, attempt: str, records: list, client) -> tuple[list, dict]:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository or ""):
        raise ValueError("invalid repository")
    if not re.fullmatch(r"[1-9][0-9]*", run_id or "") or not re.fullmatch(r"[1-9][0-9]*", attempt or ""):
        raise ValueError("invalid run/attempt")
    jobs = []
    for page in range(1, 11):
        payload = client.json(f"/repos/{repository}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100&page={page}")
        batch = payload.get("jobs")
        if not isinstance(batch, list):
            raise ValueError("invalid job response")
        jobs.extend(batch)
        if len(batch) < 100:
            break
    else:
        raise ValueError("job inventory exceeds bounded collection")
    rows, unavailable = observations(jobs, records, run_id, attempt)
    return rows, {"status": "observed", "job_count": len(jobs), "completed_observations": len(rows),
                  "unavailable": unavailable, "limitation": "Currently running collector jobs have no final duration yet."}
