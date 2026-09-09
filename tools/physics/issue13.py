"""Build and retain source-identified fresh transport controls; 180s per case."""
import argparse, json, subprocess
from pathlib import Path
from run import ROOT, identity

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reference',type=Path)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    exe=ROOT/'build/transport_characterisation.exe'
    cxx=ROOT.parent/'.local/llvm-mingw-20260826-ucrt-x86_64/bin/clang++.exe'
    cmd=[str(cxx),'-std=c++20','-O3','-DNDEBUG','-pthread','-static','-Inative/include',
         *['native/src/'+s+'.cpp' for s in ['world','material_rules','scheduler_geometry','render_snapshot']],
         'native/bench/transport_characterisation.cpp','-o',str(exe)]
    with (a.output/'build.log').open('w') as f:
        f.write(json.dumps(cmd)+'\n');f.flush()
        subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=300)
    (a.output/'manifest.json').write_text(json.dumps(identity([exe]),indent=2))
    references={};results={}
    for layout in ['packed','poured','powder','erosion','loose','film']:
        for seed in range(5):
            for workers in [1,4]:
                key=f'{layout}-s{seed}-w{workers}'
                cmd=[str(exe),layout,str(seed),str(workers),'1800']
                r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (a.output/(key+'.jsonl')).write_text(r.stdout)
                (a.output/(key+'.execution.json')).write_text(json.dumps(dict(command=cmd,exit=r.returncode,stderr=r.stderr)))
                r.check_returncode()
                rows=[json.loads(s) for s in r.stdout.splitlines()]
                references[key]=rows[:-1];results[key]=rows[-1]
                assert rows[-1]['overflow']==0
                if workers==4:assert references[key]==references[f'{layout}-s{seed}-w1'],key
        print(layout,flush=True)
    if a.reference:
        assert references==json.loads(a.reference.read_text()),'Baseline content drift'
    (a.output/'references.json').write_text(json.dumps(references,indent=2))
    (a.output/'results.json').write_text(json.dumps(results,indent=2))
    print('60 fresh controls passed')

if __name__=='__main__':main()
