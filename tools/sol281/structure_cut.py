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
if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('action',choices=['build']);parser.add_argument('--run',required=True);args=parser.parse_args()
    assert Path(args.run).name==args.run and args.run not in ['.','..'];raise SystemExit(build(args.run))
