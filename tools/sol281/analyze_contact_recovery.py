#!/usr/bin/env python3
"""Describe repeated SOL281 geometry observations without trajectory matching."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import run_qualification as qualification

CPU_LIMIT_MS = 2.0
EXPECTED_COHORTS = {(platform, workers) for platform in ("Linux", "Windows") for workers in (1, 4)}


def full_matrix_cost_gate(cohorts: list[dict]) -> dict:
    """Never promote a candidate-only or missing-host result to the full gate."""
    observed = [(cohort["platform"], cohort["workers"]) for cohort in cohorts]
    if len(set(observed)) != len(observed) or not set(observed) <= EXPECTED_COHORTS:
        raise ValueError("Duplicate or unexpected cost cohort")
    groups = []
    for cohort in cohorts:
        expected = {(kind, arm) for kind in ("packed_sand", "embedded_sand", "mixed") for arm in (False, True)}
        seen = [(group["surroundings"], group["candidate"]) for group in cohort["groups"]]
        if len(set(seen)) != len(seen) or set(seen) != expected:
            raise ValueError("Incomplete or duplicate original cost groups")
        for group in cohort["groups"]:
            value = group["metrics"]["combined_contact_ms_per_observation"]["max"]
            if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                raise ValueError("Invalid cost mean")
            groups.append({"platform": cohort["platform"], "workers": cohort["workers"],
                           "surroundings": group["surroundings"], "candidate": group["candidate"],
                           "maximum_repeat_mean_ms": value, "passed": value <= CPU_LIMIT_MS})
    complete = set(observed) == EXPECTED_COHORTS and len(groups) == 24
    passed = sum(group["passed"] for group in groups)
    return {"limit_ms": CPU_LIMIT_MS, "expected_groups": 24, "observed_groups": len(groups),
            "passed_groups": passed, "complete": complete,
            "verdict": ("PASS" if passed == 24 else "FAIL") if complete else "INCOMPLETE",
            "candidate_groups_passed": sum(group["passed"] for group in groups if group["candidate"]),
            "baseline_groups_passed": sum(group["passed"] for group in groups if not group["candidate"]),
            "failed_groups": [group for group in groups if not group["passed"]],
            "missing_cohorts": [{"platform": platform, "workers": workers}
                                for platform, workers in sorted(EXPECTED_COHORTS - set(observed))],
            "numerator": "all owner observation/envelope attempts plus all main response attempts",
            "denominator": "complete consumed observations; each group uses the largest of its three repeat means",
            "timing": "elapsed monotonic work intervals; not operating-system thread CPU time"}


def analyze(paths: list[Path]) -> dict:
    cohorts = []
    for path in paths:
        raw = path.read_bytes()
        report = json.loads(raw)
        spec = next(x for x in qualification.inventory(f"contact-w{report.get('workers')}")
                    if x.script == "test_solid_detachment_contact_recovery")
        qualification.verify_footer(spec, spec.footer + " " + json.dumps(report), report.get("platform"))
        if (report.get("schema") != "cybersand.sol281.contact-recovery.v1"
                or report.get("failures") != [] or report.get("checks") != 290
                or len(report.get("cases", [])) != 18):
            raise ValueError(f"Incomplete/failed original recovery report: {path}")
        seen = set()
        groups = {}
        for case in report["cases"]:
            key = (case["surroundings"], case["candidate"])
            identity = (*key, case["repeat"])
            if identity in seen:
                raise ValueError("Duplicate case identity")
            seen.add(identity)
            metrics = case["metrics"]
            physical = metrics["physical_contact"]
            observations = physical["observations"]
            if observations <= 0 or case["steps"] != 360 or not case["trace"]:
                raise ValueError("Missing geometry/step inventory")
            if case["sand_before"] != case["sand_after"] or case["water_before"] != case["water_after"]:
                raise ValueError("Material quantity differs")
            span_start = None
            longest_span = 0
            positive_samples = 0
            for point in case["trace"]:
                if point["sand_overlap_area"] > 1e-9:
                    positive_samples += 1
                    if span_start is None:
                        span_start = point["source_published_usec"]
                    longest_span = max(longest_span, point["source_published_usec"] - span_start)
                else:
                    span_start = None
            values = {
                "max_sand_penetration_cells": physical["max_sand_penetration"],
                "mean_overlap_cells_per_observation": physical["overlap_cell_samples"] / observations,
                "mean_overlap_area_per_observation": physical["area_samples"] / observations,
                "mean_sand_overlap_area_per_observation": physical["sand_area_samples"] / observations,
                "geometry_ms_per_observation": physical["geometry_ms_total"] / observations,
                "combined_contact_ms_per_observation": (physical["worker_contact_ms_total"] + physical["response_ms_all_attempts"]) / observations,
                "worker_observation_attempts": physical["worker_observation_attempts"],
                "worker_ms_per_attempt": physical["worker_contact_ms_total"] / physical["worker_observation_attempts"],
                "response_attempts": physical["response_attempts"],
                "response_ms_per_attempt": physical["response_ms_all_attempts"] / max(1, physical["response_attempts"]),
                "positive_sand_overlap_observations": positive_samples,
                "longest_positive_observation_span_seconds": longest_span / 1e6,
                "geometry_ms_max": physical["geometry_ms_max"],
                "geometry_probes_per_observation": physical["geometry_probes"] / observations,
                "response_ms_per_accept": physical["response_ms_total"] / max(1, physical["response_accepts"]),
                "publication_latency_ms_per_accept": physical["latency_ms_total"] / max(1, physical["response_accepts"]),
                "impulse_magnitude_sum": physical["impulse_magnitude_sum"],
                "torque_impulse_sum": physical["torque_impulse_sum"],
                "response_energy_change_sum": physical["energy_change_sum"],
                "observations": observations,
                "response_accepts": physical["response_accepts"],
                "refused_observations": physical["refused_observations"],
                "max_translation_cells": case["max_translation"],
                "max_rotation_rad": case["max_rotation"],
                "max_angular_velocity_rad_s": case["max_angular_velocity"],
            }
            # Additive SOL364 stage counters preserve the original inclusive
            # numerator. Native geometry/freezing are NESTED within native call
            # time and must never be added a second time to contact work.
            if "worker_native_call_ms_all_attempts" in physical:
                stage_fields = ("worker_native_geometry_ms_all_attempts", "worker_native_payload_freeze_ms_all_attempts",
                                "worker_native_call_ms_all_attempts", "worker_envelope_ms_all_attempts")
                if any(type(physical.get(field)) not in (int, float) or not math.isfinite(physical[field])
                       or physical[field] < 0 for field in stage_fields):
                    raise ValueError("Incomplete or invalid all-attempt stage timing")
                if abs(physical["worker_native_call_ms_all_attempts"] + physical["worker_envelope_ms_all_attempts"]
                       - physical["worker_contact_ms_total"]) > 1e-6:
                    raise ValueError("Inclusive owner work differs from native-call/envelope sum")
                if physical.get("worker_complete_attempts", -1) + physical.get("worker_refused_attempts", -1) \
                        != physical["worker_observation_attempts"]:
                    raise ValueError("Complete/refused owner attempt inventory differs")
                values.update({field: physical[field] for field in stage_fields})
                values.update({"worker_complete_attempts": physical["worker_complete_attempts"],
                               "worker_refused_attempts": physical["worker_refused_attempts"],
                               "unconsumed_or_setup_owner_attempts": physical["worker_observation_attempts"]
                                   - observations - physical.get("refused_observations", 0),
                               "owner_ready_receipts": physical.get("owner_ready_receipts", 0),
                               "owner_ready_latency_ms_max": physical.get("owner_ready_latency_ms_max", 0.0),
                               "owner_ready_latency_ms_per_receipt": physical.get("owner_ready_latency_ms_total", 0.0)
                                   / max(1, physical.get("owner_ready_receipts", 0))})
            groups.setdefault(key, []).append({"values": values, "case": case})
        expected = {(kind, arm, repeat) for kind in ("packed_sand", "embedded_sand", "mixed")
                    for arm in (False, True) for repeat in range(3)}
        if seen != expected:
            raise ValueError("Wrong complete cohort inventory")
        summaries = []
        for (kind, arm), items in sorted(groups.items()):
            stats = {}
            for metric in items[0]["values"]:
                sample = [x["values"][metric] for x in items]
                stats[metric] = {"min": min(sample), "median": statistics.median(sample), "max": max(sample),
                                 "mean": statistics.mean(sample), "sample_variance": statistics.variance(sample),
                                 "sample_standard_deviation": statistics.stdev(sample), "n": len(sample)}
            refusals = {}
            for item in items:
                for name, count in item["case"]["metrics"]["physical_contact"]["response_refusals"].items():
                    refusals[name] = refusals.get(name, 0) + count
            summaries.append({"surroundings": kind, "candidate": arm, "repetitions": len(items),
                              "metrics": stats, "response_refusals": refusals,
                              "case_values": [{"id": item["case"]["id"], "repeat": item["case"]["repeat"],
                                               "values": item["values"]} for item in items],
                              "proposed_contact_cost_gate_passed": stats["combined_contact_ms_per_observation"]["max"] <= CPU_LIMIT_MS,
                              "energy_readback_gate_passed": all(x["case"]["metrics"]["physical_contact"]["energy_violations"] == 0 for x in items)})
        cohorts.append({"platform": report["platform"], "workers": report["workers"],
                        "original": str(path), "sha256": hashlib.sha256(raw).hexdigest(), "groups": summaries})
    return {"schema": "cybersand.sol281.contact-recovery-analysis.v1", "cohorts": cohorts,
            "full_matrix_cost_gate": full_matrix_cost_gate(cohorts),
            "interpretation": "Descriptive ranges/medians over independent asynchronous runs, not causal paired comparisons. "
                              "Exact geometry is at copied native publication poses. Counts are observation samples, not cell-ticks. "
                              "Positive-overlap span is the time between consecutive positive sampled publications, not proof of unobserved continuity. "
                              "Response energy excludes separate gravity, ordinary coupling, damping and hard contacts. "
                              "Cost gate includes all worker attempts (including overwritten publications and refusals) "
                              "and every main response attempt, divided conservatively by complete consumed observations. "
                              "CPU cost is provisional; no GPU or human gameplay acceptance."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.reports)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(result["interpretation"])
    print("Full registered CPU matrix:", json.dumps(result["full_matrix_cost_gate"], sort_keys=True))
    for cohort in result["cohorts"]:
        print(f"{cohort['platform']} workers={cohort['workers']}")
        for group in cohort["groups"]:
            m = group["metrics"]
            def show(key):
                v = m[key]
                return f"{v['median']:.6g} [{v['min']:.6g},{v['max']:.6g}]"
            print(group["surroundings"], "candidate" if group["candidate"] else "baseline",
                  "depth", show("max_sand_penetration_cells"),
                  "mean area", show("mean_sand_overlap_area_per_observation"),
                  "geometry ms", show("geometry_ms_per_observation"),
                  "refusals", group["response_refusals"])


if __name__ == "__main__":
    main()
