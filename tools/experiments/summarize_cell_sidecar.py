"""Lossless L4 reduction and independent neutral-operation replay; never runs timings."""
from __future__ import annotations
import argparse,hashlib,json,statistics,struct
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import cell_sidecar as e
N,T=16384,262144
EMPTY=(0,0,0,0,0)
CELL=struct.Struct('<qqHBBhI')
def initial(density,pattern,seed):
 values=[];counts=[0]*16
 for i in range(T):
  k=(i+seed)%3;rank=((i-131*seed)*196609)%(T) if pattern=='dispersed' else i
  tag=0x80000001+2*i if rank<T*density//100 else 0
  values.append(((3,2,6)[k],1+(i+seed)%255 if k==0 else (17 if k==1 else 48),(i+seed)%13 if k==0 else (23 if k==1 else 0),200+(i+seed)%17,tag));counts[i//N]+=bool(tag)
 return values,counts
def replay(data,mode,density,pattern,seed,x,y,batches):
 """Independent tuple store/transaction implementation, plus explicit species ledgers."""
 if len(data)!=batches*256+T*26:raise ValueError('size')
 values,counts=initial(density,pattern,seed);caps=[min(N,c+64) if c else (64 if mode==1 and density==0 else 0) for c in counts]
 species=[sum(v[0]==m for v in values) for m in (2,3,6)]
 water=sum(v[1] for v in values if v[0]==3);tags=sum(counts);initial_species=species[:];initial_water=water;initial_tags=tags;ledger=[];totals=[0]*32
 unread=[0]*32
 if mode!=2:
  for i,v in enumerate(values):unread[(i%(2*N))//1024]+=sum(v[:3])+i
 for batch in range(batches):
  work=[0]*32;sources=[0]*3;sinks=[0]*3
  if mode!=2:work[28]=unread[batch%32];work[29]=8192
  for pair in (range(8) if mode==2 else ()):
   for j in range(64):
    k=batch*8+j//8;cx=(k*73+seed*19)%255;cy=(k*37+seed*11)%128
    if j//8==0:cx=127
    def location(xx):return (2*pair+xx//128)*N+cy*128+xx%128
    a,b=location(cx),location(cx+1);op=(4,6,5,2,3,0,1,7)[j%8]
    if op in (6,3):a,b=b,a
    old_a,old_b=values[a],values[b];va,vb=old_a,old_b;valid=True;work[29]+=1
    if op==0:
     valid=va[0]!=0 and vb[0]==0
     if valid:va,vb=EMPTY,va
    elif op==1:va,vb=vb,va
    elif op==2:
     valid=va[0]==3 and va[1]>1 and vb[0]==0
     if valid:vb=(va[0],va[1]//2,*va[2:]);va=(va[0],va[1]-vb[1],*va[2:])
    elif op==3:
     valid=va[0]==3 and vb[0]==3 and va[1]+vb[1]<=255
     if valid:vb=(3,va[1]+vb[1],max(va[2],vb[2]),vb[3],vb[4] or va[4]);va=EMPTY
    elif op in (4,6):va=EMPTY
    elif op==5:
     valid=va[0]==0
     if valid:
      rank=((a-131*seed)*196609)%T if pattern=='dispersed' else a
      va=(3,127,12,211,0x80000001+2*a if rank<T*density//100 else 0)
    else:work[28]+=va[4]+vb[4]+va[0]+vb[0]+va[1]+vb[1]
    if not valid:work[8+op]+=1;continue
    ca,cb=a//N,b//N;next_counts={c:counts[c] for c in (ca,cb)}
    next_counts[ca]+=bool(va[4])-bool(old_a[4]);next_counts[cb]+=bool(vb[4])-bool(old_b[4])
    if any(n>caps[c] for c,n in next_counts.items()):work[16+op]+=1;continue
    for c,n in next_counts.items():counts[c]=n
    values[a],values[b]=va,vb;work[op]+=1
    before=sum(v[1] for v in (old_a,old_b) if v[0]==3);after=sum(v[1] for v in (va,vb) if v[0]==3)
    work[24]+=max(0,after-before);work[25]+=max(0,before-after)
    before_tag=bool(old_a[4])+bool(old_b[4]);after_tag=bool(va[4])+bool(vb[4]);work[26]+=max(0,after_tag-before_tag);work[27]+=max(0,before_tag-after_tag)
    if op==2 and va[4]:work[30]+=1
    if op==6:work[31]+=bool(old_a[4])
    for z,m in enumerate((2,3,6)):
     change=sum(v[0]==m for v in (va,vb))-sum(v[0]==m for v in (old_a,old_b));sources[z]+=max(change,0);sinks[z]+=max(-change,0)
  if tuple(work)!=struct.unpack_from('<32Q',data,batch*256):raise ValueError(f'independent work replay batch{batch}')
  water+=work[24]-work[25];tags+=work[26]-work[27]
  species=[n+s-t for n,s,t in zip(species,sources,sinks)]
  if min(*species,water,tags)<0:raise ValueError('quantity underflow')
  ledger.append(dict(species=species[:],sources=sources,sinks=sinks,water=water,tags=tags))
  totals=[a+b for a,b in zip(totals,work)]
 for i,v in enumerate(values):
  c,local=divmod(i,N);expected=(x+c%4*128+local%128,y+c//4*128+local//128,*v)
  if CELL.unpack_from(data,batches*256+i*26)!=expected:raise ValueError(f'independent final state {i}')
 actual=[sum(v[0]==m for v in values) for m in (2,3,6)]
 if actual!=species or sum(v[1] for v in values if v[0]==3)!=water or sum(bool(v[4]) for v in values)!=tags:raise ValueError('final ledger')
 return dict(initial_species=initial_species,final_species=species,initial_water=initial_water,final_water=water,initial_tags=initial_tags,final_tags=tags,work_totals=totals,batch_ledgers=ledger)
def replay_case(task):
 path,d,p,s,prefix=task;seed,x,y=e.common.SEEDS[int(s)]
 result=replay(e.record(Path(prefix).with_suffix('.records.gz'),1800),2,int(d),p,seed,x,y,1800)
 e.common.write(path/f'replay-{d}-{p}-{s}.json',result)
 return dict(density=d,pattern=p,seed=s,exact=True,final_species=result['final_species'],work_totals=result['work_totals'])
def verify_preparation(path):
 m=json.loads((path/'prepared.json').read_text());rows=json.loads((path/'comparisons.json').read_text());assert len(rows)==720
 groups=defaultdict(list)
 for r in rows:
  name=r['case'].split('-');groups[tuple(name[:3])].append(r)
 tasks=[]
 for (d,p,s),rs in groups.items():
  assert len(rs)==12
  ref=None
  for r in rs:
   data=e.record(Path(r['prefix']).with_suffix('.records.gz'),1800)
   if hashlib.sha256(data).hexdigest()!=r['record_sha256']:raise ValueError('raw hash')
   if ref is None:ref=data
   elif ref!=data:raise ValueError('repeat/worker/carrier')
  tasks.append((path,d,p,s,rs[0]['prefix']))
 output=[]
 # Offline correctness only; never concurrent with the measured campaign.
 with ProcessPoolExecutor(max_workers=4) as pool:
  for result in pool.map(replay_case,tasks):
   output.append(result);print('replay',result['density'],result['pattern'],result['seed'],flush=True)
 e.common.write(path/'independent-replay.json',output)
 smoke=json.loads((path/'smokes.json').read_text());assert len(smoke)==12
 ref=e.record(Path(smoke[0]['prefix']).with_suffix('.records.gz'),1920)
 for r in smoke:
  if ref!=e.record(Path(r['prefix']).with_suffix('.records.gz'),1920):raise ValueError('smoke parity')
 e.common.write(path/'smoke-replay.json',replay(ref,0,0,'clustered',0,0,0,1920))
 e.common.write(path/'verified.json',dict(prepared_sha256=e.common.digest(path/'prepared.json'),comparisons_sha256=e.common.digest(path/'comparisons.json'),smokes_sha256=e.common.digest(path/'smokes.json'),exact_cases=60,exact_smokes=12,source=e.identity()))
 return m
def timing_replay_case(task):
 path,key,prefix=task
 result=replay(e.record(Path(prefix).with_suffix('.records.gz'),1920),*key,0,0,0,1920)
 e.common.write(path/f'replay-{key[0]}-{key[1]}-{key[2]}.json',result)
 return str(key),{k:v for k,v in result.items() if k!='batch_ledgers'}
def summarize(path):
 rows=json.loads((path/'results.json').read_text());plan=e.plan();assert len(rows)==len(plan)==1400
 groups=defaultdict(list);equivalence={};tasks=[]
 for r,p in zip(rows,plan):
  if any(r[k]!=v for k,v in p.items()):raise ValueError('plan/order')
  prefix=Path(r['prefix']);execution=json.loads(prefix.with_suffix('.execution.json').read_text());assert execution['exit_code']==0
  data=e.record(prefix.with_suffix('.records.gz'),1920)
  if hashlib.sha256(data).hexdigest()!=r['record_sha256']:raise ValueError('hash')
  key=tuple(r[k] for k in ('mode','density','pattern'))
  if key in equivalence:
   if data!=equivalence[key]:raise ValueError('exact carrier/worker/repeat')
  else:
   equivalence[key]=data;tasks.append((path,key,r['prefix']))
  samples=e.samples(prefix.with_suffix('.samples.csv'),1920)
  if e.summary(samples[:120])!=r['warmup'] or e.summary(samples[120:])!=r['steady']:raise ValueError('sample reduction')
  if any(s['units']!=struct.unpack_from('<Q',data,s['sample']*256+29*8)[0] for s in samples):raise ValueError('units/work')
  mem=r['memory'];caps=[c['cap'] for c in mem['chunks']];prepared=sum(c>0 for c in caps)
  expected=T*6+(T*4 if r['variant']=='inline' else prepared*N*4 if r['variant']=='soa' else prepared*N*2+sum(caps)*8)
  if mem['resident_array_bytes']!=expected or mem['batch_cpp_allocations']!=0:raise ValueError('memory')
  group=tuple(r[k] for k in ('candidate','mode','density','pattern','workers'));groups[group].append(r)
 with ProcessPoolExecutor(max_workers=4) as pool:replays=dict(pool.map(timing_replay_case,tasks))
 result=[]
 for key,rs in groups.items():
  assert len(rs)==14;pairs=[]
  for pair in range(7):
   a,b=sorted((r for r in rs if r['pair']==pair),key=lambda r:r['member']);ratios={k:b['steady'][k]/a['steady'][k] for k in ('p50','p95','p99','max','total','ns_per_unit')}
   pairs.append(dict(pair=pair,ratios=ratios,flag=ratios['p95']>1.15,control_prefix=a['prefix'],candidate_prefix=b['prefix']))
  result.append(dict(group=key,median_ratios={k:statistics.median(p['ratios'][k] for p in pairs) for k in pairs[0]['ratios']},flagged_pairs=[p['pair'] for p in pairs if p['flag']],pairs=pairs))
 reduced=dict(processes=1400,exact_pairs=700,groups=result,replays=replays)
 e.common.write(path/'reduced.json',reduced)
 text=['# L4 synthetic carrier results','', 'Batch units are8192 legacy reads or512 transaction attempts; no World-speed inference.','', '|Candidate|Mode|Density|Pattern|Workers|p50 ratio|p95 ratio|p99 ratio|Total ratio|15% pairs|','|---|---:|---:|---|---:|---:|---:|---:|---:|---|']
 for r in result:
  v=r['median_ratios'];text.append('|'+ '|'.join(map(str,r['group']))+f"|{v['p50']:.4f}|{v['p95']:.4f}|{v['p99']:.4f}|{v['total']:.4f}|{r['flagged_pairs']}|")
 (path/'summary.md').write_text('\n'.join(text)+'\n',encoding='utf-8');print('L4 REDUCTION PASS',flush=True)
 return reduced
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('path',type=Path);p.add_argument('--preparation',action='store_true');a=p.parse_args()
 if a.preparation:verify_preparation(a.path.resolve())
 else:summarize(a.path.resolve())
