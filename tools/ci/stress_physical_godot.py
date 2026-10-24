#!/usr/bin/env python3
"""Dispatch-only #233 stress harness: immutable source, exhaustive repeats, no retries."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from collections import Counter, defaultdict
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys

import run_godot_regressions as runner

CASES = ("test_physical_actor_arena", "test_physical_actor_rigs", "test_physical_usable_course")


def summarize(records: list[dict]) -> list[dict]:
    groups = defaultdict(list)
    for row in records:
        if row["role"] != "case":
            continue
        groups[row["name"]].append(row)
    result = []
    for name in CASES:
        rows = groups[name]
        duration = sorted(float(row["seconds"]) for row in rows)
        phases = Counter(
            re.search(r"\bphase=([\w-]+)", row.get("last_progress") or "").group(1)
            if re.search(r"\bphase=([\w-]+)", row.get("last_progress") or "")
            else "no-progress"
            for row in rows if row["status"] == "timeout"
        )
        result.append({
            "name": name, "count": len(rows),
            "passed": sum(row["status"] == "passed" for row in rows),
            "timeouts": sum(row["status"] == "timeout" for row in rows),
            "failures_or_skips": sum(row["status"] not in ("passed", "timeout") for row in rows),
            "median_seconds": round(statistics.median(duration), 3) if duration else None,
            "p95_seconds": duration[max(0, (95 * len(duration) + 99) // 100 - 1)] if duration else None,
            "max_seconds": max(duration) if duration else None,
            "timeout_by_last_phase": dict(sorted(phases.items())),
        })
    return result


def save(output: Path, report: dict) -> None:
    destination = output / "stress-summary.json"
    temp = output / "stress-summary.json.tmp"
    temp.write_text(json.dumps(report, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    temp.replace(destination)


def case_environment(folder: Path) -> dict[str, str]:
    environment = os.environ.copy()
    # Run concurrent Godot processes with distinct writable user data. The
    # checked-out source/project is intentionally identical and shared.
    for name in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = folder / name.lower()
        path.mkdir(parents=True, exist_ok=True)
        environment[name] = str(path)
    if sys.platform == "win32":
        for name in ("APPDATA", "LOCALAPPDATA"):
            path = folder / name.lower()
            path.mkdir(parents=True, exist_ok=True)
            environment[name] = str(path)
    # Native libraries can write temporary files without consulting XDG or
    # APPDATA. Keep those writes isolated in the three-process condition too.
    temporary = folder / "tmp"
    temporary.mkdir(parents=True, exist_ok=True)
    for name in ("TMPDIR", "TEMP", "TMP"):
        environment[name] = str(temporary)
    return environment


def execute(godot: str, case: runner.Case, repetition: int, output: Path) -> dict:
    location = output / ("repeat-%03d" % repetition) / case.name
    location.mkdir(parents=True, exist_ok=True)
    record, _failed = runner.run_case(
        godot, case, location, "case", env=case_environment(location / "userdata"),
    )
    record["repetition"] = repetition
    # Preserve finished attempts even if a later invocation/harness failure
    # interrupts the batch before its next summary checkpoint.
    (location / "attempt-result.json").write_text(
        json.dumps(record, sort_keys=True, indent=2) + "\n", encoding="utf-8",
    )
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mode", required=True, choices=("serial", "parallel"))
    parser.add_argument("--repetitions", type=int, default=10)
    parser.add_argument("--batch", type=int, default=0)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_source_sha):
        parser.error("expected source must be a full SHA-1 commit ID")
    if not 0 <= args.batch <= 9:
        parser.error("batch must be between 0 and 9")
    if args.repetitions < 1 or args.repetitions > 100:
        parser.error("repetitions must be between 1 and 100")

    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError("Refused: stress output must be empty; preserve prior campaign evidence")
    output.mkdir(parents=True, exist_ok=True)
    source = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=runner.ROOT, text=True,
    ).strip()
    if source != args.expected_source_sha:
        raise RuntimeError("Refused: checkout does not match the exact registered source commit")
    native, rapier = runner.runtime_paths()
    if not native.is_file() or not rapier.is_file():
        raise RuntimeError("Refused: native and Rapier runtimes must be materialized")
    candidates = {case.name: case for case in runner.discover_cases()}
    if any(name not in candidates or candidates[name].requires_display for name in CASES):
        raise RuntimeError("Refused: physical stress catalogue differs from declared headless scope")
    version = subprocess.check_output([args.godot, "--version"], text=True, timeout=30).strip()
    report = {
        "status": "running", "completed": False, "source_sha": source,
        "godot_version": version, "mode": args.mode, "repetitions": args.repetitions,
        "batch": args.batch,
        "run_id": os.getenv("GITHUB_RUN_ID"), "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
        "platform": sys.platform, "cases": list(CASES),
        "native_sha256": runner.sha256(native), "rapier_sha256": runner.sha256(rapier),
        "results": [], "summary": [],
    }
    save(output, report)
    preflight = runner.Case("import", ("--editor", "--quit"), 240, 3.0)
    record, failed = runner.run_case(args.godot, preflight, output, "preflight")
    report["results"].append(record)
    save(output, report)
    if failed:
        report["status"] = "failed"
        save(output, report)
        return 1

    selected = [candidates[name] for name in CASES]
    for local_index in range(1, args.repetitions + 1):
        repetition = args.batch * args.repetitions + local_index
        if args.mode == "serial":
            rows = [execute(args.godot, case, repetition, output) for case in selected]
        else:
            # Three process-isolated shards run at the same source, each case
            # exactly once per repetition. No automatic retries or hiding fail.
            with ThreadPoolExecutor(max_workers=len(selected)) as pool:
                futures = [pool.submit(execute, args.godot, case, repetition, output) for case in selected]
                rows = [future.result() for future in futures]
        report["results"].extend(rows)
        report["summary"] = summarize(report["results"])
        save(output, report)
        print(
            "STRESS_PROGRESS repeat=%d/%d mode=%s timeouts=%d" %
            (local_index, args.repetitions, args.mode,
             sum(item["timeouts"] for item in report["summary"])),
            flush=True,
        )

    observed = Counter((row["name"], row["repetition"]) for row in report["results"]
                       if row["role"] == "case")
    expected = Counter((name, repetition) for name in CASES
                       for repetition in range(args.batch * args.repetitions + 1, (args.batch + 1) * args.repetitions + 1))
    report["completed"] = observed == expected
    report["status"] = (
        "passed" if report["completed"] and all(
            row["status"] == "passed" for row in report["results"]
        ) else "failed"
    )
    save(output, report)
    print("STRESS_RESULT", report["status"], json.dumps(report["summary"], sort_keys=True), flush=True)
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
