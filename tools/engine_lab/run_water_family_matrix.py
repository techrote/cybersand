#!/usr/bin/env python3
"""ENG-LAB-001 Phase B: independent real Workbench/Needle four-Water-family matrix.

Fresh Godot process for each family and 1/4-worker arm. No injected actor input,
engine pacing change, RENDER-ACK gating, alternate native authority or mock World.
Record matched host identity and raw per-frame proof; do not infer a preferred
solver from software-rendered CI or naive pooled averages.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
PIN = "4.7.stable.official.5b4e0cb0f"
FAMILIES = ("freemass", "pressure", "cellular", "inertial")
RENDER = "res://tests/bench_engine_lab_water_family.gd"
MARKER = re.compile(r"ENGINE_LAB_WATER:\s*(\{[^\n]*\})")


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def command(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, timeout=40,
                                   text=True, stderr=subprocess.PIPE).strip()


def summarize_float(values: list[float]) -> dict:
    if not values:
        return {"count":0}
    v = sorted(values)
    def pick(q: float) -> float:
        return v[max(0, min(len(v)-1, int((len(v)-1)*q)))]
    return {"count":len(v), "mean":round(statistics.mean(v),3),
            "min":round(v[0],3), "median":round(pick(.5),3),
            "p95":round(pick(.95),3), "max":round(v[-1],3)}


def per_second(bench: dict) -> list[dict]:
    """Synchronized wall bins, not causal stage attribution."""
    samples = bench.get("raw_samples",[])
    if len(samples) < 3:
        return []
    start = int(samples[0]["at_usec"])
    buckets: dict[int,list[dict]] = defaultdict(list)
    for row in samples:
        buckets[(int(row["at_usec"])-start)//1_000_000].append(row)
    out = []
    for second, rows in sorted(buckets.items()):
        if len(rows) < 2:
            continue
        before, after = rows[0], rows[-1]
        elapsed = max(1e-9,(after["at_usec"]-before["at_usec"])/1_000_000)
        native = (after["native_tick"]-before["native_tick"])/elapsed
        rapier = (after["rapier_steps"]-before["rapier_steps"])/elapsed
        fields = ("workbench_sample","workbench_terrain","workbench_no_snapshot","lockstep")
        holds = {k:max(0,int(after.get("hold_counts",{}).get(k,0)) -
                          int(before.get("hold_counts",{}).get(k,0))) for k in fields}
        intervals = [(rows[i]["at_usec"]-rows[i-1]["at_usec"])/1000
                     for i in range(1,len(rows))]
        out.append({"wall_second":second, "duration_seconds":round(elapsed,4),
                    "native_hz":round(native,3),"rapier_hz":round(rapier,3),
                    "render_publications":after["render_serial"]-before["render_serial"],
                    "holds":holds, "frame_interval_ms":summarize_float(intervals)})
    return out


def observe_clock_signature(row: dict) -> dict:
    seconds = row.get("clock_bins",[])
    labels = []
    for sample in seconds:
        n, r = sample["native_hz"], sample["rapier_hz"]
        holds = sample.get("holds",{})
        sample_holds = holds.get("workbench_sample",0)
        terrain_holds = holds.get("workbench_terrain",0)
        if n < 45 and r < 45:
            code = "native-and-rapier-throughput-below-target"
        elif n >= 50 and r < 45 and sample_holds > 0:
            code = "rapier-fence-candidate"
        elif n >= 50 and r >= 50 and sample["frame_interval_ms"].get("p95",0)>33:
            code = "presentation-cadence-candidate"
        elif terrain_holds > 0:
            code = "terrain-install-candidate"
        else:
            code = "not-localized-or-near-target"
        labels.append({"wall_second":sample["wall_second"],"observation":code})
    return {"first_observation": labels[0] if labels else None,
            "timeline": labels,
            "status":"advisory-only; windows do not establish causality or GPU execution completion"}


def case(godot: Path, out: Path, source: str, driver: str,
         family: str, workers: int, repetition: int, timeout: int) -> dict:
    name = f"w{workers}-r{repetition}-{family}"
    receipt = out / f"{name}.json"
    logfile = out / f"{name}.log"
    user_data = out / f"{name}-userdata"
    user_data.mkdir(exist_ok=False)
    cmd = [str(godot), "--audio-driver","Dummy", "--rendering-driver",driver,
           "--max-fps","60", "--path",str(ROOT/"godot"),
           "--script",RENDER,"--",
           f"--family={family}",f"--workers={workers}",f"--repeat={repetition}",
           "--receipt="+str(receipt)]
    start = time.monotonic()
    try:
        proc = subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True,
                              errors="replace",timeout=timeout,
                              env={**os.environ,"GODOT_SILENCE_ROOT_WARNING":"1",
                                   "XDG_DATA_HOME":str(user_data),"APPDATA":str(user_data),
                                   "CYBERSAND_SOURCE_REVISION":source})
        log = proc.stdout+"\n--- stderr ---\n"+proc.stderr
        status = proc.returncode
    except subprocess.TimeoutExpired as exc:
        status = -1
        log = f"EXTERNAL_TIMEOUT: {exc}\nstdout={exc.stdout}\nstderr={exc.stderr}\n"
    logfile.write_text(log,encoding="utf-8")
    result = {"name":name,"family":family,"workers":workers,"repeat":repetition,
              "duration_seconds":round(time.monotonic()-start,3),
              "returncode":status,"log_sha256":sha(logfile),
              "receipt_exists":receipt.is_file(),"ok":False}
    if receipt.is_file():
        data = json.loads(receipt.read_text(encoding="utf-8"))
        result["receipt_sha256"] = sha(receipt)
        result["fixture_sha256"] = data.get("fixture_sha256")
        result["applied_family"] = data.get("applied_native_policy",{}).get("assignments",[])
        result["requested_radius"] = data.get("minimum_native_rule_radius")
        result["source_revision"] = data.get("benchmark",{}).get("identity",{}).get("source_revision")
        benchmark = data.get("benchmark",{})
        result.update({"benchmark": benchmark,
                       "native_hz":benchmark.get("actual_native_hz"),
                       "rapier_hz":benchmark.get("actual_rapier_hz"),
                       "native_ticks":benchmark.get("native_ticks"),
                       "rapier_steps":benchmark.get("rapier_steps"),
                       "frames":benchmark.get("frame_count"),
                       "render_publications":benchmark.get("accepted_publications_observed"),
                       "frame_p95_ms":benchmark.get("frame_interval_ms",{}).get("p95"),
                       "native_tick_p95_ms":benchmark.get("native_completed_tick_cost_ms",{}).get("p95"),
                       "render_age_p95_ms":benchmark.get("render_payload_age_at_frame_ms",{}).get("p95"),
                       "hold_counts":benchmark.get("coupling_held_physics_frames",{}),
                       "clock_bins":per_second(benchmark)})
        result["attribution"] = observe_clock_signature(result)
        identity = benchmark.get("identity",{})
        result["identity"] = {
            "source_revision":identity.get("source_revision"),
            "main_sha256":identity.get("main_script_sha256"),
            "worker_sha256":identity.get("worker_script_sha256"),
            "native_sha256":identity.get("native_runtime_sha256"),
            "window":identity.get("window_size"),
            "world_extent":identity.get("world_extent"),
            "video_adapter":identity.get("video_adapter"),
            "rendering_driver":identity.get("rendering_driver"),
            "rendering_method":identity.get("rendering_method"),
            "engine":identity.get("engine"),
            "native_workers_configured":identity.get("native_workers_configured"),
            "water_policy":identity.get("liquid_solver_policy"),
        }
        expected = {"freemass":"freemass_v1","pressure":"pressure_flow_v1",
                    "cellular":"cellular_yield_v1","inertial":"inertial_cellular_v1"}[family]
        water = [row for row in data.get("applied_native_policy",{}).get("assignments",[])
                 if int(row.get("material",-1)) == 3]
        matches = (len(water)==1 and water[0].get("applied_family")==expected
                   and water[0].get("applied_variant")==("cached_dormant" if family=="pressure" else "reference"))
        result["ok"] = (status==0 and data.get("ok") is True
                        and not data.get("failures") and benchmark.get("status")=="passed"
                        and matches and identity.get("source_revision")==source
                        and data.get("active_actor_tick",0)>0
                        and benchmark.get("native_ticks",0)>0
                        and benchmark.get("rapier_steps",0)>0
                        and benchmark.get("frame_count",0)>10
                        and identity.get("world_extent")==[1024,1024]
                        and all(isinstance(x,int) and x >= minimum for x,minimum in zip(data.get("window_size",[]),[900,600]))
                        and len(data.get("window_size",[])) == 2
                        and int(data.get("native_worker_request_readback",-1))==workers)
        result["failures"] = data.get("failures",[])
    print(f"{name}: {'PASS' if result['ok'] else 'FAIL'} "
          f"{result.get('native_hz','?')} native Hz, "
          f"{result.get('rapier_hz','?')} Rapier Hz, "
          f"frame p95 {result.get('frame_p95_ms','?')} ms",flush=True)
    return result


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot",required=True,type=Path)
    p.add_argument("--expected-sha",required=True)
    p.add_argument("--output",required=True,type=Path)
    p.add_argument("--rendering-driver",default="opengl3_angle" if sys.platform=="win32" else "opengl3")
    p.add_argument("--mode",choices=["smoke","full"],default="smoke")
    p.add_argument("--case-timeout",type=int,default=300)
    args = p.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True,exist_ok=True)
    target = out / "summary.json"
    if target.exists():
        p.error("Refusing to overwrite existing research evidence")
    report = {"schema":"eng-lab-001-four-water-family-graphical-v1",
              "mode":args.mode,"source":None,"complete":False,
              "scope":"Real 1024-square 1-Needle, two Water reservoirs, fixed no-input, native Workbench/Rapier/ImageTexture. Software backend if hosted.",
              "qualification":"No solver ranking or causal result without positive valid receipts",
              "case_order":[],"cases":[],"comparisons":{}}
    try:
        source = command("git","rev-parse","HEAD")
        if source != args.expected_sha:
            raise ValueError("Expected exact HEAD, got "+source)
        if command("git","status","--porcelain"):
            raise ValueError("Dirty source is not a reproducible benchmark")
        report["source"] = source
        godot = args.godot.resolve(strict=True)
        version = command(str(godot),"--version")
        if version != PIN:
            raise ValueError("Godot version mismatch "+version)
        platform = "windows" if sys.platform=="win32" else "linux"
        filename = "cybersand_native.windows.x86_64.dll" if platform=="windows" else "libcybersand_native.linux.x86_64.so"
        native = ROOT/"godot/addons/cybersand_native/bin"/filename
        provenance = ROOT/"godot/addons/cybersand_native"/(
            "runtime-provenance.json" if platform=="windows" else "runtime-provenance.linux.json")
        manifest = json.loads(provenance.read_text(encoding="utf-8"))
        if native.stat().st_size<1024 or sha(native)!=manifest.get("sha256"):
            raise ValueError("Native runtime bytes or provenance mismatch")
        report["runtime"]={"engine":version,"godot_sha256":sha(godot),
                           "native_sha256":sha(native),"native_source":manifest.get("source_commit")}
        import_cmd=[str(godot),"--headless","--path",str(ROOT/"godot"),"--editor","--quit"]
        proc=subprocess.run(import_cmd,cwd=ROOT,capture_output=True,text=True,timeout=240,
                            env={**os.environ,"GODOT_SILENCE_ROOT_WARNING":"1"})
        import_log = out/"import.log"
        import_log.write_text(proc.stdout+"\n---stderr---\n"+proc.stderr,encoding="utf-8")
        report["import"]={"returncode":proc.returncode,"log_sha256":sha(import_log)}
        if proc.returncode:
            raise RuntimeError("Godot source project import failed")
        if args.mode=="smoke":
            plans=[("freemass",1,1)]
        else:
            plans=[]
            for workers,order in [
                (1,("freemass","pressure","cellular","inertial")),
                (4,("cellular","inertial","freemass","pressure")),
            ]:
                plans.extend((family,workers,1) for family in order)
                plans.extend((family,workers,2) for family in reversed(order))
        report["case_order"]=[f"w{w}-r{r}-{f}" for f,w,r in plans]
        fixture=None
        first_identity=None
        for family,workers,repetition in plans:
            data=case(godot,out,source,args.rendering_driver,
                      family,workers,repetition,args.case_timeout)
            report["cases"].append(data)
            target.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n",encoding="utf-8")
            if not data["ok"]:
                raise RuntimeError(data["name"]+" invalid/failing case; preserve all raw files")
            if fixture is None:
                fixture=data["fixture_sha256"]
                first_identity=data["identity"]
                report["fixture_sha256"]=fixture
            if data["fixture_sha256"]!=fixture:
                raise RuntimeError("Authored starting setup/actor/layout differs across policy arms")
            for field in ("source_revision","main_sha256","worker_sha256","native_sha256",
                          "window","world_extent","video_adapter","rendering_driver","rendering_method","engine"):
                if data["identity"][field]!=first_identity[field]:
                    raise RuntimeError("Matched same-host comparison fails immutable field: "+field)
        if args.mode=="full":
            groups: dict[str,dict[int,list[dict]]] = defaultdict(lambda:defaultdict(list))
            for row in report["cases"]:
                groups[row["family"]][row["workers"]].append(row)
            if any(len(groups[family][worker])!=2 for family in FAMILIES for worker in (1,4)):
                raise RuntimeError("Incomplete/duplicated family x worker x repeat lattice")
            for family in FAMILIES:
                for worker in (1,4):
                    arm=groups[family][worker]
                    report["comparisons"][f"{family}-w{worker}"]={
                        "native_hz":summarize_float([r["native_hz"] for r in arm]),
                        "rapier_hz":summarize_float([r["rapier_hz"] for r in arm]),
                        "frame_p95_ms":summarize_float([r["frame_p95_ms"] for r in arm]),
                        "native_tick_p95_ms":summarize_float([r.get("native_tick_p95_ms",0) or 0 for r in arm]),
                        "render_age_p95_ms":summarize_float([r.get("render_age_p95_ms",0) or 0 for r in arm]),
                        "raw_case_refs":[r["name"] for r in arm],
                    }
        report["complete"] = True
    except Exception as e:
        report["error"]=type(e).__name__+": "+str(e)
        print(report["error"],file=sys.stderr,flush=True)
    finally:
        target.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    return 0 if report["complete"] else 1


if __name__=="__main__":
    raise SystemExit(main())
