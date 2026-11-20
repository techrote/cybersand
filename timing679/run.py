from pathlib import Path
import csv
import gzip
import hashlib
import io
import json
import os
import platform
import re
import statistics
import subprocess
import time

here=Path.cwd()
control=here/"control"
data=control/"timing679"
out=here/"evidence"
out.mkdir()
sources={"old":"551768ee9499f78fd656f5d2d99c5c944c8a1239","new":"b5f2f95a34a574c9aa76f79bfdcd897eb66fa727"}
order=["old","new","new","old","old","new"]
def run(args,cwd=here):
    return subprocess.check_output(list(map(str,args)),cwd=cwd,text=True)
def sha(data): return hashlib.sha256(data).hexdigest()
def load(path): return json.loads(path.read_bytes())
def expect(value,msg):
    if not value: raise RuntimeError(msg)
def fields(line): return dict(re.findall(r"([a-z0-9_]+)=([^ ,\n]+)",line))
def convert(f,except_keys):
    return {k:v if k in except_keys else (float(v) if "." in v else int(v)) for k,v in f.items()}
def save(name,obj):
    (out/name).write_text(json.dumps(obj,indent=2)+"\n")
profile_file="docs/audits/wave-water-face-004-2026-11-19/waterwall-measurements.json"
profile=load(control/profile_file)
args=profile["profiles"]["selected"]["args"]
oil_file="docs/audits/wave-oil-lava-2026-11-19/oil-brush-cost.cpp"
fixture=control/oil_file
expect("workers=6" in args and "ticks=1500" in args and "fall=3" in args,"unexpected map profile")
map_inputs={}
for filename,key in [("terrain-wall.bin","terrain_sha256"),("wall-stamps.txt","stamps_sha256")]:
    raw=gzip.decompress((data/(filename+".gz")).read_bytes())
    expect(sha(raw)==profile[key],filename)
    map_inputs[filename]=sha(raw)
    for label in sources:(here/label/filename).write_bytes(raw)
cpus=run(["lscpu","-J"])
(out/"lscpu.json").write_text(cpus)
cpu={rec["field"].rstrip(":"):rec.get("data") for rec in json.loads(cpus)["lscpu"]}
host={"os":platform.platform(),"cpu_model":cpu.get("Model name"),"cpu_affinity":sorted(os.sched_getaffinity(0)),
      "online_cpus":os.cpu_count(),"nproc":int(run(["nproc"]).strip()),
      "cpu_quota":Path("/sys/fs/cgroup/cpu.max").read_text().strip() if Path("/sys/fs/cgroup/cpu.max").exists() else None,
      "runner_image":os.environ.get("ImageOS"),"runner_image_version":os.environ.get("ImageVersion"),
      "compiler":run(["g++-13","--version"]).splitlines()[0]}
print(host,flush=True)
save("host.json",host)
build={}
src=["native/src/"+name+".cpp" for name in ["world","material_rules","scheduler_geometry","settled_world_discovery"]]
options=["g++-13","-std=c++20","-O2","-pthread","-I","native/include","-I","."]
start_code="    using Clock = std::chrono::steady_clock;"
end_code="    const auto ledger = world.quantity_ledger();"
fixture_text=fixture.read_text()
assert fixture_text.count(start_code)==fixture_text.count(end_code)==1
# The six timed brush runs use the exact original fixture. A separate run
# observes the material and parcel ledgers before and after the ticks.
before_code="    const auto initial = world.quantity_ledger();"
after_code=r'''
    const auto flight = world.ballistic_water_snapshot();
    const auto d = world.wave_flow_diagnostics();
    std::printf("initial_water=%llu initial_oil=%llu final_visible=%llu final_overfill=%llu final_in_flight=%llu launched_units=%llu launched_parcels=%llu max_live=%llu live=%u launch_refusals=%llu launch_capacity_skips=%llu launch_deferrals=%llu capacity_refusals=%llu\n",
      (unsigned long long)(initial.water_visible+initial.water_overfill+initial.water_ballistic),
      (unsigned long long)initial.material_cells[static_cast<size_t>(Material::Oil)],
      (unsigned long long)ledger.water_visible,(unsigned long long)ledger.water_overfill,
      (unsigned long long)ledger.water_ballistic,(unsigned long long)d.launched_units,
      (unsigned long long)d.launched_parcels,(unsigned long long)flight.ledger.maximum_live,
      flight.live,(unsigned long long)d.launch_refusals,(unsigned long long)d.launch_capacity_skips,
      (unsigned long long)d.launch_deferrals,(unsigned long long)d.capacity_refusals);
'''
observer=out/"oil-observe.cpp"
observer.write_text(fixture_text.replace(start_code,before_code+"\n"+start_code).replace(end_code,end_code+"\n"+after_code))
for label,rev in sources.items():
    work=here/label
    expect(run(["git","rev-parse","HEAD"],work).strip()==rev,label+" SHA")
    print("Build",label,rev,flush=True)
    subprocess.run(["make","CXX=g++-13","build/wave_waterwall"],cwd=work,check=True)
    objects=[]
    for f in src:
        obj="build/oil-"+Path(f).stem+".o"
        subprocess.run(options+["-c",f,"-o",obj],cwd=work,check=True)
        objects.append(obj)
    for test,driver in [("brush",fixture),("brush-observe",observer)]:
        subprocess.run(options+[str(driver)]+objects+["-o","build/"+test],cwd=work,check=True)
    build[label]={n:sha((work/"build"/n).read_bytes()) for n in ["wave_waterwall","brush","brush-observe"]}
save("binaries.json",build)

observations={"wall":[],"oil":[]}
for scene in observations:
    for seq,label in enumerate(order):
        work=here/label
        argv=args if scene=="wall" else ["./build/brush"]
        name=f"{scene}-{seq+1}-{label}"
        print(name,flush=True)
        completed=subprocess.run(argv,cwd=work,capture_output=True,text=True,timeout=600)
        (out/(name+".log")).write_text(completed.stdout+completed.stderr)
        expect(completed.returncode==0,name)
        lines=completed.stdout.splitlines()
        if scene=="wall":
            proc=convert(fields(lines[-1]),{"hash"})
            f=convert(fields(lines[-2]),set())
            f.pop("launch_ns_per_tick");f.pop("advance_last_ns")
            hdr=lines.index(next(v for v in lines if v.startswith("tick,total_drift,")))
            points=list(csv.DictReader(lines[hdr:-2]))
            expect(len(points)==11 and all(int(p["total_drift"])==0 for p in points), name+" water closure")
            initial=int(fields(lines[0])["water_units"])
            hydro_name=next(a.split("=",1)[1] for a in args if a.startswith("hydrograph="))
            h=(work/hydro_name).read_bytes()
            rows=list(csv.DictReader(io.StringIO(h.decode())))
            expect(len(rows)==1501,name+" hydrograph")
            (out/(name+".csv")).write_bytes(h)
            row={"median_us":proc["overall_median_us"],"p95_us":proc["p95_us"],"max_tick_us":proc["max_us"],
                 "results":{"hash":proc["hash"],"input_water":initial,"max_abs_sampled_drift":0,
                            "capacity_refusals":proc["capacity_refusals"],"hydrograph_sha256":sha(h),**f}}
        else:
            f=convert(fields(lines[-1]),{"hash"})
            expect(f["ticks"]==900 and f["water"]>0 and f["oil"]==1793,name+" brush ledger")
            row={"median_us":f["median_us"],"p95_us":f["p95_us"],
                 "results":{k:f[k] for k in ["hash","oil","water"]}}
        observations[scene].append({"seq":seq+1,"revision":label,**row})
        print(row,flush=True)
        save("observations.json",observations)
for scene,records in observations.items():
    for label in sources:
        group=[r for r in records if r["revision"]==label]
        expect(len(group)==3 and all(r["results"]==group[0]["results"] for r in group),scene+" "+label+" determinism")
oil_ledger={}
for label in sources:
    text=run(["./build/brush-observe"],here/label);(out/(label+"-oil-ledger.log")).write_text(text)
    ledger=convert(fields(text.splitlines()[-2]),set())
    final=convert(fields(text.splitlines()[-1]),{"hash"})
    ref=next(r["results"] for r in observations["oil"] if r["revision"]==label)
    expect(final["hash"]==ref["hash"] and ledger["initial_oil"]==final["oil"]==ref["oil"] and
           ledger["initial_water"]==final["water"]==ref["water"]==sum(ledger[x] for x in ("final_visible","final_overfill","final_in_flight")),label+" observer closure")
    oil_ledger[label]=ledger
save("oil-ledgers.json",oil_ledger)
summaries={}
for scene,rows in observations.items():
    stats={}
    for label in sources:
        group=[r for r in rows if r["revision"]==label]
        stats[label]={}
        for key in ["median_us","p95_us"]:
            values=[r[key] for r in group]
            stats[label][key]={"median":statistics.median(values),"min":min(values),"max":max(values)}
    stats["median_change_percent"]={key:round(100*(stats["new"][key]["median"]/stats["old"][key]["median"]-1),3) for key in ["median_us","p95_us"]}
    summaries[scene]=stats
save("summary.json",{"platform":host,"control_commit":os.environ["GITHUB_SHA"],
    "runner":f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
    "run_attempt":int(os.environ["GITHUB_RUN_ATTEMPT"]),"sources":sources,
    "fixture_source":"c35ea6b064f4bb3934ea451b5b419c373c7d1780","oil_fixture":oil_file,"oil_fixture_sha256":sha(fixture.read_bytes()),
    "wall_inputs":map_inputs,"wall_args":args,"compiler":{"wall":"make CXX=g++-13 build/wave_waterwall","oil":options,"objects":src,"binaries":build},
    "workers":6,"order":order,"ticks":{"wall":1500,"oil":900},"method":"One GitHub-hosted Ubuntu 24.04 x64 VM, all builds completed before sampling; each process exits before the next starts. A separate post-measurement brush replay checks parcel and material ledgers. Wall checks both residual and in-flight quantities every 150 ticks. Ranges span the three trial medians and p95s.",
    "summary":summaries,"per_run":{scene:[{k:v for k,v in r.items() if k!="results"} for r in rows] for scene,rows in observations.items()},
    "repeatable_outcomes":{scene:{label:next(r["results"] for r in rows if r["revision"]==label) for label in sources} for scene,rows in observations.items()},
    "oil_ledgers":oil_ledger})
print("All deterministic and conservation checks passed",flush=True)
