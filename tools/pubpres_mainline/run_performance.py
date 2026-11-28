#!/usr/bin/env python3
"""Registered M/P/C/C/P/M whole-application comparison with frozen readers."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/pubpres_final_recovery"))
from identity import driver_identity, digest
from retained_runtime import validate_runtime
from run_campaign import source_identity, copy_project, physical_outcome_parity
from run_comparison import campaign_settings, prepare, validate_task_completion
from run_focus import ENGINE_SHA256, selectors, observed_gap_counts, write_json
from results import canonical, need
from renderer_contract import verify_renderer_reducer
from results_registered_renderer import reduce_receipt
from run_source_abba import compare_registered_direction
from observer_support import execute_with_resources, validate_observers, SELECTOR
from requested_capture import validate_requested_renderer
from run_renderer_comparison import strict_logs, validate_draw_identity
from run_bounded_comparison import validate_selectors
from run_current_main_comparison import validate_control
from qualification_gate import verify_summary

REGISTRATION = HERE / "performance-registration.json"
OBSERVER = "tests/pubpres_mainline_gameplay.gd"
RECOVERY_OBSERVER = "tests/pubpres_recovery_gameplay.gd"
TREATMENT = {"engine": "stock", "render_thread": "safe", "lookahead": 0}
FLAGS = {"CYBERSAND_WORKBENCH_FLIGHT_PACING": "flight_pacing",
         "CYBERSAND_WORKBENCH_COUPLING_CLOCK": "coupling_clock",
         "CYBERSAND_WORKBENCH_EMPTY_EFFECTS": "empty_effects"}


def additional_driver_identity():
    names = subprocess.check_output(["git", "-C", str(ROOT), "ls-tree", "-r", "--name-only", "HEAD", "--", "tools/pubpres_mainline"], text=True).splitlines()
    result = {}
    for name in names:
        raw = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + name])
        need((ROOT / name).read_bytes() == raw, "Mainline driver differs from its committed source: " + name)
        result[name] = hashlib.sha256(raw).hexdigest()
    need(result, "Mainline driver was not committed")
    return result


def cohort(arms, sources, engine, registered):
    need([row["arm"] for row in arms] == registered["order"] and [row["index"] for row in arms] == list(range(6)),
         "Incomplete or reordered six-arm mainline cohort")
    matches = []
    targets = []
    for row in arms:
        stats = row["statistics"]
        need(stats["source"] == sources[row["arm"]]["source_commit"]
             and stats["registered_material_treatment"] == {"backend": "full", "policy": ""}
             and stats["same_frame_continuation"]["enabled"] is False
             and row["observers"]["presentation_enabled"] is False,
             "Source, material, continuation or observer population differs")
        need(stats["match"]["engine"] == digest(engine)
             and stats["match"]["render_thread"] == {"requested": "safe", "runtime": "safe"},
             "Stock Safe engine identity differs")
        matches.append(stats["match"])
        window = stats["windows"]["whole_capture"]
        gaps = window["physical_gap_ms"]
        observed_max = max(gaps["max"], window["physical_no_step_prefix_ms"], window["physical_no_step_suffix_ms"])
        targets.append({"role": row["arm"], "index": row["index"], "p95_ms": gaps["p95"],
                        "maximum_including_censored_boundaries_ms": observed_max,
                        "p95_deficit_ms": max(0, gaps["p95"] - registered["physical_targets"]["p95_ms"]),
                        "maximum_deficit_ms": max(0, observed_max - registered["physical_targets"]["maximum_ms"])})
    need(all(canonical(value) == canonical(matches[0]) for value in matches),
         "Hardware, fixture, Water law, camera, workers or physical workload differs")
    parity = physical_outcome_parity(arms)
    comparisons = {}
    for role, indices in (("M", (0, 2, 3, 5)), ("P", (1, 2, 3, 4))):
        selected = [dict(arms[index], index=order) for order, index in enumerate(indices)]
        comparisons[role] = compare_registered_direction(selected, reference=role)
    parity_ok = len(parity["pairs"]) == 15 and all(row["bodies_equal"] and row["admitted_moves_equal"] for row in parity["pairs"])
    return {"physical_outcome_parity": parity, "all_equal_step_pairs_match": parity_ok,
            "registered_direction": comparisons, "physical_targets": targets,
            "comparative_timing_qualified": parity_ok,
            "scope": "Raw rates/tails remain descriptive if any equal-step outcome differs. No physical monitor acceptance."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("main-source", "owner-source", "main-runtime", "owner-runtime", "runtime", "engine", "frozen-correctness", "water-correctness", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--case", action="append", required=True)
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--rapier-runtime", type=Path)
    args = parser.parse_args()
    need(not any(key.startswith("WB_COMBINED_") for key in os.environ), "Inherited combined experiment")
    registered = json.loads(REGISTRATION.read_bytes())
    need(registered["schema"] == "pubpres-mainline-three-source-v1" and registered["order"] == ["M", "P", "C", "C", "P", "M"]
         and set(args.case) <= set(registered["cases"]) and len(args.case) == len(set(args.case)), "Unregistered comparison")
    output = args.output.resolve()
    need(not output.exists(), "Preserve original comparison output")
    roots = {"M": args.main_source.resolve(), "P": args.owner_source.resolve(), "C": args.source.resolve()}
    runtimes = {"M": args.main_runtime.resolve(), "P": args.owner_runtime.resolve(), "C": args.runtime.resolve()}
    driver = driver_identity()
    extra_driver = additional_driver_identity()
    sources = {}
    for role, root in roots.items():
        source = source_identity(root)
        source["native_runtime"] = validate_runtime(root, source, runtimes[role], False)
        sources[role] = source
    need(sources["M"]["source_commit"] == registered["accepted_main"]
         and sources["P"]["source_commit"] == registered["owner_reference"]
         and sources["C"]["source_commit"] == driver["source_commit"]
         and sources["C"]["source_tree"] == driver["source_tree"], "Source registration differs")
    need(sources["M"]["native_runtime"]["toolchain"] == sources["P"]["native_runtime"]["toolchain"] == sources["C"]["native_runtime"]["toolchain"],
         "Native compiler/dependency cohort differs")
    engine = args.engine.resolve()
    platform = "windows" if os.name == "nt" else "linux"
    backend = "opengl3_angle" if os.name == "nt" else "opengl3"
    need(digest(engine) == ENGINE_SHA256[platform], "Exact official Godot4.7 is required")
    prerequisites = [verify_summary(args.frozen_correctness, sources["C"], driver, engine, "frozen"),
                     verify_summary(args.water_correctness, sources["C"], driver, engine, "water")]
    base = json.loads((ROOT / "tools/pubpres_final/registration.json").read_bytes())
    need(all(base[key] == registered[key] for key in ("minimum_capture_usec", "minimum_real_steps", "maximum_capture_usec", "reported_gap_thresholds_ms")),
         "Frozen capture windows or gap thresholds changed")
    campaign = campaign_settings(base, args.case, False)
    campaign["source_commits"]["main"] = registered["accepted_main"]
    overlays = {RECOVERY_OBSERVER: ROOT / "tools/pubpres_final_recovery/pubpres_recovery_gameplay.gd", OBSERVER: HERE / "gameplay.gd"}
    campaign["overlay_sha256"].update({name: digest(path) for name, path in overlays.items()})
    campaign["observer_entrypoint"] = OBSERVER
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    report = {"schema": "pubpres-mainline-three-source-result-v1", "registration": registered,
              "registration_sha256": digest(REGISTRATION), "sources": sources, "driver": driver,
              "mainline_driver_sha256": extra_driver, "prerequisites": prerequisites,
              "reducer": verify_renderer_reducer(ROOT), "cases": [], "failures": [], "complete": False,
              "physical_acceptance": "HOLD", "scope": registered["scope"]}
    def save(): write_json(output / "SUMMARY.json", report)
    save()
    templates = {}
    for role in ("M", "P", "C"):
        templates[role] = prepare(roots[role], sources[role], output / ("template-" + role), campaign, engine, args.rapier_runtime, overlay_sources=overlays)
        strict_logs(output / ("template-" + role) / "import")
    for case in campaign["cases"]:
        arms = []
        for index, role in enumerate(registered["order"]):
            source = sources[role]
            folder = output / case["id"] / (str(index) + "-" + role)
            folder.mkdir(parents=True)
            project = output / "projects" / (case["id"] + "-" + str(index))
            project.parent.mkdir(parents=True, exist_ok=True)
            copy_project(templates[role], project, imported=True)
            receipt = folder / "receipt.json"
            nonce = uuid.uuid4().hex
            settings = selectors({"material": "full", "same_frame_continuation": False, "wave_column_probe": False, "causal": False}, nonce)
            settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2", CYBERSAND_PLAYABILITY_RENDER_THREAD="safe", CYBERSAND_MATERIAL_QUEUE_THREAD="safe",
                            CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="0", CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL="0", CYBERSAND_DIAG_ACTUAL_SUBMISSION="0",
                            CYBERSAND_DIAG_WATER_COMPOSITION="0" if role == "M" else "1", CYBERSAND_ENGINE_RENDER_LOOKAHEAD="",
                            CYBERSAND_ENGINE_RENDER_LOOKAHEAD_TRACE="", CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER="0")
            settings[SELECTOR] = "0"
            settings.update({key: "0" if role == "M" else "1" for key in FLAGS})
            if role == "M":
                settings.update(CYBERSAND_DIAG_PHYSICS_PUBLICATION="combined", CYBERSAND_DIAG_PRESENTATION="legacy",
                                CYBERSAND_DIAG_RENDER_CADENCE="source-default", CYBERSAND_DIAG_MATERIAL_TIMING="legacy")
                for key in ("CYBERSAND_DIAG_SAME_FRAME_CONTINUATION", "CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES", "CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE"):
                    settings.pop(key)
            arguments = ["--path", str(project), "--rendering-method", "gl_compatibility", "--rendering-driver", backend,
                         "--render-thread", "safe", "--audio-driver", "Dummy", "--log-file", str(folder / "godot.log"), "--script", "res://" + OBSERVER,
                         "--", "--receipt=" + str(receipt), "--fixture=" + case["fixture"], "--camera=" + case["camera"], "--workers=" + str(case["workers"]),
                         "--water-law=" + case["water_law"], "--water-variant=" + case.get("water_variant", "reference"),
                         "--water-profile=" + case.get("water_profile", campaign["measurement"]["water_profile"]),
                         "--input-mode=" + case.get("input_mode", "tape"), "--command-mode=repeated_callback", "--observer-mode=full"]
            write_json(folder / "arm.json", {"source": source, "scenario": case, "nonce": nonce, "selectors": settings, "arguments": arguments})
            print(case["id"], index, role, flush=True)
            try:
                process = execute_with_resources(engine, arguments, folder, source["source_commit"], settings, 420, args.display_wrapper)
                strict_logs(folder)
                data = json.loads(receipt.read_bytes())
                if role == "M": validate_control(data, case, campaign, source, nonce, engine, backend)
                else:
                    validate_requested_renderer(data, case, campaign, source["source_commit"], nonce, digest(engine), "safe", expected_driver=backend)
                    validate_selectors(data, TREATMENT, 1, False)
                    validate_task_completion(data, False)
                for phase in ("selectors_before", "selectors_after"):
                    state = data[phase]
                    need(all(state["requested"].get(key) == ("0" if role == "M" else "1") for key in FLAGS), "Owner-selected policy request differs")
                    if role != "M":
                        need(all(state["mainline_selected_policy"].get(field) is True for field in FLAGS.values()), "Selected policy did not execute")
                analysis = reduce_receipt(receipt, campaign, project=project, engine=engine, arm_letter="M" if role == "M" else "C", expected_render_thread="safe")
                observers = validate_observers(receipt, process, project, False)
                events = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()]
                validate_draw_identity(events, "safe")
                analysis["physical_gap_counts_above_ms"] = observed_gap_counts(receipt.with_name("receipt-events.jsonl"), analysis["windows"], registered["reported_gap_thresholds_ms"])
                need(process["observed_application_pid"] == data["process_id"], "Observed process differs")
                row = {"arm": role, "index": index, "statistics": analysis, "observers": observers, "process": process, "receipt_sha256": digest(receipt)}
                arms.append(row)
                write_json(folder / "analysis.json", row)
                shutil.rmtree(project)
            except Exception as error:
                report["failures"].append({"case": case["id"], "index": index, "role": role, "reason": str(error)})
            save()
        result = {"case": case["id"], "arms": arms}
        try:
            result.update(cohort(arms, sources, engine, registered))
            if not result["comparative_timing_qualified"]:
                report["failures"].append({"case": case["id"], "reason": "Equal-step physical/input outcomes differ; descriptive timing retained, comparative qualification refused"})
        except Exception as error:
            report["failures"].append({"case": case["id"], "reason": str(error)})
        report["cases"].append(result)
        save()
    report["complete"] = not report["failures"]
    save()
    print(json.dumps({"complete": report["complete"], "failures": report["failures"], "physical_acceptance": "HOLD"}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
