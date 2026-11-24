#!/usr/bin/env python3
"""Serial same-source off/30/60 material deadline comparison, always Draft/HOLD.

Runs only after exact-source graphical correctness. Every capture passes the
unchanged frozen V3 physical oracle before additive deadline/freshness reduction.
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
from deadline_contract import (OBSERVER, RESOURCE, reduce_deadline_evidence,
                               validate_deadline_cohort, verify_deadline_contract)


def deadline_campaign(registration: dict, selected: list[str]) -> dict:
    admitted = registration["primary_cases"] + registration["confirmation_cases"]
    need(selected and len(selected) == len(set(selected)) and set(selected) <= set(admitted),
         "Unknown or duplicated deadline workload")
    base = json.loads((HERE / "registration.json").read_bytes())
    campaign = campaign_settings(base, selected, False)
    for key in ("minimum_capture_usec", "minimum_real_steps", "maximum_capture_usec"):
        need(campaign["measurement"][key] == registration[key], "Deadline changed frozen capture limits")
    campaign["overlay_sha256"].update({OBSERVER: digest(HERE / "pubpres_final_deadline_gameplay.gd"),
                                      RESOURCE: digest(HERE / "deadline_registration.json")})
    campaign["observer_entrypoint"] = OBSERVER
    campaign["deadline_registration_sha256"] = digest(HERE / "deadline_registration.json")
    return campaign


def correctness_prerequisite(path: Path, source: dict, driver: dict, engine: Path) -> dict:
    proof = json.loads(path.read_bytes())
    need(proof.get("schema") == "pubpres-playability-final-correctness-v1"
         and proof.get("complete") is True and proof.get("headless_only") is False
         and proof.get("physical_acceptance") == "HOLD", "Deadline timing requires complete graphical correctness")
    need(all(proof["source"][key] == source[key] for key in ("source_commit", "source_tree"))
         and all(proof["driver"][key] == driver[key] for key in ("source_commit", "source_tree"))
         and proof["native"]["binary_sha256"] == source["native_runtime"]["binary_sha256"]
         and proof["native"]["manifest_sha256"] == source["native_runtime"]["manifest_sha256"]
         and proof["engine_sha256"] == digest(engine), "Deadline correctness belongs to different source/runtime/engine bytes")
    need(not proof["import_source_mutations"] and not proof["final_source_mutations"]
         and proof["outcomes"] and all(row["valid"] is True for row in proof["outcomes"]),
         "Deadline correctness retained source mutation or invalid tests")
    required = {("test_material_publication_deadline", 2), ("test_material_deadline_main_identity", 2),
                ("test_material_deadline_main_history", 2), ("test_material_deadline_main_history", 3),
                ("test_physical_actor_integration", 2), ("test_workbench_physics_publication", 2),
                ("test_full_image_ring_publication", 3), ("pubpres_full_image_ring_oracle", 3),
                ("test_full_image_ring_main_recovery", 3)}
    need(required <= {(row["test"], row["slots"]) for row in proof["outcomes"]},
         "Deadline policy, owner, actual GPU history or physical prerequisites missing")
    graphical = {"test_material_deadline_main_history", "test_full_image_ring_publication",
                 "pubpres_full_image_ring_oracle", "test_full_image_ring_main_recovery"}
    need(all(row["graphical"] is True for row in proof["outcomes"] if row["test"] in graphical),
         "Required material history was not actually graphical")
    return {"path": str(path), "sha256": digest(path), "source": source["source_commit"],
            "outcome_count": len(proof["outcomes"]), "complete": True}


def strict_logs(folder: Path) -> None:
    text = "\n".join((folder / name).read_text(encoding="utf-8", errors="replace")
                     for name in ("stdout.log", "stderr.log"))
    need("ERROR:" not in text, "Strict deadline comparison diagnostic failure")


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
    need(not output.exists(), "Original deadline evidence must be retained; output must be new")
    driver = driver_identity()
    contract = verify_deadline_contract()
    registration = json.loads((HERE / "deadline_registration.json").read_bytes())
    need(registration["schema"] == "pubpres-final-material-deadline-registration-v1"
         and registration["order"] == [0, 30, 60, 60, 30, 0], "Unknown deadline counterbalance")
    campaign = deadline_campaign(registration, args.case or registration["primary_cases"])
    platform = "windows" if os.name == "nt" else "linux"
    need(digest(engine) == ENGINE_SHA256[platform], "Deadline comparison requires exact official Godot4.7")
    root = args.source.resolve()
    source = source_identity(root)
    source["native_runtime"] = validate_runtime(root, source, args.runtime.resolve(), False)
    base = json.loads((HERE / "registration.json").read_bytes())
    validate_registered_sources({"C": source}, driver, base, "single")
    prerequisite = correctness_prerequisite(args.correctness_summary.resolve(), source, driver, engine)
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    report = {"schema": "pubpres-final-material-deadline-comparison-v1", "source": source,
              "driver": driver, "engine_sha256": digest(engine), "registration": registration,
              "registration_sha256": digest(HERE / "deadline_registration.json"), "contract": contract,
              "campaign_sha256": digest(output / "campaign.json"), "correctness": prerequisite,
              "cases": [], "failures": [], "complete": False, "physical_acceptance": "HOLD",
              "scope": registration["scope"]}
    def save():
        write_json(output / "SUMMARY.json", report)
    save()
    template = prepare(root, source, output / "template", campaign, engine, args.rapier_runtime,
                       overlay_sources={OBSERVER: HERE / "pubpres_final_deadline_gameplay.gd",
                                        RESOURCE: HERE / "deadline_registration.json"})
    strict_logs(output / "template/import")
    rendering_driver = "opengl3_angle" if platform == "windows" else "opengl3"
    for case in campaign["cases"]:
        arms = []
        for index, hz in enumerate(registration["order"]):
            folder = output / case["id"] / f"{index}-deadline{hz}"
            project = output / "projects" / f"{case['id']}-{index}"
            project.parent.mkdir(parents=True, exist_ok=True)
            copy_project(template, project, imported=True)
            folder.mkdir(parents=True)
            receipt = folder / "receipt.json"
            nonce = uuid.uuid4().hex
            settings = selectors({"material": "full", "same_frame_continuation": False,
                                  "wave_column_probe": False, "causal": False}, nonce)
            settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2",
                            CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ=str(hz),
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
                                             "requested_hz": hz, "selectors": settings, "arguments": arguments})
            print(case["id"], index, "material deadline", hz, flush=True)
            try:
                process = execute_with_resources(engine, arguments, folder, source["source_commit"], settings, 420, args.display_wrapper)
                strict_logs(folder)
                data = json.loads(receipt.read_bytes())
                validate_requested_capture(data, case, campaign, source["source_commit"], nonce, rendering_driver)
                # Unchanged original physical predicates run before any deadline
                # counter, cadence or material-age interpretation.
                analysis = reduce_receipt(receipt, campaign, project=project, engine=engine, arm_letter="C")
                observers = validate_observers(receipt, process, project, True)
                events = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()][1:]
                slots = validate_slot_treatment(data, events, 2, require_status=True)
                deadline = reduce_deadline_evidence(receipt, events, hz)
                analysis["physical_gap_counts_above_ms"] = observed_gap_counts(
                    receipt.with_name("receipt-events.jsonl"), analysis["windows"], base["reported_gap_thresholds_ms"])
                supplement = supplementary_metrics(receipt)
                need(process["observed_application_pid"] == data["process_id"], "Deadline sampler followed another application")
                process["app_sampler_pid_matched"] = True
                for name, value in (("analysis", analysis), ("deadline-analysis", deadline), ("observers", observers),
                                    ("supplementary", supplement), ("process", process)):
                    write_json(folder / (name + ".json"), value)
                arms.append({"arm": "C", "index": index, "requested_hz": hz,
                             "statistics": analysis, "deadline": deadline, "supplementary": supplement,
                             "slots": slots, "process": process, "observers": observers,
                             "receipt_sha256": digest(receipt)})
                shutil.rmtree(project)
            except Exception as error:
                failure = {"case": case["id"], "index": index, "requested_hz": hz, "reason": str(error)}
                report["failures"].append(failure)
                print("Retained failed deadline arm:", str(error), flush=True)
            save()
        item = {"case": case["id"], "arms": arms}
        try:
            item["cohort"] = validate_deadline_cohort(arms, registration)
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
