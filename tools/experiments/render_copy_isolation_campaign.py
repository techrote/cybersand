"""Source-bound standalone Stage C; never invokes a worker or native adapter."""
from pathlib import Path
import argparse
import hashlib
import json
import platform
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
SOURCES=["native/src/world.cpp","native/src/material_rules.cpp","native/src/scheduler_geometry.cpp",
    "native/src/settled_world_discovery.cpp","native/src/render_snapshot.cpp"]

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--compiler",required=True)
    parser.add_argument("--output",required=True,type=Path)
    parser.add_argument("--mode",choices=["debug","release","sanitize"],required=True)
    parser.add_argument("--samples",type=int,default=31)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    paths=[*ROOT.glob("native/include/cybersand/*"),*ROOT.glob("native/src/*"),
        ROOT/"native/tests/test_render_copy_isolation.cpp",ROOT/"native/bench/render_copy_isolation.cpp",Path(__file__)]
    inputs={str(p.relative_to(ROOT)).replace("\\","/"):sha(p) for p in paths if p.is_file()}
    git="git" if platform.system()=="Windows" else "/mnt/c/Program Files/Git/cmd/git.exe"
    report={"mode":args.mode,"platform":platform.platform(),"compiler":args.compiler,
        "compiler_version":subprocess.check_output([args.compiler,"--version"],text=True),
        "source_commit":subprocess.check_output([git,"rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        "source_tree":subprocess.check_output([git,"rev-parse","HEAD^{tree}"],cwd=ROOT,text=True).strip(),
        "inputs":inputs,"processes":[]}
    def run(label,argv):
        start=time.monotonic()
        log=args.output/(label+".log")
        with log.open("wb") as output:
            try:
                result=subprocess.run(argv,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,timeout=1200)
                code=result.returncode
            except subprocess.TimeoutExpired:
                code="timeout"
        report["processes"].append({"label":label,"argv":list(map(str,argv)),"exit":code,
            "seconds":time.monotonic()-start,"log_sha256":sha(log)})
        (args.output/"report.json").write_text(json.dumps(report,indent=2))
        if code!=0: raise SystemExit(label+" failed; original log retained at "+str(log))
        print(label,"passed",round(time.monotonic()-start,3),flush=True)
    flags=["-std=c++20","-DCYBERSAND_RENDER_COPY_EXPERIMENT","-Inative/include"]
    if platform.system()!="Windows": flags += ["-pthread"]
    if args.mode=="debug": flags += ["-O0","-g3"]
    elif args.mode=="release":
        flags += ["-O3","-DNDEBUG","-flto"]
        if platform.system()=="Windows": flags += ["-fuse-ld=lld"]
    else: flags += ["-O1","-g","-fsanitize=address,undefined","-fno-omit-frame-pointer"]
    extension=".exe" if platform.system()=="Windows" else ""
    test=args.output/("oracle"+extension)
    run("compile-oracle",[args.compiler,*flags,*SOURCES,"native/tests/test_render_copy_isolation.cpp","-o",str(test)])
    run("oracle",[str(test)])
    report["oracle_sha256"]=sha(test)
    if args.mode!="sanitize":
        bench=args.output/("benchmark"+extension)
        run("compile-benchmark",[args.compiler,*flags,*SOURCES,"native/bench/render_copy_isolation.cpp","-o",str(bench)])
        run("benchmark",[str(bench),str(args.samples)])
        report["benchmark_sha256"]=sha(bench)
        rows=[json.loads(line) for line in (args.output/"benchmark.log").read_text().splitlines()]
        if len(rows)!=9 or any(not r["byte_exact"] or not r["world_unchanged"] or r["samples"]!=args.samples for r in rows):
            raise ValueError("invalid benchmark rows")
        report["benchmarks"]=rows
    if any(sha(ROOT/path)!=expected for path,expected in inputs.items()): raise ValueError("source changed during execution")
    (args.output/"report.json").write_text(json.dumps(report,indent=2)+"\n")

if __name__=="__main__": main()
