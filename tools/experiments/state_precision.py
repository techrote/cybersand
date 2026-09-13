"""Issue17 sequential, source-frozen experiment driver; retains every attempt."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'validation/local/issue-17'
BUILD=ROOT/'build/issue-17'
CORE=[f'native/src/{n}.cpp' for n in ('world','material_rules','scheduler_geometry','render_snapshot','c_api')]
ARMS={'m4':(4,0,8),'m6':(6,0,8),'m8':(8,0,8),'m10':(10,0,8),
      'l4':(4,1,8),'l6':(6,1,8),'l10':(10,1,8),'d4':(8,0,4)}
FIXTURES=['basin48','basin96','film','support','ledge','coherent','low','delay']
POSITIONS=[(0,0),(-129,0),(127,1),(-257,1),(65,0)]
def digest(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n')
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def environment():
    spec=importlib.util.spec_from_file_location('dev',Path('C:/kybersand/tools/dev.py'))
    dev=importlib.util.module_from_spec(spec);spec.loader.exec_module(dev)
    return dev.ENV,dev.LLVM/'bin/clang++.exe'
def identity():
    files=sorted([*ROOT.glob('native/src/*'),*ROOT.glob('native/include/cybersand/*'),
                  ROOT/'native/bench/state_precision.cpp',ROOT/'native/tests/test_state_precision.cpp',
                  Path(__file__),ROOT/'docs/operations/state-precision-experiment.md'])
    return {'head':git('rev-parse','HEAD'),'status':git('status','--short'),
            'files':{str(p.relative_to(ROOT)):digest(p) for p in files if p.is_file()}}
def execute(name,cmd,out,env,timeout=1800):
    path=out/(name+'.jsonl');meta={'command':list(map(str,cmd)),'cwd':str(ROOT),'timeout':timeout,'started':time.time()}
    if path.exists():raise RuntimeError(f'refuse overwrite {path}')
    with path.open('w') as f:
        try:r=subprocess.run(meta['command'],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=timeout);meta['exit']=r.returncode
        except subprocess.TimeoutExpired:meta['exit']=124
    meta['seconds']=time.time()-meta['started'];meta['sha256']=digest(path)
    write(out/(name+'.execution.json'),meta)
    if meta['exit']:raise RuntimeError(f'{name} failed; retained {path}')
    return path
def prepare():
    env,cxx=environment();out=OUT/('prepare-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir(parents=True)
    build=BUILD/out.name;build.mkdir(parents=True)
    write(out/'source.json',identity());execute('compiler',[cxx,'--version'],out,env)
    flags=[cxx,'-std=c++20','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wshadow','-pthread','-static','-Inative/include']
    artifacts={}
    for arm,(mass,literal,delay) in ARMS.items():
        defines=[f'-DCYBERSAND_MASS_BITS={mass}',f'-DCYBERSAND_LITERAL_TOLERANCE={literal}',f'-DCYBERSAND_DELAY_BITS={delay}']
        exe=build/(arm+'.exe');tests=build/(arm+'-tests.exe')
        print('build',arm,flush=True)
        execute('build-'+arm,[*flags,'-O3','-DNDEBUG','-flto',*defines,*CORE,'native/bench/state_precision.cpp','-o',exe],out,env,1200)
        execute('build-tests-'+arm,[*flags,'-O0','-g3',*defines,*CORE,'native/tests/test_state_precision.cpp','-o',tests],out,env,1200)
        execute('tests-'+arm,[tests],out,env)
        artifacts[arm]={'exe':str(exe),'sha256':digest(exe),'tests':digest(tests)}
    # Truly unmodified baseline source in isolated build input directory; no checkout writes.
    base=build/'baseline';base.mkdir()
    for path in git('ls-files','native').splitlines():
        if path.startswith(('native/src/','native/include/')):
            p=base/path;p.parent.mkdir(parents=True,exist_ok=True)
            p.write_bytes(subprocess.check_output(['git','show','f3fb9de:'+path],cwd=ROOT))
    baseline_flags=[str(cxx),'-std=c++20','-pthread','-static','-I'+str(base/'native/include')]
    exe=build/'baseline.exe'
    execute('build-baseline',[*baseline_flags,'-O3','-DNDEBUG','-flto','-DPRECISION_BASELINE',*[base/p for p in CORE],ROOT/'native/bench/state_precision.cpp','-o',exe],out,env,1200)
    artifacts['baseline']={'exe':str(exe),'sha256':digest(exe)}
    for arm,core,inc in [('baseline',[base/p for p in CORE],base/'native/include'),('m8',CORE,ROOT/'native/include')]:
        exe=build/(arm+'-full-tests.exe')
        execute('build-full-'+arm,[cxx,'-std=c++20','-pthread','-static','-O0','-g3','-I'+str(inc),*core,'native/tests/test_world.cpp','-o',exe],out,env,1200)
        execute('full-tests-'+arm,[exe],out,env)
    execute('c-header',[cxx.parent/'clang.exe','-std=c11','-Inative/include','-fsyntax-only','native/tests/test_c_header.c'],out,env,120)
    manifest={'source':identity(),'artifacts':artifacts,'compiler':{'path':str(cxx),'sha256':digest(cxx)},'out':str(out)}
    write(out/'prepared.json',manifest);print(out/'prepared.json',flush=True)
def load(manifest):
    m=json.loads(Path(manifest).read_text())
    if m['source']['files']!=identity()['files']:raise RuntimeError('source changed since build')
    for a in m['artifacts'].values():
        if digest(a['exe'])!=a['sha256']:raise RuntimeError('binary changed')
    return m
def command(m,arm,fixture,shift,mirror,workers,observe,mode,horizon):
    return [m['artifacts'][arm]['exe'],fixture,shift,mirror,workers,observe,mode,horizon]
def semantic_rows(path):
    rows=[json.loads(line) for line in path.read_text().splitlines()]
    return [{k:v for k,v in r.items() if k not in ('events','startup_us','resident_bytes')} for r in rows]
def behavior(manifest):
    m=load(manifest);env,_=environment();out=OUT/('behavior-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir()
    write(out/'manifest.json',m);runs=[]
    # Baseline equivalence is a gate before all candidate behavior measurements.
    for fixture in FIXTURES:
        for workers in (1,4):
            ref=None
            for arm,observer in [('baseline',0),('m8',0),('m8',1)]:
                name=f'control-{fixture}-{workers}-{arm}-{observer}'
                p=execute(name,command(m,arm,fixture,0,0,workers,observer,'behavior',1800),out,env)
                rows=semantic_rows(p)
                if ref is None:ref=rows
                elif rows!=ref:raise RuntimeError(f'control equivalence {name}')
                runs.append({'name':name,'sha256':digest(p)})
        print('control',fixture,flush=True)
    for arm in ARMS:
        for fixture in FIXTURES:
            for index,(shift,mirror) in enumerate(POSITIONS):
                ref=None
                for workers in (1,4):
                    for repeat in (0,1):
                        name=f'{arm}-{fixture}-{index}-{workers}-{repeat}'
                        p=execute(name,command(m,arm,fixture,shift,mirror,workers,1,'behavior',1800),out,env)
                        rows=semantic_rows(p)
                        if ref is None:ref=rows
                        elif rows!=ref:raise RuntimeError(f'worker/repeat mismatch {name}')
                        runs.append({'name':name,'arm':arm,'fixture':fixture,'position':index,'workers':workers,'repeat':repeat,'sha256':digest(p)})
            print(arm,fixture,flush=True)
    write(out/'completed.json',{'manifest':m,'runs':runs});print(out/'completed.json',flush=True)
def plan():
    pairs=[]
    for candidate in ['m4','m6','m10']:
        for fixture in ['basin48','basin96','ledge']:
            for workers in (1,4):pairs.append(('mass',candidate,fixture,workers,('m8',0),(candidate,0)))
    for workers in (1,4):pairs.append(('delay','d4','coherent',workers,('m8',0),('d4',0)))
    for candidate in ['m4','m6','m8','m10']:
        for workers in (1,4):pairs.append(('observer',candidate,'basin96',workers,(candidate,0),(candidate,1)))
    return pairs
def measure(manifest):
    m=load(manifest);env,_=environment();out=OUT/('timing-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir()
    write(out/'manifest.json',m);write(out/'plan.json',plan())
    # Every timing configuration gets every-tick conservation + observer-neutral verification.
    controls={}
    for _,_,fixture,workers,a,b in plan():
        for arm,observer in [a,b]:
            key=f'{arm}-{fixture}-{workers}-{observer}'
            if key in controls:continue
            p=execute('verify-'+key,command(m,arm,fixture,0,0,workers,observer,'behavior',1920),out,env)
            controls[key]=json.loads(p.read_text().splitlines()[-1])
    runs=[]
    for group,candidate,fixture,workers,a,b in plan():
        for pair in range(7):
            for side in ([0,1] if pair%2==0 else [1,0]):
                arm,observer=[a,b][side];name=f'{group}-{candidate}-{fixture}-{workers}-{pair}-{side}'
                p=execute(name,command(m,arm,fixture,0,0,workers,observer,'timing',1920),out,env)
                final=json.loads(p.read_text().splitlines()[-1]);ref=controls[f'{arm}-{fixture}-{workers}-{observer}']
                for key in ['quantity','semantic','cells','visits','block_ticks','moves','last_active']:
                    if final[key]!=ref[key]:raise RuntimeError(f'timing semantic mismatch {name}:{key}')
                runs.append(dict(name=name,group=group,candidate=candidate,fixture=fixture,workers=workers,pair=pair,side=side,arm=arm,observer=observer,sha256=digest(p)))
        print(group,candidate,fixture,workers,flush=True)
    write(out/'completed.json',{'manifest':m,'runs':runs});print(out/'completed.json',flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['prepare','behavior','measure']);p.add_argument('--manifest');a=p.parse_args()
    if a.stage=='prepare':prepare()
    elif a.stage=='behavior':behavior(a.manifest)
    else:measure(a.manifest)
