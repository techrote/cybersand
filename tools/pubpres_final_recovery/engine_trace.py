"""Independent CPU draw/admitted-transaction join; never physical or GPU credit."""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/pubpres_playability'))
from results import distribution, need

PREFIX='PUBPRES_FRAME_BUDGET_RESULT '
SCOPE='whole_process_actual_draw_cpu_only_no_gpu_fence_no_scanout_no_physics_credit'
APPLICATION_SCOPE='actual_cpu_draw_admission_no_gpu_or_display_completion'
SERIALIZED_ELAPSED_FIELDS=frozenset(('deferred_render_step_total','consumed_render_step_total','pending_render_step',
    'rejected_render_step_total','consumed_rejected_render_step','pending_rejected_render_step'))


def integer(value,minimum=0): return type(value) is int and value>=minimum

def finite(value): return type(value) in (int,float) and math.isfinite(value) and value>=0

def close(a,b): return abs(a-b)<=max(1e-9,1e-9*max(abs(a),abs(b)))


def summary_matches(data,summary):
    raw={key:value for key,value in data.items() if key!='frames'}
    terminal={key:value for key,value in summary.items() if key not in ('trace_write_error','trace_sha256')}
    if raw.keys()!=terminal.keys(): return False
    # Godot's terminal Variant JSON uses fewer significant digits than the
    # full-precision file writer. The terminal SHA still binds every raw byte.
    # Only the six known elapsed doubles admit this serialization rounding;
    # counters, identities and the complete field inventory remain exact.
    return all(finite(value) and finite(terminal[key])
        and math.isclose(value,terminal[key],rel_tol=1e-14,abs_tol=1e-14)
        if key in SERIALIZED_ELAPSED_FIELDS else value==terminal[key]
        for key,value in raw.items())


def validate_data(data,summary,*,source,thread,budget,start,end):
    need(thread in ('safe','separate') and budget in (0,4),'Unregistered engine trace treatment')
    need(data.get('schema')=='pubpres-engine-frame-budget-v2' and data.get('scope')==SCOPE
         and data.get('application_source_revision')==source and data.get('requested')==str(budget)
         and data.get('render_thread_created') is (thread=='separate'),'Engine source, owner, scope or requested budget differs')
    need(summary.get('trace_write_error')==0 and summary_matches(data,summary),
         'Terminal engine summary differs from retained raw trace')
    need(data.get('completion_fault') is False and data.get('application_admission_faults')==0
         and data.get('trace_overflow') is False and data.get('limit')==4,'Engine completion/admission fault or trace overflow')
    frames=data.get('frames')
    need(isinstance(frames,list) and frames and len(frames)==data.get('trace_rows')
         ==data.get('actual_draw_submissions')==data.get('actual_render_cpu_completions')
         and data.get('trace_capacity')==32768 and len(frames)<=32768,'Actual draw inventory is incomplete')
    counts=('eligibility_checks','eligible_checks','deferred_turns','maximum_deferred_per_draw',
            'sync_calls','sync_total_usec','sync_max_usec','rejected_draw_opportunities')
    need(all(integer(data.get(key)) for key in counts) and data['maximum_deferred_per_draw']<=4
         and data['eligible_checks']<=data['eligibility_checks'],'Invalid engine scheduling counts')
    for total,consumed,pending in (('deferred_render_step_total','consumed_render_step_total','pending_render_step'),
            ('rejected_render_step_total','consumed_rejected_render_step','pending_rejected_render_step')):
        need(all(finite(data.get(key)) for key in (total,consumed,pending))
             and close(data[total],data[consumed]+data[pending]),'Elapsed render time was lost or invented')
    if budget==0:
        need(data['deferred_turns']==data['maximum_deferred_per_draw']==data['deferred_render_step_total']==0,
             'Budget0 performed a deferred producer opportunity')
    owners={}; previous_end=0; carried=[]; rejected=[]; spent=[]; capture=[]; joins={}
    for index,row in enumerate(frames,1):
        need(row.get('serial')==index and integer(row.get('process_frame'))
             and all(integer(row.get(key),1) for key in ('submitted_usec','render_start_usec','render_end_usec'))
             and row['submitted_usec']<=row['render_start_usec']<=row['render_end_usec']
             and row['render_start_usec']>=previous_end,'Actual render-owner execution overlaps, reorders or predates submission')
        need(row.get('actual_render_owner') is (thread=='separate') and row.get('inline_main') is (thread=='safe'),
             'Actual CPU render owner differs')
        need(integer(row.get('previous_batch_deferred_turns')) and row['previous_batch_deferred_turns']<=4
             and all(finite(row.get(key)) for key in ('applied_render_step','carried_render_step','rejected_render_step'))
             and row['applied_render_step']+1e-9>=row['carried_render_step']+row['rejected_render_step'],
             'Unbounded deferral or incorrect applied render time')
        owner=row.get('owner_instance')
        need(type(owner) is int and owner>=0,'Invalid signed application Node owner')
        if owner==0:
            need(row.get('submission_serial')==row.get('candidate_serial')==row.get('application_submitted_usec')==0,
                 'Unarmed ordinary draw invented application admission')
        else:
            serial,candidate=row.get('submission_serial'),row.get('candidate_serial')
            need(integer(serial,1) and integer(candidate,serial) and integer(row.get('application_submitted_usec'),1)
                 and row['application_submitted_usec']<=row['submitted_usec'],'Invalid actual application admission')
            if owner in owners:
                prior=owners[owner]
                need(serial==prior['submission_serial']+1 and candidate>prior['candidate_serial']
                     and row['process_frame']>=prior['process_frame'],'Duplicate, skipped or reordered application completion')
            owners[owner]=row
            key=(owner,serial,candidate)
            need(key not in joins,'Duplicate actual application draw')
            joins[key]=row
        if start<=row['submitted_usec']<=end:
            need(owner>0,'Active atomic gameplay capture admitted an unowned ordinary draw')
            capture.append(row)
        carried.append(row['carried_render_step']); rejected.append(row['rejected_render_step'])
        spent.append(row['previous_batch_deferred_turns']); previous_end=row['render_end_usec']
    need(close(sum(carried),data['consumed_render_step_total'])
         and close(sum(rejected),data['consumed_rejected_render_step']), 'Per-draw elapsed time does not sum to consumed totals')
    need(0<=data['deferred_turns']-sum(spent)<=4
         and max(spent)<=data['maximum_deferred_per_draw'],'Per-draw deferred opportunity counts differ')
    need(capture,'No actual atomic draw occurred during physical capture')
    # Conservatively exclude the first in-capture row: its carried deferrals
    # may belong to the preceding startup draw. Remaining batch boundaries are
    # both within this capture, proving actual in-capture treatment execution.
    in_capture_deferrals=sum(row['previous_batch_deferred_turns'] for row in capture[1:])
    return {'schema':'pubpres-recovery-engine-trace-analysis-v1','whole_process_draws':len(frames),
        'capture_draws':len(capture),'capture_deferred_opportunities':in_capture_deferrals,
        'treatment_executed':budget==0 or in_capture_deferrals>0,
        'whole_process_deferrals':data['deferred_turns'],'maximum_deferred_per_draw':data['maximum_deferred_per_draw'],
        'rejected_draw_opportunities':data['rejected_draw_opportunities'],
        'pending_deferred_render_step':data['pending_render_step'],'pending_rejected_render_step':data['pending_rejected_render_step'],
        'sync_total_ms':data['sync_total_usec']/1000,'sync_max_ms':data['sync_max_usec']/1000,
        'capture_draw_cpu_ms':distribution((row['render_end_usec']-row['render_start_usec'])/1000 for row in capture),
        'capture_queue_to_render_ms':distribution((row['render_start_usec']-row['submitted_usec'])/1000 for row in capture),
        'capture_submission_gap_ms':distribution((b['submitted_usec']-a['submitted_usec'])/1000 for a,b in zip(capture,capture[1:])),
        'scope':'CPU actual draw admission/render-owner execution and conserved elapsed render time only; no GPU, scanout or physical-step credit.'},joins


def validate_transactions(data,probe,base,joins):
    need(data.get('schema')=='pubpres-recovery-actual-submission-observer-v1'
         and data.get('source_identity')==base['source_identity'] and data.get('process_id')==base['process_id']
         and data.get('capture_start_usec')==base['capture_start_usec'] and data.get('capture_end_usec')==base['capture_end_usec']
         and data.get('complete') is True and data.get('capacity')==6000 and data.get('dropped')==0,
         'Actual-submission sidecar source/process/window or bounded retention differs')
    rows=data.get('rows'); probes=probe.get('submissions')
    need(isinstance(rows,list) and rows and isinstance(probes,list) and len(rows)==len(probes)<=6000,
         'Missing or aliased actual submission/probe rows')
    expected_joins={key for key,draw in joins.items() if base['capture_start_usec']<=draw['submitted_usec']<=base['capture_end_usec']}
    observed_joins={(row.get('owner_instance'),row.get('submission_serial'),row.get('candidate_serial')) for row in rows}
    need(len(observed_joins)==len(rows) and observed_joins==expected_joins,
         'Actual-submission observer omitted or invented a capture-boundary engine admission')
    total=0; previous=None
    for index,(row,observed) in enumerate(zip(rows,probes)):
        need(row.get('index')==row.get('probe_index')==observed.get('index')==index
             and row.get('body_owner_available') is True and row.get('source_revision')==base['source_identity']['source_sha']
             and row.get('submission_scope')==APPLICATION_SCOPE,'Actual gameplay submission identity or physical owner differs')
        key=(row.get('owner_instance'),row.get('submission_serial'),row.get('candidate_serial'))
        need(key in joins,'Application journal has no actual admitted engine draw')
        draw=joins[key]
        need(row.get('submitted_usec')==draw['application_submitted_usec']
             and integer(row.get('prepared_usec'),1) and integer(row.get('time_usec'),1)
             and row['prepared_usec']<=row['submitted_usec']<=draw['submitted_usec']<=row['time_usec']
             <=observed['time_usec']<=draw['render_start_usec']
             and base['capture_start_usec']<=row['time_usec']<=base['capture_end_usec'],
             'Application, engine, probe and render clocks do not describe one actual draw')
        need(row.get('prepared_process_frame')==row.get('submitted_process_frame')==row.get('process_frame')
             ==observed['process_frame']==draw['process_frame'],'Stale candidate crossed the admitted Main process turn')
        need(row.get('committed_count')==row['submission_serial'] and integer(row.get('prepared_count'),row['candidate_serial'])
             and all(integer(row.get(key)) for key in ('superseded_count','rejected_count','observer_usec')),
             'Application bookkeeping does not match actual admission')
        for key in ('physical_tick','render_serial','world_generation','material_revision'):
            need(row.get(key)==observed.get(key),'Immutable submitted frame disagrees with independently observed '+key)
        if previous:
            need(row['owner_instance']==previous['owner_instance'] and row['submission_serial']==previous['submission_serial']+1
                 and row['candidate_serial']>previous['candidate_serial'],'Capture reuses or skips actual admission identity')
        preparation=('preparation_samples','preparation_total_usec','preparation_max_usec','last_preparation_usec','last_preparation_candidate_serial')
        need(all(integer(row.get(key)) for key in preparation)
             and row['last_preparation_candidate_serial']==row['candidate_serial']
             and row['preparation_max_usec']>=row['last_preparation_usec'],
             'Preparation cost is not associated with the actual admitted candidate')
        if previous:
            need(all(row[key]>=previous[key] for key in preparation[:3])
                 and row['preparation_total_usec']-previous['preparation_total_usec']>=row['last_preparation_usec'],
                 'Preparation lifetime counters regressed or omitted admitted work')
        total+=row['observer_usec']; previous=row
    need(data.get('observer_total_usec')==total,'Actual-submission observer overhead omits a callback')
    return {'rows':len(rows),'observer_total_usec':total,
        'observer_call_ms':distribution(row['observer_usec']/1000 for row in rows),
        'prepared_to_actual_submission_ms':distribution((row['submitted_usec']-row['prepared_usec'])/1000 for row in rows),
        'exact_engine_application_probe_joins':len(rows),
        'preparation':{'observed_admitted_candidate_ms':distribution(row['last_preparation_usec']/1000 for row in rows),
            'total_usec_between_first_and_last_submission':rows[-1]['preparation_total_usec']-rows[0]['preparation_total_usec'],
            'sample_delta_between_first_and_last_submission':rows[-1]['preparation_samples']-rows[0]['preparation_samples'],
            'lifetime_max_usec_at_last_submission':rows[-1]['preparation_max_usec'],
            'scope':'Last-cost samples join actual admitted candidates only. Total/sample deltas include superseded preparation between observations; lifetime maximum cannot be subtracted. No discarded-preparation duration distribution is inferred.'}}


def validate_files(folder:Path,base:dict,*,thread:str,budget:int,presentation_enabled:bool):
    trace=folder/'engine-draws.json'
    text='\n'.join((folder/name).read_text(encoding='utf-8',errors='replace') for name in ('stdout.log','stderr.log'))
    lines=[line.removeprefix(PREFIX) for line in text.splitlines() if line.startswith(PREFIX)]
    need(len(lines)==1,'Missing or repeated terminal actual engine trace identity')
    summary=json.loads(lines[0]); raw=trace.read_bytes()
    need(summary.get('trace_sha256')==hashlib.sha256(raw).hexdigest(),'Engine trace differs from terminal exact bytes')
    result,joins=validate_data(json.loads(raw),summary,source=base['source_identity']['source_sha'],
        thread=thread,budget=budget,start=base['capture_start_usec'],end=base['capture_end_usec'])
    side=folder/'receipt-submissions.json'
    if presentation_enabled:
        actual=json.loads(side.read_bytes()); probe=json.loads((folder/'receipt-presentation.json').read_bytes())
        result['application_join']=validate_transactions(actual,probe,base,joins)
        result['actual_submission_sha256']=hashlib.sha256(side.read_bytes()).hexdigest()
    else:
        need(not side.exists(),'Disabled actual-submission observer emitted a sidecar')
        result['application_join']=None
    result['trace_sha256']=summary['trace_sha256']
    return result
