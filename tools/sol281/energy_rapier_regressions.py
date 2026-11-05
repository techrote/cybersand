#!/usr/bin/env python3
"""Run unchanged SOL response controls with real Rapier, without native World."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("energy",ROOT/"tools/sol281/energy_precision.py")
e=importlib.util.module_from_spec(spec);spec.loader.exec_module(e)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("--run",required=True);args=parser.parse_args()
    assert Path(args.run).name==args.run
    folder=ROOT/"build/sol-energy"/args.run;assert not folder.exists();folder.mkdir(parents=True)
    source=e.git("rev-parse","HEAD").decode().strip();rows=[];inputs={}
    scripts=["scripts/rapier_physics_bridge.gd","scripts/rigid_body_coupling.gd"]
    tests=["test_solid_contact_response","test_solid_detachment_compound_response"]
    for name in scripts+["tests/"+name+".gd" for name in tests]:assert (ROOT/"godot"/name).read_bytes().replace(b"\r\n",b"\n")==e.git("show",e.BASE+":godot/"+name)
    for platform in ["windows","linux"]:
        manifest=json.loads((ROOT/"godot/addons/godot-rapier2d"/("runtime-provenance."+platform+".json")).read_text(encoding="utf-8"))
        runtime=ROOT/manifest["artifact"];assert e.sha(runtime.read_bytes())==manifest["sha256"]
        for name,digest in manifest["source_inputs"].items():assert e.sha((ROOT/name).read_bytes().replace(b"\r\n",b"\n"))==digest
        for arm in ["baseline","scalar64"]:
            project=folder/(platform+"-"+arm);project.mkdir()
            material={"scripts/solid_contact_response.gd":e.git("show",e.BASE+":"+e.PLANNER) if arm=="baseline" else (ROOT/e.PLANNER).read_bytes().replace(b"\r\n",b"\n"),
                "project.godot":b'config_version=5\n[application]\nconfig/name="SOL response isolated Rapier regression"\n[physics]\n2d/physics_engine="Rapier2D"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'}
            for name in scripts+["tests/"+name+".gd" for name in tests]:material[name]=(ROOT/"godot"/name).read_bytes().replace(b"\r\n",b"\n")
            for name in e.git("ls-files","godot/addons/godot-rapier2d").decode().splitlines():
                if "/bin/" not in name or name==manifest["artifact"]:material[str(Path(name).relative_to("godot")).replace("\\","/")]=(ROOT/name).read_bytes()
            for name,raw in material.items():
                target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
            inputs[project.name]={name:dict(sha256=e.sha(raw),bytes=len(raw)) for name,raw in material.items()}
            for test in [None,*tests]:
                argv=[e.ENGINES[platform],"--headless","--audio-driver","Dummy","--path",str(project) if platform=="windows" else e.wsl(project)]
                argv+=( ["--editor","--quit"] if test is None else ["--script","res://tests/"+test+".gd"] )
                if platform=="linux":argv=["wsl","-d","Ubuntu-24.04","--",*argv]
                name=project.name+"-"+(test or "import")
                row=e.command(name,argv,folder,dict(os.environ,CYBERSAND_SOURCE_REVISION=source));rows.append(row)
                e.write(folder/"receipt.json",dict(source=source,scope="Unchanged regression fixture, actual Rapier; no nativeWorld or SOL authority/clearance claim",inputs=inputs,results=rows))
                print(name,row["exit"],row["clean"],flush=True)
                if not row["clean"]:break
    return int(not all(r["clean"] for r in rows))

if __name__=="__main__":raise SystemExit(main())
