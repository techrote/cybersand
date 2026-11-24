#!/usr/bin/env python3
"""Independent authored workload, paint, eight-body and responsiveness gates."""
from __future__ import annotations

import hashlib
import json

from results import distribution, integer, need
from metrics import validate_deadline_baseline

BASIN_EDITS = [[0,496,512,16,58],[0,0,16,512,58],[496,0,16,512,58],
               [32,272,112,224,3],[160,432,144,64,3],[320,464,176,32,3],
               [256,400,8,96,58],[112,240,112,8,58]]
OPTIONS = {"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
           "thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}


def required_actors(registration: dict) -> list[dict]:
    return [{"actor_slot":slot,"instance_id":entry[0],"model":entry[1],
             "producer":"passive" if entry[1]=="reference_barrel" else "human","body_count":1}
            for slot,entry in enumerate(registration["actors"])]


def validate_setup(data: dict, registration: dict) -> tuple[dict, int]:
    fixture, workload = data["fixture"], data["mixed_workload"]
    need(fixture["name"] in ("basin512","basin1024") and fixture["actors"]==8
         and fixture["source"]=="pubpres_final_mixed_eight_actor_v1", "Unregistered mixed fixture")
    scale = 1 if fixture["name"]=="basin512" else 2
    need(fixture["extent"]==[512*scale,512*scale], "Mixed authored extent changed")
    raw = workload["setup_json"]
    need(isinstance(raw,str) and hashlib.sha256(raw.encode()).hexdigest()==fixture["setup_sha256"],
         "Mixed authored setup hash differs")
    setup = json.loads(raw)
    need(set(setup)=={"version","extent","actors","next_id","selected","edits","response","liquid_policy",
                      "normalize","rule_radius","source","material","brush","fire"}, "Mixed setup fields changed")
    expected = {"version":2,"extent":[512*scale,512*scale],"next_id":9,"selected":1,
                "response":"LA-SELECTIVE","normalize":False,"rule_radius":2,"source":[],
                "material":2,"brush":registration["brush_radius"],"fire":False}
    need(all(setup[k]==value for k,value in expected.items()), "Mixed source/options/input setup differs")
    need(isinstance(setup["liquid_policy"],list) and setup["liquid_policy"]
         and all(type(value) is int for value in setup["liquid_policy"]), "Mixed native policy carrier missing")
    expected_edits = [[value*scale if i<4 else value for i,value in enumerate(row)] for row in BASIN_EDITS]
    need(setup["edits"]==expected_edits, "Mixed authored material basin differs")
    expected_actors = [{"id":entry[0],"model":entry[1],"hash":registration["model_hashes"][entry[1]],
                        "spawn":[entry[2]*scale,entry[3]*scale],"options":OPTIONS}
                       for entry in registration["actors"]]
    need(setup["actors"]==expected_actors, "Mixed actor positions, definitions or physical options changed")
    need(workload["schema"]=="pubpres-final-mixed-workload-v1"
         and workload["actor_specification"]==registration["actors"]
         and workload["paint_tape"]==registration["paint_tape"], "Mixed registration differs from observed fixture")
    return setup, scale


def validate_neutral_controls(data: dict, steps: list[dict]) -> dict:
    before = data["mixed_workload"]["neutral_controls_before"]
    need(isinstance(before,list) and len(before)==8, "Mixed initial control roster missing")
    keys = {"slot","instance_id","sequence","deadline","generation","command_empty"}
    for slot,row in enumerate(before):
        need(set(row)==keys and row["slot"]==slot and row["instance_id"]==slot+1
             and integer(row["sequence"],-1) and integer(row["deadline"],-1)
             and integer(row["generation"]) and type(row["command_empty"]) is bool,
             "Mixed initial control owner missing or invalid")
        if slot:
            need(row["command_empty"] is True and row["sequence"]==-1 and row["deadline"]==-1,
                 "Unselected mixed actor already has a command/lease")
    for step in steps:
        controls = step.get("mixed_actor_controls")
        need(isinstance(controls,list) and len(controls)==8 and controls[1:]==before[1:],
             "Unselected actor acquired a command, generation change or different owner")
        selected = controls[0]
        need(set(selected)==keys and selected["slot"]==0 and selected["instance_id"]==1
             and selected["command_empty"] is False and selected["sequence"]==step["command_sequence"]
             and selected["deadline"]==step["command_deadline_tick"]
             and [row["generation"] for row in controls]==step["control_generations"],
             "Mixed actual selected command/control generation differs")
    return {"observed_actor_count":8,"neutral_actor_count":7,"unchanged_neutral_controls":True,
            "completed_step_observations":len(steps)}


def validate_paint(data: dict, events: list[dict], registration: dict, scale: int) -> dict:
    workload = data["mixed_workload"]
    admissions, observed = workload["paint_events"], workload["material_observations"]
    need(len(admissions)==len(observed)==4, "Missing mixed paint admission or material observation")
    need({row["action_index"] for row in observed}==set(range(4)), "Paint observation aliases or lacks an action")
    observed = sorted(observed,key=lambda row:row["action_index"])
    steps = sorted((row for row in events if row["event"]=="rapier_step"),key=lambda row:row["step"])
    callbacks = [row for row in events if row["event"] in ("physics_callback","main_callback")]
    uploads = [row for row in events if row["event"]=="texture_upload"]
    owner = data["physical_owner_before"]
    generation = steps[0]["world_generation"]
    delays, first_steps, hard_revisions = [], [], []
    for index,(spec,admission,material) in enumerate(zip(registration["paint_tape"],admissions,observed)):
        point = [value*scale for value in spec["point"]]
        need(admission["action_index"]==index and admission["accepted"] is True
             and admission["physical_tick"]==spec["tick"]
             and admission["absolute_tick"]==data["capture_physical_tick_start"]+spec["tick"]
             and admission["point"]==point and admission["material"]==spec["material"]
             and admission["radius"]==registration["brush_radius"]
             and admission["world_generation"]==generation and admission["epoch"]==owner["epoch"],
             "Ordinary paint action, native owner or real-step tape differs")
        need(integer(admission["start_usec"],1) and integer(admission["time_usec"],1)
             and data["capture_start_usec"]<=admission["start_usec"]<=admission["time_usec"]<=data["capture_end_usec"]
             and integer(admission["before_world_revision"]) and integer(admission["before_hard_revision"])
             and integer(admission["before_native_tick"]),
             "Paint admission clock/revision missing or outside capture")
        need(any(row["start_usec"]<=admission["start_usec"]<=admission["time_usec"]<=row["time_usec"]
                 for row in callbacks), "Paint was not admitted in an actual observed production callback")
        need(material["action_index"]==index and material["material"]==spec["material"]
             and integer(material["time_usec"],1) and admission["time_usec"]<=material["time_usec"]<=data["capture_end_usec"]
             and material["world_generation"]==generation and material["world_revision"]>admission["before_world_revision"]
             and integer(material["observer_usec"]), "Material witness predates paint or uses another World/revision")
        sample = material["point"]
        need(isinstance(sample,list) and len(sample)==2 and all(type(value) is int for value in sample),
             "Paint witness has no actual integer pixel")
        if spec["material"]==2:
            scan = registration["paint_scan"]
            need(point[0]+scan["x_offset"]<=sample[0]<point[0]+scan["x_offset"]+scan["width"]
                 and point[1]+scan["y_offset"]<=sample[1]<point[1]+scan["y_offset"]+scan["height"],
                 "Sand witness is outside its registered bounded search")
        else:
            need(sample==point, "Stationary paint/erase witness is not its exact authored pixel")
        joined = [row for row in uploads if row["render_serial"]==material["render_serial"]
                  and row["world_generation"]==generation and row["tick_index"]==material["native_tick"]
                  and row["generated_usec"]==material["generated_usec"] and row["time_usec"]<=material["time_usec"]]
        need(len(joined)==1, "Paint witness has no unique actual production texture upload")
        need(any(row["start_usec"]<=joined[0]["start_usec"]<=material["time_usec"]<=row["time_usec"]
                 for row in callbacks), "Paint source-image observation is not inside its real publication callback")
        following = [row for row in steps if row["step"]>admission["absolute_tick"] and row["time_usec"]>=admission["time_usec"]]
        need(following, "Paint has no subsequent genuine physical progression")
        first_steps.append((following[0]["time_usec"]-admission["time_usec"])/1000)
        hard = [row for row in following if row["installed_hard_revision"]>admission["before_hard_revision"]]
        if spec["material"] in (58,0,28):
            need(hard, "Hard material/erase action never reached a later valid installed terrain revision")
            hard_revisions.append({"action_index":index,"first_later_installed_revision":hard[0]["installed_hard_revision"],
                                   "first_later_physical_step":hard[0]["step"]})
        delays.append((material["time_usec"]-admission["time_usec"])/1000)
    need(observed[0]["time_usec"]<admissions[1]["start_usec"], "Erase has no preceding actual wall58 upload witness")
    cost = workload["material_probe_cost"]
    need(set(cost)=={"attempts","total_usec","max_usec"} and all(integer(value) for value in cost.values())
         and 4<=cost["attempts"]<=4*len(uploads) and cost["max_usec"]<=cost["total_usec"]
         and sum(row["observer_usec"] for row in observed)<=cost["total_usec"]
         and max(row["observer_usec"] for row in observed)<=cost["max_usec"],
         "Material probe costs omit an observed attempt or exceed their bounded upload opportunities")
    return {"ordinary_admissions":4,"material_witnesses":4,"admission_to_cpu_material_ms":distribution(delays),
            "admission_to_next_physical_completion_ms":distribution(first_steps),
            "later_terrain_revision_witnesses":hard_revisions,"material_probe_cost":cost,
            "scope":"First matching uploaded owned CPU material, not GPU completion/scanout. Later valid terrain revision is an aggregate revision witness, not per-brush causal acknowledgement."}


def validate_mixed_workload(data: dict, events: list[dict], registration: dict) -> dict:
    _, scale = validate_setup(data,registration)
    deadline_control = validate_deadline_baseline(data, required=True)
    need(data["schema"]=="pubpres-final-mixed-gameplay-v1" and data["camera"]=="follow"
         and data["workers"]==4 and data["water_law"]=="wave_flow_v1"
         and data["water_profile"]=="gameplay_main846f" and data["water_variant"]=="reference"
         and data["input_mode"]=="tape" and data["command_mode"]=="repeated_callback"
         and data["observer_mode"]=="full", "Mixed actual workload selection differs")
    steps = sorted((row for row in events if row["event"]=="rapier_step"),key=lambda row:row["step"])
    need(len(steps)>=144, "Mixed workload lacks real physical completions")
    controls = validate_neutral_controls(data,steps)
    contacts = [row for row in steps if row["bodies"][7]["contacts"]>0
                and 112*scale<=row["bodies"][7]["xy"][0]<=224*scale
                and 220*scale<=row["bodies"][7]["xy"][1]<=240*scale]
    need(contacts, "Passive barrel never produced a real contact above its authored platform")
    need(any(sum((a-b)**2 for a,b in zip(row["bodies"][0]["xy"],steps[0]["bodies"][0]["xy"]))>1.0
             for row in steps), "Selected Needle pose never progressed")
    return {"schema":"pubpres-final-mixed-workload-analysis-v1","controls":controls,
            "material_deadline_control":deadline_control,
            "passive_contact_steps":len(contacts),"first_passive_contact_step":contacts[0]["step"],
            "paint":validate_paint(data,events,registration,scale),
            "limits":"The ordinary action API and real physical steps are observed. Device input arrival, exact GPU completion, scanout, and pose displayed at scanout remain unobserved."}
