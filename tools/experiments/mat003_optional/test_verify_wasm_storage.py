"""Resealed S0 archives must retain the registered matrix and accepted bytes."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

from verify_wasm_storage import verify


def exercise(source,commit,linux_archive):
    source=Path(source);original=json.loads((source/'result.json').read_bytes());rows=[]
    verify(source,commit,linux_archive)
    with tempfile.TemporaryDirectory(prefix='mat003-wasm-storage-negative-') as temporary:
        for name in ('missing-arm','consistent-altered-records','imported-x64-descriptor','changed-build-flags'):
            root=Path(temporary)/name;shutil.copytree(source,root);r=copy.deepcopy(original)
            if name=='changed-build-flags':
                r['commands'][2]['argv'].append('-sSTACK_OVERFLOW_CHECK=0')
                (root/'build-storage.receipt.json').write_text(json.dumps(r['commands'][2]))
            else:
                if name=='missing-arm':r['storage_result']['arms'].pop()
                elif name=='imported-x64-descriptor':
                    for arm in r['storage_result']['arms']:
                        if arm['representation']=='split':arm['descriptor_bytes']=72
                else:
                    for arm in r['storage_result']['arms']:
                        raw=bytearray.fromhex(arm['semantic_records_hex']);raw[0]^=1
                        arm['semantic_records_hex']=raw.hex();value=14695981039346656037
                        for byte in raw:value=((value^byte)*1099511628211)&((1<<64)-1)
                        arm['semantic_digest']=f'{value:016x}'
                path=root/'case-storage.stdout';path.write_text(json.dumps(r['storage_result']))
                r['commands'][3]['stdout_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
                (root/'case-storage.receipt.json').write_text(json.dumps(r['commands'][3]))
            (root/'result.json').write_text(json.dumps(r))
            (root/'inventory.json').write_text(json.dumps({p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and p.name!='inventory.json'}))
            try:verify(root,commit,linux_archive)
            except ValueError as error:rows.append({'case':name,'refused':True,'reason':str(error)})
            else:raise AssertionError('validator accepted '+name)
    return rows


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--source-commit',required=True);p.add_argument('--linux-archive',type=Path,required=True);a=p.parse_args()
    print(json.dumps(exercise(a.evidence,a.source_commit,a.linux_archive),indent=2))
