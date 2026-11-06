#!/usr/bin/env python3
"""Independent binary64/32 decoding and rounded-state SOL energy audit."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct
from itertools import product

def sha(raw):return hashlib.sha256(raw).hexdigest()
def scalar(value):return struct.unpack("<d",bytes.fromhex(value["f64le"]))[0]
def vector(value):
    pair=(scalar(value["x"]),scalar(value["y"]))
    stored=struct.unpack("<ff",bytes.fromhex(value["f32le"]))
    assert all(a==b or (math.isnan(a) and math.isnan(b)) for a,b in zip(pair,stored)),"Vector encoding mismatch"
    return pair
def energy(v,w,m,inertia):return .5*m*(v[0]*v[0]+v[1]*v[1])+.5*inertia*w*w
def close_bits(a,b):return a==b or (math.isnan(a) and math.isnan(b))
def bit_record(value):
    if isinstance(value,dict):
        if "f64le" in value:return {"f64le":value["f64le"]}
        return {k:bit_record(v) for k,v in value.items()}
    if isinstance(value,list):return [bit_record(v) for v in value]
    return value

def same(a,b):return bit_record(a)==bit_record(b)
def f32(x):return struct.unpack("<f",struct.pack("<f",x))[0]

def coverage(data):
    expected=set(product([-10,-1,-.1,0,.1,1,10],[1e-6,1e-5,1e-4,1e-3,.01,.1],[0,3]))
    seen=set();offset=vector(data["shape"]["offset"])
    for record in data["records"]:
        if not record["name"].startswith("grid/"):continue
        _,w,d,x=record["name"].split("/");key=(float(w),float(d),float(x))
        assert key in expected and key not in seen,"Unregistered/duplicate grid input"
        seen.add(key);inp=record["input"]
        assert scalar(inp["omega"])==key[0] and vector(inp["velocity"])==(key[2],f32(-key[0]*offset[0]+key[1])),"Grid input differs from registered tuple"
        assert scalar(inp["mass"])==520 and scalar(inp["inertia"])==109907693/1560
    assert seen==expected,"Missing registered grid input"
    controls={"approaching","separating","stationary","sub-approach","finite-overflow"}
    controls.update(f"invalid-{field}/{value}" for field in ["mass","inertia"] for value in ["0.0","-1.0","inf","nan"])
    controls.update("invalid-omega/"+value for value in ["inf","nan"])
    controls.update("invalid-velocity/"+value for value in ["(inf, 0.0)","(nan, 0.0)"])
    controls.update("two-normal/"+value for value in ["-1.0","0.0","1.0"])
    assert {r["name"] for r in data["records"] if not r["name"].startswith("grid/") }==controls,"Missing registered control"
    assert set(data["ranges"])=={"baseline","scalar64"}
    for arm,records in data["ranges"].items():
        assert len(records)==2
        for record,requested in zip(records,[1e20,1e-30]):
            v=vector(record["velocity"]);observed=scalar(record["energy"])
            assert v==(f32(requested),0)
            if arm=="scalar64":assert observed==energy(v,0,520,109907693/1560) and math.isfinite(observed) and observed>0
            elif requested==1e20:assert observed==math.inf
            else:assert observed==0

def trace_coverage(record,arm):
    result=record["results"][arm];trace=record["traces"][arm+"-trace"];inp=record["input"]
    if result["outcome"]=="InvalidBody":assert not trace;return
    assert trace and trace[0]["stage"]=="initial" and sum(e["stage"]=="initial" for e in trace)==1,"Missing initial guard"
    first=trace[0]
    assert same(first["v"],inp["velocity"]) and same(first["w"],inp["omega"])
    if result["outcome"]=="InvalidEnergy":assert len(trace)==1 and not math.isfinite(scalar(first["energy"]));return
    steps=[];v=first["v"];w=first["w"];final=None;previous=(-1,-1)
    for index,event in enumerate(trace):
        assert same(event["m"],inp["mass"]) and same(event["I"],inp["inertia"])
        if index==0:continue
        assert event["stage"] in ["step","final"]
        if event["stage"]=="final":
            assert index==len(trace)-1 and final is None
            assert same(event["before_v"],first["v"]) and same(event["before_w"],first["w"])
            assert same(event["after_v"],v) and same(event["after_w"],w)
            assert same(event["before"],first["energy"]);final=event
        else:
            sweep=event["sweep"];group=event["group"]
            order=(sweep,group if sweep%2==0 else -group)
            assert 0<=sweep<4 and group>=0 and order>previous;previous=order
            assert same(event["before_v"],v) and same(event["before_w"],w),"Broken state chain"
            v=event["after_v"];w=event["after_w"];steps.append(event)
        passed=math.isfinite(scalar(event["after"])) and scalar(event["after"])<=scalar(event["before"])+scalar(event["tolerance"])
        if not passed:assert not result["accepted"] and index==len(trace)-1,"Missing terminal guard binding"
    if result["accepted"]:
        assert final is not None and len(steps)==len(result["impulses"])==result["approaching_count"],"Missing accepted guard/impulse coverage"
        assert same(result["velocity"],v) and same(result["omega"],w)
        assert same(result["energy_before"],first["energy"]) and same(result["energy_after"],final["after"]) and same(result["energy_tolerance"],final["tolerance"])
        for event,impulse in zip(steps,result["impulses"]):
            assert same(event["impulse"],impulse["impulse"]) and same(event["offset"],impulse["offset"]),"Trace/output impulse mismatch"
    else:
        terminal=trace[-1]
        assert result["outcome"]=="NonDissipativeResponse" and terminal["stage"] in ["step","final"]
        assert scalar(terminal["after"])>scalar(terminal["before"])+scalar(terminal["tolerance"]),"Missing actual refusal guard"

def audit(path):
    data=json.loads(path.read_text(encoding="utf-8"));assert not data["failures"]
    records=data["records"];assert len(records)==104 and len({r["name"] for r in records})==104
    assert sum(r["name"].startswith("grid/") for r in records)==84
    coverage(data)
    census={arm:Counter() for arm in ["baseline","scalar64"]};changed=[];false_refusals=[];old_false_accepts=[];genuine=[];guards=Counter();maximum_discrepancy=0
    for record in records:
        inp=record["input"];vector(inp["velocity"])
        for arm in census:
            trace_coverage(record,arm)
            result=record["results"][arm];assert result==record["results"][arm+"-trace"]
            if record["name"].startswith("grid/"):census[arm][result["outcome"]]+=1
            assert result["accepted"] or not result["impulses"],"Partial refusal"
            trace=record["traces"][arm+"-trace"]
            rejected=False
            for event in trace:
                m=scalar(event["m"]);inertia=scalar(event["I"]);stage=event["stage"]
                if stage=="initial":
                    expected=energy(vector(event["v"]),scalar(event["w"]),m,inertia)
                    observed=scalar(event["energy"])
                    if arm=="scalar64":assert close_bits(expected,observed),"Scalar initial energy differs"
                    guards[arm+"/initial"]+=1
                    continue
                before=energy(vector(event["before_v"]),scalar(event["before_w"]),m,inertia)
                after=energy(vector(event["after_v"]),scalar(event["after_w"]),m,inertia)
                tolerance=max(1e-8,before*1e-8)
                scalar_pass=math.isfinite(after) and after<=before+tolerance
                source_before=scalar(event["before"]);source_after=scalar(event["after"]);source_tolerance=scalar(event["tolerance"])
                source_pass=math.isfinite(source_after) and source_after<=source_before+source_tolerance
                if arm=="scalar64":
                    assert close_bits(before,source_before) and close_bits(after,source_after) and close_bits(tolerance,source_tolerance),"Scalar guard operand differs"
                    assert scalar_pass==source_pass
                else:
                    maximum_discrepancy=max(maximum_discrepancy,abs((source_after-source_before)-(after-before)))
                    if not source_pass and scalar_pass:false_refusals.append(dict(case=record["name"],stage=stage,source_delta=source_after-source_before,source_tolerance=source_tolerance,scalar_delta=after-before,scalar_tolerance=tolerance))
                    if source_pass and not scalar_pass:old_false_accepts.append(dict(case=record["name"],stage=stage,scalar_delta=after-before,scalar_tolerance=tolerance))
                guards[arm+"/"+stage]+=1
                if not scalar_pass:rejected=True
            if arm=="scalar64":
                if result["accepted"]:assert not rejected,"Candidate admitted energy violation"
                if result["outcome"]=="NonDissipativeResponse":assert rejected,"Candidate rejected without energy violation"
            if record["name"].startswith("invalid-"):assert result["outcome"]=="InvalidBody"
            if record["name"]=="finite-overflow":assert result["outcome"]=="InvalidEnergy"
            if record["name"] in ["stationary","separating","sub-approach"]:assert result["accepted"] and not result["impulses"]
            if record["name"]=="approaching":assert result["accepted"] and result["impulses"]
        left=[e for e in record["traces"]["baseline-trace"] if e["stage"]=="step"]
        right=[e for e in record["traces"]["scalar64-trace"] if e["stage"]=="step"]
        mechanical=["sweep","group","before_v","before_w","after_v","after_w","approach","lever","magnitude","impulse","torque","offset"]
        for a,b in zip(left,right):assert all(a[k]==b[k] for k in mechanical),"Mechanical prefix changed"
        if record["results"]["baseline"]["outcome"]!=record["results"]["scalar64"]["outcome"]:changed.append(record["name"])
        if record["name"].startswith("grid/") and scalar(inp["omega"])==-10 and float(record["name"].split("/")[2])==1e-5:
            assert record["results"]["scalar64"]["outcome"]=="NonDissipativeResponse";genuine.append(record["name"])
    assert len(genuine)==2,"Missing genuine rounded-state negative controls"
    return dict(source=data["source"],checks=data["checks"],record_count=len(records),grid_census={a:dict(c) for a,c in census.items()},changed_outcomes=changed,
        false_baseline_energy_refusals=false_refusals,baseline_accepted_guard_disagreements=old_false_accepts,genuine_refusals=genuine,
        evaluated_guards=dict(guards),maximum_baseline_delta_error=maximum_discrepancy,timings=data["timings"],result_sha256=sha(path.read_bytes()))

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("directory",type=Path);args=parser.parse_args()
    receipt=json.loads((args.directory/"receipt.json").read_text(encoding="utf-8"));assert all(r["clean"] for r in receipt["results"].values())
    results={}
    for platform,row in receipt["results"].items():
        path=args.directory/platform/"results.json";assert sha(path.read_bytes())==row["results_sha256"]
        results[platform]=audit(path);assert results[platform]["source"]==receipt["identity"]["source"]
    hosts=list(results)
    if len(hosts)>1:
        a=json.loads((args.directory/hosts[0]/"results.json").read_text(encoding="utf-8"));b=json.loads((args.directory/hosts[1]/"results.json").read_text(encoding="utf-8"))
        finite=lambda rows:[r for r in rows if not r["name"].startswith("invalid-")]
        assert bit_record(finite(a["records"]))==bit_record(finite(b["records"])),"Cross-host finite bit records differ"
    output=dict(registration="SOL-ENERGY-001",scope="Pure planner energy/cost only; no native/Rapier/SOL clearance",identity=receipt["identity"],results=results,cross_host_finite_bit_record_parity=True if len(hosts)>1 else None,
        decimal_format_qualification="Godot JSON diagnostic decimal formatting differs across hosts; exact scalar/vector bits are the comparison authority, not the redundant display values.",
        reducer_sha256=sha(Path(__file__).read_bytes().replace(b"\r\n",b"\n")))
    (args.directory/"reduced.json").write_text(json.dumps(output,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:{name:value for name,value in v.items() if name in ["grid_census","changed_outcomes","genuine_refusals","evaluated_guards"]} for k,v in results.items()},indent=2))

if __name__=="__main__":main()
