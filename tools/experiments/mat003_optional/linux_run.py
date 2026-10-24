"""Registered Linux portability collection for new untimed #204 specimens."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[3]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def collect(output):
    if platform.system()!='Linux' or platform.machine()!='x86_64':raise ValueError('registered native Linux x86-64 profile required')
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=False)
    registration=Path(__file__).with_name('linux-registration.json')
    spec=json.loads(registration.read_text())
    started=time.monotonic()
    result={'status':'failed','timing':False,'validation_class':'author-validation-pending-independent-review',
            'platform':platform.platform(),'python':sys.version,
            'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'registration_sha256':digest(registration),'commands':[],'builds':[],'cases':[]}
    env=dict(os.environ);env.update(spec['sanitizer_environment'])
    result['sanitizer_environment']=spec['sanitizer_environment']

    def command(argv,label,timeout):
        remaining=spec['limits']['aggregate_seconds']-(time.monotonic()-started)
        if remaining<=0:raise ValueError('aggregate watchdog')
        before=time.monotonic();code=None;error=None
        try:
            with (output/(label+'.stdout')).open('xb') as out,(output/(label+'.stderr')).open('xb') as err:
                code=subprocess.run(list(map(str,argv)),cwd=output,env=env,stdout=out,stderr=err,timeout=min(timeout,remaining)).returncode
        except subprocess.TimeoutExpired:
            error='watchdog'
        receipt={'argv':list(map(str,argv)),'exit_code':code,'stop':error,'timeout_seconds':timeout,
                 'elapsed_watchdog_seconds':time.monotonic()-before,
                 'stdout_sha256':digest(output/(label+'.stdout')),'stderr_sha256':digest(output/(label+'.stderr'))}
        result['commands'].append(receipt)
        (output/(label+'.receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n')
        if code!=0 or error or (output/(label+'.stderr')).stat().st_size:raise ValueError('command failed: '+label)
        if sum(p.stat().st_size for p in output.rglob('*') if p.is_file())>spec['limits']['output_bytes']:raise ValueError('output bound')
        return (output/(label+'.stdout')).read_text()

    try:
        compiler=Path(shutil.which('g++-13') or '').resolve()
        if not compiler.is_file():raise ValueError('G++13 unavailable')
        version=command([compiler,'-dumpfullversion'],'compiler-version',10).strip()
        if version!='13.3.0':raise ValueError('compiler version drift: '+version)
        linker=Path(command([compiler,'-print-prog-name=ld'],'linker-path',10).strip()).resolve()
        linker_version=command([linker,'--version'],'linker-version',10)
        if '2.42' not in linker_version.splitlines()[0]:raise ValueError('linker version drift')
        result.update(compiler=str(compiler),compiler_sha256=digest(compiler),linker=str(linker),linker_sha256=digest(linker))
        sources=[p for d in ('native/include','native/src') for p in (ROOT/d).rglob('*') if p.suffix in ('.hpp','.cpp')]
        sources += [p for d in ('tools/experiments/mat003_optional','tools/experiments/mat003_touch') for p in (ROOT/d).glob('*') if p.suffix in ('.cpp','.py','.json')]
        for p in sources:
            target=output/'source'/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
        result['source_sha256']={p.relative_to(ROOT).as_posix():digest(output/'source'/p.relative_to(ROOT)) for p in sources}
        shutil.copytree(output/'source/native',output/'compiled/native')
        touch_spec=json.loads((output/'source/tools/experiments/mat003_touch/registration-v3.json').read_text())
        overlay=touch_spec['source_overlay'];world=output/'compiled'/overlay['file'];before=world.read_bytes()
        if before.count(overlay['old'].encode())!=1:raise ValueError('overlay context drift')
        world.write_bytes(before.replace(overlay['old'].encode(),overlay['new'].encode()))
        result['compiled_sha256']={p.relative_to(output/'compiled').as_posix():digest(p) for p in (output/'compiled').rglob('*') if p.is_file()}
        for kind,bits,sanitized in [('optional',b,s) for s in (False,True) for b in (8,16)]+[('touch',0,s) for s in (False,True)]:
            label=kind+'-'+str(bits)+'-'+('sanitized' if sanitized else 'normal')
            binary=output/label;flags=spec['sanitizer_flags' if sanitized else 'normal_flags']
            args=[compiler,*flags,'-B'+str(linker.parent)+os.sep,'-fuse-ld=bfd']
            if kind=='optional':
                args += [f'-DMAT003_TAIL_BITS={bits}','-I'+str(output/'source/native/include'),output/'source/tools/experiments/mat003_optional/fixture.cpp']
            else:
                args += [*spec['touch_additional_flags'],'-I'+str(output/'compiled/native/include'),output/'source/tools/experiments/mat003_touch/fixture.cpp',
                         *(output/'compiled/native/src'/name for name in ('world.cpp','material_rules.cpp','scheduler_geometry.cpp','settled_world_discovery.cpp'))]
            command([*args,'-o',binary],'build-'+label,spec['limits']['compile_timeout_seconds'])
            result['builds'].append({'kind':kind,'bits':bits,'sanitized':sanitized,'path':binary.name,'sha256':digest(binary)})
        for build in result['builds']:
            contexts=[(side,mode) for side in (512,1024,2048) for mode in ('absent','allocated-unread','accessed-clustered','accessed-dispersed')] if build['kind']=='optional' else [('serial-1',),('phased-1',),('phased-4',)]
            for context in contexts:
                label=f"case-{len(result['cases']):03d}";print(label,build['kind'],context,flush=True)
                row=json.loads(command([output/build['path'],*context],label,spec['limits']['case_timeout_seconds']))
                if row.get('status')!='passed' or row.get('timing') is not False:raise ValueError('case failure')
                if build['kind']=='optional' and (row.get('tail_bits'),row.get('side'),row.get('mode'))!=(build['bits'],*context):raise ValueError('optional case identity')
                if build['kind']=='touch' and (row.get('mode')!=context[0] or row.get('native_ticks')!=513 or row.get('recoveries')!=9):raise ValueError('touch case identity')
                result['cases'].append({'kind':build['kind'],'sanitized':build['sanitized'],'binary_sha256':build['sha256'],'result':row})
        if len(result['cases'])!=54:raise ValueError('incomplete case matrix')
        for bits in (8,16):
            for side in (512,1024,2048):
                rows=[r['result'] for r in result['cases'] if r['kind']=='optional' and r['result']['tail_bits']==bits and r['result']['side']==side and r['result']['mode'].startswith('accessed-')]
                if len({r['operation_projection_hash'] for r in rows})!=1:raise ValueError('logical projection mismatch')
        touch=[r['result']['observations'] for r in result['cases'] if r['kind']=='touch']
        if any(row!=touch[0] for row in touch):raise ValueError('native observation mismatch')
        result['status']='passed'
    except Exception as error:
        result['error']=str(error);raise
    finally:
        result['elapsed_watchdog_seconds']=time.monotonic()-started
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        (output/'inventory.json').write_text(json.dumps({p.relative_to(output).as_posix():digest(p) for p in output.rglob('*') if p.is_file()},indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    collect(parser.parse_args().output)
