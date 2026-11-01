"""Read-only reduction of registered fixed-law granular entry measurements."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

from ejection_a2 import write_json


def first(frames, predicate):
    return next((f for f in frames if predicate(f)), None)


def motion_budget(frame, mass=1.0):
    """API-call boundaries; correction assignment is not an impulse."""
    details = frame["application_details"]
    if len(details) != 1:
        raise ValueError("expected one accepted synchronous body application")
    detail = details[0]
    before, corrected, after = detail["before"], detail["after_correction"], detail["after_impulse"]
    requested = frame["requested_results"]
    accepted = frame["bridge_application"][1:3]
    if detail["age"] != 0 or frame["bridge_application"][3:6] != [0, 0, 1]:
        raise ValueError("freshness/duplicate gate differs from registered synchronous arm")
    if max(abs(before[i]-frame["after_step"][i]) for i in range(6)) > 1e-5:
        raise ValueError("application starts at a different motion boundary")
    correction_dp = [mass*(corrected[i+3]-before[i+3]) for i in range(2)]
    impulse_dp = [mass*(after[i+3]-corrected[i+3]) for i in range(2)]
    impulse_error = max(abs(impulse_dp[i]-accepted[i]) for i in range(2))
    pose_error = max(abs((corrected[i]-before[i])-detail["applied_correction"][i]) for i in range(2))
    # Rapier's damping integration is explicitly a modelled residual, not an
    # inferred force/contact impulse. Preserve measured contact buffers apart.
    backend = frame["backend"]
    gravity_dp = [mass*v*backend["step"] for v in backend["gravity"]]
    damping = backend["linear_damp"]
    predicted = [(frame["before_step"][i+3]+backend["gravity"][i]*backend["step"])/
                 (1+damping*backend["step"]) for i in range(2)]
    return {"correction_dp": correction_dp, "accepted_impulse": accepted,
            "impulse_dp": impulse_dp, "impulse_error": impulse_error, "pose_error": pose_error,
            "requested_accepted_error": max(abs(requested[1+i]-accepted[i]) for i in range(2)),
            "gravity_dp": gravity_dp,
            "backend_model_residual_dv": [frame["after_step"][i+3]-predicted[i] for i in range(2)]}


def support_collapse(frames):
    result = []
    for i in range(1, len(frames)-1):
        a,b,c = frames[i-1:i+2]
        if (a["bearing"]["raw_support"] > 0 and b["bearing"]["raw_support"] == 0 and
            c["bearing"]["raw_support"] == 0 and b["body_input"][7] > 0 and c["body_input"][7] > 0 and
            b["geometry"]["pre_overlap"] >= a["geometry"]["pre_overlap"] and
            c["geometry"]["pre_overlap"] >= b["geometry"]["pre_overlap"]):
            result.append(b["tick"])
    return result


def conditional_gate(one, four):
    if one["first_support"] is None or four["first_support"] is None:
        return False
    return (four["first_support"]["vy"] > one["first_support"]["vy"] and
            (four["maximum_initial_surface_entry"] > one["maximum_initial_surface_entry"] or
             four["maximum_pre_overlap"] > one["maximum_pre_overlap"]))


def summarize(acquisition, trajectory, population):
    if not acquisition["complete"] or acquisition["native_counters"]["dropped"]:
        raise ValueError("incomplete/lossy acquisition")
    frames = trajectory["frames"]
    if len(frames) != 600 or [f["tick"] for f in frames] != list(range(600)):
        raise ValueError("requires complete ordered600frame trace")
    if not trajectory["details"]:
        raise ValueError("detailed observation required")
    initial_counts = frames[0]["stored_counts"]
    if any(f["stored_counts"] != initial_counts or f["bearing"]["probe_drops"] for f in frames):
        raise ValueError("conservation or diagnostic capacity failure")
    if any(f["completed_tick"] != f["tick"]+1 or f["attempted_tick"] != f["tick"]+1 for f in frames):
        raise ValueError("native tick boundary mismatch")
    capsules = population["capsules"]
    weights = population["event_multiplicities"]
    failures = [c for c in capsules if c["target"][0] < 0]
    support = first(frames, lambda f:f["bearing"]["raw_support"]>0)
    overlap = first(frames, lambda f:f["geometry"]["pre_overlap"]>0)
    correction = first(frames, lambda f:any(f["application_details"][0]["applied_correction"]))
    brake = first(frames,lambda f:support is not None and f["tick"]>=support["tick"] and f["bridge_application"][2]<0)
    crossing = first(frames,lambda f:support is not None and f["tick"]>=support["tick"] and f["body_input"][7]<=0)
    end = crossing["tick"] if crossing else 599
    entry = [f for f in frames if support and support["tick"] <= f["tick"] <= end]
    budgets = [motion_budget(f) for f in frames]
    if max(b["impulse_error"] for b in budgets) > 2e-5 or max(b["pose_error"] for b in budgets)>2e-5:
        raise ValueError("motion API-call budget did not close")
    limiters, reasons, stable_histogram, support_failures = Counter(), Counter(), Counter(), Counter()
    for frame in frames:
        b = frame["bearing"]
        if b["bearing_y"] < 0:
            values = {name:b[name] for name in ("arrest","yield","capacity")}
            minimum = min(values.values())
            ties = "+".join(name for name, value in values.items() if math.isclose(value,minimum,rel_tol=1e-10,abs_tol=1e-10))
            limiters[ties] += 1
            if not math.isclose(-b["bearing_y"],minimum,rel_tol=1e-7,abs_tol=1e-7):
                raise ValueError("observed bearing differs from fixed law")
        if sum(p[2] == 0 for p in b["probes"]) != b["raw_support"]:
            raise ValueError("raw support/probe accounting mismatch")
        for probe in b["probes"]:
            reasons[str(probe[2])] += 1
            if probe[2] in (0,3,4): stable_histogram[str(probe[3])] += 1
            for name,count in zip(("paused","fresh","unsupported","missing"),probe[5:9]):
                support_failures[name] += count
    def landmark(frame):
        if frame is None: return None
        return {"tick":frame["tick"],"vy":frame["body_input"][7],"rotation":frame["body_input"][3],
                "initial_surface_entry":frame["geometry"]["initial_surface_entry"],
                "pre_overlap":frame["geometry"]["pre_overlap"],"raw_support":frame["bearing"]["raw_support"],
                "contour_columns":frame["geometry"]["pre_ejection_contour_columns"]}
    first_failure = min(failures,key=lambda c:c["event_ordinal"]) if failures else None
    entry_budgets = [budgets[f["tick"]] for f in entry]
    return {"arm":acquisition["fixture"]["name"],"frames":len(frames),
            "attempts":acquisition["native_counters"]["attempts"],
            "no_target":sum(weights[c["topology_hash"]] for c in failures),
            "success":acquisition["native_counters"]["target_found"],
            "first_support":landmark(support),"first_overlap":landmark(overlap),
            "first_braking":landmark(brake),"first_correction":landmark(correction),
            "first_nonpositive_vy_after_support":landmark(crossing),
            "first_failure":{k:first_failure[k] for k in ("tick","event_ordinal","source","penetration","normal","replay_hash","topology_hash")} if first_failure else None,
            "maximum_initial_surface_entry":max(f["geometry"]["initial_surface_entry"] for f in frames),
            "maximum_pre_overlap":max(f["geometry"]["pre_overlap"] for f in frames),
            "maximum_post_ejection_overlap":max(f["geometry"]["post_ejection_overlap"] for f in frames),
            "maximum_post_tick_overlap":max(f["geometry"]["post_tick_overlap_at_packed_pose"] for f in frames),
            "maximum_raw_support":max(f["bearing"]["raw_support"] for f in frames),
            "support_collapse_ticks":support_collapse(frames),"bearing_limiters":dict(limiters),
            "global_cap_limiting_frames":sum(f["bearing"]["bearing_y"] == -20 and f["bearing"]["capacity"] ==20 for f in frames),
            "maximum_bearing":max(-f["bearing"]["bearing_y"] for f in frames),
            "support_probe_reason_counts":dict(reasons),"stable_below_histogram":dict(stable_histogram),
            "support_visited_rejections":dict(support_failures),
            "raw_support_while_rising_frames":sum(f["body_input"][7]<=0 and f["bearing"]["raw_support"]>0 for f in frames),
            "entry_window":[support["tick"],end] if support else None,
            "entry_accepted_net_y":sum(b["accepted_impulse"][1] for b in entry_budgets),
            "entry_correction_dp_y":sum(b["correction_dp"][1] for b in entry_budgets),
            "entry_backend_gravity_dp_y":sum(b["gravity_dp"][1] for b in entry_budgets),
            "max_impulse_application_error":max(b["impulse_error"] for b in budgets),
            "max_correction_application_error":max(b["pose_error"] for b in budgets),
            "max_requested_accepted_error":max(b["requested_accepted_error"] for b in budgets),
            "max_backend_model_residual_dv":max(abs(v) for b in budgets for v in b["backend_model_residual_dv"]),
            "backend_gravities":sorted({tuple(f["backend"]["gravity"]) for f in frames}),
            "backend_linear_damping":sorted({f["backend"]["linear_damp"] for f in frames}),
            "hard_contact_frames":sum(bool(f["backend"]["contacts"]) for f in frames),
            "contact_reporting_at_capacity_frames":sum(f["backend"]["at_capacity"] for f in frames),
            "descent_failures":sum(weights[c["topology_hash"]] for c in failures if c["current_body"][7]>0),
            "rising_or_stationary_failures":sum(weights[c["topology_hash"]] for c in failures if c["current_body"][7]<=0),
            "conservation_failures":0,"stream_drops":0,"support_probe_drops":0}


def neutral(on, off):
    a,b = on["frames"],off["frames"]
    if len(a) != 600 or len(b) != 600: return False
    keys = ("tick","body_input","before_step","after_step","pre_tick_metrics","pre_tick_results",
            "post_tick_metrics","requested_results","bridge_application","after_application",
            "physical_hash","events","stored_counts","attempted_tick","completed_tick")
    return all(all(x[k] == y[k] for k in keys) for x,y in zip(a,b))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    args=p.parse_args()
    if args.output.resolve().is_relative_to(args.input.resolve()):
        p.error("analysis output must be outside frozen acquisition directory")
    def read(name):return json.loads((args.input/name).read_text(encoding="utf-8"))
    replay=read("replay.json")
    raw=(args.input/"population.json").read_bytes()
    population=json.loads(raw)
    if not replay.get("ok") or replay["matched"] != len(population["capsules"]) or replay["mutation_failures"] or replay["input_sha256"] != hashlib.sha256(raw).hexdigest():
        raise ValueError("unqualified replay blocks causal interpretation")
    result=summarize(read("acquisition.json"),read("trajectory.json"),population)
    write_json(args.output,result)
    print(json.dumps({k:v for k,v in result.items() if not isinstance(v,(dict,list))}))


if __name__ == "__main__":main()
