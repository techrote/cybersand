#!/usr/bin/env python3
"""Bounded #354-B paired qualification; never overwrites a prior attempt.

The unchanged Phase A custody/reduction helpers are reused, not relaxed. New
source contracts, fixture selection and timing cohorts live in a separate plan.
No result from this apparatus grants runtime adoption or a performance waiver.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
PLAN = 'native/tests/fixtures/material_liveness_h1_v1.json'
APPARATUS = 'native/tests/test_mat354_h1.cpp'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


run = module('mat354_frozen_run', ROOT / 'tools/material_liveness/run.py')
reduce = module('mat354_frozen_reduce', ROOT / 'tools/material_liveness/reduce.py')


def require(condition, reason):
    if not condition:
        raise run.EvidenceError(reason)


def lf_sha(path):
    return hashlib.sha256(Path(path).read_bytes().replace(b'\r\n', b'\n')).hexdigest()


def source_identity(root, variant, plan):
    root = root.resolve()
    head = run.git(root, 'rev-parse', 'HEAD')
    tree = run.git(root, 'rev-parse', 'HEAD^{tree}')
    status = run.git(root, 'status', '--porcelain=v1', '--untracked-files=all')
    require(not status, f'{variant} checkout is dirty; source-qualified qualification refused: {status}')
    if variant == 'baseline':
        require(head == plan['baseline_commit'] and tree == plan['baseline_tree'], 'wrong untouched baseline')
    else:
        run.git(root, 'merge-base', '--is-ancestor', plan['successor_source_commit'], head)
        require(run.git(root, 'rev-parse', plan['successor_source_commit']+'^{tree}') == plan['successor_source_tree'],
                'wrong source-only successor receipt tree')
    require(lf_sha(root / 'native/src/world.cpp') == plan[variant+'_world_lf_sha256'], 'wrong World source identity')
    guard = run.protected_check(root)
    paths = run.git(root, 'ls-files', 'native/src', 'native/include', 'native/tests/material_liveness_probe.cpp').splitlines()
    inputs = [run.fact(root / path, root) for path in paths if (root / path).is_file()]
    check = run.committed_input_check(root, inputs, head)
    require(check['status'] == 'PASS', variant+': raw input bytes differ from Git')
    return {'root': str(root), 'commit': head, 'tree': tree, 'git_status': status,
            'world_lf_sha256': lf_sha(root/'native/src/world.cpp'), 'protected_guard': guard,
            'inputs': inputs, 'inputs_sha256': run.canonical_sha(inputs), 'committed_input_check': check}


def apparatus_identity(root):
    paths = [APPARATUS, PLAN, 'tools/material_cooling_h1/qualify.py',
             'tools/material_liveness/run.py', 'tools/material_liveness/reduce.py',
             'native/tests/fixtures/material_liveness_campaign_v1.json',
             'docs/audits/2026-11-04-mat354-h1-preregistration.md']
    facts = [run.fact(root / p, root) for p in paths]
    head = run.git(root, 'rev-parse', 'HEAD')
    require(run.committed_input_check(root, facts, head)['status']=='PASS','apparatus differs from committed source')
    return {'commit': head, 'inputs': facts, 'sha256': run.canonical_sha(facts)}


def build(root, variant, out, compiler, plan, deadline):
    out.mkdir()
    info = {'variant': variant, 'steps': []}
    flags = run.compiler_flags('normal', os.name)
    flags = [f for f in flags if f not in ('-O2','-g')] + ['-O3','-DNDEBUG', '-I'+str(root/'native/include'), '-I'+str(root/'native/tests')]
    info['flags'] = flags
    sources = [ROOT/APPARATUS] + [root/p for p in run.DEFAULT_SOURCES[1:]]
    objects=[]
    build_deadline=time.monotonic()+plan['build_timeout_seconds']
    for i, source in enumerate(sources):
        obj=out/f'input-{i}.o';dep=out/f'input-{i}.d'
        command=[compiler,*flags,'-MMD','-MF',str(dep),'-c',str(source),'-o',str(obj)]
        result=run.process(command,out,out/f'compile-{i}',run.remaining_budget(build_deadline,deadline))
        info['steps'].append(result)
        run.write_json(out/'build.json',info)
        require(result['returncode']==0 and not result['timed_out'],variant+': compile failed; retained original outputs')
        objects.append(str(obj))
    executable=out/('mat354_h1.exe' if os.name=='nt' else 'mat354_h1')
    result=run.process([compiler,*flags,*objects,'-o',str(executable)],out,out/'link',run.remaining_budget(build_deadline,deadline))
    info['steps'].append(result)
    run.write_json(out/'build.json',info)
    require(result['returncode']==0 and not result['timed_out'],variant+': link failed')
    info['executable']=run.fact(executable)
    info['dependencies']=run.actual_dependencies(root,sorted(out.glob('input-*.d')),out)
    require(any(Path(x['path']).name=='test_mat354_h1.cpp' for x in info['dependencies']), 'shared harness absent from compiler dependency map')
    info['dependency_files']=[run.fact(p) for p in sorted(out.glob('input-*.d'))]
    run.write_json(out/'build.json',info)
    return info


def execute(build_info, argv, prefix, deadline, plan):
    executable=build_info['executable']
    result=run.process([executable['path'],*argv],ROOT,prefix,
        min(plan['case_timeout_seconds'],run.remaining_budget(deadline)),
        generated_executable=executable,artifact_directory=Path(executable['path']).parent)
    run.write_json(Path(str(prefix)+'.process.json'),result)
    require(result['returncode']==0 and not result['timed_out'], f'process failed: {prefix.name}; original raw files retained')
    # Both retained byte streams must still authenticate before parsing.
    data=reduce.raw_file(result['stdout']);reduce.raw_file(result['stderr'])
    rows=reduce.read_rows(data)
    return result,rows


def correctness(report, plan, out, deadline):
    builds=report['builds']; report['runs']=[]
    regression_identity=None
    for repeat in range(plan['new_regression_repeats']):
        result,rows=execute(builds['successor'],['--regress'],out/f'h1-regress-r{repeat}',deadline,plan)
        require(rows[-1].get('type')=='h1_regression_summary' and rows[-1].get('status')=='PASS','missing H1 regression completion')
        completed=[r['case'] for r in rows if r['type']=='h1_case']
        require(completed==plan['new_regression_expected_cases'],'new regression omitted/reordered an admitted case')
        identity=[(r['case'],r['replica'],r['tick'],r['physical_hash'],r['tuple_hash']) for r in rows if r['type']=='h1_tick']
        require(identity,'regression emitted no physical trajectory')
        if regression_identity is None:regression_identity=identity
        else:require(regression_identity==identity,'new regression repeats differ in complete physical trajectories')
        report['runs'].append({'kind':'h1-regression','repeat':repeat,'process':result,
            'cases':completed,'physical_trajectory_sha256':run.canonical_sha(identity)})
        run.write_json(out/'qualification.json',report)
    historical=run.load_json(ROOT/'native/tests/fixtures/material_liveness_campaign_v1.json')
    cases={c['id']:c for c in run.validate_plan(historical)}
    require(len(plan['phase_a_case_ids'])==len(set(plan['phase_a_case_ids'])),'duplicate frozen subset case')
    groups=defaultdict(dict);differences=[];control_count=0;observed=defaultdict(int);pending=[]
    for case_id in plan['phase_a_case_ids']:
        case=cases[case_id];by_source={}
        for variant in ('baseline','successor'):
            result,rows=execute(builds[variant],case['argv'],out/(variant+'-'+case_id),deadline,plan)
            result['id']=case_id
            observation,hashes=reduce.reduce_case(result,case)
            group=reduce.physical_group(case)
            prior=groups[variant].setdefault(group,hashes)
            require(prior==hashes,variant+': exact one/four/repeat trajectory mismatch')
            if case['fixture'].startswith('distributed_') and case['workers']==4:
                require(observation['workers_observed_max']>1,variant+': distributed fixture did not observe multiple claimants')
                observed[variant]=max(observed[variant],observation['workers_observed_max'])
            report['runs'].append({'kind':'phase-a-reuse','variant':variant,'process':result,'reduction':observation})
            by_source[variant]=rows[1:-1]
        old,new=by_source['baseline'],by_source['successor']
        changed=[i+1 for i,(a,b) in enumerate(zip(old,new)) if a['physical_hash']!=b['physical_hash']]
        tuples=[i+1 for i,(a,b) in enumerate(zip(old,new)) if a['tuple_hash']!=b['tuple_hash']]
        category=comparison_category(case,plan['comparison_oracles'])
        causal=None
        if category=='exact':
            require(not changed,'unadmitted physical trajectory change in '+case_id);control_count+=1
        elif category=='tuples':
            require(not tuples,'preserved H2/awake thermal trajectory changed in '+case_id)
        elif category=='singleton':
            singleton_law(old,case,False);singleton_law(new,case,True)
            for a,b in zip(old,new):
                require(a['temperature']==b['temperature'] and a['state_b']==b['state_b'] and a['mobility_draw']==b['mobility_draw'],
                        'unadmitted temperature/compact state/RNG change in '+case_id)
                if (a['material'],a['state_a'])==(b['material'],b['state_a']):
                    require(a['tuple_hash']==b['tuple_hash'],'unexplained non-source tuple change in '+case_id)
            if tuples:
                i=tuples[0]-1;a,b=old[i],new[i]
                require((a['material_before'],a['state_a_before'])==(b['material_before'],b['state_a_before']) and
                        a['kernel_visits']==0 and b['kernel_visits']==1 and b['cooling_due'] and
                        0<b['block_before']['due']<=b['world_tick'],
                        'first tuple divergence is not restored due-lane execution after finite deadline in '+case_id)
                causal={'first_restored_owner_step':i+1,'world_tick':b['world_tick'],
                        'retained_deadline':b['block_before']['due'],'baseline_kernel_visits':0,'successor_kernel_visits':1}
        elif category=='review':
            if changed:pending.append({'id':case_id,'reason':'aggregate/edit trajectory needs independent per-source causal review; no blanket MoltenGlass acceptance'})
        differences.append({'id':case_id,'first_physical_difference':changed[0] if changed else None,
            'physical_difference_count':len(changed),'first_tuple_difference':tuples[0] if tuples else None,
            'tuple_difference_count':len(tuples),'oracle_category':category,'first_divergence_proof':causal})
        run.write_json(out/'qualification.json',report)
    path=out/'baseline-sleeping.cyps'
    export,export_rows=execute(builds['baseline'],['--snapshot-out',str(path)],out/'baseline-snapshot-export',deadline,plan)
    imported,import_rows=execute(builds['successor'],['--snapshot-in',str(path)],out/'successor-historical-snapshot-import',deadline,plan)
    import_observation=import_rows[-1]
    require(import_observation.get('type')=='h1_cross_source_import','missing cross-source import observation')
    report['cross_source_save']={'snapshot':run.fact(path),'export':export,'import':imported,'observation':import_observation,
        'scope':'existing format observation, not migration or strict replay acceptance'}
    report['correctness']={'unrelated_exact_control_cases':control_count,'differences':differences,
        'causal_disposition':'REVIEW_REQUIRED' if pending else 'PASS','pending_causal_reviews':pending,
        'actual_distributed_workers':dict(observed),'historical_import_requires_owner_disposition':
        bool(import_observation.get('accepted') and import_observation.get('unaltered_material')==36)}


def comparison_category(case, oracles):
    fixture=case['fixture']
    if fixture in oracles['exact_fixtures']:return 'exact'
    if fixture in oracles['tuple_equal_fixtures'] or (case['quiet']==1024 and fixture in oracles['molten_fixtures']):return 'tuples'
    if fixture in oracles['pending_fixtures'] or case['variant'] in oracles['pending_variants'].get(fixture,[]):return 'review'
    if fixture in oracles['singleton_fixtures']:return 'singleton'
    raise run.EvidenceError('case has no explicitly registered comparison oracle: '+case['id'])


def singleton_law(rows,case,require_obligations):
    previous=None
    for index,row in enumerate(rows,1):
        before=(row['material_before'],row['state_a_before'])
        after=(row['material'],row['state_a'])
        cause=row['wake_cause']
        if cause in ('source_edit','reset'):
            require(before==(36,4),case['id']+': source edit/reset changed its registered input')
        elif cause=='source_remove':
            require(before==(1,0),case['id']+': source removal changed its registered input')
        elif previous is not None:
            require(before==previous,case['id']+': unregistered between-tick source mutation')
        visits=row['kernel_visits'];require(visits in (0,1),case['id']+': telemetry is not singleton')
        excluded=case['variant']=='region' and 9<=index<=16
        admitted=not (row['paused'] or row['source_masked'] or excluded)
        expected=before
        if before[0]==36:
            if require_obligations and admitted and row['cooling_due']:
                require(visits==1,case['id']+': required actual thermal lane omitted')
            if not admitted:require(visits==0,case['id']+': masked/paused/excluded source executed')
            if visits and row['cooling_due']:
                cooling=180 if row['hot_neighbor_before'] else max(0,before[1]-1)
                expected=(36,cooling) if cooling else (35,0)
            if require_obligations and visits and admitted and not row['cooling_due']:
                elapsed=(row['world_tick']%4+4-row['thermal_phase'])%4
                require(row['block_after']['due']==row['world_tick']+4-elapsed,
                        case['id']+': unchanged cold source lacks its exact strictly future lane')
        else:
            require(visits==0,case['id']+': obsolete non-Molten source counted as a kernel entry')
        require(after==expected,case['id']+': source transition violates the unchanged thermal law/lane')
        previous=after


def percentile(values,q):
    return sorted(values)[max(0,math.ceil(len(values)*q)-1)]


def timings(values):
    return {'count':len(values),'mean_ns':statistics.mean(values),'median_ns':statistics.median(values),
        'p95_ns':percentile(values,.95),'p99_ns':percentile(values,.99),'max_ns':max(values),
        'stdev_ns':statistics.pstdev(values)}


def benchmark_observation(rows,workload,workers,diagnostics,plan):
    require(len(rows)==plan['benchmark_ticks']+2,'incomplete benchmark rows')
    meta,last=rows[0],rows[-1];ticks=rows[1:-1]
    require(meta.get('type')=='h1_benchmark_metadata' and last.get('type')=='h1_benchmark_summary','missing benchmark endpoints')
    require(meta['workload']==workload and meta['workers']==workers and meta['diagnostics']==diagnostics,'benchmark settings mismatch')
    require(meta['ticks']==plan['benchmark_ticks'] and meta['warmup_ticks']==plan['benchmark_warmup_ticks'],'frozen timing window changed')
    for i,row in enumerate(ticks,1):
        require(row.get('type')=='h1_benchmark_tick' and row.get('tick')==i,'noncontiguous benchmark ticks')
        require(row['observed_workers']<=workers,'claimants exceed configured capacity')
        require(row['resident_cell_bytes']==meta['resident_before'],'resident memory grew during measured ticks')
    require(last['jobs']==sum(t['jobs'] for t in ticks),'summary jobs mismatch')
    require(last['visited_cells']==sum(t['visited_cells'] for t in ticks),'summary visits mismatch')
    require(last['tick_ns_total']==sum(t['tick_ns'] for t in ticks),'summary timing mismatch')
    require(last['chunk_and_temperature_allocations']==0,'measured tick allocated chunks/temperature storage')
    require(meta['cpu_clock_ticks_per_second']>0,'invalid CPU clock resolution')
    cpu_resolution=1_000_000_000/meta['cpu_clock_ticks_per_second']
    return {'metadata':meta,'summary':last,'all_ticks':timings([t['tick_ns'] for t in ticks]),
        'active_ticks':timings([t['tick_ns'] for t in ticks if t['jobs']]) if any(t['jobs'] for t in ticks) else None,
        'tail_769_1024':timings([t['tick_ns'] for t in ticks[768:]]),
        'cpu_clock_resolution_ns':cpu_resolution if meta['cpu_clock_available'] else None,
        'cpu_all_ticks':timings([t['cpu_clock_ticks']*cpu_resolution for t in ticks]) if meta['cpu_clock_available'] else None,
        'cpu_tail_769_1024':timings([t['cpu_clock_ticks']*cpu_resolution for t in ticks[768:]]) if meta['cpu_clock_available'] else None,
        'first_source_glass_tick':next((t['tick'] for t in ticks if t['first_source_material']==35),None),
        'first_source_cumulative_timed_tick_ns_to_glass':sum(t['tick_ns'] for t in ticks[:next((i+1 for i,t in enumerate(ticks) if t['first_source_material']==35),0)]) or None,
        'first_source_elapsed_wall_ns_to_glass':next((t['elapsed_to_observation_ns'] for t in ticks if t['first_source_material']==35),None)}


def performance(report,plan,out,deadline):
    report['runs']=[];cohorts=defaultdict(lambda:defaultdict(list));identities=defaultdict(dict)
    for workers in plan['benchmark_workers']:
        for workload in plan['benchmark_workloads']:
            for repeat in range(plan['benchmark_paired_repeats']):
                order=('baseline','successor') if repeat%2==0 else ('successor','baseline')
                for variant in order:
                    result,rows=execute(report['builds'][variant],['--bench',workload,str(workers),'0'],
                        out/f'{workload}-w{workers}-r{repeat}-{variant}',deadline,plan)
                    observation=benchmark_observation(rows,workload,workers,False,plan)
                    summary=observation['summary']
                    physical=summary['physical_hash'];key=(variant,workload)
                    previous=identities[key].setdefault('physical',physical)
                    require(previous==physical,'benchmark workers/repeats changed physical identity')
                    previous_tuple=identities[key].setdefault('tuple',summary['tuple_hash'])
                    require(previous_tuple==summary['tuple_hash'],'benchmark workers/repeats changed physical tuples')
                    if workload in {'empty','inert','hot180'} or (variant=='successor' and workload.startswith('cold')):
                        require(summary['tail_769_1024_jobs']==0,workload+': unwanted permanent tail activity')
                    if variant=='successor' and workload.startswith('cold'):
                        require(summary['final_molten']==0 and summary['final_glass']==observation['metadata']['initial_molten'],
                                workload+': finite cooling did not finish')
                    if workers==4 and workload in {'cold16','cold64','mixed'}:
                        require(summary['max_workers_observed']>1,workload+': no observed multi-worker claims')
                    cohorts[(workload,workers)][variant].append(observation)
                    report['runs'].append({'variant':variant,'workload':workload,'workers':workers,'repeat':repeat,'process':result,'observation':observation})
                    run.write_json(out/'qualification.json',report)
            # Separate instrumented work trace; never pooled into timed samples.
            for variant in ('baseline','successor'):
                result,rows=execute(report['builds'][variant],['--bench',workload,str(workers),'1'],
                    out/f'{workload}-w{workers}-diagnostics-{variant}',deadline,plan)
                observation=benchmark_observation(rows,workload,workers,True,plan)
                require(observation['summary']['physical_hash']==identities[(variant,workload)]['physical'],'diagnostics changed physical behavior')
                report['runs'].append({'variant':variant,'workload':workload,'workers':workers,'diagnostic_only':True,'process':result,'observation':observation})
                run.write_json(out/'qualification.json',report)
    for workload in plan['benchmark_exact_control_workloads']:
        require(identities[('baseline',workload)]==identities[('successor',workload)],
                workload+': unrelated benchmark final physical/tuple identity changed across sources')
    comparisons=[]
    for (workload,workers),values in cohorts.items():
        aggregate={}
        for variant,runs in values.items():
            medians=[r['all_ticks']['median_ns'] for r in runs]
            aggregate[variant]={'run_count':len(runs),'run_median_ns':statistics.median(medians),
                'run_median_min_ns':min(medians),'run_median_max_ns':max(medians),'run_median_stdev_ns':statistics.pstdev(medians),
                'mean_tick_ns':statistics.mean(r['all_ticks']['mean_ns'] for r in runs),
                'p95_tick_ns':statistics.median(r['all_ticks']['p95_ns'] for r in runs),
                'max_tick_ns':max(r['all_ticks']['max_ns'] for r in runs),
                'tail_median_ns':statistics.median(r['tail_769_1024']['median_ns'] for r in runs),
                'jobs':runs[0]['summary']['jobs'],'visited_cells':runs[0]['summary']['visited_cells'],
                'resident_bytes':runs[0]['summary']['resident_after'],
                'max_workers_observed':max(r['summary']['max_workers_observed'] for r in runs),
                'cpu_clock_resolution_ns':runs[0]['cpu_clock_resolution_ns'],
                'cpu_mean_tick_ns':statistics.mean(r['cpu_all_ticks']['mean_ns'] for r in runs) if runs[0]['cpu_all_ticks'] else None,
                'cpu_median_tick_ns':statistics.median(r['cpu_all_ticks']['median_ns'] for r in runs) if runs[0]['cpu_all_ticks'] else None,
                'cpu_p95_tick_ns':statistics.median(r['cpu_all_ticks']['p95_ns'] for r in runs) if runs[0]['cpu_all_ticks'] else None,
                'cpu_p99_tick_ns':statistics.median(r['cpu_all_ticks']['p99_ns'] for r in runs) if runs[0]['cpu_all_ticks'] else None,
                'cpu_max_tick_ns':max(r['cpu_all_ticks']['max_ns'] for r in runs) if runs[0]['cpu_all_ticks'] else None,
                'cpu_tick_total_mean':statistics.mean(r['summary']['cpu_clock_ticks_total'] for r in runs) if runs[0]['cpu_all_ticks'] else None}
        base,new=aggregate['baseline'],aggregate['successor']
        comparisons.append({'workload':workload,'workers':workers,**aggregate,
            'mean_tick_delta_ns':new['mean_tick_ns']-base['mean_tick_ns'],
            'mean_tick_ratio':new['mean_tick_ns']/base['mean_tick_ns'] if base['mean_tick_ns'] else None,
            'mean_cpu_tick_delta_ns':new['cpu_mean_tick_ns']-base['cpu_mean_tick_ns'] if base['cpu_mean_tick_ns'] is not None else None,
            'mean_cpu_tick_ratio':new['cpu_mean_tick_ns']/base['cpu_mean_tick_ns'] if base['cpu_mean_tick_ns'] else None,
            'tail_median_delta_ns':new['tail_median_ns']-base['tail_median_ns'],
            'tail_median_ratio':new['tail_median_ns']/base['tail_median_ns'] if base['tail_median_ns'] else None})
    report['performance']={'comparisons':comparisons,'owner_performance_disposition_required':True,
        'numeric_adoption_threshold':None,'scope':'warm local native tick CPU/wall observations; no Godot, bridge, renderer or target-PC claim'}


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-root',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--mode',choices=('build','correctness','performance'),default='correctness')
    parser.add_argument('--compiler',default='g++')
    parser.add_argument('--build-report',type=Path,help='reuse authenticated builds; performance requires a complete correctness report')
    args=parser.parse_args(argv);out=run.output_directory(args.output,ROOT)
    report={'schema':'mat354.h1.qualification.v1','status':'INITIALIZING','started_utc':run.now(),
        'mode':args.mode,'host':run.cpu_identity(),'builds':{}}
    path=out/'qualification.json';run.write_json(path,report)
    try:
        require(args.mode!='performance' or args.build_report is not None,
                'performance requires --build-report with completed source-matched correctness evidence')
        plan=run.load_json(ROOT/PLAN);require(plan['schema']=='mat354.h1.qualification.v1','wrong plan schema')
        report['plan']=plan;report['plan_file']=run.fact(ROOT/PLAN);report['apparatus']=apparatus_identity(ROOT)
        require(run.sha(ROOT/'native/tests/fixtures/material_liveness_campaign_v1.json')==plan['phase_a_manifest_sha256'],'historical manifest changed')
        deadline=time.monotonic()+plan['campaign_timeout_seconds']
        roots={'baseline':args.baseline_root.resolve(),'successor':ROOT}
        report['sources']={v:source_identity(root,v,plan) for v,root in roots.items()}
        baseline_files={p['path']:p for p in report['sources']['baseline']['inputs']}
        current_files={p['path']:p for p in report['sources']['successor']['inputs']}
        delta=[p for p in sorted(set(baseline_files)|set(current_files)) if baseline_files.get(p)!=current_files.get(p)]
        require(delta==['native/src/world.cpp'],'production delta exceeds one admitted path: '+repr(delta))
        compiler=shutil.which(args.compiler);require(compiler is not None,'compiler unavailable')
        compiler=str(Path(compiler).resolve());report['compiler']=run.fact(Path(compiler))
        report['compiler_version']=run.process([compiler,'--version'],ROOT,out/'compiler-version',30)
        if args.build_report:
            old=run.load_json(args.build_report)
            require(old['status']=='EXECUTED' and old['mode'] in ('build','correctness'),'build reuse requires a completed build/correctness report')
            require(args.mode!='performance' or old['mode']=='correctness','performance requires completed correctness evidence')
            for key in ('sources','apparatus','compiler','plan'):
                require(old[key]==report[key],'build reuse identity changed: '+key)
            for v,b in old['builds'].items():
                require(run.fact(Path(b['executable']['path']))==b['executable'],'reused executable hash changed')
            report['builds']=old['builds'];report['build_report']=run.fact(args.build_report)
        else:
            for v,root in roots.items():
                report['builds'][v]=build(root,v,out/(v+'-build'),compiler,plan,deadline)
                run.write_json(path,report)
        report['status']='RUNNING';run.write_json(path,report)
        if args.mode=='correctness':correctness(report,plan,out,deadline)
        elif args.mode=='performance':performance(report,plan,out,deadline)
        for v,root in roots.items():require(source_identity(root,v,plan)==report['sources'][v],v+': source changed during execution')
        require(apparatus_identity(ROOT)==report['apparatus'],'apparatus changed during execution')
        for b in report['builds'].values():require(run.fact(Path(b['executable']['path']))==b['executable'],'binary changed during execution')
        report['status']='EXECUTED'
    except Exception as exc:
        report['status']='FAILED';report['failure']=type(exc).__name__+': '+str(exc)
    finally:
        report['finished_utc']=run.now();run.write_json(path,report)
    print(json.dumps({'status':report['status'],'report':str(path),'failure':report.get('failure'),
        'causal_disposition':report.get('correctness',{}).get('causal_disposition')}))
    return 0 if report['status']=='EXECUTED' else 1


if __name__=='__main__':
    raise SystemExit(main())
