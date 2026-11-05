#!/usr/bin/env python3
"""Fixed common-input loader and scalar/bin custody, not contact decisions."""
import hashlib
import json
import subprocess
from pathlib import Path
import sol_passive_values as old

ROOT=Path(__file__).resolve().parents[2]
PROFILE='native/tests/fixtures/sol_active_normal_001.json'

def load():
    profile=json.loads((ROOT/PROFILE).read_text(encoding='utf-8'))
    for name in [PROFILE,profile['additional_inputs']]:
        assert (ROOT/name).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','e7b7f997:'+name],cwd=ROOT),'Post-registration fixture drift'
    raw=(ROOT/profile['base_inputs']).read_bytes();assert hashlib.sha256(raw).hexdigest()==profile['base_inputs_sha256']
    base=json.loads(raw);cases=[]
    for item in base['cases']:
        body,solve,_=old.settings(item,base);bins=[]
        if not item.get('null_bin'):
            points=item.get('points',[item.get('front_point',base['front']['point'])]*item.get('front_samples',64))
            bins=[dict(points=points,normal=item.get('front_normal',base['front']['normal'])) for _ in range(item.get('bins',1))]
        if item.get('support_samples',0):bins.append(dict(points=[[0,0]]*item['support_samples'],normal=item['support_normal']))
        cases.append(dict(id=item['id'],body=body,solve=solve,bins=bins,null_bin=item.get('null_bin',False),oracle=item))
    extra=json.loads((ROOT/profile['additional_inputs']).read_text(encoding='utf-8'))
    for item in extra['cases']:
        body=dict(base['default_body']);body.update({k:item[k] for k in body if k in item})
        solve=dict(base['default_solve']);solve.update({k:item[k] for k in solve if k in item})
        bins=[dict(points=b.get('points',[b.get('point',[0,0])]*b.get('count',0)),normal=b['normal']) for b in item['bins']]
        cases.append(dict(id=item['id'],body=body,solve=solve,bins=bins,null_bin=False,oracle=item))
    assert len(cases)==38 and len({c['id'] for c in cases})==38
    return profile,base,cases

def encode(cases):
    lines=[str(len(cases))]
    for case in cases:
        b=case['body'];s=case['solve']
        fields=[case['id'],*b['velocity'],*b['com'],b['omega'],b['mass'],b['inertia'],b['mu'],s['available'],s['capacity_scale'],s['base_budget'],int(case['null_bin']),len(case['bins'])]
        lines.append(' '.join(map(str,fields)))
        for bin in case['bins']:
            lines.append(' '.join(map(str,[len(bin['points']),*bin['normal']])))
            lines.extend(' '.join(map(str,p)) for p in bin['points'])
    return ('\n'.join(lines)+'\n').encode()
