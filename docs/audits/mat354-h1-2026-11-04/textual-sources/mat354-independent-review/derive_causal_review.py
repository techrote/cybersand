"""Independent fixed-fixture thermal/census reconstruction; does not execute World.
Read-only inputs: frozen F2 JSONL receipts. Writes only this isolated review area.
"""
import collections,functools,hashlib,json
from pathlib import Path
ROOT=Path('/workspace/scratch/53686e322277/mat354-evidence/correctness-attempt-2')
OUT=Path('/workspace/scratch/53686e322277/mat354-independent-review')
MASK=(1<<64)-1

def fact(p):
 data=p.read_bytes();return {'path':str(p),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
def authenticate(f):
 p=Path(f['path']);got=fact(p);assert got==f,(got,f);return p.read_bytes()
def mix(v):
 v=((v^(v>>30))*0xbf58476d1ce4e5b9)&MASK
 v=((v^(v>>27))*0x94d049bb133111eb)&MASK
 return v^(v>>31)
def phase(x,y):
 y&=MASK;rot=((y<<23)|(y>>41))&MASK
 return mix((((x&MASK)*0x9e3779b185ebca87)&MASK)^rot^((192*0xa0761d6478bd642f)&MASK))%4
def visits(t,p):
 first=p or 4
 return 0 if t<first else (t-first)//4+1
def material(a):return (36,a,0,200) if a else (35,0,0,200)
def room(c,x,y,w=1):
 for xx in range(x-1,x+w+1):
  for yy in range(y-1,y+2):c[(xx,yy)]=(1,0,0,200)
@functools.lru_cache(None)
def model(variant,fixture,edit,t):
 c={}
 if fixture=='distributed_molten':
  for i in range(64):
   x,y=8+128*i,8;room(c,x,y);p=phase(x,y)
   n=visits(t,p) if variant=='successor' else int(p!=0 and t>=p)
   c[(x,y)]=material(180-n)
 elif fixture=='molten_lost_neighbor':
  room(c,8,8,2)
  a=180 if t<17 else (max(0,180-((t-17)//4+1)) if variant=='successor' else 179)
  c[(8,8)]=material(a)
  if t<17:c[(9,8)]=material(180)
 elif fixture=='molten_short' and edit=='neighbor_mask':
  room(c,8,8,2)
  a=180
  if 9<=t<=16:a=180-(1+(t>=13) if variant=='successor' else 1)
  c[(8,8)]=material(a);c[(9,8)]=material(180)
 elif fixture=='molten_short' and edit=='neighbor_edit':
  room(c,8,8,2)
  if variant=='baseline':
   c[(8,8)]=material(3 if t<17 else 180)
   if t>=17:c[(9,8)]=material(180)
  else:
   c[(8,8)]=material(max(0,4-visits(t,1)))
   if t>=17:c[(9,8)]=material(max(0,180-((t-17)//4+1)))
 else:raise AssertionError((variant,fixture,edit,t))
 h=14695981039346656037
 for (x,y),fields in sorted(c.items()):
  for n in (x,y,*fields):
   for byte in (n&MASK).to_bytes(8,'little'):h=((h^byte)*1099511628211)&MASK
 counts=collections.Counter(v[0] for v in c.values())
 return f'{h:016x}',c[(8,8)],dict(counts)

receipt_path=ROOT/'qualification.json';receipt=json.loads(receipt_path.read_text())
assert receipt['status']=='EXECUTED' and receipt['mode']=='correctness'
assert receipt['sources']['successor']['commit']=='9d218bb179e72e9fa68b755d82680dbd739fb85e'
pending={r['id'] for r in receipt['correctness']['pending_causal_reviews']}
assert len(pending)==10
runs={};raw=[]
for record in receipt['runs']:
 if record.get('kind')!='phase-a-reuse' or record['process']['id'] not in pending:continue
 p=record['process'];assert p['returncode']==0 and not p['timed_out']
 rows=[json.loads(line) for line in authenticate(p['stdout']).splitlines()]
 authenticate(p['stderr']);raw.extend([p['stdout'],p['stderr']])
 meta=rows[0];ticks=rows[1:-1];assert meta['case_id']==p['id'] and len(ticks)==meta['horizon']
 for t,row in enumerate(ticks,1):
  assert row['tick']==t and row['world_tick']==t and not row['has_failed'] and row['quantity_ok']
  expected,source,counts=model(record['variant'],meta['fixture'],meta['variant'],t)
  assert row['tuple_hash']==expected,(record['variant'],p['id'],t,'census',row['tuple_hash'],expected)
  assert (row['material'],row['state_a'],row['state_b'],row['temperature'])==source,(p['id'],t,'source')
  assert row['subject_count']==counts.get(36,0) and row['glass_count']==counts.get(35,0),(p['id'],t,'counts')
  assert row['source_x']==8 and row['source_y']==8 and row['water_quantity']==0
  if record['variant']=='successor' and meta['fixture']=='distributed_molten':
   due=sum(t%4==phase(8+128*i,8) for i in range(64))
   assert row['kernel_visits']>=due,(p['id'],t,'actual aggregate entries below due sources')
 runs[(p['id'],record['variant'])]=ticks
results=[]
for case in sorted(pending):
 old,new=runs[(case,'baseline')],runs[(case,'successor')]
 changed=[i+1 for i,(a,b) in enumerate(zip(old,new)) if a['tuple_hash']!=b['tuple_hash']]
 physical=[i+1 for i,(a,b) in enumerate(zip(old,new)) if a['physical_hash']!=b['physical_hash']]
 index=changed[0]-1
 def detail(r):return {k:r[k] for k in ('tick','world_tick','material_before','state_a_before','material','state_a','hot_neighbor_before','source_masked','cooling_due','kernel_visits','block_before','block_after','scheduled_cores')}
 if case.startswith('molten_lost_neighbor'):
  assert changed[0]==21
  reason='Partner removed at17; source179 at17. Baseline then sleeps. Successor due21 visits restore cold countdown to178, then every4 ticks to native Glass at733.'
 elif '__neighbor_mask__' in case:
  assert changed==[13,14,15,16]
  reason='Both sources reset to180 on tick1. Masked right partner at9 permits left179; successor due13 decrements178 while baseline remains179. Unmask17 restores visible MoltenGlass heat and both reset/retain180; tuples coincide thereafter.'
 elif '__neighbor_edit__' in case:
  assert changed[0]==5
  reason='Cold left source completes restored4-tick countdown toGlass at13. Identical heat insertion at17 encounters Glass in successor, so new right source cools from180; baseline left remained MoltenGlass3 and the two touching sources reset/retain180. All later cell tuples match the unchanged thermal law.'
 else:
  assert case.startswith('distributed_molten') and changed[0]==4
  reason='All64 separate sources obey their independently computed stream192 phases. Baseline phase0 sources never cool; other phases cool once then sleep. Every successor source follows180 minus its exact due-visit count. Complete576-cell census reconstructed at every tick; actual aggregate kernel entries cover all due sources.'
 results.append({'case':case,'disposition':'CAUSALLY_EXPLAINED_H1_ONLY','ticks_per_source':len(old),'independent_domain_census_hashes_matched':2*len(old),'first_physical_difference':physical[0] if physical else None,'last_physical_difference':physical[-1] if physical else None,'first_tuple_difference':changed[0],'last_tuple_difference':changed[-1],'tuple_difference_steps':len(changed),'first_tuple_baseline':detail(old[index]),'first_tuple_successor':detail(new[index]),'reason':reason})
# All comparable worker and repeat variants retain exact physical trajectories.
groups=collections.defaultdict(list)
for (case,var),ticks in runs.items():
 key=case.split('__w')[0],var
 groups[key].append([r['physical_hash'] for r in ticks])
for key,values in groups.items():assert all(v==values[0] for v in values[1:]),key
report={'schema':'mat354.independent.causal-review.v1','status':'PASS_FOR_TEN_CAUSAL_CASES_ONLY','final_adoption_disposition':'PENDING_IMMUTABLE_PUBLISHED_PACKET_AND_OTHER_GATES','input_receipt':fact(receipt_path),'candidate_commit':receipt['sources']['successor']['commit'],'candidate_tree':receipt['sources']['successor']['tree'],'source_world_sha256':receipt['sources']['successor']['world_lf_sha256'],'method':'Independent closed-form frozen-fixture thermal laws and whole-domain FNV census reconstruction; no World execution and no import of candidate reducer/oracles. Ambient200, state_b0, fixed walls, registered edits and preserved stream192 phases. Comparisons authenticate original raw bytes.','cases':results,'raw_inputs':raw,'total_independently_reconstructed_tick_censuses':sum(r['independent_domain_census_hashes_matched'] for r in results),'worker_repeat_physical_groups':len(groups)}
report['review_script']=fact(Path(__file__))
(OUT/'f2-independent-causal-review.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ('cases','raw_inputs')},indent=2))
for r in results:print(r['case'],r['first_physical_difference'],r['first_tuple_difference'],r['last_tuple_difference'],r['disposition'])
