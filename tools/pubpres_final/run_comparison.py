#!/usr/bin/env python3
"""Source-exact prospective physical-progression comparisons, always Draft/HOLD.

The original V3 reducer and observer remain byte-for-byte unchanged. A tiny
observer subclass records the new selector and its own source identity. Every
successful capture still passes the complete original V3 physical oracle.
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

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/pubpres_completion"))
sys.path.insert(0, str(ROOT / "tools/pubpres003"))
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))
from run_campaign import copy_project, execute, git, physical_outcome_parity, source_identity
from run_focus import (ENGINE_SHA256, FROZEN_REGISTRATION, OBSERVER_TARGET,
                       observed_gap_counts, selectors, stage_committed_project,
                       validate_complete_comparison, validate_requested_capture,
                       validate_runtime, verify_driver, write_json)
from results import canonical, digest, need
from results_same_frame import reduce_receipt
from run_source_abba import compare_registered_direction, TOOLCHAIN_FIELDS
from metrics import supplementary_metrics, validate_slot_treatment, validate_deadline_baseline
from observer_support import (DIRECTORY as OBSERVER_DIRECTORY, PROBE as PRESENTATION_PROBE,
                              SELECTOR as PRESENTATION_SELECTOR, observer_bundle,
                              execute_with_resources, validate_observers, calibration_measurements)

OBSERVER = "tests/pubpres_final_gameplay.gd"
MODES = ("source-abba", "slots-abba", "observer-abba", "single")


def driver_identity() -> dict:
    identity = verify_driver()
    tracked = git(ROOT, "ls-tree", "-r", "--name-only", "HEAD", "--", "tools/pubpres_final").splitlines()
    actual = {path.relative_to(ROOT).as_posix() for path in HERE.iterdir()
              if path.is_file() and path.suffix in (".py", ".gd", ".json", ".ps1")}
    needed = {path for path in tracked if Path(path).suffix in (".py", ".gd", ".json", ".ps1")}
    need(actual == needed and needed, "Uncommitted or missing final measurement driver")
    needed.add("tools/pubpres_completion/run_source_abba.py")
    for relative in sorted(needed):
        committed = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + relative])
        need((ROOT / relative).read_bytes() == committed, "Final driver differs from committed bytes: " + relative)
        identity["files_sha256"][relative] = digest(ROOT / relative)
    observer_identity = observer_bundle.identity()
    identity["files_sha256"].update(observer_identity["files_sha256"])
    identity["supplementary_observer_bundle"] = observer_identity
    return identity


def comparison_plan(mode: str, slots: int) -> list[dict]:
    need(mode in MODES and slots in (2, 3), "Unknown final comparison mode or slots")
    if mode == "source-abba":
        need(slots == 2, "Source comparison must isolate native/application delta with two Full slots")
        return [{"role": role, "slots": 2} for role in ("D", "C", "C", "D")]
    if mode == "slots-abba":
        return [{"role": "C", "slots": value} for value in (2, 3, 3, 2)]
    if mode == "observer-abba":
        need(slots == 2, "Observer calibration must retain two Full slots")
        return [{"role": "C", "slots": 2, "presentation_observer": value} for value in (False, True, True, False)]
    return [{"role": "C", "slots": slots}]


def validate_registered_sources(sources: dict, driver: dict, registration: dict, mode: str):
    need(sources["C"]["source_commit"] == driver["source_commit"]
         and sources["C"]["source_tree"] == driver["source_tree"],
         "Candidate must be the exact committed source and tree of this measurement driver")
    if mode == "source-abba":
        need(sources["D"]["source_commit"] == registration["predecessor"]["source"],
             "Source control must be the explicitly registered frozen c90 predecessor")


def campaign_settings(registration: dict, cases: list[str], sustained: bool) -> dict:
    frozen = ROOT / registration["predecessor"]["campaign_path"]
    need(digest(frozen) == registration["predecessor"]["campaign_sha256"] == FROZEN_REGISTRATION,
         "Frozen predecessor registration changed")
    campaign = json.loads(frozen.read_bytes())
    choices = {case["id"]: case for case in campaign["cases"]}
    choices["wave_1024_follow_4"] = {**choices["wave_512_follow"],
                                     "id": "wave_1024_follow_4", "fixture": "basin1024"}
    campaign["fixtures"]["basin1024"] = {"extent": [1024, 1024], "kind": "authored_setup_v2"}
    admitted = set(registration["primary_cases"] + registration["confirmation_cases"])
    need(len(cases) == len(set(cases)) and set(cases) <= admitted, "Unknown or duplicated final workload")
    campaign["cases"] = [choices[name] for name in cases]
    campaign["arms"]["C"].update(material="full", material_pool_policy=None, same_frame_continuation=False)
    need(campaign["measurement"]["minimum_capture_usec"] == registration["minimum_capture_usec"]
         and campaign["measurement"]["minimum_real_steps"] == registration["minimum_real_steps"]
         and campaign["measurement"]["maximum_capture_usec"] == registration["maximum_capture_usec"],
         "Original observation windows changed")
    if sustained:
        campaign["measurement"]["minimum_capture_usec"] = registration["sustained_minimum_usec"]
    campaign["overlay_sha256"][OBSERVER_TARGET] = digest(ROOT / "tools/pubpres003/pubpres_causal_gameplay.gd")
    campaign["overlay_sha256"][OBSERVER] = digest(HERE / "pubpres_final_gameplay.gd")
    campaign["overlay_sha256"][PRESENTATION_PROBE] = digest(OBSERVER_DIRECTORY / "presentation_probe.gd")
    campaign["observer_entrypoint"] = OBSERVER
    return campaign


def verify_rapier(root: Path, source: dict, override: Path | None) -> tuple[Path, dict]:
    platform = "windows" if os.name == "nt" else "linux"
    relative = f"godot/addons/godot-rapier2d/runtime-provenance.{platform}.json"
    record = json.loads(subprocess.check_output(["git", "-C", str(root), "show", source["source_commit"] + ":" + relative]))
    binary = override.resolve() if override is not None else root / record["artifact"]
    need(digest(binary) == record["sha256"] and binary.stat().st_size == record["size"],
         "Rapier binary differs from committed platform provenance")
    for name, expected in record["source_inputs"].items():
        actual = subprocess.check_output(["git", "-C", str(root), "show", source["source_commit"] + ":" + name])
        need(hashlib.sha256(actual).hexdigest() == expected, "Rapier source input differs: " + name)
    return binary, record


def prepare(root: Path, source: dict, output: Path, campaign: dict, engine: Path,
            rapier_override: Path | None, *, overlay_sources: dict[str, Path] | None = None) -> Path:
    template = stage_committed_project(root, source["source_commit"], output)
    recipes = template.parent / "examples/worldgen"
    if recipes.is_dir():
        shutil.copytree(recipes, template / "authoring/worldgen", dirs_exist_ok=True)
    runtime = source["native_runtime"]
    shutil.copyfile(runtime["binary_path"], template / runtime["staged_relative_path"])
    rapier_binary, rapier = verify_rapier(root, source, rapier_override)
    shutil.copyfile(rapier_binary, template / Path(rapier["artifact"]).relative_to("godot"))
    for relative, expected in campaign["overlay_sha256"].items():
        if relative == PRESENTATION_PROBE:
            need(digest(OBSERVER_DIRECTORY / "presentation_probe.gd") == expected,
                 "Supplementary observer dependency changed")
            observer_bundle.stage(template)
            continue
        original = ((overlay_sources or {})[relative] if relative in (overlay_sources or {}) else
                    HERE / "pubpres_final_gameplay.gd" if relative == OBSERVER else
                    ROOT / "tools/pubpres003/pubpres_causal_gameplay.gd" if relative == OBSERVER_TARGET else
                    ROOT / "godot" / relative)
        need(digest(original) == expected, "Observer dependency changed: " + relative)
        shutil.copyfile(original, template / relative)
    authored = {path.relative_to(template).as_posix(): digest(path)
                for path in template.rglob("*") if path.is_file()}
    execute(engine, ["--headless", "--audio-driver", "Dummy", "--path", str(template), "--editor", "--import"],
            output / "import", source["source_commit"], {}, 300)
    imported = {path.relative_to(template).as_posix(): digest(path)
                for path in template.rglob("*") if path.is_file()}
    bootstrap = {".godot/global_script_class_cache.cfg", ".godot/extension_list.cfg"}
    changes = [name for name, expected in authored.items() if name not in bootstrap and imported.get(name) != expected]
    write_json(output / "source-custody.json", {"source_commit": source["source_commit"],
               "source_tree": source["source_tree"], "authored_files_sha256": authored,
               "imported_files_sha256": imported, "authored_mutations": changes})
    need(not changes, "Import changed source-exact authored comparison inputs")
    return template


def validate_final_cohort(arms: list[dict], mode: str, plan: list[dict]) -> dict:
    validate_complete_comparison(arms, len(plan))
    parity = physical_outcome_parity(arms)
    need(all(pair["bodies_equal"] and pair["admitted_moves_equal"] for pair in parity["pairs"]),
         "Equal-step actual actor trajectories or admitted actions differ")
    for arm, treatment in zip(arms, plan):
        stats = arm["statistics"]
        need(stats["registered_material_treatment"] == {"backend": "full", "policy": ""}
             and stats["same_frame_continuation"]["enabled"] is False, "Final cohort enabled another treatment")
        for phase in ("selectors_before", "selectors_after"):
            selected = stats[phase]
            need(selected["physics"] == "early" and selected["presentation"] == "coherent"
                 and selected["cadence"] == "repaired" and selected["rendezvous"]["mode"] == "off",
                 "Final cohort changed physical/cadence/presentation control")
        need(arm["slots"]["requested_slots"] == treatment["slots"], "Final cohort slot order differs")
        need(arm["observers"]["presentation_enabled"] is treatment["presentation_observer"],
             "Final cohort supplementary observer treatment differs")
    return parity


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("control-source", "control-runtime", "candidate-source", "candidate-runtime", "engine", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--case", action="append", required=True)
    parser.add_argument("--mode", choices=MODES, default="source-abba")
    parser.add_argument("--slots", type=int, choices=(2, 3), default=2)
    parser.add_argument("--sustained", action="store_true")
    parser.add_argument("--presentation-observer", action="store_true",
                        help="Enable the separately source-bound submitted-pose sidecar equally on every arm")
    parser.add_argument("--rapier-runtime", type=Path)
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--allow-development-toolchain-drift", action="store_true")
    args = parser.parse_args()
    need(not args.sustained or args.mode == "single", "Sustained captures are separate single arms")
    need(not args.presentation_observer or args.mode != "observer-abba",
         "Observer calibration supplies its own explicit off/on/on/off selector order")
    need(not args.allow_development_toolchain_drift or args.mode != "observer-abba",
         "Observer calibration requires the pinned independently built runtime")
    output, engine = args.output.resolve(), args.engine.resolve()
    need(not output.exists(), "Evidence output exists; original attempts must be retained")
    driver = driver_identity()
    registration = json.loads((HERE / "registration.json").read_bytes())
    need(registration["schema"] == "pubpres-playability-final-registration-v1", "Unknown final registration")
    plan = comparison_plan(args.mode, args.slots)
    observer_registration = None
    if args.mode == "observer-abba":
        observer_registration = json.loads((HERE / "observer_registration.json").read_bytes())
        need(observer_registration["schema"] == "pubpres-final-observer-calibration-registration-v1"
             and observer_registration["order"] == [False, True, True, False]
             and set(args.case) <= set(observer_registration["cases"]),
             "Observer calibration must use its registered primary cases and selector order")
        need(all(observer_registration[name] == registration[name] for name in
                 ("minimum_capture_usec", "minimum_real_steps", "maximum_capture_usec")),
             "Observer calibration changed the original observation window")
    else:
        plan = [dict(item, presentation_observer=args.presentation_observer) for item in plan]
    campaign = campaign_settings(registration, args.case, args.sustained)
    platform = "windows" if os.name == "nt" else "linux"
    need(digest(engine) == ENGINE_SHA256[platform], "Engine differs from official Godot 4.7 platform pin")
    roots = {"D": args.control_source.resolve(), "C": args.candidate_source.resolve()}
    runtime_paths = {"D": args.control_runtime.resolve(), "C": args.candidate_runtime.resolve()}
    sources = {}
    for role in {item["role"] for item in plan}:
        source = source_identity(roots[role])
        source["native_runtime"] = validate_runtime(roots[role], source, runtime_paths[role],
                                                    args.allow_development_toolchain_drift)
        sources[role] = source
    validate_registered_sources(sources, driver, registration, args.mode)
    if args.mode == "source-abba":
        toolchains = [sources[role]["native_runtime"]["toolchain"] for role in ("D", "C")]
        need(toolchains[0] == toolchains[1], "Matched sources use different native toolchains/dependencies")
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    report = {"schema": "pubpres-playability-final-comparison-v1", "mode": args.mode,
              "registration_sha256": digest(HERE / "registration.json"), "driver": driver,
              "engine_sha256": digest(engine), "sources": sources, "order": plan,
              "campaign_sha256": digest(output / "campaign.json"), "cases": [], "failures": [],
              "complete": False, "physical_acceptance": "HOLD", "sustained": args.sustained,
              "scope": observer_registration["scope"] if observer_registration else registration["scope"],
              "observer_registration": observer_registration,
              "observer_registration_sha256": digest(HERE / "observer_registration.json") if observer_registration else None}
    write_json(output / "SUMMARY.json", report)
    templates = {}
    for role, source in sources.items():
        templates[role] = prepare(roots[role], source, output / ("template-" + role), campaign,
                                  engine, args.rapier_runtime)
    rendering_driver = "opengl3_angle" if platform == "windows" else "opengl3"
    for case in campaign["cases"]:
        arms = []
        for index, treatment in enumerate(plan):
            role, slots = treatment["role"], treatment["slots"]
            source = sources[role]
            folder = output / case["id"] / f"{index}-{role}-slots{slots}"
            project = output / "projects" / f"{case['id']}-{index}"
            project.parent.mkdir(parents=True, exist_ok=True)
            copy_project(templates[role], project, imported=True)
            folder.mkdir(parents=True)
            receipt = folder / "receipt.json"
            nonce = uuid.uuid4().hex
            settings = selectors({"material": "full", "same_frame_continuation": False,
                                  "wave_column_probe": False, "causal": False}, nonce)
            settings["CYBERSAND_DIAG_FULL_IMAGE_SLOTS"] = str(slots)
            settings["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"] = "0"
            settings[PRESENTATION_SELECTOR] = "1" if treatment["presentation_observer"] else "0"
            arguments = ["--path", str(project), "--rendering-method", "gl_compatibility",
                         "--rendering-driver", rendering_driver, "--render-thread", "safe", "--audio-driver", "Dummy",
                         "--log-file", str(folder / "godot.log"), "--script", "res://" + OBSERVER, "--",
                         "--receipt=" + str(receipt), "--fixture=" + case["fixture"],
                         "--camera=" + case["camera"], "--workers=" + str(case["workers"]),
                         "--water-law=" + case["water_law"], "--water-variant=" + case.get("water_variant", "reference"),
                         "--water-profile=" + case.get("water_profile", campaign["measurement"]["water_profile"]),
                         "--input-mode=" + case.get("input_mode", "tape"), "--command-mode=repeated_callback",
                         "--observer-mode=full"]
            if args.sustained:
                arguments.append("--sustained")
            write_json(folder / "arm.json", {"source": source, "scenario": case, "nonce": nonce,
                                             "treatment": treatment, "selectors": settings, "arguments": arguments})
            print(case["id"], index, treatment, flush=True)
            try:
                process = execute_with_resources(engine, arguments, folder, source["source_commit"], settings, 420, args.display_wrapper)
                data = json.loads(receipt.read_bytes())
                validate_requested_capture(data, case, campaign, source["source_commit"], nonce, rendering_driver)
                # Frozen acceptance is mandatory, with no monkeypatch/relabel.
                analysis = reduce_receipt(receipt, campaign, project=project, engine=engine, arm_letter="C")
                analysis["material_deadline_baseline"] = validate_deadline_baseline(data, required=role == "C")
                observers = validate_observers(receipt, process, project, treatment["presentation_observer"])
                events = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()]
                slot_evidence = validate_slot_treatment(data, events, slots,
                                                        require_status=args.mode == "slots-abba" or slots == 3,
                                                        expected_extent=campaign["fixtures"][case["fixture"]]["extent"])
                analysis["physical_gap_counts_above_ms"] = observed_gap_counts(
                    receipt.with_name("receipt-events.jsonl"), analysis["windows"],
                    registration["reported_gap_thresholds_ms"])
                supplement = supplementary_metrics(receipt)
                process["app_sampler_pid_matched"] = process["observed_application_pid"] == data["process_id"]
                need(process["app_sampler_pid_matched"], "Process memory sampler followed a different application")
                write_json(folder / "analysis.json", analysis)
                write_json(folder / "supplementary.json", supplement)
                write_json(folder / "observers.json", observers)
                write_json(folder / "process.json", process)
                arm_role = ("D" if index in (0, 3) else "C") if args.mode in ("slots-abba", "observer-abba") else role
                arms.append({"arm": arm_role, "index": index, "source_role": role, "statistics": analysis,
                             "supplementary": supplement, "slots": slot_evidence, "process": process,"observers":observers,
                             "receipt_sha256": digest(receipt)})
                shutil.rmtree(project)
            except Exception as error:
                failure = {"case": case["id"], "index": index, "treatment": treatment, "reason": str(error)}
                report["failures"].append(failure)
                print("Retained failed arm:", str(error), flush=True)
            write_json(output / "SUMMARY.json", report)
        record = {"case": case["id"], "arms": arms}
        try:
            record["physical_outcome_parity"] = validate_final_cohort(arms, args.mode, plan)
            if args.mode == "observer-abba":
                record["observer_calibration"] = calibration_measurements(arms)
            elif args.mode != "single":
                record["registered_direction"] = compare_registered_direction(arms)
        except (ValueError, TypeError, KeyError) as error:
            report["failures"].append({"case": case["id"], "reason": str(error)})
        report["cases"].append(record)
        write_json(output / "SUMMARY.json", report)
    report["complete"] = not report["failures"]
    write_json(output / "SUMMARY.json", report)
    print(json.dumps({"output": str(output), "complete": report["complete"], "failures": report["failures"],
                      "physical_acceptance": "HOLD"}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
