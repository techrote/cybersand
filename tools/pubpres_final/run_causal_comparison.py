#!/usr/bin/env python3
"""New exact-source Windows Wave512 causal OFF/ON/ON/OFF diagnostic."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import uuid

from run_comparison import HERE, OBSERVER, campaign_settings, driver_identity, prepare, validate_registered_sources
from run_campaign import copy_project, source_identity
from run_focus import ENGINE_SHA256, observed_gap_counts, selectors, validate_requested_capture, validate_runtime, write_json
from results import digest, need
from results_same_frame import reduce_receipt
from causal_trace import reduce_causal
from metrics import supplementary_metrics, validate_deadline_baseline, validate_slot_treatment
from observer_support import execute_with_resources, validate_observers
from run_deadline_comparison import correctness_prerequisite, strict_logs
from causal_completion_contract import observed_intervals, registration, summarize


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "runtime", "engine", "correctness-summary", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--rapier-runtime", type=Path)
    args = parser.parse_args()
    need(os.name == "nt", "First causal diagnostic is registered only for Windows")
    need(not any(key.startswith("WB_COMBINED_") for key in os.environ), "Inherited unregistered Workbench settings")
    output, engine = args.output.resolve(), args.engine.resolve()
    need(not output.exists(), "Preserve original diagnostic attempts; output must be new")
    need(digest(engine) == ENGINE_SHA256["windows"], "Causal diagnostic requires exact official Godot4.7")
    reg, driver = registration(), driver_identity()
    base = json.loads((HERE / "registration.json").read_bytes())
    campaign = campaign_settings(base, reg["cases"], False)
    need(all(campaign["measurement"][key] == reg[key] for key in
             ("minimum_capture_usec", "minimum_real_steps", "maximum_capture_usec")), "Causal capture windows changed")
    root = args.source.resolve()
    source = source_identity(root)
    source["native_runtime"] = validate_runtime(root, source, args.runtime.resolve(), False)
    validate_registered_sources({"C": source}, driver, base, "single")
    prerequisite = correctness_prerequisite(args.correctness_summary.resolve(), source, driver, engine)
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    report = {"schema": "pubpres-final-causal-completion-comparison-v1", "registration": reg,
              "registration_sha256": digest(HERE / "causal_completion_registration.json"),
              "source": source, "driver": driver, "engine_sha256": digest(engine),
              "campaign_sha256": digest(output / "campaign.json"), "correctness": prerequisite,
              "arms": [], "failures": [], "complete": False, "physical_acceptance": "HOLD"}
    def save():
        write_json(output / "SUMMARY.json", report)
    save()
    template = prepare(root, source, output / "template", campaign, engine, args.rapier_runtime)
    strict_logs(output / "template/import")
    case = campaign["cases"][0]
    for index, enabled in enumerate(reg["order"]):
        folder = output / f"{index}-causal{int(enabled)}"
        project = output / "projects" / str(index)
        project.parent.mkdir(parents=True, exist_ok=True)
        copy_project(template, project, imported=True)
        folder.mkdir(parents=True)
        receipt, nonce = folder / "receipt.json", uuid.uuid4().hex
        settings = selectors({"material": "full", "same_frame_continuation": False,
                              "wave_column_probe": False, "causal": enabled}, nonce)
        settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2", CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="0",
                        CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL="0", CYBERSAND_DIAG_PRESENTATION_OBSERVER="1")
        arguments = ["--path", str(project), "--rendering-method", "gl_compatibility",
                     "--rendering-driver", "opengl3_angle", "--render-thread", "safe", "--audio-driver", "Dummy",
                     "--log-file", str(folder / "godot.log"), "--script", "res://" + OBSERVER, "--",
                     "--receipt=" + str(receipt), "--fixture=" + case["fixture"], "--camera=" + case["camera"],
                     "--workers=" + str(case["workers"]), "--water-law=" + case["water_law"],
                     "--water-variant=" + case.get("water_variant", "reference"),
                     "--water-profile=" + case.get("water_profile", campaign["measurement"]["water_profile"]),
                     "--input-mode=" + case.get("input_mode", "tape"), "--command-mode=repeated_callback", "--observer-mode=full"]
        write_json(folder / "arm.json", {"source": source, "case": case, "nonce": nonce,
                                         "causal_enabled": enabled, "selectors": settings, "arguments": arguments})
        print(case["id"], index, "causal", enabled, flush=True)
        try:
            process = execute_with_resources(engine, arguments, folder, source["source_commit"], settings, 420)
            strict_logs(folder)
            data = json.loads(receipt.read_bytes())
            validate_requested_capture(data, case, campaign, source["source_commit"], nonce, "opengl3_angle")
            analysis = reduce_receipt(receipt, campaign, project=project, engine=engine, arm_letter="C")
            analysis["material_deadline_baseline"] = validate_deadline_baseline(data, required=True)
            observers = validate_observers(receipt, process, project, True, expected_material_steps=0)
            causal = reduce_causal(receipt, expected_enabled=enabled)
            if enabled:
                completed = analysis["windows"]["whole_capture"]["completed_rapier_steps"]
                need(causal["actual_completed_rapier_steps"] == causal["exact_application_and_exit_joins"] == completed,
                     "Causal analysis lacks exact applications/exits for actual completed Rapier steps")
            events = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()]
            slots = validate_slot_treatment(data, events, 2, require_status=True,
                                            expected_extent=campaign["fixtures"][case["fixture"]]["extent"])
            analysis["physical_gap_counts_above_ms"] = observed_gap_counts(
                receipt.with_name("receipt-events.jsonl"), analysis["windows"], base["reported_gap_thresholds_ms"])
            supplement = supplementary_metrics(receipt)
            intervals = observed_intervals(receipt, causal)
            need(process["observed_application_pid"] == data["process_id"], "Causal observer sampled another application")
            process["app_sampler_pid_matched"] = True
            for name, value in (("analysis", analysis), ("causal-analysis", causal), ("causal-intervals", intervals),
                                ("observers", observers), ("supplementary", supplement), ("process", process)):
                write_json(folder / (name + ".json"), value)
            report["arms"].append({"arm": "C", "index": index, "causal_enabled": enabled,
                                   "statistics": analysis, "causal": causal, "intervals": intervals,
                                   "supplementary": supplement, "observers": observers, "slots": slots,
                                   "process": process, "receipt_sha256": digest(receipt)})
            shutil.rmtree(project)
        except Exception as error:
            report["failures"].append({"index": index, "causal_enabled": enabled, "reason": str(error)})
        save()
    try:
        report["cohort"] = summarize(report["arms"])
    except (ValueError, KeyError, TypeError) as error:
        report["failures"].append({"scope": "complete diagnostic cohort", "reason": str(error)})
    report["complete"] = not report["failures"]
    save()
    print(json.dumps({"complete": report["complete"], "performance_selection": "NOT_AN_OPTIMIZATION_COMPARISON",
                      "physical_acceptance": "HOLD"}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
