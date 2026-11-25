#!/usr/bin/env python3
"""Run a registered current-main M/C/C/M comparison with the frozen V3 oracle."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres003"))
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))

from process_owner import bounded_process
from request import registration
from run_campaign import git
from run_focus import ENGINE_SHA256, observed_gap_counts, write_json
from run_source_abba import compare_registered_direction, validate_source_cohort
from results import digest, need

ORDER = ("M", "C", "C", "M")
CASE_ORDER = ("wave_gameplay_2048_follow", "wave_512_follow")


def comparison_campaign(frozen, settings):
    baseline = settings["main_baseline"]
    need(tuple(baseline["order"]) == ORDER and tuple(baseline["cases"]) == CASE_ORDER,
         "Unexpected current-main case or order")
    campaign = json.loads(frozen)
    need(campaign["schema"] == "pubpres-playability-campaign-v3", "Incorrect predecessor protocol")
    expected_sources = settings["reference_sources"]
    campaign["source_commits"]["main"] = expected_sources["M"]["source_commit"]
    need(campaign["source_commits"]["integration"] == expected_sources["I"]["source_commit"],
         "The frozen incompatibility observation belongs to another source")
    main = campaign["arms"]["M"]
    need((main["material"], main["physics"], main["presentation"], main["cadence"], main["same_frame_continuation"])
         == ("full", "combined", "legacy", "source-default", None), "Accepted main treatment differs")
    treatment = campaign["arms"]["C"]
    treatment.update(material="full", material_pool_policy=None, same_frame_continuation=False)
    need(treatment["physics"] == "early" and treatment["presentation"] == "coherent"
         and treatment["cadence"] == "repaired", "Candidate's registered treatment differs")
    cases = {case["id"]: case for case in campaign["cases"]}
    need(set(CASE_ORDER) <= set(cases), "Missing frozen workbench workload")
    campaign["cases"] = [cases[name] for name in CASE_ORDER]
    for case in campaign["cases"]:
        case["arm_order"] = list(ORDER)
    preflight = cases["wave_gameplay_2048_follow"]["compatibility_preflight"]
    need(preflight["expected_compatible"] is False and preflight["performance_capture_attempted"] is False
         and preflight["source"] == "I", "Incompatible I workload cannot become a performance arm")
    campaign["completion_main_baseline"] = baseline
    return campaign


def verify_rapier(root, commit, platform):
    manifest = f"godot/addons/godot-rapier2d/runtime-provenance.{platform}.json"
    content = subprocess.check_output(["git", "-C", str(root), "show", commit + ":" + manifest], timeout=60)
    record = json.loads(content)
    need(digest(root / record["artifact"]) == record["sha256"]
         and (root / record["artifact"]).stat().st_size == record["size"], "Rapier binary differs from its own source")
    need(record["source_inputs"], "Empty Rapier input ledger")
    for name, expected in record["source_inputs"].items():
        data = subprocess.check_output(["git", "-C", str(root), "show", commit + ":" + name], timeout=60)
        need(hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest() == expected, "Different Rapier source input")
    return record["sha256"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("main", "integration", "candidate", "runtime-root", "engine", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--display-wrapper", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    settings, registration_hash = registration()
    predecessor = settings["predecessor_registration"]
    frozen_path = ROOT / "tools/pubpres_playability/campaign.json"
    need(predecessor["path"] == frozen_path.relative_to(ROOT).as_posix()
         and digest(frozen_path) == predecessor["sha256"], "Frozen predecessor registration changed")
    campaign = comparison_campaign(frozen_path.read_bytes(), settings)
    effective = output / "campaign.json"
    write_json(effective, campaign)
    platform = "windows" if os.name == "nt" else "linux"
    engine = args.engine.resolve()
    need(digest(engine) == ENGINE_SHA256[platform], "Engine differs from official platform pin")
    roots = {"M": args.main.resolve(), "I": args.integration.resolve(), "C": args.candidate.resolve()}
    sources = {}
    rapier = {}
    for role, root in roots.items():
        sources[role] = git(root, "rev-parse", "HEAD")
        if role != "C":
            expected = settings["reference_sources"][role]
            need(sources[role] == expected["source_commit"]
                 and git(root, "rev-parse", "HEAD^{tree}") == expected["source_tree"], "Wrong exact reference source")
        rapier[role] = verify_rapier(root, sources[role], platform)
    need(sources["C"] == git(ROOT, "rev-parse", "HEAD") and len(set(rapier.values())) == 1,
         "Candidate source or matched Rapier runtime differs")
    runtime = args.runtime_root.resolve()
    run = output / "v3-raw"
    command = [sys.executable, str(ROOT / "tools/pubpres_playability/run_campaign.py"),
               "--main", str(roots["M"]), "--integration", str(roots["I"]), "--candidate", str(roots["C"]),
               "--engine", str(engine), "--campaign", str(effective), "--output", str(run),
               "--driver", "opengl3_angle" if platform == "windows" else "opengl3"]
    for role in roots:
        command += ["--runtime-" + role, str(runtime / role)]
    for case in CASE_ORDER:
        command += ["--case", case]
    if args.display_wrapper:
        command += ["--display-wrapper", str(args.display_wrapper.resolve())]
    report = {"schema": "pubpres-completion-main-abba-v1", "physical_acceptance": "HOLD",
              "registration_sha256": registration_hash, "effective_campaign_sha256": digest(effective),
              "sources": sources, "rapier_sha256": rapier, "order": list(ORDER), "scope": settings["main_baseline"],
              "command": command, "complete": False, "cases": [], "failures": []}
    try:
        log = output / "v3.log"
        with log.open("x", encoding="utf-8") as stream:
            status, timed_out = bounded_process(command, cwd=ROOT, stdout=stream, timeout=8700)
        report.update(returncode=status, timed_out=timed_out, log_sha256=digest(log))
        index = run / "summary.json"
        summary = json.loads(index.read_bytes())
        report["original_summary_sha256"] = digest(index)
        if (status != 0 or timed_out or summary["complete"] is not True or summary["failures"]
                or tuple(case["scenario"] for case in summary["cases"]) != CASE_ORDER):
            report["failures"].append({"reason": "Incomplete frozen-oracle comparison", "original_failures": summary["failures"]})
        for case in summary["cases"]:
            name, arms, refusal = case["scenario"], case["arms"], case["compatibility_preflight"]
            admission = {"case": name, "arms": arms, "compatibility_preflight": refusal,
                         "parity": case["physical_outcome_parity"], "registered_direction": None}
            report["cases"].append(admission)
            try:
                if name == "wave_gameplay_2048_follow":
                    need(refusal["compatible"] is False and refusal["performance_capture_attempted"] is False
                         and refusal["source_sha"] == sources["I"], "Missing explicit I compatibility refusal")
                for arm in arms:
                    folder = run / name / f"{arm['index']}-{arm['arm']}"
                    stat = arm["statistics"]
                    stat["physical_gap_counts_above_ms"] = observed_gap_counts(
                        folder / "receipt-events.jsonl", stat["windows"],
                        settings["source_gain_criteria"]["reported_gap_thresholds_ms"])
                admission["parity"] = validate_source_cohort(arms, sources, ORDER)
                admission["registered_direction"] = compare_registered_direction(arms, reference="M")
            except (OSError, RuntimeError, ValueError, TypeError, KeyError) as error:
                report["failures"].append({"case": name, "reason": str(error)})
        report["complete"] = not report["failures"]
    except (OSError, RuntimeError, ValueError, TypeError, KeyError) as error:
        report["failures"].append({"reason": str(error)})
    finally:
        write_json(output / "SUMMARY.json", report)
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
