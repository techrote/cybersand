#!/usr/bin/env python3
"""Sustained source-exact ordinary eight-actor/painting Workbench qualification.

This is an explicit new workload, not a favorable replacement for the frozen
one-actor controls. It never declares a performance win from a single capture.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import uuid

from run_comparison import (ROOT, HERE, campaign_settings, driver_identity, prepare,
                            validate_registered_sources, OBSERVER as FINAL_OBSERVER)
from run_focus import (ENGINE_SHA256, observed_gap_counts, selectors,
                       validate_requested_capture, validate_runtime, write_json)
from run_campaign import copy_project, source_identity
from results import digest, need
from results_registered_mixed import reduce_receipt
from mixed_contract import OBSERVER, RESOURCE, verify_mixed_contract
from mixed_oracles import required_actors, validate_mixed_workload
from metrics import supplementary_metrics, validate_slot_treatment
from observer_support import SELECTOR as PRESENTATION_SELECTOR, execute_with_resources, validate_observers


def mixed_campaign(registration: dict, selected: list[str]) -> dict:
    base = json.loads((HERE / "registration.json").read_bytes())
    campaign = campaign_settings(base,["wave_512_follow"],True)
    need(selected and len(selected)==len(set(selected)) and set(selected)<=set(registration["cases"]),
         "Unknown or repeated mixed workload")
    reference = campaign["cases"][0]
    campaign["schema"] = "pubpres-final-mixed-campaign-v1"
    campaign["cases"] = [{**reference,"id":name,"fixture":"basin512" if "512" in name else "basin1024",
                           "water_profile":"gameplay_main846f"} for name in selected]
    campaign["fixtures"]["basin1024"] = {"extent":[1024,1024],"kind":"pubpres_final_mixed_eight_actor_v1"}
    campaign["fixtures"]["basin512"] = {"extent":[512,512],"kind":"pubpres_final_mixed_eight_actor_v1"}
    campaign["measurement"].pop("required_actor")
    campaign["measurement"]["required_actors"] = required_actors(registration)
    campaign["measurement"]["water_profile"] = "gameplay_main846f"
    campaign["predecessor_observation_limits"] = campaign["measurement"]["limits"]
    campaign["measurement"]["limits"] = [
        "New eight-actor mixed workload; it does not replace any retained one-actor performance control.",
        "All real native/body samples, exact installed terrain, actual callback credit and original input leases remain mandatory.",
        "Current gameplay Wave uses two rounds, spill and ballistic transport; Water ledger and closed basin quantity are checked.",
        "All eight body/node/RID owners and seven neutral controls are observed; the passive barrel must have an actual platform contact.",
        "Paint admission uses the ordinary worker queue at registered physical ticks. The first observed material native tick/revision remains explicit; repeated requested ticks alone do not establish matched native paint execution.",
        "Material freshness is the first matching owned CPU image after an actual production upload. Its bounded scan costs are disclosed. GPU completion, device-input arrival and scanout remain unobserved.",
        "Safe draw notifications are Main delivery. Latest completed physical age does not prove that pose was displayed.",
        "Full two-slot, Early, coherent presentation, actual Safe owner and continuation OFF are explicit controls.",
        "Single sustained captures establish workload correctness and timing evidence, not a comparative performance win or human/NVIDIA acceptance.",
    ]
    for key in ("minimum_capture_usec","maximum_capture_usec"):
        need(campaign["measurement"][key]==registration[key], "Mixed capture registration differs")
    need(campaign["measurement"]["minimum_real_steps"]==registration["minimum_real_steps"], "Mixed real-step minimum differs")
    campaign["overlay_sha256"].pop(FINAL_OBSERVER)
    campaign["overlay_sha256"].update({OBSERVER:digest(HERE / "pubpres_final_mixed_gameplay.gd"),
                                      RESOURCE:digest(HERE / "mixed_registration.json")})
    campaign["observer_entrypoint"] = OBSERVER
    campaign["mixed_registration_sha256"] = digest(HERE / "mixed_registration.json")
    return campaign


def correctness_prerequisite(path: Path, source: dict, driver: dict, engine: Path) -> dict:
    proof = json.loads(path.read_bytes())
    need(proof["schema"]=="pubpres-playability-final-correctness-v1" and proof["complete"] is True
         and proof["headless_only"] is False and proof["physical_acceptance"]=="HOLD",
         "Mixed execution requires complete graphical correctness on this exact source/runtime")
    need(all(proof["source"][name]==source[name] for name in ("source_commit","source_tree"))
         and proof["driver"]["source_commit"]==driver["source_commit"]
         and proof["driver"]["source_tree"]==driver["source_tree"]
         and proof["native"]["binary_sha256"]==source["native_runtime"]["binary_sha256"]
         and proof["native"]["manifest_sha256"]==source["native_runtime"]["manifest_sha256"]
         and proof["engine_sha256"]==digest(engine), "Mixed correctness belongs to a different source/runtime/engine")
    need(not proof["import_source_mutations"] and not proof["final_source_mutations"]
         and proof["outcomes"] and all(row["valid"] is True for row in proof["outcomes"]),
         "Mixed correctness evidence has source changes or an invalid outcome")
    required = {"test_full_image_ring_publication","pubpres_full_image_ring_oracle","test_full_image_ring_main_recovery",
                "test_physical_actor_integration","test_workbench_physics_publication"}
    need(required<={row["test"] for row in proof["outcomes"]}, "Required physical and material history prerequisites missing")
    return {"path":str(path),"sha256":digest(path),"source":source["source_commit"],
            "outcome_count":len(proof["outcomes"]),"complete":True}


def strict_logs(folder: Path):
    text = "\n".join((folder / name).read_text(encoding="utf-8",errors="replace")
                     for name in ("stdout.log","stderr.log"))
    need("ERROR:" not in text, "Strict mixed Workbench diagnostic failure")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source","runtime","engine","correctness-summary","output"):
        parser.add_argument("--"+name,type=Path,required=True)
    parser.add_argument("--case",action="append")
    parser.add_argument("--rapier-runtime",type=Path)
    parser.add_argument("--display-wrapper",type=Path)
    args = parser.parse_args()
    output, engine = args.output.resolve(), args.engine.resolve()
    need(not output.exists(), "Original mixed evidence must be retained; output must be new")
    driver = driver_identity()
    contract = verify_mixed_contract(ROOT)
    registration = json.loads((HERE / "mixed_registration.json").read_bytes())
    need(registration["schema"]=="pubpres-final-mixed-registration-v1", "Unknown mixed registration")
    campaign = mixed_campaign(registration,args.case or registration["cases"])
    platform = "windows" if os.name=="nt" else "linux"
    need(digest(engine)==ENGINE_SHA256[platform], "Mixed qualification requires exact official Godot4.7")
    root = args.source.resolve()
    source = source_identity(root)
    source["native_runtime"] = validate_runtime(root,source,args.runtime.resolve(),False)
    base = json.loads((HERE / "registration.json").read_bytes())
    validate_registered_sources({"C":source},driver,base,"single")
    prerequisite = correctness_prerequisite(args.correctness_summary.resolve(),source,driver,engine)
    output.mkdir(parents=True)
    write_json(output / "campaign.json",campaign)
    report = {"schema":"pubpres-final-mixed-qualification-v1","source":source,"driver":driver,
              "engine_sha256":digest(engine),"registration":registration,"contract":contract,
              "registration_sha256":digest(HERE / "mixed_registration.json"),
              "campaign_sha256":digest(output / "campaign.json"),"correctness":prerequisite,
              "cases":[],"failures":[],"complete":False,"physical_acceptance":"HOLD",
              "scope":registration["scope"],
              "comparison_limit":"Single sustained workload qualification. Tick-addressed worker paint admission may land in different native ticks across repetitions; requested physical tick alone does not prove an equal material timeline or permit a causal timing comparison."}
    def save():
        write_json(output / "SUMMARY.json",report)
    save()
    template = prepare(root,source,output / "template",campaign,engine,args.rapier_runtime,
                       overlay_sources={OBSERVER:HERE / "pubpres_final_mixed_gameplay.gd",
                                        RESOURCE:HERE / "mixed_registration.json"})
    strict_logs(output / "template/import")
    rendering_driver = "opengl3_angle" if platform=="windows" else "opengl3"
    for case in campaign["cases"]:
        folder = output / case["id"]
        project = output / "projects" / case["id"]
        project.parent.mkdir(parents=True,exist_ok=True)
        copy_project(template,project,imported=True)
        folder.mkdir()
        receipt = folder / "receipt.json"
        nonce = uuid.uuid4().hex
        settings = selectors({"material":"full","same_frame_continuation":False,
                              "wave_column_probe":False,"causal":False},nonce)
        settings["CYBERSAND_DIAG_FULL_IMAGE_SLOTS"] = "2"
        settings["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"] = "0"
        settings[PRESENTATION_SELECTOR] = "1"
        arguments = ["--path",str(project),"--rendering-method","gl_compatibility",
                     "--rendering-driver",rendering_driver,"--render-thread","safe","--audio-driver","Dummy",
                     "--log-file",str(folder / "godot.log"),"--script","res://"+OBSERVER,"--",
                     "--receipt="+str(receipt),"--fixture="+case["fixture"],"--camera=follow","--workers=4",
                     "--water-law=wave_flow_v1","--water-variant=reference","--water-profile=gameplay_main846f",
                     "--input-mode=tape","--command-mode=repeated_callback","--observer-mode=full","--sustained"]
        write_json(folder / "arm.json",{"source":source,"case":case,"nonce":nonce,"selectors":settings,"arguments":arguments})
        print(case["id"],"eight actors / live paint / 60 seconds",flush=True)
        try:
            process = execute_with_resources(engine,arguments,folder,source["source_commit"],settings,420,args.display_wrapper)
            strict_logs(folder)
            data = json.loads(receipt.read_bytes())
            validate_requested_capture(data,case,campaign,source["source_commit"],nonce,rendering_driver)
            need(data["fixture"]["registration_sha256"]==report["registration_sha256"], "Actual mixed registration differs")
            analysis = reduce_receipt(receipt,campaign,project,engine,"C")
            observers = validate_observers(receipt,process,project,True)
            events = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()][1:]
            slots = validate_slot_treatment(data,events,2,require_status=True)
            mixed = validate_mixed_workload(data,events,registration)
            analysis["physical_gap_counts_above_ms"] = observed_gap_counts(receipt.with_name("receipt-events.jsonl"),
                                            analysis["windows"],base["reported_gap_thresholds_ms"])
            supplement = supplementary_metrics(receipt)
            supplement["scope"]["validation"] = "Separate explicit eight-actor mixed reducer passed every retained native/terrain/callback/input/Water/GPU predicate, all eight real owners, and additive ordinary paint/control/contact gates."
            process["app_sampler_pid_matched"] = process["observed_application_pid"]==data["process_id"]
            need(process["app_sampler_pid_matched"], "Mixed memory sampler followed another process")
            for name,value in (("analysis",analysis),("mixed-analysis",mixed),("supplementary",supplement),("process",process),("observers",observers)):
                write_json(folder / (name+".json"),value)
            report["cases"].append({"case":case["id"],"valid":True,"statistics":analysis,"mixed":mixed,
                                    "supplementary":supplement,"slots":slots,"process":process,"observers":observers,"receipt_sha256":digest(receipt)})
            shutil.rmtree(project)
        except Exception as error:
            report["failures"].append({"case":case["id"],"reason":str(error)})
            report["cases"].append({"case":case["id"],"valid":False,"failure":str(error)})
            print("Retained failed mixed workload:",str(error),flush=True)
        save()
    report["complete"] = not report["failures"]
    save()
    print(json.dumps({"output":str(output),"complete":report["complete"],"failures":report["failures"],"physical_acceptance":"HOLD"}))
    return 0 if report["complete"] else 1


if __name__=="__main__":
    raise SystemExit(main())
