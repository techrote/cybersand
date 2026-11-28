#!/usr/bin/env python3
"""Bounded, read-only Actions coordination; metadata is never qualification.

Collect uses only explicit GET requests through an already authenticated gh.
Offline snapshots from the GitHub connector use the same JSON envelope. A
partial/racing inventory remains useful but cannot become a complete report.
No tokens, runner names, signed URLs, artifact contents or writes are required.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
from typing import Any

from ci_run_metrics import elapsed, flatten_pages, stamp

SNAPSHOT_SCHEMA = "cybersand-ci-status-snapshot-v1"
LEDGER_SCHEMA = "cybersand-ci-campaign-ledger-v1"
REPORT_SCHEMA = "cybersand-ci-campaign-status-v1"
ACTIVE_STATUSES = ("in_progress", "queued", "waiting", "pending", "requested")
CONCLUSIONS = {"success", "failure", "cancelled", "timed_out", "action_required",
               "neutral", "skipped", "stale", "startup_failure"}
REPOSITORY = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*\Z")
SHA = re.compile(r"[a-f0-9]{40}\Z")
MAX_JSON_BYTES = 32 * 1024 * 1024


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def read_json_pinned(path: Path) -> tuple[Any, str]:
    # Hash the same captured bytes that are parsed. Reopening the path after
    # summarizing could attribute a concurrently replaced input to this report.
    with path.open("rb") as stream:
        raw = stream.read(MAX_JSON_BYTES + 1)
    if len(raw) > MAX_JSON_BYTES:
        raise ValueError("JSON input exceeds 32 MiB bound")
    value = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=unique_object,
                       parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite JSON")))
    return value, hashlib.sha256(raw).hexdigest()


def read_json(path: Path) -> Any:
    return read_json_pinned(path)[0]


def positive_int(value: Any) -> bool:
    return type(value) is int and value > 0


def write_json(path: Path, value: Any) -> str:
    raw = (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return hashlib.sha256(raw).hexdigest()


def page_rows(pages: Any, key: str, label: str, problems: list[str]) -> list[dict]:
    """Retain bounded observations on incomplete pages without granting completeness."""
    if not isinstance(pages, list) or not pages or any(not isinstance(p, dict) for p in pages):
        problems.append(f"{label}: missing pages")
        return []
    for page in pages:
        if (not isinstance(page.get(key), list) or type(page.get("total_count")) is not int or
                page["total_count"] < 0 or any(not isinstance(row, dict) or
                not positive_int(row.get("id")) for row in page[key])):
            raise ValueError(f"{label}: malformed page or row")
    try:
        return flatten_pages(pages, key)
    except (ValueError, TypeError):
        problems.append(f"{label}: incomplete, duplicate or changing paginated inventory")
        rows, seen = [], set()
        for page in pages:
            for row in page.get(key, []) if isinstance(page.get(key), list) else []:
                if not isinstance(row, dict) or not positive_int(row.get("id")):
                    continue
                if row["id"] not in seen:
                    rows.append(row)
                    seen.add(row["id"])
        return rows


def job_state(job: dict) -> str:
    state, conclusion = job.get("status"), job.get("conclusion")
    if state == "completed":
        return conclusion if conclusion in CONCLUSIONS else "unknown"
    return state if state in ACTIVE_STATUSES and conclusion is None else "unknown"


def platform(labels: Any) -> str:
    if not isinstance(labels, list) or not all(isinstance(x, str) for x in labels):
        return "unknown"
    if "self-hosted" in labels:
        return "other-runner"
    for os_name, prefix in (("linux", "ubuntu-"), ("windows", "windows-"), ("macos", "macos-")):
        if any(label.startswith(prefix) for label in labels):
            return os_name
    return "unknown"


def validate_ledger(ledger: dict, repository: str) -> list[dict]:
    if not isinstance(ledger, dict) or ledger.get("schema") != LEDGER_SCHEMA or ledger.get("repository") != repository:
        raise ValueError("ledger schema/repository mismatch")
    campaigns = ledger.get("campaigns")
    if not isinstance(campaigns, list) or len(campaigns) > 100:
        raise ValueError("ledger requires at most 100 campaigns")
    keys, requests = set(), set()
    for entry in campaigns:
        if not isinstance(entry, dict) or not isinstance(entry.get("key"), str) or not entry["key"] or entry["key"] in keys:
            raise ValueError("missing or duplicate campaign key")
        keys.add(entry["key"])
        if entry.get("kind") not in {"ordinary_pr", "frozen_source", "manual", "unknown"}:
            raise ValueError("unknown campaign kind")
        for field in ("trigger_sha", "source_sha", "source_tree", "current_head_sha"):
            if entry.get(field) is not None and not SHA.fullmatch(str(entry[field])):
                raise ValueError(f"invalid {field}")
        if not isinstance(entry.get("branch"), str) or not entry["branch"]:
            raise ValueError("campaign branch is required")
        if not isinstance(entry.get("runs"), list):
            raise ValueError("campaign run requests are required")
        for request in entry["runs"]:
            if not isinstance(request, dict) or not positive_int(request.get("run_id")) or not positive_int(request.get("attempt")):
                raise ValueError("explicit positive run/attempt required")
            pair = (request["run_id"], request["attempt"])
            if pair in requests:
                raise ValueError("run/attempt claimed by multiple campaigns")
            requests.add(pair)
            required = request.get("required_jobs", [])
            if not isinstance(required, list) or any(not isinstance(x, str) or not x for x in required) or len(set(required)) != len(required):
                raise ValueError("required job names must be unique nonempty strings")
    return campaigns


def summarize(snapshot: dict, ledger: dict | None = None) -> dict:
    if not isinstance(snapshot, dict) or snapshot.get("schema") != SNAPSHOT_SCHEMA or not REPOSITORY.fullmatch(str(snapshot.get("repository", ""))):
        raise ValueError("invalid snapshot schema/repository")
    repository = snapshot["repository"]
    started, observed = snapshot.get("collection_started_at"), snapshot.get("collection_finished_at")
    if elapsed(started, observed) is None:
        raise ValueError("valid ordered UTC collection timestamps required")
    problems: list[str] = []
    queries = snapshot.get("run_queries", [])
    records = snapshot.get("runs", [])
    if not isinstance(queries, list) or not isinstance(records, list) or len(records) > 100:
        raise ValueError("invalid or excessive snapshot records")
    listed: dict[int, dict] = {}
    query_statuses = []
    for query in queries:
        if not isinstance(query, dict):
            raise ValueError("query must be an object")
        status = query.get("status")
        if status not in ACTIVE_STATUSES or status in query_statuses:
            raise ValueError("invalid or repeated active status query")
        query_statuses.append(status)
        for run in page_rows(query.get("pages"), "workflow_runs", f"{status} runs", problems):
            if not positive_int(run.get("id")):
                problems.append(f"{status}: invalid run identifier")
                continue
            if run["id"] in listed:
                problems.append(f"run {run['id']}: status changed across queries")
            if run.get("status") != status:
                problems.append(f"run {run['id']}: status differs from its query; snapshot is not atomic")
            listed[run["id"]] = run
    if set(query_statuses) != set(ACTIVE_STATUSES):
        problems.append("active-status query coverage incomplete")
    # Snapshot errors are deliberately generic strings; never replay gh stderr.
    if snapshot.get("errors"):
        problems.append("collector reported unavailable/bounded queries; see raw snapshot")
    run_reports, record_ids, runner_ids = [], set(), set()
    all_jobs = []
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("run"), dict):
            raise ValueError("run record must contain a run object")
        run = record.get("run", {})
        run_id, attempt = run.get("id"), run.get("run_attempt")
        if not positive_int(run_id) or not positive_int(attempt) or not SHA.fullmatch(str(run.get("head_sha", ""))):
            raise ValueError("run identity requires id, attempt and API head SHA")
        pair = (run_id, attempt)
        if pair in record_ids:
            raise ValueError("duplicate run/attempt record")
        record_ids.add(pair)
        repository_info = run.get("repository")
        if repository_info is not None and not isinstance(repository_info, dict):
            raise ValueError("run repository must be an object")
        source_repo = repository_info.get("full_name") if repository_info else None
        if source_repo is not None and source_repo != repository:
            raise ValueError("run belongs to a different repository")
        errors: list[str] = []
        listing = listed.get(run_id)
        if listing and any(listing.get(k) != run.get(k) for k in ("run_attempt", "head_sha", "status", "conclusion")):
            errors.append("run changed between listing and detail; snapshot is not atomic")
        after = record.get("run_after")
        if after is None:
            errors.append("run was not re-read after job collection")
        elif not isinstance(after, dict):
            raise ValueError("run recheck must be an object")
        elif any(after.get(k) != run.get(k) for k in ("id", "run_attempt", "head_sha", "status", "conclusion")):
            errors.append("run changed during job collection; refresh this attempt")
        jobs = page_rows(record.get("job_pages"), "jobs", f"run {run_id}/{attempt} jobs", errors)
        job_reports = []
        for job in jobs:
            if (job.get("run_id") != run_id or job.get("run_attempt") != attempt or
                    job.get("head_sha") != run["head_sha"]):
                raise ValueError("job source/run/attempt mismatch")
            if not positive_int(job.get("id")) or not isinstance(job.get("name"), str) or not job["name"]:
                raise ValueError("invalid job identity")
            state = job_state(job)
            if state == "unknown":
                errors.append(f"job {job['id']}: inconsistent status/conclusion")
            for field in ("created_at", "started_at", "completed_at"):
                value = job.get(field)
                if value is not None and (stamp(value) is None or stamp(value) > stamp(observed)):
                    errors.append(f"job {job['id']}: {field} is invalid or after observation")
            if job.get("completed_at") is not None and (
                    job.get("status") != "completed" or elapsed(job.get("started_at"), job["completed_at"]) is None):
                errors.append(f"job {job['id']}: inconsistent completion clock/status")
            if run.get("status") == "completed" and state in ACTIVE_STATUSES:
                errors.append(f"job {job['id']}: active job in completed run; snapshot is not atomic")
            runner = job.get("runner_id")
            assigned = state == "in_progress" and positive_int(runner) and elapsed(job.get("started_at"), observed) is not None
            if assigned:
                runner_ids.add(runner)
            row = {"id": job["id"], "name": job["name"], "state": state,
                   "platform": platform(job.get("labels")), "runner_assigned": assigned,
                   "created_at": job.get("created_at"), "started_at": job.get("started_at"),
                   "completed_at": job.get("completed_at"),
                   "queue_or_dispatch_seconds": elapsed(job.get("created_at"), job.get("started_at")) if state not in {"skipped", "queued", "waiting", "pending", "requested"} else None,
                   "waiting_age_seconds": elapsed(job.get("created_at"), observed) if state in {"queued", "waiting", "pending", "requested"} else None,
                   "running_age_seconds": elapsed(job.get("started_at"), observed) if state == "in_progress" else None,
                   "completed_execution_seconds": elapsed(job.get("started_at"), job.get("completed_at")) if job.get("status") == "completed" and state != "skipped" else None,
                   "url": f"https://github.com/{repository}/actions/runs/{run_id}/job/{job['id']}"}
            job_reports.append(row)
            all_jobs.append({**row, "run_id": run_id, "attempt": attempt})
        artifacts = []
        if record.get("artifact_pages"):
            for item in page_rows(record["artifact_pages"], "artifacts", f"run {run_id} artifacts", errors):
                artifacts.append({key: item.get(key) for key in ("id", "name", "size_in_bytes", "expired", "digest")})
        run_reports.append({"id": run_id, "attempt": attempt, "workflow": run.get("name"),
            "workflow_path": run.get("path"), "event": run.get("event"), "branch": run.get("head_branch"),
            "api_head_sha": run["head_sha"], "status": run.get("status"), "conclusion": run.get("conclusion"),
            "url": f"https://github.com/{repository}/actions/runs/{run_id}/attempts/{attempt}",
            "complete_job_inventory": not errors, "problems": errors,
            "state_counts": dict(sorted(Counter(x["state"] for x in job_reports).items())),
            "jobs": job_reports, "artifacts": artifacts,
            "evidence_verification": "metadata-only; original owner verifier required"})
        problems.extend(errors)
    missing_runs = sorted(run_id for run_id in listed if not any(pair[0] == run_id for pair in record_ids))
    if missing_runs:
        problems.append("listed active runs have no job inventory: " + ", ".join(map(str, missing_runs)))
    campaign_reports = []
    if ledger is not None:
        entries = validate_ledger(ledger, repository)
        lookup = {(r["id"], r["attempt"]): r for r in run_reports}
        for entry in entries:
            requests = []
            for request in entry["runs"]:
                current = lookup.get((request["run_id"], request["attempt"]))
                reasons, required = [], []
                if current is None:
                    reasons.append("run/attempt not collected")
                else:
                    if current["branch"] != entry["branch"]:
                        reasons.append("branch differs from registered request")
                    if entry.get("trigger_sha") is None:
                        reasons.append("trigger source identity unregistered")
                    elif current["api_head_sha"] != entry["trigger_sha"]:
                        reasons.append("trigger source differs from registered request")
                    if not current["complete_job_inventory"]:
                        reasons.append("job inventory is incomplete or non-atomic")
                    for name in request.get("required_jobs", []):
                        matches = [job for job in current["jobs"] if job["name"] == name]
                        state = matches[0]["state"] if len(matches) == 1 else "missing" if not matches else "ambiguous"
                        required.append({"name": name, "state": state})
                        if state != "success":
                            reasons.append(f"required job {name}: {state}")
                    if current["status"] != "completed" or current["conclusion"] != "success":
                        reasons.append("workflow is not a completed success")
                if not request.get("required_jobs"):
                    reasons.append("required job inventory unregistered")
                superseded = bool(current and current["event"] == "pull_request" and
                    entry["kind"] == "ordinary_pr" and entry.get("current_head_sha") and
                    current["api_head_sha"] != entry["current_head_sha"])
                if superseded:
                    reasons.append("superseded by registered PR head; old evidence retains its original source")
                requests.append({"run_id": request["run_id"], "attempt": request["attempt"],
                    "required_jobs": required, "metadata_gate": "reported-success" if not reasons else "incomplete-or-blocked",
                    "reasons": reasons, "superseded_by_registered_pr_head": superseded,
                    "qualification": "not-established-by-metadata", "evidence_reuse": "requires source-bound owner verifier"})
            campaign_reports.append({key: entry.get(key) for key in ("key", "programme", "owner", "branch", "kind", "source_sha", "source_tree", "human_gate", "publication_gate")})
            campaign_reports[-1]["requests"] = requests
    running = [j for j in all_jobs if j["state"] == "in_progress"]
    waiting = [j for j in all_jobs if j["state"] in {"queued", "waiting", "pending", "requested"}]
    return {"schema": REPORT_SCHEMA, "repository": repository,
        "collection_started_at": started, "collection_finished_at": observed,
        "status": "partial" if problems else "observed",
        "observation_scope": "bounded repository snapshot; not an account-wide inventory",
        "problems": sorted(set(problems)), "runs": run_reports, "campaigns": campaign_reports,
        "pressure": {"in_progress_jobs": len(running), "assigned_runner_ids_observed": len(runner_ids),
            "in_progress_without_verified_assignment": sum(not j["runner_assigned"] for j in running),
            "assigned_jobs_by_platform": dict(Counter(j["platform"] for j in running if j["runner_assigned"])),
            "waiting_jobs": len(waiting), "waiting_states": dict(Counter(j["state"] for j in waiting)),
            "oldest_observed_wait_seconds": max((j["waiting_age_seconds"] for j in waiting if j["waiting_age_seconds"] is not None), default=None),
            "account_capacity": "unverified; repository jobs do not establish the account limit",
            "declared_capacity": ledger.get("declared_capacity") if ledger else None,
            "interpretation": "runner IDs observed during collection are not a simultaneous count; repository observations are not account utilisation, billing or proof of runner scarcity"},
        "critical_path_candidates": sorted(running, key=lambda j: j["running_age_seconds"] or 0, reverse=True)[:10],
        "critical_path_limit": "longest active jobs only; a verified dependency graph and future durations are unavailable",
        "advice": ["Check current campaign ownership before requesting a new heavy run.",
            "Stagger optional heavy requests when required work is waiting; do not cancel another programme.",
            "Preserve frozen-source campaigns and every original failed attempt.",
            "Verify original source/tree/run/attempt and required receipts before reusing evidence."],
        "qualification": "none; metadata status does not replace native, graphical, provenance or human gates"}


def gh_get(endpoint: str) -> dict:
    # No shell, dynamic method, credentials or POST fields; cannot dispatch/cancel.
    result = subprocess.run(["gh", "api", "--method", "GET", endpoint], capture_output=True,
                            timeout=30, check=False)
    if result.returncode:
        raise RuntimeError(f"read-only GitHub query failed (exit {result.returncode}); authenticate gh separately")
    if len(result.stdout) > MAX_JSON_BYTES:
        raise ValueError("GitHub response exceeds bound")
    return json.loads(result.stdout, object_pairs_hook=unique_object)


def collect(repository: str, *, max_runs: int = 20, max_pages: int = 2,
            ledger: dict | None = None, get=gh_get) -> dict:
    if not REPOSITORY.fullmatch(repository) or not 1 <= max_runs <= 100 or not 1 <= max_pages <= 5:
        raise ValueError("invalid repository or collection bounds")
    entries = validate_ledger(ledger, repository) if ledger is not None else []
    snapshot = {"schema": SNAPSHOT_SCHEMA, "repository": repository,
        "collection_started_at": utc_now(), "run_queries": [], "runs": [], "errors": [],
        "bounds": {"max_runs": max_runs, "max_pages_per_query": max_pages}}
    base, known = f"repos/{repository}/actions/runs", {}
    def pages(endpoint, key):
        result = []
        for number in range(1, max_pages + 1):
            separator = "&" if "?" in endpoint else "?"
            value = get(f"{endpoint}{separator}per_page=100&page={number}")
            result.append(value)
            if not isinstance(value.get(key), list):
                raise ValueError("invalid GitHub page")
            if len(value[key]) < 100:
                break
        return result
    for status in ACTIVE_STATUSES:
        try:
            values = pages(f"{base}?status={status}", "workflow_runs")
            snapshot["run_queries"].append({"status": status, "pages": values})
            for value in values:
                for run in value["workflow_runs"]:
                    known[run["id"]] = run
        except (RuntimeError, ValueError, OSError, subprocess.SubprocessError):
            snapshot["errors"].append(f"active {status} query unavailable")
    requests = {(r["run_id"], r["attempt"]) for c in entries for r in c["runs"]}
    requests.update((r["id"], r["run_attempt"]) for r in known.values())
    # Explicit requests first; repeated bounded collection is an operator decision.
    explicit = {(r["run_id"], r["attempt"]) for c in entries for r in c["runs"]}
    selected = sorted(requests, key=lambda pair: (pair not in explicit, -pair[0], -pair[1]))[:max_runs]
    if len(requests) > max_runs:
        snapshot["errors"].append("run detail bound reached; inventory partial")
    for run_id, attempt in selected:
        try:
            endpoint = f"{base}/{run_id}/attempts/{attempt}"
            run = get(endpoint)
            jobs = pages(endpoint + "/jobs", "jobs")
            after = get(endpoint)
            snapshot["runs"].append({"run": run, "job_pages": jobs, "run_after": after})
        except (RuntimeError, ValueError, OSError, subprocess.SubprocessError):
            snapshot["errors"].append(f"run {run_id}/{attempt} unavailable")
    snapshot["collection_finished_at"] = utc_now()
    return snapshot


def render_markdown(report: dict) -> str:
    def cell(value):
        return str(value if value is not None else "unknown").replace("|", "\\|").replace("\n", " ").replace("\r", " ")
    p = report["pressure"]
    lines = ["# CI coordination snapshot", "", f"Repository: `{report['repository']}`. Observed: {report['collection_finished_at']}.", "",
        f"**{report['status'].upper()}** — {report['observation_scope']}. No qualification or publication authority.", "",
        f"Observed during collection: {p['in_progress_jobs']} running jobs, {p['assigned_runner_ids_observed']} assigned runner IDs and {p['waiting_jobs']} waiting jobs. These are not a simultaneous count. Account capacity is unverified.", "",
        "| Run / attempt | Workflow | Branch | API head | Status | Jobs |",
        "|---|---|---|---|---|---|"]
    for run in report["runs"]:
        lines.append(f"| [{run['id']}/{run['attempt']}]({run['url']}) | {cell(run['workflow'])} | {cell(run['branch'])} | `{run['api_head_sha'][:12]}` | {cell(run['conclusion'] or run['status'])} | {cell(run['state_counts'])} |")
    if report["problems"]:
        lines += ["", "## Incomplete observations", ""] + ["- " + cell(x) for x in report["problems"]]
    lines += ["", "## Longest active jobs", "", report["critical_path_limit"] + ".", ""]
    lines += [f"- Run {j['run_id']}/{j['attempt']}: {cell(j['name'])}; elapsed {j['running_age_seconds']} seconds." for j in report["critical_path_candidates"]] or ["No active jobs in the collected records."]
    if report["campaigns"]:
        lines += ["", "## Registered campaigns", ""]
        for campaign in report["campaigns"]:
            lines += [f"### {cell(campaign['key'])}", "", f"Programme: {cell(campaign['programme'])}; owner: {cell(campaign['owner'])}; kind: {campaign['kind']}.", "",
                      f"Human gate: {cell(campaign['human_gate'])}. Publication gate: {cell(campaign['publication_gate'])}.", ""]
            for request in campaign["requests"]:
                lines.append(f"- {request['run_id']}/{request['attempt']}: **{request['metadata_gate']}**; evidence reuse requires the source-bound owner verifier.")
                lines += ["  - " + cell(reason) for reason in request["reasons"]]
    lines += ["", "## Coordination advice", ""] + ["- " + x for x in report["advice"]]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, help="offline connector/gh snapshot")
    parser.add_argument("--collect", action="store_true", help="bounded GET-only collection using existing gh authentication")
    parser.add_argument("--repository", default="techrote/cybersand")
    parser.add_argument("--ledger", type=Path)
    parser.add_argument("--raw-output", type=Path)
    parser.add_argument("--max-runs", type=int, default=20)
    parser.add_argument("--max-pages", type=int, default=2)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--markdown", type=Path)
    args = parser.parse_args()
    if bool(args.snapshot) == args.collect or (args.collect and args.raw_output is None):
        parser.error("choose --snapshot, or --collect with --raw-output")
    try:
        ledger, ledger_sha = read_json_pinned(args.ledger) if args.ledger else (None, None)
        if args.collect:
            snapshot = collect(args.repository, max_runs=args.max_runs, max_pages=args.max_pages, ledger=ledger)
            snapshot_sha = write_json(args.raw_output, snapshot)
        else:
            snapshot, snapshot_sha = read_json_pinned(args.snapshot)
        report = summarize(snapshot, ledger)
        report["snapshot_sha256"] = snapshot_sha
        if args.ledger:
            report["ledger_sha256"] = ledger_sha
        write_json(args.output, report)
        if args.markdown:
            args.markdown.parent.mkdir(parents=True, exist_ok=True)
            args.markdown.write_text(render_markdown(report), encoding="utf-8")
        print(json.dumps({"status": report["status"], "runs": len(report["runs"]), "pressure": report["pressure"]}, sort_keys=True))
        return 2 if report["status"] == "partial" else 0
    except (ValueError, OSError, TypeError, KeyError) as error:
        print(json.dumps({"status": "refused", "error": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
