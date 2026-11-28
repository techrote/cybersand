#!/usr/bin/env python3
"""Prospective same-repaired-engine Safe/Separate ABBA, always Draft/HOLD.

The original #609 renderer cohort and all its failed outcomes remain intact.
This runner admits one newly built engine only after independent raw font,
ordinary startup and per-owner two-slot GPU history qualification.
"""
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

from run_comparison import ROOT, HERE, OBSERVER, campaign_settings, driver_identity, prepare, validate_registered_sources
from run_campaign import copy_project, execute, source_identity
from run_focus import observed_gap_counts, selectors, validate_runtime, write_json
from results import digest, need
from results_registered_renderer import reduce_receipt
from renderer_contract import verify_renderer_reducer
from metrics import supplementary_metrics, validate_slot_treatment
from observer_support import SELECTOR as PRESENTATION_SELECTOR, execute_with_resources, validate_observers
from run_renderer_comparison import (EXTERNAL_INPUTS, ORACLE_RESOURCE, strict_logs,
                                     validate_draw_identity, validate_renderer_cohort, validate_requested_renderer)

sys.path.insert(0,str(ROOT/"tools/pubpres_final_engine"))
import payload
from run_font_qualification import driver_identity as font_driver_identity, verify_qualification

FONT_OBSERVER = "tests/pubpres_final_font_gameplay.gd"
ORDER = [{"engine":"repaired","render_thread":thread} for thread in ("safe","separate","separate","safe")]


def registration() -> dict:
    value=json.loads((HERE/"font_renderer_registration.json").read_bytes())
    need(value.get("schema")=="pubpres-final-font-renderer-registration-v1" and value.get("order")==ORDER
         and value.get("cases")==["wave_512_follow","wave_gameplay_2048_follow"]
         and value.get("platform")=="windows" and value.get("driver")=="opengl3_angle"
         and value.get("material")=="full" and value.get("full_image_slots")==2
         and value.get("physics")=="early" and value.get("presentation")=="coherent"
         and value.get("same_frame_continuation") is False and value.get("material_deadline_hz")==0
         and value.get("minimum_capture_usec")==10000000 and value.get("minimum_real_steps")==144
         and value.get("maximum_capture_usec")==90000000
         and value.get("comparisons")=={"same_repaired_engine_safe_separate_abba":[0,1,2,3]},
         "New engine-owner cohort differs from its separate registration")
    return value


def verify_driver() -> dict:
    result=driver_identity()
    font=font_driver_identity()
    need(result["source_commit"]==font["source_commit"] and result["source_tree"]==font["source_tree"],
         "Font qualification and timed driver source differ")
    result["files_sha256"].update(font["files_sha256"])
    for name in EXTERNAL_INPUTS:
        raw=subprocess.check_output(["git","-C",str(ROOT),"show","HEAD:"+name])
        need((ROOT/name).read_bytes()==raw,"Engine-owner comparison input differs: "+name)
        result["files_sha256"][name]=hashlib.sha256(raw).hexdigest()
    return result


def validate_deadline_off(data: dict):
    for phase in ("selectors_before","selectors_after"):
        status=data[phase]
        value=status.get("font_cohort_material_deadline")
        need(status["requested"].get("CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ")=="0"
             and isinstance(value,dict) and value.get("schema")=="pubpres-material-deadline-v1"
             and type(value.get("requested_hz")) is int and value["requested_hz"]==0
             and value.get("enabled") is False and value.get("physical_credit") is False
             and type(value.get("interval_usec")) is int and value["interval_usec"]==0
             and type(value.get("pending_count")) is int and value["pending_count"]==0
             and type(value.get("accepted_uploads")) is int and value["accepted_uploads"]==0,
             "Same-engine comparison acquired an unregistered material deadline")


def validate_cohort(arms: list[dict], registered: dict, engine_sha256: str, presentation_enabled: bool) -> dict:
    need(type(presentation_enabled) is bool and len(arms)==4,"Missing same-engine comparison arm")
    need(all(arm["statistics"]["match"]["engine"]==engine_sha256
             and arm["observers"]["presentation_enabled"] is presentation_enabled
             for arm in arms),"Same-engine cohort changed executable or observer policy")
    joined=validate_renderer_cohort(arms,{**registered,"repaired_engine_sha256":engine_sha256})
    return {**joined,"scope":"One actual repaired executable, Safe/Separate/Separate/Safe. All source/runtime, hardware, workload and equal-step physical outcomes remain matched. This isolates render ownership within that executable; it does not attribute stock/custom differences to one patch or qualify physical NVIDIA hardware."}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ("source","runtime","engine-payload","font-qualification","output"):
        parser.add_argument("--"+name,type=Path,required=True)
    payload.add_identity_arguments(parser)
    parser.add_argument("--case",action="append",required=True)
    parser.add_argument("--rapier-runtime",type=Path)
    parser.add_argument("--presentation-observer",action="store_true")
    args=parser.parse_args()
    need(os.name=="nt","New engine-owner execution is registered only for Windows/ANGLE")
    need(not any(key.startswith("WB_COMBINED_") for key in os.environ),"Inherited unregistered Workbench control")
    output=args.output.resolve()
    need(not output.exists(),"Keep original attempts; comparison output must be new")
    driver=verify_driver();registered=registration()
    need(len(args.case)==len(set(args.case)) and set(args.case)<=set(registered["cases"]),"Unknown or duplicate engine-owner workload")
    source_root=args.source.resolve();source=source_identity(source_root)
    source["native_runtime"]=validate_runtime(source_root,source,args.runtime.resolve(),False)
    base=json.loads((HERE/"registration.json").read_bytes())
    validate_registered_sources({"C":source},driver,base,"single")
    identity=payload.identity_arguments(args)
    need(identity["build_source"]==source["source_commit"],"Prospective engine build and application source must be the same campaign head")
    engine_root=args.engine_payload.resolve()
    build=payload.verify_payload(engine_root,**identity)
    engine=engine_root/build["gui_executable"]
    engine_sha=build["executables"][engine.name]["sha256"]
    need(digest(engine)==engine_sha,"New actual engine differs from admitted build")
    font_gate=verify_qualification(args.font_qualification,source=source,repaired_payload=engine_root,**identity)
    campaign=campaign_settings(base,args.case,False)
    need(all(campaign["measurement"][key]==registered[key] for key in
             ("minimum_capture_usec","minimum_real_steps","maximum_capture_usec")),"Engine cohort changed physical windows")
    campaign["overlay_sha256"][FONT_OBSERVER]=digest(HERE/"pubpres_final_font_gameplay.gd")
    campaign["observer_entrypoint"]=FONT_OBSERVER
    output.mkdir(parents=True);write_json(output/"campaign.json",campaign)
    report={"schema":"pubpres-final-font-renderer-comparison-v1","registration":registered,
            "registration_sha256":digest(HERE/"font_renderer_registration.json"),"source":source,"driver":driver,
            "reducer":verify_renderer_reducer(ROOT),"engine_build":build,"engine_admission":identity,
            "engine_sha256":engine_sha,"font_qualification":font_gate,"campaign_sha256":digest(output/"campaign.json"),
            "order":ORDER,"presentation_observer":args.presentation_observer,"qualification":[],"cases":[],
            "failures":[],"complete":False,"physical_acceptance":"HOLD"}
    def save(): write_json(output/"SUMMARY.json",report)
    save()
    template=prepare(source_root,source,output/"template",campaign,engine,args.rapier_runtime,
                     overlay_sources={FONT_OBSERVER:HERE/"pubpres_final_font_gameplay.gd"})
    strict_logs(output/"template/import")
    shutil.copyfile(ROOT/"tools/pubpres_final_windows/two_slot_oracle.gd",template/ORACLE_RESOURCE)
    sys.path.insert(0,str(ROOT/"tools/pubpres_final_windows"))
    from two_slot_oracle import validate as validate_two_slot_oracle
    qualified={}
    for thread in ("safe","separate"):
        folder=output/"qualification"/thread;folder.mkdir(parents=True)
        project=output/"oracle-projects"/thread;project.parent.mkdir(parents=True,exist_ok=True)
        copy_project(template,project,imported=True);receipt=folder/"receipt.json"
        settings=selectors({"material":"full","same_frame_continuation":False,"wave_column_probe":False,"causal":False},uuid.uuid4().hex)
        settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2",CYBERSAND_PLAYABILITY_RENDER_THREAD=thread,
                        CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="0")
        record={"render_thread":thread,"engine_sha256":engine_sha,"complete":False}
        try:
            process=execute(engine,["--path",str(project),"--rendering-method","gl_compatibility",
                "--rendering-driver","opengl3_angle","--render-thread",thread,"--audio-driver","Dummy",
                "--script","res://"+ORACLE_RESOURCE,"--","--material=full","--receipt="+str(receipt)],
                folder,source["source_commit"],settings,600)
            strict_logs(folder)
            evidence=validate_two_slot_oracle(receipt,project,source=source["source_commit"],driver="opengl3_angle",
                                               engine_sha256=engine_sha,separate=thread=="separate")
            need(process["observed_application_pid"]==evidence["context"]["process_id"],"Two-slot actual process identity differs")
            record.update(complete=True,receipt_sha256=digest(receipt),evidence=evidence,process=process)
            shutil.rmtree(project)
        except Exception as error:
            record["failure"]=str(error);report["failures"].append({"qualification":thread,"reason":str(error)})
        qualified[thread]=record["complete"];report["qualification"].append(record);save()
    for case in campaign["cases"]:
        arms=[]
        for index,treatment in enumerate(ORDER):
            thread=treatment["render_thread"];folder=output/case["id"]/f"{index}-repaired-{thread}"
            folder.mkdir(parents=True)
            if not all(qualified.values()):
                failure={"case":case["id"],"index":index,"treatment":treatment,
                         "reason":"Both actual render owners require complete exact two-slot GPU history before any timing"}
                report["failures"].append(failure);write_json(folder/"not-run.json",failure);save();continue
            project=output/"projects"/f"{case['id']}-{index}";project.parent.mkdir(parents=True,exist_ok=True)
            copy_project(template,project,imported=True);receipt=folder/"receipt.json";nonce=uuid.uuid4().hex
            settings=selectors({"material":"full","same_frame_continuation":False,"wave_column_probe":False,"causal":False},nonce)
            settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS="2",CYBERSAND_PLAYABILITY_RENDER_THREAD=thread,
                            CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ="0")
            settings[PRESENTATION_SELECTOR]="1" if args.presentation_observer else "0"
            arguments=["--path",str(project),"--rendering-method","gl_compatibility","--rendering-driver","opengl3_angle",
                "--render-thread",thread,"--audio-driver","Dummy","--log-file",str(folder/"godot.log"),
                "--script","res://"+FONT_OBSERVER,"--","--receipt="+str(receipt),"--fixture="+case["fixture"],
                "--camera="+case["camera"],"--workers="+str(case["workers"]),"--water-law="+case["water_law"],
                "--water-variant="+case.get("water_variant","reference"),
                "--water-profile="+case.get("water_profile",campaign["measurement"]["water_profile"]),
                "--input-mode="+case.get("input_mode","tape"),"--command-mode=repeated_callback","--observer-mode=full"]
            write_json(folder/"arm.json",{"source":source,"scenario":case,"nonce":nonce,"treatment":treatment,
                                         "engine_sha256":engine_sha,"selectors":settings,"arguments":arguments})
            print(case["id"],index,treatment,flush=True)
            try:
                need(digest(engine)==engine_sha,"Actual executable changed before timed arm")
                process=execute_with_resources(engine,arguments,folder,source["source_commit"],settings,420)
                strict_logs(folder);data=json.loads(receipt.read_bytes())
                validate_requested_renderer(data,case,campaign,source["source_commit"],nonce,engine_sha,thread)
                validate_deadline_off(data)
                analysis=reduce_receipt(receipt,campaign,project=project,engine=engine,arm_letter="C",expected_render_thread=thread)
                observers=validate_observers(receipt,process,project,args.presentation_observer)
                events=[json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()]
                validate_draw_identity(events,thread)
                slots=validate_slot_treatment(data,events,2,True,expected_extent=campaign["fixtures"][case["fixture"]]["extent"])
                analysis["physical_gap_counts_above_ms"]=observed_gap_counts(receipt.with_name("receipt-events.jsonl"),
                    analysis["windows"],base["reported_gap_thresholds_ms"])
                supplement=supplementary_metrics(receipt)
                need(thread!="separate" or all(not value["material_draw_identity_available"] for value in supplement["windows"].values()),
                     "Separate draw notification invented a live material association")
                need(process["observed_application_pid"]==data["process_id"],"Owned actual application PID differs")
                process["app_sampler_pid_matched"]=True
                for name,value in (("analysis",analysis),("supplementary",supplement),("observers",observers),("process",process)):
                    write_json(folder/(name+".json"),value)
                arms.append({"arm":"C","index":index,"treatment":treatment,"statistics":analysis,"slots":slots,
                             "supplementary":supplement,"process":process,"observers":observers,"receipt_sha256":digest(receipt)})
                shutil.rmtree(project)
            except Exception as error:
                report["failures"].append({"case":case["id"],"index":index,"treatment":treatment,"reason":str(error)})
            save()
        row={"case":case["id"],"arms":arms}
        try: row.update(validate_cohort(arms,registered,engine_sha,args.presentation_observer))
        except (ValueError,KeyError,TypeError) as error: report["failures"].append({"case":case["id"],"reason":str(error)})
        report["cases"].append(row);save()
    report["complete"]=not report["failures"];save()
    print(json.dumps({"output":str(output),"complete":report["complete"],"physical_acceptance":"HOLD"}))
    return 0 if report["complete"] else 1


if __name__=="__main__": raise SystemExit(main())
