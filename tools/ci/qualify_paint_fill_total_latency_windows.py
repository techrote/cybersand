#!/usr/bin/env python3
"""Windows/NVIDIA rendered Workbench end-to-end Fill trials, with source custody.

Same experimental GDScript fixture as Linux. Designed for the owner's physical
Windows GPU and its already-qualified official Godot 4.7. This is never a
fake pre-rendered image or a non-graphical headless software-only result.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ORDER = ("native", "script", "script", "native",
         "script", "native", "native", "script")
MARKER = "PAINT_FILL_TOTAL_LATENCY "
EXPECTED_CELLS = {"16k": 128*128, "65k": 256*256, "262k": 512*512}
LINUX_NATIVE = ROOT / "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
LINUX_NATIVE_SHA256 = "64869fef128f9a6ad6102778bf4ce1923d97f7f3f8f7f49e7ae09a2d2f33fa72"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for part in iter(lambda: f.read(1024 * 1024), b""):
            h.update(part)
    return h.hexdigest()


def require(value, message):
    if not value:
        raise RuntimeError(message)


def median(rows, name):
    return statistics.median(row[name] for row in rows)


def run(args):
    require(sys.platform == "win32", "Windows owner physical GPU runner; use the Linux runner for X11")
    require(os.environ.get("SESSIONNAME"), "Windows rendered desktop session required")
    require(args.scenario in EXPECTED_CELLS, "Invalid scenario")
    require(args.godot.is_file(), "Pinned Godot binary missing")
    require(digest(LINUX_NATIVE) == LINUX_NATIVE_SHA256,
            "Desktop native LFS runtime absent or differs from published SHA-256")
    source = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    require(source == args.expected_source, "Source checkout differs from qualification SHA")
    require(not subprocess.check_output(["git","-C",str(ROOT),"diff","--name-only","HEAD","--",
                                      "godot/scripts","godot/tests","godot/native_extension"], text=True).strip(),
            "Dirty current source/test files")
    version = subprocess.check_output([str(args.godot), "--version"], text=True).strip()
    require(version == "4.7.stable.official.5b4e0cb0f", "Unexpected Godot engine version")

    args.output.mkdir(parents=True, exist_ok=True)
    report = {"schema": "paint-fill-total-latency-abba-v1",
              "status": "running", "source_commit": source, "godot_version": version,
              "native_sha256": digest(LINUX_NATIVE), "scenario": args.scenario,
              "order": list(ORDER), "rendered": True, "runner": "owner-windows-rendered", "runs": []}
    summary_path = args.output / "qualification.json"
    def persist():
        summary_path.write_text(json.dumps(report, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    persist()
    for index,mode in enumerate(ORDER,1):
        log = args.output / f"run-{index:02d}-{mode}.log"
        env = os.environ.copy()
        env["FILL_TOTAL_CASE"] = args.scenario
        env["FILL_TOTAL_CAPTURE_DIR"] = str(args.output / f"verification-{index:02d}")
        env["CYBERSAND_NATIVE_PAINT_FILL"] = "script" if mode == "script" else "native"
        # Isolate user:// settings, archives, save names from test runs.
        storage = args.output / f"user-data-{index:02d}"
        (storage / "Roaming").mkdir(parents=True, exist_ok=True)
        (storage / "Local").mkdir(parents=True, exist_ok=True)
        env["APPDATA"] = str(storage / "Roaming")
        env["LOCALAPPDATA"] = str(storage / "Local")
        command = [str(args.godot),"--rendering-method","gl_compatibility",
                   "--audio-driver","Dummy",
                   "--path",str(ROOT/"godot"),"-s",
                   "res://tests/bench_paint_fill_total_latency.gd"]
        print("RUN",args.scenario,index,mode," ".join(command),flush=True)
        with log.open("wb") as output:
            try:
                result = subprocess.run(command,cwd=ROOT,env=env,stdout=output,
                                        stderr=subprocess.STDOUT,timeout=360)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = -1
        content=log.read_text(encoding="utf-8",errors="replace")
        markers=[line[len(MARKER):] for line in content.splitlines() if line.startswith(MARKER)]
        item={"index":index,"mode":mode,"exit_code":code,"log":log.name,"log_sha256":digest(log)}
        try:
            require(code==0, f"Godot process failed/timed out with {code}")
            require(len(markers)==1, f"Expected one result marker, got {len(markers)}")
            data=json.loads(markers[0])
            require(data.get("schema")=="paint-fill-total-latency-v1","Wrong record schema")
            require(data.get("scenario")==args.scenario and data.get("mode")==mode,"Wrong scenario/mode")
            require(data.get("status")=="passed" and data.get("failures")==[],"Failed Workbench assertions")
            require(data.get("rendered") is True and data.get("image_pixel_changed") is True,
                    "Actual updated framebuffer not proved")
            require(data.get("raw_material_pixel_changed") is True
                    and data.get("changed_world_screen_samples",0) >= 32
                    and data.get("world_screen_sample_count",0) >= 256,
                    "Actual native image and 32 changed WorldView samples required")
            require(data.get("render_attempts",0)>=1
                    and data.get("first_visible_post_draw_usec",-1)>=data.get("first_post_draw_usec",0),
                    "Missing actual first visible draw identity")
            require("NVIDIA" in data.get("active_graphics_adapter","").upper(),
                    "Godot did not report an actual NVIDIA renderer in this trial")
            require(data.get("display_server")=="Windows" and data.get("rendering_driver")=="opengl3",
                    "Godot is not using the accepted Windows/OpenGL3 presentation backend")
            require(data.get("source_native") is True and data.get("capture_count")==1,
                    "Wrong native source capture")
            require(data.get("requested_cells")==EXPECTED_CELLS[args.scenario]
                    and data.get("applied")==EXPECTED_CELLS[args.scenario],
                    "Incomplete edited component")
            for name in ("capture_wall_usec","planning_wall_usec","queue_to_edit_receipt_usec",
                         "request_to_draw_usec","frame_gap_p95_usec","frame_gap_p99_usec"):
                require(type(data.get(name)) is int and data[name]>=0,
                        "Invalid duration "+name)
            require(data["capture_executor_usec"]>0 and data["native_edit_executor_usec"]>0,
                    "Native executor timings missing")
            require(data["frame_samples"]>=3 and data["render_patch_bytes"]>=0,
                    "No meaningful rendered frame samples")
            require(data["request_to_draw_usec"] >= data["planning_wall_usec"],
                    "End-to-end wall clock smaller than its planning component")
            item["result"]=data
            print("PAINT_FILL_TOTAL_CASE_PASS",args.scenario,index,mode,
                  "end_to_draw_ms",round(data["request_to_draw_usec"]/1000,3),flush=True)
        except (ValueError,KeyError,RuntimeError,TypeError) as exc:
            item["failure"]=str(exc)
            report["runs"].append(item)
            report["status"]="failed"
            persist()
            print(log.read_text(encoding="utf-8",errors="replace")[-8000:],file=sys.stderr)
            raise
        report["runs"].append(item)
        persist()
    native=[x["result"] for x in report["runs"] if x["mode"]=="native"]
    script=[x["result"] for x in report["runs"] if x["mode"]=="script"]
    require(len(native)==len(script)==4,"Incomplete balanced ABBA sequence")
    keys=("request_to_draw_usec","capture_wall_usec","planning_wall_usec",
          "queue_to_edit_receipt_usec","native_edit_executor_usec","edit_receipt_to_upload_observed_usec",
          "frame_gap_p95_usec","frame_gap_p99_usec")
    metrics={}
    for key in keys:
        metrics[key]={"native_median":median(native,key),"script_median":median(script,key)}
        if metrics[key]["native_median"]>0:
            metrics[key]["script_over_native_ratio"]=round(
                metrics[key]["script_median"]/metrics[key]["native_median"],4)
    for key in ("geometry","triplet_pack","history_preflight"):
        values={}
        for name,group in (("native",native),("script",script)):
            nums=[d.get("planning_stages_usec",{}).get(key,-1) for d in group]
            require(len(nums)==4 and all(isinstance(n,int) and n>=0 for n in nums),
                    f"Missing real {name} planning stage: {key}")
            values[name+"_median"]=statistics.median(nums)
        if values["native_median"]>0:
            values["script_over_native_ratio"]=round(values["script_median"]/values["native_median"],4)
        metrics["plan_"+key+"_usec"]=values
    report["metrics"]=metrics
    report["status"]="passed"
    report["limitations"]=[
        "Owner Windows rendered Workbench; selected Godot GPU and driver recorded in each run",
        "Measured end boundary is first frame_post_draw after matching upload revision, not physical scanout",
        "Capture, planner, apply and presentation overlap asynchronously; per-stage intervals are not additive",
        "Fixture uses fresh native 512x512 canvases; source boundary and record capacities may differ in other maps",
        "Reported ratio is total request-to-drawn latency, not gameplay FPS or pure planning speedup"
    ]
    persist()
    print("PAINT_FILL_TOTAL_ABBA",json.dumps({"status":report["status"],"scenario":args.scenario,
          "source_sha":source,"total":metrics["request_to_draw_usec"],
          "geometry":metrics["plan_geometry_usec"]}),flush=True)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot",type=Path,required=True)
    p.add_argument("--scenario",choices=EXPECTED_CELLS,required=True)
    p.add_argument("--expected-source",required=True)
    p.add_argument("--output",type=Path,required=True)
    args=p.parse_args()
    try: run(args)
    except (RuntimeError,FileNotFoundError,subprocess.SubprocessError) as exc:
        print("PAINT_FILL_TOTAL_ABBA_FAILURE",type(exc).__name__,exc,file=sys.stderr)
        raise SystemExit(1)


if __name__=="__main__":
    main()
