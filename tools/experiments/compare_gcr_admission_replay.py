"""Exact selected admission replays, retaining actual application and probe counters."""
import hashlib
import json
from pathlib import Path

from compare_gcr_admission_r2 import projection, diff, digest

ROOT=Path(__file__).resolve().parents[2]


def physical(report):
    value=projection(report)
    for old,new in zip(value['rows'],report['rows']):
        if 'admission'in new:old['admission']=new['admission']
        if 'gcr'in new and 'admission'in new['gcr']:old['gcr']['admission']=new['gcr']['admission']
    return value


def main():
    primary=ROOT/'build/admission-primary/campaign.json';replay=ROOT/'build/admission-replay/campaign.json'
    a=json.loads(primary.read_text(encoding='utf-8'));b=json.loads(replay.read_text(encoding='utf-8'))
    for k in ['source','protocol_sha256','native_sha256','rapier_sha256','input_identity']:
        if a['identity'][k]!=b['identity'][k]:raise RuntimeError('Different replay identity '+k)
    lookup={(r['case'],r['arm']):r for r in a['captures']};records=[]
    for cap in b['captures']:
        original=lookup[cap['case'],cap['arm']];refraw=(primary.parent/original['raw']).read_bytes();raw=(replay.parent/cap['raw']).read_bytes()
        if hashlib.sha256(refraw).hexdigest()!=original['raw_sha256']or hashlib.sha256(raw).hexdigest()!=cap['raw_sha256']:raise RuntimeError('Raw hash changed')
        before=physical(json.loads(refraw));after=physical(json.loads(raw));mismatch=diff(before,after)
        records.append({'case':cap['case'],'arm':cap['arm'],'exact_selected_physical_values':mismatch is None,
                        'reference_raw_sha256':original['raw_sha256'],'replay_raw_sha256':cap['raw_sha256'],
                        'reference_physical_sha256':digest(before),'replay_physical_sha256':digest(after),'first_difference':mismatch})
    output={'schema':1,'identity':{k:v for k,v in a['identity'].items()if k!='project_inputs'},
            'scope':'Selected physical/material observations and actual application/refusal/age/translated wrench plus immutable admission counters; clocks and sample/session/snapshot identifiers excluded. Not full cell-state equality.',
            'projection_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'base_projection_script_sha256':hashlib.sha256((ROOT/'tools/experiments/compare_gcr_admission_r2.py').read_bytes()).hexdigest(),
            'all_exact':all(r['exact_selected_physical_values']for r in records),'records':records}
    (ROOT/'build/admission-replay-comparison.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
    print(len(records),'selected physical replays; all exact',output['all_exact'])


if __name__=='__main__':main()
