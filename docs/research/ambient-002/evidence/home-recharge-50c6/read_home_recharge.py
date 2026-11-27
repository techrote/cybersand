"""Read two actual Foundry observations without running or modifying the app."""
from __future__ import annotations
import argparse, hashlib, json, math, pathlib, struct

BASE_APP="a7250e15495667b2fcf564cbed1eaa8dea217c45"
NEW_APP="50c6df89528dc9ecdc5316d8c67abf203e192254"
NEW_TREE="d9740be7cafb8ac7b7d6eee4a16219989745fd95"
NEW_OBSERVER="52900f9d8ead1f6d0b3c4ae6fbdc1e0ac049ce4b"
SCRIPT_SHA="aac731d1d44fcc46beca22ea6b0ee84e1acfe4c09ad51cc47bd52abb8c922379"
SCENE="ambient2-settlement"
HOME=(365.0,355.0)
ARRIVAL_RADIUS=20.0
ORDINARY_RECHARGE_RADIUS=16.0

def sha(path):
    with path.open("rb") as f:return hashlib.file_digest(f,"sha256").hexdigest()

def read(path):return json.loads(path.read_text())

def original_process(folder,row):
    assert row["status"]=="passed" and row["exit_code"]==0
    assert sha(folder/"process.json")==row["process_sha256"]
    assert sha(folder/"process.log")==row["log_sha256"]
    actual=read(folder/"process.json")
    assert all(row[k]==v for k,v in actual.items())

def inspect(root,application):
    campaign=read(root/"watch-campaign.json")
    assert campaign["status"]==campaign["input_custody"]=="passed"
    assert campaign["application"]["source_commit"]==application
    assert campaign["application"]["local_delta"]==campaign["observer"]["local_delta"]==[]
    assert campaign["graphical_observation"] and not campaign["compile_only"]
    assert campaign["owner_playfeel_accepted"] is False
    assert campaign["observer"]["files_sha256"]["tools/ambient/watch_ambient_living.gd"]==SCRIPT_SHA
    compile_root=root.parent/"observer-compile"
    compiled=read(compile_root/"watch-campaign.json")
    assert compiled["status"]==compiled["input_custody"]=="passed"
    assert compiled["compile_only"] and not compiled["graphical_observation"] and not compiled["cases"]
    for key in ("application","observer","project_inputs_sha256","runtime","engine"):
        assert compiled[key]==campaign[key],key
    original_process(compile_root/"import",compiled["import"])
    original_process(compile_root/"compile",compiled["compile"])
    original_process(root/"import",campaign["import"])
    found=[c for c in campaign["cases"] if c["scene"]==SCENE]
    assert len(found)==1
    case=found[0];folder=root/SCENE
    assert case["status"]=="passed"
    original_process(folder/"process",case["process"])
    command=case["process"]["command"]
    assert "--headless" not in command and command[command.index("--display-driver")+1]=="x11"
    assert "/application/godot" in command[command.index("--path")+1]
    assert "/observer/tools/ambient/" in command[command.index("--script")+1]
    path=folder/"frames/watch-report.json"
    assert sha(path)==case["report_sha256"]
    report=read(path)
    assert report["status"]=="passed" and report["failures"]==[]
    assert report["source_revision"]==application and report["observer_script_sha256"]==SCRIPT_SHA
    assert report["engine_sha256"]==campaign["engine"]["sha256"]
    assert report["scene"]==SCENE and report["follow_actor"]==7
    assert report["requested_simulation_seconds"]==60 and report["actual_simulation_seconds"]>=60
    assert report["native_ticks"]==report["physical_ticks"]==3601
    assert report["display"]=="X11" and report["rendering_driver"]=="opengl3"
    assert len(report["samples"])==len(case["observation"]["images"])==61
    assert set(case["observation"]["images"])=={f"frame-{n:04d}.png" for n in range(61)}
    roster=None;authority=None;focus=[];displayed=0;position_matches=0;last_time=-1
    for sample_index,s in enumerate(report["samples"]):
        second=s["requested_simulation_second"]
        assert second==sample_index
        name=f"frame-{second:04d}.png";image=folder/"frames"/name
        assert pathlib.PurePosixPath(s["capture"]["path"]).name==name
        receipt=case["observation"]["images"][name]
        assert sha(image)==receipt["sha256"] and image.stat().st_size==receipt["bytes"]
        with image.open("rb") as f:header=f.read(24)
        assert header[:8]==b"\x89PNG\r\n\x1a\n"
        assert list(struct.unpack(">II",header[16:24]))==receipt["dimensions"]==report["actual_framebuffer_size"]
        assert s["simulation_seconds_since_play"]>last_time
        last_time=s["simulation_seconds_since_play"]
        assert s["diagnostics_native_tick"]==receipt["native_tick"]
        assert s["diagnostics_physical_tick"]==receipt["physical_tick"]
        current=[(a["instance_id"],a["actor_id"],a["profile_id"],a["model"]) for a in s["actors"]]
        if roster is None:roster=current
        assert current==roster and len(current)==8
        if second:
            current_authority=[(a["run_id"],a["epoch"],a["generation"]) for a in s["actors"]]
            if authority is None:authority=current_authority
            assert current_authority==authority
            assert all(a["rejected"]==0 and not a["error"] for a in s["actors"])
        captured={int(a["instance_id"]):a for a in s["capture"]["actors"]}
        for a in s["actors"]:
            assert a["observation"]["position"]==captured[a["instance_id"]]["current_physical_position"]
            position_matches+=1
        frame,material=s["capture"]["rendered_actor_frame"],s["capture"]["material_display"]
        if frame["available"]:
            assert frame["world_generation"]==material["generation"] and frame["revision"]==material["revision"]
            displayed+=1
        a=next(a for a in s["actors"] if a["instance_id"]==7)
        p=a["observation"]["position"]
        assert all(math.isfinite(x) for x in p)
        focus.append({"requested_second":second,"actual_simulation_seconds":s["simulation_seconds_since_play"],
                      "position":p,"home_distance_cells":math.dist(p,HOME),
                      "exploration_drive":a.get("drives",{}).get("exploration"),
                      "intent":a["intent"],"memory":{k:v for k,v in a["memory"].items() if not k.endswith("_tail")}})
    for name,digest in case["media"]["files_sha256"].items():assert sha(folder/"media"/name)==digest
    segments=[];active=[]
    for row in focus:
        resting=row["intent"].get("selected_goal")=="seek_home_drive" and row["intent"].get("goal_phase")=="home_rest"
        if resting:active.append(row)
        elif active:segments.append(active);active=[]
    if active:segments.append(active)
    home_rests=[]
    for segment in segments:
        home_rests.append({"first_requested_second":segment[0]["requested_second"],
            "last_requested_second":segment[-1]["requested_second"],"samples":len(segment),
            "first_drive":segment[0]["exploration_drive"],"last_drive":segment[-1]["exploration_drive"],
            "drive_delta":segment[-1]["exploration_drive"]-segment[0]["exploration_drive"],
            "minimum_home_distance":min(r["home_distance_cells"] for r in segment),
            "maximum_home_distance":max(r["home_distance_cells"] for r in segment),
            "outside_sixteen_samples":sum(r["home_distance_cells"]>16 for r in segment),
            "neutral_intent_samples":sum(r["intent"].get("direction")==[0.0,0.0] for r in segment),
            "sampled_path_cells":sum(math.dist(a["position"],b["position"]) for a,b in zip(segment,segment[1:]))})
    result={"application_commit":application,"observer_commit":campaign["observer"]["commit"],
            "compile_campaign_sha256":sha(compile_root/"watch-campaign.json"),
            "compile_to_actual_all_inputs_equal":True,
            "campaign_sha256":sha(root/"watch-campaign.json"),"report_sha256":case["report_sha256"],
            "actual_simulation_seconds":report["actual_simulation_seconds"],"native_ticks":report["native_ticks"],
            "physical_ticks":report["physical_ticks"],"raw_image_count":61,
            "actual_framebuffer_size":report["actual_framebuffer_size"],"matched_displayed_publications":displayed,
            "copied_position_matches":position_matches,"renderer":report["renderer"],
            "process_wall_seconds":case["process"]["seconds"],"draw_intervals":report["draw_intervals"],
            "home_rest_segments":home_rests,"focus_samples":focus,
            "initial_actors":[{k:a[k] for k in ("instance_id","actor_id","model","profile_id","observation")} for a in report["samples"][0]["actors"]],
            "image_inventory":case["observation"]["images"],"media_sha256":case["media"]["files_sha256"]}
    return campaign,result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--baseline",type=pathlib.Path,required=True)
    p.add_argument("--candidate",type=pathlib.Path,required=True)
    p.add_argument("--output",type=pathlib.Path,required=True)
    args=p.parse_args()
    b,baseline=inspect(args.baseline,BASE_APP);n,candidate=inspect(args.candidate,NEW_APP)
    assert n["application"]["source_tree"]==NEW_TREE and n["observer"]["commit"]==NEW_OBSERVER
    assert n["requested_application_revision"]==n["admitted_application_revision"]==NEW_APP
    assert len(n["cases"])==1
    assert b["engine"]["sha256"]==n["engine"]["sha256"] and b["runtime"]==n["runtime"]
    assert baseline["initial_actors"]==candidate["initial_actors"]
    old_inputs,new_inputs=b["project_inputs_sha256"],n["project_inputs_sha256"]
    assert set(old_inputs)==set(new_inputs)
    changed=sorted(k for k in old_inputs if old_inputs[k]!=new_inputs[k])
    assert set(changed)=={"scripts/ambient/ambient_engine.gd","scripts/ambient/ambient_profile_editor.gd","tests/test_ambient_living_engine.gd"}
    assert baseline["home_rest_segments"] and candidate["home_rest_segments"]
    result={"schema":"ambient2-home-recharge-observation-comparison/v1","status":"passed",
            "reader_sha256":sha(pathlib.Path(__file__)),"home_center":HOME,
            "configured_arrival_radius":ARRIVAL_RADIUS,"ordinary_neutral_recharge_radius":ORDINARY_RECHARGE_RADIUS,
            "project_input_count":len(new_inputs),"changed_project_files":changed,
            "identical_authored_scene_and_initial_copied_actor_states":True,
            "same_official_engine_retained_native_and_rapier":True,"same_observer_gdscript_sha256":SCRIPT_SHA,
            "baseline":baseline,"candidate":candidate,
            "recharge_observed_in_candidate_home_rest":any(s["drive_delta"]>0 and s["samples"]>=2 for s in candidate["home_rest_segments"]),
            "outside_sixteen_band_exercised":any(s["outside_sixteen_samples"]>=2 and s["drive_delta"]>0 for s in candidate["home_rest_segments"]),
            "limits":["Separate actual hosted Linux runs; no cross-platform or repeated-run bit-determinism claim.",
                      "Approximately 1 Hz samples are coarse phase evidence, not a complete 10 Hz decision history.",
                      "Identical authored scene and initial copied actor poses are checked; the original watcher did not hash initial native material bytes.",
                      "Configured twenty-cell arrival is distinct from the primary science's separate sixteen-cell home metric.",
                      "Neutral intentions can retain physical movement; sampled positions quantify the observed residual.",
                      "Software rendering and sampled accelerated movies do not establish physical NVIDIA or owner monitor playfeel."]}
    if not result["recharge_observed_in_candidate_home_rest"]:result["status"]="recharge_not_observed"
    args.output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"status":result["status"],"baseline_rest":baseline["home_rest_segments"],
                     "candidate_rest":candidate["home_rest_segments"],"outside_sixteen_band_exercised":result["outside_sixteen_band_exercised"]},indent=2))

if __name__=="__main__":main()
