#!/usr/bin/env python3
"""ENG-LAB Test It: exact native/Godot 4.7 graphical 2048² owner-fixture smoke."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
PIN="4.7.stable.official.5b4e0cb0f"
SOURCE_FILE="godot/tests/fixtures/engine_lab/setup-gate-canvas.json"
REFERENCE="b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954"
MATERIAL="71610b37531531e284f069cf1e07c151283a441c9b0ff32a4fcc1dbb6c997a7a"

def sha(path: Path)->str:
    with path.open("rb") as f: return hashlib.file_digest(f,"sha256").hexdigest()

def main()->int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot",required=True,type=Path)
    p.add_argument("--expected-sha",required=True)
    p.add_argument("--output",required=True,type=Path)
    p.add_argument("--rendering-driver",default="opengl3_angle" if sys.platform=="win32" else "opengl3")
    p.add_argument("--timeout",type=int,default=900)
    args=p.parse_args()
    out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=True)
    target=out/"summary.json"
    if target.exists():p.error("Refuse overwrite")
    report={"schema":"eng-lab-scripted-smoke-v1","source":None,"complete":False}
    try:
        source=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True,timeout=40).strip()
        if source != args.expected_sha:raise RuntimeError("source HEAD mismatch")
        report["source"]=source
        engine=args.godot.resolve(strict=True)
        version=subprocess.check_output([str(engine),"--version"],cwd=ROOT,text=True,timeout=40).strip()
        if version!=PIN:raise RuntimeError("Godot 4.7 mismatch")
        report["godot_sha256"]=sha(engine)
        if sha(ROOT/SOURCE_FILE)!=REFERENCE:raise RuntimeError("Owner fixture source bytes changed")
        platform="windows" if sys.platform=="win32" else "linux"
        name="cybersand_native.windows.x86_64.dll" if platform=="windows" else "libcybersand_native.linux.x86_64.so"
        manifest=ROOT/"godot/addons/cybersand_native"/("runtime-provenance.json" if platform=="windows" else "runtime-provenance.linux.json")
        native=ROOT/"godot/addons/cybersand_native/bin"/name
        if sha(native)!=json.loads(manifest.read_text())["sha256"]:
            raise RuntimeError("Native source-matched runtime invalid")
        report["native_sha256"]=sha(native)
        env={**os.environ,"GODOT_SILENCE_ROOT_WARNING":"1","CYBERSAND_SOURCE_REVISION":source}
        init=subprocess.run([str(engine),"--headless","--path",str(ROOT/"godot"),"--editor","--quit"],
                            cwd=ROOT,capture_output=True,text=True,timeout=240,env=env)
        (out/"import.log").write_text(init.stdout+"\n---stderr---\n"+init.stderr)
        if init.returncode:raise RuntimeError("Source project import failed")
        receipt=out/"freemass-1worker.json"
        cli=[str(engine),"--rendering-driver",args.rendering_driver,
             "--rendering-method","gl_compatibility","--audio-driver","Dummy","--max-fps","60",
             "--path",str(ROOT/"godot"),"--script","res://tests/bench_engine_lab_test_it.gd",
             "--","--family=freemass","--workers=1","--repeat=1",
             "--engine-lab-scripted","--receipt="+str(receipt)]
        start=time.monotonic()
        try:
            process=subprocess.run(cli,cwd=ROOT,capture_output=True,text=True,errors="replace",
                                   timeout=args.timeout,env=env)
            log=process.stdout+"\n---stderr---\n"+process.stderr
            ret=process.returncode
        except subprocess.TimeoutExpired as e:
            log="TIMEOUT "+str(e)+"\n"+str(e.stdout)+"\n"+str(e.stderr)
            ret=-1
        (out/"scripted.log").write_text(log,encoding="utf-8")
        report["elapsed_seconds"]=round(time.monotonic()-start,3)
        report["exit_code"]=ret
        if receipt.exists():
            data=json.loads(receipt.read_text(encoding="utf-8"))
            report["case_status"]=data.get("status")
            report["failures"]=data.get("failures")
            report["input_events"]=data.get("input_tape",{}).get("observed",{}).get("events")
            report["reference"]=data.get("reference")
            report["actor"]=data.get("actor",{}).get("last")
            report["native_hz"]=data.get("benchmark",{}).get("actual_native_hz")
            report["rapier_hz"]=data.get("benchmark",{}).get("actual_rapier_hz")
            report["receipt_sha256"]=sha(receipt)
        if ret or not receipt.exists():
            raise RuntimeError("Real graphical Test It failed; see full transcript and receipt")
        d=json.loads(receipt.read_text(encoding="utf-8"))
        if (d.get("status")!="passed" or d.get("reference",{}).get("json_sha256")!=REFERENCE
            or d["reference"].get("generated_material_sha256")!=MATERIAL
            or d["reference"].get("native_receipts")!=256
            or not d["input_tape"]["complete"]
            or len(d["input_tape"]["observed"]["events"])!=8
            or d.get("world_size")!=[2048,2048]
            or d["benchmark"]["native_ticks"]<=0 or d["benchmark"]["rapier_steps"]<=0
            or d["benchmark"]["identity"].get("source_revision")!=source):
            raise RuntimeError("Missing exact reference, input admission or true physics-rate receipts")
        report["complete"]=True
    except Exception as e:
        report["error"]=f"{type(e).__name__}: {e}"
        print(report["error"],file=sys.stderr)
    finally:
        target.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("ENG_LAB_SCRIPTED_SMOKE ", "PASS" if report["complete"] else "FAIL",flush=True)
    return 0 if report["complete"] else 1

if __name__=="__main__":
    raise SystemExit(main())
