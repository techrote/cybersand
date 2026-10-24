"""Collect the registered Current-World capture-touch counterexample without timing."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/experiments/mat003_correctness'))
from collect import digest, run


def collect(compiler, output, expected_compiler):
    compiler=Path(compiler).resolve();output=Path(output).resolve()
    if digest(compiler)!=expected_compiler:raise ValueError('compiler seal mismatch')
    output.mkdir(parents=True,exist_ok=False)
    registration=Path(__file__).with_name('registration-v3.json')
    spec=json.loads(registration.read_text())
    started=time.monotonic()
    result=dict(status='failed',timing=False,validation_class='author-validation-pending-independent-review',
                source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                registration_sha256=digest(registration),compiler_sha256=expected_compiler,builds=[],cases=[])
    env=dict(os.environ)
    env['PATH']=str(compiler.parent)+os.pathsep+env.get('PATH','')
    env['ASAN_OPTIONS']='detect_leaks=0:halt_on_error=1'
    env['UBSAN_OPTIONS']='halt_on_error=1:print_stacktrace=1'
    result['sanitizer_environment']={k:env[k] for k in ('ASAN_OPTIONS','UBSAN_OPTIONS')}
    try:
        sources=[p for d in ('native/include','native/src') for p in (ROOT/d).rglob('*') if p.suffix in ('.hpp','.cpp')]
        sources += [Path(__file__),Path(__file__).with_name('fixture.cpp'),registration,
                    ROOT/'tools/experiments/mat003_correctness/collect.py',ROOT/'tools/experiments/mat003_correctness/windows_job.py']
        for p in sources:
            target=output/'source'/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
        result['source_sha256']={p.relative_to(ROOT).as_posix():digest(output/'source'/p.relative_to(ROOT)) for p in sources}
        shutil.copytree(output/'source/native',output/'compiled/native')
        overlay=spec['source_overlay'];target=output/'compiled'/overlay['file']
        before=target.read_bytes();old=overlay['old'].encode();new=overlay['new'].encode()
        if before.count(old)!=overlay['required_count']:raise ValueError('unused-capture overlay context drift')
        target.write_bytes(before.replace(old,new))
        result['compiled_sha256']={p.relative_to(output/'compiled').as_posix():digest(p) for p in (output/'compiled').rglob('*') if p.is_file()}
        result['overlay']=overlay
        linker=compiler.with_name('ld.lld.exe' if os.name=='nt' else 'ld.lld')
        result['linker_sha256']=digest(linker)
        for sanitized in (False,True):
            name='sanitized' if sanitized else 'normal'
            binary=output/(name+('.exe' if os.name=='nt' else ''))
            flags=spec['sanitizer_flags' if sanitized else 'normal_flags']
            args=[compiler,*flags,'--ld-path='+str(linker),'-DCYBERSAND_MASS_BITS=8','-DCYBERSAND_DELAY_BITS=8','-DCYBERSAND_LITERAL_TOLERANCE=0',
                  '-I'+str(output/'compiled/native/include'),output/'source/tools/experiments/mat003_touch/fixture.cpp',
                  *(output/'compiled/native/src'/n for n in ('world.cpp','material_rules.cpp','scheduler_geometry.cpp','settled_world_discovery.cpp')),
                  '-o',binary]
            receipt=run(args,output,'build-'+name,spec['limits']['build_timeout_seconds'],spec['limits']['process_rss_bytes'],env,started)
            result['builds'].append(dict(sanitized=sanitized,path=binary.name,sha256=digest(binary),receipt=receipt))
        for build in result['builds']:
            for mode in spec['cases']:
                remaining=spec['limits']['aggregate_seconds']-(time.monotonic()-started)
                if remaining<=0:raise ValueError('aggregate watchdog')
                label='case-'+str(len(result['cases']))
                receipt=run([output/build['path'],mode],output,label,min(spec['limits']['case_timeout_seconds'],remaining),spec['limits']['process_rss_bytes'],env,started)
                row=json.loads((output/(label+'.stdout')).read_text())
                if row.get('status')!='passed' or row.get('timing') is not False or row.get('mode')!=mode:
                    raise ValueError('case identity')
                if row['native_ticks']!=513 or row['recoveries']!=9 or [v['completed_tick'] for v in row['observations']]!=spec['checkpoints']:
                    raise ValueError('checkpoint/recovery coverage')
                row['sanitized']=build['sanitized'];row['binary_sha256']=build['sha256'];row['receipt']=receipt
                result['cases'].append(row)
        if len(result['cases'])!=6:raise ValueError('incomplete registered matrix')
        result['status']='passed'
    except Exception as error:
        result['error']=str(error)
        raise
    finally:
        result['elapsed_watchdog_seconds']=time.monotonic()-started
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        (output/'inventory.json').write_text(json.dumps({p.relative_to(output).as_posix():digest(p) for p in output.rglob('*') if p.is_file()},indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler',type=Path,required=True)
    parser.add_argument('--expected-compiler-sha256',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    collect(args.compiler,args.output,args.expected_compiler_sha256)
