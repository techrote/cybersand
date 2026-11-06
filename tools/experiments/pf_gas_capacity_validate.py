#!/usr/bin/env python3
"""Independent comparisons of raw PF capacity experiment records, no golden regeneration.

Use only a completed source-matched, source-hashed native experiment directory.
Exits nonzero on missing cases, failed parity, incorrect boundary refusals or corrupt CSV.
Expected capacity-exhaustion rows are quarantined and excluded from physical parity.
"""
import argparse
import csv
import hashlib
import json
import re
import statistics
from collections import defaultdict
from pathlib import Path

IDENTITY = (
    "live region_volume max_live_id next_id topology_rev gas_created "
    "gas_absorbed gas_vented gas_collapsed gas_live_amount creations merges "
    "splits vents collapses water_quantity physical_hash gas_digest history_digest"
).split()
VARIANT = (
    "live region_volume max_live_id next_id topology_rev gas_created "
    "gas_absorbed gas_vented gas_collapsed gas_live_amount creations merges "
    "splits vents collapses water_quantity pressure_variant_projection "
    "gas_digest history_digest"
).split()
KEY = re.compile(r"C(1024|2048|4096)_(.+)_v([012])_w([14])_n([0-9]+)\.csv$")
CHECKPOINTS = {0,1,10,30,60,120,300}
def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for buf in iter(lambda:f.read(1<<20),b""):h.update(buf)
    return h.hexdigest()
def percent(values,p):
    if not values:return None
    vals=sorted(values)
    return vals[min(len(vals)-1, (p*len(vals)+99)//100-1)]
def main(root:Path)->int:
    errors=[];warnings=[];cases={};cmp_rows=0;cmp_pairs=0;variant_rows=0;worker_rows=0;cyps_pairs=0
    for path in sorted((root/"rows").glob("C*.csv")):
        m=KEY.fullmatch(path.name)
        if not m:
            errors.append("invalid case name "+str(path));continue
        cap,scene,variant,workers,rooms=m.groups()
        case=(int(cap),scene,int(variant),int(workers),int(rooms))
        with path.open(newline="") as stream:
            records=list(csv.DictReader(stream))
        if not records:
            errors.append(f"empty raw observations: {case}");continue
        if any(r.get("capacity")!=cap for r in records):
            errors.append(f"wrong compiled capacity in raw data: {case}")
        cases[case]=records
        if records[0]["phase"]!="initial" or records[0]["tick"]!="0":
            errors.append(f"initial phase absent: {case}")
        for r in records:
            if r["world_failed"]!="1" and r["ledger_closes"]!="1":
                errors.append(f"ledger does not close {case} at tick {r['tick']}")
            if int(r["live"])>int(cap):
                errors.append(f"compartments above capacity: {case} at tick {r['tick']}")
    def initial(cap,scene,variant,worker,rooms):
        return cases.get((cap,scene,variant,worker,rooms))
    for cap in (1024,2048,4096):
        for rooms in (cap,cap+1):
            v=initial(cap,"isolated",0,1,rooms)
            if v is None:
                errors.append(f"boundary scenario missing C{cap} / {rooms}");continue
            if int(v[0]["initial_census"])!=rooms:
                errors.append(f"census wrong C{cap} / {rooms}")
            if rooms==cap and (v[-1]["world_failed"]=="1" or int(v[-1]["live"])!=rooms):
                errors.append(f"ceiling case failed C{cap} / {rooms}")
            if rooms==cap+1 and (
                len(v)<2 or v[1]["world_failed"]!="1"
                or "capacity exhausted" not in v[1]["exception"]):
                errors.append(f"over-capacity case not quarantined C{cap} / {rooms}")
        v=initial(cap,"dynamic",0,1,cap+1)
        if v is None:
            errors.append(f"dynamic split absent C{cap}")
        elif len(v)<3 or v[1]["world_failed"]!="0" or v[2]["world_failed"]!="1":
            errors.append(f"dynamic refusal missing after first completed tick C{cap}")
    for size,expected in ((16384,1),(16385,0)):
        for cap in (1024,2048,4096):
            v=initial(cap,"atmosphere",0,1,size)
            if not v or int(v[0]["initial_census"])!=expected:
                errors.append(f"atmosphere threshold changed C{cap}/{size}")
    for cap in (1024,2048,4096):
        v=initial(cap,"unseeded",0,1,1025)
        if not v or int(v[0]["initial_census"])!=0 or any(int(r["live"])!=0 for r in v):
            errors.append(f"unseeded pocket control failed C{cap}")
    for cap in (1024,2048,4096):
        v=initial(cap,"default",0,1,1025)
        if not v: errors.append(f"default native demo missing C{cap}");continue
        if cap==1024:
            if v[1]["world_failed"]!="1" or int(v[0]["initial_census"])!=1025:
                errors.append("old demo expected refusal missing")
        else:
            if int(v[0]["initial_census"])!=1175 or v[-1]["world_failed"]!="0":
                errors.append(f"raised default count/refusal unexpectedly changed C{cap}")
    def compare(a,b,fields,label):
        nonlocal cmp_rows
        if not a or not b:
            errors.append(f"missing comparable histories {label}");return 0
        count=0
        for i,(x,y) in enumerate(zip(a,b)):
            if x["world_failed"]=="1" or y["world_failed"]=="1":break
            for f in fields:
                if x.get(f)!=y.get(f):
                    errors.append(f"{label} tick {i} differs in {f}: {x.get(f)} / {y.get(f)}")
            count+=1
        if len(a)!=len(b):warnings.append(f"different time horizon {label}")
        cmp_rows+=count
        return count
    for (cap,scene,v,w,rooms),rows in sorted(cases.items()):
        if cap!=1024:continue
        for higher in (2048,4096):
            dst=cases.get((higher,scene,v,w,rooms))
            if dst:
                compare(rows,dst,IDENTITY,f"C1024 -> C{higher} {scene}/v{v}/w{w}/n{rooms}")
                cmp_pairs+=1
    # Cross-family equivalence must use its explicitly normalised physical projection:
    # original physical hashes/CYPS bind the immutable selected pressure implementation.
    for (cap,scene,variant,w,rooms),rows in sorted(cases.items()):
        if variant!=0 or w!=1:continue
        for vv in (1,2):
            other=cases.get((cap,scene,vv,1,rooms))
            if other:
                checked=min(len(rows),len(other))
                before=cmp_rows
                compare(rows[:checked],other[:checked],VARIANT,
                        f"normalised reference-v{vv} C{cap} {scene}/w1")
                variant_rows+=cmp_rows-before
        for vv in (0,1,2):
            a=cases.get((cap,scene,vv,1,rooms))
            b=cases.get((cap,scene,vv,4,rooms))
            if a and b:
                checked=min(len(a),len(b))
                before=cmp_rows
                compare(a[:checked],b[:checked],VARIANT,
                        f"serial-vs-phased C{cap} {scene}/v{vv}")
                worker_rows+=cmp_rows-before
    # Compare every sampled canonical CYPS payload between ceilings for identical
    # exact-authority histories; no textual normalisation of binary files.
    saves=root/"saves"
    for (cap,scene,variant,w,rooms),rows in sorted(cases.items()):
        if cap!=1024:continue
        src=f"C1024_{scene}_v{variant}_w{w}_n{rooms}"
        for higher in (2048,4096):
            dest=f"C{higher}_{scene}_v{variant}_w{w}_n{rooms}"
            if (higher,scene,variant,w,rooms) not in cases:continue
            for p in saves.glob(src+"-t*.cyps"):
                other=saves / p.name.replace(src,dest,1)
                if not other.exists():
                    errors.append(f"missing higher save {other.name}");continue
                if digest(p)!=digest(other):
                    errors.append(f"CYPS byte identity failure: {p.name} vs {other.name}")
                cyps_pairs+=1
    source=(root/"source-sha.txt").read_text().strip()
    metrics=[]
    for (cap,scene,v,w,rooms),rows in sorted(cases.items()):
        completed=[r for r in rows if r["phase"]!="initial" and r["world_failed"]!="1"]
        ticks=[int(r["native_tick_ns"]) for r in completed]
        metrics.append({
            "capacity":cap,"scene":scene,"variant":v,"workers":w,"rooms":rooms,
            "initial_census":int(rows[0]["initial_census"]),
            "peak_live":max(int(r["live"]) for r in rows),
            "last_completed_tick":int(completed[-1]["tick"]) if completed else 0,
            "failed_world":rows[-1]["world_failed"]=="1",
            "refusal":rows[-1]["exception"],
            "tick_samples":len(ticks),
            "mean_tick_ms":statistics.mean(ticks)/1e6 if ticks else None,
            "p95_tick_ms":percent(ticks,95)/1e6 if ticks else None,
            "mean_gas_ms":statistics.mean(int(r["gas_ns"]) for r in completed)/1e6 if completed else None,
            "mean_head_ms":statistics.mean(int(r["head_ns"]) for r in completed)/1e6 if completed else None,
            "topology_reserved_bytes":int(rows[0]["topology_reserved_bytes"]),
            "initial_gas_cache_reserved_bytes":int(rows[0]["gas_cache_reserved_bytes"]),
            "initial_derived_reserved_bytes":int(rows[0]["derived_reserved_bytes"]),
            "initial_vmrss_kib":int(rows[0]["vmrss_kib"]),
            "peak_vmrss_kib":max(int(r["vmrss_kib"]) for r in rows),
        })
    result={"schema":"pf-native-gas-capacity-qualification-v1","source_sha":source,
            "compiled_capacities":[1024,2048,4096],"case_count":len(cases),
            "cross_capacity_case_pairs":cmp_pairs,"compared_rows_total":cmp_rows,
            "normalised_variant_rows":variant_rows,"serial_phased_rows":worker_rows,
            "identical_cyps_save_pairs":cyps_pairs,"errors":errors,"warnings":warnings,
            "measurements":metrics}
    (root/"qualification.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    lines=["# Native PressureFlow capacity experiment raw evidence","",
           f"Source: "+source,"",
           f"Cases: {len(cases)}; paired below-old-limit cases: {cmp_pairs};",
           f"full matched authoritative rows: {cmp_rows}; normalised variant rows: {variant_rows};",
           f"serial/phased rows: {worker_rows}; byte-identical sampled CYPS pairs: {cyps_pairs}.","",
           f"Violations: {len(errors)}; warnings: {len(warnings)}.","",
           "Values are observations from a single hosted execution, not multi-run statistical confidence intervals."]
    lines += ["", "## Errors"] + (["- "+s for s in errors] or ["None detected."])
    lines += ["", "## Warnings"] + (["- "+s for s in warnings] or ["None."])
    (root/"qualification.md").write_text("\n".join(lines)+"\n")
    print(json.dumps({k:result[k] for k in ("source_sha","case_count","cross_capacity_case_pairs",
          "compared_rows_total","normalised_variant_rows","serial_phased_rows",
          "identical_cyps_save_pairs")},sort_keys=True))
    if errors:
        print("FAIL",len(errors),"first violations:",errors[:12])
    return int(bool(errors))
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("evidence_directory",type=Path)
    args=p.parse_args()
    raise SystemExit(main(args.evidence_directory))
