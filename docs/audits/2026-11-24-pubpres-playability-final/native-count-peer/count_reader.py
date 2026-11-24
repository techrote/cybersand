#!/usr/bin/env python3
"""Independent source-bound regression of the count attribution review findings."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--repository',type=Path,default=Path('/workspace/scratch/0b2a9bdf7883/cybersand'))
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();root=a.repository.resolve();output=a.output.resolve()
if output.exists():raise ValueError('Preserve original independent peer report')
sys.path.insert(0,str(root/'tools/pubpres_final'))
from test_material_steps_contract import evidence
from material_steps_contract import validate_evidence,validate_registration
from material_steps_status import live_bridge_identity

files=['tools/pubpres_final/material_steps_contract.py','tools/pubpres_final/material_steps_status.py',
       'tools/pubpres_final/material_steps_oracle.py','tools/pubpres_final/test_material_steps_contract.py']
hashes={}
for name in files:
    raw=(root/name).read_bytes()
    if raw!=subprocess.check_output(['git','-C',str(root),'show','07bb22a1:'+name]):
        raise ValueError('Reviewed07 source changed: '+name)
    hashes[name]=hashlib.sha256(raw).hexdigest()
values=evidence();steps=[row for row in values[1] if row['event']=='rapier_step']
steps[2]['time_usec']=125000;steps[3]['time_usec']=135000
try:validate_evidence(*values,2)
except ValueError as error:stale_reason=str(error)
else:raise ValueError('Stale but real anchor survived')
bad_bridges=[0,'0','-0','+1','01',False,1.0,str(2**63),str(-2**63-1)]
for value in bad_bridges:
    try:live_bridge_identity(value)
    except ValueError:pass
    else:raise ValueError('Malformed live bridge admitted: '+repr(value))
valid_bridges=[-2**63,2**63-1,-1234,1234]
for value in valid_bridges:
    if live_bridge_identity(str(value))!=value:raise ValueError('Valid signed64 bridge rejected')
registration=json.loads((root/'tools/pubpres_final/material_steps_registration.json').read_bytes())
controls=[]
for key,value in registration.items():
    if type(value) is int:
        for wrong in [float(value),False]:
            item=copy.deepcopy(registration);item[key]=wrong
            try:validate_registration(item)
            except ValueError:controls.append({'field':key,'type':type(wrong).__name__})
            else:raise ValueError('Coerced registration accepted: '+key)
for index,value in [(0,False),(1,2.0)]:
    item=copy.deepcopy(registration);item['order'][index]=value
    try:validate_registration(item)
    except ValueError:controls.append({'field':'order['+str(index)+']','type':type(value).__name__})
    else:raise ValueError('Coerced registration order accepted')
report={'schema':'pubpres-count-independent-review-resolution-v1',
        'reviewed_fix':'07bb22a1baa24a52e9ca0c3ded2c279386cf7d67',
        'observed_repository_head':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),
        'reader_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_files_sha256':hashes,
        'stale_but_real_anchor':{'actual_latest_step':14,'forged_anchor':12,'rejected':True,'reason':stale_reason},
        'malformed_bridge_controls_rejected':len(bad_bridges),'valid_signed64_controls':valid_bridges,
        'registration_controls_rejected':controls,'complete':True,'physical_acceptance':'HOLD',
        'scope':'Independent parser/source review only. The old ca006d22 reader accepted the stale12 anchor despite13/14 completing before take and misclassified it as deadline-only; the exact repaired source now refuses it. Main drain is synchronous outside the callback observer. The explicit pre-capture join cannot supply independent treatment credit. No runtime/timing result is created.'}
output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'complete':True,'output':str(output),'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}))
