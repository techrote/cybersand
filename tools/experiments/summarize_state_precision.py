"""Independent per-run validation/reduction; no dropped samples or pooled pairs."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics

def quantize(n,d,b):return (2*n*((1<<b)-1)+d)//(2*d)
def quantile(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def read(path):return [json.loads(line) for line in path.read_text().splitlines()]
def validate(rows,horizon,timing=False):
    meta=rows[0];ticks=rows[1:-1];final=rows[-1]
    if not meta.get('metadata') or not final.get('result'):raise ValueError('incomplete run')
    if [r['tick'] for r in ticks]!=list(range(horizon+1)):raise ValueError('missing/duplicate tick')
    for row in [ticks[0],final] if timing else [*ticks,final]:
        if row['quantity']!=meta['initial']:raise ValueError('integer conservation failure')
        if sum(row['columns'])!=row['quantity']:raise ValueError('column accounting')
        if 'cells' in row and sum(row['cells'][2::4])!=row['quantity']:raise ValueError('snapshot accounting')
    if final['visits']!=sum(t['visited'] for t in ticks[1:]):raise ValueError('work total')
    return meta,ticks,final
def behavior_run(rows,horizon=1800):
    m,t,f=validate(rows,horizon)
    maximum=m['maximum'];requested=m['requested_numerator']/m['requested_denominator']
    e=t[-1].get('events',[0]*18)
    return dict(maximum=maximum,initial=m['initial'],requested=requested,
      initial_error=m['initial']/maximum-requested,conserved=True,
      final_spread=f['spread']/maximum,spread_600=t[600]['spread']/maximum,
      spread_1200=t[1200]['spread']/maximum,columns=[x/maximum for x in f['columns']],
      final_fill=f['quantity']/maximum,occupied=f['occupied'],tiny=f['tiny'],front=f['front'],
      discharge=f['below']/maximum,arrival=f['arrival'],level=f['level'],last_change=f['last_change'],
      stable_tail=horizon-f['last_change'],rest_observed=horizon-f['last_change']>=40,
      visits=f['visits'],block_ticks=f['block_ticks'],last_active=f['last_active'],
      late_changed=sum(t[i]['semantic']!=t[i-1]['semantic'] for i in range(1201,horizon+1)),
      transferred_units=e[4],successful_transfers=e[12],water_updates=e[13],lateral_probes=e[10],
      lateral_requests=e[14],zero_requests=e[15],block_wakes=e[16],block_sleeps=e[17],
      final_semantic=f['semantic'],final_cells=f['cells'])
def timing_run(rows):
    m,t,f=validate(rows,1920,True);steady=t[121:];warmup=t[1:121]
    times=[r['tick_us'] for r in steady];total=sum(times);visits=sum(r['visited'] for r in steady)
    return dict(p50=quantile(times,.5),p95=quantile(times,.95),p99=quantile(times,.99),maximum=max(times),
      total_us=total,visited=visits,ns_per_visit=total*1000/visits if visits else None,
      block_ticks=sum(r['active'] for r in steady),startup_us=m['startup_us'],warmup_us=sum(r['tick_us'] for r in warmup),
      run_visits=f['visits'],last_active=f['last_active'],semantic=f['semantic'])
def reduce_behavior(path):
    root=path.parent;m=json.loads(path.read_text());results=[];groups={};delay={}
    for run in m['runs']:
        p=root/(run['name']+'.jsonl')
        if digest(p)!=run['sha256']:raise ValueError('raw identity mismatch')
        rows=read(p);values=behavior_run(rows)
        if 'arm' not in run:continue
        key=(run['arm'],run['fixture'],run['position'])
        # Compare every semantic/work/event tick, omitting no non-metadata fields.
        canonical=hashlib.sha256(json.dumps(rows[1:],sort_keys=True,separators=(',',':')).encode()).hexdigest()
        if key in groups:
            if groups[key]!=canonical:raise ValueError('worker/repeat/event mismatch')
        else:groups[key]=canonical
        if run['arm'] in ('m8','d4') and run['workers']==1 and run['repeat']==0:
            dkey=(run['fixture'],run['position'])
            if dkey in delay and delay[dkey]!=canonical:raise ValueError('delay equivalence')
            delay[dkey]=canonical
        results.append({**run,**values})
    table=[]
    for arm in ('m4','m6','m8','m10','l4','l6','l10','d4'):
        for fixture in ('basin48','basin96','film','support','ledge','coherent','low','delay'):
            rows=[r for r in results if r['arm']==arm and r['fixture']==fixture and r['workers']==1 and r['repeat']==0]
            if len(rows)!=5:raise ValueError('missing registered behavior arm')
            keys=['initial_error','final_spread','spread_600','spread_1200','occupied','tiny','discharge','front','arrival','level','last_change','last_active','visits','block_ticks','late_changed','successful_transfers','transferred_units','water_updates','lateral_requests','lateral_probes','zero_requests','block_wakes','block_sleeps']
            table.append(dict(arm=arm,fixture=fixture,rest_count=sum(r['rest_observed'] for r in rows),
                metrics={k:dict(min=min(r[k] for r in rows),median=statistics.median(r[k] for r in rows),max=max(r[k] for r in rows)) for k in keys}))
    return dict(processes=len(m['runs']),candidate_processes=len(results),exact=True,worker_repeat=True,delay_equivalent=True,table=table,runs=results)
def reduce_timing(path):
    root=path.parent;m=json.loads(path.read_text());runs=[];groups={}
    for r in m['runs']:
        p=root/(r['name']+'.jsonl')
        if digest(p)!=r['sha256']:raise ValueError('raw identity mismatch')
        v=timing_run(read(p));row={**r,**v};runs.append(row)
        key=(r['group'],r['candidate'],r['fixture'],r['workers'])
        groups.setdefault(key,{}).setdefault(r['pair'],{})[r['side']]=row
    table=[]
    for (group,candidate,fixture,workers),pairs in groups.items():
        if set(pairs)!=set(range(7)) or any(set(v)!={0,1} for v in pairs.values()):raise ValueError('incomplete pairs')
        metrics=['p50','p95','p99','maximum','total_us','visited','ns_per_visit','block_ticks','warmup_us','startup_us']
        control=[pairs[i][0] for i in range(7)];cand=[pairs[i][1] for i in range(7)]
        ratios={k:[b[k]/a[k] if a[k] and b[k] is not None else None for a,b in zip(control,cand)] for k in metrics}
        def median_defined(values):
            values=[v for v in values if v is not None]
            return statistics.median(values) if values else None
        table.append(dict(group=group,candidate=candidate,fixture=fixture,workers=workers,
          control={k:median_defined(r[k] for r in control) for k in metrics},
          candidate_metrics={k:median_defined(r[k] for r in cand) for k in metrics},
          paired_ratios=ratios,median_ratios={k:statistics.median([v for v in vs if v is not None]) if any(v is not None for v in vs) else None for k,vs in ratios.items()},
          p95_review_pairs=sum(b['p95']>a['p95']*1.15 for a,b in zip(control,cand))))
    return dict(processes=len(runs),table=table,runs=runs)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('kind',choices=['behavior','timing']);p.add_argument('manifest',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    result=reduce_behavior(a.manifest) if a.kind=='behavior' else reduce_timing(a.manifest)
    a.output.write_text(json.dumps(result,indent=2)+'\n');print(a.kind,result['processes'],'validated')
