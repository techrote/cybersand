#!/usr/bin/env python3
"""Portable paired raw audit; no World/import or executable runtime required."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import uuid
import sol_chamber_cost_reduce as c

def main():
    root=c.ROOT;packet=root/'docs/audits/sol-response-cost-20261105'
    original=json.loads((packet/'execution.json').read_text(encoding='utf-8'))
    index=json.loads((packet/'reference-payload-index.json').read_text(encoding='utf-8'))
    source_data={o:json.loads((packet/('raw-'+o+'.json')).read_text(encoding='utf-8')) for o in ['full','minimal']}
    def resolve(value):
        path=(root/index[value]).resolve()
        assert path.is_relative_to(root/'docs/audits/sol-chamber-20261105/reference-payloads')
        return path
    c.g.r.local_path=resolve
    workspace=root/'build/sol-response-cost'/('portable-'+uuid.uuid4().hex);workspace.mkdir(parents=True)
    def run(name,mutation=None,failed_process=False):
        folder=workspace/name;folder.mkdir();receipt=deepcopy(original)
        receipt['matrix']=dict(platforms=['windows'],cases=['closed-driven'],workers=[1],repeats=1,observers=['full','minimal'])
        receipt['campaign_elapsed_seconds']=None
        receipt['portable_scope']='two-report derivative; original execution receipt is unchanged'
        receipt['results']=[]
        for observer in ['full','minimal']:
            data=deepcopy(source_data[observer])
            if mutation and observer=='minimal':mutation(data)
            path=folder/(observer+'.json');raw=(json.dumps(data,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
            proc=next(p for p in original['results'] if p['platform']=='windows' and p['name']=='closed-driven-'+observer+'-w1-r0')
            proc=deepcopy(proc);proc['reports']=[dict(path=path.relative_to(root).as_posix(),sha256=hashlib.sha256(raw).hexdigest())]
            if failed_process and observer=='minimal':proc['clean']=False;proc['exit']=1
            receipt['results'].append(proc)
        (folder/'receipt.json').write_bytes((json.dumps(receipt)+'\n').encode())
        sys.argv=[str(Path(__file__)),str(folder)];c.main()
        return json.loads((folder/'reduction/summary.json').read_text(encoding='utf-8'))
    baseline=run('baseline');assert baseline['all_pairs_equivalent'] and baseline['complete_requested_matrix'] and not baseline['full_registered_matrix']
    mutations=[
        lambda d:d['steps'][0].pop('payload'),
        lambda d:(d['steps'][0]['sample'].update(epoch=d['initial_sample']['epoch']+1),d['steps'][0]['response'].update(epoch=d['initial_sample']['epoch']+1)),
        lambda d:d['steps'][0]['sample']['states'].__setitem__(5*17+10,999),
        lambda d:d['case'].update(driven=False),
        lambda d:d['construction_receipt'].update(worker_threads=4),
        lambda d:d['steps'][0]['response']['rows'][0].update(generation=2),
        lambda d:d['steps'][0]['response']['rows'][0].update(external_drive=True),
    ]
    refused=0
    for number,change in enumerate(mutations):
        try:run('corrupt-'+str(number),change)
        except AssertionError:refused+=1
        else:raise AssertionError('Corrupted premise admitted')
    failed=run('failed-process',failed_process=True)
    assert not failed['all_pairs_equivalent'] and not failed['complete_requested_matrix'] and failed['pairs'][0].get('elapsed_difference_us') is None
    assert refused==len(mutations)
    print(json.dumps(dict(raw_reference_pairs=1,corruptions_refused=refused,failed_process_latency_refused=True,scope='portable reference only; full external matrix review pending',artifacts=workspace.relative_to(root).as_posix())))

if __name__=='__main__':main()
