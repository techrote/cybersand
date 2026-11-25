#!/usr/bin/env python3
"""Read-only Art startup/native-context phase observations on a pinned app."""
from __future__ import annotations
import argparse, hashlib, json, os, pathlib, platform, re, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[2]
APP="2743f89a0df6f6afcf7484e859c10790d521e74b"
GODOT="f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
FIXTURE="tools/fixtures/art_startup_phase_probe.gd"
NATIVE="godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
RAPIER="godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
def sha(p):
    h=hashlib.sha256()
    with pathlib.Path(p).open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):h.update(chunk)
    return h.hexdigest()
def git(*args):return subprocess.check_output(["git",*args],cwd=ROOT,timeout=60).decode().strip()
def identity():
    runtime={}
    for n in [NATIVE,RAPIER]:
        pointer=git("show","HEAD:"+n); match=re.search(r"oid sha256:([0-9a-f]{64})",pointer)
        if not match or sha(ROOT/n)!=match[1]:raise ValueError("Unpinned runtime "+n)
        runtime[n]=match[1]
    dirty=set(git("diff","--name-only","HEAD").splitlines())-{NATIVE,RAPIER}
    if dirty:raise ValueError("Modified source "+repr(sorted(dirty)))
    delta=set(git("diff","--name-only",APP,"HEAD").splitlines())
    expected={FIXTURE,"tools/ci/run_art_startup_phase_probe.py","docs/audits/2026-11-25-art-startup-phase-probe/README.md"}
    if delta!=expected:raise ValueError("App is not the declared unchanged source plus three apparatus files")
    return {"commit":git("rev-parse","HEAD"),"tree":git("rev-parse","HEAD^{tree}"),"application_source":APP,"runtime_sha256":runtime,
            "apparatus_sha256":{n:sha(ROOT/n) for n in sorted(expected)}}
def cache():
    base=ROOT/"godot/.godot"
    return {p.relative_to(base).as_posix():{"bytes":p.stat().st_size,"sha256":sha(p)} for p in sorted(base.rglob("*")) if p.is_file()}
def host():
    value={"platform":platform.platform(),"logical_cpus":os.cpu_count()}
    for name,path in [("cpu","/proc/cpuinfo"),("memory","/proc/meminfo"),("cgroup_memory","/sys/fs/cgroup/memory.current"),("cgroup_limit","/sys/fs/cgroup/memory.max")]:
        try:
            text=pathlib.Path(path).read_text()
            if name=="cpu":text="\n".join(dict.fromkeys(l for l in text.splitlines() if l.startswith(("model name","cpu cores","siblings"))))
            if name=="memory":text="\n".join(l for l in text.splitlines() if l.startswith(("MemTotal:","MemAvailable:","SwapFree:")))
            value[name]=text
        except OSError:value[name]="unavailable"
    return value
def write(path,value):path.write_text(json.dumps(value,indent=2,sort_keys=True)+"\n")
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--godot",type=pathlib.Path,required=True);p.add_argument("--output",type=pathlib.Path,required=True)
    p.add_argument("--label",required=True);p.add_argument("--import-before",action="store_true");p.add_argument("--graphical",action="store_true");args=p.parse_args()
    args.output=args.output.resolve();args.godot=args.godot.resolve()
    if args.output.exists() or sha(args.godot)!=GODOT:p.error("Fresh output and pinned Linux engine required")
    source=identity();args.output.mkdir(parents=True);profile=args.output/"profile";profile.mkdir()
    env=dict(os.environ,XDG_DATA_HOME=str(profile),XDG_CONFIG_HOME=str(profile),CYBERSAND_SOURCE_REVISION=source["commit"],ART_STARTUP_PHASE_OUTPUT=str(args.output/"phases.json"))
    inputs={"source":source,"label":args.label,"fresh_profile":True,"explicit_import_before":args.import_before,"graphical":args.graphical,
            "cache_before":cache(),"host_before":host(),"godot_sha256":sha(args.godot),"os_page_cache":"Not cleared or controlled; do not call this OS-cold."}
    write(args.output/"inputs.json",inputs)
    result={"source":source,"label":args.label,"passed":False}
    if args.import_before:
        began=time.monotonic()
        with (args.output/"import.log").open("wb") as f:
            proc=subprocess.run([str(args.godot),"--headless","--path",str(ROOT/"godot"),"--editor","--import"],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=180)
        result["import"]={"returncode":proc.returncode,"wall_seconds":time.monotonic()-began,"log_sha256":sha(args.output/"import.log")}
    result["cache_before_runtime"]=cache()
    command=[str(args.godot),"--audio-driver","Dummy","--rendering-method","gl_compatibility","--path",str(ROOT/"godot"),"--script",str(ROOT/FIXTURE)]
    if not args.graphical:command.insert(1,"--headless")
    result["command"]=command;began=time.monotonic();log=args.output/"process.log"
    with log.open("wb") as f:
        try:
            proc=subprocess.run(command,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=180);result["returncode"]=proc.returncode;result["timeout"]=False
        except subprocess.TimeoutExpired:result["returncode"]=None;result["timeout"]=True
    result.update(wall_seconds=time.monotonic()-began,log_sha256=sha(log),cache_after=cache(),host_after=host(),source_unchanged=identity()==source)
    text=log.read_text(errors="replace");rows=[line.removeprefix("ART_STARTUP_PHASE_RESULT ") for line in text.splitlines() if line.startswith("ART_STARTUP_PHASE_RESULT ")]
    if len(rows)==1:result["fixture"]=json.loads(rows[0])
    value=result.get("fixture",{})
    result["passed"]=(result.get("returncode")==0 and not result.get("timeout") and result["source_unchanged"] and len(rows)==1
                      and value.get("checks",0)>=25 and value.get("failures")==[] and value.get("provider_requests")==0 and len(value.get("captures",[]))==3
                      and not any(token in text for token in ["ERROR:","Parse Error:","Failed to load script"]))
    write(args.output/"result.json",result)
    print(json.dumps({"passed":result["passed"],"label":args.label,"checks":value.get("checks"),"phases":value.get("phases"),"source":source["commit"]}))
    return 0 if result["passed"] else 1
if __name__=="__main__":raise SystemExit(main())
