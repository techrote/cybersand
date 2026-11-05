#!/usr/bin/env python3
"""Source-pinned opt-in SOL chamber runner; no historical campaign mutation."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("physical",ROOT/"tools/experiments/la_physical_campaign.py")
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
p=c.process

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("--run",required=True)
    parser.add_argument("--platforms",default="windows,linux");parser.add_argument("--workers",default="1,4")
    parser.add_argument("--cases",default="");parser.add_argument("--arms",default="");parser.add_argument("--repeats",type=int,default=3)
    args=parser.parse_args();assert Path(args.run).name==args.run and args.run not in [".",".."]
    info=c.identity();profile=json.loads((ROOT/"godot/tests/fixtures/sol_chamber/registration.json").read_text(encoding="utf-8"))
    if "windows" in args.platforms.split(","):
        pin=info["runtimes"]["windows"]["retained_native"]
        assert info["runtimes"]["windows"]["engine"]["launcher_sha256"]==pin["godot_validation_executable_sha256"]
    cases=[s for s in profile["cases"] if not args.cases or s["id"] in args.cases.split(",")]
    arms=[a for a in profile["arms"] if not args.arms or a in args.arms.split(",")]
    assert cases and arms and 0<args.repeats<=profile["repeats"]
    if args.cases:assert {s["id"] for s in cases}==set(args.cases.split(","))
    if args.arms:assert set(arms)==set(args.arms.split(","))
    platforms=args.platforms.split(",");workers=list(map(int,args.workers.split(",")))
    assert set(platforms)<=set(profile["platforms"]) and set(workers)<=set(profile["workers"])
    folder=ROOT/"build/sol-chamber"/args.run;assert not folder.exists();folder.mkdir(parents=True)
    rows=[];effective={}
    apparatus=json.loads((ROOT/"godot/tests/fixtures/sol_chamber/apparatus-002.json").read_text(encoding="utf-8"))
    manifest=dict(identity=info,registration=profile,apparatus=apparatus,matrix=dict(platforms=platforms,workers=workers,cases=[s["id"] for s in cases],arms=arms,repeats=args.repeats),results=rows,effective_inputs=effective)
    p.write(folder/"receipt.json",manifest)
    for platform in platforms:
        host=folder/platform;project=host/"godot"
        for name in info["copied_inputs"]:
            target=project/Path(name).relative_to("godot");target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        binary="cybersand_native.windows.x86_64.dll" if platform=="windows" else "libcybersand_native.linux.x86_64.so"
        shutil.copyfile(ROOT/"build/la-physical/runtimes"/binary,project/"addons/cybersand_native/bin"/binary)
        inventory={f.relative_to(project).as_posix():p.sha(f.read_bytes()) for f in project.rglob("*") if f.is_file()}
        effective[platform]=inventory;p.write(folder/"receipt.json",manifest)
        def run(name,script=None,environment=None):
            env=dict(os.environ,CYBERSAND_SOURCE_REVISION=info["source"],**(environment or {}))
            argv=[p.ENGINES[platform],"--headless","--audio-driver","Dummy","--path",str(project) if platform=="windows" else p.wsl_path(project)]
            argv+=(["--editor","--import","--quit"] if script is None else ["--max-fps","120","--script",script])
            if platform=="linux":argv=["wsl","-d","Ubuntu-24.04","--","env","CYBERSAND_SOURCE_REVISION="+info["source"],*[k+"="+v for k,v in (environment or {}).items()],*argv]
            row=p.command(name,argv,host,env,timeout=180 if script else 240);rows.append(row)
            p.write(folder/"receipt.json",manifest);return row
        imported=run("import")
        if not imported["clean"]:continue
        for repeat in range(args.repeats):
            for worker in workers:
                for case in cases:
                    for arm in arms:
                        name=case["id"]+"-"+arm+"-w"+str(worker)+"-r"+str(repeat)
                        output=host/name;output.mkdir()
                        env=dict(SOL_CHAMBER_OUTPUT=str(output) if platform=="windows" else p.wsl_path(output),SOL_CHAMBER_CASE=case["id"],SOL_CHAMBER_ARM=arm,SOL_CHAMBER_WORKERS=str(worker),SOL_CHAMBER_REPEAT=str(repeat))
                        row=run(name,"res://tests/support/sol_chamber_experiment.gd",env)
                        reports=list(output.glob("*.json"));row["reports"]=[dict(path=str(f.relative_to(ROOT)),sha256=p.sha(f.read_bytes())) for f in reports]
                        if row["clean"]:
                            assert len(reports)==1,"missing episode report"
                            report=json.loads(reports[0].read_text(encoding="utf-8"))
                            assert report["source"]==info["source"] and report["registration"]==profile["id"] and not report["failures"] and len(report["steps"])==180
                        p.write(folder/"receipt.json",manifest)
        changes=[]
        for name,digest in inventory.items():
            current=project/name
            if p.sha(current.read_bytes())==digest:continue
            original=ROOT/"godot"/name
            if name.endswith(".import") and current.read_bytes().replace(b"\r\n",b"\n")==original.read_bytes().replace(b"\r\n",b"\n"):continue
            changes.append(name)
        manifest.setdefault("post_checks",{})[platform]=dict(unexpected_changes=changes);assert not changes
        p.write(folder/"receipt.json",manifest)
    assert info["copied_inputs"]==c.identity()["copied_inputs"],"source changed during run"
    return int(not all(r["clean"] for r in rows))

if __name__=="__main__":raise SystemExit(main())
