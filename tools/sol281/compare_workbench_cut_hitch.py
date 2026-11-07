import json,statistics,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/workbench-cut-hitch'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def stats(values):return dict(median=statistics.median(values),minimum=min(values),maximum=max(values),samples=len(values))
keys=['outcome','phase','ok','done','member_count','source_member_count','fringe_count','mass','inertia','rectangles','source_digest','frontier_checks','frontier_candidates','frontier_complete','frontier_limited','discovery_attempts','discovery_cells','discovery_neighbours','aggregate_owned','granular_converted_count','fringe_converted_count']
cells=[];parity=[];reports=[];history=[]
for platform in ['windows','linux']:
 for worker in [1,4]:
  paths=[OUT/arm/platform/f'test_workbench_cut_hitch-w{worker}.json' for arm in ['baseline-003','candidate-001']]
  if not all(p.exists() for p in paths):continue
  pair=[json.loads(p.read_text()) for p in paths]
  for arm,p,d in zip(['baseline','candidate'],paths,pair):
   reports.append(dict(arm=arm,platform=platform,workers=worker,path=p.relative_to(ROOT).as_posix(),sha256=sha(p),checks=d['checks'],failures=d['failures'],observed_workers=d['evidence']['maximum_observed_workers']))
   history.append(dict(arm=arm,platform=platform,workers=worker,usec=stats(d['evidence']['history_usec'])))
  for fps in [60,30]:
   for kind in ['first-tree-core','appended-building-core','small-debris','anchored-refusal']:
    a=[[v for v in d['evidence']['cuts'] if v['kind']==kind and v['fps']==fps] for d in pair]
    assert len(a[0])==len(a[1])==5
    assert all([v['repeat'] for v in rows]==list(range(5)) for rows in a)
    entry=dict(platform=platform,workers=worker,fps=fps,kind=kind)
    for arm,rows in zip(['baseline','candidate'],a):
     entry[arm]=dict(held_usec=stats([v['timings']['total_usec'] for v in rows]),observed_usec=stats([v['total_usec'] for v in rows]),maximum_frame_usec=stats([v['maximum_frame_usec'] for v in rows]),recipe_usec=stats([v['timings']['recipe_usec'] for v in rows]),stage_usec=stats([v['timings']['stage_usec'] for v in rows]),render_parts_observer_usec=stats([v['first_visual_usec'] for v in rows]),rpc_count=stats([len({r['request_id'] for r in v['receipts']}) for v in rows]))
    entry['lower_candidate_median']=entry['candidate']['held_usec']['median']<entry['baseline']['held_usec']['median']
    cells.append(entry)
    for old,new in zip(*a):
     legacy=[{k:r.get(k) for k in keys} for r in old['receipts']]
     candidate=[{k:r.get(k) for k in keys} for r in new['receipts']]
     parity.append(dict(platform=platform,workers=worker,fps=fps,kind=kind,repeat=old['repeat'],native_attempts=len(legacy),equal=legacy==candidate))
r=dict(baseline_production='55cbc8199dee01b670536d1c6721bb82c92f0622',baseline_observer='b041f576bfb5173de692e0afeabb428787b0b12c',candidate='14f7c60c',cells=cells,history=history,reports=reports,parity=parity,exact_keys_compared=keys,all_native_attempts_equal=all(x['equal'] for x in parity),all_medians_lower=all(x['lower_candidate_median'] for x in cells),complete=len(cells)==32)
(OUT/'comparison.json').write_text(json.dumps(r,indent=2)+'\n')
print('cells',len(cells),'matched episodes',len(parity),'all exact',r['all_native_attempts_equal'],'uniform rule',r['all_medians_lower'])
print('non-lower',[(x['platform'],x['workers'],x['fps'],x['kind'],x['baseline']['held_usec']['median'],x['candidate']['held_usec']['median']) for x in cells if not x['lower_candidate_median']])
