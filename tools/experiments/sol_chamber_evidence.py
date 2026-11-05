#!/usr/bin/env python3
"""Seal compact review evidence while retaining complete raw local custody."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(path):return json.loads(path.read_text(encoding="utf-8-sig"))
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    text=json.dumps(value,separators=(",",":")) if path.name=="reference-trajectories.json" else json.dumps(value,indent=2)
    path.write_bytes((text+"\n").encode())

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("output",type=Path);args=parser.parse_args()
    assert not args.output.exists();args.output.mkdir(parents=True)
    base=ROOT/"build/sol-chamber";run=base/"registered-matrix-corrected";summary=load(run/"reduction/reduced.json");receipt=load(run/"receipt.json")
    assert summary["full_matrix_coverage"] and len(summary["episodes"])==192 and all(r["clean"] for r in receipt["results"])
    assert sha((ROOT/"tools/experiments/sol_chamber_reduce.py").read_bytes().replace(b"\r\n",b"\n"))==summary["reducer_sha256"],"Preserve executed evaluator source"
    files=[]
    def copy(source,name):
        raw=source.read_bytes();retained=raw.replace(b"\r\n",b"\n") if source.suffix==".json" else raw
        target=args.output/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(retained)
        files.append(dict(path=name,bytes=len(retained),sha256=sha(retained),original_local_path=str(source.relative_to(ROOT)),original_local_bytes=len(raw),original_local_sha256=sha(raw)))
    copy(run/"receipt.json","execution.json");copy(run/"reduction/reduced.json","episodes.json")
    for name in ["initial-closed","closed-replay","driven-accounting","registered-matrix"]:copy(base/name/"receipt.json",name+".json")
    copy(base/"registered-matrix/interrupted-custody.json","interrupted-custody.json")
    copy(base/"force-source/receipt.json","force-source.json")
    for name in ["driven-comparison.png","occupancy-counterexample.png","cost-ledger.png"]:copy(base/"figures-v2"/name,name)
    inputs=defaultdict(set);groups=defaultdict(list);bindings=[];trajectories={};geometry_complete=0
    for row in summary["episodes"]:
        raw=load(ROOT/row["report_path"]);metrics=load(run/"reduction"/(row["platform"]+"-"+row["id"]+".metrics.json"))
        assert raw["source"]==receipt["identity"]["source"] and sha((ROOT/row["report_path"]).read_bytes())==row["raw_sha256"]
        inputs[row["case"]["id"]].add(raw["initial_payload"]["sha256"])
        full=all(g["complete_in_fixed_roi"] for s in metrics["steps"] for g in s["geometry"]);geometry_complete+=full
        groups[(row["case"]["id"],row["mode"])].append(row)
        bindings.append(dict(platform=row["platform"],id=row["id"],source=row["source"],raw_sha256=row["raw_sha256"],world_instance=raw["initial"]["world_instance"],body_rid=raw["initial"]["state"]["rid"],session=raw["initial_sample"]["session"],epoch=raw["initial_sample"]["epoch"],instance_id=520,generation=1,
            initial_sample_sha256=raw["construction_receipt"]["workbench_initial_sample_sha256"],full_geometry_coverage=full,
            initial_cyps=metrics["initial_payload"],final_cyps=metrics["final_payload"],
            external_api_kinetic_delta_sum=sum(s["external_api_kinetic_delta"] for s in raw["steps"]),
            rapier_kinetic_delta_sum=sum(s["rapier_kinetic_delta"] for s in raw["steps"]),
            preapplication_kinetic_delta_sum=sum(s["preapplication_kinetic_delta"] for s in raw["steps"]),
            max_application_age=max(s["application"]["bodies"][0]["age"] for s in raw["steps"])))
        if row["platform"]=="windows" and row["requested_workers"]==1 and row["repeat"]==0:
            trajectories[row["id"]]=[dict(step=s["step"],geometry=[{k:v for k,v in g.items() if k not in ["recorded_transform_proxy_union","hard_exclusions"]} for g in s["geometry"]],hard_counts=[len(g["hard_exclusions"]) for g in s["geometry"]],candidate_kinetic_delta=s["recomputed_response_kinetic_delta"]) for s in metrics["steps"]]
            if row["case"]["id"]=="closed-driven" and row["mode"]=="LA-SELECTIVE":
                copy(ROOT/row["report_path"],"raw-reference-closed-driven-selective.json")
                payload_index={};seen=set()
                metas=[raw["initial_payload"],*[s["payload"] for s in raw["steps"] if "payload" in s],raw["final_payload"]]
                for meta in metas:
                    source=Path(meta["path"]).resolve();assert source.is_relative_to(base.resolve()) and sha(source.read_bytes())==meta["sha256"]
                    name="reference-payloads/"+meta["sha256"]+".cyps";payload_index[meta["path"]]=name
                    if name not in seen:copy(source,name);seen.add(name)
                write(args.output/"reference-payload-index.json",payload_index)
                raw_index=(args.output/"reference-payload-index.json").read_bytes();files.append(dict(path="reference-payload-index.json",bytes=len(raw_index),sha256=sha(raw_index)))
    assert all(len(values)==1 for values in inputs.values()),"Initial full CYPS differs within a matched case"
    comparison=[]
    for (case,mode),rows in groups.items():
        comparison.append(dict(case=case,mode=mode,executions=len(rows),sand_area_max=max(r["maximum_observed_sand_area"] for r in rows),depth_max=max(r["maximum_observed_sand_depth"] for r in rows),hard_step_records=sum(r["hard_exclusion_steps"] for r in rows),
            final_area_range=[min(r["final"]["sand_area"] for r in rows),max(r["final"]["sand_area"] for r in rows)],
            counts_preserved=all(r["material_count_conservation"] for r in rows),tuples_preserved=all(r["exact_tuple_multiset_conservation"] for r in rows)))
    performance=[]
    for host in ["windows","linux"]:
        for workers in [1,4]:
            rows=[r for r in summary["episodes"] if r["platform"]==host and r["requested_workers"]==workers]
            kernel=[sum(r["cost_us"][k] for k in ["preparation_us","native_tick_us","application_us","rapier_us"])/180/1000 for r in rows]
            elapsed=[r["cost_us"]["elapsed_us"]/180/1000 for r in rows]
            performance.append(dict(platform=host,requested_workers=workers,episodes=len(rows),kernel_episode_mean_ms_range=[min(kernel),max(kernel)],measured_step_episode_mean_ms_range=[min(elapsed),max(elapsed)],actual_participants_max=max(r["native_peaks"].get("worker_threads_observed",0) for r in rows)))
    outputs={"comparison.json":dict(executed_source=receipt["identity"]["source"],complete_matrix=True,episodes=192,steps=34560,phase_observations=172800,full_geometry_coverage_episodes=geometry_complete,initial_cyps_hashes={k:list(v) for k,v in inputs.items()},groups=comparison,performance=performance,
        cost_qualifier="Elapsed stage measurements; all child-process startup/final dump/teardown retained in execution.json. Controller checksum/setup/copy and interrupted totals not fully measured. Not original SOL CPU or universal60Hz qualification."),
        "bindings-and-quantities.json":bindings,"reference-trajectories.json":dict(selection="Fixed Windows/requestedworker1/repeat0 for all16conditions; full192bindings retained separately",trajectories=trajectories)}
    for name,value in outputs.items():
        write(args.output/name,value);raw=(args.output/name).read_bytes();files.append(dict(path=name,bytes=len(raw),sha256=sha(raw)))
    raw_files=[]
    for path in sorted(base.rglob("*")):
        if not path.is_file() or path.suffix not in [".json",".cyps",".log"] or any(p in path.parts for p in ["godot","plot-env"]):continue
        raw_files.append(dict(path=str(path.relative_to(ROOT)),bytes=path.stat().st_size,sha256=sha(path.read_bytes())))
    write(args.output/"manifest.json",dict(schema="cybersand.sol-chamber.evidence.v1",scope="Geometry surrogate, no original SOL authority/admission",execution_source=receipt["identity"]["source"],files=files,local_raw_files=raw_files,
        raw_custody="Complete logs/CYPS/reports/derivatives retained locally; compact ledgers and one fixed raw reference committed. Full raw packet required for independent final audit. LF normalization of copied JSON preserves original local hashes separately.",
        attempt_ledger=dict(initial_typed_array_failed=2,static_replay_passed=2,first_matrix_sealed=28,first_matrix_observer_failures=12,first_matrix_interrupted=1,first_matrix_not_run=163,corrected_driven_passed=2,corrected_matrix_passed=192,total_attempted_episodes_including_interrupted=227),
        assembly_tool_sha256=sha(Path(__file__).read_bytes().replace(b"\r\n",b"\n"))))
    print("sealed",len(files),"review files,",len(raw_files),"local raw file identities; geometry-complete",geometry_complete)

if __name__=="__main__":main()
