"""Aggregate all planned experiments; missing/failed trials cannot look green."""

import json
import os
import re
from pathlib import Path
import sys
from collections import Counter

from stress_physical_actors import SUSPECTS, progress_phase


def report_batch(path: Path) -> tuple[str, int] | None:
    match = re.search(r"(?:^|-)(windows|linux)-([0-4])(?:-|$)", path.parent.name)
    return (match[1], int(match[2])) if match else None


def summarize(root: Path, *, expected_source_sha=None, expected_run_id=None, expected_run_attempt=None) -> dict:
    counts = {}
    phases = Counter()
    errors = []
    identities = {}
    source_shas = set()
    campaigns = set()
    batches = Counter()
    reports = sorted(root.glob("*/stress.json"))
    if len(reports) != 10:
        errors.append(f"Expected ten batch reports, found {len(reports)}")
    for path in reports:
        batch = report_batch(path)
        if batch is None:
            errors.append(f"Invalid host/batch identity: {path}")
            continue
        host, batch_number = batch
        batches[batch] += 1
        try:
            report = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            errors.append(f"Unreadable batch evidence: {path}: {error}")
            continue
        identity = report["identity"]
        source_shas.add(identity["source_sha"])
        run_id, attempt = str(identity.get("run_id", "")), str(identity.get("attempt", ""))
        campaigns.add((run_id, attempt))
        if not run_id.isdecimal() or not attempt.isdecimal() or int(attempt) < 1:
            errors.append(f"Missing or invalid run/attempt identity: {path}")
        for label, actual, expected in (("source", identity["source_sha"], expected_source_sha),
                                        ("run", run_id, expected_run_id), ("attempt", attempt, expected_run_attempt)):
            if expected is not None and actual != str(expected):
                errors.append(f"Batch differs from declared {label}: {path}")
        runtime = tuple(identity[key] for key in ("native_sha256", "rapier_sha256", "godot_version"))
        if host in identities and identities[host] != runtime:
            errors.append(f"Mixed runtime identities for {host}: {path}")
        identities[host] = runtime
        if not report["completed"] or report["iterations_requested"] != 10:
            errors.append(f"Incomplete batch: {path}")
        expected = Counter((iteration, name) for iteration in range(10) for name in SUSPECTS)
        actual = Counter((result["iteration"], result["name"]) for result in report["results"])
        if actual != expected:
            errors.append(f"Trial identities are missing or duplicated: {path}")
        for result in report["results"]:
            key = host + "/" + result["name"]
            counts.setdefault(key, Counter())[result["status"]] += 1
            if result["status"] == "timeout":
                phases[key + "/" + progress_phase(result)] += 1
    for host in ("linux", "windows"):
        for batch in range(5):
            if batches[(host, batch)] != 1:
                errors.append(f"Expected one distinct batch {host}/{batch}, found {batches[(host, batch)]}")
        for case in SUSPECTS:
            key = host + "/" + case
            values = counts.get(key, Counter())
            if sum(values.values()) != 50 or values["passed"] != 50:
                errors.append(f"Required 50/50 passes for {key}: {dict(values)}")
    if len(source_shas) != 1:
        errors.append(f"Expected one source revision, found {sorted(source_shas)}")
    if len(campaigns) != 1:
        errors.append(f"Expected one run/attempt identity, found {sorted(campaigns)}")
    return {"source_shas": sorted(source_shas), "runtime_identities": identities,
            "campaign_ids": sorted(campaigns),
            "counts": {k: dict(v) for k, v in counts.items()}, "timeouts_by_phase": dict(phases), "errors": errors}


def main() -> int:
    root = Path(sys.argv[1])
    report = summarize(root, expected_source_sha=os.getenv("GITHUB_SHA"),
                       expected_run_id=os.getenv("GITHUB_RUN_ID"), expected_run_attempt=os.getenv("GITHUB_RUN_ATTEMPT"))
    (root / "summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    lines = ["| Host/test | Trials | Timeouts | Other failures |", "|---|---:|---:|---:|"]
    for key, counts in sorted(report["counts"].items()):
        total = sum(counts.values())
        lines.append(f"| {key} | {total} | {counts.get('timeout', 0)} | {total - counts.get('passed', 0) - counts.get('timeout', 0)} |")
    lines += ["", "Timeouts by last observed phase:", "```json", json.dumps(report["timeouts_by_phase"], indent=2), "```", *report["errors"]]
    text = "\n".join(lines) + "\n"
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(text)
    return int(bool(report["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
