"""Read original hosted observation receipts; never execute the application."""
from __future__ import annotations
import argparse, collections, hashlib, json, math, pathlib, struct, zipfile

APP = "a7250e15495667b2fcf564cbed1eaa8dea217c45"
TREE = "a038e6df65d58529f4c496c01f26c65975654fa6"
OBSERVER = "2eea3dbb921058db418fbb243b4abc493cddbdb9"
OUTER = "907f8bcdd11ef4c7150dc252844ec8545a0a7a46e66abf41ff10e889ad868cef"
EXPECTED_TOOLS = {
    "tools/ambient/watch_ambient_living.gd": "aac731d1d44fcc46beca22ea6b0ee84e1acfe4c09ad51cc47bd52abb8c922379",
    "tools/ambient/run_graphical_watch.py": "8fa9b1fc6736a0259f8c065f7c1214703e964219cfbf23e6e733c5e4da2d65ac",
    "tools/ambient/test_graphical_watch.py": "bc79201adcc545bfc69f68ae37799a867628383cc9a85763e56cfd92e08c3e92",
}

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def read(path):
    return json.loads(path.read_text())

def verify_process(path, record):
    assert record["status"] == "passed" and record["exit_code"] == 0
    assert sha(path / "process.log") == record["log_sha256"]
    assert sha(path / "process.json") == record["process_sha256"]

def motion(samples, instance_id):
    # Start after the first three simulated seconds to separate initial settling.
    selected = [(s, next(a for a in s["actors"] if a["instance_id"] == instance_id))
                for s in samples if s["requested_simulation_second"] >= 3]
    positions = [a["observation"]["position"] for _, a in selected]
    for p in positions:
        assert len(p) == 2 and all(math.isfinite(x) for x in p)
    transitions = []
    last = None
    phase_counts = collections.Counter()
    for s, a in selected:
        i = a["intent"]
        key = (i.get("selected_goal", ""), i.get("goal_phase", ""), i.get("active_override", ""))
        phase_counts[" / ".join(key)] += 1
        if key != last:
            transitions.append({"actual_simulation_seconds": s["simulation_seconds_since_play"],
                                "goal": key[0], "phase": key[1], "override": key[2],
                                "reason": i.get("reason", ""), "position": a["observation"]["position"]})
            last = key
    first, final = selected[0][1], selected[-1][1]
    memory_fields = ("visited_count", "visit_admissions", "reentries", "interests_count",
                     "obstructions_count", "failure_events", "forgotten", "evictions")
    return {"instance_id": instance_id, "actor_id": final["actor_id"],
            "profile": final["profile_name"], "model": final["model"],
            "measurement_starts_at_requested_second": 3,
            "first_position": positions[0], "last_position": positions[-1],
            "x_range_cells": max(p[0] for p in positions) - min(p[0] for p in positions),
            "y_range_cells": max(p[1] for p in positions) - min(p[1] for p in positions),
            "sampled_path_cells": sum(math.dist(a,b) for a,b in zip(positions, positions[1:])),
            "net_displacement_cells": math.dist(positions[0], positions[-1]),
            "sampled_phase_counts": dict(phase_counts), "sampled_phase_transitions": transitions,
            "memory_at_three_seconds": {k:first["memory"].get(k) for k in memory_fields},
            "memory_at_end": {k:final["memory"].get(k) for k in memory_fields},
            "drives_at_three_seconds": first["drives"], "drives_at_end": final["drives"],
            "decisions_at_end": final["decisions"], "accepted_at_end": final["accepted"],
            "rejected_at_end": final["rejected"]}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", type=pathlib.Path)
    ap.add_argument("--output", type=pathlib.Path, required=True)
    args = ap.parse_args()
    root = args.root
    archive = root / "ambient-002-observation-2eea3dbb.zip"
    assert archive.stat().st_size == 66483275 and sha(archive) == OUTER
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        member_count = len(z.infolist())
    original = root / "original"
    campaign_root = original / "graphical-watch"
    campaign = read(campaign_root / "watch-campaign.json")
    compile_root = original / "observer-compile"
    compile_report = read(compile_root / "watch-campaign.json")
    assert campaign["status"] == "passed" and campaign["input_custody"] == "passed"
    assert campaign["graphical_observation"] and not campaign["compile_only"]
    assert campaign["owner_playfeel_accepted"] is False and campaign["platform"] == "linux"
    for report in (campaign, compile_report):
        assert report["application"]["source_commit"] == APP
        assert report["application"]["source_tree"] == TREE
        assert report["application"]["local_delta"] == []
        assert report["observer"]["commit"] == OBSERVER
        assert report["observer"]["files_sha256"] == EXPECTED_TOOLS
        assert report["observer"]["local_delta"] == []
        assert report["project_input_count"] == len(report["project_inputs_sha256"]) == 855
        assert report["input_custody"] == "passed"
    assert campaign["application"] == compile_report["application"]
    assert campaign["project_inputs_sha256"] == compile_report["project_inputs_sha256"]
    assert campaign["engine"] == compile_report["engine"]
    assert campaign["runtime"] == compile_report["runtime"]
    verify_process(campaign_root / "import", campaign["import"])
    verify_process(compile_root / "import", compile_report["import"])
    if "compile" in compile_report:
        verify_process(compile_root / "compile", compile_report["compile"])
    scenes = []
    image_count = 0
    for case in campaign["cases"]:
        scene = case["scene"]
        case_root = campaign_root / scene
        assert case["status"] == "passed"
        verify_process(case_root / "process", case["process"])
        command = case["process"]["command"]
        assert "--headless" not in command
        assert command[command.index("--display-driver")+1] == "x11"
        assert "/application/godot" in command[command.index("--path")+1]
        assert "/observer/tools/ambient/" in command[command.index("--script")+1]
        report_path = case_root / "frames/watch-report.json"
        assert sha(report_path) == case["report_sha256"]
        w = read(report_path)
        assert w["status"] == "passed" and w["failures"] == []
        assert w["source_revision"] == APP and w["scene"] == scene
        assert w["observer_script_sha256"] == EXPECTED_TOOLS["tools/ambient/watch_ambient_living.gd"]
        assert w["engine_sha256"] == campaign["engine"]["sha256"]
        assert w["actual_simulation_seconds"] >= 60 and w["requested_simulation_seconds"] == 60
        assert w["physical_ticks"] == w["native_ticks"] == 3601
        assert len(w["samples"]) == 61 and w["display"] == "X11"
        assert w["owner_playfeel_accepted"] is False
        image_inventory = {}
        frame_publications = collections.Counter()
        authority = None
        roster = None
        last_time = -1
        for sample in w["samples"]:
            second = sample["requested_simulation_second"]
            name = f"frame-{second:04d}.png"
            image_path = case_root / "frames" / name
            image = case["observation"]["images"][name]
            actual_hash = sha(image_path)
            assert actual_hash == image["sha256"] and image_path.stat().st_size == image["bytes"]
            with image_path.open("rb") as f:
                header = f.read(24)
            assert header[:8] == b"\x89PNG\r\n\x1a\n"
            dimensions = list(struct.unpack(">II", header[16:24]))
            assert dimensions == image["dimensions"] == w["actual_framebuffer_size"]
            assert sample["simulation_seconds_since_play"] > last_time
            last_time = sample["simulation_seconds_since_play"]
            assert sample["diagnostics_native_tick"] == image["native_tick"]
            assert sample["diagnostics_physical_tick"] == image["physical_tick"]
            actors = sample["actors"]
            current_roster = [(a["actor_id"],a["instance_id"],a["profile_id"],a["model"]) for a in actors]
            if roster is None: roster = current_roster
            assert current_roster == roster
            if second:
                current_authority = [(a["run_id"],a["epoch"],a["generation"]) for a in actors]
                if authority is None: authority = current_authority
                assert current_authority == authority
                assert all(a["rejected"] == 0 and not a["error"] for a in actors)
            frame = sample["capture"]["rendered_actor_frame"]
            material = sample["capture"]["material_display"]
            if frame.get("available"):
                assert frame["world_generation"] == material["generation"]
                assert frame["revision"] == material["revision"]
                frame_publications["matched_available"] += 1
            else:
                frame_publications["unavailable"] += 1
            image_inventory[name] = image
            image_count += 1
        assert len(image_inventory) == 61
        media_inventory = {}
        for name, expected in case["media"]["files_sha256"].items():
            path = case_root / "media" / name
            assert sha(path) == expected
            media_inventory[name] = {"sha256":expected,"bytes":path.stat().st_size}
        assert case["media"]["playback_samples_per_second"] == 6
        all_motion = [motion(w["samples"], a["instance_id"]) for a in w["samples"][0]["actors"]]
        scenes.append({"scene":scene, "follow_instance_id":w["follow_actor"],
                       "actor_count":len(roster), "samples":61,
                       "actual_simulation_seconds":w["actual_simulation_seconds"],
                       "native_ticks":w["native_ticks"], "physical_ticks":w["physical_ticks"],
                       "process_wall_seconds":case["process"]["seconds"],
                       "observation_wall_seconds":w["elapsed_wall_seconds"],
                       "actual_framebuffer_size":w["actual_framebuffer_size"],
                       "renderer":w["renderer"],"renderer_vendor":w["renderer_vendor"],
                       "draw_intervals":w["draw_intervals"],
                       "image_inventory":image_inventory,"media_inventory":media_inventory,
                       "rendered_publications":dict(frame_publications),
                       "report_sha256":case["report_sha256"],"actor_motion":all_motion})
    assert image_count == 183 and len(scenes) == 3
    result = {"schema":"ambient2-sustained-independent-readback/v1", "status":"passed",
              "reader_sha256":sha(pathlib.Path(__file__)),
              "original_artifact":{"id":14992866806,"run":45544614719,"bytes":archive.stat().st_size,
                                   "sha256":OUTER,"members":member_count},
              "application_commit":APP,"application_tree":TREE,"observer_commit":OBSERVER,
              "source_input_count":len(campaign["application"]["source_inputs_sha256"]),
              "project_input_count":855,"campaign_sha256":sha(campaign_root / "watch-campaign.json"),
              "engine":campaign["engine"],"observer_files_sha256":EXPECTED_TOOLS,
              "native_runtime":campaign["runtime"]["cybersand_runtime"],
              "rapier_runtime":campaign["runtime"]["rapier_runtime"],
              "campaign_wall_seconds":campaign["elapsed_wall_seconds"],
              "verified_raw_images":image_count,"scenes":scenes,
              "limits":["Independent receipt and original-file audit, not a fresh application execution.",
                        "Three observational Worlds and 22 actors are separate from registered 194-episode experiment.",
                        "Approximately 1 Hz sampled positions undercount path and can miss intervening intentions.",
                        "Sampled phase counts are sample frequencies, not exact durations or 10 Hz transition counts.",
                        "Motion metrics begin at requested second 3 to reduce initial settling; gait still contributes.",
                        "Frame publication stamps and current copied poses are distinct; no identical-pose assumption.",
                        "Sampled 6 fps derivative is accelerated simulation playback, not continuous hardware video.",
                        "llvmpipe draw intervals include diagnostic/PNG overhead and do not qualify physical NVIDIA playfeel."]}
    args.output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"status":result["status"],"verified_raw_images":image_count,
                     "scenes":[{k:s[k] for k in ("scene","actor_count","actual_simulation_seconds","process_wall_seconds","actual_framebuffer_size","rendered_publications")} for s in scenes]},indent=2))

if __name__ == "__main__":
    main()
