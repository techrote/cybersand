#!/usr/bin/env python3
"""Run exactly one bounded 16-configuration Windows/Godot gas CPU profile.

Reads *two* same-compiler diagnostic native DLLs built from source on the
same Linux builder; alternates baseline/candidate on ONE Windows runner.
Never overwrites production LFS binaries, never imports #405.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from pf_gas_godot_run import download_godot, call, WIN_DLL
from pf_gas_acceptance import read_json, write_json, sha256, selected

STEPS=(("baseline",0,0),("candidate",0,1),
       ("candidate",1,2),("baseline",1,3))
C2048="24a8bbe8ccf0d17196ebbab580b924930a964584"
CANDIDATE_BUILD="b7f151f85676ffc6b2ea87f3e5c6165b890727e0"

def verify_and_stage(out:Path, app:Path, binaries:Path)->None:
    doc=read_json(binaries/"source/probe-patch-identities.json")
    attest={
       "baseline":(C2048,doc["baseline"]),
       "candidate":(CANDIDATE_BUILD,doc["candidate"]),
    }
    probe_hashes=[]
    for role,(source,identity) in attest.items():
        if identity["original_source_commit"]!=source:
            raise RuntimeError("Wrong native source/"+role)
        p=binaries/role/WIN_DLL
        if not p.is_file(): raise FileNotFoundError(str(p))
        manifest=read_json(binaries/role/"source-build.json")
        if manifest["source_commit"]!=source or manifest["native_sha256"]!=sha256(p):
            raise RuntimeError("Unmatched diagnostic source/native executable SHA: "+role)
        if manifest.get("probe_patch_source_sha256")!=identity["patch_source_sha256"]:
            raise RuntimeError("Unmatched trace patch identity: "+role)
        probe_hashes.append(identity["patch_source_sha256"])
        (out/"identities").mkdir(parents=True,exist_ok=True)
        write_json(out/"identities"/(role+".json"),manifest)
        shutil.copy2(p,out/"identities"/(role+".dll"))
    if len(set(probe_hashes))!=1: raise RuntimeError("Two sources got different CPU probe scripts")
    original=app/"godot/addons/cybersand_native/bin"/WIN_DLL
    if not original.exists():raise FileNotFoundError(str(original))
    print("TWO_IDENTICALLY_INSTRUMENTED_SOURCE_BUILDS_SHA_VERIFIED",flush=True)

def main()->None:
    p=argparse.ArgumentParser()
    p.add_argument("--app",required=True)
    p.add_argument("--binaries",required=True)
    p.add_argument("--out",required=True)
    p.add_argument("--godot-url",required=True)
    p.add_argument("--godot-sha512",required=True)
    p.add_argument("--godot-version",required=True)
    a=p.parse_args()
    app=Path(a.app).resolve()
    binaries=Path(a.binaries).resolve()
    out=Path(a.out).resolve()
    if (out/"ABBA").exists():raise FileExistsError("Cannot overwrite original profile trial evidence")
    if subprocess.check_output(["git","-C",str(app),"rev-parse","HEAD"],text=True).strip()!=C2048:
        raise RuntimeError("Godot app isn't pinned exact accepted C2048 main")
    verify_and_stage(out,app,binaries)
    rapier=app/"godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
    native=app/"godot/addons/cybersand_native/bin"/WIN_DLL
    engine=download_godot(out/"toolchain",a.godot_url,a.godot_sha512,a.godot_version)
    call([str(engine),"--headless","--editor","--path",str(app/"godot"),"--import"],
         log=out/"toolchain/import.log",timeout=450)
    print("SOURCE_IDENTICAL_PROFILED_GODOT_IMPORT_PASS",flush=True)
    # Every batch reconstructs all 16 cases via #493 fixture, 30 warmup+100
    # measured native ticks. Original benchmark cohort isn't rerun.
    for role,rep,order in STEPS:
        dll=out/"identities"/(role+".dll")
        desired=read_json(out/"identities"/(role+".json"))["native_sha256"]
        shutil.copy2(dll,native)
        if sha256(native)!=desired:raise RuntimeError("Incorrect instrumented source DLL installed")
        manifest=out/"identities"/(role+".json")
        cmd=[sys.executable,"tools/ci/pf_gas_acceptance.py","execute",
             "--subset","pfprofile","--role",role,"--replicate",str(rep),
             "--order-position",str(order),
             "--source-build-manifest",str(manifest),
             "--godot",str(engine),"--project",str(app/"godot"),
             "--native",str(native),"--rapier",str(rapier),
             "--out",str(out/"ABBA"/role),"--timeout","1900"]
        print("CPU_GODOT_ABBA_BEGIN "+role+" r"+str(rep),flush=True)
        r=subprocess.run(cmd,env={**os.environ,"CYBERSAND_PF_GAS_CPU_PROFILE":"1"},timeout=1950,check=False)
        if r.returncode:raise RuntimeError(f"CPU_GODOT_ABBA_FAIL {role} {rep} return={r.returncode}")
        print("CPU_GODOT_ABBA_PASS "+role+" r"+str(rep),flush=True)
    # Use the source-matched independent reducer, retaining every raw trace.
    cmd=[sys.executable,"tools/ci/pf_gas_cpu_report.py",
         "--baseline",str(out/"ABBA/baseline"),
         "--candidate",str(out/"ABBA/candidate"),
         "--output",str(out/"ABBA/cpu-stage-report.json")]
    call(cmd,timeout=50)
    print("PF_GAS_CPU_PROFILE_COMPLETE no-physics-changes no-full-factorial",flush=True)

if __name__=="__main__":
    try:main()
    except Exception as exc:
        print("PF_GAS_CPU_PROFILE_EXECUTION_ERROR "+str(exc),file=sys.stderr,flush=True)
        raise SystemExit(1)
