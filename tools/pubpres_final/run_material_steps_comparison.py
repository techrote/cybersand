#!/usr/bin/env python3
"""Serial same-source count0/count2/count2/count0 material comparison, always Draft/HOLD.

Runs only after exact-source graphical correctness. Every capture passes the
unchanged frozen V3 physical oracle before additive count/freshness reduction.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import uuid

from run_comparison import (ROOT, HERE, campaign_settings, driver_identity, prepare,
                            validate_registered_sources)
from run_campaign import copy_project, source_identity
from run_focus import (ENGINE_SHA256, observed_gap_counts, selectors,
                       validate_requested_capture, validate_runtime, write_json)
from results import digest, need
from results_same_frame import reduce_receipt
from metrics import supplementary_metrics, validate_slot_treatment
from observer_support import execute_with_resources, validate_observers
from material_steps_contract import (OBSERVER, RESOURCE, reduce_evidence, validate_cohort, verify_contract, validate_registration)
from material_steps_oracle import main_history_result, headless_result
from run_deadline_comparison import correctness_prerequisite as existing_correctness_prerequisite


def steps_campaign(registration: dict, selected: list[str]) -> dict:
    validate_registration(registration)
    admitted = registration["primary_cases"]
    need(selected and len(selected) == len(set(selected)) and set(selected) <= set(admitted),
         "Unknown or duplicated count workload")
    base = json.loads((HERE / "registration.json").read_bytes())
    campaign = campaign_settings(base, selected, False)
    for key in ("minimum_capture_usec", "minimum_real_steps", "maximum_capture_usec"):
        need(campaign["measurement"][key] == registration[key], "Deadline changed frozen capture limits")
    campaign["overlay_sha256"].update({OBSERVER: digest(HERE / "pubpres_final_material_steps_gameplay.gd"),
                                      RESOURCE: digest(HERE / "material_steps_registration.json")})
    campaign["observer_entrypoint"] = OBSERVER
    campaign["material_steps_registration_sha256"] = digest(HERE / "material_steps_registration.json")
    return campaign


def correctness_prerequisite(path: Path, source: dict, driver: dict, engine: Path) -> dict:
    result = existing_correctness_prerequisite(path, source, driver, engine)
    proof = json.loads(path.read_bytes())
    project = Path(source["root"]) / "godot"
    required = ("test_material_publication_steps", "test_material_steps_main_identity", "test_material_steps_main_history")
    rows = {(row["test"], row["slots"]): row for row in proof["outcomes"]}
    need(len(rows) == len(proof["outcomes"]), "Duplicated correctness outcome")
    replayed = []
    for test in required:
        need((test, 2) in rows, "Count policy/owner/actual seven-pair GPU prerequisite missing: " + test)
        row = rows[test, 2]
        folder = path.parent / (test + "-slots2")
        process = json.loads((folder / "process.json").read_bytes())
        log = folder / "stdout.log"
        text = log.read_text(encoding="utf-8", errors="strict")
        graphical = test == "test_material_steps_main_history"
        need(row["valid"] is True and row["graphical"] is graphical
             and type(process["returncode"]) is int and process["returncode"] == 0
             and process["timed_out"] is False and process.get("display_owner_verified", True) is True
             and process.get("terminal_interruption") is None
             and process["log_sha256"] == row["log_sha256"] == digest(log)
             and row["command"] == process["command"] and "ERROR:" not in text,
             "Count prerequisite raw process/log is missing, altered or unsuccessful")
        command = process["command"]
        need(command.count(str(engine)) == 1 and "--path" in command and "--script" in command
             and command[command.index("--path") + 1] == str(path.parent / "project")
             and command[command.index("--script") + 1] == "res://tests/" + test + ".gd",
             "Count prerequisite executed another source/project/fixture")
        if graphical:
            need("--headless" not in command and "--render-thread" in command
                 and command[command.index("--render-thread") + 1] == "safe", "Count GPU prerequisite used another owner")
            evidence = main_history_result(text, source["source_commit"], project,
                          "opengl3_angle" if os.name == "nt" else "opengl3", engine_sha256=digest(engine))
        else:
            need("--headless" in command, "Count policy/identity fixture changed registered process mode")
            evidence = headless_result(test, text, project)
        need(evidence == row["evidence"], "Count prerequisite summary differs from independent raw replay")
        replayed.append({"test": test, "log_sha256": digest(log), "process_sha256": digest(folder / "process.json"),
                         "checks": evidence["checks"], "graphical": graphical})
    return {**result, "count_prerequisites_replayed": replayed, "physical_credit": False}


def strict_logs(folder: Path) -> None:
    text = "\n".join((folder / name).read_text(encoding="utf-8", errors="replace")
                     for name in ("stdout.log", "stderr.log"))
    need("ERROR:" not in text, "Strict count comparison diagnostic failure")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "runtime", "engine", "correctness-summary", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--case", action="append")
    parser.add_argument("--rapier-runtime", type=Path)
    parser.add_argument("--display-wrapper", type=Path)
    args = parser.parse_args()
    need(not any(key.startswith("WB_COMBINED_") for key in os.environ), "Inherited unregistered Workbench settings")
    output, engine = args.output.resolve(), args.engine.resolve()
    need(not output.exists(), "Original count evidence must be retained; output must be new")
    driver = driver_identity()
    contract = verify_contract()
    registration = json.loads((HERE / "material_steps_registration.json").read_bytes())
    need(registration["schema"] == "pubpres-final-material-steps-registration-v1"
         and registration["order"] == [0, 2, 2, 0], "Unknown count counterbalance")
    campaign = steps_campaign(registration, args.case or registration["primary_cases"])
    platform = "windows" if os.name == "nt" else "linux"
    need(digest(engine) == ENGINE_SHA256[platform], "Count comparison requires exact official Godot4.7")
    root = args.source.resolve()
    source = source_identity(root)
    source["native_runtime"] = validate_runtime(root, source, args.runtime.resolve(), False)
    base = json.loads((HERE / "registration.json").read_bytes())
    validate_registered_sources({"C": source}, driver, base, "single")
    prerequisite = correctness_prerequisite(args.correctness_summary.resolve(), source, driver, engine)
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    report = {"schema": "pubpres-final-material-steps-comparison-v1", "source": source,
              "driver": driver, "engine_sha256": digest(engine), "registration": registration,
              "registration_sha256": digest(HERE / "material_steps_registration.json"), "contract": contract,
              "campaign_sha256": digest(output / "campaign.json"), "correctness": prerequisite,
              "cases": [], "failures": [], "complete": False, "physical_acceptance": "HOLD",
              "scope": registration["scope"]}
    def save():
        write_json(output / "SUMMARY.json", report)
    save()
    template = prepare(root, source, output / "template", campaign, engine, args.rapier_runtime,
                       overlay_sources={OBSERVER: HERE / "pubpres_final_material_steps_gameplay.gd",
                                        RESOURCE: HERE / "material_steps_registration.json"})
    strict_logs(output / "template/import")
    rendering_driver = "opengl3_angle" if platform == "windows" else "opengl3"
    for case in campaign["cases"]:
        arms = []
        for index, interval in enumerate(registration["order"]):
            folder = output / case["id"] / f"{index}-count{interval}"
            project = output / "projects" / f"{case['id']}-{index}"
            project.parent.mkdir(parents=True, exist_ok=True)
            copy_project(template, project, imported=True)
            folder.mkdir(parents=True)
            receipt = folder / "receipt.json"
            nonce = uuid.uuid4().hex
            settings = selectors({"material": "full", "same_frame_continuation": False,
                                  "wave_column_probe": False, "causal": False}, nonce)
            settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2",
                            CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="0",
                            CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL=str(interval),
                            CYBERSAND_DIAG_PRESENTATION_OBSERVER="1")
            arguments = ["--path", str(project), "--rendering-method", "gl_compatibility",
                         "--rendering-driver", rendering_driver, "--render-thread", "safe", "--audio-driver", "Dummy",
                         "--log-file", str(folder / "godot.log"), "--script", "res://" + OBSERVER, "--",
                         "--receipt=" + str(receipt), "--fixture=" + case["fixture"],
                         "--camera=" + case["camera"], "--workers=" + str(case["workers"]),
                         "--water-law=" + case["water_law"], "--water-variant=" + case.get("water_variant", "reference"),
                         "--water-profile=" + case.get("water_profile", campaign["measurement"]["water_profile"]),
                         "--input-mode=" + case.get("input_mode", "tape"), "--command-mode=repeated_callback",
                         "--observer-mode=full"]
            write_json(folder / "arm.json", {"source": source, "case": case, "nonce": nonce,
                                             "requested_interval": interval, "selectors": settings, "arguments": arguments})
            print(case["id"], index, "completed-step material interval", interval, flush=True)
            try:
                process = execute_with_resources(engine, arguments, folder, source["source_commit"], settings, 420, args.display_wrapper)
                strict_logs(folder)
                data = json.loads(receipt.read_bytes())
                validate_requested_capture(data, case, campaign, source["source_commit"], nonce, rendering_driver)
                # Unchanged original physical predicates run before any count
                # counter, cadence or material-age interpretation.
                analysis = reduce_receipt(receipt, campaign, project=project, engine=engine, arm_letter="C")
                observers = validate_observers(receipt, process, project, True, expected_material_steps=interval)
                events = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()][1:]
                slots = validate_slot_treatment(data, events, 2, require_status=True,
                                                expected_extent=campaign["fixtures"][case["fixture"]]["extent"])
                steps = reduce_evidence(receipt, events, interval)
                analysis["physical_gap_counts_above_ms"] = observed_gap_counts(
                    receipt.with_name("receipt-events.jsonl"), analysis["windows"], base["reported_gap_thresholds_ms"])
                supplement = supplementary_metrics(receipt)
                need(process["observed_application_pid"] == data["process_id"], "Count sampler followed another application")
                process["app_sampler_pid_matched"] = True
                for name, value in (("analysis", analysis), ("material-steps-analysis", steps), ("observers", observers),
                                    ("supplementary", supplement), ("process", process)):
                    write_json(folder / (name + ".json"), value)
                arms.append({"arm": "C", "index": index, "requested_interval": interval,
                             "statistics": analysis, "material_steps": steps, "supplementary": supplement,
                             "slots": slots, "process": process, "observers": observers,
                             "receipt_sha256": digest(receipt)})
                shutil.rmtree(project)
            except Exception as error:
                failure = {"case": case["id"], "index": index, "requested_interval": interval, "reason": str(error)}
                report["failures"].append(failure)
                print("Retained failed count arm:", str(error), flush=True)
            save()
        item = {"case": case["id"], "arms": arms}
        try:
            item["cohort"] = validate_cohort(arms, registration)
            need(item["cohort"]["treatment_exercised_in_both_arms"] is True,
                 "Valid no-op/deadline-only count2 arm: registered deferral/coalescing/real-count eligibility was not exercised in both arms")
        except (ValueError, TypeError, KeyError) as error:
            report["failures"].append({"case": case["id"], "reason": str(error)})
        report["cases"].append(item)
        save()
    report["complete"] = not report["failures"]
    save()
    print(json.dumps({"output": str(output), "complete": report["complete"],
                      "failures": report["failures"], "physical_acceptance": "HOLD"}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
