"""Issue16 L3 registered epoch isolation; prepare before released sequential timing."""
from __future__ import annotations
import argparse,csv,gzip,json,struct,sys,time
from pathlib import Path
import cell_layout as common
from cell_packing import cases
from summarize_cell_layout import summarize_samples
ROOT,OUT,BUILD=common.ROOT,common.OUT,common.BUILD
VARIANTS={'e8':8,'e6':6}
def identity():
 r=common.identity()
 for name in ('tools/experiments/cell_epoch.py','tools/experiments/cell_packing.py','tools/experiments/summarize_cell_layout.py','native/bench/cell_epoch.cpp','native/tests/test_cell_epoch.cpp'):
  r['files'][str(Path(name))]=common.digest(ROOT/name)
 return r
def frame(stream,keep_hash=False,events=True):
 size=stream.read(8)
 if not size:return None
 if len(size)!=8:raise ValueError('truncated frame size')
 n=struct.unpack('<Q',size)[0];cells=stream.read(n);work=stream.read(128);count=stream.read(8)
 if n%22 or len(cells)!=n or len(work)!=128 or len(count)!=8:raise ValueError('truncated frame')
 tail=stream.read(struct.unpack('<Q',count)[0]*16)
 if len(tail)!=struct.unpack('<Q',count)[0]*16:raise ValueError('truncated events')
 return size+cells+work[:128 if keep_hash else 120]+(count+tail if events else b'')
def frames(path,keep_hash=False,events=True):
 opener=gzip.open if path.suffix=='.gz' else open
 with opener(path,'rb') as stream:
  while (value:=frame(stream,keep_hash,events)) is not None:yield value
def equal_frames(a,b,keep_hash=False,events=True,prefix=False):
 left,right=iter(frames(a,keep_hash,events)),iter(frames(b,keep_hash,events))
 count=0
 for value in left:
  if next(right,None)!=value:raise ValueError(f'Exact frame mismatch: {a} / {b} frame{count}')
  count+=1
 if not prefix and next(right,None) is not None:raise ValueError('extra frame')
 return count
def normalized_timing(path,ticks=2048):
 with path.open('rb') as stream:
  work=stream.read(ticks*120)
  if len(work)!=ticks*120:raise ValueError('truncated timing work')
  value=frame(stream)
  if value is None or stream.read(1):raise ValueError('missing/extra timing frame')
  return work+value
def wrap_ticks(bits,last=2048,first=1):
 m=(1<<bits)-1
 return list(range(m+1,last+1,m)) if first==1 else [t for t in range(m+1,last+1,m) if t>=first]
def read_clears(prefix,bits,enabled,last):
 with prefix.with_suffix('.clears.csv').open() as f:rows=[{k:int(v) for k,v in x.items()} for x in csv.DictReader(f)]
 with prefix.with_suffix('.clear-chunks.csv').open() as f:chunks=[{k:int(v) for k,v in x.items()} for x in csv.DictReader(f)]
 expected=wrap_ticks(bits,last) if enabled else []
 if [r['tick'] for r in rows]!=expected:raise ValueError('clear schedule mismatch')
 by_tick={t:[] for t in expected}
 for c in chunks:
  if c['tick'] not in by_tick:raise ValueError('unexpected chunk record')
  by_tick[c['tick']].append(c)
 for r in rows:
  cs=by_tick[r['tick']]
  if len(cs)!=r['chunks'] or sum(c['cells'] for c in cs)!=r['cells'] or len({(c['x'],c['y']) for c in cs})!=len(cs):raise ValueError('clear identity mismatch')
  if any(c['cells']!=16384 or c['selection'] not in (0,1,2) or c['active'] not in (0,1) for c in cs):raise ValueError('clear geometry/flags mismatch')
 return rows,chunks
def plan():
 rows=[]
 def series(name,fixture,extent,workers,a,b,obs=(0,0)):
  for pair in range(7):
   for member in ((0,1) if pair%2==0 else (1,0)):
    rows.append(dict(comparison=name,fixture=fixture,extent=extent,workers=workers,pair=pair,member=member,variant=(a,b)[member],observer=obs[member],ticks=2048))
 for f,e,w in [('dense',512,4),('sleeping',4096,1)]:series('bridge',f,e,w,'legacy8','e8')
 for f,e,w in cases():series('epoch',f,e,w,'e8','e6')
 for v in VARIANTS:
  for f,e in [('sparse',1024),('sleeping',4096)]:
   for w in (1,4):series('observer-'+v,f,e,w,v,v,(0,2))
 assert len(rows)==280
 return rows
def prepare(legacy_path):
 legacy=json.loads(legacy_path.read_text());env,cxx=common.environment()
 retained=legacy['artifacts']['packed4'];assert common.digest(retained['exe'])==retained['sha256']
 assert common.digest(cxx)==legacy['toolchain']['sha256']
 out=OUT/('prepare-l3-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir()
 build=BUILD/out.name;build.mkdir()
 common.write(out/'source-before.json',identity())
 flags=[cxx,'-std=c++20','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wshadow','-pthread','-static','-Inative/include']
 common.execute('build-default-tests',[*flags,'-O0','-g3',*common.CORE,'native/tests/test_world.cpp','-o',build/'default-tests.exe'],out,env,1200)
 common.execute('default-tests',[build/'default-tests.exe'],out,env)
 artifacts={'legacy8':dict(retained,epoch_bits=8)}
 for name,bits in VARIANTS.items():
  target=build/name;target.mkdir()
  defs=['-DCYBERSAND_CELL_LAYOUT_EXPERIMENT=4','-DCYBERSAND_CELL_LAYOUT_ALIGNMENT=4','-DCYBERSAND_CELL_LAYOUT_PACKED=1','-DCYBERSAND_CELL_EPOCH_OBSERVER=1',f'-DCYBERSAND_CELL_LAYOUT_EPOCH_BITS={bits}']
  exe,tests,epoch=target/'cell_epoch.exe',target/'tests.exe',target/'epoch-tests.exe'
  common.execute('build-'+name,[*flags,'-O3','-DNDEBUG','-flto',*defs,*common.CORE,'native/bench/cell_epoch.cpp','-lpsapi','-o',exe],out,env,1200)
  common.execute('build-tests-'+name,[*flags,'-O0','-g3',*defs,*common.CORE,'native/tests/test_world.cpp','-o',tests],out,env,1200)
  common.execute('native-tests-'+name,[tests],out,env)
  common.execute('build-epoch-tests-'+name,[*flags,'-O2',*defs,*common.CORE,'native/tests/test_cell_epoch.cpp','-o',epoch],out,env,1200)
  common.execute('epoch-tests-'+name,[epoch],out,env)
  common.execute('assembly-'+name,[*flags,'-O3','-DNDEBUG',*defs,'-S','native/src/world.cpp','-o',target/'world.s'],out,env,1200)
  common.execute('lto-disassembly-'+name,[cxx.parent/'llvm-objdump.exe','-d','--demangle',exe],out,env,1200)
  artifacts[name]=dict(exe=str(exe),sha256=common.digest(exe),tests=str(tests),tests_sha256=common.digest(tests),epoch_tests=str(epoch),epoch_tests_sha256=common.digest(epoch),defines=defs,epoch_bits=bits)
  common.write(out/'built-artifacts.json',artifacts)
 common.execute('c-header',[cxx.parent/'clang.exe','-std=c11','-Wall','-Wextra','-Wpedantic','-Inative/include','-fsyntax-only','native/tests/test_c_header.c'],out,env,120)
 comparisons=[]
 for fixture in ('behavior','epoch'):
  for seed,x,y in common.SEEDS:
   ref=None
   for name,bits in VARIANTS.items():
    for workers in (1,4):
     for repeat in (0,1):
      label=f'{fixture}-{seed}-{name}-{workers}-{repeat}';prefix=out/label
      common.execute(label,[artifacts[name]['exe'],'correctness',fixture,512,workers,2048,seed,x,y,3,prefix],out,env)
      record=prefix.with_suffix('.records');read_clears(prefix,bits,True,2048)
      if ref is None:ref=record
      else:equal_frames(ref,record,keep_hash=name=='e8')
      if name=='e8' and fixture=='behavior':equal_frames(Path(legacy['output'])/f'behavior-{seed}-packed4-1-0.records.gz',record,keep_hash=True,prefix=True)
      comparisons.append(dict(case=label,sha256=common.digest(record),exact=True))
     if seed==0:
      label=f'{fixture}-observer-off-{name}-{workers}';prefix=out/label
      common.execute(label,[artifacts[name]['exe'],'correctness',fixture,512,workers,2048,seed,x,y,0,prefix],out,env)
      equal_frames(ref,prefix.with_suffix('.records'),keep_hash=name=='e8',events=False)
      read_clears(prefix,bits,False,2048);common.compress(prefix.with_suffix('.records'))
      comparisons.append(dict(case=label,observer_neutral=True))
   for record in out.glob(f'{fixture}-{seed}-*.records'):common.compress(record)
   common.write(out/'comparisons.json',comparisons)
 # Reuse retained L1 setup trajectories; no performance samples in preparation.
 first=json.loads(Path(legacy['legacy_manifest']).read_text())
 for name,bits in VARIANTS.items():
  for fixture,extent,workers in cases():
   label=f'setup-{name}-{fixture}-{extent}-{workers}';prefix=out/label
   common.execute(label,[artifacts[name]['exe'],'correctness',fixture,extent,workers,1,0,0,0,0,prefix],out,env)
   equal_frames(Path(first['output'])/'setup-smoke'/f'{fixture}-{extent}-4-{workers}.records.gz',prefix.with_suffix('.records'),keep_hash=True)
   common.compress(prefix.with_suffix('.records'));comparisons.append(dict(case=label,exact=True))
 common.write(out/'comparisons.json',comparisons)
 manifest=dict(stage='L3-prepared',source=identity(),artifacts=artifacts,toolchain=legacy['toolchain'],output=str(out),legacy_manifest=str(legacy_path),plan=plan())
 common.write(out/'prepared.json',manifest);print('L3 PREPARED',out/'prepared.json',flush=True)
def measure(path,released):
 if not released:raise RuntimeError('Owner release required')
 m=json.loads(path.read_text());assert m['source']['files']==identity()['files'] and m['plan']==plan()
 for a in m['artifacts'].values():assert common.digest(a['exe'])==a['sha256']
 env,cxx=common.environment();assert common.digest(cxx)==m['toolchain']['sha256']
 out=OUT/('timing-l3-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir()
 common.write(out/'identity.json',m);common.write(out/'plan.json',m['plan']);results=[];pairs={}
 for index,row in enumerate(m['plan']):
  prefix=out/f'{index:03d}';a=m['artifacts'][row['variant']]
  log=common.execute(prefix.name,[a['exe'],'timing',row['fixture'],row['extent'],row['workers'],2048,0,0,0,row['observer'],prefix],out,env)
  with prefix.with_suffix('.ticks.csv').open() as f:ticks=list(csv.DictReader(f))
  assert len(ticks)==2048
  if row['variant']!='legacy8':read_clears(prefix,a['epoch_bits'],row['observer']==2,int(ticks[-1]['tick']))
  result=dict(**row,prefix=str(prefix),startup_and_memory=json.loads(log.read_text()),warmup=summarize_samples(ticks[:120]),steady=summarize_samples(ticks[120:]))
  key=(row['comparison'],row['fixture'],row['extent'],row['workers'],row['pair'])
  if key in pairs:
   other=pairs[key];left=Path(other['prefix']).with_suffix('.records');right=prefix.with_suffix('.records')
   if normalized_timing(left)!=normalized_timing(right):raise ValueError('Timed exact epoch pair mismatch')
   if row['comparison']!='epoch' and left.read_bytes()!=right.read_bytes():raise ValueError('Same-schema raw hash/record mismatch')
   control,candidate=(other,result) if row['member']==1 else (result,other)
   result['paired_p95_ratio']=candidate['steady']['p95']/control['steady']['p95']
  else:pairs[key]=result
  results.append(result);common.write(out/'results.json',results)
 print('L3 complete:',out,flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=('prepare','plan','measure'));p.add_argument('--manifest',type=Path);p.add_argument('--owner-released',action='store_true');a=p.parse_args()
 if ROOT!=Path('C:/kybersand/worktrees/issue-16-cell-layout'):raise RuntimeError('Wrong workspace')
 if a.action=='plan':print(json.dumps(plan(),indent=2))
 elif a.manifest is None:p.error('--manifest required')
 elif a.action=='prepare':prepare(a.manifest.resolve())
 else:measure(a.manifest.resolve(),a.owner_released)
