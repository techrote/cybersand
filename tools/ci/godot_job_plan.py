#!/usr/bin/env python3
"""Derive complete Godot matrices whose sequential watchdogs fit hosted jobs.

The historical runtime weights only distribute work. They never shorten a
child's maximum allowance or turn an elapsed-time observation into a failure.
"""

import argparse
import json
import math
import os
from pathlib import Path

import execution_policy as policy
import execution_telemetry
import run_godot_regressions as runner


def case_allowance(case: runner.Case) -> float:
    values = policy.identity()["watchdogs"]
    return case.timeout + values["operation_seconds"] + policy.godot_process_cleanup_seconds()


def plan(cases: list[runner.Case], *, platform: str) -> dict:
    values = policy.identity()["watchdogs"]
    job_seconds = values["godot_job_minutes"] * 60
    if job_seconds > 360 * 60:
        raise ValueError("Scaled Godot job exceeds the GitHub-hosted six-hour limit")
    if not cases:
        raise ValueError("A complete platform suite must contain cases")
    import_seconds = values["godot_import_seconds"] + policy.godot_process_cleanup_seconds()
    reserved = values["godot_setup_seconds"] + values["aggregate_headroom_seconds"]
    metadata_seconds = values["godot_metadata_seconds"]
    available = job_seconds - reserved - import_seconds - metadata_seconds
    if available <= 0 or max(map(case_allowance, cases)) > available:
        raise ValueError("A child watchdog does not fit its hosted parent")
    minimum = max(1, math.ceil(sum(map(case_allowance, cases)) / available))
    for count in range(minimum, min(len(cases), 256) + 1):
        shards, estimates = runner.build_shard_plan(cases, count)
        budgets = [sum(map(case_allowance, shard)) for shard in shards]
        if all(shards) and max(budgets) <= available:
            break
    else:
        raise ValueError("Complete suite cannot fit the hosted matrix limit")
    execution_seconds = math.ceil(max(budgets) + import_seconds + metadata_seconds)
    return {"schema": "godot-hosted-job-plan-v1", "platform": platform,
        "execution_policy": policy.identity(), "source": execution_telemetry.source_identity(policy.ROOT),
        "case_count": len(cases), "shard_count": count,
        "job_minutes": math.ceil(job_seconds / 60),
        "setup_artifact_seconds": values["godot_setup_seconds"],
        "aggregate_headroom_seconds": values["aggregate_headroom_seconds"],
        "import_with_cleanup_seconds": import_seconds,
        "metadata_seconds": metadata_seconds,
        "execution_seconds": execution_seconds,
        "execution_minutes": math.ceil(execution_seconds / 60),
        "matrix": {"shard": list(range(count))},
        "shards": [{"index": index, "case_budget_seconds": budgets[index],
            "estimated_seconds": estimates[index],
            "cases": [runner.case_dict(case) for case in shard]}
            for index, shard in enumerate(shards)]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    cases = runner.discover_cases()
    plans = {platform: plan([case for case in cases if platform == "linux" or not case.requires_display], platform=platform)
             for platform in ("linux", "windows")}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(plans, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for platform, value in plans.items():
        print(f"{platform}: {value['case_count']} cases in {value['shard_count']} complete shards; "
              f"execution {value['execution_minutes']}m inside {value['job_minutes']}m parent")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            for platform, value in plans.items():
                for key in ("matrix", "shard_count", "job_minutes", "execution_minutes", "execution_seconds"):
                    output.write(f"{platform}_{key}={json.dumps(value[key], separators=(',', ':'))}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
