"""Independent v1 controls; retains inputs, observations and conservation failures."""
import argparse,json,subprocess
from pathlib import Path
from run import ROOT,identity

p=argparse.ArgumentParser();p.add_argument('output',type=Path);p.add_argument('--profiles',type=Path,required=True)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
exe=ROOT/'build/transport_sampling.exe'
profiles=[a.profiles/'2-0.ints',*sorted(a.profiles.glob('*-*.ints'))]
profiles=list(dict.fromkeys(v for v in profiles if v.stem=='2-0' or not v.stem[0].isdigit()))
(a.output/'manifest.json').write_text(json.dumps(identity([exe,*profiles]),indent=2))
out=[]
for profile in profiles:
    for layout in ['powder','loose','erosion']:
        key=profile.stem+'-'+layout
        cmd=[str(exe),layout,'0','1','1800',str(profile)]
        r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
        (a.output/(key+'.jsonl')).write_text(r.stdout)
        (a.output/(key+'.execution.json')).write_text(json.dumps(dict(command=cmd,exit=r.returncode,stderr=r.stderr,timeout_seconds=180)))
        r.check_returncode();rows=[json.loads(line) for line in r.stdout.splitlines()]
        for row in rows[:-1]:
            assert all(row['counts'][i]==rows[0]['counts'][i] for i in [2,14,33]),key
            assert row['water']==rows[0]['water'],key
        assert rows[-1]['allocations']==0 and rows[-1]['overflow']==0,key
        events={str(k):sum(v for e,v in rows[-1]['events'] if e>>24==k) for k in range(1,12)}
        out.append(dict(id=key,profile=profile.stem,layout=layout,events=events,final=rows[-2],work=rows[-1]))
        print(key,events['8'],events['9'],rows[-2]['interface_edges'],flush=True)
(a.output/'results.json').write_text(json.dumps(out,indent=2))
powder={r['profile']:r for r in out if r['layout']=='powder'}
assert powder['mixing-0']['events']['8']==0
assert powder['mixing-255']['events']['8']>powder['2-0']['events']['8']
for key in ['carrying-0','carrying-64','pickup-0','pickup-255','packing-0','packing-32','cadence-4','cadence-60']:
    assert powder[key]['final']==powder['2-0']['final'],key+' changed independent powder behavior'
for r in out:
    if r['layout']!='powder' and r['profile'] in ['carrying-0','pickup-255']: assert r['events']['9']==0,r['id']
print('Independent controls and conservation passed')
