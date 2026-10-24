"""Resealed negative archives must not acquire a Wasm portability pass."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

from verify_wasm import verify


def exercise(source,commit,windows_optional,windows_touch):
    source=Path(source);original=json.loads((source/'result.json').read_text());rows=[]
    verify(source,commit,windows_optional,windows_touch)
    names=('missing-case','changed-flags','missing-wasm','wrong-target-abi','false-pointer-bytes','changed-logical-result','runtime-diagnostic','timing-relabel')
    with tempfile.TemporaryDirectory(prefix='mat003-wasm-negative-') as temporary:
        for name in names:
            destination=Path(temporary)/name;shutil.copytree(source,destination);result=copy.deepcopy(original)
            if name=='missing-case':result['cases'].pop()
            elif name=='changed-flags':
                receipt=result['commands'][2];receipt['argv'].append('-sSTACK_OVERFLOW_CHECK=0')
                (destination/'build-optional-8.receipt.json').write_text(json.dumps(receipt))
            elif name=='missing-wasm':
                (destination/'optional-8.wasm').unlink();result['builds'][0]['assets'].pop('optional-8.wasm')
            elif name=='wrong-target-abi':
                path=destination/'wasm_abi.hpp';path.write_bytes(path.read_bytes().replace(b'== 4',b'== 8'));result['abi_assertion_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
            elif name in ('false-pointer-bytes','changed-logical-result'):
                row=result['cases'][0]['result'];row['pointer_capacity_bytes' if name=='false-pointer-bytes' else 'operation_projection_hash']+=1
                path=destination/'case-000.stdout';path.write_text(json.dumps(row));result['commands'][5]['stdout_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
                (destination/'case-000.receipt.json').write_text(json.dumps(result['commands'][5]))
            elif name=='runtime-diagnostic':
                path=destination/'case-000.stderr';path.write_text('runtime error: retained negative fixture\n');result['commands'][5]['stderr_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
                (destination/'case-000.receipt.json').write_text(json.dumps(result['commands'][5]))
            else:result['timing']=True
            (destination/'result.json').write_text(json.dumps(result))
            seals={p.relative_to(destination).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in destination.rglob('*') if p.is_file() and p.name!='inventory.json'}
            (destination/'inventory.json').write_text(json.dumps(seals))
            try:verify(destination,commit,windows_optional,windows_touch)
            except ValueError as error:rows.append({'case':name,'refused':True,'reason':str(error)})
            else:raise AssertionError('validator accepted '+name)
    return rows


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--source-commit',required=True)
    p.add_argument('--windows-optional',type=Path,required=True);p.add_argument('--windows-touch',type=Path,required=True);a=p.parse_args()
    print(json.dumps(exercise(a.evidence,a.source_commit,json.loads(a.windows_optional.read_text()),json.loads(a.windows_touch.read_text())),indent=2))
