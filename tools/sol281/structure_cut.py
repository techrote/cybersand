#!/usr/bin/env python3
"""Source-local structural SOL baseline; actual Windows and WSL Linux."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import qualify_facade_refusal as facade

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/sol-structure-cut'
BASE='e4c2649e82d943554f4dc6a0634336770cda08f6'
ENGINES={'windows':'C:/Godot47/Godot_v4.7-stable_win64_console.exe','linux':'/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64'}
BINARIES={'windows':'cybersand_native.windows.x86_64.dll','linux':'libcybersand_native.linux.x86_64.so'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def lfsha(p):return hashlib.sha256(Path(p).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args])
def wsl(p):
    s=str(p).replace('\\','/');return '/mnt/'+s[0].lower()+s[2:]
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(v,indent=2)+'\n').encode())
def command(name,argv,folder,env=None,timeout=300):
    log=folder/(name+'.log');assert not log.exists();folder.mkdir(parents=True,exist_ok=True)
    args=list(map(str,argv))
    if Path(args[0]).name.lower()=='wsl.exe':i=args.index('--')+1;args[i:i]=['timeout','--signal=TERM','--kill-after=5s',str(timeout)+'s']
    start=time.monotonic()
    with log.open('wb') as f:
        process=subprocess.Popen(args,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT)
        try:code=process.wait(timeout=timeout+10)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=f,stderr=subprocess.STDOUT,timeout=10);process.wait(timeout=10);code=124
    text=log.read_text(encoding='utf-8',errors='replace')
    row=dict(name=name,command=args,exit=code,seconds=time.monotonic()-start,timeout_seconds=timeout,log=str(log.relative_to(ROOT)),log_sha256=sha(log),
        clean=code==0 and not any(x in text for x in ['SCRIPT ERROR:','ERROR:','ObjectDB instances leaked','resources still in use','runtime error:','AddressSanitizer:']))
    write(folder/(name+'.receipt.json'),row);print(name,code,row['clean'],flush=True);return row
def identity():
    assert not git('status','--porcelain'),'Commit source before execution'
    subprocess.run(['git','-C',str(ROOT),'merge-base','--is-ancestor',BASE,'HEAD'],check=True)
    head=git('rev-parse','HEAD').decode().strip();snap=facade.snapshot(ROOT,head)
    profile='native/tests/fixtures/sol_structure_cut_001.json'
    assert (ROOT/profile).read_bytes()==git('show','97e6a85e:'+profile)
    # Every original material/physics source remains exactly the chosen SOL source.
    protected=['tools/material_catalogue/compatibility.py','materials/catalogue/compatibility-lock.json']
    material=json.loads((ROOT/protected[1]).read_text(encoding='utf-8'))
    protected+= [r['path'] for r in material['source_locks']]
    for name in protected:assert (ROOT/name).read_bytes()==git('show',BASE+':'+name),name
    return dict(**snap,base=BASE,registration_sha256=sha(ROOT/profile),material_inputs={n:sha(ROOT/n) for n in sorted(set(protected))},runner_sha256=sha(__file__))
def build(run):
    info=identity();folder=OUT/run;assert not folder.exists();folder.mkdir(parents=True)
    receipt=dict(identity=info,platforms={});write(folder/'receipt.json',receipt)
    def host(platform):
        target=folder/platform;target.mkdir();rows=[]
        def execute(name,argv,env=None,timeout=900):
            row=command(name,argv,target,env,timeout);rows.append(row);return row
        if platform=='windows':
            sdk=Path('C:/Users/_/lcb-local-toolchain/env/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496')
            compiler=Path('C:/Users/_/lcb-local-toolchain/llvm-mingw-20260826/bin/x86_64-w64-mingw32-g++.exe')
            deps=[sys.executable,'tools/sol281/structure_dependencies.py',str(sdk),str(compiler),str(compiler)]
            env=dict(os.environ,GODOT_CPP_ROOT=sdk.as_posix(),GODOT_CPP_LIBRARY=(sdk/'bin/libgodot-cpp.windows.template_debug.x86_64.a').as_posix(),WINDOWS_CXX=compiler.as_posix(),
                CYBERSAND_ALLOW_TOOLCHAIN_DRIFT='0',CYBERSAND_VERIFY_M11_OUTPUT='0',CYBERSAND_DRY_RUN='0',CYBERSAND_NATIVE_OUTPUT=(target/BINARIES[platform]).as_posix(),PATH='C:/Users/_/lcb-local-toolchain/shims;'+os.environ['PATH'])
            argv=['C:/Program Files/Git/bin/bash.exe','tools/build_native_extension_windows.sh']
        else:
            sdk='/home/i/render-publication-abc-tools/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496'
            wrapper=target/'g++';wrapper.write_bytes((ROOT/'tools/toolchains/g++').read_bytes().replace(b'\r\n',b'\n'))
            linux=['wsl.exe','-d','Ubuntu-24.04','--cd',wsl(ROOT),'--'];execute('wrapper-mode',linux+['chmod','+x',wsl(wrapper)])
            deps=linux+['python3','tools/sol281/structure_dependencies.py',sdk,'/usr/bin/g++',wsl(wrapper)]
            env=None;argv=linux+['env','GODOT_CPP_ROOT='+sdk,'GODOT_CPP_LIBRARY='+sdk+'/bin/libgodot-cpp.linux.template_debug.x86_64.a','LINUX_CXX='+wsl(wrapper),'CYBERSAND_REAL_CXX=/usr/bin/g++',
                'CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=0','CYBERSAND_VERIFY_M11_OUTPUT=0','CYBERSAND_DRY_RUN=0','CYBERSAND_NATIVE_OUTPUT='+wsl(target/BINARIES[platform]),'bash','tools/build_native_extension.sh']
        before=execute('dependencies-before',deps);assert before['clean']
        compiled=execute('build',argv,env);after=execute('dependencies-after',deps);assert after['clean']
        assert (ROOT/before['log']).read_bytes()==(ROOT/after['log']).read_bytes(),'Dependency change'
        binary=target/BINARIES[platform]
        return dict(commands=rows,clean=compiled['clean'],dependency_equality=True,dependency_receipt=before,output=str(binary.relative_to(ROOT)),sha256=sha(binary) if binary.is_file() else None)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for platform,row in zip(BINARIES,pool.map(host,BINARIES)):receipt['platforms'][platform]=row;write(folder/'receipt.json',receipt)
    assert info==identity();receipt['post_source_equality']=True;write(folder/'receipt.json',receipt)
    return int(not all(r['clean'] for r in receipt['platforms'].values()))
def hosts(args):
    info=identity();build_receipt=json.loads((OUT/'runtimes-001/receipt.json').read_text(encoding='utf-8'))
    assert build_receipt['post_source_equality'] and info['source_inputs']==build_receipt['identity']['source_inputs']
    assert info['material_inputs']==build_receipt['identity']['material_inputs']
    folder=OUT/args.run;assert not folder.exists();folder.mkdir(parents=True)
    copied={n:sha(ROOT/n) for n in git('ls-files','godot').decode().splitlines() if (ROOT/n).is_file()}
    receipt=dict(identity=info,build_receipt_sha256=sha(OUT/'runtimes-001/receipt.json'),matrix=vars(args),hosts={},copied_inputs=copied,
        qualification='Actual source-local SOL, not Workbench; sequential full-observer diagnostics, no originalCPU or MAT integration pass.')
    def save():write(folder/'receipt.json',receipt)
    save()
    for platform in args.platforms.split(','):
        assert platform in BINARIES
        host=folder/platform;project=host/'godot';host.mkdir();rows=[]
        for name in copied:
            dst=project/Path(name).relative_to('godot');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,dst)
        native=build_receipt['platforms'][platform];assert native['clean'] and sha(ROOT/native['output'])==native['sha256']
        shutil.copyfile(ROOT/native['output'],project/'addons/cybersand_native/bin'/BINARIES[platform])
        rapier=json.loads((ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_text(encoding='utf-8'))
        assert sha(ROOT/rapier['artifact'])==rapier['sha256']
        for name,digest in rapier['source_inputs'].items():assert lfsha(ROOT/name)==digest,name
        inventory={p.relative_to(project).as_posix():sha(p) for p in project.rglob('*') if p.is_file()}
        state=dict(commands=rows,effective_inputs=inventory,compiled_native=native,rapier=rapier);receipt['hosts'][platform]=state;save()
        def run(name,script=None,extra=None,env=None,version=False):
            forwarded=dict(CYBERSAND_SOURCE_REVISION=info['source_commit'],**(env or {}));argv=[ENGINES[platform]]
            if version:argv+=['--version']
            else:
                argv+=['--headless','--audio-driver','Dummy','--path',str(project) if platform=='windows' else wsl(project)]
                argv+=['--editor','--import','--quit'] if script is None else ['--max-fps','120','--script','res://tests/'+script+'.gd',*(extra or [])]
            if platform=='linux':argv=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in forwarded.items()],*argv]
            row=command(name,argv,host,dict(os.environ,**forwarded),timeout=300);rows.append(row);save();return row
        version=run('version',version=True);assert version['clean']
        native_manifest=json.loads((ROOT/('godot/addons/cybersand_native/runtime-provenance'+('.linux' if platform=='linux' else '')+'.json')).read_text(encoding='utf-8'))
        assert (ROOT/version['log']).read_text(encoding='utf-8').strip()==native_manifest['godot_version']
        if platform=='windows':
            engine=sha(ENGINES[platform].replace('_console.exe','.exe'));launcher=sha(ENGINES[platform])
            assert launcher==native_manifest['godot_validation_executable_sha256']
        else:
            row=command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',ENGINES[platform]],host);rows.append(row);assert row['clean']
            engine=(ROOT/row['log']).read_text(encoding='utf-8').split()[0];launcher=engine
        assert engine==native_manifest['godot_executable_sha256'];state['engine']=dict(sha256=engine,launcher_sha256=launcher,version=native_manifest['godot_version']);save()
        imported=run('import')
        if imported['clean']:
            for worker in map(int,args.workers.split(',')):
                assert worker in [1,4]
                if args.suite=='original':
                    output=host/('original-w'+str(worker)+'.json');path=str(output) if platform=='windows' else wsl(output)
                    row=run('original-w'+str(worker),'test_solid_detachment',['--',path,'--workers='+str(worker)])
                    if output.exists():row['report']=dict(path=str(output.relative_to(ROOT)),sha256=sha(output));save()
                    continue
                structures=['tree'] if args.suite=='smoke' else ['tree','building']
                for structure in structures:
                    for enabled in ([False,True] if args.suite=='packed' else [False]):
                        surroundings='packed_sand' if args.suite=='packed' else 'empty'
                        name=structure+'-'+surroundings+'-response'+str(int(enabled))+'-w'+str(worker)
                        output=host/(name+'.json');path=str(output) if platform=='windows' else wsl(output)
                        row=run(name,'test_sol_structure_cut',env=dict(SOL_STRUCTURE=structure,SOL_SURROUNDINGS=surroundings,SOL_SAND_RESPONSE=str(int(enabled)),SOL_WORKERS=str(worker),SOL_OUTPUT=path))
                        if output.exists():
                            row['report']=dict(path=str(output.relative_to(ROOT)),sha256=sha(output),bytes=output.stat().st_size)
                            data=json.loads(output.read_text(encoding='utf-8'));row['report_complete']=not data['failures'] and len(data['steps'])==(360 if args.suite=='packed' else 720)
                        save()
        changes=[];normalized=[]
        for name,digest in inventory.items():
            p=project/name
            if p.is_file() and sha(p)==digest:continue
            original=ROOT/'godot'/name
            if name.endswith('.import') and original.is_file() and p.is_file() and p.read_bytes().replace(b'\r\n',b'\n')==original.read_bytes().replace(b'\r\n',b'\n'):normalized.append(name)
            else:changes.append(name)
        state['post_inventory']=dict(unexpected_changes=changes,import_LF_normalization_only=normalized);save();assert not changes
    assert info==identity() and copied=={n:sha(ROOT/n) for n in copied}
    receipt['post_source_equality']=True;save()
    return int(not all(c['clean'] and c.get('report_complete',True) for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('action',choices=['build','hosts']);parser.add_argument('--run',required=True)
    parser.add_argument('--suite',choices=['original','smoke','dry','packed'],default='original');parser.add_argument('--platforms',default='windows,linux');parser.add_argument('--workers',default='1,4');args=parser.parse_args()
    assert Path(args.run).name==args.run and args.run not in ['.','..'];raise SystemExit(build(args.run) if args.action=='build' else hosts(args))
