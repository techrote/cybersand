#!/usr/bin/env python3
"""Independent evidence audit, without importing the production budget checker."""
from pathlib import Path
import datetime
import hashlib
import json
import math
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/audits/objectshard-001r-20261122/native-performance"
HEAD = "514d76fbf4df30eb05353bc14b6a4ec3ea9bf61c"
OUT = Path(__file__).resolve().parent
errors = []
checks = 0

def check(value, detail):
    global checks
    checks += 1
    if not value:
        errors.append(detail)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def read(path):
    return json.loads(path.read_text())

def blob(commit, path):
    return subprocess.check_output(["git", "show", f"{commit}:{path}"], cwd=ROOT)

budget_path = "tools/objectshard/native_budgets.json"
budget_bytes = blob(HEAD, budget_path)
budget = json.loads(budget_bytes)
stable_paths = [budget_path, "tools/objectshard/run_benchmarks.py", "native/tests/benchmark_object_shard.cpp"]
stable = {}
for p in stable_paths:
    historical = blob("dc4282e5f5f9b886315e8450613740d265f5fbc3", p)
    current = blob(HEAD, p)
    check(historical == current, f"Harness or budget changed: {p}")
    stable[p] = sha(current)

custody = read(EVIDENCE / "artifact-custody.json")
custody_findings = []
for name, expected in custody["sha256"].items():
    p = EVIDENCE / name
    actual = sha(p.read_bytes()) if p.is_file() else None
    check(actual == expected, f"Evidence custody mismatch: {name}")
    custody_findings.append({"path": name, "actual_sha256": actual, "matched": actual == expected})

bindings = []
for name in ("final-514d-inputs.json", "focused-final-514d-inputs.json", "m2-control-inputs.json", "f11-memory-negative-inputs.json"):
    d = read(EVIDENCE / name)
    specification = {k: v for k, v in d.items() if k not in ("git_head", "git_status", "input_digest", "source_root")}
    computed_digest = sha(json.dumps(specification, sort_keys=True).encode())
    check(computed_digest == d["input_digest"], f"Input digest mismatch: {name}")
    mismatches = []
    for path, expected in d["sources"].items():
        actual = sha(blob(d["git_head"], path))
        check(actual == expected, f"Git source mismatch: {name}/{path}")
        if actual != expected:
            mismatches.append(path)
    bindings.append({"manifest": name, "head": d["git_head"], "input_digest": computed_digest,
                     "files": len(d["sources"]), "mismatches": mismatches})

expected_names = {"empty_lab", "inert_stationary", "inert_moving", "reacting_one", "reacting_three",
                  "perforated_reacting", "saturated_world_destinations", "dormant_twelve", "wake_burst_twelve",
                  "compact_vs_tuned_serial_miniature"}

def qualify(report):
    failures = []
    count = 0
    names = [c["name"] for c in report["cases"]]
    check(set(names) == expected_names and len(names) == len(set(names)), "Missing/duplicate workload")
    def limit(name, actual, maximum):
        nonlocal count
        count += 1
        if not math.isfinite(actual) or actual > maximum:
            failures.append({"name": name, "actual": actual, "maximum": maximum})
    for case in report["cases"]:
        name = case["name"]
        if name == "compact_vs_tuned_serial_miniature":
            for candidate in ("compact", "miniature"):
                limit(f"{name}.{candidate}.allocations", case["memory"][f"{candidate}_steady_allocations"],
                      budget["comparison_requirements"]["steady_cpp_allocations_each_candidate"])
            continue
        frame = case["timings"]["native_frame_including_snapshot_receipt"]
        check(frame["samples"] >= budget["minimum_frame_samples_per_workload"], f"Insufficient samples: {name}")
        for metric in ("p95", "p99", "max"):
            limit(f"{name}.frame.{metric}_us", frame[f"{metric}_us"], budget["integrated_limits"][f"native_frame_{metric}_us"])
        for metric in ("cpp_live_max_bytes", "cpp_peak_max_bytes", "registry_retained_max_bytes"):
            limit(f"{name}.{metric}", case["memory"][metric], budget["integrated_limits"][metric])
        limit(f"{name}.steady_allocations", case["memory"]["steady_allocations"], budget["integrated_limits"]["steady_cpp_allocations"])
        limit(f"{name}.geometry_age_ticks", case["observations"]["geometry_age_max_ticks"], budget["integrated_limits"]["geometry_age_max_ticks"])
    check(count == 74, "Threshold count not 74")
    return {"count": count, "failures": failures}

cohorts = {}
for name in ("m2-control", "f11-memory-negative", "repaired-memory", "final-514d"):
    report = read(EVIDENCE / f"{name}-benchmark.json")
    summary = read(EVIDENCE / f"{name}-summary.json")
    computed = qualify(report)
    check(len(computed["failures"]) == len(summary["budget_qualification"]["failures"]), f"Failure count discrepancy {name}")
    check(summary["checks"] == report["checks"] and summary["failures"] == report["failures"] == 0,
          f"Functional count discrepancy {name}")
    binary = Path(summary["execution"]["command"][0])
    actual_sha = sha(binary.read_bytes())
    check(actual_sha == summary["binary_sha256"], f"Binary custody mismatch {name}")
    raw = Path(summary["execution"]["log"])
    check(read(raw) == report, f"Raw executable report differs {name}")
    cohorts[name] = {**computed, "assertions": report["checks"], "binary_sha256": actual_sha}

historical = ROOT / "docs/audits/objectshard-001-20261122/portable-math/native-result.json"
old_report = read(historical)
cohorts["historical_m2_final_failure"] = qualify(old_report)
check(len(cohorts["historical_m2_final_failure"]["failures"]) == 10, "Historical 10/74 failure not retained")

paired = EVIDENCE / "paired-pre-telemetry"
plan = read(paired / "plan.json")
runs = read(paired / "runs.json")
check([r["cohort"] for r in runs] == plan["order"] == ["control", "candidate", "candidate", "control", "control", "candidate"],
      "Paired sequence discrepancy")
check(datetime.datetime.fromisoformat(plan["registered_utc"]) <= datetime.datetime.fromisoformat(runs[0]["started_utc"]),
      "Paired plan timestamp not before observations")
observations = {"control": {}, "candidate": {}}
for run in runs:
    report = read(paired / f"{run['index']:02d}-{run['cohort']}.json")
    result = qualify(report)
    check(not result["failures"] and run["returncode"] == 0 and report["failures"] == 0,
          f"Paired run not green: {run['index']}")
    check(run["checks"] == report["checks"], f"Paired count mismatch {run['index']}")
    check(sha(Path(run["command"][0]).read_bytes()) == run["binary_sha256"], f"Paired binary mismatch {run['index']}")
    for case in report["cases"]:
        if case["name"] == "compact_vs_tuned_serial_miniature":
            continue
        observations[run["cohort"]].setdefault(case["name"], []).append(case)

calculated = {}
published = read(paired / "comparison.json")["cases"]
for name in observations["control"]:
    out = {}
    for cohort in ("control", "candidate"):
        frames = [case["timings"]["native_frame_including_snapshot_receipt"] for case in observations[cohort][name]]
        stats = {}
        for metric in ("p50", "p95", "p99", "max"):
            values = [frame[f"{metric}_us"] for frame in frames]
            stats[metric] = {"median": statistics.median(values), "minimum": min(values), "maximum": max(values)}
            check(stats[metric] == published[name][cohort]["frame_us"][metric], f"Paired statistics mismatch {name}/{cohort}/{metric}")
        out[cohort] = stats
    out["change_percent"] = {metric: (out["candidate"][metric]["median"] / out["control"][metric]["median"] - 1) * 100
                             for metric in ("p50", "p95", "p99")}
    calculated[name] = out

san = read(EVIDENCE / "focused-final-514d-summary.json")
san_checks = 0
san_failures = 0
san_hashes = {}
for name, suite in san["suites"].items():
    san_checks += suite["checks"]
    san_failures += suite["failures"]
    b = Path(suite["execution"]["command"][0])
    digest = sha(b.read_bytes())
    check(digest == suite["binary_sha256"], f"Sanitizer binary mismatch {name}")
    log = Path(suite["execution"]["log"]).read_text()
    check(f"{suite['checks']} checks, {suite['failures']} failures" in log, f"Sanitizer log count mismatch {name}")
    check(suite["execution"]["returncode"] == 0 and not suite["execution"]["timed_out"], f"Sanitizer execution failed {name}")
    san_hashes[name] = digest
check(san_checks == san["checks_reported"] == 34895 and san_failures == san["failures_reported"] == 0, "Sanitizer aggregate mismatch")

result = {"schema": 1, "reviewed_head": HEAD, "reviewed_tree": subprocess.check_output(["git", "rev-parse", HEAD+"^{tree}"],cwd=ROOT,text=True).strip(),
          "independent_checks": checks, "errors": errors, "unchanged_harness_sha256": stable,
          "artifact_custody": custody_findings, "source_bindings": bindings, "cohorts": cohorts,
          "paired_recomputed": calculated, "sanitizers": {"checks": san_checks, "failures": san_failures, "binary_hashes": san_hashes},
          "scope": "Independent recomputation and source/custody inspection; no extra performance rerun or Windows acceptance."}
(OUT / "recomputed-evidence.json").write_text(json.dumps(result, indent=2, sort_keys=True)+"\n")
print(json.dumps({"checks": checks, "errors": errors, "cohorts": {name: {"limits": d['count'], "failures":len(d['failures'])} for name,d in cohorts.items()},
                  "source_binding_file_counts": [d['files'] for d in bindings]}, indent=2))
raise SystemExit(bool(errors))
