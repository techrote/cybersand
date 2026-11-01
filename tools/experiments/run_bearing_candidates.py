"""Source-bound execution/custody for the preregistered B0/Y1/A2 study."""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

import ejection_a2 as a2

ROOT=Path(__file__).resolve().parents[2]
PROTOCOL="docs/audits/granular-bearing-candidates-2026-11-01/protocol.json"
INPUTS=("godot/tests/test_granular_bearing_candidates.gd","godot/tests/test_granular_bearing_capture.gd",
        "godot/tests/test_ejection_topology_capture.gd","godot/tests/test_ejection_capsules.gd",
        "godot/tests/helpers/physical_internal_watchdog.gd","godot/scripts/rapier_physics_bridge.gd",
        "godot/scripts/rigid_body_coupling.gd","godot/scripts/cell_world.gd","godot/project.godot",
        "tools/experiments/run_bearing_candidates.py","tools/experiments/bearing_candidate_analysis.py",PROTOCOL)
INPUTS += ("tools/experiments/ejection_a2.py","tools/experiments/ejection_topology.py",
           "tools/experiments/granular_bearing_analysis.py",
           "docs/audits/granular-bearing-candidates-2026-11-01/qualification-addendum.json")

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding="utf-8"))
def git(*args):return subprocess.check_output(["git","-C",str(ROOT),*args],timeout=30)

def collect(directory,acquisition):
    """Streaming bounded parts, retaining every event, original ordinals and both identities."""
    counters=acquisition["native_counters"]
    deadline=time.monotonic()+180
    if not acquisition["complete"] or counters["dropped"] or counters["relocation_refused"]:
        raise ValueError("loss/refusal/incomplete capture blocks interpretation")
    if len(acquisition["segments"])!=10 or acquisition["fixture"]["ticks"]!=600:
        raise ValueError("incomplete600-tick/10segment record")
    fence=(counters["capture_instance_id"],counters["capture_reset_generation"])
    events=[];parts=[];batch=[];weights=Counter();reasons=Counter();native_ordinals=Counter();no_target=0
    def flush():
        if not batch:return
        name=f"capsules-{len(parts):03d}.json"
        a2.write_json(directory/name,{"schema_version":1,"candidate":acquisition["candidate"],"capsules":batch})
        parts.append({"path":name,"sha256":sha(directory/name),"capsules":len(batch)})
        batch.clear()
    with (directory/"events.jsonl").open(encoding="utf-8") as stream:
        for ordinal,line in enumerate(stream,1):
            if time.monotonic()>deadline:raise TimeoutError("registered180s collection guard")
            if ordinal>81920:raise ValueError("global event bound exceeded")
            c=json.loads(line)
            if c["candidate"]!=acquisition["candidate"] or c["event_ordinal"]!=ordinal:
                raise ValueError("mixed candidate/ordinal")
            if (c["instance_id"],c["reset_generation"])!=fence:raise ValueError("owner fence mismatch")
            segment=c["capture_segment"]
            if not 0<=segment<10:raise ValueError("segment bound")
            native_ordinals[segment]+=1
            if c["event_ordinal_native"]!=native_ordinals[segment] or c["tick"]//60!=segment:
                raise ValueError("native ordinal/segment drift")
            actual,target,trace,_=a2.production_identity(c)
            if (actual,target,trace)!=(c["replay_hash"],c["target"],c["trace"]):
                raise ValueError("production differential mismatch")
            c["topology_hash"]=a2.topology_hash(c);c["structural_hash"]=a2.structural_hash(c)
            weights[c["topology_hash"]]+=1
            no_target+=target[0]<0
            reasons.update(row[2] for row in trace)
            events.append({k:c[k] for k in ("tick","event_ordinal","event_ordinal_native","capture_segment",
                "source","target","penetration","normal","current_body","replay_hash","topology_hash")})
            batch.append(c)
            if len(batch)==500:flush()
    flush()
    if len(events)!=counters["attempts"] or no_target!=counters["searched_no_target"] or len(events)-no_target!=counters["target_found"]:
        raise ValueError("outcome accounting mismatch")
    for i,s in enumerate(acquisition["segments"]):
        if s["attempts"]!=native_ordinals[i] or not s["owner_current"] or s["dropped"]:
            raise ValueError("segment custody mismatch")
    manifest={"schema":1,"candidate":acquisition["candidate"],"parts":parts,"events":events,
              "event_multiplicities":dict(weights),"attempts":len(events),"no_target":no_target,
              "success":len(events)-no_target,"candidate_reasons":dict(reasons),"stream_drops":0,
              "reconstruction":"Each capsule retains native ordinal/segment; global ordinal is diagnostic custody. Restore native ordinal and remove added provenance/hash keys to recover original values."}
    a2.write_json(directory/"population-manifest.json",manifest)
    return manifest

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot",type=Path,required=True);p.add_argument("--project",type=Path,required=True)
    p.add_argument("--compiled-inputs",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    p.add_argument("--candidate",choices=("B0","Y1","A2"),required=True)
    p.add_argument("--arm",choices=("speed0","speed30","speed90","excavation","hard","water"),required=True)
    p.add_argument("--details",choices=("on","off"),required=True)
    args=p.parse_args()
    if git("status","--porcelain","--untracked-files=no").strip():p.error("freeze/commit source before running")
    if git("show","HEAD:"+PROTOCOL)!=Path(ROOT/PROTOCOL).read_bytes():p.error("protocol must be committed")
    compiled=read(args.compiled_inputs)
    build_receipt=args.compiled_inputs.with_name("runtime-build-receipt.json")
    built=read(build_receipt)
    if built["source_inputs"]!=compiled or built["native_sha256"]!=sha(args.project/"addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"):
        p.error("runtime bytes not bound to successful current build")
    for path,expected in compiled.items():
        if sha(ROOT/path)!=expected:p.error("native input changed since build: "+path)
    for path in INPUTS:
        if path.startswith("godot/") and sha(ROOT/path)!=sha(args.project/path[6:]):p.error("isolated project mismatch: "+path)
    directory=args.output.resolve()
    if directory.exists():p.error("preserve existing run; output must be new")
    directory.mkdir(parents=True)
    source=git("rev-parse","HEAD").decode().strip();env=os.environ.copy();env["CYBERSAND_SOURCE_REVISION"]=source
    runtime={"console_launcher":sha(args.godot),"engine":sha(args.godot.with_name(args.godot.name.replace("_console",""))),
             "native":sha(args.project/"addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
             "rapier":sha(args.project/"addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")}
    command=[str(args.godot.resolve()),"--headless","--path",str(args.project.resolve()),"--script",
             "res://tests/test_granular_bearing_candidates.gd","--","--candidate="+args.candidate,
             "--arm="+args.arm,"--details="+args.details,"--output="+directory.as_posix()]
    receipt={"schema":1,"candidate":args.candidate,"arm":args.arm,"details":args.details,"source":source,
             "successful_build_receipt_sha256":sha(build_receipt),
             "tree":git("show","-s","--format=%T","HEAD").decode().strip(),"runtime":runtime,
             "source_inputs":{s:sha(ROOT/s) for s in INPUTS},"compiled_inputs":compiled,
             "command":command,"platform":platform.platform(),"python":sys.version,"outer_seconds":150}
    try:
        with (directory/"capture.log").open("wb") as log:
            r=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=150)
        receipt["capture_exit"]=r.returncode
        if r.returncode or "ERROR:" in (directory/"capture.log").read_text(encoding="utf-8",errors="replace"):
            raise ValueError("Godot capture failed; retain original log")
        manifest=collect(directory,read(directory/"acquisition.json"))
        replays=[]
        for part in manifest["parts"]:
            report=directory/(part["path"].replace("capsules-","replay-"))
            replay_command=command[:command.index("--")+1]+["--mode=replay","--candidate="+args.candidate,
                "--capsule-input="+str(directory/part["path"]),"--replay-report="+str(report)]
            with report.with_suffix(".log").open("wb") as log:
                r=subprocess.run(replay_command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=150)
            result=read(report)
            if r.returncode or not result["ok"] or result["matched"]!=part["capsules"] or result["mutation_failures"] or result["input_sha256"]!=part["sha256"]:
                raise ValueError("replay mismatch/mutation blocks interpretation")
            result["candidate"]=args.candidate;result["command"]=replay_command
            a2.write_json(report,result)
            replays.append(result)
        receipt["replay_matches"]=sum(r["matched"] for r in replays)
        receipt["replays"]=replays;receipt["attempts"]=manifest["attempts"];receipt["ok"]=True
        receipt["artifact_sha256"]={f.name:sha(f) for f in directory.iterdir() if f.is_file() and f.suffix==".json"}
    except Exception as error:
        receipt["ok"]=False;receipt["error"]=str(error);raise
    finally:a2.write_json(directory/"receipt.json",receipt)
    print(json.dumps({"ok":True,"candidate":args.candidate,"arm":args.arm,"attempts":manifest["attempts"],"no_target":manifest["no_target"],"success":manifest["success"]}))

if __name__=="__main__":main()
