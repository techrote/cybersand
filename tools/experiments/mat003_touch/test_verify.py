"""Resealed capture evidence must not hide an altered predicate or native copy."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

from verify import verify


def exercise(source):
    source=Path(source);original=json.loads((source/'result.json').read_bytes());rows=[]
    arguments=(original['source_commit'],original['registration_sha256'],original['compiler_sha256'])
    verify(source,*arguments)
    with tempfile.TemporaryDirectory(prefix='mat003-touch-negative-') as temporary:
        for name in ('missing-case','changed-flags','altered-native-copy','false-restored-support','false-noop','missing-checkpoint'):
            root=Path(temporary)/name;shutil.copytree(source,root);r=copy.deepcopy(original)
            if name=='missing-case':r['cases'].pop()
            elif name=='changed-flags':
                receipt=r['builds'][0]['receipt'];receipt['argv'].append('-Wno-everything')
                (root/'build-normal.receipt.json').write_text(json.dumps(receipt))
            elif name=='altered-native-copy':
                path=root/'compiled/native/src/world.cpp';path.write_bytes(path.read_bytes()+b'\n// undeclared alteration\n')
                r['compiled_sha256']['native/src/world.cpp']=hashlib.sha256(path.read_bytes()).hexdigest()
            else:
                row=r['cases'][0]
                if name=='missing-checkpoint':row['observations'].pop()
                else:row['observations'][0]['restored_support' if name=='false-restored-support' else 'noop_hash_unchanged']=name=='false-restored-support'
                raw={k:v for k,v in row.items() if k not in ('sanitized','binary_sha256','receipt')}
                path=root/'case-0.stdout';path.write_text(json.dumps(raw));row['receipt']['stdout_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
                (root/'case-0.receipt.json').write_text(json.dumps(row['receipt']))
            (root/'result.json').write_text(json.dumps(r))
            (root/'inventory.json').write_text(json.dumps({p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and p.name!='inventory.json'}))
            try:verify(root,*arguments)
            except ValueError as error:rows.append({'case':name,'refused':True,'reason':str(error)})
            else:raise AssertionError('validator accepted '+name)
    return rows


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);a=p.parse_args()
    print(json.dumps(exercise(a.evidence),indent=2))
