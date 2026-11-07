#!/usr/bin/env python3
"""Strict real full-size Godot 2048x1024 matched CPU, worker and physics reducer.

Not a synthetic workload, not an optimizer and not a simulation-law test patch.
Refuses missing native quantity conservation, gas ledger closure, source identity
or actual task participant observation. Async actor inputs are NOT lockstep.
"""
from __future__ import annotations
import hashlib, json, statistics, sys
from pathlib import Path

import pf532_stress_workbench_readback as historical

COUNTERS=(
    "gas_nanoseconds","head_nanoseconds","preparation_nanoseconds",
    "pf_probe_gas_process_cpu_ns","pf_probe_gas_owner_cpu_ns",
    "pf_probe_head_process_cpu_ns","pf_probe_discovery_process_cpu_ns",
    "pf_probe_identity_process_cpu_ns","pf_probe_relabel_process_cpu_ns",
    "gas_seed_cells","gas_seed_probes","gas_bfs_cells","gas_bfs_probes",
    "gas_relabel_cells","gas_reference_passes","gas_reuses",
    "gas_component_reuses","gas_member_validations","gas_invalidation_pairs",
    "gas_component_invalidations","gas_dirty_chunks_queued","gas_cache_build_cells",
    "gas_member_initializations","gas_member_builds","gas_restart_fallbacks",
    "gas_capacity_fallbacks","gas_budget_fallbacks","gas_cache_builds","gas_identity_nodes",
    "water_material_calls","water_motion_calls",
)
NS=("gas_nanoseconds","head_nanoseconds","preparation_nanoseconds",
    "pf_probe_gas_process_cpu_ns","pf_probe_gas_owner_cpu_ns",
    "pf_probe_head_process_cpu_ns","pf_probe_discovery_process_cpu_ns",
    "pf_probe_identity_process_cpu_ns","pf_probe_relabel_process_cpu_ns")

def require(ok:bool,msg:str):
    if not ok: raise ValueError(msg)

def read_dict(x,name):
    require(isinstance(x,dict),f"{name} missing/corrupt")
    return x

def one(record:dict,tag:str)->dict:
    src=record["pf_full_profile"]
    begin=read_dict(src["begin"],tag+" start")
    end=read_dict(src["end"],tag+" end")
    ticks=int(end["tick"])-int(begin["tick"])
    require(170<=ticks<=300,f"{tag}: invalid effective native tick interval {ticks}")
    require(int(begin["native_generation"])==int(end["native_generation"]),
            f"{tag}: source World was replaced during profiling")
    counter0=read_dict(begin["counters"],tag+" counters before")
    counter1=read_dict(end["counters"],tag+" counters after")
    out={"ticks":ticks,"raw":{},"per_tick":{}}
    for key in COUNTERS:
        val0,val1=counter0.get(key),counter1.get(key)
        require(isinstance(val0,str) and val0.isdecimal() and isinstance(val1,str) and val1.isdecimal(),
                f"{tag}: missing native counter {key}")
        delta=int(val1)-int(val0)
        require(delta>=0,f"{tag}: nonmonotonic {key}")
        out["raw"][key]=delta
        out["per_tick"][key]=(delta/ticks/1e6) if key in NS else delta/ticks
    part=src["worker_participation"]
    require(isinstance(part,list) and len(part)>=2,f"{tag}: no actual native worker observations")
    workers=[int(p.get("workers_observed",-1)) for p in part]
    capacities=[int(p.get("worker_capacity",-1)) for p in part]
    require(all(1<=w<=c<=32 for w,c in zip(workers,capacities)),
            f"{tag}: invalid actual participant count/capacity {workers}, {capacities}")
    out["cache_observed"]=read_dict(end.get("observed",{}),tag+" observed cache state")
    out["requested_config"]=read_dict(end.get("requested_config",{}),tag+" requested cache config")
    out["execution_version"]=int(end.get("execution_version",0))
    out["worker"]={"samples":len(part),"max_actual_participants":max(workers),
                   "median_actual_participants":statistics.median(workers),
                   "max_configured_capacity":max(capacities),
                   "minimum_actual_participants":min(workers)}
    checkpoints=src["checkpoints"]
    require(isinstance(checkpoints,list) and len(checkpoints)>=3,
            f"{tag}: completed tick authoritative physics checkpoints missing")
    seen=set()
    checks={}
    for cp in checkpoints:
        t=int(cp["tick"])
        require(t not in seen,f"{tag}: duplicate checkpoint tick {t}")
        seen.add(t)
        h=cp.get("physical_hash","")
        require(isinstance(h,str) and len(h)==16 and all(c in "0123456789abcdefABCDEF" for c in h),
                f"{tag}: invalid physical state hash at {t}")
        require(int(cp.get("hash_version",-1))==5,f"{tag}: not explicit C2048 physical hash 5")
        require(int(cp.get("gas_capacity",-1))==2048
                and 0 <=int(cp.get("gas_compartments",-1))<=2048,
                f"{tag}: C2048 capacity or gas census mismatch")
        q=read_dict(cp.get("water_quantity"),tag+" Water native quantity")
        g=read_dict(cp.get("gas_ledger"),tag+" native gas ledger")
        b=read_dict(cp.get("ballistic_water"),tag+" ballistic Water")
        require(q.get("closed") is True and
                int(q.get("actual",-1))==int(q.get("produced",-1))-int(q.get("consumed",-1)),
                f"{tag}: native complete Water quantity invariant failed at tick {t}")
        require(g.get("closes") is True and
                int(g.get("amount_live",-1))+int(g.get("vented",-1))+int(g.get("collapsed",-1))
                    ==int(g.get("created",-1))+int(g.get("absorbed",-1)),
                f"{tag}: gas inventory/creation accounting invariant failed at tick {t}")
        require(int(b.get("total",-1))==int(b.get("expected",-2)) and
                int(q.get("actual",-1))==int(b.get("total",-2)),
                f"{tag}: Water grid/ballistic exact accounting disagrees at tick {t}")
        kinds=q.get("kinds")
        require(isinstance(kinds,list) and len(kinds)==6 and all(
            isinstance(v,dict) and int(v.get("produced",-1))>=0
            and int(v.get("consumed",-1))>=0 for v in kinds),
            f"{tag}: incomplete six-kind native quantity causality")
        checks[t]={
          "tick":t, "physical_hash":h,"physical_hash_version":5,
          "water":q,"gas":g,"gas_compartments":int(cp["gas_compartments"]),
          "ballistic_water":b,
        }
    out["physics"]={"checkpoints":checks,"closed":True,
                    "checkpoint_ticks":sorted(checks),"snapshots":len(checks)}
    return out

def metric(records:dict,k:str)->dict:
    values={arm:records[arm]["per_tick"][k] for arm in ("B1","C1","C2","B2")}
    paired=[]
    for j in (1,2):
        a,b=values["B"+str(j)],values["C"+str(j)]
        paired.append(100*(1-b/a) if a>0 else None)
    valid=[x for x in paired if x is not None]
    return {"baseline_median":statistics.median(values[x] for x in ("B1","B2")),
            "candidate_median":statistics.median(values[x] for x in ("C1","C2")),
            "paired_speedup_percent":paired,
            "median_paired_speedup_percent":statistics.median(valid) if valid else None,
            "unit":"ms/native_tick" if k in NS else "events/native_tick"}

def compare_physics(records:dict)->dict:
    pairs=[]
    for rep in (1,2):
        a=records["B"+str(rep)]["physics"]["checkpoints"]
        b=records["C"+str(rep)]["physics"]["checkpoints"]
        shared=sorted(set(a)&set(b))
        matches=[t for t in shared if a[t]["physical_hash"]==b[t]["physical_hash"]]
        pairs.append({"pair":rep,"baseline_checkpoint_ticks":sorted(a),
                      "candidate_checkpoint_ticks":sorted(b),
                      "matched_native_tick_checkpoints":shared,
                      "identical_full_physical_state_hash_at_same_tick":matches,
                      "different_full_physical_state_hash_at_same_tick":[t for t in shared if t not in matches],
                      "async_limitation":"Independent Rapier inputs are not a replay-locked identical body stream"})
    return {"pairs":pairs,
            "all_native_water_and_gas_ledgers_closed":all(
                r["physics"]["closed"] for r in records.values()),
            "deterministic_source_physics_parity_qualified":False,
            "reason":"Actual async Godot/Rapier body states, hard edit timing and injected jets are not held to the same native-tick input log; raw physical hash inequality alone is not attributable to gas solver"}

def main()->int:
    if len(sys.argv)!=2:
        raise SystemExit("usage: pf532_fullsize_cpu_physics_readback.py <evidence-dir>")
    root=Path(sys.argv[1])
    try:
        historic=historical.compare(root)
        records={}
        for arm in ("B1","C1","C2","B2"):
            records[arm]=one(historic["source_reports"][arm],arm)
        m={k:metric(records,k) for k in COUNTERS}
        gas=m["gas_nanoseconds"]["median_paired_speedup_percent"]
        cpu=m["pf_probe_gas_process_cpu_ns"]["median_paired_speedup_percent"]
        native=historic["metrics"]["simulation"]["p50_ms"]["median_paired_speedup_percent"]
        # Do not interpret two pairs as high-confidence optimization admission.
        status=("HOLD_NEGATIVE_FULLSIZE" if native <=0 or gas is None or cpu is None or
                gas <=0 or cpu <=0 else
                "HOLD_SMALL_POSITIVE_UNQUALIFIED" if native <5 else
                "HOLD_MORE_QUALIFICATION_REQUIRED")
        doc={
            "schema":"pf532-full-workbench-cpu-physics-v1",
            "status":status,"decision":"NO_MERGE_NO_FULL_FACTORIAL",
            "base":historic["base_source"],"candidate":historic["optimized_source"],
            "profile_probes":json.loads((root/"probe-patch-identities.json").read_text()),
            "host_source_probes":json.loads((root/"godot-source-probe.json").read_text()),
            "workload":historic["workload"],
            "four_executable_runs":"4/4 PASS",
            "performance":historic["metrics"],
            "cpu_and_gas_work_per_tick":m,
            "worker_participation":{k:v["worker"] for k,v in records.items()},
            "cache_observed":{k:v["cache_observed"] for k,v in records.items()},
            "execution_version":{k:v["execution_version"] for k,v in records.items()},
            "physics":compare_physics(records),
            "raw_run_metric_and_physics_copies":records,
            "limits":[
               "Linux process CPU clock includes all native worker and Godot/Rapier threads active inside gas-owner time windows; not gas-exclusive CPU",
               "Owner thread CPU excludes workers; only observed task participants, not phase utilization or pinning",
               "No bitwise source-to-source physical equality claim from separately timed asynchronous body input streams",
               "Test-only identical probes may perturb performance; compare to prior uninstrumented full-size experiment",
               "Four paired runs, full 2048x1024, are not a statistically generalizable percent-of-FPS claim",
               "Full 360x3 per source and installed native LFS publication not attempted",
            ]
        }
        (root/"fullsize-cpu-physics-report.json").write_text(json.dumps(doc,indent=2,sort_keys=True)+"\n")
        summary={"status":status,"gas_wall":m["gas_nanoseconds"],"gas_cpu":m["pf_probe_gas_process_cpu_ns"],
                 "owner_cpu":m["pf_probe_gas_owner_cpu_ns"],"native_p50":native,
                 "worker_counts":doc["worker_participation"],
                 "physics_closed":doc["physics"]["all_native_water_and_gas_ledgers_closed"],
                 "hashes":doc["physics"]["pairs"]}
        print("PF532_FULLSIZE_FINAL_CPU_PHYSICS "+json.dumps(summary,sort_keys=True))
        return 0
    except Exception as e:
        (root/"fullsize-cpu-physics-error.txt").write_text(str(e)+"\n")
        raise
if __name__=="__main__":
    raise SystemExit(main())
