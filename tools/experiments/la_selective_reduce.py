#!/usr/bin/env python3
"""Reduce retained LA surrogate runs without changing failures or denominators."""
import hashlib
import argparse
import json
import math
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"build/la-selective"


def sha(data): return hashlib.sha256(data).hexdigest()
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8")
def norm(value): return math.hypot(*value)
def git(*args): return subprocess.check_output(["git","-C",str(ROOT),*args])


def cohort(path):
    data=json.loads(path.read_text(encoding="utf-8"))
    expected_sources={
        "hosts-comparison":"b11e73f92267abdddf17905a94fd99fcb650cd7a",
        "hosts-comparison-full":"a331eca650f228a6795da10d12f31c1c31f6f9fe",
        "hosts-comparison-primed":"ec0ddb9235c42176f240d4289fa021f8647b36fc"}
    assert data["source"]==expected_sources[path.parent.parent.name],"wrong execution source"
    assert not data["failures"] and len(data["episodes"])==32
    assert len({(e["case"],e["mode"]) for e in data["episodes"]})==32
    rows=[]
    initial={}
    for e in data["episodes"]:
        steps=e["steps"]
        assert len(steps)==24 and [s["step"] for s in steps]==list(range(24))
        pristine={k:e[k] for k in ["initial_inventory","initial_body","geometry"]}
        if "initial_geometry" in e: pristine["initial_geometry"]=e["initial_geometry"]
        assert initial.setdefault(e["case"],pristine)==pristine,"unmatched pristine input"
        first=e["initial_inventory"]
        assert all(s["stored_inventory"]["counts"][m]==first["counts"][m]
                   for s in steps for m in [1,2,14]), "granular/Wall count loss"
        assert all(s["stored_inventory"]["water_mass"]==first["water_mass"] for s in steps),"Water quantity loss"
        errors=[]
        for s in steps:
            action=s["application"]["bodies"][0]
            v=s["sampled_body"]["velocity"][:]
            for axis in [0,1]:
                if v[axis]*action["correction"][axis]<0: v[axis]=0
                v[axis]+=action["impulse"][axis]/s["sampled_body"]["mass"]
            omega=s["sampled_body"]["omega"]+action["torque"]/s["sampled_body"]["inertia"]
            errors.append(max(norm([a-b for a,b in zip(v,s["after_application"]["velocity"])]),
                              abs(omega-s["after_application"]["omega"])))
        start=e.get("initial_geometry",steps[0]["geometry_before_step"])
        final=steps[-1]["geometry_after_step"]
        body=e["initial_body"]
        end=steps[-1]["after_step"]
        arrivals=sum(s["candidate_row"]["arrival_count"] for s in steps)
        if e["mode"]=="LA-SELECTIVE":
            if e["case"] in ["passive-burial","stopped-blocked","six-proxy-burial-surrogate","six-proxy-rotated-surrogate"]:
                assert arrivals==0 and end["pose"]==body["pose"] and end["kinetic"]==0
            if e["case"] in ["new-Sand-arrivals","new-Dust-arrivals"]: assert arrivals==1
        if data["profile"].get("backend_warmup_steps",0): assert max(errors)<=1e-5,"Rapier application readback"
        timed=e["owner_total_us"]+e["application_total_us"]
        controls=e.get("control_application_us")
        stats=[s.get("native_statistics",{}).get("values",{}).get("worker_threads_observed") for s in steps]
        rows.append(dict(case=e["case"],mode=e["mode"],requested_workers=e["workers"],steps=len(steps),
            actual_workers_observed=sorted({v for v in stats if v is not None}),
            initial_area=start["material_area"],first_prepared_area=steps[0]["geometry_before_step"]["material_area"],
            final_area=final["material_area"],initial_depth=start["max_proxy_cell_sat_depth"],final_depth=final["max_proxy_cell_sat_depth"],
            body_translation=[a-b for a,b in zip(end["pose"][2],body["pose"][2])],final_kinetic=end["kinetic"],
            event_impulse_magnitude_sum=sum(norm(s["candidate_row"]["event_accepted"]) for s in steps),
            passive_impulse_magnitude_sum=sum(norm(s["candidate_row"]["passive_impulse"]) for s in steps),
            legacy_residual_magnitude_sum=sum(norm(s["legacy_residual"]) for s in steps),
            arrival_count=arrivals,arrival_counters_enabled=e["mode"]=="LA-SELECTIVE",
            missing=sum(s["candidate_row"]["arrival_missing"] for s in steps),
            misaligned=sum(s["candidate_row"]["arrival_misaligned"] for s in steps),
            displaced=sum(s["candidate_row"]["displaced"] for s in steps),
            unresolved=sum(s["candidate_row"]["unresolved"] for s in steps),
            passive_nodes=sum(s["candidate_row"]["nodes"] for s in steps),
            response_energy_delta_sum=sum(s["response_energy_delta"] for s in steps),
            external_challenge_work_sum=sum(s["external_challenge_work"] for s in steps),
            Rapier_step_energy_delta_sum=sum(s["Rapier_step_energy_delta"] for s in steps),
            maximum_immediate_readback_error=max(errors),step_zero_readback_error=errors[0],
            later_readback_error=max(errors[1:]),sidecar_bytes=steps[0]["packet"]["arrival_storage_bytes"],
            native_and_valid_application_total_us=timed,control_application_total_us=controls,
            control_application_attempts=e.get("control_application_attempts"),
            all_recorded_response_work_mean_ms=(timed+controls)/24000 if controls is not None else None,
            timing_qualifier="descriptive wall intervals; shared-host load; no 3-repeat or original SOL CPU gate; includes recorded refused application controls only when available",
            exact_material_counts_conserved=True,water_quantity_conserved=True,
            complete_native_tuples_or_combined_mechanical_energy=False))
    return dict(source=data["source"],profile=data["profile"]["id"],platform=data["platform"],
                raw_path=str(path.relative_to(ROOT)),raw_sha256=sha(path.read_bytes()),raw_bytes=path.stat().st_size,
                checks=data["checks"],failures=data["failures"],episodes=rows)


def composition():
    refs={"LA394":"f44488e9b24c61db3924685ef3723296ab768533",
          "SOL347":"1598115c9065239cc1eaec11e99077274b457be1",
          "facade393":"e4c2649e82d943554f4dc6a0634336770cda08f6",
          "main":"ee92dc45b12455f01218394fd773da516caf356e"}
    common=git("merge-base",refs["LA394"],refs["SOL347"]).decode().strip()
    changed=set()
    for ref in refs.values(): changed.update(git("diff","--name-only",common,ref).decode().splitlines())
    paths=sorted(p for p in changed if p.startswith(("native/","godot/","tools/material_catalogue/","materials/catalogue/")))
    trees={k:{row.split(None,3)[3]:row.split()[2] for row in git("ls-tree","-r",ref).decode().splitlines()} for k,ref in refs.items()}
    lock=json.loads((ROOT/"materials/catalogue/compatibility-lock.json").read_text(encoding="utf-8"))
    protected={v["path"] for v in lock["source_locks"]}
    inventory=[]
    for path in sorted(set(paths)|protected):
        cells={}
        for label,tree in trees.items():
            blob=tree.get(path)
            cells[label]=None if blob is None else dict(blob=blob,lf_sha256=sha(git("cat-file","blob",blob).replace(b"\r\n",b"\n")))
        inventory.append(dict(path=path,protected=path in protected,sources=cells))
    return dict(sources={label:dict(commit=ref,tree=git("rev-parse",ref+"^{tree}").decode().strip()) for label,ref in refs.items()},
                common_ancestor=common,scope="complete changed source/runtime/material path union plus all frozen protected consumers; blob SHA hashes Git content, LFS blobs are pointers",
                files=inventory,admissible_composition=False,
                reason="Distinct protected World/pressure/inertial bytes and missing SOL ownership substrate; no combined source admission. #393 facade repair changes no protected consumer.")


def main():
    global OUT
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument("--run",default="la-selective",help="complete retained campaign directory under build")
    args=parser.parse_args()
    if Path(args.run).name!=args.run or args.run in [".",".."]: raise ValueError("Expected one owned build directory name")
    OUT=ROOT/"build"/args.run
    results=[]
    for scope in ["hosts-comparison","hosts-comparison-full","hosts-comparison-primed"]:
        for platform in ["windows","linux"]:
            for workers in [1,4]:
                path=OUT/scope/platform/("experiment-w"+str(workers)+".json")
                if not path.is_file(): raise RuntimeError("Missing registered cohort: "+str(path))
                results.append(cohort(path))
    write(OUT/"comparison-summary.json",dict(cohorts=results,original_SOL_matched_arm="UNAVAILABLE",
        area_precision="Godot float32 surrogate metrics; not original SOL acceptance",original_120_plus_60="NOT REGISTERED OR EXECUTED"))
    write(OUT/"composition-map.json",composition())
    print("cohorts",len(results),"episodes",sum(len(c["episodes"]) for c in results),
          "steps",sum(sum(e["steps"] for e in c["episodes"]) for c in results))


if __name__=="__main__": main()
