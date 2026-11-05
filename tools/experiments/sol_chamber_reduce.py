#!/usr/bin/env python3
"""Independent full-square/SAT, actual-mask and CYPS chamber evidence audit."""
import argparse
from collections import Counter
import importlib.util
import json
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("physical_reduce",Path(__file__).with_name("la_physical_reduce.py"))
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)

def decode(runs,size):
    values=[]
    for value,count in runs:
        assert isinstance(count,int) and count>0 and len(values)+count<=size,"Unbounded RLE"
        values.extend([value]*count)
    assert len(values)==size,"Incomplete census"
    return values

def payload(meta):
    if meta is None:return None
    result=r.tuples(r.local_path(meta["path"]))
    assert result["sha256"]==meta["sha256"] and result["bytes"]==meta["bytes"]
    return result

def geometry(capture,rectangles):
    xx,xy,yx,yy,tx,ty=struct.unpack("<6d",bytes.fromhex(capture["state"]["pose_f64le"]))
    assert all(math.isfinite(v) for v in [xx,xy,yx,yy,tx,ty])
    ox,oy=capture["origin"];width,height=capture["size"];size=width*height
    cells=decode(capture["material_runs"],size);mask=decode(capture["mask_runs"],size)
    assert all(0<=m<=6 for m in mask),"Foreign mask ownership"
    areas=Counter();depths=Counter();hard=[];polygons=[];centres=set();outside=False
    for cx,cy,w,h in rectangles:
        poly=[(tx+xx*x+yx*y,ty+xy*x+yy*y) for x,y in [(cx-w/2,cy-h/2),(cx+w/2,cy-h/2),(cx+w/2,cy+h/2),(cx-w/2,cy+h/2)]]
        polygons.append(poly)
        if any(x<ox or y<oy or x>ox+width or y>oy+height for x,y in poly):outside=True
        for y in range(max(oy,math.floor(min(v[1] for v in poly))),min(oy+height,math.ceil(max(v[1] for v in poly)))):
            for x in range(max(ox,math.floor(min(v[0] for v in poly))),min(ox+width,math.ceil(max(v[0] for v in poly)))):
                index=(y-oy)*width+x-ox;material=cells[index]
                if material:
                    area=r.overlap(poly,x,y)
                    if area>0:
                        areas[material]+=area;depths[material]=max(depths[material],r.proxy_depth(poly,x,y))
                        if material!=2 and area>1e-9:hard.append([x,y,material,area])
                determinant=xx*yy-xy*yx;dx=x+.5-tx;dy=y+.5-ty
                lx=(yy*dx-yx*dy)/determinant;ly=(-xy*dx+xx*dy)/determinant
                if abs(lx-cx)<w/2 and abs(ly-cy)<h/2:centres.add(index)
    own={index for index,value in enumerate(mask) if value}
    vacant=sum(cells[(y-oy)*width+x-ox]==0 and mask[(y-oy)*width+x-ox]==0 for y in range(61,101) for x in range(49,96))
    return dict(sand_area=areas[2],sand_max_depth=depths[2],area_by_material=dict(areas),max_depth_by_material=dict(depths),hard_exclusions=hard,
        exact_proxy_union=polygons,complete_in_fixed_roi=not outside,body_center_cells=len(centres),actual_mask_cells=len(own),
        centre_mask_symmetric_difference=len(own^centres),sand_cells_under_actual_mask=sum(cells[i]==2 for i in own),
        chamber_unmasked_empty_cells=vacant,roi_counts=dict(Counter(cells)),sand_roi_sum_y=sum(oy+i//width for i,m in enumerate(cells) if m==2),
        body_position=[tx,ty],body_basis_determinant=xx*yy-xy*yx)

def report(path,profile):
    raw=path.read_bytes();data=json.loads(raw)
    binary=bytes.fromhex(data["geometry_f64le"]);values=struct.unpack("<"+"d"*(len(binary)//8),binary)
    rectangles=[values[i:i+4] for i in range(0,len(values),4)];assert len(rectangles)==6
    initial=geometry(data["initial"],rectangles);final=geometry(data["final"],rectangles)
    initial_payload=payload(data["initial_payload"]);final_payload=payload(data["final_payload"])
    expected=profile["stored_sand_counts"]["open" if data["case"]["open"] else "closed"]
    assert initial_payload["material_counts"]=={1:178,2:expected},"Initial map differs from registration"
    assert initial["chamber_unmasked_empty_cells"]==(560 if data["case"]["open"] else 0),"Initial vacancy differs"
    valid_initial=initial["complete_in_fixed_roi"] and initial["sand_area"]<=1e-6 and initial["sand_max_depth"]<=2e-5 and not initial["hard_exclusions"]
    assert [s["step"] for s in data["steps"]]==list(range(len(data["steps"]))),"Step gap/reordering"
    steps=[];costs=Counter();arrival=0;maximum_area=0;maximum_depth=0;hard_steps=0;candidate_work=0.0;drive_work=0.0
    for step in data["steps"]:
        complete=[b["boundary"] for b in step["boundaries"]]==profile["boundaries"]
        measurements=[dict(boundary=b["boundary"],tick=b["native_tick"],revision=b["revision"],**geometry(b,rectangles)) for b in step["boundaries"]]
        for measure in measurements:
            maximum_area=max(maximum_area,measure["sand_area"]);maximum_depth=max(maximum_depth,measure["sand_max_depth"])
        hard_steps+=any(m["hard_exclusions"] for m in measurements)
        for key in ["preparation_us","native_tick_us","application_us","rapier_us","observer_us","export_us","elapsed_us"]:costs[key]+=int(step.get(key,0))
        if step.get("response",{}).get("valid"):
            assert step["response"]["response"]==data["mode"]
            assert step["response"]["session"]==step["sample"]["session"] and step["response"]["epoch"]==step["sample"]["epoch"]
            arrival+=sum(row["arrival_count"] for row in step["response"]["rows"])
        candidate_work+=step.get("candidate_kinetic_delta",0);drive_work+=step.get("force_endpoint_work_estimate",0)
        if "payload" in step:payload(step["payload"])
        steps.append(dict(step=step["step"],complete_boundaries=complete,terminal=step.get("terminal"),geometry=measurements))
    complete=len(steps)==profile["steps"] and all(s["complete_boundaries"] and not s["terminal"] for s in steps) and not data["failures"]
    conserved=final_payload is not None and initial_payload["material_counts"]==final_payload["material_counts"]
    return dict(id=data["id"],source=data["source"],mode=data["mode"],case=data["case"],requested_workers=data["requested_workers"],repeat=data["repeat"],raw_sha256=r.sha(raw),
        valid_initial_geometry=valid_initial,complete_episode=complete,initial=initial,final=final,steps=steps,
        material_count_conservation=conserved,initial_payload=initial_payload,final_payload=final_payload,
        maximum_observed_sand_area=maximum_area,maximum_observed_sand_depth=maximum_depth,hard_exclusion_steps=hard_steps,
        observed_arrivals=arrival if data["mode"]=="LA-SELECTIVE" else None,arrival_qualifier="Nonselective modes disable arrival-history instrumentation",
        candidate_kinetic_delta_sum=candidate_work,force_endpoint_work_estimate_sum=drive_work,cost_us=dict(costs),
        scope="Exact geometry surrogate; centre-mask and endpoint metrics do not certify continuous clearance, parcel routes or original SOL authority")

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("directory",type=Path);args=parser.parse_args()
    receipt=json.loads((args.directory/"receipt.json").read_text(encoding="utf-8"));profile=receipt["registration"];rows=[]
    for process in receipt["results"]:
        for item in process.get("reports",[]):
            path=ROOT/item["path"];assert r.sha(path.read_bytes())==item["sha256"]
            result=report(path,profile);target=path.with_suffix(".metrics.json")
            assert not target.exists(),"Preserve prior reduction";target.write_text(json.dumps(result)+"\n",encoding="utf-8")
            rows.append({key:value for key,value in result.items() if key not in ["steps","initial_payload","final_payload"]})
    summary=dict(registration=profile["id"],source=receipt["identity"]["source"],matrix=receipt["matrix"],episodes=rows,
        process_attempts=len(receipt["results"]),process_failures=sum(not row["clean"] for row in receipt["results"]))
    target=args.directory/"reduced.json";assert not target.exists();target.write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(reports=len(rows),valid_initial=sum(row["valid_initial_geometry"] for row in rows),complete=sum(row["complete_episode"] for row in rows),conserved=sum(row["material_count_conservation"] for row in rows),process_failures=summary["process_failures"])))

if __name__=="__main__":main()
