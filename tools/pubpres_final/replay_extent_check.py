#!/usr/bin/env python3
"""Recheck retained 515fce graphical comparisons; never rerun or rewrite them.

Reconstruct only the declared source-identity files, from exact Git objects and
retained independently built runtimes. Run every frozen V3 predicate and the
corrected independently registered extent/slot check. No newer observer claim
is added to historical captures.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from run_comparison import ROOT, HERE
from runtime_replay import verify_recorded_runtime, identity as runtime_replay_identity
from run_focus import validate_complete_comparison, observed_gap_counts, write_json
from run_campaign import physical_outcome_parity
from results_same_frame import reduce_receipt
from run_source_abba import compare_registered_direction
from results import digest, need
from metrics import validate_slot_treatment

CAPTURE_DRIVER = "515fce2862dd87d8dd01935bdf7bd1736e645901"
OVERLAYS = {"tests/pubpres_final_gameplay.gd":"tools/pubpres_final/pubpres_final_gameplay.gd",
            "tests/pubpres003_causal_gameplay.gd":"tools/pubpres003/pubpres_causal_gameplay.gd"}


def git_bytes(commit: str, relative: str) -> bytes:
    return subprocess.check_output(["git","-C",str(ROOT),"show",commit+":"+relative])


def verify_retained_runtime(source: dict, folder: Path, *, target_platform: str) -> dict:
    """Replay every frozen runtime predicate for an explicit recorded target."""
    tree=subprocess.check_output(["git","-C",str(ROOT),"rev-parse",source["source_commit"]+"^{tree}"],text=True).strip()
    need(tree==source["source_tree"],"Captured source tree is not the exact Git object")
    record=json.loads((folder/"PUBPRES-RUNTIME.json").read_bytes())
    with tempfile.TemporaryDirectory(prefix="pubpres-replay-native-") as directory:
        staging=Path(directory)/"source"
        subprocess.run(["git","-C",str(ROOT),"worktree","add","--detach","--no-checkout",
                        str(staging),source["source_commit"]],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            subprocess.run(["git","-C",str(staging),"checkout",source["source_commit"],"--",
                            "native/include","native/src","godot/native_extension",record["build_script"]],
                           check=True,stdout=subprocess.DEVNULL)
            return verify_recorded_runtime(staging,source,folder,target_platform=target_platform)
        finally:
            subprocess.run(["git","-C",str(ROOT),"worktree","remove","--force",str(staging)],check=True)


def reconstruct(project: Path, data: dict, campaign: dict, native: Path, rapier: Path):
    source=data["source_identity"]["source_sha"]
    for resource,expected in data["source_identity"]["files"].items():
        need(resource.startswith("res://"),"Unexpected captured source resource")
        relative=resource.removeprefix("res://")
        need(".." not in Path(relative).parts and not Path(relative).is_absolute(),"Unsafe captured resource")
        if expected is None:continue
        if relative in campaign["overlay_sha256"]:
            # Exact original prepare() mapping: these two added resources live
            # under tools; remaining frozen overlays come from driver godot/.
            raw=git_bytes(CAPTURE_DRIVER,OVERLAYS.get(relative,"godot/"+relative))
        elif relative.endswith("/"+native.name):raw=native.read_bytes()
        elif relative.endswith("/"+rapier.name):raw=rapier.read_bytes()
        else:raw=git_bytes(source,"godot/"+relative)
        need(hashlib.sha256(raw).hexdigest()==expected,"Retained source/runtime differs: "+resource)
        target=project/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ("input","runtime-root","engine","rapier-runtime","output"):
        parser.add_argument("--"+key,type=Path,required=True)
    parser.add_argument("--target-platform",choices=("linux","windows"),required=True,
                        help="Recorded artifact platform; this reader never executes its binaries")
    args=parser.parse_args()
    incoming=args.input.resolve();output=args.output.resolve()
    need(not output.exists(),"Replay output must be new; retained evidence is immutable")
    report={"schema":"pubpres-final-retained-extent-replay-v1","capture_driver":CAPTURE_DRIVER,
            "replay_program_sha256":digest(Path(__file__)),"extent_checker_sha256":digest(HERE/"metrics.py"),
            "frozen_reducer_sha256":digest(ROOT/"tools/pubpres_playability/results_same_frame.py"),
            "recorded_target_platform":args.target_platform,"offline_runtime_reader":runtime_replay_identity(),
            "engine_sha256":digest(args.engine),"comparisons":[],"failures":[],
            "physical_acceptance":"HOLD","original_graphical_job_conclusion":"FAILURE",
            "scope":"Read-only replay of exact original source/runtime/raw traces. Corrected extent check binds campaign fixture dimensions independently of allocation telemetry. No workload rerun, historical summary rewrite or retrospective supplementary-observer claim."}
    for mode in ("source-abba","slots-abba"):
        folder=incoming/mode;original_path=folder/"SUMMARY.json";original=json.loads(original_path.read_bytes())
        need(original["driver"]["source_commit"]==CAPTURE_DRIVER and original["mode"]==mode,
             "This replay is registered only for the retained 515fce comparison")
        need(digest(args.engine)==original["engine_sha256"],"Retained executable identity differs")
        for name,expected in original["driver"]["files_sha256"].items():
            need(hashlib.sha256(git_bytes(CAPTURE_DRIVER,name)).hexdigest()==expected,
                 "Original executed driver source differs: "+name)
        campaign_path=folder/"campaign.json";campaign=json.loads(campaign_path.read_bytes())
        need(digest(campaign_path)==original["campaign_sha256"],"Original campaign bytes changed")
        sources=original["sources"];runtimes={}
        for role,source in sources.items():
            need(not source["working_tree_changes"] and not source["untracked_source_files"]
                 and source["qualified_exact_head"] is True,"Original source was not exact")
            verified=verify_retained_runtime(source,args.runtime_root.resolve()/role,target_platform=args.target_platform)
            need(all(verified[key]==source["native_runtime"][key] for key in
                     ("manifest_sha256","binary_sha256","source_inputs_sha256","toolchain","build_commit")),
                 "Retained runtime custody differs from captured source")
            runtimes[role]=verified
        comparison={"mode":mode,"original_summary_sha256":digest(original_path),
                    "original_complete":original["complete"],"original_failures":original["failures"],
                    "campaign_sha256":digest(campaign_path),"native_runtimes":runtimes,"cases":[]}
        for case in campaign["cases"]:
            arms=[]
            for index,treatment in enumerate(original["order"]):
                role,slots=treatment["role"],treatment["slots"]
                receipt=folder/case["id"]/f"{index}-{role}-slots{slots}"/"receipt.json"
                before=digest(receipt);data=json.loads(receipt.read_bytes())
                need(data["source_identity"]["source_sha"]==sources[role]["source_commit"],"Captured source role differs")
                with tempfile.TemporaryDirectory(prefix="pubpres-retained-identity-") as staging:
                    project=Path(staging)
                    reconstruct(project,data,campaign,Path(runtimes[role]["binary_path"]),args.rapier_runtime.resolve())
                    analysis=reduce_receipt(receipt,campaign,project=project,engine=args.engine,arm_letter="C")
                events=[json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()]
                slot_proof=validate_slot_treatment(data,events,slots,require_status=mode=="slots-abba" or slots==3,
                                                 expected_extent=campaign["fixtures"][case["fixture"]]["extent"])
                analysis["physical_gap_counts_above_ms"]=observed_gap_counts(receipt.with_name("receipt-events.jsonl"),
                                                           analysis["windows"],[100,250,500,1000])
                need(digest(receipt)==before,"Replay changed original receipt")
                arms.append({"index":index,"arm":("D" if index in(0,3) else "C") if mode=="slots-abba" else role,
                             "source_role":role,"statistics":analysis,"slots":slot_proof,"receipt_sha256":before})
            validate_complete_comparison(arms,4)
            parity=physical_outcome_parity(arms)
            need(all(row["bodies_equal"] and row["admitted_moves_equal"] for row in parity["pairs"]),
                 "Retained equal-step physical outcome or admitted input differs")
            comparison["cases"].append({"case":case["id"],"arms":arms,"physical_outcome_parity":parity,
                                        "registered_direction":compare_registered_direction(arms)})
        need(digest(original_path)==comparison["original_summary_sha256"],"Replay changed original summary")
        report["comparisons"].append(comparison)
    report["complete"]=not report["failures"]
    write_json(output,report)
    print(json.dumps({"output":str(output),"complete":report["complete"],
                      "original_graphical_job_conclusion":"FAILURE","physical_acceptance":"HOLD"}))
    return 0


if __name__=="__main__":raise SystemExit(main())
