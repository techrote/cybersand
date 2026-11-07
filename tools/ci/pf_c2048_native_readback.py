#!/usr/bin/env python3
"""Independent strict C1024/C2048 capacity, authored-fixture and CYPS readback."""
import csv
import json
import sys
from pathlib import Path

def require(ok, why):
    if not ok:
        raise AssertionError(why)

root = Path(sys.argv[1])
cases = {}
for line in (root/"cases.tsv").read_text().splitlines():
    name, requested = line.split("\t")
    with (root/"rows"/(name+".csv")).open(newline="") as f:
        rows = list(csv.DictReader(f))
    capacity = int(name.split("_")[0][1:])
    require(bool(rows) and rows[0]["phase"]=="initial", f"{name}: initial row absent")
    require(all(int(r["capacity"])==capacity for r in rows), f"{name}: wrong applied capacity")
    require(all(int(r["live"])<=capacity for r in rows), f"{name}: overflow beyond capacity")
    require(all(r["ledger_closes"]=="1" for r in rows if r["world_failed"]=="0"),
            f"{name}: gas conservation ledger open")
    cases[name]=(int(requested),rows)

def get(cap,scene,v,w,rooms):
    name=f"C{cap}_{scene}_v{v}_w{w}_n{rooms}"
    require(name in cases, f"case missing: {name}")
    return cases[name][1]

for cap in (1024,2048):
    exact=get(cap,"isolated",0,1,cap)
    require(int(exact[0]["initial_census"])==cap and exact[-1]["world_failed"]=="0"
            and int(exact[-1]["live"])==cap, f"C{cap} exact-limit failure")
    excess=get(cap,"isolated",0,1,cap+1)
    require(int(excess[0]["initial_census"])==cap+1 and excess[-1]["world_failed"]=="1"
            and "capacity exhausted" in excess[-1]["exception"], f"C{cap}+1 did not quarantine")
dynamic=get(2048,"dynamic",0,1,2049)
require(len(dynamic)>2 and dynamic[1]["world_failed"]=="0"
        and dynamic[2]["world_failed"]=="1", "2049 split boundary not enforced")
for volume,expected in ((16384,1),(16385,0)):
    require(int(get(2048,"atmosphere",0,1,volume)[0]["initial_census"])==expected,
            "atmospheric threshold changed")
require(int(get(2048,"default",0,1,1025)[0]["initial_census"])==1175,
        "1175-pocket default demo incomplete")
require(get(1024,"default",0,1,1025)[-1]["world_failed"]=="1",
        "legacy default-demo C1024 refusal missing")
for v,w in ((0,1),(1,4),(2,1)):
    require(get(2048,"default",v,w,1025)[-1]["world_failed"]=="0",
            f"default demo C2048 v{v} workers{w} failed")
parity_fields=("live","region_volume","max_live_id","next_id","topology_rev",
               "gas_created","gas_absorbed","gas_vented","gas_collapsed",
               "gas_live_amount","creations","merges","splits","vents","collapses",
               "water_quantity","gas_digest","history_digest")
compared=0
for v in (0,1,2):
    a=get(1024,"isolated",v,1,512)
    b=get(2048,"isolated",v,1,512)
    require(len(a)==len(b), "under-limit duration mismatch")
    for i,(ra,rb) in enumerate(zip(a,b)):
        for f in parity_fields:
            require(ra[f]==rb[f], f"C1024/C2048 physical mismatch v{v} tick{i}: {f}")
        compared+=1
for scene, variants in (("my-canvas",((2,1),)),("bench-canvas",((0,1),(1,4),(2,1)))):
    for v,w in variants:
        require(get(2048,scene,v,w,0)[-1]["world_failed"]=="0",
                f"C2048 {scene} v{v} w{w} failed")
old=get(1024,"stress-canvas",2,1,0)
new=get(2048,"stress-canvas",2,1,0)
require(old[-1]["world_failed"]=="1" and "capacity exhausted" in old[-1]["exception"],
        "Old authored stress capacity failure was not reproduced")
require(110<=int(old[-1]["tick"])<=150, "Legacy failure tick not near expected tick125")
require(len(new)==901 and new[-1]["world_failed"]=="0" and int(new[-1]["tick"])==900,
        "C2048 did not complete full 900-tick stress")
peak=max(int(r["live"]) for r in new)
require(1024<peak<=2048, "C2048 never exercised greater than 1024 live compartments")
for row in old:
    if row["world_failed"]=="1":
        break
    other=new[int(row["tick"])]
    for f in parity_fields:
        require(row[f]==other[f], f"pre-limit stress parity mismatch tick{row['tick']} {f}")
    compared+=1
for v,w,ticks in ((0,1,300),(1,4,300),(2,4,120)):
    rows=get(2048,"stress-canvas",v,w,0)
    require(len(rows)==ticks+1 and rows[-1]["world_failed"]=="0",
            f"C2048 stress v{v},w{w}: requested {ticks} ticks not completed")
# Worker participation is an actual native TickStats counter, not a requested configuration.
# Four configured workers may legitimately execute with fewer participants in a
# particular dispatch; require actual parallel participation over the stress run.
def observed(cap,scene,variant,workers,rooms):
    rows=get(cap,scene,variant,workers,rooms)
    counts=[int(row["worker_threads_observed"]) for row in rows
            if row["world_failed"]=="0"]
    require(all(0<=n<=workers for n in counts),
            f"C{cap}/{scene} v{variant} worker participation exceeds configured count")
    return max(counts,default=0)

worker_participation={
    "C2048_stress_reference_w1_peak":observed(2048,"stress-canvas",0,1,0),
    "C2048_stress_cached_w4_peak":observed(2048,"stress-canvas",1,4,0),
    "C2048_stress_cached_dormant_w4_peak":observed(2048,"stress-canvas",2,4,0),
    "C2048_default_cached_w4_peak":observed(2048,"default",1,4,1025),
}
require(worker_participation["C2048_stress_reference_w1_peak"]==1,
        "one-worker native stress did not record actual participation")
require(max(worker_participation[k] for k in (
    "C2048_stress_cached_w4_peak","C2048_stress_cached_dormant_w4_peak"))>=2,
        "four-worker native stress never engaged multiple distinct native workers")
report={"schema":"pf-c2048-native-production-v1",
        "exact_source":(root/"source.txt").read_text().strip(),
        "cases":len(cases),"parity_rows_compared":compared,
        "worker_participation":worker_participation,
        "c1024_stress_failure_tick":int(old[-1]["tick"]),
        "c1024_stress_error":old[-1]["exception"],
        "c2048_peak":peak,"c2048_end_live":int(new[-1]["live"]),
        "c2048_complete_ticks":900,
        "limitations":"this matrix captures actual participating native worker threads per tick; live Rapier actor stress separately required"}
(root/"readback.json").write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
print("PF_C2048_AUTHORED_NATIVE_PASS",json.dumps(report,sort_keys=True))
