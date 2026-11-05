#!/usr/bin/env python3
"""Independent full-square/SAT, actual-mask and CYPS chamber evidence audit."""
import argparse
from collections import Counter
import importlib.util
import json
import math
from pathlib import Path
import struct
from itertools import product

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("physical_reduce",Path(__file__).with_name("la_physical_reduce.py"))
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
CACHE={}

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

def kinetic(state):
    vx,vy,w=struct.unpack("<3d",bytes.fromhex(state["velocity_omega_f64le"]))
    result=.5*state["mass"]*(vx*vx+vy*vy)+.5*state["inertia"]*w*w
    assert abs(result-state["kinetic"])<=max(1e-8,abs(result)*1e-13),"Kinetic display inconsistent with exact state"
    return result

def geometry(capture,rectangles):
    key=(capture["state"]["pose_f64le"],tuple(capture["origin"]),tuple(capture["size"]),tuple(map(tuple,capture["material_runs"])),tuple(map(tuple,capture["mask_runs"])),tuple(map(tuple,rectangles)))
    if key in CACHE:return CACHE[key]
    result=calculate_geometry(capture,rectangles)
    if len(CACHE)>=256:CACHE.clear()
    CACHE[key]=result;return result

def calculate_geometry(capture,rectangles):
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
        recorded_transform_proxy_union=polygons,complete_in_fixed_roi=not outside,body_center_cells=len(centres),actual_mask_cells=len(own),
        centre_mask_symmetric_difference=len(own^centres),sand_cells_under_actual_mask=sum(cells[i]==2 for i in own),
        chamber_unmasked_empty_cells=vacant,roi_counts=dict(Counter(cells)),sand_roi_sum_y=sum(oy+i//width for i,m in enumerate(cells) if m==2),
        body_position=[tx,ty],body_basis_determinant=xx*yy-xy*yx)

def report(path,profile):
    CACHE.clear()
    raw=path.read_bytes();data=json.loads(raw)
    binary=bytes.fromhex(data["geometry_f64le"]);values=struct.unpack("<"+"d"*(len(binary)//8),binary)
    rectangles=[values[i:i+4] for i in range(0,len(values),4)];assert len(rectangles)==6
    f32=lambda x:struct.unpack("<f",struct.pack("<f",x))[0]
    com=(f32(32+3293/130),f32(16+175/8))
    expected_rectangles=[(f32(x+w/2-com[0]),f32(y+h/2-com[1]),w,h) for x,y,w,h in profile["source_rectangles"]]
    assert rectangles==expected_rectangles,"Registered shape differs"
    initial_state=data["initial"]["state"]
    assert struct.unpack("<6d",bytes.fromhex(initial_state["pose_f64le"]))==(1,0,0,1,f32(com[0]+6),f32(com[1]+35)),"Initial pose differs"
    assert initial_state["mass"]==520 and abs(initial_state["inertia"]-f32(profile["nominal_inertia"]))<1e-9
    assert len(data["actual_shapes"])==6
    assert struct.unpack("<3d",bytes.fromhex(initial_state["velocity_omega_f64le"]))==(0,0,0),"Pristine motion differs"
    for shape,(cx,cy,w,h) in zip(data["actual_shapes"],expected_rectangles):
        assert tuple(map(f32,shape["transform"]))==(1,0,0,1,cx,cy) and tuple(shape["data"])==(w/2,h/2),"Actual Rapier shapes differ"
    initial=geometry(data["initial"],rectangles);final=geometry(data["final"],rectangles)
    initial_payload=payload(data["initial_payload"]);final_payload=payload(data["final_payload"])
    expected=profile["stored_sand_counts"]["open" if data["case"]["open"] else "closed"]
    assert initial_payload["material_counts"]=={1:178,2:expected},"Initial map differs from registration"
    assert initial["chamber_unmasked_empty_cells"]==(560 if data["case"]["open"] else 0),"Initial vacancy differs"
    valid_initial=initial["complete_in_fixed_roi"] and initial["sand_area"]<=1e-6 and initial["sand_max_depth"]<=2e-5 and not initial["hard_exclusions"]
    valid_initial=valid_initial and initial["body_center_cells"]==initial["actual_mask_cells"]==520 and initial["centre_mask_symmetric_difference"]==0
    assert [s["step"] for s in data["steps"]]==list(range(len(data["steps"]))),"Step gap/reordering"
    steps=[];costs=Counter();arrival=0;maximum_area=0;maximum_depth=0;hard_steps=0;candidate_work=0.0;drive_work=0.0
    counters=Counter();peaks=Counter();wrenches=Counter()
    for step in data["steps"]:
        complete=[b["boundary"] for b in step["boundaries"]]==profile["boundaries"]
        for capture in step["boundaries"]:
            assert capture["world_instance"]==data["initial"]["world_instance"] and capture["state"]["rid"]==data["initial"]["state"]["rid"],"Owner/body identity changed"
        if complete:
            assert [b["native_tick"] for b in step["boundaries"]]==[step["step"],step["step"],step["step"]+1,step["step"]+1,step["step"]+1],"Native clock misalignment"
        measurements=[dict(boundary=b["boundary"],tick=b["native_tick"],revision=b["revision"],**geometry(b,rectangles)) for b in step["boundaries"]]
        for measure in measurements:
            maximum_area=max(maximum_area,measure["sand_area"]);maximum_depth=max(maximum_depth,measure["sand_max_depth"])
        hard_steps+=any(m["hard_exclusions"] for m in measurements)
        for key in ["preparation_us","native_tick_us","application_us","rapier_us","observer_us","export_us","elapsed_us"]:costs[key]+=int(step.get(key,0))
        response=step.get("response",{});application=step.get("application",{})
        machine_valid=step.get("prepared")==True and step.get("ticked")==True and all(not b["failed"] for b in step["boundaries"]) and response.get("valid")==True and len(response.get("rows",[]))==1 and application.get("accepted")==True and len(application.get("bodies",[]))==1
        if response.get("valid") and len(response.get("rows",[]))==1:
            assert step["response"]["response"]==data["mode"]
            assert step["response"]["session"]==step["sample"]["session"] and step["response"]["epoch"]==step["sample"]["epoch"]
            assert step["response"]["sample_tick"]==step["step"],"Stale publication"
            assert all(row["sample"]==step["sample"]["states"][10] and row["instance_id"]==520 and row["generation"]==1 and row["proxy_count"]==6 for row in step["response"]["rows"])
            arrival+=sum(row["arrival_count"] for row in step["response"]["rows"])
            peaks["arrival_storage_bytes"]=max(peaks["arrival_storage_bytes"],step["response"]["arrival_storage_bytes"])
            for row in step["response"]["rows"]:
                for key in ["arrival_missing","arrival_misaligned","displaced","unresolved","passivity_rejected"]:counters[key]+=row[key]
                for index,axis in enumerate(["x","y"]):
                    for name in ["impulse","event_accepted","passive_impulse"]:wrenches[name+"_"+axis]+=row[name][index]
                    wrenches["legacy_residual_"+axis]+=row["impulse"][index]-row["event_accepted"][index]-row["passive_impulse"][index]
                for name in ["torque","event_torque","passive_torque"]:wrenches[name]+=row[name]
            for key in ["worker_threads_observed","resident_cell_bytes","resident_chunks","chunk_allocations","temperature_field_allocations"]:
                peaks[key]=max(peaks[key],step.get("statistics",{}).get("values",{}).get(key,0))
        live=step.get("live_before_application",step["boundaries"][2]["state"] if len(step["boundaries"])>=3 else None)
        response_delta=kinetic(step["after_application"])-kinetic(live) if live is not None and "after_application" in step else None
        if machine_valid:
            action=application["bodies"][0]
            assert action["instance_id"]==520 and action["sample"]==step["sample"]["states"][10] and application["snapshot"]==step["step"]+1
            vx,vy,w=struct.unpack("<3d",bytes.fromhex(live["velocity_omega_f64le"]));actual=struct.unpack("<3d",bytes.fromhex(step["after_application"]["velocity_omega_f64le"]))
            predicted=[(0 if v*corr<0 else v)+j/live["mass"] for v,corr,j in zip([vx,vy],action["correction"],action["impulse"])]
            assert math.hypot(predicted[0]-actual[0],predicted[1]-actual[1])<=1e-5 and abs(w+action["torque"]/live["inertia"]-actual[2])<=1e-5,"Independent RID application mismatch"
            if "after_external_drive" in step:
                delta=kinetic(step["after_external_drive"])-kinetic(step["before"])
                assert abs(delta-step["external_api_kinetic_delta"])<=max(1e-8,abs(delta)*1e-13)
        if response_delta is not None:candidate_work+=response_delta
        drive_work+=step.get("force_endpoint_work_estimate",0)
        if "payload" in step:payload(step["payload"])
        steps.append(dict(step=step["step"],complete_boundaries=complete,machine_valid=machine_valid,terminal=step.get("terminal"),geometry=measurements,recomputed_response_kinetic_delta=response_delta,original_reported_response_kinetic_delta=step.get("candidate_kinetic_delta")))
    complete=len(steps)==profile["steps"] and all(s["complete_boundaries"] and s["machine_valid"] and not s["terminal"] for s in steps) and not data["failures"]
    conserved=final_payload is not None and initial_payload["material_counts"]==final_payload["material_counts"]
    return dict(id=data["id"],source=data["source"],mode=data["mode"],case=data["case"],requested_workers=data["requested_workers"],repeat=data["repeat"],raw_sha256=r.sha(raw),
        valid_initial_geometry=valid_initial,complete_episode=complete,initial=initial,final=final,steps=steps,
        material_count_conservation=conserved,exact_tuple_multiset_conservation=final_payload is not None and initial_payload["tuple_multiset"]==final_payload["tuple_multiset"],initial_payload=initial_payload,final_payload=final_payload,
        maximum_observed_sand_area=maximum_area,maximum_observed_sand_depth=maximum_depth,hard_exclusion_steps=hard_steps,
        observed_arrivals=arrival if data["mode"]=="LA-SELECTIVE" else None,arrival_qualifier="Nonselective modes disable arrival-history instrumentation",
        candidate_kinetic_delta_sum=candidate_work,force_endpoint_work_estimate_sum=drive_work,cost_us=dict(costs),native_peaks=dict(peaks),native_counters=dict(counters),wrench_component_sums=dict(wrenches),
        scope="Original shape identity with float64 union of recorded quantized basis/local rectangles; not captured internal Rapier vertices. Tiny boundary results remain geometry conditional. Masks/endpoints do not certify continuous clearance, parcel routes or original SOL authority")

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("directory",type=Path);parser.add_argument("--output",type=Path);args=parser.parse_args()
    output=args.output or args.directory/"reduction";assert not output.exists(),"Preserve prior derivative";output.mkdir(parents=True)
    receipt=json.loads((args.directory/"receipt.json").read_text(encoding="utf-8"));profile=receipt["registration"];rows=[]
    for process in receipt["results"]:
        for item in process.get("reports",[]):
            path=ROOT/item["path"];assert r.sha(path.read_bytes())==item["sha256"]
            platform=path.resolve().relative_to(args.directory.resolve()).parts[0]
            result=report(path,profile);result.update(platform=platform,report_path=item["path"])
            target=output/(platform+"-"+result["id"]+".metrics.json")
            assert not target.exists(),"Preserve prior reduction";target.write_text(json.dumps(result)+"\n",encoding="utf-8")
            rows.append({key:value for key,value in result.items() if key not in ["steps","initial_payload","final_payload"]})
    matrix=receipt["matrix"]
    expected=set(product(matrix["platforms"],matrix["cases"],matrix["arms"],matrix["workers"],range(matrix["repeats"])))
    coordinates=Counter((row["platform"],row["case"]["id"],row["mode"],row["requested_workers"],row["repeat"]) for row in rows)
    assert set(coordinates)<=expected,"Unexpected matrix coordinates"
    missing=sorted(expected-set(coordinates));duplicates=[list(k) for k,v in coordinates.items() if v!=1]
    summary=dict(registration=profile["id"],source=receipt["identity"]["source"],matrix=matrix,episodes=rows,
        full_matrix_coverage=not missing and not duplicates,missing_coordinates=missing,duplicate_coordinates=duplicates,
        reducer_sha256=r.sha(Path(__file__).read_bytes().replace(b"\r\n",b"\n")),
        process_attempts=len(receipt["results"]),process_failures=sum(not row["clean"] for row in receipt["results"]))
    target=output/"reduced.json";assert not target.exists();target.write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(reports=len(rows),valid_initial=sum(row["valid_initial_geometry"] for row in rows),complete=sum(row["complete_episode"] for row in rows),conserved=sum(row["material_count_conservation"] for row in rows),process_failures=summary["process_failures"])))

if __name__=="__main__":main()
