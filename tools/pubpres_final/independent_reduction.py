#!/usr/bin/env python3
"""Independently audit genuine steps and recompute timing from retained traces.

Only the Python standard library is imported. No campaign-produced metric or
shared quantile/reducer helper is used to calculate these results. This bounded
audit supplements, and does not replace, full source/GPU/Water qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def summary(values):
    ordered = sorted(float(value) for value in values)
    if not ordered:
        return None
    require(all(math.isfinite(value) for value in ordered), "Nonfinite observed duration")
    result = {"count":len(ordered),"mean":math.fsum(ordered)/len(ordered),"max":ordered[-1]}
    for percentile in (50,95,99):
        position = (len(ordered)-1)*percentile/100
        lower = int(position)
        upper = min(lower+1,len(ordered)-1)
        result["p"+str(percentile)] = ordered[lower]+(ordered[upper]-ordered[lower])*(position-lower)
    return result


def witnessed_steps(data, rows):
    start,end = data["capture_start_usec"],data["capture_end_usec"]
    steps = sorted((row for row in rows if row.get("event")=="rapier_step"),key=lambda row:row["step"])
    require(steps and all(start<=row["time_usec"]<=end for row in steps), "No in-capture genuine step observations")
    require(steps[0]["step"]==data["capture_physical_tick_start"]+1, "Initial step does not follow observed capture state")
    require(all(right["step"]-left["step"]==right["manual_steps"]-left["manual_steps"]
                ==right["native_tick_used"]-left["native_tick_used"]==1
                and right["time_usec"]>=left["time_usec"]
                for left,right in zip(steps,steps[1:])), "Steps or native prerequisites were skipped/reused/reordered")
    callbacks = {row["callback_id"]:row for row in rows if row.get("event")=="physics_callback"}
    require(len(callbacks)==sum(row.get("event")=="physics_callback" for row in rows), "Duplicate real callback ID")
    native = {(row["world_generation"],row["tick_index"],row["body_sample"]):row
              for row in rows if row.get("event")=="native_completion_observed"}
    expected = [{"slot":body["body_slot"],"body_rid":body["body_rid"]}
                for actor in data["actor_roster_before"] for body in actor["bodies"]]
    require(data["actor_roster_before"]==data["actor_roster_after"] and expected
            and len({row["body_rid"] for row in expected})==len(expected), "Actual actor/body owners changed or alias")
    used, owners, bootstrap = set(),set(),0
    for index,row in enumerate(steps):
        require(row["body_ownership"]==expected and len(row["bodies"])==len(expected), "Step has a different body owner or missing pose")
        require(row["pending_hard_chunks"]==0 and row["required_hard_revision"]==row["packet_hard_revision"]
                ==row["installed_hard_revision"], "Step used invalid or incomplete native terrain")
        require(row["packet_failed"] is False and row["response_refusal"]=="" and abs(row["fixed_delta"]-1/60)<=1e-12,
                "Physical authority or fixed delta differs")
        owners.add((row["world_generation"],row["session"],row["epoch"]))
        origin=row["origin_callback_id"]
        require(origin not in used and origin in callbacks, "Step invents or reuses callback credit")
        used.add(origin);callback=callbacks[origin]
        require(row["origin_callback_start_usec"]==callback["start_usec"]
                and row["origin_process_frame"]==callback["process_frame"]
                and row["origin_physics_frame"]==callback["physics_frame"]
                and row["step"]==callback["before_step"]+1, "Step's scheduled callback identity differs")
        if row["execution_kind"]=="physics_callback":
            require(callback["after_step"]==row["step"] and row["start_usec"]==callback["start_usec"]
                    and row["time_usec"]<=callback["time_usec"], "Callback does not witness its completed step")
        else:
            attempts=[attempt for attempt in rows if attempt.get("event")=="physics_continuation"
                      and attempt.get("origin_callback_id")==origin and attempt.get("advanced") is True
                      and attempt["after_step"]==row["step"] and attempt["start_usec"]<=row["time_usec"]<=attempt["time_usec"]]
            require(row["execution_kind"]=="physics_continuation" and len(attempts)==1
                    and callback["after_step"]==callback["before_step"], "No independently observed deferred completion")
        initial=index==0 and row["completed_body_sample"]==-1 and row["native_tick_used"]==data["capture_native_tick_start"]
        if initial:
            require(row["response_accepted"] is False and row["accepted_samples"]==[-1]*len(expected), "Unregistered initial sample credit")
            bootstrap+=1
        else:
            key=(row["world_generation"],row["native_tick_used"],row["completed_body_sample"])
            require(row["response_accepted"] is True and row["accepted_samples"]==[row["completed_body_sample"]]*len(expected)
                    and key in native and native[key]["time_usec"]<=row["time_usec"], "Step lacks its actual accepted native body response")
    require(len(owners)==1, "Physical native World/session/epoch changed")
    return steps,{"actual_completed_steps":len(steps),"unique_callback_credits":len(used),
                  "actual_owned_bodies":len(expected),"initial_pre_capture_sample_steps":bootstrap,
                  "native_response_steps":len(steps)-bootstrap,"terrain_and_owner_fences":True}


def measure(data, rows, steps, end):
    start=data["capture_start_usec"]
    selected=[row for row in steps if row["time_usec"]<=end]
    gaps=[(right["time_usec"]-left["time_usec"])/1000 for left,right in zip(selected,selected[1:])]
    commands={}
    for row in sorted((row for row in rows if row.get("event")=="command_attempt"),key=lambda row:row["time_usec"]):
        commands.setdefault(row["absolute_tick"],[]).append(row)
    first,consumed=[],[]
    for row in selected:
        admissions=[command for command in commands.get(row["step"]-1,[]) if command["time_usec"]<=row["time_usec"]]
        require(admissions and admissions[-1]["accepted"] is True
                and admissions[-1]["sequence_after"]==row["command_sequence"]
                and admissions[-1]["deadline_tick"]==row["command_deadline_tick"]
                and admissions[-1]["accepted_move"]==row["admitted_move"], "Actual action/lease differs from consumed command")
        first.append((row["time_usec"]-admissions[0]["time_usec"])/1000)
        consumed.append((row["time_usec"]-admissions[-1]["time_usec"])/1000)
    inside=[row for row in rows if start<=row.get("time_usec",-1)<=end]
    uploads=[row for row in inside if row["event"]=="texture_upload"]
    draws=sorted((row for row in inside if row["event"]=="framebuffer_draw"),key=lambda row:row["time_usec"])
    span=math.fsum(gaps)
    burden={str(limit):{"count":sum(value>limit for value in gaps),
                        "count_per_capture_minute":sum(value>limit for value in gaps)*60e6/(end-start),
                        "inter_step_span_ms_in_long_gaps":math.fsum(value for value in gaps if value>limit),
                        "share_of_observed_inter_step_span":math.fsum(value for value in gaps if value>limit)/span if span else None,
                        "summed_excess_above_threshold_ms":math.fsum(max(0,value-limit) for value in gaps)}
            for limit in (100,250,500,1000)}
    return {"duration_seconds":(end-start)/1e6,"completed_rapier_steps":len(selected),
            "rapier_steps_per_second":len(selected)*1e6/(end-start),"physical_gap_ms":summary(gaps),
            "gaps_above_ms":{str(limit):sum(value>limit for value in gaps) for limit in (100,250,500,1000)},
            "absolute_tail_burden":burden,"observed_inter_step_span_ms":span,
            "tail_burden_scope":"Existing reporting thresholds only, not owner acceptance budgets. Gap spans exclude capture edges before first and after last observed completion; rate normalization uses the full capture window.",
            "first_command_admission_to_completion_ms":summary(first),
            "latest_consumed_command_to_completion_ms":summary(consumed),
            "native_completion_clock_to_physical_ms":summary((row["time_usec"]-row["native_completed_usec"])/1000
                for row in selected if row.get("native_completed_usec") is not None and row["native_completed_usec"]>0),
            "solver_elapsed_ms":summary(row["solver_usec"]/1000 for row in selected),
            "upload_submit_call_ms":summary((row["time_usec"]-row["start_usec"])/1000 for row in uploads),
            "delivered_draw_gap_ms":summary((right["time_usec"]-left["time_usec"])/1000 for left,right in zip(draws,draws[1:]))}


def reduce(path):
    path=Path(path);data=json.loads(path.read_bytes())
    trace=path.with_name(path.stem+"-events.jsonl")
    require(sha(trace)==data["trace_sha256"], "Original trace differs from receipt checksum")
    rows=[json.loads(line) for line in trace.read_text(encoding="utf-8").splitlines()]
    require(rows[0]["event"]=="identity" and rows[0]["source"]==data["source_identity"], "Trace and receipt identity differ")
    rows=rows[1:]
    require(data["observer_mode"]=="full", "This independent audit requires complete native/physics channels")
    steps,witness=witnessed_steps(data,rows)
    windows={"whole_capture":measure(data,rows,steps,data["capture_end_usec"])}
    if len(steps)>=144:
        windows["first_144_steps"]=measure(data,rows,steps,steps[143]["time_usec"])
    body_hash=hashlib.sha256(json.dumps([row["bodies"] for row in steps[:144]],sort_keys=True,separators=(",", ":")).encode()).hexdigest()
    return {"receipt":str(path),"receipt_sha256":sha(path),"trace_sha256":sha(trace),
            "capture_claims_complete":data["complete"],"capture_failures":data["failures"],
            "source_identity":data["source_identity"],"fixture":data["fixture"],"water_profile":data["water_profile"],
            "renderer":data["renderer"],"render_thread":data["render_thread"],"adapter":data["adapter"],
            "cpu":data["cpu"],"selectors_before":data["selectors_before"],"selectors_after":data["selectors_after"],
            "physical_witness":witness,"windows":windows,"first_144_body_trajectory_sha256":body_hash}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",type=Path,action="append",required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    require(not args.output.exists(), "Preserve the original independent reduction")
    paths=sorted({path for root in args.input for path in ([root] if root.is_file() else root.rglob("receipt.json"))})
    report={"schema":"pubpres-final-independent-reduction-v1","program_sha256":sha(__file__),
            "receipts":[],"failures":[],"physical_acceptance":"HOLD",
            "scope":"Independent stdlib recomputation of recorded genuine-step, callback, native response, terrain, body and command witnesses. It does not replace complete source/Water/GPU qualification. Draws are Main-delivered notifications, uploads are CPU submission calls, and input clocks begin at application admission."}
    for path in paths:
        try:
            report["receipts"].append(reduce(path))
        except (ValueError,KeyError,TypeError,OSError) as error:
            report["failures"].append({"receipt":str(path),"reason":str(error)})
    require(paths, "No retained receipts found")
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"receipts":len(report["receipts"]),"failures":report["failures"],"output":str(args.output)}))
    return int(bool(report["failures"]))


if __name__=="__main__":
    raise SystemExit(main())
