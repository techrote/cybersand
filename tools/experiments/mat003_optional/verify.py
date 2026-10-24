"""Read-only completeness, command, source and accounting checks for optional tails."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(root, expected_commit, expected_registration):
    root=Path(root).resolve()
    inventory=json.loads((root/'inventory.json').read_text())
    actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='inventory.json'}
    if actual!=set(inventory):raise ValueError('missing/extra evidence')
    for name,seal in inventory.items():
        path=root/name
        if not path.resolve().is_relative_to(root) or path.is_symlink() or digest(path)!=seal:
            raise ValueError('evidence seal mismatch')
    result=json.loads((root/'result.json').read_text())
    registration_path=root/'source/tools/experiments/mat003_optional/registration.json'
    if digest(registration_path)!=expected_registration or result['registration_sha256']!=expected_registration:
        raise ValueError('registration identity')
    registration=json.loads(registration_path.read_text())
    if result.get('status')!='passed' or result.get('timing') is not False or result.get('source_commit')!=expected_commit:
        raise ValueError('result identity/completion')
    for name,seal in result['source_sha256'].items():
        path=root/'source'/name
        if not path.resolve().is_relative_to(root/'source') or digest(path)!=seal:raise ValueError('source seal mismatch')
        git_bytes=subprocess.check_output(['git','show',expected_commit+':'+name])
        if path.read_bytes().replace(b'\r\n',b'\n')!=git_bytes.replace(b'\r\n',b'\n'):
            raise ValueError('source differs from frozen Git content')
    if len(result['builds'])!=4 or len(result['cases'])!=48 or len(result['commands'])!=53:
        raise ValueError('incomplete matrix')
    expected_builds=list(itertools.product((False,True),(8,16)))
    if [(b['sanitized'],b['bits']) for b in result['builds']]!=expected_builds:
        raise ValueError('build order/identity')
    for build in result['builds']:
        if digest(root/build['binary'])!=build['sha256']:raise ValueError('binary seal mismatch')
    expected_cases=[(san,bits,side,mode) for san,bits in expected_builds for side in (512,1024,2048)
                    for mode in ('absent','allocated-unread','accessed-clustered','accessed-dispersed')]
    if [(r['sanitized'],r['tail_bits'],r['side'],r['mode']) for r in result['cases']]!=expected_cases:
        raise ValueError('case order/identity')
    labels=['compiler-version']+['build-tail-'+str(bits)+'-'+('sanitized' if san else 'normal') for san,bits in expected_builds]+[f'case-{i:03d}' for i in range(48)]
    for index,(label,command) in enumerate(zip(labels,result['commands'])):
        if json.loads((root/(label+'.receipt.json')).read_text())!=command:raise ValueError('command receipt drift')
        if command['exit_code'] or command['stop'] or (root/(label+'.stderr')).stat().st_size:
            raise ValueError('failed command/diagnostic')
        if command['elapsed_watchdog_seconds']>command['timeout_seconds']+1:raise ValueError('command timeout')
        for stream in ('stdout','stderr'):
            if digest(root/(label+'.'+stream))!=command[stream+'_sha256']:raise ValueError('command stream seal')
        if index>=5 and json.loads((root/(label+'.stdout')).read_text())!={k:v for k,v in result['cases'][index-5].items() if k not in ('sanitized','binary_sha256')}:
            raise ValueError('case stdout substitution')
    for row in result['cases']:
        side=row['side'];chunks=(side//128)**2;width=row['tail_bits']//8
        allocated=0 if row['mode']=='absent' else chunks if row['mode']=='accessed-dispersed' else 2
        if row['status']!='passed' or row['timing'] is not False or row['checks']<side*side:
            raise ValueError('missing correctness/reference checks')
        if (row['cell_size'],row['cell_alignment'],row['tail_element_size'],row['tail_element_alignment'])!=(8,8,width,width):
            raise ValueError('storage ABI')
        if (row['resident_owners'],row['allocated_owners'],row['allocations'])!=(chunks,allocated,allocated):
            raise ValueError('owner allocation accounting')
        if row['tail_array_bytes']!=allocated*16384*width or row['dense_tail_arithmetic_bytes']!=side*side*width:
            raise ValueError('array footprint accounting')
        if row['base_capacity_bytes']<side*side*8 or row['pointer_capacity_bytes']<chunks*8:
            raise ValueError('capacity below live allocation')
        if row['mode']=='allocated-unread' and (row['consumer_reads'] or row['consumer_writes'] or row['nonzero_payloads']):
            raise ValueError('unread state was accessed')
        if row['mode'].startswith('accessed-') and not (row['consumer_reads'] and row['consumer_writes'] and row['nonzero_payloads']):
            raise ValueError('vacuous accessed state')
        if row['mode']=='absent' and (row['consumer_reads']!=1 or row['consumer_writes'] or row['nonzero_payloads']):
            raise ValueError('absent state contract')
        build=next(b for b in result['builds'] if (b['bits'],b['sanitized'])==(row['tail_bits'],row['sanitized']))
        if row['binary_sha256']!=build['sha256']:raise ValueError('case uses wrong binary')
    for bits,side in itertools.product((8,16),(512,1024,2048)):
        rows=[r for r in result['cases'] if r['tail_bits']==bits and r['side']==side and r['mode'].startswith('accessed-')]
        if len({r['operation_projection_hash'] for r in rows})!=1:raise ValueError('cross-layout/configuration projection')
    return {'status':'verified','cases':48,'builds':4,'timing':False,'validation_class':'author-validation-pending-independent-review'}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence',type=Path)
    parser.add_argument('--source-commit',required=True)
    parser.add_argument('--registration-sha256',required=True)
    args=parser.parse_args()
    print(json.dumps(verify(args.evidence,args.source_commit,args.registration_sha256),indent=2))
