"""M3-HISTORY-001: real native PAINT Undo + host-owned branch relocation,
followed by four bounded sequential native Workbench decisions.

NO d1 model inference. This admits a deterministic controller only; model
selection and full 36-decision A1/A2/A3 remain separately gated.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import traceback

from experiments.driv3r.d_common.v1.verify import SCHEMA, validate_bundle
from experiments.driv3r.m3_native.qualify import (
    ROOT, PROTOCOL, M1_SHA, M1_SCHEMA_SHA, FOCUS, START, DESTINATION,
    world, _dump, _blob, _assert, digest, canonical, guidance,
    observation_record,
)
from .native import HistorySession

SOURCE_SCENARIO = {
    "schema":"driv3r-m3-history-v1","world":[512,512],"focus":FOCUS,
    "phase1":{"action_ids":["DRAW_A","DRAW_B"],"material":58,
              "anchor":"branchA","relocation":"RELOCATE_TO_BRANCH",
              "native_inverse":"UNDO_MATERIAL_EDIT","replay":True},
    "phase2":{"decision_budget":4,"chosen_policy":"deterministic_adjacent_legal",
              "points":[[12,25],[13,25],[13,26],[14,26]],
              "branch_anchor_after_step":1,"material":58},
    "model":None,"model_selections":0,"training":False,
    "formal_A1_A2_A3":False,"allow_native_undo":True,
    "max_total_forward_material_operations_across_all_sessions":8,
    "max_real_native_undo_operations":3,
}


def _op(point: list[int]) -> dict:
    return {"shape":"rectangle","x0":point[0],"y0":point[1],
            "x1":point[0],"y1":point[1],"material":58}


def _check(result: dict, label: str) -> None:
    _assert(result.get("status")=="completed",f"{label} not completed: {result.get('reason')}")


def _read(root: Path, obs: dict, target: list[int]) -> int:
    return int(obs["materials"][target[1]*96 + target[0]])


def _record_action(root: Path, episode: str, sequence: int, source_observation: dict,
                   pre: dict, post: dict, start: list[int], end: list[int],
                   code: str, result: dict, *, legal_sha: str) -> dict:
    _check(result,"real native action "+code)
    _assert(result["receipt"]["actual_changed_cells"]==1 and
            result["receipt"]["readback_matches"] and
            result["receipt"]["receipts_reconstruct_materials"],
            "actual native Art receipts do not support exactly one new cell")
    receipt_ref="native-receipt-"+code
    receipt=_dump(root, "receipts/"+code+".json",
                  {"status":result["status"],"receipt":result["receipt"]})
    return {
        "protocol":PROTOCOL,"type":"action","record_id":"action-"+code,
        "episode_id":episode,"sequence":sequence,
        "observation_ref":source_observation["record_id"],
        "world_precondition":world(pre),
        "candidate_set_sha256":legal_sha,
        "legal_candidate_set_sha256":legal_sha,
        "candidate_id":code,"actor":"deterministic","mode":"add_material",
        "cursor_before":start.copy(),"cursor_after":end.copy(),
        "path":[start.copy(),end.copy()],"brush_state":"add",
        "guidance_ref":"guide-001",
        "operation_sha256":digest([_op(end)]),"model_decision_ref":None,
        "predicted_effects":{"native_material_cells_predicted":1},
        "execution_status":"committed","native_receipt_ref":receipt_ref,
        "native_receipt_artifact":receipt,"world_postcondition":world(post),
    }


def _record_reversal(episode: str, sequence: int, code: str, mechanism: str,
                     source_action: str, anchor_observation: str,
                     before_obs: dict, after_obs: dict,
                     cursor_before: list[int],cursor_after: list[int],
                     changed: int=0,undo_blob: dict|None=None) -> dict:
    return {
        "protocol":PROTOCOL,"type":"reversal","record_id":"reversal-"+code,
        "episode_id":episode,"sequence":sequence,"mechanism":mechanism,
        "source_action_ref":source_action,
        "history_anchor_ref":anchor_observation,
        "cursor_before":cursor_before.copy(),"cursor_after":cursor_after.copy(),
        "brush_lifted":True,"preserve_material_edits":mechanism != "UNDO_MATERIAL_EDIT",
        "before_world":world(before_obs),"after_world":world(after_obs),
        "native_undo_receipt_ref":("PAINT-native-undo-"+code)
                                     if undo_blob is not None else None,
        "native_undo_receipt_artifact":undo_blob,
        "actual_material_cells_changed":changed,"status":"applied",
        "reason_code":"native_PAINT_history_verified" if undo_blob is not None
                    else "host_owned_branch_anchor_no_native_material_mutation",
    }


def _verify_bundle(root: Path, episode: str, records: list[dict], terminal: dict,
                   guidance_field: dict, artifacts: list[dict],
                   receipts: list[dict], outcome: str, replay: str,
                   metrics: dict) -> dict:
    ident=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD^{tree}"],
                                   text=True,timeout=20).strip()
    world_blob=_blob(root,"native/"+terminal["world_material_path"],"i32le")
    prov={
        "protocol":PROTOCOL,"type":"provenance","record_id":"provenance-001",
        "episode_id":episode,"sequence":len(records),"evidence_class":"native",
        "source_commit":metrics["source_sha"],"source_tree":ident,
        "base_commit":M1_SHA,"interface_schema_sha256":M1_SCHEMA_SHA,
        "experiment_id":episode,"arm":"A1_native_real_history" if "history" in episode
             else "A1_short_sequential_native",
        "split":"pilot","scenario_sha256":digest(SOURCE_SCENARIO),
        "algorithm":{"name":"m3_source_fenced_host_controller","version":"2",
                     "seed":570,"recipe_sha256":digest(SOURCE_SCENARIO)},
        "model":None,"native":world_blob,"native_receipts":receipts,
        "guidance_ref":guidance_field["record_id"],
        "episode_record_refs":[x["record_id"] for x in records],
        "final_world":world(terminal),"outcome":outcome,
        "metrics":{"native_actions":int(metrics["native_actions"]),
                   "native_undos":int(metrics["native_undos"]),
                   "host_branch_relocations":int(metrics["branch_relocations"]),
                   "neural_model_decisions":0},
        "replay":replay,"artifacts":artifacts,
    }
    journal=[*records,prov]
    verified=validate_bundle(journal,evidence_root=root)
    _assert(verified["evidence_bytes_verified"],"Native provenance byte verification absent")
    with (root/"events.jsonl").open("xb") as f:
        for row in journal:
            f.write(canonical(row)+b"\n")
    _dump(root,"bundle-validation.json",verified)
    return verified


def _native_action(session: HistorySession, point: list[int], choice: str) -> dict:
    pre=session.latest_observation
    _assert(pre is not None and _read(session.output.parent, pre,point)==0,
            "Chosen candidate target is not originally Empty")
    return session.apply([_op(point)],expected_generation=pre["generation"],
                         expected_revision=pre["revision"],
                         expected_tick=pre["tick"],action_id=choice,cell_budget=1)


def _history_cycle(root: Path, args) -> dict:
    episode="m3-native-history-branch"
    root.mkdir(parents=True,exist_ok=False)
    rows=[];rects=[];receipt_blobs=[]
    guide=guidance(root,episode);rows.append(guide)
    anchors={}
    with HistorySession(ROOT,args.godot,root/"native",args.source_sha,
                        runtime_manifest=args.runtime_manifest) as native:
        r=native.reset("wall-v1");_check(r,"history reset")
        _assert(r["m3"]["cursor"]==START and r["m3"]["brush_lifted"],"Native host cursor absent")
        a=native.observe();_check(a,"native initial observation")
        initial=a["observation"]
        _assert(_read(root,initial,[12,25])==0 and _read(root,initial,[13,25])==0,
                "Original fixture targets unexpectedly occupied")
        obs1=observation_record(root,initial,episode,1,"obs-001",START,[START])
        rows.append(obs1);rects.append(_blob(root,"native/"+initial["png_path"],"png"))
        legal=digest({"scene":"wall-v1","offers":["DRAW_A","STOP"],
                      "authoritative_native_material":"58","footprint":[12,25]})
        paint_a=_native_action(native,[12,25],"DRAW_A");_check(paint_a,"native paint A")
        after_a=paint_a["observation"]
        move_a=native.cursor_move(START,[12,25]);_check(move_a,"native acknowledged cursor advance A")
        _assert(move_a["m3"]["cursor"]==[12,25],"Host logical cursor A missing")
        saved=native.save_branch("branchA",[12,25]);_check(saved,"native branch anchor")
        _assert(len(saved["m3"]["anchors"])==1,"Native anchor not retained")
        actionA=_record_action(root,episode,2,obs1,initial,after_a,START,[12,25],
                              "DRAW_A",paint_a,legal_sha=legal)
        rows.append(actionA);receipt_blobs.append(actionA["native_receipt_artifact"])
        obs2=observation_record(root,saved["observation"],episode,3,"obs-002",
                                 [12,25],[START,[12,25]],
                                 "action-DRAW_A","native-receipt-DRAW_A")
        rows.append(obs2)
        # A second native Art submission is a distinct PAINT history step.
        legal_b=digest({"scene":"wall-v1","offers":["DRAW_B","STOP"],
                        "footprint":[13,25]})
        paint_b=_native_action(native,[13,25],"DRAW_B");_check(paint_b,"native paint B")
        after_b=paint_b["observation"]
        _assert(_read(root,after_b,[12,25])==58 and _read(root,after_b,[13,25])==58,
                "Both real native paint operations did not persist")
        moved=native.cursor_move([12,25],[13,25]);_check(moved,"native acknowledged cursor advance B")
        _assert(moved["m3"]["cursor"]==[13,25],"Host logical cursor B missing")
        actionB=_record_action(root,episode,4,obs2,saved["observation"],after_b,
                              [12,25],[13,25],"DRAW_B",paint_b,legal_sha=legal_b)
        rows.append(actionB);receipt_blobs.append(actionB["native_receipt_artifact"])
        obs3=observation_record(root,moved["observation"],episode,5,"obs-003",
                                 [13,25],[START,[12,25],[13,25]],
                                 "action-DRAW_B","native-receipt-DRAW_B")
        rows.append(obs3)
        before_relocate=moved["observation"]
        relocated=native.relocate_branch("branchA",[13,25])
        _check(relocated,"real Workbench host branch relocation")
        _assert(relocated["m3"]["cursor"]==[12,25]
                and relocated["m3"]["brush_lifted"] is True
                and relocated["m3"]["cursor_kind"]=="host_logical_no_native_pointer",
                "Native host branch relocation did not identify a logical brush-up event")
        after_relocate=relocated["observation"]
        _assert(after_relocate["world_material_sha256"]==
                before_relocate["world_material_sha256"] and
                after_relocate["material_sha256"]==
                before_relocate["material_sha256"],"Branch relocation modified real native material")
        rel=_record_reversal(episode,6,"BRANCH_A","RELOCATE_TO_BRANCH",
                              "action-DRAW_B","obs-002",
                              before_relocate,after_relocate,[13,25],[12,25])
        rows.append(rel)
        obs4=observation_record(root,after_relocate,episode,7,"obs-004",
                                [12,25],[START,[12,25],[13,25],[12,25]],
                                "action-DRAW_B","native-receipt-DRAW_B")
        rows.append(obs4)
        stale=native.undo(precondition=initial)
        _assert(stale["status"]=="refused" and stale["receipt"]["actual_changed_cells"]==0
                and stale["observation"]["world_material_sha256"]==
                    after_relocate["world_material_sha256"],
                "Stale PAINT Undo was not safely refused")
        undo=native.undo();_check(undo,"real PAINT native Undo")
        undo_event=undo["history_receipt"]
        _assert(undo_event["origin"]=="agent"
                and undo_event["status"]=="completed"
                and undo_event["changed"]==1 and undo_event["recorded"]
                and undo["receipt"]["actual_changed_cells"]==1,
                "Real PAINT undo was not confirmed by native history completion")
        after_undo=undo["observation"]
        _assert(_read(root,after_undo,[12,25])==58
                and _read(root,after_undo,[13,25])==0,
                "Native Undo did not reverse exactly the latest one-cell Art action")
        _assert(after_undo["world_material_sha256"]==
                after_a["world_material_sha256"],
                "Native Undo did not restore exact prior full World bytes")
        undo_blob=_dump(root,"receipts/REAL_PAINT_UNDO.json",
                        {"history_receipt":undo_event,"receipt":undo["receipt"],
                         "status":undo["status"]})
        receipt_blobs.append(undo_blob)
        reversal=_record_reversal(episode,8,"NATIVE_UNDO","UNDO_MATERIAL_EDIT",
                                  "action-DRAW_B","obs-004",
                                  after_relocate,after_undo,[12,25],[12,25],
                                  changed=1,undo_blob=undo_blob)
        rows.append(reversal)
        obs5=observation_record(root,after_undo,episode,9,"obs-005",
                                 [12,25],[START,[12,25],[13,25],[12,25]],
                                 "action-DRAW_B","native-receipt-DRAW_B")
        rows.append(obs5)
        rects.extend(_blob(root,"native/"+v["png_path"],"png")
                     for v in (after_b,after_relocate,after_undo))
        # Ensure cleanup/STOP does not claim to undo edits.
        stopped=native.stop("M3 qualified real Undo/relocation Stop")
        _assert(stopped["status"]=="stopped" and
                stopped["observation"]["world_material_sha256"]==
                    after_undo["world_material_sha256"],
                "Explicit Stop did not preserve final native material")
    cleanup=json.loads((root/"native/cleanup.json").read_text())
    _assert(cleanup["exit_code"]==0,"Original native history process was not reaped cleanly")
    # Independent re-execution of the actual sequence, including real Undo.
    with HistorySession(ROOT,args.godot,root/"replay-native",args.source_sha,
                        runtime_manifest=args.runtime_manifest) as replay:
        _check(replay.reset("wall-v1"),"independent history reset")
        _check(replay.observe(),"independent history observation")
        _check(_native_action(replay,[12,25],"REPLAY_DRAW_A"),"independent replay A")
        _check(_native_action(replay,[13,25],"REPLAY_DRAW_B"),"independent replay B")
        _check(replay.undo(),"independent native PAINT Undo replay")
        read=replay.observe();_check(read,"independent native history final readback")
        _assert(read["observation"]["world_material_sha256"]==
                after_undo["world_material_sha256"],
                "Independent native Undo replay hash differs from original")
        _assert(_read(root,read["observation"],[12,25])==58
                and _read(root,read["observation"],[13,25])==0,
                "Independent Undo replay did not isolate the latest edit")
        _check_status_stop=replay.stop("M3 independent Undo replay Stop")
        _assert(_check_status_stop["status"]=="stopped",
                "Independent native replay Stop refused")
    replay_cleanup=json.loads((root/"replay-native/cleanup.json").read_text())
    _assert(replay_cleanup["exit_code"]==0,"Independent native Undo replay not reaped")
    _dump(root,"replay-result.json",{
        "source_sha":args.source_sha,
        "qualified":"REAL_NATIVE_PAINT_AND_PAINT_HISTORY_UNDO",
        "original_world_sha256":after_undo["world_material_sha256"],
        "replay_world_sha256":read["observation"]["world_material_sha256"],
        "same_full_native_world_material":True,
        "actual_undo_receipt_count":1,
        "process_cleanup_exit_codes":[cleanup["exit_code"],replay_cleanup["exit_code"]],
    })
    check=_verify_bundle(root,episode,rows,after_undo,guide,rects,receipt_blobs,
                         "success","pass",
                         {"source_sha":args.source_sha,"native_actions":2,
                          "native_undos":1,"branch_relocations":1})
    return {"status":"PASS","phase":"real_history_and_branch_relocation",
            "native_actions":2,"native_material_undo":1,"branch_relocations":1,
            "stale_undo_refused":True,"independent_native_replay":True,
            "validated_event_types":check["types"],
            "final_world_sha256":after_undo["world_material_sha256"],
            "native_cleanup":[cleanup["exit_code"],replay_cleanup["exit_code"]]}


def _short_episode(root: Path,args) -> dict:
    """Four bounded host-driven sequential native selections after phase-one PASS."""
    episode="m3-short-four-native-decisions"
    root.mkdir(parents=True,exist_ok=False)
    guide=guidance(root,episode)
    records=[guide]
    receipts=[];pngs=[]
    path=[START.copy()]
    selected=[list(p) for p in SOURCE_SCENARIO["phase2"]["points"]]
    first_anchor_ref=None
    with HistorySession(ROOT,args.godot,root/"native",args.source_sha,
                        runtime_manifest=args.runtime_manifest) as native:
        _check(native.reset("wall-v1"),"short-run reset")
        for index,point in enumerate(selected):
            read=native.observe();_check(read,"short-run fresh observation")
            before=read["observation"]
            _assert(read["m3"]["cursor"]==path[-1],
                    "Short-run host native logical cursor out of synchrony")
            obsid="obs-%02d"%index
            obs=observation_record(root,before,episode,len(records),obsid,
                                    path[-1],path,
                                    ("action-STEP_%02d"%(index-1)) if index>0 else None,
                                    ("native-receipt-STEP_%02d"%(index-1)) if index>0 else None)
            records.append(obs)
            legal_catalog=[
                {"id":"STEP_%02d"%index,"path":[path[-1],point],
                 "swept":[point],"effect":"add_58","cell_budget":1},
                {"id":"STOP","path":[],"swept":[],"effect":"none","cell_budget":0},
            ]
            legal=digest(sorted(legal_catalog,key=lambda v:v["id"]))
            receipt=_native_action(native,point,"STEP_%02d"%index)
            _check(receipt,"short-run native action %d"%index)
            painted=receipt["observation"]
            _assert(_read(root,painted,point)==58,"Short-run native cell was not painted")
            moved=native.cursor_move(path[-1],point)
            _check(moved,"short-run native logical cursor move %d"%index)
            path.append(point)
            action=_record_action(root,episode,len(records),obs,before,painted,
                                   path[-2],point,"STEP_%02d"%index,
                                   receipt,legal_sha=legal)
            records.append(action)
            receipts.append(action["native_receipt_artifact"])
            pngs.append(_blob(root,"native/"+painted["png_path"],"png"))
            if index==0:
                anchor=native.save_branch("short-trunk",point)
                _check(anchor,"short-run initial branch anchor")
                anchor_obs=observation_record(root,anchor["observation"],episode,
                        len(records),"obs-branch-anchor",point,path,
                        "action-STEP_00","native-receipt-STEP_00")
                records.append(anchor_obs)
                first_anchor_ref=anchor_obs["record_id"]
        original_final=native.observe()
        _check(original_final,"short-run fourth fresh observation")
        _assert(all(_read(root,original_final["observation"],pt)==58 for pt in selected),
                "Short-run native four-cell material readback incomplete")
        before_relocate=original_final["observation"]
        change=native.relocate_branch("short-trunk",selected[-1])
        _check(change,"short-run branch relocation")
        after_relocate=change["observation"]
        _assert(change["m3"]["cursor"]==selected[0]
                and after_relocate["world_material_sha256"]==
                    before_relocate["world_material_sha256"],
                "Short-run relocation changed native material or cursor anchor")
        obs_last=observation_record(root,before_relocate,episode,len(records),
                                    "obs-before-recovery",selected[-1],path,
                                    "action-STEP_03","native-receipt-STEP_03")
        records.append(obs_last)
        rev=_record_reversal(episode,len(records),"SHORT_BRANCH",
                              "RELOCATE_TO_BRANCH","action-STEP_03",
                              first_anchor_ref,before_relocate,after_relocate,
                              selected[-1],selected[0])
        records.append(rev)
        before_undo=observation_record(root,after_relocate,episode,len(records),
                                       "obs-before-undo",selected[0],
                                       [*path,selected[0]],"action-STEP_03",
                                       "native-receipt-STEP_03")
        records.append(before_undo)
        undo=native.undo()
        _check(undo,"short-run real Undo after four native decisions")
        after_undo=undo["observation"]
        _assert(_read(root,after_undo,selected[-1])==0 and
                all(_read(root,after_undo,p)==58 for p in selected[:-1]),
                "Short-run Undo failed to reverse only the most recent native edit")
        undo_blob=_dump(root,"receipts/SHORT_UNDO.json",
                        {"status":undo["status"],"history_receipt":undo["history_receipt"],
                         "receipt":undo["receipt"]})
        receipts.append(undo_blob)
        rev_undo=_record_reversal(episode,len(records),"SHORT_UNDO",
                                  "UNDO_MATERIAL_EDIT","action-STEP_03",
                                  "obs-before-undo",after_relocate,after_undo,
                                  selected[0],selected[0],changed=1,undo_blob=undo_blob)
        records.append(rev_undo)
        obs_terminal=observation_record(root,after_undo,episode,len(records),
                                         "obs-terminal",selected[0],[*path,selected[0]],
                                         "action-STEP_03","native-receipt-STEP_03")
        records.append(obs_terminal)
        pngs.extend(_blob(root,"native/"+o["png_path"],"png")
                    for o in (before_relocate,after_undo))
        stop=native.stop("M3 short four native decisions finished")
        _assert(stop["status"]=="stopped","Short-run host STOP failed")
    cleanup=json.loads((root/"native/cleanup.json").read_text())
    _assert(cleanup["exit_code"]==0,"Short-run native process not reaped")
    validated=_verify_bundle(root,episode,records,after_undo,guide,pngs,receipts,
                             "success","not_attempted",
                             {"source_sha":args.source_sha,"native_actions":4,
                              "native_undos":1,"branch_relocations":1})
    return {"status":"PASS","phase":"short_four_sequential_native_decisions",
            "native_actions":4,"native_undos":1,"branch_relocations":1,
            "fresh_observation_per_decision":True,
            "neural_model_decisions":0,"final_world_sha256":after_undo["world_material_sha256"],
            "native_process_exit_code":cleanup["exit_code"],
            "event_type_checks":validated["types"]}


def qualify(args) -> dict:
    root=args.output.resolve()
    _assert(not root.exists(),"M3 history evidence path already exists")
    _assert(len(args.source_sha)==40,"Source SHA must be full immutable identity")
    head=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],
                                  text=True,timeout=20).strip()
    _assert(head==args.source_sha,"M3 history source mismatch")
    subprocess.run(["git","-C",str(ROOT),"merge-base","--is-ancestor",M1_SHA,"HEAD"],
                   check=True,timeout=20)
    _assert(hashlib.sha256(SCHEMA.read_bytes()).hexdigest()==M1_SCHEMA_SHA,
            "M1 accepted schema changed")
    root.mkdir(parents=True)
    started=time.monotonic()
    try:
        history=_history_cycle(root/"phase1-history",args)
        _assert(history["status"]=="PASS" and history["independent_native_replay"],
                "M3 native history phase failed; refuse short expansion")
        short=_short_episode(root/"phase2-short",args)
        _assert(short["status"]=="PASS", "M3 short native episode failed")
        report={
            "schema":"driv3r-m3-history-short-v1",
            "source_sha":args.source_sha,"frozen_m1_sha":M1_SHA,
            "m1_schema_sha256":M1_SCHEMA_SHA,
            "status":"PASS","phase1":history,"phase2":short,
            "real_native_material_undo_qualified":True,
            "native_branch_relocation_qualified_as":"HOST_LOGICAL_CURSOR_ONLY",
            "native_physical_pointer_relocation_qualified":False,
            "short_sequential_real_native_decisions":4,
            "neural_model_decisions":0,"a1_a2_a3_comparative_models_qualified":False,
            "native_world_dimensions":[512,512],
            "total_actual_forward_native_edits":8,
            "total_actual_native_undo_operations":3,
            "native_session_count":3,
            "replay_count":1,
            "elapsed_seconds":round(time.monotonic()-started,3),
            "not_qualified":["d1_2b_short_model_selections","36_decision_episodes",
                             "A1_A2_A3_model_campaigns","native_cursor_teleport",
                             "arbitrary_World_dimensions","graphical_multimodal_feedback"],
        }
        _dump(root,"summary.json",report)
        print(json.dumps({"m3_history_status":"PASS","source_sha":args.source_sha,
                          "real_native_undo":True,"branch_relocation":"logical_brush_up_only",
                          "short_native_decisions":4,"model_decisions":0},sort_keys=True),flush=True)
        return report
    except BaseException as exc:
        record={"schema":"driv3r-m3-history-short-failed-v1","source_sha":args.source_sha,
                "status":"FAILED","type":type(exc).__name__,"message":str(exc),
                "traceback":traceback.format_exc(),
                "elapsed_seconds":round(time.monotonic()-started,3)}
        _dump(root,"failure.json",record)
        print(json.dumps({"m3_history_status":"FAIL","type":record["type"],
                          "message":record["message"]},sort_keys=True),flush=True)
        raise


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",type=Path,required=True)
    parser.add_argument("--runtime-manifest",type=Path,required=True)
    parser.add_argument("--source-sha",required=True)
    parser.add_argument("--output",type=Path,required=True)
    qualify(parser.parse_args())


if __name__=="__main__":
    main()
