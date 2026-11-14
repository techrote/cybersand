#!/usr/bin/env python3
"""Reduce one bounded same-host Gas stage-CPU A/B without physics changes.

Profiles two identical diagnostic Windows builds over #493's eight-actor Godot
workload. Windows GetProcessTimes values are CPU spent by the ENTIRE process
during the native gas code region; owner thread uses GetThreadTimes. They are
not claimed as gas-exclusive CPU cycles or a rendered application FPS.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import statistics
from pf_gas_acceptance import load_role, read_json, selected, write_json

GAS_COUNTERS = (
    "gas_nanoseconds", "head_nanoseconds", "preparation_nanoseconds",
    "pf_probe_gas_process_cpu_ns", "pf_probe_gas_owner_cpu_ns",
    "pf_probe_head_process_cpu_ns", "pf_probe_discovery_process_cpu_ns",
    "pf_probe_identity_process_cpu_ns", "pf_probe_relabel_process_cpu_ns",
    "gas_seed_cells", "gas_seed_probes", "gas_bfs_cells", "gas_bfs_probes",
    "gas_relabel_cells", "gas_identity_nodes", "gas_reference_passes",
    "gas_reuses", "gas_restart_fallbacks", "gas_component_reuses",
    "gas_capacity_fallbacks", "gas_budget_fallbacks", "water_material_calls",
    "water_motion_calls",
)
TIMING_NAMES = (
    "native_tick_p50_ms", "native_tick_p95_ms", "native_tick_p99_ms",
    "native_hz", "rapier_step_p50_ms", "rapier_step_p95_ms",
)
NAMES = {
    "gas_nanoseconds":"gas_stage_wall_ms_per_tick",
    "head_nanoseconds":"pressure_head_wall_ms_per_tick",
    "preparation_nanoseconds":"pressure_prepare_wall_ms_per_tick",
    "pf_probe_gas_process_cpu_ns":"gas_window_all_process_cpu_ms_per_tick",
    "pf_probe_gas_owner_cpu_ns":"gas_window_owner_thread_cpu_ms_per_tick",
    "pf_probe_head_process_cpu_ns":"head_window_process_cpu_ms_per_tick",
    "pf_probe_discovery_process_cpu_ns":"gas_discovery_window_process_cpu_ms_per_tick",
    "pf_probe_identity_process_cpu_ns":"gas_identity_window_process_cpu_ms_per_tick",
    "pf_probe_relabel_process_cpu_ns":"gas_relabel_window_process_cpu_ms_per_tick",
}
COUNTERS=tuple(NAMES.values())

def median(xs: list[float]) -> float:
    return statistics.median(xs) if xs else math.nan

def extract(row: dict) -> dict:
    s=row["summary"]
    begin=s.get("pf_cpu_profile_begin",{})
    end=s.get("pf_cpu_profile_end",{})
    if not isinstance(begin,dict) or not isinstance(end,dict) or not begin or not end:
        raise ValueError("Incomplete worker-exclusive profiling for "+str(row.get("id")))
    c0=begin.get("counters",{})
    c1=end.get("counters",{})
    tick0=int(begin.get("tick",-1))
    tick1=int(end.get("tick",-1))
    n=tick1-tick0
    if n<99 or n>160 or n<0:
        raise ValueError("Profiling must correspond to ~100 real native ticks: "+str((tick0,tick1)))
    values={}
    for name in GAS_COUNTERS:
        if name not in c0 or name not in c1 or not str(c0[name]).isdigit() or not str(c1[name]).isdigit():
            raise ValueError(f"Missing unsigned native stage/work counter {name} in {row['id']}")
        d=int(c1[name])-int(c0[name])
        if d<0: raise ValueError("Nonmonotonic native counter "+name+" "+row["id"])
        values[name]=d
    m={key:values[src]/(n*1e6) for src,key in NAMES.items()}
    for name in ("gas_seed_cells","gas_seed_probes","gas_bfs_cells","gas_bfs_probes",
                 "gas_relabel_cells","gas_identity_nodes","gas_reference_passes",
                 "gas_reuses","gas_restart_fallbacks","gas_component_reuses",
                 "gas_capacity_fallbacks","gas_budget_fallbacks",
                 "water_material_calls","water_motion_calls"):
        m[name+"_per_tick"]=values[name]/n
    for name in TIMING_NAMES:
        v=float(s.get(name,-1))
        if v<0 or not math.isfinite(v):
            raise ValueError("Invalid Godot native timing "+name+" in "+row["id"])
        m[name]=v
    a=s.get("native_wall_samples_ms",[])
    m["native_sampled_mean_tick_ms"]=statistics.mean(a) if a else None
    m["worker_observation_start"]=begin.get("native_worker_participation",{})
    m["worker_observation_end"]=end.get("native_worker_participation",{})
    m["tick_interval"]=[tick0,tick1]
    m["measured_native_ticks"]=int(s.get("native_ticks",0))
    m["rapier_ticks"]=int(s.get("rapier_ticks",0))
    m["spray_ledger"]=s.get("spray_ledger")
    m["spray_totals"]=s.get("spray_totals")
    m["spray_receipt"]=s.get("spray_receipt")
    m["sample_count"]=int(s.get("snapshot_samples",0))
    return m

def difference(a:dict,b:dict,field:str)->dict:
    base=a[field]; cand=b[field]
    return {"baseline":base,"candidate":cand,
            "delta_candidate_minus_baseline":cand-base,
            "speedup_percent":100*(1-cand/base) if base>0 else None}

def robust_summary(rows: list[dict],key:str) -> dict:
    if not rows: return {"paired_configs":0}
    d=[r["metrics"][key] for r in rows]
    improvements=[x["speedup_percent"] for x in d if x["speedup_percent"] is not None]
    return {
        "paired_configs":len(rows),
        "baseline_median":median([v["baseline"] for v in d]),
        "candidate_median":median([v["candidate"] for v in d]),
        "median_paired_speedup_percent":median(improvements) if improvements else None,
        "median_paired_delta":median([v["delta_candidate_minus_baseline"] for v in d]),
        "range_paired_speedup_percent":[min(improvements),max(improvements)] if improvements else None,
    }

def compare(baseline:Path,candidate:Path)->dict:
    a_receipts,a_rows,a_counts=load_role(baseline,"baseline","pfprofile")
    b_receipts,b_rows,b_counts=load_role(candidate,"candidate","pfprofile")
    problems=[]
    for role,c in (("baseline",a_counts),("candidate",b_counts)):
        if c!={"PASS":32}: problems.append(role+": not 32/32 PASS "+str(c))
    if set(a_rows)!=set(b_rows):
        problems.append("Unmatched config/repetition set")
    invariants=("hardware","godot_version","godot_sha256","rapier_sha256",
                "fixture_sha256","generator_sha256","acceptance_runner_sha256",
                "source_revision_harness")
    for key in invariants:
        if len({json.dumps(z.get(key),sort_keys=True)
                for z in (*a_receipts.values(),*b_receipts.values())})!=1:
            problems.append("Runtime/source-host invariant mismatch "+key)
    for role,rcpts in (("baseline",a_receipts),("candidate",b_receipts)):
        if len({r["native_build"]["source_commit"] for r in rcpts.values()})!=1:
            problems.append(role+" inconsistent build source")
    fields=("compiler","build_flags","build_profile")
    for key in fields:
        if a_receipts[0]["native_build"].get(key)!=b_receipts[0]["native_build"].get(key):
            problems.append("Build configuration differs "+key)
    if problems:
        return {"schema":"pf-gas-cpu-profile-report-v1","decision":"INVALID","problems":problems}
    pairs=[]
    for cfg in selected(0,"pfprofile"):
        ident=cfg["id"]
        aa=[extract(a_rows[(ident,rep)]) for rep in (0,1)]
        bb=[extract(b_rows[(ident,rep)]) for rep in (0,1)]
        fields=tuple(NAMES.values())+(
            "native_tick_p50_ms","native_tick_p95_ms","native_tick_p99_ms","native_hz",
            "rapier_step_p50_ms","rapier_step_p95_ms","gas_seed_cells_per_tick",
            "gas_seed_probes_per_tick","gas_bfs_cells_per_tick",
            "gas_bfs_probes_per_tick","gas_relabel_cells_per_tick",
            "gas_reference_passes_per_tick","gas_reuses_per_tick",
            "gas_restart_fallbacks_per_tick","gas_component_reuses_per_tick")
        samples={}
        for key in fields:
            a_m=median([x[key] for x in aa])
            b_m=median([x[key] for x in bb])
            samples[key]=difference({key:a_m},{key:b_m},key)
            samples[key]["baseline_repeats"]=[x[key] for x in aa]
            samples[key]["candidate_repeats"]=[x[key] for x in bb]
        equivalent_spray=all(
            aa[i]["spray_ledger"]==bb[i]["spray_ledger"] and
            aa[i]["spray_totals"]==bb[i]["spray_totals"] and
            aa[i]["spray_receipt"]==bb[i]["spray_receipt"]
            for i in (0,1))
        if not equivalent_spray:
            problems.append("Different splash/quantity receipts: "+ident)
        pairs.append({
            "config":cfg,"id":ident,
            "metrics":samples,
            "spray_identical_per_repetition":equivalent_spray,
            "per_repetition":{"baseline":aa,"candidate":bb},
        })
    pf_on=[x for x in pairs if x["config"]["family"]=="pressure_flow_v1" and x["config"]["gas"]]
    pf_off=[x for x in pairs if x["config"]["family"]=="pressure_flow_v1" and not x["config"]["gas"]]
    controls=[x for x in pairs if x["config"]["family"]!="pressure_flow_v1"]
    keys=("native_tick_p50_ms","gas_stage_wall_ms_per_tick","gas_window_all_process_cpu_ms_per_tick",
          "gas_window_owner_thread_cpu_ms_per_tick","gas_discovery_window_process_cpu_ms_per_tick",
          "gas_identity_window_process_cpu_ms_per_tick","gas_relabel_window_process_cpu_ms_per_tick",
          "pressure_head_wall_ms_per_tick","head_window_process_cpu_ms_per_tick",
          "gas_seed_cells_per_tick","gas_bfs_cells_per_tick","gas_relabel_cells_per_tick")
    def summary(rows):return {k:robust_summary(rows,k) for k in keys}
    out={
        "schema":"pf-gas-cpu-profile-report-v1",
        "decision":"REPAIR" if problems else "DIAGNOSTIC_ONLY",
        "scope":"exact original #493 59-material/eight-Rapier-actor 1024x512 scene; ballistic/face/spray; 32/64-cell cores; 30 warmup + 100 native ticks",
        "trials":{"baseline":len(a_rows),"candidate":len(b_rows),
                  "configurations":16,"repeats_per_source":2,
                  "baseline_statuses":a_counts,"candidate_statuses":b_counts},
        "source_builds":{"baseline":a_receipts[0]["native_build"],
                         "candidate":b_receipts[0]["native_build"]},
        "problems":problems,
        "gas_on":summary(pf_on),
        "gas_off":summary(pf_off),
        "non_pf_controls":summary(controls),
        "by_core":{"64":summary([x for x in pf_on if not x["config"]["fine"]]),
                   "32":summary([x for x in pf_on if x["config"]["fine"]])},
        "pairs":pairs,
        "interpretation_limits":[
            "Windows process CPU between gas-stage boundaries includes all concurrent Godot/Rapier and worker threads; cannot be ascribed exclusively to gas",
            "Owner-thread CPU excludes parallel worker CPU; gas process CPU may exceed elapsed gas wall because multiple threads execute",
            "Gas stage and head boundaries are taken inside temporary identical diagnostic builds, not admitted uninstrumented production source",
            "Cumulative tick counters are sampled at exclusive-worker snapshot publication; a few skipped frames may make interval length differ from nominal 100",
            "Native tick p50 is wall-clock time, not process CPU or desktop rendered FPS",
            "Ordinary async actor trajectories are not a bit-exact coupled determinism proof",
            "This diagnostic selection does not substitute the full 360x3 source-matched factorial or real GPU acceptance",
        ],
    }
    return out

def main()->None:
    p=argparse.ArgumentParser()
    p.add_argument("--baseline",required=True)
    p.add_argument("--candidate",required=True)
    p.add_argument("--output",required=True)
    a=p.parse_args()
    try:
        report=compare(Path(a.baseline),Path(a.candidate))
    except Exception as e:
        report={"schema":"pf-gas-cpu-profile-report-v1","decision":"INVALID","problems":[str(e)]}
    write_json(Path(a.output),report)
    short={k:v for k,v in report.items() if k!="pairs"}
    print("PF_GAS_CPU_PROFILE_REPORT "+json.dumps(short,sort_keys=True),flush=True)
    if report["decision"]=="INVALID" or report.get("problems"):
        raise SystemExit(1)

if __name__=="__main__":
    main()
