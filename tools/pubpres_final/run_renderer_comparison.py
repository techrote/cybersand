#!/usr/bin/env python3
"""Isolate recovered #609 engine and actual Safe/Separate render ownership.

One exact current application/native/Rapier source and Full-two/early/coherent
policy are used throughout. This Windows-only, explicitly registered apparatus
preserves every non-render-owner frozen V3 predicate and always returns HOLD.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

from run_comparison import (ROOT, HERE, OBSERVER, campaign_settings, driver_identity,
                            prepare, validate_registered_sources)
from run_campaign import copy_project, execute, physical_outcome_parity, source_identity
from run_focus import observed_gap_counts, selectors, validate_runtime, write_json
from results import canonical, digest, need
from results_registered_renderer import reduce_receipt
from run_source_abba import compare_registered_direction
from metrics import supplementary_metrics, validate_slot_treatment
from renderer_contract import verify_renderer_reducer
from observer_support import SELECTOR as PRESENTATION_SELECTOR, execute_with_resources, validate_observers

ORACLE_RESOURCE = "tests/pubpres_final_two_slot_oracle.gd"
EXTERNAL_INPUTS = (
    "tools/ci/restore_workbench_godot.py", "tools/ci/build_workbench_godot.py",
    "third_party/workbench-godot.lock.json", "third_party/workbench-godot-evaluation.lock.json",
    "third_party/patches/godot-egl-current-window.patch",
    "tools/pubpres_final_windows/two_slot_oracle.py", "tools/pubpres_final_windows/two_slot_oracle.gd",
    "godot/tests/pubpres_source_transition_oracle.gd", "godot/tests/pubpres_transition.gd",
    "godot/tests/palette_qualification_context.gd", "godot/tests/support/ci_execution_policy.gd",
    "godot/tests/support/ci_execution_policy.json", "godot/scripts/palette_shader_selector.gd",
)


def validate_requested_renderer(data: dict, case: dict, campaign: dict, source: str,
                                nonce: str, engine_sha256: str, thread: str):
    """Original requested-capture contract with one explicit registered owner."""
    need(thread in ("safe", "separate"), "Unregistered render owner")
    need(data["source_identity"]["source_sha"] == source and data["case_nonce"] == nonce
         and data["source_identity"]["engine_sha256"] == engine_sha256,
         "Captured application/executable/nonce differs")
    expected = {"renderer": "opengl3_angle", "render_thread": {"requested": thread, "runtime": thread},
                "camera": case["camera"], "workers": case["workers"], "water_law": case["water_law"],
                "water_profile": case.get("water_profile", campaign["measurement"]["water_profile"]),
                "water_variant": case.get("water_variant", "reference"), "input_mode": case.get("input_mode", "tape"),
                "command_mode": "repeated_callback", "observer_mode": "full"}
    need(data["fixture"]["name"] == case["fixture"], "Requested renderer fixture differs")
    for key, value in expected.items():
        need(data[key] == value, "Requested renderer capture differs: " + key)
    for phase in ("selectors_before", "selectors_after"):
        status = data[phase]
        need(status["physics"] == "early" and status["presentation"] == "coherent"
             and status["cadence"] == "repaired" and status["rendezvous"]["mode"] == "off"
             and status["rendezvous"]["separate_render_thread"] is (thread == "separate"),
             "Renderer isolation changed physical policy or actual rendezvous render owner")


def validate_draw_identity(events: list[dict], thread: str):
    draws = [row for row in events if row["event"] == "framebuffer_draw"]
    need(draws, "Missing delivered draw notifications")
    if thread == "separate":
        need(all(row["inline_main"] is False and row["render_serial"] == -1
                 and row["draw_identity_scope"] == "unknown: Separate notification deferred to Main" for row in draws),
             "Separate invented an upload-specific draw identity from a deferred Main notification")
    else:
        need(all(row["inline_main"] is True and type(row["render_serial"]) is int
                 and row["render_serial"] > 0 for row in draws), "Safe draw notification owner/serial differs")


def validate_renderer_cohort(arms: list[dict], registration: dict) -> dict:
    plan = registration["order"]
    need(len(arms) == len(plan) and [row["index"] for row in arms] == list(range(len(plan))),
         "Incomplete/reordered renderer-isolation cohort")
    matches = []
    for arm, expected in zip(arms, plan):
        need(arm["treatment"] == expected, "Renderer-isolation arm order differs")
        match = dict(arm["statistics"]["match"])
        need(match["engine"] == registration[expected["engine"] + "_engine_sha256"]
             and match["render_thread"] == {"requested": expected["render_thread"], "runtime": expected["render_thread"]},
             "Renderer-isolation actual engine/owner differs")
        # Only these two preregistered dimensions vary. Raw evidence and the
        # complete match record retain both; no receipt is relabelled Safe.
        del match["engine"], match["render_thread"]
        matches.append(match)
        need(arm["slots"]["requested_slots"] == 2 and arm["slots"]["effective_slots_verified"] is True
             and arm["statistics"]["registered_material_treatment"] == {"backend": "full", "policy": ""}
             and arm["statistics"]["same_frame_continuation"]["enabled"] is False,
             "Renderer-isolation changed material slots, backend or callback policy")
    need(all(canonical(match) == canonical(matches[0]) for match in matches),
         "Renderer-isolation hardware, fixture, workload or native policy differs")
    parity = physical_outcome_parity(arms)
    need(parity["same_source_pairs_equal"] is True,
         "Same-source equal-step bodies/admitted commands diverged; causal timing attribution refused")
    comparisons = {}
    for name, indices in registration["comparisons"].items():
        subset = [dict(arms[index], index=position, arm="D" if position in (0, 3) else "C")
                  for position, index in enumerate(indices)]
        comparisons[name] = compare_registered_direction(subset)
    return {"physical_outcome_parity": parity, "registered_directions": comparisons,
            "scope": "Engine package and render owner are separately counterbalanced; neither is a physical NVIDIA acceptance."}


def strict_logs(folder: Path):
    text = "\n".join((folder / name).read_text(encoding="utf-8", errors="replace")
                     for name in ("stdout.log", "stderr.log"))
    need("ERROR:" not in text, "Strict renderer experiment diagnostic failure")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "runtime", "official-engine", "patched-engine-root", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--case", action="append", required=True)
    parser.add_argument("--rapier-runtime", type=Path)
    parser.add_argument("--qualify-only", action="store_true")
    parser.add_argument("--presentation-observer", action="store_true")
    args = parser.parse_args()
    need(os.name == "nt", "Recovered engine isolation is registered only for hosted Windows/ANGLE")
    need(not any(key.startswith("WB_COMBINED_") for key in os.environ), "Inherited unregistered combined-workbench settings")
    output = args.output.resolve()
    need(not output.exists(), "Original renderer evidence must be retained; output must be new")
    driver = driver_identity()
    for relative in EXTERNAL_INPUTS:
        committed = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + relative])
        need((ROOT / relative).read_bytes() == committed, "Renderer dependency differs from driver commit: " + relative)
        driver["files_sha256"][relative] = hashlib.sha256(committed).hexdigest()
    reducer = verify_renderer_reducer(ROOT)
    registration = json.loads((HERE / "renderer_registration.json").read_bytes())
    need(registration["schema"] == "pubpres-final-renderer-isolation-registration-v1"
         and set(args.case) <= set(registration["cases"]), "Unregistered renderer comparison workload")
    source_root = args.source.resolve()
    source = source_identity(source_root)
    source["native_runtime"] = validate_runtime(source_root, source, args.runtime.resolve(), False)
    base_registration = json.loads((HERE / "registration.json").read_bytes())
    validate_registered_sources({"C": source}, driver, base_registration, "single")
    campaign = campaign_settings(base_registration, args.case, False)
    sys.path.insert(0, str(ROOT / "tools/ci"))
    from restore_workbench_godot import verify_payload
    patched_root = args.patched_engine_root.resolve()
    proof = verify_payload(patched_root)
    engines = {"official": args.official_engine.resolve(), "patched": patched_root / proof["gui_executable"]}
    for role, path in engines.items():
        need(digest(path) == registration[role + "_engine_sha256"], "Actual renderer executable differs: " + role)
    need(digest(patched_root / "build-provenance.json") == registration["patched_build_provenance_sha256"]
         and proof["upstream_commit"] == registration["patched_engine_source"]
         and proof["application_source"] == registration["patched_engine_build_source"]
         and str(proof["workflow_run"]) == str(registration["patched_engine_run"]),
         "Recovered patched-engine custody differs")
    sys.path.insert(0, str(ROOT / "tools/pubpres_final_windows"))
    from two_slot_oracle import validate as validate_two_slot_oracle
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    report = {"schema": "pubpres-final-renderer-isolation-v1", "registration": registration,
              "registration_sha256": digest(HERE / "renderer_registration.json"), "source": source,
              "driver": driver, "reducer": reducer, "patched_engine_build": proof,
              "campaign_sha256": digest(output / "campaign.json"), "order": registration["order"],
              "qualification": [], "cases": [], "failures": [], "complete": False,
              "qualify_only": args.qualify_only, "physical_acceptance": "HOLD"}
    def save():
        write_json(output / "SUMMARY.json", report)
    save()
    templates = {}
    for role, engine in engines.items():
        templates[role] = prepare(source_root, source, output / ("template-" + role), campaign, engine, args.rapier_runtime)
        strict_logs(output / ("template-" + role) / "import")
        shutil.copyfile(ROOT / "tools/pubpres_final_windows/two_slot_oracle.gd", templates[role] / ORACLE_RESOURCE)
    qualified = {}
    for role, thread in (("official", "safe"), ("patched", "safe"), ("patched", "separate")):
        label = role + "-" + thread
        folder = output / "qualification" / label
        project = output / "oracle-projects" / label
        folder.mkdir(parents=True)
        project.parent.mkdir(parents=True, exist_ok=True)
        copy_project(templates[role], project, imported=True)
        receipt = folder / "receipt.json"
        settings = selectors({"material": "full", "same_frame_continuation": False,
                              "wave_column_probe": False, "causal": False}, uuid.uuid4().hex)
        settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2", CYBERSAND_PLAYABILITY_RENDER_THREAD=thread)
        record = {"engine": role, "render_thread": thread, "complete": False}
        try:
            process = execute(engines[role], ["--path", str(project), "--rendering-method", "gl_compatibility",
                              "--rendering-driver", "opengl3_angle", "--render-thread", thread, "--audio-driver", "Dummy",
                              "--script", "res://" + ORACLE_RESOURCE, "--", "--material=full", "--receipt=" + str(receipt)],
                              folder, source["source_commit"], settings, 600)
            strict_logs(folder)
            evidence = validate_two_slot_oracle(receipt, project, source=source["source_commit"], driver="opengl3_angle",
                                               engine_sha256=registration[role + "_engine_sha256"], separate=thread == "separate")
            need(process["observed_application_pid"] == evidence["context"]["process_id"], "Oracle process identity differs")
            record.update(complete=True, receipt_sha256=digest(receipt), evidence=evidence, process=process)
            shutil.rmtree(project)
        except Exception as error:
            record["failure"] = str(error)
            report["failures"].append({"qualification": label, "reason": str(error)})
        qualified[(role, thread)] = record["complete"]
        report["qualification"].append(record)
        save()
    if not args.qualify_only:
        for case in campaign["cases"]:
            arms = []
            for index, treatment in enumerate(registration["order"]):
                role, thread = treatment["engine"], treatment["render_thread"]
                folder = output / case["id"] / f"{index}-{role}-{thread}"
                folder.mkdir(parents=True)
                if not qualified[(role, thread)]:
                    failure = {"case": case["id"], "index": index, "treatment": treatment,
                               "reason": "Actual engine/owner failed prior two-slot exact-history qualification; timed arm not run"}
                    report["failures"].append(failure)
                    write_json(folder / "not-run.json", failure)
                    save()
                    continue
                project = output / "projects" / f"{case['id']}-{index}"
                project.parent.mkdir(parents=True, exist_ok=True)
                copy_project(templates[role], project, imported=True)
                receipt = folder / "receipt.json"
                nonce = uuid.uuid4().hex
                settings = selectors({"material": "full", "same_frame_continuation": False,
                                      "wave_column_probe": False, "causal": False}, nonce)
                settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2", CYBERSAND_PLAYABILITY_RENDER_THREAD=thread)
                settings[PRESENTATION_SELECTOR] = "1" if args.presentation_observer else "0"
                arguments = ["--path", str(project), "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
                             "--render-thread", thread, "--audio-driver", "Dummy", "--log-file", str(folder / "godot.log"),
                             "--script", "res://" + OBSERVER, "--", "--receipt=" + str(receipt), "--fixture=" + case["fixture"],
                             "--camera=" + case["camera"], "--workers=" + str(case["workers"]), "--water-law=" + case["water_law"],
                             "--water-variant=" + case.get("water_variant", "reference"),
                             "--water-profile=" + case.get("water_profile", campaign["measurement"]["water_profile"]),
                             "--input-mode=" + case.get("input_mode", "tape"), "--command-mode=repeated_callback", "--observer-mode=full"]
                write_json(folder / "arm.json", {"source": source, "scenario": case, "nonce": nonce,
                                                 "treatment": treatment, "selectors": settings, "arguments": arguments})
                print(case["id"], index, treatment, flush=True)
                try:
                    need(digest(engines[role]) == registration[role + "_engine_sha256"], "Executable changed before timed arm")
                    process = execute_with_resources(engines[role], arguments, folder, source["source_commit"], settings, 420)
                    strict_logs(folder)
                    data = json.loads(receipt.read_bytes())
                    validate_requested_renderer(data, case, campaign, source["source_commit"], nonce,
                                                registration[role + "_engine_sha256"], thread)
                    analysis = reduce_receipt(receipt, campaign, project=project, engine=engines[role], arm_letter="C",
                                              expected_render_thread=thread)
                    observers = validate_observers(receipt, process, project, args.presentation_observer)
                    events = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()]
                    validate_draw_identity(events, thread)
                    slot_evidence = validate_slot_treatment(data, events, 2, True)
                    analysis["physical_gap_counts_above_ms"] = observed_gap_counts(
                        receipt.with_name("receipt-events.jsonl"), analysis["windows"], base_registration["reported_gap_thresholds_ms"])
                    supplement = supplementary_metrics(receipt)
                    need(thread != "separate" or all(not window["material_draw_identity_available"]
                                                      for window in supplement["windows"].values()),
                         "Separate supplemental measurement invented material/draw matching")
                    need(process["observed_application_pid"] == data["process_id"], "Application memory sampler PID differs")
                    process["app_sampler_pid_matched"] = True
                    write_json(folder / "analysis.json", analysis)
                    write_json(folder / "supplementary.json", supplement)
                    write_json(folder / "observers.json", observers)
                    write_json(folder / "process.json", process)
                    arms.append({"arm": "C", "index": index, "treatment": treatment, "statistics": analysis,
                                 "slots": slot_evidence, "supplementary": supplement, "process": process,"observers":observers,
                                 "receipt_sha256": digest(receipt)})
                    shutil.rmtree(project)
                except Exception as error:
                    report["failures"].append({"case": case["id"], "index": index, "treatment": treatment, "reason": str(error)})
                save()
            record = {"case": case["id"], "arms": arms}
            try:
                record.update(validate_renderer_cohort(arms, registration))
            except (ValueError, KeyError, TypeError) as error:
                report["failures"].append({"case": case["id"], "reason": str(error)})
            report["cases"].append(record)
            save()
    report["complete"] = not report["failures"]
    save()
    print(json.dumps({"output": str(output), "complete": report["complete"], "physical_acceptance": "HOLD"}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
