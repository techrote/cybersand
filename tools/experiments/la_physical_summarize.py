#!/usr/bin/env python3
"""Publish compact source-qualified ledgers from retained complete reductions.

Raw captures/logs stay under ignored build paths; this records recoverable paths,
hashes and exact process receipts rather than committing generated logs/binaries.
"""
import argparse
from collections import Counter,defaultdict
import hashlib
import json
import math
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
def digest(raw):return hashlib.sha256(raw).hexdigest()
def read(path):return json.loads(path.read_text(encoding="utf-8"))
def write(path,value,compact=False):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,separators=(",",":")) +"\n" if compact else json.dumps(value,indent=2)+"\n",encoding="utf-8")
def maximum(rows,key):return max((r.get(key,0) for r in rows),default=0)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("runs",nargs="+")
    parser.add_argument("--output",type=Path,default=ROOT/"docs/audits/la-physical-20261105")
    args=parser.parse_args();episodes=[];cohorts=[];receipts={};inventory={};causal=[];supports=[];timing_groups=defaultdict(list)
    for run in args.runs:
        directory=ROOT/"build/la-physical"/run;reduced=read(directory/"reduced.json");receipt=read(directory/"result.json")
        receipts[run]=receipt;rows=reduced["results"]
        cohorts.append(dict(run=run,source=receipt["identity"]["source"],tree=receipt["identity"]["tree"],
            registration=receipt["registration"]["id"],matrix=receipt["matrix"],coverage=reduced["coverage"],
            episodes=len(rows),observed_steps=sum(r["steps"] for r in rows),
            failed_episodes=sum(bool(r["failures"]) for r in rows),
            closed_tuple_passes=sum(r["closed_tuple_multiset_equal"] is True for r in rows),
            source_ledger_passes=sum(r["material_source_ledger_closes"] is True for r in rows),
            missing_final_capture=sum(r["final"] is None for r in rows),
            max_RID_readback_error=maximum(rows,"max_RID_readback_error"),
            reduction_sha256=digest((directory/"reduced.json").read_bytes())))
        for r in rows:
            path=Path(r["report_path"]);raw=path.read_bytes();assert digest(raw)==r["report_sha256"]
            d=json.loads(raw);steps=d["steps"];platform=next(p for p in receipt["matrix"]["platforms"] if p in path.parts)
            atoms=[row for s in steps for row in s["native_response"]["rows"]]
            applied=[row for s in steps for row in s["application"]["bodies"]]
            counts=Counter()
            for s in steps:
                for a in s["application"]["bodies"]:
                    if "refusal" in a:counts[a["refusal"]]+=1
            geometry=[g for sample in r["geometry_observations"] for g in sample["bodies"]]
            material_area=defaultdict(float);material_depth=defaultdict(float);centres=defaultdict(int)
            for g in geometry:
                for k,v in g.get("area_by_material",{}).items():material_area[k]=max(material_area[k],v)
                for k,v in g.get("maximum_convex_proxy_depth",{}).items():material_depth[k]=max(material_depth[k],v)
                for k,v in g.get("cell_centres_inside",{}).items():centres[k]=max(centres[k],v)
            screen=receipt["registration"]["static_observation"]
            static=None
            if d["case"]["kind"]=="static":
                enough=len(steps)==receipt["registration"]["static_steps"] and all(s["observed_terminal_steps"]==screen["terminal_window"] for s in r["stability"])
                static=dict(sufficient_window=enough,passes=bool(enough and all(max(s["span_x"],s["span_y"])<=screen["span_cells"] and s["rotation_span"]<=screen["rotation_span_radians"] and s["terminal_speed"]<=screen["speed_cells_per_second"] for s in r["stability"])))
            phase={name:dict(mean=sum(s[name] for s in steps)/len(steps),maximum=max(s[name] for s in steps)) for name in ["preparation_us","native_tick_us","application_us","rapier_us","simulation_us","observation_us"]}
            external_impulse_work=sum(float(e.get("impulse_work",0))+float(e.get("reversal_work",0)) for s in steps for e in s["external"])
            force_estimate=0
            for s in steps:
                for i,e in enumerate(s["external"]):
                    if d["case"].get("physical_step_before_application",False):continue
                    force_estimate+=sum(e["force"][axis]*(s["after_step"][i]["pose"][4+axis]-s["after_application"][i]["pose"][4+axis]) for axis in [0,1])
            item=dict(run=run,id=r["id"],platform=platform,source=r["source"],case=r["case"],arm=r["arm"],
                repeat=d["repeat"],requested_workers=r["requested_workers"],actual_workers=r["actual_workers"],steps=r["steps"],
                failures=r["failures"],failure_attempt=r["failure_attempt"],
                initial=r["initial"],final=r["final"],closed_tuple_multiset_equal=r["closed_tuple_multiset_equal"],
                material_source_ledger_closes=r["material_source_ledger_closes"],inserted_materials=r["inserted_materials"],removed_materials=r["removed_materials"],
                initial_geometry=r["initial_geometry"],last_geometry=r["geometry_observations"][-1] if r["geometry_observations"] else None,
                max_area_by_material=dict(material_area),max_convex_proxy_depth_by_material=dict(material_depth),max_cell_centres_inside=dict(centres),
                stability=r["stability"],static_screen=static,final_bodies=steps[-1]["after_step"],
                arrival_count=sum(a["arrival_count"] for a in atoms),arrival_missing=sum(a["arrival_missing"] for a in atoms),arrival_misaligned=sum(a["arrival_misaligned"] for a in atoms),
                event_norm_sum=sum(math.hypot(*a["event_accepted"]) for a in atoms),event_torque_sum=sum(a["event_torque"] for a in atoms),
                displaced=sum(a["displaced"] for a in atoms),unresolved=sum(a["unresolved"] for a in atoms),
                passivity_rejected=sum(bool(a["passivity_rejected"]) for a in atoms),application_refusals=dict(counts),
                scaled_actions=sum(a.get("passive_scale",1)<1 for a in applied),
                maximum_removed_passive_impulse=max(abs(1-a.get("passive_scale",1))*math.hypot(*a.get("passive_impulse_before",[0,0])) for a in applied),
                maximum_removed_passive_torque=max(abs(1-a.get("passive_scale",1))*abs(a.get("passive_torque_before",0)) for a in applied),
                minimum_passive_scale=r["minimum_passive_scale"],max_RID_readback_error=r["max_RID_readback_error"],
                external_direct_impulse_work=external_impulse_work,sustained_force_work_estimate=force_estimate,
                controller_work_status="not independently integrated; recorded forces/torques remain in raw reports",
                response_delta_kinetic_sum=sum(b["response_delta_kinetic"] for s in r["energy"] for b in s["bodies"]),
                correction_potential_sum=sum(b["correction_delta_potential"] for s in r["energy"] for b in s["bodies"]),
                correction_clipping_sum=sum(b["correction_clipping_loss"] for s in r["energy"] for b in s["bodies"]),
                max_arrival_storage_bytes=max(s["native_response"]["arrival_storage_bytes"] for s in steps),
                max_resident_cell_bytes=max(s["statistics"]["values"]["resident_cell_bytes"] for s in steps),
                max_scheduled_cores=max(s["statistics"]["values"]["scheduled_cores"] for s in steps),
                tick_chunk_allocations=sum(s["statistics"]["values"]["chunk_allocations"] for s in steps),
                native_phase_jobs=[s["statistics"]["phase_jobs_last_tick"] for s in [steps[0],steps[-1]]],
                stage_us=phase,timings=r["timings"],control_attempts=d["control_application_attempts"],
                raw_report=str(path.relative_to(ROOT)),raw_report_sha256=r["report_sha256"])
            episodes.append(item)
            if d["case"]["kind"]=="performance":timing_groups[(run,platform,d["case"]["id"],d["arm"],d["requested_workers"])].append(item)
            if d["case"]["kind"]=="causal":
                selected={0,1,2,3,len(steps)-1}
                causal.append(dict(run=run,id=r["id"],source=r["source"],platform=platform,authored=d["authored"],initial_sample=d["initial_sample"],
                    observations=[s for s in steps if s["step"] in selected],complete_window_steps=len(steps),raw_report_sha256=r["report_sha256"]))
            if d["case"]["id"] in ["barrel-rest","needle-rest","scooper-rest","actual-step-delayed-support"] and platform=="windows" and d["requested_workers"]==1 and d["arm"].startswith("LA-SELECTIVE"):
                supports.append(dict(run=run,id=r["id"],source=r["source"],authored=d["authored"],
                    observations=[dict(step=s["step"],live=s["live_before_application"],actions=s["application"]["bodies"],after=s["after_step"],
                        native=[{key:a[key] for key in ["impulse","torque","correction","event_accepted","event_torque","passive_impulse","passive_torque","arrival_count","displaced"]} for a in s["native_response"]["rows"]]) for s in steps]))
        for platform in receipt["matrix"]["platforms"]:
            folder=directory/platform
            for path in folder.rglob("*"):
                if not path.is_file() or "godot" in path.relative_to(folder).parts:continue
                if path.suffix not in [".json",".cyps",".log"]:continue
                inventory[str(path.relative_to(ROOT))]=dict(bytes=path.stat().st_size,sha256=digest(path.read_bytes()))
    repeats=[]
    for key,rows in sorted(timing_groups.items()):
        repeats.append(dict(run=key[0],platform=key[1],case=key[2],arm=key[3],workers=key[4],repeats=len(rows),
            repeat_means_us=[r["timings"]["mean_simulation_us"] for r in rows],
            worst_unrounded_repeat_mean_us=max(r["timings"]["mean_simulation_us"] for r in rows),
            maximum_observed_us=max(r["timings"]["max_simulation_us"] for r in rows),
            terminal60_means_us=[r["timings"]["terminal60_mean_us"] for r in rows],
            actual_participants=sorted({w for r in rows for w in r["actual_workers"]})))
    summary=dict(source=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
        scope="Source-qualified episode summaries, not originalSOL or universal gameplay acceptance",cohorts=cohorts,
        total_episodes=len(episodes),total_observed_steps=sum(r["steps"] for r in episodes),
        attempted_failed_episodes=sum(bool(r["failures"]) for r in episodes),
        max_RID_readback_error=maximum(episodes,"max_RID_readback_error"),
        limitations=["Global native parcel momentum/kinetic energy unavailable","Whole-cell masks and sampled/live geometry differ","Raw local captures required to repeat full reduction","No actual human/device acceptance or originalSOL composition","Total heap allocations and per-worker utilization unavailable"])
    write(args.output/"summary.json",summary);write(args.output/"episodes.json",dict(episodes=episodes),True)
    write(args.output/"performance.json",dict(units="microseconds",scope="instrumented local host timings; originalSOL2msgate not applied",groups=repeats))
    write(args.output/"causal-records.json",dict(scope="Selected actual per-step records; complete local windows separately hashed",records=causal),True)
    write(args.output/"support-trajectories.json",dict(records=supports),True)
    write(args.output/"process-receipts.json",receipts);write(args.output/"raw-inventory.json",inventory,True)
    print(json.dumps(summary,indent=2))

if __name__=="__main__":main()
