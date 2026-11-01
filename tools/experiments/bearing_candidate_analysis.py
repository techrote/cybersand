"""Registered causal metrics/gates. No candidate search or parameter selection."""
from __future__ import annotations
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import statistics

from granular_bearing_analysis import motion_budget, neutral

def read(path):return json.loads(Path(path).read_text(encoding="utf-8"))
def percentile(values,p):
    data=sorted(values);return data[min(len(data)-1,math.ceil(p*len(data))-1)] if data else None
def longest(flags):
    best=current=0
    for flag in flags:
        current=current+1 if flag else 0;best=max(best,current)
    return best
def ratio_reduction(base,value):return (base-value)/base if base>0 else 0.0

def describe(directory):
    directory=Path(directory);receipt=read(directory/"receipt.json");acq=read(directory/"acquisition.json")
    for name,expected in receipt.get("artifact_sha256",{}).items():
        if hashlib.sha256((directory/name).read_bytes()).hexdigest()!=expected:
            raise ValueError("frozen acquisition artifact changed: "+name)
    pop=read(directory/"population-manifest.json");trajectory=read(directory/"trajectory.json")
    if not receipt.get("ok") or receipt["replay_matches"]!=pop["attempts"] or not acq["complete"]:
        raise ValueError("qualified replay/capture required")
    for part in pop["parts"]:
        if hashlib.sha256((directory/part["path"]).read_bytes()).hexdigest()!=part["sha256"]:
            raise ValueError("replayed part changed")
    frames=trajectory["frames"]
    if len(frames)!=600 or [f["tick"] for f in frames]!=list(range(600)) or not trajectory["details"]:
        raise ValueError("complete detailed600frame trace required")
    mode=acq["candidate"];events=pop["events"]
    failures=[e for e in events if e["target"][0]<0]
    first=lambda predicate:next((f for f in frames if predicate(f)),None)
    support=first(lambda f:f["candidate_metrics"]["selected_support"]>0)
    current=first(lambda f:f["candidate_metrics"]["current_support"]>0)
    overlap=first(lambda f:f["geometry"]["pre_overlap"]>0)
    crossing=first(lambda f:support is not None and f["tick"]>=support["tick"] and f["body_input"][7]<=0)
    arrest=first(lambda f:support is not None and f["tick"]>=support["tick"] and f["after_application"][4]<=0)
    correction=first(lambda f:any(f["application_details"][0]["applied_correction"]))
    end=crossing["tick"] if crossing else 599
    entry=[f for f in frames if support and support["tick"]<=f["tick"]<=end]
    budgets=[motion_budget(f) for f in frames]
    if max(b["impulse_error"] for b in budgets)>2e-5 or max(b["pose_error"] for b in budgets)>2e-5:
        raise ValueError("API boundary accounting failed")
    limiters=Counter();per_frame=[];hover=[];lift=[];unknown_gap_frames=[]
    expected_counts=frames[0]["stored_counts"];expected_mass=frames[0]["stored_water_mass"]
    for i,f in enumerate(frames):
        w=f["candidate_metrics"];b=f["bearing"];vy=f["body_input"][7]
        if f["candidate"]!=mode or w["candidate"]!=mode or b["candidate"]!=mode:
            raise ValueError("mutable/mixed candidate")
        if f["body_input"][10]!=i+1 or f["requested_results"][8]!=i+1 or f["completed_tick"]!=i+1:
            raise ValueError("sample/step/response identity drift")
        if b["probe_drops"] or w["invalid_geometry"] or w["maximum_ray_cells"]>3 or w["extra_cells"]>2*w["boundaries"]:
            raise ValueError("ray work/capacity failure")
        if not 0<=w["lookahead"]<=2 or w["maximum_hit_distance"]>w["lookahead"]:
            raise ValueError("lookahead exceeded bound")
        if w["selected_support"]!=w["current_support"]+w["predicted_only"] or b["raw_support"]!=w["selected_support"]:
            raise ValueError("support set accounting")
        if mode!="A2" and (w["extra_cells"] or w["predicted_only"]):raise ValueError("nonA2 changed admission")
        if mode=="A2" and vy<=0 and (w["lookahead"] or w["extra_cells"]):raise ValueError("rising lookahead")
        coefficient=1.0 if mode=="Y1" else .18
        yielding=92/60+max(0,vy-92/60)*coefficient
        capacity=min(20,w["selected_support"]*2)
        magnitude=min(vy,yielding,capacity) if vy>0 and w["selected_support"] else 0
        if abs(b["bearing_y"]+magnitude)>2e-5:raise ValueError("formula isolation failure")
        chosen=[]
        if magnitude>0:
            chosen=[name for name,value in (("arrest",vy),("yield",yielding),("capacity",capacity)) if math.isclose(value,magnitude,abs_tol=1e-9,rel_tol=1e-10)]
            limiters["+".join(chosen)]+=1
        per_frame.append({"tick":i,"limiters":chosen,"current":w["current_support"],"selected":w["selected_support"],
                          "predicted_only":w["predicted_only"],"lookahead":w["lookahead"],"bearing_y":b["bearing_y"]})
        gaps=[];admitted=0
        for ray in b["admissions"]:
            steps=ray["steps"]
            if not 0<=ray["length"]<=2 or not 1<=len(steps)<=3:raise ValueError("malformed ray")
            for j,s in enumerate(steps):
                if not 0<=s[2]<=ray["length"]:raise ValueError("ray crossing beyond segment")
                if j and abs(ray["q"]+s[2]-s[1])>1e-9:raise ValueError("not exact grid crossing")
                if j<len(steps)-1 and (not s[3] or s[4] or s[5] or s[6]):raise ValueError("passed barrier/earlier hit")
            if ray["selected"]>=0:
                admitted+=1
                hit=steps[ray["selected"]]
                if not hit[6] or not hit[3] or hit[4] or hit[5]:raise ValueError("illegal admitted support")
                physical_lower=ray["geometric_lower"]
                if physical_lower is not None:gaps.append(hit[1]-physical_lower)
        if w["current_support"]==0 and w["selected_support"]>0 and admitted!=len(gaps):
            unknown_gap_frames.append(i)
            raise ValueError("predicted-only support has unmeasured physical gap; hover safety unqualified")
        hover.append(w["current_support"]==0 and w["selected_support"]>0 and bool(gaps)
                     and min(gaps)>.5 and abs(f["after_application"][4])<=1)
        if i:
            lift.append(vy<0 and frames[i-1]["body_input"][7]<0 and w["current_support"]==0
                        and f["after_application"][4]<f["after_step"][4]-.05)
        else:lift.append(False)
        if not w["selected_support"] and (b["bearing_y"] or f["requested_results"][4]):
            raise ValueError("bearing/correction retained without selected support")
        if i==300 and acq["fixture"]["name"]=="excavation":
            expected_counts=acq["excavation"]["after_counts"];expected_mass=acq["excavation"]["after_water"]
        if f["stored_water_mass"]!=expected_mass or f["pre_water_mass"]!=expected_mass or f["post_water_mass"]!=expected_mass:
            raise ValueError("quantity conservation failure")
        if acq["fixture"]["name"]!="water" and f["stored_counts"]!=expected_counts:
            raise ValueError("material conservation failure")
    tail=frames[300:];ys=[f["after_application"][1] for f in tail];vs=[abs(f["after_application"][4]) for f in tail]
    center=(min(ys)+max(ys))/2;last=0;crossings=0
    for y in ys:
        sign=1 if y>center+.5 else -1 if y<center-.5 else 0
        if sign and last and sign!=last:crossings+=1
        if sign:last=sign
    def landmark(f):
        if f is None:return None
        return {"tick":f["tick"],"vy":f["body_input"][7],"entry":f["geometry"]["initial_surface_entry"],
                "pre_overlap":f["geometry"]["pre_overlap"],"center_y":f["after_step"][1]}
    failure=min(failures,key=lambda e:e["event_ordinal"]) if failures else None
    first_failure=landmark(frames[failure["tick"]]) if failure else None
    if first_failure:first_failure.update({"source":failure["source"],"normal":failure["normal"],"penetration":failure["penetration"]})
    result={"candidate":mode,"arm":acq["fixture"]["name"],"source":receipt["source"],"runtime":receipt["runtime"],
            "attempts":pop["attempts"],"no_target":pop["no_target"],"success":pop["success"],
            "descent_no_target":sum(e["current_body"][7]>0 for e in failures),
            "rising_no_target":sum(e["current_body"][7]<=0 for e in failures),
            "maximum_entry":max(f["geometry"]["initial_surface_entry"] for f in frames),
            "maximum_pre_overlap":max(f["geometry"]["pre_overlap"] for f in frames),
            "maximum_post_overlap":max(f["geometry"]["post_ejection_overlap"] for f in frames),
            "first_support":landmark(support),"first_current_support":landmark(current),"first_overlap":landmark(overlap),
            "first_no_target":first_failure,"first_nonpositive_post_step":landmark(crossing),"first_arrest_post_application":landmark(arrest),
            "first_correction":({**landmark(correction),"requested":correction["application_details"][0]["requested_correction"],
                                 "applied":correction["application_details"][0]["applied_correction"]} if correction else None),
            "support_to_arrest_samples":crossing["tick"]-support["tick"] if crossing and support else None,
            "support_to_arrest_descent":sum(max(f["after_step"][1]-f["before_step"][1],0) for f in frames[support["tick"]+1:crossing["tick"]+1]) if crossing and support else None,
            "common_start_stopping_distance":sum(max(f["after_step"][1]-f["before_step"][1],0) for f in frames[:arrest["tick"]+1]) if arrest else None,
            "entry_accepted_net_y":sum(f["bridge_application"][2] for f in entry),
            "entry_nominal_bearing_y":sum(f["bearing"]["bearing_y"] for f in entry),
            "entry_correction_dp_y":sum(budgets[f["tick"]]["correction_dp"][1] for f in entry),
            "peak_upward_rebound":max([max(-f["after_step"][4],-f["after_application"][4],0) for f in frames[arrest["tick"]:]] or [0]) if arrest else 0,
            "bearing_limiters":dict(limiters),"per_frame_selection":per_frame,
            "predicted_only_frames":sum(f["candidate_metrics"]["predicted_only"]>0 for f in frames),
            "maximum_lookahead":max(f["candidate_metrics"]["lookahead"] for f in frames),
            "maximum_additional_probes":max(f["candidate_metrics"]["extra_cells"] for f in frames),
            "maximum_ray_cells":max(f["candidate_metrics"]["maximum_ray_cells"] for f in frames),
            "callback_us":{"p50":statistics.median(f["coupling_usec"] for f in frames),"p95":percentile([f["coupling_usec"] for f in frames],.95),"max":max(f["coupling_usec"] for f in frames)},
            "settled":{"span":max(ys)-min(ys),"net_drift":ys[-1]-ys[0],"p95_abs_vy":percentile(vs,.95),"max_abs_vy":max(vs),
                       "overlap_sum":sum(f["geometry"]["post_tick_overlap_at_packed_pose"] for f in tail),
                       "overlap_frames":sum(f["geometry"]["post_tick_overlap_at_packed_pose"]>0 for f in tail),
                       "overlap_max":max(f["geometry"]["post_tick_overlap_at_packed_pose"] for f in tail),"large_cycles":crossings//2},
            "longest_hover":longest(hover),"longest_artificial_lift":longest(lift),
            "unknown_predicted_support_gap_frames":unknown_gap_frames,
            "max_impulse_error":max(b["impulse_error"] for b in budgets),"max_correction_error":max(b["pose_error"] for b in budgets),
            "conservation_failures":0,"stream_drops":0}
    return result

def efficacy(base,candidate):
    overlap=ratio_reduction(base["maximum_pre_overlap"],candidate["maximum_pre_overlap"])
    entry=ratio_reduction(base["maximum_entry"],candidate["maximum_entry"])
    descent=ratio_reduction(base["descent_no_target"],candidate["descent_no_target"])
    bstop,cstop=base["common_start_stopping_distance"],candidate["common_start_stopping_distance"]
    stop_abs=bstop-cstop if bstop is not None and cstop is not None else None
    stop_frac=ratio_reduction(bstop,cstop) if stop_abs is not None else None
    bfail,cfail=base["first_no_target"],candidate["first_no_target"]
    prevention=bfail is not None and cfail is None
    delay=cfail["tick"]-bfail["tick"] if bfail and cfail else None
    corroboration=descent>=.25 or prevention or (delay is not None and delay>=1) or (stop_abs is not None and stop_abs>=.5 and stop_frac>=.20)
    return {"overlap_absolute":base["maximum_pre_overlap"]-candidate["maximum_pre_overlap"],"overlap_reduction":overlap,
            "entry_absolute":base["maximum_entry"]-candidate["maximum_entry"],"entry_reduction":entry,
            "descent_absolute":base["descent_no_target"]-candidate["descent_no_target"],"descent_reduction":descent,
            "stopping_absolute":stop_abs,"stopping_reduction":stop_frac,"first_failure_delay":delay,"failure_prevented":prevention,
            "corroboration":corroboration,"required":overlap>=.25 and entry>=.20,
            "pass":overlap>=.25 and entry>=.20 and corroboration,
            "material_effect":overlap>=.25 or entry>=.20 or prevention or (delay is not None and delay>=1) or (stop_abs is not None and stop_abs>=.5 and stop_frac>=.20)}

def settling(base,candidate):
    b,c=base["settled"],candidate["settled"]
    gates={"rebound":not(candidate["peak_upward_rebound"]>1.25*base["peak_upward_rebound"] and candidate["peak_upward_rebound"]-base["peak_upward_rebound"]>2),
           "settled_span":c["span"]<=1,"settled_drift":abs(c["net_drift"])<=.5,"settled_p95":c["p95_abs_vy"]<=4,"settled_max":c["max_abs_vy"]<=8,
           "persistent_overlap":all(c[k]<=b[k] for k in ("overlap_sum","overlap_frames","overlap_max")),
           "hover":candidate["longest_hover"]<30,"lift":candidate["longest_artificial_lift"]<3 or candidate["longest_artificial_lift"]<=base["longest_artificial_lift"],
           "oscillation":not(c["large_cycles"]>=3 and c["span"]>1 and b["large_cycles"]<3)}
    return {"pass":all(gates.values()),"gates":gates}

def excavation(directory):
    frames=read(Path(directory)/"trajectory.json")["frames"];before=frames[240:300];after=frames[300:]
    ys=[f["after_application"][1] for f in before]
    precondition=max(ys)-min(ys)<=1 and any(f["candidate_metrics"]["selected_support"]>0 for f in before)
    zero=all(f["candidate_metrics"]["selected_support"]==0 and f["candidate_metrics"]["current_support"]==0 and f["bearing"]["bearing_y"]==0 and f["requested_results"][4]==0 for f in after)
    residual=max(abs(v) for f in after[:20] for v in motion_budget(f)["backend_model_residual_dv"])
    no_contacts=not any(f["backend"]["contacts"] for f in after[:20])
    descent=frames[319]["after_application"][1]-frames[300]["before_step"][1]
    fall=frames[319]["after_application"][4]>0 and descent>=1
    return {"pass":precondition and zero and residual<=1e-4 and no_contacts and fall,"precondition":precondition,
            "support_retired":zero,"first20_freeflight_error":residual,"first20_no_contacts":no_contacts,
            "descent_by319":descent,"fall_resumes":fall}

def negative(base_dir,candidate_dir):
    a,b=read(Path(base_dir)/"trajectory.json"),read(Path(candidate_dir)/"trajectory.json")
    zero=all(f["candidate_metrics"]["selected_support"]==0 and f["bearing"]["bearing_y"]==0 and f["requested_results"][4]==0 for f in b["frames"])
    equal=neutral(a,b)
    quantity=all(x["stored_water_mass"]==y["stored_water_mass"] for x,y in zip(a["frames"],b["frames"]))
    return {"pass":zero and equal and quantity,"zero_granular":zero,"exact_physical_equivalence":equal,"exact_quantity_equivalence":quantity}

def state(comparisons,safety,mechanism):
    if not safety:return "N"
    if all(c["pass"] for c in comparisons) and mechanism:return "H"
    if any(c["material_effect"] for c in comparisons) and mechanism:return "P"
    return "N"

def disposition(y,a):
    if "P" in (y,a):return "partial/mechanistic result only"
    return {("H","H"):"Y1 HIGH-VALUE / A2 HIGH-VALUE — separate combination experiment warranted",
            ("H","N"):"Y1 HIGH-VALUE / A2 NO-GO",("N","H"):"A2 HIGH-VALUE / Y1 NO-GO",("N","N"):"both NO-GO"}[(y,a)]

def mechanism(base_dir,candidate_dir):
    b=read(Path(base_dir)/"trajectory.json")["frames"];c=read(Path(candidate_dir)/"trajectory.json")["frames"]
    first=next((i for i in range(600) if b[i]["requested_results"][1:5]!=c[i]["requested_results"][1:5]),None)
    if first is None:return {"verified":False,"first_changed_packet":None}
    same=all(b[i]["body_input"]==c[i]["body_input"] and b[i]["physical_hash"]==c[i]["physical_hash"] for i in range(first+1))
    mode=c[first]["candidate"];w=c[first]["candidate_metrics"]
    intended=(w["current_support"]==b[first]["candidate_metrics"]["current_support"] and
              c[first]["bearing"]["bearing_y"]<b[first]["bearing"]["bearing_y"])
    if mode=="A2":intended=intended and w["predicted_only"]>0 and 0<w["maximum_hit_distance"]<=w["lookahead"]<=2
    return {"verified":same and intended,"first_changed_packet":first,"prefix_input_and_cell_states_equal":same,
            "baseline_bearing":b[first]["bearing"]["bearing_y"],"candidate_bearing":c[first]["bearing"]["bearing_y"],
            "current_support":w["current_support"],"selected_support":w["selected_support"],"lookahead":w["lookahead"]}

def campaign(root):
    root=Path(root)
    summaries={mode:{arm:describe(root/(mode+"-"+arm+"-on")) for arm in ("speed0","speed30","speed90","excavation","hard","water")}
               for mode in ("B0","Y1","A2")}
    identities={(s["source"],json.dumps(s["runtime"],sort_keys=True)) for group in summaries.values() for s in group.values()}
    if len(identities)!=1:raise ValueError("comparisons require exact common source/runtime")
    result={"schema":1,"summaries":summaries,"candidates":{}}
    for mode in ("Y1","A2"):
        comparisons={arm:efficacy(summaries["B0"][arm],summaries[mode][arm]) for arm in ("speed30","speed90")}
        mechanisms={arm:mechanism(root/("B0-"+arm+"-on"),root/(mode+"-"+arm+"-on")) for arm in comparisons}
        controls={"speed0":settling(summaries["B0"]["speed0"],summaries[mode]["speed0"]),
                  "excavation":excavation(root/(mode+"-excavation-on")),
                  "hard":negative(root/"B0-hard-on",root/(mode+"-hard-on")),
                  "water":negative(root/"B0-water-on",root/(mode+"-water-on"))}
        safety=all(c["pass"] for c in controls.values())
        verified=any(m["verified"] for m in mechanisms.values())
        if any(c["material_effect"] and not mechanisms[arm]["verified"] for arm,c in comparisons.items()):
            raise ValueError("observed effect lacks registered causal mechanism")
        classification=state(list(comparisons.values()),safety,verified)
        result["candidates"][mode]={"comparisons":comparisons,"mechanisms":mechanisms,"controls":controls,"state":classification}
    result["disposition"]=disposition(result["candidates"]["Y1"]["state"],result["candidates"]["A2"]["state"])
    result["baseline_excavation"]=excavation(root/"B0-excavation-on")
    if not result["baseline_excavation"]["pass"]:raise ValueError("baseline excavation precondition/release control failed")
    return result

if __name__=="__main__":
    import argparse
    from ejection_a2 import write_json
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--input",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args()
    if args.output.resolve().is_relative_to(args.input.resolve()):p.error("output must not overwrite input corpus")
    result=campaign(args.input);write_json(args.output,result)
    print(json.dumps({mode:{"state":value["state"],"comparisons":value["comparisons"],"controls":value["controls"]} for mode,value in result["candidates"].items()},indent=2))
    print(result["disposition"])
