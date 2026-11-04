#!/usr/bin/env python3
"""Independent raw reduction; no imports from candidate tools or reducers."""
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import math
import statistics as st

ROOT = Path('/workspace/scratch/53686e322277')
INPUT = ROOT / 'mat354-evidence/performance-attempt-1/qualification.json'
OUT = ROOT / 'mat354-independent-review/independent-primary-performance.json'

def fact(p):
    b = Path(p).read_bytes()
    return {'path': str(p), 'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()}

def check_fact(f):
    actual = fact(f['path'])
    assert all(actual[k] == f[k] for k in ('bytes', 'sha256')), (f, actual)
    return actual

def stats(values):
    ordered = sorted(values)
    return {'count': len(values), 'mean_ns': st.mean(values), 'median_ns': st.median(values),
            'p95_ns': ordered[math.ceil(.95 * len(values))-1],
            'p99_ns': ordered[math.ceil(.99 * len(values))-1],
            'max_ns': max(values), 'stdev_ns': st.pstdev(values)}

def equality_stats(actual, expected):
    assert actual.keys() == expected.keys()
    for k in actual:
        assert math.isclose(actual[k], expected[k], rel_tol=1e-12, abs_tol=1e-9), (k, actual, expected)

def digest(value):
    return hashlib.sha256(json.dumps(value, separators=(',', ':'), sort_keys=True).encode()).hexdigest()

report = json.loads(INPUT.read_text())
assert report['status'] == 'EXECUTED' and report['mode'] == 'performance'
assert report['sources']['successor']['commit'] == '9d218bb179e72e9fa68b755d82680dbd739fb85e'
plan = report['plan']
assert plan['benchmark_paired_repeats'] == 5 and plan['benchmark_ticks'] == 1024
assert plan['benchmark_workers'] == [1, 4]
assert len(report['runs']) == 336
expected_order = []
for workers in [1,4]:
    for workload in plan['benchmark_workloads']:
        for repeat in range(5):
            for variant in (('baseline','successor') if repeat % 2 == 0 else ('successor','baseline')):
                expected_order.append((workload,workers,repeat,variant,False))
        for variant in ('baseline','successor'):
            expected_order.append((workload,workers,None,variant,True))
assert [(r['workload'],r['workers'],r.get('repeat'),r['variant'],r.get('diagnostic_only',False))
        for r in report['runs']] == expected_order

checks = [check_fact(report['build_report']), check_fact(report['plan_file']), check_fact(report['compiler'])]
raw_checks = []
cohorts = defaultdict(list)
work = defaultdict(list)
per_run = []
diagnostics = []
epoch_ticks = {256,511,766,1021}
recorded_state = ('jobs','visited_cells','active_blocks','chunk_allocations','temperature_allocations',
                  'resident_cell_bytes','observed_deadline_changes','first_source_due',
                  'first_source_material','first_source_a')
for run in report['runs']:
    process = run['process']
    assert process['returncode'] == 0 and not process['timed_out']
    raw_checks.extend(check_fact(process[name]) for name in ('stdout','stderr'))
    assert process['stderr']['bytes'] == 0
    lines = [json.loads(s) for s in Path(process['stdout']['path']).read_text().splitlines()]
    assert len(lines) == 1026
    meta, rows, end = lines[0], lines[1:-1], lines[-1]
    diag = run.get('diagnostic_only',False)
    assert meta['type'] == 'h1_benchmark_metadata' and end['type'] == 'h1_benchmark_summary'
    assert meta['ticks'] == 1024 and meta['warmup_ticks'] == 32 and meta['warmup_world'] == 'separate throwaway'
    assert (meta['workload'],meta['workers'],meta['diagnostics']) == (run['workload'],run['workers'],diag)
    assert all(r['type'] == 'h1_benchmark_tick' and r['tick'] == i for i,r in enumerate(rows,1))
    assert meta['cpu_clock_available'] and meta['cpu_clock_ticks_per_second'] == 1000000
    assert all(r['resident_cell_bytes'] == meta['resident_before'] for r in rows)
    assert end['resident_after'] == meta['resident_before']
    assert all(r['chunk_allocations'] == r['temperature_allocations'] == 0 for r in rows)
    assert end['chunk_and_temperature_allocations'] == 0
    assert all(0 <= r['observed_workers'] <= run['workers'] for r in rows)
    assert end['jobs'] == sum(r['jobs'] for r in rows)
    assert end['visited_cells'] == sum(r['visited_cells'] for r in rows)
    assert end['tick_ns_total'] == sum(r['tick_ns'] for r in rows)
    assert end['cpu_clock_ticks_total'] == sum(r['cpu_clock_ticks'] for r in rows)
    assert end['tail_769_1024_jobs'] == sum(r['jobs'] for r in rows[768:])
    assert end['max_workers_observed'] == max(r['observed_workers'] for r in rows)
    wall = [r['tick_ns'] for r in rows]
    cpu = [r['cpu_clock_ticks'] * 1000 for r in rows]
    equality_stats(stats(wall), run['observation']['all_ticks'])
    equality_stats(stats(cpu), run['observation']['cpu_all_ticks'])
    equality_stats(stats(wall[768:]), run['observation']['tail_769_1024'])
    equality_stats(stats(cpu[768:]), run['observation']['cpu_tail_769_1024'])
    first = next((i for i,r in enumerate(rows) if r['first_source_material'] == 35), None)
    assert run['observation']['first_source_glass_tick'] == (first + 1 if first is not None else None)
    if first is not None:
        assert sum(wall[:first+1]) == run['observation']['first_source_cumulative_timed_tick_ns_to_glass']
        assert rows[first]['elapsed_to_observation_ns'] == run['observation']['first_source_elapsed_wall_ns_to_glass']
    fields = {k:run[k] for k in ('workload','workers','variant')}
    fields.update(repeat=run.get('repeat'),diagnostic=diag)
    sig = digest([[r[k] for k in recorded_state] for r in rows])
    work[(run['variant'],run['workload'])].append({'signature':sig,'physical':end['physical_hash'],
                                                 'tuple':end['tuple_hash']})
    fields.update(wall=stats(wall),cpu=stats(cpu),tail_wall=stats(wall[768:]),
                  non_epoch_wall=stats([r['tick_ns'] for r in rows if r['tick'] not in epoch_ticks]),
                  epoch_wall=stats([r['tick_ns'] for r in rows if r['tick'] in epoch_ticks]),
                  jobs=end['jobs'],visited=end['visited_cells'],claimants=end['max_workers_observed'],
                  last_job=max((r['tick'] for r in rows if r['jobs']),default=0),
                  tail_jobs=sum(r['jobs'] for r in rows[768:]),
                  tail_active_blocks=sum(r['active_blocks'] for r in rows[768:]),
                  tail_visited=sum(r['visited_cells'] for r in rows[768:]),
                  deadline_changes=sum(r['observed_deadline_changes'] for r in rows),
                  final_molten=end['final_molten'],final_glass=end['final_glass'],
                  first_glass_tick=first+1 if first is not None else None,
                  cumulative_tick_to_glass_ns=sum(wall[:first+1]) if first is not None else None,
                  elapsed_wall_to_glass_ns=rows[first]['elapsed_to_observation_ns'] if first is not None else None,
                  largest_ticks=[{k:r[k] for k in ('tick','tick_ns','cpu_clock_ticks','jobs','visited_cells')}
                                 for r in sorted(rows,key=lambda t:t['tick_ns'],reverse=True)[:5]],
                  work_signature=sig,raw_stdout=process['stdout'])
    if diag:
        assert end['kernel_entries_world'] == sum(r['kernel_entries_world'] for r in rows)
        assert end['glass_conversions'] == sum(r['glass_conversions'] for r in rows)
        fields.update(kernel_entries=end['kernel_entries_world'],conversions=end['glass_conversions'],
                      conversion_ticks=[{'tick':r['tick'],'count':r['glass_conversions']}
                                        for r in rows if r['glass_conversions']])
        if run['workload'] == 'cold1':
            fields['due_lane_entries'] = sum(r['kernel_entries_world'] for r in rows if r['tick'] % 4 == 0)
            fields['off_lane_entries'] = sum(r['kernel_entries_world'] for r in rows if r['tick'] % 4 != 0)
        diagnostics.append(fields)
    else:
        assert all(r['kernel_entries_world'] is None and r['glass_conversions'] is None for r in rows)
        per_run.append(fields)
        cohorts[(run['workload'],run['workers'],run['variant'])].append(fields)

assert len(raw_checks) == 672 and len(per_run) == 280 and len(diagnostics) == 56
for key,items in work.items():
    assert len(items) == 12 and all(v == items[0] for v in items), key
for name in plan['benchmark_exact_control_workloads']:
    assert work[('baseline',name)][0] == work[('successor',name)][0], name

comparisons = []
for workers in [1,4]:
    for workload in plan['benchmark_workloads']:
        a = sorted(cohorts[(workload,workers,'baseline')],key=lambda r:r['repeat'])
        b = sorted(cohorts[(workload,workers,'successor')],key=lambda r:r['repeat'])
        aggregates = {}
        for name,rs in [('baseline',a),('successor',b)]:
            aggregates[name] = {'wall_mean_ns':st.mean(r['wall']['mean_ns'] for r in rs),
                                'wall_median_of_run_medians_ns':st.median(r['wall']['median_ns'] for r in rs),
                                'wall_run_median_range_ns':[min(r['wall']['median_ns'] for r in rs),max(r['wall']['median_ns'] for r in rs)],
                                'wall_run_mean_sd_ns':st.pstdev(r['wall']['mean_ns'] for r in rs),
                                'wall_p95_median_ns':st.median(r['wall']['p95_ns'] for r in rs),
                                'wall_p99_median_ns':st.median(r['wall']['p99_ns'] for r in rs),
                                'wall_max_ns':max(r['wall']['max_ns'] for r in rs),
                                'cpu_mean_ns':st.mean(r['cpu']['mean_ns'] for r in rs),
                                'tail_median_ns':st.median(r['tail_wall']['median_ns'] for r in rs),
                                'epoch_mean_ns':st.mean(r['epoch_wall']['mean_ns'] for r in rs),
                                'non_epoch_mean_ns':st.mean(r['non_epoch_wall']['mean_ns'] for r in rs),
                                'jobs':rs[0]['jobs'],'visited':rs[0]['visited'],
                                'claimants':max(r['claimants'] for r in rs),'last_job':rs[0]['last_job'],
                                'tail_jobs':rs[0]['tail_jobs'],'tail_active_blocks':rs[0]['tail_active_blocks'],
                                'tail_visited':rs[0]['tail_visited'],'deadline_changes':rs[0]['deadline_changes'],
                                'final_molten':rs[0]['final_molten'],'final_glass':rs[0]['final_glass'],
                                'first_glass_tick':rs[0]['first_glass_tick'],
                                'elapsed_wall_to_glass_mean_ns':st.mean(r['elapsed_wall_to_glass_ns'] for r in rs) if rs[0]['first_glass_tick'] else None}
        old,new=aggregates['baseline'],aggregates['successor']
        comp={'workload':workload,'workers':workers,**aggregates,
              'wall_ratio':new['wall_mean_ns']/old['wall_mean_ns'],
              'wall_delta_ns':new['wall_mean_ns']-old['wall_mean_ns'],
              'cpu_ratio':new['cpu_mean_ns']/old['cpu_mean_ns'],
              'paired_run_mean_deltas_ns':[rb['wall']['mean_ns']-ra['wall']['mean_ns'] for ra,rb in zip(a,b)],
              'paired_run_median_deltas_ns':[rb['wall']['median_ns']-ra['wall']['median_ns'] for ra,rb in zip(a,b)],
              'epoch_contribution_to_mean_delta_ns':(new['epoch_mean_ns']-old['epoch_mean_ns'])*4/1024,
              'non_epoch_contribution_to_mean_delta_ns':(new['non_epoch_mean_ns']-old['non_epoch_mean_ns'])*1020/1024}
        original=next(c for c in report['performance']['comparisons'] if (c['workload'],c['workers'])==(workload,workers))
        assert math.isclose(comp['wall_ratio'],original['mean_tick_ratio'],rel_tol=1e-12)
        comparisons.append(comp)

result={'schema':'mat354.independent.performance.raw-review.v1',
        'created_utc':datetime.now(timezone.utc).isoformat(),
        'status':'RAW_CUSTODY_ARITHMETIC_AND_FINITE_WORK_PASS_PERFORMANCE_DISPOSITION_PENDING',
        'reviewer':'/root/independent_review; read-only source and evidence review; no candidate reducer imports',
        'qualification':fact(INPUT),'reproducer':fact(Path(__file__)),
        'source_head':report['sources']['successor']['commit'],'host':report['host'],
        'raw_facts_authenticated':len(raw_checks),'primary_runs':len(per_run),'diagnostic_runs':len(diagnostics),
        'primary_timed_ticks':len(per_run)*1024,'diagnostic_trace_ticks':len(diagnostics)*1024,
        'recorded_work_trajectories_equal_within_source':len(work),
        'exact_old_new_control_trajectories':plan['benchmark_exact_control_workloads'],
        'all_tick_chunk_temperature_allocations':0,'all_tick_resident_capacity_growth':0,
        'source_config_parallel_job_threshold':1,'production_default_parallel_job_threshold':8,
        'cpu_clock_nominal_resolution_ns':1000,'epoch_wrap_ticks':sorted(epoch_ticks),
        'comparisons':comparisons,'per_run':per_run,'diagnostic_runs_detail':diagnostics,
        'limitations':[
            'No numerical H1 adoption threshold exists; explicit owner performance disposition remains required.',
            'Empty-world mean/CPU increases and Water PressureFlow w1 variation remain unresolved; none classified as benign noise.',
            'Configured-four singleton tests force threshold1 and observe one claimant; they are not four-way scaling proofs.',
            'Worker counts were measured in separate time windows; ratios do not establish isolated causal scaling.',
            'All primary outliers and epoch-wrap ticks are retained. Subdivision is explanatory only.',
            'Process CPU includes worker CPU plus surrounding clock calls and has 1000ns nominal resolution.',
            'Chunk/temperature allocation counts and resident_cell_bytes are not complete heap/RSS measurement.',
            'Work trajectories expose scheduler/material-source observations, not every cell physical state each tick.',
            'Diagnostic timings are never pooled with the primary timings; multicell entries are aggregate.',
            'No adoption, runtime, CI, saved-state migration, or final independent GO is supplied by this review.'
        ]}
assert not OUT.exists(), 'review output already exists; do not overwrite'
OUT.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(json.dumps({'output':fact(OUT),'status':result['status'],'raw_facts_authenticated':len(raw_checks),
                  'primary_runs':len(per_run),'diagnostic_runs':len(diagnostics)},indent=2))
