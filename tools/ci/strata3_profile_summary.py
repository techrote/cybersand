#!/usr/bin/env python3
"""Summarize already source-qualified optical cohorts without inventing acceptance.

Load the frozen application's strict original reader, then retain per-repeat
physical/native rates and tails. Whole-process CPU/RSS includes scene setup and
the observer; it is never allocated to individual profiles by this summarizer.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
from pathlib import Path
import statistics
import subprocess
import sys

APPLICATION = "fd0830abcfadd9ae19162e5677943bb131223e59"
TREE = "fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def population(values):
    require(len(values) == 3, "Expected the three preregistered repeats")
    return {"original_order": values, "minimum": min(values),
            "median": statistics.median(values), "maximum": max(values)}


def cohort(samples):
    profiles = {}
    for sample in samples:
        profiles.setdefault(sample["profile"], []).append(sample)
    require(len(profiles) == 5 and "classic" in profiles, "Expected the registered five-profile cohort")
    summaries = {}
    for name, rows in profiles.items():
        require([row["repeat"] for row in rows] == [0, 1, 2], "Repeat order changed")
        value = {"quality": rows[0]["quality"],
                 "native_ticks_per_second": population([row["native_ticks_per_second"] for row in rows]),
                 "rapier_ticks_per_second": population([row["rapier_ticks_per_second"] for row in rows]),
                 "physical_p95_usec": population([row["physical_distribution_usec"]["p95"] for row in rows]),
                 "physical_p99_usec": population([row["physical_distribution_usec"]["p99"] for row in rows]),
                 "physical_maximum_usec": population([row["physical_distribution_usec"]["max"] for row in rows]),
                 "callback_p95_usec": population([row["callback_distribution_usec"]["p95"] for row in rows]),
                 "godot_process_monitor_mean_ms": population([statistics.mean(row["godot_process_ms"]) for row in rows]),
                 "repeats": [{"repeat": row["repeat"], "elapsed_usec": row["elapsed_usec"],
                              "native_tick_delta": row["after"]["native_tick"]-row["before"]["native_tick"],
                              "rapier_tick_delta": row["after"]["rapier_tick"]-row["before"]["rapier_tick"],
                              "scene_admission_elapsed_ms": row["scene_admission_elapsed_ms"],
                              "scene_admission_target_met": row["scene_admission_target_met"],
                              "physical_intervals_usec": row["physical_distribution_usec"],
                              "native_publication_intervals_usec": row["native_publication_interval_distribution_usec"],
                              "callback_intervals_usec": row["callback_distribution_usec"],
                              "actor_distance_cells": row["actor_distance_cells"],
                              "native_capture_delta": row["native_capture_delta"],
                              "decorative_upload_delta": row["decorative_upload_delta"]} for row in rows]}
        summaries[name] = value
    baseline = summaries["classic"]
    for name, value in summaries.items():
        ratios = {key: value[key]["median"]/baseline[key]["median"]
                  for key in ("native_ticks_per_second", "rapier_ticks_per_second")}
        limit = max(1.2*baseline["physical_p95_usec"]["median"], baseline["physical_p95_usec"]["median"]+10000)
        value["median_comparison_to_classic"] = {
            "native_rate_ratio": ratios["native_ticks_per_second"],
            "rapier_rate_ratio": ratios["rapier_ticks_per_second"],
            "physical_p95_limit_usec": limit,
            "observed_native_rate_target_met": ratios["native_ticks_per_second"] >= .90,
            "observed_rapier_rate_target_met": ratios["rapier_ticks_per_second"] >= .90,
            "observed_physical_p95_target_met": value["physical_p95_usec"]["median"] <= limit,
            "interpretation": "Observed median targets only. Review repeat spread, p99/max and stalls before adjudicating; no physical GPU or perceptual acceptance."}
    return summaries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application-root", type=Path, required=True)
    parser.add_argument("--campaign", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.application_root.resolve(strict=True)
    head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"]).decode().strip()
    tree = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD^{tree}"]).decode().strip()
    require((head, tree) == (APPLICATION, TREE), "Use the unchanged frozen application checkout for original source custody")
    sys.path.insert(0, str(root / "tools/ci"))
    q = importlib.import_module("qualify_strata3_workbench")
    require(q.ROOT.resolve() == root, "Reader imported from a different application checkout")
    source = q.identity()
    reports = []
    for argument in args.campaign:
        folder = argument.resolve(strict=True)
        campaign = q.verify_campaign(folder, expected=source, full=True)
        rows = [case for case in campaign["cases"] if case["phase"] == "progression"]
        require(len(rows) == 1, "Expected the one registered native progression process")
        case = rows[0]
        results = [item["result"] for item in campaign["cases"] if "result" in item]
        for item in campaign["cases"]:
            if item["phase"] in ("install", "reopen", "motion", "progression"):
                result = item["result"]
                require(type(result.get("admission_elapsed_ms")) is int and result["admission_elapsed_ms"] >= 0
                        and result.get("admission_target_met") == (result["admission_elapsed_ms"] <= 45000),
                        "Initial scene admission differs from the unchanged 45-second criterion")
        reports.append({"platform": campaign["platform"], "campaign_sha256": sha(folder / "campaign.json"),
                        "source_commit": source["source_commit"], "source_tree": source["source_tree"],
                        "suite": campaign["suite"], "godot": campaign["godot"],
                        "rendering_adapters": sorted({row["rendering_adapter"] for row in results if "rendering_adapter" in row}),
                        "case_count_including_headless_import": len(campaign["cases"]),
                        "embedded_native_harness_checks_excluding_regression_markers": sum(row.get("checks", 0) for row in results),
                        "admissions": [{"scene": item["scene"], "phase": item["phase"],
                                        "elapsed_ms": item["result"]["admission_elapsed_ms"],
                                        "target_ms": 45000, "target_met": item["result"]["admission_target_met"]}
                                       for item in campaign["cases"] if item["phase"] in ("install", "reopen", "motion", "progression")],
                        "progression_report_sha256": case["report_sha256"],
                        "profiles": cohort(case["result"]["progression_samples"]),
                        "whole_progression_process_resources": case["process"]["resources"],
                        "whole_progression_process_elapsed_seconds": case["process"]["seconds"],
                        "resource_scope": "Includes initial admission, fifteen per-window scene reloads, warmups and observation. Not per-profile CPU, RSS or GPU time.",
                        "human_performance_adjudication": "PENDING independent review of raw repeat populations and host variance"})
    result = {"schema": "strata3-profile-research-summary-v1", "source_commit": APPLICATION, "source_tree": TREE,
              "summarizer_sha256": sha(Path(__file__).resolve()),
              "qualification_reader": "Frozen application tools/ci/qualify_strata3_workbench.py; full verification performed before summary",
              "registration": {"minimum_median_native_rate_ratio": .90, "minimum_median_rapier_rate_ratio": .90,
                               "physical_p95_limit": "max(1.20 * Classic p95, Classic p95 + 10000 usec)",
                               "physical_gpu_acceptance": False}, "campaigns": reports}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output.resolve()), "sha256": sha(args.output),
                      "platforms": [row["platform"] for row in reports]}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        print("PROFILE_SUMMARY_REJECTED: "+str(error), file=sys.stderr)
        raise SystemExit(1)
