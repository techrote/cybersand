"""Read-only source, command and observation verification of the Windows probe."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path, PurePosixPath
import subprocess


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(root,source_commit,registration_sha256,compiler_sha256):
    root=Path(root).resolve();r=json.loads((root/'result.json').read_bytes());inventory=json.loads((root/'inventory.json').read_bytes())
    if set(inventory)!={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='inventory.json'}:raise ValueError('evidence inventory')
    for name,seal in inventory.items():
        path=root/name
        if not path.resolve().is_relative_to(root) or path.is_symlink() or digest(path)!=seal:raise ValueError('evidence seal')
    if r.get('status')!='passed' or r.get('timing') is not False or r.get('source_commit')!=source_commit:raise ValueError('source/completion identity')
    reg=root/'source/tools/experiments/mat003_touch/registration-v3.json';spec=json.loads(reg.read_bytes())
    if digest(reg)!=registration_sha256 or r['registration_sha256']!=registration_sha256 or r['compiler_sha256']!=compiler_sha256:raise ValueError('registration/compiler identity')
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',source_commit,'native'],text=True).splitlines()
    required={name for name in names if name.startswith(('native/include/','native/src/')) and PurePosixPath(name).suffix in ('.cpp','.hpp')}
    required|={'tools/experiments/mat003_touch/'+name for name in ('run.py','fixture.cpp','registration-v3.json')}
    required|={'tools/experiments/mat003_correctness/'+name for name in ('collect.py','windows_job.py')}
    if set(r['source_sha256'])!=required:raise ValueError('source inventory')
    for name,seal in r['source_sha256'].items():
        path=root/'source'/name;raw=path.read_bytes()
        if digest(path)!=seal or raw.replace(b'\r\n',b'\n')!=subprocess.check_output(['git','show',source_commit+':'+name]).replace(b'\r\n',b'\n'):raise ValueError('frozen source')
    native={name for name in required if name.startswith('native/')}
    if set(r['compiled_sha256'])!=native or r['overlay']!=spec['source_overlay']:raise ValueError('compiled inventory/overlay')
    overlay=spec['source_overlay']
    for name,seal in r['compiled_sha256'].items():
        expected=(root/'source'/name).read_bytes()
        if name==overlay['file']:
            if expected.count(overlay['old'].encode())!=overlay['required_count']:raise ValueError('overlay context')
            expected=expected.replace(overlay['old'].encode(),overlay['new'].encode())
        if (root/'compiled'/name).read_bytes()!=expected or digest(root/'compiled'/name)!=seal:raise ValueError('compiled literal overlay')
    if [(b['sanitized'],b['path']) for b in r['builds']]!=[(False,'normal.exe'),(True,'sanitized.exe')] or len(r['cases'])!=6:raise ValueError('complete build/case matrix')
    if r['sanitizer_environment']!={'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1:print_stacktrace=1'}:raise ValueError('sanitizer environment')
    slash=lambda value:str(value).replace('\\','/')
    original=slash(r['builds'][0]['receipt']['cwd']);compiler=slash(r['builds'][0]['receipt']['argv'][0]);linker=compiler.rsplit('/',1)[0]+'/ld.lld.exe'
    normal=lambda argv:[slash(value).replace(original,'$EVIDENCE') for value in argv]
    commands=[]
    for b in r['builds']:
        if digest(root/b['path'])!=b['sha256']:raise ValueError('binary seal')
        name='sanitized' if b['sanitized'] else 'normal'
        flags=spec['sanitizer_flags' if b['sanitized'] else 'normal_flags']
        expected=[compiler,*flags,'--ld-path='+linker,'-DCYBERSAND_MASS_BITS=8','-DCYBERSAND_DELAY_BITS=8','-DCYBERSAND_LITERAL_TOLERANCE=0',
                  '-I$EVIDENCE/compiled/native/include','$EVIDENCE/source/tools/experiments/mat003_touch/fixture.cpp',
                  *('$EVIDENCE/compiled/native/src/'+n for n in ('world.cpp','material_rules.cpp','scheduler_geometry.cpp','settled_world_discovery.cpp')),'-o','$EVIDENCE/'+b['path']]
        commands.append(('build-'+name,b['receipt'],expected,spec['limits']['build_timeout_seconds']))
    contexts=list(itertools.product((False,True),spec['cases']))
    for index,(row,(san,mode)) in enumerate(zip(r['cases'],contexts)):
        build=r['builds'][int(san)]
        if (row['sanitized'],row['mode'],row['binary_sha256'])!=(san,mode,build['sha256']):raise ValueError('case context/binary')
        data={key:value for key,value in row.items() if key not in ('sanitized','binary_sha256','receipt')}
        if data!=json.loads((root/f'case-{index}.stdout').read_bytes()):raise ValueError('stdout binding')
        expected=[{'completed_tick':tick,'before_support':True,'noop_hash_unchanged':True,'after_edit_support':False,
                   'restored_content_equal':True,'restored_support':False,'native_clock_unchanged':True} for tick in spec['checkpoints']]
        if data['status']!='passed' or data['timing'] is not False or data['observations']!=expected:raise ValueError('capture/noop/support observations')
        if (data['native_ticks'],data['recoveries'],data['checks'],data['configured_workers'])!=(513,9,605,4 if mode=='phased-4' else 1):raise ValueError('checkpoint/recovery coverage')
        commands.append((f'case-{index}',row['receipt'],['$EVIDENCE/'+build['path'],mode],spec['limits']['case_timeout_seconds']))
    for label,receipt,expected,timeout in commands:
        if receipt!=json.loads((root/(label+'.receipt.json')).read_bytes()) or receipt['exit_code']!=0 or receipt['stop'] or receipt['stderr_bytes'] or (root/(label+'.stderr')).stat().st_size:raise ValueError('failed command/receipt')
        if normal(receipt['argv'])!=expected or slash(receipt['cwd'])!=original:raise ValueError('ordered command binding')
        if receipt['timeout']!=timeout or receipt['elapsed_watchdog_seconds']>timeout+1 or not 0<receipt['peak_rss']<=spec['limits']['process_rss_bytes']:raise ValueError('registered resource bound')
        for stream in ('stdout','stderr'):
            if digest(root/(label+'.'+stream))!=receipt[stream+'_sha256']:raise ValueError('stream seal')
    if r['elapsed_watchdog_seconds']>spec['limits']['aggregate_seconds']:raise ValueError('aggregate watchdog')
    return {'status':'verified','builds':2,'cases':6,'observations':54,'checks':3630,'timing':False,'native_restore_qualified':False,
            'validation_class':'author-validation-pending-independent-review'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--source-commit',required=True)
    p.add_argument('--registration-sha256',required=True);p.add_argument('--compiler-sha256',required=True);a=p.parse_args()
    print(json.dumps(verify(a.evidence,a.source_commit,a.registration_sha256,a.compiler_sha256),indent=2))
