"""Authenticate copied-cell Scooper diagnostics; retain closed-side defects.

Observed coordinate sets are not persistent grain identities or continuous
paths. Passive energy excludes actuation, correction, events and gravity.
"""
import argparse
import collections
import hashlib
import json
import math
import struct
import subprocess
from pathlib import Path

from analyze_gcr_authored import (CODE, DEFINITION, DEFINITION_HASH,
    FROZEN_DEFINITION_SOURCE, EvidenceError, archived, bundle_path, digest,
    distribution, finite, integer, norm, read, require, same, source_scope,
    state_metrics, verify_source_map)

ROOT=Path(__file__).resolve().parents[2]
REG="GCR-CARRY-002"
PROTOCOL="docs/audits/gcr-carry-2026-11-04/protocol.json"
PLATFORMS=("windows","linux")
SELECTORS={"LA":"control","LA-EVENT-OFF":"off","LA-SELECTIVE":"selective"}
FLAGS=("primary_cavity","below_closed_deck","beyond_closed_stop","beyond_open_nose","above_rim")


def f32(value):
    return struct.unpack('f',struct.pack('f',value))[0]


def point_set(observation):
    return {tuple(g["cell"]) for g in observation["grains"]}


def counts(observation,frame):
    grains=observation["grains"]
    result={k:sum(g[frame][k] is True for g in grains) for k in FLAGS}
    result["inside_hull"]=sum(bool(g[frame]["inside_rectangles"]) for g in grains)
    result["classes"]=dict(collections.Counter(g[frame]["class"] for g in grains))
    return result


def persistent_rows(rows,flag):
    # The next completed owner boundary includes its preparation. This is an
    # aggregate far-side witness in two observed frames, not a claim that any
    # particular grain followed a continuous trajectory through the wall.
    return [i for i in range(len(rows)-1)
            if counts(rows[i]["after"],"current")[flag]>0
            and counts(rows[i+1]["after"],"sampled")[flag]>0
            and counts(rows[i+1]["after"],"current")[flag]>0]


def location(pose,local):
    x,y=local;c,s=math.cos(pose["rotation"]),math.sin(pose["rotation"])
    return [pose["position"][0]+c*x-s*y,pose["position"][1]+s*x+c*y]


def validate_observation(observation,rectangles,com,expected,expected_counts,water,sample,current):
    require(observation.get("failed") is False,"Observation refused")
    grains=observation.get("grains");require(isinstance(grains,list) and len(grains)==expected,"Complete copied grain set")
    require(len(point_set(observation))==expected,"Duplicate grain coordinate")
    require(set(map(tuple,observation["points"]))==point_set(observation),"Coordinate and classification sets differ")
    require(observation["observed_count"]==expected,"Observed grain count differs")
    x,y,w,h=observation["roi"]
    require(all(integer(v) for v in (x,y,w,h)) and w==h==128 and 0<=x<=896 and 0<=y<=384,"ROI capacity/bounds")
    roi_count=sum(x<=g["cell"][0]<x+w and y<=g["cell"][1]<y+h for g in grains)
    require(roi_count==observation["roi_count"],"Measured ROI set/count mismatch")
    if observation["coverage"]=="whole-fixture":
        require(observation["outside_roi_count"]==expected-roi_count,"Whole-fixture outside count mismatch")
        require(observation["global_counts"]==expected_counts and observation["global_water_mass"]==water,"Exact global quantities")
    else:
        require(observation["coverage"]=="bounded-roi" and observation["outside_roi_count"] is None,"Unmeasured outside count must remain null")
        require(observation["global_counts"] is None and observation["global_water_mass"] is None and roi_count==expected,"ROI-only coverage/quantity schema")
    ambiguities=0
    for grain in grains:
        require(len(grain["cell"])==2 and all(integer(v) for v in grain["cell"]) and 0<=grain["cell"][0]<1024 and 0<=grain["cell"][1]<512,"Stored cell bounds")
        require(integer(grain["native_mask_proxy"]) and 0<=grain["native_mask_proxy"]<=6,"Native mask proxy")
        for frame,pose in (("sampled",sample),("current",current)):
            q=grain[frame];local=q["local"];raw=q["authored_local"]
            require(same(raw,[local[i]+com[i] for i in (0,1)],1e-4),"Authored/COM coordinate conversion")
            centre=location(pose,local)
            require(same(centre,[grain["cell"][0]+.5,grain["cell"][1]+.5],4e-4),"Copied local coordinate differs from actual pose")
            indices=[];near=False
            for i,rect in enumerate(rectangles):
                delta=[abs(local[j]-rect["center"][j])-rect["size"][j]/2 for j in (0,1)]
                if max(delta)<=0:indices.append(i)
                near|=any(abs(v)<1e-4 for v in delta)
            if near:ambiguities+=1
            else:require(indices==q["inside_rectangles"],"Separated hull membership differs")
            expected_flags={"primary_cavity":-12<=raw[0]<12 and -4<=raw[1]<2,
                "closed_deck_interior_x":-12<=raw[0]<12,"below_closed_deck":-12<=raw[0]<12 and raw[1]>4,
                "beyond_closed_stop":raw[0]<-15,"beyond_open_nose":raw[0]>18,"above_rim":raw[1]<-5}
            require(all(type(q[k]) is bool and q[k]==v for k,v in expected_flags.items()),"Copied side classification differs")
            require(same(q["below_deck_margin"],raw[1]-4,1e-4) and same(q["closed_stop_margin"],-15-raw[0],1e-4),"Closed-side signed margin differs")
    return ambiguities


def witness(rows,index,flag):
    if index is None:return None
    r,n=rows[index],rows[index+1]
    frames=[r["before"]["grains"],r["after"]["grains"],n["after"]["grains"]]
    all_x=all(g["current"]["closed_deck_interior_x"] for cloud in frames for g in cloud)
    all_stop_y=all(-5<=g["current"]["authored_local"][1]<=4 for cloud in frames for g in cloud)
    return {"tick":r["tick"],"next_completed_boundary":n["tick"],"flag":flag,
        "before_current":counts(r["before"],"current"),"after_sampled":counts(r["after"],"sampled"),
        "after_current":counts(r["after"],"current"),"next_after_sampled":counts(n["after"],"sampled"),
        "next_after_current":counts(n["after"],"current"),"all_grains_deck_interior_x_at_three_observations":all_x,
        "all_grains_within_closed_stop_height_at_three_observations":all_stop_y,
        "all_initial_witness_grains_in_closed_stop_before":all(g["current"]["class"]=="closed_stop" for g in frames[0]),
        "sample_to_current_com_delta":[r["state"]["position"][j]-r["sample_state"]["position"][j] for j in (0,1)],
        "velocity":r["state"]["velocity"],"aggregate_displaced":r["gcr"]["displaced"],
        "scope":"Copied-set far-side occupancy survives the next completed preparation/owner boundary; no particle IDs or continuous path inferred."}


def compact_trace(row):
    phases={}
    for phase in ("before","after"):
        o=row[phase]
        phases[phase]={"coverage":o["coverage"],"outside_roi_count":o["outside_roi_count"],"grains":[
            {"cell":g["cell"],"mask":g["native_mask_proxy"],
             **{frame:{"xy":g[frame]["authored_local"],"class":g[frame]["class"],"primary":g[frame]["primary_cavity"],
                "rectangles":g[frame]["inside_rectangles"],"below":g[frame]["below_closed_deck"],
                "stop":g[frame]["beyond_closed_stop"],"nose":g[frame]["beyond_open_nose"],"rim":g[frame]["above_rim"]}
                for frame in("sampled","current")}}for g in o["grains"]]}
    return {"tick":row["tick"],"sample_state":row["sample_state"],"state":row["state"],**phases,
        "native":{k:row["gcr"].get(k)for k in ("sample_serial","sample_com","displaced","unresolved","cellular_overlap_pre","cellular_overlap_post","impulse","torque","arrival_count","normal_accepted","event_budget_cost","global_capacity","energy_before","energy_after")}}


def reduce_capture(raw,spec,protocol,identity,runtime,receipt):
    finite(raw);require(same(raw.get("case"),spec) and raw.get("registration")==REG,"Foreign capture case")
    for key,expected in {"source":identity["source"],"inputs":identity["inputs_hash"],"protocol_sha256":identity["protocol_sha256"],
                         "definition_hash":DEFINITION_HASH,"native_sha256":runtime["native_sha256"],"physics_backend":"Rapier2D"}.items():
        require(raw["identity"].get(key)==expected,"Capture identity "+key)
    options={"response":spec["response"],"budget":20.,"mass_multiplier":1.,"inertia_multiplier":1.,"thrust_multiplier":1.,"torque_multiplier":1.,"boost_multiplier":2.}
    require(same(raw["options"],options),"Frozen actor overrides")
    definition=json.loads(archived(FROZEN_DEFINITION_SOURCE)["retained"][DEFINITION])
    original=definition["hull"]["rects"];area=sum(r[2]*r[3]for r in original)
    com=[sum(r[2]*r[3]*(r[i]+r[i+2]/2)for r in original)/area for i in(0,1)]
    geometry=[{"center":[r[i]+r[i+2]/2-com[i]for i in(0,1)],"size":r[2:]}for r in original]
    inertia=definition["physics"]["mass"]/area*sum(r[2]*r[3]*((r[2]**2+r[3]**2)/12+sum((r[i]+r[i+2]/2-com[i])**2 for i in(0,1)))for r in original)
    require(abs(raw["mass"]-.18)<1e-6 and same(raw["authored_com"],com,1e-5)and same(raw["hull_rectangles"],geometry,1e-5)and abs(raw["inertia"]-inertia)<1e-4,"Frozen physical mass/COM/inertia/geometry")
    require(same(raw["initial"],{"position":protocol["spawn"],"velocity":[0,0],"rotation":0,"omega":0}),"Registered initial physical state")
    seed={(x,249)for x in range(504,520)}
    require(set(map(tuple,raw["before"]["points"]))==seed,"Registered initial coordinate set")
    require(sum(raw["before"]["counts"])==1024*512 and all(integer(v)and v >= 0 for v in raw["before"]["counts"]),"Whole-fixture native census schema")
    require(raw["before"]["counts"]==raw["after"]["counts"] and raw["before"]["water_mass"]==raw["after"]["water_mass"],"Final closed native quantities")
    require(raw["before"]["counts"][protocol["material"]]==protocol["grains"] and raw["before"]["water_mass"]==0,"Registered initial grain quantity")
    rows=raw.get("rows",[]);violations=[];ambiguities=0
    def check(value,reason,tick):
        if not value:violations.append({"tick":tick,"reason":reason})
    previous=raw["before"]["points"]
    serials=set();sessions=set()
    for tick,row in enumerate(rows):
        require(row["tick"]==tick,"Noncontiguous capture")
        before=row["sample_state"];after=row["state"];g=row["gcr"]
        for phase,actual in (("before",before),("after",after)):
            ambiguities+=validate_observation(row[phase],raw["hull_rectangles"],raw["authored_com"],protocol["grains"],raw["before"]["counts"],raw["before"]["water_mass"],before,actual)
        check(point_set(row["before"])==set(map(tuple,previous)),"No material mutation between observed owner boundaries",tick)
        previous=row["after"]["points"]
        if tick:check(same(before,rows[tick-1]["state"]),"No post-construction pose/velocity setter",tick)
        moving=protocol["move_from"]<=tick<protocol["move_to"];braking=protocol["move_to"]<=tick<protocol["brake_to"]
        # Godot's Vector2 stores the requested decimal fraction as float32.
        # Match that exact value; do not widen a physical outcome tolerance.
        request={"action":{"move":[f32(v)for v in spec["move"]]if moving else[0,0],"aim":[1,0],"effort":1.,"trim":0.,"primary":False,"secondary":braking,"auxiliary":False},
                 "ports":{"q":False,"e":False,"s":False,"boost":moving and spec["boost"]}}
        check(same(row["request"],request),"Registered actuation interval",tick)
        check(row["observed_steps"]==[1,1] and row["observed_response_counts"][0]==1 and row["observed_response_counts"][1]in(0,1),"One native/Rapier/response boundary",tick)
        app=row["application"];bodies=app.get("bodies",[])
        check(app.get("accepted")is True and len(bodies)==1 and row["physical_wrench_applications"]in(0,1),"One accepted physical wrench owner",tick)
        if len(bodies)==1:
            check(bodies[0]["sample"]==g["sample_serial"]and bodies[0]["session"]==g["session_id"]and bodies[0]["age"]==0 and bodies[0]["index"]==0 and bodies[0]["physical_wrench_applications"]==row["physical_wrench_applications"],"Fresh aggregate application identity",tick)
            check(abs(bodies[0]["actual_mass"]-raw["mass"])<1e-6 and abs(bodies[0]["actual_inertia"]-raw["inertia"])<1e-4,"One actual physical mass/inertia",tick)
        check(g["admission_kind"]=="authored" and g["granular_events"]==SELECTORS[spec["response"]] and g["proxy_count"]==6 and g["physical_body_id"]==1,"Actual compound response selector/geometry",tick)
        check(integer(g["sample_serial"]) and g["sample_serial"]>0 and g["sample_serial"]not in serials,"Fresh sample serial",tick)
        serials.add(g["sample_serial"]);sessions.add(g["session_id"])
        check(g["normal_accepted"]+g["event_budget_cost"]<=g["global_capacity"]+1e-8,"Shared accepted budget",tick)
        check(g["energy_after"]<=g["energy_before"]+1e-8*max(1.,g["energy_before"]),"Passive energy ledger",tick)
        check(0<=g["nodes"]<=96 and 0<=g["updates"]<=768,"Bounded solver work",tick)
        if spec["response"]=="LA-EVENT-OFF" or (spec["response"]=="LA-SELECTIVE" and g["arrival_count"]==0):
            check(g["event_accepted"]==[0.,0.]and g["event_torque"]==0 and g["event_budget_cost"]==0,"Suppressed event/arrival closure",tick)
    check(len(sessions)<=1,"One native session",None)
    complete=raw.get("ok")is True and not raw.get("errors") and len(rows)==protocol["ticks"] and receipt.get("ok")is True and receipt.get("exit")==0
    sides={};indices=set()
    for flag in ("below_closed_deck","beyond_closed_stop","beyond_open_nose","above_rim"):
        observed=[i for i,r in enumerate(rows)if counts(r["after"],"current")[flag]]
        pers=persistent_rows(rows,flag)
        sides[flag]={"first_post_tick":observed[0]if observed else None,"last_post_tick":observed[-1]if observed else None,
            "post_boundaries":len(observed),"peak_count":max((counts(r["after"],"current")[flag]for r in rows),default=0),
            "first_persistent_tick":pers[0]if pers else None,"last_persistent_tick":pers[-1]if pers else None,"persistent_boundary_pairs":len(pers),
            "first_persistent_witness":witness(rows,pers[0]if pers else None,flag)}
        if pers:
            for i in (pers[0]-1,pers[0],pers[0]+1):
                if 0<=i<len(rows):indices.add(i)
    overlap=[i for i,r in enumerate(rows)if counts(r["after"],"current")["inside_hull"]]
    if overlap:
        for i in (overlap[0],overlap[0]+1):
            if i<len(rows):indices.add(i)
    points=raw["hull_rectangles"]
    corners=[[r["center"][j]+sign*r["size"][j]/2 for j,sign in enumerate(signs)]for r in points for signs in ((-1,-1),(-1,1),(1,1),(1,-1))]
    com_steps=[];normal_steps=[];corner_steps=[]
    for row in rows:
        a,b=row["sample_state"],row["state"];delta=[b["position"][j]-a["position"][j]for j in(0,1)]
        com_steps.append(norm(delta));normal_steps.append(abs(math.sin(a["rotation"])*delta[0]-math.cos(a["rotation"])*delta[1]))
        corner_steps.extend(math.dist(location(a,p),location(b,p))for p in corners)
    summary={"case":spec["id"],"response":spec["response"],"capture_complete":complete,"observed_rows":len(rows),"errors":raw.get("errors",[]),
        "observed_mechanical_pass":not violations,"mechanical_complete_pass":complete and not violations,"violations":violations,
        "motion":state_metrics(rows,raw["initial"]),"maximum_com_displacement_per_tick":max(com_steps,default=None),
        "maximum_absolute_deck_normal_com_displacement_per_tick":max(normal_steps,default=None),"maximum_sampled_corner_displacement_per_tick":max(corner_steps,default=None),
        "primary_cavity_minimum_current":min((counts(r["after"],"current")["primary_cavity"]for r in rows),default=None),
        "primary_cavity_minimum_sampled":min((counts(r["after"],"sampled")["primary_cavity"]for r in rows),default=None),
        "first_current_hull_overlap":overlap[0]if overlap else None,"current_hull_overlap_boundaries":len(overlap),
        "sides":sides,"exact_start_end_quantity":True,"global_observations":sum(o["coverage"]=="whole-fixture"for r in rows for o in(r["before"],r["after"])),
        "classification_boundary_ambiguities":ambiguities,"maximum_nodes":max((r["gcr"]["nodes"]for r in rows),default=None),
        "maximum_updates":max((r["gcr"]["updates"]for r in rows),default=None),"step_time_us":distribution([r["step_us"]for r in rows]),
        "maximum_pre_ejection_overlap":max((r["gcr"].get("cellular_overlap_pre",0)for r in rows),default=None),
        "maximum_post_ejection_overlap":max((r["gcr"].get("cellular_overlap_post",0)for r in rows),default=None),
        "ejection_displaced_sum":sum(r["gcr"]["displaced"]for r in rows),"reported_failure":raw.get("failure")}
    return summary,[compact_trace(rows[i])for i in sorted(indices)]


def reduce_replay(raw,identity,runtime,gate_log):
    finite(raw);require(raw["registration"]==REG and raw["source"]==identity["source"] and raw["native_sha256"]==runtime["native_sha256"],"Native replay identity")
    require(raw["checks"]==1046 and not raw["failures"]and len(raw["reports"])==36,"Complete native replay assertions")
    lines=[line.split(" ",1)[1]for line in gate_log.splitlines()if line.startswith("GCR_SCOOPER_EJECTION_REPLAY ")]
    require(len(lines)==1 and same(json.loads(lines[0]),raw),"Replay output differs from hash-bound gate log")
    keys=set();cases=[]
    for r in raw["reports"]:
        key=(r["arm"],r["admission"],r["advance_up_cells"])
        require(key not in keys,"Duplicate replay case");keys.add(key)
        require(r["admitted"]==[True,True]and r["native_ticks"]==[0,0]and not r["native_failed"],"Replay preparation/clock validity")
        require(r["quantity_before"]==r["quantity_after"]and r["quantity_before"]["counts"][2]==1 and r["quantity_before"]["water_mass"]==0,"Replay exact quantity")
        require(r["copied_velocity"]==[0.,0.]and r["before"]["side"]=="above","Replay geometric isolation")
        after=r["after"]["relative_current"];wrong=after["side"]=="below"and abs(after["local"][0])<13
        require(r["observed_closed_deck_wrong_side"]is wrong,"Replay wrong-side flag differs from observed endpoint")
        cases.append({"arm":r["arm"],"admission":r["admission"],"advance_up_cells":r["advance_up_cells"],
            "before_cell":r["before"]["cell"],"encounter_local":r["seed_relative_current_before_prepare"]["local"],
            "after_cell":after["cell"],"after_local":after["local"],"after_side":after["side"],"relocation_cells":r["relocation_cells"],"wrong_side":wrong})
    expected={(a,k,d)for a in("control","off","selective")for k in("independent","authored-single-rectangle")for d in(0.,.5,1.,1.5,2.,3.)}
    require(keys==expected,"Native replay population differs")
    return {"checks":raw["checks"],"cases":36,"wrong_side_count":sum(r["wrong_side"]for r in cases),"observations":cases,
        "scope":raw["scope"],"conservation":True,"zero_native_ticks":True,"force_result_evaluation":False}


def analyze(output,summary_dir):
    output,summary_dir=Path(output).resolve(),Path(summary_dir).resolve();require(not summary_dir.exists(),"Fresh summary directory required")
    software={"path":"tools/experiments/analyze_gcr_carry.py","sha256":digest(Path(__file__).read_bytes()),
              "shared_authentication_helper_sha256":digest((Path(__file__).parent/'analyze_gcr_authored.py').read_bytes())}
    watched={};manifest=[];errors=[];summaries=[];selected=[];replays=[]
    def watch(path,kind):
        require(path.is_file(),"Missing evidence "+str(path.relative_to(output)))
        data=path.read_bytes();h=digest(data);watched[path]=h
        manifest.append({"path":path.relative_to(output).as_posix(),"kind":kind,"bytes":len(data),"sha256":h});return h
    watch(output/'identity.json',"source identity");identity=read(output/'identity.json');source=identity['source'];archive=archived(source)
    require(identity["tree"]==subprocess.check_output(["git","-C",str(ROOT),"rev-parse",source+"^{tree}"],text=True,timeout=60).strip(),"Source tree identity")
    verify_source_map(identity["inputs"],source_scope(archive),"Complete captured Godot")
    require(digest(json.dumps(identity["inputs"],sort_keys=True).encode())==identity["inputs_hash"],"Input-map hash")
    protocol_bytes=subprocess.check_output(["git","-C",str(ROOT),"show",source+":"+PROTOCOL],timeout=60).replace(b'\r\n',b'\n')
    protocol=json.loads(protocol_bytes);require(protocol["registration"]==REG and protocol["ticks"]==450 and len(protocol["cases"])==10,"Frozen protocol population")
    frozen=archived(FROZEN_DEFINITION_SOURCE)["retained"][DEFINITION]
    require(archive["retained"][DEFINITION]==frozen,"Registered Scooper definition")
    completion=None
    if (output/'completion.json').is_file():watch(output/'completion.json',"runner completion");completion=read(output/'completion.json')
    for platform in PLATFORMS:
        folder=output/platform
        try:
            ph=watch(folder/PROTOCOL,"registered protocol");require(ph==identity["protocol_sha256"]and (folder/PROTOCOL).read_bytes().replace(b'\r\n',b'\n')==protocol_bytes,"Protocol authority")
            watch(folder/'runtime.json',"runtime");runtime=read(folder/'runtime.json')
            require(runtime["engine_version"]=="4.7.stable.official.5b4e0cb0f","Pinned engine version")
            project=folder/'godot'
            for name,h in identity["inputs"].items():require(digest(bundle_path(project,name.removeprefix("godot/")).read_bytes().replace(b'\r\n',b'\n'))==h,"Copied source "+name)
            suffix=""if platform=="windows"else".linux"
            native=read(project/f'addons/cybersand_native/runtime-provenance{suffix}.json')
            require(native["source_commit"]==runtime["native_build_source"]and native["source_inputs"]==runtime["native_source_inputs"],"Runtime provenance identity")
            verify_source_map(native["source_inputs"],source_scope(archive,native=True),"Capture native")
            verify_source_map(native["source_inputs"],source_scope(archived(native["source_commit"]),native=True),"Compiled native")
            require(digest(bundle_path(project,native["artifact"].removeprefix("godot/")).read_bytes())==native["sha256"]==runtime["native_sha256"],"Native runtime bytes")
            rapier=read(project/f'addons/godot-rapier2d/runtime-provenance.{platform}.json')
            require(digest(bundle_path(project,rapier["artifact"].removeprefix("godot/")).read_bytes())==rapier["sha256"]==runtime["rapier_sha256"],"Rapier runtime bytes")
            gh=watch(folder/'gates.json',"gate receipts");gates=read(folder/'gates.json')
            gate_names={g["test"]for g in gates}
            required_gates={"import","test_gcr_scooper_leak_capture","test_gcr_scooper_ejection_replay"}
            require(required_gates<=gate_names and len(gate_names)==len(gates),"Complete unique host controls")
            require(all(name in required_gates or name.startswith('test_')and 'godot/tests/'+name+'.gd'in identity['inputs']for name in gate_names),"Unbound extra host control")
            for gate in gates:
                require(gate["ok"]is True and gate["exit"]==0 and not gate["timed_out"],"Failed host control")
                require(watch(folder/(gate["test"]+'.log'),"gate log")==gate["log_sha256"],"Original gate log hash")
            watch(folder/'ejection-replay.json',"native copied-geometry replay")
            replays.append(dict(platform=platform,**reduce_replay(read(folder/'ejection-replay.json'),identity,runtime,(folder/'test_gcr_scooper_ejection_replay.log').read_text(encoding='utf-8'))))
            ch=watch(folder/'campaign.json',"campaign receipts");campaign=read(folder/'campaign.json')
            receipts={r["case"]:r for r in campaign};require(len(receipts)==len(campaign)and receipts.keys()<={s["id"]for s in protocol["cases"]},"Foreign/duplicate campaign member")
            if completion:
                entry=next(r for r in completion["results"]if r["platform"]==platform)
                require(entry["gates_sha256"]==gh and entry["campaign_sha256"]==ch,"Completion custody hashes")
            for spec in protocol["cases"]:
                row={"platform":platform,"case":spec["id"],"response":spec["response"]}
                try:
                    receipt=receipts[spec["id"]];require(receipt["response"]==spec["response"],"Response receipt")
                    rh=watch(folder/(spec["id"]+'.json'),"copied grain capture");lh=watch(folder/(spec["id"]+'.log'),"capture log")
                    require(rh==receipt["raw_sha256"]and lh==receipt["log_sha256"],"Original capture/log hash")
                    raw=read(folder/(spec["id"]+'.json'));require(receipt["rows"]==len(raw["rows"]),"Receipt row count")
                    reduced,trace=reduce_capture(raw,spec,protocol,identity,runtime,receipt);row.update(reduced)
                    selected.append({"platform":platform,"case":spec["id"],"response":spec["response"],"rows":trace})
                except (EvidenceError,KeyError,TypeError,ValueError,OSError)as exc:row.update(capture_complete=False,mechanical_complete_pass=False,identity_errors=[str(exc)])
                summaries.append(row)
        except (EvidenceError,KeyError,TypeError,ValueError,OSError,StopIteration)as exc:errors.append({"platform":platform,"error":str(exc)})
    for path,h in watched.items():require(path.is_file()and digest(path.read_bytes())==h,"Evidence changed during analysis "+str(path))
    require(digest(Path(__file__).read_bytes())==software["sha256"]and digest((Path(__file__).parent/'analyze_gcr_authored.py').read_bytes())==software["shared_authentication_helper_sha256"],"Reducer source changed during analysis")
    require(completion is None or completion["source"]==source,"Completion source")
    full=len(summaries)==20 and all(r.get("capture_complete")for r in summaries)
    mechanical=full and not errors and all(r.get("mechanical_complete_pass")for r in summaries)
    custody=bool(completion and completion.get("ok")is True and completion.get("inputs_unchanged")is True)
    result={"registration":REG,"source":source,"tree":identity["tree"],"protocol_sha256":identity["protocol_sha256"],"analysis_software":software,
        "expected_physical_captures":20,"reported_physical_captures":len(summaries),
        "complete_physical_captures":full,"mechanical_population_pass":mechanical,"runner_custody_pass":custody,
        "diagnostic_acquisition_pass":mechanical and custody and len(replays)==2,"runner_completion":completion,
        "integrity_errors":errors,"cases":summaries,"native_replays":replays,
        "scope":["Persistent means far-side copied-set occupancy after the next completed owner boundary, including its preparation; no particle identities/continuous paths.",
        "Cavity-count dips and inside-hull overlap alone are not declared leaks. Open nose/rim side occupancy is separate.",
        "Per-proxy endpoint counters are unobserved because their old getter evaluates/mutates rest history.",
        "Whole owner timing only; diagnostics are outside the timer. Passive energy is not whole-system energy.",
        "A valid diagnostic acquisition can retain physical wrong-side defects; no production or gameplay acceptance follows."]}
    summary_dir.mkdir(parents=True)
    for name,value in (("machine-summary.json",result),("raw-manifest.json",{"source":source,"files":manifest})):
        (summary_dir/name).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n',encoding='utf-8',newline='\n')
    # One dense case per line keeps the selected-frame artifact compact. Its
    # fields remain named; raw hashes authenticate the unreduced observations.
    trace_text='{\n  "source": '+json.dumps(source)+',\n  "cases": [\n'
    trace_text+=',\n'.join('    '+json.dumps(case,separators=(',',':'),allow_nan=False)for case in selected)
    (summary_dir/'selected-traces.json').write_text(trace_text+'\n  ]\n}\n',encoding='utf-8',newline='\n')
    return result


def paired_summary(baseline,candidate,baseline_folder,candidate_folder):
    """Compare registered observations; this does not invent an acceptance gate."""
    require(baseline['protocol_sha256']==candidate['protocol_sha256'],'Paired registered protocol differs')
    old=read(Path(baseline_folder)/'identity.json');new=read(Path(candidate_folder)/'identity.json')
    changes=[p for p in sorted(old['inputs'].keys()|new['inputs'].keys())if old['inputs'].get(p)!=new['inputs'].get(p)]
    allowed={'godot/addons/cybersand_native/runtime-provenance.json','godot/addons/cybersand_native/runtime-provenance.linux.json'}
    new_tests=[p for p in changes if p not in old['inputs']and p.startswith('godot/tests/')]
    require(set(changes)<=allowed|set(new_tests),'Paired runtime/actor/capture/replay inputs changed: '+str(changes))
    native_changes={}
    for platform in PLATFORMS:
        a=read(Path(baseline_folder)/platform/'runtime.json');b=read(Path(candidate_folder)/platform/'runtime.json')
        require(a['engine_version']==b['engine_version']and a['engine_sha256']==b['engine_sha256']and a['rapier_sha256']==b['rapier_sha256'],'Paired host or Rapier runtime differs')
        native_changes[platform]=[p for p in sorted(a['native_source_inputs'].keys()|b['native_source_inputs'].keys())if a['native_source_inputs'].get(p)!=b['native_source_inputs'].get(p)]
    a={(r['platform'],r['case']):r for r in baseline['cases']};b={(r['platform'],r['case']):r for r in candidate['cases']}
    paired=[]
    for key in sorted(a.keys()|b.keys()):
        left,right=a.get(key),b.get(key);row={'platform':key[0],'case':key[1]}
        valid=left is not None and right is not None and left.get('mechanical_complete_pass')and right.get('mechanical_complete_pass')
        row['complete_valid_pair']=bool(valid)
        if valid:
            for label,source in(('baseline',left),('candidate',right)):
                sides=source['sides'];w=sides['below_closed_deck']['first_persistent_witness']
                row[label]={'response':source['response'],'first_persistent_below_deck_side':sides['below_closed_deck']['first_persistent_tick'],
                    'persistent_below_deck_pairs':sides['below_closed_deck']['persistent_boundary_pairs'],
                    'qualified_all_cloud_interior_deck_witness':bool(w and w['all_grains_deck_interior_x_at_three_observations']),
                    'first_persistent_beyond_stop_side':sides['beyond_closed_stop']['first_persistent_tick'],
                    'stop_height_qualifier':bool(sides['beyond_closed_stop']['first_persistent_witness']and sides['beyond_closed_stop']['first_persistent_witness']['all_grains_within_closed_stop_height_at_three_observations']),
                    'first_persistent_open_nose_side':sides['beyond_open_nose']['first_persistent_tick'],
                    'primary_cavity_minimum':source['primary_cavity_minimum_current'],
                    'peak_upward_speed':source['motion']['peak_upward_speed'],'final_position':source['motion']['final']['position'],
                    'maximum_com_step':source['maximum_com_displacement_per_tick'],'maximum_deck_normal_com_step':source['maximum_absolute_deck_normal_com_displacement_per_tick'],
                    'ejection_displaced_sum':source['ejection_displaced_sum'],'maximum_post_ejection_overlap':source['maximum_post_ejection_overlap']}
            require(row['baseline']['response']==row['candidate']['response'],'Paired response selection differs')
        paired.append(row)
    return {'registration':REG,'baseline_source':baseline['source'],'candidate_source':candidate['source'],
        'both_acquisitions_valid':baseline['diagnostic_acquisition_pass']and candidate['diagnostic_acquisition_pass'],
        'complete_pairs':sum(r['complete_valid_pair']for r in paired),'unchanged_actor_capture_inputs':True,
        'changed_godot_input_paths':changes,'added_test_inputs_not_in_actor_runtime':new_tests,'changed_native_input_paths':native_changes,
        'native_replay_wrong_side_counts':{label:{r['platform']:r['wrong_side_count']for r in data['native_replays']}for label,data in(('baseline',baseline),('candidate',candidate))},
        'cases':paired,'scope':['Comparison of registered measurements only; no new outcome thresholds or force/material tuning.',
        'Beyond-stop/open-nose/rim occupancy is separate from demonstrated closed-hull crossing.',
        'A qualified interior deck witness requires all copied grains inside the horizontal interior across the recorded witness observations.',
        'Cavity minimum zero remains visible; no uninterrupted carry, production or owner acceptance follows.']}


def self_test():
    def g(flag=False,inside=False):return {"cell":[0,0],"current":{**{k:False for k in FLAGS},"below_closed_deck":flag,"inside_rectangles":[0]if inside else[],"class":"deck"if inside else"free"},"sampled":{**{k:False for k in FLAGS},"below_closed_deck":flag,"inside_rectangles":[],"class":"free"}}
    def row(flag=False,inside=False):return {"after":{"grains":[g(flag,inside)]}}
    assert persistent_rows([row(False,True),row(False)],"below_closed_deck")==[]
    assert persistent_rows([row(True),row(False)],"below_closed_deck")==[]
    assert persistent_rows([row(True),row(True)],"below_closed_deck")==[0]
    try:verify_source_map({}, {'required':'hash'},'empty map');raise AssertionError('missing map accepted')
    except EvidenceError:pass
    assert counts({"grains":[g(False,True)]},"current")["inside_hull"]==1
    assert counts({"grains":[g(False,True)]},"current")["below_closed_deck"]==0
    next_row=row(True);next_row["after"]["grains"][0]["sampled"]["below_closed_deck"]=False
    assert persistent_rows([row(True),next_row],"below_closed_deck")==[]
    assert f32(-.1)!=-.1 and f32(-.1)==struct.unpack('f',bytes.fromhex('cdccccbd'))[0]
    print('GCR_CARRY_ANALYZER_SELF_TEST 8 controls passed')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--summary-dir',type=Path);parser.add_argument('--baseline',type=Path);parser.add_argument('--self-test',action='store_true');args=parser.parse_args()
    if args.self_test:self_test();return 0
    if args.output is None or args.summary_dir is None:parser.error('Both --output and --summary-dir are required')
    try:
        result=analyze(args.output,args.summary_dir)
        if args.baseline:
            old=analyze(args.baseline,args.summary_dir/'baseline-recheck')
            paired=paired_summary(old,result,args.baseline,args.output)
            (args.summary_dir/'paired-summary.json').write_text(json.dumps(paired,indent=2,allow_nan=False)+'\n',encoding='utf-8',newline='\n')
    except (EvidenceError,KeyError,TypeError,ValueError,OSError)as exc:print(json.dumps({'ok':False,'evidence_error':str(exc)}));return 2
    print(json.dumps({k:result[k]for k in('source','complete_physical_captures','mechanical_population_pass','runner_custody_pass','diagnostic_acquisition_pass')}))
    return 0 if result['diagnostic_acquisition_pass']else 1


if __name__=='__main__':raise SystemExit(main())
