#!/usr/bin/env python3
"""Independent read-only authentication/reduction of registered idle supplement."""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import math
import statistics as st

ROOT=Path('/workspace/scratch/53686e322277')
BASE=ROOT/'mat354-evidence/performance-empty-supplement'
OUT=ROOT/'mat354-independent-review/independent-idle-supplement.json'

def fact(path):
    b=Path(path).read_bytes()
    return {'path':str(path),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}

def verify(f):
    a=fact(f['path'])
    assert a['bytes']==f['bytes'] and a['sha256']==f['sha256'], (a,f)
    return a

def stats(v):
    s=sorted(v)
    return {'count':len(v),'mean_ns':st.mean(v),'median_ns':st.median(v),
            'p95_ns':s[math.ceil(.95*len(v))-1],'p99_ns':s[math.ceil(.99*len(v))-1],
            'min_ns':min(v),'max_ns':max(v),'stdev_ns':st.pstdev(v)}

plan_path=BASE/'preregistration.json';report_path=BASE/'attempt-1/supplement.json'
assert fact(plan_path)['sha256']=='de2b592d03d9bf0198ed59d48d16bbbc7df581779482bd5954414233e740cf3d'
assert fact(report_path)['sha256']=='81de78f4bc38fecd0c3e779f010409ce1cb30202d7f3d60a290781fc34b43f54'
plan=json.loads(plan_path.read_text());report=json.loads(report_path.read_text())
assert report['status']=='EXECUTED_PERFORMANCE_DISPOSITION_PENDING'
assert plan==report['plan'] and len(report['runs'])==80
verified=[verify(plan[k]) for k in ['driver','custody_helper','original_source_plan','primary_receipt','primary_audit']]
primary=json.loads(Path(plan['primary_receipt']['path']).read_text())
for name,value in plan['executables'].items():
    verified.append(verify(value));assert value==primary['builds'][name]['executable']
assert plan['created_utc']<report['started_utc']<report['finished_utc']
assert report['host']==primary['host']==plan['expected_host']
assert report['owner_performance_disposition_required'] and report['numeric_adoption_threshold'] is None
wraps={256,511,766,1021};groups=defaultdict(list);raw_count=0
expected=[]
for w in [1,4]:
    for i in range(20):
        for v in (['baseline','successor'] if i%2==0 else ['successor','baseline']):expected.append((w,i,v))
assert [(r['workers'],r['repeat'],r['variant']) for r in report['runs']]==expected
for run in report['runs']:
    proc=run['process'];assert proc['returncode']==0 and not proc['timed_out']
    for k in ['stdout','stderr']:verify(proc[k]);raw_count+=1
    assert proc['stderr']['bytes']==0
    assert proc['argv']==[plan['executables'][run['variant']]['path'],'--bench','empty',str(run['workers']),'0']
    lines=[json.loads(l) for l in Path(proc['stdout']['path']).read_text().splitlines()]
    assert len(lines)==1026
    meta,rows,end=lines[0],lines[1:-1],lines[-1]
    assert meta['workers']==run['workers'] and meta['diagnostics'] is False and meta['workload']=='empty'
    assert meta['warmup_ticks']==32 and meta['ticks']==1024 and meta['resident_before']==4202496
    assert meta['cpu_clock_ticks_per_second']==1000000 and meta['cpu_clock_available']
    zero=['jobs','visited_cells','active_blocks','observed_workers','chunk_allocations','temperature_allocations',
          'observed_deadline_changes','first_source_due','first_source_material','first_source_a']
    for i,row in enumerate(rows,1):
        assert row['tick']==i and row['type']=='h1_benchmark_tick'
        assert all(row[k]==0 for k in zero) and row['resident_cell_bytes']==4202496
        assert row['kernel_entries_world'] is None and row['glass_conversions'] is None
    assert end['physical_hash']=='5e5b53ab4b8ddf62' and end['tuple_hash']=='cbf29ce484222325'
    assert end['tick_ns_total']==sum(r['tick_ns'] for r in rows)
    assert end['cpu_clock_ticks_total']==sum(r['cpu_clock_ticks'] for r in rows)
    derived={}
    windows={'all':rows,'tail_769_1024':rows[768:],
             'epoch_wrap':[r for r in rows if r['tick'] in wraps],
             'non_epoch_wrap':[r for r in rows if r['tick'] not in wraps]}
    for name,selected in windows.items():
        derived[name]={}
        for clock,values in [('wall',[r['tick_ns'] for r in selected]),('cpu',[r['cpu_clock_ticks']*1000 for r in selected])]:
            calc=stats(values);reference=run['observation']['timing'][name][clock]
            assert calc.keys()==reference.keys()
            assert all(math.isclose(calc[k],reference[k],rel_tol=1e-12,abs_tol=1e-9) for k in calc)
            derived[name][clock]=calc
    groups[(run['workers'],run['variant'])].append({'repeat':run['repeat'],'timing':derived,'stdout':proc['stdout'],
        'top_ticks':[{k:r[k] for k in ['tick','tick_ns','cpu_clock_ticks']} for r in sorted(rows,key=lambda r:r['tick_ns'],reverse=True)[:5]]})

comparisons=[]
for w in [1,4]:
    result={'workers':w,'cohorts':{},'deltas':{}}
    for variant in ['baseline','successor']:
        runs=groups[(w,variant)];assert len(runs)==20
        result['cohorts'][variant]={}
        for window in ['all','tail_769_1024','epoch_wrap','non_epoch_wrap']:
            result['cohorts'][variant][window]={}
            for clock in ['wall','cpu']:
                values=[r['timing'][window][clock] for r in runs]
                result['cohorts'][variant][window][clock]={
                    'mean_ns':st.mean(v['mean_ns'] for v in values),
                    'median_of_run_medians_ns':st.median(v['median_ns'] for v in values),
                    'p95_median_ns':st.median(v['p95_ns'] for v in values),
                    'p99_median_ns':st.median(v['p99_ns'] for v in values),
                    'mean_run_sd_ns':st.pstdev(v['mean_ns'] for v in values),
                    'max_ns':max(v['max_ns'] for v in values)}
    for window in ['all','tail_769_1024','epoch_wrap','non_epoch_wrap']:
        result['deltas'][window]={}
        for clock in ['wall','cpu']:
            old=result['cohorts']['baseline'][window][clock]['mean_ns']
            new=result['cohorts']['successor'][window][clock]['mean_ns']
            deltas=[b['timing'][window][clock]['mean_ns']-a['timing'][window][clock]['mean_ns']
                    for a,b in zip(groups[(w,'baseline')],groups[(w,'successor')])]
            result['deltas'][window][clock]={'mean_delta_ns':new-old,'ratio':new/old,
                'positive_pairs':sum(d>0 for d in deltas),'paired_deltas_ns':deltas,'paired_delta_sd_ns':st.pstdev(deltas)}
    original=next(c for c in report['comparisons'] if c['workers']==w)
    for window in result['deltas']:
        for clock in result['deltas'][window]:
            assert math.isclose(result['deltas'][window][clock]['ratio'],original['differences'][window][clock]['mean_ratio'],rel_tol=1e-12)
    comparisons.append(result)
result={'schema':'mat354.independent.idle-supplement-review.v1',
        'status':'AUTHENTICATED_COMPLETE_SEPARATE_SUPPLEMENT_PERFORMANCE_DISPOSITION_PENDING',
        'report':fact(report_path),'plan':fact(plan_path),'reproducer':fact(Path(__file__)),
        'source_and_driver_facts':verified,'source_head':'9d218bb179e72e9fa68b755d82680dbd739fb85e',
        'processes':80,'raw_output_facts_authenticated':raw_count,'tick_rows':81920,
        'zero_jobs_visits_active_blocks_allocations_deadlines':True,'resident_growth':0,
        'comparisons':comparisons,'runs':[{'workers':w,'variant':v,'rows':rs} for (w,v),rs in groups.items()],
        'limitations':['Primary samples and interpretations remain unchanged; no exclusions.',
            'No owner performance acceptance or final GO is supplied.',
            'Water PressureFlow timing observation is unaddressed by this empty-only supplement.',
            'Unchanged source and zero simulation jobs do not identify the cause of CPU and timing variation.',
            'Shared-host scheduling/cache/frequency and complete heap/RSS remain unmeasured.']}
assert not OUT.exists()
OUT.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(json.dumps({'output':fact(OUT),'status':result['status'],'comparisons':comparisons},indent=2))
