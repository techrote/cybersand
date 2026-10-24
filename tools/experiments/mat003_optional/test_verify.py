"""Mutate retained controls, reseal them, and require semantic/provenance refusal.

Run with a complete collector output. No candidate is executed by these tests.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

from verify import verify


def exercise(evidence):
    source=Path(evidence)
    original=json.loads((source/'result.json').read_text())
    rows=[]
    with tempfile.TemporaryDirectory(prefix='mat003-optional-negative-') as temporary:
        for name in ('missing-case','wrong-case-binary','changed-compile-flags','accessed-unread','false-array-bytes','timing-relabel'):
            destination=Path(temporary)/name
            shutil.copytree(source,destination)
            result=copy.deepcopy(original)
            if name=='missing-case':result['cases'].pop()
            if name in ('wrong-case-binary','changed-compile-flags'):
                index=5 if name=='wrong-case-binary' else 1
                label='case-000' if index==5 else 'build-tail-8-normal'
                if index==5:result['commands'][index]['argv'][0]=result['commands'][17]['argv'][0]
                else:result['commands'][index]['argv'].append('-Wno-everything')
                (destination/(label+'.receipt.json')).write_text(json.dumps(result['commands'][index]))
            if name in ('accessed-unread','false-array-bytes'):
                index=1 if name=='accessed-unread' else 0
                result['cases'][index]['consumer_reads' if index==1 else 'tail_array_bytes']=1
                row={k:v for k,v in result['cases'][index].items() if k not in ('sanitized','binary_sha256')}
                path=destination/f'case-{index:03d}.stdout';path.write_text(json.dumps(row))
                result['commands'][index+5]['stdout_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
                (destination/f'case-{index:03d}.receipt.json').write_text(json.dumps(result['commands'][index+5]))
            if name=='timing-relabel':result['timing']=True
            (destination/'result.json').write_text(json.dumps(result))
            # Resealing is intentional: a hash-only validator must not satisfy this test.
            seals={p.relative_to(destination).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in destination.rglob('*') if p.is_file() and p.name!='inventory.json'}
            (destination/'inventory.json').write_text(json.dumps(seals))
            try:verify(destination,result['source_commit'],result['registration_sha256'])
            except ValueError as error:rows.append({'case':name,'refused':True,'reason':str(error)})
            else:raise AssertionError('validator accepted '+name)
    return rows


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence',type=Path)
    args=parser.parse_args()
    print(json.dumps(exercise(args.evidence),indent=2))
