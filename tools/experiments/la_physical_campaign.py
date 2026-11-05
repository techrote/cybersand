#!/usr/bin/env python3
"""Run the reconciled, real-authored LA campaign with fresh rebuilt runtimes.

Historical 001--003 runner/registrations remain unchanged. This runner verifies
the exact 84-input source, copied Godot inputs, runtime bytes and each process.
"""
import argparse
import concurrent.futures
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
BASE="8f6412da2004a5bfd4b68f40c854b564696637f7"
spec=importlib.util.spec_from_file_location("la_process",ROOT/"tools/experiments/la_selective_experiment.py")
process=importlib.util.module_from_spec(spec);spec.loader.exec_module(process)


def git(*args):return subprocess.check_output(["git","-C",str(ROOT),*args])


def identity():
    subprocess.run(["git","-C",str(ROOT),"merge-base","--is-ancestor",BASE,"HEAD"],check=True)
    source=git("rev-parse","HEAD").decode().strip()
    inventory=json.loads((ROOT/"godot/addons/cybersand_native/runtime-provenance.json").read_text(encoding="utf-8"))["source_inputs"]
    for name,digest in inventory.items():
        assert process.sha((ROOT/name).read_bytes().replace(b"\r\n",b"\n"))==digest,name
        assert git("show",source+":"+name)==git("show",BASE+":"+name),name
    assert len(inventory)==84
    suffixes={".c",".cc",".cpp",".cxx",".h",".hh",".hpp",".hxx",".inc",".inl",".tpp"}
    actual={p.relative_to(ROOT).as_posix() for folder in ["native/include","native/src","godot/native_extension"]
            for p in (ROOT/folder).rglob("*") if p.is_file() and p.suffix in suffixes}
    assert actual==set(inventory),"incomplete native inventory"
    runtimes={}
    for platform,filename in [("windows","runtime-provenance.json"),("linux","runtime-provenance.linux.json")]:
        path="godot/addons/cybersand_native/"+filename
        raw=(ROOT/path).read_bytes().replace(b"\r\n",b"\n")
        assert raw==git("show",source+":"+path),"mutable provenance"
        native=json.loads(raw);assert native["source_inputs"]==inventory
        assert process.sha((ROOT/native["artifact"]).read_bytes())==native["sha256"]
        path="godot/addons/godot-rapier2d/runtime-provenance."+platform+".json"
        raw=(ROOT/path).read_bytes().replace(b"\r\n",b"\n")
        assert raw==git("show",source+":"+path)
        rapier=json.loads(raw)
        assert process.sha((ROOT/rapier["artifact"]).read_bytes())==rapier["sha256"]
        for name,digest in rapier["source_inputs"].items():
            assert process.sha((ROOT/name).read_bytes().replace(b"\r\n",b"\n"))==digest,name
        if platform=="windows":
            launcher=process.sha(Path(process.ENGINES[platform]).read_bytes())
            engine=process.sha(Path(process.ENGINES[platform].replace("_console.exe",".exe")).read_bytes())
            version=subprocess.check_output([process.ENGINES[platform],"--version"]).decode().strip()
        else:
            engine=subprocess.check_output(["wsl","-d","Ubuntu-24.04","--","sha256sum",process.ENGINES[platform]]).decode().split()[0]
            launcher=engine
            version=subprocess.check_output(["wsl","-d","Ubuntu-24.04","--",process.ENGINES[platform],"--version"]).decode().strip()
        assert engine==native["godot_executable_sha256"] and version==native["godot_version"]
        runtimes[platform]=dict(retained_native=native,rapier=rapier,engine=dict(path=process.ENGINES[platform],sha256=engine,launcher_sha256=launcher,version=version))
    rebuild=json.loads((ROOT/"build/la-physical/runtimes/receipt.json").read_text(encoding="utf-8"))
    assert rebuild["source"]==BASE and all(row["clean"] for row in rebuild["results"])
    for name,digest in rebuild["outputs"].items():assert process.sha((ROOT/"build/la-physical/runtimes"/name).read_bytes())==digest
    inputs={p:process.sha((ROOT/p).read_bytes()) for p in git("ls-files","godot").decode().splitlines() if (ROOT/p).is_file()}
    return dict(source=source,tree=git("rev-parse","HEAD^{tree}").decode().strip(),native_base=BASE,
                native_inputs=inventory,rebuild=rebuild,runtimes=runtimes,copied_inputs=inputs,
                runner_sha256=process.sha(Path(__file__).read_bytes().replace(b"\r\n",b"\n")),local_delta=git("status","--short").decode())


def load_registration(path):
    current=json.loads(path.read_text(encoding="utf-8"))
    if "extends" in current:
        inherited=load_registration(ROOT/"godot"/current["extends"].removeprefix("res://"))
        inherited.update(current);current=inherited
    current["cases"]+=current.pop("extra_cases",[])
    return current


def main():
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument("--run",required=True)
    parser.add_argument("--cases",default="")
    parser.add_argument("--platforms",default="windows,linux")
    parser.add_argument("--workers",default="1,4")
    parser.add_argument("--repeats",type=int,default=1)
    parser.add_argument("--existing-tests",action="store_true")
    parser.add_argument("--sequential-platforms",action="store_true")
    parser.add_argument("--tests-only",action="store_true",help="Run import/safety/scoped fixtures without physical episodes")
    args=parser.parse_args()
    assert Path(args.run).name==args.run and args.run not in [".",".."]
    info=identity();output=ROOT/"build/la-physical"/args.run
    registration=load_registration(ROOT/"godot/tests/fixtures/la_physical/registration-v5.json")
    cases=[c for c in registration["cases"] if not args.cases or c["id"] in args.cases.split(",")]
    if args.tests_only:cases=[]
    if args.cases:assert {c["id"] for c in cases}==set(args.cases.split(","))

    def host(platform):
        folder=output/platform;project=folder/"godot"
        if project.exists():raise RuntimeError("Preserve previous run; select a new --run name")
        for name in info["copied_inputs"]:
            src=ROOT/name;target=project/Path(name).relative_to("godot")
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
        binary="cybersand_native.windows.x86_64.dll" if platform=="windows" else "libcybersand_native.linux.x86_64.so"
        shutil.copy2(ROOT/"build/la-physical/runtimes"/binary,project/"addons/cybersand_native/bin"/binary)
        effective={p.relative_to(project).as_posix():process.sha(p.read_bytes()) for p in project.rglob("*") if p.is_file()}
        process.write(folder/"effective-project.json",dict(source=info["source"],files=effective,
            native_override=dict(path="addons/cybersand_native/bin/"+binary,retained=info["runtimes"][platform]["retained_native"]["sha256"],executed=process.sha((project/"addons/cybersand_native/bin"/binary).read_bytes()))))
        rows=[]
        def run(name,script=None,env=None):
            engine=process.ENGINES[platform];path=str(project) if platform=="windows" else process.wsl_path(project)
            argv=[engine,"--headless","--audio-driver","Dummy","--path",path]
            argv+= ["--editor","--quit"] if script is None else ["--max-fps","120","--script","res://tests/"+script+".gd"]
            environment=dict(os.environ,CYBERSAND_SOURCE_REVISION=info["source"])
            environment.update(env or {})
            if platform=="linux":
                forwarded=["CYBERSAND_SOURCE_REVISION="+info["source"],*[k+"="+v for k,v in (env or {}).items()]]
                argv=["wsl","-d","Ubuntu-24.04","--","env",*forwarded,*argv]
            row=process.command(name,argv,folder,environment,timeout=300)
            rows.append(row);process.write(folder/"receipt.json",dict(identity=info,platform=platform,results=rows))
            return row["clean"]
        if not run("import"):return rows
        if not run("passive-safety","test_la_passive_response"):return rows
        if args.existing_tests:
            for name in process.SCOPED:run("workbench-"+name,"test_workbench_"+name)
        for repeat in range(args.repeats):
            for worker in map(int,args.workers.split(",")):
                for case in cases:
                    data=folder/(case["id"]+"-w"+str(worker)+"-r"+str(repeat));data.mkdir()
                    env={"LA_PHYSICAL_OUTPUT":str(data) if platform=="windows" else process.wsl_path(data),
                         "LA_PHYSICAL_CASES":case["id"],"LA_PHYSICAL_WORKERS":str(worker),"LA_PHYSICAL_REPEAT":str(repeat)}
                    clean=run(case["id"]+"-w"+str(worker)+"-r"+str(repeat),"test_la_physical_campaign",env)
                    reports=list(data.glob("*.json"))
                    if clean:
                        assert len(reports)==len(registration["arms"]),"incomplete arm inventory"
                        for report in reports:
                            d=json.loads(report.read_text(encoding="utf-8"))
                            assert d["source"]==info["source"] and not d["failures"] and d["requested_workers"]==worker
                    # A failure remains retained; independent cases continue.
        changed=[];line_endings=[]
        for name,digest in effective.items():
            if name.startswith(".godot/"):continue
            current=project/name
            if current.is_file() and process.sha(current.read_bytes())==digest:continue
            original=ROOT/"godot"/name
            if name.endswith(".import") and current.is_file() and original.is_file() and current.read_bytes().replace(b"\r\n",b"\n")==original.read_bytes().replace(b"\r\n",b"\n"):
                line_endings.append(dict(path=name,before_sha256=digest,after_sha256=process.sha(current.read_bytes())))
            else:changed.append(name)
        process.write(folder/"effective-project-after.json",dict(source=info["source"],unexpected_changes=changed,
            import_metadata_LF_normalization_only=line_endings,verified_files=sum(not n.startswith(".godot/") for n in effective)))
        assert not changed,"copied authored project or loaded runtime changed during execution"
        return rows
    platforms=args.platforms.split(",")
    if args.sequential_platforms:results={platform:host(platform) for platform in platforms}
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(platforms)) as pool:results=dict(zip(platforms,pool.map(host,platforms)))
    assert info["copied_inputs"]==identity()["copied_inputs"],"source changed during campaign"
    process.write(output/"result.json",dict(identity=info,results=results,registration=registration,
        matrix=dict(cases=[c["id"] for c in cases],workers=list(map(int,args.workers.split(","))),platforms=platforms,repeats=args.repeats)))
    return int(not all(row["clean"] for rows in results.values() for row in rows))


if __name__=="__main__":raise SystemExit(main())
