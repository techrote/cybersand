#!/usr/bin/env python3
"""Independent, read-only-source SOL364 hosted cost arithmetic and custody review.

Writes only review outputs beside this script. Does not download, execute a
runtime, alter source, or import the repository's cost analyzer.
"""
from __future__ import annotations

import argparse
import collections
import datetime
import functools
import gzip
import hashlib
import json
import math
from pathlib import Path
import statistics
import zipfile

RUN = 41815817333
SOURCE = {"sha": "9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d",
          "tree": "b5baf8b23ff947c2d7b70e69745c10f18fbe9ebe"}
HISTORICAL = "749fb8b597ad866f7535f26442e904207c4f7611"
CANONICAL_ROOT = f"docs/audits/sol281-20261103/hosted/{SOURCE['sha']}"
RUNTIMES = {"Linux": "de38c0de458b2a30d43cb36c633cb7ee3b469f8d84f7a3e512fafc9838bb82a5",
            "Windows": "a5e616c0e72eee56c84f66151499d401dd3f4fb7faab347adbc6335493fefd61"}
LIMIT = 2.0
EXPECTED = {(p, w) for p in ("Linux", "Windows") for w in (1, 4)}
RESPONSE_STAGES = ("rid_state", "planner", "impulse_apply", "readback", "other")
OWNER_STAGES = ("native_call", "envelope", "native_geometry", "native_payload_freeze")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def numeric(value):
    return type(value) in (int, float) and math.isfinite(value)


def close(a, b, label, tolerance=1e-6):
    require(numeric(a) and numeric(b) and abs(a - b) <= tolerance, label)


def stats(values):
    values = list(values)
    if not values:
        return {"n": 0, "min": None, "median": None, "max": None,
                "mean": None, "sample_variance": None, "sample_standard_deviation": None}
    return {"n": len(values), "min": min(values), "median": statistics.median(values),
            "max": max(values), "mean": statistics.mean(values),
            "sample_variance": statistics.variance(values) if len(values) > 1 else None,
            "sample_standard_deviation": statistics.stdev(values) if len(values) > 1 else None}


@functools.lru_cache(maxsize=None)
def artifact(base, name):
    metadata = read(Path(__file__).resolve().parent / "github-contact-artifacts.json")
    items = [item for item in metadata["artifacts"] if item["name"] == name]
    require(len(items) == 1, "Missing or duplicate independently retrieved artifact metadata")
    item = items[0]
    require(item["workflow_run"]["id"] == RUN and item["workflow_run"]["head_sha"] == SOURCE["sha"],
            "GitHub artifact belongs to a different run/source")
    path = base / (name + ".zip")
    require(path.stat().st_size == item["size_in_bytes"] and "sha256:" + sha(path) == item["digest"],
            "Artifact ZIP differs from independently retrieved GitHub digest/size")
    return item, path


def check_members(archive_path, directory, files):
    with zipfile.ZipFile(archive_path) as archive:
        for path in files:
            member = path.relative_to(directory).as_posix()
            require(hashlib.sha256(archive.read(member)).hexdigest() == sha(path),
                    "Extracted file differs from authenticated ZIP member: " + member)


def authenticate(base, platform, workers):
    directory = base / "cohorts" / platform.lower() / f"contact-w{workers}"
    report_path = directory / ("host/report.json" if platform == "Linux" else "report.json")
    if not report_path.exists():
        return None
    report = read(report_path)
    require(report.get("schema") == "cybersand.sol281.qualification.v1"
            and report.get("source") == SOURCE, f"Wrong hosted source: {report_path}")
    require(report.get("platform") == platform and report.get("cohort") == f"contact-w{workers}"
            and report.get("status") == "passed" and report.get("errors") == []
            and report.get("source_unchanged") is True
            and report.get("checkout_inputs_unchanged") is True,
            f"Failed or mismatched hosted cohort: {report_path}")
    build_path = base / f"build-{platform.lower()}" / "build.json"
    build = read(build_path)
    before_path = build_path.parent / "before.json"
    before = read(before_path)
    require(build.get("source") == SOURCE and before.get("source") == SOURCE
            and build.get("before_manifest_sha256") == sha(before_path)
            and build.get("inputs") == before.get("inputs")
            and build.get("checkout_inputs") == before.get("checkout_inputs"),
            f"Build before/after source custody differs: {build_path}")
    require(report.get("build_manifest_sha256") == sha(build_path)
            and report.get("runtime") == build.get("runtime")
            and build["runtime"]["sha256"] == RUNTIMES[platform], "Host/build pinned runtime receipt differs")
    runtime_path = build_path.parent / build["runtime"]["filename"]
    require(sha(runtime_path) == build["runtime"]["sha256"]
            and runtime_path.stat().st_size == build["runtime"]["size"], "Built runtime bytes differ")
    input_path = report_path.parent / "inputs-before.json"
    inputs = read(input_path)
    checkout = read(report_path.parent / "checkout-inputs-before.json")
    require(inputs == read(report_path.parent / "inputs-after.json") == build["inputs"],
            "Hosted normalized inputs differ from build or changed during execution")
    require(checkout == read(report_path.parent / "checkout-inputs-after.json")
            and set(checkout) == set(inputs), "Hosted raw checkout changed or inventory differs")
    records = [r for r in report["records"] if r.get("name") == f"contact-recovery-w{workers}"]
    require(len(records) == 1, "Missing or duplicate recovery process receipt")
    record = records[0]
    require(record.get("status") == "passed" and record.get("returncode") == 0
            and record.get("natural_completion") is True and record.get("skip_messages") == [],
            "Recovery process did not naturally pass")
    result_path = report_path.parent / record["result"]["path"]
    require(result_path.resolve().is_relative_to(report_path.parent.resolve()), "Unsafe result path")
    require(sha(result_path) == record["result"]["sha256"], "Canonical result hash differs")
    log_path = report_path.parent / record["log"]
    require(sha(log_path) == record["log_sha256"], "Recovery process log hash differs")
    raw = read(result_path)
    footer = record.get("readback", {})
    require(raw.get("schema") == "cybersand.sol281.contact-recovery.v1"
            and raw.get("platform") == platform and raw.get("workers") == workers
            and raw.get("checks") == 290 and raw.get("failures") == [] and len(raw.get("cases", [])) == 18,
            "Incomplete canonical asynchronous report")
    require(all(footer.get(key) == raw.get(key) for key in ("schema", "platform", "workers", "checks", "failures"))
            and footer.get("case_count") == 18, "Concise footer differs from canonical report")
    artifact_name = f"sol281-host-{platform.lower()}-contact-w{workers}-{RUN}-1"
    build_name = f"sol281-build-{platform.lower()}-{RUN}-1"
    host_artifact, host_zip = artifact(base, artifact_name)
    build_artifact, build_zip = artifact(base, build_name)
    check_members(host_zip, directory, [report_path, result_path, log_path, input_path,
        report_path.parent / "inputs-after.json", report_path.parent / "checkout-inputs-before.json",
        report_path.parent / "checkout-inputs-after.json"])
    check_members(build_zip, build_path.parent, [build_path, before_path, runtime_path])
    return raw, {"platform": platform, "workers": workers, "source": SOURCE,
        "workflow_run_url": f"https://github.com/techrote/cybersand/actions/runs/{RUN}",
        "cohort_artifact": {key: host_artifact[key] for key in ("id", "name", "digest", "size_in_bytes")},
        "build_artifact": {key: build_artifact[key] for key in ("id", "name", "digest", "size_in_bytes")},
        "cohort_report": str(report_path.relative_to(base)), "cohort_report_sha256": sha(report_path),
        "repository_cohort_report": f"{CANONICAL_ROOT}/{report_path.relative_to(base).as_posix()}",
        "build_manifest": str(build_path.relative_to(base)), "build_manifest_sha256": sha(build_path),
        "repository_build_manifest": f"{CANONICAL_ROOT}/build/{platform.lower()}/build.json",
        "canonical_result": str(result_path.relative_to(base)), "canonical_result_sha256": sha(result_path),
        "repository_canonical_result": f"{CANONICAL_ROOT}/{result_path.relative_to(base).as_posix()}",
        "log_sha256": sha(log_path), "normalized_input_count": len(inputs),
        "normalized_inputs_sha256": sha(input_path), "runtime": build["runtime"],
        "runtime_repository_path": "godot/addons/cybersand_native/bin/" + build["runtime"]["filename"],
        "compiler": build.get("compiler"), "bindings": build.get("bindings"),
        "engine": report.get("engine"), "rapier": report.get("rapier"),
        "process_elapsed_seconds": record.get("seconds"),
        "process_resources": record.get("resources"),
        "scope": "Runtime bytes and receipt chain independently authenticated; source inputs unchanged."}


def analyze_case(case, platform, workers, new=True):
    physical = case["metrics"]["physical_contact"]
    n = physical["observations"]
    attempts = physical["worker_observation_attempts"]
    response_attempts = physical["response_attempts"]
    accepts = physical["response_accepts"]
    owner = physical["worker_contact_ms_total"]
    response = physical["response_ms_all_attempts"]
    require(type(n) is int and n > 0 and type(attempts) is int
            and attempts >= n + physical["refused_observations"], "Invalid observation inventory")
    require(case["steps"] == 360 and len(case["trace"]) == n
            and len({point["snapshot"] for point in case["trace"]}) == n,
            "Complete consumed denominator differs from unique trace receipts")
    require(all(numeric(x) and x >= 0 for x in (owner, response)), "Invalid inclusive work")
    require(response_attempts == accepts + sum(physical["response_refusals"].values())
            + sum(physical["response_failures"].values()), "Missing main response attempt")
    require(physical["energy_violations"] == 0 and physical["response_failures"] == {}, "Response failure")
    require(case["sand_before"] == case["sand_after"] and case["water_before"] == case["water_after"],
            "Native quantity changed")
    response_trace_available = all("response" in point for point in case["trace"])
    require(response_trace_available or not new, "Current hosted trace lacks response details")
    accepted_trace = [point["response"] for point in case["trace"] if point.get("response", {}).get("accepted")]
    if response_trace_available:
        require(len(accepted_trace) == accepts, "Accepted trace receipts differ from response counter")
        close(sum(item["application_ms"] for item in accepted_trace), physical["response_ms_total"],
              "Accepted application timing differs from original trace")
        close(sum(item["publication_latency_ms"] for item in accepted_trace), physical["latency_ms_total"],
              "Accepted latency timing differs from original trace")
    result = {"platform": platform, "workers": workers, "id": case["id"],
        "fixture": case["surroundings"], "candidate": case["candidate"], "repeat": case["repeat"],
        "declared_steps": case["steps"], "complete_consumed_observations": n,
        "trace_receipts": len(case["trace"]), "consumed_refused_observations": physical["refused_observations"],
        "owner_attempts": attempts, "owner_work_ms": owner, "response_work_ms": response,
        "total_work_ms": owner + response, "cost_ms_per_complete_observation": (owner + response) / n,
        "gate_passed": (owner + response) / n <= LIMIT,
        "owner_ms_per_attempt": owner / attempts, "owner_attempt_ms_max": physical["worker_contact_ms_max"],
        "response_attempts": response_attempts, "response_accepts": accepts,
        "response_refusals": physical["response_refusals"], "response_failures": physical["response_failures"],
        "response_ms_per_attempt": response / response_attempts if response_attempts else None,
        "response_attempt_ms_max": physical["response_ms_max_attempt"],
        "worker_geometry_probes": physical["worker_geometry_probes"],
        "worker_support_probes": physical["worker_support_probes"],
        "trace_response_details_available": response_trace_available,
        "consumed_native_observation_ms": stats(point["observation_ms"] for point in case["trace"]),
        "accepted_response_application_ms": stats(point["response"]["application_ms"] for point in case["trace"]
            if point.get("response", {}).get("accepted")),
        "accepted_publication_latency_ms": stats(point["response"]["publication_latency_ms"] for point in case["trace"]
            if point.get("response", {}).get("accepted")),
        "accepted_publication_latency_total_ms": physical["latency_ms_total"],
        "max_sand_penetration_cells": physical["max_sand_penetration"],
        "overlap_cell_samples": physical["overlap_cell_samples"],
        "sand_area_samples": physical["sand_area_samples"],
        "max_translation_cells": case["max_translation"], "max_rotation_rad": case["max_rotation"],
        "max_angular_velocity_rad_s": case["max_angular_velocity"],
        "impulse_magnitude_sum": physical["impulse_magnitude_sum"],
        "response_energy_change_sum": physical["energy_change_sum"],
        "energy_readback_violations": physical["energy_violations"]}
    if new:
        owner_stages = {stage: physical[f"worker_{stage}_ms_all_attempts"] for stage in OWNER_STAGES}
        response_stages = {stage: physical[f"response_{stage}_ms_all_attempts"] for stage in RESPONSE_STAGES}
        require(all(numeric(value) and value >= -1e-6 for value in (*owner_stages.values(), *response_stages.values())),
                "Invalid/missing all-attempt stages")
        close(owner_stages["native_call"] + owner_stages["envelope"], owner, "Owner work partition differs")
        close(sum(response_stages.values()), response, "Response work partition differs")
        require(physical["worker_complete_attempts"] + physical["worker_refused_attempts"] == attempts
                and physical["worker_complete_attempts"] >= n
                and physical["owner_ready_receipts"] == n + physical["refused_observations"],
                "Owner complete/refused/ready receipt accounting differs")
        evaluated_trace = [point["response"] for point in case["trace"] if point.get("response", {}).get("evaluated")]
        require(len(evaluated_trace) == response_attempts
                and dict(collections.Counter(item["outcome"] for item in evaluated_trace if not item.get("accepted")))
                    == physical["response_refusals"], "Evaluated/refused trace inventory differs from all-attempt counters")
        for stage in RESPONSE_STAGES[:-1]:
            close(sum(item.get(stage + "_ms", 0) for item in evaluated_trace), response_stages[stage],
                  "All-attempt response stage differs from original trace: " + stage)
        result.update(owner_stages_ms=owner_stages, response_stages_ms=response_stages,
            owner_complete_attempts=physical["worker_complete_attempts"],
            owner_refused_attempts=physical["worker_refused_attempts"],
            complete_owner_attempts_not_consumed=physical["worker_complete_attempts"] - n,
            unconsumed_or_setup_owner_attempts=attempts - n - physical["refused_observations"],
            owner_ready_receipts=physical["owner_ready_receipts"],
            owner_ready_latency_total_ms=physical["owner_ready_latency_ms_total"],
            owner_ready_latency_mean_ms=physical["owner_ready_latency_ms_total"] / physical["owner_ready_receipts"],
            owner_ready_latency_max_ms=physical["owner_ready_latency_ms_max"])
    return result


def grouping(cases):
    buckets = collections.defaultdict(list)
    for case in cases:
        buckets[(case["platform"], case["workers"], case["fixture"], case["candidate"])].append(case)
    groups = []
    for (platform, workers, fixture, candidate), values in sorted(buckets.items()):
        values.sort(key=lambda c: c["repeat"])
        require([c["repeat"] for c in values] == [0, 1, 2], "Incomplete repeat group")
        worst = max(values, key=lambda c: c["cost_ms_per_complete_observation"])
        groups.append({"platform": platform, "workers": workers, "fixture": fixture, "candidate": candidate,
            "repeat_means_ms": [c["cost_ms_per_complete_observation"] for c in values],
            "cost_distribution": stats(c["cost_ms_per_complete_observation"] for c in values),
            "passed": all(c["gate_passed"] for c in values),
            "worst_repeat": worst["repeat"], "worst_owner_ms": worst["owner_work_ms"],
            "worst_response_ms": worst["response_work_ms"],
            "worst_observations": worst["complete_consumed_observations"],
            "owner_attempts_range": [min(c["owner_attempts"] for c in values), max(c["owner_attempts"] for c in values)],
            "observations_range": [min(c["complete_consumed_observations"] for c in values), max(c["complete_consumed_observations"] for c in values)],
            "depth_range_cells": [min(c["max_sand_penetration_cells"] for c in values), max(c["max_sand_penetration_cells"] for c in values)]})
    return groups


def summarize_work(cases):
    if not cases:
        return {}
    sums = {field: sum(case[field] for case in cases) for field in (
        "owner_work_ms", "response_work_ms", "total_work_ms", "owner_attempts", "owner_complete_attempts",
        "owner_refused_attempts", "complete_consumed_observations", "response_attempts", "response_accepts",
        "complete_owner_attempts_not_consumed", "unconsumed_or_setup_owner_attempts", "consumed_refused_observations",
        "owner_ready_receipts", "owner_ready_latency_total_ms", "accepted_publication_latency_total_ms")}
    sums["owner_stages_ms"] = {stage: sum(case["owner_stages_ms"][stage] for case in cases) for stage in OWNER_STAGES}
    sums["response_stages_ms"] = {stage: sum(case["response_stages_ms"][stage] for case in cases) for stage in RESPONSE_STAGES}
    sums["response_refusals"] = dict(sum((collections.Counter(case["response_refusals"]) for case in cases), collections.Counter()))
    sums["owner_ready_latency_mean_ms"] = sums["owner_ready_latency_total_ms"] / sums["owner_ready_receipts"]
    sums["owner_ready_latency_max_ms"] = max(case["owner_ready_latency_max_ms"] for case in cases)
    sums["accepted_publication_latency_mean_ms"] = sums["accepted_publication_latency_total_ms"] / sums["response_accepts"]
    sums["accepted_publication_latency_max_ms"] = max(case["accepted_publication_latency_ms"]["max"] or 0 for case in cases)
    sums["owner_per_attempt_means_ms"] = stats(case["owner_ms_per_attempt"] for case in cases)
    sums["candidate_response_per_attempt_means_ms"] = stats(case["response_ms_per_attempt"] for case in cases if case["candidate"])
    sums["owner_attempt_ms_max"] = max(case["owner_attempt_ms_max"] for case in cases)
    sums["response_attempt_ms_max"] = max(case["response_attempt_ms_max"] for case in cases)
    sums["planner_fraction_of_summed_response_work"] = sums["response_stages_ms"]["planner"] / sums["response_work_ms"]
    return sums


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True, help="Repository checkout containing preserved earlier receipts")
    parser.add_argument("--base", type=Path, required=True, help="Authenticated extracted artifacts, with build-linux/build-windows and cohorts subdirectories")
    args = parser.parse_args()
    output = Path(__file__).resolve().parent
    cases, custody, missing = [], [], []
    for platform, workers in sorted(EXPECTED):
        pair = authenticate(args.base, platform, workers)
        if pair is None:
            missing.append({"platform": platform, "workers": workers})
            continue
        raw, receipt = pair
        expected = [(kind, repeat, arm) for kind in ("packed_sand", "embedded_sand", "mixed")
                    for repeat in range(3) for arm in ((False, True) if repeat % 2 == 0 else (True, False))]
        require([(c["surroundings"], c["repeat"], c["candidate"]) for c in raw["cases"]] == expected,
                "Canonical repeat inventory changed")
        custody.append(receipt)
        cases.extend(analyze_case(case, platform, workers) for case in raw["cases"])
    groups = grouping(cases)
    historical_cases, historical_hashes = [], []
    old_base = args.repo / "docs/audits/sol281-20261103/hosted" / HISTORICAL / "cohorts"
    for path in sorted(old_base.glob("**/contact-recovery-w*.json")):
        raw = read(path)
        historical_hashes.append({"path": str(path.relative_to(args.repo)), "sha256": sha(path)})
        historical_cases.extend(analyze_case(case, raw["platform"], raw["workers"], False) for case in raw["cases"])
    historical_groups = grouping(historical_cases)
    old_failure = next(case for case in historical_cases if case["platform"] == "Windows"
        and case["workers"] == 4 and case["id"] == "embedded_sand/baseline/r0")
    local_path = args.repo / "docs/audits/sol364-20261104/development-cost/contact-recovery-w1.json.gz"
    local_bytes = gzip.decompress(local_path.read_bytes())
    local = json.loads(local_bytes)
    local_case = next(case for case in local["cases"] if case["id"] == "embedded_sand/candidate/r2")
    local_failure = analyze_case(local_case, "Linux", 1, False)
    preserved = {"original_windows_failure": old_failure,
        "original_sources": historical_hashes,
        "local_development_failure": local_failure,
        "local_source": {"path": str(local_path.relative_to(args.repo)), "gzip_sha256": sha(local_path),
                         "uncompressed_sha256": hashlib.sha256(local_bytes).hexdigest()},
        "historical_groups": historical_groups,
        "disposition": "Both original failures remain failed receipts; later runs do not revise their limits or outcomes."}
    complete = len(groups) == 24 and not missing and len(cases) == 72
    passed = sum(group["passed"] for group in groups)
    cohort_summaries = [{"platform": platform, "workers": workers,
        **summarize_work([case for case in cases if (case["platform"], case["workers"]) == (platform, workers)])}
        for platform, workers in sorted({(case["platform"], case["workers"]) for case in cases})]
    analysis = {"schema": "cybersand.sol364.independent-hosted-cost-review.v1", "run_id": RUN,
        "source": SOURCE, "review_script_sha256": sha(Path(__file__).resolve()),
        "repository_canonical_root": CANONICAL_ROOT,
        "repository_review_directory": "docs/audits/sol364-20261104/hosted-review/",
        "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "threshold_ms": LIMIT, "observed_cases": len(cases), "expected_cases": 72,
        "observed_groups": len(groups), "expected_groups": 24, "passed_groups": passed,
        "baseline_groups_passed": sum(g["passed"] for g in groups if not g["candidate"]),
        "candidate_groups_passed": sum(g["passed"] for g in groups if g["candidate"]),
        "complete": complete, "verdict": ("PASS" if passed == 24 else "FAIL") if complete else "INCOMPLETE",
        "missing_cohorts": missing, "groups": groups, "cohort_custody": custody,
        "cohort_work_summaries": cohort_summaries, "all_case_work_summary": summarize_work(cases),
        "timing": "Elapsed monotonic work intervals, not operating-system thread CPU time.",
        "numerator": "Cumulative owner observation/envelope work at the final consumed receipt plus all main Sand-response attempts.",
        "timing_scope": "Registered owner interval covers native observation/value construction plus metadata envelope/freezing; bridge response calls are measured separately. Cumulative metrics bookkeeping occurs after ready timestamp and shared publication is outside the historical contact interval. This is not whole simulation/snapshot CPU or separately measured mutex CPU.",
        "denominator": "Complete consumed observations; unique complete trace receipts are independently counted.",
        "gate": "Each of 24 groups passes only if all three unrounded repeat means are <= 2 ms.",
        "stages": "Native call + envelope = inclusive owner. Native geometry/payload freeze are nested in native call; do not add again. Five response stages sum to inclusive response.",
        "latency": "Owner ready-to-receipt includes observed handoff/scheduling. Accepted publication latency extends to response and uses only accepts; the two must not be added.",
        "missing_observations": "Unconsumed/setup attempts are not all proven overwritten publications; no unobserved overlap is invented.",
        "comparison": "Independent asynchronous repeats are descriptive distributions, not identical-input causal comparisons.",
        "physical_acceptance": "A CPU pass does not establish sustained clearance, merge readiness, graphical acceptance or GPU frame pacing."}
    write_json(output / "cost-review.json", analysis)
    write_json(output / "case-accounting-annex.json", {"schema": "cybersand.sol364.independent-cost-cases.v1",
        "source": SOURCE, "run_id": RUN, "cases": cases, "case_count": len(cases)})
    write_json(output / "preserved-cost-failures.json", preserved)
    old_lookup = {(group["platform"], group["workers"], group["fixture"], group["candidate"]): group for group in historical_groups}
    comparison = [{"platform": group["platform"], "workers": group["workers"], "fixture": group["fixture"],
        "candidate": group["candidate"], "historical": old_lookup[(group["platform"], group["workers"], group["fixture"], group["candidate"])],
        "current": group} for group in groups]
    write_json(output / "before-after-groups.json", {"historical_source": HISTORICAL, "current_source": SOURCE,
        "scope": "Separate asynchronous distributions, not matched histories or a causal optimization speedup.", "groups": comparison})
    lines = ["# SOL364 hosted contact cost review", "", f"Run `{RUN}`; source `{SOURCE['sha']}`; tree `{SOURCE['tree']}`.", "",
        f"**Registered matrix: {analysis['verdict']}; {passed}/{len(groups)} observed groups pass; {len(groups)}/24 groups and {len(cases)}/72 cases available.**",
        "", "The fixed criterion is 2 ms per complete consumed observation, with all owner and main response attempts retained in the numerator. Each group uses its largest unrounded repeat mean.",
        "", "## Group results", "", "All numbers below are elapsed work in ms per complete observation. SD is the sample standard deviation of the three repeat means.", "",
        "| Platform | Workers | Fixture | Arm | r0 | r1 | r2 | SD | Worst repeat accounting (owner + response)/N | Gate |",
        "|---|---:|---|---|---:|---:|---:|---:|---|---|"]
    for group in groups:
        values = group["repeat_means_ms"]
        lines.append(f"| {group['platform']} | {group['workers']} | {group['fixture']} | {'candidate' if group['candidate'] else 'baseline'} | "
            + " | ".join(f"{value:.9f}" for value in values)
            + f" | {group['cost_distribution']['sample_standard_deviation']:.9f} | r{group['worst_repeat']}: ({group['worst_owner_ms']:.3f} + {group['worst_response_ms']:.3f})/{group['worst_observations']} | {'PASS' if group['passed'] else 'FAIL'} |")
    lines += ["", "## All-attempt work and receipt totals", "",
        "| Platform | Workers | Owner attempts (complete/refused) | Complete consumed | Main attempts (accept/refuse) | Owner ms | Response ms | Planner ms | Ready latency mean/max ms | Accepted publication latency mean/max ms |",
        "|---|---:|---|---:|---|---:|---:|---:|---|---|"]
    for summary in cohort_summaries:
        lines.append(f"| {summary['platform']} | {summary['workers']} | {summary['owner_attempts']} ({summary['owner_complete_attempts']}/{summary['owner_refused_attempts']}) | "
            f"{summary['complete_consumed_observations']} | {summary['response_attempts']} ({summary['response_accepts']}/{sum(summary['response_refusals'].values())}) | "
            f"{summary['owner_work_ms']:.3f} | {summary['response_work_ms']:.3f} | {summary['response_stages_ms']['planner']:.3f} | "
            f"{summary['owner_ready_latency_mean_ms']:.6f}/{summary['owner_ready_latency_max_ms']:.3f} | "
            f"{summary['accepted_publication_latency_mean_ms']:.6f}/{summary['accepted_publication_latency_max_ms']:.3f} |")
    lines += ["", "## Preserved failures", "",
        f"- Historical Windows w4 embedded baseline r0: {old_failure['owner_work_ms']:.3f} ms owner + {old_failure['response_work_ms']:.3f} ms response, {old_failure['owner_attempts']} owner attempts / {old_failure['complete_consumed_observations']} complete consumed = **{old_failure['cost_ms_per_complete_observation']:.12f} ms, FAIL**.",
        f"- Local Linux w1 embedded candidate r2: {local_failure['owner_work_ms']:.3f} ms owner + {local_failure['response_work_ms']:.3f} ms response, {local_failure['owner_attempts']} owner attempts and {local_failure['response_attempts']} response attempts / {local_failure['complete_consumed_observations']} complete consumed = **{local_failure['cost_ms_per_complete_observation']:.12f} ms, FAIL**.",
        "", "## Accounting and interpretation", "",
        "Native geometry and payload-freezing timings are nested inside native-call work. Only native-call + envelope + the five disjoint response stages form the inclusive numerator. Unconsumed/setup owner attempts remain included, but their count is not a claim that every one was overwritten.", "",
        "The registered owner interval covers native observation/value construction and metadata envelope/freezing. Cumulative metrics bookkeeping follows the ready timestamp; shared publication lies outside that historical interval. This is not a whole simulation/snapshot CPU budget, and mutex CPU is not measured separately.", "",
        "Owner ready-to-receipt latency and accepted publication-to-response latency use distinct endpoints and denominators. These are elapsed monotonic intervals, not OS thread CPU measurements. Whole-process resource receipts, where present, are a separate process-wide quantity.", "",
        "The JSON annex retains all trial numerators, denominators, attempts, refusals, stage totals, latency means/maxima and observed motion/depth. Historical asynchronous before/after ranges are descriptive; no matched-trajectory or continuous-overlap claim is made.", "",
        "## Evidence files", "", "- `cost-review.json`: group gates, variance and source/runtime custody.",
        "- `case-accounting-annex.json`: all available cases, with a required final inventory of 72.",
        "- `preserved-cost-failures.json`: both earlier failed receipts and all original 24 group summaries.",
        "- `before-after-groups.json`: old/new per-group repeat ranges, maxima, SD and observation denominators.",
        "- `github-contact-artifacts.json`: independently retrieved GitHub artifact IDs, ZIP digests, byte sizes and source/run identity.",
        "- `review_cost.py`: independent reproducible calculation; does not import the repository analyzer.", "",
        "## Reproduction and portable identities", "",
        f"Canonical published raw evidence belongs under `{CANONICAL_ROOT}/`; each cohort receipt in `cost-review.json` records its portable repository path, artifact name, source commit/tree and exact hashes.", "",
        "Retrieve the named build/host artifacts from the run and retain the original build DLL/ELF. Extract build artifacts into `build-linux/` and `build-windows/`; host artifacts into `cohorts/<platform>/contact-w<workers>/` preserving their ZIP structure. Then run:", "",
        "```sh", "python3 review_cost.py --repo /path/to/cybersand --base /path/to/extracted-artifacts", "```", "",
        "The review requires the actual hosted binaries and hashes them. The earlier local development ELF is not an accepted substitute. Source and GitHub state remain unchanged.", ""]
    (output / "cost-review.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({key: analysis[key] for key in ("run_id", "verdict", "observed_cases", "observed_groups", "passed_groups", "missing_cohorts")}, sort_keys=True))


if __name__ == "__main__":
    main()
