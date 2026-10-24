"""Read-only archived Linux source/command/result and cross-platform reconciliation."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path, PurePosixPath
import subprocess

from comparison_contract import authenticate_comparator, compare_result


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(root, expected_commit, windows_optional=None, windows_touch=None):
    if windows_optional is not None: authenticate_comparator('optional', windows_optional)
    if windows_touch is not None: authenticate_comparator('touch', windows_touch)
    root=Path(root).resolve();inventory=json.loads((root/'inventory.json').read_text())
    if set(inventory)!={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='inventory.json'}:
        raise ValueError('evidence inventory')
    for name,seal in inventory.items():
        p=root/name
        if not p.resolve().is_relative_to(root) or p.is_symlink() or digest(p)!=seal:raise ValueError('evidence seal')
    r=json.loads((root/'result.json').read_text())
    if r.get('status')!='passed' or r.get('timing') is not False or r.get('source_commit')!=expected_commit:
        raise ValueError('result identity/completion')
    regpath=root/'source/tools/experiments/mat003_optional/linux-registration-v2.json'
    if r['registration_sha256']!=digest(regpath):raise ValueError('registration seal')
    spec=json.loads(regpath.read_text())
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',expected_commit,'native','tools/experiments/mat003_optional','tools/experiments/mat003_touch'],text=True).splitlines()
    required={name for name in names if (name.startswith(('native/include/','native/src/')) and PurePosixPath(name).suffix in ('.cpp','.hpp')) or
              (name.startswith(('tools/experiments/mat003_optional/','tools/experiments/mat003_touch/')) and len(PurePosixPath(name).parts)==4 and PurePosixPath(name).suffix in ('.cpp','.py','.json'))}
    if set(r['source_sha256'])!=required:raise ValueError('incomplete source snapshot')
    for name,seal in r['source_sha256'].items():
        p=root/'source'/name
        if digest(p)!=seal or p.read_bytes()!=subprocess.check_output(['git','show',expected_commit+':'+name]):raise ValueError('frozen source mismatch')
    native={name for name in required if name.startswith('native/')}
    if set(r['compiled_sha256'])!=native:raise ValueError('compiled inventory')
    overlay=json.loads((root/'source/tools/experiments/mat003_touch/registration-v3.json').read_text())['source_overlay']
    for name,seal in r['compiled_sha256'].items():
        before=(root/'source'/name).read_bytes();expected=before
        if name==overlay['file']:
            if before.count(overlay['old'].encode())!=1:raise ValueError('overlay context')
            expected=before.replace(overlay['old'].encode(),overlay['new'].encode())
        if (root/'compiled'/name).read_bytes()!=expected or digest(root/'compiled'/name)!=seal:raise ValueError('literal overlay mismatch')
    builds=[('optional',bits,san) for san in (False,True) for bits in (8,16)]+[('touch',0,san) for san in (False,True)]
    if [(b['kind'],b['bits'],b['sanitized']) for b in r['builds']]!=builds or len(r['cases'])!=54:raise ValueError('matrix coverage')
    for b in r['builds']:
        if digest(root/b['path'])!=b['sha256']:raise ValueError('binary seal')
    labels=['compiler-version','linker-path','linker-version','library-package-versions','library-libstdc++.so','library-libgcc_s.so.1']
    labels+=['build-'+b['path'] for b in r['builds']]+[f'case-{i:03d}' for i in range(54)]
    if len(r['commands'])!=len(labels):raise ValueError('command count')
    original_root=r['commands'][6]['argv'][-1].rsplit('/',1)[0]
    def normal(argv):return [str(v).replace(original_root,'$EVIDENCE') for v in argv]
    expected_commands=[[r['compiler'],'-dumpfullversion'],[r['compiler'],'-print-prog-name=ld'],[r['linker'],'--version'],
                       ['dpkg-query','-W','libc6','libstdc++6','libgcc-s1','g++-13','binutils'],
                       [r['compiler'],'-print-file-name=libstdc++.so'],[r['compiler'],'-print-file-name=libgcc_s.so.1']]
    for b in r['builds']:
        flags=spec['sanitizer_flags' if b['sanitized'] else 'normal_flags']
        args=[r['compiler'],*flags,'-B'+r['linker'].rsplit('/',1)[0]+'/','-fuse-ld=bfd']
        if b['kind']=='optional':args += [f"-DMAT003_TAIL_BITS={b['bits']}",'-I$EVIDENCE/source/native/include','$EVIDENCE/source/tools/experiments/mat003_optional/fixture.cpp']
        else:args += [*spec['touch_additional_flags'],'-I$EVIDENCE/compiled/native/include','$EVIDENCE/source/tools/experiments/mat003_touch/fixture.cpp',
                     *('$EVIDENCE/compiled/native/src/'+n for n in ('world.cpp','material_rules.cpp','scheduler_geometry.cpp','settled_world_discovery.cpp'))]
        expected_commands.append([*args,'-o','$EVIDENCE/'+b['path']])
    cases=[]
    for b in r['builds']:
        contexts=list(itertools.product((512,1024,2048),('absent','allocated-unread','accessed-clustered','accessed-dispersed'))) if b['kind']=='optional' else [('serial-1',),('phased-1',),('phased-4',)]
        cases.extend((b,c) for c in contexts)
        expected_commands.extend([['$EVIDENCE/'+b['path'],*map(str,c)] for c in contexts])
    for i,(label,receipt) in enumerate(zip(labels,r['commands'])):
        if json.loads((root/(label+'.receipt.json')).read_text())!=receipt:raise ValueError('command receipt drift')
        if receipt['exit_code'] or receipt['stop'] or (root/(label+'.stderr')).stat().st_size:raise ValueError('failed invocation')
        if normal(receipt['argv'])!=expected_commands[i]:raise ValueError('ordered command binding')
        if receipt['elapsed_watchdog_seconds']>receipt['timeout_seconds']+1:raise ValueError('command watchdog')
        for stream in ('stdout','stderr'):
            if digest(root/(label+'.'+stream))!=receipt[stream+'_sha256']:raise ValueError('stream seal')
    for index,(row,(build,context)) in enumerate(zip(r['cases'],cases)):
        if row['kind']!=build['kind'] or row['sanitized']!=build['sanitized'] or row['binary_sha256']!=build['sha256']:raise ValueError('case binary binding')
        data=row['result']
        compare_result(row['kind'], data)
        if data!=json.loads((root/f'case-{index:03d}.stdout').read_text()) or data['status']!='passed' or data['timing'] is not False:raise ValueError('case result substitution')
        if row['kind']=='optional':
            if (data['tail_bits'],data['side'],data['mode'])!=(build['bits'],*context):raise ValueError('optional context')
            if windows_optional is not None:
                win=next(c for c in windows_optional['cases'] if (c['tail_bits'],c['sanitized'],c['side'],c['mode'])==(build['bits'],build['sanitized'],*context))
                compare_result('optional', data, win)
        elif windows_touch is not None:
            win=next(c for c in windows_touch['cases'] if (c['sanitized'],c['mode'])==(build['sanitized'],context[0]))
            compare_result('touch', data, win)
    if r['elapsed_watchdog_seconds']>spec['limits']['aggregate_seconds']:raise ValueError('aggregate watchdog')
    return {'status':'verified','builds':6,'optional_cases':48,'touch_cases':6,'timing':False,
            'windows_optional_compared':bool(windows_optional),'windows_touch_compared':bool(windows_touch),
            'validation_class':'author-validation-pending-independent-review'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--source-commit',required=True)
    p.add_argument('--windows-optional',type=Path);p.add_argument('--windows-touch',type=Path);args=p.parse_args()
    print(json.dumps(verify(args.evidence,args.source_commit,
                           json.loads(args.windows_optional.read_text()) if args.windows_optional else None,
                           json.loads(args.windows_touch.read_text()) if args.windows_touch else None),indent=2))
