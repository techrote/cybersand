#!/usr/bin/env python3
"""Retain comparable GitHub-hosted timing history as nonblocking advice.

Current raw observations stay in current.jsonl. Failed, incomplete, unknown and
incompatible observations remain visible in summary.json, outside the numeric
baseline. Neither an elapsed-time ratio nor missing history changes test status.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

import execution_policy
import execution_telemetry

SCHEMA = "execution-performance-history-v1"
PREFIX = "execution-performance-"
MAX_ARCHIVE_BYTES = 32 * 1024 * 1024
MAX_MEMBER_BYTES = 16 * 1024 * 1024
MAX_EXPANDED_BYTES = 64 * 1024 * 1024
MAX_HISTORY_BYTES = 128 * 1024 * 1024
MAX_MEMBERS = 2048
MAX_LINE_BYTES = 1024 * 1024
MAX_RECORDS = 25000
UNKNOWN = {"", "unknown", "unavailable", "unset", "unspecified", "none", "null"}
HASH = re.compile(r"[0-9a-f]{40}")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def strict_json(data: str | bytes):
    def pairs(values):
        result = {}
        for key, value in values:
            if key in result:
                raise ValueError("duplicate JSON field")
            result[key] = value
        return result
    def constant(_):
        raise ValueError("nonfinite JSON constant")
    def number(text):
        value = float(text)
        if not math.isfinite(value):
            raise ValueError("nonfinite JSON exponent")
        return value
    return json.loads(data, object_pairs_hook=pairs, parse_constant=constant, parse_float=number)


def error_name(error: Exception) -> str:
    # HTTP exception text may contain signed artifact URLs. Never retain it.
    if isinstance(error, urllib.error.HTTPError):
        return "HTTP " + str(error.code)
    return type(error).__name__


def timestamp(value) -> float | None:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parsed.timestamp() if parsed.tzinfo is not None else None
    except (AttributeError, ValueError, OverflowError):
        return None


def positive_id(value) -> str | None:
    if type(value) not in (str, int) or not re.fullmatch(r"[1-9][0-9]{0,19}", str(value)):
        return None
    return str(value)


def finite_number(value) -> bool:
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False


def median(values) -> float:
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    low, high = ordered[middle - 1:middle + 1]
    return low + (high - low) / 2


def known(value) -> bool:
    if isinstance(value, str):
        return value.strip().lower() not in UNKNOWN
    if type(value) in (int, float):
        return finite_number(value)
    if type(value) is bool:
        return True
    if isinstance(value, dict):
        return bool(value) and all(known(item) for item in value.values())
    if isinstance(value, list):
        return all(known(item) for item in value)
    return False


def comparison_issues(record: dict) -> list[str]:
    problems = []
    if record.get("schema") != execution_telemetry.SCHEMA:
        problems.append("unsupported_schema")
    if record.get("result") != "passed":
        problems.append("process_not_passed")
    if record.get("natural_completion") is not True or record.get("watchdog_reached") is not False:
        problems.append("incomplete_or_watchdog_reached")
    wall = record.get("wall_seconds")
    if not finite_number(wall) or wall <= 0:
        problems.append("invalid_wall_seconds")
    host, render, source = (record.get(key, {}) for key in ("host", "renderer", "source"))
    if not all(isinstance(value, dict) for value in (host, render, source)):
        return problems + ["invalid_identity_objects"]
    for key in ("platform", "architecture", "cpu_model", "runner_image", "hardware_cohort"):
        if not isinstance(host.get(key), str) or not known(host[key]) or host[key].lower() == "not-applicable":
            problems.append("unknown_host_" + key)
    if type(host.get("logical_cpu_count")) is not int or host["logical_cpu_count"] <= 0:
        problems.append("unknown_cpu_count")
    if host.get("runner_class") != "github-hosted" or host.get("runner_environment") != "github-hosted":
        problems.append("non_github_hosted_cohort")
    for key in ("backend", "driver", "compiler", "variant", "cache_state"):
        if not isinstance(render.get(key), str) or not known(render[key]):
            problems.append("unknown_renderer_" + key)
    for key in ("fixture", "test_version", "phase"):
        if not isinstance(record.get(key), str) or not known(record[key]):
            problems.append("unknown_" + key)
    if not isinstance(record.get("configuration"), dict) or not known(record["configuration"]):
        problems.append("unknown_configuration")
    if not isinstance(source.get("commit"), str) or not HASH.fullmatch(source["commit"]):
        problems.append("unknown_source_commit")
    for name, value, length in (
        ("source_tree", source.get("tree"), 40),
        ("fixture_sha256", record.get("fixture_sha256"), 64),
        ("shader_source_sha256", render.get("shader_source_sha256"), 64),
        ("shader_variant_sha256", render.get("shader_variant_sha256"), 64),
    ):
        if value is not None and (not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{" + str(length) + r"}", value)):
            problems.append("invalid_" + name)
    if source.get("tracked_delta_sha256") is not None:
        problems.append("uncommitted_source_delta")
    if positive_id(source.get("run_id")) is None or positive_id(source.get("run_attempt")) is None:
        problems.append("unknown_run_identity")
    if timestamp(record.get("recorded_utc")) is None:
        problems.append("unknown_recording_time")
    return problems


def parse_jsonl(data: bytes, origin: dict) -> tuple[list[dict], list[dict]]:
    records, errors = [], []
    for line_number, line in enumerate(data.splitlines(), 1):
        if not line.strip():
            continue
        location = {**origin, "line": line_number, "line_sha256": sha(line)}
        try:
            if len(line) > MAX_LINE_BYTES:
                raise ValueError("line exceeds bound")
            record = strict_json(line.decode("utf-8"))
            if not isinstance(record, dict) or record.get("schema") != execution_telemetry.SCHEMA:
                continue  # A directory can contain unrelated scientific JSONL.
            records.append({"record": record, "origin": location})
            if len(records) > MAX_RECORDS:
                raise ValueError("record count exceeds bound")
        except (UnicodeError, ValueError, TypeError) as error:
            errors.append({**location, "reason": error_name(error)})
    return records[:MAX_RECORDS], errors


def read_current(paths: list[Path], output: Path) -> tuple[list[dict], list[dict]]:
    records, errors, seen_paths = [], [], set()
    for root in paths:
        candidates = [root] if root.is_file() else sorted(root.rglob("*.jsonl")) if root.is_dir() else []
        if not root.exists():
            errors.append({"path": str(root), "reason": "current_input_missing"})
        for path in candidates:
            if path.is_symlink() or path.resolve() == (output / "current.jsonl").resolve() or path.resolve() in seen_paths:
                continue
            seen_paths.add(path.resolve())
            try:
                if path.stat().st_size > MAX_MEMBER_BYTES:
                    raise ValueError("current JSONL exceeds bound")
                rows, rejected = parse_jsonl(path.read_bytes(), {"kind": "current", "path": str(path)})
                records.extend(rows)
                errors.extend(rejected)
                if len(records) > MAX_RECORDS:
                    errors.append({"scope": "current", "reason": "current_record_bound_reached"})
                    return deduplicate(records[:MAX_RECORDS]), errors
            except (OSError, ValueError) as error:
                errors.append({"path": str(path), "reason": error_name(error)})
    return deduplicate(records), errors


def deduplicate(entries: list[dict]) -> list[dict]:
    # The same raw observation can appear in both a shard and a consolidation.
    seen, result = set(), []
    for entry in entries:
        key = sha(json.dumps(entry["record"], sort_keys=True, allow_nan=False).encode())
        if key not in seen:
            seen.add(key)
            result.append({**entry, "record_sha256": key})
    return result


def read_archive(data: bytes, origin: dict) -> tuple[list[dict], list[dict], int]:
    if len(data) > MAX_ARCHIVE_BYTES:
        raise ValueError("archive exceeds compressed bound")
    records, errors, total, names = [], [], 0, set()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        members = archive.infolist()
        if len(members) > MAX_MEMBERS:
            raise ValueError("archive member count exceeds bound")
        for member in members:
            name = member.orig_filename
            components = name.rstrip("/").split("/")
            if (not name or PurePosixPath(name).is_absolute() or "\\" in name or ":" in name
                    or any(part in ("", ".", "..") for part in components)
                    or any(ord(char) < 32 or ord(char) == 127 for char in name)
                    or stat.S_ISLNK(member.external_attr >> 16) or member.flag_bits & 1
                    or name in names):
                raise ValueError("unsafe archive member")
            names.add(name)
            total += member.file_size
            if member.file_size > MAX_MEMBER_BYTES or total > MAX_EXPANDED_BYTES:
                raise ValueError("archive exceeds expanded bound")
        for member in members:
            if member.is_dir() or not member.filename.endswith(".jsonl"):
                continue
            with archive.open(member) as stream:
                payload = stream.read(MAX_MEMBER_BYTES + 1)
            if len(payload) != member.file_size:
                raise ValueError("archive member size differs")
            rows, rejected = parse_jsonl(payload, {**origin, "member": member.filename})
            records.extend(rows)
            errors.extend(rejected)
            if len(records) > MAX_RECORDS:
                raise ValueError("archive record count exceeds bound")
    return deduplicate(records), errors, total


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        return None


class GitHub:
    def __init__(self, token: str, *, timeout: float | None = None):
        self.token = token
        self.until = time.monotonic() + (timeout or execution_policy.watchdog_seconds("operation_seconds"))
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, path: str, *, limit: int = MAX_MEMBER_BYTES) -> bytes:
        url = "https://api.github.com" + path
        for _ in range(6):
            remaining = self.until - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("history collection allowance exhausted")
            parsed = urllib.parse.urlparse(url)
            if parsed.scheme != "https" or parsed.username or parsed.password or parsed.port not in (None, 443):
                raise ValueError("unsafe artifact redirect")
            headers = {"Accept": "application/vnd.github+json", "User-Agent": "CyberSand-performance-history",
                       "X-GitHub-Api-Version": "2022-11-28"}
            # Signed storage redirects must never receive the repository token.
            if parsed.hostname == "api.github.com":
                headers["Authorization"] = "Bearer " + self.token
            request = urllib.request.Request(url, headers=headers, method="GET")
            try:
                response = self.opener.open(request, timeout=min(30.0, remaining))
            except urllib.error.HTTPError as error:
                if error.code not in (301, 302, 303, 307, 308) or not error.headers.get("Location"):
                    raise
                url = urllib.parse.urljoin(url, error.headers["Location"])
                error.close()
                continue
            with response:
                if int(response.headers.get("Content-Length", "0")) > limit:
                    raise ValueError("download exceeds byte bound")
                chunks, size = [], 0
                while True:
                    if time.monotonic() >= self.until:
                        raise TimeoutError("history collection allowance exhausted")
                    chunk = response.read(min(65536, limit + 1 - size))
                    if not chunk:
                        return b"".join(chunks)
                    chunks.append(chunk)
                    size += len(chunk)
                    if size > limit:
                        raise ValueError("download exceeds byte bound")
        raise ValueError("too many artifact redirects")

    def json(self, path: str):
        return strict_json(self.request(path))


def collect_history(repository: str, branch: str | None, limit: int, *, token: str | None,
                    current_run: str | None = None, client=None) -> tuple[list[dict], dict]:
    receipt = {"status": "unavailable", "requested_artifacts": limit, "artifacts": [], "unavailable": []}
    entries = []
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository or "") or not token:
        receipt["unavailable"].append({"scope": "history", "reason": "repository_or_read_token_unavailable"})
        return entries, receipt
    api = client or GitHub(token)
    try:
        repo = api.json("/repos/" + repository)
        canonical_branch = repo["default_branch"]
        if branch is not None and branch != canonical_branch:
            raise ValueError("requested branch is not repository default")
        receipt["repository"], receipt["default_branch"] = repository, canonical_branch
        runs, expanded, selected, seen = {}, 0, 0, set()
        for page in range(1, 21):
            document = api.json(f"/repos/{repository}/actions/artifacts?per_page=100&page={page}")
            artifacts = document["artifacts"]
            if not isinstance(artifacts, list):
                raise ValueError("invalid artifact inventory")
            artifacts.sort(key=lambda item: (timestamp(item.get("created_at")) or 0, int(positive_id(item.get("id")) or 0)), reverse=True)
            for artifact in artifacts:
                artifact_id = positive_id(artifact.get("id"))
                workflow = artifact.get("workflow_run", {})
                run_id = positive_id(workflow.get("id"))
                if (not str(artifact.get("name", "")).startswith(PREFIX) or artifact_id in seen
                        or artifact_id is None or run_id is None or run_id == positive_id(current_run)
                        or workflow.get("head_branch") != canonical_branch):
                    continue
                seen.add(artifact_id)
                if run_id not in runs:
                    runs[run_id] = api.json(f"/repos/{repository}/actions/runs/{run_id}")
                run = runs[run_id]
                if (run.get("status") != "completed" or run.get("head_branch") != canonical_branch
                        or run.get("event") not in ("push", "schedule", "workflow_dispatch", "workflow_run")
                        or run.get("head_repository", {}).get("full_name", "").lower() != repository.lower()):
                    continue
                selected += 1
                location = {"artifact_id": artifact_id, "artifact_name": artifact["name"],
                            "run_id": run_id, "run_attempt": run.get("run_attempt"),
                            "head_sha": run.get("head_sha"), "created_at": artifact.get("created_at")}
                try:
                    if artifact.get("expired") is not False:
                        raise ValueError("artifact_expired")
                    size = artifact.get("size_in_bytes")
                    if type(size) is not int or not 0 < size <= MAX_ARCHIVE_BYTES:
                        raise ValueError("artifact_size_unavailable_or_excessive")
                    data = api.request(f"/repos/{repository}/actions/artifacts/{artifact_id}/zip", limit=MAX_ARCHIVE_BYTES)
                    digest = artifact.get("digest")
                    if digest and digest != "sha256:" + sha(data):
                        raise ValueError("artifact_digest_mismatch")
                    rows, errors, amount = read_archive(data, {"kind": "github-artifact", **location})
                    expanded += amount
                    if expanded > MAX_HISTORY_BYTES:
                        raise ValueError("history_expanded_byte_bound")
                    authenticated = []
                    for row in rows:
                        source = row["record"].get("source", {})
                        attempt = positive_id(source.get("run_attempt")) if isinstance(source, dict) else None
                        if (not isinstance(source, dict) or positive_id(source.get("run_id")) != run_id
                                or source.get("commit") != run.get("head_sha") or attempt is None
                                or int(attempt) > int(run.get("run_attempt", 0))):
                            row["history_identity_error"] = "artifact_run_source_mismatch"
                            receipt["unavailable"].append({**location, "member": row["origin"].get("member"),
                                "line": row["origin"].get("line"), "reason": "artifact_run_source_mismatch"})
                        authenticated.append(row)
                    entries.extend(authenticated)
                    receipt["unavailable"].extend(errors)
                    receipt["artifacts"].append({**location, "sha256": sha(data), "records": len(rows)})
                except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, RuntimeError) as error:
                    receipt["unavailable"].append({**location, "reason": error_name(error)})
                if selected >= limit:
                    break
            if selected >= limit or len(artifacts) < 100:
                break
        receipt["status"] = "partial" if receipt["artifacts"] and receipt["unavailable"] else (
            "available" if receipt["artifacts"] else "unavailable")
        if not selected:
            receipt["unavailable"].append({"scope": "history", "reason": "no_completed_default_branch_artifacts"})
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        receipt["unavailable"].append({"scope": "history_lookup", "reason": error_name(error)})
        if receipt["artifacts"]:
            receipt["status"] = "partial"
    receipt["distinct_artifact_runs"] = len({item["run_id"] for item in receipt["artifacts"]})
    receipt["window_unit"] = "artifacts; multiple shard artifacts may belong to one workflow run"
    return deduplicate(entries), receipt


def settings() -> dict:
    values = execution_policy.identity()["advisories"]
    for key in ("rolling_window", "minimum_baseline_samples", "drift_window"):
        if type(values.get(key)) is not int or not 1 <= values[key] <= 100:
            raise ValueError("invalid history window policy")
    if not 1 < values["warning_ratio"] <= values["prominent_ratio"] or values["drift_ratio"] <= 1:
        raise ValueError("invalid advisory ratios")
    return values


def compact(entry: dict) -> dict:
    row = entry["record"]
    source = row.get("source", {})
    return {"record_sha256": entry.get("record_sha256"), "fixture": row.get("fixture"),
            "phase": row.get("phase"), "result": row.get("result"), "wall_seconds": row.get("wall_seconds"),
            "natural_completion": row.get("natural_completion"), "watchdog_reached": row.get("watchdog_reached"),
            "source": source, "recorded_utc": row.get("recorded_utc"), "origin": entry["origin"]}


def parent_commit(commit: str, previous: str) -> bool:
    if not all(isinstance(value, str) and HASH.fullmatch(value) for value in (commit, previous)):
        return False
    try:
        parents = subprocess.check_output(["git", "-C", str(execution_policy.ROOT), "show", "-s", "--format=%P", commit],
            stderr=subprocess.DEVNULL, timeout=execution_policy.watchdog_seconds("operation_seconds")).decode().split()
        return previous in parents
    except (OSError, subprocess.SubprocessError):
        return False


def source_changes(record: dict, samples: list[dict]) -> dict:
    def values(row):
        return {"commit": row["source"].get("commit"), "tree": row["source"].get("tree"),
                "fixture_sha256": row.get("fixture_sha256"),
                "shader_source_sha256": row["renderer"].get("shader_source_sha256"),
                "shader_variant_sha256": row["renderer"].get("shader_variant_sha256")}
    current = values(record)
    baseline = [values(entry["record"]) for sample in samples for entry in sample["entries"]]
    return {key: {"current": value, "baseline": sorted({row[key] for row in baseline if row[key] is not None}),
                  "changed": any(row[key] != value for row in baseline)} for key, value in current.items()}


def build_report(current: list[dict], history: list[dict], history_receipt: dict, input_errors: list[dict],
                 *, policy: dict | None = None, is_parent=parent_commit) -> dict:
    rules = policy or settings()
    current = deduplicate(current)
    history = deduplicate(history)
    current_runs = {positive_id(row["record"].get("source", {}).get("run_id")) for row in current
                    if isinstance(row["record"].get("source"), dict)} - {None}
    first_current = {}
    for entry in current:
        row = entry["record"]
        if not comparison_issues(row):
            key = execution_telemetry.cohort(row)
            first_current[key] = min(first_current.get(key, float("inf")), timestamp(row["recorded_utc"]))
    grouped, excluded = defaultdict(list), []
    for entry in history:
        row = entry["record"]
        issues = comparison_issues(row)
        if entry.get("history_identity_error"):
            issues.append(entry["history_identity_error"])
        if isinstance(row.get("source"), dict) and positive_id(row["source"].get("run_id")) in current_runs:
            issues.append("current_run_cannot_supply_its_baseline")
        if not issues:
            key = execution_telemetry.cohort(row)
            if key not in first_current:
                issues.append("incompatible_or_unrequested_cohort")
            elif timestamp(row["recorded_utc"]) >= first_current[key]:
                issues.append("history_not_earlier_than_current")
        if issues:
            excluded.append({**compact(entry), "excluded_for": issues})
        else:
            grouped[execution_telemetry.cohort(row)].append(entry)
    baselines, samples_by_cohort = {}, {}
    for key, entries in grouped.items():
        runs = defaultdict(list)
        for entry in entries:
            runs[positive_id(entry["record"]["source"]["run_id"])].append(entry)
        samples = []
        for run_id, rows in runs.items():
            latest_attempt = max(int(entry["record"]["source"]["run_attempt"]) for entry in rows)
            selected = [entry for entry in rows if int(entry["record"]["source"]["run_attempt"]) == latest_attempt]
            samples.append({"run_id": run_id, "run_attempt": str(latest_attempt), "entries": selected,
                            "time": max(timestamp(entry["record"]["recorded_utc"]) for entry in selected),
                            "wall_seconds": median(entry["record"]["wall_seconds"] for entry in selected)})
        samples.sort(key=lambda sample: (sample["time"], int(sample["run_id"])))
        samples = samples[-rules["rolling_window"]:]
        samples_by_cohort[key] = samples
        baselines[key] = {"sample_count": len(samples), "minimum_samples": rules["minimum_baseline_samples"],
                          "median_wall_seconds": median(sample["wall_seconds"] for sample in samples)
                            if len(samples) >= rules["minimum_baseline_samples"] else None,
                          "samples": [{**{field: sample[field] for field in ("run_id", "run_attempt", "wall_seconds")},
                                       "observations": [compact(entry) for entry in sample["entries"]]} for sample in samples]}
    comparisons, failures = [], []
    for entry in current:
        row = entry["record"]
        item = compact(entry)
        issues = comparison_issues(row)
        if row.get("result") != "passed" or row.get("natural_completion") is not True or row.get("watchdog_reached") is not False:
            failures.append(item)
        if issues:
            comparisons.append({**item, "comparison": "incomparable", "reasons": issues, "advisory": "none"})
            continue
        key = execution_telemetry.cohort(row)
        samples = samples_by_cohort.get(key, [])
        baseline = baselines.get(key)
        item.update(cohort=key, comparable_runs=len(samples), advisory="none")
        if not baseline or baseline["median_wall_seconds"] is None:
            comparisons.append({**item, "comparison": "insufficient_history", "minimum_samples": rules["minimum_baseline_samples"]})
            continue
        baseline_median = baseline["median_wall_seconds"]
        ratio = row["wall_seconds"] / baseline_median
        if not finite_number(ratio):
            comparisons.append({**item, "comparison": "incomparable", "reasons": ["nonfinite_derived_ratio"]})
            continue
        item.update(comparison="compared", baseline_median_wall_seconds=baseline_median, ratio=ratio,
                    source_changes=source_changes(row, samples))
        item["advisory"] = "prominent" if ratio >= rules["prominent_ratio"] else "warning" if ratio >= rules["warning_ratio"] else "none"
        steps = rules["drift_window"]
        values = [sample["wall_seconds"] for sample in samples[-steps:]] + [row["wall_seconds"]]
        cumulative_ratio = values[-1] / values[0] if len(values) == steps + 1 else None
        drift = (cumulative_ratio is not None and finite_number(cumulative_ratio)
                 and all(b > a for a, b in zip(values, values[1:])) and cumulative_ratio >= rules["drift_ratio"])
        item["drift"] = {"flagged": drift, "steps": steps, "wall_seconds": values,
                         "cumulative_ratio": cumulative_ratio if finite_number(cumulative_ratio) else None}
        if drift and item["advisory"] == "none":
            item["advisory"] = "gradual-drift"
        latest = samples[-1]
        previous = latest["entries"][0]["record"]["source"]["commit"]
        commit = row["source"]["commit"]
        if (ratio >= rules["warning_ratio"] and latest["wall_seconds"] / baseline_median < rules["warning_ratio"]
                and not any(entry["record"]["source"]["commit"] == commit for sample in samples for entry in sample["entries"])
                and is_parent(commit, previous)):
            item["introducing_commit_candidate"] = {"commit": commit, "previous_observed_commit": previous,
                "basis": "first observed threshold crossing after a verified direct parent in this history window",
                "causality_established": False}
        comparisons.append(item)
    return {"schema": SCHEMA, "generated_utc": datetime.now(timezone.utc).isoformat(), "advisory_only": True,
            "functional_status_changed": False, "rules": rules, "history": history_receipt,
            "current_record_count": len(current), "history_record_count": len(history),
            "current_input_errors": input_errors, "failed_or_incomplete_current": failures,
            "excluded_history": excluded, "baselines": baselines, "comparisons": comparisons,
            "limitations": ["Timing ratios do not prove a code cause or graphical/device acceptance.",
                "Unknown cohort fields prevent comparison; historical external providers never supply a GitHub-hosted baseline.",
                "A sample is the median of one distinct workflow run's latest represented successful attempt.",
                "Retrieval is bounded by artifacts, so multiple artifacts per run can leave fewer comparable runs than the requested rolling window.",
                "Gradual drift requires five increasing steps (six observations) under the initial policy."]}


def markdown(report: dict) -> str:
    def cell(value):
        return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ").replace("`", "'")
    compared = [row for row in report["comparisons"] if row["comparison"] == "compared"]
    flagged = [row for row in compared if row["advisory"] != "none"]
    lines = ["## Execution performance history", "", "Advisory only; functional test results are unchanged.", "",
             f"Current observations: {report['current_record_count']}; compared: {len(compared)}; "
             f"advisories: {len(flagged)}; failed or incomplete: {len(report['failed_or_incomplete_current'])}.",
             f"History: {report['history']['status']}; artifacts: {len(report['history'].get('artifacts', []))}; "
             f"unavailable history items: {len(report['history'].get('unavailable', []))}.", ""]
    if flagged:
        lines += ["| Fixture | Result | Seconds | Baseline median | Ratio | Advice |", "|---|---|---:|---:|---:|---|"]
        for row in flagged[:50]:
            lines.append(f"| {cell(row['fixture'])} | {cell(row['result'])} | {row['wall_seconds']:.3f} | "
                         f"{row['baseline_median_wall_seconds']:.3f} | {row['ratio']:.2f}× | {cell(row['advisory'])} |")
        if len(flagged) > 50:
            lines.append(f"\n{len(flagged) - 50} further advisories are retained in summary.json.")
    else:
        lines.append("No threshold advisory was established from the available comparable observations.")
    counts = Counter(row["comparison"] for row in report["comparisons"])
    lines += ["", f"Insufficient history: {counts['insufficient_history']}; incomparable: {counts['incomparable']}.",
              "Failed and excluded observations, exact baseline run/attempt/source identities and SHA changes are retained in summary.json.",
              "Unknown fields are never filled with a comparable host, compiler or cache state.", ""]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current", action="append", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--default-branch")
    parser.add_argument("--no-history", action="store_true")
    parser.add_argument("--include-jobs", action="store_true",
                        help="Retain completed current-run job durations using original runner observations")
    args = parser.parse_args(argv)
    try:
        if any(path.is_file() and path.resolve() == (args.output / "current.jsonl").resolve() for path in args.current):
            raise ValueError("output would replace a supplied raw observation file")
        current, errors = read_current(args.current, args.output)
        # Preserve every parsed current observation before any remote-history or
        # advisory-reduction failure can interfere with durable raw output.
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / "current.jsonl").write_text("".join(json.dumps(entry["record"], sort_keys=True, allow_nan=False) + "\n"
                                                       for entry in current), encoding="utf-8")
        jobs_receipt = {"status": "not_requested"}
        if args.include_jobs:
            try:
                import job_performance
                token = os.environ.get("GITHUB_TOKEN")
                if not token:
                    raise ValueError("job metadata token unavailable")
                rows, jobs_receipt = job_performance.collect(args.repository,
                    os.environ.get("GITHUB_RUN_ID", ""), os.environ.get("GITHUB_RUN_ATTEMPT", ""),
                    [entry["record"] for entry in current], GitHub(token))
                data = "".join(json.dumps(row, sort_keys=True, allow_nan=False) + "\n" for row in rows)
                with (args.output / "current.jsonl").open("a", encoding="utf-8") as output:
                    output.write(data)
                entries, rejected = parse_jsonl(data.encode(), {"scope": "current_completed_jobs"})
                current.extend(entries)
                errors.extend(rejected)
            except Exception as error:
                jobs_receipt = {"status": "unavailable", "reason": error_name(error)}
        rules = settings()
        if args.no_history:
            history, receipt = [], {"status": "not_requested", "artifacts": [], "unavailable": []}
        else:
            history, receipt = collect_history(args.repository, args.default_branch, rules["rolling_window"],
                token=os.environ.get("GITHUB_TOKEN"), current_run=os.environ.get("GITHUB_RUN_ID"))
        report = build_report(current, history, receipt, errors, policy=rules)
        report["whole_jobs"] = jobs_receipt
        (args.output / "summary.json").write_text(json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
        text = markdown(report)
        (args.output / "summary.md").write_text(text, encoding="utf-8")
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            try:
                with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a", encoding="utf-8") as stream:
                    stream.write(text)
            except OSError as error:
                report["presentation_errors"] = [{"scope": "step_summary", "reason": error_name(error)}]
                (args.output / "summary.json").write_text(json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
        print(f"PERFORMANCE_HISTORY advisory-only current={len(current)} history={len(history)} status={receipt['status']}")
    except Exception as error:
        # A reporting outage is separately visible; it cannot change functional
        # job acceptance or manufacture an elapsed-time baseline.
        print("PERFORMANCE_HISTORY unavailable: " + error_name(error), file=sys.stderr)
        try:
            args.output.mkdir(parents=True, exist_ok=True)
            (args.output / "summary.json").write_text(json.dumps({"schema": SCHEMA, "advisory_only": True,
                "functional_status_changed": False, "collector_status": "unavailable", "error": error_name(error)}) + "\n", encoding="utf-8")
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
