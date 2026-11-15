"""S1-2B-DRIV3R M3 short *resident d1-Q8 selected* native Workbench smoke.

Decision backend: pinned, resident llama.cpp /v1/systemone, same one PID.
Native authority: existing source-fenced HistorySession, never model-issued RPC.
Max four model requests, four host-admitted one-cell edits, one brush-up
logical branch relocation, and one independent actual native replay.
No training, no formal A1/A2/A3, no material Undo in this first model smoke.
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
    ROOT, M1_SHA, M1_SCHEMA_SHA, PROTOCOL, START, DESTINATION,
    _dump, _blob, _assert, canonical, digest, world,
    guidance, observation_record,
)
from experiments.driv3r.m3_history.qualify import (
    _op, _record_action, _record_reversal,
)
from experiments.driv3r.d_common.v1.verify import SCHEMA, validate_bundle

SCENARIO={
 "id":"m3-model-short-4-decisions-001",
 "split":"pilot","fixture":"wall-v1","world":[512,512],"focus":[0,0,96,96],
 "start":START,"target":[14,26],"material":58,
 "max_model_requests":4,"max_native_actions":4,"replay":True,
 "stop_option":True,"legal_options":"host_cardinal_empty_neighbors",
 "model":"LiquidAI/d1-2B official Q8 only",
 "guidance":"M1 positive core A1, no optional channels",
 "max_episode_wall_seconds":600,
 "allow_long_horizon":False,"allow_model_training":False,
 "allow_a1_a2_a3_campaign":False,
}
DIRS=(("N",0,-1),("E",1,0),("S",0,1),("W",-1,0))


def legal_candidates(native: dict, position: list[int]) -> list[dict]:
    """One-cell cardinal movements and STOP, purely native-material/host defined."""
    _assert(native["focus"]==[0,0,96,96],"Unexpected native focus")
    x,y=position
    options=[]
    for direction,dx,dy in DIRS:
        nx,ny=x+dx,y+dy
        if not(0<=nx<96 and 0<=ny<96):
            continue
        if any(rx<=nx<rx+rw and ry<=ny<ry+rh
               for rx,ry,rw,rh in native["protected_rectangles"]):
            continue
        if native["materials"][ny*96+nx]!=0:
            continue
        options.append({"id":"MOVE_"+direction,
                        "path":[position.copy(),[nx,ny]],
                        "material":58,"footprint":[[nx,ny]],
                        "max_changed_cells":1,"kind":"paint_and_move"})
    options.append({"id":"STOP","path":[],"material":None,"footprint":[],
                    "max_changed_cells":0,"kind":"stop"})
    return sorted(options,key=lambda c:c["id"])


def select(backend, native: dict, cursor: list[int], offered: list[dict],
           index: int, *, timeout:float=75) -> tuple[dict,dict]:
    # Guidance and goal are *soft*, not permission grants.
    descriptions={}
    goal=SCENARIO["target"]
    for c in offered:
        if c["id"]=="STOP":
            descriptions[c["id"]]="Stop (only if target already reached or no useful legal action remains)"
        else:
            pt=c["path"][-1]
            md=abs(pt[0]-goal[0])+abs(pt[1]-goal[1])
            descriptions[c["id"]]=(f"Paint one native material-58 cell at ({pt[0]},{pt[1]}) "
                                   f"and move brush-up cursor; remaining Manhattan target distance {md}")
    state={
        "task":"Extend a connected original four-cell drawing through legal empty adjacent cells toward (14,26).",
        "objective":"Make useful progress, do not repeat a painted cell; stop only on completion or blockage.",
        "native_world_hash":native["world_material_sha256"],
        "native_revision":native["revision"],
        "step":index,"max_forward_decisions":4,"cursor":cursor,
        "target":goal,
        "local_material":{c["id"]:native["materials"][c["path"][-1][1]*96+c["path"][-1][0]]
                          for c in offered if c["id"]!="STOP"},
        "guidance":{"semantic_id":"positive_scalar/v1",
                    "encoding":"u16le","zero":"neutral","target":[12,25],
                    "interpretation":"soft positive guide is not an exclusion mask"},
        "offered_legal_ids":[c["id"] for c in offered],
    }
    question={"next_action":{"type":"choice",
      "instructions":"Choose the next ONE legal host-offered action. Prefer moving toward the target while continuing the drawing; STOP only if finished or no useful move remains.",
      "criteria":descriptions}}
    prompt=canonical(state).decode()
    result=backend.decide(prompt,question,timeout_seconds=timeout)
    if result.get("status")!="ok":
        raise RuntimeError(f"Resident d1-2B decision failed at step {index}: {result.get('status')} {result.get('error')}")
    answer=parse_choice_response(result["raw_response"],"next_action",[c["id"] for c in offered])
    choice=next(c for c in offered if c["id"]==answer["candidate_id"])
    return choice,{"state":state,"questions":question,"raw":result,"parsed":answer,
                   "choice":choice["id"],"index":index,
                   "legal_catalog_sha256":digest(offered),
                   "model_visible_sha256":digest({"state":state,"questions":question})}


def _native_action(native, point:list[int], name:str):
    pre=native.latest_observation
    _assert(pre is not None and pre["materials"][point[1]*96+point[0]]==0,
            "Selected cell is not native Empty")
    return native.apply([_op(point)],
                        expected_generation=pre["generation"],
                        expected_revision=pre["revision"],
                        expected_tick=pre["tick"],action_id=name,cell_budget=1)


def _replay(args,root:Path,selected:list[dict],target_sha:str) -> dict:
    with HistorySession(ROOT,args.godot,root/"replay-native",args.source_sha,
                        runtime_manifest=args.runtime_manifest) as replay:
        r=replay.reset("wall-v1");_assert(r["status"]=="completed","Replay fixture rejected")
        before=replay.observe();_assert(before["status"]=="completed","Replay observation failed")
        original=before["observation"]["world_material_sha256"]
        cursor=START.copy()
        for i,c in enumerate(selected):
            endpoint=c["path"][-1]
            result=_native_action(replay,endpoint,f"REPLAY-MODEL-{i}")
            _assert(result["status"]=="completed" and
                    result["receipt"]["actual_changed_cells"]==1 and
                    result["receipt"]["receipts_reconstruct_materials"],
                    "Real native model-choice replay write failed")
            moved=replay.cursor_move(cursor,endpoint)
            _assert(moved["status"]=="completed" and moved["m3"]["cursor"]==endpoint,
                    "Replay logical cursor move refused")
            cursor=endpoint.copy()
        final=replay.observe();_assert(final["status"]=="completed","Replay readback failed")
        _assert(final["observation"]["world_material_sha256"]==target_sha,
                "Independent replay full native material SHA mismatch")
        stop=replay.stop("M3 short resident model independent replay Stop")
        _assert(stop["status"]=="stopped","Replay Stop refused")
    cleanup=json.loads((root/"replay-native/cleanup.json").read_text())
    _assert(cleanup["exit_code"]==0,"Replay native process did not exit 0")
    return {"native_replay":"PASS","original_sha":original,"final_sha":target_sha,
            "actions_replayed":len(selected),"native_process_exit_code":cleanup["exit_code"]}


def qualify(args) -> dict:
    root=args.output.resolve()
    _assert(not root.exists(),"M3 short model evidence destination already exists")
    head=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],
                                  text=True,timeout=15).strip()
    _assert(head==args.source_sha,"Exact source does not match checked-out HEAD")
    subprocess.run(["git","-C",str(ROOT),"merge-base","--is-ancestor",M1_SHA,"HEAD"],
                   check=True,timeout=15)
    _assert(hashlib.sha256(SCHEMA.read_bytes()).hexdigest()==M1_SCHEMA_SHA,
            "Accepted M1 schema is not immutable")
    root.mkdir(parents=True)
    started=time.monotonic()
    records=[];receipts=[];artifacts=[];selected=[];decisions=[];cursor=START.copy()
    episode="m3-resident-q8-short-real-native"
    guide=guidance(root,episode)
    records.append(guide)
    runtime=json.loads(args.model_runtime_manifest.read_text())
    _assert(runtime["model_identity"]["sha256"] and
            runtime["backend_identity"]["binary_sha256"],
            "Pinned model/runtime provenance missing")
    _dump(root,"model/runtime-identity.json",runtime)
    backend=new_backend(runtime,root/"resident-inference",threads=2,ctx_size=4096,batch_size=2048)
    native_exit=None
    try:
        with backend:
            with HistorySession(ROOT,args.godot,root/"native",args.source_sha,
                                runtime_manifest=args.runtime_manifest) as native:
                reset=native.reset("wall-v1")
                _assert(reset["status"]=="completed","Real native reset refused")
                initial=native.observe()
                _assert(initial["status"]=="completed" and initial["m3"]["cursor"]==START,
                        "Initial native observation/cursor invalid")
                saved=native.save_branch("short-model-start",START)
                _assert(saved["status"]=="completed","Host branch anchor not saved")
                history=[START.copy()]
                previous_action=None
                previous_receipt=None
                for i in range(SCENARIO["max_model_requests"]):
                    _assert(time.monotonic()-started<SCENARIO["max_episode_wall_seconds"],
                            "Short model wall-clock budget exhausted")
                    fresh=native.observe()
                    _assert(fresh["status"]=="completed" and fresh["m3"]["cursor"]==cursor,
                            "Fresh source-fenced native observation or cursor mismatch")
                    before=fresh["observation"]
                    offered=legal_candidates(before,cursor)
                    _assert(len(offered)>=2,"No STOP-plus-move candidate")
                    record=observation_record(root,before,episode,len(records),f"obs-{i:02d}",
                                              cursor,history,previous_action,previous_receipt)
                    record["target"]=SCENARIO["target"].copy()
                    record["objective"]="Complete 4 legal host-selected incremental native cells toward target"
                    record["subgoal"]="Select useful legal next one-cell addition or STOP"
                    records.append(record)
                    choice,decision=select(backend,before,cursor,offered,i)
                    decision_blob=_dump(root,f"model/decision-{i:02d}.json",decision)
                    artifacts.append(decision_blob)
                    decisions.append(decision)
                    _assert(choice["id"] in {c["id"] for c in offered},
                            "Model selected unknown or illegal host candidate")
                    if choice["id"]=="STOP":
                        records.append({
                            "protocol":PROTOCOL,"type":"action",
                            "record_id":f"action-STOP-{i:02d}","episode_id":episode,
                            "sequence":len(records),
                            "observation_ref":record["record_id"],
                            "world_precondition":world(before),
                            "candidate_set_sha256":decision["model_visible_sha256"],
                            "legal_candidate_set_sha256":decision["legal_catalog_sha256"],
                            "candidate_id":"STOP","actor":"d1","mode":"stop",
                            "cursor_before":cursor.copy(),"cursor_after":cursor.copy(),
                            "path":[cursor.copy()],"brush_state":"up",
                            "guidance_ref":"guide-001","operation_sha256":None,
                            "model_decision_ref":f"model-{i:04d}",
                            "predicted_effects":{"native_changes":0},
                            "execution_status":"selected","native_receipt_ref":None,
                            "native_receipt_artifact":None,"world_postcondition":None
                        })
                        break
                    point=choice["path"][-1]
                    applied=_native_action(native,point,f"MODEL-{i}-{choice['id']}")
                    _assert(applied["status"]=="completed" and
                            applied["receipt"]["actual_changed_cells"]==1 and
                            applied["receipt"]["readback_matches"] and
                            applied["receipt"]["receipts_reconstruct_materials"],
                            "Model selection not followed by exact one-cell native material receipt")
                    moved=native.cursor_move(cursor,point)
                    _assert(moved["status"]=="completed" and moved["m3"]["cursor"]==point
                            and moved["receipt"]["actual_changed_cells"]==0,
                            "Host logical cursor movement not source-fenced")
                    action=_record_action(root,episode,len(records),record,before,
                                          applied["observation"],cursor,point,
                                          f"MODEL_{i:02d}",applied,
                                          legal_sha=decision["legal_catalog_sha256"])
                    action["actor"]="d1"
                    action["candidate_id"]=choice["id"]
                    action["candidate_set_sha256"]=decision["model_visible_sha256"]
                    action["model_decision_ref"]=f"model-{i:04d}"
                    records.append(action)
                    receipts.append(action["native_receipt_artifact"])
                    artifacts.append(_blob(root,"native/"+applied["observation"]["png_path"],"png"))
                    previous_action=action["record_id"]
                    previous_receipt=action["native_receipt_ref"]
                    selected.append(choice)
                    cursor=point.copy()
                    history.append(cursor.copy())
                final=native.observe()
                _assert(final["status"]=="completed","Final real native model episode readback missing")
                original_final=final["observation"]
                _assert(all(original_final["materials"][p["path"][-1][1]*96+p["path"][-1][0]]==58
                            for p in selected),"Model-selected material footprint lost")
                if selected:
                    returned=native.relocate_branch("short-model-start",cursor)
                    _assert(returned["status"]=="completed"
                            and returned["m3"]["cursor"]==START
                            and returned["observation"]["world_material_sha256"]==
                                original_final["world_material_sha256"],
                            "Logical branch recovery changed native material")
                    rev=_record_reversal(episode,len(records),"MODEL_BRANCH",
                                         "RELOCATE_TO_BRANCH",previous_action,
                                         records[1]["record_id"],original_final,
                                         returned["observation"],cursor,START)
                    records.append(rev)
                    final_obs=returned["observation"]
                else:
                    final_obs=original_final
                artifacts.append(_blob(root,"native/"+final_obs["png_path"],"png"))
                stop=native.stop("M3 resident d1 Q8 bounded short Stop")
                _assert(stop["status"]=="stopped"
                        and stop["observation"]["world_material_sha256"]==
                            final_obs["world_material_sha256"],
                        "Native explicit Stop changed material")
        native_exit=json.loads((root/"native/cleanup.json").read_text())["exit_code"]
        _assert(native_exit==0,"Native Workbench short-session process was not reaped")
        replay=_replay(args,root,selected,final_obs["world_material_sha256"]) if selected else {
            "native_replay":"not_attempted","actions_replayed":0}
        _dump(root,"replay-result.json",replay)
        ident=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD^{tree}"],
                                      text=True,timeout=20).strip()
        modelid=runtime["model_identity"]; backendid=runtime["backend_identity"]
        provenance={
            "protocol":PROTOCOL,"type":"provenance",
            "record_id":"provenance-001","episode_id":episode,
            "sequence":len(records),"evidence_class":"native",
            "source_commit":args.source_sha,"source_tree":ident,
            "base_commit":M1_SHA,"interface_schema_sha256":M1_SCHEMA_SHA,
            "experiment_id":"m3-short-resident-d1-2b","arm":"A1_short_q8",
            "split":"pilot","scenario_sha256":digest(SCENARIO),
            "algorithm":{"name":"m3_model_selected_native",
                         "version":"1","seed":570,"recipe_sha256":digest(SCENARIO)},
            "model":{"repo":modelid["repository"],"revision":modelid["revision"],
                     "weights_sha256":modelid["sha256"],
                     "backend_sha256":backendid["binary_sha256"]},
            "native":_blob(root,"native/"+final_obs["world_material_path"],"i32le"),
            "native_receipts":receipts,"guidance_ref":"guide-001",
            "episode_record_refs":[x["record_id"] for x in records],
            "final_world":world(final_obs),
            "outcome":"success" if len(selected)>=2 else "partial",
            "metrics":{"model_requests":len(decisions),
                       "native_material_actions":len(selected),
                       "native_material_cells_changed":len(selected),
                       "logical_relocations":int(bool(selected)),
                       "model_zero_output_tokens":all(
                           d["raw"]["raw_response"]["usage"]["output_tokens"]==0
                           for d in decisions),
                       "model_unique_pids":len({d["raw"]["pid"] for d in decisions}),
                       "model_latency_seconds":sum(d["raw"]["latency_seconds"] for d in decisions)},
            "replay":"pass" if selected else "not_attempted",
            "artifacts":artifacts,
        }
        records.append(provenance)
        checked=validate_bundle(records,evidence_root=root)
        _assert(checked["evidence_bytes_verified"],
                "M1 actual native and model provenance custody did not validate")
        with (root/"events.jsonl").open("xb") as file:
            for event in records:
                file.write(canonical(event)+b"\n")
        _assert(backend.shutdown_record and backend.shutdown_record["process_reaped"],
                "Resident d1 model process leaked")
        pass_gate=len(selected)>=2 and len(decisions)>=2 and \
                  len({d["raw"]["pid"] for d in decisions})==1 and \
                  replay["native_replay"]=="PASS"
        summary={
            "schema":"driv3r-m3-model-short-v1","source_sha":args.source_sha,
            "frozen_m1_source_sha":M1_SHA,"frozen_m1_schema_sha256":M1_SCHEMA_SHA,
            "status":"PASS" if pass_gate else "PARTIAL",
            "short_model_selected_native_gate":pass_gate,
            "model_requests":len(decisions),"valid_model_selected_material_actions":len(selected),
            "identical_legal_candidate_policy":"native_geometry_only",
            "native_replay":replay,"native_process_exit_code":native_exit,
            "resident_model_process_reaped":backend.shutdown_record["process_reaped"],
            "m4_36_decision_campaign_permitted_by_results":pass_gate,
            "native_final_world_sha256":final_obs["world_material_sha256"],
            "elapsed_seconds":round(time.monotonic()-started,3),
            "not_claimed":["vision","neural_material_undo","model_training",
                           "36_decision_comparative_performance"],
        }
        _dump(root,"summary.json",summary)
        print(json.dumps({"m3_model_short":summary["status"],
                          "model_requests":len(decisions),
                          "native_model_selected_actions":len(selected),
                          "native_replay":replay["native_replay"],
                          "source_sha":args.source_sha},sort_keys=True),flush=True)
        if not pass_gate:
            raise RuntimeError("M3 short model session lacked >=2 real selected native edits: retain PARTIAL")
        return summary
    except BaseException as exc:
        failure={"status":"FAILED","source_sha":args.source_sha,
                 "type":type(exc).__name__,"error":str(exc),
                 "traceback":traceback.format_exc(),
                 "model_requests_so_far":len(decisions),
                 "native_actions_so_far":len(selected)}
        _dump(root,"failure.json",failure)
        print(json.dumps({"m3_model_short":"FAIL","error":failure["error"]},sort_keys=True),flush=True)
        raise


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--source-sha",required=True)
    p.add_argument("--godot",type=Path,required=True)
    p.add_argument("--runtime-manifest",type=Path,required=True)
    p.add_argument("--model-runtime-manifest",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    qualify(p.parse_args())


if __name__=="__main__":
    main()
