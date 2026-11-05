#!/usr/bin/env python3
"""Source-pinned SOL-ENERGY-001: isolated pure Godot planner, no native addons."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
BASE="e4c2649e82d943554f4dc6a0634336770cda08f6"
HISTORY="8e25c3a9c2c18b5b22c95d641601a07eea81c195"
PLANNER="godot/scripts/solid_contact_response.gd"
HIST_DIR="docs/audits/sol347-independent-20261104/planner-numeric/"
ENGINES={"windows":"C:/Godot47/Godot_v4.7-stable_win64_console.exe","linux":"/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64"}
ENGINE_SHA={"linux":"f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"}

def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(["git","-C",str(ROOT),*args])
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
def wsl(path):
    text=str(path).replace("\\","/");return "/mnt/"+text[0].lower()+text[2:]

def trace(source):
    anchors=[
      ("extends RefCounted\n","extends RefCounted\n\nstatic var numeric_trace: Array[Dictionary] = []\n"),
      ("\tvar before: float = _energy(velocity, omega, mass, inertia)\n",
       "\tvar before: float = _energy(velocity, omega, mass, inertia)\n\tnumeric_trace.append({\"stage\":\"initial\",\"v\":velocity,\"w\":omega,\"m\":mass,\"I\":inertia,\"energy\":before})\n"),
      ("\t\t\tif not is_finite(magnitude) or not impulse.is_finite()",
       "\t\t\tnumeric_trace.append({\"stage\":\"step\",\"sweep\":sweep,\"group\":index,\"before_v\":result_velocity,\"before_w\":result_omega,\"after_v\":next_velocity,\"after_w\":next_omega,\"m\":mass,\"I\":inertia,\"before\":step_before,\"after\":step_after,\"tolerance\":step_tolerance,\"approach\":approach,\"lever\":lever,\"magnitude\":magnitude,\"impulse\":impulse,\"torque\":torque,\"offset\":offset})\n\t\t\tif not is_finite(magnitude) or not impulse.is_finite()"),
      ("\tvar after: float = _energy(result_velocity, result_omega, mass, inertia)\n",
       "\tvar after: float = _energy(result_velocity, result_omega, mass, inertia)\n\tnumeric_trace.append({\"stage\":\"final\",\"before_v\":velocity,\"before_w\":omega,\"after_v\":result_velocity,\"after_w\":result_omega,\"m\":mass,\"I\":inertia,\"before\":before,\"after\":after,\"tolerance\":tolerance})\n")]
    for old,new in anchors:
        assert source.count(old)==1,"instrumentation anchor drift"
        source=source.replace(old,new)
    return source

def command(name,argv,folder,env=None):
    log=folder/(name+".log");assert not log.exists(),"Retain prior run"
    actual=list(argv)
    if actual[0]=="wsl":actual[actual.index("--")+1:actual.index("--")+1]=["timeout","--signal=TERM","--kill-after=5s","120s"]
    start=time.monotonic()
    with log.open("wb") as handle:
        process=subprocess.Popen(actual,cwd=ROOT,env=env,stdout=handle,stderr=subprocess.STDOUT)
        try:code=process.wait(timeout=130)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],stdout=handle,stderr=subprocess.STDOUT,check=False);process.wait(timeout=10);code=124
    text=log.read_text(encoding="utf-8",errors="replace")
    return dict(command=actual,exit=code,clean=code==0 and not any(s in text for s in ["SCRIPT ERROR:","ERROR:","ObjectDB instances leaked","resources still in use"]),seconds=time.monotonic()-start,log=str(log.relative_to(ROOT)),log_sha256=sha(log.read_bytes()))

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("--run",required=True);parser.add_argument("--platforms",default="windows,linux")
    args=parser.parse_args();assert Path(args.run).name==args.run
    folder=ROOT/"build/sol-energy"/args.run;assert not folder.exists(),"New run name required";folder.mkdir(parents=True)
    registration=json.loads((ROOT/"tools/sol281/energy_precision_registration.json").read_text(encoding="utf-8"))
    baseline=git("show",BASE+":"+PLANNER);assert sha(baseline)==registration["baseline"]["sha256"]
    assert baseline==git("show","1598115c:"+PLANNER)
    candidate=(ROOT/PLANNER).read_bytes().replace(b"\r\n",b"\n")
    old=b"\treturn 0.5 * mass * velocity.length_squared() + 0.5 * inertia * omega * omega"
    new=b"\t# Vector2.length_squared() rounds its norm at real_t precision. Evaluate the\n\t# energy of these already rounded components in scalar float64 instead.\n\tvar vx: float = velocity.x\n\tvar vy: float = velocity.y\n\treturn 0.5 * mass * (vx * vx + vy * vy) + 0.5 * inertia * omega * omega"
    assert candidate==baseline.replace(old,new) and baseline.count(old)==1,"Unregistered production delta"
    history={name:dict(sha256=sha(git("show",HISTORY+":"+HIST_DIR+name))) for name in ["registration.md.txt","probe.gd.txt","results.json","exact_case_replay.json"]}
    assert history["registration.md.txt"]["sha256"]=="63d8b79b3518a6c3934cf4c54cc9fccfd8a23c6fb03de0daef310a96f36fa426"
    assert history["probe.gd.txt"]["sha256"]=="94cb00d85bf6f18e7785e38026609760f632a345e6f0c01c13c839e67edb0523"
    files={"baseline.gd":baseline,"scalar64.gd":candidate,"baseline-trace.gd":trace(baseline.decode()).encode(),"scalar64-trace.gd":trace(candidate.decode()).encode(),
      "probe.gd":(ROOT/"godot/tests/support/sol_energy_precision_probe.gd").read_bytes().replace(b"\r\n",b"\n"),
      "project.godot":b'config_version=5\n[application]\nconfig/name="SOL energy precision isolated"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'}
    info=dict(source=git("rev-parse","HEAD").decode().strip(),tree=git("rev-parse","HEAD^{tree}").decode().strip(),local_delta=git("status","--short").decode(),base=BASE,registration=registration,
      history=history,inputs={name:dict(sha256=sha(raw),bytes=len(raw)) for name,raw in files.items()},runner_sha256=sha(Path(__file__).read_bytes().replace(b"\r\n",b"\n")),engines={})
    rows={}
    for platform in args.platforms.split(","):
        project=folder/platform;project.mkdir()
        for name,raw in files.items():(project/name).write_bytes(raw)
        if platform=="windows":
            engine=Path(ENGINES[platform].replace("_console.exe",".exe"));digest=sha(engine.read_bytes());launcher=sha(Path(ENGINES[platform]).read_bytes())
            version=subprocess.check_output([ENGINES[platform],"--version"]).decode().strip()
            argv=[ENGINES[platform],"--headless","--path",str(project),"--script","res://probe.gd"]
        else:
            digest=subprocess.check_output(["wsl","-d","Ubuntu-24.04","--","sha256sum",ENGINES[platform]]).decode().split()[0];launcher=digest
            version=subprocess.check_output(["wsl","-d","Ubuntu-24.04","--",ENGINES[platform],"--version"]).decode().strip()
            argv=["wsl","-d","Ubuntu-24.04","--","env","CYBERSAND_SOURCE_REVISION="+info["source"],ENGINES[platform],"--headless","--path",wsl(project),"--script","res://probe.gd"]
        # The Windows binary is pinned by the retained manifest, not guessed from a filename.
        if platform=="windows":
            expected=json.loads(git("show","ba9cbc89:godot/addons/cybersand_native/runtime-provenance.json"))["godot_executable_sha256"]
        else:expected=ENGINE_SHA[platform]
        assert digest==expected and version=="4.7.stable.official.5b4e0cb0f"
        info["engines"][platform]=dict(path=ENGINES[platform],sha256=digest,launcher_sha256=launcher,version=version)
        row=command(platform,argv,folder,dict(os.environ,CYBERSAND_SOURCE_REVISION=info["source"]));rows[platform]=row
        for name,raw in files.items():assert (project/name).read_bytes()==raw,"copied input changed"
        if row["clean"]:
            data=json.loads((project/"results.json").read_text(encoding="utf-8"));assert not data["failures"] and data["source"]==info["source"]
            row["results_sha256"]=sha((project/"results.json").read_bytes())
        write(folder/"receipt.json",dict(identity=info,results=rows));print(platform,row["exit"],row["clean"],flush=True)
    assert candidate==(ROOT/PLANNER).read_bytes().replace(b"\r\n",b"\n")
    return int(not all(row["clean"] for row in rows.values()))

if __name__=="__main__":raise SystemExit(main())
