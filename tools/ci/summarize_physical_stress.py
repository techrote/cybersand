"""Aggregate all planned experiments; missing/failed trials cannot look green."""

import json
import os
from pathlib import Path
import sys
from collections import Counter

from stress_physical_actors import SUSPECTS


def summarize(root: Path) -> dict:
    counts = {}
    phases = Counter()
    errors = []
    identities = {}
    source_shas = set()
    reports = sorted(root.glob("*/stress.json"))
    if len(reports) != 10:
        errors.append(f"Expected ten batch reports, found {len(reports)}")
    for path in reports:
        report = json.loads(path.read_text(encoding="utf-8"))
        host = "windows" if "windows" in path.parent.name else "linux"
        identity = report["identity"]
        source_shas.add(identity["source_sha"])
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
                phases[key + "/" + (result.get("last_progress") or {}).get("phase", "before-first-marker")] += 1
    for host in ("linux", "windows"):
        for case in SUSPECTS:
            key = host + "/" + case
            values = counts.get(key, Counter())
            if sum(values.values()) != 50 or values["passed"] != 50:
                errors.append(f"Required 50/50 passes for {key}: {dict(values)}")
    if len(source_shas) != 1:
        errors.append(f"Expected one source revision, found {sorted(source_shas)}")
    return {"source_shas": sorted(source_shas), "runtime_identities": identities,
            "counts": {k: dict(v) for k, v in counts.items()}, "timeouts_by_phase": dict(phases), "errors": errors}


def main() -> int:
    root = Path(sys.argv[1])
    report = summarize(root)
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
