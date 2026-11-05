#!/usr/bin/env python3
"""Portable value and merit audit, plus corrupted-premise refusal controls."""
from copy import deepcopy
import hashlib
import json
import math
import sol_active_normal_inputs as inputs
import sol_active_normal_audit as audit
import sol_active_normal_compare as comparison

def main():
    profile,base,cases=inputs.load();folder=inputs.ROOT/'docs/audits/sol-active-normal-20261105'
    manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    for item in manifest['files']:
        raw=(folder/item['path']).read_bytes();assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
    arms=[json.loads((folder/f'arm-{a}.json').read_text(encoding='utf-8')) for a in range(3)]
    assert [r['observation'] for r in arms[0]['cases']]==[r['observation'] for r in arms[1]['cases']]
    metrics=[[audit.record(c,r,a) for c,r in zip(cases,arms[a]['cases'])] for a in range(3)]
    for c,m in zip(cases,metrics[2]):
        if c['id'] in profile['benefit_targets']:assert not m['refused'] and math.hypot(*m['velocity'])<=1e-12 and m['normal_cap_hits']==0
        if not m['early_refusal']:assert m['normal_energy_increase_max']<=profile['normal_energy_tolerance']
    original=json.loads((inputs.ROOT/'docs/audits/sol-chamber-20261105/passive-observations.json').read_text(encoding='utf-8'))
    assert [r['observation'] for r in arms[0]['cases'][:25]]==[r['observation'] for r in original['cases']]
    receipt=json.loads((folder/'execution.json').read_text(encoding='utf-8'))
    # File resolution uses equal parsed values; original raw-byte receipt is intact.
    for entry in receipt['executions']:
        path=folder/f"arm-{entry['arm_index']}.json"
        entry['process']['log']=path.relative_to(inputs.ROOT).as_posix()
        entry['process']['log_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    verdict=comparison.compare(receipt)
    assert verdict['candidate_decision']=='PASS' and all(p['decision']=='PASS' for p in verdict['platforms'])
    def corrupt(case_id,change):
        index=next(i for i,c in enumerate(cases) if c['id']==case_id);record=deepcopy(arms[2]['cases'][index]);change(record)
        try:audit.record(cases[index],record,2)
        except AssertionError:return
        raise AssertionError('Corrupt record admitted')
    corrupt('capacity-not-redistributed',lambda r:r['observation']['nodes'][0].update(capacity=.5))
    corrupt('loaded-unwind',lambda r:r['trace'][2]['active'].__setitem__(0,False))
    corrupt('support-64',lambda r:r['trace'][0]['weight_used'].__setitem__(0,.5))
    corrupt('max-two-nodes',lambda r:r['observation']['result'].update(nodes=1))
    corrupt('loaded-unwind',lambda r:r['observation']['result'].update(raw_torque=0))
    corrupt('front',lambda r:r.update(replays_equal=False))
    corrupt('null',lambda r:r['observation']['result'].update(impulse=[1,0]))
    print(json.dumps(dict(cases=38,arms=3,source=manifest['execution_source'],benefit_targets=9,corruptions_refused=7,scope='Portable copied-value audit; no runtime/SOL admission')))

if __name__=='__main__':main()
