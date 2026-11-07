#!/usr/bin/env python3
"""Read-only alternating worker benchmark. Run once per baseline/candidate checkout."""
import argparse, json, os, platform, shutil, statistics, subprocess
from pathlib import Path

def call(args, root, logfile):
    p=subprocess.run([str(a) for a in args],cwd=root,capture_output=True,text=True)
    logfile.write_text("$ "+" ".join(map(str,args))+"\n"+p.stdout+"\n"+p.stderr+"\n")
    if p.returncode: raise RuntimeError(f"{args[0]} failed ({p.returncode}): {logfile}")
    return p.stdout.strip()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo",type=Path,default=Path("."))
    ap.add_argument("--out",type=Path,required=True)
    ap.add_argument("--cycles",type=int,default=3)
    ap.add_argument("--extended",action="store_true")
    ap.add_argument("--no-perf",action="store_true")
    a=ap.parse_args(); root=a.repo.resolve(); out=a.out.resolve()
    out.mkdir(parents=True,exist_ok=True)
    if not 1<=a.cycles<=10: raise ValueError("cycles must be 1..10")
    if not shutil.which("g++-13"): raise RuntimeError("g++-13 unavailable")
    if not (root/"native/src/world.cpp").is_file(): raise RuntimeError("not a source checkout")
    meta={"os":platform.platform(),"cpu_count":os.cpu_count(),
          "head":call(["git","rev-parse","HEAD"],root,out/"git.log"),
          "g++-13":call(["g++-13","--version"],root,out/"gcc.log").splitlines()[0]}
    try:
        meta["cpu_model"]=next(line.split(":",1)[1].strip() for line in
            Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name"))
    except (OSError,StopIteration): pass
    (out/"machine.json").write_text(json.dumps(meta,indent=2)+"\n")
    call(["make","CXX=g++-13","build/tests"],root,out/"build.log")
    call([root/"build/tests"],root,out/"native-tests.log")
    dest=out/"neighbour_cursor_bench"
    sources=sorted((root/"native/src").glob("*.cpp"))
    call(["g++-13","-std=c++20","-O2","-g","-fno-omit-frame-pointer",
          "-pthread","-I",root/"native/include",*sources,
          root/"native/bench/neighbour_cursor_bench.cpp","-o",dest],root,out/"compile.log")
    scene=root/"native/bench/data/neighbour_stress_rectangles.txt"
    rows=[]
    for cycle in range(a.cycles):
        for idx,workers in enumerate((1,6,6,1)):
            tag=f"{cycle+1:02d}_{idx+1}_{workers}w"
            output=call([dest,scene,workers,600,out/f"{tag}.csv"],root,out/f"{tag}.log")
            rows.append(dict(label=tag,**json.loads(output)))
            (out/"runs.json").write_text(json.dumps(rows,indent=2)+"\n")
    signatures={json.dumps((r["checkpoints"],r["state_hash"],r["physical_state_hash"],
                            r["visited_total"],r["moved_total"],r["scheduled_cores_total"]),
                           sort_keys=True) for r in rows}
    if len(signatures)!=1: raise RuntimeError("hash or work-count PARITY FAILURE")
    result={"head":meta["head"],"parity":True,"state_hash":rows[0]["state_hash"],
            "physical_state_hash":rows[0]["physical_state_hash"],
            "means_ms":{str(w):statistics.mean(r["mean_ms"] for r in rows if r["workers"]==w)
                        for w in (1,6)},"runs":len(rows)}
    (out/"summary.json").write_text(json.dumps(result,indent=2)+"\n")
    if a.extended:
        for workers in (1,6):
            call([dest,scene,workers,1800,out/f"extended_{workers}.csv"],root,
                 out/f"extended_{workers}.log")
    if not a.no_perf and shutil.which("perf"):
        call(["perf","record","--call-graph","fp","-F","499","-o",out/"perf.data",
              "--",dest,scene,6,600],root,out/"perf-record.log")
        for name,sort in (("functions","symbol"),("lines","symbol,srcline")):
            text=call(["perf","report","-i",out/"perf.data","--stdio","-n",
                       "--sort",sort],root,out/f"perf-{name}.log")
            (out/f"perf-{name}.txt").write_text(text)
    print(json.dumps(result,indent=2))

if __name__=="__main__":
    main()
