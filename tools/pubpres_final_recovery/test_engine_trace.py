from __future__ import annotations
import copy
import unittest
from engine_trace import validate_data, validate_transactions, summary_matches, SCOPE, APPLICATION_SCOPE

SOURCE='a'*40


def fixture():
    frames=[]
    for index in range(4):
        at=(index+1)*100
        frames.append({'serial':index+1,'process_frame':index+1,'submitted_usec':at,
            'render_start_usec':at+20,'render_end_usec':at+30,'previous_batch_deferred_turns':4 if index==2 else 0,
            'applied_render_step':0.05 if index==2 else 0.01,'carried_render_step':0.04 if index==2 else 0.0,
            'rejected_render_step':0.0,'owner_instance':9 if index else 0,
            'submission_serial':index,'candidate_serial':index,'application_submitted_usec':at-3 if index else 0,
            'actual_render_owner':True,'inline_main':False})
    trace={'schema':'pubpres-engine-frame-budget-v2','scope':SCOPE,'application_source_revision':SOURCE,
        'requested':'4','render_thread_created':True,'completion_fault':False,'application_admission_faults':0,
        'trace_overflow':False,'limit':4,'trace_rows':4,'actual_draw_submissions':4,'actual_render_cpu_completions':4,
        'trace_capacity':32768,'eligibility_checks':8,'eligible_checks':4,'deferred_turns':4,
        'maximum_deferred_per_draw':4,'sync_calls':4,'sync_total_usec':12,'sync_max_usec':4,
        'rejected_draw_opportunities':0,'deferred_render_step_total':.04,'consumed_render_step_total':.04,
        'pending_render_step':0.,'rejected_render_step_total':0.,'consumed_rejected_render_step':0.,
        'pending_rejected_render_step':0.,'frames':frames}
    return trace


def validate(trace):
    summary={key:value for key,value in trace.items() if key!='frames'}
    summary.update(trace_write_error=0,trace_sha256='b'*64)
    return validate_data(trace,summary,source=SOURCE,thread='separate',budget=4,start=150,end=450)


class ActualEngineTrace(unittest.TestCase):
    def test_terminal_rounding_preserves_exact_inventory_and_counts(self):
        trace=fixture();trace['rejected_render_step_total']=1.2877791249983999
        summary={key:value for key,value in trace.items() if key!='frames'}
        summary.update(trace_write_error=0,trace_sha256='b'*64)
        summary['rejected_render_step_total']=1.2877791249984
        self.assertTrue(summary_matches(trace,summary))
        changed=copy.deepcopy(summary);changed['rejected_render_step_total']+=1e-7
        self.assertFalse(summary_matches(trace,changed))
        changed=copy.deepcopy(summary);changed['actual_draw_submissions']+=1
        self.assertFalse(summary_matches(trace,changed))
        changed=copy.deepcopy(summary);changed.pop('pending_render_step')
        self.assertFalse(summary_matches(trace,changed))

    def test_actual_bounded_completion_and_unarmed_startup_are_distinct(self):
        result,joins=validate(fixture())
        self.assertEqual(result['capture_deferred_opportunities'],4)
        self.assertEqual(result['capture_draws'],3)
        self.assertTrue(result['treatment_executed'])
        self.assertEqual(len(joins),3)
        trace=fixture();trace['frames'][2]['previous_batch_deferred_turns']=0
        trace['frames'][0]['previous_batch_deferred_turns']=4
        result,_=validate(trace)
        self.assertFalse(result['treatment_executed'],'Startup-only deferral must remain an unexercised treatment')

    def test_false_completion_clock_owner_or_conservation_is_refused(self):
        for key,bad in (('actual_render_cpu_completions',3),('application_admission_faults',1),
                        ('deferred_render_step_total',.08),('pending_rejected_render_step',.1),
                        ('trace_overflow',True),('maximum_deferred_per_draw',5)):
            trace=fixture();trace[key]=bad
            with self.assertRaises(ValueError,msg=key):validate(trace)
        for key,bad in (('serial',4),('submission_serial',1),('candidate_serial',1),('render_start_usec',150),
                        ('actual_render_owner',False),('applied_render_step',.001),('owner_instance',0)):
            trace=fixture();trace['frames'][2][key]=bad
            with self.assertRaises(ValueError,msg=key):validate(trace)

    def test_exact_application_engine_probe_join_and_no_alias(self):
        _,joins=validate(fixture())
        base={'source_identity':{'source_sha':SOURCE},'process_id':73,'capture_start_usec':150,'capture_end_usec':450}
        rows=[];probes=[]
        for index,draw in enumerate(fixture()['frames'][1:]):
            row={'index':index,'probe_index':index,'body_owner_available':True,'source_revision':SOURCE,
                'owner_instance':9,'submission_serial':index+1,'candidate_serial':index+1,
                'submission_scope':APPLICATION_SCOPE,'prepared_usec':draw['application_submitted_usec']-5,
                'submitted_usec':draw['application_submitted_usec'],'time_usec':draw['submitted_usec']+1,
                'prepared_process_frame':draw['process_frame'],'submitted_process_frame':draw['process_frame'],
                'process_frame':draw['process_frame'],'committed_count':index+1,'prepared_count':index+1,
                'superseded_count':0,'rejected_count':0,'observer_usec':3,'physical_tick':index+7,
                'preparation_samples':index+1,'preparation_total_usec':(index+1)*10,'preparation_max_usec':10,
                'last_preparation_usec':10,'last_preparation_candidate_serial':index+1,
                'render_serial':index+9,'world_generation':1,'material_revision':index+3}
            rows.append(row)
            probes.append({**{key:row[key] for key in ('index','process_frame','physical_tick','render_serial','world_generation','material_revision')},
                           'time_usec':row['time_usec']+1})
        data={'schema':'pubpres-recovery-actual-submission-observer-v1','source_identity':base['source_identity'],
            'process_id':73,'capture_start_usec':150,'capture_end_usec':450,'complete':True,'capacity':6000,
            'dropped':0,'rows':rows,'observer_total_usec':9}
        probe={'submissions':probes}
        self.assertEqual(validate_transactions(data,probe,base,joins)['exact_engine_application_probe_joins'],3)
        shortened=copy.deepcopy(data);shortened['rows']=shortened['rows'][:-1];shortened['observer_total_usec']=6
        with self.assertRaisesRegex(ValueError,'capture-boundary'):
            validate_transactions(shortened,{'submissions':probes[:-1]},base,joins)
        for key,bad in (('probe_index',0),('body_owner_available',False),('submission_serial',1),
                        ('physical_tick',100),('submitted_usec',200),('prepared_process_frame',1)):
            changed=copy.deepcopy(data);changed['rows'][1][key]=bad
            with self.assertRaises(ValueError,msg=key):validate_transactions(changed,probe,base,joins)

if __name__=='__main__':unittest.main()
