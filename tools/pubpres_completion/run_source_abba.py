#!/usr/bin/env python3
"""Execute a registered D/C/C/D full-publication cohort on one graphical host."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres003"))
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))

from process_owner import bounded_process
from request import registration
from run_focus import validate_complete_comparison, write_json
from run_campaign import git, physical_outcome_parity
from results import digest, need, number

ORDER = ("D", "C", "C", "D")
ARM_ALLOWANCE_SECONDS = 840
GAP_THRESHOLDS = ("100", "250", "500", "1000")
TOOLCHAIN_FIELDS = ("godot_cpp_commit", "godot_cpp_library_sha256", "godot_cpp_dependency_sha256",
                    "compiler_command", "compiler_version", "toolchain_drift_allowed")


def validate_source_cohort(arms, sources, order=ORDER):
    validate_complete_comparison(arms, len(order))
    need([arm["arm"] for arm in arms] == list(order), "Registered source order changed")
    for arm in arms:
        stats = arm["statistics"]
        need(stats["source"] == sources[arm["arm"]] and stats["observer_mode"] == "full",
             "Measured source or observer mode differs")
        need(stats["registered_material_treatment"] == {"backend": "full", "policy": ""},
             "Source cohort used a different publication backend")
        need(stats["same_frame_continuation"]["enabled"] is False,
             "Source cohort enabled the continuation treatment")
        for phase in ("selectors_before", "selectors_after"):
            selected = stats[phase]
            if arm["arm"] == "M":
                need(all(selected[key] is None for key in ("material", "physics", "presentation", "cadence", "rendezvous"))
                     and selected["requested"]["CYBERSAND_DIAG_PHYSICS_PUBLICATION"] == "combined"
                     and selected["requested"]["CYBERSAND_DIAG_PRESENTATION"] == "legacy",
                     "Accepted main acquired an integrated treatment")
            else:
                need(selected["physics"] == "early" and selected["presentation"] == "coherent"
                     and selected["cadence"] == "repaired" and selected["rendezvous"]["mode"] == "off",
                     "Physical, presentation or cadence treatment differs")
    parity = physical_outcome_parity(arms)
    need(len(parity["pairs"]) == 6 and all(row["bodies_equal"] and row["admitted_moves_equal"]
                                          for row in parity["pairs"]),
         "Equal-step physical trajectories or admitted input differ across the cohort")
    return parity


def compare_registered_direction(arms, reference="D"):
    rates = {reference: [], "C": []}
    tails = {role: {key: [] for key in ("p95", "p99", "max")} for role in rates}
    severe = {role: {key: [] for key in GAP_THRESHOLDS} for role in rates}
    for arm in arms:
        stats = arm["statistics"]
        window = stats["windows"]["first_144_steps"]
        counts = stats["physical_gap_counts_above_ms"]["first_144_steps"]
        need(window["completed_rapier_steps"] == 144 and set(counts) == set(GAP_THRESHOLDS)
             and all(type(value) is int and 0 <= value < 144 for value in counts.values()),
             "First-144 window or registered gap thresholds are incomplete")
        rate = window["rapier_steps_per_second"]
        gaps = window["physical_gap_ms"]
        need(number(rate) and rate > 0 and all(number(gaps[key]) for key in ("p95", "p99", "max")),
             "Physical progression/tail observations are not finite")
        rates[arm["arm"]].append(rate)
        for quantile in ("p95", "p99", "max"):
            tails[arm["arm"]][quantile].append(gaps[quantile])
        for threshold in GAP_THRESHOLDS:
            severe[arm["arm"]][threshold].append(counts[threshold])
    higher_rate = min(rates["C"]) > max(rates[reference])
    smaller_tail = {q: max(tails["C"][q]) < min(tails[reference][q]) for q in ("p95", "p99")}
    maximum_within_reference = max(tails["C"]["max"]) <= max(tails[reference]["max"])
    severe_within_reference = {ms: max(severe["C"][ms]) <= max(severe[reference][ms]) for ms in GAP_THRESHOLDS}
    supported = higher_rate and all(smaller_tail.values()) and maximum_within_reference and all(severe_within_reference.values())
    return {"window": "first_144_steps", "reference_role": reference, "all_candidate_rates_higher": higher_rate,
            "all_candidate_gap_quantiles_lower": smaller_tail,
            "all_candidate_max_gaps_within_worst_reference": maximum_within_reference,
            "all_candidate_severe_counts_within_worst_reference": severe_within_reference,
            "repeatable_direction": supported,
            "disposition": "SUPPORTED_FOR_THIS_COHORT" if supported else "NOT_ESTABLISHED"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("donor", "candidate", "runtime-root", "engine", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--case", required=True)
    parser.add_argument("--display-wrapper", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    settings, registration_hash = registration()
    need(tuple(settings["source_order"]) == ORDER and settings["source_material"] == "full"
         and args.case in settings["final_cases"], "Source comparison is outside the frozen registration")
    roots = {"D": args.donor.resolve(), "C": args.candidate.resolve()}
    sources = {key: git(root, "rev-parse", "HEAD") for key, root in roots.items()}
    need(sources["D"] == settings["reference_sources"]["D"]["source_commit"]
         and sources["C"] == git(ROOT, "rev-parse", "HEAD"), "Source comparison checked out a different donor or candidate")
    runtime = args.runtime_root.resolve()
    records = {key: json.loads((runtime / key / "PUBPRES-RUNTIME.json").read_bytes()) for key in roots}
    fields = [{field: records[key][field] for field in TOOLCHAIN_FIELDS} for key in ORDER[:2]]
    need(fields[0] == fields[1] and fields[0]["toolchain_drift_allowed"] is False,
         "D and C native toolchains differ")
    report = {"schema": "pubpres-completion-source-abba-v1", "case": args.case,
              "registration_sha256": registration_hash, "order": list(ORDER), "sources": sources,
              "toolchain": fields[0], "native_runtime_sha256": {key: records[key]["runtime_sha256"] for key in roots},
              "material": "full", "continuation": "off", "outcomes": [], "complete": False,
              "failures": [], "physical_acceptance": "HOLD",
              "scope": "Same-host D/C whole-source comparison. The four frozen per-arm receipts retain independently defined timing windows and exact input outcomes."}
    write_json(output / "SUMMARY.json", report)
    admitted = []
    for index, key in enumerate(ORDER):
        run_dir = output / f"{index:02d}-{key}"
        command = [sys.executable, str(ROOT / "tools/pubpres003/run_focus.py"), "--completion-role", key,
                   "--source", str(roots[key]), "--runtime", str(runtime / key), "--engine", str(args.engine.resolve()),
                   "--case", args.case, "--mode", "baseline", "--material", "full", "--output", str(run_dir)]
        if args.display_wrapper:
            command += ["--display-wrapper", str(args.display_wrapper.resolve())]
        log = output / (run_dir.name + ".log")
        outcome = {"arm": key, "index": index, "command": command, "log": log.name}
        report["outcomes"].append(outcome)
        try:
            with log.open("x", encoding="utf-8") as stream:
                status, timed_out = bounded_process(command, cwd=ROOT, stdout=stream, timeout=ARM_ALLOWANCE_SECONDS)
            outcome.update(returncode=status, timed_out=timed_out, log_sha256=digest(log))
            need(status == 0 and not timed_out, "Source arm process failed or timed out")
            summary_path = run_dir / "summary.json"
            summary = json.loads(summary_path.read_bytes())
            need(summary["complete"] is True and not summary["failures"] and summary["completion_role"] == key
                 and summary["source"]["source_commit"] == sources[key] and summary["mode"] == "baseline"
                 and summary["material"] == "full" and len(summary["cases"]) == 1
                 and summary["cases"][0]["case"] == args.case and len(summary["cases"][0]["arms"]) == 1,
                 "Source arm is incomplete or differs from the exact request")
            arm = summary["cases"][0]["arms"][0]
            admitted.append({**arm, "arm": key, "index": index})
            outcome.update(summary_sha256=digest(summary_path), receipt_sha256=arm["receipt_sha256"])
        except (OSError, RuntimeError, ValueError, TypeError, KeyError) as error:
            outcome["failure"] = str(error)
            report["failures"].append({"index": index, "arm": key, "reason": str(error)})
        write_json(output / "SUMMARY.json", report)
    try:
        report["parity"] = validate_source_cohort(admitted, sources)
        report["registered_direction"] = compare_registered_direction(admitted)
        report["complete"] = not report["failures"]
    except (ValueError, KeyError, TypeError) as error:
        report["failures"].append({"reason": str(error)})
    report["arms"] = admitted
    write_json(output / "SUMMARY.json", report)
    print(json.dumps({"output": str(output), "complete": report["complete"], "failures": report["failures"]}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
