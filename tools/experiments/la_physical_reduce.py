#!/usr/bin/env python3
"""Independent CYPS2 tuple extraction, double geometry and physical accounting.

The trailing native ledgers are retained as an opaque authenticated tail; this
does not claim a complete persistence decoder or a granular kinetic model.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]


def sha(data): return hashlib.sha256(data).hexdigest()

def local_path(value):
    if value.startswith("/mnt/c/") and __import__("os").name=="nt": return Path("C:/"+value[7:])
    return Path(value)


def tuples(path):
    raw=path.read_bytes()
    if sha(raw[:-32])!=raw[-32:].hex(): raise ValueError("CYPS checksum mismatch")
    offset=0
    def take(fmt):
        nonlocal offset
        layout=struct.Struct("<"+fmt);values=layout.unpack_from(raw,offset);offset+=layout.size
        return values[0] if len(values)==1 else values
    magic,version=take("II")
    if magic!=0x53505943 or version!=2: raise ValueError("Only authenticated CYPS2 is admitted")
    side,activity,core,radius=take("iiii")
    if side<1 or side>1024: raise ValueError("Invalid chunk side")
    take("I");ambient=take("h")
    take("BiBhBBIBBB")
    for _ in range(2):
        length=take("I")
        if length>(len(raw)-offset-32)//4: raise ValueError("Truncated policy envelope")
        offset+=4*length
    tick,completed=take("QQ");take("BQB")
    for _ in range(2):
        present=take("B")
        if present: take("qqqq")
    events=take("I");offset+=events*21
    chunks=take("I")
    if chunks>100000: raise ValueError("Unbounded chunk inventory")
    counts=Counter();hist=Counter();water=0;sum_y=Counter()
    for _ in range(chunks):
        cx,cy=take("qq");flags=take("B")
        if flags & ~3: raise ValueError("Unexpected CYPS2 sidecar")
        blocks=take("I");offset+=blocks*13
        cells=memoryview(raw)[offset:offset+side*side*6];offset+=side*side*6
        temperatures=None
        if flags&1:
            temperatures=struct.unpack_from("<"+"h"*(side*side),raw,offset);offset+=side*side*2
        if flags&2: offset+=side*side*8
        for index,(material,a,b,epoch) in enumerate(struct.iter_unpack("<HHBB",cells)):
            if material==0: continue
            temp=temperatures[index] if temperatures is not None else ambient
            counts[material]+=1;hist[(material,a,b,temp)]+=1
            sum_y[material]+=cy*side+index//side
            if material==3:water+=a
    if offset>len(raw)-32: raise ValueError("Truncated CYPS payload")
    canonical=[[list(k),v] for k,v in sorted(hist.items())]
    return dict(sha256=sha(raw),version=version,tick=tick,completed_tick=completed,chunks=chunks,
                material_counts=dict(sorted(counts.items())),tuple_multiset=canonical,
                tuple_multiset_sha256=sha(json.dumps(canonical,separators=(",",":")).encode()),
                water_quantity=water,sum_y=dict(sorted(sum_y.items())),
                unparsed_ledger_tail_bytes=len(raw)-32-offset,unparsed_ledger_tail_sha256=sha(raw[offset:-32]))


def clip(poly,axis,bound,sign):
    if not poly:return []
    result=[];previous=poly[-1];old=sign*(previous[axis]-bound)
    for point in poly:
        new=sign*(point[axis]-bound)
        if (old>=0)!=(new>=0):
            t=old/(old-new);result.append(tuple(a+(b-a)*t for a,b in zip(previous,point)))
        if new>=0:result.append(point)
        previous,old=point,new
    return result


def overlap(poly,x,y):
    for axis,bound,sign in [(0,x,1),(0,x+1,-1),(1,y,1),(1,y+1,-1)]:poly=clip(poly,axis,bound,sign)
    relative=[(p[0]-x,p[1]-y) for p in poly]
    if len(relative)<3:return 0.0
    return abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(relative,relative[1:]+relative[:1])))*0.5


def geometry(observation,rectangles):
    if observation.get("outside"):return dict(outside=True)
    ox,oy=observation["origin"];width,height=observation["size"]
    cells=[]
    for material,count in observation["material_runs"]:cells.extend([material]*count)
    if len(cells)!=width*height:raise ValueError("Incomplete material ROI")
    xx,xy,yx,yy,tx,ty=observation["pose"]
    areas=Counter();centres=Counter()
    for rect in rectangles:
        cx,cy=rect["center"];w,h=rect["size"]
        corners=[(cx-w/2,cy-h/2),(cx+w/2,cy-h/2),(cx+w/2,cy+h/2),(cx-w/2,cy+h/2)]
        poly=[(tx+xx*x+yx*y,ty+xy*x+yy*y) for x,y in corners]
        for y in range(max(oy,math.floor(min(p[1] for p in poly))),min(oy+height,math.ceil(max(p[1] for p in poly)))):
            for x in range(max(ox,math.floor(min(p[0] for p in poly))),min(ox+width,math.ceil(max(p[0] for p in poly)))):
                material=cells[(y-oy)*width+x-ox]
                if not material:continue
                a=overlap(poly,x,y)
                if a>0:areas[material]+=a
                dx=x+.5-tx;dy=y+.5-ty
                # Actual float basis need not be exactly orthonormal; invert it.
                determinant=xx*yy-xy*yx
                lx=(yy*dx-yx*dy)/determinant;ly=(-xy*dx+xx*dy)/determinant
                if abs(lx-cx)<w/2 and abs(ly-cy)<h/2:centres[material]+=1
    return dict(area_by_material=dict(areas),cell_centres_inside=dict(centres),outside=False)


def report(path):
    d=json.loads(path.read_text(encoding="utf-8"));steps=d["steps"]
    if d["failures"]:raise ValueError("Fixture failed: "+str(d["failures"]))
    initial=tuples(local_path(d["initial_payload"]["path"]))
    final=tuples(local_path(d["final_payload"]["path"]))
    shape=[a["geometry"] for a in d["authored"]]
    first_geometry=[geometry(g,r) for g,r in zip(d["initial_geometry"],shape)]
    snapshots=[];energy=[];workers=[];times=[];readback=0;passive_positive=0;scales=[]
    for s in steps:
        workers.append(s["statistics"]["values"]["worker_threads_observed"])
        times.append(s["simulation_us"])
        if s["geometry"]:snapshots.append(dict(step=s["step"],bodies=[geometry(g,r) for g,r in zip(s["geometry"],shape)]))
        row=[]
        for index,action in enumerate(s["application"]["bodies"]):
            if "refusal" in action:continue
            live=s["live_before_application"][index];after=s["after_application"][index]
            v=list(live["velocity"]);J=action["impulse"];correction=action["correction"]
            clipped=v[:]
            for axis in [0,1]:
                if clipped[axis]*correction[axis]<0:clipped[axis]=0
            predicted=[clipped[a]+J[a]/live["mass"] for a in [0,1]]
            predicted_w=live["omega"]+action["torque"]/live["inertia"]
            readback=max(readback,math.dist(predicted,after["velocity"]),abs(predicted_w-after["omega"]))
            passive_positive=max(passive_positive,action.get("passive_energy_accepted",0))
            scales.append(action.get("passive_scale",1))
            row.append(dict(body=index,response_delta_kinetic=after["kinetic"]-live["kinetic"],
                            correction_delta_potential=after["potential"]-live["potential"],
                            correction_clipping_loss=.5*live["mass"]*(sum(x*x for x in clipped)-sum(x*x for x in v)),
                            applied_impulse=J,applied_torque=action["torque"],
                            passive_unscaled=action.get("passive_energy_unscaled"),passive_accepted=action.get("passive_energy_accepted")))
        energy.append(dict(step=s["step"],bodies=row))
    if readback>1e-5:raise ValueError("Independent actual RID reconstruction failed")
    no_external_cells=not d["case"].get("stream") and d["case"].get("distributed")!="stream" and "remove_support_step" not in d["case"]
    inventory_equal=initial["tuple_multiset"]==final["tuple_multiset"]
    if no_external_cells and not inventory_equal:raise ValueError("Material tuple multiset changed in closed fixture")
    tail=steps[-120:];stability=[]
    for index in range(len(shape)):
        states=[s["after_step"][index] for s in tail]
        positions=[s["pose"][4:] for s in states]
        angles=[math.atan2(s["pose"][1],s["pose"][0]) for s in states]
        stability.append(dict(span_x=max(p[0] for p in positions)-min(p[0] for p in positions),
                              span_y=max(p[1] for p in positions)-min(p[1] for p in positions),
                              rotation_span=max(angles)-min(angles),terminal_speed=math.hypot(*states[-1]["velocity"])))
    inserted=Counter()
    for step in steps:inserted.update({int(k):v for k,v in step.get("inserted_materials",{}).items()})
    removed=Counter()
    if "removal_before" in d:
        a=tuples(local_path(d["removal_before"]["path"]));b=tuples(local_path(d["removal_after"]["path"]))
        removed=Counter({int(k):v for k,v in a["material_counts"].items()})
        removed.subtract({int(k):v for k,v in b["material_counts"].items()})
    counts=Counter({int(k):v for k,v in initial["material_counts"].items()});counts.update(inserted);counts.subtract(removed)
    assert +counts==Counter({int(k):v for k,v in final["material_counts"].items()}),"material source/removal ledger does not close"
    return dict(id=d["id"],source=d["source"],arm=d["arm"],case=d["case"],steps=len(steps),
                requested_workers=d["requested_workers"],actual_workers=sorted(set(workers)),
                initial=initial,final=final,closed_tuple_multiset_equal=inventory_equal if no_external_cells else None,
                material_source_ledger_closes=True,inserted_materials=dict(inserted),removed_materials=dict(removed),
                initial_geometry=first_geometry,geometry_observations=snapshots,stability=stability,
                max_RID_readback_error=readback,max_analytic_passive_energy=passive_positive,
                minimum_passive_scale=min(scales,default=1),timings=dict(mean_simulation_us=sum(times)/len(times),
                max_simulation_us=max(times),total_control_us=d["control_application_us"],
                total_control_attempts=d["control_application_attempts"]),energy=energy,
                report_path=str(path),report_sha256=sha(path.read_bytes()))


def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("paths",nargs="+",type=Path);parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args();results=[]
    for path in args.paths:
        for file in sorted(path.rglob("*.json")) if path.is_dir() else [path]:
            if "initial_payload" not in json.loads(file.read_text(encoding="utf-8")):continue
            results.append(report(file));print("reduced",file.name,flush=True)
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(dict(results=results),separators=(",",":"))+"\n",encoding="utf-8")


if __name__=="__main__":main()
