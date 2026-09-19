"""Rebuild and run issue #9 fixtures; raw evidence stays outside the source tree.

Python standard library only. Each result links a source/file/artifact manifest.
Use --help. No production descriptor, scene or installed dependency is retuned.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import itertools
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
MATERIALS = {"Sand":2,"Water":3,"Lava":8,"Stone":13,"Dust":14,"Oil":16,
             "Seed":19,"Paste":20,"Salt":23,"Brine":24,"Sodium":25,
             "Gunpowder":26,"Coal":27,"Rust":29,"Concrete":31,"Mercury":33,"Wall":1}
POWDERS = ["Sand","Stone","Dust","Seed","Salt","Sodium","Gunpowder","Coal","Rust"]

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(["git","-C",str(ROOT),*args], text=True).strip()

def identity(artifacts):
    files = sorted(set(git("ls-files").splitlines() + git("ls-files","--others","--exclude-standard").splitlines()))
    source_files = {p:sha(ROOT/p) for p in files if (ROOT/p).is_file() and
                    p.startswith(("native/","godot/scripts/","godot/tests/","godot/native_extension/","tools/physics/","third_party/"))}
    return {"utc":dt.datetime.now(dt.timezone.utc).isoformat(),"head":git("rev-parse","HEAD"),
            "branch":git("branch","--show-current"),"status":git("status","--porcelain=v2"),
            "source_files":source_files,"source_sha256":hashlib.sha256(json.dumps(source_files,sort_keys=True).encode()).hexdigest(),
            "artifacts":{str(p):sha(p) for p in artifacts if Path(p).is_file()},
            "platform":platform.platform(),"machine":platform.machine(),"python":platform.python_version(),
            "dependencies":{"godot":"4.7.stable.official.5b4e0cb0f","rapier":"0.35.2","godot_cpp":"101ae38034304346a46ea9ea84ae156d3e860496"}}

def native_cases(group):
    specs=[]
    def add(a,b,layout="packed",depth=32,variant="baseline",width=32,**kw):
        specs.append(dict(top=MATERIALS[a],bottom=MATERIALS[b],layout=layout,depth=depth,variant=variant,width=width,
                          name=f"{a}-{b}-{layout}-{depth}-{variant}-w{width}",**kw))
    pairs=[("Sand","Dust"),("Stone","Sand"),("Rust","Sand")]
    if group in ("smoke","screen","expanded","controls"):
        for a,b in pairs:
            add(a,b);add(b,a)
        for liquid in ["Mercury","Water","Oil","Brine","Paste","Lava"]:
            for powder in ["Sand","Dust"]:
                add(liquid,powder);add(powder,liquid)
        for hard in ["Wall","Concrete"]:
            add("Sand",hard);add("Mercury",hard)
    if group=="expanded":
        for a,b in itertools.permutations(POWDERS,2): add(a,b)
        for a,b in pairs:
            for layout in ["holes","slope","unsupported","granular"]:add(a,b,layout)
        for liquid in ["Mercury","Water","Oil","Brine","Paste","Lava"]:
            for powder in ["Sand","Dust"]:
                for depth in [16,64]:add(liquid,powder,depth=depth)
                for layout in ["open","saturated"]:add(liquid,powder,layout)
        add("Water","Salt");add("Lava","Water")
    if group in ("controls","finalists"):
        for a,b in pairs:
            add(a,b,variant="exchange_off")
        for viscosity in [96,160,224,248]:
            add("Mercury","Sand",variant=f"viscosity_{viscosity}")
            add("Mercury","Sand",variant=f"viscosity_{viscosity}",width=1)
        add("Mercury","Sand",variant="exchange_off")
        for layout in ["reentry","excavate"]: add("Sand","Dust",layout)
        add("Sand","Dust",workers=4);add("Mercury","Sand",workers=4)
        add("Sand","Dust",telemetry=False);add("Mercury","Sand",telemetry=False)
        add("Sand","Dust",serial=True);add("Mercury","Sand",serial=True)
    if group=="finalists":
        add("Sand","Dust");add("Mercury","Sand")
    if group=="smoke":return specs[:2]+[s for s in specs if s["name"].startswith("Mercury-Sand")]
    # Preserve distinct execution profiles while removing repeated baseline definitions.
    return list({json.dumps(s,sort_keys=True):s for s in specs}.values())

def godot_cases(group):
    cases=[]
    def add(material="Sand",mode="barrel",layout="flat",**kw):
        cases.append(dict(material=MATERIALS.get(material,0),mode=mode,layout=layout,name=f"{mode}-{material}-{layout}") | kw)
    if group in ("smoke","screen","expanded","controls"):
        for powder in POWDERS:
            add(powder,"player")
        for material in ["Sand","Dust","Salt","Water","Oil","Mercury"]:
            add(material,visual=True)
        add("Empty",layout="hard",visual=True)
        add("Empty",name="freefall")
        add("Sand",layout="mixed")
    if group=="expanded":
        for material in POWDERS:
            for layout in ["walk","slope","side","film","enclosed","falling"]:add(material,"player",layout)
        for material in ["Wall","Water"]:add(material,"player")
        add("Sand","player","interior")
        for material in ["Sand","Dust","Salt"]:
            for drop in [0,4,8]:add(material,drop=drop)
        for angle in [0.7853981633974483,1.5707963267948966]:add(angle=angle)
        add(size=2.0)
        for mode in ["player","barrel"]:
            for layout in ["excavate","reentry"]:add(mode=mode,layout=layout,visual=True)
        for speed in [1800.0,2040.0]:add("Empty",layout="hard",speed=speed)
    if group in ("controls","finalists"):
        for family,base in [("displacement",0.18),("boundary",0.19),("contact",0.025)]:
            for factor in [0,0.5,2]:add(**{family:base*factor})
        for cap in [1.5,6]:add(cap=cap)
        add(density_limit=3.2)
        for mass in [0.5,2]:add(mass=mass)
        for damping in [0.5,2]:add(damping=damping)
        for friction in [0.4,1]:add(friction=friction)
        for delay in [1,2,4,8,9]:add(delay=delay)
        add(duplicate=True)
        add(telemetry=False)
        add(workers=4)
        add(serial=True)
        for material in ["Sand","Dust","Mercury"]:
            add(material,fallback=True);add(material,"player",fallback=True)
    if group=="finalists":
        cases=[]
        for spec in [{},{"cap":6},{"boundary":0.38},{"delay":4},{"layout":"excavate"},{"material":"Dust"},{"material":"Mercury"},
                     {"contact":0.0},{"contact":0.0,"layout":"excavate"},{"contact":0.0,"drop":4},{"contact":0.0,"delay":4}]:add(**spec)
    if group=="smoke":return [s for s in cases if s["name"] in ["barrel-Sand-flat","barrel-Empty-hard","freefall","player-Sand-flat","player-Dust-flat"]]
    return cases

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("engine",choices=["native","godot"])
    p.add_argument("--group",choices=["smoke","screen","expanded","controls","finalists"],default="smoke")
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--seeds",type=int,default=5)
    p.add_argument("--ticks",type=int,default=1800)
    p.add_argument("--fallback-ticks",type=int,default=180,help="Short, separately labelled interpreted reference coverage")
    p.add_argument("--godot",type=Path,default=Path("C:/Godot47/Godot_v4.7-stable_win64_console.exe"))
    p.add_argument("--cxx",default=str(ROOT.parent/".local/llvm-mingw-20260826-ucrt-x86_64/bin/clang++.exe") if os.name=="nt" else "c++")
    p.add_argument("--skip-build",action="store_true",help="Use only with a recorded source-matched native CLI")
    a=p.parse_args()
    if not 1<=a.seeds<=20 or not 1<=a.ticks<=7200:p.error("seeds 1..20; ticks 1..7200")
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
    exe=ROOT/"build"/("physics_characterisation.exe" if os.name=="nt" else "physics_characterisation")
    if a.engine=="native" and not a.skip_build:
        exe.parent.mkdir(exist_ok=True)
        cmd=[a.cxx,"-std=c++20","-O3","-DNDEBUG","-pthread","-static","-Inative/include",
             "native/src/world.cpp","native/src/material_rules.cpp","native/src/scheduler_geometry.cpp","native/src/render_snapshot.cpp","native/src/settled_world_discovery.cpp",
             "native/bench/physics_characterisation.cpp","-o",str(exe)]
        with (out/"build.log").open("w") as log:
            log.write(json.dumps(cmd)+"\n");log.flush()
            subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
    artifacts=[exe] if a.engine=="native" else [a.godot,ROOT/"godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",ROOT/"godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"]
    manifest=identity(artifacts);manifest["invocation"]=vars(a)|{"output":str(out),"godot":str(a.godot)}
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    specs=native_cases(a.group) if a.engine=="native" else godot_cases(a.group)
    all_specs=[]
    for index,spec in enumerate(specs):
        for seed in range(1 if spec.get("fallback") else a.seeds):
            all_specs.append(spec|{"seed":seed,"ticks":a.fallback_ticks if spec.get("fallback") else a.ticks,"id":f"{index:03d}-{spec['name']}-s{seed:02d}"})
    (out/"cases.json").write_text(json.dumps(all_specs,indent=2),encoding="utf-8")
    if a.engine=="godot":
        # Runner bounds 512 cases; split batches without changing individual worlds.
        for offset in range(0,len(all_specs),100):
            batch=out/f"batch-{offset:04d}.json";batch.write_text(json.dumps(all_specs[offset:offset+100]),encoding="utf-8")
            (out/f"batch-{offset:04d}.manifest.json").write_text(json.dumps(identity(artifacts),indent=2),encoding="utf-8")
            cmd=[str(a.godot),"--headless","--path",str(ROOT/"godot"),"--script","res://tests/test_physics_characterisation.gd","--",str(batch),str(out)]
            started=time.monotonic()
            with (out/f"batch-{offset:04d}.log").open("w") as log:
                log.write(json.dumps(cmd)+"\n");log.flush()
                result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=3600)
            errors=(out/f"batch-{offset:04d}.log").read_text(encoding="utf-8",errors="replace")
            if result.returncode or "SCRIPT ERROR" in errors or "ERROR:" in errors:raise RuntimeError(f"Godot batch {offset} failed; retain log")
            print(f"Godot {offset+min(100,len(all_specs)-offset)}/{len(all_specs)} {time.monotonic()-started:.1f}s",flush=True)
    else:
        for index,spec in enumerate(all_specs):
            cmd=[str(exe),str(spec["top"]),str(spec["bottom"]),spec["layout"],str(spec["depth"]),str(spec["seed"]),str(spec["ticks"]),
                 str(spec.get("workers",1)),spec["variant"],str(int(spec.get("telemetry",True))),str(int(spec.get("serial",False))),str(spec["width"])]
            started=time.monotonic();result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/(spec["id"]+".jsonl")).write_text(result.stdout,encoding="utf-8")
            (out/(spec["id"]+".execution.json")).write_text(json.dumps({"command":cmd,"exit":result.returncode,"seconds":time.monotonic()-started,"stderr":result.stderr,"manifest":"manifest.json"}),encoding="utf-8")
            if result.returncode:raise RuntimeError(f"failed {spec['id']}: {result.stderr}")
            if index%25==0:print(f"Native {index+1}/{len(all_specs)}",flush=True)
    print(f"Completed {len(all_specs)} cases: {out}",flush=True)

if __name__=="__main__":main()
