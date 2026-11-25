#!/usr/bin/env python3
"""Offline attribution of recorded Main/physics opportunities; no scheduling changes."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def need(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def distribution(values):
    values = sorted(values)
    if not values:
        return None
    def quantile(f):
        index = (len(values)-1)*f
        lo = int(index)
        hi = min(lo+1, len(values)-1)
        return values[lo]+(values[hi]-values[lo])*(index-lo)
    return {'count':len(values), 'min':values[0], 'p50':quantile(.5), 'p95':quantile(.95),
            'p99':quantile(.99), 'max':values[-1], 'mean':sum(values)/len(values)}


def analyze(folder, source):
    folder, source = Path(folder).resolve(), Path(source).resolve()
    receipt = json.loads((folder/'receipt.json').read_bytes())
    source_sha = receipt['source_identity']['source_sha']
    actual_sha = subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
    need(actual_sha == source_sha, 'Replay uses a different original driver source')
    original_reader = source/'tools/pubpres_final_recovery/engine_trace.py'
    need(original_reader.read_bytes()==subprocess.check_output(['git','-C',str(source),'show',
        source_sha+':tools/pubpres_final_recovery/engine_trace.py']), 'Original engine reader was modified')
    analysis = json.loads((folder/'analysis.json').read_bytes())
    need(analysis['receipt_sha256']==digest(folder/'receipt.json')
         and analysis['statistics']['source']==source_sha
         and analysis['statistics']['trace_sha256']==receipt['trace_sha256']==digest(folder/'receipt-events.jsonl'),
         'Original full physical arm was not admitted or raw physical bytes changed')
    sys.path.insert(0,str(source/'tools/pubpres_final_recovery'))
    from engine_trace import validate_files
    arm = json.loads((folder/'arm.json').read_bytes())
    treatment = arm['treatment']
    need(treatment['engine']=='bounded' and treatment['render_thread']=='separate'
         and treatment['lookahead'] in (0,4), 'No bounded Separate original arm')
    observed = treatment.get('presentation_observer',True)
    verified = validate_files(folder,receipt,thread='separate',budget=treatment['lookahead'],presentation_enabled=observed)
    start,end = receipt['capture_start_usec'],receipt['capture_end_usec']
    trace = json.loads((folder/'engine-draws.json').read_bytes())
    draws = trace['frames']
    events = [json.loads(line) for line in (folder/'receipt-events.jsonl').read_text().splitlines()]
    main,physics,steps = defaultdict(list),defaultdict(list),defaultdict(list)
    for row in events:
        kind = row.get('event')
        if kind=='main_callback': main[row['process_frame']].append(row)
        elif kind=='physics_callback': physics[row['process_frame']].append(row)
        elif kind=='rapier_step': steps[row['origin_process_frame']].append(row)
    exact,unclassified,boundaries = [],[],[]
    total=0
    for previous,current in zip(draws,draws[1:]):
        count = current['previous_batch_deferred_turns']
        if not count: continue
        if not (start<=previous['submitted_usec']<=current['submitted_usec']<=end):
            if start<=current['submitted_usec']<=end or start<=previous['submitted_usec']<=end:
                boundaries.append({'previous_draw':previous['serial'],'next_draw':current['serial'],
                    'recorded_deferrals':count,'reason':'paired_admissions_cross_capture_boundary'})
            continue
        total += 1
        reasons=[]
        if previous['owner_instance']<=0 or current['owner_instance']!=previous['owner_instance']:
            reasons.append('owner_or_owner_transition')
        between=list(range(previous['process_frame']+1,current['process_frame']))
        if len(between)!=count:
            reasons.append('intervening_process_count_does_not_equal_recorded_deferrals')
        if any(len(main[frame])!=1 for frame in between):
            reasons.append('missing_or_duplicate_original_main_callback')
        if current['serial']!=previous['serial']+1:
            reasons.append('nonconsecutive_actual_draw_identity')
        observed_main=[main[frame][0] for frame in between if len(main[frame])==1]
        observed_physics=[row for frame in between for row in physics[frame]]
        observed_steps=[row for frame in between for row in steps[frame]]
        for label,rows in [('main',observed_main),('physics',observed_physics),('step',observed_steps)]:
            if any(not previous['submitted_usec']<=row['start_usec']<=row['time_usec']<=current['submitted_usec'] for row in rows):
                reasons.append(label+'_timestamps_outside_paired_admissions')
        callback_index = {row['callback_id']:row for row in observed_physics}
        if len(callback_index)!=len(observed_physics): reasons.append('duplicate_physics_callback_identity')
        if any(row['before_step']>row['after_step'] for row in observed_physics):
            reasons.append('regressing_physics_callback')
        for row in observed_steps:
            callback=callback_index.get(row['origin_callback_id'])
            if callback is None or row['process_frame']!=row['origin_process_frame'] \
                    or row['origin_process_frame']!=callback['process_frame'] \
                    or row['origin_physics_frame']!=callback['physics_frame'] \
                    or row['origin_callback_start_usec']!=callback['start_usec'] \
                    or not callback['start_usec']<=row['start_usec']<=row['time_usec']<=callback['time_usec'] \
                    or not callback['before_step']<row['step']<=callback['after_step']:
                reasons.append('completed_step_lacks_containing_actual_physics_callback')
                break
        if len({row['step'] for row in observed_steps})!=len(observed_steps):
            reasons.append('duplicate_completed_step_identity')
        if reasons:
            unclassified.append({'previous_draw':previous['serial'],'next_draw':current['serial'],
                'recorded_deferrals':count,'previous_process_frame':previous['process_frame'],
                'next_process_frame':current['process_frame'],'reasons':reasons})
            continue
        exact.append({'previous_draw':previous['serial'],'next_draw':current['serial'],
            'producer_process_frames':between,'recorded_deferrals':count,
            'main_callbacks':len(observed_main),'legitimate_physics_callbacks':len(observed_physics),
            'actual_completed_steps':len(observed_steps),
            'completed_step_ids':[row['step'] for row in observed_steps],
            'completed_physics_callbacks_before_prior_render_return':sum(row['time_usec']<=previous['render_end_usec'] for row in observed_physics),
            'steps_before_prior_render_return':sum(row['time_usec']<=previous['render_end_usec'] for row in observed_steps),
            'first_intervening_main_start_usec':observed_main[0]['start_usec'],
            'last_intervening_main_end_usec':observed_main[-1]['time_usec'],
            'intervening_main_observation_span_ms':(observed_main[-1]['time_usec']-observed_main[0]['start_usec'])/1000,
            'actual_draw_admission_interval_ms':(current['submitted_usec']-previous['submitted_usec'])/1000,
            'previous_render_cpu_interval_ms':(previous['render_end_usec']-previous['render_start_usec'])/1000,
            'carried_scaled_render_step_ms':1000*current['carried_render_step']})
    return {'schema':'pubpres-deferred-producer-attribution-v1','source_commit':source_sha,
        'original_engine_validation':verified,
        'original_physical_validation':'Original admitted analysis/receipt/events byte join only; full V3 physical reduction is not independently re-executed by this supplementary tool.',
        'raw_sha256':{name:digest(folder/name) for name in ['receipt.json','receipt-events.jsonl','engine-draws.json','arm.json','analysis.json']},
        'complete_in_capture_batches_with_deferrals':total,'exact_batches':len(exact),'unclassified_batches':len(unclassified),
        'exact_batch_histograms':{key:dict(sorted(Counter(row[key] for row in exact).items())) for key in
            ['recorded_deferrals','legitimate_physics_callbacks','actual_completed_steps']},
        'exact_batch_distributions':{key:distribution(row[key] for row in exact) for key in
            ['intervening_main_observation_span_ms','actual_draw_admission_interval_ms',
             'previous_render_cpu_interval_ms','carried_scaled_render_step_ms']},
        'batches':exact,'unclassified':unclassified,'capture_boundary_batches':boundaries,
        'scope':'Exact original engine draw/callback/step associations only. Intervening Main callback spans exclude uninstrumented late preparation/flush/defer calls. Carried scaled render time is not wall time. No individual defer timestamp, prospective physics deadline, GPU/display completion or physical credit is inferred. Every ambiguous batch remains counted and retained.'}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arm',type=Path,required=True)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    need(not args.output.exists(),'Preserve previous analysis')
    result=analyze(args.arm,args.source)
    result['analysis_script_sha256']=digest(__file__)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({key:result[key] for key in ['source_commit','complete_in_capture_batches_with_deferrals','exact_batches','unclassified_batches','exact_batch_histograms','exact_batch_distributions']},indent=2))
