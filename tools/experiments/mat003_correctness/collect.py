"""Bounded future collector. Nothing runs on import; explicit admitted authority required."""
import sys
sys.dont_write_bytecode=True
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
from matrix import ARMS,cases,LIMITS
from overlay import prepare,S1,HERE

ROOT=Path(__file__).resolve().parents[3]
SEMANTIC_DEFINITIONS=['-DCYBERSAND_MASS_BITS=8','-DCYBERSAND_DELAY_BITS=8','-DCYBERSAND_LITERAL_TOLERANCE=0']
COMMON=('native/src/material_rules.cpp','native/src/scheduler_geometry.cpp','native/src/settled_world_discovery.cpp')

def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()

def dump(path,value):
    Path(path).write_text(json.dumps(value,indent=2,sort_keys=True)+'\n',encoding='utf-8')

def source_inventory(root):
    names=[]
    for directory in ('native/include','native/src','tools/experiments/mat003_prepass','tools/experiments/mat003_continuation','tools/experiments/mat003_correctness'):
        names.extend(p for p in (root/directory).rglob('*') if p.is_file() and p.suffix in ('.hpp','.h','.cpp','.inc','.py','.json','.md','.txt'))
    names.extend(root/p for p in ('third_party/native-toolchain.lock.json','docs/research/mat003-correctness-only-plan.md'))
    if any(p.is_symlink() for p in names):raise ValueError('symlink source input')
    return {p.relative_to(root).as_posix():digest(p) for p in sorted(set(names))}

def run(command,output,label,timeout,rss_limit,environment,budget_started):
    # psutil is isolated apparatus tooling, pinned and sealed in admission. No install occurs here.
    import psutil
    if psutil.__version__!='7.0.0':raise ValueError('requires independently sealed psutil7.0.0')
    stdout=output/(label+'.stdout');stderr=output/(label+'.stderr');stdout.parent.mkdir(parents=True,exist_ok=True)
    receipt=dict(argv=list(map(str,command)),cwd=str(output),timeout=timeout,exit_code=None,peak_rss=0,stop=None)
    start=time.monotonic()
    child=None;job=None
    with stdout.open('xb') as out,stderr.open('xb') as err:
        try:
            child=subprocess.Popen(receipt['argv'],cwd=output,stdout=out,stderr=err,env=environment,start_new_session=os.name!='nt',creationflags=0x00000004 if os.name=='nt' else 0)
            if os.name=='nt':
                from windows_job import WindowsJob
                job=WindowsJob(int(child._handle),rss_limit)
            proc=psutil.Process(child.pid)
            while child.poll() is None:
                family=[proc]
                try:
                    family.extend(proc.children(recursive=True))
                    resident=sum(p.memory_info().rss for p in family if p.is_running())
                except psutil.NoSuchProcess:resident=0
                except psutil.AccessDenied:
                    receipt['stop']='resource visibility denied';resident=0
                receipt['peak_rss']=max(receipt['peak_rss'],resident)
                total=sum(p.stat().st_size for p in output.rglob('*') if p.is_file())
                if time.monotonic()-start>timeout:receipt['stop']='timeout'
                if time.monotonic()-budget_started>LIMITS['platform_wall_seconds']:receipt['stop']='platform wall budget'
                if resident>rss_limit:receipt['stop']='RSS ceiling'
                if total>LIMITS['total_output_bytes']//2:receipt['stop']='platform output ceiling'
                if receipt['stop']:break
                time.sleep(.05)
        except Exception as error:
            receipt['stop']='collector/process failure: '+str(error)
        finally:
            if child is not None:
                if receipt['stop']:
                    if os.name!='nt':
                        import signal
                        try:os.killpg(child.pid,signal.SIGKILL)
                        except ProcessLookupError:pass
                    else:
                        if job:job.close()
                        try:child.kill()
                        except OSError:pass
                receipt['exit_code']=child.wait()
            else:receipt['exit_code']=-1
            if job:job.close()
    receipt['elapsed_watchdog_seconds']=time.monotonic()-start
    receipt['stderr_bytes']=stderr.stat().st_size
    receipt['stdout_sha256']=digest(stdout);receipt['stderr_sha256']=digest(stderr)
    dump(output/(label+'.receipt.json'),receipt)
    if receipt['stop'] or receipt['exit_code']!=0 or receipt['stderr_bytes']:
        raise ValueError('retained failed invocation: '+label)
    return receipt

def authority_input(path,seal):
    if len(seal)!=64 or digest(path)!=seal:raise ValueError('external authority seal mismatch')
    a=json.loads(Path(path).read_text(encoding='utf-8'))
    required=('source_commit','source_tree','owner_authority_reference','independent_review_reference','compiler','compiler_sha256','linker','linker_sha256','platform_identity','source_sha256','normal_flags','sanitizer_flags','psutil_source_sha256','sanitizer_preflight_reference','toolchain_proof_file','toolchain_proof_sha256','sanitizer_environment','linker_selection_flags')
    if any(not a.get(k) for k in required):raise ValueError('incomplete frozen platform inputs')
    if a['platform_identity']!=dict(system=platform.system(),machine=platform.machine(),release=platform.release(),version=platform.version(),python=platform.python_version(),python_executable_sha256=digest(sys.executable)):raise ValueError('platform identity drift')
    compiler,linker=Path(a['compiler']).resolve(),Path(a['linker']).resolve()
    if digest(compiler)!=a['compiler_sha256'] or digest(linker)!=a['linker_sha256']:raise ValueError('tool binary drift')
    proof=Path(a['toolchain_proof_file'])
    if digest(proof)!=a['toolchain_proof_sha256']:raise ValueError('toolchain preflight seal mismatch')
    p=json.loads(proof.read_text(encoding='utf-8'))
    if p.get('status')!='independently-qualified-toolchain-resolution' or p.get('compiler_sha256')!=a['compiler_sha256'] or p.get('resolved_linker_sha256')!=a['linker_sha256'] or p.get('resolved_linker')!=str(linker) or p.get('selection_flags')!=a['linker_selection_flags'] or not p.get('driver_resolution_trace') or not p.get('input_files'):raise ValueError('missing exact linker/search/input qualification')
    for name,value in p['input_files'].items():
        if digest(name)!=value:raise ValueError('toolchain input drift: '+name)
    if os.name=='nt':
        if a['linker_selection_flags']!=['--ld-path='+str(linker)]:raise ValueError('Windows requires preflight-qualified absolute linker selection')
    else:
        if a['linker_selection_flags']!=['-B'+str(linker.parent)+os.sep,'-fuse-ld=bfd']:raise ValueError('Linux requires preflight-qualified pinned bfd search')
    import psutil
    if psutil.__version__!='7.0.0':raise ValueError('monitor version drift')
    pkg=Path(psutil.__file__).parent
    actual={p.relative_to(pkg).as_posix():digest(p) for p in pkg.rglob('*') if p.is_file() and p.suffix in ('.py','.so','.pyd')}
    if actual!=a['psutil_source_sha256']:raise ValueError('monitor source drift')
    if 'halt_on_error=1' not in a['sanitizer_environment'].get('ASAN_OPTIONS','') or 'halt_on_error=1' not in a['sanitizer_environment'].get('UBSAN_OPTIONS',''):raise ValueError('sanitizers not fail-fast')
    return a,compiler,linker,pkg

def inventory(output,name):
    dump(output/name,{p.relative_to(output).as_posix():digest(p) for p in sorted(output.rglob('*')) if p.is_file() and p.relative_to(output).as_posix()!=name})

def build(authority_path,output,seal):
    a,compiler,linker,pkg=authority_input(authority_path,seal)
    if a.get('owner_build_authorized') is not True:raise ValueError('HELD: separate build authority required')
    if subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()!=a['source_commit'] or subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=ROOT,text=True).strip()!=a['source_tree']:raise ValueError('source Git identity drift')
    if source_inventory(ROOT)!=a['source_sha256']:raise ValueError('source does not match reviewed inventory')
    output=Path(output).resolve()
    if output.exists() or ROOT==output or ROOT in output.parents:raise ValueError('append-only evidence must be new and outside source tree')
    output.mkdir(parents=True);source=output/'source';started=time.monotonic()
    report=dict(status='incomplete',source_commit=a['source_commit'],source_tree=a['source_tree'],build_authority_sha256=seal,evidence_root=str(output),cases=cases(),builds=[],generated={},timing=False)
    shutil.copyfile(authority_path,output/'build-authority.json')
    shutil.copyfile(a['toolchain_proof_file'],output/'toolchain-proof.json')
    try:
        tools=output/'tools';tools.mkdir();shutil.copyfile(compiler,tools/'compiler.bin');shutil.copyfile(linker,tools/'linker.bin')
        for name in a['psutil_source_sha256']:
            target=output/'monitor'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(pkg/name,target)
        for name in a['source_sha256']:
            target=source/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        if source_inventory(source)!=a['source_sha256']:raise ValueError('snapshot readback drift')
        for arm in ARMS:
            cap=int(arm.split('-')[0][1:]);bits=int(arm.split('E')[1]);work=output/'generated'/arm
            overlay=prepare(source,work,arm)
            before={p.relative_to(work).as_posix():digest(p) for p in work.rglob('*') if p.is_file()}
            report['generated'][arm]=before
            dump(output/('generated-'+arm+'-precompile.json'),before)
            definitions=[f'-DMAT003_CAPACITY={cap}',f'-DMAT003_EPOCH_BITS={bits}']
            for sanitized in (False,True):
                flags=a['sanitizer_flags' if sanitized else 'normal_flags']
                for kind in ('storage','world'):
                    binary=output/'binaries'/f'{arm}-{int(sanitized)}-{kind}';binary.parent.mkdir(exist_ok=True)
                    if os.name=='nt':binary=binary.with_suffix('.exe')
                    if kind=='storage':command=[str(compiler),*flags,*SEMANTIC_DEFINITIONS,*a['linker_selection_flags'],*definitions,'-I'+str(source/HERE),str(source/HERE/'storage.cpp'),'-o',str(binary)]
                    else:command=[str(compiler),*flags,*SEMANTIC_DEFINITIONS,*a['linker_selection_flags'],*overlay['compile_definitions'],'-I'+str(work/S1),'-I'+str(work/'native/include'),'-I'+str(work/'native/src'),str(work/S1/'reviewed_world.cpp'),*(str(work/p) for p in COMMON),'-o',str(binary)]
                    if os.name=='nt':command+=['-lpsapi']
                    receipt=run(command,output,f'builds/{arm}-{int(sanitized)}-{kind}',180,3*1024**3,os.environ.copy(),started)
                    report['builds'].append(dict(arm=arm,sanitized=sanitized,kind=kind,path=binary.relative_to(output).as_posix(),sha256=digest(binary),receipt=receipt))
                    if len(report['builds'])>32:raise ValueError('compile budget exceeded')
            if before!={p.relative_to(work).as_posix():digest(p) for p in work.rglob('*') if p.is_file()}:raise ValueError('generated sources changed during build')
        if len(report['builds'])!=32:raise ValueError('partial build matrix')
        report['status']='built-execution-held'
    except Exception as exc:
        report['error']=str(exc);raise
    finally:
        report['build_watchdog_seconds']=time.monotonic()-started
        dump(output/'built.json',report);inventory(output,'build-inventory.json')

def execute(authority_path,output,seal,binary_admission_path):
    a,compiler,linker,pkg=authority_input(authority_path,seal)
    if a.get('owner_execution_authorized') is not True or a.get('independent_admission')!='admitted':raise ValueError('HELD: owner and independent binary admission required')
    output=Path(output).resolve()
    if (output/'execution-attempt.json').exists() or (output/'cases').exists():raise ValueError('prior attempt retained; never retry observations')
    built=json.loads((output/'built.json').read_text(encoding='utf-8'));initial=json.loads((output/'build-authority.json').read_text(encoding='utf-8'))
    if built.get('status')!='built-execution-held' or built.get('cases')!=cases() or len(built.get('builds',[]))!=32:raise ValueError('incomplete build checkpoint')
    if digest(output/'build-authority.json')!=a.get('build_authority_sha256'):raise ValueError('build authority mismatch')
    fixed=('source_commit','source_tree','source_sha256','compiler_sha256','linker_sha256','psutil_source_sha256','normal_flags','sanitizer_flags','platform_identity','sanitizer_environment','linker_selection_flags','toolchain_proof_sha256')
    if any(a[k]!=initial[k] for k in fixed):raise ValueError('execution changes frozen build inputs')
    from readback import sealed_inventory
    sealed_inventory(output,json.loads((output/'build-inventory.json').read_text(encoding='utf-8')),excluded='build-inventory.json')
    if digest(binary_admission_path)!=a.get('binary_admission_sha256'):raise ValueError('external binary admission seal mismatch')
    admitted=json.loads(Path(binary_admission_path).read_text(encoding='utf-8'))
    binary_seals={b['path']:digest(output/b['path']) for b in built['builds']}
    if admitted.get('built_sha256')!=digest(output/'built.json') or admitted.get('binary_sha256')!=binary_seals or admitted.get('generated_sha256')!=built['generated'] or admitted.get('independent_admission')!='admitted' or not admitted.get('independent_review_reference'):raise ValueError('binaries/generated sources not independently admitted')
    for arm,files in built['generated'].items():
        if files!={p.relative_to(output/'generated'/arm).as_posix():digest(p) for p in (output/'generated'/arm).rglob('*') if p.is_file()}:raise ValueError('pre-execution generated seal mismatch')
    for b in built['builds']:
        if digest(output/b['path'])!=b['sha256']:raise ValueError('pre-execution binary seal mismatch')
    # Exclusive attempt marker is written only after admission readback, before the first process.
    with (output/'execution-attempt.json').open('x',encoding='utf-8') as f:json.dump(dict(authority_sha256=seal,binary_admission_sha256=a['binary_admission_sha256']),f)
    shutil.copyfile(authority_path,output/'authority.json');shutil.copyfile(binary_admission_path,output/'binary-admission.json')
    report=dict(built,authority_sha256=seal,authority=a,results=[],qualification_admitted=True,status='incomplete')
    started=time.monotonic()-built['build_watchdog_seconds']
    binaries={(b['arm'],b['sanitized'],b['kind']):output/b['path'] for b in built['builds']}
    try:
        for case in cases():
            directory=output/'cases'/case['id'];directory.mkdir(parents=True)
            kind='storage' if case['suite']=='storage' else 'world';binary=binaries[case['arm'],case['sanitized'],kind]
            command=[str(binary),'--correctness-only'] if kind=='storage' else [str(binary),case['suite'],str(case.get('side',256)),str(case.get('workers',1)),case.get('backend','serial'),case.get('scene','ordinary'),str(directory/'world')]
            environment=os.environ.copy();environment.update(a['sanitizer_environment']);environment['MAT003_RESOURCE_RECEIPT']=str(directory/'peak-rss.txt')
            receipt=run(command,output,'cases/'+case['id']+'/process',case['timeout'],LIMITS['sanitized_rss_bytes' if case['sanitized'] else 'normal_rss_bytes'],environment,started)
            peak=int((directory/'peak-rss.txt').read_text());limit=LIMITS['sanitized_rss_bytes' if case['sanitized'] else 'normal_rss_bytes']
            if not 0<peak<=limit:raise ValueError('native peak RSS breach/missing receipt')
            report['results'].append(dict(case=case['id'],binary_sha256=digest(binary),receipt=receipt,peak_rss=peak))
            dump(output/'progress.json',report)
        if len(report['results'])!=152:raise ValueError('partial matrix')
        report['status']='collected-not-verified'
    except Exception as exc:
        report['error']=str(exc);raise
    finally:
        report['wall_watchdog_seconds']=time.monotonic()-started
        dump(output/'result.json',report);inventory(output,'inventory.json')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--stage',choices=['build','execute'],required=True);parser.add_argument('--authority',type=Path,required=True);parser.add_argument('--authorized-authority-sha256',required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--binary-admission',type=Path)
    args=parser.parse_args()
    if args.stage=='build':build(args.authority,args.output,args.authorized_authority_sha256)
    elif args.binary_admission is None:parser.error('execute requires separately admitted binary seal')
    else:execute(args.authority,args.output,args.authorized_authority_sha256,args.binary_admission)
