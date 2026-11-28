#!/usr/bin/env python3
"""Exercise the new causal interval entry on retained actual ON and OFF traces."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import zipfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace-root',type=Path,default=Path('/workspace/scratch/0b2a9bdf7883'))
parser.add_argument('--output',type=Path)
args=parser.parse_args();base=args.workspace_root;root=base/'cybersand'
sys.path.insert(0,str(root/'tools/pubpres_final'))
from causal_completion_contract import observed_intervals
from causal_trace import reduce_causal

sha=lambda data:hashlib.sha256(data).hexdigest()
controls=(
    (base/'evidence-c/14778950415-original.zip','causal/wave_gameplay_2048_follow/0-C/',True),
    (base/'evidence-root/final-03/graphical-linux/original.zip','source-abba/wave_512_follow/1-C-slots2/',False),
)
result={'schema':'pubpres-causal-entry-retained-data-independent-peer-v1',
        'reader_sha256':sha(Path(__file__).read_bytes()),
        'code_sha256':{name:sha((root/'tools/pubpres_final'/name).read_bytes())
                       for name in ('causal_completion_contract.py','causal_completion_registration.json','run_causal_comparison.py')},
        'controls':[],'physical_acceptance':'HOLD',
        'scope':'New entry-method replay on unchanged actual prior ON/OFF raw traces. No source/runtime relabeling, no new Godot process and no future campaign performance conclusion.'}
for archive,prefix,enabled in controls:
    with zipfile.ZipFile(archive) as z:
        raw={name:z.read(prefix+name) for name in ('receipt.json','receipt-events.jsonl','receipt-causal-events.jsonl')}
    with tempfile.TemporaryDirectory(prefix='pubpres-causal-peer-',dir=base/'evidence-c') as temporary:
        folder=Path(temporary)
        for name,value in raw.items():(folder/name).write_bytes(value)
        receipt=folder/'receipt.json'
        causal=reduce_causal(receipt,expected_enabled=enabled)
        intervals=observed_intervals(receipt,causal)
        assert intervals['causal_enabled'] is enabled and intervals['physical_witness']['actual_completed_steps']==144
        assert len(intervals['gaps'])==143
        failures=[]
        def refused(label,call):
            try:call()
            except (ValueError,KeyError,TypeError) as error:
                failures.append({'mutation':label,'refused':True,'message':str(error)})
            else:raise AssertionError('accepted adversary: '+label)
        for label,key,value in [('causal source','source',{}),('base trace hash','base_trace_sha256','0'*64),
                                ('causal trace hash','trace_sha256','0'*64),('bool selection','enabled',int(enabled))]:
            changed=copy.deepcopy(causal);changed[key]=value
            refused(label,lambda:observed_intervals(receipt,changed))
        events=[json.loads(line) for line in raw['receipt-events.jsonl'].splitlines()]
        duplicate=next(e for e in events if e.get('event')=='native_completion_observed')
        altered=events+[duplicate]
        changed_raw=('\n'.join(json.dumps(e) for e in altered)+'\n').encode()
        (folder/'receipt-events.jsonl').write_bytes(changed_raw)
        data=json.loads(raw['receipt.json']);data['trace_sha256']=sha(changed_raw)
        receipt.write_text(json.dumps(data))
        changed=copy.deepcopy(causal);changed['base_trace_sha256']=sha(changed_raw)
        refused('self-consistent duplicate native completion',lambda:observed_intervals(receipt,changed))
        for name,value in raw.items():(folder/name).write_bytes(value)
        # Native readiness and callback start need not be ordered. The existing
        # partition retains this as unavailable, rather than clamping a negative
        # duration into an invented chronological split.
        gaps=intervals['gaps']
        result['controls'].append({'archive':str(archive.relative_to(base)),'members_sha256':{prefix+k:sha(v) for k,v in raw.items()},
                                  'source':json.loads(raw['receipt.json'])['source_identity']['source_sha'],
                                  'enabled':enabled,'actual_completed_steps':144,'intervals':intervals,
                                  'adversaries':failures})
result['passed']=True
output=args.output or base/'evidence-c/causal-entry-retained-data-independent-peer.json'
output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'output':str(output),'sha256':sha(output.read_bytes()),'controls':len(result['controls']),
                  'adversaries':sum(len(c['adversaries']) for c in result['controls']),'passed':True}))
