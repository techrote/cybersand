#!/usr/bin/env python3
"""Guarded-pose Windows GL/ANGLE A/B — same qualified native DLL all arms.

Runs eight fresh physical Main scenes; never runs with '--headless' when
capture is requested. Hosted ANGLE is not a substitute for owner physical GPU.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BINARY="Godot_v4.7-stable_win64_console.exe"
GODOT_HASH=(
    "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
    "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9"
)
NATIVE_HASH="6c7811b78c12e34a68931f83f2fd505c20078c089bce245a9be8be6e02e6d04d"
PR_HEAD="214de85adef2aaabc8e26de8612a3bf27cc1a081"


def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda:handle.read(1024*1024),b""):
            h.update(block)
    return h.hexdigest()


def check_binary():
    artifact=ROOT/"build/pr566-qualified"
    runtime=artifact/"cybersand_native.windows.x86_64.dll"
    prov=json.loads((artifact/"runtime-provenance.json").read_text("utf-8"))
    if prov.get("source_commit")!=PR_HEAD or prov.get("sha256")!=NATIVE_HASH:
        raise RuntimeError("Qualified native DLL provenance does not match PR #566")
    if digest(runtime)!=NATIVE_HASH:
        raise RuntimeError("Qualified PR #566 DLL bytes changed")
    inputs=prov.get("source_inputs",{})
    for name,reference in inputs.items():
        path=ROOT/name
        if not path.is_file():
            raise RuntimeError("Source-matched native input absent: "+name)
        body=path.read_bytes().replace(b"\r\n",b"\n")
        if hashlib.sha256(body).hexdigest()!=reference:
            raise RuntimeError("Native input changed since final PR566 source: "+name)
    destination=ROOT/"godot/addons/cybersand_native/bin"/runtime.name
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(runtime.read_bytes())
    return {"sha256":digest(destination),"source_commit":PR_HEAD,
            "source_input_count":len(inputs),"path":str(destination)}


def prepare_godot(path,destination):
    archive=path.read_bytes()
    if hashlib.sha512(archive).hexdigest()!=GODOT_HASH:
        raise RuntimeError("Pinned Godot 4.7 Windows archive SHA512 mismatch")
    destination.mkdir(parents=True,exist_ok=False)
    with zipfile.ZipFile(path) as z:
        if z.testzip(): raise RuntimeError("Corrupt Godot archive")
        z.extractall(destination)
    godot=destination/BINARY
    if not godot.exists(): raise RuntimeError("Missing official Godot console binary")
    version=subprocess.check_output([str(godot),"--version"],timeout=45,text=True).strip()
    if version!="4.7.stable.official.5b4e0cb0f":
        raise RuntimeError("Godot engine identity changed: "+version)
    return godot,version


def execute(name,cmd,env,destination,timeout):
    start=time.monotonic()
    with destination.open("w",encoding="utf-8",errors="replace") as log:
        log.write("RUN "+name+" COMMAND "+json.dumps(cmd)+"\n")
        log.flush()
        try:
            proc=subprocess.run(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,
                                timeout=timeout,check=False)
        except subprocess.TimeoutExpired as e:
            raise RuntimeError(f"{name} exceeded {timeout}s; see {destination}") from e
    duration=time.monotonic()-start
    tail=destination.read_text("utf-8",errors="replace")[-3500:]
    if proc.returncode:
        raise RuntimeError(f"{name}: exit {proc.returncode}, {duration:.1f}s; log tail:\n{tail}")
    print(f"PR566_POSE_AB_HOST {name} OK {duration:.2f}s",flush=True)
    return duration


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot-zip",type=Path,required=True)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--engine-directory",type=Path,required=True)
    args=parser.parse_args()
    target=args.evidence.resolve()
    target.mkdir(parents=True,exist_ok=True)
    (target/"reports").mkdir(exist_ok=True)
    (target/"frames").mkdir(exist_ok=True)
    (target/"logs").mkdir(exist_ok=True)
    native=check_binary()
    engine,version=prepare_godot(args.godot_zip.resolve(),args.engine_directory.resolve())
    config={"qualified_native":native,"godot":version,"system":sys.platform,
            "source_branch":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
            "renderer":"gl_compatibility/opengl3_angle","display_intent":"windows non-headless graphical"}
    (target/"identity.json").write_text(json.dumps(config,indent=2)+"\n",encoding="utf-8")
    base=[str(engine),"--audio-driver","Dummy"]
    # Host import can be headless; only *rendered* trials require a display.
    execute("editor-import",base+["--headless","--path",str(ROOT/"godot"),
                      "--editor","--quit"],os.environ.copy(),target/"logs/import.log",180)
    results=[]
    for fire in ("nofire","fire"):
        for camera in ("free","follow"):
            for pose in ("mask","guarded"):
                arm=f"{fire}-{pose}-{camera}"
                frames=target/"frames"/arm
                frames.mkdir(parents=True,exist_ok=True)
                env=os.environ.copy()
                env.update({
                    "CYBERSAND_RECOIL_TRIAL":fire,
                    "CYBERSAND_DIAG_FLYER_POSE":pose,
                    "CYBERSAND_POSE_AB_CAMERA":camera,
                    "CYBERSAND_POSE_AB_CAPTURE_DIR":str(frames),
                    "CYBERSAND_RECOIL_OUTPUT":str(target/"reports"/(arm+".json")),
                    "CYBERSAND_DIAG_SUPPRESS_EXHAUST_UNRESOLVED_RECOIL":"0",
                    "CYBERSAND_CI_WATCHDOG_SCALE":"1",
                })
                cmd=base+["--rendering-method","gl_compatibility",
                    "--rendering-driver","opengl3_angle","--path",str(ROOT/"godot"),
                    "--script","res://tests/test_pr566_mask_coherent_ab.gd"]
                seconds=execute(arm,cmd,env,target/"logs"/(arm+".log"),210)
                results.append({"arm":arm,"seconds":seconds,"report":str(target/"reports"/(arm+".json"))})
    from reduce_pr566_mask_coherent_ab import reduce
    summary=reduce(target)
    (target/"summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    for comparison in summary["comparisons"]:
        print("PR566_MASK_COHERENT_PAIR",json.dumps(comparison,sort_keys=True),flush=True)
    print("PR566_MASK_COHERENT_RESULT",json.dumps({
        "status":"hosted_windows_graphical_pass",
        "head":config["source_branch"],"godot":version,
        "cohorts":len(results),"paired_comparisons":len(summary["comparisons"]),
        "qualified_native_sha256":native["sha256"]}),flush=True)


if __name__=="__main__":
    main()
