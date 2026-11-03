#!/usr/bin/env python3
"""Plan complete Godot matrices by expected cost, with separate safety ceilings."""

import argparse
import json
import math
import os
from pathlib import Path

import execution_policy as policy
import execution_telemetry
import run_godot_regressions as runner
import godot_scheduling as scheduling


def case_allowance(case: runner.Case) -> float:
    return scheduling.case_allowance(case.timeout)


def plan(cases: list[runner.Case], *, platform: str) -> dict:
    values = policy.identity()["watchdogs"]
    job_seconds = values["godot_job_minutes"] * 60
    execution_seconds = scheduling.execution_seconds()
    if not cases:
        raise ValueError("A complete platform suite must contain cases")
    if len(cases) > 256 * scheduling.MAX_CASES_PER_SHARD:
        raise ValueError("Complete suite exceeds the hosted matrix case-capacity limit")
    import_seconds = values["godot_import_seconds"] + policy.godot_process_cleanup_seconds()
    metadata_seconds = values["godot_metadata_seconds"]
    available = execution_seconds - import_seconds - metadata_seconds
    if available <= 0 or max(map(case_allowance, cases)) > available:
        raise ValueError("A child watchdog does not fit its hosted parent")
    if any(not scheduling.finite_positive(case.weight) for case in cases):
        raise ValueError("Scheduling weights must be finite and positive")
    if max(case.weight for case in cases) > available:
        raise ValueError("An estimated case exceeds the hosted execution boundary")
    maximum = min(len(cases), 256)
    minimum = min(maximum, max(1,
        math.ceil(sum(case.weight for case in cases) / scheduling.TARGET_CASE_SECONDS),
        math.ceil(len(cases) / scheduling.MAX_CASES_PER_SHARD)))
    for count in range(minimum, maximum + 1):
        shards, estimates = runner.build_shard_plan(cases, count)
        budgets = [sum(map(case_allowance, shard)) for shard in shards]
        if all(shards) and max(estimates) <= available:
            break
    else:
        raise ValueError("Complete suite cannot fit the hosted matrix limit")
    return {"schema": "godot-hosted-job-plan-v2", "platform": platform,
        "scheduling": scheduling.profile_identity(),
        "execution_policy": policy.identity(), "source": execution_telemetry.source_identity(policy.ROOT),
        "case_count": len(cases), "shard_count": count,
        "job_minutes": math.ceil(job_seconds / 60),
        "setup_artifact_seconds": values["godot_setup_seconds"],
        "aggregate_headroom_seconds": values["aggregate_headroom_seconds"],
        "import_with_cleanup_seconds": import_seconds,
        "metadata_seconds": metadata_seconds,
        "execution_seconds": execution_seconds,
        "execution_minutes": math.ceil(execution_seconds / 60),
        "expected_case_seconds": sum(estimates),
        "expected_critical_shard_seconds": max(estimates),
        "aggregate_admission": "Reserve full next-case ceiling and final metadata; unstarted cases fail incomplete",
        "matrix": {"shard": list(range(count))},
        "shards": [{"index": index, "case_budget_seconds": budgets[index],
            "watchdog_sum_is_execution_deadline": False,
            "largest_case_allowance_seconds": max(map(case_allowance, shard)),
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
