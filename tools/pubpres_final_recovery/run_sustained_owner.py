"""Five minutes of native Workbench authoring and flight in each shipped example."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from identity import ROOT, HERE, driver_identity, digest
from retained_runtime import validate_runtime
from run_comparison import prepare
from run_campaign import source_identity
from run_focus import ENGINE_SHA256, write_json
from results import distribution, need
from observer_support import execute_with_resources
from run_renderer_comparison import strict_logs
from engine_admission import add_arguments, admit

WINDOWS = ROOT / "tools/pubpres_recovery_windows"
sys.path.insert(0, str(WINDOWS))
import recovery_policy

CASES = {"wave512": (512, 1), "wave1024": (1024, 4), "wave2048": (2048, 1), "mixed2048": (2048, 4)}


def launcher_settings(case, selected):
    command = """
$ErrorActionPreference='Stop'
. ./tools/pubpres_recovery_windows/Start-PUBPRES-Final.ps1 -Library
$settings=Get-PFSettings 'C' $env:PUBPRES_OWNER_ENGINE $env:PUBPRES_OWNER_THREAD 2 'opengl3_angle' $env:PUBPRES_OWNER_SCENE 'Selected'
@{settings=$settings; config=(Get-PPOverride)} | ConvertTo-Json -Compress
"""
    return json.loads(subprocess.check_output(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command], cwd=ROOT, timeout=30,
        env={**os.environ, "PUBPRES_OWNER_ENGINE": selected["engine"], "PUBPRES_OWNER_THREAD": selected["render_thread"],
             "PUBPRES_OWNER_SCENE": case}))


def reduce_session(folder, case, source, project, engine, selected, process):
    ready = json.loads((folder / "startup.json").read_bytes())
    data = json.loads((folder / "session.json").read_bytes())
    cpu = process["process_cpu"]["summary"]
    side, bodies = CASES[case]
    need(ready["source_commit"] == data["source"] == source["source_commit"]
         and ready["process_id"] == data["process_id"] == process["observed_application_pid"]
         and ready["scene"] == data["scene"] == case and ready["extent"] == [side, side]
         and ready["authored_actor_count"] == bodies and ready["ready"] and ready["wave_flow"]["enabled"]
         and ready["native_sha256"] == source["native_runtime"]["binary_sha256"]
         and ready["engine_sha256"] == digest(engine)
         and ready["main_sha256"] == digest(project / "scripts/main.gd")
         and ready["observer_sha256"] == digest(HERE / "sustained_owner.gd")
         and ready["rapier_sha256"] == digest(project / "addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
         and ready["render_driver"] == "opengl3_angle"
         and ready["render_thread_inline"] is (selected["render_thread"] == "safe")
         and ready["recovery"]["water_enabled"] is bool(selected["water"])
         and ready["recovery"]["actual_submission_enabled"] is bool(selected["actual_submission"])
         and ready["recovery"]["task_completion"]["mode"] == "all_workers"
         and cpu["complete"] and process["exit_code"] == 0, "Installed engine, policy or native owner differs")
    duration = data["ended_usec"] - data["began_usec"]
    need(duration >= 300_000_000 and data["pulses"] == 30 and not data["failures"]
         and data["actor_count"] == bodies+1 and data["epoch"] > data["initial_epoch"]
         and all(row["accepted"] is True for row in data["actions"])
         and len([row for row in data["actions"] if row["action"].startswith("paint-")]) == 30,
         "Incomplete five-minute gameplay, authoring, or ownership handoff")
    for label in ("before", "after"):
        need(digest(folder / (label + ".png")) == data[label + "_sha256"], "Changed framebuffer " + label)
    steps = data["physical_observations"]
    samples = data["resources"]
    need(len(steps) >= 144 and all(b[0] > a[0] and b[1] > a[1] for a, b in zip(steps, steps[1:]))
         and all(data["began_usec"] <= row[1] <= row[2] <= data["ended_usec"] for row in steps)
         and len(samples) >= 59 and samples[-1]["physical_step"] > samples[-3]["physical_step"]
         and samples[-1]["native_tick"] > samples[-3]["native_tick"]
         and all(row["backend"] == "full" and row["active_slots"] == 2 and row["world"] == data["world"]
                 and row["epoch"] == data["epoch"] for row in samples), "Physical, material or resource observation failed")
    # Consecutive authenticated completions only. Missed polling intervals and intentional pauses remain separate.
    gaps = [(b[1] - a[1]) / 1000 for a, b in zip(steps, steps[1:])
            if b[0] == a[0] + 1 and a[6] == b[6] == "playing"]
    late = [(b[1] - a[1]) / 1000 for a, b in zip(steps, steps[1:])
            if b[0] == a[0] + 1 and a[6] == b[6] == "playing" and a[1] >= data["began_usec"] + 240_000_000]
    need(gaps and late, "Late sustained capture has no consecutive physical completion observations")
    return {"case": case, "duration_seconds": duration / 1e6, "completed_physical_steps": steps[-1][0]-data["initial_tick"],
            "observed_completions": len(steps), "missed_between_observations": sum(b[0]-a[0]-1 for a,b in zip(steps,steps[1:])),
            "whole_playing_gap_ms": distribution(gaps), "last_minute_playing_gap_ms": distribution(late),
            "playing_gap_counts_above_ms": {v: sum(g > v for g in gaps) for v in (100, 250, 500, 1000)},
            "frame_gap_ms": distribution([v/1000 for v in data["frames_usec"]]),
            "unique_texture_rids": len({rid for row in samples for rid in row["texture_rids"]}),
            "peak_pending_terrain_chunks_at_sample": max(row["hard_queue"] for row in samples),
            "peak_rss_bytes": process["sampled_peak_rss_bytes"], "whole_process_cpu": cpu,
            "startup_sha256": digest(folder/"startup.json"), "session_sha256": digest(folder/"session.json")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("runtime", "stock-engine", "output"):
        parser.add_argument("--" + option, type=Path, required=True)
    parser.add_argument("--case", choices=CASES, action="append")
    add_arguments(parser)
    args = parser.parse_args()
    need(os.name == "nt", "Owner scenes require actual Windows renderer and native provenance")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = source_identity(ROOT)
    source["native_runtime"] = validate_runtime(ROOT, source, args.runtime, False)
    choice = recovery_policy.selection()
    selected = recovery_policy.configuration(choice)
    engine = args.stock_engine.resolve()
    need(digest(engine) == ENGINE_SHA256["windows"], "Stock engine bytes differ")
    if selected["engine"] != "stock":
        engine, _ = admit(args)
    cases = args.case or list(CASES)
    launchers = {case: launcher_settings(case, selected) for case in cases}
    override = output / "override.cfg"
    override.write_bytes(launchers[cases[0]]["config"].encode("utf-8"))
    program = "tests/pubpres_sustained_owner.gd"
    overlays = {"tests/pubpres_playability_owner_start.gd": WINDOWS / "owner_start.gd",
                program: HERE / "sustained_owner.gd", "override.cfg": override}
    campaign = {"overlay_sha256": {name: digest(path) for name, path in overlays.items()}}
    project = prepare(ROOT, source, output / "template", campaign, args.stock_engine.resolve(), None, overlay_sources=overlays)
    strict_logs(output / "template/import")
    result = {"platform": "Windows hosted ANGLE", "source": source, "driver": driver_identity(), "policy": choice,
              "rows": [], "failures": [], "physical_acceptance": "HOLD"}
    for case in cases:
        folder = output / case
        settings = launchers[case]["settings"]
        need(launchers[case]["config"].encode("utf-8") == override.read_bytes(), "Owner override differs between scenes")
        settings["CYBERSAND_PLAYABILITY_OWNER_RECEIPT"] = str(folder / "startup.json")
        command = ["--path", str(project), "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
                   "--render-thread", selected["render_thread"], "--audio-driver", "Dummy", "--script", "res://" + program]
        try:
            print("Five-minute owner scene", case, flush=True)
            process = execute_with_resources(engine, command, folder, source["source_commit"], settings, 660)
            strict_logs(folder)
            row = reduce_session(folder, case, source, project, engine, {**selected, "water": choice["water_composition"]}, process)
            result["rows"].append(row)
        except Exception as exc:
            result["failures"].append({"case": case, "reason": str(exc)})
        write_json(output / "SUMMARY.json", result)
    return int(bool(result["failures"]))


if __name__ == "__main__":
    sys.exit(main())
