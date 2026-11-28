#!/usr/bin/env python3
"""Bounded, source-identified ordinary Workbench Place/Reset/Restore observation.

Uses the selected production settings and existing owner collector. Headless
runs are explicit diagnostics; they cannot satisfy graphical acceptance. Stages
committed application source with an independently admitted native build.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))
from process_owner import bounded_process


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def metrics(values):
    values = sorted(values)
    if not values:
        return None
    # Match the established completion-gap readers' nearest-rank convention.
    # A tiny adverse sample must not lose its tail through floor interpolation.
    return {"count": len(values), "p50_usec": values[math.ceil(len(values)*.50)-1],
            "p95_usec": values[math.ceil(len(values)*.95)-1],
            "p99_usec": values[math.ceil(len(values)*.99)-1], "maximum_usec": values[-1]}


def reduce(folder: Path, report):
    rows = []
    for path in sorted(folder.glob("segment-*.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            value = json.loads(line)
            if isinstance(value, list):
                rows.append(value)
    rows.sort(key=lambda row: row[1])
    lost = [r for r in rows if r[0] == "loss"]
    step_times = [r[1] for r in rows if r[0] == "step"]
    draw_times = [r[1] for r in rows if r[0] == "draw"]
    cases = []
    for case in report["cases"]:
        start, end = case["request_usec"], case.get("end_usec", case["request_return_usec"])
        def gaps(times, context=False):
            # A completed interval belongs to the case in which it ends. Keep
            # the gap across this request, but do not attribute the following
            # case's spawn to this case's tail. The original both-boundary
            # distribution remains visible as context.
            return [b-a for a, b in zip(times, times[1:]) if b >= start and (a <= end if context else b <= end)]
        def suffix(times):
            previous = [value for value in times if value <= end]
            return end-previous[-1] if previous else None
        exact = [r for r in rows if r[0] == "step" and r[1] >= start and r[5] == case.get("epoch")]
        phases = [{"phase":r[2], "completed_usec":r[1], "duration_usec":r[9], "details":r[10]}
                  for r in rows if r[0] == "spawn" and r[3] == case["request_serial"] and start <= r[1] <= end]
        result = {"label": case["label"], "accepted":case["accepted"],
                  "request_latency_usec":case["request_return_usec"]-start,
                  "owner_admission_observed_usec":case["admitted_usec"]-start if case["admitted_usec"] >= 0 else None,
                  "first_completed_step_usec": exact[0][1]-start if exact else None,
                  "first_observed_step_upper_bound_usec":case["first_observed_step_usec"]-start if case["first_observed_step_usec"] >= 0 else None,
                  "first_coherent_draw_observed_usec":case["first_coherent_draw_observed_usec"]-start if case["first_coherent_draw_observed_usec"] >= 0 else None,
                  "input_admission_observed_usec":case["input_accepted_observed_usec"]-case["first_input_usec"] if case["input_accepted_observed_usec"] >= 0 else None,
                  "input_physical_application_observed_usec":case["input_applied_observed_usec"]-case["first_input_usec"] if case["input_applied_observed_usec"] >= 0 else None,
                  "input_upward_pose_response_observed_usec":case["input_response_observed_usec"]-case["first_input_usec"] if case.get("input_response_observed_usec",-1) >= 0 else None,
                  "physical_gaps":metrics(gaps(step_times)), "draw_callback_gaps":metrics(gaps(draw_times)),
                  "physical_gap_context_both_boundaries":metrics(gaps(step_times,True)),
                  "physical_unfinished_suffix_usec":suffix(step_times),
                  "draw_callback_gap_context_both_boundaries":metrics(gaps(draw_times,True)),
                  "draw_callback_unfinished_suffix_usec":suffix(draw_times),
                  "observed_draw_callback_gaps":metrics(gaps(report.get("draw_callback_usec",[]))),
                  "observed_draw_callback_gap_context_both_boundaries":metrics(gaps(report.get("draw_callback_usec",[]),True)),
                  "observed_draw_callback_unfinished_suffix_usec":suffix(report.get("draw_callback_usec",[])),
                  "process_sampled_completion_gaps_upper_bound":metrics(gaps(report.get("observed_completion_usec",[]))),
                  "phases":phases}
        owned_times = [r[1] for r in exact if r[1] <= end]
        tail = [b-a for a,b in zip(owned_times,owned_times[1:]) if a >= end-1_000_000]
        cadence = metrics(tail)
        result["last_second_physical_gaps"] = cadence
        # Explicit descriptive settlement rule; this does not waive the
        # separately registered p95/max physical acceptance objectives.
        band = max(50_000,2*cadence["p50_usec"]) if cadence else None
        settled = None
        if band is not None:
            for offset in range(12,len(owned_times)):
                window = owned_times[offset-12:offset+1]
                if max(b-a for a,b in zip(window,window[1:])) <= band:
                    settled = window[-1]-start
                    break
        result["cadence_return"] = {"completed_usec_after_request":settled,"consecutive_intervals":12,
                                    "maximum_interval_usec":band,"reference":"last-second p50 x2, minimum50ms"}
        admitted = case["admitted_usec"]
        seconds = (end-admitted)/1e6 if admitted >= 0 and end > admitted else 0
        result["post_admission"] = {"wall_seconds":seconds,
            "physical_steps_per_second":(case["final_rapier_steps"]-case["admission_rapier_steps"])/seconds
                if seconds and "admission_rapier_steps" in case and "final_rapier_steps" in case else None,
            "native_ticks_per_second":(case["final_native_tick"]-case["admission_native_tick"])/seconds
                if seconds and "admission_native_tick" in case and "final_native_tick" in case else None}
        result["post_admission"]["simulated_seconds_per_wall_second"] = (
            result["post_admission"]["physical_steps_per_second"] * case["physical_delta_seconds"]
            if result["post_admission"]["physical_steps_per_second"] is not None and "physical_delta_seconds" in case else None)
        cases.append(result)
    return {"cases":cases,"recorder_loss_intervals":lost,"recorder_closed":any(r[0]=="close" for r in rows),
            "recorded_actual_steps":len(step_times),
            "recorded_draw_callbacks":len(draw_times),
            "whole_recording_physical_gaps":metrics([b-a for a,b in zip(step_times,step_times[1:])]),
            "whole_observer_draw_gaps":metrics([b-a for a,b in zip(report.get("draw_callback_usec",[]),report.get("draw_callback_usec",[])[1:])]),
            "scope":"Primary gaps end within this case, retaining the interval across its request. Both-boundary context preserves a following-case interval. Unfinished suffixes are right-censored lower bounds, not completed gaps. Whole-recording maxima remain. Headless draw fields remain null. CPU callbacks are not GPU duration or physical display. Loss means observed tails are incomplete. First process-frame step is an upper bound; actual step rows supply exact completion times when recording is enabled."}


def complete_recording(reduced, graphical):
    return (reduced["recorder_closed"] and not reduced["recorder_loss_intervals"]
            and reduced["recorded_actual_steps"] > 0
            and (not graphical or reduced["recorded_draw_callbacks"] > 0)
            and all(row["first_completed_step_usec"] is not None and row["physical_gaps"] is not None
                    for row in reduced["cases"] if row["accepted"]))


def stage(source_root: Path, runtime: Path, engine: Path, output: Path):
    import common
    sys.path.insert(0,str(ROOT / "tools/pubpres003"))
    from run_focus import stage_committed_project, ENGINE_SHA256
    platform = common.platform_name()
    source = common.source_identity(source_root)
    common.require(digest(engine)==ENGINE_SHA256[platform],"Engine differs from the pinned Godot4.7 executable")
    project = stage_committed_project(source_root,source["source_commit"],output / "template")
    common.install_runtime(source_root,runtime,project,platform)
    rapier_relative = common.RAPIER[platform].removeprefix("godot/")
    shutil.copyfile(source_root / common.RAPIER[platform],project / rapier_relative)
    native = common.observed_runtime(source_root,runtime,project,platform)
    recipes = project.parent / "examples/worldgen"
    if recipes.is_dir(): shutil.copytree(recipes,project / "authoring/worldgen",dirs_exist_ok=True)
    fixtures = {"tests/pubpres_playability_owner_start.gd": ROOT / "tools/pubpres_recovery_windows/owner_start.gd",
                "tests/pubpres_spawn_latency.gd":Path(__file__).with_name("spawn_latency.gd")}
    for name,path in fixtures.items(): shutil.copyfile(path,project / name)
    authored = {p.relative_to(project).as_posix():digest(p) for p in project.rglob("*") if p.is_file()}
    # Use the same owned-process timeout boundary as the accepted build tools.
    with (output / "import.log").open("x",encoding="utf-8") as stream:
        code,timed_out = bounded_process([str(engine),"--headless","--audio-driver","Dummy","--path",str(project),
                                         "--editor","--import"],cwd=ROOT,stdout=stream,timeout=300)
    bootstrap = {".godot/global_script_class_cache.cfg",".godot/extension_list.cfg"}
    mutations = [name for name,expected in authored.items() if name not in bootstrap and digest(project / name)!=expected]
    common.write_json(output / "source-custody.json",{"source":source,"authored_files_sha256":authored,
        "authored_mutations":mutations,"native_overlay":native,"fixtures":{n:digest(p) for n,p in fixtures.items()}})
    common.require(not code and not timed_out and not mutations,"Committed project import failed or changed authored inputs")
    common.require(not any(marker in (output / "import.log").read_text(encoding="utf-8",errors="replace")
        for marker in ("SCRIPT ERROR:","Parse Error:","Failed to load script")),"Committed project has an import script failure")
    return project,source,native,fixtures


def driver_identity():
    import common
    paths = [Path(__file__),Path(__file__).with_name("spawn_latency.gd"),Path(common.__file__),
             ROOT / "tools/pubpres_recovery_windows/owner_start.gd"]
    values = {}
    for path in paths:
        name = path.relative_to(ROOT).as_posix()
        committed = common.git(ROOT,"show","HEAD:"+name)
        common.require(path.read_bytes().replace(b"\r\n",b"\n")==committed.replace(b"\r\n",b"\n"),
                       "Spawn driver differs from committed source: "+name)
        values[name] = digest(path)
    return {**common.source_identity(ROOT),"files_sha256":values}


def main():
    import common
    sys.path.insert(0,str(ROOT / "tools/pubpres_final_observers"))
    from execute_with_resources import execute_with_resources
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source", help="Optional expected application revision; must equal source-root HEAD")
    parser.add_argument("--scene", action="append", choices=("wave512","wave1024","wave2048","mixed2048"))
    parser.add_argument("--recording", choices=("on","off","both"), default="both")
    parser.add_argument("--recording-order", choices=("on-off","off-on"), default="on-off",
                        help="Order of the two independent processes when --recording both")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--timeout", type=int, default=480)
    args = parser.parse_args()
    source_root,runtime,engine,output = args.source_root.resolve(),args.runtime.resolve(),args.engine.resolve(),args.output.resolve()
    common.require(not output.is_relative_to(source_root),"Keep staged execution and original evidence outside the source checkout")
    output.mkdir(parents=True, exist_ok=False)
    if args.source:
        common.require(args.source==common.source_identity(source_root)["source_commit"],"Requested source differs from committed checkout")
    try:
        driver = driver_identity()
        project,source_record,native,fixtures = stage(source_root,runtime,engine,output)
    except Exception as error:
        common.write_json(output / "ADMISSION-FAILED.json",{"error":str(error),"pass":False})
        raise
    source = source_record["source_commit"]
    identities = {"source":source,"source_tree":source_record["source_tree"],"engine_sha256":digest(engine),
                  "native_sha256":native["cybersand_runtime"]["sha256"],"native_custody":native,
                  "main_sha256":digest(project / "scripts/main.gd"),
                  "fixtures":{name:digest(path) for name,path in fixtures.items()},"selected":common.SELECTORS,
                  "driver":driver,
                  "graphical":not args.headless}
    (output / "IDENTITY.json").write_text(json.dumps(identities,indent=2)+"\n",encoding="utf-8")
    modes = tuple(args.recording_order.split("-")) if args.recording == "both" else (args.recording,)
    results = []
    summary = {"schema":"pubpres-spawn-qualification-v2","identity":identities,"results":results,
               "pass":False,"physical_hardware_acceptance":False}
    for scene in args.scene or ("wave512","mixed2048"):
        for mode in modes:
            folder = output / (scene+"-"+mode)
            profile = folder / "profile"
            startup = folder / "startup.json"
            settings = dict(common.SELECTORS)
            settings.update(CYBERSAND_SOURCE_REVISION=source,CYBERSAND_FINAL_SCENE=scene,
                       CYBERSAND_PLAYABILITY_OWNER_RECEIPT=str(startup),CYBERSAND_PLAYABILITY_OWNER_RECORDING="1" if mode == "on" else "0")
            cmd = ["--path",str(project),"--resolution","1280x720","--audio-driver","Dummy",
                   "--render-thread","safe","--script","res://tests/pubpres_spawn_latency.gd"]
            if args.headless: cmd.append("--headless")
            else: cmd.extend(["--rendering-method","gl_compatibility","--rendering-driver","opengl3_angle" if os.name == "nt" else "opengl3"])
            execution_error = None
            process = {}
            try:
                process = execute_with_resources(engine,cmd,folder,source,settings,args.timeout)
            except Exception as error:
                execution_error = str(error)
                if (folder / "process.json").is_file(): process = json.loads((folder / "process.json").read_bytes())
            code,timed_out = process.get("exit_code"),process.get("timed_out",False)
            for segment in profile.rglob("pubpres-gameplay/segment-*.jsonl"):
                shutil.copyfile(segment,folder / segment.name)
            ok = code == 0 and not timed_out and execution_error is None and startup.is_file() and (folder / "spawn.json").is_file()
            detail = {"scene":scene,"recording":mode,"exit_code":code,"timed_out":timed_out,"pass":False,"execution_error":execution_error}
            if startup.is_file() and (folder / "spawn.json").is_file():
                report = json.loads((folder / "spawn.json").read_bytes())
                ready = json.loads(startup.read_bytes())
                ok = (ok and report["pass"] and report["source"] == source and report["engine_sha256"] == identities["engine_sha256"]
                      and report["native_sha256"] == identities["native_sha256"] and report["graphical"] == (not args.headless)
                      and ready["main_sha256"] == identities["main_sha256"] and ready["scene"] == scene
                      and ready["observer_sha256"] == identities["fixtures"]["tests/pubpres_spawn_latency.gd"]
                      and ready["rapier_sha256"] == native["rapier_runtime"]["sha256"]
                      and ready["source_commit"] == source and ready["process_id"] == report["process_id"] == process.get("observed_application_pid")
                      and ready["material_publication"]["backend"] == "full" and ready["material_publication"]["full_image_slots"] == 2
                      and ready["recovery"]["task_completion"]["mode"] == "all_workers"
                      and ready["flight_pacing_enabled"] and ready["coupling_clock_enabled"] and ready["empty_effects_enabled"]
                      and ready["render_thread_inline"] and ready["recovery"]["water_enabled"]
                      and process.get("process_cpu",{}).get("summary",{}).get("complete",False)
                      and len(report["cases"]) == 6
                      and all(case.get("final_rapier_steps",-1)-case.get("admission_rapier_steps",-1)
                              == case.get("final_physical_steps",-2)-case.get("admission_physical_step",-1)
                              and case.get("physical_delta_seconds",0) > 0 for case in report["cases"])
                      and len(report.get("draw_callback_usec",[])) < 20000
                      and len(report.get("observed_completion_usec",[])) < 20000)
                reduced = reduce(folder,report)
                (folder / "REDUCED.json").write_text(json.dumps(reduced,indent=2)+"\n",encoding="utf-8")
                detail["recorder_complete"] = complete_recording(reduced,not args.headless) if mode == "on" else None
                detail["failures"] = report["failures"]
                if mode == "on": ok &= any(folder.glob("segment-*.jsonl")) and detail["recorder_complete"]
                else: ok &= not any(folder.glob("segment-*.jsonl"))
            detail["pass"] = bool(ok)
            results.append(detail)
            common.write_json(output / "SUMMARY.json",summary)
            print(json.dumps(detail),flush=True)
    summary["pass"] = all(r["pass"] for r in results)
    (output / "SUMMARY.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    return 0 if summary["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
