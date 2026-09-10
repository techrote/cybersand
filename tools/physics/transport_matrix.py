"""Run fixed profile comparisons with prepared inputs and retained failures."""
import argparse,json,subprocess,shutil
from pathlib import Path
from run import ROOT,identity

p=argparse.ArgumentParser();p.add_argument('output',type=Path);p.add_argument('--profiles',type=Path,required=True)
p.add_argument('--smoke',action='store_true')
p.add_argument('--reuse',type=Path,help='Retain unaffected runs from an earlier matrix; rerun sustained and seed-zero Water depth fixtures')
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
exe=ROOT/'build/transport_sampling.exe'
artifacts=[exe,*a.profiles.glob('*.ints'),*a.profiles.glob('*.json')]
manifest=identity(artifacts)
if a.reuse:
    old=json.loads((a.reuse/'manifest.json').read_text())
    core=lambda m:{k:v for k,v in m['source_files'].items() if k.startswith(('native/src/','native/include/'))}
    packets=lambda m:{Path(k).name:v for k,v in m['artifacts'].items() if k.endswith('.ints')}
    if core(old)!=core(manifest) or packets(old)!=packets(manifest):
        raise ValueError('Cannot reuse runs with different native rules or resolved profiles')
    # The caller must also inspect the declared unaffected benchmark layouts;
    # manifests retain both benchmark versions rather than hiding that change.
    manifest['reuse_validation']='native source/header and resolved packet hashes match; benchmark-only corrections remain explicitly declared'
    shutil.copyfile(a.reuse/'manifest.json',a.output/'reused-manifest.json')
(a.output/'manifest.json').write_text(json.dumps(manifest,indent=2))
results=[]
for profile in range(3):
    for sampled in ([0] if a.smoke else [0,1]):
        for layout in ['powder','erosion','loose','poured','packed','film','sparse','sustained']:
            for seed in ([0] if a.smoke else range(5)):
                for workers in ([1] if a.smoke else [1,4]):
                    key=f'p{profile}-h{sampled}-{layout}-s{seed}-w{workers}'
                    reused=bool(a.reuse) and layout!='sustained' and not (seed==0 and layout in ['erosion','loose','sparse'])
                    cmd=[str(exe),layout,str(seed),str(workers),'1800',str(a.profiles/f'{profile}-{sampled}.ints')]
                    if reused:
                        for suffix in ['.jsonl','.execution.json']:
                            shutil.copyfile(a.reuse/(key+suffix),a.output/(key+suffix))
                    else:
                        r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
                        (a.output/(key+'.jsonl')).write_text(r.stdout)
                        (a.output/(key+'.execution.json')).write_text(json.dumps(dict(command=cmd,exit=r.returncode,stderr=r.stderr,timeout_seconds=180)))
                        r.check_returncode()
                    rows=[json.loads(line) for line in (a.output/(key+'.jsonl')).read_text().splitlines()]
                    events={str(k):sum(v for e,v in rows[-1]['events'] if e>>24==k) for k in range(1,12)}
                    summary=dict(id=key,profile=profile,sampled=sampled,layout=layout,seed=seed,workers=workers,reused=reused,
                                 events=events,final=rows[-2],work=rows[-1])
                    results.append(summary)
                    print(key,{k:events[k] for k in ['8','9','10','11']},'interface',rows[-2]['interface_contacts'],
                          'deposit',rows[-2]['deposited'],'eroded',rows[-2]['eroded_sites'],'late',rows[-1]['late_moves'],flush=True)
(a.output/'results.json').write_text(json.dumps(results,indent=2))
