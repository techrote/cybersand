"""Rebuild and measure fixed closed-basin Water fronts on signed/mirrored seams."""
import argparse,json,subprocess
from pathlib import Path
from run import ROOT,identity

p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
exe=a.output.resolve()/'water_leveling.exe'
cxx=ROOT.parent/'.local/llvm-mingw-20260826-ucrt-x86_64/bin/clang++.exe'
cmd=[str(cxx),'-std=c++20','-O3','-DNDEBUG','-pthread','-static','-Inative/include',
     *['native/src/'+s+'.cpp' for s in ['world','material_rules','scheduler_geometry','settled_world_discovery','render_snapshot']],
     'native/bench/water_leveling.cpp','-o',str(exe)]
with (a.output/'build.log').open('w') as f:
    f.write(json.dumps(cmd)+'\n');f.flush();subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=300)
(a.output/'manifest.json').write_text(json.dumps(identity([exe]),indent=2))
results=[];previous={}
for width in [48,96]:
    for shift in [-65,0,63]:
        for mirror in [0,1]:
            for workers in [1,4]:
                key=f'w{width}-s{shift}-m{mirror}-t{workers}';cmd=[str(exe),str(width),str(shift),str(workers),str(mirror)]
                r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (a.output/(key+'.jsonl')).write_text(r.stdout)
                (a.output/(key+'.execution.json')).write_text(json.dumps(dict(command=cmd,exit=r.returncode,stderr=r.stderr,timeout_seconds=180)))
                r.check_returncode();rows=[json.loads(s) for s in r.stdout.splitlines()]
                assert rows[-1]['allocations']==0
                if workers==4:assert rows[:-1]==previous[(width,shift,mirror)]
                previous[(width,shift,mirror)]=rows[:-1]
                results.append(dict(width=width,shift=shift,mirror=mirror,workers=workers,samples=rows[:-1],work=rows[-1]))
                print(key,rows[-1]['arrival_tick'],rows[-1]['one_cell_level_tick'],flush=True)
(a.output/'results.json').write_text(json.dumps(results,indent=2));print('24 conserved worker-matched basin cases passed')
