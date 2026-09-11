"""Issue16 L4 bounded synthetic carrier: prepare, then sequential released timing."""
from __future__ import annotations
import argparse,csv,gzip,json,math,statistics,struct,time
from pathlib import Path
import cell_layout as common
ROOT,OUT,BUILD=common.ROOT,common.OUT,common.BUILD
VARIANTS={'inline':0,'soa':1,'sparse':2}
DENSITIES=(0,1,5,15,50,100)
def identity():
 r=common.identity()
 for pattern in ('native/bench/cell_sidecar.cpp','tools/experiments/*cell_sidecar*.py'):
  for p in ROOT.glob(pattern):r['files'][str(p.relative_to(ROOT))]=common.digest(p)
 return r
def plan():
 rows=[]
 for candidate in ('soa','sparse'):
  for mode in (0,1,2):
   for density in ((0,) if mode==0 else DENSITIES):
    for pattern in (('clustered',) if mode==0 else ('clustered','dispersed')):
     for workers in (1,4):
      for pair in range(7):
       for member in ((0,1) if pair%2==0 else (1,0)):
        rows.append(dict(candidate=candidate,mode=mode,density=density,pattern=pattern,workers=workers,pair=pair,member=member,variant=('inline',candidate)[member],batches=1920))
 assert len(rows)==1400
 return rows
def samples(path,batches):
 with path.open() as f:rows=[{k:int(v) for k,v in x.items()} for x in csv.DictReader(f)]
 if [r['sample'] for r in rows]!=list(range(batches)) or any(r['ns']<=0 for r in rows):raise ValueError('samples')
 return rows
def summary(rows):
 times=sorted(r['ns'] for r in rows);n=len(times);units=sum(r['units'] for r in rows)
 return dict(p50=times[math.ceil(n*.5)-1],p95=times[math.ceil(n*.95)-1],p99=times[math.ceil(n*.99)-1],max=times[-1],total=sum(times),ns_per_unit=sum(times)/units)
def record(path,batches):
 with (gzip.open(path,'rb') if path.suffix=='.gz' else path.open('rb')) as f:data=f.read()
 if len(data)!=batches*256+262144*26:raise ValueError('record size')
 return data
def run(label,a,mode,density,pattern,workers,batches,seed,x,y,correctness,out,env):
 prefix=out/label
 log=common.execute(label,[a['exe'],mode,density,pattern,workers,batches,seed,x,y,int(correctness),prefix,0],out,env)
 meta=json.loads(log.read_text(encoding='utf-8'))
 if meta['batch_cpp_allocations']!=0:raise ValueError('allocation')
 rows=samples(prefix.with_suffix('.samples.csv'),batches)
 if any(r['units']!=(512 if mode==2 else 8192) for r in rows):raise ValueError('units')
 raw=prefix.with_suffix('.records');sha=common.digest(raw);common.compress(raw)
 return dict(prefix=str(prefix),record_sha256=sha,memory=meta,warmup=summary(rows[:120]),steady=summary(rows[120:]))
def prepare():
 out=OUT/('prepare-l4-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir();build=BUILD/out.name;build.mkdir()
 env,cxx=common.environment();common.write(out/'source-before.json',identity());artifacts={}
 flags=[cxx,'-std=c++20','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wshadow','-pthread','-static','-Inative/include','-DCYBERSAND_CELL_LAYOUT_EXPERIMENT=4','-DCYBERSAND_CELL_LAYOUT_ALIGNMENT=4','-DCYBERSAND_CELL_LAYOUT_PACKED=0']
 for name,index in VARIANTS.items():
  exe=build/(name+'.exe');common.execute('build-'+name,[*flags,'-O3','-DNDEBUG','-flto',f'-DSIDECAR_LAYOUT={index}','native/bench/cell_sidecar.cpp','-lpsapi','-o',exe],out,env,1200)
  artifacts[name]=dict(exe=str(exe),sha256=common.digest(exe))
  common.execute('selftest-'+name,[exe,'selftest'],out,env)
  common.execute('disassembly-'+name,[cxx.parent/'llvm-objdump.exe','-d','--demangle',exe],out,env,1200)
 common.write(out/'built-artifacts.json',artifacts);results=[]
 for density in DENSITIES:
  for pattern in ('clustered','dispersed'):
   for seed,x,y in common.SEEDS:
    reference=None
    for name in VARIANTS:
     for workers in (1,4):
      for repeat in (0,1):
       label=f'{density}-{pattern}-{seed}-{name}-{workers}-{repeat}'
       r=run(label,artifacts[name],2,density,pattern,workers,1800,seed,x,y,True,out,env)
       data=record(Path(r['prefix']).with_suffix('.records.gz'),1800)
       totals=[0]*32
       for work in struct.iter_unpack('<32Q',data[:1800*256]):totals=[a+b for a,b in zip(totals,work)]
       if any(n==0 for n in totals[:8]):raise ValueError('insufficient accepted operation coverage')
       r['work_totals']=totals
       if reference is None:reference=data
       elif reference!=data:raise ValueError('correctness exact mismatch '+label)
       results.append(dict(case=label,**r));common.write(out/'comparisons.json',results)
 smokes=[];reference=None
 for mode in (0,1):
  for name in VARIANTS:
   for workers in (1,4):
    r=run(f'smoke-{mode}-{name}-{workers}',artifacts[name],mode,0,'clustered',workers,1920,0,0,0,False,out,env)
    data=record(Path(r['prefix']).with_suffix('.records.gz'),1920)
    if reference is None:reference=data
    elif reference!=data:raise ValueError('absent/unread smoke mismatch')
    smokes.append(r)
 common.write(out/'smokes.json',smokes)
 manifest=dict(stage='L4-prepared',source=identity(),artifacts=artifacts,toolchain=dict(path=str(cxx),sha256=common.digest(cxx)),output=str(out),plan=plan())
 common.write(out/'prepared.json',manifest);print('L4 PREPARED',out/'prepared.json',flush=True)
def measure(path,released):
 if not released:raise RuntimeError('owner release required')
 m=json.loads(path.read_text(encoding='utf-8'));assert m['source']['files']==identity()['files'] and m['plan']==plan()
 prep=Path(m['output']);assert len(json.loads((prep/'independent-replay.json').read_text()))==60 and len(json.loads((prep/'smokes.json').read_text()))==12
 verified=json.loads((prep/'verified.json').read_text());assert verified['prepared_sha256']==common.digest(path) and verified['comparisons_sha256']==common.digest(prep/'comparisons.json') and verified['smokes_sha256']==common.digest(prep/'smokes.json') and verified['source']['files']==identity()['files']
 env,cxx=common.environment();assert common.digest(cxx)==m['toolchain']['sha256']
 for a in m['artifacts'].values():assert common.digest(a['exe'])==a['sha256']
 out=OUT/('timing-l4-'+time.strftime('%Y%m%d-%H%M%S'));out.mkdir();common.write(out/'identity.json',m);common.write(out/'plan.json',plan());common.write(out/'release-identity.json',identity());results=[];pairs={}
 for index,row in enumerate(plan()):
  r=run(f'{index:04d}',m['artifacts'][row['variant']],row['mode'],row['density'],row['pattern'],row['workers'],1920,0,0,0,False,out,env);r=dict(**row,**r)
  key=tuple(row[k] for k in ('candidate','mode','density','pattern','workers','pair'))
  if key in pairs:
   old=pairs.pop(key)
   if record(Path(old['prefix']).with_suffix('.records.gz'),1920)!=record(Path(r['prefix']).with_suffix('.records.gz'),1920):raise ValueError('timed exact mismatch')
  else:pairs[key]=r
  results.append(r);common.write(out/'results.json',results)
 common.write(out/'post-measurement-identity.json',identity());assert m['source']['files']==identity()['files']
 print('L4 COMPLETE',out,flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=('prepare','measure','plan'));p.add_argument('--manifest',type=Path);p.add_argument('--owner-released',action='store_true');a=p.parse_args()
 if ROOT!=Path('C:/kybersand/worktrees/issue-16-cell-layout'):raise RuntimeError('wrong workspace')
 if a.action=='prepare':prepare()
 elif a.action=='plan':print(json.dumps(plan(),indent=2))
 elif a.manifest is None:p.error('--manifest required')
 else:measure(a.manifest.resolve(),a.owner_released)
