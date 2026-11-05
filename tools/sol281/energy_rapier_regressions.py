#!/usr/bin/env python3
"""Run unchanged SOL response controls with real Rapier, without native World."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("energy",ROOT/"tools/sol281/energy_precision.py")
e=importlib.util.module_from_spec(spec);spec.loader.exec_module(e)

def authenticate_engine(platform):
    if platform=="windows":
        digest=e.sha(Path(e.ENGINES[platform].replace("_console.exe",".exe")).read_bytes())
        launcher=e.sha(Path(e.ENGINES[platform]).read_bytes())
        pin=json.loads(e.git("show","ba9cbc89:godot/addons/cybersand_native/runtime-provenance.json"))
        assert launcher==pin["godot_validation_executable_sha256"]
        expected=pin["godot_executable_sha256"]
        command=[e.ENGINES[platform],"--version"]
    else:
        digest=subprocess.check_output(["wsl","-d","Ubuntu-24.04","--","sha256sum",e.ENGINES[platform]]).decode().split()[0]
        launcher=digest;expected=e.ENGINE_SHA[platform]
        command=["wsl","-d","Ubuntu-24.04","--",e.ENGINES[platform],"--version"]
    version=subprocess.check_output(command).decode().strip()
    assert digest==expected and version=="4.7.stable.official.5b4e0cb0f"
    return dict(path=e.ENGINES[platform],sha256=digest,launcher_sha256=launcher,version=version)

def verify_report(test,platform,row,material):
    prefix="SOL281_CONTACT_RESPONSE " if test=="test_solid_contact_response" else "SOL281_COMPOUND_RESPONSE "
    reports=[json.loads(line[len(prefix):]) for line in (ROOT/row["log"]).read_text(encoding="utf-8",errors="replace").splitlines() if line.startswith(prefix)]
    if len(reports)!=1:return False,None
    report=reports[0]
    valid=not report.get("failures",["missing"]) and report.get("platform")==platform.capitalize()
    if test=="test_solid_contact_response":
        mechanical=report.get("mechanical",{})
        valid=valid and report.get("checks")==101 and mechanical.get("mass")==520 and mechanical.get("steps")==12 and len(mechanical.get("trajectory",[]))==12 and mechanical.get("gate_passed")==True and mechanical.get("off_center",{}).get("gate_passed")==True and report.get("planner_source_sha256")==e.sha(material["scripts/solid_contact_response.gd"])
    else:valid=valid and report.get("checks")==33
    return valid,report

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("--run",required=True);args=parser.parse_args()
    assert Path(args.run).name==args.run
    folder=ROOT/"build/sol-energy"/args.run;assert not folder.exists();folder.mkdir(parents=True)
    source=e.git("rev-parse","HEAD").decode().strip();rows=[];inputs={};engines={}
    scripts=["scripts/rapier_physics_bridge.gd","scripts/rigid_body_coupling.gd","scripts/cell_world.gd","scripts/interaction_policy.gd"]
    tests=["test_solid_contact_response","test_solid_detachment_compound_response"]
    for name in scripts+["tests/"+name+".gd" for name in tests]:assert (ROOT/"godot"/name).read_bytes().replace(b"\r\n",b"\n")==e.git("show",e.BASE+":godot/"+name)
    for platform in ["windows","linux"]:
        engines[platform]=authenticate_engine(platform)
        manifest=json.loads((ROOT/"godot/addons/godot-rapier2d"/("runtime-provenance."+platform+".json")).read_text(encoding="utf-8"))
        runtime=ROOT/manifest["artifact"];assert e.sha(runtime.read_bytes())==manifest["sha256"]
        for name,digest in manifest["source_inputs"].items():assert e.sha((ROOT/name).read_bytes().replace(b"\r\n",b"\n"))==digest
        for arm in ["baseline","scalar64"]:
            project=folder/(platform+"-"+arm);project.mkdir()
            material={"scripts/solid_contact_response.gd":e.git("show",e.BASE+":"+e.PLANNER) if arm=="baseline" else (ROOT/e.PLANNER).read_bytes().replace(b"\r\n",b"\n"),
                "project.godot":b'config_version=5\n[application]\nconfig/name="SOL response isolated Rapier regression"\n[physics]\n2d/physics_engine="Rapier2D"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'}
            for name in scripts+["tests/"+name+".gd" for name in tests]:material[name]=(ROOT/"godot"/name).read_bytes().replace(b"\r\n",b"\n")
            for name in e.git("ls-files","godot/addons/godot-rapier2d").decode().splitlines():
                if not name.endswith(".import") and ("/bin/" not in name or name==manifest["artifact"]):material[str(Path(name).relative_to("godot")).replace("\\","/")]=(ROOT/name).read_bytes()
            for name,raw in material.items():
                target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
            inputs[project.name]={name:dict(sha256=e.sha(raw),bytes=len(raw)) for name,raw in material.items()}
            e.write(folder/"inputs.json",dict(source=source,tree=e.git("rev-parse","HEAD^{tree}").decode().strip(),engines=engines,inputs=inputs))
            for test in [None,*tests]:
                argv=[e.ENGINES[platform],"--headless","--audio-driver","Dummy","--path",str(project) if platform=="windows" else e.wsl(project)]
                argv+=( ["--editor","--import","--quit"] if test is None else ["--script","res://tests/"+test+".gd"] )
                if platform=="linux":argv=["wsl","-d","Ubuntu-24.04","--",*argv]
                name=project.name+"-"+(test or "import")
                row=e.command(name,argv,folder,dict(os.environ,CYBERSAND_SOURCE_REVISION=source));rows.append(row)
                if test is not None:
                    row["report_valid"],row["report"]=verify_report(test,platform,row,material)
                    row["clean"]=row["clean"] and row["report_valid"]
                for path,raw in material.items():assert (project/path).read_bytes()==raw,"copied input changed"
                e.write(folder/"receipt.json",dict(source=source,tree=e.git("rev-parse","HEAD^{tree}").decode().strip(),local_delta=e.git("status","--short").decode(),runner_sha256=e.sha(Path(__file__).read_bytes().replace(b"\r\n",b"\n")),engines=engines,scope="Unchanged regression fixture and bridge, actual Rapier; fallback class parsed but no World instantiated; no nativeWorld or SOL authority/clearance claim",inputs=inputs,results=rows))
                print(name,row["exit"],row["clean"],flush=True)
                if not row["clean"]:break
    return int(not all(r["clean"] for r in rows))

if __name__=="__main__":raise SystemExit(main())
