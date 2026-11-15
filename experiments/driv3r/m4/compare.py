"""M4 first paired native 36-decision A1/A2/A3 Q8 study, source-fenced.

Each arm runs independently against identical initial native fixture/seed and host
legal option semantics. Optional typed channels only change model information,
never the legality engine. Never imply causal inference from richer arms alone.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import traceback

from experiments.driv3r.backend import parse_choice_response
from experiments.driv3r.qualify import new_backend
from experiments.driv3r.m3_history.native import HistorySession
from experiments.driv3r.m3_native.qualify import (
    ROOT,M1_SHA,M1_SCHEMA_SHA,PROTOCOL,START,
    _assert,_dump,_blob,canonical,digest,world,observation_record
)
from experiments.driv3r.m3_history.qualify import _op,_record_action,_record_reversal
from experiments.driv3r.m3_model.short import legal_candidates,_native_action
from experiments.driv3r.d_common.v1.verify import SCHEMA,validate_bundle
from .guides import make,values_for,GOAL,ARMS

MAX_DECISIONS=36
MAX_NATIVE_PAINT=56
MAX_RECOVERIES=8
MAX_AUTO_STEPS=12
SCENARIO={"id":"m4-a1a2a3-guided-coverage-v1","fixture":"wall-v1",
          "world":[512,512],"focus":[0,0,96,96],"goal":GOAL,
          "seed":570,"max_model_decisions":36,"max_native_writes":56,
          "max_brush_up_recoveries":8,"max_auto_after_recovery":12,
          "host_legality":"native_empty_cardinal_with_protection_and_stop",
          "same_candidate_policy_all_arms":True,
          "no_model_training":True,"no_heldout_confirmation":True,
          "no_real_material_undo_in_comparison":True}


def legal(native,cursor,history,recoveries,edits):
    offered=legal_candidates(native,cursor)
    if edits>=MAX_NATIVE_PAINT:
        return [c for c in offered if c["id"]=="STOP"]
    if recoveries<MAX_RECOVERIES and len(history)>2:
        p=history[-2]
        if abs(p[0]-cursor[0])+abs(p[1]-cursor[1])==1:
            offered.append({"id":"BACKTRACK","kind":"backtrack","path":[cursor.copy(),p.copy()],
                            "footprint":[],"material":None,"max_changed_cells":0})
    if recoveries<MAX_RECOVERIES and len(history)>5 and cursor!=START:
        offered.append({"id":"RELOCATE_START","kind":"branch_relocate",
                        "path":[cursor.copy(),START.copy()],"footprint":[],
                        "material":None,"max_changed_cells":0})
    return sorted(offered,key=lambda v:v["id"])


def ask(backend,arm,guide,samples,before,cursor,offered,i):
    descriptions={}
    features={}
    for c in offered:
        if c["id"]=="STOP":
            descriptions[c["id"]]="Stop only when done or no productive legal route remains"
        elif c["kind"]=="backtrack":
            descriptions[c["id"]]="Brush-up return to previous visited cursor without removing material"
        elif c["kind"]=="branch_relocate":
            descriptions[c["id"]]="Brush-up jump to saved starting branch, keeping all native edits"
        else:
            p=c["path"][-1]
            distance=abs(p[0]-GOAL[0])+abs(p[1]-GOAL[1])
            descriptions[c["id"]]=(f"Paint one legal empty cell at {p}; "
                                   f"distance toward goal {distance}")
            features[c["id"]]=values_for(guide,samples,p)
    state={
       "objective":"Extend a productive connected material trail to goal while respecting native authority",
       "model_decision_index":i,"decision_budget":MAX_DECISIONS,
       "cursor":cursor,"goal":GOAL,
       "native_world_material_sha256":before["world_material_sha256"],
       "native_epoch":[before["generation"],before["revision"],before["tick"]],
       "soft_positive_guidance":{"format":"u16le","sha256":guide["values"]["sha256"],
                                 "zero":"neutral"},
       "optional_semantics":[{"channel_id":c["channel_id"],"semantic":c["semantic_id"],
                               "class":c["signal_class"],"sha256":c["values"]["sha256"],
                               "units":c["units"],"scale":c["scale"]}
                               for c in guide["optional_channels"]],
       "candidate_signals":features,
       "legal_candidates":[c["id"] for c in offered],
    }
    questions={"next_action":{"type":"choice",
       "instructions":"Choose one host-legal action. Prefer safe productive drawing toward the goal; use brush-up recovery when blocked. Guidance is advisory, not permission. STOP only when finished or stuck.",
       "criteria":descriptions}}
    result=backend.decide(canonical(state).decode(),questions,timeout_seconds=90)
    if result.get("status")!="ok":
        raise RuntimeError(f"M4 Q8 decision failed: {result.get('status')} {result.get('error')}")
    parsed=parse_choice_response(result["raw_response"],"next_action",
                                 [c["id"] for c in offered])
    candidate=next(c for c in offered if c["id"]==parsed["candidate_id"])
    evidence={"index":i,"arm":arm,"model_request":{"state":state,"questions":questions},
              "model_response":result,"parsed_choice":parsed,
              "choice":candidate["id"],
              "legal_candidate_set_sha256":digest(offered),
              "presentation_sha256":digest({"state":state,"questions":questions})}
    return candidate,evidence


def observe_record(root,episode,journal,native,cursor,history,guide,prior,receipt):
    response=native.observe()
    _assert(response["status"]=="completed" and response["m3"]["cursor"]==cursor,
            "Real native observation or host cursor not at expected source fence")
    before=response["observation"]
    record=observation_record(root,before,episode,len(journal),
                              f"obs-{len(journal)}",cursor,history,prior,receipt)
    record["target"]=GOAL.copy()
    record["objective"]="Original source-fenced guided procedural coverage"
    record["subgoal"]="Choose host-admitted drawing or recovery"
    prior_model=sum(x.get("type")=="action" and x.get("actor")=="d1" for x in journal)
    prior_native=sum(x.get("type")=="action" and x.get("execution_status")=="committed" for x in journal)
    record["budget"]["decisions_remaining"]=max(0,MAX_DECISIONS-prior_model)
    record["budget"]["material_cell_budget"]=max(0,MAX_NATIVE_PAINT-prior_native)
    record["budget"]["wall_seconds_remaining"]=4400
    record["guidance_channel_handling"]["used_channel_ids"]=[
        c["channel_id"] for c in guide["optional_channels"]]
    journal.append(record)
    return before,record


def draw(root,episode,native,journal,actions,receipts,artifacts,guide,
         cursor,history,code,obs,before,model=False,legal_hash=None,present_hash=None):
    _assert(len(actions)<MAX_NATIVE_PAINT,"Native writes reached hard 56-cell limit")
    target=cursor["to"]
    result=_native_action(native,target,code)
    _assert(result["status"]=="completed" and result["receipt"]["actual_changed_cells"]==1
            and result["receipt"]["readback_matches"] and
            result["receipt"]["receipts_reconstruct_materials"],
            "Original real native PAINT receipt does not match expected one-cell write")
    moved=native.cursor_move(cursor["from"],target)
    _assert(moved["status"]=="completed" and moved["receipt"]["actual_changed_cells"]==0,
            "Brush-up cursor update changed native material")
    act=_record_action(root,episode,len(journal),obs,before,cursor["from"],target,
                        code,result,legal_sha=legal_hash or digest([_op(target)]))
    if model:
        act["actor"]="d1";act["candidate_id"]=cursor["candidate"]
        act["model_decision_ref"]=f"model-{cursor['index']:04d}"
        act["candidate_set_sha256"]=present_hash
    journal.append(act)
    receipts.append(act["native_receipt_artifact"])
    artifacts.append(_blob(root,"native/"+result["observation"]["png_path"],"png"))
    actions.append({"point":target.copy(),"record_id":act["record_id"],
                    "origin":"d1" if model else "host_post_recovery_procedural",
                    "actual_native_material_sha256":result["observation"]["world_material_sha256"]})
    history.append(target.copy())
    return act


def replay(root,args,actions,expected):
    with HistorySession(ROOT,args.godot,root/"replay-native",args.source_sha,
                        runtime_manifest=args.runtime_manifest) as native:
        _assert(native.reset("wall-v1")["status"]=="completed","Replay reset refused")
        _assert(native.observe()["status"]=="completed","Replay observation refused")
        for i,a in enumerate(actions):
            result=_native_action(native,a["point"],f"M4_REPLAY_{i}")
            _assert(result["status"]=="completed"
                    and result["receipt"]["actual_changed_cells"]==1
                    and result["receipt"]["receipts_reconstruct_materials"],
                    "Independent native replay failed at an original recorded material operation")
        final=native.observe()
        _assert(final["status"]=="completed"
                and final["observation"]["world_material_sha256"]==expected,
                "Independent replay native World bytes differ")
        _assert(native.stop("M4 replay Stop")["status"]=="stopped","Replay Stop not confirmed")
    cleanup=json.loads((root/"replay-native/cleanup.json").read_text())
    _assert(cleanup["exit_code"]==0,"Independent replay native child not reaped")
    return {"actual_independent_native_replay":True,
            "native_material_actions_replayed":len(actions),
            "final_world_sha256":expected,"exit_code":0}


def qualify(args):
    _assert(args.arm in ARMS,"M4 arm must be A1/A2/A3")
    root=args.output.resolve()
    _assert(not root.exists(),"Cannot overwrite M4 original evidence")
    head=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],
                                 text=True,timeout=15).strip()
    _assert(head==args.source_sha,"M4 source mismatch")
    subprocess.run(["git","-C",str(ROOT),"merge-base","--is-ancestor",M1_SHA,"HEAD"],
                   check=True,timeout=15)
    _assert(hashlib.sha256(SCHEMA.read_bytes()).hexdigest()==M1_SCHEMA_SHA,
            "Frozen common contract modified")
    root.mkdir(parents=True)
    started=time.monotonic()
    episode=f"m4-guided-coverage-{args.arm}-seed570"
    model_manifest=json.loads(args.model_runtime_manifest.read_text())
    _assert(model_manifest["model_identity"]["repository"]=="LiquidAI/d1-2B",
            "Unpinned/unexpected model")
    guide,values=make(root,episode,args.arm)
    journal=[guide];actions=[];receipts=[];artifacts=[];steps=[]
    original_cursor=START.copy();cursor=START.copy()
    history=[START.copy()]
    model_calls=0;recovery_calls=0;productive=0
    prior=None;prior_receipt=None
    final=None;initial=None
    backend=new_backend(model_manifest,root/"resident-inference",
                        threads=2,ctx_size=4096,batch_size=2048)
    try:
        with backend:
            with HistorySession(ROOT,args.godot,root/"native",args.source_sha,
                                runtime_manifest=args.runtime_manifest) as native:
                reset=native.reset("wall-v1")
                _assert(reset["status"]=="completed","Initial native World not admitted")
                first=native.observe()
                _assert(first["status"]=="completed" and first["m3"]["cursor"]==START,
                        "Initial native material/cursor observation invalid")
                initial=first["observation"]
                _assert(native.save_branch("m4-start",START)["status"]=="completed",
                        "Native M4 trunk anchor refused")
                for i in range(MAX_DECISIONS):
                    if time.monotonic()-started>=4400:
                        raise TimeoutError("M4 four-thousand-four-hundred-second total bound")
                    before,obs=observe_record(root,episode,journal,native,
                                              cursor,history,guide,prior,prior_receipt)
                    opts=legal(before,cursor,history,recovery_calls,len(actions))
                    _assert(any(c["id"]=="STOP" for c in opts)
                            and len({c["id"] for c in opts})==len(opts),
                            "Host legal candidate set invalid")
                    choice,decision=ask(backend,args.arm,guide,values,before,cursor,opts,i)
                    blob=_dump(root,f"model/model-{i:02d}.json",decision)
                    artifacts.append(blob)
                    model_calls+=1
                    trace={"index":i,"source_world_sha256":before["world_material_sha256"],
                           "cursor_before":cursor.copy(),
                           "candidate_ids":[x["id"] for x in opts],
                           "legal_sha256":decision["legal_candidate_set_sha256"],
                           "choice":choice["id"],"model_file":blob["path"],
                           "model_visible_sha256":decision["presentation_sha256"]}
                    steps.append(trace)
                    if choice["id"]=="STOP":
                        journal.append({
                            "protocol":PROTOCOL,"type":"action","record_id":f"action-STOP-{i}",
                            "episode_id":episode,"sequence":len(journal),
                            "observation_ref":obs["record_id"],"world_precondition":world(before),
                            "candidate_set_sha256":decision["presentation_sha256"],
                            "legal_candidate_set_sha256":decision["legal_candidate_set_sha256"],
                            "candidate_id":"STOP","actor":"d1","mode":"stop",
                            "cursor_before":cursor.copy(),"cursor_after":cursor.copy(),
                            "path":[cursor.copy()],"brush_state":"up","guidance_ref":"guide-001",
                            "operation_sha256":None,"model_decision_ref":f"model-{i:04d}",
                            "predicted_effects":{"actual_changed_cells":0},
                            "execution_status":"selected","native_receipt_ref":None,
                            "native_receipt_artifact":None,"world_postcondition":None})
                        trace.update({"cursor_after":cursor.copy(),
                                      "world_after_sha256":before["world_material_sha256"],
                                      "material_changed":False})
                        break
                    if choice["kind"]=="paint_and_move":
                        point=choice["path"][-1]
                        action=draw(root,episode,native,journal,actions,receipts,artifacts,
                                    guide,{"from":cursor.copy(),"to":point.copy(),
                                           "candidate":choice["id"],"index":i},
                                    history,f"MODEL_{args.arm}_{i}",obs,before,
                                    model=True,legal_hash=decision["legal_candidate_set_sha256"],
                                    present_hash=decision["presentation_sha256"])
                        prior,prior_receipt=action["record_id"],action["native_receipt_ref"]
                        cursor=point.copy()
                    elif choice["kind"] in ("backtrack","branch_relocate"):
                        _assert(prior is not None,"Cannot recover before a real native edit")
                        old=cursor.copy()
                        if choice["kind"]=="backtrack":
                            target=history[-2].copy()
                            acknowledged=native.cursor_move(cursor,target)
                            mechanism="BACKTRACK_CURSOR"
                            history.pop()
                        else:
                            target=START.copy()
                            acknowledged=native.relocate_branch("m4-start",cursor)
                            mechanism="RELOCATE_TO_BRANCH"
                            history.append(target.copy())
                        _assert(acknowledged["status"]=="completed"
                                and acknowledged["receipt"]["actual_changed_cells"]==0
                                and acknowledged["observation"]["world_material_sha256"]==
                                    before["world_material_sha256"],
                                "Host-only logical recovery mutated material")
                        rev=_record_reversal(episode,len(journal),f"RECOVERY_{i}",mechanism,
                                             prior,obs["record_id"],before,
                                             acknowledged["observation"],old,target)
                        journal.append(rev)
                        cursor=target.copy()
                        recovery_calls+=1
                        for j in range(2):
                            if productive>=MAX_AUTO_STEPS or len(actions)>=MAX_NATIVE_PAINT:
                                break
                            a,b=observe_record(root,episode,journal,native,cursor,
                                                history,guide,prior,prior_receipt)
                            options=[o for o in legal_candidates(a,cursor) if o["id"]!="STOP"]
                            if not options:
                                break
                            candidate=min(options,key=lambda c:(
                                abs(c["path"][-1][0]-GOAL[0])+abs(c["path"][-1][1]-GOAL[1]),
                                c["id"]))
                            target=candidate["path"][-1]
                            rec=draw(root,episode,native,journal,actions,receipts,artifacts,
                                      guide,{"from":cursor.copy(),"to":target.copy()},
                                      history,f"PROCEDURAL_{i}_{j}",b,a)
                            prior,prior_receipt=rec["record_id"],rec["native_receipt_ref"]
                            cursor=target.copy()
                            productive+=1
                    else:
                        raise RuntimeError("Unknown model-selected M4 host operation")
                    post=native.observe()
                    _assert(post["status"]=="completed" and post["m3"]["cursor"]==cursor,
                            "Post-decision native readback/cursor did not match")
                    trace.update({"cursor_after":cursor.copy(),
                                  "world_after_sha256":post["observation"]["world_material_sha256"],
                                  "material_changed":post["observation"]["world_material_sha256"]!=
                                                     before["world_material_sha256"],
                                  "host_autonomous_new_cells_this_step":
                                    productive-sum(t.get("host_autonomous_new_cells_this_step",0)
                                                   for t in steps[:-1])})
                terminal=native.observe()
                _assert(terminal["status"]=="completed","Final native observation failed")
                final=terminal["observation"]
                artifacts.append(_blob(root,"native/"+final["png_path"],"png"))
                _assert(native.stop("M4 bounded model comparison host Stop")["status"]=="stopped",
                        "M4 host Stop not confirmed")
        cleanup=json.loads((root/"native/cleanup.json").read_text())
        _assert(cleanup["exit_code"]==0,"M4 model episode native process not reaped")
        replayer=replay(root,args,actions,final["world_material_sha256"])
        _dump(root,"native-replay.json",replayer)
        _dump(root,"decision-effects.json",steps)
        _dump(root,"guide-original.json",guide)
        modelid=model_manifest["model_identity"]
        backendid=model_manifest["backend_identity"]
        tree=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD^{tree}"],
                                     text=True,timeout=15).strip()
        provenance={
            "protocol":PROTOCOL,"type":"provenance","record_id":"provenance-001",
            "episode_id":episode,"sequence":len(journal),"evidence_class":"native",
            "source_commit":args.source_sha,"source_tree":tree,"base_commit":M1_SHA,
            "interface_schema_sha256":M1_SCHEMA_SHA,
            "experiment_id":"m4-first-guided-coverage","arm":args.arm,"split":"pilot",
            "scenario_sha256":digest(SCENARIO),
            "algorithm":{"name":"m4_guided_coverage","version":"1",
                         "seed":570,"recipe_sha256":digest(SCENARIO)},
            "model":{"repo":modelid["repository"],"revision":modelid["revision"],
                     "weights_sha256":modelid["sha256"],
                     "backend_sha256":backendid["binary_sha256"]},
            "native":_blob(root,"native/"+final["world_material_path"],"i32le"),
            "native_receipts":receipts,"guidance_ref":"guide-001",
            "episode_record_refs":[v["record_id"] for v in journal],
            "final_world":world(final),
            "outcome":"success" if model_calls==MAX_DECISIONS else "stop",
            "metrics":{"model_decisions":model_calls,
                       "native_material_edits":len(actions),
                       "neural_recoveries":recovery_calls,
                       "productive_procedural_steps_after_recovery":productive,
                       "recovery_leverage":(productive/recovery_calls) if recovery_calls else None,
                       "first_selected_choice":steps[0]["choice"] if steps else None},
            "replay":"pass","artifacts":artifacts,
        }
        journal.append(provenance)
        assert validate_bundle(journal,evidence_root=root)["evidence_bytes_verified"]
        with (root/"events.jsonl").open("xb") as file:
            for event in journal:
                file.write(canonical(event)+b"\n")
        _assert(backend.shutdown_record and backend.shutdown_record["process_reaped"],
                "Resident Q8 process not reaped")
        _assert(len({x["model_response"]["pid"] for x in
                     (json.loads((root/f"model/model-{i:02d}.json").read_text())
                      for i in range(model_calls))})==1,
                "More than one resident Q8 PID observed")
        summary={
            "schema":"driv3r-m4-matched-first-pilot-v1","source_sha":args.source_sha,
            "arm":args.arm,"status":"PASS",
            "model_requests":model_calls,"model_selected_native_edits":
                sum(1 for a in actions if a["origin"]=="d1"),
            "actual_native_edits":len(actions),
            "neural_recovery_interventions":recovery_calls,
            "productive_procedural_steps_after_recovery":productive,
            "recovery_leverage":productive/recovery_calls if recovery_calls else None,
            "initial_world_sha256":initial["world_material_sha256"],
            "final_world_sha256":final["world_material_sha256"],
            "first_legal_catalog_sha256":steps[0]["legal_sha256"] if steps else None,
            "first_choice":steps[0]["choice"] if steps else None,
            "decision_effects":steps,
            "independent_native_replay":True,
            "native_exit_codes":[cleanup["exit_code"],replayer["exit_code"]],
            "resident_model_reaped":True,"heldout_confirmed":False,
            "limitations":["One development scenario/seed only","A2/A3 add information; representation effect not isolated",
                           "Stored-material images are not framebuffer captures"],
            "elapsed_seconds":round(time.monotonic()-started,3),
        }
        _dump(root,"summary.json",summary)
        print(json.dumps({"m4_arm":args.arm,"status":"PASS","model_decisions":model_calls,
                          "native_writes":len(actions),
                          "recovery_leverage":summary["recovery_leverage"],
                          "full_native_replay":True},sort_keys=True),flush=True)
        return summary
    except BaseException as exc:
        _dump(root,"failure.json",{"source_sha":args.source_sha,"arm":args.arm,
              "type":type(exc).__name__,"error":str(exc),"traceback":traceback.format_exc(),
              "model_calls":model_calls,"native_writes":len(actions)})
        raise

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--arm",choices=ARMS,required=True)
    p.add_argument("--godot",type=Path,required=True)
    p.add_argument("--runtime-manifest",type=Path,required=True)
    p.add_argument("--model-runtime-manifest",type=Path,required=True)
    p.add_argument("--source-sha",required=True)
    p.add_argument("--output",type=Path,required=True)
    qualify(p.parse_args())

if __name__=="__main__":
    main()
