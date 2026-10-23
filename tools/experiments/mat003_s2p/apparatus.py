"""S2P actual-workload twin qualifier. Never invokes measurement mode."""
import argparse,hashlib,importlib.util,json,os,platform,shutil,subprocess,sys,time
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path('tools/experiments/mat003_s2p')
BASE='2b2a1dd64f16dc46d5e812b757de73f47df0fb2b'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):
 p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(v,indent=2,sort_keys=True)+'\n').encode())
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def module(p,name):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def collect(out):
 out=out.resolve();assert not out.exists(),'append-only output exists';out.mkdir(parents=True)
 reg=load(ROOT/HERE/'registration.json'); started=time.monotonic()
 report=dict(source_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),registration_sha256=sha(ROOT/HERE/'registration.json'),status='incomplete',errors=[],commands=[],builds=[],cases=[],formal_timing_admitted=False)
 def run(argv,label,timeout):
  assert time.monotonic()-started<reg['budgets']['qualification_wall_seconds'],'wall budget exhausted'
  a=out/(label+'.stdout');b=out/(label+'.stderr');a.parent.mkdir(parents=True,exist_ok=True)
  row=dict(label=label,argv=list(map(str,argv)),timeout=timeout,exit_code=None,timed_out=False);report['commands'].append(row)
  with a.open('wb') as stdout,b.open('wb') as stderr:
   try:row['exit_code']=subprocess.run(row['argv'],cwd=ROOT,stdout=stdout,stderr=stderr,timeout=timeout).returncode
   except subprocess.TimeoutExpired:row['timed_out']=True
  assert row['exit_code']==0 and not row['timed_out'],'failed '+label
  assert not b.read_bytes().strip(),'stderr '+label
  return a.read_text()
 try:
  assert reg['formal_timing_admitted'] is False and reg['execution_authorized'] is False
  assert platform.system()=='Linux' and platform.machine()=='x86_64'
  paths=subprocess.check_output(['git','ls-files','native/include','native/src','tools/experiments/mat003_prepass','tools/experiments/mat003_s2a','tools/experiments/mat003_continuation','tools/experiments/mat003_s2p'],cwd=ROOT,text=True).splitlines()
  source=out/'source';manifest={}
  for name in paths:
   original=ROOT/name;data=original.read_bytes();expected=subprocess.check_output(['git','show',report['source_head']+':'+name],cwd=ROOT)
   assert data==expected,'local source delta '+name
   if name.startswith(('native/','tools/experiments/mat003_prepass/','tools/experiments/mat003_s2a/')):
    assert data==subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT),'accepted source drift '+name
   dest=source/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);manifest[name]=sha(dest)
  dump(out/'source-manifest.json',manifest)
  report['compiler_version']=run(['g++-13','--version'],'compiler-version',10);report['linker_version']=run(['ld','--version'],'linker-version',10)
  assert '13.3.0' in report['compiler_version'] and '2.42' in report['linker_version']
  overlay=module(source/'tools/experiments/mat003_continuation/overlay.py','s2p_overlay')
  pending=[]
  for arm in reg['arms']:
   work=out/'overlays'/arm['id'];receipt=overlay.prepare(source,work,arm['representation'],8,arm['extra_bytes'])
   # Compile the same generated source for each observed/off twin.
   for observer in [0,1]:
    ident=arm['id']+'-o'+str(observer);binary=out/'bin'/ident;binary.parent.mkdir(exist_ok=True)
    argv=['g++-13',*reg['flags'],*receipt['compile_definitions'],'-DMAT003_TWIN_OBSERVERS='+str(observer),'-I'+str(work/'native/include'),'-I'+str(work/'tools/experiments/mat003_prepass'),str(source/HERE/'fixture.cpp'),str(work/'native/src/world.cpp'),*[str(work/('native/src/'+n+'.cpp')) for n in ['material_rules','scheduler_geometry','settled_world_discovery']],'-o',str(binary)]
    pending.append((ident,arm,observer,binary,work,receipt,argv))
  dump(out/'generated-seal.json',{p.relative_to(out).as_posix():sha(p) for p in sorted((out/'overlays').rglob('*')) if p.is_file()})
  for ident,arm,observer,binary,work,receipt,argv in pending:
   run(argv,'compile/'+ident,reg['budgets']['compile_seconds']);report['builds'].append(dict(id=ident,arm=arm['id'],observer=observer,binary=binary.relative_to(out).as_posix(),sha256=sha(binary),overlay=work.relative_to(out).as_posix(),compile_definitions=receipt['compile_definitions']))
  dump(out/'binary-seal.json',report['builds'])
  for b in report['builds']:
   binary=out/b['binary'];assert sha(binary)==b['sha256']
   argv=[str(binary),'--side','512','--workers','4','--warmup','120','--ticks','256','--seed','204','--scenario','active','--mode','qualify']
   run(argv,'execute/'+b['id'],reg['budgets']['process_seconds'])
   report['cases'].append(dict(id=b['id'],arm=b['arm'],observer=b['observer'],stdout='execute/'+b['id']+'.stdout',stderr='execute/'+b['id']+'.stderr'))
  assert len(report['builds'])==10 and len(report['cases'])==10
  report['status']='qualified-not-admitted'
 except Exception as error:report['errors'].append(str(error))
 finally:
  dump(out/'run.json',report);dump(out/'files.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='files.json'})
 if report['errors']:raise ValueError(report['errors'])
if __name__=='__main__':
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args();collect(args.output)
