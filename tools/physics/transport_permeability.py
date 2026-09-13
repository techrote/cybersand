"""Screen permeability independently against the retained period-30 front."""
import argparse,json,subprocess
from pathlib import Path
from run import ROOT,identity

p=argparse.ArgumentParser();p.add_argument('output',type=Path);p.add_argument('--profiles',type=Path,required=True)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
exe=ROOT/'build/transport_sampling.exe'
profiles={1:a.profiles/'permeability-1.ints',30:a.profiles/'2-0.ints',60:a.profiles/'permeability-60.ints'}
(a.output/'manifest.json').write_text(json.dumps(identity([exe,*profiles.values()]),indent=2))
out=[]
for period,profile in profiles.items():
    previous=None
    for workers in [1,4]:
        key=f'period-{period}-w{workers}'
        cmd=[str(exe),'packed','0',str(workers),'1800',str(profile)]
        r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
        (a.output/(key+'.jsonl')).write_text(r.stdout)
        (a.output/(key+'.execution.json')).write_text(json.dumps(dict(command=cmd,exit=r.returncode,stderr=r.stderr,timeout_seconds=180)))
        r.check_returncode();rows=[json.loads(line) for line in r.stdout.splitlines()]
        assert rows[-1]['allocations']==0 and rows[-1]['overflow']==0
        for row in rows[:-1]:
            assert row['counts'][2]==1024 and row['counts'][33]==512 and row['water']==0
        assert rows[5]['tick']==300 and rows[5]['front']==min(32,300//period),(key,rows[5]['front'])
        if previous is not None: assert rows[:-1]==previous
        previous=rows[:-1]
        out.append(dict(period=period,workers=workers,front_at_300=rows[5]['front'],final=rows[-2],work=rows[-1]))
(a.output/'results.json').write_text(json.dumps(out,indent=2))
print('Six permeability controls passed: tick-300 fronts 32 / 10 / 5 for periods 1 / 30 / 60')
